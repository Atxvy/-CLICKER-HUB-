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

    -- 2. Fallback to GitHub remote loadstring
    local url = GITHUB_REPO .. "/AutoProg.lua"
    local ok, chunk = pcall(game.HttpGet, game, url)
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
