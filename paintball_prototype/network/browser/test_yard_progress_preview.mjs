import assert from 'node:assert/strict';
import {mkdtemp,mkdir,rm,rename,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createPreviewYards} from './yard_progress_preview.mjs';
const source=resolve(process.argv[2]),load=m=>import(pathToFileURL(join(source,m)).href);
const [{makeStore},rules]=await Promise.all([load('world-store.mjs'),load('public/yard-upgrades.js')]);
const dir=await mkdtemp(join(tmpdir(),'willowbrook-yard-test-'));
try{
 const file=join(dir,'qa.json'),now=10000;
 const get=()=>Object.assign(makeStore(file),{accountFile:file});
 let store=get();
 store.setSettings({registrationEnabled:true});
 const a=store.auth({type:'register',username:'yard_first',password:'synthetic-pass'}), b=store.auth({type:'register',username:'yard_second',password:'synthetic-pass'});
 const teller={interiorBusiness:'bank',x:-54,z:-48}, bank=(p,wire)=>store.bank(p,wire,teller);
 for(const [i,p] of [a.profile,b.profile].entries()){p.hasJob=true;p.stars=900;assert.equal(bank(p,{action:'apply',home:i}),null);}
 for(const variant of ['cottage','family']){
  const loan=a.profile.mortgage;
  assert.equal(bank(a.profile,{action:'repay',amount:loan.balance,loanId:loan.id,requestId:'fixture-pay-'+variant}),null);
  assert.equal(bank(a.profile,{action:'upgrade',home:0,variant}),null);
 }
 a.profile.stars=100;b.profile.stars=100;store.save();
 let service=createPreviewYards({store,rules});
 const peer=profile=>({profile,zone:'town',x:-51,z:-19,y:.03,updated:now,grounded:true});
 let p=peer(a.profile),q=peer(b.profile);
 const buy=(p,kind,requestId,extra={})=>service.apply(p,{type:'progress',action:'yard',operation:'buy',kind,requestId,...extra},now);
 assert.equal(service.snapshot(p.profile).eligible,true);assert.equal(service.snapshot(q.profile).eligible,false);
 assert.match(buy(q,'fence','starter-owner-denied').error,/Family home/);
 assert.match(buy(p,'fence','wrong-owner-supplied',{home:1}).error,/Choose/);
 assert.match(buy(p,'fence','stale-location-test',{price:0}).error,/Choose/);
 assert.match(buy({...p,updated:0},'fence','too-stale-for-yard').error,/front yard/);
 assert.match(buy({...p,zone:'private'},'fence','unknown-private-room').error,/front yard/);
 const near={...p,zone:'private',petHome:{plot:0,inRoom:true,furniturePose:{x:0,y:0,z:3.5,at:now}}};
 await mkdir(file+'.tmp');
 assert.match(buy(near,'fence','failed-fence-req').error,/Nothing was changed/);
 assert.equal(p.profile.stars,100);assert.deepEqual(service.town(),[]);
 await rm(file+'.tmp',{recursive:true,force:true});
 assert.match(buy(near,'fence','fence-row-saved').text,/installed/);
 assert.match(buy(near,'fence','fence-row-saved').text,/already saved/);
 assert.match(buy(near,'trees','fence-row-saved').error,/already used/);
 assert.match(buy(near,'fence','different-fence-request').error,/already installed/);
 assert.equal(p.profile.stars,70);
 const backups=join(dir,'backups');
 await rename(backups,join(dir,'backups-old'));await writeFile(backups,'backup rename already happened');
 assert.match(buy(p,'trees','trees-row-saved').text,/installed/);
 await rm(backups,{force:true});await rename(join(dir,'backups-old'),backups);
 assert.match(buy(p,'decor','decor-row-saved').text,/installed/);
 assert.deepEqual(service.town(),[{plot:0,fence:true,trees:true,decor:true}]);
 assert.equal(p.profile.stars,35);assert.equal(q.profile.stars,100);
 assert.equal(p.profile.mortgage.balance,300);
 store=get();service=createPreviewYards({store,rules});
 p=peer(store.auth({type:'resume',session:a.session}).profile);q=peer(store.auth({type:'resume',session:b.session}).profile);
 assert.deepEqual(service.town(),[{plot:0,fence:true,trees:true,decor:true}]);assert.equal(p.profile.stars,35);assert.equal(q.profile.stars,100);
 assert.match(buy(p,'decor','decor-row-saved').text,/already saved/);
 assert.equal(p.profile.stars,35);
 console.log('PASS original 30/20/15 prices, private own/yard reach, one-time purchases, safe retries/front-yard validation, save faults, restart and privacy-only plot flags.');
}finally{await rm(dir,{recursive:true,force:true});}

