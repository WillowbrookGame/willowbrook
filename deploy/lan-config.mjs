// SPDX-License-Identifier: MIT
import {isIPv4} from 'node:net';
import {networkInterfaces} from 'node:os';
import {privateHttpsSite} from '../game/network/browser/https_site_policy.mjs';

export function getLanSite(env = process.env) {
 const ip=env.WILLOWBROOK_PRIVATE_IP;
 const host=env.WILLOWBROOK_PRIVATE_HOST;
 const [a,b] = String(ip).split('.').map(Number);
 const local = Object.values(networkInterfaces()).flat().some(i=>i?.address===ip&&!i.internal);
 if(!isIPv4(ip??'')||!(a===10||a===172&&b>=16&&b<=31||a===192&&b===168)||!local) {
   throw new Error('WILLOWBROOK_PRIVATE_IP must be an assigned LAN IPv4 address in an RFC1918 subnet.');
 }
 if(typeof host!=='string'||host.includes(':'))throw new Error('Provide only the canonical LAN DNS name.');
 return privateHttpsSite('https://'+host+':8443');
}
