-- QuestMapMarkerEngine.lua - Map marker management for quest objectives
-- Part of InfinityQuestie addon suite
-- Manages quest markers on world map, minimap, and nav markers

local QuestMapMarkerEngine = {}
QuestMapMarkerEngine.enabled = false
QuestMapMarkerEngine.db = nil
QuestMapMarkerEngine.markers = {}
QuestMapMarkerEngine.marker_config = {}
QuestMapMarkerEngine.marker_groups = {}

-- Configuration
QuestMapMarkerEngine.config = {
    enabled = true,
    show_world_map = true,
    show_minimap = true,
    show_nav_arrow = true,
    marker_size = 32,
    marker_opacity = 1.0,
}

function QuestMapMarkerEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.markers then
        self.db.markers = {}
    end
    
    if not self.db.marker_config then
        self.db.marker_config = {}
    end
    
    if not self.db.marker_groups then
        self.db.marker_groups = {}
    end
    
    self.markers = self.db.markers
    self.marker_config = self.db.marker_config
    self.marker_groups = self.db.marker_groups
    self.enabled = true
    
    self:Log("Initialized map marker engine")
end

function QuestMapMarkerEngine:CreateMarker(questId, markerType, x, y, mapId)
    if not questId or not markerType then
        return false
    end
    
    local markerId = "quest_" .. questId .. "_" .. GetTime()
    
    local marker = {
        id = markerId,
        quest_id = tonumber(questId),
        type = markerType,  -- "objective", "turnin", "questgiver"
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        map_id = tonumber(mapId) or 0,
        created_at = GetTime(),
        visible = true,
        custom_icon = nil,
    }
    
    self.markers[markerId] = marker
    self:Log("Created marker: " .. markerId .. " for quest " .. questId)
    
    return markerId
end

function QuestMapMarkerEngine:RemoveMarker(markerId)
    if not markerId or not self.markers[markerId] then
        return false
    end
    
    self.markers[markerId] = nil
    self:Log("Removed marker: " .. markerId)
    
    return true
end

function QuestMapMarkerEngine:UpdateMarkerPosition(markerId, x, y)
    if not markerId or not self.markers[markerId] then
        return false
    end
    
    self.markers[markerId].x = tonumber(x) or self.markers[markerId].x
    self.markers[markerId].y = tonumber(y) or self.markers[markerId].y
    self.markers[markerId].updated_at = GetTime()
    
    return true
end

function QuestMapMarkerEngine:SetMarkerVisibility(markerId, visible)
    if not markerId or not self.markers[markerId] then
        return false
    end
    
    self.markers[markerId].visible = visible
    self:Log("Marker " .. markerId .. " visibility: " .. (visible and "shown" or "hidden"))
    
    return true
end

function QuestMapMarkerEngine:GetMarkersByQuestId(questId)
    local result = {}
    questId = tonumber(questId)
    
    for _, marker in pairs(self.markers) do
        if marker.quest_id == questId then
            table.insert(result, marker)
        end
    end
    
    return result
end

function QuestMapMarkerEngine:GetMarkersByType(markerType)
    local result = {}
    
    for _, marker in pairs(self.markers) do
        if marker.type == markerType then
            table.insert(result, marker)
        end
    end
    
    return result
end

function QuestMapMarkerEngine:GetMarkersByMapId(mapId)
    local result = {}
    mapId = tonumber(mapId)
    
    for _, marker in pairs(self.markers) do
        if marker.map_id == mapId then
            table.insert(result, marker)
        end
    end
    
    return result
end

function QuestMapMarkerEngine:CreateMarkerGroup(groupName, questIds)
    if not groupName or not questIds or #questIds == 0 then
        return false
    end
    
    local groupId = "group_" .. groupName .. "_" .. GetTime()
    
    local group = {
        id = groupId,
        name = groupName,
        quest_ids = {},
        created_at = GetTime(),
        visible = true,
        color = { r = 1, g = 1, b = 1 },
    }
    
    for _, questId in ipairs(questIds) do
        table.insert(group.quest_ids, tonumber(questId))
    end
    
    self.marker_groups[groupId] = group
    self:Log("Created marker group: " .. groupName .. " with " .. #questIds .. " quests")
    
    return groupId
end

function QuestMapMarkerEngine:RemoveMarkerGroup(groupId)
    if not groupId or not self.marker_groups[groupId] then
        return false
    end
    
    self.marker_groups[groupId] = nil
    self:Log("Removed marker group: " .. groupId)
    
    return true
end

function QuestMapMarkerEngine:SetGroupVisibility(groupId, visible)
    if not groupId or not self.marker_groups[groupId] then
        return false
    end
    
    self.marker_groups[groupId].visible = visible
    self:Log("Group " .. groupId .. " visibility: " .. (visible and "shown" or "hidden"))
    
    return true
end

function QuestMapMarkerEngine:GetGroupMarkers(groupId)
    if not groupId or not self.marker_groups[groupId] then
        return {}
    end
    
    local group = self.marker_groups[groupId]
    local result = {}
    
    for _, questId in ipairs(group.quest_ids) do
        local questMarkers = self:GetMarkersByQuestId(questId)
        for _, marker in ipairs(questMarkers) do
            table.insert(result, marker)
        end
    end
    
    return result
end

function QuestMapMarkerEngine:SetGroupColor(groupId, r, g, b)
    if not groupId or not self.marker_groups[groupId] then
        return false
    end
    
    self.marker_groups[groupId].color = {
        r = tonumber(r) or 1,
        g = tonumber(g) or 1,
        b = tonumber(b) or 1,
    }
    
    return true
end

function QuestMapMarkerEngine:GetMarkerDistance(markerId, playerX, playerY)
    if not markerId or not self.markers[markerId] then
        return nil
    end
    
    local marker = self.markers[markerId]
    local dx = marker.x - playerX
    local dy = marker.y - playerY
    
    return math.sqrt(dx * dx + dy * dy)
end

function QuestMapMarkerEngine:GetNearestMarker(playerX, playerY, maxDistance)
    maxDistance = maxDistance or 1000
    local nearest = nil
    local nearestDistance = maxDistance
    
    for markerId, marker in pairs(self.markers) do
        if marker.visible then
            local distance = self:GetMarkerDistance(markerId, playerX, playerY)
            if distance and distance < nearestDistance then
                nearest = marker
                nearestDistance = distance
            end
        end
    end
    
    return nearest, nearestDistance
end

function QuestMapMarkerEngine:GetMarkersInRadius(playerX, playerY, radius)
    local result = {}
    
    for markerId, marker in pairs(self.markers) do
        if marker.visible then
            local distance = self:GetMarkerDistance(markerId, playerX, playerY)
            if distance and distance <= radius then
                table.insert(result, { marker = marker, distance = distance })
            end
        end
    end
    
    -- Sort by distance
    table.sort(result, function(a, b) return a.distance < b.distance end)
    
    return result
end

function QuestMapMarkerEngine:SetMarkerIcon(markerId, iconPath)
    if not markerId or not self.markers[markerId] then
        return false
    end
    
    self.markers[markerId].custom_icon = iconPath
    self:Log("Set marker icon: " .. markerId .. " -> " .. iconPath)
    
    return true
end

function QuestMapMarkerEngine:ClearAllMarkers()
    local count = 0
    
    for markerId in pairs(self.markers) do
        self.markers[markerId] = nil
        count = count + 1
    end
    
    self:Log("Cleared " .. count .. " markers")
    
    return count
end

function QuestMapMarkerEngine:GetMarkerStatistics()
    local stats = {
        total_markers = 0,
        visible_markers = 0,
        by_type = {},
        by_map = {},
        total_groups = 0,
    }
    
    for _, marker in pairs(self.markers) do
        stats.total_markers = stats.total_markers + 1
        
        if marker.visible then
            stats.visible_markers = stats.visible_markers + 1
        end
        
        if not stats.by_type[marker.type] then
            stats.by_type[marker.type] = 0
        end
        stats.by_type[marker.type] = stats.by_type[marker.type] + 1
        
        if not stats.by_map[marker.map_id] then
            stats.by_map[marker.map_id] = 0
        end
        stats.by_map[marker.map_id] = stats.by_map[marker.map_id] + 1
    end
    
    for _ in pairs(self.marker_groups) do
        stats.total_groups = stats.total_groups + 1
    end
    
    return stats
end

function QuestMapMarkerEngine:UpdateConfig(key, value)
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

function QuestMapMarkerEngine:GetStatus()
    local stats = self:GetMarkerStatistics()
    
    return {
        enabled = self.enabled,
        total_markers = stats.total_markers,
        visible_markers = stats.visible_markers,
        total_groups = stats.total_groups,
        show_world_map = self.config.show_world_map,
        show_minimap = self.config.show_minimap,
    }
end

function QuestMapMarkerEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestMapMarkerEngine] " .. message)
    else
        print("[QuestMapMarkerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTMARKER1 = "/questmarker"
    SlashCmdList["QUESTMARKER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local questId, markerType, x, y = args:match("^(%d+)%s+(%w+)%s+([%d.]+)%s+([%d.]+)$")
            if questId and markerType and x and y then
                local markerId = QuestMapMarkerEngine:CreateMarker(questId, markerType, x, y)
                print("Created marker: " .. markerId)
            else
                print("Usage: /questmarker create <questId> <type> <x> <y>")
            end
        elseif cmd == "remove" then
            if args ~= "" then
                local success = QuestMapMarkerEngine:RemoveMarker(args)
                print("Remove marker: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questmarker remove <markerId>")
            end
        elseif cmd == "clear" then
            local count = QuestMapMarkerEngine:ClearAllMarkers()
            print("Cleared " .. count .. " markers")
        elseif cmd == "list" then
            local stats = QuestMapMarkerEngine:GetMarkerStatistics()
            print("Marker Statistics:")
            print("  Total: " .. stats.total_markers)
            print("  Visible: " .. stats.visible_markers)
            print("  Groups: " .. stats.total_groups)
            for markerType, count in pairs(stats.by_type) do
                print("  " .. markerType .. ": " .. count)
            end
        elseif cmd == "status" then
            local status = QuestMapMarkerEngine:GetStatus()
            print("Quest Map Marker Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Markers: " .. status.total_markers .. "/" .. status.visible_markers)
            print("  Groups: " .. status.total_groups)
        else
            print("Quest Map Marker Commands:")
            print("  /questmarker create <questId> <type> <x> <y> - Create marker")
            print("  /questmarker remove <markerId> - Remove marker")
            print("  /questmarker clear - Clear all markers")
            print("  /questmarker list - List marker statistics")
            print("  /questmarker status - Show engine status")
        end
    end
end

return QuestMapMarkerEngine
