-- QuestAchievementIntegrationEngine.lua - Quest and achievement integration
-- Part of InfinityQuestie addon suite
-- Links quests to achievements and provides achievement-based quest filtering

local QuestAchievementIntegrationEngine = {}
QuestAchievementIntegrationEngine.enabled = false
QuestAchievementIntegrationEngine.db = nil
QuestAchievementIntegrationEngine.quest_achievement_map = {}
QuestAchievementIntegrationEngine.achievement_data = {}

-- Configuration
QuestAchievementIntegrationEngine.config = {
    enabled = true,
    cache_achievements = true,
}

function QuestAchievementIntegrationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_achievement_map then
        self.db.quest_achievement_map = {}
    end
    
    if not self.db.achievement_data then
        self.db.achievement_data = {}
    end
    
    self.quest_achievement_map = self.db.quest_achievement_map
    self.achievement_data = self.db.achievement_data
    self.enabled = true
    
    self:Log("Initialized quest achievement integration engine")
end

function QuestAchievementIntegrationEngine:LinkQuestToAchievement(questId, achievementId, description)
    if not questId or not achievementId then
        return false
    end
    
    if not self.quest_achievement_map[questId] then
        self.quest_achievement_map[questId] = {}
    end
    
    table.insert(self.quest_achievement_map[questId], {
        achievement_id = achievementId,
        description = description,
        linked_at = GetTime(),
    })
    
    self:Log("Linked quest " .. questId .. " to achievement " .. achievementId)
    return true
end

function QuestAchievementIntegrationEngine:GetQuestAchievements(questId)
    if not questId then
        return {}
    end
    
    if not self.quest_achievement_map[questId] then
        return {}
    end
    
    return self.quest_achievement_map[questId]
end

function QuestAchievementIntegrationEngine:GetAchievementQuests(achievementId)
    if not achievementId then
        return {}
    end
    
    local quests = {}
    
    for questId, achievements in pairs(self.quest_achievement_map) do
        for _, achievement in ipairs(achievements) do
            if achievement.achievement_id == achievementId then
                table.insert(quests, questId)
            end
        end
    end
    
    return quests
end

function QuestAchievementIntegrationEngine:IsQuestForAchievement(questId, achievementId)
    if not questId or not achievementId then
        return false
    end
    
    if not self.quest_achievement_map[questId] then
        return false
    end
    
    for _, achievement in ipairs(self.quest_achievement_map[questId]) do
        if achievement.achievement_id == achievementId then
            return true
        end
    end
    
    return false
end

function QuestAchievementIntegrationEngine:GetAchievementData(achievementId)
    if not achievementId then
        return nil
    end
    
    if self.achievement_data[achievementId] then
        return self.achievement_data[achievementId]
    end
    
    return nil
end

function QuestAchievementIntegrationEngine:RegisterAchievementData(achievementId, data)
    if not achievementId or not data then
        return false
    end
    
    self.achievement_data[achievementId] = {
        id = achievementId,
        name = data.name or "Achievement " .. achievementId,
        description = data.description,
        category = data.category,
        points = data.points or 0,
        quests = data.quests or {},
        registered_at = GetTime(),
    }
    
    self:Log("Registered achievement " .. achievementId)
    return true
end

function QuestAchievementIntegrationEngine:GetQuestProgressToAchievement(questId, achievementId)
    if not questId or not achievementId then
        return 0
    end
    
    local achievements = self:GetQuestAchievements(questId)
    if #achievements == 0 then
        return 0
    end
    
    local progress = 0
    
    for _, achievement in ipairs(achievements) do
        if achievement.achievement_id == achievementId then
            progress = progress + 1
        end
    end
    
    return progress
end

function QuestAchievementIntegrationEngine:GetAchievementCompletionPercentage(achievementId)
    if not achievementId then
        return 0
    end
    
    local quests = self:GetAchievementQuests(achievementId)
    if #quests == 0 then
        return 0
    end
    
    local completed = 0
    for _, q in ipairs(quests) do
        local qid = type(q) == "table" and (q.id or q.quest_id) or q
        if qid then
            local done = false
            if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                local ok, res = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid)
                done = ok and res == true
            elseif IsQuestFlaggedCompleted then
                local ok, res = pcall(IsQuestFlaggedCompleted, qid)
                done = ok and res == true
            end
            if done then completed = completed + 1 end
        end
    end
    
    return (completed / #quests) * 100
end

function QuestAchievementIntegrationEngine:FilterQuestsByAchievementCategory(questList, category)
    if not questList or not category then
        return {}
    end
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        local achievements = self:GetQuestAchievements(quest.id)
        
        for _, achievement in ipairs(achievements) do
            local achData = self:GetAchievementData(achievement.achievement_id)
            
            if achData and achData.category == category then
                table.insert(filtered, quest)
                break
            end
        end
    end
    
    return filtered
end

function QuestAchievementIntegrationEngine:GetStatus()
    local linkedCount = 0
    
    for _, achievements in pairs(self.quest_achievement_map) do
        linkedCount = linkedCount + #achievements
    end
    
    return {
        enabled = self.enabled,
        total_linked = linkedCount,
        total_achievements = table.getn(self.achievement_data),
        quests_with_achievements = table.getn(self.quest_achievement_map),
    }
end

function QuestAchievementIntegrationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestAchievementIntegrationEngine] " .. message)
    else
        print("[QuestAchievementIntegrationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTACH1 = "/questach"
    SlashCmdList["QUESTACH"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "link" then
            local questId, achId = args:match("^(%d+)%s+(%d+)$")
            if questId and achId then
                questId = tonumber(questId)
                achId = tonumber(achId)
                if QuestAchievementIntegrationEngine:LinkQuestToAchievement(questId, achId) then
                    print("Linked quest " .. questId .. " to achievement " .. achId)
                else
                    print("Failed to link quest and achievement")
                end
            else
                print("Usage: /questach link <questId> <achievementId>")
            end
        elseif cmd == "achievements" then
            local questId = tonumber(args)
            if questId then
                local achievements = QuestAchievementIntegrationEngine:GetQuestAchievements(questId)
                print("Achievements for quest " .. questId .. ":")
                if #achievements > 0 then
                    for i, achievement in ipairs(achievements) do
                        print("  [" .. i .. "] Achievement " .. achievement.achievement_id)
                    end
                else
                    print("  No achievements")
                end
            else
                print("Usage: /questach achievements <questId>")
            end
        elseif cmd == "quests" then
            local achId = tonumber(args)
            if achId then
                local quests = QuestAchievementIntegrationEngine:GetAchievementQuests(achId)
                print("Quests for achievement " .. achId .. ":")
                if #quests > 0 then
                    for i, questId in ipairs(quests) do
                        print("  [" .. i .. "] Quest " .. questId)
                    end
                else
                    print("  No quests")
                end
            else
                print("Usage: /questach quests <achievementId>")
            end
        elseif cmd == "status" then
            local status = QuestAchievementIntegrationEngine:GetStatus()
            print("Quest Achievement Integration Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Linked: " .. status.total_linked)
            print("  Total Achievements: " .. status.total_achievements)
            print("  Quests with Achievements: " .. status.quests_with_achievements)
        else
            print("Quest Achievement Commands:")
            print("  /questach link <questId> <achId> - Link quest to achievement")
            print("  /questach achievements <questId> - Show achievements for quest")
            print("  /questach quests <achId> - Show quests for achievement")
            print("  /questach status - Show engine status")
        end
    end
end

return QuestAchievementIntegrationEngine
