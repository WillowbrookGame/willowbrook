// Shared prices and job-board definitions. The server validates all spending and rewards.
export const furniturePrices=Object.freeze({chair:2,plant:2,rug:3,lamp:3,table:5});
export const petPrice=8;
export const jobBoard=Object.freeze({x:10,z:4,radius:4.5});
export const workDefinitions=Object.freeze(Object.fromEntries([
 ['delivery',-16,24,'store'],['bank',-54,-49,'bank'],['vet',-18,-49,'vet'],['salon',18,-49,'salon'],['cafe',16,24,'cafe'],['store',-16,24,'store'],['library',-16,-24,'library'],['nursery',-23,48,null],['park',16,-24,null],['singing',54,-49,null]
].map(([name,x,z,business])=>[name,Object.freeze({x,z,business,route:name==='delivery',reward:3,durationMs:8000,cooldownMs:60000})])));
export const classTiers=Object.freeze([{tier:1,cost:50,reward:5},{tier:2,cost:120,reward:8},{tier:3,cost:200,reward:10}].map(Object.freeze));
export function workReward(name,classes){return classTiers[(classes?.[name]?.tier||0)-1]?.reward??3;}
export const economy=Object.freeze({furniturePrices,petPrice,jobBoard,workDefinitions,classTiers});



export function atVetDesk(p){const v=workDefinitions.vet;return !!p&&p.interiorBusiness==='vet'&&p.interiorHome==null&&p.carId==null&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.abs(p.x-v.x)<=2.4&&p.z>=v.z-.1&&p.z<=v.z+2.5;}

export function atLibraryDesk(p){const v=workDefinitions.library;return !!p&&p.interiorBusiness==='library'&&p.interiorHome==null&&p.carId==null&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.abs(p.x-v.x)<=2.4&&p.z>=v.z-.1&&p.z<=v.z+2.5;}
