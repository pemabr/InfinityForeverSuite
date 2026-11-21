-- GatherMate2IntegrationEngine.lua - Load data from GatherMate2 addon
-- Part of InfinityGather addon suite
-- Imports herb/ore/treasure/fishing node data from GatherMate2 storage modules

local GatherMate2IntegrationEngine = {}
GatherMate2IntegrationEngine.enabled = false
GatherMate2IntegrationEngine.loaded_sources = {}

-- Configuration
GatherMate2IntegrationEngine.config = {
    enabled = true,
    auto_import_on_load = true,
}

function GatherMate2IntegrationEngine:Initialize()
    self.enabled = true
    self:Log("Initialized GatherMate2 integration engine")
    
    if self.config.auto_import_on_load then
        self:LoadAllGatherMate2Data()
    end
end

function GatherMate2IntegrationEngine:LoadAllGatherMate2Data()
    local imported = 0
    
    imported = imported + self:LoadDragonflightData()
    imported = imported + self:LoadMidnightData()
    imported = imported + self:LoadTheWarWithinData()
    imported = imported + self:LoadCoreGatherMate2Data()
    
    self:Log("Loaded total " .. imported .. " nodes from GatherMate2 sources")
    
    return imported
end

function GatherMate2IntegrationEngine:LoadDragonflightData()
    if not GatherMate2Storage_Dragonflight then
        self:Log("GatherMate2Storage_Dragonflight not found")
        return 0
    end
    
    local dragonflightDB = GatherMate2Storage_Dragonflight
    local imported = 0
    
    -- Parse herb nodes
    if dragonflightDB.Herbs then
        for zone, nodes in pairs(dragonflightDB.Herbs) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "herb", zone, "Dragonflight")
                imported = imported + 1
            end
        end
    end
    
    -- Parse ore nodes
    if dragonflightDB.Ore then
        for zone, nodes in pairs(dragonflightDB.Ore) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "ore", zone, "Dragonflight")
                imported = imported + 1
            end
        end
    end
    
    -- Parse treasure nodes
    if dragonflightDB.Treasures then
        for zone, nodes in pairs(dragonflightDB.Treasures) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "treasure", zone, "Dragonflight")
                imported = imported + 1
            end
        end
    end
    
    -- Parse fishing nodes
    if dragonflightDB.Fishing then
        for zone, nodes in pairs(dragonflightDB.Fishing) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "fishing", zone, "Dragonflight")
                imported = imported + 1
            end
        end
    end
    
    table.insert(self.loaded_sources, {
        name = "GatherMate2Storage_Dragonflight",
        nodes = imported,
        expansion = "Dragonflight",
    })
    
    self:Log("Loaded " .. imported .. " nodes from Dragonflight")
    
    return imported
end

function GatherMate2IntegrationEngine:LoadMidnightData()
    if not GatherMate2Storage_Midnight then
        self:Log("GatherMate2Storage_Midnight not found")
        return 0
    end
    
    local midnightDB = GatherMate2Storage_Midnight
    local imported = 0
    
    -- Parse herb nodes
    if midnightDB.Herbs then
        for zone, nodes in pairs(midnightDB.Herbs) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "herb", zone, "Midnight")
                imported = imported + 1
            end
        end
    end
    
    -- Parse ore nodes
    if midnightDB.Ore then
        for zone, nodes in pairs(midnightDB.Ore) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "ore", zone, "Midnight")
                imported = imported + 1
            end
        end
    end
    
    -- Parse fishing nodes
    if midnightDB.Fishing then
        for zone, nodes in pairs(midnightDB.Fishing) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "fishing", zone, "Midnight")
                imported = imported + 1
            end
        end
    end
    
    table.insert(self.loaded_sources, {
        name = "GatherMate2Storage_Midnight",
        nodes = imported,
        expansion = "Midnight",
    })
    
    self:Log("Loaded " .. imported .. " nodes from Midnight")
    
    return imported
end

function GatherMate2IntegrationEngine:LoadTheWarWithinData()
    if not GatherMate2Storage_TheWarWithin then
        self:Log("GatherMate2Storage_TheWarWithin not found")
        return 0
    end
    
    local theWarWithinDB = GatherMate2Storage_TheWarWithin
    local imported = 0
    
    -- Parse herb nodes
    if theWarWithinDB.Herbs then
        for zone, nodes in pairs(theWarWithinDB.Herbs) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "herb", zone, "TheWarWithin")
                imported = imported + 1
            end
        end
    end
    
    -- Parse ore nodes
    if theWarWithinDB.Ore then
        for zone, nodes in pairs(theWarWithinDB.Ore) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "ore", zone, "TheWarWithin")
                imported = imported + 1
            end
        end
    end
    
    -- Parse fishing nodes
    if theWarWithinDB.Fishing then
        for zone, nodes in pairs(theWarWithinDB.Fishing) do
            for nodeID, nodeData in pairs(nodes) do
                self:_ImportNode(nodeData, "fishing", zone, "TheWarWithin")
                imported = imported + 1
            end
        end
    end
    
    table.insert(self.loaded_sources, {
        name = "GatherMate2Storage_TheWarWithin",
        nodes = imported,
        expansion = "TheWarWithin",
    })
    
    self:Log("Loaded " .. imported .. " nodes from The War Within")
    
    return imported
end

function GatherMate2IntegrationEngine:LoadCoreGatherMate2Data()
    if not GatherMate2_Data then
        self:Log("GatherMate2_Data not found")
        return 0
    end
    
    local coreDB = GatherMate2_Data
    local imported = 0
    
    -- Parse all data types from core
    local dataTypes = {"Herbs", "Ore", "Treasures", "Fishing", "Gas", "Archaeology"}
    
    for _, dataType in ipairs(dataTypes) do
        if coreDB[dataType] then
            for zone, nodes in pairs(coreDB[dataType]) do
                for nodeID, nodeData in pairs(nodes) do
                    local nodeType = dataType:lower()
                    if nodeType == "treasures" then
                        nodeType = "treasure"
                    elseif nodeType == "archaeology" then
                        nodeType = "disenchant"
                    elseif nodeType == "gas" then
                        nodeType = "ore"
                    end
                    
                    self:_ImportNode(nodeData, nodeType, zone, "Core")
                    imported = imported + 1
                end
            end
        end
    end
    
    table.insert(self.loaded_sources, {
        name = "GatherMate2_Data",
        nodes = imported,
        expansion = "Core",
    })
    
    self:Log("Loaded " .. imported .. " nodes from core GatherMate2")
    
    return imported
end

function GatherMate2IntegrationEngine:_ImportNode(nodeData, nodeType, zone, expansion)
    if not InfinityCore then
        return
    end
    
    local db = InfinityCore:GetDatabase("InfinityGather")
    if not db then
        db = {}
    end
    
    if not db.nodes_snapshot then
        db.nodes_snapshot = {}
    end
    
    -- Parse GatherMate2 node format: typically {id, x, y, z, name, ...}
    local x = 0
    local y = 0
    local z = 0
    local name = "Unknown"
    
    if type(nodeData) == "table" then
        x = nodeData[1] or 0
        y = nodeData[2] or 0
        z = nodeData[3] or 0
        name = nodeData[5] or ("Node_" .. nodeType)
    end
    
    -- Create unique ID
    local nodeID = zone .. "_" .. nodeType .. "_" .. x .. "_" .. y
    
    -- Check if node already exists
    if db.nodes_snapshot[nodeID] then
        return
    end
    
    -- Add node to database
    db.nodes_snapshot[nodeID] = {
        id = nodeID,
        type = nodeType,
        name = name,
        x = x,
        y = y,
        z = z,
        zone = zone,
        level_req = 1,
        last_seen = GetTime(),
        accuracy = 85,
        source = "GatherMate2",
        expansion = expansion,
    }
end

function GatherMate2IntegrationEngine:GetLoadedSources()
    return self.loaded_sources
end

function GatherMate2IntegrationEngine:GetStatus()
    local totalNodes = 0
    
    for _, source in ipairs(self.loaded_sources) do
        totalNodes = totalNodes + source.nodes
    end
    
    return {
        enabled = self.enabled,
        sources_loaded = #self.loaded_sources,
        total_nodes = totalNodes,
    }
end

function GatherMate2IntegrationEngine:PrintLoadedSources()
    self:Log("Loaded sources:")
    for _, source in ipairs(self.loaded_sources) do
        self:Log("  " .. source.name .. " (" .. source.expansion .. "): " .. source.nodes .. " nodes")
    end
end

function GatherMate2IntegrationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[GatherMate2IntegrationEngine] " .. message)
    else
        print("[GatherMate2IntegrationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERIMATE1 = "/gatherimate"
    SlashCmdList["GATHERIMATE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "load" then
            local imported = GatherMate2IntegrationEngine:LoadAllGatherMate2Data()
            print("Loaded " .. imported .. " nodes from GatherMate2")
        elseif cmd == "sources" then
            GatherMate2IntegrationEngine:PrintLoadedSources()
        elseif cmd == "status" then
            local status = GatherMate2IntegrationEngine:GetStatus()
            print("GatherMate2 Integration Status:")
            print("  Sources: " .. status.sources_loaded)
            print("  Total nodes: " .. status.total_nodes)
        else
            print("GatherMate2 Integration Commands:")
            print("  /gatherimate load - Load all GatherMate2 data")
            print("  /gatherimate sources - List loaded sources")
            print("  /gatherimate status - Show status")
        end
    end
end

return GatherMate2IntegrationEngine
