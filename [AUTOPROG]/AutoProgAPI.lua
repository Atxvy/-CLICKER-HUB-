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

local QuestFrontend = nil
pcall(function() QuestFrontend = require(Client:WaitForChild("QuestFrontend", 5)) end)

-- Channels
local Channels = {
    Click = Network.Channel("Click"),
    Rebirths = Network.Channel("Rebirths"),
    Egg = Network.Channel("Egg"),
    Pets = Network.Channel("Pets"),
    Portals = Network.Channel("Portals"),
    Islands = Network.Channel("Islands"),
    Items = Network.Channel("Items"),
    Milestones = Network.Channel("Milestones"),
    FreeGifts = Network.Channel("FreeGifts"),
    Achievements = Network.Channel("Achievements"),
    DailyRewards = Network.Channel("DailyRewards"),
    Codes = Network.Channel("Codes"),
    BeachChest = Network.Channel("BeachChest"),
    Upgrades = Network.Channel("Upgrades"),
    RebirthShop = Network.Channel("RebirthShop"),
    MiniUpgrades = Network.Channel("MiniUpgrades"),
    Crafting = Network.Channel("Crafting"),
    RNGUpgrades = Network.Channel("RNGUpgrades"),
    TradingPlazaTeleport = Network.Channel("TradingPlazaTeleport"),
    SkillTree = Network.Channel("SkillTree"),
    Quest = Network.Channel("Quest"),
    Quests = Network.Channel("Quest"),
    StarterPetAB = Network.Channel("StarterPetAB"),
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
ProgAPI.QuestFrontend = QuestFrontend
ProgAPI.AutoRebirthFrontend = AutoRebirthFrontend
ProgAPI.SkillTreeFrontend = SkillTreeFrontend
ProgAPI.BreakablesFrontend = BreakablesFrontend

-- Safe no-op to avoid interfering with game native UI modals and tabs
function ProgAPI.SuppressBlackShade()
    return true
end

-- Checks if player is new and auto-claims starter pet (Cat)
function ProgAPI.CheckAndSelectStarterPet(): boolean
    if not Channels.StarterPetAB then return false end
    local isNew = false
    local checkOk, checkRes = pcall(function()
        return Channels.StarterPetAB:InvokeServer("Check")
    end)
    if checkOk and checkRes == true then
        isNew = true
    end

    if isNew then
        local claimOk, claimRes = pcall(function()
            return Channels.StarterPetAB:InvokeServer("Claim", "Cat")
        end)
        if claimOk and claimRes == true then
            pcall(function()
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                local selectGui = pGui and pGui:FindFirstChild("SelectStarterPet")
                if selectGui then
                    selectGui.Enabled = false
                end
            end)
            task.wait(0.3)
            pcall(ProgAPI.EquipBest)
            return true
        end
    end
    return false
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
    if ProgAPI.IsRainbowMode and ProgAPI.IsRainbowMode() then
        return false, "Auto Rebirth disabled during Rainbow Mode to preserve clicks for egg hatching"
    end

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
    if ProgAPI.AreAllIslandsUnlocked and not ProgAPI.AreAllIslandsUnlocked() then
        return false, "Cannot Prestige yet: All 17 islands must be unlocked first!"
    end

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
-- World 1 (Overworld): Spawn -> Winter -> Forest -> Desert -> Candy -> Beach ->
--                      Sakura -> Volcano -> Rave -> Heaven -> Castle -> Mystical -> Hell (13)
-- World 2 (Techworld): Base -> Spaceship -> Fragment -> Matrix (14 to 17)
--==============================================================================
local ISLAND_SPEEDRUN_ROADMAP = {
    -- World 1: Overworld (1-13)
    { name = "Spawn",     world = "Overworld", cost = 0,             num = 1 },
    { name = "Winter",    world = "Overworld", cost = 1000,          num = 2 },
    { name = "Forest",    world = "Overworld", cost = 25000,         num = 3 },
    { name = "Desert",    world = "Overworld", cost = 400000,        num = 4 },
    { name = "Candy",     world = "Overworld", cost = 6000000,       num = 5 },
    { name = "Beach",     world = "Overworld", cost = 100000000,     num = 6 },
    { name = "Sakura",    world = "Overworld", cost = 1500000000,    num = 7 },
    { name = "Volcano",   world = "Overworld", cost = 25000000000,   num = 8 },
    { name = "Rave",      world = "Overworld", cost = 7.5e17,        num = 9 },
    { name = "Heaven",    world = "Overworld", cost = 2.5e19,        num = 10 },
    { name = "Castle",    world = "Overworld", cost = 2e20,          num = 11 },
    { name = "Mystical",  world = "Overworld", cost = 2.5e21,        num = 12 },
    { name = "Hell",      world = "Overworld", cost = 5e22,          num = 13 },
    -- World 2: Tech World (14-17)
    { name = "Base",      world = "Techworld", cost = 1.5e23,        num = 14 },
    { name = "Spaceship", world = "Techworld", cost = 7.5e23,        num = 15 },
    { name = "Fragment",  world = "Techworld", cost = 5e24,          num = 16 },
    { name = "Matrix",    world = "Techworld", cost = 2.5e25,        num = 17 },
}

local islandMetaLookup = {}
for idx, data in ipairs(ISLAND_SPEEDRUN_ROADMAP) do
    islandMetaLookup[data.name] = data
end

-- Dynamically incorporate any real-time Island meta from Directory.Islands
pcall(function()
    if Directory and Directory.Islands then
        for name, data in pairs(Directory.Islands) do
            if islandMetaLookup[name] then
                if data.Cost then islandMetaLookup[name].cost = data.Cost end
                if data.World then islandMetaLookup[name].world = data.World end
            end
        end
    end
end)

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
        if not ok or res ~= true then
            pcall(function() Channels.Portals:InvokeServer("Teleport", worldName) end)
        end
        return ok and res == true
    end
    return false
end

function ProgAPI.TeleportToIsland(islandName: string): boolean
    if islandName == "DominusArea" or islandName == "Dominus" then
        local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
        if MF and MF.Enter then
            pcall(function() MF.Enter("DominusArea") end)
            task.wait(0.35)
            return true
        end
    else
        local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
        if MF and MF.Active and MF.Active() == "DominusArea" then
            pcall(function() MF.Exit() end)
            task.wait(0.35)
        end
    end

    local meta = islandMetaLookup[islandName]
    local targetWorld = meta and meta.world or "Overworld"
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    -- 1. Switch world if targeting island in another world
    if targetWorld ~= curWorld and Channels.Portals then
        pcall(function()
            Channels.Portals:InvokeServer("TeleportToWorld", targetWorld)
        end)
        task.wait(0.5)
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

-- Checks if Hell is unlocked and navigates to the World 2 (Techworld) portal
function ProgAPI.CheckAndEnterTechWorld(): (boolean, string?)
    if not ProgAPI.IsIslandUnlocked("Hell") then return false, "Hell island not unlocked yet" end
    local stats = Stats.Local(true) or {}
    local prestiges = stats.Prestiges or 0
    if prestiges < 1 then
        return false, "You need 1 Prestige to enter Tech World!"
    end

    local curWorld = stats.CurrentWorld or "Overworld"
    if curWorld == "Techworld" or curWorld == "Space" then
        if not ProgAPI.IsIslandUnlocked("Base") then
            ProgAPI.UnlockIsland("Base")
        end
        return true, "Already in Tech World"
    end

    -- Navigate to TechPortal Hitbox in workspace._MAP.Interact.TechPortal
    local mapFolder = workspace:FindFirstChild("_MAP")
    local interact = mapFolder and mapFolder:FindFirstChild("Interact")
    local techPortal = interact and interact:FindFirstChild("TechPortal")
    local hitbox = techPortal and (techPortal:FindFirstChild("Hitbox") or techPortal:FindFirstChildWhichIsA("BasePart"))

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and hitbox then
        local savedCF = hrp.CFrame
        hrp.CFrame = hitbox.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.2)
        local ok, res, msg = pcall(function()
            return Channels.Portals:InvokeServer("EnterTechworld")
        end)
        task.wait(0.3)
        if ok and res == true then
            if not ProgAPI.IsIslandUnlocked("Base") then
                ProgAPI.UnlockIsland("Base")
            end
            return true, "Successfully entered Tech World!"
        end
    end

    -- Direct remote attempt
    if Channels.Portals then
        local ok, res, msg = pcall(function()
            return Channels.Portals:InvokeServer("EnterTechworld")
        end)
        if ok and res == true then
            if not ProgAPI.IsIslandUnlocked("Base") then
                ProgAPI.UnlockIsland("Base")
            end
            return true, "Successfully entered Tech World!"
        end
    end

    return false, "Could not enter Tech World"
end

function ProgAPI.UnlockIsland(islandName: string): boolean
    if ProgAPI.IsIslandUnlocked(islandName) then return true end

    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
    
    local def = Directory and Directory.Islands and Directory.Islands[islandName]
    local cost = (def and def.Cost) or (islandMetaLookup[islandName] and islandMetaLookup[islandName].cost) or 0
    if clicks < cost then return false end

    local meta = islandMetaLookup[islandName]
    local targetWorld = meta and meta.world or "Overworld"
    local curWorld = stats.CurrentWorld or "Overworld"
    if targetWorld ~= curWorld and Channels.Portals then
        pcall(function() Channels.Portals:InvokeServer("TeleportToWorld", targetWorld) end)
        task.wait(0.4)
    end

    -- 1. The official Clicker Simulator remotes
    if Channels.Portals then
        pcall(function() Channels.Portals:InvokeServer("PurchaseIsland", islandName) end)
        pcall(function() Channels.Portals:InvokeServer("UnlockIslandByHitbox", islandName) end)
    end

    if Channels.Islands then
        pcall(function() Channels.Islands:InvokeServer("PurchaseIsland", islandName) end)
    end

    -- 2. Physical portal proximity fallback if still locked
    if not ProgAPI.IsIslandUnlocked(islandName) then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local mapFolder = workspace:FindFirstChild("_MAP")
        local portalModel = mapFolder and mapFolder:FindFirstChild("Portals") and mapFolder.Portals:FindFirstChild(islandName)
        if hrp and portalModel then
            local portalPart = portalModel:FindFirstChild("Portal") or portalModel:FindFirstChildWhichIsA("BasePart") or portalModel.PrimaryPart
            if portalPart then
                local prevCF = hrp.CFrame
                hrp.CFrame = portalPart.CFrame
                task.wait(0.2)
                pcall(function() Channels.Portals:InvokeServer("PurchaseIsland", islandName) end)
                pcall(function() Channels.Portals:InvokeServer("UnlockIslandByHitbox", islandName) end)
                task.wait(0.15)
                if not ProgAPI.IsIslandUnlocked(islandName) then
                    hrp.CFrame = prevCF
                end
            end
        end
    end

    task.wait(0.1)
    return ProgAPI.IsIslandUnlocked(islandName)
end

-- Checks all locked islands and automatically re-purchases any affordable islands in order
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
            
            -- If island is Base (first Tech World island), ensure player unlocked Tech World portal
            if islandId == "Base" and ProgAPI.IsIslandUnlocked("Hell") then
                ProgAPI.CheckAndEnterTechWorld()
            end

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
    -- World 1 (Overworld)
    { name = "BasicEgg",        cost = 250,             island = "Spawn" },
    { name = "FlowerEgg",       cost = 2750,            island = "Spawn" },
    { name = "AcornEgg",        cost = 175000,          island = "Winter" },
    { name = "SnowmanEgg",      cost = 1500000,         island = "Winter" },
    { name = "WoodEgg",         cost = 40000000,        island = "Forest" },
    { name = "CactusEgg",       cost = 300000000,       island = "Desert" },
    { name = "CottonCandyEgg",  cost = 20000000000,     island = "Candy" },
    { name = "ChocolateEgg",    cost = 70000000000,     island = "Candy" },
    { name = "PalmTreeEgg",     cost = 450000000000,    island = "Beach" },
    { name = "BeachBallEgg",    cost = 900000000000,    island = "Beach" },
    { name = "BlossomEgg",      cost = 1e14,            island = "Sakura" },
    { name = "VolcanoEgg",      cost = 1e16,            island = "Volcano" },
    { name = "DiscoEgg",        cost = 2e17,            island = "Rave" },
    { name = "AngelEgg",        cost = 4e18,            island = "Heaven" },
    { name = "CastleEgg",       cost = 5e19,            island = "Castle" },
    { name = "CursedEgg",       cost = 1.5e20,          island = "Mystical" },
    { name = "RockEgg",         cost = 1e21,            island = "Mystical" },
    { name = "DemonicEgg",      cost = 1.5e22,          island = "Hell" },

    -- World 2 (Tech World)
    { name = "TechEgg",         cost = 4.5e22,          island = "Base" },
    { name = "HolographicEgg",  cost = 1.5e23,          island = "Spaceship" },
    { name = "404Egg",          cost = 5e23,            island = "Fragment" },
    { name = "RedTechEgg",      cost = 1e24,            island = "Matrix" },
    { name = "FragmentedEgg",   cost = 5e24,            island = "Fragment" },
    { name = "MatrixEgg",       cost = 2.5e25,          island = "Matrix" },

    -- Event Eggs (Spawn) - Costs 1e16 (10 Qa clicks), only affordable when clicks >= 1e16!
    { name = "CandyCornEgg",    cost = 1e16,            island = "Spawn" },
    { name = "SixSevenEgg",     cost = 1e16,            island = "Spawn" },
}

local eggData = {}
for _, e in ipairs(REAL_PROGRESSION_EGGS) do
    eggData[e.name] = { cost = e.cost, island = e.island, name = e.name }
end

-- Dynamically incorporate / update any live eggs from Directory.Eggs
pcall(function()
    if Directory and Directory.Eggs then
        for name, data in pairs(Directory.Eggs) do
            local isRobux = (data.Currency == "Robux" or (data.Price and data.Price.Id == "Robux") or name:find("Robux"))
            local info = data.Info or {}
            local cur = info.Currency or data.Currency or "Clicks"
            if not isRobux and cur == "Clicks" then
                local cost = info.Cost or data.Cost or (data.Price and data.Price.Amount)
                if cost and cost > 0 and cost < math.huge then
                    if eggData[name] then
                        eggData[name].cost = cost
                    end
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
        local pInfo = (stats.Pets and stats.Pets[guid]) or (stats.EquippedPets and stats.EquippedPets[guid])
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
        local pInfo = (stats.Pets and stats.Pets[guid]) or (stats.EquippedPets and stats.EquippedPets[guid])
        if not pInfo then return false end
        local isRainbow = (pInfo.v == "Rainbow" or pInfo.Variant == "Rainbow")
        if not isRainbow then
            return false
        end
    end

    return hasAny
end

-- Rainbow Mode Checker: Active in Phase 2 when all islands are unlocked, Skill Tree is MAXED, but team is NOT yet 100% Rainbow
function ProgAPI.IsRainbowMode(): boolean
    local allIslands = ProgAPI.AreAllIslandsUnlocked()
    if not allIslands then return false end

    local stProg = ProgAPI.GetSkillTreeProgress()
    local isSkillTreeMaxed = stProg and stProg.CoinsComplete and stProg.TechComplete
    local isAllRainbow = ProgAPI.IsEquippedTeamAllRainbow()

    return isSkillTreeMaxed and (not isAllRainbow)
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

-- Finds the physical Egg model and target stand platform anywhere in the game world
function ProgAPI.FindEggModel(eggName: string): (Instance?, BasePart?)
    local cleanName = eggName:gsub("%s+", "")
    local mapFolder = workspace:FindFirstChild("_MAP")
    local interact = mapFolder and mapFolder:FindFirstChild("Interact")
    local eggsFolder = interact and interact:FindFirstChild("Eggs")
    
    local eggModel = eggsFolder and (eggsFolder:FindFirstChild(cleanName) or eggsFolder:FindFirstChild(eggName))
    if not eggModel and mapFolder then
        local directEggs = mapFolder:FindFirstChild("Eggs")
        if directEggs then
            eggModel = directEggs:FindFirstChild(cleanName) or directEggs:FindFirstChild(eggName)
        end
    end
    if not eggModel and workspace:FindFirstChild("Eggs") then
        eggModel = workspace.Eggs:FindFirstChild(cleanName) or workspace.Eggs:FindFirstChild(eggName)
    end
    
    -- Fallback search across workspace descendants
    if not eggModel then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if (desc.Name == cleanName or desc.Name == eggName) and desc:IsA("Model") then
                eggModel = desc
                break
            end
        end
    end
    
    if eggModel then
        local targetPart = eggModel:FindFirstChild("Point")
            or eggModel:FindFirstChild("Platform")
            or eggModel:FindFirstChild("Hitbox")
            or eggModel:FindFirstChildWhichIsA("BasePart")
            or eggModel.PrimaryPart
        return eggModel, targetPart
    end
    
    return nil, nil
end

-- Retrieves best affordable egg for the current furthest island or specified target island
-- Scales naturally from BasicEgg -> Island Eggs -> Event Egg (CandyCornEgg / SixSevenEgg at 1e16 clicks)
function ProgAPI.GetBestAffordableEgg(targetIsland: string?)
    local stats = Stats.Local(true) or {}
    local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
    local isFullEventGold = ProgAPI.HasFullGoldEventTeam()

    -- 1. If targetIsland explicitly requested, match best affordable egg on that island
    if targetIsland then
        local bestEggName, bestCost = nil, 0
        for eggName, meta in pairs(eggData) do
            if meta.island == targetIsland and meta.cost <= clicks then
                if meta.cost >= bestCost then
                    bestCost = meta.cost
                    bestEggName = eggName
                end
            end
        end
        if bestEggName then
            return { name = bestEggName, cost = bestCost, island = targetIsland }
        end
    end

    -- 2. Progressive Egg Selection:
    -- Searches all unlocked islands (and Spawn event eggs) for the highest egg cost <= clicks!
    local bestEggName = nil
    local bestCost = 0

    for eggName, meta in pairs(eggData) do
        local isEvent = (eggName == "CandyCornEgg" or eggName == "SixSevenEgg")
        local isIslandAvailable = ProgAPI.IsIslandUnlocked(meta.island) or (meta.island == "Spawn")

        if isIslandAvailable and meta.cost <= clicks then
            local eligible = true
            if isEvent then
                -- Event eggs only hatch if clicks >= 1e16 and player still needs an event gold team
                eligible = (clicks >= 1e16) and (not isFullEventGold)
            end

            if eligible then
                if meta.cost > bestCost then
                    bestCost = meta.cost
                    bestEggName = eggName
                elseif meta.cost == bestCost and isEvent then
                    bestEggName = eggName
                end
            end
        end
    end

    -- 3. Fallback: if player has less than 250 clicks, default to BasicEgg
    if not bestEggName then
        bestEggName = "BasicEgg"
        bestCost = 250
    end

    return {
        name = bestEggName,
        cost = bestCost,
        island = eggData[bestEggName] and eggData[bestEggName].island or "Spawn"
    }
end

function ProgAPI.TeleportToEgg(eggName: string): boolean
    local eggMeta = eggData[eggName]
    local island = eggMeta and eggMeta.island
    if island and ProgAPI.IsIslandUnlocked(island) then
        local stats = Stats.Local(true) or {}
        if stats.CurrentIsland ~= island then
            ProgAPI.TeleportToIsland(island)
            task.wait(0.3)
        end
    end

    local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and targetPart then
        hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.15)
        return true
    end

    return false
end

-- Calculates dynamic max multi-open hatch amount (1x, 3x, 8x, or higher) based on gamepasses, boosts, inventory space, and clicks
function ProgAPI.GetMaxEggOpenAmount(eggName: string?): number
    eggName = eggName or "BasicEgg"
    local maxCount = 8 -- Base multi-open fallback for players with multi-hatch capability

    if EggsFrontend then
        local count1 = pcall(function() return EggsFrontend.GetMaxButtonHatchCount(eggName) end) and EggsFrontend.GetMaxButtonHatchCount(eggName)
        local count2 = pcall(function() return EggsFrontend.GetMaxHatchCount(eggName) end) and EggsFrontend.GetMaxHatchCount(eggName)
        local count3 = pcall(function() return EggsFrontend.GetHalfHatchCount(eggName) end) and EggsFrontend.GetHalfHatchCount(eggName)
        local shouldPrompt = pcall(function() return EggsFrontend.ShouldPromptX8Hatch(eggName) end) and EggsFrontend.ShouldPromptX8Hatch(eggName)

        if not shouldPrompt and type(count1) == "number" and count1 > 0 then
            maxCount = math.max(maxCount, count1)
        elseif type(count3) == "number" and count3 > 0 then
            maxCount = math.max(maxCount, count3)
        elseif type(count2) == "number" and count2 > 0 then
            maxCount = math.max(maxCount, count2)
        end
    end

    -- Respect remaining inventory slots so inventory never overflows
    local stats = Stats.Local(true) or {}
    local curInv = 0
    for _ in pairs(stats.Pets or {}) do curInv = curInv + 1 end
    local maxInv = stats.MaxInventoryPets or 200
    local freeSlots = math.max(1, maxInv - curInv)
    maxCount = math.min(maxCount, freeSlots)

    -- Check affordability if eggName is known
    if eggName then
        local cost = (EggsFrontend and EggsFrontend.GetEggCost and pcall(function() return EggsFrontend.GetEggCost(eggName) end) and EggsFrontend.GetEggCost(eggName))
            or (ProgAPI.EggData and ProgAPI.EggData[eggName] and ProgAPI.EggData[eggName].cost)
        local clicks = (Currency and Currency.Get and Currency.Get("Clicks")) or (stats.Currency and stats.Currency.Clicks) or 0
        if cost and cost > 0 then
            local canAfford = math.floor(clicks / cost)
            maxCount = math.min(maxCount, math.max(1, canAfford))
        end
    end

    return math.max(1, math.floor(maxCount))
end

function ProgAPI.OpenEgg(eggName: string, amount: number?, skipTeleport: boolean?): (boolean, string)
    if not amount or amount <= 0 then
        amount = ProgAPI.GetMaxEggOpenAmount(eggName)
    end
    if not Channels.Egg then return false, "No Egg channel" end

    -- Verify character is in proximity to the egg model (server requires <= 20 studs)
    local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not skipTeleport then
        local needsTp = true
        if hrp and targetPart then
            local dist = (hrp.Position - targetPart.Position).Magnitude
            if dist <= 18 then
                needsTp = false
            end
        end
        if needsTp then
            ProgAPI.TeleportToEgg(eggName)
            task.wait(0.25)
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

    if not ok or res == false then
        pcall(function()
            Channels.Egg:FireServer("Open", eggName, amount)
        end)
    end

    if ok and (res == true or type(res) == "table") then
        pcall(ProgAPI.CraftGoldenPets)
        pcall(ProgAPI.EquipBest)
        return true, "Successfully opened " .. eggName
    end

    return false, "Failed to open egg: " .. tostring(res)
end

function ProgAPI.EquipBest()
    if Channels.Pets then
        pcall(function() Channels.Pets:FireServer("EquipBest") end)
        pcall(function() Channels.Pets:InvokeServer("EquipBest") end)
    end
end

function ProgAPI.UnequipAll()
    if Channels.Pets then
        pcall(function() Channels.Pets:FireServer("UnequipAll") end)
        pcall(function() Channels.Pets:InvokeServer("UnequipAll") end)
    end
end

-- Converts batches of duplicate normal pets into Golden pets with 100% Guaranteed Chance Priority
-- Includes equipped duplicates if needed to reach guaranteed threshold, and auto re-equips afterwards!
function ProgAPI.CraftGoldenPets(): number
    if not Channels.Pets and not Channels.Crafting then return 0 end
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
        local isLocked = p.Locked == true or p.l == true
        local isNormal = (p.v == nil or p.v == "Normal")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        if not isLocked and isNormal and not isExclusive then
            local key = tostring(p.id) .. "_" .. tostring(p.Shiny or p.s or false)
            if not groups[key] then
                local meta = Directory.Pets and Directory.Pets[p.id] or {}
                local multi = (meta.Stats and meta.Stats.Clicks) or 1
                groups[key] = { id = p.id, multi = multi, unequipped = {}, equipped = {} }
            end
            if equipped[guid] ~= nil then
                table.insert(groups[key].equipped, guid)
            else
                table.insert(groups[key].unequipped, guid)
            end
        end
    end

    local groupList = {}
    for _, g in pairs(groups) do table.insert(groupList, g) end
    table.sort(groupList, function(a, b) return a.multi > b.multi end)

    local craftedCount = 0
    for _, g in ipairs(groupList) do
        local totalAvailable = #g.unequipped + #g.equipped
        while totalAvailable >= requiredFor100 do
            local batch = {}
            while #batch < requiredFor100 and #g.unequipped > 0 do
                table.insert(batch, table.remove(g.unequipped, 1))
            end
            while #batch < requiredFor100 and #g.equipped > 0 do
                table.insert(batch, table.remove(g.equipped, 1))
            end

            if #batch < requiredFor100 then break end

            local ok, res = pcall(function()
                if Channels.Pets then
                    return Channels.Pets:InvokeServer("CraftGolden", batch)
                elseif Channels.Crafting then
                    return Channels.Crafting:InvokeServer("CraftGolden", batch)
                end
            end)
            if not ok or res == false then
                pcall(function()
                    if Channels.Pets then
                        Channels.Pets:FireServer("CraftGolden", batch)
                    end
                end)
            end

            craftedCount = craftedCount + 1
            totalAvailable = totalAvailable - requiredFor100
            task.wait(0.15)
        end
    end

    if craftedCount > 0 then
        ProgAPI.EquipBest()
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
        while #g.guids >= 6 do
            local batch = {}
            for i = 1, 6 do
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
        for slotKey, craft in pairs(rainbowCrafts) do
            local slotIndex = tonumber(slotKey)
            if slotIndex and type(craft) == "table" and craft.EndTimestamp then
                local now = workspace:GetServerTimeNow()
                local saveAge = stats.SaveAge or 0
                local remaining = craft.EndTimestamp - now
                if craft.SaveAge ~= nil then
                    remaining = remaining - (saveAge - craft.SaveAge) * 2
                end
                if remaining <= 0 then
                    local ok, res = pcall(function()
                        return Channels.Pets:InvokeServer("ClaimRainbowCraft", slotIndex)
                    end)
                    if ok and (res == true or type(res) == "table") then
                        claimedCount = claimedCount + 1
                        task.wait(0.15)
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

    if claimedCount > 0 then
        pcall(ProgAPI.EquipBest)
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
    local ownedMini = stats.MiniUpgrades or {}
    local bought = 0

    local miniFolder = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Interact")
        and workspace._MAP.Interact:FindFirstChild("MiniUpgrades")
    if not miniFolder then return 0 end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local upgradeList = { "AutoClick", "WalkSpeed1", "PetEquip1", "Storage1" }

    for _, id in ipairs(upgradeList) do
        local dirData = Directory.MiniUpgrades and Directory.MiniUpgrades[id]
        local cost = dirData and dirData.Cost or 999999999
        local isOwned = ownedMini[id] == true

        if not isOwned and gems >= cost then
            local model = miniFolder:FindFirstChild(id)
            local targetPart = model and (model:FindFirstChild("Part") or model:FindFirstChildWhichIsA("BasePart"))
            if targetPart then
                local savedCF = hrp.CFrame
                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.15)
                local ok, res = pcall(function()
                    return Channels.MiniUpgrades:InvokeServer("Purchase", id)
                end)
                if ok and res == true then
                    bought = bought + 1
                    gems = gems - cost
                    ownedMini[id] = true
                end
                task.wait(0.1)
                if hrp and hrp.Parent then
                    hrp.CFrame = savedCF
                end
                task.wait(0.1)
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

    local isDominusUnlocked = (stats.DominusAreaUnlocked == true or stats.SecretAreaDoorUnlocked == true)

    for catName, catData in pairs(d) do
        -- Skip hidden Dominus Fortune branch if DominusArea is not unlocked yet
        local catRequiresDominus = (catData.Requires and catData.Requires.DominusArea == true)
        if catRequiresDominus and not isDominusUnlocked then
            continue
        end

        if type(catData) == "table" and catData.Upgrades then
            for upgName, upgData in pairs(catData.Upgrades) do
                local upgRequiresDominus = (upgData.Requires and upgData.Requires.DominusArea == true)
                if upgRequiresDominus and not isDominusUnlocked then
                    continue
                end

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

local currentCoinsIsland = "Heaven"
local currentTechIsland = "Matrix"

-- Target lock / focus fire cache
local currentTargetUID: string? = nil
local currentTargetModel: Model? = nil

-- Finds the breakable zone part and zone ID for an island
function ProgAPI.GetIslandBreakableZone(islandName: string?, ignoreBossChest: boolean?): (Instance?, string?)
    if ignoreBossChest == nil then ignoreBossChest = true end
    local pData = ProgAPI.GetPlayerData()
    islandName = islandName or pData.CurrentIsland

    if islandName == "DominusArea" or islandName == "Dominus" then
        local mgFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Minigames")
        local domMg = mgFolder and mgFolder:FindFirstChild("DominusArea")
        if domMg then
            local interact = domMg:FindFirstChild("Interact")
            local tp = interact and interact:FindFirstChild("Teleport")
            local tpPart = tp and (tp:IsA("BasePart") and tp or tp:FindFirstChildWhichIsA("BasePart"))
            if tpPart then return tpPart, "DominusArea/1" end
            local anyPart = domMg:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then return anyPart, "DominusArea/1" end
        end
        local domArea = workspace:FindFirstChild("_MAP")
            and workspace._MAP:FindFirstChild("Interact")
            and workspace._MAP.Interact:FindFirstChild("DominusArea")
        local anchor = domArea and domArea:FindFirstChildWhichIsA("BasePart")
        if anchor then return anchor, "DominusArea/1" end
        return nil, "DominusArea/1"
    end

    local islands = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Islands")
    local isl = islands and islands:FindFirstChild(islandName)
    local interact = isl and isl:FindFirstChild("Interact")
    local bZones = interact and interact:FindFirstChild("BreakableZones")
    if bZones then
        -- In Heaven: if not ignoring boss chests, check if HugeHeavenChest has an active target or exists!
        if islandName == "Heaven" and not ignoreBossChest then
            local hugeZone = bZones:FindFirstChild("HugeHeavenChest")
            local bf = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
            local hasHugeBreakable = false
            if bf then
                for _, child in ipairs(bf:GetChildren()) do
                    local m = child:FindFirstChildWhichIsA("Model") or child
                    local bId = tostring(m:GetAttribute("BreakableId") or m.Name):lower()
                    local hp = m:GetAttribute("BreakableHP") or 1
                    if (bId:find("giant") or bId:find("huge") or bId:find("heaven")) and hp > 0 then
                        hasHugeBreakable = true
                        break
                    end
                end
            end
            if (hasHugeBreakable or math.random(1, 4) == 1) and hugeZone and hugeZone:IsA("BasePart") then
                return hugeZone, "Heaven/HugeHeavenChest"
            end
        end

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
                    if distToZone < 160 or distToPlayer < 50 or (not ignoreBossChest and entry.isBoss) then
                        table.insert(candidates, { entry = entry, dist = distToPlayer, isBoss = entry.isBoss })
                    end
                end
            end
        end

        if #candidates > 0 then
            table.sort(candidates, function(a, b)
                if not ignoreBossChest then
                    if a.isBoss and not b.isBoss then return true end
                    if not a.isBoss and b.isBoss then return false end
                end
                return a.dist < b.dist
            end)
            targetModel = candidates[1].entry.model
            targetUID = candidates[1].entry.uid
            currentTargetModel = targetModel
            currentTargetUID = targetUID
        end
    end

    if (not targetModel or not targetUID) and BreakablesFrontend and BreakablesFrontend.GetSnapshots then
        local snaps = BreakablesFrontend.GetSnapshots()
        for uid, snap in pairs(snaps) do
            if (snap.islandId == islandName or islandName == "DominusArea") and (snap.hp or 1) > 0 then
                targetUID = uid
                break
            end
        end
    end

    if not targetUID then
        if zonePart and (hrp.Position - zonePart.Position).Magnitude > 30 then
            hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        end
        return false, "Waiting for breakables respawn", nil
    end

    if not targetModel then
        if Channels.Breakables then
            pcall(function()
                Channels.Breakables:InvokeServer("Click", targetUID)
                Channels.Breakables:InvokeServer("Hit", targetUID, 1)
            end)
        end
        return true, "Attacking Dominus Breakable", targetUID
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

function ProgAPI.GetActiveIslandBreakablesCount(islandName: string, includeBoss: boolean?): number
    if islandName == "DominusArea" or islandName == "Dominus" then
        local dominusCenter = Vector3.new(400, 256.7, 2747.2)
        local count = 0
        local bf = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
        if bf then
            for _, f in ipairs(bf:GetChildren()) do
                local m = f:FindFirstChildWhichIsA("Model") or (f:IsA("Model") and f) or f:FindFirstChildWhichIsA("BasePart") or (f:IsA("BasePart") and f)
                if m then
                    local pos = m:IsA("Model") and m:GetPivot().Position or (m:IsA("BasePart") and m.Position)
                    if pos and (pos - dominusCenter).Magnitude < 150 then
                        local hp = m:GetAttribute("BreakableHP") or f:GetAttribute("BreakableHP") or 1
                        if hp > 0 then
                            count = count + 1
                        end
                    end
                end
            end
        end
        return count
    end

    if BreakablesFrontend and BreakablesFrontend.SyncIsland then
        pcall(function() BreakablesFrontend.SyncIsland(islandName) end)
    end
    
    local snaps = (BreakablesFrontend and BreakablesFrontend.GetSnapshots and BreakablesFrontend.GetSnapshots()) or {}
    local snapCount = 0
    for uid, snap in pairs(snaps) do
        if snap.islandId == islandName and (snap.hp or 1) > 0 then
            local isBoss = ProgAPI.IsBossChest(snap.breakableId or uid)
            if includeBoss or not isBoss then
                snapCount = snapCount + 1
            end
        end
    end

    local wsCount = 0
    local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    if breakablesFolder then
        for _, f in ipairs(breakablesFolder:GetChildren()) do
            local entry = resolveBreakableEntry(f)
            if entry and entry.hp > 0 then
                local inIsland = false
                if entry.zone and entry.zone:find(islandName) then
                    inIsland = true
                else
                    local zonePart = ProgAPI.GetIslandBreakableZone(islandName, false)
                    if zonePart and (entry.pos - zonePart.Position).Magnitude < 160 then
                        inIsland = true
                    end
                end
                if inIsland then
                    if includeBoss or not entry.isBoss then
                        wsCount = wsCount + 1
                    end
                end
            end
        end
    end

    return math.max(snapCount, wsCount)
end

function ProgAPI.GetActiveBreakablesCount(islandName: string, zoneName: string?): number
    return ProgAPI.GetActiveIslandBreakablesCount(islandName, false)
end

function ProgAPI.GetBestBreakableIsland(mode: string?, attackBigChests: boolean?): string?
    local pData = ProgAPI.GetPlayerData()
    local unlocked = pData.UnlockedIslands or { "Spawn" }
    local unlockedSet = {}
    for _, isl in ipairs(unlocked) do unlockedSet[isl] = true end

    local techIslands = { "Matrix", "Fragment", "Spaceship", "Base" }
    mode = mode or "Auto (Dynamic Smart)"

    local progress = ProgAPI.GetSkillTreeProgress()
    local stats = Stats.Local(true) or {}
    local isDominusUnlocked = stats.DominusAreaUnlocked == true or stats.SecretAreaDoorUnlocked == true

    if not progress.CoinsComplete or mode == "Coins World (Volcano/Heaven)" or mode == "Coins Only" then
        -- User instruction: "instead of heaven volcano the big heaven chess hell chest just do the ??? area"
        currentCoinsIsland = "DominusArea"
        return "DominusArea"
    else
        -- Tech World progression: Matrix > Fragment > Spaceship > Base
        local curTechCount = ProgAPI.GetActiveIslandBreakablesCount(currentTechIsland, false)
        if curTechCount > 0 then
            return currentTechIsland
        end

        for _, isl in ipairs(techIslands) do
            if unlockedSet[isl] and ProgAPI.GetActiveIslandBreakablesCount(isl, false) > 0 then
                currentTechIsland = isl
                return currentTechIsland
            end
        end

        return "Matrix"
    end
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
function ProgAPI.StepBreakablesPipeline(attackBigChests: boolean?): (string, string)
    if attackBigChests == nil then attackBigChests = true end
    local stProg = ProgAPI.GetSkillTreeProgress()
    local targetWorld = ProgAPI.GetBestBreakableIsland("Auto (Dynamic Smart)", attackBigChests) or "Heaven"
    local pData = ProgAPI.GetPlayerData()

    -- Asynchronously purchase affordable perks (Coins prioritized first!)
    task.spawn(function()
        pcall(function()
            ProgAPI.BuyAffordableSkillTree(not stProg.CoinsComplete)
        end)
    end)

    local ignoreBoss = not attackBigChests

    -- Minigame handling for DominusArea
    local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
    if targetWorld == "DominusArea" then
        if MF and MF.Active and MF.Active() ~= "DominusArea" then
            pcall(function() MF.Enter("DominusArea") end)
            task.wait(0.35)
        end
    else
        if MF and MF.Active and MF.Active() == "DominusArea" then
            pcall(function() MF.Exit() end)
            task.wait(0.35)
        end
    end

    -- If player is not on the target breakables island, warp there
    if targetWorld ~= "DominusArea" and targetWorld and targetWorld ~= pData.CurrentIsland then
        ProgAPI.TeleportToIsland(targetWorld)
        task.wait(0.35)
        ProgAPI.TeleportToBreakableZone(targetWorld, ignoreBoss)
        task.wait(0.15)
    end

    -- Keep character anchored inside breakables zone
    if targetWorld ~= "DominusArea" then
        local zonePart = ProgAPI.GetIslandBreakableZone(targetWorld, ignoreBoss)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and zonePart and (hrp.Position - zonePart.Position).Magnitude > 35 then
            ProgAPI.TeleportToBreakableZone(targetWorld, ignoreBoss)
        end
    end

    -- Periodically sync HugeHeavenChest snapshot when on Heaven
    if targetWorld == "Heaven" and attackBigChests then
        pcall(function()
            if Channels.Breakables then
                Channels.Breakables:InvokeServer("Get", "Heaven/HugeHeavenChest")
            end
        end)
    end

    -- Attack breakable
    local okAtk = false
    local targetName, dmg = nil, nil
    pcall(function()
        okAtk, targetName, dmg = ProgAPI.AttackBreakable(ignoreBoss, targetWorld)
    end)

    -- If no attack on current island, check if all breakables on current island are truly broken (count == 0)
    if not okAtk and not stProg.CoinsComplete then
        local curCount = ProgAPI.GetActiveIslandBreakablesCount(targetWorld, attackBigChests)
        if curCount == 0 then
            -- ALL breakables on current island are broken! Now and only now look for alternate island
            local altIsland = (targetWorld == "Heaven") and "Volcano" or "Heaven"
            if targetWorld == "DominusArea" then altIsland = "Heaven" end
            local altCount = ProgAPI.GetActiveIslandBreakablesCount(altIsland, attackBigChests)
            if altCount > 0 then
                targetWorld = altIsland
                if altIsland ~= "DominusArea" and MF and MF.Active and MF.Active() == "DominusArea" then
                    pcall(function() MF.Exit() end)
                    task.wait(0.3)
                end
                ProgAPI.TeleportToIsland(altIsland)
                task.wait(0.35)
                ProgAPI.TeleportToBreakableZone(altIsland, ignoreBoss)
                return "Cleared arena! Teleporting to " .. tostring(altIsland), tostring(altIsland)
            end
        end
        return "Waiting for breakables respawn in " .. tostring(targetWorld), tostring(targetWorld)
    end

    if okAtk then
        return "Attacking " .. tostring(targetName or "Breakable"), targetWorld
    else
        return tostring(targetName or "Waiting for breakables respawn"), targetWorld
    end
end

-- Automatically claims all completed quests (Legacy, Challenges, Clans)
function ProgAPI.ClaimCompletedQuests(): number
    if not Channels.Quest then return 0 end
    local stats = Stats.Local(true) or {}
    local quests = stats.Quests or {}
    local claimedCount = 0

    for qId, qData in pairs(quests) do
        if type(qData) == "table" and qData.Completed ~= true then
            local tier = qData.Tier or 1
            local claimable = false

            if QuestFrontend and QuestFrontend.GetQuest then
                local qDef = QuestFrontend.GetQuest(qId)
                local curTier = QuestFrontend.GetCurrentTier and QuestFrontend.GetCurrentTier(qId) or tier
                local req = QuestFrontend.GetRequiredAmount and QuestFrontend.GetRequiredAmount(qId) or qData.Amount or 0
                local prog = QuestFrontend.GetProgress and QuestFrontend.GetProgress(qId) or qData.Progress or 0
                tier = curTier
                if req > 0 and prog >= req and (not qDef or qDef.Category ~= "???") then
                    claimable = true
                end
            else
                local req = qData.Amount or 0
                local prog = qData.Progress or 0
                if req > 0 and prog >= req and qData.Category ~= "???" then
                    claimable = true
                end
            end

            if claimable then
                local ok, res = pcall(function()
                    return Channels.Quest:InvokeServer("Claim", qId, tier)
                end)
                if ok and (res == true or type(res) == "table") then
                    claimedCount = claimedCount + 1
                    task.wait(0.08)
                end
            end
        end
    end

    return claimedCount
end

--==============================================================================
-- MILESTONES & REWARDS AUTOMATION
--==============================================================================
function ProgAPI.ClaimAllMilestones(): (number, number)
    local achClaimed = 0
    local roadClaimed = 0

    -- 1. Auto Claim Completed Quests
    pcall(ProgAPI.ClaimCompletedQuests)

    -- 2. Achievements (Milestones) via Frontend & Direct Remote Calls
    if Channels.Achievements then
        pcall(function() Channels.Achievements:FireServer("ClaimAll") end)

        if AchievementsFrontend and AchievementsFrontend.GetOrderedAchievements then
            local pcallOk, list = pcall(AchievementsFrontend.GetOrderedAchievements)
            if pcallOk and list then
                for _, ach in ipairs(list) do
                    local achId = ach._id or ach.Id or ach.Name
                    if achId and (AchievementsFrontend.IsClaimable == nil or AchievementsFrontend.IsClaimable(achId)) then
                        pcall(function() Channels.Achievements:FireServer("Claim", achId) end)
                        achClaimed = achClaimed + 1
                    end
                end
            end
        end

        if Directory and Directory.Achievements then
            for achId, _ in pairs(Directory.Achievements) do
                pcall(function() Channels.Achievements:FireServer("Claim", achId) end)
            end
        end
    end

    -- 3. Dedicated Milestones Channel fallback
    if Channels.Milestones then
        pcall(function() Channels.Milestones:FireServer("ClaimAll") end)
    end

    -- 4. Summer Road Milestones
    local raw = Stats.Local(true) or {}
    local shells = raw.Currency and raw.Currency.Shells or 0
    local claimed = (raw.SummerRewardsRoad and raw.SummerRewardsRoad.Claimed) or {}
    local road = Directory and Directory.SummerRewardsRoad or {}
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

    -- 5. Secondary Milestones & Retention / Leaving
    pcall(function()
        if Channels.RetentionGift then Channels.RetentionGift:FireServer("Claim") end
        if Channels.LeavingGift then Channels.LeavingGift:FireServer("Claim") end
        if Channels.LikesGoal then Channels.LikesGoal:FireServer("Claim") end
    end)

    return achClaimed, roadClaimed
end

-- Uses/consumes an item from inventory (Channels.Items is the official remote)
function ProgAPI.UseItem(itemId: string, tier: number?, amount: number?): (boolean, any)
    tier = tier or 1
    amount = amount or 1
    if not Channels.Items then return false, "No Items channel" end

    local ok, res = pcall(function()
        return Channels.Items:InvokeServer("Use", itemId, tier, amount)
    end)
    return ok and (res == true or type(res) == "table"), res
end

-- Consumables: Potions
function ProgAPI.UseAllBestPotions(): number
    local stats = Stats.Local(true) or {}
    local items = stats.Items or {}
    local usedCount = 0

    local potionTypes = { "Clicks Potion", "Hatch Speed Potion", "Luck Potion", "Gems Potion", "Clicks Speed Potion", "Raid Luck Potion", "Raid Damage Potion", "Raid XP Potion" }
    for _, pName in ipairs(potionTypes) do
        local bestTier = nil
        for tier = 10, 1, -1 do
            local key = pName .. "_" .. tostring(tier)
            if items[key] and items[key] > 0 then
                bestTier = tier
                break
            end
        end
        if bestTier then
            local ok = ProgAPI.UseItem(pName, bestTier, 1)
            if ok then
                usedCount = usedCount + 1
                task.wait(0.08)
            end
        end
    end

    -- Also check any other potion in stats.Items
    for key, count in pairs(items) do
        local amount = tonumber(count) or 0
        if amount > 0 and key:find("Potion") then
            local baseName, tierStr = key:match("^(.-)_(%d+)$")
            local tier = tonumber(tierStr) or 1
            baseName = baseName or key
            local ok = ProgAPI.UseItem(baseName, tier, 1)
            if ok then
                usedCount = usedCount + 1
                task.wait(0.05)
            end
        end
    end

    return usedCount
end

-- Consumables: Fruits
function ProgAPI.UseAllFruits(): number
    local stats = Stats.Local(true) or {}
    local items = stats.Items or {}
    local usedCount = 0

    local fruitTypes = { "Apple", "Blueberry", "Strawberry", "Watermelon", "Green Apple", "Orange", "Banana", "Dragonfruit", "Pineapple", "Grape", "Pear" }
    for _, fruit in ipairs(fruitTypes) do
        local owned = items[fruit .. "_1"] or items[fruit] or 0
        if type(owned) == "table" then owned = owned.Amount or owned.Count or 1 end
        owned = tonumber(owned) or 0
        if owned > 0 then
            local toUse = math.min(owned, 10)
            local ok = ProgAPI.UseItem(fruit, 1, toUse)
            if ok then
                usedCount = usedCount + toUse
                task.wait(0.08)
            end
        end
    end

    -- Also check any other fruit in stats.Items
    for key, count in pairs(items) do
        local amount = tonumber(count) or 0
        if amount > 0 and (key:find("Fruit") or key:find("Apple") or key:find("Berry") or key:find("Banana")) then
            local baseName, tierStr = key:match("^(.-)_(%d+)$")
            local tier = tonumber(tierStr) or 1
            baseName = baseName or key
            local toUse = math.min(amount, 10)
            local ok = ProgAPI.UseItem(baseName, tier, toUse)
            if ok then
                usedCount = usedCount + toUse
                task.wait(0.05)
            end
        end
    end

    return usedCount
end

-- Free Gifts: Clicker Simulator uses Channels.FreeGifts:FireServer("ClaimGift", i)
function ProgAPI.ClaimAllFreeGifts(): number
    if not Channels.FreeGifts then return 0 end
    local stats = Stats.Local(true) or {}
    local playtime = stats.FreeGiftsPlaytime or 0
    local claimedGifts = stats.FreeGifts or {}
    local times = (Directory and Directory.FreeGifts and Directory.FreeGifts.Times) or {3, 6, 9, 12, 15, 20, 25, 30, 40, 50, 55, 60}
    local claimed = 0

    for i = 1, #times do
        if claimedGifts[i] == nil then
            local reqSeconds = times[i] * 60
            if playtime >= reqSeconds then
                Channels.FreeGifts:FireServer("ClaimGift", i)
                claimed = claimed + 1
                task.wait(0.08)
            end
        end
    end

    return claimed
end

function ProgAPI.ClaimHellChest(): boolean
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local chests = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Interact")
        and workspace._MAP.Interact:FindFirstChild("Chests")
    local hc = chests and chests:FindFirstChild("Hell Chest")
    local hb = hc and hc:FindFirstChild("Hitbox")
    if hrp and hb and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, hb, 0)
            task.wait(0.02)
            firetouchinterest(hrp, hb, 1)
        end)
        return true
    end
    return false
end

function ProgAPI.ClaimAllChests(): number
    local claimed = 0
    if Channels.BeachChest then
        local ok = pcall(function() return Channels.BeachChest:InvokeServer("Claim") end)
        if ok then claimed = claimed + 1 end
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local chests = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Interact")
        and workspace._MAP.Interact:FindFirstChild("Chests")
    if chests and hrp and firetouchinterest then
        for _, cName in ipairs({ "Hell Chest", "Grand Chest", "Beach Chest" }) do
            local c = chests:FindFirstChild(cName)
            local hb = c and c:FindFirstChild("Hitbox")
            if hb then
                pcall(function()
                    firetouchinterest(hrp, hb, 0)
                    task.wait(0.02)
                    firetouchinterest(hrp, hb, 1)
                    claimed = claimed + 1
                end)
            end
        end
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
-- SECRET ??? QUESTLINE (Overworld Gate / Dominus Area)
--==============================================================================
function ProgAPI.GetSecretQuestProgress()
    local stats = Stats.Local(true) or {}
    local collected = stats.SecretAreaCollectedFeathers or {}
    local count = 0
    for _ in pairs(collected) do count = count + 1 end
    return {
        FeathersCollected = count,
        DoorUnlocked = stats.DominusAreaUnlocked == true or stats.SecretAreaDoorUnlocked == true,
        QuestClaimed = stats.DominusAreaUnlocked == true,
    }
end

function ProgAPI.StepSecretQuest(): (boolean, string)
    local stats = Stats.Local(true) or {}
    local doorUnlocked = stats.DominusAreaUnlocked == true or stats.SecretAreaDoorUnlocked == true
    if doorUnlocked then
        local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
        if MF and MF.Enter and MF.Active and MF.Active() ~= "DominusArea" then
            pcall(function() MF.Enter("DominusArea") end)
        end
        return true, "??? Secret Door Unlocked!"
    end

    if not ProgAPI.IsIslandUnlocked("Mystical") then
        return false, "Unlock Mystical Island first!"
    end

    local questCh = Channels.Quest
    if not questCh then return false, "No Quest channel" end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Check if any completed secret sub-quests need claiming
    local quests = stats.Quests or {}
    for qId, qData in pairs(quests) do
        if type(qData) == "table" and qId:find("secret_") then
            if qData.Amount and qData.Progress and qData.Progress >= qData.Amount and qData.Completed ~= true then
                pcall(function()
                    questCh:InvokeServer("Claim", qId, qData.Tier or 1)
                end)
                task.wait(0.15)
            end
        end
    end

    -- 1. Secret Feathers: If secret_feathers is active and progress < amount
    local feathersQuest = quests.secret_feathers
    if feathersQuest and feathersQuest.Progress < feathersQuest.Amount and hrp then
        local collected = stats.SecretAreaCollectedFeathers or {}
        local CollectionService = game:GetService("CollectionService")
        local taggedFeathers = CollectionService:GetTagged("FindFeathers")
        for _, featherObj in ipairs(taggedFeathers) do
            if not collected[featherObj.Name] then
                local pivot = featherObj:GetPivot()
                hrp.CFrame = pivot + Vector3.new(0, 1, 0)
                task.wait(0.25)
                return false, string.format("Collecting Feathers (%d/%d)...", feathersQuest.Progress, feathersQuest.Amount)
            end
        end
    end

    -- 2. Secret Hatch Eggs: If secret_hatch_eggs is active and progress < amount
    local hatchQuest = quests.secret_hatch_eggs
    if hatchQuest and hatchQuest.Progress < hatchQuest.Amount then
        if stats.CurrentIsland ~= "Spawn" then
            ProgAPI.TeleportToIsland("Spawn")
            task.wait(0.3)
        end
        local basicEgg = workspace:FindFirstChild("_MAP")
            and workspace._MAP:FindFirstChild("Interact")
            and workspace._MAP.Interact:FindFirstChild("Eggs")
            and workspace._MAP.Interact.Eggs:FindFirstChild("BasicEgg")
        if basicEgg and hrp then
            local eggPart = basicEgg:FindFirstChild("EggModel") or basicEgg.PrimaryPart or basicEgg:FindFirstChildWhichIsA("BasePart")
            if eggPart and (hrp.Position - eggPart.Position).Magnitude > 16 then
                hrp.CFrame = eggPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.2)
            end
        end
        local maxHatch = math.min(8, ProgAPI.GetMaxEggOpenAmount("BasicEgg"))
        ProgAPI.OpenEgg("BasicEgg", maxHatch, true)
        return false, string.format("Hatching Eggs for ??? Quest (%d/%d)...", hatchQuest.Progress, hatchQuest.Amount)
    end

    -- 3. Secret Craft Golden: If secret_craft_golden is active and progress < amount
    local craftQuest = quests.secret_craft_golden
    if craftQuest and craftQuest.Progress < craftQuest.Amount then
        ProgAPI.CraftGoldenPets()
        return false, string.format("Crafting Golden Pets for ??? Quest (%d/%d)...", craftQuest.Progress, craftQuest.Amount)
    end

    -- 4. Secret Clicks: If secret_click_* is active and progress < amount
    for _, clickKey in ipairs({"secret_click_1", "secret_click_2", "secret_click_3"}) do
        local clickQ = quests[clickKey]
        if clickQ and clickQ.Progress < clickQ.Amount then
            ProgAPI.Click()
            return false, string.format("Clicking for ??? Quest (%d/%d)...", clickQ.Progress, clickQ.Amount)
        end
    end

    -- 5. Interacting with Door at Spawn to unlock
    local door = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Islands")
        and workspace._MAP.Islands:FindFirstChild("Spawn")
        and workspace._MAP.Islands.Spawn:FindFirstChild("Map")
        and workspace._MAP.Islands.Spawn.Map:FindFirstChild("Door")
    local interact = door and door:FindFirstChild("Interact")

    if hrp and interact and (hrp.Position - interact.Position).Magnitude > 15 then
        if stats.CurrentIsland ~= "Spawn" then
            ProgAPI.TeleportToIsland("Spawn")
            task.wait(0.3)
        end
        hrp.CFrame = interact.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.2)
    end

    local ok, res1, res2 = pcall(function()
        return questCh:InvokeServer("ClaimSecretAreaQuestline")
    end)

    if ok and res1 == true and (res2 == "Unlocked" or res2 == "Claimed") then
        local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
        if MF and MF.Enter then
            pcall(function() MF.Enter("DominusArea") end)
        end
        return true, "??? Door Unlocked! Entered Dominus Area."
    end

    return false, tostring(res2 or "In progress")
end

--==============================================================================
-- PERFORMANCE & MISC OPTIMIZATIONS (Black Screen 3D Render & Remove Maps)
--==============================================================================
local blackScreenGui = nil
local savedGuiStates = {}
local blackScreenInputConn = nil
local originalTransparencies = {}
local isMapsRemoved = false

ProgAPI.OnBlackScreenToggled = nil

function ProgAPI.SetBlackScreen(enabled: boolean)
    pcall(function()
        local RunService = game:GetService("RunService")
        if RunService and RunService.Set3dRenderingEnabled then
            RunService:Set3dRenderingEnabled(not enabled)
        end
    end)

    local targetParent = nil
    pcall(function()
        if typeof(gethui) == "function" then
            targetParent = gethui()
        end
    end)
    if not targetParent then
        pcall(function()
            targetParent = game:GetService("CoreGui")
        end)
    end
    if not targetParent then
        local lp = LocalPlayer or game:GetService("Players").LocalPlayer
        targetParent = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    end

    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))

    if enabled then
        -- Hide all ScreenGuis in PlayerGui to eliminate 2D UI draw calls and lingering labels
        if pg then
            for _, ch in ipairs(pg:GetChildren()) do
                if ch:IsA("ScreenGui") and ch ~= blackScreenGui then
                    if savedGuiStates[ch] == nil then
                        savedGuiStates[ch] = ch.Enabled
                    end
                    ch.Enabled = false
                end
            end
        end

        if not blackScreenGui or not blackScreenGui.Parent then
            if not targetParent then return end

            pcall(function()
                for _, ch in ipairs(targetParent:GetChildren()) do
                    if ch.Name == "ClickerHub_BlackScreen" and ch ~= blackScreenGui then
                        ch:Destroy()
                    end
                end
                if pg then
                    for _, ch in ipairs(pg:GetChildren()) do
                        if ch.Name == "ClickerHub_BlackScreen" and ch ~= blackScreenGui then
                            ch:Destroy()
                        end
                    end
                end
            end)

            blackScreenGui = Instance.new("ScreenGui")
            blackScreenGui.Name = "ClickerHub_BlackScreen"
            blackScreenGui.ResetOnSpawn = false
            blackScreenGui.DisplayOrder = 2147483647
            blackScreenGui.IgnoreGuiInset = true
            blackScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

            local bg = Instance.new("Frame")
            bg.Name = "BlackBackground"
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.Position = UDim2.new(0, 0, 0, 0)
            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bg.BackgroundTransparency = 0
            bg.BorderSizePixel = 0
            bg.Active = true
            bg.Parent = blackScreenGui

            local card = Instance.new("Frame")
            card.Size = UDim2.new(0, 520, 0, 220)
            card.AnchorPoint = Vector2.new(0.5, 0.5)
            card.Position = UDim2.new(0.5, 0, 0.5, 0)
            card.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
            card.BorderSizePixel = 0
            card.Parent = bg

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 16)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = Color3.fromRGB(168, 85, 247)
            cardStroke.Thickness = 2
            cardStroke.Transparency = 0.2
            cardStroke.Parent = card

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 50)
            title.Position = UDim2.new(0, 0, 0, 22)
            title.BackgroundTransparency = 1
            title.Text = "Premium Script !"
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.TextSize = 36
            title.Font = Enum.Font.GothamBold
            title.Parent = card

            local sub = Instance.new("TextLabel")
            sub.Size = UDim2.new(1, -40, 0, 48)
            sub.Position = UDim2.new(0, 20, 0, 76)
            sub.BackgroundTransparency = 1
            sub.Text = "⚡ <b>3D Rendering Disabled • CPU & GPU Saver Active</b> ⚡\nMemory and processor load minimized for 24/7 background AFK farming."
            sub.RichText = true
            sub.TextColor3 = Color3.fromRGB(192, 132, 252)
            sub.TextSize = 14
            sub.Font = Enum.Font.GothamMedium
            sub.TextWrapped = true
            sub.Parent = card

            local restoreBtn = Instance.new("TextButton")
            restoreBtn.Name = "RestoreBtn"
            restoreBtn.Size = UDim2.new(0, 260, 0, 42)
            restoreBtn.AnchorPoint = Vector2.new(0.5, 0)
            restoreBtn.Position = UDim2.new(0.5, 0, 0, 136)
            restoreBtn.BackgroundColor3 = Color3.fromRGB(126, 58, 242)
            restoreBtn.BorderSizePixel = 0
            restoreBtn.Text = "↺  Restore UI / Resume 3D"
            restoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            restoreBtn.TextSize = 15
            restoreBtn.Font = Enum.Font.GothamBold
            restoreBtn.AutoButtonColor = true
            restoreBtn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 8)
            btnCorner.Parent = restoreBtn

            restoreBtn.MouseButton1Click:Connect(function()
                ProgAPI.SetBlackScreen(false)
            end)

            local hint = Instance.new("TextLabel")
            hint.Size = UDim2.new(1, 0, 0, 20)
            hint.Position = UDim2.new(0, 0, 0, 186)
            hint.BackgroundTransparency = 1
            hint.Text = "Click button above or press RightControl to restore"
            hint.TextColor3 = Color3.fromRGB(140, 130, 160)
            hint.TextSize = 12
            hint.Font = Enum.Font.Gotham
            hint.Parent = card

            blackScreenGui.Parent = targetParent
        end

        blackScreenGui.Enabled = true

        if not blackScreenInputConn then
            local UserInputService = game:GetService("UserInputService")
            blackScreenInputConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift then
                    ProgAPI.SetBlackScreen(false)
                end
            end)
        end
    else
        if blackScreenInputConn then
            blackScreenInputConn:Disconnect()
            blackScreenInputConn = nil
        end

        if blackScreenGui then
            blackScreenGui.Enabled = false
        end

        -- Restore all previously hidden ScreenGuis
        if pg then
            for ch, wasEnabled in pairs(savedGuiStates) do
                pcall(function()
                    if ch and ch.Parent then
                        ch.Enabled = wasEnabled
                    end
                end)
            end
            savedGuiStates = {}

            local hubUI = pg:FindFirstChild("ClickerHub_UI")
            if hubUI then
                hubUI.Enabled = true
            end
        end
    end

    if ProgAPI.OnBlackScreenToggled then
        pcall(ProgAPI.OnBlackScreenToggled, enabled)
    end
end

function ProgAPI.SetRemoveMaps(enabled: boolean)
    isMapsRemoved = enabled
    local islands = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Islands")
    if not islands then return end

    if enabled then
        for _, isl in ipairs(islands:GetChildren()) do
            local map = isl:FindFirstChild("Map")
            local decor = map and map:FindFirstChild("Decor")
            if decor then
                for _, obj in ipairs(decor:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        if originalTransparencies[obj] == nil then
                            originalTransparencies[obj] = obj.Transparency
                        end
                        obj.Transparency = 1
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                        if originalTransparencies[obj] == nil then
                            originalTransparencies[obj] = obj.Enabled
                        end
                        obj.Enabled = false
                    end
                end
            end
        end
    else
        for obj, orig in pairs(originalTransparencies) do
            pcall(function()
                if obj and obj.Parent then
                    if obj:IsA("BasePart") then
                        obj.Transparency = orig
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                        obj.Enabled = orig
                    end
                end
            end)
        end
        table.clear(originalTransparencies)
    end
end

function ProgAPI.SetDisableInGameSettings(enabled: boolean)
    local SettingsCh = Channels.Settings or (Network and Network.Channel("Settings"))
    if not SettingsCh then return false end

    local targetSettings = {
        PotatoMode = enabled,
        DisableGoldenRolling = enabled,
        DisableScreenShake = enabled,
        HideClicksPopup = enabled,
        HideCrit = enabled,
        HidePetsOthers = enabled,
        HidePetsOwn = enabled,
        TransparentPets = enabled,
        DisableServerMessages = enabled,
    }

    for settingName, val in pairs(targetSettings) do
        pcall(function()
            SettingsCh:InvokeServer("SetSetting", settingName, val)
        end)
    end

    -- Visually update button states if PlayerGui.Settings is open
    pcall(function()
        local lp = LocalPlayer or game:GetService("Players").LocalPlayer
        local settingsGui = lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("Settings")
        if settingsGui then
            local scrolling = settingsGui:FindFirstChild("Scrolling", true)
            if scrolling then
                for settingName, val in pairs(targetSettings) do
                    local row = scrolling:FindFirstChild(settingName, true)
                    local btn = row and row:FindFirstChild("Button", true)
                    if btn then
                        local onImg = btn:FindFirstChild("On")
                        local offImg = btn:FindFirstChild("Off")
                        local title = btn:FindFirstChild("Title", true)
                        if onImg then onImg.Enabled = val end
                        if offImg then offImg.Enabled = not val end
                        if title and title:IsA("TextLabel") then
                            title.Text = val and "On" or "Off"
                        end
                    end
                end
            end
        end
    end)

    return true
end

return ProgAPI
