-- Quest Chains
-- Quest prerequisite chains and dependencies

local PluribusQuestChains = {}
_G.PluribusQuestChains = PluribusQuestChains

PluribusQuestChains.chains = {}

function PluribusQuestChains:RegisterChain(chainID, questIDs)
    if not chainID or not questIDs or #questIDs == 0 then return false end
    
    self.chains[chainID] = {
        id = chainID,
        quests = questIDs,
        length = #questIDs,
        name = "Chain: " .. questIDs[1],
    }
    
    return true
end

function PluribusQuestChains:GetChain(chainID)
    return self.chains[chainID]
end

function PluribusQuestChains:GetChainForQuest(questID)
    for chainID, chain in pairs(self.chains) do
        for _, qID in ipairs(chain.quests) do
            if qID == questID then
                return chain
            end
        end
    end
    return nil
end

function PluribusQuestChains:GetPrerequisites(questID)
    local chain = self:GetChainForQuest(questID)
    if not chain then return {} end
    
    local prereqs = {}
    for i, qID in ipairs(chain.quests) do
        if qID == questID and i > 1 then
            for j = 1, i - 1 do
                table.insert(prereqs, chain.quests[j])
            end
            break
        end
    end
    
    return prereqs
end

function PluribusQuestChains:GetFollowups(questID)
    local chain = self:GetChainForQuest(questID)
    if not chain then return {} end
    
    local followups = {}
    for i, qID in ipairs(chain.quests) do
        if qID == questID and i < #chain.quests then
            for j = i + 1, #chain.quests do
                table.insert(followups, chain.quests[j])
            end
            break
        end
    end
    
    return followups
end

return PluribusQuestChains
