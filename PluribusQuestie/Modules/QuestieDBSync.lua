-- PluribusQuestie - QuestieDB Auto-Sync Module
-- Automatically populates quest database from Questie addon if available

local QuestieDBSync = {}
_G.PluribusQuestieDBSync = QuestieDBSync

QuestieDBSync.questieAvailable = false
QuestieDBSync.syncInProgress = false
QuestieDBSync.questsLoaded = 0
QuestieDBSync.maxSyncBatch = 100

--- Initialize standalone native quest log sync (+ optional QuestieDB bonus if installed)
function QuestieDBSync:Initialize()
	self.questieAvailable = _G.QuestieDB ~= nil
	self.standaloneMode = not self.questieAvailable
	
	-- Always populate from the player's live WoW Quest Log (works 100% standalone)
	self:SyncFromNativeQuestLog()
	
	-- Keep native quest log synced automatically and detect late-loaded optional QuestieDB
	if not self.eventFrame then
		local ef = CreateFrame("Frame")
		pcall(ef.RegisterEvent, ef, "QUEST_LOG_UPDATE")
		pcall(ef.RegisterEvent, ef, "QUEST_ACCEPTED")
		pcall(ef.RegisterEvent, ef, "QUEST_REMOVED")
		pcall(ef.RegisterEvent, ef, "PLAYER_ENTERING_WORLD")
		pcall(ef.RegisterEvent, ef, "ADDON_LOADED")
		ef:SetScript("OnEvent", function(_, ev, loadedAddon)
			if ev == "ADDON_LOADED" then
				if (loadedAddon == "Questie" or loadedAddon == "QuestieDB") and _G.QuestieDB and not QuestieDBSync.questieAvailable then
					QuestieDBSync.questieAvailable = true
					QuestieDBSync.standaloneMode = false
					PluribusUtils:Info("Optional QuestieDB loaded - enriching quest database", "QuestieSync")
					QuestieDBSync:BeginSync()
				end
				return
			end
			QuestieDBSync:SyncFromNativeQuestLog()
		end)
		self.eventFrame = ef
	end
	
	if self.questieAvailable then
		PluribusUtils:Info("Optional QuestieDB detected - enriching standalone quest database", "QuestieSync")
		self:BeginSync()
	else
		PluribusUtils:Debug("Running in standalone live quest log mode (QuestieDB optional)", "QuestieSync")
	end
end

--- Populate active quests & database directly from WoW C_QuestLog (no QuestieDB required)
function QuestieDBSync:SyncFromNativeQuestLog()
	if not PluribusUtils or not PluribusUtils.GetQuestLogCount then return 0 end
	local count = PluribusUtils:GetQuestLogCount()
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local loaded = 0
	local seen = {}

	for i = 1, count do
		local title, level, isHeader, questID, isComplete = PluribusUtils:GetQuestLogEntry(i)
		if title and not isHeader and questID and type(questID) == "number" and questID > 0 then
			seen[questID] = true
			local rawObjectives = PluribusUtils:GetQuestObjectives(questID)
			local objectives = {}
			for _, obj in ipairs(rawObjectives) do
				table.insert(objectives, {
					description = obj.text or "Objective",
					progress = obj.numFulfilled or 0,
					required = obj.numRequired or 1,
					complete = obj.finished or false,
				})
			end
			if _G.PluribusQuestTracker then
				if _G.PluribusQuestTracker.AcceptQuest then
					pcall(function()
						_G.PluribusQuestTracker:AcceptQuest(questID, title, level, zone, objectives)
					end)
				end
				if _G.PluribusQuestTracker.RegisterQuest then
					pcall(function()
						_G.PluribusQuestTracker:RegisterQuest(questID, {
							name = title,
							giver = "Quest Log",
							level = level or 0,
							zone = zone,
							objectives = objectives,
							rewards = {},
							complete = isComplete or false,
						})
					end)
				end
			end
			loaded = loaded + 1
		end
	end

	-- Prune quests no longer in the live quest log
	if _G.PluribusQuestTracker and _G.PluribusQuestTracker.active_quests and count > 0 then
		for qid in pairs(_G.PluribusQuestTracker.active_quests) do
			if not seen[qid] then
				_G.PluribusQuestTracker.active_quests[qid] = nil
			end
		end
	end

	self.questsLoaded = math.max(self.questsLoaded or 0, loaded)
	return loaded
end

--- Begin syncing quests from optional QuestieDB
function QuestieDBSync:BeginSync()
	if not self.questieAvailable or self.syncInProgress then
		return
	end
	
	self.syncInProgress = true
	
	-- Sync in batches to avoid lag
	self:SyncBatch(1)
end

--- Sync a batch of quests from optional QuestieDB
function QuestieDBSync:SyncBatch(startId)
	if not self.questieAvailable then
		self.syncInProgress = false
		return
	end
	
	local endId = startId + self.maxSyncBatch
	local synced = 0
	
	if _G.QuestieDB and _G.QuestieDB.Quest then
		for questId = startId, endId do
			if _G.QuestieDB.Quest[questId] then
				local questData = _G.QuestieDB.Quest[questId]
				self:SyncQuest(questId, questData)
				synced = synced + 1
			end
		end
	end
	
	self.questsLoaded = self.questsLoaded + synced
	
	if synced > 0 and synced >= self.maxSyncBatch then
		C_Timer.After(0.5, function()
			self:SyncBatch(endId + 1)
		end)
	else
		self.syncInProgress = false
		PluribusUtils:Info("Optional QuestieDB sync complete: " .. self.questsLoaded .. " quests loaded", "QuestieSync")
		if PluribusMessaging then
			PluribusMessaging:Publish("quest_database_synced", self.questsLoaded)
		end
	end
end

--- Sync a single quest from optional QuestieDB
function QuestieDBSync:SyncQuest(questId, questData)
	if not PluribusQuestTracker or not questData then
		return
	end
	
	local questName = questData.name or ("Quest " .. questId)
	local questLevel = questData.level or 1
	local zone = questData.zone or "Unknown"
	
	local giver = "Unknown"
	if questData.start and _G.QuestieDB and _G.QuestieDB.NPC then
		local starterNPC = _G.QuestieDB.NPC[questData.start[1]]
		if starterNPC then
			giver = starterNPC.name or giver
		end
	end
	
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
	
	PluribusQuestTracker:RegisterQuest(questId, {
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
		standaloneMode = not self.questieAvailable,
		syncInProgress = self.syncInProgress,
		questsLoaded = self.questsLoaded,
	}
end

--- Display sync information
function QuestieDBSync:DisplayStatus()
	print("|cffffd700=== PluribusQuestie Sync Status ===|r")
	print("Mode: " .. (self.questieAvailable and "|cff00ff00Standalone + QuestieDB|r" or "|cff00ff00Standalone (Native WoW Quest Log)|r"))
	print("Sync Status: " .. (self.syncInProgress and "|cffffaa00In Progress|r" or "|cff00ff00Active|r"))
	print("Quests Tracked: " .. self.questsLoaded)
end

return QuestieDBSync
