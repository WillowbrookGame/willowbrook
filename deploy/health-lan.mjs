// SPDX-License-Identifier: MIT
import {get} from 'node:http';
import {getLanSite} from './lan-config.mjs';

const site=getLanSite();
// The private origin guard requires the canonical Host header, even though
// this probe connects over loopback without the TLS edge.
const request=get({host:'127.0.0.1',port:24863,path:'/health',
 headers:{Host:site.host},timeout:3000}, response=>{
 response.resume();
 if(response.statusCode!==200)process.exitCode=1;
});
request.on('timeout',()=>request.destroy());
request.on('error',()=>{process.exitCode=1;});
