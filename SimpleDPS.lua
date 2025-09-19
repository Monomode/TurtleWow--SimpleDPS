-- SimpleDPS.lua
-- Core logic: combat parsing, data storage, API, events/callbacks
-- This file should not create UI elements.

SimpleDPSDB = SimpleDPSDB or {}

local coreFrame = CreateFrame("Frame", "SimpleDPSCoreFrame")

local SimpleDPS = {
    data = SimpleDPSDB.data or { totalDamage = 0, abilities = {} },
    totalCombatTime = SimpleDPSDB.totalCombatTime or 0,
    inCombat = false,
    combatStart = 0,
    useCombatLog = (CombatLogGetCurrentEventInfo ~= nil),
    callbacks = {}, -- functions to call when data changes
}

-- Save DB on logout/leaving world
local function SaveDB()
    SimpleDPSDB.data = SimpleDPS.data
    SimpleDPSDB.totalCombatTime = SimpleDPS.totalCombatTime
end

-- Combat timer helpers
local function StartCombatTimer()
    if not SimpleDPS.inCombat then
        SimpleDPS.inCombat = true
        SimpleDPS.combatStart = GetTime()
        -- notify UI
        for _,cb in ipairs(SimpleDPS.callbacks) do pcall(cb, "COMBAT_START") end
    end
end

local function StopCombatTimer()
    if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
        local dt = GetTime() - SimpleDPS.combatStart
        SimpleDPS.totalCombatTime = SimpleDPS.totalCombatTime + dt
        SimpleDPS.combatStart = 0
    end
    SimpleDPS.inCombat = false
    for _,cb in ipairs(SimpleDPS.callbacks) do pcall(cb, "COMBAT_STOP") end
end

local function GetActiveCombatTime()
    local t = SimpleDPS.totalCombatTime
    if SimpleDPS.inCombat and SimpleDPS.combatStart and SimpleDPS.combatStart > 0 then
        t = t + (GetTime() - SimpleDPS.combatStart)
    end
    if t < 1 then t = 1 end
    return t
end

-- Recording damage (only player's direct damage by default)
-- spellName: string, amount: number, sourceGUID: string (from combat log)
function SimpleDPS.RecordDamage(spellName, amount, sourceGUID)
    if not spellName or not amount or amount <= 0 then return end
    -- track only player's own damage; you can change this to include pets
    local playerGUID = UnitGUID("player")
    if sourceGUID ~= playerGUID then return end

    local d = SimpleDPS.data
    d.totalDamage = (d.totalDamage or 0) + amount
    d.abilities[spellName] = d.abilities[spellName] or { damage = 0, hits = 0 }
    d.abilities[spellName].damage = d.abilities[spellName].damage + amount
    d.abilities[spellName].hits = d.abilities[spellName].hits + 1

    -- notify listeners that data changed (ability updated)
    for _,cb in ipairs(SimpleDPS.callbacks) do pcall(cb, "DATA_UPDATED", spellName) end
end

-- Combat log parsing (tries to be resilient)
local function HandleCombatLog()
    local timestamp, subEvent, hideCaster,
        sourceGUID, sourceName, sourceFlags, sourceRaidFlag,
        destGUID, destName, destFlags, destRaidFlag,
        spellId, spellName, spellSchool,
        amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = CombatLogGetCurrentEventInfo()

    if not subEvent then return end
    if subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        if type(amount) == "number" and amount > 0 then
            SimpleDPS.RecordDamage(spellName or ("Spell_"..tostring(spellId)), amount, sourceGUID)
        end
    elseif subEvent == "SWING_DAMAGE" then
        local swingAmount = amount
        if type(swingAmount) == "number" and swingAmount > 0 then
            SimpleDPS.RecordDamage("Melee", swingAmount, sourceGUID)
        end
    end
end

-- Chat fallback (fragile / english)
local function HandleChatEvent(event, msg)
    if not msg then return end
    -- "Your Fireball hits ... for 120."
    local spell, dmg = string.match(msg, "^Your (.+) hits .+ for (%d+)")
    if spell and dmg then
        SimpleDPS.RecordDamage(spell, tonumber(dmg), UnitGUID("player"))
        return
    end
    spell, dmg = string.match(msg, "^Your (.+) crits .+ for (%d+)")
    if spell and dmg then
        SimpleDPS.RecordDamage(spell, tonumber(dmg), UnitGUID("player"))
        return
    end
    dmg = string.match(msg, "^You hit .+ for (%d+)")
    if dmg then
        SimpleDPS.RecordDamage("Melee", tonumber(dmg), UnitGUID("player"))
        return
    end
end

-- Centralized event handler for core
local function CoreOnEvent(self, event, ...)
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
        HandleCombatLog()
        return
    end

    -- chat fallback events
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        local msg = select(1, ...)
        HandleChatEvent(event, msg)
        return
    end
end

-- register events
coreFrame:RegisterEvent("PLAYER_LOGOUT")
coreFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
coreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
coreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

if SimpleDPS.useCombatLog then
    coreFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
else
    coreFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    coreFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    coreFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    coreFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
end

coreFrame:SetScript("OnEvent", CoreOnEvent)

-- Public API for UI / other modules
function SimpleDPS.GetSummary()
    -- returns array sorted by DPS desc
    local d = SimpleDPS.data
    local tot = d.totalDamage or 0
    local tTime = GetActiveCombatTime()
    local arr = {}
    for name,info in pairs(d.abilities) do
        local dmg = info.damage or 0
        local dps = dmg / tTime
        tinsert(arr, { ability = name, damage = dmg, dps = dps, hits = info.hits or 0 })
    end
    table.sort(arr, function(a,b) return a.dps > b.dps end)
    return arr, tot, tTime
end

function SimpleDPS.GetActiveCombatTime() return GetActiveCombatTime() end

function SimpleDPS.Reset()
    SimpleDPS.data = { totalDamage = 0, abilities = {} }
    SimpleDPS.totalCombatTime = 0
    SaveDB()
    for _,cb in ipairs(SimpleDPS.callbacks) do pcall(cb, "RESET") end
end

function SimpleDPS.ExportTop(n)
    n = n or 20
    local arr, tot, tTime = SimpleDPS.GetSummary()
    local out = {}
    for i=1, math.min(n, #arr) do
        local item = arr[i]
        tinsert(out, string.format("%d) %s - DPS: %.1f - Damage: %d - %.1f%%", i, item.ability, item.dps, item.damage, tot>0 and (100*item.damage/tot) or 0))
    end
    return out, tot, tTime
end

-- callback registration
function SimpleDPS.RegisterCallback(func)
    if type(func) == "function" then
        tinsert(SimpleDPS.callbacks, func)
    end
end

-- convenience (global access)
_G.SimpleDPS = SimpleDPS
