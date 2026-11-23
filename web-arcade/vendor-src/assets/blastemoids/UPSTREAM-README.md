# BLASTEMOIDS — Wireframe Asteroids HTML Game Template

A complete asteroids-style space shooter in a single self-contained
HTML file. Thrust, rotate, fire. The void has no friction. Hit a rock,
it splits. Hit the smallest rocks, they vanish. Clear the wave.

Pure black background, wireframe-only rendering, phosphor green glow,
scanline overlay. The CRT terminal aesthetic isn't a filter on top of
a normal game — it's how everything is rendered. No filled shapes, no
sprites. Stroked vectors all the way down.

This is the only template in the line built around **inertia-based
movement** — momentum persists, drift is a feature, planning is
required. And the only one with a deliberate vector / CRT aesthetic.

Drop `index.html` on any web host and you're live. No build tools, no
dependencies, no image or sound assets to ship.

---

## Highlights

- **Inertia physics** — thrust adds velocity, the void doesn't take
  it back. Plan your turns. Counter-thrust to stop. The hardest
  control style in any of the templates so far, and the most
  satisfying when you nail it.
- **Wireframe rendering throughout** — the ship is a stroked
  triangle, asteroids are stroked irregular polygons, the UFO is a
  stroked saucer, bullets are bright dots, particles are line
  fragments. Nothing is filled. The aesthetic IS the rendering
  technique.
- **Phosphor glow** — every line gets a colored shadow blur,
  configurable from off to full. Combined with the scanline overlay,
  it sells the CRT terminal feeling.
- **Scanline overlay** — repeating-gradient CSS layer with
  `mix-blend-mode: multiply` over the canvas. Toggleable. Cheap to
  render — no per-frame cost.
- **Wraparound everything** — ship, bullets, asteroids, particles
  all wrap at the screen edges. Collision uses *wrapped* delta
  vectors so a near-edge ship can be hit by an off-screen-but-wrapped
  asteroid correctly.
- **Asteroid splitting chain** — large → 2 medium → 2 small (so 4
  smalls per large). Three size tiers, each with its own vertex count,
  speed range, and point value. Total wave-clearing work scales
  smoothly with level.
- **Random vertex generation** — each asteroid gets unique jagged
  vertices generated at construction. No two look identical.
- **Four enemy types unlocked over waves** — instead of one UFO, you
  fight a growing roster:
  - **UFO** (wave 1+) — drifts across, jukes, fires aimed/spread/burst/twin/wide-cone (800 pts)
  - **Sniper** (wave 3+) — small dart, telegraphs each shot with a charge-up glow, then unleashes fast precise patterns (1,200 pts)
  - **Spinner** (wave 5+) — rotates and emits radial bullet patterns — stars, crosses, spirals, 7-bullet rings — with no aiming (1,500 pts)
  - **Hunter** (wave 8+) — accelerates toward the player, fires rapid twin and cone shots when close (1,800 pts)
- **Random firing patterns** — every shot is one of the enemy's pool of
  named patterns (`aimed`, `spread`, `burst`, `twin`, `wideCone`, `star`,
  `cross`, `spiral`, `radialOdd`, `aimedFast`). Easy to extend with new
  patterns — see `FiringPatterns` in section 13.
- **Random bullet variants** — each enemy bullet is randomly `standard`
  (~70%), `heavy` (slower, bigger, ~12%), `fast` (faster, smaller, ~12%),
  or `wavy` (sine-wave path, ~6%). Tunable in `CONFIG.hostileBullet`.
- **Spawn rate scales with level** — interval shortens and the cap on
  concurrent enemies grows up to 4 at high waves.
- **Hyperspace teleport** — classic asteroids feature. Random teleport
  with brief invulnerability, but every use carries a 1-in-12 chance
  of instant death. True panic button.
- **Engine particles** — tiny dots stream backward from the ship when
  thrusting, with velocity inheritance from the ship's motion. Sells
  the inertia feeling visually.
- **Line-fragment debris** — when something explodes, line segments
  fly outward, rotating and fading. Looks like the wireframe shape
  shattering into vectors.
- **Persistent thrust audio** — a single sawtooth oscillator runs
  through a low-pass filter while the player thrusts, fades in and
  out. Distinct from one-shot SFX and very satisfying.
- **AAA initials high score** — top 8, tracking score AND wave
  reached (so you can see whether the run was long or efficient).
- **Stats screen** — best score, best wave, runs, total waves,
  rocks destroyed by size, UFOs killed, shots fired, deaths, extra
  lives earned, hyperspaces used, hyperspace deaths.
- **Extra lives** every 10,000 points (cap 9), with arpeggio audio
  and a celebratory popup.
- **Wave clear bonus** — `level × 250` points awarded on clear.
- **Mobile virtual buttons** — five circular hit zones (rotate-L,
  rotate-R, thrust, fire, hyperspace) drawn directly on the canvas.
  Multi-touch supported (rotate AND thrust simultaneously).
  **Auto-hidden on desktop** via `(pointer: coarse)` detection — they
  only appear on touch devices. Still toggleable in settings if you
  want to test the touch UI from a desktop browser.
- **Full input** — keyboard, gamepad (analog stick + d-pad + face
  buttons), virtual canvas buttons. Discrete events for fire / pause
  / hyperspace; continuous polling for rotate / thrust.

---

## Controls

| Action      | Keyboard       | Gamepad         | Mobile           |
|-------------|----------------|-----------------|------------------|
| Rotate      | ← → / A D      | Stick / D-pad   | Tap < or >       |
| Thrust      | ↑ / W          | Up D-pad / A    | Hold ^ button    |
| Fire        | Space          | RT / X          | Tap F button     |
| Hyperspace  | Shift / H      | LT / B          | Tap H button     |
| Pause       | P / Esc        | Start           | Pause icon       |

---

## Architecture

The whole game is one HTML file with the JS divided into 16 numbered
sections:

| # | Section | What lives here |
|---|---------|-----------------|
| 1 | `CONFIG` | World dims, ship/bullet/asteroid/UFO defs, audio levels |
| 2 | Utilities | `clamp`, `lerp`, `wrap`, `wrapDelta`, pentatonic, glow helper |
| 3 | Audio | Procedural Web Audio with persistent thrust oscillator |
| 4 | Settings | Versioned localStorage |
| 5 | Stats | Versioned localStorage |
| 6 | High Scores | Top 8 with 3-letter initials |
| 7 | Input | Keyboard, gamepad, virtual-button hit testing |
| 8 | Pool + glow helper | Reusable particle pool, `withGlow` wrapper |
| 9 | `Particles` | Dot trails (engine) and line fragments (debris) |
| 10 | `Bullet` class | Position, velocity, lifetime, hostile flag |
| 11 | `Ship` class | Rotate, thrust, fire, hyperspace, draw |
| 12 | `Asteroid` class | Random vertex generation, split logic |
| 13 | Enemies + Firing Patterns | `Enemy` base, `UFO` / `Sniper` / `Spinner` / `Hunter` subclasses, the `FiringPatterns` table, `pickEnemyType()` weighted spawner |
| 14 | `VirtualControls` | Renders the 5 mobile hit zones |
| 15 | `Game` class | State machine, collision, wave management, undo |
| 16 | UI + bootstrap | Overlays, HSEntry, button wiring, rAF loop |

Storage keys (versioned):

- `blastemoids_settings_v1`
- `blastemoids_stats_v1`
- `blastemoids_highscores_v1`

### Inertia physics

The ship's velocity persists with a **very gentle** exponential drag
(0.35 per second). This means without thrust, the ship slows by ~30%
per second — slow enough to feel like real space momentum, fast enough
that you don't drift forever after a single touch. Tune
`CONFIG.ship.drag` if you want pure-Newtonian space (`drag: 0`) or
arcade-feel friction (`drag: 1.5`).

`CONFIG.ship.maxSpeed = 320` clamps the velocity magnitude so the ship
doesn't outrun bullets or game logic. `thrust = 220 px/s²` reaches max
speed in roughly 1.5 seconds of continuous thrust from rest.

### Wraparound

Every moving object calls `wrap(this)` at the end of its update.
Collisions use `wrapDelta(ax, ay, bx, by)` which returns the shortest
delta accounting for the world being a torus. This way a ship at x=10
and an asteroid at x=790 are correctly seen as 20 pixels apart, not
780 — preventing the off-by-screen-width edge case.

The UFO does NOT wrap — it crosses the screen and despawns. This makes
its threat finite and gives the player a clear "evade until it
leaves" option.

### Asteroid generation

Each asteroid generates `vertexCount` vertices around a base radius,
with each vertex's distance from center jittered by up to
`vertexJitter = 32%`. The result is a unique jagged polygon every
time. Vertices are stored relative to the asteroid's local frame and
rotated as a whole — so they never reshape, just spin.

### State machine

```
MENU → PLAYING: Begin run
PLAYING → RESPAWN: Ship destroyed, lives > 0
RESPAWN → PLAYING: Safe respawn (no asteroid near center)
PLAYING → LEVEL_TRANSITION: All asteroids destroyed
LEVEL_TRANSITION → PLAYING: 1.8s pause, next wave spawns
PLAYING → GAME_OVER: Lives reached zero
GAME_OVER → HS_ENTRY (if score qualifies) → GAME_OVER
PLAYING ↔ PAUSED (Esc / P / Start button)
```

The respawn logic checks for asteroids within an 80-pixel radius of
the spawn point. If any are too close, it waits another 0.3 seconds
before checking again — preventing instant-death respawns.

### Audio architecture

Most SFX are one-shot tones, sweeps, or filtered noise. The thrust
sound is special — a persistent oscillator created when thrust starts
and faded out when thrust ends. This avoids the popping that comes
from re-creating an oscillator every frame. See `Audio.startThrust()`
and `Audio.stopThrust()`.

The level-clear arpeggio uses pentatonic note picking (D-minor scale)
for a satisfying ascending feel.

---

## Customizing

### Re-skin to a different palette

Change four colors in `CONFIG`:

```js
ship: { color: '#00ff66' },       // ship + ship bullets + engine particles
asteroid: { color: '#00ff66' },   // asteroids + debris
ufo: { color: '#ffaa00' },        // UFO + UFO bullets
bullet: { color: '#a0ff80' },     // ship bullet brightness
```

And the CSS `:root` variables for HUD colors. Try amber phosphor
(`#ffb000` everywhere), classic green (`#33ff33`), or a non-CRT
palette like white-on-black for a pure vector look.

### Slow / fast game

`CONFIG.ship.thrust`, `CONFIG.ship.maxSpeed`, `CONFIG.ship.drag` —
tune the trio together. Higher thrust + higher max speed + lower drag
= aggressive twitchy game. Lower everything = floaty space.

### More / fewer asteroids per wave

```js
level: { asteroidsBase: 4, asteroidsPerLevel: 1, asteroidsMax: 10 }
```

Wave 1 starts with 4 large asteroids; wave N starts with 4 + (N-1)
large, capped at 10. Each large splits into 2 medium → 2 small, so
wave N has up to 10 × 7 = 70 destroy events.

### Enemy frequency, mix, and difficulty

`CONFIG.enemy.spawnIntervalBase` and `spawnIntervalMin` are the easy and
hard endpoints; the actual interval lerps between them over the first
`spawnIntervalRampLevels` waves. `maxConcurrentBase` +
`maxConcurrentPerLevel` (capped at `maxConcurrentCap`) controls how many
enemies can be on screen at once.

Each enemy block (`CONFIG.enemy.ufo`, `.sniper`, `.spinner`, `.hunter`)
has:
- `minLevel` — earliest wave it can spawn on
- `weight` — relative spawn chance among unlocked enemies
- `fireInterval` — seconds between attempts to fire
- `patterns` — array of pattern names from `FiringPatterns` it picks from
- `accuracy` — radians of random aim error (0 for no aim error, only
  applies to aiming patterns)

### Add a new firing pattern

Patterns are functions in the `FiringPatterns` table (Section 13). Each
takes `(enemy, ship, ctx)` and uses `ctx.add(bullet)` for immediate
shots and `ctx.schedule(delaySeconds, () => bullet)` for sequential
ones. Add your pattern to the table, then add its name to one or more
enemies' `patterns` arrays in CONFIG.

### Add a new enemy type

1. Add a config block under `CONFIG.enemy.<name>` with `minLevel`,
   `weight`, dimensions, color, points, fire interval, and patterns.
2. Subclass `Enemy` (Section 13) — implement `update(dt, ship, addBullet)`
   for movement, plus a `draw(g)` for the silhouette.
3. Register it in the `ENEMY_CLASSES` table at the bottom of Section 13.
4. That's it — `pickEnemyType()` and the spawner pick it up automatically.

### Disable hyperspace (or make it safe)

Set `CONFIG.hyperspace.deathChance = 0` for a safe panic button,
or remove the hyperspace handling entirely from `Game.triggerHyperspace`
and the controls.

### Reskin Ideas

- **White-on-black vector** — change all colors to `#ffffff`.
  Drop scanlines. You get a closer match to the original arcade
  asteroids look.
- **Amber phosphor** — change `:root` `--phosphor` to `#ffb000`,
  ship/asteroid/UFO colors to match. Looks like an old amber CRT.
- **Cyan terminal** — `#00ffff` everywhere. Different vibe, very
  Tron / Star Trek.
- **Doomsday** — `#ff3030` everywhere. Threatening, alarm-clock CRT.

---

## Tested

- Chrome / Edge / Firefox / Safari desktop, Chrome Android, Safari iOS
- Mobile portrait + landscape — virtual buttons reposition automatically
- Multi-touch — rotate AND thrust at the same time works on iOS Safari
- Xbox Series controller, PS5 DualSense — analog + d-pad + buttons all map
- Wraparound collision verified with wrapDelta-based circle test
- Asteroid splitting chain verified across all three size tiers
- UFO juke + aim-and-fire verified
- Hyperspace death chance verified (1-in-12 over 100 trials = ~8 deaths)
- Respawn safety check verified — never respawns into an asteroid
- Lives counter capped at 9, extra-life threshold doubles per earn
- Pause / resume preserves all entity state and audio thrust state
- Glow / scanlines / particles all toggleable individually
- 8-position high score table, score AND wave persisted

---

## Itch.io Listing Cheatsheet

- **Classification**: Game assets → Templates → HTML
- **Pricing**: pay-what-you-want, $0 minimum, $2 suggested
- **Embed**: 800 × 600 landscape, "Click to launch in fullscreen" on
- **Tags**: `template`, `html5`, `source-code`, `arcade`, `asteroids`,
  `space`, `vector`, `retro`, `crt`, `wireframe`, `mobile`, `free`,
  `javascript`
- **AI disclosure**: code/text only
- **Custom noun**: "template"
- **Visibility**: keep as draft until your cover image and screenshots
  are uploaded

The zip contains `index.html`, `README.md`, and `LICENSE.txt` — all
itch needs.

---

## License

MIT. Use in commercial and non-commercial projects, including paid
games. See `LICENSE.txt`.

If this template helps you, a tip on the original itch.io page is
appreciated but never required.

---

## Tip URL

Open Section 1 of `index.html` and replace `CONFIG.tipURL` with your
own itch.io page URL. The "// tip on itch.io" link in the menu uses
this value.

---

Thrust. Rotate. Fire. The void is patient.
