import {readFileSync} from 'node:fs';
const version=1;
const granted=s=>Number.isSafeInteger(s?.trophyInventoryVersion)&&s.trophyInventoryVersion>=version;
export function createPreviewHuntTrophy({store,kind}){
 if(kind!=='scavengerTrophy')throw Error('Unexpected Town Explorer trophy kind');
 const ownsPlaced=p=>store.state.homes.some(h=>h.owner===p.id&&Array.isArray(h.furniture)&&h.furniture.some(row=>row.kind===kind));
 function persist(p,next){
  const prior=p.previewScavenger, bag=p.furnitureInventory;
  let updatedBag=bag, updated=next;
  if(next.trophyAwarded===true&&!granted(next)){
   if(!bag||typeof bag!=='object'||Array.isArray(bag))throw Error('Invalid furniture inventory');
   const quantity=bag[kind]??0;
   if(!Number.isSafeInteger(quantity)||quantity<0)throw Error('Invalid trophy inventory');
   if(quantity===0&&!ownsPlaced(p))updatedBag={...bag,[kind]:1};
   updated={...next,trophyInventoryVersion:version};
  }
  p.previewScavenger=updated;
  p.furnitureInventory=updatedBag;
  try{store.save();}
  catch(error){
   // Legacy save's rename is the commit; daily backup errors come afterward.
   if(store.accountFile){
    try{
     const disk=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles[p.username];
     if(disk&&JSON.stringify(disk.previewScavenger)===JSON.stringify(updated)&&JSON.stringify(disk.furnitureInventory)===JSON.stringify(updatedBag))return;
    }catch{}
   }
   if(prior===undefined)delete p.previewScavenger;else p.previewScavenger=prior;
   if(bag===undefined)delete p.furnitureInventory;else p.furnitureInventory=bag;
   throw error;
  }
 }
 function reconcile(p){
  const s=p.previewScavenger;
  if(s?.trophyAwarded!==true||granted(s))return false;
  persist(p,s);
  return true;
 }
 return {persist,reconcile};
}


