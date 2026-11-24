
import assert from 'node:assert/strict';
import {mkdtemp} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createPreviewJobs} from './job_progress_preview.mjs';
const source=resolve(process.argv[2]);
const load=name=>import(pathToFileURL(join(source,name)).href);
const [{businessDefinitions},{employerFor},jobTaskRules,starterRules,{makeStore,workReward}]=await Promise.all([
 load('public/business-interiors.js'),load('public/employers.js'),load('public/job-tasks.js'),load('public/starter-quests.js'),load('world-store.mjs')]);
const dir=await mkdtemp(join(tmpdir(),'willowbrook-jobs-test-'));
const file=join(dir,'disposable-jobs.json');
const a={type:'register',username:'local_jobs_qa',password:'disposable jobs qa password'};
let store=makeStore(file);
const first=store.auth(a), second=store.auth({...a,username:'separate_qa'});
let jobs=createPreviewJobs({store,businessDefinitions,employerFor,jobTaskRules,starterRules});
let now=2_000_000;
const p={profile:first.profile,zone:'town',x:0,y:0,z:0,grounded:true,updated:now};
const action=(operation,job,extra={})=>jobs.apply(p,{type:'progress',action:'jobs',operation,...(job?{job}:{}),...extra},now);
function move(marker){
 Object.assign(p,{zone:marker.zone,x:marker.x,z:marker.z,updated:now,grounded:true});
}
function jump(ms){
 now+=ms;
 p.updated=now;
}
function point(target){
 const zone=target.interiorBusiness??'town', b=businessDefinitions[zone];
 return {zone,x:target.x-(b?.x??0),z:target.z-(b?.z??0)};
}
const state=()=>jobs.snapshot(p.profile,now);
const expectOK=result=>assert.ok(!result?.error,result?.error);
const offer=(kind,job)=>state().available.find(q=>q.kind===kind&&q.job===job);
assert.match(action('hire','park').error,/employer/i);
move(offer('hire','park'));
assert.match(action('hire','park').error,/starter activities/i);
assert.equal(p.profile.stars,0);
assert.equal(store.tendGarden(p.profile,{x:20,z:49},now),null);
jobs.creditGarden(p.profile);
assert.deepEqual(state().completed,['garden']);
assert.equal(state().starterWaitMs.garden,300000);
assert.match(store.tendGarden(p.profile,{x:20,z:49},now+1),/resting|wait|recent|need time/i);
assert.equal(jobs.snapshot(p.profile,now+298000).starterWaitMs.garden,2000);
assert.equal(jobs.snapshot(p.profile,now+300000).starterWaitMs.garden,0);
assert.deepEqual(jobs.snapshot(second.profile,now).starterWaitMs,{cafe:0,store:0,park:0,garden:0});
for(const name of ['cafe','store','park']){
 const q=starterRules.starterQuests[name];
 const start=offer('starter',name);assert.ok(start);
 assert.deepEqual([start.zone,start.x,start.z],Object.values(point(q.steps[0])));
 move(start);
 expectOK(action('interact',name));
 assert.ok(state().current.pending);
 assert.match(action('finish',name,{stars:999}).error,/valid job/i);
 assert.equal(jobs.tick(p,now),null);
 if(name==='cafe'){
  const other={...start,zone:'town',x:0,z:0};
  move(other);assert.match(jobs.tick(p,now).text,/paused/);
  jump(5000);move(start);expectOK(action('interact',name));
 }
 jump(q.steps[0].durationMs);expectOK(jobs.tick(p,now));
 const next=state().current;move(next);expectOK(action('interact',name));
 jump(q.steps[1].durationMs);expectOK(jobs.tick(p,now));
 assert.equal(state().starterWaitMs[name],60000);
 assert.equal(jobs.snapshot(p.profile,now+59456).starterWaitMs[name],544);
 assert.equal(jobs.snapshot(p.profile,now+60000).starterWaitMs[name],0);
 assert.equal(state().current,null);
}
assert.equal(p.profile.stars,5);
assert.equal(state().eligible,true);
let deterministic=0;
for(const name of [...Object.keys(jobTaskRules.workTaskDefinitions),'delivery']){
 const hire=offer('hire',name);assert.ok(hire,name);
 move(hire);expectOK(action('hire',name));
 assert.ok(state().memberships.includes(name));
 const station=offer('start',name);assert.ok(station,name);
 move(station);expectOK(action('interact',name));
 const steps=jobTaskRules.workTaskDefinitions[name]?.tasks??[null,null];
 for(const task of steps){
  const current=state().current;
  assert.ok(current,name+' expected a current task');
  move(current);
  if(task)assert.deepEqual([current.zone,current.x,current.z],Object.values(point(task)));
  expectOK(action('interact',name));
  if(task){jump(task.durationMs);expectOK(jobs.tick(p,now));}
 }
 deterministic+=workReward(name,p.profile.classes);
 assert.equal(p.profile.stars,5+deterministic);
 assert.equal(state().current,null);
}
assert.equal(second.profile.stars,0);
const afterPaid=p.profile.stars;
move(offer('starter','park'));expectOK(action('interact','park'));
const priorTask=state().current;
store=makeStore(file);
jobs=createPreviewJobs({store,businessDefinitions,employerFor,jobTaskRules,starterRules});
p.profile=store.auth({type:'resume',session:first.session}).profile;
assert.equal(p.profile.stars,afterPaid);
assert.deepEqual(state().current,priorTask);
move(priorTask);
jump(2000);expectOK(jobs.tick(p,now));
assert.equal(state().current.pending,false);
expectOK(action('cancel'));
assert.equal(state().current,null);
assert.equal(p.profile.stars,afterPaid);
console.log('PASS job rules: 4 starters/eligibility, every live employer, every timed paid route and delivery, account isolation, and reload of a pending task.');

