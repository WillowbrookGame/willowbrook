
export function createPreviewJobs({store,businessDefinitions,employerFor,jobTaskRules,starterRules}){
 const {workTaskDefinitions,parcelStation,deliveryStop,atJobTask}=jobTaskRules;
 const {starterQuests,starterEligible}=starterRules;
 const publicTowns=new Set(['town',...Object.keys(businessDefinitions)]);
 const settings={moveMaxAge:1800};
 function position(peer,now){
  if(!publicTowns.has(peer.zone)||!peer.updated||now-peer.updated>settings.moveMaxAge||!peer.grounded||Math.abs(peer.y)>=2)return null;
  const b=businessDefinitions[peer.zone];
  return {x:peer.x+(b?.x??0),z:peer.z+(b?.z??0),interiorBusiness:b?peer.zone:null,interiorHome:null,carId:null};
 }
 function marker(task,job,kind,label=task.label,pending=false){
  const b=businessDefinitions[task.interiorBusiness];
  return {job,kind,label,zone:task.interiorBusiness??'town',x:task.x-(b?.x??0),z:task.z-(b?.z??0),radius:task.radius,pending};
 }
 function active(p){
  if(p.starter.run){
   const run=p.starter.run, job=run.quest,task=starterQuests[job]?.steps[run.step];
   if(task)return {kind:'starter',job,run,task};
  }
  if(p.work.taskRun){
   const job=p.work.name,run=p.work.taskRun,task=workTaskDefinitions[job]?.tasks[run.step];
   if(task)return {kind:'work',job,run,task};
  }
  if(p.job.stage==='pickup'||p.job.stage==='deliver')return {kind:'delivery',job:'delivery',run:p.job,task:p.job.stage==='pickup'?parcelStation:deliveryStop(p.job.destination)};
  return null;
 }
 function available(p){
  const list=[];
  for(const [job,q] of Object.entries(starterQuests))if(job!=='garden')list.push({kind:'starter',job,task:q.steps[0]});
  for(const job of [...Object.keys(workTaskDefinitions),'delivery']){
   if(p.jobMembership.includes(job)){
    list.push({kind:'start',job,task:job==='delivery'?parcelStation:workTaskDefinitions[job]?.station});
   }else{
    const employer=employerFor(job);
    if(employer)list.push({kind:'hire',job,task:employer,label:'Talk to '+employer.label});
   }
  }
  return list.filter(a=>a.task);
 }
 function snapshot(p,now=Date.now()){
  const record=active(p);
  return {
   memberships:[...p.jobMembership],
   completed:Object.keys(starterQuests).filter(id=>Number.isFinite(p.starter.completed[id])),
   starterWaitMs:Object.fromEntries(Object.entries(starterQuests).map(([id,quest])=>{
    // Garden uses its server-owned quick action; other starters use their most recent paid reward.
    const rewardedAt=id==='garden'?p.gardenLastTendedAt:p.activityAt?.[id];
    return [id,Number.isFinite(rewardedAt)?Math.min(quest.cooldownMs,Math.max(0,Math.ceil(rewardedAt+quest.cooldownMs-now))):0];
   })),
   eligible:starterEligible(p.starter),
   current:record?marker(record.task,record.job,record.kind,record.kind==='delivery'&&p.job.stage==='deliver'?'Deliver the parcel':record.task.label,!!record.run.pending):null,
   available:record?[]:available(p).map(o=>marker(o.task,o.job,o.kind,o.label)),
   employers:['park','nursery','singing'].flatMap(job=>{
    const task=employerFor(job);
    return task?[marker(task,job,'hire','Talk to '+task.label)]:[];
   }),
   status:record?(record.kind==='delivery'&&p.job.stage==='deliver'?'Deliver to '+record.task.label:record.run.pending?'Helping…':record.task.label):'',
  };
 }
 function apply(peer,m,now){
  if(!['interact','hire','cancel'].includes(m.operation)||Object.keys(m).some(k=>!['type','action','operation','job'].includes(k))||(m.job!==undefined&&typeof m.job!=='string'))return {error:'Choose a valid job action.'};
  const p=peer.profile,pAt=position(peer,now),record=active(p),before=p.stars;
  let error,text;
  if(m.operation==='cancel'){
   if(!record)return {error:'There is no active activity to cancel.'};
   if(record.kind==='starter')error=store.starterTask(p,{action:'cancel',assignmentId:record.run.id},pAt,now);
   else if(record.kind==='work')error=store.work(p,record.job,'cancel',pAt,now);
   else error=store.job(p,'cancel',pAt,now);
   text='Activity canceled.';
  }else if(!pAt)return {error:'Stand at the activity or employer and try again.'};
  else if(m.operation==='hire'){
   if(!m.job)return {error:'Choose a workplace first.'};
   error=store.work(p,m.job,'hire',pAt,now);
   text='You got the job! Visit the work supplies to start.';
  }else if(record){
   if((m.job!==undefined&&m.job!==record.job)||!atJobTask(pAt,record.task))return {error:'Visit the current activity marker first.'};
   if(record.kind==='delivery'){
    const action=p.job.stage==='pickup'?'pickup':'deliver';
    error=store.job(p,action,pAt,now,{assignmentId:record.run.id});
    text=action==='pickup'?'Deliver to '+deliveryStop(p.job.destination).label+'.':'Parcel delivered! +'+(p.stars-before)+' saved stars.';
   }else{
    const op=record.kind==='starter'?store.starterTask:store.workTask;
    error=op(p,{action:'begin',assignmentId:record.run.id,task:record.task.id},pAt,now);
    text='Helping… stay close until the task finishes.';
   }
  }else{
   const options=available(p).filter(o=>(m.job===undefined||m.job===o.job)&&atJobTask(pAt,o.task));
   const dist=o=>Math.hypot(pAt.x-o.task.x,pAt.z-o.task.z);
   options.sort((a,b)=>dist(a)-dist(b)||(a.kind==='start'?-1:1));
   const offer=options[0];
   if(!offer)return {error:'There is no job activity here. Look for a marked employer or the work supplies.'};
   const {kind,job,task}=offer;
   if(kind==='hire'){
    error=store.work(p,job,'hire',pAt,now);
    text='You got the job! Visit the work supplies to start.';
   }else if(kind==='starter'){
    error=store.starterTask(p,{action:'start',quest:job},pAt,now);
    if(!error)error=store.starterTask(p,{action:'begin',assignmentId:p.starter.run.id,quest:job,task:task.id},pAt,now);
    text='Helping… stay close until the task finishes.';
   }else{
    error=job==='delivery'?store.job(p,'start',pAt,now):store.work(p,job,'start',pAt,now);
    text=job==='delivery'?'Delivery started. Pick up your parcel.':'Shift started. Follow the gold task marker.';
   }
  }
  return error?{error}:{text};
 }
 function tick(peer,now){
  const p=peer.profile,rec=active(p);
  if(!rec||!rec.run.pending||!peer.updated)return null;
  const pAt=position(peer,now);
  if(!pAt)return null;
  if(!atJobTask(pAt,rec.task)){
   rec.run.pending=null;
   store.save();
   return {text:'Step paused. Return to the marker and try again.'};
  }
  if(now-rec.run.pending.beganAt<rec.task.durationMs)return null;
  const before=p.stars,canHireBefore=starterEligible(p.starter);
  const op=rec.kind==='starter'?store.starterTask:store.workTask;
  const error=op(p,{action:'finish',assignmentId:rec.run.id,task:rec.task.id},pAt,now);
  if(error)return {error};
  const next=active(p), earned=p.stars-before;
  let text=next?'Step complete! Next: '+next.task.label+'.':rec.kind==='starter'?'Activity complete! Its star reward is resting.':'Shift done!';
  if(earned>0)text=(rec.kind==='starter'?'Activity complete! ':'Shift done! ')+'+'+earned+' saved stars.';
  if(!canHireBefore&&starterEligible(p.starter))text+=' You can now get hired!';
  return {text};
 }
 function creditGarden(profile){
  if(!Number.isFinite(profile.gardenLastTendedAt)||Number.isFinite(profile.starter.completed.garden))return;
  profile.starter.completed.garden=profile.gardenLastTendedAt;
  store.save();
 }
 return {snapshot,apply,tick,creditGarden};
}

