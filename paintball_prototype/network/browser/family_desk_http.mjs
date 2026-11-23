// Loopback-only same-origin HTTP adapter. It never logs URLs, bodies, or cookies.
const prefix='/api/family-desk/';
const token=/^[A-Za-z0-9_-]{32}$/;
function fail(text,status=400){throw Object.assign(new Error(text),{deskError:true,status});}
function body(req){
 return new Promise((yes,no)=>{
  let n=0,parts=[],tooLarge=false;
  req.on('data',p=>{n+=p.length;if(n>2048){tooLarge=true;parts=[];}else if(!tooLarge)parts.push(p);});
  req.on('error',()=>no(Object.assign(new Error('Invalid request.'),{deskError:true,status:400})));
  req.on('end',()=>{
   if(tooLarge){no(Object.assign(new Error('Request too large.'),{deskError:true,status:413}));return;}
   try{
    const data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(parts)));
    if(!data||typeof data!=='object'||Array.isArray(data))throw Error();
    yes(data);
   }catch{no(Object.assign(new Error('Invalid request.'),{deskError:true,status:400}));}
  });
 });
}
function cookie(req,name){
 const rows=(req.headers.cookie??'').split(';').map(x=>x.trim()).filter(x=>x.startsWith(name+'='));
 const value=rows.length===1?rows[0].slice(name.length+1):null;
 return value&&token.test(value)?value:null;
}
export function createDeskHttp({desk,address,clock=Date.now}) {
 const buckets=new Map();
 const openActions=new Set(['login','redeem-parent','redeem-player','redeem-reset']);
 function grant(name,limit) {
  const now=clock(),times=(buckets.get(name)??[]).filter(t=>now-t<60000);
  if(times.length>=limit)fail('Too many requests. Try again in a minute.',429);
  times.push(now);buckets.set(name,times);
 }
 return async(req,res)=>{
  if(!req.url?.startsWith('/api/family-desk'))return false;
  const send=(status,data,extra={})=>{
   res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff',...extra});
   res.end(JSON.stringify(data));
  };
  try {
   if(!desk||!req.url.startsWith(prefix)||!/^\/api\/family-desk\/[a-z-]{1,24}$/.test(req.url))fail('Not found.',404);
   const local=address();
   if(local?.address!=='127.0.0.1'||req.socket.remoteAddress!=='127.0.0.1')fail('Not found.',404);
   const host='127.0.0.1:'+local.port,origin='http://'+host,cName='willowbrook_desk_'+local.port;
   const header=req.headers['sec-fetch-site'];
   if(req.headers.forwarded||Object.keys(req.headers).some(k=>k.startsWith('x-forwarded-'))||req.headers.host!==host||req.headers['x-willowbrook-desk']!=='1'||(header&&header!=='same-origin')||(req.headers.origin&&req.headers.origin!==origin))fail('Same-origin desk request required.',403);
   const action=req.url.slice(prefix.length);
   const current=cookie(req,cName),actor=desk.authenticate(current);
   if(req.method==='GET'&&action==='state'){grant('state',120);send(200,{ok:true,...desk.status(actor)});return true;}
   if(req.method!=='POST'||req.headers.origin!==origin||!/^application\/json(?:;\s*charset=utf-8)?$/i.test(req.headers['content-type']??''))fail('Use a same-origin JSON request.',403);
   grant(openActions.has(action)?'open':'auth',openActions.has(action)?18:90);
   if(!openActions.has(action)){
    if(!actor)fail('Sign in to the desk first.',401);
    if(req.headers['x-willowbrook-csrf']!==actor.csrf)fail('Desk security token missing.',403);
   }
   if(Number(req.headers['content-length'])>2048)fail('Request too large.',413);
   const data=await body(req);
   if(!openActions.has(action)&&!desk.authenticate(current))fail('Sign in to the desk first.',401);
   if(action==='login'){
    if(Object.keys(data).length!==2||!Object.hasOwn(data,'username')||!Object.hasOwn(data,'password'))fail('Desk sign-in failed.',401);
    const session=desk.login(data.username,data.password);
    send(200,{ok:true,...desk.status(session.actor)},{'Set-Cookie':cName+'='+session.secret+'; Path=/api/family-desk/; HttpOnly; SameSite=Strict; Max-Age=14400'});
    return true;
   }
   if(action==='logout'){
    if(Object.keys(data).length)fail('Invalid logout request.');
    desk.logout(current);send(200,{ok:true,role:null},{'Set-Cookie':cName+'=; Path=/api/family-desk/; HttpOnly; SameSite=Strict; Max-Age=0'});return true;
   }
   const result=desk.action(action,actor,data);send(200,{ok:true,...result});
  }catch(e){
   // Do not send errors produced by disk/crypto/parser internals to the browser.
   if(!res.headersSent)send(e?.deskError===true?e.status:503,{ok:false,error:e?.deskError===true?e.message:'Family Desk is temporarily unavailable.'});
   else res.destroy();
  }
  return true;
 };
}
