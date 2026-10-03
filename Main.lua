--!strict
--==============================================================================
-- [CLICKER HUB] Main.lua
-- Feature-Packed Automation Hub for [⌛7H] Clicker Simulator!
-- Fully modularized: Auto Farm, Auto Hatch, Skill Tree, Upgrades, Rewards, Teleports
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = ReplicatedStorage:WaitForChild("Library", 10)
local Client = Library and Library:WaitForChild("Client", 5)

--==============================================================================
-- UNLOAD PREVIOUS INSTANCE (Safety Guard)
--==============================================================================
local Globals = (getgenv and getgenv()) or _G
if Globals.ClickerHub_Unload then
    pcall(Globals.ClickerHub_Unload)
end

--==============================================================================
-- LOAD WORKSPACE MODULES (Hybrid Local + GitHub Remote Fallback)
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
            warn("[Clicker Hub] Local compile error in " .. name .. ":", err)
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
            error("[Clicker Hub] Remote compile error in " .. name .. ": " .. tostring(err))
        end
    end

    error("[Clicker Hub] File not found in workspace or GitHub: " .. name)
end

local UILibrary = loadModule("UILibrary.lua")
local GameAPI = loadModule("GameAPI.lua")
local Configs = loadModule("Configs.lua")

-- Load saved configs
local cfg = Configs.Load()

--==============================================================================
-- HUB STATE & FLAGS
--==============================================================================
if _G.ClickerHubCleanup then
    pcall(_G.ClickerHubCleanup)
end

local isRunning = true
local threads = {}

_G.ClickerHubCleanup = function()
    isRunning = false
    for _, t in ipairs(threads) do
        pcall(task.cancel, t)
    end
    if GameAPI and GameAPI.StopBreakables then
        pcall(GameAPI.StopBreakables)
    end
end

local State = {
    -- Auto Prog & Speedrun Suite
    AutoProgMaster = (cfg.AutoProg and cfg.AutoProg.MasterEnabled ~= false),
    AutoMagmaSkin = true,

    -- Auto Farm
    AutoClick = (cfg.AutoClick and cfg.AutoClick.Enabled ~= false),
    ClickSpeed = (cfg.AutoClick and cfg.AutoClick.Speed) or 0.001,

    AutoRebirth = (cfg.AutoRebirth and cfg.AutoRebirth.Enabled ~= false),
    RebirthMode = (cfg.AutoRebirth and cfg.AutoRebirth.Mode) or "Max Rebirth",
    RebirthDelay = (cfg.AutoRebirth and cfg.AutoRebirth.Delay) or 0.25,

    AutoUnlockNextIsland = (cfg.AutoFarm and cfg.AutoFarm.AutoUnlockNextIsland ~= false),

    AutoEquipBest = (cfg.AutoPets and cfg.AutoPets.EquipBest ~= false),
    EquipInterval = (cfg.AutoPets and cfg.AutoPets.Interval) or 5,
    AutoGoldPets = (cfg.AutoPets and cfg.AutoPets.AutoGoldPets) or false,
    AutoRainbowPets = (cfg.AutoPets and cfg.AutoPets.AutoRainbowPets) or false,
    AutoClaimRainbowPets = (cfg.AutoPets and cfg.AutoPets.AutoClaimRainbow ~= false) or true,

    -- Pets Helper & Auto Gold Engine
    AutoOpenProgEggs = (cfg.AutoProg and cfg.AutoProg.AutoOpenEggs ~= false),
    AutoGold = (cfg.AutoProg and cfg.AutoProg.AutoGold ~= false),
    AutoCraftGolden = (cfg.AutoProg and cfg.AutoProg.AutoCraftGolden ~= false),
    ProtectCraftingPets = (cfg.AutoProg and cfg.AutoProg.ProtectCraftingPets ~= false),
    AutoCleanPets = (cfg.AutoProg and cfg.AutoProg.AutoCleanPets ~= false),
    KeepTopPets = (cfg.AutoProg and cfg.AutoProg.KeepTopPets) or 15,

    -- Auto Hatch
    AutoHatch = (cfg.AutoHatch and cfg.AutoHatch.Enabled) or false,
    SelectedEgg = (cfg.AutoHatch and cfg.AutoHatch.Egg) or "Best Affordable Egg",
    AutoTeleportToEgg = (cfg.AutoHatch and cfg.AutoHatch.AutoTeleportToEgg ~= false),
    HatchAmount = (cfg.AutoHatch and cfg.AutoHatch.Amount) or 1,
    HatchDelay = (cfg.AutoHatch and cfg.AutoHatch.Delay) or 0.05,

    -- Skill Tree & Breakables
    AutoBreakables = (cfg.SkillTree and cfg.SkillTree.AutoBreakables ~= false),
    Breakables_BestWorld = (cfg.SkillTree and cfg.SkillTree.BestWorld ~= false),
    Breakables_TargetWorld = (cfg.SkillTree and cfg.SkillTree.TargetWorld and cfg.SkillTree.TargetWorld ~= "Best Unlocked" and cfg.SkillTree.TargetWorld) or "Auto (Dynamic Smart)",
    Breakables_IgnoreBossChest = (cfg.SkillTree and cfg.SkillTree.IgnoreBossChest ~= false),
    BreakablesDelay = (cfg.SkillTree and cfg.SkillTree.Delay) or 0.05,
    AutoSkillTree = (cfg.SkillTree and cfg.SkillTree.AutoSkillTree ~= false),

    -- Auto Quest
    AutoQuest_Claim = (cfg.AutoQuest and cfg.AutoQuest.AutoClaim ~= false),
    AutoSecretQuests = (cfg.AutoQuest and cfg.AutoQuest.AutoSecretQuests ~= false),
    AutoQuest_Interval = (cfg.AutoQuest and cfg.AutoQuest.Interval) or 5,

    -- Upgrades
    AutoGemUpgrades = (cfg.Upgrades and cfg.Upgrades.GemUpgrades ~= false),
    AutoRebirthButtons = (cfg.Upgrades and cfg.Upgrades.RebirthButtons ~= false),
    AutoDoubleJump = (cfg.Upgrades and cfg.Upgrades.DoubleJump) or false,
    AutoMiniUpgrades = (cfg.Upgrades and cfg.Upgrades.MiniUpgrades ~= false),
    AutoRNGUpgrades = (cfg.Upgrades and cfg.Upgrades.RNGUpgrades) or false,

    -- Auto Items & Consumables
    AutoPotions = (cfg.AutoItems and cfg.AutoItems.AutoPotions ~= false),
    AutoFruits = (cfg.AutoItems and cfg.AutoItems.AutoFruits ~= false),
    AutoCraftPowerups = (cfg.AutoItems and cfg.AutoItems.AutoCraftPowerups) or false,
    Potion_Clicks = (cfg.AutoItems and cfg.AutoItems.ClicksPotion ~= false),
    Potion_HatchSpeed = (cfg.AutoItems and cfg.AutoItems.HatchSpeedPotion ~= false),
    Potion_Luck = (cfg.AutoItems and cfg.AutoItems.LuckPotion ~= false),
    Potion_Gems = (cfg.AutoItems and cfg.AutoItems.GemsPotion ~= false),
    Potion_ClicksSpeed = (cfg.AutoItems and cfg.AutoItems.ClicksSpeedPotion ~= false),

    -- Rewards & Misc
    AutoFreeGifts = (cfg.AutoRewards and cfg.AutoRewards.FreeGifts ~= false),
    AutoAchievements = (cfg.AutoRewards and cfg.AutoRewards.Achievements ~= false),
    AutoChests = (cfg.AutoRewards and cfg.AutoRewards.Chests ~= false),
    AutoDaily = (cfg.AutoRewards and cfg.AutoRewards.Daily ~= false),
    AutoWheel = (cfg.AutoRewards and cfg.AutoRewards.SpinWheel ~= false),
    AutoQuests = (cfg.AutoRewards and cfg.AutoRewards.Quests ~= false),
    AutoFinishedCrafts = (cfg.AutoRewards and cfg.AutoRewards.FinishedCrafts ~= false),
    RewardsInterval = (cfg.AutoRewards and cfg.AutoRewards.Interval) or 10,

    WalkSpeed = (cfg.Misc and cfg.Misc.WalkSpeed) or 16,
    JumpPower = (cfg.Misc and cfg.Misc.JumpPower) or 50,
    InfiniteJump = (cfg.Misc and cfg.Misc.InfiniteJump) or false,
    AntiAFK = (cfg.Misc and cfg.Misc.AntiAFK ~= false),

    SelectedTeleport = "Spawn",
    AutoProgress = false,
}

--==============================================================================
-- CREATE MAIN GUI WINDOW
--==============================================================================
local Window = UILibrary.CreateWindow({
    Title = "CLICKER HUB",
    SubTitle = "v1.1 • Clicker Simulator",
    ToggleKey = Enum.KeyCode.RightControl,
    Size = UDim2.new(0, 620, 0, 440)
})

if Window and Window.ScreenGui then
    Window.ScreenGui.Destroying:Connect(function()
        if _G.ClickerHubCleanup then
            pcall(_G.ClickerHubCleanup)
        end
    end)
end

--==============================================================================
-- 1. OVERVIEW TAB
--==============================================================================
local OverviewTab = Window:AddTab({ Title = "Overview", Icon = "📊" })

OverviewTab:AddSection("SESSION STATUS")
local StatCard = OverviewTab:AddParagraph({
    Title = "Player Information",
    Content = "Loading live game telemetry..."
})

OverviewTab:AddSection("QUICK ACTIONS")
OverviewTab:AddButton({
    Title = "🚀 Launch Auto Progression Speedrunner",
    Description = "Opens Clicker Hub Auto Prog to speedrun from zero to endgame automatically",
    Callback = function()
        if readfile and isfile and isfile("[CLICKER HUB]/AutoProg.lua") then
            local chunk = readfile("[CLICKER HUB]/AutoProg.lua")
            local fn = loadstring(chunk)
            if fn then fn() end
        else
            local ok, chunk = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main/AutoProg.lua")
            if ok and chunk then
                local fn = loadstring(chunk)
                if fn then fn() end
            end
        end
    end
})

OverviewTab:AddButton({
    Title = "Equip Best Pets",
    Description = "Instantly equips your most powerful pets",
    Callback = function()
        GameAPI.EquipBest()
        Window:Notify({ Title = "Pets", Content = "Best pets equipped!", Duration = 2 })
    end
})

OverviewTab:AddButton({
    Title = "Max Rebirth",
    Description = "Rebirths at your highest owned milestone button when ready",
    Callback = function()
        local info = GameAPI.GetMaxRebirthInfo()
        if info.CanAffordMax then
            GameAPI.RebirthMaxTarget()
            Window:Notify({ Title = "Rebirth", Content = "Max Rebirth executed! (+" .. GameAPI.FormatNumber(info.MaxAmount) .. ")", Duration = 2.5 })
        else
            Window:Notify({
                Title = "Rebirth",
                Content = string.format("Cannot afford Max Button #%d yet (%d%% of %s Clicks)", info.MaxButtonIndex, math.floor(info.Progress * 100), GameAPI.FormatNumber(info.MaxCost)),
                Duration = 3
            })
        end
    end
})

OverviewTab:AddButton({
    Title = "Claim All Rewards",
    Description = "Collects free gifts, daily rewards, achievements, and chests",
    Callback = function()
        GameAPI.ClaimAllFreeGifts()
        GameAPI.ClaimAllAchievements()
        GameAPI.ClaimAllChests()
        GameAPI.ClaimDaily()
        GameAPI.RollWheel()
        Window:Notify({ Title = "Rewards", Content = "All claimable rewards triggered!", Duration = 2.5 })
    end
})

--==============================================================================
-- 2. AUTO PROG TAB (Dedicated Auto Progression Suite - ALL TOGGLES ON BY DEFAULT)
--==============================================================================
local AutoProgTab = Window:AddTab({ Title = "Auto Prog", Icon = "🚀" })

AutoProgTab:AddSection("PROGRESSION CHECKS & TELEMETRY")
local ProgCheckCard = AutoProgTab:AddParagraph({
    Title = "Live Speedrun & Endgame Checks",
    Content = "Evaluating account progression..."
})

AutoProgTab:AddSection("SPEEDRUN CONTROLS (DEFAULT: ALL ON)")
AutoProgTab:AddToggle("AutoProgMasterToggle", {
    Title = "⚡ Master Auto Progression Engine",
    Description = "Full automated zero-to-hero speedrun: clicks, max rebirth, island rushing, and questline",
    Default = State.AutoProgMaster,
    Callback = function(val)
        State.AutoProgMaster = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.MasterEnabled = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoClickToggle_Prog", {
    Title = "Auto Click",
    Description = "Non-stop frame-tick clicking at ultra speed",
    Default = State.AutoClick,
    Callback = function(val)
        State.AutoClick = val
        if not cfg.AutoClick then cfg.AutoClick = {} end
        cfg.AutoClick.Enabled = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoRebirthToggle_Prog", {
    Title = "Smart Max Rebirth (Goal: 10 Qi Rebirths)",
    Description = "Rebirths at maximum affordable milestone. Tracks progress towards 10 Qi endgame requirement!",
    Default = State.AutoRebirth,
    Callback = function(val)
        State.AutoRebirth = val
        if not cfg.AutoRebirth then cfg.AutoRebirth = {} end
        cfg.AutoRebirth.Enabled = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoMagmaSkinToggle_Prog", {
    Title = "Auto Equip Magma Click Skin (+4 Egg Hatch, +20% Speed)",
    Description = "Automatically unlocks and equips Magma Click Skin once 10 Qi rebirths is reached",
    Default = State.AutoMagmaSkin,
    Callback = function(val)
        State.AutoMagmaSkin = val
    end
})

AutoProgTab:AddToggle("AutoUnlockIslandToggle_Prog", {
    Title = "Auto Unlock & Advance Islands",
    Description = "Automatically purchases next island and teleports there when clicks cost is met",
    Default = State.AutoUnlockNextIsland,
    Callback = function(val)
        State.AutoUnlockNextIsland = val
        if not cfg.AutoFarm then cfg.AutoFarm = {} end
        cfg.AutoFarm.AutoUnlockNextIsland = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoFreeGiftsToggle_Prog", {
    Title = "Auto Collect Free Gifts & Chests",
    Description = "Automatically claims all 12 free gifts, daily rewards, achievements, and chests",
    Default = State.AutoFreeGifts,
    Callback = function(val)
        State.AutoFreeGifts = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.FreeGifts = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoPotionsToggle_Prog", {
    Title = "Auto Use Potions & Fruits",
    Description = "Automatically consumes your best owned Clicks, Speed, Luck, and Gems potions",
    Default = State.AutoPotions,
    Callback = function(val)
        State.AutoPotions = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.AutoPotions = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoSkillTreeToggle_Prog", {
    Title = "Auto Skill Tree (Todo Skill Tree Check: Tech -> Coins)",
    Description = "Farms breakables and buys Tech World perks first, then completes Overworld Coins tree",
    Default = State.AutoSkillTree,
    Callback = function(val)
        State.AutoSkillTree = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.AutoSkillTree = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoSecretQuestsToggle_Prog", {
    Title = "Auto ??? Secret Dominus Quest",
    Description = "Automatically gathers 10 feathers, hatches 2,500 basic eggs, and claims the Dominus door",
    Default = State.AutoSecretQuests,
    Callback = function(val)
        State.AutoSecretQuests = val
        if not cfg.AutoQuest then cfg.AutoQuest = {} end
        cfg.AutoQuest.AutoSecretQuests = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoMapUpgradesToggle_Prog", {
    Title = "Auto Buy Map Upgrades (+1 Pet Slot)",
    Description = "Buys island mini upgrade pads: +1 pet equip slot, storage, and walkspeed",
    Default = State.AutoMiniUpgrades,
    Callback = function(val)
        State.AutoMiniUpgrades = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.MiniUpgrades = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoGemUpgradesToggle_Prog", {
    Title = "Auto Desert Gem Machine & Rebirth Shop",
    Description = "Spends rebirth gems on Click, Combo, Hatch speed upgrades, and Rebirth buttons",
    Default = State.AutoGemUpgrades,
    Callback = function(val)
        State.AutoGemUpgrades = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.GemUpgrades = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoEquipBestToggle_Prog", {
    Title = "Auto Equip Best Pets",
    Description = "Keeps your highest multiplier pets equipped at all times",
    Default = State.AutoEquipBest,
    Callback = function(val)
        State.AutoEquipBest = val
        if not cfg.AutoPets then cfg.AutoPets = {} end
        cfg.AutoPets.EquipBest = val
        Configs.Save()
    end
})

AutoProgTab:AddSection("PETS HELPER & GOLDEN ENGINE")
AutoProgTab:AddToggle("AutoOpenEggsToggle_Prog", {
    Title = "Auto Open Best Affordable Eggs",
    Description = "Automatically purchases and hatches the best affordable egg in the unlocked world",
    Default = State.AutoOpenProgEggs,
    Callback = function(val)
        State.AutoOpenProgEggs = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.AutoOpenEggs = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoGoldToggle_Prog", {
    Title = "Auto Gold (Full Golden Team)",
    Description = "Keeps opening best eggs & crafts in Golden Machine with 100% chance priority until all equipped slots are Golden!",
    Default = State.AutoGold,
    Callback = function(val)
        State.AutoGold = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.AutoGold = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Auto Gold", Content = "Auto Gold enabled: Opening best eggs until all equipped are Golden!", Duration = 3 })
        end
    end
})

AutoProgTab:AddToggle("AutoCraftGoldenToggle_Prog", {
    Title = "Auto Craft Golden (100% Guaranteed Priority)",
    Description = "Automatically converts batches of normal pets into Golden pets with guaranteed 100% success rate",
    Default = State.AutoCraftGolden,
    Callback = function(val)
        State.AutoCraftGolden = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.AutoCraftGolden = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("ProtectCraftingPetsToggle_Prog", {
    Title = "Protect Crafting Candidates (Do Not Delete)",
    Description = "Prevents duplicate normal pets from being deleted so they can reach the 6-pet Golden crafting threshold",
    Default = State.ProtectCraftingPets,
    Callback = function(val)
        State.ProtectCraftingPets = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.ProtectCraftingPets = val
        Configs.Save()
    end
})

AutoProgTab:AddToggle("AutoCleanPetsToggle_Prog", {
    Title = "Auto Clean Weak Pets",
    Description = "Automatically deletes obsolete weak pets while keeping all Golden, Rainbow, Special, and crafting candidate pets safe",
    Default = State.AutoCleanPets,
    Callback = function(val)
        State.AutoCleanPets = val
        if not cfg.AutoProg then cfg.AutoProg = {} end
        cfg.AutoProg.AutoCleanPets = val
        Configs.Save()
    end
})

AutoProgTab:AddSection("QUICK CHECKS & ACTIONS")
AutoProgTab:AddButton({
    Title = "Craft Golden Pets Now (100% Guaranteed)",
    Description = "Immediately runs 100% guaranteed Golden crafting on eligible candidate batches",
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

AutoProgTab:AddButton({
    Title = "Clean Pet Inventory Now",
    Description = "Cleans obsolete pets while keeping top pets and crafting candidates safe",
    Callback = function()
        local cleaned = GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
        Window:Notify({ Title = "Pet Cleaner", Content = string.format("Cleaned %d obsolete pets!", cleaned), Duration = 2.5 })
    end
})

AutoProgTab:AddButton({
    Title = "Claim All Free Gifts Now",
    Description = "Instantly collects all free gifts, daily rewards, and chests",
    Callback = function()
        GameAPI.ClaimAllFreeGifts()
        GameAPI.ClaimDaily()
        GameAPI.ClaimAllChests()
        GameAPI.ClaimAllAchievements()
        GameAPI.RollWheel()
        Window:Notify({ Title = "Free Gifts", Content = "All claimable gifts triggered!", Duration = 2.5 })
    end
})

AutoProgTab:AddButton({
    Title = "Consume Best Potions Now",
    Description = "Uses highest tier Clicks, Hatch Speed, Luck, and Gems potions",
    Callback = function()
        local used = GameAPI.UseAllBestPotions()
        Window:Notify({ Title = "Potions", Content = string.format("Consumed %d best potion(s)!", used), Duration = 2.5 })
    end
})

AutoProgTab:AddButton({
    Title = "Check & Equip Magma Skin",
    Description = "Checks 10 Qi rebirth requirement and equips Magma Click Skin (+4 Egg Hatch, +20% Speed)",
    Callback = function()
        local ok, msg = GameAPI.CheckAndEquipMagmaSkin()
        Window:Notify({ Title = "Click Skin", Content = tostring(msg), Duration = 3 })
    end
})

--==============================================================================
-- 3. AUTO FARM TAB
--==============================================================================
local FarmTab = Window:AddTab({ Title = "Auto Farm", Icon = "⚡" })

FarmTab:AddSection("AUTO CLICKER")
FarmTab:AddToggle("AutoClickToggle", {
    Title = "Auto Click",
    Description = "Repeatedly sends clicks to the server at ultra speed",
    Default = State.AutoClick,
    Callback = function(val)
        State.AutoClick = val
        if not cfg.AutoClick then cfg.AutoClick = {} end
        cfg.AutoClick.Enabled = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Auto Clicker", Content = "Started clicking!", Duration = 2 })
        end
    end
})

FarmTab:AddSection("AUTO REBIRTH")
FarmTab:AddToggle("AutoRebirthToggle", {
    Title = "Auto Rebirth",
    Description = "Automatically triggers rebirths when affordable",
    Default = State.AutoRebirth,
    Callback = function(val)
        State.AutoRebirth = val
        if not cfg.AutoRebirth then cfg.AutoRebirth = {} end
        cfg.AutoRebirth.Enabled = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Auto Rebirth", Content = "Auto rebirth active (" .. State.RebirthMode .. ")", Duration = 2 })
        end
    end
})

FarmTab:AddDropdown("RebirthModeDropdown", {
    Title = "Rebirth Mode",
    Description = "Select target rebirth behavior",
    Values = { "Max Rebirth", "Best Affordable", "Button 1", "Button 2", "Button 3" },
    Default = State.RebirthMode,
    Callback = function(val)
        State.RebirthMode = val
        if not cfg.AutoRebirth then cfg.AutoRebirth = {} end
        cfg.AutoRebirth.Mode = val
        Configs.Save()
    end
})

local RebirthStatusCard = FarmTab:AddParagraph({
    Title = "Rebirth Milestone Telemetry",
    Content = "Evaluating highest owned rebirth button..."
})

FarmTab:AddSection("AUTO ISLAND (MAP PROGRESSION)")
local IslandStatusCard = FarmTab:AddParagraph({
    Title = "Next Island Status",
    Content = "Calculating next world..."
})

FarmTab:AddToggle("AutoUnlockIslandToggle", {
    Title = "Auto Unlock & Advance Islands",
    Description = "When you can afford the next locked island, automatically buys and teleports you there!",
    Default = State.AutoUnlockNextIsland,
    Callback = function(val)
        State.AutoUnlockNextIsland = val
        if not cfg.AutoFarm then cfg.AutoFarm = {} end
        cfg.AutoFarm.AutoUnlockNextIsland = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Island Progression", Content = "Auto Unlock Islands Enabled!", Duration = 2.5 })
        end
    end
})

FarmTab:AddButton({
    Title = "Unlock & Teleport to Next Island Now",
    Description = "Purchases the next locked island and teleports there if you have enough clicks",
    Callback = function()
        local ok, msg = GameAPI.UnlockAndTeleportToNextIsland()
        if ok then
            Window:Notify({ Title = "Island Unlocked!", Content = "🌟 " .. tostring(msg), Duration = 3 })
        else
            Window:Notify({ Title = "Island Progression", Content = tostring(msg), Duration = 3 })
        end
    end
})

FarmTab:AddSection("PET AUTOMATION")
FarmTab:AddToggle("AutoEquipPetsToggle", {
    Title = "Auto Equip Best Pets",
    Description = "Continuously keeps strongest hatched pets equipped",
    Default = State.AutoEquipBest,
    Callback = function(val)
        State.AutoEquipBest = val
        if not cfg.AutoPets then cfg.AutoPets = {} end
        cfg.AutoPets.EquipBest = val
        Configs.Save()
    end
})

FarmTab:AddToggle("AutoGoldPetsToggle", {
    Title = "Auto Craft Golden Pets",
    Description = "Automatically converts batches of 5-6 duplicate normal pets into Golden pets",
    Default = State.AutoGoldPets,
    Callback = function(val)
        State.AutoGoldPets = val
        if not cfg.AutoPets then cfg.AutoPets = {} end
        cfg.AutoPets.AutoGoldPets = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Pet Crafting", Content = "Auto Craft Golden Pets Active!", Duration = 2 })
        end
    end
})

FarmTab:AddToggle("AutoRainbowPetsToggle", {
    Title = "Auto Craft Rainbow Pets",
    Description = "Automatically converts batches of 5-6 duplicate Golden pets into Rainbow pets",
    Default = State.AutoRainbowPets,
    Callback = function(val)
        State.AutoRainbowPets = val
        if not cfg.AutoPets then cfg.AutoPets = {} end
        cfg.AutoPets.AutoRainbowPets = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Pet Crafting", Content = "Auto Craft Rainbow Pets Active!", Duration = 2 })
        end
    end
})

FarmTab:AddToggle("AutoClaimRainbowPetsToggle", {
    Title = "Auto Claim Rainbow Pets",
    Description = "Automatically claims completed Rainbow pets from the machine immediately upon finishing",
    Default = State.AutoClaimRainbowPets,
    Callback = function(val)
        State.AutoClaimRainbowPets = val
        if not cfg.AutoPets then cfg.AutoPets = {} end
        cfg.AutoPets.AutoClaimRainbow = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Pet Crafting", Content = "Auto Claim Rainbow Pets Active!", Duration = 2 })
        end
    end
})

FarmTab:AddButton({
    Title = "Claim Finished Rainbow Pets Now",
    Description = "Checks the Rainbow machine and claims all completed pet slots right now",
    Callback = function()
        local claimed = GameAPI.ClaimRainbowPets()
        Window:Notify({
            Title = "Rainbow Machine",
            Content = claimed > 0 and string.format("Claimed %d finished Rainbow pet(s)!", claimed) or "No completed Rainbow pets ready to claim.",
            Duration = 3
        })
    end
})

FarmTab:AddButton({
    Title = "Craft All Golden & Rainbow Pets Now",
    Description = "Instantly converts all eligible duplicates into Golden and Rainbow pets",
    Callback = function()
        local gCount = GameAPI.CraftGoldenPets()
        local rCount = GameAPI.CraftRainbowPets()
        Window:Notify({
            Title = "Pet Crafting",
            Content = string.format("Crafted %d Golden and %d Rainbow pets!", gCount, rCount),
            Duration = 3
        })
    end
})

FarmTab:AddButton({
    Title = "Unequip All Pets",
    Description = "Unequips all currently equipped pets",
    Callback = function()
        GameAPI.UnequipAll()
        Window:Notify({ Title = "Pets", Content = "Unequipped all pets", Duration = 2 })
    end
})

--==============================================================================
-- 3. AUTO HATCH TAB
--==============================================================================
local HatchTab = Window:AddTab({ Title = "Auto Hatch", Icon = "🥚" })

local eggsList = GameAPI.GetEggList()
HatchTab:AddSection("EGG CONFIGURATION")
local EggDropdown = HatchTab:AddDropdown("EggDropdown", {
    Title = "Target Egg",
    Description = "Select which egg you want to hatch (Defaults to Best Affordable)",
    Values = eggsList,
    Default = State.SelectedEgg,
    Callback = function(val)
        State.SelectedEgg = val
        if not cfg.AutoHatch then cfg.AutoHatch = {} end
        cfg.AutoHatch.Egg = val
        Configs.Save()
    end
})

HatchTab:AddToggle("AutoTeleportEggToggle", {
    Title = "Auto Teleport to Egg",
    Description = "Automatically teleports your character right in front of the egg platform before hatching",
    Default = State.AutoTeleportToEgg,
    Callback = function(val)
        State.AutoTeleportToEgg = val
        if not cfg.AutoHatch then cfg.AutoHatch = {} end
        cfg.AutoHatch.AutoTeleportToEgg = val
        Configs.Save()
    end
})

HatchTab:AddDropdown("HatchAmountDropdown", {
    Title = "Hatch Quantity",
    Description = "Number of eggs to open per roll",
    Values = { "1 Egg", "3 Eggs" },
    Default = State.HatchAmount == 3 and "3 Eggs" or "1 Egg",
    Callback = function(val)
        State.HatchAmount = val == "3 Eggs" and 3 or 1
        if not cfg.AutoHatch then cfg.AutoHatch = {} end
        cfg.AutoHatch.Amount = State.HatchAmount
        Configs.Save()
    end
})

HatchTab:AddSection("AUTOMATION")
local EggStatusCard = HatchTab:AddParagraph({
    Title = "Egg Status",
    Content = "Evaluating target egg..."
})

HatchTab:AddToggle("AutoHatchToggle", {
    Title = "Enable Auto Hatch",
    Description = "Automatically purchases and hatches selected egg",
    Default = State.AutoHatch,
    Callback = function(val)
        State.AutoHatch = val
        if not cfg.AutoHatch then cfg.AutoHatch = {} end
        cfg.AutoHatch.Enabled = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Auto Hatch", Content = "Now hatching: " .. State.SelectedEgg, Duration = 2 })
        end
    end
})

HatchTab:AddButton({
    Title = "Hatch Selected Egg Now",
    Description = "Triggers an instant single purchase of the configured egg",
    Callback = function()
        local eggName = State.SelectedEgg
        if eggName == "Best Affordable Egg" then
            local best = GameAPI.GetBestAffordableEgg()
            eggName = best and best.name or "BasicEgg"
        end
        if State.AutoTeleportToEgg then
            GameAPI.TeleportToEgg(eggName)
            task.wait(0.2)
        end
        local ok, msg = GameAPI.OpenEgg(eggName, State.HatchAmount)
        Window:Notify({ Title = "Egg Hatch", Content = tostring(msg), Duration = 2 })
    end
})

--==============================================================================
-- 4. SKILL TREE & BREAKABLES TAB (NEW)
--==============================================================================
local SkillTreeTab = Window:AddTab({ Title = "Skill Tree", Icon = "🌳" })

SkillTreeTab:AddSection("BREAKABLES FARMING (COINS)")
local BreakablesStatusCard = SkillTreeTab:AddParagraph({
    Title = "Breakables & Coins Status",
    Content = "Checking breakable zones..."
})

SkillTreeTab:AddToggle("AutoBreakablesToggle", {
    Title = "Auto Break Breakables",
    Description = "Continuously attacks breakables in the arena to farm Coins for the Skill Tree",
    Default = State.AutoBreakables,
    Callback = function(val)
        State.AutoBreakables = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.AutoBreakables = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Breakables", Content = "Auto Breakables Started!", Duration = 2 })
        else
            GameAPI.StopBreakables()
            Window:Notify({ Title = "Breakables", Content = "Auto Breakables Stopped & Cleaned Up!", Duration = 2 })
        end
    end
})

SkillTreeTab:AddDropdown("BreakablesTargetWorldDropdown", {
    Title = "Target World",
    Description = "Auto Dynamic routes Tech World until finished, then automatically moves to Coins for faster progress!",
    Values = {"Auto (Dynamic Smart)", "Coins World (Heaven)", "Tech World (Fragment)", "Fragment", "Spaceship", "Base", "Heaven", "Volcano", "Candy", "Forest"},
    Default = State.Breakables_TargetWorld,
    Callback = function(val)
        State.Breakables_TargetWorld = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.TargetWorld = val
        Configs.Save()
    end
})

SkillTreeTab:AddToggle("BreakablesIgnoreBossToggle", {
    Title = "Ignore Boss Chest",
    Description = "Skips giant boss chests so attacks focus only on regular breakable boxes",
    Default = State.Breakables_IgnoreBossChest,
    Callback = function(val)
        State.Breakables_IgnoreBossChest = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.IgnoreBossChest = val
        Configs.Save()
    end
})

SkillTreeTab:AddToggle("BreakablesBestWorldToggle", {
    Title = "Auto TP to Target World",
    Description = "Automatically teleports player to target world arena when breakables are enabled",
    Default = State.Breakables_BestWorld,
    Callback = function(val)
        State.Breakables_BestWorld = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.BestWorld = val
        Configs.Save()
    end
})

SkillTreeTab:AddButton({
    Title = "Teleport to Best Breakables Arena",
    Description = "Warps character directly to the dynamic target breakables arena",
    Callback = function()
        local bestWorld = GameAPI.GetBestBreakableIsland(State.Breakables_TargetWorld)
        if bestWorld then
            GameAPI.TeleportToIsland(bestWorld)
            task.wait(0.5)
            local ok = GameAPI.TeleportToBreakableZone(bestWorld)
            if ok then
                Window:Notify({ Title = "Breakables", Content = "Warped to " .. bestWorld .. " Arena!", Duration = 2.5 })
            else
                Window:Notify({ Title = "Breakables", Content = "Warped to " .. bestWorld, Duration = 2 })
            end
        else
            Window:Notify({ Title = "Breakables", Content = "No breakables worlds unlocked yet.", Duration = 2.5 })
        end
    end
})

SkillTreeTab:AddSection("SKILL TREE AUTOMATION")
SkillTreeTab:AddToggle("AutoSkillTreeToggle", {
    Title = "Auto Buy Skill Tree Perks",
    Description = "Automatically purchases all unlocked and affordable perks in the Skill Tree (Default & RNG trees)",
    Default = State.AutoSkillTree,
    Callback = function(val)
        State.AutoSkillTree = val
        if not cfg.SkillTree then cfg.SkillTree = {} end
        cfg.SkillTree.AutoSkillTree = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Skill Tree", Content = "Auto Skill Tree Perks Enabled!", Duration = 2 })
        end
    end
})

SkillTreeTab:AddButton({
    Title = "Buy All Affordable Perks Now",
    Description = "Purchases any unlocked and affordable Skill Tree perks immediately",
    Callback = function()
        local count = GameAPI.BuyAffordableSkillTree()
        Window:Notify({ Title = "Skill Tree", Content = "Purchased " .. tostring(count) .. " skill tree perks!", Duration = 2.5 })
    end
})

--==============================================================================
-- 5. UPGRADES TAB (NEW)
--==============================================================================
local UpgradesTab = Window:AddTab({ Title = "Upgrades", Icon = "💎" })

UpgradesTab:AddSection("GEM UPGRADES")
UpgradesTab:AddToggle("AutoGemUpgradesToggle", {
    Title = "Auto Buy Gem Upgrades",
    Description = "Automatically purchases Click Multiplier, Hatch Speed, Combo & Crit Chance using Gems",
    Default = State.AutoGemUpgrades,
    Callback = function(val)
        State.AutoGemUpgrades = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.GemUpgrades = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Gem Upgrades", Content = "Auto Gem Upgrades Enabled!", Duration = 2 })
        end
    end
})

UpgradesTab:AddButton({
    Title = "Buy All Gem Upgrades Now",
    Description = "Purchases all currently affordable Gem upgrades immediately",
    Callback = function()
        local count = GameAPI.BuyAffordableGemUpgrades()
        Window:Notify({ Title = "Gem Upgrades", Content = "Purchased " .. tostring(count) .. " gem upgrades!", Duration = 2.5 })
    end
})

UpgradesTab:AddSection("REBIRTH SHOP BUTTONS")
UpgradesTab:AddToggle("AutoRebirthButtonsToggle", {
    Title = "Auto Buy Rebirth Buttons (Gems)",
    Description = "Automatically purchases Rebirth Buttons (Buttons 4-30) as new islands are unlocked",
    Default = State.AutoRebirthButtons,
    Callback = function(val)
        State.AutoRebirthButtons = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.RebirthButtons = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Rebirth Shop", Content = "Auto Buy Rebirth Buttons Enabled!", Duration = 2 })
        end
    end
})

UpgradesTab:AddButton({
    Title = "Buy Next Rebirth Button",
    Description = "Purchases the next available rebirth milestone button with Gems",
    Callback = function()
        local ok = GameAPI.BuyNextRebirthButton()
        if ok then
            Window:Notify({ Title = "Rebirth Shop", Content = "Successfully bought new Rebirth Button!", Duration = 2.5 })
        else
            Window:Notify({ Title = "Rebirth Shop", Content = "Not affordable or island requirement not met.", Duration = 2.5 })
        end
    end
})

UpgradesTab:AddSection("MOBILITY UPGRADES")
UpgradesTab:AddToggle("AutoDoubleJumpToggle", {
    Title = "Auto Buy Double Jump",
    Description = "Automatically purchases Double Jump upgrades with Gems as islands unlock",
    Default = State.AutoDoubleJump,
    Callback = function(val)
        State.AutoDoubleJump = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.DoubleJump = val
        Configs.Save()
    end
})

UpgradesTab:AddButton({
    Title = "Buy Next Double Jump",
    Description = "Purchases the next Double Jump upgrade tier with Gems",
    Callback = function()
        local ok = GameAPI.BuyNextDoubleJump()
        if ok then
            Window:Notify({ Title = "Double Jump", Content = "Purchased next jump level!", Duration = 2.5 })
        else
            Window:Notify({ Title = "Double Jump", Content = "Not affordable or island requirements not met.", Duration = 2.5 })
        end
    end
})

UpgradesTab:AddSection("PERMANENT SLOTS (MINI UPGRADES)")
UpgradesTab:AddToggle("AutoMiniUpgradesToggle", {
    Title = "Auto Buy Mini Upgrades",
    Description = "Automatically purchases permanent +1 Pet Equip slot, +100 Pet Storage, WalkSpeed, and AutoClicker",
    Default = State.AutoMiniUpgrades,
    Callback = function(val)
        State.AutoMiniUpgrades = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.MiniUpgrades = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Mini Upgrades", Content = "Auto Mini Upgrades Enabled!", Duration = 2 })
        end
    end
})

UpgradesTab:AddButton({
    Title = "Buy All Mini Upgrades Now",
    Description = "Instantly buys all unowned Mini Upgrades (Pet Equip slot, +100 Storage, etc.)",
    Callback = function()
        local count = GameAPI.BuyAffordableMiniUpgrades()
        Window:Notify({ Title = "Mini Upgrades", Content = "Purchased " .. tostring(count) .. " mini upgrades!", Duration = 2.5 })
    end
})

UpgradesTab:AddSection("RNG UPGRADES (PIXEL COINS)")
UpgradesTab:AddToggle("AutoRNGUpgradesToggle", {
    Title = "Auto Buy RNG Upgrades",
    Description = "Automatically purchases Breakable Health, Luck Multiplier, and Pixel Coin upgrades",
    Default = State.AutoRNGUpgrades,
    Callback = function(val)
        State.AutoRNGUpgrades = val
        if not cfg.Upgrades then cfg.Upgrades = {} end
        cfg.Upgrades.RNGUpgrades = val
        Configs.Save()
    end
})

UpgradesTab:AddButton({
    Title = "Buy Max RNG Upgrades Now",
    Description = "Instantly purchases max affordable tiers for all RNG upgrades",
    Callback = function()
        local count = GameAPI.BuyAffordableRNGUpgrades()
        Window:Notify({ Title = "RNG Upgrades", Content = "Upgraded " .. tostring(count) .. " RNG perks!", Duration = 2.5 })
    end
})

UpgradesTab:AddSection("MACHINE TELEPORTS")
UpgradesTab:AddButton({
    Title = "Teleport to Upgrades Machine",
    Description = "Warps character directly in front of the Upgrades Machine",
    Callback = function()
        local ok = GameAPI.TeleportToMachine("Upgrades")
        if ok then
            Window:Notify({ Title = "Upgrades", Content = "Warped to Upgrades Machine!", Duration = 2.5 })
        else
            Window:Notify({ Title = "Upgrades", Content = "Could not find Upgrades Machine.", Duration = 2.5 })
        end
    end
})

--==============================================================================
-- 6. ITEMS & POWERUPS TAB
--==============================================================================
local ItemsTab = Window:AddTab({ Title = "Items", Icon = "🧪" })

ItemsTab:AddSection("CONSUMABLE BOOSTS (POTIONS)")
local PotionsStatusCard = ItemsTab:AddParagraph({
    Title = "Active Potion Boosts",
    Content = "Evaluating active potion durations..."
})

ItemsTab:AddToggle("AutoPotionsToggle", {
    Title = "Auto Consume Potions",
    Description = "Automatically uses highest tier potions when duration expires (< 20s remaining)",
    Default = State.AutoPotions,
    Callback = function(val)
        State.AutoPotions = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.AutoPotions = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Potions", Content = "Auto Consume Potions Active!", Duration = 2 })
        end
    end
})

ItemsTab:AddToggle("PotionClicksToggle", {
    Title = "Include Clicks Potion",
    Description = "Automatically uses Clicks Potions",
    Default = State.Potion_Clicks,
    Callback = function(val)
        State.Potion_Clicks = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.ClicksPotion = val
        Configs.Save()
    end
})

ItemsTab:AddToggle("PotionHatchToggle", {
    Title = "Include Hatch Speed Potion",
    Description = "Automatically uses Hatch Speed Potions",
    Default = State.Potion_HatchSpeed,
    Callback = function(val)
        State.Potion_HatchSpeed = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.HatchSpeedPotion = val
        Configs.Save()
    end
})

ItemsTab:AddToggle("PotionLuckToggle", {
    Title = "Include Luck Potion",
    Description = "Automatically uses Luck Potions",
    Default = State.Potion_Luck,
    Callback = function(val)
        State.Potion_Luck = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.LuckPotion = val
        Configs.Save()
    end
})

ItemsTab:AddToggle("PotionGemsToggle", {
    Title = "Include Gems Potion",
    Description = "Automatically uses Gems Potions",
    Default = State.Potion_Gems,
    Callback = function(val)
        State.Potion_Gems = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.GemsPotion = val
        Configs.Save()
    end
})

ItemsTab:AddToggle("PotionSpeedToggle", {
    Title = "Include Clicks Speed Potion",
    Description = "Automatically uses Clicks Speed Potions",
    Default = State.Potion_ClicksSpeed,
    Callback = function(val)
        State.Potion_ClicksSpeed = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.ClicksSpeedPotion = val
        Configs.Save()
    end
})

ItemsTab:AddButton({
    Title = "Use All Best Potions Now",
    Description = "Instantly uses 1 of your highest tier for each enabled potion type",
    Callback = function()
        local count = GameAPI.UseAllBestPotions()
        Window:Notify({ Title = "Potions", Content = "Consumed " .. tostring(count) .. " best potions!", Duration = 2.5 })
    end
})

ItemsTab:AddSection("FRUITS CONSUMABLES")
local FruitsStatusCard = ItemsTab:AddParagraph({
    Title = "Fruit Buffs Status",
    Content = "Evaluating fruit stacks..."
})

ItemsTab:AddToggle("AutoFruitsToggle", {
    Title = "Auto Eat Fruits",
    Description = "Automatically consumes Apple, Blueberry, Strawberry & Watermelon up to 10x stack limit",
    Default = State.AutoFruits,
    Callback = function(val)
        State.AutoFruits = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.AutoFruits = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Fruits", Content = "Auto Eat Fruits Active!", Duration = 2 })
        end
    end
})

ItemsTab:AddButton({
    Title = "Eat All Available Fruits Now",
    Description = "Eats all fruits in your inventory up to maximum stack limit",
    Callback = function()
        local count = GameAPI.UseAllFruits()
        Window:Notify({ Title = "Fruits", Content = "Consumed " .. tostring(count) .. " fruits!", Duration = 2.5 })
    end
})

ItemsTab:AddSection("POWERUPS CRAFTING (BREWING MACHINE)")
local BrewingStatusCard = ItemsTab:AddParagraph({
    Title = "Brewing Slots Status",
    Content = "Evaluating brewing machine slots..."
})

ItemsTab:AddToggle("AutoCraftPowerupsToggle", {
    Title = "Auto Craft Powerups",
    Description = "Automatically brews the highest tier affordable potion & enchant recipes in free slots",
    Default = State.AutoCraftPowerups,
    Callback = function(val)
        State.AutoCraftPowerups = val
        if not cfg.AutoItems then cfg.AutoItems = {} end
        cfg.AutoItems.AutoCraftPowerups = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Crafting", Content = "Auto Craft Powerups Active!", Duration = 2 })
        end
    end
})

ItemsTab:AddButton({
    Title = "Craft All Affordable Recipes Now",
    Description = "Fills all available brewing slots with the best affordable potion recipes",
    Callback = function()
        local count = GameAPI.AutoCraftPowerups()
        Window:Notify({ Title = "Crafting", Content = "Started brewing " .. tostring(count) .. " powerup recipes!", Duration = 2.5 })
    end
})

--==============================================================================
-- 7. PREMIUM TAB (LOCKED FOR REWORK)
--==============================================================================
local PremiumTab = Window:AddTab({ Title = "Premium", Icon = "⭐" })

PremiumTab:AddSection("24/7 AUTO PROGRESSION (LOCKED)")
PremiumTab:AddParagraph({
    Title = "🔒 Auto Progress Locked (Under Rework)",
    Content = "Auto Progress is currently locked for maintenance and refactoring as requested.\n\nAll progression systems have been separated into dedicated, customizable tabs:\n• Auto Farm: Clicking, Rebirth, and Island Progression\n• Auto Hatch: Best Egg & Auto Teleport\n• Skill Tree: Breakables & Perks\n• Upgrades: Gem & Rebirth Shop"
})

PremiumTab:AddToggle("AutoProgressLockedToggle", {
    Title = "Enable Auto Progress (Locked)",
    Description = "Currently locked for rework",
    Default = false,
    Callback = function(val)
        Window:Notify({ Title = "Locked", Content = "Auto Progress is currently locked for rework.", Duration = 3 })
    end
})

--==============================================================================
-- 7. REWARDS & COLLECTIBLES TAB
--==============================================================================
local RewardsTab = Window:AddTab({ Title = "Rewards", Icon = "🎁" })

RewardsTab:AddSection("AUTOMATIC REWARDS")
RewardsTab:AddToggle("AutoFreeGiftsToggle", {
    Title = "Auto Claim Free Gifts",
    Description = "Continuously claims all 12 timed play gifts as they unlock",
    Default = State.AutoFreeGifts,
    Callback = function(val)
        State.AutoFreeGifts = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.FreeGifts = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoAchievementsToggle", {
    Title = "Auto Claim Achievements",
    Description = "Automatically claims completed achievements for free gems",
    Default = State.AutoAchievements,
    Callback = function(val)
        State.AutoAchievements = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.Achievements = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoChestsToggle", {
    Title = "Auto Claim Chests",
    Description = "Automatically unlocks Beach, Grand, and Hell chests on cooldown",
    Default = State.AutoChests,
    Callback = function(val)
        State.AutoChests = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.Chests = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoDailyToggle", {
    Title = "Auto Claim Daily Reward",
    Description = "Automatically redeems daily login reward",
    Default = State.AutoDaily,
    Callback = function(val)
        State.AutoDaily = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.Daily = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoWheelToggle", {
    Title = "Auto Spin Wheel",
    Description = "Spins the free reward wheel whenever free spins are available",
    Default = State.AutoWheel,
    Callback = function(val)
        State.AutoWheel = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.SpinWheel = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoQuestsToggle", {
    Title = "Auto Claim Quests",
    Description = "Automatically claims completed Main, Clan, and Challenge quests for free rewards",
    Default = State.AutoQuests,
    Callback = function(val)
        State.AutoQuests = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.Quests = val
        Configs.Save()
    end
})

RewardsTab:AddToggle("AutoFinishedCraftsToggle", {
    Title = "Auto Claim Finished Crafts",
    Description = "Automatically claims finished potion brews and completed Rainbow pets",
    Default = State.AutoFinishedCrafts,
    Callback = function(val)
        State.AutoFinishedCrafts = val
        if not cfg.AutoRewards then cfg.AutoRewards = {} end
        cfg.AutoRewards.FinishedCrafts = val
        Configs.Save()
    end
})

RewardsTab:AddSection("MANUAL REWARDS ACTIONS")
RewardsTab:AddButton({
    Title = "Redeem All Active Game Codes",
    Description = "Automatically redeems all 13+ unredeemed game codes for free boosts, clicks & gems",
    Callback = function()
        task.spawn(function()
            local count, list = GameAPI.RedeemAllCodes()
            Window:Notify({
                Title = "Codes",
                Content = string.format("Redeemed %d new codes successfully!", count),
                Duration = 3.5
            })
        end)
    end
})

RewardsTab:AddButton({
    Title = "Claim All Rewards Now",
    Description = "Triggers an immediate collection of all eligible gifts, chests, quests & crafts",
    Callback = function()
        GameAPI.ClaimAllFreeGifts()
        GameAPI.ClaimAllAchievements()
        GameAPI.ClaimAllChests()
        GameAPI.ClaimDaily()
        GameAPI.RollWheel()
        GameAPI.ClaimCompletedQuests()
        GameAPI.ClaimFinishedCrafts()
        Window:Notify({ Title = "Rewards", Content = "All claim requests sent!", Duration = 2.5 })
    end
})

--==============================================================================
-- 8. AUTO QUEST TAB
--==============================================================================
local QuestTab = Window:AddTab({ Title = "Auto Quest", Icon = "📜" })

QuestTab:AddSection("SECRET ??? QUESTLINE (DOMINUS AREA)")
local SecretQuestStatusCard = QuestTab:AddParagraph({
    Title = "Dominus Secret Questline (???)",
    Content = "Scanning secret questline progress..."
})

QuestTab:AddToggle("AutoSecretQuestsToggle", {
    Title = "Auto Complete ??? Quests",
    Description = "Dynamically completes all ??? secret requirements: Clicks, Feathers, Golden Pets, and Egg Hatching",
    Default = State.AutoSecretQuests,
    Callback = function(val)
        State.AutoSecretQuests = val
        if not cfg.AutoQuest then cfg.AutoQuest = {} end
        cfg.AutoQuest.AutoSecretQuests = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Secret Quests", Content = "Auto ??? Quests Enabled!", Duration = 2 })
        else
            Window:Notify({ Title = "Secret Quests", Content = "Auto ??? Quests Disabled", Duration = 2 })
        end
    end
})

QuestTab:AddButton({
    Title = "Claim Secret Area Door",
    Description = "Attempts to unlock and claim the Dominus secret door if requirements are met",
    Callback = function()
        local ok, res = GameAPI.ClaimSecretDoor()
        Window:Notify({
            Title = "Secret Door",
            Content = tostring(res),
            Duration = 3
        })
    end
})

QuestTab:AddButton({
    Title = "Collect All Feathers Now",
    Description = "Instantly collects all 10 secret area feathers in the game",
    Callback = function()
        local count = GameAPI.CollectSecretFeathers()
        Window:Notify({
            Title = "Feathers",
            Content = count > 0 and string.format("Collected %d feathers!", count) or "All feathers already collected!",
            Duration = 2.5
        })
    end
})

QuestTab:AddSection("STANDARD QUESTS & REWARDS")
local QuestStatusCard = QuestTab:AddParagraph({
    Title = "Active Quests Status",
    Content = "Scanning player quests..."
})

QuestTab:AddToggle("AutoQuestClaimToggle", {
    Title = "Auto Claim Quests",
    Description = "Automatically claims completed challenge, clan, and legacy quest rewards in the background",
    Default = State.AutoQuest_Claim,
    Callback = function(val)
        State.AutoQuest_Claim = val
        if not cfg.AutoQuest then cfg.AutoQuest = {} end
        cfg.AutoQuest.AutoClaim = val
        Configs.Save()
        if val then
            Window:Notify({ Title = "Quests", Content = "Auto Claim Quests Enabled!", Duration = 2 })
        end
    end
})

QuestTab:AddButton({
    Title = "Claim All Completed Quests",
    Description = "Instantly claims all currently ready quest rewards",
    Callback = function()
        local count = GameAPI.ClaimCompletedQuests()
        Window:Notify({
            Title = "Quests Claimed",
            Content = count > 0 and string.format("Claimed %d quests successfully!", count) or "No quests currently ready to claim.",
            Duration = 2.5
        })
    end
})

--==============================================================================
-- 9. TELEPORTS TAB
--==============================================================================
local TeleportsTab = Window:AddTab({ Title = "Teleports", Icon = "🌍" })

local islandsList = GameAPI.GetIslandList()
TeleportsTab:AddSection("OVERWORLD ISLANDS")
TeleportsTab:AddDropdown("IslandDropdown", {
    Title = "Select Destination Island",
    Description = "Choose an unlocked island to teleport to",
    Values = islandsList,
    Default = State.SelectedTeleport,
    Callback = function(val)
        State.SelectedTeleport = val
    end
})

TeleportsTab:AddButton({
    Title = "Teleport to Selected Island",
    Description = "Instantly warps character to destination portal zone",
    Callback = function()
        local ok = GameAPI.TeleportToIsland(State.SelectedTeleport)
        if ok then
            Window:Notify({ Title = "Teleport", Content = "Warped to " .. State.SelectedTeleport, Duration = 2 })
        else
            Window:Notify({ Title = "Teleport", Content = "Teleport failed (Island locked or invalid)", Duration = 2.5 })
        end
    end
})

--==============================================================================
-- 9. MISC TAB
--==============================================================================
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "🛠️" })

MiscTab:AddSection("CHARACTER MODIFIERS")
MiscTab:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Description = "Custom movement speed",
    Min = 16,
    Max = 200,
    Rounding = 1,
    Suffix = " studs/s",
    Default = State.WalkSpeed,
    Callback = function(val)
        State.WalkSpeed = val
        if not cfg.Misc then cfg.Misc = {} end
        cfg.Misc.WalkSpeed = val
        Configs.Save()
    end
})

MiscTab:AddSlider("JumpPowerSlider", {
    Title = "JumpPower",
    Description = "Custom jump vertical force",
    Min = 50,
    Max = 300,
    Rounding = 1,
    Suffix = " power",
    Default = State.JumpPower,
    Callback = function(val)
        State.JumpPower = val
        if not cfg.Misc then cfg.Misc = {} end
        cfg.Misc.JumpPower = val
        Configs.Save()
    end
})

MiscTab:AddToggle("InfiniteJumpToggle", {
    Title = "Infinite Jump",
    Description = "Allows infinite consecutive jumps in mid-air",
    Default = State.InfiniteJump,
    Callback = function(val)
        State.InfiniteJump = val
        if not cfg.Misc then cfg.Misc = {} end
        cfg.Misc.InfiniteJump = val
        Configs.Save()
    end
})

MiscTab:AddSection("SAFETY & UTILITIES")
MiscTab:AddToggle("AntiAFKToggle", {
    Title = "Anti-AFK",
    Description = "Prevents Roblox 20-minute disconnect timeout",
    Default = State.AntiAFK,
    Callback = function(val)
        State.AntiAFK = val
        if not cfg.Misc then cfg.Misc = {} end
        cfg.Misc.AntiAFK = val
        Configs.Save()
    end
})

MiscTab:AddButton({
    Title = "Unload Clicker Hub",
    Description = "Closes UI and terminates all running automation background tasks",
    Callback = function()
        if Globals.ClickerHub_Unload then
            Globals.ClickerHub_Unload()
        end
    end
})

--==============================================================================
-- BACKGROUND WORKER THREADS
--==============================================================================

-- 1. Auto Click Thread (Farm Tab)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoClick then
            GameAPI.Click()
            if State.ClickSpeed <= 0.005 then
                GameAPI.Click()
                GameAPI.Click()
            end
        end
        task.wait(State.ClickSpeed)
    end
end))

-- 2. Auto Rebirth Thread (Farm Tab)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoRebirth then
            if State.RebirthMode == "Max Rebirth" then
                GameAPI.RebirthMaxTarget()
            elseif State.RebirthMode == "Best Affordable" then
                local bestIdx = GameAPI.GetBestAffordableRebirthIndex()
                GameAPI.Rebirth(bestIdx)
            elseif State.RebirthMode == "Button 1" then
                GameAPI.Rebirth(1)
            elseif State.RebirthMode == "Button 2" then
                GameAPI.Rebirth(2)
            elseif State.RebirthMode == "Button 3" then
                GameAPI.Rebirth(3)
            end
        end
        task.wait(State.RebirthDelay)
    end
end))

-- 3. Auto Island Progression Thread (Farm Tab)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoUnlockNextIsland then
            local pData = GameAPI.GetPlayerData()
            local nextIsld = GameAPI.GetNextLockedIsland()
            if nextIsld and pData.Clicks >= nextIsld.cost then
                local ok, res = GameAPI.UnlockAndTeleportToNextIsland()
                if ok then
                    Window:Notify({ Title = "Island Unlocked!", Content = "🌟 " .. tostring(res), Duration = 3.5 })
                end
            end
        end
        task.wait(1.0)
    end
end))

-- 4. Auto Equip Best Pets Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoEquipBest then
            GameAPI.EquipBest()
        end
        task.wait(State.EquipInterval)
    end
end))

-- 4b. Auto Pet Crafting Thread (Golden & Rainbow & Claim)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoGoldPets or (State.AutoProgMaster and State.AutoCraftGolden) then
            local crafted = 0
            pcall(function()
                crafted = GameAPI.CraftGoldenPets()
                if crafted > 0 then
                    GameAPI.EquipBest()
                end
            end)
        end
        if State.AutoRainbowPets then
            pcall(GameAPI.CraftRainbowPets)
        end
        if State.AutoClaimRainbowPets then
            pcall(GameAPI.ClaimRainbowPets)
        end
        task.wait(2.0)
    end
end))

-- 4c. Auto Prog Egg & Auto Gold Worker Thread
table.insert(threads, task.spawn(function()
    local lastProgHatch = 0
    local lastProgClean = 0
    while isRunning do
        if State.AutoProgMaster then
            local now = tick()
            local isAllGold = GameAPI.IsEquippedTeamAllGold()
            local pData = GameAPI.GetPlayerData()

            -- Clean inventory periodically if enabled
            if State.AutoCleanPets and (now - lastProgClean > 4) then
                lastProgClean = now
                pcall(function()
                    GameAPI.CleanOldPets(State.KeepTopPets, State.ProtectCraftingPets)
                end)
            end

            -- Auto Gold or Auto Open Eggs
            if (State.AutoGold and not isAllGold) or State.AutoOpenProgEggs then
                if (now - lastProgHatch > 0.35) then
                    lastProgHatch = now
                    local bestEgg = GameAPI.GetBestAffordableEgg()
                    if bestEgg and pData.Clicks >= bestEgg.cost then
                        GameAPI.OpenEgg(bestEgg.name, 1)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end))

-- 5. Auto Hatch Thread (Hatch Tab)
local lastHatchedEgg = ""
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoHatch then
            local targetEggName = State.SelectedEgg
            if targetEggName == "Best Affordable Egg" then
                local best = GameAPI.GetBestAffordableEgg()
                targetEggName = best and best.name or "BasicEgg"
            end

            if State.AutoTeleportToEgg and targetEggName ~= "" then
                if targetEggName ~= lastHatchedEgg then
                    lastHatchedEgg = targetEggName
                    GameAPI.TeleportToEgg(targetEggName)
                    task.wait(0.35)
                end
            end

            GameAPI.OpenEgg(targetEggName, State.HatchAmount)
        else
            lastHatchedEgg = ""
        end
        task.wait(State.HatchDelay)
    end
end))

-- 6. Skill Tree & Breakables Worker Thread (Skill Tree Tab)
table.insert(threads, task.spawn(function()
    local lastZoneCheck = 0
    local skillTreeTimer = 0
    while isRunning do
        if State.AutoBreakables then
            local pData = GameAPI.GetPlayerData()
            local targetIsland = GameAPI.GetBestBreakableIsland(State.Breakables_TargetWorld) or "Heaven"

            -- If auto teleport is enabled and player is not on the target island, warp there
            if State.Breakables_BestWorld and targetIsland and targetIsland ~= pData.CurrentIsland then
                GameAPI.TeleportToIsland(targetIsland)
                task.wait(0.5)
            end

            local hasZone = GameAPI.HasBreakables(targetIsland)
            if hasZone then
                if tick() - lastZoneCheck > 3 then
                    lastZoneCheck = tick()
                    local zonePart = GameAPI.GetIslandBreakableZone(targetIsland, State.Breakables_IgnoreBossChest)
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and zonePart then
                        local dist = (hrp.Position - zonePart.Position).Magnitude
                        if dist > 80 then
                            GameAPI.TeleportToBreakableZone(targetIsland, State.Breakables_IgnoreBossChest)
                        end
                    end
                end
                pcall(function()
                    GameAPI.AttackBreakable(State.Breakables_IgnoreBossChest)
                end)
            end
        end
        task.wait(State.BreakablesDelay)
    end
end))

-- 6b. Auto Skill Tree Perks Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoSkillTree then
            pcall(GameAPI.BuyAffordableSkillTree)
        end
        task.wait(1.5)
    end
end))

-- 7. Upgrades Worker Thread (Upgrades Tab)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoGemUpgrades then
            pcall(GameAPI.BuyAffordableGemUpgrades)
        end
        if State.AutoRebirthButtons then
            pcall(GameAPI.BuyNextRebirthButton)
        end
        if State.AutoDoubleJump then
            pcall(GameAPI.BuyNextDoubleJump)
        end
        if State.AutoMiniUpgrades then
            pcall(GameAPI.BuyAffordableMiniUpgrades)
        end
        if State.AutoRNGUpgrades then
            pcall(GameAPI.BuyAffordableRNGUpgrades)
        end
        task.wait(1.5)
    end
end))

-- 8. Auto Rewards Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoFreeGifts then pcall(GameAPI.ClaimAllFreeGifts) end
        if State.AutoAchievements then pcall(GameAPI.ClaimAllAchievements) end
        if State.AutoChests then pcall(GameAPI.ClaimAllChests) end
        if State.AutoDaily then pcall(GameAPI.ClaimDaily) end
        if State.AutoWheel then pcall(GameAPI.RollWheel) end
        if State.AutoQuests then pcall(GameAPI.ClaimCompletedQuests) end
        if State.AutoFinishedCrafts then pcall(GameAPI.ClaimFinishedCrafts) end
        task.wait(State.RewardsInterval)
    end
end))

-- 8b. Auto Items & Crafting Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoPotions then
            pcall(function()
                GameAPI.AutoConsumePotions({
                    ["Clicks Potion"] = State.Potion_Clicks,
                    ["Hatch Speed Potion"] = State.Potion_HatchSpeed,
                    ["Luck Potion"] = State.Potion_Luck,
                    ["Gems Potion"] = State.Potion_Gems,
                    ["Clicks Speed Potion"] = State.Potion_ClicksSpeed,
                })
            end)
        end
        if State.AutoFruits then
            pcall(GameAPI.AutoConsumeFruits)
        end
        if State.AutoCraftPowerups then
            pcall(GameAPI.AutoCraftPowerups)
        end
        task.wait(3.0)
    end
end))

-- 8c. Auto Quest Worker Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoQuest_Claim then
            pcall(GameAPI.ClaimCompletedQuests)
        end
        task.wait(State.AutoQuest_Interval)
    end
end))

-- 8d. Auto ??? Secret Quests Worker Thread
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoSecretQuests then
            pcall(GameAPI.StepSecretQuest)
        end
        task.wait(0.35)
    end
end))

-- 9. Live Telemetry & Cards Update Thread
local lastClicks = 0
local lastSampleTime = tick()
local currentCps = 0

table.insert(threads, task.spawn(function()
    while isRunning do
        local ok, err = xpcall(function()
            local pData = GameAPI.GetPlayerData()
            local now = tick()
            local dt = now - lastSampleTime
            if dt >= 1.0 then
                local diff = pData.Clicks - lastClicks
                if diff >= 0 then
                    currentCps = math.floor(diff / dt)
                end
                lastClicks = pData.Clicks
                lastSampleTime = now
            end

            -- Stat Card (Overview)
            local contentStr = string.format(
                "User: %s  |  Island: %s\n" ..
                "Clicks: %s  (+%s/s)\n" ..
                "Rebirths: %s  |  Gems: %s",
                LocalPlayer.Name,
                tostring(pData.CurrentIsland),
                GameAPI.FormatNumber(pData.Clicks),
                GameAPI.FormatNumber(currentCps),
                GameAPI.FormatNumber(pData.Rebirths),
                GameAPI.FormatNumber(pData.Gems)
            )
            StatCard:Set({
                Title = "Live Telemetry  •  " .. os.date("%X"),
                Content = contentStr
            })

            -- Rebirth Card (Auto Farm)
            local rInfo = GameAPI.GetMaxRebirthInfo()
            local statusTitle = rInfo.CanAffordMax and "Rebirth Target  •  READY (100%)" or string.format("Rebirth Target  •  %d%%", math.floor(rInfo.Progress * 100))
            RebirthStatusCard:Set({
                Title = statusTitle,
                Content = string.format(
                    "Max Milestone: Button #%d (+%s Rebirths)\n" ..
                    "Target Cost: %s Clicks\n" ..
                    "Progress: %s / %s (%d%%)\n" ..
                    "Mode: %s",
                    rInfo.MaxButtonIndex,
                    GameAPI.FormatNumber(rInfo.MaxAmount),
                    GameAPI.FormatNumber(rInfo.MaxCost),
                    GameAPI.FormatNumber(rInfo.CurrentClicks),
                    GameAPI.FormatNumber(rInfo.MaxCost),
                    math.floor(rInfo.Progress * 100),
                    State.RebirthMode
                )
            })

            -- Island Status Card (Auto Farm)
            local nextIsld = GameAPI.GetNextLockedIsland()
            local islandName = nextIsld and nextIsld.name or "All Islands Unlocked!"
            local islandCostStr = nextIsld and GameAPI.FormatNumber(nextIsld.cost) or "MAX"
            local islandPct = nextIsld and math.clamp(math.floor((pData.Clicks / nextIsld.cost) * 100), 0, 100) or 100
            IslandStatusCard:Set({
                Title = "Next Island  •  " .. islandName .. " (" .. tostring(islandPct) .. "%)",
                Content = string.format(
                    "Target Cost: %s Clicks\n" ..
                    "Current Clicks: %s\n" ..
                    "Status: %s",
                    islandCostStr,
                    GameAPI.FormatNumber(pData.Clicks),
                    (nextIsld and pData.Clicks >= nextIsld.cost) and "✅ AFFORDABLE (Ready to Unlock!)" or "⏳ Gathering Clicks..."
                )
            })

            -- Egg Status Card (Auto Hatch)
            local targetEggName = State.SelectedEgg
            local effectiveEggName = targetEggName
            if targetEggName == "Best Affordable Egg" then
                local best = GameAPI.GetBestAffordableEgg()
                effectiveEggName = best and best.name or "BasicEgg"
            end
            EggStatusCard:Set({
                Title = "Target Egg: " .. effectiveEggName,
                Content = string.format(
                    "Selection: %s\n" ..
                    "Auto Teleport to Platform: %s\n" ..
                    "Hatch Status: %s",
                    targetEggName,
                    State.AutoTeleportToEgg and "Enabled" or "Disabled",
                    State.AutoHatch and "Active (Hatching...)" or "Idle"
                )
            })

            -- Breakables Card (Skill Tree)
            local coinsVal = pData.Raw and pData.Raw.Currency and pData.Raw.Currency.Coins or 0
            local spaceCoinsVal = pData.Raw and pData.Raw.Currency and pData.Raw.Currency.SpaceCoins or 0
            local effectiveTargetWorld = GameAPI.GetBestBreakableIsland(State.Breakables_TargetWorld) or "Heaven"
            local hasZone = GameAPI.HasBreakables(pData.CurrentIsland)
            local stProg = GameAPI.GetSkillTreeProgress()
            local dynamicRoutingStr = ""
            if stProg.TechComplete and not stProg.CoinsComplete then
                dynamicRoutingStr = string.format("Tech Done (%d/%d) ➔ Farming Coins (%d left)", stProg.TechBought, stProg.TechTotal, stProg.CoinsRemaining)
            elseif not stProg.TechComplete then
                dynamicRoutingStr = string.format("Farming Tech (%d left) ➔ Coins after", stProg.TechRemaining)
            else
                dynamicRoutingStr = "Skill Tree 100% Completed!"
            end

            BreakablesStatusCard:Set({
                Title = "Breakables  •  " .. GameAPI.FormatNumber(coinsVal) .. " Coins | " .. GameAPI.FormatNumber(spaceCoinsVal) .. " Tech",
                Content = string.format(
                    "Current Island: %s (%s)\n" ..
                    "Target World: %s (%s)\n" ..
                    "Skill Tree Mode: %s\n" ..
                    "Ignore Boss Chest: %s\n" ..
                    "Farming Status: %s",
                    tostring(pData.CurrentIsland),
                    hasZone and "Arena Active" or "No Arena",
                    effectiveTargetWorld,
                    State.Breakables_TargetWorld,
                    dynamicRoutingStr,
                    State.Breakables_IgnoreBossChest and "Enabled" or "Disabled",
                    State.AutoBreakables and "Active (Attacking...)" or "Idle"
                )
            })

            -- Items & Potions Card (Items Tab)
            local bf = nil
            pcall(function() bf = require(Client:WaitForChild("BoostsFrontend")) end)
            local activeBoosts = (bf and bf.GetAllActiveBoosts and bf.GetAllActiveBoosts()) or {}
            local potionLines = {}
            for _, pName in ipairs({"Clicks Potion", "Hatch Speed Potion", "Luck Potion", "Gems Potion", "Clicks Speed Potion"}) do
                local rem = activeBoosts[pName] and activeBoosts[pName].remaining or 0
                local statusStr = rem > 0 and string.format("Active (%dm %ds, T%d)", math.floor(rem / 60), rem % 60, activeBoosts[pName].tier or 1) or "Inactive"
                table.insert(potionLines, string.format("• %s: %s", pName, statusStr))
            end
            PotionsStatusCard:Set({
                Title = "Active Potion Boosts",
                Content = table.concat(potionLines, "\n")
            })

            -- Fruits Card (Items Tab)
            local fruitLines = {}
            for _, fName in ipairs({"Apple", "Blueberry", "Strawberry", "Watermelon", "Green Apple"}) do
                local q = (bf and bf.GetQueue and bf.GetQueue(fName)) or {}
                local rem = 0
                for _, item in ipairs(q) do rem = rem + (item.remaining or 0) end
                local statusStr = #q > 0 and string.format("%dx Stack (%dm left)", #q, math.floor(rem / 60)) or "0x (Inactive)"
                table.insert(fruitLines, string.format("• %s: %s", fName, statusStr))
            end
            FruitsStatusCard:Set({
                Title = "Fruit Buffs Status",
                Content = table.concat(fruitLines, "\n")
            })

            -- Brewing Slots Card (Items Tab)
            local craftInfo = GameAPI.GetItemsAndCraftStatus()
            BrewingStatusCard:Set({
                Title = string.format("Brewing Machine  •  %d/6 In Progress", craftInfo.activeCraftsCount),
                Content = craftInfo.craftDetails
            })

            -- Secret ??? Quests Card (Auto Quest Tab)
            local sProg = GameAPI.GetSecretQuestProgress()
            local sLines = {}
            local function formatStep(name, data)
                local mark = data.done and "✔ COMPLETE" or string.format("%s / %s (%d%%)", GameAPI.FormatNumber(data.prog), GameAPI.FormatNumber(data.req), math.clamp(math.floor((data.prog / data.req) * 100), 0, 100))
                return string.format("• %s: %s", name, mark)
            end
            table.insert(sLines, formatStep("Clicks (3,500)", sProg.clicks))
            table.insert(sLines, formatStep("Feathers (10)", sProg.feathers))
            table.insert(sLines, formatStep("Golden Pets (15)", sProg.golden))
            table.insert(sLines, formatStep("Eggs Hatched (2,500)", sProg.hatch))
            table.insert(sLines, string.format("• Current Objective: %s", sProg.currentStep))
            if sProg.isUnlocked then
                table.insert(sLines, "• Status: Dominus Secret Door UNLOCKED!")
            elseif sProg.allDone then
                table.insert(sLines, "• Status: All 4 Quests Done! Door Ready to Claim!")
            end

            SecretQuestStatusCard:Set({
                Title = sProg.isUnlocked and "Dominus Questline (???) • UNLOCKED!" or (sProg.allDone and "Dominus Questline (???) • READY TO CLAIM!" or "Dominus Secret Questline (???)"),
                Content = table.concat(sLines, "\n")
            })

            -- Quests Card (Auto Quest Tab)
            local qInfo = GameAPI.GetQuestList()
            local qLines = {}
            for i = 1, math.min(#qInfo.active, 4) do
                local q = qInfo.active[i]
                local pct = q.req > 0 and math.clamp(math.floor((q.prog / q.req) * 100), 0, 100) or 100
                local status = q.claimable and "READY TO CLAIM!" or string.format("%d/%d (%d%%)", q.prog, q.req, pct)
                table.insert(qLines, string.format("• %s: %s", q.title, status))
            end
            QuestStatusCard:Set({
                Title = string.format("Active Quests  •  %d Ready to Claim", #qInfo.claimable),
                Content = #qLines > 0 and table.concat(qLines, "\n") or "No active quests found."
            })

            -- ProgCheckCard (Auto Prog Tab - The Buyer Checklist!)
            local pProgLines = {}
            table.insert(pProgLines, "1st. Desert Gem Machine: Active (Click/Combo/Hatch/Rebirth Upgrades)")
            local stStatus = (stProg.TechComplete and "✔ TECH DONE" or string.format("Tech %d/%d (%d left)", stProg.TechBought, stProg.TechTotal, stProg.TechRemaining))
                .. " ➔ " .. (stProg.CoinsComplete and "✔ COINS DONE" or string.format("Coins %d/%d", stProg.CoinsBought, stProg.CoinsTotal))
            table.insert(pProgLines, "2nd. Todo Skill Tree Check: " .. stStatus)
            local domStatus = sProg.isUnlocked and "✔ UNLOCKED" or (sProg.allDone and "✔ READY TO CLAIM" or string.format("Feathers %d/10 • Hatches %d/2500", sProg.feathers.prog, sProg.hatch.prog))
            table.insert(pProgLines, "3rd. Auto ??? Dominus Quest: " .. domStatus)
            local targetQi = 1e19
            local curRebirths = pData.Rebirths or 0
            local qiPct = math.clamp(math.floor((curRebirths / targetQi) * 100), 0, 100)
            local skinStatus = GameAPI.GetClickSkinStatus("Magma")
            local skinStr = skinStatus.equipped and "✔ EQUIPPED (+4 Hatch, +20% Speed)" or (curRebirths >= targetQi and "READY TO EQUIP" or string.format("%d%% of 10 Qi", qiPct))
            table.insert(pProgLines, string.format("4th. 10 Qi Rebirth Check: %s / 10.00 Qi (%d%%) • Magma Skin: %s", GameAPI.FormatNumber(curRebirths), qiPct, skinStr))
            table.insert(pProgLines, "• Auto Free Gifts: Active (12/12 Gifts, Chests, Daily)")
            table.insert(pProgLines, "• Auto Use Potions: Active (Best Tier Clicks, Speed, Luck, Gems)")
            table.insert(pProgLines, string.format("• Island Rush: %s ➔ %s (%s)", pData.CurrentIsland, islandName, (nextIsld and pData.Clicks >= nextIsld.cost) and "READY TO UNLOCK!" or tostring(islandPct) .. "%"))

            ProgCheckCard:Set({
                Title = "Speedrun & Endgame Checklist  •  " .. os.date("%X"),
                Content = table.concat(pProgLines, "\n")
            })

        end, function(e)
            return tostring(e) .. "\n" .. debug.traceback()
        end)
        if not ok then
            Globals.TelemetryError = tostring(err)
        end
        task.wait(0.5)
    end
end))

-- 10. Character Modifier Enforcer (WalkSpeed & JumpPower)
table.insert(threads, task.spawn(function()
    while isRunning do
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if State.WalkSpeed ~= 16 and hum.WalkSpeed ~= State.WalkSpeed then
                hum.WalkSpeed = State.WalkSpeed
            end
            if State.JumpPower ~= 50 and hum.JumpPower ~= State.JumpPower then
                hum.UseJumpPower = true
                hum.JumpPower = State.JumpPower
            end
        end
        task.wait(0.5)
    end
end))

-- 11. Infinite Jump Event Connection
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump and isRunning then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 12. Anti-AFK Connection
local afkConn = LocalPlayer.Idled:Connect(function()
    if State.AntiAFK and isRunning then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- 13. Auto Magma Click Skin Enforcer (Endgame: 10 Qi Rebirth Requirement)
table.insert(threads, task.spawn(function()
    while isRunning do
        if State.AutoMagmaSkin then
            pcall(GameAPI.CheckAndEquipMagmaSkin)
        end
        task.wait(4.0)
    end
end))

--==============================================================================
-- GLOBAL UNLOAD FUNCTION
--==============================================================================
Globals.ClickerHub_Unload = function()
    isRunning = false
    Globals.ClickerHub_Running = false

    -- Disconnect events
    if jumpConn then pcall(function() jumpConn:Disconnect() end) end
    if afkConn then pcall(function() afkConn:Disconnect() end) end

    -- Cancel all active threads
    for _, th in ipairs(threads) do
        if th and coroutine.status(th) ~= "dead" then
            pcall(task.cancel, th)
        end
    end
    table.clear(threads)

    -- Destroy UI
    Window:Destroy()
    Globals.ClickerHub_Unload = nil
end

Globals.ClickerHub_Running = true

Window:Notify({
    Title = "Clicker Hub Loaded",
    Content = "Tap ⚡ on screen or press Right-Ctrl to toggle UI.",
    Duration = 4
})

print("[CLICKER HUB] Successfully initialized and running!")
