
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {tmpdir} from 'node:os';
import {mkdtemp} from 'node:fs/promises';
import {once} from 'node:events';
import {environmentAt,startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]);
const {environmentAt:legacy}=await import(pathToFileURL(join(source,'multiplayer.mjs')).href);
for(const time of [-1200001,-1,0,299999,300000,599999,600000,899999,900000,1199999,1200000,Date.now()]){
 assert.deepEqual(environmentAt(time),legacy(time));
}
const {WebSocket}=createRequire(join(source,'package.json'))('ws');
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-weather-qa-'));
const seedAccounts=[{username:'qa_sky_one',password:'fixture-sky-only-a'},{username:'qa_sky_two',password:'fixture-sky-only-b'}];
const realNow=Date.now;
let clock=realNow()-realNow()%3600000+10000,server;
Date.now=()=>clock;
const opts={source,port:0,accountsDir,seedAccounts};
const begin=async(options=opts)=>{server=await startLocalServer(options)};
const close=async()=>{const old=server;server=null;await old?.close()};
async function connect(auth){
 const origin='http://127.0.0.1:'+server.address.port;
 const ws=new WebSocket(origin.replace('http','ws')+'/play',{origin:auth?origin:''});
 const queue=[];
 ws.on('message',data=>{queue.push(JSON.parse(data));if(queue.length>75)queue.shift()});
 await once(ws,'open');
 const send=m=>ws.send(JSON.stringify(m));
 const take=async pred=>{
  const stop=realNow()+4000;
  do{
   const i=queue.findIndex(pred);if(i>=0)return queue.splice(i,1)[0];
   await new Promise(r=>setTimeout(r,10));
  }while(realNow()<stop);
  throw Error('Expected weather snapshot not received');
 };
 send(auth?{type:'login',...auth}:{type:'join',alias:'Guest Sky',code:server.invite});
 await take(m=>m.type==='welcome');
 const move=zone=>send({type:'move',zone,x:0,y:0,z:0,yaw:0,moving:false,grounded:true});
 move('town');
 return {move,take};
}
try{
 await begin({...opts,enableWeather:true});
 const a=await connect(seedAccounts[0]),b=await connect(seedAccounts[1]);
 for(const kind of ['sunny','cloudy','rain']){
  const ws=await Promise.all([a,b].map(c=>c.take(m=>m.type==='world'&&m.environment?.weather===kind)));
  assert.deepEqual(ws[0].environment,ws[1].environment);
  assert.deepEqual(ws[0].environment,legacy(clock));
  if(kind!=='rain')clock+=300000;
 }
 for(const zone of ['beach','vet','private']){
  b.move(zone);
  assert.equal((await b.take(m=>m.type==='world'&&m.zone===zone)).environment,undefined);
 }
 await close();
 await begin();
 const defaultOff=await connect(seedAccounts[0]);
 assert.equal((await defaultOff.take(m=>m.type==='world'&&m.zone==='town')).environment,undefined);
 await close();
 await begin({source,port:0,enableWeather:true});
 const guest=await connect(null);
 assert.equal((await guest.take(m=>m.type==='world'&&m.zone==='town')).environment,undefined);
 console.log('PASS exact legacy UTC phase and weather edges, synchronized Town across two account sockets, no weather off-Town, guest, or without explicit opt-in');
}finally{Date.now=realNow;await close();}

