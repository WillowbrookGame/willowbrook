
import {readFileSync} from 'node:fs';

const BAY=[[-22,3.5],[-20,3.5],[-18,3.5]];
const ROAD_Z=[-36,-12,12,36], ROAD_X=[-72,-36,0,36,72];
const layout=JSON.parse(readFileSync(new URL('../../vehicles/side_driveways.json',import.meta.url),'utf8'));
const PLOT_ROWS=Object.freeze([-1,1].flatMap(side=>layout.rows.map(row=>Object.freeze({
 side,row,houseX:side*layout.houseCenterX,x:side*layout.houseCenterX+layout.sideOffsetX,z:row+layout.parkZ,yaw:Math.PI
}))));
export const driveways=PLOT_ROWS;
const SLOT='previewVehicleParkingV1';
const clamp=(v,a,b)=>Math.max(a,Math.min(v,b));
const wrap=v=>Math.atan2(Math.sin(v),Math.cos(v));
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const OVER=0.12, TIMEOUT=500;
const coast=(v,n)=>Math.sign(v)*Math.max(0,Math.abs(v)-n);
const atBay=(x,z)=>(x>=-25&&x<=-15&&z>=0.5&&z<=5.5)||(x>=-23&&x<=-17&&z>=5&&z<=9);
export const drivewayPlot=(x,z)=>PLOT_ROWS.findIndex(d=>Math.abs(x-d.x)<=layout.width*0.5&&z>=d.row+layout.rowStartZ&&z<=d.row+layout.rowEndZ);
const formerPad=(x,z,d)=>!!d&&Math.abs(x-d.side*layout.oldCenterX)<=layout.oldHalfX&&Math.abs(z-d.row-layout.oldZ)<=layout.oldHalfZ;
const samePose=(a,b)=>!!a&&!!b&&['x','z','yaw'].every(k=>a[k]===b[k]);
function clearOfHomes(c,x,z,yaw){
 const width=c.kind==='car'?.98:.27,length=c.kind==='car'?1.84:.61;
 const cw=Math.abs(Math.cos(yaw)),sw=Math.abs(Math.sin(yaw));
 const hx=width*cw+length*sw,hz=length*cw+width*sw;
 return !PLOT_ROWS.some(d=>Math.abs(x-d.houseX)<layout.familyWidth/2+hx&&z+hz>d.row+layout.houseFrontZ-layout.familyDepth&&z-hz<d.row+layout.houseFrontZ);
}
const pose=(x,z,yaw)=>({x,z,yaw});
export function validVehicleGround(x,z){
 if(!Number.isFinite(x)||!Number.isFinite(z))return false;
 if(atBay(x,z)||drivewayPlot(x,z)>=0||ROAD_Z.some(row=>Math.abs(z-row)<=3.6&&Math.abs(x)<=76.2))return true;
 return ROAD_X.some(col=>Math.abs(x-col)<=4.2&&ROAD_Z.some(row=>Math.abs(z-row)<=4.2)||Math.abs(x-col)<=3.6&&Math.abs(z)<=40.2);
}

export function createVehicleWorld(store,online,playing=()=>false,legacyValid=()=>false){
 const cars=new Map();
 BAY.forEach(([x,z],i)=>cars.set('s'+i,{id:'s'+i,kind:'scooter',tier:0,x,z,yaw:Math.PI,speed:0,driver:null,passenger:null,input:null}));
 const carFor=p=>cars.get('a'+p.profile?.id);
 const open=(x,z,except,gap)=>![...cars.values()].some(c=>c!==except&&distance(c,{x,z})<gap);
 const parking=except=>{
  for(const z of [12,-12,36,-36])for(const x of [24,16,32,8,40,48,56,-8,-16,-24,-32,-40,-48,-56]){
   if(open(x,z,except,4.6))return {x,z,yaw:-Math.PI/2};
  }
  return null;
 };
 const ownedDriveway=p=>{
  const h=store.state.homes.find(plot=>plot.owner===p.profile.id);
  return h&&Number.isInteger(h.id)?(PLOT_ROWS[h.id]??null):null;
 };
 function sync(p){
  const owned=p.profile?.ownedCar;
  if(!owned)return;
  const old=carFor(p);
  if(old){old.tier=owned.tier;return;}
  const own=ownedDriveway(p);
  const saved=p.profile[SLOT];
  const modern=Number.isFinite(saved?.yaw)&&samePose(saved?.legacy,owned)
   ?pose(saved.x,saved.z,wrap(saved.yaw)):null;
  const original=pose(owned.x,owned.z,wrap(owned.yaw+Math.PI));
  const wasPad=PLOT_ROWS.some(d=>formerPad(original.x,original.z,d));
  const candidate=modern??(formerPad(original.x,original.z,own)?pose(own.x,own.z,own.yaw):wasPad?null:original);
  const loc=candidate&&validVehicleGround(candidate.x,candidate.z)&&clearOfHomes({kind:'car'},candidate.x,candidate.z,candidate.yaw)&&open(candidate.x,candidate.z,null,4.4)?candidate:parking(null);
  if(loc)cars.set('a'+p.profile.id,{id:'a'+p.profile.id,kind:'car',owner:p.profile.id,tier:owned.tier,...loc,speed:0,driver:null,passenger:null,input:null});
 }
 function persist(c){
  if(c.kind!=='car')return true;
  const owner=Object.values(store.state.profiles).find(p=>p.id===c.owner);
  if(!owner?.ownedCar)return false;
  const old={...owner.ownedCar},previous=owner[SLOT];
  const modern=pose(c.x,c.z,wrap(c.yaw));
  let legacy=pose(c.x,c.z,wrap(c.yaw+Math.PI));
  if(!legacyValid(legacy)){
   // The old save reader may sanitize a new side lane back to its road.
   // Keep a legal compatibility pose without losing the exact current position.
   const d=PLOT_ROWS[drivewayPlot(c.x,c.z)];
   const road=d?pose(d.x,d.row+layout.roadZ,legacy.yaw):null;
   legacy=road&&legacyValid(road)?road:legacyValid(old)?pose(old.x,old.z,old.yaw):pose(16,12,Math.PI/2);
  }
  Object.assign(owner.ownedCar,legacy);
  owner[SLOT]={...modern,legacy};
  try{store.save();return true;}catch{
   try{
    const saved=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles?.[owner.username];
    if(saved&&samePose(saved.ownedCar,owner.ownedCar)&&saved.ownedCar.tier===owner.ownedCar.tier&&samePose(saved[SLOT],modern)&&samePose(saved[SLOT].legacy,legacy))return true;
   }catch{}
   owner.ownedCar=old;
   if(previous===undefined)delete owner[SLOT];else owner[SLOT]=previous;
   return false;
  }
 }
 const fresh=(p,now)=>p.zone==='town'&&p.grounded&&Math.abs(p.y)<1&&now-p.updated<=2500;
 const get=p=>p.vehicleSeat?cars.get(p.vehicleSeat.car):null;
 function position(c,seat){
  const side=c.kind==='car'?(seat==='driver'?-.50:.50):0;
  const y=c.kind==='car'?0.48:0.22;
  return {x:c.x+Math.cos(c.yaw)*side,z:c.z-Math.sin(c.yaw)*side,y,yaw:c.yaw,moving:Math.abs(c.speed)>OVER};
 }
 function broadcastPose(p,c){Object.assign(p,position(c,p.vehicleSeat.seat),{grounded:false});}
 function safeExit(p,c,side){
  const radius=c.kind==='scooter'?1.15:2.3;
  const cos=Math.cos(c.yaw),sin=Math.sin(c.yaw);
  for(const [a,b] of [[radius*side,0],[-radius*side,0],[radius*side,1.5],[-radius*side,1.5],[0,-2.3],[0,2.3]]){
   const x=c.x+cos*a+sin*b,z=c.z-sin*a+cos*b;
   if(validVehicleGround(x,z)&&open(x,z,c,2.1)&&!online().some(q=>q!==p&&q.zone==='town'&&!q.vehicleSeat&&distance(q,{x,z})<.8))return {x,z};
  }
  return null;
 }
 function release(p,forced=false){
  const c=get(p);
  if(!c){p.vehicleSeat=null;return {text:'Already on foot.'};}
  if(!forced&&Math.abs(c.speed)>OVER)return {error:'Let the vehicle stop before getting out.'};
  const seat=p.vehicleSeat.seat;
  const landing=safeExit(p,c,seat==='driver'?-1:1);
  if(!forced&&!landing)return {error:'Stop somewhere with room to get out.'};
  if(seat==='driver'){c.input=null;c.speed=0;}
  c[seat]=null;
  p.vehicleSeat=null;
  Object.assign(p,landing??{x:c.x,z:c.z},{y:0,grounded:true,moving:false});
  const saved=persist(c);
  return {text:saved?'Back on foot.':'Back on foot. Parking position could not be saved.',exit:{x:p.x,z:p.z}};
 }
 function call(p,m,now){
  const own=carFor(p), c=get(p);
  if(m.operation==='exit')return release(p);
  if(m.operation==='enter'){
   const target=cars.get(m.car), seat=m.seat;
   if(c||playing(p)||!fresh(p,now)||!target||!['driver','passenger'].includes(seat)||distance(p,target)>3.2||
      Math.abs(target.speed)>OVER||target[seat]!==null||
      (seat==='passenger'?target.kind!=='car':target.owner!=null&&target.owner!==p.profile.id))
    return {error:'Choose an empty seat on a stopped vehicle nearby.'};
   target[seat]=p.profile.id;p.vehicleSeat={car:target.id,seat};broadcastPose(p,target);
   return {text:seat==='driver'?'Drive with WASD or the thumbstick. Release to stop.':'Riding along. Wait until stopped to get out.'};
  }
  if(m.operation==='recall'){
   const dest=m.destination==='lot'&&distance(p,{x:19,z:3})<=3?parking(own):m.destination==='home'?ownedDriveway(p):null;
   if(!own||!fresh(p,now)||c||!dest||m.destination==='home'&&distance(p,dest)>5||own.driver!=null||own.passenger!=null||!open(dest.x,dest.z,own,4.4))
    return {error:'Walk to the lot or your own driveway. All car seats must be empty.'};
   const old={x:own.x,z:own.z,yaw:own.yaw};
   Object.assign(own,dest);
   if(!persist(own)){Object.assign(own,old);return {error:'Could not save the recalled position.'};}
   return {text:'Your car is parked nearby.'};
  }
  if(m.operation==='park'&&c===own&&p.vehicleSeat?.seat==='driver'){
   const home=ownedDriveway(p);
   if(!home||distance(c,home)>5||Math.abs(c.speed)>OVER||c.passenger!==null||!open(home.x,home.z,c,4.4))return {error:'Stop near your empty home driveway and let the passenger out first.'};
   const old={x:c.x,z:c.z,yaw:c.yaw};
   Object.assign(c,home);
   const answer=release(p);
   if(answer.error)Object.assign(c,old);
   return answer.error?answer:{...answer,text:'Parked at your home.'};
  }
  if(m.operation==='return'&&c?.kind==='scooter'&&p.vehicleSeat?.seat==='driver'){
   if(!atBay(c.x,c.z)||Math.abs(c.speed)>OVER)return {error:'Stop in the scooter bay first.'};
   const bay=BAY.map(([x,z])=>({x,z})).find(q=>open(q.x,q.z,c,1.4));
   if(!bay)return {error:'The scooter rack is full.'};
   const old={x:c.x,z:c.z,yaw:c.yaw};
   Object.assign(c,bay,{yaw:Math.PI});
   const answer=release(p);
   if(answer.error)Object.assign(c,old);
   return answer.error?answer:{...answer,text:'Scooter returned.'};
  }
  return {error:'That vehicle action is unavailable.'};
 }
 function input(p,m,now){
  const c=get(p);
  if(c&&p.vehicleSeat.seat==='driver'&&c.driver===p.profile?.id&&p.zone==='town'&&
    [m.throttle,m.steer].every(n=>Number.isFinite(n)&&Math.abs(n)<=1))c.input={throttle:m.throttle,steer:m.steer,at:now};
 }
 function tick(now,dt){
  for(const c of cars.values()){
   const impulse=c.driver!==null&&c.input&&now-c.input.at<=TIMEOUT?c.input:null;
   if(!impulse){c.speed=0;c.input=null;continue;}
   const steps=Math.max(1,Math.ceil(dt/.025)),step=dt/steps,limit=c.kind==='scooter'?7:10;
   for(let i=0;i<steps;i++){
    c.speed=clamp(c.speed+impulse.throttle*7*step,c.kind==='scooter'?-3.5:-4,limit);
    if(!impulse.throttle)c.speed=coast(c.speed,5*step);
    const k=clamp((Math.abs(c.speed)-2)/(limit-2),0,1),curve=k*k*(3-2*k);
    const steer=1.8+((c.kind==='scooter'?1.05:.85)-1.8)*curve;
    const turned=wrap(c.yaw-impulse.steer*steer*step*(c.speed<-.01?-1:1));
    if(clearOfHomes(c,c.x,c.z,turned))c.yaw=turned;
    const x=c.x-Math.sin(c.yaw)*c.speed*step,z=c.z-Math.cos(c.yaw)*c.speed*step;
    const gap=.58*(c.kind==='car'?3.7:1.2);
    if(validVehicleGround(x,z)&&clearOfHomes(c,x,z,c.yaw)&&open(x,z,c,gap)){c.x=x;c.z=z;}else{c.speed=0;break;}
   }
  }
  for(const p of online()){const c=get(p);if(c)broadcastPose(p,c);}
 }
 function view(viewer){
  const own=carFor(viewer);
  const ableRecall=own&&own.driver===null&&own.passenger===null;
  const home=ownedDriveway(viewer);
  const parkHome=!!home&&own?.driver===viewer.profile.id&&own.passenger===null&&Math.abs(own.speed)<=OVER&&distance(own,home)<=5;
  return {rows:[...cars.values()].map(c=>({id:c.id,kind:c.kind,tier:c.tier,x:c.x,z:c.z,yaw:c.yaw,speed:c.speed,driver:c.driver,passenger:c.passenger,canDrive:c.kind==='scooter'||c.owner===viewer.profile.id})),
   self:viewer.vehicleSeat??null,recallHome:!!ableRecall&&!!home&&distance(viewer,home)<=5,parkHome};
 }
 return {sync,call,input,tick,view,release,get,canPurchase:p=>!get(p)&&!playing(p)&&(!carFor(p)||carFor(p).driver===null&&carFor(p).passenger===null), parkingAvailable:()=>!!parking(null)};
}

