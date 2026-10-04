--!strict
--==============================================================================
-- [AUTOPROG] ProgAPI.lua
-- Dedicated Full Zero-to-Hero Auto Progression API Engine for Clicker Simulator!
-- Integrates directly with game internal Network channels, Stats, Directory,
-- Balancing, and Frontend modules.
--==============================================================================

local ProgAPI = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Resolve Library & Client Modules safely
local Library = ReplicatedStorage:WaitForChild("Library", 10)
if not Library then
    error("[ProgAPI] Failed to locate ReplicatedStorage.Library!")
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

local AchievementsFrontend = nil
pcall(function() AchievementsFrontend = require(Client:WaitForChild("AchievementsFrontend", 5)) end)

local AutoRebirthFrontend = nil
pcall(function() AutoRebirthFrontend = require(Client:WaitForChild("AutoRebirthFrontend", 5)) end)

local SkillTreeFrontend = nil
pcall(function() SkillTreeFrontend = require(Client:WaitForChild("SkillTreeFrontend", 5)) end)

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
    Breakables = Network.Channel("Breakables"),
    SummerEvent2026 = Network.Channel("SummerEvent2026"),
    RetentionGift = Network.Channel("RetentionGift"),
    LeavingGift = Network.Channel("LeavingGift"),
    LikesGoal = Network.Channel("LikesGoal"),
    SpinWheel = Network.Channel("SpinWheel"),
}

ProgAPI.Channels = Channels
ProgAPI.Directory = Directory
ProgAPI.Constants = Constants
ProgAPI.Balancing = Balancing
ProgAPI.AchievementsFrontend = AchievementsFrontend
ProgAPI.AutoRebirthFrontend = AutoRebirthFrontend
ProgAPI.SkillTreeFrontend = SkillTreeFrontend
ProgAPI.BreakablesFrontend = BreakablesFrontend

-- Safe no-op to avoid interfering with game native UI modals and tabs
function ProgAPI.SuppressBlackShade()
    return true
end


--==============================================================================
-- NUMBER FORMATTING & PLAYER DATA
--==============================================================================
local SUFFIXES = {
    "", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
    "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"
}

function ProgAPI.FormatNumber(val: number?): string
    if not val or val ~= val then return "0" end
    if val < 0 then return "-" .. ProgAPI.FormatNumber(-val) end
    if val < 1000 then return tostring(math.floor(val)) end

    local exp = math.floor(math.log(val, 10) / 3)
    if exp < 1 then return tostring(math.floor(val)) end
    if exp > #SUFFIXES - 1 then
        return string.format("%.2e", val)
    end

    local scaled = val / (10 ^ (exp * 3))
    return string.format("%.2f%s", scaled, SUFFIXES[exp + 1])
end

function ProgAPI.GetPlayerData()
    local raw = Stats.Local(true) or {}
    local curr = raw.Currency or {}
    return {
        Clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or curr.Clicks or 0,
        Rebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or curr.Rebirths or 0,
        Gems = (Currency and Currency.Get and Currency.Get("Gems")) or curr.Gems or 0,
        Coins = (Currency and Currency.Get and Currency.Get("Coins")) or curr.Coins or 0,
        SpaceCoins = (Currency and Currency.Get and Currency.Get("SpaceCoins")) or curr.SpaceCoins or 0,
        Shells = (Currency and Currency.Get and Currency.Get("Shells")) or curr.Shells or 0,
        Prestiges = raw.Prestiges or 0,
        CurrentIsland = raw.CurrentIsland or "Spawn",
        CurrentWorld = raw.CurrentWorld or "Overworld",
        EquippedPets = raw.EquippedPets or {},
        UnlockedIslands = raw.UnlockedIslands or { "Spawn" },
        OwnedRebirthButtons = raw.OwnedRebirthButtons or {},
        SkillTree = raw.SkillTree or {},
    }
end

--==============================================================================
-- CLICKS & CORE MECHANICS
--==============================================================================
function ProgAPI.Click()
    if Channels.Click then
        Channels.Click:FireServer("Click", true)
    end
end

--==============================================================================
-- REBIRTHS & MAX REBIRTH
--==============================================================================
function ProgAPI.Rebirth(index: number)
    if Channels.Rebirths then
        Channels.Rebirths:FireServer("Rebirth", index or 1)
    end
end

function ProgAPI.MaxRebirth()
    return ProgAPI.RebirthMaxTarget()
end

-- Computes live data for the player's HIGHEST AFFORDABLE rebirth milestone button
function ProgAPI.GetMaxRebirthInfo()
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

-- Executes highest affordable rebirth milestone button directly
function ProgAPI.RebirthMaxTarget(): (boolean, any)
    local info = ProgAPI.GetMaxRebirthInfo()
    if info.CanAffordMax and info.BestAffordableIndex then
        -- 1. Direct channel fire to active button index
        if Channels.Rebirths then
            Channels.Rebirths:FireServer("Rebirth", info.BestAffordableIndex)
        end

        -- 2. Notify AutoRebirthFrontend
        if AutoRebirthFrontend then
            pcall(function()
                AutoRebirthFrontend.SetSelectedButtonIndex(info.BestAffordableIndex)
                AutoRebirthFrontend.RequestImmediateCheck()
            end)
        end

        -- 3. Click quick rebirth button in UI if available
        pcall(function()
            local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
            local qr = pg and pg:FindFirstChild("Main", true) and pg.Main:FindFirstChild("Left") and pg.Main.Left:FindFirstChild("QuickRebirth")
            local btn = qr and qr:FindFirstChild("Rebirth") and qr.Rebirth:FindFirstChild("Main") and qr.Rebirth.Main:FindFirstChild("Button")
            if btn and firesignal then
                firesignal(btn.Activated)
            end
        end)

        return true, info
    end

    return false, info
end

--==============================================================================
-- PRESTIGE AUTOMATION
--==============================================================================
function ProgAPI.GetPrestigeInfo()
    local stats = Stats.Local(true) or {}
    local curPrest = stats.Prestiges or 0
    local tiers = (Balancing and Balancing.Prestige and Balancing.Prestige.Tiers) or {}
    local nextTier = tiers[curPrest + 1]

    local curRebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or (stats.Currency and stats.Currency.Rebirths) or 0

    if not nextTier then
        return {
            CanPrestige = false,
            CurrentPrestige = curPrest,
            MaxPrestigeReached = true,
            RequiredRebirths = math.huge,
            CurrentRebirths = curRebirths,
        }
    end

    local reqRebirths = nextTier.RequiredRebirths or nextTier.Rebirths or 1e16
    return {
        CanPrestige = (curRebirths >= reqRebirths),
        CurrentPrestige = curPrest,
        MaxPrestigeReached = false,
        RequiredRebirths = reqRebirths,
        CurrentRebirths = curRebirths,
        Multipliers = nextTier.Multipliers or {}
    }
end

function ProgAPI.CheckAndTriggerPrestige(): (boolean, string)
    local pInfo = ProgAPI.GetPrestigeInfo()
    if pInfo.MaxPrestigeReached then
        return false, "Maximum Prestige level already achieved!"
    end

    if not pInfo.CanPrestige then
        return false, string.format("Need %s Rebirths (Have %s)", ProgAPI.FormatNumber(pInfo.RequiredRebirths), ProgAPI.FormatNumber(pInfo.CurrentRebirths))
    end

    if Channels.Prestige then
        local ok, res = pcall(function()
            return Channels.Prestige:InvokeServer("Prestige")
        end)
        if ok and (res == true or type(res) == "table") then
            return true, string.format("Successfully Prestiged to Tier %d!", pInfo.CurrentPrestige + 1)
        end
    end

    return false, "Prestige remote failed to execute."
end

--==============================================================================
-- ISLANDS & WORLDS SPEEDRUN ROADMAP
--==============================================================================
local ISLAND_SPEEDRUN_ROADMAP = {
    { name = "Spawn",     world = "Overworld", cost = 0,             num = 1 },
    { name = "Winter",    world = "Overworld", cost = 1000,          num = 2 },
    { name = "Forest",    world = "Overworld", cost = 25000,         num = 3 },
    { name = "Desert",    world = "Overworld", cost = 400000,        num = 4 },
    { name = "Candy",     world = "Overworld", cost = 6000000,       num = 5 },
    { name = "Beach",     world = "Overworld", cost = 100000000,     num = 6 },
    { name = "Sakura",    world = "Overworld", cost = 1500000000,    num = 7 },
    { name = "Base",      world = "Space",     cost = 25000000000,   num = 8 },
    { name = "Spaceship", world = "Space",     cost = 400000000000,  num = 9 },
    { name = "Volcano",   world = "Overworld", cost = 6000000000000, num = 10 },
    { name = "Rave",      world = "Overworld", cost = 80000000000000, num = 11 },
    { name = "Heaven",    world = "Overworld", cost = 1.2e15,        num = 12 },
    { name = "Castle",    world = "Overworld", cost = 1.8e16,        num = 13 },
    { name = "Mystical",  world = "Overworld", cost = 2.5e17,        num = 14 },
    { name = "Hell",      world = "Overworld", cost = 4e18,          num = 15 },
    { name = "Fragment",  world = "Techworld", cost = 6e19,          num = 16 },
    { name = "Matrix",    world = "Techworld", cost = 1e21,          num = 17 },
}

local islandMetaLookup = {}
for idx, data in ipairs(ISLAND_SPEEDRUN_ROADMAP) do
    islandMetaLookup[data.name] = data
end
ProgAPI.OrderedIslands = ISLAND_SPEEDRUN_ROADMAP

function ProgAPI.GetIslandMetadata(islandName: string)
    return islandMetaLookup[islandName]
end

function ProgAPI.IsIslandUnlocked(islandName: string): boolean
    if islandName == "Spawn" then return true end
    local stats = Stats.Local(true) or {}
    local unlocked = stats.UnlockedIslands or {}
    for _, name in pairs(unlocked) do
        if name == islandName then return true end
    end
    if IslandsFrontend and IslandsFrontend.IsUnlocked then
        local ok, res = pcall(IslandsFrontend.IsUnlocked, islandName)
        if ok and res then return true end
    end
    return false
end

function ProgAPI.GetFurthestUnlockedIsland(): string
    local furthest = "Spawn"
    for _, island in ipairs(ISLAND_SPEEDRUN_ROADMAP) do
        if ProgAPI.IsIslandUnlocked(island.name) then
            furthest = island.name
        end
    end
    return furthest
end

function ProgAPI.GetNextLockedIsland()
    for _, island in ipairs(ISLAND_SPEEDRUN_ROADMAP) do
        if not ProgAPI.IsIslandUnlocked(island.name) then
            return island
        end
    end
    return nil
end

function ProgAPI.TeleportToWorld(worldName: string): boolean
    if Channels.Portals then
        local ok, res = pcall(function()
            return Channels.Portals:InvokeServer("TeleportToWorld", worldName)
        end)
        return ok and res == true
    end
    return false
end

function ProgAPI.TeleportToIsland(islandName: string): boolean
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

    -- 3. Instant client local teleport
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

function ProgAPI.UnlockIsland(islandName: string): boolean
    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
    
    local def = Directory and Directory.Islands and Directory.Islands[islandName]
    local cost = (def and def.Cost) or (islandMetaLookup[islandName] and islandMetaLookup[islandName].cost) or 0
    if clicks < cost then return false end

    -- The official Clicker Simulator remote is Channels.Portals:InvokeServer("PurchaseIsland", islandName)
    if Channels.Portals then
        local ok, res = pcall(function()
            return Channels.Portals:InvokeServer("PurchaseIsland", islandName)
        end)
        if ok and res == true then
            return true
        end
    end

    if Channels.Islands then
        local ok, res = pcall(function()
            return Channels.Islands:InvokeServer("PurchaseIsland", islandName)
        end)
        if ok and res == true then
            return true
        end
    end

    return false
end

-- Checks all locked islands and automatically re-purchases any affordable islands in order (especially after Prestige)
function ProgAPI.CheckAndRebuyIslands(): (number, string?)
    local unlockedCount = 0
    local lastUnlocked = nil
    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0

    local ordered = {
        "Winter", "Forest", "Desert", "Candy", "Beach", "Sakura",
        "Volcano", "Rave", "Heaven", "Castle", "Mystical", "Hell",
        "Base", "Spaceship", "Fragment", "Matrix"
    }

    for _, islandId in ipairs(ordered) do
        if not ProgAPI.IsIslandUnlocked(islandId) then
            local def = Directory and Directory.Islands and Directory.Islands[islandId]
            local cost = (def and def.Cost) or (islandMetaLookup[islandId] and islandMetaLookup[islandId].cost) or 0
            if clicks >= cost then
                local ok = ProgAPI.UnlockIsland(islandId)
                if ok then
                    unlockedCount = unlockedCount + 1
                    lastUnlocked = islandId
                    task.wait(0.1)
                else
                    break
                end
            else
                break
            end
        end
    end

    return unlockedCount, lastUnlocked
end

function ProgAPI.UnlockAllAffordableIslands(): (number, string?)
    return ProgAPI.CheckAndRebuyIslands()
end

--==============================================================================
-- PETS, EGG HATCHING & GOLDEN CRAFTING
--==============================================================================
local REAL_PROGRESSION_EGGS = {
    { name = "BasicEgg",       cost = 250,         island = "Spawn" },
    { name = "FlowerEgg",      cost = 2750,        island = "Spawn" },
    { name = "AcornEgg",       cost = 175000,      island = "Spawn" },
    { name = "SnowmanEgg",     cost = 1500000,     island = "Winter" },
    { name = "WoodEgg",        cost = 40000000,    island = "Forest" },
    { name = "CactusEgg",      cost = 300000000,   island = "Desert" },
    { name = "CottonCandyEgg", cost = 20000000000, island = "Candy" },
    { name = "ChocolateEgg",   cost = 70000000000, island = "Candy" },
    { name = "PalmTreeEgg",    cost = 450000000000, island = "Beach" },
    { name = "BeachBallEgg",   cost = 900000000000, island = "Beach" },
    { name = "BlossomEgg",     cost = 1e14,        island = "Sakura" },
    { name = "TechEgg",        cost = 5e14,        island = "Base" },
    { name = "CosmicEgg",      cost = 1e15,        island = "Spaceship" },
    { name = "VolcanoEgg",     cost = 1e16,        island = "Volcano" },
    { name = "DiscoEgg",       cost = 2e17,        island = "Rave" },
    { name = "AngelEgg",       cost = 4e18,        island = "Heaven" },
    { name = "CastleEgg",      cost = 5e19,        island = "Castle" },
    { name = "CursedEgg",      cost = 1.5e20,      island = "Mystical" },
    { name = "DemonicEgg",     cost = 1.5e22,      island = "Hell" },
    { name = "FragmentedEgg",  cost = 5e23,        island = "Fragment" },
    { name = "MatrixEgg",      cost = 2.5e25,      island = "Matrix" },
    { name = "CandyCornEgg",   cost = 10000000,    island = "Spawn" },
}

local eggData = {}
for _, e in ipairs(REAL_PROGRESSION_EGGS) do
    eggData[e.name] = { cost = e.cost, island = e.island, name = e.name }
end

-- Dynamically incorporate any live eggs from Directory.Eggs
pcall(function()
    if Directory and Directory.Eggs then
        for name, data in pairs(Directory.Eggs) do
            local isRobux = (data.Currency == "Robux" or (data.Price and data.Price.Id == "Robux") or name:find("Robux"))
            if not isRobux then
                local cost = data.Cost or (data.Price and data.Price.Amount)
                local isl = data.RequiredIsland or data.Island
                if cost and isl then
                    eggData[name] = { cost = cost, island = isl, name = name }
                end
            end
        end
    end
end)

ProgAPI.EggData = eggData

-- Checker: Verifies if ALL 17 islands are unlocked (Strict requirement for Phase 2)
function ProgAPI.AreAllIslandsUnlocked(): boolean
    local locked = ProgAPI.GetNextLockedIsland()
    return (locked == nil)
end

-- Checks if entire equipped team is 100% Golden (or Rainbow)
function ProgAPI.IsEquippedTeamAllGold(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local hasAny = false

    for guid, _ in pairs(equipped) do
        hasAny = true
        local pInfo = stats.Pets and stats.Pets[guid]
        if not pInfo then return false end
        local isGold = (pInfo.v == "Golden" or pInfo.Variant == "Golden" or pInfo.Gold == true or pInfo.Type == "Golden" or pInfo.v == "Rainbow" or pInfo.Variant == "Rainbow")
        if not isGold then
            return false
        end
    end

    return hasAny
end

-- Checks if entire equipped team is 100% Rainbow
function ProgAPI.IsEquippedTeamAllRainbow(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local hasAny = false

    for guid, _ in pairs(equipped) do
        hasAny = true
        local pInfo = stats.Pets and stats.Pets[guid]
        if not pInfo then return false end
        local isRainbow = (pInfo.v == "Rainbow" or pInfo.Variant == "Rainbow")
        if not isRainbow then
            return false
        end
    end

    return hasAny
end

function ProgAPI.HasFullGoldEventTeam(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local maxSlots = stats.EquippedSlots or 6
    local count = 0

    for guid, _ in pairs(equipped) do
        local p = stats.Pets and stats.Pets[guid]
        if p and (p.id == "WitchCat" or p.id == "MapleLeaf") and (p.v == "Golden" or p.v == "Rainbow") then
            count = count + 1
        end
    end

    return (count >= maxSlots)
end

-- Retrieves best affordable egg for the current furthest island or specified target island
function ProgAPI.GetBestAffordableEgg(targetIsland: string?)
    local island = targetIsland or ProgAPI.GetFurthestUnlockedIsland()
    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0

    local bestEggName = nil
    local bestCost = 0

    -- 1. Try to match the best egg on the requested island
    for eggName, meta in pairs(eggData) do
        if meta.island == island and meta.cost <= clicks then
            if meta.cost >= bestCost then
                bestCost = meta.cost
                bestEggName = eggName
            end
        end
    end

    -- 2. Fallback to the highest affordable egg across any unlocked island
    if not bestEggName then
        for eggName, meta in pairs(eggData) do
            if ProgAPI.IsIslandUnlocked(meta.island) and meta.cost <= clicks then
                if meta.cost >= bestCost then
                    bestCost = meta.cost
                    bestEggName = eggName
                end
            end
        end
    end

    if not bestEggName then
        bestEggName = "BasicEgg"
        bestCost = 250
    end

    return { name = bestEggName, cost = bestCost, island = eggData[bestEggName] and eggData[bestEggName].island or "Spawn" }
end

function ProgAPI.TeleportToEgg(eggName: string): boolean
    local eggMeta = eggData[eggName]
    if not eggMeta or not eggMeta.island then return false end

    ProgAPI.TeleportToIsland(eggMeta.island)
    task.wait(0.3)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local mapFolder = workspace:FindFirstChild("_MAP")
    local eggObj = mapFolder and mapFolder:FindFirstChild("Eggs") and mapFolder.Eggs:FindFirstChild(eggName)
    if not eggObj and workspace:FindFirstChild("Eggs") then
        eggObj = workspace.Eggs:FindFirstChild(eggName)
    end

    if eggObj then
        local targetPart = eggObj:FindFirstChildWhichIsA("BasePart") or eggObj.PrimaryPart
        if targetPart then
            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 5)
            return true
        end
    end

    return false
end

function ProgAPI.OpenEgg(eggName: string, amount: number?, skipTeleport: boolean?): (boolean, string)
    amount = amount or 1
    if not Channels.Egg then return false, "No Egg channel" end

    if not skipTeleport then
        local eggMeta = eggData[eggName]
        if eggMeta and eggMeta.island then
            local stats = Stats.Local(true) or {}
            if stats.CurrentIsland ~= eggMeta.island then
                ProgAPI.TeleportToEgg(eggName)
                task.wait(0.35)
            end
        end
    end

    local stats = Stats.Local(true) or {}
    local curInv = 0
    for _ in pairs(stats.Pets or {}) do curInv = curInv + 1 end
    local maxInv = stats.MaxInventoryPets or 150
    if curInv >= maxInv - 5 then
        ProgAPI.CleanWeakPets(true)
        task.wait(0.2)
    end

    local guid = HttpService:GenerateGUID(false)
    local ok, res = pcall(function()
        return Channels.Egg:InvokeServer("Open", eggName, amount, guid)
    end)

    if not ok or res == false then
        pcall(function()
            ok, res = pcall(function() return Channels.Egg:InvokeServer("Open", eggName, amount) end)
        end)
    end

    if ok and (res == true or type(res) == "table") then
        return true, "Successfully opened " .. eggName
    end

    return false, "Failed to open egg: " .. tostring(res)
end

function ProgAPI.EquipBest()
    if Channels.Pets then
        pcall(function() Channels.Pets:InvokeServer("EquipBest") end)
    end
end

function ProgAPI.UnequipAll()
    if Channels.Pets then
        pcall(function() Channels.Pets:InvokeServer("UnequipAll") end)
    end
end

-- Converts batches of duplicate normal pets into Golden pets with 100% Guaranteed Chance Priority
function ProgAPI.CraftGoldenPets(): number
    if not Channels.Pets then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local reduction = 0
    pcall(function()
        if MasteryFrontend and MasteryFrontend.GetPower then
            reduction = MasteryFrontend.GetPower(stats, "GoldenCraftPetReduction") or 0
        end
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
                task.wait(0.15)
            else
                break
            end
        end
    end
    return craftedCount
end

-- Converts batches of duplicate Golden pets into Rainbow pets
function ProgAPI.CraftRainbowPets(): number
    if not Channels.Pets and not Channels.Crafting then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local groups = {}
    for guid, p in pairs(pets) do
        local isEquipped = equipped[guid] ~= nil
        local isLocked = p.Locked == true or p.l == true
        local isGolden = (p.v == "Golden" or p.Variant == "Golden" or p.Gold == true or p.Type == "Golden")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        if not isEquipped and not isLocked and isGolden and not isExclusive then
            local key = tostring(p.id) .. "_" .. tostring(p.Shiny or p.s or false)
            groups[key] = groups[key] or { id = p.id, guids = {} }
            table.insert(groups[key].guids, guid)
        end
    end

    local craftedCount = 0
    for _, g in pairs(groups) do
        while #g.guids >= 5 do
            local batch = {}
            for i = 1, math.min(6, #g.guids) do
                table.insert(batch, table.remove(g.guids, 1))
            end
            local ok, res = pcall(function()
                if Channels.Pets then
                    return Channels.Pets:InvokeServer("StartRainbowCraft", batch)
                elseif Channels.Crafting then
                    return Channels.Crafting:InvokeServer("CraftRainbow", batch)
                end
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

function ProgAPI.ClaimRainbowPets(): number
    local claimedCount = 0
    local stats = Stats.Local(true) or {}
    local rainbowCrafts = stats.RainbowCrafts or stats.RainbowCraftQueue or {}

    if Channels.Pets then
        for slotIndex = 1, math.min(5, #rainbowCrafts) do
            local craft = rainbowCrafts[slotIndex]
            if craft and craft.EndTimestamp then
                local now = workspace:GetServerTimeNow()
                if (craft.EndTimestamp - now) <= 0 then
                    local ok, res = pcall(function()
                        return Channels.Pets:InvokeServer("ClaimRainbowCraft", slotIndex)
                    end)
                    if ok and res == true then
                        claimedCount = claimedCount + 1
                        task.wait(0.2)
                    end
                end
            end
        end
    end

    if Channels.Crafting and claimedCount == 0 then
        for queueId, slotData in pairs(rainbowCrafts) do
            if type(slotData) == "table" and slotData.Ready == true then
                local ok = pcall(function()
                    return Channels.Crafting:InvokeServer("ClaimRainbow", queueId)
                end)
                if ok then claimedCount = claimedCount + 1 end
            end
        end
    end

    return claimedCount
end


local petIslandIndexMap = nil
local function buildPetIslandMap()
    if petIslandIndexMap then return petIslandIndexMap end
    petIslandIndexMap = {}
    local eggMap = {}
    for eggName, eData in pairs(eggData) do
        local m = islandMetaLookup[eData.island]
        eggMap[eggName] = m and m.num or 1
    end

    if Directory.Eggs then
        for eggName, eggObj in pairs(Directory.Eggs) do
            local worldNum = eggMap[eggName] or 1
            if eggObj.Pets then
                for _, petEntry in ipairs(eggObj.Pets) do
                    local pid = petEntry.Value or petEntry.Id
                    if pid and not petIslandIndexMap[pid] then
                        petIslandIndexMap[pid] = worldNum
                    end
                end
            end
        end
    end
    return petIslandIndexMap
end

-- Weak pet deletion: If highest unlocked island is N, delete all normal pets from world (N - 2) and below
function ProgAPI.CleanWeakPets(protectCrafting: boolean?): number
    if protectCrafting == nil then protectCrafting = true end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local furthestIsland = ProgAPI.GetFurthestUnlockedIsland()
    local meta = islandMetaLookup[furthestIsland]
    local highestWorldIndex = meta and meta.num or 1
    local deleteThreshold = highestWorldIndex - 2

    local petMap = buildPetIslandMap()
    local bestEgg = ProgAPI.GetBestAffordableEgg()
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
        if not equipped[guid] and not p.Locked and not p.l then
            local isSpecial = (p.rarity == "Secret" or p.rarity == "Divine" or p.rarity == "Mega" or p.rarity == "Exclusive")
            local isShiny = (p.Shiny or p.s or false)
            local isVariant = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")

            if not isSpecial and not isShiny and not isVariant then
                local petOriginWorld = petMap[p.id] or 1
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
function ProgAPI.BuyAffordableGemUpgrades(): number
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

function ProgAPI.BuyNextRebirthButton(): boolean
    local stats = Stats.Local(true) or {}
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
            if islandOk then
                local ok, res = pcall(function()
                    return Channels.RebirthShop:InvokeServer("BuyRebirthButton", idx)
                end)
                if ok and res == true then
                    boughtAny = true
                    ownedMap[idx] = true
                    task.wait(0.08)
                else
                    -- Server denied purchase (insufficient gems or prerequisites not met)
                    break
                end
            else
                -- Next required island is locked
                break
            end
        end
    end
    return boughtAny
end

function ProgAPI.BuyNextDoubleJump(): boolean
    local stats = Stats.Local(true) or {}
    local currentDJ = (stats.Upgrades and stats.Upgrades.DoubleJumps) or stats.DoubleJumps or 0
    local nextDJ = currentDJ + 1

    if Channels.RebirthShop then
        local ok, res = pcall(function()
            return Channels.RebirthShop:InvokeServer("BuyDoubleJumpUpgrade", nextDJ)
        end)
        return ok and res == true
    end
    return false
end


function ProgAPI.BuyAffordableMiniUpgrades(): number
    if not Channels.MiniUpgrades then return 0 end
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local bought = 0

    local islandNames = { "Spawn", "Winter", "Forest", "Desert", "Candy", "Beach", "Sakura", "Base", "Spaceship", "Volcano", "Rave", "Heaven", "Castle", "Mystical", "Hell", "Fragment", "Matrix" }

    for _, isl in ipairs(islandNames) do
        if ProgAPI.IsIslandUnlocked(isl) then
            local cost = 500000000
            pcall(function()
                if Directory.MiniUpgrades and Directory.MiniUpgrades[isl] then
                    cost = Directory.MiniUpgrades[isl].Cost or cost
                end
            end)
            local owned = stats.MiniUpgrades and stats.MiniUpgrades[isl]
            if not owned and gems >= cost then
                local ok, res = pcall(function()
                    return Channels.MiniUpgrades:InvokeServer("Buy", isl)
                end)
                if ok and res == true then
                    gems = gems - cost
                    bought = bought + 1
                    task.wait(0.08)
                end
            end
        end
    end
    return bought
end

--==============================================================================
-- SKILL TREE & BREAKABLES PIPELINE (Transferred from [CLICKER HUB])
-- Dynamic Priority: Coins First (Volcano <-> Heaven Switching) -> Tech World (Matrix)
--==============================================================================

-- Calculates completion progress for Tech World (SpaceCoins) vs Overworld (Coins) skill tree perks
function ProgAPI.GetSkillTreeProgress()
    local stFrontend = nil
    pcall(function()
        stFrontend = require(Client:WaitForChild("SkillTreeFrontend"))
    end)
    local stats = Stats.Local(true) or {}
    local d = Directory.SkillTree and Directory.SkillTree.Default or {}

    local techTotal = 0
    local techBought = 0
    local coinsTotal = 0
    local coinsBought = 0

    local SkillTreeUtil = nil
    pcall(function()
        SkillTreeUtil = require(Library:WaitForChild("Utils"):WaitForChild("SkillTreeUtil"))
    end)

    for catName, catData in pairs(d) do
        if type(catData) == "table" and catData.Upgrades then
            for upgName, upgData in pairs(catData.Upgrades) do
                local p = upgData.Price
                local curr = p and p.Id or "Coins"
                local isTech = (curr == "SpaceCoins")
                    or (upgData.Requires and upgData.Requires.World == "Techworld")
                    or (catData.Requires and catData.Requires.World == "Techworld")

                local saveKey = upgName
                if SkillTreeUtil and SkillTreeUtil.GetSaveKey then
                    saveKey = SkillTreeUtil.GetSaveKey(upgName, "Default")
                end

                local owned = stats.SkillTree and (stats.SkillTree[saveKey] == true or stats.SkillTree[upgName] == true)
                if not owned and stFrontend and stFrontend.OwnsUpgrade then
                    owned = stFrontend.OwnsUpgrade(upgName, "Default")
                end

                if isTech then
                    techTotal = techTotal + 1
                    if owned then techBought = techBought + 1 end
                else
                    coinsTotal = coinsTotal + 1
                    if owned then coinsBought = coinsBought + 1 end
                end
            end
        end
    end

    local techDone = (techTotal > 0 and techBought >= techTotal)
    local coinsDone = (coinsTotal > 0 and coinsBought >= coinsTotal)

    return {
        TechTotal = techTotal,
        TechBought = techBought,
        TechRemaining = math.max(0, techTotal - techBought),
        TechComplete = techDone,
        CoinsTotal = coinsTotal,
        CoinsBought = coinsBought,
        CoinsRemaining = math.max(0, coinsTotal - coinsBought),
        CoinsComplete = coinsDone,
        AllComplete = techDone and coinsDone,
        UserSkills = stats.SkillTree or {}
    }
end

local coinsSwitchTick = 0
local currentCoinsIsland = "Volcano"

function ProgAPI.ForceSwitchCoinsIsland(): string
    coinsSwitchTick = tick()
    currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
    return currentCoinsIsland
end

function ProgAPI.GetBestBreakableIsland(mode: string?): string?
    local pData = ProgAPI.GetPlayerData()
    local unlocked = pData.UnlockedIslands or { "Spawn" }
    local unlockedSet = {}
    for _, isl in ipairs(unlocked) do unlockedSet[isl] = true end

    -- Latest tech islands in descending order of progression (Matrix is the newest 17th world)
    local techIslands = { "Matrix", "Fragment", "Spaceship", "Base" }

    mode = mode or "Auto (Dynamic Smart)"

    if mode == "Coins World (Volcano/Heaven)" or mode == "Coins Only" then
        local now = tick()
        if now - coinsSwitchTick > 10 then
            coinsSwitchTick = now
            currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
        end
        if unlockedSet[currentCoinsIsland] and ProgAPI.HasBreakables(currentCoinsIsland) then
            return currentCoinsIsland
        end
        return unlockedSet["Heaven"] and "Heaven" or "Volcano"
    elseif mode == "Tech World (Matrix/Fragment)" or mode == "Tech Only" then
        for _, isl in ipairs(techIslands) do
            if unlockedSet[isl] and ProgAPI.HasBreakables(isl) then
                return isl
            end
        end
        return "Matrix"
    elseif mode == "Auto (Dynamic Smart)" or mode == "Best Unlocked" or mode == "" then
        local progress = ProgAPI.GetSkillTreeProgress()

        -- 1. PRIORITIZE COINS SKILL TREE FIRST!
        -- Alternate between Volcano and Heaven to break all breakables!
        if not progress.CoinsComplete then
            local now = tick()
            if now - coinsSwitchTick > 10 then
                coinsSwitchTick = now
                currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
            end
            if unlockedSet[currentCoinsIsland] and ProgAPI.HasBreakables(currentCoinsIsland) then
                return currentCoinsIsland
            end
            if unlockedSet["Heaven"] and ProgAPI.HasBreakables("Heaven") then return "Heaven" end
            if unlockedSet["Volcano"] and ProgAPI.HasBreakables("Volcano") then return "Volcano" end
        else
            -- 2. AFTER ALL COINS UPGRADES ARE DONE:
            -- Teleport to the LATEST unlocked Tech World island (Matrix > Fragment > Spaceship > Base) to farm Tech Coins!
            for _, isl in ipairs(techIslands) do
                if unlockedSet[isl] and ProgAPI.HasBreakables(isl) then
                    return isl
                end
            end
        end

        -- Fallback
        if unlockedSet["Matrix"] and ProgAPI.HasBreakables("Matrix") then return "Matrix" end
        if unlockedSet["Heaven"] and ProgAPI.HasBreakables("Heaven") then return "Heaven" end
        return "Volcano"
    elseif unlockedSet[mode] and ProgAPI.HasBreakables(mode) then
        return mode
    end

    if ProgAPI.HasBreakables(pData.CurrentIsland) then
        return pData.CurrentIsland
    end
    return "Heaven"
end

-- Target lock / focus fire cache
local currentTargetUID: string? = nil
local currentTargetModel: Model? = nil

-- Finds the breakable zone part and zone ID for an island
function ProgAPI.GetIslandBreakableZone(islandName: string?, ignoreBossChest: boolean?): (Instance?, string?)
    if ignoreBossChest == nil then ignoreBossChest = true end
    local pData = ProgAPI.GetPlayerData()
    islandName = islandName or pData.CurrentIsland
    local islands = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Islands")
    local isl = islands and islands:FindFirstChild(islandName)
    local interact = isl and isl:FindFirstChild("Interact")
    local bZones = interact and interact:FindFirstChild("BreakableZones")
    if bZones then
        local normalZone = bZones:FindFirstChild("1")
        if normalZone and normalZone:IsA("BasePart") then
            return normalZone, islandName .. "/1"
        end
        for _, child in ipairs(bZones:GetChildren()) do
            if child:IsA("BasePart") then
                local cName = child.Name:lower()
                if not (ignoreBossChest and (cName:find("huge") or cName:find("boss") or cName:find("giant") or cName:find("chest"))) then
                    return child, islandName .. "/" .. child.Name
                end
            end
        end
        local part = bZones:FindFirstChildWhichIsA("BasePart")
        if part then
            return part, islandName .. "/" .. part.Name
        end
    end

    -- Check _THINGS._BreakableZones
    local thingsBZones = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("_BreakableZones")
    if thingsBZones then
        local targetZoneName = (islandName .. "/1"):lower()
        for _, z in ipairs(thingsBZones:GetChildren()) do
            if z.Name:lower() == targetZoneName then
                return z, z.Name
            end
        end
        for _, z in ipairs(thingsBZones:GetChildren()) do
            local zName = z.Name:lower()
            if zName:find(islandName:lower()) then
                if not (ignoreBossChest and (zName:find("huge") or zName:find("boss") or zName:find("giant") or zName:find("chest"))) then
                    return z, z.Name
                end
            end
        end
    end

    return nil, nil
end

function ProgAPI.GetBreakableZonePosition(islandName: string): Vector3?
    local part = ProgAPI.GetIslandBreakableZone(islandName, true)
    if part and part:IsA("BasePart") then
        return part.Position
    end
    local fallbacks = {
        Volcano = Vector3.new(-228.66, 9667.0, 327.77),
        Heaven = Vector3.new(-153.86, 12668.5, 360.0),
        Matrix = Vector3.new(-120.0, 5000.0, 200.0),
    }
    return fallbacks[islandName]
end

-- Checks if the island has breakables
function ProgAPI.HasBreakables(islandName: string?): boolean
    local pData = ProgAPI.GetPlayerData()
    islandName = islandName or pData.CurrentIsland
    if Directory and Directory.Islands and Directory.Islands[islandName] then
        if Directory.Islands[islandName].Breakables ~= nil then
            return true
        end
    end
    local zonePart = ProgAPI.GetIslandBreakableZone(islandName, true)
    return zonePart ~= nil
end

-- Stop attacking and cleanly detach from breakables zone so normal player clicking works seamlessly
function ProgAPI.StopBreakables()
    currentTargetModel = nil
    currentTargetUID = nil
    if BreakablesFrontend then
        pcall(function()
            BreakablesFrontend.SetExternalTarget(nil)
            BreakablesFrontend.LeaveZone()
        end)
    end
end

-- Checks if a breakable model is considered a giant / boss chest
function ProgAPI.IsBossChest(modelOrId: any): boolean
    local str = ""
    local maxHP = 0
    if typeof(modelOrId) == "Instance" then
        local bId = modelOrId:GetAttribute("BreakableId") or modelOrId.Name
        str = tostring(bId):lower()
        local zone = modelOrId:GetAttribute("BreakableZone")
        if zone then str = str .. " " .. tostring(zone):lower() end
        local mhp = modelOrId:GetAttribute("BreakableMaxHP") or modelOrId:GetAttribute("BreakableHP")
        if type(mhp) == "number" then maxHP = mhp end
    elseif type(modelOrId) == "string" then
        str = modelOrId:lower()
    end
    return str:find("boss") ~= nil 
        or str:find("giant") ~= nil 
        or str:find("huge") ~= nil 
        or str:find("grand") ~= nil
        or maxHP > 40000000
end

local function resolveBreakableEntry(child)
    if not child then return nil end
    local uid = child:GetAttribute("BreakableUID") or (child.Name:find("%-") and child.Name) or child.Name
    local m = child:FindFirstChildWhichIsA("Model") or (child:IsA("Model") and child) or child:FindFirstChildWhichIsA("BasePart") or child
    local pivot = nil
    if m:IsA("Model") then
        pivot = m:GetPivot()
    elseif m:IsA("BasePart") then
        pivot = m.CFrame
    elseif child:IsA("BasePart") then
        pivot = child.CFrame
    end
    if not pivot then return nil end
    local hp = m:GetAttribute("BreakableHP") or child:GetAttribute("BreakableHP") or 1
    local isBoss = ProgAPI.IsBossChest(m) or ProgAPI.IsBossChest(child) or ProgAPI.IsBossChest(uid)
    local zone = m:GetAttribute("BreakableZone") or child:GetAttribute("BreakableZone")
    return {
        uid = tostring(uid),
        model = m,
        pivot = pivot,
        pos = pivot.Position,
        hp = tonumber(hp) or 1,
        isBoss = isBoss,
        zone = zone
    }
end

-- Teleports character directly to the active breakable box itself or zone center
function ProgAPI.TeleportToBreakableZone(islandName: string?, ignoreBossChest: boolean?): boolean
    if ignoreBossChest == nil then ignoreBossChest = true end
    local zonePart, zoneId = ProgAPI.GetIslandBreakableZone(islandName, ignoreBossChest)
    if not zonePart then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if BreakablesFrontend and zoneId then
        pcall(function()
            BreakablesFrontend.EnterZone(zoneId)
        end)
    end

    local bestEntry = nil
    local bestDist = math.huge
    local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    if breakablesFolder then
        for _, f in ipairs(breakablesFolder:GetChildren()) do
            local entry = resolveBreakableEntry(f)
            if entry and entry.hp > 0 and not (ignoreBossChest and entry.isBoss) then
                local dist = (entry.pos - zonePart.Position).Magnitude
                if dist < 120 and dist < bestDist then
                    bestDist = dist
                    bestEntry = entry
                end
            end
        end
    end

    if bestEntry then
        hrp.CFrame = CFrame.lookAt(bestEntry.pos + Vector3.new(0, 1.5, 3), bestEntry.pos)
        return true
    else
        hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        return true
    end
end

-- Attacks active breakable in the zone with 100% reliability (Focus Fire + Direct Server Remotes + Frontend Visuals + Player Tapping)
function ProgAPI.AttackBreakable(ignoreBossChest: boolean?, islandName: string?): (boolean, string?, number?)
    if ignoreBossChest == nil then ignoreBossChest = true end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character", nil end

    local pData = ProgAPI.GetPlayerData()
    islandName = islandName or pData.CurrentIsland
    local zonePart, zoneId = ProgAPI.GetIslandBreakableZone(islandName, ignoreBossChest)
    if not zonePart then return false, "No breakables on island", nil end

    if BreakablesFrontend and zoneId then
        pcall(function() BreakablesFrontend.EnterZone(zoneId) end)
    end

    -- Validate existing target lock (Focus Fire)
    local targetModel = currentTargetModel
    local targetUID = currentTargetUID

    if targetModel and targetModel.Parent and targetUID then
        local hp = targetModel:GetAttribute("BreakableHP") or (targetModel.Parent and targetModel.Parent:GetAttribute("BreakableHP"))
        local isBoss = ProgAPI.IsBossChest(targetModel)
        if (hp and hp <= 0) or (ignoreBossChest and isBoss) then
            targetModel = nil
            targetUID = nil
            currentTargetModel = nil
            currentTargetUID = nil
            if BreakablesFrontend then
                pcall(function() BreakablesFrontend.SetExternalTarget(nil) end)
            end
        end
    else
        targetModel = nil
        targetUID = nil
        currentTargetModel = nil
        currentTargetUID = nil
    end

    -- If no valid locked target, select best candidate in zone
    if not targetModel then
        local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
        local candidates = {}

        if breakablesFolder then
            for _, f in ipairs(breakablesFolder:GetChildren()) do
                local entry = resolveBreakableEntry(f)
                if entry and entry.hp > 0 and not (ignoreBossChest and entry.isBoss) then
                    local distToZone = (entry.pos - zonePart.Position).Magnitude
                    local distToPlayer = (entry.pos - hrp.Position).Magnitude
                    if distToZone < 140 or distToPlayer < 45 then
                        table.insert(candidates, { entry = entry, dist = distToPlayer })
                    end
                end
            end
        end

        if #candidates > 0 then
            table.sort(candidates, function(a, b) return a.dist < b.dist end)
            targetModel = candidates[1].entry.model
            targetUID = candidates[1].entry.uid
            currentTargetModel = targetModel
            currentTargetUID = targetUID
        end
    end

    if not targetModel or not targetUID then
        if zonePart and (hrp.Position - zonePart.Position).Magnitude > 30 then
            hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        end
        return false, "Waiting for breakables respawn", nil
    end

    -- Face target and maintain close proximity
    local pivot = (targetModel:IsA("Model") and targetModel:GetPivot()) or (targetModel:IsA("BasePart") and targetModel.CFrame) or hrp.CFrame
    local dist = (hrp.Position - pivot.Position).Magnitude
    if dist > 8 then
        hrp.CFrame = CFrame.lookAt(pivot.Position + Vector3.new(0, 1.5, 3), pivot.Position)
    else
        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(pivot.Position.X, hrp.Position.Y, pivot.Position.Z))
    end

    -- Optimized Attack Execution (BreakablesFrontend + Pet Strikes)
    local dmg = nil
    local zone = targetModel:GetAttribute("BreakableZone") or (targetModel.Parent and targetModel.Parent:GetAttribute("BreakableZone")) or zoneId
    if BreakablesFrontend then
        pcall(function()
            if zone then
                BreakablesFrontend.EnterZone(zone)
            end
            dmg = BreakablesFrontend.ReportClick(targetModel)

            local stats = Stats.Local(true) or {}
            local equipped = stats.EquippedPets or {}
            for guid, _ in pairs(equipped) do
                BreakablesFrontend.ReportStrike(guid)
            end
        end)
    end

    -- Direct Server Click & Pet Hits (Guaranteed Server Execution + Player Tapping Damage)
    if Channels.Breakables and targetUID then
        pcall(function()
            Channels.Breakables:InvokeServer("Click", targetUID)
        end)
        local stats = Stats.Local(true) or {}
        local equipped = stats.EquippedPets or {}
        for guid, _ in pairs(equipped) do
            pcall(function()
                Channels.Breakables:InvokeServer("Hit", targetUID, guid)
            end)
        end
    end

    -- Fire player core click alongside breakable attack for clicks multiplier
    ProgAPI.Click()

    return true, targetModel.Name, dmg
end

function ProgAPI.AttackBreakablesInZone(targetIsland: string, ignoreBossChest: boolean?): (boolean, string?)
    local ok, name = ProgAPI.AttackBreakable(ignoreBossChest, targetIsland)
    return ok, name
end

function ProgAPI.GetActiveBreakablesCount(islandName: string, zoneName: string?): number
    local bf = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    if not bf then return 0 end
    local count = 0
    for _, child in ipairs(bf:GetChildren()) do
        local entry = resolveBreakableEntry(child)
        if entry and entry.hp > 0 and not entry.isBoss then
            count = count + 1
        end
    end
    return count
end


-- Purchases any affordable and unlocked Skill Tree perks (Default & RNG trees), prioritizing Coins when preferCoins is true
function ProgAPI.BuyAffordableSkillTree(preferCoins: boolean?): number
    local stFrontend = nil
    pcall(function()
        stFrontend = require(Client:WaitForChild("SkillTreeFrontend"))
    end)
    if not Directory.SkillTree or not Channels.SkillTree then return 0 end

    if preferCoins == nil then
        local stProg = ProgAPI.GetSkillTreeProgress()
        preferCoins = not stProg.CoinsComplete
    end

    local count = 0
    local boughtAny = true

    -- Loop to continuously purchase chained perks if previous purchase unlocks next perk
    while boughtAny and count < 30 do
        boughtAny = false
        local stats = Stats.Local(true) or {}
        local curr = stats.Currency or {}

        for treeId, categories in pairs(Directory.SkillTree) do
            if type(categories) == "table" then
                for catId, catData in pairs(categories) do
                    -- Check category price if required
                    if catData.Price and stFrontend and not stFrontend.OwnsCategory(catId, treeId) then
                        local p = catData.Price
                        local isCoins = (p.Id == "Coins")
                        local canBuyCat = (not preferCoins or isCoins)
                        if canBuyCat and p and curr[p.Id] and curr[p.Id] >= p.Amount then
                            local ok = false
                            pcall(function()
                                ok = Channels.SkillTree:InvokeServer("PurchaseCategory", catId, treeId)
                            end)
                            if ok == true then
                                count = count + 1
                                boughtAny = true
                                curr[p.Id] = curr[p.Id] - p.Amount
                                task.wait(0.1)
                            end
                        end
                    end

                    local upgrades = (type(catData) == "table" and catData.Upgrades)
                    if type(upgrades) == "table" then
                        for skillId, skillData in pairs(upgrades) do
                            local p = skillData.Price
                            local isCoins = (p and p.Id == "Coins")
                            local canBuyThis = (not preferCoins or isCoins)

                            if canBuyThis then
                                local alreadyOwned = false
                                if stFrontend then
                                    alreadyOwned = stFrontend.Owns(skillId, treeId)
                                else
                                    local saveKey = skillId
                                    local util = nil
                                    pcall(function() util = require(Library:WaitForChild("Utils"):WaitForChild("SkillTreeUtil")) end)
                                    if util and util.GetSaveKey then
                                        saveKey = util.GetSaveKey(skillId, treeId)
                                    end
                                    alreadyOwned = stats.SkillTree and stats.SkillTree[saveKey] == true
                                end

                                if not alreadyOwned then
                                    local reqFail = nil
                                    if stFrontend then
                                        reqFail = stFrontend.GetRequirementFailure(skillData, treeId)
                                    end

                                    if not reqFail then
                                        if p and curr[p.Id] and curr[p.Id] >= p.Amount then
                                            local ok = false
                                            pcall(function()
                                                ok = Channels.SkillTree:InvokeServer("Purchase", skillId, treeId)
                                            end)
                                            if ok == true then
                                                count = count + 1
                                                boughtAny = true
                                                curr[p.Id] = curr[p.Id] - p.Amount
                                                task.wait(0.1)
                                                break -- refresh and re-evaluate next tier perks
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return count
end

-- Executes the exact dynamic Skill Tree & Breakables loop transferred from [CLICKER HUB]
function ProgAPI.StepBreakablesPipeline(): (string, string)
    local stProg = ProgAPI.GetSkillTreeProgress()
    local targetWorld = ProgAPI.GetBestBreakableIsland("Auto (Dynamic Smart)") or "Heaven"
    local pData = ProgAPI.GetPlayerData()

    -- Asynchronously purchase affordable perks (Coins prioritized first!)
    task.spawn(function()
        pcall(function()
            ProgAPI.BuyAffordableSkillTree(not stProg.CoinsComplete)
        end)
    end)

    -- If player is not on the target breakables island, warp there
    if targetWorld and targetWorld ~= pData.CurrentIsland then
        ProgAPI.TeleportToIsland(targetWorld)
        task.wait(0.35)
        ProgAPI.TeleportToBreakableZone(targetWorld, true)
        task.wait(0.15)
    end

    -- Keep character anchored inside breakables zone
    local zonePart = ProgAPI.GetIslandBreakableZone(targetWorld, true)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and zonePart and (hrp.Position - zonePart.Position).Magnitude > 35 then
        ProgAPI.TeleportToBreakableZone(targetWorld, true)
    end

    -- Attack breakable
    local okAtk = false
    local targetName, dmg = nil, nil
    pcall(function()
        okAtk, targetName, dmg = ProgAPI.AttackBreakable(true, targetWorld)
    end)

    -- If no breakables on current Coins island, switch immediately between Volcano and Heaven so it never stops!
    if not okAtk and not stProg.CoinsComplete then
        local altIsland = ProgAPI.ForceSwitchCoinsIsland()
        if altIsland and altIsland ~= pData.CurrentIsland then
            ProgAPI.TeleportToIsland(altIsland)
            task.wait(0.35)
            ProgAPI.TeleportToBreakableZone(altIsland, true)
            targetWorld = altIsland
        end
        return "Switching to " .. tostring(altIsland), tostring(altIsland)
    end

    if okAtk then
        return "Attacking " .. tostring(targetName or "Breakable"), targetWorld
    else
        return tostring(targetName or "Waiting for breakables respawn"), targetWorld
    end
end

--==============================================================================
-- MILESTONES & REWARDS AUTOMATION
--==============================================================================
function ProgAPI.ClaimAllMilestones(): (number, number)
    local achClaimed = 0
    local roadClaimed = 0

    -- 1. Achievements Milestones
    if AchievementsFrontend and Channels.Achievements then
        local list = AchievementsFrontend.GetOrderedAchievements and AchievementsFrontend.GetOrderedAchievements() or {}
        for _, item in ipairs(list) do
            local id = item.Id
            if id and AchievementsFrontend.IsClaimable(id) then
                pcall(function()
                    Channels.Achievements:FireServer("Claim", id)
                end)
                achClaimed = achClaimed + 1
            end
        end
    end

    -- 2. Summer Road Milestones
    local raw = Stats.Local(true) or {}
    local shells = raw.Currency and raw.Currency.Shells or 0
    local claimed = (raw.SummerRewardsRoad and raw.SummerRewardsRoad.Claimed) or {}
    local road = Directory.SummerRewardsRoad or {}
    local summerChannel = Channels.SummerEvent2026

    if summerChannel and shells > 0 then
        for idx = 1, #road do
            local entry = road[idx]
            if not entry then break end
            local isClaimed = claimed[tostring(idx)] or claimed[idx]
            if not isClaimed then
                local price = entry.Price or 0
                if shells >= price then
                    local ok, res = pcall(function()
                        return summerChannel:InvokeServer("ClaimRoadReward", idx)
                    end)
                    if ok and res then
                        roadClaimed = roadClaimed + 1
                        shells = shells - price
                        task.wait(0.12)
                    else
                        break
                    end
                else
                    break
                end
            end
        end
    end

    -- 3. Secondary Milestones & Retention / Leaving
    pcall(function()
        if Channels.RetentionGift then Channels.RetentionGift:FireServer("Claim") end
        if Channels.LeavingGift then Channels.LeavingGift:FireServer("Claim") end
        if Channels.LikesGoal then Channels.LikesGoal:FireServer("Claim") end
    end)

    return achClaimed, roadClaimed
end

-- Consumables: Potions & Fruits
function ProgAPI.UseAllBestPotions(): number
    if not Channels.Potions or not Directory.Items then return 0 end
    local stats = Stats.Local(true) or {}
    local inventory = stats.Inventory or stats.Items or {}
    local usedCount = 0

    for itemId, data in pairs(inventory) do
        local amount = type(data) == "table" and (data.Amount or data.Count or 1) or tonumber(data) or 0
        local itemMeta = Directory.Items[itemId]
        if itemMeta and itemMeta.Category == "Potion" and amount > 0 then
            local activeBuffs = stats.Buffs or {}
            local isBuffActive = activeBuffs[itemId] ~= nil
            if not isBuffActive then
                local ok = pcall(function()
                    return Channels.Potions:InvokeServer("Consume", itemId, 1)
                end)
                if ok then
                    usedCount = usedCount + 1
                    task.wait(0.05)
                end
            end
        end
    end
    return usedCount
end

function ProgAPI.UseAllFruits(): number
    if not Channels.Fruits or not Directory.Items then return 0 end
    local stats = Stats.Local(true) or {}
    local inventory = stats.Inventory or stats.Items or {}
    local usedCount = 0

    for itemId, data in pairs(inventory) do
        local amount = type(data) == "table" and (data.Amount or data.Count or 1) or tonumber(data) or 0
        local itemMeta = Directory.Items[itemId]
        if itemMeta and itemMeta.Category == "Fruit" and amount > 0 then
            local ok = pcall(function()
                return Channels.Fruits:InvokeServer("Consume", itemId, math.min(amount, 5))
            end)
            if ok then
                usedCount = usedCount + 1
                task.wait(0.05)
            end
        end
    end
    return usedCount
end

function ProgAPI.ClaimAllFreeGifts(): number
    if not Channels.FreeGifts then return 0 end
    local stats = Stats.Local(true) or {}
    local gifts = stats.FreeGifts or {}
    local claimed = 0

    for i = 1, 12 do
        if not gifts[i] and not gifts[tostring(i)] then
            local ok, res = pcall(function()
                return Channels.FreeGifts:InvokeServer("Claim", i)
            end)
            if ok and res == true then
                claimed = claimed + 1
                task.wait(0.08)
            end
        end
    end
    return claimed
end

function ProgAPI.ClaimAllChests(): number
    local claimed = 0
    if Channels.BeachChest then
        local ok = pcall(function() return Channels.BeachChest:InvokeServer("Claim") end)
        if ok then claimed = claimed + 1 end
    end
    return claimed
end

function ProgAPI.ClaimDaily(): boolean
    if not Channels.DailyRewards then return false end
    local ok, res = pcall(function() return Channels.DailyRewards:InvokeServer("Claim") end)
    return ok and res == true
end

function ProgAPI.ClaimAllAchievements(): number
    local ach, _ = ProgAPI.ClaimAllMilestones()
    return ach
end

function ProgAPI.RedeemAllCodes(): number
    if not Channels.Codes or not Directory.Codes then return 0 end
    local redeemed = 0
    for codeName, _ in pairs(Directory.Codes) do
        pcall(function()
            if Channels.Codes:InvokeServer("Redeem", codeName) == true then
                redeemed = redeemed + 1
                task.wait(0.1)
            end
        end)
    end
    return redeemed
end

--==============================================================================
-- 10 QI REBIRTH GOAL & MAGMA CLICK SKIN
--==============================================================================
function ProgAPI.CheckAndEquipMagmaSkin(): (boolean, string)
    local stats = Stats.Local(true) or {}
    local curRebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or (stats.Currency and stats.Currency.Rebirths) or 0
    local target = 1e19 -- 10 Qi Rebirths

    if curRebirths < target then
        return false, string.format("Progress: %s / 10 Qi (%d%%)", ProgAPI.FormatNumber(curRebirths), math.floor((curRebirths / target) * 100))
    end

    local skinCh = Network.Channel("ClickSkins")
    if not skinCh then return false, "ClickSkins channel unavailable" end

    local skins = stats.ClickSkins or {}
    local ownsMagma = skins["Magma"] == true or skins.Magma == true

    if not ownsMagma then
        pcall(function() skinCh:InvokeServer("Unlock", "Magma") end)
        task.wait(0.2)
    end

    if stats.EquippedClickSkin ~= "Magma" then
        local ok, res = pcall(function()
            return skinCh:InvokeServer("Equip", "Magma")
        end)
        if ok and res == true then
            return true, "Magma Click Skin Equipped! (+4 Egg Hatch, +20% Speed active)"
        end
    else
        return true, "Magma Click Skin is Active."
    end

    return false, "Failed to equip Magma Click Skin"
end

--==============================================================================
-- SECRET ??? QUESTLINE
--==============================================================================
function ProgAPI.GetSecretQuestProgress()
    local stats = Stats.Local(true) or {}
    local collected = stats.SecretAreaCollectedFeathers or {}
    local count = 0
    for _ in pairs(collected) do count = count + 1 end
    return {
        FeathersCollected = count,
        DoorUnlocked = stats.SecretAreaDoorUnlocked == true,
        QuestClaimed = stats.SecretAreaQuestClaimed == true,
    }
end

function ProgAPI.StepSecretQuest(): (boolean, string)
    local qProg = ProgAPI.GetSecretQuestProgress()
    if qProg.QuestClaimed then return true, "Already Completed & Claimed" end

    local secretCh = Network.Channel("SecretArea")
    if not secretCh then return false, "No SecretArea channel" end

    if qProg.FeathersCollected < 5 then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local mapFeathers = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Feathers")
        if mapFeathers and hrp then
            for idx, fObj in ipairs(mapFeathers:GetChildren()) do
                local p = fObj:FindFirstChildWhichIsA("BasePart") or fObj
                if p and p:IsA("BasePart") then
                    hrp.CFrame = p.CFrame + Vector3.new(0, 1, 0)
                    pcall(function() secretCh:InvokeServer("CollectFeather", idx) end)
                    task.wait(0.3)
                end
            end
        end
        return false, string.format("Collecting Feathers (%d/5)", qProg.FeathersCollected)
    end

    if not qProg.DoorUnlocked then
        local ok, res = pcall(function() return secretCh:InvokeServer("UnlockDoor") end)
        if ok and res == true then
            return true, "Door Unlocked!"
        end
    end

    local okClaim = pcall(function() return secretCh:InvokeServer("ClaimReward") end)
    if okClaim then return true, "Claimed Secret Quest Reward!" end

    return false, "In progress"
end

return ProgAPI
