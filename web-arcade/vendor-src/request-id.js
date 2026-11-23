// Non-secret idempotency identifiers; never use these as credentials.
let sequence=0;
export function requestId(cryptoApi=globalThis.crypto){
 try{if(typeof cryptoApi?.randomUUID==='function')return cryptoApi.randomUUID();}catch{}
 try{if(typeof cryptoApi?.getRandomValues==='function'){const bytes=new Uint8Array(16);cryptoApi.getRandomValues(bytes);return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');}}catch{}
 sequence=(sequence+1)%Number.MAX_SAFE_INTEGER;return 'req_'+Date.now().toString(36)+'_'+sequence.toString(36)+'_'+Math.random().toString(36).slice(2,14);
}
