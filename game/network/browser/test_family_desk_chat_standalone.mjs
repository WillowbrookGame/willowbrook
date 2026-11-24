import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,readFileSync,unlinkSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomBytes} from 'node:crypto';
import {request} from 'node:http';
import {startLocalServer} from './server.mjs';
import {createFamilyDesk} from './family_desk_preview.mjs';
import {openPreviewAccounts} from './preview_accounts.mjs';

import {selectRuntime} from './runtime_source.mjs';

const runtime=await selectRuntime();
const {WebSocket}=runtime.webSockets();
const {makeStore,characters}=await runtime.load('world-store.mjs');
const dir=mkdtempSync(join(tmpdir(),'willowbrook-family-desk-owner-chat-test-'));
const marker=join(dir,'.willowbrook-family-desk-opt-in'),file=join(dir,'preview-accounts-v1.json');
const password=()=>randomBytes(24).toString('base64url');
const passwords=[password(),password(),password(),password(),password()];
let svc;
const clients=new Set();
let count=0;
const check=async(label,fn)=>{await fn();count++;console.log('PASS '+label);};
const own=()=>JSON.parse(readFileSync(file,'utf8'));
const start=async chatEnabled=>await startLocalServer({port:0,accountsDir:dir,parentDeskFile:marker,chatEnabled});
const base=()=>`http://127.0.0.1:${svc.address.port}`;
const call=async(route,data=null,auth={},options={})=>{
 const headers={'x-willowbrook-desk':'1',...(data===null?{}:{'Content-Type':'application/json',Origin:base()}),...(auth.cookie?{cookie:auth.cookie,'x-willowbrook-csrf':auth.csrf}:{}),...options};
 const r=await fetch(base()+'/api/family-desk/'+route,{method:data===null?'GET':'POST',headers,body:data===null?undefined:JSON.stringify(data)});
 return {status:r.status,p:await r.json(),cookie:r.headers.get('set-cookie')?.split(';')[0],cache:r.headers.get('cache-control')};
};
const login=async(username,password)=>{
 const r=await call('login',{username,password});assert.equal(r.status,200);assert.equal(r.cache,'no-store');return {cookie:r.cookie,csrf:r.p.csrf};
};
const ws=async(username,password,scheme=true)=>{
 const player=new WebSocket(base().replace('http','ws')+'/play',{origin:base()});clients.add(player);
 const rows=[];
 player.on('message',val=>rows.push(JSON.parse(val)));
 await new Promise((ok,no)=>{player.once('open',ok);player.once('error',no);});
 const send=m=>player.send(JSON.stringify(m));
 const take=async fn=>{
  for(let i=0;i<200;i++){
   const match=rows.findIndex(fn);
   if(match>=0)return rows.splice(match,1)[0];
   await new Promise(ok=>setTimeout(ok,10));
  }
  throw Error('Expected game packet did not arrive.');
 };
 send({type:'login',username,password});const initial=await take(m=>m.type==='welcome');assert.equal(initial.chatEnabled,scheme);
 return {send,take,rows,player};
};
const move=(p,zone)=>p.send({type:'move',zone,x:0,y:0,z:0,yaw:0,grounded:true,moving:false});
const wsStatus=(p,yes)=>p.take(m=>m.type==='chatStatus'&&m.available===yes);
const settings=(enabled,auth,headers={})=>call('global-chat',{enabled},auth,headers);
try{
 writeFileSync(marker,'willowbrook-local-family-desk-v1\n',{mode:0o600,flag:'wx'});
 const acc=await openPreviewAccounts({accountsDir:dir,source:runtime.root,site:null,makeStore,allowEmpty:true,parentDeskEnabled:true});
 const desk=createFamilyDesk({accounts:acc,accountFile:file,makeStore,characters});
 desk.bootstrapOwner('probe_owner',passwords[0]);
 let actor=desk.login('probe_owner',passwords[0]).actor;
 for(const [name,pass] of [['probe_parent',passwords[1]],['other_parent',passwords[4]]]){
  const i=desk.action('invite-parent',actor,{username:name});
  desk.action('redeem-parent',null,{code:i.code,password:pass});
 }
 actor=desk.login('probe_parent',passwords[1]).actor;
 const child=desk.action('create-player',actor,{nickname:'probe_child',avatar:'male-a',password:passwords[2]}).player;
 actor=desk.login('other_parent',passwords[4]).actor;
 const other=desk.action('create-player',actor,{nickname:'other_child',avatar:'male-a',password:passwords[3]}).player;
 // Historical v1 compatibility, seeded fixture only.
 const legacy=own();assert.equal(legacy.familyDesk.version,1);assert.ok(!Object.hasOwn(legacy,'familyChatPolicy'));
 writeFileSync(file,JSON.stringify(legacy),{mode:0o600});
 svc=await start(true);
 let owner=await login('probe_owner',passwords[0]);
 const parent=await login('probe_parent',passwords[1]),otherParent=await login('other_parent',passwords[4]);
 await check('legacy v1 launch authority still on; new children still off',async()=>{
  assert.equal((await call('state',null,owner)).p.globalChat.enabled,true);
  assert.equal((await call('state',null,parent)).p.players[0].chatEnabled,false);
 });
 await check('owner-only mutation and strict same-origin/CSRF/boolean payload',async()=>{
  assert.equal((await settings(false,{})).status,401);
  assert.equal((await settings(false,parent)).status,403);
  assert.equal((await settings(false,otherParent)).status,403);
  assert.equal((await settings(false,owner,{Origin:'http://localhost:'+svc.address.port})).status,403);
  assert.equal((await settings(false,owner,{'x-willowbrook-csrf':'mismatch'})).status,403);
  assert.equal((await settings(false,owner,{'x-forwarded-host':'127.0.0.1'})).status,403);
  for(const body of [{enabled:0},{enabled:false,role:'owner'},{}])assert.equal((await call('global-chat',body,owner)).status,400);
  assert.equal(own().familyDesk.version,1);
 });
 assert.equal((await call('player-permissions',{id:child.id,chatEnabled:true},parent)).status,200);
 assert.equal((await call('player-permissions',{id:other.id,chatEnabled:true},otherParent)).status,200);
 const a=await ws('probe_child',passwords[2]),b=await ws('other_child',passwords[3]);
 move(a,'town');move(b,'beach');
 const sample='synthetic chat '+randomBytes(5).toString('hex');a.send({type:'chat',text:sample});
 await b.take(m=>m.type==='chat'&&m.text===sample);await a.take(m=>m.type==='chat'&&m.text===sample);
 await check('injected write failure leaves policy on, preferences/disk unchanged',async()=>{
  const before=readFileSync(file);
  writeFileSync(file+'.tmp','test collision',{flag:'wx'});
  try{
   assert.equal((await settings(false,owner)).status,503);
   assert.equal((await call('state',null,owner)).p.globalChat.enabled,true);
   assert.deepEqual(readFileSync(file),before);
   await a.take(m=>m.type==='world'&&m.chatEnabled===true);
  }finally{unlinkSync(file+'.tmp');}
 });
 await check('owner turns off both live players immediately, blocks both sending and receiving',async()=>{
  const r=await settings(false,owner);assert.equal(r.status,200);assert.deepEqual(r.p.globalChat,{enabled:false,canEnable:true});
  await Promise.all([wsStatus(a,false),wsStatus(b,false)]);
  a.send({type:'chat',text:'must not deliver'});
  await a.take(m=>m.type==='chatError'&&m.code==='unavailable');
  await b.take(m=>m.type==='world'&&m.chatEnabled===false);
  assert.ok(!b.rows.some(r=>r.type==='chat'&&r.text==='must not deliver'));
  const state=own();assert.deepEqual(state.familyChatPolicy,{version:1,enabled:false});
  assert.equal(state.familyDesk.version,1);assert.ok(!Object.hasOwn(state.familyDesk,'globalChatEnabled'));
  assert.equal(state.familyDesk.children[child.id].chatEnabled,true);
  assert.equal(state.familyDesk.children[other.id].chatEnabled,true);
  assert.ok(!JSON.stringify(state).includes(sample));
 });
 await check('in-flight prior login cannot change global settings after same-owner replacement',async()=>{
  const text='{"enabled":true}';
  const req=request(base()+'/api/family-desk/global-chat',{method:'POST',headers:{'Content-Length':text.length,'Content-Type':'application/json',Origin:base(),'x-willowbrook-desk':'1',cookie:owner.cookie,'x-willowbrook-csrf':owner.csrf}});
  const answer=new Promise((ok,no)=>{req.once('response',r=>{r.resume();ok(r.statusCode);});req.once('error',no);});
  req.write(text.slice(0,6));
  await new Promise(ok=>setTimeout(ok,70));
  owner=await login('probe_owner',passwords[0]);
  req.end(text.slice(6));
  assert.equal(await answer,401);
  assert.equal(own().familyChatPolicy.enabled,false);
 });
 await check('restart keeps global off; re-enable preserves household override',async()=>{
  await svc.close();svc=await start(true);owner=await login('probe_owner',passwords[0]);
  const p=await login('probe_parent',passwords[1]),q=await login('other_parent',passwords[4]);
  const c=await ws('probe_child',passwords[2],false),d=await ws('other_child',passwords[3],false);
  assert.equal((await call('player-permissions',{id:other.id,chatEnabled:false},q)).status,200);
  assert.equal((await call('player-permissions',{id:other.id,chatEnabled:true},p)).status,404);
  assert.equal((await settings(true,owner)).p.globalChat.enabled,true);
  await wsStatus(c,true);
  c.send({type:'chat',text:'only one allowed'});
  await c.take(m=>m.type==='chat'&&m.text==='only one allowed');
  await d.take(m=>m.type==='world'&&m.chatEnabled===false);
  assert.ok(!d.rows.some(r=>r.type==='chat'));
  assert.equal(own().familyDesk.children[child.id].chatEnabled,true);
  assert.equal(own().familyDesk.children[other.id].chatEnabled,false);
 });
 await check('launch-time prohibition cannot be overridden by owner',async()=>{
  await svc.close();svc=await start(false);owner=await login('probe_owner',passwords[0]);
  const r=await call('state',null,owner);assert.deepEqual(r.p.globalChat,{enabled:false,canEnable:false});
  assert.equal((await settings(true,owner)).status,409);
  await ws('probe_child',passwords[2],false);
 });
 await check('Desk routes require a valid local opt-in marker',async()=>{
  await svc.close();svc=null;
  await assert.rejects(startLocalServer({port:0,accountsDir:dir,parentDeskFile:marker+'.missing',chatEnabled:true}),/dedicated Family Desk marker/);
  writeFileSync(marker,'not the opt-in marker\n');
  await assert.rejects(start(true),/Invalid local family desk opt-in file/);
  writeFileSync(marker,'willowbrook-local-family-desk-v1\n');
  svc=await startLocalServer({port:0,accountsDir:dir,parentDeskFile:marker});
  assert.equal((await call('state')).p.role,null);
  owner=await login('probe_owner',passwords[0]);
  assert.deepEqual((await call('state',null,owner)).p.globalChat,{enabled:false,canEnable:false});
 });
 console.log('PASS '+count+' main scenarios');
}finally{
 for(const p of clients)p.terminate();
 if(svc)await svc.close();
 // Remove only the mkdtemp-created synthetic fixture, never a selected data directory.
 assert.ok(dir.startsWith(join(tmpdir(),'willowbrook-family-desk-owner-chat-test-')));
 rmSync(dir,{recursive:true,force:true});
}

