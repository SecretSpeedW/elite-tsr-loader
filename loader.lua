-- language: Lua, file: loader.lua, target: Roblox (Potassium / Standard Luau)
-- Elite Hub Secure Loader

local WORKER_URL = "https://elite-hub-gate.pavlo-melnik001.workers.dev"
local SAVE_FILE = "elite_tsr_key.txt"
local DISCORD_INVITE = "https://discord.gg/sy79UrhJj8"

-- Capture privileged globals NOW, while this thread still has full capabilities.
-- On some executors (Project Real) threads resumed after a yield / from UI callbacks
-- cannot touch `Instance` (capability Plugin), so we hand it to the hub via a custom env.
local RealInstance = Instance
getgenv().__EliteInstance = RealInstance
local BaseEnv = getfenv(1)
local Captured = {
    Instance = RealInstance, game = game, workspace = workspace, Enum = Enum,
    Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, UDim2 = UDim2, UDim = UDim,
    Color3 = Color3, ColorSequence = ColorSequence, NumberSequence = NumberSequence,
    NumberRange = NumberRange, TweenInfo = TweenInfo, Rect = Rect, Font = Font,
    Ray = Ray, Region3 = Region3, BrickColor = BrickColor, Random = Random,
    task = task, typeof = typeof, require = require, shared = shared,
}
local ScriptEnv
ScriptEnv = setmetatable({}, {
    __index = function(_, k)
        local v = Captured[k]
        if v ~= nil then return v end
        return BaseEnv[k]
    end,
    __newindex = function(_, k, v) rawset(ScriptEnv, k, v) end,
})
rawset(ScriptEnv, "loadstring", function(src, name)
    local f, e = loadstring(src, name)
    if f and setfenv then pcall(setfenv, f, ScriptEnv) end
    return f, e
end)
rawset(ScriptEnv, "_G", BaseEnv._G or _G)

-- Anti-Hooking Protection Check
pcall(function()
    if isfunctionhooked and (isfunctionhooked(loadstring) or isfunctionhooked(print)) then
        error("Security violation detected: Execution aborted.")
    end
end)

local function httpRequest(options)
    local fn = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if fn then return fn(options) end
    error("Executor does not support HTTP requests")
end

local function executeScript(code)
    local loaded, compileErr = loadstring(code)
    if loaded then
        if setfenv then pcall(setfenv, loaded, ScriptEnv) end
        local success, runErr = pcall(loaded)
        if not success then
            warn("[Elite Hub] Runtime Error: " .. tostring(runErr))
        end
    else
        warn("[Elite Hub] Syntax Error: " .. tostring(compileErr))
    end
end

local function verifyKey(key)
    if not key or key == "" then 
        return false, "Key cannot be empty" 
    end
    
    local cleanKey = string.gsub(key, "^%s*(.-)%s*$", "%1")
    local response = httpRequest({
        Url = WORKER_URL,
        Method = "GET",
        Headers = {
            ["X-Auth-Key"] = cleanKey
        }
    })

    if response.StatusCode == 200 and response.Body and response.Body ~= "" then
        if writefile then
            writefile(SAVE_FILE, cleanKey)
        end
        return true, response.Body
    elseif response.StatusCode == 403 then
        if delfile and isfile and isfile(SAVE_FILE) then
            delfile(SAVE_FILE)
        end
        return false, "Invalid or expired key"
    elseif response.StatusCode == 404 then
        return false, "Script is currently offline"
    else
        return false, "Gateway Error: " .. tostring(response.StatusCode)
    end
end

if isfile and isfile(SAVE_FILE) then
    local savedKey = readfile(SAVE_FILE)
    if savedKey and savedKey ~= "" then
        local ok, payload = verifyKey(savedKey)
        if ok then
            executeScript(payload)
            return
        end
    end
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Elite Hub | Key Verification",
    Icon = 0,
    LoadingTitle = "Elite Hub",
    LoadingSubtitle = "Authentication Service",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local Tab = Window:CreateTab("Authorization", 4483362458)

Tab:CreateSection("Access Verification")

Tab:CreateParagraph({
    Title = "How to get a key?",
    Content = "Keys are generated and distributed on our official Discord server.\nClick the button below to copy the server invite link."
})

local function safeNotify(t, c)
    pcall(function()
        Rayfield:Notify({ Title = t, Content = c, Duration = 4, Image = 4483362458 })
    end)
end

local enteredKey, submittedKey = "", nil

Tab:CreateInput({
    Name = "License Key",
    PlaceholderText = "Paste your key here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) enteredKey = text end,
})

Tab:CreateButton({
    Name = "Launch Script",
    Callback = function()
        if enteredKey == "" then
            safeNotify("Error", "Please enter a key before launching.")
            return
        end
        submittedKey = enteredKey
    end,
})

Tab:CreateButton({
    Name = "Copy Discord Server",
    Callback = function()
        local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)
        if clip then
            clip(DISCORD_INVITE)
            safeNotify("Clipboard", "Discord invite link copied successfully!")
        end
    end,
})

-- Verification + launch happen in the main loader thread, not inside a UI callback
local payload
while not payload do
    if submittedKey then
        local k = submittedKey
        submittedKey = nil
        safeNotify("Authorizing...", "Checking key integrity with gateway...")
        local okV, success, body = pcall(verifyKey, k)
        if okV and success then
            payload = body
        else
            safeNotify("Access Denied", tostring(okV and body or success))
        end
    end
    task.wait(0.2)
end

pcall(function() Rayfield:Destroy() end)
executeScript(payload)
