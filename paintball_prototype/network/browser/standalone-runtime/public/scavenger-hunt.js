import {businessAt} from './business-interiors.js';
import {scavengerSpots,scavengerSpot} from './scavenger-spots.js';
export const scavengerHunt=Object.freeze({version:1,rewardKind:'scavengerTrophy',title:'Town treasure hunt',items:Object.freeze([
 ['coin','Coin',-8,19,'Near the town store','scavenger/pickups/coin.glb'],
 ['gem','Gem',8,-24,'Look beside the park','scavenger/pickups/gem.glb'],
 ['ruby','Ruby',25,48,'Near the garden','scavenger/pickups/ruby.glb'],
 ['heart','Heart',-30,48,'Outside the nursery','scavenger/pickups/heart.glb'],
 ['star','Star',43,54,'Near the playground','scavenger/pickups/star.glb'],
 ['key','Key',-43,-18,'By the west neighborhood','scavenger/pickups/key.glb'],
 ['scroll','Scroll',43,18,'By the east neighborhood','scavenger/pickups/scroll.glb'],
 ['medallion','Medallion',46,-43,'Near the stage','scavenger/pickups/medallion.glb']
].map(([id,name,x,z,hint,asset])=>Object.freeze({id,name,x,z,hint,asset,radius:2.2}))) });
export const scavengerItem=id=>typeof id==='string'?scavengerHunt.items.find(i=>i.id===id):undefined;
export function atScavengerPoint(p,item){return !!p&&!!item&&p.interiorHome==null&&item.interiorHome==null&&item.room==null&&((item.interiorBusiness??null)===null||!!businessAt(item.interiorBusiness))&&(p.interiorBusiness??null)===(item.interiorBusiness??null)&&p.carId==null&&!p.rest&&!p.playground&&[p.x,p.z].every(Number.isFinite)&&Math.hypot(p.x-item.x,p.z-item.z)<=item.radius;}
export function normalizeScavenger(value){
 const v=value&&typeof value==='object'?value:{},completedAt=Number.isFinite(v.completedAt)&&v.completedAt>=0?v.completedAt:null;
 if(v.placements!==undefined&&v.placements!==null&&!Array.isArray(v.placements)||v.version>=3&&v.startedAt!==null&&v.startedAt!==undefined&&!Array.isArray(v.placements))throw Error('Invalid hunt placements save; preserve file and restore backup');
 const trophyAwarded=v.trophyAwarded===true||v.rewardClaimed===true||completedAt!==null;
 return {version:4,placements:Array.isArray(v.placements)?v.placements.map(p=>({...p,...((v.version??0)<4&&!Object.hasOwn(p??{},'interiorBusiness')?{interiorBusiness:null}:{})})):null,elapsedMs:Number.isSafeInteger(v.elapsedMs)&&v.elapsedMs>=0?v.elapsedMs:null,runId:typeof v.runId==='string'&&/^[a-f0-9]{24}$/.test(v.runId)?v.runId:null,startedAt:Number.isFinite(v.startedAt)&&v.startedAt>=0?v.startedAt:null,collected:[...new Set((Array.isArray(v.collected)?v.collected:[]).filter(id=>scavengerItem(id)))],completedAt,trophyAwarded,rewardClaimed:trophyAwarded};
}export function legacyScavengerPlacements(){return scavengerHunt.items.map(item=>({itemId:item.id,spotId:'legacy-'+item.id,x:item.x,z:item.z,hint:item.hint,radius:2.2,interiorBusiness:null}));}
export function createScavengerPlacements(random,previous=[]){
 const shuffle=list=>{const copy=[...list];for(let i=copy.length-1;i>0;i--){const j=random(i+1);if(!Number.isInteger(j)||j<0||j>i)throw Error('Invalid hunt random source');[copy[i],copy[j]]=[copy[j],copy[i]];}return copy;};
 const spots=shuffle(scavengerSpots).slice(0,scavengerHunt.items.length),items=shuffle(scavengerHunt.items);
 if(spots.length!==scavengerHunt.items.length)throw Error('Not enough hunt spots');
 let assigned=items.map((item,i)=>({itemId:item.id,...spots[i],spotId:spots[i].id,radius:2.2}));
 if(assigned.every(p=>previous?.some(old=>old.itemId===p.itemId&&old.spotId===p.spotId))){assigned=items.map((item,i)=>({itemId:item.id,...spots[(i+1)%spots.length],spotId:spots[(i+1)%spots.length].id,radius:2.2}));}
 return assigned.map(({id,...placement})=>({...placement,interiorBusiness:placement.interiorBusiness??null}));
}
export function validScavengerPlacements(placements){
 if(!Array.isArray(placements)||placements.length!==scavengerHunt.items.length||new Set(placements.map(p=>p?.itemId)).size!==scavengerHunt.items.length||new Set(placements.map(p=>p?.spotId)).size!==scavengerHunt.items.length)return false;
 return placements.every(p=>{
  const item=scavengerItem(p?.itemId);if(!item||typeof p.spotId!=='string')return false;
  const canonical=p.spotId==='legacy-'+item.id?item:scavengerSpot(p.spotId);
  return !!canonical&&Object.hasOwn(p,'interiorBusiness')&&p.interiorHome==null&&p.room==null&&(p.interiorBusiness===null||!!businessAt(p.interiorBusiness))&&p.interiorBusiness===(canonical.interiorBusiness??null)&&p.x===canonical.x&&p.z===canonical.z&&p.radius===2.2&&p.hint===canonical.hint;
 });
}