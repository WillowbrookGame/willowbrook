// Pure shared interaction geometry; local +Z is every cabinet's playable front.
export const arcadeExterior=Object.freeze({x:0,z:-51,w:10,d:8,doorX:0,doorZ:-47});
const specifications=[
 ['basketball',"HOOPS '88",'basketball-game',-6,-5.5,2.3,2.3,0],
 ['memory','Memory Match','arcade-machine',-2,-5.8,1.5,1.8,0],
 ['road-hop','Road Crossing','arcade-machine',2,-5.8,1.5,1.8,0],
 ['maze-chase','Blastemoids','arcade-machine',6,-5.8,1.5,1.8,0],
 ['claw','Claw Machine','claw-machine',-7.8,0,1.8,1.8,Math.PI/2],
 ['air-hockey','Air Hockey','air-hockey',0,0,4,2.8,0],
 ['brick-breaker','Cosmic Breakout','arcade-machine',7.8,1,1.5,1.8,-Math.PI/2],
 ['survivors','Basic Survivors','arcade-machine',-7.8,3.6,1.5,1.8,Math.PI/2]
];
export const arcadeCabinets=Object.freeze(specifications.map(([id,name,asset,lx,lz,modelWidth,modelDepth,rotation])=>{
 const side=Math.abs(Math.sin(rotation))>.5,x=arcadeExterior.x+lx,z=arcadeExterior.z+lz,front=modelDepth/2+.9;
 return Object.freeze({id,name,asset,x,z,rotation,modelWidth,modelDepth,w:side?modelDepth:modelWidth,d:side?modelWidth:modelDepth,talkX:x+Math.sin(rotation)*front,talkZ:z+Math.cos(rotation)*front,radius:1.7,interiorBusiness:'arcade'});
}));
export const arcadeCabinet=id=>arcadeCabinets.find(c=>c.id===id)||null;
