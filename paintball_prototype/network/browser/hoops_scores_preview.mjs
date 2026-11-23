import {readFileSync} from 'node:fs';

// Only the completed result from the original server replay reaches this adapter.
// Account profiles share the original durable field/sort. Guests only have a score
// for the current cabinet visit, not a shared leaderboard entry.
export function createHoopsScores(accounts){
 const practice=new WeakMap();
 return {
  best(p){return (accounts?p.profile.hoopsBest?.score:practice.get(p))??null;},
  rows(){return accounts?accounts.hoopsLeaderboard():[];},
  leave(p){practice.delete(p);},
  record(p,run){
   if(!run.finished||!Number.isSafeInteger(run.score)||run.score<0||
      !Number.isSafeInteger(run.endsAt)||run.endsAt<0)throw Error('Expected verified round.');
   if(!accounts){practice.set(p,Math.max(run.score,practice.get(p)??0));return;}
   const old=p.profile.hoopsBest;
   // Retrying the original verified result is safe, including after a write failure.
   // A tied score keeps the earlier achievement timestamp.
   if(old&&old.score>=run.score)return;
   try{accounts.recordHoopsBest(p.profile,run.score,run.endsAt);}
   catch(error){
    // The legacy store writes the primary file before rotating its daily backup.
    // If only that last backup failed, do not claim the committed score was lost.
    let committed=false;
    try{
     const disk=JSON.parse(readFileSync(accounts.accountFile,'utf8'));
     const saved=disk.profiles?.[p.profile.username]?.hoopsBest;
     committed=saved?.score===run.score&&saved.finishedAt===run.endsAt;
    }catch{}
    if(!committed){p.profile.hoopsBest=old;throw error;}
   }
  }
 };
}

