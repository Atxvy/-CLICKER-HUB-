--!strict
--==============================================================================
-- [CLICKER HUB] AutoProgLoader.lua
-- Single-line loader to launch Clicker Hub Auto Prog standalone speedrunner
--==============================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function checkExecutor()
    local name = ""
    if identifyexecutor then
        local ok, n = pcall(identifyexecutor)
        if ok and type(n) == "string" then name = n:lower() end
    elseif getexecutorname then
        local ok, n = pcall(getexecutorname)
        if ok and type(n) == "string" then name = n:lower() end
    end
    if name:find("xeno") or name:find("solara") then
        if LocalPlayer then
            LocalPlayer:Kick("Not supported executor. Please use a supported executor.")
        end
        return false
    end
    return true
end

if not checkExecutor() then return end

-- Check if current player should be ignored
local function shouldIgnoreCurrentPlayer(): boolean
    local lp = LocalPlayer or Players.LocalPlayer
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
    local lp = LocalPlayer or Players.LocalPlayer
    warn(string.format("[CLICKER HUB] Current player '%s' (%s) is in IgnorePlayer list. Execution halted.", lp and lp.Name or "Unknown", tostring(lp and lp.UserId or 0)))
    return
end

local GITHUB_REPO = "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main"

local function launch()
    -- 1. Try local workspace development version first
    if readfile and isfile and isfile("[CLICKER HUB]/AutoProg.lua") then
        local chunk = readfile("[CLICKER HUB]/AutoProg.lua")
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        else
            warn("[CLICKER HUB AUTO PROG] Local compile error:", err)
        end
    end

    -- 2. Fallback to GitHub remote loadstring with cache-buster
    local url = GITHUB_REPO .. "/AutoProg.lua?t=" .. tostring(os.time())
    local ok, chunk = pcall(game.HttpGet, game, url)
    if not ok or not chunk or #chunk == 0 then
        ok, chunk = pcall(game.HttpGet, game, GITHUB_REPO .. "/AutoProg.lua")
    end

    if ok and chunk and #chunk > 0 then
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        else
            warn("[CLICKER HUB AUTO PROG] Remote compile error:", err)
        end
    else
        warn("[CLICKER HUB AUTO PROG] Could not fetch AutoProg.lua from GitHub or local workspace!")
    end
end

launch()
