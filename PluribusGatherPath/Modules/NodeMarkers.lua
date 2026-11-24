-- Node Markers Module
-- Display node markers on world/minimap

local PluribusNodeMarkers = {}
_G.PluribusNodeMarkers = PluribusNodeMarkers

PluribusNodeMarkers.markers = {}

function PluribusNodeMarkers:CreateMarker(nodeID, x, y, zone, nodeType)
    self.markers[nodeID] = {
        id = nodeID,
        x = x,
        y = y,
        zone = zone,
        type = nodeType,
        visible = true,
    }
end

function PluribusNodeMarkers:ShowMarkers(zone, nodeType)
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

function PluribusNodeMarkers:HideMarkers()
    for nodeID, marker in pairs(self.markers) do
        marker.visible = false
    end
end

function PluribusNodeMarkers:RemoveMarker(nodeID)
    self.markers[nodeID] = nil
end

function PluribusNodeMarkers:GetVisibleMarkers()
    local visible = {}
    
    for nodeID, marker in pairs(self.markers) do
        if marker.visible then
            table.insert(visible, marker)
        end
    end
    
    return visible
end

function PluribusNodeMarkers:ClearMarkers()
    self.markers = {}
end

return PluribusNodeMarkers
