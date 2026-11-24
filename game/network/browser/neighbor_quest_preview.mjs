
import { openSync, writeFileSync, fsyncSync, closeSync, renameSync, unlinkSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';

const own=Object.hasOwn, routeNames=['gardener','librarian'], actions=['start','step','cancel'];
const maxReceipts=64, limit=Number.MAX_SAFE_INTEGER, cooldown=60000;
const request=/^[A-Za-z0-9_-]{8,64}$/;
const labels={
 gardener:['Collect seeds at the nursery','Plant the community garden','Care for the park'],
 librarian:['Collect a book at the lending library','Bring the book to the cafe','Return the book to the lending library']
};
const name={gardener:'Gardener',librarian:'Librarian'};
const course={gardener:'nursery',librarian:'library'};
const anchors={gardener:[['nursery',-23,48],['garden',20,48],['park',16,-24]],librarian:[['cottage',-16,-24],['cafe',16,19],['cottage',-16,-24]]};
const shape=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>own(v,k));
const rev=v=>Number.isSafeInteger(v)&&v>=0;
const publicError=error=>({error});
const keys=['type','action','operation','route','revision','requestId'];
export function createPreviewNeighborQuests({store,questDefinitions,businessDefinitions,workReward}){
 const routes=Object.fromEntries(routeNames.map(route=>{
  const stops=questDefinitions?.[route];
  if(!Array.isArray(stops)||stops.length!==3||!stops.every((s,i)=>isDeepStrictEqual([s.name,s.x,s.z],anchors[route][i])))
   throw Error('Neighbor route anchors changed; review before enabling.');
  return [route,stops.map((s,i)=>{
   const business=s.name==='cottage'?'library':s.name==='cafe'?'cafe':null;
   const room=business?businessDefinitions[business]:null;
   if(business&&(!room||![room.halfWidth,room.halfDepth].every(Number.isFinite)||room.halfWidth<=0||room.halfDepth<=0))
    throw Error('Neighbor route room bounds missing.');
   return Object.freeze({label:labels[route][i],x:s.x,z:s.z,business,halfWidth:room?.halfWidth,halfDepth:room?.halfDepth});
  })];
 }));
 const totalReward=(profile,route)=>{
  const n=workReward(course[route],profile.classes);
  if(![3,5,8,10].includes(n))throw Error('Unsupported neighbor quest reward.');
  return n;
 };
 function meta(p){
  const m=p.previewNeighborQuest;
  if(m===undefined)return {version:1,revision:0,receipts:[]};
  if(!shape(m,['version','revision','receipts'])||m.version!==1||!rev(m.revision)||!Array.isArray(m.receipts)||m.receipts.length>maxReceipts||
     new Set(m.receipts.map(r=>r?.requestId)).size!==m.receipts.length||
     !m.receipts.every((r,i)=>shape(r,['requestId','operation','route','revision','earned','completed'])&&
      typeof r.requestId==='string'&&request.test(r.requestId)&&actions.includes(r.operation)&&routeNames.includes(r.route)&&rev(r.revision)&&
      r.revision===m.revision-m.receipts.length+i&&rev(r.earned)&&r.earned<=10&&typeof r.completed==='boolean'&&
      (!r.completed?r.earned===0:r.operation==='step')))return null;
  return m;
 }
 function marker(route,step){
  const s=routes[route][step];
  return {label:s.label,worldX:s.x,worldZ:s.z,radius:7,business:s.business};
 }
 function snapshot(p,now){
  const m=meta(p),q=p.quest;
  if(!m)return {available:false,revision:null,current:null,routes:[]};
  const current=q.name?{route:q.name,step:q.step,marker:marker(q.name,q.step)}:null;
  return {available:true,revision:m.revision,current,routes:routeNames.map(route=>({
   route,label:name[route],reward:totalReward(p,route),marker:marker(route,0),
   completed:Number.isFinite(q.completed[route]),
   waitMs:Number.isFinite(q.completed[route])?Math.min(cooldown,Math.max(0,Math.ceil(q.completed[route]+cooldown-now))):0
  }))};
 }
 function atStop(peer,stop,now){
  if(![peer.x,peer.y,peer.z,peer.updated].every(Number.isFinite)||peer.updated<=0||now-peer.updated<0||now-peer.updated>1800||
     peer.grounded!==true||Math.abs(peer.y)>=2||peer.carId!=null||peer.interiorHome!=null||peer.rest||peer.playground)return false;
  if(peer.zone==='town')return Math.hypot(peer.x-stop.x,peer.z-stop.z)<=7;
  return stop.business!==null&&peer.zone===stop.business&&Math.abs(peer.x)<=stop.halfWidth&&Math.abs(peer.z)<=stop.halfDepth;
 }
 function persist(p,quest,nextMeta,stars){
  // One synchronous local writer, same path/commit protocol as Family Desk.
  // Confirmed durable rename is the only point at which live state advances.
  // Keep the legacy runtime's separate daily/.bak rotations untouched.
  const file=store.accountFile;
  const temp=file+'.tmp';
  const draft={...store.state,profiles:{...store.state.profiles,[p.username]:{...p,quest,previewNeighborQuest:nextMeta,stars}}};
  let fd,opened=false,committed=false;
  try{
   fd=openSync(temp,'wx',0o600);opened=true;
   writeFileSync(fd,JSON.stringify(draft));fsyncSync(fd);closeSync(fd);fd=undefined;
   renameSync(temp,file);committed=true;
  }catch{return false;}
  finally{
   if(fd!==undefined)try{closeSync(fd);}catch{}
   if(opened&&!committed)try{unlinkSync(temp);}catch{}
  }
  p.quest=quest;p.previewNeighborQuest=nextMeta;p.stars=stars;
  return true;
 }
 function apply(peer,m,now){
  if(!shape(m,keys)||m.type!=='progress'||m.action!=='neighborQuest'||!actions.includes(m.operation)||
     !routeNames.includes(m.route)||!rev(m.revision)||typeof m.requestId!=='string'||!request.test(m.requestId)||!rev(now))return publicError('Choose a valid neighbor quest action.');
  const p=peer.profile;
  if(!p||!own(store.state.profiles,p.username)||store.state.profiles[p.username]!==p||p.disabled||p.mustChangePassword)
   return publicError('Sign in to your player account first.');
  const current=meta(p);
  if(!current)return publicError('Neighbor quest progress needs a local save check. No further quest changes were made.');
  const prior=current.receipts.find(r=>r.requestId===m.requestId);
  if(prior){
   if(prior.operation!==m.operation||prior.route!==m.route||prior.revision!==m.revision)return publicError('This quest request ID was already used.');
   return {text:'That quest update was already saved.',earned:0,replay:true};
  }
  if(current.revision===limit||m.revision!==current.revision)return publicError('Quest progress changed. Use your current quest marker.');
  const q=structuredClone(p.quest), route=m.route, op=m.operation;
  if(op==='start'){
   if(q.name!==null)return publicError('Finish or cancel your current neighbor route first.');
   if(Number.isFinite(q.completed[route])&&now-q.completed[route]<cooldown)return publicError('This route is resting. Try again in a minute.');
  }else if(q.name!==route)return publicError('Choose your active neighbor route.');
  if(op!=='cancel'&&!atStop(peer,routes[route][op==='start'?0:q.step],now))
   return publicError('Visit the highlighted quest stop and stand nearby.');
  let stars=p.stars,earned=0,completed=false,text;
  if(op==='start'){q.name=route;q.step=0;text=labels[route][0]+'.';}
  else if(op==='cancel'){q.name=null;q.step=0;text='Neighbor route canceled.';}
  else if(q.step<2){++q.step;text='Next: '+labels[route][q.step]+'.';}
  else{
   completed=true;q.name=null;q.step=0;q.completed[route]=now;
   earned=Math.min(limit-stars,totalReward(p,route));stars+=earned;
   text=earned?'Neighbor route complete! +'+earned+' saved stars.':'Neighbor route complete. Your Saved Stars balance is full.';
  }
  const receipt={requestId:m.requestId,operation:op,route,revision:m.revision,earned,completed};
  if(!persist(p,q,{version:1,revision:current.revision+1,receipts:[...current.receipts.slice(-(maxReceipts-1)),receipt]},stars))
   return publicError('Could not save this quest update. Try it again.');
  return {text,earned,replay:false};
 }
 return {snapshot,apply};
}

