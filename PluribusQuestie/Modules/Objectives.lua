-- Objectives Module
-- Quest objective tracking

local PluribusQuestObjectives = {}
_G.PluribusQuestObjectives = PluribusQuestObjectives

PluribusQuestObjectives.objectives = {}
PluribusQuestObjectives.callbacks = {}

function PluribusQuestObjectives:RegisterObjective(objectiveID, questID, description, type)
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

function PluribusQuestObjectives:UpdateProgress(objectiveID, progress, required)
    local obj = self.objectives[objectiveID]
    if not obj then return false end
    
    obj.progress = progress or obj.progress
    obj.required = required or obj.required
    obj.completed = (obj.progress >= obj.required)
    
    self:TriggerCallback("objective_updated", objectiveID, obj.progress, obj.required)
    return true
end

function PluribusQuestObjectives:GetObjectives(questID)
    local result = {}
    for _, obj in pairs(self.objectives) do
        if obj.questID == questID then
            table.insert(result, obj)
        end
    end
    return result
end

function PluribusQuestObjectives:GetObjectiveText(questID)
    local text = ""
    local objectives = self:GetObjectives(questID)
    
    for _, obj in ipairs(objectives) do
        text = text .. string.format("  - %s (%d/%d)\n", 
            obj.description, obj.progress, obj.required)
    end
    
    return text
end

function PluribusQuestObjectives:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusQuestObjectives:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusQuestObjectives
