import {readFileSync} from 'node:fs';

const MAX_RECEIPTS = 32;
const rid = x => typeof x === 'string' && /^[A-Za-z0-9_-]{8,64}$/.test(x);

export function rewardForRank(rank) {
 const r = Number(rank);
 if (r === 1) return 10;
 if (r === 2) return 7;
 return 5;
}

export function createPaintballRewards(store) {
 function persist(profile, nextStars, nextReceipts) {
  const prevStars = profile.stars;
  const prevReceipts = profile.paintballReceipts;
  profile.stars = nextStars;
  profile.paintballReceipts = nextReceipts;
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
  return persist(profile, nextStars, receipts) ? reward : 0;
 }

 return {awardOnline};
}
