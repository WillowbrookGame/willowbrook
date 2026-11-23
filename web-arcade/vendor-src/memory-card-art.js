// Unmodified CC0 Kenney Animal Pack Remastered pictures, decoded once on demand.
export const memoryAnimals=Object.freeze(['elephant','rabbit','giraffe','penguin','frog','whale'].map(id=>Object.freeze({id,name:id[0].toUpperCase()+id.slice(1),url:'./assets/arcade-memory/'+id+'.png'})));
let cached=null;
export function loadMemoryArt(){
 if(cached)return cached;
 if(typeof Image==='undefined')return {};
 cached={};for(const animal of memoryAnimals){const img=new Image();img.decoding='async';img.src=animal.url;cached[animal.id]=img;}return cached;
}
export function drawMemoryFace(c,value,x,y,w=96,h=84,art={}){
 const animal=memoryAnimals[value];if(!animal)return;
 const img=art[animal.id];c.fillStyle='#fff9eb';c.fillRect(x,y,w,h);
 if(img?.complete&&img.naturalWidth>0&&img.naturalHeight>0){const scale=Math.min((w-16)/img.naturalWidth,(h-25)/img.naturalHeight),iw=img.naturalWidth*scale,ih=img.naturalHeight*scale;c.drawImage(img,x+(w-iw)/2,y+5+(h-25-ih)/2,iw,ih);}
 else{c.fillStyle='#617d8a';c.font='bold 22px sans-serif';c.textAlign='center';c.fillText(animal.name[0],x+w/2,y+40);}
 c.fillStyle='#294652';c.font='bold 12px sans-serif';c.textAlign='center';c.fillText(animal.name,x+w/2,y+h-8);c.textAlign='start';
}
