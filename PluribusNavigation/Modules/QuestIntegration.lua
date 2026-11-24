-- Questie Integration
local PluribusQuestIntegration = {}
_G.PluribusQuestIntegration = PluribusQuestIntegration

PluribusQuestIntegration.questCache = {}
PluribusQuestIntegration.questieAvailable = _G.QuestieDB ~= nil

function PluribusQuestIntegration:Initialize()
	self.questieAvailable = _G.QuestieDB ~= nil
	PluribusUtils:Debug("Navigation quest integration initialized (mode: " .. (self.questieAvailable and "QuestieDB+Native" or "Standalone Native") .. ")", "Navigation")
end

function PluribusQuestIntegration:GetQuestData(questId)
	if self.questieAvailable and _G.QuestieDB and _G.QuestieDB.QueryQuestSingle then
		local ok, questData = pcall(function() return _G.QuestieDB:QueryQuestSingle(questId) end)
		if ok and questData then return questData end
	end
	-- Standalone fallback via PluribusQuestTracker or native C_QuestLog
	if _G.PluribusQuestTracker and _G.PluribusQuestTracker.active_quests and _G.PluribusQuestTracker.active_quests[questId] then
		return _G.PluribusQuestTracker.active_quests[questId]
	end
	if PluribusUtils and PluribusUtils.GetQuestTitleByID then
		local title = PluribusUtils:GetQuestTitleByID(questId)
		if title then
			return { id = questId, name = title, objectives = PluribusUtils:GetQuestObjectives(questId) }
		end
	end
	return nil
end

function PluribusQuestIntegration:GetObjectiveLocations(questId)
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

function PluribusQuestIntegration:GetQuestRewards(questId)
	local quest = self:GetQuestData(questId)
	if not quest then return {} end
	
	return quest.rewards or {}
end

return PluribusQuestIntegration
