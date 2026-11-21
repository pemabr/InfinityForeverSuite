-- QuestChainVisualizerEngine.lua - Visualize quest chains and dependencies
-- Part of InfinityQuestie addon suite
-- Shows quest relationships, prerequisites, and progression paths

local QuestChainVisualizerEngine = {}
QuestChainVisualizerEngine.enabled = false
QuestChainVisualizerEngine.db = nil
QuestChainVisualizerEngine.chains = {}
QuestChainVisualizerEngine.visualizations = {}

-- Configuration
QuestChainVisualizerEngine.config = {
    enabled = true,
    max_chain_depth = 10,
    max_chains = 100,
    visualization_format = "text",  -- text, table, graph
}

function QuestChainVisualizerEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.chains then
        self.db.chains = {}
    end
    
    if not self.db.visualizations then
        self.db.visualizations = {}
    end
    
    self.chains = self.db.chains
    self.visualizations = self.db.visualizations
    self.enabled = true
    
    self:Log("Initialized quest chain visualizer engine")
end

function QuestChainVisualizerEngine:BuildQuestChain(questId)
    if not questId or not QuestDatabaseEngine then
        return nil
    end
    
    local chain = {
        root_quest = questId,
        prerequisites = {},
        continuations = {},
        related_quests = {},
        created_at = GetTime(),
    }
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return nil
    end
    
    -- Get prerequisites
    if quest.prerequisites and #quest.prerequisites > 0 then
        for _, prereqId in ipairs(quest.prerequisites) do
            local prereq = QuestDatabaseEngine:GetQuest(prereqId)
            if prereq then
                table.insert(chain.prerequisites, {
                    id = prereqId,
                    name = prereq.name,
                    level = prereq.level,
                })
            end
        end
    end
    
    -- Get related quests (continuations)
    if quest.related_quests and #quest.related_quests > 0 then
        for _, relatedId in ipairs(quest.related_quests) do
            local related = QuestDatabaseEngine:GetQuest(relatedId)
            if related then
                table.insert(chain.related_quests, {
                    id = relatedId,
                    name = related.name,
                    level = related.level,
                    type = "related",
                })
            end
        end
    end
    
    table.insert(self.chains, chain)
    self:Log("Built quest chain for: " .. questId)
    
    return chain
end

function QuestChainVisualizerEngine:GetChain(questId)
    for _, chain in ipairs(self.chains) do
        if chain.root_quest == questId then
            return chain
        end
    end
    
    return nil
end

function QuestChainVisualizerEngine:GetChainDepth(questId)
    if not questId or not QuestDatabaseEngine then
        return 0
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest or not quest.prerequisites or #quest.prerequisites == 0 then
        return 0
    end
    
    local maxDepth = 0
    
    for _, prereqId in ipairs(quest.prerequisites) do
        local depth = 1 + self:GetChainDepth(prereqId)
        if depth > maxDepth then
            maxDepth = depth
        end
    end
    
    return math.min(maxDepth, self.config.max_chain_depth)
end

function QuestChainVisualizerEngine:GetChainLength(questId)
    if not questId or not QuestDatabaseEngine then
        return 0
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return 0
    end
    
    local length = 1
    
    if quest.related_quests and #quest.related_quests > 0 then
        for _, relatedId in ipairs(quest.related_quests) do
            length = length + self:GetChainLength(relatedId)
        end
    end
    
    return length
end

function QuestChainVisualizerEngine:IsQuestPartOfChain(questId, chainRootId)
    if not questId or not chainRootId then
        return false
    end
    
    if questId == chainRootId then
        return true
    end
    
    if not QuestDatabaseEngine then
        return false
    end
    
    local quest = QuestDatabaseEngine:GetQuest(chainRootId)
    if not quest then
        return false
    end
    
    -- Check prerequisites
    if quest.prerequisites and #quest.prerequisites > 0 then
        for _, prereqId in ipairs(quest.prerequisites) do
            if self:IsQuestPartOfChain(questId, prereqId) then
                return true
            end
        end
    end
    
    -- Check related quests
    if quest.related_quests and #quest.related_quests > 0 then
        for _, relatedId in ipairs(quest.related_quests) do
            if self:IsQuestPartOfChain(questId, relatedId) then
                return true
            end
        end
    end
    
    return false
end

function QuestChainVisualizerEngine:GetChainAsText(questId)
    local chain = self:GetChain(questId)
    if not chain then
        return "No chain data available"
    end
    
    local text = "QUEST CHAIN FOR: " .. questId .. "\n"
    text = text .. "=========================================\n\n"
    
    if #chain.prerequisites > 0 then
        text = text .. "PREREQUISITES:\n"
        for i, prereq in ipairs(chain.prerequisites) do
            text = text .. "  [" .. i .. "] [" .. prereq.level .. "] " .. prereq.name .. "\n"
        end
        text = text .. "\n"
    end
    
    text = text .. "CURRENT: [" .. chain.root_quest .. "]\n\n"
    
    if #chain.related_quests > 0 then
        text = text .. "CONTINUATIONS:\n"
        for i, related in ipairs(chain.related_quests) do
            text = text .. "  [" .. i .. "] [" .. related.level .. "] " .. related.name .. "\n"
        end
    end
    
    return text
end

function QuestChainVisualizerEngine:GetChainAsTable(questId)
    local chain = self:GetChain(questId)
    if not chain then
        return {}
    end
    
    local table_data = {
        root_quest = chain.root_quest,
        prerequisites = chain.prerequisites,
        continuations = chain.related_quests,
        created_at = chain.created_at,
    }
    
    return table_data
end

function QuestChainVisualizerEngine:GetChainTree(questId, depth)
    depth = depth or 0
    
    if depth > self.config.max_chain_depth then
        return nil
    end
    
    if not QuestDatabaseEngine then
        return nil
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return nil
    end
    
    local tree = {
        id = questId,
        name = quest.name,
        level = quest.level,
        prerequisites = {},
        continuations = {},
        depth = depth,
    }
    
    -- Add prerequisites recursively
    if quest.prerequisites and #quest.prerequisites > 0 then
        for _, prereqId in ipairs(quest.prerequisites) do
            local prereqTree = self:GetChainTree(prereqId, depth + 1)
            if prereqTree then
                table.insert(tree.prerequisites, prereqTree)
            end
        end
    end
    
    -- Add continuations recursively
    if quest.related_quests and #quest.related_quests > 0 then
        for _, relatedId in ipairs(quest.related_quests) do
            local relatedTree = self:GetChainTree(relatedId, depth + 1)
            if relatedTree then
                table.insert(tree.continuations, relatedTree)
            end
        end
    end
    
    return tree
end

function QuestChainVisualizerEngine:GetChainStatistics(questId)
    local chain = self:GetChain(questId)
    if not chain then
        return nil
    end
    
    local prereqCount = #chain.prerequisites
    local continuationCount = #chain.related_quests
    local depth = self:GetChainDepth(questId)
    local length = self:GetChainLength(questId)
    
    return {
        quest_id = questId,
        prerequisite_count = prereqCount,
        continuation_count = continuationCount,
        chain_depth = depth,
        chain_length = length,
        total_related = prereqCount + continuationCount,
    }
end

function QuestChainVisualizerEngine:FindChainStart(questId)
    if not questId or not QuestDatabaseEngine then
        return questId
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest or not quest.prerequisites or #quest.prerequisites == 0 then
        return questId
    end
    
    -- Recursively find the start of the chain
    return self:FindChainStart(quest.prerequisites[1])
end

function QuestChainVisualizerEngine:FindChainEnd(questId)
    if not questId or not QuestDatabaseEngine then
        return questId
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest or not quest.related_quests or #quest.related_quests == 0 then
        return questId
    end
    
    -- Recursively find the end of the chain
    return self:FindChainEnd(quest.related_quests[1])
end

function QuestChainVisualizerEngine:GetAllChains()
    return self.chains
end

function QuestChainVisualizerEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_chains = #self.chains,
        max_chains = self.config.max_chains,
    }
end

function QuestChainVisualizerEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestChainVisualizerEngine] " .. message)
    else
        print("[QuestChainVisualizerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTCHAIN1 = "/questchain"
    SlashCmdList["QUESTCHAIN"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "build" then
            local questId = tonumber(args)
            if questId then
                QuestChainVisualizerEngine:BuildQuestChain(questId)
                print("Built chain for quest: " .. questId)
            else
                print("Usage: /questchain build <questId>")
            end
        elseif cmd == "view" then
            local questId = tonumber(args)
            if questId then
                local text = QuestChainVisualizerEngine:GetChainAsText(questId)
                print(text)
            else
                print("Usage: /questchain view <questId>")
            end
        elseif cmd == "depth" then
            local questId = tonumber(args)
            if questId then
                local depth = QuestChainVisualizerEngine:GetChainDepth(questId)
                print("Quest " .. questId .. " chain depth: " .. depth)
            else
                print("Usage: /questchain depth <questId>")
            end
        elseif cmd == "length" then
            local questId = tonumber(args)
            if questId then
                local length = QuestChainVisualizerEngine:GetChainLength(questId)
                print("Quest " .. questId .. " chain length: " .. length)
            else
                print("Usage: /questchain length <questId>")
            end
        elseif cmd == "start" then
            local questId = tonumber(args)
            if questId then
                local start = QuestChainVisualizerEngine:FindChainStart(questId)
                print("Quest " .. questId .. " chain starts at: " .. start)
            else
                print("Usage: /questchain start <questId>")
            end
        elseif cmd == "end" then
            local questId = tonumber(args)
            if questId then
                local endQuest = QuestChainVisualizerEngine:FindChainEnd(questId)
                print("Quest " .. questId .. " chain ends at: " .. endQuest)
            else
                print("Usage: /questchain end <questId>")
            end
        elseif cmd == "stats" then
            local questId = tonumber(args)
            if questId then
                local stats = QuestChainVisualizerEngine:GetChainStatistics(questId)
                if stats then
                    print("Chain Statistics for Quest " .. questId .. ":")
                    print("  Prerequisites: " .. stats.prerequisite_count)
                    print("  Continuations: " .. stats.continuation_count)
                    print("  Chain Depth: " .. stats.chain_depth)
                    print("  Chain Length: " .. stats.chain_length)
                end
            else
                print("Usage: /questchain stats <questId>")
            end
        elseif cmd == "status" then
            local status = QuestChainVisualizerEngine:GetStatus()
            print("Quest Chain Visualizer:")
            print("  Total Chains: " .. status.total_chains)
            print("  Max Chains: " .. status.max_chains)
        else
            print("Quest Chain Commands:")
            print("  /questchain build <questId> - Build chain")
            print("  /questchain view <questId> - View chain")
            print("  /questchain depth <questId> - Show depth")
            print("  /questchain length <questId> - Show length")
            print("  /questchain start <questId> - Find chain start")
            print("  /questchain end <questId> - Find chain end")
            print("  /questchain stats <questId> - Show statistics")
            print("  /questchain status - Show system status")
        end
    end
end

return QuestChainVisualizerEngine
