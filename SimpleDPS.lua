local abilities = {}
local combatStartTime = 0
local inCombat = false

local function ResetData()
    abilities = {}
    combatStartTime = GetTime()
    SimpleDPSListText:SetText("Tracking...")
end

local function FormatAbilities()
    local elapsed = GetTime() - combatStartTime
    local lines = {}
    local total = 0

    for _, data in pairs(abilities) do
        total = total + data.damage
    end

    for spellName, data in pairs(abilities) do
        local dps = (elapsed > 0) and (data.damage / elapsed) or 0
        local pct = (total > 0) and (data.damage / total * 100) or 0
        table.insert(lines, string.format("%s: %d dmg (%.1f DPS, %.1f%%)", spellName, data.damage, dps, pct))
    end

    if total == 0 then
        return "No damage yet."
    else
        table.sort(lines) -- alphabetic for now
        return table.concat(lines, "\n")
    end
end

local function UpdateDisplay()
    SimpleDPSListText:SetText(FormatAbilities())
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ResetData()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and inCombat then
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, amount, _, _, _, spellName = CombatLogGetCurrentEventInfo()
        if sourceGUID == UnitGUID("player") then
            local dmg = 0
            local name = spellName or "Melee"

            if subEvent == "SWING_DAMAGE" then
                dmg = amount
                name = "Melee"
            elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
                dmg = amount
            end

            if dmg > 0 then
                if not abilities[name] then
                    abilities[name] = { damage = 0 }
                end
                abilities[name].damage = abilities[name].damage + dmg
                UpdateDisplay()
            end
        end
    end
end

SimpleDPSFrame:SetScript("OnEvent", OnEvent)
