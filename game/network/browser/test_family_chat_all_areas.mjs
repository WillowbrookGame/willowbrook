import assert from 'node:assert/strict';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {mkdtemp,readFile,readdir,rm} from 'node:fs/promises';
import {once} from 'node:events';
import {startLocalServer} from './server.mjs';
import {selectRuntime} from './runtime_source.mjs';

const source=process.argv[2]; // Optional explicit trusted source for parity comparison only.
const {WebSocket}=(await selectRuntime(source)).webSockets();
const data=await mkdtemp(join(tmpdir(),'willowbrook-chat-fixture-'));
const seeds=[{username:'qa_chat_alpha',password:'disposable chat fixture alpha'},{username:'qa_chat_bravo',password:'disposable chat fixture bravo'}];
const logs=[], servers=[], sockets=[];
const synthetic='synthetic-chat-proof-never-save-7a37';
const deskState=s=>fetch('http://127.0.0.1:'+s.address.port+'/api/family-desk/state',{headers:{'x-willowbrook-desk':'1'}});
const t=(ms)=>new Promise(resolve=>setTimeout(resolve,ms));
const w=(s)=>s.messages.filter(m=>m.type==='chat');
const opts={source,port:0,log:x=>logs.push(x)};
async function start(extra={}) {
 const server=await startLocalServer({...opts,...extra});servers.push(server);return server;
}
async function socket(server,useOrigin=true) {
 const origin='http://127.0.0.1:'+server.address.port;
 const ws=new WebSocket(origin.replace('http','ws')+'/play',useOrigin?{origin}:{});
 sockets.push(ws);const messages=[];
 ws.on('message',body=>messages.push(JSON.parse(body)));
 await once(ws,'open');
 return {ws,messages, send:m=>ws.send(JSON.stringify(m)), take:async f=>{
  const end=Date.now()+3500;
  while(Date.now()<end) {
   const i=messages.findIndex(f);
   if(i>=0)return messages.splice(i,1)[0];
   await t(12);
  }
  throw Error('Expected synthetic server response did not arrive.');
 }};
}
const pose=zone=>({type:'move',zone,x:1,y:0,z:2,yaw:0,moving:false,grounded:true});
const say=(s,text)=>s.send({type:'chat',text});
const status=(s,available)=>s.take(m=>m.type==='chatStatus'&&m.available===available);
const expectError=(s,code)=>s.take(m=>m.type==='chatError'&&m.code===code);
const recv=(s,text)=>s.take(m=>m.type==='chat'&&m.text===text);
async function withAuth(server,packet,useOrigin=true) {
 const s=await socket(server,useOrigin);s.send(packet);
 return [s,await s.take(m=>m.type==='welcome')];
}
async function move(s,zone,available){
 s.send(pose(zone));
 await s.take(m=>m.type==='world'&&m.zone===zone&&m.chatEnabled===available);
}
try {
 await assert.rejects(start({chatEnabled:true}),/preapproved preview accounts/);
 const guest=await start();
 assert.equal((await deskState(guest)).status,404);
 const [anon,hello]=await withAuth(guest,{type:'join',code:guest.invite,alias:'Demo Visitor'},false);
 assert.equal(hello.chatEnabled,false);
 await move(anon,'town',false);say(anon,'Guest denied.');await t(90);
 assert.equal(w(anon).length,0);

 const cfg={accountsDir:data,seedAccounts:seeds};
 const off=await start(cfg);
 const [offA,offHello]=await withAuth(off,{type:'login',...seeds[0]});
 assert.equal(offHello.chatEnabled,false);
 await move(offA,'town',false);say(offA,'Must be off by default');await expectError(offA,'unavailable');
 await off.close();servers.splice(servers.indexOf(off),1);

 const s=await start({...cfg,chatEnabled:true});
 assert.equal((await deskState(s)).status,404,'Explicit game chat opt-in must not mount Parent Desk');
 const bad=await socket(s);
 say(bad,'Sign-in bypass denied.');
 await bad.take(m=>m.type==='denied');
 const [a,aw]=await withAuth(s,{type:'login',...seeds[0]});
 const [b,bw]=await withAuth(s,{type:'login',...seeds[1]});
 assert.equal(aw.chatEnabled,true);
 assert.equal(bw.chatEnabled,true);
 await move(a,'town',true);
 await move(b,'cafe',true);
 // Welcome already reports current policy. Status is a change event, not a second initial snapshot.
 assert.ok(![a,b].some(p=>p.messages.some(m=>m.type==='chatStatus')));
 // Spoofed attribution, routing, and unbounded or non-string data are rejected.
 for (const payload of [
  {type:'chat',text:'spoofed name',from:'qa_chat_bravo'},
  {type:'chat',text:'unexpected channel',zone:'beach'},
  {type:'chat',text:'unexpected recipient',to:'qa_chat_bravo'},
  {type:'chat',text:{text:'wrong type'}},{type:'chat',text:null},
  {type:'chat',text:'\u0001\u202E \u2028 '},{type:'chat',text:'\u{1f680}'.repeat(161)},
  {type:'chat',text:'a'.repeat(641)}
 ]) {a.send(payload);await expectError(a,'invalid');}
 assert.equal(w(b).length,0);
 const file=join(data,'preview-accounts-v1.json');
 const before=await readFile(file);
 say(a,'  '+synthetic+'\u0007\u202E\u2028 stay-text <em>only</em>  ');
 const clean=synthetic+'  stay-text <em>only</em>';
 assert.deepEqual(await recv(b,clean),{type:'chat',from:'qa_chat_alpha',text:clean});
 assert.deepEqual(await recv(a,clean),{type:'chat',from:'qa_chat_alpha',text:clean});
 assert.deepEqual(await readFile(file),before,'message must not change save bytes');
 say(a,'Rate limited.');await expectError(a,'rate');
 const bye=once(a.ws,'close');a.ws.close();await bye;
 const [resumed]=await withAuth(s,{type:'resume',session:aw.session});
 await move(resumed,'town',true);
 say(resumed,'Still rate limited after reconnect.');await expectError(resumed,'rate');
 assert.equal(w(b).length,0);
 // Rate is independent per approved account. Exact 160 Unicode code points survive.
 const boundary='\u{1F680}'.repeat(160);say(b,boundary);
 assert.equal((await recv(resumed,boundary)).from,'qa_chat_bravo');await recv(b,boundary);
 await move(b,'beach',true);
 await t(2050);
 say(b,'Beach reaches town');await recv(b,'Beach reaches town');await recv(resumed,'Beach reaches town');
 await move(b,'private',true);
 say(resumed,'Private receives without zone leakage');
 assert.deepEqual(await recv(b,'Private receives without zone leakage'),{type:'chat',from:'qa_chat_alpha',text:'Private receives without zone leakage'});
 await move(b,'library',true);
 s.disableFamilyChat();await status(b,false);await status(resumed,false);
 say(resumed,'No chat after kill');await expectError(resumed,'unavailable');
 assert.equal(w(b).length,0);
 for(const n of await readdir(data,{recursive:true,withFileTypes:true}))if(n.isFile()){
  const body=await readFile(join(n.parentPath,n.name));assert(!body.includes(synthetic),'No message text in auth store or backup');
 }
 assert(!JSON.stringify(logs).includes(synthetic),'No chat content in server logs');
 console.log('Passed: default off, non-account opt-in denied, unauthenticated/guest denied, two approved accounts, Town/interior route, cross-zone Beach/private chat without location leakage, spoofed routing/authorship denied, Unicode and size, reconnect rate, runtime kill, unchanged message save bytes/no logs.');
} finally {
 for(const q of sockets)if(q.readyState!==WebSocket.CLOSED)q.terminate();
 try{for(const server of [...servers].reverse())await server.close();}
 finally{await rm(data,{recursive:true,force:true});}
}

