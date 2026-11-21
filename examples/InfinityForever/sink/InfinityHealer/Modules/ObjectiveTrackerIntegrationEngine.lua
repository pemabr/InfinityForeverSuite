-- ObjectiveTrackerIntegrationEngine.lua - Integrate with quest/objective tracking
-- Part of InfinityHealer addon suite
-- Displays active quests and objectives relevant to current encounter

local ObjectiveTrackerIntegrationEngine = {}
ObjectiveTrackerIntegrationEngine.enabled = false
ObjectiveTrackerIntegrationEngine.db = nil
ObjectiveTrackerIntegrationEngine.objectives = {}

-- Configuration
ObjectiveTrackerIntegrationEngine.config = {
    enabled = true,
    show_quests = true,
    show_achievements = true,
    show_dungeons = true,
    show_world_quests = false,
    update_frequency = 5,  -- Check every 5 seconds
    max_objectives = 10,
}

function ObjectiveTrackerIntegrationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.tracked_objectives then
        self.db.tracked_objectives = {}
    end
    
    if not self.db.objective_completion then
        self.db.objective_completion = {}
    end
    
    self.objectives = self.db.tracked_objectives
    self.enabled = true
    
    self:Log("Initialized with objective tracking enabled")
end

function ObjectiveTrackerIntegrationEngine:GetActiveQuests()
    local quests = {}
    
    if not self.config.show_quests then
        return quests
    end
    
    -- In a real implementation, would query quest log
    -- This is a stub that shows how data would be structured
    
    for i = 1, GetNumQuestLogEntries() do
        local questName, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(i)
        
        if questName and not isHeader and not isComplete then
            table.insert(quests, {
                id = questID,
                name = questName,
                level = level,
                type = "QUEST",
                complete = false,
            })
        end
    end
    
    return quests
end

function ObjectiveTrackerIntegrationEngine:GetCurrentInstanceObjectives()
    local objectives = {}
    
    if not self.config.show_dungeons then
        return objectives
    end
    
    -- Get current instance name
    local instanceName, instanceType = GetInstanceInfo()
    
    if not instanceName then
        return objectives
    end
    
    -- Hardcoded instance objectives (in a real system, would load from database)
    local instanceObjectives = {
        ["Molten Core"] = {
            {name = "Defeat Lucifron", difficulty = "NORMAL"},
            {name = "Defeat Magmadar", difficulty = "NORMAL"},
            {name = "Defeat Gehennas", difficulty = "NORMAL"},
            {name = "Defeat Garr", difficulty = "NORMAL"},
            {name = "Defeat Baron Geddon", difficulty = "NORMAL"},
            {name = "Defeat Shazzrah", difficulty = "NORMAL"},
            {name = "Defeat Sulfuron Harbinger", difficulty = "NORMAL"},
            {name = "Defeat Ragnaros", difficulty = "HARD"},
        },
        ["Blackwing Lair"] = {
            {name = "Defeat Razorgore", difficulty = "NORMAL"},
            {name = "Defeat Vaelastrasz", difficulty = "NORMAL"},
            {name = "Defeat Lashlayer", difficulty = "NORMAL"},
            {name = "Defeat Four Dragons", difficulty = "NORMAL"},
            {name = "Defeat Taerar", difficulty = "NORMAL"},
            {name = "Defeat Ysondre", difficulty = "NORMAL"},
            {name = "Defeat Lethaldrin", difficulty = "NORMAL"},
            {name = "Defeat Nefarian", difficulty = "HARD"},
        },
    }
    
    if instanceObjectives[instanceName] then
        for _, objective in ipairs(instanceObjectives[instanceName]) do
            table.insert(objectives, {
                instance = instanceName,
                name = objective.name,
                difficulty = objective.difficulty,
                type = "BOSS",
                complete = false,
            })
        end
    end
    
    return objectives
end

function ObjectiveTrackerIntegrationEngine:GetTrackedObjectives()
    local tracked = {}
    local quests = self:GetActiveQuests()
    local instanceObjectives = self:GetCurrentInstanceObjectives()
    
    -- Combine all objectives
    for _, quest in ipairs(quests) do
        if #tracked < self.config.max_objectives then
            table.insert(tracked, quest)
        end
    end
    
    for _, objective in ipairs(instanceObjectives) do
        if #tracked < self.config.max_objectives then
            table.insert(tracked, objective)
        end
    end
    
    return tracked
end

function ObjectiveTrackerIntegrationEngine:MarkObjectiveComplete(objectiveName)
    if not objectiveName then
        return false
    end
    
    if not self.db.objective_completion then
        self.db.objective_completion = {}
    end
    
    self.db.objective_completion[objectiveName] = {
        completed_at = GetTime(),
        completed_by = GetPlayerName and GetPlayerName() or "Unknown",
    }
    
    self:Log("Objective marked complete: " .. objectiveName)
    return true
end

function ObjectiveTrackerIntegrationEngine:IsObjectiveComplete(objectiveName)
    if not objectiveName or not self.db.objective_completion then
        return false
    end
    
    return self.db.objective_completion[objectiveName] ~= nil
end

function ObjectiveTrackerIntegrationEngine:GetCompletionStats()
    if not self.db.objective_completion then
        return {total = 0, completed = 0, percentage = 0}
    end
    
    local completedCount = 0
    
    for _ in pairs(self.db.objective_completion) do
        completedCount = completedCount + 1
    end
    
    local tracked = self:GetTrackedObjectives()
    local totalTracked = #tracked
    
    local percentage = 0
    if totalTracked > 0 then
        percentage = math.floor((completedCount / totalTracked) * 100)
    end
    
    return {
        total = totalTracked,
        completed = completedCount,
        percentage = percentage,
    }
end

function ObjectiveTrackerIntegrationEngine:SetShowQuests(show)
    self.config.show_quests = show
    self:Log("Show quests: " .. (show and "ON" or "OFF"))
    return true
end

function ObjectiveTrackerIntegrationEngine:SetShowAchievements(show)
    self.config.show_achievements = show
    self:Log("Show achievements: " .. (show and "ON" or "OFF"))
    return true
end

function ObjectiveTrackerIntegrationEngine:SetShowDungeons(show)
    self.config.show_dungeons = show
    self:Log("Show dungeons: " .. (show and "ON" or "OFF"))
    return true
end

function ObjectiveTrackerIntegrationEngine:ResetCompletion()
    self.db.objective_completion = {}
    self:Log("All objective completion records reset")
    return true
end

function ObjectiveTrackerIntegrationEngine:GetStatus()
    local stats = self:GetCompletionStats()
    
    return {
        enabled = self.enabled,
        show_quests = self.config.show_quests,
        show_achievements = self.config.show_achievements,
        show_dungeons = self.config.show_dungeons,
        tracked_objectives = stats.total,
        completed_objectives = stats.completed,
        completion_percentage = stats.percentage,
    }
end

function ObjectiveTrackerIntegrationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ObjectiveTrackerIntegrationEngine] " .. message)
    else
        print("[ObjectiveTrackerIntegrationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_OBJECTIVES1 = "/objectives"
    SlashCmdList["OBJECTIVES"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local objectives = ObjectiveTrackerIntegrationEngine:GetTrackedObjectives()
            print("Tracked Objectives (" .. #objectives .. "):")
            for i, obj in ipairs(objectives) do
                local status = ObjectiveTrackerIntegrationEngine:IsObjectiveComplete(obj.name) and "[✓]" or "[ ]"
                print("  " .. status .. " " .. obj.name .. " (" .. obj.type .. ")")
            end
        elseif cmd == "mark" then
            if args and args ~= "" then
                ObjectiveTrackerIntegrationEngine:MarkObjectiveComplete(args)
                print("Marked complete: " .. args)
            else
                print("Usage: /objectives mark <name>")
            end
        elseif cmd == "quests" then
            if args == "on" then
                ObjectiveTrackerIntegrationEngine:SetShowQuests(true)
                print("Quest tracking enabled")
            elseif args == "off" then
                ObjectiveTrackerIntegrationEngine:SetShowQuests(false)
                print("Quest tracking disabled")
            else
                print("Usage: /objectives quests <on|off>")
            end
        elseif cmd == "dungeons" then
            if args == "on" then
                ObjectiveTrackerIntegrationEngine:SetShowDungeons(true)
                print("Dungeon tracking enabled")
            elseif args == "off" then
                ObjectiveTrackerIntegrationEngine:SetShowDungeons(false)
                print("Dungeon tracking disabled")
            else
                print("Usage: /objectives dungeons <on|off>")
            end
        elseif cmd == "achievements" then
            if args == "on" then
                ObjectiveTrackerIntegrationEngine:SetShowAchievements(true)
                print("Achievement tracking enabled")
            elseif args == "off" then
                ObjectiveTrackerIntegrationEngine:SetShowAchievements(false)
                print("Achievement tracking disabled")
            else
                print("Usage: /objectives achievements <on|off>")
            end
        elseif cmd == "stats" then
            local stats = ObjectiveTrackerIntegrationEngine:GetCompletionStats()
            print("Objective Progress:")
            print("  Total: " .. stats.total)
            print("  Completed: " .. stats.completed)
            print("  Progress: " .. stats.percentage .. "%")
        elseif cmd == "reset" then
            if args == "confirm" then
                ObjectiveTrackerIntegrationEngine:ResetCompletion()
                print("Completion records reset")
            else
                print("Usage: /objectives reset confirm")
            end
        elseif cmd == "status" then
            local status = ObjectiveTrackerIntegrationEngine:GetStatus()
            print("Objective Tracker Integration:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Objective Tracker Commands:")
            print("  /objectives list - Show tracked objectives")
            print("  /objectives mark <name> - Mark objective complete")
            print("  /objectives quests <on|off> - Toggle quest tracking")
            print("  /objectives dungeons <on|off> - Toggle dungeon tracking")
            print("  /objectives achievements <on|off> - Toggle achievement tracking")
            print("  /objectives stats - Show completion stats")
            print("  /objectives reset confirm - Reset completion records")
            print("  /objectives status - Show system status")
        end
    end
end

return ObjectiveTrackerIntegrationEngine
