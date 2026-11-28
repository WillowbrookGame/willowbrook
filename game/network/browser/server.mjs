import {privateHttpsSite,requestMatchesSite} from './https_site_policy.mjs';
import {createHideSeekPrototype} from './hide_seek_prototype.mjs';
import {createPreviewYards} from './yard_progress_preview.mjs';
import {createHomeVisits} from './home_visits_preview.mjs';
import {createPreviewFurniture} from './furniture_progress_preview.mjs';
import {createPreviewNeighborQuests} from './neighbor_quest_preview.mjs';
import {createPreviewClasses} from './class_progress_preview.mjs';
import {createPreviewFishing} from './fishing_progress_preview.mjs';
import {createPreviewReefPhotos} from './reef_photos_preview.mjs';
import {createPreviewPets} from './pet_progress_preview.mjs';
import {createServer} from 'node:http';
import {randomBytes,timingSafeEqual} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {resolve,join,extname,sep} from 'node:path';
import {realpath,stat,readFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHoopsScores} from './hoops_scores_preview.mjs';
import {createVehicleWorld} from './vehicle_world_preview.mjs';
import {createPreviewVehicles} from './vehicle_purchase_preview.mjs';
import {openPreviewAccounts,validatePreviewDirectory} from './preview_accounts.mjs';
import {createPreviewJobs} from './job_progress_preview.mjs';
import {createPreviewHunt} from './scavenger_preview.mjs';
import {createFamilyChat} from './family_chat_preview.mjs';
import {requireDeskOptIn,claimDeskWriter,createFamilyDesk,canManagedPlayerChat,globalFamilyChatAllowed} from './family_desk_preview.mjs';
import {createDeskHttp} from './family_desk_http.mjs';
import {selectRuntime,sourceArgument,projectRoot,pathsOverlap} from './runtime_source.mjs';

// Original Willowbrook v0.51 Town clock/weather schedule (UTC milliseconds).
export function environmentAt(now=Date.now()){
 return {phase:((now%1200000)+1200000)%1200000/1200000,weather:['sunny','cloudy','rain'][((Math.floor(now/300000)%3)+3)%3]};
}
import {startPaintballWorker} from './paintball_worker_preview.mjs';
import {createPrivatePaintballMatches} from './paintball_matches_preview.mjs';
import {createPaintballLobbies} from './paintball_lobby_preview.mjs';
import {createPaintballRewards} from './paintball_rewards_preview.mjs';
import {createPlayground} from './playground_preview.mjs';
const publicZones=new Set(['town','beach','arcade','bank','vet','salon','store','cafe','library','reef','skyhill']);
const place=z=>({town:'In town',beach:'At the beach',arcade:'At the arcade',reef:'At the reef',skyhill:'At Skyhill Park',private:'In another activity'})[z]||'Indoors';
const send=(ws,m)=>{if(ws.readyState===1&&ws.bufferedAmount<32768)ws.send(JSON.stringify(m));};
function sameCode(a,b){return typeof a==='string'&&/^[0-9a-f]{12}$/i.test(a)&&timingSafeEqual(Buffer.from(a.toUpperCase()),Buffer.from(b));}
function cleanAlias(value){return (typeof value==='string'?value.slice(0,32).replace(/[^a-z0-9 _-]/gi,'').trim().slice(0,18):'')||'Player';}
function cleanPose(m){
 if(typeof m.zone!=='string'||!publicZones.has(m.zone)&&m.zone!=='private')return null;
 if(m.zone==='private')return {zone:'private',x:0,y:0,z:0,yaw:0,grounded:true,moving:false,rest:'',glide:null};
 const skyhill=m.zone==='skyhill';
 if(![m.x,m.y,m.z,m.yaw].every(Number.isFinite)||Math.abs(m.x)>240||Math.abs(m.z)>240||m.y<(skyhill?-4:m.zone==='reef'?-22:-10)||m.y>(skyhill?42:25)||Math.abs(m.yaw)>Math.PI*2)return null;
 // Match the Godot Skyhill presence contract; never forward its fields in other zones.
 const glide=skyhill&&Array.isArray(m.glide)&&m.glide.length===2&&m.glide.every(Number.isFinite)&&Math.abs(m.glide[0])<=.7&&Math.abs(m.glide[1])<=1.6?m.glide:null;
 const maySit=skyhill?!glide&&m.grounded===true&&Math.abs(m.x)<=6.25&&m.y>=23&&m.y<=24.2&&m.z>=10.5&&m.z<=21.5:Math.abs(m.y)<1.5&&['bank','vet','salon','store','cafe','library'].includes(m.zone);
 return {zone:m.zone,x:m.x,y:m.y,z:m.z,yaw:m.yaw,moving:m.moving===true,grounded:m.grounded===true,rest:m.rest==='sit'&&m.moving!==true&&maySit?'sit':'',glide};
}

export async function startLocalServer({source,port=24862,origins=[],webRoot=null,accountsDir=null,seedAccounts=[],chatEnabled=false,enableWeather=false,enableHomeVisits=false,enableHideSeek=false,enablePaintballLobbyTransport=false,paintballWorker=null,parentDeskFile=null,deskClock=Date.now,privateHttpsOrigin=null,log=()=>{}}){
 const httpsSite=privateHttpsSite(privateHttpsOrigin);
 if(httpsSite&&(!accountsDir||!webRoot||origins.length))throw Error('Private HTTPS requires distinct accounts and Web directories, without the preview Origin override.');
 let releaseDeskWriter=()=>{};
 try{
 const runtime=await selectRuntime(source);
 const {WebSocketServer}=runtime.webSockets();
 const {load}=runtime;
 const [{createUpstreamHockey},{createHoopsService},{arcadeCabinet,arcadeExterior}]=await Promise.all([load('upstream-hockey-service.mjs'),load('hoops-service.mjs'),load('public/arcade-cabinets.js')]);
 const invite=randomBytes(6).toString('hex').toUpperCase(), peers=new Map();
 let next=0;
 const site=webRoot?await realpath(webRoot):null;
 if(site&&(!(await stat(site)).isDirectory()||pathsOverlap(site,runtime.root)))throw new Error('Web root must be a separate static export directory.');
 if(chatEnabled===true&&!accountsDir)throw Error('Family chat requires preapproved preview accounts.');
 if(accountsDir&&port===24862)throw Error('Use a separate port for the account preview, e.g. 24863.');
 const dataPaths={accountsDir,source:runtime.root,projectRoot,site};
 if(parentDeskFile!==null){if(port===24864)throw Error('Family Desk cannot bind the active game port.');await validatePreviewDirectory(dataPaths);requireDeskOptIn(parentDeskFile,accountsDir);releaseDeskWriter=claimDeskWriter(accountsDir);}
 const worldStore=accountsDir?await load('world-store.mjs'):null;
 const accounts=accountsDir?await openPreviewAccounts({...dataPaths,makeStore:worldStore.makeStore,seeds:seedAccounts,allowEmpty:parentDeskFile!==null,parentDeskEnabled:parentDeskFile!==null}):null;
 const character=p=>worldStore?.characters.includes(p.character)?p.character:'male-a';
 const desk=parentDeskFile!==null?createFamilyDesk({accounts,accountFile:accounts.accountFile,makeStore:worldStore.makeStore,characters:worldStore.characters,clock:deskClock,chatEnabledAtLaunch:chatEnabled===true,onGlobalChatChanged:()=>chat.refresh(),onPlayerChanged:id=>closeOrRefreshPlayer(id)}):null;
 const httpDesk=createDeskHttp({desk,address:()=>server.address(),clock:deskClock,httpsSite});
 let jobs=null,hunt=null,neighborQuests=null;
 if(accounts){
  const [{businessDefinitions},{employerFor},jobTaskRules,starterRules]=await Promise.all([load('public/business-interiors.js'),load('public/employers.js'),load('public/job-tasks.js'),load('public/starter-quests.js')]);
  neighborQuests=createPreviewNeighborQuests({store:accounts,businessDefinitions,questDefinitions:worldStore.questDefinitions,workReward:worldStore.workReward});
  jobs=createPreviewJobs({store:accounts,businessDefinitions,employerFor,jobTaskRules,starterRules});
  const [{scavengerHunt},spots]=await Promise.all([load('public/scavenger-hunt.js'),readFile(new URL('../../scavenger/spots.json',import.meta.url),'utf8').then(data=>JSON.parse(data.replace(/^\uFEFF/,'')))]);
  hunt=createPreviewHunt({store:accounts,catalog:scavengerHunt,spots});
 }
 const pets=accounts?createPreviewPets(accounts):null;
 const furniture=accounts?createPreviewFurniture({store:accounts,housingRules:await load('public/housing.js'),catalogRules:await load('public/furniture-catalog.js')}):null;
 const fishing=accounts?createPreviewFishing(accounts):null;
 const reefPhotos=accounts?createPreviewReefPhotos(accounts):null;
 const vehicles=accounts?createPreviewVehicles(accounts):null;
 const vehicleRules=accounts?await load('public/car-economy.js'):null;
 const vehicleWorld=accounts?createVehicleWorld(accounts,()=>[...peers.values()].filter(admitted),p=>!!playground.own(p),vehicleRules.validCarSpot):null;
 const classes=accounts?createPreviewClasses(accounts,worldStore):null;
 const yards=accounts?createPreviewYards({store:accounts,rules:await load('public/yard-upgrades.js')}):null;
 const progress=(p,serverTime=Date.now())=>({vehicleOffer:vehicles.snapshot(p.profile),neighborQuests:neighborQuests.snapshot(p.profile,serverTime),classes:classes.snapshot(p.profile),fishing:fishing.snapshot(p),reefPhotos:reefPhotos.snapshot(p.profile),...pets.snapshot(p.profile),furniture:furniture.snapshot(p.profile),yard:yards.snapshot(p.profile),stars:p.profile.stars,gardenLastTendedAt:p.profile.gardenLastTendedAt,serverTime,jobs:jobs.snapshot(p.profile,serverTime),scavenger:hunt.snapshot(p.profile),scavengerLeaderboard:hunt.leaderboard()});
 function jobReply(p,operation,result,now){
  send(p.ws,{type:'progress',action:'jobs',operation,ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
 }
 let failedAuth=[];

 const MIME={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.ico':'image/x-icon','.json':'application/json','.jpg':'image/jpeg','.webp':'image/webp','.ogg':'audio/ogg','.mp3':'audio/mpeg','.wav':'audio/wav','.woff2':'font/woff2'};
 const server=createServer(async(req,res)=>{
  if(httpsSite&&!requestMatchesSite(req,httpsSite)){
   res.writeHead(403,{'cache-control':'no-store'});res.end();return;
  }
  if(await httpDesk(req,res))return;
  const fail=()=>{res.writeHead(404);res.end();};
  if(!['GET','HEAD'].includes(req.method)){fail();return;}
  if(req.url==='/health'){res.writeHead(200,{'content-type':'application/json'});res.end('{"ok":true,"scope":"loopback"}');return;}
  if(!site){fail();return;}
  try{
   const path=decodeURIComponent(req.url.split('?')[0]);
   if(!path.startsWith('/')||path.includes('\\')||path.split('/').some(p=>p.startsWith('.'))){fail();return;}
   const filename=await realpath(join(site,path==='/'?'index.html':path.slice(1)));
   if(!filename.startsWith(site+sep)){fail();return;}
   const info=await stat(filename);
   if(!info.isFile()){fail();return;}
   res.writeHead(200,{'content-type':MIME[extname(filename).toLowerCase()]||'application/octet-stream','content-length':info.size,'x-content-type-options':'nosniff','cache-control':'no-store'});
   if(req.method==='HEAD'){res.end();return;}
   createReadStream(filename).on('error',()=>res.destroy()).pipe(res);
  }catch{if(!res.headersSent)fail();else res.destroy();}
 });
 server.once('close',releaseDeskWriter);
 const wss=new WebSocketServer({noServer:true,maxPayload:2048,perMessageDeflate:false});
 const admitted=p=>!!p?.profile&&peers.has(p.ws)&&(!accounts||(!p.profile.disabled&&!p.profile.mustChangePassword&&accounts.auth({type:'resume',session:p.session}).profile===p.profile));
 const hideAreas=enableHideSeek===true&&accounts?
   JSON.parse(await readFile(new URL('./hide_seek_geometry.json',import.meta.url),'utf8')):null;
 const nearHideDoor=(pose,at,range)=>at&&Math.hypot(pose.x-at.x,pose.z-at.z)<=range;
 const hideSeek=hideAreas?createHideSeekPrototype({areas:hideAreas,admitted,resolveScene:(p,t)=>{
   if(!Object.hasOwn(hideAreas,p.zone)||p.hideSeekInvalidDoor===true||playground.own(p))return false;
   return {id:p.zone,pose:p};
 }}):null;
 function trackHideDoor(p,to,t){
   if(!hideSeek||p.zone===to.zone)return;
   p.hideSeekInvalidDoor=false;
   if(!hideSeek.enrolled(p))return;
   const from=hideAreas[p.zone],nextArea=hideAreas[to.zone];
   if(!from||!nextArea)return; // out-of-scope travel withdraws on the next match tick
   const fresh=t-p.updated<=12_000;
   const legal=p.zone==='town'&&nearHideDoor(p,nextArea.door,4.25)&&nearHideDoor(to,nextArea.spawn,4.25)||
      to.zone==='town'&&nearHideDoor(p,from.exit,3.75)&&nearHideDoor(to,from.return,4.25);
   if(!fresh||!legal)p.hideSeekInvalidDoor=true;
 }

 const playground=createPlayground({admitted});
 const paintballRewards=accounts?createPaintballRewards(accounts):null;
 const homeVisits=accounts&&enableHomeVisits===true?createHomeVisits({store:accounts,admitted,send:(p,m)=>send(p.ws,m),furnitureCatalog:(await load('public/furniture-catalog.js')).furnitureCatalog,character}):null;
 // Explicit local-only opt-in. An absent or unhealthy worker keeps the arena on its solo route.
 let worker=null,matches=null;
 if(accounts&&enablePaintballLobbyTransport===true&&paintballWorker){
  try{
   worker=startPaintballWorker({...paintballWorker,onLost:()=>matches?.unavailable()});
   matches=createPrivatePaintballMatches({worker,admitted,character,rewards:paintballRewards,onStarsUpdated:p=>send(p.ws,{type:'progress',action:'paintball',operation:'onlineReward',ok:true,...progress(p)}),send:(p,m)=>send(p.ws,m),hideFromWorld:p=>{
    homeVisits?.release(p);playground.release(p);clearArcade(p);clearVehicle(p);fishing?.close(p);
    Object.assign(p,{zone:'private',x:0,y:0,z:0,yaw:0,moving:false,grounded:true,rest:'',interiorBusiness:null});
    chat.update(p);
   }});
  }catch{worker?.close();worker=null;matches=null;}
 }
 const paintball=enablePaintballLobbyTransport===true&&accounts?createPaintballLobbies({
  admitted,send:(p,m)=>send(p.ws,m),authority:matches,
  nearDoor:(p,now)=>p.zone==='town'&&p.grounded&&!p.rest&&!p.vehicleSeat&&!playground.own(p)&&Math.abs(p.y)<1&&p.updated>0&&now-p.updated<=2000&&Math.hypot(p.x-36,p.z+46)<=2.35
 }):null;
 const chat=createFamilyChat({enabled:chatEnabled===true&&!!accounts,policy:()=>globalFamilyChatAllowed(accounts?.state),authorized:p=>!!accounts&&admitted(p)&&canManagedPlayerChat(accounts.state,p.profile),send:(p,m)=>send(p.ws,m),peers:()=>peers.values()});
 const hoops=createHoopsService();
 const hoopsScores=createHoopsScores(accounts);
 const hockey=createUpstreamHockey({isAuthorized:admitted,send:(p,m)=>send(p.ws,m)});
 const clearArcade=p=>{hockey.leave(p);hoops.leave(p);hoopsScores.leave(p);};
 const clearVehicle=p=>{if(p.vehicleSeat)vehicleWorld?.release(p,true);};
 function closeOrRefreshPlayer(id){for(const p of peers.values())if(p.profile?.id===id){if(!admitted(p)){clearArcade(p);clearVehicle(p);fishing?.close(p);homeVisits?.release(p);paintball?.disconnect(p,Date.now(),{revoke:true});matches?.disconnect(p,Date.now(),{revoke:true});p.profile=null;p.session=null;p.ws.close(1008,'Play session ended');}else chat.update(p);}}
 function world(){
  const all=[...peers.values()].filter(admitted),now=Date.now();
  homeVisits?.trim(now);
  const fishPopulation=fishing&&all.some(p=>p.zone==='beach')?fishing.population(now):null;
  const baselinePresence=all.map(p=>({alias:p.profile.username,place:place(p.zone)}));
  hideSeek?.tick();
  const environment=enableWeather===true&&accounts?environmentAt(now):null;
  const homeExteriors=accounts?accounts.state.homes
   .filter(h=>Number.isInteger(h.id)&&h.id>=0&&h.id<6&&h.owner!=null&&['cottage','family'].includes(h.variant))
   .map(h=>({plot:h.id,variant:h.variant})):null;
  const townRides=all.some(p=>p.zone==='town')?playground.active(now):null;
  for(const q of all){
   if(hideSeek&&q.ws.readyState===1&&q.ws.bufferedAmount<32768){
    if(q.hideSeekOpenInvite&&q.hideSeekOpenInvite!==hideSeek.openInviteId()){
     send(q.ws,{type:'hideSeekInviteClosed',id:q.hideSeekOpenInvite});
     q.hideSeekOpenInvite=null;
    }
    const invite=hideSeek.invitationFor(q);
    if(invite){q.hideSeekOpenInvite=invite.id;send(q.ws,invite);}
   }
   const presence=hideSeek?.enrolled(q)?baselinePresence.map((p,i)=>({...p,place:hideSeek.presencePlace(q,all[i],p.place)})):baselinePresence;
   const players=q.zone==='private'?[]:all.filter(p=>p!==q&&p.zone===q.zone&&(!hideSeek||hideSeek.visible(q,p))).map(p=>({id:p.profile.id,alias:p.profile.username,...(accounts?{character:character(p.profile),companionSpecies:pets.companion(p.profile)}:{}),...(fishing&&p.zone==='beach'?{fishingEquipped:fishing.visual(p).equipped,fishingCast:fishing.visual(p).cast}:{}),zone:p.zone,x:p.x,y:p.y,z:p.z,yaw:p.yaw,moving:p.moving,grounded:p.grounded,...(p.zone==='town'&&p.vehicleSeat?{vehicleSeat:p.vehicleSeat}:{}),rest:p.rest??'',...(p.zone==='skyhill'&&p.glide?{glide:p.glide}:{})}));
   const homeScene=homeVisits&&q.zone==='private'?homeVisits.snapshot(q,now):null;
   send(q.ws,{type:'world',zone:q.zone,presence,players,...(hideSeek?{hideSeek:hideSeek.view(q)}:{}),...(homeScene?{homeScene}:{}),...(homeExteriors&&q.zone==='town'?{homeExteriors}:{}),...(townRides&&q.zone==='town'?{playground:{active:townRides,self:playground.own(q)}}:{}),...(fishPopulation&&q.zone==='beach'?{serverTime:now,fishPopulation,fishingVisual:fishing.visual(q)}:{}),...(yards&&q.zone==='town'?{yards:yards.town()}:{}),chatEnabled:chat.available(q),...(environment&&q.zone==='town'?{environment}:{}),...(vehicleWorld&&q.zone==='town'?{vehicles:vehicleWorld.view(q)}:{})});
  }
 }
 server.on('upgrade',(req,socket,head)=>{
  const origin=req.headers.origin;
  const local=['http://127.0.0.1:'+server.address().port,'http://localhost:'+server.address().port];
  const permitted=httpsSite?requestMatchesSite(req,httpsSite,true):(accounts?local.includes(origin):(!origin||[...origins,...(site?local:[])].includes(origin)));
  if(req.url!=='/play'||!permitted||peers.size>=16){socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');socket.destroy();return;}
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws));
 });
 function handleArcade(p,m,now){
  const {type,action}=m;
  if(p.zone!=='arcade'){
   send(p.ws,{type:type==='airHockey'?'airHockeyError':type,error:'Visit the arcade first'});
   return;
  }
  if(type==='airHockey'){
   let error;
   if(action!=='leave'&&hoops.has(p))error='Finish basketball first';
   else{const roomZ=p.z;try{p.z+=arcadeExterior.z;error=hockey.handle(p,m,now);}finally{p.z=roomZ;}}
   if(error)send(p.ws,{type:'airHockeyError',error});
   return;
  }
  const reply=(extra={})=>send(p.ws,{type,action,serverTime:now,best:hoopsScores.best(p),rows:hoopsScores.rows(),...extra});
  if(action==='leave'){hoops.leave(p);hoopsScores.leave(p);reply({run:null});return;}
  if(action==='leaderboard'){reply();return;}
  if(hockey.side(p)>=0){reply({error:'Leave air hockey first'});return;}
  if(action==='start'){
   const c=arcadeCabinet('basketball');if(Math.hypot(p.x-c.talkX,p.z+arcadeExterior.z-c.talkZ)>c.radius){reply({error:'Walk closer to the basketball cabinet'});return;}
   reply(hoops.start(p,m.requestId,now));return;
  }
  if(action==='input'){const error=hoops.input(p,m,now);if(error)reply({error});return;}
  if(action==='finish'){
   const result=hoops.finish(p,m,now);
   if(!result.error){
    try{hoopsScores.record(p,result.run);}catch{reply({error:'Could not save this score. Your previous best has not been replaced.'});return;}
   }
   reply(result);return;
  }
  reply({error:'Unsupported basketball action'});
 }
 wss.on('connection',ws=>{
  const p={ws,profile:null,zone:'private',x:0,y:0,z:0,yaw:0,moving:false,grounded:true,seen:Date.now(),updated:0,window:Date.now(),messages:0,alive:true,interiorBusiness:null,interiorHome:null,carId:null};peers.set(ws,p);
  ws.on('error',()=>{});
  ws.on('pong',()=>p.alive=true);
  ws.on('close',()=>{homeVisits?.release(p);playground.release(p);clearArcade(p);clearVehicle(p);fishing?.close(p);paintball?.disconnect(p,Date.now());matches?.disconnect(p,Date.now());peers.delete(ws);world();});
  ws.on('message',data=>{
   const now=Date.now();
   if(now-p.window>=1000){p.window=now;p.messages=0;}
   if(++p.messages>90){ws.close(1008,'Too many messages');return;}
   let m;try{m=JSON.parse(data.toString());}catch{return;}
   if(!m||typeof m!=='object'||Array.isArray(m))return;
   if(!admitted(p)){
    if(accounts){
     const deny=error=>{send(ws,{type:'denied',error});ws.close(1008,'Sign-in required');};
     if(!['login','resume'].includes(m.type)){deny('Sign in to play online.');return;}
     failedAuth=failedAuth.filter(t=>now-t<60000);
     if(failedAuth.length>=20){deny('Too many sign-in attempts. Try again in a minute.');return;}
     let result;
     try{result=accounts.auth(m);}catch{deny('The local account store is temporarily unavailable.');return;}
     if(result.error||result.profile.disabled||result.profile.mustChangePassword){
      failedAuth.push(now);
      deny(m.type==='resume'?'Please sign in again.':'Username or password is incorrect.');
      return;
     }
     // One visible avatar per account. A stale tab must not stay visible after a reload.
     for(const previous of peers.values())if(previous!==p&&previous.profile?.id===result.profile.id){
      clearArcade(previous);clearVehicle(previous);fishing?.close(previous);homeVisits?.release(previous);paintball?.disconnect(previous,now,{revoke:m.type==='login'});matches?.disconnect(previous,now,{revoke:m.type==='login'}); previous.profile=null;
      send(previous.ws,{type:'denied',error:'This account joined from another window.'});
      previous.ws.close(1008,'Session replaced');
     }
     try{hunt.reconcile(result.profile);}catch{} // Keep prior earned reward pending if storage temporarily fails.
     try{jobs.creditGarden(result.profile);}
     catch{deny('The local account store could not recover your progress.');return;}
     p.profile=result.profile;p.session=result.session;vehicleWorld.sync(p);p.chatAvailable=chat.available(p);
     send(ws,{type:'welcome',id:p.profile.id,alias:p.profile.username,character:character(p.profile),session:p.session,progress:progress(p,now),chatEnabled:p.chatAvailable,...(hideSeek?{hideSeekEnabled:true}:{}),...(homeVisits?{homeVisits:true}:{})});
     if(m.type==='resume'){paintball?.resume(p,now);void matches?.resume(p,now);}
     else{paintball?.forgetAccount(p.profile.id);matches?.forgetAccount(p.profile.id);}
     world();
     return;
    }
    if(m.type!=='join')return;
    if(!sameCode(m.code,invite)){send(ws,{type:'denied',error:'Invite code did not match.'});ws.close(1008,'Invite denied');return;}
    const names=new Set([...peers.values()].filter(admitted).map(q=>q.profile.username.toLowerCase()));
    const base=cleanAlias(m.alias);let alias=base,i=2;
    while(names.has(alias.toLowerCase()))alias=base.slice(0,15)+' '+i++;
    p.profile={id:++next,username:alias};
    send(ws,{type:'welcome',id:p.profile.id,alias,chatEnabled:false});world();return;
   }
   if(accounts&&m.type==='logout'){
    try{accounts.logout(p.session);}catch{send(ws,{type:'denied',error:'The local account store could not save the sign-out.'});}
    clearArcade(p);clearVehicle(p);fishing?.close(p);homeVisits?.release(p);paintball?.disconnect(p,now,{revoke:true});matches?.disconnect(p,now,{revoke:true});p.profile=null;p.session=null;ws.close(1000,'Signed out');world();return;
   }
   if(matches?.active(p)&&!['paintballLobby','paintballMatch','chat','hideSeek'].includes(m.type))return;
   if(m.type==='hideSeek'&&hideSeek){
    const action=['join','start','tag','leave','state','accept','decline'].includes(m.action)?m.action:'invalid';
    const result=action==='state'&&Object.keys(m).length===2?{ok:true}:hideSeek.handle(p,m);
    if(action==='start'&&result.ok)p.moving=false;
    const inviteReply=['accept','decline'].includes(action)&&typeof m.inviteId==='string'&&/^[a-f0-9]{16}$/.test(m.inviteId);
    if(inviteReply&&result.ok)p.hideSeekOpenInvite=null;
    send(ws,{type:'hideSeek',action,...(inviteReply?{inviteId:m.inviteId}:{}),...result,state:hideSeek.view(p)});
    if(result.ok&&action!=='state')world();
    return;
   }
   if(m.type==='chat'){if(accounts)chat.handle(p,m,now);return;}
   if(hideSeek?.frozen(p))return; // Preserve the authoritative countdown pose and block other interactions.
   if(m.type==='homeVisit'&&homeVisits){
    const r=homeVisits.request(p,m,now,{busy:!!playground.own(p)});
    if(r.silent)return;
    send(ws,{type:'homeVisit',action:['enter','leave','lock'].includes(m.action)?m.action:'invalid',ok:!r.error,...r});
    if(!r.error)world();
    return;
   }
   if(homeVisits?.guest(p)&&['progress','vehicleInput','vehicleAction','paintballLobby','paintballMatch'].includes(m.type)){
    send(ws,{type:'homeVisit',action:'readOnly',text:'Only the homeowner can make changes here.'});
    return;
   }
   if(m.type==='paintballLobby'){void paintball?.handle(p,m,now);return;}
   if(m.type==='paintballMatch'){void matches?.handle(p,m,now);return;}
   if(vehicleWorld&&m.type==='vehicleInput'){vehicleWorld.input(p,m,now);return;}
   if(vehicleWorld&&m.type==='vehicleAction'){
    const result=vehicleWorld.call(p,m,now);
    send(ws,{type:'vehicleEvent',ok:!result.error,text:result.error??result.text,...(result.exit?{exit:result.exit}:{})});
    world();return;
   }
   if(accounts&&m.type==='progress'){
    if(p.vehicleSeat){send(ws,{type:'progress',action:'tendGarden',ok:false,error:'Get out of the vehicle first.',...progress(p,now)});return;}
    if(m.action==='yard'){
     let result;try{result=yards.apply(p,m,now);}catch{result={error:'The local account store could not save the yard improvement.'};}
     send(ws,{type:'progress',action:'yard',operation:'buy',...(typeof m.requestId==='string'?{requestId:m.requestId.slice(0,64)}:{}),ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     return;
    }
    if(m.action==='neighborQuest'){
     let r;try{r=neighborQuests.apply({...p,playground:playground.own(p)},m,now);}catch{r={error:'Neighbor quests are temporarily unavailable.'};}
     const requestId=typeof m.requestId==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId)?m.requestId:null;
     send(ws,{type:'progress',action:'neighborQuest',operation:['start','step','cancel'].includes(m.operation)?m.operation:'invalid',requestId,ok:!r.error,text:r.error??r.text,...progress(p,now),...(r.error?{error:r.error}:{earned:r.earned,replay:r.replay})});
     return;
    }
    if(m.action==='furniture'){
     let result;
     try{result=furniture.apply(p,m,now);}
     catch{result={error:'The local account store could not save the furniture update.'};}
     if(result.silent)return;
     send(ws,{type:'progress',action:'furniture',operation:typeof m.operation==='string'?m.operation.slice(0,48):'unknown',
      ...(typeof m.requestId==='string'?{requestId:m.requestId.slice(0,64)}:{}),
      ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     return;
    }
    if(m.action==='vehicles'){
     const result=!vehicleWorld.canPurchase(p)?{error:'Everyone must leave the car before purchasing.'}:m.operation==='buy'&&!p.profile.ownedCar&&!vehicleWorld.parkingAvailable()?{error:'No parking places are available.'}:vehicles.apply(p,m,now);
     if(!result.error)vehicleWorld.sync(p);
     const requestId=typeof m.requestId==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId)?m.requestId:null;
     const operation=['buy','upgrade'].includes(m.operation)?m.operation:'unknown';
     send(ws,{type:'progress',action:'vehicles',operation,requestId,ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     return;
    }
    if(m.action==='classes'){
     const result=classes.apply(p,m,now);
     const requestId=typeof m.requestId==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId)?m.requestId:null;
     send(ws,{type:'progress',action:'classes',operation:'pay',requestId,ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     return;
    }
    if(m.action==='fishing'){
     let result;try{result=fishing.apply(p,m,now);}catch{result={ok:false,text:'Fishing progress is unavailable.'};}
     const {ok,text,...payload}=result;
     send(ws,{type:'progress',action:'fishing',operation:typeof m.operation==='string'?m.operation.slice(0,48):'unknown',
      ...(typeof m.requestId==='string'?{requestId:m.requestId.slice(0,64)}:{}),
      ok,text,...progress(p,now),...payload,...(!ok?{error:text}:{})});
     return;
    }
    if(m.action==='reefPhotos'){
     let result;try{result=reefPhotos.apply(p,m);}catch{result={ok:false,text:'Reef photos are unavailable.'};}
     const {ok,text,...payload}=result;
     send(ws,{type:'progress',action:'reefPhotos',operation:typeof m.operation==='string'?m.operation.slice(0,48):'unknown',
      ...(typeof m.requestId==='string'?{requestId:m.requestId.slice(0,64)}:{}),
      ok,text,...progress(p,now),...payload,...(!ok?{error:text}:{})});
     return;
    }
    if(m.action==='pets'||m.action==='housing'){
     let result;try{result=pets.apply(p,m,now);}catch{result={error:'Could not save that update.'};}
     const operation=typeof m.operation==='string'?m.operation.slice(0,48):'unknown';
     const requestId=m.action==='housing'&&['repay','upgrade'].includes(operation)&&typeof m.requestId==='string'&&/^[A-Za-z0-9_-]{8,64}$/.test(m.requestId)?m.requestId:null;
     send(ws,{type:'progress',action:m.action,operation,...(requestId?{requestId}:{}),ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     return;
    }
    if(m.action==='scavenger'){
     let result;
     try{result=hunt.apply(p,m,now);}
     catch{result={error:'The local account store could not save this hunt update.'};}
     send(ws,{type:'progress',action:'scavenger',operation:m.operation,ok:!result.error,text:result.error??result.text,...progress(p,now),...(result.error?{error:result.error}:{})});
     if(result.completed){
      const rows=hunt.leaderboard();
      for(const q of peers.values())if(admitted(q))send(q.ws,{type:'scavengerLeaderboard',rows});
     }
     return;
    }
    if(m.action==='jobs'){
     let result;
     try{result=jobs.apply(p,m,now);}
     catch{result={error:'The local account store could not save that update.'};}
     jobReply(p,m.operation,result,now);
     return;
    }
    const action='tendGarden';
    let error;
    if(m.action!==action||Object.keys(m).some(k=>!['type','action'].includes(k)))error='Choose a supported account activity.';
    else if(p.zone!=='town'||!p.grounded||Math.abs(p.y)>1)error='Walk to the community garden in town first.';
    else{
     try{error=accounts.tendGarden(p.profile,p,now);if(!error)jobs.creditGarden(p.profile);}
     catch{error='The local account store could not save that update.';}
    }
    send(ws,{type:'progress',action,ok:!error,...progress(p,now),...(error?{error}:{})});
    return;
   }
   if(m.type==='playground'){
    const result=p.vehicleSeat&&m.action==='board'?{error:'Get off the vehicle before using playground equipment.'}:playground.handle(p,m,now);
    send(ws,{type:'playground',ok:!result.error,...(result.error?{error:result.error}:{})});
    if(!result.error)world();
    return;
   }
   if(m.type==='move'){
    if(p.vehicleSeat)return;
    if(now-p.updated<30&&p.zone===m.zone)return;
    const pose=cleanPose(m);if(!pose)return;
    if(p.zone==='arcade'&&pose.zone!=='arcade')clearArcade(p);
    trackHideDoor(p,pose,now);
    homeVisits?.moved(p,pose,now);
    playground.moved(p,pose);
    paintball?.moved(p,pose);
    if(pets)pets.moved(p,pose,now);
    if(fishing)fishing.moved(p,pose);
    Object.assign(p,pose,{updated:now,interiorBusiness:pose.zone==='arcade'?'arcade':null});if(accounts)chat.update(p);return;
   }
   if(m.type==='airHockey'||m.type==='hoops88')handleArcade(p,m,now);
  });
 });
 const snapshots=setInterval(()=>{
  paintball?.tick(Date.now());matches?.tick(Date.now());
  if(paintball){
   const available=matches?.ready()===true;
   for(const p of peers.values())if(admitted(p)&&p.paintballAvailable!==available){
    p.paintballAvailable=available;
    send(p.ws,{type:'paintballCapability',available});
   }
  }
  if(jobs){
   const now=Date.now();
   for(const p of peers.values())if(admitted(p)){
    fishing?.update(p,now);
    let result;
    try{result=jobs.tick(p,now);}
    catch{result={error:'The local account store could not save that job step.'};}
    if(result)jobReply(p,'finish',result,now);
   }
  }
  world();
 },90);
 const vehicleTick=vehicleWorld?setInterval(()=>vehicleWorld.tick(Date.now(),0.05),50):null;
 const heartbeat=setInterval(()=>{for(const p of peers.values()){if(!p.alive||!admitted(p)&&Date.now()-p.seen>7000){p.ws.terminate();continue;}p.alive=false;p.ws.ping();}},4000);
 await new Promise((ok,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',ok);}).catch(e=>{clearInterval(snapshots);clearInterval(heartbeat);clearInterval(vehicleTick);hockey.close();worker?.close();wss.close();throw e;});
 const address=server.address();
 log(accounts?{mode:'accounts',url:'ws://127.0.0.1:'+address.port+'/play'}:{invite,url:'ws://127.0.0.1:'+address.port+'/play',origins});
 return {invite,address,disableFamilyChat:()=>chat.disable(),close:async()=>{clearInterval(snapshots);clearInterval(heartbeat);clearInterval(vehicleTick);hockey.close();worker?.close();for(const p of peers.values()){clearVehicle(p);p.ws.terminate();}wss.close();await new Promise(resolve=>server.close(resolve));}};
 }catch(e){releaseDeskWriter();throw e;}
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const option=key=>process.argv.flatMap((item,i)=>item===key?[process.argv[i+1]]:[]);
 const source=sourceArgument(process.argv.slice(2));
 const httpsOrigins=option('--private-https-origin');
 if(httpsOrigins.length>1||httpsOrigins.length===1&&!httpsOrigins[0])throw Error('Pass at most one explicit private HTTPS origin.');
 const port=Number(option('--port')[0]??24862);
 if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('Port must be 1024â€“65535.');
 const accountsDir=option('--accounts-dir')[0]??null;
 let seedAccounts=[];
 if(accountsDir&&process.env.WILLOWBROOK_PREVIEW_ACCOUNTS){
  try{seedAccounts=JSON.parse(process.env.WILLOWBROOK_PREVIEW_ACCOUNTS);}
  catch{throw Error('WILLOWBROOK_PREVIEW_ACCOUNTS must be a JSON array of disposable accounts.');}
  finally{delete process.env.WILLOWBROOK_PREVIEW_ACCOUNTS;}
 }
 const enablePaintballLobbyTransport=process.argv.includes('--enable-paintball-lobby');
 const exe=option('--paintball-worker-exe')[0],project=option('--paintball-worker-project')[0];
 const paintballWorker=enablePaintballLobbyTransport&&exe&&project?{exe,project}:null;
 const local=await startLocalServer({source,port,enablePaintballLobbyTransport,paintballWorker,privateHttpsOrigin:httpsOrigins[0]??null,origins:option('--origin'),webRoot:option('--web-root')[0],accountsDir,seedAccounts,chatEnabled:process.argv.includes('--enable-family-chat'),enableWeather:process.argv.includes('--enable-town-weather'),enableHomeVisits:process.argv.includes('--enable-home-visits'),parentDeskFile:option('--parent-desk-file')[0]??null,log:data=>console.log(JSON.stringify(data))});
 process.on('SIGINT',async()=>{await local.close();process.exit();});
}
