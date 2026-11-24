// SPDX-License-Identifier: MIT
import {accessSync, constants} from 'node:fs';
import {getLanSite} from './lan-config.mjs';
import {startLocalServer} from '../game/network/browser/server.mjs';

export function containerPaintballOptions({enabled=process.env.WILLOWBROOK_PAINTBALL,
 runtime='/opt/willowbrook-paintball', access=accessSync}={}) {
 if (enabled!=='1') return {};
 const exe=runtime+'/godot-paintball-stdio',project=runtime+'/project';
 try {
  access(exe,constants.X_OK);
  access(runtime+'/Godot_v4.7.2-stable_linux.x86_64',constants.X_OK);
  access(project+'/project.godot',constants.R_OK);
 } catch {
  return {enablePaintballLobbyTransport:true,paintballWorker:null};
 }
 return {enablePaintballLobbyTransport:true,paintballWorker:{exe,project}};
}

export const containerFamilyFeatures=Object.freeze({
 enableWeather:true,
 enableHomeVisits:true,
 enableHideSeek:true,
 chatEnabled:false
});

export async function startContainer({privateLan=false}={}) {
 const state='/var/lib/willowbrook-family-desk-container';
 const site=privateLan?getLanSite():null;
 const paintball=containerPaintballOptions();
 if (paintball.enablePaintballLobbyTransport&&!paintball.paintballWorker) {
  console.log('Online Paintball runtime unavailable; solo remains available.');
 }
 const local=await startLocalServer({port:24863,webRoot:'/web',accountsDir:state,
  parentDeskFile:state+'/.willowbrook-family-desk-opt-in',privateHttpsOrigin:site?.origin??null,
  ...containerFamilyFeatures,...paintball});
 for(const signal of ['SIGINT','SIGTERM'])process.once(signal,async()=>{await local.close();process.exit();});
 console.log(site?'Willowbrook ready behind the private HTTPS edge.':'Willowbrook ready on loopback.');
}
