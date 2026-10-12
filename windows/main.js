// Global Pulse — Windows screensaver host (Electron).
// Reuses the hosted web app and gives it a real embedded browser (<webview>) so
// pressing OK on an event opens the article in-app, scrollable, Back returns to the globe.
//
// Windows runs a .scr with flags:  /s = show fullscreen,  /p <hwnd> = preview,  /c = config.
const { app, BrowserWindow, ipcMain, screen, session } = require('electron');
const path = require('path');

const DEFAULT_URL = 'https://global-pulse-two.vercel.app/?tv=1.4';
// GP_URL (dev override) is honoured only for unpackaged runs (npm start), never in the shipped .exe.
const APP_URL = (!app.isPackaged && process.env.GP_URL) || DEFAULT_URL;

// figure out the screensaver mode from argv (Windows passes /s, /p, /c)
const argv = process.argv.slice(1).map(a => a.toLowerCase());
const mode = argv.find(a => a === '/s' || a.startsWith('/p') || a === '/c') || '/s';

let win = null;
function createSaver() {
  win = new BrowserWindow({
    fullscreen: true, frame: false, kiosk: true, backgroundColor: '#05070d',
    autoHideMenuBar: true, show: false,
    webPreferences: { webviewTag: true, contextIsolation: true, nodeIntegration: false, sandbox: true, webSecurity: true,
      preload: path.join(__dirname, 'preload.js') }
  });
  win.setMenuBarVisibility(false);
  win.loadURL(APP_URL);
  win.once('ready-to-show', () => win.show());

  // Standard screensaver behavior: any real mouse movement exits.
  // Keyboard (OK / arrows / Back) is reserved for the app; Esc quits via the renderer.
  let origin = null;
  const poll = setInterval(() => {
    if (!win) return clearInterval(poll);
    const p = screen.getCursorScreenPoint();
    if (!origin) { origin = p; return; }
    if (Math.abs(p.x - origin.x) > 8 || Math.abs(p.y - origin.y) > 8) { clearInterval(poll); app.quit(); }
  }, 250);
}

ipcMain.on('gp-quit', () => app.quit());

// Hardening: the window renders remote content and hosts third-party article pages in <webview>.
app.on('web-contents-created', (_e, wc) => {
  wc.setWindowOpenHandler(() => ({ action: 'deny' }));             // no popups / new windows
  wc.on('will-attach-webview', (e, prefs, params) => {             // guests: http(s) only, no Node, no preload
    delete prefs.preload; delete prefs.preloadURL;
    prefs.nodeIntegration = false; prefs.contextIsolation = true; prefs.sandbox = true;
    if (!/^https?:\/\//i.test(params.src || '')) e.preventDefault();
  });
  wc.on('will-navigate', (e, u) => {                               // the app window stays on the app origin
    try { if (win && wc === win.webContents && new URL(u).origin !== new URL(APP_URL).origin) e.preventDefault(); }
    catch (_) { e.preventDefault(); }
  });
});
app.on('window-all-closed', () => app.quit());

app.whenReady().then(() => {
  if (mode === '/c') { app.quit(); return; }          // no config dialog
  if (mode.startsWith('/p')) { app.quit(); return; }  // Windows preview pane is unsupported; no-op
  session.defaultSession.setPermissionRequestHandler((_wc, perm, cb) => cb(perm === 'fullscreen'));  // deny camera/mic/geo/etc.
  createSaver();                                       // '/s' (and default): run the screensaver
});
