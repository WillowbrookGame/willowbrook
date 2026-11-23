import assert from 'node:assert/strict';
import {mkdtemp,readFile,writeFile,unlink} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createPreviewClasses} from './class_progress_preview.mjs';
import {startLocalServer} from './server.mjs';

const source=resolve(process.argv[2]);
const world=await import(pathToFileURL(join(source,'world-store.mjs')).href);
const dir=await mkdtemp(join(tmpdir(),'willowbrook-classes-unit-')),file=join(dir,'class-profile.json');
let store=Object.assign(world.makeStore(file),{accountFile:file});
const qa={username:'qa_school_kid',password:'disposable unit test password'};
const p=store.auth({type:'register',...qa}).profile;
p.stars=800;
store.save();
const classes=createPreviewClasses(store,world);
const now=2_000_000,at={profile:p,zone:'library',x:0,y:0,z:1.2,updated:now,grounded:true};
const packet=(amount,requestId,course='delivery')=>({type:'progress',action:'classes',operation:'pay',course,amount,tier:p.classes[course].tier,paid:p.classes[course].paid,requestId});
const ok=(m)=>assert.ok(!classes.apply(at,m,now).error);
assert.equal(Object.keys(classes.snapshot(p)).length,10);
assert.equal(p.hasJob,false);
assert.match(classes.apply({...at,zone:'town'},packet(1,'outside-lib'),now).error,/librarian/);
assert.match(classes.apply({...at,updated:1},packet(1,'stale-pose'),now).error,/librarian/);
assert.match(classes.apply({...at,z:-2},packet(1,'wrong-side'),now).error,/librarian/);
assert.match(classes.apply(at,packet(51,'overpay-001'),now).error,/remaining/);
assert.equal(p.stars,800);
const first=packet(20,'tuition-a1');
ok(first);
ok(first);
assert.equal(p.stars,780);
assert.deepEqual(classes.snapshot(p).delivery,{tier:0,paid:20,reward:3});
assert.match(classes.apply(at,{...first,amount:21},now).error,/already used/);
assert.match(classes.apply(at,{...first,requestId:'stale-version'},now).error,/changed/);
ok(packet(30,'tuition-a2'));
assert.deepEqual(classes.snapshot(p).delivery,{tier:1,paid:0,reward:5});
ok(packet(120,'tuition-a3'));
assert.deepEqual(classes.snapshot(p).delivery,{tier:2,paid:0,reward:8});
ok(packet(200,'tuition-a4'));
assert.deepEqual(classes.snapshot(p).delivery,{tier:3,paid:0,reward:10});
assert.equal(p.stars,430);
assert.equal(classes.snapshot(p).bank.reward,3);
assert.equal(p.hasJob,false);
const saved=await readFile(file);
const normal=store.save;
// Simulate failure before replacing the save, using no live or real data.
store.save=()=>{throw Error('Synthetic disk error');};
// world-store's actual private save closure isn't replaced by replacing its exposed method, so
// test the exception via an injected transaction adapter rather than making OS-global changes.
const failStore={...store,takeClass:(q,m)=>{q.stars-=1;q.classes.bank.paid+=1;q.classReceipts.push({...m});throw Error('Synthetic precommit failure');}};
const failed=createPreviewClasses(failStore,world);
assert.match(failed.apply(at,packet(1,'failed-001','bank'),now).error,/not changed/);
assert.equal(p.stars,430);
assert.equal(p.classes.bank.paid,0);
assert.deepEqual(await readFile(file),saved);
store.save=normal;
const reloaded=world.makeStore(file);
const restored=reloaded.auth({type:'login',...qa}).profile;
assert.equal(restored.stars,430);
assert.deepEqual(restored.classes.delivery,{tier:3,paid:0});
restored.jobMembership.push('delivery');
const job=await import(pathToFileURL(join(source,'public/job-tasks.js')).href);
const px=where=>({x:where.x,z:where.z,interiorBusiness:where.interiorBusiness});
assert.equal(reloaded.job(restored,'start',px(job.parcelStation),now+100),null);
assert.equal(reloaded.job(restored,'pickup',px(job.parcelStation),now+200,{assignmentId:restored.job.id}),null);
assert.equal(reloaded.job(restored,'deliver',px(job.deliveryStop(restored.job.destination)),now+20000,{assignmentId:restored.job.id}),null);
assert.equal(restored.stars,440);
console.log('PASS: eligibility, locality, partial tuition, stale/duplicate guards, 3 reward tiers, save failure, restart and +10 saved delivery payout');

// Test the actual browser adapter's message envelope and live balance on a
// fresh throwaway directory, with no Family Desk active.
const accountsDir=await mkdtemp(join(tmpdir(),'willowbrook-classes-ws-'));
const local=await startLocalServer({source,port:0,accountsDir,seedAccounts:[qa]});
const {WebSocket}=createRequire(pathToFileURL(join(source,'package.json')))('ws');
const ws=new WebSocket('ws://127.0.0.1:'+local.address.port+'/play',{origin:'http://127.0.0.1:'+local.address.port});
let pending=null,queue=[];
ws.on('message',data=>{const m=JSON.parse(data);if(pending)pending(m);else queue.push(m);});
const recv=pred=>new Promise((resolve,reject)=>{
 const old=queue.findIndex(pred);if(old>=0){resolve(queue.splice(old,1)[0]);return;}
 const timeout=setTimeout(()=>{pending=null;reject(Error('Timed out waiting for the fixture server'));},3500);
 pending=m=>{if(pred(m)){clearTimeout(timeout);pending=null;resolve(m);}};
});
const send=m=>ws.send(JSON.stringify(m));
try{
 await new Promise((yes,no)=>{ws.once('open',yes);ws.once('error',no);});
 send({type:'login',...qa});
 const hello=await recv(m=>m.type==='welcome');
 assert.equal(hello.progress.classes.park.reward,3);
 send({type:'move',zone:'town',x:20,y:0,z:49,yaw:0,grounded:true,moving:false});
 send({type:'progress',action:'tendGarden'});
 assert.equal((await recv(m=>m.type==='progress'&&m.action==='tendGarden')).stars,2);
 send({type:'move',zone:'library',x:0,y:0,z:1.2,yaw:0,grounded:true,moving:false});
 send({type:'progress',action:'classes',operation:'pay',course:'park',amount:1,tier:0,paid:0,requestId:'socket-paid-01'});
 const reply=await recv(m=>m.type==='progress'&&m.action==='classes');
 assert.ok(reply.ok,reply.error);
 assert.equal(reply.requestId,'socket-paid-01');
 assert.equal(reply.stars,1);
 assert.deepEqual(reply.classes.park,{tier:0,paid:1,reward:3});
 console.log('PASS: disposable browser WebSocket sends class state with welcome, earns saved stars, pays and acknowledges exact receipt ID');
}finally{
 ws.terminate();
 await local.close();
}

