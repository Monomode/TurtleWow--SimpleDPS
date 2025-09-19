-- SimpleDPS.lua
-- Tracks DPS per ability and shows it in a frame

local SimpleDPS = CreateFrame("Frame", "SimpleDPSFrame", UIParent)
SimpleDPS:SetSize(200, 200)
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
SimpleDPS.text:SetAllPoints()
SimpleDPS.text:SetJustifyH("LEFT")

-- Data table
local damageData = {}
local fightStart = nil

-- Helper to reset fight
local function StartFight()
    damageData = {}
    fightStart = GetTime()
end

-- Combat log event handler
SimpleDPS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
SimpleDPS:RegisterEvent("PLAYER_REGEN_ENABLED") -- leave combat
SimpleDPS:RegisterEvent("PLAYER_REGEN_DISABLED") -- enter combat

SimpleDPS:SetScript("OnEvent", function(self, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              spellId, spellName, spellSchool,
              amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()
        
        -- Only track player's damage
        if sourceName == UnitName("player") and (subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE") then
            if spellName then
                damageData[spellName] = (damageData[spellName] or 0) + (amount or 0)
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Enter combat: start fight
        StartFight()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leave combat: could do summary here if desired
    end
end)

-- OnUpdate: refresh display every 0.5 seconds
SimpleDPS:SetScript("OnUpdate", function(self, elapsed)
    if not fightStart then return end
    local fightTime = math.max(GetTime() - fightStart, 1)
    local lines = {}
    for spell, dmg in pairs(damageData) do
        local dps = dmg / fightTime
        table.insert(lines, string.format("%-12s %.1f DPS", spell, dps))
    end
    -- Sort by DPS descending
    table.sort(lines, function(a, b)
        return tonumber(a:match("%s(%d+%.?%d*) DPS")) > tonumber(b:match("%s(%d+%.?%d*) DPS"))
    end)

    SimpleDPS.text:SetText(table.concat(lines, "\n"))
end)
