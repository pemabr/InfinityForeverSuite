-- AssistIndicatorEngine.lua - Track assist target (target's target)
-- Part of InfinityHealer addon suite
-- Shows assist target status and indicators

local AssistIndicatorEngine = {}
AssistIndicatorEngine.enabled = false
AssistIndicatorEngine.db = nil
AssistIndicatorEngine.assist_cache = {}

-- Configuration
AssistIndicatorEngine.config = {
    enabled = true,
    show_assist = true,
    show_assist_indicator = true,
    show_assist_frame = false,
    assist_color = { 1, 0.5, 0 },  -- Orange
    update_frequency = 0.1,
    indicator_width = 2,
}

function AssistIndicatorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.assist_cache then
        self.db.assist_cache = {}
    end
    
    self.assist_cache = self.db.assist_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function AssistIndicatorEngine:GetAssistTarget()
    -- Assist is the target of your target
    local targetUnit = "target"
    
    if not UnitExists(targetUnit) then
        return nil
    end
    
    local assistUnit = targetUnit .. "target"
    
    if not UnitExists(assistUnit) then
        return nil
    end
    
    local name = UnitName(assistUnit)
    local health = UnitHealth(assistUnit)
    local maxHealth = UnitHealthMax(assistUnit)
    
    if maxHealth <= 0 then
        maxHealth = 100
    end
    
    return {
        unit = assistUnit,
        name = name,
        health = health,
        max_health = maxHealth,
        health_percent = (health / maxHealth) * 100,
        is_alive = not UnitIsDead(assistUnit),
        threat_level = self:GetAssistThreat(assistUnit),
    }
end

function AssistIndicatorEngine:GetAssistThreat(unitID)
    if not unitID or not UnitExists(unitID) then
        return 0
    end
    
    -- Simplified threat check based on being in combat
    if UnitThreatSituation(unitID) then
        return UnitThreatSituation(unitID)
    end
    
    return 0
end

function AssistIndicatorEngine:CreateAssistIndicator(frame)
    if not frame then
        return nil
    end
    
    -- Create assist highlight border
    local assistBorder = CreateFrame("Frame", nil, frame)
    assistBorder:SetAllPoints(frame)
    assistBorder:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = self.config.indicator_width,
    })
    assistBorder:SetBackdropBorderColor(1, 0.5, 0, 0)  -- Orange, invisible initially
    assistBorder:Hide()
    
    return {
        frame = frame,
        assist_border = assistBorder,
        is_assist = false,
    }
end

function AssistIndicatorEngine:UpdateAssistIndicator(indicatorData, unitID)
    if not indicatorData or not unitID then
        return
    end
    
    local assistInfo = self:GetAssistTarget()
    
    if assistInfo and UnitIsUnit(unitID, assistInfo.unit) then
        if self.config.show_assist_indicator then
            indicatorData.assist_border:SetBackdropBorderColor(self.config.assist_color[1], self.config.assist_color[2], self.config.assist_color[3], 1)
            indicatorData.assist_border:Show()
            indicatorData.is_assist = true
        end
    else
        indicatorData.assist_border:Hide()
        indicatorData.is_assist = false
    end
end

function AssistIndicatorEngine:GetAssistStatus()
    local assistInfo = self:GetAssistTarget()
    
    return {
        has_assist = assistInfo ~= nil,
        assist_name = assistInfo and assistInfo.name or "none",
        assist_health = assistInfo and assistInfo.health_percent or 0,
        assist_alive = assistInfo and assistInfo.is_alive or false,
    }
end

function AssistIndicatorEngine:GetFrameIndicatorStatus(unitID)
    if not unitID then
        return nil
    end
    
    local assistInfo = self:GetAssistTarget()
    local isAssist = assistInfo and UnitIsUnit(unitID, assistInfo.unit) or false
    
    return {
        unit = unitID,
        is_assist = isAssist,
        assist_on_this_frame = isAssist,
    }
end

function AssistIndicatorEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function AssistIndicatorEngine:GetStatus()
    local assistStatus = self:GetAssistStatus()
    
    return {
        enabled = self.enabled,
        has_assist = assistStatus.has_assist,
        assist_name = assistStatus.assist_name,
        show_indicator = self.config.show_assist_indicator,
    }
end

function AssistIndicatorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[AssistIndicatorEngine] " .. message)
    else
        print("[AssistIndicatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_ASSISTINDICATOR1 = "/assistindicator"
    SlashCmdList["ASSISTINDICATOR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            local assist = AssistIndicatorEngine:GetAssistTarget()
            if assist then
                print("Assist Target: " .. assist.name)
                print("  Health: " .. math.floor(assist.health_percent) .. "%")
                print("  Alive: " .. tostring(assist.is_alive))
                print("  Threat: " .. assist.threat_level)
            else
                print("No assist target (no target or target has no target)")
            end
        elseif cmd == "status" then
            local status = AssistIndicatorEngine:GetStatus()
            print("Assist Indicator Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "indicator" then
            if args == "on" then
                AssistIndicatorEngine:SetConfig("show_assist_indicator", true)
                print("Assist indicator enabled")
            elseif args == "off" then
                AssistIndicatorEngine:SetConfig("show_assist_indicator", false)
                print("Assist indicator disabled")
            else
                print("Usage: /assistindicator indicator <on|off>")
            end
        else
            print("Assist Indicator Commands:")
            print("  /assistindicator check - Check assist target")
            print("  /assistindicator indicator <on|off> - Toggle indicator")
            print("  /assistindicator status - Show system status")
        end
    end
end

return AssistIndicatorEngine
