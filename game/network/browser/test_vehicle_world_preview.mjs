
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp} from 'node:fs/promises';
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
const approx=(a,b,d=.10)=>Math.abs(a-b)<d;
try{
 server=await startLocalServer({...options,seedAccounts:users});await close();
 const fixture=makeStore(join(accountsDir,'preview-accounts-v1.json'));
 fixture.state.profiles[users[0].username].stars=120;
 fixture.state.homes[0].owner=fixture.state.profiles[users[0].username].id;
 fixture.state.homes[0].paidOff=true; fixture.save();
 server=await startLocalServer(options);
 const a=await connect(users[0]),b=await connect(users[1]);
 const carId='a'+a.welcome.id;
 const car=(peer=a)=>peer.world?.vehicles?.rows.find(row=>row.id===carId);
 a.move(19,3);b.move(17,12);
 a.send({type:'progress',action:'vehicles',operation:'buy',expectedTier:-1,requestId:'fixture-purchase-01'});
 const bought=await a.take(x=>x.type==='progress'&&x.action==='vehicles');
 assert.equal(bought.stars,90);
 const parked=await wait(()=>car(a));
 assert.equal((await wait(()=>car(b))).canDrive,false);
 assert.equal(parked.canDrive,true); assert.equal(parked.tier,0);
 b.move(51,49.8);await sleep(100);
 b.send({type:'playground',action:'board',target:'swing-0',onFoot:true});
 assert.equal((await b.take(x=>x.type==='playground')).ok,true);
 b.move(parked.x,parked.z-2);await sleep(110);
 assert.equal((await b.action('enter',{car:carId,seat:'passenger'})).ok,false);
 assert.equal(b.world?.playground?.self,'swing-0');
 b.send({type:'playground',action:'exit'});
 assert.equal((await b.take(x=>x.type==='playground')).ok,true);
 a.move(parked.x,parked.z+2);b.move(parked.x,parked.z-2);
 await sleep(120);
 assert.equal((await b.action('enter',{car:carId,seat:'driver'})).ok,false);
 assert.equal((await a.action('enter',{car:carId,seat:'driver'})).ok,true);
 assert.equal((await b.action('enter',{car:carId,seat:'passenger'})).ok,true);
 b.send({type:'playground',action:'board',target:'swing-0',onFoot:true});
 const lease=(await b.take(x=>x.type==='playground'));
 assert.equal(lease.ok,false);assert.match(lease.error,/Get off the vehicle/);

 await wait(()=>a.world?.vehicles?.self?.seat==='driver'&&b.world?.vehicles?.self?.seat==='passenger');
 for(let i=0;i<7;i++){b.input(1,0);await sleep(70);}
 assert.ok(approx(car(a).x,parked.x)&&approx(car(b).z,parked.z));
 for(let i=0;i<16;i++){a.input(1,0);await sleep(85);}
 const moved=await wait(()=>car(a)?.x>parked.x+3&&car(a));
 assert.equal((await b.action('exit')).ok,false);
 await wait(()=>car(b)?.x>=moved.x);
 assert.ok(approx(a.world.players[0].x,car(a).x,.7));
 assert.ok(approx(b.world.players[0].x,car(b).x,.7));
 assert.equal(a.world.players[0].vehicleSeat.seat,'passenger');
 assert.equal(b.world.players[0].vehicleSeat.seat,'driver');
 await sleep(1100);
 const stopped=car(a);assert.equal(stopped.speed,0);assert.ok(validVehicleGround(stopped.x,stopped.z));
 assert.equal((await b.action('exit')).ok,true);
 const departed=once(a.ws,'close');a.ws.close();await departed;
 await wait(()=>car(b)?.driver===null&&car(b)?.passenger===null);
 const bPose=car(b);assert.equal(bPose.speed,0);
 b.move(0,34,'beach');
 await wait(()=>b.world?.zone==='beach');
 assert.equal(b.world.vehicles,undefined);
 await close();server=await startLocalServer(options);
 const renewed=await connect(users[0]);
 renewed.move(16,13);
 const saved=await wait(()=>renewed.world?.vehicles?.rows.find(row=>row.id===carId));
 assert.ok(approx(saved.x,bPose.x));assert.equal(saved.driver,null);
 assert.equal(renewed.welcome.progress.stars,90);assert.equal(renewed.welcome.progress.vehicleOffer.tier,0);
 renewed.move(19,3);await sleep(110);
 assert.equal((await renewed.action('recall',{destination:'lot'})).ok,true);
 await wait(()=>approx(car(renewed)?.x,24));
 renewed.move(-40.1,-19.6);await sleep(110);
 assert.equal((await renewed.action('recall',{destination:'home'})).ok,true);
 const stowed=await wait(()=>approx(car(renewed)?.x,-40.1)&&car(renewed));
 renewed.move(stowed.x+2.0,stowed.z);await sleep(110);
 assert.equal((await renewed.action('enter',{car:carId,seat:'driver'})).ok,true);
 assert.equal((await renewed.action('park')).ok,true);
 renewed.move(-22,4.9);await sleep(110);
 assert.equal((await renewed.action('enter',{car:'s0',seat:'passenger'})).ok,false);
 assert.equal((await renewed.action('enter',{car:'s0',seat:'driver'})).ok,true);
 assert.equal((await renewed.action('return')).ok,true);
 console.log('PASS authoritative two-account buy, distinct dynamic seats, passenger cannot drive, synchronized motion, stopped exit, stale throttle stop, driver disconnect releases, Beach isolation and parked ownership restart plus lot/home recall, home parking and shared scooter return');
}finally{await close();}



