-- RangeIndicatorEngine.lua - Display range status visually on frames
-- Part of PluribusHealer addon suite
-- Shows text, icons, or colors indicating if player is in range

local RangeIndicatorEngine = {}
RangeIndicatorEngine.enabled = false
RangeIndicatorEngine.db = nil
RangeIndicatorEngine.range_cache = {}

-- Configuration
RangeIndicatorEngine.config = {
    enabled = true,
    max_healing_range = 40,
    show_text = true,
    show_icon = true,
    show_color = false,
    out_of_range_color = { 0.8, 0.2, 0.2 },
    in_range_color = { 0.2, 0.8, 0.2 },
    update_frequency = 1.0,
    display_mode = "text",  -- text, icon, both
}

function RangeIndicatorEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.range_cache then
        self.db.range_cache = {}
    end
    
    self.range_cache = self.db.range_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function RangeIndicatorEngine:GetUnitRange(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    -- Simplified distance check (actual range varies by spell)
    local distance = 0
    
    -- Use the more reliable method: check distance in yards
    if UnitIsPlayer(unitID) then
        local x1, y1 = UnitPosition("player")
        local x2, y2 = UnitPosition(unitID)
        
        if x1 and x2 and y1 and y2 then
            distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        end
    end
    
    return distance
end

function RangeIndicatorEngine:IsInRange(unitID)
    if not unitID or not UnitExists(unitID) then
        return false
    end
    
    local distance = self:GetUnitRange(unitID)
    if not distance then
        return false
    end
    
    return distance <= self.config.max_healing_range
end

function RangeIndicatorEngine:GetRangeStatus(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    local distance = self:GetUnitRange(unitID)
    
    if not distance then
        return {
            unit = unitID,
            distance = 0,
            max_range = self.config.max_healing_range,
            in_range = false,
            range_percent = 0,
            status = "unknown",
        }
    end
    
    local in_range = distance <= self.config.max_healing_range
    local range_percent = (distance / self.config.max_healing_range) * 100
    
    if range_percent > 100 then
        range_percent = 100
    end
    
    local status = "unknown"
    if in_range then
        if distance <= 10 then
            status = "melee"
        elseif distance <= 20 then
            status = "close"
        else
            status = "far"
        end
    else
        status = "out_of_range"
    end
    
    return {
        unit = unitID,
        distance = distance,
        max_range = self.config.max_healing_range,
        in_range = in_range,
        range_percent = range_percent,
        status = status,
    }
end

function RangeIndicatorEngine:CreateRangeIndicator(frame)
    if not frame then
        return nil
    end
    
    -- Create range text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 1, 1, 1)
    
    -- Create range icon (small square)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(8, 8)
    icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    icon:SetTexture("Interface/Buttons/UI-Quickslot")
    
    return {
        frame = frame,
        text = text,
        icon = icon,
        unit = nil,
        last_distance = 0,
        last_status = "unknown",
    }
end

function RangeIndicatorEngine:UpdateRangeIndicator(indicatorData, unitID)
    if not indicatorData or not unitID then
        return
    end
    
    indicatorData.unit = unitID
    
    local rangeStatus = self:GetRangeStatus(unitID)
    if not rangeStatus then
        indicatorData.text:SetText("")
        return
    end
    
    -- Update text
    if self.config.show_text then
        self:UpdateRangeText(indicatorData, rangeStatus)
    else
        indicatorData.text:SetText("")
    end
    
    -- Update icon color
    if self.config.show_icon then
        self:UpdateRangeIcon(indicatorData, rangeStatus)
    else
        indicatorData.icon:SetAlpha(0)
    end
    
    indicatorData.last_distance = rangeStatus.distance
    indicatorData.last_status = rangeStatus.status
end

function RangeIndicatorEngine:UpdateRangeText(indicatorData, rangeStatus)
    if not indicatorData or not rangeStatus then
        return
    end
    
    local text = ""
    
    if rangeStatus.in_range then
        if rangeStatus.status == "melee" then
            text = "MELEE"
            indicatorData.text:SetTextColor(0.2, 0.8, 0.2)
        elseif rangeStatus.status == "close" then
            text = math.floor(rangeStatus.distance) .. "y"
            indicatorData.text:SetTextColor(0.2, 0.8, 0.2)
        else
            text = math.floor(rangeStatus.distance) .. "y"
            indicatorData.text:SetTextColor(1, 1, 0.5)
        end
    else
        text = "OOR"
        indicatorData.text:SetTextColor(0.8, 0.2, 0.2)
    end
    
    indicatorData.text:SetText(text)
end

function RangeIndicatorEngine:UpdateRangeIcon(indicatorData, rangeStatus)
    if not indicatorData or not rangeStatus then
        return
    end
    
    if rangeStatus.in_range then
        indicatorData.icon:SetVertexColor(0.2, 0.8, 0.2, 1)  -- Green
    else
        indicatorData.icon:SetVertexColor(0.8, 0.2, 0.2, 1)  -- Red
    end
    
    indicatorData.icon:SetAlpha(1)
end

function RangeIndicatorEngine:GetRangeReport(unitID)
    if not unitID then
        return nil
    end
    
    local rangeStatus = self:GetRangeStatus(unitID)
    if not rangeStatus then
        return nil
    end
    
    local name = UnitName(unitID)
    
    return {
        name = name,
        unit = unitID,
        distance = math.floor(rangeStatus.distance),
        in_range = rangeStatus.in_range,
        status = rangeStatus.status,
    }
end

function RangeIndicatorEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function RangeIndicatorEngine:GetStatus()
    return {
        enabled = self.enabled,
        max_range = self.config.max_healing_range,
        show_text = self.config.show_text,
        show_icon = self.config.show_icon,
        display_mode = self.config.display_mode,
    }
end

function RangeIndicatorEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[RangeIndicatorEngine] " .. message)
    else
        print("[RangeIndicatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RANGEINDICATOR1 = "/rangeindicator"
    SlashCmdList["RANGEINDICATOR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local report = RangeIndicatorEngine:GetRangeReport(args)
                if report then
                    print("Range for " .. report.name .. ":")
                    print("  Distance: " .. report.distance .. " yards")
                    print("  In Range: " .. tostring(report.in_range))
                    print("  Status: " .. report.status)
                else
                    print("Unit not found: " .. args)
                end
            else
                print("Usage: /rangeindicator check <unit>")
            end
        elseif cmd == "range" then
            if args and tonumber(args) then
                RangeIndicatorEngine:SetConfig("max_healing_range", tonumber(args))
                print("Max healing range set to: " .. args .. " yards")
            else
                print("Usage: /rangeindicator range <yards>")
            end
        elseif cmd == "status" then
            local status = RangeIndicatorEngine:GetStatus()
            print("Range Indicator Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Range Indicator Commands:")
            print("  /rangeindicator check <unit> - Check range to unit")
            print("  /rangeindicator range <yards> - Set max healing range")
            print("  /rangeindicator status - Show system status")
        end
    end
end

return RangeIndicatorEngine
