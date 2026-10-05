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
    ClickSkins = Network.Channel("ClickSkins"),
    Trading = Network.Channel("Trading"),
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

function ProgAPI.DetectGlobalWebhook(): string?
    local candidates = {
        (getgenv and type(getgenv) == "function" and getgenv()) or nil,
        _G,
        shared,
    }
    local keys = {"Webhook", "WebhookUrl", "webhook", "webhookurl", "WEBHOOK", "WEBHOOK_URL", "Webhook_Url"}
    for _, env in ipairs(candidates) do
        if type(env) == "table" then
            for _, k in ipairs(keys) do
                local val = rawget(env, k) or env[k]
                if type(val) == "string" and val:match("%S") then
                    local clean = val:gsub("^%s+", ""):gsub("%s+$", "")
                    if clean ~= "" then
                        return clean
                    end
                end
            end
        end
    end
    return nil
end

local detectedWebhook = ProgAPI.DetectGlobalWebhook()
if detectedWebhook then
    ProgAPI.WebhookUrl = detectedWebhook
    ProgAPI.WebhookEnabled = true
end

function ProgAPI.DetectGlobalDisableRender(): boolean?
    local candidates = {
        (getgenv and type(getgenv) == "function" and getgenv()) or nil,
        _G,
        shared,
    }
    local keys = {
        "DisableRender", "disableRender", "disablerender", "DISABLE_RENDER",
        "DisableRendering", "disableRendering", "RenderDisabled",
        "BlackScreen", "blackScreen", "blackscreen"
    }
    for _, env in ipairs(candidates) do
        if type(env) == "table" then
            for _, k in ipairs(keys) do
                local val = rawget(env, k) or env[k]
                if type(val) == "boolean" then
                    return val
                end
            end
        end
    end
    return nil
end

local detectedDisableRender = ProgAPI.DetectGlobalDisableRender()
if detectedDisableRender ~= nil then
    ProgAPI.DisableRender = detectedDisableRender
end

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

-- Declare telemetry updater upvalue for immediate hatch feedback
local updateBlackScreenTelemetry = nil

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

        pcall(function()
            if updateBlackScreenTelemetry then
                updateBlackScreenTelemetry()
            end
        end)
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

function ProgAPI.TeleportToWorld(worldName: string, force: boolean?): boolean
    ProgAPI.ExitMinigame()

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"

    if worldName == "Techworld" or worldName == "Tech" or worldName == "Space" then
        if not force and (curWorld == "Techworld" or curWorld == "Space") then
            return true
        end

        if Channels.Portals then
            local ok, res = pcall(function()
                return Channels.Portals:InvokeServer("TeleportToWorld", "Techworld")
            end)
            if ok and res == true then
                task.wait(0.4)
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
        if not force and curWorld == "Overworld" then
            return true
        end
        if Channels.Portals then
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToWorld", "Overworld")
            end)
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToIsland", "Spawn")
            end)
            task.wait(0.4)
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
}

local eggData = {}
for _, e in ipairs(REAL_PROGRESSION_EGGS) do
    eggData[e.name] = { cost = e.cost, island = e.island, name = e.name }
end
ProgAPI.ProgressionEggs = REAL_PROGRESSION_EGGS

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

    -- 1. If targetIsland explicitly requested, match best affordable egg on that island ONLY
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
        -- STRICT: If a specific island was requested, NEVER fallback to lower islands or Spawn!
        return nil
    end

    -- 2. Progressive Egg Selection:
    local curWorld = stats.CurrentWorld or "Overworld"
    local allIslands = ProgAPI.AreAllIslandsUnlocked()
    local isTechWorld = (curWorld == "Techworld" or curWorld == "Space")
    local furthest = ProgAPI.GetFurthestUnlockedIsland()

    local bestEggName = nil
    local bestCost = 0

    for eggName, meta in pairs(eggData) do
        local isEvent = (eggName == "CandyCornEgg")
        
        -- STRICT: If player has unlocked islands beyond Spawn, never consider normal Spawn eggs!
        local isIslandAvailable = false
        if meta.island == "Spawn" then
            if isEvent then
                isIslandAvailable = true
            elseif furthest == "Spawn" then
                isIslandAvailable = true
            else
                isIslandAvailable = false
            end
        else
            isIslandAvailable = ProgAPI.IsIslandUnlocked(meta.island)
        end

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
    if not bestEggName and not isTechWorld and not allIslands and furthest == "Spawn" and clicks >= 250 then
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

function ProgAPI.TeleportToEgg(eggName: string, forceWorldRemote: boolean?): boolean
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local eggMeta = eggData[eggName] or (Directory and Directory.Eggs and Directory.Eggs[eggName])
    local island = eggMeta and (eggMeta.island or eggMeta.Island) or "Spawn"
    local meta = islandMetaLookup[island] or (Directory and Directory.Islands and Directory.Islands[island])
    local targetWorld = (meta and (meta.world or meta.World)) or "Overworld"
    if island == "Base" or island == "Spaceship" or island == "Fragment" or island == "Matrix"
        or eggName == "TechEgg" or eggName == "HolographicEgg" or eggName == "404Egg"
        or eggName == "RedTechEgg" or eggName == "FragmentedEgg" or eggName == "MatrixEgg" then
        targetWorld = "Techworld"
    else
        targetWorld = "Overworld"
    end

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"
    local curIsland = stats.CurrentIsland or ""

    -- Check if character is ALREADY close to the egg AND in the correct world AND not in minigame
    local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    local isNear = (targetPart and (hrp.Position - targetPart.Position).Magnitude <= 16)
        or (eggName == "MatrixEgg" and (hrp.Position - Vector3.new(7828.7, 6196.1, 303.1)).Magnitude <= 16)

    local inMinigame = (ProgAPI.IsInMinigame and ProgAPI.IsInMinigame())
    if not forceWorldRemote and isNear and curWorld == targetWorld and not inMinigame then
        return true
    end

    -- 1. Exit any active minigame if active
    if ProgAPI.IsInMinigame and ProgAPI.IsInMinigame() then
        ProgAPI.ExitMinigame()
        task.wait(0.35)
    end

    -- 2. Switch world via TeleportToWorld remote FIRST if forced or worlds differ
    stats = Stats.Local(true) or {}
    curWorld = stats.CurrentWorld or "Overworld"
    if forceWorldRemote or targetWorld ~= curWorld then
        if Channels.Portals then
            pcall(function() Channels.Portals:InvokeServer("TeleportToWorld", targetWorld) end)
            task.wait(0.5)
        else
            ProgAPI.TeleportToWorld(targetWorld, true)
            task.wait(0.5)
        end
    end

    -- 3. Teleport to target island via server remote and client local teleport
    ProgAPI.TeleportToIsland(island)
    task.wait(0.3)

    -- 4. Find the egg model and stand directly on it (with streaming retry)
    eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    char = LocalPlayer.Character
    hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not targetPart or not hrp then
        for _ = 1, 6 do
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
        task.wait(0.15)
        return true
    end

    return false
end

-- Dynamically retrieves the exact Hatching Speed displayed on the User Profile
-- (e.g. 1.5s, 2.7s) to guarantee 100% accurate synchronization with game engine and server cooldowns
function ProgAPI.GetUserProfileHatchSpeed(eggName: string?): (number, string)
    eggName = eggName or ProgAPI.SelectedEgg or "MatrixEgg"

    -- 1. Try reading the exact text from the User Profile GUI if available
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local profileGui = pGui and pGui:FindFirstChild("Profile")
    if profileGui then
        local hs = profileGui:FindFirstChild("HatchSpeed", true)
        if hs then
            local val = hs:FindFirstChild("Value")
            if val and val.Text and val.Text ~= "" then
                local num = tonumber(val.Text:match("([%d%.]+)"))
                if num and num > 0 then
                    return num, string.format("%.1fs", num)
                end
            end
        end
    end

    -- 2. Exact game engine formula used by Profile script: string.format("%.1fs", 4.2 / EggsFrontend.GetHatchSpeedMultiplier())
    local mult = 1
    if EggsFrontend and EggsFrontend.GetHatchSpeedMultiplier then
        local ok, m = pcall(function()
            return EggsFrontend.GetHatchSpeedMultiplier(eggName)
        end)
        if not ok or type(m) ~= "number" or m <= 0 then
            ok, m = pcall(function()
                return EggsFrontend.GetHatchSpeedMultiplier()
            end)
        end
        if ok and type(m) == "number" and m > 0 then
            mult = m
        end
    end

    local raw = 4.2 / mult
    local formatted = string.format("%.1f", raw)
    local speed = tonumber(formatted) or raw
    return math.clamp(speed, 0.1, 10.0), formatted .. "s"
end

function ProgAPI.GetPlayerHatchSpeed(eggName: string?): number
    local speed = ProgAPI.GetUserProfileHatchSpeed(eggName)
    return speed
end

function ProgAPI.FormatHatchSpeed(eggName: string?): string
    local _, formatted = ProgAPI.GetUserProfileHatchSpeed(eggName)
    return formatted
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
    local maxInv = 200
    pcall(function()
        local Pets = require(Client:WaitForChild("Pets", 2))
        if Pets and Pets.GetEffectiveMaxInventoryPets then
            maxInv = Pets.GetEffectiveMaxInventoryPets()
        elseif stats.MaxInventoryPets then
            maxInv = stats.MaxInventoryPets
        end
    end)
    local freeSlots = math.max(0, maxInv - curInv)
    if freeSlots > 0 then
        maxCount = math.min(maxCount, freeSlots)
    end

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

-- Disables client egg animations and camera locks to enable instantaneous egg opening
function ProgAPI.DisableEggAnimation()
    pcall(function()
        local Client = game:GetService("ReplicatedStorage"):WaitForChild("Library", 999):WaitForChild("Client")
        local OpenEgg = require(Client:WaitForChild("OpenEgg"))
        if OpenEgg then
            OpenEgg.Play = function(eggId, pets, onComplete, isCancelled)
                if onComplete then
                    task.spawn(onComplete)
                end
            end
        end
        local OpenEggFolder = Client:WaitForChild("OpenEgg")
        if OpenEggFolder and OpenEggFolder:FindFirstChild("Animation") then
            local Animation = require(OpenEggFolder.Animation)
            if Animation then
                Animation.Play = function(params)
                    if params and params.onComplete then
                        task.spawn(params.onComplete)
                    end
                end
            end
        end
    end)
end

function ProgAPI.OpenEgg(eggName: string, amount: number?, skipTeleport: boolean?): (boolean, string)
    if not eggName or eggName == "" then return false, "No egg specified" end
    ProgAPI.SelectedEgg = eggName
    ProgAPI.DisableEggAnimation()

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"
    local curIsland = stats.CurrentIsland or ""

    -- Strict Safety Guard: Never open BasicEgg if in Tech World, or all islands unlocked, or past Spawn, UNLESS doing Phase 2 secret quest or Phase 4 auto index!
    local isPhase2Quest = false
    pcall(function()
        if ProgAPI.GetSecretQuestInfo then
            local q = ProgAPI.GetSecretQuestInfo()
            if not q.AllQuestsDone or not q.IsDoorUnlocked then
                isPhase2Quest = true
            end
        end
    end)
    local isPhase4AutoIndex = false
    pcall(function()
        if ProgAPI.IsPhase4 and ProgAPI.IsPhase4() then
            isPhase4AutoIndex = true
        end
        local st = rawget(_G, "State")
        if st and st.AutoIndexPets then
            isPhase4AutoIndex = true
        end
    end)
    if eggName == "BasicEgg" and not isPhase2Quest and not isPhase4AutoIndex and (curWorld == "Techworld" or curWorld == "Space" or ProgAPI.AreAllIslandsUnlocked() or ProgAPI.IsIslandUnlocked("Winter")) then
        return false, "Blocked opening BasicEgg on advanced progression"
    end

    if not amount or amount <= 0 then
        amount = ProgAPI.GetMaxEggOpenAmount(eggName)
    end
    if not Channels.Egg then return false, "No Egg channel" end

    -- Verify character is on target island/world and in proximity to the egg model
    local eggMeta = eggData[eggName]
    local targetIsland = eggMeta and eggMeta.island or "Spawn"
    local meta = islandMetaLookup[targetIsland]
    local targetWorld = (meta and meta.world) or "Overworld"

    local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local dist = (hrp and targetPart) and (hrp.Position - targetPart.Position).Magnitude or 9999
    local inMinigame = (ProgAPI.IsInMinigame and ProgAPI.IsInMinigame())

    -- If skipTeleport is not true, ensure player is officially on the right island & world and next to the egg!
    if not skipTeleport then
        local needsTeleport = (not targetPart) or (dist > 16) or (curWorld ~= targetWorld) or (curIsland ~= targetIsland) or inMinigame
        if needsTeleport then
            ProgAPI.TeleportToEgg(eggName)
            task.wait(0.25)
            eggModel, targetPart = ProgAPI.FindEggModel(eggName)
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
        end
    end

    if hrp and targetPart then
        local currentDist = (hrp.Position - targetPart.Position).Magnitude
        if currentDist > 16 then
            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.12)
        end
    elseif not targetPart then
        return false, "Cannot locate egg model in workspace"
    end

    -- Proactive Inventory Check & Cleaning BEFORE invoking the server!
    local isP4 = ProgAPI.IsPhase4 and ProgAPI.IsPhase4()
    local isP5 = ProgAPI.IsPhase5 and ProgAPI.IsPhase5()
    local isP6 = ProgAPI.IsPhase6 and ProgAPI.IsPhase6()
    local curInv = 0
    for _ in pairs(stats.Pets or {}) do curInv = curInv + 1 end
    local maxInv = 200
    pcall(function()
        local Pets = require(Client:WaitForChild("Pets", 2))
        if Pets and Pets.GetEffectiveMaxInventoryPets then
            maxInv = Pets.GetEffectiveMaxInventoryPets()
        elseif stats.MaxInventoryPets then
            maxInv = stats.MaxInventoryPets
        end
    end)

    local isP2GoldDone = ProgAPI.IsPhase2QuestGoldDone and ProgAPI.IsPhase2QuestGoldDone()

    if curInv + amount >= maxInv - 2 then
        if isP6 then
            pcall(ProgAPI.CleanNonMythicPets)
            pcall(ProgAPI.CraftGoldenPets)
        elseif isP4 then
            pcall(ProgAPI.CraftGoldenPets)
            pcall(ProgAPI.CleanIndexedFodder)
        elseif isP2GoldDone then
            pcall(ProgAPI.CleanSecretQuestPets)
        else
            pcall(ProgAPI.CraftGoldenPets)
            local cleaned = ProgAPI.CleanWeakPets(true)
            if cleaned == 0 then
                -- Inventory still near capacity; relax crafting candidate protection to avoid deadlock
                ProgAPI.CleanWeakPets(false)
            end
        end
        task.wait(0.08)
    end

    local guid = HttpService:GenerateGUID(false)
    local ok, res, reason = pcall(function()
        return Channels.Egg:InvokeServer("Open", eggName, amount, guid)
    end)

    if ok and (res == true or type(res) == "table") then
        return true, "Successfully opened " .. eggName
    end

    -- If server rejected due to full inventory, clean immediately
    if tostring(reason):lower():find("full") or tostring(res):lower():find("full") then
        if isP6 then
            pcall(ProgAPI.CleanNonMythicPets)
        elseif isP4 then
            pcall(ProgAPI.CraftGoldenPets)
            pcall(ProgAPI.CleanIndexedFodder)
        elseif isP2GoldDone then
            pcall(ProgAPI.CleanSecretQuestPets)
        else
            pcall(ProgAPI.CraftGoldenPets)
            pcall(function() ProgAPI.CleanWeakPets(false) end)
        end
    end

    -- If server rate-limited or player on cooldown, back off minimally to let server cooldown expire
    if tostring(reason):lower():find("too fast") or tostring(res):lower():find("too fast") then
        ProgAPI.HatchBackoffUntil = tick() + 0.35
    end
    if tostring(reason):lower():find("cooldown") or tostring(res):lower():find("cooldown") or tostring(reason):lower():find("ratelimit") or tostring(res):lower():find("ratelimit") then
        ProgAPI.HatchBackoffUntil = tick() + 1.2
    end

    -- If server specifically rejected due to distance, gently reposition HRP right onto the egg stand
    if tostring(reason):lower():find("far") or tostring(res):lower():find("far") then
        pcall(function()
            local eggModel, targetPart = ProgAPI.FindEggModel(eggName)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and targetPart then
                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
            end
        end)
    end

    return false, "Failed to open egg: " .. tostring(reason or res)
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
    local isP2GoldDone = ProgAPI.IsPhase2QuestGoldDone and ProgAPI.IsPhase2QuestGoldDone()
    local basicEggDrops = { Dog = true, Cat = true, Bunny = true, Pig = true }

    local groups = {}
    for guid, p in pairs(pets) do
        local isLocked = p.Locked == true or p.l == true
        local isNormal = (p.v == nil or p.v == "Normal")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        -- Skip crafting BasicEgg pets into Golden if Phase 2 gold objective is already done!
        if isP2GoldDone and basicEggDrops[p.id] then
            continue
        end

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

--==============================================================================
-- RAINBOW MACHINE HELPERS & TRACKING
--==============================================================================
function ProgAPI.GetActiveAndQueuedRainbowPetIds(): { [string]: boolean }
    local res = {}
    local stats = Stats.Local(true) or {}
    local crafts = stats.RainbowCrafts or {}
    for slot, craft in pairs(crafts) do
        if type(craft) == "table" and craft.PetId then
            res[tostring(craft.PetId)] = true
        end
    end
    local queue = stats.RainbowCraftQueue or {}
    for idx, item in pairs(queue) do
        if type(item) == "table" and item.PetId then
            res[tostring(item.PetId)] = true
        end
    end
    return res
end

function ProgAPI.GetRainbowMachineStatus(): {
    ActiveCount: number,
    QueueCount: number,
    TotalCooking: number,
    ActivePetIds: { [string]: boolean }
}
    local activeOrQueued = ProgAPI.GetActiveAndQueuedRainbowPetIds()
    local stats = Stats.Local(true) or {}
    local crafts = stats.RainbowCrafts or {}
    local queue = stats.RainbowCraftQueue or {}

    local aCount = 0
    for _, c in pairs(crafts) do
        if type(c) == "table" and c.PetId then aCount = aCount + 1 end
    end
    local qCount = 0
    for _, q in pairs(queue) do
        if type(q) == "table" and q.PetId then qCount = qCount + 1 end
    end

    return {
        ActiveCount = aCount,
        QueueCount = qCount,
        TotalCooking = aCount + qCount,
        ActivePetIds = activeOrQueued
    }
end

-- Converts batches of duplicate Golden pets into Rainbow pets
-- In Phase 4 Index Mode: Only crafts easy pets (Basic & Rare & Epic), and only 1 batch per pet until queued or obtained.
-- If includeLegendary is true (Stage 3B), also crafts Legendary batches!
function ProgAPI.CraftRainbowPets(phase4IndexMode: boolean?, includeLegendary: boolean?): number
    if not Channels.Pets and not Channels.Crafting then return 0 end
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}
    local obtained = stats.ObtainedPets or {}
    local activeOrQueued = ProgAPI.GetActiveAndQueuedRainbowPetIds()

    local currentTotalIndexed = 0
    local totalCooking = 0
    local targetTotal = 250
    if phase4IndexMode then
        local st = rawget(_G, "State")
        targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
        local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
        currentTotalIndexed = (totalStats and totalStats.TotalIndexed) or 0
        local rainbowStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
        totalCooking = (rainbowStatus and rainbowStatus.TotalCooking) or 0

        -- User requirement: 250 Total Index goal. If already met or accounted for by queued rainbows, stop crafting!
        if (currentTotalIndexed + totalCooking) >= targetTotal then
            return 0
        end
    end

    local groups = {}
    for guid, p in pairs(pets) do
        local isEquipped = equipped[guid] ~= nil
        local isLocked = p.Locked == true or p.l == true
        local isGolden = (p.v == "Golden" or p.Variant == "Golden" or p.Gold == true or p.Type == "Golden")
        local isExclusive = Directory.Pets and Directory.Pets[p.id] and Directory.Pets[p.id].Rarity == "Exclusive"

        if not isEquipped and not isLocked and isGolden and not isExclusive then
            local petDef = Directory.Pets and Directory.Pets[p.id]
            local rarity = (petDef and petDef.Rarity) or "Basic"
            local isEasyRarity = (rarity == "Basic" or rarity == "Rare" or rarity == "Common")
            if Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] then
                isEasyRarity = (Constants.RarityOrder[rarity] <= 2)
            end
            if includeLegendary == true and (rarity == "Legendary" or (Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] == 4)) then
                isEasyRarity = true
            end

            local allow = true
            if phase4IndexMode then
                if not isEasyRarity then
                    allow = false
                elseif obtained[p.id .. "_Golden"] ~= true then
                    -- User requirement: Prioritize Gold first! Must have Gold indexed before crafting Rainbow!
                    allow = false
                elseif obtained[p.id .. "_Rainbow"] == true then
                    allow = false
                elseif activeOrQueued[tostring(p.id)] == true then
                    allow = false
                end
            end

            if allow then
                local key = tostring(p.id) .. "_" .. tostring(p.Shiny or p.s or false)
                groups[key] = groups[key] or { id = p.id, guids = {} }
                table.insert(groups[key].guids, guid)
            end
        end
    end

    local craftedCount = 0
    for _, g in pairs(groups) do
        if phase4IndexMode and (currentTotalIndexed + totalCooking) >= targetTotal then
            break
        end

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
            if ok and (res == true or type(res) == "table" or res == "Queued") then
                craftedCount = craftedCount + 1
                totalCooking = totalCooking + 1
                activeOrQueued[tostring(g.id)] = true
                task.wait(0.2)
                if phase4IndexMode then
                    break
                end
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
                local saveAge = (Stats.GetSaveAge and Stats.GetSaveAge()) or stats.SaveAge or 0
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

-- Single source of truth validator for High-Tier & Protected Pets
-- STRICT USER REQUIREMENT:
-- 1. High-Tier Pets (Exclusive, Secret, Stock, Divine, Mega, Mythic/Mythical, Special - Rarity Order >= 5):
--    NEVER BE DELETED under ANY circumstances (whether Normal, Golden, Rainbow, Shiny, Mutated, etc.)!
-- 2. Manually Locked Pets (p.Locked == true or p.l == true): NEVER BE DELETED!
-- 3. Low-Tier Pets (Basic, Rare, Epic, Legendary - Rarity Order <= 4):
--    MUST BE DELETED when cleaners run, EVEN IF Rainbow, Shiny, Mutated, or Dark Matter!
function ProgAPI.IsSecretOrAbove(p: any): boolean
    if not p then return true end -- Fail-safe: nil pets are protected

    -- 1. Strictly protect locked pets
    if type(p) == "table" and (p.Locked == true or p.l == true) then
        return true
    end

    local pId = (type(p) == "table" and (p.id or p.Id or p.Name or p.PetId)) or (type(p) == "string" and p)
    if not pId then return true end

    -- 2. Official game client engine Pets.GetRarityOrder check
    -- Basic=1, Rare=2, Epic=3, Leg=4, Mythic/Mythical=5, Exclusive/Special=6, Secret/Stock=7, Divine=8, Mega=9
    local order = nil
    pcall(function()
        local PetsMod = require(Client:WaitForChild("Pets", 2))
        if PetsMod and PetsMod.GetRarityOrder then
            order = PetsMod.GetRarityOrder(tostring(pId))
        end
    end)
    if type(order) == "number" then
        if order >= 5 then
            return true -- Exclusive, Secret, Stock, Divine, Mega, Mythic, Special
        elseif order <= 4 then
            return false -- Basic, Rare, Epic, Legendary are fodder (even if Shiny/Rainbow/Mutated)
        end
    end

    -- 3. Safe Directory lookup using pcall & rawget to avoid throwing on unknown keys
    local meta = nil
    pcall(function()
        if Directory and Directory.Pets then
            meta = rawget(Directory.Pets, pId) or rawget(Directory.Pets, tostring(pId))
            if not meta then
                meta = Directory.Pets[pId] or Directory.Pets[tostring(pId)]
            end
        end
    end)

    if not meta and type(pId) == "string" and Directory and Directory.Pets then
        pcall(function()
            for id, data in pairs(Directory.Pets) do
                if tostring(id):lower() == pId:lower() then
                    meta = data
                    break
                end
            end
        end)
    end

    local r = (meta and meta.Rarity) or (type(p) == "table" and (p.rarity or p.Rarity))
    if not r then
        -- Strict safety: If rarity cannot be determined, treat as protected so we NEVER delete unknown/custom pets
        return true
    end

    -- 4. Official Constants.RarityOrder check (Mythic, Exclusive, Secret, Stock, Divine, Mega >= 5)
    if Constants and Constants.RarityOrder and Constants.RarityOrder[r] then
        local constOrder = Constants.RarityOrder[r]
        if constOrder >= 5 then
            return true
        elseif constOrder <= 4 then
            return false
        end
    end

    -- 5. String matching on rarity: Exclusive, Secret, Stock, Divine, Mega, Mythic, Mythical, Special
    local rLower = tostring(r):lower()
    if rLower:find("exclusive") or rLower:find("secret") or rLower:find("stock")
       or rLower:find("divine") or rLower:find("mega") or rLower:find("mythic")
       or rLower:find("mythical") or rLower:find("special") then
        return true
    end

    -- 6. String matching on Pet ID and Display Name
    local idLower = tostring(pId):lower()
    local nameLower = meta and meta.Name and tostring(meta.Name):lower() or ""
    if idLower:find("secret") or idLower:find("divine") or idLower:find("mega")
       or idLower:find("exclusive") or idLower:find("stock") or idLower:find("mythic")
       or nameLower:find("secret") or nameLower:find("divine") or nameLower:find("mega")
       or nameLower:find("exclusive") or nameLower:find("stock") or nameLower:find("mythic") then
        return true
    end

    -- ONLY returns false if the pet is 100% verified to be Basic (1), Rare (2), Epic (3), or Legendary (4)
    return false
end

-- Backward compatibility alias
function ProgAPI.IsMythicOrAbove(p: any): boolean
    return ProgAPI.IsSecretOrAbove(p)
end
function ProgAPI.IsProtectedPet(p: any): boolean
    return ProgAPI.IsSecretOrAbove(p)
end

-- Checks if player is in Phase 2 (??? Secret Area Quest) and has already completed Objective 3 (15 Golden Pets)
function ProgAPI.IsPhase2QuestGoldDone(): boolean
    local stats = Stats.Local(true) or {}
    local isClaimed = stats.SecretAreaQuestClaimed == true
    local isDoorUnlocked = stats.DominusAreaUnlocked == true
    if not isClaimed or isDoorUnlocked then
        return false
    end
    local quests = stats.SecretAreaQuests
    if quests and quests.Golden and quests.Golden.Done == true then
        return true
    end
    if ProgAPI.GetSecretQuestInfo then
        local qInfo = ProgAPI.GetSecretQuestInfo()
        if (qInfo.Golden and qInfo.Golden.Done == true) and (not qInfo.IsDoorUnlocked) then
            return true
        end
    end
    return false
end

-- Deletes all BasicEgg / World 1 Spawn pets (Dog, Cat, Bunny, Pig - Normal, Golden, Rainbow) hatched during Phase 2 ??? Quest
-- Strictly preserves equipped pets, locked pets, and Mythic/Special/Secret/Divine pets!
function ProgAPI.CleanSecretQuestPets(): number
    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}

    local basicEggDrops = {
        Dog = true,
        Cat = true,
        Bunny = true,
        Pig = true,
    }

    local petMap = buildPetIslandMap()
    local toDelete = {}
    for guid, p in pairs(pets) do
        -- Never delete currently equipped pets or locked pets!
        if not equipped[guid] and not p.Locked and not p.l then
            -- Strictly keep ALL Exclusive, Secret, Stock, Divine, Mega, Mythic pets!
            if not ProgAPI.IsSecretOrAbove(p) then
                -- Strictly ONLY delete confirmed BasicEgg drops (Dog, Cat, Bunny, Pig)!
                if basicEggDrops[p.id] then
                    table.insert(toDelete, guid)
                end
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

-- Weak pet deletion: If highest unlocked island is N, delete all normal pets from world (N - 2) and below
function ProgAPI.CleanWeakPets(protectCrafting: boolean?): number
    if ProgAPI.IsPhase6 and ProgAPI.IsPhase6() then
        return ProgAPI.CleanNonMythicPets()
    end
    if ProgAPI.IsPhase5 and ProgAPI.IsPhase5() then
        return ProgAPI.CleanNonMythicPets()
    end
    if ProgAPI.IsPhase4 and ProgAPI.IsPhase4() then
        return ProgAPI.CleanIndexedFodder()
    end
    if ProgAPI.IsPhase2QuestGoldDone and ProgAPI.IsPhase2QuestGoldDone() then
        return ProgAPI.CleanSecretQuestPets()
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
            -- ABSOLUTE SAFETY: Strictly NEVER delete Exclusive, Secret, Stock, Divine, Mega, Mythic or protected pets!
            local isProtected = ProgAPI.IsSecretOrAbove(p)

            if not isProtected then
                local petOriginWorld = petMap[p.id] or 999 -- Default to 999 (safe / endgame), NEVER 1!
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

    if coinsTotal < 39 then
        coinsTotal = 39
    end

    local techDone = (techBought >= 13) or (techTotal > 0 and techBought >= techTotal)
    local coinsDone = (coinsBought >= 39) or (coinsTotal >= 39 and coinsBought >= coinsTotal)

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

    -- Always attempt to purchase Dominus Fortune perks (80B, 200B, 400B Coins)
    pcall(function()
        local dfBought = ProgAPI.BuyDominusFortuneUpgrades()
        count = count + dfBought
    end)

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

        -- Check if breakables have spawned in DominusArea. If not, wait in place without teleporting!
        local curCount = ProgAPI.GetActiveIslandBreakablesCount("DominusArea", false)
        if curCount == 0 then
            return "Waiting for ??? Breakables spawn...", "DominusArea"
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
    if targetWorld == "DominusArea" then
        local zonePart = ProgAPI.GetIslandBreakableZone("DominusArea", false)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and zonePart and (hrp.Position - zonePart.Position).Magnitude > 25 then
            hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        end
    else
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
-- PHASE RECOGNITION HELPERS
-- Phase 1: Island Speedrun (locked islands remaining)
-- Phase 2: Endgame Preparation (all islands unlocked, Skill Tree in progress)
-- Phase 3: ??? Secret Quest (Skill Tree complete, ??? questline in progress)
-- Phase 4: Endgame Matrix Mythics (Skill Tree complete AND ??? questline complete)
--==============================================================================
function ProgAPI.IsPhase1(): boolean
    return not ProgAPI.AreAllIslandsUnlocked()
end

function ProgAPI.IsSkillTreeMaxed(): boolean
    local stProg = ProgAPI.GetSkillTreeProgress()
    local coinsDone = stProg and (stProg.CoinsComplete or stProg.CoinsBought >= 39)
    local techDone = stProg and (stProg.TechComplete or stProg.TechBought >= 13)
    return (coinsDone and techDone) == true
end

function ProgAPI.IsPhase2(): boolean
    if not ProgAPI.AreAllIslandsUnlocked() then return false end
    return not ProgAPI.IsSecretQuestComplete()
end

--==============================================================================
-- PHASE 3: ??? SECRET AREA QUESTLINE AUTOMATION
-- Quests:
-- 1. secret_click_1: Click 3,500 Times
-- 2. secret_feathers: Collect 10 Feathers across maps
-- 3. secret_craft_golden: Craft 15 Golden Pets
-- 4. secret_hatch_eggs: Hatch 2,500 Eggs
-- Door: Dominus secret door on Spawn island (Overworld)
--==============================================================================

function ProgAPI.GetSecretQuestInfo()
    local stats = Stats.Local(true) or {}
    local quests = stats.Quests or {}
    local collectedFeathers = stats.SecretAreaCollectedFeathers or {}
    local isDoorUnlocked = (stats.DominusAreaUnlocked == true)
    local isClaimed = (stats.SecretAreaQuestClaimed == true)

    local clickQ = quests.secret_click_1
    local clickProg = clickQ and clickQ.Progress or 0
    local clickReq = clickQ and clickQ.Amount or 3500
    local clickDone = clickProg >= clickReq

    local featherQ = quests.secret_feathers
    local featherProg = featherQ and featherQ.Progress or 0
    local featherReq = featherQ and featherQ.Amount or 10
    local featherDone = featherProg >= featherReq

    local goldenQ = quests.secret_craft_golden
    local goldenProg = goldenQ and goldenQ.Progress or 0
    local goldenReq = goldenQ and goldenQ.Amount or 15
    local goldenDone = goldenProg >= goldenReq

    local hatchQ = quests.secret_hatch_eggs
    local hatchProg = hatchQ and hatchQ.Progress or 0
    local hatchReq = hatchQ and hatchQ.Amount or 2500
    local hatchDone = hatchProg >= hatchReq

    local allQuestsDone = clickDone and featherDone and goldenDone and hatchDone
    local isComplete = isDoorUnlocked

    local currentStep = "Completed"
    if isDoorUnlocked then
        currentStep = "Dominus Area Unlocked!"
    elseif not isClaimed then
        currentStep = "Accept Quest (Spawn Door)"
    elseif not clickDone then
        currentStep = string.format("Clicks: %s / %s", ProgAPI.FormatNumber(clickProg), ProgAPI.FormatNumber(clickReq))
    elseif not featherDone then
        currentStep = string.format("Feathers: %d / %d", featherProg, featherReq)
    elseif not goldenDone then
        currentStep = string.format("Golden Pets: %d / %d", goldenProg, goldenReq)
    elseif not hatchDone then
        currentStep = string.format("Hatch Eggs: %s / %s", ProgAPI.FormatNumber(hatchProg), ProgAPI.FormatNumber(hatchReq))
    elseif allQuestsDone and not isDoorUnlocked then
        currentStep = "Unlock Spawn Door"
    end

    return {
        IsClaimed = isClaimed,
        IsDoorUnlocked = isDoorUnlocked,
        DoorUnlocked = isDoorUnlocked,
        AllQuestsDone = allQuestsDone,
        IsComplete = isComplete,
        CurrentStep = currentStep,
        Clicks = { Progress = clickProg, Amount = clickReq, Done = clickDone },
        Feathers = { Progress = featherProg, Amount = featherReq, Done = featherDone, Collected = collectedFeathers },
        Golden = { Progress = goldenProg, Amount = goldenReq, Done = goldenDone },
        Hatch = { Progress = hatchProg, Amount = hatchReq, Done = hatchDone },
    }
end

function ProgAPI.IsSecretQuestComplete(): boolean
    local stats = Stats.Local(true) or {}
    return stats.DominusAreaUnlocked == true
end

--==============================================================================
-- DOMINUS FORTUNE SKILL TREE ENGINE (3 UPGRADES: 680B COINS TOTAL)
-- 1. DominusEggHatch (80B Coins) -> Open +1 pet from every normal egg hatch!
-- 2. DominusEggLuck (200B Coins) -> Gain +15% permanent Egg Luck!
-- 3. DominusSecretSeeker (400B Coins) -> Secret pet chances are 10% higher!
--==============================================================================

function ProgAPI.GetDominusFortuneProgress(): {
    HatchOwned: boolean,
    LuckOwned: boolean,
    SeekerOwned: boolean,
    BoughtCount: number,
    TotalCount: number,
    IsComplete: boolean
}
    local stats = Stats.Local(true) or {}
    local st = stats.SkillTree or {}
    local stFrontend = nil
    pcall(function()
        stFrontend = require(Client:WaitForChild("SkillTreeFrontend"))
    end)
    local SkillTreeUtil = nil
    pcall(function()
        SkillTreeUtil = require(Library:WaitForChild("Utils"):WaitForChild("SkillTreeUtil"))
    end)

    local function checkOwned(upgId: string): boolean
        local saveKey = upgId
        if SkillTreeUtil and SkillTreeUtil.GetSaveKey then
            pcall(function() saveKey = SkillTreeUtil.GetSaveKey(upgId, "Default") end)
        end
        if st[saveKey] == true or st[upgId] == true then return true end
        if stFrontend and stFrontend.OwnsUpgrade then
            local res = false
            pcall(function() res = stFrontend.OwnsUpgrade(upgId, "Default") end)
            if res == true then return true end
        end
        return false
    end

    local hatch = checkOwned("DominusEggHatch")
    local luck = checkOwned("DominusEggLuck")
    local seeker = checkOwned("DominusSecretSeeker")
    local count = (hatch and 1 or 0) + (luck and 1 or 0) + (seeker and 1 or 0)

    return {
        HatchOwned = hatch,
        LuckOwned = luck,
        SeekerOwned = seeker,
        BoughtCount = count,
        TotalCount = 3,
        IsComplete = (count >= 3)
    }
end

function ProgAPI.IsDominusFortuneComplete(): boolean
    local prog = ProgAPI.GetDominusFortuneProgress()
    return prog.IsComplete
end

function ProgAPI.BuyDominusFortuneUpgrades(): number
    if not Channels.SkillTree then return 0 end
    local stats = Stats.Local(true) or {}
    local curr = (stats.Currency and stats.Currency.Coins) or 0
    local prog = ProgAPI.GetDominusFortuneProgress()
    if prog.IsComplete then return 0 end

    local boughtCount = 0

    -- 1. DominusEggHatch (80B Coins)
    if not prog.HatchOwned then
        if curr >= 80000000000 then
            local ok = false
            pcall(function()
                ok = Channels.SkillTree:InvokeServer("Purchase", "DominusEggHatch", "Default")
            end)
            if ok == true then
                boughtCount = boughtCount + 1
                curr = curr - 80000000000
                task.wait(0.1)
                prog = ProgAPI.GetDominusFortuneProgress()
            end
        end
    end

    -- 2. DominusEggLuck (200B Coins, requires DominusEggHatch)
    if prog.HatchOwned and not prog.LuckOwned then
        if curr >= 200000000000 then
            local ok = false
            pcall(function()
                ok = Channels.SkillTree:InvokeServer("Purchase", "DominusEggLuck", "Default")
            end)
            if ok == true then
                boughtCount = boughtCount + 1
                curr = curr - 200000000000
                task.wait(0.1)
                prog = ProgAPI.GetDominusFortuneProgress()
            end
        end
    end

    -- 3. DominusSecretSeeker (400B Coins, requires DominusEggLuck)
    if prog.LuckOwned and not prog.SeekerOwned then
        if curr >= 400000000000 then
            local ok = false
            pcall(function()
                ok = Channels.SkillTree:InvokeServer("Purchase", "DominusSecretSeeker", "Default")
            end)
            if ok == true then
                boughtCount = boughtCount + 1
                curr = curr - 400000000000
                task.wait(0.1)
            end
        end
    end

    return boughtCount
end

function ProgAPI.EnterDominusArea(): boolean
    local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))
    if MF and MF.Enter then
        pcall(function() MF.Enter("DominusArea") end)
    end
    task.wait(0.3)
    local zonePart = ProgAPI.GetIslandBreakableZone("DominusArea", false)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and zonePart then
        hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
        return true
    elseif hrp then
        hrp.CFrame = CFrame.new(399.61, 256.0, 2758.04)
        return true
    end
    return false
end

function ProgAPI.StepDominusAreaFarming(): (string, string)
    local MF = MinigamesFrontend or (Library and require(Library.Client.MinigamesFrontend))

    -- 1. Ensure we are in DominusArea minigame
    if not ProgAPI.IsInMinigame("DominusArea") then
        ProgAPI.EnterDominusArea()
        task.wait(0.35)
    end

    -- 2. Position character in breakable zone
    local zonePart = ProgAPI.GetIslandBreakableZone("DominusArea", false)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and zonePart and (hrp.Position - zonePart.Position).Magnitude > 30 then
        hrp.CFrame = zonePart.CFrame * CFrame.new(0, 2, 0)
    end

    -- 3. Check for active breakables
    local curCount = ProgAPI.GetActiveIslandBreakablesCount("DominusArea", false)
    if curCount == 0 then
        return "Waiting for Dominus Breakables to spawn...", "DominusArea"
    end

    -- 4. Attack breakable
    local okAtk, targetName = pcall(function()
        return ProgAPI.AttackBreakable(false, "DominusArea")
    end)

    if okAtk and targetName then
        return string.format("Farming %s", tostring(targetName)), "DominusArea"
    else
        return "Targeting Dominus Breakables...", "DominusArea"
    end
end

--==============================================================================
-- PHASE 5: ULTIMATE CLICK SKIN PIPELINE
-- Activates once Phase 4 (Auto Index >= 250) is complete!
-- Buys/equips the purple 'Ultimate' Click Skin (requires 250 pets).
-- Saves up 100 Qa Gems (1e17) before rerolling.
-- Rerolls until BOTH +3 Egg Hatch AND +15% Hatch Speed are acquired.
-- If only +3 Egg or only +15% Hatch Speed is rolled, continues rerolling.
-- Once both are met, replaces and equips the skin.
--==============================================================================

function ProgAPI.EvaluateClickSkin(skinData: any): (boolean, number, number)
    if not skinData or type(skinData) ~= "table" then return false, 0, 0 end
    local eggHatchVal = 0
    local hatchSpeedVal = 0

    if skinData.Passives and type(skinData.Passives) == "table" then
        for _, p in ipairs(skinData.Passives) do
            if type(p) == "table" and p.Id == "EggHatch" then
                eggHatchVal = math.max(eggHatchVal, tonumber(p.Value) or 0)
            end
        end
    end

    if skinData.Boosts and type(skinData.Boosts) == "table" then
        for _, b in ipairs(skinData.Boosts) do
            if type(b) == "table" and b.Id == "HatchSpeed" then
                hatchSpeedVal = math.max(hatchSpeedVal, tonumber(b.Value) or 0)
            end
        end
    end

    local st = rawget(_G, "State")
    local targetEggHatch = (st and tonumber(st.ClickSkinTargetEggHatch)) or 3
    local targetHatchSpeed = (st and tonumber(st.ClickSkinTargetHatchSpeed)) or 15

    local isGoalMet = (eggHatchVal >= targetEggHatch) and (hatchSpeedVal >= targetHatchSpeed)
    return isGoalMet, eggHatchVal, hatchSpeedVal
end

function ProgAPI.GetClickSkinStatus(): table
    local stats = Stats.Local(true) or {}
    local clickSkins = stats.ClickSkins or {}
    local equipped = clickSkins.Equipped
    local pending = clickSkins.Pending
    local currentGems = (stats.Currency and stats.Currency.Gems) or (stats.Gems) or 0

    local eqMet, eqEgg, eqSpeed = ProgAPI.EvaluateClickSkin(equipped)
    local penMet, penEgg, penSpeed = ProgAPI.EvaluateClickSkin(pending)

    local st = rawget(_G, "State")
    local targetTier = (st and st.ClickSkinTier) or "Ultimate"
    local gemThresholdQa = (st and tonumber(st.ClickSkinGemsThreshold)) or 100
    local gemThreshold = gemThresholdQa * 1e15 -- 100 Qa = 1e17

    local isEquippedTargetTier = (equipped and equipped.Tier == targetTier) == true

    return {
        Equipped = equipped,
        Pending = pending,
        EquippedTier = (equipped and equipped.Tier) or "None",
        EquippedEggHatch = eqEgg,
        EquippedHatchSpeed = eqSpeed,
        EquippedGoalMet = eqMet,
        PendingTier = (pending and pending.Tier) or "None",
        PendingId = (pending and pending.Id),
        PendingEggHatch = penEgg,
        PendingHatchSpeed = penSpeed,
        PendingGoalMet = penMet,
        CurrentGems = currentGems,
        GemsThreshold = gemThreshold,
        GemsThresholdMet = (currentGems >= gemThreshold),
        GoalMet = (isEquippedTargetTier and eqMet) == true,
    }
end

function ProgAPI.IsClickSkinGoalMet(): boolean
    local status = ProgAPI.GetClickSkinStatus()
    return status.GoalMet == true
end

local lastSkinRollTick = 0

function ProgAPI.StepClickSkinPipeline(): (boolean, string)
    local status = ProgAPI.GetClickSkinStatus()
    local st = rawget(_G, "State")
    local targetTier = (st and st.ClickSkinTier) or "Ultimate"

    -- 1. If already met on equipped skin, we are done!
    if status.GoalMet then
        return true, string.format("🌟 [Phase 5: Complete] Ultimate Skin Active! (+%d Egg, +%.1f%% Speed)", status.EquippedEggHatch, status.EquippedHatchSpeed)
    end

    local skinCh = Channels.ClickSkins or Network.Channel("ClickSkins")
    if not skinCh then
        return false, "[Phase 5: Skin] ClickSkins remote channel not found"
    end

    -- 2. If Pending skin satisfies BOTH target stats (+3 Egg Hatch & +15% Hatch Speed), replace immediately!
    if status.Pending and status.PendingGoalMet and status.PendingId then
        local okRep = pcall(function()
            return skinCh:InvokeServer("Replace", status.PendingId)
        end)
        task.wait(0.2)
        local postStatus = ProgAPI.GetClickSkinStatus()
        if postStatus.GoalMet then
            return true, string.format("🎉 [Phase 5: Complete] Replaced & Equipped Ultimate Skin (+%d Egg, +%.1f%% Speed)!", postStatus.EquippedEggHatch, postStatus.EquippedHatchSpeed)
        end
    end

    -- 3. If Equipped is not Ultimate yet, but Pending is an Ultimate skin:
    -- Replace it once so player equips the Ultimate skin and gains base boosts!
    if status.EquippedTier ~= targetTier and status.Pending and status.PendingTier == targetTier and status.PendingId then
        pcall(function()
            skinCh:InvokeServer("Replace", status.PendingId)
        end)
        task.wait(0.2)
        status = ProgAPI.GetClickSkinStatus()
        if status.GoalMet then
            return true, string.format("🎉 [Phase 5: Complete] Equipped Ultimate Skin (+%d Egg, +%.1f%% Speed)!", status.EquippedEggHatch, status.EquippedHatchSpeed)
        end
    end

    -- 4. Check Gems Threshold before rerolling!
    -- Must save up to ClickSkinGemsThreshold (default 100 Qa = 1e17 Gems) before rerolling.
    if status.CurrentGems < status.GemsThreshold then
        local stats = Stats.Local(true) or {}
        local curWorld = (stats and stats.CurrentWorld) or "Overworld"
        if curWorld ~= "Techworld" and curWorld ~= "Space" then
            ProgAPI.ExitMinigame()
            task.wait(0.2)
            ProgAPI.TeleportToWorld("Techworld")
            task.wait(0.3)
        end
        pcall(function() ProgAPI.StepBreakablesPipeline(true) end)
        return false, string.format("[Phase 5: Skin] Saving Gems: %s / %s (Farming Breakables)",
            ProgAPI.FormatNumber(status.CurrentGems),
            ProgAPI.FormatNumber(status.GemsThreshold)
        )
    end

    -- 5. Reroll Pending skin!
    -- Ultimate roll costs 1 Qa Gems (1e15).
    local rollCost = 1e15
    if status.CurrentGems < rollCost then
        return false, string.format("[Phase 5: Skin] Need %s Gems for roll (Have: %s)",
            ProgAPI.FormatNumber(rollCost),
            ProgAPI.FormatNumber(status.CurrentGems)
        )
    end

    local now = tick()
    if now - lastSkinRollTick < 0.35 then
        return false, "[Phase 5: Skin] Rerolling Ultimate Skin..."
    end
    lastSkinRollTick = now

    local pendingId = status.PendingId
    local okRoll, resRoll = pcall(function()
        return skinCh:InvokeServer("Roll", targetTier, pendingId, false)
    end)

    task.wait(0.15)
    local newStatus = ProgAPI.GetClickSkinStatus()

    -- Check if newly rolled skin satisfies BOTH goals!
    if newStatus.PendingGoalMet and newStatus.PendingId then
        pcall(function()
            skinCh:InvokeServer("Replace", newStatus.PendingId)
        end)
        task.wait(0.2)
        local finalStatus = ProgAPI.GetClickSkinStatus()
        if finalStatus.GoalMet then
            return true, string.format("🎉 [Phase 5: Complete] Rolled Perfect Ultimate Skin (+%d Egg, +%.1f%% Speed)!", finalStatus.EquippedEggHatch, finalStatus.EquippedHatchSpeed)
        end
    end

    return false, string.format("[Phase 5: Skin Reroll] Pending: +%d Egg, +%.1f%% Speed (Need +3 Egg & +15%% Speed) | Gems: %s",
        newStatus.PendingEggHatch,
        newStatus.PendingHatchSpeed,
        ProgAPI.FormatNumber(newStatus.CurrentGems)
    )
end

function ProgAPI.IsPhase3(): boolean
    if not ProgAPI.AreAllIslandsUnlocked() then return false end
    if not ProgAPI.IsSecretQuestComplete() then return false end
    return not ProgAPI.IsSkillTreeMaxed()
end

function ProgAPI.IsPhase4(): boolean
    if not ProgAPI.AreAllIslandsUnlocked() then return false end
    if not ProgAPI.IsSecretQuestComplete() then return false end
    if not ProgAPI.IsSkillTreeMaxed() then return false end
    local st = rawget(_G, "State")
    if st and st.AutoIndexPets == false then return false end

    -- Check if IndexTargetTotal goal (default 250) has been reached
    local targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    if totalStats and totalStats.TotalIndexed >= targetTotal then
        return false -- Target reached! Phase 4 complete!
    end

    local ignMyth = (st and st.IndexIgnoreMythicAndAbove ~= nil) and st.IndexIgnoreMythicAndAbove or true
    local unNorm = (st and st.IndexUnlockNormal ~= nil) and st.IndexUnlockNormal or true
    local unGold = (st and st.IndexUnlockGold ~= nil) and st.IndexUnlockGold or true
    local unRain = (st and st.IndexUnlockRainbow ~= nil) and st.IndexUnlockRainbow or true
    local unDM = (st and st.IndexUnlockDarkMatter ~= nil) and st.IndexUnlockDarkMatter or false
    return not ProgAPI.IsIndexComplete(ignMyth, unNorm, unGold, unRain, unDM)
end

function ProgAPI.IsPhase5(): boolean
    if not ProgAPI.AreAllIslandsUnlocked() then return false end
    if not ProgAPI.IsSecretQuestComplete() then return false end
    if not ProgAPI.IsSkillTreeMaxed() then return false end
    -- Phase 4 must be completed first!
    if ProgAPI.IsPhase4() then return false end

    local st = rawget(_G, "State")
    if st and st.AutoClickSkin == false then return false end

    -- Active while ClickSkin target goal (+3 Egg Hatch & +15% Speed) has NOT been met
    return not ProgAPI.IsClickSkinGoalMet()
end

function ProgAPI.IsPhase6(): boolean
    if not ProgAPI.AreAllIslandsUnlocked() then return false end
    if not ProgAPI.IsSecretQuestComplete() then return false end
    if not ProgAPI.IsSkillTreeMaxed() then return false end
    -- Phase 4 must be completed first!
    if ProgAPI.IsPhase4() then return false end

    local st = rawget(_G, "State")
    -- If Phase 5 (ClickSkin) is disabled, Phase 6 activates immediately after Phase 4!
    if st and st.AutoClickSkin == false then
        return true
    end

    -- If Phase 5 is enabled, Phase 6 activates once Phase 5 goal is met!
    return ProgAPI.IsClickSkinGoalMet()
end

function ProgAPI.TeleportToSpawnDoor(): boolean
    if ProgAPI.IsInMinigame and ProgAPI.IsInMinigame() then
        ProgAPI.ExitMinigame()
        task.wait(0.3)
    end
    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"
    if curWorld ~= "Overworld" then
        ProgAPI.TeleportToWorld("Overworld")
        task.wait(0.6)
    end
    local curIsland = stats.CurrentIsland or ""
    if curIsland ~= "Spawn" then
        ProgAPI.TeleportToIsland("Spawn")
        task.wait(0.4)
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local door = workspace:FindFirstChild("_MAP")
        and workspace._MAP:FindFirstChild("Islands")
        and workspace._MAP.Islands:FindFirstChild("Spawn")
        and workspace._MAP.Islands.Spawn:FindFirstChild("Map")
        and workspace._MAP.Islands.Spawn.Map:FindFirstChild("Door")
    local interact = door and door:FindFirstChild("Interact")

    if interact and interact:IsA("BasePart") then
        hrp.CFrame = interact.CFrame + Vector3.new(0, 3, 4)
        task.wait(0.1)
        return true
    else
        hrp.CFrame = CFrame.new(-344, 15, 345)
        task.wait(0.1)
        return true
    end
end

function ProgAPI.AcceptSecretQuest(): (boolean, string)
    if not Channels.Quest then return false, "No Quest channel" end
    local stats = Stats.Local(true) or {}
    if stats.SecretAreaQuestClaimed then
        return true, "Quest already claimed/in progress"
    end

    ProgAPI.TeleportToSpawnDoor()
    task.wait(0.2)

    local ok, res, msg = pcall(function()
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

    if ok and res == true then
        return true, tostring(msg or "Quest Accepted")
    end
    return false, tostring(msg or res or "Failed to accept quest")
end

function ProgAPI.CollectSecretFeathers(): number
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local feathersFolder = workspace:FindFirstChild("_THINGS") and workspace._THINGS:FindFirstChild("Feathers")
    if not feathersFolder then return 0 end

    local stats = Stats.Local(true) or {}
    local collectedTable = stats.SecretAreaCollectedFeathers or {}
    local newlyCollected = 0

    for _, f in ipairs(feathersFolder:GetChildren()) do
        local fName = f.Name
        if collectedTable[fName] ~= true then
            local hitbox = f:FindFirstChild("Hitbox")
            if hitbox and hitbox:IsA("BasePart") then
                if type(firetouchinterest) == "function" then
                    firetouchinterest(hrp, hitbox, 0)
                    task.wait(0.02)
                    firetouchinterest(hrp, hitbox, 1)
                    task.wait(0.01)
                    newlyCollected = newlyCollected + 1
                else
                    local prevCF = hrp.CFrame
                    hrp.CFrame = hitbox.CFrame
                    task.wait(0.08)
                    hrp.CFrame = prevCF
                    newlyCollected = newlyCollected + 1
                end
            end
        end
    end
    return newlyCollected
end

function ProgAPI.UnlockSecretDoor(): (boolean, string)
    if not Channels.Quest then return false, "No Quest channel" end

    -- 1. Ensure character is physically at Spawn Door in Overworld (exiting any minigame)
    ProgAPI.TeleportToSpawnDoor()
    task.wait(0.3)

    -- 2. Claim all 4 secret quest objectives
    for _, qId in ipairs({"secret_click_1", "secret_feathers", "secret_craft_golden", "secret_hatch_eggs"}) do
        pcall(function()
            Channels.Quest:InvokeServer("Claim", qId, 1)
        end)
    end
    task.wait(0.15)

    -- 3. Invoke questline unlock remote to trigger door unlock
    local ok, res, msg = pcall(function()
        return Channels.Quest:InvokeServer("ClaimSecretAreaQuestline")
    end)

    -- 4. Trigger proximity prompt on door interact if available
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

    task.wait(0.5)

    -- 5. Verify if door is confirmed unlocked in player stats or server response
    local stats = Stats.Local(true) or {}
    local isUnlocked = (stats.DominusAreaUnlocked == true) or (ok and (res == true or res == "Unlocked" or msg == "Unlocked"))

    if isUnlocked then
        task.wait(0.5)
        -- Door is unlocked! Now safely enter Dominus Area
        ProgAPI.EnterDominusArea()
        return true, "Spawn Door Unlocked! Entering Dominus Area."
    end

    return false, tostring(msg or res or "Unlocking Spawn Door...")
end

function ProgAPI.StepSecretQuest(): (boolean, string)
    local questInfo = ProgAPI.GetSecretQuestInfo()
    if questInfo.IsDoorUnlocked then
        return true, "Dominus Secret Area Unlocked! Ready for Phase 3 Skill Tree."
    end

    -- 1. Ensure quest is accepted at Spawn door
    if not questInfo.IsClaimed then
        local okAcc, msgAcc = ProgAPI.AcceptSecretQuest()
        return okAcc, "[Phase 2: ???] Accepting Quest: " .. tostring(msgAcc)
    end

    -- 2. Objective 1: Clicks (3,500)
    if not questInfo.Clicks.Done then
        pcall(function() ProgAPI.Click(25) end)
        return true, string.format("[Phase 2: ???] Clicking (%s / %s)", ProgAPI.FormatNumber(questInfo.Clicks.Progress), ProgAPI.FormatNumber(questInfo.Clicks.Amount))
    end

    -- 3. Objective 2: Feathers (10)
    if not questInfo.Feathers.Done then
        local count = ProgAPI.CollectSecretFeathers()
        return true, string.format("[Phase 2: ???] Collecting Feathers (%d / %d)", questInfo.Feathers.Progress, questInfo.Feathers.Amount)
    end

    -- 4. Objective 3: Golden Pets (15) - User instruction: use BasicEgg from World 1 Spawn
    if not questInfo.Golden.Done then
        local crafted = ProgAPI.CraftGoldenPets()
        if crafted > 0 then
            return true, string.format("[Phase 2: ???] Crafted %d Golden Pets (%d / %d)", crafted, questInfo.Golden.Progress, questInfo.Golden.Amount)
        else
            local eggName = "BasicEgg"
            local stats = Stats.Local(true) or {}
            local curWorld = stats.CurrentWorld or "Overworld"
            local curIsland = stats.CurrentIsland or ""
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local _, targetPart = ProgAPI.FindEggModel(eggName)
            local dist = (hrp and targetPart) and (hrp.Position - targetPart.Position).Magnitude or 9999

            -- Explicitly invoke the official server portal/island teleport remote if not already positioned at BasicEgg on Spawn!
            if curWorld ~= "Overworld" or curIsland ~= "Spawn" or dist > 16 or (ProgAPI.IsInMinigame and ProgAPI.IsInMinigame()) then
                ProgAPI.TeleportToEgg(eggName)
                task.wait(0.3)
            end

            local openAmount = math.min(8, ProgAPI.GetMaxEggOpenAmount(eggName))
            ProgAPI.OpenEgg(eggName, openAmount, false)
            task.wait(0.08)
            pcall(ProgAPI.CraftGoldenPets)
            pcall(ProgAPI.CleanWeakPets)
            return true, string.format("[Phase 2: ???] Hatching %s at Spawn to craft Golden (%d / %d)", eggName, questInfo.Golden.Progress, questInfo.Golden.Amount)
        end
    end

    -- 5. Objective 4: Hatch Eggs (2,500) - After Gold is Done!
    -- User rule: Auto delete pets after gold is done so it does not clump up inventory!
    if not questInfo.Hatch.Done then
        local eggName = "BasicEgg"
        local stats = Stats.Local(true) or {}
        local curWorld = stats.CurrentWorld or "Overworld"
        local curIsland = stats.CurrentIsland or ""
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local _, targetPart = ProgAPI.FindEggModel(eggName)
        local dist = (hrp and targetPart) and (hrp.Position - targetPart.Position).Magnitude or 9999

        -- Explicitly invoke the official server portal/island teleport remote if not already positioned at BasicEgg on Spawn!
        if curWorld ~= "Overworld" or curIsland ~= "Spawn" or dist > 16 or (ProgAPI.IsInMinigame and ProgAPI.IsInMinigame()) then
            ProgAPI.TeleportToEgg(eggName)
            task.wait(0.3)
        end

        local openAmount = math.min(8, ProgAPI.GetMaxEggOpenAmount(eggName))
        ProgAPI.OpenEgg(eggName, openAmount, false)
        -- Auto delete all BasicEgg pets (Dog, Cat, Bunny, Pig - Normal & Golden) immediately
        pcall(ProgAPI.CleanSecretQuestPets)
        return true, string.format("[Phase 2: ???] Hatching %s at Spawn (%s / %s)", eggName, ProgAPI.FormatNumber(questInfo.Hatch.Progress), ProgAPI.FormatNumber(questInfo.Hatch.Amount))
    end

    -- 6. All 4 quests are done, but door not unlocked yet: TP to door & unlock!
    if not questInfo.IsDoorUnlocked then
        local okDoor, msgDoor = ProgAPI.UnlockSecretDoor()
        return okDoor, "[Phase 2: ???] " .. tostring(msgDoor)
    end

    return true, "Dominus Secret Area Unlocked! Ready for Phase 3 Skill Tree."
end

--==============================================================================
-- PHASE 4: AUTO INDEX PETS PIPELINE
-- Cycles through all progression eggs from World 1 Spawn upwards,
-- registering missing pets across Normal, Gold, and Rainbow variants,
-- skips ultra-rare drops (Mythic, Secret, Divine, Exclusive) if enabled,
-- keeps high-tier pets permanently, and deletes indexed fodder.
--==============================================================================

function ProgAPI.GetTotalIndexStats(): {
    IndexedNormal: number,
    IndexedGolden: number,
    IndexedRainbow: number,
    IndexedShiny: number,
    TotalIndexed: number,
    TotalUniquePets: number,
    ProgressionUniquePets: number
}
    local stats = Stats.Local(true) or {}
    local obtained = stats.ObtainedPets or {}

    local normalCount = 0
    local goldenCount = 0
    local rainbowCount = 0
    local shinyCount = 0
    local totalIndexed = 0

    for key, val in pairs(obtained) do
        if val == true then
            totalIndexed = totalIndexed + 1
            if key:find("_Normal") then
                normalCount = normalCount + 1
            elseif key:find("_Golden") then
                goldenCount = goldenCount + 1
            elseif key:find("_Rainbow") then
                rainbowCount = rainbowCount + 1
            elseif key:find("_Shiny") then
                shinyCount = shinyCount + 1
            end
        end
    end

    local totalUnique = 0
    if Directory and Directory.Pets then
        for _ in pairs(Directory.Pets) do
            totalUnique = totalUnique + 1
        end
    end
    if totalUnique == 0 then totalUnique = 401 end

    return {
        IndexedNormal = normalCount,
        IndexedGolden = goldenCount,
        IndexedRainbow = rainbowCount,
        IndexedShiny = shinyCount,
        TotalIndexed = totalIndexed,
        TotalUniquePets = totalUnique,
        ProgressionUniquePets = 269
    }
end

function ProgAPI.IsPetIndexed(petId: string, variant: string): boolean
    local stats = Stats.Local(true) or {}
    local obtained = stats.ObtainedPets or {}
    local key = petId .. "_" .. variant
    return obtained[key] == true
end

function ProgAPI.GetEggIndexProgress(
    eggName: string,
    ignoreMythicAndAbove: boolean?,
    unlockNormal: boolean?,
    unlockGold: boolean?,
    unlockRainbow: boolean?,
    unlockDM: boolean?,
    includeGoldLegendary: boolean?,
    includeRainbowLegendary: boolean?
)
    if ignoreMythicAndAbove == nil then ignoreMythicAndAbove = true end
    if unlockNormal == nil then unlockNormal = true end
    if unlockGold == nil then unlockGold = true end
    if unlockRainbow == nil then unlockRainbow = false end
    if unlockDM == nil then unlockDM = false end
    if includeGoldLegendary == nil then includeGoldLegendary = false end
    if includeRainbowLegendary == nil then includeRainbowLegendary = false end

    local stats = Stats.Local(true) or {}
    local obtained = stats.ObtainedPets or {}
    local eggDef = nil
    pcall(function()
        if Directory and Directory.Eggs then
            eggDef = Directory.Eggs[eggName]
        end
    end)

    if not eggDef or not eggDef.Pets then
        return {
            EggName = eggName,
            DisplayName = eggName,
            IsComplete = true,
            TargetPetsCount = 0,
            CompletedPetsCount = 0,
            MissingPets = {},
            QueuedRainbows = {},
            SkippedRareCount = 0,
            SkippedRares = {}
        }
    end

    local st = rawget(_G, "State")
    local targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    local currentTotalIndexed = (totalStats and totalStats.TotalIndexed) or 0
    if currentTotalIndexed >= targetTotal then
        return {
            EggName = eggName,
            DisplayName = eggDef.Name or eggName,
            IsComplete = true,
            TargetPetsCount = 0,
            CompletedPetsCount = 0,
            MissingPets = {},
            QueuedRainbows = {},
            SkippedRareCount = 0,
            SkippedRares = {}
        }
    end

    local rainbowStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
    local totalCookingRainbows = (rainbowStatus and rainbowStatus.TotalCooking) or 0
    -- Rainbow is optional filler towards 250 index goal: only required if totalIndexed + cooking < targetTotal
    local needRainbowForTarget = unlockRainbow and ((currentTotalIndexed + totalCookingRainbows) < targetTotal)

    local targetPets = {}
    local skippedRares = {}

    for _, drop in ipairs(eggDef.Pets) do
        local petId = drop.Value or drop.Pet or drop.Id
        if petId then
            local petDef = nil
            pcall(function()
                if Directory and Directory.Pets then
                    petDef = Directory.Pets[petId]
                end
            end)
            local rarity = (petDef and petDef.Rarity) or "Unknown"
            local petName = (petDef and (petDef.Name or petDef.Title)) or petId

            local isRare = false
            if Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] then
                isRare = Constants.RarityOrder[rarity] >= 5
            else
                local rLower = tostring(rarity):lower()
                isRare = rLower:find("mythic") ~= nil or rLower:find("secret") ~= nil
                    or rLower:find("divine") ~= nil or rLower:find("exclusive") ~= nil
                    or rLower:find("mega") ~= nil or rLower:find("special") ~= nil
            end

            if isRare and ignoreMythicAndAbove then
                table.insert(skippedRares, {
                    PetId = petId,
                    Name = petName,
                    Rarity = rarity
                })
            else
                table.insert(targetPets, {
                    PetId = petId,
                    Name = petName,
                    Rarity = rarity
                })
            end
        end
    end

    local activeOrQueuedRainbow = ProgAPI.GetActiveAndQueuedRainbowPetIds and ProgAPI.GetActiveAndQueuedRainbowPetIds() or {}
    local missingList = {}
    local queuedRainbows = {}
    local completedCount = 0

    for _, target in ipairs(targetPets) do
        local pId = target.PetId
        local rarity = target.Rarity or "Unknown"
        local rOrder = (Constants and Constants.RarityOrder and Constants.RarityOrder[rarity]) or 1

        -- Normal: Common, Rare, Epic, Legendary (order <= 4)
        local isNormalEligible = rOrder <= 4

        -- Gold: Common, Rare, Epic always eligible. Legendary is eligible ONLY in Stage 2 (includeGoldLegendary == true)!
        local isGoldEligible = (rOrder <= 3 and rarity ~= "Legendary")
            or (includeGoldLegendary == true and (rarity == "Legendary" or rOrder == 4))

        -- Rainbow: Basic and Rare ONLY! (rOrder <= 2, Common/Basic and Rare). Legendary ONLY if includeRainbowLegendary == true.
        local isRainbowEligible = (rOrder <= 2 and rarity ~= "Epic" and rarity ~= "Legendary")
            or (includeRainbowLegendary == true and (rarity == "Legendary" or rOrder == 4))

        local missingVariants = {}
        local isQueuedRainbow = false

        if unlockNormal and isNormalEligible and obtained[pId .. "_Normal"] ~= true then
            table.insert(missingVariants, "Normal")
        end
        if unlockGold and isGoldEligible and obtained[pId .. "_Golden"] ~= true then
            table.insert(missingVariants, "Golden")
        end

        -- Rainbow variant check: ONLY required if unlockRainbow is true, target 250 not reached, and pet is Common/Rare/Epic (NO Legendary)
        if needRainbowForTarget and isRainbowEligible then
            if obtained[pId .. "_Rainbow"] ~= true then
                if activeOrQueuedRainbow[pId] == true then
                    -- Already in Rainbow Machine (cooking 30-min craft or waiting in queue)!
                    -- Does NOT block the egg from being completed / moving to next egg!
                    isQueuedRainbow = true
                    table.insert(queuedRainbows, {
                        PetId = pId,
                        Name = target.Name
                    })
                else
                    table.insert(missingVariants, "Rainbow")
                end
            end
        end

        if unlockDM and obtained[pId .. "_DarkMatter"] ~= true then
            table.insert(missingVariants, "DarkMatter")
        end

        if #missingVariants > 0 then
            table.insert(missingList, {
                PetId = pId,
                Name = target.Name,
                Rarity = target.Rarity,
                MissingVariants = missingVariants,
                RainbowQueued = isQueuedRainbow
            })
        else
            completedCount = completedCount + 1
        end
    end

    local isDone = (#missingList == 0) and (#targetPets > 0)
    local dispName = (eggDef.Name or eggDef.DisplayName) or eggName

    return {
        EggName = eggName,
        DisplayName = dispName,
        IsComplete = isDone,
        TargetPetsCount = #targetPets,
        CompletedPetsCount = completedCount,
        MissingPets = missingList,
        QueuedRainbows = queuedRainbows,
        SkippedRareCount = #skippedRares,
        SkippedRares = skippedRares
    }
end

function ProgAPI.GetNextUnindexedEgg(
    ignoreMythicAndAbove: boolean?,
    unlockNormal: boolean?,
    unlockGold: boolean?,
    unlockRainbow: boolean?,
    unlockDM: boolean?
)
    if ignoreMythicAndAbove == nil then ignoreMythicAndAbove = true end
    if unlockNormal == nil then unlockNormal = true end
    if unlockGold == nil then unlockGold = true end
    if unlockRainbow == nil then unlockRainbow = true end
    if unlockDM == nil then unlockDM = false end

    local st = rawget(_G, "State")
    local targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    local curIndexed = (totalStats and totalStats.TotalIndexed) or 0
    if curIndexed >= targetTotal then
        return nil, nil -- Target reached! All done!
    end

    -- =========================================================================
    -- STAGE 1: FAST BASE SWEEP ACROSS ALL WORLDS
    -- Normal: Common, Rare, Epic, Legendary
    -- Gold: Common, Rare, Epic ONLY (Legendary deferred for speedrun)
    -- =========================================================================
    if unlockNormal or unlockGold then
        for _, e in ipairs(REAL_PROGRESSION_EGGS) do
            local prog = ProgAPI.GetEggIndexProgress(
                e.name,
                ignoreMythicAndAbove,
                unlockNormal,
                unlockGold,
                false, -- unlockRainbow is strictly FALSE during Stage 1
                unlockDM,
                false, -- includeGoldLegendary = false
                false  -- includeRainbowLegendary = false
            )
            if not prog.IsComplete then
                prog.IndexStage = "Stage 1: Normal & Easy Gold (Common..Epic)"
                prog.StageCode = 1
                return e, prog
            end
        end
    end

    -- =========================================================================
    -- STAGE 2: RAINBOW PRIORITY (BASIC & RARE ONLY)
    -- User rule: "after all normal until legendary is done auto gold until epic is done
    -- then start auto rainbow until only in basic and rare only"
    -- =========================================================================
    local rainbowStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
    local cookingCount = (rainbowStatus and rainbowStatus.TotalCooking) or 0

    if unlockRainbow and (curIndexed + cookingCount) < targetTotal then
        for _, e in ipairs(REAL_PROGRESSION_EGGS) do
            local prog = ProgAPI.GetEggIndexProgress(
                e.name,
                ignoreMythicAndAbove,
                false, -- Normal already 100% complete across all worlds
                false, -- Gold already 100% complete across all worlds
                true,  -- unlockRainbow = true (Basic & Rare ONLY)
                unlockDM,
                false, -- includeGoldLegendary = false
                false  -- includeRainbowLegendary = false (Basic & Rare ONLY!)
            )
            if not prog.IsComplete then
                prog.IndexStage = "Stage 2: Rainbow (Basic & Rare Only)"
                prog.StageCode = 2
                return e, prog
            end
        end
    end

    return nil, nil
end

function ProgAPI.IsIndexComplete(
    ignoreMythicAndAbove: boolean?,
    unlockNormal: boolean?,
    unlockGold: boolean?,
    unlockRainbow: boolean?,
    unlockDM: boolean?
): boolean
    local st = rawget(_G, "State")
    local targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    if totalStats and totalStats.TotalIndexed >= targetTotal then
        return true -- Target reached!
    end

    local egg = ProgAPI.GetNextUnindexedEgg(
        ignoreMythicAndAbove,
        unlockNormal,
        unlockGold,
        unlockRainbow,
        unlockDM
    )
    return egg == nil
end

function ProgAPI.CleanIndexedFodder(
    unlockGold: boolean?,
    unlockRainbow: boolean?,
    includeGoldLegendary: boolean?,
    includeRainbowLegendary: boolean?
): number
    if unlockGold == nil then unlockGold = true end
    if unlockRainbow == nil then unlockRainbow = true end
    if includeGoldLegendary == nil then includeGoldLegendary = false end
    if includeRainbowLegendary == nil then includeRainbowLegendary = false end

    local stats = Stats.Local(true) or {}
    local pets = stats.Pets or {}
    local equipped = stats.EquippedPets or {}
    local obtained = stats.ObtainedPets or {}
    local activeOrQueuedRainbow = ProgAPI.GetActiveAndQueuedRainbowPetIds and ProgAPI.GetActiveAndQueuedRainbowPetIds() or {}

    local st = rawget(_G, "State")
    local targetTotal = (st and tonumber(st.IndexTargetTotal)) or 250
    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    local currentTotalIndexed = (totalStats and totalStats.TotalIndexed) or 0
    local rainbowStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
    local totalCookingRainbows = (rainbowStatus and rainbowStatus.TotalCooking) or 0
    local needRainbowForTarget = unlockRainbow and ((currentTotalIndexed + totalCookingRainbows) < targetTotal)

    -- Count unequipped copies per petId to avoid deleting crafting ingredients
    local normalCounts = {}
    local goldenCounts = {}
    for guid, p in pairs(pets) do
        if not equipped[guid] and not p.Locked and not p.l then
            local pid = p.id or p.PetId
            local isGold = (p.Variant == "Golden" or p.variant == "Golden" or p.g == true)
            local isRainbow = (p.Variant == "Rainbow" or p.variant == "Rainbow" or p.r == true)
            if pid and not isGold and not isRainbow then
                normalCounts[pid] = (normalCounts[pid] or 0) + 1
            elseif pid and isGold then
                goldenCounts[pid] = (goldenCounts[pid] or 0) + 1
            end
        end
    end

    local toDelete = {}
    local preservedForGold = {}
    local preservedForRainbow = {}

    for guid, p in pairs(pets) do
        if not equipped[guid] and not p.Locked and not p.l then
            -- ABSOLUTE SAFETY: Strictly NEVER delete Mythic, Secret, Divine, Mega, Special, or Exclusive pets!
            local isMythicOrAbove = ProgAPI.IsMythicOrAbove(p)
            if not isMythicOrAbove then
                local pid = p.id or p.PetId
                local isGold = (p.Variant == "Golden" or p.variant == "Golden" or p.g == true)
                local isRainbow = (p.Variant == "Rainbow" or p.variant == "Rainbow" or p.r == true)

                local petDef = Directory.Pets and Directory.Pets[pid]
                local rarity = (petDef and petDef.Rarity) or "Basic"
                local isGoldEligible = (rarity == "Basic" or rarity == "Rare" or rarity == "Common" or rarity == "Epic") and (rarity ~= "Legendary")
                if Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] then
                    isGoldEligible = (Constants.RarityOrder[rarity] <= 3) and (rarity ~= "Legendary")
                end
                if includeGoldLegendary == true and (rarity == "Legendary" or (Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] == 4)) then
                    isGoldEligible = true
                end

                local isRainbowEligible = (rarity == "Basic" or rarity == "Rare" or rarity == "Common") and (rarity ~= "Epic" and rarity ~= "Legendary")
                if Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] then
                    isRainbowEligible = (Constants.RarityOrder[rarity] <= 2) and (rarity ~= "Epic" and rarity ~= "Legendary")
                end
                if includeRainbowLegendary == true and (rarity == "Legendary" or (Constants and Constants.RarityOrder and Constants.RarityOrder[rarity] == 4)) then
                    isRainbowEligible = true
                end

                local hasNormalIndex = (obtained[pid .. "_Normal"] == true)
                local hasGoldIndex = (obtained[pid .. "_Golden"] == true)
                local hasRainbowIndex = (obtained[pid .. "_Rainbow"] == true)
                local isRainbowQueued = (activeOrQueuedRainbow[pid] == true)

                local shouldKeep = false

                -- If Gold index is needed (Common/Rare/Epic only, NO Legendary) and this is a normal pet, preserve up to 10 copies to craft Gold
                if unlockGold and isGoldEligible and not hasGoldIndex and not isGold and not isRainbow then
                    preservedForGold[pid] = (preservedForGold[pid] or 0) + 1
                    if preservedForGold[pid] <= 10 then
                        shouldKeep = true
                    end
                end

                -- If Rainbow index is needed for Common/Rare/Epic (NO Legendary) and not yet indexed and not yet queued:
                -- preserve up to 6 golden copies to start a 100% 30-min craft!
                if needRainbowForTarget and isRainbowEligible and not hasRainbowIndex and not isRainbowQueued and isGold then
                    preservedForRainbow[pid] = (preservedForRainbow[pid] or 0) + 1
                    if preservedForRainbow[pid] <= 6 then
                        shouldKeep = true
                    end
                end

                -- If this pet has already fulfilled all active index requirements, it is fodder -> safe to delete!
                if not shouldKeep then
                    local normalSatisfied = (not unlockNormal) or hasNormalIndex
                    local goldSatisfied = (not unlockGold) or (not isGoldEligible) or hasGoldIndex
                    local rainbowSatisfied = (not needRainbowForTarget) or (not isRainbowEligible) or hasRainbowIndex or isRainbowQueued

                    if normalSatisfied and goldSatisfied and rainbowSatisfied then
                        table.insert(toDelete, guid)
                    end
                end
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

function ProgAPI.StepAutoIndex(
    ignoreMythicAndAbove: boolean?,
    unlockNormal: boolean?,
    unlockGold: boolean?,
    unlockRainbow: boolean?,
    unlockDM: boolean?
): (boolean, string)
    local nextEgg, eggProg = ProgAPI.GetNextUnindexedEgg(
        ignoreMythicAndAbove,
        unlockNormal,
        unlockGold,
        unlockRainbow,
        unlockDM
    )

    if not nextEgg or not eggProg then
        return true, "All progression eggs / target index goals complete! Phase 4 complete."
    end

    local stageCode = eggProg.StageCode or 1
    local isRainbowStage = (stageCode == 2)
    local includeRainLeg = false
    local pData = ProgAPI.GetPlayerData()
    local clicks = pData.Clicks or 0

    -- Check if player can afford egg
    if clicks < nextEgg.cost then
        return false, string.format("[Phase 4: %s] Saving clicks for %s (%s / %s)",
            tostring(eggProg.IndexStage or "Index Progression"),
            tostring(nextEgg.name),
            ProgAPI.FormatNumber(clicks),
            ProgAPI.FormatNumber(nextEgg.cost)
        )
    end

    -- Identify target egg, island, and world
    local eggMeta = eggData[nextEgg.name] or (Directory and Directory.Eggs and Directory.Eggs[nextEgg.name])
    local targetIsland = eggMeta and (eggMeta.island or eggMeta.Island) or "Spawn"
    local meta = islandMetaLookup[targetIsland] or (Directory and Directory.Islands and Directory.Islands[targetIsland])
    local targetWorld = (meta and (meta.world or meta.World)) or "Overworld"
    if targetIsland == "Base" or targetIsland == "Spaceship" or targetIsland == "Fragment" or targetIsland == "Matrix"
        or nextEgg.name == "TechEgg" or nextEgg.name == "HolographicEgg" or nextEgg.name == "404Egg"
        or nextEgg.name == "RedTechEgg" or nextEgg.name == "FragmentedEgg" or nextEgg.name == "MatrixEgg" then
        targetWorld = "Techworld"
    else
        targetWorld = "Overworld"
    end

    local stats = Stats.Local(true) or {}
    local curWorld = stats.CurrentWorld or "Overworld"
    local curIsland = stats.CurrentIsland or ""
    local inMinigame = (ProgAPI.IsInMinigame and ProgAPI.IsInMinigame())

    local eggModel, targetPart = ProgAPI.FindEggModel(nextEgg.name)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local dist = (hrp and targetPart) and (hrp.Position - targetPart.Position).Magnitude or 999
    local isNearby = (dist <= 16) or (nextEgg.name == "MatrixEgg" and hrp and (hrp.Position - Vector3.new(7828.7, 6196.1, 303.1)).Magnitude <= 16)

    local isNewEgg = (rawget(ProgAPI, "_CurrentIndexEgg") ~= nextEgg.name)
    local worldMismatch = (curWorld ~= targetWorld)

    -- Teleport ONLY IF:
    -- 1. Currently in a minigame
    -- 2. In the wrong world (curWorld ~= targetWorld)
    -- 3. Not nearby the target egg (dist > 16 studs)
    if inMinigame or worldMismatch or not isNearby then
        -- 1. Exit minigame if in one
        if inMinigame then
            ProgAPI.ExitMinigame()
            task.wait(0.3)
        end

        -- 2. World Remote: ONLY invoke TeleportToWorld if in the WRONG WORLD!
        -- If player is already in targetWorld, NEVER invoke TeleportToWorld (it teleports to Tech World Spawn)!
        if worldMismatch then
            if Channels.Portals then
                pcall(function()
                    Channels.Portals:InvokeServer("TeleportToWorld", targetWorld)
                end)
                task.wait(0.4)
            else
                ProgAPI.TeleportToWorld(targetWorld, true)
                task.wait(0.4)
            end
        end

        -- 3. Island Remote: invoke if island is not Spawn
        if targetIsland ~= "Spawn" and Channels.Portals then
            pcall(function()
                Channels.Portals:InvokeServer("TeleportToIsland", targetIsland)
            end)
            task.wait(0.15)
        end
        if IslandsFrontend and IslandsFrontend.LocalTeleport then
            pcall(function()
                IslandsFrontend.LocalTeleport(targetIsland)
            end)
        end

        -- 4. Teleport directly to the egg stand
        ProgAPI.TeleportToEgg(nextEgg.name, false)
        task.wait(0.1)
        ProgAPI._CurrentIndexEgg = nextEgg.name
    else
        -- Already standing at the egg in the correct world: keep locked onto platform
        ProgAPI._CurrentIndexEgg = nextEgg.name
        if hrp and targetPart and dist > 8 then
            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
        end
    end

    -- Multi-hatch at maximum speed without redundant teleportation
    local hatchAmount = ProgAPI.GetMaxEggOpenAmount(nextEgg.name)
    local openOk, openMsg = ProgAPI.OpenEgg(nextEgg.name, hatchAmount, true)

    -- Auto craft golden pets FIRST (Normal > Gold priority in Stage 1 & 2)
    if unlockGold then
        pcall(ProgAPI.CraftGoldenPets)
    end

    -- Rainbow crafting: ONLY executed during Stage 2 (Rainbow stage, Basic & Rare ONLY)
    if isRainbowStage and unlockRainbow then
        pcall(function()
            ProgAPI.CraftRainbowPets(true, false)
        end)
    end
    -- Always claim ready rainbow crafts in background
    pcall(ProgAPI.ClaimRainbowPets)

    -- Sweep and delete indexed fodder (while protecting Mythics/Secrets!)
    pcall(function()
        ProgAPI.CleanIndexedFodder(unlockGold, isRainbowStage and unlockRainbow, false, false)
    end)

    local missingNames = {}
    for _, m in ipairs(eggProg.MissingPets) do
        table.insert(missingNames, string.format("%s (%s)", m.Name, table.concat(m.MissingVariants, "/")))
    end
    local queuedStr = ""
    if eggProg.QueuedRainbows and #eggProg.QueuedRainbows > 0 then
        local qNames = {}
        for _, q in ipairs(eggProg.QueuedRainbows) do
            table.insert(qNames, q.Name)
        end
        queuedStr = string.format(" [Queued 🌈: %s]", table.concat(qNames, ", "))
    end
    local missingStr = #missingNames > 0 and table.concat(missingNames, ", ") or "All Active Goals Done"

    local totalStats = ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()
    local curTotal = (totalStats and totalStats.TotalIndexed) or 0
    local rbStatus = ProgAPI.GetRainbowMachineStatus and ProgAPI.GetRainbowMachineStatus()
    local cooking = (rbStatus and rbStatus.TotalCooking) or 0

    local stageLabel = eggProg.IndexStage or "Index Progression"
    return false, string.format("[Phase 4: %s (%d%s/250)] %s (%d/%d): Missing %s%s",
        stageLabel,
        curTotal,
        cooking > 0 and ("+" .. tostring(cooking)) or "",
        tostring(eggProg.DisplayName),
        eggProg.CompletedPetsCount,
        eggProg.TargetPetsCount,
        missingStr,
        queuedStr
    )
end

--==============================================================================
-- PHASE 6: ENDGAME MATRIX MYTHIC PIPELINE
-- Activates once Phase 5 (Ultimate Click Skin) is complete (or bypassed)!
--==============================================================================
-- Phase 6 Dedicated Pet Filter: Keeps ONLY High-Tier & Protected pets!
-- STRICTLY PRESERVES Exclusive, Secret, Stock, Divine, Mega, Mythic, Mythical, Special pets
-- Deletes strictly confirmed low-tier fodder (Basic, Rare, Epic, Legendary)
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

-- Backward compatibility alias
function ProgAPI.GetSecretQuestProgress()
    return ProgAPI.GetSecretQuestInfo()
end

--==============================================================================
-- PERFORMANCE & MISC OPTIMIZATIONS (Black Screen 3D Render & Remove Maps)
--==============================================================================
local blackScreenGui = nil
local savedGuiStates = {}
local blackScreenInputConn = nil
local blackScreenRefreshTask = nil
local blackScreenChildAddedConn = nil
local blackScreenPropConns = {}
local blackScreenTradeConn = nil
local blackScreenRowLabels = {}
local originalTransparencies = {}
local isMapsRemoved = false

ProgAPI.OnBlackScreenToggled = nil

updateBlackScreenTelemetry = function()
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    if not blackScreenGui or not blackScreenGui.Parent or not blackScreenGui.Enabled then
        local found = (pg and pg:FindFirstChild("ClickerHub_BlackScreen"))
            or (game:GetService("CoreGui") and pcall(function() return game:GetService("CoreGui"):FindFirstChild("ClickerHub_BlackScreen") end) and game:GetService("CoreGui"):FindFirstChild("ClickerHub_BlackScreen"))
            or _G.__ProgAPI_BlackScreenGui
        if found and found.Enabled and found.Parent then
            blackScreenGui = found
        else
            return
        end
    end

    local labels = _G.__ProgAPI_BlackScreenLabels or blackScreenRowLabels
    if not labels or not labels.Activity then
        local main = blackScreenGui:FindFirstChild("MainContent")
        if main then
            local list = main:FindFirstChild("RowsList")
            if list then
                labels = labels or {}
                for _, r in ipairs(list:GetChildren()) do
                    if r:IsA("Frame") and r.Name:sub(1, 4) == "Row_" then
                        local key = r.Name:sub(5)
                        local val = r:FindFirstChild("Value")
                        if val and val:IsA("TextLabel") then
                            labels[key] = val
                        end
                    end
                end
                local footer = main:FindFirstChild("Footer")
                if footer then
                    local fl = footer:FindFirstChild("FooterLeft")
                    if fl and fl:IsA("TextLabel") then
                        labels.FooterLeft = fl
                    end
                end
                _G.__ProgAPI_BlackScreenLabels = labels
                blackScreenRowLabels = labels
            end
        end
    end
    if not labels then return end

    local pData = (ProgAPI.GetPlayerData and ProgAPI.GetPlayerData()) or {}
    local StatsMod = Stats
    if not StatsMod then
        pcall(function()
            local lib = game:GetService("ReplicatedStorage"):FindFirstChild("Library")
            local client = lib and lib:FindFirstChild("Client")
            StatsMod = require(client and client:FindFirstChild("Stats") or Client:WaitForChild("Stats", 2))
        end)
    end
    local stats = (StatsMod and StatsMod.Local and StatsMod.Local(true)) or {}
    local Currency = nil
    pcall(function()
        local lib = game:GetService("ReplicatedStorage"):FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        Currency = require(client and client:FindFirstChild("Currency") or Client:WaitForChild("Currency", 2))
    end)

    -- 1. Status & Phase determination
    local statusText = "Running | World Progression"
    if ProgAPI.IsPhase6 and ProgAPI.IsPhase6() then
        statusText = "Running | Endgame Matrix Mythics"
    elseif ProgAPI.IsPhase5 and ProgAPI.IsPhase5() then
        statusText = "Running | Ultimate Click Skin"
    elseif ProgAPI.IsPhase4 and ProgAPI.IsPhase4() then
        statusText = "Running | Pet Collection"
    elseif ProgAPI.IsPhase3 and ProgAPI.IsPhase3() then
        statusText = "Running | Endgame Skill Tree"
    elseif ProgAPI.IsPhase2 and ProgAPI.IsPhase2() then
        statusText = "Running | ??? Secret Area Quest"
    end

    -- 2. Currencies (Clicks, Gems, Coins, Tech Coins, Tokens)
    local clicks = (stats.Currency and stats.Currency.Clicks) or (Currency and Currency.Get and Currency.Get("Clicks")) or pData.Clicks or 0
    local gems = (stats.Currency and stats.Currency.Gems) or (Currency and Currency.Get and Currency.Get("Gems")) or pData.Gems or 0
    local coins = (stats.Currency and stats.Currency.Coins) or (Currency and Currency.Get and Currency.Get("Coins")) or stats.Coins or 0
    local techCoins = (stats.Currency and (stats.Currency.TechCoins or stats.Currency["Tech Coins"])) or (Currency and Currency.Get and (Currency.Get("TechCoins") or Currency.Get("Tech Coins"))) or stats.TechCoins or 0
    local tokens = (stats.Currency and stats.Currency.Tokens) or (Currency and Currency.Get and Currency.Get("Tokens")) or stats.Tokens or 0

    -- 3. Current Activity & Target Egg
    local eggName = ProgAPI.SelectedEgg or "MatrixEgg"
    local nextEgg, eggProg = nil, nil
    if ProgAPI.IsPhase4 and ProgAPI.IsPhase4() then
        nextEgg, eggProg = ProgAPI.GetNextUnindexedEgg and ProgAPI.GetNextUnindexedEgg()
        if nextEgg and nextEgg.name then eggName = nextEgg.name end
    elseif _G.State and _G.State.SelectedEgg then
        eggName = _G.State.SelectedEgg
    end
    local eggData = Directory.Eggs and Directory.Eggs[eggName]
    local eggDispName = (eggData and (eggData.Name or eggData.DisplayName)) or eggName

    local curActivity = tostring((_G.State and _G.State.Activity) or ProgAPI.CurrentActivity or ("Hatching " .. eggDispName))
    if ProgAPI.IsPhase4 and ProgAPI.IsPhase4() and eggProg and eggProg.MissingPets and #eggProg.MissingPets > 0 then
        local firstMissing = eggProg.MissingPets[1]
        local vList = table.concat(firstMissing.MissingVariants, "/")
        curActivity = string.format("Getting %s %s (%s)", vList, firstMissing.Name, eggDispName)
    end

    -- 4. Rebirths & Prestige
    local rebirths = (stats.Currency and stats.Currency.Rebirths) or pData.Rebirths or 0
    local prestiges = stats.Prestiges or 0
    local rebStr = string.format("%s / %d/2", ProgAPI.FormatNumber(rebirths), prestiges)

    -- 5. World / Island
    local curWorld = tostring(stats.CurrentWorld or pData.CurrentWorld or "Overworld")
    local curIsland = tostring(stats.CurrentIsland or pData.CurrentIsland or "Spawn")
    local worldIslandStr = string.format("%s / %s", curWorld, curIsland)

    -- 6. Pet Collection
    local idx = (ProgAPI.GetTotalIndexStats and ProgAPI.GetTotalIndexStats()) or {}
    local maxPetCount = idx.ProgressionUniquePets or 269
    local petCollStr = string.format("Normal %d/%d | Golden %d/%d | Rainbow %d/%d",
        idx.IndexedNormal or 0, maxPetCount,
        idx.IndexedGolden or 0, maxPetCount,
        idx.IndexedRainbow or 0, maxPetCount
    )

    -- 7. Collection Target
    local collTargetStr = "Progression Target: Active"
    if ProgAPI.IsPhase4 and ProgAPI.IsPhase4() then
        if eggProg and eggProg.MissingPets and #eggProg.MissingPets > 0 then
            local firstMissing = eggProg.MissingPets[1]
            local nDone = (stats.ObtainedPets and stats.ObtainedPets[firstMissing.PetId .. "_Normal"]) and "Completed" or "Doing"
            local gDone = (stats.ObtainedPets and stats.ObtainedPets[firstMissing.PetId .. "_Golden"]) and "Completed" or (nDone == "Completed" and "Doing" or "Pending")
            local rDone = (stats.ObtainedPets and stats.ObtainedPets[firstMissing.PetId .. "_Rainbow"]) and "Completed" or (gDone == "Completed" and "Doing" or "Pending")
            collTargetStr = string.format("%s | Normal: %s | Golden: %s | Rainbow: %s", firstMissing.Name, nDone, gDone, rDone)
        else
            local targetTotal = (_G.State and _G.State.IndexTargetTotal) or 250
            collTargetStr = string.format("Target: 250 Index | Total: %d/%d", idx.TotalIndexed or 0, targetTotal)
        end
    elseif ProgAPI.IsPhase6 and ProgAPI.IsPhase6() then
        local isFullRainbow, rbCount, totalEquipped = false, 0, 0
        if ProgAPI.IsEquippedTeamAllRainbowMythic then
            isFullRainbow, rbCount, totalEquipped = ProgAPI.IsEquippedTeamAllRainbowMythic()
        end
        collTargetStr = string.format("Rainbow Matrix Mythics: %d/%d Equipped", rbCount, totalEquipped)
    elseif ProgAPI.IsPhase5 and ProgAPI.IsPhase5() then
        collTargetStr = "Ultimate Click Skin | Rerolling +3 Hatch & +15% Speed"
    elseif ProgAPI.IsPhase2 and ProgAPI.IsPhase2() then
        collTargetStr = "Dominus Gateway Quest | Objective in progress"
    else
        collTargetStr = string.format("World %d | Highest Island: %s", pData.FurthestWorld or 1, curIsland)
    end

    -- 8. Pet Inventory
    local curPets = 0
    local maxPets = stats.MaxInventoryPets or 200
    pcall(function()
        local petsMod = require(Library.Client.Pets)
        if petsMod and petsMod.GetInventoryCount then curPets = petsMod.GetInventoryCount() end
        if petsMod and petsMod.GetEffectiveMaxInventoryPets then maxPets = petsMod.GetEffectiveMaxInventoryPets() end
    end)
    if curPets == 0 and stats.EquippedPets then
        local count = 0
        for _ in pairs(stats.EquippedPets) do count = count + 1 end
        curPets = count
    end
    local petInvStr = string.format("%d / %d", curPets, maxPets)

    -- 9. Skill Tree
    local treeCount = 0
    for _, v in pairs(stats.SkillTree or {}) do
        if v == true then treeCount = treeCount + 1 end
    end
    local dominusArea = (stats.DominusAreaUnlocked == true) or (stats.SkillTree and stats.SkillTree["SecretArea"] == true)
    local skillTreeStr = string.format("%d/52 | Secret area: %s", treeCount, dominusArea and "Unlocked" or "Locked")

    -- 10. Session Time
    if not _G.__ProgAPI_StartTick then _G.__ProgAPI_StartTick = tick() end
    local sessionTimeStr = ProgAPI.FormatSessionTime()

    -- 11. Apply directly to all labels
    pcall(function()
        if labels.Status then labels.Status.Text = statusText end
        if labels.Activity then labels.Activity.Text = curActivity end
        if labels.SessionTime then labels.SessionTime.Text = sessionTimeStr end
        if labels.Clicks then labels.Clicks.Text = ProgAPI.FormatNumber(clicks) end
        if labels.Gems then labels.Gems.Text = ProgAPI.FormatNumber(gems) end
        if labels.CoinsTechCoins then
            labels.CoinsTechCoins.Text = string.format("%s / %s", ProgAPI.FormatNumber(coins), ProgAPI.FormatNumber(techCoins))
        end
        if labels.RebirthsPrestige then labels.RebirthsPrestige.Text = rebStr end
        if labels.WorldIsland then labels.WorldIsland.Text = worldIslandStr end
        if labels.CurrentEgg then labels.CurrentEgg.Text = eggDispName end
        if labels.PetCollection then labels.PetCollection.Text = petCollStr end
        if labels.CollectionTarget then labels.CollectionTarget.Text = collTargetStr end
        if labels.PetInventory then labels.PetInventory.Text = petInvStr end
        if labels.SkillTree then labels.SkillTree.Text = skillTreeStr end

        if labels.FooterLeft then
            local tradeState = (_G.State and _G.State.AutoAcceptTrade ~= false) and "Auto Accept" or "Disabled"
            labels.FooterLeft.Text = string.format("%s | Trade: %s | Tokens: %s", lp.Name, tradeState, ProgAPI.FormatNumber(tokens))
        end
    end)
end
ProgAPI.UpdateBlackScreenTelemetry = updateBlackScreenTelemetry

function ProgAPI.SetBlackScreen(enabled: boolean)
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    local RunService = game:GetService("RunService")
    local parentTarget = pg

    pcall(function()
        if RunService and RunService.Set3dRenderingEnabled then
            RunService:Set3dRenderingEnabled(not enabled)
        end
    end)

    if enabled then
        -- Suppress and listen for all ScreenGuis in PlayerGui
        local function suppressGui(ch)
            if not ch or not ch:IsA("ScreenGui") then return end
            if ch == blackScreenGui or ch.Name == "ClickerHub_BlackScreen" then return end
            if savedGuiStates[ch] == nil then
                savedGuiStates[ch] = ch.Enabled
            end
            ch.Enabled = false
        end

        if pg then
            for _, ch in ipairs(pg:GetChildren()) do
                suppressGui(ch)
                if ch:IsA("ScreenGui") and ch ~= blackScreenGui and ch.Name ~= "ClickerHub_BlackScreen" and not blackScreenPropConns[ch] then
                    blackScreenPropConns[ch] = ch:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if blackScreenGui and blackScreenGui.Enabled and ch.Enabled and ch ~= blackScreenGui and ch.Name ~= "ClickerHub_BlackScreen" then
                            ch.Enabled = false
                        end
                    end)
                end
            end

            if not blackScreenChildAddedConn then
                blackScreenChildAddedConn = pg.ChildAdded:Connect(function(ch)
                    if ch:IsA("ScreenGui") and ch ~= blackScreenGui and ch.Name ~= "ClickerHub_BlackScreen" then
                        suppressGui(ch)
                        if not blackScreenPropConns[ch] then
                            blackScreenPropConns[ch] = ch:GetPropertyChangedSignal("Enabled"):Connect(function()
                                if blackScreenGui and blackScreenGui.Enabled and ch.Enabled and ch ~= blackScreenGui and ch.Name ~= "ClickerHub_BlackScreen" then
                                    ch.Enabled = false
                                end
                            end)
                        end
                    end
                end)
            end
        end

        -- Auto-decline incoming trade requests during Black Screen ONLY if AutoAcceptTrade is disabled
        if not blackScreenTradeConn then
            pcall(function()
                local TradeFrontend = require(Client:WaitForChild("TradeFrontend", 2))
                if TradeFrontend and TradeFrontend.TradeRequestReceived then
                    blackScreenTradeConn = TradeFrontend.TradeRequestReceived:Connect(function(otherPlayer)
                        local st = rawget(_G, "State")
                        if st and st.AutoAcceptTrade == false then
                            pcall(function()
                                TradeFrontend.TradeRequestDecision(otherPlayer, false)
                            end)
                            pcall(function()
                                local Trading = Channels.Trading or (Network and Network.Channel("Trading"))
                                if Trading then
                                    Trading:InvokeServer("TradeRequestDecision", otherPlayer, false)
                                end
                            end)
                        end
                    end)
                end
            end)
        end

        if not blackScreenGui or not blackScreenGui.Parent then
            -- Clean up old instances across CoreGui, gethui(), and PlayerGui
            pcall(function()
                local cg = game:GetService("CoreGui")
                if cg then
                    for _, inst in ipairs(cg:GetDescendants()) do
                        if inst.Name == "ClickerHub_BlackScreen" and inst ~= blackScreenGui then
                            pcall(function() inst:Destroy() end)
                        end
                    end
                end
            end)
            pcall(function()
                if gethui and type(gethui) == "function" then
                    local h = gethui()
                    if h then
                        for _, inst in ipairs(h:GetDescendants()) do
                            if inst.Name == "ClickerHub_BlackScreen" and inst ~= blackScreenGui then
                                pcall(function() inst:Destroy() end)
                            end
                        end
                    end
                end
            end)
            pcall(function()
                if pg then
                    for _, ch in ipairs(pg:GetChildren()) do
                        if ch.Name == "ClickerHub_BlackScreen" and ch ~= blackScreenGui then
                            pcall(function() ch:Destroy() end)
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
            _G.__ProgAPI_BlackScreenGui = blackScreenGui

            -- Opaque pure black backdrop covering entire screen + huge margin to prevent any light leaking
            local bg = Instance.new("Frame")
            bg.Name = "BlackBackground"
            bg.Size = UDim2.new(1, 4000, 1, 4000)
            bg.Position = UDim2.new(0, -2000, 0, -2000)
            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bg.BackgroundTransparency = 0
            bg.BorderSizePixel = 0
            bg.Active = true
            bg.ZIndex = 1
            bg.Parent = blackScreenGui

            -- Main Dashboard Container (centered, 760px wide, 560px high)
            local main = Instance.new("Frame")
            main.Name = "MainContent"
            main.Size = UDim2.new(0, 760, 0, 560)
            main.AnchorPoint = Vector2.new(0.5, 0.5)
            main.Position = UDim2.new(0.5, 0, 0.5, 0)
            main.BackgroundTransparency = 1
            main.ZIndex = 2
            main.Parent = blackScreenGui

            -- Dynamic UIScale to ensure it fits any window / resolution cleanly without cut-off
            local uiScale = Instance.new("UIScale")
            uiScale.Parent = main
            local function updateScale()
                local cam = workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    local scaleX = (vp.X * 0.92) / 760
                    local scaleY = (vp.Y * 0.92) / 560
                    local s = math.min(1, scaleX, scaleY)
                    uiScale.Scale = math.clamp(s, 0.4, 1.0)
                end
            end
            updateScale()
            if workspace.CurrentCamera then
                workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
            end
            workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                local cam = workspace.CurrentCamera
                if cam then
                    updateScale()
                    cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
                end
            end)

            -- Header: Title & Subtitle
            local title = Instance.new("TextLabel")
            title.Name = "Title"
            title.Text = "CLICKER HUB"
            title.Font = Enum.Font.GothamBlack
            title.TextSize = 34
            title.TextColor3 = Color3.fromRGB(245, 245, 250)
            title.Size = UDim2.new(1, 0, 0, 36)
            title.Position = UDim2.new(0, 0, 0, 6)
            title.TextXAlignment = Enum.TextXAlignment.Center
            title.BackgroundTransparency = 1
            title.Parent = main

            local sub = Instance.new("TextLabel")
            sub.Name = "Subtitle"
            sub.Text = "CLICKER SIMULATOR / KAITUN"
            sub.Font = Enum.Font.GothamBold
            sub.TextSize = 11
            sub.TextColor3 = Color3.fromRGB(115, 120, 130)
            sub.Size = UDim2.new(1, 0, 0, 16)
            sub.Position = UDim2.new(0, 0, 0, 44)
            sub.TextXAlignment = Enum.TextXAlignment.Center
            sub.BackgroundTransparency = 1
            sub.Parent = main

            local rowsContainer = Instance.new("Frame")
            rowsContainer.Name = "RowsList"
            rowsContainer.Size = UDim2.new(1, 0, 0, 455)
            rowsContainer.Position = UDim2.new(0, 0, 0, 68)
            rowsContainer.BackgroundTransparency = 1
            rowsContainer.Parent = main

            local function addCapsuleRow(labelText, defaultVal, yPos, key)
                local row = Instance.new("Frame")
                row.Name = "Row_" .. (key or labelText)
                row.Size = UDim2.new(1, 0, 0, 30)
                row.Position = UDim2.new(0, 0, 0, yPos)
                row.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
                row.BorderSizePixel = 0
                row.Parent = rowsContainer

                local rowCorner = Instance.new("UICorner")
                rowCorner.CornerRadius = UDim.new(0, 6)
                rowCorner.Parent = row

                local rowStroke = Instance.new("UIStroke")
                rowStroke.Color = Color3.fromRGB(36, 38, 46)
                rowStroke.Thickness = 1
                rowStroke.Transparency = 0
                rowStroke.Parent = row

                local lbl = Instance.new("TextLabel")
                lbl.Name = "Label"
                lbl.Text = labelText
                lbl.Font = Enum.Font.GothamMedium
                lbl.TextSize = 13
                lbl.TextColor3 = Color3.fromRGB(155, 160, 170)
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Position = UDim2.new(0, 16, 0, 0)
                lbl.Size = UDim2.new(0.3, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Parent = row

                local val = Instance.new("TextLabel")
                val.Name = "Value"
                val.Text = defaultVal or "..."
                val.Font = Enum.Font.GothamBold
                val.TextSize = 13
                val.TextColor3 = Color3.fromRGB(240, 245, 255)
                val.TextXAlignment = Enum.TextXAlignment.Right
                val.Position = UDim2.new(0.3, 16, 0, 0)
                val.Size = UDim2.new(0.7, -32, 1, 0)
                val.TextTruncate = Enum.TextTruncate.AtEnd
                val.BackgroundTransparency = 1
                val.Parent = row

                return val
            end

            -- Build the 13 exact rows matching the reference dashboard
            blackScreenRowLabels = {}
            -- Section 1: Session Status & Time (3 rows, spacing 34px)
            blackScreenRowLabels.Status = addCapsuleRow("Status", "Running | Pet Collection", 0, "Status")
            blackScreenRowLabels.Activity = addCapsuleRow("Activity", "Getting Rainbow Nebula Wyvern", 34, "Activity")
            blackScreenRowLabels.SessionTime = addCapsuleRow("Session Time", "00:00:15", 68, "SessionTime")

            -- Section 2: Progression Stats & Balances (12px gap -> starts at 114px, spacing 34px)
            blackScreenRowLabels.Clicks = addCapsuleRow("Clicks", "0", 114, "Clicks")
            blackScreenRowLabels.Gems = addCapsuleRow("Gems", "0", 148, "Gems")
            blackScreenRowLabels.CoinsTechCoins = addCapsuleRow("Coins / Tech Coins", "0 / 0", 182, "CoinsTechCoins")
            blackScreenRowLabels.RebirthsPrestige = addCapsuleRow("Rebirths / Prestige", "0 / 0/2", 216, "RebirthsPrestige")
            blackScreenRowLabels.WorldIsland = addCapsuleRow("World / Island", "Spawn / Spawn", 250, "WorldIsland")
            blackScreenRowLabels.CurrentEgg = addCapsuleRow("Current Egg", "MatrixEgg", 284, "CurrentEgg")
            blackScreenRowLabels.PetCollection = addCapsuleRow("Pet Collection", "Normal 0/0 | Golden 0/0 | Rainbow 0/0", 318, "PetCollection")
            blackScreenRowLabels.CollectionTarget = addCapsuleRow("Collection Target", "Progression Target", 352, "CollectionTarget")
            blackScreenRowLabels.PetInventory = addCapsuleRow("Pet Inventory", "0 / 200", 386, "PetInventory")
            blackScreenRowLabels.SkillTree = addCapsuleRow("Skill Tree", "0/52 | Secret area: Locked", 420, "SkillTree")

            -- Bottom Footer (at 528px, height 32px)
            local footerFrame = Instance.new("Frame")
            footerFrame.Name = "Footer"
            footerFrame.Size = UDim2.new(1, 0, 0, 32)
            footerFrame.Position = UDim2.new(0, 0, 0, 528)
            footerFrame.BackgroundTransparency = 1
            footerFrame.Parent = main

            local footerLeft = Instance.new("TextLabel")
            footerLeft.Name = "FooterLeft"
            footerLeft.Text = string.format("%s | Trade: Auto Accept | Tokens: 0", lp.Name)
            footerLeft.Font = Enum.Font.GothamMedium
            footerLeft.TextSize = 12
            footerLeft.TextColor3 = Color3.fromRGB(115, 120, 130)
            footerLeft.TextXAlignment = Enum.TextXAlignment.Left
            footerLeft.Size = UDim2.new(0.65, 0, 1, 0)
            footerLeft.Position = UDim2.new(0, 0, 0, 0)
            footerLeft.BackgroundTransparency = 1
            footerLeft.Parent = footerFrame
            blackScreenRowLabels.FooterLeft = footerLeft

            local disableBtn = Instance.new("TextButton")
            disableBtn.Name = "DisableBtn"
            disableBtn.Size = UDim2.new(0, 160, 0, 32)
            disableBtn.Position = UDim2.new(1, -196, 0, 0)
            disableBtn.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
            disableBtn.BorderSizePixel = 0
            disableBtn.Text = "Disable Black Screen"
            disableBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
            disableBtn.TextSize = 12
            disableBtn.Font = Enum.Font.GothamBold
            disableBtn.AutoButtonColor = true
            disableBtn.Parent = footerFrame

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = disableBtn

            local btnStroke = Instance.new("UIStroke")
            btnStroke.Color = Color3.fromRGB(48, 52, 62)
            btnStroke.Thickness = 1
            btnStroke.Parent = disableBtn

            local logoBadge = Instance.new("Frame")
            logoBadge.Name = "LogoBadge"
            logoBadge.Size = UDim2.new(0, 30, 0, 30)
            logoBadge.Position = UDim2.new(1, -30, 0, 1)
            logoBadge.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
            logoBadge.BorderSizePixel = 0
            logoBadge.Parent = footerFrame

            local badgeCorner = Instance.new("UICorner")
            badgeCorner.CornerRadius = UDim.new(0, 6)
            badgeCorner.Parent = logoBadge

            local badgeStroke = Instance.new("UIStroke")
            badgeStroke.Color = Color3.fromRGB(50, 55, 68)
            badgeStroke.Thickness = 1
            badgeStroke.Parent = logoBadge

            local badgeText = Instance.new("TextLabel")
            badgeText.Name = "BadgeText"
            badgeText.Size = UDim2.new(1, 0, 1, 0)
            badgeText.Text = "CH"
            badgeText.Font = Enum.Font.GothamBlack
            badgeText.TextSize = 13
            badgeText.TextColor3 = Color3.fromRGB(0, 180, 255)
            badgeText.BackgroundTransparency = 1
            badgeText.Parent = logoBadge

            disableBtn.MouseButton1Click:Connect(function()
                ProgAPI.SetBlackScreen(false)
            end)

            _G.__ProgAPI_BlackScreenLabels = blackScreenRowLabels

            pcall(function()
                blackScreenGui.Parent = parentTarget
            end)
        end

        blackScreenGui.Enabled = true
        pcall(updateBlackScreenTelemetry)

        -- Start periodic telemetry refresh & continuous anti-disruption watchdog
        _G.__ProgAPI_IsBlackScreenRunning = true
        if blackScreenRefreshTask then
            pcall(function() task.cancel(blackScreenRefreshTask) end)
            blackScreenRefreshTask = nil
        end
        if _G.__ProgAPI_BlackScreenRefreshTask then
            pcall(function() task.cancel(_G.__ProgAPI_BlackScreenRefreshTask) end)
            _G.__ProgAPI_BlackScreenRefreshTask = nil
        end
        blackScreenRefreshTask = task.spawn(function()
            while _G.__ProgAPI_IsBlackScreenRunning and blackScreenGui and blackScreenGui.Enabled and blackScreenGui.Parent do
                -- 1. Continuously enforce 3D rendering disabled while black screen is active
                pcall(function()
                    if RunService and RunService.Set3dRenderingEnabled then
                        RunService:Set3dRenderingEnabled(false)
                    end
                end)

                -- 2. Ensure blackScreenGui exists, is enabled, and is top-layered
                pcall(function()
                    if blackScreenGui then
                        if parentTarget and blackScreenGui.Parent ~= parentTarget then
                            blackScreenGui.Parent = parentTarget
                        end
                        blackScreenGui.Enabled = true
                        blackScreenGui.DisplayOrder = 2147483647
                    end
                end)

                -- 3. Continuously suppress game ScreenGuis in PlayerGui
                pcall(function()
                    if pg then
                        for _, ch in ipairs(pg:GetChildren()) do
                            if ch:IsA("ScreenGui") and ch ~= blackScreenGui and ch.Name ~= "ClickerHub_BlackScreen" and ch.Enabled then
                                if savedGuiStates[ch] == nil then
                                    savedGuiStates[ch] = ch.Enabled
                                end
                                pcall(function() ch.Enabled = false end)
                            end
                        end
                        if (_G.State and _G.State.AutoAcceptTrade == false) then
                            local trading = pg:FindFirstChild("Trading")
                            if trading and trading.Enabled then trading.Enabled = false end
                        end
                        local msg = pg:FindFirstChild("Message")
                        if msg and msg.Enabled then msg.Enabled = false end
                        local prompt = pg:FindFirstChild("InputPrompt")
                        if prompt and prompt.Enabled then prompt.Enabled = false end
                    end
                end)

                pcall(updateBlackScreenTelemetry)
                task.wait(0.2)
            end
        end)
        _G.__ProgAPI_BlackScreenRefreshTask = blackScreenRefreshTask
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
        _G.__ProgAPI_IsBlackScreenRunning = false
        if blackScreenRefreshTask then
            pcall(function() task.cancel(blackScreenRefreshTask) end)
            blackScreenRefreshTask = nil
        end
        if _G.__ProgAPI_BlackScreenRefreshTask then
            pcall(function() task.cancel(_G.__ProgAPI_BlackScreenRefreshTask) end)
            _G.__ProgAPI_BlackScreenRefreshTask = nil
        end

        if blackScreenInputConn then
            blackScreenInputConn:Disconnect()
            blackScreenInputConn = nil
        end

        if blackScreenChildAddedConn then
            blackScreenChildAddedConn:Disconnect()
            blackScreenChildAddedConn = nil
        end

        if blackScreenTradeConn then
            blackScreenTradeConn:Disconnect()
            blackScreenTradeConn = nil
        end

        for ch, conn in pairs(blackScreenPropConns) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(blackScreenPropConns)

        if blackScreenGui then
            pcall(function() blackScreenGui:Destroy() end)
            blackScreenGui = nil
            _G.__ProgAPI_BlackScreenGui = nil
        end

        pcall(function()
            local cg = game:GetService("CoreGui")
            if cg then
                for _, inst in ipairs(cg:GetDescendants()) do
                    if inst.Name == "ClickerHub_BlackScreen" then
                        pcall(function() inst:Destroy() end)
                    end
                end
            end
            if gethui and type(gethui) == "function" then
                local h = gethui()
                if h then
                    for _, inst in ipairs(h:GetDescendants()) do
                        if inst.Name == "ClickerHub_BlackScreen" then
                            pcall(function() inst:Destroy() end)
                        end
                    end
                end
            end
            if pg then
                for _, ch in ipairs(pg:GetChildren()) do
                    if ch.Name == "ClickerHub_BlackScreen" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
        end)

        -- Guaranteed 3D rendering recovery: restore immediately and pulse across next frames
        pcall(function()
            local RunService = game:GetService("RunService")
            if RunService and RunService.Set3dRenderingEnabled then
                RunService:Set3dRenderingEnabled(true)
            end
        end)
        task.spawn(function()
            for _ = 1, 5 do
                task.wait(0.08)
                pcall(function()
                    local RunService = game:GetService("RunService")
                    if RunService and RunService.Set3dRenderingEnabled then
                        RunService:Set3dRenderingEnabled(true)
                    end
                end)
            end
        end)

        pcall(function()
            if _G.State then _G.State.BlackScreen = false end
            local Configs = rawget(_G, "Configs")
            if Configs and Configs.Set then Configs.Set("BlackScreen", false) end
        end)

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
        TradeRequests = true, -- TradeRequests MUST ALWAYS BE TRUE! Never disable in in-game settings
    }

    for settingName, val in pairs(targetSettings) do
        pcall(function()
            SettingsCh:InvokeServer("SetSetting", settingName, val)
        end)
    end
    -- Redundant guarantee: explicitly ensure TradeRequests is set to true on the server
    pcall(function()
        SettingsCh:InvokeServer("SetSetting", "TradeRequests", true)
    end)

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

-- Automatically disable egg animations upon initialization
pcall(ProgAPI.DisableEggAnimation)

-- Auto-decline incoming trade requests ONLY if AutoAcceptTrade is explicitly disabled
pcall(function()
    local TradeFrontend = require(Client:WaitForChild("TradeFrontend", 2))
    if TradeFrontend and TradeFrontend.TradeRequestReceived then
        TradeFrontend.TradeRequestReceived:Connect(function(otherPlayer)
            local st = rawget(_G, "State")
            if st and st.AutoAcceptTrade == false then
                pcall(function()
                    TradeFrontend.TradeRequestDecision(otherPlayer, false)
                end)
                pcall(function()
                    local Trading = Channels.Trading or (Network and Network.Channel("Trading"))
                    if Trading then
                        Trading:InvokeServer("TradeRequestDecision", otherPlayer, false)
                    end
                end)
            end
        end)
    end
end)

--==============================================================================
-- THE BANK UTILITY ENGINE
-- Bypasses FFlags restriction and allows viewing, depositing, and withdrawing
-- from The Bank without client script auto-closing.
--==============================================================================

function ProgAPI.IsBankOpen(): boolean
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    local bankGui = pg and pg:FindFirstChild("Bank")
    local frame = bankGui and bankGui:FindFirstChild("Frame")
    return bankGui ~= nil and bankGui.Enabled == true and frame ~= nil and frame.Visible == true
end

function ProgAPI.OpenBank(): (boolean, string)
    local ClientFolder = Client or (Library and Library:FindFirstChild("Client"))
    if not ClientFolder then return false, "Client library not found" end

    -- 1. Enable FFlags for Banks so the client script doesn't force-close it
    pcall(function()
        local FFlags = require(ClientFolder:WaitForChild("FFlags", 5))
        if FFlags and debug and debug.getupvalues then
            local upvals = debug.getupvalues(FFlags.Get)
            if upvals and upvals[1] and upvals[1]["Banks"] then
                upvals[1]["Banks"].Value = true
                if upvals[1]["BanksUpgrading"] then upvals[1]["BanksUpgrading"].Value = true end
                if upvals[1]["BanksWithdrawingOthersTokens"] then upvals[1]["BanksWithdrawingOthersTokens"].Value = true end
            end
            if FFlags.Changed and FFlags.Changed.Fire then
                pcall(function() FFlags.Changed:Fire("Banks") end)
            end
        end
    end)

    -- 2. Open via GUI module
    pcall(function()
        local GUI = require(ClientFolder:WaitForChild("GUI", 5))
        if GUI and GUI.Open then
            GUI.Open("Bank")
        end
    end)

    -- 3. Ensure ScreenGui is enabled and Frame is visible
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    local bankGui = pg and pg:FindFirstChild("Bank")
    if bankGui then
        bankGui.Enabled = true
        local frame = bankGui:FindFirstChild("Frame")
        if frame then
            frame.Visible = true
        end
        return true, "The Bank opened successfully!"
    end

    return false, "Bank ScreenGui not found in PlayerGui"
end

function ProgAPI.CloseBank(): (boolean, string)
    pcall(function()
        local ClientFolder = Client or (Library and Library:FindFirstChild("Client"))
        if ClientFolder then
            local GUI = require(ClientFolder:FindFirstChild("GUI"))
            if GUI and GUI.Close then
                GUI.Close("Bank")
            end
        end
    end)
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    local bankGui = pg and pg:FindFirstChild("Bank")
    if bankGui then
        bankGui.Enabled = false
        local frame = bankGui:FindFirstChild("Frame")
        if frame then
            frame.Visible = false
        end
    end
    return true, "Bank closed."
end

function ProgAPI.ToggleBank(): (boolean, string)
    if ProgAPI.IsBankOpen() then
        return ProgAPI.CloseBank()
    else
        return ProgAPI.OpenBank()
    end
end

--==============================================================================
-- MULTI-ACCOUNT PROFILE UTILITIES
--==============================================================================
function ProgAPI.GetUserAccountName(): string
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    return (lp and lp.Name) or "Player"
end

function ProgAPI.GetUserAccountUserId(): number
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    return (lp and lp.UserId) or 0
end

function ProgAPI.GetUserAccountFolder(): string
    return string.format("[AUTOPROG]/[%s][%s]", ProgAPI.GetUserAccountName(), tostring(ProgAPI.GetUserAccountUserId()))
end

function ProgAPI.GetUserAccountConfigPath(): string
    return string.format("%s/config.json", ProgAPI.GetUserAccountFolder())
end

--==============================================================================
-- ANTI-AFK ENGINE (Idle Kick Interception & Controller Keepalive)
--==============================================================================
local _antiAfkConnection = nil
local _antiAfkThread = nil
local _antiAfkActive = false

function ProgAPI.IsAntiAFKEnabled(): boolean
    return _antiAfkActive
end

function ProgAPI.StartAntiAFK()
    if _antiAfkActive then return end
    _antiAfkActive = true

    local lp = LocalPlayer or game:GetService("Players").LocalPlayer

    -- 1. Disable / disconnect any existing internal Roblox Idled listeners if executor supports getconnections
    pcall(function()
        if getconnections and lp then
            for _, conn in ipairs(getconnections(lp.Idled)) do
                pcall(function()
                    if conn.Disable then
                        conn:Disable()
                    elseif conn.Disconnect then
                        conn:Disconnect()
                    end
                end)
            end
        end
    end)

    -- 2. Connect to LocalPlayer.Idled with VirtualUser input dispatch
    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        if lp and not _antiAfkConnection then
            _antiAfkConnection = lp.Idled:Connect(function()
                if not _antiAfkActive then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end)
        end
    end)

    -- 3. Heartbeat keepalive thread (every 60s) to continuously reset AFK timer
    if not _antiAfkThread then
        _antiAfkThread = task.spawn(function()
            local VirtualUser = game:GetService("VirtualUser")
            while _antiAfkActive do
                task.wait(60)
                if not _antiAfkActive then break end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
            _antiAfkThread = nil
        end)
    end
end

function ProgAPI.StopAntiAFK()
    _antiAfkActive = false
    if _antiAfkConnection then
        pcall(function() _antiAfkConnection:Disconnect() end)
        _antiAfkConnection = nil
    end
    if _antiAfkThread then
        pcall(function() task.cancel(_antiAfkThread) end)
        _antiAfkThread = nil
    end
end

--==============================================================================
-- AUTO REJOIN ENGINE (Reconnection on any error / disconnect / kick)
--==============================================================================
local _autoRejoinActive = false
local _autoRejoinDebounce = false
local _autoRejoinConnections = {}

function ProgAPI.IsAutoRejoinEnabled(): boolean
    return _autoRejoinActive
end

function ProgAPI.TriggerRejoin(reason: string)
    if not _autoRejoinActive or _autoRejoinDebounce then return end
    _autoRejoinDebounce = true
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer

    warn(string.format("[ClickerHub AutoRejoin] Disconnection detected: %s. Initiating reconnect sequence...", tostring(reason)))

    -- Display reconnect notification
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("SendNotification", {
            Title = "CLICKER HUB REJOIN",
            Text = "Disconnection detected (" .. tostring(reason) .. "). Reconnecting...",
            Duration = 6
        })
    end)

    -- Queue the loader on teleport so the script executes automatically when loaded
    pcall(function()
        local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if queueTeleport then
            queueTeleport([[
                repeat task.wait() until game:IsLoaded()
                task.wait(1.5)
                pcall(function()
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/Atxvy/-CLICKER-HUB-/main/%5BAUTOPROG%5D/Main.lua?t=" .. tostring(os.time())))()
                end)
            ]])
        end
    end)

    -- Reconnect execution loop
    task.spawn(function()
        local TeleportService = game:GetService("TeleportService")
        local placeId = game.PlaceId
        local jobId = game.JobId

        task.wait(2)

        -- First attempt: Reconnect to same instance (if server is still alive)
        if jobId and #jobId > 0 then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, jobId, lp)
            end)
        end

        task.wait(3.5)

        -- Fallback loop: Teleport to placeId
        while true do
            pcall(function()
                TeleportService:Teleport(placeId, lp)
            end)
            task.wait(5)
        end
    end)
end

function ProgAPI.StartAutoRejoin()
    if _autoRejoinActive then return end
    _autoRejoinActive = true

    local GuiService = game:GetService("GuiService")
    local CoreGui = game:GetService("CoreGui")

    -- 1. GuiService ErrorMessageChanged listener
    pcall(function()
        local conn = GuiService.ErrorMessageChanged:Connect(function(msg)
            if not _autoRejoinActive then return end
            if msg and #msg > 0 then
                ProgAPI.TriggerRejoin("GuiService Error: " .. tostring(msg))
            end
        end)
        table.insert(_autoRejoinConnections, conn)
    end)

    -- 2. CoreGui RobloxPromptGui promptOverlay listener
    pcall(function()
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if promptGui then
            local promptOverlay = promptGui:FindFirstChild("promptOverlay")
            if promptOverlay then
                local conn = promptOverlay.ChildAdded:Connect(function(child)
                    if not _autoRejoinActive then return end
                    if child.Name == "ErrorPrompt" or child:FindFirstChild("MessageArea") then
                        ProgAPI.TriggerRejoin("PromptOverlay ErrorPrompt")
                    end
                end)
                table.insert(_autoRejoinConnections, conn)

                -- Check if error prompt is already active
                if promptOverlay:FindFirstChild("ErrorPrompt") then
                    ProgAPI.TriggerRejoin("Pre-existing ErrorPrompt")
                end
            end
        end
    end)

    -- 3. Watchdog loop checking error code
    local watchdogThread = task.spawn(function()
        while _autoRejoinActive do
            task.wait(3)
            if not _autoRejoinActive then break end
            pcall(function()
                local errCode = GuiService:GetErrorCode()
                if errCode and errCode.Value ~= 0 then
                    ProgAPI.TriggerRejoin("GuiService ErrorCode " .. tostring(errCode.Value))
                end
            end)
        end
    end)
    table.insert(_autoRejoinConnections, {
        Disconnect = function()
            pcall(task.cancel, watchdogThread)
        end
    })
end

function ProgAPI.StopAutoRejoin()
    _autoRejoinActive = false
    _autoRejoinDebounce = false
    for _, conn in ipairs(_autoRejoinConnections) do
        pcall(function()
            if conn.Disconnect then
                conn:Disconnect()
            end
        end)
    end
    table.clear(_autoRejoinConnections)
end

--==============================================================================
-- AUTOMATIC TRADING PIPELINE
-- Feature: Auto Accept Trade (Default ON)
-- 1. Automatically accepts incoming trade requests.
-- 2. Waits until the other player is ready (Accepted!).
-- 3. Readies up once the other player is ready.
-- 4. Waits through the 5-second countdown cooldown until the button changes to "Confirm!".
-- 5. Confirms the trade.
--==============================================================================

local _autoTradeListenerConnected = false
local _acceptedTradeRequesters = {} -- [requester] = tick()
local _lastTradeActionTick = 0
local _lastTradeSettingTick = 0

function ProgAPI.InitAutoTradeListener()
    -- Always guarantee in-game TradeRequests setting is ON (never disabled)
    pcall(function()
        local SettingsCh = Channels.Settings or (Network and Network.Channel("Settings"))
        if SettingsCh then
            SettingsCh:InvokeServer("SetSetting", "TradeRequests", true)
        end
    end)

    if _autoTradeListenerConnected then return end
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local lib = rep:WaitForChild("Library", 5)
        local client = lib and lib:WaitForChild("Client", 5)
        if not client then return end

        -- 1. Hook Client.UI.Message.New: Instantly return 1 (Accept) for trade requests so no modal popup blocks or times out
        local messageMod = client:FindFirstChild("UI") and client.UI:FindFirstChild("Message")
        if messageMod then
            local Message = require(messageMod)
            if Message and Message.New and not Message._autoTradeHooked then
                local origMsgNew = Message.New
                Message.New = function(title, buttons, ...)
                    local st = rawget(_G, "State")
                    if st and st.AutoAcceptTrade ~= false then
                        local titleStr = tostring(title or ""):lower()
                        if titleStr:find("trade request") or titleStr:find("trade") or titleStr:find("sent you") then
                            return 1 -- Option 1 = "Accept"
                        end
                    end
                    return origMsgNew(title, buttons, ...)
                end
                Message._autoTradeHooked = true
            end
        end

        local tradeFrontendMod = client:FindFirstChild("TradeFrontend") or client:WaitForChild("TradeFrontend", 5)
        if tradeFrontendMod then
            local TradeFrontend = require(tradeFrontendMod)
            if TradeFrontend then
                -- 2. Hook TradeRequestDecision: Whenever AutoAcceptTrade is active, FORCE decision = 1 (Accept) and debounce duplicates
                if TradeFrontend.TradeRequestDecision and not TradeFrontend._autoTradeHooked then
                    local origDecision = TradeFrontend.TradeRequestDecision
                    TradeFrontend.TradeRequestDecision = function(requester, decision)
                        local st = rawget(_G, "State")
                        if st and st.AutoAcceptTrade ~= false then
                            if decision == false or decision == 2 or decision == nil then
                                decision = 1 -- 1 = Accept in Clicker Simulator TradeFrontend
                            end
                            local now = tick()
                            if requester and _acceptedTradeRequesters[requester] and (now - _acceptedTradeRequesters[requester] < 3) then
                                return true -- Already accepted, avoid duplicate server invocation
                            end
                            if requester then
                                _acceptedTradeRequesters[requester] = now
                            end
                        end
                        return origDecision(requester, decision)
                    end
                    TradeFrontend._autoTradeHooked = true
                end

                -- 3. Hook TradeRequestReceived: Instantly accept on the first call
                if TradeFrontend.TradeRequestReceived then
                    TradeFrontend.TradeRequestReceived:Connect(function(requester)
                        local st = rawget(_G, "State")
                        if st and st.AutoAcceptTrade ~= false then
                            task.spawn(function()
                                -- Accept trade directly via TradeRequestDecision
                                pcall(function()
                                    TradeFrontend.TradeRequestDecision(requester, 1)
                                end)
                                -- Dismiss/accept any leftover Message GUI prompt if present
                                task.wait(0.04)
                                pcall(function()
                                    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
                                    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
                                    local msgGui = pg and pg:FindFirstChild("Message")
                                    if msgGui and msgGui.Enabled then
                                        local frame = msgGui:FindFirstChild("Frame")
                                        local buttons = frame and frame:FindFirstChild("Buttons")
                                        if buttons then
                                            for _, b in ipairs(buttons:GetChildren()) do
                                                local titleLbl = b:FindFirstChild("Title", true)
                                                local mainBtn = b:FindFirstChild("Main") or b:FindFirstChildWhichIsA("GuiButton", true)
                                                if titleLbl and titleLbl.Text == "Accept" and mainBtn then
                                                    if firesignal then
                                                        firesignal(mainBtn.Activated)
                                                        firesignal(mainBtn.MouseButton1Click)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end)
                            end)
                        end
                    end)
                    _autoTradeListenerConnected = true
                end
            end
        end
    end)
end

function ProgAPI.GetTradeStatus(): (boolean, table?)
    local tradingGui = LocalPlayer.PlayerGui:FindFirstChild("Trading")
    if not tradingGui or not tradingGui.Enabled then
        return false, nil
    end
    local frame = tradingGui:FindFirstChild("Frame")
    if not frame or not frame.Visible then
        return false, nil
    end

    local they = frame:FindFirstChild("They")
    local readyBtn = they and they:FindFirstChild("Buttons") and they.Buttons:FindFirstChild("Ready") and they.Buttons.Ready:FindFirstChild("Button")
    local readyTitle = readyBtn and readyBtn:FindFirstChild("Title")
    local status = they and they:FindFirstChild("Scrolling") and they.Scrolling:FindFirstChild("Status")
    local statusLabel = status and status:FindFirstChild("Label")
    local note = they and they:FindFirstChild("Note")

    local otherAccepted = (status and status.Visible and statusLabel and (statusLabel.Text == "Accepted!" or statusLabel.Text == "Confirmed!"))
        or (note and (note.Text:find("Waiting for You to Accept") ~= nil or note.Text:find("Waiting for You to Confirm") ~= nil or note.Text:find("both players Confirm") ~= nil))

    local btnText = (readyTitle and readyTitle.Text) or ""
    local noteText = (note and note.Text) or ""

    return true, {
        TradingOpen = true,
        ReadyButton = readyBtn,
        ButtonText = btnText,
        NoteText = noteText,
        OtherAccepted = otherAccepted or false,
        StatusText = (statusLabel and statusLabel.Text) or "",
        Executing = (btnText == "Processing..." or noteText:find("Processing") ~= nil)
    }
end

function ProgAPI.StepAutoTrade(): (boolean, string?)
    local st = rawget(_G, "State")
    if st and st.AutoAcceptTrade == false then
        return false, "AutoAcceptTrade disabled"
    end

    local now = tick()

    -- Periodically enforce in-game setting TradeRequests = true every 5 seconds
    if now - _lastTradeSettingTick >= 5 then
        _lastTradeSettingTick = now
        pcall(function()
            local SettingsCh = Channels.Settings or (Network and Network.Channel("Settings"))
            if SettingsCh then
                SettingsCh:InvokeServer("SetSetting", "TradeRequests", true)
            end
        end)
    end

    -- 1. Auto-accept pending trade request prompt in Message GUI if visible
    local msgGui = LocalPlayer.PlayerGui:FindFirstChild("Message")
    if msgGui and msgGui.Enabled then
        local frame = msgGui:FindFirstChild("Frame")
        local desc = frame and frame:FindFirstChild("Desc")
        local descText = (desc and desc.Text) or ""
        if descText:find("trade request") or descText:find("Trade") or descText:find("sent you") then
            local buttons = frame and frame:FindFirstChild("Buttons")
            if buttons then
                for _, b in ipairs(buttons:GetChildren()) do
                    if b:IsA("GuiObject") then
                        local titleLbl = b:FindFirstChild("Title", true)
                        local mainBtn = b:FindFirstChild("Main") or b:FindFirstChildWhichIsA("GuiButton", true)
                        if titleLbl and titleLbl.Text == "Accept" and mainBtn then
                            pcall(function()
                                if firesignal then
                                    firesignal(mainBtn.Activated)
                                    firesignal(mainBtn.MouseButton1Click)
                                end
                            end)
                            return true, "Accepted incoming trade request prompt"
                        end
                    end
                end
            end
        end
    end

    -- 2. Inspect active trading window
    local isOpen, trade = ProgAPI.GetTradeStatus()
    if not isOpen or not trade or not trade.ReadyButton then
        return false, "Trade window closed"
    end

    if trade.Executing then
        return true, "Trade processing..."
    end

    -- 3. If other player is ready and our button is "Ready!", ready up!
    if trade.ButtonText == "Ready!" then
        if trade.OtherAccepted then
            if now - _lastTradeActionTick >= 0.35 then
                _lastTradeActionTick = now
                pcall(function()
                    if firesignal then
                        firesignal(trade.ReadyButton.Activated)
                        firesignal(trade.ReadyButton.MouseButton1Click)
                    end
                end)
                return true, "Readied up trade"
            end
        else
            return false, "Waiting for other player to accept"
        end
    end

    -- 4. If button is "Confirm!", the 5-second countdown cooldown has elapsed -> Confirm the trade!
    if trade.ButtonText == "Confirm!" then
        if now - _lastTradeActionTick >= 0.35 then
            _lastTradeActionTick = now
            pcall(function()
                if firesignal then
                    firesignal(trade.ReadyButton.Activated)
                    firesignal(trade.ReadyButton.MouseButton1Click)
                end
            end)
            return true, "Confirmed trade"
        end
    end

    -- 5. During countdown (ButtonText is "Unready!" and cooldown is running)
    if trade.ButtonText == "Unready!" then
        return false, trade.NoteText ~= "" and trade.NoteText or "Cooldown timer running..."
    end

    return false, "Trading in progress"
end

return ProgAPI

