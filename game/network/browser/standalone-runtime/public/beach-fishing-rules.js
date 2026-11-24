import {beachWalkable} from './beach-layout.js';
export const fishingPole={x:2.8,z:2,radius:2.5};
export const fishShop={x:-19,z:27,radius:3};
export const fishingZones=[{id:'left',side:-1,x:-5},{id:'right',side:1,x:5}];
export const atFishingPier=(x,z)=>Number.isFinite(x)&&Number.isFinite(z)&&beachWalkable(x,z)&&Math.abs(x)<=1.65&&z<=-2&&z>=-34;
// Only reachable sand/dock edges may cast. Target always lies off the boards in water.
export function fishingCastTarget(x,z){
 if(!Number.isFinite(x)||!Number.isFinite(z)||!beachWalkable(x,z))return null;
 if(z>=1&&z<=4)return {x:Math.abs(x)<3?x+(x<0?-5:5):Math.abs(x-32)<6?x+(x<32?-7:7):x,z:-3};
 if(z<1&&Math.abs(x)<1.65)return {x:x<0?-5:5,z};
 if(z<1&&Math.abs(x-32)<5)return {x:x<32?25:39,z};
 return null;
}

// Match the rendered dock boards; sand remains at ground level.
export function beachStandingHeight(x,z){return Number.isFinite(x)&&Number.isFinite(z)&&beachWalkable(x,z)&&(z<1||Math.abs(x-32)<2.2&&z<14||x>21&&x<31&&z>6&&z<13)?.55:0;}

export const canReachFishingFish=(x,z,fish)=>!!fishingCastTarget(x,z)&&!!fish&&Number.isFinite(fish.x)&&Number.isFinite(fish.z)&&Math.hypot(x-fish.x,z-fish.z)<=9;
export const fishPopulationSpots=[...[-52,-44,-36,-28,-20,-12,12,20,44,52].map(x=>({x,z:-3})),...[-4,-12,-20,-28].flatMap(z=>[{x:-5,z},{x:5,z}]),{x:25,z:-4},{x:39,z:-4},{x:25,z:-10},{x:39,z:-10}];
