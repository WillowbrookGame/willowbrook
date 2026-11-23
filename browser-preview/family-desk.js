(() => {
  'use strict';
  const by=id=>document.getElementById(id);
  const avatars=[...'abcdefg'].map(x=>'male-'+x).concat([...'abcdef'].map(x=>'female-'+x),['alien','knight','raider','robot','soldier','worker','zombie']);
  const choices=new Set(['parent-login','parent-invite','player-invite','player-reset']);
  let session=null, inviteId=null, busy=false;
  const notice=text=>{by('announcement').textContent=text};
  function choose(id) {
    if(!choices.has(id)) return;
    for(const section of document.querySelectorAll('.choice')) section.hidden=section.id!==id;
    for(const button of document.querySelectorAll('[data-choice]')) button.setAttribute('aria-pressed',String(button.dataset.choice===id));
  }
  function element(tag,text) {
    const n=document.createElement(tag);
    if(text!==undefined) n.textContent=text;
    return n;
  }
  const displayAvatar=id=>id.startsWith('male-')?'Boy '+id.slice(-1).toUpperCase():id.startsWith('female-')?'Girl '+id.slice(-1).toUpperCase():id[0].toUpperCase()+id.slice(1);
  for(const box of document.querySelectorAll('[data-avatars]')) {
    for(const id of avatars) {
      const tile=element('label'), picture=element('img'), name=element('span',displayAvatar(id)), radio=element('input');
      radio.type='radio';radio.name='avatar';radio.value=id;radio.required=true;radio.defaultChecked=id===avatars[0];radio.checked=radio.defaultChecked;
      picture.src='./avatar-thumbs/'+id+'.webp';picture.alt='';picture.loading='lazy';picture.onerror=()=>picture.remove();
      tile.append(picture,name,radio);box.append(tile);
    }
  }
  async function req(path,data) {
    const h={'X-Willowbrook-Desk':'1'};
    if(data!==undefined){h['Content-Type']='application/json';if(session?.csrf)h['X-Willowbrook-Csrf']=session.csrf;}
    const r=await fetch('./api/family-desk/'+path,{method:data===undefined?'GET':'POST',headers:h,credentials:'same-origin',cache:'no-store',redirect:'error',body:data===undefined?undefined:JSON.stringify(data)});
    if(path==='state'&&r.status===404) return null;
    const v=await r.json().catch(()=>null);
    if(!r.ok||!v?.ok) throw Error(typeof v?.error==='string'?v.error:'The local Family Desk didn’t respond. Try again.');
    return v;
  }
  function hideCode() {
    inviteId=null;by('code').textContent='';by('code-expiry').textContent='';by('secret').hidden=true;
  }
  function showCode(value,purpose) {
    inviteId=value.inviteId;
    by('code-heading').textContent=purpose+' code';
    by('code').textContent=value.code;
    const expiry=new Date(value.expiresAt);
    by('code-expiry').textContent=Number.isFinite(expiry.getTime())?'Expires '+expiry.toLocaleString():'It expires soon.';
    by('secret').hidden=false;
    by('revoke-code').hidden=typeof inviteId!=='string';
    by('forget-code').focus({preventScroll:true});
  }
  async function pending() {
    const list=by('pending-invites');
    list.replaceChildren();
    let count=0;
    for(const invite of session?.pendingInvites??[]) {
      if(typeof invite.id!=='string') continue;
      const row=element('li'), expire=new Date(invite.expiresAt);
      row.textContent='Unused '+String(invite.purpose)+' code'+(Number.isFinite(expire.getTime())?' · expires '+expire.toLocaleString():'');
      const revoke=element('button','Revoke');
      revoke.type='button';revoke.className='secondary';
      revoke.addEventListener('click',()=>run(revoke,async()=>{await req('revoke-invite',{inviteId:invite.id});if(invite.id===inviteId)hideCode();await refresh();notice('Code revoked.');}));
      row.append(' ',revoke);list.append(row);count++;
    }
    by('pending').hidden=!count;
  }
  function renderPlayers(players=[]) {
    const list=by('player-roster');
    list.replaceChildren();
    if(!players.length) list.append(element('li','No players yet. Make a player invite to get started.'));
    for(const p of players) {
      const card=element('li'), heading=element('strong',p.nickname), meta=element('p',(avatars.includes(p.avatar)?displayAvatar(p.avatar):'Character')+' · '+(p.playEnabled?'Play allowed':'Play suspended')+' · '+(p.chatEnabled?'Chat allowed':'Chat off'));
      const actions=element('div');actions.className='permissions';
      const play=element('button',p.playEnabled?'Suspend play':'Allow play');play.type='button';
      const chat=element('button',p.chatEnabled?'Turn chat off':'Allow family chat');chat.type='button';
      const reset=element('button','Make reset code');reset.type='button';reset.className='secondary';
      const set=(button,change)=>run(button,async()=>{await req('player-permissions',{id:p.id,...change});await refresh();notice('Permissions saved for '+p.nickname+'.');});
      play.addEventListener('click',()=>set(play,{playEnabled:!p.playEnabled}));
      chat.addEventListener('click',()=>set(chat,{chatEnabled:!p.chatEnabled}));
      reset.addEventListener('click',()=>run(reset,async()=>{
        if(!confirm('Reset '+p.nickname+'’s password? This immediately signs the player out.')) return;
        const result=await req('reset-player',{id:p.id});await refresh();showCode(result,'Password reset');notice('Player signed out. Give the reset code privately.');
      }));
      actions.append(play,chat,reset);card.append(heading,meta,actions);list.append(card);
    }
  }
  function render() {
    const role=session?.role;
    by('guest').hidden=!session||Boolean(role);
    by('owner').hidden=role!=='owner';by('parent').hidden=role!=='parent';by('logout').hidden=!role;
    if(role==='parent') renderPlayers(session.players);
    const state=session?.globalChat;
    const control=by('global-chat');
    control.disabled=role!=='owner'||state?.canEnable!==true;
    control.textContent=state?.enabled?'Turn off chat for everyone':'Turn on chat for everyone';
    by('global-chat-state').textContent=state?.enabled?'Family Chat is on for players who are allowed to use it.':state?.canEnable===false?'Family Chat is off because this preview was started without it.':'Family Chat is off for everyone.';
    by('parent-chat-global-off').hidden=role!=='parent'||state?.enabled!==false;
    void pending();
  }
  async function refresh(){session=await req('state');render();return session;}
  async function run(button,action) {
    if(busy)return;
    busy=true;button.disabled=true;notice('Working…');
    try{await action();if(by('announcement').textContent==='Working…') notice('');}
    catch(e){notice(e?.message||'Try again.');}
    finally{busy=false;button.disabled=false;}
  }
  const onForm=(id,action)=>by(id).addEventListener('submit',ev=>{
    ev.preventDefault();const form=ev.currentTarget;
    run(ev.submitter||form.querySelector('button'),async()=>{
      try{await action(Object.fromEntries(new FormData(form)),form);}
      finally{for(const field of form.querySelectorAll('input[type=password], input[name=code]'))field.value='';}
    });
  });
  for(const item of document.querySelectorAll('[data-choice]')) item.addEventListener('click',()=>{choose(item.dataset.choice);notice('');});
  choose(location.hash.slice(1)||'parent-login');
  for(const input of document.querySelectorAll('[name=nickname], #invite-parent [name=username]')) {
    input.pattern='[a-zA-Z0-9_\\-]{3,20}';
    input.title='Use 3 to 20 letters, numbers, dashes, or underscores.';
  }
  for(const input of document.querySelectorAll('input[autocomplete=new-password]')){
    input.minLength=10;input.maxLength=100;
  }
  onForm('login',async(info,form)=>{session=await req('login',info);render();form.reset();notice('Signed in.');});
  onForm('invite-parent',async(info,form)=>{const result=await req('invite-parent',info);form.reset();await refresh();showCode(result,'Parent invite');notice('Parent invite ready.');});
  by('global-chat').addEventListener('click',ev=>run(ev.currentTarget,async()=>{
    if(session?.role!=='owner'||session.globalChat?.canEnable!==true)return;
    const enabled=!session.globalChat.enabled;
    const result=await req('global-chat',{enabled});
    session.globalChat=result.globalChat;
    render();
    notice(result.globalChat.enabled?'Family Chat is on for allowed players.':'Family Chat is off for everyone.');
  }));
  by('invite-player').addEventListener('click',ev=>run(ev.currentTarget,async()=>{const result=await req('invite-player',{});await refresh();showCode(result,'Player invite');notice('Player invite ready.');}));
  onForm('redeem-parent',async(info,form)=>{const r=await req('redeem-parent',info);form.reset();choose('parent-login');by('login').elements.username.value=r.username;
    notice('Parent account ready. Sign in with the password you just chose.');by('login').elements.password.focus();});
  onForm('redeem-player',async(info,form)=>{await req('redeem-player',info);form.reset();choose('parent-login');notice('Your player is ready! Go back to Willowbrook and sign in with your nickname and password.');document.querySelector('.home').focus();});
  onForm('redeem-reset',async(info,form)=>{await req('redeem-reset',info);form.reset();notice('Password changed. You can go back to Willowbrook and sign in.');document.querySelector('.home').focus();});
  onForm('create-player',async(info,form)=>{await req('create-player',info);form.reset();await refresh();notice('Player created.');});
  by('forget-code').addEventListener('click',()=>{hideCode();notice('Code hidden. You can revoke unused codes below.');});
  by('revoke-code').addEventListener('click',ev=>run(ev.currentTarget,async()=>{if(!inviteId)return;await req('revoke-invite',{inviteId});hideCode();await refresh();notice('Code revoked.');}));
  by('logout').addEventListener('click',ev=>run(ev.currentTarget,async()=>{await req('logout',{});session=null;hideCode();by('player-roster').replaceChildren();render();await refresh();notice('Signed out.');}));
  refresh().then(s=>notice(s?'':'Family Desk is not enabled on this preview.')).catch(()=>notice('Family Desk is unavailable. Go back to Willowbrook and try again later.'));
})();
