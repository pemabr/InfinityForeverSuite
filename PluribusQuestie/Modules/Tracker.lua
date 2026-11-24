-- Tracker Module
-- Track accepted and completed quests

local PluribusQuestTracker = {}
_G.PluribusQuestTracker = PluribusQuestTracker

PluribusQuestTracker.active_quests = {}
PluribusQuestTracker.completed_quests = {}
PluribusQuestTracker.abandoned_quests = {}
PluribusQuestTracker.callbacks = {}

function PluribusQuestTracker:AcceptQuest(questID, questName, questLevel, zone, objectives)
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

function PluribusQuestTracker:RegisterQuest(questID, data)
    if not questID or type(data) ~= "table" then return false end
    self.registered_quests = self.registered_quests or {}
    self.registered_quests[questID] = data
    if _G.PluribusQuestDB and _G.PluribusQuestDB.AddQuest then
        pcall(function() _G.PluribusQuestDB:AddQuest(questID, data) end)
    end
    return true
end

function PluribusQuestTracker:CompleteQuest(questID, questName)
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

function PluribusQuestTracker:AbandonQuest(questID)
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

function PluribusQuestTracker:GetActiveQuests()
    return self.active_quests
end

function PluribusQuestTracker:GetCompletedQuests()
    return self.completed_quests
end

function PluribusQuestTracker:GetQuestStatus(questID)
    if self.active_quests[questID] then
        return "active"
    elseif self.completed_quests[questID] then
        return "completed"
    elseif self.abandoned_quests[questID] then
        return "abandoned"
    end
    return "unknown"
end

function PluribusQuestTracker:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusQuestTracker:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusQuestTracker
