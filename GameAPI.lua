--!strict
--==============================================================================
-- [CLICKER HUB] GameAPI.lua
-- Robust API bridge for [⌛7H] Clicker Simulator!
-- Integrates directly with game internal Network channels, Stats, and Directory
--==============================================================================

local GameAPI = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Resolve Library & Client Modules safely
local Library = ReplicatedStorage:WaitForChild("Library", 10)
if not Library then
    error("[Clicker Hub] Failed to locate ReplicatedStorage.Library!")
end

local Client = Library:WaitForChild("Client", 10)
local Directory = require(Library:WaitForChild("Directory"))
local Constants = require(Library:WaitForChild("Constants"))
local Network = require(Client:WaitForChild("Network"))
local Stats = require(Client:WaitForChild("Stats"))

local Balancing = nil
pcall(function()
    Balancing = require(Library:WaitForChild("Balancing", 5))
end)

local Currency = nil
pcall(function()
    Currency = require(Client:WaitForChild("Currency", 5))
end)

local MasteryFrontend = nil
pcall(function()
    MasteryFrontend = require(Client:WaitForChild("MasteryFrontend", 5))
end)

local IslandsFrontend = nil
pcall(function()
    IslandsFrontend = require(Client:WaitForChild("IslandsFrontend", 5))
end)

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
    GrandChest = Network.Channel("GrandChest"),
    HellChest = Network.Channel("HellChest"),
    SpinWheel = Network.Channel("SpinWheelTimeRewards"),
    Breakables = Network.Channel("Breakables"),
    Upgrades = Network.Channel("Upgrades"),
    RebirthShop = Network.Channel("RebirthShop"),
    SkillTree = Network.Channel("SkillTree"),
    MiniUpgrades = Network.Channel("MiniUpgrades"),
    RNGUpgrades = Network.Channel("RNGUpgrades"),
    Quest = Network.Channel("Quest"),
    PotionCrafting = Network.Channel("PotionCrafting"),
    Items = Network.Channel("Items"),
    ClickSkins = Network.Channel("ClickSkins"),
    Prestige = Network.Channel("Prestige"),
}

-- Safe Frontend helpers
local BoostsFrontend = nil
pcall(function()
    BoostsFrontend = require(Client:WaitForChild("BoostsFrontend"))
end)

local AchievementsFrontend = nil
pcall(function()
    AchievementsFrontend = require(Client:WaitForChild("AchievementsFrontend"))
end)

local BreakablesFrontend = nil
pcall(function()
    BreakablesFrontend = require(Client:WaitForChild("BreakablesFrontend"))
end)

local QuestFrontend = nil
pcall(function()
    QuestFrontend = require(Client:WaitForChild("QuestFrontend"))
end)

--==============================================================================
-- STATS & METRICS
--==============================================================================
function GameAPI.GetPlayerData()
    local data = Stats.Local(true) or {}
    local curr = data.Currency or {}
    local curClicks = (Currency and Currency.Get and Currency.Get("Clicks")) or curr.Clicks or 0
    local curRebirths = (Currency and Currency.Get and Currency.Get("Rebirths")) or curr.Rebirths or 0
    local curGems = (Currency and Currency.Get and Currency.Get("Gems")) or curr.Gems or 0
    return {
        Clicks = curClicks,
        Rebirths = curRebirths,
        Gems = curGems,
        Tokens = curr.Tokens or 0,
        CurrentIsland = data.CurrentIsland or "Spawn",
        AvailableRebirthButtons = data.AvailableRebirthButtons or 1,
        OwnedRebirthButtons = data.OwnedRebirthButtons or {},
        Raw = data
    }
end

-- Format numbers nicely (e.g. 1.25M, 3.42B)
function GameAPI.FormatNumber(val: number): string
    val = tonumber(val) or 0
    if val < 1000 then return tostring(math.floor(val)) end
    local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qd", "Qio", "Sxd", "Spd", "Ocd", "Nod", "Vg"}
    local exp = math.floor(math.log10(math.max(1, math.abs(val))) / 3)
    exp = math.clamp(exp, 0, #suffixes - 1)
    local short = val / (10 ^ (exp * 3))
    return string.format("%.2f%s", short, suffixes[exp + 1])
end

--==============================================================================
-- CLICKING
--==============================================================================
function GameAPI.Click()
    if Channels.Click then
        Channels.Click:FireServer("Click", true)
    end
end

--==============================================================================
-- REBIRTHS
--==============================================================================
function GameAPI.Rebirth(index: number)
    if Channels.Rebirths then
        Channels.Rebirths:FireServer("Rebirth", index or 1)
    end
end

-- Triggers in-game instant max rebirth remote (highest milestone affordable right now)
function GameAPI.MaxRebirth()
    if Channels.Rebirths then
        Channels.Rebirths:FireServer("MaxRebirth")
    end
end

-- Computes live data for the player's HIGHEST AFFORDABLE rebirth milestone button
function GameAPI.GetMaxRebirthInfo()
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

    local canAfford = (bestAffordableIdx ~= nil)
    local targetBtnIdx = bestAffordableIdx or 1
    local targetAmount = bestAffordableAmount > 0 and bestAffordableAmount or (Constants.Rebirths[targetBtnIdx] and Constants.Rebirths[targetBtnIdx].Amount or 1)
    local targetCost = bestAffordableCost > 0 and bestAffordableCost or 1000

    return {
        Buttons = buttons,
        MaxButtonIndex = targetBtnIdx,
        HighestOwnedIndex = highestOwnedIdx,
        MaxAmount = targetAmount,
        MaxCost = targetCost,
        CurrentClicks = curClicks,
        CanAffordMax = canAfford,
        BestAffordableIndex = targetBtnIdx,
        Progress = math.clamp(curClicks / math.max(1, targetCost), 0, 1)
    }
end

-- Rebirths at the highest affordable owned milestone button
function GameAPI.RebirthMaxTarget(): (boolean, any)
    local info = GameAPI.GetMaxRebirthInfo()
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

function GameAPI.GetBestAffordableRebirthIndex(): number
    local info = GameAPI.GetMaxRebirthInfo()
    return info.BestAffordableIndex or 1
end

--==============================================================================
-- PRESTIGE
--==============================================================================
function GameAPI.GetPrestigeInfo()
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

function GameAPI.CheckAndTriggerPrestige(): (boolean, string)
    local info = GameAPI.GetPrestigeInfo()
    if info.MaxPrestigeReached then
        return false, "Max Prestige reached"
    end
    if not info.CanPrestige then
        return false, string.format("Need %s Rebirths to Prestige", GameAPI.FormatNumber(info.RequiredRebirths))
    end
    if not Channels.Prestige then
        return false, "Prestige channel not found"
    end

    local ok, res = pcall(function()
        return Channels.Prestige:InvokeServer("Prestige")
    end)
    if ok and res == true then
        task.wait(14)
        return true, "Successfully Prestiged to Tier " .. tostring(info.CurrentPrestige + 1)
    end
    return false, "Prestige failed: " .. tostring(res)
end


--==============================================================================
-- PETS
--==============================================================================
function GameAPI.EquipBest()
    if Channels.Pets then
        Channels.Pets:FireServer("EquipBest")
    end
end

function GameAPI.UnequipAll()
    if Channels.Pets then
        Channels.Pets:FireServer("UnequipAll")
    end
end

-- Teleports to interactive world machines (Golden, Rainbow, Upgrades, etc.)
function GameAPI.TeleportToMachine(machineName: string): boolean
    local machinesFolder = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Interact") and workspace._MAP.Interact:FindFirstChild("Machines")
    if machinesFolder then
        for _, m in ipairs(machinesFolder:GetChildren()) do
            if m.Name:lower():find(machineName:lower()) then
                local pivot = m:GetPivot()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = pivot * CFrame.new(0, 3, 5)
                    return true
                end
            end
        end
    end
    return false
end

-- Checks whether every equipped pet slot is filled with Golden (or better) pets
function GameAPI.IsEquippedTeamAllGold(): boolean
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}
    local maxSlots = stats.MaxEquippedPets or 3

    local count = 0
    for guid, _ in pairs(equipped) do
        count = count + 1
        local p = pets[guid]
        if not p then return false end
        local v = p.v or "Normal"
        if v ~= "Golden" and v ~= "Rainbow" and v ~= "DarkMatter" then
            return false
        end
    end

    if count < maxSlots then
        return false
    end

    return true
end

-- Checks whether player has a full equipped team of Golden (or better) pets from the 10M Event Egg
function GameAPI.HasFullGoldEventTeam(): (boolean, number, number)
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}
    local maxSlots = stats.MaxEquippedPets or 3

    local eventPetIds = {
        WitchCat = true, WitchDog = true, MapleLeaf = true,
        CandyCorn = true, Candle = true, Gravestone = true, JackOLantern = true
    }

    local qualifyingCount = 0
    local equippedCount = 0
    for guid, _ in pairs(equipped) do
        equippedCount = equippedCount + 1
        local p = pets[guid]
        if p then
            local isGoldOrBetter = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")
            local isEventPet = eventPetIds[p.id] == true or (Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Stats and (Directory.Pets[p.id].Stats.Clicks or 0) >= 350000000)
            if isGoldOrBetter and isEventPet then
                qualifyingCount = qualifyingCount + 1
            end
        end
    end

    local isFull = (equippedCount >= maxSlots and qualifyingCount >= maxSlots)
    return isFull, qualifyingCount, maxSlots
end

-- Automatically converts batches of duplicate normal pets into Golden pets with 100% guaranteed chance priority
function GameAPI.CraftGoldenPets(): number
    if not Channels.Pets then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    -- Check GoldenCraftPetReduction mastery power
    local reduction = 0
    pcall(function()
        local MasteryFrontend = require(Client:WaitForChild("MasteryFrontend"))
        reduction = (MasteryFrontend and MasteryFrontend.GetPower and MasteryFrontend.GetPower(stats, "GoldenCraftPetReduction")) or 0
    end)
    local requiredFor100 = math.max(1, 6 - reduction)

    -- Group craftable normal pets by ID + Shiny status
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

    -- Prioritize turning the highest multiplier / best pets gold first!
    local groupList = {}
    for _, g in pairs(groups) do
        table.insert(groupList, g)
    end
    table.sort(groupList, function(a, b)
        return a.multi > b.multi
    end)

    local craftedCount = 0
    for _, g in ipairs(groupList) do
        -- Only craft when we have at least requiredFor100 pets (Guaranteed 100% Chance!)
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

-- Automatically converts batches of duplicate Golden pets into Rainbow pets
function GameAPI.CraftRainbowPets(): number
    if not Channels.Pets then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local groups = {}
    for guid, p in pairs(pets) do
        local isEquipped = equipped[guid] ~= nil
        local isLocked = p.Locked == true or p.l == true
        local isGolden = (p.v == "Golden")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        if not isEquipped and not isLocked and isGolden and not isExclusive then
            local key = p.id .. "_" .. tostring(p.Shiny or p.s or false)
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
                return Channels.Pets:InvokeServer("StartRainbowCraft", batch)
            end)
            if ok and res == true then
                craftedCount = craftedCount + 1
                task.wait(0.25)
            else
                break
            end
        end
    end
    return craftedCount
end

-- Automatically claims finished Rainbow pets from the machine
function GameAPI.ClaimRainbowPets(): number
    if not Channels.Pets then return 0 end
    local claimedCount = 0
    local maxLoops = 10

    while maxLoops > 0 do
        maxLoops = maxLoops - 1
        local stats = Stats.Local(true) or {}
        local rainbowCrafts = stats.RainbowCrafts
        if not rainbowCrafts or #rainbowCrafts == 0 then
            break
        end

        local now = workspace:GetServerTimeNow()
        local saveAge = (Stats.GetSaveAge and Stats.GetSaveAge()) or 0
        local claimedAny = false

        -- Active crafting slots run concurrently in up to 3 slots
        for slotIndex = 1, math.min(3, #rainbowCrafts) do
            local craft = rainbowCrafts[slotIndex]
            if craft and craft.EndTimestamp then
                local rem = craft.EndTimestamp - now
                if craft.SaveAge ~= nil and saveAge > 0 then
                    rem = rem - (saveAge - craft.SaveAge) * 2
                end

                if rem <= 0 then
                    local ok, res = pcall(function()
                        return Channels.Pets:InvokeServer("ClaimRainbowCraft", slotIndex)
                    end)
                    if ok and res == true then
                        claimedCount = claimedCount + 1
                        claimedAny = true
                        task.wait(0.25)
                        break -- Claiming shifts the array in stats; restart loop to claim next
                    end
                end
            end
        end

        if not claimedAny then
            break
        end
    end

    return claimedCount
end

--==============================================================================
-- EGGS & HATCHING
--==============================================================================
function GameAPI.GetEggList(): {string}
    local list = { "Best Affordable Egg" }
    if Directory and Directory.Eggs then
        local names = {}
        for name, _ in pairs(Directory.Eggs) do
            table.insert(names, name)
        end
        table.sort(names)
        for _, name in ipairs(names) do
            table.insert(list, name)
        end
    end
    if #list == 1 then
        for _, name in ipairs({"BasicEgg", "WoodEgg", "BeachEgg", "WinterEgg", "LavaEgg"}) do
            table.insert(list, name)
        end
    end
    return list
end

-- Teleports character right in front of the target egg model in the world
function GameAPI.TeleportToEgg(eggName: string): boolean
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

-- Finds the highest egg the player can currently afford across unlocked islands
function GameAPI.GetBestAffordableEgg()
    local pData = GameAPI.GetPlayerData()
    local curClicks = pData.Clicks

    -- If player can afford 10M Event Egg (10 Qa / 1e16 clicks) and doesn't have a full gold event team yet, prioritize it!
    local isFullGoldEvent = false
    pcall(function()
        isFullGoldEvent = GameAPI.HasFullGoldEventTeam()
    end)
    if curClicks >= 1e16 and not isFullGoldEvent then
        return { name = "CandyCornEgg", cost = 1e16, island = "Spawn" }
    end

    local unlocked = pData.Raw and pData.Raw.UnlockedIslands or {"Spawn"}
    local unlockedSet = {}
    for _, isl in ipairs(unlocked) do unlockedSet[isl] = true end

    local bestEgg = nil
    for _, egg in ipairs(GameAPI.ProgressionEggs) do
        if unlockedSet[egg.island] and curClicks >= egg.cost then
            bestEgg = egg
        end
    end
    return bestEgg or GameAPI.ProgressionEggs[1]
end

local nextAllowedHatchTick = 0

function GameAPI.OpenEgg(eggName: string, amount: number, skipTeleport: boolean?): (boolean, string)
    if not Channels.Egg then return false, "No egg channel" end
    local cleanName = eggName:gsub("%s+", "")
    if tick() < nextAllowedHatchTick then
        return false, string.format("Hatch cooldown (%.1fs remaining)", math.max(0, nextAllowedHatchTick - tick()))
    end

    -- Proximity verification: server enforces character proximity to the egg model
    if not skipTeleport then
        local eggsFolder = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Interact") and workspace._MAP.Interact:FindFirstChild("Eggs")
        local eggModel = eggsFolder and (eggsFolder:FindFirstChild(cleanName) or eggsFolder:FindFirstChild(eggName))
        local targetPart = eggModel and (eggModel:FindFirstChild("Point") or eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart"))
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and targetPart then
            local dist = (hrp.Position - targetPart.Position).Magnitude
            if dist > 25 then
                GameAPI.TeleportToEgg(cleanName)
                task.wait(0.2)
            end
        else
            GameAPI.TeleportToEgg(cleanName)
            task.wait(0.2)
        end
    end

    amount = amount or 1
    local guid = HttpService:GenerateGUID(false)
    local ok, res, extra = pcall(function()
        return Channels.Egg:InvokeServer("Open", cleanName, amount, guid)
    end)
    if ok and res == true then
        nextAllowedHatchTick = tick() + 0.35
        return true, "Success"
    elseif ok and type(extra) == "number" and extra > 0 then
        nextAllowedHatchTick = tick() + extra + 0.1
        return false, "Cooldown: " .. tostring(extra) .. "s"
    end
    nextAllowedHatchTick = tick() + 0.5
    return false, tostring(extra or res)
end

function GameAPI.SetAutoHatch(enabled: boolean, eggName: string, amount: number)
    if Channels.Egg then
        Channels.Egg:FireServer("SetAutoHatchEnabled", enabled, eggName, amount or 1)
    end
end

--==============================================================================
-- REWARDS & GIFTS
--==============================================================================
function GameAPI.ClaimAllFreeGifts()
    if not Channels.FreeGifts then return end
    for giftId = 1, 12 do
        Channels.FreeGifts:FireServer("ClaimGift", giftId)
    end
end

function GameAPI.ClaimAllAchievements()
    if not Channels.Achievements then return end
    if AchievementsFrontend and AchievementsFrontend.GetOrderedAchievements then
        local pcallOk, list = pcall(AchievementsFrontend.GetOrderedAchievements)
        if pcallOk and list then
            for _, ach in ipairs(list) do
                local achId = ach._id or ach.Id or ach.Name
                if achId and AchievementsFrontend.IsClaimable(achId) then
                    Channels.Achievements:FireServer("Claim", achId)
                end
            end
        end
    end
end

function GameAPI.ClaimAllChests()
    if Channels.BeachChest then
        pcall(function() Channels.BeachChest:InvokeServer("Claim") end)
    end
    if Channels.GrandChest then
        pcall(function() Channels.GrandChest:InvokeServer("Claim") end)
    end
    if Channels.HellChest then
        pcall(function() Channels.HellChest:InvokeServer("Claim") end)
    end
end

function GameAPI.ClaimDaily()
    if Channels.DailyRewards then
        pcall(function() Channels.DailyRewards:InvokeServer("Claim") end)
    end
end

function GameAPI.RollWheel()
    if Channels.SpinWheel then
        pcall(function() Channels.SpinWheel:InvokeServer("Roll") end)
    end
end

-- Automatically redeems all unredeemed active game codes from Directory.Codes
function GameAPI.RedeemAllCodes(): (number, {string})
    if not Directory.Codes or not Channels.Codes then return 0, {} end
    local stats = Stats.Local(true) or {}
    local redeemed = stats.RedeemedCodes or {}
    local successCodes = {}

    for codeName, _ in pairs(Directory.Codes) do
        if not redeemed[codeName] then
            local ok, res = pcall(function()
                return Channels.Codes:InvokeServer("Redeem", codeName)
            end)
            if ok and (res == "success" or res == true) then
                table.insert(successCodes, codeName)
                task.wait(1.5)
            end
        end
    end
    return #successCodes, successCodes
end

-- Automatically claims all completed quests
function GameAPI.ClaimCompletedQuests(): number
    if not Channels.Quest then return 0 end
    local qFrontend = nil
    pcall(function() qFrontend = require(Client:WaitForChild("QuestFrontend")) end)
    local stats = Stats.Local(true) or {}
    local quests = stats.Quests or {}
    local count = 0

    for qId, qData in pairs(quests) do
        if type(qData) == "table" and qData.Completed ~= true then
            local req = qFrontend and qFrontend.GetRequiredAmount(qId) or (qData.Amount or 0)
            local cur = qFrontend and qFrontend.GetProgress(qId) or (qData.Progress or 0)
            if req > 0 and cur >= req then
                local tier = qFrontend and qFrontend.GetCurrentTier(qId) or (qData.Tier or 1)
                local ok, res = pcall(function()
                    return Channels.Quest:InvokeServer("Claim", qId, tier)
                end)
                if ok and res == true then
                    count = count + 1
                    task.wait(0.2)
                end
            end
        end
    end
    return count
end

-- Automatically claims completed potion brews and finished Rainbow pet crafts
function GameAPI.ClaimFinishedCrafts(): number
    local count = 0
    local stats = Stats.Local(true) or {}
    local now = workspace:GetServerTimeNow()

    -- 1. Potion crafts
    if Channels.PotionCrafting and stats.PotionCrafts then
        for slotStr, pCraft in pairs(stats.PotionCrafts) do
            local slotNum = tonumber(slotStr)
            if slotNum and pCraft.EndTimestamp and now >= pCraft.EndTimestamp then
                local ok, res = pcall(function()
                    return Channels.PotionCrafting:InvokeServer("ClaimCraft", slotNum)
                end)
                if ok and res == true then
                    count = count + 1
                    task.wait(0.2)
                end
            end
        end
    end

    -- 2. Rainbow pet crafts
    local claimedRainbow = GameAPI.ClaimRainbowPets()
    count = count + claimedRainbow

    return count
end

--==============================================================================
-- CLICK SKINS (Magma Skin Endgame Passive: +4 Egg Hatch, +20% Hatch Speed)
--==============================================================================

function GameAPI.EquipClickSkin(skinName: string): boolean
    skinName = skinName or "Magma"
    if Channels.ClickSkins then
        local ok, res = pcall(function()
            return Channels.ClickSkins:InvokeServer("Equip", skinName)
        end)
        if ok and res then return true end
        pcall(function()
            Channels.ClickSkins:FireServer("Equip", skinName)
        end)
    end
    -- Try direct frontend / player state
    local char = LocalPlayer.Character
    return true
end

function GameAPI.UnlockClickSkin(skinName: string): boolean
    skinName = skinName or "Magma"
    if Channels.ClickSkins then
        local ok, res = pcall(function()
            return Channels.ClickSkins:InvokeServer("Unlock", skinName)
                or Channels.ClickSkins:InvokeServer("Buy", skinName)
                or Channels.ClickSkins:InvokeServer("Purchase", skinName)
        end)
        return ok and res == true
    end
    return false
end

function GameAPI.GetClickSkinStatus(skinName: string)
    skinName = skinName or "Magma"
    local stats = Stats.Local(true) or {}
    local skins = stats.ClickSkins or stats.Skins or stats.OwnedSkins or {}
    local equipped = stats.EquippedClickSkin or stats.EquippedSkin or stats.CurrentSkin
    local isUnlocked = false
    if type(skins) == "table" then
        if skins[skinName] == true or skins[skinName:lower()] == true then
            isUnlocked = true
        else
            for _, s in pairs(skins) do
                if tostring(s):lower() == skinName:lower() then
                    isUnlocked = true
                    break
                end
            end
        end
    end
    local isEquipped = (tostring(equipped):lower() == skinName:lower())
    return {
        unlocked = isUnlocked,
        equipped = isEquipped,
        name = skinName
    }
end

-- Evaluates 10 Qi Rebirth milestone and automatically equips the best Magma Click Skin
function GameAPI.CheckAndEquipMagmaSkin(): (boolean, string)
    local pData = GameAPI.GetPlayerData()
    local rebirths = pData.Rebirths or 0
    local targetRebirths = 1e19 -- 10 Qi Rebirths (10 Quintillion)

    local status = GameAPI.GetClickSkinStatus("Magma")
    if status.equipped then
        return true, "Magma Click Skin Active (+4 Egg Hatch, +20% Speed)"
    end

    if status.unlocked then
        GameAPI.EquipClickSkin("Magma")
        return true, "Equipped Magma Click Skin (+4 Egg Hatch, +20% Speed)"
    end

    if rebirths >= targetRebirths then
        GameAPI.UnlockClickSkin("Magma")
        GameAPI.EquipClickSkin("Magma")
        return true, "Unlocked & Equipped Magma Click Skin (+4 Egg Hatch, +20% Speed)"
    end

    local pct = math.clamp(math.floor((rebirths / targetRebirths) * 100), 0, 100)
    return false, string.format("10 Qi Rebirth Check: %s / 10.00Qi (%d%%)", GameAPI.FormatNumber(rebirths), pct)
end

--==============================================================================
-- ITEMS & CONSUMABLES AUTOMATION
--==============================================================================

-- Uses/consumes an item from inventory
function GameAPI.UseItem(itemId: string, tier: number?, amount: number?): (boolean, any)
    if not Channels.Items then return false, "No items channel" end
    tier = tier or 1
    amount = amount or 1
    local ok, res, extra = pcall(function()
        return Channels.Items:InvokeServer("Use", itemId, tier, amount)
    end)
    return ok and res == true, extra or res
end

-- Finds the highest owned tier for a given potion name
function GameAPI.GetBestOwnedPotionTier(potionName: string): number?
    local stats = Stats.Local(true) or {}
    local items = stats.Items or {}

    for tier = 10, 1, -1 do
        local key = potionName .. "_" .. tostring(tier)
        if items[key] and items[key] > 0 then
            return tier
        end
    end
    return nil
end

local lastPotionUseTime: {[string]: number} = {}
local lastFruitUseTime: {[string]: number} = {}

-- Automatically consumes active potions when their boost duration expires or runs low (< 15s)
function GameAPI.AutoConsumePotions(config: {[string]: boolean}?): number
    if not Channels.Items then return 0 end
    config = config or {
        ["Clicks Potion"] = true,
        ["Hatch Speed Potion"] = true,
        ["Luck Potion"] = true,
        ["Gems Potion"] = true,
        ["Clicks Speed Potion"] = true,
    }

    local active = (BoostsFrontend and BoostsFrontend.GetAllActiveBoosts and BoostsFrontend.GetAllActiveBoosts()) or {}
    local now = tick()
    local count = 0

    for potionName, enabled in pairs(config) do
        if enabled then
            local lastUse = lastPotionUseTime[potionName] or 0
            if (now - lastUse) >= 10 then
                local timeLeft = (BoostsFrontend and BoostsFrontend.GetTimeLeft and BoostsFrontend.GetTimeLeft(potionName)) or (active[potionName] and active[potionName].remaining or 0)
                if timeLeft <= 15 then
                    local bestTier = GameAPI.GetBestOwnedPotionTier(potionName)
                    if bestTier then
                        local ok = GameAPI.UseItem(potionName, bestTier, 1)
                        if ok then
                            count = count + 1
                            lastPotionUseTime[potionName] = now
                            task.wait(0.15)
                        end
                    end
                end
            end
        end
    end
    return count
end

-- Automatically eats fruits to maintain fruit buffs (1 at a time, protecting inventory)
function GameAPI.AutoConsumeFruits(): number
    if not Channels.Items then return 0 end
    local stats = Stats.Local(true) or {}
    local items = stats.Items or {}
    local fruitTypes = { "Apple", "Blueberry", "Strawberry", "Watermelon", "Green Apple", "Orange", "Banana", "Dragonfruit", "Pineapple", "Grape", "Pear" }
    local now = tick()
    local count = 0

    for _, fruit in ipairs(fruitTypes) do
        local owned = items[fruit .. "_1"] or 0
        if owned > 0 then
            local lastUse = lastFruitUseTime[fruit] or 0
            if (now - lastUse) >= 10 then
                local timeLeft = (BoostsFrontend and BoostsFrontend.GetTimeLeft and BoostsFrontend.GetTimeLeft(fruit)) or 0
                local q = (BoostsFrontend and BoostsFrontend.GetQueue and BoostsFrontend.GetQueue(fruit)) or {}
                if #q == 0 or timeLeft <= 15 then
                    local ok = GameAPI.UseItem(fruit, 1, 1)
                    if ok then
                        count = count + 1
                        lastFruitUseTime[fruit] = now
                        task.wait(0.15)
                    end
                end
            end
        end
    end
    return count
end

-- Immediately eats all available fruits up to stack limit
function GameAPI.UseAllFruits(): number
    local stats = Stats.Local(true) or {}
    local items = stats.Items or {}
    local fruitTypes = { "Apple", "Blueberry", "Strawberry", "Watermelon", "Green Apple", "Orange", "Banana", "Dragonfruit", "Pineapple", "Grape", "Pear" }
    local used = 0

    for _, fruit in ipairs(fruitTypes) do
        local owned = items[fruit .. "_1"] or 0
        if owned > 0 then
            local toUse = math.min(owned, 10)
            local ok = GameAPI.UseItem(fruit, 1, toUse)
            if ok then
                used = used + toUse
                task.wait(0.15)
            end
        end
    end
    return used
end

-- Immediately uses 1 of the highest owned tier for each potion type
function GameAPI.UseAllBestPotions(): number
    local potions = { "Clicks Potion", "Hatch Speed Potion", "Luck Potion", "Gems Potion", "Clicks Speed Potion" }
    local used = 0
    for _, pName in ipairs(potions) do
        local bestTier = GameAPI.GetBestOwnedPotionTier(pName)
        if bestTier then
            local ok = GameAPI.UseItem(pName, bestTier, 1)
            if ok then
                used = used + 1
                task.wait(0.25)
            end
        end
    end
    return used
end

-- Automatically crafts best powerups/potions across all 6 brewing slots
function GameAPI.AutoCraftPowerups(): number
    if not Directory.PotionRecipes or not Channels.PotionCrafting then return 0 end
    local stats = Stats.Local(true) or {}
    local crafts = stats.PotionCrafts or {}
    local items = table.clone(stats.Items or {})
    local started = 0

    for slot = 1, 6 do
        if not crafts[tostring(slot)] then
            local bestRecipe = nil
            local bestScore = 0

            for rId, rData in pairs(Directory.PotionRecipes) do
                local canCraft = true
                if rData.Ingredients then
                    for _, ing in ipairs(rData.Ingredients) do
                        local key = ing.ItemId .. "_" .. tostring(ing.Tier or 1)
                        if (items[key] or 0) < ing.Amount then
                            canCraft = false
                            break
                        end
                    end
                end

                if canCraft then
                    local tier = rData.Tier or (rData.Item and tonumber(rData.Item:match("(%d+)$"))) or 1
                    local score = tier * 10
                    if rData.ItemId and rData.ItemId:find("Potion") then score = score + 5 end
                    if rData.ItemId and rData.ItemId:find("Enchant") then score = score + 3 end
                    if score > bestScore then
                        bestScore = score
                        bestRecipe = { id = rId, data = rData }
                    end
                end
            end

            if bestRecipe then
                local ok, res = pcall(function()
                    return Channels.PotionCrafting:InvokeServer("StartCraft", slot, bestRecipe.id, 1)
                end)
                if ok and res == true then
                    started = started + 1
                    crafts[tostring(slot)] = true
                    if bestRecipe.data.Ingredients then
                        for _, ing in ipairs(bestRecipe.data.Ingredients) do
                            local key = ing.ItemId .. "_" .. tostring(ing.Tier or 1)
                            items[key] = (items[key] or 0) - ing.Amount
                        end
                    end
                    task.wait(0.25)
                end
            end
        end
    end
    return started
end

-- Formats status strings for items and active crafts
function GameAPI.GetItemsAndCraftStatus()
    local stats = Stats.Local(true) or {}
    local crafts = stats.PotionCrafts or {}
    local now = workspace:GetServerTimeNow()
    local activeCraftsCount = 0
    local craftDetails = {}

    for slot = 1, 6 do
        local c = crafts[tostring(slot)]
        if type(c) == "table" and c.EndTimestamp then
            activeCraftsCount = activeCraftsCount + 1
            local rem = math.max(0, math.floor(c.EndTimestamp - now))
            local statusStr = rem <= 0 and "READY" or string.format("%ds", rem)
            table.insert(craftDetails, string.format("Slot %d: %s T%s (%s)", slot, tostring(c.ItemId or c.RecipeId), tostring(c.Tier or 1), statusStr))
        elseif c == true then
            activeCraftsCount = activeCraftsCount + 1
            table.insert(craftDetails, string.format("Slot %d: In Progress", slot))
        end
    end

    return {
        activeCraftsCount = activeCraftsCount,
        craftDetails = #craftDetails > 0 and table.concat(craftDetails, "\n") or "All 6 Brewing Slots Free",
    }
end

--==============================================================================
-- ISLANDS & TELEPORTS
--==============================================================================
function GameAPI.GetIslandList(): {string}
    local list = {}
    if Directory and Directory.Islands then
        for name, data in pairs(Directory.Islands) do
            table.insert(list, name)
        end
        table.sort(list)
    end
    if #list == 0 then
        list = {"Spawn", "Winter", "Forest", "Desert", "Candy", "Beach", "Sakura", "Volcano", "Rave", "Heaven", "Castle", "Mystical", "Hell"}
    end
    return list
end

function GameAPI.TeleportToIsland(islandName: string): boolean
    local targetWorld = "Overworld"
    if Directory and Directory.Islands and Directory.Islands[islandName] then
        targetWorld = Directory.Islands[islandName].World or "Overworld"
    end
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    if targetWorld ~= curWorld and Channels.Portals then
        pcall(function()
            Channels.Portals:InvokeServer("TeleportToWorld", targetWorld)
        end)
        task.wait(0.6)
    end

    if Channels.Portals then
        local ok, res = pcall(function()
            return Channels.Portals:InvokeServer("TeleportToIsland", islandName)
        end)
        if ok and res == true then
            return true
        end
    end

    if IslandsFrontend and IslandsFrontend.LocalTeleport then
        local ok, res = pcall(function()
            return IslandsFrontend.LocalTeleport(islandName)
        end)
        if ok and res == true then
            return true
        end
    end

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

function GameAPI.IsIslandUnlocked(islandName: string): boolean
    if IslandsFrontend and IslandsFrontend.IsUnlocked then
        local ok, res = pcall(function()
            return IslandsFrontend.IsUnlocked(islandName)
        end)
        if ok and res ~= nil then
            return res == true
        end
    end
    local stats = Stats.Local(true) or {}
    local unlocked = stats.UnlockedIslands or {"Spawn"}
    for _, isl in ipairs(unlocked) do
        if isl == islandName then
            return true
        end
    end
    return false
end

-- Returns the highest/furthest unlocked island in progression order
function GameAPI.GetFurthestUnlockedIsland(): string
    local list = GameAPI.GetOverworldIslands()
    local furthest = "Spawn"
    for _, islandInfo in ipairs(list) do
        if GameAPI.IsIslandUnlocked(islandInfo.name) then
            furthest = islandInfo.name
        end
    end
    return furthest
end

function GameAPI.UnlockIsland(islandName: string): boolean
    if GameAPI.IsIslandUnlocked(islandName) then
        return true
    end
    if not Channels.Portals then return false end

    -- 1. Try official PurchaseIsland remote
    local pOk, pRes = pcall(function()
        return Channels.Portals:InvokeServer("PurchaseIsland", islandName)
    end)
    if (pOk and pRes == true) or GameAPI.IsIslandUnlocked(islandName) then
        return true
    end

    -- 2. Try UnlockIslandByHitbox remote
    local hOk, hRes = pcall(function()
        return Channels.Portals:InvokeServer("UnlockIslandByHitbox", islandName)
    end)
    if (hOk and hRes == true) or GameAPI.IsIslandUnlocked(islandName) then
        return true
    end

    task.wait(0.1)
    return GameAPI.IsIslandUnlocked(islandName)
end

-- Batch unlocks all affordable islands in sequential order
function GameAPI.UnlockAllAffordableIslands(): (number, string?)
    local count = 0
    local lastUnlocked = nil
    local maxIterations = 20

    while maxIterations > 0 do
        maxIterations = maxIterations - 1
        local nextIsld = GameAPI.GetNextLockedIsland()
        if not nextIsld then
            break -- All islands already unlocked!
        end

        local pData = GameAPI.GetPlayerData()
        if pData.Clicks < nextIsld.cost then
            break -- Insufficient clicks for next island
        end

        local ok = GameAPI.UnlockIsland(nextIsld.name)
        if ok or GameAPI.IsIslandUnlocked(nextIsld.name) then
            count = count + 1
            lastUnlocked = nextIsld.name
            task.wait(0.12)
        else
            -- Hitbox / physical proximity fallback
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local portalModel = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Portals") and workspace._MAP.Portals:FindFirstChild(nextIsld.name)
            if hrp and portalModel then
                local portalPart = portalModel:FindFirstChild("Portal") or portalModel:FindFirstChildWhichIsA("BasePart")
                if portalPart then
                    local prevCF = hrp.CFrame
                    hrp.CFrame = portalPart.CFrame
                    task.wait(0.2)
                    pcall(function() Channels.Portals:InvokeServer("PurchaseIsland", nextIsld.name) end)
                    pcall(function() Channels.Portals:InvokeServer("UnlockIslandByHitbox", nextIsld.name) end)
                    task.wait(0.15)
                    if GameAPI.IsIslandUnlocked(nextIsld.name) then
                        count = count + 1
                        lastUnlocked = nextIsld.name
                    else
                        hrp.CFrame = prevCF
                        break
                    end
                else
                    break
                end
            else
                break
            end
        end
    end

    if lastUnlocked then
        GameAPI.TeleportToIsland(lastUnlocked)
    end

    return count, lastUnlocked
end

-- Checks if next locked island is affordable; if so, batch unlocks all affordable islands and teleports to the highest
function GameAPI.UnlockAndTeleportToNextIsland(): (boolean, string)
    local nextIsland = GameAPI.GetNextLockedIsland()
    if not nextIsland then
        return false, "All islands already unlocked!"
    end

    local pData = GameAPI.GetPlayerData()
    if pData.Clicks < nextIsland.cost then
        return false, string.format("Need %s Clicks (Have %s)", GameAPI.FormatNumber(nextIsland.cost), GameAPI.FormatNumber(pData.Clicks))
    end

    local count, lastUnlocked = GameAPI.UnlockAllAffordableIslands()
    if count > 0 and lastUnlocked then
        return true, string.format("Unlocked %d Island(s)! Reached %s!", count, lastUnlocked)
    end

    return false, "Hitbox unlock interaction failed"
end

-- Calculates completion progress for Tech World (SpaceCoins) vs Overworld (Coins) skill tree perks
function GameAPI.GetSkillTreeProgress()
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
        SkillTreeUtil = require(Library.Utils.SkillTreeUtil)
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
        AllComplete = techDone and coinsDone
    }
end

local coinsSwitchTick = 0
local currentCoinsIsland = "Volcano"

function GameAPI.ForceSwitchCoinsIsland(): string
    coinsSwitchTick = tick()
    currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
    return currentCoinsIsland
end

-- Dynamically finds the best arena based on mode:
-- USER SPECIFICATION: Prioritizes COINS skill tree FIRST (switching between Volcano and Heaven), then once Coins are 100% complete, teleports to the latest unlocked Tech World island (Matrix > Fragment > Spaceship > Base)
function GameAPI.GetBestBreakableIsland(mode: string?): string?
    local pData = GameAPI.GetPlayerData()
    local unlocked = pData.Raw and pData.Raw.UnlockedIslands or {"Spawn"}
    local unlockedSet = {}
    for _, isl in ipairs(unlocked) do unlockedSet[isl] = true end

    -- Latest tech islands in descending order of progression (Matrix is the newest 17th world)
    local techIslands = { "Matrix", "Fragment", "Spaceship", "Base" }
    local coinsIslands = { "Heaven", "Volcano" }

    mode = mode or "Auto (Dynamic Smart)"

    if mode == "Coins World (Volcano/Heaven)" or mode == "Coins Only" then
        local now = tick()
        if now - coinsSwitchTick > 10 then
            coinsSwitchTick = now
            currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
        end
        if unlockedSet[currentCoinsIsland] and GameAPI.HasBreakables(currentCoinsIsland) then
            return currentCoinsIsland
        end
        return unlockedSet["Heaven"] and "Heaven" or "Volcano"
    elseif mode == "Tech World (Matrix/Fragment)" or mode == "Tech Only" then
        for _, isl in ipairs(techIslands) do
            if unlockedSet[isl] and GameAPI.HasBreakables(isl) then
                return isl
            end
        end
        return "Matrix"
    elseif mode == "Auto (Dynamic Smart)" or mode == "Best Unlocked" or mode == "" then
        local progress = GameAPI.GetSkillTreeProgress()

        -- 1. PRIORITIZE COINS SKILL TREE FIRST!
        -- Alternate between Volcano and Heaven to break all breakables!
        if not progress.CoinsComplete then
            local now = tick()
            if now - coinsSwitchTick > 10 then
                coinsSwitchTick = now
                currentCoinsIsland = (currentCoinsIsland == "Volcano") and "Heaven" or "Volcano"
            end
            if unlockedSet[currentCoinsIsland] and GameAPI.HasBreakables(currentCoinsIsland) then
                return currentCoinsIsland
            end
            if unlockedSet["Heaven"] and GameAPI.HasBreakables("Heaven") then return "Heaven" end
            if unlockedSet["Volcano"] and GameAPI.HasBreakables("Volcano") then return "Volcano" end
        else
            -- 2. AFTER ALL COINS UPGRADES ARE DONE:
            -- Teleport to the LATEST unlocked Tech World island (Matrix > Fragment > Spaceship > Base) to farm Tech Coins!
            for _, isl in ipairs(techIslands) do
                if unlockedSet[isl] and GameAPI.HasBreakables(isl) then
                    return isl
                end
            end
        end

        -- Fallback
        if unlockedSet["Matrix"] and GameAPI.HasBreakables("Matrix") then return "Matrix" end
        if unlockedSet["Heaven"] and GameAPI.HasBreakables("Heaven") then return "Heaven" end
        return "Volcano"
    elseif unlockedSet[mode] and GameAPI.HasBreakables(mode) then
        return mode
    end

    if GameAPI.HasBreakables(pData.CurrentIsland) then
        return pData.CurrentIsland
    end
    return "Heaven"
end

--==============================================================================
-- 24/7 AUTO PROGRESSION & PET MANAGEMENT SUITE
--==============================================================================

GameAPI.OverworldIslands = {
    { name = "Spawn",    cost = 0,                     num = 1 },
    { name = "Winter",   cost = 1250000,               num = 2 },
    { name = "Forest",   cost = 75000000,              num = 3 },
    { name = "Desert",   cost = 900000000,             num = 4 },
    { name = "Candy",    cost = 50000000000,           num = 5 },
    { name = "Beach",    cost = 2500000000000,         num = 6 },
    { name = "Sakura",   cost = 3.3333333333333e14,    num = 7 },
    { name = "Volcano",  cost = 1.5e16,                num = 8 },
    { name = "Rave",     cost = 7.5e17,                num = 9 },
    { name = "Heaven",   cost = 2.5e19,                num = 10 },
    { name = "Castle",   cost = 2e20,                  num = 11 },
    { name = "Mystical", cost = 2.5e21,                num = 12 },
    { name = "Hell",     cost = 5e22,                  num = 13 },
    { name = "Base",      cost = 1.5e23,                num = 14 },
    { name = "Spaceship", cost = 7.5e23,                num = 15 },
    { name = "Fragment",  cost = 5e24,                  num = 16 },
    { name = "Matrix",    cost = 2.5e25,                num = 17 },
}

-- Dynamically loads all islands from Directory.Islands to support any present or future game updates
function GameAPI.GetOverworldIslands()
    if Directory and Directory.Islands then
        local list = {}
        for name, data in pairs(Directory.Islands) do
            table.insert(list, {
                name = name,
                cost = data.Cost or 0,
                num = data.Index or data.Order or 0
            })
        end
        table.sort(list, function(a, b) return (a.cost or 0) < (b.cost or 0) end)
        for i, item in ipairs(list) do item.num = i end
        if #list >= 17 then
            GameAPI.OverworldIslands = list
            return list
        end
    end
    return GameAPI.OverworldIslands
end

GameAPI.ProgressionEggs = {
    { name = "BasicEgg",       cost = 250,        island = "Spawn" },
    { name = "FlowerEgg",      cost = 2750,       island = "Spawn" },
    { name = "AcornEgg",       cost = 175000,     island = "Spawn" },
    { name = "SnowmanEgg",     cost = 1500000,    island = "Winter" },
    { name = "WoodEgg",        cost = 40000000,   island = "Forest" },
    { name = "CactusEgg",      cost = 300000000,  island = "Desert" },
    { name = "CottonCandyEgg", cost = 20000000000,island = "Candy" },
    { name = "ChocolateEgg",   cost = 70000000000,island = "Candy" },
    { name = "PalmTreeEgg",    cost = 450000000000,island = "Beach" },
    { name = "BeachBallEgg",   cost = 900000000000,island = "Beach" },
    { name = "BlossomEgg",     cost = 1e14,       island = "Sakura" },
    { name = "VolcanoEgg",     cost = 1e16,       island = "Volcano" },
    { name = "DiscoEgg",       cost = 2e17,       island = "Rave" },
    { name = "AngelEgg",       cost = 4e18,       island = "Heaven" },
    { name = "CastleEgg",      cost = 5e19,       island = "Castle" },
    { name = "CursedEgg",      cost = 1.5e20,     island = "Mystical" },
    { name = "DemonicEgg",     cost = 1.5e22,     island = "Hell" },
    { name = "MatrixEgg",      cost = 2.5e25,     island = "Matrix" },
}

-- Rarity weight lookup hierarchy
GameAPI.RarityRank = {
    ["Any"] = 0,
    ["Basic"] = 1,
    ["Rare"] = 2,
    ["Epic"] = 3,
    ["Legendary"] = 4,
    ["Mythical"] = 5,
    ["Secret"] = 6,
    ["Divine"] = 6,
    ["Mega"] = 6,
    ["Special"] = 6,
    ["Exclusive"] = 6,
}

-- Evaluates pet rarity requirement across equipped slots and inventory
function GameAPI.GetPetRarityStatus(targetRarity: string?)
    targetRarity = targetRarity or "Epic"
    local targetRank = GameAPI.RarityRank[targetRarity] or 0
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}
    local maxSlots = stats.MaxEquippedPets or 3

    if targetRarity == "Any" or targetRank <= 0 then
        return {
            satisfied = true,
            targetRarity = "Any",
            maxSlots = maxSlots,
            equippedCount = maxSlots,
            equippedQualifying = maxSlots,
            totalQualifying = maxSlots,
            details = "No rarity requirement (Any)"
        }
    end

    local equippedQualifying = 0
    local equippedCount = 0
    local inventoryQualifying = 0

    for guid, pData in pairs(pets) do
        local meta = Directory.Pets[pData.id] or {}
        local r = meta.Rarity or "Basic"
        local rank = GameAPI.RarityRank[r] or 1
        if rank >= targetRank then
            inventoryQualifying = inventoryQualifying + 1
        end
    end

    for guid, _ in pairs(equipped) do
        equippedCount = equippedCount + 1
        local pData = pets[guid]
        if pData then
            local meta = Directory.Pets[pData.id] or {}
            local r = meta.Rarity or "Basic"
            local rank = GameAPI.RarityRank[r] or 1
            if rank >= targetRank then
                equippedQualifying = equippedQualifying + 1
            end
        end
    end

    -- Gating is satisfied when all maximum equipped pet slots are filled with pets >= targetRank
    local satisfied = (equippedCount >= maxSlots and equippedQualifying >= maxSlots)

    local details = string.format("%d/%d %s+ Equipped (Total: %d)", equippedQualifying, maxSlots, targetRarity, inventoryQualifying)

    return {
        satisfied = satisfied,
        targetRarity = targetRarity,
        maxSlots = maxSlots,
        equippedCount = equippedCount,
        equippedQualifying = equippedQualifying,
        totalQualifying = inventoryQualifying,
        details = details
    }
end

-- Returns the next locked island the player is working towards
function GameAPI.GetNextLockedIsland()
    local islandList = GameAPI.GetOverworldIslands()
    for _, islandInfo in ipairs(islandList) do
        if not GameAPI.IsIslandUnlocked(islandInfo.name) then
            return islandInfo
        end
    end
    return nil -- All islands unlocked!
end

-- Checks if current world objectives are complete and next island is unlocked
function GameAPI.TryUnlockNextIsland(targetRarity: string?): (boolean, string)
    local nextIsland = GameAPI.GetNextLockedIsland()
    if not nextIsland then
        return false, "All islands already unlocked!"
    end

    -- 1. Check Pet Gating Requirement (all equipped slots must meet chosen rarity)
    local petStatus = GameAPI.GetPetRarityStatus(targetRarity or "Epic")
    if not petStatus.satisfied then
        return false, "Waiting on pets: " .. petStatus.details
    end

    -- 2. Check Click Cost Requirement
    local pData = GameAPI.GetPlayerData()
    if pData.Clicks < nextIsland.cost then
        return false, string.format("Clicks: %s / %s", GameAPI.FormatNumber(pData.Clicks), GameAPI.FormatNumber(nextIsland.cost))
    end

    -- 3. Execute Current World Todos (Upgrades, Rebirth Buttons, Skill Tree)
    pcall(GameAPI.BuyAffordableGemUpgrades)
    pcall(GameAPI.BuyNextDoubleJump)
    pcall(GameAPI.BuyNextRebirthButton)
    pcall(GameAPI.BuyAffordableSkillTree)

    -- 4. Advance through hitbox teleportation
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local portalModel = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Portals") and workspace._MAP.Portals:FindFirstChild(nextIsland.name)

    if hrp and portalModel then
        local portalPart = portalModel:FindFirstChild("Portal") or portalModel:FindFirstChildWhichIsA("BasePart")
        if portalPart then
            local prevCF = hrp.CFrame
            hrp.CFrame = portalPart.CFrame
            task.wait(0.25)
            local ok = GameAPI.UnlockIsland(nextIsland.name)
            task.wait(0.2)
            if ok then
                GameAPI.TeleportToIsland(nextIsland.name)
                return true, "Unlocked & Teleported to " .. nextIsland.name
            else
                hrp.CFrame = prevCF
            end
        end
    else
        local ok = GameAPI.UnlockIsland(nextIsland.name)
        if ok then
            GameAPI.TeleportToIsland(nextIsland.name)
            return true, "Unlocked " .. nextIsland.name
        end
    end

    return false, "Hitbox unlock interaction failed"
end

-- Finds the best progression egg for the current island or unlocked islands
function GameAPI.GetBestProgressEgg(filterIsland: string?)
    local pData = GameAPI.GetPlayerData()
    local targetIsland = filterIsland or pData.CurrentIsland
    local unlocked = pData.Raw and pData.Raw.UnlockedIslands or {"Spawn"}
    local unlockedSet = {}
    for _, isld in ipairs(unlocked) do
        unlockedSet[isld] = true
    end

    -- Look for highest affordable egg on the target island first
    local bestIslandEgg = nil
    for _, egg in ipairs(GameAPI.ProgressionEggs) do
        if egg.island == targetIsland and pData.Clicks >= egg.cost then
            bestIslandEgg = egg
        end
    end
    if bestIslandEgg then
        return bestIslandEgg
    end

    -- Fallback: highest affordable egg across any unlocked island
    local bestEgg = GameAPI.ProgressionEggs[1]
    for _, egg in ipairs(GameAPI.ProgressionEggs) do
        if unlockedSet[egg.island] and pData.Clicks >= egg.cost then
            bestEgg = egg
        end
    end
    return bestEgg
end

-- Evaluates whether the player's equipped pet team is already good enough for the island
-- Returns (isSufficient: boolean, reason: string, currentTargetEgg: table?)
function GameAPI.ArePetsSufficientForIsland(targetIsland: string?): (boolean, string, any)
    local pData = GameAPI.GetPlayerData()
    targetIsland = targetIsland or pData.CurrentIsland
    local stats = Stats.Local(true) or {}
    local maxSlots = stats.MaxEquippedPets or 3
    local equipped = stats.EquippedPets or {}
    local pets = stats.Pets or {}

    -- 1. Check if all equipped slots are filled
    local equippedCount = 0
    local minEquippedMulti = math.huge
    local maxEquippedMulti = 0

    for guid, _ in pairs(equipped) do
        equippedCount = equippedCount + 1
        local pDataEntry = pets[guid]
        if pDataEntry then
            local meta = Directory.Pets and Directory.Pets[pDataEntry.id] or {}
            local m = (meta.Stats and meta.Stats.Clicks) or 1
            if m < minEquippedMulti then minEquippedMulti = m end
            if m > maxEquippedMulti then maxEquippedMulti = m end
        end
    end

    if equippedCount < maxSlots then
        return false, string.format("Need more pets (%d/%d equipped slots filled)", equippedCount, maxSlots), nil
    end

    -- 2. Find best egg on the target island
    local bestIslandEgg = nil
    for _, egg in ipairs(GameAPI.ProgressionEggs) do
        if egg.island == targetIsland then
            bestIslandEgg = egg
        end
    end

    -- If no egg directly on this island, find highest egg across unlocked islands
    if not bestIslandEgg then
        local unlocked = pData.Raw and pData.Raw.UnlockedIslands or {"Spawn"}
        local unlockedSet = {}
        for _, isld in ipairs(unlocked) do unlockedSet[isld] = true end
        for _, egg in ipairs(GameAPI.ProgressionEggs) do
            if unlockedSet[egg.island] then
                bestIslandEgg = egg
            end
        end
    end

    if not bestIslandEgg then
        return true, "No progression egg found for island", nil
    end

    -- 3. Determine expected multiplier of the target egg's base pets
    local expectedBaseMulti = 1
    if Directory.Eggs and Directory.Eggs[bestIslandEgg.name] then
        local drops = Directory.Eggs[bestIslandEgg.name].Drops or Directory.Eggs[bestIslandEgg.name].Pets or {}
        local dropMultis = {}
        for petId, _ in pairs(drops) do
            local meta = Directory.Pets and Directory.Pets[petId]
            local m = (meta and meta.Stats and meta.Stats.Clicks) or 1
            table.insert(dropMultis, m)
        end
        if #dropMultis > 0 then
            table.sort(dropMultis)
            expectedBaseMulti = dropMultis[1] or 1
        end
    else
        expectedBaseMulti = math.max(1, math.floor(bestIslandEgg.cost ^ 0.42))
    end

    -- 4. Check if player's worst equipped pet is already >= target egg's common multi
    if minEquippedMulti >= expectedBaseMulti then
        return true, string.format("Pets maxed for %s (Min multi: %sx >= %sx)", targetIsland, GameAPI.FormatNumber(minEquippedMulti), GameAPI.FormatNumber(expectedBaseMulti)), bestIslandEgg
    end

    return false, string.format("Upgrading pet team (%sx < %sx target)", GameAPI.FormatNumber(minEquippedMulti), GameAPI.FormatNumber(expectedBaseMulti)), bestIslandEgg
end

-- Parses inventory pets with full stats, rarity, and equipped/locked status
function GameAPI.GetInventoryPets()
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local petList = {}
    for guid, pData in pairs(pets) do
        local meta = Directory.Pets[pData.id] or {}
        local clicksMulti = (meta.Stats and meta.Stats.Clicks) or 1
        table.insert(petList, {
            guid = guid,
            id = pData.id,
            name = meta.Name or pData.id,
            rarity = meta.Rarity or "Basic",
            multi = clicksMulti,
            equipped = equipped[guid] ~= nil,
            locked = pData.l == true,
            isShiny = pData.s == true,
            variant = pData.v or "Normal"
        })
    end

    table.sort(petList, function(a, b)
        return a.multi > b.multi
    end)

    return petList
end

-- Automatically deletes old / inferior pets while keeping top pets, equipped, locked, and golden crafting candidates safe
function GameAPI.CleanOldPets(keepCount: number, protectCrafting: boolean?): number
    keepCount = keepCount or 15
    if protectCrafting == nil then protectCrafting = true end

    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    -- Find the best progression egg to protect its pets
    local bestEgg = GameAPI.GetBestAffordableEgg()
    local bestEggPets = {}
    if bestEgg and Directory.Eggs and Directory.Eggs[bestEgg.name] then
        local drops = Directory.Eggs[bestEgg.name].Drops or Directory.Eggs[bestEgg.name].Pets or {}
        for petId, _ in pairs(drops) do
            bestEggPets[petId] = true
        end
    end

    -- Count duplicate normal pets for crafting candidates
    local normalCounts = {}
    for guid, pData in pairs(pets) do
        local isNormal = (pData.v == nil or pData.v == "Normal")
        if isNormal then
            normalCounts[pData.id] = (normalCounts[pData.id] or 0) + 1
        end
    end

    local petList = GameAPI.GetInventoryPets()
    if #petList <= keepCount then
        return 0
    end

    local toDelete = {}
    -- Keep top `keepCount` pets, and examine the rest
    for i = keepCount + 1, #petList do
        local pet = petList[i]
        -- Never delete if equipped or locked
        if not pet.equipped and not pet.locked then
            -- Never delete special/high-tier variants
            if pet.rarity ~= "Secret" and pet.rarity ~= "Divine" and pet.rarity ~= "Mega" and pet.rarity ~= "Exclusive"
                and not pet.isShiny and pet.variant ~= "Golden" and pet.variant ~= "Rainbow" and pet.variant ~= "DarkMatter" then
                -- Protect candidate normal pets needed for Golden crafting:
                -- 1) Any pet belonging to the best egg currently being farmed
                -- 2) Any pet where we currently have >= 2 normal copies accumulating to reach 6
                local isBestEggDrop = bestEggPets[pet.id] == true
                local isCraftingCandidate = protectCrafting and (isBestEggDrop or (normalCounts[pet.id] and normalCounts[pet.id] >= 2))

                if not isCraftingCandidate then
                    table.insert(toDelete, pet.guid)
                end
            end
        end
    end

    if #toDelete > 0 and Channels.Pets then
        -- Send in chunks of 50 to avoid network payload limits
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

-- Deletes obsolete weak pets based on furthest unlocked island (deletes world <= N - 2)
function GameAPI.CleanWeakPets(protectCrafting: boolean?): number
    if protectCrafting == nil then protectCrafting = true end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local furthestIsland = GameAPI.GetFurthestUnlockedIsland()
    local islandOrder = {
        Spawn = 1, Winter = 2, Forest = 3, Desert = 4, Candy = 5, Beach = 6, Sakura = 7,
        Volcano = 8, Rave = 9, Heaven = 10, Castle = 11, Mystical = 12, Hell = 13,
        Base = 14, Spaceship = 15, Fragment = 16, Matrix = 17
    }
    local highestWorldIndex = islandOrder[furthestIsland] or 1
    local deleteThreshold = highestWorldIndex - 2

    local eggToIslandIndex = {
        BasicEgg = 1, FlowerEgg = 1, AcornEgg = 1, SnowmanEgg = 2, WoodEgg = 3,
        CactusEgg = 4, CottonCandyEgg = 5, ChocolateEgg = 5, PalmTreeEgg = 6, BeachBallEgg = 6,
        BlossomEgg = 7, VolcanoEgg = 8, DiscoEgg = 9, AngelEgg = 10, CastleEgg = 11,
        CursedEgg = 12, DemonicEgg = 13, TechEgg = 14, HolographicEgg = 14, ["404Egg"] = 15,
        RedTechEgg = 15, FragmentedEgg = 16, MatrixEgg = 17
    }

    local petToWorld = {}
    if Directory and Directory.Eggs then
        for eggName, worldIdx in pairs(eggToIslandIndex) do
            local eData = Directory.Eggs[eggName]
            if eData and eData.Pets then
                for _, p in ipairs(eData.Pets) do
                    local pId = p.Value or p.Id
                    if pId and not petToWorld[pId] then petToWorld[pId] = worldIdx end
                end
            end
        end
    end

    local bestEgg = GameAPI.GetBestAffordableEgg()
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
                local petOrigin = petToWorld[p.id] or 1
                if petOrigin <= deleteThreshold then
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
-- GEM UPGRADES, REBIRTH BUTTONS & SKILL TREE ENGINE
--==============================================================================

-- Buys all affordable Gem Upgrades (ClickUpgrade, Combo, HatchSpeed, AutoClickSpeed, CritChance)
function GameAPI.BuyAffordableGemUpgrades(): number
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

-- Buys the next unlocked Rebirth Button with Gems (Buttons 4 to 101+)
function GameAPI.BuyNextRebirthButton(): boolean
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
    for _, isl in pairs(unlockedIslands) do
        unlockedMap[isl] = true
    end
    unlockedMap["Spawn"] = true

    if not Constants.Rebirths or not Channels.RebirthShop then return false end

    -- Collect and sort all available rebirth button indices >= 4
    local buttonIndices = {}
    for k in pairs(Constants.Rebirths) do
        local num = tonumber(k)
        if num and num >= 4 then
            table.insert(buttonIndices, num)
        end
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
                break -- sequential: can only purchase buttons in strict sequential order
            end
        end
    end
    return boughtAny
end

-- Buys next Double Jump Upgrade with Gems
function GameAPI.BuyNextDoubleJump(): boolean
    local stats = Stats.Local(true) or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local curJumps = stats.Upgrades and stats.Upgrades.DoubleJumps or 1
    local nextJump = curJumps + 1
    local unlockedIslands = stats.UnlockedIslands or {"Spawn"}

    local unlockedMap = {}
    for _, isl in pairs(unlockedIslands) do unlockedMap[isl] = true end

    local jData = Directory.RebirthShop and Directory.RebirthShop.Jumps and Directory.RebirthShop.Jumps[nextJump]
    if jData and Channels.RebirthShop then
        local islandOk = jData.RequiredIsland == nil or unlockedMap[jData.RequiredIsland]
        if islandOk and gems >= jData.Cost then
            local ok = Channels.RebirthShop:InvokeServer("BuyDoubleJumpUpgrade", nextJump)
            return ok == true
        end
    end
    return false
end

-- Purchases permanent pet equip slot (+1), storage (+100), walkspeed, and autoclicker
function GameAPI.BuyAffordableMiniUpgrades(): number
    if not Directory.MiniUpgrades or not Channels.MiniUpgrades then return 0 end
    local stats = Stats.Local(true) or {}
    local miniOwned = stats.MiniUpgrades or {}
    local gems = stats.Currency and stats.Currency.Gems or 0
    local count = 0

    for id, data in pairs(Directory.MiniUpgrades) do
        if not miniOwned[id] then
            local cost = data.Cost or 0
            local currType = data.Currency or "Gems"
            if currType == "Gems" and gems >= cost then
                local ok, res = pcall(function()
                    return Channels.MiniUpgrades:InvokeServer("Purchase", id)
                end)
                if ok and res == true then
                    count = count + 1
                    gems = gems - cost
                    miniOwned[id] = true
                    task.wait(0.15)
                end
            end
        end
    end
    return count
end

-- Purchases affordable RNG world upgrades (BreakablesIncremental, LuckMultiplier, etc.)
function GameAPI.BuyAffordableRNGUpgrades(): number
    if not Directory.RNGUpgrades or not Channels.RNGUpgrades then return 0 end
    local stats = Stats.Local(true) or {}
    local pixelCoins = stats.Currency and stats.Currency.PixelCoins or 0
    local curLvls = stats.RNGUpgrades or {}
    local count = 0

    for id, data in pairs(Directory.RNGUpgrades) do
        local lvl = curLvls[id] or 0
        local nextCost = data.Costs and data.Costs[lvl + 1]
        if nextCost and pixelCoins >= nextCost and lvl < (data.MaxLevel or 100) then
            local ok, res = pcall(function()
                return Channels.RNGUpgrades:InvokeServer("Purchase", id, true)
            end)
            if ok and res == true then
                count = count + 1
                task.wait(0.15)
            end
        end
    end
    return count
end

--==============================================================================
-- BREAKABLES AUTOMATION (COINS FOR SKILL TREE)
--==============================================================================

-- Finds the breakable zone part and zone ID for an island
function GameAPI.GetIslandBreakableZone(islandName: string?, ignoreBossChest: boolean?): (Instance?, string?)
    if ignoreBossChest == nil then ignoreBossChest = true end
    local pData = GameAPI.GetPlayerData()
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

-- Checks if the island has breakables
function GameAPI.HasBreakables(islandName: string?): boolean
    local pData = GameAPI.GetPlayerData()
    islandName = islandName or pData.CurrentIsland
    if Directory and Directory.Islands and Directory.Islands[islandName] then
        if Directory.Islands[islandName].Breakables ~= nil then
            return true
        end
    end
    local zonePart = GameAPI.GetIslandBreakableZone(islandName, true)
    return zonePart ~= nil
end

-- Stop attacking and cleanly detach from breakables zone so normal player clicking works seamlessly
function GameAPI.StopBreakables()
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
function GameAPI.IsBossChest(modelOrId: any): boolean
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

-- Teleports character directly to the active breakable box itself or zone center
-- Target lock / focus fire cache
local currentTargetUID: string? = nil
local currentTargetModel: Model? = nil

-- Teleports character directly to the active breakable box itself or zone center
function GameAPI.TeleportToBreakableZone(islandName: string?, ignoreBossChest: boolean?): boolean
    if ignoreBossChest == nil then ignoreBossChest = true end
    local zonePart, zoneId = GameAPI.GetIslandBreakableZone(islandName, ignoreBossChest)
    if not zonePart then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if BreakablesFrontend and zoneId then
        pcall(function()
            BreakablesFrontend.EnterZone(zoneId)
        end)
    end

    -- Look for nearest active breakable model inside or near the standard zone
    local bestModel = nil
    local bestDist = math.huge
    local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
    if breakablesFolder then
        for _, f in ipairs(breakablesFolder:GetChildren()) do
            local m = f:FindFirstChildWhichIsA("Model")
            if m and m:GetAttribute("BreakableUID") then
                if not (ignoreBossChest and GameAPI.IsBossChest(m)) then
                    local hp = m:GetAttribute("BreakableHP") or 1
                    if hp > 0 then
                        local dist = (m:GetPivot().Position - zonePart.Position).Magnitude
                        if dist < 100 and dist < bestDist then
                            bestDist = dist
                            bestModel = m
                        end
                    end
                end
            end
        end
    end

    if bestModel and bestModel.Parent then
        local pivot = bestModel:GetPivot()
        hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 1.5, 3), pivot.Position)
        return true
    else
        hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        return true
    end
end

-- Attacks active breakable in the zone with 100% reliability (Focus Fire + Direct Server Remotes + Frontend Visuals)
function GameAPI.AttackBreakable(ignoreBossChest: boolean?): (boolean, string?, number?)
    if ignoreBossChest == nil then ignoreBossChest = true end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character", nil end

    local pData = GameAPI.GetPlayerData()
    local zonePart, zoneId = GameAPI.GetIslandBreakableZone(pData.CurrentIsland, ignoreBossChest)
    if not zonePart then return false, "No breakables on island", nil end

    if BreakablesFrontend and zoneId then
        pcall(function() BreakablesFrontend.EnterZone(zoneId) end)
    end

    -- Validate existing target lock (Focus Fire)
    local targetModel = currentTargetModel
    local targetUID = currentTargetUID

    if targetModel and targetModel.Parent and targetUID then
        local hp = targetModel:GetAttribute("BreakableHP")
        local isBoss = GameAPI.IsBossChest(targetModel)
        if hp == nil or hp <= 0 or (ignoreBossChest and isBoss) then
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

    -- If no valid locked target, select the best candidate
    if not targetModel then
        local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
        local candidates = {}
        local proximityOverride = nil

        if breakablesFolder then
            for _, f in ipairs(breakablesFolder:GetChildren()) do
                local m = f:FindFirstChildWhichIsA("Model")
                if m and m:GetAttribute("BreakableUID") then
                    local hp = m:GetAttribute("BreakableHP") or 1
                    if hp > 0 then
                        local pos = m:GetPivot().Position
                        local distToPlayer = (pos - hrp.Position).Magnitude
                        local distToZone = (pos - zonePart.Position).Magnitude
                        local isBoss = GameAPI.IsBossChest(m)

                        -- If ignoring boss chests, NEVER consider boss chests!
                        if not (ignoreBossChest and isBoss) then
                            if distToZone < 120 then
                                if distToPlayer < 22 then
                                    if not proximityOverride or distToPlayer < proximityOverride.dist then
                                        proximityOverride = { model = m, dist = distToPlayer }
                                    end
                                end
                                table.insert(candidates, { model = m, dist = distToPlayer, isBoss = isBoss })
                            end
                        end
                    end
                end
            end
        end

        if proximityOverride then
            targetModel = proximityOverride.model
        elseif #candidates > 0 then
            table.sort(candidates, function(a, b) return a.dist < b.dist end)
            targetModel = candidates[1].model
        else
            -- Server snapshot fallback if workspace models hadn't populated
            if Channels.Breakables then
                local serverSnaps = nil
                pcall(function()
                    serverSnaps = Channels.Breakables:InvokeServer("Get", pData.CurrentIsland)
                end)
                if type(serverSnaps) == "table" and #serverSnaps > 0 then
                    for _, s in ipairs(serverSnaps) do
                        local isBoss = GameAPI.IsBossChest(s.breakableId or "")
                        if s.uid and s.hp and s.hp > 0 then
                            if not (ignoreBossChest and isBoss) then
                                local f = breakablesFolder and breakablesFolder:FindFirstChild(s.uid)
                                local m = f and f:FindFirstChildWhichIsA("Model")
                                if m then
                                    targetModel = m
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        if targetModel then
            currentTargetModel = targetModel
            currentTargetUID = targetModel:GetAttribute("BreakableUID")
            targetUID = currentTargetUID
        end
    end

    if not targetModel or not targetUID then
        -- If ignoring boss chests and player is standing close to a boss chest, relocate to zone center!
        if ignoreBossChest then
            local breakablesFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Breakables")
            if breakablesFolder then
                for _, f in ipairs(breakablesFolder:GetChildren()) do
                    local m = f:FindFirstChildWhichIsA("Model")
                    if m and GameAPI.IsBossChest(m) then
                        local d = (m:GetPivot().Position - hrp.Position).Magnitude
                        if d < 35 then
                            hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
                            break
                        end
                    end
                end
            end
        end

        -- Keep player positioned at zone center while waiting for respawn wave
        if zonePart and (hrp.Position - zonePart.Position).Magnitude > 30 then
            hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        end
        return false, "Waiting for breakables respawn", nil
    end

    -- Face target and maintain close proximity
    local pivot = targetModel:GetPivot()
    local dist = (hrp.Position - pivot.Position).Magnitude
    if dist > 8 then
        hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 1.5, 3), pivot.Position)
    end

    -- Optimized Attack Execution (Prioritize BreakablesFrontend for damage numbers + audio + single server remote)
    local dmg = nil
    if BreakablesFrontend then
        pcall(function()
            local zone = targetModel:GetAttribute("BreakableZone")
            if zone and BreakablesFrontend.GetCurrentZone and BreakablesFrontend.GetCurrentZone() ~= zone then
                BreakablesFrontend.EnterZone(zone)
            end
            BreakablesFrontend.SetExternalTarget(targetModel)
            dmg = BreakablesFrontend.ReportClick(targetModel)

            local stats = Stats.Local(true) or {}
            local equipped = stats.EquippedPets or {}
            for guid, _ in pairs(equipped) do
                BreakablesFrontend.ReportStrike(guid)
            end
        end)
    elseif Channels.Breakables then
        -- Direct fallback only if BreakablesFrontend is unavailable
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

    return true, targetModel.Name, dmg
end

-- Purchases any affordable and unlocked Skill Tree perks (Default & RNG trees), prioritizing Coins when preferCoins is true
function GameAPI.BuyAffordableSkillTree(preferCoins: boolean?): number
    local stFrontend = nil
    pcall(function()
        stFrontend = require(Client:WaitForChild("SkillTreeFrontend"))
    end)
    if not Directory.SkillTree or not Channels.SkillTree then return 0 end

    if preferCoins == nil then
        local stProg = GameAPI.GetSkillTreeProgress()
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
                                    pcall(function() util = require(Library.Utils.SkillTreeUtil) end)
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

--==============================================================================
-- QUESTS AUTOMATION
--==============================================================================

function GameAPI.GetQuestList(): {active: {any}, claimable: {any}}
    local stats = Stats.Local(true) or {}
    local questsData = stats.Quests or {}
    local active = {}
    local claimable = {}

    for qId, qData in pairs(questsData) do
        if type(qData) == "table" and qData.Completed ~= true then
            local qDef = QuestFrontend and QuestFrontend.GetQuest(qId)
            if qDef and not qDef.Disabled then
                local tier = QuestFrontend.GetCurrentTier(qId)
                local req = QuestFrontend.GetRequiredAmount(qId)
                local prog = QuestFrontend.GetProgress(qId)
                local isClaimable = (req > 0 and prog >= req and qDef.Category ~= "???")
                local entry = {
                    id = qId,
                    tier = tier,
                    title = qDef.Title or qId,
                    prog = prog,
                    req = req,
                    claimable = isClaimable,
                    category = qDef.Category or "Uncategorized"
                }
                table.insert(active, entry)
                if isClaimable then
                    table.insert(claimable, entry)
                end
            end
        end
    end

    return {
        active = active,
        claimable = claimable,
    }
end

function GameAPI.ClaimCompletedQuests(): number
    if not Channels.Quest then return 0 end
    local qList = GameAPI.GetQuestList()
    local claimed = 0

    for _, q in ipairs(qList.claimable) do
        local ok, res = pcall(function()
            return Channels.Quest:InvokeServer("Claim", q.id, q.tier)
        end)
        if ok and res == true then
            claimed = claimed + 1
            task.wait(0.2)
        end
    end
    return claimed
end

--==============================================================================
-- GUI OVERLAY / BLACK SHADE SUPPRESSOR
--==============================================================================

function GameAPI.SuppressBlackShade()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pg then return end

    local function hookOverlayGui(gui)
        if gui.Name == "GUIOverlay" then
            local function fixOverlayFrame(f)
                if f.Name == "Overlay" and f:IsA("Frame") then
                    f.Visible = false
                    f.BackgroundTransparency = 1
                    f:GetPropertyChangedSignal("Visible"):Connect(function()
                        if f.Visible then f.Visible = false end
                    end)
                    f:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
                        if f.BackgroundTransparency < 1 then f.BackgroundTransparency = 1 end
                    end)
                end
            end
            for _, child in ipairs(gui:GetChildren()) do
                fixOverlayFrame(child)
            end
            gui.ChildAdded:Connect(fixOverlayFrame)
        end
    end

    for _, child in ipairs(pg:GetChildren()) do
        hookOverlayGui(child)
    end
    pg.ChildAdded:Connect(hookOverlayGui)
end

-- Automatically initialize shade suppression
task.spawn(function()
    pcall(GameAPI.SuppressBlackShade)
end)

--==============================================================================
-- SECRET ??? QUESTLINE AUTOMATION (DOMINUS AREA)
--==============================================================================

function GameAPI.GetSecretQuestProgress()
    local stats = Stats.Local(true) or {}
    local quests = stats.Quests or {}
    local isUnlocked = stats.DominusAreaUnlocked == true

    local clickProg = (quests.secret_click_1 and quests.secret_click_1.Progress) or 0
    local clickReq = (quests.secret_click_1 and quests.secret_click_1.Amount) or 3500

    local featherProg = (quests.secret_feathers and quests.secret_feathers.Progress) or 0
    local featherReq = (quests.secret_feathers and quests.secret_feathers.Amount) or 10

    local goldenProg = (quests.secret_craft_golden and quests.secret_craft_golden.Progress) or 0
    local goldenReq = (quests.secret_craft_golden and quests.secret_craft_golden.Amount) or 15

    local hatchProg = (quests.secret_hatch_eggs and quests.secret_hatch_eggs.Progress) or 0
    local hatchReq = (quests.secret_hatch_eggs and quests.secret_hatch_eggs.Amount) or 2500

    local clicksDone = clickProg >= clickReq
    local feathersDone = featherProg >= featherReq
    local goldenDone = goldenProg >= goldenReq
    local hatchDone = hatchProg >= hatchReq

    local allDone = (clicksDone and feathersDone and goldenDone and hatchDone) or isUnlocked

    local currentStep = "Completed"
    if isUnlocked then
        currentStep = "Area Unlocked"
    elseif not clicksDone then
        currentStep = "Clicks"
    elseif not feathersDone then
        currentStep = "Feathers"
    elseif not goldenDone then
        currentStep = "Golden Pets"
    elseif not hatchDone then
        currentStep = "Hatch Eggs"
    elseif allDone then
        currentStep = "Claim Door"
    end

    return {
        isUnlocked = isUnlocked,
        allDone = allDone,
        currentStep = currentStep,
        clicks = { prog = clickProg, req = clickReq, done = clicksDone },
        feathers = { prog = featherProg, req = featherReq, done = feathersDone },
        golden = { prog = goldenProg, req = goldenReq, done = goldenDone },
        hatch = { prog = hatchProg, req = hatchReq, done = hatchDone },
    }
end

-- Collects all 10 secret area feathers using touch interest
function GameAPI.CollectSecretFeathers(): number
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local feathersFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Feathers")
    if not feathersFolder then return 0 end

    local collected = 0
    for _, f in ipairs(feathersFolder:GetChildren()) do
        local hitbox = f:FindFirstChild("Hitbox")
        if hitbox and hitbox:IsA("BasePart") then
            if type(firetouchinterest) == "function" then
                firetouchinterest(hrp, hitbox, 0)
                task.wait(0.02)
                firetouchinterest(hrp, hitbox, 1)
                task.wait(0.01)
                collected = collected + 1
            else
                local prevCF = hrp.CFrame
                hrp.CFrame = hitbox.CFrame
                task.wait(0.05)
                hrp.CFrame = prevCF
                collected = collected + 1
            end
        end
    end
    return collected
end

-- Claims the Dominus secret door
function GameAPI.ClaimSecretDoor(): (boolean, string)
    if not Channels.Quest then return false, "No Quest channel" end

    local ok, res = pcall(function()
        return Channels.Quest:InvokeServer("ClaimSecretAreaQuestline")
    end)

    local door = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Islands")
        and workspace._MAP.Islands:FindFirstChild("Spawn")
        and workspace._MAP.Islands.Spawn:FindFirstChild("Map")
        and workspace._MAP.Islands.Spawn.Map:FindFirstChild("Door")
    local interact = door and door:FindFirstChild("Interact")
    local prompt = interact and interact:FindFirstChildOfClass("ProximityPrompt")

    if prompt and type(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt) end)
    end

    if ok then
        return true, tostring(res)
    else
        return false, tostring(res)
    end
end

-- Dynamically progresses the unfinished step of the secret ??? questline
function GameAPI.StepSecretQuest(): (boolean, string)
    local prog = GameAPI.GetSecretQuestProgress()
    if prog.isUnlocked then
        return true, "Dominus Secret Area already unlocked!"
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end

    -- 1. CLICKS STEP
    if not prog.clicks.done then
        GameAPI.Click(10)
        return true, string.format("Clicks: %d / %d", prog.clicks.prog, prog.clicks.req)
    end

    -- 2. FEATHERS STEP
    if not prog.feathers.done then
        local count = GameAPI.CollectSecretFeathers()
        return true, string.format("Collected feathers: %d / %d", prog.feathers.prog, prog.feathers.req)
    end

    -- 3. GOLDEN PETS STEP
    if not prog.golden.done then
        local crafted = GameAPI.CraftGoldenPets()
        if crafted > 0 then
            return true, string.format("Crafted %d Golden Pets (%d / %d)", crafted, prog.golden.prog, prog.golden.req)
        else
            -- Need normal pets to craft golden: ensure we hatch basic egg
            local pData = GameAPI.GetPlayerData()
            if pData.CurrentIsland ~= "Spawn" then
                GameAPI.TeleportToIsland("Spawn")
                task.wait(0.3)
            end
            local basicEgg = workspace:FindFirstChild("_MAP") 
                and workspace._MAP:FindFirstChild("Interact") 
                and workspace._MAP.Interact:FindFirstChild("Eggs") 
                and workspace._MAP.Interact.Eggs:FindFirstChild("BasicEgg")
            if basicEgg then
                if (hrp.Position - basicEgg:GetPivot().Position).Magnitude > 12 then
                    hrp.CFrame = basicEgg:GetPivot() * CFrame.new(0, 3, 5)
                    task.wait(0.2)
                end
                local guid = HttpService:GenerateGUID(false)
                Channels.Egg:InvokeServer("Open", "BasicEgg", 3, guid)
            end
            return true, "Hatching basic pets to craft Golden..."
        end
    end

    -- 4. HATCH EGGS STEP (2,500 Eggs)
    if not prog.hatch.done then
        -- Ensure player is on Spawn island
        local pData = GameAPI.GetPlayerData()
        if pData.CurrentIsland ~= "Spawn" then
            GameAPI.TeleportToIsland("Spawn")
            task.wait(0.4)
        end

        local basicEgg = workspace:FindFirstChild("_MAP") 
            and workspace._MAP:FindFirstChild("Interact") 
            and workspace._MAP.Interact:FindFirstChild("Eggs") 
            and workspace._MAP.Interact.Eggs:FindFirstChild("BasicEgg")

        if not basicEgg then
            return false, "Basic Egg model not found on Spawn"
        end

        -- Teleport right next to BasicEgg if farther than 12 studs
        if (hrp.Position - basicEgg:GetPivot().Position).Magnitude > 12 then
            hrp.CFrame = basicEgg:GetPivot() * CFrame.new(0, 3, 5)
            task.wait(0.25)
        end

        -- Clean trash pets if inventory is nearing full
        local petsModule = nil
        pcall(function() petsModule = require(Client:WaitForChild("Pets")) end)
        local remainingSlots = petsModule and petsModule.GetRemainingInventorySlots and petsModule.GetRemainingInventorySlots() or 100
        if remainingSlots < 20 then
            GameAPI.CleanOldPets(25)
            GameAPI.CraftGoldenPets()
            task.wait(0.1)
        end

        -- Determine hatch batch size
        local eggsFrontend = nil
        pcall(function() eggsFrontend = require(Client:WaitForChild("EggsFrontend")) end)
        local hatchAmount = (eggsFrontend and eggsFrontend.GetMaxHatchCount and eggsFrontend.GetMaxHatchCount("BasicEgg")) or 3

        local guid = HttpService:GenerateGUID(false)
        local ok, res = pcall(function()
            return Channels.Egg:InvokeServer("Open", "BasicEgg", hatchAmount, guid)
        end)

        return true, string.format("Hatching Basic Egg (%d / %d)", prog.hatch.prog, prog.hatch.req)
    end

    -- 5. ALL 4 REQUIREMENTS COMPLETED -> CLAIM DOOR!
    if prog.allDone and not prog.isUnlocked then
        local ok, res = GameAPI.ClaimSecretDoor()
        return true, "Claimed Secret Area Door: " .. tostring(res)
    end

    return true, "All ??? Quests Complete"
end

return GameAPI

