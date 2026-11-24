import {randomBytes} from 'node:crypto';
import {readFileSync} from 'node:fs';
const species=['beaver','bee','bunny','cat','caterpillar','chick','cow','crab','deer','dog','elephant','fish','fox','giraffe','hog','koala','lion','monkey','panda','parrot','penguin','pig','polar','tiger'];
const keys=(m,...fields)=>Object.keys(m).every(k=>['type','action','operation',...fields].includes(k));
const validId=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(id);
const nearDesk=(p,zone,now)=>p.zone===zone&&p.grounded&&Math.abs(p.y)<1.25&&now-p.updated<=2500&&Math.abs(p.x)<=3.4&&p.z>=-.85&&p.z<=3.9;
const loanId=id=>typeof id==='string'&&/^[a-f0-9]{32}$/.test(id);
const doors=[[-51,-19],[-51,5],[-51,29],[51,-19],[51,5],[51,29]];
const permittedHome=(profile,homes)=>homes.find(h=>h.owner===profile.id&&doors[h.id]);
const replyError=error=>({error});
export function createPreviewPets(store){
 const homes=store.state.homes;
 const savedPets=p=>p.previewPets&&typeof p.previewPets==='object'?p.previewPets:{};
 const petSnapshot=p=>{
  const saved=savedPets(p), bought=Array.isArray(saved.owned)?saved.owned:[];
  const owned=species.filter(k=>p.ownedPets.includes(k)).map(k=>({id:'legacy-'+k,species:k}));
  for(const row of bought)if(row&&validId(row.id)&&species.includes(row.species))owned.push({id:row.id,species:row.species});
  const active=Object.hasOwn(saved,'activeId')?saved.activeId:'legacy-'+p.pet;
  return {owned,activeId:owned.some(x=>x.id===active)?active:null};
 };
 function snapshot(p){
  const h=permittedHome(p,homes);
  return {pets:petSnapshot(p),home:h?{plot:h.id,variant:h.variant}:null,
   homePlots:homes.filter(h=>doors[h.id]).map(h=>({plot:h.id,available:h.owner===null})),
   mortgage:store.bankStatus(p).mortgage,bankEligible:store.bankStatus(p).bankEligible};
 }
 // fs.rename is the legacy store commit point. Its daily backup runs afterward;
 // on backup error the transaction is already durable. Verify exact intended
 // profile/home fields before reporting success, otherwise restore memory.
 function commit(p,change){
  const old={stars:p.stars,pet:p.pet,ownedPets:p.ownedPets.slice(),mortgage:structuredClone(p.mortgage),requests:structuredClone(p.previewPets),mortgageHistory:structuredClone(p.mortgageHistory),housingReceipts:structuredClone(p.previewHousingReceipts),homes:structuredClone(homes)};
  try{return change();}
  catch(e){
   try{
    const disk=JSON.parse(readFileSync(store.accountFile,'utf8')),d=disk.profiles[p.username];
    const comparable=q=>[q.stars,q.pet,q.ownedPets,q.mortgage,q.previewPets,q.mortgageHistory,q.previewHousingReceipts];
    if(d&&JSON.stringify(comparable(d))===JSON.stringify(comparable(p))&&JSON.stringify(disk.homes)===JSON.stringify(homes))return {};
   }catch{}
   Object.assign(p,{stars:old.stars,pet:old.pet,ownedPets:old.ownedPets,mortgage:old.mortgage,mortgageHistory:old.mortgageHistory});
   if(old.housingReceipts===undefined)delete p.previewHousingReceipts;else p.previewHousingReceipts=old.housingReceipts;
   if(old.requests===undefined)delete p.previewPets;else p.previewPets=old.requests;
   homes.forEach((h,i)=>Object.assign(h,old.homes[i]));
   return replyError('Could not save. Nothing was changed.');
  }
 }
 function apply(p,m,now){
  const profile=p.profile;
  if(m.action==='housing'){
   if(m.operation==='leave'&&keys(m)){p.petHome=null;return {text:'Left home.'};}
   if(m.operation==='repay'||m.operation==='upgrade'){
    const repay=m.operation==='repay';
    if(!validId(m.requestId)||!loanId(m.loanId)||(repay
      ?!keys(m,'loanId','amount','requestId')||!Number.isSafeInteger(m.amount)||m.amount<1
      :!keys(m,'plot','variant','loanId','requestId')||!Number.isInteger(m.plot)||!doors[m.plot]||!['cottage','family'].includes(m.variant)))
     return replyError(repay?'Choose a whole-star payment for your current loan.':'Choose the next upgrade for your own home.');
    const fp=JSON.stringify(repay?['repay',m.loanId,m.amount]:['upgrade',m.loanId,m.plot,m.variant]);
    const receipts=Array.isArray(profile.previewHousingReceipts)?profile.previewHousingReceipts:[];
    const duplicate=receipts.find(r=>r?.requestId===m.requestId);
    if(duplicate)return duplicate.fingerprint===fp?{text:'This Bank request was already saved.'}:replyError('That Bank request was used for different details.');
    if(!nearDesk(p,'bank',now))return replyError('Speak to the Bank teller first.');
    const h=permittedHome(profile,homes);
    if(!h||profile.mortgage?.id!==m.loanId||profile.mortgage.homeId!==h.id)return replyError('Refresh your current mortgage before continuing.');
    if(!repay&&m.plot!==h.id)return replyError('Choose your own home to upgrade.');
    const wire=repay?{action:'repay',loanId:m.loanId,amount:m.amount,requestId:m.requestId}:{action:'upgrade',home:h.id,variant:m.variant};
    const result=commit(profile,()=>{
     const prior=profile.previewHousingReceipts;
     profile.previewHousingReceipts=[...receipts,{requestId:m.requestId,fingerprint:fp}];
     try{
      const error=store.bank(profile,wire,{interiorBusiness:'bank',x:-54,z:-48});
      if(error){if(prior===undefined)delete profile.previewHousingReceipts;else profile.previewHousingReceipts=prior;return {error};}
      return {};
     }catch(e){throw e;}
    });
    return result.error?result:{text:repay?'Mortgage payment saved.':'Your '+m.variant+' upgrade is ready.'};
   }
   if(!Number.isInteger(m.plot)||!doors[m.plot])return replyError('Choose a home plot.');
   if(m.operation==='enter'&&keys(m,'plot')){
    const home=homes[m.plot], [x,z]=doors[m.plot];
    if(home?.owner!==profile.id)return replyError('Only your own home can manage companions.');
    if(p.zone!=='town'||!p.grounded||Math.abs(p.y)>=1.25||now-p.updated>2500||Math.hypot(x-p.x,z-p.z)>3.0)return replyError('Walk to your own front door.');
    p.petHome={plot:m.plot,at:now,inRoom:false};
    return {text:'Home is ready.'};
   }
   if(m.operation==='claim'&&keys(m,'plot','requestId')&&validId(m.requestId)){
    if(!nearDesk(p,'bank',now))return replyError('Speak to the Bank teller first.');
    const current=permittedHome(profile,homes);
    if(current?.id===m.plot)return {text:'You already own this home.'};
    const result=commit(profile,()=>{
     // Pass the corresponding legacy teller position after validating the
     // Godot scene's local desk coordinates.
     const error=store.bank(profile,{action:'apply',home:m.plot},{interiorBusiness:'bank',x:-54,z:-48});
     return error?{error}:{};
    });
    return result.error?result:{text:'Starter home approved.'};
   }
   return replyError('Choose a supported housing action.');
  }
  if(!validId(m.requestId))return replyError('Please retry this pet action.');
  if(m.operation==='adopt'&&keys(m,'species','requestId')&&species.includes(m.species)){
   const saved=savedPets(profile);
   const owned=Array.isArray(saved.owned)?saved.owned:[];
   const earlier=owned.find(row=>row?.requestId===m.requestId);
   if(earlier)return earlier.species===m.species?{text:'That adoption was already saved.'}:replyError('That request was already used for a different adoption.');
   if(!nearDesk(p,'vet',now))return replyError('Speak to the Vet at the adoption desk first.');
   if(profile.stars<8)return replyError('You need 8 saved stars to adopt this pet.');
   const result=commit(profile,()=>{
    profile.previewPets={...saved,owned:[...owned,{id:randomBytes(12).toString('hex'),species:m.species,requestId:m.requestId}]};
    profile.stars-=8;
    store.save();
    return {};
   });
   return result.error?result:{text:'Pet adopted for 8 stars. Visit your home to bring it along.'};
  }
  if(m.operation==='equip'&&keys(m,'id','requestId')&&(m.id===null||validId(m.id))){
   if(p.zone!=='private'||!p.petHome?.inRoom||homes[p.petHome.plot]?.owner!==profile.id)return replyError('Choose your companion inside your own home.');
   if(m.id!==null&&!petSnapshot(profile).owned.some(k=>k.id===m.id))return replyError('Adopt that pet before choosing it.');
   const saved=savedPets(profile), receipts=Array.isArray(saved.equipReceipts)?saved.equipReceipts:[];
   const earlier=receipts.find(r=>r?.requestId===m.requestId);
   if(earlier)return earlier.id===m.id?{text:'Companion selection already saved.'}:replyError('That request was already used for a different companion.');
   const result=commit(profile,()=>{
    profile.previewPets={...saved,activeId:m.id,equipReceipts:[...receipts.slice(-127),{requestId:m.requestId,id:m.id}]};
    store.save();return {};
   });
   return result.error?result:{text:m.id===null?'Your companion is resting at home.':'Your companion is ready.'};
  }
  return replyError('Choose a supported pet action.');
 }
 function moved(p,pose,now){
  if(!p.petHome)return;
  if(pose.zone==='private'){
   if(p.petHome.inRoom||p.zone==='town'&&now-p.petHome.at<=5000)p.petHome.inRoom=true;
   else p.petHome=null;
  }else if(!(p.zone==='town'&&pose.zone==='town'&&!p.petHome.inRoom&&now-p.petHome.at<=5000&&Math.hypot(pose.x-doors[p.petHome.plot][0],pose.z-doors[p.petHome.plot][1])<=3.0)){
   p.petHome=null;
  }
 }
 return {snapshot,apply,moved,companion:p=>{const pets=petSnapshot(p);return pets.owned.find(row=>row.id===pets.activeId)?.species??null;}};
}

