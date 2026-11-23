import {HOOPS_HZ, HOOPS_TICKS, HOOPS_ACTIONS, replayHoops} from './hoops-simulation.js';

// Implements the original controller's message contract for offline solo
// practice. The controller, simulation, graphics and scoring are unchanged.
// No account, shared scoreboard, persistence or network is involved.
export function createLocalHoops(deliver, now = Date.now) {
  let run = null;
  let lastTick = 0;
  let events = [];
  let keys = new Set();
  let best = null;
  let stopped = false;
  const publish = (action, extra={}) => {
    const body = {type:'hoops88', action, serverTime:now(), best, rows:[], ...extra};
    queueMicrotask(() => { if (!stopped) deliver(body); });
  };
  return {
    send(m) {
      if (stopped || m?.type !== 'hoops88') return false;
      const {action} = m;
      if (action === 'leaderboard') publish(action);
      else if (action === 'start') {
        const t = now();
        run = {id:'practice-'+m.requestId, startedAt:t, endsAt:t+1000*HOOPS_TICKS/HOOPS_HZ, finished:false, score:null};
        lastTick = 0; events = []; keys = new Set();
        publish(action,{run:{...run}});
      } else if (action === 'input') {
        if (!run || run.finished || m.runId !== run.id
            || m.seq !== events.length+1 || !Number.isInteger(m.tick)
            || m.tick < lastTick || m.tick < 0 || m.tick >= HOOPS_TICKS
            || !HOOPS_ACTIONS.includes(m.key) || typeof m.down !== 'boolean'
            || keys.has(m.key) === m.down || events.length >= 3000) return false;
        lastTick = m.tick;
        if (m.down) keys.add(m.key); else keys.delete(m.key);
        events.push({tick:m.tick,action:m.key,down:m.down});
      } else if (action === 'finish') {
        if (!run || m.runId !== run.id || m.seq !== events.length) return false;
        if (!run.finished) {
          const score = replayHoops(events);
          run = {...run, finished:true, score};
          best = Math.max(score,best??0);
        }
        publish(action,{run:{...run}});
      } else if (action === 'leave') {
        run = null; events = []; keys.clear();
      } else return false;
      return true;
    },
    dispose() { stopped = true; run = null; events = []; keys.clear(); }
  };
}
