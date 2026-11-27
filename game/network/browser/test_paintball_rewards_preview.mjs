import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPaintballRewards} from './paintball_rewards_preview.mjs';

const dir = mkdtempSync(join(tmpdir(), 'wb-pb-rewards-'));
try {
 const accountFile = join(dir, 'accounts.json');
 const state = {profiles: {alice: {username: 'alice', stars: 3}}};
 const store = {
  accountFile,
  state,
  save() {
   writeFileSync(accountFile, JSON.stringify(state));
  },
 };
 const rewards = createPaintballRewards(store);
 const p = state.profiles.alice;

 // Online reward: 1st place = +10, idempotent per match id, persisted to disk.
 assert.equal(rewards.awardOnline(p, 1, 'pb_match_0001'), 10);
 assert.equal(p.stars, 13);
 assert.equal(rewards.awardOnline(p, 1, 'pb_match_0001'), 10);
 assert.equal(p.stars, 13);
 const saved1 = JSON.parse(readFileSync(accountFile, 'utf8'));
 assert.equal(saved1.profiles.alice.stars, 13);

 // Solo reward: 2nd place = +7, idempotent per requestId, cooldown enforced.
 const t0 = 1_000_000;
 const r1 = rewards.applySolo(p, {type: 'progress', action: 'paintball', operation: 'completeSolo', rank: 2, requestId: 'solo_req_0001'}, t0);
 assert.equal(r1.reward, 7);
 assert.equal(p.stars, 20);
 const dup = rewards.applySolo(p, {type: 'progress', action: 'paintball', operation: 'completeSolo', rank: 2, requestId: 'solo_req_0001'}, t0 + 1000);
 assert.equal(dup.reward, 7);
 assert.equal(p.stars, 20);
 const tooSoon = rewards.applySolo(p, {type: 'progress', action: 'paintball', operation: 'completeSolo', rank: 1, requestId: 'solo_req_0002'}, t0 + 30_000);
 assert.ok(tooSoon.error);
 assert.equal(p.stars, 20);
 const later = rewards.applySolo(p, {type: 'progress', action: 'paintball', operation: 'completeSolo', rank: 3, requestId: 'solo_req_0003'}, t0 + 125_000);
 assert.equal(later.reward, 5);
 assert.equal(p.stars, 25);

 // Invalid rank rejected.
 const bad = rewards.applySolo(p, {type: 'progress', action: 'paintball', operation: 'completeSolo', rank: 9, requestId: 'solo_req_0004'}, t0 + 300_000);
 assert.ok(bad.error);
 console.log('PASS: Paintball online + solo server-backed Stars rewards, idempotency, persistence, and cooldown');
} finally {
 rmSync(dir, {recursive: true, force: true});
}
