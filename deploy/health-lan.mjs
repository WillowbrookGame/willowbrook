// SPDX-License-Identifier: MIT
import {getLanSite} from './lan-config.mjs';
const site=getLanSite();
const r=await fetch('http://127.0.0.1:24863/health',{headers:{host:site.host}});
if(!r.ok)process.exitCode=1;
