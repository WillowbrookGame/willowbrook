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

if (process.argv.length !== 3) {
 console.error('Usage: node game/network/browser/test_b2_combined_restore.mjs <standalone-runtime-dir>');
 process.exit(2);
}
const source=resolve(process.argv[2]);
const {WebSocket}=createRequire(join(source,'package.json'))('./vendor/ws');
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
 // Seed a disposable profile with a caught fish and one R5 compatible companion.
 const file=join(accountsDir,'preview-accounts-v1.json');
 const world=await import(pathToFileURL(join(source,'world-store.mjs')).href);
 const seeded=await openPreviewAccounts({accountsDir,source,site:null,seeds:seedAccounts,makeStore:world.makeStore});
 const profile=seeded.state.profiles[seedAccounts[0].username];
 const petId='abcdef0123456789abcdef01';
 profile.stars=75;
 profile.previewFishing={inventory:[{id:'abcdef0123456789abcdef02',type:'goldfish'}],sales:[],catches:[]};
 profile.previewPets={owned:[{id:petId,species:'beaver'}],activeId:petId};
 seeded.save();
 await begin(opts);
 const a=await connect(seedAccounts[0]),b=await connect(seedAccounts[1]);
 assert.equal(a.hello.progress.stars,75);
 assert.equal(a.hello.progress.pets.activeId,petId);
 assert.equal(a.hello.progress.fishing.inventory.length,1);
 assert.equal((await play(a,8)).best,8);
 await a.move('library',0,1.2);
 a.send({type:'progress',action:'classes',operation:'pay',requestId:'b2-class-fixture-1',course:'delivery',amount:50,tier:0,paid:0});
 const paid=await a.take(m=>m.type==='progress'&&m.action==='classes');
 assert.equal(paid.ok,true,paid.error);
 assert.equal(paid.stars,25);
 assert.equal(paid.classes.delivery.reward,5);
 assert.equal(paid.fishing.inventory.length,1);
 assert.equal(paid.pets.activeId,petId);
 await a.move('beach',-19,28);
 a.send({type:'progress',action:'fishing',operation:'quote',requestId:'b2-fish-quote-1'});
 const quoted=await a.take(m=>m.type==='progress'&&m.action==='fishing'&&m.operation==='quote');
 assert.equal(quoted.ok,true,quoted.error);
 assert.equal(quoted.stars,25);
 a.send({type:'progress',action:'fishing',operation:'sell',requestId:'b2-fish-sale-1',quoteId:quoted.quote.quoteId});
 const sold=await a.take(m=>m.type==='progress'&&m.action==='fishing'&&m.operation==='sell');
 assert.equal(sold.ok,true,sold.error);
 assert.equal(sold.stars,26);
 assert.equal(sold.classes.delivery.tier,1);
 assert.equal(sold.fishing.inventory.length,0);
 assert.equal(sold.pets.activeId,petId);
 assert.equal(b.hello.progress.stars,0);
 await finish();
 await begin();
 const after=await connect(seedAccounts[0]),neighbor=await connect(seedAccounts[1]);
 assert.equal(after.hello.progress.stars,26);
 assert.equal(after.hello.progress.classes.delivery.reward,5);
 assert.deepEqual(after.hello.progress.fishing.inventory,[]);
 assert.equal(after.hello.progress.pets.activeId,petId);
 assert.equal((await board(after)).best,8);
 assert.equal(neighbor.hello.progress.stars,0);
 assert.equal(neighbor.hello.progress.classes.delivery.reward,3);
 assert.equal(neighbor.hello.progress.pets.activeId,null);
 assert.equal((await board(neighbor)).best,null);
 console.log('PASS one disposable account sequence: existing pet + fish, true Hoops score, saved tuition debited, quoted fish sale credited, restart restores all four systems with no cross-account leakage');
}finally{Date.now=realNow;await finish();}
