import {createHash,randomBytes,scryptSync,timingSafeEqual} from 'node:crypto';
import fs from 'node:fs';
import {isAbsolute,resolve,basename,join} from 'node:path';

const marker='willowbrook-local-family-desk-v1\n';
const namePattern=/^[a-z0-9_-]{3,20}$/;
const keyPattern=/^[A-Za-z0-9_-]{32}$/;
const idPattern=/^[a-f0-9]{24}$/;
const token=()=>randomBytes(24).toString('base64url');
const id=()=>randomBytes(12).toString('hex');
const sha=v=>createHash('sha256').update(v).digest('hex');
const h = (password,salt,adult) => adult?scryptSync(password,salt,64,{N:32768,r:8,p:1,maxmem:67108864}):scryptSync(password,salt,64);
const limits={parents:16,childrenPerHousehold:16,invitesPerIssuer:12,recordedSessions:48};
const same=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&Buffer.byteLength(a)===Buffer.byteLength(b)&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
const goodName=v=>{
 const name=typeof v==='string'?v.trim().toLowerCase():'';
 return namePattern.test(name)&&!['__proto__','constructor','prototype'].includes(name)?name:null;
};
const goodPassword=v=>typeof v==='string'&&v.length>=10&&v.length<=100;
const publicPlayer=(p,perm)=>({id:p.id,nickname:p.username,avatar:p.character,playEnabled:!p.disabled,chatEnabled:perm.chatEnabled===true});
const own=(o,k)=>Object.hasOwn(o,k)?o[k]:null;
const put=(o,key,value)=>Object.defineProperty(o,key,{value,writable:true,enumerable:true,configurable:true});
const on=(q,n)=>q&&typeof q==='object'&&!Array.isArray(q)&&Object.keys(q).length===n.length&&n.every(k=>Object.hasOwn(q,k));
const fresh=()=>({version:1,owner:null,parents:{},children:{},invites:{}});
const validGlobalChat=p=>on(p,['version','enabled'])&&p.version===1&&typeof p.enabled==='boolean';
function refuse(message,status=400){throw Object.assign(new Error(message),{deskError:true,status});}
function validate(desk){
 if(!on(desk,['version','owner','parents','children','invites'])||desk.version!==1
    ||![desk.parents,desk.children,desk.invites].every(x=>x&&typeof x==='object'&&!Array.isArray(x)))throw Error('Unsupported family desk data.');
 const credential=a=>a&&goodName(a.username)===a.username&&/^[a-f0-9]{32}$/.test(a.salt)&&/^[a-f0-9]{128}$/.test(a.digest);
 if(desk.owner!==null&&!credential(desk.owner))throw Error('Invalid family owner data.');
 if(Object.keys(desk.parents).length>limits.parents||Object.entries(desk.parents).some(([k,v])=>!credential(v)||v.username!==k||!idPattern.test(v.household)))throw Error('Invalid family parent data.');
 const households=new Set(Object.values(desk.parents).map(p=>p.household));
 if(Object.entries(desk.children).some(([k,v])=>!/^[1-9][0-9]*$/.test(k)||!v||!households.has(v.household)||typeof v.chatEnabled!=='boolean'))throw Error('Invalid family child data.');
 if(Object.entries(desk.invites).some(([k,v])=>!/^[a-f0-9]{64}$/.test(k)||!v||!idPattern.test(v.id)||!['parent','player','reset'].includes(v.purpose)||!Number.isSafeInteger(v.expiresAt)||typeof v.issuer!=='string'))throw Error('Invalid family invite data.');
 return desk;
}
export function requireDeskOptIn(path,accountsDir) {
 if(typeof path!=='string'||!isAbsolute(path)||typeof accountsDir!=='string'||!isAbsolute(accountsDir)||resolve(path).toLowerCase()!==join(resolve(accountsDir),'.willowbrook-family-desk-opt-in').toLowerCase())throw Error('Use the dedicated Family Desk marker inside the selected local account directory.');
 if(!/^willowbrook-(?:family|parent)-desk-[a-z0-9-]+$/i.test(basename(resolve(accountsDir))))throw Error('Family Desk requires its named isolated account folder.');
 const p=resolve(path), info=fs.lstatSync(p);
 if(!info.isFile()||info.isSymbolicLink()||info.size!==Buffer.byteLength(marker)||fs.realpathSync(p).toLowerCase()!==p.toLowerCase()||fs.readFileSync(p,'utf8')!==marker)throw Error('Invalid local family desk opt-in file.');
}
export function claimDeskWriter(accountsDir){
 const file=join(accountsDir,'.willowbrook-family-desk-writer');
 const nonce=token();
 let fd;
 try{fd=fs.openSync(file,'wx',0o600);}
 catch(e){if(e.code==='EEXIST')throw Error('Family Desk account data is already locked by an isolated writer.');throw e;}
 try{fs.writeFileSync(fd,nonce);fs.fsyncSync(fd);}catch(e){try{fs.unlinkSync(file);}catch{}throw e;}finally{fs.closeSync(fd);}
 let held=true;
 const release=()=>{if(!held)return;held=false;process.removeListener('exit',release);try{if(fs.readFileSync(file,'utf8')===nonce)fs.unlinkSync(file);}catch{}};
 process.once('exit',release);
 return release;
}
// The launch flag is still required. Preserve the prior preference for legacy v1
// saves; unknown policy shapes never enable chat.
export function globalFamilyChatAllowed(state){
 if(!state||!Object.hasOwn(state,'familyChatPolicy'))return true;
 const policy=state.familyChatPolicy;
 return validGlobalChat(policy)&&policy.enabled;
}
export function canManagedPlayerChat(state,profile){
 const d=state?.familyDesk;
 if(d===undefined)return true;
 if(d?.version!==1||!d.children||typeof d.children!=='object')return false;
 const key=String(profile.id);
 return !Object.hasOwn(d.children,key)||d.children[key]?.chatEnabled===true;
}
export function createFamilyDesk({accounts,accountFile,makeStore,characters,clock=Date.now,chatEnabledAtLaunch=false,onGlobalChatChanged=()=>{},onPlayerChanged=()=>{}}){
 if(!accounts||!isAbsolute(accountFile)||!Array.isArray(characters)||!characters.includes('male-a'))throw Error('Local family desk dependencies are missing.');
 if(accounts.state.familyDesk!==undefined)validate(accounts.state.familyDesk);
 if(Object.hasOwn(accounts.state,'familyChatPolicy')&&!validGlobalChat(accounts.state.familyChatPolicy))throw Error('Invalid family chat policy.');
 const sessions=new Map(), days=86400000;
 const read=()=>accounts.state.familyDesk??fresh();
 const profile=(state,n)=>Object.values(state.profiles).find(p=>p.id===n)??null;
 const adult=(d,name)=>d.owner?.username===name?d.owner:own(d.parents,name);
 const identity=(d,who)=>(who?.role==='owner'&&d.owner?.username===who.username)?d.owner:who?.role==='parent'?own(d.parents,who.username):null;
 const canChat=profile=>canManagedPlayerChat(accounts.state,profile);
 const chatPolicy=()=>({ enabled:chatEnabledAtLaunch===true&&globalFamilyChatAllowed(accounts.state), canEnable:chatEnabledAtLaunch===true });
 function commit(edit) {
  // Single Node process and a synchronous critical section. The profile and
  // consumed invite reach disk together; failed writes never change live state.
  const before=accounts.state,draft=structuredClone(before);
  draft.familyDesk=validate(draft.familyDesk??fresh());
  const result=edit(draft,draft.familyDesk);
  validate(draft.familyDesk);
  const temp=accountFile+'.tmp';
  let fd, opened=false, renamed=false;
  try {
   fd=fs.openSync(temp,'wx',0o600);opened=true;
   fs.writeFileSync(fd,JSON.stringify(draft));
   fs.fsyncSync(fd);fs.closeSync(fd);fd=undefined;
   fs.renameSync(temp,accountFile);renamed=true;
  } finally {
   if(fd!==undefined)fs.closeSync(fd);
   if(opened&&!renamed)try{fs.unlinkSync(temp);}catch{}
  }
  before.familyDesk=draft.familyDesk;before.sessions=draft.sessions;before.nextProfile=draft.nextProfile;
  if(Object.hasOwn(draft,'familyChatPolicy'))before.familyChatPolicy=draft.familyChatPolicy;
  for(const [k,next] of Object.entries(draft.profiles)){
   if(Object.hasOwn(before.profiles,k))Object.assign(before.profiles[k],next);
   else put(before.profiles,k,next);
  }
  return result;
 }
 function adultCredential(username,password){
  const salt=randomBytes(16).toString('hex');
  return {username,salt,digest:h(password,salt,true).toString('hex')};
 }
 function bootstrapOwner(username,password){
  const who=goodName(username);
  if(!who||!goodPassword(password))refuse('Use a valid account name and a password of at least 10 characters.');
  commit((s,d)=>{
   if(d.owner||own(s.profiles,who))refuse('An owner already exists or that name is unavailable.',409);
   d.owner=adultCredential(who,password);
  });
 }
 function roleOnly(actor,role){if(actor?.role!==role)refuse('This action is not available.',403);}
 function childScoped(s,d,actor,n){
  roleOnly(actor,'parent');
  if(!Number.isSafeInteger(n)||n<1)refuse('Player not found.',404);
  const perm=own(d.children,String(n));
  const p=profile(s,n);
  if(!p||!perm||perm.household!==actor.household)refuse('Player not found.',404);
  return [p,perm];
 }
 function revokeChildSessions(s,p){for(const [k,v] of Object.entries(s.sessions))if(v.id===p.id)delete s.sessions[k];}
 function setPlayerPassword(p,password){
  p.salt=randomBytes(16).toString('hex');p.hash=h(password,p.salt,false).toString('hex');p.mustChangePassword=false;
 }
 function createChild(s,d,household,nickname,avatar,password){
  const username=goodName(nickname);
  if(!username||!characters.includes(avatar??'male-a')||!goodPassword(password))refuse('Use a valid nickname, avatar, and password of at least 10 characters.');
  if(own(s.profiles,username)||adult(d,username)||Object.values(d.invites).some(i=>i.purpose==='parent'&&i.username===username&&i.expiresAt>clock()))refuse('That nickname is unavailable.',409);
  if(Object.keys(s.profiles).length>=100||Object.values(d.children).filter(c=>c.household===household).length>=limits.childrenPerHousehold)refuse('Player limit reached.',409);
  const isolated=makeStore(null);
  if(isolated.createApprovedAccount(username,password).error)refuse('Player could not be created.');
  const p=structuredClone(isolated.state.profiles[username]);
  p.id=s.nextProfile++;p.character=avatar??'male-a';p.presentation=p.character.startsWith('female-')?'feminine':'classic';
  p.mustChangePassword=false;p.disabled=false;
  put(s.profiles,username,p);
  const perm={household,chatEnabled:false};put(d.children,String(p.id),perm);
  return publicPlayer(p,perm);
 }
 function purge(d,now){for(const [k,v] of Object.entries(d.invites))if(v.expiresAt<=now)delete d.invites[k];}
 function createInvite(d,actor,kind,extra={}){
  const now=clock();purge(d,now);
  if(Object.values(d.invites).filter(i=>i.issuer===actor.username).length>=limits.invitesPerIssuer)refuse('Too many pending invites.',409);
  const code=token(),info={id:id(),purpose:kind,issuer:actor.username,expiresAt:now+(kind==='parent'?days:30*60000),...extra};
  put(d.invites,sha(code),info);
  return {code,inviteId:info.id,expiresAt:info.expiresAt};
 }
 function take(d,code,kind){
  if(typeof code!=='string'||!keyPattern.test(code))refuse('Invite is invalid, expired, or already used.',404);
  const hash=sha(code),info=own(d.invites,hash);
  if(!info||info.purpose!==kind||info.expiresAt<=clock())refuse('Invite is invalid, expired, or already used.',404);
  delete d.invites[hash];
  return info;
 }
 function pruneSessions(){
  const now=clock();
  for(const [key,session] of sessions)if(session.expiresAt<=now)sessions.delete(key);
 }
 function login(username,password){
  const name=goodName(username),d=read();
  if(!name||!goodPassword(password))refuse('Desk sign-in failed.',401);
  const p=adult(d,name);
  // Work for unknown users as well; do not expose hashes or account existence.
  const calc=h(password,p?.salt??'00000000000000000000000000000000',true).toString('hex');
  if(!p||!same(calc,p.digest))refuse('Desk sign-in failed.',401);
  pruneSessions();
  for(const [k,v] of sessions)if(v.username===name)sessions.delete(k);
  if(sessions.size>=limits.recordedSessions)refuse('Too many desk sessions.',429);
  const secret=token(),actor={username:p.username,role:d.owner===p?'owner':'parent',household:p.household??null,csrf:token(),expiresAt:clock()+4*3600000};
  sessions.set(sha(secret),actor);
  return {secret,actor};
 }
 function authenticate(secret){
  if(typeof secret!=='string'||!keyPattern.test(secret))return null;
  pruneSessions();
  const actor=sessions.get(sha(secret))??null;
  return identity(read(),actor)?actor:null;
 }
 function status(actor){
  if(!actor)return {role:null};
  const d=read(),state=accounts.state;
  const inv=Object.values(d.invites).filter(i=>i.issuer===actor.username&&i.expiresAt>clock()).map(i=>({id:i.id,purpose:i.purpose,expiresAt:i.expiresAt}));
  const players=actor.role==='parent'?Object.values(state.profiles).flatMap(p=>{
   const perm=own(d.children,String(p.id));return perm?.household===actor.household?[publicPlayer(p,perm)]:[];
  }):[];
  return {role:actor.role,csrf:actor.csrf,players,pendingInvites:inv,globalChat:actor.role==='owner'?chatPolicy():{enabled:chatPolicy().enabled}};
 }
 function action(kind,actor,q){
  switch(kind){
  case 'global-chat': {
   roleOnly(actor,'owner');
   if(!on(q,['enabled'])||typeof q.enabled!=='boolean')refuse('Choose whether family chat is on or off.');
   if(q.enabled&&!chatEnabledAtLaunch)refuse('Family chat is disabled by this preview launcher.',409);
   if(q.enabled!==globalFamilyChatAllowed(accounts.state)){
    commit(s=>{s.familyChatPolicy={version:1,enabled:q.enabled};});
    onGlobalChatChanged();
   }
   return {globalChat:chatPolicy()};
  }
  case 'invite-parent':
   roleOnly(actor,'owner');if(!on(q,['username']))refuse('Invalid parent invite request.');
   return commit((s,d)=>{
    const username=goodName(q.username);
    if(!username||adult(d,username)||own(s.profiles,username)||Object.values(d.invites).some(i=>i.purpose==='parent'&&i.username===username&&i.expiresAt>clock()))refuse('That parent name is unavailable.',409);
    if(Object.keys(d.parents).length>=limits.parents)refuse('Parent limit reached.',409);
    return createInvite(d,actor,'parent',{username,household:id()});
   });
  case 'invite-player':
   roleOnly(actor,'parent');if(!on(q,[]))refuse('Invalid player invite request.');
   return commit((s,d)=>createInvite(d,actor,'player',{household:actor.household}));
  case 'revoke-invite':
   if(!actor)refuse('Sign in to the desk first.',401);
   if(!on(q,['inviteId'])||!idPattern.test(q.inviteId??''))refuse('Invite not found.',404);
   return commit((s,d)=>{
    const row=Object.entries(d.invites).find(([,v])=>v.id===q.inviteId&&v.issuer===actor.username&&v.expiresAt>clock());
    if(!row)refuse('Invite not found.',404);
    delete d.invites[row[0]];return {};
   });
  case 'redeem-parent':
   if(!on(q,['code','password'])||!goodPassword(q.password))refuse('Use a password of at least 10 characters.');
   return commit((s,d)=>{
    const i=take(d,q.code,'parent');
    if(d.owner?.username!==i.issuer||adult(d,i.username)||own(s.profiles,i.username)||Object.keys(d.parents).length>=limits.parents)refuse('Parent invite cannot be used.',409);
    put(d.parents,i.username,{...adultCredential(i.username,q.password),household:i.household});return {username:i.username};
   });
  case 'redeem-player':
   if(!on(q,['code','nickname','avatar','password']))refuse('Invalid player setup.');
   return commit((s,d)=>{
    const i=take(d,q.code,'player');
    if(own(d.parents,i.issuer)?.household!==i.household)refuse('Invite is no longer available.',404);
    return {player:createChild(s,d,i.household,q.nickname,q.avatar,q.password)};
   });
  case 'create-player':
   roleOnly(actor,'parent');if(!on(q,['nickname','avatar','password']))refuse('Invalid player setup.');
   return commit((s,d)=>({player:createChild(s,d,actor.household,q.nickname,q.avatar,q.password)}));
  case 'player-permissions': {
   if(!(on(q,['id','playEnabled'])&&typeof q.playEnabled==='boolean')&&!(on(q,['id','chatEnabled'])&&typeof q.chatEnabled==='boolean'))refuse('Change one play or chat permission at a time.');
   const reply=commit((s,d)=>{
    const [p,perm]=childScoped(s,d,actor,q.id);if(Object.hasOwn(q,'playEnabled'))p.disabled=!q.playEnabled;if(Object.hasOwn(q,'chatEnabled'))perm.chatEnabled=q.chatEnabled;
    if(p.disabled)revokeChildSessions(s,p);
    return {player:publicPlayer(p,perm)};
   });
   onPlayerChanged(q.id);return reply;
  }
  case 'reset-player': {
   if(!on(q,['id']))refuse('Player not found.',404);
   const reply=commit((s,d)=>{
    const [p]=childScoped(s,d,actor,q.id);
    for(const [k,v] of Object.entries(d.invites))if(v.purpose==='reset'&&v.playerId===p.id)delete d.invites[k];
    // Random, unissued credential immediately invalidates the old password.
    p.salt=randomBytes(16).toString('hex');p.hash=randomBytes(64).toString('hex');p.mustChangePassword=true;
    revokeChildSessions(s,p);
    return createInvite(d,actor,'reset',{household:actor.household,playerId:p.id});
   });
   onPlayerChanged(q.id);return reply;
  }
  case 'redeem-reset': {
   if(!on(q,['code','password'])||!goodPassword(q.password))refuse('Use a password of at least 10 characters.');
   const reply=commit((s,d)=>{
    const i=take(d,q.code,'reset'),p=profile(s,i.playerId);
    if(!p||own(d.children,String(i.playerId))?.household!==i.household||own(d.parents,i.issuer)?.household!==i.household)refuse('Invite is no longer available.',404);
    setPlayerPassword(p,q.password);revokeChildSessions(s,p);
    return {nickname:p.username,playerId:p.id};
   });
   onPlayerChanged(reply.playerId);return {nickname:reply.nickname};
  }
  default:refuse('Not found.',404);
  }
 }
 return {bootstrapOwner,canChat,login,authenticate,status,action,logout:secret=>{if(typeof secret==='string'&&keyPattern.test(secret))sessions.delete(sha(secret));}};
}
