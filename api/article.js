// Global Pulse — server-side article extractor. Pulls a 2-3 paragraph blurb + images
// from a news article URL (no CORS issues, runs server-side). Best-effort: returns
// whatever it can scrape from og: tags + the article body.

function decodeEntities(s){
  if(!s) return '';
  return s.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"')
    .replace(/&#0?39;|&apos;|&#x27;/g,"'").replace(/&nbsp;/g,' ').replace(/&hellip;/g,'…')
    .replace(/&mdash;/g,'—').replace(/&ndash;/g,'–').replace(/&rsquo;/g,'’').replace(/&lsquo;/g,'‘')
    .replace(/&ldquo;/g,'“').replace(/&rdquo;/g,'”')
    .replace(/&#(\d+);/g,(_,n)=>String.fromCharCode(+n))
    .replace(/&#x([0-9a-f]+);/gi,(_,n)=>String.fromCharCode(parseInt(n,16)));
}
function clean(frag){ return decodeEntities(String(frag||'').replace(/<[^>]+>/g,' ')).replace(/\s+/g,' ').trim(); }
function abs(src,base){ if(!src) return ''; try{ return new URL(src, base).href; }catch(e){ return ''; } }
function host(u){ try{ return new URL(u).hostname.replace(/^www\./,''); }catch(e){ return ''; } }
function metaOf(html,prop){
  const a=new RegExp('<meta[^>]+(?:property|name)=["\\\']'+prop+'["\\\'][^>]*?content=["\\\']([^"\\\']*)["\\\']','i').exec(html);
  if(a) return decodeEntities(a[1]);
  const b=new RegExp('<meta[^>]+content=["\\\']([^"\\\']*)["\\\'][^>]*?(?:property|name)=["\\\']'+prop+'["\\\']','i').exec(html);
  return b?decodeEntities(b[1]):'';
}

module.exports = async (req,res)=>{
  res.setHeader('Access-Control-Allow-Origin','*');
  res.setHeader('Cache-Control','s-maxage=900, stale-while-revalidate=3600');
  let url = (req.query && req.query.url) || '';
  if(!url){ try{ url=new URL(req.url,'http://x').searchParams.get('url')||''; }catch(e){} }
  if(!url){ res.status(400).json({error:'missing url'}); return; }
  try{
    const ctl=AbortSignal.timeout? AbortSignal.timeout(7000):undefined;
    const r=await fetch(url,{ redirect:'follow', signal:ctl,
      headers:{'User-Agent':'Mozilla/5.0 (compatible; GlobalPulseBot/1.0; +https://global-pulse-two.vercel.app)','Accept':'text/html,application/xhtml+xml'} });
    const html=(await r.text()).slice(0, 600000);
    const title=metaOf(html,'og:title')||clean((/<title[^>]*>([\s\S]*?)<\/title>/i.exec(html)||[])[1]||'');
    const description=metaOf(html,'og:description')||metaOf(html,'twitter:description')||metaOf(html,'description')||'';
    const ogimg=abs(metaOf(html,'og:image')||metaOf(html,'twitter:image'), url);
    const site=metaOf(html,'og:site_name')||host(url);

    // prefer <article> body, else whole doc
    let body=html; const am=/<article[\s\S]*?<\/article>/i.exec(html); if(am&&am[0].length>400) body=am[0];
    body=body.replace(/<(script|style|figure|aside|nav|header|footer)[\s\S]*?<\/\1>/gi,' ');
    const paragraphs=[]; const seen=new Set(); let m; const pre=/<p[^>]*>([\s\S]*?)<\/p>/gi;
    while((m=pre.exec(body)) && paragraphs.length<4){ const t=clean(m[1]);
      if(t.length>70 && !seen.has(t) && !/cookie|subscribe|sign in|advertisement|©|all rights reserved/i.test(t)){ seen.add(t); paragraphs.push(t); } }
    if(!paragraphs.length && description) paragraphs.push(description);

    const images=[]; if(ogimg) images.push(ogimg);
    let im; const ire=/<img[^>]+?(?:data-src|src)=["\']([^"\']+)["\']/gi;
    while((im=ire.exec(body)) && images.length<5){ const s=abs(im[1],url);
      if(s && /\.(jpe?g|png|webp)(\?|$)/i.test(s) && !/(sprite|logo|icon|avatar|favicon|1x1|pixel|placeholder|blank)/i.test(s) && !images.includes(s)) images.push(s); }

    res.status(200).json({ title, description, site, paragraphs:paragraphs.slice(0,3), images:images.slice(0,4) });
  }catch(e){ res.status(200).json({ paragraphs:[], images:[], error:String(e&&e.message||e) }); }
};
