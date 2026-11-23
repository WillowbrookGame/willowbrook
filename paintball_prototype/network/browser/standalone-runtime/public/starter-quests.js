// Short optional-repeat town activities. Complete all four once before first hiring.
const step=(id,label,x,z,interiorBusiness=null)=>Object.freeze({id,label,x,z,interiorBusiness,radius:1.7,durationMs:2000});
export const starterQuests=Object.freeze({
 cafe:Object.freeze({id:'cafe',label:'Serve a cafe snack',reward:1,cooldownMs:60000,steps:[step('collect','Collect a snack tray',16,20.6,'cafe'),step('serve','Serve the snack',18.5,23.5,'cafe')]}),
 store:Object.freeze({id:'store',label:'Stock the town store',reward:1,cooldownMs:60000,steps:[step('collect','Collect a stock box',-13,26,'store'),step('stock','Stock the shelf',-12.3,23.5,'store')]}),
 park:Object.freeze({id:'park',label:'Tidy the park',reward:1,cooldownMs:60000,steps:[step('collect','Pick up litter',11,-24),step('recycle','Put it in the recycling bin',21,-24)]}),
 garden:Object.freeze({id:'garden',label:'Water the garden',reward:2,cooldownMs:300000,steps:[step('water-left','Water the first plants',18.5,47),step('water-right','Water the other plants',21.5,51)]})
});
export const starterQuest=id=>typeof id==='string'&&Object.hasOwn(starterQuests,id)?starterQuests[id]:null;
export function starterEligible(starter){return starter?.unlocked===true||Object.keys(starterQuests).every(id=>Number.isFinite(starter?.completed?.[id]));}
export function currentStarterTask(starter){const r=starter?.run;return r?starterQuest(r.quest)?.steps[r.step]||null:null;}
