
import assert from 'node:assert/strict';
import {mkdtemp,readFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createPreviewHunt,makeHuntPlacements} from './scavenger_preview.mjs';
const source=resolve(process.argv[2]);
const load=file=>import(pathToFileURL(join(source,file)).href);
const [{makeStore},{scavengerHunt:catalog}]=await Promise.all([load('world-store.mjs'),load('public/scavenger-hunt.js')]);
const spots=JSON.parse((await readFile(new URL('../../scavenger/spots.json',import.meta.url),'utf8')).replace(/^\uFEFF/,''));
const byId=new Map(spots.map(s=>[s.id,s]));
const seeded=seed=>n=>{
 seed=(Math.imul(seed,1664525)+1013904223)>>>0;
 return Math.floor(seed*n/0x100000000);
};
const seen=new Set();
let someWithoutBeach=false;
for(let seed=0;seed<100;seed++){
 const result=makeHuntPlacements({items:catalog.items,spots,random:seeded(seed)});
 assert.equal(result.length,8);
 assert.equal(new Set(result.map(r=>r.id)).size,8);
 assert.equal(new Set(result.map(r=>r.spotId)).size,8);
 const zones=result.map(r=>byId.get(r.spotId).zone);
 assert.ok(zones.every(z=>!['private','paintball'].includes(z)));
 zones.forEach(z=>seen.add(z));
 if(!zones.includes('beach'))someWithoutBeach=true;
}
assert.ok(seen.has('town')&&seen.has('beach')&&seen.has('library'));
assert.ok(someWithoutBeach,'Beach is possible, not forced');
const path=join(await mkdtemp(join(tmpdir(),'willowbrook-hunt-test-')),'account.json');
let store=makeStore(path);
const fixture={type:'register',username:'hunt_test_a',password:'disposable hunt fixture'};
const a=store.auth(fixture),b=store.auth({...fixture,username:'hunt_test_b'});
const setup=()=>createPreviewHunt({store,catalog,spots,random:n=>n-1});
let hunt=setup();
let now=100_000;
const peer={profile:a.profile,zone:'town',x:0,y:0,z:0,grounded:true,updated:now};
const place=(zone,x,z)=>Object.assign(peer,{zone,x,z,updated:now});
const start=(requestId,runId)=>hunt.apply(peer,{type:'progress',action:'scavenger',operation:'start',requestId,runId},now);
const pick=marker=>hunt.apply(peer,{type:'progress',action:'scavenger',operation:'collect',runId:hunt.snapshot(peer.profile).runId,item:marker.id},now);
assert.match(start('request-old-first',null).error,/Mayor/);
place('town',24,-26);
assert.ok(start('request-first',null).text);
const first=hunt.snapshot(peer.profile);
assert.equal(first.placements.length,8);
assert.equal(first.startedAt,now);
assert.deepEqual(hunt.snapshot(b.profile).placements,[]);
assert.ok(start('request-first',null).text);
assert.equal(hunt.snapshot(peer.profile).runId,first.runId);
assert.match(start('request-new-active',first.runId).error,/Finish/);
const initial=first.placements[0];
place('paintball',initial.x,initial.z);
assert.match(pick(initial).error,/closer/);
place(initial.zone,initial.x,initial.z);
now+=2000;
assert.match(pick(initial).error,/closer/);
place(initial.zone,initial.x,initial.z);
assert.match(pick(initial).text,/found/);
assert.match(pick(initial).text,/already/);
assert.equal(hunt.snapshot(peer.profile).collected.length,1);
store=makeStore(path);
peer.profile=store.auth({type:'resume',session:a.session}).profile;
hunt=setup();
assert.equal(hunt.snapshot(peer.profile).runId,first.runId);
assert.deepEqual(hunt.snapshot(peer.profile).collected,[initial.id]);
assert.deepEqual(hunt.leaderboard(),[]);
for(const marker of first.placements.slice(1)){
 now+=250;place(marker.zone,marker.x,marker.z);
 assert.ok(pick(marker).text);
}
const completed=hunt.snapshot(peer.profile);
assert.equal(completed.collected.length,8);
assert.equal(completed.elapsedMs,now-first.startedAt);
assert.equal(completed.bestMs,completed.elapsedMs);
assert.equal(completed.rewardClaimed,true);
assert.equal(peer.profile.stars,0);
assert.deepEqual(hunt.leaderboard(),[{rank:1,displayName:'hunt_test_a',durationMs:completed.bestMs}]);
now+=100;place('town',24,-26);
assert.ok(start('request-second',first.runId).text);
const second=hunt.snapshot(peer.profile);
assert.notEqual(second.runId,first.runId);
assert.notDeepEqual(second.placements,first.placements);
assert.equal(second.rewardClaimed,true);
assert.equal(second.bestMs,completed.bestMs);
assert.equal(second.completedAt,null);
for(const marker of second.placements){
 now+=1000;place(marker.zone,marker.x,marker.z);
 const result=pick(marker);
 assert.ok(result.text);
 assert.doesNotMatch(result.text,/earned the treasure trophy/);
}
assert.equal(hunt.snapshot(peer.profile).bestMs,completed.bestMs);
assert.equal(hunt.snapshot(store.auth({type:'resume',session:b.session}).profile).trophyAwarded,false);
console.log('PASS original eight treasures, seeded eligible placement distribution, optional beach, no paintball, active account resume, original timing/bests/reroll and one lifetime trophy with no star mint.');

