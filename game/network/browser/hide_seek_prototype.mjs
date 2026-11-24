import {randomBytes} from 'node:crypto';
const MAX_PLAYERS = 8;
const LOBBY_MS = 60_000;
const HIDE_MS = 30_000;
const SEEK_MS = 180_000;
const TRANSITION_MS = 8_000;
const RESULT_MS = 20_000;
const POSE_MAX_AGE_MS = 700;
const TAG_COOLDOWN_MS = 500;
const RANGE = 2.25;
const FACING = Math.cos(65 * Math.PI / 180);

// Geometry is opt-in and fixture/scene-specific. Unknown geometry fails closed.
function blocked(a, b, boxes) {
  return boxes.some(({ min, max }) => {
    let t0 = 0, t1 = 1;
    for (const k of ['x', 'y', 'z']) {
      const at = a[k], d = b[k] - at;
      if (Math.abs(d) < 1e-9) {
        if (at < min[k] || at > max[k]) return false;
      } else {
        let ta = (min[k] - at) / d, tb = (max[k] - at) / d;
        if (ta > tb) [ta, tb] = [tb, ta];
        t0 = Math.max(t0, ta); t1 = Math.min(t1, tb);
        if (t0 > t1) return false;
      }
    }
    return true;
  });
}

// resolveScene is a trusted server adapter: {id, pose}, null while a validated door is
// loading, false for excluded scenes. Never populate it from a game action packet.
export function createHideSeekPrototype({ areas, resolveScene, admitted, seekMs=SEEK_MS, now = Date.now } = {}) {
  const rows=Object.entries(areas??{});
  if (!rows.length || rows.length>64 || typeof admitted !== 'function' || typeof resolveScene !== 'function' ||
      !Number.isInteger(seekMs)||seekMs<30_000||seekMs>600_000 || !rows.every(([id,area])=>
      !['private','beach','paintball'].includes(id) && /^[A-Za-z0-9:_-]+$/.test(id) &&
      area?.verified===true && Array.isArray(area.boxes) && area.boxes.length<=512 && area.bounds &&
      [area.bounds,...area.boxes].every(({min,max}) =>
        ['x','y','z'].every(k=>Number.isFinite(min?.[k])&&Number.isFinite(max?.[k])&&min[k]<max[k]))))
    throw new Error('Hide and Seek requires known local fixture geometry.');
  const geometry = new Map(rows.map(([id,geo])=>[id,JSON.parse(JSON.stringify(geo))]));
  const roster = new Map();
  const invited = new Map();
  let inviteId = null;
  let nextHint = 0, hint = false;
  let phase = 'idle', deadline = 0, host = null, seeker = null, result = null;
  const ok = extra => ({ok:true,...extra});
  const denied = error => ({ok:false,error});
  const who = p => admitted(p) && p?.profile && (typeof p.profile.id==='string'||Number.isSafeInteger(p.profile.id)) ? p.profile.id : null;
  const scene = (p,t) => {
    if(p.vehicleSeat||p.activity||p.rest==='sit')return false;
    return resolveScene(p,t);
  };
  const inBounds = (p,area) => p&&['x','y','z'].every(k=>Number.isFinite(p[k])&&p[k]>=area.bounds.min[k]&&p[k]<=area.bounds.max[k]);
  const playable = s=>Boolean(s&&geometry.has(s.id)&&inBounds(s.pose,geometry.get(s.id)));
  const canTagPose = (p,t) => p.grounded===true && Number.isFinite(p.yaw) &&
    Number.isFinite(p.updated) && t-p.updated>=0 && t-p.updated<=POSE_MAX_AGE_MS;
  const reset = () => { nextHint=0;hint=false;roster.clear();invited.clear();inviteId=null; phase='idle'; deadline=0; host=null; seeker=null; result=null; };
  function finish(winner, t) { result=winner; phase='results'; deadline=t+RESULT_MS; }
  function refresh(t) {
    for (const [id,row] of roster) {
      if (who(row.peer)!==id) {withdraw(id,t);continue;}
      const s=scene(row.peer,t);
      if(playable(s)){row.transition=null;continue;}
      if(s===null&&(row.transition??=t)+TRANSITION_MS>t)continue;
      withdraw(id,t);
    }
    if (phase==='results' && t>=deadline) { reset(); return; }
    if (phase==='lobby' && t>=deadline) { reset(); return; }
    if (phase==='hide' && t>=deadline) { phase='seek'; deadline+=seekMs; }
    if (phase==='seek' && t>=deadline) finish('hiders',t);
  }
  function withdraw(id,t) {
    if (!roster.delete(id)) return;
    if (!roster.size) {reset();return;}
    if (phase==='lobby') {if(id===host)host=roster.keys().next().value;return;}
    if (phase==='hide'||phase==='seek') {
      if(id===seeker) finish('hiders',t);
      else if (![...roster.values()].some(r=>r.id!==seeker&&!r.found)) finish('seeker',t);
    }
  }
  function handle(p,m) {
    const t=now(); refresh(t);
    const id=who(p);
    if(id===null||!m||typeof m!=='object'||!['join','start','tag','leave','accept','decline'].includes(m.action)||
        Object.keys(m).some(k=>!['type','action',...(['accept','decline'].includes(m.action)?['inviteId']:[])].includes(k))) return denied('Unavailable action.');
    const entry=roster.get(id);
    if(entry && entry.peer!==p) return denied('Already joined on another connection.');
    if(m.action==='leave'){withdraw(id,t);return ok({});}
    const answering=['accept','decline'].includes(m.action);
    if(answering&&(phase!=='lobby'||typeof m.inviteId!=='string'||m.inviteId!==inviteId||invited.get(id)!=='sent'))
      return denied('This invitation is no longer open.');
    if(m.action==='decline'){invited.set(id,'declined');return ok({});}
    const self=scene(p,t);
    if(!playable(self))return denied(answering?'Return to Town or a public Town building to join.':'Enter a supported Town area.');
    if(m.action==='join'||m.action==='accept'){
      if(!['idle','lobby'].includes(phase)||roster.size>=MAX_PLAYERS)return denied('This round is full or has started.');
      if(!entry)roster.set(id,{id,peer:p,found:false,lastTag:-Infinity,transition:null});
      if(phase==='idle'){
        host=id;phase='lobby';deadline=t+LOBBY_MS;
        inviteId=randomBytes(8).toString('hex');invited.clear();
      }
      invited.set(id,'joined');
      return ok({});
    }
    if(m.action==='start'){
      if(phase!=='lobby'||id!==host||roster.size<2)return denied('The host can start with at least two players.');
      if(!self.pose.grounded)return denied('Stand on the ground before starting.');
      seeker=host;phase='hide';deadline=t+HIDE_MS;
      return ok({});
    }
    if(phase!=='seek'||id!==seeker||!entry)return denied('Only the seeker can tag during seeking.');
    if(t-entry.lastTag<TAG_COOLDOWN_MS)return denied('Try again in a moment.');
    entry.lastTag=t;
    if(!canTagPose(self.pose,t))return denied('Stand on the ground before tagging.');
    const candidates=targets(self,id,t);
    if(!candidates.length)return denied('Get closer and face a hider in the open.');
    candidates[0].row.found=true;
    if(![...roster.values()].some(r=>r.id!==seeker&&!r.found))finish('seeker',t);
    return ok({found:true});
  }
  function targets(self,id,t) {
    const pos=self.pose, forwardX=-Math.sin(pos.yaw), forwardZ=-Math.cos(pos.yaw);
    const candidates=[];
    for(const row of roster.values()){
      if(row.id===id||row.found)continue;
      const candidate=scene(row.peer,t);
      if(candidate?.id!==self.id||!playable(candidate)||!canTagPose(candidate.pose,t))continue;
      const q=candidate.pose,dx=q.x-pos.x,dz=q.z-pos.z,dy=q.y-pos.y;
      const distance=Math.hypot(dx,dz);
      if(distance>RANGE||Math.abs(dy)>.9)continue;
      if(distance>.12&&(forwardX*dx+forwardZ*dz)/distance<FACING)continue;
      const a={x:pos.x,y:pos.y+1,z:pos.z}, b={x:q.x,y:q.y+1,z:q.z};
      if(blocked(a,b,geometry.get(self.id).boxes))continue;
      candidates.push({row,distance});
    }
    candidates.sort((a,b)=>a.distance-b.distance);
    return candidates;
  }
  const enrolled = p => roster.get(p?.profile?.id)?.peer===p;
  function presencePlace(observer,subject,place) {
    return ['hide','seek'].includes(phase)&&enrolled(observer)&&enrolled(subject)?'Hide and Seek':place;
  }
  function view(p) {
    const t=now();
    const id=who(p), row=roster.get(id);
    if(id===null||row?.peer!==p)return null;
    if(id===seeker&&phase==='seek'&&t>=nextHint){
      const s=scene(p,t);
      hint=playable(s)&&canTagPose(s.pose,t)&&targets(s,id,t).length>0;
      nextHint=t+250;
    }
    return {phase, remainingMs:Math.max(0,deadline-t), role:seeker===id?'seeker':seeker===null?'waiting':'hider',
      host:id===host, memberCount:roster.size, found:row.found,
      ...(phase==='seek'&&id===seeker?{tagEligible:hint}:{}),
      remaining:[...roster.values()].filter(r=>r.id!==seeker&&!r.found).length, result};
  }
  const frozen = p => phase==='hide'&&roster.get(seeker)?.peer===p;
  function invitationFor(p) {
    if(phase!=='lobby')return null;
    const id=who(p);
    if(id===null||roster.has(id)||invited.has(id))return null;
    const alias=roster.get(host)?.peer?.profile?.username??'Player';
    invited.set(id,'sent');
    return {type:'hideSeekInvite',id:inviteId,host:alias,remainingMs:Math.max(0,deadline-now())};
  }
  function visible(observer,subject) {
    if(phase!=='hide'||roster.get(seeker)?.peer!==observer)return true;
    const row=roster.get(subject?.profile?.id);
    return !row||row.peer!==subject||row.id===seeker||row.found;
  }
  return {handle,view,visible,presencePlace,enrolled,frozen,invitationFor,openInviteId:()=>phase==='lobby'?inviteId:null,tick:()=>refresh(now())};
}
