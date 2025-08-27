local timer = nil
local settings = {key="a", count=0, interval=1, unit="seconds", app="TextEdit"}
local pressesDone = 0
local paused = false
local pollTimer = nil

-- Convert interval to seconds
local function intervalToSeconds()
    if settings.unit=="milliseconds" then return settings.interval/1000
    elseif settings.unit=="minutes" then return settings.interval*60
    else return settings.interval
    end
end

local function pressKey()
    if paused then return end
    if settings.count>0 and pressesDone>=settings.count then
        if timer then timer:stop() end
        timer=nil
        if webview then webview:evaluateJavaScript("document.getElementById('status').innerText='Stopped (done)'") end
        print("[DEBUG] Reached target count; stopped timer")
        return
    end
    
    local app = settings.app and settings.app ~= "" and hs.application.find(settings.app) or hs.application.frontmostApplication()
    print("[DEBUG] Pressing key:", settings.key, "target app:", settings.app ~= "" and settings.app or "frontmost")
    print("[DEBUG] App found:", app and "YES" or "NO", "App name:", app and app:name() or "NONE")
    
    -- Try different approaches for better game compatibility
    if settings.app and settings.app ~= "" and app then
        -- Method 1: Create more realistic key events for games
        local keyCode = hs.keycodes.map[settings.key]
        if keyCode then
            -- Create key down and key up events like real keyboard input
            local keyDownEvent = hs.eventtap.event.newKeyEvent({}, settings.key, true)
            local keyUpEvent = hs.eventtap.event.newKeyEvent({}, settings.key, false)
            
            -- Send to the specific app
            keyDownEvent:post(app)
            hs.timer.usleep(50000) -- 50ms delay between down and up
            keyUpEvent:post(app)
        else
            -- Fallback to keyStroke
            hs.eventtap.keyStroke({}, settings.key, 0, app)
        end
    else
        -- Method 2: Send globally (like MurGaa might do)
        local keyCode = hs.keycodes.map[settings.key]
        if keyCode then
            -- Create key down and key up events like real keyboard input
            local keyDownEvent = hs.eventtap.event.newKeyEvent({}, settings.key, true)
            local keyUpEvent = hs.eventtap.event.newKeyEvent({}, settings.key, false)
            
            -- Send globally
            keyDownEvent:post()
            hs.timer.usleep(50000) -- 50ms delay between down and up
            keyUpEvent:post()
        else
            -- Fallback to keyStroke
            hs.eventtap.keyStroke({}, settings.key, 0)
        end
    end
    
    pressesDone = pressesDone + 1
    print("[DEBUG] pressesDone=", pressesDone)
end

local function startPressing()
    if timer then timer:stop() end
    pressesDone=0
    paused=false
    timer=hs.timer.doEvery(intervalToSeconds(), pressKey)
    if webview then 
        webview:evaluateJavaScript("document.getElementById('status').innerText='Running'")
        webview:evaluateJavaScript("document.getElementById('toggleBtn').innerText='⏹️ Stop (Ctrl+Shift+S)'")
        webview:evaluateJavaScript("document.getElementById('toggleBtn').className='btn-toggle running'")
    end
    print("[DEBUG] Started autoclicker with interval(s)=", intervalToSeconds())
end

local function stopPressing()
    if timer then timer:stop() end
    timer=nil
    paused=false
    if webview then 
        webview:evaluateJavaScript("document.getElementById('status').innerText='Stopped'")
        webview:evaluateJavaScript("document.getElementById('toggleBtn').innerText='▶️ Start/Stop (Ctrl+Shift+S)'")
        webview:evaluateJavaScript("document.getElementById('toggleBtn').className='btn-toggle'")
    end
    print("[DEBUG] Stopped autoclicker")
end

local function togglePause()
    if not timer then return end
    paused = not paused
    if paused then
        if webview then webview:evaluateJavaScript("document.getElementById('status').innerText='Paused'") end
        print("[DEBUG] Paused autoclicker")
    else
        if webview then webview:evaluateJavaScript("document.getElementById('status').innerText='Running'") end
        print("[DEBUG] Resumed autoclicker")
    end
end

-- Function to get list of open applications
local function getOpenApplications()
    local apps = {}
    local runningApps = hs.application.runningApplications()
    
    -- List of major apps to include (add more as needed)
    local majorApps = {
        "Google Chrome", "Safari", "Firefox", "Microsoft Edge", "Opera",
        "Spotify", "Apple Music", "iTunes",
        "TextEdit", "Pages", "Microsoft Word", "Google Docs",
        "Xcode", "Visual Studio Code", "Cursor", "Sublime Text", "Atom",
        "Terminal", "iTerm2", "Hyper",
        "Finder", "System Preferences", "System Settings",
        "Mail", "Messages", "Slack", "Discord", "Zoom", "Teams",
        "Photoshop", "Illustrator", "Figma", "Sketch",
        "Steam", "Epic Games Launcher", "Battle.net", "Roblox", "AdobeLightroom",
        "Preview", "QuickTime Player", "VLC", "IINA", "Code"
    }
    
    -- Create a set for faster lookup
    local majorAppsSet = {}
    for _, appName in ipairs(majorApps) do
        majorAppsSet[appName] = true
    end
    
    -- First, add major apps that are running
    for _, app in pairs(runningApps) do
        if app:name() and majorAppsSet[app:name()] then
            table.insert(apps, app:name())
        end
    end
    
    -- Then, add any other running apps that might be renamed versions of major apps
    for _, app in pairs(runningApps) do
        if app:name() and not majorAppsSet[app:name()] then
            -- Check if it's a game or major application by looking at bundle ID or other properties
            local bundleID = app:bundleID()
            if bundleID then
                -- Only add specific apps we want, not all Apple system apps
                if string.find(bundleID, "com.roblox") or 
                   string.find(bundleID, "com.spotify") or
                   string.find(bundleID, "com.hnc.Discord") or
                   string.find(bundleID, "com.microsoft.VSCode") or
                   string.find(bundleID, "com.todesktop.230313mzl4w4u92") then
                    -- Filter out helper/plugin processes
                    if not string.find(app:name(), "Helper") and 
                       not string.find(app:name(), "Plugin") and
                       not string.find(app:name(), "Renderer") and
                       not string.find(app:name(), "fileWatcher") and
                       not string.find(app:name(), "shared%-process") and
                       not string.find(app:name(), "terminal pty%-host") then
                        print("[DEBUG] Adding app: " .. app:name() .. " (matched bundle ID)")
                        table.insert(apps, app:name())
                    end
                end
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(apps)
    
    -- If no apps were found, include all running apps as fallback
    if #apps == 0 then
        print("[DEBUG] No major apps found, including all running apps")
        for _, app in pairs(runningApps) do
            if app:name() then
                table.insert(apps, app:name())
            end
        end
        table.sort(apps)
    end
    
    return apps
end

-- Function to populate app dropdown
local function populateAppDropdown()
    if not webview then return end
    
    -- Debug: Show ALL running applications first
    print("[DEBUG] ALL running applications:")
    local allRunningApps = hs.application.runningApplications()
    for _, app in pairs(allRunningApps) do
        if app:name() then
            print("  - " .. app:name() .. " (Bundle ID: " .. (app:bundleID() or "none") .. ")")
        end
    end
    
    local openApps = getOpenApplications()
    local options = '<option value="">Frontmost App</option>'
    
    -- Debug: Print all detected apps
    print("[DEBUG] Filtered applications:")
    for _, appName in ipairs(openApps) do
        print("  - " .. appName)
    end
    
    -- If Roblox is not in the filtered list, add it manually
    local hasRoblox = false
    for _, appName in ipairs(openApps) do
        if appName == "Roblox" then
            hasRoblox = true
            break
        end
    end
    
    if not hasRoblox then
        print("[DEBUG] Roblox not found in filtered list, adding it manually")
        table.insert(openApps, "Roblox")
        table.sort(openApps)
    end
    
    for _, appName in ipairs(openApps) do
        local selected = (appName == settings.app) and ' selected' or ''
        options = options .. '<option value="' .. appName .. '"' .. selected .. '>' .. appName .. '</option>'
    end
    
    webview:evaluateJavaScript([[
        var appSelect = document.getElementById('app');
        appSelect.innerHTML = ']] .. options .. [[';
        
        // Preserve the current selection after repopulating
        if (']] .. (settings.app or "") .. [[') {
            appSelect.value = ']] .. (settings.app or "") .. [[';
        }
    ]])
end

-- Function to save settings
local function saveSettings()
    print("[DEBUG] Saving settings (manual or auto)")
    webview:evaluateJavaScript([[
        var keyValue = document.getElementById('key').value;
        var countValue = document.getElementById('count').value;
        var intervalValue = document.getElementById('interval').value;
        var unitValue = document.getElementById('unit').value;
        var appValue = document.getElementById('app').value;
        
        console.log('Form values:', {key: keyValue, count: countValue, interval: intervalValue, unit: unitValue, app: appValue});
        
        JSON.stringify({
            key: keyValue,
            count: countValue,
            interval: intervalValue,
            unit: unitValue,
            app: appValue
        })
    ]], function(jsonResult)
        local success, data = pcall(hs.json.decode, jsonResult)
        if success and data then
            print("[DEBUG] Raw settings data:", jsonResult)
            settings.key = data.key or "a"
            settings.count = tonumber(data.count) or 0
            settings.interval = tonumber(data.interval) or 1
            settings.unit = data.unit or "seconds"
            settings.app = data.app or ""
            print("[DEBUG] Settings saved:", "key=" .. settings.key, "count=" .. settings.count, "interval=" .. settings.interval, "unit=" .. settings.unit, "app=" .. settings.app)
            if webview then webview:evaluateJavaScript("document.getElementById('status').innerText='Settings Auto-Saved'") end
            
            -- If currently running, restart with new interval
            if timer then
                timer:stop()
                timer = hs.timer.doEvery(intervalToSeconds(), pressKey)
                print("[DEBUG] Updated running timer with new interval(s)=", intervalToSeconds())
            end
        else
            print("[DEBUG] Error parsing settings JSON:", jsonResult)
        end
    end)
end

-- Function to check for button clicks by polling
local function checkButtonClicks()
    if not webview then return end
    
    webview:evaluateJavaScript("window.buttonClicked || ''", function(result)
        if result and result ~= "" then
            print("[DEBUG] Button clicked:", result)
            -- Clear the flag
            webview:evaluateJavaScript("window.buttonClicked = ''")
            
            if result == "toggle" then 
                if timer then
                    stopPressing()
                else
                    startPressing()
                end
            elseif result == "save" then
                saveSettings()
            elseif result == "refresh" then
                populateAppDropdown()
            end
        end
    end)
end

local html = [[
<html>
<head>
<style>
* {
    box-sizing: border-box;
}

body { 
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', Helvetica, Arial, sans-serif; 
    padding: 0;
    margin: 0;
    background: #f8f9fa;
    min-height: 100vh;
}

.container {
    background: white;
    padding: 30px;
    width: 100%;
    height: 100vh;
    box-sizing: border-box;
}

h2 {
    text-align: center;
    margin-bottom: 25px;
    color: #2c3e50;
    font-weight: 600;
    font-size: 24px;
}

.form-group {
    margin-bottom: 20px;
}

label {
    display: block;
    margin-bottom: 6px;
    font-weight: 500;
    color: #34495e;
    font-size: 14px;
}

input[type="text"], input[type="number"], select {
    width: 100%;
    padding: 12px 16px;
    border: 2px solid #e1e8ed;
    border-radius: 10px;
    font-size: 16px;
    transition: all 0.3s ease;
    background: white;
}

input[type="text"]:focus, input[type="number"]:focus, select:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.interval-group {
    display: flex;
    gap: 10px;
    align-items: flex-end;
}

.interval-input, .interval-unit {
    flex: 1;
}

input[type="number"], select {
    width: 100%;
    height: 44px; /* Ensures same height */
    padding: 10px 14px;
    border: 2px solid #e1e8ed;
    border-radius: 10px;
    font-size: 16px;
    appearance: none; /* Makes select cleaner */
}


.button-group {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 25px;
    margin-bottom: 20px;
}

button {
    padding: 12px 20px;
    border: none;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
}

.btn-toggle {
    background: linear-gradient(135deg, #868e96, #6c757d);
    color: white;
}

.btn-toggle.running {
    background: linear-gradient(135deg, #6c757d, #495057);
}

button:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}

button:active {
    transform: translateY(0);
}

.status-container {
    text-align: center;
    padding: 15px;
    background: rgba(102, 126, 234, 0.1);
    border-radius: 10px;
    border: 1px solid rgba(102, 126, 234, 0.2);
}

.status-label {
    font-size: 14px;
    color: #34495e;
    margin-bottom: 5px;
}

.status {
    font-weight: 700;
    font-size: 16px;
    color: #667eea;
}

.status.running {
    color: #56ab2f;
}

.status.paused {
    color: #f5576c;
}

.status.stopped {
    color: #ee5a24;
}

input[type="text"]::placeholder,
input[type="number"]::placeholder {
    color: #95a5a6;
}
</style>
</head>
<body>
<div class="container">
    <h2>⌨️ Auto Key Presser</h2>
    
    <div class="form-group">
        <label for="key">Key to Press</label>
        <select id="key">
            <option value="a" selected>a</option>
            <option value="b">b</option>
            <option value="c">c</option>
            <option value="d">d</option>
            <option value="e">e</option>
            <option value="f">f</option>
            <option value="g">g</option>
            <option value="h">h</option>
            <option value="i">i</option>
            <option value="j">j</option>
            <option value="k">k</option>
            <option value="l">l</option>
            <option value="m">m</option>
            <option value="n">n</option>
            <option value="o">o</option>
            <option value="p">p</option>
            <option value="q">q</option>
            <option value="r">r</option>
            <option value="s">s</option>
            <option value="t">t</option>
            <option value="u">u</option>
            <option value="v">v</option>
            <option value="w">w</option>
            <option value="x">x</option>
            <option value="y">y</option>
            <option value="z">z</option>
            <option value="space">Space</option>
            <option value="tab">Tab</option>
            <option value="return">Enter</option>
            <option value="escape">Escape</option>
            <option value="delete">Delete</option>
            <option value="forwarddelete">Forward Delete</option>
            <option value="up">Up Arrow</option>
            <option value="down">Down Arrow</option>
            <option value="left">Left Arrow</option>
            <option value="right">Right Arrow</option>
            <option value="home">Home</option>
            <option value="end">End</option>
            <option value="pageup">Page Up</option>
            <option value="pagedown">Page Down</option>
            <option value="f1">F1</option>
            <option value="f2">F2</option>
            <option value="f3">F3</option>
            <option value="f4">F4</option>
            <option value="f5">F5</option>
            <option value="f6">F6</option>
            <option value="f7">F7</option>
            <option value="f8">F8</option>
            <option value="f9">F9</option>
            <option value="f10">F10</option>
            <option value="f11">F11</option>
            <option value="f12">F12</option>
        </select>
    </div>
    
    <div class="form-group">
        <label for="count">Press Count</label>
        <input type="number" id="count" value="0" min="0" placeholder="0 = infinite">
    </div>
    
    <div class="form-group">
        <label>Interval</label>
        <div class="interval-group">
            <div class="interval-input">
                <input type="number" id="interval" value="1" min="0.001" step="0.001" placeholder="1">
            </div>
            <div class="interval-unit">
                <select id="unit">
                    <option value="seconds" selected>Seconds</option>
                    <option value="milliseconds">Milliseconds</option>
                    <option value="minutes">Minutes</option>
                </select>
            </div>
        </div>
    </div>
    
    <div class="form-group">
        <label for="app">Target Application</label>
        <div style="display: flex; gap: 10px; align-items: center;">
            <select id="app" style="flex: 1;">
                <option value="">Frontmost App</option>
                <option value="TextEdit" selected>TextEdit</option>
            </select>
            <button onclick="window.buttonClicked='refresh'; console.log('Refresh clicked')" style="padding: 8px 12px; background: #6c757d; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 12px;">🔄</button>
        </div>
    </div>
    
    <div class="button-group">
        <button class="btn-toggle" id="toggleBtn" onclick="window.buttonClicked='toggle'; console.log('Toggle clicked')">▶️ Start/Stop (Ctrl+Shift+S)</button>
    </div>
    
    <div class="status-container">
        <div class="status-label">Status</div>
        <div id="status" class="status stopped">Stopped</div>
    </div>
</div>

<script>
window.buttonClicked = '';
console.log('Page loaded and ready');

// Auto-save functionality
let autoSaveTimer = null;

function triggerAutoSave() {
    // Clear existing timer
    if (autoSaveTimer) {
        clearTimeout(autoSaveTimer);
    }
    
    // Set new timer to auto-save after 100ms of no changes
    autoSaveTimer = setTimeout(function() {
        window.buttonClicked = 'save';
        console.log('Auto-saving settings...');
    }, 100); // Much faster auto-save
}

// Add event listeners for auto-save
document.addEventListener('DOMContentLoaded', function() {
    const inputs = ['key', 'count', 'interval', 'unit', 'app'];
    
    inputs.forEach(function(inputId) {
        const element = document.getElementById(inputId);
        if (element) {
            element.addEventListener('input', function() {
                console.log('Input changed:', inputId, element.value);
                triggerAutoSave();
            });
            element.addEventListener('change', function() {
                console.log('Change event:', inputId, element.value);
                triggerAutoSave();
            });
        }
    });
});

// Update status classes
function updateStatus(newStatus) {
    const statusEl = document.getElementById('status');
    statusEl.className = 'status ' + newStatus.toLowerCase().replace(/[^a-z]/g, '');
    statusEl.innerText = newStatus;
}

// Override the status updates to use the new function
const originalEvaluateJavaScript = window.evaluateJavaScript;
</script>
</body>
</html>
]]

-- Create webview
webview = hs.webview.new({x=200,y=200,w=480,h=580})
    :windowStyle({"titled","closable","resizable"})
    :windowTitle("Auto Key Presser")
    :allowTextEntry(true)
    :html(html)
    :level(hs.drawing.windowLevels.normal)
    -- :behaviorAsLabels({"canJoinAllSpaces"}) --> makes it appear on all spaces
    :show()
print("[DEBUG] Webview created and shown")

-- Populate app dropdown after webview is created
hs.timer.doAfter(0.1, function()
    populateAppDropdown()
    -- Load current settings into the form
    if webview then
        webview:evaluateJavaScript([[
            document.getElementById('key').value = ']] .. (settings.key or "a") .. [[';
            document.getElementById('count').value = ']] .. (settings.count or 0) .. [[';
            document.getElementById('interval').value = ']] .. (settings.interval or 1) .. [[';
            document.getElementById('unit').value = ']] .. (settings.unit or "seconds") .. [[';
            // App will be set by populateAppDropdown
        ]])
    end
end)

-- Start polling for button clicks every 100ms
pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)
print("[DEBUG] Poll timer started (100ms)")

-- Keybind functions
local function toggleWindow()
    if webview and webview:isVisible() then
        webview:hide()
        print("[DEBUG] Window hidden via hotkey")
    else
        if webview then
            webview:show()
            print("[DEBUG] Window shown via hotkey")
        else
            -- Recreate webview if it was closed
            webview = hs.webview.new({x=200,y=200,w=480,h=580})
                :windowStyle({"titled","closable","resizable"})
                :windowTitle("Auto Key Presser")
                :allowTextEntry(true)
                :html(html)
                :level(hs.drawing.windowLevels.normal)
                :show()
            print("[DEBUG] Webview recreated and shown via hotkey")
            pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)
            print("[DEBUG] Poll timer restarted (100ms)")
            hs.timer.doAfter(0.1, populateAppDropdown)
        end
    end
end

-- Toggle autoclicker with a single hotkey (works even if GUI is closed)
local function toggleAutoclickerHotkey()
    if timer then
        print("[DEBUG] Hotkey: toggling OFF")
        stopPressing()
    else
        print("[DEBUG] Hotkey: toggling ON")
        startPressing()
    end
end

-- Set up keybinds
-- Cmd+Shift+K to toggle the window
hs.hotkey.bind({"cmd", "shift"}, "K", toggleWindow)

-- Ctrl+Shift+S to toggle the autoclicker
hs.hotkey.bind({"ctrl", "shift"}, "S", toggleAutoclickerHotkey)

print("Auto Key Presser loaded with keybinds:")
print("  Cmd+Shift+K: Toggle window")
print("  Ctrl+Shift+S: Toggle autoclicker ON/OFF")