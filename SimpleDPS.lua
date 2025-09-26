--[[
SimpleDPS (Turtle WoW Addon)
=============================
Author: Monomoy

Context:
--------
This addon is written specifically for **Turtle WoW** (a Vanilla 1.12 private server).
The API and available functions are the same as **World of Warcraft 1.12 (Classic)**,
NOT modern retail WoW. 

Important differences vs Retail:
- `CombatLogGetCurrentEventInfo()` does NOT exist in 1.12.
  Instead, COMBAT_LOG_EVENT_UNFILTERED passes arguments directly into `OnEvent`.
- `BackdropTemplateMixin` does NOT exist in 1.12, so the frame uses only `SetBackdrop()`.
- Always enable script error display with `/console scriptErrors 1` if debugging.

Addon Behavior:
---------------
- Creates a movable DPS frame that is shown immediately on login.
- Tracks your outgoing damage by spell name using the combat log.
- Calculates DPS since combat started.
- Provides a "Reset DPS" button.
- Provides a slash command `/simpledps` to toggle the frame visibility.

Usage:
------
1. Place this file into a folder named `SimpleDPS` inside your Turtle WoW `Interface/AddOns` directory.
   Example: `Interface/AddOns/SimpleDPS/SimpleDPS.lua`
2. Create a `SimpleDPS.toc` file in the same folder with at least:
     ## Interface: 11200
     ## Title: SimpleDPS
     ## Notes: Minimal DPS meter for Turtle WoW
     SimpleDPS.lua
3. Restart the game (reloadui is not enough if it’s a first-time install).
4. On login, the DPS window will appear automatically.
5. Type `/simpledps` to hide/show the frame.

]]

local SimpleDPS = {}
SimpleDPS.damageData = {}
SimpleDPS.startTime = nil
SimpleDPS.totalTime = 0

-- Main frame
local f = CreateFrame("Frame", "SimpleDPSFrame", UIParent)
f:SetSize(220, 260)
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

-- DPS text
f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("TOPLEFT", 10, -10)
f.text:SetPoint("BOTTOMRIGHT", -10, 40)
f.text:SetJustifyH("LEFT")
f.text:SetJustifyV("TOP")

-- Reset button
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

-- Combat event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              spellId, spellName, spellSchool,
              amount = ...

        if sourceName == UnitName("player") and
           (subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE") then
            if spellName and amount then
                SimpleDPS.damageData[spellName] = (SimpleDPS.damageData[spellName] or 0) + amount
                if not SimpleDPS.startTime then
                    SimpleDPS.startTime = GetTime()
                end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not SimpleDPS.startTime then
            SimpleDPS.startTime = GetTime()
        end
    end
end)

-- Update DPS display
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
        return tonumber(a:match("%s(%d+%.?%d*) DPS")) > tonumber(b:match("%s(%d+%.?%d*) DPS"))
    end)
    f.text:SetText(table.concat(lines, "\n"))
end)

-- Always show frame on login
f:Show()
