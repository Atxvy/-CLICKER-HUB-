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
--   - Priority 1: Desert Machine & Rebirth Shop gem upgrades maxing
--   - Priority 2: Skill Tree Coins First (Volcano <-> Heaven breakables alternation) -> Tech Coins Tree
--
-- • PHASE 3 (??? Secret Area Questline Solver):
--   - Auto accept quest at Spawn Door
--   - Step 1: Click 3,500 Times
--   - Step 2: Collect 10 Feathers across maps via instant touch interest
--   - Step 3: Craft 15 Golden Pets (hatches & crafts)
--   - Step 4: Hatch 2,500 Eggs (dynamic auto hatch)
--   - Step 5: Unlocks Dominus Secret Door and triggers Phase 4
--
-- • PHASE 4 (Endgame Matrix Mythic Pipeline):
--   - Auto open Matrix Egg (highest endgame egg in Tech World)
--   - Mythic Only Filter: Delete all non-mythic pets
--   - Auto craft Golden Mythics & Rainbow Mythics
--   - Auto claim finished Rainbow pets
--   - Equip 100% full Rainbow Mythic team
--   - 10 Qi Rebirth goal & Magma click skin (+4 Egg Hatch, +20% Speed)
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

-- Suppress game black shade & disable egg animation
pcall(ProgAPI.SuppressBlackShade)
pcall(ProgAPI.DisableEggAnimation)

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
    pcall(function()
        if ProgAPI and ProgAPI.SetBlackScreen then ProgAPI.SetBlackScreen(false) end
        if ProgAPI and ProgAPI.SetRemoveMaps then ProgAPI.SetRemoveMaps(false) end
    end)
    if _G.ClickerSimulatorAutoProgWindow then
        pcall(function() _G.ClickerSimulatorAutoProgWindow:Destroy() end)
    end
end

-- Load state from Configs
local State = Configs.Load()
if State.OptimizeGameSettings == nil then State.OptimizeGameSettings = true end
_G.State = State
_G.ProgAPI = ProgAPI
_G.AutoProgAPI = AutoProgAPI

--==============================================================================
-- UI INITIALIZATION
--==============================================================================
local Window = UILibrary:CreateWindow({
    Title = "CLICKER HUB • CLICKER SIMULATOR",
    SubTitle = "Auto Progression • Zero To Hero",
    Subtitle = "Auto Progression • Zero To Hero",
    Size = UDim2.fromOffset(700, 520),
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
local CurrentlyDoingCard = DashTab:AddParagraph({
    Title = "Currently Doing:",
    Content = "Evaluating Activity...",
    TitleSize = 17,
    BodySize = 15,
    Height = 65
})
_G.ClickerSimulatorCurrentlyDoingCard = CurrentlyDoingCard

local LiveStatusCard = DashTab:AddParagraph({
    Title = "Progression Telemetry",
    Content = "Initializing...",
    TitleSize = 16,
    BodySize = 14,
    Height = 185
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
-- 3. PHASE 2: ENDGAME PREPARATION TAB
--==============================================================================
local Phase2Tab = Window:AddTab({ Title = "Phase 2: Endgame Prep", Icon = "👑" })

Phase2Tab:AddSection("PHASE 2 SETTINGS (ENDGAME PREPARATION)")
Phase2Tab:AddParagraph({
    Title = "Endgame Preparation Order",
    Content = "1st: Desert Gem Machine & Rebirth Shop Maxing\n" ..
              "2nd: Skill Tree Coins First (??? Dominus Area) -> Tech Coins Tree (Matrix)\n" ..
              "Once Skill Tree is 100% complete, Phase 3 (Matrix Mythic Pipeline) activates automatically!"
})

Phase2Tab:AddToggle("AutoDesertMachineToggle_P2", {
    Title = "1st: Desert Machine & Gem Upgrades Maxing",
    Description = "Maxes out Desert machine perks and rebirth milestone buttons",
    Default = State.AutoDesertMachine,
    Callback = function(val) State.AutoDesertMachine = val; Configs.Set("AutoDesertMachine", val) end
})

Phase2Tab:AddToggle("AutoSkillTreeToggle_P2", {
    Title = "2nd: Skill Tree (??? Dominus Area -> Tech Matrix)",
    Description = "Grinds ??? Dominus Area for Coins perks, then advances to Matrix for Tech Coins",
    Default = State.AutoSkillTree,
    Callback = function(val) State.AutoSkillTree = val; Configs.Set("AutoSkillTree", val) end
})

Phase2Tab:AddToggle("AutoPrestigeToggle_P2", {
    Title = "Auto Prestige (When Available)",
    Description = "Automatically triggers Prestige when Rebirths requirement is met, adapting progression smoothly",
    Default = State.AutoPrestige,
    Callback = function(val) State.AutoPrestige = val; Configs.Set("AutoPrestige", val) end
})

--==============================================================================
-- 4. PHASE 3: ??? SECRET QUEST & DOMINUS FORTUNE TAB
--==============================================================================
local Phase3Tab = Window:AddTab({ Title = "Phase 3: ??? & Dominus", Icon = "🗝️" })

Phase3Tab:AddSection("PHASE 3 SETTINGS (??? QUEST & DOMINUS FORTUNE)")
Phase3Tab:AddParagraph({
    Title = "Phase 3 Strategy",
    Content = "Activates automatically after Phase 2 (Skill Tree 100% complete)!\n" ..
              "• Automatically accepts the ??? Quest at Spawn Door\n" ..
              "• Step 1: Click 3,500 Times (high speed auto-clicks)\n" ..
              "• Step 2: Collect 10 Feathers across maps (instant touch interest)\n" ..
              "• Step 3: Hatches BasicEgg from World 1 Spawn to craft 15 Golden Pets\n" ..
              "• Step 4: Hatches 2,500 Eggs using BasicEgg from World 1 Spawn\n" ..
              "• Step 5: Teleports to Spawn Door, unlocks & enters Dominus Area\n" ..
              "• Step 6: Farms Dominus breakables & completes all 3 Dominus Fortune upgrades (80B + 200B + 400B Coins)\n" ..
              "• Step 7: Transitions to Phase 4 (Matrix Mythics) once Dominus Fortune is complete (3/3)!"
})

local Phase3ProgressCard = Phase3Tab:AddParagraph({
    Title = "??? Quest & Dominus Fortune Status",
    Content = "Evaluating...",
    TitleSize = 16,
    BodySize = 13,
})
_G.ClickerSimulatorPhase3ProgressCard = Phase3ProgressCard

Phase3Tab:AddToggle("AutoSecretQuestToggle", {
    Title = "Enable Phase 3 Automation",
    Description = "Automatically completes ??? quests, unlocks door, and farms Dominus Fortune",
    Default = State.AutoSecretQuest ~= false,
    Callback = function(val) State.AutoSecretQuest = val; Configs.Set("AutoSecretQuest", val) end
})

Phase3Tab:AddToggle("AutoCollectFeathersToggle", {
    Title = "Auto Collect Feathers",
    Description = "Automatically gathers all 10 feathers required for the secret quest",
    Default = State.AutoCollectFeathers ~= false,
    Callback = function(val) State.AutoCollectFeathers = val; Configs.Set("AutoCollectFeathers", val) end
})

Phase3Tab:AddToggle("AutoSecretCraftGoldenToggle", {
    Title = "Auto Craft Golden Pets (BasicEgg)",
    Description = "Hatches BasicEgg from Spawn and crafts 15 Golden pets to complete quest requirement",
    Default = State.AutoSecretCraftGolden ~= false,
    Callback = function(val) State.AutoSecretCraftGolden = val; Configs.Set("AutoSecretCraftGolden", val) end
})

Phase3Tab:AddToggle("AutoUnlockSecretDoorToggle", {
    Title = "Auto Unlock & Enter Dominus Door",
    Description = "Teleports to Spawn Door, unlocks secret door, and enters Dominus Area",
    Default = State.AutoUnlockSecretDoor ~= false,
    Callback = function(val) State.AutoUnlockSecretDoor = val; Configs.Set("AutoUnlockSecretDoor", val) end
})

Phase3Tab:AddToggle("AutoDominusFortuneToggle", {
    Title = "Auto Farm Dominus Fortune (3 Upgrades)",
    Description = "Grinds breakables in Dominus Area and purchases Dominus Hatch, Dominus Luck, and Secret Seeker",
    Default = State.AutoDominusFortune ~= false,
    Callback = function(val) State.AutoDominusFortune = val; Configs.Set("AutoDominusFortune", val) end
})

--==============================================================================
-- 5. PHASE 4: MATRIX MYTHICS TAB
--==============================================================================
local Phase4Tab = Window:AddTab({ Title = "Phase 4: Matrix Mythics", Icon = "🧬" })

Phase4Tab:AddSection("PHASE 4 SETTINGS (ENDGAME MATRIX MYTHIC PIPELINE)")
Phase4Tab:AddParagraph({
    Title = "Phase 4 Strategy",
    Content = "Activates automatically after Phase 3 (??? Secret Quest) is 100% complete!\n" ..
              "• Auto Open Matrix Egg (highest endgame egg in Tech World)\n" ..
              "• Rebirth at Max Milestone Only (preserves clicks for Matrix Egg)\n" ..
              "• Mythic Pet Filter: Deletes all non-mythic pets (Common/Rare/Epic/Legendary) and weak pets\n" ..
              "• Auto Crafts Golden Mythics & Rainbow Mythics\n" ..
              "• Equips best pets as Rainbow Mythics are created, replacing old pets until team is 100% Rainbow Mythics!"
})

Phase4Tab:AddToggle("AutoMatrixEggToggle_P4", {
    Title = "Auto Open Matrix Egg",
    Description = "Continuously hatches Matrix Egg on Matrix Island in Tech World",
    Default = State.AutoMatrixEgg,
    Callback = function(val) State.AutoMatrixEgg = val; Configs.Set("AutoMatrixEgg", val) end
})

Phase4Tab:AddToggle("AutoMythicFilterToggle_P4", {
    Title = "Keep Mythic & Above (Delete Non-Mythic)",
    Description = "Strictly keeps Mythic, Secret, Mega, Divine, and Exclusive pets; deletes Common, Rare, Epic, Legendary",
    Default = State.AutoMythicFilter,
    Callback = function(val) State.AutoMythicFilter = val; Configs.Set("AutoMythicFilter", val) end
})

Phase4Tab:AddToggle("AutoCraftMythicsToggle_P4", {
    Title = "Auto Craft Golden & Rainbow Mythics",
    Description = "Automatically crafts Golden and Rainbow versions of Mythic pets",
    Default = State.AutoCraftMythics,
    Callback = function(val) State.AutoCraftMythics = val; Configs.Set("AutoCraftMythics", val) end
})

Phase4Tab:AddToggle("AutoReplaceTeamToggle_P4", {
    Title = "Auto Replace Team with Rainbow Mythics",
    Description = "Equips best pets as Rainbow Mythics are forged, replacing weaker old pets",
    Default = State.AutoReplaceTeam,
    Callback = function(val) State.AutoReplaceTeam = val; Configs.Set("AutoReplaceTeam", val) end
})

Phase4Tab:AddToggle("PauseRebirthToggle_P4", {
    Title = "Rebirth at Max Milestone Only",
    Description = "Waits until no more Next Rebirth button, then rebirths to the max affordable milestone",
    Default = (State.PauseRebirthPhase4 ~= nil) and State.PauseRebirthPhase4 or State.PauseRebirthPhase3,
    Callback = function(val) State.PauseRebirthPhase4 = val; State.PauseRebirthPhase3 = val; Configs.Set("PauseRebirthPhase4", val) end
})

Phase4Tab:AddToggle("AutoRainbowClaimToggle_P4", {
    Title = "Auto Claim Rainbow Pets",
    Description = "Automatically collects finished pets from the Rainbow Machine",
    Default = State.AutoRainbowClaim,
    Callback = function(val) State.AutoRainbowClaim = val; Configs.Set("AutoRainbowClaim", val) end
})

Phase4Tab:AddToggle("AutoMagmaSkinToggle_P4", {
    Title = "10 Qi Rebirth Goal & Magma Click Skin",
    Description = "Monitors 10 Qi Rebirth milestone and equips Magma Click Skin (+4 Egg Hatch, +20% Speed)",
    Default = State.AutoMagmaSkin,
    Callback = function(val) State.AutoMagmaSkin = val; Configs.Set("AutoMagmaSkin", val) end
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

--==============================================================================
-- 6. MISC TAB
--==============================================================================
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "⚙️" })

MiscTab:AddSection("PERFORMANCE & CPU SAVER")
local blackScreenToggleObj
blackScreenToggleObj = MiscTab:AddToggle("BlackScreenToggle", {
    Title = "Black Screen / 3D Render Off (Save CPU & Memory)",
    Description = "Disables 3D engine rendering and displays centered Clicker Hub live telemetry & session overlay",
    Default = State.BlackScreen,
    Callback = function(val)
        if State.BlackScreen == val then return end
        State.BlackScreen = val
        Configs.Set("BlackScreen", val)
        AutoProgAPI.SetBlackScreen(val)
    end
})

AutoProgAPI.OnBlackScreenToggled = function(val)
    State.BlackScreen = val
    Configs.Set("BlackScreen", val)
    if blackScreenToggleObj and blackScreenToggleObj.SetValue then
        pcall(function() blackScreenToggleObj:SetValue(val) end)
    end
end

MiscTab:AddToggle("RemoveMapsToggle", {
    Title = "Remove Maps (FPS & Memory Booster)",
    Description = "Hides map decor, scenery, and non-critical props to maximize FPS and free RAM",
    Default = State.RemoveMaps,
    Callback = function(val)
        State.RemoveMaps = val
        Configs.Set("RemoveMaps", val)
        AutoProgAPI.SetRemoveMaps(val)
    end
})

MiscTab:AddToggle("OptimizeGameSettingsToggle", {
    Title = "Disable In-Game Visuals & Performance Settings",
    Description = "Turns on Potato Mode, hides other/own pets, hides crits, hides popups, transparent pets, and disables server messages",
    Default = State.OptimizeGameSettings,
    Callback = function(val)
        State.OptimizeGameSettings = val
        Configs.Set("OptimizeGameSettings", val)
        AutoProgAPI.SetDisableInGameSettings(val)
    end
})

MiscTab:AddSection("DISCORD WEBHOOK NOTIFICATIONS")
MiscTab:AddToggle("WebhookEnabledToggle", {
    Title = "Secret & Above Hatch Webhook",
    Description = "Sends Discord webhook notifications when Secret, Mega, Divine, or Exclusive pets are hatched (Mythics ignored)",
    Default = State.WebhookEnabled,
    Callback = function(val)
        State.WebhookEnabled = val
        Configs.Set("WebhookEnabled", val)
        AutoProgAPI.WebhookEnabled = val
    end
})

MiscTab:AddInput("WebhookUrlInput", {
    Title = "Discord Webhook URL",
    Description = "Paste your Discord webhook URL to receive instant rare pet alerts",
    Default = State.WebhookUrl or "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(val)
        State.WebhookUrl = val
        Configs.Set("WebhookUrl", val)
        AutoProgAPI.WebhookUrl = val
    end
})

MiscTab:AddButton({
    Title = "Send Test Webhook Notification",
    Description = "Sends a sample Secret pet hatch notification to test your Discord webhook",
    Callback = function()
        AutoProgAPI.WebhookUrl = State.WebhookUrl
        AutoProgAPI.WebhookEnabled = State.WebhookEnabled
        local ok, msg = AutoProgAPI.SendTestWebhook()
        if ok then
            Window:Notify({ Title = "Webhook Success", Content = "Test webhook notification sent successfully! Check your Discord channel.", Duration = 4 })
        else
            Window:Notify({ Title = "Webhook Failed", Content = msg or "Failed to send test webhook", Duration = 5 })
        end
    end
})

MiscTab:AddSection("BIG CHESTS AUTOMATION")
MiscTab:AddToggle("AttackBigChestsToggle_Misc", {
    Title = "Attack Big Chests (Heaven Giant Chest & Hell Chest)",
    Description = "Prioritizes the Heaven Giant Chest in HugeHeavenChest and auto-claims Hell Chest",
    Default = State.AttackBigChests,
    Callback = function(val)
        State.AttackBigChests = val
        Configs.Set("AttackBigChests", val)
    end
})

MiscTab:AddButton({
    Title = "Claim All Map Chests Now",
    Description = "Directly touches and claims Hell Chest, Grand Chest, and Beach Chest hitboxes",
    Callback = function()
        local count = AutoProgAPI.ClaimAllChests()
        Window:Notify({ Title = "Chests", Content = string.format("Claimed %d map chest(s)!", count), Duration = 3 })
    end
})

-- Startup code & gifts claim
task.spawn(function()
    AutoProgAPI.WebhookUrl = State.WebhookUrl or ""
    AutoProgAPI.WebhookEnabled = State.WebhookEnabled ~= false
    task.wait(1.5)
    pcall(AutoProgAPI.CheckAndSelectStarterPet)
    pcall(AutoProgAPI.RedeemAllCodes)
    pcall(AutoProgAPI.ClaimAllFreeGifts)
    pcall(AutoProgAPI.ClaimCompletedQuests)
    pcall(AutoProgAPI.ClaimDaily)
    pcall(AutoProgAPI.ClaimAllChests)
    pcall(AutoProgAPI.EquipBest)
    if State.BlackScreen then pcall(AutoProgAPI.SetBlackScreen, true) end
    if State.RemoveMaps then pcall(AutoProgAPI.SetRemoveMaps, true) end
    if State.OptimizeGameSettings ~= false then pcall(AutoProgAPI.SetDisableInGameSettings, true) end
end)

-- Rejoin & Startup Teleport Guarantee: Positions player according to current phase
task.spawn(function()
    task.wait(1.8)
    pcall(function()
        if AutoProgAPI.IsPhase4 and AutoProgAPI.IsPhase4() then
            local pData = AutoProgAPI.GetPlayerData()
            local curWorld = pData.CurrentWorld or "Overworld"
            if curWorld ~= "Techworld" and curWorld ~= "Space" then
                AutoProgAPI.TeleportToWorld("Techworld")
                task.wait(0.5)
                AutoProgAPI.TeleportToEgg("MatrixEgg")
            end
            return
        end

        if AutoProgAPI.IsPhase3 and AutoProgAPI.IsPhase3() then
            local qInfo = AutoProgAPI.GetSecretQuestInfo and AutoProgAPI.GetSecretQuestInfo()
            if qInfo and qInfo.IsDoorUnlocked then
                -- Door is unlocked: enter Dominus Area to farm Dominus Fortune!
                AutoProgAPI.EnterDominusArea()
            end
            return
        end

        local pData = AutoProgAPI.GetPlayerData()
        local lockedIsland = AutoProgAPI.GetNextLockedIsland()
        if lockedIsland == nil and State.AutoSkillTree then
            local qProg = AutoProgAPI.GetSecretQuestProgress()
            if State.AutoSecretQuest and not qProg.DoorUnlocked then
                -- Door not unlocked yet, let StepSecretQuest handle positioning
                return
            end
            local stProg = AutoProgAPI.GetSkillTreeProgress()
            local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 36)
            local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
            if not coinsDone then
                if qProg and qProg.DoorUnlocked then
                    AutoProgAPI.TeleportToIsland("DominusArea")
                else
                    AutoProgAPI.TeleportToWorld("Overworld")
                    AutoProgAPI.TeleportToIsland("Heaven")
                    task.wait(0.4)
                    AutoProgAPI.TeleportToBreakableZone("Heaven")
                end
            elseif not techDone then
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

-- THREAD 2: DEDICATED CONTINUOUS REBIRTH ENGINE
-- Phase 1, 2, 3: Rebirth as long as affordable (RebirthBestAffordable)
-- Phase 4: Max Rebirth only (RebirthMaxTarget)
table.insert(threads, task.spawn(function()
    local lastRebirthAttempt = 0
    while isRunning do
        task.wait(0.12)
        if not State.MasterEnabled or not State.AutoMaxRebirth or not isRunning then continue end

        local now = tick()
        if now - lastRebirthAttempt > 0.25 then
            lastRebirthAttempt = now

            local isP4 = AutoProgAPI.IsPhase4 and AutoProgAPI.IsPhase4()
            if isP4 then
                -- Phase 4: Rebirth at MAX milestone only
                pcall(AutoProgAPI.RebirthMaxTarget)
            else
                -- Phase 1, Phase 2, Phase 3: Rebirth as long as they can afford it
                pcall(AutoProgAPI.RebirthBestAffordable)
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
-- THREAD 12: DEDICATED AUTO PRESTIGE THREAD (Strict Phase 2 requirement: All islands unlocked)
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(2)
        if isRunning and State.MasterEnabled and State.AutoPrestige then
            local prestInfo = AutoProgAPI.GetPrestigeInfo()
            if prestInfo and not prestInfo.MaxPrestigeReached and prestInfo.CanPrestige then
                if AutoProgAPI.AreAllIslandsUnlocked() then
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

        local isP3 = AutoProgAPI.IsPhase3 and AutoProgAPI.IsPhase3()
        if isP3 then
            task.wait(0.5)
            continue
        end

        local allIslands = AutoProgAPI.AreAllIslandsUnlocked()
        local stProg = AutoProgAPI.GetSkillTreeProgress()
        local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 36)
        local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
        local isSkillTreeMaxed = coinsDone and techDone

        -- Runs in Phase 2 until Skill Tree is fully maxed! (Farms Dominus Area for Coins -> Tech World for Tech Coins)
        if allIslands and (not isSkillTreeMaxed) and State.AutoSkillTree then
            local now = tick()
            if now - lastBreakableTick >= 0.05 then
                lastBreakableTick = now

                -- If Coins skill tree is done, make sure we are in Tech World!
                if coinsDone and not techDone then
                    local pData = AutoProgAPI.GetPlayerData()
                    local curWorld = pData.CurrentWorld or "Overworld"
                    if AutoProgAPI.IsInMinigame() or (curWorld ~= "Techworld" and curWorld ~= "Space") then
                        AutoProgAPI.ExitMinigame()
                        AutoProgAPI.TeleportToWorld("Techworld")
                        task.wait(0.4)
                    end
                end

                local action, targetIsl = AutoProgAPI.StepBreakablesPipeline(false)
                if coinsDone then
                    if action then
                        currentActivity = string.format("[Tech Skill Tree] %s in %s", tostring(action), tostring(targetIsl or "Matrix"))
                    else
                        currentActivity = string.format("[Tech Skill Tree] Farming Breakables in %s", tostring(targetIsl or "Matrix"))
                    end
                else
                    if action then
                        currentActivity = string.format("[Skill Tree] %s in %s", tostring(action), tostring(targetIsl or "DominusArea"))
                    else
                        currentActivity = "[Skill Tree] Farming Breakables in Dominus Area"
                    end
                end
            end
        end
    end
end))

-- THREAD 14: MAIN PROGRESSION STATE MACHINE (Step 1 / Phase 1 vs Phase 2)
table.insert(threads, task.spawn(function()
    local lastTeleportTick = 0
    local lastEggHatchTick = 0
    local isEggHatching = false
    local lastEggHatchStartTick = 0
    local lastSkinTick = 0
    local lastQuestTick = 0
    local lastFurthestTpTick = 0

    while isRunning do
        task.wait(0.05)
        if not State.MasterEnabled or not isRunning then continue end
        pcall(function()
            local now = tick()

            -- WATCHDOG: If egg hatching task hangs or takes > 3.5s, force unlock to prevent stalls
            if isEggHatching and (now - lastEggHatchStartTick > 3.5) then
                isEggHatching = false
            end

            -- Respect server rate-limiter backoff
            if now < (AutoProgAPI.HatchBackoffUntil or 0) then
                return
            end

            local pData = AutoProgAPI.GetPlayerData()
            local allIslandsUnlocked = AutoProgAPI.AreAllIslandsUnlocked()
            local lockedIsland = AutoProgAPI.GetNextLockedIsland()
            local isAllGold = AutoProgAPI.IsEquippedTeamAllGold()
            local isAllRainbow = AutoProgAPI.IsEquippedTeamAllRainbow()
            local isSkillTreeDone = AutoProgAPI.IsSkillTreeMaxed and AutoProgAPI.IsSkillTreeMaxed()
            local isSecretQuestDone = AutoProgAPI.IsSecretQuestComplete and AutoProgAPI.IsSecretQuestComplete()
            local isDominusFortuneDone = AutoProgAPI.IsDominusFortuneComplete and AutoProgAPI.IsDominusFortuneComplete()
            local isP3 = AutoProgAPI.IsPhase3 and AutoProgAPI.IsPhase3()
            local isP4 = AutoProgAPI.IsPhase4 and AutoProgAPI.IsPhase4()

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
                local isSafeEgg = bestEgg and (bestEgg.name ~= "BasicEgg" or pData.CurrentIsland == "Spawn")
                local shouldHatch = (State.AutoBestEggs or State.AutoGold) and (not isAllGold) and canAffordBestEgg and isSafeEgg

                -- 1. Auto Teleport to furthest unlocked island (For best click multiplier when not hatching!)
                if not shouldHatch and (now - lastTeleportTick > 3) then
                    lastTeleportTick = now
                    local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                    if pData.CurrentIsland ~= furthest then
                        AutoProgAPI.TeleportToIsland(furthest)
                    end
                end

                if not shouldHatch and lockedIsland and pData.Clicks < lockedIsland.cost then
                    currentActivity = string.format("[Phase 1] Speedrunning Clicks for %s (%s / %s)", lockedIsland.name, AutoProgAPI.FormatNumber(pData.Clicks), AutoProgAPI.FormatNumber(lockedIsland.cost))
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
                local hatchDelay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed(bestEgg and bestEgg.name)) or 2.5
                if (State.AutoBestEggs or State.AutoGold) and not isEggHatching and (now - lastEggHatchTick >= hatchDelay) then
                    lastEggHatchTick = now
                    local isNearUnlock = lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.75)

                    -- If team is not yet all gold, hatch best affordable egg!
                    if not isAllGold and canAffordBestEgg and isSafeEgg then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount(bestEgg.name)
                        currentActivity = string.format("[Phase 1] Hatching %dx %s on %s for Golden Team", hatchAmount, bestEgg.name, bestEgg.island)
                        isEggHatching = true
                        lastEggHatchStartTick = now
                        task.spawn(function()
                            pcall(function()
                                AutoProgAPI.OpenEgg(bestEgg.name, hatchAmount, true)
                                pcall(AutoProgAPI.CraftGoldenPets)
                                pcall(AutoProgAPI.EquipBest)
                            end)
                            isEggHatching = false
                        end)
                    elseif not isNearUnlock and State.AutoBestEggs and canAffordBestEgg and isSafeEgg then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount(bestEgg.name)
                        currentActivity = string.format("[Phase 1] Hatching %dx %s on %s", hatchAmount, bestEgg.name, bestEgg.island)
                        isEggHatching = true
                        lastEggHatchStartTick = now
                        task.spawn(function()
                            pcall(function()
                                AutoProgAPI.OpenEgg(bestEgg.name, hatchAmount, true)
                                pcall(AutoProgAPI.CraftGoldenPets)
                                pcall(AutoProgAPI.EquipBest)
                            end)
                            isEggHatching = false
                        end)
                    end
                end

            -- =====================================================================
            -- PHASE 2: ENDGAME PREPARATION
            -- Condition: All 17 islands unlocked, but Skill Tree is NOT yet maxed!
            -- Order:
            -- 1. Desert Gem Machine & Rebirth Shop Maxing (Thread 8 & 9)
            -- 2. Max Skill Tree (Dominus Area for Coins -> Matrix for Tech Coins) (Thread 13)
            -- =====================================================================
            elseif not isSkillTreeDone then
                currentPhaseText = "👑 PHASE 2: ENDGAME PREPARATION"
                -- Thread 13 handles breakables and skill tree purchasing.

            -- =====================================================================
            -- PHASE 3: ??? SECRET AREA QUEST & DOMINUS FORTUNE GRIND
            -- Condition: All 17 islands unlocked, Base Skill Tree 100% maxed, but Dominus Fortune not complete!
            -- Flow:
            -- 1. Accept Quest at Spawn Door
            -- 2. Click 3,500 Times
            -- 3. Collect 10 Feathers across maps
            -- 4. Hatches BasicEgg from World 1 Spawn to craft 15 Golden Pets
            -- 5. Hatches 2,500 Eggs using BasicEgg from World 1 Spawn
            -- 6. Teleports to Spawn Door, unlocks & enters Dominus Area
            -- 7. Farms Dominus breakables & buys 3 Dominus Fortune upgrades:
            --    - DominusEggHatch (80B Coins)
            --    - DominusEggLuck (200B Coins)
            --    - DominusSecretSeeker (400B Coins)
            -- Once 3/3 complete -> Transitions to Phase 4!
            -- =====================================================================
            elseif not isDominusFortuneDone then
                currentPhaseText = "🗝️ PHASE 3: ??? & DOMINUS FORTUNE"
                local qInfo = AutoProgAPI.GetSecretQuestInfo and AutoProgAPI.GetSecretQuestInfo()
                local isQuestComplete = (qInfo and qInfo.IsDoorUnlocked and qInfo.AllQuestsDone) or (isSecretQuestDone)

                if not isQuestComplete then
                    -- Quest in progress: hatch BasicEgg paced at player hatch speed
                    local p3Delay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed("BasicEgg")) or 0.5
                    if State.AutoSecretQuest ~= false and not isEggHatching and (now - lastEggHatchTick >= p3Delay) then
                        lastEggHatchTick = now
                        isEggHatching = true
                        lastEggHatchStartTick = now
                        task.spawn(function()
                            local pcallOk, stepSuccess, stepMsg = pcall(AutoProgAPI.StepSecretQuest)
                            if pcallOk and stepMsg and type(stepMsg) == "string" then
                                currentActivity = tostring(stepMsg)
                            elseif pcallOk and type(stepSuccess) == "string" then
                                currentActivity = tostring(stepSuccess)
                            end
                            isEggHatching = false
                        end)
                    end
                else
                    -- Quest & Door complete: fast-paced breakables farming in Dominus Area for Dominus Fortune!
                    if State.AutoSecretQuest ~= false and (now - lastEggHatchTick >= 0.05) then
                        lastEggHatchTick = now
                        task.spawn(function()
                            local pcallOk, stepSuccess, stepMsg = pcall(AutoProgAPI.StepSecretQuest)
                            if pcallOk and stepMsg and type(stepMsg) == "string" then
                                currentActivity = tostring(stepMsg)
                            elseif pcallOk and type(stepSuccess) == "string" then
                                currentActivity = tostring(stepSuccess)
                            end
                        end)
                    end
                end

            -- =====================================================================
            -- PHASE 4: ENDGAME MATRIX MYTHIC PIPELINE
            -- Condition: All 17 islands unlocked, Base Skill Tree maxed, ??? Quest done, AND Dominus Fortune maxed!
            -- Strategy:
            -- 1. Auto Open Matrix Egg (highest endgame egg in Tech World)
            -- 2. Max Rebirth Only (Thread 2 fires at Max milestone button)
            -- 3. Mythic Only Filter: Delete all non-mythic pets & old weak pets!
            -- 4. Auto Craft Golden Mythics & Rainbow Mythics
            -- 5. Gradually replaces equipped team until 100% Rainbow Mythics!
            -- =====================================================================
            else
                currentPhaseText = "🧬 PHASE 4: MATRIX MYTHIC PIPELINE"

                local curWorld = pData.CurrentWorld or "Overworld"
                if AutoProgAPI.IsInMinigame() or (curWorld ~= "Techworld" and curWorld ~= "Space") then
                    AutoProgAPI.ExitMinigame()
                    task.wait(0.3)
                    currentActivity = "[Phase 4: Matrix] Teleporting to Tech World..."
                    AutoProgAPI.TeleportToWorld("Techworld")
                    task.wait(0.5)
                    AutoProgAPI.TeleportToEgg("MatrixEgg")
                    task.wait(0.5)
                    return
                end

                local curIsland = pData.CurrentIsland or ""
                if curIsland ~= "Matrix" then
                    currentActivity = "[Phase 4: Matrix] Teleporting to Matrix Island..."
                    AutoProgAPI.TeleportToEgg("MatrixEgg")
                    task.wait(0.5)
                    return
                end

                local isAllRainbowMythic, mythicCount, totalSlots = AutoProgAPI.IsEquippedTeamAllRainbowMythic()
                local hatchDelay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed("MatrixEgg")) or 1.9

                -- 1. Auto Open Matrix Egg (runs non-blocking in task.spawn without client animations)
                if State.AutoMatrixEgg and not isEggHatching and (now - lastEggHatchTick >= hatchDelay) then
                    lastEggHatchTick = now
                    local matrixCost = 2.5e25
                    local eggModel, targetPart = AutoProgAPI.FindEggModel("MatrixEgg")
                    local char = game:GetService("Players").LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local dist = (hrp and targetPart) and (hrp.Position - targetPart.Position).Magnitude or 999

                    if dist > 16 and targetPart and hrp then
                        hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.08)
                    elseif dist > 20 then
                        currentActivity = "[Phase 4: Matrix] Teleporting to Matrix Egg in Tech World..."
                        AutoProgAPI.TeleportToEgg("MatrixEgg")
                        task.wait(0.3)
                    end

                    if pData.Clicks >= matrixCost then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount("MatrixEgg")
                        currentActivity = string.format("[Phase 4: Matrix] Hatching %dx MatrixEgg (Mythic Hunt)...", hatchAmount)
                        isEggHatching = true
                        lastEggHatchStartTick = now
                        task.spawn(function()
                            pcall(function()
                                -- Proactive cleanup BEFORE open to guarantee free slots!
                                if State.AutoMythicFilter then
                                    pcall(AutoProgAPI.CleanNonMythicPets)
                                end
                                AutoProgAPI.OpenEgg("MatrixEgg", hatchAmount, true)

                                -- 2. Mythic Pet Filter & Cleaner: Delete non-mythics and old weak pets
                                if State.AutoMythicFilter then
                                    pcall(AutoProgAPI.CleanNonMythicPets)
                                end

                                -- 3. Auto Craft Golden & Rainbow Mythics
                                if State.AutoCraftMythics then
                                    pcall(AutoProgAPI.CraftGoldenPets)
                                    pcall(AutoProgAPI.CraftRainbowPets)
                                    pcall(AutoProgAPI.ClaimRainbowPets)
                                end

                                -- 4. Auto Replace Team with Mythics
                                if State.AutoReplaceTeam then
                                    pcall(AutoProgAPI.EquipBest)
                                end
                            end)
                            isEggHatching = false
                        end)
                    else
                        -- Not enough clicks yet for Matrix Egg: Stay directly on Matrix Egg to click & hatch!
                        if dist > 16 and targetPart and hrp then
                            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                        end
                        currentActivity = string.format("[Phase 4: Matrix] Speedrunning Clicks for Matrix Egg (%s / %s)", AutoProgAPI.FormatNumber(pData.Clicks), "25.00Sp")
                    end
                end

                -- Periodically clean non-mythics and old weak pets
                if State.AutoMythicFilter and (now - lastFurthestTpTick > 5) then
                    lastFurthestTpTick = now
                    pcall(AutoProgAPI.CleanNonMythicPets)
                    if State.AutoCraftMythics then
                        pcall(AutoProgAPI.ClaimRainbowPets)
                    end
                    if State.AutoReplaceTeam then
                        pcall(AutoProgAPI.EquipBest)
                    end
                end

                if isAllRainbowMythic then
                    currentActivity = string.format("🌟 [Phase 4: Complete] Team 100%% Rainbow Mythic (%d/%d)!", mythicCount, totalSlots)
                end

                -- 10 Qi Rebirth Goal & Magma Click Skin
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

        -- 1. Dedicated Currently Doing Display Card
        AutoProgAPI.CurrentActivity = currentActivity or "Auto Progression Active"
        AutoProgAPI.CurrentPhase = currentPhaseText or "Evaluating..."

        if CurrentlyDoingCard then
            local doingTitle = "Currently Doing:"
            local doingContent = string.format("⚡ <b>Activity:</b> %s\n🎯 <b>Phase:</b> %s",
                tostring(currentActivity or "Auto Progression Active"),
                tostring(currentPhaseText or "Evaluating...")
            )
            CurrentlyDoingCard:Set({
                Title = doingTitle,
                Content = doingContent
            })
            if CurrentlyDoingCard.TitleLabel then
                pcall(function() CurrentlyDoingCard.TitleLabel.Text = doingTitle end)
            end
            if CurrentlyDoingCard.BodyLabel then
                pcall(function() CurrentlyDoingCard.BodyLabel.Text = doingContent end)
            end
        end

        local qInfo = ProgAPI.GetSecretQuestInfo and ProgAPI.GetSecretQuestInfo()
        local questStr = qInfo and (qInfo.IsDoorUnlocked and "🔓 Dominus Door Unlocked!" or tostring(qInfo.CurrentStep)) or "N/A"

        -- 2. Statistical Progression Telemetry Card
        local cardTitle = "Progression Telemetry"
        local cardContent = string.format(
            "⚡ <b>Clicks:</b> %s  |  <b>Rebirths:</b> %s\n" ..
            "💎 <b>Gems:</b> %s  |  <b>Coins:</b> %s  |  <b>Tech Coins:</b> %s\n" ..
            "🚀 <b>Prestige:</b> %s\n" ..
            "🏝️ <b>Islands:</b> %s\n" ..
            "🐾 <b>Pet Team:</b> %s\n" ..
            "🌳 <b>Skill Tree:</b> %s\n" ..
            "🗝️ <b>??? Quest:</b> %s\n" ..
            "🔥 <b>Magma Skin:</b> %s",
            ProgAPI.FormatNumber(pData.Clicks or 0),
            ProgAPI.FormatNumber(pData.Rebirths or 0),
            ProgAPI.FormatNumber(pData.Gems or 0),
            ProgAPI.FormatNumber(pData.Coins or 0),
            ProgAPI.FormatNumber(pData.SpaceCoins or 0),
            tostring(prestStr),
            tostring(islandProgressStr),
            tostring(teamStr),
            tostring(stStr),
            tostring(questStr),
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

        if Phase3ProgressCard then
            local domProg = AutoProgAPI.GetDominusFortuneProgress and AutoProgAPI.GetDominusFortuneProgress()
            local curStats = (AutoProgAPI.GetPlayerData and AutoProgAPI.GetPlayerData()) or {}
            local coinAmt = (curStats.Currency and curStats.Currency.Coins) or curStats.Coins or 0

            local qContent = ""
            if qInfo then
                qContent = qContent .. string.format(
                    "🎯 <b>Quest Status:</b> %s\n" ..
                    "🖱️ <b>Clicks:</b> %s / %s (%s)\n" ..
                    "🪶 <b>Feathers:</b> %d / %d (%s)\n" ..
                    "⭐ <b>Golden Crafts (BasicEgg):</b> %d / %d (%s)\n" ..
                    "🥚 <b>Hatch Eggs (BasicEgg):</b> %s / %s (%s)\n" ..
                    "🚪 <b>Dominus Door:</b> %s\n",
                    tostring(qInfo.CurrentStep),
                    AutoProgAPI.FormatNumber(qInfo.Clicks.Progress), AutoProgAPI.FormatNumber(qInfo.Clicks.Amount), qInfo.Clicks.Done and "✅" or "⏳",
                    qInfo.Feathers.Progress, qInfo.Feathers.Amount, qInfo.Feathers.Done and "✅" or "⏳",
                    qInfo.Golden.Progress, qInfo.Golden.Amount, qInfo.Golden.Done and "✅" or "⏳",
                    AutoProgAPI.FormatNumber(qInfo.Hatch.Progress), AutoProgAPI.FormatNumber(qInfo.Hatch.Amount), qInfo.Hatch.Done and "✅" or "⏳",
                    qInfo.IsDoorUnlocked and "🔓 UNLOCKED" or (qInfo.AllQuestsDone and "READY TO UNLOCK" or "LOCKED")
                )
            end
            if domProg then
                local nextPerkText = "Maxed (3/3)!"
                if not domProg.HatchOwned then
                    nextPerkText = "Dominus Hatch (80B)"
                elseif not domProg.LuckOwned then
                    nextPerkText = "Dominus Luck (200B)"
                elseif not domProg.SeekerOwned then
                    nextPerkText = "Secret Seeker (400B)"
                end
                qContent = qContent .. string.format(
                    "👑 <b>Dominus Fortune:</b> %d / 3 (%s)\n" ..
                    "  • Dominus Hatch (+1 Pet): %s\n" ..
                    "  • Dominus Luck (+15%%): %s\n" ..
                    "  • Secret Seeker (+10%%): %s\n" ..
                    "💰 <b>Coins:</b> %s (Next: %s)",
                    domProg.BoughtCount, domProg.IsComplete and "✅ COMPLETE" or "FARMING",
                    domProg.HatchOwned and "✅" or "80B",
                    domProg.LuckOwned and "✅" or "200B",
                    domProg.SeekerOwned and "✅" or "400B",
                    AutoProgAPI.FormatNumber(coinAmt),
                    nextPerkText
                )
            end

            Phase3ProgressCard:Set({
                Title = "??? Quest & Dominus Fortune Status",
                Content = qContent
            })
            if Phase3ProgressCard.TitleLabel then
                pcall(function() Phase3ProgressCard.TitleLabel.Text = "??? Quest & Dominus Fortune Status" end)
            end
            if Phase3ProgressCard.BodyLabel then
                pcall(function() Phase3ProgressCard.BodyLabel.Text = qContent end)
            end
        end

        if State.BlackScreen and AutoProgAPI and AutoProgAPI.UpdateBlackScreenTelemetry then
            pcall(AutoProgAPI.UpdateBlackScreenTelemetry)
        end
    end)
    if not ok then
        pcall(function()
            if CurrentlyDoingCard then
                local fallbackDoing = string.format("⚡ <b>Activity:</b> %s\n🎯 <b>Phase:</b> %s", tostring(currentActivity or "Active"), tostring(currentPhaseText or "Phase 2"))
                CurrentlyDoingCard:Set({
                    Title = "Currently Doing:",
                    Content = fallbackDoing
                })
                if CurrentlyDoingCard.TitleLabel then pcall(function() CurrentlyDoingCard.TitleLabel.Text = "Currently Doing:" end) end
                if CurrentlyDoingCard.BodyLabel then pcall(function() CurrentlyDoingCard.BodyLabel.Text = fallbackDoing end) end
            end
            if LiveStatusCard then
                local fallbackTitle = "Progression Telemetry"
                local fallbackBody = string.format("⚡ <b>Running Auto Progression...</b>\n📊 <b>Status:</b> %s", tostring(currentActivity or "Active"))
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

-- Immediate initial telemetry update
pcall(updateTelemetry)

-- Refresh telemetry immediately on startup
task.spawn(function()
    task.wait(0.2)
    pcall(updateTelemetry)
end)

-- THREAD 15: TELEMETRY DISPLAY REFRESH LOOP
table.insert(threads, task.spawn(function()
    pcall(updateTelemetry)
    while isRunning do
        task.wait(0.5)
        if not isRunning then break end
        local ok, err = pcall(updateTelemetry)
        if not ok then
            warn("[AutoProg] updateTelemetry error:", err)
        end
    end
end))

pcall(function()
    if Window then
        if Window.ScreenGui then Window.ScreenGui.Enabled = true end
        if Window.MainFrame then Window.MainFrame.Visible = true end
        if Window.Show then Window:Show() end
    end
end)

pcall(function()
    Window:Notify({
        Title = "Auto Progression Loaded!",
        Content = "Autonomous Zero-to-Hero Speedrun Engine [AUTOPROG] is active!",
        Duration = 4
    })
end)
