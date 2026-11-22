-- QuestNavCompassEngine.lua - Navigation compass display for active quests
-- Part of InfinityQuestie addon suite
-- Displays compass showing direction and distance to quest objectives

local QuestNavCompassEngine = {}
QuestNavCompassEngine.enabled = false
QuestNavCompassEngine.db = nil
QuestNavCompassEngine.compass_data = {}
QuestNavCompassEngine.compass_config = {}
QuestNavCompassEngine.target_waypoint = nil

-- Configuration
QuestNavCompassEngine.config = {
    enabled = true,
    show_compass = true,
    update_frequency = 1,  -- seconds
    show_distance = true,
    show_arrow = true,
    compass_size = 128,
}

function QuestNavCompassEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.compass_data then
        self.db.compass_data = {}
    end
    
    if not self.db.compass_config then
        self.db.compass_config = {}
    end
    
    self.compass_data = self.db.compass_data
    self.compass_config = self.db.compass_config
    self.enabled = true
    
    self:Log("Initialized navigation compass engine")
end

function QuestNavCompassEngine:SetTargetWaypoint(x, y, z)
    if not x or not y then
        return false
    end
    
    self.target_waypoint = {
        x = tonumber(x),
        y = tonumber(y),
        z = z and tonumber(z) or nil,
        set_at = GetTime(),
    }
    
    self:Log("Set target waypoint: (" .. x .. ", " .. y .. ")")
    
    return true
end

function QuestNavCompassEngine:CalculateDirection(playerX, playerY, targetX, targetY)
    if not playerX or not playerY or not targetX or not targetY then
        return nil
    end
    
    -- Calculate angle in degrees (0 = North, 90 = East, 180 = South, 270 = West)
    local dx = targetX - playerX
    local dy = targetY - playerY
    
    local angle = math.atan2(dy, dx) * 180 / math.pi
    -- Normalize to 0-360
    angle = (angle + 450) % 360
    
    return angle
end

function QuestNavCompassEngine:CalculateDistance(playerX, playerY, playerZ, targetX, targetY, targetZ)
    if not playerX or not playerY or not targetX or not targetY then
        return nil
    end
    
    local dx = targetX - playerX
    local dy = targetY - playerY
    local dz = (targetZ and playerZ) and (targetZ - playerZ) or 0
    
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    
    return distance
end

function QuestNavCompassEngine:GetDirectionName(angle)
    if not angle then
        return "Unknown"
    end
    
    if angle < 22.5 or angle >= 337.5 then
        return "North"
    elseif angle < 67.5 then
        return "Northeast"
    elseif angle < 112.5 then
        return "East"
    elseif angle < 157.5 then
        return "Southeast"
    elseif angle < 202.5 then
        return "South"
    elseif angle < 247.5 then
        return "Southwest"
    elseif angle < 292.5 then
        return "West"
    else
        return "Northwest"
    end
end

local function getLivePlayerPosition()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                return pos.x * 100, pos.y * 100, 0
            end
        end
    end
    if GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if x and y then
            return x * 100, y * 100, 0
        end
    end
    return 0, 0, 0
end

function QuestNavCompassEngine:GetCompassData()
    if not self.target_waypoint then
        return nil
    end
    
    local playerX, playerY, playerZ = getLivePlayerPosition()
    
    local direction = self:CalculateDirection(playerX, playerY, 
                                            self.target_waypoint.x, 
                                            self.target_waypoint.y)
    
    local distance = self:CalculateDistance(playerX, playerY, playerZ,
                                           self.target_waypoint.x,
                                           self.target_waypoint.y,
                                           self.target_waypoint.z or 0)
    
    local compass = {
        angle = direction,
        direction_name = self:GetDirectionName(direction),
        distance = distance,
        target_x = self.target_waypoint.x,
        target_y = self.target_waypoint.y,
        is_close = distance < 50,
        is_very_close = distance < 10,
    }
    
    return compass
end

function QuestNavCompassEngine:IsWaypointReached(threshold)
    threshold = threshold or 5
    
    if not self.target_waypoint then
        return false
    end
    
    local playerX, playerY, playerZ = getLivePlayerPosition()
    local distance = self:CalculateDistance(playerX, playerY, playerZ,
                                           self.target_waypoint.x,
                                           self.target_waypoint.y,
                                           self.target_waypoint.z or 0)
    
    return distance < threshold
end

function QuestNavCompassEngine:ClearTarget()
    self.target_waypoint = nil
    self:Log("Cleared target waypoint")
    return true
end

function QuestNavCompassEngine:GetTargetWaypoint()
    return self.target_waypoint
end

function QuestNavCompassEngine:RecordCompassView(compassData)
    if not compassData then
        return false
    end
    
    table.insert(self.compass_data, {
        timestamp = GetTime(),
        angle = compassData.angle,
        distance = compassData.distance,
        direction = compassData.direction_name,
    })
    
    -- Keep only last 100 records
    while #self.compass_data > 100 do
        table.remove(self.compass_data, 1)
    end
    
    return true
end

function QuestNavCompassEngine:GetCompassHistory()
    return self.compass_data
end

function QuestNavCompassEngine:CalculatePathTaken()
    if #self.compass_data < 2 then
        return 0
    end
    
    local totalDistance = 0
    
    for i = 1, #self.compass_data - 1 do
        -- Estimate based on distance changes
        local distDiff = self.compass_data[i + 1].distance - self.compass_data[i].distance
        
        if distDiff > 0 then
            -- Player moved away
            totalDistance = totalDistance + distDiff
        end
    end
    
    return totalDistance
end

function QuestNavCompassEngine:GetAverageDistance()
    if #self.compass_data == 0 then
        return 0
    end
    
    local totalDistance = 0
    
    for _, record in ipairs(self.compass_data) do
        totalDistance = totalDistance + record.distance
    end
    
    return totalDistance / #self.compass_data
end

function QuestNavCompassEngine:IsHeadingTowardWaypoint()
    if #self.compass_data < 2 then
        return nil
    end
    
    local prevDistance = self.compass_data[#self.compass_data - 1].distance
    local currentDistance = self.compass_data[#self.compass_data].distance
    
    return currentDistance < prevDistance
end

function QuestNavCompassEngine:UpdateConfig(key, value)
    if not key then
        return false
    end
    
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    
    return false
end

function QuestNavCompassEngine:GetStatus()
    local hasTarget = self.target_waypoint ~= nil
    
    return {
        enabled = self.enabled,
        show_compass = self.config.show_compass,
        has_target = hasTarget,
        history_entries = #self.compass_data,
        compass_size = self.config.compass_size,
    }
end

function QuestNavCompassEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestNavCompassEngine] " .. message)
    else
        print("[QuestNavCompassEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTCOMPASS1 = "/questcompass"
    SlashCmdList["QUESTCOMPASS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            local x, y = args:match("^([%d.]+)%s+([%d.]+)$")
            if x and y then
                x = tonumber(x)
                y = tonumber(y)
                QuestNavCompassEngine:SetTargetWaypoint(x, y)
                print("Target waypoint set to (" .. x .. ", " .. y .. ")")
            else
                print("Usage: /questcompass set <x> <y> [z]")
            end
        elseif cmd == "clear" then
            QuestNavCompassEngine:ClearTarget()
            print("Target waypoint cleared")
        elseif cmd == "target" then
            local waypoint = QuestNavCompassEngine:GetTargetWaypoint()
            if waypoint then
                print("Current target: (" .. waypoint.x .. ", " .. waypoint.y .. ")")
            else
                print("No target waypoint set")
            end
        elseif cmd == "compass" then
            local data = QuestNavCompassEngine:GetCompassData()
            if data then
                print("Compass Data:")
                print("  Direction: " .. data.direction_name .. " (" .. string.format("%.1f", data.angle) .. "°)")
                print("  Distance: " .. string.format("%.1f", data.distance))
                print("  Close: " .. (data.is_close and "Yes" or "No"))
            else
                print("No target waypoint")
            end
        elseif cmd == "heading" then
            local heading = QuestNavCompassEngine:IsHeadingTowardWaypoint()
            if heading == true then
                print("Status: Heading toward waypoint")
            elseif heading == false then
                print("Status: Moving away from waypoint")
            else
                print("Status: Not enough data")
            end
        elseif cmd == "distance" then
            local avg = QuestNavCompassEngine:GetAverageDistance()
            print("Average distance: " .. string.format("%.1f", avg))
        elseif cmd == "status" then
            local status = QuestNavCompassEngine:GetStatus()
            print("Quest Navigation Compass Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Has Target: " .. (status.has_target and "Yes" or "No"))
            print("  History: " .. status.history_entries .. " entries")
        else
            print("Quest Navigation Compass Commands:")
            print("  /questcompass set <x> <y> [z] - Set target waypoint")
            print("  /questcompass clear - Clear target")
            print("  /questcompass target - Show current target")
            print("  /questcompass compass - Show compass data")
            print("  /questcompass heading - Check if heading toward waypoint")
            print("  /questcompass distance - Show average distance")
            print("  /questcompass status - Show engine status")
        end
    end
end

return QuestNavCompassEngine
