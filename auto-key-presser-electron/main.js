const { app, BrowserWindow, ipcMain, globalShortcut } = require('electron');
const { execSync } = require('child_process');
const path = require('path');

let mainWindow;
let autoKeyTimer = null;
let settings = { key: 'a', count: 0, interval: 1, unit: 'seconds', app: '' };
let pressesDone = 0;
let paused = false;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 480,
    height: 580,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    },
    titleBarStyle: 'default',
    resizable: true
  });

  mainWindow.loadFile('index.html');
  
  // Set up global shortcuts
  globalShortcut.register('CommandOrControl+Shift+K', () => {
    if (mainWindow.isVisible()) {
      mainWindow.hide();
    } else {
      mainWindow.show();
    }
  });

  globalShortcut.register('CommandOrControl+Shift+S', () => {
    if (autoKeyTimer) {
      stopAutoclicker();
    } else {
      startAutoclicker();
    }
  });
}

function intervalToSeconds() {
  if (settings.unit === 'milliseconds') return settings.interval / 1000;
  if (settings.unit === 'minutes') return settings.interval * 60;
  return settings.interval;
}

function pressKey() {
  if (paused) return;
  
  if (settings.count > 0 && pressesDone >= settings.count) {
    stopAutoclicker();
    return;
  }

  try {
    // Use AppleScript for more reliable key simulation
    let script;
    if (settings.app && settings.app !== '') {
      script = `
        tell application "${settings.app}"
          activate
        end tell
        delay 0.1
        tell application "System Events"
          key code ${getKeyCode(settings.key)}
        end tell
      `;
    } else {
      script = `
        tell application "System Events"
          key code ${getKeyCode(settings.key)}
        end tell
      `;
    }
    
    execSync(`osascript -e '${script}'`, { timeout: 1000 });
    pressesDone++;
    
    mainWindow.webContents.send('update-status', {
      status: 'Running',
      pressesDone: pressesDone
    });
  } catch (error) {
    console.error('Error pressing key:', error);
  }
}

function getKeyCode(key) {
  const keyCodes = {
    'a': 0, 'b': 11, 'c': 8, 'd': 2, 'e': 14, 'f': 3, 'g': 5, 'h': 4,
    'i': 34, 'j': 38, 'k': 40, 'l': 37, 'm': 46, 'n': 45, 'o': 31,
    'p': 35, 'q': 12, 'r': 15, 's': 1, 't': 17, 'u': 32, 'v': 9,
    'w': 13, 'x': 7, 'y': 16, 'z': 6,
    'space': 49, 'tab': 48, 'return': 36, 'escape': 53, 'delete': 51,
    'up': 126, 'down': 125, 'left': 123, 'right': 124,
    'f1': 122, 'f2': 120, 'f3': 99, 'f4': 118, 'f5': 96, 'f6': 97
  };
  return keyCodes[key] || 0;
}

function startAutoclicker() {
  if (autoKeyTimer) clearInterval(autoKeyTimer);
  pressesDone = 0;
  paused = false;
  
  const intervalMs = intervalToSeconds() * 1000;
  autoKeyTimer = setInterval(pressKey, intervalMs);
  
  mainWindow.webContents.send('update-ui', {
    status: 'Running',
    buttonText: '⏹️ Stop',
    buttonClass: 'running'
  });
}

function stopAutoclicker() {
  if (autoKeyTimer) {
    clearInterval(autoKeyTimer);
    autoKeyTimer = null;
  }
  paused = false;
  
  mainWindow.webContents.send('update-ui', {
    status: 'Stopped',
    buttonText: '▶️ Start',
    buttonClass: ''
  });
}

function getRunningApps() {
  try {
    const script = `
      tell application "System Events"
        set appList to {}
        repeat with proc in (every application process whose visible is true)
          set end of appList to name of proc
        end repeat
        return appList
      end tell
    `;
    const result = execSync(`osascript -e '${script}'`).toString().trim();
    return result.split(', ').filter(app => 
      !app.includes('Helper') && 
      !app.includes('Renderer') && 
      app !== 'Auto Key Presser'
    );
  } catch (error) {
    console.error('Error getting running apps:', error);
    return [];
  }
}

// IPC handlers
ipcMain.on('save-settings', (event, newSettings) => {
  settings = { ...settings, ...newSettings };
  
  // Restart timer if running with new interval
  if (autoKeyTimer) {
    clearInterval(autoKeyTimer);
    const intervalMs = intervalToSeconds() * 1000;
    autoKeyTimer = setInterval(pressKey, intervalMs);
  }
});

ipcMain.on('toggle-autoclicker', () => {
  if (autoKeyTimer) {
    stopAutoclicker();
  } else {
    startAutoclicker();
  }
});

ipcMain.on('get-running-apps', (event) => {
  event.reply('running-apps', getRunningApps());
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
