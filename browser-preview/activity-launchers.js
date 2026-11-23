(() => {
  'use strict';
  const nav=document.createElement('nav');
  nav.id='town-activity-launchers';nav.hidden=true;
  nav.setAttribute('aria-label','Town activities');
  const list=document.createElement('div');
  list.id='town-activity-buttons';list.className='activity-grid';
  const more=document.createElement('button');
  more.type='button';more.id='town-activity-more';more.hidden=true;
  more.setAttribute('aria-controls',list.id);
  nav.append(list,more);document.body.append(nav);
  const items=new Map();
  let owner='',activate=null,layout=null,context=false,expanded=false;
  const chat=document.getElementById('family-chat-toggle');
  function measure(){
    const width=chat?.getClientRects().length?Math.max(44,Math.floor(chat.getBoundingClientRect().left-20)):322;
    const value=width+'px';
    if(nav.style.getPropertyValue('--activity-chat-limit')!==value)nav.style.setProperty('--activity-chat-limit',value);
    layout?.(nav.hidden?0:nav.getBoundingClientRect().bottom);
  }
  const observer=new ResizeObserver(measure);
  observer.observe(nav);
  if(chat)observer.observe(chat);
  window.addEventListener('resize',measure);
  const button=(id,label)=>{
    const b=document.createElement('button');
    b.type='button';b.dataset.activity=id;b.textContent=label;return b;
  };
  function draw(){
    const available=[...items.values()].filter(x=>x.eligible);
    const showing=context&&available.length>0;
    const oldKey=document.activeElement?.dataset.activity;
    const focusLost=!!oldKey&&list.contains(document.activeElement);
    if(!showing||available.length<=4)expanded=false;
    nav.hidden=!showing;
    more.hidden=!showing||available.length<=4;
    more.textContent=expanded?'▴':'▾';
    more.setAttribute('aria-label',expanded?'Show fewer activities':'Show more activities');
    more.setAttribute('aria-expanded',String(expanded));
    list.replaceChildren(...(expanded?available:available.slice(0,4)).map(x=>x.button));
    measure();
    if(focusLost){
      const same=[...list.children].find(b=>b.dataset.activity===oldKey);
      if(same&&!nav.hidden)same.focus();
      else if(!more.hidden)more.focus();
      else document.getElementById('canvas')?.focus();
    }
  }
  function register(id,label,action,eligible=true){
    const old=items.get(id);
    if(old){old.eligible=eligible===true;old.action=action;old.button.textContent=label;}
    else{
      const b=button(id,label);
      const item={button:b,eligible:eligible===true,action};
      b.addEventListener('click',()=>item.action());
      items.set(id,item);
    }
  }
  register('getting-started','Getting Started',()=>activate?.('getting-started'),false);
  register('neighbor-quests','Neighbor Quests',()=>activate?.('neighbor-quests'),false);
  more.addEventListener('click',()=>{expanded=!expanded;draw();});
  window.WillowbrookActivityLaunchers={
    bindTown(id,cb,reportLayout){owner=id;activate=cb;layout=reportLayout;context=false;expanded=false;draw();},
    setTown(id,visible,starter,quests){
      if(id!==owner)return;
      const a=items.get('getting-started'),b=items.get('neighbor-quests');
      if(context===(visible===true)&&a.eligible===(starter===true)&&b.eligible===(quests===true))return;
      context=visible===true;a.eligible=starter===true;b.eligible=quests===true;draw();
    },
    clearTown(id){if(id===owner){owner='';activate=null;layout=null;context=false;expanded=false;draw();}},
    register(id,label,action,eligible=true){register(id,label,action,eligible);draw();},
    unregister(id){if(!['getting-started','neighbor-quests'].includes(id)){items.delete(id);draw();}}
  };
})();