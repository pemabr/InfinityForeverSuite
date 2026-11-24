-- QuestieDB Integration Module
-- Bridges Questie addon with PluribusData for seamless quest database sharing

local QuestieIntegration = {
	questieAvailable = false,
	syncState = {
		syncing = false,
		totalQuests = 0,
		synced = 0,
		startTime = 0,
	},
	
	config = {
		enableSync = true,
		batchSize = 100,
		batchDelay = 0.5, -- seconds
		autoSync = true,
		syncOnLoad = true,
	},
}

_G.PluribusQuestieIntegration = QuestieIntegration

function QuestieIntegration:Initialize()
	PluribusUtils:Info("QuestieDB Integration initialized", "Questie")
	
	-- Check if optional Questie is available
	if _G.Questie then
		self.questieAvailable = true
		PluribusUtils:Info("Optional Questie addon detected and linked", "Questie")
		
		if self.config.syncOnLoad then
			C_Timer.After(2, function()
				self:StartSync()
			end)
		end
	else
		PluribusUtils:Debug("Running in standalone quest mode (Questie optional)", "Questie")
	end
	
	-- Register for optional Questie load event
	local frame = CreateFrame("Frame")
	pcall(frame.RegisterEvent, frame, "ADDON_LOADED")
	frame:SetScript("OnEvent", function(f, event, addon)
		if event == "ADDON_LOADED" and addon == "Questie" then
			QuestieIntegration.questieAvailable = true
			PluribusUtils:Info("Optional Questie addon loaded - starting sync", "Questie")
			if QuestieIntegration.config.autoSync then
				QuestieIntegration:StartSync()
			end
		end
	end)
end

function QuestieIntegration:StartSync()
	if not self.config.enableSync then return end
	if self.syncState.syncing then return end
	
	if not self.questieAvailable then
		if _G.PluribusQuestieDBSync and _G.PluribusQuestieDBSync.SyncFromNativeQuestLog then
			_G.PluribusQuestieDBSync:SyncFromNativeQuestLog()
		end
		PluribusUtils:Debug("Questie optional - synced live WoW quest log instead", "Questie")
		return
	end
	
	self.syncState.syncing = true
	self.syncState.startTime = time()
	self.syncState.synced = 0
	
	-- Get all quests from Questie
	local questList = self:GetQuestListFromQuestie()
	self.syncState.totalQuests = #questList
	
	PluribusUtils:Info("Starting QuestieDB sync - " .. #questList .. " quests to sync", "Questie")
	
	-- Start batch processing
	self:ProcessQuestBatch(questList, 1)
end

function QuestieIntegration:GetQuestListFromQuestie()
	-- Questie stores quest data in _G.questieQuests table
	if not _G.questieQuests then return {} end
	
	local questList = {}
	for questID, questData in pairs(_G.questieQuests) do
		if questID and questData then
			table.insert(questList, {id = questID, data = questData})
		end
	end
	
	return questList
end

function QuestieIntegration:ProcessQuestBatch(questList, startIndex)
	if not self.syncState.syncing then return end
	
	local endIndex = math.min(startIndex + self.config.batchSize - 1, #questList)
	
	-- Process quests in this batch
	for i = startIndex, endIndex do
		local questEntry = questList[i]
		if questEntry then
			self:SyncQuestData(questEntry.id, questEntry.data)
			self.syncState.synced = self.syncState.synced + 1
		end
	end
	
	-- Schedule next batch if not done
	if endIndex < #questList then
		C_Timer.After(self.config.batchDelay, function()
			QuestieIntegration:ProcessQuestBatch(questList, endIndex + 1)
		end)
	else
		-- Sync complete
		self:OnSyncComplete()
	end
end

function QuestieIntegration:SyncQuestData(questID, questieData)
	if not questID then return end
	
	-- Check if already in PluribusData
	if PluribusData:GetQuest(questID) then
		-- Update with Questie data if newer
		local existing = PluribusData:GetQuest(questID)
		if not existing.questieData then
			existing.questieData = questieData
			PluribusData:StoreQuest(questID, existing)
		end
		return
	end
	
	-- Convert Questie format to PluribusData format
	local pluribusQuestData = self:ConvertQuestieToPluribus(questID, questieData)
	
	-- Store in PluribusData
	if pluribusQuestData then
		PluribusData:StoreQuest(questID, pluribusQuestData)
	end
end

function QuestieIntegration:ConvertQuestieToPluribus(questID, questieData)
	-- Parse Questie format and convert to our schema
	-- Questie format: {title, startNpc, endNpc, objectives, rewards, ...}
	
	if not questieData or not questieData[1] then return nil end
	
	local questName = questieData[1] or "Unknown"
	local questLevel = questieData.level or 1
	local questType = questieData.type or "normal"
	
	-- Extract objectives from Questie format
	local objectives = {}
	if questieData.objectives then
		for _, obj in ipairs(questieData.objectives) do
			if obj then
				table.insert(objectives, {
					text = obj.description or "Unknown objective",
					type = "objective",
					completed = false,
				})
			end
		end
	end
	
	-- Extract quest giver and quest completer
	local questGiver = nil
	local questCompleter = nil
	if questieData.startNpc then
		questGiver = type(questieData.startNpc) == "table" and questieData.startNpc[1] or questieData.startNpc
	end
	if questieData.endNpc then
		questCompleter = type(questieData.endNpc) == "table" and questieData.endNpc[1] or questieData.endNpc
	end
	
	-- Extract rewards
	local rewards = {}
	if questieData.rewards then
		if questieData.rewards.money then
			rewards.money = questieData.rewards.money
		end
		if questieData.rewards.items then
			rewards.items = questieData.rewards.items
		end
	end
	
	-- Build PluribusData quest format
	local pluribusData = {
		id = questID,
		name = questName,
		level = questLevel,
		type = questType,
		questGiver = questGiver,
		questCompleter = questCompleter,
		objectives = objectives,
		rewards = rewards,
		questieData = questieData, -- Store original Questie data as reference
		syncedAt = time(),
		source = "questie",
	}
	
	return pluribusData
end

function QuestieIntegration:OnSyncComplete()
	self.syncState.syncing = false
	local duration = time() - self.syncState.startTime
	
	PluribusUtils:Info(
		string.format("QuestieDB sync complete - Synced %d/%d quests in %.1fs",
			self.syncState.synced,
			self.syncState.totalQuests,
			duration
		), "Questie"
	)
	
	-- Publish completion event
	PluribusMessaging:Publish("questie_sync_complete", self.syncState.synced, self.syncState.totalQuests)
	
	-- Now share the quest data to guild members
	self:ShareSyncedData()
end

function QuestieIntegration:ShareSyncedData()
	-- Share all synced quest data with guild
	if DataSharing then
		PluribusUtils:Info("Sharing synced quest data with guild...", "Questie")
		
		local allQuests = PluribusData:GetAllQuests()
		local sharedCount = 0
		
		for questID, questData in pairs(allQuests) do
			if questData.source == "questie" and not questData.shared then
				DataSharing:ShareQuestData(questID, questData.name)
				questData.shared = true
				sharedCount = sharedCount + 1
				
				-- Throttle to avoid spam
				if sharedCount % 50 == 0 then
					C_Timer.After(0.1, function() end) -- Slight delay
				end
			end
		end
		
		PluribusUtils:Info("Shared " .. sharedCount .. " quest data entries with guild", "Questie")
	end
end

function QuestieIntegration:GetSyncStatus()
	if self.syncState.syncing then
		return string.format("Syncing: %d/%d quests",
			self.syncState.synced,
			self.syncState.totalQuests
		)
	else
		return string.format("Sync complete: %d quests synced",
			self.syncState.synced
		)
	end
end

function QuestieIntegration:IsQuestieAvailable()
	return self.questieAvailable
end

function QuestieIntegration:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("QuestieDB Integration config updated: " .. key .. " = " .. tostring(value), "Questie")
	end
end

function QuestieIntegration:ManualSync()
	if self.syncState.syncing then
		PluribusUtils:Warning("Sync already in progress", "Questie")
		return
	end
	self:StartSync()
end

return QuestieIntegration
