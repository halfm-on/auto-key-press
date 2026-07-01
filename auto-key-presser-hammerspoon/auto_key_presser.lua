local timer = nil
local settings = {key="a", count=0, interval=1, unit="seconds", app="TextEdit", holdDuration=50}
local pressesDone = 0
local paused = false
local pollTimer = nil

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
    local holdUs = (settings.holdDuration or 50) * 1000  -- ms to microseconds
    print("[DEBUG] Pressing key:", settings.key, "hold(ms):", settings.holdDuration)

    if settings.app and settings.app ~= "" and app then
        local keyCode = hs.keycodes.map[settings.key]
        if keyCode then
            local keyDownEvent = hs.eventtap.event.newKeyEvent({}, settings.key, true)
            local keyUpEvent = hs.eventtap.event.newKeyEvent({}, settings.key, false)
            keyDownEvent:post(app)
            hs.timer.usleep(holdUs)
            keyUpEvent:post(app)
        else
            hs.eventtap.keyStroke({}, settings.key, 0, app)
        end
    else
        local keyCode = hs.keycodes.map[settings.key]
        if keyCode then
            local keyDownEvent = hs.eventtap.event.newKeyEvent({}, settings.key, true)
            local keyUpEvent = hs.eventtap.event.newKeyEvent({}, settings.key, false)
            keyDownEvent:post()
            hs.timer.usleep(holdUs)
            keyUpEvent:post()
        else
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

local function getOpenApplications()
    local apps = {}
    local seenByBundle = {}
    local seenByName = {}

    local function isExcluded(name, bundleID)
        if bundleID == "org.hammerspoon.Hammerspoon" then return true end
        if not name then return true end
        return name:find("Helper") or name:find("Renderer") or name:find("GPU Process") or
               name:find("Crashpad") or name:find("Web Content") or name:find("UIService") or
               name:find("UIViewService") or name:find("Daemon") or name:find("Notification")
    end

    local runningApps = hs.application.runningApplications()
    for _, app in ipairs(runningApps) do
        local name = app:name()
        local bundleID = app:bundleID() or ""
        if name and name ~= "" and not isExcluded(name, bundleID) then
            local hidden = false
            pcall(function() hidden = app:isHidden() end)
            if not hidden then
                local hasActiveWindow = false
                local wins = nil
                pcall(function() wins = app:allWindows() end)
                if wins then
                    for i = 1, #wins do
                        local w = wins[i]
                        local notMin = true
                        local looksLikeWindow = false
                        pcall(function() notMin = not w:isMinimized() end)
                        if notMin then
                            local std = false
                            local fs = false
                            local title = nil
                            pcall(function() std = w:isStandard() end)
                            pcall(function() fs = w:isFullScreen() end)
                            if std or fs then
                                looksLikeWindow = true
                            else
                                pcall(function() title = w:title() end)
                                looksLikeWindow = title and title ~= ""
                            end
                            if looksLikeWindow then
                                hasActiveWindow = true
                                break
                            end
                        end
                    end
                end
                if hasActiveWindow then
                    if (bundleID ~= "" and not seenByBundle[bundleID]) or (bundleID == "" and not seenByName[name]) then
                        table.insert(apps, name)
                        if bundleID ~= "" then seenByBundle[bundleID] = true
                        else seenByName[name] = true end
                    end
                end
            end
        end
    end

    if #apps < 5 then
        local seen = {}
        for _, app in ipairs(runningApps) do
            local name = app:name()
            local bundleID = app:bundleID() or ""
            if name and name ~= "" and not isExcluded(name, bundleID) then
                local hidden = false
                pcall(function() hidden = app:isHidden() end)
                if not hidden then
                    local key = bundleID ~= "" and bundleID or name
                    if not seen[key] then
                        table.insert(apps, name)
                        seen[key] = true
                    end
                end
            end
        end
    end

    table.sort(apps)
    return apps
end

local function populateAppDropdown()
    if not webview then return end

    local openApps = getOpenApplications()
    local options = '<option value="">Frontmost App</option>'

    for _, appName in ipairs(openApps) do
        local selected = (appName == settings.app) and ' selected' or ''
        options = options .. '<option value="' .. appName .. '"' .. selected .. '>' .. appName .. '</option>'
    end

    webview:evaluateJavaScript([[
        var appSelect = document.getElementById('app');
        appSelect.innerHTML = ']] .. options .. [[';
        if (']] .. (settings.app or "") .. [[') {
            appSelect.value = ']] .. (settings.app or "") .. [[';
        }
    ]])
end

local function saveSettings()
    print("[DEBUG] Saving settings")
    webview:evaluateJavaScript([[
        var keyValue = document.getElementById('key').value.trim();
        var countValue = document.getElementById('count').value;
        var intervalValue = document.getElementById('interval').value;
        var unitValue = document.getElementById('unit').value;
        var appValue = document.getElementById('app').value;
        var holdValue = document.getElementById('holdDuration').value;
        JSON.stringify({
            key: keyValue,
            count: countValue,
            interval: intervalValue,
            unit: unitValue,
            app: appValue,
            holdDuration: holdValue
        })
    ]], function(jsonResult)
        local success, data = pcall(hs.json.decode, jsonResult)
        if success and data then
            settings.key = (data.key and data.key ~= "") and data.key or "a"
            settings.count = tonumber(data.count) or 0
            settings.interval = tonumber(data.interval) or 1
            settings.unit = data.unit or "seconds"
            settings.app = data.app or ""
            settings.holdDuration = tonumber(data.holdDuration) or 50
            print("[DEBUG] Settings saved: key=" .. settings.key .. " hold=" .. settings.holdDuration .. "ms")
            if webview then webview:evaluateJavaScript("document.getElementById('status').innerText='Settings Auto-Saved'") end
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

local function checkButtonClicks()
    if not webview then return end
    webview:evaluateJavaScript("window.buttonClicked || ''", function(result)
        if result and result ~= "" then
            print("[DEBUG] Button clicked:", result)
            webview:evaluateJavaScript("window.buttonClicked = ''")
            if result == "toggle" then
                if timer then stopPressing() else startPressing() end
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
* { box-sizing: border-box; }
body {
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', Helvetica, Arial, sans-serif;
    padding: 0; margin: 0;
    background: #f8f9fa;
    min-height: 100vh;
}
.container {
    background: white;
    padding: 24px 30px 30px;
    width: 100%; height: 100vh;
    box-sizing: border-box;
    overflow-y: auto;
}
h2 {
    text-align: center;
    margin-bottom: 22px;
    color: #2c3e50;
    font-weight: 600;
    font-size: 22px;
}
.form-group { margin-bottom: 18px; }
label {
    display: block;
    margin-bottom: 5px;
    font-weight: 500;
    color: #34495e;
    font-size: 13px;
}
.hint {
    display: block;
    font-size: 11px;
    color: #95a5a6;
    margin-top: 3px;
}
input[type="text"], input[type="number"], select {
    width: 100%;
    padding: 10px 14px;
    border: 2px solid #e1e8ed;
    border-radius: 10px;
    font-size: 15px;
    transition: all 0.2s ease;
    background: white;
    color: #2c3e50;
}
input[type="text"]:focus, input[type="number"]:focus, select:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102,126,234,0.1);
}
.row {
    display: flex;
    gap: 10px;
    align-items: flex-end;
}
.row > * { flex: 1; }
.row .narrow { flex: 0 0 auto; }
.button-group {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 22px;
    margin-bottom: 18px;
}
button {
    padding: 12px 20px;
    border: none;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
}
.btn-toggle { background: linear-gradient(135deg, #868e96, #6c757d); color: white; }
.btn-toggle.running { background: linear-gradient(135deg, #6c757d, #495057); }
button:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.12); }
button:active { transform: translateY(0); }
.status-container {
    text-align: center;
    padding: 14px;
    background: rgba(102,126,234,0.08);
    border-radius: 10px;
    border: 1px solid rgba(102,126,234,0.18);
}
.status-label { font-size: 13px; color: #34495e; margin-bottom: 4px; }
.status { font-weight: 700; font-size: 15px; color: #667eea; }
.key-input-wrap { position: relative; }
.key-badge {
    display: inline-block;
    background: #f0f0f0;
    border: 1px solid #ccc;
    border-radius: 5px;
    padding: 1px 7px;
    font-family: monospace;
    font-size: 12px;
    color: #444;
    margin: 2px 2px 0 0;
    cursor: pointer;
    user-select: none;
}
.key-badge:hover { background: #dde; border-color: #667eea; color: #667eea; }
.keys-hint { margin-top: 6px; line-height: 2; }
</style>
</head>
<body>
<div class="container">
    <h2>⌨️ Auto Key Presser</h2>

    <div class="form-group">
        <label for="key">Key to press</label>
        <div class="key-input-wrap">
            <input type="text" id="key" value="a" maxlength="20" placeholder="e.g. a, space, f5, up, return">
        </div>
        <div class="keys-hint">
            <span class="key-badge" onclick="setKey('space')">space</span>
            <span class="key-badge" onclick="setKey('return')">return</span>
            <span class="key-badge" onclick="setKey('escape')">escape</span>
            <span class="key-badge" onclick="setKey('tab')">tab</span>
            <span class="key-badge" onclick="setKey('delete')">delete</span>
            <span class="key-badge" onclick="setKey('up')">up</span>
            <span class="key-badge" onclick="setKey('down')">down</span>
            <span class="key-badge" onclick="setKey('left')">left</span>
            <span class="key-badge" onclick="setKey('right')">right</span>
            <span class="key-badge" onclick="setKey('f1')">f1</span>
            <span class="key-badge" onclick="setKey('f5')">f5</span>
            <span class="key-badge" onclick="setKey('f12')">f12</span>
        </div>
    </div>

    <div class="form-group">
        <div class="row">
            <div>
                <label for="holdDuration">Hold duration (ms)</label>
                <input type="number" id="holdDuration" value="50" min="1" max="60000" step="1" placeholder="50">
            </div>
            <div>
                <label for="count">Press count</label>
                <input type="number" id="count" value="0" min="0" placeholder="0 = infinite">
            </div>
        </div>
        <span class="hint">Hold duration: how long the key is held down each press. 50ms feels natural; go higher to simulate a long-press.</span>
    </div>

    <div class="form-group">
        <label>Interval between presses</label>
        <div class="row">
            <input type="number" id="interval" value="1" min="0.001" step="0.001" placeholder="1">
            <select id="unit" style="flex: 0 0 140px;">
                <option value="seconds" selected>Seconds</option>
                <option value="milliseconds">Milliseconds</option>
                <option value="minutes">Minutes</option>
            </select>
        </div>
    </div>

    <div class="form-group">
        <label for="app">Target application</label>
        <div class="row">
            <select id="app">
                <option value="">Frontmost App</option>
                <option value="TextEdit" selected>TextEdit</option>
            </select>
            <button onclick="window.buttonClicked='refresh'" style="flex: 0 0 auto; padding: 8px 12px; background: #6c757d; color: white; border-radius: 8px; font-size: 13px;">🔄</button>
        </div>
    </div>

    <div class="button-group">
        <button class="btn-toggle" id="toggleBtn" onclick="window.buttonClicked='toggle'">▶️ Start/Stop (Ctrl+Shift+S)</button>
    </div>

    <div class="status-container">
        <div class="status-label">Status</div>
        <div id="status" class="status">Stopped</div>
    </div>
</div>

<script>
window.buttonClicked = '';

function setKey(k) {
    var el = document.getElementById('key');
    el.value = k;
    el.dispatchEvent(new Event('change'));
}

var autoSaveTimer = null;
function triggerAutoSave() {
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
    autoSaveTimer = setTimeout(function() {
        window.buttonClicked = 'save';
    }, 100);
}

document.addEventListener('DOMContentLoaded', function() {
    var inputs = ['key', 'count', 'interval', 'unit', 'app', 'holdDuration'];
    inputs.forEach(function(id) {
        var el = document.getElementById(id);
        if (el) {
            el.addEventListener('input', triggerAutoSave);
            el.addEventListener('change', triggerAutoSave);
        }
    });
});
</script>
</body>
</html>
]]

webview = hs.webview.new({x=200,y=200,w=480,h=620})
    :windowStyle({"titled","closable","resizable"})
    :windowTitle("Auto Key Presser")
    :allowTextEntry(true)
    :html(html)
    :level(hs.drawing.windowLevels.normal)
    :show()
print("[DEBUG] Webview created and shown")

local uiInitPollTimer = nil
uiInitPollTimer = hs.timer.doEvery(0.08, function()
    if not webview then return end
    webview:evaluateJavaScript("document.readyState", function(state)
        if state == "complete" or state == "interactive" then
            hs.timer.doAfter(0.25, populateAppDropdown)
            if webview then
                webview:evaluateJavaScript([[\
                    (function(){\
                        var k=document.getElementById('key'); if(k){k.value=']] .. (settings.key or "a") .. [[';}\
                        var c=document.getElementById('count'); if(c){c.value=']] .. (settings.count or 0) .. [[';}\
                        var i=document.getElementById('interval'); if(i){i.value=']] .. (settings.interval or 1) .. [[';}\
                        var u=document.getElementById('unit'); if(u){u.value=']] .. (settings.unit or "seconds") .. [[';}\
                        var h=document.getElementById('holdDuration'); if(h){h.value=']] .. (settings.holdDuration or 50) .. [[';}\
                        return true;\
                    })();
                ]])
            end
            if uiInitPollTimer then uiInitPollTimer:stop() uiInitPollTimer = nil end
            print("[DEBUG] UI initialized")
        end
    end)
end)

pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)
print("[DEBUG] Poll timer started")

local lastAppListKey = ""
local appListDirty = true

local appWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if eventType == hs.application.watcher.launched or
       eventType == hs.application.watcher.terminated or
       eventType == hs.application.watcher.hidden or
       eventType == hs.application.watcher.unhidden or
       eventType == hs.application.watcher.activated then
        appListDirty = true
    end
end)
appWatcher:start()

hs.timer.doAfter(0.5, function()
    hs.timer.doEvery(1.0, function()
        if not webview then return end
        if not appListDirty then return end
        appListDirty = false
        local list = getOpenApplications()
        local key = table.concat(list, "\0")
        if key ~= lastAppListKey then
            lastAppListKey = key
            populateAppDropdown()
        end
    end)
end)

local function toggleWindow()
    if webview and webview:isVisible() then
        webview:hide()
    else
        if webview then
            webview:show()
            hs.timer.doAfter(0.2, populateAppDropdown)
        else
            webview = hs.webview.new({x=200,y=200,w=480,h=620})
                :windowStyle({"titled","closable","resizable"})
                :windowTitle("Auto Key Presser")
                :allowTextEntry(true)
                :html(html)
                :level(hs.drawing.windowLevels.normal)
                :show()
            pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)
            hs.timer.doAfter(0.2, populateAppDropdown)
        end
    end
end

local function toggleAutoclickerHotkey()
    if timer then stopPressing() else startPressing() end
end

hs.hotkey.bind({"cmd", "shift"}, "K", toggleWindow)
hs.hotkey.bind({"ctrl", "shift"}, "S", toggleAutoclickerHotkey)

print("Auto Key Presser loaded:")
print("  Cmd+Shift+K: Toggle window")
print("  Ctrl+Shift+S: Toggle autoclicker ON/OFF")
