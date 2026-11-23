// Ephemeral family chat; no message content retained, logged or persisted.

const maxRawCodeUnits=640, maxCharacters=160, waitMs=2000, maxRecentAccounts=1024;
const error=(code,text)=>({type:'chatError',code,text});

export function createFamilyChat({enabled=false,policy=()=>true,authorized,send,peers}) {
 let on=enabled===true;
 const recent=new Map();
 const effective=()=>on&&policy()===true;
 const available=p=>effective()&&!!p&&authorized(p);
 function update(p) {
  const now=available(p);
  if (p.chatAvailable!==now) {
   p.chatAvailable=now;
   send(p,{type:'chatStatus',available:now});
  }
 }
 function refresh(){
  if(!effective())recent.clear();
  for(const p of peers())if(authorized(p)||p.chatAvailable===true)update(p);
 }
 function disable() {
  if (!on) return;
  on=false;
  refresh();
 }
 function handle(p,message,now) {
  const tell=(code,text)=>send(p,error(code,text));
  if (!available(p)) {tell('unavailable','Family chat is only available to signed-in family.');return;}
  if (Object.keys(message).length!==2||!Object.hasOwn(message,'text')
      ||typeof message.text!=='string'||message.text.length>maxRawCodeUnits) {
   tell('invalid','Enter a plain-text message of 1 to 160 characters.');return;
  }
  // Replace isolated surrogates before cleaning so all counted values are Unicode scalars.
  const clean=message.text.toWellFormed().replace(/[\p{Cc}\p{Cf}]/gu,'').replace(/[\u2028\u2029]/gu,' ').trim();
  if (!clean||Array.from(clean).length>maxCharacters) {
   tell('invalid','Enter a plain-text message of 1 to 160 characters.');return;
  }
  const id=p.profile.id, name=p.profile.username;
  if (!Number.isSafeInteger(id)||id<1||typeof name!=='string'||!/^[a-z0-9_-]{3,20}$/i.test(name)) return;
  for (const [key,readyAt] of recent) if (now>=readyAt) recent.delete(key);
  if (recent.has(id)||recent.size>=maxRecentAccounts) {
   tell('rate','Wait two seconds between chat messages.');return;
  }
  recent.set(id,now+waitMs);
  const packet={type:'chat',from:name,text:clean};
  for (const q of peers()) if (available(q)) send(q,packet);
 }
 return {available,update,refresh,disable,handle};
}
