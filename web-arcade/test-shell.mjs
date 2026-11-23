import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

class Element {
  constructor(tag){this.tagName=tag.toUpperCase();this.style={};this.nodes=[];this.events={};this.isConnected=true;if(tag==='iframe')this.contentWindow={focus(){}}}
  setAttribute(){}
  append(...els){els.forEach(el=>{el.parent=this;this.nodes.push(el)})}
  prepend(el){el.parent=this;this.nodes.unshift(el)}
  addEventListener(e,f){this.events[e]=f}
  remove(){this.isConnected=false;if(this.parent)this.parent.nodes=this.parent.nodes.filter(el=>el!==this)}
  focus(){document.activeElement=this}
}
let timers=new Map(),id=0;
const canvas=new Element('canvas');
const document={currentScript:{src:'http://127.0.0.1/web-arcade/shell.js'},activeElement:canvas,body:new Element('body'),createElement:t=>new Element(t),querySelector:()=>canvas};
const window={addEventListener(){},dispatchEvent(){}};
const context={Event,window,document,location:{origin:'http://127.0.0.1'},URL,setTimeout(f){timers.set(++id,f);return id},clearTimeout(n){timers.delete(n)},requestAnimationFrame:fn=>fn()};
runInNewContext(readFileSync(new URL('./shell.js',import.meta.url),'utf8'),context);
const app=window.WillowbrookArcade, transport=window.WillowbrookArcadeTransport;
function getFrame(){return document.body.nodes[0].nodes.find(x=>x.tagName==='IFRAME')}
function getNotice(){return document.body.nodes[0].nodes.find(x=>x.tagName==='SECTION')}
let closed=0, pass=true, sends=0;
const send=(body,ticket)=>{assert.equal(JSON.parse(body).type,'airHockey');sends++;app.reportSent(ticket,pass)};
const packet=(type,n)=>JSON.stringify({type,n});
assert.equal(app.open('air-hockey','Air Hockey',()=>closed++,send,true),true);
const first=getFrame(),firstOwner=first.contentWindow;
const payloads=[];
firstOwner.arcadeReceive=x=>payloads.push(JSON.parse(x));
for(let i=0;i<24;i++) app.receive(packet('airHockeyFrame',i));
app.receive(packet('hoops88',999));
app.receive('this is not a packet');
app.receive(packet('airHockeyFrame','s'.repeat(65536)));
assert.equal(payloads.length,0);
assert.equal(app.ready(firstOwner),true);
assert.equal(app.ready(firstOwner),false);
assert.deepEqual(payloads.map(x=>x.n),Array.from({length:16},(_,i)=>i+8));
assert.equal(transport.send({type:'airHockey',action:'join'},firstOwner),true);
pass=false;
assert.equal(transport.send({type:'airHockey',action:'join'},firstOwner),false);
assert.equal(transport.send({type:'hoops88'},firstOwner),false);
assert.equal(sends,2);
assert.equal(app.close(),true);
assert.equal(document.activeElement,canvas);
assert.equal(app.open('air-hockey','Air Hockey',()=>closed++,send,true),true);
app.receive(packet('airHockeyFrame',100));
assert.equal(transport.send({type:'airHockey'},firstOwner),false);
assert.equal(app.ready(firstOwner),false);
assert.equal(app.fail(firstOwner),undefined);
for(const fn of timers.values()) fn();
const notice=getNotice();
const retry=notice.nodes.find(x=>x.textContent==='Retry');
assert.equal(retry.hidden,false);
assert.match(notice.nodes.find(x=>x.tagName==='P').textContent,/did not load/);
retry.events.click();
const newFrame=getFrame();
assert.ok(newFrame);
const received=[];
newFrame.contentWindow.arcadeReceive=x=>received.push(JSON.parse(x).n);
assert.equal(app.ready(newFrame.contentWindow),true);
assert.deepEqual(received,[]);
app.receive(packet('airHockeyFrame',101));
assert.deepEqual(received,[101]);
app.close();assert.equal(closed,2);
assert.equal(timers.size,0);
console.log('PASS bridge bounded early queue, late frame rejection, verified send results, loading timeout and retry isolation, close and focus');
