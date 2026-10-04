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

-- Suppress game black shade permanently
function ProgAPI.SuppressBlackShade()
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
    local meta = islandMetaLookup[islandName]
    if not meta then return false end

    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
    if clicks < meta.cost then return false end

    -- Try BuyIsland remote
    if Channels.Islands then
        local ok, res = pcall(function()
            return Channels.Islands:InvokeServer("BuyIsland", islandName)
        end)
        if ok and res == true then return true end
    end

    if Channels.Portals then
        local ok, res = pcall(function()
            return Channels.Portals:InvokeServer("UnlockIsland", islandName)
        end)
        if ok and res == true then return true end
    end

    return false
end

function ProgAPI.UnlockAllAffordableIslands(): (number, string?)
    local unlockedCount = 0
    local lastUnlocked = nil

    while true do
        local nextIsl = ProgAPI.GetNextLockedIsland()
        if not nextIsl then break end

        local stats = Stats.Local(true) or {}
        local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
        if clicks < nextIsl.cost then break end

        local ok = ProgAPI.UnlockIsland(nextIsl.name)
        if ok then
            unlockedCount = unlockedCount + 1
            lastUnlocked = nextIsl.name
            task.wait(0.3)
            ProgAPI.TeleportToIsland(nextIsl.name)
            task.wait(0.2)
        else
            break
        end
    end

    return unlockedCount, lastUnlocked
end

--==============================================================================
-- PETS, EGG HATCHING & GOLDEN CRAFTING
--==============================================================================
local eggData = {
    BasicEgg = { cost = 10, island = "Spawn" },
    WinterEgg = { cost = 1000, island = "Winter" },
    ForestEgg = { cost = 25000, island = "Forest" },
    DesertEgg = { cost = 400000, island = "Desert" },
    CandyEgg = { cost = 6000000, island = "Candy" },
    BeachEgg = { cost = 100000000, island = "Beach" },
    SakuraEgg = { cost = 1.5e9, island = "Sakura" },
    BaseEgg = { cost = 2.5e10, island = "Base" },
    SpaceshipEgg = { cost = 4e11, island = "Spaceship" },
    VolcanoEgg = { cost = 6e12, island = "Volcano" },
    RaveEgg = { cost = 8e13, island = "Rave" },
    HeavenEgg = { cost = 1.2e15, island = "Heaven" },
    CastleEgg = { cost = 1.8e16, island = "Castle" },
    MysticalEgg = { cost = 2.5e17, island = "Mystical" },
    HellEgg = { cost = 4e18, island = "Hell" },
    FragmentedEgg = { cost = 6e19, island = "Fragment" },
    MatrixEgg = { cost = 1e21, island = "Matrix" },
    EventEgg = { cost = 10000000, island = "Spawn" },
}

-- Checks if entire equipped team is 100% Golden (or Rainbow)
function ProgAPI.IsEquippedTeamAllGold(): boolean
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local hasAny = false

    for guid, _ in pairs(equipped) do
        hasAny = true
        local pInfo = stats.Pets and stats.Pets[guid]
        if not pInfo then return false end
        -- In Clicker Simulator, pet variant is stored in pInfo.v
        local isGold = (pInfo.v == "Golden" or pInfo.Variant == "Golden" or pInfo.Gold == true or pInfo.Type == "Golden" or pInfo.v == "Rainbow" or pInfo.Variant == "Rainbow")
        if not isGold then
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

function ProgAPI.GetBestAffordableEgg()
    local furthest = ProgAPI.GetFurthestUnlockedIsland()
    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0

    local bestEggName = nil
    local bestCost = 0

    for eggName, meta in pairs(eggData) do
        if meta.cost <= clicks and ProgAPI.IsIslandUnlocked(meta.island) then
            if meta.cost >= bestCost then
                bestCost = meta.cost
                bestEggName = eggName
            end
        end
    end

    if not bestEggName then
        bestEggName = "BasicEgg"
        bestCost = 10
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
                task.wait(0.4)
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

    local ok, res = pcall(function()
        return Channels.Egg:InvokeServer("Open", eggName, amount)
    end)

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

function ProgAPI.ClaimRainbowPets(): number
    if not Channels.Crafting then return 0 end
    local stats = Stats.Local(true) or {}
    local claimed = 0
    local rawQueue = stats.RainbowCraftQueue or stats.RainbowCrafts or {}

    for queueId, slotData in pairs(rawQueue) do
        if type(slotData) == "table" and slotData.Ready == true then
            local ok = pcall(function()
                return Channels.Crafting:InvokeServer("ClaimRainbow", queueId)
            end)
            if ok then claimed = claimed + 1 end
        end
    end
    return claimed
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
-- SKILL TREE AUTOMATION (Coins First -> Tech Coins)
--==============================================================================
function ProgAPI.GetSkillTreeProgress()
    if not Directory.SkillTree then
        return { CoinsBought = 0, CoinsTotal = 0, CoinsComplete = false, TechBought = 0, TechTotal = 0, TechComplete = false }
    end

    local stats = Stats.Local(true) or {}
    local userSkills = stats.SkillTree or {}

    local coinsBought, coinsTotal = 0, 0
    local techBought, techTotal = 0, 0

    local skillTreeDefault = Directory.SkillTree.Default or {}
    for _, nodeData in pairs(skillTreeDefault) do
        if type(nodeData) == "table" and nodeData.Upgrades then
            for upgId, upgData in pairs(nodeData.Upgrades) do
                local price = upgData.Price
                if price and price.Id == "Coins" then
                    coinsTotal = coinsTotal + 1
                    if userSkills[upgId] == true then coinsBought = coinsBought + 1 end
                elseif price and (price.Id == "SpaceCoins" or price.Id == "TechCoins") then
                    techTotal = techTotal + 1
                    if userSkills[upgId] == true then techBought = techBought + 1 end
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

-- Purchases affordable perks using verified RPC: Channels.SkillTree:InvokeServer("Purchase", id, "Default")
-- Chained multi-tier loop continuously buys newly unlocked perks as long as currency is available
function ProgAPI.BuyAffordableSkillTree(preferCoins: boolean?): number
    if not Directory.SkillTree or not Channels.SkillTree then return 0 end
    local skillTreeDefault = Directory.SkillTree.Default
    if not skillTreeDefault then return 0 end

    local totalBought = 0
    local pData = ProgAPI.GetPlayerData()
    local coins = pData.Coins
    local spaceCoins = pData.SpaceCoins

    local stats = Stats.Local(true) or {}
    local userSkills = {}
    for k, v in pairs(stats.SkillTree or {}) do
        userSkills[k] = v
    end

    local keepSearching = true
    while keepSearching do
        keepSearching = false
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
                            elseif (curr == "SpaceCoins" or curr == "TechCoins") and spaceCoins >= cost then
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
            if (c.curr == "Coins" and coins >= c.cost) or ((c.curr == "SpaceCoins" or c.curr == "TechCoins") and spaceCoins >= c.cost) then
                local ok, res = pcall(function()
                    return Channels.SkillTree:InvokeServer("Purchase", c.id, "Default")
                end)
                if ok and (res == true or type(res) == "table") then
                    totalBought = totalBought + 1
                    userSkills[c.id] = true
                    if c.curr == "Coins" then coins = coins - c.cost end
                    if c.curr == "SpaceCoins" or c.curr == "TechCoins" then spaceCoins = spaceCoins - c.cost end
                    keepSearching = true
                    task.wait(0.08)
                end
            end
        end
    end

    return totalBought
end

--==============================================================================
-- BREAKABLES PIPELINE (Direct TP, Dual Damage: Player Click + Pet Strikes)
--==============================================================================
local activeCoinsIsland = "Heaven"
local lastBreakablesSwitchTick = 0

function ProgAPI.GetActiveBreakablesCount(islandName: string, zoneName: string?): number
    local bf = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    if not bf then return 0 end
    local count = 0
    for _, child in ipairs(bf:GetChildren()) do
        local m = child:FindFirstChildWhichIsA("Model") or child
        if m and m:GetAttribute("BreakableUID") then
            local z = tostring(m:GetAttribute("BreakableZone") or "")
            local bName = tostring(m:GetAttribute("BreakableId") or m.Name):lower()
            local isBoss = bName:find("giant") or bName:find("boss") or bName:find("huge")
            local hp = m:GetAttribute("BreakableHP") or 0
            if hp > 0 and (not isBoss) then
                if z:find(islandName) or z == "" then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Teleports character directly to breakable & executes simultaneous Player Click + Pet Strikes
-- Targets standard coins & tech breakables (skipping high-HP boss chests)
function ProgAPI.AttackBreakablesInZone(targetIsland: string, ignoreBossChest: boolean?): (boolean, string?)
    if ignoreBossChest == nil then ignoreBossChest = true end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end

    -- Verify player is on target island
    local stats = Stats.Local(true) or {}
    if stats.CurrentIsland ~= targetIsland then
        ProgAPI.TeleportToIsland(targetIsland)
        task.wait(0.4)
        return true, "Teleported to " .. targetIsland
    end

    -- Enter zone frontend
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
            local m = f:FindFirstChildWhichIsA("Model") or f
            if m and m:GetAttribute("BreakableUID") then
                local bZone = tostring(m:GetAttribute("BreakableZone") or "")
                local bName = tostring(m:GetAttribute("BreakableId") or m.Name):lower()
                local isBoss = bName:find("giant") or bName:find("boss") or bName:find("huge")

                if (not isBoss or not ignoreBossChest) and (bZone == "" or bZone:find(targetIsland)) then
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

    local uid = targetModel:GetAttribute("BreakableUID")
    local pivot = targetModel:GetPivot()
    local tPos = pivot.Position
    local eyePos = tPos + Vector3.new(0, 1.5, 3.2)

    -- 1. TELEPORT DIRECTLY NEXT TO THE TARGET BREAKABLE & AIM AT IT
    hrp.CFrame = CFrame.lookAt(eyePos, tPos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local cam = workspace.CurrentCamera
    if cam then
        cam.CFrame = CFrame.lookAt(eyePos + Vector3.new(0, 2.5, 3.5), tPos)
    end

    -- 2. ENTER ZONE & SET TARGET IN FRONTEND
    local zoneId = targetIsland .. "/1"
    if BreakablesFrontend then
        pcall(function()
            BreakablesFrontend.EnterZone(zoneId)
            BreakablesFrontend.SetExternalTarget(targetModel)
            BreakablesFrontend.ReportClick(targetModel)
        end)
    end

    -- 3. PLAYER RAPID SCREEN TAPPING VIA VIRTUAL INPUT MANAGER
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        if cam and vim then
            local sPos, onScreen = cam:WorldToViewportPoint(tPos)
            if onScreen and sPos.Z > 0 then
                for _ = 1, 4 do
                    vim:SendMouseButtonEvent(sPos.X, sPos.Y, 0, true, game, 0)
                    task.wait(0.015)
                    vim:SendMouseButtonEvent(sPos.X, sPos.Y, 0, false, game, 0)
                    task.wait(0.02)
                end
            end
        end
    end)

    -- 4. DIRECT SERVER CLICK RPC + CLICK POWER
    if Channels.Breakables and uid then
        pcall(function()
            Channels.Breakables:InvokeServer("Click", uid)
        end)
    end
    ProgAPI.Click()

    -- 5. PET STRIKES: ALL EQUIPPED PETS HIT SIMULTANEOUSLY
    local equipped = stats.EquippedPets or {}
    for guid, _ in pairs(equipped) do
        if Channels.Breakables and uid then
            pcall(function()
                Channels.Breakables:InvokeServer("Hit", uid, guid)
            end)
        end
        if BreakablesFrontend then
            pcall(function()
                BreakablesFrontend.ReportStrike(guid)
            end)
        end
    end

    local displayName = targetModel:GetAttribute("BreakableId") or targetModel.Name
    return true, displayName
end

-- Executes the full Coins (Volcano <-> Heaven) -> Tech World breakables state machine
function ProgAPI.StepBreakablesPipeline(): (string, string)
    local stProg = ProgAPI.GetSkillTreeProgress()
    local now = tick()

    -- Continuously attempt to buy affordable skill tree perks
    pcall(function() ProgAPI.BuyAffordableSkillTree(not stProg.CoinsComplete) end)

    -- 1. Coins Skill Tree NOT done: Farm Heaven and Volcano breakables!
    if not stProg.CoinsComplete then
        local stats = Stats.Local(true) or {}
        local curIsland = stats.CurrentIsland or "Spawn"
        local curWorld = stats.CurrentWorld or "Overworld"

        if curWorld ~= "Overworld" then
            ProgAPI.TeleportToWorld("Overworld")
            task.wait(0.5)
        end

        -- Ensure player is on activeCoinsIsland
        if curIsland ~= activeCoinsIsland then
            ProgAPI.TeleportToIsland(activeCoinsIsland)
            lastBreakablesSwitchTick = now
            task.wait(0.4)
            return "Teleported to " .. activeCoinsIsland, activeCoinsIsland
        end

        local activeOnCur = ProgAPI.GetActiveBreakablesCount(activeCoinsIsland, "1")
        -- Only switch if we've been here at least 8 seconds AND there are 0 breakables, OR 30 seconds have passed
        if (now - lastBreakablesSwitchTick > 8 and activeOnCur == 0) or (now - lastBreakablesSwitchTick > 30) then
            lastBreakablesSwitchTick = now
            activeCoinsIsland = (activeCoinsIsland == "Volcano") and "Heaven" or "Volcano"
            ProgAPI.TeleportToIsland(activeCoinsIsland)
            task.wait(0.4)
            return "Switched Coins Zone to " .. activeCoinsIsland, activeCoinsIsland
        end

        local attacked, targetName = ProgAPI.AttackBreakablesInZone(activeCoinsIsland, true)
        pcall(function() ProgAPI.BuyAffordableSkillTree(true) end)
        return "Attacking " .. tostring(targetName or "Breakables"), activeCoinsIsland

    -- 2. Coins skill tree complete: Teleport to latest Tech World (Matrix) to farm Tech Coins!
    else
        local stats = Stats.Local(true) or {}
        local curWorld = stats.CurrentWorld or "Overworld"

        if curWorld ~= "Techworld" then
            ProgAPI.TeleportToWorld("Techworld")
            task.wait(0.5)
        end

        local techTarget = ProgAPI.IsIslandUnlocked("Matrix") and "Matrix" or (ProgAPI.IsIslandUnlocked("Fragment") and "Fragment" or "Base")
        local curIsland = stats.CurrentIsland or ""
        if curIsland ~= techTarget then
            ProgAPI.TeleportToIsland(techTarget)
            task.wait(0.4)
            return "Teleported to " .. techTarget, techTarget
        end

        local attacked, targetName = ProgAPI.AttackBreakablesInZone(techTarget, true)
        pcall(function() ProgAPI.BuyAffordableSkillTree(false) end)
        return "Attacking " .. tostring(targetName or "Tech Breakables"), techTarget
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
