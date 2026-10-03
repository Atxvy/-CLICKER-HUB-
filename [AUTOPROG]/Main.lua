--!strict
--==============================================================================
-- [AUTOPROG] Main.lua
-- Dedicated Full Zero-to-Hero Auto Progression Speedrun Engine for Clicker Simulator!
--
-- WORKFLOW:
-- • GLOBAL AUTOMATIC ACTIONS (Always Active):
--   - High-speed frame tick auto clicking
--   - Auto consume potions & all fruits
--   - Auto claim all 12 free gifts, chests, daily rewards, achievements
--   - Auto equip best pets
--   - Auto craft Golden pets (100% guaranteed chance priority)
--   - Remove weak pets prior to world (best world N: delete world <= N - 2)
--   - Prestige trigger as soon as requirements are met
--
-- • PHASE 1 (Island Speedrun - Locked Islands Remaining):
--   - Teleport to best unlocked island every 5 seconds
--   - Batch unlock affordable islands as soon as clicks requirement is met
--   - Smart Max Rebirth (pauses when clicks >= 85% of next island cost)
--   - Buy island mini upgrades (+1 pet equip slot, storage, speed)
--   - Buy rebirth gem upgrades & milestone buttons
--   - Auto open best egg until entire equipped team is 100% Golden
--
-- • PHASE 2 (Endgame Roadmap - All 17 Islands Unlocked):
--   - Periodic furthest map teleport every 30 seconds
--   - Continuous Max Rebirth at highest milestone button
--   - Keep opening best egg (MatrixEgg / CandyCornEgg) until 100% of equipped team is Golden
--   - Priority 1: Desert Machine & Rebirth Shop gem upgrades maxing
--   - Priority 2: Skill Tree Coins First (Volcano <-> Heaven breakables alternation) -> Tech Coins Tree
--   - 10 Qi Rebirth goal & Magma click skin (+4 Egg Hatch, +20% Speed)
--   - Auto ??? Secret Questline solver (Feathers, Hatches, Door)
--   - Auto claim finished Rainbow pets
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

--==============================================================================
-- LOAD MODULES (Hybrid Local + GitHub Remote Fallback)
--==============================================================================
local GITHUB_REPO = "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main"

local function loadModule(name: string)
    -- 1. Check local [AUTOPROG] folder first
    local localPath = "[AUTOPROG]/" .. name
    if readfile and isfile and isfile(localPath) then
        local chunk = readfile(localPath)
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        else
            warn("[AutoProg] Local compile error in " .. name .. ":", err)
        end
    end

    -- 2. Check local [CLICKER HUB] folder fallback
    local clickerHubPath = "[CLICKER HUB]/" .. name
    if readfile and isfile and isfile(clickerHubPath) then
        local chunk = readfile(clickerHubPath)
        local fn, err = loadstring(chunk)
        if fn then
            return fn()
        end
    end

    -- 3. Fallback to GitHub raw
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
            error("[AutoProg] Remote compile error in " .. name .. ": " .. tostring(err))
        end
    end

    error("[AutoProg] File not found in workspace or GitHub: " .. name)
end

local UILibrary = loadModule("UILibrary.lua")
local ProgAPI = nil
local okProg, pMod = pcall(function() return loadModule("ProgAPI.lua") end)
if okProg and pMod then
    ProgAPI = pMod
else
    ProgAPI = loadModule("AutoProgAPI.lua")
end
local AutoProgAPI = ProgAPI -- Backward compatibility alias
local Configs = loadModule("Configs.lua")

-- Suppress game black shade
pcall(ProgAPI.SuppressBlackShade)

-- Clean up any prior running AutoProg instance
if _G.ClickerSimulatorAutoProgCleanup then
    pcall(_G.ClickerSimulatorAutoProgCleanup)
end

local isRunning = true
local threads = {}

_G.ClickerSimulatorAutoProgCleanup = function()
    isRunning = false
    for _, th in ipairs(threads) do
        pcall(task.cancel, th)
    end
    table.clear(threads)
    if _G.ClickerSimulatorAutoProgWindow then
        pcall(function() _G.ClickerSimulatorAutoProgWindow:Destroy() end)
    end
end

-- Load state from Configs
local State = Configs.Load()

--==============================================================================
-- UI INITIALIZATION
--==============================================================================
local Window = UILibrary:CreateWindow({
    Title = "CLICKER SIMULATOR — AUTO PROGRESSION",
    Subtitle = "Zero-To-Hero Speedrun Engine [AUTOPROG]",
    Size = UDim2.fromOffset(660, 500),
    AccentColor = Color3.fromRGB(0, 170, 255),
    Theme = "Dark",
})
_G.ClickerSimulatorAutoProgWindow = Window

--==============================================================================
-- 1. DASHBOARD TAB
--==============================================================================
local DashTab = Window:AddTab({ Title = "Dashboard", Icon = "📊" })

DashTab:AddSection("MASTER CONTROLS")
DashTab:AddToggle("MasterEnabledToggle", {
    Title = "Enable Auto Progression Engine",
    Description = "Master switch controlling all automated gameplay phases",
    Default = State.MasterEnabled,
    Callback = function(val)
        State.MasterEnabled = val
        Configs.Set("MasterEnabled", val)
    end
})

DashTab:AddSection("LIVE TELEMETRY")
local LiveStatusCard = DashTab:AddParagraph({
    Title = "Progression Telemetry",
    Content = "Initializing..."
})

DashTab:AddSection("QUICK ACTIONS")
DashTab:AddButton({
    Title = "Prestige Now (If Available)",
    Description = "Immediately executes Prestige if requirements are met",
    Callback = function()
        local ok, msg = AutoProgAPI.CheckAndTriggerPrestige()
        Window:Notify({ Title = "Prestige", Content = msg, Duration = 3.5 })
    end
})

DashTab:AddButton({
    Title = "Max Rebirth Now",
    Description = "Triggers highest affordable rebirth milestone button",
    Callback = function()
        local info = AutoProgAPI.GetMaxRebirthInfo()
        if info.CanAffordMax then
            AutoProgAPI.RebirthMaxTarget()
            Window:Notify({ Title = "Rebirth", Content = "Max Rebirth executed! (+" .. AutoProgAPI.FormatNumber(info.BestAffordableAmount) .. ")", Duration = 2.5 })
        else
            Window:Notify({ Title = "Rebirth", Content = "Cannot afford Max Rebirth yet.", Duration = 2 })
        end
    end
})

DashTab:AddButton({
    Title = "Unlock All Affordable Islands",
    Description = "Purchases next locked islands in sequential order",
    Callback = function()
        local count, lastIsl = AutoProgAPI.UnlockAllAffordableIslands()
        Window:Notify({ Title = "Island Progression", Content = count > 0 and string.format("Unlocked %d Island(s)! Reached %s!", count, lastIsl) or "No affordable islands right now.", Duration = 3 })
    end
})

DashTab:AddButton({
    Title = "Craft 100% Golden Pets Now",
    Description = "Converts batches of 6 identical normal pets into Golden pets",
    Callback = function()
        local crafted = AutoProgAPI.CraftGoldenPets()
        AutoProgAPI.EquipBest()
        Window:Notify({ Title = "Golden Machine", Content = crafted > 0 and string.format("Crafted %d Golden Pet(s)!", crafted) or "No batches ready for Golden crafting.", Duration = 2.5 })
    end
})

DashTab:AddButton({
    Title = "Equip Best Pets",
    Description = "Equips your highest multiplier pets",
    Callback = function()
        AutoProgAPI.EquipBest()
        Window:Notify({ Title = "Pets", Content = "Best pets equipped!", Duration = 2 })
    end
})

DashTab:AddButton({
    Title = "Clean Weak Pets Now (World <= Best - 2)",
    Description = "Deletes obsolete weak pets based on your furthest world index",
    Callback = function()
        local cleaned = AutoProgAPI.CleanWeakPets(State.ProtectCraftingPets)
        Window:Notify({ Title = "Pet Cleaner", Content = string.format("Cleaned %d weak pets!", cleaned), Duration = 2.5 })
    end
})

DashTab:AddButton({
    Title = "Claim Milestones & Rewards",
    Description = "Claims all completed achievement stages, summer road rewards, and gifts",
    Callback = function()
        local ach, road = ProgAPI.ClaimAllMilestones()
        Window:Notify({ Title = "Milestones Claimed", Content = string.format("Claimed %d achievements, %d event rewards!", ach, road), Duration = 3 })
    end
})

--==============================================================================
-- 2. PHASE 1: ISLAND SPEEDRUN TAB
--==============================================================================
local Phase1Tab = Window:AddTab({ Title = "Phase 1: Islands", Icon = "🏝️" })

Phase1Tab:AddSection("PHASE 1 SETTINGS (UNLOCK ALL 17 ISLANDS)")
Phase1Tab:AddParagraph({
    Title = "Phase 1 Strategy",
    Content = "High-speed clicking, smart Max Rebirths, pet upgrades, unlocking affordable islands sequentially, and keeping best eggs hatched until the equipped team is 100% Golden."
})

Phase1Tab:AddToggle("AutoClickToggle_P1", {
    Title = "Auto Click",
    Description = "Maximum speed auto-clicking",
    Default = State.AutoClick,
    Callback = function(val) State.AutoClick = val; Configs.Set("AutoClick", val) end
})

Phase1Tab:AddToggle("AutoMaxRebirthToggle_P1", {
    Title = "Smart Max Rebirth",
    Description = "Rebirths at max affordable milestone. Automatically pauses rebirth when close to next island unlock cost.",
    Default = State.AutoMaxRebirth,
    Callback = function(val) State.AutoMaxRebirth = val; Configs.Set("AutoMaxRebirth", val) end
})

Phase1Tab:AddToggle("AutoUnlockIslandsToggle_P1", {
    Title = "Auto Unlock Islands",
    Description = "Buys next island and advances progression immediately",
    Default = State.AutoUnlockIslands,
    Callback = function(val) State.AutoUnlockIslands = val; Configs.Set("AutoUnlockIslands", val) end
})

Phase1Tab:AddToggle("AutoMapUpgradesToggle_P1", {
    Title = "Auto Buy Map Upgrades (+1 Pet Slot)",
    Description = "Buys island mini-upgrades for extra pet slots, storage, and speed",
    Default = State.AutoMapUpgrades,
    Callback = function(val) State.AutoMapUpgrades = val; Configs.Set("AutoMapUpgrades", val) end
})

Phase1Tab:AddToggle("AutoGemUpgradesToggle_P1", {
    Title = "Auto Buy Gem Upgrades & Rebirth Buttons",
    Description = "Spends rebirth gems on Click upgrades, Combo, and Rebirth milestone buttons",
    Default = State.AutoGemUpgrades,
    Callback = function(val) State.AutoGemUpgrades = val; Configs.Set("AutoGemUpgrades", val) end
})

Phase1Tab:AddToggle("AutoBestEggsToggle_P1", {
    Title = "Auto Open Best Eggs",
    Description = "Hatches highest affordable egg across unlocked islands",
    Default = State.AutoBestEggs,
    Callback = function(val) State.AutoBestEggs = val; Configs.Set("AutoBestEggs", val) end
})

Phase1Tab:AddToggle("AutoGoldToggle_P1", {
    Title = "Auto Gold (Full Golden Team)",
    Description = "Keeps opening best egg until 100% of equipped pet slots are Golden",
    Default = State.AutoGold,
    Callback = function(val) State.AutoGold = val; Configs.Set("AutoGold", val) end
})

--==============================================================================
-- 3. PHASE 2: ENDGAME ROADMAP TAB
--==============================================================================
local Phase2Tab = Window:AddTab({ Title = "Phase 2: Endgame", Icon = "👑" })

Phase2Tab:AddSection("PHASE 2 SETTINGS (RUNS WHEN ALL 17 ISLANDS UNLOCKED)")
Phase2Tab:AddParagraph({
    Title = "Endgame Progression Order",
    Content = "1st: Desert Gem Machine & Rebirth Shop Maxing\n" ..
              "2nd: Skill Tree Coins First (Volcano <-> Heaven Alternation) -> Tech Coins Tree\n" ..
              "3rd: Auto Prestige as soon as affordable\n" ..
              "4th: 10 Qi Rebirth Goal & Magma Click Skin\n" ..
              "5th: Auto ??? Secret Quest & Claim Rainbow Pets"
})

Phase2Tab:AddToggle("AutoPrestigeToggle_P2", {
    Title = "Auto Prestige (When Available)",
    Description = "Automatically triggers Prestige when Rebirths requirement is met, adapting progression smoothly",
    Default = State.AutoPrestige,
    Callback = function(val) State.AutoPrestige = val; Configs.Set("AutoPrestige", val) end
})

Phase2Tab:AddToggle("AutoDesertMachineToggle_P2", {
    Title = "1st: Desert Machine & Gem Upgrades Maxing",
    Description = "Maxes out Desert machine perks and rebirth milestone buttons",
    Default = State.AutoDesertMachine,
    Callback = function(val) State.AutoDesertMachine = val; Configs.Set("AutoDesertMachine", val) end
})

Phase2Tab:AddToggle("AutoSkillTreeToggle_P2", {
    Title = "2nd: Skill Tree (Coins First -> Tech Coins)",
    Description = "Farms Volcano & Heaven breakables for Coins perks, then advances to Matrix for Tech Coins",
    Default = State.AutoSkillTree,
    Callback = function(val) State.AutoSkillTree = val; Configs.Set("AutoSkillTree", val) end
})

Phase2Tab:AddToggle("AutoMagmaSkinToggle_P2", {
    Title = "4th: 10 Qi Rebirth Goal & Magma Click Skin",
    Description = "Monitors 10 Qi Rebirth milestone and equips Magma Click Skin (+4 Egg Hatch, +20% Speed)",
    Default = State.AutoMagmaSkin,
    Callback = function(val) State.AutoMagmaSkin = val; Configs.Set("AutoMagmaSkin", val) end
})

Phase2Tab:AddToggle("AutoSecretQuestToggle_P2", {
    Title = "5th: Auto ??? Secret Quest",
    Description = "Solves Dominus questline: collects feathers, hatches, and claims door",
    Default = State.AutoSecretQuest,
    Callback = function(val) State.AutoSecretQuest = val; Configs.Set("AutoSecretQuest", val) end
})

Phase2Tab:AddToggle("AutoRainbowClaimToggle_P2", {
    Title = "Auto Claim Rainbow Pets",
    Description = "Automatically collects finished pets from the Rainbow Machine",
    Default = State.AutoRainbowClaim,
    Callback = function(val) State.AutoRainbowClaim = val; Configs.Set("AutoRainbowClaim", val) end
})

--==============================================================================
-- 4. PETS HELPER TAB
--==============================================================================
local PetsTab = Window:AddTab({ Title = "Pets Helper", Icon = "🐾" })

PetsTab:AddSection("GOLDEN TEAM AUTOMATION")
PetsTab:AddToggle("AutoGoldToggle_Pets", {
    Title = "Auto Gold (Keep Opening Until Full Golden Team)",
    Description = "Continues hatching best egg until every single equipped pet slot is Golden!",
    Default = State.AutoGold,
    Callback = function(val) State.AutoGold = val; Configs.Set("AutoGold", val) end
})

PetsTab:AddToggle("AutoCraftGoldenToggle_Pets", {
    Title = "Auto Craft Golden (100% Guaranteed Priority)",
    Description = "Crafts batches of 6 normal pets into Golden pets with guaranteed 100% success rate",
    Default = State.AutoCraftGolden,
    Callback = function(val) State.AutoCraftGolden = val; Configs.Set("AutoCraftGolden", val) end
})

PetsTab:AddToggle("ProtectCraftingPetsToggle_Pets", {
    Title = "Protect Crafting Candidates (Do Not Delete)",
    Description = "Protects normal duplicate pets accumulating towards the 6-pet Golden crafting threshold",
    Default = State.ProtectCraftingPets,
    Callback = function(val) State.ProtectCraftingPets = val; Configs.Set("ProtectCraftingPets", val) end
})

PetsTab:AddToggle("AutoEquipBestToggle_Pets", {
    Title = "Auto Equip Best Pets",
    Description = "Always keeps your strongest pets equipped",
    Default = State.AutoEquipBest,
    Callback = function(val) State.AutoEquipBest = val; Configs.Set("AutoEquipBest", val) end
})

PetsTab:AddSection("SMART INVENTORY CLEANING")
PetsTab:AddToggle("AutoCleanPetsToggle_Pets", {
    Title = "Remove Weak Pets (World <= Best - 2)",
    Description = "Deletes normal pets from world (Best Island - 2) and below (e.g. World <= 15 when at Matrix)",
    Default = State.AutoCleanPets,
    Callback = function(val) State.AutoCleanPets = val; Configs.Set("AutoCleanPets", val) end
})

--==============================================================================
-- 5. CONSUMABLES & REWARDS TAB
--==============================================================================
local RewardsTab = Window:AddTab({ Title = "Consumables & Rewards", Icon = "🎁" })

RewardsTab:AddSection("AUTOMATIC CONSUMABLES")
RewardsTab:AddToggle("AutoPotionsToggle", {
    Title = "Auto Consume Potions",
    Description = "Continuously uses best owned Clicks, Speed, Luck, and Gems potions",
    Default = State.AutoPotions,
    Callback = function(val) State.AutoPotions = val; Configs.Set("AutoPotions", val) end
})

RewardsTab:AddToggle("AutoFruitsToggle", {
    Title = "Auto Consume Fruits",
    Description = "Continuously eats Apple, Banana, Orange, Grape, Pineapple, Dragonfruit, Pear",
    Default = State.AutoFruits,
    Callback = function(val) State.AutoFruits = val; Configs.Set("AutoFruits", val) end
})

RewardsTab:AddSection("FREE GIFTS & REWARDS")
RewardsTab:AddToggle("AutoFreeGiftsToggle", {
    Title = "Auto Claim Free Gifts, Chests & Achievements",
    Description = "Claims all 12 free gifts, daily rewards, world chests, and achievements automatically",
    Default = State.AutoFreeGifts,
    Callback = function(val) State.AutoFreeGifts = val; Configs.Set("AutoFreeGifts", val) end
})

RewardsTab:AddButton({
    Title = "Redeem All Promo Codes Now",
    Description = "Redeems all active game promo codes",
    Callback = function()
        local count = AutoProgAPI.RedeemAllCodes()
        Window:Notify({ Title = "Promo Codes", Content = string.format("Redeemed %d promo code(s)!", count), Duration = 3 })
    end
})

-- Startup code & gifts claim
task.spawn(function()
    task.wait(1.5)
    pcall(AutoProgAPI.RedeemAllCodes)
    pcall(AutoProgAPI.ClaimAllFreeGifts)
    pcall(AutoProgAPI.ClaimDaily)
end)

--==============================================================================
-- CORE ENGINE BACKGROUND THREADS
--==============================================================================

local currentActivity = "Initializing AutoProg..."
local currentPhaseText = "Evaluating..."

-- THREAD 1: HIGH-SPEED CLICK LOOP (CPS Maxing)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.MasterEnabled and State.AutoClick then
            AutoProgAPI.Click()
            task.wait(0.001)
        else
            task.wait(0.25)
        end
    end
end))

-- THREAD 2: GLOBAL AUTOMATIC MAINTENANCE (Consumables, Crafting, Cleaning, Prestige)
table.insert(threads, task.spawn(function()
    local lastPotionTick = 0
    local lastGiftTick = 0
    local lastCraftTick = 0
    local lastCleanTick = 0
    local lastEquipTick = 0
    local lastPrestigeTick = 0

    while isRunning do
        task.wait(0.5)
        if not State.MasterEnabled or not isRunning then continue end
        local now = tick()

        -- A. Prestige check (Runs continuously whenever eligible)
        if State.AutoPrestige and (now - lastPrestigeTick > 3) then
            lastPrestigeTick = now
            local prestInfo = AutoProgAPI.GetPrestigeInfo()
            if prestInfo.CanPrestige then
                currentActivity = "🚀 Triggering Prestige to Tier " .. tostring(prestInfo.CurrentPrestige + 1) .. "!"
                local ok, pMsg = AutoProgAPI.CheckAndTriggerPrestige()
                if ok then
                    Window:Notify({ Title = "PRESTIGE!", Content = pMsg, Duration = 5 })
                end
            end
        end

        -- B. Consumables: Potions & Fruits
        if (State.AutoPotions or State.AutoFruits) and (now - lastPotionTick > 15) then
            lastPotionTick = now
            if State.AutoPotions then pcall(AutoProgAPI.UseAllBestPotions) end
            if State.AutoFruits then pcall(AutoProgAPI.UseAllFruits) end
        end

        -- C. Free Gifts, Chests, Daily, Achievements & Milestones
        if State.AutoFreeGifts and (now - lastGiftTick > 8) then
            lastGiftTick = now
            pcall(function()
                ProgAPI.ClaimAllFreeGifts()
                ProgAPI.ClaimAllChests()
                ProgAPI.ClaimDaily()
                ProgAPI.ClaimAllMilestones()
            end)
        end

        -- D. Auto Craft Golden Pets (100% Guaranteed Priority)
        if State.AutoCraftGolden and (now - lastCraftTick > 2) then
            lastCraftTick = now
            local crafted = AutoProgAPI.CraftGoldenPets()
            if crafted > 0 then
                pcall(AutoProgAPI.EquipBest)
            end
        end

        -- E. Auto Clean Weak Pets (World <= Best - 2)
        if State.AutoCleanPets and (now - lastCleanTick > 5) then
            lastCleanTick = now
            AutoProgAPI.CleanWeakPets(State.ProtectCraftingPets)
        end

        -- F. Auto Equip Best Pets
        if State.AutoEquipBest and (now - lastEquipTick > 4) then
            lastEquipTick = now
            AutoProgAPI.EquipBest()
        end
    end
end))

-- THREAD 3: DEDICATED CONTINUOUS MAX REBIRTH (Non-blocking high-frequency execution)
table.insert(threads, task.spawn(function()
    local lastRebirthAttempt = 0
    while isRunning do
        task.wait(0.1)
        if not State.MasterEnabled or not State.AutoMaxRebirth or not isRunning then continue end
        local now = tick()
        if now - lastRebirthAttempt > 0.2 then
            lastRebirthAttempt = now
            local lockedIsland = ProgAPI.GetNextLockedIsland()
            local pData = ProgAPI.GetPlayerData()

            -- In Phase 1: if close to next island cost, hold clicks for unlock
            local isSavingForIsland = false
            if lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.85) then
                isSavingForIsland = true
            end

            if not isSavingForIsland then
                local maxInfo = ProgAPI.GetMaxRebirthInfo()
                if maxInfo.CanAffordMax then
                    ProgAPI.RebirthMaxTarget()
                end
            end
        end
    end
end))

-- THREAD 4: MAIN PROGRESSION STATE MACHINE (Phase 1 vs Phase 2)
table.insert(threads, task.spawn(function()
    local lastTeleportTick = 0
    local lastEggHatchTick = 0
    local lastUpgradesTick = 0
    local lastSkinTick = 0
    local lastQuestTick = 0
    local lastRainbowTick = 0
    local lastFurthestTpTick = 0

    while isRunning do
        task.wait(0.1)
        if not State.MasterEnabled or not isRunning then continue end
        local now = tick()

        local pData = AutoProgAPI.GetPlayerData()
        local lockedIsland = AutoProgAPI.GetNextLockedIsland()
        local isAllGold = AutoProgAPI.IsEquippedTeamAllGold()

        -- =====================================================================
        -- PHASE 1: ISLAND SPEEDRUN (Locked islands remaining)
        -- =====================================================================
        if lockedIsland ~= nil then
            currentPhaseText = "🌟 PHASE 1: ISLAND SPEEDRUN"

            -- 1. Auto Teleport to Best Unlocked Island Every 5 Seconds
            if now - lastTeleportTick > 5 then
                lastTeleportTick = now
                local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                if pData.CurrentIsland ~= furthest then
                    AutoProgAPI.TeleportToIsland(furthest)
                end
            end

            -- 2. Check Island Unlock Condition
            if State.AutoUnlockIslands and lockedIsland then
                if pData.Clicks >= lockedIsland.cost then
                    currentActivity = "🌟 Unlocking next island: " .. lockedIsland.name .. "!"
                    local count, lastIsl = AutoProgAPI.UnlockAllAffordableIslands()
                    if count > 0 and lastIsl then
                        Window:Notify({ Title = "Islands Unlocked!", Content = string.format("🚀 Reached %s!", lastIsl), Duration = 3 })
                        pcall(AutoProgAPI.EquipBest)
                        pData = AutoProgAPI.GetPlayerData()
                        lockedIsland = AutoProgAPI.GetNextLockedIsland()
                    end
                end
            end

            -- 3. Smart Max Rebirth
            -- If we are NOT within 85% of next island cost, rebirth aggressively to multiply clicks!
            if State.AutoMaxRebirth and lockedIsland then
                local isNearIsland = (pData.Clicks >= lockedIsland.cost * 0.85)
                if not isNearIsland then
                    local maxInfo = AutoProgAPI.GetMaxRebirthInfo()
                    if maxInfo.CanAffordMax then
                        currentActivity = string.format("Rebirthing Max Button #%d (+%s)", maxInfo.MaxButtonIndex, AutoProgAPI.FormatNumber(maxInfo.BestAffordableAmount))
                        AutoProgAPI.RebirthMaxTarget()
                    end
                else
                    currentActivity = string.format("Saving Clicks for %s (%s / %s)", lockedIsland.name, AutoProgAPI.FormatNumber(pData.Clicks), AutoProgAPI.FormatNumber(lockedIsland.cost))
                end
            end

            -- 4. Map Mini Upgrades (+1 Pet Slot, Storage)
            if State.AutoMapUpgrades and (now - lastUpgradesTick > 2) then
                lastUpgradesTick = now
                AutoProgAPI.BuyAffordableMiniUpgrades()
            end

            -- 5. Gem Upgrades & Rebirth Buttons
            if State.AutoGemUpgrades and (now - lastUpgradesTick > 1.5) then
                AutoProgAPI.BuyAffordableGemUpgrades()
                if State.AutoRebirthButtons then
                    AutoProgAPI.BuyNextRebirthButton()
                    AutoProgAPI.BuyNextDoubleJump()
                end
            end

            -- 6. Auto Open Best Egg & Auto Gold
            if (State.AutoBestEggs or State.AutoGold) and (now - lastEggHatchTick > 0.35) then
                lastEggHatchTick = now
                local isNearUnlock = lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.70)

                -- If AutoGold is active and team is not all gold: KEEP OPENING BEST EGG!
                if State.AutoGold and not isAllGold then
                    local bestEgg = AutoProgAPI.GetBestAffordableEgg()
                    if bestEgg and pData.Clicks >= bestEgg.cost then
                        currentActivity = string.format("[Auto Gold] Hatching %s for 100%% Golden Team", bestEgg.name)
                        AutoProgAPI.OpenEgg(bestEgg.name, 1)
                        pcall(AutoProgAPI.CraftGoldenPets)
                        pcall(AutoProgAPI.EquipBest)
                    end
                elseif not isNearUnlock and State.AutoBestEggs then
                    local bestEgg = AutoProgAPI.GetBestAffordableEgg()
                    if bestEgg and pData.Clicks >= bestEgg.cost then
                        currentActivity = "Hatching " .. bestEgg.name
                        AutoProgAPI.OpenEgg(bestEgg.name, 1)
                    end
                end
            end

        -- =====================================================================
        -- PHASE 2: ENDGAME ROADMAP (All 17 Islands Unlocked!)
        -- =====================================================================
        else
            currentPhaseText = "👑 PHASE 2: ENDGAME ROADMAP"

            -- 1. Periodic Furthest Map Teleport Every 30 Seconds
            if (now - lastFurthestTpTick > 30) then
                lastFurthestTpTick = now
                local stProg = AutoProgAPI.GetSkillTreeProgress()
                -- If skill tree coins is done, keep player on furthest map (Matrix in Tech World)
                if stProg.CoinsComplete then
                    local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                    if pData.CurrentIsland ~= furthest then
                        AutoProgAPI.TeleportToIsland(furthest)
                    end
                end
            end

            -- 2. Max Rebirth Continuously (Milestone button 47+)
            if State.AutoMaxRebirth then
                local maxInfo = AutoProgAPI.GetMaxRebirthInfo()
                if maxInfo.CanAffordMax then
                    currentActivity = string.format("[Endgame] Max Rebirth (+%s)", AutoProgAPI.FormatNumber(maxInfo.BestAffordableAmount))
                    AutoProgAPI.RebirthMaxTarget()
                end
            end

            -- 3. Keep Hatching Best Egg Until Full Golden Team!
            if State.AutoGold and not isAllGold and (now - lastEggHatchTick > 0.35) then
                lastEggHatchTick = now
                local bestEgg = AutoProgAPI.GetBestAffordableEgg()
                if bestEgg and pData.Clicks >= bestEgg.cost then
                    currentActivity = "[Auto Gold] Hatching " .. bestEgg.name .. " for Full Golden Team"
                    AutoProgAPI.OpenEgg(bestEgg.name, 1)
                    pcall(AutoProgAPI.CraftGoldenPets)
                    pcall(AutoProgAPI.EquipBest)
                end
            end

            -- 4. PRIORITY 1: Desert Machine & Gem Upgrades Maxing
            if State.AutoDesertMachine and (now - lastUpgradesTick > 2) then
                lastUpgradesTick = now
                AutoProgAPI.BuyAffordableGemUpgrades()
                AutoProgAPI.BuyAffordableMiniUpgrades()
                AutoProgAPI.BuyNextRebirthButton()
                AutoProgAPI.BuyNextDoubleJump()
            end

            -- 5. PRIORITY 2: Skill Tree Coins First -> Tech Coins Pipeline
            if State.AutoSkillTree then
                local action, targetIsl = AutoProgAPI.StepBreakablesPipeline()
                currentActivity = string.format("[Skill Tree] %s in %s", action, targetIsl)
            end

            -- 6. 10 Qi Rebirth Goal & Magma Click Skin
            if State.AutoMagmaSkin and (now - lastSkinTick > 3) then
                lastSkinTick = now
                local okSkin, skinMsg = AutoProgAPI.CheckAndEquipMagmaSkin()
                if okSkin and skinMsg and not skinMsg:find("Active") then
                    currentActivity = "[Magma Skin] " .. tostring(skinMsg)
                end
            end

            -- 7. Auto ??? Secret Quest
            if State.AutoSecretQuest and (now - lastQuestTick > 0.5) then
                lastQuestTick = now
                local okQ, qMsg = AutoProgAPI.StepSecretQuest()
                if okQ and qMsg and not qMsg:find("Already") then
                    currentActivity = "[??? Quest] " .. tostring(qMsg)
                end
            end

            -- 8. Auto Claim Rainbow Pets
            if State.AutoRainbowClaim and (now - lastRainbowTick > 5) then
                lastRainbowTick = now
                local claimed = AutoProgAPI.ClaimRainbowPets()
                if claimed > 0 then
                    currentActivity = string.format("Claimed %d Rainbow Pet(s)!", claimed)
                end
            end
        end
    end
end))

-- THREAD 5: TELEMETRY DISPLAY REFRESH
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(0.5)
        if not isRunning then break end

        pcall(function()
            local pData = AutoProgAPI.GetPlayerData()
            local lockedIsland = AutoProgAPI.GetNextLockedIsland()
            local totalIslands = #AutoProgAPI.OrderedIslands

            local islandProgressStr = ""
            if lockedIsland then
                local pct = math.clamp(math.floor((pData.Clicks / math.max(1, lockedIsland.cost)) * 100), 0, 100)
                islandProgressStr = string.format("Current: %s • Next: %s (%d%% of %s)", pData.CurrentIsland, lockedIsland.name, pct, AutoProgAPI.FormatNumber(lockedIsland.cost))
            else
                islandProgressStr = string.format("All %d/%d Islands Unlocked! (100%% Complete)", totalIslands, totalIslands)
            end

            local prestInfo = AutoProgAPI.GetPrestigeInfo()
            local prestStr = prestInfo.CanPrestige and "READY TO PRESTIGE!" or string.format("Tier %d (Need %s Rebirths)", prestInfo.CurrentPrestige, AutoProgAPI.FormatNumber(prestInfo.RequiredRebirths))

            local stProg = AutoProgAPI.GetSkillTreeProgress()
            local stStr = stProg and string.format("Coins: %d/%d (%s) • Tech: %d/%d (%s)",
                stProg.CoinsBought, stProg.CoinsTotal, stProg.CoinsComplete and "DONE" or "In Progress",
                stProg.TechBought, stProg.TechTotal, stProg.TechComplete and "DONE" or "In Progress"
            ) or "N/A"

            local isAllGold = AutoProgAPI.IsEquippedTeamAllGold()
            local goldStr = isAllGold and "100% FULL GOLD TEAM" or "In Progress (Hatching Best Egg...)"

            local skinStatus = AutoProgAPI.CheckAndEquipMagmaSkin
            local magmaPct = math.clamp(math.floor((pData.Rebirths / 1e19) * 100), 0, 100)
            local magmaStr = (pData.Rebirths >= 1e19) and "UNLOCKED / ACTIVE" or string.format("%d%% of 10 Qi (%s/10 Qi)", magmaPct, AutoProgAPI.FormatNumber(pData.Rebirths))

            LiveStatusCard:Set({
                Title = "Speedrun Telemetry — " .. os.date("%X"),
                Content = string.format(
                    "📊 **Status**: %s\n" ..
                    "🎯 **Phase**: %s\n" ..
                    "⚡ **Clicks**: %s | **Rebirths**: %s\n" ..
                    "💎 **Gems**: %s | **Coins**: %s | **Tech Coins**: %s\n" ..
                    "🚀 **Prestige**: %s\n" ..
                    "🏝️ **Islands**: %s\n" ..
                    "🐾 **Gold Team**: %s\n" ..
                    "🌳 **Skill Tree**: %s\n" ..
                    "🔥 **Magma Skin**: %s",
                    currentActivity,
                    currentPhaseText,
                    AutoProgAPI.FormatNumber(pData.Clicks),
                    AutoProgAPI.FormatNumber(pData.Rebirths),
                    AutoProgAPI.FormatNumber(pData.Gems),
                    AutoProgAPI.FormatNumber(pData.Coins),
                    AutoProgAPI.FormatNumber(pData.SpaceCoins),
                    prestStr,
                    islandProgressStr,
                    goldStr,
                    stStr,
                    magmaStr
                )
            })
        end)
    end
end))

Window:Notify({
    Title = "Auto Progression Loaded!",
    Content = "Autonomous Zero-to-Hero Speedrun Engine [AUTOPROG] is active!",
    Duration = 4
})
