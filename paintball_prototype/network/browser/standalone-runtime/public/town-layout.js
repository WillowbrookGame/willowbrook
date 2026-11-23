// One road grid shared by rendering and authoritative vehicle movement.

export const tileSize=12;
export const townBounds=Object.freeze({x:80,z:62});

// Shift both home rows outward so family houses and purchased yards clear the full sidewalk tiles.
export const plots=[[-51,-24],[-51,0],[-51,24],[51,-24],[51,0],[51,24]];

export const library={x:-16,z:-24};

export const activities={cafe:[16,19],store:[-16,19],park:[16,-24]};

export const questDefinitions={gardener:[{name:'nursery',x:-23,z:48},{name:'garden',x:20,z:48},{name:'park',x:16,z:-24}],librarian:[{name:'cottage',x:-16,z:-24},{name:'cafe',x:16,z:19},{name:'cottage',x:-16,z:-24}]};

const cells=new Map(),key=(x,z)=>x+','+z;

for(const z of [-3,-1,1,3])for(let x=-6;x<=6;x++)cells.set(key(x,z),{x:x*12,z:z*12});

for(const x of [-6,-3,0,3,6])for(let z=-3;z<=3;z++)cells.set(key(x,z),{x:x*12,z:z*12});

export const roads=[...cells.values()].map(p=>{const cx=p.x/12,cz=p.z/12,e=cells.has(key(cx+1,cz)),w=cells.has(key(cx-1,cz)),n=cells.has(key(cx,cz-1)),s=cells.has(key(cx,cz+1)),count=+e + +w + +n + +s;let file='road-straight',yaw=n&&s?Math.PI/2:0;if(count===4)file='road-crossroad';else if(count===3){file='road-intersection';yaw=!n?0:!s?Math.PI:!w?Math.PI/2:-Math.PI/2;}else if(count===2&&!(e&&w)&&!(n&&s)){file='road-bend-square';yaw=e&&s?Math.PI/2:s&&w?0:w&&n?-Math.PI/2:Math.PI;}else if(count===1){file='road-end';yaw=e?0:w?Math.PI:n?Math.PI/2:-Math.PI/2;}return {...p,e,w,n,s,file,yaw};});

export function onRoad(x,z){if(!Number.isFinite(x)||!Number.isFinite(z))return false;return roads.some(t=>{const dx=x-t.x,dz=z-t.z;if(Math.abs(dx)<=4.2&&Math.abs(dz)<=4.2)return true;return (t.e&&dx>=0&&dx<=6&&Math.abs(dz)<=3.6)||(t.w&&dx<=0&&dx>=-6&&Math.abs(dz)<=3.6)||(t.s&&dz>=0&&dz<=6&&Math.abs(dx)<=3.6)||(t.n&&dz<=0&&dz>=-6&&Math.abs(dx)<=3.6);});}

export const hills=Array.from({length:16},(_,i)=>({x:Math.cos(i/16*Math.PI*2)*125,z:Math.sin(i/16*Math.PI*2)*110,radius:13,height:10+i%3*3}));



