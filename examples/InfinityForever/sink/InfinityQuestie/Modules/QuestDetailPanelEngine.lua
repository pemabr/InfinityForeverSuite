-- QuestDetailPanelEngine.lua - Individual quest details panel
-- Part of InfinityQuestie addon suite
-- Displays comprehensive quest information in detail view

local QuestDetailPanelEngine = {}
QuestDetailPanelEngine.enabled = false
QuestDetailPanelEngine.db = nil
QuestDetailPanelEngine.quest_details = {}
QuestDetailPanelEngine.detail_cache = {}
QuestDetailPanelEngine.detail_config = {}

-- Configuration
QuestDetailPanelEngine.config = {
    enabled = true,
    show_objectives = true,
    show_rewards = true,
    show_requirements = true,
    show_lore = true,
}

function QuestDetailPanelEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_details then
        self.db.quest_details = {}
    end
    
    if not self.db.detail_cache then
        self.db.detail_cache = {}
    end
    
    if not self.db.detail_config then
        self.db.detail_config = {}
    end
    
    self.quest_details = self.db.quest_details
    self.detail_cache = self.db.detail_cache
    self.detail_config = self.db.detail_config
    self.enabled = true
    
    self:Log("Initialized quest detail panel engine")
end

function QuestDetailPanelEngine:LoadQuestDetails(questId)
    if not questId then
        return nil
    end
    
    questId = tonumber(questId)
    
    -- Check cache first
    if self.detail_cache[questId] then
        return self.detail_cache[questId]
    end
    
    local details = {
        quest_id = questId,
        name = "Unknown Quest",
        level = 60,
        difficulty = "normal",
        description = "",
        objectives = {},
        objectives_text = {},
        progress_text = {},
        completion_text = "",
        rewards = {
            gold = 0,
            experience = 0,
            items = {},
            reputation = {},
        },
        requirements = {
            level = 1,
            class = nil,
            race = nil,
            faction = nil,
            prerequisites = {},
        },
        giver = {
            name = "Unknown NPC",
            location = "Unknown Location",
            coordinates = { x = 0, y = 0 },
        },
        turnin = {
            name = "Unknown NPC",
            location = "Unknown Location",
            coordinates = { x = 0, y = 0 },
        },
        lore = "",
        tags = {},
        created_at = GetTime(),
    }
    
    self.quest_details[questId] = details
    self.detail_cache[questId] = details
    self:Log("Loaded quest details for quest " .. questId)
    
    return details
end

function QuestDetailPanelEngine:SetQuestDescription(questId, description)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].description = description
    self:Log("Set description for quest " .. questId)
    
    return true
end

function QuestDetailPanelEngine:AddObjective(questId, objectiveText, objectiveType)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    table.insert(self.quest_details[questId].objectives, {
        text = objectiveText,
        type = objectiveType or "default",
        completed = false,
    })
    
    return true
end

function QuestDetailPanelEngine:SetObjectiveProgress(questId, objectiveIndex, completed)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] or 
       not self.quest_details[questId].objectives[objectiveIndex] then
        return false
    end
    
    self.quest_details[questId].objectives[objectiveIndex].completed = completed
    
    return true
end

function QuestDetailPanelEngine:AddRewardItem(questId, itemName, itemQuality)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    table.insert(self.quest_details[questId].rewards.items, {
        name = itemName,
        quality = itemQuality or "common",
        added_at = GetTime(),
    })
    
    return true
end

function QuestDetailPanelEngine:SetRewardGold(questId, gold)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].rewards.gold = tonumber(gold) or 0
    
    return true
end

function QuestDetailPanelEngine:SetRewardExperience(questId, experience)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].rewards.experience = tonumber(experience) or 0
    
    return true
end

function QuestDetailPanelEngine:AddReputation(questId, factionName, amount)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    table.insert(self.quest_details[questId].rewards.reputation, {
        faction = factionName,
        amount = tonumber(amount) or 0,
    })
    
    return true
end

function QuestDetailPanelEngine:SetRequirements(questId, minLevel, reqClass, reqRace)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].requirements.level = tonumber(minLevel) or 1
    self.quest_details[questId].requirements.class = reqClass
    self.quest_details[questId].requirements.race = reqRace
    
    return true
end

function QuestDetailPanelEngine:SetQuestGiver(questId, npcName, location, x, y)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].giver = {
        name = npcName or "Unknown",
        location = location or "Unknown",
        coordinates = { x = tonumber(x) or 0, y = tonumber(y) or 0 },
    }
    
    return true
end

function QuestDetailPanelEngine:SetQuestTurnin(questId, npcName, location, x, y)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].turnin = {
        name = npcName or "Unknown",
        location = location or "Unknown",
        coordinates = { x = tonumber(x) or 0, y = tonumber(y) or 0 },
    }
    
    return true
end

function QuestDetailPanelEngine:SetLore(questId, loreText)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    self.quest_details[questId].lore = loreText or ""
    
    return true
end

function QuestDetailPanelEngine:AddTag(questId, tag)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return false
    end
    
    table.insert(self.quest_details[questId].tags, tag)
    
    return true
end

function QuestDetailPanelEngine:GetQuestDetails(questId)
    questId = tonumber(questId)
    return self.quest_details[questId]
end

function QuestDetailPanelEngine:FormatRewardText(questId)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return ""
    end
    
    local details = self.quest_details[questId]
    local rewardText = "Rewards:\n"
    
    if details.rewards.gold > 0 then
        rewardText = rewardText .. "  " .. details.rewards.gold .. " gold\n"
    end
    
    if details.rewards.experience > 0 then
        rewardText = rewardText .. "  " .. details.rewards.experience .. " experience\n"
    end
    
    if #details.rewards.items > 0 then
        rewardText = rewardText .. "  Items:\n"
        for _, item in ipairs(details.rewards.items) do
            rewardText = rewardText .. "    - " .. item.name .. "\n"
        end
    end
    
    if #details.rewards.reputation > 0 then
        rewardText = rewardText .. "  Reputation:\n"
        for _, rep in ipairs(details.rewards.reputation) do
            rewardText = rewardText .. "    - " .. rep.faction .. " (" .. rep.amount .. ")\n"
        end
    end
    
    return rewardText
end

function QuestDetailPanelEngine:FormatObjectivesText(questId)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return ""
    end
    
    local details = self.quest_details[questId]
    local objectivesText = "Objectives:\n"
    
    for i, obj in ipairs(details.objectives) do
        local status = obj.completed and "✓" or "○"
        objectivesText = objectivesText .. "  " .. status .. " " .. obj.text .. "\n"
    end
    
    return objectivesText
end

function QuestDetailPanelEngine:FormatRequirementsText(questId)
    questId = tonumber(questId)
    
    if not self.quest_details[questId] then
        return ""
    end
    
    local details = self.quest_details[questId]
    local reqText = "Requirements:\n"
    
    reqText = reqText .. "  Minimum Level: " .. details.requirements.level .. "\n"
    
    if details.requirements.class then
        reqText = reqText .. "  Class: " .. details.requirements.class .. "\n"
    end
    
    if details.requirements.race then
        reqText = reqText .. "  Race: " .. details.requirements.race .. "\n"
    end
    
    return reqText
end

function QuestDetailPanelEngine:GetDetailsStatistics()
    local stats = {
        total_quests = 0,
        with_rewards = 0,
        with_objectives = 0,
        with_lore = 0,
        total_items = 0,
        average_gold = 0,
    }
    
    local totalGold = 0
    
    for _, details in pairs(self.quest_details) do
        stats.total_quests = stats.total_quests + 1
        
        if details.rewards.gold > 0 then
            stats.with_rewards = stats.with_rewards + 1
            totalGold = totalGold + details.rewards.gold
        end
        
        if #details.objectives > 0 then
            stats.with_objectives = stats.with_objectives + 1
        end
        
        if details.lore and details.lore ~= "" then
            stats.with_lore = stats.with_lore + 1
        end
        
        stats.total_items = stats.total_items + #details.rewards.items
    end
    
    if stats.with_rewards > 0 then
        stats.average_gold = totalGold / stats.with_rewards
    end
    
    return stats
end

function QuestDetailPanelEngine:GetStatus()
    local stats = self:GetDetailsStatistics()
    
    return {
        enabled = self.enabled,
        total_quests = stats.total_quests,
        with_rewards = stats.with_rewards,
        with_objectives = stats.with_objectives,
        total_items = stats.total_items,
    }
end

function QuestDetailPanelEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestDetailPanelEngine] " .. message)
    else
        print("[QuestDetailPanelEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTDETAIL1 = "/questdetail"
    SlashCmdList["QUESTDETAIL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "load" then
            local questId = tonumber(args)
            if questId then
                QuestDetailPanelEngine:LoadQuestDetails(questId)
                print("Loaded details for quest " .. questId)
            else
                print("Usage: /questdetail load <questId>")
            end
        elseif cmd == "show" then
            local questId = tonumber(args)
            if questId then
                local details = QuestDetailPanelEngine:GetQuestDetails(questId)
                if details then
                    print("Quest: " .. details.name)
                    print("Level: " .. details.level)
                    print("Giver: " .. details.giver.name .. " (" .. details.giver.location .. ")")
                    print("Turnin: " .. details.turnin.name .. " (" .. details.turnin.location .. ")")
                else
                    print("Quest not loaded")
                end
            else
                print("Usage: /questdetail show <questId>")
            end
        elseif cmd == "rewards" then
            local questId = tonumber(args)
            if questId then
                print(QuestDetailPanelEngine:FormatRewardText(questId))
            else
                print("Usage: /questdetail rewards <questId>")
            end
        elseif cmd == "objectives" then
            local questId = tonumber(args)
            if questId then
                print(QuestDetailPanelEngine:FormatObjectivesText(questId))
            else
                print("Usage: /questdetail objectives <questId>")
            end
        elseif cmd == "stats" then
            local stats = QuestDetailPanelEngine:GetDetailsStatistics()
            print("Quest Detail Statistics:")
            print("  Total Quests: " .. stats.total_quests)
            print("  With Rewards: " .. stats.with_rewards)
            print("  With Objectives: " .. stats.with_objectives)
            print("  Total Items: " .. stats.total_items)
        elseif cmd == "status" then
            local status = QuestDetailPanelEngine:GetStatus()
            print("Quest Detail Panel Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Quests: " .. status.total_quests)
            print("  With Rewards: " .. status.with_rewards)
        else
            print("Quest Detail Panel Commands:")
            print("  /questdetail load <questId> - Load quest details")
            print("  /questdetail show <questId> - Show quest info")
            print("  /questdetail rewards <questId> - Show rewards")
            print("  /questdetail objectives <questId> - Show objectives")
            print("  /questdetail stats - Show statistics")
            print("  /questdetail status - Show engine status")
        end
    end
end

return QuestDetailPanelEngine
