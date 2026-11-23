// Derived from HOOPS '88, MIT copyright 2026 Carlos Sardo and Eduardo Sardo.
// See vendor/hoops88/LICENSE. Shared fixed-step SOLO rules, no DOM/network/storage.
export const HOOPS_HZ=120,HOOPS_TICKS=7200;
export const HOOPS_ACTIONS=Object.freeze(['left','right','up','down','shoot']);
export function createHoopsSimulation({event=()=>{}}={}){
 const W=480,H=640,GRAVITY=1500,BALL_R=18,ROUND_TIME=60,FLOOR_Y=H-70,PLAYER_W=26,PLAYER_H=58,PLAYER_SPEED=240,MAX_SHOT_V=1500,MIN_SHOT_V=320,MIN_ANGLE=25*Math.PI/180,MAX_ANGLE=82*Math.PI/180,AIM_RATE=1.4,CHARGE_RATE=1.6,DEG=Math.PI/180;
 const state={running:true,mode:'solo',timeLeft:60,particles:[],floaters:[],rings:[],flash:0,shake:0,shooters:[]};
 const hoop={x:W/2,y:170,rimW:90,dir:1,speed:0,backboardH:110};
 const ui={combo:{textContent:''}};
 const sfx=new Proxy({}, {get:(_,name)=>(...args)=>event({type:'sound',name,args})});
 let tick=0;
 function scoreBasket(sh,swish,superShot){let base=swish?3:2;if(superShot)base+=5;const pts=base*sh.combo;sh.score+=pts;event({type:'basket',pts,swish,superShot});sh.combo++;updateHoopSpeed();}
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
  function updateHoopSpeed() {
    let maxCombo = 1;
    for (const sh of state.shooters) if (sh.combo > maxCombo) maxCombo = sh.combo;
    hoop.speed = maxCombo > 1 ? Math.min(40 + maxCombo * 14, 170) : 0;
  }
  function missShot(sh) {
    if (sh.combo > 1) {
      sh.combo = 1;
      if (state.mode !== "duel") ui.combo.textContent = "x1";
      updateHoopSpeed();
    }
  }
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
 state.shooters=[createShooter({id:0,label:'PLAYER 1',color:'#2ff3ff',startX:W/2,facing:1})];
 function input(action,down){if(!HOOPS_ACTIONS.includes(action)||typeof down!=='boolean'||!state.running)return false;const sh=state.shooters[0];if(!!sh.keys[action]===down)return false;sh.keys[action]=down;if(action==='shoot'){if(down&&!sh.ball.flying&&!sh.aim.charging){sh.aim.charging=true;sh.aim.power=0;sh.aim.chargeDir=1;}else if(!down&&sh.aim.charging){sh.aim.charging=false;if(!sh.ball.flying){const speed=MIN_SHOT_V+(MAX_SHOT_V-MIN_SHOT_V)*sh.aim.power;Object.assign(sh.ball,{vx:Math.cos(sh.aim.angle)*speed*sh.player.facing,vy:-Math.sin(sh.aim.angle)*speed,flying:true,canScore:true,spin:Math.cos(sh.aim.angle)*speed*sh.player.facing*.01});sh.shotScored=false;sh.aim.power=0;event({type:'sound',name:'shoot',args:[]});}}}return true;}
 function step(){if(!state.running)return;tick++;state.timeLeft=Math.max(0,(HOOPS_TICKS-tick)/HOOPS_HZ);if(tick>=HOOPS_TICKS){state.running=false;event({type:'end',score:state.shooters[0].score});return;}const dt=1/HOOPS_HZ;if(hoop.speed>0){hoop.x+=hoop.dir*hoop.speed*dt;const margin=hoop.rimW/2+30;if(hoop.x<margin){hoop.x=margin;hoop.dir=1;}if(hoop.x>W-margin){hoop.x=W-margin;hoop.dir=-1;}}updateShooter(state.shooters[0],dt);}
 return {state,hoop,input,step,get tick(){return tick;},get score(){return state.shooters[0].score;}};
}
export function replayHoops(events){const sim=createHoopsSimulation();let i=0;for(let tick=0;tick<HOOPS_TICKS;tick++){while(i<events.length&&events[i].tick===tick){const e=events[i++];sim.input(e.action,e.down);}sim.step();}return sim.score;}
