import {readFileSync} from 'node:fs';
export const reefPhotoCatalog=[
 'clownfish','bluetang','butterflyfish','coralgrouper',
 'parrotfish','tuna','shark','sunfish',
];
const allowed=new Set(reefPhotoCatalog);
const rid=x=>typeof x==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(x);

export function createPreviewReefPhotos(store){
 function saved(profile){
  const raw=profile?.reefPhotos;
  if(raw===undefined)return [];
  if(!Array.isArray(raw)||raw.length>reefPhotoCatalog.length||raw.some(id=>typeof id!=='string'||!allowed.has(id)))
   throw Error('Invalid reef photos save');
  return [...new Set(raw)];
 }
 function save(profile,old,next){
  const previous=profile.reefPhotos;
  profile.reefPhotos=next;
  try{store.save();return true;}
  catch{
   try{const d=JSON.parse(readFileSync(store.accountFile,'utf8')).profiles[profile.username];if(JSON.stringify(d?.reefPhotos)===JSON.stringify(next))return true;}catch{}
   if(previous===undefined)delete profile.reefPhotos;else profile.reefPhotos=old;
   return false;
  }
 }
 function snapshot(profile){
  return saved(profile);
 }
 function apply(p,m){
  if(!p?.profile)return {ok:false,text:'Sign in to save reef photos.'};
  if(m.operation!=='record'||!rid(m.requestId)||typeof m.species!=='string'||!allowed.has(m.species))
   return {ok:false,text:'Choose a valid reef wildlife species.'};
  const old=saved(p.profile);
  const isNew=!old.includes(m.species);
  if(!isNew){
   return {ok:true,text:'Reef photo already in your book.',species:m.species,newDiscovery:false,count:old.length,total:reefPhotoCatalog.length};
  }
  const next=[...old,m.species];
  if(!save(p.profile,old,next))
   return {ok:false,text:'Could not save your reef photo.'};
  return {ok:true,text:'Reef photo saved!',species:m.species,newDiscovery:true,count:next.length,total:reefPhotoCatalog.length};
 }
 return {snapshot,apply};
}
