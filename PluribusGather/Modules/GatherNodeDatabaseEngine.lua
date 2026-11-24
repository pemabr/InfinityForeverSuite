-- GatherNodeDatabaseEngine.lua - Gathering node database and storage
-- Part of PluribusGather addon suite
-- Provides storage, retrieval, and management of herb, ore, treasure, and fishing nodes

local GatherNodeDatabaseEngine = {}
GatherNodeDatabaseEngine.enabled = false
GatherNodeDatabaseEngine.db = nil
GatherNodeDatabaseEngine.nodes = {}
GatherNodeDatabaseEngine.node_types = {}
GatherNodeDatabaseEngine.nodes_by_zone = {}

-- Node types
GatherNodeDatabaseEngine.NODE_TYPES = {
    HERB = "herb",
    ORE = "ore",
    TREASURE = "treasure",
    FISHING = "fishing",
    SKINNING = "skinning",
    DISENCHANT = "disenchant",
}

-- Configuration
GatherNodeDatabaseEngine.config = {
    enabled = true,
    max_nodes = 50000,
    enable_persistence = true,
}

function GatherNodeDatabaseEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.nodes then
        self.db.nodes = {}
    end
    
    if not self.db.nodes_by_zone then
        self.db.nodes_by_zone = {}
    end
    
    self.nodes = self.db.nodes
    self.nodes_by_zone = self.db.nodes_by_zone
    self.enabled = true
    
    self:Log("Initialized gather node database engine")
end

function GatherNodeDatabaseEngine:AddNode(nodeData)
    if not nodeData or not nodeData.id or not nodeData.type then
        return false
    end
    
    -- Check size limit
    if #self.nodes >= self.config.max_nodes then
        return false
    end
    
    local node = {
        id = nodeData.id,
        type = nodeData.type,
        name = nodeData.name or "Unknown Node",
        x = nodeData.x or 0,
        y = nodeData.y or 0,
        z = nodeData.z or 0,
        zone = nodeData.zone or "Unknown",
        level_req = nodeData.level_req or 1,
        respawn_time = nodeData.respawn_time or 0,
        last_seen = GetTime(),
        accuracy = nodeData.accuracy or 100,
        rarities = nodeData.rarities or {},
    }
    
    self.nodes[nodeData.id] = node
    
    -- Index by zone
    if not self.nodes_by_zone[node.zone] then
        self.nodes_by_zone[node.zone] = {}
    end
    
    table.insert(self.nodes_by_zone[node.zone], nodeData.id)
    
    self:Log("Added node: " .. nodeData.id .. " (" .. nodeData.type .. ")")
    
    return true
end

function GatherNodeDatabaseEngine:GetNode(nodeId)
    if not nodeId or not self.nodes[nodeId] then
        return nil
    end
    
    return self.nodes[nodeId]
end

function GatherNodeDatabaseEngine:UpdateNodeLocation(nodeId, x, y, z)
    if not nodeId or not self.nodes[nodeId] then
        return false
    end
    
    self.nodes[nodeId].x = x or self.nodes[nodeId].x
    self.nodes[nodeId].y = y or self.nodes[nodeId].y
    self.nodes[nodeId].z = z or self.nodes[nodeId].z
    
    self:Log("Updated node location: " .. nodeId)
    
    return true
end

function GatherNodeDatabaseEngine:UpdateNodeAccuracy(nodeId, accuracy)
    if not nodeId or not self.nodes[nodeId] or not accuracy then
        return false
    end
    
    if accuracy < 0 or accuracy > 100 then
        return false
    end
    
    self.nodes[nodeId].accuracy = accuracy
    self:Log("Updated node accuracy: " .. nodeId .. " = " .. accuracy)
    
    return true
end

function GatherNodeDatabaseEngine:RecordNodeSighting(nodeId)
    if not nodeId or not self.nodes[nodeId] then
        return false
    end
    
    self.nodes[nodeId].last_seen = GetTime()
    
    self:Log("Recorded node sighting: " .. nodeId)
    
    return true
end

function GatherNodeDatabaseEngine:GetNodesByZone(zone)
    if not zone or not self.nodes_by_zone[zone] then
        return {}
    end
    
    local zoneNodes = {}
    
    for _, nodeId in ipairs(self.nodes_by_zone[zone]) do
        if self.nodes[nodeId] then
            table.insert(zoneNodes, self.nodes[nodeId])
        end
    end
    
    return zoneNodes
end

function GatherNodeDatabaseEngine:GetNodesByType(nodeType)
    if not nodeType then
        return {}
    end
    
    local typeNodes = {}
    
    for _, node in pairs(self.nodes) do
        if node.type == nodeType then
            table.insert(typeNodes, node)
        end
    end
    
    return typeNodes
end

function GatherNodeDatabaseEngine:GetNodesByZoneAndType(zone, nodeType)
    if not zone or not nodeType then
        return {}
    end
    
    local results = {}
    
    for _, node in pairs(self:GetNodesByZone(zone)) do
        if node.type == nodeType then
            table.insert(results, node)
        end
    end
    
    return results
end

function GatherNodeDatabaseEngine:FilterNodesByDistance(centerX, centerY, centerZ, maxDistance)
    if not centerX or not centerY or not maxDistance then
        return {}
    end
    
    local results = {}
    
    for _, node in pairs(self.nodes) do
        local distance = math.sqrt(
            (node.x - centerX) ^ 2 +
            (node.y - centerY) ^ 2 +
            (node.z - centerZ) ^ 2
        )
        
        if distance <= maxDistance then
            table.insert(results, {
                node = node,
                distance = distance,
            })
        end
    end
    
    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)
    
    return results
end

function GatherNodeDatabaseEngine:FilterNodesByLevel(minLevel, maxLevel)
    if not minLevel then
        return {}
    end
    
    maxLevel = maxLevel or minLevel
    local results = {}
    
    for _, node in pairs(self.nodes) do
        if node.level_req >= minLevel and node.level_req <= maxLevel then
            table.insert(results, node)
        end
    end
    
    return results
end

function GatherNodeDatabaseEngine:DeleteNode(nodeId)
    if not nodeId or not self.nodes[nodeId] then
        return false
    end
    
    local zone = self.nodes[nodeId].zone
    
    self.nodes[nodeId] = nil
    
    -- Remove from zone index
    if self.nodes_by_zone[zone] then
        for i, id in ipairs(self.nodes_by_zone[zone]) do
            if id == nodeId then
                table.remove(self.nodes_by_zone[zone], i)
                break
            end
        end
    end
    
    self:Log("Deleted node: " .. nodeId)
    
    return true
end

function GatherNodeDatabaseEngine:GetNodeCount()
    local count = 0
    
    for _ in pairs(self.nodes) do
        count = count + 1
    end
    
    return count
end

function GatherNodeDatabaseEngine:GetNodeCountByType()
    local counts = {}
    
    for _, node in pairs(self.nodes) do
        if not counts[node.type] then
            counts[node.type] = 0
        end
        counts[node.type] = counts[node.type] + 1
    end
    
    return counts
end

function GatherNodeDatabaseEngine:GetNodeCountByZone()
    local counts = {}
    
    for zone, nodeIds in pairs(self.nodes_by_zone) do
        counts[zone] = #nodeIds
    end
    
    return counts
end

function GatherNodeDatabaseEngine:CleanupStaleNodes(maxAgeDays)
    if not maxAgeDays then
        return 0
    end
    
    local maxAgeSeconds = maxAgeDays * 86400
    local currentTime = GetTime()
    local removedCount = 0
    
    for nodeId, node in pairs(self.nodes) do
        if currentTime - node.last_seen > maxAgeSeconds then
            self:DeleteNode(nodeId)
            removedCount = removedCount + 1
        end
    end
    
    self:Log("Cleaned up " .. removedCount .. " stale nodes")
    
    return removedCount
end

function GatherNodeDatabaseEngine:GetStatus()
    local counts = self:GetNodeCountByType()
    
    return {
        enabled = self.enabled,
        total_nodes = self:GetNodeCount(),
        herb_nodes = counts[self.NODE_TYPES.HERB] or 0,
        ore_nodes = counts[self.NODE_TYPES.ORE] or 0,
        treasure_nodes = counts[self.NODE_TYPES.TREASURE] or 0,
        fishing_nodes = counts[self.NODE_TYPES.FISHING] or 0,
    }
end

function GatherNodeDatabaseEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherNodeDatabaseEngine] " .. message)
    else
        print("[GatherNodeDatabaseEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERDB1 = "/gatherdb"
    SlashCmdList["GATHERDB"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "status" then
            local status = GatherNodeDatabaseEngine:GetStatus()
            print("Gathering Node Database Status:")
            print("  Total Nodes: " .. status.total_nodes)
            print("  Herbs: " .. status.herb_nodes)
            print("  Ore: " .. status.ore_nodes)
            print("  Treasure: " .. status.treasure_nodes)
            print("  Fishing: " .. status.fishing_nodes)
        elseif cmd == "zone" then
            if args ~= "" then
                local nodes = GatherNodeDatabaseEngine:GetNodesByZone(args)
                print("Nodes in " .. args .. ": " .. #nodes)
            else
                print("Usage: /gatherdb zone <zonename>")
            end
        elseif cmd == "cleanup" then
            local days = tonumber(args) or 7
            local removed = GatherNodeDatabaseEngine:CleanupStaleNodes(days)
            print("Cleaned up " .. removed .. " stale nodes (older than " .. days .. " days)")
        elseif cmd == "counts" then
            local counts = GatherNodeDatabaseEngine:GetNodeCountByType()
            print("Nodes by Type:")
            for type, count in pairs(counts) do
                print("  " .. type .. ": " .. count)
            end
        else
            print("Gather Database Commands:")
            print("  /gatherdb status - Show database status")
            print("  /gatherdb zone <name> - Nodes in zone")
            print("  /gatherdb cleanup [days] - Remove old nodes")
            print("  /gatherdb counts - Nodes by type")
        end
    end
end

return GatherNodeDatabaseEngine
