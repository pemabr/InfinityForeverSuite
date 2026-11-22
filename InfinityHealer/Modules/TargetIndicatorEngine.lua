-- TargetIndicatorEngine.lua - Highlight your current target, focus, and assist
-- Part of InfinityHealer addon suite
-- Shows visual indicators on frames for target selection

local TargetIndicatorEngine = {}
TargetIndicatorEngine.enabled = false
TargetIndicatorEngine.db = nil
TargetIndicatorEngine.frame_cache = {}

-- Configuration
TargetIndicatorEngine.config = {
    enabled = true,
    show_target_indicator = true,
    show_focus_indicator = true,
    show_assist_indicator = true,
    target_color = { 1, 1, 0 },  -- Yellow
    focus_color = { 0, 1, 1 },  -- Cyan
    assist_color = { 1, 0.5, 0 },  -- Orange
    indicator_width = 2,  -- Border thickness
    update_frequency = 0.1,
}

function TargetIndicatorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.frame_cache then
        self.db.frame_cache = {}
    end
    
    self.frame_cache = self.db.frame_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function TargetIndicatorEngine:CreateTargetIndicator(frame)
    if not frame then
        return nil
    end
    
    -- Create target highlight border
    local targetBorder = CreateFrame("Frame", nil, frame)
    targetBorder:SetAllPoints(frame)
    targetBorder:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = self.config.indicator_width,
    })
    targetBorder:SetBackdropBorderColor(1, 1, 0, 0)  -- Yellow, invisible
    targetBorder:Hide()
    
    -- Create focus highlight (thinner border)
    local focusBorder = CreateFrame("Frame", nil, frame)
    focusBorder:SetAllPoints(frame)
    focusBorder:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
    })
    focusBorder:SetBackdropBorderColor(0, 1, 1, 0)  -- Cyan, invisible
    focusBorder:Hide()
    
    -- Create assist highlight
    local assistBorder = CreateFrame("Frame", nil, frame)
    assistBorder:SetAllPoints(frame)
    assistBorder:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
    })
    assistBorder:SetBackdropBorderColor(1, 0.5, 0, 0)  -- Orange, invisible
    assistBorder:Hide()
    
    return {
        frame = frame,
        target_border = targetBorder,
        focus_border = focusBorder,
        assist_border = assistBorder,
        is_target = false,
        is_focus = false,
        is_assist = false,
    }
end

function TargetIndicatorEngine:UpdateTargetIndicators(indicatorData, unitID)
    if not indicatorData or not unitID then
        return
    end
    
    local isTarget = UnitIsUnit(unitID, "target")
    local isFocus = UnitIsUnit(unitID, "focus")
    
    -- Assist is usually the target of your target
    local isAssist = false
    if UnitExists("target") and UnitIsUnit(unitID, "targettarget") then
        isAssist = true
    end
    
    -- Update target indicator
    if isTarget and self.config.show_target_indicator then
        indicatorData.target_border:SetBackdropBorderColor(self.config.target_color[1], self.config.target_color[2], self.config.target_color[3], 1)
        indicatorData.target_border:Show()
        indicatorData.is_target = true
    else
        indicatorData.target_border:Hide()
        indicatorData.is_target = false
    end
    
    -- Update focus indicator
    if isFocus and self.config.show_focus_indicator then
        indicatorData.focus_border:SetBackdropBorderColor(self.config.focus_color[1], self.config.focus_color[2], self.config.focus_color[3], 1)
        indicatorData.focus_border:Show()
        indicatorData.is_focus = true
    else
        indicatorData.focus_border:Hide()
        indicatorData.is_focus = false
    end
    
    -- Update assist indicator
    if isAssist and self.config.show_assist_indicator then
        indicatorData.assist_border:SetBackdropBorderColor(self.config.assist_color[1], self.config.assist_color[2], self.config.assist_color[3], 1)
        indicatorData.assist_border:Show()
        indicatorData.is_assist = true
    else
        indicatorData.assist_border:Hide()
        indicatorData.is_assist = false
    end
end

function TargetIndicatorEngine:GetTargetStatus()
    -- Get current target/focus/assist info
    local target = UnitName("target")
    local focus = UnitName("focus")
    
    local assist = nil
    if UnitExists("target") then
        assist = UnitName("targettarget")
    end
    
    return {
        target = target,
        focus = focus,
        assist = assist,
    }
end

function TargetIndicatorEngine:SetTarget(unitID)
    if unitID then
        TargetUnit(unitID)
        self:Log("Target set to: " .. UnitName(unitID))
    end
end

function TargetIndicatorEngine:SetFocus(unitID)
    if unitID then
        SetFocusUnit(unitID)
        self:Log("Focus set to: " .. UnitName(unitID))
    end
end

function TargetIndicatorEngine:ClearFocus()
    ClearFocus()
    self:Log("Focus cleared")
end

function TargetIndicatorEngine:GetIndicatorStatus(unitID)
    if not unitID then
        return nil
    end
    
    local isTarget = UnitIsUnit(unitID, "target")
    local isFocus = UnitIsUnit(unitID, "focus")
    local isAssist = false
    
    if UnitExists("target") and UnitIsUnit(unitID, "targettarget") then
        isAssist = true
    end
    
    return {
        unit = unitID,
        is_target = isTarget,
        is_focus = isFocus,
        is_assist = isAssist,
    }
end

function TargetIndicatorEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function TargetIndicatorEngine:GetStatus()
    local targetStatus = self:GetTargetStatus()
    
    return {
        enabled = self.enabled,
        current_target = targetStatus.target,
        current_focus = targetStatus.focus,
        show_target = self.config.show_target_indicator,
        show_focus = self.config.show_focus_indicator,
        show_assist = self.config.show_assist_indicator,
    }
end

function TargetIndicatorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[TargetIndicatorEngine] " .. message)
    else
        print("[TargetIndicatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_TARGETINDICATOR1 = "/targetindicator"
    SlashCmdList["TARGETINDICATOR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            if args and args ~= "" then
                TargetIndicatorEngine:SetTarget(args)
                print("Target changed to: " .. args)
            else
                print("Usage: /targetindicator set <unit>")
            end
        elseif cmd == "focus" then
            if args and args ~= "" then
                TargetIndicatorEngine:SetFocus(args)
                print("Focus set to: " .. args)
            else
                print("Usage: /targetindicator focus <unit>")
            end
        elseif cmd == "clearfocus" then
            TargetIndicatorEngine:ClearFocus()
            print("Focus cleared")
        elseif cmd == "check" then
            if args and args ~= "" then
                local status = TargetIndicatorEngine:GetIndicatorStatus(args)
                if status then
                    print("Indicators for " .. args .. ":")
                    print("  Target: " .. tostring(status.is_target))
                    print("  Focus: " .. tostring(status.is_focus))
                    print("  Assist: " .. tostring(status.is_assist))
                else
                    print("Unit not found: " .. args)
                end
            else
                print("Usage: /targetindicator check <unit>")
            end
        elseif cmd == "status" then
            local status = TargetIndicatorEngine:GetStatus()
            print("Target Indicator Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Target Indicator Commands:")
            print("  /targetindicator set <unit> - Set target")
            print("  /targetindicator focus <unit> - Set focus")
            print("  /targetindicator clearfocus - Clear focus")
            print("  /targetindicator check <unit> - Check indicators")
            print("  /targetindicator status - Show system status")
        end
    end
end

return TargetIndicatorEngine
