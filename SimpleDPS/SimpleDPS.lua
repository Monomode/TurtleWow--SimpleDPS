-- SimpleDPS - Minimal per-ability DPS tracker
-- Put this file in Interface/AddOns/SimpleDPS/SimpleDPS.lua

-- Saved vars
SimpleDPSDB = SimpleDPSDB or {}

local frame = CreateFrame("FRAME", "SimpleDPSFrame")
local playerName = UnitName("player")
local playerGUID = UnitGUID("player")

-- Data structure:
-- SimpleDPS.data = {
--   totalDamage = number,
--   abilities = {
--     ["Fireball"] = { damage = number, hits = number },
--     ...
--   }
-- }
local SimpleDPS = {
    data = SimpleDPSDB.data or { totalDamage = 0, abilities = {} },
    -- combat time tracking
    totalCombatTime = SimpleDPSDB.totalCombatTime or 0, -- accumulated across fights/sessions
    inCombat = false,
    combatStart = 0,
}

-- Utility: persist DB on logout / reload
local function SaveDB()
    SimpleDPSDB.data = SimpleDPS.data
    SimpleDPSDB.totalCombatTime = SimpleDPS.totalCombatTime
end
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        SaveDB()
    end
end)

-- Combat time tracking using PLAYER_REGEN_* events
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entered combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- left combat

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if not SimpleDPS.inCombat then
            SimpleDPS.inCombat = true
            SimpleDPS.combatStart = GetTime()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
            local dt = GetTime() - SimpleDPS.combatStart
            SimpleDPS.totalCombatTime = SimpleDPS.totalCombatTime + dt
            SimpleDPS.combatStart = 0
        end
        SimpleDPS.inCombat = false
    end
end)

-- Helper to get current total active combat time (seconds)
local function GetActiveCombatTime()
    local t = SimpleDPS.totalCombatTime
    if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
        t = t + (GetTime() - SimpleDPS.combatStart)
    end
    -- prevent zero division
    if t < 1 then t = 1 end
    return t
end

-- Data recording helper
local function RecordDamage(spellName, amount, sourceGUID)
    if not spellName or amount == 0 then return end
    -- only track player's damage and their pet's (optional)
    if sourceGUID ~= playerGUID then
        -- try to include pet: check if source is player's pet
        -- Basic check: compare owner GUID prefix? Simpler: include if unit is "pet" (we don't have pet GUID easily here)
        -- We'll track only player's direct damage by default
        return
    end

    local d = SimpleDPS.data
    d.totalDamage = (d.totalDamage or 0) + amount
    d.abilities[spellName] = d.abilities[spellName] or { damage = 0, hits = 0 }
    d.abilities[spellName].damage = d.abilities[spellName].damage + amount
    d.abilities[spellName].hits = d.abilities[spellName].hits + 1
end

-- Combat log parsing (preferred). Works with COMBAT_LOG_EVENT_UNFILTERED.
-- Modern API returns many values through CombatLogGetCurrentEventInfo()
local function OnCombatLogEvent()
    local timeStamp, subEvent, _, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, extra1, extra2, extra3, extra4 = CombatLogGetCurrentEventInfo()
    if not subEvent then return end

    -- Handle spell damage types and ranged/swing
    if subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        local amount = extra1 -- amount is usually the first extra param for damage
        if type(amount) == "number" and amount > 0 then
            RecordDamage(spellName or ("Spell_"..tostring(spellId)), amount, sourceGUID)
        end
    elseif subEvent == "SWING_DAMAGE" then
        local amount = extra1
        if type(amount) == "number" and amount > 0 then
            RecordDamage("Melee", amount, sourceGUID)
        end
    end
end

-- Fallback: older chat combat messages parsing for servers where combat log event isn't available
-- NOTE: parsing chat text is fragile and locale-dependent. This fallback handles English basic patterns.
local function OnChatCombatEvent(self, event, msg, author, ...)
    -- Only process events where player is the source (author is "You" or playerName)
    -- Typical messages: "Your Fireball hits Orc for 120.", "You hit Orc for 40."
    -- We look for patterns: "Your (.+) hits .+ for (%d+)" and "You hit .+ for (%d+)" (melee)
    if not msg then return end

    -- your spells
    local spell, dmg = string.match(msg, "^Your (.+) hits .+ for (%d+)")
    if spell and dmg then
        RecordDamage(spell, tonumber(dmg), playerGUID)
        return
    end
    -- crit variant
    spell, dmg = string.match(msg, "^Your (.+) crits .+ for (%d+)")
    if spell and dmg then
        RecordDamage(spell, tonumber(dmg), playerGUID)
        return
    end
    -- melee 'You hit' - treat as "Melee"
    dmg = string.match(msg, "^You hit .+ for (%d+)")
    if dmg then
        RecordDamage("Melee", tonumber(dmg), playerGUID)
        return
    end
end

-- Register combat log handler if available, else register chat fallback
if CombatLogGetCurrentEventInfo then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- handled above via second handler - keep for safety
        else
            -- other events already handled above
        end
    end)
else
    -- fallback chat events (English-only basic patterns)
    local chatFrame = frame
    local chatEvents = {
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "CHAT_MSG_COMBAT_SELF_HITS",
        "CHAT_MSG_COMBAT_SELF_MISSES",
        "CHAT_MSG_SPELL_SELF_BUFF",
        "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
        -- party/friendly versions could be added
    }
    for _, ev in ipairs(chatEvents) do
        chatFrame:RegisterEvent(ev)
    end

    chatFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- handled earlier by top-level script; ignore here
            return
        end
        local msg = select(1, ...)
        OnChatCombatEvent(self, event, msg, ...)
    end)
end

-- UI: very small scrolling list
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

-- Scrolling content
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

-- Refresh UI listing
local function RefreshUI()
    local d = SimpleDPS.data
    local total = d.totalDamage or 0
    local totTime = GetActiveCombatTime()
    -- collect abilities into array and sort by DPS descending
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

-- Refresh on a small timer so it updates while fighting
local uiTicker = ui:CreateAnimationGroup()
local anim = uiTicker:CreateAnimation()
uiTicker:SetLooping("REPEAT")
uiTicker:SetScript("OnPlay", function() end)
anim:SetDuration(0.6) -- not used directly
ui:SetScript("OnUpdate", function(self, elapsed)
    -- simple throttled refresh: only refresh once every 0.6s
    if not self._acc then self._acc = 0 end
    self._acc = self._acc + elapsed
    if self._acc >= 0.6 then
        RefreshUI()
        self._acc = 0
    end
end)

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
        -- very small export to chat
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

-- init message
print("SimpleDPS loaded. Use /sdps for commands.")
