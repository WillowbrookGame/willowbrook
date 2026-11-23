import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createRequire} from 'node:module';
import {startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]), {WebSocket}=createRequire(join(source,'package.json'))('ws');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
for(const enablePaintballLobbyTransport of [false,true]){
 const data=await mkdtemp(join(tmpdir(),'willowbrook-no-worker-fixture-'));
 const user={username:'qa_solo_only',password:'synthetic B8 fail closed'};
 const server=await startLocalServer({source,port:0,accountsDir:data,enableHomeVisits:true,enablePaintballLobbyTransport,seedAccounts:[user]});
 const url='127.0.0.1:'+server.address.port;
 const ws=new WebSocket('ws://'+url+'/play',{origin:'http://'+url});const inbox=[];
 ws.on('message',b=>inbox.push(JSON.parse(b)));
 const send=m=>ws.send(JSON.stringify(m));
 async function until(f){let n=Date.now()+4000;while(Date.now()<n){const m=inbox.find(f);if(m)return m;await wait(20);}throw Error('Expected fixture message missing');}
 try{
  await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j);});
  send({type:'login',...user});assert.equal((await until(m=>m.type==='welcome')).homeVisits,true);
  send({type:'move',zone:'town',x:36,y:0,z:-45,yaw:0,grounded:true});
  const town=await until(m=>m.type==='world'&&m.zone==='town');
  assert.ok(town.vehicles&&town.yards&&town.homeExteriors);
  if(enablePaintballLobbyTransport)assert.equal((await until(m=>m.type==='paintballCapability')).available,false);
  else await wait(240);
  assert.ok(!inbox.some(m=>m.type==='paintballCapability'&&m.available===true));
  assert.ok(!inbox.some(m=>m.type==='world'&&(m.paintball||m.homeScene)));
  console.log('PASS B8 solo path eligibility: '+(enablePaintballLobbyTransport?'opt-in without worker advertises multiplayer unavailable':'default app never advertises multiplayer')+'; Town home/yard/vehicle views preserved.');
 }finally{ws.terminate();await server.close();await rm(data,{recursive:true,force:true});}
}
