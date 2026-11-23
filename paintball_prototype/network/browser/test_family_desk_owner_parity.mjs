// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createFamilyDesk} from './family_desk_preview.mjs';
import {openPreviewAccounts} from './preview_accounts.mjs';
import {selectRuntime} from './runtime_source.mjs';
import {startLocalServer} from './server.mjs';

const runtime=await selectRuntime();
const {makeStore,characters}=await runtime.load('world-store.mjs');
const {WebSocket}=runtime.webSockets();
const stem=join(tmpdir(),'willowbrook-family-desk-owner-parity-');
const dir=mkdtempSync(stem);
const file=join(dir,'preview-accounts-v1.json');
const marker=join(dir,'.willowbrook-family-desk-opt-in');
const passwords=Array.from({length:5},()=>randomBytes(20).toString('base64url'));
const sockets=new Set();
let service,now=Date.now();
const saved=()=>JSON.parse(readFileSync(file,'utf8'));
const start=()=>startLocalServer({port:0,accountsDir:dir,parentDeskFile:marker,deskClock:()=>now});
const origin=()=> 'http://127.0.0.1:'+service.address.port;
const request=async (route,data=null,auth=null)=>{
 const headers={'X-Willowbrook-Desk':'1'};
 if(data!==null)Object.assign(headers,{'Content-Type':'application/json',Origin:origin()});
 if(auth)Object.assign(headers,{Cookie:auth.cookie,'X-Willowbrook-Csrf':auth.csrf});
 const response=await fetch(origin()+'/api/family-desk/'+route,{
  method:data===null?'GET':'POST',headers,body:data===null?undefined:JSON.stringify(data)
 });
 return {status:response.status,data:await response.json(),cookie:response.headers.get('set-cookie')?.split(';')[0]};
};
const signIn=async (username,password)=>{
 const r=await request('login',{username,password});
 assert.equal(r.status,200);
 return {cookie:r.cookie,csrf:r.data.csrf};
};
const waitLogin=async (username,password)=>{
 const socket=new WebSocket(origin().replace('http','ws')+'/play',{origin:origin()});
 sockets.add(socket);
 let timer;
 try{
  return await new Promise((resolve,reject)=>{
   timer=setTimeout(()=>reject(Error('Expected a gameplay login result.')),3000);
   socket.once('error',reject);
   socket.once('open',()=>socket.send(JSON.stringify({type:'login',username,password})));
   socket.on('message',body=>{
    const packet=JSON.parse(body);
    if(packet.type==='welcome'||packet.type==='denied')resolve(packet);
   });
  });
 }finally{clearTimeout(timer);socket.terminate();sockets.delete(socket);}
};
try{
 writeFileSync(marker,'willowbrook-local-family-desk-v1\n',{mode:0o600,flag:'wx'});
 // Historical format: a fresh v1 owner with a separately invited parent and that
 // parent's child, but no owner-household records. The public import must read it as-is.
 const accounts=await openPreviewAccounts({accountsDir:dir,source:runtime.root,site:null,makeStore,allowEmpty:true,parentDeskEnabled:true});
 const setup=createFamilyDesk({accounts,accountFile:file,makeStore,characters});
 setup.bootstrapOwner('fixture_owner',passwords[0]);
 const oldOwner=setup.login('fixture_owner',passwords[0]).actor;
 const parentInvite=setup.action('invite-parent',oldOwner,{username:'fixture_parent'});
 setup.action('redeem-parent',null,{code:parentInvite.code,password:passwords[1]});
 const historicalParent=setup.login('fixture_parent',passwords[1]).actor;
 const legacy=setup.action('create-player',historicalParent,{nickname:'legacy_child',avatar:'male-a',password:passwords[2]}).player;
 const initial=saved();
 assert.equal(initial.familyDesk.version,1);
 assert.ok(/^[a-f0-9]{24}$/.test(initial.familyDesk.children[legacy.id].household));
 assert.ok(!Object.hasOwn(initial,'familyChatPolicy'));
 service=await start();
 let owner=await signIn('fixture_owner',passwords[0]);
 let parent=await signIn('fixture_parent',passwords[1]);
 const oldState=await request('state',null,owner);
 assert.equal(oldState.data.role,'owner');
 assert.equal(oldState.data.canManagePlayers,true);
 assert.deepEqual(oldState.data.players,[]);
 assert.deepEqual(oldState.data.globalChat,{enabled:false,canEnable:false});
 assert.deepEqual((await request('state',null,parent)).data.players.map(p=>p.nickname),['legacy_child']);
 assert.deepEqual(saved(),initial);

 const invite=await request('invite-player',{},owner);
 assert.equal(invite.status,200);
 const invited=await request('redeem-player',{code:invite.data.code,nickname:'owner_child',avatar:'female-a',password:passwords[3]});
 assert.equal(invited.status,200);
 const player=invited.data.player;
 assert.equal(player.nickname,'owner_child');
 assert.equal(player.chatEnabled,false);
 assert.equal(saved().familyDesk.children[player.id].household,'owner:fixture_owner');
 assert.equal((await request('redeem-player',{code:invite.data.code,nickname:'another_child',avatar:'male-a',password:passwords[3]})).status,404);
 assert.deepEqual((await request('state',null,owner)).data.players.map(p=>p.nickname),['owner_child']);
 assert.deepEqual((await request('state',null,parent)).data.players.map(p=>p.nickname),['legacy_child']);
 assert.equal((await request('global-chat',{enabled:true},owner)).status,409);

 const ownMutation=await request('player-permissions',{id:player.id,chatEnabled:true},owner);
 assert.equal(ownMutation.status,200);
 assert.equal(ownMutation.data.player.chatEnabled,true);
 assert.equal((await request('player-permissions',{id:player.id,playEnabled:false},parent)).status,404);
 assert.equal((await request('reset-player',{id:legacy.id},owner)).status,404);
 assert.equal((await request('reset-player',{id:player.id},parent)).status,404);
 const allowed=await waitLogin('owner_child',passwords[3]);
 assert.equal(allowed.type,'welcome');
 assert.equal(allowed.chatEnabled,false);
 const paused=await request('player-permissions',{id:player.id,playEnabled:false},owner);
 assert.equal(paused.status,200);
 assert.equal((await waitLogin('owner_child',passwords[3])).type,'denied');
 assert.equal((await request('player-permissions',{id:player.id,playEnabled:true},owner)).status,200);

 const reset=await request('reset-player',{id:player.id},owner);
 assert.equal(reset.status,200);
 assert.equal((await waitLogin('owner_child',passwords[3])).type,'denied');
 assert.equal((await request('redeem-reset',{code:reset.data.code,password:passwords[4]})).status,200);
 assert.equal((await request('redeem-reset',{code:reset.data.code,password:passwords[3]})).status,404);
 assert.equal((await waitLogin('owner_child',passwords[4])).type,'welcome');

 const expired=await request('invite-player',{},owner);
 assert.equal(expired.status,200);
 now+=31*60*1000;
 assert.equal((await request('redeem-player',{code:expired.data.code,nickname:'late_child',avatar:'male-a',password:passwords[3]})).status,404);
 const before=saved();
 await service.close();
 service=null;
 service=await start();
 owner=await signIn('fixture_owner',passwords[0]);
 parent=await signIn('fixture_parent',passwords[1]);
 assert.deepEqual((await request('state',null,owner)).data.players.map(p=>p.nickname),['owner_child']);
 assert.deepEqual((await request('state',null,parent)).data.players.map(p=>p.nickname),['legacy_child']);
 assert.equal((await waitLogin('legacy_child',passwords[2])).type,'welcome');
 assert.equal(saved().familyDesk.version,before.familyDesk.version);
 assert.deepEqual(saved().familyDesk.children,before.familyDesk.children);
 console.log('PASS owner direct invite, redemption/expiry, game sign-in, household privacy, permissions, reset, old v1 compatibility and restart');
}finally{
 for(const socket of sockets)socket.terminate();
 if(service)await service.close();
 assert.ok(dir.startsWith(stem));
 rmSync(dir,{recursive:true,force:true});
}
