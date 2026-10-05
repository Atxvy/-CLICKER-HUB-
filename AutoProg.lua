--!strict
--==============================================================================
-- [CLICKER HUB AUTO PROG] AutoProg.lua
-- Dedicated Full Zero-to-Hero Auto Progression Speedrun Engine for Clicker Simulator!
--
-- WORKFLOW:
-- • PHASE 1 (Early to Mid Game - Unlock All Islands Speedrun):
--   - Non-stop high-speed Auto Clicks
--   - Smart Auto Rebirth (Max Rebirth when affordable, leashes when near next island)
--   - Auto Buy Map Upgrades (+1 extra pet slot, storage, speed)
--   - Auto Buy Gem Upgrades (Rebirth shop, buttons, double jumps)
--   - Auto Open Best Affordable Eggs (with smart inventory cleaning of old weak pets)
--   - Auto Equip Best Pets
--   - Auto Unlock & Teleport to Next Island as soon as affordable
--
-- • PHASE 2 (Endgame - Triggered ONLY after all 16 islands are unlocked):
--   - Max out Desert Machine & Gem Upgrades
--   - Dynamic Skill Tree (Tech World first, then Overworld Coins)
--   - Auto ??? Secret Questline Solver (feathers, hatches, Dominus door)
--   - Auto Rainbow Machine crafting and claiming
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Check unsupported executors (Xeno / Solara)
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
        (getgenv and type(getgenv) == "function" and getgenv()) or nil,
        _G,
        shared,
    }
    local keys = {
        "IgnorePlayer", "IgnorePlayers", "ignorePlayer", "ignorePlayers",
        "ignoreplayer", "ignoreplayers", "IGNORE_PLAYER", "IGNORE_PLAYERS"
    }

    for _, env in ipairs(candidates) do
        if type(env) == "table" then
            for _, k in ipairs(keys) do
                local val = rawget(env, k) or env[k]
                if val ~= nil then
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

--==============================================================================
-- LOAD MODULES (Hybrid Local + GitHub Remote Fallback)
--==============================================================================
local GITHUB_REPO = "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main"

local function loadModule(name: string)
    -- 1. Check local workspace first (for dev / testing)
    local localPath = "[CLICKER HUB]/" .. name
    if readfile and isfile and isfile(localPath) then
        local chunk = readfile(localPath)
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        else
            warn("[Auto Prog] Local compile error in " .. name .. ":", err)
        end
    end

    -- 2. Fallback to GitHub raw (with cache-buster)
    local url = GITHUB_REPO .. "/" .. name .. "?t=" .. tostring(os.time())
    local ok, chunk = pcall(game.HttpGet, game, url)
    if not ok or not chunk or #chunk == 0 then
        ok, chunk = pcall(game.HttpGet, game, GITHUB_REPO .. "/" .. name)
    end
    if ok and chunk and #chunk > 0 then
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        else
            error("[Auto Prog] Remote compile error in " .. name .. ": " .. tostring(err))
        end
    end

    error("[Auto Prog] File not found in workspace or GitHub: " .. name)
end

local UILibrary = loadModule("UILibrary.lua")
local GameAPI = loadModule("GameAPI.lua")
local Configs = loadModule("Configs.lua")

-- Suppress game black shade permanently
pcall(GameAPI.SuppressBlackShade)

-- Clean up any prior running AutoProg instance
if _G.ClickerHubAutoProgCleanup then
    pcall(_G.ClickerHubAutoProgCleanup)
end

local isRunning = true
local threads = {}

_G.ClickerHubAutoProgCleanup = function()
    isRunning = false
    for _, t in ipairs(threads) do
        pcall(task.cancel, t)
    end
    if GameAPI and GameAPI.StopBreakables then
        pcall(GameAPI.StopBreakables)
    end
end

--==============================================================================
-- AUTO PROG STATE
--==============================================================================
local State = {
    -- Master Engine
    MasterEnabled = true,

    -- Pets Helper & Golden Engine
    AutoGold = true,              -- Keep opening best egg until entire equipped team is Golden
    AutoCraftGolden = true,       -- Golden machine 100% chance priority
    ProtectCraftingPets = true,   -- Do not delete pets needed for golden crafting
    AutoBestEggs = true,          -- Open highest affordable egg
    AutoCleanPets = true,         -- Delete inferior weak pets
    KeepTopPets = 15,             -- Keep top 15 strongest pets
    AutoEquipBest = true,

    -- Phase 1 Settings (Early-to-Mid Game Speedrun)
    AutoClick = true,
    AutoMaxRebirth = true,
    AutoUnlockIslands = true,
    AutoMapUpgrades = true,       -- +1 pet slot, storage, speed
    AutoGemUpgrades = true,       -- Rebirth gem upgrades
    AutoRebirthButtons = true,    -- Rebirth shop milestone buttons with gems
    AutoFreeGifts = true,         -- Auto collect 12 free gifts, daily, chests
    AutoPotions = true,           -- Auto use best potions (clicks, speed, luck, gems)

    -- Phase 2 Settings (Endgame - Activates once all islands unlocked)
    AutoDesertMachine = true,     -- 1st: Desert Gem Upgrade machine
    AutoSkillTree = true,         -- 2nd: Tech World then Coins
    AutoSecretQuest = true,       -- 3rd: ??? Dominus secret quest
    AutoMagmaSkin = true,         -- 4th: 10 Qi Rebirth & Magma Click Skin (+4 Hatch, +20% Speed)
    AutoRainbowClaim = true,      -- Auto claim rainbow pets

    -- Misc
    AntiAFK = true,
    WalkSpeed = 16,
    JumpPower = 50,
}

--==============================================================================
-- CREATE UI WINDOW
--==============================================================================
local Window = UILibrary.CreateWindow({
    Title = "CLICKER HUB AUTO PROG",
    SubTitle = "Zero-to-Hero Speedrun Engine",
    ToggleKey = Enum.KeyCode.RightControl,
    Size = UDim2.new(0, 620, 0, 440)
})

if Window and Window.ScreenGui then
    Window.ScreenGui.Destroying:Connect(function()
        if _G.ClickerHubAutoProgCleanup then
            pcall(_G.ClickerHubAutoProgCleanup)
        end
    end)
end

--==============================================================================
-- 1. DASHBOARD & TELEMETRY TAB
--==============================================================================
local DashTab = Window:AddTab({ Title = "Dashboard", Icon = "🚀" })

DashTab:AddSection("ENGINE STATUS")
local MasterToggle = DashTab:AddToggle("MasterProgToggle", {
    Title = "⚡ Master Auto Progression Engine",
    Description = "Fully automates the entire game from zero to endgame!",
    Default = State.MasterEnabled,
    Callback = function(val)
        State.MasterEnabled = val
        if val then
            Window:Notify({ Title = "Auto Prog", Content = "Speedrun engine started!", Duration = 2.5 })
        else
            Window:Notify({ Title = "Auto Prog", Content = "Speedrun engine paused.", Duration = 2 })
        end
    end
})

local LiveStatusCard = DashTab:AddParagraph({
    Title = "Speedrun Telemetry",
    Content = "Evaluating account status..."
})

DashTab:AddSection("QUICK COMMANDS")
DashTab:AddButton({
    Title = "Equip Best Pets",
    Description = "Instantly equips your highest multiplier pets",
    Callback = function()
        GameAPI.EquipBest()
        Window:Notify({ Title = "Pets", Content = "Best pets equipped!", Duration = 2 })
    end
})

DashTab:AddButton({
    Title = "Max Rebirth Now",
    Description = "Triggers highest affordable rebirth milestone",
    Callback = function()
        local info = GameAPI.GetMaxRebirthInfo()
        if info.CanAffordMax then
            GameAPI.RebirthMaxTarget()
            Window:Notify({ Title = "Rebirth", Content = "Max Rebirth executed! (+" .. GameAPI.FormatNumber(info.MaxAmount) .. ")", Duration = 2.5 })
        else
            Window:Notify({ Title = "Rebirth", Content = "Cannot afford Max Rebirth yet.", Duration = 2 })
        end
    end
})

DashTab:AddButton({
    Title = "Unlock Next Island Now",
    Description = "Purchases next locked island and teleports there immediately",
    Callback = function()
        local ok, msg = GameAPI.UnlockAndTeleportToNextIsland()
        Window:Notify({ Title = "Island Progression", Content = tostring(msg), Duration = 3 })
    end
})

DashTab:AddButton({
    Title = "Clean Pet Inventory Now",
    Description = "Deletes weak/inferior pets while preserving your top 15 pets and equipped ones",
    Callback = function()
        local count = GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
        Window:Notify({ Title = "Inventory Cleaner", Content = string.format("Cleaned %d weak pets!", count), Duration = 2.5 })
    end
})

--==============================================================================
-- 2. PETS HELPER TAB (GOLDEN CRAFTING & INVENTORY MANAGEMENT)
--==============================================================================
local PetsHelperTab = Window:AddTab({ Title = "Pets Helper", Icon = "🐾" })

PetsHelperTab:AddSection("GOLDEN TEAM AUTOMATION")
PetsHelperTab:AddToggle("AutoGoldToggle", {
    Title = "Auto Gold (Full Golden Team)",
    Description = "Keeps opening best affordable eggs and crafts them in Golden Machine with 100% chance priority until your entire equipped team is Golden!",
    Default = State.AutoGold,
    Callback = function(val)
        State.AutoGold = val
        if val then
            Window:Notify({ Title = "Auto Gold", Content = "Auto Gold enabled: Opening best eggs until all equipped are Golden!", Duration = 3 })
        end
    end
})

PetsHelperTab:AddToggle("AutoCraftGoldenToggle", {
    Title = "Auto Craft Golden (100% Priority)",
    Description = "Automatically converts batches of normal pets into Golden pets with guaranteed 100% success rate (batches of 6, or 5 with perk).",
    Default = State.AutoCraftGolden,
    Callback = function(val) State.AutoCraftGolden = val end
})

PetsHelperTab:AddToggle("ProtectCraftingPetsToggle", {
    Title = "Protect Crafting Candidates (Do Not Delete)",
    Description = "Prevents duplicate normal pets from being deleted so they can reach the 6-pet Golden crafting threshold.",
    Default = State.ProtectCraftingPets,
    Callback = function(val) State.ProtectCraftingPets = val end
})

PetsHelperTab:AddToggle("AutoEquipBestToggle_Pets", {
    Title = "Auto Equip Best Pets",
    Description = "Automatically keeps your highest multiplier pets equipped continuously",
    Default = State.AutoEquipBest,
    Callback = function(val) State.AutoEquipBest = val end
})

PetsHelperTab:AddSection("INVENTORY CLEANER (SMART TRASH REMOVAL)")
PetsHelperTab:AddToggle("AutoCleanPetsToggle_Pets", {
    Title = "Auto Clean Weak Pets",
    Description = "Automatically deletes obsolete weak pets while safely keeping all Golden, Rainbow, Special, and crafting candidate pets",
    Default = State.AutoCleanPets,
    Callback = function(val) State.AutoCleanPets = val end
})

PetsHelperTab:AddSlider("KeepTopPetsSlider", {
    Title = "Keep Top Pets Amount",
    Description = "Number of strongest pets to preserve during cleaning",
    Min = 5,
    Max = 50,
    Rounding = 1,
    Default = State.KeepTopPets,
    Callback = function(val) State.KeepTopPets = val end
})

PetsHelperTab:AddSection("INSTANT ACTIONS")
PetsHelperTab:AddButton({
    Title = "Craft Golden Pets Now (100% Guaranteed)",
    Description = "Immediately runs Golden crafting on all eligible candidate batches",
    Callback = function()
        local crafted = GameAPI.CraftGoldenPets()
        GameAPI.EquipBest()
        Window:Notify({
            Title = "Golden Machine",
            Content = crafted > 0 and string.format("Crafted %d Golden Pet(s) with 100%% Chance!", crafted) or "No batches ready for 100% Golden crafting yet.",
            Duration = 2.5
        })
    end
})

PetsHelperTab:AddButton({
    Title = "Equip Best Pets Now",
    Description = "Instantly equips highest multiplier pets from inventory",
    Callback = function()
        GameAPI.EquipBest()
        Window:Notify({ Title = "Pets", Content = "Best pets equipped!", Duration = 2 })
    end
})

PetsHelperTab:AddButton({
    Title = "Clean Inventory Now",
    Description = "Cleans obsolete pets while keeping top pets and crafting candidates safe",
    Callback = function()
        local cleaned = GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
        Window:Notify({ Title = "Pet Cleaner", Content = string.format("Cleaned %d obsolete pets!", cleaned), Duration = 2.5 })
    end
})

--==============================================================================
-- 3. PHASE 1: ISLAND SPEEDRUN TAB
--==============================================================================
local Phase1Tab = Window:AddTab({ Title = "Phase 1: Islands", Icon = "🏝️" })

Phase1Tab:AddSection("GOAL: UNLOCK ALL 16 ISLANDS")
local Phase1Desc = Phase1Tab:AddParagraph({
    Title = "Phase 1 Strategy",
    Content = "Focuses 100% on power scaling: rapid clicking, Max Rebirths, pet upgrades, best eggs, and unlocking each island as soon as affordable."
})

Phase1Tab:AddSection("AUTOMATION CONTROLS")
Phase1Tab:AddToggle("AutoClickProgToggle", {
    Title = "Auto Click",
    Description = "High-speed frame tick clicking",
    Default = State.AutoClick,
    Callback = function(val) State.AutoClick = val end
})

Phase1Tab:AddToggle("AutoMaxRebirthToggle", {
    Title = "Smart Max Rebirth",
    Description = "Rebirths at max affordable milestone. Automatically pauses rebirth if close to island unlock cost.",
    Default = State.AutoMaxRebirth,
    Callback = function(val) State.AutoMaxRebirth = val end
})

Phase1Tab:AddToggle("AutoUnlockIslandsToggle", {
    Title = "Auto Unlock & Advance Islands",
    Description = "Instantly buys next island and warps there when Clicks requirement is met",
    Default = State.AutoUnlockIslands,
    Callback = function(val) State.AutoUnlockIslands = val end
})

Phase1Tab:AddToggle("AutoMapUpgradesToggle", {
    Title = "Auto Buy Map Upgrades (+1 Pet Slot)",
    Description = "Buys island mini upgrades: +1 pet equip slot, storage, and walkspeed pads",
    Default = State.AutoMapUpgrades,
    Callback = function(val) State.AutoMapUpgrades = val end
})

Phase1Tab:AddToggle("AutoGemUpgradesToggle", {
    Title = "Auto Gem Upgrades & Rebirth Buttons",
    Description = "Spends rebirth gems on Click upgrades, Combo, Hatch speed, and Rebirth milestone buttons",
    Default = State.AutoGemUpgrades,
    Callback = function(val) State.AutoGemUpgrades = val end
})

Phase1Tab:AddToggle("AutoBestEggsToggle", {
    Title = "Auto Open Best Affordable Eggs",
    Description = "Continuously hatches the highest affordable egg across your unlocked worlds",
    Default = State.AutoBestEggs,
    Callback = function(val) State.AutoBestEggs = val end
})

Phase1Tab:AddToggle("AutoGoldToggle_Phase1", {
    Title = "Auto Gold (Prio 100% Golden Team)",
    Description = "Keeps opening best eggs & crafts in Golden Machine with 100% chance priority until all equipped slots are Golden!",
    Default = State.AutoGold,
    Callback = function(val) State.AutoGold = val end
})

Phase1Tab:AddToggle("AutoCleanPetsToggle", {
    Title = "Auto Clean Weak Pets (Prevent Full Inventory)",
    Description = "Automatically deletes common weak pets so your inventory never hits maximum capacity",
    Default = State.AutoCleanPets,
    Callback = function(val) State.AutoCleanPets = val end
})

Phase1Tab:AddToggle("AutoEquipBestToggle", {
    Title = "Auto Equip Best Pets",
    Description = "Automatically keeps your highest multiplier pets equipped at all times",
    Default = State.AutoEquipBest,
    Callback = function(val) State.AutoEquipBest = val end
})

Phase1Tab:AddToggle("AutoFreeGiftsProgToggle", {
    Title = "Auto Collect Free Gifts & Chests",
    Description = "Automatically claims all 12 free gifts, daily rewards, achievements, and chests",
    Default = State.AutoFreeGifts,
    Callback = function(val) State.AutoFreeGifts = val end
})

Phase1Tab:AddToggle("AutoPotionsProgToggle", {
    Title = "Auto Use Potions & Fruits",
    Description = "Automatically consumes your best owned Clicks, Speed, Luck, and Gems potions",
    Default = State.AutoPotions,
    Callback = function(val) State.AutoPotions = val end
})

Phase1Tab:AddToggle("AutoMagmaSkinProgToggle_Phase1", {
    Title = "Check % & Equip Magma Skin",
    Description = "Tracks 10 Qi Rebirth goal and equips Magma Click Skin (+4 Egg Hatch Passive, 20% Hatch Speed)",
    Default = State.AutoMagmaSkin,
    Callback = function(val) State.AutoMagmaSkin = val end
})

--==============================================================================
-- 3. PHASE 2: ENDGAME AUTOMATION TAB
--==============================================================================
local Phase2Tab = Window:AddTab({ Title = "Phase 2: Endgame", Icon = "👑" })

Phase2Tab:AddSection("ENDGAME ROADMAP (AUTOMATICALLY RUNS WHEN ALL MAPS UNLOCKED)")
local Phase2Desc = Phase2Tab:AddParagraph({
    Title = "Endgame Progression Order",
    Content = "1st: Desert Gem Machine & Rebirth Shop Maxing\n" ..
              "2nd: Dynamic Skill Tree Farming (Tech World First ➔ Coins Tree)\n" ..
              "3rd: Auto ??? Secret Dominus Quest (Feathers ➔ 2.5k Hatches ➔ Door)\n" ..
              "4th: 10 Qi Rebirth Goal & Magma Click Skin (+4 Egg Hatch, +20% Speed)"
})

Phase2Tab:AddSection("ENDGAME TOGGLES (DEFAULT: ALL ON)")
Phase2Tab:AddToggle("AutoDesertMachineToggle", {
    Title = "1st: Desert Machine & Gem Upgrades",
    Description = "Maxes out Desert island gem machine upgrades and rebirth shop perks",
    Default = State.AutoDesertMachine,
    Callback = function(val) State.AutoDesertMachine = val end
})

Phase2Tab:AddToggle("AutoSkillTreeProgToggle", {
    Title = "2nd: Auto Skill Tree (Tech World -> Coins)",
    Description = "Farms breakables and purchases Tech World perks first, then completes Overworld Coins tree",
    Default = State.AutoSkillTree,
    Callback = function(val) State.AutoSkillTree = val end
})

Phase2Tab:AddToggle("AutoSecretQuestProgToggle", {
    Title = "3rd: Auto ??? Secret Dominus Quest",
    Description = "Automatically grabs 10 hidden feathers, hatches 2,500 basic eggs, and claims the Dominus door",
    Default = State.AutoSecretQuest,
    Callback = function(val) State.AutoSecretQuest = val end
})

Phase2Tab:AddToggle("AutoMagmaSkinProgToggle", {
    Title = "4th: 10 Qi Rebirth & Magma Click Skin",
    Description = "Tracks 10 Qi rebirth goal and equips Magma Click Skin (+4 Egg Hatch Passive & 20% Hatch Speed)",
    Default = State.AutoMagmaSkin,
    Callback = function(val) State.AutoMagmaSkin = val end
})

Phase2Tab:AddToggle("AutoRainbowClaimProgToggle", {
    Title = "Auto Claim Rainbow Machine",
    Description = "Collects finished Rainbow pets from the machine immediately upon completion",
    Default = State.AutoRainbowClaim,
    Callback = function(val) State.AutoRainbowClaim = val end
})

--==============================================================================
-- 4. UTILITY & MISC TAB
--==============================================================================
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "⚙️" })

MiscTab:AddSection("CHARACTER")
MiscTab:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Description = "Customize character movement speed",
    Min = 16,
    Max = 150,
    Rounding = 1,
    Default = State.WalkSpeed,
    Callback = function(val)
        State.WalkSpeed = val
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end
})

MiscTab:AddSlider("JumpPowerSlider", {
    Title = "JumpPower",
    Description = "Customize jump height",
    Min = 50,
    Max = 200,
    Rounding = 1,
    Default = State.JumpPower,
    Callback = function(val)
        State.JumpPower = val
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = val end
    end
})

MiscTab:AddToggle("AntiAFKToggle", {
    Title = "Anti-AFK Protection",
    Description = "Prevents Roblox 20-minute idle disconnection",
    Default = State.AntiAFK,
    Callback = function(val) State.AntiAFK = val end
})

MiscTab:AddSection("INSTANT REWARDS")
MiscTab:AddButton({
    Title = "Redeem All Active Codes",
    Description = "Redeems all active game codes for free clicks, gems, and boosts",
    Callback = function()
        local count, codes = GameAPI.RedeemAllCodes()
        Window:Notify({
            Title = "Codes",
            Content = count > 0 and string.format("Redeemed %d code(s)!", count) or "No unredeemed codes available.",
            Duration = 3
        })
    end
})

MiscTab:AddButton({
    Title = "Claim All Gifts, Chests & Daily",
    Description = "Collects all free gifts, daily rewards, achievements, and chests",
    Callback = function()
        GameAPI.ClaimAllFreeGifts()
        GameAPI.ClaimAllAchievements()
        GameAPI.ClaimAllChests()
        GameAPI.ClaimDaily()
        GameAPI.RollWheel()
        Window:Notify({ Title = "Rewards", Content = "All claimable rewards triggered!", Duration = 2.5 })
    end
})

-- Anti-AFK Connection
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

-- Character speed loop
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(1)
        if isRunning then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if State.WalkSpeed > 16 and hum.WalkSpeed ~= State.WalkSpeed then
                    hum.WalkSpeed = State.WalkSpeed
                end
                if State.JumpPower > 50 and hum.JumpPower ~= State.JumpPower then
                    hum.JumpPower = State.JumpPower
                end
            end
        end
    end
end))

-- Redeem codes on startup for fresh accounts
task.spawn(function()
    task.wait(2)
    pcall(GameAPI.RedeemAllCodes)
    pcall(GameAPI.ClaimAllFreeGifts)
    pcall(GameAPI.ClaimDaily)
end)

--==============================================================================
-- SPEEDRUN CORE ENGINE LOOPS
--==============================================================================

local currentActivity = "Initializing Speedrun Engine..."
local currentPhaseText = "Evaluating..."

-- 1. HIGH-SPEED CLICK LOOP (Dedicated Coroutine for Maximum CPS)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.MasterEnabled and State.AutoClick then
            GameAPI.Click()
            task.wait(0.001)
        else
            task.wait(0.2)
        end
    end
end))

-- 2. MASTER PROGRESSION PIPELINE LOOP
table.insert(threads, task.spawn(function()
    local lastEggHatch = 0
    local lastPetClean = 0
    local lastEquipBest = 0
    local lastUpgradesCheck = 0
    local lastRainbowClaim = 0
    local lastQuestStep = 0
    local lastBreakableTick = 0
    local lastGiftCheck = 0
    local lastPotionCheck = 0
    local lastSkinCheck = 0
    local lastCraftGolden = 0

    while isRunning do
        task.wait(0.1)
        if not State.MasterEnabled or not isRunning then
            continue
        end

        local now = tick()
        local pData = GameAPI.GetPlayerData()
        local lockedIsland = GameAPI.GetNextLockedIsland()
        local allIslandsUnlocked = (lockedIsland == nil)

        -- Global Auto Free Gifts & Chests (Runs continuously across all phases)
        if State.AutoFreeGifts and (now - lastGiftCheck > 12) then
            lastGiftCheck = now
            pcall(function()
                GameAPI.ClaimAllFreeGifts()
                GameAPI.ClaimAllChests()
                GameAPI.ClaimDaily()
                GameAPI.ClaimAllAchievements()
            end)
        end

        -- Global Auto Use Potions & Fruits (Runs continuously across all phases)
        if State.AutoPotions and (now - lastPotionCheck > 25) then
            lastPotionCheck = now
            pcall(function()
                GameAPI.UseAllBestPotions()
                GameAPI.UseAllFruits()
            end)
        end

        -- =====================================================================
        -- PHASE 1: ISLAND SPEEDRUN (Locked islands remaining)
        -- =====================================================================
        if not allIslandsUnlocked then
            currentPhaseText = "🌟 PHASE 1: ISLAND SPEEDRUN"

            -- A. Check Island Unlock Condition
            if State.AutoUnlockIslands and lockedIsland then
                if pData.Clicks >= lockedIsland.cost then
                    currentActivity = "🌟 Unlocking next island: " .. lockedIsland.name .. "!"
                    local count, lastIsland = GameAPI.UnlockAllAffordableIslands()
                    if count > 0 and lastIsland then
                        Window:Notify({ Title = "Islands Unlocked!", Content = string.format("🚀 Unlocked %d Island(s)! Reached %s!", count, lastIsland), Duration = 3 })
                        pcall(GameAPI.EquipBest)
                        task.wait(0.3)
                        pData = GameAPI.GetPlayerData()
                        lockedIsland = GameAPI.GetNextLockedIsland()
                        allIslandsUnlocked = (lockedIsland == nil)
                    end
                end
            end

            -- B. Smart Max Rebirth
            -- If we are NOT within 85% of next island cost, rebirth aggressively to multiply clicks!
            if State.AutoMaxRebirth and lockedIsland then
                local isNearIsland = (pData.Clicks >= lockedIsland.cost * 0.85)
                if not isNearIsland then
                    local maxInfo = GameAPI.GetMaxRebirthInfo()
                    if maxInfo.CanAffordMax then
                        currentActivity = string.format("Rebirthing Max Button #%d (+%s)", maxInfo.MaxButtonIndex, GameAPI.FormatNumber(maxInfo.MaxAmount))
                        GameAPI.RebirthMaxTarget()
                    end
                else
                    currentActivity = string.format("Saving Clicks for %s (%s / %s)", lockedIsland.name, GameAPI.FormatNumber(pData.Clicks), GameAPI.FormatNumber(lockedIsland.cost))
                end
            end

            -- C. Map Mini Upgrades (+1 Pet Slot, Storage, Walkspeed)
            if State.AutoMapUpgrades and (now - lastUpgradesCheck > 2) then
                lastUpgradesCheck = now
                local boughtMini = GameAPI.BuyAffordableMiniUpgrades()
                if boughtMini > 0 then
                    currentActivity = string.format("Purchased %d Map Mini-Upgrade(s)!", boughtMini)
                end
            end

            -- D. Gem Upgrades & Rebirth Buttons
            if State.AutoGemUpgrades and (now - lastUpgradesCheck > 1.5) then
                GameAPI.BuyAffordableGemUpgrades()
                if State.AutoRebirthButtons then
                    GameAPI.BuyNextRebirthButton()
                    GameAPI.BuyNextDoubleJump()
                end
            end

            -- E. Inventory Cleaning (Keep top 15 pets, protect Golden crafting candidates)
            if State.AutoCleanPets and (now - lastPetClean > 3) then
                lastPetClean = now
                local cleaned = GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
                if cleaned > 0 then
                    currentActivity = string.format("Cleaned %d weak pets from inventory", cleaned)
                end
            end

            -- F. Auto Open Best Affordable Egg & Auto Gold (Full Golden Team)
            if (State.AutoBestEggs or State.AutoGold) and (now - lastEggHatch > 0.35) then
                lastEggHatch = now
                local isAllGold = GameAPI.IsEquippedTeamAllGold()
                local isSufficient, petReason, targetEgg = GameAPI.ArePetsSufficientForIsland()
                local isNearIslandUnlock = lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.70)

                -- 1. Auto Gold Priority: Keep hatching best affordable egg until all equipped slots are Golden!
                if State.AutoGold and not isAllGold then
                    local bestEgg = GameAPI.GetBestAffordableEgg()
                    if bestEgg and pData.Clicks >= bestEgg.cost then
                        currentActivity = string.format("[Auto Gold] Hatching %s (Crafting 100%% Golden Team)", bestEgg.name)
                        GameAPI.OpenEgg(bestEgg.name, 1)
                    end
                elseif isNearIslandUnlock then
                    -- Within 70% of next island unlock cost: Save clicks instead of spending on eggs!
                    currentActivity = string.format("Saving clicks for %s (%s / %s)", lockedIsland.name, GameAPI.FormatNumber(pData.Clicks), GameAPI.FormatNumber(lockedIsland.cost))
                elseif isSufficient and (not State.AutoGold or isAllGold) then
                    -- Equipped pets are already good enough for this island: Stop hatching and farm clicks!
                    currentActivity = string.format("Pets maxed for %s! Farming clicks for %s", pData.CurrentIsland, lockedIsland and lockedIsland.name or "endgame")
                else
                    -- Need better pets for current island: Hatch best affordable egg!
                    local bestEgg = GameAPI.GetBestAffordableEgg()
                    if bestEgg and pData.Clicks >= bestEgg.cost then
                        currentActivity = "Hatching " .. bestEgg.name .. " (" .. petReason .. ")"
                        GameAPI.OpenEgg(bestEgg.name, 1)
                    end
                end
            end

            -- G. Auto Golden Machine Crafting (100% Guaranteed Chance Priority)
            if State.AutoCraftGolden and (now - lastCraftGolden > 1.5) then
                lastCraftGolden = now
                local crafted = GameAPI.CraftGoldenPets()
                if crafted > 0 then
                    currentActivity = string.format("[Auto Gold] Crafted %d Golden Pet(s) with 100%% Chance!", crafted)
                    pcall(GameAPI.EquipBest)
                end
            end

            -- H. Auto Equip Best Pets
            if State.AutoEquipBest and (now - lastEquipBest > 4) then
                lastEquipBest = now
                GameAPI.EquipBest()
            end

        -- =====================================================================
        -- PHASE 2: ENDGAME ROADMAP (All 16 islands unlocked!)
        -- =====================================================================
        else
            currentPhaseText = "👑 PHASE 2: ENDGAME ROADMAP"

            -- A. Max Rebirth
            if State.AutoMaxRebirth then
                local maxInfo = GameAPI.GetMaxRebirthInfo()
                if maxInfo.CanAffordMax then
                    currentActivity = string.format("[Endgame] Max Rebirth (+%s)", GameAPI.FormatNumber(maxInfo.MaxAmount))
                    GameAPI.RebirthMaxTarget()
                end
            end

            -- A2. Keep hatching if team is not 100% full gold
            local isAllGold = GameAPI.IsEquippedTeamAllGold()
            if not isAllGold and (now - lastEggHatch > 0.35) then
                lastEggHatch = now
                local bestEgg = GameAPI.GetBestAffordableEgg()
                if bestEgg and pData.Clicks >= bestEgg.cost then
                    currentActivity = "[Auto Gold] Hatching " .. bestEgg.name .. " for Full Gold Team"
                    GameAPI.OpenEgg(bestEgg.name, 1)
                    pcall(GameAPI.CraftGoldenPets)
                    pcall(GameAPI.EquipBest)
                end
            end

            -- B. 1st: Desert Gem Upgrade Machine & Rebirth Shop Maxing
            if State.AutoDesertMachine and (now - lastUpgradesCheck > 2) then
                lastUpgradesCheck = now
                GameAPI.BuyAffordableGemUpgrades()
                GameAPI.BuyAffordableMiniUpgrades()
                GameAPI.BuyNextRebirthButton()
                GameAPI.BuyNextDoubleJump()
            end

            -- C. 2nd: Dynamic Skill Tree Farming (Tech World First -> Coins Tree)
            if State.AutoSkillTree then
                -- Farm breakables in target world
                local bestWorld = GameAPI.GetBestBreakableIsland("Auto (Dynamic Smart)")
                if bestWorld then
                    if (now - lastBreakableTick > 0.05) then
                        lastBreakableTick = now
                        local okAtk, targetName = GameAPI.AttackBreakable(true)
                        if okAtk then
                            currentActivity = "[Skill Tree] Farming Breakables in " .. bestWorld
                        end
                    end
                end
                -- Buy affordable perks
                pcall(GameAPI.BuyAffordableSkillTree)
            end

            -- D. 3rd: Auto ??? Secret Dominus Quest (Feathers -> 2.5k Hatches -> Door)
            if State.AutoSecretQuest and (now - lastQuestStep > 0.5) then
                lastQuestStep = now
                local okQuest, qMsg = GameAPI.StepSecretQuest()
                if okQuest then
                    currentActivity = "[??? Quest] " .. tostring(qMsg)
                end
            end

            -- E. 4th: 10 Qi Rebirth Goal & Auto-Equip Magma Click Skin (+4 Egg Hatch, +20% Speed)
            if State.AutoMagmaSkin and (now - lastSkinCheck > 3) then
                lastSkinCheck = now
                local okSkin, skinMsg = GameAPI.CheckAndEquipMagmaSkin()
                if okSkin and skinMsg and skinMsg ~= "Already equipped" and skinMsg ~= "Holding" then
                    currentActivity = "[Magma Skin] " .. tostring(skinMsg)
                end
            end

            -- F. Auto Claim Rainbow Pets
            if State.AutoRainbowClaim and (now - lastRainbowClaim > 5) then
                lastRainbowClaim = now
                local claimed = GameAPI.ClaimRainbowPets()
                if claimed > 0 then
                    currentActivity = string.format("Claimed %d finished Rainbow Pet(s)!", claimed)
                end
            end

            -- G. Auto Golden Crafting (100% Chance Priority)
            if State.AutoCraftGolden and (now - lastCraftGolden > 2) then
                lastCraftGolden = now
                local crafted = GameAPI.CraftGoldenPets()
                if crafted > 0 then
                    pcall(GameAPI.EquipBest)
                end
            end

            -- H. Clean & Equip Best Pets
            if State.AutoCleanPets and (now - lastPetClean > 4) then
                lastPetClean = now
                GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
            end
            if State.AutoEquipBest and (now - lastEquipBest > 5) then
                lastEquipBest = now
                GameAPI.EquipBest()
            end
        end
    end
end))

-- 3. TELEMETRY DISPLAY REFRESH LOOP
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(0.5)
        if not isRunning then break end

        pcall(function()
            local pData = GameAPI.GetPlayerData()
            local stats = (Stats and Stats.Local and Stats.Local(true)) or {}
            local unlockedIslands = (pData.Raw and pData.Raw.UnlockedIslands) or {"Spawn"}
            local totalIslands = #GameAPI.OverworldIslands
            local unlockedCount = #unlockedIslands
            local lockedIsland = GameAPI.GetNextLockedIsland()

            local islandProgressStr = ""
            if lockedIsland then
                local pct = math.clamp(math.floor((pData.Clicks / math.max(1, lockedIsland.cost)) * 100), 0, 100)
                islandProgressStr = string.format("Current: %s • Next: %s (%d%% of %s)", pData.CurrentIsland, lockedIsland.name, pct, GameAPI.FormatNumber(lockedIsland.cost))
            else
                islandProgressStr = string.format("All %d/%d Islands Unlocked! (100%% Complete)", totalIslands, totalIslands)
            end

            local qProg = GameAPI.GetSecretQuestProgress()
            local qStr = qProg and (qProg.isUnlocked and "Dominus Door: UNLOCKED" or (qProg.allDone and "READY TO CLAIM!" or string.format("Feathers: %d/10 | Hatch: %d/2500", qProg.feathers.prog, qProg.hatch.prog))) or "N/A"

            local stProg = GameAPI.GetSkillTreeProgress()
            local stStr = stProg and string.format("Tech: %d/%d (%s) • Coins: %d/%d (%s)",
                stProg.TechBought, stProg.TechTotal, stProg.TechComplete and "DONE" or "In Progress",
                stProg.CoinsBought, stProg.CoinsTotal, stProg.CoinsComplete and "DONE" or "In Progress"
            ) or "N/A"

            local skinStatus = GameAPI.GetClickSkinStatus("Magma")
            local magmaStr = "Locked"
            if skinStatus and skinStatus.equipped then
                magmaStr = "EQUIPPED (+4 Hatch, +20% Spd)"
            elseif skinStatus and skinStatus.unlocked then
                magmaStr = "Unlocked (Equipping...)"
            else
                local currentRebirths = pData.Rebirths or 0
                local pctRebirth = math.clamp(math.floor((currentRebirths / 1e19) * 100), 0, 100)
                magmaStr = string.format("%d%% of 10 Qi (%s/10 Qi)", pctRebirth, GameAPI.FormatNumber(currentRebirths))
            end

            LiveStatusCard:Set({
                Title = "Speedrun Telemetry — " .. os.date("%X"),
                Content = currentPhaseText .. "\n" ..
                    "• Action: " .. currentActivity .. "\n" ..
                    "• Islands: " .. unlockedCount .. " / " .. totalIslands .. " (" .. islandProgressStr .. ")\n" ..
                    "• Clicks: " .. GameAPI.FormatNumber(pData.Clicks) .. " • Gems: " .. GameAPI.FormatNumber(pData.Gems) .. "\n" ..
                    "• Rebirths: " .. GameAPI.FormatNumber(pData.Rebirths) .. " • Multiplier: " .. GameAPI.FormatNumber(pData.Multiplier) .. "x\n" ..
                    "• 1st: Desert Machine / Gems: Active\n" ..
                    "• 2nd: Skill Tree: " .. stStr .. "\n" ..
                    "• 3rd: ??? Quest: " .. qStr .. "\n" ..
                    "• 4th: Magma Skin: " .. magmaStr
            })
        end)
    end
end))

-- 4. Furthest Unlocked Map Periodic Teleport Thread (Every 30 Seconds)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(30)
        pcall(function()
            local furthest = GameAPI.GetFurthestUnlockedIsland()
            if furthest and furthest ~= "" and furthest ~= "Spawn" then
                GameAPI.TeleportToIsland(furthest)
            end
        end)
    end
end))

-- 5. Auto Consumables & Rewards Thread (Potions, Fruits, Gifts, Chests)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(4.0)
        pcall(function()
            GameAPI.AutoConsumePotions()
            GameAPI.AutoConsumeFruits()
            GameAPI.ClaimAllFreeGifts()
            GameAPI.ClaimAllChests()
            GameAPI.ClaimDaily()
            GameAPI.ClaimAllAchievements()
            GameAPI.RollWheel()
        end)
    end
end))

Window:Notify({
    Title = "Clicker Hub Auto Prog",
    Content = "Tap ⚡ on screen or press Right-Ctrl to toggle UI.",
    Duration = 4
})
