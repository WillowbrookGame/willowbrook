// HOOPS '88 adaptation; MIT copyright Carlos Sardo and Eduardo Sardo, 2026.
// Original artwork/renderer preserved; shared physics and server-verified scoring.
import {createHoopsSimulation,HOOPS_HZ,HOOPS_TICKS} from './hoops-simulation.js';
import {requestId} from './request-id.js';
export function createHoopsView(send){
 const view=globalThis.document.createElement('div');view.tabIndex=0;view.style.cssText='width:100%;height:100%;overflow:hidden';const root=view.attachShadow({mode:'open'});
 root.innerHTML='<link rel="stylesheet" href="'+new URL('./vendor/hoops88/adapted.css'+new URL(import.meta.url).search,import.meta.url).href+'"><div class="hoops-body">'+"\n  <div class=\"crt\">\n    <div class=\"game-shell\">\n      <header class=\"hud\">\n        <div id=\"blockScore\" class=\"hud-block\">\n          <span id=\"lblScore\" class=\"hud-label\">SCORE</span>\n          <span id=\"score\" class=\"hud-value\">000</span>\n        </div>\n        <div class=\"hud-block\">\n          <span class=\"hud-label\">TIME</span>\n          <span id=\"time\" class=\"hud-value\">60</span>\n        </div>\n        <div id=\"blockCombo\" class=\"hud-block\">\n          <span id=\"lblCombo\" class=\"hud-label\">COMBO</span>\n          <span id=\"combo\" class=\"hud-value\">x1</span>\n        </div>\n        <div id=\"blockBest\" class=\"hud-block\">\n          <span class=\"hud-label\">BEST</span>\n          <span id=\"best\" class=\"hud-value\">000</span>\n        </div>\n      </header>\n\n      <div class=\"canvas-wrap\">\n        <canvas id=\"game\" width=\"480\" height=\"640\"></canvas>\n\n        <!-- Start screen -->\n        <div id=\"startScreen\" class=\"overlay\">\n          <h1 class=\"title\">HOOPS<span class=\"title-year\">'88</span></h1>\n          <p class=\"subtitle\">RETRO ARCADE BASKETBALL</p>\n          <div class=\"instructions\">\n            <p class=\"ctrl-p1\">P1 \u25c4 \u25ba / A D \u2014 MOVE &nbsp; \u25b2 \u25bc / W S \u2014 ARC &nbsp; SPACE \u2014 SHOOT</p>\n            <p class=\"ctrl-p2\">P2 \u25c4 \u25ba \u2014 MOVE &nbsp; \u25b2 \u25bc \u2014 ARC &nbsp; ENTER \u2014 SHOOT</p>\n            <p>HOLD shoot to charge, RELEASE to fire. SINK baskets!</p>\n            <p class=\"ctrl-touch\">TAP &amp; HOLD the on-screen pads to MOVE &amp; AIM &nbsp; \u00b7 &nbsp; HOLD SHOOT to charge, RELEASE to fire.</p>\n          </div>\n          <div class=\"btn-row\">\n            <button id=\"startBtn\" class=\"arcade-btn\">1 PLAYER \u25b8</button>\n            <button id=\"startBtn2\" class=\"arcade-btn alt\">2 PLAYERS \u00b7 1v1 \u25b8</button>\n          </div>\n          <p class=\"hint\">1v1: both players share the hoop \u2014 most points in 60s WINS.</p>\n        </div>\n\n        <!-- Game over screen -->\n        <div id=\"overScreen\" class=\"overlay hidden\">\n          <h1 class=\"title small\">GAME OVER</h1>\n          <p id=\"winnerLine\" class=\"winner-line hidden\">PLAYER 1 WINS</p>\n          <p class=\"final-line\">FINAL SCORE</p>\n          <p id=\"finalScore\" class=\"final-score\">000</p>\n          <p id=\"newBest\" class=\"new-best hidden\">\u2605 NEW HIGH SCORE \u2605</p>\n          <button id=\"againBtn\" class=\"arcade-btn\">PLAY AGAIN</button>\n        </div>\n\n        <!-- Touch controls (mobile, 1-player only) -->\n        <div id=\"touchControls\" class=\"touch-controls hidden\" aria-hidden=\"true\">\n          <div class=\"touch-cluster touch-move\">\n            <button class=\"touch-btn\" data-touch=\"left\" aria-label=\"Move left\">\u25c4</button>\n            <button class=\"touch-btn\" data-touch=\"right\" aria-label=\"Move right\">\u25ba</button>\n          </div>\n          <div class=\"touch-cluster touch-arc\">\n            <button class=\"touch-btn\" data-touch=\"up\" aria-label=\"Raise arc\">\u25b2</button>\n            <button class=\"touch-btn\" data-touch=\"down\" aria-label=\"Lower arc\">\u25bc</button>\n          </div>\n          <button class=\"touch-btn touch-shoot\" data-touch=\"shoot\" aria-label=\"Hold to charge, release to shoot\">SHOOT</button>\n        </div>\n      </div>\n\n      <footer class=\"foot\">\n        <span id=\"message\" class=\"message\">READY</span>\n      </footer>\n    </div>\n  </div>\n\n  "+'<pre id="board"></pre><p class="credit">HOOPS &#39;88  -  Carlos Sardo & Eduardo Sardo  -  MIT</p></div>';

 const document={getElementById:id=>root.querySelector('#'+id),body:root.querySelector('.hoops-body')};
 const window=globalThis.window;let disposed=false,raf=0,lastFrame=0,run=null,seq=0,finishSent=false,failed=false,pendingStart=false,paused=false,soundMuted=true,observer=null,clock={server:Date.now(),local:performance.now()};const timers=new Set();
 const setTimeout=(fn,ms)=>{const id=globalThis.setTimeout(()=>{timers.delete(id);if(!disposed)fn();},ms);timers.add(id);return id;};
 const serverNow=()=>clock.server+performance.now()-clock.local;
 function recordInput(action,down){advanceToClock();if(paused&&down||failed||!run||run.finished||!sim.state.running)return;const tick=sim.tick;if(tick>=HOOPS_TICKS)return;if(sim.input(action,down)){send({type:'hoops88',action:'input',runId:run.id,seq:++seq,tick,key:action,down});}}
 function onSimulationEvent(e){if(e.type==='sound'){if(!paused)sfx[e.name]?.(...e.args);}else if(e.type==='basket'){scoreBasket(state.shooters[0],e.swish,e.superShot);}else if(e.type==='end')endGame();}


  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const W = canvas.width;
  const H = canvas.height;

  // ---- UI elements ----
  const ui = {
    score: document.getElementById("score"),
    time: document.getElementById("time"),
    combo: document.getElementById("combo"),
    best: document.getElementById("best"),
    message: document.getElementById("message"),
    startScreen: document.getElementById("startScreen"),
    overScreen: document.getElementById("overScreen"),
    startBtn: document.getElementById("startBtn"),
    startBtn2: document.getElementById("startBtn2"),
    againBtn: document.getElementById("againBtn"),
    finalScore: document.getElementById("finalScore"),
    newBest: document.getElementById("newBest"),
    winnerLine: document.getElementById("winnerLine"),
    // HUD blocks / labels (relabeled per mode)
    blockScore: document.getElementById("blockScore"),
    blockCombo: document.getElementById("blockCombo"),
    blockBest: document.getElementById("blockBest"),
    lblScore: document.getElementById("lblScore"),
    lblCombo: document.getElementById("lblCombo"),
  };

  // ---- Device detection (touch / mobile) ----
  // Coarse pointer + touch points => treat as a mobile/touch device.
  const IS_TOUCH =
    (("ontouchstart" in window) || (navigator.maxTouchPoints || 0) > 0) &&
    window.matchMedia("(pointer: coarse)").matches;
  if (IS_TOUCH) document.body.classList.add("is-touch");

  const touchControls = document.getElementById("touchControls");

  // ---- Constants ----
  const GRAVITY = 1500;          // px/s^2
  const BALL_R = 18;
  const ROUND_TIME = 60;         // seconds
  const FLOOR_Y = H - 70;

  // ---- Keyboard player constants ----
  const PLAYER_W = 26;
  const PLAYER_H = 58;
  const PLAYER_SPEED = 240;      // px/s horizontal walk speed
  const MAX_SHOT_V = 1500;       // px/s launch speed at full power
  const MIN_SHOT_V = 320;        // px/s launch speed at zero power
  const MIN_ANGLE = 25 * Math.PI / 180;  // flattest shot (from horizontal)
  const MAX_ANGLE = 82 * Math.PI / 180;  // steepest shot
  const AIM_RATE = 1.4;          // rad/s angle adjust
  const CHARGE_RATE = 1.6;       // power meter cycles/s (ping-pong)
  const DEG = Math.PI / 180;

  // Player colors (P1 cyan, P2 magenta)
  const P_COLORS = ["#2ff3ff", "#ff4fd8"];

  // ---- High score (persisted, solo only) ----
  let best=0;

  // ---- Game state ----
  let sim=createHoopsSimulation({event:onSimulationEvent}),state=sim.state,hoop=sim.hoop;
  state.running=false;
  // ---------------------------------------------------------------
  //  Shooter factory — each human player owns a player, ball & aim
  // ---------------------------------------------------------------
  function createShooter(cfg) {
    const sh = {
      id: cfg.id,
      label: cfg.label,
      color: cfg.color,
      startX: cfg.startX,
      facing: cfg.facing,
      score: 0,
      combo: 1,
      shotScored: false,
      player: { x: cfg.startX, y: FLOOR_Y, facing: cfg.facing, walk: 0 },
      ball: { x: 0, y: 0, vx: 0, vy: 0, flying: false, canScore: false, spin: 0, rot: 0, wallHit: false },
      aim: { angle: 65 * DEG, charging: false, power: 0, chargeDir: 1 },
      keys: Object.create(null),
    };
    resetBall(sh);
    return sh;
  }

  // ---------------------------------------------------------------
  //  Audio (Web Audio API — no asset files needed)
  // ---------------------------------------------------------------
  let audioCtx = null;
  function ensureAudio() {
    if(disposed||paused||soundMuted)return;
    if (!audioCtx) {
      try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); }
      catch (e) { audioCtx = null; }
    }
  }
  function blip(freq, dur, type = "square", vol = 0.15, slideTo = null) {
    if (!audioCtx||disposed||paused||soundMuted) return;
    const t = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + dur);
  }
  const sfx = {
    shoot: () => blip(220, 0.12, "square", 0.12, 520),
    bounce: () => blip(140, 0.08, "triangle", 0.1),
    rim: () => blip(320, 0.05, "sawtooth", 0.08),
    swish: () => { blip(880, 0.12, "sine", 0.16, 1320); setTimeout(() => blip(1320, 0.14, "sine", 0.12, 1760), 90); },
    score: () => { blip(660, 0.1, "square", 0.14, 990); setTimeout(() => blip(990, 0.12, "square", 0.12), 90); },
    combo: (n) => blip(440 + n * 80, 0.12, "square", 0.16, 660 + n * 80),
    over: () => { blip(440, 0.2, "square", 0.16, 220); setTimeout(() => blip(330, 0.3, "square", 0.16, 110), 180); },
    super: () => {
      // rising arcade fanfare for a wall-banked super shot
      blip(523, 0.1, "square", 0.16, 784);
      setTimeout(() => blip(784, 0.1, "square", 0.16, 1046), 90);
      setTimeout(() => blip(1046, 0.16, "square", 0.18, 1568), 180);
      setTimeout(() => blip(1568, 0.2, "sine", 0.14, 2093), 300);
    },
  };

  // ---------------------------------------------------------------
  //  Input — keyboard controls, mapped per player
  //  P1 (always):     A/D move, W/S arc, SPACE shoot
  //  P1 (solo also):  arrow keys mirror WASD
  //  P2 (duel):       ← → move, ↑ ↓ arc, ENTER (or /) shoot
  // ---------------------------------------------------------------
  let keyMap = Object.create(null);

  function buildKeyMap(mode) {
    const map = Object.create(null);
    // Player 1
    map["a"] = { p: 0, act: "left" };
    map["d"] = { p: 0, act: "right" };
    map["w"] = { p: 0, act: "up" };
    map["s"] = { p: 0, act: "down" };
    map[" "] = { p: 0, act: "shoot" };
    map["spacebar"] = { p: 0, act: "shoot" };
    if (mode === "duel") {
      // Player 2 owns the arrow keys + Enter / slash
      map["arrowleft"] = { p: 1, act: "left" };
      map["arrowright"] = { p: 1, act: "right" };
      map["arrowup"] = { p: 1, act: "up" };
      map["arrowdown"] = { p: 1, act: "down" };
      map["enter"] = { p: 1, act: "shoot" };
      map["/"] = { p: 1, act: "shoot" };
    } else {
      // Solo: arrow keys mirror P1's WASD
      map["arrowleft"] = { p: 0, act: "left" };
      map["arrowright"] = { p: 0, act: "right" };
      map["arrowup"] = { p: 0, act: "up" };
      map["arrowdown"] = { p: 0, act: "down" };
    }
    return map;
  }

function startCharge(sh){recordInput('shoot',true);}

function onKeyDown(e){const b=keyMap[e.key.toLowerCase()];if(b){e.preventDefault();recordInput(b.act,true);}}

function onKeyUp(e){const b=keyMap[e.key.toLowerCase()];if(b){e.preventDefault();recordInput(b.act,false);}}




  // ---------------------------------------------------------------
  //  Touch controls (mobile, 1-player / solo only)
  //  On-screen pads drive the same per-shooter key flags as keyboard.
  // ---------------------------------------------------------------
  function soloShooter() {
    return state.running && state.mode === "solo" ? state.shooters[0] : null;
  }

function touchPress(act,on){recordInput(act,on);}

  function setupTouchControls() {
    if (!touchControls) return;
    const btns = touchControls.querySelectorAll("[data-touch]");
    btns.forEach((btn) => {
      const act = btn.getAttribute("data-touch");
      const press = (e) => {
        e.preventDefault();
        if (btn.setPointerCapture) {
          try { btn.setPointerCapture(e.pointerId); } catch (_) {}
        }
        btn.classList.add("pressed");
        touchPress(act, true);
      };
      const release = (e) => {
        e.preventDefault();
        btn.classList.remove("pressed");
        touchPress(act, false);
      };
      btn.addEventListener("pointerdown", press);
      btn.addEventListener("pointerup", release);
      btn.addEventListener("pointercancel", release);
      btn.addEventListener("contextmenu", (e) => e.preventDefault());
    });
  }
  setupTouchControls();

  function showTouchControls(show) {
    if (!touchControls) return;
    if (show && IS_TOUCH) {
      touchControls.classList.remove("hidden");
      touchControls.setAttribute("aria-hidden", "false");
    } else {
      touchControls.classList.add("hidden");
      touchControls.setAttribute("aria-hidden", "true");
      touchControls
        .querySelectorAll(".pressed")
        .forEach((b) => b.classList.remove("pressed"));
    }
  }

  // Launch a shooter's ball using its current angle + power.
function shootBall(sh){recordInput('shoot',false);}

  ui.startBtn.addEventListener("click", () => startGame("solo"));
  ui.startBtn2.addEventListener("click", () => startGame("duel"));
  ui.againBtn.addEventListener("click", () => startGame(state.mode));

  // ---------------------------------------------------------------
  //  Game flow
  // ---------------------------------------------------------------
  function configureHud(mode) {
    if (mode === "duel") {
      ui.lblScore.textContent = "P1";
      ui.blockScore.classList.add("hud-p1");
      ui.lblCombo.textContent = "P2";
      ui.blockCombo.classList.add("hud-p2");
      ui.blockBest.classList.add("hidden");
    } else {
      ui.lblScore.textContent = "SCORE";
      ui.blockScore.classList.remove("hud-p1");
      ui.lblCombo.textContent = "COMBO";
      ui.blockCombo.classList.remove("hud-p2");
      ui.blockBest.classList.remove("hidden");
    }
  }

function startGame(){if(pendingStart||run&&!run.finished)return;pendingStart=true;ensureAudio();if(!soundMuted&&!paused&&audioCtx?.state==='suspended')audioCtx.resume().catch(()=>{});setMessage('Connecting to the town scoreboard...');send({type:'hoops88',action:'start',requestId:requestId()});}

function endGame(){state.running=false;showTouchControls(false);ui.finalScore.textContent=pad(sim.score);ui.winnerLine.classList.add('hidden');ui.newBest.classList.add('hidden');ui.overScreen.classList.remove('hidden');setMessage('Checking score with the town server...');if(run&&!finishSent){finishSent=true;send({type:'hoops88',action:'finish',runId:run.id,seq});}}

  // Where the ball sits while held in a player's hands.
  function handPos(sh) {
    return {
      x: sh.player.x + sh.player.facing * 8,
      y: sh.player.y - PLAYER_H - BALL_R + 4,
    };
  }

  function resetBall(sh) {
    const h = handPos(sh);
    sh.ball.x = h.x;
    sh.ball.y = h.y;
    sh.ball.vx = 0;
    sh.ball.vy = 0;
    sh.ball.flying = false;
    sh.ball.canScore = false;
    sh.ball.spin = 0;
    sh.ball.rot = 0;
    sh.ball.wallHit = false;
    sh.aim.charging = false;
    sh.aim.power = 0;
  }

  function setMessage(txt, flash = false) {
    ui.message.textContent = txt;
    ui.message.classList.toggle("flash", flash);
  }

  function refreshScores() {
    if (state.mode === "duel") {
      ui.score.textContent = pad(state.shooters[0].score);
      ui.combo.textContent = pad(state.shooters[1].score);
    } else {
      ui.score.textContent = pad(state.shooters[0].score);
      ui.combo.textContent = "x" + state.shooters[0].combo;
    }
  }

  // ---------------------------------------------------------------
  //  Difficulty: hoop drifts faster as the hottest combo grows
  // ---------------------------------------------------------------
  function updateHoopSpeed() {
    let maxCombo = 1;
    for (const sh of state.shooters) if (sh.combo > maxCombo) maxCombo = sh.combo;
    hoop.speed = maxCombo > 1 ? Math.min(40 + maxCombo * 14, 170) : 0;
  }

  // ---------------------------------------------------------------
  //  Scoring
  // ---------------------------------------------------------------
  function scoreBasket(sh, swish, superShot) {
    let base = swish ? 3 : 2;
    if (superShot) base += 5;            // wall-bank bonus
    const pts = base * sh.combo;

    refreshScores();

    const tag = state.mode === "duel" ? sh.label.replace("PLAYER ", "P") + " " : "";

    if (superShot) {
      superShotFx(sh, pts);
      setMessage(tag + "★ SUPER SHOT! +" + pts, true);
    } else {
      addFloater(hoop.x, hoop.y + 30, "+" + pts, swish ? "#2ff3ff" : sh.color);
      burst(hoop.x, hoop.y + 26, sh.color, swish ? 26 : 16);
      state.shake = swish ? 10 : 6;
      if (swish) { sfx.swish(); setMessage(tag + "SWISH! +" + pts, true); }
      else { sfx.score(); setMessage(tag + "BUCKET! +" + pts); }
    }


    if (sh.combo > 2) { sfx.combo(sh.combo); }
    if (state.mode !== "duel") ui.combo.textContent = "x" + sh.combo;


  }

  // Over-the-top celebration for a wall-banked SUPER SHOT.
  function superShotFx(sh, pts) {
    state.shake = 18;
    state.flash = 0.85;
    // expanding neon shockwave rings from the hoop
    state.rings.push({ x: hoop.x, y: hoop.y + 20, r: 8, vr: 540, life: 0.6, max: 0.6, color: "#ffe24b", w: 6 });
    state.rings.push({ x: hoop.x, y: hoop.y + 20, r: 4, vr: 380, life: 0.7, max: 0.7, color: "#2ff3ff", w: 4 });
    state.rings.push({ x: hoop.x, y: hoop.y + 20, r: 2, vr: 260, life: 0.8, max: 0.8, color: "#ff4fd8", w: 3 });
    // rainbow particle explosion
    const colors = ["#ffe24b", "#2ff3ff", "#ff4fd8", "#ff8a3c", "#fff"];
    for (const c of colors) burst(hoop.x, hoop.y + 24, c, 18);
    // big animated score banner
    addFloater(hoop.x, hoop.y + 4, "SUPER! +" + pts, "#ffe24b", { scale: 1.8, super: true, life: 1.4 });
    sfx.swish();
    sfx.super();
  }

  function missShot(sh) {
    if (sh.combo > 1) {
      sh.combo = 1;
      if (state.mode !== "duel") ui.combo.textContent = "x1";
      updateHoopSpeed();
    }
  }

  // ---------------------------------------------------------------
  //  Per-shooter physics
  // ---------------------------------------------------------------
  function updateShooter(sh, dt) {
    const player = sh.player;
    const ball = sh.ball;
    const aim = sh.aim;
    const keys = sh.keys;

    // horizontal movement
    let move = 0;
    if (keys.left) move -= 1;
    if (keys.right) move += 1;
    if (move !== 0) {
      player.x += move * PLAYER_SPEED * dt;
      player.walk += Math.abs(move) * dt * 10;
    }
    const pMargin = PLAYER_W / 2 + 4;
    player.x = Math.max(pMargin, Math.min(W - pMargin, player.x));
    // always orient toward the basket so shots fly the right way
    player.facing = hoop.x >= player.x ? 1 : -1;

    // shot-arc adjustment
    if (keys.up) aim.angle = Math.min(MAX_ANGLE, aim.angle + AIM_RATE * dt);
    if (keys.down) aim.angle = Math.max(MIN_ANGLE, aim.angle - AIM_RATE * dt);

    // power meter ping-pongs while charging
    if (aim.charging) {
      aim.power += aim.chargeDir * CHARGE_RATE * dt;
      if (aim.power >= 1) { aim.power = 1; aim.chargeDir = -1; }
      if (aim.power <= 0) { aim.power = 0; aim.chargeDir = 1; }
    }

    // ball stays in the player's hands until shot
    if (!ball.flying) {
      const h = handPos(sh);
      ball.x = h.x;
      ball.y = h.y;
      ball.rot += dt * 2;
      return;
    }

    // flying ball physics
    ball.vy += GRAVITY * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.rot += ball.spin * dt * 8;

    // walls — a side-wall touch on a live shot arms the SUPER SHOT bonus
    if (ball.x < BALL_R) { ball.x = BALL_R; ball.vx *= -0.6; if (ball.canScore) ball.wallHit = true; sfx.bounce(); }
    if (ball.x > W - BALL_R) { ball.x = W - BALL_R; ball.vx *= -0.6; if (ball.canScore) ball.wallHit = true; sfx.bounce(); }

    handleRimCollision(ball);
    checkScore(sh);

    // floor
    if (ball.y >= FLOOR_Y - BALL_R) {
      ball.y = FLOOR_Y - BALL_R;
      ball.vy *= -0.5;
      ball.vx *= 0.7;
      if (Math.abs(ball.vy) < 60) {
        // settled -> end of shot
        if (!sh.shotScored) missShot(sh);
        resetBall(sh);
      } else {
        sfx.bounce();
      }
    }
  }

  // ---------------------------------------------------------------
  //  Global update
  // ---------------------------------------------------------------
  function update(dt) {
    // timer
    state.timeLeft -= dt;
    if (state.timeLeft <= 0) {
      state.timeLeft = 0;
      ui.time.textContent = "0";
      endGame();
      return;
    }
    ui.time.textContent = String(Math.ceil(state.timeLeft));

    // moving hoop
    if (hoop.speed > 0) {
      hoop.x += hoop.dir * hoop.speed * dt;
      const margin = hoop.rimW / 2 + 30;
      if (hoop.x < margin) { hoop.x = margin; hoop.dir = 1; }
      if (hoop.x > W - margin) { hoop.x = W - margin; hoop.dir = -1; }
    }

    // each player
    for (const sh of state.shooters) updateShooter(sh, dt);

    // particles
    for (let i = state.particles.length - 1; i >= 0; i--) {
      const p = state.particles[i];
      p.vy += 600 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) state.particles.splice(i, 1);
    }
    // floaters
    for (let i = state.floaters.length - 1; i >= 0; i--) {
      const f = state.floaters[i];
      f.y -= 40 * dt;
      f.life -= dt;
      if (f.life <= 0) state.floaters.splice(i, 1);
    }
    // shockwave rings (super shot fx)
    for (let i = state.rings.length - 1; i >= 0; i--) {
      const r = state.rings[i];
      r.r += r.vr * dt;
      r.life -= dt;
      if (r.life <= 0) state.rings.splice(i, 1);
    }
    // full-screen flash decay (super shot fx)
    if (state.flash > 0) state.flash = Math.max(0, state.flash - dt * 2.2);
    if (state.shake > 0) state.shake = Math.max(0, state.shake - dt * 40);
  }

  // Rim posts act as two small circular colliders
  function rimPosts() {
    const half = hoop.rimW / 2;
    return [
      { x: hoop.x - half, y: hoop.y, r: 5 },
      { x: hoop.x + half, y: hoop.y, r: 5 },
    ];
  }

  function handleRimCollision(ball) {
    for (const post of rimPosts()) {
      const dx = ball.x - post.x;
      const dy = ball.y - post.y;
      const dist = Math.hypot(dx, dy);
      const min = BALL_R + post.r;
      if (dist < min && dist > 0) {
        // push out
        const nx = dx / dist, ny = dy / dist;
        const overlap = min - dist;
        ball.x += nx * overlap;
        ball.y += ny * overlap;
        // reflect velocity
        const dot = ball.vx * nx + ball.vy * ny;
        ball.vx = (ball.vx - 2 * dot * nx) * 0.62;
        ball.vy = (ball.vy - 2 * dot * ny) * 0.62;
        sfx.rim();
      }
    }
    // backboard collision (right-side board behind rim top)
    const boardX = hoop.x + hoop.rimW / 2 + 6;
    const boardTop = hoop.y - hoop.backboardH;
    if (
      ball.x + BALL_R > boardX &&
      ball.x < boardX + 14 &&
      ball.y > boardTop &&
      ball.y < hoop.y &&
      ball.vx > 0
    ) {
      ball.x = boardX - BALL_R;
      ball.vx *= -0.55;
      sfx.bounce();
    }
  }

  function checkScore(sh) {
    const ball = sh.ball;
    if (!ball.canScore) return;
    const half = hoop.rimW / 2 - 4;
    const withinX = ball.x > hoop.x - half && ball.x < hoop.x + half;
    const crossing = ball.vy > 0 &&
      ball.y > hoop.y - 4 && ball.y < hoop.y + 14;
    if (withinX && crossing) {
      ball.canScore = false;
      sh.shotScored = true;
      // swish if it didn't hit rim recently (fast, centered)
      const centered = Math.abs(ball.x - hoop.x) < half * 0.5;
      const swish = centered && Math.abs(ball.vx) < 220;
      // super shot: banked off a side wall before dropping in
      const superShot = ball.wallHit;
      scoreBasket(sh, swish, superShot);
      // let it fall through, dampen a touch
      ball.vx *= 0.3;
    }
  }

  // ---------------------------------------------------------------
  //  Effects helpers
  // ---------------------------------------------------------------
  function burst(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 80 + Math.random() * 220;
      state.particles.push({
        x, y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 60,
        life: 0.5 + Math.random() * 0.5,
        color,
        size: 2 + Math.random() * 3,
      });
    }
  }
  function addFloater(x, y, text, color, opts) {
    opts = opts || {};
    state.floaters.push({
      x, y, text, color,
      life: opts.life || 1.0,
      maxLife: opts.life || 1.0,
      scale: opts.scale || 1,
      super: !!opts.super,
    });
  }

  // ---------------------------------------------------------------
  //  Rendering
  // ---------------------------------------------------------------
  function draw() {
    ctx.clearRect(0, 0, W, H);

    ctx.save();
    if (state.shake > 0) {
      ctx.translate((Math.random() - 0.5) * state.shake, (Math.random() - 0.5) * state.shake);
    }

    drawBackground();
    drawCourt();
    drawHoop();
    for (const sh of state.shooters) drawPlayer(sh);
    for (const sh of state.shooters) drawBall(sh);
    for (const sh of state.shooters) drawAim(sh);
    drawParticles();
    drawRings();
    drawFloaters();

    ctx.restore();

    // full-screen flash sits above everything (super shot fx)
    if (state.flash > 0) {
      ctx.save();
      ctx.globalAlpha = Math.min(0.6, state.flash);
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, W, H);
      ctx.restore();
    }
  }

  function drawBackground() {
    // neon synth grid floor
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, "#0a0820");
    g.addColorStop(1, "#140a2c");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    ctx.strokeStyle = "rgba(47,243,255,0.12)";
    ctx.lineWidth = 1;
    // vertical perspective lines below horizon
    const horizon = FLOOR_Y;
    for (let i = -6; i <= 6; i++) {
      ctx.beginPath();
      ctx.moveTo(W / 2 + i * 24, horizon);
      ctx.lineTo(W / 2 + i * 120, H);
      ctx.stroke();
    }
    for (let j = 0; j < 8; j++) {
      const y = horizon + Math.pow(j / 8, 2) * (H - horizon);
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(W, y);
      ctx.stroke();
    }
  }

  function drawCourt() {
    // floor line
    ctx.strokeStyle = "rgba(255,79,216,0.5)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, FLOOR_Y);
    ctx.lineTo(W, FLOOR_Y);
    ctx.stroke();
  }

  function drawHoop() {
    const half = hoop.rimW / 2;
    const boardX = hoop.x + half + 6;
    const boardTop = hoop.y - hoop.backboardH;

    // backboard
    ctx.fillStyle = "rgba(47,243,255,0.10)";
    ctx.strokeStyle = "#2ff3ff";
    ctx.lineWidth = 3;
    ctx.fillRect(boardX, boardTop, 14, hoop.backboardH);
    ctx.strokeRect(boardX, boardTop, 14, hoop.backboardH);
    // board square
    ctx.strokeStyle = "rgba(255,226,75,0.7)";
    ctx.lineWidth = 2;
    ctx.strokeRect(boardX + 3, hoop.y - 46, 8, 30);

    // pole from board to floor
    ctx.strokeStyle = "rgba(170,160,220,0.5)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(boardX + 7, boardTop);
    ctx.lineTo(boardX + 7, FLOOR_Y);
    ctx.stroke();

    // net (animated trapezoid strings)
    const netTop = hoop.y + 2;
    const netH = 34;
    ctx.strokeStyle = "rgba(255,255,255,0.55)";
    ctx.lineWidth = 1.4;
    const segs = 7;
    for (let i = 0; i <= segs; i++) {
      const tx = hoop.x - half + (hoop.rimW * i) / segs;
      const bx = hoop.x - half * 0.5 + (hoop.rimW * 0.5 * i) / segs;
      ctx.beginPath();
      ctx.moveTo(tx, netTop);
      ctx.lineTo(bx, netTop + netH);
      ctx.stroke();
    }
    // cross net
    for (let r = 0; r < 3; r++) {
      const yy = netTop + (netH * (r + 1)) / 4;
      const shrink = (half - half * 0.5) * ((r + 1) / 4);
      ctx.beginPath();
      ctx.moveTo(hoop.x - half + shrink, yy);
      ctx.lineTo(hoop.x + half - shrink, yy);
      ctx.stroke();
    }

    // rim (glowing orange)
    ctx.save();
    ctx.shadowColor = "#ff8a3c";
    ctx.shadowBlur = 16;
    ctx.strokeStyle = "#ff8a3c";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(hoop.x - half, hoop.y);
    ctx.lineTo(hoop.x + half, hoop.y);
    ctx.stroke();
    // rim posts
    for (const post of rimPosts()) {
      ctx.beginPath();
      ctx.arc(post.x, post.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = "#ffd24b";
      ctx.fill();
    }
    ctx.restore();
  }

  function drawBall(sh) {
    const ball = sh.ball;
    ctx.save();
    ctx.translate(ball.x, ball.y);
    ctx.rotate(ball.rot);
    // glow
    ctx.shadowColor = "#ff8a3c";
    ctx.shadowBlur = 14;
    const grad = ctx.createRadialGradient(-5, -5, 3, 0, 0, BALL_R);
    grad.addColorStop(0, "#ffb066");
    grad.addColorStop(1, "#e8631f");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, BALL_R, 0, Math.PI * 2);
    ctx.fill();
    // seams
    ctx.shadowBlur = 0;
    ctx.strokeStyle = "#3a1404";
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(0, 0, BALL_R, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-BALL_R, 0); ctx.lineTo(BALL_R, 0);
    ctx.moveTo(0, -BALL_R); ctx.lineTo(0, BALL_R);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(-BALL_R, 0, BALL_R * 1.1, -0.6, 0.6);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(BALL_R, 0, BALL_R * 1.1, Math.PI - 0.6, Math.PI + 0.6);
    ctx.stroke();
    ctx.restore();
  }

  function drawPlayer(sh) {
    const player = sh.player;
    const ball = sh.ball;
    const keys = sh.keys;
    const cx = player.x;
    const feet = player.y;
    const top = feet - PLAYER_H;       // shoulders/neck height
    const f = player.facing;
    const moving = keys.left || keys.right;
    const legSwing = moving ? Math.sin(player.walk) * 7 : 0;

    ctx.save();
    ctx.strokeStyle = sh.color;
    ctx.fillStyle = sh.color;
    ctx.lineWidth = 4;
    ctx.lineCap = "round";
    ctx.shadowColor = sh.color;
    ctx.shadowBlur = 10;

    // legs
    ctx.beginPath();
    ctx.moveTo(cx, top + 30);
    ctx.lineTo(cx - 8 + legSwing, feet);
    ctx.moveTo(cx, top + 30);
    ctx.lineTo(cx + 8 - legSwing, feet);
    ctx.stroke();

    // torso
    ctx.beginPath();
    ctx.moveTo(cx, top + 12);
    ctx.lineTo(cx, top + 30);
    ctx.stroke();

    // arms raised toward the ball (both up when holding, shooting pose)
    const armUp = !ball.flying;
    ctx.beginPath();
    ctx.moveTo(cx, top + 16);
    if (armUp) {
      ctx.lineTo(cx + f * 8, top - 8);
    } else {
      ctx.lineTo(cx + f * 14, top + 6);
    }
    ctx.moveTo(cx, top + 16);
    ctx.lineTo(cx - f * 10, top + 4);
    ctx.stroke();

    // head
    ctx.beginPath();
    ctx.arc(cx, top + 4, 8, 0, Math.PI * 2);
    ctx.fillStyle = "#0a0820";
    ctx.fill();
    ctx.stroke();

    // player tag (only in duel, so you can tell who's who)
    if (state.mode === "duel") {
      ctx.shadowBlur = 0;
      ctx.fillStyle = sh.color;
      ctx.font = "bold 11px 'Courier New', monospace";
      ctx.textAlign = "center";
      ctx.fillText(sh.label.replace("PLAYER ", "P"), cx, feet + 16);
      ctx.textAlign = "start";
    }
    ctx.restore();
  }

  function drawAim(sh) {
    const player = sh.player;
    const ball = sh.ball;
    const aim = sh.aim;
    if (ball.flying || !state.running) return;

    const start = handPos(sh);
    const f = player.facing;
    const angle = aim.angle;
    // direction unit vector (up is negative y)
    const dx = Math.cos(angle) * f;
    const dy = -Math.sin(angle);

    // --- aim arrow showing arc direction ---
    const len = 46;
    const ex = start.x + dx * len;
    const ey = start.y + dy * len;
    ctx.save();
    ctx.strokeStyle = "#ffe24b";
    ctx.fillStyle = "#ffe24b";
    ctx.lineWidth = 3;
    ctx.setLineDash([6, 5]);
    ctx.beginPath();
    ctx.moveTo(start.x, start.y);
    ctx.lineTo(ex, ey);
    ctx.stroke();
    ctx.setLineDash([]);
    // arrowhead
    const ah = Math.atan2(dy, dx);
    ctx.beginPath();
    ctx.moveTo(ex, ey);
    ctx.lineTo(ex - Math.cos(ah - 0.4) * 12, ey - Math.sin(ah - 0.4) * 12);
    ctx.lineTo(ex - Math.cos(ah + 0.4) * 12, ey - Math.sin(ah + 0.4) * 12);
    ctx.closePath();
    ctx.fill();

    // --- predicted trajectory while charging ---
    if (aim.charging) {
      const speed = MIN_SHOT_V + (MAX_SHOT_V - MIN_SHOT_V) * aim.power;
      let px = start.x, py = start.y;
      let pvx = dx * speed, pvy = dy * speed;
      const step = 1 / 50;
      const t = aim.power;
      const col = t < 0.5 ? "#2ff3ff" : t < 0.8 ? "#ffe24b" : "#ff4fd8";
      ctx.fillStyle = col;
      for (let i = 0; i < 45; i++) {
        pvy += GRAVITY * step;
        px += pvx * step;
        py += pvy * step;
        if (py > FLOOR_Y || px < 0 || px > W) break;
        if (i % 2 === 0) {
          ctx.globalAlpha = 1 - i / 45;
          ctx.beginPath();
          ctx.arc(px, py, 3, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      ctx.globalAlpha = 1;

      // --- power meter above the player ---
      const mw = 70, mh = 8;
      const mx = player.x - mw / 2;
      const my = player.y - PLAYER_H - 30;
      ctx.strokeStyle = "rgba(255,255,255,0.7)";
      ctx.lineWidth = 2;
      ctx.strokeRect(mx, my, mw, mh);
      ctx.fillStyle = col;
      ctx.fillRect(mx + 1, my + 1, (mw - 2) * aim.power, mh - 2);
    }
    ctx.restore();
  }

  function drawParticles() {
    for (const p of state.particles) {
      ctx.globalAlpha = Math.max(0, p.life);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x, p.y, p.size, p.size);
    }
    ctx.globalAlpha = 1;
  }

  function drawRings() {
    for (const r of state.rings) {
      const a = Math.max(0, r.life / r.max);
      ctx.globalAlpha = a;
      ctx.strokeStyle = r.color;
      ctx.lineWidth = r.w * a + 1;
      ctx.shadowColor = r.color;
      ctx.shadowBlur = 18;
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 1;
  }

  function drawFloaters() {
    ctx.textAlign = "center";
    for (const f of state.floaters) {
      const a = Math.max(0, f.life);
      ctx.globalAlpha = a;
      let color = f.color;
      if (f.super) {
        // cycle through neon hues for a rainbow shimmer
        const hue = (performance.now() / 4) % 360;
        color = "hsl(" + hue + ", 100%, 65%)";
      }
      // pop-in then settle: scale eases up over the floater's life
      const grow = f.super ? 1 + (1 - a / f.maxLife) * 0.25 : 1;
      const size = Math.round(26 * f.scale * grow);
      ctx.fillStyle = color;
      ctx.font = "bold " + size + "px 'Courier New', monospace";
      ctx.shadowColor = color;
      ctx.shadowBlur = f.super ? 20 : 10;
      ctx.fillText(f.text, f.x, f.y);
    }
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 1;
    ctx.textAlign = "start";
  }

  // ---------------------------------------------------------------
  //  Helpers
  // ---------------------------------------------------------------
  function pad(n) { return String(n).padStart(3, "0"); }

  // ---------------------------------------------------------------
  //  Main loop
  // ---------------------------------------------------------------
function advanceToClock(){if(run&&!run.finished&&!failed){const target=Math.min(HOOPS_TICKS,Math.max(0,Math.floor((serverNow()-run.startedAt)*HOOPS_HZ/1000)));while(sim.tick<target&&sim.state.running)sim.step();ui.time.textContent=String(Math.ceil(sim.state.timeLeft));refreshScores();}}
function loop(now){if(disposed)return;const dt=Math.min(.033,(now-lastFrame)/1000)||0;lastFrame=now;advanceToClock();
 for(const p of state.particles){p.vy+=600*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.life-=dt;}state.particles=state.particles.filter(p=>p.life>0);for(const f of state.floaters){f.y-=40*dt;f.life-=dt;}state.floaters=state.floaters.filter(f=>f.life>0);for(const r of state.rings){r.r+=r.vr*dt;r.life-=dt;}state.rings=state.rings.filter(r=>r.life>0);state.flash=Math.max(0,state.flash-dt*2.2);state.shake=Math.max(0,state.shake-dt*40);draw();raf=globalThis.requestAnimationFrame(loop);}

  // initial idle ball draw (single player) + start loop
  ui.best.textContent = pad(best);



 function setState(m){if(disposed||!m)return;if(m.error){pendingStart=false;failed=true;state.running=false;setMessage(m.error+' Close and retry. Previous best is safe.');return;}if(Number.isFinite(m.serverTime))clock={server:m.serverTime,local:performance.now()};if(Number.isInteger(m.best)){best=m.best;ui.best.textContent=pad(best);}if(Array.isArray(m.rows))document.getElementById('board').textContent='TOWN HIGH SCORES\n'+m.rows.slice(0,10).map(r=>r.rank+'. '+r.displayName+'  '+r.score).join('\n');
 if(m.run===null){run=null;state.running=false;setMessage('Round ended. Close and play again.');return;}
 if(m.run&&m.action==='start'){pendingStart=false;run=m.run;seq=0;finishSent=false;failed=false;sim=createHoopsSimulation({event:onSimulationEvent});state=sim.state;hoop=sim.hoop;keyMap=buildKeyMap('solo');configureHud('solo');ui.startScreen.classList.add('hidden');ui.overScreen.classList.add('hidden');ui.time.textContent='60';showTouchControls(true);setMessage('60 seconds. Help does not pause the clock.');}
 if(m.run&&m.action==='finish'){run=m.run;state.running=false;ui.finalScore.textContent=pad(run.score);setMessage('Verified score: '+run.score+'  -  no stars spent or earned');ui.overScreen.classList.remove('hidden');}}
 function fit(){const r=view.getBoundingClientRect?.();if(!r)return;const width=Math.max(60,Math.min(r.width-20,(r.height-120)*.75,480));root.querySelector('.crt').style.width=(width+16)+'px';}
 return {view,mount(){fit();if(globalThis.ResizeObserver){observer=new globalThis.ResizeObserver(fit);observer.observe(view);}raf=globalThis.requestAnimationFrame(loop);send({type:'hoops88',action:'leaderboard'});},setState,input(action,down){recordInput(action==='action'?'shoot':action,down);},pause(value){if(disposed||!!value===paused)return;if(value&&!paused)for(const action of ['left','right','up','down','shoot'])recordInput(action,false);paused=!!value;if(paused)audioCtx?.suspend?.().catch(()=>{});else if(!soundMuted)audioCtx?.resume?.().catch(()=>{});},setMuted(value){soundMuted=!!value;if(soundMuted)audioCtx?.suspend?.().catch(()=>{});else if(!paused&&!disposed)audioCtx?.resume?.().catch(()=>{});},status:()=>({message:failed?'Round could not be verified. Close and retry.':'Solo high-score challenge. Help does not pause the 60-second clock.'}),dispose(){disposed=true;observer?.disconnect();globalThis.cancelAnimationFrame(raf);for(const id of timers)globalThis.clearTimeout(id);audioCtx?.close?.();send({type:'hoops88',action:'leave'});view.remove();}};
}
