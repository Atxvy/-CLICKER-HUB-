--!strict
--==============================================================================
-- [AUTOPROG] Configs.lua
-- Settings persistence manager for Auto Progression
-- Supports multi-account profile isolation: [AUTOPROG]/[NAME][USERID]/config.json
--==============================================================================

local Configs = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        LocalPlayer = Players.PlayerAdded:Wait()
    end)
end

local playerName = (LocalPlayer and LocalPlayer.Name) or "Player"
local playerUserId = (LocalPlayer and LocalPlayer.UserId) or 0

-- Multi-account isolated folder structure: [AUTOPROG]/[NAME][USERID]/config.json
local USER_FOLDER = string.format("[AUTOPROG]/[%s][%s]", playerName, tostring(playerUserId))
local CONFIG_PATH = string.format("%s/config.json", USER_FOLDER)
local LEGACY_CONFIG_PATH = "[AUTOPROG]/config.json"

Configs.UserFolder = USER_FOLDER
Configs.ConfigPath = CONFIG_PATH
Configs.UserName = playerName
Configs.UserId = playerUserId

Configs.Default = {
    MasterEnabled = true,
    AutoClick = true,
    AutoMaxRebirth = true,
    AutoPrestige = true,
    AutoUnlockIslands = true,
    AutoBestEggs = true,
    AutoGold = true,
    AutoCraftGolden = true,
    ProtectCraftingPets = true,
    AutoCleanPets = true,
    AutoEquipBest = true,
    AutoMapUpgrades = true,
    AutoGemUpgrades = true,
    AutoRebirthButtons = true,
    AutoDesertMachine = true,
    AutoSkillTree = true,
    AutoMagmaSkin = true,
    AutoRainbowClaim = true,
    -- Phase 2: ??? Secret Quest
    AutoSecretQuest = true,
    AutoCollectFeathers = true,
    AutoSecretCraftGolden = true,
    AutoUnlockSecretDoor = true,
    -- Phase 3: Endgame Skill Tree (39/39) & Preparation
    -- Phase 4: Auto Index Pets (Goal: 250 Total Index)
    AutoIndexPets = true,
    IndexTargetTotal = 250,
    IndexUnlockNormal = true,
    IndexUnlockGold = true,
    IndexUnlockRainbow = true, -- Common & Rare pets only (Easy ones, auto-queues in Rainbow Machine up to target 250)
    IndexUnlockDarkMatter = false,
    IndexIgnoreMythicAndAbove = true,
    IndexAutoDeleteFodder = true,
    -- Phase 5: Endgame Matrix Mythics
    AutoMatrixEgg = true,
    AutoMythicFilter = true,
    AutoCraftMythics = true,
    AutoReplaceTeam = true,
    PauseRebirthPhase3 = true,
    PauseRebirthPhase4 = true,
    PauseRebirthPhase5 = true,
    AutoPotions = true,
    AutoFruits = true,
    AutoFreeGifts = true,
    AttackBigChests = true,
    BlackScreen = false,
    RemoveMaps = false,
    OptimizeGameSettings = true,
    -- Session Resilience & Multi-Account (Default ON)
    AntiAFK = true,
    AutoRejoin = true,
    WalkSpeed = 16,
    JumpPower = 50,
    WebhookUrl = "",
    WebhookEnabled = true,
}

Configs.Current = table.clone(Configs.Default)

local function ensureFolder()
    pcall(function()
        if makefolder and isfolder then
            if not isfolder("[AUTOPROG]") then
                makefolder("[AUTOPROG]")
            end
            if not isfolder(USER_FOLDER) then
                makefolder(USER_FOLDER)
            end
        end
    end)
end

function Configs.Load()
    ensureFolder()
    pcall(function()
        if readfile and isfile then
            local targetPath = nil
            if isfile(CONFIG_PATH) then
                targetPath = CONFIG_PATH
            elseif isfile(LEGACY_CONFIG_PATH) then
                targetPath = LEGACY_CONFIG_PATH
            end

            if targetPath then
                local raw = readfile(targetPath)
                local decoded = HttpService:JSONDecode(raw)
                if type(decoded) == "table" then
                    for k, v in pairs(decoded) do
                        Configs.Current[k] = v
                    end
                end
                -- Ensure defaults for newly introduced keys if nil in loaded json
                if Configs.Current.AntiAFK == nil then Configs.Current.AntiAFK = true end
                if Configs.Current.AutoRejoin == nil then Configs.Current.AutoRejoin = true end
                if Configs.Current.IndexUnlockRainbow == nil or Configs.Current._RainbowV3Default == nil then
                    Configs.Current.IndexUnlockRainbow = true
                    Configs.Current._RainbowV3Default = true
                end
                if Configs.Current.IndexTargetTotal == nil then Configs.Current.IndexTargetTotal = 250 end

                -- If loaded from legacy config, save into new isolated path immediately
                if targetPath == LEGACY_CONFIG_PATH and not isfile(CONFIG_PATH) then
                    Configs.Save()
                end
            else
                -- Initialize file with defaults immediately
                Configs.Save()
            end
        end
    end)
    return Configs.Current
end

function Configs.Save()
    ensureFolder()
    pcall(function()
        if writefile then
            local encoded = HttpService:JSONEncode(Configs.Current)
            writefile(CONFIG_PATH, encoded)
        end
    end)
end

function Configs.Get(key: string, defaultVal: any): any
    if Configs.Current[key] ~= nil then
        return Configs.Current[key]
    end
    return defaultVal
end

function Configs.Set(key: string, val: any)
    Configs.Current[key] = val
    Configs.Save()
end

return Configs
