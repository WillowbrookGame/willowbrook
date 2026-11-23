const RESERVATION_MS=20_000;
const IDLE_MS=10*60_000;
const BOTS=['Pip','Scout','Sunny'];
const MAX=4;
const MIN=2;

export function createPaintballLobbies({admitted,nearDoor,send,authority=null}){
 const room={slots:[],host:0,expires:0,starting:false,revision:0,notice:''};
 const memberships=new Map();
 let nextSlot=0,lastBusy=false,lastWorker=false;
 const active=p=>{const slot=memberships.get(p.profile?.id);return slot?.peer===p?slot:null;};
 const reply=(p,action,payload)=>{if(admitted(p))send(p,{type:'paintballLobby',action,...payload});};
 const working=()=>authority?.ready()===true;
 const busy=()=>authority?.busy()===true;
 function snapshot(slot){
  const humans=room.slots.map(s=>({slot:s.id,alias:s.alias,connected:!!s.peer,ready:!!s.peer&&s.ready}));
  return {phase:room.starting?'starting':'lobby',selfSlot:slot.id,hostSlot:room.host,minPlayers:MIN,maxPlayers:MAX,
   humans,botPreview:BOTS.slice(0,MAX-humans.length),arenaBusy:busy(),workerReady:working(),notice:room.notice};
 }
 function publish(){
  for(const slot of room.slots)if(slot.peer)reply(slot.peer,'state',{ok:true,room:snapshot(slot)});
 }
 function pickHost(){
  if(!room.slots.some(s=>s.id===room.host&&s.peer))room.host=room.slots.find(s=>s.peer)?.id??0;
 }
 function changed(notice){
  room.revision++;
  room.notice=room.slots.length?notice:'';
  for(const s of room.slots)s.ready=false;
  pickHost();
 }
 function remove(slot,reason=null){
  memberships.delete(slot.account);
  room.slots=room.slots.filter(s=>s!==slot);
  changed('The roster changed. Please mark Ready again.');
  if(slot.peer&&reason)reply(slot.peer,'state',{ok:true,room:null,reason});
  publish();
 }
 function forgetAccount(id){const slot=memberships.get(id);if(slot)remove(slot);}
 function disconnect(p,now,{revoke=false}={}){
  const slot=active(p);if(!slot)return;
  if(revoke){remove(slot);return;}
  slot.peer=null;slot.hold=now+RESERVATION_MS;
  changed('A player disconnected. Please mark Ready again.');
  publish();
 }
 function resume(p,now){
  if(!admitted(p))return false;
  const slot=memberships.get(p.profile?.id);
  if(!slot||slot.peer||slot.hold<=now||room.expires<=now)return false;
  slot.peer=p;slot.hold=0;
  changed('A player reconnected. Please mark Ready again.');
  publish();
  return true;
 }
 async function maybeStart(){
  if(room.starting||room.slots.length<MIN||!working()||busy()||room.slots.some(s=>!s.peer||!s.ready))return;
  const host=room.slots.find(s=>s.id===room.host);
  if(!host?.ready)return;
  room.starting=true;
  room.notice='';
  publish();
  const revision=room.revision;
  let result;
  try{result=await authority.start(room,host,revision);}
  catch{result={ok:false,error:'The online arena is unavailable.'};}
  room.starting=false;
  if(!result.ok){
   changed(result.error||'Could not start the arena. Please mark Ready again.');
   publish();
   return;
  }
  for(const s of room.slots)memberships.delete(s.account);
  room.slots=[];room.host=0;room.expires=0;room.notice='';room.revision++;
 }
 function tick(now,auto=true){
  if(room.slots.length&&room.expires<=now){
   const all=room.slots.slice();
   for(const s of all)remove(s,'The lobby timed out.');
   return;
  }
  for(const s of [...room.slots]){
   if((s.peer&&!admitted(s.peer))||(!s.peer&&s.hold<=now))remove(s);
  }
  const currentBusy=busy();
  const currentWorker=working();
  if(currentBusy!==lastBusy||currentWorker!==lastWorker){lastBusy=currentBusy;lastWorker=currentWorker;publish();}
  if(auto)void maybeStart();
 }
 function moved(p,pose){
  const slot=active(p);
  if(slot&&(pose.zone!=='town'||Math.hypot(pose.x-36,pose.z+46)>7))remove(slot,'You left the Paintball entrance.');
 }
 async function handle(p,msg,now){
  if(!admitted(p))return;
  tick(now,false);
  const supported=['join','ready','leave','state'];
  const action=typeof msg.action==='string'&&supported.includes(msg.action)?msg.action:'invalid';
  const fail=error=>reply(p,action,{ok:false,error});
  if(Object.keys(msg).some(k=>!['type','action',...(action==='ready'?['ready']:[])].includes(k))||action==='invalid'||
     (action==='ready'&&typeof msg.ready!=='boolean'))return fail('Choose a supported lobby action.');
  const slot=active(p);
  if(action==='state')return reply(p,action,{ok:true,room:slot?snapshot(slot):null});
  if(action==='leave'){
   if(slot)remove(slot);
   return reply(p,action,{ok:true,room:null});
  }
  if(action==='ready'){
   if(!slot)return fail('Join the Paintball lobby first.');
   if(room.starting)return fail('The arena is already loading.');
   if(!working())return fail('Online Paintball is unavailable right now.');
   slot.ready=msg.ready;
   room.expires=now+IDLE_MS;
   room.notice='';
   reply(p,action,{ok:true,room:snapshot(slot)});
   publish();
   return maybeStart();
  }
  if(slot)return reply(p,action,{ok:true,room:snapshot(slot)});
  if(!nearDoor(p,now))return fail('Walk to the Paintball entrance first.');
  if(authority?.active(p))return fail('Leave your current match before joining the waiting lobby.');
  if(!working())return fail('Online Paintball is unavailable right now.');
  if(room.starting)return fail('A match is loading. Tap Multiplayer again in a moment.');
  if(memberships.has(p.profile.id))return fail('Your spot is reserved. Reconnect or try again shortly.');
  if(room.slots.length>=MAX)return fail('The waiting lobby is full (4 players). Try again after it starts.');
  const joined={id:++nextSlot,alias:p.profile.username,account:p.profile.id,peer:p,hold:0,ready:false};
  room.slots.push(joined);room.revision++;room.expires=now+IDLE_MS;memberships.set(joined.account,joined);
  pickHost();
  reply(p,action,{ok:true,room:snapshot(joined)});
  publish();
 }
 return {handle,moved,resume,disconnect,forgetAccount,tick};
}