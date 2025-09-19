local SimpleDPS = {}
SimpleDPS.damageData = {}
SimpleDPS.startTime = nil
SimpleDPS.totalTime = 0

-- Main frame
local f = CreateFrame("Frame", "SimpleDPSFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
f:SetSize(220, 260)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 1,
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

-- Combat logic frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              spellId, spellName, spellSchool,
              amount = CombatLogGetCurrentEventInfo()

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

-- OnUpdate
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

f:Show()
