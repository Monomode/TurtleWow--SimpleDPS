-- SimpleDPSUI.lua
-- UI file: purely presentation and registering callbacks to SimpleDPS core

-- Wait until core loaded
if not SimpleDPS then
    print("SimpleDPS UI: core not loaded")
    return
end

local ui = CreateFrame("Frame", "SimpleDPS_UI", UIParent, "BackdropTemplate")
ui:SetSize(420, 320)
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
header:SetPoint("TOPLEFT", 12, -32)
header:SetText("Ability                                   DPS     Total     %")

local scroll = CreateFrame("ScrollFrame", "SimpleDPSScroll", ui, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
scroll:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -28, 12)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1,1)
scroll:SetScrollChild(content)

local lines = {}
local maxLines = 35
for i=1, maxLines do
    local f = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetPoint("TOPLEFT", content, "TOPLEFT", 8, - (i-1) * 16)
    f:SetWidth(380)
    f:SetJustifyH("LEFT")
    lines[i] = f
end

-- Refresh function uses SimpleDPS API
local function RefreshUI()
    local arr, total, ttime = SimpleDPS.GetSummary()
    for i=1, maxLines do
        if arr[i] then
            local pct = total>0 and (100 * arr[i].damage / total) or 0
            lines[i]:SetText(string.format("%2d. %-33s %6.1f  %8d  %5.1f%%", i, arr[i].ability, arr[i].dps, arr[i].damage, pct))
        else
            lines[i]:SetText("")
        end
    end
end

-- register refresh as callback with core
SimpleDPS.RegisterCallback(function(event, ...)
    -- possible events: "DATA_UPDATED", "COMBAT_START", "COMBAT_STOP", "RESET"
    -- update UI when data changes or combat state changes
    if event == "DATA_UPDATED" or event == "COMBAT_STOP" or event == "COMBAT_START" or event == "RESET" then
        RefreshUI()
    end
end)

-- expose simple show/hide functions to core or slash commands
function SimpleDPS.ShowUI()
    ui:Show()
    RefreshUI()
end
function SimpleDPS.HideUI()
    ui:Hide()
end

-- simple minimap button (optional)
local function CreateMinimapButton()
    if SimpleDPS_MinimapButton then return end
    local b = CreateFrame("Button", "SimpleDPS_MinimapButton", Minimap)
    b:SetSize(26,26)
    b:SetFrameLevel(8)
    b:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    b.texture = b:CreateTexture(nil, "ARTWORK")
    b.texture:SetAllPoints()
    b.texture:SetTexture("Interface\\Icons\\INV_Misc_Head_Dwarf_01") -- placeholder icon
    b:SetScript("OnClick", function()
        if ui:IsShown() then
            ui:Hide()
        else
            ui:Show()
        end
    end)
    SimpleDPS_MinimapButton = b
end
-- optional: createMinimap now or later
-- CreateMinimapButton()

-- register slash commands here (UI ties into core)
SLASH_SIMPLEDPS1 = "/sdps"
SlashCmdList["SIMPLEDPS"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "show" then
        SimpleDPS.ShowUI()
    elseif msg == "hide" then
        SimpleDPS.HideUI()
    elseif msg == "reset" then
        SimpleDPS.Reset()
        RefreshUI()
        print("SimpleDPS: data reset")
    elseif msg == "export" then
        local out, tot, ttime = SimpleDPS.ExportTop(20)
        print("SimpleDPS Export - TotalDamage:", tot, "CombatTime(s):", math.floor(ttime))
        for _,line in ipairs(out) do print(line) end
    else
        print("SimpleDPS commands:")
        print("/sdps show   - Show UI")
        print("/sdps hide   - Hide UI")
        print("/sdps reset  - Reset tracked data and combat time")
        print("/sdps export - Print top abilities to chat")
    end
end

-- auto-show UI first time damage recorded (optional)
local firstDamageSeen = false
SimpleDPS.RegisterCallback(function(event, ...)
    if event == "DATA_UPDATED" and not firstDamageSeen then
        firstDamageSeen = true
        -- Uncomment to auto-show when first damage recorded:
        -- SimpleDPS.ShowUI()
    end
end)
