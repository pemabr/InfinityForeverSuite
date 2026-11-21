-- Questie Integration
local InfinityQuestIntegration = {}
_G.InfinityQuestIntegration = InfinityQuestIntegration

InfinityQuestIntegration.questCache = {}
InfinityQuestIntegration.questieAvailable = _G.QuestieDB ~= nil

function InfinityQuestIntegration:Initialize()
	self.questieAvailable = _G.QuestieDB ~= nil
	InfinityUtils:Info("Quest integration initialized. Questie: " .. tostring(self.questieAvailable), "Navigation")
end

function InfinityQuestIntegration:GetQuestData(questId)
	if not self.questieAvailable or not QuestieDB or not QuestieDB.QueryQuestSingle then
		return nil
	end
	
	local questData = QuestieDB:QueryQuestSingle(questId)
	return questData
end

function InfinityQuestIntegration:GetObjectiveLocations(questId)
	local quest = self:GetQuestData(questId)
	if not quest then return {} end
	
	local locations = {}
	
	-- Add kill/interact objectives
	if quest.objectives then
		for _, obj in ipairs(quest.objectives) do
			if obj.locations then
				for _, loc in ipairs(obj.locations) do
					table.insert(locations, {
						x = loc.x,
						y = loc.y,
						zone = loc.zone,
						type = obj.type,
						description = obj.description,
					})
				end
			end
		end
	end
	
	return locations
end

function InfinityQuestIntegration:GetQuestRewards(questId)
	local quest = self:GetQuestData(questId)
	if not quest then return {} end
	
	return quest.rewards or {}
end

return InfinityQuestIntegration
