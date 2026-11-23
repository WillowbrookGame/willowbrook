// Ephemeral spot leases; no account data is saved.
export const boarding={'swing-0':[51,49.8],slide:[43.15,45.1],'seesaw-0':[42.5,53.55],'seesaw-1':[42.5,56.45]};
export const SWING_BACK_ENTRY=[51,44.2];
export const SLIDE_DURATION_MS=4600;
export function createPlayground({admitted}){
 const holds=new Map();
 function release(p){for(const [k,v] of holds)if(v.peer===p)holds.delete(k);}
 function trim(now){for(const [k,{peer,at}] of holds)
  if(!admitted(peer)||peer.zone!=='town'||now-peer.updated>3500||(k==='slide'&&now-at>=SLIDE_DURATION_MS))holds.delete(k);}
 function own(p){for(const [k,v] of holds)if(v.peer===p)return k;return '';}
 function handle(p,m,now){
  trim(now);
  if(!admitted(p)||p.zone!=='town')return {error:'Go to the town playground first.'};
  const current=own(p);
  if(m.action==='exit'&&Object.keys(m).length===2){
   if(current==='slide')return {error:'Let the slide finish first.'};
   release(p);return {};
  }
  if(m.action!=='board'||Object.keys(m).length!==4||m.onFoot!==true||typeof m.target!=='string'||!Object.hasOwn(boarding,m.target))return {error:'Choose a playground boarding spot.'};
  if(current===m.target)return {};
  if(current)return {error:'Step off first.'};
  const [x,z]=boarding[m.target];
  const distance=Math.hypot(p.x-x,p.z-z);
  const near=m.target==='swing-0'?Math.min(distance,Math.hypot(p.x-SWING_BACK_ENTRY[0],p.z-SWING_BACK_ENTRY[1])):distance;
  if(p.carId!=null||!p.grounded||![p.x,p.z,p.y,p.updated].every(Number.isFinite)||Math.abs(p.y)>.8||now-p.updated>2000||near>2)
   return {error:'Walk to the boarding spot first.'};
  if(holds.has(m.target))return {error:'Someone is using this spot.'};
  holds.set(m.target,{peer:p,at:now});
  return {};
 }
 function moved(p,pose){if(pose.zone!=='town')release(p);}
 function active(now){trim(now);return [...holds].map(([target,v])=>({target,ageMs:Math.min(Math.max(0,now-v.at),86400000)}));}
 return {handle,moved,release,active,own};
}
