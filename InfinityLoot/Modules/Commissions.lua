-- InfinityLoot - Commissions Module
-- Tracks repeatable quests and commissions

InfinityLootCommissions = {
	db = {},
}

-- Initialize commissions module
function InfinityLootCommissions:Initialize()
	InfinityUtils:Info("Commissions module initializing...", "InfinityLoot")
	
	-- Load saved data
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	
	-- Register with data manager
	InfinityDataManager:RegisterSource("loot_commissions", function(data)
		InfinityUtils:Debug("Commissions data updated", "InfinityLoot")
	end)
	
	-- Initialize default structure
	if not self.db.commissions then
		self.db.commissions = {}
	end
	
	if not self.db.dailyQuests then
		self.db.dailyQuests = {}
	end
	
	InfinityUtils:Info("Commissions module initialized", "InfinityLoot")
end

-- Register a commission/repeatable quest
function InfinityLootCommissions:RegisterQuest(questId, questName, npcName, questGiver, rewards)
	local quest = {
		id = questId,
		name = questName,
		npcName = npcName,
		questGiver = questGiver,
		rewards = rewards or {},
		timesCompleted = 0,
		lastCompleted = nil,
	}
	
	self.db.commissions[questId] = quest
	
	InfinityUtils:Debug("Commission registered: " .. questName, "InfinityLoot")
	
	return true
end

-- Mark commission as completed
function InfinityLootCommissions:CompleteQuest(questId)
	if not self.db.commissions[questId] then
		return false
	end
	
	local quest = self.db.commissions[questId]
	quest.timesCompleted = quest.timesCompleted + 1
	quest.lastCompleted = InfinityUtils:GetTimeStamp()
	
	InfinityUtils:Info("Commission completed: " .. quest.name, "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_commissions", "quest_completed", questId)
	
	return true
end

-- Get daily quests available today
function InfinityLootCommissions:GetDailyQuests()
	local today = date("%Y-%m-%d")
	
	if not self.db.dailyQuests[today] then
		self.db.dailyQuests[today] = {
			completed = {},
			timestamp = InfinityUtils:GetTimeStamp(),
		}
	end
	
	return self.db.dailyQuests[today]
end

-- Check if quest completed today
function InfinityLootCommissions:IsCompletedToday(questId)
	local dailyQuests = self:GetDailyQuests()
	return dailyQuests.completed[questId] == true
end

-- Mark daily quest as completed
function InfinityLootCommissions:MarkDailyCompleted(questId)
	local dailyQuests = self:GetDailyQuests()
	dailyQuests.completed[questId] = true
	
	return true
end

-- Get commission statistics
function InfinityLootCommissions:GetStatistics()
	local stats = {
		totalQuestRegistered = 0,
		totalCompletions = 0,
		averageCompletionsPerQuest = 0,
		todayCompleted = 0,
	}
	
	for questId, quest in pairs(self.db.commissions) do
		stats.totalQuestRegistered = stats.totalQuestRegistered + 1
		stats.totalCompletions = stats.totalCompletions + quest.timesCompleted
	end
	
	if stats.totalQuestRegistered > 0 then
		stats.averageCompletionsPerQuest = math.floor(stats.totalCompletions / stats.totalQuestRegistered)
	end
	
	local dailyQuests = self:GetDailyQuests()
	for _ in pairs(dailyQuests.completed) do
		stats.todayCompleted = stats.todayCompleted + 1
	end
	
	return stats
end

-- Get available commissions
function InfinityLootCommissions:GetAvailableCommissions()
	local available = {}
	
	for questId, quest in pairs(self.db.commissions) do
		if not self:IsCompletedToday(questId) then
			table.insert(available, quest)
		end
	end
	
	return available
end

-- Get completed commissions
function InfinityLootCommissions:GetCompletedCommissions()
	local completed = {}
	
	for questId, quest in pairs(self.db.commissions) do
		if self:IsCompletedToday(questId) then
			table.insert(completed, quest)
		end
	end
	
	return completed
end

return InfinityLootCommissions

