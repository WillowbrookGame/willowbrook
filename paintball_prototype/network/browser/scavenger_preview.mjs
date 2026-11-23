
import {createPreviewHuntTrophy} from './hunt_trophy_preview.mjs';
import {randomBytes,randomInt} from 'node:crypto';

const eligible=new Set(['town','beach','arcade','bank','vet','salon','store','cafe','library']);
const runPattern=/^[a-f0-9]{24}$/;
const requestPattern=/^[A-Za-z0-9_-]{8,64}$/;
const mayor={zone:'town',x:24,z:-26,radius:1.7};
const blank=()=>({version:1,runId:null,startedAt:null,completedAt:null,elapsedMs:null,bestMs:null,bestAt:null,trophyAwarded:false,collected:[],placements:[],starts:[]});
const at=(p,spot,now)=>p.zone===spot.zone&&p.grounded&&Math.abs(p.y)<2&&p.updated>0&&now-p.updated<=1800&&Math.hypot(p.x-spot.x,p.z-spot.z)<=spot.radius;

export function makeHuntPlacements({items,spots,random=randomInt,previous=[]}){
 const shuffle=list=>{
  const out=[...list];
  for(let i=out.length-1;i>0;i--){
   const j=random(i+1);
   if(!Number.isInteger(j)||j<0||j>i)throw Error('Invalid hunt random source');
   [out[i],out[j]]=[out[j],out[i]];
  }
  return out;
 };
 const chosen=shuffle(spots).slice(0,items.length),ordered=shuffle(items);
 const arrange=offset=>ordered.map((item,i)=>({id:item.id,spotId:chosen[(i+offset)%chosen.length].id}));
 const result=arrange(0);
 return result.every(p=>previous.some(old=>old.id===p.id&&old.spotId===p.spotId))?arrange(1):result;
}
export function createPreviewHunt({store,catalog,spots,random=randomInt}){
 const trophy=createPreviewHuntTrophy({store,kind:catalog.rewardKind});
 const items=catalog.items;
 if(items.length!==8||new Set(items.map(i=>i.id)).size!==8)throw Error('The preview hunt requires eight distinct original treasures');
 if(!Array.isArray(spots)||spots.length<items.length||new Set(spots.map(s=>s?.id)).size!==spots.length||
  !spots.every(s=>s&&typeof s.id==='string'&&eligible.has(s.zone)&&[s.x,s.z].every(Number.isFinite)&&s.radius===2.2&&typeof s.hint==='string'))throw Error('Invalid preview hunt spot catalog');
 if(new Set(spots.map(s=>JSON.stringify([s.zone,s.x,s.z]))).size!==spots.length)throw Error('Duplicate preview treasure coordinates');
 const itemFor=new Map(items.map(i=>[i.id,i])),spotFor=new Map(spots.map(s=>[s.id,s]));
 const state=p=>p.previewScavenger??blank();
 const visible=({id,spotId})=>{
  const item=itemFor.get(id),spot=spotFor.get(spotId);
  if(!item||!spot)return null;
  return {id,label:item.name,zone:spot.zone,x:spot.x,z:spot.z,hint:spot.hint,radius:spot.radius,asset:item.asset};
 };
 function snapshot(p){
  const s=state(p);
  return {runId:s.runId,startedAt:s.startedAt,completedAt:s.completedAt,elapsedMs:s.elapsedMs,bestMs:s.bestMs,
   trophyAwarded:s.trophyAwarded,rewardClaimed:s.trophyAwarded&&Number.isSafeInteger(s.trophyInventoryVersion)&&s.trophyInventoryVersion>=1,trophyInventoryPending:s.trophyAwarded===true&&!(Number.isSafeInteger(s.trophyInventoryVersion)&&s.trophyInventoryVersion>=1),rewardKind:catalog.rewardKind,
   collected:[...s.collected],placements:s.placements.map(visible).filter(Boolean)};
 }
 function leaderboard(){
  return Object.values(store.state.profiles)
   .filter(p=>!p.disabled&&!p.mustChangePassword&&Number.isSafeInteger(p.previewScavenger?.bestMs))
   .sort((a,b)=>a.previewScavenger.bestMs-b.previewScavenger.bestMs||a.previewScavenger.bestAt-b.previewScavenger.bestAt||a.id-b.id)
   .slice(0,50).map((p,i)=>({rank:i+1,displayName:p.username,durationMs:p.previewScavenger.bestMs}));
 }
 const persist=trophy.persist;
 function apply(peer,m,now){
  if(!Number.isSafeInteger(now)||now<0)return {error:'Hunt clock changed; please try again.'};
  const p=peer.profile,s=state(p);
  if(m.operation==='start'){
   if(!at(peer,mayor,now))return {error:'Talk to the Mayor in the park to start the treasure hunt.'};
   if(Object.keys(m).some(k=>!['type','action','operation','requestId','runId'].includes(k))||typeof m.requestId!=='string'||!requestPattern.test(m.requestId))return {error:'Please retry starting the hunt.'};
   const prior=m.runId??null;
   if(prior!==null&&(typeof prior!=='string'||!runPattern.test(prior)))return {error:'This hunt changed; talk to the Mayor again.'};
   const replay=s.starts.find(row=>row.id===m.requestId);
   if(replay)return replay.prior===prior?{text:'Find the eight treasures around Willowbrook.'}:{error:'Hunt request already used.'};
   if(prior!==s.runId)return {error:'This hunt changed; talk to the Mayor again.'};
   if(s.startedAt!==null&&s.completedAt===null)return {error:'Finish your current treasure hunt first.'};
   const next={...s,runId:randomBytes(12).toString('hex'),startedAt:now,completedAt:null,elapsedMs:null,collected:[],
    placements:makeHuntPlacements({items,spots,random,previous:s.placements}),
    starts:[...s.starts.slice(-31),{id:m.requestId,prior}]};
   persist(p,next);
   return {text:'Find the eight treasures around Willowbrook.'};
  }
  if(m.operation!=='collect'||Object.keys(m).some(k=>!['type','action','operation','runId','item'].includes(k)))return {error:'Choose a treasure hunt action.'};
  if(s.startedAt===null||!s.runId)return {error:'Ask the Mayor in the park about the treasure hunt first.'};
  if(typeof m.runId!=='string'||m.runId!==s.runId)return {error:'This treasure belongs to a different hunt.'};
  const assigned=s.placements.find(row=>row.id===m.item),spot=spotFor.get(assigned?.spotId);
  if(!spot||!at(peer,spot,now))return {error:'Walk closer to this treasure.'};
  if(s.collected.includes(m.item))return {text:'Treasure already found.'};
  if(s.completedAt!==null)return {error:'Talk to the Mayor to start another hunt.'};
  const final=s.collected.length===items.length-1,next={...s,collected:[...s.collected,m.item]};
  if(final){
   if(now<s.startedAt)return {error:'Hunt clock changed; please try again.'};
   next.completedAt=now;
   next.elapsedMs=now-s.startedAt;
   if(next.bestMs===null||next.elapsedMs<next.bestMs||(next.elapsedMs===next.bestMs&&now<next.bestAt)){
    next.bestMs=next.elapsedMs;next.bestAt=now;
   }
   next.trophyAwarded=true;
  }
  persist(p,next);
  if(!final)return {text:'Treasure found!'};
  return {text:s.trophyAwarded?'Treasure hunt complete!':'Treasure hunt complete! You earned the treasure trophy.',completed:true};
 }
 return {snapshot,leaderboard,apply,reconcile:trophy.reconcile};
}

