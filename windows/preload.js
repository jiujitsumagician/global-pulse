// Exposes a tiny bridge so the web app knows it's inside the Electron screensaver
// (uses <webview> for the in-app reader) and can quit on Escape.
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('GPElectron', {
  quit: () => ipcRenderer.send('gp-quit')
});
