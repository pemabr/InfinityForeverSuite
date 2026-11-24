-- FrameColoringEngine.lua - Tint out-of-range player frames with color
-- Part of PluribusHealer addon suite
-- Changes frame color based on range and other conditions

local FrameColoringEngine = {}
FrameColoringEngine.enabled = false
FrameColoringEngine.db = nil
FrameColoringEngine.frame_cache = {}

-- Configuration
FrameColoringEngine.config = {
    enabled = true,
    color_by_range = true,
    color_by_class = false,
    color_by_role = false,
    max_range = 40,
    in_range_tint = { 1, 1, 1 },  -- White (no tint)
    out_of_range_tint = { 0.5, 0.5, 0.5 },  -- Gray
    low_health_tint = { 1, 0.5, 0.5 },  -- Red-ish
    dead_tint = { 0.3, 0.3, 0.3 },  -- Dark gray
    update_frequency = 1.0,
}

-- Class colors for reference
FrameColoringEngine.class_colors = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1, 0.96, 0.41 },
    PRIEST = { 1, 1, 1 },
    SHAMAN = { 0, 0.44, 0.87 },
    DRUID = { 1, 0.49, 0.04 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    MAGE = { 0.41, 0.80, 0.94 },
}

-- Role colors for reference
FrameColoringEngine.role_colors = {
    TANK = { 0.8, 0.5, 0.2 },  -- Orange
    HEALER = { 0.2, 0.8, 0.5 },  -- Green
    DAMAGER = { 0.8, 0.2, 0.2 },  -- Red
}

function FrameColoringEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
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

function FrameColoringEngine:GetUnitRange(unitID)
    if not unitID or not UnitExists(unitID) then
        return 999
    end
    
    local x1, y1 = UnitPosition("player")
    local x2, y2 = UnitPosition(unitID)
    
    if not (x1 and x2 and y1 and y2) then
        return 999
    end
    
    local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    return distance
end

function FrameColoringEngine:IsInRange(unitID)
    if not unitID then
        return false
    end
    
    local distance = self:GetUnitRange(unitID)
    return distance <= self.config.max_range
end

function FrameColoringEngine:GetUnitClass(unitID)
    if not unitID then
        return nil
    end
    
    return select(2, UnitClass(unitID))
end

function FrameColoringEngine:GetUnitRole(unitID)
    if not unitID then
        return nil
    end
    
    -- Simplified role detection based on class
    local class = self:GetUnitClass(unitID)
    
    -- Proper role detection would need GroupRole API
    if class == "PALADIN" or class == "WARRIOR" or class == "DRUID" then
        return "TANK"  -- Could be tank
    elseif class == "PRIEST" or class == "SHAMAN" or class == "DRUID" then
        return "HEALER"  -- Could be healer
    else
        return "DAMAGER"
    end
end

function FrameColoringEngine:GetUnitHealthPercent(unitID)
    if not unitID or not UnitExists(unitID) then
        return 100
    end
    
    local health = UnitHealth(unitID)
    local maxHealth = UnitHealthMax(unitID)
    
    if maxHealth <= 0 then
        return 0
    end
    
    return (health / maxHealth) * 100
end

function FrameColoringEngine:CalculateFrameColor(unitID)
    if not unitID or not UnitExists(unitID) then
        return self.config.out_of_range_tint
    end
    
    -- Check if dead first
    if UnitIsDead(unitID) then
        return self.config.dead_tint
    end
    
    -- Check by range
    if self.config.color_by_range then
        local in_range = self:IsInRange(unitID)
        
        if in_range then
            -- Check health
            local healthPercent = self:GetUnitHealthPercent(unitID)
            if healthPercent < 30 then
                return self.config.low_health_tint
            end
            return self.config.in_range_tint
        else
            return self.config.out_of_range_tint
        end
    end
    
    -- Check by class
    if self.config.color_by_class then
        local class = self:GetUnitClass(unitID)
        if class and self.class_colors[class] then
            return self.class_colors[class]
        end
        return { 1, 1, 1 }
    end
    
    -- Check by role
    if self.config.color_by_role then
        local role = self:GetUnitRole(unitID)
        if role and self.role_colors[role] then
            return self.role_colors[role]
        end
        return { 1, 1, 1 }
    end
    
    return { 1, 1, 1 }
end

function FrameColoringEngine:UpdateFrameColor(frame, unitID)
    if not frame or not unitID then
        return
    end
    
    local color = self:CalculateFrameColor(unitID)
    
    if frame and color then
        frame:SetVertexColor(color[1], color[2], color[3], 1)
    end
end

function FrameColoringEngine:UpdateGroupFrameColors(frames)
    if not frames then
        return
    end
    
    for i, frameData in ipairs(frames) do
        if frameData.frame and frameData.unit then
            self:UpdateFrameColor(frameData.frame, frameData.unit)
        end
    end
end

function FrameColoringEngine:GetColorStatus(unitID)
    if not unitID then
        return nil
    end
    
    local color = self:CalculateFrameColor(unitID)
    
    return {
        unit = unitID,
        color = color,
        in_range = self:IsInRange(unitID),
        is_dead = UnitIsDead(unitID),
        health_percent = self:GetUnitHealthPercent(unitID),
    }
end

function FrameColoringEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function FrameColoringEngine:SetColorMode(mode)
    -- mode: "range", "class", "role"
    if mode == "range" then
        self.config.color_by_range = true
        self.config.color_by_class = false
        self.config.color_by_role = false
    elseif mode == "class" then
        self.config.color_by_range = false
        self.config.color_by_class = true
        self.config.color_by_role = false
    elseif mode == "role" then
        self.config.color_by_range = false
        self.config.color_by_class = false
        self.config.color_by_role = true
    end
    
    self:Log("Color mode set to: " .. mode)
end

function FrameColoringEngine:GetStatus()
    local mode = "none"
    if self.config.color_by_range then
        mode = "range"
    elseif self.config.color_by_class then
        mode = "class"
    elseif self.config.color_by_role then
        mode = "role"
    end
    
    return {
        enabled = self.enabled,
        color_mode = mode,
        max_range = self.config.max_range,
    }
end

function FrameColoringEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[FrameColoringEngine] " .. message)
    else
        print("[FrameColoringEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_FRAMECOLORING1 = "/framecolor"
    SlashCmdList["FRAMECOLORING"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "mode" then
            if args and args ~= "" then
                if args == "range" or args == "class" or args == "role" then
                    FrameColoringEngine:SetColorMode(args)
                    print("Color mode: " .. args)
                else
                    print("Usage: /framecolor mode <range|class|role>")
                end
            else
                local status = FrameColoringEngine:GetStatus()
                print("Current color mode: " .. status.color_mode)
            end
        elseif cmd == "check" then
            if args and args ~= "" then
                local status = FrameColoringEngine:GetColorStatus(args)
                if status then
                    print("Color for " .. args .. ":")
                    print("  RGB: " .. math.floor(status.color[1] * 255) .. ", " .. math.floor(status.color[2] * 255) .. ", " .. math.floor(status.color[3] * 255))
                    print("  In Range: " .. tostring(status.in_range))
                    print("  Dead: " .. tostring(status.is_dead))
                    print("  Health: " .. math.floor(status.health_percent) .. "%")
                else
                    print("Unit not found: " .. args)
                end
            else
                print("Usage: /framecolor check <unit>")
            end
        elseif cmd == "status" then
            local status = FrameColoringEngine:GetStatus()
            print("Frame Coloring Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Frame Coloring Commands:")
            print("  /framecolor mode <range|class|role> - Set coloring mode")
            print("  /framecolor check <unit> - Check frame color")
            print("  /framecolor status - Show system status")
        end
    end
end

return FrameColoringEngine
