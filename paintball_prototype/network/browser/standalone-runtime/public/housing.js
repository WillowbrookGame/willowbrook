// Play-only housing, funded with earned stars. No interest, deadlines or penalties.
export const bank=Object.freeze({x:-54,z:-49,radius:7});
export const starterMortgage=100;
export const homeVariants=Object.freeze({
 starter:Object.freeze({level:0,cost:0,rooms:1,w:7,d:7,maxX:2,maxZ:2}),
 cottage:Object.freeze({level:1,cost:200,rooms:2,w:9,d:8,maxX:3,maxZ:2}),
 family:Object.freeze({level:2,cost:300,rooms:3,w:11,d:10,maxX:4,maxZ:3})
});
// A home is one isolated instance. Rooms share local coordinates and connecting doors.
export const interiorRooms=Object.freeze([0,1,2].map(id=>Object.freeze({id,name:id===0?'Main room':'Room '+(id+1),x:id*12,z:0,w:12,d:10,maxX:4,maxZ:3})));
export const interiorSpawn=Object.freeze({x:0,y:0,z:3.5,yaw:0});
export function roomsForHome(variant){return interiorRooms.slice(0,homeVariants[variant]?.rooms||1);}
export function interiorRoomAt(variant,x,z){
 if(!Number.isFinite(x)||!Number.isFinite(z))return null;
 const count=homeVariants[variant]?.rooms||1;
 if(x< -5.5||x>(count-1)*12+5.5||Math.abs(z)>4.5)return null;
 for(let i=1;i<count;i++)if(Math.abs(x-(i*12-6))<.25&&Math.abs(z)>1.5)return null;
 return Math.max(0,Math.min(count-1,Math.floor((x+6)/12)));
}
export function canMoveInside(variant,from,to){
 if(!from||!to||interiorRoomAt(variant,from.x,from.z)===null||interiorRoomAt(variant,to.x,to.z)===null)return false;
 const count=homeVariants[variant]?.rooms||1;
 for(let i=1;i<count;i++){
  const wall=i*12-6;
  if((from.x<wall&&to.x>=wall)||(from.x>=wall&&to.x<wall)){
   const t=(wall-from.x)/(to.x-from.x),z=from.z+(to.z-from.z)*t;
   if(Math.abs(z)>1.5)return false;
  }
 }
 return true;
}
export const housing=Object.freeze({bank,starterMortgage,homeVariants,interiorRooms,interiorSpawn});





// Teller service zone is inside the bank, on the customer side of the counter.
export function atBankTeller(p){return !!p && p.interiorBusiness==='bank' && p.interiorHome==null && p.carId==null && Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.abs(p.x-bank.x)<=2.4&&p.z>=bank.z-.1&&p.z<=bank.z+2.5;}
