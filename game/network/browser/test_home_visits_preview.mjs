import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]),data=await mkdtemp(join(tmpdir(),'willowbrook-visits-test-'));
const users=['qa_home_owner','qa_home_guest','qa_home_other'].map(username=>({username,password:'synthetic Home Visits QA pass '+username}));
const load=p=>import(pathToFileURL(join(source,p)));
const {makeStore}=await load('world-store.mjs');
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const opts={source,port:0,accountsDir:data};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
let server,sockets=[];
async function start(enableHomeVisits=false,seedAccounts=[]){server=await startLocalServer({...opts,enableHomeVisits,seedAccounts});}
async function stop(){for(const c of sockets)c.terminate();sockets=[];await server?.close();server=null;}
async function connect(user){
 const url='127.0.0.1:'+server.address.port;
 const ws=new WebSocket('ws://'+url+'/play',{origin:'http://'+url});sockets.push(ws);
 let inbox=[];ws.on('message',b=>inbox.push(JSON.parse(b)));await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j)});
 const send=data=>{ws.send(JSON.stringify(data));};
 async function get(pred,start=0,ms=4000){const limit=Date.now()+ms;do{const r=inbox.slice(start).find(pred);if(r)return r;await wait(20);}while(Date.now()<limit);throw new Error('No matching result');}
 const act=async (action,fields={})=>{const n=inbox.length;send({type:'homeVisit',action,...fields});return get(m=>m.type==='homeVisit'&&m.action===action,n);};
 const move=async (zone,x=0,z=0,grounded=true)=>{await wait(45);const n=inbox.length;send({type:'move',zone,x,z,y:0,yaw:0,grounded});return get(m=>m.type==='world'&&m.zone===zone,n);};
 if(!user)return {send,get,act};
 send({type:'login',...user});const welcome=await get(m=>m.type==='welcome');
 return {send,get,act,move,ws,welcome,mark:()=>inbox.length};
}
async function enterOwner(p,plot,x,z){
 await p.move('town',x,z);
 const n=p.mark();p.send({type:'progress',action:'housing',operation:'enter',plot});
 const r=await p.get(m=>m.type==='progress'&&m.action==='housing'&&m.operation==='enter',n);
 assert.equal(r.ok,true);return p.move('private');
}
async function visit(p,plot,x,z){
 await p.move('town',x,z);const r=await p.act('enter',{plot});assert.equal(r.ok,true);assert.equal(r.plot,plot);
 return p.move('private');
}
const view=(p,x,z)=>p.send({type:'homeVisit',action:'pose',x,y:0,z,yaw:0,moving:false,grounded:true});
try{
 await start(false,users);
 assert.ok(!(await connect(users[0])).welcome.homeVisits);
 await stop();
 const file=join(data,'preview-accounts-v1.json');
 let store=makeStore(file);let [a,b,c]=users.map(u=>store.state.profiles[u.username]);
 for(const p of [a,c])p.hasJob=true;
 assert.equal(store.bank(a,{action:'apply',home:0},{interiorBusiness:'bank',x:-54,z:-48}),null);
 assert.equal(store.bank(c,{action:'apply',home:1},{interiorBusiness:'bank',x:-54,z:-48}),null);
 store.state.homes[0].furniture.push({id:'000000000000000000000001',kind:'scavengerTrophy',room:0,x:2,z:0,rotation:0});
 store.save();
 await start(true);
 const stranger=await connect();
 stranger.send({type:'homeVisit',action:'enter',plot:0});
 assert.match((await stranger.get(m=>m.type==='denied')).error,/Sign in/);
 const o=await connect(users[0]),g=await connect(users[1]),n=await connect(users[2]);
 assert.equal(o.welcome.homeVisits,true);
 await g.move('town',0,3);
 assert.equal((await g.act('enter',{plot:0})).ok,false);
 await g.move('town',-51,-19,false);
 assert.equal((await g.act('enter',{plot:0})).ok,false);
 const guest=await visit(g,0,-51,-19);
 assert.equal(guest.homeScene.owner,false);
 assert.deepEqual(guest.homeScene.decor,[{id:'decor-0',kind:'scavengerTrophy',room:0,x:2,z:0,y:0,rotation:0}]);
 assert.deepEqual(guest.players,[]);
 assert.equal((await g.act('lock',{locked:true})).ok,false);
 for(const m of [
  {action:'housing',operation:'repay',amount:1,loanId:'x',requestId:'qa-auth-a'},
  {action:'furniture',operation:'pack',id:'000000000000000000000001',requestId:'qa-auth-b',expectedRevision:0},
  {action:'pets',operation:'equip',id:null,requestId:'qa-auth-c'},
  {action:'jobs',operation:'finish',requestId:'qa-auth-d'}
 ]){
  const before=g.mark();g.send({type:'progress',...m});
  await g.get(w=>w.type==='homeVisit'&&w.action==='readOnly',before);
 }
 await enterOwner(o,0,-51,-19);
 await enterOwner(n,1,-51,5);
 view(o,1.25,2);view(g,2.25,3);
 const ownerView=await o.get(m=>m.homeScene?.visitors.some(x=>x.alias===users[1].username));
 assert.equal(ownerView.homeScene.visitors[0].x,2.25);
 assert.ok(!ownerView.homeScene.decor);
 assert.ok(!Object.hasOwn(ownerView.homeScene.visitors[0],'stars'));
 const guestView=await g.get(m=>m.homeScene?.visitors.some(x=>x.alias===users[0].username));
 assert.equal(guestView.homeScene.visitors[0].z,2);
 const otherView=await n.get(m=>m.homeScene?.owner);
 assert.deepEqual(otherView.homeScene.visitors,[]);
 assert.ok(otherView.presence.every(x=>!x.place.includes('Home')&&!Object.hasOwn(x,'plot')));
 const ejectAt=g.mark();
 assert.equal((await o.act('lock',{locked:true})).locked,true);
 await g.get(m=>m.type==='homeVisit'&&m.action==='eject',ejectAt);
 await g.get(m=>m.type==='world'&&m.zone==='private'&&!m.homeScene,ejectAt);
 await stop();
 await start(true);
 const g2=await connect(users[1]);await g2.move('town',-51,-19);
 assert.equal((await g2.act('enter',{plot:0})).ok,false);
 const o2=await connect(users[0]);await enterOwner(o2,0,-51,-19);
 const unlocked=await o2.act('lock',{locked:false});assert.equal(unlocked.ok,true);assert.equal(unlocked.locked,false);
 o2.ws.close();await wait(150);
 assert.ok((await visit(g2,0,-51,-19)).homeScene);
 assert.equal((await g2.act('leave')).ok,true);
 assert.equal((await g2.move('town',-51,-17)).homeScene,undefined);
 await stop();
 store=makeStore(file);
 assert.equal(store.state.homes[0].locked,false);
 assert.equal(store.state.homes[0].furniture.length,1);
 assert.equal(store.state.profiles[users[1].username].stars,0);
 store.state.profiles[users[0].username].disabled=true;store.save();
 await start(true);
 const g3=await connect(users[1]);await g3.move('town',-51,-19);
 assert.equal((await g3.act('enter',{plot:0})).ok,false);
 console.log('PASS Home Visits real disposable sockets: opt-in, admission, range/on-foot, lock persists across restart, ejection, offline owner distinction, visitor actions blocked, exact décor & same-house pose only, leave, disabled homeowner deny.');
}finally{await stop();await rm(data,{recursive:true,force:true});}
