
import assert from 'node:assert/strict';
import {mkdtemp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createVehicleWorld,drivewayPlot,driveways,validVehicleGround} from './vehicle_world_preview.mjs';

const load=path=>import(pathToFileURL(resolve(process.argv[2],path)).href);
const [{makeStore},{validCarSpot}]=await Promise.all([load('world-store.mjs'),load('public/car-economy.js')]);
const folder=await mkdtemp(join(tmpdir(),'willowbrook-side-driveway-preview-'));
const accountFile=join(folder,'preview-accounts-v1.json');
const open=()=>Object.assign(makeStore(accountFile),{accountFile});
const makePeer=profile=>({profile,x:0,z:0,zone:'town',grounded:true,y:0,updated:Date.now()});
let store=open();store.setSettings({registrationEnabled:true});
const seeds=['keeperqa','otherqa'].map(username=>store.auth({type:'register',username,password:'all-fixture-only-do-not-use'}).profile);
const [a,b]=seeds;
store.state.homes[0].owner=a.id;store.state.homes[0].paidOff=true;store.state.homes[0].variant='family';
store.state.homes[1].owner=b.id;store.state.homes[1].paidOff=true;store.state.homes[1].variant='family';
a.stars=90;b.stars=20;
a.ownedCar={x:-40.1,z:-19.6,yaw:-Math.PI/2,tier:2}; // Former pad on this owner's plot.
b.ownedCar={x:40.1,z:4.4,yaw:Math.PI/2,tier:1}; // Former pad belonging to a different plot.
assert.ok(validCarSpot(a.ownedCar)&&validCarSpot(b.ownedCar));
store.save();
let pa=makePeer(a),pb=makePeer(b),team=[pa,pb],service=createVehicleWorld(store,()=>team,()=>false,validCarSpot);
service.sync(pa);service.sync(pb);
const row=(p)=>service.view(p).rows.find(x=>x.id==='a'+p.profile.id);
for(let i=0;i<6;i++){
 const d=driveways[i];
 assert.ok(d.houseX-d.x>=8.5);
 for(let z=d.z;z<=d.row+12;z+=.11)assert.ok(validVehicleGround(d.x,z));
 assert.equal(drivewayPlot(d.x,d.z),i);
 assert.ok(validVehicleGround(d.x+2.3,d.z));
 assert.equal(drivewayPlot(d.x+2.6,d.z),-1);
 if(d.side<0)assert.ok(!validVehicleGround(d.side*40.1,d.row+4.4));
 assert.ok(validCarSpot({x:d.x,z:d.row+12,yaw:0}));
}
const slot=driveways[0];
assert.equal(row(pa).x,slot.x);assert.equal(row(pa).z,slot.z);
assert.notEqual(row(pb).x,b.ownedCar.x);
assert.equal(a.ownedCar.tier,2);assert.equal(b.ownedCar.tier,1);
Object.assign(pa,{x:slot.x,z:slot.z+2.1,updated:Date.now()});
const board=service.call(pa,{operation:'enter',car:row(pa).id,seat:'driver'},Date.now());
assert.equal(board.error,undefined);
for(let i=0;i<49;i++){
 const n=Date.now();
 service.input(pa,{throttle:1,steer:0},n);
 service.tick(n,.05);
}
assert.ok(row(pa).z>slot.row+8.4 && validVehicleGround(row(pa).x,row(pa).z),'Actual driver must reach the street from its side pad.');
service.release(pa,true);
Object.assign(pa,{x:slot.x,z:slot.z+1.1,grounded:true,updated:Date.now()});
assert.equal(service.call(pa,{operation:'recall',destination:'home'},Date.now()).error,undefined);
const compat={...a.ownedCar};
assert.equal(compat.tier,2);assert.equal(compat.z,slot.row+12);assert.ok(validCarSpot(compat));
assert.equal(a.previewVehicleParkingV1.z,slot.z);
store=open();pa=makePeer(store.state.profiles.keeperqa);team=[pa];
service=createVehicleWorld(store,()=>team,()=>false,validCarSpot);service.sync(pa);
assert.equal(row(pa).z,slot.z);assert.equal(row(pa).tier,2);assert.equal(pa.profile.stars,90);
// An older version legitimately parks it elsewhere; do not overwrite that newer activity with the side-lane mirror.
Object.assign(pa.profile.ownedCar,{x:24,z:12,yaw:Math.PI/2});
store.save();store=open();pa=makePeer(store.state.profiles.keeperqa);team=[pa];
service=createVehicleWorld(store,()=>team,()=>false,validCarSpot);service.sync(pa);
assert.equal(row(pa).x,24);assert.equal(row(pa).z,12);
console.log('PASS six continuous side lanes, real legacy store won’t sanitize current parking, own retired pad relocates, foreign retired pad clears, drive on/off street, recall and restart, changed legacy parking wins, wallet/tier preserved');


