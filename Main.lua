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
        if ProgAPI and ProgAPI.StopAntiAFK then ProgAPI.StopAntiAFK() end
        if ProgAPI and ProgAPI.StopAutoRejoin then ProgAPI.StopAutoRejoin() end
    end)
    if _G.ClickerSimulatorAutoProgWindow then
        pcall(function() _G.ClickerSimulatorAutoProgWindow:Destroy() end)
    end
end

-- Load state from Configs (Multi-account isolated profile)
local State = Configs.Load()
if State.OptimizeGameSettings == nil then State.OptimizeGameSettings = true end
if State.AntiAFK == nil then State.AntiAFK = true end
if State.AutoRejoin == nil then State.AutoRejoin = true end
if State.IndexUnlockRainbow == nil or State._RainbowV3Updated ~= true then
    State.IndexUnlockRainbow = true
    State._RainbowV3Updated = true
    Configs.Set("IndexUnlockRainbow", true)
    Configs.Set("_RainbowV3Updated", true)
end
if State.IndexTargetTotal == nil then
    State.IndexTargetTotal = 250
    Configs.Set("IndexTargetTotal", 250)
end
if State.AutoAcceptTrade == nil then
    State.AutoAcceptTrade = true
    Configs.Set("AutoAcceptTrade", true)
end
_G.State = State
_G.ProgAPI = ProgAPI
_G.AutoProgAPI = AutoProgAPI
_G.OpenBank = function() return AutoProgAPI.OpenBank() end
_G.CloseBank = function() return AutoProgAPI.CloseBank() end
_G.ToggleBank = function() return AutoProgAPI.ToggleBank() end

-- Auto-start default resilience features (Anti-AFK & Auto Rejoin enabled by default)
if State.AntiAFK ~= false then
    pcall(AutoProgAPI.StartAntiAFK)
end
if State.AutoRejoin ~= false then
    pcall(AutoProgAPI.StartAutoRejoin)
end
if State.AutoAcceptTrade ~= false then
    pcall(AutoProgAPI.InitAutoTradeListener)
end

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
    Title = "Open Bank GUI",
    Description = "Bypasses FFlags restriction and opens The Bank window to deposit and withdraw tokens and pets",
    Callback = function()
        local ok, msg = AutoProgAPI.OpenBank()
        Window:Notify({ Title = "The Bank", Content = msg or (ok and "Bank Opened!" or "Failed to open Bank"), Duration = 3 })
    end
})
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
-- 3. PHASE 2: ??? SECRET QUEST TAB
--==============================================================================
local Phase2Tab = Window:AddTab({ Title = "Phase 2: ??? Secret Quest", Icon = "🗝️" })

Phase2Tab:AddSection("PHASE 2 SETTINGS (??? SECRET AREA QUEST)")
Phase2Tab:AddParagraph({
    Title = "Phase 2 Strategy",
    Content = "Activates automatically after Phase 1 (All 17 Islands Unlocked)!\n" ..
              "• Automatically accepts the ??? Quest at Spawn Door\n" ..
              "• Step 1: Click 3,500 Times (high speed auto-clicks)\n" ..
              "• Step 2: Collect 10 Feathers across maps (instant touch interest)\n" ..
              "• Step 3: Hatches BasicEgg from World 1 Spawn to craft 15 Golden Pets\n" ..
              "• Step 4: Hatches 2,500 Eggs using BasicEgg from World 1 Spawn\n" ..
              "• Step 5: Teleports to Spawn Door, unlocks & enters Dominus Area\n" ..
              "• Once Door is unlocked -> Transitions to Phase 3 (Endgame Skill Tree 39/39)!"
})

local Phase2ProgressCard = Phase2Tab:AddParagraph({
    Title = "??? Secret Quest Status",
    Content = "Evaluating...",
    TitleSize = 16,
    BodySize = 13,
})
_G.ClickerSimulatorPhase2ProgressCard = Phase2ProgressCard

Phase2Tab:AddToggle("AutoSecretQuestToggle", {
    Title = "Enable Phase 2 Automation",
    Description = "Automatically completes ??? quests, crafts 15 golden pets, hatches 2,500 eggs, and unlocks door",
    Default = State.AutoSecretQuest ~= false,
    Callback = function(val) State.AutoSecretQuest = val; Configs.Set("AutoSecretQuest", val) end
})

Phase2Tab:AddToggle("AutoCollectFeathersToggle", {
    Title = "Auto Collect Feathers",
    Description = "Automatically gathers all 10 feathers required for the secret quest",
    Default = State.AutoCollectFeathers ~= false,
    Callback = function(val) State.AutoCollectFeathers = val; Configs.Set("AutoCollectFeathers", val) end
})

Phase2Tab:AddToggle("AutoSecretCraftGoldenToggle", {
    Title = "Auto Craft Golden Pets (BasicEgg)",
    Description = "Hatches BasicEgg from Spawn and crafts 15 Golden pets to complete quest requirement",
    Default = State.AutoSecretCraftGolden ~= false,
    Callback = function(val) State.AutoSecretCraftGolden = val; Configs.Set("AutoSecretCraftGolden", val) end
})

Phase2Tab:AddToggle("AutoUnlockSecretDoorToggle", {
    Title = "Auto Unlock & Enter Dominus Door",
    Description = "Teleports to Spawn Door, unlocks secret door, and enters Dominus Area",
    Default = State.AutoUnlockSecretDoor ~= false,
    Callback = function(val) State.AutoUnlockSecretDoor = val; Configs.Set("AutoUnlockSecretDoor", val) end
})

--==============================================================================
-- 4. PHASE 3: ENDGAME SKILL TREE (39/39) TAB
--==============================================================================
local Phase3Tab = Window:AddTab({ Title = "Phase 3: Skill Tree (39/39)", Icon = "👑" })

Phase3Tab:AddSection("PHASE 3 SETTINGS (ENDGAME SKILL TREE & PREPARATION)")
Phase3Tab:AddParagraph({
    Title = "Phase 3 Strategy",
    Content = "Activates automatically after Phase 2 (??? Secret Door Unlocked)!\n" ..
              "• 1st: Max Skill Tree Coins (39/39) farming breakables in ??? Dominus Area (includes all 3 Dominus Fortune perks: Dominus Hatch, Dominus Luck, Secret Seeker!)\n" ..
              "• 2nd: Max Skill Tree Tech (13/13) farming breakables in Tech World (Matrix Island)\n" ..
              "• 3rd: Desert Gem Machine & Rebirth Shop Maxing\n" ..
              "• Once Skill Tree is 100% complete (39/39 Coins & 13/13 Tech), Phase 4 (Matrix Mythics) activates automatically!"
})

local Phase3ProgressCard = Phase3Tab:AddParagraph({
    Title = "Skill Tree Progress (39/39 Coins & 13/13 Tech)",
    Content = "Evaluating...",
    TitleSize = 16,
    BodySize = 13,
})
_G.ClickerSimulatorPhase3ProgressCard = Phase3ProgressCard

Phase3Tab:AddToggle("AutoSkillTreeToggle_P3", {
    Title = "Auto Skill Tree (Dominus Area 39/39 -> Matrix 13/13)",
    Description = "Grinds ??? Dominus Area for Coins 39/39, then advances to Matrix for Tech Coins 13/13",
    Default = State.AutoSkillTree,
    Callback = function(val) State.AutoSkillTree = val; Configs.Set("AutoSkillTree", val) end
})

Phase3Tab:AddToggle("AutoDesertMachineToggle_P3", {
    Title = "Desert Machine & Gem Upgrades Maxing",
    Description = "Maxes out Desert machine perks and rebirth milestone buttons",
    Default = State.AutoDesertMachine,
    Callback = function(val) State.AutoDesertMachine = val; Configs.Set("AutoDesertMachine", val) end
})

Phase3Tab:AddToggle("AutoPrestigeToggle_P3", {
    Title = "Auto Prestige (When Available)",
    Description = "Automatically triggers Prestige when Rebirths requirement is met, adapting progression smoothly",
    Default = State.AutoPrestige,
    Callback = function(val) State.AutoPrestige = val; Configs.Set("AutoPrestige", val) end
})

--==============================================================================
-- 5. PHASE 4: AUTO INDEX PETS TAB
--==============================================================================
local Phase4Tab = Window:AddTab({ Title = "Phase 4: Auto Index", Icon = "📖" })

Phase4Tab:AddSection("PHASE 4 SETTINGS (AUTO INDEX PETS PIPELINE)")
Phase4Tab:AddParagraph({
    Title = "Auto Index Strategy",
    Content = "Activates automatically after Phase 3 (Skill Tree 39/39 & 13/13)!\n" ..
              "• Priority Order: Normal > Gold across ALL worlds up to Legendary first!\n" ..
              "• Two-Pass Architecture: Completes all Normal and Gold pets across all eggs before ever starting Rainbows!\n" ..
              "• Target Goal: 250 Total Index (Reaching 250 via Normal/Gold immediately completes Phase 4 without Rainbows)!\n" ..
              "• Rainbow Fallback: Only starts crafting easy Rainbows if all worlds are finished with Gold and index is still below 250!\n" ..
              "• Ignore Rare Filter: Skips ultra-rare drops (Mythic, Secret, Divine) so bot never gets stuck on 1 egg!\n" ..
              "• Keep Rare Guarantee: If any Secret/Mythic drops by luck, it is 100% saved in inventory and NEVER deleted!\n" ..
              "• Auto Delete Fodder: Deletes common/rare/epic indexed pets once registered to keep bag empty\n" ..
              "• Background Claimer: Periodically claims ready Rainbow pets from the machine in the background!"
})

local Phase4CurrentEggCard = Phase4Tab:AddParagraph({
    Title = "Current Egg Progress",
    Content = "Evaluating...",
    TitleSize = 16,
    BodySize = 13,
})
_G.ClickerSimulatorPhase4CurrentEggCard = Phase4CurrentEggCard

local Phase4IndexStatsCard = Phase4Tab:AddParagraph({
    Title = "Total Index Telemetry",
    Content = "Evaluating...",
    TitleSize = 16,
    BodySize = 13,
})
_G.ClickerSimulatorPhase4IndexStatsCard = Phase4IndexStatsCard

Phase4Tab:AddToggle("AutoIndexPetsToggle", {
    Title = "Enable Phase 4: Auto Index Pets",
    Description = "Automatically visits all progression eggs and unlocks missing pet index entries",
    Default = State.AutoIndexPets ~= false,
    Callback = function(val) State.AutoIndexPets = val; Configs.Set("AutoIndexPets", val) end
})

Phase4Tab:AddSlider("IndexTargetTotalSlider", {
    Title = "Phase 4 Target Index Goal",
    Description = "Total index entries needed before completing Phase 4 and transitioning to Phase 5 (Default: 250)",
    Default = tonumber(State.IndexTargetTotal) or 250,
    Min = 50,
    Max = 400,
    Increment = 10,
    Callback = function(val) State.IndexTargetTotal = val; Configs.Set("IndexTargetTotal", val) end
})

Phase4Tab:AddToggle("IndexIgnoreMythicToggle", {
    Title = "Ignore Mythic, Secret & Higher Ups (Egg Skip)",
    Description = "Skips ultra-rare drops when checking if an egg is complete. If hatched by luck, they are ALWAYS kept!",
    Default = State.IndexIgnoreMythicAndAbove ~= false,
    Callback = function(val) State.IndexIgnoreMythicAndAbove = val; Configs.Set("IndexIgnoreMythicAndAbove", val) end
})

Phase4Tab:AddToggle("IndexUnlockNormalToggle", {
    Title = "Unlock Normal Index",
    Description = "Hatches until all standard pets for the egg have their Normal index registered",
    Default = State.IndexUnlockNormal ~= false,
    Callback = function(val) State.IndexUnlockNormal = val; Configs.Set("IndexUnlockNormal", val) end
})

Phase4Tab:AddToggle("IndexUnlockGoldToggle", {
    Title = "Unlock Gold Index",
    Description = "Collects normal copies, auto-crafts Golden pets, and registers Golden index",
    Default = State.IndexUnlockGold ~= false,
    Callback = function(val) State.IndexUnlockGold = val; Configs.Set("IndexUnlockGold", val) end
})

Phase4Tab:AddToggle("IndexUnlockRainbowToggle", {
    Title = "Unlock Rainbow Index (Common & Rare Only)",
    Description = "Collects 6 gold copies, auto-queues in Rainbow Machine, and advances to next egg while 30m craft cooks",
    Default = State.IndexUnlockRainbow ~= false,
    Callback = function(val) State.IndexUnlockRainbow = val; Configs.Set("IndexUnlockRainbow", val) end
})

Phase4Tab:AddToggle("IndexUnlockDarkMatterToggle", {
    Title = "Unlock Dark Matter Index",
    Description = "Converts to Dark Matter to register Dark Matter index if available in game",
    Default = State.IndexUnlockDarkMatter == true,
    Callback = function(val) State.IndexUnlockDarkMatter = val; Configs.Set("IndexUnlockDarkMatter", val) end
})

Phase4Tab:AddToggle("IndexAutoDeleteFodderToggle", {
    Title = "Auto Delete Indexed Fodder",
    Description = "Deletes Common, Rare, Epic, and Legendary pets once their index is acquired (Protects Mythics/Secrets!)",
    Default = State.IndexAutoDeleteFodder ~= false,
    Callback = function(val) State.IndexAutoDeleteFodder = val; Configs.Set("IndexAutoDeleteFodder", val) end
})

--==============================================================================
-- 6. PHASE 5: CLICK SKIN TAB
--==============================================================================
local Phase5Tab = Window:AddTab({ Title = "Phase 5: Click Skin", Icon = "🟣" })

Phase5Tab:AddSection("PHASE 5 SETTINGS (ULTIMATE CLICK SKIN PIPELINE)")
Phase5Tab:AddParagraph({
    Title = "Phase 5 Strategy",
    Content = "Activates automatically after Phase 4 (250 Pets Indexed)!\n" ..
              "• Buys the purple 'Ultimate' Click Skin (Requires 250 Pets)\n" ..
              "• Saves up 100 Qa Gems (1e17) before rerolling\n" ..
              "• Automatically rerolls until BOTH stats are rolled:\n" ..
              "    - +3 Egg Hatch (Max Flat Roll)\n" ..
              "    - +15% Hatch Speed (Target >= 15%)\n" ..
              "• If only +3 Egg or only +15% Speed is rolled, keeps rerolling!\n" ..
              "• Replaces & equips once both target goals are satisfied\n" ..
              "• Once complete, advances directly to Phase 6: Matrix Mythics!"
})

Phase5Tab:AddToggle("AutoClickSkinToggle", {
    Title = "Auto Ultimate Click Skin",
    Description = "Enables Phase 5 Click Skin pipeline (save 100Qa gems & reroll +3 Egg, +15% Speed)",
    Default = State.AutoClickSkin ~= false,
    Callback = function(val) State.AutoClickSkin = val; Configs.Set("AutoClickSkin", val) end
})

Phase5Tab:AddSlider("ClickSkinTargetEggHatchSlider", {
    Title = "Target Egg Hatch Passive",
    Description = "Desired Egg Hatch passive bonus (+1 to +3)",
    Default = (State.ClickSkinTargetEggHatch ~= nil) and State.ClickSkinTargetEggHatch or 3,
    Min = 1,
    Max = 3,
    Rounding = 0,
    Callback = function(val) State.ClickSkinTargetEggHatch = val; Configs.Set("ClickSkinTargetEggHatch", val) end
})

Phase5Tab:AddSlider("ClickSkinTargetHatchSpeedSlider", {
    Title = "Target Hatch Speed Boost (%)",
    Description = "Desired Hatch Speed boost percentage (e.g. 15% to 18%)",
    Default = (State.ClickSkinTargetHatchSpeed ~= nil) and State.ClickSkinTargetHatchSpeed or 15,
    Min = 5,
    Max = 18,
    Rounding = 0,
    Callback = function(val) State.ClickSkinTargetHatchSpeed = val; Configs.Set("ClickSkinTargetHatchSpeed", val) end
})

Phase5Tab:AddSlider("ClickSkinGemsThresholdSlider", {
    Title = "Gems Saving Threshold (Qa)",
    Description = "Saves up this amount of Qa Gems before rerolling (Default: 100 Qa = 1e17)",
    Default = (State.ClickSkinGemsThreshold ~= nil) and State.ClickSkinGemsThreshold or 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(val) State.ClickSkinGemsThreshold = val; Configs.Set("ClickSkinGemsThreshold", val) end
})

Phase5Tab:AddToggle("PauseRebirthToggle_P5", {
    Title = "Rebirth at Max Milestone Only",
    Description = "Waits until no more Next Rebirth button, then rebirths to the max affordable milestone",
    Default = (State.PauseRebirthPhase5 ~= nil) and State.PauseRebirthPhase5 or true,
    Callback = function(val) State.PauseRebirthPhase5 = val; Configs.Set("PauseRebirthPhase5", val) end
})

local Phase5SkinCard = Phase5Tab:AddParagraph({
    Title = "Live Skin Status",
    Content = "Loading click skin telemetry..."
})

--==============================================================================
-- 7. PHASE 6: MATRIX MYTHICS TAB
--==============================================================================
local Phase6Tab = Window:AddTab({ Title = "Phase 6: Matrix Mythics", Icon = "🧬" })

Phase6Tab:AddSection("PHASE 6 SETTINGS (ENDGAME MATRIX MYTHIC PIPELINE)")
Phase6Tab:AddParagraph({
    Title = "Phase 6 Strategy",
    Content = "Activates automatically after Phase 5 (Ultimate Click Skin) is complete (or disabled)!\n" ..
              "• Auto Open Matrix Egg (highest endgame egg in Tech World)\n" ..
              "• Rebirth at Max Milestone Only (preserves clicks for Matrix Egg)\n" ..
              "• Mythic Pet Filter: Deletes all non-mythic pets (Common/Rare/Epic/Legendary) and weak pets\n" ..
              "• Auto Crafts Golden Mythics & Rainbow Mythics\n" ..
              "• Equips best pets as Rainbow Mythics are created, replacing old pets until team is 100% Rainbow Mythics!"
})

Phase6Tab:AddToggle("AutoMatrixEggToggle_P6", {
    Title = "Auto Open Matrix Egg",
    Description = "Continuously hatches Matrix Egg on Matrix Island in Tech World",
    Default = State.AutoMatrixEgg ~= false,
    Callback = function(val) State.AutoMatrixEgg = val; Configs.Set("AutoMatrixEgg", val) end
})

Phase6Tab:AddToggle("AutoMythicFilterToggle_P6", {
    Title = "Protect High-Tier (Exclusive, Secret, Stock, Divine, Mega)",
    Description = "Strictly keeps Exclusive, Secret, Stock, Divine, Mega, and Mythic pets; deletes Common, Rare, Epic, Legendary",
    Default = State.AutoMythicFilter ~= false,
    Callback = function(val) State.AutoMythicFilter = val; Configs.Set("AutoMythicFilter", val) end
})

Phase6Tab:AddToggle("AutoCraftMythicsToggle_P6", {
    Title = "Auto Craft Golden & Rainbow Mythics",
    Description = "Automatically crafts Golden and Rainbow versions of Mythic pets",
    Default = State.AutoCraftMythics ~= false,
    Callback = function(val) State.AutoCraftMythics = val; Configs.Set("AutoCraftMythics", val) end
})

Phase6Tab:AddToggle("AutoReplaceTeamToggle_P6", {
    Title = "Auto Replace Team with Rainbow Mythics",
    Description = "Equips best pets as Rainbow Mythics are forged, replacing weaker old pets",
    Default = State.AutoReplaceTeam ~= false,
    Callback = function(val) State.AutoReplaceTeam = val; Configs.Set("AutoReplaceTeam", val) end
})

Phase6Tab:AddToggle("PauseRebirthToggle_P6", {
    Title = "Rebirth at Max Milestone Only",
    Description = "Waits until no more Next Rebirth button, then rebirths to the max affordable milestone",
    Default = (State.PauseRebirthPhase6 ~= nil) and State.PauseRebirthPhase6 or (State.PauseRebirthPhase5 ~= nil and State.PauseRebirthPhase5 or true),
    Callback = function(val) State.PauseRebirthPhase6 = val; Configs.Set("PauseRebirthPhase6", val) end
})

Phase6Tab:AddToggle("AutoRainbowClaimToggle_P6", {
    Title = "Auto Claim Rainbow Pets",
    Description = "Automatically collects finished pets from the Rainbow Machine",
    Default = State.AutoRainbowClaim ~= false,
    Callback = function(val) State.AutoRainbowClaim = val; Configs.Set("AutoRainbowClaim", val) end
})

Phase6Tab:AddToggle("AutoMagmaSkinToggle_P6", {
    Title = "10 Qi Rebirth Goal & Magma Click Skin",
    Description = "Monitors 10 Qi Rebirth milestone and equips Magma Click Skin (+4 Egg Hatch, +20% Speed)",
    Default = State.AutoMagmaSkin,
    Callback = function(val) State.AutoMagmaSkin = val; Configs.Set("AutoMagmaSkin", val) end
})

local Phase6MythicCard = Phase6Tab:AddParagraph({
    Title = "Live Matrix Mythic Team Status",
    Content = "Loading team status..."
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

MiscTab:AddSection("SESSION RESILIENCE & MULTI-ACCOUNT")
MiscTab:AddToggle("AntiAFKToggle", {
    Title = "Anti-AFK (Idle Kick Prevention)",
    Description = "Prevents Roblox 20-minute idle disconnection via Idled event bypass and controller keepalive",
    Default = State.AntiAFK ~= false,
    Callback = function(val)
        State.AntiAFK = val
        Configs.Set("AntiAFK", val)
        if val then
            AutoProgAPI.StartAntiAFK()
            Window:Notify({ Title = "Anti-AFK", Content = "Anti-AFK enabled! AFK kicks are prevented.", Duration = 2.5 })
        else
            AutoProgAPI.StopAntiAFK()
            Window:Notify({ Title = "Anti-AFK", Content = "Anti-AFK disabled.", Duration = 2.5 })
        end
    end
})

MiscTab:AddToggle("AutoRejoinToggle", {
    Title = "Auto Rejoin on Disconnect (Any Error)",
    Description = "Automatically reconnects and reloads the script upon any disconnection, kick, or error code",
    Default = State.AutoRejoin ~= false,
    Callback = function(val)
        State.AutoRejoin = val
        Configs.Set("AutoRejoin", val)
        if val then
            AutoProgAPI.StartAutoRejoin()
            Window:Notify({ Title = "Auto Rejoin", Content = "Auto Rejoin enabled! Will reconnect on disconnect.", Duration = 2.5 })
        else
            AutoProgAPI.StopAutoRejoin()
            Window:Notify({ Title = "Auto Rejoin", Content = "Auto Rejoin disabled.", Duration = 2.5 })
        end
    end
})

MiscTab:AddSection("AUTOMATIC TRADING")
MiscTab:AddToggle("AutoAcceptTradeToggle", {
    Title = "Auto Accept Trade",
    Description = "Automatically accepts incoming trade requests, waits for the other player to ready, and confirms after the countdown",
    Default = State.AutoAcceptTrade ~= false,
    Callback = function(val)
        State.AutoAcceptTrade = val
        Configs.Set("AutoAcceptTrade", val)
        if val then
            AutoProgAPI.InitAutoTradeListener()
            Window:Notify({ Title = "Auto Trade", Content = "Auto Accept Trade enabled!", Duration = 2.5 })
        else
            Window:Notify({ Title = "Auto Trade", Content = "Auto Accept Trade disabled.", Duration = 2.5 })
        end
    end
})

MiscTab:AddParagraph({
    Title = "Active Account Profile (Isolated Storage)",
    Content = string.format("User: %s (ID: %d)\nProfile Folder: %s\nConfig Path: %s",
        LocalPlayer.Name,
        LocalPlayer.UserId,
        Configs.UserFolder or AutoProgAPI.GetUserAccountFolder(),
        Configs.ConfigPath or AutoProgAPI.GetUserAccountConfigPath()
    ),
    TitleSize = 15,
    BodySize = 13,
    Height = 85
})

MiscTab:AddSection("QUICK UTILITIES & SHORTCUTS")
MiscTab:AddButton({
    Title = "Open Bank GUI",
    Description = "Bypasses FFlags restriction and opens The Bank window to deposit and withdraw tokens and pets",
    Callback = function()
        local ok, msg = AutoProgAPI.OpenBank()
        Window:Notify({ Title = "The Bank", Content = msg or (ok and "Bank Opened!" or "Failed to open Bank"), Duration = 3 })
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
        if AutoProgAPI.IsPhase6 and AutoProgAPI.IsPhase6() then
            local pData = AutoProgAPI.GetPlayerData()
            local curWorld = pData.CurrentWorld or "Overworld"
            if curWorld ~= "Techworld" and curWorld ~= "Space" then
                AutoProgAPI.TeleportToWorld("Techworld")
                task.wait(0.5)
                AutoProgAPI.TeleportToEgg("MatrixEgg")
            end
            return
        end

        if AutoProgAPI.IsPhase5 and AutoProgAPI.IsPhase5() then
            local pData = AutoProgAPI.GetPlayerData()
            local curWorld = pData.CurrentWorld or "Overworld"
            if curWorld ~= "Techworld" and curWorld ~= "Space" then
                AutoProgAPI.TeleportToWorld("Techworld")
                task.wait(0.5)
            end
            return
        end

        if AutoProgAPI.IsPhase4 and AutoProgAPI.IsPhase4() then
            local nextEgg = AutoProgAPI.GetNextUnindexedEgg and AutoProgAPI.GetNextUnindexedEgg(
                State.IndexIgnoreMythicAndAbove ~= false,
                State.IndexUnlockNormal ~= false,
                State.IndexUnlockGold ~= false,
                State.IndexUnlockRainbow ~= false,
                State.IndexUnlockDarkMatter == true
            )
            if nextEgg then
                AutoProgAPI.TeleportToEgg(nextEgg.name)
            end
            return
        end

        if AutoProgAPI.IsPhase3 and AutoProgAPI.IsPhase3() then
            local stProg = AutoProgAPI.GetSkillTreeProgress()
            local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 39)
            local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
            if not coinsDone then
                AutoProgAPI.EnterDominusArea()
            elseif not techDone then
                AutoProgAPI.TeleportToWorld("Techworld")
                task.wait(0.4)
                AutoProgAPI.TeleportToIsland("Matrix")
                task.wait(0.4)
                AutoProgAPI.TeleportToBreakableZone("Matrix")
            end
            return
        end

        local pData = AutoProgAPI.GetPlayerData()
        local lockedIsland = AutoProgAPI.GetNextLockedIsland()
        if lockedIsland == nil and State.AutoSkillTree then
            local qProg = AutoProgAPI.GetSecretQuestProgress()
            if State.AutoSecretQuest and not (qProg and qProg.DoorUnlocked) then
                -- Door not unlocked yet, let StepSecretQuest handle positioning
                return
            end
            local stProg = AutoProgAPI.GetSkillTreeProgress()
            local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 39)
            local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
            if not coinsDone then
                AutoProgAPI.EnterDominusArea()
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
-- Phase 1, 2, 3, 4: Rebirth as long as affordable (RebirthBestAffordable)
-- Phase 5 & 6: Max Rebirth only (RebirthMaxTarget)
table.insert(threads, task.spawn(function()
    local lastRebirthAttempt = 0
    while isRunning do
        task.wait(0.12)
        if not State.MasterEnabled or not State.AutoMaxRebirth or not isRunning then continue end

        local now = tick()
        if now - lastRebirthAttempt > 0.25 then
            lastRebirthAttempt = now

            local isP6 = AutoProgAPI.IsPhase6 and AutoProgAPI.IsPhase6()
            local isP5 = AutoProgAPI.IsPhase5 and AutoProgAPI.IsPhase5()
            if isP6 or isP5 then
                -- Phase 5 & 6: Rebirth at MAX milestone only
                pcall(AutoProgAPI.RebirthMaxTarget)
            else
                -- Phase 1, 2, 3, 4: Rebirth as long as they can afford it
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

-- THREAD 13: DEDICATED BREAKABLES & SKILL TREE ENGINE (Active in Phase 3 until Skill Tree is MAXED 39/39 & 13/13!)
table.insert(threads, task.spawn(function()
    local lastBreakableTick = 0
    while isRunning do
        task.wait(0.04)
        if not State.MasterEnabled or not isRunning then continue end

        local isP2 = AutoProgAPI.IsPhase2 and AutoProgAPI.IsPhase2()
        if isP2 then
            task.wait(0.5)
            continue
        end

        local allIslands = AutoProgAPI.AreAllIslandsUnlocked()
        local isSecretQuestDone = AutoProgAPI.IsSecretQuestComplete and AutoProgAPI.IsSecretQuestComplete()
        local stProg = AutoProgAPI.GetSkillTreeProgress()
        local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 39)
        local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
        local isSkillTreeMaxed = coinsDone and techDone

        -- Runs in Phase 3 until Skill Tree is fully maxed! (Farms Dominus Area for Coins 39/39 -> Tech World Matrix for Tech Coins 13/13)
        if allIslands and isSecretQuestDone and (not isSkillTreeMaxed) and State.AutoSkillTree then
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
                        currentActivity = string.format("[Tech Skill Tree (13/13)] %s in %s", tostring(action), tostring(targetIsl or "Matrix"))
                    else
                        currentActivity = string.format("[Tech Skill Tree (13/13)] Farming Breakables in %s", tostring(targetIsl or "Matrix"))
                    end
                else
                    if action then
                        currentActivity = string.format("[Skill Tree (39/39)] %s in %s", tostring(action), tostring(targetIsl or "DominusArea"))
                    else
                        currentActivity = "[Skill Tree (39/39)] Farming Breakables in Dominus Area"
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
                local furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                currentPhaseText = string.format("🌟 PHASE 1: ISLAND SPEEDRUN (%s - %s)", furthest, lockedIsland.name)

                -- Auto pick starter pet if new player
                pcall(AutoProgAPI.CheckAndSelectStarterPet)

                -- 1. Strictly stay on furthest unlocked island! (Never leave best unlocked island!)
                if pData.CurrentIsland ~= furthest and (now - lastTeleportTick > 2) then
                    lastTeleportTick = now
                    AutoProgAPI.TeleportToIsland(furthest)
                    pData = AutoProgAPI.GetPlayerData()
                end

                -- In Phase 1: Only look for affordable eggs located strictly ON the furthest unlocked island!
                local bestEgg = AutoProgAPI.GetBestAffordableEgg(furthest)
                local canAffordBestEgg = (bestEgg ~= nil) and (pData.Clicks >= bestEgg.cost)
                local isSafeEgg = bestEgg and (bestEgg.island == furthest)
                local isNearUnlock = lockedIsland and (pData.Clicks >= lockedIsland.cost * 0.75)
                local shouldHatch = (State.AutoBestEggs or State.AutoGold) and (not isAllGold) and canAffordBestEgg and isSafeEgg and not isNearUnlock

                if not shouldHatch and lockedIsland and pData.Clicks < lockedIsland.cost then
                    currentActivity = string.format("[Phase 1] Speedrunning Clicks for %s on %s (%s / %s)", lockedIsland.name, furthest, AutoProgAPI.FormatNumber(pData.Clicks), AutoProgAPI.FormatNumber(lockedIsland.cost))
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
                            furthest = AutoProgAPI.GetFurthestUnlockedIsland()
                            AutoProgAPI.TeleportToIsland(furthest)
                        end
                    end
                end

                -- 3. Auto buy egg for pets & auto gold pets strictly on furthest island
                local hatchDelay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed(bestEgg and bestEgg.name)) or 1.5
                if (State.AutoBestEggs or State.AutoGold) and not isEggHatching and (now - lastEggHatchTick >= hatchDelay) then
                    lastEggHatchTick = now

                    -- If team is not yet all gold, hatch best affordable egg strictly on furthest island!
                    if not isAllGold and canAffordBestEgg and isSafeEgg and not isNearUnlock then
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
                    end
                end

            -- =====================================================================
            -- PHASE 2: ??? SECRET AREA QUEST
            -- Condition: All 17 islands unlocked, but Secret Quest is NOT complete!
            -- Flow:
            -- 1. Accept Quest at Spawn Door
            -- 2. Click 3,500 Times
            -- 3. Collect 10 Feathers across maps
            -- 4. Hatches BasicEgg from World 1 Spawn to craft 15 Golden Pets
            -- 5. Hatches 2,500 Eggs using BasicEgg from World 1 Spawn
            -- 6. Teleports to Spawn Door, unlocks & enters Dominus Area
            -- Once Door is unlocked -> Transitions to Phase 3 (Skill Tree 39/39)!
            -- =====================================================================
            elseif not isSecretQuestDone then
                currentPhaseText = "🗝️ PHASE 2: ??? SECRET QUEST"
                local qInfo = AutoProgAPI.GetSecretQuestInfo and AutoProgAPI.GetSecretQuestInfo()

                -- Quest in progress: hatch BasicEgg paced at player hatch speed
                local p2Delay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed("BasicEgg")) or 1.5
                if State.AutoSecretQuest ~= false and not isEggHatching and (now - lastEggHatchTick >= p2Delay) then
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

            -- =====================================================================
            -- PHASE 3: ENDGAME SKILL TREE & PREPARATION (39/39 COINS & 13/13 TECH)
            -- Condition: All 17 islands unlocked, Secret Quest done, but Skill Tree NOT maxed!
            -- Order:
            -- 1. Thread 13 farms Dominus Area for Coins (39/39 perks including 3 Dominus Fortune perks)
            -- 2. Thread 13 farms Matrix in Tech World for Tech Coins (13/13 perks)
            -- 3. Thread 8 & 9 max Desert Gem Machine & Rebirth Shop
            -- Once 39/39 Coins & 13/13 Tech complete -> Transitions to Phase 4!
            -- =====================================================================
            elseif not isSkillTreeDone then
                currentPhaseText = "👑 PHASE 3: ENDGAME SKILL TREE (39/39)"
                -- Thread 13 handles breakables and skill tree purchasing.

            -- =====================================================================
            -- PHASE 4: AUTO INDEX PETS PIPELINE
            -- Condition: All 17 islands unlocked, Secret Quest done, Skill Tree done (39/39),
            -- and AutoIndexPets enabled and NOT all progression eggs indexed!
            -- =====================================================================
            elseif State.AutoIndexPets and AutoProgAPI.IsPhase4 and AutoProgAPI.IsPhase4() then
                currentPhaseText = "📖 PHASE 4: AUTO INDEX PETS"
                local nextEgg, eggProg = AutoProgAPI.GetNextUnindexedEgg(
                    State.IndexIgnoreMythicAndAbove ~= false,
                    State.IndexUnlockNormal ~= false,
                    State.IndexUnlockGold ~= false,
                    State.IndexUnlockRainbow ~= false,
                    State.IndexUnlockDarkMatter == true
                )

                local p4Delay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed(nextEgg and nextEgg.name)) or 1.5
                if not isEggHatching and (now - lastEggHatchTick >= p4Delay) then
                    lastEggHatchTick = now
                    isEggHatching = true
                    lastEggHatchStartTick = now
                    task.spawn(function()
                        local okStep, stepIsDone, stepMsg = pcall(function()
                            return AutoProgAPI.StepAutoIndex(
                                State.IndexIgnoreMythicAndAbove ~= false,
                                State.IndexUnlockNormal ~= false,
                                State.IndexUnlockGold ~= false,
                                State.IndexUnlockRainbow ~= false,
                                State.IndexUnlockDarkMatter == true
                            )
                        end)
                        if okStep and stepMsg and type(stepMsg) == "string" then
                            currentActivity = stepMsg
                        end
                        isEggHatching = false
                    end)
                end

            -- =====================================================================
            -- PHASE 5: ULTIMATE CLICK SKIN PIPELINE
            -- Condition: All 17 islands unlocked, Secret Quest done, Skill Tree done (39/39),
            -- Phase 4 complete, and AutoClickSkin enabled and ClickSkin goal NOT yet met!
            -- =====================================================================
            elseif State.AutoClickSkin and AutoProgAPI.IsPhase5 and AutoProgAPI.IsPhase5() then
                currentPhaseText = "🟣 PHASE 5: ULTIMATE CLICK SKIN"
                local okStep, stepIsDone, stepMsg = pcall(function()
                    return AutoProgAPI.StepClickSkinPipeline()
                end)
                if okStep and stepMsg and type(stepMsg) == "string" then
                    currentActivity = stepMsg
                end

            -- =====================================================================
            -- PHASE 6: ENDGAME MATRIX MYTHIC PIPELINE
            -- Condition: All 17 islands unlocked, Secret Quest done, Skill Tree done (39/39),
            -- and Phase 5 complete (or disabled)!
            -- =====================================================================
            else
                currentPhaseText = "🧬 PHASE 6: MATRIX MYTHIC PIPELINE"

                local curWorld = pData.CurrentWorld or "Overworld"
                if AutoProgAPI.IsInMinigame() or (curWorld ~= "Techworld" and curWorld ~= "Space") then
                    AutoProgAPI.ExitMinigame()
                    task.wait(0.3)
                    currentActivity = "[Phase 6: Matrix] Teleporting to Tech World..."
                    AutoProgAPI.TeleportToWorld("Techworld")
                    task.wait(0.5)
                    AutoProgAPI.TeleportToEgg("MatrixEgg")
                    task.wait(0.5)
                    return
                end

                local curIsland = pData.CurrentIsland or ""
                if curIsland ~= "Matrix" then
                    currentActivity = "[Phase 6: Matrix] Teleporting to Matrix Island..."
                    AutoProgAPI.TeleportToEgg("MatrixEgg")
                    task.wait(0.5)
                    return
                end

                local isAllRainbowMythic, mythicCount, totalSlots = AutoProgAPI.IsEquippedTeamAllRainbowMythic()
                local hatchDelay = (AutoProgAPI.GetPlayerHatchSpeed and AutoProgAPI.GetPlayerHatchSpeed("MatrixEgg")) or 1.5

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
                        currentActivity = "[Phase 6: Matrix] Teleporting to Matrix Egg in Tech World..."
                        AutoProgAPI.TeleportToEgg("MatrixEgg")
                        task.wait(0.3)
                    end

                    if pData.Clicks >= matrixCost then
                        local hatchAmount = AutoProgAPI.GetMaxEggOpenAmount("MatrixEgg")
                        currentActivity = string.format("[Phase 6: Matrix] Hatching %dx MatrixEgg (Mythic Hunt)...", hatchAmount)
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
                        currentActivity = string.format("[Phase 6: Matrix] Speedrunning Clicks for Matrix Egg (%s / %s)", AutoProgAPI.FormatNumber(pData.Clicks), "25.00Sp")
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
                    currentActivity = string.format("🌟 [Phase 6: Complete] Team 100%% Rainbow Mythic (%d/%d)!", mythicCount, totalSlots)
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

        local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
        local idxStr = totalStats and string.format("%d Pets (Norm: %d, Gold: %d)", totalStats.TotalIndexed or 0, totalStats.IndexedNormal or 0, totalStats.IndexedGolden or 0) or "N/A"

        local skStatus = ProgAPI.GetClickSkinStatus and ProgAPI.GetClickSkinStatus()
        local skinStr = skStatus and (skStatus.GoalMet and string.format("Ultimate (+%d Egg, +%.1f%% Speed) ✅", skStatus.EquippedEggHatch, skStatus.EquippedHatchSpeed) or string.format("Rerolling (+%d Egg, +%.1f%% Speed)", skStatus.EquippedEggHatch, skStatus.EquippedHatchSpeed)) or "N/A"

        local hatchSpeedStr = (ProgAPI.FormatHatchSpeed and ProgAPI.FormatHatchSpeed()) or "1.5s"

        -- 2. Statistical Progression Telemetry Card
        local cardTitle = "Progression Telemetry"
        local cardContent = string.format(
            "⚡ <b>Clicks:</b> %s  |  <b>Rebirths:</b> %s  |  <b>Hatch Speed:</b> %s\n" ..
            "💎 <b>Gems:</b> %s  |  <b>Coins:</b> %s  |  <b>Tech Coins:</b> %s\n" ..
            "🚀 <b>Prestige:</b> %s\n" ..
            "🏝️ <b>Islands:</b> %s\n" ..
            "🐾 <b>Pet Team:</b> %s\n" ..
            "🌳 <b>Skill Tree:</b> %s\n" ..
            "🗝️ <b>??? Quest:</b> %s\n" ..
            "📖 <b>Auto Index:</b> %s\n" ..
            "🟣 <b>Click Skin:</b> %s\n" ..
            "🔥 <b>Magma Skin:</b> %s",
            ProgAPI.FormatNumber(pData.Clicks or 0),
            ProgAPI.FormatNumber(pData.Rebirths or 0),
            tostring(hatchSpeedStr),
            ProgAPI.FormatNumber(pData.Gems or 0),
            ProgAPI.FormatNumber(pData.Coins or 0),
            ProgAPI.FormatNumber(pData.SpaceCoins or 0),
            tostring(prestStr),
            tostring(islandProgressStr),
            tostring(teamStr),
            tostring(stStr),
            tostring(questStr),
            tostring(idxStr),
            tostring(skinStr),
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

        if Phase2ProgressCard then
            local qContent = ""
            if qInfo then
                qContent = string.format(
                    "🎯 <b>Quest Step:</b> %s\n" ..
                    "🖱️ <b>Clicks:</b> %s / %s (%s)\n" ..
                    "🪶 <b>Feathers:</b> %d / %d (%s)\n" ..
                    "⭐ <b>Golden Crafts (BasicEgg):</b> %d / %d (%s)\n" ..
                    "🥚 <b>Hatch Eggs (BasicEgg):</b> %s / %s (%s)\n" ..
                    "🚪 <b>Dominus Door:</b> %s",
                    tostring(qInfo.CurrentStep),
                    AutoProgAPI.FormatNumber(qInfo.Clicks.Progress), AutoProgAPI.FormatNumber(qInfo.Clicks.Amount), qInfo.Clicks.Done and "✅" or "⏳",
                    qInfo.Feathers.Progress, qInfo.Feathers.Amount, qInfo.Feathers.Done and "✅" or "⏳",
                    qInfo.Golden.Progress, qInfo.Golden.Amount, qInfo.Golden.Done and "✅" or "⏳",
                    AutoProgAPI.FormatNumber(qInfo.Hatch.Progress), AutoProgAPI.FormatNumber(qInfo.Hatch.Amount), qInfo.Hatch.Done and "✅" or "⏳",
                    qInfo.IsDoorUnlocked and "🔓 UNLOCKED (Phase 2 Done)" or (qInfo.AllQuestsDone and "READY TO UNLOCK" or "LOCKED")
                )
            else
                qContent = "Secret Quest initializing..."
            end

            Phase2ProgressCard:Set({
                Title = "??? Secret Quest Status",
                Content = qContent
            })
            if Phase2ProgressCard.TitleLabel then
                pcall(function() Phase2ProgressCard.TitleLabel.Text = "??? Secret Quest Status" end)
            end
            if Phase2ProgressCard.BodyLabel then
                pcall(function() Phase2ProgressCard.BodyLabel.Text = qContent end)
            end
        end

        if Phase3ProgressCard then
            local domProg = AutoProgAPI.GetDominusFortuneProgress and AutoProgAPI.GetDominusFortuneProgress()
            local curStats = (AutoProgAPI.GetPlayerData and AutoProgAPI.GetPlayerData()) or {}
            local coinAmt = (curStats.Currency and curStats.Currency.Coins) or curStats.Coins or 0
            local spaceAmt = (curStats.Currency and curStats.Currency.SpaceCoins) or curStats.SpaceCoins or 0
            local stProg = AutoProgAPI.GetSkillTreeProgress and AutoProgAPI.GetSkillTreeProgress()
            local coinsBought = stProg and stProg.CoinsBought or 0
            local coinsTotal = stProg and stProg.CoinsTotal or 39
            local techBought = stProg and stProg.TechBought or 0
            local techTotal = stProg and stProg.TechTotal or 13

            local stContent = string.format(
                "👑 <b>Coins Skill Tree:</b> %d / %d (%s)\n" ..
                "💰 <b>Coins:</b> %s\n" ..
                "  • Dominus Hatch (+1 Pet): %s (80B)\n" ..
                "  • Dominus Luck (+15%%): %s (200B)\n" ..
                "  • Secret Seeker (+10%%): %s (400B)\n\n" ..
                "⚡ <b>Tech Skill Tree:</b> %d / %d (%s)\n" ..
                "🌌 <b>Tech Coins:</b> %s",
                coinsBought, coinsTotal, (coinsBought >= 39) and "✅ COMPLETE" or "FARMING",
                AutoProgAPI.FormatNumber(coinAmt),
                (domProg and domProg.HatchOwned) and "✅ OWNED" or "⏳",
                (domProg and domProg.LuckOwned) and "✅ OWNED" or "⏳",
                (domProg and domProg.SeekerOwned) and "✅ OWNED" or "⏳",
                techBought, techTotal, (techBought >= 13) and "✅ COMPLETE" or "FARMING",
                AutoProgAPI.FormatNumber(spaceAmt)
            )

            Phase3ProgressCard:Set({
                Title = "Skill Tree Progress (39/39 Coins & 13/13 Tech)",
                Content = stContent
            })
            if Phase3ProgressCard.TitleLabel then
                pcall(function() Phase3ProgressCard.TitleLabel.Text = "Skill Tree Progress (39/39 Coins & 13/13 Tech)" end)
            end
            if Phase3ProgressCard.BodyLabel then
                pcall(function() Phase3ProgressCard.BodyLabel.Text = stContent end)
            end
        end

        if Phase4CurrentEggCard or Phase4IndexStatsCard then
            local nextEgg, eggProg = ProgAPI.GetNextUnindexedEgg(
                State.IndexIgnoreMythicAndAbove ~= false,
                State.IndexUnlockNormal ~= false,
                State.IndexUnlockGold ~= false,
                State.IndexUnlockRainbow ~= false,
                State.IndexUnlockDarkMatter == true
            )

            if Phase4CurrentEggCard then
                local eggContent = ""
                if eggProg and nextEgg then
                    local missingList = {}
                    for _, m in ipairs(eggProg.MissingPets or {}) do
                        table.insert(missingList, string.format("• <b>%s</b> (%s) - %s", m.Name, m.Rarity, table.concat(m.MissingVariants, ", ")))
                    end
                    local missingDetails = #missingList > 0 and table.concat(missingList, "\n") or "None (All active requirements fulfilled or queued!)"

                    local skippedStr = ""
                    if eggProg.SkippedRareCount and eggProg.SkippedRareCount > 0 then
                        local sNames = {}
                        for _, s in ipairs(eggProg.SkippedRares or {}) do
                            table.insert(sNames, string.format("%s (%s)", s.Name, s.Rarity))
                        end
                        skippedStr = string.format("\n⏩ <b>Ignored Rares (Skipped):</b> %s", table.concat(sNames, ", "))
                    end

                    local queuedStr = ""
                    if eggProg.QueuedRainbows and #eggProg.QueuedRainbows > 0 then
                        local qNames = {}
                        for _, q in ipairs(eggProg.QueuedRainbows) do
                            table.insert(qNames, q.Name)
                        end
                        queuedStr = string.format("\n🌈 <b>Queued in Rainbow Machine (Cooking 30m):</b> %s", table.concat(qNames, ", "))
                    end

                    local stageStr = eggProg.IndexStage or "Index Progression"
                    eggContent = string.format(
                        "🎯 <b>Stage:</b> %s\n" ..
                        "🥚 <b>Target Egg:</b> %s\n" ..
                        "🏝️ <b>Island / World:</b> %s (%s)\n" ..
                        "💰 <b>Cost:</b> %s Clicks\n" ..
                        "📊 <b>Egg Progress:</b> %d / %d pets indexed (%d%%)%s%s\n\n" ..
                        "🔍 <b>Missing Pets to Index:</b>\n%s",
                        stageStr,
                        tostring(eggProg.DisplayName or nextEgg.name),
                        tostring(nextEgg.island or "Spawn"),
                        tostring(nextEgg.world or "Overworld"),
                        ProgAPI.FormatNumber(nextEgg.cost or 0),
                        eggProg.CompletedPetsCount or 0,
                        eggProg.TargetPetsCount or 0,
                        (eggProg.TargetPetsCount and eggProg.TargetPetsCount > 0) and math.floor(((eggProg.CompletedPetsCount or 0) / eggProg.TargetPetsCount) * 100) or 100,
                        skippedStr,
                        queuedStr,
                        missingDetails
                    )
                else
                    eggContent = "🎉 <b>ALL PROGRESSION EGGS INDEXED!</b>\nAll eligible Normal, Gold, and Rainbow variants are unlocked in the index!"
                end

                Phase4CurrentEggCard:Set({
                    Title = "Current Egg Index Progress",
                    Content = eggContent
                })
                if Phase4CurrentEggCard.TitleLabel then
                    pcall(function() Phase4CurrentEggCard.TitleLabel.Text = "Current Egg Index Progress" end)
                end
                if Phase4CurrentEggCard.BodyLabel then
                    pcall(function() Phase4CurrentEggCard.BodyLabel.Text = eggContent end)
                end
            end

            if Phase4IndexStatsCard and totalStats then
                local totalUnique = totalStats.ProgressionUniquePets or totalStats.TotalUniquePets or 269
                local normPct = math.clamp(math.floor(((totalStats.IndexedNormal or 0) / math.max(1, totalUnique)) * 100), 0, 100)
                local goldPct = math.clamp(math.floor(((totalStats.IndexedGolden or 0) / math.max(1, totalUnique)) * 100), 0, 100)
                local rainPct = math.clamp(math.floor(((totalStats.IndexedRainbow or 0) / math.max(1, totalUnique)) * 100), 0, 100)

                local targetGoal = (State and tonumber(State.IndexTargetTotal)) or 250
                local rainbowStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
                local cookingCount = (rainbowStatus and rainbowStatus.TotalCooking) or 0

                local statsContent = string.format(
                    "🎯 <b>Target Goal:</b> %d Total Index (Rainbow Optional)\n" ..
                    "📖 <b>Total Indexed:</b> %s / %d (Cooking 🌈: %d)\n\n" ..
                    "⚪ <b>Normal:</b> %d / %d (%d%%)\n" ..
                    "🟡 <b>Golden:</b> %d / %d (%d%%) [Prioritized]\n" ..
                    "🌈 <b>Rainbow:</b> %d / %d (%d%%)\n" ..
                    "✨ <b>Shiny:</b> %d\n" ..
                    "🌌 <b>Total Game Pets:</b> %d entries in index",
                    targetGoal,
                    ProgAPI.FormatNumber(totalStats.TotalIndexed or 0),
                    targetGoal,
                    cookingCount,
                    totalStats.IndexedNormal or 0, totalUnique, normPct,
                    totalStats.IndexedGolden or 0, totalUnique, goldPct,
                    totalStats.IndexedRainbow or 0, totalUnique, rainPct,
                    totalStats.IndexedShiny or 0,
                    totalStats.TotalUniquePets or 0
                )

                Phase4IndexStatsCard:Set({
                    Title = "Total Index Telemetry",
                    Content = statsContent
                })
                if Phase4IndexStatsCard.TitleLabel then
                    pcall(function() Phase4IndexStatsCard.TitleLabel.Text = "Total Index Telemetry" end)
                end
                if Phase4IndexStatsCard.BodyLabel then
                    pcall(function() Phase4IndexStatsCard.BodyLabel.Text = statsContent end)
                end
            end
        end

        if Phase5SkinCard then
            local skStatus = AutoProgAPI.GetClickSkinStatus and AutoProgAPI.GetClickSkinStatus()
            local skContent = ""
            if skStatus then
                local eqGoalStr = skStatus.EquippedGoalMet and "✅ (TARGET MET)" or "⏳ (REROLLING)"
                local penStr = "None"
                if skStatus.Pending then
                    penStr = string.format("+%d Egg, +%.1f%% Speed (%s)", skStatus.PendingEggHatch, skStatus.PendingHatchSpeed, skStatus.PendingGoalMet and "✅ MET" or "❌ Skip")
                end
                local gemStr = string.format("%s / %s (%s)", AutoProgAPI.FormatNumber(skStatus.CurrentGems), AutoProgAPI.FormatNumber(skStatus.GemsThreshold), skStatus.GemsThresholdMet and "✅ Ready" or "⏳ Saving")
                skContent = string.format(
                    "🟣 <b>Target Skin:</b> Ultimate (Purple, Requires 250 Pets)\n" ..
                    "🎯 <b>Target Stats:</b> +%d Egg Hatch & +%.1f%% Hatch Speed\n\n" ..
                    "👑 <b>Equipped Skin:</b> %s (%s)\n" ..
                    "  • Passives: +%d Egg Hatch\n" ..
                    "  • Boosts: +%.1f%% Hatch Speed\n\n" ..
                    "🎲 <b>Pending Roll:</b> %s\n" ..
                    "💎 <b>Gems Status:</b> %s\n" ..
                    "🏁 <b>Phase 5 Status:</b> %s",
                    (State and tonumber(State.ClickSkinTargetEggHatch)) or 3,
                    (State and tonumber(State.ClickSkinTargetHatchSpeed)) or 15,
                    tostring(skStatus.EquippedTier),
                    eqGoalStr,
                    skStatus.EquippedEggHatch,
                    skStatus.EquippedHatchSpeed,
                    penStr,
                    gemStr,
                    skStatus.GoalMet and "🎉 COMPLETE -> PHASE 6 ACTIVE" or (skStatus.GemsThresholdMet and "REROLLING..." or "SAVING GEMS")
                )
            else
                skContent = "Click Skin telemetry initializing..."
            end
            Phase5SkinCard:Set({
                Title = "Live Skin Status",
                Content = skContent
            })
            if Phase5SkinCard.TitleLabel then pcall(function() Phase5SkinCard.TitleLabel.Text = "Live Skin Status" end) end
            if Phase5SkinCard.BodyLabel then pcall(function() Phase5SkinCard.BodyLabel.Text = skContent end) end
        end

        if Phase6MythicCard then
            local isAllRainbow, mythicCount, totalSlots = false, 0, 0
            if AutoProgAPI.IsEquippedTeamAllRainbowMythic then
                isAllRainbow, mythicCount, totalSlots = AutoProgAPI.IsEquippedTeamAllRainbowMythic()
            end
            local mContent = string.format(
                "🧬 <b>Target Egg:</b> Matrix Egg (Tech World)\n" ..
                "🌈 <b>Full Rainbow Mythic Team:</b> %s (%d / %d slots)\n" ..
                "🗑️ <b>Mythic Pet Filter:</b> %s (Deletes non-mythics)\n" ..
                "⚒️ <b>Auto Golden & Rainbow Crafting:</b> %s",
                isAllRainbow and "✅ 100% COMPLETE" or "IN PROGRESS",
                mythicCount or 0,
                totalSlots or 0,
                State.AutoMythicFilter ~= false and "ACTIVE" or "OFF",
                State.AutoCraftMythics ~= false and "ACTIVE" or "OFF"
            )
            Phase6MythicCard:Set({
                Title = "Live Matrix Mythic Team Status",
                Content = mContent
            })
            if Phase6MythicCard.TitleLabel then pcall(function() Phase6MythicCard.TitleLabel.Text = "Live Matrix Mythic Team Status" end) end
            if Phase6MythicCard.BodyLabel then pcall(function() Phase6MythicCard.BodyLabel.Text = mContent end) end
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

-- THREAD 16: DEDICATED AUTO ACCEPT TRADE ENGINE
table.insert(threads, task.spawn(function()
    while isRunning do
        task.wait(0.2)
        if not isRunning then break end
        if State.AutoAcceptTrade ~= false and AutoProgAPI and AutoProgAPI.StepAutoTrade then
            pcall(AutoProgAPI.StepAutoTrade)
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
