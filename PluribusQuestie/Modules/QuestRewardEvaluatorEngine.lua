-- QuestRewardEvaluatorEngine.lua - Evaluate and prioritize quest rewards
-- Part of PluribusQuestie addon suite
-- Analyzes quest rewards and prioritizes based on character needs

local QuestRewardEvaluatorEngine = {}
QuestRewardEvaluatorEngine.enabled = false
QuestRewardEvaluatorEngine.db = nil
QuestRewardEvaluatorEngine.reward_evaluations = {}
QuestRewardEvaluatorEngine.preference_weights = {}

-- Configuration
QuestRewardEvaluatorEngine.config = {
    enabled = true,
    evaluate_gold = true,
    evaluate_experience = true,
    evaluate_items = true,
    evaluate_reputation = true,
}

-- Reward type weights
QuestRewardEvaluatorEngine.reward_weights = {
    gold = 0.1,
    experience = 0.2,
    item = 0.3,
    reputation = 0.2,
    achievement = 0.15,
    mount = 0.4,
    pet = 0.35,
}

-- Item slot priorities
QuestRewardEvaluatorEngine.slot_priorities = {
    head = 10,
    neck = 8,
    shoulder = 10,
    chest = 11,
    waist = 9,
    leg = 10,
    feet = 9,
    wrist = 7,
    hands = 10,
    finger = 6,
    trinket = 8,
    back = 7,
    main_hand = 11,
    off_hand = 10,
    two_hand = 11,
    ranged = 10,
}

function QuestRewardEvaluatorEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.reward_evaluations then
        self.db.reward_evaluations = {}
    end
    
    if not self.db.preference_weights then
        self.db.preference_weights = {}
    end
    
    self.reward_evaluations = self.db.reward_evaluations
    self.preference_weights = self.db.preference_weights
    self.enabled = true
    
    self:Log("Initialized reward evaluator engine")
end

function QuestRewardEvaluatorEngine:EvaluateQuestReward(questId, rewards)
    if not questId or not rewards then
        return nil
    end
    
    local evaluation = {
        quest_id = tonumber(questId),
        timestamp = GetTime(),
        total_score = 0,
        component_scores = {},
        priority = "medium",
        analysis = {},
    }
    
    -- Evaluate gold
    if rewards.gold then
        local goldScore = math.min((rewards.gold / 1000), 10) * self.reward_weights.gold
        evaluation.component_scores.gold = goldScore
        evaluation.total_score = evaluation.total_score + goldScore
        table.insert(evaluation.analysis, "Gold: " .. rewards.gold .. " (" .. string.format("%.1f", goldScore) .. " pts)")
    end
    
    -- Evaluate experience
    if rewards.experience then
        local expScore = math.min((rewards.experience / 100000), 10) * self.reward_weights.experience
        evaluation.component_scores.experience = expScore
        evaluation.total_score = evaluation.total_score + expScore
        table.insert(evaluation.analysis, "Experience: " .. rewards.experience .. " (" .. string.format("%.1f", expScore) .. " pts)")
    end
    
    -- Evaluate items
    if rewards.items and #rewards.items > 0 then
        local itemScore = 0
        for _, item in ipairs(rewards.items) do
            itemScore = itemScore + self:EvaluateItem(item)
        end
        evaluation.component_scores.items = itemScore
        evaluation.total_score = evaluation.total_score + itemScore
        table.insert(evaluation.analysis, "Items: " .. #rewards.items .. " (" .. string.format("%.1f", itemScore) .. " pts)")
    end
    
    -- Evaluate reputation
    if rewards.reputation then
        local repScore = math.min((rewards.reputation / 100), 10) * self.reward_weights.reputation
        evaluation.component_scores.reputation = repScore
        evaluation.total_score = evaluation.total_score + repScore
        table.insert(evaluation.analysis, "Reputation: " .. rewards.reputation .. " (" .. string.format("%.1f", repScore) .. " pts)")
    end
    
    -- Evaluate special rewards
    if rewards.mount then
        evaluation.component_scores.mount = self.reward_weights.mount
        evaluation.total_score = evaluation.total_score + self.reward_weights.mount
        table.insert(evaluation.analysis, "Mount reward (" .. string.format("%.1f", self.reward_weights.mount) .. " pts)")
    end
    
    if rewards.pet then
        evaluation.component_scores.pet = self.reward_weights.pet
        evaluation.total_score = evaluation.total_score + self.reward_weights.pet
        table.insert(evaluation.analysis, "Pet reward (" .. string.format("%.1f", self.reward_weights.pet) .. " pts)")
    end
    
    -- Set priority
    if evaluation.total_score >= 8 then
        evaluation.priority = "high"
    elseif evaluation.total_score >= 5 then
        evaluation.priority = "medium"
    else
        evaluation.priority = "low"
    end
    
    self.reward_evaluations[tonumber(questId)] = evaluation
    
    return evaluation
end

function QuestRewardEvaluatorEngine:EvaluateItem(item)
    if not item then
        return 0
    end
    
    local score = 0
    
    -- Base item value from quality
    local qualityMultipliers = {
        poor = 0.5,
        common = 1.0,
        uncommon = 2.0,
        rare = 4.0,
        epic = 8.0,
        legendary = 16.0,
    }
    
    local quality = item.quality or "common"
    score = score + (qualityMultipliers[quality] or 1.0)
    
    -- Slot priority bonus
    if item.slot then
        local slotPriority = self.slot_priorities[item.slot] or 5
        score = score + (slotPriority / 10)
    end
    
    -- Level-appropriateness bonus
    if item.required_level then
        local levelDiff = math.abs((item.required_level or 1) - 60)
        if levelDiff < 5 then
            score = score + 2.0
        elseif levelDiff < 10 then
            score = score + 1.0
        end
    end
    
    score = score * self.reward_weights.item
    
    return score
end

function QuestRewardEvaluatorEngine:GetRewardEvaluation(questId)
    questId = tonumber(questId)
    return self.reward_evaluations[questId]
end

function QuestRewardEvaluatorEngine:GetTopRewardQuests(limit)
    limit = limit or 10
    local quests = {}
    
    for questId, evaluation in pairs(self.reward_evaluations) do
        table.insert(quests, { id = questId, evaluation = evaluation })
    end
    
    -- Sort by total score descending
    table.sort(quests, function(a, b)
        return a.evaluation.total_score > b.evaluation.total_score
    end)
    
    -- Return top N
    local result = {}
    for i = 1, math.min(limit, #quests) do
        table.insert(result, quests[i])
    end
    
    return result
end

function QuestRewardEvaluatorEngine:GetQuestsByPriority(priority)
    local result = {}
    
    for questId, evaluation in pairs(self.reward_evaluations) do
        if evaluation.priority == priority then
            table.insert(result, evaluation)
        end
    end
    
    -- Sort by score descending
    table.sort(result, function(a, b)
        return a.total_score > b.total_score
    end)
    
    return result
end

function QuestRewardEvaluatorEngine:SetRewardWeight(rewardType, weight)
    if not rewardType then
        return false
    end
    
    weight = tonumber(weight) or 0.1
    
    if self.reward_weights[rewardType] ~= nil then
        self.reward_weights[rewardType] = weight
        self:Log("Updated weight for " .. rewardType .. ": " .. weight)
        return true
    end
    
    return false
end

function QuestRewardEvaluatorEngine:SetSlotPriority(slot, priority)
    if not slot then
        return false
    end
    
    priority = tonumber(priority) or 5
    self.slot_priorities[slot] = priority
    self:Log("Updated slot priority: " .. slot .. " = " .. priority)
    
    return true
end

function QuestRewardEvaluatorEngine:GetRewardComparison(questId1, questId2)
    local eval1 = self:GetRewardEvaluation(questId1)
    local eval2 = self:GetRewardEvaluation(questId2)
    
    if not eval1 or not eval2 then
        return nil
    end
    
    local comparison = {
        quest1_id = questId1,
        quest2_id = questId2,
        quest1_score = eval1.total_score,
        quest2_score = eval2.total_score,
        better = eval1.total_score > eval2.total_score and questId1 or questId2,
        score_diff = math.abs(eval1.total_score - eval2.total_score),
    }
    
    return comparison
end

function QuestRewardEvaluatorEngine:GetAverageRewardScore()
    if not self.reward_evaluations or next(self.reward_evaluations) == nil then
        return 0
    end
    
    local totalScore = 0
    local count = 0
    
    for _, evaluation in pairs(self.reward_evaluations) do
        totalScore = totalScore + evaluation.total_score
        count = count + 1
    end
    
    return totalScore / count
end

function QuestRewardEvaluatorEngine:GetRewardDistribution()
    local distribution = {
        high = 0,
        medium = 0,
        low = 0,
    }
    
    for _, evaluation in pairs(self.reward_evaluations) do
        distribution[evaluation.priority] = distribution[evaluation.priority] + 1
    end
    
    return distribution
end

function QuestRewardEvaluatorEngine:ClearEvaluations()
    local count = 0
    
    for questId in pairs(self.reward_evaluations) do
        self.reward_evaluations[questId] = nil
        count = count + 1
    end
    
    self:Log("Cleared " .. count .. " reward evaluations")
    
    return count
end

function QuestRewardEvaluatorEngine:GetStatus()
    local distribution = self:GetRewardDistribution()
    local avgScore = self:GetAverageRewardScore()
    
    return {
        enabled = self.enabled,
        total_evaluations = next(self.reward_evaluations) and 1 or 0,
        high_priority = distribution.high,
        medium_priority = distribution.medium,
        low_priority = distribution.low,
        average_score = string.format("%.1f", avgScore),
    }
end

function QuestRewardEvaluatorEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestRewardEvaluatorEngine] " .. message)
    else
        print("[QuestRewardEvaluatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTREWARD1 = "/questreward"
    SlashCmdList["QUESTREWARD"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "eval" then
            local questId = tonumber(args)
            if questId then
                -- Simulate reward data for testing
                local rewards = {
                    gold = 1000 + (questId * 100),
                    experience = 5000 + (questId * 500),
                    items = { { quality = "uncommon", slot = "head" } },
                    reputation = 100,
                }
                local eval = QuestRewardEvaluatorEngine:EvaluateQuestReward(questId, rewards)
                print("Quest " .. questId .. " Reward Evaluation:")
                print("  Priority: " .. eval.priority)
                print("  Score: " .. string.format("%.1f", eval.total_score))
                for _, line in ipairs(eval.analysis) do
                    print("  " .. line)
                end
            else
                print("Usage: /questreward eval <questId>")
            end
        elseif cmd == "top" then
            local limit = tonumber(args) or 10
            local topQuests = QuestRewardEvaluatorEngine:GetTopRewardQuests(limit)
            print("Top " .. limit .. " Reward Quests:")
            for i, quest in ipairs(topQuests) do
                print(i .. ". Quest " .. quest.id .. ": " .. string.format("%.1f", quest.evaluation.total_score) .. " pts")
            end
        elseif cmd == "priority" then
            local priority = args ~= "" and args or "high"
            local quests = QuestRewardEvaluatorEngine:GetQuestsByPriority(priority)
            print("Quests with " .. priority .. " priority:")
            for i = 1, math.min(5, #quests) do
                print(i .. ". Quest " .. quests[i].quest_id .. ": " .. string.format("%.1f", quests[i].total_score) .. " pts")
            end
        elseif cmd == "avg" then
            local avg = QuestRewardEvaluatorEngine:GetAverageRewardScore()
            print("Average reward score: " .. string.format("%.1f", avg))
        elseif cmd == "distribution" then
            local dist = QuestRewardEvaluatorEngine:GetRewardDistribution()
            print("Reward Distribution:")
            print("  High: " .. dist.high)
            print("  Medium: " .. dist.medium)
            print("  Low: " .. dist.low)
        elseif cmd == "status" then
            local status = QuestRewardEvaluatorEngine:GetStatus()
            print("Quest Reward Evaluator Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Evaluations: " .. status.total_evaluations)
            print("  Average Score: " .. status.average_score)
        else
            print("Quest Reward Evaluator Commands:")
            print("  /questreward eval <questId> - Evaluate quest rewards")
            print("  /questreward top [limit] - Show top reward quests")
            print("  /questreward priority [high/medium/low] - Show quests by priority")
            print("  /questreward avg - Show average reward score")
            print("  /questreward distribution - Show reward distribution")
            print("  /questreward status - Show engine status")
        end
    end
end

return QuestRewardEvaluatorEngine
