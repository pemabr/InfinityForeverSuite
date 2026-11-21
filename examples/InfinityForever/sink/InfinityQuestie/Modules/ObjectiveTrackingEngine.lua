-- ObjectiveTrackingEngine.lua - Track individual quest objectives
-- Part of InfinityQuestie addon suite
-- Monitors progress on objectives like kills, collection, travel, etc.

local ObjectiveTrackingEngine = {}
ObjectiveTrackingEngine.enabled = false
ObjectiveTrackingEngine.db = nil
ObjectiveTrackingEngine.objectives = {}

-- Configuration
ObjectiveTrackingEngine.config = {
    enabled = true,
    update_interval = 1,  -- Check every second
    objective_types = {
        "kill",      -- Kill X of mob
        "collect",   -- Collect X of item
        "explore",   -- Explore location
        "talk",      -- Talk to NPC
        "deliver",   -- Deliver item
        "protect",   -- Protect NPC
        "discover",  -- Discover location
        "complete",  -- Complete other quest
        "use",       -- Use item at location
        "fish",      -- Fish items
    },
}

function ObjectiveTrackingEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.objectives then
        self.db.objectives = {}
    end
    
    self.objectives = self.db.objectives
    self.enabled = true
    
    self:Log("Initialized objective tracking engine")
end

function ObjectiveTrackingEngine:AddObjective(questId, objectiveId, objectiveType, objectiveText, required)
    if not questId or not objectiveId or not objectiveType then
        return false
    end
    
    if not self.objectives[questId] then
        self.objectives[questId] = {}
    end
    
    local objective = {
        id = objectiveId,
        quest_id = questId,
        type = objectiveType,
        text = objectiveText or "Unknown",
        required = required or 1,
        progress = 0,
        completed = false,
        discovered_at = GetTime(),
        completed_at = nil,
    }
    
    table.insert(self.objectives[questId], objective)
    
    return true
end

function ObjectiveTrackingEngine:GetObjectives(questId)
    if not questId or not self.objectives[questId] then
        return {}
    end
    
    return self.objectives[questId]
end

function ObjectiveTrackingEngine:GetObjective(questId, objectiveId)
    if not questId or not self.objectives[questId] then
        return nil
    end
    
    for _, objective in ipairs(self.objectives[questId]) do
        if objective.id == objectiveId then
            return objective
        end
    end
    
    return nil
end

function ObjectiveTrackingEngine:UpdateObjectiveProgress(questId, objectiveId, progress)
    local objective = self:GetObjective(questId, objectiveId)
    if not objective then
        return false
    end
    
    objective.progress = math.min(objective.required, math.max(0, progress or 0))
    
    if objective.progress >= objective.required and not objective.completed then
        objective.completed = true
        objective.completed_at = GetTime()
        self:Log("Completed objective: " .. objective.text)
    end
    
    return true
end

function ObjectiveTrackingEngine:CompleteObjective(questId, objectiveId)
    local objective = self:GetObjective(questId, objectiveId)
    if not objective then
        return false
    end
    
    objective.progress = objective.required
    objective.completed = true
    objective.completed_at = GetTime()
    
    self:Log("Manually completed objective: " .. objective.text)
    
    return true
end

function ObjectiveTrackingEngine:IsObjectiveCompleted(questId, objectiveId)
    local objective = self:GetObjective(questId, objectiveId)
    if not objective then
        return false
    end
    
    return objective.completed
end

function ObjectiveTrackingEngine:GetQuestProgress(questId)
    local objectives = self:GetObjectives(questId)
    if #objectives == 0 then
        return 0
    end
    
    local completed = 0
    
    for _, objective in ipairs(objectives) do
        if objective.completed then
            completed = completed + 1
        end
    end
    
    return math.floor((completed / #objectives) * 100)
end

function ObjectiveTrackingEngine:AreAllObjectivesCompleted(questId)
    local objectives = self:GetObjectives(questId)
    if #objectives == 0 then
        return false
    end
    
    for _, objective in ipairs(objectives) do
        if not objective.completed then
            return false
        end
    end
    
    return true
end

function ObjectiveTrackingEngine:GetObjectivesByType(questId, objectiveType)
    local objectives = self:GetObjectives(questId)
    if #objectives == 0 then
        return {}
    end
    
    local results = {}
    
    for _, objective in ipairs(objectives) do
        if objective.type == objectiveType then
            table.insert(results, objective)
        end
    end
    
    return results
end

function ObjectiveTrackingEngine:GetCompletionTime(questId, objectiveId)
    local objective = self:GetObjective(questId, objectiveId)
    if not objective or not objective.completed_at then
        return 0
    end
    
    return objective.completed_at - objective.discovered_at
end

function ObjectiveTrackingEngine:GetAverageObjectiveTime(questId)
    local objectives = self:GetObjectives(questId)
    if #objectives == 0 then
        return 0
    end
    
    local totalTime = 0
    local completedCount = 0
    
    for _, objective in ipairs(objectives) do
        if objective.completed_at then
            totalTime = totalTime + (objective.completed_at - objective.discovered_at)
            completedCount = completedCount + 1
        end
    end
    
    if completedCount == 0 then
        return 0
    end
    
    return totalTime / completedCount
end

function ObjectiveTrackingEngine:GetObjectiveStats(questId)
    local objectives = self:GetObjectives(questId)
    local completed = 0
    local totalProgress = 0
    
    for _, objective in ipairs(objectives) do
        if objective.completed then
            completed = completed + 1
        end
        
        totalProgress = totalProgress + (objective.progress / objective.required)
    end
    
    return {
        total = #objectives,
        completed = completed,
        progress_percent = #objectives > 0 and math.floor((totalProgress / #objectives) * 100) or 0,
    }
end

function ObjectiveTrackingEngine:ClearObjectives(questId)
    if not questId then
        return false
    end
    
    if self.objectives[questId] then
        self.objectives[questId] = nil
        self:Log("Cleared objectives for quest: " .. questId)
        return true
    end
    
    return false
end

function ObjectiveTrackingEngine:GetStatus()
    local totalObjectives = 0
    
    for _, objectiveList in pairs(self.objectives) do
        totalObjectives = totalObjectives + #objectiveList
    end
    
    return {
        enabled = self.enabled,
        total_objectives = totalObjectives,
        active_quests = table.getn(self.objectives),
    }
end

function ObjectiveTrackingEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ObjectiveTrackingEngine] " .. message)
    else
        print("[ObjectiveTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_OBJECTIVE1 = "/objective"
    SlashCmdList["OBJECTIVE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local questId = tonumber(args)
            if questId then
                local objectives = ObjectiveTrackingEngine:GetObjectives(questId)
                print("Objectives for Quest " .. questId .. ": " .. #objectives)
                for i, obj in ipairs(objectives) do
                    print("  [" .. i .. "] " .. obj.text)
                    print("       Type: " .. obj.type .. " | Progress: " .. obj.progress .. "/" .. obj.required)
                end
            else
                print("Usage: /objective list <questId>")
            end
        elseif cmd == "progress" then
            local questId = tonumber(args)
            if questId then
                local stats = ObjectiveTrackingEngine:GetObjectiveStats(questId)
                print("Quest " .. questId .. " Progress:")
                print("  Total Objectives: " .. stats.total)
                print("  Completed: " .. stats.completed)
                print("  Overall: " .. stats.progress_percent .. "%")
            else
                print("Usage: /objective progress <questId>")
            end
        elseif cmd == "complete" then
            local parts = args:match("(%d+)%s+(%d+)")
            local questId, objectiveId = tonumber(parts:match("(%d+)%s+(%d+)") or "0 0")
            
            if questId and objectiveId then
                ObjectiveTrackingEngine:CompleteObjective(questId, objectiveId)
                print("Objective completed")
            else
                print("Usage: /objective complete <questId> <objectiveId>")
            end
        elseif cmd == "status" then
            local status = ObjectiveTrackingEngine:GetStatus()
            print("Objective Tracking:")
            print("  Total Objectives: " .. status.total_objectives)
            print("  Active Quests: " .. status.active_quests)
        else
            print("Objective Commands:")
            print("  /objective list <questId> - List quest objectives")
            print("  /objective progress <questId> - Show progress")
            print("  /objective complete <questId> <objId> - Complete objective")
            print("  /objective status - Show status")
        end
    end
end

return ObjectiveTrackingEngine
