-- SimpleDPS.lua
local SimpleDPS = CreateFrame("Frame", "SimpleDPSFrame", UIParent)
SimpleDPS:SetSize(200, 220)
SimpleDPS:SetPoint("CENTER")
SimpleDPS:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 1,
})
SimpleDPS:SetBackdropColor(0, 0, 0, 0.7)
SimpleDPS:EnableMouse(true)
SimpleDPS:SetMovable(true)
SimpleDPS:RegisterForDrag("LeftButton")
SimpleDPS:SetScript("OnDragStart", SimpleDPS.StartMoving)
SimpleDPS:SetScript("OnDragStop", SimpleDPS.StopMovingOrSizing)

-- Font string for output
SimpleDPS.text = SimpleDPS:CreateFontString(nil, "OVERLAY", "GameFontNormal")
SimpleDPS.text:SetPoint("TOPLEFT", 10, -10)
SimpleDPS.text:SetPoint("BOTTOMRIGHT", -10, 40)
SimpleDPS.text:SetJustifyH("LEFT")

-- Reset button
SimpleDPS.resetButton = CreateFrame("Button", nil, SimpleDPS, "UIPanelButtonTemplate")
SimpleDPS.resetButton:SetSize(180, 30)
SimpleDPS.resetButton:SetPoint("BOTTOM", 0, 5)
SimpleDPS.resetButton:SetText("Reset DPS")
SimpleDPS.resetButton:SetScript("OnClick", function()
    damageData = {}
    totalTime = 0
    startTime = nil
end)

-- Data tables
local damageData = {}
local startTime = nil
local totalTime = 0

-- Event handler
SimpleDPS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
SimpleDPS:RegisterEvent("PLAYER_REGEN_DISABLED")
SimpleDPS:RegisterEvent("PLAYER_REGEN_ENABLED")

SimpleDPS:SetScript("OnEvent", function(self, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              spellId, spellName, spellSchool,
              amount = CombatLogGetCurrentEventInfo()

        if sourceName == UnitName("player") and (subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE") then
            if spellName then
                damageData[spellName] = (damageData[spellName] or 0) + (amount or 0)
                if not startTime then startTime = GetTime() end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if not startTime then startTime = GetTime() end
    end
end)

-- OnUpdate: refresh display
SimpleDPS:SetScript("OnUpdate", function(self, elapsed)
    if not startTime then return end
    totalTime = GetTime() - startTime
    if totalTime <= 0 then return end

    local lines
