// SPDX-License-Identifier: MIT
// The optional HTTPS edge must preserve the exact browser Host and Origin,
// strip forwarding headers and connect over loopback. No implicit origin.
export function privateHttpsSite(origin) {
 if(origin==null)return null;
 if(typeof origin!=="string"||origin.length>260)throw Error("Invalid explicit Willowbrook HTTPS origin.");
 let url;
 try{url=new URL(origin);}catch{throw Error("Invalid explicit Willowbrook HTTPS origin.");}
 const hostname=url.hostname;
 const isDns=hostname.includes(".")&&hostname.split(".").every(x=>/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(x))&&/[a-z]/.test(hostname.split(".").at(-1));
 if(url.protocol!=="https:"||url.origin!==origin||!isDns||url.username||url.password||url.pathname!=="/"||url.search||url.hash)
  throw Error("Use the exact HTTPS DNS origin without a path, query, fragment, or credentials.");
 return Object.freeze({origin: url.origin,host:url.host});
}

export function requestMatchesSite(req,site,originRequired=false) {
 if(req.socket.remoteAddress!=="127.0.0.1")return false;
 const hosts=[],origins=[];
 for(let i=0;i<req.rawHeaders.length;i+=2){
  const name=req.rawHeaders[i].toLowerCase();
  if(name==="forwarded"||name.startsWith("x-forwarded-")||name==="x-original-host"||name==="x-original-url"||name==="x-rewrite-url")return false;
  if(name==="host")hosts.push(req.rawHeaders[i+1]);
  if(name==="origin")origins.push(req.rawHeaders[i+1]);
 }
 return hosts.length===1&&hosts[0]===site.host&&(origins.length===0&&!originRequired||origins.length===1&&origins[0]===site.origin);
}
