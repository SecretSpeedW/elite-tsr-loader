-- language: Lua, file: loader.lua, target: Roblox (Real Executor / Potassium)
-- Elite Hub Secure Loader

local lp = game:GetService("Players").LocalPlayer
local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))

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

local function parseResponse(r1, r2)
	local resp = (type(r1) == "table" and r1) or (type(r2) == "table" and r2) or nil
	if resp then
		local body = resp.Body or resp.body or resp.Response or resp.response or resp.data or ""
		local rawCode = resp.StatusCode or resp.status_code or resp.code or resp.Code or resp.status or resp.Status
		local code = tonumber(rawCode)
		if not code and type(rawCode) == "string" then
			code = tonumber(rawCode:match("(%d%d%d)"))
		end
		if not code and resp.Success ~= nil then
			code = resp.Success and 200 or 403
		end
		return code or 200, tostring(body)
	end
	if type(r1) == "string" then return 200, r1 end
	if type(r2) == "string" then return 200, r2 end
	return nil, nil
end

local function verifyKey(key)
	if not key or key == "" then
		return false, "Key cannot be empty"
	end
	local cleanKey = string.gsub(key, "^%s*(.-)%s*$", "%1")
	for attempt = 1, 3 do
		local okHttp, r1, r2 = pcall(httpRequest, {
			Url = WORKER_URL,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
				["X-Auth-Key"] = cleanKey
			}
		})
		local code, body = parseResponse(r1, r2)
		if okHttp and code then
			if code == 200 and body and body ~= "" and not body:match("^%s*<%!DOCTYPE") then
				if writefile then pcall(writefile, SAVE_FILE, cleanKey) end
				return true, body
			elseif code == 200 then
				return false, "Unexpected server response (HTML gateway page?)"
			elseif code == 403 then
				if delfile and isfile and isfile(SAVE_FILE) then
					pcall(delfile, SAVE_FILE)
				end
				return false, "Invalid or expired key"
			elseif code == 404 then
				return false, "Script is currently offline"
			elseif code >= 500 and attempt < 3 then
				task.wait(1.5)
			else
				local errDetail = (body and body ~= "") and body or ("HTTP " .. tostring(code))
				return false, "Gateway Error: " .. tostring(errDetail)
			end
		elseif attempt < 3 then
			task.wait(1.5)
		else
			local failReason = not okHttp and tostring(r1) or "nil response"
			return false, "Connection failed (" .. failReason .. ")"
		end
	end
	return false, "Connection failed"
end

-- Проверка сохраненного ключа при старте
if isfile and isfile(SAVE_FILE) then
    local okr, savedKey = pcall(readfile, SAVE_FILE)
    if okr and savedKey and savedKey ~= "" then
        local ok, payload = verifyKey(savedKey)
        if ok and payload then
            executeScript(payload)
            return
        end
    end
end

-- Загрузка Rayfield UI
local Rayfield = nil
local okUI, uiErr = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if okUI and typeof(uiErr) == "table" then
    Rayfield = uiErr
else
    Rayfield = nil
    warn("[Elite Hub] UI library failed to load: " .. tostring(uiErr))
    print("[Elite Hub] Paste your key into '" .. SAVE_FILE .. "' via executor console (writefile) to auto-launch.")
end

local enteredKey = ""
local submittedKey = nil
local keyInputObj = nil

local function safeNotify(title, content)
    if Rayfield then
        pcall(function()
            Rayfield:Notify({ Title = title, Content = content, Duration = 4 })
        end)
    else
        print("[Elite Hub] " .. tostring(title) .. ": " .. tostring(content))
    end
end

local function cleanLoaderGui()
    if Rayfield then
        pcall(function() Rayfield:Destroy() end)
    end
    pcall(function()
        local function purge(parent)
            if not parent then return end
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == "Rayfield" or child.Name:match("^Rayfield") then
                    pcall(function() child:Destroy() end)
                end
            end
        end
        if gethui then purge(gethui()) end
        if pg then purge(pg) end
        pcall(function() purge(game:GetService("CoreGui")) end)
    end)
end

if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "Elite Hub | Key Verification",
        Icon = 0,
        LoadingTitle = "Elite Hub",
        LoadingSubtitle = "Authentication Service",
        Theme = "Default",
        DisableRayfieldPrompts = true,
        ConfigurationSaving = {
            Enabled = false
        },
        KeySystem = false
    })

    local Tab = Window:CreateTab("Authorization")

    Tab:CreateSection("Access Verification")

    Tab:CreateParagraph({
        Title = "How to get a key?",
        Content = "Keys are generated and distributed on our official Discord server.\nClick the button below to copy the server invite link."
    })

    keyInputObj = Tab:CreateInput({
        Name = "License Key",
        PlaceholderText = "Paste your key here...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            if type(text) == "string" and text ~= "" then
                enteredKey = text
            end
        end,
    })

    Tab:CreateButton({
        Name = "Launch Script",
        Callback = function()
            local keyToTest = enteredKey
            if (not keyToTest or keyToTest == "") and keyInputObj and keyInputObj.CurrentValue then
                keyToTest = keyInputObj.CurrentValue
            end
            if not keyToTest or keyToTest == "" then
                safeNotify("Error", "Please enter a key before launching.")
                return
            end
            submittedKey = keyToTest
        end,
    })

    Tab:CreateButton({
        Name = "Copy Discord Server",
        Callback = function()
            local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)
            if clip then
                clip(DISCORD_INVITE)
                safeNotify("Clipboard", "Discord invite copied!")
            end
        end,
    })
end

-- Главный цикл верификации
local lastFileCheck = 0
local payload = nil

while not payload do
    if submittedKey then
        local k = submittedKey
        submittedKey = nil
        safeNotify("Authorizing...", "Checking key...")
        local ok, res = verifyKey(k)
        if ok then
            payload = res
            safeNotify("Success", "Key accepted! Loading script...")
        else
            safeNotify("Access Denied", tostring(res))
        end
    end

    if not Rayfield and os.clock() - lastFileCheck > 3 and isfile and isfile(SAVE_FILE) then
        lastFileCheck = os.clock()
        local okr, savedKey = pcall(readfile, SAVE_FILE)
        if okr and savedKey and savedKey ~= "" then
            local ok, res = verifyKey(savedKey)
            if ok then
                payload = res
            else
                warn("[Elite Hub] " .. tostring(res))
            end
        end
    end

    task.wait(0.2)
end

-- Зачистка лоадера перед запуском основного скрипта
cleanLoaderGui()
task.wait(0.5)

print("[Elite Hub] Key accepted — launching script...")
task.spawn(function()
    executeScript(payload)
end)
