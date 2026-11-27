import {readFileSync} from 'node:fs';

const SOLO_COOLDOWN_MS = 120_000;
const MAX_RECEIPTS = 32;
const rid = x => typeof x === 'string' && /^[A-Za-z0-9_-]{8,64}$/.test(x);

export function rewardForRank(rank) {
 const r = Number(rank);
 if (r === 1) return 10;
 if (r === 2) return 7;
 return 5;
}

export function createPaintballRewards(store) {
 function persist(profile, nextStars, nextReceipts, nextSoloAt) {
  const prevStars = profile.stars;
  const prevReceipts = profile.paintballReceipts;
  const prevSoloAt = profile.paintballSoloAt;
  profile.stars = nextStars;
  profile.paintballReceipts = nextReceipts;
  if (nextSoloAt !== undefined) profile.paintballSoloAt = nextSoloAt;
  try {
   store.save();
   return true;
  } catch {
   try {
    const disk = JSON.parse(readFileSync(store.accountFile, 'utf8')).profiles[profile.username];
    if (disk?.stars === nextStars && JSON.stringify(disk.paintballReceipts) === JSON.stringify(nextReceipts)) return true;
   } catch {}
   profile.stars = prevStars;
   if (prevReceipts === undefined) delete profile.paintballReceipts; else profile.paintballReceipts = prevReceipts;
   if (nextSoloAt !== undefined) {
    if (prevSoloAt === undefined) delete profile.paintballSoloAt; else profile.paintballSoloAt = prevSoloAt;
   }
   return false;
  }
 }

 function awardOnline(profile, rank, matchId) {
  if (!profile || !rid(matchId)) return 0;
  const receipts = Array.isArray(profile.paintballReceipts) ? profile.paintballReceipts.slice() : [];
  const existing = receipts.find(r => r && r.id === matchId);
  if (existing) return Number(existing.stars) || 0;
  const reward = rewardForRank(rank);
  const nextStars = Math.min(Number.MAX_SAFE_INTEGER, (Number(profile.stars) || 0) + reward);
  receipts.push({id: matchId, stars: reward});
  while (receipts.length > MAX_RECEIPTS) receipts.shift();
  return persist(profile, nextStars, receipts, undefined) ? reward : 0;
 }

 function applySolo(profile, m, now = Date.now()) {
  if (!profile) return {error: 'Sign in first to save Stars.'};
  if (!Object.keys(m).every(k => ['type', 'action', 'operation', 'rank', 'requestId'].includes(k))
   || m.operation !== 'completeSolo'
   || !Number.isSafeInteger(m.rank) || m.rank < 1 || m.rank > 4
   || !rid(m.requestId)) {
   return {error: 'Invalid Paintball reward request.'};
  }
  const receipts = Array.isArray(profile.paintballReceipts) ? profile.paintballReceipts.slice() : [];
  const prior = receipts.find(r => r && r.id === m.requestId);
  if (prior) return {reward: Number(prior.stars) || 0, text: `Match reward: +${prior.stars} Stars!`};
  const lastAt = Number(profile.paintballSoloAt);
  if (Number.isFinite(lastAt) && now - lastAt < SOLO_COOLDOWN_MS) {
   return {error: 'Paintball Stars are cooling down. Play another full match in a moment.'};
  }
  const reward = rewardForRank(m.rank);
  const nextStars = Math.min(Number.MAX_SAFE_INTEGER, (Number(profile.stars) || 0) + reward);
  receipts.push({id: m.requestId, stars: reward});
  while (receipts.length > MAX_RECEIPTS) receipts.shift();
  if (!persist(profile, nextStars, receipts, now)) {
   return {error: 'Could not save your Paintball Stars right now.'};
  }
  return {reward, text: `Match reward: +${reward} Stars!`};
 }

 return {awardOnline, applySolo};
}
