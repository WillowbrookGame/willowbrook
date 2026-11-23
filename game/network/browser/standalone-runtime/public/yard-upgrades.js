import {plots} from './town-layout.js';
import {homeVariants,interiorRoomAt} from './housing.js';
// One-time plot improvements purchased with earned play stars, never real money.
export const yardUpgrades=Object.freeze({
 fence:Object.freeze({name:'Yard fence',price:30}),
 trees:Object.freeze({name:'Yard trees',price:20}),
 decor:Object.freeze({name:'Yard decorations',price:15})
});
export function yardUpgradeEligible(home,profileId){return !!home&&profileId!=null&&home.owner===profileId&&home.variant==='family';}

export function atYardHome(home,position){if(!home||!position||position.interiorBusiness!=null||position.carId!=null||position.rest||position.playground||![position.x,position.z].every(Number.isFinite))return false;if(position.interiorHome!=null)return position.interiorHome===home.id&&interiorRoomAt(home.variant,position.x,position.z)!==null;const plot=plots[home.id],variant=homeVariants[home.variant];return !!plot&&!!variant&&Math.hypot(position.x-plot[0],position.z-plot[1]-variant.d/2)<=7;}
