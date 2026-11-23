import {spawn} from 'node:child_process';
import {isAbsolute,join} from 'node:path';
import {performance} from 'node:perf_hooks';

const size=2048, prefix='WBPA1:', maxPending=64, maxLine=65536, RPC_MS=1200, OPEN_MS=5000, HEALTH_MS=1800;
export function startPaintballWorker({exe,project,now=()=>performance.now(),spawnWorker=spawn,onLost=()=>{}}){
 if(typeof exe!=='string'||!isAbsolute(exe)||typeof project!=='string'||!isAbsolute(project))throw Error('Configured local worker paths must be absolute.');
 const script='res://paintball_prototype/network/paintball/match_worker.gd';
 const child=spawnWorker(exe,['--headless','--path',project,'--max-fps','60','--script',script],{
  cwd:project,windowsHide:true,shell:false,stdio:['pipe','pipe','ignore']
 });
 let healthy=false,dead=false,last=0,nextId=0,tail='',heartbeat,starting,killTimer,openingUntil=0;
 const pending=new Map();
 function fail(){
  if(dead)return;
  dead=true;healthy=false;
  clearInterval(heartbeat);clearTimeout(starting);
  for(const row of pending.values()){clearTimeout(row.timer);row.resolve(null);}
  pending.clear();
  child.stdin.end();
  killTimer=setTimeout(()=>{if(child.exitCode==null)child.kill();},650);killTimer.unref();
  try{onLost();}catch{}
 }
 function freshness(){return now()<=(openingUntil||last+HEALTH_MS);}
 function call(op,payload={}){
  if(!healthy||dead||!freshness()||pending.size>=maxPending||child.stdin.writableLength>size*16){
   if(healthy&&(!freshness()||child.stdin.writableLength>size*16))fail();
   return Promise.resolve(null);
  }
  if(openingUntil)return Promise.resolve(null);
  const id=++nextId;
  const packed=Buffer.from(JSON.stringify({id,op,...payload}),'utf8');
  if(packed.length>size)return Promise.resolve(null);
  const frame=Buffer.alloc(size,32);
  packed.copy(frame);
  return new Promise(resolve=>{
   const open=op==='open';
   if(open)openingUntil=now()+OPEN_MS;
   const timer=setTimeout(fail,open?OPEN_MS:RPC_MS);timer.unref();
   pending.set(id,{resolve,timer,open});
   try{child.stdin.write(frame,e=>{if(e)fail();});}catch{fail();}
  });
 }
 function handle(line){
  if(!line.startsWith(prefix))return;
  let msg;
  try{msg=JSON.parse(line.slice(prefix.length));}catch{return fail();}
  if(msg?.kind==='hello'&&!healthy&&msg.version===1&&msg.maxRooms===3){
   healthy=true;last=now();clearTimeout(starting);
   heartbeat=setInterval(()=>{if(!openingUntil)void call('ping');},450);heartbeat.unref();
   return;
  }
  if(!healthy||msg?.kind!=='reply'||!Number.isSafeInteger(msg.id)||typeof msg.result?.ok!=='boolean')return fail();
  const row=pending.get(msg.id);
  if(!row)return fail();
  last=now();
  if(row.open)openingUntil=0;
  clearTimeout(row.timer);
  pending.delete(msg.id);
  row.resolve(msg.result);
 }
 child.stdout.setEncoding('utf8');
 child.stdout.on('data',chunk=>{
  if(dead)return;
  tail+=chunk;
  if(tail.length>maxLine)return fail();
  let cut;
  while((cut=tail.indexOf('\n'))>=0){
   const line=tail.slice(0,cut).replace(/\r$/,'');
   tail=tail.slice(cut+1);
   handle(line);
   if(dead)return;
  }
 });
 child.stdout.on('error',fail);child.stdin.on('error',fail);
 child.on('error',fail);child.on('exit',()=>{fail();clearTimeout(killTimer);});
 starting=setTimeout(fail,8000);starting.unref();
 return {healthy:()=>healthy&&!dead&&freshness(),call,close:fail};
}
