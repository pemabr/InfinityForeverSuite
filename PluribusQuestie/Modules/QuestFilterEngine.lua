-- QuestFilterEngine.lua - Filter quests by level, zone, type, rewards
-- Part of PluribusQuestie addon suite
-- Provides powerful quest filtering for UI display

local QuestFilterEngine = {}
QuestFilterEngine.enabled = false
QuestFilterEngine.db = nil
QuestFilterEngine.filters = {}
QuestFilterEngine.active_filters = {}

-- Configuration
QuestFilterEngine.config = {
    enabled = true,
    max_filters = 10,
    default_sort = "level",  -- level, name, zone, rewards, difficulty
    sort_ascending = true,
}

function QuestFilterEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.filters then
        self.db.filters = {}
    end
    
    if not self.db.active_filters then
        self.db.active_filters = {}
    end
    
    self.filters = self.db.filters
    self.active_filters = self.db.active_filters
    self.enabled = true
    
    self:Log("Initialized quest filter engine")
end

function QuestFilterEngine:CreateFilter(filterId, filterName, filterType)
    if not filterId or not filterName or not filterType then
        return false
    end
    
    if #self.filters >= self.config.max_filters then
        self:Log("Max filters reached (" .. self.config.max_filters .. ")")
        return false
    end
    
    local filter = {
        id = filterId,
        name = filterName,
        type = filterType,  -- level, zone, type, reward, status, difficulty
        criteria = {},
        created_at = GetTime(),
        active = false,
    }
    
    table.insert(self.filters, filter)
    self:Log("Created filter: " .. filterId)
    
    return true
end

function QuestFilterEngine:GetFilter(filterId)
    for _, filter in ipairs(self.filters) do
        if filter.id == filterId then
            return filter
        end
    end
    
    return nil
end

function QuestFilterEngine:AddFilterCriteria(filterId, criteriaKey, criteriaValue)
    local filter = self:GetFilter(filterId)
    if not filter then
        return false
    end
    
    if filter.criteria[criteriaKey] then
        if type(filter.criteria[criteriaKey]) == "table" then
            table.insert(filter.criteria[criteriaKey], criteriaValue)
        else
            filter.criteria[criteriaKey] = { filter.criteria[criteriaKey], criteriaValue }
        end
    else
        filter.criteria[criteriaKey] = criteriaValue
    end
    
    return true
end

function QuestFilterEngine:ActivateFilter(filterId)
    local filter = self:GetFilter(filterId)
    if not filter then
        return false
    end
    
    filter.active = true
    table.insert(self.active_filters, filterId)
    self:Log("Activated filter: " .. filterId)
    
    return true
end

function QuestFilterEngine:DeactivateFilter(filterId)
    local filter = self:GetFilter(filterId)
    if not filter then
        return false
    end
    
    filter.active = false
    
    for i, id in ipairs(self.active_filters) do
        if id == filterId then
            table.remove(self.active_filters, i)
            break
        end
    end
    
    self:Log("Deactivated filter: " .. filterId)
    
    return true
end

function QuestFilterEngine:FilterByLevel(questList, minLevel, maxLevel)
    if not questList or #questList == 0 then
        return {}
    end
    
    minLevel = minLevel or 1
    maxLevel = maxLevel or 60
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        local level = quest.level or 1
        
        if level >= minLevel and level <= maxLevel then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:FilterByZone(questList, zoneId)
    if not questList or #questList == 0 or not zoneId then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        if quest.zone_id == zoneId then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:FilterByType(questList, questType)
    if not questList or #questList == 0 or not questType then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        if quest.type == questType then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:FilterByReward(questList, minGold, minXP)
    if not questList or #questList == 0 then
        return {}
    end
    
    minGold = minGold or 0
    minXP = minXP or 0
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        local gold = quest.reward_gold or 0
        local xp = quest.reward_xp or 0
        
        if gold >= minGold and xp >= minXP then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:FilterByStatus(questList, status)
    if not questList or #questList == 0 or not status then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        if quest.status == status then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:FilterByDifficulty(questList, difficulty)
    if not questList or #questList == 0 or not difficulty then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(questList) do
        if quest.difficulty == difficulty then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestFilterEngine:SortQuests(questList, sortBy, ascending)
    if not questList or #questList == 0 then
        return {}
    end
    
    sortBy = sortBy or self.config.default_sort
    ascending = ascending == nil and self.config.sort_ascending or ascending
    
    local function comparator(a, b)
        local result
        
        if sortBy == "level" then
            result = (a.level or 0) < (b.level or 0)
        elseif sortBy == "name" then
            result = (a.name or "") < (b.name or "")
        elseif sortBy == "zone" then
            result = (a.zone_id or 0) < (b.zone_id or 0)
        elseif sortBy == "rewards" then
            result = ((a.reward_gold or 0) + (a.reward_xp or 0)) < 
                     ((b.reward_gold or 0) + (b.reward_xp or 0))
        elseif sortBy == "difficulty" then
            result = (a.difficulty or 0) < (b.difficulty or 0)
        else
            result = (a.level or 0) < (b.level or 0)
        end
        
        return ascending and result or not result
    end
    
    table.sort(questList, comparator)
    
    return questList
end

function QuestFilterEngine:ApplyActiveFilters(questList)
    if #self.active_filters == 0 then
        return questList
    end
    
    local results = questList
    
    for _, filterId in ipairs(self.active_filters) do
        local filter = self:GetFilter(filterId)
        
        if filter and filter.type == "level" then
            results = self:FilterByLevel(results, filter.criteria.min, filter.criteria.max)
        elseif filter and filter.type == "zone" then
            results = self:FilterByZone(results, filter.criteria.zone_id)
        elseif filter and filter.type == "type" then
            results = self:FilterByType(results, filter.criteria.quest_type)
        elseif filter and filter.type == "reward" then
            results = self:FilterByReward(results, filter.criteria.min_gold, filter.criteria.min_xp)
        elseif filter and filter.type == "status" then
            results = self:FilterByStatus(results, filter.criteria.status)
        elseif filter and filter.type == "difficulty" then
            results = self:FilterByDifficulty(results, filter.criteria.difficulty)
        end
    end
    
    return results
end

function QuestFilterEngine:ClearAllFilters()
    for _, filter in ipairs(self.filters) do
        filter.active = false
    end
    
    self.active_filters = {}
    self:Log("Cleared all filters")
    
    return true
end

function QuestFilterEngine:DeleteFilter(filterId)
    for i, filter in ipairs(self.filters) do
        if filter.id == filterId then
            if filter.active then
                self:DeactivateFilter(filterId)
            end
            
            table.remove(self.filters, i)
            self:Log("Deleted filter: " .. filterId)
            return true
        end
    end
    
    return false
end

function QuestFilterEngine:GetActiveFilterCount()
    return #self.active_filters
end

function QuestFilterEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_filters = #self.filters,
        active_filters = #self.active_filters,
        max_filters = self.config.max_filters,
    }
end

function QuestFilterEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestFilterEngine] " .. message)
    else
        print("[QuestFilterEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTFILTER1 = "/questfilter"
    SlashCmdList["QUESTFILTER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local filterId, filterType = args:match("(%S+)%s+(%S+)")
            if filterId and filterType then
                QuestFilterEngine:CreateFilter(filterId, "Filter_" .. filterId, filterType)
                print("Created filter: " .. filterId .. " (" .. filterType .. ")")
            else
                print("Usage: /questfilter create <filterId> <type>")
            end
        elseif cmd == "activate" then
            local filterId = args
            if filterId ~= "" then
                QuestFilterEngine:ActivateFilter(filterId)
                print("Activated filter: " .. filterId)
            else
                print("Usage: /questfilter activate <filterId>")
            end
        elseif cmd == "deactivate" then
            local filterId = args
            if filterId ~= "" then
                QuestFilterEngine:DeactivateFilter(filterId)
                print("Deactivated filter: " .. filterId)
            else
                print("Usage: /questfilter deactivate <filterId>")
            end
        elseif cmd == "clear" then
            QuestFilterEngine:ClearAllFilters()
            print("Cleared all filters")
        elseif cmd == "status" then
            local status = QuestFilterEngine:GetStatus()
            print("Quest Filter System:")
            print("  Total Filters: " .. status.total_filters)
            print("  Active Filters: " .. status.active_filters)
        else
            print("Quest Filter Commands:")
            print("  /questfilter create <id> <type> - Create filter")
            print("  /questfilter activate <id> - Activate filter")
            print("  /questfilter deactivate <id> - Deactivate filter")
            print("  /questfilter clear - Clear all filters")
            print("  /questfilter status - Show system status")
        end
    end
end

return QuestFilterEngine
