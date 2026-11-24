import {fishingPole,fishShop,fishingCastTarget,beachStandingHeight,canReachFishingFish,fishPopulationSpots} from './public/beach-fishing-rules.js';
import {randomBytes,randomInt} from 'node:crypto';
import {fishCatalog} from './public/beach-fish-catalog.js';
const fishByType=new Map(fishCatalog.map(f=>[f.id,f]));
export function normalizeFishProfile(p){
 if(p.fishInventory===undefined)p.fishInventory=[];
 if(p.fishSaleReceipts===undefined)p.fishSaleReceipts=[];
 const ids=new Set();
 if(!Array.isArray(p.fishInventory)||p.fishInventory.length>500)throw Error('Invalid fish inventory save; preserve file and restore backup');
 for(const f of p.fishInventory){if(!f||typeof f.id!=='string'||!/^[a-f0-9]{24}$/.test(f.id)||ids.has(f.id)||!fishByType.has(f.type))throw Error('Invalid fish inventory save; preserve file and restore backup');ids.add(f.id);}
 if(!Array.isArray(p.fishSaleReceipts)||p.fishSaleReceipts.some(r=>!r||typeof r.quoteId!=='string'||!/^[a-f0-9]{24}$/.test(r.quoteId)||!Number.isSafeInteger(r.total)||r.total<1||!Number.isSafeInteger(r.count)||r.count<1))throw Error('Invalid fish sale receipts; preserve file and restore backup');
}
const inventoryKey=items=>JSON.stringify(items.map(f=>[f.id,f.type]).sort((a,b)=>a[0].localeCompare(b[0])));
export function createBeachFishing({store,enabled=false,clock=Date.now,random=()=>randomInt(0x100000000)/0x100000000,id=()=>randomBytes(12).toString('hex')}){
 const quotes=new WeakMap(),fish=new Map(),activeCasters=new Set();let nextRefresh=clock()+30000+Math.floor(random()*40001);
 function spawnFish(){const candidates=fishPopulationSpots.filter(s=>![...fish.values()].some(f=>Math.hypot(f.x-s.x,f.z-s.z)<7)&&![...activeCasters].some(p=>p.fishCast&&Math.hypot(p.fishCast.x-s.x,p.fishCast.z-s.z)<=10));if(!candidates.length)return false;const spot=candidates[Math.min(candidates.length-1,Math.floor(random()*candidates.length))],kind=pick();const f={id:id(),...spot,size:.8+random()*.4,type:kind.id,owner:null};fish.set(f.id,f);return true;}
 if(enabled){const count=2+Math.floor(random()*9);for(let i=0;i<count;i++)spawnFish();}
 function population(now=clock()){if(enabled&&now>=nextRefresh){const target=2+Math.floor(random()*9);if(fish.size<2){for(let i=0;i<2&&fish.size<2;i++)if(!spawnFish())break;}else if(fish.size<target)spawnFish();else if(fish.size>target){const free=[...fish.values()].filter(f=>!f.owner);if(free.length)fish.delete(free[Math.floor(random()*free.length)].id);}nextRefresh=now+30000+Math.floor(random()*40001);}return [...fish.values()].map(({id,x,z,size,owner})=>({id,x,z,size,reserved:!!owner}));}

 const reply=(ok,text,extra={})=>({ok,text,...extra});
 const eligible=p=>enabled&&p.map==='beach'&&p.carId==null&&!p.rest&&!p.playground&&!p.beachSlide&&p.interiorHome==null&&p.interiorBusiness==null;
 const atPole=p=>Math.hypot(p.x-fishingPole.x,p.z-fishingPole.z)<=fishingPole.radius;
 const atWater=p=>fishingCastTarget(p.x,p.z);
 const atShop=p=>Math.hypot(p.x-fishShop.x,p.z-fishShop.z)<=fishShop.radius;
 function clear(p,putAway=false){activeCasters.delete(p);if(p.fishCast){const f=fish.get(p.fishCast.fishId);if(f?.owner===p)fish.delete(f.id);}p.fishCast=null;if(putAway){p.fishEquipped=false;quotes.delete(p);}}
 function pick(){let n=random()*fishCatalog.reduce((a,f)=>a+f.weight,0);for(const f of fishCatalog){n-=f.weight;if(n<0)return f;}return fishCatalog.at(-1);}
 function handle(p,m){
  if(!eligible(p))return reply(false,'Stand on the beach to go fishing');
  const now=clock();
  if(m.action==='equip'){if(!atPole(p))return reply(false,'Walk to the fishing poles on the pier');p.fishEquipped=true;return reply(true,'Fishing pole ready!');}
  if(m.action==='putAway'){clear(p,true);return reply(true,'Fishing pole put away');}
  if(m.action==='cancel'){const empty=p.fishCast?.empty===true;clear(p);quotes.delete(p);return reply(true,empty?'No fish took the bait':'Line reeled in');}
  if(m.action==='cast'){
   if(!p.fishEquipped)return reply(false,'Pick up a fishing pole first');
   if(!atWater(p))return reply(false,'Stand close to the water or on either pier to cast');
   if(p.fishCast)return reply(false,'Reel in your current line first');
   if(p.profile.fishInventory.length>=500)return reply(false,'Your fish bag is full. Sell your fish at the snack shop');
   const available=[...fish.values()].filter(f=>!f.owner&&canReachFishingFish(p.x,p.z,f)).sort((a,b)=>Math.hypot(p.x-a.x,p.z-a.z)-Math.hypot(p.x-b.x,p.z-b.z));
   const selected=m.fishId==null?available[0]:available.find(f=>f.id===m.fishId);
   if(!selected&&m.fishId!=null)return reply(false,'That fish is unavailable. Cast again without choosing it');
   if(!selected){p.moving=false;p.y=beachStandingHeight(p.x,p.z);p.fishCast={id:id(),fishId:null,empty:true,startedAt:now,nibbleAt:null,nibbles:[],biteAt:null,expiresAt:now+20000,...atWater(p),originX:p.x,originZ:p.z};activeCasters.add(p);return reply(true,'Line cast. Wait or reel in to try another spot');}
   selected.owner=p;
   p.moving=false;p.y=beachStandingHeight(p.x,p.z);
   const biteAt=now+4000+Math.floor(random()*4001),nibbleCount=1+Math.floor(random()*3),nibbles=Array.from({length:nibbleCount},(_,i)=>biteAt-(nibbleCount-i)*900);
   p.fishCast={id:id(),fishId:selected.id,empty:false,startedAt:now,nibbleAt:nibbles[0],nibbles,biteAt,expiresAt:biteAt+2500,x:selected.x,z:selected.z,originX:p.x,originZ:p.z};activeCasters.add(p);
   return reply(true,'Watch the shadow and wait for a bite');
  }
  if(m.action==='reel'){
   const cast=p.fishCast;if(!cast)return reply(false,'Cast your line first');if(cast.empty){clear(p);return reply(false,'No fish took the bait');}const hooked=fish.get(cast.fishId);const owned=hooked?.owner===p;clear(p);if(!owned)return reply(false,'That fish swam away');
   if(!atWater(p)||Math.hypot(p.x-cast.originX,p.z-cast.originZ)>.75)return reply(false,'Stay beside your fishing line');
   if(now<cast.biteAt)return reply(false,'Too soon! Wait for the bite before reeling');
   if(now>cast.expiresAt)return reply(false,'The fish got away. Try another cast');
   const kind=fishByType.get(hooked.type),caught={id:id(),type:kind.id};p.profile.fishInventory.push(caught);store.save();quotes.delete(p);
   return reply(true,'Caught a '+kind.name+'!',{caught:{...caught,name:kind.name,value:kind.value}});
  }
  if(m.action==='quote'){
   if(!atShop(p))return reply(false,'Walk to the snack shop fish counter');
   if(p.fishCast)return reply(false,'Reel in your line first');
   if(!p.profile.fishInventory.length)return reply(false,'Your fish bag is empty');
   const items=p.profile.fishInventory.map(f=>({...f,name:fishByType.get(f.type).name,value:fishByType.get(f.type).value}));
   const quote={quoteId:id(),items,total:items.reduce((n,f)=>n+f.value,0),expiresAt:now+60000};quotes.set(p,{...quote,key:inventoryKey(p.profile.fishInventory)});
   return reply(true,'Review your fish before selling',{quote});
  }
  if(m.action==='sell'){
   if(!atShop(p))return reply(false,'Stay at the snack shop fish counter');
   if(typeof m.quoteId!=='string')return reply(false,'Review your fish before selling');
   if(p.profile.fishSaleReceipts.some(r=>r.quoteId===m.quoteId))return reply(false,'These fish were already sold');
   const q=quotes.get(p);
   if(!q||q.quoteId!==m.quoteId||now>q.expiresAt)return reply(false,'Open a fresh fish sale preview');
   if(q.key!==inventoryKey(p.profile.fishInventory)){quotes.delete(p);return reply(false,'Your fish bag changed. Review it again before selling');}
   if(!Number.isSafeInteger(p.profile.stars+q.total))return reply(false,'Your star balance is full');
   p.profile.stars+=q.total;p.profile.fishInventory=[];p.profile.fishSaleReceipts.push({quoteId:q.quoteId,total:q.total,count:q.items.length});p.profile.fishSaleReceipts=p.profile.fishSaleReceipts.slice(-100);quotes.delete(p);store.save();
   return reply(true,'Sold '+q.items.length+' fish for '+q.total+' stars!',{sold:{quoteId:q.quoteId,total:q.total,count:q.items.length}});
  }
  return reply(false,'Choose a valid fishing action');
 }
 function update(p,now=clock()){if(!p.fishCast)return null;if(!eligible(p)||!atWater(p)||Math.hypot(p.x-p.fishCast.originX,p.z-p.fishCast.originZ)>.75){clear(p);return reply(false,'Line reeled in when you moved away');}if(now>p.fishCast.expiresAt){const empty=p.fishCast.empty===true;clear(p);return reply(false,empty?'No fish took the bait':'The fish got away. Try another cast');}return null;}
 function visual(p){if(!p.fishCast)return null;const {originX,originZ,...visual}=p.fishCast;return visual;}
 return {handle,clear,update,visual,population};
}
