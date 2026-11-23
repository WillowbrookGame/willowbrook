import {mountArcadeUI,loadArcadeGame} from './arcade-ui.js';
import {arcadeCabinet} from './arcade-cabinets.js';
import {createLocalHoops} from './local-hoops.js';
import {unavailableCabinets} from './available-games.js';

const host = document.getElementById('arcadeHost');
const cabinet = arcadeCabinet(new URL(location.href).searchParams.get('cabinet'));
let ui;
let disposed = false;
let observer;
let practice;
let hoopsStartTimer;
let gameReady = false;
const pending = [];
const handlers = new AbortController();
const reconnectHint = 'Multiplayer disconnected. Close and reopen this cabinet to play solo.';

function transport() {
  try { return window.parent.WillowbrookArcadeTransport; }
  catch { return null; }
}
const online = transport()?.available?.(window) === true;
function packet(message) {
  let data;
  try { data = typeof message === 'string' ? JSON.parse(message) : message; } catch { return; }
  if (disposed || !data) return;
  if (!gameReady) { if (pending.length >= 16) pending.shift(); pending.push(data); return; }
  if (data?.type === 'hoops88' && (data.error || data.action === 'start')) {
    clearTimeout(hoopsStartTimer);
    hoopsStartTimer = undefined;
  }
  if (data?.type === 'airHockeyFrame') ui?.receiveFrame(data.frame);
  else if (data?.type === 'airHockeyError') ui?.receiveError(data.text || data.error);
  else if (data?.type === 'hoops88' || data?.type === 'error' && cabinet?.id === 'basketball' || String(data?.type ?? '').startsWith('hoops88')) ui?.receiveHoops(data);
}
function closeInShell() {
  if (window.parent !== window) window.parent.postMessage({type:'willowbrook-arcade-close'},location.origin);
}
function showUnavailable(title, message) {
  const panel = document.createElement('section');
  panel.id = 'arcadeNetworkNotice';
  panel.setAttribute('role','dialog');
  panel.setAttribute('aria-modal','true');
  panel.setAttribute('aria-label',title);
  const heading = document.createElement('h2');
  heading.textContent = title;
  const explanation = document.createElement('p');
  explanation.textContent = message;
  const done = document.createElement('button');
  done.type = 'button';
  done.textContent = 'Back to Arcade';
  done.addEventListener('click',closeInShell);
  panel.append(heading,explanation,done);
  host.append(panel);
  done.focus();
  document.addEventListener('keydown',event=>{
    if (event.key === 'Escape') {event.preventDefault(); closeInShell();}
  },{signal:handlers.signal});
}

window.arcadeReceive = packet;
window.arcadeTransportChanged = ready => {
  if (ready || !online || disposed) return;
  if (cabinet?.id === 'air-hockey') {
    packet({type:'airHockeyFrame',frame:null});
    packet({type:'airHockeyError',error:'Multiplayer disconnected. Close this cabinet and press Multiplayer (M) to rejoin.'});
  } else if (cabinet?.id === 'basketball') {
    packet({type:'hoops88',error:reconnectHint});
  }
};
window.arcadeDispose = function() {
  disposed = true;
  handlers.abort();
  pending.length = 0;
  observer?.disconnect();
  clearTimeout(hoopsStartTimer);
  ui?.close();
  practice?.dispose();
};
if (!cabinet) {
  showUnavailable('Cabinet unavailable','This cabinet was not found.');
} else if (unavailableCabinets.includes(cabinet.id)) {
  showUnavailable('Coming soon','This cabinet is not open yet. Try another arcade game.');
} else if (cabinet.id === 'air-hockey' && !online) {
  showUnavailable('Air Hockey needs a friend',
    'Close this cabinet, then press Multiplayer (M). Reconnect or sign in, then have both players return to this cabinet and choose Play.');
} else {
  if (cabinet.id === 'basketball' && !online) practice = createLocalHoops(packet);
  ui = mountArcadeUI(host,{
    getCabinet: () => cabinet,
    async load(id,send) {
      gameReady = false;
      try {
        const game = await loadArcadeGame(id,send);
        setTimeout(()=>{
          if (disposed) return;
          gameReady = true;
          for (const item of pending.splice(0)) packet(item);
        },0);
        return game;
      } catch (error) {
        setTimeout(()=>{if(!disposed) window.parent.WillowbrookArcade?.fail(window);},0);
        throw error;
      }
    },
    clearInput() {},
    getMuted: () => false,
    send(message) {
      if (practice) return practice.send(message);
      try {
        if (transport()?.send(message,window) === true) {
          if (message.type === 'hoops88' && message.action === 'start') {
            clearTimeout(hoopsStartTimer);
            hoopsStartTimer = setTimeout(()=>packet({type:'hoops88',error:'The scoreboard did not respond. Close and reopen this cabinet to retry.'}),5000);
          }
          return true;
        }
      } catch {}
      if (message.type === 'hoops88' && message.action === 'start') {
        queueMicrotask(()=>packet({type:'hoops88',error:reconnectHint}));
      }
      if (message.type === 'airHockey' && ['join','restart','rematch'].includes(message.action)) {
        queueMicrotask(()=>packet({type:'airHockeyError',error:'Could not reach the other player. Check Multiplayer, then try again.'}));
      }
      return false;
    }
  });
  ui.open();
  const panel = document.getElementById('arcadePanel');
  if (practice) {
    const note = document.createElement('p');
    note.className = 'arcade-practice-note';
    note.textContent = 'Solo practice · Scores stay on this device for this cabinet visit.';
    panel.prepend(note);
  }
  observer = new MutationObserver(() => {
    if (!disposed && !ui.isOpen()) closeInShell();
  });
  observer.observe(panel,{attributes:true,attributeFilter:['hidden']});
  window.addEventListener('keydown',(event)=>{
    if (event.key==='Escape' && !panel.contains(document.activeElement)) {
      event.preventDefault();
      ui.close();
    }
  },{capture:true,signal:handlers.signal});
}

window.parent.WillowbrookArcade?.ready(window);
