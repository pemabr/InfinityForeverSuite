-- QuestFilterUIEngine.lua - Quest filter control UI system
-- Part of InfinityQuestie addon suite
-- Provides UI controls for filtering quests by various criteria

local QuestFilterUIEngine = {}
QuestFilterUIEngine.enabled = false
QuestFilterUIEngine.db = nil
QuestFilterUIEngine.active_filters = {}
QuestFilterUIEngine.filter_config = {}
QuestFilterUIEngine.filter_presets = {}

-- Configuration
QuestFilterUIEngine.config = {
    enabled = true,
    max_active_filters = 5,
    allow_multiple = true,
    show_filter_panel = true,
}

-- Predefined filter types
QuestFilterUIEngine.filter_types = {
    LEVEL = "level",
    DIFFICULTY = "difficulty",
    ZONE = "zone",
    TYPE = "type",
    REWARD = "reward",
    STATUS = "status",
    FACTION = "faction",
}

function QuestFilterUIEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.active_filters then
        self.db.active_filters = {}
    end
    
    if not self.db.filter_config then
        self.db.filter_config = {}
    end
    
    if not self.db.filter_presets then
        self.db.filter_presets = {}
    end
    
    self.active_filters = self.db.active_filters
    self.filter_config = self.db.filter_config
    self.filter_presets = self.db.filter_presets
    self.enabled = true
    
    self:Log("Initialized quest filter UI engine")
end

function QuestFilterUIEngine:AddFilter(filterId, filterType, filterValue)
    if not filterId or not filterType or not filterValue then
        return false
    end
    
    -- Check if filter already active
    if self.active_filters[filterId] then
        return false
    end
    
    -- Check max active filters
    if #self.active_filters >= self.config.max_active_filters and not self.config.allow_multiple then
        return false
    end
    
    local filter = {
        id = filterId,
        type = filterType,
        value = filterValue,
        created_at = GetTime(),
        enabled = true,
    }
    
    self.active_filters[filterId] = filter
    self:Log("Added filter: " .. filterId .. " (" .. filterType .. ")")
    
    return true
end

function QuestFilterUIEngine:RemoveFilter(filterId)
    if not filterId or not self.active_filters[filterId] then
        return false
    end
    
    self.active_filters[filterId] = nil
    self:Log("Removed filter: " .. filterId)
    
    return true
end

function QuestFilterUIEngine:ToggleFilter(filterId)
    if not filterId or not self.active_filters[filterId] then
        return false
    end
    
    self.active_filters[filterId].enabled = not self.active_filters[filterId].enabled
    self:Log("Toggled filter: " .. filterId)
    
    return true
end

function QuestFilterUIEngine:CreateLevelFilter(minLevel, maxLevel)
    local filterId = "level_" .. minLevel .. "_" .. maxLevel .. "_" .. GetTime()
    
    local value = {
        min = tonumber(minLevel) or 1,
        max = tonumber(maxLevel) or 60,
    }
    
    self:AddFilter(filterId, self.filter_types.LEVEL, value)
    
    return filterId
end

function QuestFilterUIEngine:CreateDifficultyFilter(difficulty)
    local filterId = "difficulty_" .. difficulty .. "_" .. GetTime()
    
    self:AddFilter(filterId, self.filter_types.DIFFICULTY, difficulty)
    
    return filterId
end

function QuestFilterUIEngine:CreateZoneFilter(zoneName)
    local filterId = "zone_" .. zoneName .. "_" .. GetTime()
    
    self:AddFilter(filterId, self.filter_types.ZONE, zoneName)
    
    return filterId
end

function QuestFilterUIEngine:CreateTypeFilter(questType)
    local filterId = "type_" .. questType .. "_" .. GetTime()
    
    self:AddFilter(filterId, self.filter_types.TYPE, questType)
    
    return filterId
end

function QuestFilterUIEngine:CreateRewardFilter(minReward)
    local filterId = "reward_" .. minReward .. "_" .. GetTime()
    
    self:AddFilter(filterId, self.filter_types.REWARD, tonumber(minReward) or 0)
    
    return filterId
end

function QuestFilterUIEngine:CreateStatusFilter(status)
    local filterId = "status_" .. status .. "_" .. GetTime()
    
    self:AddFilter(filterId, self.filter_types.STATUS, status)
    
    return filterId
end

function QuestFilterUIEngine:GetActiveFilters()
    local filters = {}
    
    for filterId, filter in pairs(self.active_filters) do
        if filter.enabled then
            table.insert(filters, filter)
        end
    end
    
    return filters
end

function QuestFilterUIEngine:GetFiltersByType(filterType)
    local result = {}
    
    for filterId, filter in pairs(self.active_filters) do
        if filter.type == filterType then
            table.insert(result, filter)
        end
    end
    
    return result
end

function QuestFilterUIEngine:ApplyFilters(questList)
    if not questList or #questList == 0 then
        return {}
    end
    
    local activeFilters = self:GetActiveFilters()
    
    if #activeFilters == 0 then
        return questList
    end
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        local passesAllFilters = true
        
        for _, filter in ipairs(activeFilters) do
            if not self:QuestPassesFilter(quest, filter) then
                passesAllFilters = false
                break
            end
        end
        
        if passesAllFilters then
            table.insert(filtered, quest)
        end
    end
    
    return filtered
end

function QuestFilterUIEngine:QuestPassesFilter(quest, filter)
    if filter.type == self.filter_types.LEVEL then
        return quest.level >= filter.value.min and quest.level <= filter.value.max
    elseif filter.type == self.filter_types.DIFFICULTY then
        return quest.difficulty == filter.value
    elseif filter.type == self.filter_types.ZONE then
        return quest.zone == filter.value
    elseif filter.type == self.filter_types.TYPE then
        return quest.type == filter.value
    elseif filter.type == self.filter_types.REWARD then
        return (quest.reward_gold or 0) >= filter.value
    elseif filter.type == self.filter_types.STATUS then
        return quest.status == filter.value
    end
    
    return true
end

function QuestFilterUIEngine:SaveFilterPreset(presetName)
    if not presetName then
        return false
    end
    
    local preset = {
        name = presetName,
        filters = {},
        created_at = GetTime(),
    }
    
    -- Copy active filters
    for filterId, filter in pairs(self.active_filters) do
        table.insert(preset.filters, {
            type = filter.type,
            value = filter.value,
        })
    end
    
    self.filter_presets[presetName] = preset
    self:Log("Saved filter preset: " .. presetName)
    
    return true
end

function QuestFilterUIEngine:LoadFilterPreset(presetName)
    if not presetName or not self.filter_presets[presetName] then
        return false
    end
    
    -- Clear active filters
    self.active_filters = {}
    
    -- Load preset filters
    local preset = self.filter_presets[presetName]
    for i, filter in ipairs(preset.filters) do
        local filterId = presetName .. "_" .. i
        self:AddFilter(filterId, filter.type, filter.value)
    end
    
    self:Log("Loaded filter preset: " .. presetName)
    
    return true
end

function QuestFilterUIEngine:GetFilterPresets()
    local presets = {}
    
    for presetName, preset in pairs(self.filter_presets) do
        table.insert(presets, {
            name = presetName,
            filter_count = #preset.filters,
            created_at = preset.created_at,
        })
    end
    
    return presets
end

function QuestFilterUIEngine:DeleteFilterPreset(presetName)
    if not presetName or not self.filter_presets[presetName] then
        return false
    end
    
    self.filter_presets[presetName] = nil
    self:Log("Deleted filter preset: " .. presetName)
    
    return true
end

function QuestFilterUIEngine:ClearAllFilters()
    local count = 0
    
    for filterId in pairs(self.active_filters) do
        self.active_filters[filterId] = nil
        count = count + 1
    end
    
    self:Log("Cleared " .. count .. " filters")
    
    return count
end

function QuestFilterUIEngine:GetFilterStatistics()
    local stats = {
        total_active = 0,
        by_type = {},
        total_presets = 0,
        enabled_filters = 0,
    }
    
    for filterId, filter in pairs(self.active_filters) do
        stats.total_active = stats.total_active + 1
        
        if filter.enabled then
            stats.enabled_filters = stats.enabled_filters + 1
        end
        
        if not stats.by_type[filter.type] then
            stats.by_type[filter.type] = 0
        end
        stats.by_type[filter.type] = stats.by_type[filter.type] + 1
    end
    
    for _ in pairs(self.filter_presets) do
        stats.total_presets = stats.total_presets + 1
    end
    
    return stats
end

function QuestFilterUIEngine:GetStatus()
    local stats = self:GetFilterStatistics()
    
    return {
        enabled = self.enabled,
        total_active = stats.total_active,
        enabled_filters = stats.enabled_filters,
        total_presets = stats.total_presets,
        max_filters = self.config.max_active_filters,
    }
end

function QuestFilterUIEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestFilterUIEngine] " .. message)
    else
        print("[QuestFilterUIEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTFILTER1 = "/questfilter"
    SlashCmdList["QUESTFILTER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "level" then
            local min, max = args:match("^(%d+)%s+(%d+)$")
            if min and max then
                QuestFilterUIEngine:CreateLevelFilter(tonumber(min), tonumber(max))
                print("Added level filter: " .. min .. "-" .. max)
            else
                print("Usage: /questfilter level <min> <max>")
            end
        elseif cmd == "difficulty" then
            if args ~= "" then
                QuestFilterUIEngine:CreateDifficultyFilter(args)
                print("Added difficulty filter: " .. args)
            else
                print("Usage: /questfilter difficulty <type>")
            end
        elseif cmd == "zone" then
            if args ~= "" then
                QuestFilterUIEngine:CreateZoneFilter(args)
                print("Added zone filter: " .. args)
            else
                print("Usage: /questfilter zone <name>")
            end
        elseif cmd == "clear" then
            local count = QuestFilterUIEngine:ClearAllFilters()
            print("Cleared " .. count .. " filters")
        elseif cmd == "active" then
            local filters = QuestFilterUIEngine:GetActiveFilters()
            print("Active Filters (" .. #filters .. "):")
            for i, filter in ipairs(filters) do
                print(i .. ". " .. filter.type .. ": " .. tostring(filter.value))
            end
        elseif cmd == "save" then
            if args ~= "" then
                QuestFilterUIEngine:SaveFilterPreset(args)
                print("Saved preset: " .. args)
            else
                print("Usage: /questfilter save <name>")
            end
        elseif cmd == "load" then
            if args ~= "" then
                local success = QuestFilterUIEngine:LoadFilterPreset(args)
                print("Load preset: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questfilter load <name>")
            end
        elseif cmd == "presets" then
            local presets = QuestFilterUIEngine:GetFilterPresets()
            print("Filter Presets (" .. #presets .. "):")
            for i, preset in ipairs(presets) do
                print(i .. ". " .. preset.name .. " (" .. preset.filter_count .. " filters)")
            end
        elseif cmd == "stats" then
            local stats = QuestFilterUIEngine:GetFilterStatistics()
            print("Filter Statistics:")
            print("  Active: " .. stats.total_active .. "/" .. stats.enabled_filters)
            print("  Presets: " .. stats.total_presets)
        elseif cmd == "status" then
            local status = QuestFilterUIEngine:GetStatus()
            print("Quest Filter UI Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Active: " .. status.total_active .. "/" .. status.max_filters)
            print("  Presets: " .. status.total_presets)
        else
            print("Quest Filter UI Commands:")
            print("  /questfilter level <min> <max> - Add level filter")
            print("  /questfilter difficulty <type> - Add difficulty filter")
            print("  /questfilter zone <name> - Add zone filter")
            print("  /questfilter clear - Clear all filters")
            print("  /questfilter active - Show active filters")
            print("  /questfilter save <name> - Save filter preset")
            print("  /questfilter load <name> - Load filter preset")
            print("  /questfilter presets - List presets")
            print("  /questfilter stats - Show statistics")
            print("  /questfilter status - Show engine status")
        end
    end
end

return QuestFilterUIEngine
