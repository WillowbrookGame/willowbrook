import {readFileSync} from 'node:fs';

const doors=[[-51,-19],[-51,5],[-51,29],[51,-19],[51,5],[51,29]];
const rooms={starter:1,cottage:2,family:3};
const has=(o,k)=>Object.hasOwn(o,k);
const no=error=>({error});
const unavailable=()=>no('This home is not available to visit.');
const exact=(m,...keys)=>Object.keys(m).length===keys.length+2&&keys.every(k=>has(m,k));
const number=(v,min,max)=>Number.isFinite(v)&&v>=min&&v<=max;
const near=(p,i,now)=>p.zone==='town'&&p.grounded&&number(p.y,-.8,.8)&&now-p.updated<=2000&&p.updated<=now&&Math.hypot(p.x-doors[i][0],p.z-doors[i][1])<=3;
const variant=h=>h&&has(rooms,h.variant)?h.variant:null;
const inside=(v,x,z)=>number(x,-5.85,(rooms[v]-1)*12+5.85)&&number(z,-4.86,4.86);
const ownPlot=p=>p.petHome?.inRoom&&p.zone==='private'?p.petHome.plot:null;

export function createHomeVisits({store,admitted,send,furnitureCatalog,character}){
 const guests=new Map(), poses=new Map();
 const home=i=>Number.isInteger(i)&&doors[i]?store.state.homes[i]:null;
 const enabledOwner=h=>h?.owner!=null&&Object.values(store.state.profiles).some(p=>p.id===h.owner&&!p.disabled&&!p.mustChangePassword);
 function release(p){guests.delete(p);poses.delete(p);}
 function eject(p){
  release(p);
  if(admitted(p))send(p,{type:'homeVisit',action:'eject',text:'This home is no longer open to visitors.'});
 }
 function validGuest(p,g,now){
  const h=home(g.plot);
  return admitted(p)&&h?.owner===g.owner&&h.locked!==true&&variant(h)===g.variant&&enabledOwner(h)
    &&(g.inside?p.zone==='private'&&now-p.updated<8000:now-g.at<=5500);
 }
 function trim(now){
  for(const [p,g] of guests)if(!validGuest(p,g,now))eject(p);
  for(const [p,row] of poses)if(!admitted(p)||now-row.at>3000)poses.delete(p);
 }
 function here(p,now){
  if(!admitted(p)||p.zone!=='private'||now-p.updated>8000)return null;
  const g=guests.get(p);
  if(g?.inside&&validGuest(p,g,now))return {plot:g.plot,owner:false};
  const i=ownPlot(p),h=home(i);
  if(variant(h)&&h.owner===p.profile.id)return {plot:i,owner:true};
  return null;
 }
 function remember(p,m,now){
  if(!exact(m,'x','y','z','yaw','moving','grounded'))return;
  const state=here(p,now),old=poses.get(p);if(!state||old&&now-old.at<45)return;
  const h=home(state.plot);
  if(!inside(h.variant,m.x,m.z)||!number(m.y,-.2,4.3)||!number(m.yaw,-Math.PI,Math.PI)||typeof m.moving!=='boolean'||typeof m.grounded!=='boolean')return;
  poses.set(p,{plot:state.plot,at:now,x:m.x,y:m.y,z:m.z,yaw:m.yaw,moving:m.moving,grounded:m.grounded});
 }
 function persist(h,value){
  const old=h.locked;h.locked=value;
  try{store.save();}catch(e){
   try{const disk=JSON.parse(readFileSync(store.accountFile,'utf8'));const row=disk.homes[h.id];if(row?.owner===h.owner&&row.locked===value)return true;}catch{}
   h.locked=old;return false;
  }
  return true;
 }
 function request(p,m,now,{busy=false}={}){
  trim(now);
  if(!admitted(p))return unavailable();
  if(m.action==='pose'){remember(p,m,now);return {silent:true};}
  if(m.action==='leave'&&exact(m)){release(p);return {};}
  if(m.action==='enter'&&exact(m,'plot')){
   const h=home(m.plot);
   if(!variant(h)||h.owner===p.profile.id||h.locked===true||!enabledOwner(h)||busy||p.carId!=null||p.vehicleSeat!=null||!near(p,m.plot,now)||guests.has(p))return unavailable();
   p.petHome=null;
   guests.set(p,{plot:m.plot,owner:h.owner,variant:h.variant,at:now,inside:false});
   return {plot:m.plot,variant:h.variant};
  }
  if(m.action==='lock'&&exact(m,'locked')&&typeof m.locked==='boolean'){
   const state=here(p,now);
   if(!state?.owner)return no('Only the homeowner can change the lock.');
   const h=home(state.plot);
   if(h.locked!==m.locked&&!persist(h,m.locked))return no('Could not save the lock. Nothing was changed.');
   if(m.locked)for(const [other,g] of guests)if(g.plot===state.plot)eject(other);
   return {locked:h.locked===true};
  }
  return no('Choose a home visit action.');
 }
 function moved(p,pose,now){
  const g=guests.get(p);
  if(!g){if(pose.zone!=='private')poses.delete(p);return;}
  if(pose.zone==='private'&&!g.inside&&now-g.at<=5500&&near(p,g.plot,now)){g.inside=true;return;}
  if(pose.zone==='private'&&g.inside)return;
  if(pose.zone==='town'&&!g.inside&&now-g.at<=5500&&Math.hypot(pose.x-doors[g.plot][0],pose.z-doors[g.plot][1])<=3)return;
  release(p);
 }
 function decor(h){
  return h.furniture.slice(0,20).flatMap((f,i)=>{
   if(typeof f.kind!=='string'||!has(furnitureCatalog,f.kind)||!Number.isInteger(f.room??0)||(f.room??0)>=rooms[h.variant]||(f.room??0)<0||!number(f.x,-5,5)||!number(f.z,-4,4))return [];
   return [{id:'decor-'+i,kind:f.kind,room:f.room??0,x:f.x,z:f.z,y:number(f.y,0,4)?f.y:0,rotation:Number.isInteger(f.rotation)&&f.rotation>=0&&f.rotation<=3?f.rotation:0}];
  });
 }
 function snapshot(viewer,now){
  const state=here(viewer,now);if(!state)return null;
  const h=home(state.plot);
  const visitors=[];
  for(const [other,row] of poses){
   if(other===viewer||row.plot!==state.plot||now-row.at>3000||here(other,now)?.plot!==state.plot)continue;
   const {x,y,z,yaw,moving,grounded}=row;
   visitors.push({id:other.profile.id,alias:other.profile.username,character:character(other.profile),x,y,z,yaw,moving,grounded});
  }
  return {variant:h.variant,owner:state.owner,...(state.owner?{locked:h.locked===true}:{decor:decor(h)}),visitors};
 }
 return {trim,request,moved,release,snapshot,guest:p=>guests.has(p)};
}
