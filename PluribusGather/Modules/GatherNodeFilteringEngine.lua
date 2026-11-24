-- GatherNodeFilteringEngine.lua - Node filtering and query system
-- Part of PluribusGather addon suite
-- Provides advanced filtering for gathering nodes

local GatherNodeFilteringEngine = {}
GatherNodeFilteringEngine.enabled = false
GatherNodeFilteringEngine.db = nil
GatherNodeFilteringEngine.saved_filters = {}
GatherNodeFilteringEngine.filter_presets = {}

-- Configuration
GatherNodeFilteringEngine.config = {
    enabled = true,
    max_filters = 50,
}

function GatherNodeFilteringEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.saved_filters then
        self.db.saved_filters = {}
    end
    
    if not self.db.filter_presets then
        self.db.filter_presets = {}
    end
    
    self.saved_filters = self.db.saved_filters
    self.filter_presets = self.db.filter_presets
    self.enabled = true
    
    self:Log("Initialized node filtering engine")
end

function GatherNodeFilteringEngine:CreateFilter(filterName)
    if not filterName then
        return nil
    end
    
    local filter = {
        name = filterName,
        node_type = nil,
        zone = nil,
        min_level = nil,
        max_level = nil,
        min_distance = nil,
        max_distance = nil,
        accuracy_min = 0,
        status = "active",
        created_at = GetTime(),
    }
    
    self.saved_filters[filterName] = filter
    self:Log("Created filter: " .. filterName)
    
    return filter
end

function GatherNodeFilteringEngine:SetFilterNodeType(filterName, nodeType)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    self.saved_filters[filterName].node_type = nodeType
    self:Log("Set filter node type: " .. filterName .. " = " .. (nodeType or "none"))
    
    return true
end

function GatherNodeFilteringEngine:SetFilterZone(filterName, zone)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    self.saved_filters[filterName].zone = zone
    self:Log("Set filter zone: " .. filterName .. " = " .. (zone or "none"))
    
    return true
end

function GatherNodeFilteringEngine:SetFilterLevelRange(filterName, minLevel, maxLevel)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    self.saved_filters[filterName].min_level = minLevel
    self.saved_filters[filterName].max_level = maxLevel or minLevel
    self:Log("Set filter level range: " .. filterName .. " = " .. (minLevel or "any"))
    
    return true
end

function GatherNodeFilteringEngine:SetFilterDistanceRange(filterName, minDistance, maxDistance)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    self.saved_filters[filterName].min_distance = minDistance
    self.saved_filters[filterName].max_distance = maxDistance
    self:Log("Set filter distance: " .. filterName)
    
    return true
end

function GatherNodeFilteringEngine:SetFilterAccuracyMin(filterName, minAccuracy)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    if minAccuracy < 0 or minAccuracy > 100 then
        return false
    end
    
    self.saved_filters[filterName].accuracy_min = minAccuracy
    self:Log("Set filter accuracy min: " .. filterName .. " = " .. minAccuracy)
    
    return true
end

function GatherNodeFilteringEngine:ApplyFilter(filterName, nodes)
    if not filterName or not self.saved_filters[filterName] or not nodes then
        return {}
    end
    
    local filter = self.saved_filters[filterName]
    local results = {}
    
    for _, node in ipairs(nodes) do
        local passed = true
        
        -- Type filter
        if filter.node_type and node.type ~= filter.node_type then
            passed = false
        end
        
        -- Zone filter
        if filter.zone and node.zone ~= filter.zone then
            passed = false
        end
        
        -- Level filter
        if filter.min_level and node.level_req < filter.min_level then
            passed = false
        end
        
        if filter.max_level and node.level_req > filter.max_level then
            passed = false
        end
        
        -- Accuracy filter
        if node.accuracy < filter.accuracy_min then
            passed = false
        end
        
        if passed then
            table.insert(results, node)
        end
    end
    
    self:Log("Applied filter: " .. filterName .. " - " .. #results .. " results")
    
    return results
end

function GatherNodeFilteringEngine:SaveFilterAsPreset(filterName, presetName)
    if not filterName or not self.saved_filters[filterName] or not presetName then
        return false
    end
    
    local filterData = {}
    for k, v in pairs(self.saved_filters[filterName]) do
        filterData[k] = v
    end
    
    self.filter_presets[presetName] = filterData
    self:Log("Saved filter as preset: " .. presetName)
    
    return true
end

function GatherNodeFilteringEngine:LoadFilterFromPreset(presetName, filterName)
    if not presetName or not self.filter_presets[presetName] or not filterName then
        return false
    end
    
    local presetData = {}
    for k, v in pairs(self.filter_presets[presetName]) do
        presetData[k] = v
    end
    
    presetData.name = filterName
    self.saved_filters[filterName] = presetData
    self:Log("Loaded preset to filter: " .. filterName)
    
    return true
end

function GatherNodeFilteringEngine:GetFilter(filterName)
    if not filterName or not self.saved_filters[filterName] then
        return nil
    end
    
    return self.saved_filters[filterName]
end

function GatherNodeFilteringEngine:DeleteFilter(filterName)
    if not filterName or not self.saved_filters[filterName] then
        return false
    end
    
    self.saved_filters[filterName] = nil
    self:Log("Deleted filter: " .. filterName)
    
    return true
end

function GatherNodeFilteringEngine:ListFilters()
    local filters = {}
    
    for filterName in pairs(self.saved_filters) do
        table.insert(filters, filterName)
    end
    
    return filters
end

function GatherNodeFilteringEngine:ListPresets()
    local presets = {}
    
    for presetName in pairs(self.filter_presets) do
        table.insert(presets, presetName)
    end
    
    return presets
end

function GatherNodeFilteringEngine:DuplicateFilter(sourceFilterName, newFilterName)
    if not sourceFilterName or not self.saved_filters[sourceFilterName] or not newFilterName then
        return false
    end
    
    local sourceFilter = self.saved_filters[sourceFilterName]
    local newFilter = {}
    
    for k, v in pairs(sourceFilter) do
        newFilter[k] = v
    end
    
    newFilter.name = newFilterName
    self.saved_filters[newFilterName] = newFilter
    self:Log("Duplicated filter: " .. sourceFilterName .. " -> " .. newFilterName)
    
    return true
end

function GatherNodeFilteringEngine:GetFilterSummary(filterName)
    if not filterName or not self.saved_filters[filterName] then
        return nil
    end
    
    local filter = self.saved_filters[filterName]
    local summary = "Filter: " .. filterName
    
    if filter.node_type then
        summary = summary .. " | Type: " .. filter.node_type
    end
    
    if filter.zone then
        summary = summary .. " | Zone: " .. filter.zone
    end
    
    if filter.min_level then
        summary = summary .. " | Level: " .. filter.min_level
        if filter.max_level and filter.max_level ~= filter.min_level then
            summary = summary .. "-" .. filter.max_level
        end
    end
    
    return summary
end

function GatherNodeFilteringEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_filters = next(self.saved_filters) and 1 or 0,
        total_presets = next(self.filter_presets) and 1 or 0,
    }
end

function GatherNodeFilteringEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherNodeFilteringEngine] " .. message)
    else
        print("[GatherNodeFilteringEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERFILTER1 = "/gatherfilter"
    SlashCmdList["GATHERFILTER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            if args ~= "" then
                GatherNodeFilteringEngine:CreateFilter(args)
                print("Filter created: " .. args)
            else
                print("Usage: /gatherfilter create <name>")
            end
        elseif cmd == "list" then
            local filters = GatherNodeFilteringEngine:ListFilters()
            print("Filters (" .. #filters .. "):")
            for _, name in ipairs(filters) do
                print("  " .. name)
            end
        elseif cmd == "delete" then
            if args ~= "" then
                local success = GatherNodeFilteringEngine:DeleteFilter(args)
                print("Delete: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /gatherfilter delete <name>")
            end
        elseif cmd == "presets" then
            local presets = GatherNodeFilteringEngine:ListPresets()
            print("Presets (" .. #presets .. "):")
            for _, name in ipairs(presets) do
                print("  " .. name)
            end
        elseif cmd == "status" then
            local status = GatherNodeFilteringEngine:GetStatus()
            print("Node Filtering Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Filters: " .. status.total_filters)
            print("  Presets: " .. status.total_presets)
        else
            print("Node Filtering Commands:")
            print("  /gatherfilter create <name> - Create filter")
            print("  /gatherfilter delete <name> - Delete filter")
            print("  /gatherfilter list - List all filters")
            print("  /gatherfilter presets - List presets")
            print("  /gatherfilter status - Show status")
        end
    end
end

return GatherNodeFilteringEngine
