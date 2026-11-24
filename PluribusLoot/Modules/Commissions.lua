-- PluribusLoot - Commissions Module
-- Tracks repeatable quests and commissions

PluribusLootCommissions = {
	db = {},
}

-- Initialize commissions module
function PluribusLootCommissions:Initialize()
	PluribusUtils:Info("Commissions module initializing...", "PluribusLoot")
	
	-- Load saved data
	self.db = PluribusStorageManager:GetFeatureSettings(PLURIBUS_FEATURES.LOOT) or {}
	
	-- Register with data manager
	PluribusDataManager:RegisterSource("loot_commissions", function(data)
		PluribusUtils:Debug("Commissions data updated", "PluribusLoot")
	end)
	
	-- Initialize default structure
	if not self.db.commissions then
		self.db.commissions = {}
	end
	
	if not self.db.dailyQuests then
		self.db.dailyQuests = {}
	end
	
	PluribusUtils:Info("Commissions module initialized", "PluribusLoot")
end

-- Register a commission/repeatable quest
function PluribusLootCommissions:RegisterQuest(questId, questName, npcName, questGiver, rewards)
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
	
	PluribusUtils:Debug("Commission registered: " .. questName, "PluribusLoot")
	
	return true
end

-- Mark commission as completed
function PluribusLootCommissions:CompleteQuest(questId)
	if not self.db.commissions[questId] then
		return false
	end
	
	local quest = self.db.commissions[questId]
	quest.timesCompleted = quest.timesCompleted + 1
	quest.lastCompleted = PluribusUtils:GetTimeStamp()
	
	PluribusUtils:Info("Commission completed: " .. quest.name, "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_commissions", "quest_completed", questId)
	
	return true
end

-- Get daily quests available today
function PluribusLootCommissions:GetDailyQuests()
	local today = date("%Y-%m-%d")
	
	if not self.db.dailyQuests[today] then
		self.db.dailyQuests[today] = {
			completed = {},
			timestamp = PluribusUtils:GetTimeStamp(),
		}
	end
	
	return self.db.dailyQuests[today]
end

-- Check if quest completed today
function PluribusLootCommissions:IsCompletedToday(questId)
	local dailyQuests = self:GetDailyQuests()
	return dailyQuests.completed[questId] == true
end

-- Mark daily quest as completed
function PluribusLootCommissions:MarkDailyCompleted(questId)
	local dailyQuests = self:GetDailyQuests()
	dailyQuests.completed[questId] = true
	
	return true
end

-- Get commission statistics
function PluribusLootCommissions:GetStatistics()
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
function PluribusLootCommissions:GetAvailableCommissions()
	local available = {}
	
	for questId, quest in pairs(self.db.commissions) do
		if not self:IsCompletedToday(questId) then
			table.insert(available, quest)
		end
	end
	
	return available
end

-- Get completed commissions
function PluribusLootCommissions:GetCompletedCommissions()
	local completed = {}
	
	for questId, quest in pairs(self.db.commissions) do
		if self:IsCompletedToday(questId) then
			table.insert(completed, quest)
		end
	end
	
	return completed
end

return PluribusLootCommissions

