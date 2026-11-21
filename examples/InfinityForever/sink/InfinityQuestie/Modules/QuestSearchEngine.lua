-- QuestSearchEngine.lua - Advanced quest search and discovery
-- Part of InfinityQuestie addon suite
-- Provides powerful search, indexing, and quest discovery features

local QuestSearchEngine = {}
QuestSearchEngine.enabled = false
QuestSearchEngine.db = nil
QuestSearchEngine.search_index = {}
QuestSearchEngine.search_cache = {}
QuestSearchEngine.search_config = {}

-- Configuration
QuestSearchEngine.config = {
    enabled = true,
    cache_results = true,
    max_cache_size = 100,
    index_names = true,
    index_descriptions = true,
    index_objectives = true,
    index_rewards = true,
}

function QuestSearchEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.search_index then
        self.db.search_index = {}
    end
    
    if not self.db.search_cache then
        self.db.search_cache = {}
    end
    
    if not self.db.search_config then
        self.db.search_config = {}
    end
    
    self.search_index = self.db.search_index
    self.search_cache = self.db.search_cache
    self.search_config = self.db.search_config
    self.enabled = true
    
    self:Log("Initialized quest search engine")
end

function QuestSearchEngine:IndexQuest(questId, questData)
    if not questId or not questData then
        return false
    end
    
    questId = tonumber(questId)
    
    local index = {
        quest_id = questId,
        name = questData.name or "",
        name_lower = (questData.name or ""):lower(),
        description = questData.description or "",
        description_lower = (questData.description or ""):lower(),
        objectives = questData.objectives or {},
        objectives_text = "",
        rewards = questData.rewards or "",
        rewards_lower = (questData.rewards or ""):lower(),
        keywords = {},
        indexed_at = GetTime(),
    }
    
    -- Build objectives text
    if type(questData.objectives) == "table" then
        for _, obj in ipairs(questData.objectives) do
            index.objectives_text = index.objectives_text .. " " .. (obj.text or "")
        end
    end
    
    -- Extract keywords from name
    if index.name ~= "" then
        for word in index.name:gmatch("%w+") do
            table.insert(index.keywords, word:lower())
        end
    end
    
    self.search_index[questId] = index
    self:Log("Indexed quest: " .. questId)
    
    return true
end

function QuestSearchEngine:SearchByName(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end
    
    searchTerm = searchTerm:lower()
    local results = {}
    
    for questId, index in pairs(self.search_index) do
        if index.name_lower:find(searchTerm, 1, true) then
            table.insert(results, {
                quest_id = questId,
                name = index.name,
                match_type = "name",
                score = 100,
            })
        end
    end
    
    return results
end

function QuestSearchEngine:SearchByDescription(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end
    
    searchTerm = searchTerm:lower()
    local results = {}
    
    for questId, index in pairs(self.search_index) do
        if index.description_lower:find(searchTerm, 1, true) then
            table.insert(results, {
                quest_id = questId,
                name = index.name,
                match_type = "description",
                score = 75,
            })
        end
    end
    
    return results
end

function QuestSearchEngine:SearchByObjective(objectiveTerm)
    if not objectiveTerm or objectiveTerm == "" then
        return {}
    end
    
    objectiveTerm = objectiveTerm:lower()
    local results = {}
    
    for questId, index in pairs(self.search_index) do
        if index.objectives_text:lower():find(objectiveTerm, 1, true) then
            table.insert(results, {
                quest_id = questId,
                name = index.name,
                match_type = "objective",
                score = 50,
            })
        end
    end
    
    return results
end

function QuestSearchEngine:SearchByKeyword(keyword)
    if not keyword or keyword == "" then
        return {}
    end
    
    keyword = keyword:lower()
    local results = {}
    
    for questId, index in pairs(self.search_index) do
        for _, kw in ipairs(index.keywords) do
            if kw == keyword then
                table.insert(results, {
                    quest_id = questId,
                    name = index.name,
                    match_type = "keyword",
                    score = 80,
                })
                break
            end
        end
    end
    
    return results
end

function QuestSearchEngine:AdvancedSearch(criteria)
    if not criteria then
        return {}
    end
    
    local results = {}
    
    for questId, index in pairs(self.search_index) do
        local matches = 0
        
        if criteria.name and index.name_lower:find(criteria.name:lower(), 1, true) then
            matches = matches + 1
        end
        
        if criteria.description and index.description_lower:find(criteria.description:lower(), 1, true) then
            matches = matches + 1
        end
        
        if criteria.reward_type and index.rewards_lower:find(criteria.reward_type:lower(), 1, true) then
            matches = matches + 1
        end
        
        if matches > 0 then
            table.insert(results, {
                quest_id = questId,
                name = index.name,
                matches = matches,
                score = matches * 50,
            })
        end
    end
    
    -- Sort by score descending
    table.sort(results, function(a, b) return a.score > b.score end)
    
    return results
end

function QuestSearchEngine:AutoComplete(partialTerm)
    if not partialTerm or partialTerm == "" then
        return {}
    end
    
    partialTerm = partialTerm:lower()
    local suggestions = {}
    
    for questId, index in pairs(self.search_index) do
        if index.name_lower:sub(1, #partialTerm) == partialTerm then
            table.insert(suggestions, {
                quest_id = questId,
                name = index.name,
            })
        end
    end
    
    -- Limit to top 10
    if #suggestions > 10 then
        for i = 11, #suggestions do
            table.remove(suggestions)
        end
    end
    
    return suggestions
end

function QuestSearchEngine:GetSimilarQuests(questId, limit)
    limit = limit or 5
    questId = tonumber(questId)
    
    if not self.search_index[questId] then
        return {}
    end
    
    local sourceIndex = self.search_index[questId]
    local similar = {}
    
    for otherId, otherIndex in pairs(self.search_index) do
        if otherId ~= questId then
            local similarity = 0
            
            -- Name similarity
            if sourceIndex.name_lower == otherIndex.name_lower then
                similarity = similarity + 100
            end
            
            -- Keyword overlap
            for _, kw in ipairs(sourceIndex.keywords) do
                for _, okw in ipairs(otherIndex.keywords) do
                    if kw == okw then
                        similarity = similarity + 20
                    end
                end
            end
            
            if similarity > 0 then
                table.insert(similar, {
                    quest_id = otherId,
                    name = otherIndex.name,
                    similarity_score = similarity,
                })
            end
        end
    end
    
    -- Sort by similarity score descending
    table.sort(similar, function(a, b) return a.similarity_score > b.similarity_score end)
    
    -- Return top N
    local result = {}
    for i = 1, math.min(limit, #similar) do
        table.insert(result, similar[i])
    end
    
    return result
end

function QuestSearchEngine:GetSearchStatistics()
    local stats = {
        total_indexed = 0,
        cached_searches = 0,
        average_index_size = 0,
    }
    
    local totalSize = 0
    
    for questId in pairs(self.search_index) do
        stats.total_indexed = stats.total_indexed + 1
        totalSize = totalSize + 1
    end
    
    for _ in pairs(self.search_cache) do
        stats.cached_searches = stats.cached_searches + 1
    end
    
    if stats.total_indexed > 0 then
        stats.average_index_size = totalSize / stats.total_indexed
    end
    
    return stats
end

function QuestSearchEngine:ClearCache()
    local count = 0
    
    for cacheKey in pairs(self.search_cache) do
        self.search_cache[cacheKey] = nil
        count = count + 1
    end
    
    self:Log("Cleared " .. count .. " search cache entries")
    
    return count
end

function QuestSearchEngine:GetStatus()
    local stats = self:GetSearchStatistics()
    
    return {
        enabled = self.enabled,
        total_indexed = stats.total_indexed,
        cached_searches = stats.cached_searches,
        cache_enabled = self.config.cache_results,
    }
end

function QuestSearchEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestSearchEngine] " .. message)
    else
        print("[QuestSearchEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTSEARCH1 = "/questsearch"
    SlashCmdList["QUESTSEARCH"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "name" then
            if args ~= "" then
                local results = QuestSearchEngine:SearchByName(args)
                print("Search Results for '" .. args .. "': " .. #results)
                for i = 1, math.min(5, #results) do
                    print(i .. ". " .. results[i].name)
                end
            else
                print("Usage: /questsearch name <term>")
            end
        elseif cmd == "objective" then
            if args ~= "" then
                local results = QuestSearchEngine:SearchByObjective(args)
                print("Objective Search Results: " .. #results)
                for i = 1, math.min(5, #results) do
                    print(i .. ". " .. results[i].name)
                end
            else
                print("Usage: /questsearch objective <term>")
            end
        elseif cmd == "similar" then
            local questId = tonumber(args)
            if questId then
                local similar = QuestSearchEngine:GetSimilarQuests(questId, 5)
                print("Similar to quest " .. questId .. ": " .. #similar)
                for i, quest in ipairs(similar) do
                    print(i .. ". " .. quest.name .. " (" .. quest.similarity_score .. ")")
                end
            else
                print("Usage: /questsearch similar <questId>")
            end
        elseif cmd == "complete" then
            if args ~= "" then
                local suggestions = QuestSearchEngine:AutoComplete(args)
                print("Autocomplete suggestions for '" .. args .. "':")
                for i = 1, math.min(10, #suggestions) do
                    print(i .. ". " .. suggestions[i].name)
                end
            else
                print("Usage: /questsearch complete <partial>")
            end
        elseif cmd == "index" then
            local questId = tonumber(args)
            if questId then
                QuestSearchEngine:IndexQuest(questId, { name = "Quest " .. questId })
                print("Indexed quest " .. questId)
            else
                print("Usage: /questsearch index <questId>")
            end
        elseif cmd == "stats" then
            local stats = QuestSearchEngine:GetSearchStatistics()
            print("Search Statistics:")
            print("  Indexed: " .. stats.total_indexed)
            print("  Cached: " .. stats.cached_searches)
        elseif cmd == "status" then
            local status = QuestSearchEngine:GetStatus()
            print("Quest Search Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Indexed: " .. status.total_indexed)
            print("  Cache: " .. (status.cache_enabled and "Enabled" or "Disabled"))
        else
            print("Quest Search Commands:")
            print("  /questsearch name <term> - Search by name")
            print("  /questsearch objective <term> - Search by objective")
            print("  /questsearch similar <questId> - Find similar quests")
            print("  /questsearch complete <partial> - Autocomplete")
            print("  /questsearch index <questId> - Index quest")
            print("  /questsearch stats - Show statistics")
            print("  /questsearch status - Show engine status")
        end
    end
end

return QuestSearchEngine
