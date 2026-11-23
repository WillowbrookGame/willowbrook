// Local CC0 furnishings; all prices are earned play stars, never real money.
export const furnitureCatalog=Object.freeze(Object.fromEntries([
 ['books','Books','books',2,.4,.3],
 ['scavengerTrophy','Town Explorer trophy','../scavenger/trophy',0,.8,.7],
 ['chair','Chair','chairCushion',2,.7,.7],['table','Table','table',5,1.8,1],['plant','Plant','pottedPlant',2,.5,.6],['rug','Rug','rugRectangle',3,2.6,1.55],['lamp','Floor lamp','lampRoundFloor',3,.4,.45],
 ['bed','Single bed','bedSingle',12,1.8,2.8],['sofa','Sofa','loungeSofa',10,2.8,1.2],['coffeeTable','Coffee table','tableCoffee',5,1.6,1],['bedside','Bedside cabinet','cabinetBed',4,.8,.7],['bookshelf','Bookshelf','bookcaseClosedWide',8,1.8,.7],['counter','Kitchen counter','kitchenCabinet',6,1.1,1.2],['sink','Kitchen sink','kitchenSink',8,1.1,1.2],['stove','Stove','kitchenStove',10,1.1,1.2],['fridge','Fridge','kitchenFridge',12,1.1,.9]
].map(([kind,name,file,price,width,depth])=>[kind,Object.freeze({name,file,price,width,depth,...(kind==='books'?{surfacePlaceable:true,height:.27625,surfaceWidth:.4,surfaceDepth:.25125}:kind==='scavengerTrophy'?{rewardOnly:true,surfacePlaceable:true,height:1,surfaceWidth:.566,surfaceDepth:.406}:kind==='plant'?{surfacePlaceable:true,height:1.5,surfaceWidth:.487,surfaceDepth:.554}:{})})])));
export const furnitureShop=Object.freeze({x:-16,z:22.2,radius:2.2});
export function atFurnitureShop(p){return !!p&&p.interiorBusiness==='store'&&p.interiorHome==null&&p.carId==null&&[p.x,p.z].every(Number.isFinite)&&Math.hypot(p.x-furnitureShop.x,p.z-furnitureShop.z)<=furnitureShop.radius;}
export function furnitureBounds(kind,x,z,rotation=0){const c=furnitureCatalog[kind];if(!c)return null;const odd=rotation%2!==0,w=odd?c.depth:c.width,d=odd?c.width:c.depth;return {left:x-w/2,right:x+w/2,back:z-d/2,front:z+d/2};}
export function furnitureOverlaps(a,b){const x=furnitureBounds(a.kind,a.x,a.z,a.rotation??0),y=furnitureBounds(b.kind,b.x,b.z,b.rotation??0);return !!x&&!!y&&x.left<y.right-.01&&x.right>y.left+.01&&x.back<y.front-.01&&x.front>y.back+.01;}

// Surfaces measured after fitFurnitureModel; y is holder offset (absolute top minus .25).
export const furnitureSurfaces=Object.freeze(Object.fromEntries([
 ['table',.698906,1.8,.956962,0,0],['coffeeTable',.556736,1.6,.968236,0,0],['bedside',.701353,.8,.646617,0,0],['counter',1.074419,1.1,1.074418,0,.038372],['bookshelf',1.7775,1.8,.5625,0,0]
].map(([kind,y,width,depth,x,z])=>[kind,Object.freeze([...(kind==='bookshelf'?[.1575,.6975,1.2375].map((height,i)=>Object.freeze({id:'shelf-'+(i+1),label:'Shelf '+(i+1),x:0,z:-.025,y:height,width:1.6,depth:.43,clearance:.4725})):[]),Object.freeze({id:'top',label:'Top',x,z,y,width,depth,clearance:Infinity})])])));