import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {openPreviewAccounts} from './preview_accounts.mjs';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp,readFile} from 'node:fs/promises';
import {once} from 'node:events';
import {startLocalServer} from './server.mjs';
import {createHoopsScores} from './hoops_scores_preview.mjs';

const source=resolve(process.argv[2]);
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-hoops-qa-'));
const seedAccounts=[{username:'qa_hoops_1',password:'fixture-a-only'},{username:'qa_hoops_2',password:'fixture-b-only'}];
const realNow=Date.now;
let offset=0,server;
Date.now=()=>realNow()+offset;
const opts={source,port:0,accountsDir};
const begin=async (options=opts)=>{server=await startLocalServer(options);};
const finish=async()=>{const old=server;server=null;await old?.close();};
async function connect(auth){
 const origin='http://127.0.0.1:'+server.address.port;
 const ws=new WebSocket(origin.replace('http','ws')+'/play',{origin,...(!auth?{origin:''}:{})});
 const incoming=[];
 ws.on('message',data=>{incoming.push(JSON.parse(data));if(incoming.length>100)incoming.shift();});
 await once(ws,'open');
 const send=data=>ws.send(JSON.stringify(data));
 const take=async pred=>{
  const limit=realNow()+4000;
  do{
   const i=incoming.findIndex(pred);
   if(i>=0)return incoming.splice(i,1)[0];
   await new Promise(r=>setTimeout(r,10));
  }while(realNow()<limit);
  throw Error('Expected WebSocket response not received.');
 };
 send(auth?{type:'login',...auth}:{type:'join',alias:'Guest Round',code:server.invite});
 const hello=await take(m=>m.type==='welcome');
 send({type:'move',zone:'arcade',x:-6,y:0,z:-3.65,yaw:0,moving:false,grounded:true});
 await take(m=>m.type==='world'&&m.zone==='arcade');
 const act=(action,extra={})=>send({type:'hoops88',action,...extra});
 const ack=action=>take(m=>m.type==='hoops88'&&m.action===action);
 const move=async (zone,x,z)=>{ send({type:'move',zone,x,y:0,z,yaw:0,moving:false,grounded:true}); await take(m=>m.type==='world'&&m.zone===zone); }; return {act,ack,ws,send,take,move,hello};
}
let req=0;
async function play(client,target){
 client.act('start',{requestId:'disposable-round-'+(++req)});
 const {run}=await client.ack('start');
 assert.ok(run?.id);
 let seq=0;
 if(target){
  client.act('input',{runId:run.id,seq:++seq,tick:1,key:'shoot',down:true});
  await new Promise(r=>setTimeout(r,490));
  client.act('input',{runId:run.id,seq:++seq,tick:57,key:'shoot',down:false});
 }
 client.act('finish',{runId:run.id,seq});
 assert.match((await client.ack('finish')).error,/still running/);
 offset+=60010;
 client.act('finish',{runId:run.id,seq});
 const verified=await client.ack('finish');
 assert.equal(verified.error,undefined);
 assert.equal(verified.run.score,target);
 client.act('finish',{runId:run.id,seq});
 assert.equal((await client.ack('finish')).replay,true);
 return verified;
}
const board=async client=>{client.act('leaderboard');return client.ack('leaderboard');};
try{
 await begin({...opts,seedAccounts});
 const a=await connect(seedAccounts[0]),b=await connect(seedAccounts[1]);
 const move=(c,zone,x,y,z,rest='')=>c.send({type:'move',zone,x,y,z,yaw:1.57,moving:false,grounded:true,rest});
 move(b,'bank',-4.6,0,1);
 move(a,'bank',-6,.55,1,'sit');
 const seated=await b.take(m=>m.type==='world'&&m.zone==='bank'&&m.players.some(p=>p.alias==='qa_hoops_1'&&p.rest==='sit'));
 assert.equal(seated.players.find(p=>p.alias==='qa_hoops_1').yaw,1.57);
 await new Promise(r=>setTimeout(r,75));
 move(a,'bank',-4.7,0,1);
 await b.take(m=>m.type==='world'&&m.zone==='bank'&&m.players.some(p=>p.alias==='qa_hoops_1'&&p.rest===''));
 move(a,'private',2,.61,-2,'lie');
 await b.take(m=>m.type==='world'&&m.zone==='bank'&&m.players.length===0);
 const privateView=await a.take(m=>m.type==='world'&&m.zone==='private');
 assert.deepEqual(privateView.players,[]);
 move(a,'beach',0,0,25);
 await a.take(m=>m.type==='world'&&m.zone==='beach');
 move(b,'beach',2,0,20);
 const beach=await b.take(m=>m.type==='world'&&m.zone==='beach'&&m.players.some(p=>p.alias==='qa_hoops_1'));
 assert.equal(beach.players[0].rest,'');
 console.log('PASS real detached server relay: public Bank seat/yaw only to same-zone browser peer; stand clears; private rooms expose no coordinates/pose; returning to Beach resets pose');
}finally{Date.now=realNow;await finish();}
