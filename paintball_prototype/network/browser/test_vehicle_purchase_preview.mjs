
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {once} from 'node:events';
import {startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]);
const {makeStore}=await import(pathToFileURL(join(source,'world-store.mjs')).href);
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-vehicle-disposable-'));
const users=[{username:'qa_driver_a',password:'fixture-driver-a'},{username:'qa_driver_b',password:'fixture-driver-b'}];
const options={source,port:0,accountsDir};
let server;
async function close(){const old=server;server=null;await old?.close();}
async function connect(auth){
 const origin='http://127.0.0.1:'+server.address.port;
 const ws=new WebSocket(origin.replace('http','ws')+'/play',{origin});
 const packets=[];ws.on('message',buf=>{packets.push(JSON.parse(buf));if(packets.length>100)packets.shift();});
 await once(ws,'open');
 const send=p=>ws.send(JSON.stringify(p));
 const take=async pred=>{
  const limit=Date.now()+4500;
  do{
   const i=packets.findIndex(pred);
   if(i>=0)return packets.splice(i,1)[0];
   await new Promise(r=>setTimeout(r,10));
  }while(Date.now()<limit);
  throw Error('Missing expected packet');
 };
 send({type:'login',...auth});
 const welcome=await take(x=>x.type==='welcome');
 const move=(x,z,zone='town')=>send({type:'move',zone,x,z,y:0,yaw:0,moving:false,grounded:true});
 const action=async(data)=>{send({type:'progress',action:'vehicles',...data});return take(m=>m.type==='progress'&&m.action==='vehicles')};
 return {send,take,move,action,welcome};
}
const op=(operation,expectedTier,suffix)=>({operation,expectedTier,requestId:'test-offer-'+suffix});
const snapshot=(r,stars,tier)=>{assert.equal(r.stars,stars);assert.deepEqual(r.vehicleOffer,{tier});};
try{
 server=await startLocalServer({...options,seedAccounts:users});await close();
 const fixture=makeStore(join(accountsDir,'preview-accounts-v1.json'));
 fixture.state.profiles[users[0].username].stars=200;
 fixture.state.profiles[users[1].username].stars=25; fixture.save();
 server=await startLocalServer(options);
 const a=await connect(users[0]),b=await connect(users[1]);
 snapshot(a.welcome.progress,200,-1);snapshot(b.welcome.progress,25,-1);
 assert.match((await a.action(op('buy',-1,'outside'))).error,/Walk/);
 a.move(19,3);b.move(19,3);
 const buy=op('buy',-1,'buy');const upgrade=op('upgrade',0,'blue');
 snapshot(await a.action(buy),170,0);
 assert.match((await a.action(buy)).text,/already saved/);
 assert.match((await a.action(op('upgrade',0,'buy'))).error,/different offer/);
 snapshot(await a.action(upgrade),110,1);
 snapshot(await a.action(op('upgrade',1,'sport')),10,2);
 assert.match((await a.action(op('upgrade',1,'old-tier'))).error,/selection changed/);
 const poor=await b.action(op('buy',-1,'poor'));assert.match(poor.error,/Earn 30/);snapshot(poor,25,-1);
 const peer=await b.take(m=>m.type==='world'&&m.players.length===1);
 assert.equal(peer.vehicleOffer,undefined);
 assert.equal(peer.players[0].vehicleOffer,undefined);
 await close();server=await startLocalServer(options);
 const restored=await connect(users[0]),other=await connect(users[1]);
 snapshot(restored.welcome.progress,10,2);snapshot(other.welcome.progress,25,-1);
 restored.move(19,3);snapshot(await restored.action(upgrade),10,2);
 await new Promise(r=>setTimeout(r,55));
 restored.move(20,49);
 restored.send({type:'progress',action:'tendGarden'});
 const watered=await restored.take(m=>m.type==='progress'&&m.action==='tendGarden');
 assert.equal(watered.ok,true,watered.error);snapshot(watered,12,2);
 assert.ok(watered.jobs.completed.includes('garden'));
 console.log('PASS disposable Willow Wheels actual socket purchase, exact 30/60/100 debits, stale/repeated request, insufficient stars, private owner snapshots and restart');
}finally{await close();}

