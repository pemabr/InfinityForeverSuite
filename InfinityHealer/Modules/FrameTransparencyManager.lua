-- FrameTransparencyManager.lua - Fade out-of-range player frames
-- Part of InfinityHealer addon suite
-- Changes frame opacity based on range

local FrameTransparencyManager = {}
FrameTransparencyManager.enabled = false
FrameTransparencyManager.db = nil
FrameTransparencyManager.frame_cache = {}

-- Configuration
FrameTransparencyManager.config = {
    enabled = true,
    fade_out_of_range = true,
    in_range_alpha = 1.0,
    out_of_range_alpha = 0.4,
    max_range = 40,
    update_frequency = 1.0,
    fade_smooth = true,
    fade_speed = 0.2,
}

function FrameTransparencyManager:Initialize()
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

function FrameTransparencyManager:GetUnitRange(unitID)
    if not unitID or not UnitExists(unitID) then
        return 999  -- Out of range
    end
    
    local x1, y1 = UnitPosition("player")
    local x2, y2 = UnitPosition(unitID)
    
    if not (x1 and x2 and y1 and y2) then
        return 999
    end
    
    local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    return distance
end

function FrameTransparencyManager:IsInRange(unitID)
    if not unitID then
        return false
    end
    
    local distance = self:GetUnitRange(unitID)
    return distance <= self.config.max_range
end

function FrameTransparencyManager:UpdateFrameTransparency(frame, unitID)
    if not frame or not unitID then
        return
    end
    
    local in_range = self:IsInRange(unitID)
    
    if self.config.fade_out_of_range then
        local targetAlpha = in_range and self.config.in_range_alpha or self.config.out_of_range_alpha
        
        if self.config.fade_smooth then
            self:SmoothFadeFrame(frame, targetAlpha)
        else
            frame:SetAlpha(targetAlpha)
        end
    else
        frame:SetAlpha(1.0)
    end
end

function FrameTransparencyManager:SmoothFadeFrame(frame, targetAlpha)
    if not frame then
        return
    end
    
    local currentAlpha = frame:GetAlpha()
    local difference = targetAlpha - currentAlpha
    
    if math.abs(difference) < 0.01 then
        frame:SetAlpha(targetAlpha)
        return
    end
    
    -- Smooth fade
    local newAlpha = currentAlpha + (difference * self.config.fade_speed)
    frame:SetAlpha(newAlpha)
end

function FrameTransparencyManager:UpdateGroupFramesTransparency(frames)
    if not frames then
        return
    end
    
    for i, frameData in ipairs(frames) do
        if frameData.frame and frameData.unit then
            self:UpdateFrameTransparency(frameData.frame, frameData.unit)
        end
    end
end

function FrameTransparencyManager:FadeAllOutOfRange(frames)
    -- Quickly fade all out-of-range frames
    if not frames then
        return
    end
    
    for i, frameData in ipairs(frames) do
        if frameData.frame and frameData.unit then
            local in_range = self:IsInRange(frameData.unit)
            
            if not in_range then
                frameData.frame:SetAlpha(self.config.out_of_range_alpha)
            else
                frameData.frame:SetAlpha(self.config.in_range_alpha)
            end
        end
    end
end

function FrameTransparencyManager:GetTransparencyStatus(unitID)
    if not unitID then
        return nil
    end
    
    local in_range = self:IsInRange(unitID)
    local distance = self:GetUnitRange(unitID)
    
    return {
        unit = unitID,
        distance = distance,
        in_range = in_range,
        current_alpha = in_range and self.config.in_range_alpha or self.config.out_of_range_alpha,
    }
end

function FrameTransparencyManager:GetRangeReport()
    -- Get all frame transparency statuses
    local report = {}
    
    for i = 1, 40 do
        local unitID = "raid" .. i
        
        if UnitExists(unitID) then
            local status = self:GetTransparencyStatus(unitID)
            if status then
                table.insert(report, status)
            end
        end
    end
    
    return report
end

function FrameTransparencyManager:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function FrameTransparencyManager:GetStatus()
    return {
        enabled = self.enabled,
        fade_out_of_range = self.config.fade_out_of_range,
        in_range_alpha = self.config.in_range_alpha,
        out_of_range_alpha = self.config.out_of_range_alpha,
        max_range = self.config.max_range,
        fade_smooth = self.config.fade_smooth,
    }
end

function FrameTransparencyManager:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[FrameTransparencyManager] " .. message)
    else
        print("[FrameTransparencyManager] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_FRAMETRANSPARENCY1 = "/frametrans"
    SlashCmdList["FRAMETRANSPARENCY"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local status = FrameTransparencyManager:GetTransparencyStatus(args)
                if status then
                    print("Transparency for " .. args .. ":")
                    print("  Distance: " .. math.floor(status.distance) .. " yards")
                    print("  In Range: " .. tostring(status.in_range))
                    print("  Alpha: " .. math.floor(status.current_alpha * 100) .. "%")
                else
                    print("Unit not found: " .. args)
                end
            else
                print("Usage: /frametrans check <unit>")
            end
        elseif cmd == "fade" then
            if args == "in" then
                FrameTransparencyManager:SetConfig("fade_out_of_range", true)
                print("Fade enabled")
            elseif args == "off" then
                FrameTransparencyManager:SetConfig("fade_out_of_range", false)
                print("Fade disabled")
            else
                print("Usage: /frametrans fade <in|off>")
            end
        elseif cmd == "range" then
            if args and tonumber(args) then
                FrameTransparencyManager:SetConfig("max_range", tonumber(args))
                print("Max range set to: " .. args .. " yards")
            else
                print("Usage: /frametrans range <yards>")
            end
        elseif cmd == "alpha" then
            local inAlpha, outAlpha = args:match("^(%S+)%s+(%S+)$")
            if inAlpha and outAlpha and tonumber(inAlpha) and tonumber(outAlpha) then
                FrameTransparencyManager:SetConfig("in_range_alpha", tonumber(inAlpha))
                FrameTransparencyManager:SetConfig("out_of_range_alpha", tonumber(outAlpha))
                print("Alpha set - In range: " .. inAlpha .. " Out of range: " .. outAlpha)
            else
                print("Usage: /frametrans alpha <in_alpha> <out_alpha> (0.0-1.0)")
            end
        elseif cmd == "status" then
            local status = FrameTransparencyManager:GetStatus()
            print("Frame Transparency Manager:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Frame Transparency Commands:")
            print("  /frametrans check <unit> - Check frame transparency")
            print("  /frametrans fade <in|off> - Toggle fading")
            print("  /frametrans range <yards> - Set max range")
            print("  /frametrans alpha <in> <out> - Set alpha values")
            print("  /frametrans status - Show system status")
        end
    end
end

return FrameTransparencyManager
