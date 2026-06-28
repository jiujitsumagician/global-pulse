# Global Pulse — Windows screensaver

An Electron host that runs the live Global Pulse globe full-screen and gives it a real
embedded browser, so on Windows you get the full behavior: the globe flies between live
world events, **press Enter/OK** on one to open the article *inside* the screensaver
(scroll with ↑/↓), and **Esc / Back** returns to the globe. Moving the mouse exits the
screensaver as usual.

## Build the .scr
```
cd windows
npm install
npm run build          # produces dist/GlobalPulse.exe
```
Then:
1. Rename `dist/GlobalPulse.exe` → `GlobalPulse.scr`.
2. Right-click `GlobalPulse.scr` → **Install** (or copy it to `C:\Windows\System32\`).
3. It now appears in **Settings → Personalization → Lock screen → Screen saver** as
   "GlobalPulse". Select it.

## Try it without packaging
```
cd windows
npm install
npm start -- /s
```

## Config
- Data + UI come from the hosted app. Point it elsewhere with an env var:
  `set GP_URL=https://your-host/?tv=1.4 && npm start -- /s`
- Flags: `/s` run, `/p` preview (no-op), `/c` config (no-op).

## Notes
- The Windows screensaver **preview pane** (small box in Settings) isn't rendered — Electron
  can't host the legacy preview HWND. The full-screen saver (`/s`) is the real experience.
- Requires internet (loads the hosted globe + live `/api/events`).
