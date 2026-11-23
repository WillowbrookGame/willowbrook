export const beachLayout={bounds:{x:58,minZ:-55,maxZ:43},spawn:{x:0,z:34},shore:0,mainPier:{x:0,z:-17,width:4.4,length:36},diveShop:{x:-25,z:7},boatRental:{x:24.5,z:9},rentalPier:{x:32,z:-4,width:4,length:20}};
// Self-contained map: never imports town geometry, networking, accounts or saves.
export const beachTownExit={x:0,z:36,halfWidth:4,target:'/'};
export function atBeachTownExit(x,z){return Number.isFinite(x)&&Number.isFinite(z)&&Math.abs(x-beachTownExit.x)<=beachTownExit.halfWidth&&z>=beachTownExit.z&&z<43;}
export function beachWalkable(x,z){return Math.abs(x)<57&&z<43&&!(Math.abs(x+25)<4.4&&Math.abs(z-8)<3.5)&&!(Math.abs(x-24.5)<3&&Math.abs(z-9)<2.7)&&!(Math.abs(x+19)<4.9&&z>30.2&&z<37)&&!(Math.abs(x+43)<5&&Math.abs(z-9)<4.6)&&!snackProps.some(([px,pz,r])=>Math.hypot(x-px,z-pz)<r)&&(z>=1||Math.abs(x)<1.65&&z>=-34||Math.abs(x-32)<1.7&&z>=-11||Math.abs(x-32)<5&&z>=-11&&z<=-6);}

// Decorative snack furniture shares client/server collision; routes remain open.
const snackProps=[[-14.68,24.24,2.2],[-12.52,29.52,.95],[-25.14,29.52,1],...[-4.5,-1.5,1.5,4.5].map(x=>[-19+x*.48,30,.47])];
