import {randomBytes} from 'node:crypto';

const HOLD_MS=20000, ABSENT_MS=15000, MAX_MATCH_MS=13*60_000;
const ACTIONS=['ready','view','input','next','leave'];
const closed=()=>({ok:false,error:'Online Paintball is unavailable. Solo play still works.'});

export function createPrivatePaintballMatches({worker,admitted,send,hideFromWorld,rewards=null,onStarsUpdated=null,now=()=>Date.now()}){
 const matches=new Map(), memberships=new Map();
 const peerSlot=p=>{const row=memberships.get(p.profile?.id);return row?.peer===p?row:null;};
 const reply=(p,action,data)=>{if(admitted(p))send(p,{type:'paintballMatch',action,...data});};
 const ready=()=>worker.healthy();
 const active=p=>!!peerSlot(p);

 function applyMatchRewards(room,view){
  if(!rewards||view?.phase!=='finished'||!Array.isArray(view.ranking))return;
  if(!room.rewards)room.rewards=new Map();
  for(const member of room.members){
   if(room.rewards.has(member.slot)||!member.peer?.profile)continue;
   const entry=view.ranking.find(x=>x&&String(x.slot)===member.slot);
   if(!entry)continue;
   const earned=rewards.awardOnline(member.peer.profile,entry.rank,'pb_'+room.id);
   if(earned>0){
    room.rewards.set(member.slot,earned);
    if(onStarsUpdated&&admitted(member.peer))onStarsUpdated(member.peer);
   }
  }
 }

 function end(room,message){
  if(matches.get(room.id)!==room)return;
  matches.delete(room.id);
  for(const row of room.members){
   memberships.delete(row.account);
   if(row.peer)reply(row.peer,'ended',{ok:true,epoch:room.epoch,returnTown:true,text:message});
  }
  if(ready())void worker.call('close',{room:room.id});
 }
 function unavailable(){
  for(const room of [...matches.values()])end(room,'Online Paintball disconnected. Return to Town; Solo still works.');
 }
 function publishJoin(row){
  reply(row.peer,'enter',{ok:true,epoch:row.room.epoch,selfSlot:row.slot});
 }
 async function start(lobby,host,revision){
  if(!ready())return closed();
  if(matches.size>0)return {ok:false,error:'The preview arena is already in use. Try again after that match.'};
  if(lobby.slots.length<2||lobby.slots.length>4||lobby.slots.some(s=>!s.peer||!admitted(s.peer)||memberships.has(s.account)))
   return {ok:false,error:'At least two connected players are needed.'};
  const connected=lobby.slots.slice();
  const room={id:randomBytes(12).toString('hex'),epoch:randomBytes(8).toString('hex'),members:[],until:now()+MAX_MATCH_MS};
  const humans=connected.map(s=>({slot:String(s.id),alias:s.alias}));
  const result=await worker.call('open',{room:room.id,slot:String(host.id),humans});
  if(!result?.ok||!ready())return closed();
  if(lobby.revision!==revision||lobby.slots.length!==connected.length||connected.some(s=>!lobby.slots.includes(s)||!s.peer||!admitted(s.peer)||memberships.has(s.account))){
   await worker.call('close',{room:room.id});
   return {ok:false,error:'The lobby changed while loading. Try again.'};
  }
  matches.set(room.id,room);
  for(const s of connected){
   const row={room,account:s.account,slot:String(s.id),peer:s.peer,held:0,last:now(),limitAt:0,rate:0,busy:false};
   memberships.set(row.account,row);
   room.members.push(row);
   hideFromWorld(row.peer);
  }
  for(const row of room.members)publishJoin(row);
  return {ok:true};
 }
 function disconnect(p,time,{revoke=false}={}){
  const row=peerSlot(p);
  if(!row)return false;
  if(revoke){void remove(row,false);return true;}
  row.peer=null;row.held=time+HOLD_MS;
  if(ready())void worker.call('disconnect',{room:row.room.id,slot:row.slot});
  return true;
 }
 async function remove(row,notify){
  memberships.delete(row.account);
  const p=row.peer;
  row.room.members=row.room.members.filter(x=>x!==row);
  if(notify&&p)reply(p,'leave',{ok:true,epoch:row.room.epoch,returnTown:true});
  if(row.room.members.length===0){end(row.room,'This Paintball match has closed.');return;}
  if(ready())await worker.call('leave',{room:row.room.id,slot:row.slot});
 }
 async function resume(p,t){
  if(!admitted(p)||!ready())return false;
  const row=memberships.get(p.profile?.id);
  if(!row||row.peer||row.held<=t)return false;
  const result=await worker.call('resume',{room:row.room.id,slot:row.slot});
  if(!result?.ok||!admitted(p)||memberships.get(row.account)!==row||row.peer)return false;
  row.held=0;row.peer=p;
  hideFromWorld(p);
  publishJoin(row);
  return true;
 }
 function forgetAccount(id){
  const row=memberships.get(id);
  if(row)void remove(row,false);
 }
 function validFrame(v){
  return v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===7&&Number.isSafeInteger(v.sequence)&&v.sequence>=0&&v.sequence<=2147483647
   &&Number.isFinite(v.x)&&Math.abs(v.x)<=1&&Number.isFinite(v.z)&&Math.abs(v.z)<=1
   &&Number.isFinite(v.yaw)&&Math.abs(v.yaw)<=Math.PI&&Number.isFinite(v.pitch)&&Math.abs(v.pitch)<=1.1
   &&typeof v.jump==='boolean'&&typeof v.paint==='boolean';
 }
 async function handle(p,m,time){
  const action=ACTIONS.includes(m.action)?m.action:'invalid';
  if(!admitted(p))return;
  const row=peerSlot(p);
  if(!row||!ready())return reply(p,action,closed());
  if(m.epoch!==row.room.epoch||action==='invalid'||Object.keys(m).some(k=>!['type','action','epoch',...(action==='input'?['frame']:[])].includes(k)))
   return reply(p,action,{ok:false,error:'Choose a match action.'});
  if(action==='leave')return await remove(row,true);
  if(action==='input'&&!validFrame(m.frame))return reply(p,action,{ok:false,error:'Invalid game input.'});
  if(row.limitAt<time-1000){row.limitAt=time;row.rate=0;}
  if(++row.rate>40||row.busy)return;
  row.busy=true;
  const r=await worker.call(action,{room:row.room.id,slot:row.slot,...(action==='input'?{frame:m.frame}:{})});
  row.busy=false;
  if(peerSlot(p)!==row)return;
  if(!r)return reply(p,action,closed());
  if(r.view?.phase==='abandoned')return end(row.room,'This match has ended. Return to Town.');
  if(r.view?.phase==='finished')applyMatchRewards(row.room,r.view);
  if(r.ok) row.last=time;
  const view=r.view&&row.room.rewards?.has(row.slot)?{...r.view,rewardStars:row.room.rewards.get(row.slot)}:r.view;
  reply(p,action,{ok:r.ok,epoch:row.room.epoch,...(view?{view}:{})});
 }
 function tick(time){
  if(!ready()){unavailable();return;}
  for(const room of [...matches.values()]){
   if(room.until<=time){end(room,'This Paintball match timed out. Return to Town.');continue;}
   for(const row of [...room.members]){
    if(!row.peer&&row.held<=time)void remove(row,false);
    else if(row.peer&&!admitted(row.peer))void remove(row,false);
    else if(row.peer&&row.last>0&&row.last+ABSENT_MS<time){
     reply(row.peer,'ended',{ok:true,returnTown:true,text:'You left the match idle too long.'});
     void remove(row,false);
    }
   }
  }
 }
 return {start,ready,busy:()=>matches.size>0,active,handle,disconnect,resume,forgetAccount,tick,unavailable};
}
