// Authenticated, cabinet-scoped adapter around pinned Apache-2.0 upstream Room.
// No listener, URL room discovery, persistent data, spectator or economy access.
import {Room} from './vendor/air-hockey/room.js';
import {arcadeCabinet} from './public/arcade-cabinets.js';
export function decodeHockeyInput(frame){
 if(!frame||frame.encoding!=='base64'||typeof frame.data!=='string'||frame.data.length!==8||!/^[A-Za-z0-9+/]{7}=$/.test(frame.data))return null;
 const bytes=Buffer.from(frame.data,'base64');if(bytes.length!==5||bytes[0]!==1||bytes.toString('base64')!==frame.data)return null;
 return new Uint8Array(bytes).buffer;
}
export function createUpstreamHockey({isAuthorized,send,autoStart=true}={}){
 if(typeof isAuthorized!=='function'||typeof send!=='function')throw new TypeError('Hockey requires authenticated host callbacks');
 const peers=new Map(),votes=new Set(),rules={arena:['ice','sea','desert'],rounds:3,goals:5};let room=new Room(rules),closed=false,phase='wait';
 const authorized=p=>{try{return !!p?.profile&&!p.profile.disabled&&!p.profile.mustChangePassword&&isAuthorized(p)===true;}catch{return false;}};
 const eligible=p=>authorized(p)&&p.interiorBusiness==='arcade'&&p.interiorHome==null&&p.carId==null&&!p.rest&&!p.playground;
 const side=p=>[...peers.keys()].indexOf(p);
 function output(p,data){if(!peers.has(p)||!eligible(p))return;let frame;if(typeof data==='string'){if(data.length>8192)return;const m=JSON.parse(data);if(m.t==='match'){phase=m.phase;if(phase!=='end')votes.clear();}frame={encoding:'text',data};}else{const bytes=new Uint8Array(data);if(bytes.byteLength>1024)return;frame={encoding:'base64',data:Buffer.from(bytes).toString('base64')};}send(p,{type:'airHockeyFrame',frame});}
 function connect(p){const conn={send:data=>output(p,data)};peers.set(p,{conn,lastInput:-Infinity});room.connect(conn);room.receive(conn,JSON.stringify({t:'join',name:String(p.profile.username||'Player').slice(0,64)}));}
 function leave(p){const entry=peers.get(p);if(!entry)return false;peers.delete(p);votes.delete(p);room.disconnect(entry.conn);if(authorized(p))send(p,{type:'airHockeyFrame',frame:null});if(!peers.size)room.stop();return true;}
 function sweep(){for(const p of [...peers.keys()])if(!eligible(p))leave(p);}
 function restart(){const participants=[...peers.keys()];room.stop();room=new Room(rules);peers.clear();votes.clear();phase='wait';for(const p of participants)if(eligible(p))connect(p);if(autoStart&&peers.size)room.start();}
 function handle(p,m,now=Date.now()){
  if(closed)return 'This table is closed';sweep();if(m?.action==='leave'){leave(p);return null;}if(!eligible(p))return 'Stand inside the arcade with an active account to play';
  if(m?.action==='join'){
   const c=arcadeCabinet('air-hockey');if(!Number.isFinite(p.x)||!Number.isFinite(p.z)||Math.hypot(p.x-c.talkX,p.z-c.talkZ)>c.radius)return 'Walk closer to the air hockey table';
   if(peers.has(p))return null;if(peers.size>=2)return 'This table already has two players';
   if([...peers.keys()].some(q=>q.profile===p.profile||q.profile.id&&q.profile.id===p.profile.id))return 'This player is already at the table';connect(p);if(autoStart)room.start();return null;
  }
  const entry=peers.get(p);if(!entry)return 'Join the table first';
  if(m.action==='frame'){const input=decodeHockeyInput(m.frame);if(!input)return 'Choose a valid paddle position';if(now-entry.lastInput<8)return null;entry.lastInput=now;room.receive(entry.conn,input);return null;}
  if(m.action==='rematch'){if(phase!=='end')return 'Finish this match first';votes.add(p);if(peers.size===2&&[...peers.keys()].every(q=>votes.has(q)))restart();return null;}
  return 'Choose a valid air hockey action';
 }
 const maintenance=autoStart?setInterval(sweep,100):null;maintenance?.unref?.();
 return {handle,leave,side,participants:()=>[...peers.keys()],sweep,tick(){sweep();room.tick();},close(){if(closed)return;closed=true;if(maintenance)clearInterval(maintenance);room.stop();for(const p of [...peers.keys()])leave(p);},get size(){return peers.size;},get phase(){return phase;}};
}
