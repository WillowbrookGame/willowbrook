import {randomBytes} from 'node:crypto';
import {HOOPS_HZ,HOOPS_TICKS,HOOPS_ACTIONS,replayHoops} from './public/hoops-simulation.js';
// One bounded ephemeral run per connection; completed records are persisted by the caller.
export function createHoopsService(){
 const runs=new Map();
 function start(owner,requestId,now=Date.now()){
  if(typeof requestId!=='string'||!/^[A-Za-z0-9_-]{8,64}$/.test(requestId))return {error:'Please retry this round'};
  const old=runs.get(owner);if(old?.requestId===requestId)return {run:summary(old)};if(old&&!old.finished&&now<old.endsAt)return {error:'Finish or leave your current round first'};
  const run={id:randomBytes(16).toString('hex'),requestId,startedAt:now,endsAt:now+60000,events:[],seq:0,lastTick:0,keys:{},finished:false,score:null};runs.set(owner,run);return {run:summary(run)};
 }
 function summary(r){return {id:r.id,startedAt:r.startedAt,endsAt:r.endsAt,finished:r.finished,score:r.score};}
 function input(owner,m,now=Date.now()){
  const r=runs.get(owner);if(!r||m.runId!==r.id||r.finished)return 'This round is not active';
  if(now>r.endsAt+3000)return 'This round has ended';
  if(!Number.isSafeInteger(m.seq)||m.seq!==r.seq+1||!Number.isSafeInteger(m.tick)||m.tick<r.lastTick||m.tick<Math.max(0,Math.floor((now-r.startedAt-1500)*HOOPS_HZ/1000))||m.tick<0||m.tick>=HOOPS_TICKS||m.tick>Math.floor(Math.max(0,now-r.startedAt)*HOOPS_HZ/1000)+30||!HOOPS_ACTIONS.includes(m.key)||typeof m.down!=='boolean'||r.events.length>=3000)return 'Invalid or out-of-order round input';
  if(!!r.keys[m.key]===m.down)return 'Repeated input transition';
  r.events.push({tick:m.tick,action:m.key,down:m.down});r.keys[m.key]=m.down;r.seq=m.seq;r.lastTick=m.tick;return null;
 }
 function finish(owner,m,now=Date.now()){
  const r=runs.get(owner);if(!r||m.runId!==r.id)return {error:'This round is not active'};if(r.finished)return {run:summary(r),replay:true};
  if(now<r.endsAt)return {error:'The round is still running'};if(now>r.endsAt+30000)return {error:'This round expired; play again'};
  if(m.seq!==r.seq)return {error:'Round inputs are incomplete'};
  r.score=replayHoops(r.events);r.finished=true;r.events=[];return {run:summary(r),replay:false};
 }
 function leave(owner){runs.delete(owner);}
 return {start,input,finish,leave,has:owner=>runs.has(owner),size:()=>runs.size};
}
