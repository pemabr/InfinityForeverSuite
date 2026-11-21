-- InfinityGuideQuests Module
-- Manages quest tracking and guidance

InfinityGuideQuests = {}
InfinityGuideQuests.quests = {}
InfinityGuideQuests.questLog = {}

function InfinityGuideQuests:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuide", "quests", {})
	self.quests = storageData.quests or {}
	self.questLog = storageData.questLog or {}
	InfinityUtils:Info("GuideQuests module initialized", "InfinityGuide")
end

function InfinityGuideQuests:RegisterQuest(questName, questId, level, questGiver, reward)
	local quest = {
		id = questId or ("q_" .. InfinityUtils:GetTimeStamp()),
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
	InfinityMessaging:Publish("quest_registered", { quest = questName })
	
	return quest
end

function InfinityGuideQuests:TrackQuest(questName)
	if not self.quests[questName] then return nil end
	
	self.quests[questName].tracked = true
	self.questLog[questName] = {
		name = questName,
		progress = 0,
		startTime = InfinityUtils:GetTimeStamp(),
		active = true,
	}
	
	self:SaveQuests()
	InfinityMessaging:Publish("quest_tracked", { quest = questName })
	
	return self.quests[questName]
end

function InfinityGuideQuests:CompleteQuest(questName)
	if not self.quests[questName] then return nil end
	
	self.quests[questName].completed = true
	self.quests[questName].tracked = false
	
	if self.questLog[questName] then
		self.questLog[questName].active = false
		self.questLog[questName].completedTime = InfinityUtils:GetTimeStamp()
	end
	
	self:SaveQuests()
	InfinityMessaging:Publish("quest_completed", { quest = questName })
	
	return self.quests[questName]
end

function InfinityGuideQuests:GetTrackedQuests()
	local tracked = {}
	for questName, quest in pairs(self.quests) do
		if quest.tracked then
			table.insert(tracked, quest)
		end
	end
	return tracked
end

function InfinityGuideQuests:GetQuestsByLevel(minLevel, maxLevel)
	local result = {}
	for questName, quest in pairs(self.quests) do
		if quest.level >= minLevel and quest.level <= maxLevel then
			table.insert(result, quest)
		end
	end
	return result
end

function InfinityGuideQuests:SaveQuests()
	InfinityStorageManager:SetFeatureSetting("InfinityGuide", "quests", {
		quests = self.quests,
		questLog = self.questLog,
	})
	InfinityDataManager:UpdateSourceData("InfinityGuide", "quests", {
		quests = self.quests,
		questLog = self.questLog,
	})
end

return InfinityGuideQuests
