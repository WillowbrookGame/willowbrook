import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp,writeFile,unlink,rmdir} from 'node:fs/promises';
import {once} from 'node:events';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {startLocalServer} from './server.mjs';
const source=resolve(process.argv[2]);
const require=createRequire(join(source,'package.json'));
const {WebSocket}=require('ws');
const root=await mkdtemp(join(tmpdir(),'willowbrook-browser-'));
await writeFile(join(root,'index.html'),'<title>Loopback preview</title>');
await writeFile(join(root,'sample.wasm'),Buffer.from([0,97,115,109]));
const server=await startLocalServer({source,port:0,webRoot:root});
const base='http://127.0.0.1:'+server.address.port;
const url=base.replace('http','ws')+'/play';
const sockets=[];
async function connect(origin=base){
 const ws=new WebSocket(url,{origin});
 sockets.push(ws);
 const queue=[];
 ws.on('message',bytes=>{queue.push(JSON.parse(bytes));if(queue.length>100)queue.shift();});
 await once(ws,'open');
 const send=m=>ws.send(JSON.stringify(m));
 const take=async check=>{
  const stop=Date.now()+3500;
  while(Date.now()<stop){
   const i=queue.findIndex(check);if(i>=0){const item=queue.splice(i,1)[0];return item;}
   await new Promise(r=>setTimeout(r,15));
  }
  throw new Error('No matching packet, queue '+JSON.stringify(queue.slice(-5)));
 };
 return {ws,send,take};
}
const pose=(zone,x=0,z=0)=>({type:'move',zone,x,y:0,z,yaw:0,moving:false,grounded:true});
try{
 assert.equal(server.address.address,'127.0.0.1');
 assert.match(await (await fetch(base+'/')).text(),/Loopback preview/);
 assert.equal((await fetch(base+'/sample.wasm',{method:'HEAD'})).headers.get('content-type'),'application/wasm');
 assert.equal((await fetch(base+'/..%2Fsecret')).status,404);
 await assert.rejects(connect('https://unrelated.invalid'),/403/);
 const wrong=await connect();wrong.send({type:'join',alias:'No',code:'000000000000'});await wrong.take(m=>m.type==='denied');
 const a=await connect(),b=await connect();
 a.send({type:'join',alias:'<b>Guest',code:server.invite});b.send({type:'join',alias:'bGuest',code:server.invite});
 const aw=await a.take(m=>m.type==='welcome'),bw=await b.take(m=>m.type==='welcome');
 assert.equal(aw.alias,'bGuest');assert.equal(bw.alias,'bGuest 2');assert.notEqual(aw.id,bw.id);
 a.send(pose('town',7));b.send(pose('town',12));
 const here=await a.take(m=>m.type==='world'&&m.players.some(p=>p.x===12));
 assert.equal(here.players[0].alias,'bGuest 2');
 b.send(pose('private',12,56));
 await a.take(m=>m.type==='world'&&m.players.length===0&&m.presence.some(p=>p.place==='In another activity'));
 const hidden=await b.take(m=>m.type==='world'&&m.zone==='private');
 assert.deepEqual(hidden.players,[]);
 b.send({type:'airHockey',action:'join'});
 assert.equal((await b.take(m=>m.type==='airHockeyError')).error,'Visit the arcade first');
 a.send(pose('arcade',0,2.3));b.send(pose('arcade',0,2.3));
 await a.take(m=>m.type==='world'&&m.zone==='arcade'&&m.players.length===1);
 a.send({type:'airHockey',action:'join'});b.send({type:'airHockey',action:'join'});
 await a.take(m=>m.type==='airHockeyFrame'&&m.frame?.encoding==='text'&&JSON.parse(m.frame.data).t==='match');
 await b.take(m=>m.type==='airHockeyFrame'&&m.frame?.encoding==='base64');
 b.send({type:'airHockey',action:'frame',frame:{encoding:'base64',data:Buffer.from([1,0,0,0,0]).toString('base64')}});
 b.send({type:'airHockey',action:'leave'});await b.take(m=>m.type==='airHockeyFrame'&&m.frame===null);
 b.send(pose('arcade',-6,-3.65));
 await a.take(m=>m.type==='world'&&m.zone==='arcade'&&m.players[0]?.x===-6);
 b.send({type:'hoops88',action:'start',requestId:'browser-test-001'});
 const hoops=await b.take(m=>m.type==='hoops88'&&m.action==='start');assert.ok(hoops.run?.id,JSON.stringify(hoops));
 b.send({type:'hoops88',action:'finish',runId:hoops.run.id,seq:0});
 const early=await b.take(m=>m.type==='hoops88'&&m.action==='finish');assert.match(early.error,/still running/);
 b.send({type:'hoops88',action:'leave'});await b.take(m=>m.type==='hoops88'&&m.run===null);
 const bye=once(b.ws,'close');b.ws.close();await bye;await a.take(m=>m.type==='world'&&m.presence.length===1);
 a.ws.close();
 if(process.argv[3]){
  const project=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
  const check=spawn(process.argv[3],['--headless','--path',project,'--script','res://game/network/browser/test_browser_adapter.gd','--',url,server.invite],{stdio:'inherit',windowsHide:true});
  const [status]=await once(check,'exit');
  assert.equal(status,0,'Godot WebSocket adapter failed');
 }
 console.log('PASS browser backend: static export, loopback, origin gate, invite, nickname, scoped/private positions, actual upstream hockey frame exchange, original Hoops run/early-finish validation, departure');
} finally {
 for(const s of sockets)s.terminate();
 await server.close();
 for(const name of ['index.html','sample.wasm'])await unlink(join(root,name));
 await rmdir(root);
}
