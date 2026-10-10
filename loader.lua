-- Elite Hub Secure Loader
local WORKER_URL = "https://elite-hub-gate.pavlo-melnik001.workers.dev"
local SAVE_FILE = "elite_tsr_key.txt"
local DISCORD_INVITE = "https://discord.gg/sy79UrhJj8"

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
    DisableBuildWarnings = true,
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

local enteredKey = ""

Tab:CreateInput({
    Name = "License Key",
    PlaceholderText = "Paste your key here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        enteredKey = text
    end,
})

Tab:CreateButton({
    Name = "Verify & Launch",
    Callback = function()
        Rayfield:Notify({
            Title = "Elite Hub",
            Content = "Checking key validity...",
            Duration = 2,
            Image = 4483362458
        })

        task.spawn(function()
            local success, payload = verifyKey(enteredKey)
            if success then
                Rayfield:Notify({
                    Title = "Access Granted",
                    Content = "Starting Elite Hub...",
                    Duration = 2.5,
                    Image = 4483362458
                })
                task.wait(1)
                Rayfield:Destroy()
                executeScript(payload)
            else
                Rayfield:Notify({
                    Title = "Access Denied",
                    Content = tostring(payload),
                    Duration = 4,
                    Image = 4483362458
                })
            end
        end)
    end,
})

Tab:CreateButton({
    Name = "Copy Discord Server",
    Callback = function()
        local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)
        if clip then
            clip(DISCORD_INVITE)
            Rayfield:Notify({
                Title = "Clipboard",
                Content = "Discord invite link copied successfully!",
                Duration = 2.5,
                Image = 4483362458
            })
        else
            Rayfield:Notify({
                Title = "Clipboard Error",
                Content = "Failed to copy automatically: " .. DISCORD_INVITE,
                Duration = 5,
                Image = 4483362458
            })
        end
    end,
})
