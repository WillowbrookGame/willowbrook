// Willowbrook bridge for the pinned Apache-2.0 upstream game. No new socket or URL route.
export function hockeyFrame(data){
 if(typeof data==='string')return data.length<=8192?{encoding:'text',data}:null;
 if(!(data instanceof ArrayBuffer)||data.byteLength!==5)return null;
 const bytes=new Uint8Array(data);if(bytes[0]!==1)return null;
 return {encoding:'base64',data:btoa(String.fromCharCode(...bytes))};
}
export function unpackHockeyFrame(frame){
 if(frame?.encoding==='text'&&typeof frame.data==='string'&&frame.data.length<=8192)return frame.data;
 if(frame?.encoding!=='base64'||typeof frame.data!=='string'||frame.data.length>1400||!/^[A-Za-z0-9+/]*={0,2}$/.test(frame.data))return null;
 try{const s=atob(frame.data);if(s.length>1024)return null;return Uint8Array.from(s,c=>c.charCodeAt(0)).buffer;}catch{return null;}
}
export function createUpstreamHockey(send,{load=()=>import('./vendor/air-hockey/client.js')}={}){
 const view=typeof document==='undefined'?null:document.createElement('div');
 let game=null,container=null,holder=null,observer=null,disposed=false,joined=false,confirmed=false,error=null,phase='wait',roster=[],you=-1,paused=false,lastSend=-Infinity,pendingFrame=null,flushTimer=null;
 const socket={binaryType:'arraybuffer',onopen:null,onclose:null,onmessage:null,
  send(data){if(disposed)return;if(typeof data==='string'){let m;try{m=JSON.parse(data);}catch{return;}if(m.t==='join'&&!joined){joined=true;if(send({type:'airHockey',action:'join'})===false){joined=false;error='Reconnecting. Close the table and try again.';}}return;}const frame=hockeyFrame(data);if(frame&&!paused&&joined){pendingFrame=frame;flush();}},
  close(){if(joined){joined=false;send({type:'airHockey',action:'leave'});}}};
 function flush(){if(disposed||paused||!joined){pendingFrame=null;return;}const now=performance.now(),wait=50-(now-lastSend);if(wait>0){if(flushTimer===null)flushTimer=setTimeout(()=>{flushTimer=null;flush();},wait);return;}if(pendingFrame){const frame=pendingFrame;pendingFrame=null;lastSend=now;send({type:'airHockey',action:'frame',frame});}}
 function retry(){if(confirmed||disposed)return;error=null;joined=true;if(send({type:'airHockey',action:'join'})===false){joined=false;error='Reconnecting. Try again shortly.';}}
 function clear(){pendingFrame=null;if(flushTimer!==null){clearTimeout(flushTimer);flushTimer=null;}for(const a of ['left','right','up','down'])game?.input?.(a,false);}
 function size(){if(!holder||!container)return;const r=container.getBoundingClientRect();const wide=globalThis.matchMedia?.('(orientation: landscape) and (max-height: 500px)').matches;const ratio=wide?2430/1125:4/3;holder.style.width=Math.max(0,Math.min(r.width,r.height*ratio))+'px';}
 return {view,
  async mount(node=view){if(disposed||container)return;if(!node){error='Game display unavailable';return;}container=node;container.style.cssText='width:100%;height:100%;display:grid;place-items:center;overflow:hidden';holder=document.createElement('div');container.append(holder);size();if(typeof ResizeObserver!=='undefined'){observer=new ResizeObserver(size);observer.observe(container);}try{const mod=await load();if(disposed)return;game=mod.airHockey(holder,{name:'Player',socket,fullscreen:false});game.on('roster',m=>{roster=m.players;you=m.you;confirmed=roster.some(p=>p.id===you);joined=confirmed;error=null;});game.on('match',m=>{phase=m.phase;});queueMicrotask(()=>{if(!disposed)socket.onopen?.();});}catch{error='This table could not load. Close it and try again.';}},
  receiveFrame(frame){if(disposed)return;if(frame===null){joined=false;confirmed=false;clear();error='Connection to table ended. Close and reopen to reconnect.';socket.onclose?.();return;}const data=unpackHockeyFrame(frame);if(data!==null)socket.onmessage?.({data});},
  setError(text){if(!confirmed)joined=false;error=String(text||'Unable to join this table');},
  input(action,pressed=true){if(disposed||paused)return;if(action==='action'&&pressed&&error&&!confirmed)retry();else if(action==='action'&&pressed&&phase==='end')send({type:'airHockey',action:'rematch'});else game?.input?.(action,pressed);},
  pause(value){const next=!!value;if(next===paused)return;paused=next;if(paused)clear();},tick(){},setMuted(){},
  get status(){const own=roster.find(p=>p.id===you);return {message:error||(!game?'Loading table...':roster.length<2?'Waiting for a friend at this cabinet.':phase==='end'?'Match complete! Both players can choose Rematch, or the next match starts soon.':'Your '+(own?.team===1?'right':'left')+' paddle: drag or use arrows. Three rounds to five goals.'),done:phase==='end'};},
  dispose(){if(disposed)return;disposed=true;clear();observer?.disconnect();game?.destroy();socket.close();holder?.remove();view?.remove();game=null;container=null;}
 };
}
