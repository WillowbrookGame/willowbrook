// SPDX-License-Identifier: MIT
import {getLanSite} from './lan-config.mjs';
import {startLocalServer} from '../paintball_prototype/network/browser/server.mjs';
const state='/var/lib/willowbrook-family-desk-container';
const site=getLanSite();
const local=await startLocalServer({port:24863,webRoot:'/web',accountsDir:state,
 parentDeskFile:state+'/.willowbrook-family-desk-opt-in',privateHttpsOrigin:site.origin});
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,async()=>{await local.close();process.exit();});
console.log('Willowbrook ready behind the private HTTPS edge.');
