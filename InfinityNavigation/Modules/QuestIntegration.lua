-- Questie Integration
local InfinityQuestIntegration = {}
_G.InfinityQuestIntegration = InfinityQuestIntegration

InfinityQuestIntegration.questCache = {}
InfinityQuestIntegration.questieAvailable = _G.QuestieDB ~= nil

function InfinityQuestIntegration:Initialize()
	self.questieAvailable = _G.QuestieDB ~= nil
	InfinityUtils:Debug("Navigation quest integration initialized (mode: " .. (self.questieAvailable and "QuestieDB+Native" or "Standalone Native") .. ")", "Navigation")
end

function InfinityQuestIntegration:GetQuestData(questId)
	if self.questieAvailable and _G.QuestieDB and _G.QuestieDB.QueryQuestSingle then
		local ok, questData = pcall(function() return _G.QuestieDB:QueryQuestSingle(questId) end)
		if ok and questData then return questData end
	end
	-- Standalone fallback via InfinityQuestTracker or native C_QuestLog
	if _G.InfinityQuestTracker and _G.InfinityQuestTracker.active_quests and _G.InfinityQuestTracker.active_quests[questId] then
		return _G.InfinityQuestTracker.active_quests[questId]
	end
	if InfinityUtils and InfinityUtils.GetQuestTitleByID then
		local title = InfinityUtils:GetQuestTitleByID(questId)
		if title then
			return { id = questId, name = title, objectives = InfinityUtils:GetQuestObjectives(questId) }
		end
	end
	return nil
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
