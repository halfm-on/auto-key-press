local timer = nil
local settings = {key="a", count=0, interval=1, unit="seconds", app="TextEdit"}
local pressesDone = 0
local pollTimer = nil

-- Convert interval to seconds
local function intervalToSeconds()
    if settings.unit=="milliseconds" then return settings.interval/1000
    elseif settings.unit=="minutes" then return settings.interval*60
    else return settings.interval
    end
end

local function pressKey()
    if settings.count>0 and pressesDone>=settings.count then
        if timer then timer:stop() end
        timer=nil
        webview:evaluateJavaScript("document.getElementById('status').innerText='Stopped (done)'")
        return
    end
    local app = settings.app and settings.app ~= "" and hs.application.find(settings.app) or hs.application.frontmostApplication()
    hs.eventtap.keyStroke({}, settings.key, 0, app)
    pressesDone = pressesDone + 1
end

local function startPressing()
    if timer then timer:stop() end
    pressesDone=0
    timer=hs.timer.doEvery(intervalToSeconds(), pressKey)
    webview:evaluateJavaScript("document.getElementById('status').innerText='Running'")
end

local function stopPressing()
    if timer then timer:stop() end
    timer=nil
    webview:evaluateJavaScript("document.getElementById('status').innerText='Stopped'")
end

-- Function to save settings
local function saveSettings()
    webview:evaluateJavaScript([[
        JSON.stringify({
            key: document.getElementById('key').value,
            count: document.getElementById('count').value,
            interval: document.getElementById('interval').value,
            unit: document.getElementById('unit').value,
            app: document.getElementById('app').value
        })
    ]], function(jsonResult)
        local success, data = pcall(hs.json.decode, jsonResult)
        if success and data then
            settings.key = data.key or "a"
            settings.count = tonumber(data.count) or 0
            settings.interval = tonumber(data.interval) or 1
            settings.unit = data.unit or "seconds"
            settings.app = data.app or ""
            print("Settings auto-saved:", "key=" .. settings.key, "count=" .. settings.count, "interval=" .. settings.interval, "unit=" .. settings.unit, "app=" .. settings.app)
            webview:evaluateJavaScript("document.getElementById('status').innerText='Settings Auto-Saved'")
            
            -- If currently running, restart with new interval
            if timer then
                timer:stop()
                timer = hs.timer.doEvery(intervalToSeconds(), pressKey)
                print("Updated running timer with new interval:", intervalToSeconds())
            end
        else
            print("Error parsing settings JSON")
        end
    end)
end

-- Function to check for button clicks by polling
local function checkButtonClicks()
    if not webview then return end
    
    webview:evaluateJavaScript("window.buttonClicked || ''", function(result)
        if result and result ~= "" then
            print("Button clicked:", result)
            -- Clear the flag
            webview:evaluateJavaScript("window.buttonClicked = ''")
            
            if result == "save" then
                saveSettings()
            elseif result == "start" then 
                startPressing()
            elseif result == "stop" then 
                stopPressing()
            elseif result == "close" then 
                stopPressing()
                if pollTimer then pollTimer:stop() end
                webview:delete()
                webview = nil
                pollTimer = nil
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
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
}

.container {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border-radius: 20px;
    padding: 30px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
    width: 100%;
    max-width: 400px;
    border: 1px solid rgba(255, 255, 255, 0.2);
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
    display: grid;
    grid-template-columns: 1fr 1fr;
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
    flex-direction: column;
}

.btn-start {
    background: linear-gradient(135deg, #56ab2f, #a8e6cf);
    color: white;
}

.btn-stop {
    background: linear-gradient(135deg, #ff6b6b, #ee5a24);
    color: white;
}

.btn-close {
    background: linear-gradient(135deg, #757f9a, #d7dde8);
    color: #2c3e50;
    grid-column: span 2;
}

button:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}

button:active {
    transform: translateY(0);
}

.keybind {
    font-size: 11px;
    opacity: 0.8;
    margin-top: 2px;
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
        <input type="text" id="key" value="a" maxlength="1" placeholder="Enter single key">
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
        <input type="text" id="app" value="TextEdit" placeholder="Leave empty for frontmost app">
    </div>
    
    <div class="button-group">
        <button class="btn-start" onclick="window.buttonClicked='start'; console.log('Start clicked')">
            ▶️ Start
            <span class="keybind">Ctrl+Shift+S</span>
        </button>
        <button class="btn-stop" onclick="window.buttonClicked='stop'; console.log('Stop clicked')">
            ⏹️ Stop
            <span class="keybind">Ctrl+Shift+S</span>
        </button>
        <button class="btn-close" onclick="window.buttonClicked='close'; console.log('Close clicked')">
            ❌ Close
            <span class="keybind">Cmd+Shift+K</span>
        </button>
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
    
    // Set new timer to auto-save after 1 second of no changes
    autoSaveTimer = setTimeout(function() {
        window.buttonClicked = 'save';
        console.log('Auto-saving settings...');
    }, 1000);
}

// Add event listeners for auto-save
document.addEventListener('DOMContentLoaded', function() {
    const inputs = ['key', 'count', 'interval', 'unit', 'app'];
    
    inputs.forEach(function(inputId) {
        const element = document.getElementById(inputId);
        if (element) {
            element.addEventListener('input', triggerAutoSave);
            element.addEventListener('change', triggerAutoSave);
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

-- Start polling for button clicks every 100ms
pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)

-- Keybind functions
local function toggleWindow()
    if webview and webview:isVisible() then
        webview:hide()
    else
        if webview then
            webview:show()
        else
            -- Recreate webview if it was closed
            webview = hs.webview.new({x=200,y=200,w=480,h=580})
                :windowStyle({"titled","closable","resizable"})
                :windowTitle("Auto Key Presser")
                :allowTextEntry(true)
                :html(html)
                :level(hs.drawing.windowLevels.normal)
                :show()
            pollTimer = hs.timer.doEvery(0.1, checkButtonClicks)
        end
    end
end

local function closeWindow()
    if webview then
        stopPressing()
        if pollTimer then pollTimer:stop() end
        webview:delete()
        webview = nil
        pollTimer = nil
    end
end

local function startWithKeybind()
    if webview and webview:isVisible() then
        startPressing()
    end
end

local function stopWithKeybind()
    if webview and webview:isVisible() then
        stopPressing()
    end
end

-- Set up keybinds
-- Cmd+Shift+K to toggle the window
hs.hotkey.bind({"cmd", "shift"}, "K", toggleWindow)

-- Cmd+Shift+Q to close the window
hs.hotkey.bind({"cmd", "shift"}, "Q", closeWindow)

-- Cmd+Shift+S to start the autoclicker
hs.hotkey.bind({"cmd", "shift"}, "S", startWithKeybind)

-- Cmd+Shift+X to stop the autoclicker
hs.hotkey.bind({"cmd", "shift"}, "X", stopWithKeybind)

print("Auto Key Presser loaded with keybinds:")
print("  Cmd+Shift+K: Toggle window")
print("  Cmd+Shift+Q: Close window")
print("  Cmd+Shift+S: Start autoclicker")
print("  Cmd+Shift+X: Stop autoclicker")