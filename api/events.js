// Global Pulse — realtime world-event aggregator (Vercel serverless, CommonJS).
// Returns one geolocated, categorized feed: GDELT world news + USGS earthquakes.
// Runs server-side, so there is no CORS problem reaching GDELT.

// --- approximate country centroids (GDELT sourcecountry + headline matching) ---
const COUNTRY = {
  "united states":[39.8,-98.6],"usa":[39.8,-98.6],"america":[39.8,-98.6],"canada":[56,-106],"mexico":[23,-102],
  "brazil":[-10,-55],"argentina":[-38,-63],"chile":[-33,-71],"colombia":[4,-73],"peru":[-10,-76],"venezuela":[7,-66],
  "bolivia":[-17,-65],"ecuador":[-1.5,-78],"paraguay":[-23,-58],"uruguay":[-33,-56],"cuba":[21.5,-79.5],"haiti":[19,-72.4],
  "guatemala":[15.7,-90.2],"honduras":[15,-86.5],"panama":[8.5,-80],"costa rica":[9.7,-84],"nicaragua":[13,-85],"jamaica":[18,-77.3],
  "united kingdom":[54,-2],"britain":[54,-2],"england":[52.5,-1.5],"scotland":[56.5,-4],"ireland":[53,-8],"france":[46,2],
  "germany":[51,10],"spain":[40,-4],"portugal":[39,-8],"italy":[42,12],"netherlands":[52,5],"belgium":[50.5,4.5],
  "switzerland":[47,8],"austria":[47.5,14],"poland":[52,19],"ukraine":[49,32],"russia":[61,90],"belarus":[53,28],
  "sweden":[62,15],"norway":[62,9],"finland":[64,26],"denmark":[56,9],"greece":[39,22],"turkey":[39,35],"turkiye":[39,35],
  "romania":[46,25],"hungary":[47,19],"czech republic":[49.8,15.5],"czechia":[49.8,15.5],"bulgaria":[42.7,25.5],"serbia":[44,21],
  "croatia":[45.1,15.5],"slovakia":[48.7,19.7],"slovenia":[46.1,14.8],"bosnia":[44,18],"albania":[41,20],"moldova":[47,28.5],
  "estonia":[59,26],"latvia":[57,25],"lithuania":[55,24],"iceland":[65,-18],"cyprus":[35,33],"luxembourg":[49.8,6.1],
  "china":[35,103],"japan":[36,138],"south korea":[36.5,128],"north korea":[40,127],"india":[22,79],"pakistan":[30,70],
  "bangladesh":[24,90],"sri lanka":[7.9,80.7],"nepal":[28,84],"afghanistan":[33,66],"iran":[32,53],"iraq":[33,44],
  "syria":[35,38],"saudi arabia":[24,45],"yemen":[15.5,48],"united arab emirates":[24,54],"uae":[24,54],"israel":[31,35],
  "palestine":[31.9,35.2],"jordan":[31,36],"lebanon":[33.8,35.8],"kuwait":[29.3,47.6],"qatar":[25.3,51.2],"bahrain":[26,50.5],
  "oman":[21,57],"egypt":[26,30],"libya":[27,17],"tunisia":[34,9],"algeria":[28,3],"morocco":[32,-6],"sudan":[15,30],
  "ethiopia":[9,39],"kenya":[0,38],"tanzania":[-6,35],"uganda":[1,32],"nigeria":[9,8],"ghana":[8,-1],"senegal":[14,-14],
  "mali":[17,-4],"niger":[17,8],"chad":[15,19],"cameroon":[6,12],"angola":[-12,17],"zambia":[-13,27],"zimbabwe":[-19,29],
  "mozambique":[-18,35],"south africa":[-29,24],"namibia":[-22,17],"botswana":[-22,24],"madagascar":[-19,46],"somalia":[6,47],
  "rwanda":[-2,30],"congo":[-1,15],"australia":[-25,133],"new zealand":[-41,174],"indonesia":[-2,118],"malaysia":[3.5,102],
  "singapore":[1.35,103.8],"thailand":[15,100],"vietnam":[16,106],"philippines":[13,122],"myanmar":[21,96],"cambodia":[12.5,105],
  "taiwan":[23.7,121],"mongolia":[46,105],"kazakhstan":[48,67],"uzbekistan":[41,64],"azerbaijan":[40,47.5],"armenia":[40,45],
  "georgia":[42,43.5]
};
// major cities / hotspots — checked first so stories land where they happen
const CITY = {
  "washington":[38.9,-77],"new york":[40.7,-74],"los angeles":[34,-118.2],"london":[51.5,-0.1],"paris":[48.85,2.35],
  "berlin":[52.5,13.4],"moscow":[55.75,37.6],"kyiv":[50.45,30.5],"kiev":[50.45,30.5],"beijing":[39.9,116.4],
  "shanghai":[31.2,121.5],"hong kong":[22.3,114.2],"tokyo":[35.7,139.7],"seoul":[37.55,126.97],"pyongyang":[39,125.75],
  "new delhi":[28.6,77.2],"delhi":[28.6,77.2],"mumbai":[19,72.9],"tehran":[35.7,51.4],"baghdad":[33.3,44.4],
  "damascus":[33.5,36.3],"jerusalem":[31.78,35.22],"tel aviv":[32.08,34.78],"gaza":[31.5,34.47],"beirut":[33.9,35.5],
  "cairo":[30.05,31.25],"istanbul":[41,28.95],"ankara":[39.9,32.85],"riyadh":[24.7,46.7],"dubai":[25.2,55.3],
  "kabul":[34.5,69.2],"islamabad":[33.7,73.1],"karachi":[24.9,67],"bangkok":[13.75,100.5],"hanoi":[21,105.85],
  "manila":[14.6,121],"jakarta":[-6.2,106.8],"sydney":[-33.87,151.2],"brussels":[50.85,4.35],"geneva":[46.2,6.15],
  "rome":[41.9,12.5],"madrid":[40.4,-3.7],"athens":[38,23.7],"warsaw":[52.2,21],"vienna":[48.2,16.37],
  "rafah":[31.29,34.25],"khan younis":[31.34,34.3]
};
const CONFLICT=/strike|attack|kill|war\b|troops|missile|clash|militan|bomb|shell|offensive|conflict|invasion|gaza|hostage|drone|airstrike|ceasefire|gunmen|insurgen/i;
const POLITICS=/election|vote|president|parliament|minister|senate|policy|sanction|summit|diplomat|coup|referendum|cabinet|congress|premier|chancellor|envoy/i;
const DISASTER=/storm|flood|quake|earthquake|wildfire|fire\b|hurricane|cyclone|typhoon|drought|eruption|volcano|landslide|evacuat|tsunami|famine|outbreak/i;
function categorize(t){ if(CONFLICT.test(t))return"Conflict"; if(DISASTER.test(t))return"Disaster"; if(POLITICS.test(t))return"Politics"; return"News"; }
function hash(s){ let h=0; for(let i=0;i<s.length;i++){ h=(h*31+s.charCodeAt(i))|0; } return h; }
function jitter(seed,amp){ const a=Math.abs(hash(seed)); return ((a%2000)/1000-1)*amp; }
function placeOf(title,country){
  const lc=' '+title.toLowerCase()+' ';
  for(const k in CITY){ if(lc.includes(' '+k+' ')||lc.includes(' '+k+',')||lc.includes(' '+k+"'")) return {ll:CITY[k], name:cap(k)}; }
  for(const k in COUNTRY){ if(lc.includes(' '+k+' ')||lc.includes(' '+k+',')) return {ll:COUNTRY[k], name:cap(k)}; }
  const c=(country||'').toLowerCase().trim();
  if(COUNTRY[c]) return {ll:COUNTRY[c], name:country};
  return null;
}
function cap(s){ return s.replace(/\b\w/g,m=>m.toUpperCase()); }

const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function getNews(){
  const q=encodeURIComponent('(breaking OR crisis OR election OR war OR strike OR summit OR protest OR disaster OR killed OR president OR talks OR attack OR court OR economy OR climate OR deal OR ceasefire) sourcelang:english');
  const url=`https://api.gdeltproject.org/api/v2/doc/doc?query=${q}&mode=ArtList&format=json&maxrecords=75&timespan=150min&sort=DateDesc`;
  let arts=[];
  // GDELT rate-limits to 1 req / 5s per IP; retry a couple of times on the shared serverless egress
  for(let attempt=0; attempt<3 && !arts.length; attempt++){
    try{ const r=await fetch(url,{headers:{'User-Agent':'GlobalPulse/1.0'}}); const txt=await r.text();
      const j=JSON.parse(txt); arts=j.articles||[]; }
    catch(e){ if(attempt<2) await sleep(1600); }
  }
  if(!arts.length) return [];
  const out=[]; const seenLoc={};
  for(const a of arts){
    const title=(a.title||'').trim(); if(!title||!a.url) continue;
    const p=placeOf(title, a.sourcecountry); if(!p) continue;
    const seed=a.url;
    // small per-location stacking offset so same-place stories spread a little
    const key=p.ll.join(','); const n=(seenLoc[key]=(seenLoc[key]||0)+1);
    const lat=clampLat(p.ll[0]+jitter(seed,2.2)+ (n>1?Math.sin(n)*1.5:0));
    const lng=p.ll[1]+jitter(seed+'x',2.6)+ (n>1?Math.cos(n)*1.5:0);
    out.push({ id:'n:'+hash(a.url), type:'News', category:categorize(title),
      lat, lng, title, place:p.name, time:parseDate(a.seendate)||Date.now(),
      url:a.url, source:a.domain||'' });
    if(out.length>=70) break;
  }
  return out;
}
function clampLat(v){ return Math.max(-84,Math.min(84,v)); }
function parseDate(s){ // GDELT seendate like 20240628T031500Z
  if(!s) return null; const m=/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(s);
  if(!m) return null; return Date.UTC(+m[1],+m[2]-1,+m[3],+m[4],+m[5],+m[6]); }

async function getQuakes(){
  try{
    const r=await fetch('https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson');
    const j=await r.json();
    return (j.features||[]).map(f=>({ id:'q:'+f.id, type:'Quake', category:'Quake',
      lat:f.geometry.coordinates[1], lng:f.geometry.coordinates[0],
      title:`M${f.properties.mag} earthquake — ${f.properties.place||'unknown region'}`,
      place:f.properties.place||'Unknown region', time:f.properties.time||Date.now(),
      url:f.properties.url, mag:f.properties.mag, source:'usgs.gov' })).slice(0,45);
  }catch(e){ return []; }
}

// NASA EONET — natural events (wildfires, storms, volcanoes, floods, ice...) with real coords
async function getEonet(){
  try{
    const r=await fetch('https://eonet.gsfc.nasa.gov/api/v3/events?status=open&days=10&limit=80');
    const j=await r.json();
    return (j.events||[]).map(ev=>{
      const g=ev.geometry&&ev.geometry[ev.geometry.length-1]; if(!g||!g.coordinates) return null;
      let lng,lat;
      if(g.type==='Point'){ lng=g.coordinates[0]; lat=g.coordinates[1]; }
      else { const c=g.coordinates&&g.coordinates[0]&&g.coordinates[0][0]; if(!c) return null; lng=c[0]; lat=c[1]; }
      if(!Number.isFinite(lat)||!Number.isFinite(lng)) return null;
      const ct=(ev.categories&&ev.categories[0]&&ev.categories[0].title)||'Natural event';
      const disaster=/wildfire|storm|flood|volcano|landslide|drought|cyclone|hurricane|temperature/i.test(ct);
      const link=(ev.sources&&ev.sources[0]&&ev.sources[0].url)||ev.link||'https://eonet.gsfc.nasa.gov/';
      return { id:'e:'+ev.id, type:'Nature', category:disaster?'Disaster':'Nature',
        lat:clampLat(lat), lng, title:ev.title, place:ct, time:Date.parse(g.date)||Date.now(), url:link, source:'nasa.gov' };
    }).filter(Boolean).slice(0,45);
  }catch(e){ return []; }
}
// The Space Devs Launch Library — recent/upcoming rocket launches, geolocated by pad.
// LL2 free tier is rate-limited (~15/hr), so cache across warm invocations for 20 min.
let LAUNCHCACHE={ data:[], ts:0 };
async function getLaunches(){
  if(LAUNCHCACHE.data.length && Date.now()-LAUNCHCACHE.ts < 20*60*1000) return LAUNCHCACHE.data;
  try{
    const r=await fetch('https://ll.thespacedevs.com/2.2.0/launch/?limit=14&ordering=-net&mode=normal',{headers:{'User-Agent':'GlobalPulse/1.0'}});
    if(!r.ok) return LAUNCHCACHE.data;          // 429/etc -> keep last good
    const j=await r.json();
    const out=(j.results||[]).map(l=>{ const pad=l.pad||{}; const lat=parseFloat(pad.latitude), lng=parseFloat(pad.longitude);
      if(!Number.isFinite(lat)||!Number.isFinite(lng)) return null;
      return { id:'l:'+l.id, type:'Space', category:'Space', lat, lng,
        title:l.name||'Rocket launch', place:(pad.location&&pad.location.name)||pad.name||'Launch site',
        time:Date.parse(l.net)||Date.now(),
        url:'https://www.google.com/search?q='+encodeURIComponent((l.name||'rocket launch')+' launch'), source:'thespacedevs.com' };
    }).filter(Boolean);
    if(out.length) LAUNCHCACHE={ data:out, ts:Date.now() };
    return out;
  }catch(e){ return LAUNCHCACHE.data; }
}

// in-memory last-good cache (persists across warm invocations) so a transient
// GDELT rate-limit doesn't blank the feed
let LASTGOOD = { news:[], ts:0 };

module.exports = async (req,res)=>{
  res.setHeader('Access-Control-Allow-Origin','*');
  let news=[], quakes=[], nature=[], space=[];
  try{ [news,quakes,nature,space]=await Promise.all([getNews(),getQuakes(),getEonet(),getLaunches()]); }catch(e){}
  let cached=false;
  if(news.length){ LASTGOOD={ news, ts:Date.now() }; }
  else if(LASTGOOD.news.length && Date.now()-LASTGOOD.ts < 25*60*1000){ news=LASTGOOD.news; cached=true; }
  const events=[...news,...nature,...space,...quakes].sort((a,b)=>b.time-a.time);
  // cache good responses at the edge for a while; recover fast from a fully-empty one
  res.setHeader('Cache-Control', (news.length||nature.length) ? 's-maxage=180, stale-while-revalidate=600' : 's-maxage=8');
  res.status(200).json({ updated:Date.now(),
    counts:{news:news.length,nature:nature.length,space:space.length,quakes:quakes.length,cached}, events });
};
