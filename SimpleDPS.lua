-- SimpleDPS - Minimal per-ability DPS tracker (fixed consolidated event handler)
-- Put this file in Interface/AddOns/SimpleDPS/SimpleDPS.lua

SimpleDPSDB = SimpleDPSDB or {}

local frame = CreateFrame("FRAME", "SimpleDPSFrame")
local playerName = UnitName("player")
local playerGUID = UnitGUID("player")

local SimpleDPS = {
    data = SimpleDPSDB.data or { totalDamage = 0, abilities = {} },
    totalCombatTime = SimpleDPSDB.totalCombatTime or 0,
    inCombat = false,
    combatStart = 0,
    useCombatLog = (CombatLogGetCurrentEventInfo ~= nil)
}

-- save DB helper
local function SaveDB()
    SimpleDPSDB.data = SimpleDPS.data
    SimpleDPSDB.totalCombatTime = SimpleDPS.totalCombatTime
end

-- combat-time helpers
local function StartCombatTimer()
    if not SimpleDPS.inCombat then
        SimpleDPS.inCombat = true
        SimpleDPS.combatStart = GetTime()
    end
end
local function StopCombatTimer()
    if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
        local dt = GetTime() - SimpleDPS.combatStart
        SimpleDPS.totalCombatTime = SimpleDPS.totalCombatTime + dt
        SimpleDPS.combatStart = 0
    end
    SimpleDPS.inCombat = false
end
local function GetActiveCombatTime()
    local t = SimpleDPS.totalCombatTime
    if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
        t = t + (GetTime() - SimpleDPS.combatStart)
    end
    if t < 1 then t = 1 end
    return t
end

-- record damage (tracks only player's direct damage by default)
local function RecordDamage(spellName, amount, sourceGUID)
    if not spellName or not amount or amount == 0 then return end
    -- only track player's own damage (change this if you want pet tracking)
    if sourceGUID ~= playerGUID then return end

    local d = SimpleDPS.data
    d.totalDamage = (d.totalDamage or 0) + amount
    d.abilities[spellName] = d.abilities[spellName] or { damage = 0, hits = 0 }
    d.abilities[spellName].damage = d.abilities[spellName].damage + amount
    d.abilities[spellName].hits = d.abilities[spellName].hits + 1
end

-- Combat log parsing
local function OnCombatLogEvent()
    local timestamp, subEvent, hideCaster,
        sourceGUID, sourceName, sourceFlags, sourceRaidFlag,
        destGUID, destName, destFlags, destRaidFlag,
        spellId, spellName, spellSchool,
        amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = CombatLogGetCurrentEventInfo()

    if not subEvent then return end

    if subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        -- For these events, amount is the 15th+ returned param in some clients; CombatLogGetCurrentEventInfo returns varying counts,
        -- but in retail/classic wrappers the first damage amount is often at index 15 (we assigned it to 'amount' above).
        if type(amount) == "number" and amount > 0 then
            RecordDamage(spellName or ("Spell_"..tostring(spellId)), amount, sourceGUID)
        end
    elseif subEvent == "SWING_DAMAGE" then
        -- swing events don't have spellName; treat as "Melee"
        local swingAmount = amount
        if type(swingAmount) == "number" and swingAmount > 0 then
            RecordDamage("Melee", swingAmount, sourceGUID)
        end
    end
end

-- Chat fallback for servers without modern combat log (fragile, English only)
local function OnChatCombatEvent(event, msg)
    if not msg then return end
    -- "Your Fireball hits ... for 120."
    local spell, dmg = string.match(msg, "^Your (.+) hits .+ for (%d+)")
    if spell and dmg then
        RecordDamage(spell, tonumber(dmg), playerGUID)
        return
    end
    -- "Your Fireball crits ... for 240."
    spell, dmg = string.match(msg, "^Your (.+) crits .+ for (%d+)")
    if spell and dmg then
        RecordDamage(spell, tonumber(dmg), playerGUID)
        return
    end
    -- "You hit ... for 40."
    dmg = string.match(msg, "^You hit .+ for (%d+)")
    if dmg then
        RecordDamage("Melee", tonumber(dmg), playerGUID)
        return
    end
end

-- UI (same as original, slightly trimmed)
local ui = CreateFrame("Frame", "SimpleDPS_UI", UIParent, "BackdropTemplate")
ui:SetSize(380, 300)
ui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ui:SetMovable(true)
ui:EnableMouse(true)
ui:RegisterForDrag("LeftButton")
ui:SetScript("OnDragStart", ui.StartMoving)
ui:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
ui:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
ui:Hide()

local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -8)
title:SetText("SimpleDPS")

local header = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
header:SetPoint("TOPLEFT", 12, -30)
header:SetText("Ability                                  DPS     Total     %")

local scroll = CreateFrame("ScrollFrame", "SimpleDPSScroll", ui, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
scroll:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -28, 12)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1,1)
scroll:SetScrollChild(content)

local lines = {}
local maxLines = 30
for i=1, maxLines do
    local f = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetPoint("TOPLEFT", content, "TOPLEFT", 8, - (i-1) * 16)
    f:SetWidth(340)
    f:SetJustifyH("LEFT")
    lines[i] = f
end

local function RefreshUI()
    local d = SimpleDPS.data
    local total = d.totalDamage or 0
    local totTime = GetActiveCombatTime()
    local arr = {}
    for ability, info in pairs(d.abilities) do
        local dmg = info.damage or 0
        local dps = dmg / totTime
        tinsert(arr, { ability = ability, damage = dmg, dps = dps })
    end
    table.sort(arr, function(a,b) return a.dps > b.dps end)

    for i=1, maxLines do
        if arr[i] then
            local pct = total>0 and (100 * arr[i].damage / total) or 0
            lines[i]:SetText(string.format("%2d. %-30s %6.1f  %8d  %5.1f%%", i, arr[i].ability, arr[i].dps, arr[i].damage, pct))
        else
            lines[i]:SetText("")
        end
    end
end

ui:SetScript("OnUpdate", function(self, elapsed)
    if not self._acc then self._acc = 0 end
    self._acc = self._acc + elapsed
    if self._acc >= 0.6 then
        RefreshUI()
        self._acc = 0
    end
end)

-- One consolidated OnEvent handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        SaveDB()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        StartCombatTimer()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopCombatTimer()
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- quick debug to ensure events come in (comment out if spammy)
        -- print("SimpleDPS: combat log event")
        OnCombatLogEvent()
        return
    end

    -- Chat fallback events
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        local msg = select(1, ...)
        OnChatCombatEvent(event, msg)
        return
    end
end

-- Register events (register everything once)
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

if SimpleDPS.useCombatLog then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
else
    -- fallback chat events (English)
    frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
end

frame:SetScript("OnEvent", OnEvent)

-- Slash commands
SLASH_SIMPLEDPS1 = "/sdps"
SlashCmdList["SIMPLEDPS"] = function(msg)
    msg = msg:lower()
    if msg == "show" then
        ui:Show()
        RefreshUI()
        print("SimpleDPS: UI shown")
    elseif msg == "hide" then
        ui:Hide()
        print("SimpleDPS: UI hidden")
    elseif msg == "reset" then
        SimpleDPS.data = { totalDamage = 0, abilities = {} }
        SimpleDPS.totalCombatTime = 0
        SaveDB()
        print("SimpleDPS: Data reset")
        RefreshUI()
    elseif msg == "export" then
        local d = SimpleDPS.data
        local tot = d.totalDamage or 0
        local ttime = GetActiveCombatTime()
        print("SimpleDPS Export - TotalDamage:", tot, "CombatTime(s):", math.floor(ttime))
        local arr = {}
        for ability, info in pairs(d.abilities) do
            local dmg = info.damage
            local dps = dmg / ttime
            tinsert(arr, { ability = ability, damage = dmg, dps = dps })
        end
        table.sort(arr, function(a,b) return a.dps > b.dps end)
        for i=1, math.min(20,#arr) do
            local pct = tot>0 and (100 * arr[i].damage / tot) or 0
            print(string.format("%d) %s - DPS: %.1f - Damage: %d - %.1f%%", i, arr[i].ability, arr[i].dps, arr[i].damage, pct))
        end
    else
        print("SimpleDPS commands:")
        print("/sdps show   - Show UI")
        print("/sdps hide   - Hide UI")
        print("/sdps reset  - Reset tracked data and combat time")
        print("/sdps export - Print top abilities to chat")
    end
end

print("SimpleDPS loaded. Use /sdps for commands.")
