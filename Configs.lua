--!strict
--==============================================================================
-- [AUTOPROG] Configs.lua
-- Settings persistence manager for Auto Progression
--==============================================================================

local Configs = {}

local HttpService = game:GetService("HttpService")
local CONFIG_PATH = "[AUTOPROG]/config.json"

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
    AutoSecretQuest = true,
    AutoMagmaSkin = true,
    AutoRainbowClaim = true,
    AutoPotions = true,
    AutoFruits = true,
    AutoFreeGifts = true,
    AttackBigChests = true,
    BlackScreen = false,
    RemoveMaps = false,
    OptimizeGameSettings = true,
    WalkSpeed = 16,
    JumpPower = 50,
}

Configs.Current = table.clone(Configs.Default)

function Configs.Load()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_PATH) then
            local raw = readfile(CONFIG_PATH)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    Configs.Current[k] = v
                end
            end
        end
    end)
    return Configs.Current
end

function Configs.Save()
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
