-- QuestTrackingEngine.lua - Track player's quest progress
-- Part of InfinityQuestie addon suite
-- Tracks available, active, and completed quests

local QuestTrackingEngine = {}
QuestTrackingEngine.enabled = false
QuestTrackingEngine.db = nil
QuestTrackingEngine.active_quests = {}
QuestTrackingEngine.completed_quests = {}
QuestTrackingEngine.abandoned_quests = {}

-- Configuration
QuestTrackingEngine.config = {
    enabled = true,
    max_active = 25,  -- WoW limit
    update_interval = 5,  -- Check every 5 seconds
}

function QuestTrackingEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.active_quests then
        self.db.active_quests = {}
    end
    
    if not self.db.completed_quests then
        self.db.completed_quests = {}
    end
    
    if not self.db.abandoned_quests then
        self.db.abandoned_quests = {}
    end
    
    self.active_quests = self.db.active_quests
    self.completed_quests = self.db.completed_quests
    self.abandoned_quests = self.db.abandoned_quests
    self.enabled = true
    
    self:Log("Initialized quest tracking engine")
end

function QuestTrackingEngine:AddActiveQuest(questId, questName, objectives)
    if not questId or not questName then
        return false
    end
    
    if #self.active_quests >= self.config.max_active then
        self:Log("Max active quests reached (" .. self.config.max_active .. ")")
        return false
    end
    
    -- Check if already active
    if self:IsQuestActive(questId) then
        return false
    end
    
    local quest = {
        id = questId,
        name = questName,
        started_at = GetTime(),
        objectives = objectives or {},
        progress = 0,  -- Percentage
        is_active = true,
    }
    
    table.insert(self.active_quests, quest)
    self:Log("Added active quest: " .. questName .. " (ID: " .. questId .. ")")
    
    return true
end

function QuestTrackingEngine:IsQuestActive(questId)
    for _, quest in ipairs(self.active_quests) do
        if quest.id == questId then
            return true
        end
    end
    
    return false
end

function QuestTrackingEngine:GetActiveQuest(questId)
    for _, quest in ipairs(self.active_quests) do
        if quest.id == questId then
            return quest
        end
    end
    
    return nil
end

function QuestTrackingEngine:GetAllActiveQuests()
    return self.active_quests
end

function QuestTrackingEngine:UpdateQuestProgress(questId, progress)
    local quest = self:GetActiveQuest(questId)
    if not quest then
        return false
    end
    
    quest.progress = math.min(100, math.max(0, progress or 0))
    
    return true
end

function QuestTrackingEngine:UpdateObjectiveProgress(questId, objectiveIndex, progress, required)
    local quest = self:GetActiveQuest(questId)
    if not quest then
        return false
    end
    
    if not quest.objectives[objectiveIndex] then
        return false
    end
    
    quest.objectives[objectiveIndex].progress = progress or 0
    quest.objectives[objectiveIndex].required = required or 1
    
    return true
end

function QuestTrackingEngine:CompleteQuest(questId)
    local questIndex = nil
    
    for i, quest in ipairs(self.active_quests) do
        if quest.id == questId then
            questIndex = i
            break
        end
    end
    
    if not questIndex then
        return false
    end
    
    local quest = self.active_quests[questIndex]
    
    table.insert(self.completed_quests, {
        id = quest.id,
        name = quest.name,
        started_at = quest.started_at,
        completed_at = GetTime(),
        duration = GetTime() - quest.started_at,
    })
    
    table.remove(self.active_quests, questIndex)
    
    self:Log("Completed quest: " .. quest.name .. " (ID: " .. questId .. ")")
    
    return true
end

function QuestTrackingEngine:AbandonQuest(questId)
    local questIndex = nil
    
    for i, quest in ipairs(self.active_quests) do
        if quest.id == questId then
            questIndex = i
            break
        end
    end
    
    if not questIndex then
        return false
    end
    
    local quest = self.active_quests[questIndex]
    
    table.insert(self.abandoned_quests, {
        id = quest.id,
        name = quest.name,
        abandoned_at = GetTime(),
        progress = quest.progress,
    })
    
    table.remove(self.active_quests, questIndex)
    
    self:Log("Abandoned quest: " .. quest.name .. " (ID: " .. questId .. ")")
    
    return true
end

function QuestTrackingEngine:IsQuestCompleted(questId)
    for _, quest in ipairs(self.completed_quests) do
        if quest.id == questId then
            return true
        end
    end
    
    return false
end

function QuestTrackingEngine:GetCompletedQuestCount()
    return #self.completed_quests
end

function QuestTrackingEngine:GetAbandonedQuestCount()
    return #self.abandoned_quests
end

function QuestTrackingEngine:GetActiveQuestCount()
    return #self.active_quests
end

function QuestTrackingEngine:GetAverageQuestDuration()
    if #self.completed_quests == 0 then
        return 0
    end
    
    local totalDuration = 0
    
    for _, quest in ipairs(self.completed_quests) do
        totalDuration = totalDuration + quest.duration
    end
    
    return totalDuration / #self.completed_quests
end

function QuestTrackingEngine:GetQuestsByZone(zoneName)
    if not zoneName then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(self.active_quests) do
        if quest.zone == zoneName then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestTrackingEngine:ClearCompletedQuests(daysOld)
    daysOld = daysOld or 7
    local cutoffTime = GetTime() - (daysOld * 86400)
    local newCompleted = {}
    
    for _, quest in ipairs(self.completed_quests) do
        if quest.completed_at > cutoffTime then
            table.insert(newCompleted, quest)
        end
    end
    
    self.completed_quests = newCompleted
    self.db.completed_quests = newCompleted
    
    self:Log("Cleared completed quests older than " .. daysOld .. " days")
end

function QuestTrackingEngine:GetStatus()
    return {
        enabled = self.enabled,
        active_quests = #self.active_quests,
        completed_quests = #self.completed_quests,
        abandoned_quests = #self.abandoned_quests,
        max_active = self.config.max_active,
    }
end

function QuestTrackingEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestTrackingEngine] " .. message)
    else
        print("[QuestTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTTRACK1 = "/questtrack"
    SlashCmdList["QUESTTRACK"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local quests = QuestTrackingEngine:GetAllActiveQuests()
            print("Active Quests: " .. #quests .. "/" .. QuestTrackingEngine.config.max_active)
            for i, quest in ipairs(quests) do
                print("  [" .. i .. "] " .. quest.name .. " (" .. quest.progress .. "%)")
            end
        elseif cmd == "completed" then
            local count = QuestTrackingEngine:GetCompletedQuestCount()
            print("Completed Quests: " .. count)
            if count > 0 then
                local avg = QuestTrackingEngine:GetAverageQuestDuration()
                print("  Average Duration: " .. string.format("%.1f", avg / 60) .. " minutes")
            end
        elseif cmd == "abandoned" then
            local count = QuestTrackingEngine:GetAbandonedQuestCount()
            print("Abandoned Quests: " .. count)
        elseif cmd == "complete" then
            local questId = tonumber(args)
            if questId then
                QuestTrackingEngine:CompleteQuest(questId)
                print("Quest completed: ID " .. questId)
            end
        elseif cmd == "abandon" then
            local questId = tonumber(args)
            if questId then
                QuestTrackingEngine:AbandonQuest(questId)
                print("Quest abandoned: ID " .. questId)
            end
        elseif cmd == "status" then
            local status = QuestTrackingEngine:GetStatus()
            print("Quest Tracking:")
            print("  Active: " .. status.active_quests .. "/" .. status.max_active)
            print("  Completed: " .. status.completed_quests)
            print("  Abandoned: " .. status.abandoned_quests)
        else
            print("Quest Tracking Commands:")
            print("  /questtrack list - List active quests")
            print("  /questtrack completed - Show completed count")
            print("  /questtrack abandoned - Show abandoned count")
            print("  /questtrack complete <id> - Mark quest complete")
            print("  /questtrack abandon <id> - Abandon quest")
            print("  /questtrack status - Show status")
        end
    end
end

return QuestTrackingEngine
