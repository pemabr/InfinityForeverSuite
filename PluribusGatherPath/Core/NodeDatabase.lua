-- Node Database
-- Gathering node tracking and storage

local PluribusNodeDB = {}
_G.PluribusNodeDB = PluribusNodeDB

PluribusNodeDB.nodes = {}
PluribusNodeDB.callbacks = {}

function PluribusNodeDB:RecordNode(nodeType, x, y, zone, respawnTime)
    local nodeID = string.format("%s_%d_%d_%s", nodeType, x, y, zone)
    
    if self.nodes[nodeID] then
        self.nodes[nodeID].last_seen = GetTime()
        return false -- Node already recorded
    end
    
    self.nodes[nodeID] = {
        id = nodeID,
        type = nodeType,
        x = x,
        y = y,
        zone = zone,
        first_seen = GetTime(),
        last_seen = GetTime(),
        respawn_time = respawnTime or 300,
        harvest_count = 0,
    }
    
    self:TriggerCallback("node_recorded", nodeType, zone)
    return true
end

function PluribusNodeDB:GetNodes(zone, nodeType)
    local result = {}
    
    for nodeID, node in pairs(self.nodes) do
        if (not zone or node.zone == zone) and 
           (not nodeType or node.type == nodeType) then
            table.insert(result, node)
        end
    end
    
    return result
end

function PluribusNodeDB:GetNodesByType(nodeType)
    local result = {}
    
    for nodeID, node in pairs(self.nodes) do
        if node.type == nodeType then
            table.insert(result, node)
        end
    end
    
    return result
end

function PluribusNodeDB:GetNodesByZone(zone)
    local result = {}
    
    for nodeID, node in pairs(self.nodes) do
        if node.zone == zone then
            table.insert(result, node)
        end
    end
    
    return result
end

function PluribusNodeDB:GetNodeCount()
    local count = 0
    for _ in pairs(self.nodes) do
        count = count + 1
    end
    return count
end

function PluribusNodeDB:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusNodeDB:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusNodeDB:Export()
    local data = {}
    for nodeID, node in pairs(self.nodes) do
        table.insert(data, node)
    end
    return data
end

return PluribusNodeDB
