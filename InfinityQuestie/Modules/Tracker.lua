-- Tracker Module
-- Track accepted and completed quests

local InfinityQuestTracker = {}
_G.InfinityQuestTracker = InfinityQuestTracker

InfinityQuestTracker.active_quests = {}
InfinityQuestTracker.completed_quests = {}
InfinityQuestTracker.abandoned_quests = {}
InfinityQuestTracker.callbacks = {}

function InfinityQuestTracker:AcceptQuest(questID, questName, questLevel, zone, objectives)
    if not questID then return false end
    local existing = self.active_quests[questID]
    if existing then
        if questName and questName ~= "" then existing.name = questName end
        if questLevel and questLevel > 0 then existing.level = questLevel end
        if zone and zone ~= "" then existing.zone = zone end
        if objectives then existing.objectives = objectives end
        return false
    end
    
    self.active_quests[questID] = {
        id = questID,
        name = questName or ("Quest #" .. tostring(questID)),
        level = questLevel or 0,
        zone = zone or (GetRealZoneText and GetRealZoneText()) or "Azeroth",
        objectives = objectives or {},
        accepted_time = GetTime(),
        progress = 0,
    }
    
    self:TriggerCallback("quest_accepted", questID, questName)
    return true
end

function InfinityQuestTracker:RegisterQuest(questID, data)
    if not questID or type(data) ~= "table" then return false end
    self.registered_quests = self.registered_quests or {}
    self.registered_quests[questID] = data
    if _G.InfinityQuestDB and _G.InfinityQuestDB.AddQuest then
        pcall(function() _G.InfinityQuestDB:AddQuest(questID, data) end)
    end
    return true
end

function InfinityQuestTracker:CompleteQuest(questID, questName)
    if not self.active_quests[questID] then return false end
    
    local quest = self.active_quests[questID]
    self.completed_quests[questID] = {
        id = questID,
        name = questName or quest.name,
        completed_time = GetTime(),
        duration = GetTime() - quest.accepted_time,
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
