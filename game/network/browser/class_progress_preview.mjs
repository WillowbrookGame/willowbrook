import {readFileSync} from 'node:fs';

// Godot room-local coordinates. Legacy rules are called only after the
// player is at the public side of the librarian's desk in the current room.
const maxPoseAge=1800;
const librarian={x:0,z:-2};
const legacyDesk={x:-16,z:-23,interiorBusiness:'library',interiorHome:null,carId:null};
const fields=['type','action','operation','course','amount','tier','paid','requestId'];
const validId=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(id);

export function createPreviewClasses(store,{classTiers,workDefinitions,workReward}){
 const courses=Object.keys(workDefinitions);
 const snapshot=p=>Object.fromEntries(courses.map(course=>{
  const {tier,paid}=p.classes[course];
  return [course,{tier,paid,reward:workReward(course,p.classes)}];
 }));
 function apply(peer,m,now){
  if(m.operation!=='pay'||Object.keys(m).length!==fields.length||!fields.every(k=>Object.hasOwn(m,k))
   ||typeof m.course!=='string'||!courses.includes(m.course)||!validId(m.requestId)
   ||!Number.isSafeInteger(m.amount)||m.amount<1||m.amount>200||!Number.isInteger(m.tier)||m.tier<0||m.tier>=classTiers.length
   ||!Number.isInteger(m.paid)||m.paid<0||m.paid>=classTiers[m.tier].cost)return {error:'Choose a whole-star class payment.'};
  const p=peer.profile;
  if(peer.zone!=='library'||peer.grounded!==true||![peer.x,peer.y,peer.z,peer.updated].every(Number.isFinite)
   ||peer.updated<=0||now-peer.updated<0||now-peer.updated>maxPoseAge
   ||Math.abs(peer.y)>=1.35||peer.z<=librarian.z+.45||Math.hypot(peer.x-librarian.x,peer.z-librarian.z)>4.3)
   return {error:'Walk to the librarian before paying tuition.'};
  const receipt=p.classReceipts.find(r=>r.requestId===m.requestId);
  if(receipt)return receipt.name===m.course&&receipt.amount===m.amount?{text:'That payment was already saved.'}:{error:'That payment ID was already used.'};
  const before=p.classes[m.course];
  if(before.tier!==m.tier||before.paid!==m.paid)return {error:'Tuition changed. Review the current amount before paying.'};
  const oldStars=p.stars,oldClass={...before},oldReceiptCount=p.classReceipts.length;
  const success=()=>before.tier>oldClass.tier
   ?{text:'Tier '+before.tier+' completed! '+m.course+' now pays '+workReward(m.course,p.classes)+' stars.'}
   :{text:'Paid '+m.amount+' saved star'+(m.amount===1?'':'s')+' toward tuition.'};
  try{
   const error=store.takeClass(p,{name:m.course,amount:m.amount,requestId:m.requestId},legacyDesk);
   return error?{error}:success();
  }catch{
   // Legacy save may fail creating its daily backup after the atomic live
   // file replace. Confirm the exact desired persisted fields in that case.
   try{
    const saved=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles[p.username];
    const r=saved?.classReceipts?.[oldReceiptCount];
    if(r?.requestId===m.requestId&&r.name===m.course&&r.amount===m.amount
     &&saved.stars===p.stars&&saved.classes?.[m.course]?.tier===before.tier&&saved.classes?.[m.course]?.paid===before.paid)return success();
   }catch{}
   p.stars=oldStars;Object.assign(before,oldClass);p.classReceipts.length=oldReceiptCount;
   return {error:'Could not save tuition. Your stars were not changed.'};
  }
 }
 return {snapshot,apply};
}
