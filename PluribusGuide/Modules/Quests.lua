-- PluribusGuideQuests Module
-- Manages quest tracking and guidance

PluribusGuideQuests = {}
PluribusGuideQuests.quests = {}
PluribusGuideQuests.questLog = {}

function PluribusGuideQuests:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGuide", "quests", {})
	self.quests = storageData.quests or {}
	self.questLog = storageData.questLog or {}
	PluribusUtils:Info("GuideQuests module initialized", "PluribusGuide")
end

function PluribusGuideQuests:RegisterQuest(questName, questId, level, questGiver, reward)
	local quest = {
		id = questId or ("q_" .. PluribusUtils:GetTimeStamp()),
		name = questName,
		level = level or 1,
		giver = questGiver or "Unknown",
		reward = reward or 0,
		tracked = false,
		completed = false,
		steps = {},
	}
	
	self.quests[questName] = quest
	self:SaveQuests()
	PluribusMessaging:Publish("quest_registered", { quest = questName })
	
	return quest
end

function PluribusGuideQuests:TrackQuest(questName)
	if not self.quests[questName] then return nil end
	
	self.quests[questName].tracked = true
	self.questLog[questName] = {
		name = questName,
		progress = 0,
		startTime = PluribusUtils:GetTimeStamp(),
		active = true,
	}
	
	self:SaveQuests()
	PluribusMessaging:Publish("quest_tracked", { quest = questName })
	
	return self.quests[questName]
end

function PluribusGuideQuests:CompleteQuest(questName)
	if not self.quests[questName] then return nil end
	
	self.quests[questName].completed = true
	self.quests[questName].tracked = false
	
	if self.questLog[questName] then
		self.questLog[questName].active = false
		self.questLog[questName].completedTime = PluribusUtils:GetTimeStamp()
	end
	
	self:SaveQuests()
	PluribusMessaging:Publish("quest_completed", { quest = questName })
	
	return self.quests[questName]
end

function PluribusGuideQuests:GetTrackedQuests()
	local tracked = {}
	for questName, quest in pairs(self.quests) do
		if quest.tracked then
			table.insert(tracked, quest)
		end
	end
	return tracked
end

function PluribusGuideQuests:GetQuestsByLevel(minLevel, maxLevel)
	local result = {}
	for questName, quest in pairs(self.quests) do
		if quest.level >= minLevel and quest.level <= maxLevel then
			table.insert(result, quest)
		end
	end
	return result
end

function PluribusGuideQuests:SaveQuests()
	PluribusStorageManager:SetFeatureSetting("PluribusGuide", "quests", {
		quests = self.quests,
		questLog = self.questLog,
	})
	PluribusDataManager:UpdateSourceData("PluribusGuide", "quests", {
		quests = self.quests,
		questLog = self.questLog,
	})
end

return PluribusGuideQuests
