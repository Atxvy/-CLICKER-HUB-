--!strict
--==============================================================================
-- [AUTOPROG] OpenBank.lua
-- Dedicated Standalone Script to Open The Bank in Clicker Simulator!
-- Bypasses FFlags restriction and allows viewing, depositing, and withdrawing.
--==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Library = ReplicatedStorage:WaitForChild("Library", 5)
if not Library then
    return warn("[OpenBank] ReplicatedStorage.Library not found")
end

local Client = Library:WaitForChild("Client", 5)
if not Client then
    return warn("[OpenBank] ReplicatedStorage.Library.Client not found")
end

-- 1. Enable FFlags for Banks so the client script does not force-close it
pcall(function()
    local FFlags = require(Client:WaitForChild("FFlags", 5))
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
    local GUI = require(Client:WaitForChild("GUI", 5))
    if GUI and GUI.Open then
        GUI.Open("Bank")
    end
end)

-- 3. Ensure ScreenGui is enabled and Frame is visible
local lp = Players.LocalPlayer
local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
local bankGui = pg and pg:FindFirstChild("Bank")
if bankGui then
    bankGui.Enabled = true
    local frame = bankGui:FindFirstChild("Frame")
    if frame then
        frame.Visible = true
    end
    print("[OpenBank] The Bank opened successfully!")
else
    warn("[OpenBank] Bank ScreenGui not found in PlayerGui")
end
