-- QuestRewardPreviewEngine.lua - Preview quest rewards before completion
-- Part of PluribusQuestie addon suite
-- Shows rewards, XP, reputation gains, and choices

local QuestRewardPreviewEngine = {}
QuestRewardPreviewEngine.enabled = false
QuestRewardPreviewEngine.db = nil
QuestRewardPreviewEngine.reward_cache = {}

-- Configuration
QuestRewardPreviewEngine.config = {
    enabled = true,
    show_xp_preview = true,
    show_gold_preview = true,
    show_item_preview = true,
    show_reputation_preview = true,
    estimate_sellable_value = true,
}

function QuestRewardPreviewEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.reward_cache then
        self.db.reward_cache = {}
    end
    
    self.reward_cache = self.db.reward_cache
    self.enabled = true
    
    self:Log("Initialized quest reward preview engine")
end

function QuestRewardPreviewEngine:AddRewardData(questId, rewardType, rewardName, rewardValue)
    if not questId or not rewardType or not rewardName then
        return false
    end
    
    if not self.reward_cache[questId] then
        self.reward_cache[questId] = {
            xp = 0,
            gold = 0,
            reputation = {},
            items = {},
            choice_items = {},
            talents = {},
            achievements = {},
        }
    end
    
    if rewardType == "xp" then
        self.reward_cache[questId].xp = rewardValue or 0
    elseif rewardType == "gold" then
        self.reward_cache[questId].gold = rewardValue or 0
    elseif rewardType == "reputation" then
        table.insert(self.reward_cache[questId].reputation, {
            faction = rewardName,
            value = rewardValue or 0,
        })
    elseif rewardType == "item" then
        table.insert(self.reward_cache[questId].items, {
            name = rewardName,
            item_id = rewardValue,
            quantity = 1,
            guaranteed = true,
        })
    elseif rewardType == "choice_item" then
        table.insert(self.reward_cache[questId].choice_items, {
            name = rewardName,
            item_id = rewardValue,
            quantity = 1,
        })
    end
    
    return true
end

function QuestRewardPreviewEngine:GetQuestRewards(questId)
    if not questId or not self.reward_cache[questId] then
        return nil
    end
    
    return self.reward_cache[questId]
end

function QuestRewardPreviewEngine:GetRewardXP(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return 0
    end
    
    return rewards.xp
end

function QuestRewardPreviewEngine:GetRewardGold(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return 0
    end
    
    return rewards.gold
end

function QuestRewardPreviewEngine:GetRewardReputation(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards or #rewards.reputation == 0 then
        return {}
    end
    
    return rewards.reputation
end

function QuestRewardPreviewEngine:GetGuaranteedRewards(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return nil
    end
    
    return {
        xp = rewards.xp,
        gold = rewards.gold,
        items = rewards.items,
        reputation = rewards.reputation,
    }
end

function QuestRewardPreviewEngine:GetChoiceRewards(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards or #rewards.choice_items == 0 then
        return {}
    end
    
    return rewards.choice_items
end

function QuestRewardPreviewEngine:GetTotalRewardValue(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return {
            xp = 0,
            gold = 0,
            item_count = 0,
        }
    end
    
    local itemCount = #rewards.items + #rewards.choice_items
    
    return {
        xp = rewards.xp,
        gold = rewards.gold,
        item_count = itemCount,
        reputation_count = #rewards.reputation,
    }
end

function QuestRewardPreviewEngine:FormatRewardText(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return "No reward data"
    end
    
    local text = ""
    
    if rewards.xp > 0 then
        text = text .. rewards.xp .. " XP"
    end
    
    if rewards.gold > 0 then
        if text ~= "" then text = text .. " + " end
        text = text .. "|cFFFFD700" .. math.floor(rewards.gold / 100) .. "g|r"
    end
    
    if #rewards.items > 0 then
        if text ~= "" then text = text .. " + " end
        text = text .. #rewards.items .. " item" .. (#rewards.items > 1 and "s" or "")
    end
    
    if #rewards.choice_items > 0 then
        if text ~= "" then text = text .. " + " end
        text = text .. #rewards.choice_items .. " choice"
    end
    
    return text
end

function QuestRewardPreviewEngine:IsRewardWorth(questId, minGoldValue)
    minGoldValue = minGoldValue or 0
    
    local rewards = self:GetQuestRewards(questId)
    if not rewards then
        return false
    end
    
    return rewards.gold >= minGoldValue
end

function QuestRewardPreviewEngine:GetItemRewardDetails(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards or (#rewards.items == 0 and #rewards.choice_items == 0) then
        return {}
    end
    
    local details = {}
    
    for _, item in ipairs(rewards.items) do
        table.insert(details, {
            name = item.name,
            item_id = item.item_id,
            quantity = item.quantity,
            type = "guaranteed",
        })
    end
    
    for _, item in ipairs(rewards.choice_items) do
        table.insert(details, {
            name = item.name,
            item_id = item.item_id,
            quantity = item.quantity,
            type = "choice",
        })
    end
    
    return details
end

function QuestRewardPreviewEngine:GetReputationGains(questId)
    local rewards = self:GetQuestRewards(questId)
    if not rewards or #rewards.reputation == 0 then
        return {}
    end
    
    local details = {}
    
    for _, rep in ipairs(rewards.reputation) do
        table.insert(details, {
            faction = rep.faction,
            value = rep.value,
        })
    end
    
    return details
end

function QuestRewardPreviewEngine:CompareQuestRewards(questId1, questId2)
    local rewards1 = self:GetQuestRewards(questId1)
    local rewards2 = self:GetQuestRewards(questId2)
    
    if not rewards1 or not rewards2 then
        return nil
    end
    
    return {
        xp_difference = rewards1.xp - rewards2.xp,
        gold_difference = rewards1.gold - rewards2.gold,
        item_difference = (#rewards1.items + #rewards1.choice_items) - 
                         (#rewards2.items + #rewards2.choice_items),
    }
end

function QuestRewardPreviewEngine:GetStatus()
    local totalQuests = table.getn(self.reward_cache)
    local totalRewards = 0
    
    for _, rewards in pairs(self.reward_cache) do
        totalRewards = totalRewards + #rewards.items + #rewards.choice_items
    end
    
    return {
        enabled = self.enabled,
        cached_quests = totalQuests,
        total_rewards = totalRewards,
    }
end

function QuestRewardPreviewEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestRewardPreviewEngine] " .. message)
    else
        print("[QuestRewardPreviewEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTREWARD1 = "/questreward"
    SlashCmdList["QUESTREWARD"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "preview" then
            local questId = tonumber(args)
            if questId then
                local rewards = QuestRewardPreviewEngine:GetQuestRewards(questId)
                if rewards then
                    print("Quest " .. questId .. " Rewards:")
                    print("  XP: " .. rewards.xp)
                    print("  Gold: " .. rewards.gold)
                    print("  Items: " .. #rewards.items)
                    print("  Choices: " .. #rewards.choice_items)
                    print("  Reputation: " .. #rewards.reputation)
                else
                    print("No reward data for quest: " .. questId)
                end
            else
                print("Usage: /questreward preview <questId>")
            end
        elseif cmd == "text" then
            local questId = tonumber(args)
            if questId then
                local text = QuestRewardPreviewEngine:FormatRewardText(questId)
                print("Reward Text: " .. text)
            else
                print("Usage: /questreward text <questId>")
            end
        elseif cmd == "items" then
            local questId = tonumber(args)
            if questId then
                local items = QuestRewardPreviewEngine:GetItemRewardDetails(questId)
                print("Quest " .. questId .. " Items:")
                for i, item in ipairs(items) do
                    print("  [" .. i .. "] " .. item.name .. " (" .. item.type .. ")")
                end
            else
                print("Usage: /questreward items <questId>")
            end
        elseif cmd == "compare" then
            local q1, q2 = args:match("(%d+)%s+(%d+)")
            if q1 and q2 then
                local comparison = QuestRewardPreviewEngine:CompareQuestRewards(tonumber(q1), tonumber(q2))
                if comparison then
                    print("Comparison (Quest " .. q1 .. " vs Quest " .. q2 .. "):")
                    print("  XP: " .. (comparison.xp_difference > 0 and "+" or "") .. comparison.xp_difference)
                    print("  Gold: " .. (comparison.gold_difference > 0 and "+" or "") .. comparison.gold_difference)
                    print("  Items: " .. (comparison.item_difference > 0 and "+" or "") .. comparison.item_difference)
                end
            else
                print("Usage: /questreward compare <questId1> <questId2>")
            end
        elseif cmd == "status" then
            local status = QuestRewardPreviewEngine:GetStatus()
            print("Quest Reward Cache:")
            print("  Cached Quests: " .. status.cached_quests)
            print("  Total Rewards: " .. status.total_rewards)
        else
            print("Quest Reward Commands:")
            print("  /questreward preview <questId> - Show reward preview")
            print("  /questreward text <questId> - Format reward text")
            print("  /questreward items <questId> - List reward items")
            print("  /questreward compare <q1> <q2> - Compare two quests")
            print("  /questreward status - Show system status")
        end
    end
end

return QuestRewardPreviewEngine
