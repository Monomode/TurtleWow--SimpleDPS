local totalDamage = 0
local combatStartTime = 0
local inCombat = false

local function UpdateDisplay()
    local elapsed = GetTime() - combatStartTime
    local dps = (elapsed > 0) and (totalDamage / elapsed) or 0
    SimpleDPSText:SetText(string.format("Damage: %d\nDPS: %.1f", totalDamage, dps))
end

local function ResetData()
    totalDamage = 0
    combatStartTime = GetTime()
    UpdateDisplay()
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Enter combat
        inCombat = true
        ResetData()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leave combat
        inCombat = false
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and inCombat then
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, amount = CombatLogGetCurrentEventInfo()
        if sourceGUID == UnitGUID("player") then
            if subEvent == "SWING_DAMAGE" then
                totalDamage = totalDamage + amount
                UpdateDisplay()
            elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
                totalDamage = totalDamage + amount
                UpdateDisplay()
            end
        end
    end
end

SimpleDPSFrame:SetScript("OnEvent", OnEvent)
