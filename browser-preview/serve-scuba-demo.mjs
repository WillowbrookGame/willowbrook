import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,basename,resolve} from 'node:path';
import {createInterface} from 'node:readline';
import {startLocalServer} from '../game/network/browser/server.mjs';
const webRoot=resolve(process.argv[2]),source=process.argv[3]?resolve(process.argv[3]):undefined;
const input=createInterface({input:process.stdin,terminal:false});
let fixture,server,closing=false;
async function close(){
 if(closing)return;
 closing=true;
 input.close();
 try { if(server)await server.close(); } finally {
   if(fixture&&basename(fixture).startsWith('willowbrook-scuba-demo-'))await rm(fixture,{recursive:true,force:true});
 }
}
process.once('SIGINT',()=>{void close()});
process.once('SIGTERM',()=>{void close()});
try{
 const next=input[Symbol.asyncIterator]();
 const entry=await next.next();
 const {first}=JSON.parse(entry.value);
 if([first].some(p=>typeof p!=='string'||p.length<10||p.length>100))throw new Error('Choose a password from 10 to 100 characters for the test account.');
 fixture=await mkdtemp(join(tmpdir(),'willowbrook-scuba-demo-'));
 server=await startLocalServer({source,webRoot,port:0,accountsDir:fixture,chatEnabled:true,enableHideSeek:false,seedAccounts:[{username:'scuba_demo',password:first}]});
 console.log('Scuba local preview: http://127.0.0.1:'+server.address.port+'/');
 console.log('Sign in as scuba_demo. Ctrl+C here stops the isolated preview.');
 // Optional stdin stop for a disposable launcher smoke check. Not available through HTTP.
 for await(const line of input){if(line==='stop'){await close();break;}}
}catch(e){
 console.error(e instanceof SyntaxError?'Expected local launcher input.':e.message);
 await close();
 process.exitCode=1;
}
