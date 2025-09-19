-- SimpleDPS.lua

-- Create a main frame that waits for PLAYER_LOGIN
local SimpleDPS = CreateFrame("Frame")
SimpleDPS:RegisterEvent("PLAYER_LOGIN")
SimpleDPS:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then

        -- Create the actual display frame
        local f = CreateFrame("Frame", "SimpleDPSFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        f:SetSize(220, 260)
        f:SetPoint("CENTER")
        f:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 1,
        })
        f:SetBackdropColor(0,0,0,0.7)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        -- FontString for DPS display
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("TOPLEFT", 10, -10)
        f.text:SetPoint("BOTTOMRIGHT", -10, 40)
        f.text:SetJustifyH("LEFT")
        f.text:SetJustifyV("TOP")

        -- Reset button
        f.resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.resetButton:SetSize(200, 30)
        f.resetButton:SetPoint("BOTTOM", 0, 5)
        f.resetButton:SetText("Reset DPS")
        f.resetButton:SetScript("OnClick", function()
            SimpleDPS.damageData = {}
            SimpleDPS.startTime = nil
        end)

        -- Slash command to toggle frame
        SLASH_SIMPLEDPS1 = "/simpledps"
        SlashCmdList["SIMPLEDPS"] = function()
            if f:IsShown() then f:Hide() else f:Show() end
        end

        -- Store globals
        SimpleDPS.frame = f
        SimpleDPS.damageData = {}
        SimpleDPS.startTime = nil
        SimpleDPS.totalTime = 0

        -- Event handling
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self, event)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                local timestamp, subevent, hideCaster,
                      sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
                      destGUID, destName, destFlags, destRaidFlags,
                      spellId, spellName, spellSchool,
                      amount = CombatLogGetCurrentEventInfo()

                if sourceName == UnitName("player") and
                   (subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE") then
                    if spellName and amount then
                        SimpleDPS.damageData[spellName] = (SimpleDPS.damageData[spellName] or 0) + amount
                        if not SimpleDPS.startTime then
                            SimpleDPS.startTime = GetTime()
                        end
                    end
                end

            elseif event == "PLAYER_REGEN_DISABLED" then
                if not SimpleDPS.startTime then
                    SimpleDPS.startTime = GetTime()
                end
            end
        end)

        -- OnUpdate: refresh DPS display every 0.5s
        f:SetScript("OnUpdate", function(self, elapsed)
            if not SimpleDPS.startTime then return end
            SimpleDPS.totalTime = GetTime() - SimpleDPS.startTime
            if SimpleDPS.totalTime <= 0 then return end

            local lines = {}
            for spell, dmg in pairs(SimpleDPS.damageData) do
                local dps = dmg / SimpleDPS.totalTime
                table.insert(lines, string.format("%-12s %.1f DPS", spell, dps))
            end
            table.sort(lines, function(a,b)
                return tonumber(a:match("%s(%d+%.?%d*) DPS")) > tonumber(b:match("%s(%d+%.?%d*) DPS"))
            end)

            f.text:SetText(table.concat(lines, "\n"))
        end)

        -- Show frame immediately
        f:Show()
    end
end)
