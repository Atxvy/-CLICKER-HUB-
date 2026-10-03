--!strict
--==============================================================================
-- [CLICKER HUB] Configs.lua
-- Settings persistence manager (JSON based)
--==============================================================================

local Configs = {}

local HttpService = game:GetService("HttpService")
local CONFIG_PATH = "[CLICKER HUB]/config.json"

Configs.Default = {
    AutoClick = {
        Enabled = false,
        Speed = 0.001,
    },
    AutoRebirth = {
        Enabled = false,
        Mode = "Max Rebirth", -- "Max Rebirth", "Best Affordable", "Button 1", "Button 2", "Button 3"
        Index = 1,
        Delay = 0.5,
    },
    AutoFarm = {
        AutoUnlockNextIsland = false,
    },
    AutoPets = {
        EquipBest = false,
        Interval = 5,
        AutoGoldPets = false,
        AutoRainbowPets = false,
        AutoClaimRainbow = true,
    },
    AutoHatch = {
        Enabled = false,
        Egg = "Best Affordable Egg",
        AutoTeleportToEgg = true,
        Amount = 1,
        Delay = 0.5,
    },
    SkillTree = {
        AutoBreakables = false,
        BestWorld = true,
        TargetWorld = "Auto (Dynamic Smart)",
        IgnoreBossChest = true,
        Delay = 0.05,
        AutoSkillTree = false,
    },
    AutoQuest = {
        AutoClaim = true,
        AutoSecretQuests = false,
        Interval = 5,
    },
    Upgrades = {
        GemUpgrades = false,
        RebirthButtons = false,
        DoubleJump = false,
        MiniUpgrades = true,
        RNGUpgrades = false,
    },
    AutoRewards = {
        FreeGifts = true,
        Achievements = true,
        Chests = true,
        Daily = true,
        SpinWheel = true,
        Quests = true,
        FinishedCrafts = true,
        Interval = 10,
    },
    AutoItems = {
        AutoPotions = false,
        AutoFruits = false,
        AutoCraftPowerups = false,
        ClicksPotion = true,
        HatchSpeedPotion = true,
        LuckPotion = true,
        GemsPotion = true,
        ClicksSpeedPotion = true,
    },
    Misc = {
        WalkSpeed = 16,
        JumpPower = 50,
        InfiniteJump = false,
        AntiAFK = true,
    }
}

Configs.Current = table.clone(Configs.Default)

function Configs.Load()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_PATH) then
            local raw = readfile(CONFIG_PATH)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for category, tbl in pairs(decoded) do
                    if type(tbl) == "table" and Configs.Current[category] then
                        for k, v in pairs(tbl) do
                            Configs.Current[category][k] = v
                        end
                    end
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

return Configs
