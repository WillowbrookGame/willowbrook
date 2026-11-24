import {readFileSync} from 'node:fs';

const validRequestId=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(id);
const fields=new Set(['type','action','operation','expectedTier','requestId']);
const fail=error=>({error});

export function createPreviewVehicles(store){
 function snapshot(profile){
  const tier=profile.ownedCar?.tier;
  return {tier:Number.isInteger(tier)&&tier>=0&&tier<=2?tier:-1};
 }
 function apply(p,m,now=Date.now()){
  const profile=p.profile;
  if(!profile||profile.disabled||profile.mustChangePassword||store.state.profiles[profile.username]!==profile)return fail('Sign in first.');
  if(!['buy','upgrade'].includes(m.operation)||!validRequestId(m.requestId)||
     !Number.isInteger(m.expectedTier)||m.expectedTier < -1||m.expectedTier>1||
     Object.keys(m).some(k=>!fields.has(k)))return fail('Choose a current Willow Wheels offer.');
  if(p.zone!=='town'||!p.grounded||Math.abs(p.y)>=1||now-p.updated>2500||
     !Number.isFinite(p.x)||!Number.isFinite(p.z)||Math.hypot(p.x-19,p.z-3)>3)return fail('Walk to Willow Wheels on foot first.');
  const old={stars:profile.stars,ownedCar:structuredClone(profile.ownedCar),carReceipts:structuredClone(profile.carReceipts)};
  const original=old.carReceipts.find(r=>r.requestId===m.requestId);
  if(original)return original.action===m.operation&&original.expectedTier===m.expectedTier
   ?{text:'This Willow Wheels purchase was already saved.'}:fail('That purchase request was used for a different offer.');
  let error;
  try{error=store.carShop(profile,{action:m.operation,expectedTier:m.expectedTier,requestId:m.requestId},{x:p.x,z:p.z});}
  catch{
   // Legacy atomic primary write can commit before its daily backup fails.
   let committed=false;
   try{
    const saved=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles?.[profile.username];
    const wallet=obj=>[obj.stars,obj.ownedCar,obj.carReceipts];
    committed=saved?.carReceipts?.some(r=>r.requestId===m.requestId)&&JSON.stringify(wallet(saved))===JSON.stringify(wallet(profile));
   }catch{}
   if(!committed){Object.assign(profile,old);return fail('Could not save your purchase. No stars were spent.');}
  }
  if(error)return fail(error);
  return {text:m.operation==='buy'?'Your car purchase is saved. Find your car parked on the road.':'Your car upgrade is saved.'};
 }
 return {snapshot,apply};
}

