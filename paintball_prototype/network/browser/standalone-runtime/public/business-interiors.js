// Shared isolated business rooms. Interior coordinates remain world-relative for jobs.
export const businessDefinitions=Object.freeze(Object.fromEntries([
 ['bank','Willow Bank',-54,-49,-2.142857,4],['vet','Pet Vet',-18,-49,-2.142857,4],['salon','Beauty Salon',18,-49,-2.142857,4],
 ['store','Town Store',-16,24,0,-3.5],['cafe','Sunny Cafe',16,24,0,-3.5],['library','Library',-16,-24,0,5],['arcade','Willow Arcade',0,-51,0,4]
].map(([id,name,x,z,dx,dz])=>[id,Object.freeze({id,name,x,z,doorX:x+dx,doorZ:z+dz,spawnX:x,spawnZ:z+5.5,exitX:x,exitZ:z+6.5,halfWidth:9,halfDepth:7})])));
export function businessAt(id){return typeof id==='string'&&Object.hasOwn(businessDefinitions,id)?businessDefinitions[id]:null;}
export function insideBusiness(id,x,z){const b=businessAt(id);return !!b&&Number.isFinite(x)&&Number.isFinite(z)&&Math.abs(x-b.x)<=b.halfWidth&&Math.abs(z-b.z)<=b.halfDepth;}
export function nearBusinessExit(id,x,z){const b=businessAt(id);return !!b&&insideBusiness(id,x,z)&&Math.hypot(x-b.exitX,z-b.exitZ)<=2;}
export function canEnterBusiness(id,p){const b=businessAt(id);return !!b&&!!p&&p.interiorHome==null&&p.interiorBusiness==null&&p.carId==null&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.hypot(p.x-b.doorX,p.z-b.doorZ)<=3;}
export function sameRoom(a,b){return (a.interiorHome??null)===(b.interiorHome??null)&&(a.interiorBusiness??null)===(b.interiorBusiness??null);}


