-- Tracker Module
-- Track accepted and completed quests

local InfinityQuestTracker = {}
_G.InfinityQuestTracker = InfinityQuestTracker

InfinityQuestTracker.active_quests = {}
InfinityQuestTracker.completed_quests = {}
InfinityQuestTracker.abandoned_quests = {}
InfinityQuestTracker.callbacks = {}

function InfinityQuestTracker:SyncQuestLog(quests)
    if type(quests) ~= "table" then return false end
    local active = {}
    for _, entry in ipairs(quests) do
        local quest = self.active_quests[entry.id] or { id = entry.id }
        quest.name = entry.title
        quest.objectives = entry.objectives
        active[entry.id] = quest
    end
    self.active_quests = active
    return true
end

function InfinityQuestTracker:AcceptQuest(questID, questName)
    if self.active_quests[questID] then return false end
    
    self.active_quests[questID] = {
        id = questID,
        name = questName or "Unknown",
        accepted_time = GetTime(),
        progress = 0,
    }
    
    self:TriggerCallback("quest_accepted", questID, questName)
    return true
end

function InfinityQuestTracker:CompleteQuest(questID, questName)
    if not self.active_quests[questID] then return false end
    
    local quest = self.active_quests[questID]
    self.completed_quests[questID] = {
        id = questID,
        name = questName or quest.name,
        completed_time = GetTime(),
        duration = quest.accepted_time and (GetTime() - quest.accepted_time) or nil,
    }
    
    self.active_quests[questID] = nil
    self:TriggerCallback("quest_completed", questID, questName)
    return true
end

function InfinityQuestTracker:AbandonQuest(questID)
    if not self.active_quests[questID] then return false end
    
    local quest = self.active_quests[questID]
    self.abandoned_quests[questID] = {
        id = questID,
        name = quest.name,
        abandoned_time = GetTime(),
    }
    
    self.active_quests[questID] = nil
    self:TriggerCallback("quest_abandoned", questID)
    return true
end

function InfinityQuestTracker:GetActiveQuests()
    return self.active_quests
end

function InfinityQuestTracker:GetCompletedQuests()
    return self.completed_quests
end

function InfinityQuestTracker:GetQuestStatus(questID)
    if self.active_quests[questID] then
        return "active"
    elseif self.completed_quests[questID] then
        return "completed"
    elseif self.abandoned_quests[questID] then
        return "abandoned"
    end
    return "unknown"
end

function InfinityQuestTracker:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityQuestTracker:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityQuestTracker
