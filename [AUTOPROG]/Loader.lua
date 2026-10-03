--!strict
--==============================================================================
-- [AUTOPROG] Loader.lua
-- Dedicated loader for Auto Progression engine
--==============================================================================

local LOCAL_PATH = "[AUTOPROG]/Main.lua"
local GITHUB_URL = "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main/%5BAUTOPROG%5D/Main.lua"

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
