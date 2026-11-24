export const garden=Object.freeze({x:20,z:49,radius:5,reward:2,cooldownMs:300000,label:'Tend garden'});
export function atGarden(p){return !!p&&p.interiorHome==null&&p.interiorBusiness==null&&p.carId==null&&!p.rest&&!p.playground&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&Math.hypot(p.x-garden.x,p.z-garden.z)<=garden.radius;}
