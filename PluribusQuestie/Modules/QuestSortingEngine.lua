-- QuestSortingEngine.lua - Advanced quest sorting and ordering
-- Part of PluribusQuestie addon suite
-- Handles multiple sorting methods and custom quest ordering

local QuestSortingEngine = {}
QuestSortingEngine.enabled = false
QuestSortingEngine.db = nil
QuestSortingEngine.sort_order = {}
QuestSortingEngine.sort_history = {}
QuestSortingEngine.current_sort_method = "level"

-- Configuration
QuestSortingEngine.config = {
    enabled = true,
    cache_sorts = true,
    history_size = 10,
}

-- Sorting methods
QuestSortingEngine.sort_methods = {
    "level",        -- By quest level (ascending)
    "name",         -- Alphabetical
    "reward_xp",    -- By XP reward
    "reward_gold",  -- By gold reward
    "difficulty",   -- By difficulty
    "distance",     -- By distance to objective
    "completion",   -- By completion percentage
    "type",         -- By quest type
    "zone",         -- By zone
    "newest",       -- By creation order (newest first)
    "oldest",       -- By creation order (oldest first)
}

function QuestSortingEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.sort_order then
        self.db.sort_order = {}
    end
    
    if not self.db.sort_history then
        self.db.sort_history = {}
    end
    
    if not self.db.current_sort_method then
        self.db.current_sort_method = "level"
    end
    
    self.sort_order = self.db.sort_order
    self.sort_history = self.db.sort_history
    self.current_sort_method = self.db.current_sort_method
    self.enabled = true
    
    self:Log("Initialized quest sorting engine")
end

function QuestSortingEngine:SortByLevel(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false  -- Default to ascending
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local levelA = a.level or 1
        local levelB = b.level or 1
        
        if ascending then
            return levelA < levelB
        else
            return levelA > levelB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByName(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local nameA = a.name or ""
        local nameB = b.name or ""
        
        if ascending then
            return nameA < nameB
        else
            return nameA > nameB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByRewardXP(questList, descending)
    if not questList then
        return {}
    end
    
    descending = descending ~= false  -- Default to descending (highest first)
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local xpA = (a.rewards and a.rewards.xp) or 0
        local xpB = (b.rewards and b.rewards.xp) or 0
        
        if descending then
            return xpA > xpB
        else
            return xpA < xpB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByRewardGold(questList, descending)
    if not questList then
        return {}
    end
    
    descending = descending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local goldA = (a.rewards and a.rewards.gold) or 0
        local goldB = (b.rewards and b.rewards.gold) or 0
        
        if descending then
            return goldA > goldB
        else
            return goldA < goldB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByDifficulty(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local diffA = a.difficulty or 2
        local diffB = b.difficulty or 2
        
        if ascending then
            return diffA < diffB
        else
            return diffA > diffB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByDistance(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local distA = a.distance or 0
        local distB = b.distance or 0
        
        if ascending then
            return distA < distB
        else
            return distA > distB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByCompletion(questList, descending)
    if not questList then
        return {}
    end
    
    descending = descending ~= false  -- Higher completion first
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local completionA = (a.completion_percent) or 0
        local completionB = (b.completion_percent) or 0
        
        if descending then
            return completionA > completionB
        else
            return completionA < completionB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByZone(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local zoneA = a.zone or ""
        local zoneB = b.zone or ""
        
        if ascending then
            return zoneA < zoneB
        else
            return zoneA > zoneB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByType(questList, ascending)
    if not questList then
        return {}
    end
    
    ascending = ascending ~= false
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local typeA = a.quest_type or "Normal"
        local typeB = b.quest_type or "Normal"
        
        if ascending then
            return typeA < typeB
        else
            return typeA > typeB
        end
    end)
    
    return sorted
end

function QuestSortingEngine:SortByNewest(questList)
    if not questList then
        return {}
    end
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local idA = a.id or 0
        local idB = b.id or 0
        return idA > idB  -- Highest ID first (newest)
    end)
    
    return sorted
end

function QuestSortingEngine:SortByOldest(questList)
    if not questList then
        return {}
    end
    
    local sorted = {}
    for _, quest in ipairs(questList) do
        table.insert(sorted, quest)
    end
    
    table.sort(sorted, function(a, b)
        local idA = a.id or 0
        local idB = b.id or 0
        return idA < idB  -- Lowest ID first (oldest)
    end)
    
    return sorted
end

function QuestSortingEngine:Sort(questList, sortMethod, sortOptions)
    if not questList or not sortMethod then
        return questList
    end
    
    sortOptions = sortOptions or {}
    local ascending = sortOptions.ascending ~= false
    local descending = sortOptions.descending ~= false
    
    local sorted = {}
    
    if sortMethod == "level" then
        sorted = self:SortByLevel(questList, ascending)
    elseif sortMethod == "name" then
        sorted = self:SortByName(questList, ascending)
    elseif sortMethod == "reward_xp" then
        sorted = self:SortByRewardXP(questList, descending)
    elseif sortMethod == "reward_gold" then
        sorted = self:SortByRewardGold(questList, descending)
    elseif sortMethod == "difficulty" then
        sorted = self:SortByDifficulty(questList, ascending)
    elseif sortMethod == "distance" then
        sorted = self:SortByDistance(questList, ascending)
    elseif sortMethod == "completion" then
        sorted = self:SortByCompletion(questList, descending)
    elseif sortMethod == "type" then
        sorted = self:SortByType(questList, ascending)
    elseif sortMethod == "zone" then
        sorted = self:SortByZone(questList, ascending)
    elseif sortMethod == "newest" then
        sorted = self:SortByNewest(questList)
    elseif sortMethod == "oldest" then
        sorted = self:SortByOldest(questList)
    else
        self:Log("Unknown sort method: " .. sortMethod)
        return questList
    end
    
    self.current_sort_method = sortMethod
    self.db.current_sort_method = sortMethod
    
    -- Add to history
    table.insert(self.sort_history, {
        method = sortMethod,
        timestamp = GetTime(),
        quest_count = #sorted,
    })
    
    -- Keep history size limited
    while #self.sort_history > self.config.history_size do
        table.remove(self.sort_history, 1)
    end
    
    return sorted
end

function QuestSortingEngine:GetSortMethods()
    return self.sort_methods
end

function QuestSortingEngine:IsValidSortMethod(sortMethod)
    if not sortMethod then
        return false
    end
    
    for _, method in ipairs(self.sort_methods) do
        if method == sortMethod then
            return true
        end
    end
    
    return false
end

function QuestSortingEngine:GetCurrentSortMethod()
    return self.current_sort_method
end

function QuestSortingEngine:GetSortHistory()
    return self.sort_history
end

function QuestSortingEngine:GetStatus()
    return {
        enabled = self.enabled,
        current_sort_method = self.current_sort_method,
        total_sort_methods = #self.sort_methods,
        history_entries = #self.sort_history,
    }
end

function QuestSortingEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestSortingEngine] " .. message)
    else
        print("[QuestSortingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTSORT1 = "/questsort"
    SlashCmdList["QUESTSORT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "methods" then
            local methods = QuestSortingEngine:GetSortMethods()
            print("Available Sort Methods:")
            for i, method in ipairs(methods) do
                print("  [" .. i .. "] " .. method)
            end
        elseif cmd == "current" then
            print("Current sort method: " .. QuestSortingEngine:GetCurrentSortMethod())
        elseif cmd == "history" then
            local history = QuestSortingEngine:GetSortHistory()
            if #history > 0 then
                print("Sort History:")
                for i, entry in ipairs(history) do
                    print("  [" .. i .. "] " .. entry.method .. " (" .. entry.quest_count .. " quests)")
                end
            else
                print("No sort history")
            end
        elseif cmd == "status" then
            local status = QuestSortingEngine:GetStatus()
            print("Quest Sorting Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Current Method: " .. status.current_sort_method)
            print("  Total Methods: " .. status.total_sort_methods)
            print("  History Entries: " .. status.history_entries)
        else
            print("Quest Sorting Commands:")
            print("  /questsort methods - List available sort methods")
            print("  /questsort current - Show current sort method")
            print("  /questsort history - Show sort history")
            print("  /questsort status - Show engine status")
        end
    end
end

return QuestSortingEngine
