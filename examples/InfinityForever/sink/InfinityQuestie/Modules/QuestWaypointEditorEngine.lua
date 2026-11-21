-- QuestWaypointEditorEngine.lua - Waypoint creation, editing, and management
-- Part of InfinityQuestie addon suite
-- Handles manual waypoint creation and editing for quests

local QuestWaypointEditorEngine = {}
QuestWaypointEditorEngine.enabled = false
QuestWaypointEditorEngine.db = nil
QuestWaypointEditorEngine.waypoints = {}
QuestWaypointEditorEngine.editing_state = {}

-- Configuration
QuestWaypointEditorEngine.config = {
    enabled = true,
    allow_custom_waypoints = true,
    max_waypoints_per_quest = 50,
}

function QuestWaypointEditorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.waypoints then
        self.db.waypoints = {}
    end
    
    if not self.db.editing_state then
        self.db.editing_state = {}
    end
    
    self.waypoints = self.db.waypoints
    self.editing_state = self.db.editing_state
    self.enabled = true
    
    self:Log("Initialized waypoint editor engine")
end

function QuestWaypointEditorEngine:CreateWaypoint(questId, x, y, z, description)
    if not questId or not x or not y then
        return false
    end
    
    if not self.waypoints[questId] then
        self.waypoints[questId] = {}
    end
    
    -- Check waypoint limit
    if #self.waypoints[questId] >= self.config.max_waypoints_per_quest then
        self:Log("Max waypoints reached for quest " .. questId)
        return false
    end
    
    local waypoint = {
        id = table.getn(self.waypoints[questId]) + 1,
        x = tonumber(x),
        y = tonumber(y),
        z = z and tonumber(z) or nil,
        description = description or "Waypoint " .. (table.getn(self.waypoints[questId]) + 1),
        created_at = GetTime(),
        updated_at = GetTime(),
    }
    
    table.insert(self.waypoints[questId], waypoint)
    
    self:Log("Created waypoint " .. waypoint.id .. " for quest " .. questId)
    
    return true
end

function QuestWaypointEditorEngine:EditWaypoint(questId, waypointId, newData)
    if not questId or not waypointId or not newData then
        return false
    end
    
    if not self.waypoints[questId] or not self.waypoints[questId][waypointId] then
        self:Log("Waypoint not found")
        return false
    end
    
    local waypoint = self.waypoints[questId][waypointId]
    
    if newData.x then waypoint.x = tonumber(newData.x) end
    if newData.y then waypoint.y = tonumber(newData.y) end
    if newData.z then waypoint.z = tonumber(newData.z) end
    if newData.description then waypoint.description = newData.description end
    
    waypoint.updated_at = GetTime()
    
    self:Log("Updated waypoint " .. waypointId .. " for quest " .. questId)
    
    return true
end

function QuestWaypointEditorEngine:DeleteWaypoint(questId, waypointId)
    if not questId or not waypointId then
        return false
    end
    
    if not self.waypoints[questId] or not self.waypoints[questId][waypointId] then
        self:Log("Waypoint not found")
        return false
    end
    
    table.remove(self.waypoints[questId], waypointId)
    
    self:Log("Deleted waypoint " .. waypointId .. " for quest " .. questId)
    
    return true
end

function QuestWaypointEditorEngine:GetWaypoints(questId)
    if not questId then
        return {}
    end
    
    if not self.waypoints[questId] then
        return {}
    end
    
    return self.waypoints[questId]
end

function QuestWaypointEditorEngine:GetWaypoint(questId, waypointId)
    if not questId or not waypointId then
        return nil
    end
    
    if self.waypoints[questId] and self.waypoints[questId][waypointId] then
        return self.waypoints[questId][waypointId]
    end
    
    return nil
end

function QuestWaypointEditorEngine:GetWaypointCount(questId)
    if not questId or not self.waypoints[questId] then
        return 0
    end
    
    return #self.waypoints[questId]
end

function QuestWaypointEditorEngine:ClearWaypoints(questId)
    if not questId then
        return false
    end
    
    if self.waypoints[questId] then
        self.waypoints[questId] = {}
        self:Log("Cleared all waypoints for quest " .. questId)
        return true
    end
    
    return false
end

function QuestWaypointEditorEngine:DuplicateWaypoint(questId, waypointId)
    if not questId or not waypointId then
        return false
    end
    
    local waypoint = self:GetWaypoint(questId, waypointId)
    if not waypoint then
        return false
    end
    
    return self:CreateWaypoint(questId, waypoint.x, waypoint.y, waypoint.z, 
                               waypoint.description .. " (copy)")
end

function QuestWaypointEditorEngine:ReorderWaypoints(questId, newOrder)
    if not questId or not newOrder then
        return false
    end
    
    if not self.waypoints[questId] then
        return false
    end
    
    if #newOrder ~= #self.waypoints[questId] then
        return false
    end
    
    local reordered = {}
    for _, index in ipairs(newOrder) do
        if self.waypoints[questId][index] then
            table.insert(reordered, self.waypoints[questId][index])
        end
    end
    
    if #reordered == #self.waypoints[questId] then
        self.waypoints[questId] = reordered
        self:Log("Reordered waypoints for quest " .. questId)
        return true
    end
    
    return false
end

function QuestWaypointEditorEngine:CalculateDistance(wp1, wp2)
    if not wp1 or not wp2 then
        return 0
    end
    
    local dx = wp2.x - wp1.x
    local dy = wp2.y - wp1.y
    local dz = (wp2.z and wp1.z) and (wp2.z - wp1.z) or 0
    
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function QuestWaypointEditorEngine:CalculateTotalDistance(questId)
    if not questId or not self.waypoints[questId] then
        return 0
    end
    
    local waypoints = self.waypoints[questId]
    if #waypoints < 2 then
        return 0
    end
    
    local totalDistance = 0
    
    for i = 1, #waypoints - 1 do
        totalDistance = totalDistance + self:CalculateDistance(waypoints[i], waypoints[i + 1])
    end
    
    return totalDistance
end

function QuestWaypointEditorEngine:FindNearestWaypoint(questId, x, y, z)
    if not questId or not x or not y then
        return nil
    end
    
    if not self.waypoints[questId] then
        return nil
    end
    
    local nearestId = nil
    local nearestDistance = math.huge
    
    local searchPoint = {x = x, y = y, z = z}
    
    for id, waypoint in ipairs(self.waypoints[questId]) do
        local distance = self:CalculateDistance(searchPoint, waypoint)
        
        if distance < nearestDistance then
            nearestDistance = distance
            nearestId = id
        end
    end
    
    if nearestId then
        return {
            id = nearestId,
            waypoint = self.waypoints[questId][nearestId],
            distance = nearestDistance,
        }
    end
    
    return nil
end

function QuestWaypointEditorEngine:ExportWaypoints(questId, format)
    if not questId then
        return nil
    end
    
    if not self.waypoints[questId] then
        return nil
    end
    
    format = format or "lua"
    
    if format == "lua" then
        local lua = "-- Waypoints for quest " .. questId .. "\nlocal waypoints = {\n"
        
        for _, wp in ipairs(self.waypoints[questId]) do
            lua = lua .. "  {id=" .. wp.id .. ", x=" .. wp.x .. ", y=" .. wp.y
            if wp.z then lua = lua .. ", z=" .. wp.z end
            lua = lua .. ", desc='" .. (wp.description or "") .. "'},\n"
        end
        
        lua = lua .. "}\nreturn waypoints"
        return lua
    end
    
    return nil
end

function QuestWaypointEditorEngine:ImportWaypoints(questId, waypointData)
    if not questId or not waypointData then
        return 0
    end
    
    if type(waypointData) ~= "table" then
        return 0
    end
    
    local imported = 0
    
    for _, wp in ipairs(waypointData) do
        if self:CreateWaypoint(questId, wp.x, wp.y, wp.z, wp.description or wp.desc) then
            imported = imported + 1
        end
    end
    
    self:Log("Imported " .. imported .. " waypoints for quest " .. questId)
    return imported
end

function QuestWaypointEditorEngine:GetStatus()
    local totalWaypoints = 0
    local questCount = 0
    
    for questId, waypoints in pairs(self.waypoints) do
        if #waypoints > 0 then
            questCount = questCount + 1
            totalWaypoints = totalWaypoints + #waypoints
        end
    end
    
    return {
        enabled = self.enabled,
        total_waypoints = totalWaypoints,
        quests_with_waypoints = questCount,
        max_per_quest = self.config.max_waypoints_per_quest,
    }
end

function QuestWaypointEditorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestWaypointEditorEngine] " .. message)
    else
        print("[QuestWaypointEditorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTWP1 = "/questwp"
    SlashCmdList["QUESTWP"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local questId, x, y = args:match("^(%d+)%s+([%d.]+)%s+([%d.]+)$")
            if questId and x and y then
                questId = tonumber(questId)
                x = tonumber(x)
                y = tonumber(y)
                if QuestWaypointEditorEngine:CreateWaypoint(questId, x, y) then
                    print("Created waypoint for quest " .. questId .. " at (" .. x .. ", " .. y .. ")")
                else
                    print("Failed to create waypoint")
                end
            else
                print("Usage: /questwp create <questId> <x> <y> [z]")
            end
        elseif cmd == "delete" then
            local questId, wpId = args:match("^(%d+)%s+(%d+)$")
            if questId and wpId then
                questId = tonumber(questId)
                wpId = tonumber(wpId)
                if QuestWaypointEditorEngine:DeleteWaypoint(questId, wpId) then
                    print("Deleted waypoint " .. wpId .. " for quest " .. questId)
                else
                    print("Failed to delete waypoint")
                end
            else
                print("Usage: /questwp delete <questId> <waypointId>")
            end
        elseif cmd == "list" then
            local questId = tonumber(args)
            if questId then
                local wps = QuestWaypointEditorEngine:GetWaypoints(questId)
                print("Waypoints for quest " .. questId .. ":")
                if #wps > 0 then
                    for i, wp in ipairs(wps) do
                        print("  [" .. i .. "] (" .. wp.x .. ", " .. wp.y .. ") - " .. wp.description)
                    end
                else
                    print("  No waypoints")
                end
            else
                print("Usage: /questwp list <questId>")
            end
        elseif cmd == "distance" then
            local questId = tonumber(args)
            if questId then
                local dist = QuestWaypointEditorEngine:CalculateTotalDistance(questId)
                print("Total distance for quest " .. questId .. ": " .. string.format("%.1f", dist))
            else
                print("Usage: /questwp distance <questId>")
            end
        elseif cmd == "clear" then
            local questId = tonumber(args)
            if questId then
                QuestWaypointEditorEngine:ClearWaypoints(questId)
                print("Cleared waypoints for quest " .. questId)
            else
                print("Usage: /questwp clear <questId>")
            end
        elseif cmd == "status" then
            local status = QuestWaypointEditorEngine:GetStatus()
            print("Waypoint Editor Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Waypoints: " .. status.total_waypoints)
            print("  Quests with Waypoints: " .. status.quests_with_waypoints)
        else
            print("Quest Waypoint Editor Commands:")
            print("  /questwp create <questId> <x> <y> [z] - Create waypoint")
            print("  /questwp delete <questId> <waypointId> - Delete waypoint")
            print("  /questwp list <questId> - List waypoints")
            print("  /questwp distance <questId> - Calculate total distance")
            print("  /questwp clear <questId> - Clear all waypoints")
            print("  /questwp status - Show engine status")
        end
    end
end

return QuestWaypointEditorEngine
