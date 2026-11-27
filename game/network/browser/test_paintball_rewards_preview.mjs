import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPaintballRewards} from './paintball_rewards_preview.mjs';
import {createPrivatePaintballMatches} from './paintball_matches_preview.mjs';

const dir = mkdtempSync(join(tmpdir(), 'wb-pb-rewards-'));
try {
 const accountFile = join(dir, 'accounts.json');
 const state = {
  profiles: {
   alice: {id: 'acct-a', username: 'alice', stars: 3, character: 'female-b'},
   bob: {id: 'acct-b', username: 'bob', stars: 1, character: 'robot'},
  },
 };
 const store = {
  accountFile,
  state,
  save() {
   writeFileSync(accountFile, JSON.stringify(state));
  },
 };
 const rewards = createPaintballRewards(store);

 // 1. Direct online reward check: 1st=+10, 2nd=+7, 3rd=+5, idempotent per match id, persisted.
 assert.equal(rewards.awardOnline(state.profiles.alice, 1, 'pb_match_0001'), 10);
 assert.equal(state.profiles.alice.stars, 13);
 assert.equal(rewards.awardOnline(state.profiles.alice, 1, 'pb_match_0001'), 10);
 assert.equal(state.profiles.alice.stars, 13);
 assert.equal(rewards.awardOnline(state.profiles.bob, 2, 'pb_match_0001'), 7);
 assert.equal(state.profiles.bob.stars, 8);
 const saved1 = JSON.parse(readFileSync(accountFile, 'utf8'));
 assert.equal(saved1.profiles.alice.stars, 13);
 assert.equal(saved1.profiles.bob.stars, 8);

 // 2. Private match start forwards two distinct saved human avatars to the worker
 //    and awards Stars once when the authority reports phase === 'finished'.
 let openedHumans = null;
 const sent = [];
 const updatedStars = [];
 const worker = {
  healthy: () => true,
  async call(op, payload) {
   if (op === 'open') {
    openedHumans = payload.humans;
    return {ok: true};
   }
   if (op === 'view') {
    return {
     ok: true,
     view: {
      phase: 'finished',
      round: 3,
      selfSlot: payload.slot,
      hostSlot: '1',
      ranking: [
       {slot: '1', alias: 'alice', score: 12, rank: 1, bot: false, left: false},
       {slot: '2', alias: 'bob', score: 8, rank: 2, bot: false, left: false},
      ],
      players: [],
      events: [],
     },
    };
   }
   return {ok: true};
  },
 };
 const peerA = {profile: state.profiles.alice};
 const peerB = {profile: state.profiles.bob};
 const matches = createPrivatePaintballMatches({
  worker,
  admitted: () => true,
  send: (p, m) => sent.push({p, m}),
  hideFromWorld: () => {},
  character: p => p.character || 'male-a',
  rewards,
  onStarsUpdated: p => updatedStars.push(p.profile.username),
 });
 const lobby = {
  revision: 1,
  slots: [
   {id: 1, account: 'acct-a', alias: 'alice', peer: peerA},
   {id: 2, account: 'acct-b', alias: 'bob', peer: peerB},
  ],
 };
 const started = await matches.start(lobby, lobby.slots[0], 1);
 assert.equal(started.ok, true);
 assert.deepEqual(openedHumans, [
  {slot: '1', alias: 'alice', avatar: 'female-b'},
  {slot: '2', alias: 'bob', avatar: 'robot'},
 ]);
 const enterA = sent.find(x => x.p === peerA && x.m.action === 'enter');
 assert.ok(enterA);
 await matches.handle(peerA, {type: 'paintballMatch', action: 'view', epoch: enterA.m.epoch}, 5000);
 const viewA = sent.find(x => x.p === peerA && x.m.action === 'view');
 assert.equal(viewA.m.view.rewardStars, 10);
 assert.equal(state.profiles.alice.stars, 23);
 assert.equal(state.profiles.bob.stars, 15);
 assert.deepEqual(updatedStars.sort(), ['alice', 'bob']);

 console.log('PASS: Paintball online Stars rewards, idempotency, persistence, and two distinct human avatars');
} finally {
 rmSync(dir, {recursive: true, force: true});
}
