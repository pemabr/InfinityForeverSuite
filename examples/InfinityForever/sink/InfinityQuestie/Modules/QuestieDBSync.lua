-- InfinityQuestie - QuestieDB Auto-Sync Module
-- Automatically populates quest database from Questie addon if available

local QuestieDBSync = {}
_G.InfinityQuestieDBSync = QuestieDBSync

QuestieDBSync.questieAvailable = false
QuestieDBSync.syncInProgress = false
QuestieDBSync.questsLoaded = 0
QuestieDBSync.maxSyncBatch = 100

--- Initialize QuestieDB sync
function QuestieDBSync:Initialize()
	self.questieAvailable = _G.QuestieDB ~= nil
	
	if self.questieAvailable then
		InfinityUtils:Info("QuestieDB found - auto-syncing quest data", "QuestieSync")
		self:BeginSync()
	else
		InfinityUtils:Info("QuestieDB not found - quest data empty until populated", "QuestieSync")
	end
end

--- Begin syncing quests from QuestieDB
function QuestieDBSync:BeginSync()
	if not self.questieAvailable or self.syncInProgress then
		return
	end
	
	self.syncInProgress = true
	self.questsLoaded = 0
	
	-- Sync in batches to avoid lag
	self:SyncBatch(1)
end

--- Sync a batch of quests
function QuestieDBSync:SyncBatch(startId)
	if not self.questieAvailable then
		self.syncInProgress = false
		return
	end
	
	local endId = startId + self.maxSyncBatch
	local synced = 0
	
	-- Iterate through QuestieDB quests
	if QuestieDB and QuestieDB.Quest then
		for questId = startId, endId do
			if QuestieDB.Quest[questId] then
				local questData = QuestieDB.Quest[questId]
				self:SyncQuest(questId, questData)
				synced = synced + 1
			end
		end
	end
	
	self.questsLoaded = self.questsLoaded + synced
	
	-- If we synced anything, schedule next batch
	if synced > 0 and synced >= self.maxSyncBatch then
		C_Timer.After(0.5, function()
			self:SyncBatch(endId + 1)
		end)
	else
		-- Sync complete
		self.syncInProgress = false
		InfinityUtils:Info("Quest sync complete: " .. self.questsLoaded .. " quests loaded", "QuestieSync")
		InfinityMessaging:Publish("quest_database_synced", self.questsLoaded)
	end
end

--- Sync a single quest from QuestieDB
function QuestieDBSync:SyncQuest(questId, questData)
	if not InfinityQuestTracker or not questData then
		return
	end
	
	-- Extract quest information from Questie format
	local questName = questData.name or ("Quest " .. questId)
	local questLevel = questData.level or 1
	local zone = questData.zone or "Unknown"
	
	-- Parse quest giver (Questie stores as ID, need name)
	local giver = "Unknown"
	if questData.start and QuestieDB.NPC then
		local starterNPC = QuestieDB.NPC[questData.start[1]]
		if starterNPC then
			giver = starterNPC.name or giver
		end
	end
	
	-- Parse objectives from Questie format
	local objectives = {}
	if questData.objectives then
		for _, objective in ipairs(questData.objectives) do
			table.insert(objectives, {
				description = objective.description or "Unknown",
				progress = 0,
				complete = false,
			})
		end
	end
	
	-- Parse rewards
	local rewards = {}
	if questData.reward_items then
		for _, itemId in ipairs(questData.reward_items) do
			table.insert(rewards, {
				type = "item",
				id = itemId,
				value = 0,
			})
		end
	end
	if questData.reward_money then
		table.insert(rewards, {
			type = "gold",
			amount = questData.reward_money,
		})
	end
	
	-- Register quest
	InfinityQuestTracker:RegisterQuest(questId, {
		name = questName,
		giver = giver,
		level = questLevel,
		zone = zone,
		objectives = objectives,
		rewards = rewards,
		prerequisite = questData.questStarter or nil,
		followUp = questData.nextQuestId or nil,
	})
end

--- Get sync status
function QuestieDBSync:GetStatus()
	return {
		questieAvailable = self.questieAvailable,
		syncInProgress = self.syncInProgress,
		questsLoaded = self.questsLoaded,
	}
end

--- Display sync information
function QuestieDBSync:DisplayStatus()
	print("|cffffd700=== QuestieDB Sync Status ===|r")
	print("Questie Addon: " .. (self.questieAvailable and "|cff00ff00Available|r" or "|cffff0000Not Installed|r"))
	print("Sync Status: " .. (self.syncInProgress and "|cffffaa00In Progress|r" or "|cff00ff00Complete|r"))
	print("Quests Loaded: " .. self.questsLoaded)
end

return QuestieDBSync
