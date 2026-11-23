// src/shared/constants.ts
var W = 2e3;
var H = 1125;
/** Units per second. */
var PUCK_MAX_SPEED = 2400;
/** Fast enough to keep up with a quick mouse flick (about 3000 px/s on a laptop-sized table). */
var PADDLE_MAX_SPEED = 7200;
/** Ticks a genie's spell paralyses the paddle that shot the puck at it (5 s). */
var STUN = 1200;
/** Default match rules. */
var RULES = {
	arena: [
		"ice",
		"sea",
		"desert"
	],
	rounds: 3,
	goals: 5,
	hit: 1,
	goal: 20,
	ownGoal: 10,
	roundWin: 10,
	matchWin: 30,
	headStart: 1,
	readySec: 3,
	breakSec: 3,
	endSec: 15
};
// src/shared/arena.ts
/**
* Icebergs (vortices at sea, whirlwinds in the desert) of the left half, above and below its serve
* spot, as seed 0 places them: [x, r, y]. The right half mirrors.
*/
var BERGS = [[
	450,
	72,
	270
], [
	460,
	62,
	870
]];
/**
* Where a seed may place one, in front of the left goal, top half: a grid 75 units apart within a
* quarter of the rink from the goal line, the cells that keep every guarantee (see the top). The
* bottom half and the right side mirror it.
*/
var CELLS = [
	[225, 225],
	[300, 225],
	[375, 225],
	[450, 225],
	[300, 300],
	[375, 300],
	[450, 300]
];
/** Penguin radius, a genie's too. */
var PR = 40;
/** Shark radius: big, as wide as the gaps it swings across allow (see top). */
var SR = 44;
/**
* Penguin lanes, [x, phase, zig-zag sign]: a pair 280 units off the centre line, in step, and one
* on the line, half a period apart. At t = 0 the pair is at the bottom board, the middle one at
* the top board. The pair's sharks zig-zag in mirror (opposite signs).
*/
var LANES = [
	[
		W / 2 - 280,
		.5,
		1
	],
	[
		W / 2,
		0,
		1
	],
	[
		W / 2 + 280,
		.5,
		-1
	]
];
/** Ticks for a penguin to slide there and back: 2048 divides 65536, 8.5 s at 240 Hz. */
var PERIOD = 2048;
/** Sideways speed of a shark, units per second: 4 · ZA per back-and-forth, about 197. */
var ZV = 403200 / PERIOD;
var WANDER = 1024;
/** Obstacles kept for a count of 2 to 7 (see obstacles): bit i keeps index i of the full layout. */
var MASKS = [
	3,
	35,
	83,
	115,
	95,
	127
];
/**
* A share in [0, 1) for draw i of a seed (pair i of icebergs, a genie's waypoint, a whirlwind's
* hold): murmur3's integer finalizer, so host and clients draw the same, with no shared random
* state.
*/
var draw = (seed, i) => {
	let h = seed * 2 + i;
	h = Math.imul(h ^ h >>> 16, 2246822507);
	h = Math.imul(h ^ h >>> 13, 3266489909);
	return ((h ^ h >>> 16) >>> 0) / 2 ** 32;
};
/**
* Icebergs, vortices and whirlwinds: they break after ICEBERG_HP hits. Penguins move, go on one.
* Sharks and genies move and never go: a shark eats the puck, a genie casts a spell.
*/
var fixed = (o) => [
	"iceberg",
	"vortex",
	"whirlwind"
].includes(o.kind);
/**
* Sense a whirlwind spins the puck in, on a rink of that size: 1 clockwise on screen (y down), left
* of the centre line, -1 counter-clockwise on the right. Mirrored whirlwinds spin in mirror.
*/
var swirl = (o, size = 1) => o.x < 2e3 * size / 2 ? 1 : -1;
/**
* The obstacles of an arena at tick t: icebergs (vortices, whirlwinds) first, fixed, then penguins
* (sharks, genies), moving. 'classic' has none. t may be fractional, for drawing between steps.
* The motion repeats with a period that divides 65536 ticks, so the wrap of the u16 snapshot tick
* is seamless. vx and vy are the velocity, units per second (a shark's heading). The layout is
* mirror-symmetric across the centre line (the centre shark over time): neither team is favoured.
*
* The layout is drawn for the base rink and scaled by `size` (positions, radii, speeds: the
* crossing time stays the same). `count` picks which obstacles stay, in the order above and
* mirror-symmetric at every count: top icebergs (2), centre penguin (3), side penguins instead of
* the centre one (4), all three penguins (5), bottom icebergs too (6), everything (7). Same slots
* at sea and in the desert. Indices follow the returned order and are stable for a given count.
* Fresh objects every call.
*
* `seed` (an integer, picked by the host each round) places the icebergs (vortices, whirlwinds),
* each on a cell of CELLS in its half, and draws the genies' waypoints; 0 keeps the fixed layout
* of the icebergs (BERGS). `times[i]` (ObstacleState.times): each time iceberg i comes back, it
* takes another cell of its half. `lags[i]`: ticks genie i floats behind t (its spells, see
* ObstacleState.lag).
*/
var obstacles = (arena, t, size = 1, count = 7, seed = 0, times = [], lags = []) => {
	const mask = MASKS[count - 2] ?? 127;
	const sea = arena == "sea";
	const [still, mover] = {
		sea: ["vortex", "shark"],
		desert: ["whirlwind", "genie"]
	}[arena] ?? ["iceberg", "penguin"];
	const r = sea ? SR : PR;
	const span = H - 2 * r;
	const v = 2 * span * 240 / PERIOD;
	return arena == "classic" ? [] : [...BERGS.flatMap(([x, r, y], i) => [0, 1].map((j) => {
		let c = draw(seed, 400 + 2 * i + j) * CELLS.length | 0;
		for (let n = 1; n <= (times[2 * i + j] ?? 0); n++) c = (c + 1 + (draw(seed, 1e6 + 8 * n + 2 * i + j) * (CELLS.length - 1) | 0)) % CELLS.length;
		const [cx, cy] = seed ? CELLS[c] : [x, y];
		const down = seed && +(draw(seed, 300) < .5) ^ i ^ j;
		return {
			kind: still,
			x: j ? W - cx : cx,
			y: down ? H - cy : cy,
			r,
			vx: 0,
			vy: 0
		};
	})), ...LANES.map(([x, phase, m], l) => {
		if (arena == "desert") {
			let k = 0;
			for (let b = 0; b < 4 + l; b++) k += mask >> b & 1;
			const f = ((t - (lags[k] ?? 0)) / WANDER % 64 + 64) % 64;
			const n = f | 0;
			const u = f - n;
			const e = u * u * (3 - 2 * u);
			const de = 6 * u * (1 - u) * 240 / WANDER;
			const at = (j, n) => draw(seed, 2 + 128 * +(x == W / 2) + 64 * j + n % 64);
			const [dx, dy] = [0, 1].map((j) => at(j, n + 1) - at(j, n));
			return {
				kind: mover,
				x: x + m * 30 * (2 * (at(0, n) + dx * e) - 1),
				y: r + span * (at(1, n) + dy * e),
				r,
				vx: 2 * m * 30 * dx * de,
				vy: span * dy * de
			};
		}
		const u = (t / PERIOD + phase) % 1;
		const up = u >= .5;
		const z = (6 * u + .25) % 1;
		return {
			kind: mover,
			x: sea ? x + m * 70 * (1 - 4 * Math.abs(z - .5)) : x,
			y: r + span * (up ? 2 - 2 * u : 2 * u),
			r,
			vx: sea ? m * (z < .5 ? ZV : -ZV) : 0,
			vy: up ? -v : v
		};
	})].filter((_, i) => mask & 1 << i).map((o) => ({
		...o,
		x: o.x * size,
		y: o.y * size,
		r: o.r * size,
		vx: o.vx * size,
		vy: o.vy * size
	}));
};
/**
* Rink geometry for a number of players. The area grows with the players so each keeps the same
* room: size = √(players / 2) on each side, from 1 (2 players) to MAX_SIZE (8 and more).
* Obstacles: players / 2 + 2, from 3 (2 players: icebergs and the centre penguin) to 7 (10 and
* more), always in mirrored pairs plus, when odd, a penguin on the centre line.
*/
var layout = (players) => ({
	size: Math.min(2, Math.max(1, Math.sqrt(players / 2))),
	count: Math.min(7, Math.max(3, (players / 2 | 0) + 2))
});
/** The scene of round n (from 1; 0 while waiting plays round 1's): the rules' list takes turns. */
var scene = (arena, n) => {
	const a = [].concat(arena);
	return a[(Math.max(n, 1) - 1) % a.length] ?? "ice";
};
// src/shared/physics.ts
/** Restitution of walls, posts and paddle hits. */
var E = .9;
/** Share of the puck speed kept after one second of sliding. */
var DRAG = .7;
/** Minimum speed of a puck leaving an obstacle: the pinball kick (× size). */
var KICK = 1e3;
/** Turns per second of a puck caught in a whirlwind. */
var TURNS = 2.5;
/**
* Seconds a whirlwind holds the puck: HOLD, plus up to SWAY drawn at random. SWAY is 2 turns, so
* the puck leaves in any direction.
*/
var HOLD = .6;
var SWAY = .8;
/** Speed a whirlwind flings the puck out at, a shark spits it at (× size). */
var FLING = 1400;
/** Seconds a shark keeps the puck in its belly. */
var CHEW = .6;
/** A puck coming up from a vortex stays this far from the goal lines (× size). */
var SHORE = 300;
/** Speed a caught puck sinks into a whirlwind's eye or a vortex and comes back out at, units/s. */
var SINK = 600;
/** Clearance a served puck keeps from paddles and obstacles, and the step between serve spots tried. */
var SERVE_GAP = 40;
var SERVE_STEP = 160;
/** Paddle-puck contact distance. */
var RR = 103;
var cl = (v, a, b) => v < a ? a : v > b ? b : v;
/** Bounces a velocity component off a wall whose inward direction is `n` (+1 or -1). */
var bounce = (v, n) => v * n < 0 ? -v * E : v;
/**
* The paddles the puck meets, on a rink of that size. In the crease of its own goal (CREASE ·
* size round the middle of the mouth) only the paddle nearest the goal stops the puck, the lower
* id on a tie: the others there are ghosts it goes through, so a wall of defenders cannot shut
* the goal. Outside the crease every paddle is solid. From positions alone: host and prediction
* agree.
*/
var solid = (ps, size = 1) => {
	const d = (p) => Math.hypot(p.x - p.team * W * size, p.y - H * size / 2);
	const inside = (p) => d(p) <= 300 * size;
	return ps.filter((p) => !inside(p) || !ps.some((q) => q != p && q.team == p.team && inside(q) && (d(q) < d(p) || d(q) == d(p) && q.id < p.id)));
};
/** Clamps a paddle centre to its team's half and inside the walls of a rink of that size. */
var clampPaddle = (team, x, y, size = 1) => {
	const h = W * size / 2;
	const l = team ? h + 75 : 75;
	return [cl(x, l, l + h - 150), cl(y, 75, H * size - 75)];
};
var place = (p, x, y, s) => {
	[p.x, p.y] = clampPaddle(p.team, x, y, s);
};
/** Puck counterpart of place: kept between the top and bottom walls. */
var put = (k, x, y, s) => {
	k.x = x;
	k.y = cl(y, 28, H * s - 28);
};
/**
* Pushes c out of circle o (an obstacle, the puck, a paddle) to the contact distance D, through
* fix (place or put). When a wall stops it, it slides along that wall instead: a penguin at a
* board squeezes it out sideways. `past` (a paddle out of an obstacle): cornered there, where
* a board meets the centre line, it slips past to the obstacle's far side. Returns whether c was
* inside.
*/
var out = (c, o, D, fix, s, past = false) => {
	let nx = c.x - o.x;
	let ny = c.y - o.y;
	let d = Math.hypot(nx, ny);
	if (d >= D) return false;
	if (!d) nx = d = 1;
	const y = o.y + ny / d * D;
	fix(c, o.x + nx / d * D, y, s);
	nx = c.x - o.x;
	ny = c.y - o.y;
	if (nx * nx + ny * ny < D * D) {
		const along = c.y != y;
		const slide = (k) => along ? fix(c, o.x + k * (nx < 0 ? -1 : 1) * Math.sqrt(D * D - ny * ny), c.y, s) : fix(c, c.x, o.y + k * (ny < 0 ? -1 : 1) * Math.sqrt(D * D - nx * nx), s);
		slide(1);
		if (past && Math.hypot(c.x - o.x, c.y - o.y) < D - 1e-6) slide(-1);
	}
	return true;
};
/** Whether a puck at x, y stands clear of every paddle and obstacle, by SERVE_GAP. */
var clear = (w, obs, x, y) => w.paddles.every((p) => Math.hypot(p.x - x, p.y - y) > RR + SERVE_GAP) && obs.every((o) => Math.hypot(o.x - x, o.y - y) > o.r + 28 + SERVE_GAP);
/**
* Serves the puck at rest at x, on the centre row or the nearest clear spot along it, not in play:
* a paddle left on the spot would otherwise shove the puck the moment it appears, into a goal
* again and again.
*/
var serve = (w, obs, x) => {
	const k = w.puck;
	const Y = H * w.size;
	w.live = false;
	[k.x, k.y, k.vx, k.vy] = [
		x,
		Y / 2,
		0,
		0
	];
	for (const f of [
		0,
		-1,
		1,
		-2,
		2
	]) if (clear(w, obs, x, Y / 2 + f * SERVE_STEP * w.size)) {
		k.y = Y / 2 + f * SERVE_STEP * w.size;
		break;
	}
};
/** Whether obstacle i is out of play (removed, ghost included): it touches nothing. */
var off = (w, i) => (w.obs[i]?.gone ?? -1) >= 0;
/** Whether genie i is casting its spell: it stands still, its victim too. */
var casting = (w, i) => (w.obs[i]?.cast ?? -1) >= 0;
/**
* The obstacles of the world at tick t, where they stand: the icebergs placed by their removals,
* each genie behind t by its lag, a casting one still since its spell struck.
*/
var around = (w, t) => obstacles(w.arena, t, w.size, w.count, w.seed, w.obs.map((s) => s.times), w.obs.map((s, i) => (s.lag ?? 0) + (casting(w, i) ? t - s.cast : 0))).map((o, i) => casting(w, i) ? {
	...o,
	vx: 0,
	vy: 0
} : o);
/** The obstacles of the world at its tick, where they stand. */
var standing = (w) => around(w, w.tick);
/**
* Puck against the obstacles in play: out of them, bounce on the relative velocity (penguins,
* sharks and genies move), then the kick: it leaves at KICK · size at least, the push added along
* the normal. A whirlwind, a vortex or a shark grabs the puck instead (w.held, see twirl).
* Records w.bumps. A shark keeps it CHEW seconds; the others HOLD + SWAY · a draw of the seed and
* the u16 tick of the catch: host and prediction draw the same.
* On the host (`was`: the bumps of the previous step) a new contact is a hit: one that did not
* touch that obstacle in the previous step, nor earlier in this one, so a puck held against it
* counts once. A fixed obstacle (iceberg, vortex, whirlwind) goes at its ICEBERG_HP-th hit, a
* penguin or a genie at the first one, removed at once at the tick this step lands on; a shark
* never goes. The puck bounces and gets the kick all the same; a whirlwind or a vortex that goes
* lets go of it at once.
*/
var bump = (w, obs, was) => obs.forEach((o, i) => {
	const k = w.puck;
	const kick = KICK * w.size;
	if (!w.live || w.held >= 0 || off(w, i) || !out(k, o, o.r + 28, put, w.size)) return;
	const d = Math.hypot(k.x - o.x, k.y - o.y);
	const nx = (k.x - o.x) / d;
	const ny = (k.y - o.y) / d;
	const vn = (k.vx - o.vx) * nx + (k.vy - o.vy) * ny;
	if ([
		"whirlwind",
		"vortex",
		"shark"
	].includes(o.kind)) {
		w.held = i;
		w.left = o.kind == "shark" ? CHEW : HOLD + SWAY * draw(w.seed, w.tick & 65535);
	}
	if (o.kind == "genie" && !casting(w, i)) {
		const p = w.paddles.find((p) => p.id == w.last);
		serve(w, obs, (p ? 3 - 2 * p.team : 2) * W * w.size / 4);
		if (p && was) Object.assign(w.obs[i] ??= {
			hits: 0,
			gone: -1,
			angle: 0
		}, {
			cast: w.tick + 1,
			victim: p.id
		});
	} else {
		if (vn < 0) {
			k.vx -= 1.9 * vn * nx;
			k.vy -= 1.9 * vn * ny;
		}
		const s = Math.hypot(k.vx, k.vy);
		if (s < kick) {
			const un = k.vx * nx + k.vy * ny;
			const a = Math.sqrt(un * un - s * s + kick * kick) - un;
			k.vx += a * nx;
			k.vy += a * ny;
		}
	}
	if (!w.bumps.includes(i)) {
		w.bumps.push(i);
		if (was && !was.includes(i)) {
			const st = w.obs[i] ??= {
				hits: 0,
				gone: -1,
				angle: 0
			};
			st.angle = Math.atan2(-ny, -nx);
			if (!["shark", "genie"].includes(o.kind) && ++st.hits >= (fixed(o) ? 3 : 1)) {
				st.gone = w.tick + 1;
				st.times = (st.times ?? 0) + 1 & 255;
			}
		}
	}
});
/**
* A grabbed puck for dt, by obstacle w.held of obs, until w.left runs out or the obstacle goes:
* - a whirlwind turns it TURNS a second in its sense (swirl), sinking at SINK to the eye's edge
*   (o.r - PUCK_R: no paddle reaches it there), back out to the rim in time. Then it flies off
*   along its circle at FLING · size from just past the rim, from where it turned to: a random
*   direction.
* - a vortex turns it the same way down to its centre, under the water. Then it comes up at rest
*   on the first of five spots drawn from the seed and the u16 tick that stands clear (or the
*   last one): anywhere on the rink but within SHORE of a goal line, in mirror for a vortex right
*   of the centre line.
* - a shark keeps it in its belly, at its centre, then spits it at FLING · size from just past
*   its rim in a direction drawn from the seed and the u16 tick: aimed at a player, it would set
*   two of them shooting it back and forth through the shark.
* Its velocity follows its motion, for drawing between steps.
*/
var twirl = (w, obs, dt) => {
	const k = w.puck;
	const o = obs[w.held];
	const s = w.size;
	const d = swirl(o, s);
	const a = Math.atan2(k.y - o.y, k.x - o.x) + d * TURNS * 2 * Math.PI * dt;
	let r = Math.hypot(k.x - o.x, k.y - o.y);
	w.left -= dt;
	const gone = w.left < 1e-9 || off(w, w.held);
	r = o.kind == "shark" ? 0 : gone ? o.r + 28 + 1 : r + cl((o.kind == "vortex" ? 0 : w.left * SINK < 56 ? o.r + 28 : o.r - 28) - r, -600 * dt, SINK * dt);
	const x = o.x + Math.cos(a) * r;
	const y = o.y + Math.sin(a) * r;
	[k.vx, k.vy] = o.kind == "shark" ? [o.vx, o.vy] : [(x - k.x) / dt, (y - k.y) / dt];
	[k.x, k.y] = [x, y];
	if (!gone) return;
	w.held = -1;
	k.vx = -Math.sin(a) * d * FLING * s;
	k.vy = Math.cos(a) * d * FLING * s;
	const t = (w.tick & 65535) * 10;
	if (o.kind == "vortex") {
		for (let j = 0; j < 10; j += 2) {
			k.x = (SHORE + (W - 2 * SHORE) * draw(w.seed, t + j)) * s;
			k.x = d > 0 ? k.x : W * s - k.x;
			k.y = 28 + (H * s - 56) * draw(w.seed, t + j + 1);
			if (clear(w, obs, k.x, k.y)) break;
		}
		k.vx = k.vy = 0;
	}
	if (o.kind == "shark") {
		const b = 2 * Math.PI * draw(w.seed, t);
		const [ux, uy] = [Math.cos(b), Math.sin(b)];
		put(k, o.x + ux * (o.r + 28 + 1), o.y + uy * (o.r + 28 + 1), s);
		k.vx = ux * FLING * s;
		k.vy = uy * FLING * s;
	}
};
/** A paddle out of the obstacles in play: it slides around them. */
var avoid = (p, w, obs) => obs.forEach((o, i) => off(w, i) || out(p, o, o.r + 75, place, w.size, true));
/** Empty world at tick 0: puck at the centre, no paddles, 0-0, every obstacle in play, intact. */
var createWorld = (arena = "ice", size = 1, count = 7, seed = 0) => ({
	arena,
	size,
	count,
	seed,
	tick: 0,
	bumps: [],
	live: false,
	held: -1,
	left: 0,
	obs: obstacles(arena, 0, size, count, seed).map(() => ({
		hits: 0,
		gone: -1,
		angle: 0
	})),
	puck: {
		x: W * size / 2,
		y: H * size / 2,
		vx: 0,
		vy: 0
	},
	paddles: [],
	score: [0, 0],
	hit: -1
});
/**
* Spawn point for the n-th paddle of a team, spread over its half of a rink of that size: the
* n-th spot of the grid below that no obstacle of obs covers (10 units clear).
* Three columns of three, from the goal outward, 150 and 145 apart (a paddle wide, about); the
* last column is 105 units short of the serve spot (W / 4 from the goal), more than
* PUCK_R + PADDLE_R. The icebergs stand on cells of the same area (see CELLS in arena.ts), so a
* spot under one is skipped; the last column is clear of the nearest penguin lane (x 720), of a
* shark at the end of its swing and of a genie at the edge of its band. Past 9 spots the grid
* repeats, shifted down by 60 units.
* All of it is drawn on the base rink and scaled with the obstacles, so every clearance grows.
*/
var spawnPoint = (team, n, size = 1, obs = []) => {
	let p;
	let k = 0;
	do {
		const x = [
			100,
			250,
			395
		][(k / 3 | 0) % 3] * size;
		const y = (H / 2 + [
			0,
			-.3,
			.3
		][k % 3] * H + 60 * (k++ / 9 | 0)) * size;
		p = clampPaddle(team, team ? W * size - x : x, y, size);
	} while (obs.some((o) => Math.hypot(p[0] - o.x, p[1] - o.y) <= o.r + 75 + 10) || n-- > 0);
	return p;
};
/**
* Advances the world by dt seconds (always 1 / TICK_HZ in practice) and w.tick by one.
* Moves paddles toward their target, moves the puck, resolves collisions with the obstacles
* of the arena at the new tick.
* On a goal it bumps the score, re-serves the puck and returns the scoring team; -1 otherwise.
* Sets w.hit to the paddle that touched the puck during the step (the last one if several), or -1,
* and w.bumps to the obstacles it touched.
* `host`: the authoritative world, where the puck damages the obstacles (see bump). A prediction
* (false) bounces off the same obstacles and leaves w.obs alone but for their return.
*
* Obstacles due back at the new tick (gone + RESPAWN) come back first, intact. A live puck in the
* way is pushed out gently, a unit clear: no kick, no damage, no bump. Paddles slide out of them
* like out of any obstacle, in the sub-step.
*
* No tunnelling at 240 Hz: the puck moves at most 2400 / 240 = 10 units per step (< PUCK_R = 28
* against walls and posts), a paddle 7200 / 240 = 30, so the closing distance per step is at
* most 40 < PUCK_R + PADDLE_R = 103: an overlap is always caught before the centres cross.
* Penguins, sharks (zig-zag included) and genies (at their fastest, mid-glide) move under 1.6
* units per step: puck to obstacle closes at most 11.6 < 40 + 28 (the smallest obstacle, a penguin
* or a genie), paddle to obstacle 31.6 < 40 + 75. A caught puck moves with its whirlwind's turn.
* On a bigger rink top speeds grow with the size, so the step runs in ceil(size) sub-steps, the
* obstacles taken at fractional ticks: the distances per sub-step stay those above.
*/
var step = (w, dt, host = true) => {
	const was = host ? w.bumps : void 0;
	w.hit = -1;
	w.bumps = [];
	let goal = -1;
	const n = Math.ceil(w.size);
	const at = (i) => around(w, w.tick + i / n);
	if (dt > 0) {
		w.obs.forEach((st) => {
			if ((st.cast ?? -1) >= 0 && w.tick + 1 - st.cast >= 1200) {
				st.lag = (st.lag ?? 0) + STUN & 65535;
				st.cast = -1;
			}
		});
		at(1).forEach((o, i) => {
			const st = w.obs[i];
			if (st?.gone >= 0 && w.tick + 1 - st.gone >= 2400) {
				Object.assign(st, {
					hits: 0,
					gone: -1
				});
				if (w.live) out(w.puck, o, o.r + 28 + 1, put, w.size);
			}
		});
	}
	for (let i = 1; dt > 0 && i <= n; i++) {
		const g = sub(w, dt / n, at(i), was);
		if (g != -1) goal = g;
	}
	w.tick += +(dt > 0);
	return goal;
};
/** Paddle p toward its target for dt, at most PADDLE_MAX_SPEED · size, around the obstacles obs. */
var drive = (p, w, obs, dt) => {
	const s = w.size;
	const m = PADDLE_MAX_SPEED * s * dt;
	const ox = p.x;
	const oy = p.y;
	const [tx, ty] = w.obs.some((st) => (st.cast ?? -1) >= 0 && st.victim == p.id) ? [p.x, p.y] : clampPaddle(p.team, p.tx, p.ty, s);
	let dx = tx - ox;
	let dy = ty - oy;
	const d = Math.hypot(dx, dy);
	if (d > m) {
		dx *= m / d;
		dy *= m / d;
	}
	place(p, ox + dx, oy + dy, s);
	avoid(p, w, obs);
	p.vx = (p.x - ox) / dt;
	p.vy = (p.y - oy) / dt;
};
/**
* The countdown before a round (phase 'ready'): step for the paddles only. They move toward their
* targets as in step, around the obstacles where they stand and around the puck, which they never
* push. The puck, the obstacles, w.tick, w.hit, w.live and the score stay as they are.
*/
var skate = (w, dt) => {
	const n = Math.ceil(w.size);
	const obs = standing(w);
	for (let i = 0; i < n; i++) for (const p of w.paddles) {
		drive(p, w, obs, dt / n);
		if (out(p, w.puck, RR, place, w.size)) avoid(p, w, obs);
	}
};
/** One sub-step of step, among the obstacles obs. */
var sub = (w, dt, obs, was) => {
	const s = w.size;
	const k = w.puck;
	const X = W * s;
	const Y = H * s;
	const G = 380 * s / 2;
	let hit = -1;
	let goal = -1;
	w.paddles.forEach((p) => drive(p, w, obs, dt));
	const ps = solid(w.paddles, s);
	if (w.held >= 0) twirl(w, obs, dt);
	if (w.held >= 0) {
		ps.forEach((p) => out(p, k, RR, place, s) && avoid(p, w, obs));
		return -1;
	}
	const f = DRAG ** dt;
	k.vx *= f;
	k.vy *= f;
	k.x += k.vx * dt;
	k.y += k.vy * dt;
	for (const p of ps) {
		let nx = k.x - p.x;
		let ny = k.y - p.y;
		let d = Math.hypot(nx, ny);
		if (d < RR) {
			hit = p.id;
			if (!d) {
				nx = 1 - 2 * p.team;
				d = 1;
			}
			nx /= d;
			ny /= d;
			k.x = p.x + nx * RR;
			k.y = p.y + ny * RR;
			const vn = (k.vx - p.vx) * nx + (k.vy - p.vy) * ny;
			if (vn < 0) {
				k.vx -= 1.9 * vn * nx;
				k.vy -= 1.9 * vn * ny;
			}
		}
	}
	if (k.y < 28 || k.y > Y - 28) {
		k.y = cl(k.y, 28, Y - 28);
		k.vy = bounce(k.vy, k.y < Y / 2 ? 1 : -1);
	}
	const i = k.x < X / 2 ? 1 : -1;
	const gx = i > 0 ? 0 : X;
	const u = (k.x - gx) * i;
	if (u < 28) {
		const dy = k.y - Y / 2;
		if (Math.abs(dy) > G) {
			k.x = gx + 28 * i;
			k.vx = bounce(k.vx, i);
		} else if (u < 0) {
			if (Math.abs(dy) > G - 28) {
				k.y = Y / 2 + Math.sign(dy) * (G - 28);
				k.vy = bounce(k.vy, -Math.sign(dy));
			}
			k.vx = i * Math.min(k.vx * i, -300 * s);
			if (u < -28) {
				goal = i > 0 ? 1 : 0;
				w.score[goal]++;
				serve(w, obs, i > 0 ? X / 4 : 3 * X / 4);
			}
		} else {
			const py = Y / 2 + (dy < 0 ? -G : G);
			let nx = k.x - gx;
			let ny = k.y - py;
			const d = Math.hypot(nx, ny);
			if (d < 28 && d) {
				nx /= d;
				ny /= d;
				k.x = gx + nx * 28;
				k.y = py + ny * 28;
				const vn = k.vx * nx + k.vy * ny;
				if (vn < 0) {
					k.vx -= 1.9 * vn * nx;
					k.vy -= 1.9 * vn * ny;
				}
			}
		}
	}
	w.live ||= hit != -1;
	if (hit != -1) w.hit = w.last = hit;
	bump(w, obs, was);
	for (let n = 0; n < 4; n++) {
		for (const p of solid(w.paddles, s)) if (out(p, k, RR, place, s)) {
			w.hit = w.last = p.id;
			w.live = true;
			avoid(p, w, obs);
			out(k, p, RR, put, s);
		}
		bump(w, obs, was);
	}
	const v = Math.hypot(k.vx, k.vy);
	const top = PUCK_MAX_SPEED * s;
	if (v > top) {
		k.vx *= top / v;
		k.vy *= top / v;
	}
	return goal;
};
var toWire = (v) => Math.max(0, Math.min(65535, Math.round(v * 16)));
var fromWire = (v) => v / 16;
/** A velocity travels in whole units per second, in an Int16. */
var speed = (v) => Math.max(-32768, Math.min(32767, Math.round(v)));
var decodeInput = (buf) => {
	if (buf.byteLength !== 5) return null;
	const v = new DataView(buf);
	if (v.getUint8(0) !== 1) return null;
	return {
		x: fromWire(v.getUint16(1)),
		y: fromWire(v.getUint16(3))
	};
};
var SNAP_HEAD = 17;
var SNAP_PADDLE = 5;
var SNAP_OB = 10;
var TURN = 2 * Math.PI;
var encodeSnapshot = (s) => {
	const obs = s.obs ?? [];
	const o = SNAP_HEAD + SNAP_PADDLE * s.paddles.length;
	const v = new DataView(new ArrayBuffer(o + 1 + SNAP_OB * obs.length));
	v.setUint8(0, 2);
	v.setUint16(1, s.tick & 65535);
	v.setUint8(3, Math.min(255, s.score[0]));
	v.setUint8(4, Math.min(255, s.score[1]));
	v.setUint16(5, toWire(s.puck.x));
	v.setUint16(7, toWire(s.puck.y));
	v.setUint8(9, s.paddles.length);
	v.setUint8(10, +!!s.live | (s.held ?? -1) + 1 << 1);
	v.setInt16(11, speed(s.puck.vx));
	v.setInt16(13, speed(s.puck.vy));
	v.setUint16(15, Math.round((s.left ?? 0) * 1e3));
	s.paddles.forEach((p, i) => {
		const o = SNAP_HEAD + i * SNAP_PADDLE;
		v.setUint8(o, p.id);
		v.setUint16(o + 1, toWire(p.x));
		v.setUint16(o + 3, toWire(p.y));
	});
	v.setUint8(o, obs.length);
	obs.forEach(({ hits, since, angle, times = 0, cast = -1, victim = 0, lag = 0 }, i) => {
		const b = o + 1 + i * SNAP_OB;
		v.setUint8(b, Math.min(255, hits));
		v.setUint16(b + 1, since < 0 ? 65535 : Math.min(65534, since));
		v.setUint8(b + 3, Math.round(angle / TURN * 256) & 255);
		v.setUint8(b + 4, times);
		v.setUint16(b + 5, cast < 0 ? 65535 : Math.min(65534, cast));
		v.setUint8(b + 7, victim);
		v.setUint16(b + 8, lag);
	});
	return v.buffer;
};
/** Returns null on anything that is not a known text message. */
var parseText = (raw) => {
	try {
		const msg = JSON.parse(raw);
		return msg && typeof msg.t === "string" ? msg : null;
	} catch {
		return null;
	}
};
// src/shared/room.ts
/** Ticks run at most this many times per timer callback, so a stalled host does not spiral. */
var MAX_CATCH_UP = 20;
/** First n characters (code points) of s, trimmed. */
var cut = (s, n) => Array.from(s).slice(0, n).join("").trim();
var cleanName = (raw) => cut((typeof raw === "string" ? raw : "").replace(/\s+/g, " ").replace(/\p{Cc}/gu, "").trim(), 16);
/** name, or name 2, name 3… (base cut to stay within MAX_NAME) when it is taken. */
var unique = (name, taken) => {
	let out = name;
	for (let n = 2; taken.includes(out); n++) out = `${cut(name, 15 - `${n}`.length)} ${n}`;
	return out;
};
var fresh = (info) => ({
	...info,
	points: 0,
	goals: 0,
	hits: 0
});
/** A new seed for the icebergs (vortices, whirlwinds), never 0 (the fixed layout). */
var seed = () => 1 + (Math.random() * 4294967294 >>> 0);
var idle = ({ goals, rounds }, { arena, size, count, seed }) => ({
	t: "match",
	phase: "wait",
	round: 0,
	wins: [0, 0],
	arena,
	size,
	count,
	seed,
	goals,
	rounds
});
var setEvery = (cb, ms) => {
	const id = setInterval(cb, ms);
	return () => clearInterval(id);
};
/**
* One game, transport-agnostic. The Node server and the local host tab both
* drive a Room: they feed it connections and frames, the room answers through Conn.send.
*/
var Room = class {
	/** Every connected peer; null until it joins. */
	peers = /* @__PURE__ */ new Map();
	world;
	/** Room ticks, frozen phases included: the snapshot cadence. */
	ticks = 0;
	halt;
	rules;
	/** The match state, as broadcast. */
	m;
	/** Ticks left in 'ready', 'break' or 'end'. */
	timer = 0;
	/** Last toucher of the puck; none after a serve or a goal. */
	last;
	/**
	* Everyone who played the current match, left ones included, in the order their points last
	* changed: the stable sort of the ranking then puts whoever reached a total first ahead.
	*/
	stats = [];
	/** Missing rules fall back to RULES. */
	constructor(rules = {}) {
		this.rules = {
			...RULES,
			...rules
		};
		this.world = this.empty();
		this.m = idle(this.rules, this.world);
	}
	/** Number of joined players. */
	get size() {
		return this.players().length;
	}
	/** A peer opened. Nothing is sent until it joins. */
	connect(conn) {
		this.peers.set(conn, null);
	}
	/** A text (JSON) or binary frame from a peer. */
	receive(conn, data) {
		const p = this.peers.get(conn);
		if (typeof data === "string") {
			const msg = parseText(data);
			if (p === null && msg?.t === "join") this.join(conn, msg.name);
			return;
		}
		const input = p && decodeInput(data);
		if (input) [p.paddle.tx, p.paddle.ty] = clampPaddle(p.info.team, input.x, input.y, this.world.size);
	}
	/** A peer left: its paddle goes, the roster goes out again. */
	disconnect(conn) {
		const p = this.peers.get(conn);
		this.peers.delete(conn);
		if (!p) return;
		const w = this.world;
		w.paddles = w.paddles.filter((q) => q !== p.paddle);
		if (p.rank) p.rank.left = true;
		if (this.size) this.roster();
		else {
			this.world = this.empty();
			this.ticks = 0;
		}
		if (!this.sync() && this.fit()) this.go(this.m.phase);
	}
	/** One physics step of 1 / TICK_HZ; a snapshot goes out every SNAP_EVERY ticks. */
	tick() {
		if (!this.size) return;
		const { rules, m, world: w } = this;
		const { phase } = m;
		if (phase === "ready") {
			skate(w, 1 / 240);
			if (--this.timer < 1) this.go("play");
		} else if (phase === "break" || phase === "end") {
			if (--this.timer < 1) {
				if (phase === "break") this.next();
				else this.sync(true);
			}
		} else {
			const goal = step(w, 1 / 240);
			const p = this.players().find((p) => p.info.id === w.hit);
			if (p && p !== this.last) this.add(this.last = p, rules.hit, "hits");
			if (goal !== -1) {
				if (this.last) this.add(this.last, this.last.info.team === goal ? rules.goal : -rules.ownGoal, this.last.info.team === goal ? "goals" : void 0);
				this.last = void 0;
				this.broadcast(JSON.stringify({
					t: "goal",
					team: goal,
					score: [...w.score]
				}));
				if (phase === "play" && w.score[goal] >= rules.goals) {
					m.wins[goal]++;
					const end = m.round >= rules.rounds;
					const [a, b] = m.wins;
					const win = end && a != b ? +(b > a) : goal;
					const n = this.teams();
					const k = Math.round(n[1 - win] / n[win]) || 1;
					this.players().forEach((p) => this.add(p, (p.info.team === goal ? rules.roundWin : 0) + (end && p.info.team === win ? rules.matchWin * k : 0)));
					this.timer = Math.round((end ? rules.endSec : rules.breakSec) * 240);
					this.go(end ? "end" : "break", win);
				} else if (this.fit()) this.go(phase);
			}
		}
		if (++this.ticks % 4 === 0) this.broadcast(encodeSnapshot({
			tick: w.tick,
			score: w.score,
			puck: w.puck,
			paddles: w.paddles,
			live: w.live,
			held: w.held,
			left: w.left,
			obs: w.obs.map(({ gone, cast = -1, ...o }) => ({
				...o,
				since: gone < 0 ? -1 : w.tick - gone,
				cast: cast < 0 ? -1 : w.tick - cast
			}))
		}));
	}
	/**
	* Drives tick() with a timer. An accumulator on performance.now() keeps the
	* simulation at TICK_HZ whatever the timer jitter; after a stall at most
	* MAX_CATCH_UP ticks are replayed and the rest of the backlog is dropped.
	* `every` replaces setInterval, e.g. with a Worker-backed timer that
	* background tabs do not throttle.
	*/
	start(every = setEvery) {
		if (this.halt) return;
		const dt = 1e3 / 240;
		let last = performance.now();
		let acc = 0;
		this.halt = every(() => {
			const now = performance.now();
			acc += now - last;
			last = now;
			for (let n = 0; acc >= dt && n < MAX_CATCH_UP; n++) {
				this.tick();
				acc -= dt;
			}
			acc %= dt;
		}, dt);
	}
	stop() {
		this.halt?.();
		this.halt = void 0;
	}
	/** A world on the rink of layout(0), in the first scene, for a room nobody joined yet. */
	empty() {
		const { size, count } = layout(0);
		return createWorld(scene(this.rules.arena, 0), size, count, seed());
	}
	/** The scene of the current round: the first one while waiting. */
	scene() {
		return scene(this.rules.arena, this.m.round);
	}
	players() {
		return [...this.peers.values()].filter((p) => p !== null);
	}
	broadcast(data) {
		this.players().forEach((p) => p.conn.send(data));
	}
	join(conn, name) {
		const players = this.players();
		if (players.length >= 16) {
			conn.send(JSON.stringify({ t: "full" }));
			return;
		}
		let id = 0;
		while (players.some((p) => p.info.id === id)) id++;
		const n = this.teams();
		const team = n[1] < n[0] ? 1 : 0;
		const [x, y] = spawnPoint(team, n[team], this.world.size, standing(this.world));
		const paddle = {
			id,
			team,
			x,
			y,
			vx: 0,
			vy: 0,
			tx: x,
			ty: y
		};
		const info = {
			id,
			name: unique(cleanName(name) || `Player ${id}`, players.map((p) => p.info.name)),
			color: `hsl(${Math.round(id * 137.508 % 360)} 80% 55%)`,
			team
		};
		const player = {
			conn,
			info,
			paddle
		};
		const { phase } = this.m;
		if (phase !== "wait" && phase !== "end") {
			let r = this.stats.find((r) => r.left && r.name === info.name);
			if (r) delete r.left;
			else this.stats.push(r = fresh(info));
			player.rank = Object.assign(r, info);
		}
		this.world.paddles.push(paddle);
		this.peers.set(conn, player);
		this.roster();
		if (!this.sync()) {
			if (this.fit()) this.go(this.m.phase);
			else conn.send(this.told());
		}
	}
	add(p, points, stat) {
		const r = p?.rank;
		if (r && !r.left) {
			if (stat) r[stat]++;
			if (points) {
				const s = this.stats;
				r.points += points;
				s.push(...s.splice(s.indexOf(r), 1));
			}
		}
	}
	/** Players per team. */
	teams() {
		const n = [0, 0];
		this.world.paddles.forEach((p) => n[p.team]++);
		return n;
	}
	/**
	* Starts a match once both teams have a player, drops back to 'wait' when one empties.
	* The final ranking stays up for endSec unless the room empties; `due` ends it.
	* Returns whether the phase changed.
	*/
	sync(due) {
		const [a, b] = this.teams();
		const { phase } = this.m;
		const on = a && b;
		if (!due && (on ? phase !== "wait" : phase === "wait" || phase === "end" && this.size)) return false;
		this.m = idle(this.rules, this.world);
		if (on) {
			this.stats = this.players().map((p) => p.rank = fresh(p.info));
			this.next();
		} else {
			this.fit();
			this.go("wait");
		}
		return true;
	}
	/**
	* Moves the world onto the rink the joined players call for, in the scene of the round (the
	* first one while waiting), when that is fair: while waiting, during the countdown, or mid-round
	* while the puck waits at its serve spot (after a goal) and nobody has touched it yet. Paddles
	* respawn on it (see shape), the puck keeps its serve spot, scaled; the score stays, so does
	* the countdown. The icebergs (vortices) take a new place while waiting, keep the round's one
	* otherwise. The caller tells the clients.
	* Returns whether it did.
	*/
	fit() {
		const { size, count } = layout(this.size);
		const w = this.world;
		const { phase } = this.m;
		if (!(phase === "wait" || phase === "ready" || phase === "play" && !w.live) || size === w.size && count === w.count && w.arena === this.scene()) return false;
		const { x, y } = w.puck;
		const r = size / w.size;
		this.shape(w.score, phase === "wait" ? seed() : w.seed);
		if (phase === "play") Object.assign(this.world.puck, {
			x: x * r,
			y: y * r
		});
		return true;
	}
	/**
	* The world on the rink for the joined players (layout), in the scene of the round, at tick 0,
	* where no penguin stands on the centre spot: paddles back to their spawn points, puck served,
	* every obstacle back and intact (a fresh w.obs, sized to the new count), the icebergs (vortices)
	* placed by `seed`, score as given.
	* Returns the paddles per team.
	*/
	shape(score, seed) {
		const w = this.world;
		const { size, count } = layout(this.size);
		const n = [0, 0];
		const arena = this.scene();
		Object.assign(w, createWorld(arena, size, count, seed), {
			paddles: w.paddles,
			score
		});
		const obs = standing(w);
		w.paddles.forEach((p) => {
			[p.tx, p.ty] = [p.x, p.y] = spawnPoint(p.team, n[p.team]++, size, obs);
		});
		Object.assign(this.m, {
			arena,
			size,
			count,
			seed
		});
		this.last = void 0;
		return n;
	}
	/**
	* Next round, in its scene, on the rink for the players joined right now (set until the next
	* round), the icebergs (vortices) in a new place: paddles back to their spawn points, puck served,
	* head start for the smaller team, then the readySec countdown (none at 0) before play.
	*/
	next() {
		this.m.round++;
		const [a, b] = this.shape([0, 0], seed());
		const { goals, headStart, readySec } = this.rules;
		this.world.score[a < b ? 0 : 1] = Math.min(goals - 1, headStart * Math.abs(a - b));
		this.timer = Math.round(readySec * 240);
		this.go(this.timer > 0 ? "ready" : "play");
	}
	/**
	* Phase change, broadcast. 'break' and 'end' carry the winner and the ranking at that time,
	* 'ready' the time left (see told).
	*/
	go(phase, winner) {
		Object.assign(this.m, {
			phase,
			left: void 0,
			winner,
			ranking: winner === void 0 ? winner : [...this.stats].sort((a, b) => b.points - a.points || b.goals - a.goals || b.hits - a.hits)
		});
		this.broadcast(this.told());
	}
	/**
	* The match message as of now. In 'ready' it carries the ms left until play: a client counts
	* down from when it gets the message, a joiner mid-countdown included, all of them late by
	* their own latency only, like the 'play' message that ends it.
	*/
	told() {
		if (this.m.phase === "ready") this.m.left = Math.round(this.timer * 1e3 / 240);
		return JSON.stringify(this.m);
	}
	/** Each joined peer gets the full roster with its own id. */
	roster() {
		const players = this.players();
		const list = players.map((p) => p.info).sort((a, b) => a.id - b.id);
		players.forEach((p) => p.conn.send(JSON.stringify({
			t: "roster",
			you: p.info.id,
			players: list
		})));
	}
};
export { RULES as n, Room as t };
