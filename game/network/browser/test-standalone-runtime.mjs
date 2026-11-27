import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {once} from 'node:events';
import {mkdir,mkdtemp,readFile,readdir,rm,writeFile,copyFile,access,symlink,realpath} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {setTimeout as wait} from 'node:timers/promises';
import {standaloneRoot,selectRuntime,sourceArgument} from './runtime_source.mjs';
import {startLocalServer} from './server.mjs';

const here=dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(await readFile(join(here,'standalone-runtime-manifest.json'),'utf8'));
async function members(root,prefix=''){
 const files=[];
 for(const entry of await readdir(join(root,prefix),{withFileTypes:true})){
  const name=prefix+entry.name;
  if(entry.isDirectory())files.push(...await members(root,name+'/'));
  else{assert.ok(entry.isFile(),'No links or special files in standalone runtime');files.push(name);}
 }
 return files;
}
assert.deepEqual((await members(standaloneRoot)).sort(),Object.keys(manifest.files).sort());
for(const [file,{bytes,sha256}] of Object.entries(manifest.files)){
 const data=await readFile(join(standaloneRoot,file));
 assert.equal(data.length,bytes,file);
 assert.equal(createHash('sha256').update(data).digest('hex'),sha256,file);
}
const fsPermissions=dir=>['--permission','--allow-fs-read='+dir,'--allow-fs-write='+dir];
if(process.argv[2]!=='--relocated-fixture'){
 const temp=await realpath(await mkdtemp(join(tmpdir(),'willowbrook-standalone-test-')));
 try{
  const source=resolve(here,'../../..');
  const project=join(temp,'relocated-project'),relBrowser='game/network/browser';
  // Copy only audited current server modules + DB-independent catalogs. No checkout, installs, exports, or data.
  const code=['server.mjs','runtime_source.mjs','parent_desk_setup.mjs','test-standalone-runtime.mjs','standalone-runtime-manifest.json','hide_seek_geometry.json'];
  const imports=/^import\s.*?\sfrom '\.\/([^']+)'/gm;
  for(let i=0;i<code.length;i++){
   if(!code[i].endsWith('.mjs'))continue;
   const data=await readFile(join(here,code[i]),'utf8');
   for(const match of data.matchAll(imports))if(!code.includes(match[1]))code.push(match[1]);
  }
  const files=[
   ...code.map(file=>relBrowser+'/'+file),
   ...Object.keys(manifest.files).map(file=>relBrowser+'/standalone-runtime/'+file),
   'game/scavenger/spots.json','game/vehicles/side_driveways.json'
  ];
  for(const file of files){
   const target=join(project,file);
   await mkdir(dirname(target),{recursive:true});
   await copyFile(join(source,file),target);
  }
  const linked=await symlink(project,join(temp,'project-alias'),process.platform==='win32'?'junction':'dir').then(()=>true,error=>{if(error.code==='EPERM'||error.code==='EACCES')return false;throw error;});
  const runFromFixture={cwd:temp,env:{...process.env,HOME:temp,USERPROFILE:temp,NODE_PATH:'',NODE_OPTIONS:''}};
  const deskData=join(temp,'willowbrook-family-desk-closure'), marker=join(deskData,'.willowbrook-family-desk-opt-in');
  await mkdir(deskData);
  await writeFile(marker,'willowbrook-local-family-desk-v1\n');
  execFileSync(process.execPath,[join(project,relBrowser,'parent_desk_setup.mjs'),'--accounts-dir',deskData,'--parent-desk-file',marker,'--owner','closure_owner'],{...runFromFixture,input:'Disposable desk setup password\n',stdio:['pipe','pipe','pipe'],timeout:10000});
  await assert.rejects(access(join(deskData,'.willowbrook-family-desk-writer')),e=>e.code==='ENOENT');
  execFileSync(process.execPath,[...fsPermissions(temp),join(project,relBrowser,'test-standalone-runtime.mjs'),'--relocated-fixture',temp,linked?'junction':'no-junction'],{
   ...runFromFixture,stdio:'inherit',timeout:45000
  });
 }finally{await rm(temp,{recursive:true,force:true});}
}else{
 const temp=process.argv[3], project=resolve(here,'../../..'), site=join(temp,'static'), data=join(temp,'isolated-test-accounts');
 assert.equal(process.permission.has('fs.read',dirname(temp)),false);
 assert.equal(process.permission.has('fs.write',dirname(temp)),false);
 const deskData=join(temp,'willowbrook-family-desk-closure');
 const uncreated=join(project,'unsafe-account-location'), alias=join(temp,'project-alias');
 const seeds=[{username:'closure_alpha',password:'disposable closure alpha'},{username:'closure_beta',password:'disposable closure beta'}];
 const {WebSocket}= (await selectRuntime()).webSockets();
 const clients=[];
 let server;
 async function connect(seed,origin=base()){
  const ws=new WebSocket(base().replace('http:','ws:')+'/play',{origin});
  ws.on('error',()=>{});
  clients.push(ws);
  const messages=[];
  ws.on('message',raw=>{messages.push(JSON.parse(raw));if(messages.length>100)messages.shift();});
  await once(ws,'open');
  const send=message=>ws.send(JSON.stringify(message));
  const take=async check=>{
   const deadline=Date.now()+4000;
   while(Date.now()<deadline){
    const i=messages.findIndex(check);
    if(i>=0)return messages.splice(i,1)[0];
    await wait(8);
   }
   throw Error('Expected standalone WS message: '+check.toString());
  };
  send({type:'login',...seed});
  return {send,take,welcome:await take(m=>m.type==='welcome')};
 }
 const base=()=> 'http://127.0.0.1:'+server.address.port;
 const move=(zone,x,z)=>({type:'move',zone,x,y:0,z,yaw:0,moving:false,grounded:true});
 const close=async()=>{for(const ws of clients.splice(0))ws.terminate();await server?.close();server=null;};

 assert.equal(sourceArgument(['--port','24863']),undefined);
 assert.throws(()=>sourceArgument(['--source','--port']),/explicit/);
 assert.throws(()=>sourceArgument(['--source','a','--source','b']),/explicit/);
 await assert.rejects(selectRuntime(join(temp,'missing-explicit-source')),e=>e.code==='ENOENT');
 await assert.rejects(startLocalServer({port:0,accountsDir:uncreated}),/outside/);
 await assert.rejects(access(uncreated),e=>e.code==='ENOENT');
 if(process.argv[4]==='junction'){
  await assert.rejects(startLocalServer({port:0,accountsDir:join(alias,'unsafe-account-location')}),/outside/);
  await assert.rejects(access(uncreated),e=>e.code==='ENOENT');
 }else console.log('SKIP junction fixture: host disallows creating temporary links.');
 await assert.rejects(startLocalServer({port:0,webRoot:standaloneRoot}),/separate static/);
 await mkdir(site);
 await writeFile(join(site,'index.html'),'<title>Standalone static sentinel</title>');
 const desk=JSON.parse(await readFile(join(deskData,'preview-accounts-v1.json'),'utf8'));
 assert.equal(desk.familyDesk.owner.username,'closure_owner');
 assert.equal(Object.keys(desk.profiles).length,0);
 try{
  server=await startLocalServer({port:0,accountsDir:data,webRoot:site,seedAccounts:seeds,enableWeather:true,enableHideSeek:true,enableHomeVisits:true});
  assert.equal(server.address.address,'127.0.0.1');
  assert.equal((await fetch(base()+'/health')).status,200);
  assert.match(await (await fetch(base()+'/')).text(), /standalone static sentinel/i);
  for(const file of ['world-store.mjs','standalone-runtime-manifest.json','standalone-runtime/vendor/ws/index.js','preview-accounts-v1.json'])assert.equal((await fetch(base()+'/'+file)).status,404);
  await assert.rejects(connect(seeds[0],'https://wrong-origin.invalid'),/403/);
  const a=await connect(seeds[0]),b=await connect(seeds[1]);
  assert.ok(a.welcome.id&&a.welcome.progress.classes&&a.welcome.progress.jobs&&a.welcome.progress.fishing);
  // Reef poses use the same route as the exported game, including vertical movement and isolation.
  const reefPose=(y,x)=>({...move('reef',x,12),y,grounded:false,moving:true});
  a.send(reefPose(-17.4,3)); b.send(reefPose(-16,1));
  const aReef=await a.take(m=>m.type==='world'&&m.zone==='reef'&&m.players.some(p=>p.id===b.welcome.id&&p.y===-16));
  const bReef=await b.take(m=>m.type==='world'&&m.zone==='reef'&&m.players.some(p=>p.id===a.welcome.id&&p.y===-17.4));
  assert.ok(aReef.players.some(p=>p.moving&&!p.grounded));
  assert.ok(bReef.presence.some(p=>p.alias===seeds[0].username&&p.place==='At the reef'));
  b.send(move('beach',0,12));
  await b.take(m=>m.type==='world'&&m.zone==='beach'&&!m.players.length);
  await a.take(m=>m.type==='world'&&m.zone==='reef'&&!m.players.length&&m.presence.some(p=>p.alias===seeds[1].username&&p.place==='At the beach'));
  b.send(move('town',0,12));
  await b.take(m=>m.type==='world'&&m.zone==='town'&&!m.players.length);
  b.send({...move('town',1,12),y:-15});
  b.send(reefPose(-16,5));
  await a.take(m=>m.type==='world'&&m.zone==='reef'&&m.players.some(p=>p.id===b.welcome.id&&p.x===5));
  console.log('PASS two browser protocol peers: deep Reef poses, roster, Beach/Town isolation, and re-entry');
  a.send(move('town',20,49));
  a.send({type:'progress',action:'tendGarden'});
  assert.equal((await a.take(m=>m.type==='progress'&&m.ok)).stars,2);
  a.send(move('arcade',0,2.3));b.send(move('arcade',0,2.3));
  await a.take(m=>m.type==='world'&&m.zone==='arcade');
  await b.take(m=>m.type==='world'&&m.zone==='arcade');
  a.send({type:'airHockey',action:'join'});b.send({type:'airHockey',action:'join'});
  await a.take(m=>m.type==='airHockeyFrame'&&m.frame?.encoding==='text');
  await b.take(m=>m.type==='airHockeyFrame'&&m.frame?.encoding==='text');
  a.send({type:'airHockey',action:'leave'});
  await a.take(m=>m.type==='airHockeyFrame'&&m.frame===null);
  a.send(move('arcade',-6,-3.65));
  a.send({type:'hoops88',action:'start',requestId:'fixture-round-one'});
  assert.ok((await a.take(m=>m.type==='hoops88'&&m.action==='start')).run?.id);
  await close();
  server=await startLocalServer({port:0,accountsDir:data,webRoot:site});
  const a2=await connect(seeds[0]);
  assert.equal(a2.welcome.progress.stars,2);
  const state=JSON.parse(await readFile(join(data,'preview-accounts-v1.json'),'utf8'));
  assert.equal(String(state.profiles.closure_alpha.id),String(a.welcome.id));
  assert.equal(state.profiles.closure_alpha.stars,2);
  assert.equal(state.profiles.closure_beta.stars,0);
  console.log('PASS filesystem-isolated relocated standalone closure, manifest, denied source/export overlap, Desk provisioning, HTTP, origin guard, two real hockey peers, HOOPS authority, persistent profile id and progress.');
 }finally{await close();}
}
