// JanSetu-Swachh Admin - Electron shell around the React admin dashboard.
//
// The built dashboard (./app) is served from a tiny local HTTP server on a
// fixed loopback port instead of file://, so absolute asset paths work and
// localStorage (admin session, server address) persists between launches.
const { app, BrowserWindow, shell, Menu } = require('electron');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const APP_DIR = path.join(__dirname, 'app');
const PREFERRED_PORT = 47821;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function startStaticServer() {
  const server = http.createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    let filePath = path.normalize(path.join(APP_DIR, urlPath));
    if (!filePath.startsWith(APP_DIR)) {
      res.writeHead(403).end();
      return;
    }
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(APP_DIR, 'index.html'); // single-page app fallback
    }
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(res);
  });

  return new Promise((resolve) => {
    server.once('error', () => {
      // Preferred port busy (e.g. a second copy is open) - use any free port.
      server.listen(0, '127.0.0.1', () => resolve(server.address().port));
    });
    server.listen(PREFERRED_PORT, '127.0.0.1', () => resolve(server.address().port));
  });
}

async function createWindow() {
  const port = await startStaticServer();
  const appOrigin = `http://127.0.0.1:${port}`;

  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    title: 'JanSetu-Swachh Admin',
    backgroundColor: '#f7f5f1',
    icon: path.join(__dirname, 'build', 'icon.png'),
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  // Photo links ("View Photo Reported by Citizen", proof photos) open in the
  // system browser rather than a bare Electron window.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http://') || url.startsWith('https://')) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith(appOrigin)) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });

  // Open the portal with "Admin" preselected as the login type.
  await win.loadURL(`${appOrigin}/?role=admin`);
}

Menu.setApplicationMenu(
  Menu.buildFromTemplate([
    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
      ],
    },
  ]),
);

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    const [win] = BrowserWindow.getAllWindows();
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });
  app.whenReady().then(createWindow);
  app.on('window-all-closed', () => app.quit());
}
