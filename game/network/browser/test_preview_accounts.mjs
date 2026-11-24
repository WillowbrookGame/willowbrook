
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp,writeFile} from 'node:fs/promises';
import {once} from 'node:events';
import {startLocalServer} from './server.mjs';

const source=resolve(process.argv[2]);
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const scratch=await mkdtemp(join(tmpdir(),'willowbrook-disposable-accounts-'));
const webRoot=await mkdtemp(join(tmpdir(),'willowbrook-disposable-web-'));
const seeds=[{username:'qa_alder',password:'disposable fixture alpha'},{username:'qa_birch',password:'disposable fixture bravo'}];
const options={source,webRoot,accountsDir:scratch,port:0};
const logs=[];
await writeFile(join(webRoot,'index.html'),'<title>Disposable preview</title>');
let server=await startLocalServer({...options,seedAccounts:seeds,log:r=>logs.push(r)});
const sockets=[];
const base=()=> 'http://127.0.0.1:'+server.address.port;
async function connect(origin=base()){
 const ws=new WebSocket(base().replace('http','ws')+'/play',origin?{origin}:{});
 sockets.push(ws);
 const messages=[];
 ws.on('message',body=>messages.push(JSON.parse(body)));
 await once(ws,'open');
 return {
  ws,
  send:m=>ws.send(JSON.stringify(m)),
  take:async filter=>{
   const expires=Date.now()+4000;
   while(Date.now()<expires){
    const i=messages.findIndex(filter);
    if(i!==-1)return messages.splice(i,1)[0];
    await new Promise(r=>setTimeout(r,15));
   }
   throw Error('Expected response did not arrive');
  },
 };
}
const pose=(zone,x=0,z=0)=>({type:'move',zone,x,y:0,z,yaw:0,moving:false,grounded:true});
const tend={type:'progress',action:'tendGarden'};
async function login(seed){
 const socket=await connect();
 socket.send({type:'login',...seed});
 return [socket,await socket.take(m=>m.type==='welcome')];
}
try{
 assert.equal(server.address.address,'127.0.0.1');
 assert.equal((await fetch(base()+'/preview-accounts-v1.json')).status,404);
 await assert.rejects(connect('https://unrelated.invalid'),/403/);
 await assert.rejects(connect(null),/403/);
 const denied=await connect();denied.send(tend);
 assert.equal((await denied.take(m=>m.type==='denied')).error,'Sign in to play online.');
 const wrong=await connect();wrong.send({type:'login',username:seeds[0].username,password:'not the correct password'});
 assert.match((await wrong.take(m=>m.type==='denied')).error,/incorrect/);
 const [a,aw]=await login(seeds[0]),[b,bw]=await login(seeds[1]);
 assert.notEqual(aw.id,bw.id);
 assert.notEqual(aw.session,bw.session);
 assert.deepEqual(Object.keys(aw.progress).sort(),['gardenLastTendedAt','jobs','scavenger','scavengerLeaderboard','serverTime','stars']);
 assert.equal(aw.alias,seeds[0].username);
 assert.equal(aw.progress.stars,0);
 assert.equal(bw.progress.stars,0);
 a.send(pose('town',0,4));b.send(pose('town',3,4));
 const world=await a.take(m=>m.type==='world'&&m.players.some(q=>q.id===bw.id));
 assert.ok(world.players.every(q=>!('session'in q)&&!('stars'in q)));
 b.send(pose('beach',3,4));
 await a.take(m=>m.type==='world'&&!m.players.some(q=>q.id===bw.id)&&m.presence.some(q=>q.place==='At the beach'));
 a.send(tend);
 assert.equal((await a.take(m=>m.type==='progress')).ok,false);
 // Client-supplied reward, identity, and position are never accepted as mutation fields.
 a.send({...tend,stars:999,x:20,z:49,accountId:bw.id});
 assert.equal((await a.take(m=>m.type==='progress')).stars,0);
 a.send(pose('town',20,49));
 a.send(tend);
 const saved=await a.take(m=>m.type==='progress'&&m.ok);
 assert.equal(saved.stars,2);
 a.send(tend);
 let repeated=await a.take(m=>m.type==='progress');
 assert.equal(repeated.ok,false);
 assert.equal(repeated.stars,2);
 assert.match(repeated.error,/resting/i);
 const disconnect=once(b.ws,'close');b.ws.close();await disconnect;
 await a.take(m=>m.type==='world'&&m.presence.length===1);
 const reload=await connect();reload.send({type:'resume',session:aw.session});
 const replay=await reload.take(m=>m.type==='welcome');
 assert.equal(replay.id,aw.id);
 assert.equal(replay.progress.stars,2);
 assert.equal(replay.progress.gardenLastTendedAt,saved.gardenLastTendedAt);
 await a.take(m=>m.type==='denied');
 await server.close();
 server=await startLocalServer(options);
 const resumed=await connect();resumed.send({type:'resume',session:aw.session});
 const loaded=await resumed.take(m=>m.type==='welcome');
 assert.equal(loaded.id,aw.id);
 assert.equal(loaded.progress.stars,2);
 resumed.send(pose('town',20,49));resumed.send(tend);
 repeated=await resumed.take(m=>m.type==='progress');
 assert.equal(repeated.ok,false);
 assert.equal(repeated.stars,2);
 const signout=once(resumed.ws,'close');resumed.send({type:'logout'});await signout;
 const retired=await connect();retired.send({type:'resume',session:aw.session});
 assert.match((await retired.take(m=>m.type==='denied')).error,/sign in again/i);
 const [,fresh]=await login(seeds[0]);
 assert.equal(fresh.progress.stars,2);
 const [jobsPlayer,unchanged]=await login(seeds[1]);
 assert.equal(unchanged.progress.stars,0);
 assert.equal(unchanged.progress.gardenLastTendedAt,null);
 const cafe=unchanged.progress.jobs.available.find(m=>m.kind==='starter'&&m.job==='cafe');
 assert.equal(cafe.zone,'cafe');
 const stay=at=>setInterval(()=>jobsPlayer.send(pose(at.zone,at.x,at.z)),150);
 const jobInteract=()=>jobsPlayer.send({type:'progress',action:'jobs',operation:'interact',job:'cafe'});
 const complete=async at=>{
  await new Promise(resolve=>setTimeout(resolve,55));
  jobsPlayer.send(pose(at.zone,at.x,at.z));
  jobInteract();
  const timer=stay(at);
  try{
   const started=await jobsPlayer.take(m=>m.type==='progress'&&m.action==='jobs'&&m.operation==='interact');
   assert.equal(started.ok,true,started.text);
   return await jobsPlayer.take(m=>m.type==='progress'&&m.action==='jobs'&&m.operation==='finish');
  }finally{clearInterval(timer);}
 };
 const step=await complete(cafe);
 assert.equal(step.stars,0);
 const done=await complete(step.jobs.current);
 assert.equal(done.stars,1);
 assert.equal(done.jobs.current,null);
 assert.deepEqual(done.jobs.completed,['cafe']);

 assert.ok(logs.every(r=>!('invite'in r)&&!('session'in r)&&!('username'in r)&&!('password'in r)));
 await assert.rejects(startLocalServer({...options,port:24862}),/separate port/);
 await assert.rejects(startLocalServer({...options,accountsDir:source}),/outside/);
 console.log('PASS: isolated disposable accounts, origin gate, anonymous denial, secret-free presence, shared/private map visibility, isolated server-calculated garden reward, duplicate rejection, reload/restart progress, and logout revocation.');
}finally{
 for(const ws of sockets)ws.terminate();
 await server.close();
}

