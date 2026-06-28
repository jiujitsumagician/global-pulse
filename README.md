# 🌍 Global Pulse — Live World Events

A rotating globe that tracks **realtime world news and events**. The camera flies to each
event's location, zooms in, drops a pulsing marker, and shows a card. Press **OK** on an
event to open the article in an in-app browser (scroll with ↑/↓); **Back** returns to the
globe. Runs as an ambient **screensaver** across platforms from one shared web core.

**Live:** https://global-pulse-two.vercel.app  ·  **API:** https://global-pulse-two.vercel.app/api/events

## What's real right now
- **Globe** — globe.gl / three.js (NASA Blue Marble), auto-rotating, fly-to + zoom, pulse rings, HTML markers.
- **Realtime data** — a Vercel serverless aggregator (`api/events.js`) that, server-side (no CORS):
  - pulls **GDELT** world news, **geolocates each headline** (scans ~200 countries / 50 hotspot cities so a story lands where it happens), and **categorizes** it (Conflict / Politics / Disaster / News);
  - merges **USGS** live earthquakes; returns one cached JSON feed (~110 events, ~2 min refresh).
- **Navigation** — D-pad / arrows move through events, **OK/Enter** opens the reader, **Back/Esc** returns. Live feed list + QR code to open any article on a phone.

## Platforms (one core, four hosts)
| Platform | Folder | How it runs | In-app reader |
|---|---|---|---|
| Web / Smart-TV browser | `index.html` | open the URL (`?tv=1.5` for TV scale) | iframe + QR |
| Windows screensaver | `windows/` | Electron host -> `.scr` | real `<webview>` (scrolls) |
| Fire TV | `firetv/` | Android leanback WebView app | native reader (D-pad scroll) |
| Roku | `roku/` | native BrightScript SceneGraph screensaver | QR (Roku has no browser) |

Windows & Fire TV reuse the hosted web app and add a true embedded browser for articles.
Roku is native 2D (equirectangular world map + live markers + headline cards) since it can't
run WebGL, and shows a QR on OK. See each folder's README for build/sideload steps.

## Caveats / next steps
- **Google Earth:** classic API discontinued; Google photoreal 3D needs a billed Maps key.
  Current globe is a key-free WebGL earth; swapping to Google 3D tiles via Cesium is a clean step.
- GDELT rate-limits 1 req/5s per IP -> handled by edge caching + retry.
- Custom domain (e.g. globalpulse.dsio.io) needs one Cloudflare DNS record; using *.vercel.app for now.
