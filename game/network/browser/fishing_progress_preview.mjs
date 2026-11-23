import {randomBytes,randomInt} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {catalog} from './fishing_catalog_preview.mjs';
const species=new Map(catalog.map(f=>[f.id,f]));
const maxBag=500, reach=4.5, maxCast=17.05;
const holds=[ [20.15,22.85,-9.25,-4.75],[41.4,44.6,-9.8,-4.2] ];
const buildings=[[-29.4,-20.6,4.5,11.5],[21.85,27.15,6.8,11.2],[-23.9,-14.1,30.2,37],[-48,-38,4.4,13.6]];
const spots=[...[-52,-44,-36,-28,-20,-12,12,20,44,52].map(x=>({x,z:-3})),...[-4,-12,-20,-28].flatMap(z=>[{x:-5,z},{x:5,z}]),{x:25,z:-4},{x:39,z:-4},{x:23.5,z:-10},{x:40.5,z:-10}];
const within=(p,[x1,x2,z1,z2])=>p.x>=x1&&p.x<=x2&&p.z>=z1&&p.z<=z2;
const boat=p=>holds.some(r=>within(p,r));
const dock=p=>(Math.abs(p.x)<=2.2&&p.z>=-23)||(Math.abs(p.x)<=3.25&&p.z>=-35&&p.z<=-23)||(Math.abs(p.x-32)<=2.2&&p.z>=-11)||(Math.abs(p.x-32)<=7&&p.z>=-11.45&&p.z<=-6);
const water=p=>Math.abs(p.x)<57&&p.z>=-55&&p.z<1&&!dock(p)&&!boat(p);
const stand=p=>p.grounded&&Math.abs(p.y)<1.4&&Math.abs(p.x)<57&&(p.z>=1&&p.z<=5||p.z<1&&dock(p));
const d=(p,q)=>Math.hypot(p.x-q.x,p.z-q.z);
const stretch=(p,q,t)=>({x:p.x+(q.x-p.x)*t,z:p.z+(q.z-p.z)*t});
const clear=(p,q,valid)=>{const steps=Math.max(1,Math.ceil(d(p,q)/.24));for(let i=0;i<=steps;i++)if(!valid(stretch(p,q,i/steps)))return false;return true;};
const rid=x=>typeof x==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(x);
const id24=x=>typeof x==='string'&&/^[a-f0-9]{24}$/.test(x);
const bagKey=bag=>JSON.stringify(bag.map(x=>[x.id,x.type]));
const yes=(text,extra={})=>({ok:true,text,...extra});
const no=text=>({ok:false,text});
const dealer=p=>Math.abs(p.x+19)<=3.5&&p.z<30.12&&Math.hypot(p.x+19,p.z-32.65)<=7&&p.grounded&&Math.abs(p.y)<1.25;
const empty=()=>({inventory:[],sales:[],catches:[]});
export function createPreviewFishing(store,{clock=Date.now,random=()=>randomInt(0x100000000)/0x100000000,id=()=>randomBytes(12).toString('hex')}={}){
 const fish=new Map(), lines=new Map();
 let refresh=clock(), last=clock();
 function saved(profile){
  const s=profile.previewFishing;
  if(s===undefined)return empty();
  if(!s||!Array.isArray(s.inventory)||s.inventory.length>maxBag||!Array.isArray(s.sales)||!Array.isArray(s.catches)||s.inventory.some(r=>!id24(r?.id)||!species.has(r.type))||new Set(s.inventory.map(r=>r.id)).size!==s.inventory.length)throw Error('Invalid fishing save');
  return s;
 }
 const item=r=>{const f=species.get(r.type);return {id:r.id,type:r.type,name:f.name,value:f.value};};
 function save(profile,old,next,nextStars){
  const previous=profile.previewFishing, stars=profile.stars;
  profile.previewFishing=next;profile.stars=nextStars;
  try{store.save();return true;}
  catch{
   try{const d=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles[profile.username];if(d?.stars===nextStars&&JSON.stringify(d.previewFishing)===JSON.stringify(next))return true;}catch{}
   if(previous===undefined)delete profile.previewFishing;else profile.previewFishing=old;
   profile.stars=stars;return false;
  }
 }
 function selectType(){
  let n=random()*catalog.reduce((s,f)=>s+f.weight,0);
  for(const f of catalog){n-=f.weight;if(n<0)return f.id;}
  return catalog.at(-1).id;
 }
 function spawn(){
  const candidates=spots.filter(s=>water(s)&&![...fish.values()].some(f=>d(s,f)<7)&&![...lines.values()].some(l=>d(s,l)<=10));
  if(!candidates.length)return false;
  const point=candidates[Math.floor(random()*candidates.length)];
  const theta=random()*Math.PI*2;
  const f={...point,id:id(),size:.81+random()*.38,type:selectType(),owner:null,headingX:Math.cos(theta),headingZ:Math.sin(theta)};
  fish.set(f.id,f);return true;
 }
 for(let i=0,n=2+Math.floor(random()*9);i<n;i++)spawn();
 function schedule(now){refresh=now+(fish.size<2?7000+Math.floor(random()*4001):30000+Math.floor(random()*40001));}
 schedule(last);
 function population(now=clock()){
  const dt=Math.min(.2,Math.max(0,now-last)/1000);last=now;
  for(const f of fish.values()){
   let next;
   const l=f.owner&&lines.get(f.owner);
   const toward=l&&now>=l.landAt;
   if(toward){
    const dx=l.x-f.x,dz=l.z-f.z,dist=Math.hypot(dx,dz);
    if(dist<.13)continue;
    f.headingX=dx/dist;f.headingZ=dz/dist;
    next=stretch(f,l,Math.min(1,dt*1.9/dist));
   }else next={x:f.x+f.headingX*dt*.42,z:f.z+f.headingZ*dt*.42};
   if(clear(f,next,water)){f.x=next.x;f.z=next.z;}
   else if(!toward){const theta=random()*Math.PI*2;f.headingX=Math.cos(theta);f.headingZ=Math.sin(theta);}
  }
  if(now>=refresh){
   if(fish.size<2){while(fish.size<2&&spawn()){}}
   else{const target=2+Math.floor(random()*9);if(fish.size<target)spawn();else if(fish.size>target){const idle=[...fish.values()].filter(f=>!f.owner);if(idle.length)fish.delete(idle[Math.floor(random()*idle.length)].id);}}
   schedule(now);
  }
  return [...fish.values()].map(({id,x,z,size,owner,headingX,headingZ})=>({id,x,z,size,reserved:!!owner,headingX,headingZ}));
 }
 const visual=p=>({equipped:p.fishingEquipped===true,cast:lines.get(p)?.visual??null});
 const snapshot=p=>({...visual(p),inventory:saved(p.profile).inventory.map(item)});
 function clearLine(p,putAway=false){
  const l=lines.get(p);lines.delete(p);
  const f=l&&fish.get(l.visual.fishId);if(f?.owner===p){fish.delete(f.id);if(fish.size<2)refresh=Math.min(refresh,clock()+7000+Math.floor(random()*4001));}
  if(putAway){p.fishingEquipped=false;p.fishingQuote=null;p.fishingRequests=null;}
 }
 const close=p=>clearLine(p,true);
 const eligible=(p,now)=>p.zone==='beach'&&p.profile&&Number.isFinite(p.updated)&&now-p.updated<=2500&&Math.abs(p.x)<57&&p.z>=-55&&p.z<=43;
 function moved(p,pose){
  if(p.zone==='beach'&&pose.zone!=='beach'){close(p);return;}
  const l=lines.get(p);if(l&&d(pose,l.origin)>1.25)clearLine(p);
 }
 function update(p,now){
  const l=lines.get(p);
  if(l&&(now>l.visual.expiresAt||!eligible(p,now)||!stand(p)||d(p,l.origin)>1.25))clearLine(p);
 }
 function apply(p,m,now=clock()){
  const op=m.operation;
  const required={cast:['x','z'],reel:['castId'],sell:['quoteId']};
  const allowed={equip:[],putAway:[],cancel:['castId'],cast:required.cast,reel:required.reel,quote:[],sell:required.sell};
  if(!Object.hasOwn(allowed,op)||!rid(m.requestId)||Object.keys(m).some(k=>!['type','action','operation','requestId',...allowed[op]].includes(k)))return no('Choose a supported fishing action.');
  const old=saved(p.profile);
  if(op==='sell'&&id24(m.quoteId)){
   const sold=old.sales.find(r=>r.quoteId===m.quoteId);
   if(sold)return yes('That fish sale was already saved.',{sold});
  }
  if(op==='reel'&&id24(m.castId)){
   const r=old.catches.find(r=>r.castId===m.castId&&r.requestId===m.requestId);
   if(r)return yes('That catch was already saved.',{caught:item(r)});
  }
  if(op==='putAway'){clearLine(p,true);return yes('Fishing pole put away.');}
  if(op==='cancel'){
   const l=lines.get(p);
   if(!l||!m.castId||l.visual.id===m.castId)clearLine(p);
   p.fishingQuote=null;
   return yes('Line reeled in.');
  }
  if(!eligible(p,now))return no('Stand on the beach to go fishing.');
  if(op==='equip'){
   if(!p.grounded||Math.abs(p.y)>1.25||d(p,{x:2.8,z:2})>3)return no('Walk to the fishing pole by the pier.');
   p.fishingEquipped=true;return yes('Fishing pole ready!');
  }
  if(op==='cast'){
   if(!p.fishingEquipped)return no('Pick up a fishing pole first.');
   const target={x:m.x,z:m.z};
   if(!Number.isFinite(target.x)||!Number.isFinite(target.z)||!stand(p)||!water(target)||d(p,target)<1.2||d(p,target)>maxCast||!clear(p,target,v=>!boat(v)&&!buildings.some(r=>within(v,r))))return no('Aim at clear water near the shore or a pier.');
   const prior=lines.get(p);if(prior)return prior.requestId===m.requestId?yes('Line is already cast.'):no('Reel in your current line first.');
   if(old.inventory.length>=maxBag)return no('Your fish bag is full. Sell your fish at the snack shop.');
   if(p.fishingRequests?.has(m.requestId))return no('That cast request already ended.');
   if(!p.fishingRequests)p.fishingRequests=new Set();
   p.fishingRequests.add(m.requestId);if(p.fishingRequests.size>64)p.fishingRequests.delete(p.fishingRequests.values().next().value);
   const available=[...fish.values()].filter(f=>!f.owner&&d(target,f)<=reach&&clear(f,target,water)).sort((a,b)=>d(target,a)-d(target,b));
   const f=available[0], landAt=now+580;
   const biteAt=f?landAt+4000+Math.floor(random()*4001):null;
   const nibbles=f?Array.from({length:1+Math.floor(random()*3)},(_,i)=>i):[];
   const visual={id:id(),fishId:f?.id??null,...target,startedAt:now,landAt,nibbles:nibbles.map(i=>biteAt-(nibbles.length-i)*900),biteAt,expiresAt:f?biteAt+2500:landAt+20000};
   lines.set(p,{...target,visual,origin:{x:p.x,z:p.z},requestId:m.requestId});
   if(f)f.owner=p;
   return yes(f?'Watch the bobber and wait for the bite.':'Line cast. Reel in any time to try another spot.');
  }
  if(op==='reel'){
   const l=lines.get(p);
   if(!id24(m.castId)||l?.visual.id!==m.castId)return no('Cast your line first.');
   const v=l.visual, f=fish.get(v.fishId);
   if(now<v.landAt)return no('Wait for the line to land.');
   if(!stand(p)||d(p,l.origin)>1.25){clearLine(p);return no('Stay beside your fishing line.');}
   if(!f||f.owner!==p||now<v.biteAt||now>v.expiresAt){
    clearLine(p);return no(!f?'No fish took the bait.':now<v.biteAt?'Too soon! Wait for the bite.':'The fish got away.');
   }
   if(old.inventory.length>=maxBag){clearLine(p);return no('Your fish bag is full.');}
   const row={id:id(),type:f.type}, receipt={...row,castId:v.id,requestId:m.requestId};
   const next={...old,inventory:[...old.inventory,row],catches:[...old.catches.slice(-63),receipt]};
   if(!save(p.profile,old,next,p.profile.stars))return no('Could not save the catch. Try reeling again before the fish gets away.');
   clearLine(p);p.fishingQuote=null;
   const caught=item(row);return yes('Caught a '+caught.name+'!',{caught});
  }
  if(!dealer(p))return no('Walk to Marina at the snack shop fish counter.');
  if(lines.has(p))return no('Reel in your line first.');
  if(op==='quote'){
   if(!old.inventory.length)return no('Your fish bag is empty.');
   const items=old.inventory.map(item), quote={quoteId:id(),items,total:items.reduce((s,r)=>s+r.value,0),expiresAt:now+60000};
   p.fishingQuote={...quote,key:bagKey(old.inventory)};
   return yes('Review your fish before selling.',{quote});
  }
  const q=p.fishingQuote;
  if(!id24(m.quoteId)||!q||q.quoteId!==m.quoteId||now>q.expiresAt||q.key!==bagKey(old.inventory))return no('Open a fresh fish sale preview.');
  if(!Number.isSafeInteger(p.profile.stars+q.total))return no('Your star balance is full.');
  const sold={quoteId:q.quoteId,total:q.total,count:q.items.length};
  const next={...old,inventory:[],sales:[...old.sales.slice(-99),sold]};
  if(!save(p.profile,old,next,p.profile.stars+q.total))return no('Could not save the sale. Your fish and stars are unchanged.');
  p.fishingQuote=null;
  return yes('Sold '+sold.count+' fish for '+sold.total+' stars!',{sold});
 }
 return {apply,population,snapshot,visual,update,moved,close};
}

