import {readFileSync} from 'node:fs';
const ids=/^[a-f0-9]{24}$/;
const request=/^[A-Za-z0-9_-]{8,64}$/;
const doors=[[-51,-19],[-51,5],[-51,29],[51,-19],[51,5],[51,29]];
const fields=(m,...keys)=>Object.keys(m).every(k=>['type','action','operation',...keys].includes(k));
const isId=x=>typeof x==='string'&&ids.test(x);
const reject=error=>({error});

export function createPreviewFurniture({store,housingRules,catalogRules}){
 const {interiorRoomAt,canMoveInside,homeVariants}=housingRules;
 const {furnitureBounds,furnitureCatalog,furnitureShop}=catalogRules;
 const known=k=>typeof k==='string'&&Object.hasOwn(furnitureCatalog,k);
 const own=p=>store.state.homes.find(h=>h.owner===p.id&&doors[h.id]);
 const lease=p=>p.zone==='private'&&p.petHome?.inRoom&&own(p.profile)?.id===p.petHome.plot?p.petHome:null;
 const ownedFields=['stars','furnitureInventory','furnitureDeliveries','furnitureReceipts'];
 function snapshot(profile){
  const home=own(profile);
  const stock=Object.entries(profile.furnitureInventory).filter(([k,n])=>known(k)&&Number.isSafeInteger(n)&&n>0).map(([kind,quantity])=>({kind,quantity}));
  const placed=(home?.furniture??[]).filter(r=>known(r.kind)).map(({id,kind,room,x,z,y,rotation,supportId,surfaceId,revision})=>({id,kind,room:room??0,x,z,y:y??0,rotation:rotation??0,supportId:supportId??null,surfaceId:surfaceId??null,revision:revision??0}));
  return {stock,placed,deliveries:profile.furnitureDeliveries.filter(x=>known(x.kind)&&x.homeId===home?.id).map(({id,kind,quantity})=>({id,kind,quantity}))};
 }
 function pose(p,m,now){
  const inside=lease(p);
  if(!inside||!fields(m,'x','y','z'))return false;
  const h=own(p.profile),{x,y,z}=m;
  if(![x,y,z].every(Number.isFinite)||y<-.15||y>2||interiorRoomAt(h.variant,x,z)===null)return false;
  const last=inside.furniturePose??{x:0,y:0,z:3.5,at:inside.at};
  if(now<last.at||Math.hypot(x-last.x,z-last.z)>1.9+Math.min(9000,now-last.at)*.012||!canMoveInside(h.variant,last,{x,z}))return false;
  inside.furniturePose={x,y,z,at:now};
  return true;
 }
 function atomic(profile,home,operation){
  const previous=Object.fromEntries(ownedFields.map(k=>[k,structuredClone(profile[k])]));
  const oldHome=structuredClone(home.furniture);
  try{const error=operation();return error?reject(error):{};}
  catch{
   try{
    const disk=JSON.parse(readFileSync(store.accountFile,'utf8')),p=disk.profiles[profile.username],h=disk.homes[home.id];
    const cmp=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
    if(p&&h&&ownedFields.every(k=>cmp(p[k],profile[k]))&&cmp(h.furniture,home.furniture))return {};
   }catch{}
   Object.assign(profile,previous);home.furniture=oldHome;
   return reject('Could not save the furniture change. Nothing was changed.');
  }
 }
 function apply(p,m,now){
  if(m.operation==='pose'){pose(p,m,now);return {silent:true};}
  if(typeof m.requestId!=='string'||!request.test(m.requestId))return reject('Please retry this furniture request.');
  const profile=p.profile,h=own(profile);
  if(!h)return reject('Visit your own saved home to manage furniture.');
  if(m.operation==='buy'||m.operation==='sell'){
   if(!fields(m,'kind','quantity','requestId')||!known(m.kind)||!Number.isSafeInteger(m.quantity)||m.quantity<1||m.quantity>10)return reject('Choose one to ten items.');
   if(furnitureCatalog[m.kind].rewardOnly)return reject('The Town Explorer trophy is earned and cannot be bought or sold.');
   if(p.zone!=='store'||!p.grounded||Math.abs(p.y)>1.25||now-p.updated>2500||p.z<=-4.60||Math.hypot(p.x,p.z+5.05)>4.75)
    return reject('Speak to the shopkeeper at the Town Store counter first.');
   const legacy={interiorBusiness:'store',x:furnitureShop.x,z:furnitureShop.z};
   const method=m.operation==='buy'?store.furnitureOrder:store.furnitureSell;
   const out=atomic(profile,h,()=>method(profile,{kind:m.kind,quantity:m.quantity,requestId:m.requestId},legacy));
   return out.error?out:{text:m.operation==='buy'?'Order saved. Pick it up outside your front door.':'Furniture sold. Your saved stars were updated.'};
  }
  if(m.operation==='pickup'){
   if(!fields(m,'deliveryId','requestId')||!isId(m.deliveryId))return reject('Choose a delivery.');
   const delivery=profile.furnitureDeliveries.find(row=>row.id===m.deliveryId&&known(row.kind)&&row.homeId===h.id);
   const replay=profile.furnitureReceipts.some(r=>r.requestId===m.requestId&&r.payload===JSON.stringify(['pickup',m.deliveryId]));
   if(!delivery&&!replay)return reject('This delivery is not waiting at your home.');
   const [x,z]=doors[h.id];
   if(p.zone!=='town'||!p.grounded||Math.abs(p.y)>1.25||now-p.updated>2500||Math.hypot(x-p.x,z-p.z)>4)return reject('Walk to your own front-door package.');
   // Earlier route established the authored Godot door. Translate the front
   // marker to the corresponding legacy yard coordinate expected by the store.
   const legacyDoorZ=z-5+homeVariants[h.variant].d/2;
   const out=atomic(profile,h,()=>store.furniturePickup(profile,{requestId:m.requestId,deliveryId:m.deliveryId},{x,z:legacyDoorZ}));
   return out.error?out:{text:'Furniture package collected.'};
  }
  const inside=lease(p), point=inside?.furniturePose;
  if(!point||now-point.at>2000||point.y>1.3)return reject('Stand inside your own home and try again.');
  const room=interiorRoomAt(h.variant,point.x,point.z);
  if(room===null)return reject('Stand inside the room you want to decorate.');
  const at={x:point.x,z:point.z,interiorHome:h.id}, common={home:h.id,requestId:m.requestId};
  if(m.operation==='place'||m.operation==='move'){
   const moving=m.operation==='move', current=moving?h.furniture.find(r=>r.id===m.id):null;
   const kind=moving?current?.kind:m.kind;
   if(!known(kind)||(moving&&(!isId(m.id)||!Number.isSafeInteger(m.expectedRevision)||m.expectedRevision<0))||
      !fields(m,'kind','room','x','z','rotation','supportId','surfaceId','requestId',...(moving?['id','expectedRevision']:[]))||
      (m.kind!==undefined&&m.kind!==kind)||
      m.room!==room||![m.x,m.z].every(Number.isFinite)||!Number.isInteger(m.rotation)||m.rotation<0||m.rotation>3||
      (m.supportId!=null&&!isId(m.supportId))||(m.surfaceId!=null&&(typeof m.surfaceId!=='string'||m.surfaceId.length>32)))
    return reject('Choose a valid furniture location in this room.');
   if(m.supportId==null){
    const b=furnitureBounds(kind,m.x,m.z,m.rotation), x=point.x-room*12;
    if(x>b.left-.32&&x<b.right+.32&&point.z>b.back-.32&&point.z<b.front+.32)
     return reject('Step back before placing the furniture.');
   }
   const wire={...common,type:moving?'furnitureMove':'furnish',kind,room,x:m.x,z:m.z,rotation:m.rotation,supportId:m.supportId??null,surfaceId:m.surfaceId??null,...(moving?{item:m.id,expectedRevision:m.expectedRevision}:{})};
   const out=atomic(profile,h,()=>store.action(profile,wire,at));
   return out.error?out:{text:moving?'Furniture position saved.':'Furniture placed.'};
  }
  if(m.operation==='pack'){
   if(!fields(m,'id','expectedRevision','requestId')||!isId(m.id)||!Number.isSafeInteger(m.expectedRevision)||m.expectedRevision<0)
    return reject('Choose a placed piece of furniture.');
   const item=h.furniture.find(r=>r.id===m.id);
   if(item&&!known(item.kind))return reject('Choose a placed piece of furniture.');
   const out=atomic(profile,h,()=>store.action(profile,{...common,type:'remove',item:m.id,expectedRevision:m.expectedRevision},at));
   return out.error?out:{text:'Furniture packed away.'};
  }
  return reject('Choose a supported furniture action.');
 }
 return {snapshot,apply};
}

