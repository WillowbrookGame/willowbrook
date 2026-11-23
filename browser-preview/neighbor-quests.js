
(() => {
  'use strict';
  const routes = ['gardener', 'librarian'];
  const make = (tag, text='') => { const e=document.createElement(tag); e.textContent=text; return e; };
  const launch=make('button','Neighbor quests');
  launch.id='neighbor-quests-open'; launch.hidden=true;
  const dlg=make('dialog');
  dlg.id='neighbor-quests-dialog'; dlg.setAttribute('aria-labelledby','neighbor-quests-title');
  const title=make('h2','Help your neighbors'); title.id='neighbor-quests-title';
  const intro=make('p','Choose an optional route. Finish three stops to earn Stars.');
  const steps=make('p'); steps.id='neighbor-quests-current';
  const status=make('p'); status.id='neighbor-quests-status'; status.setAttribute('role','status');
  const actions=make('div'); actions.className='neighbor-quest-actions';
  const close=make('button','Close quests');
  for(const b of [launch,close])b.type='button';
  dlg.append(title,intro,steps,status,actions,close);
  document.body.append(launch,dlg);
  let bind=null, context=false, town=false, state=null, pending=false, locked=false, clockAt=0;
  const cooldownRows=new Map();
  function show(open){
    if(open&&!dlg.open){dlg.showModal();close.focus();}
    if(!open&&dlg.open){dlg.close();if(!launch.hidden)launch.focus();else document.getElementById("canvas")?.focus();}
  }
  function askClose(){bind?.toggle(false);}
  function button(label, action, route, disabled=false){
    const b=make('button',label); b.type='button'; b.disabled=disabled;
    b.addEventListener('click',()=>bind?.action(action,route)); actions.append(b); return b;
  }
  function draw(){
    const focus=actions.contains(document.activeElement)?document.activeElement.textContent:null;
    actions.replaceChildren();cooldownRows.clear();
    steps.textContent='';
    if(!context||!state?.available)return;
    if(pending){
      steps.textContent=state.current?.marker?.label??'Checking your last quest action.';
      button('Retry last quest action','retry','',locked);
    }else if(state.current){
      const c=state.current;
      steps.textContent='Stop '+(c.step+1)+' of 3: '+c.marker.label;
      if(town)button('Visit next stop','visit',c.route);
      button('Complete this step','step',c.route);
      button('Cancel route','cancel',c.route);
    }else{
      for(const r of state.routes??[]){
        if(!routes.includes(r.route))continue;
        const group=make('p');
        actions.append(group);
        const controls=[];
        if(town)controls.push(button('Visit '+r.label+' start','visit',r.route));
        controls.push(button('Start '+r.label+' route','start',r.route));
        cooldownRows.set(r.route,{r,group,controls});
      }
    }
    refreshCooldowns();
    if(focus)([...actions.querySelectorAll('button')].find(b=>b.textContent===focus&&!b.disabled)??close).focus();
  }
  close.addEventListener('click',askClose);
  dlg.addEventListener('cancel',e=>{e.preventDefault();askClose();});
  launch.addEventListener('click',()=>bind?.toggle(true));
  function refreshCooldowns(){
    for(const {r,group,controls} of cooldownRows.values()){
      const seconds=Math.max(0,Math.ceil((r.waitMs-(performance.now()-clockAt))/1000));
      const text=r.label+' route | '+r.reward+' Stars'+(seconds?' | Wait '+seconds+'s':'');
      if(group.textContent!==text)group.textContent=text;
      for(const control of controls)if(control.disabled!==(seconds>0))control.disabled=seconds>0;
    }
  }
  setInterval(()=>{if(dlg.open)refreshCooldowns();},500);
  window.WillowbrookNeighborQuests={
    bind(toggle,action){bind={toggle,action};},
    setContext(visible,inTown,showLauncher=true){
      context=visible===true;town=inTown===true;
      launch.hidden=!context||showLauncher!==true;
      if(!context)show(false);
      draw();
    },
    setOpen:show,
    setState(json){try{state=JSON.parse(json);clockAt=performance.now();draw();}catch{state=null;}},
    setPending(value,cooldown){pending=value===true;locked=cooldown===true;draw();},
    feedback(text){status.textContent=text;}
  };
})();

