import {readFileSync} from 'node:fs';
const keys=['fence','trees','decor'];
const doors=[[-51,-19],[-51,5],[-51,29],[51,-19],[51,5],[51,29]];
const clean=h=>Object.fromEntries(keys.map(k=>[k,h?.yardUpgrades?.[k]===true]));
export function createPreviewYards({store,rules}){
 const own=profile=>store.state.homes.find(h=>h.owner===profile.id&&doors[h.id]);
 function snapshot(profile){const h=own(profile);return {eligible:rules.yardUpgradeEligible(h,profile.id),flags:clean(h)};}
 function town(){return store.state.homes.filter(h=>doors[h.id]&&h.owner!==null&&h.variant==='family').map(h=>({plot:h.id,...clean(h)})).filter(h=>keys.some(k=>h[k]));}
 function apply(seat,m,now){
  const profile=seat.profile,h=own(profile);
  const bad=error=>({error});
  if(!Object.keys(m).every(k=>['type','action','operation','kind','requestId'].includes(k))||m.operation!=='buy'||typeof m.kind!=='string'||!Object.hasOwn(rules.yardUpgrades,m.kind)||typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return bad('Choose a yard improvement.');
  if(!rules.yardUpgradeEligible(h,profile.id))return bad('Only the owner of a Family home can improve its yard.');
  const prior=profile.yardReceipts.find(r=>r.requestId===m.requestId);
  if(prior)return prior.home===h.id&&prior.kind===m.kind?{text:'This yard purchase was already saved.'}:bad('This yard request was already used.');
  let position;
  const [x,z]=doors[h.id];
  if(seat.zone==='town'&&seat.grounded&&Math.abs(seat.y)<1.25&&now-seat.updated<=2500&&Math.hypot(seat.x-x,seat.z-z)<=7)
   position={x:seat.x,z:seat.z};
  const local=seat.petHome?.furniturePose;
  if(seat.zone==='private'&&seat.petHome?.plot===h.id&&seat.petHome.inRoom&&local&&now-local.at<=2000&&local.y<1.3)
   position={interiorHome:h.id,x:local.x,z:local.z};
  if(!position)return bad('Visit your own front yard or go inside your Family home first.');
  const before={stars:profile.stars,receipts:structuredClone(profile.yardReceipts),flags:structuredClone(h.yardUpgrades)};
  const wire={home:h.id,kind:m.kind,requestId:m.requestId};
  try{
   const error=store.yardUpgrade(profile,wire,position);
   if(error)return bad(error);
  }catch{
   let durable=false;
   try{
    const disk=JSON.parse(readFileSync(store.accountFile,'utf8')),p=disk.profiles[profile.username],home=disk.homes[h.id];
    durable=p?.stars===profile.stars&&JSON.stringify(p.yardReceipts)===JSON.stringify(profile.yardReceipts)&&JSON.stringify(home?.yardUpgrades)===JSON.stringify(h.yardUpgrades);
   }catch{}
   if(!durable){profile.stars=before.stars;profile.yardReceipts=before.receipts;h.yardUpgrades=before.flags;return bad('Could not save the yard improvement. Nothing was changed.');}
  }
  return {text:rules.yardUpgrades[m.kind].name+' installed.'};
 }
 return {snapshot,town,apply};
}

