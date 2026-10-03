--!strict
--==============================================================================
-- [AUTOPROG] AutoProgAPI.lua
-- Dedicated Full Zero-to-Hero Auto Progression API Engine for Clicker Simulator!
-- Integrates directly with game internal Network channels, Stats, Directory,
-- Balancing, and Frontend modules.
--==============================================================================

local AutoProgAPI = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Resolve Library & Client Modules safely
local Library = ReplicatedStorage:WaitForChild("Library", 10)
if not Library then
    error("[AutoProg] Failed to locate ReplicatedStorage.Library!")
end

local Client = Library:WaitForChild("Client", 10)
local Directory = require(Library:WaitForChild("Directory"))
local Constants = require(Library:WaitForChild("Constants"))
local Network = require(Client:WaitForChild("Network"))
local Stats = require(Client:WaitForChild("Stats"))

local Balancing = nil
pcall(function() Balancing = require(Library:WaitForChild("Balancing", 5)) end)

local Currency = nil
pcall(function() Currency = require(Client:WaitForChild("Currency", 5)) end)

local MasteryFrontend = nil
pcall(function() MasteryFrontend = require(Client:WaitForChild("MasteryFrontend", 5)) end)

local IslandsFrontend = nil
pcall(function() IslandsFrontend = require(Client:WaitForChild("IslandsFrontend", 5)) end)

local BreakablesFrontend = nil
pcall(function() BreakablesFrontend = require(Client:WaitForChild("BreakablesFrontend", 5)) end)

local EggsFrontend = nil
pcall(function() EggsFrontend = require(Client:WaitForChild("EggsFrontend", 5)) end)

-- Channels
local Channels = {
    Click = Network.Channel("Click"),
    Rebirths = Network.Channel("Rebirths"),
    Egg = Network.Channel("Egg"),
    Pets = Network.Channel("Pets"),
    Portals = Network.Channel("Portals"),
    FreeGifts = Network.Channel("FreeGifts"),
    Achievements = Network.Channel("Achievements"),
    DailyRewards = Network.Channel("DailyRewards"),
    Codes = Network.Channel("Codes"),
    BeachChest = Network.Channel("BeachChest"),
    Upgrades = Network.Channel("Upgrades"),
    RebirthShop = Network.Channel("RebirthShop"),
    MiniUpgrades = Network.Channel("MiniUpgrades"),
    Potions = Network.Channel("Potions"),
    Fruits = Network.Channel("Fruits"),
    Crafting = Network.Channel("Crafting"),
    RNGUpgrades = Network.Channel("RNGUpgrades"),
    TradingPlazaTeleport = Network.Channel("TradingPlazaTeleport"),
    SkillTree = Network.Channel("SkillTree"),
    Quests = Network.Channel("Quests"),
    Prestige = Network.Channel("Prestige"),
}

AutoProgAPI.Channels = Channels
AutoProgAPI.Directory = Directory
AutoProgAPI.Constants = Constants
AutoProgAPI.Balancing = Balancing

-- Suppress game black shade permanently
function AutoProgAPI.SuppressBlackShade()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and (gui.Name:find("Overlay") or gui.Name:find("Black") or gui.Name:find("Transition")) then
            local fr = gui:FindFirstChildWhichIsA("Frame")
            if fr and fr.BackgroundColor3 == Color3.new(0, 0, 0) and fr.BackgroundTransparency < 1 then
                fr.BackgroundTransparency = 1
            end
        end
    end
end

--==============================================================================
-- NUMBER FORMATTING & PLAYER DATA
--==============================================================================
local SUFFIXES = {
    "", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
    "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"
}

function AutoProgAPI.FormatNumber(val: number?): string
    if not val or val ~= val then return "0" end
    if val < 0 then return "-" .. AutoProgAPI.FormatNumber(-val) end
    if val < 1000 then return tostring(math.floor(val)) end

    local exp = math.floor(math.log(val, 10) / 3)
    if exp < 1 then return tostring(math.floor(val)) end
    if exp > #SUFFIXES - 1 then
        return string.format("%.2e", val)
    end

    local scaled = val / (10 ^ (exp * 3))
    return string.format("%.2f%s", scaled, SUFFIXES[exp + 1])
end

function AutoProgAPI.GetPlayerData()
    local raw = Stats.Local(true) or {}
    local curr = raw.Currency or {}
    return {
        Clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or curr.Clicks or 0,
        Rebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or curr.Rebirths or 0,
        Gems = (Currency and Currency.Get and Currency.Get("Gems")) or curr.Gems or 0,
        Coins = (Currency and Currency.Get and Currency.Get("Coins")) or curr.Coins or 0,
        SpaceCoins = (Currency and Currency.Get and Currency.Get("SpaceCoins")) or curr.SpaceCoins or 0,
        PixelCoins = (Currency and Currency.Get and Currency.Get("PixelCoins")) or curr.PixelCoins or 0,
        Prestiges = raw.Prestiges or 0,
        CurrentIsland = raw.CurrentIsland or "Spawn",
        CurrentWorld = raw.CurrentWorld or "Overworld",
        Raw = raw
    }
end

--==============================================================================
-- HIGH-SPEED CLICKING
--==============================================================================
function AutoProgAPI.Click()
    if Channels.Click then
        Channels.Click:FireServer("Click", true)
    end
end

--==============================================================================
-- REBIRTHS & MAX REBIRTH
--==============================================================================
function AutoProgAPI.Rebirth(index: number)
    if Channels.Rebirths then
        Channels.Rebirths:FireServer("Rebirth", index or 1)
    end
end

function AutoProgAPI.MaxRebirth()
    if Channels.Rebirths then
        Channels.Rebirths:FireServer("MaxRebirth")
    end
end

-- Computes live data for the player's HIGHEST AFFORDABLE rebirth milestone button
function AutoProgAPI.GetMaxRebirthInfo()
    local raw = Stats.Local(true) or {}
    local owned = raw.OwnedRebirthButtons or {}
    local buttons = { 1, 2, 3 }
    for k, v in pairs(owned) do
        local n = type(v) == "number" and v or (v == true and tonumber(k)) or tonumber(v) or tonumber(k)
        if n and n >= 4 and Constants.Rebirths and Constants.Rebirths[n] then
            table.insert(buttons, n)
        end
    end
    table.sort(buttons)

    local costMultiplier = 1
    if MasteryFrontend and MasteryFrontend.GetPower then
        pcall(function()
            costMultiplier = MasteryFrontend.GetPower(raw, "RebirthCostMultiplier")
        end)
    end

    local curRebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or (raw.Currency and raw.Currency.Rebirths) or 0
    local curClicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (raw.Currency and raw.Currency.Clicks) or 0

    local highestOwnedIdx = buttons[#buttons] or 1
    local bestAffordableIdx = nil
    local bestAffordableCost = 0
    local bestAffordableAmount = 0

    for _, btnIdx in ipairs(buttons) do
        local entry = Constants.Rebirths and Constants.Rebirths[btnIdx]
        if entry and entry.Amount then
            local cost = 0
            if Balancing and Balancing.Rebirths and Balancing.Rebirths.GetCost then
                cost = Balancing.Rebirths.GetCost(entry.Amount, curRebirths, costMultiplier)
            else
                cost = entry.Amount * 1000
            end
            if curClicks >= cost then
                bestAffordableIdx = btnIdx
                bestAffordableCost = cost
                bestAffordableAmount = entry.Amount
            end
        end
    end

    local maxEntry = Constants.Rebirths and Constants.Rebirths[highestOwnedIdx]
    local maxAmount = maxEntry and maxEntry.Amount or (highestOwnedIdx * 10)
    local maxCost = 0
    if Balancing and Balancing.Rebirths and Balancing.Rebirths.GetCost then
        maxCost = Balancing.Rebirths.GetCost(maxAmount, curRebirths, costMultiplier)
    else
        maxCost = maxAmount * 1000
    end

    return {
        CanAffordMax = (bestAffordableIdx ~= nil),
        BestAffordableIndex = bestAffordableIdx,
        BestAffordableAmount = bestAffordableAmount,
        BestAffordableCost = bestAffordableCost,
        MaxButtonIndex = highestOwnedIdx,
        MaxAmount = maxAmount,
        MaxCost = maxCost,
        CurrentClicks = curClicks,
        CurrentRebirths = curRebirths,
        CostMultiplier = costMultiplier,
        OwnedButtons = buttons
    }
end

-- Executes the highest affordable rebirth milestone button directly
function AutoProgAPI.RebirthMaxTarget(): (boolean, any)
    local info = AutoProgAPI.GetMaxRebirthInfo()
    if Channels.Rebirths then
        if info.CanAffordMax and info.BestAffordableIndex then
            Channels.Rebirths:FireServer("Rebirth", info.BestAffordableIndex)
            pcall(function() Channels.Rebirths:FireServer("MaxRebirth") end)
            return true, info
        end
        pcall(function() Channels.Rebirths:FireServer("MaxRebirth") end)
    end
    return false, info
end

--==============================================================================
-- PRESTIGE AUTOMATION
--==============================================================================
function AutoProgAPI.GetPrestigeInfo()
    local stats = Stats.Local(true) or {}
    local curPrest = stats.Prestiges or 0
    local tiers = (Balancing and Balancing.Prestige and Balancing.Prestige.Tiers) or {}
    local nextTier = tiers[curPrest + 1]
    local curRebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or (stats.Currency and stats.Currency.Rebirths) or 0

    if not nextTier then
        return {
            CanPrestige = false,
            CurrentPrestige = curPrest,
            NextTier = nil,
            RequiredRebirths = 0,
            CurrentRebirths = curRebirths,
            MissingRebirths = 0,
            MaxPrestigeReached = true
        }
    end

    local req = nextTier.RequiredRebirths or math.huge
    local canPrestige = (curRebirths >= req)
    return {
        CanPrestige = canPrestige,
        CurrentPrestige = curPrest,
        NextTier = nextTier,
        RequiredRebirths = req,
        CurrentRebirths = curRebirths,
        MissingRebirths = math.max(0, req - curRebirths),
        MaxPrestigeReached = false
    }
end

function AutoProgAPI.CheckAndTriggerPrestige(): (boolean, string)
    local info = AutoProgAPI.GetPrestigeInfo()
    if info.MaxPrestigeReached then
        return false, "Max Prestige reached"
    end
    if not info.CanPrestige then
        return false, string.format("Need %s Rebirths to Prestige", AutoProgAPI.FormatNumber(info.RequiredRebirths))
    end
    if not Channels.Prestige then
        return false, "Prestige channel not found"
    end

    local ok, res = pcall(function()
        return Channels.Prestige:InvokeServer("Prestige")
    end)
    if ok and res == true then
        -- Wait 14s for sequence animation to finish
        task.wait(14)
        return true, "Successfully Prestiged to Tier " .. tostring(info.CurrentPrestige + 1)
    end
    return false, "Prestige failed: " .. tostring(res)
end

--==============================================================================
-- ISLANDS, WORLDS & CROSS-WORLD NAVIGATION
--==============================================================================

-- Progression sequence of all 17 islands with exact costs, worlds, and eggs
AutoProgAPI.OrderedIslands = {
    { num = 1,  name = "Spawn",     cost = 0,                     world = "Overworld", eggs = {"BasicEgg", "FlowerEgg", "AcornEgg"} },
    { num = 2,  name = "Winter",    cost = 1250000,               world = "Overworld", eggs = {"SnowmanEgg"} },
    { num = 3,  name = "Forest",    cost = 75000000,              world = "Overworld", eggs = {"WoodEgg"} },
    { num = 4,  name = "Desert",    cost = 900000000,             world = "Overworld", eggs = {"CactusEgg"} },
    { num = 5,  name = "Candy",     cost = 50000000000,           world = "Overworld", eggs = {"CottonCandyEgg", "ChocolateEgg"} },
    { num = 6,  name = "Beach",     cost = 2500000000000,         world = "Overworld", eggs = {"PalmTreeEgg", "BeachBallEgg"} },
    { num = 7,  name = "Sakura",    cost = 3.3333333333333e14,    world = "Overworld", eggs = {"BlossomEgg"} },
    { num = 8,  name = "Volcano",   cost = 1.5e16,                world = "Overworld", eggs = {"VolcanoEgg"} },
    { num = 9,  name = "Rave",      cost = 7.5e17,                world = "Overworld", eggs = {"DiscoEgg"} },
    { num = 10, name = "Heaven",    cost = 2.5e19,                world = "Overworld", eggs = {"AngelEgg"} },
    { num = 11, name = "Castle",    cost = 2e20,                  world = "Overworld", eggs = {"CastleEgg"} },
    { num = 12, name = "Mystical",  cost = 2.5e21,                world = "Overworld", eggs = {"CursedEgg", "RockEgg"} },
    { num = 13, name = "Hell",      cost = 5e22,                  world = "Overworld", eggs = {"DemonicEgg"} },
    { num = 14, name = "Base",      cost = 1.5e23,                world = "Techworld", eggs = {"TechEgg", "HolographicEgg"} },
    { num = 15, name = "Spaceship", cost = 7.5e23,                world = "Techworld", eggs = {"404Egg", "RedTechEgg"} },
    { num = 16, name = "Fragment",  cost = 5e24,                  world = "Techworld", eggs = {"FragmentedEgg"} },
    { num = 17, name = "Matrix",    cost = 2.5e25,                world = "Techworld", eggs = {"MatrixEgg"} },
}

-- Mappings for fast lookup
local islandMetaLookup = {}
for idx, data in ipairs(AutoProgAPI.OrderedIslands) do
    data.globalIndex = idx
    islandMetaLookup[data.name] = data
end

function AutoProgAPI.GetIslandMetadata(islandName: string)
    return islandMetaLookup[islandName]
end

function AutoProgAPI.IsIslandUnlocked(islandName: string): boolean
    if IslandsFrontend and IslandsFrontend.IsUnlocked then
        local ok, res = pcall(function() return IslandsFrontend.IsUnlocked(islandName) end)
        if ok and res ~= nil then return res == true end
    end
    local stats = Stats.Local(true) or {}
    local unlocked = stats.UnlockedIslands or {"Spawn"}
    for _, isl in ipairs(unlocked) do
        if isl == islandName then return true end
    end
    return false
end

-- Returns the highest/furthest unlocked island in progression order
function AutoProgAPI.GetFurthestUnlockedIsland(): string
    local furthest = "Spawn"
    for _, islandInfo in ipairs(AutoProgAPI.OrderedIslands) do
        if AutoProgAPI.IsIslandUnlocked(islandInfo.name) then
            furthest = islandInfo.name
        end
    end
    return furthest
end

-- Returns the first locked island in progression order (or nil if all 17 are unlocked)
function AutoProgAPI.GetNextLockedIsland()
    for _, islandInfo in ipairs(AutoProgAPI.OrderedIslands) do
        if not AutoProgAPI.IsIslandUnlocked(islandInfo.name) then
            return islandInfo
        end
    end
    return nil -- All 17 islands unlocked!
end

-- Robust Cross-World & Island Teleport
function AutoProgAPI.TeleportToWorld(worldName: string): boolean
    if not Channels.Portals then return false end
    local ok, res = pcall(function()
        return Channels.Portals:InvokeServer("TeleportToWorld", worldName)
    end)
    return ok and res == true
end

function AutoProgAPI.TeleportToIsland(islandName: string): boolean
    local meta = islandMetaLookup[islandName]
    local targetWorld = meta and meta.world or "Overworld"
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    -- 1. Switch world if targeting island in another world
    if targetWorld ~= curWorld and Channels.Portals then
        pcall(function()
            Channels.Portals:InvokeServer("TeleportToWorld", targetWorld)
        end)
        task.wait(0.6)
    end

    -- 2. Try server portal teleport
    if Channels.Portals then
        local ok, res = pcall(function()
            return Channels.Portals:InvokeServer("TeleportToIsland", islandName)
        end)
        if ok and res == true then
            return true
        end
    end

    -- 3. Instant client local teleport (sets CFrame smoothly)
    if IslandsFrontend and IslandsFrontend.LocalTeleport then
        local ok, res = pcall(function()
            return IslandsFrontend.LocalTeleport(islandName)
        end)
        if ok and res == true then
            return true
        end
    end

    -- 4. Direct CFrame teleport to island model if loaded
    local islModel = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Islands") and workspace._MAP.Islands:FindFirstChild(islandName)
    if islModel then
        local interact = islModel:FindFirstChild("Interact")
        local tp = interact and interact:FindFirstChild("Teleport")
        local point = tp and (tp:FindFirstChild("Teleport") or tp:FindFirstChildWhichIsA("BasePart") or tp.PrimaryPart)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and point then
            hrp.CFrame = point.CFrame + Vector3.new(0, 3, 0)
            return true
        end
    end

    return false
end

-- Purchases island
function AutoProgAPI.UnlockIsland(islandName: string): boolean
    if AutoProgAPI.IsIslandUnlocked(islandName) then
        return true
    end
    if not Channels.Portals then return false end

    local pOk, pRes = pcall(function()
        return Channels.Portals:InvokeServer("PurchaseIsland", islandName)
    end)
    if (pOk and pRes == true) or AutoProgAPI.IsIslandUnlocked(islandName) then
        return true
    end

    local hOk, hRes = pcall(function()
        return Channels.Portals:InvokeServer("UnlockIslandByHitbox", islandName)
    end)
    if (hOk and hRes == true) or AutoProgAPI.IsIslandUnlocked(islandName) then
        return true
    end

    task.wait(0.1)
    return AutoProgAPI.IsIslandUnlocked(islandName)
end

-- Batch unlocks all affordable islands sequentially
function AutoProgAPI.UnlockAllAffordableIslands(): (number, string?)
    local count = 0
    local lastUnlocked = nil

    while true do
        local nextIsld = AutoProgAPI.GetNextLockedIsland()
        if not nextIsld then break end

        local pData = AutoProgAPI.GetPlayerData()
        if pData.Clicks < nextIsld.cost then break end

        local ok = AutoProgAPI.UnlockIsland(nextIsld.name)
        if ok or AutoProgAPI.IsIslandUnlocked(nextIsld.name) then
            count = count + 1
            lastUnlocked = nextIsld.name
            task.wait(0.15)
        else
            break
        end
    end

    return count, lastUnlocked
end

--==============================================================================
-- EGGS & PETS AUTOMATION
--==============================================================================

AutoProgAPI.ProgressionEggs = {
    { name = "BasicEgg",       cost = 250,        island = "Spawn",    world = "Overworld" },
    { name = "FlowerEgg",      cost = 2750,       island = "Spawn",    world = "Overworld" },
    { name = "AcornEgg",       cost = 175000,     island = "Spawn",    world = "Overworld" },
    { name = "SnowmanEgg",     cost = 1500000,    island = "Winter",   world = "Overworld" },
    { name = "WoodEgg",        cost = 40000000,   island = "Forest",   world = "Overworld" },
    { name = "CactusEgg",      cost = 300000000,  island = "Desert",   world = "Overworld" },
    { name = "CottonCandyEgg", cost = 20000000000,island = "Candy",    world = "Overworld" },
    { name = "ChocolateEgg",   cost = 70000000000,island = "Candy",    world = "Overworld" },
    { name = "PalmTreeEgg",    cost = 450000000000,island = "Beach",   world = "Overworld" },
    { name = "BeachBallEgg",   cost = 900000000000,island = "Beach",   world = "Overworld" },
    { name = "BlossomEgg",     cost = 1e14,       island = "Sakura",   world = "Overworld" },
    { name = "VolcanoEgg",     cost = 1e16,       island = "Volcano",  world = "Overworld" },
    { name = "DiscoEgg",       cost = 2e17,       island = "Rave",     world = "Overworld" },
    { name = "AngelEgg",       cost = 4e18,       island = "Heaven",   world = "Overworld" },
    { name = "CastleEgg",      cost = 5e19,       island = "Castle",   world = "Overworld" },
    { name = "CursedEgg",      cost = 1.5e20,     island = "Mystical", world = "Overworld" },
    { name = "DemonicEgg",     cost = 1.5e22,     island = "Hell",     world = "Overworld" },
    { name = "HolographicEgg", cost = 1.5e23,     island = "Base",     world = "Techworld" },
    { name = "404Egg",         cost = 5e23,       island = "Spaceship",world = "Techworld" },
    { name = "RedTechEgg",     cost = 1e24,       island = "Spaceship",world = "Techworld" },
    { name = "FragmentedEgg",  cost = 5e24,       island = "Fragment", world = "Techworld" },
    { name = "MatrixEgg",      cost = 2.5e25,     island = "Matrix",   world = "Techworld" },
}

-- Checks whether every single equipped pet slot is filled with Golden (or better) pets
function AutoProgAPI.IsEquippedTeamAllGold(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local pets = stats.Pets or {}
    local count = 0

    for guid, _ in pairs(equipped) do
        count = count + 1
        local p = pets[guid]
        if not p then return false end
        local isGoldOrBetter = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")
        if not isGoldOrBetter then
            return false
        end
    end

    return (count > 0)
end

function AutoProgAPI.HasFullGoldEventTeam(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local pets = stats.Pets or {}
    local count = 0
    local eventDrops = { WitchDog = true, WitchCat = true, MapleLeaf = true }

    for guid, _ in pairs(equipped) do
        count = count + 1
        local p = pets[guid]
        if not p then return false end
        local isEvent = (eventDrops[p.id] == true)
        local isGold = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")
        if not (isEvent and isGold) then
            return false
        end
    end
    return (count > 0)
end

-- Finds highest affordable egg across unlocked islands
function AutoProgAPI.GetBestAffordableEgg()
    local pData = AutoProgAPI.GetPlayerData()
    local curClicks = pData.Clicks

    -- If player can afford 10M Event Egg (10 Qa / 1e16 clicks) and doesn't have a full gold event team yet, prioritize it!
    local isFullGoldEvent = false
    pcall(function() isFullGoldEvent = AutoProgAPI.HasFullGoldEventTeam() end)
    if curClicks >= 1e16 and not isFullGoldEvent then
        local eventWorld = (pData.CurrentWorld == "Techworld") and "Techworld" or "Overworld"
        return { name = "CandyCornEgg", cost = 1e16, island = "Spawn", world = eventWorld }
    end

    local bestEgg = nil
    for _, egg in ipairs(AutoProgAPI.ProgressionEggs) do
        if AutoProgAPI.IsIslandUnlocked(egg.island) and curClicks >= egg.cost then
            bestEgg = egg
        end
    end
    return bestEgg or AutoProgAPI.ProgressionEggs[1]
end

-- Teleports character right in front of target egg model
function AutoProgAPI.TeleportToEgg(eggName: string): boolean
    local cleanName = eggName:gsub("%s+", "")
    local eggsFolder = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Interact") and workspace._MAP.Interact:FindFirstChild("Eggs")
    local eggModel = eggsFolder and (eggsFolder:FindFirstChild(cleanName) or eggsFolder:FindFirstChild(eggName))
    if not eggModel then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if (desc.Name == cleanName or desc.Name == eggName) and desc:IsA("Model") then
                eggModel = desc
                break
            end
        end
    end
    if eggModel then
        local targetPart = eggModel:FindFirstChild("Point") or eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart")
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and targetPart then
            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
            return true
        end
    end
    return false
end

-- Opens egg ensuring correct world and proximity
local nextAllowedHatchTick = 0
function AutoProgAPI.OpenEgg(eggName: string, amount: number?, skipTeleport: boolean?): (boolean, string)
    if not Channels.Egg then return false, "No egg channel" end
    local now = tick()
    if now < nextAllowedHatchTick then
        return false, "Hatch cooldown"
    end

    amount = amount or 1
    local cleanName = eggName:gsub("%s+", "")

    -- Find target world for egg
    local targetWorld = nil
    for _, egg in ipairs(AutoProgAPI.ProgressionEggs) do
        if egg.name == cleanName or egg.name == eggName then
            targetWorld = egg.world
            break
        end
    end
    if targetWorld then
        local stats = Stats.Local(true) or {}
        local curWorld = stats.CurrentWorld or "Overworld"
        if curWorld ~= targetWorld then
            AutoProgAPI.TeleportToWorld(targetWorld)
            task.wait(0.6)
        end
    end

    if not skipTeleport then
        AutoProgAPI.TeleportToEgg(cleanName)
    end

    local guid = HttpService:GenerateGUID(false)
    local ok, res, msg = pcall(function()
        return Channels.Egg:InvokeServer("Open", cleanName, amount, guid)
    end)

    if ok and res == true then
        nextAllowedHatchTick = tick() + 0.25
        return true, "Hatched " .. cleanName
    else
        nextAllowedHatchTick = tick() + 0.4
        return false, tostring(msg or res or "Failed to open")
    end
end

-- Equips best pets
function AutoProgAPI.EquipBest()
    if Channels.Pets then
        Channels.Pets:FireServer("EquipBest")
    end
end

function AutoProgAPI.UnequipAll()
    if Channels.Pets then
        Channels.Pets:FireServer("UnequipAll")
    end
end

-- Converts batches of duplicate normal pets into Golden pets with 100% Guaranteed Chance Priority
function AutoProgAPI.CraftGoldenPets(): number
    if not Channels.Pets then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local reduction = 0
    pcall(function()
        local MasteryFrontend = require(Client:WaitForChild("MasteryFrontend"))
        reduction = (MasteryFrontend and MasteryFrontend.GetPower and MasteryFrontend.GetPower(stats, "GoldenCraftPetReduction")) or 0
    end)
    local requiredFor100 = math.max(1, 6 - reduction)

    local groups = {}
    for guid, p in pairs(pets) do
        local isEquipped = equipped[guid] ~= nil
        local isLocked = p.Locked == true or p.l == true
        local isNormal = (p.v == nil or p.v == "Normal")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        if not isEquipped and not isLocked and isNormal and not isExclusive then
            local key = p.id .. "_" .. tostring(p.Shiny or p.s or false)
            if not groups[key] then
                local meta = Directory.Pets and Directory.Pets[p.id] or {}
                local multi = (meta.Stats and meta.Stats.Clicks) or 1
                groups[key] = { id = p.id, multi = multi, guids = {} }
            end
            table.insert(groups[key].guids, guid)
        end
    end

    local groupList = {}
    for _, g in pairs(groups) do table.insert(groupList, g) end
    table.sort(groupList, function(a, b) return a.multi > b.multi end)

    local craftedCount = 0
    for _, g in ipairs(groupList) do
        while #g.guids >= requiredFor100 do
            local batch = {}
            for i = 1, requiredFor100 do
                table.insert(batch, table.remove(g.guids, 1))
            end
            local ok, res = pcall(function()
                return Channels.Pets:InvokeServer("CraftGolden", batch)
            end)
            if ok and (res == true or type(res) == "table") then
                craftedCount = craftedCount + 1
                task.wait(0.2)
            else
                break
            end
        end
    end
    return craftedCount
end

-- Rainbow crafting and claiming
function AutoProgAPI.ClaimRainbowPets(): number
    if not Channels.Pets then return 0 end
    local stats = Stats.Local(true) or {}
    local rainbowTable = stats.RainbowCrafting or stats.RainbowPets or {}
    local claimed = 0
    local now = os.time()

    for slotId, craftData in pairs(rainbowTable) do
        if type(craftData) == "table" and craftData.CompleteTime and craftData.CompleteTime <= now then
            local ok, res = pcall(function()
                return Channels.Pets:InvokeServer("ClaimRainbow", slotId)
            end)
            if ok and (res == true or type(res) == "table") then
                claimed = claimed + 1
                task.wait(0.1)
            end
        end
    end
    return claimed
end

-- Map every pet to originating island index (1 to 17)
local petIslandIndexMap = nil
local function buildPetIslandMap()
    if petIslandIndexMap then return petIslandIndexMap end
    petIslandIndexMap = {}
    for _, isld in ipairs(AutoProgAPI.OrderedIslands) do
        for _, eggName in ipairs(isld.eggs) do
            local eggData = Directory.Eggs and Directory.Eggs[eggName]
            if eggData and eggData.Pets then
                for _, p in ipairs(eggData.Pets) do
                    local pId = p.Value or p.Id
                    if pId and not petIslandIndexMap[pId] then
                        petIslandIndexMap[pId] = isld.num -- 1 to 17
                    end
                end
            end
        end
    end
    return petIslandIndexMap
end

-- Weak pet deletion: If highest unlocked island is N, delete all normal pets from world (N - 2) and below
function AutoProgAPI.CleanWeakPets(protectCrafting: boolean?): number
    if protectCrafting == nil then protectCrafting = true end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local furthestIsland = AutoProgAPI.GetFurthestUnlockedIsland()
    local meta = islandMetaLookup[furthestIsland]
    local highestWorldIndex = meta and meta.num or 1
    local deleteThreshold = highestWorldIndex - 2 -- e.g. 17 - 2 = 15; 16 - 2 = 14

    local petMap = buildPetIslandMap()
    local bestEgg = AutoProgAPI.GetBestAffordableEgg()
    local bestEggPets = {}
    if bestEgg and Directory.Eggs and Directory.Eggs[bestEgg.name] then
        local drops = Directory.Eggs[bestEgg.name].Pets or {}
        for _, p in ipairs(drops) do
            local pId = p.Value or p.Id
            if pId then bestEggPets[pId] = true end
        end
    end

    local normalCounts = {}
    for guid, pData in pairs(pets) do
        if pData.v == nil or pData.v == "Normal" then
            normalCounts[pData.id] = (normalCounts[pData.id] or 0) + 1
        end
    end

    local toDelete = {}
    for guid, p in pairs(pets) do
        -- Never delete equipped or locked pets
        if not equipped[guid] and not p.Locked and not p.l then
            -- Never delete special/high tier pets
            local isSpecial = (p.rarity == "Secret" or p.rarity == "Divine" or p.rarity == "Mega" or p.rarity == "Exclusive")
            local isShiny = (p.Shiny or p.s or false)
            local isVariant = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")

            if not isSpecial and not isShiny and not isVariant then
                local petOriginWorld = petMap[p.id] or 1
                -- Check delete threshold: world <= (highest - 2)
                if petOriginWorld <= deleteThreshold then
                    local isBestEggDrop = bestEggPets[p.id] == true
                    local isCraftingCandidate = protectCrafting and (isBestEggDrop or (normalCounts[p.id] and normalCounts[p.id] >= 2))
                    if not isCraftingCandidate then
                        table.insert(toDelete, guid)
                    end
                end
            end
        end
    end

    if #toDelete > 0 and Channels.Pets then
        for i = 1, #toDelete, 50 do
            local batch = {}
            for j = i, math.min(i + 49, #toDelete) do
                table.insert(batch, toDelete[j])
            end
            pcall(function()
                Channels.Pets:FireServer("DeletePetsBulk", batch)
            end)
            task.wait(0.1)
        end
    end

    return #toDelete
end

--==============================================================================
-- GEM UPGRADES & REBIRTH BUTTONS
--==============================================================================
function AutoProgAPI.BuyAffordableGemUpgrades(): number
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local bought = 0
    if not Directory.Upgrades or not Channels.Upgrades then return 0 end

    for id, data in pairs(Directory.Upgrades) do
        local curLvl = stats.Upgrades and stats.Upgrades[id] or 0
        local nextTier = data.Tiers and data.Tiers[curLvl + 1]
        if nextTier and data.Currency == "Gems" and gems >= nextTier.Price then
            Channels.Upgrades:FireServer("Buy", id)
            gems = gems - nextTier.Price
            bought = bought + 1
            task.wait(0.08)
        end
    end
    return bought
end

function AutoProgAPI.BuyNextRebirthButton(): boolean
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local ownedList = stats.OwnedRebirthButtons or {}
    local unlockedIslands = stats.UnlockedIslands or {"Spawn"}

    local ownedMap = {}
    for k, v in pairs(ownedList) do
        local n = type(v) == "number" and v or (v == true and tonumber(k)) or tonumber(v) or tonumber(k)
        if n then ownedMap[n] = true end
    end

    local unlockedMap = {}
    for _, isl in pairs(unlockedIslands) do unlockedMap[isl] = true end
    unlockedMap["Spawn"] = true

    if not Constants.Rebirths or not Channels.RebirthShop then return false end

    local buttonIndices = {}
    for k in pairs(Constants.Rebirths) do
        local num = tonumber(k)
        if num and num >= 4 then table.insert(buttonIndices, num) end
    end
    table.sort(buttonIndices)

    local boughtAny = false
    for _, idx in ipairs(buttonIndices) do
        if not ownedMap[idx] then
            local rData = Constants.Rebirths[idx]
            local islandOk = (rData.RequiredIsland == nil or unlockedMap[rData.RequiredIsland] == true)
            if islandOk and gems >= (rData.Cost or 0) then
                local ok = Channels.RebirthShop:InvokeServer("BuyRebirthButton", idx)
                if ok == true then
                    boughtAny = true
                    ownedMap[idx] = true
                    gems = gems - (rData.Cost or 0)
                    task.wait(0.1)
                else
                    break
                end
            else
                break
            end
        end
    end
    return boughtAny
end

function AutoProgAPI.BuyNextDoubleJump(): boolean
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local curJumps = stats.Upgrades and stats.Upgrades.DoubleJumps or 1
    local nextJump = curJumps + 1
    local unlockedIslands = stats.UnlockedIslands or {"Spawn"}
    local unlockedMap = {}
    for _, isl in pairs(unlockedIslands) do unlockedMap[isl] = true end

    if not Constants.DoubleJumps or not Channels.RebirthShop then return false end
    local jData = Constants.DoubleJumps[nextJump]
    if not jData then return false end
    local islandOk = (jData.RequiredIsland == nil or unlockedMap[jData.RequiredIsland] == true)
    if islandOk and gems >= (jData.Cost or 0) then
        local ok = Channels.RebirthShop:InvokeServer("BuyDoubleJump", nextJump)
        return ok == true
    end
    return false
end

function AutoProgAPI.BuyAffordableMiniUpgrades(): number
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local bought = 0
    local unlocked = stats.UnlockedIslands or {"Spawn"}
    local miniData = Directory.MiniUpgrades or {}
    local curMini = stats.MiniUpgrades or {}

    for _, islandName in ipairs(unlocked) do
        local islMini = miniData[islandName]
        if type(islMini) == "table" then
            for upgradeKey, upgradeDef in pairs(islMini) do
                local curLvl = (curMini[islandName] and curMini[islandName][upgradeKey]) or 0
                local tiers = upgradeDef.Tiers or {}
                local nextTier = tiers[curLvl + 1]
                if nextTier and (nextTier.Currency == "Gems" or nextTier.Currency == nil) then
                    local cost = nextTier.Cost or nextTier.Price or 0
                    if cost > 0 and gems >= cost then
                        local ok = pcall(function()
                            if Channels.MiniUpgrades then
                                Channels.MiniUpgrades:InvokeServer("Buy", islandName, upgradeKey)
                            end
                        end)
                        if ok then
                            gems = gems - cost
                            bought = bought + 1
                            task.wait(0.08)
                        end
                    end
                end
            end
        end
    end
    return bought
end

--==============================================================================
-- SKILL TREE & BREAKABLES (COINS FIRST -> TECH COINS)
--==============================================================================

function AutoProgAPI.GetSkillTreeProgress()
    local skillTreeDefault = Directory.SkillTree and Directory.SkillTree.Default
    local stats = Stats.Local(true) or {}
    local userSkills = stats.SkillTree or {}

    local coinsBought = 0
    local coinsTotal = 0
    local techBought = 0
    local techTotal = 0

    if skillTreeDefault then
        for nodeName, nodeData in pairs(skillTreeDefault) do
            if type(nodeData) == "table" and nodeData.Upgrades then
                for upgId, upgData in pairs(nodeData.Upgrades) do
                    local currencyId = upgData.Price and upgData.Price.Id or "Unknown"
                    local bought = (userSkills[upgId] == true)
                    if currencyId == "Coins" then
                        coinsTotal = coinsTotal + 1
                        if bought then coinsBought = coinsBought + 1 end
                    elseif currencyId == "SpaceCoins" then
                        techTotal = techTotal + 1
                        if bought then techBought = techBought + 1 end
                    end
                end
            end
        end
    end

    return {
        CoinsBought = coinsBought,
        CoinsTotal = coinsTotal,
        CoinsComplete = (coinsTotal > 0 and coinsBought >= coinsTotal),
        TechBought = techBought,
        TechTotal = techTotal,
        TechComplete = (techTotal > 0 and techBought >= techTotal),
        UserSkills = userSkills
    }
end

function AutoProgAPI.BuyAffordableSkillTree(preferCoins: boolean?): number
    if not Directory.SkillTree or not Channels.SkillTree then return 0 end
    local stats = Stats.Local(true) or {}
    local userSkills = stats.SkillTree or {}
    local pData = AutoProgAPI.GetPlayerData()

    local coins = pData.Coins
    local spaceCoins = pData.SpaceCoins
    local boughtCount = 0

    local skillTreeDefault = Directory.SkillTree.Default
    if not skillTreeDefault then return 0 end

    local candidates = {}
    for nodeName, nodeData in pairs(skillTreeDefault) do
        if type(nodeData) == "table" and nodeData.Upgrades then
            for upgId, upgData in pairs(nodeData.Upgrades) do
                if not userSkills[upgId] then
                    local req = upgData.Requires or {}
                    local parentBought = (req.Upgrade == nil or userSkills[req.Upgrade] == true)
                    local curr = upgData.Price and upgData.Price.Id
                    local cost = upgData.Price and upgData.Price.Amount or 0

                    if parentBought and curr and cost > 0 then
                        if curr == "Coins" and coins >= cost then
                            table.insert(candidates, { id = upgId, curr = curr, cost = cost, prio = 1 })
                        elseif curr == "SpaceCoins" and spaceCoins >= cost then
                            table.insert(candidates, { id = upgId, curr = curr, cost = cost, prio = preferCoins and 2 or 1 })
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        return a.cost < b.cost
    end)

    for _, c in ipairs(candidates) do
        local ok, res = pcall(function()
            return Channels.SkillTree:InvokeServer("Buy", c.id)
        end)
        if ok and (res == true or type(res) == "table") then
            boughtCount = boughtCount + 1
            userSkills[c.id] = true
            if c.curr == "Coins" then coins = coins - c.cost end
            if c.curr == "SpaceCoins" then spaceCoins = spaceCoins - c.cost end
            task.wait(0.1)
        end
    end

    return boughtCount
end

-- Breakables Target Lock & State
local activeCoinsIsland = "Heaven"
local lastBreakablesSwitchTick = 0

function AutoProgAPI.GetActiveBreakablesCount(islandName: string, zoneName: string?): number
    zoneName = zoneName or "1"
    if not BreakablesFrontend or not BreakablesFrontend.GetSnapshots then return 0 end
    local snapshots = BreakablesFrontend.GetSnapshots() or {}
    local count = 0
    for _, s in pairs(snapshots) do
        if s.islandId == islandName and s.hp and s.hp > 0 then
            if not zoneName or s.zoneName == zoneName then
                count = count + 1
            end
        end
    end
    return count
end

function AutoProgAPI.AttackBreakablesInZone(targetIsland: string, ignoreBossChest: boolean?): (boolean, string?)
    if ignoreBossChest == nil then ignoreBossChest = true end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end

    -- Verify player is on the target island
    local stats = Stats.Local(true) or {}
    if stats.CurrentIsland ~= targetIsland then
        AutoProgAPI.TeleportToIsland(targetIsland)
        task.wait(0.5)
        return true, "Teleported to " .. targetIsland
    end

    -- Enter zone
    local zoneId = targetIsland .. "/1"
    if BreakablesFrontend then
        pcall(function() BreakablesFrontend.EnterZone(zoneId) end)
    end

    -- Find target breakable model
    local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    local targetModel = nil
    local bestDist = math.huge

    if breakablesFolder then
        for _, f in ipairs(breakablesFolder:GetChildren()) do
            local m = f:FindFirstChildWhichIsA("Model")
            if m and m:GetAttribute("BreakableUID") then
                local bZone = tostring(m:GetAttribute("BreakableZone") or "")
                local bName = tostring(m:GetAttribute("BreakableId") or m.Name):lower()
                local isBoss = bName:find("giant") or bName:find("boss") or bName:find("huge") or bName:find("chest")

                if (bZone == "" or bZone:find(targetIsland)) and not (ignoreBossChest and isBoss) then
                    local hp = m:GetAttribute("BreakableHP") or 1
                    if hp > 0 then
                        local dist = (m:GetPivot().Position - hrp.Position).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            targetModel = m
                        end
                    end
                end
            end
        end
    end

    if not targetModel then
        return false, "No active breakables in zone"
    end

    -- Teleport close to target breakable
    local pivot = targetModel:GetPivot()
    if (hrp.Position - pivot.Position).Magnitude > 8 then
        hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 1.5, 3), pivot.Position)
    end

    -- Attack via BreakablesFrontend
    if BreakablesFrontend then
        pcall(function()
            BreakablesFrontend.SetExternalTarget(targetModel)
            BreakablesFrontend.ReportClick(targetModel)
            local equipped = stats.EquippedPets or {}
            for guid, _ in pairs(equipped) do
                BreakablesFrontend.ReportStrike(guid)
            end
        end)
    end

    return true, targetModel.Name
end

-- Executes the full Coins (Volcano <-> Heaven) -> Tech World breakables state machine
function AutoProgAPI.StepBreakablesPipeline(): (string, string)
    local stProg = AutoProgAPI.GetSkillTreeProgress()
    local now = tick()

    -- 1. Coins Skill Tree NOT done: Alternate between Volcano and Heaven!
    if not stProg.CoinsComplete then
        local stats = Stats.Local(true) or {}
        local curIsland = stats.CurrentIsland or "Heaven"
        local curWorld = stats.CurrentWorld or "Overworld"

        if curWorld ~= "Overworld" then
            AutoProgAPI.TeleportToWorld("Overworld")
            task.wait(0.5)
        end

        local activeOnCur = AutoProgAPI.GetActiveBreakablesCount(activeCoinsIsland, "1")
        if activeOnCur == 0 or (now - lastBreakablesSwitchTick > 20) then
            -- Zone cleared or time elapsed: Switch island!
            lastBreakablesSwitchTick = now
            activeCoinsIsland = (activeCoinsIsland == "Volcano") and "Heaven" or "Volcano"
            AutoProgAPI.TeleportToIsland(activeCoinsIsland)
            task.wait(0.4)
            return "Switched Coins Zone", activeCoinsIsland
        end

        AutoProgAPI.AttackBreakablesInZone(activeCoinsIsland, true)
        pcall(function() AutoProgAPI.BuyAffordableSkillTree(true) end)
        return "Farming Coins", activeCoinsIsland

    -- 2. Coins skill tree complete: Teleport to latest Tech World (Matrix) to farm Tech Coins!
    else
        local stats = Stats.Local(true) or {}
        local curWorld = stats.CurrentWorld or "Techworld"

        if curWorld ~= "Techworld" then
            AutoProgAPI.TeleportToWorld("Techworld")
            task.wait(0.5)
        end

        local techTarget = AutoProgAPI.IsIslandUnlocked("Matrix") and "Matrix" or (AutoProgAPI.IsIslandUnlocked("Fragment") and "Fragment" or "Base")
        AutoProgAPI.AttackBreakablesInZone(techTarget, true)
        pcall(function() AutoProgAPI.BuyAffordableSkillTree(false) end)
        return "Farming Tech Coins", techTarget
    end
end

--==============================================================================
-- CONSUMABLES & GLOBAL REWARDS
--==============================================================================

function AutoProgAPI.UseAllBestPotions(): number
    local stats = Stats.Local(true) or {}
    local potions = stats.Potions or {}
    local usedCount = 0
    local types = { "Clicks", "Speed", "Luck", "Gems" }

    for _, pType in ipairs(types) do
        local bestTier = nil
        local bestAmt = 0
        for tier = 1, 10 do
            local key = pType .. tostring(tier)
            local amt = potions[key] or (potions[pType] and potions[pType][tier]) or 0
            if amt > 0 then
                bestTier = tier
                bestAmt = amt
            end
        end
        if bestTier and Channels.Potions then
            local ok = pcall(function()
                Channels.Potions:InvokeServer("Use", pType, bestTier)
            end)
            if ok then usedCount = usedCount + 1 end
        end
    end
    return usedCount
end

function AutoProgAPI.UseAllFruits(): number
    local stats = Stats.Local(true) or {}
    local fruits = stats.Fruits or {}
    local usedCount = 0
    local fruitTypes = { "Apple", "Banana", "Orange", "Grape", "Pineapple", "Dragonfruit", "Pear" }

    for _, fName in ipairs(fruitTypes) do
        local count = fruits[fName] or 0
        if count > 0 and Channels.Fruits then
            local ok = pcall(function()
                Channels.Fruits:InvokeServer("Use", fName, math.min(count, 5))
            end)
            if ok then usedCount = usedCount + 1 end
        end
    end
    return usedCount
end

function AutoProgAPI.ClaimAllFreeGifts(): number
    if not Channels.FreeGifts then return 0 end
    local claimed = 0
    for i = 1, 12 do
        local ok, res = pcall(function()
            return Channels.FreeGifts:InvokeServer("Claim", i)
        end)
        if ok and (res == true or type(res) == "table") then
            claimed = claimed + 1
        end
    end
    return claimed
end

function AutoProgAPI.ClaimAllChests(): number
    local claimed = 0
    if Channels.BeachChest then
        pcall(function()
            if Channels.BeachChest:InvokeServer("Claim") == true then claimed = claimed + 1 end
        end)
    end
    return claimed
end

function AutoProgAPI.ClaimDaily(): boolean
    if not Channels.DailyRewards then return false end
    local ok, res = pcall(function() return Channels.DailyRewards:InvokeServer("Claim") end)
    return ok and res == true
end

function AutoProgAPI.ClaimAllAchievements(): number
    if not Channels.Achievements then return 0 end
    local claimed = 0
    local stats = Stats.Local(true) or {}
    local ach = stats.Achievements or {}
    for id, data in pairs(ach) do
        if type(data) == "table" and data.Claimable == true then
            local ok = pcall(function()
                Channels.Achievements:InvokeServer("Claim", id)
            end)
            if ok then claimed = claimed + 1 end
        end
    end
    return claimed
end

function AutoProgAPI.RedeemAllCodes(): number
    if not Channels.Codes or not Directory.Codes then return 0 end
    local redeemed = 0
    for codeName, _ in pairs(Directory.Codes) do
        pcall(function()
            if Channels.Codes:InvokeServer("Redeem", codeName) == true then
                redeemed = redeemed + 1
            end
        end)
    end
    return redeemed
end

--==============================================================================
-- CLICK SKINS & 10 QI REBIRTH GOAL
--==============================================================================
function AutoProgAPI.CheckAndEquipMagmaSkin(): (boolean, string)
    local pData = AutoProgAPI.GetPlayerData()
    local rebirths = pData.Rebirths or 0
    local targetRebirths = 1e19 -- 10 Qi Rebirths

    local stats = Stats.Local(true) or {}
    local skins = stats.ClickSkins or {}
    local equippedSkin = stats.EquippedClickSkin

    if equippedSkin == "Magma" then
        return true, "Magma Click Skin Active (+4 Egg Hatch, +20% Speed)"
    end

    if skins["Magma"] == true then
        if Channels.Click then
            Channels.Click:FireServer("EquipSkin", "Magma")
        end
        return true, "Equipped Magma Click Skin (+4 Egg Hatch, +20% Speed)"
    end

    if rebirths >= targetRebirths then
        if Channels.Click then
            Channels.Click:FireServer("UnlockSkin", "Magma")
            Channels.Click:FireServer("EquipSkin", "Magma")
        end
        return true, "Unlocked & Equipped Magma Click Skin (+4 Egg Hatch, +20% Speed)"
    end

    local pct = math.clamp(math.floor((rebirths / targetRebirths) * 100), 0, 100)
    return false, string.format("10 Qi Rebirth Check: %s / 10.00Qi (%d%%)", AutoProgAPI.FormatNumber(rebirths), pct)
end

--==============================================================================
-- SECRET ??? QUESTLINE SOLVER
--==============================================================================
function AutoProgAPI.GetSecretQuestProgress()
    local stats = Stats.Local(true) or {}
    local quests = stats.Quests or {}
    local secretQ = quests["???"] or quests["Secret"] or {}

    local feathersProg = secretQ.Feathers or 0
    local hatchProg = secretQ.HatchCount or 0
    local goldenProg = secretQ.GoldenCrafts or 0

    return {
        isUnlocked = stats.DominusAreaUnlocked == true,
        feathers = { prog = feathersProg, req = 10, done = feathersProg >= 10 },
        hatch = { prog = hatchProg, req = 2500, done = hatchProg >= 2500 },
        golden = { prog = goldenProg, req = 10, done = goldenProg >= 10 },
        allDone = (feathersProg >= 10 and hatchProg >= 2500 and goldenProg >= 10)
    }
end

function AutoProgAPI.StepSecretQuest(): (boolean, string)
    local prog = AutoProgAPI.GetSecretQuestProgress()
    if prog.isUnlocked then
        return true, "Dominus Door Already Unlocked!"
    end

    -- 1. Collect Feathers
    if not prog.feathers.done then
        local feathersFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Feathers")
        if feathersFolder then
            for _, f in ipairs(feathersFolder:GetChildren()) do
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and f:IsA("BasePart") then
                    hrp.CFrame = f.CFrame
                    task.wait(0.2)
                    return true, string.format("Collecting Feather (%d / 10)", prog.feathers.prog)
                end
            end
        end
    end

    -- 2. Craft Golden Pets
    if not prog.golden.done then
        local crafted = AutoProgAPI.CraftGoldenPets()
        if crafted > 0 then
            return true, string.format("Crafted %d Golden Pets (%d / 10)", crafted, prog.golden.prog)
        end
    end

    -- 3. Door Claim
    if prog.allDone and not prog.isUnlocked and Channels.Quests then
        local ok, res = pcall(function()
            return Channels.Quests:InvokeServer("UnlockSecretDoor")
        end)
        return true, "Claimed Secret Area Door: " .. tostring(res)
    end

    return true, "Secret Quest in progress"
end

return AutoProgAPI
