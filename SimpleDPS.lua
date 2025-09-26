--[[
ShaguDPS Lite - Turtle WoW (v1.12) AddOn
----------------------------------------
This is a lightweight DPS meter inspired by ShaguDPS,
built specifically for the Turtle WoW client (1.12 Vanilla).
It avoids modern API calls and is fully compatible with the
original WoW API from patch 1.12.

Goals:
- Always load on login
- Provide real-time DPS/Damage tracking
- Minimal memory usage, minimal code footprint
- Highly simplified compared to full ShaguDPS

This file contains:
- Addon initialization
- Config defaults
- Core data structures
- Utility functions
- Frame scaffolding for expansion
--]]

-- Create addon table
ShaguDPS = {}

------------------------------------------------
-- Dialogs / Shared UI Elements
------------------------------------------------
StaticPopupDialogs["SHAGUMETER_QUESTION"] = {
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

------------------------------------------------
-- Statusbar Textures
------------------------------------------------
local textures = {
  "Interface\\BUTTONS\\WHITE8X8",
  "Interface\\TargetingFrame\\UI-StatusBar",
  "Interface\\Tooltips\\UI-Tooltip-Background",
  "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
}

------------------------------------------------
-- Utility Functions
------------------------------------------------
-- Round numbers to given decimal places
local function round(input, places)
  if not places then places = 0 end
  if type(input) == "number" and type(places) == "number" then
    local pow = 10 ^ places
    return floor(input * pow + 0.5) / pow
  end
end

-- Detect client expansion (should always return "vanilla" in Turtle WoW)
local function expansion()
  local _, _, _, client = GetBuildInfo()
  client = client or 11200
  if client >= 20000 and client <= 20400 then
    return "tbc"
  elseif client >= 30000 and client <= 30300 then
    return "wotlk"
  else
    return "vanilla"
  end
end

------------------------------------------------
-- Shared Variables
------------------------------------------------
local data = {
  damage = {
    [0] = {}, -- overall
    [1] = {}, -- current fight
  },

  heal = {
    [0] = {}, -- overall
    [1] = {}, -- current fight
  },

  classes = {},
}

local dmg_table = {}
local view_dmg_all = {}
local view_dps_all = {}
local playerClasses = {}

------------------------------------------------
-- Default Config
------------------------------------------------
local config = {
  -- size
  height = 15,
  spacing = 0,

  -- tracking
  track_all_units = 0,
  merge_pets = 1,

  -- appearance
  visible = 1,
  backdrop = 1,
  texture = 2,
  pastel = 0,
  lock = 0,
}

-- internal keys that should be skipped when iterating
local internals = {
  ["_sum"] = true,
  ["_ctime"] = true,
  ["_tick"] = true,
  ["_esum"] = true,
  ["_effective"] = true,
}

------------------------------------------------
-- Frame Initialization
------------------------------------------------
-- Persistent settings container
local settings = CreateFrame("Frame", nil, UIParent)

-- Event parser (COMBAT_LOG / CHAT_MSG events for 1.12)
local parser = CreateFrame("Frame")

-- Core window table (to be populated with bars later)
local window = {}

------------------------------------------------
-- Expose Public API
------------------------------------------------
ShaguDPS.data      = data
ShaguDPS.config    = config
ShaguDPS.textures  = textures
ShaguDPS.window    = window
ShaguDPS.settings  = settings
ShaguDPS.internals = internals
ShaguDPS.parser    = parser
ShaguDPS.round     = round
ShaguDPS.expansion = expansion

------------------------------------------------
-- Addon Loader
------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShaguDPS Lite loaded (Turtle WoW - Vanilla)|r")
end)
