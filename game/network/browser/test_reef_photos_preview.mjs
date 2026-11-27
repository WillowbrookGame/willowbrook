import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createPreviewReefPhotos,reefPhotoCatalog} from './reef_photos_preview.mjs';
const {makeStore}=await import(pathToFileURL(resolve(process.argv[2],'world-store.mjs')).href);
const dir=await mkdtemp(join(tmpdir(),'willowbrook-reef-photos-test-'));
try{
 const file=join(dir,'accounts.json');
 const get=()=>Object.assign(makeStore(file),{accountFile:file});
 let store=get();
 store.setSettings({registrationEnabled:true});
 const a=store.auth({type:'register',username:'reef_alice',password:'disposable_pass'});
 const b=store.auth({type:'register',username:'reef_bob',password:'disposable_pass'});
 assert.ok(a.profile&&b.profile);
 let photos=createPreviewReefPhotos(store);
 assert.equal(reefPhotoCatalog.length,8);
 assert.deepEqual(photos.snapshot(a.profile),[]);
 assert.deepEqual(photos.snapshot(b.profile),[]);

 // Invalid species rejected.
 assert.equal(photos.apply({profile:a.profile},{operation:'record',species:'not_a_fish',requestId:'req-00000001'}).ok,false);

 // Failed save rolls back cleanly.
 const realSave=store.save;
 store.save=()=>{throw Error('synthetic save failure');};
 assert.equal(photos.apply({profile:a.profile},{operation:'record',species:'clownfish',requestId:'req-00000002'}).ok,false);
 assert.deepEqual(photos.snapshot(a.profile),[]);
 store.save=realSave;

 // Confirmed photo saves once and does not double-count on repeat.
 const first=photos.apply({profile:a.profile},{operation:'record',species:'shark',requestId:'req-00000003'});
 assert.equal(first.ok,true);assert.equal(first.newDiscovery,true);assert.equal(first.count,1);assert.equal(first.total,8);
 const repeat=photos.apply({profile:a.profile},{operation:'record',species:'shark',requestId:'req-00000004'});
 assert.equal(repeat.ok,true);assert.equal(repeat.newDiscovery,false);assert.equal(repeat.count,1);

 // Full reload from disk: survives for alice and never appears on bob.
 store=get();
 photos=createPreviewReefPhotos(store);
 const aReloaded=store.auth({type:'resume',session:a.session}).profile;
 const bReloaded=store.auth({type:'resume',session:b.session}).profile;
 assert.deepEqual(photos.snapshot(aReloaded),['shark']);
 assert.deepEqual(photos.snapshot(bReloaded),[]);

 // Legacy profile with fishing discoveries but no reefPhotos loads cleanly as [].
 const legacy={username:'legacy',stars:0,previewFishing:{inventory:[],sales:[],catches:[],discovered:['shark']}};
 assert.deepEqual(photos.snapshot(legacy),[]);

 console.log('PASS reef photos server persistence: atomic save, rollback, full reload, account isolation, and Fishing separation.');
}finally{await rm(dir,{recursive:true,force:true});}
