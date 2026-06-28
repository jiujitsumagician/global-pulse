// Global Pulse — Windows screensaver host (Electron).
// Reuses the hosted web app and gives it a real embedded browser (<webview>) so
// pressing OK on an event opens the article in-app, scrollable, Back returns to the globe.
//
// Windows runs a .scr with flags:  /s = show fullscreen,  /p <hwnd> = preview,  /c = config.
const { app, BrowserWindow, ipcMain, screen } = require('electron');
const path = require('path');

const APP_URL = process.env.GP_URL || 'https://global-pulse-two.vercel.app/?tv=1.4';

// figure out the screensaver mode from argv (Windows passes /s, /p, /c)
const argv = process.argv.slice(1).map(a => a.toLowerCase());
const mode = argv.find(a => a === '/s' || a.startsWith('/p') || a === '/c') || '/s';

let win = null;
function createSaver() {
  win = new BrowserWindow({
    fullscreen: true, frame: false, kiosk: true, backgroundColor: '#05070d',
    autoHideMenuBar: true, show: false,
    webPreferences: { webviewTag: true, contextIsolation: true, preload: path.join(__dirname, 'preload.js') }
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
app.on('window-all-closed', () => app.quit());

app.whenReady().then(() => {
  if (mode === '/c') { app.quit(); return; }          // no config dialog
  if (mode.startsWith('/p')) { app.quit(); return; }  // Windows preview pane is unsupported; no-op
  createSaver();                                       // '/s' (and default): run the screensaver
});
