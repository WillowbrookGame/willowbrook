import {normalizeFishProfile} from './beach-fishing.mjs';
import {furniturePlacement,furnitureHasChildren} from './public/furniture-placement.js';
import {scavengerHunt,scavengerItem,atScavengerPoint,normalizeScavenger,createScavengerPlacements,legacyScavengerPlacements,validScavengerPlacements} from './public/scavenger-hunt.js';
import {yardUpgrades,yardUpgradeEligible,atYardHome} from './public/yard-upgrades.js';
import {atEmployer} from './public/employers.js';
import {starterQuests,starterQuest,starterEligible} from './public/starter-quests.js';
import {parcelStation,deliveryDestinations,deliveryStop,nurseryStation,nurseryTasks,atJobTask,workTaskDefinitions} from './public/job-tasks.js';
import {garden,atGarden} from './public/garden.js';
import {furnitureCatalog,atFurnitureShop,furnitureBounds,furnitureOverlaps} from './public/furniture-catalog.js';
import {carTiers,carLot,atCarLot,lotParking,validCarSpot} from './public/car-economy.js';
import {randomInt,randomBytes,scryptSync,timingSafeEqual,createHash} from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {plots,activities,questDefinitions} from './public/town-layout.js';
export {plots,activities,questDefinitions};
import {atLibraryDesk,classTiers,workReward,atVetDesk,furniturePrices,petPrice,jobBoard,workDefinitions,economy} from './public/economy.js';
export {classTiers,workReward,furniturePrices,petPrice,jobBoard,workDefinitions,economy};
import {atBankTeller,bank as bankLocation,starterMortgage,homeVariants,housing,roomsForHome,interiorRoomAt} from './public/housing.js';
export {housing};
export const palette=[0xe7ad64,0x729ed1,0xc17da7,0x7eae79,0xa28ace,0xde896a];
export const appearancePalette=Object.freeze([0x3b2b26,0x6d5146,0xc99551,0xe5c88c,0x303a52,0x527d86,0x9b638d,0xe7ad64]);
export const characters=Object.freeze(['male-a','male-b','male-c','male-d','male-e','male-f','male-g','female-a','female-b','female-c','female-d','female-e','female-f','alien','knight','raider','robot','soldier','worker','zombie']);
const presentations=['classic','feminine'],pets=['none','cat','dog','bunny','chick','parrot'],vehicles=['walk','scooter'];
function defaults(p){
 normalizeFishProfile(p);
 if(p.hoopsBest===undefined)p.hoopsBest=null;
 if(p.hoopsBest!==null&&(!Number.isSafeInteger(p.hoopsBest.score)||p.hoopsBest.score<0||p.hoopsBest.score>100000||!Number.isSafeInteger(p.hoopsBest.finishedAt)||p.hoopsBest.finishedAt<0))throw Error('Invalid hoops best save; preserve file and restore backup');
 p.scavenger=normalizeScavenger(p.scavenger);
 if(p.scavenger.startedAt!==null&&p.scavenger.placements===null)p.scavenger.placements=legacyScavengerPlacements();
 if(p.scavenger.placements!==null&&!validScavengerPlacements(p.scavenger.placements))throw Error('Invalid hunt placements save; preserve file and restore backup');
 if(!p.scavengerBest||!Number.isSafeInteger(p.scavengerBest.durationMs)||p.scavengerBest.durationMs<0||!Number.isSafeInteger(p.scavengerBest.finishedAt)||p.scavengerBest.finishedAt<0)p.scavengerBest=null;
 if(p.scavenger.startedAt!==null&&!p.scavenger.runId)p.scavenger.runId=randomBytes(12).toString('hex');
 if(!Array.isArray(p.scavengerReceipts))p.scavengerReceipts=[];
 const inventory=p.furnitureInventory&&typeof p.furnitureInventory==='object'?p.furnitureInventory:{};p.furnitureInventory=Object.fromEntries(Object.keys(furnitureCatalog).map(k=>[k,Number.isSafeInteger(inventory[k])&&inventory[k]>=0?inventory[k]:0]));
 if(!Array.isArray(p.furnitureDeliveries))p.furnitureDeliveries=[];
 if(!Array.isArray(p.furnitureReceipts))p.furnitureReceipts=[];
 const deliveryIds=new Set();for(const d of p.furnitureDeliveries){if(!d||typeof d.id!=='string'||!/^[a-f0-9]{24}$/.test(d.id)||deliveryIds.has(d.id)||typeof d.kind!=='string'||!Object.hasOwn(furnitureCatalog,d.kind)||!Number.isInteger(d.quantity)||d.quantity<1||d.quantity>10||!Number.isInteger(d.homeId)||d.homeId<0||d.homeId>=6)throw Error('Invalid furniture delivery save; preserve file and restore backup');deliveryIds.add(d.id);}
 if(!appearancePalette.includes(p.hairColor))p.hairColor=0x6d5146;
 if(!appearancePalette.includes(p.pantsColor))p.pantsColor=0x527d86;
 if(!presentations.includes(p.presentation))p.presentation='classic';
 if(!characters.includes(p.character))p.character=p.presentation==='feminine'?'female-a':'male-a';
 if(!pets.includes(p.pet))p.pet='none';
 p.ownedPets=[...new Set((Array.isArray(p.ownedPets)?p.ownedPets:[]).filter(pet=>pets.includes(pet)&&pet!=='none'))];
 if(p.pet!=='none'&&!p.ownedPets.includes(p.pet))p.ownedPets.push(p.pet);
 if(!p.work||typeof p.work!=='object'||Array.isArray(p.work))p.work={name:null,startedAt:null,completed:{}};
 if(!p.work.completed||typeof p.work.completed!=='object'||Array.isArray(p.work.completed))p.work.completed={};
 p.work.completed=Object.fromEntries(Object.keys(workDefinitions).filter(name=>Number.isFinite(p.work.completed[name])&&p.work.completed[name]>=0).map(name=>[name,p.work.completed[name]]));
 if(typeof p.work.name!=='string'||!Object.hasOwn(workDefinitions,p.work.name)||!Number.isFinite(p.work.startedAt)||p.work.startedAt<0){p.work.name=null;p.work.startedAt=null;}
 const memberships=new Set((Array.isArray(p.jobMembership)?p.jobMembership:[]).filter(name=>typeof name==='string'&&Object.hasOwn(workDefinitions,name)));
 for(const name of Object.keys(p.work.completed))memberships.add(name);
 if(p.work.name!==null)memberships.add(p.work.name);
 p.jobMembership=[...memberships];p.hasJob=p.hasJob===true||p.jobMembership.length>0;
 const oldClasses=p.classes&&typeof p.classes==='object'&&!Array.isArray(p.classes)?p.classes:{};
 p.classes=Object.fromEntries(Object.keys(workDefinitions).map(name=>{const old=oldClasses[name],tier=Number.isInteger(old?.tier)&&old.tier>=0&&old.tier<=3?old.tier:0,paid=tier<3&&Number.isSafeInteger(old?.paid)&&old.paid>=0&&old.paid<classTiers[tier].cost?old.paid:0;return [name,{tier,paid}];}));
 if(!Array.isArray(p.classReceipts))p.classReceipts=[];
 if(p.mortgage===undefined)p.mortgage=null;
 if(p.mortgageHistory===undefined)p.mortgageHistory=[];
 p.vehicle='walk';
 if(!p.ownedCar||!Number.isInteger(p.ownedCar.tier)||p.ownedCar.tier<0||p.ownedCar.tier>=carTiers.length)p.ownedCar=null;
 else if(!validCarSpot(p.ownedCar))Object.assign(p.ownedCar,lotParking(p.id));
 if(!Array.isArray(p.carReceipts))p.carReceipts=[];
 if(!Array.isArray(p.yardReceipts))p.yardReceipts=[];
 if(!Number.isSafeInteger(p.stars)||p.stars<0)p.stars=0;
 if(!Number.isSafeInteger(p.gardenLastTendedAt)||p.gardenLastTendedAt<0)p.gardenLastTendedAt=null;
 if(!p.activityAt||typeof p.activityAt!=='object'||Array.isArray(p.activityAt))p.activityAt={};
 if(!p.job||!['none','pickup','deliver'].includes(p.job.stage))p.job={stage:'none',completedAt:null};
 if(p.job.stage!=='none'&&!p.job.id){p.job.id=randomBytes(12).toString('hex');p.job.destination='cafe';p.job.startedAt=0;p.job.legacy=true;}
 if(p.job.stage==='deliver'&&!deliveryDestinations.some(t=>t.id===p.job.destination))p.job.destination='cafe';
 if(!Number.isSafeInteger(p.job.deliveries)||p.job.deliveries<0)p.job.deliveries=0;
 const tasks=workTaskDefinitions[p.work.name]?.tasks;
 if(tasks&&(!p.work.taskRun||typeof p.work.taskRun.id!=='string'||!Number.isInteger(p.work.taskRun.step)||p.work.taskRun.step<0||p.work.taskRun.step>=tasks.length))p.work.taskRun={id:randomBytes(12).toString('hex'),step:0,pending:null};
 if(!tasks)p.work.taskRun=null;
 if(p.work.taskRun?.pending&&(!Number.isFinite(p.work.taskRun.pending.beganAt)||p.work.taskRun.pending.beganAt<0||p.work.taskRun.pending.task!==tasks[p.work.taskRun.step].id))p.work.taskRun.pending=null;
 if(!p.quest||typeof p.quest!=='object'||Array.isArray(p.quest))p.quest={name:null,step:0,completed:{}};
 if(!p.quest.completed||typeof p.quest.completed!=='object'||Array.isArray(p.quest.completed))p.quest.completed={};
 p.quest.completed=Object.fromEntries(Object.keys(questDefinitions).filter(name=>Number.isFinite(p.quest.completed[name])&&p.quest.completed[name]>=0).map(name=>[name,p.quest.completed[name]]));
 if(typeof p.quest.name!=='string'||!Object.hasOwn(questDefinitions,p.quest.name)||!Number.isInteger(p.quest.step)||p.quest.step<0||p.quest.step>=3){p.quest.name=null;p.quest.step=0;}
 if(!p.starter||p.starter.version!==1){
  const completed={};for(const id of Object.keys(starterQuests)){const at=id==='garden'?p.gardenLastTendedAt:p.activityAt[id];if(Number.isFinite(at)&&at>=0)completed[id]=at;}
  p.starter={version:1,unlocked:p.hasJob===true||p.jobMembership.length>0,completed,run:null};
 }
 p.starter.completed=Object.fromEntries(Object.keys(starterQuests).filter(id=>Number.isFinite(p.starter.completed?.[id])&&p.starter.completed[id]>=0).map(id=>[id,p.starter.completed[id]]));
 p.starter.unlocked=p.starter.unlocked===true;
 const sr=p.starter.run,sq=starterQuest(sr?.quest);if(sr&&(!sq||typeof sr.id!=='string'||!Number.isInteger(sr.step)||sr.step<0||sr.step>=sq.steps.length))p.starter.run=null;
 if(p.starter.run?.pending&&(!Number.isFinite(p.starter.run.pending.beganAt)||p.starter.run.pending.task!==sq.steps[sr.step].id))p.starter.run.pending=null;
 if(!p.petCare||typeof p.petCare!=='object'||Array.isArray(p.petCare))p.petCare={};
 for(const name of ['feed','play','rest'])if(!Number.isSafeInteger(p.petCare[name])||p.petCare[name]<0)p.petCare[name]=0;
 if(!p.petCare.last||typeof p.petCare.last!=='object'||Array.isArray(p.petCare.last))p.petCare.last={};
}
export function makeStore(file,{deliveryRandom=randomInt,scavengerRandom=randomInt}={}){
 let state={version:1,nextProfile:1,profiles:{},sessions:{},homes:plots.map((_,i)=>({id:i,owner:null,open:false,locked:false,furniture:[]}))};
 if(file&&fs.existsSync(file)){state=JSON.parse(fs.readFileSync(file,'utf8'));if(state.version!==1||!Array.isArray(state.homes)||state.homes.length!==6)throw Error('Unsupported town save; preserve file and restore backup');}
 if(!state.settings||typeof state.settings!=='object'||Array.isArray(state.settings))state.settings={};
 if(typeof state.settings.chatEnabled!=='boolean')state.settings.chatEnabled=process.env.CHAT_ENABLED!=='false';
 if(typeof state.settings.registrationEnabled!=='boolean')state.settings.registrationEnabled=process.env.REGISTRATION_ENABLED!=='false';
 for(const p of Object.values(state.profiles))defaults(p);
 const legacyHousing=state.housingVersion===undefined;
 if(!legacyHousing&&state.housingVersion!==1)throw Error('Unsupported housing save; preserve file and restore backup');
 for(const h of state.homes){
  h.yardUpgrades=Object.fromEntries(Object.keys(yardUpgrades).map(k=>[k,h.yardUpgrades?.[k]===true]));
  if(legacyHousing)h.variant=h.owner!==null?'family':'starter';else if(h.variant===undefined)h.variant='starter';
  if(typeof h.variant!=='string'||!Object.hasOwn(homeVariants,h.variant))throw Error('Invalid housing save; preserve file and restore backup');
  if(legacyHousing||h.paidOff===undefined)h.paidOff=h.owner!==null;
  for(const item of h.furniture){if(!Number.isInteger(item.room)||item.room<0||item.room>2)item.room=0;if(item.rotation===undefined)item.rotation=0;if(item.supportId===undefined)item.supportId=null;if(item.surfaceId===undefined)item.surfaceId=null;if(item.y===undefined)item.y=0;if(item.revision===undefined)item.revision=0;}
 }
 // Legacy trophies may already be placed instead of in inventory. Never issue
 // another reward merely because the permanent flag predates this save format.
 for(const p of Object.values(state.profiles))if((p.furnitureInventory[scavengerHunt.rewardKind]||0)>0||state.homes.some(h=>h.owner===p.id&&h.furniture.some(f=>f.kind===scavengerHunt.rewardKind))){p.scavenger.trophyAwarded=true;p.scavenger.rewardClaimed=true;}
 // New editor relationships are checked, never silently dropped. Legacy floor
 // positions remain untouched; elevation is always reconstructed from geometry.
 for(const h of state.homes){
  const ids=new Set();for(const f of h.furniture){if(ids.has(f.id))throw Error('Duplicate furniture save; preserve file and restore backup');ids.add(f.id);if(!Number.isSafeInteger(f.revision)||f.revision<0||!Number.isInteger(f.rotation)||f.rotation<0||f.rotation>3)throw Error('Invalid furniture editor save; preserve file and restore backup');}
  for(const f of h.furniture){if(f.supportId==null){if(f.surfaceId!=null)throw Error('Orphan furniture surface save; preserve file and restore backup');f.y=0;continue;}const result=furniturePlacement(h,f,{ignoreId:f.id});if(result.error)throw Error('Invalid furniture support save; preserve file and restore backup: '+result.error);f.y=result.item.y;}
 }
 const loanPrincipals=[12,starterMortgage,homeVariants.cottage.cost,homeVariants.family.cost];
 for(const p of Object.values(state.profiles)){
  if(!Array.isArray(p.mortgageHistory))throw Error('Invalid mortgage history save; preserve file and restore backup');
  const ids=new Set();for(const paid of p.mortgageHistory){if(!paid||typeof paid.id!=='string'||!/^[a-f0-9]{32}$/.test(paid.id)||ids.has(paid.id)||!Number.isInteger(paid.homeId)||!state.homes[paid.homeId]||!loanPrincipals.includes(paid.principal))throw Error('Invalid mortgage history save; preserve file and restore backup');ids.add(paid.id);}
 }
 // Legacy twelve-star loans retain their original terms; no debt is silently increased.
 for(const p of Object.values(state.profiles))if(p.mortgage!==null){
  const loan=p.mortgage,h=state.homes[loan?.homeId];
  if(!loan||typeof loan.id!=='string'||!/^[a-f0-9]{32}$/.test(loan.id)||!Number.isInteger(loan.homeId)||!h||h.owner!==p.id||!loanPrincipals.includes(loan.principal)||!Number.isSafeInteger(loan.balance)||loan.balance<0||loan.balance>loan.principal||!Array.isArray(loan.repayments)||loan.repayments.length>loan.principal)throw Error('Invalid mortgage save; preserve file and restore backup');
  const ids=new Set();let repaid=0;
  for(const receipt of loan.repayments){if(!receipt||typeof receipt.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(receipt.requestId)||ids.has(receipt.requestId)||!Number.isSafeInteger(receipt.amount)||receipt.amount<1||receipt.amount>loan.principal)throw Error('Invalid mortgage save; preserve file and restore backup');ids.add(receipt.requestId);repaid+=receipt.amount;}
  if(repaid!==loan.principal-loan.balance)throw Error('Invalid mortgage save; preserve file and restore backup');
  h.paidOff=loan.balance===0;
 }
 for(const h of state.homes)if(typeof h.paidOff!=='boolean'||(h.owner!==null&&!h.paidOff&&!Object.values(state.profiles).some(p=>p.id===h.owner&&p.mortgage?.homeId===h.id)))throw Error('Invalid housing save; preserve file and restore backup');
 state.housingVersion=1;
 function save(){
  if(!file)return;
  fs.mkdirSync(path.dirname(file),{recursive:true});const tmp=file+'.tmp';
  fs.writeFileSync(tmp,JSON.stringify(state));if(fs.existsSync(file))fs.copyFileSync(file,file+'.bak');fs.renameSync(tmp,file);
  // First successful save of each UTC day; never rotate the live save or .bak.
  const directory=path.join(path.dirname(file),'backups');fs.mkdirSync(directory,{recursive:true});
  const dated=path.join(directory,'town-'+new Date().toISOString().slice(0,10)+'.json');
  if(!fs.existsSync(dated))fs.copyFileSync(file,dated,fs.constants.COPYFILE_EXCL);

 }
 function yardUpgrade(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return 'Please retry this yard purchase';
  const h=Number.isInteger(m.home)?state.homes[m.home]:null,item=typeof m.kind==='string'&&Object.hasOwn(yardUpgrades,m.kind)?yardUpgrades[m.kind]:null;
  if(!h||!item)return 'Choose a yard improvement';
  if(!yardUpgradeEligible(h,p.id))return 'Only the owner of a top family home can improve its yard';
  const old=p.yardReceipts.find(r=>r.requestId===m.requestId);
  if(old)return old.home===m.home&&old.kind===m.kind?null:'Yard purchase request already used';
  if(!atYardHome(h,position))return 'Visit your own home or front yard to improve it';
  if(h.yardUpgrades[m.kind])return 'This yard improvement is already installed';
  if(p.stars<item.price)return 'Earn '+item.price+' stars for this yard improvement';
  p.stars-=item.price;h.yardUpgrades[m.kind]=true;p.yardReceipts.push({requestId:m.requestId,home:m.home,kind:m.kind});save();return null;
 }
 function furnitureReceipt(p,m,operation){
  if(typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return {error:'Please retry this furniture action'};
  const payload=JSON.stringify(operation),old=p.furnitureReceipts.find(r=>r.requestId===m.requestId);
  return old?{error:old.payload===payload?null:'Furniture request already used',replay:true}:{payload};
 }
 function furnitureOrder(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  const receipt=furnitureReceipt(p,m,['buy',m.kind,m.quantity]);if(receipt.error||receipt.replay)return receipt.error;
  const home=state.homes.find(h=>h.owner===p.id);if(!home)return 'Get a home from the bank before ordering furniture';
  if(!atFurnitureShop(position))return 'Talk to the shopkeeper inside the store first';
  const item=typeof m.kind==='string'&&Object.hasOwn(furnitureCatalog,m.kind)?furnitureCatalog[m.kind]:null;
  if(item?.rewardOnly)return 'Earn this item by completing the town treasure hunt';
  if(!item||!Number.isInteger(m.quantity)||m.quantity<1||m.quantity>10)return 'Choose 1 to 10 copies of an item';
  if(p.furnitureDeliveries.length>=50)return 'Collect your home deliveries before ordering more';
  const cost=item.price*m.quantity;if(p.stars<cost)return 'Earn '+cost+' stars for this order';
  p.stars-=cost;p.furnitureDeliveries.push({id:randomBytes(12).toString('hex'),kind:m.kind,quantity:m.quantity,homeId:home.id});p.furnitureReceipts.push({requestId:m.requestId,payload:receipt.payload});save();return null;
 }
 function furnitureSell(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  const receipt=furnitureReceipt(p,m,['sell',m.kind,m.quantity]);if(receipt.error||receipt.replay)return receipt.error;
  if(!atFurnitureShop(position)||position.rest||position.playground)return 'Talk to the shopkeeper inside the store first';
  const item=typeof m.kind==='string'&&Object.hasOwn(furnitureCatalog,m.kind)?furnitureCatalog[m.kind]:null;
  if(!item||item.rewardOnly)return 'This item cannot be sold';
  if(!Number.isInteger(m.quantity)||m.quantity<1||m.quantity>10)return 'Choose 1 to 10 items to sell';
  if((p.furnitureInventory[m.kind]||0)<m.quantity)return 'Pack these items into your inventory before selling';
  const refund=Math.floor(item.price/2)*m.quantity;if(!Number.isSafeInteger(p.stars+refund))return 'Star balance is full';
  p.furnitureInventory[m.kind]-=m.quantity;p.stars+=refund;p.furnitureReceipts.push({requestId:m.requestId,payload:receipt.payload});save();return null;
 }
 function furniturePickup(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  const receipt=furnitureReceipt(p,m,['pickup',m.deliveryId]);if(receipt.error||receipt.replay)return receipt.error;
  const index=p.furnitureDeliveries.findIndex(d=>d.id===m.deliveryId),delivery=p.furnitureDeliveries[index],home=delivery&&state.homes[delivery.homeId];
  if(!home||home.owner!==p.id)return 'This delivery is not waiting at your home';
  const loc=plots[home.id],doorZ=loc[1]+homeVariants[home.variant].d/2;
  if(!position||position.interiorHome!=null||position.interiorBusiness!=null||position.carId!=null||![position.x,position.z].every(Number.isFinite)||Math.hypot(position.x-loc[0],position.z-doorZ)>4)return 'Walk outside to your own front-door package';
  if(!Number.isSafeInteger((p.furnitureInventory[delivery.kind]||0)+delivery.quantity))return 'Furniture inventory is full';p.furnitureInventory[delivery.kind]=(p.furnitureInventory[delivery.kind]||0)+delivery.quantity;p.furnitureDeliveries.splice(index,1);p.furnitureReceipts.push({requestId:m.requestId,payload:receipt.payload});save();return null;
 }
 function carShop(p,m,position){
  if(!atCarLot(position))return 'Walk to the car lot on foot first';
  if(!['buy','upgrade'].includes(m.action)||!Number.isInteger(m.expectedTier)||typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return 'Invalid car purchase';
  const receipt=p.carReceipts.find(r=>r.requestId===m.requestId);
  if(receipt)return receipt.action===m.action&&receipt.expectedTier===m.expectedTier?null:'Purchase request already used';
  const current=p.ownedCar?.tier??-1,next=current+1;
  if(current!==m.expectedTier||m.action!==(current<0?'buy':'upgrade'))return 'Car selection changed; check the current offer';
  if(!carTiers[next])return 'You already own the top car';
  const cost=carTiers[next].cost;if(p.stars<cost)return 'Earn '+cost+' stars for this car';
  p.stars-=cost;p.ownedCar={...(p.ownedCar||lotParking(p.id)),tier:next};
  p.carReceipts.push({requestId:m.requestId,action:m.action,expectedTier:m.expectedTier});save();return null;
 }
 function auth(m){
  if(!m||!['register','login','resume'].includes(m.type))return {error:'Invalid sign in'};
  if(m.type==='register'&&!state.settings.registrationEnabled)return {error:'New profiles are disabled by the town owner'};
  state.sessions ||= {};
  const digest=t=>createHash('sha256').update(t).digest('hex');
  if(m.type==='resume'){if(typeof m.session!=='string')return {error:'Please sign in again'};const entry=state.sessions[digest(m.session)];if(!entry||entry.until<Date.now())return {error:'Please sign in again'};const p=Object.values(state.profiles).find(p=>p.id===entry.id);return p&&!p.disabled?{profile:p,session:m.session}:{error:'Please sign in again'};}
  if(typeof m.username!=='string'||typeof m.password!=='string')return {error:'Invalid sign in'};
  const user=m.username.trim().toLowerCase();const password=m.password;
  if(!/^[a-z0-9_-]{3,20}$/.test(user)||password.length<6||password.length>100)return {error:'Use a 3-20 character username and a password of 6-100 characters'};
  let p=Object.hasOwn(state.profiles,user)?state.profiles[user]:null;
  if(m.type==='register'){if(p)return {error:'That username is taken'};if(Object.keys(state.profiles).length>=100)return {error:'Profile limit reached'};const salt=randomBytes(16).toString('hex');p={id:state.nextProfile++,username:user,salt,hash:scryptSync(password,salt,64).toString('hex'),color:palette[0],hat:'none',prop:'none'};defaults(p);Object.defineProperty(state.profiles,user,{value:p,writable:true,enumerable:true,configurable:true});}
  else {const hash=p?.hash&&Buffer.from(p.hash,'hex');if(!hash||hash.length!==64||!timingSafeEqual(hash,scryptSync(password,p.salt,64)))return {error:'Username or password is incorrect'};}
  if(p.disabled)return {error:'This player is disabled. Ask the town owner'};
  const session=randomBytes(24).toString('hex');for(const [k,v]of Object.entries(state.sessions))if(v.until<Date.now())delete state.sessions[k];state.sessions[digest(session)]={id:p.id,until:Date.now()+7*86400000};save();return {profile:p,session};
 }
 function setSettings(settings){
  if(!settings||typeof settings!=='object'||Array.isArray(settings)||!Object.keys(settings).length||Object.keys(settings).some(k=>!['chatEnabled','registrationEnabled'].includes(k)||typeof settings[k]!=='boolean'))return 'Choose valid boolean settings';
  Object.assign(state.settings,settings);save();return null;
 }
 function resetPassword(username,password){
  if(typeof username!=='string'||typeof password!=='string'||password.length<6||password.length>100)return {error:'Use a username and a password of 6-100 characters'};
  const name=username.trim().toLowerCase(),p=Object.hasOwn(state.profiles,name)?state.profiles[name]:null;
  if(!p)return {error:'Profile not found'};
  const salt=randomBytes(16).toString('hex');p.salt=salt;p.hash=scryptSync(password,salt,64).toString('hex');p.mustChangePassword=true;
  for(const [key,entry]of Object.entries(state.sessions||{}))if(entry.id===p.id)delete state.sessions[key];
  save();return {profileId:p.id};
 }

 function createApprovedAccount(username,password){
  if(typeof username!=='string'||typeof password!=='string')return {error:'Use a username and temporary password'};
  const name=username.trim().toLowerCase();
  if(!/^[a-z0-9_-]{3,20}$/.test(name)||password.length<6||password.length>100)return {error:'Use a 3-20 character username and password of 6-100 characters'};
  if(Object.hasOwn(state.profiles,name))return {error:'That username is taken'};
  if(Object.keys(state.profiles).length>=100)return {error:'Profile limit reached'};
  const salt=randomBytes(16).toString('hex'),p={id:state.nextProfile++,username:name,salt,hash:scryptSync(password,salt,64).toString('hex'),color:palette[0],hat:'none',prop:'none',mustChangePassword:true,disabled:false};
  defaults(p);Object.defineProperty(state.profiles,name,{value:p,writable:true,enumerable:true,configurable:true});save();return {profileId:p.id};
 }
 function setPlayerEnabled(username,enabled){
  if(typeof username!=='string'||typeof enabled!=='boolean')return {error:'Choose a player and enabled state'};
  const name=username.trim().toLowerCase(),p=Object.hasOwn(state.profiles,name)?state.profiles[name]:null;if(!p)return {error:'Profile not found'};
  p.disabled=!enabled;if(!enabled)for(const [key,entry]of Object.entries(state.sessions||{}))if(entry.id===p.id)delete state.sessions[key];save();return {profileId:p.id};
 }
 function changePassword(session,currentPassword,newPassword){
  const result=auth({type:'resume',session});if(result.error)return result;
  const p=result.profile;
  if(typeof currentPassword!=='string'||currentPassword.length>100||typeof newPassword!=='string'||newPassword.length<6||newPassword.length>100)return {error:'Use a new password of 6-100 characters'};
  if(currentPassword===newPassword)return {error:'Choose a different new password'};
  if(!timingSafeEqual(Buffer.from(p.hash,'hex'),scryptSync(currentPassword,p.salt,64)))return {error:'Current password is incorrect'};
  resetPassword(p.username,newPassword);p.mustChangePassword=false;save();return auth({type:'login',username:p.username,password:newPassword});
 }
 function backup(){const copy=structuredClone(state);copy.sessions={};return copy;}
 function logout(session){delete state.sessions[createHash('sha256').update(String(session)).digest('hex')];save();}
 function tendGarden(p,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!atGarden(position))return 'Walk to the community garden and leave your seat or vehicle first';
  if(!Number.isSafeInteger(now)||now<0)return 'Please try tending again';
  if(p.gardenLastTendedAt!==null&&now-p.gardenLastTendedAt<garden.cooldownMs)return 'Your garden is resting. Tend it again five minutes after your last visit';
  p.gardenLastTendedAt=now;p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+garden.reward);save();return null;
 }
 function activity(p,name,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(position?.interiorHome!=null)return 'Exit your home before doing town activities';
  if(typeof name!=='string'||!Object.hasOwn(activities,name))return 'Choose a town activity';
  if(position?.interiorBusiness!=null&&position.interiorBusiness!==name)return 'Visit the correct activity';
  const [x,z]=activities[name];
  if(!position||![position.x,position.z].every(Number.isFinite)||(position.interiorBusiness!==name&&Math.hypot(position.x-x,position.z-z)>7))return 'Get closer to this activity';
  if(Number.isFinite(p.activityAt[name])&&now-p.activityAt[name]<60000)return 'This activity is resting. Try again in a minute';
  p.activityAt[name]=now;p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+1);save();return null;
 }
 function scavenger(p,m,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p||p.disabled||p.mustChangePassword)return 'Join the town first';
  if(!Number.isSafeInteger(now)||now<0)return 'Please try again';
  const hunt=p.scavenger;
  if(m.action==='start'){
   if(!atEmployer(position,'park'))return 'Talk to the Mayor in the park to start the treasure hunt';
   if(typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return 'Please retry starting this hunt';
   const payload=JSON.stringify(['start',m.previousRunId??null]),old=p.scavengerReceipts.find(r=>r.requestId===m.requestId);
   if(old)return old.payload===payload?null:'Hunt request already used';
   if((m.previousRunId??null)!==hunt.runId)return 'This hunt changed; talk to the Mayor again';
   if(hunt.startedAt!==null&&hunt.completedAt===null)return 'Finish your current treasure hunt first';
   const placements=createScavengerPlacements(scavengerRandom,hunt.placements);
   Object.assign(hunt,{runId:randomBytes(12).toString('hex'),startedAt:now,collected:[],completedAt:null,elapsedMs:null,placements});
   p.scavengerReceipts.push({requestId:m.requestId,payload});save();return null;
  }
  if(m.action!=='collect')return 'Choose a treasure hunt action';
  if(hunt.startedAt===null)return 'Ask the Mayor in the park about the treasure hunt first';
  if(typeof m.runId!=='string'||m.runId!==hunt.runId)return 'This treasure belongs to a different hunt';
  const item=scavengerItem(m.item),assigned=item&&hunt.placements?.find(p=>p.itemId===item.id);if(!atScavengerPoint(position,assigned))return 'Walk closer to this treasure in town';
  if(hunt.collected.includes(item.id))return null;
  if(hunt.completedAt!==null)return 'Talk to the Mayor to start another hunt';
  const final=hunt.collected.length===scavengerHunt.items.length-1;
  if(now<hunt.startedAt||!Number.isSafeInteger(now-hunt.startedAt))return 'Hunt clock changed; please try again';
  if(final&&!hunt.trophyAwarded&&!Number.isSafeInteger((p.furnitureInventory[scavengerHunt.rewardKind]||0)+1))return 'Furniture inventory is full';
  hunt.collected.push(item.id);
  if(final){hunt.completedAt=now;hunt.elapsedMs=now-hunt.startedAt;if(!p.scavengerBest||hunt.elapsedMs<p.scavengerBest.durationMs||hunt.elapsedMs===p.scavengerBest.durationMs&&now<p.scavengerBest.finishedAt)p.scavengerBest={durationMs:hunt.elapsedMs,finishedAt:now};if(!hunt.trophyAwarded){p.furnitureInventory[scavengerHunt.rewardKind]=(p.furnitureInventory[scavengerHunt.rewardKind]||0)+1;hunt.trophyAwarded=true;hunt.rewardClaimed=true;}}
  save();return null;
 }
 function recordHoopsBest(p,score,finishedAt){if(!p||state.profiles[p.username]!==p||p.disabled||p.mustChangePassword||!Number.isSafeInteger(score)||score<0||score>100000||!Number.isSafeInteger(finishedAt)||finishedAt<0)return false;if(!p.hoopsBest||score>p.hoopsBest.score){p.hoopsBest={score,finishedAt};save();return true;}return false;}
 function hoopsLeaderboard(){return Object.values(state.profiles).filter(p=>!p.disabled&&!p.mustChangePassword&&p.hoopsBest).sort((a,b)=>b.hoopsBest.score-a.hoopsBest.score||a.hoopsBest.finishedAt-b.hoopsBest.finishedAt||a.id-b.id).slice(0,50).map((p,i)=>({rank:i+1,displayName:p.username,score:p.hoopsBest.score}));}
 function scavengerLeaderboard(){return Object.values(state.profiles).filter(p=>!p.disabled&&!p.mustChangePassword&&p.scavengerBest).sort((a,b)=>a.scavengerBest.durationMs-b.scavengerBest.durationMs||a.scavengerBest.finishedAt-b.scavengerBest.finishedAt||a.id-b.id).map((p,i)=>({rank:i+1,displayName:p.username,durationMs:p.scavengerBest.durationMs}));}
 function starterTask(p,m,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!Number.isSafeInteger(now)||now<0)return 'Try this activity again';
  const st=p.starter,run=st.run;
  if(m.action==='cancel'){if(!run||m.assignmentId!==run.id)return 'This activity is no longer active';st.run=null;save();return null;}
  if(m.action==='start'){
   const q=starterQuest(m.quest);if(!q)return 'Choose a town starter activity';
   if(run)return 'Finish or cancel your current starter activity';
   if(p.work.name!==null||p.job.stage!=='none')return 'Finish or cancel your current paid job first';
   if(!atJobTask(position,q.steps[0]))return 'Walk to the activity supplies first';
   st.run={id:randomBytes(12).toString('hex'),quest:q.id,step:0,pending:null};save();return null;
  }
  if(!run||m.assignmentId!==run.id)return 'Start this activity at its supplies first';
  if(m.quest!==undefined&&m.quest!==run.quest)return 'Finish your current starter activity';
  const q=starterQuest(run.quest),task=q.steps[run.step];
  if(m.task!==task.id)return 'Follow the next activity step';
  if(!atJobTask(position,task))return 'Walk closer to the marked activity supplies';
  if(m.action==='begin'){if(run.pending)return 'Finish the current activity step';run.pending={task:task.id,beganAt:now};save();return null;}
  if(m.action!=='finish'||!run.pending||run.pending.task!==task.id)return 'Begin this activity step first';
  if(now-run.pending.beganAt<task.durationMs)return 'Keep helping for a moment';
  run.step++;run.pending=null;
  if(run.step===q.steps.length){
   const last=q.id==='garden'?p.gardenLastTendedAt:p.activityAt[q.id];
   if(!Number.isFinite(last)||now-last>=q.cooldownMs){p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+q.reward);if(q.id==='garden')p.gardenLastTendedAt=now;else p.activityAt[q.id]=now;}
   if(!Number.isFinite(st.completed[q.id]))st.completed[q.id]=now;
   st.run=null;
  }
  save();return null;
 }
 function work(p,name,action,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!['hire','start','complete','cancel'].includes(action))return 'Choose a workplace action';
  if(action!=='cancel'&&position?.interiorHome!=null)return 'Exit your home before visiting a workplace';
  const current=p.work;
  if(action==='hire'){
   if(typeof name!=='string'||!Object.hasOwn(workDefinitions,name))return 'Choose a town job';
   if(!atEmployer(position,name))return 'Talk to this workplace employer to get hired';
   if(!starterEligible(p.starter))return 'Complete the cafe, store, park and garden starter activities before your first job';
   p.hasJob=true;if(!p.jobMembership.includes(name))p.jobMembership.push(name);save();return null;
  }
  if(action==='cancel'){current.name=null;current.startedAt=null;current.taskRun=null;save();return null;}
  if(action==='start'){
   if(typeof name!=='string'||!Object.hasOwn(workDefinitions,name))return 'Choose a town job';
   if(!p.jobMembership.includes(name))return 'Talk to the workplace employer to get hired for this job';
   if(current.name!==null||p.job.stage!=='none'||p.starter.run)return 'Finish or cancel your current work first';
  }else{
   if(current.name===null)return 'Start a shift at its workplace first';
   if(name!==undefined&&name!==current.name)return 'Finish your current job first';
   name=current.name;
  }
  const definition=workDefinitions[name],handsOn=workTaskDefinitions[name];
  if(!Number.isFinite(now)||now<0)return 'Try this shift again';
  if(handsOn&&action==='start'&&!atJobTask(position,handsOn.station))return 'Visit the work supplies to start this shift';
  if(handsOn&&(position?.carId!=null||position?.rest||position?.playground))return 'Leave your vehicle or seat before working';
  if(definition.route)return 'Use the parcel delivery route at the store';
  if(definition.business?position?.interiorBusiness!==definition.business:position?.interiorBusiness!=null)return 'Enter the correct workplace to start or finish this shift';
  if(action==='start'&&!handsOn&&Number.isFinite(current.completed[name])&&now-current.completed[name]<definition.cooldownMs)return 'This job is resting. Try again in a minute';
  if(!position||![position.x,position.z].every(Number.isFinite)||(!handsOn&&Math.hypot(position.x-definition.x,position.z-definition.z)>7))return 'Get closer to your workplace';
  if(action==='start'){current.name=name;current.startedAt=now;current.taskRun=handsOn?{id:randomBytes(12).toString('hex'),step:0,pending:null}:null;}
  else{
   if(handsOn)return 'Complete each marked task to finish your shift';
   if(now-current.startedAt<definition.durationMs)return 'Keep helping until your work timer finishes';
   p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+workReward(name,p.classes));current.completed[name]=now;current.name=null;current.startedAt=null;
  }
  save();return null;
 }
 function takeClass(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!atLibraryDesk(position))return 'Visit the librarian to take a class';
  if(!m||typeof m.name!=='string'||!Object.hasOwn(workDefinitions,m.name))return 'Choose a class';
  if(!Number.isSafeInteger(m.amount)||m.amount<1||typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId))return 'Choose a whole-star payment and a valid payment ID';
  const receipt=p.classReceipts.find(r=>r.requestId===m.requestId);
  if(receipt)return receipt.name===m.name&&receipt.amount===m.amount?null:'This payment ID was already used for another class payment';
  const progress=p.classes[m.name],next=classTiers[progress.tier];
  if(!next)return 'You completed every tier for this class';
  if(m.amount>next.cost-progress.paid)return 'That payment is more than the remaining class cost';
  if(m.amount>p.stars)return 'Earn more stars for this class payment';
  p.stars-=m.amount;progress.paid+=m.amount;
  p.classReceipts.push({requestId:m.requestId,name:m.name,amount:m.amount,tier:next.tier});
  if(progress.paid===next.cost){progress.tier++;progress.paid=0;}
  save();return null;
 }
 function archiveMortgage(p){const loan=p.mortgage;if(loan&&loan.balance===0&&!p.mortgageHistory.some(paid=>paid.id===loan.id))p.mortgageHistory.push({id:loan.id,homeId:loan.homeId,principal:loan.principal});}
 function bankStatus(p){return {hasJob:p.hasJob,jobMembership:p.jobMembership,bankEligible:p.hasJob,mortgage:p.mortgage?{id:p.mortgage.id,homeId:p.mortgage.homeId,principal:p.mortgage.principal,balance:p.mortgage.balance}:null};}
 function bank(p,m,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!m||!['apply','repay','upgrade'].includes(m.action))return 'Choose a bank action';
  if(position?.interiorHome!=null)return 'Exit your home before visiting the bank';
  if(!atBankTeller(position))return 'Visit the bank teller to continue';
  if(m.action==='apply'){
   if(!p.hasJob)return 'Get hired for a job first';
   if(p.mortgage?.balance>0)return 'You already have a starter mortgage';
   if(state.homes.some(h=>h.owner===p.id))return 'You already have a home';
   const h=Number.isInteger(m.home)?state.homes[m.home]:null;
   if(!h)return 'Choose a home';if(h.owner!==null)return 'This home is already claimed';
   p.mortgage={id:randomBytes(16).toString('hex'),homeId:h.id,principal:starterMortgage,balance:starterMortgage,repayments:[]};
   h.owner=p.id;h.open=true;h.locked=false;h.paidOff=false;h.variant='starter';save();return null;
  }
  if(m.action==='repay'){
   const loan=p.mortgage;
   if(!loan||typeof m.loanId!=='string'||m.loanId!==loan.id)return 'Choose your current mortgage';
   if(typeof m.requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId)||!Number.isSafeInteger(m.amount)||m.amount<1||m.amount>loan.principal)return 'Choose a whole-star payment and a valid payment ID';
   const receipt=loan.repayments.find(r=>r.requestId===m.requestId);
   if(receipt)return receipt.amount===m.amount?null:'This payment ID was already used for another amount';
   const h=state.homes[loan.homeId];if(!h||h.owner!==p.id)return 'This mortgage does not match your home';
   if(m.amount>loan.balance)return 'That payment is more than your remaining mortgage';
   if(m.amount>p.stars)return 'Earn more stars for this payment';
   p.stars-=m.amount;loan.balance-=m.amount;loan.repayments.push({requestId:m.requestId,amount:m.amount});h.paidOff=loan.balance===0;save();return null;
  }
  const h=Number.isInteger(m.home)?state.homes[m.home]:null;
  if(!h||h.owner!==p.id)return 'Choose your own home';
  if(!h.paidOff||p.mortgage?.balance>0)return 'Pay off your current mortgage before upgrading';
  if(typeof m.variant!=='string'||!Object.hasOwn(homeVariants,m.variant)||homeVariants[m.variant].level!==homeVariants[h.variant].level+1)return 'Choose the next home upgrade';
  const principal=homeVariants[m.variant].cost;archiveMortgage(p);
  p.mortgage={id:randomBytes(16).toString('hex'),homeId:h.id,principal,balance:principal,repayments:[]};
  h.variant=m.variant;h.paidOff=false;save();return null;
 }
 function workTask(p,m,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  const name=p.work?.name,tasks=workTaskDefinitions[name]?.tasks,run=tasks?p.work.taskRun:null;
  if(!m||!run||m.assignmentId!==run.id)return 'Start your shift at its work supplies first';
  const task=tasks[run.step];if(!task||m.task!==task.id)return 'Follow the next marked work task';
  if(!atJobTask(position,task))return 'Walk closer to the marked work task';
  if(!Number.isFinite(now)||now<0)return 'Try this task again';
  if(m.action==='begin'){if(run.pending)return 'Finish this task first';run.pending={task:task.id,beganAt:now};save();return null;}
  if(m.action!=='finish'||!run.pending||run.pending.task!==task.id)return 'Begin this work task first';
  if(now-run.pending.beganAt<task.durationMs)return 'Keep helping for a moment';
  run.step++;run.pending=null;
  if(run.step===tasks.length){p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+workReward(name,p.classes));p.work.completed[name]=now;p.work.name=null;p.work.startedAt=null;p.work.taskRun=null;}
  save();return null;
 }

 function job(p,action,position,now=Date.now(),m={}){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!['start','pickup','deliver','cancel'].includes(action))return 'Choose a delivery job action';
  if(action==='cancel'){p.job.stage='none';p.job.id=null;save();return null;}
  if(position?.interiorHome!=null)return 'Exit your home before doing deliveries';
  if(action==='start'){
   if(!p.jobMembership.includes('delivery'))return 'Talk to the shopkeeper to get hired for delivery';
   if(p.job.stage!=='none'||p.work.name!==null||p.starter.run)return 'Finish or cancel your current work first';
   if(!atJobTask(position,parcelStation))return 'Visit the parcel station inside the store';
   Object.assign(p.job,{stage:'pickup',id:randomBytes(12).toString('hex'),destination:null,startedAt:now,legacy:false});save();return null;
  }
  if(action==='pickup'&&p.job.stage!=='pickup')return 'Start a delivery at the store first';
  if(action==='deliver'&&p.job.stage!=='deliver')return 'Pick up your parcel at the store first';
  if(m.assignmentId!==p.job.id)return 'This parcel belongs to a different delivery';
  const target=action==='pickup'?parcelStation:deliveryStop(p.job.destination);
  if(!atJobTask(position,target))return action==='pickup'?'Visit the parcel station inside the store':'Walk to your marked delivery door and leave your vehicle';
  if(action==='pickup'){p.job.destination=deliveryDestinations[deliveryRandom(deliveryDestinations.length)].id;p.job.stage='deliver';}
  else{p.job.stage='none';p.job.completedAt=now;p.job.deliveries++;p.job.id=null;p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+workReward('delivery',p.classes));}
  save();return null;
 }
 function quest(p,name,action,position,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(!['start','step','cancel'].includes(action))return 'Choose a quest action';
  if(action==='cancel'){p.quest.name=null;p.quest.step=0;save();return null;}
  if(position?.interiorHome!=null)return 'Exit your home before doing quests';
  const q=p.quest;if(action==='step'&&name===undefined)name=q.name;
  if(typeof name!=='string'||!Object.hasOwn(questDefinitions,name))return 'Choose gardener or librarian';
  if(action==='start'){
   if(q.name!==null)return 'Finish or cancel your current quest first';
   if(Number.isFinite(q.completed[name])&&now-q.completed[name]<60000)return 'Try this quest again in a minute';
  }else if(q.name!==name)return 'Start this quest first';
  const location=questDefinitions[name][action==='start'?0:q.step];
  if(position?.interiorBusiness!=null&&position.interiorBusiness!==(location.name==='cottage'?'library':location.name))return 'Visit the correct quest stop';
  if(!position||![position.x,position.z].every(Number.isFinite)||(position.interiorBusiness!==(location.name==='cottage'?'library':location.name)&&Math.hypot(position.x-location.x,position.z-location.z)>7))return 'Get closer to the '+location.name;
  if(action==='start'){q.name=name;q.step=0;}
  else if(q.step<questDefinitions[name].length-1)q.step++;
  else{q.name=null;q.step=0;q.completed[name]=now;p.stars=Math.min(Number.MAX_SAFE_INTEGER,p.stars+workReward(name==='gardener'?'nursery':'library',p.classes));}
  save();return null;
 }
 function petCare(p,action,now=Date.now()){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  if(p.pet==='none')return 'Choose a pet first';
  if(!['feed','play','rest'].includes(action))return 'Choose feed, play or rest';
  if(Number.isFinite(p.petCare.last[action])&&now-p.petCare.last[action]<60000)return 'Your pet enjoyed that! Try again in a minute';
  p.petCare[action]=Math.min(Number.MAX_SAFE_INTEGER,p.petCare[action]+1);p.petCare.last[action]=now;save();return null;
 }
 function insideHome(h,position){return position?.interiorHome===h.id&&interiorRoomAt(h.variant,position.x,position.z)!==null;}
 function nearHome(h,position){const loc=plots[h.id];return position?.interiorHome==null&&position?.interiorBusiness==null&&position&&[position.x,position.z].every(Number.isFinite)&&Math.hypot(position.x-loc[0],position.z-loc[1]-homeVariants[h.variant].d/2)<=7;}
 function entry(p,home,position){
  if(!p||state.profiles[p.username]!==p)return 'Join the town first';
  const h=Number.isInteger(home)?state.homes[home]:null;if(!h)return 'Choose a home';
  if(position?.interiorHome!=null||position?.interiorBusiness!=null)return 'Exit your current building first';
  if(position?.carId!=null)return 'Leave the car before entering a home';
  if(h.owner===null)return 'This home needs an owner first';
  const loc=plots[h.id];if(!position||![position.x,position.z].every(Number.isFinite)||Math.hypot(position.x-loc[0],position.z-loc[1]-homeVariants[h.variant].d/2)>5)return 'Get closer to this home doorway';
  return null;
 }
 function action(p,m,position){const h=Number.isInteger(m?.home)?state.homes[m.home]:null;if(!p||state.profiles[p.username]!==p)return 'Join the town first';if(!m||typeof m!=='object')return 'Unknown action';
  if(m.type==='style'){
   const presentation=m.presentation??p.presentation,pet=m.pet===undefined?p.pet:m.pet,vehicle=m.vehicle??p.vehicle;
   const character=m.character===undefined?(presentation!==p.presentation?(presentation==='feminine'?'female-a':'male-a'):p.character):m.character;
   const hairColor=m.hairColor===undefined?p.hairColor:m.hairColor,pantsColor=m.pantsColor===undefined?p.pantsColor:m.pantsColor;
   if(!palette.includes(m.color)||!['none','cap','crown'].includes(m.hat)||!['none','balloon','book','glasses','sunglasses','cane','luggage'].includes(m.prop)||!presentations.includes(presentation)||!pets.includes(pet)||!vehicles.includes(vehicle)||!appearancePalette.includes(hairColor)||!appearancePalette.includes(pantsColor)||!characters.includes(character))return 'Invalid style';
   const cost=pet!=='none'&&!p.ownedPets.includes(pet)?petPrice:0;
   if(cost&&!atVetDesk(position))return 'Visit the vet to adopt a new pet at the adoption desk';
   if(p.stars<cost)return 'Earn '+cost+' stars to adopt this pet';
   p.stars-=cost;if(cost)p.ownedPets.push(pet);
   Object.assign(p,{color:m.color,hat:m.hat,prop:m.prop,presentation,character,pet,vehicle:'walk',hairColor,pantsColor});save();return null;
  }
  if(!h)return 'Choose a home';
  if(m.type==='claim')return 'Visit the bank to apply for a starter home';
  if(h.owner!==p.id)return 'Only this home owner can change it';
  const operation=[m.type,m.home,m.kind,m.room??0,m.x,m.z,m.item];if(['rotation','supportId','surfaceId','expectedRevision'].some(k=>Object.hasOwn(m,k)))operation.push(m.rotation??0,m.supportId??null,m.surfaceId??null,m.expectedRevision??null);
  const receipt=['furnish','remove','furnitureMove'].includes(m.type)?furnitureReceipt(p,m,operation):null;if(receipt?.error||receipt?.replay)return receipt.error;
  if(m.type==='lock')return 'Homes are always open to visitors';
  else if(m.type==='release'){if(p.furnitureDeliveries.some(d=>d.homeId===h.id))return 'Collect your front-door packages before releasing this home';if(p.mortgage?.homeId===h.id&&p.mortgage.balance>0)return 'Pay off your current mortgage before releasing this home';if(!insideHome(h,position)&&!nearHome(h,position))return 'Visit your home doorway to release it';if(p.mortgage?.homeId===h.id){archiveMortgage(p);p.mortgage=null;}h.owner=null;h.locked=false;h.open=false;h.variant='starter';h.paidOff=false;for(const item of h.furniture)if(Object.hasOwn(furnitureCatalog,item.kind))p.furnitureInventory[item.kind]=(p.furnitureInventory[item.kind]||0)+1;h.furniture=[];}
  else if(m.type==='furnish'||m.type==='furnitureMove'){
   const moving=m.type==='furnitureMove',existing=moving?h.furniture.find(f=>f.id===m.item):null;
   if(moving&&!existing)return 'Furniture not found';
   if(existing&&m.kind!==undefined&&m.kind!==existing.kind)return 'Furniture kind cannot change';
   if(existing&&!Number.isSafeInteger((existing.revision??0)+1))return 'Furniture revision limit reached';
   if(existing&&m.expectedRevision!==undefined&&m.expectedRevision!==(existing.revision??0))return 'This furniture changed; refresh before moving it';
   if(existing&&furnitureHasChildren(h,existing.id))return 'Move or pack the decorations on this furniture first';
   const candidate={kind:existing?.kind??m.kind,room:m.room??existing?.room??0,x:m.x,z:m.z,rotation:m.rotation??existing?.rotation??0,supportId:m.supportId??null,surfaceId:m.surfaceId??null};
   if(position?.rest||position?.playground||position?.carId!=null||!insideHome(h,position)||interiorRoomAt(h.variant,position.x,position.z)!==candidate.room||existing&&(existing.room??0)!==candidate.room)return 'Stand inside this home and room to decorate';
   const checked=furniturePlacement(h,candidate,{ignoreId:existing?.id??null});if(checked.error)return checked.error;
   if(!moving&&h.furniture.length>=20)return 'This home has 20 pieces already';
   if(moving)Object.assign(existing,checked.item,{revision:(existing.revision??0)+1});
   else{if(!(p.furnitureInventory[m.kind]>0))return 'Buy this item at the store and collect its package first';p.furnitureInventory[m.kind]--;h.furniture.push({id:randomBytes(12).toString('hex'),...checked.item,revision:0});}
  }
  else if(m.type==='remove'){
   const i=h.furniture.findIndex(f=>f.id===m.item);if(i<0)return 'Furniture not found';
   if(position?.rest||position?.playground||position?.carId!=null||!insideHome(h,position)||interiorRoomAt(h.variant,position.x,position.z)!==(h.furniture[i].room??0))return 'Stand inside this home and room to remove furniture';
   if(m.expectedRevision!==undefined&&m.expectedRevision!==(h.furniture[i].revision??0))return 'This furniture changed; refresh before packing it';
   if(furnitureHasChildren(h,m.item))return 'Move or pack the decorations on this furniture first';
   if(!Number.isSafeInteger((p.furnitureInventory[h.furniture[i].kind]||0)+1))return 'Furniture inventory is full';
   const [removed]=h.furniture.splice(i,1);p.furnitureInventory[removed.kind]=(p.furnitureInventory[removed.kind]||0)+1;
  }
  else return 'Unknown action';if(receipt)p.furnitureReceipts.push({requestId:m.requestId,payload:receipt.payload});save();return null;
 }
 return {recordHoopsBest,hoopsLeaderboard,scavenger,scavengerLeaderboard,state,save,auth,logout,tendGarden,yardUpgrade,carShop,furnitureOrder,furnitureSell,furniturePickup,action,activity,work,workTask,starterTask,takeClass,bank,bankStatus,entry,job,quest,petCare,setSettings,resetPassword,createApprovedAccount,setPlayerEnabled,changePassword,backup};
}





















