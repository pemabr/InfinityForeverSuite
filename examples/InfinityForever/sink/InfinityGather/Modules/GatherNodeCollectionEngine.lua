-- GatherNodeCollectionEngine.lua - Tracking collected nodes from gameplay
-- Part of InfinityGather addon suite
-- Records found nodes from actual player gathering

local GatherNodeCollectionEngine = {}
GatherNodeCollectionEngine.enabled = false
GatherNodeCollectionEngine.db = nil
GatherNodeCollectionEngine.collected_nodes = {}
GatherNodeCollectionEngine.collection_sessions = {}
GatherNodeCollectionEngine.last_collection_time = 0

-- Configuration
GatherNodeCollectionEngine.config = {
    enabled = true,
    max_collected = 10000,
    auto_merge_distance = 10,
}

function GatherNodeCollectionEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.collected_nodes then
        self.db.collected_nodes = {}
    end
    
    if not self.db.collection_sessions then
        self.db.collection_sessions = {}
    end
    
    self.collected_nodes = self.db.collected_nodes
    self.collection_sessions = self.db.collection_sessions
    self.enabled = true
    
    self:Log("Initialized node collection engine")
end

function GatherNodeCollectionEngine:RecordNodeFound(nodeId, nodeType, x, y, z, zone)
    if not nodeId or not nodeType then
        return false
    end
    
    -- Check size limit
    if #self.collected_nodes >= self.config.max_collected then
        return false
    end
    
    local collection = {
        node_id = nodeId,
        node_type = nodeType,
        x = x or 0,
        y = y or 0,
        z = z or 0,
        zone = zone or "Unknown",
        found_at = GetTime(),
        gathered = false,
        gathered_at = nil,
    }
    
    table.insert(self.collected_nodes, collection)
    
    self:Log("Recorded node found: " .. nodeId .. " (" .. nodeType .. ") at " .. zone)
    
    return true
end

function GatherNodeCollectionEngine:MarkNodeGathered(collectionIndex)
    if not collectionIndex or collectionIndex < 1 or collectionIndex > #self.collected_nodes then
        return false
    end
    
    local collection = self.collected_nodes[collectionIndex]
    collection.gathered = true
    collection.gathered_at = GetTime()
    
    self:Log("Marked node gathered: " .. collection.node_id)
    
    return true
end

function GatherNodeCollectionEngine:FindDuplicateNodes(maxDistance)
    maxDistance = maxDistance or self.config.auto_merge_distance
    local duplicates = {}
    
    for i = 1, #self.collected_nodes do
        for j = i + 1, #self.collected_nodes do
            local node1 = self.collected_nodes[i]
            local node2 = self.collected_nodes[j]
            
            if node1.node_type == node2.node_type and node1.zone == node2.zone then
                local distance = math.sqrt(
                    (node1.x - node2.x) ^ 2 +
                    (node1.y - node2.y) ^ 2 +
                    (node1.z - node2.z) ^ 2
                )
                
                if distance <= maxDistance then
                    table.insert(duplicates, {
                        index1 = i,
                        index2 = j,
                        distance = distance,
                    })
                end
            end
        end
    end
    
    self:Log("Found " .. #duplicates .. " potential duplicates")
    
    return duplicates
end

function GatherNodeCollectionEngine:MergeDuplicateNodes(index1, index2)
    if not index1 or not index2 then
        return false
    end
    
    if index1 < 1 or index1 > #self.collected_nodes or index2 < 1 or index2 > #self.collected_nodes then
        return false
    end
    
    local node1 = self.collected_nodes[index1]
    local node2 = self.collected_nodes[index2]
    
    -- Average the positions
    node1.x = (node1.x + node2.x) / 2
    node1.y = (node1.y + node2.y) / 2
    node1.z = (node1.z + node2.z) / 2
    
    -- Use earlier found time
    if node2.found_at < node1.found_at then
        node1.found_at = node2.found_at
    end
    
    -- Remove the second node
    table.remove(self.collected_nodes, index2)
    
    self:Log("Merged duplicate nodes")
    
    return true
end

function GatherNodeCollectionEngine:GetCollectionStats()
    local total = #self.collected_nodes
    local gathered = 0
    local ungathered = 0
    
    for _, collection in ipairs(self.collected_nodes) do
        if collection.gathered then
            gathered = gathered + 1
        else
            ungathered = ungathered + 1
        end
    end
    
    return {
        total_collected = total,
        gathered = gathered,
        ungathered = ungathered,
        gather_rate = total > 0 and (gathered / total * 100) or 0,
    }
end

function GatherNodeCollectionEngine:GetCollectionsByZone(zone)
    if not zone then
        return {}
    end
    
    local results = {}
    
    for _, collection in ipairs(self.collected_nodes) do
        if collection.zone == zone then
            table.insert(results, collection)
        end
    end
    
    return results
end

function GatherNodeCollectionEngine:GetCollectionsByType(nodeType)
    if not nodeType then
        return {}
    end
    
    local results = {}
    
    for _, collection in ipairs(self.collected_nodes) do
        if collection.node_type == nodeType then
            table.insert(results, collection)
        end
    end
    
    return results
end

function GatherNodeCollectionEngine:StartSession()
    local session = {
        start_time = GetTime(),
        end_time = nil,
        nodes_found = 0,
        nodes_gathered = 0,
    }
    
    table.insert(self.collection_sessions, session)
    
    self:Log("Started collection session")
    
    return session
end

function GatherNodeCollectionEngine:EndSession()
    if #self.collection_sessions == 0 then
        return false
    end
    
    local session = self.collection_sessions[#self.collection_sessions]
    session.end_time = GetTime()
    session.duration = session.end_time - session.start_time
    
    self:Log("Ended collection session - " .. session.nodes_gathered .. "/" .. session.nodes_found .. " gathered")
    
    return session
end

function GatherNodeCollectionEngine:IncrementSessionFind()
    if #self.collection_sessions == 0 then
        return false
    end
    
    local session = self.collection_sessions[#self.collection_sessions]
    session.nodes_found = session.nodes_found + 1
    
    return true
end

function GatherNodeCollectionEngine:IncrementSessionGather()
    if #self.collection_sessions == 0 then
        return false
    end
    
    local session = self.collection_sessions[#self.collection_sessions]
    session.nodes_gathered = session.nodes_gathered + 1
    
    return true
end

function GatherNodeCollectionEngine:ExportCollectionData(format)
    if not format then
        format = "json"
    end
    
    if format == "json" then
        local data = {
            total_nodes = #self.collected_nodes,
            nodes = self.collected_nodes,
            sessions = self.collection_sessions,
        }
        return data
    elseif format == "csv" then
        local csv = "NodeID,Type,Zone,X,Y,Z,Found,Gathered\n"
        for _, collection in ipairs(self.collected_nodes) do
            csv = csv .. collection.node_id .. "," .. collection.node_type .. "," .. collection.zone .. ","
            csv = csv .. collection.x .. "," .. collection.y .. "," .. collection.z .. ","
            csv = csv .. collection.found_at .. "," .. (collection.gathered_at or "") .. "\n"
        end
        return csv
    end
    
    return nil
end

function GatherNodeCollectionEngine:ClearOldCollections(maxAgeDays)
    if not maxAgeDays then
        return 0
    end
    
    local maxAgeSeconds = maxAgeDays * 86400
    local currentTime = GetTime()
    local removedCount = 0
    
    for i = #self.collected_nodes, 1, -1 do
        local collection = self.collected_nodes[i]
        if currentTime - collection.found_at > maxAgeSeconds then
            table.remove(self.collected_nodes, i)
            removedCount = removedCount + 1
        end
    end
    
    self:Log("Cleared " .. removedCount .. " old collections")
    
    return removedCount
end

function GatherNodeCollectionEngine:GetStatus()
    local stats = self:GetCollectionStats()
    
    return {
        enabled = self.enabled,
        total_collected = stats.total_collected,
        gathered = stats.gathered,
        ungathered = stats.ungathered,
        gather_rate = stats.gather_rate,
        sessions = #self.collection_sessions,
    }
end

function GatherNodeCollectionEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[GatherNodeCollectionEngine] " .. message)
    else
        print("[GatherNodeCollectionEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERCOLLECT1 = "/gathercollect"
    SlashCmdList["GATHERCOLLECT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            GatherNodeCollectionEngine:StartSession()
            print("Collection session started")
        elseif cmd == "end" then
            local session = GatherNodeCollectionEngine:EndSession()
            if session then
                print("Session ended - " .. session.nodes_gathered .. "/" .. session.nodes_found .. " gathered")
            end
        elseif cmd == "stats" then
            local stats = GatherNodeCollectionEngine:GetCollectionStats()
            print("Collection Statistics:")
            print("  Total: " .. stats.total_collected)
            print("  Gathered: " .. stats.gathered)
            print("  Ungathered: " .. stats.ungathered)
            print("  Rate: " .. string.format("%.1f", stats.gather_rate) .. "%")
        elseif cmd == "duplicates" then
            local dups = GatherNodeCollectionEngine:FindDuplicateNodes()
            print("Found " .. #dups .. " potential duplicates")
        elseif cmd == "cleanup" then
            local days = tonumber(args) or 30
            local removed = GatherNodeCollectionEngine:ClearOldCollections(days)
            print("Cleaned up " .. removed .. " collections older than " .. days .. " days")
        elseif cmd == "status" then
            local status = GatherNodeCollectionEngine:GetStatus()
            print("Collection Status:")
            print("  Collected: " .. status.total_collected)
            print("  Gathered: " .. status.gathered)
            print("  Sessions: " .. status.sessions)
        else
            print("Collection Commands:")
            print("  /gathercollect start - Start session")
            print("  /gathercollect end - End session")
            print("  /gathercollect stats - Show statistics")
            print("  /gathercollect duplicates - Find duplicates")
            print("  /gathercollect cleanup [days] - Remove old data")
            print("  /gathercollect status - Show status")
        end
    end
end

return GatherNodeCollectionEngine
