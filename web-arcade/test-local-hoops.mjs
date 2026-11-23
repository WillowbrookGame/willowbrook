import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {resolve,join} from 'node:path';

const assets=resolve(process.argv[2],'web-arcade');
const {createLocalHoops}=await import(pathToFileURL(join(assets,'local-hoops.js')).href);
const {replayHoops}=await import(pathToFileURL(join(assets,'hoops-simulation.js')).href);
const messages=[];
let clock=1_700_100_000_000;
const local=createLocalHoops(m=>messages.push(m),()=>clock);
const send=body=>local.send({type:'hoops88',...body});
assert.ok(send({action:'leaderboard'}));
assert.ok(send({action:'start',requestId:'test-round-abcd'}));
await Promise.resolve();
const received=messages.at(-1);
assert.equal(received.action,'start');
assert.equal(received.run.endsAt-received.run.startedAt,60000);
assert.equal(received.run.finished,false);
assert.deepEqual(received.rows,[]);
const id=received.run.id;
const events=[
  {tick:10,action:'right',down:true},
  {tick:55,action:'right',down:false},
  {tick:80,action:'shoot',down:true},
  {tick:110,action:'shoot',down:false}
];
for(const [i,event] of events.entries()) assert.ok(send({action:'input',runId:id,seq:i+1,tick:event.tick,key:event.action,down:event.down}));
assert.equal(send({action:'input',runId:id,seq:events.length+1,tick:5,key:'left',down:true}),false);
assert.equal(send({action:'finish',runId:id,seq:0}),false);
clock+=60000;
assert.ok(send({action:'finish',runId:id,seq:events.length}));
await Promise.resolve();
assert.equal(messages.at(-1).run.score,replayHoops(events));
assert.equal(messages.at(-1).run.finished,true);
assert.deepEqual(messages.at(-1).rows,[]);
local.dispose();
assert.equal(send({action:'start',requestId:'should-ignore'}),false);
console.log('PASS offline HOOPS uses original replay scoring with no external leaderboard');
