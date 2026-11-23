
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {once} from 'node:events';
import {startLocalServer} from './server.mjs';
import {validVehicleGround} from './vehicle_world_preview.mjs';
const source=resolve(process.argv[2]);
const {makeStore}=await import(pathToFileURL(join(source,'world-store.mjs')).href);
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-vehicle-world-'));
const users=[{username:'qa_seat_a',password:'fixture-driver-only-a'},{username:'qa_seat_b',password:'fixture-driver-only-b'}];
const options={source,port:0,accountsDir};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let server;
async function close(){const old=server;server=null;await old?.close();}
async function connect(auth){
 const origin='http://127.0.0.1:'+server.address.port;
 const ws=new WebSocket(origin.replace('http','ws')+'/play',{origin});
 const packets=[];let latest;
 ws.on('message',buf=>{const row=JSON.parse(buf);packets.push(row);if(row.type==='world')latest=row;if(packets.length>120)packets.shift();});
 await once(ws,'open');
 const send=p=>ws.send(JSON.stringify(p));
 const take=async pred=>{
  const limit=Date.now()+5000;
  do{const i=packets.findIndex(pred);if(i>=0)return packets.splice(i,1)[0];await sleep(15);}while(Date.now()<limit);
  throw Error('Missing expected packet');
 };
 send({type:'login',...auth});const welcome=await take(x=>x.type==='welcome');
 const move=(x,z,zone='town')=>send({type:'move',zone,x,z,y:0,yaw:0,moving:false,grounded:true});
 const action=async(operation,m={})=>{send({type:'vehicleAction',operation,...m});return take(x=>x.type==='vehicleEvent');};
 const input=(throttle=0,steer=0)=>send({type:'vehicleInput',throttle,steer});
 return {move,take,send,input,action,welcome,ws,get world(){return latest}};
}
async function wait(f){const t=Date.now()+4800;do{let value=f();if(value)return value;await sleep(20);}while(Date.now()<t);throw Error('Vehicle snapshot not observed');}

const snap=(f,tier)=>{assert.equal(f.ok,true,f.error);return f;};
try{
 server=await startLocalServer({...options,seedAccounts:users});await close();
 const fixture=makeStore(join(accountsDir,'preview-accounts-v1.json'));
 const p=fixture.state.profiles[users[0].username];
 p.hasJob=true;p.stars=520; fixture.save();
 server=await startLocalServer(options);
 const a=await connect(users[0]),b=await connect(users[1]);
 const near=async (client,x,z,zone='town')=>{client.move(x,z,zone);await sleep(90);};
 const doAction=async(action,operation,extra={})=>{
  const id='qa-b5-combination-'+action+'-'+operation+'-'+ ++serial;
  a.send({type:'progress',action,operation,requestId:id,...extra});
  const r=await a.take(x=>x.type==='progress'&&x.action===action&&x.operation===operation);
  assert.equal(r.ok,true,r.error);
  return r;
 };
 let serial=0;
 await near(a,0,1,'bank');
 const initial=await doAction('housing','claim',{plot:0});assert.equal(initial.stars,520);
 const first=await doAction('housing','repay',{loanId:initial.mortgage.id,amount:100});assert.equal(first.stars,420);
 const cottage=await doAction('housing','upgrade',{plot:0,variant:'cottage',loanId:first.mortgage.id});
 assert.equal(cottage.mortgage.balance,200);
 const repaid=await doAction('housing','repay',{loanId:cottage.mortgage.id,amount:200});assert.equal(repaid.stars,220);
 const family=await doAction('housing','upgrade',{plot:0,variant:'family',loanId:repaid.mortgage.id});
 assert.equal(family.home.variant,'family');assert.equal(family.mortgage.balance,300);
 await near(a,0,-1,'store');
 const order=await doAction('furniture','buy',{kind:'books',quantity:1});assert.equal(order.stars,218);
 assert.equal(order.furniture.deliveries[0].kind,'books');
 await near(a,-51,-19);
 const packed=await doAction('furniture','pickup',{deliveryId:order.furniture.deliveries[0].id});
 assert.equal(packed.furniture.stock[0].kind,'books');
 // Housing entry and fixture-authorized room-local placement are separate from public world pose.
 a.send({type:'progress',action:'housing',operation:'enter',plot:0});
 assert.equal((await a.take(x=>x.type==='progress'&&x.action==='housing'&&x.operation==='enter')).ok,true);
 await near(a,0,0,'private');
 a.send({type:'progress',action:'furniture',operation:'pose',x:0,y:0.04,z:3.5});
 await sleep(110);
 const placed=await doAction('furniture','place',{kind:'books',room:0,x:2,z:0,rotation:0});
 assert.equal(placed.furniture.placed[0].kind,'books');
 const yard=await doAction('yard','buy',{kind:'fence'});
 assert.equal(yard.stars,188);assert.equal(yard.yard.flags.fence,true);
 await near(b,0,3);
 const shared=await b.take(x=>x.type==='world'&&x.yards?.some(y=>y.plot===0&&y.fence));
 assert.deepEqual(shared.yards,[{plot:0,fence:true,trees:false,decor:false}]);
 assert.equal(shared.furniture,undefined);assert.equal(shared.yard,undefined);assert.equal(shared.players.length,0);
 await near(a,19,3);
 const car=await doAction('vehicles','buy',{expectedTier:-1});
 assert.equal(car.stars,158);assert.equal(car.vehicleOffer.tier,0);
 await near(a,20,49);
 a.send({type:'progress',action:'tendGarden'});
 const garden=await a.take(x=>x.type==='progress'&&x.action==='tendGarden');
 assert.equal(garden.ok,true);assert.equal(garden.stars,160);
 assert.ok(garden.jobs.completed.includes('garden'));
 await close();server=await startLocalServer(options);
 const after=await connect(users[0]),peer=await connect(users[1]);
 const one=after.welcome.progress,two=peer.welcome.progress;
 if(process.argv[3])await writeFile(process.argv[3],JSON.stringify({...after.welcome,session:'x'.repeat(48)}));
 assert.equal(one.stars,160);assert.equal(one.mortgage.balance,300);assert.equal(one.home.variant,'family');
 assert.equal(one.furniture.placed[0].kind,'books');assert.equal(one.yard.flags.fence,true);assert.equal(one.vehicleOffer.tier,0);
 assert.equal(two.stars,0);assert.equal(two.home,null);assert.deepEqual(two.furniture.placed,[]);assert.equal(two.vehicleOffer.tier,-1);
 console.log('PASS B5 two-account cross-feature authoritative wallet 520→420→220→218→188→158→160, saved Family house, delivered/placed books, public-only fence, car, Garden and isolation after restart');
} finally{await close();}



