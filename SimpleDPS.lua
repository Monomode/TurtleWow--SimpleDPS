local MyDPS = CreateFrame("Frame")
MyDPS:RegisterEvent("PLAYER_LOGIN")
MyDPS:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    -- create first window
    CreateMyDPSWindow(1)
  end
end)

local config = {}
local window = {}

local backdrop_window = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}
local backdrop_border = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function CreateMyDPSWindow(wid)
  config[wid] = config[wid] or {}
  config[wid].bars = config[wid].bars or 8
  config[wid].width = config[wid].width or 177
  config[wid].segment = config[wid].segment or 1
  config[wid].view = config[wid].view or 1

  local frame = CreateFrame("Frame", "MyDPSWindow"..wid, UIParent)
  frame:SetID(wid)
  frame:SetSize(config[wid].width, config[wid].bars * 12 + 22)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  frame:SetBackdrop(backdrop_window)
  frame:SetBackdropColor(.2, .2, .2, .7)
  frame.border = CreateFrame("Frame", nil, frame)
  frame.border:SetAllPoints(frame)
  frame.border:SetBackdrop(backdrop_border)
  frame.border:SetBackdropBorderColor(.7,.7,.7,1)

  -- make draggable
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  -- title text
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", frame, "TOP", 0, -5)
  title:SetText("MyDPS (Shagu style)")

  window[wid] = frame
  frame:Show()
end
