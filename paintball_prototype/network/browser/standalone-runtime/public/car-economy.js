import {inScooterBay} from './scooter-parking.js';
import {plots,onRoad} from './town-layout.js';
export const carLot=Object.freeze({x:19,z:3,radius:3});
export const carTiers=Object.freeze([{name:'Town car',cost:30,model:'sedan'},{name:'Blue town car',cost:60,model:'sedan'},{name:'Sporty car',cost:100,model:'sedan-sports'}].map(Object.freeze));
export function atCarLot(p){return p&&p.interiorHome==null&&p.interiorBusiness==null&&p.carId==null&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.hypot(p.x-carLot.x,p.z-carLot.z)<=carLot.radius;}
export function drivewayFor(id){const p=plots[id];return Number.isInteger(id)&&p?{x:Math.sign(p[0])*41,z:p[1]+6,yaw:p[0]<0?-Math.PI/2:Math.PI/2}:null;}
export function onVehicleGround(x,z){return onRoad(x,z)||inScooterBay(x,z)||plots.some((_,i)=>{const d=drivewayFor(i);return Math.abs(z-d.z)<=2&&Math.abs(x)>=34&&Math.abs(x)<=41.25;});}
export function lotParking(id=0){return {x:8+(Math.abs(id)%6)*8,z:12,yaw:Math.PI/2};}
export function validCarSpot(p){return p&&[p.x,p.z,p.yaw].every(Number.isFinite)&&onVehicleGround(p.x,p.z);}

// Both UI and protocol use the authoritative speed, not keyboard state.
export function vehicleStopped(car){return !!car&&Number.isFinite(car.speed)&&Math.abs(car.speed)<=0.01;}
export function canParkAtHome(car,profileId,homeId,seat){const d=drivewayFor(homeId);return vehicleStopped(car)&&car.kind==='car'&&car.ownerId===profileId&&seat==='driver'&&!!d&&Math.hypot(car.x-d.x,car.z-d.z)<=5;}
