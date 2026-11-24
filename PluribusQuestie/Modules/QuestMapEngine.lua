-- QuestMapEngine.lua - World and minimap quest marker display
-- Part of PluribusQuestie addon suite
-- Renders quest and objective markers on maps

local QuestMapEngine = {}
QuestMapEngine.enabled = false
QuestMapEngine.db = nil
QuestMapEngine.markers = {}
QuestMapEngine.map_data = {}

-- Configuration
QuestMapEngine.config = {
    enabled = true,
    max_markers = 100,
    icon_quality = "high",  -- low, medium, high
    show_completed = false,
    show_inactive = false,
}

function QuestMapEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.markers then
        self.db.markers = {}
    end
    
    if not self.db.map_data then
        self.db.map_data = {}
    end
    
    self.markers = self.db.markers
    self.map_data = self.db.map_data
    self.enabled = true
    
    self:Log("Initialized quest map engine")
end

function QuestMapEngine:AddMarker(markerId, markerType, posX, posY, mapId, questId, iconColor)
    if not markerId or not markerType or not posX or not posY or not mapId then
        return false
    end
    
    if #self.markers >= self.config.max_markers then
        self:Log("Max markers reached (" .. self.config.max_markers .. ")")
        return false
    end
    
    local marker = {
        id = markerId,
        type = markerType,  -- quest_giver, quest_objective, quest_start, quest_end
        x = posX,
        y = posY,
        map_id = mapId,
        quest_id = questId,
        icon_color = iconColor or "yellow",  -- yellow, green, purple, red
        created_at = GetTime(),
        visible = true,
    }
    
    table.insert(self.markers, marker)
    self:Log("Added marker: " .. markerId .. " (" .. markerType .. ") at " .. mapId)
    
    return true
end

function QuestMapEngine:GetMarker(markerId)
    for _, marker in ipairs(self.markers) do
        if marker.id == markerId then
            return marker
        end
    end
    
    return nil
end

function QuestMapEngine:GetMarkersByQuest(questId)
    local results = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.quest_id == questId then
            table.insert(results, marker)
        end
    end
    
    return results
end

function QuestMapEngine:GetMarkersByMap(mapId)
    local results = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.map_id == mapId and marker.visible then
            table.insert(results, marker)
        end
    end
    
    return results
end

function QuestMapEngine:GetMarkersByType(markerType)
    local results = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.type == markerType then
            table.insert(results, marker)
        end
    end
    
    return results
end

function QuestMapEngine:SetMarkerVisibility(markerId, visible)
    local marker = self:GetMarker(markerId)
    if not marker then
        return false
    end
    
    marker.visible = visible
    
    return true
end

function QuestMapEngine:HideAllMarkersForQuest(questId)
    local markers = self:GetMarkersByQuest(questId)
    
    for _, marker in ipairs(markers) do
        marker.visible = false
    end
    
    return true
end

function QuestMapEngine:ShowAllMarkersForQuest(questId)
    local markers = self:GetMarkersByQuest(questId)
    
    for _, marker in ipairs(markers) do
        marker.visible = true
    end
    
    return true
end

function QuestMapEngine:GetMarkersByColor(iconColor)
    local results = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.icon_color == iconColor then
            table.insert(results, marker)
        end
    end
    
    return results
end

function QuestMapEngine:UpdateMarkerPosition(markerId, newX, newY)
    local marker = self:GetMarker(markerId)
    if not marker then
        return false
    end
    
    marker.x = newX
    marker.y = newY
    
    return true
end

function QuestMapEngine:GetNearestMarker(playerX, playerY, maxDistance)
    maxDistance = maxDistance or 100
    
    local nearest = nil
    local minDistance = maxDistance
    
    for _, marker in ipairs(self.markers) do
        if marker.visible then
            local dx = marker.x - playerX
            local dy = marker.y - playerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < minDistance then
                minDistance = distance
                nearest = marker
            end
        end
    end
    
    return nearest, minDistance
end

function QuestMapEngine:GetMarkersInRadius(centerX, centerY, radius)
    local results = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.visible then
            local dx = marker.x - centerX
            local dy = marker.y - centerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= radius then
                table.insert(results, {
                    marker = marker,
                    distance = distance,
                })
            end
        end
    end
    
    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)
    
    return results
end

function QuestMapEngine:DeleteMarker(markerId)
    for i, marker in ipairs(self.markers) do
        if marker.id == markerId then
            table.remove(self.markers, i)
            self:Log("Deleted marker: " .. markerId)
            return true
        end
    end
    
    return false
end

function QuestMapEngine:ClearMarkersForQuest(questId)
    local newMarkers = {}
    
    for _, marker in ipairs(self.markers) do
        if marker.quest_id ~= questId then
            table.insert(newMarkers, marker)
        end
    end
    
    self.markers = newMarkers
    self.db.markers = newMarkers
    
    self:Log("Cleared markers for quest: " .. questId)
end

function QuestMapEngine:GetMarkerCount()
    return #self.markers
end

function QuestMapEngine:GetMarkerCountByMap(mapId)
    local count = 0
    
    for _, marker in ipairs(self.markers) do
        if marker.map_id == mapId and marker.visible then
            count = count + 1
        end
    end
    
    return count
end

function QuestMapEngine:GetStatus()
    local mapCounts = {}
    
    for _, marker in ipairs(self.markers) do
        if not mapCounts[marker.map_id] then
            mapCounts[marker.map_id] = 0
        end
        mapCounts[marker.map_id] = mapCounts[marker.map_id] + 1
    end
    
    return {
        enabled = self.enabled,
        total_markers = #self.markers,
        max_markers = self.config.max_markers,
        maps_with_markers = table.getn(mapCounts),
    }
end

function QuestMapEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestMapEngine] " .. message)
    else
        print("[QuestMapEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTMAP1 = "/questmap"
    SlashCmdList["QUESTMAP"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "show" then
            local mapId = tonumber(args)
            if mapId then
                local markers = QuestMapEngine:GetMarkersByMap(mapId)
                print("Quest Markers on Map " .. mapId .. ": " .. #markers)
                for i, marker in ipairs(markers) do
                    print("  [" .. i .. "] " .. marker.type .. " (" .. marker.icon_color .. ")")
                    print("       Pos: " .. string.format("%.1f, %.1f", marker.x, marker.y))
                end
            else
                print("Usage: /questmap show <mapId>")
            end
        elseif cmd == "quest" then
            local questId = tonumber(args)
            if questId then
                local markers = QuestMapEngine:GetMarkersByQuest(questId)
                print("Markers for Quest " .. questId .. ": " .. #markers)
                for i, marker in ipairs(markers) do
                    print("  [" .. i .. "] " .. marker.type .. " on map " .. marker.map_id)
                end
            else
                print("Usage: /questmap quest <questId>")
            end
        elseif cmd == "hide" then
            local questId = tonumber(args)
            if questId then
                QuestMapEngine:HideAllMarkersForQuest(questId)
                print("Hidden all markers for quest: " .. questId)
            end
        elseif cmd == "show" then
            local questId = tonumber(args)
            if questId then
                QuestMapEngine:ShowAllMarkersForQuest(questId)
                print("Showed all markers for quest: " .. questId)
            end
        elseif cmd == "status" then
            local status = QuestMapEngine:GetStatus()
            print("Quest Map:")
            print("  Total Markers: " .. status.total_markers .. "/" .. status.max_markers)
            print("  Maps with Markers: " .. status.maps_with_markers)
        else
            print("Quest Map Commands:")
            print("  /questmap show <mapId> - Show markers on map")
            print("  /questmap quest <questId> - Show markers for quest")
            print("  /questmap hide <questId> - Hide quest markers")
            print("  /questmap show <questId> - Show quest markers")
            print("  /questmap status - Show system status")
        end
    end
end

return QuestMapEngine
