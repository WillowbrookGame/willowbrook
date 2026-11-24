
import {mkdir,readdir,readFile,realpath,lstat,writeFile} from 'node:fs/promises';
import {basename,dirname,isAbsolute,join,relative,sep,resolve} from 'node:path';

const marker='willowbrook-godot-local-account-preview-v1\n';
const contains=(dir,child)=>{
 const r=relative(dir,child);
 return !r||(!isAbsolute(r)&&r!=='..'&&!r.startsWith('..'+sep));
};

// Resolve existing parents before mkdir or writer creation, including junctions.
async function canonicalCandidate(target){
 try{return await realpath(target);}
 catch(error){
  const parent=dirname(target);
  if(error.code!=='ENOENT'||parent===target)throw error;
  return join(await canonicalCandidate(parent),basename(target));
 }
}
export async function validatePreviewDirectory({accountsDir,source,projectRoot=null,site}){
 if(typeof accountsDir!=='string'||!isAbsolute(accountsDir))throw Error('Use an absolute path for the separate account preview data folder.');
 const target=resolve(accountsDir);
 const protectedRoots=await Promise.all([source,projectRoot,site].filter(Boolean).map(p=>realpath(p)));
 for(const candidate of [target,await canonicalCandidate(target)]){
  if(protectedRoots.some(root=>contains(root,candidate)||contains(candidate,root)))throw Error('Account preview data must be outside the project, runtime source and static preview.');
 }
 return target;
}

export async function openPreviewAccounts({accountsDir,source,projectRoot=null,site,makeStore,seeds=[],allowEmpty=false,parentDeskEnabled=false}){
 const locations={accountsDir,source,projectRoot,site};
 const target=await validatePreviewDirectory(locations);
 await mkdir(target,{recursive:true});
 const dir=await realpath(target);
 await validatePreviewDirectory({...locations,accountsDir:dir});
 const markerFile=join(dir,'.willowbrook-preview-store');
 const listing=await readdir(dir);
 const names=parentDeskEnabled?listing.filter(n=>!['.willowbrook-family-desk-opt-in','.willowbrook-family-desk-writer'].includes(n)):listing;
 if(!names.length)await writeFile(markerFile,marker,{flag:'wx',mode:0o600});
 else if(!names.includes('.willowbrook-preview-store')||await readFile(markerFile,'utf8')!==marker)throw Error('Use a new empty preview data folder; an existing non-preview store was not opened.');
 for(const name of names){
  if(!['.willowbrook-preview-store','preview-accounts-v1.json','preview-accounts-v1.json.bak','preview-accounts-v1.json.tmp','backups'].includes(name))throw Error('Account preview folder contains unrelated files.');
  if((await lstat(join(dir,name))).isSymbolicLink())throw Error('Unexpected link in the preview account folder.');
 }
 const file=join(dir,'preview-accounts-v1.json');
 const store=makeStore(file);
 if(!Array.isArray(seeds)||seeds.length>16)throw Error('Invalid disposable account seed list.');
 if(seeds.length&&!Object.keys(store.state.profiles).length){
  const names=new Set();
  for(const seed of seeds){
   const user=typeof seed?.username==='string'?seed.username.toLowerCase().trim():'';
   if(!/^[a-z0-9_-]{3,20}$/.test(user)||names.has(user)||typeof seed.password!=='string'||seed.password.length<6||seed.password.length>100)throw Error('Use distinct disposable preview usernames and passwords.');
   names.add(user);
  }
  store.setSettings({registrationEnabled:true,chatEnabled:false});
  for(const seed of seeds){
   const result=store.auth({type:'register',username:seed.username,password:seed.password});
   if(result.error)throw Error('Could not create a disposable preview account.');
   store.logout(result.session);
  }
 }
 if(!allowEmpty&&!Object.keys(store.state.profiles).length)throw Error('Provide disposable preview accounts at first startup via WILLOWBROOK_PREVIEW_ACCOUNTS.');
 store.setSettings({registrationEnabled:false,chatEnabled:false});
 return Object.assign(store,{accountFile:file});
}

