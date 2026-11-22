-- Quest Database
-- Quest information and metadata

local InfinityQuestDB = {}
_G.InfinityQuestDB = InfinityQuestDB

InfinityQuestDB.quests = {}
InfinityQuestDB.callbacks = {}

function InfinityQuestDB:RegisterQuest(questID, data)
    if not questID or not data or not data.name then return false end
    
    self.quests[questID] = {
        id = questID,
        name = data.name,
        level = data.level or 1,
        zone = data.zone or "Unknown",
        giver = data.giver or "Unknown",
        type = data.type or "normal",
        rewards_xp = data.rewards_xp or 0,
        rewards_gold = data.rewards_gold or 0,
        rewards_items = data.rewards_items or {},
        prerequisites = data.prerequisites or {},
        followups = data.followups or {},
        description = data.description or "",
        objectives = data.objectives or {},
    }
    
    return true
end

function InfinityQuestDB:GetQuest(questID)
    return self.quests[questID]
end

function InfinityQuestDB:GetQuestsByZone(zone)
    local result = {}
    for questID, quest in pairs(self.quests) do
        if quest.zone == zone then
            table.insert(result, quest)
        end
    end
    return result
end

function InfinityQuestDB:GetQuestsByLevel(minLevel, maxLevel)
    local result = {}
    for questID, quest in pairs(self.quests) do
        if quest.level >= minLevel and quest.level <= maxLevel then
            table.insert(result, quest)
        end
    end
    return result
end

function InfinityQuestDB:SearchQuests(searchTerm)
    local result = {}
    searchTerm = searchTerm:lower()
    
    for questID, quest in pairs(self.quests) do
        if quest.name:lower():find(searchTerm) or 
           quest.description:lower():find(searchTerm) then
            table.insert(result, quest)
        end
    end
    
    return result
end

function InfinityQuestDB:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityQuestDB:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityQuestDB
