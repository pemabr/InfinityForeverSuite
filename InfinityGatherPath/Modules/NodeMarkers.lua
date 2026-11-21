-- Node Markers Module
-- Display node markers on world/minimap

local InfinityNodeMarkers = {}
_G.InfinityNodeMarkers = InfinityNodeMarkers

InfinityNodeMarkers.markers = {}

function InfinityNodeMarkers:CreateMarker(nodeID, x, y, zone, nodeType)
    self.markers[nodeID] = {
        id = nodeID,
        x = x,
        y = y,
        zone = zone,
        type = nodeType,
        visible = true,
    }
end

function InfinityNodeMarkers:ShowMarkers(zone, nodeType)
    local shown = 0
    
    for nodeID, marker in pairs(self.markers) do
        if (not zone or marker.zone == zone) and
           (not nodeType or marker.type == nodeType) then
            marker.visible = true
            shown = shown + 1
        end
    end
    
    return shown
end

function InfinityNodeMarkers:HideMarkers()
    for nodeID, marker in pairs(self.markers) do
        marker.visible = false
    end
end

function InfinityNodeMarkers:RemoveMarker(nodeID)
    self.markers[nodeID] = nil
end

function InfinityNodeMarkers:GetVisibleMarkers()
    local visible = {}
    
    for nodeID, marker in pairs(self.markers) do
        if marker.visible then
            table.insert(visible, marker)
        end
    end
    
    return visible
end

function InfinityNodeMarkers:ClearMarkers()
    self.markers = {}
end

return InfinityNodeMarkers
