-- QuestDatabaseEngine.lua - Quest data storage and lookup
-- Part of PluribusQuestie addon suite
-- Stores and indexes all quest information for fast lookups

local QuestDatabaseEngine = {}
QuestDatabaseEngine.enabled = false
QuestDatabaseEngine.db = nil
QuestDatabaseEngine.quests = {}
QuestDatabaseEngine.quest_index = {}  -- Fast lookup by quest ID

-- Configuration
QuestDatabaseEngine.config = {
    enabled = true,
    max_quests = 5000,
}

function QuestDatabaseEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quests then
        self.db.quests = {}
    end
    
    if not self.db.quest_index then
        self.db.quest_index = {}
    end
    
    self.quests = self.db.quests
    self.quest_index = self.db.quest_index
    self.enabled = true
    
    self:Log("Initialized quest database engine")
end

function QuestDatabaseEngine:AddQuest(questId, questName, questLevel, questZone, questGiver)
    if not questId or not questName then
        return false
    end
    
    if #self.quests >= self.config.max_quests then
        self:Log("Max quests reached (" .. self.config.max_quests .. ")")
        return false
    end
    
    local quest = {
        id = questId,
        name = questName,
        level = questLevel or 1,
        zone = questZone or "Unknown",
        giver = questGiver or "Unknown",
        objectives = {},
        rewards = {},
        prerequisites = {},
        added_at = GetTime(),
    }
    
    table.insert(self.quests, quest)
    self.quest_index[questId] = quest
    
    return true
end

function QuestDatabaseEngine:GetQuest(questId)
    if not questId then
        return nil
    end
    
    return self.quest_index[questId]
end

function QuestDatabaseEngine:GetQuestByName(questName)
    if not questName then
        return nil
    end
    
    for _, quest in ipairs(self.quests) do
        if quest.name == questName then
            return quest
        end
    end
    
    return nil
end

function QuestDatabaseEngine:GetQuestsByZone(zoneName)
    if not zoneName then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(self.quests) do
        if quest.zone == zoneName then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestDatabaseEngine:GetQuestsByLevel(minLevel, maxLevel)
    if not minLevel then
        minLevel = 1
    end
    
    if not maxLevel then
        maxLevel = 120
    end
    
    local results = {}
    
    for _, quest in ipairs(self.quests) do
        if quest.level >= minLevel and quest.level <= maxLevel then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestDatabaseEngine:AddObjective(questId, objectiveType, objectiveData)
    local quest = self:GetQuest(questId)
    if not quest then
        return false
    end
    
    local objective = {
        type = objectiveType,  -- kill, collect, explore, talk, etc.
        data = objectiveData or {},
        progress = 0,
        required = objectiveData.required or 1,
    }
    
    table.insert(quest.objectives, objective)
    
    return true
end

function QuestDatabaseEngine:GetObjectives(questId)
    local quest = self:GetQuest(questId)
    if not quest then
        return {}
    end
    
    return quest.objectives
end

function QuestDatabaseEngine:AddReward(questId, rewardType, rewardData)
    local quest = self:GetQuest(questId)
    if not quest then
        return false
    end
    
    local reward = {
        type = rewardType,  -- item, experience, money, honor, etc.
        data = rewardData or {},
    }
    
    table.insert(quest.rewards, reward)
    
    return true
end

function QuestDatabaseEngine:GetRewards(questId)
    local quest = self:GetQuest(questId)
    if not quest then
        return {}
    end
    
    return quest.rewards
end

function QuestDatabaseEngine:AddPrerequisite(questId, prerequisiteQuestId)
    local quest = self:GetQuest(questId)
    if not quest then
        return false
    end
    
    table.insert(quest.prerequisites, prerequisiteQuestId)
    
    return true
end

function QuestDatabaseEngine:GetPrerequisites(questId)
    local quest = self:GetQuest(questId)
    if not quest then
        return {}
    end
    
    return quest.prerequisites
end

function QuestDatabaseEngine:CanStartQuest(questId, playerLevel, completedQuests)
    local quest = self:GetQuest(questId)
    if not quest then
        return false, "Quest not found"
    end
    
    -- Check level requirement
    if playerLevel < quest.level then
        return false, "Level too low"
    end
    
    -- Check prerequisites
    for _, prerequisiteId in ipairs(quest.prerequisites) do
        local hasPrerequisite = false
        
        for _, completedId in ipairs(completedQuests or {}) do
            if completedId == prerequisiteId then
                hasPrerequisite = true
                break
            end
        end
        
        if not hasPrerequisite then
            return false, "Prerequisite quest not completed"
        end
    end
    
    return true, "Quest available"
end

function QuestDatabaseEngine:SearchQuests(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end
    
    local results = {}
    local lowerSearch = searchTerm:lower()
    
    for _, quest in ipairs(self.quests) do
        if quest.name:lower():find(lowerSearch) or
           quest.zone:lower():find(lowerSearch) or
           quest.giver:lower():find(lowerSearch) then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestDatabaseEngine:GetQuestCount()
    return #self.quests
end

function QuestDatabaseEngine:GetQuestCountByZone()
    local counts = {}
    
    for _, quest in ipairs(self.quests) do
        if not counts[quest.zone] then
            counts[quest.zone] = 0
        end
        counts[quest.zone] = counts[quest.zone] + 1
    end
    
    return counts
end

function QuestDatabaseEngine:ExportQuestData(questId)
    local quest = self:GetQuest(questId)
    if not quest then
        return nil
    end
    
    return {
        id = quest.id,
        name = quest.name,
        level = quest.level,
        zone = quest.zone,
        giver = quest.giver,
        objectives = quest.objectives,
        rewards = quest.rewards,
        prerequisites = quest.prerequisites,
    }
end

function QuestDatabaseEngine:GetStatus()
    local counts = self:GetQuestCountByZone()
    
    return {
        enabled = self.enabled,
        total_quests = #self.quests,
        max_quests = self.config.max_quests,
        zones = table.getn(counts),
    }
end

function QuestDatabaseEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestDatabaseEngine] " .. message)
    else
        print("[QuestDatabaseEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTDB1 = "/questdb"
    SlashCmdList["QUESTDB"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "search" then
            local results = QuestDatabaseEngine:SearchQuests(args)
            print("Quest Search Results: " .. #results .. " found")
            for i, quest in ipairs(results) do
                if i <= 10 then  -- Show first 10
                    print("  [" .. quest.id .. "] " .. quest.name .. " (Level " .. quest.level .. ")")
                end
            end
        elseif cmd == "zone" then
            local quests = QuestDatabaseEngine:GetQuestsByZone(args)
            print("Quests in " .. args .. ": " .. #quests)
            for i, quest in ipairs(quests) do
                if i <= 10 then
                    print("  [" .. quest.id .. "] " .. quest.name)
                end
            end
        elseif cmd == "level" then
            local minLevel, maxLevel = args:match("(%d+)%s+(%d+)")
            minLevel = tonumber(minLevel) or 1
            maxLevel = tonumber(maxLevel) or 120
            
            local quests = QuestDatabaseEngine:GetQuestsByLevel(minLevel, maxLevel)
            print("Quests Level " .. minLevel .. "-" .. maxLevel .. ": " .. #quests)
        elseif cmd == "zones" then
            local counts = QuestDatabaseEngine:GetQuestCountByZone()
            print("Quests by Zone:")
            for zone, count in pairs(counts) do
                print("  " .. zone .. ": " .. count)
            end
        elseif cmd == "status" then
            local status = QuestDatabaseEngine:GetStatus()
            print("Quest Database:")
            print("  Total Quests: " .. status.total_quests .. "/" .. status.max_quests)
            print("  Zones: " .. status.zones)
        else
            print("Quest Database Commands:")
            print("  /questdb search <term> - Search quests")
            print("  /questdb zone <zone> - Quests in zone")
            print("  /questdb level <min> <max> - Quests by level")
            print("  /questdb zones - List all zones")
            print("  /questdb status - Show status")
        end
    end
end

return QuestDatabaseEngine
