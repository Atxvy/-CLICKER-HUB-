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

local MinigamesFrontend = nil
pcall(function() MinigamesFrontend = require(Client:WaitForChild("MinigamesFrontend", 5)) end)

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
ProgAPI.MinigamesFrontend = MinigamesFrontend

function ProgAPI.GetActiveMinigameName(): string?
    local MF = MinigamesFrontend or (Client and Client:FindFirstChild("MinigamesFrontend") and require(Client.MinigamesFrontend))
    if not MF or not MF.Active then return nil end
    local a = MF.Active()
    if not a then return nil end
    if type(a) == "table" then return a.Name or a.WorldModel end
    if type(a) == "string" then return a end
    return nil
end

function ProgAPI.IsInMinigame(targetName: string?): boolean
    local cur = ProgAPI.GetActiveMinigameName()
    if not cur then return false end
    if targetName then return cur:lower() == targetName:lower() end
    return true
end

function ProgAPI.ExitMinigame(): boolean
    local MF = MinigamesFrontend or (Client and Client:FindFirstChild("MinigamesFrontend") and require(Client.MinigamesFrontend))
    if not MF or not MF.Exit then return false end
    if ProgAPI.IsInMinigame() then
        pcall(function() MF.Exit() end)
        task.wait(0.35)
        return true
    end
    return false
end

--==============================================================================
-- SESSION TRACKING, TELEMETRY & DISCORD WEBHOOK INTEGRATION
--==============================================================================
if not _G.__ProgAPI_SessionStats then
    _G.__ProgAPI_SessionStats = {
        Eggs = 0,
        Mythicals = 0,
        Secrets = 0,
        Megas = 0,
        StartTick = tick(),
    }
end
ProgAPI.SessionStats = _G.__ProgAPI_SessionStats
ProgAPI.WebhookUrl = ""
ProgAPI.WebhookEnabled = true
ProgAPI.CurrentActivity = "Auto Progression Active"
ProgAPI.CurrentPhase = "Evaluating..."
ProgAPI.SelectedEgg = "MatrixEgg"

function ProgAPI.FormatSessionTime(): string
    local startTick = (ProgAPI.SessionStats and ProgAPI.SessionStats.StartTick) or tick()
    local elapsed = math.max(0, math.floor(tick() - startTick))
    local hrs = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = elapsed % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

function ProgAPI.GetCurrentEggLuckMultiplier(): number
    local mult = 1
    pcall(function()
        local BoostsFrontend = nil
        pcall(function() BoostsFrontend = require(Client:WaitForChild("BoostsFrontend", 2)) end)
        if BoostsFrontend and BoostsFrontend.GetBoostMultiplier then
            local b1 = BoostsFrontend.GetBoostMultiplier("Luck") or 1
            local b2 = BoostsFrontend.GetBoostMultiplier("Super Luck") or 1
            local b3 = BoostsFrontend.GetBoostMultiplier("Ultra Luck") or 1
            mult = mult * b1 * b2 * b3
        end
    end)
    pcall(function()
        local raw = Stats.Local(true) or {}
        if MasteryFrontend and MasteryFrontend.GetPower then
            local mp = MasteryFrontend.GetPower(raw, "EggLuckMultiplier")
            if mp and mp > 0 then mult = mult * mp end
        end
    end)
    pcall(function()
        local SkillTreeUtil = nil
        pcall(function() SkillTreeUtil = require(Library:WaitForChild("Utils", 2):WaitForChild("SkillTreeUtil", 2)) end)
        if SkillTreeFrontend and SkillTreeFrontend.GetPower and SkillTreeUtil and SkillTreeUtil.Power and SkillTreeUtil.Power.LuckMultiplier then
            local sp = SkillTreeFrontend.GetPower(SkillTreeUtil.Power.LuckMultiplier)
            if sp and sp > 0 then mult = mult * sp end
        end
    end)
    return math.max(1, mult)
end

function ProgAPI.FormatLuck(mult: number?): string
    local m = mult or ProgAPI.GetCurrentEggLuckMultiplier()
    local pct = m * 100
    if pct < 1000 then
        return string.format("%.2f%%", pct)
    else
        local formatted = ProgAPI.FormatNumber(pct)
        return formatted:upper() .. "%"
    end
end

function ProgAPI.FormatHatchChance(val: number?): string
    if not val or val ~= val then return "0%" end
    if val >= 1 then
        return string.format("%.1f%%", val)
    elseif val >= 0.01 then
        return string.format("%.3f%%", val)
    elseif val >= 0.0001 then
        return string.format("%.5f%%", val)
    else
        return string.format("%.7f%%", val)
    end
end

function ProgAPI.GetEggDropChancesSummary(eggId: string?): string
    local targetEgg = eggId or ProgAPI.SelectedEgg or "MatrixEgg"
    local eggData = Directory.Eggs and Directory.Eggs[targetEgg]
    if not eggData or not eggData.Pets then
        return "N/A"
    end

    local rareItems = {}
    for _, p in ipairs(eggData.Pets) do
        local petId = p.Value
        local petDef = Directory.Pets and Directory.Pets[petId]
        local rarity = (petDef and petDef.Rarity) or "Unknown"
        local name = (petDef and (petDef.Name or petDef.DisplayName)) or petId
        local chance = nil
        pcall(function()
            if EggsFrontend and EggsFrontend.GetPetChance then
                chance = EggsFrontend.GetPetChance(targetEgg, petId)
            end
        end)
        if not chance then
            chance = p.Weight or 0
        end

        if rarity == "Mythical" or rarity == "Mythic" or rarity == "Secret" or rarity == "Mega" or rarity == "Divine" or rarity == "Exclusive" then
            table.insert(rareItems, {
                Name = name,
                Rarity = rarity,
                Chance = chance,
            })
        end
    end

    if #rareItems == 0 then
        return "Common / Standard Egg"
    end

    table.sort(rareItems, function(a, b)
        local orderA = (Constants.RarityOrder and Constants.RarityOrder[a.Rarity]) or 0
        local orderB = (Constants.RarityOrder and Constants.RarityOrder[b.Rarity]) or 0
        if orderA ~= orderB then
            return orderA < orderB
        end
        return a.Chance > b.Chance
    end)

    local parts = {}
    for i = 1, math.min(3, #rareItems) do
        local item = rareItems[i]
        local chanceStr = ProgAPI.FormatHatchChance(item.Chance)
        table.insert(parts, string.format("%s: %s", item.Name, chanceStr))
    end

    return table.concat(parts, " • ")
end

function ProgAPI.SendHatchWebhook(eggName: string, pet: any, petDef: any): boolean
    local url = ProgAPI.WebhookUrl
    if not url or url == "" then return false end
    if not (url:find("discord.com/api/webhooks") or url:find("discordapp.com/api/webhooks")) then
        return false
    end

    local httpReq = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    if not httpReq then return false end

    local petName = (petDef and (petDef.Name or petDef.DisplayName)) or pet.PetId or pet.petId or "Unknown Pet"
    local rarity = (petDef and petDef.Rarity) or (pet.isSecret and "Secret") or "Ultra Rare"
    local variant = pet.Variant or pet.variant or "Normal"
    local isShiny = (pet.IsShiny == true or pet.isShiny == true)

    local chanceStr = "N/A"
    pcall(function()
        if EggsFrontend and EggsFrontend.GetPetChance then
            local rawChance = EggsFrontend.GetPetChance(eggName, pet.PetId or pet.petId)
            if rawChance then
                chanceStr = ProgAPI.FormatHatchChance(rawChance)
            end
        end
    end)

    local embedColor = 0xF59E0B
    if rarity == "Secret" then
        embedColor = 0x9333EA
    elseif rarity == "Mega" then
        embedColor = 0xEF4444
    elseif rarity == "Divine" then
        embedColor = 0x06B6D4
    elseif rarity == "Exclusive" then
        embedColor = 0x3B82F6
    end

    local payload = {
        username = "Clicker Hub • Auto Progression",
        avatar_url = "https://i.imgur.com/8Q5FqWl.png",
        embeds = {
            {
                title = "🎉 ULTRA RARE PET HATCHED! 🎉",
                description = string.format("**%s** just hatched a rare **%s** pet!", LocalPlayer.Name, rarity),
                color = embedColor,
                fields = {
                    { name = "👤 Player", value = LocalPlayer.Name, inline = true },
                    { name = "🐾 Pet", value = petName, inline = true },
                    { name = "✨ Rarity", value = rarity, inline = true },
                    { name = "🧬 Variant", value = variant, inline = true },
                    { name = "⭐ Shiny", value = isShiny and "Yes ⭐" or "No", inline = true },
                    { name = "🥚 Egg", value = eggName or "Unknown", inline = true },
                    { name = "🎲 Hatch Chance", value = chanceStr, inline = true },
                    { name = "📊 Eggs Hatched (Session)", value = ProgAPI.FormatNumber(ProgAPI.SessionStats.Eggs), inline = true },
                    { name = "⏱️ Session Time", value = ProgAPI.FormatSessionTime(), inline = true },
                },
                footer = { text = "Clicker Hub • Clicker Simulator Auto Progression" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
        }
    }

    local ok, res = pcall(function()
        return httpReq({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return ok
end

function ProgAPI.SendTestWebhook(): (boolean, string)
    local url = ProgAPI.WebhookUrl
    if not url or url == "" then
        return false, "Webhook URL is empty! Please enter your Discord Webhook URL first."
    end
    if not (url:find("discord.com/api/webhooks") or url:find("discordapp.com/api/webhooks")) then
        return false, "Invalid URL! Must start with https://discord.com/api/webhooks/..."
    end

    local httpReq = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    if not httpReq then
        return false, "No HTTP request function available on executor."
    end

    local payload = {
        username = "Clicker Hub • Auto Progression",
        avatar_url = "https://i.imgur.com/8Q5FqWl.png",
        embeds = {
            {
                title = "🔔 DISCORD WEBHOOK TEST NOTIFICATION",
                description = "Your Discord Webhook is successfully connected to **Clicker Hub**! You will receive notifications when a **Secret, Mega, Divine, or Exclusive** pet is hatched.",
                color = 0x22C55E,
                fields = {
                    { name = "👤 Player", value = LocalPlayer.Name, inline = true },
                    { name = "🐾 Sample Pet", value = "Neo (Secret)", inline = true },
                    { name = "✨ Filter Rule", value = "Secret & Above ONLY (Mythics ignored)", inline = false },
                    { name = "🥚 Sample Egg", value = "Matrix Egg", inline = true },
                    { name = "⏱️ Session Time", value = ProgAPI.FormatSessionTime(), inline = true },
                    { name = "📊 Eggs Hatched", value = ProgAPI.FormatNumber(ProgAPI.SessionStats.Eggs), inline = true },
                },
                footer = { text = "Clicker Hub • Discord Webhook Integration" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
        }
    }

    local ok, res = pcall(function()
        return httpReq({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if ok then
        return true, "Test webhook sent successfully! Check your Discord channel."
    else
        return false, "Failed to send: " .. tostring(res)
    end
end

-- Setup background egg hatch event listener
local function setupHatchTracker()
    if _G.__ProgAPI_HatchConn then
        pcall(function() _G.__ProgAPI_HatchConn:Disconnect() end)
        _G.__ProgAPI_HatchConn = nil
    end

    local eggChannel = Channels.Egg
    if not eggChannel then return end

    local ok, sig = pcall(function()
        return eggChannel.OnClientEvent("HatchedBatch")
    end)
    if not ok or not sig then return end

    _G.__ProgAPI_HatchConn = sig:Connect(function(eggName, petList, batchId)
        if type(petList) ~= "table" then return end
        local count = #petList
        ProgAPI.SessionStats.Eggs = ProgAPI.SessionStats.Eggs + count
        ProgAPI.SelectedEgg = eggName

        for _, pet in ipairs(petList) do
            local petId = pet.PetId or pet.petId
            local petDef = Directory.Pets and Directory.Pets[petId]
            local rarity = (petDef and petDef.Rarity) or "Unknown"
            local rarityOrder = (Constants.RarityOrder and Constants.RarityOrder[rarity]) or 0
            local isSecret = pet.isSecret == true or pet.IsSecret == true or rarity == "Secret" or rarity == "Divine" or rarity == "Mega"

            if rarity == "Mythical" or rarity == "Mythic" then
                ProgAPI.SessionStats.Mythicals = ProgAPI.SessionStats.Mythicals + 1
            elseif rarity == "Secret" or isSecret then
                ProgAPI.SessionStats.Secrets = ProgAPI.SessionStats.Secrets + 1
            end
            if rarity == "Mega" or pet.isMega == true then
                ProgAPI.SessionStats.Megas = ProgAPI.SessionStats.Megas + 1
            end

            -- STRICT RULE: ONLY Secret or above! NEVER send for Mythic / Mythical!
            local isAboveMythic = (rarityOrder > 5 or isSecret) and (rarity ~= "Mythical" and rarity ~= "Mythic")
            if isAboveMythic and ProgAPI.WebhookEnabled and ProgAPI.WebhookUrl and ProgAPI.WebhookUrl ~= "" then
                task.spawn(function()
                    ProgAPI.SendHatchWebhook(eggName, pet, petDef)
                end)
            end
        end
    end)
end
pcall(setupHatchTracker)

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

-- Helper function to check if player has a Next Rebirth milestone button pending
-- (Matches game UI: "Goal" frame is visible in QuickRebirth, showing next milestone button and progress bar)
function ProgAPI.HasNextRebirthGoal(): boolean
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local qr = pg and pg:FindFirstChild("Main", true) and pg.Main:FindFirstChild("Left") and pg.Main.Left:FindFirstChild("QuickRebirth")
    local goal = qr and qr:FindFirstChild("Goal")
    if goal and goal.Visible == true then
        return true
    end

    -- Mathematical verification: If current best affordable button is less than the highest owned button
    local info = ProgAPI.GetMaxRebirthInfo()
    if info and info.BestAffordableIndex and info.MaxButtonIndex then
        if info.BestAffordableIndex < info.MaxButtonIndex then
            return true
        end
    end

    return false
end

-- Executes highest affordable rebirth milestone button directly
-- Strictly follows user rule: ONLY rebirths when player has reached the MAX milestone (no more Next Rebirth button)
-- If there is a Next Rebirth button pending (Image 2), it waits until that milestone is reached!
function ProgAPI.RebirthMaxTarget(): (boolean, any)
    local info = ProgAPI.GetMaxRebirthInfo()
    if info.CanAffordMax and info.BestAffordableIndex then
        -- Must be at the absolute max milestone button owned
        if info.BestAffordableIndex < info.MaxButtonIndex then
            return false, "Waiting to reach maximum milestone button index..."
        end

        -- 1. Direct channel fire to active max affordable button index
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

-- Phase 1 & 2 Dedicated Rebirth: Rebirths at the highest affordable button as soon as affordable!
-- Strictly follows user rule: Does NOT wait for Goal or button 57, rebirths immediately as long as affordable!
function ProgAPI.RebirthBestAffordable(): (boolean, any)
    local info = ProgAPI.GetMaxRebirthInfo()
    if info.CanAffordMax and info.BestAffordableIndex then
        local btnIdx = info.BestAffordableIndex

        -- 1. Direct channel fire to active best affordable button index
        if Channels.Rebirths then
            Channels.Rebirths:FireServer("Rebirth", btnIdx)
        end

        -- 2. Notify AutoRebirthFrontend
        if AutoRebirthFrontend then
            pcall(function()
                AutoRebirthFrontend.SetSelectedButtonIndex(btnIdx)
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
    ProgAPI.ExitMinigame()

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    if worldName == "Techworld" or worldName == "Tech" or worldName == "Space" then
        if curWorld == "Techworld" or curWorld == "Space" then
            return true
        end

        if Channels.Portals then
            local ok, res = pcall(function()
                return Channels.Portals:InvokeServer("TeleportToWorld", "Techworld")
            end)
            if ok and res == true then
                task.wait(0.5)
                return true
            end
        end

        local ok, msg = ProgAPI.CheckAndEnterTechWorld()
        if ok then return true end

        if Channels.Portals then
            local ok2, res2 = pcall(function()
                return Channels.Portals:InvokeServer("TeleportToIsland", "Matrix")
            end)
            if ok2 and res2 == true then return true end
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToIsland", "Base")
            end)
        end
        return true
    elseif worldName == "Overworld" then
        if curWorld == "Overworld" then
            return true
        end
        if Channels.Portals then
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToWorld", "Overworld")
            end)
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToIsland", "Spawn")
            end)
        end
        return true
    end
    return false
end

function ProgAPI.TeleportToIsland(islandName: string): boolean
    if islandName == "DominusArea" or islandName == "Dominus" then
        if not ProgAPI.IsInMinigame("DominusArea") then
            local MF = MinigamesFrontend or (Client and Client:FindFirstChild("MinigamesFrontend") and require(Client.MinigamesFrontend))
            if MF and MF.Enter then
                pcall(function() MF.Enter("DominusArea") end)
                task.wait(0.35)
            end
        end
        return true
    else
        ProgAPI.ExitMinigame()
    end

    local meta = islandMetaLookup[islandName]
    local targetWorld = meta and meta.world or "Overworld"
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    -- 1. Switch world if targeting island in another world
    if targetWorld ~= curWorld then
        if targetWorld == "Techworld" then
            ProgAPI.TeleportToWorld("Techworld")
            task.wait(0.4)
        elseif targetWorld == "Overworld" then
            ProgAPI.TeleportToWorld("Overworld")
            task.wait(0.4)
        end
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

    -- 3. Instant client local teleport (only if in same world!)
    stats = Stats.Local(true) or {}
    curWorld = stats.CurrentWorld or "Overworld"
    if targetWorld == curWorld and IslandsFrontend and IslandsFrontend.LocalTeleport then
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
    local curWorld = stats.CurrentWorld or "Overworld"
    local allIslands = ProgAPI.AreAllIslandsUnlocked()
    local isTechWorld = (curWorld == "Techworld" or curWorld == "Space")

    local bestEggName = nil
    local bestCost = 0

    for eggName, meta in pairs(eggData) do
        local isEvent = (eggName == "CandyCornEgg" or eggName == "SixSevenEgg")
        local isIslandAvailable = ProgAPI.IsIslandUnlocked(meta.island) or (meta.island == "Spawn")

        -- If player is in Tech World, strictly filter to Tech World eggs! Never select Spawn/Overworld eggs!
        local isWorldAllowed = true
        if isTechWorld then
            isWorldAllowed = (meta.island == "Matrix" or meta.island == "Fragment" or meta.island == "Spaceship" or meta.island == "Base")
        end

        if isIslandAvailable and isWorldAllowed and meta.cost <= clicks then
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

    -- 3. Fallback: ONLY for brand new players on Spawn with zero unlocked islands!
    if not bestEggName and not isTechWorld and not allIslands and not ProgAPI.IsIslandUnlocked("Winter") and clicks >= 250 then
        bestEggName = "BasicEgg"
        bestCost = 250
    end

    if not bestEggName then
        return nil
    end

    return {
        name = bestEggName,
        cost = bestCost,
        island = eggData[bestEggName] and eggData[bestEggName].island or "Spawn"
    }
end

-- Selects the absolute highest affordable endgame egg in Tech World (or high Overworld)
-- NEVER falls back to BasicEgg/Spawn in Phase 2!
function ProgAPI.GetEndgameEgg()
    local pData = ProgAPI.GetPlayerData()
    local clicks = pData.Clicks or 0

    local techEggs = {
        { name = "MatrixEgg", cost = 2.5e25, island = "Matrix" },
        { name = "FragmentedEgg", cost = 5e24, island = "Fragment" },
        { name = "RedTechEgg", cost = 1e24, island = "Matrix" },
        { name = "404Egg", cost = 5e23, island = "Fragment" },
        { name = "HolographicEgg", cost = 1.5e23, island = "Spaceship" },
        { name = "TechEgg", cost = 4.5e22, island = "Base" },
    }

    for _, e in ipairs(techEggs) do
        if ProgAPI.IsIslandUnlocked(e.island) and clicks >= e.cost then
            return e
        end
    end

    local overworldEggs = {
        { name = "DemonicEgg", cost = 1.5e22, island = "Hell" },
        { name = "RockEgg", cost = 1e21, island = "Mystical" },
        { name = "CursedEgg", cost = 1.5e20, island = "Mystical" },
        { name = "CastleEgg", cost = 5e19, island = "Castle" },
        { name = "AngelEgg", cost = 4e18, island = "Heaven" },
        { name = "DiscoEgg", cost = 2e17, island = "Rave" },
        { name = "VolcanoEgg", cost = 1e16, island = "Volcano" },
    }

    for _, e in ipairs(overworldEggs) do
        if ProgAPI.IsIslandUnlocked(e.island) and clicks >= e.cost then
            return e
        end
    end

    return nil
end

function ProgAPI.TeleportToEgg(eggName: string): boolean
    local eggMeta = eggData[eggName]
    local island = eggMeta and eggMeta.island or "Spawn"
    local meta = islandMetaLookup[island]
    local targetWorld = (meta and meta.world) or "Overworld"

    -- 1. Exit any active minigame (DominusArea, Raids, etc.)
    ProgAPI.ExitMinigame()

    -- 2. Switch world if needed (e.g. Overworld <-> Techworld)
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"
    if targetWorld ~= curWorld and Channels.Portals then
        pcall(function() Channels.Portals:InvokeServer("TeleportToWorld", targetWorld) end)
        task.wait(0.6)
    end

    -- 3. Teleport to the target island
    ProgAPI.TeleportToIsland(island)
    task.wait(0.35)

    -- 4. Find the egg model and stand directly on it (with streaming retry)
    local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not targetPart or not hrp then
        for _ = 1, 5 do
            task.wait(0.2)
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            eggModel, targetPart = ProgAPI.FindEggModel(eggName)
            if hrp and targetPart then break end
        end
    end

    if hrp and targetPart then
        hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.15)
        return true
    end

    -- Fallback for MatrixEgg: known position
    if eggName == "MatrixEgg" and hrp then
        hrp.CFrame = CFrame.new(7828.7, 6196.1, 303.1)
        return true
    end

    return false
end

-- Calculates dynamic egg hatching animation & cooldown speed matching game engine profile (4.2 / multiplier)
function ProgAPI.GetPlayerHatchSpeed(): number
    local mult = 1
    if EggsFrontend and EggsFrontend.GetHatchSpeedMultiplier then
        local ok, m = pcall(EggsFrontend.GetHatchSpeedMultiplier)
        if ok and type(m) == "number" and m > 0 then
            mult = m
        end
    end
    return math.clamp(4.2 / mult, 0.05, 10.0)
end

function ProgAPI.FormatHatchSpeed(): string
    local speed = ProgAPI.GetPlayerHatchSpeed()
    return string.format("%.1fs", speed)
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
    if not eggName or eggName == "" then return false, "No egg specified" end
    ProgAPI.SelectedEgg = eggName

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    -- Strict Safety Guard: Never open BasicEgg if in Tech World, or all islands unlocked, or past Spawn!
    if eggName == "BasicEgg" and (curWorld == "Techworld" or curWorld == "Space" or ProgAPI.AreAllIslandsUnlocked() or ProgAPI.IsIslandUnlocked("Winter")) then
        return false, "Blocked opening BasicEgg on advanced progression"
    end

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

-- Single source of truth validator for Mythic and above pets
-- Strictly identifies and protects Mythic, Mythical, Special, Mega, Secret, Divine, and Exclusive pets
-- Returns TRUE to protect the pet from any deletion/selling routines
function ProgAPI.IsMythicOrAbove(p: any): boolean
    if not p then return false end

    local pId = (type(p) == "table" and (p.id or p.Id or p.Name)) or p
    local directRarity = type(p) == "table" and (p.rarity or p.Rarity)

    local meta = nil
    if Directory and Directory.Pets then
        meta = Directory.Pets[pId] or Directory.Pets[tostring(pId)]
        if not meta and type(pId) == "string" then
            for id, data in pairs(Directory.Pets) do
                if tostring(id):lower() == pId:lower() then
                    meta = data
                    break
                end
            end
        end
    end

    local r = (meta and meta.Rarity) or directRarity
    if not r then
        -- Safety safeguard: If rarity cannot be determined, treat as protected so we NEVER delete unknown pets
        return true
    end

    -- Official game Constants.RarityOrder check:
    -- Basic (1), Rare (2), Epic (3), Legendary (4) < 5
    -- Mythical/Mythic (5), Exclusive (6), Special (6), Secret (7), Divine (8), Mega (9) >= 5
    if Constants and Constants.RarityOrder and Constants.RarityOrder[r] then
        if Constants.RarityOrder[r] >= 5 then
            return true
        end
    end

    local rLower = tostring(r):lower()
    if rLower:find("mythic") or rLower:find("mythical") or rLower:find("secret")
       or rLower:find("divine") or rLower:find("mega") or rLower:find("special")
       or rLower:find("exclusive") then
        return true
    end

    return false
end

-- Weak pet deletion: If highest unlocked island is N, delete all normal pets from world (N - 2) and below
function ProgAPI.CleanWeakPets(protectCrafting: boolean?): number
    if ProgAPI.IsPhase3 and ProgAPI.IsPhase3() then
        return ProgAPI.CleanNonMythicPets()
    end
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
            -- ABSOLUTE SAFETY: Strictly NEVER delete Mythic or above pets!
            local isMythicOrAbove = ProgAPI.IsMythicOrAbove(p)
            local isShiny = (p.Shiny or p.s or false)
            local isVariant = (p.v == "Golden" or p.v == "Rainbow" or p.v == "DarkMatter")

            if not isMythicOrAbove and not isShiny and not isVariant then
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

    local techDone = (techBought >= 13) or (techTotal > 0 and techBought >= techTotal)
    local coinsDone = (coinsBought >= 36) or (coinsTotal > 0 and coinsBought >= coinsTotal)

    return {
        TechTotal = techTotal,
        TechBought = techBought,
        TechRemaining = math.max(0, techDone and 0 or (techTotal - techBought)),
        TechComplete = techDone,
        CoinsTotal = coinsTotal,
        CoinsBought = coinsBought,
        CoinsRemaining = math.max(0, coinsDone and 0 or (coinsTotal - coinsBought)),
        CoinsComplete = coinsDone,
        AllComplete = techDone and coinsDone,
        UserSkills = stats.SkillTree or {}
    }
end

local currentCoinsIsland = "Heaven"
local currentTechIsland = "Matrix"
local dominusEmptyStartTick = 0

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
    local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))

    -- When Coins skill tree is done, tp to Tech World after!
    if stProg.CoinsComplete then
        if ProgAPI.IsInMinigame() then
            ProgAPI.ExitMinigame()
            task.wait(0.35)
        end
        local curStats = Stats.Local(true) or {}
        local curWorld = curStats.CurrentWorld or "Overworld"
        if curWorld ~= "Techworld" and curWorld ~= "Space" then
            ProgAPI.TeleportToWorld("Techworld")
            task.wait(0.5)
        end
        targetWorld = ProgAPI.GetBestBreakableIsland("Auto (Dynamic Smart)", false) or "Matrix"
    end

    -- Minigame handling for DominusArea (the ??? area)
    if targetWorld == "DominusArea" then
        if not ProgAPI.IsInMinigame("DominusArea") then
            if MF and MF.Enter then pcall(function() MF.Enter("DominusArea") end) end
            task.wait(0.35)
        end

        -- Check if breakables have spawned in DominusArea. If not, tp to Spawn and re-enter!
        local curCount = ProgAPI.GetActiveIslandBreakablesCount("DominusArea", false)
        if curCount == 0 then
            if dominusEmptyStartTick == 0 then
                dominusEmptyStartTick = tick()
            elseif (tick() - dominusEmptyStartTick) > 2.0 then
                dominusEmptyStartTick = tick()
                ProgAPI.ExitMinigame()
                ProgAPI.TeleportToIsland("Spawn")
                task.wait(0.6)
                if MF and MF.Enter then pcall(function() MF.Enter("DominusArea") end) end
                task.wait(0.5)
                return "Respawning ??? Breakables via Spawn...", "DominusArea"
            end
            return "Waiting for ??? Breakables spawn...", "DominusArea"
        else
            dominusEmptyStartTick = 0
        end
    else
        if ProgAPI.IsInMinigame("DominusArea") or ProgAPI.IsInMinigame() then
            ProgAPI.ExitMinigame()
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

    -- If no attack on current island, handle empty breakables
    if not okAtk then
        if targetWorld == "DominusArea" then
            if dominusEmptyStartTick == 0 then
                dominusEmptyStartTick = tick()
            elseif (tick() - dominusEmptyStartTick) > 2.0 then
                dominusEmptyStartTick = tick()
                if MF and MF.Exit then pcall(MF.Exit) end
                ProgAPI.TeleportToIsland("Spawn")
                task.wait(0.6)
                if MF and MF.Enter then pcall(function() MF.Enter("DominusArea") end) end
                task.wait(0.5)
                return "Respawning ??? Breakables via Spawn...", "DominusArea"
            end
            return "Waiting for ??? Breakables respawn...", "DominusArea"
        elseif not stProg.CoinsComplete then
            local curCount = ProgAPI.GetActiveIslandBreakablesCount(targetWorld, attackBigChests)
            if curCount == 0 then
                local altIsland = (targetWorld == "Heaven") and "Volcano" or "Heaven"
                local altCount = ProgAPI.GetActiveIslandBreakablesCount(altIsland, attackBigChests)
                if altCount > 0 then
                    targetWorld = altIsland
                    ProgAPI.TeleportToIsland(altIsland)
                    task.wait(0.35)
                    ProgAPI.TeleportToBreakableZone(altIsland, ignoreBoss)
                    return "Cleared arena! Teleporting to " .. tostring(altIsland), tostring(altIsland)
                end
            end
            return "Waiting for breakables respawn in " .. tostring(targetWorld), tostring(targetWorld)
        else
            return "Waiting for Tech breakables respawn in " .. tostring(targetWorld), tostring(targetWorld)
        end
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
-- PHASE 3: ENDGAME MATRIX MYTHIC PIPELINE
-- Activates once Phase 2 (Desert Machine & Skill Tree) is 100% complete!
--==============================================================================
function ProgAPI.IsPhase3(): boolean
    local allIslands = ProgAPI.AreAllIslandsUnlocked()
    if not allIslands then return false end
    local stProg = ProgAPI.GetSkillTreeProgress()
    local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 36)
    local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
    return (coinsDone and techDone) == true
end

-- Phase 3 Dedicated Mythic Filter: Keeps ONLY Mythic and above pets!
-- Strictly preserves Mythic, Mythical, Special, Mega, Secret, Divine, and Exclusive pets
-- Deletes all non-mythic pets (Basic, Rare, Epic, Legendary, Stock)
function ProgAPI.CleanNonMythicPets(): number
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local toDelete = {}
    for guid, p in pairs(pets) do
        -- Never delete currently equipped pets or locked pets
        if not equipped[guid] and not p.Locked and not p.l then
            -- Strictly keep ALL Mythic and above pets!
            local isMythicOrAbove = ProgAPI.IsMythicOrAbove(p)

            -- If it is NOT a Mythic or above, delete it!
            if not isMythicOrAbove then
                table.insert(toDelete, guid)
            end
        end
    end

    local deletedCount = 0
    if #toDelete > 0 and Channels.Pets then
        for i = 1, #toDelete, 50 do
            local batch = {}
            for j = i, math.min(i + 49, #toDelete) do
                table.insert(batch, toDelete[j])
            end
            pcall(function()
                Channels.Pets:FireServer("DeletePetsBulk", batch)
            end)
            deletedCount = deletedCount + #batch
            task.wait(0.08)
        end
    end
    return deletedCount
end

-- Checks if entire equipped team is 100% Rainbow Mythics
function ProgAPI.IsEquippedTeamAllRainbowMythic(): (boolean, number, number)
    local stats = Stats.Local(true) or {}
    local equipped = stats.EquippedPets or {}
    local total = 0
    local mythicCount = 0

    for guid, _ in pairs(equipped) do
        total = total + 1
        local pInfo = (stats.Pets and stats.Pets[guid]) or (stats.EquippedPets and stats.EquippedPets[guid])
        if pInfo then
            local isMythic = ProgAPI.IsMythicOrAbove(pInfo)
            local isRainbow = (pInfo.v == "Rainbow" or pInfo.Variant == "Rainbow" or pInfo.Rainbow == true)
            if isMythic and isRainbow then
                mythicCount = mythicCount + 1
            end
        end
    end

    return (total > 0 and mythicCount == total), mythicCount, total
end

-- Backward compatibility stub
function ProgAPI.GetSecretQuestProgress()
    return { DoorUnlocked = true, QuestClaimed = true }
end

function ProgAPI.StepSecretQuest(): (boolean, string)
    return true, "??? Quest completed and bypassed for Phase 3"
end

--==============================================================================
-- PERFORMANCE & MISC OPTIMIZATIONS (Black Screen 3D Render & Remove Maps)
--==============================================================================
local blackScreenGui = nil
local savedGuiStates = {}
local blackScreenInputConn = nil
local blackScreenRefreshTask = nil
local blackScreenRowLabels = {}
local originalTransparencies = {}
local isMapsRemoved = false

ProgAPI.OnBlackScreenToggled = nil

local function updateBlackScreenTelemetry()
    if not blackScreenGui or not blackScreenGui.Enabled then return end
    local pData = ProgAPI.GetPlayerData()
    local curPets = 0
    local maxPets = 0
    pcall(function()
        local Pets = require(Client:WaitForChild("Pets", 2))
        if Pets and Pets.GetInventoryCount then
            curPets = Pets.GetInventoryCount()
        end
        if Pets and Pets.GetEffectiveMaxInventoryPets then
            maxPets = Pets.GetEffectiveMaxInventoryPets()
        end
    end)

    local eggName = ProgAPI.SelectedEgg or "MatrixEgg"
    local eggData = Directory.Eggs and Directory.Eggs[eggName]
    local eggDispName = (eggData and (eggData.Name or eggData.DisplayName)) or eggName
    local eggCost = 0
    local eggCurr = (eggData and eggData.Info and eggData.Info.Currency) or "Clicks"
    pcall(function()
        if EggsFrontend and EggsFrontend.GetEggCost then
            eggCost = EggsFrontend.GetEggCost(eggName)
        end
    end)

    local luckMult = ProgAPI.GetCurrentEggLuckMultiplier()

    pcall(function()
        if blackScreenRowLabels.Clicks then blackScreenRowLabels.Clicks.Text = ProgAPI.FormatNumber(pData.Clicks) end
        if blackScreenRowLabels.Rebirths then blackScreenRowLabels.Rebirths.Text = ProgAPI.FormatNumber(pData.Rebirths) end
        if blackScreenRowLabels.Gems then blackScreenRowLabels.Gems.Text = ProgAPI.FormatNumber(pData.Gems) end
        if blackScreenRowLabels.World then blackScreenRowLabels.World.Text = tostring(pData.CurrentWorld or "Overworld") end
        if blackScreenRowLabels.Island then blackScreenRowLabels.Island.Text = tostring(pData.CurrentIsland or "Spawn") end
        if blackScreenRowLabels.PetInv then blackScreenRowLabels.PetInv.Text = string.format("%d / %d", curPets, maxPets) end
        if blackScreenRowLabels.SelectedEgg then
            blackScreenRowLabels.SelectedEgg.Text = string.format("%s (%s %s)", eggDispName, ProgAPI.FormatNumber(eggCost), eggCurr)
        end
        if blackScreenRowLabels.EggLuck then
            local speedText = ProgAPI.FormatHatchSpeed and ProgAPI.FormatHatchSpeed() or "2.7s"
            blackScreenRowLabels.EggLuck.Text = string.format("%s (Hatch: %s)", ProgAPI.FormatLuck(luckMult), speedText)
        end
        if blackScreenRowLabels.Activity then blackScreenRowLabels.Activity.Text = tostring(ProgAPI.CurrentActivity or "Auto Progression Active") end
        if blackScreenRowLabels.Chances then blackScreenRowLabels.Chances.Text = ProgAPI.GetEggDropChancesSummary(eggName) end

        if blackScreenRowLabels.EggsHatched then blackScreenRowLabels.EggsHatched.Text = tostring(ProgAPI.SessionStats.Eggs) end
        if blackScreenRowLabels.Mythicals then blackScreenRowLabels.Mythicals.Text = tostring(ProgAPI.SessionStats.Mythicals) end
        if blackScreenRowLabels.Secrets then blackScreenRowLabels.Secrets.Text = tostring(ProgAPI.SessionStats.Secrets) end
        if blackScreenRowLabels.Megas then blackScreenRowLabels.Megas.Text = tostring(ProgAPI.SessionStats.Megas) end
        if blackScreenRowLabels.SessionTime then blackScreenRowLabels.SessionTime.Text = ProgAPI.FormatSessionTime() end

        if _G.__ProgAPI_BlackScreenWebhookBox and not _G.__ProgAPI_BlackScreenWebhookBox:IsFocused() then
            local curUrl = ProgAPI.WebhookUrl or ""
            if _G.__ProgAPI_BlackScreenWebhookBox.Text ~= curUrl and curUrl ~= "" then
                _G.__ProgAPI_BlackScreenWebhookBox.Text = curUrl
            end
        end
    end)
end

function ProgAPI.SetBlackScreen(enabled: boolean)
    pcall(function()
        local RunService = game:GetService("RunService")
        if RunService and RunService.Set3dRenderingEnabled then
            RunService:Set3dRenderingEnabled(not enabled)
        end
    end)

    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    local targetParent = pg

    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then
                local test = Instance.new("Folder")
                test.Parent = h
                test:Destroy()
                targetParent = h
            end
        end
    end)
    if not targetParent then targetParent = pg end

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
            if not targetParent and not pg then return end

            pcall(function()
                if targetParent then
                    for _, ch in ipairs(targetParent:GetChildren()) do
                        if ch.Name == "ClickerHub_BlackScreen" and ch ~= blackScreenGui then
                            ch:Destroy()
                        end
                    end
                end
                if pg and pg ~= targetParent then
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
            card.Name = "CardFrame"
            card.Size = UDim2.new(0, 470, 0, 555)
            card.AnchorPoint = Vector2.new(0.5, 0.5)
            card.Position = UDim2.new(0.5, 0, 0.5, 0)
            card.BackgroundColor3 = Color3.fromRGB(11, 14, 21)
            card.BorderSizePixel = 0
            card.Parent = bg

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 14)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = Color3.fromRGB(37, 99, 235)
            cardStroke.Thickness = 1.5
            cardStroke.Transparency = 0
            cardStroke.Parent = card

            local title = Instance.new("TextLabel")
            title.Text = "CLICKER HUB • CLICKER SIMULATOR"
            title.Font = Enum.Font.GothamBold
            title.TextSize = 17
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Position = UDim2.new(0, 22, 0, 18)
            title.Size = UDim2.new(1, -44, 0, 22)
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.BackgroundTransparency = 1
            title.Parent = card

            local sub = Instance.new("TextLabel")
            sub.Text = "3D rendering disabled • Session statistics"
            sub.Font = Enum.Font.Gotham
            sub.TextSize = 12
            sub.TextColor3 = Color3.fromRGB(115, 135, 165)
            sub.Position = UDim2.new(0, 22, 0, 42)
            sub.Size = UDim2.new(1, -44, 0, 16)
            sub.TextXAlignment = Enum.TextXAlignment.Left
            sub.BackgroundTransparency = 1
            sub.Parent = card

            local divider = Instance.new("Frame")
            divider.Position = UDim2.new(0, 22, 0, 66)
            divider.Size = UDim2.new(1, -44, 0, 1)
            divider.BackgroundColor3 = Color3.fromRGB(25, 33, 48)
            divider.BorderSizePixel = 0
            divider.Parent = card

            local container = Instance.new("Frame")
            container.Name = "RowsContainer"
            container.Position = UDim2.new(0, 22, 0, 76)
            container.Size = UDim2.new(1, -44, 0, 380)
            container.BackgroundTransparency = 1
            container.Parent = card

            local function addRow(lblText, defaultVal, yPos, key)
                local rowFrame = Instance.new("Frame")
                rowFrame.Size = UDim2.new(1, 0, 0, 20)
                rowFrame.Position = UDim2.new(0, 0, 0, yPos)
                rowFrame.BackgroundTransparency = 1
                rowFrame.Parent = container

                local lbl = Instance.new("TextLabel")
                lbl.Text = lblText
                lbl.Font = Enum.Font.RobotoMono
                lbl.TextSize = 12.5
                lbl.TextColor3 = Color3.fromRGB(235, 240, 250)
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Size = UDim2.new(0, 175, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Parent = rowFrame

                local val = Instance.new("TextLabel")
                val.Name = "Value_" .. (key or lblText)
                val.Text = defaultVal
                val.Font = Enum.Font.RobotoMono
                val.TextSize = 12.5
                val.TextColor3 = Color3.fromRGB(215, 220, 235)
                val.TextXAlignment = Enum.TextXAlignment.Left
                val.Position = UDim2.new(0, 178, 0, 0)
                val.Size = UDim2.new(1, -178, 1, 0)
                val.TextTruncate = Enum.TextTruncate.AtEnd
                val.BackgroundTransparency = 1
                val.Parent = rowFrame

                return val
            end

            -- Live initial data pre-fetch so UI renders with actual numbers instantly
            local pData = ProgAPI.GetPlayerData()
            local initPets = 0
            local initMaxPets = 0
            pcall(function()
                local Pets = require(Client:WaitForChild("Pets", 2))
                if Pets and Pets.GetInventoryCount then initPets = Pets.GetInventoryCount() end
                if Pets and Pets.GetEffectiveMaxInventoryPets then initMaxPets = Pets.GetEffectiveMaxInventoryPets() end
            end)

            local initEgg = ProgAPI.SelectedEgg or "MatrixEgg"
            local initEggData = Directory.Eggs and Directory.Eggs[initEgg]
            local initEggDisp = (initEggData and (initEggData.Name or initEggData.DisplayName)) or initEgg
            local initEggCost = 0
            local initEggCurr = (initEggData and initEggData.Info and initEggData.Info.Currency) or "Clicks"
            pcall(function()
                if EggsFrontend and EggsFrontend.GetEggCost then initEggCost = EggsFrontend.GetEggCost(initEgg) end
            end)

            local initLuck = ProgAPI.GetCurrentEggLuckMultiplier()
            local initChances = ProgAPI.GetEggDropChancesSummary(initEgg)

            blackScreenRowLabels = {}
            blackScreenRowLabels.Clicks = addRow("Clicks", ProgAPI.FormatNumber(pData.Clicks), 0, "Clicks")
            blackScreenRowLabels.Rebirths = addRow("Rebirths", ProgAPI.FormatNumber(pData.Rebirths), 20, "Rebirths")
            blackScreenRowLabels.Gems = addRow("Gems", ProgAPI.FormatNumber(pData.Gems), 40, "Gems")
            blackScreenRowLabels.World = addRow("World", tostring(pData.CurrentWorld or "Overworld"), 60, "World")
            blackScreenRowLabels.Island = addRow("Island", tostring(pData.CurrentIsland or "Spawn"), 80, "Island")
            blackScreenRowLabels.PetInv = addRow("Pet Inventory", string.format("%d / %d", initPets, initMaxPets), 100, "PetInv")
            blackScreenRowLabels.SelectedEgg = addRow("Selected Egg", string.format("%s (%s %s)", initEggDisp, ProgAPI.FormatNumber(initEggCost), initEggCurr), 120, "SelectedEgg")
            local initSpeed = ProgAPI.FormatHatchSpeed and ProgAPI.FormatHatchSpeed() or "2.7s"
            blackScreenRowLabels.EggLuck = addRow("Current Egg Luck", string.format("%s (Hatch: %s)", ProgAPI.FormatLuck(initLuck), initSpeed), 140, "EggLuck")

            blackScreenRowLabels.Activity = addRow("Current Activity", tostring(ProgAPI.CurrentActivity or "Auto Farm Active"), 168, "Activity")
            blackScreenRowLabels.Chances = addRow("Top Drop Chances", initChances, 188, "Chances")

            blackScreenRowLabels.EggsHatched = addRow("Eggs Hatched (Session)", tostring(ProgAPI.SessionStats.Eggs), 216, "EggsHatched")
            blackScreenRowLabels.Mythicals = addRow("Mythicals (Session)", tostring(ProgAPI.SessionStats.Mythicals), 236, "Mythicals")
            blackScreenRowLabels.Secrets = addRow("Secrets (Session)", tostring(ProgAPI.SessionStats.Secrets), 256, "Secrets")
            blackScreenRowLabels.Megas = addRow("Megas (Session)", tostring(ProgAPI.SessionStats.Megas), 276, "Megas")
            blackScreenRowLabels.SessionTime = addRow("Session Time", ProgAPI.FormatSessionTime(), 296, "SessionTime")

            _G.__ProgAPI_BlackScreenLabels = blackScreenRowLabels

            local webhookFrame = Instance.new("Frame")
            webhookFrame.Name = "WebhookFrame"
            webhookFrame.Position = UDim2.new(0, 22, 0, 404)
            webhookFrame.Size = UDim2.new(1, -44, 0, 52)
            webhookFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
            webhookFrame.BorderSizePixel = 0
            webhookFrame.Parent = card

            local wfCorner = Instance.new("UICorner")
            wfCorner.CornerRadius = UDim.new(0, 8)
            wfCorner.Parent = webhookFrame

            local wfStroke = Instance.new("UIStroke")
            wfStroke.Color = Color3.fromRGB(37, 99, 235)
            wfStroke.Thickness = 1
            wfStroke.Transparency = 0.5
            wfStroke.Parent = webhookFrame

            local wfTitle = Instance.new("TextLabel")
            wfTitle.Text = "DISCORD WEBHOOK (SECRET+ HATCH ALERTS)"
            wfTitle.Font = Enum.Font.GothamBold
            wfTitle.TextSize = 10
            wfTitle.TextColor3 = Color3.fromRGB(120, 140, 175)
            wfTitle.Position = UDim2.new(0, 10, 0, 5)
            wfTitle.Size = UDim2.new(1, -20, 0, 14)
            wfTitle.TextXAlignment = Enum.TextXAlignment.Left
            wfTitle.BackgroundTransparency = 1
            wfTitle.Parent = webhookFrame

            local webhookBox = Instance.new("TextBox")
            webhookBox.Name = "WebhookInput"
            webhookBox.Position = UDim2.new(0, 10, 0, 22)
            webhookBox.Size = UDim2.new(1, -20, 0, 24)
            webhookBox.BackgroundTransparency = 1
            webhookBox.Font = Enum.Font.RobotoMono
            webhookBox.TextSize = 11.5
            webhookBox.TextColor3 = Color3.fromRGB(240, 245, 255)
            webhookBox.PlaceholderColor3 = Color3.fromRGB(100, 115, 140)
            webhookBox.PlaceholderText = "Paste Discord Webhook URL here..."
            webhookBox.Text = ProgAPI.WebhookUrl or ""
            webhookBox.ClearTextOnFocus = false
            webhookBox.TextXAlignment = Enum.TextXAlignment.Left
            webhookBox.TextTruncate = Enum.TextTruncate.AtEnd
            webhookBox.Parent = webhookFrame

            local function saveWebhook(text)
                local clean = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                ProgAPI.WebhookUrl = clean
                pcall(function()
                    local Configs = loadfile and isfile and isfile("[AUTOPROG]/Configs.lua") and loadfile("[AUTOPROG]/Configs.lua")()
                    if Configs and Configs.Set then
                        Configs.Set("WebhookUrl", clean)
                        Configs.Save()
                    end
                end)
                pcall(function()
                    if _G.State then _G.State.WebhookUrl = clean end
                end)
            end

            webhookBox.FocusLost:Connect(function()
                saveWebhook(webhookBox.Text)
            end)

            _G.__ProgAPI_BlackScreenWebhookBox = webhookBox

            local restoreBtn = Instance.new("TextButton")
            restoreBtn.Name = "DisableBtn"
            restoreBtn.Position = UDim2.new(0, 22, 0, 466)
            restoreBtn.Size = UDim2.new(1, -44, 0, 40)
            restoreBtn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
            restoreBtn.BorderSizePixel = 0
            restoreBtn.Text = "Disable Black Screen"
            restoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            restoreBtn.TextSize = 14
            restoreBtn.Font = Enum.Font.GothamBold
            restoreBtn.AutoButtonColor = true
            restoreBtn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 10)
            btnCorner.Parent = restoreBtn

            restoreBtn.MouseButton1Click:Connect(function()
                ProgAPI.SetBlackScreen(false)
            end)

            local hint = Instance.new("TextLabel")
            hint.Position = UDim2.new(0, 22, 0, 514)
            hint.Size = UDim2.new(1, -44, 0, 18)
            hint.BackgroundTransparency = 1
            hint.Text = "Click button above or press RightControl to restore"
            hint.TextColor3 = Color3.fromRGB(115, 130, 155)
            hint.TextSize = 11
            hint.Font = Enum.Font.Gotham
            hint.TextXAlignment = Enum.TextXAlignment.Center
            hint.Parent = card

            local okParent = pcall(function()
                blackScreenGui.Parent = targetParent
            end)
            if not okParent and pg then
                pcall(function()
                    blackScreenGui.Parent = pg
                end)
            end
        end

        blackScreenGui.Enabled = true

        -- Start periodic telemetry refresh
        if blackScreenRefreshTask then
            pcall(function() task.cancel(blackScreenRefreshTask) end)
            blackScreenRefreshTask = nil
        end
        blackScreenRefreshTask = task.spawn(function()
            while blackScreenGui and blackScreenGui.Enabled and blackScreenGui.Parent do
                pcall(updateBlackScreenTelemetry)
                task.wait(0.8)
            end
        end)
        pcall(updateBlackScreenTelemetry)

        if not blackScreenInputConn then
            local UserInputService = game:GetService("UserInputService")
            blackScreenInputConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift then
                    ProgAPI.SetBlackScreen(false)
                end
            end)
        end
    else
        if blackScreenRefreshTask then
            pcall(function() task.cancel(blackScreenRefreshTask) end)
            blackScreenRefreshTask = nil
        end

        if blackScreenInputConn then
            blackScreenInputConn:Disconnect()
            blackScreenInputConn = nil
        end

        if blackScreenGui then
            pcall(function() blackScreenGui:Destroy() end)
            blackScreenGui = nil
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
