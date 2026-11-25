import assert from 'node:assert/strict';
import {mkdtemp,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {startLocalServer} from './server.mjs';
import {selectRuntime} from './runtime_source.mjs';
const source=process.argv[2]?resolve(process.argv[2]):undefined;
const geometry=JSON.parse(await readFile(new URL('./hide_seek_geometry.json',import.meta.url),'utf8'));
const {WebSocket}=(await selectRuntime(source)).webSockets();
const users=['qa_seek_it','qa_seek_hider','qa_seek_visitor','qa_seek_late'].map(username=>({username,password:'disposable Hide and Seek test '+username}));
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-hideseek-ws-fixture-'));
const opt={source,port:0,accountsDir,seedAccounts:users};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
let server, peers=[];
async function stop(){for(const ws of peers)ws.terminate();peers=[];await server?.close();server=null;}
async function connect(user){
 const addr='127.0.0.1:'+server.address.port, ws=new WebSocket('ws://'+addr+'/play',{origin:'http://'+addr});
 peers.push(ws);
 const packets=[];ws.on('message',x=>packets.push(JSON.parse(x)));
 await new Promise((ok,no)=>{ws.once('open',ok);ws.once('error',no);});
 const send=m=>ws.send(JSON.stringify(m));
 const get=async(fn,mark=0,ms=4500)=>{const t=Date.now()+ms;while(Date.now()<t){const r=packets.slice(mark).find(fn);if(r)return r;await wait(20);}throw Error('Expected server reply was not received');};
 const act=(action,fields={})=>{const mark=packets.length;send({type:'hideSeek',action,...fields});return get(m=>m.type==='hideSeek'&&m.action===action,mark);};
 const pose=(zone,x,z,yaw=0)=>send({type:'move',zone,x,y:.04,z,yaw,grounded:true,moving:false});
 const move=async(zone,x,z,yaw=0)=>{await wait(40);const mark=packets.length;pose(zone,x,z,yaw);return get(m=>m.type==='world'&&m.zone===zone,mark);};
 let welcome;if(user){send({type:'login',...user});welcome=await get(m=>m.type==='welcome');}
 return {send,get,act,pose,move,welcome,mark:()=>packets.length,count:type=>packets.filter(p=>p.type===type).length};
}
try{
 server=await startLocalServer(opt);
 const disabled=await connect(users[0]);
 assert(!disabled.welcome.hideSeekEnabled);assert(!Object.hasOwn(await disabled.move('town',0,3),'hideSeek'));
 await stop();
 server=await startLocalServer({...opt,enableHideSeek:true});
 const anon=await connect();anon.send({type:'hideSeek',action:'join'});assert.match((await anon.get(m=>m.type==='denied')).error,/Sign in/);
 const a=await connect(users[0]),b=await connect(users[1]),c=await connect(users[2]);
 assert(a.welcome.hideSeekEnabled&&b.welcome.hideSeekEnabled);
 await c.move('beach',0,3);assert(!(await c.act('join')).ok);
 await c.move('private',0,3);assert(!(await c.act('join')).ok);
 await c.move('beach',0,3);
 await a.move('town',0,3);await b.move('town',0,4);
 assert((await a.act('join')).state.host);
 const [bi,ci]=await Promise.all([b.get(m=>m.type==='hideSeekInvite'),c.get(m=>m.type==='hideSeekInvite')]);
 assert.equal(bi.id,ci.id);assert.equal(ci.host,users[0].username);assert(ci.remainingMs>0);
 assert.equal(a.count('hideSeekInvite'),0);
 const unsupported=await c.act('accept',{inviteId:ci.id});assert(!unsupported.ok&&/Return to Town/.test(unsupported.error));
 const declined=await c.act('decline',{inviteId:ci.id});assert(declined.ok&&declined.state===null&&declined.inviteId===ci.id);
 assert(!(await c.act('accept',{inviteId:ci.id})).ok);
 assert((await b.act('accept',{inviteId:bi.id})).ok);
 assert.equal(b.count('hideSeekInvite'),1);assert.equal(c.count('hideSeekInvite'),1);
 const d=await connect(users[3]);const di=await d.get(m=>m.type==='hideSeekInvite');
 assert.equal(di.id,bi.id);

 assert(!(await b.act('start')).ok);assert.equal((await a.act('start')).state.role,'seeker');
 assert.equal((await d.get(m=>m.type==='hideSeekInviteClosed')).id,di.id);
 assert(!(await a.act('tag')).ok);
 const hidden=await a.get(m=>m.type==='world'&&m.hideSeek?.phase==='hide');
 assert(!hidden.players.some(p=>p.alias===users[1].username));
 assert.equal(hidden.presence.find(p=>p.alias===users[1].username).place,'Hide and Seek');
 assert.deepEqual(Object.keys(hidden.hideSeek).sort(),['found','host','memberCount','phase','remaining','remainingMs','result','role'].sort());
 async function enter(p,zone){const g=geometry[zone];await p.move('town',g.door.x,g.door.z);return p.move(zone,g.spawn.x,g.spawn.z);}
 const bank=geometry.bank;
 const library=geometry.library;
 const keeper=b.mark();a.pose('town',8,8);a.pose('bank',bank.spawn.x,bank.spawn.z);
 a.send({type:'playground',action:'enter',ride:'swing-0'});
 const truth=await b.get(m=>m.type==='world'&&m.zone==='town'&&m.players.some(v=>v.alias===users[0].username),keeper);
 const frozen=truth.players.find(v=>v.alias===users[0].username);
 assert.equal(frozen.x,0);assert.equal(frozen.z,3);assert.equal(frozen.moving,false);
 const aFrozen=await a.get(m=>m.type==='world'&&m.zone==='town',a.mark());assert.equal(aFrozen.hideSeek.phase,'hide');
 const vet=geometry.vet;
 assert.equal((await enter(b,'vet')).hideSeek.memberCount,2);
 await b.move('vet',vet.exit.x,vet.exit.z);
 // Godot lands 2.0 outside; the server's reference remains 2.2.
 assert.equal((await b.move('town',vet.return.x,vet.door.z+2.0)).hideSeek.memberCount,2);
 await enter(b,'library');
 assert.equal((await b.act('state')).state.memberCount,2);
 assert.equal((await a.act('state')).state.phase,'hide');
 await a.get(m=>m.hideSeek?.phase==='seek',a.mark(),34000);
 await enter(a,'bank');await a.move('bank',0,.49);await b.move('library',0,-1.50);
 assert(!(await a.act('tag')).ok,'same coordinates in different scenes never tag');
 await b.move('library',library.exit.x,library.exit.z);
 assert.equal((await b.move('town',library.return.x,library.return.z)).hideSeek.memberCount,2);
 assert.equal((await enter(b,'bank')).hideSeek.memberCount,2);
 await b.move('bank',0,-1.5);await a.move('bank',0,.49);
 assert(!(await a.act('tag')).ok,'baked actual bank counter blocks');
 await wait(520);
 await b.move('bank',2.3,-1.3);await a.move('bank',2.3,.5);
 const approaching=await a.get(m=>m.hideSeek?.tagEligible===true,a.mark(),3300);
 assert(approaching.players.some(row=>row.alias===users[1].username));
 await Promise.all([a.move('bank',2.3,.5),b.move('bank',2.3,-1.3)]);
 assert.equal((await a.act('tag')).state.result,'seeker');
 assert((await b.act('state')).state.found);
 assert((await a.act('leave')).ok);assert((await b.act('leave')).ok);
 console.log('PASS actual local WebSockets: opt-in, account gate, no Beach/private entry, cross-zone invitation/decline, frozen countdown pose and privacy, separate public room identity, legal Vet and library exit and bank entrance, baked bank counter occlusion, clear authoritative tag, results.');
}finally{await stop();}
