let release=()=>{};
import {selectRuntime,sourceArgument,projectRoot} from './runtime_source.mjs';
import {openPreviewAccounts,validatePreviewDirectory} from './preview_accounts.mjs';
import {createFamilyDesk,requireDeskOptIn,claimDeskWriter} from './family_desk_preview.mjs';

try {
 const pick=name=>{const found=process.argv.flatMap((s,i)=>s===name?[process.argv[i+1]]:[]);return found.length===1?found[0]:null;};
 const source=sourceArgument(process.argv.slice(2)),accountsDir=pick('--accounts-dir'),marker=pick('--parent-desk-file'),username=pick('--owner');
 if(process.argv.length!==(source===undefined?8:10)||!accountsDir||!marker||!username||process.stdin.isTTY)throw Error('Owner setup requires explicit local desk options and private stdin.');
 const runtime=await selectRuntime(source);
 const dataPaths={accountsDir,source:runtime.root,projectRoot,site:null};
 await validatePreviewDirectory(dataPaths);
 requireDeskOptIn(marker,accountsDir);
 release=claimDeskWriter(accountsDir);
 const chunks=[];let length=0;
 for await(const chunk of process.stdin){
  if((length+=chunk.length)>404)throw Error('Password input too long.');
  chunks.push(chunk);
 }
 const password=new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks)).replace(/\r?\n$/,'');
 if(/[\r\n]/.test(password))throw Error('Use one private password input line.');
 const world=await runtime.load('world-store.mjs');
 const accounts=await openPreviewAccounts({...dataPaths,makeStore:world.makeStore,allowEmpty:true,parentDeskEnabled:true});
 const desk=createFamilyDesk({accounts,accountFile:accounts.accountFile,makeStore:world.makeStore,characters:world.characters});
 desk.bootstrapOwner(username,password);
 console.log('One local family desk owner created. No player or session created.');
}catch{
 console.error('Local Family Desk owner setup held; no secret was logged. Check the fresh isolated directory, opt-in marker, owner name, and private password input. Never run while its isolated server is running.');
 process.exitCode=1;
} finally{release();}
