--!strict
--==============================================================================
-- [AUTOPROG] Loader.lua
-- Dedicated loader for Auto Progression engine
--==============================================================================

local LOCAL_PATH = "[AUTOPROG]/Main.lua"
local GITHUB_URL = "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main/%5BAUTOPROG%5D/Main.lua"

-- Check if current player should be ignored
local function shouldIgnoreCurrentPlayer(): boolean
    local lp = game:GetService("Players").LocalPlayer
    if not lp then return false end

    local myName = string.lower(lp.Name)
    local myUserId = lp.UserId

    local candidates = {
        (getgenv and type(getgenv) == "function" and pcall(getgenv) and getgenv()) or nil,
        _G,
        shared,
        (getfenv and pcall(getfenv, 0) and getfenv(0)) or nil,
        (getfenv and pcall(getfenv, 1) and getfenv(1)) or nil,
    }
    local keys = {
        "IgnorePlayer", "IgnorePlayers", "ignorePlayer", "ignorePlayers",
        "ignoreplayer", "ignoreplayers", "IGNORE_PLAYER", "IGNORE_PLAYERS"
    }

    for _, env in ipairs(candidates) do
        if type(env) == "table" then
            for _, k in ipairs(keys) do
                local ok, val = pcall(function() return rawget(env, k) or env[k] end)
                if ok and val ~= nil then
                    if type(val) == "table" then
                        for _, entry in pairs(val) do
                            if type(entry) == "string" then
                                local clean = string.lower(entry:gsub("^%s+", ""):gsub("%s+$", ""))
                                if clean ~= "" and (clean == myName or tonumber(clean) == myUserId) then
                                    return true
                                end
                            elseif type(entry) == "number" then
                                if entry == myUserId then
                                    return true
                                end
                            end
                        end
                    elseif type(val) == "string" then
                        local clean = string.lower(val:gsub("^%s+", ""):gsub("%s+$", ""))
                        if clean ~= "" and (clean == myName or tonumber(clean) == myUserId) then
                            return true
                        end
                    elseif type(val) == "number" then
                        if val == myUserId then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

if shouldIgnoreCurrentPlayer() then
    local lp = game:GetService("Players").LocalPlayer
    warn(string.format("[CLICKER HUB] Current player '%s' (%s) is in IgnorePlayer list. Execution halted.", lp and lp.Name or "Unknown", tostring(lp and lp.UserId or 0)))
    return
end

if readfile and isfile and isfile(LOCAL_PATH) then
    local chunk = readfile(LOCAL_PATH)
    local fn, err = loadstring(chunk)
    if fn then
        return fn()
    else
        warn("[AutoProg Loader] Local compile error:", err)
    end
end

-- Fallback to remote GitHub
local url = GITHUB_URL .. "?t=" .. tostring(os.time())
local ok, chunk = pcall(game.HttpGet, game, url)
if not ok or not chunk or #chunk == 0 then
    ok, chunk = pcall(game.HttpGet, game, GITHUB_URL)
end

if ok and chunk and #chunk > 0 then
    local fn, err = loadstring(chunk)
    if fn then
        return fn()
    else
        error("[AutoProg Loader] Remote compile error: " .. tostring(err))
    end
end

error("[AutoProg Loader] Failed to load Main.lua from disk or GitHub.")
