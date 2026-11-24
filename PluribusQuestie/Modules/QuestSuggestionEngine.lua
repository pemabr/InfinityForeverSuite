-- QuestSuggestionEngine.lua - Suggest related and next quests
-- Part of PluribusQuestie addon suite
-- Provides intelligent quest recommendations based on current progress

local QuestSuggestionEngine = {}
QuestSuggestionEngine.enabled = false
QuestSuggestionEngine.db = nil
QuestSuggestionEngine.suggestions = {}
QuestSuggestionEngine.suggestion_cache = {}

-- Configuration
QuestSuggestionEngine.config = {
    enabled = true,
    max_suggestions = 10,
    similarity_threshold = 0.5,
    cache_ttl = 300,  -- seconds
}

function QuestSuggestionEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.suggestions then
        self.db.suggestions = {}
    end
    
    if not self.db.suggestion_cache then
        self.db.suggestion_cache = {}
    end
    
    self.suggestions = self.db.suggestions
    self.suggestion_cache = self.db.suggestion_cache
    self.enabled = true
    
    self:Log("Initialized quest suggestion engine")
end

function QuestSuggestionEngine:GetSuggestionsForQuest(questId)
    if not questId then
        return {}
    end
    
    -- Check cache first
    if self.suggestion_cache[questId] then
        local cached = self.suggestion_cache[questId]
        if GetTime() - cached.cached_at < self.config.cache_ttl then
            return cached.suggestions
        end
    end
    
    if not QuestDatabaseEngine then
        return {}
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return {}
    end
    
    local suggestions = {}
    
    -- Get continuation quests (related)
    if quest.related_quests and #quest.related_quests > 0 then
        for _, relatedId in ipairs(quest.related_quests) do
            local related = QuestDatabaseEngine:GetQuest(relatedId)
            if related then
                table.insert(suggestions, {
                    id = relatedId,
                    name = related.name,
                    level = related.level,
                    zone = related.zone,
                    type = "continuation",
                    relevance = 1.0,
                })
            end
        end
    end
    
    -- Get similar level quests in same zone
    if quest.zone then
        local allQuests = QuestDatabaseEngine:GetAllQuests()
        if allQuests then
            for _, otherQuest in ipairs(allQuests) do
                if otherQuest.id ~= questId and otherQuest.zone == quest.zone then
                    local levelDiff = math.abs(otherQuest.level - quest.level)
                    
                    if levelDiff <= 3 then
                        local relevance = 1.0 - (levelDiff / 10)
                        
                        table.insert(suggestions, {
                            id = otherQuest.id,
                            name = otherQuest.name,
                            level = otherQuest.level,
                            zone = otherQuest.zone,
                            type = "similar_level",
                            relevance = relevance,
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by relevance
    table.sort(suggestions, function(a, b)
        return a.relevance > b.relevance
    end)
    
    -- Limit to max suggestions
    if #suggestions > self.config.max_suggestions then
        for i = #suggestions, self.config.max_suggestions + 1, -1 do
            table.remove(suggestions, i)
        end
    end
    
    -- Cache suggestions
    self.suggestion_cache[questId] = {
        suggestions = suggestions,
        cached_at = GetTime(),
    }
    
    return suggestions
end

function QuestSuggestionEngine:GetNextQuestAfter(questId)
    if not questId or not QuestDatabaseEngine then
        return nil
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest or not quest.related_quests or #quest.related_quests == 0 then
        return nil
    end
    
    -- Return the first continuation quest
    local nextId = quest.related_quests[1]
    local nextQuest = QuestDatabaseEngine:GetQuest(nextId)
    
    if nextQuest then
        return {
            id = nextQuest.id,
            name = nextQuest.name,
            level = nextQuest.level,
            zone = nextQuest.zone,
            type = "continuation",
        }
    end
    
    return nil
end

function QuestSuggestionEngine:GetQuestsInSameZone(questId)
    if not questId or not QuestDatabaseEngine then
        return {}
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return {}
    end
    
    local results = {}
    local allQuests = QuestDatabaseEngine:GetAllQuests()
    
    if allQuests then
        for _, otherQuest in ipairs(allQuests) do
            if otherQuest.id ~= questId and otherQuest.zone == quest.zone then
                table.insert(results, {
                    id = otherQuest.id,
                    name = otherQuest.name,
                    level = otherQuest.level,
                })
            end
        end
    end
    
    return results
end

function QuestSuggestionEngine:GetQuestsByLevel(minLevel, maxLevel)
    if not QuestDatabaseEngine then
        return {}
    end
    
    minLevel = minLevel or 1
    maxLevel = maxLevel or 60
    
    local results = {}
    local allQuests = QuestDatabaseEngine:GetAllQuests()
    
    if allQuests then
        for _, quest in ipairs(allQuests) do
            if quest.level >= minLevel and quest.level <= maxLevel then
                table.insert(results, {
                    id = quest.id,
                    name = quest.name,
                    level = quest.level,
                    zone = quest.zone,
                })
            end
        end
    end
    
    return results
end

function QuestSuggestionEngine:GetRecommendedNextQuests(playerLevel, currentZone)
    if not QuestDatabaseEngine then
        return {}
    end
    
    local minLevel = math.max(1, playerLevel - 5)
    local maxLevel = playerLevel + 2
    
    local recommendations = {}
    local allQuests = QuestDatabaseEngine:GetAllQuests()
    
    if allQuests then
        for _, quest in ipairs(allQuests) do
            if quest.level >= minLevel and quest.level <= maxLevel then
                local score = 0
                
                -- Higher score for same zone
                if currentZone and quest.zone == currentZone then
                    score = score + 10
                end
                
                -- Higher score for exact level match
                if quest.level == playerLevel then
                    score = score + 5
                end
                
                -- Lower score if too high level
                if quest.level > playerLevel + 2 then
                    score = score - 5
                end
                
                table.insert(recommendations, {
                    id = quest.id,
                    name = quest.name,
                    level = quest.level,
                    zone = quest.zone,
                    score = score,
                })
            end
        end
    end
    
    -- Sort by score
    table.sort(recommendations, function(a, b)
        return a.score > b.score
    end)
    
    -- Limit to max suggestions
    if #recommendations > self.config.max_suggestions then
        for i = #recommendations, self.config.max_suggestions + 1, -1 do
            table.remove(recommendations, i)
        end
    end
    
    return recommendations
end

function QuestSuggestionEngine:IsSimilarLevel(questId1, questId2, maxDifference)
    if not questId1 or not questId2 or not QuestDatabaseEngine then
        return false
    end
    
    maxDifference = maxDifference or 3
    
    local quest1 = QuestDatabaseEngine:GetQuest(questId1)
    local quest2 = QuestDatabaseEngine:GetQuest(questId2)
    
    if not quest1 or not quest2 then
        return false
    end
    
    return math.abs(quest1.level - quest2.level) <= maxDifference
end

function QuestSuggestionEngine:GetSimilarQuests(questId, similarityType)
    similarityType = similarityType or "level"
    
    if not questId or not QuestDatabaseEngine then
        return {}
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return {}
    end
    
    local results = {}
    local allQuests = QuestDatabaseEngine:GetAllQuests()
    
    if not allQuests then
        return {}
    end
    
    if similarityType == "level" then
        for _, otherQuest in ipairs(allQuests) do
            if otherQuest.id ~= questId then
                if self:IsSimilarLevel(questId, otherQuest.id, 2) then
                    table.insert(results, {
                        id = otherQuest.id,
                        name = otherQuest.name,
                        level = otherQuest.level,
                        zone = otherQuest.zone,
                    })
                end
            end
        end
    elseif similarityType == "zone" then
        for _, otherQuest in ipairs(allQuests) do
            if otherQuest.id ~= questId and otherQuest.zone == quest.zone then
                table.insert(results, {
                    id = otherQuest.id,
                    name = otherQuest.name,
                    level = otherQuest.level,
                })
            end
        end
    elseif similarityType == "type" then
        for _, otherQuest in ipairs(allQuests) do
            if otherQuest.id ~= questId and otherQuest.type == quest.type then
                table.insert(results, {
                    id = otherQuest.id,
                    name = otherQuest.name,
                    level = otherQuest.level,
                    zone = otherQuest.zone,
                })
            end
        end
    end
    
    return results
end

function QuestSuggestionEngine:ClearCache()
    self.suggestion_cache = {}
    self:Log("Suggestion cache cleared")
    return true
end

function QuestSuggestionEngine:GetStatus()
    local cacheSize = table.getn(self.suggestion_cache)
    
    return {
        enabled = self.enabled,
        cache_size = cacheSize,
        max_suggestions = self.config.max_suggestions,
    }
end

function QuestSuggestionEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestSuggestionEngine] " .. message)
    else
        print("[QuestSuggestionEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTSUGGEST1 = "/questsuggest"
    SlashCmdList["QUESTSUGGEST"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "get" then
            local questId = tonumber(args)
            if questId then
                local suggestions = QuestSuggestionEngine:GetSuggestionsForQuest(questId)
                print("Suggestions for Quest " .. questId .. ": " .. #suggestions)
                for i, suggestion in ipairs(suggestions) do
                    print("  [" .. i .. "] [" .. suggestion.level .. "] " .. suggestion.name)
                end
            else
                print("Usage: /questsuggest get <questId>")
            end
        elseif cmd == "next" then
            local questId = tonumber(args)
            if questId then
                local nextQuest = QuestSuggestionEngine:GetNextQuestAfter(questId)
                if nextQuest then
                    print("Next Quest: [" .. nextQuest.level .. "] " .. nextQuest.name)
                else
                    print("No next quest found")
                end
            else
                print("Usage: /questsuggest next <questId>")
            end
        elseif cmd == "zone" then
            local questId = tonumber(args)
            if questId then
                local quests = QuestSuggestionEngine:GetQuestsInSameZone(questId)
                print("Quests in same zone: " .. #quests)
                for i, quest in ipairs(quests) do
                    print("  [" .. i .. "] [" .. quest.level .. "] " .. quest.name)
                end
            else
                print("Usage: /questsuggest zone <questId>")
            end
        elseif cmd == "similar" then
            local questId = tonumber(args)
            if questId then
                local quests = QuestSuggestionEngine:GetSimilarQuests(questId, "level")
                print("Similar Level Quests: " .. #quests)
                for i, quest in ipairs(quests) do
                    print("  [" .. i .. "] [" .. quest.level .. "] " .. quest.name)
                end
            else
                print("Usage: /questsuggest similar <questId>")
            end
        elseif cmd == "clear" then
            QuestSuggestionEngine:ClearCache()
            print("Cache cleared")
        elseif cmd == "status" then
            local status = QuestSuggestionEngine:GetStatus()
            print("Quest Suggestion System:")
            print("  Cache Size: " .. status.cache_size)
            print("  Max Suggestions: " .. status.max_suggestions)
        else
            print("Quest Suggestion Commands:")
            print("  /questsuggest get <questId> - Get suggestions")
            print("  /questsuggest next <questId> - Get next quest")
            print("  /questsuggest zone <questId> - Quests in zone")
            print("  /questsuggest similar <questId> - Similar quests")
            print("  /questsuggest clear - Clear cache")
            print("  /questsuggest status - Show status")
        end
    end
end

return QuestSuggestionEngine
