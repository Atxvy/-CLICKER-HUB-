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

    -- 3. Fallback to GitHub raw (checks both [AUTOPROG] directory and repository root)
    local urls = {
        GITHUB_REPO .. "/%5BAUTOPROG%5D/" .. name .. "?t=" .. tostring(os.time()),
        GITHUB_REPO .. "/[AUTOPROG]/" .. name,
        GITHUB_REPO .. "/" .. name .. "?t=" .. tostring(os.time()),
        GITHUB_REPO .. "/" .. name
    }
    for _, url in ipairs(urls) do
        local ok, chunk = pcall(game.HttpGet, game, url)
        if ok and chunk and #chunk > 0 and not chunk:find("404: Not Found") then
            local fn, err = loadstring(chunk)
            if fn then
                return fn()
            else
                warn("[AutoProg] Remote compile error in " .. name .. " from " .. url .. ":", err)
            end
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
_G.ClickerSimulatorAutoProgCard = LiveStatusCard

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

DashTab:AddButton({
    Title = "Upgrade Skill Tree Now",
    Description = "Buys all currently affordable skill tree perks immediately",
    Callback = function()
        local bought = ProgAPI.BuyAffordableSkillTree(true)
        Window:Notify({ Title = "Skill Tree", Content = string.format("Upgraded %d perk(s)!", bought), Duration = 2.5 })
    end
})

DashTab:AddButton({
    Title = "Buy Affordable Rebirth Buttons Now",
    Description = "Purchases all affordable rebirth buttons & double jumps immediately",
    Callback = function()
        local boughtAny = ProgAPI.BuyNextRebirthButton()
        local boughtJump = ProgAPI.BuyNextDoubleJump()
        local maxInfo = ProgAPI.GetMaxRebirthInfo()
        Window:Notify({
            Title = "Rebirth Buttons",
            Content = string.format("Highest button unlocked: #%d (+%s)!", maxInfo.MaxButtonIndex, ProgAPI.FormatNumber(maxInfo.MaxAmount)),
            Duration = 3
        })
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
    pcall(AutoProgAPI.CheckAndSelectStarterPet)
    pcall(AutoProgAPI.RedeemAllCodes)
    pcall(AutoProgAPI.ClaimAllFreeGifts)
    pcall(AutoProgAPI.ClaimCompletedQuests)
    pcall(AutoProgAPI.ClaimDaily)
    pcall(AutoProgAPI.EquipBest)
end)

-- Rejoin & Startup Teleport Guarantee: If in Phase 2 and Skill Tree is not maxed, teleport to active breakables arena!
task.spawn(function()
    task.wait(1.8)
    pcall(function()
        local pData = AutoProgAPI.GetPlayerData()
        local lockedIsland = AutoProgAPI.GetNextLockedIsland()
        if lockedIsland == nil and State.AutoSkillTree then
            local stProg = AutoProgAPI.GetSkillTreeProgress()
            if not stProg.CoinsComplete then
                AutoProgAPI.TeleportToWorld("Overworld")
                AutoProgAPI.TeleportToIsland("Heaven")
                task.wait(0.4)
                AutoProgAPI.TeleportToBreakableZone("Heaven")
            elseif not stProg.TechComplete then
                AutoProgAPI.TeleportToWorld("Techworld")
                AutoProgAPI.TeleportToIsland("Matrix")
                task.wait(0.4)
                AutoProgAPI.TeleportToBreakableZone("Matrix")
            end
        end
    end)
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

-- THREAD 2: DEDICATED CONTINUOUS MAX REBIRTH (Non-blocking high-frequency execution)
table.insert(threads, task.spawn(function()
    local lastRebirthAttempt = 0
    while isRunning do
        task.wait(0.1)
        if not State.MasterEnabled or not State.AutoMaxRebirth or not isRunning then continue end

        -- RAINBOW MODE PROTECTION: Disable auto rebirth while building Rainbow Team so zero clicks are wasted!
        if AutoProgAPI.IsRainbowMode and AutoProgAPI.IsRainbowMode() then
            task.wait(0.5)
            continue
        end

        local now = tick()
        if now - lastRebirthAttempt > 0.15 then
            lastRebirthAttempt = now
            local maxInfo = ProgAPI.GetMaxRebirthInfo()
            if maxInfo and maxInfo.CanAffordMax then
                ProgAPI.RebirthMaxTarget()
            end
        end
    end
end))

-- THREAD 3: DEDICATED AUTO POTIONS CONSUMABLE THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(4)
        if isRunning and State.MasterEnabled and State.AutoPotions then
            pcall(AutoProgAPI.UseAllBestPotions)
        end
    end
end))

-- THREAD 4: DEDICATED AUTO FRUITS CONSUMABLE THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(4)
        if isRunning and State.MasterEnabled and State.AutoFruits then
            pcall(AutoProgAPI.UseAllFruits)
        end
    end
end))

-- THREAD 5: DEDICATED AUTO FREE GIFTS, CHESTS, DAILY, QUESTS & MILESTONES THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(4)
        if isRunning and State.MasterEnabled and State.AutoFreeGifts then
            pcall(function()
                AutoProgAPI.ClaimAllFreeGifts()
                AutoProgAPI.ClaimAllChests()
                AutoProgAPI.ClaimDaily()
                AutoProgAPI.ClaimCompletedQuests()
                AutoProgAPI.ClaimAllMilestones()
            end)
        end
    end
end))

-- THREAD 6: DEDICATED AUTO CRAFT GOLDEN PETS THREAD (100% Guaranteed Priority)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2)
        if isRunning and State.MasterEnabled and State.AutoCraftGolden then
            local crafted = AutoProgAPI.CraftGoldenPets()
            if crafted > 0 then
                pcall(AutoProgAPI.EquipBest)
            end
        end
    end
end))

-- THREAD 7: DEDICATED AUTO RAINBOW PETS CRAFT & CLAIM THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2.5)
        if isRunning and State.MasterEnabled and State.AutoRainbowClaim then
            AutoProgAPI.CraftRainbowPets()
            AutoProgAPI.ClaimRainbowPets()
        end
    end
end))

-- THREAD 8: DEDICATED AUTO CLEAN WEAK PETS THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(5)
        if isRunning and State.MasterEnabled and State.AutoCleanPets then
            AutoProgAPI.CleanWeakPets(State.ProtectCraftingPets)
        end
    end
end))

-- THREAD 9: DEDICATED AUTO EQUIP BEST PETS THREAD
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2.5)
        if isRunning and State.MasterEnabled and State.AutoEquipBest then
            ProgAPI.EquipBest()
        end
    end
end))

-- THREAD 10: DEDICATED AUTO ISLAND UNLOCK / RE-PURCHASE THREAD (Recovers islands after prestige & enters Tech World)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(1.5)
        if isRunning and State.MasterEnabled and State.AutoUnlockIslands then
            pcall(AutoProgAPI.CheckAndRebuyIslands)
            if AutoProgAPI.IsIslandUnlocked("Hell") and not AutoProgAPI.IsIslandUnlocked("Base") then
                pcall(AutoProgAPI.CheckAndEnterTechWorld)
            end
        end
    end
end))

-- THREAD 11: DEDICATED PASSIVE UPGRADES THREAD (Mini Upgrades, Gems, Desert Machine, Rebirth Buttons)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2)
        if isRunning and State.MasterEnabled then
            if State.AutoMapUpgrades then pcall(AutoProgAPI.BuyAffordableMiniUpgrades) end
            if State.AutoGemUpgrades or State.AutoDesertMachine then pcall(AutoProgAPI.BuyAffordableGemUpgrades) end
            if State.AutoRebirthButtons then
                pcall(function()
                    AutoProgAPI.BuyNextRebirthButton()
                    AutoProgAPI.BuyNextDoubleJump()
                end)
            end
        end
    end
end))

-- THREAD 12: DEDICATED AUTO PRESTIGE THREAD (Strict Phase 2 requirement: All islands unlocked)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2)
        if isRunning and State.MasterEnabled and State.AutoPrestige then
            if AutoProgAPI.AreAllIslandsUnlocked() then
                local prestInfo = AutoProgAPI.GetPrestigeInfo()
                if prestInfo and prestInfo.CanPrestige then
                    currentActivity = "🚀 Triggering Prestige to Tier " .. tostring(prestInfo.CurrentPrestige + 1) .. "!"
                    local ok, pMsg = AutoProgAPI.CheckAndTriggerPrestige()
                    if ok then
                        Window:Notify({ Title = "PRESTIGE!", Content = pMsg, Duration = 5 })
                        task.wait(1)
                        pcall(AutoProgAPI.CheckAndRebuyIslands)
                    end
                end
            end
        end
    end
end))

-- THREAD 13: DEDICATED BREAKABLES & SKILL TREE ENGINE (Active in Phase 2 until Skill Tree is MAXED!)
table.insert(threads, task.spawn(function()
    local lastBreakableTick = 0
    while isRunning do
        task.wait(0.04)
        if not State.MasterEnabled or not isRunning then continue end

        local allIslands = AutoProgAPI.AreAllIslandsUnlocked()
        local stProg = AutoProgAPI.GetSkillTreeProgress()
        local isSkillTreeMaxed = stProg and stProg.CoinsComplete and stProg.TechComplete

        -- Runs in Phase 2 until Skill Tree is fully maxed!
        if allIslands and (not isSkillTreeMaxed) and State.AutoSkillTree then
            local now = tick()
            if now - lastBreakableTick >= 0.05 then
                lastBreakableTick = now
                local action, targetIsl = AutoProgAPI.StepBreakablesPipeline()
                if action then
                    currentActivity = string.format("[Skill Tree] %s in %s", tostring(action), tostring(targetIsl or "Heaven"))
                end
            end
        end
    end
end))

-- THREAD 14: MAIN PROGRESSION STATE MACHINE (Step 1 / Phase 1 vs Phase 2)
table.insert(threads, task.spawn(function()
    local lastTeleportTick = 0
    local lastEggHatchTick = 0
    local lastSkinTick = 0
    local lastQuestTick = 0
    local lastFurthestTpTick = 0

    while isRunning do
        task.wait(0.05)
        if not State.MasterEnabled or not isRunning then continue end
        pcall(function()
            local now = tick()
            local pData = AutoProgAPI.GetPlayerData()
            local allIslandsUnlocked = AutoProgAPI.AreAllIslandsUnlocked()
            local lockedIsland = AutoProgAPI.GetNextLockedIsland()
            local isAllGold = AutoProgAPI.IsEquippedTeamAllGold()
            local isAllRainbow = AutoProgAPI.IsEquippedTeamAllRainbow()

            -- =====================================================================
            -- STEP 1 (PHASE 1: ISLAND SPEEDRUN)
            -- Condition: Player does NOT own all islands yet!
            -- Rule: Never start skill tree until all islands owned & team upgraded!
            -- =====================================================================
            if not allIslandsUnlocked and lockedIsland ~= nil then
                currentPhaseText = string.format("🌟 PHASE 1: ISLAND SPEEDRUN (%s)", lockedIsland.name)

                -- Auto pick starter pet if new player
                pcall(AutoProgAPI.CheckAndSelectStarterPet)

                local bestEgg = AutoProgAPI.GetBestAffordableEgg()
                local canAffordBestEgg = (bestEgg ~= nil) and (pData.Clicks >= bestEgg.cost)
                local shouldHatch = (State.AutoBestEggs or State.AutoGold) and (not isAllGold) and canAffordBestEgg

                -- 1. Auto Teleport to furthest unlocked island (For best click multiplier when not hatching!)
                if not shouldHatch and (now - lastTeleportTick > 3) then
                    lastTeleportTick = now
                    local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                    if pData.CurrentIsland ~= furthest then
                        AutoProgAPI.TeleportToIsland(furthest)
                    end
                end

                -- 2. Auto buy island as soon as clicks requirement is met
                if State.AutoUnlockIslands and lockedIsland then
                    -- If next locked island is in Tech World and Hell is unlocked, enter Tech World!
                    if AutoProgAPI.IsIslandUnlocked("Hell") and not AutoProgAPI.IsIslandUnlocked("Base") then
                        pcall(AutoProgAPI.CheckAndEnterTechWorld)
                    end

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

                -- 3. Auto buy egg for pets & auto gold pets
                if (State.AutoBestEggs or State.AutoGold) and (now - lastEggHatchTick > 0.35) then
                    lastEggHatchTick = now
                    local isNearUnlock = lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.75)

                    -- If team is not yet all gold, hatch best affordable egg!
                    if not isAllGold and canAffordBestEgg then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount(bestEgg.name)
                        currentActivity = string.format("[Phase 1] Hatching %dx %s on %s for Golden Team", hatchAmount, bestEgg.name, bestEgg.island)
                        AutoProgAPI.OpenEgg(bestEgg.name, hatchAmount)
                        pcall(AutoProgAPI.CraftGoldenPets)
                        pcall(AutoProgAPI.EquipBest)
                    elseif not isNearUnlock and State.AutoBestEggs and canAffordBestEgg then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount(bestEgg.name)
                        currentActivity = string.format("[Phase 1] Hatching %dx %s on %s", hatchAmount, bestEgg.name, bestEgg.island)
                        AutoProgAPI.OpenEgg(bestEgg.name, hatchAmount)
                        pcall(AutoProgAPI.CraftGoldenPets)
                        pcall(AutoProgAPI.EquipBest)
                    end
                end

            -- =====================================================================
            -- PHASE 2 (ENDGAME ROADMAP)
            -- Condition: ALL 17 islands are owned and unlocked!
            -- Progression Order:
            -- 1. Accept ??? Quest EARLY at start of Phase 2
            -- 2. Max Skill Tree (Coins first via Heaven/Volcano, then Tech via Matrix)
            -- 3. Auto Rainbow pets (Hatch best egg -> Gold -> Rainbow -> Claim) once Skill Tree is maxed
            -- 4. Prestige if possible (Resets islands & restarts Phase 1 with huge multiplier)
            -- =====================================================================
            else
                currentPhaseText = "👑 PHASE 2: ENDGAME ROADMAP"

                local stProg = AutoProgAPI.GetSkillTreeProgress()
                local isSkillTreeMaxed = stProg and stProg.CoinsComplete and stProg.TechComplete

                -- 1. Accept / Advance ??? Secret Quest EARLY when Phase 2 starts!
                if State.AutoSecretQuest and (now - lastQuestTick > 1.5) then
                    lastQuestTick = now
                    local qProg = AutoProgAPI.GetSecretQuestProgress()
                    if not qProg.DoorUnlocked then
                        local okQ, qMsg = AutoProgAPI.StepSecretQuest()
                        if okQ and qMsg and not qMsg:find("Already") then
                            currentActivity = "[??? Quest] " .. tostring(qMsg)
                        end
                    end
                end

                -- 2. Auto Rainbow Team Building: Initiates WHEN Skill Tree is MAXED!
                if isSkillTreeMaxed and not isAllRainbow and (now - lastEggHatchTick > 0.35) then
                    lastEggHatchTick = now
                    local latestEgg = AutoProgAPI.GetBestAffordableEgg()
                    if latestEgg and pData.Clicks >= latestEgg.cost then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount(latestEgg.name)
                        currentActivity = string.format("[Phase 2: Rainbow] Hatching %dx %s -> Golden -> Rainbow Pipeline", hatchAmount, latestEgg.name)
                        AutoProgAPI.OpenEgg(latestEgg.name, hatchAmount)
                        pcall(AutoProgAPI.CraftGoldenPets)
                        pcall(AutoProgAPI.CraftRainbowPets)
                        pcall(AutoProgAPI.ClaimRainbowPets)
                        pcall(AutoProgAPI.EquipBest)
                    else
                        -- Accumulate clicks on furthest island if egg is unaffordable
                        local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                        if pData.CurrentIsland ~= furthest and (now - lastTeleportTick > 3) then
                            lastTeleportTick = now
                            AutoProgAPI.TeleportToIsland(furthest)
                        end
                    end
                end

                -- 3. Furthest Map Teleport Check: when skill tree is fully complete AND team is all rainbow, stay at furthest island for click farming
                if isSkillTreeMaxed and isAllRainbow and (now - lastFurthestTpTick > 30) then
                    lastFurthestTpTick = now
                    local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                    if pData.CurrentIsland ~= furthest then
                        AutoProgAPI.TeleportToIsland(furthest)
                    end
                end

                -- 4. 10 Qi Rebirth Goal & Magma Click Skin
                if State.AutoMagmaSkin and (now - lastSkinTick > 3) then
                    lastSkinTick = now
                    local okSkin, skinMsg = AutoProgAPI.CheckAndEquipMagmaSkin()
                    if okSkin and skinMsg and not skinMsg:find("Active") then
                        currentActivity = "[Magma Skin] " .. tostring(skinMsg)
                    end
                end
            end
        end)
    end
end))

local function updateTelemetry()
    local ok, err = pcall(function()
        local pData = ProgAPI.GetPlayerData()
        local lockedIsland = ProgAPI.GetNextLockedIsland()
        local totalIslands = (ProgAPI.OrderedIslands and #ProgAPI.OrderedIslands) or 17

        local islandProgressStr = ""
        if lockedIsland then
            local pct = math.clamp(math.floor((pData.Clicks / math.max(1, lockedIsland.cost)) * 100), 0, 100)
            islandProgressStr = string.format("Current: %s • Next: %s (%d%% of %s)", pData.CurrentIsland, lockedIsland.name, pct, ProgAPI.FormatNumber(lockedIsland.cost))
        else
            islandProgressStr = string.format("All %d/%d Islands Unlocked! (100%% Complete)", totalIslands, totalIslands)
        end

        local prestInfo = ProgAPI.GetPrestigeInfo()
        local prestStr = prestInfo.CanPrestige and "READY TO PRESTIGE!" or string.format("Tier %d (Need %s Rebirths)", prestInfo.CurrentPrestige, ProgAPI.FormatNumber(prestInfo.RequiredRebirths))

        local stProg = ProgAPI.GetSkillTreeProgress()
        local stStr = stProg and string.format("Coins: %d/%d (%s) • Tech: %d/%d (%s)",
            stProg.CoinsBought, stProg.CoinsTotal, stProg.CoinsComplete and "DONE" or "In Progress",
            stProg.TechBought, stProg.TechTotal, stProg.TechComplete and "DONE" or "In Progress"
        ) or "N/A"

        local isAllGold = ProgAPI.IsEquippedTeamAllGold()
        local isAllRainbow = ProgAPI.IsEquippedTeamAllRainbow()
        local teamStr = isAllRainbow and "🌈 100% FULL RAINBOW TEAM" or (isAllGold and "⭐ Full Gold (Crafting Rainbow...)" or "In Progress (Hatching Best Egg...)")

        local magmaPct = math.clamp(math.floor((pData.Rebirths / 1e19) * 100), 0, 100)
        local magmaStr = (pData.Rebirths >= 1e19) and "UNLOCKED / ACTIVE" or string.format("%d%% of 10 Qi (%s/10 Qi)", magmaPct, ProgAPI.FormatNumber(pData.Rebirths))

        local cardTitle = "CURRENT: " .. tostring(currentActivity or "Auto Progression Active")
        local cardContent = string.format(
            "📊 **Activity**: %s\n" ..
            "🎯 **Phase**: %s\n" ..
            "⚡ **Clicks**: %s | **Rebirths**: %s\n" ..
            "💎 **Gems**: %s | **Coins**: %s | **Tech Coins**: %s\n" ..
            "🚀 **Prestige**: %s\n" ..
            "🏝️ **Islands**: %s\n" ..
            "🐾 **Pet Team**: %s\n" ..
            "🌳 **Skill Tree**: %s\n" ..
            "🔥 **Magma Skin**: %s",
            tostring(currentActivity or "Auto Progression Active"),
            tostring(currentPhaseText or "Phase 2"),
            ProgAPI.FormatNumber(pData.Clicks or 0),
            ProgAPI.FormatNumber(pData.Rebirths or 0),
            ProgAPI.FormatNumber(pData.Gems or 0),
            ProgAPI.FormatNumber(pData.Coins or 0),
            ProgAPI.FormatNumber(pData.SpaceCoins or 0),
            tostring(prestStr),
            tostring(islandProgressStr),
            tostring(teamStr),
            tostring(stStr),
            tostring(magmaStr)
        )

        if LiveStatusCard then
            LiveStatusCard:Set({
                Title = cardTitle,
                Content = cardContent
            })
            if LiveStatusCard.TitleLabel then
                pcall(function() LiveStatusCard.TitleLabel.Text = cardTitle end)
            end
            if LiveStatusCard.BodyLabel then
                pcall(function() LiveStatusCard.BodyLabel.Text = cardContent end)
            end
        end
    end)
    if not ok then
        pcall(function()
            if LiveStatusCard then
                local fallbackTitle = "CURRENT: " .. tostring(currentActivity or "Running")
                local fallbackBody = string.format("📊 **Activity**: %s\n🎯 **Phase**: %s\n⚡ Running Auto Progression...", tostring(currentActivity or "Active"), tostring(currentPhaseText or "Phase 2"))
                LiveStatusCard:Set({
                    Title = fallbackTitle,
                    Content = fallbackBody
                })
                if LiveStatusCard.TitleLabel then pcall(function() LiveStatusCard.TitleLabel.Text = fallbackTitle end) end
                if LiveStatusCard.BodyLabel then pcall(function() LiveStatusCard.BodyLabel.Text = fallbackBody end) end
            end
        end)
    end
end

-- Refresh telemetry immediately on startup
task.spawn(function()
    task.wait(0.2)
    updateTelemetry()
end)

-- THREAD 5: TELEMETRY DISPLAY REFRESH LOOP
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(0.5)
        if not isRunning then break end
        updateTelemetry()
    end
end))

Window:Notify({
    Title = "Auto Progression Loaded!",
    Content = "Autonomous Zero-to-Hero Speedrun Engine [AUTOPROG] is active!",
    Duration = 4
})
