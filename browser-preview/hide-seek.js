(() => {
  'use strict';
  const launchers=window.WillowbrookActivityLaunchers;
  if(!launchers)return;
  const panel=document.createElement('section'), title=document.createElement('strong'), line=document.createElement('p'), timer=document.createElement('span'), actions=document.createElement('div'), notice=document.createElement('div');
  panel.id='hide-seek-status';
  panel.hidden=true;
  panel.setAttribute('aria-label','Hide and Seek');
  title.textContent='Hide and Seek';
  line.setAttribute('aria-live','polite');
  timer.setAttribute('aria-label','Time remaining');
  notice.setAttribute('role','status');
  panel.append(title,line,timer,actions,notice);
  const blackout=document.createElement('div');
  blackout.addEventListener('contextmenu',e=>e.preventDefault());
  blackout.id='hide-seek-blackout';blackout.hidden=true;blackout.setAttribute('aria-hidden','true');
  const invite=document.createElement('section'), inviteBody=document.createElement('p'), inviteNotice=document.createElement('div');
  invite.id='hide-seek-invite';invite.hidden=true;invite.setAttribute('aria-label','Hide and Seek invitation');
  inviteBody.setAttribute('aria-live','polite');inviteNotice.setAttribute('role','status');
  invite.append(inviteBody);
  for(const [action,label] of [['accept','Join'],['decline','Not Now']]){
    const b=document.createElement('button');
    b.type='button';b.textContent=label;b.dataset.hideInvite=action;
    b.addEventListener('click',()=>{inviteNotice.textContent='';send?.(action);});
    invite.append(b);
  }
  invite.append(inviteNotice);
  document.body.append(blackout,panel,invite);
  let invitation='',inviteTimeout=0;
  function clearInvite(){
    clearTimeout(inviteTimeout);invitation='';invite.hidden=true;inviteNotice.textContent='';
    if(invite.contains(document.activeElement))document.getElementById('canvas')?.focus({preventScroll:true});
  }
  let send,launch=false,member=false,eligible=false,opened=false,lastDisplay='',lastText='',end=0;
  const buttons={};
  for(const [action,label] of [['join','Join'],['start','Start'],['leave','Leave'],['close','Close']]){
    const button=document.createElement('button');
    button.type='button';button.textContent=label;button.dataset.hideSeek=action;button.hidden=true;
    button.addEventListener('click',()=>{
      notice.textContent='';
      if(action==='close'){opened=false;render();}else send?.(action);
      document.getElementById('canvas')?.focus({preventScroll:true});
    });
    actions.append(button);buttons[action]=button;
  }
  let state={};
  function render(){
    panel.hidden=!(member || launch&&opened);
    if(panel.hidden)return;
    const {phase,role,memberCount,found,remaining,result}=state;
    let body='';
    if(!member)body='Start a Town game or join the waiting group. The first player to join is It.';
    else if(phase==='lobby')body=memberCount===1?'Waiting for someone to join.':memberCount+' players ready to play.';
    else if(phase==='hide')body=role==='seeker'?'Your eyes are closed while others hide':'Hide now! You have a 30-second head start.';
    else if(phase==='seek')body=!eligible?'Return to Town to keep playing.':role==='seeker'?'Find and tag the hiders. '+remaining+' left.':found?'You were found. Wait for the result.':'Stay hidden!';
    else if(phase==='results')body=result==='seeker'?'It found everyone!':result==='hiders'?'The hiders win!':'Round ended.';
    if(body!==lastText){line.textContent=body;lastText=body}
    const shown={join:!member,start:member&&eligible&&phase==='lobby'&&state.host===true&&memberCount>=2,leave:member,close:!member};
    for(const [key,val] of Object.entries(shown)){
      if(buttons[key].hidden===val){
        if(!val&&document.activeElement===buttons[key]) document.getElementById('canvas')?.focus({preventScroll:true});
        buttons[key].hidden=!val;
      }
    }
    buttons.leave.textContent=phase==='results'?'Done':'Leave';
    timer.hidden=phase!=='hide'&&phase!=='seek';
    updateTimer();
  }
  function updateTimer(){
    if(panel.hidden||timer.hidden)return;
    const t=Math.ceil(Math.max(0,end-performance.now())/1000);
    const text=Math.floor(t/60)+':'+String(t%60).padStart(2,'0');
    if(timer.textContent!==text)timer.textContent=text;
  }
  setInterval(updateTimer,250);
  window.WillowbrookHideSeek={
    bind(callback){send=callback;},
    blackout(on){
      const wasClosed=!blackout.hidden;
      blackout.hidden=!on;panel.classList.toggle('eyes-closed',on);
      if(wasClosed&&!on){
        const focused=document.activeElement;
        if(!focused||focused===document.body||focused===blackout)document.getElementById('canvas')?.focus({preventScroll:true});
      }
    },
    invite(id,host,remaining){
      if(invitation===id||remaining<=0)return;
      clearInvite();invitation=id;
      inviteBody.textContent=host+' started Hide and Seek. Want to join?';
      invite.hidden=false;
      inviteTimeout=setTimeout(clearInvite,Math.min(remaining,60000));
    },
    clearInvite,
    inviteFeedback(text){if(!invite.hidden)inviteNotice.textContent=String(text);},
    context(canLaunch,hasMembership,inArea){
      const changed=launch!==canLaunch;
      launch=canLaunch;member=hasMembership;eligible=inArea;
      if(changed)launchers.register('hide-and-seek','Hide and Seek',()=>{opened=!opened;notice.textContent='';render();},launch);
      if(!launch||member)opened=false;
      if(!launch&&!member)notice.textContent='';
      render();
    },
    update(encoded){
      const next=JSON.parse(encoded);
      const key=JSON.stringify(next);
      if(lastDisplay!==key){lastDisplay=key;state=next;end=performance.now()+Number(next.remainingMs||0);render();}
    },
    feedback(text){notice.textContent=String(text);}
  };
})();
