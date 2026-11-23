import assert from 'node:assert/strict';
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
 await take(m=>m.type==='welcome');
 send({type:'move',zone:'arcade',x:-6,y:0,z:-3.65,yaw:0,moving:false,grounded:true});
 await take(m=>m.type==='world'&&m.zone==='arcade');
 const act=(action,extra={})=>send({type:'hoops88',action,...extra});
 const ack=action=>take(m=>m.type==='hoops88'&&m.action===action);
 return {act,ack,ws};
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
 assert.deepEqual((await board(a)).rows,[]);
 assert.equal((await play(a,8)).best,8);
 assert.equal((await play(b,8)).best,8);
 assert.equal((await play(a,0)).best,8);
 const expected=[{rank:1,displayName:'qa_hoops_1',score:8},{rank:2,displayName:'qa_hoops_2',score:8}];
 assert.deepEqual((await board(b)).rows,expected);
 await finish();
 const data=JSON.parse(await readFile(join(accountsDir,'preview-accounts-v1.json'),'utf8'));
 assert.ok(data.profiles.qa_hoops_1.hoopsBest.finishedAt<data.profiles.qa_hoops_2.hoopsBest.finishedAt);
 await begin();
 const resumed=await connect(seedAccounts[1]);
 assert.equal((await board(resumed)).best,8);
 assert.deepEqual((await board(resumed)).rows,expected);
 await finish();

 await begin({source,port:0});
 const guest=await connect(null);
 const practice=await play(guest,0);
 assert.equal(practice.best,0);assert.deepEqual(practice.rows,[]);
 guest.act('leave');assert.equal((await guest.ack('leave')).best,null);
 await finish();

 const fixture={profile:{username:'synthetic',hoopsBest:{score:3,finishedAt:123}}};
 const out=createHoopsScores({hoopsLeaderboard:()=>[],accountFile:join(accountsDir,'missing.json'),recordHoopsBest(profile,score,finishedAt){profile.hoopsBest={score,finishedAt};throw Error('Synthetic disk failure');}});
 assert.throws(()=>out.record(fixture,{score:8,endsAt:999,finished:true}));
 assert.equal(out.best(fixture),3);
 console.log('PASS actual verified baskets, two independent accounts, stable ties, lower score/replay, graceful drain/restart, guest cabinet only, failed-write previous best');
}finally{Date.now=realNow;await finish();}

