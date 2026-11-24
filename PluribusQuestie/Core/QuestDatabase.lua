-- Quest Database
-- Quest information and metadata

local PluribusQuestDB = {}
_G.PluribusQuestDB = PluribusQuestDB

PluribusQuestDB.quests = {}
PluribusQuestDB.callbacks = {}

function PluribusQuestDB:RegisterQuest(questID, data)
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

function PluribusQuestDB:GetQuest(questID)
    return self.quests[questID]
end

function PluribusQuestDB:GetQuestsByZone(zone)
    local result = {}
    for questID, quest in pairs(self.quests) do
        if quest.zone == zone then
            table.insert(result, quest)
        end
    end
    return result
end

function PluribusQuestDB:GetQuestsByLevel(minLevel, maxLevel)
    local result = {}
    for questID, quest in pairs(self.quests) do
        if quest.level >= minLevel and quest.level <= maxLevel then
            table.insert(result, quest)
        end
    end
    return result
end

function PluribusQuestDB:SearchQuests(searchTerm)
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

function PluribusQuestDB:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusQuestDB:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusQuestDB
