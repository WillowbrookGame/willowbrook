import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {mkdtemp,readFile,stat,rm} from 'node:fs/promises';
import {resolve,extname,sep,join} from 'node:path';
import os from 'node:os';

const root = resolve(process.argv[2]);
const held = new Set(['survivors','brick-breaker']);
const chrome = process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const noFile = new Set(), errors = [];
const fixture = '<!doctype html><canvas tabindex="0"></canvas><script src="./web-arcade/shell.js"></script>';
const types = {'.html':'text/html','.css':'text/css','.js':'text/javascript','.png':'image/png'};
const server=http.createServer(async(req,res)=>{
  const path=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
  if(path==='/' || path==='/fixture'){res.setHeader('Content-Type','text/html');res.end(fixture);return;}
  if(path==='/favicon.ico'){res.statusCode=204;res.end();return;}
  const full=resolve(root,'.'+path);
  try {
    if(!full.startsWith(root+sep)||(await stat(full)).isDirectory()) throw Error('not a file');
    res.setHeader('Content-Type',types[extname(full)]??'application/octet-stream');res.end(await readFile(full));
  } catch {noFile.add(path);res.statusCode=404;res.end();}
});
server.listen(0,'127.0.0.1');await once(server,'listening');
const tmp=await mkdtemp(join(os.tmpdir(),'willowbrook-arcade-chrome-'));
const proc=spawn(chrome,['--headless=new','--remote-debugging-port=0','--disable-extensions','--disable-background-networking','--enable-unsafe-swiftshader','--use-angle=swiftshader','--user-data-dir='+tmp,'about:blank'],{windowsHide:true,stdio:['ignore','ignore','pipe']});
proc.stderr.on('data', x=>process.stderr.write(x));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let ws;
try{
  const api = await waitFor(async()=>{try{return Number((await readFile(join(tmp,'DevToolsActivePort'),'utf8')).split('\n')[0]);}catch{return 0;}});
  const tab = (await (await fetch('http://127.0.0.1:'+api+'/json/list')).json()).find(t=>t.type==='page');
  ws=new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise(r=>ws.addEventListener('open',r,{once:true}));
  let last=0; const pending=new Map();
  ws.addEventListener('message',({data})=>{
    const m=JSON.parse(data);
    if(pending.has(m.id)){const [resolve,reject]=pending.get(m.id);pending.delete(m.id);m.error?reject(m.error):resolve(m.result);}
    if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.exception?.description??m.params.exceptionDetails.text);
  });
  const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++last;pending.set(id,[resolve,reject]);ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{
    const r=await call('Runtime.evaluate',{expression,returnByValue:true});
    if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);
    return r.result?.value;
  };
  await call('Runtime.enable');
  await call('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/fixture'});
  await waitFor(()=>evaluate('!!window.WillowbrookArcade'));
  await evaluate('document.querySelector("canvas").focus();window.sent=[];window.arcadeCloseCount=0;true');
  const expected = {
    'basketball':'HOOPS', 'memory':'Memory Match', 'road-hop':'Road Crossing',
    'maze-chase':'Blastemoids', 'claw':'Claw Machine', 'air-hockey':'Air Hockey',
    'brick-breaker':'Cosmic Breakout', 'survivors':'Basic Survivors',
  };
  const panel='document.querySelector("iframe").contentDocument.getElementById("arcadePanel")';
  for(const [id,name] of Object.entries(expected)){
    assert.equal(await evaluate('window.WillowbrookArcade.open('+JSON.stringify(id)+','+JSON.stringify(name)+',()=>arcadeCloseCount++,(packet,ticket)=>{sent.push(JSON.parse(packet));WillowbrookArcade.reportSent(ticket,true)},true)'),true);
    if (held.has(id)) {
      const instructions=await waitFor(()=>evaluate('document.querySelector("iframe")?.contentDocument?.getElementById("arcadeNetworkNotice")?.textContent'));
      assert.ok(instructions.includes('Coming soon')&&instructions.includes('Try another arcade game'),instructions);
      await evaluate('document.querySelector("iframe").contentDocument.dispatchEvent(new KeyboardEvent("keydown",{bubbles:true,key:"Escape"}));true');
      await waitFor(()=>evaluate('!window.WillowbrookArcade.isOpen()&&document.activeElement===document.querySelector("canvas")'));
      console.log('PASS held',id,'clear notice and returned focus');
      continue;
    }
    const heading=await waitFor(()=>evaluate('document.querySelector("iframe")?.contentDocument?.querySelector("#arcadePanel h2")?.textContent'));
    assert.ok(heading.includes(name),heading);
    assert.equal(await evaluate(panel+'.hidden'),false);
    await evaluate('[...'+panel+'.querySelectorAll("button")].find(b=>b.textContent==="Play").click();true');
    const loaded=await waitFor(()=>evaluate('(() => {const p='+panel+';return [...p.querySelectorAll("canvas")].some(c=>c.getClientRects().length>0)||[...p.querySelectorAll("div")].some(d=>d.shadowRoot?.querySelector("canvas"));})()'));
    assert.ok(loaded,'cabinet loaded: '+id);
    await sleep(250);
    const status=await evaluate(panel+'.textContent');
    assert.ok(!(status.includes('This cabinet could not load')||status.includes('This table could not load')),status);
    if(id==='air-hockey'){
      const join=await waitFor(()=>evaluate('sent.some(p=>p.type==="airHockey"&&p.action==="join")'));
      assert.ok(join,'original hockey sends join through parent transport');
    }
    if(id==='memory'){
      await evaluate(panel+'.querySelector("canvas").dispatchEvent(new KeyboardEvent("keydown",{bubbles:true,code:"Space",key:" "}));true');
    }
    if(id==='claw'){
      await evaluate('[...'+panel+'.querySelectorAll("button")].find(b=>b.textContent==="Done").click();true');
    } else {
      await evaluate(panel+'.dispatchEvent(new KeyboardEvent("keydown",{bubbles:true,code:"Escape",key:"Escape"}));true');
    }
    await waitFor(()=>evaluate('!window.WillowbrookArcade.isOpen()&&document.activeElement===document.querySelector("canvas")'));
    console.log('PASS original',id,'loaded and returned focus');
  }
  assert.equal(await evaluate('sent.some(p=>p.type==="airHockey"&&p.action==="leave")'),true);
  assert.equal(await evaluate('window.arcadeCloseCount'),8);
  await evaluate('sent.length=0;true');
  for(const [id,name] of Object.entries(expected)){
    assert.equal(await evaluate('window.WillowbrookArcade.open('+JSON.stringify(id)+','+JSON.stringify(name)+',()=>arcadeCloseCount++,(packet,ticket)=>{sent.push(JSON.parse(packet));WillowbrookArcade.reportSent(ticket,true)},false)'),true);
    if(held.has(id)){
      const instructions=await waitFor(()=>evaluate('document.querySelector("iframe")?.contentDocument?.getElementById("arcadeNetworkNotice")?.textContent'));
      assert.ok(instructions.includes('Coming soon'),instructions);
      await evaluate('document.querySelector("iframe").contentDocument.getElementById("arcadeNetworkNotice").querySelector("button").click();true');
    } else if(id==='air-hockey'){
      const instructions=await waitFor(()=>evaluate('document.querySelector("iframe")?.contentDocument?.getElementById("arcadeNetworkNotice")?.textContent'));
      assert.ok(instructions.includes('Multiplayer (M)')&&instructions.includes('sign in'),instructions);
      await evaluate('document.querySelector("iframe").contentDocument.getElementById("arcadeNetworkNotice").querySelector("button").click();true');
    } else {
      await waitFor(()=>evaluate('!!document.querySelector("iframe")?.contentDocument?.querySelector("#arcadePanel h2")'));
      await evaluate('[...'+panel+'.querySelectorAll("button")].find(b=>b.textContent==="Play").click();true');
      if(id==='basketball'){
        const hoopView='[...'+panel+'.querySelectorAll("div")].find(x=>x.shadowRoot?.getElementById("startBtn")).shadowRoot';
        await waitFor(()=>evaluate('!!'+hoopView+'.getElementById("startBtn")'));
        assert.match(await evaluate(panel+'.querySelector(".arcade-practice-note").textContent'), /Scores stay on this device/);
        await evaluate(hoopView+'.getElementById("startBtn").click();true');
        await waitFor(()=>evaluate(hoopView+'.getElementById("startScreen").classList.contains("hidden")'));
        await waitFor(()=>evaluate(Number(0) + ' || Number('+hoopView+'.getElementById("time").textContent)<60'));
      } else {
        await waitFor(()=>evaluate('(() => {const p='+panel+';return [...p.querySelectorAll("canvas")].some(c=>c.getClientRects().length>0)||[...p.querySelectorAll("div")].some(d=>d.shadowRoot?.querySelector("canvas"));})()'));
      }
      await evaluate(panel+'.dispatchEvent(new KeyboardEvent("keydown",{bubbles:true,code:"Escape",key:"Escape"}));true');
    }
    await waitFor(()=>evaluate('!window.WillowbrookArcade.isOpen()&&document.activeElement===document.querySelector("canvas")'));
    console.log('PASS guest',id,'without a network session');
  }
  assert.equal(await evaluate('window.arcadeCloseCount'),16);
  assert.deepEqual(await evaluate('sent'),[]);

  assert.deepEqual([...noFile],[]);
  assert.deepEqual(errors,[]);
} finally {
  ws?.close();
  proc.kill();
  await new Promise(r=>server.close(r));
  try{await rm(tmp,{recursive:true,force:true,maxRetries:2});}catch{}
}

async function waitFor(fn){
  let last;
  for(let i=0;i<160;i++){
    try{const r=await fn();if(r)return r;}catch(error){last=error;}
    await sleep(50);
  }
  throw Error('waitFor timed out '+(last??''));
}

