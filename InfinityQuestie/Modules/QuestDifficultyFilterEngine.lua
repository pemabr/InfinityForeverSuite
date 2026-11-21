-- QuestDifficultyFilterEngine.lua - Difficulty-based quest filtering and suggestion
-- Part of InfinityQuestie addon suite
-- Handles quest difficulty classification, filtering, and difficulty-based recommendations

local QuestDifficultyFilterEngine = {}
QuestDifficultyFilterEngine.enabled = false
QuestDifficultyFilterEngine.db = nil
QuestDifficultyFilterEngine.difficulty_thresholds = {}
QuestDifficultyFilterEngine.quest_difficulties = {}

-- Configuration
QuestDifficultyFilterEngine.config = {
    enabled = true,
    difficulty_levels = 5,  -- Easy, Normal, Hard, Very Hard, Impossible
    calculate_on_load = true,
}

-- Difficulty levels
QuestDifficultyFilterEngine.difficulty_names = {
    [1] = "Easy",
    [2] = "Normal",
    [3] = "Hard",
    [4] = "Very Hard",
    [5] = "Impossible",
}

function QuestDifficultyFilterEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_difficulties then
        self.db.quest_difficulties = {}
    end
    
    if not self.db.difficulty_thresholds then
        self.db.difficulty_thresholds = {
            easy_max = 5,
            normal_max = 10,
            hard_max = 15,
            very_hard_max = 20,
        }
    end
    
    self.quest_difficulties = self.db.quest_difficulties
    self.difficulty_thresholds = self.db.difficulty_thresholds
    self.enabled = true
    
    self:Log("Initialized difficulty filter engine")
end

function QuestDifficultyFilterEngine:CalculateQuestDifficulty(questData, playerLevel)
    if not questData then
        return nil
    end
    
    if not playerLevel then
        playerLevel = UnitLevel("player") or 1
    end
    
    -- Difficulty calculation based on level difference
    local levelDiff = (questData.level or 1) - playerLevel
    local difficulty = 2  -- Default to Normal
    
    -- Adjust difficulty based on level difference
    if levelDiff <= -10 then
        difficulty = 1  -- Easy
    elseif levelDiff <= -5 then
        difficulty = 1  -- Easy
    elseif levelDiff <= 0 then
        difficulty = 2  -- Normal
    elseif levelDiff <= 5 then
        difficulty = 3  -- Hard
    elseif levelDiff <= 10 then
        difficulty = 4  -- Very Hard
    else
        difficulty = 5  -- Impossible
    end
    
    -- Adjust for enemy count in objectives
    if questData.objectives then
        for _, objective in ipairs(questData.objectives) do
            if objective.type == "kill" and objective.required_count then
                if objective.required_count >= 50 then
                    difficulty = difficulty + 1
                elseif objective.required_count >= 20 then
                    difficulty = difficulty + 0.5
                end
            end
        end
    end
    
    -- Cap difficulty at max level
    difficulty = math.min(difficulty, 5)
    difficulty = math.max(difficulty, 1)
    
    return difficulty
end

function QuestDifficultyFilterEngine:RegisterQuestDifficulty(questId, difficulty)
    if not questId or not difficulty then
        return false
    end
    
    if difficulty < 1 or difficulty > 5 then
        self:Log("Invalid difficulty level: " .. difficulty)
        return false
    end
    
    self.quest_difficulties[questId] = difficulty
    return true
end

function QuestDifficultyFilterEngine:GetQuestDifficulty(questId)
    if not questId then
        return nil
    end
    
    return self.quest_difficulties[questId]
end

function QuestDifficultyFilterEngine:GetDifficultyName(difficulty)
    if not difficulty then
        return "Unknown"
    end
    
    -- Round to nearest integer
    difficulty = math.floor(difficulty + 0.5)
    
    return self.difficulty_names[difficulty] or "Unknown"
end

function QuestDifficultyFilterEngine:FilterQuestsByDifficulty(questList, minDifficulty, maxDifficulty)
    if not questList then
        return {}
    end
    
    minDifficulty = minDifficulty or 1
    maxDifficulty = maxDifficulty or 5
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        local difficulty = self:GetQuestDifficulty(quest.id)
        
        if difficulty then
            if difficulty >= minDifficulty and difficulty <= maxDifficulty then
                table.insert(filtered, quest)
            end
        end
    end
    
    return filtered
end

function QuestDifficultyFilterEngine:GetEasyQuests(questList)
    return self:FilterQuestsByDifficulty(questList, 1, 1)
end

function QuestDifficultyFilterEngine:GetNormalQuests(questList)
    return self:FilterQuestsByDifficulty(questList, 2, 2)
end

function QuestDifficultyFilterEngine:GetHardQuests(questList)
    return self:FilterQuestsByDifficulty(questList, 3, 3)
end

function QuestDifficultyFilterEngine:GetVeryHardQuests(questList)
    return self:FilterQuestsByDifficulty(questList, 4, 4)
end

function QuestDifficultyFilterEngine:GetImpossibleQuests(questList)
    return self:FilterQuestsByDifficulty(questList, 5, 5)
end

function QuestDifficultyFilterEngine:GetRecommendedQuests(questList, playerLevel)
    if not playerLevel then
        playerLevel = UnitLevel("player") or 1
    end
    
    -- Recommended quests are Normal to Hard for the player's level
    return self:FilterQuestsByDifficulty(questList, 2, 3)
end

function QuestDifficultyFilterEngine:GetChallengeQuests(questList, playerLevel)
    if not playerLevel then
        playerLevel = UnitLevel("player") or 1
    end
    
    -- Challenge quests are Hard to Very Hard
    return self:FilterQuestsByDifficulty(questList, 3, 4)
end

function QuestDifficultyFilterEngine:CalculateBulkDifficulties(questList, playerLevel)
    if not questList then
        return 0
    end
    
    if not playerLevel then
        playerLevel = UnitLevel("player") or 1
    end
    
    local calculated = 0
    
    for _, quest in ipairs(questList) do
        if not self:GetQuestDifficulty(quest.id) then
            local difficulty = self:CalculateQuestDifficulty(quest, playerLevel)
            if self:RegisterQuestDifficulty(quest.id, difficulty) then
                calculated = calculated + 1
            end
        end
    end
    
    self:Log("Calculated difficulties for " .. calculated .. " quests")
    return calculated
end

function QuestDifficultyFilterEngine:GetDifficultyDistribution(questList)
    if not questList then
        return {}
    end
    
    local distribution = {
        [1] = 0,  -- Easy
        [2] = 0,  -- Normal
        [3] = 0,  -- Hard
        [4] = 0,  -- Very Hard
        [5] = 0,  -- Impossible
    }
    
    for _, quest in ipairs(questList) do
        local difficulty = self:GetQuestDifficulty(quest.id)
        if difficulty then
            difficulty = math.floor(difficulty + 0.5)
            if distribution[difficulty] then
                distribution[difficulty] = distribution[difficulty] + 1
            end
        end
    end
    
    return distribution
end

function QuestDifficultyFilterEngine:GetDifficultyStats(questList)
    if not questList then
        return nil
    end
    
    local distribution = self:GetDifficultyDistribution(questList)
    local total = #questList
    
    return {
        total = total,
        easy = distribution[1],
        normal = distribution[2],
        hard = distribution[3],
        very_hard = distribution[4],
        impossible = distribution[5],
        easy_percent = (distribution[1] / total * 100),
        normal_percent = (distribution[2] / total * 100),
        hard_percent = (distribution[3] / total * 100),
        very_hard_percent = (distribution[4] / total * 100),
        impossible_percent = (distribution[5] / total * 100),
    }
end

function QuestDifficultyFilterEngine:GetStatus()
    local difficultyCount = table.getn(self.quest_difficulties)
    
    return {
        enabled = self.enabled,
        difficulty_levels = self.config.difficulty_levels,
        cached_difficulties = difficultyCount,
    }
end

function QuestDifficultyFilterEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestDifficultyFilterEngine] " .. message)
    else
        print("[QuestDifficultyFilterEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTDIFF1 = "/questdiff"
    SlashCmdList["QUESTDIFF"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "calc" then
            local questId = tonumber(args)
            if questId then
                local difficulty = QuestDifficultyFilterEngine:GetQuestDifficulty(questId)
                if difficulty then
                    print("Quest " .. questId .. " Difficulty: " .. 
                          QuestDifficultyFilterEngine:GetDifficultyName(difficulty) ..
                          " (" .. string.format("%.1f", difficulty) .. ")")
                else
                    print("No difficulty calculated for quest: " .. questId)
                end
            else
                print("Usage: /questdiff calc <questId>")
            end
        elseif cmd == "set" then
            local questId, diff = args:match("^(%d+)%s+(%d+)$")
            if questId and diff then
                questId = tonumber(questId)
                diff = tonumber(diff)
                if QuestDifficultyFilterEngine:RegisterQuestDifficulty(questId, diff) then
                    print("Set difficulty for quest " .. questId .. " to " .. diff)
                else
                    print("Invalid difficulty level: " .. diff)
                end
            else
                print("Usage: /questdiff set <questId> <difficulty>")
            end
        elseif cmd == "levels" then
            print("Difficulty Levels:")
            for i = 1, 5 do
                print("  " .. i .. ": " .. QuestDifficultyFilterEngine:GetDifficultyName(i))
            end
        elseif cmd == "status" then
            local status = QuestDifficultyFilterEngine:GetStatus()
            print("Difficulty Filter Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Difficulty Levels: " .. status.difficulty_levels)
            print("  Cached Difficulties: " .. status.cached_difficulties)
        else
            print("Quest Difficulty Commands:")
            print("  /questdiff calc <questId> - Calculate difficulty for quest")
            print("  /questdiff set <questId> <level> - Set difficulty level (1-5)")
            print("  /questdiff levels - Show difficulty levels")
            print("  /questdiff status - Show engine status")
        end
    end
end

return QuestDifficultyFilterEngine
