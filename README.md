# 🌍 Global Pulse — Live World Events

A rotating 3D globe that monitors world events in realtime. When something happens the
camera flies to the location, zooms in, drops a pulsing marker, and shows a popup card
with a link to read more. A live feed lists recent events; click any to revisit it.

## Run
Just open `index.html` in a browser. No build, no keys.

## How it works
- **Globe:** `globe.gl` (three.js + NASA Blue Marble imagery), auto-rotating, with
  `pointOfView()` fly-to + zoom and animated pulse rings.
- **Realtime data:**
  - **USGS** live earthquake feed (geolocated, with detail links) — always on, CORS-friendly.
  - **GDELT** geolocated news headlines — best-effort via a public CORS proxy; the app still
    works fully on the USGS feed if GDELT/proxy is unavailable.
- Polls every 60s; brand-new events jump to the front of the "showcase" queue (fly + popup).

## Notes / next iterations
- True **Google Earth** photoreal 3D needs a billed Google Maps API key (Photorealistic
  3D Tiles via Cesium). Swapping the renderer is a drop-in next step.
- A small backend/proxy would make the news feed (GDELT/NewsAPI) more robust than a public
  CORS proxy, and unlock keyed sources.
