// Global Pulse — server-side article extractor. Pulls a 2-3 paragraph blurb + images
// from a news article URL (no CORS issues, runs server-side). Best-effort: returns
// whatever it can scrape from og: tags + the article body.
//
// Security notes: the URL is caller-supplied, so it is restricted to public http(s)
// hosts (no loopback/private/link-local/metadata addresses, re-checked on every
// redirect hop), the body read is size-capped, and all HTML scanning is linear-time
// (indexOf based) so a hostile page cannot pin the function CPU.

const dns = require('dns');
const net = require('net');

const MAX_BYTES = 600000;      // max bytes of the remote page we will read
const MAX_REDIRECTS = 4;
const MAX_URL_LEN = 2048;
const MAX_TAG_LEN = 2000;      // ignore absurdly long tags when scraping meta/img

function decodeEntities(s){
  if(!s) return '';
  return s.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"')
    .replace(/&#0?39;|&apos;|&#x27;/g,"'").replace(/&nbsp;/g,' ').replace(/&hellip;/g,'…')
    .replace(/&mdash;/g,'—').replace(/&ndash;/g,'–').replace(/&rsquo;/g,'’').replace(/&lsquo;/g,'‘')
    .replace(/&ldquo;/g,'“').replace(/&rdquo;/g,'”')
    .replace(/&#(\d+);/g,(_,n)=>String.fromCharCode(+n))
    .replace(/&#x([0-9a-f]+);/gi,(_,n)=>String.fromCharCode(parseInt(n,16)));
}
// Remove <...> tags (replaced by a space) with a single linear pass.
function stripTags(s){
  let out='', pos=0;
  for(;;){
    const i=s.indexOf('<',pos); if(i<0) break;
    const j=s.indexOf('>',i+1); if(j<0) break;          // no closer anywhere after: nothing more to strip
    if(j===i+1){ out+=s.slice(pos,i+1); pos=i+1; continue; }   // "<>" is not a tag
    out+=s.slice(pos,i)+' '; pos=j+1;
  }
  return out+s.slice(pos);
}
function clean(frag){ return decodeEntities(stripTags(String(frag||''))).replace(/\s+/g,' ').trim(); }
// Resolve to an absolute http(s) URL only (javascript:, data:, etc. are dropped).
function abs(src,base){ if(!src) return ''; try{ const u=new URL(src, base); return (u.protocol==='http:'||u.protocol==='https:')?u.href:''; }catch(e){ return ''; } }
function host(u){ try{ return new URL(u).hostname.replace(/^www\./,''); }catch(e){ return ''; } }
// ASCII-only lowercase: keeps string length identical so indexes map back onto the original.
function asciiLower(s){ return s.replace(/[A-Z]/g,c=>String.fromCharCode(c.charCodeAt(0)+32)); }

// ---- linear-time HTML scanning helpers -------------------------------------------------
// Remove whole <tag ...>...</tag> blocks. If a tag has an opener but no closer, no later
// opener can have one either, so we stop (this is what keeps it linear).
function stripBlocks(body){
  for(const tag of ['script','style','figure','aside','nav','header','footer']){
    const lower=asciiLower(body), open='<'+tag, close='</'+tag;
    const parts=[]; let pos=0;
    for(;;){
      const i=lower.indexOf(open,pos); if(i<0) break;
      const j=lower.indexOf(close,i); if(j<0) break;
      const k=lower.indexOf('>',j); if(k<0) break;
      parts.push(body.slice(pos,i),' '); pos=k+1;
    }
    if(parts.length){ parts.push(body.slice(pos)); body=parts.join(''); }
  }
  return body;
}
// Raw <p>...</p> fragments in document order (capped so work stays bounded).
function paragraphsOf(body,max){
  const lower=asciiLower(body), out=[]; let pos=0;
  while(out.length<max){
    const i=lower.indexOf('<p',pos); if(i<0) break;
    const g=lower.indexOf('>',i); if(g<0) break;
    const c=lower.indexOf('</p>',g+1); if(c<0) break;
    out.push(body.slice(g+1,c)); pos=c+4;
  }
  return out;
}
// Find the end (index of '>') of the tag starting at i, honouring quoted attribute values
// (a '>' inside content="..." must not end the tag). Falls back to the first '>'.
function tagEnd(s,i){
  const lim=Math.min(s.length,i+MAX_TAG_LEN); let q='';
  for(let p=i+1;p<lim;p++){
    const ch=s[p];
    if(q){ if(ch===q) q=''; }
    else if(ch==='"'||ch==="'") q=ch;
    else if(ch==='>') return p;
  }
  const g=s.indexOf('>',i); return (g>=0 && g-i<MAX_TAG_LEN)? g : -1;
}
function metaTags(html){
  const lower=asciiLower(html), tags=[]; let pos=0;
  for(let tries=0;tries<400;tries++){          // bounded attempts keep the scan linear
    const i=lower.indexOf('<meta',pos); if(i<0) break;
    if(html.indexOf('>',i)<0) break;
    const e=tagEnd(html,i); if(e<0){ pos=i+5; continue; }
    const attrs=[]; const re=/([a-zA-Z:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g; let m;
    const tag=html.slice(i+5,e);
    while((m=re.exec(tag))) attrs.push({ n:m[1].toLowerCase(), v:m[2]!==undefined?m[2]:m[3], at:m.index });
    tags.push(attrs); pos=e+1;
  }
  return tags;
}
function metaOf(tags,prop){
  prop=prop.toLowerCase();
  // pass 1: property/name before content; pass 2: content before property/name (as before)
  for(const order of [0,1]){
    for(const attrs of tags){
      const k=attrs.find(a=>(a.n==='property'||a.n==='name') && a.v.toLowerCase()===prop);
      const c=attrs.find(a=>a.n==='content');
      if(!k||!c) continue;
      if(order===0 ? k.at<c.at : c.at<k.at) return decodeEntities(c.v);
    }
  }
  return '';
}
function titleOf(html){
  const lower=asciiLower(html);
  const i=lower.indexOf('<title'); if(i<0) return '';
  const g=lower.indexOf('>',i); if(g<0) return '';
  const c=lower.indexOf('</title>',g+1); if(c<0) return '';
  return clean(html.slice(g+1,c));
}
function articleOf(html){
  const lower=asciiLower(html);
  const i=lower.indexOf('<article'); if(i<0) return '';
  const c=lower.indexOf('</article>',i); if(c<0) return '';
  return html.slice(i,c+10);
}
function imagesOf(body,base,images,max){
  const lower=asciiLower(body); let pos=0;
  const sre=/(?:data-src|src)=["']([^"']+)["']/i;
  while(images.length<max){
    const i=lower.indexOf('<img',pos); if(i<0) break;
    const g=body.indexOf('>',i); if(g<0) break;
    pos=g+1; if(g-i>MAX_TAG_LEN) continue;
    const m=sre.exec(body.slice(i+4,g)); if(!m) continue;
    const s=abs(m[1],base);
    if(s && /\.(jpe?g|png|webp)(\?|$)/i.test(s) && !/(sprite|logo|icon|avatar|favicon|1x1|pixel|placeholder|blank)/i.test(s) && !images.includes(s)) images.push(s);
  }
}

// ---- SSRF protection ---------------------------------------------------------------------
function isBlockedV4(a,b,c,d){
  if(a===0||a===10||a===127) return true;                  // this-net, private, loopback
  if(a===100 && b>=64 && b<=127) return true;              // CGNAT
  if(a===169 && b===254) return true;                      // link-local / cloud metadata
  if(a===172 && b>=16 && b<=31) return true;               // private
  if(a===192 && b===0 && (c===0||c===2)) return true;     // IETF protocol / TEST-NET-1
  if(a===192 && b===168) return true;                      // private
  if(a===198 && (b===18||b===19)) return true;            // benchmarking
  if(a===198 && b===51 && c===100) return true;           // TEST-NET-2
  if(a===203 && b===0 && c===113) return true;            // TEST-NET-3
  if(a>=224) return true;                                  // multicast, reserved, broadcast
  return false;
}
function parseV6(ip){
  let s=ip.split('%')[0].toLowerCase(), tail=null;
  const dot=s.lastIndexOf('.');
  if(dot>=0){                                              // embedded dotted IPv4 tail
    const col=s.lastIndexOf(':'); const v4=s.slice(col+1).split('.').map(Number);
    if(v4.length!==4||v4.some(n=>!(n>=0&&n<=255))) return null;
    tail=[(v4[0]<<8)|v4[1],(v4[2]<<8)|v4[3]]; s=s.slice(0,col+1)+'0:0';
  }
  const halves=s.split('::'); if(halves.length>2) return null;
  const left=halves[0]?halves[0].split(':'):[], right=halves.length===2&&halves[1]?halves[1].split(':'):[];
  let groups;
  if(halves.length===2){ const fill=8-left.length-right.length; if(fill<1) return null; groups=[...left,...Array(fill).fill('0'),...right]; }
  else groups=left;
  if(groups.length!==8) return null;
  const nums=groups.map(g=>/^[0-9a-f]{1,4}$/.test(g)?parseInt(g,16):NaN);
  if(nums.some(Number.isNaN)) return null;
  if(tail){ nums[6]=tail[0]; nums[7]=tail[1]; }
  return nums;
}
function isBlockedIp(ip){
  const v=net.isIP(ip);
  if(v===4){ const [a,b,c,d]=ip.split('.').map(Number); return isBlockedV4(a,b,c,d); }
  if(v===6){
    const g=parseV6(ip); if(!g) return true;
    const v4=(x,y)=>isBlockedV4(x>>8,x&255,y>>8,y&255);
    if(g.every(n=>n===0)) return true;                                            // ::
    if(g.slice(0,7).every(n=>n===0) && g[7]===1) return true;                    // ::1
    if(g.slice(0,5).every(n=>n===0) && g[5]===0xffff) return v4(g[6],g[7]);      // ::ffff:a.b.c.d (mapped)
    if(g.slice(0,6).every(n=>n===0)) return v4(g[6],g[7]);                        // ::a.b.c.d (compat)
    if(g[0]===0x64 && g[1]===0xff9b && g.slice(2,6).every(n=>n===0)) return v4(g[6],g[7]); // NAT64
    if(g[0]===0x2002) return v4(g[1],g[2]);                                       // 6to4
    if((g[0]&0xfe00)===0xfc00) return true;                                       // fc00::/7 unique local
    if((g[0]&0xffc0)===0xfe80) return true;                                       // fe80::/10 link-local
    if((g[0]&0xffc0)===0xfec0) return true;                                       // fec0::/10 site-local
    if((g[0]&0xff00)===0xff00) return true;                                       // multicast
    return false;
  }
  return true;                                                                    // not an IP: treat as blocked
}
// Resolve a URL's host and make sure it is a public address. Throws when it is not.
async function assertPublicUrl(u){
  if(u.protocol!=='http:' && u.protocol!=='https:') throw new Error('blocked');
  if(u.username||u.password) throw new Error('blocked');
  let h=u.hostname.toLowerCase().replace(/\.$/,'');
  if(h.startsWith('[')&&h.endsWith(']')) h=h.slice(1,-1);
  if(!h) throw new Error('blocked');
  if(net.isIP(h)){ if(isBlockedIp(h)) throw new Error('blocked'); return; }
  if(h==='localhost'||!h.includes('.')||/\.(localhost|local|internal|localdomain|home|lan|corp|intranet)$/.test(h)) throw new Error('blocked');
  const addrs=await dns.promises.lookup(h,{all:true});
  if(!addrs.length || addrs.some(a=>isBlockedIp(a.address))) throw new Error('blocked');
}
// Read at most `max` bytes of the response body, then cancel the stream.
async function readCapped(r,max){
  if(!r.body||!r.body.getReader) return (await r.text()).slice(0,max);
  const reader=r.body.getReader(), dec=new TextDecoder('utf-8'); let got=0, out='';
  try{
    for(;;){
      const {done,value}=await reader.read(); if(done) break;
      const room=max-got; const chunk=value.length>room? value.subarray(0,room) : value;
      out+=dec.decode(chunk,{stream:true}); got+=chunk.length;
      if(got>=max) break;
    }
  } finally { try{ await reader.cancel(); }catch(e){} }
  return (out+dec.decode()).slice(0,max);
}
// Fetch with manual redirect handling so every hop is validated.
async function safeFetch(startUrl,signal){
  let u=new URL(startUrl);
  for(let hop=0;hop<=MAX_REDIRECTS;hop++){
    await assertPublicUrl(u);
    const r=await fetch(u.href,{ redirect:'manual', signal,
      headers:{'User-Agent':'Mozilla/5.0 (compatible; GlobalPulseBot/1.0; +https://global-pulse-two.vercel.app)','Accept':'text/html,application/xhtml+xml'} });
    if(r.status>=300 && r.status<400 && r.headers.get('location')){
      try{ r.body&&r.body.cancel&&r.body.cancel(); }catch(e){}
      u=new URL(r.headers.get('location'),u);
      continue;
    }
    return r;
  }
  throw new Error('too many redirects');
}

const EMPTY = ()=>({ paragraphs:[], images:[] });

module.exports = async (req,res)=>{
  res.setHeader('Cache-Control','s-maxage=900, stale-while-revalidate=3600');
  let url = (req.query && req.query.url) || '';
  if(!url){ try{ url=new URL(req.url,'http://x').searchParams.get('url')||''; }catch(e){} }
  if(!url){ res.status(400).json({error:'missing url'}); return; }
  if(Array.isArray(url)) url=url[0];
  url=String(url);
  let parsed;
  try{
    if(url.length>MAX_URL_LEN) throw new Error('too long');
    parsed=new URL(url);
    if(parsed.protocol!=='http:' && parsed.protocol!=='https:') throw new Error('scheme');
    if(parsed.username||parsed.password) throw new Error('credentials');
  }catch(e){ res.status(200).json(EMPTY()); return; }
  try{
    const ctl=AbortSignal.timeout? AbortSignal.timeout(7000):undefined;
    const r=await safeFetch(parsed.href,ctl);
    const html=await readCapped(r,MAX_BYTES);
    const tags=metaTags(html);
    const title=metaOf(tags,'og:title')||titleOf(html);
    const description=metaOf(tags,'og:description')||metaOf(tags,'twitter:description')||metaOf(tags,'description')||'';
    const ogimg=abs(metaOf(tags,'og:image')||metaOf(tags,'twitter:image'), url);
    const site=metaOf(tags,'og:site_name')||host(url);

    // prefer <article> body, else whole doc
    let body=html; const am=articleOf(html); if(am&&am.length>400) body=am;
    body=stripBlocks(body);
    const paragraphs=[]; const seen=new Set();
    for(const frag of paragraphsOf(body,400)){ if(paragraphs.length>=4) break; const t=clean(frag);
      if(t.length>70 && !seen.has(t) && !/cookie|subscribe|sign in|advertisement|©|all rights reserved/i.test(t)){ seen.add(t); paragraphs.push(t); } }
    if(!paragraphs.length && description) paragraphs.push(description);

    const images=[]; if(ogimg) images.push(ogimg);
    imagesOf(body,url,images,5);

    res.status(200).json({ title, description, site, paragraphs:paragraphs.slice(0,3), images:images.slice(0,4) });
  }catch(e){ res.status(200).json(EMPTY()); }
};
module.exports.isBlockedIp=isBlockedIp; module.exports.assertPublicUrl=assertPublicUrl;
module.exports.stripBlocks=stripBlocks; module.exports.paragraphsOf=paragraphsOf; module.exports.metaTags=metaTags;
module.exports.metaOf=metaOf; module.exports.clean=clean; module.exports.imagesOf=imagesOf;
