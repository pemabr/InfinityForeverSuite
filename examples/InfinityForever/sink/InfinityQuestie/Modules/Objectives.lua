-- Objectives Module
-- Quest objective tracking

local InfinityQuestObjectives = {}
_G.InfinityQuestObjectives = InfinityQuestObjectives

InfinityQuestObjectives.objectives = {}
InfinityQuestObjectives.callbacks = {}

function InfinityQuestObjectives:RegisterObjective(objectiveID, questID, description, type)
    self.objectives[objectiveID] = {
        id = objectiveID,
        questID = questID,
        description = description,
        type = type or "normal",
        progress = 0,
        required = 1,
        completed = false,
    }
end

function InfinityQuestObjectives:UpdateProgress(objectiveID, progress, required)
    local obj = self.objectives[objectiveID]
    if not obj then return false end
    
    obj.progress = progress or obj.progress
    obj.required = required or obj.required
    obj.completed = (obj.progress >= obj.required)
    
    self:TriggerCallback("objective_updated", objectiveID, obj.progress, obj.required)
    return true
end

function InfinityQuestObjectives:GetObjectives(questID)
    local result = {}
    for _, obj in pairs(self.objectives) do
        if obj.questID == questID then
            table.insert(result, obj)
        end
    end
    return result
end

function InfinityQuestObjectives:GetObjectiveText(questID)
    local text = ""
    local objectives = self:GetObjectives(questID)
    
    for _, obj in ipairs(objectives) do
        text = text .. string.format("  - %s (%d/%d)\n", 
            obj.description, obj.progress, obj.required)
    end
    
    return text
end

function InfinityQuestObjectives:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityQuestObjectives:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityQuestObjectives
