// SPDX-License-Identifier: MIT
// Requires the existing Web export and a disposable test certificate matching
// DNS:willowbrook.test. Trusts only that certificate in these fixture clients.
import assert from 'node:assert/strict';
import { createServer as tlsServer, request as tlsRequest } from 'node:https';
import { request as httpRequest } from 'node:http';
import { randomBytes } from 'node:crypto';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { resolve,join } from 'node:path';
import { tmpdir } from 'node:os';
import { startLocalServer } from '../paintball_prototype/network/browser/server.mjs';
import { privateHttpsSite, requestMatchesSite } from '../paintball_prototype/network/browser/https_site_policy.mjs';
import { openPreviewAccounts } from '../paintball_prototype/network/browser/preview_accounts.mjs';
import { createFamilyDesk } from '../paintball_prototype/network/browser/family_desk_preview.mjs';
import * as store from '../paintball_prototype/network/browser/standalone-runtime/world-store.mjs';
import { selectRuntime } from '../paintball_prototype/network/browser/runtime_source.mjs';

const webRoot=resolve(process.argv[2]),cert=await readFile(process.argv[3]),key=await readFile(process.argv[4]);
const workerPath=process.argv[5];
const paintballOptions=workerPath?{enablePaintballLobbyTransport:true,paintballWorker:{
 exe:process.argv[6]?resolve(process.argv[6]):resolve(workerPath,'godot-paintball-stdio'),project:process.argv[6]?resolve(workerPath):resolve(workerPath,'project')
}}:{};
const runtime=await selectRuntime();const source=runtime.root;const {WebSocket}=runtime.webSockets();
const state=await mkdtemp(join(tmpdir(),'willowbrook-family-desk-'));
const marker=join(state,'.willowbrook-family-desk-opt-in');
const hostname='willowbrook.test';
const alias=label=>({username:'stub_'+label,password:randomBytes(25).toString('base64url')});
const owner=alias('owner'),seeds=[alias('first'),alias('second')];
const sockets=new Set();
let backend,edge;
let origin,host;
const send=(ws,m)=>ws.send(JSON.stringify(m));
function relay(req){
 return httpRequest({host:'127.0.0.1',port:backend.address.port,path:req.url,method:req.method,headers:req.headers});
}
function makeEdge(){
 const server=tlsServer({cert,key},(req,res)=>{
  const out=relay(req);out.on('response',r=>{res.writeHead(r.statusCode,r.headers);r.pipe(res)});out.on('error',()=>res.destroy());req.pipe(out);
 });
 server.on('connection',s=>{sockets.add(s);s.once('close',()=>sockets.delete(s));});
 server.on('upgrade',(req,front,head)=>{
  const out=relay(req);
  out.on('response',r=>{r.resume();front.end('HTTP/1.1 '+r.statusCode+' Forbidden\r\nConnection: close\r\n\r\n');});
  out.on('error',()=>front.destroy());
  out.on('upgrade',(r,back,extra)=>{
   const lines=[];for(let i=0;i<r.rawHeaders.length;i+=2)lines.push(r.rawHeaders[i]+': '+r.rawHeaders[i+1]);
   front.write('HTTP/1.1 101 Switching Protocols\r\n'+lines.join('\r\n')+'\r\n\r\n');
   if(extra.length)front.write(extra);if(head.length)back.write(head);
   front.on('close',()=>back.destroy());back.on('close',()=>front.destroy());front.on('error',()=>back.destroy());back.on('error',()=>front.destroy());
   front.pipe(back);back.pipe(front);
  });out.end();
 });
 return server;
}
function req(method,path,body){
 const pay=body===undefined?undefined:JSON.stringify(body);
 return new Promise((ok,no)=>{
  const r=tlsRequest({host:'127.0.0.1',port:edge.address().port,servername:hostname,ca:cert,path,method,
   headers:{Host:host,Origin:origin,'X-Willowbrook-Desk':'1','Sec-Fetch-Site':'same-origin',...(pay?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(pay)}:{})}},res=>{const chunks=[];res.on('data',d=>chunks.push(d));res.on('end',()=>ok({status:res.statusCode,headers:res.headers,body:Buffer.concat(chunks)}));});
  r.on('error',no);r.end(pay);
 });
}
function player(seed,localAddress){
 return new Promise((ok,no)=>{
  const ws=new WebSocket('wss://127.0.0.1:'+edge.address().port+'/play',{headers:{Host:host},origin,servername:hostname,ca:cert,localAddress});
  const frames=[];
  ws.on('message',d=>frames.push(JSON.parse(d)));
  ws.once('error',no);
  ws.once('open',()=>{send(ws,{type:'login',...seed});ok({ws,frames});});
 });
}
async function wait(f){
 const deadline=Date.now()+8000;
 do{const result=f();if(result)return result;await new Promise(r=>setTimeout(r,30));}while(Date.now()<deadline);
 throw new Error('Fixture expected game packet not received.');
}
try{
 edge=makeEdge();await new Promise((ok,no)=>{edge.once('error',no);edge.listen(0,'127.0.0.1',ok);});
 host=hostname+':'+edge.address().port;origin='https://'+host;
 const site=privateHttpsSite(origin),sample={socket:{remoteAddress:'127.0.0.1'},rawHeaders:['Host',host,'Origin',origin]};
 assert.equal(requestMatchesSite(sample,site,true),true);
 for(const sampleOrigin of ['http://'+host,origin+'/',origin+'?x','https://user@'+host,'https://127.0.0.1'])assert.throws(()=>privateHttpsSite(sampleOrigin));
 assert.equal(requestMatchesSite({...sample,rawHeaders:['Host',host]},site,true),false);
 assert.equal(requestMatchesSite({...sample,rawHeaders:[...sample.rawHeaders,'X-Forwarded-Proto','https']},site),false);
 await writeFile(marker,'willowbrook-local-family-desk-v1\n',{mode:0o600});
 const a=await openPreviewAccounts({accountsDir:state,source,site:webRoot,makeStore:store.makeStore,seeds,allowEmpty:true,parentDeskEnabled:true});
 createFamilyDesk({accounts:a,accountFile:a.accountFile,makeStore:store.makeStore,characters:store.characters}).bootstrapOwner(owner.username,owner.password);
 backend=await startLocalServer({port:0,webRoot,accountsDir:state,parentDeskFile:marker,privateHttpsOrigin:origin,...paintballOptions});
 const login=await req('POST','/api/family-desk/login',owner);
 assert.equal(login.status,200);
 assert.equal(JSON.parse(login.body).role,'owner');
 const cookie=login.headers['set-cookie'][0];
 assert.match(cookie,/^__Secure-willowbrook_desk=/);assert.match(cookie,/; Secure/);assert.match(cookie,/; HttpOnly/);assert.match(cookie,/SameSite=Strict/);
 assert.equal((await req('GET','/index.html')).status,200);
 const clients=await Promise.all([player(seeds[0],'127.0.0.1'),player(seeds[1],'127.0.0.2')]);
 for(let i=0;i<clients.length;i++){
  const c=clients[i];assert.equal((await wait(()=>c.frames.find(m=>m.type==='welcome'))).alias,seeds[i].username);
  send(c.ws,{type:'move',zone:'town',x:i,y:0,z:0,yaw:0,grounded:true});
 }
 for(let i=0;i<clients.length;i++)await wait(()=>clients[i].frames.some(m=>m.type==='world'&&m.players?.some(q=>q.alias===seeds[1-i].username)));
 if(workerPath){
  const [first,second]=clients;
  const waitFor=(client,pred)=>wait(()=>{
   const at=client.frames.findIndex(pred);
   return at<0?null:client.frames.splice(at,1)[0];
  });
  const lobby=(c,action,fields={})=>send(c.ws,{type:'paintballLobby',action,...fields});
  const lobbyAck=(c,action)=>waitFor(c,m=>m.type==='paintballLobby'&&m.action===action);
  const match=(c,action,epoch,fields={})=>send(c.ws,{type:'paintballMatch',action,epoch,...fields});
  const matchAck=(c,action)=>waitFor(c,m=>m.type==='paintballMatch'&&m.action===action);
  for(const c of clients)await waitFor(c,m=>m.type==='paintballCapability'&&m.available);
  for(const c of clients){
   send(c.ws,{type:'move',zone:'town',x:36,y:0,z:-44.7,yaw:0,moving:false,grounded:true});
   // A fresh Town snapshot ensures the new presence has crossed the server tick.
   c.frames.length=0;
  }
  for(const c of clients)await waitFor(c,m=>m.type==='world'&&m.zone==='town');
  lobby(first,'join');assert.equal((await lobbyAck(first,'join')).ok,true);
  lobby(first,'ready',{ready:true});assert.equal((await lobbyAck(first,'ready')).ok,true);
  assert(!first.frames.some(m=>m.type==='paintballMatch'&&m.action==='enter'));
  lobby(second,'join');const joined=await lobbyAck(second,'join');
  assert.equal(joined.ok,true);
  assert.deepEqual(joined.room.humans.map(x=>x.ready),[true,false]);
  lobby(second,'ready',{ready:true});assert.equal((await lobbyAck(second,'ready')).ok,true);
  const [a,b]=await Promise.all(clients.map(c=>matchAck(c,'enter')));
  assert.equal(a.epoch,b.epoch);assert.notEqual(a.selfSlot,b.selfSlot);
  for(const c of clients){match(c,'ready',a.epoch);assert.equal((await matchAck(c,'ready')).ok,true);}
  match(first,'view',a.epoch);
  const active=await matchAck(first,'view');
  assert.equal(active.view.phase,'playing');
  assert.equal(active.view.players.filter(p=>p.bot).length,2);
  const frame={sequence:1,x:.9,z:0,yaw:0,pitch:0,jump:false,paint:false};
  match(first,'input',a.epoch,{frame});assert.equal((await matchAck(first,'input')).ok,true);
  match(first,'input',a.epoch,{frame});assert.equal((await matchAck(first,'input')).ok,false);
  console.log('PASS trusted TLS two-account shared lobby, host-first Ready preserved, authoritative game and stale-input guard, two bots.');
 }
 for(const c of clients)c.ws.close();
 console.log('PASS private HTTPS owner Secure cookie + two independent trusted TLS clients from 127.0.0.1 and 127.0.0.2 see one another; synthetic loopback only.');
} finally {
 for(const socket of sockets)socket.destroy();
 if(edge)await new Promise(r=>edge.close(r));
 if(backend)await backend.close();
 await rm(state,{recursive:true,force:true});
}
