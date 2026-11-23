import {createRequire} from 'node:module';
import {realpath,stat} from 'node:fs/promises';
import {isAbsolute,join,relative,resolve,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

export const projectRoot=fileURLToPath(new URL('../../../',import.meta.url));
export const standaloneRoot=fileURLToPath(new URL('./standalone-runtime/',import.meta.url));

function contains(root,candidate){
 const suffix=relative(root,candidate);
 return !suffix||(!isAbsolute(suffix)&&suffix!=='..'&&!suffix.startsWith('..'+sep));
}
export const pathsOverlap=(a,b)=>contains(a,b)||contains(b,a);

export function sourceArgument(args){
 const positions=args.flatMap((item,index)=>item==='--source'?[index]:[]);
 if(!positions.length)return undefined;
 const value=args[positions[0]+1];
 if(positions.length!==1||!value||value.startsWith('--'))throw Error('Specify one explicit trusted --source path, or omit it for the standalone runtime.');
 return value;
}

export async function selectRuntime(override){
 const standalone=override===undefined;
 if(!standalone&&(typeof override!=='string'||!override.trim()))throw Error('Invalid explicit Willowbrook runtime source.');
 const root=await realpath(standalone?standaloneRoot:resolve(override));
 if(!(await stat(root)).isDirectory()||!(await stat(join(root,'package.json'))).isFile())throw Error('Willowbrook runtime source must be a module directory.');
 const bundled=standalone||!relative(standaloneRoot,root);
 const require=createRequire(pathToFileURL(join(root,'package.json')));
 return {
  root,
  load:file=>import(pathToFileURL(join(root,file)).href),
  webSockets(){
   if(!bundled)return require('ws');
   // Exact pinned JS implementation; never load optional native packages from ancestors or NODE_PATH.
   const keys=['WS_NO_BUFFER_UTIL','WS_NO_UTF_8_VALIDATE'];
   const previous=keys.map(key=>process.env[key]);
   for(const key of keys)process.env[key]='1';
   try{return require(join(root,'vendor','ws','index.js'));}
   finally{keys.forEach((key,i)=>{if(previous[i]===undefined)delete process.env[key];else process.env[key]=previous[i];});}
  }
 };
}
