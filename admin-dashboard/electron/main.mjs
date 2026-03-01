import { app, BrowserWindow, shell, Menu } from 'electron';
import { fileURLToPath } from 'url';
import path from 'path';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const isDev = process.env.NODE_ENV === 'development';

function createWindow() {
    const win = new BrowserWindow({
        width: 1280,
        height: 800,
        minWidth: 960,
        minHeight: 600,
        title: 'Afya Links Admin',
        icon: path.join(__dirname, '../public/favicon.ico'),
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
        },
    });

    if (isDev) {
        // In dev mode, load the Vite dev server
        win.loadURL('http://localhost:5173');
        win.webContents.openDevTools();
    } else {
        // In production, load the built index.html
        const indexPath = path.join(__dirname, '../dist/index.html');
        if (existsSync(indexPath)) {
            win.loadFile(indexPath);
        } else {
            win.loadURL('about:blank');
            win.webContents.executeJavaScript(
                `document.body.innerHTML = '<h2 style="font-family:sans-serif;color:red;padding:40px">Error: dist/index.html not found. Run npm run build first.</h2>'`
            );
        }
    }

    // Open external links in the default browser, not Electron
    win.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
}

// Build a simple app menu
function buildMenu() {
    const template = [
        {
            label: 'File',
            submenu: [{ role: 'quit' }],
        },
        {
            label: 'View',
            submenu: [
                { role: 'reload' },
                { role: 'forceReload' },
                { type: 'separator' },
                { role: 'resetZoom' },
                { role: 'zoomIn' },
                { role: 'zoomOut' },
                { type: 'separator' },
                { role: 'togglefullscreen' },
            ],
        },
        {
            label: 'Window',
            submenu: [{ role: 'minimize' }, { role: 'zoom' }],
        },
    ];
    Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.whenReady().then(() => {
    buildMenu();
    createWindow();
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
