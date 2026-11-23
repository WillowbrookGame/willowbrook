
import assert from 'node:assert/strict';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {once} from 'node:events';
import {createRequire} from 'node:module';
import {startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]);
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-scavenger-wire-'));
const webRoot=await mkdtemp(join(tmpdir(),'willowbrook-scavenger-static-'));
await writeFile(join(webRoot,'index.html'),'<title>Disposable hunt</title>');
const seedAccounts=['test_hunter','test_watcher'].map(username=>({username,password:'disposable hunt socket fixture'}));
const server=await startLocalServer({source,accountsDir,seedAccounts,webRoot,port:0});
const socks=[];
const nap=ms=>new Promise(r=>setTimeout(r,ms));
async function client(seed){
 const host='127.0.0.1:'+server.address.port;
 const ws=new WebSocket('ws://'+host+'/play',{origin:'http://'+host});
 socks.push(ws);
 const received=[];
 ws.on('message',m=>received.push(JSON.parse(m)));
 await once(ws,'open');
 const send=m=>ws.send(JSON.stringify(m));
 const take=async fn=>{
  const until=Date.now()+3500;
  while(Date.now()<until){
   const i=received.findIndex(fn);
   if(i>=0)return received.splice(i,1)[0];
   await nap(10);
  }
  throw Error('Expected socket response not received');
 };
 send({type:'login',...seed});
 const welcome=await take(m=>m.type==='welcome');
 return {send,take,welcome,received};
}
const progress=m=>m.type==='progress'&&m.action==='scavenger';
const pose=(zone,x,z)=>({type:'move',zone,x,z,y:0,yaw:0,moving:false,grounded:true});
try{
 const a=await client(seedAccounts[0]),b=await client(seedAccounts[1]);
 assert.deepEqual(b.welcome.progress.scavenger.placements,[]);
 a.send(pose('town',24,-26));b.send(pose('town',23,-26));
 await b.take(m=>m.type==='world'&&m.players.some(r=>r.alias===seedAccounts[0].username));
 a.send({type:'progress',action:'scavenger',operation:'start',requestId:'first-run-wire-test',runId:null});
 const opened=await a.take(progress);
 assert.equal(opened.ok,true);
 assert.equal(opened.scavenger.placements.length,8);
 assert.ok(b.received.filter(m=>m.type==='world').every(m=>!m.scavenger&&m.players.every(r=>!r.placements)));
 b.send({type:'progress',action:'scavenger',operation:'collect',item:opened.scavenger.placements[0].id,runId:opened.scavenger.runId});
 const foreign=await b.take(progress);
 assert.equal(foreign.ok,false);
 assert.deepEqual(foreign.scavenger.placements,[]);
 for(const mark of opened.scavenger.placements){
  await nap(50);
  a.send(pose(mark.zone,mark.x,mark.z));
  a.send({type:'progress',action:'scavenger',operation:'collect',item:mark.id,runId:opened.scavenger.runId});
  const found=await a.take(progress);
  assert.equal(found.ok,true,found.text);
 }
 const shared=await b.take(m=>m.type==='scavengerLeaderboard');
 assert.equal(shared.rows.length,1);
 assert.equal(shared.rows[0].displayName,seedAccounts[0].username);
 assert.deepEqual(Object.keys(shared.rows[0]).sort(),['displayName','durationMs','rank']);
 assert.ok(shared.rows[0].durationMs>0);
 console.log('PASS preview hunt WebSocket: personal placements and collection, public alias/time leaderboard only.');
}finally{
 for(const ws of socks)ws.terminate();
 await server.close();
}

