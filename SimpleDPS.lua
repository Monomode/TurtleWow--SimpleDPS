--[[
SimpleDPS (Turtle WoW Addon)
=============================
Author: Monomoy

Context:
--------
This addon is written specifically for **Turtle WoW** (a Vanilla 1.12 private server).
The API is WoW 1.12 — there is no COMBAT_LOG_EVENT_UNFILTERED.  
Damage events must be parsed from combat log chat messages.

Addon Behavior:
---------------
- Shows a movable DPS window on login.
- Parses your outgoing combat log messages to detect damage.
- Tracks DPS per ability and shows it in real time.
- Provides a "Reset DPS" button.
- Provides a slash command `/simpledps` to toggle the frame visibility.

Usage:
------
1. Put this file in `Interface/AddOns/SimpleDPS/SimpleDPS.lua`
2. Add a `.toc` file (see example below).
3. Restart client, `/console scriptErrors 1` to see errors.
]]

local SimpleDPS = {}
SimpleDPS.damageData = {}
SimpleDPS.startTime = nil
SimpleDPS.totalTime = 0

-- === Frame Setup ===
local f = CreateFrame("Frame", "SimpleDPSFrame", UIParent)
f:SetWidth(220)
f:SetHeight(260)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
f:SetBackdropColor(0,0,0,0.7)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("TOPLEFT", 10, -10)
f.text:SetPoint("BOTTOMRIGHT", -10, 40)
f.text:SetJustifyH("LEFT")
f.text:SetJustifyV("TOP")

f.resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.resetButton:SetSize(200, 30)
f.resetButton:SetPoint("BOTTOM", 0, 5)
f.resetButton:SetText("Reset DPS")
f.resetButton:SetScript("OnClick", function()
    SimpleDPS.damageData = {}
    SimpleDPS.startTime = nil
end)

SimpleDPS.frame = f

-- Slash command
SLASH_SIMPLEDPS1 = "/simpledps"
SlashCmdList["SIMPLEDPS"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- === Combat Log Parser for 1.12 ===
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

eventFrame:SetScript("OnEvent", function(self, event, msg)
    -- Example messages:
    -- "Your Fireball hits Defias Thug for 45 Fire damage."
    -- "You hit Defias Thug for 12."
    local spell, dmg = msg:match("Your (.+) hits .- for (%d+)")
    if not spell then
        spell, dmg = msg:match("You hit .- for (%d+)")
        if spell then
            -- Auto-attacks
            spell = "Melee"
        end
    end
    if not spell then
        spell, dmg = msg:match("Your (.+) crits .- for (%d+)")
    end
    if not spell then
        spell, dmg = msg:match("You crit .- for (%d+)")
        if spell then
            spell = "Melee"
        end
    end

    if spell and dmg then
        dmg = tonumber(dmg)
        SimpleDPS.damageData[spell] = (SimpleDPS.damageData[spell] or 0) + dmg
        if not SimpleDPS.startTime then
            SimpleDPS.startTime = GetTime()
        end
    end
end)

-- === Update DPS Display ===
f:SetScript("OnUpdate", function(self, elapsed)
    if not SimpleDPS.startTime then return end
    SimpleDPS.totalTime = GetTime() - SimpleDPS.startTime
    if SimpleDPS.totalTime <= 0 then return end

    local lines = {}
    for spell, dmg in pairs(SimpleDPS.damageData) do
        local dps = dmg / SimpleDPS.totalTime
        table.insert(lines, string.format("%-12s %.1f DPS", spell, dps))
    end
    table.sort(lines, function(a,b)
        return tonumber(a:match("(%d+%.?%d*) DPS")) > tonumber(b:match("(%d+%.?%d*) DPS"))
    end)
    f.text:SetText(table.concat(lines, "\n"))
end)

f:Show()
