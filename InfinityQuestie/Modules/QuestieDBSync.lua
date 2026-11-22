local QuestieDBSync = {
	questieAvailable = false,
	syncInProgress = false,
	questsLoaded = 0,
	maxSyncBatch = 100,
}
_G.InfinityQuestieDBSync = QuestieDBSync

function QuestieDBSync:Initialize()
	local lib = _G.LibQuestieDB
	if not lib then
		self.questieAvailable = false
		InfinityUtils:Info("QuestieDB unavailable; showing the live quest log.", "QuestieSync")
		return false
	end
	if self.source == lib and (self.syncInProgress or self.completed) then return true end
	if type(lib.RequireContract) ~= "function" or type(lib.Quest) ~= "table"
		or type(lib.Quest.GetAllIds) ~= "function" or type(lib.Quest.name) ~= "function"
		or type(lib.Quest.questLevel) ~= "function" then
		InfinityUtils:Warning("Unsupported QuestieDB API; quest database search unavailable.", "QuestieSync")
		return false
	end
	local ok, compatible, reason = pcall(lib.RequireContract, 1)
	if not ok then
		InfinityUtils:Warning("QuestieDB contract check failed: " .. tostring(compatible), "QuestieSync")
		return false
	elseif not compatible then
		InfinityUtils:Warning("QuestieDB incompatible: " .. tostring(reason), "QuestieSync")
		return false
	end
	local idsOK, ids = pcall(lib.Quest.GetAllIds)
	if not idsOK then
		InfinityUtils:Warning("QuestieDB quest list failed: " .. tostring(ids), "QuestieSync")
		return false
	end
	if type(ids) ~= "table" then
		InfinityUtils:Warning("QuestieDB returned an invalid quest list.", "QuestieSync")
		return false
	end
	if #ids > self.maxSyncBatch and not (_G.C_Timer and _G.C_Timer.After) then
		InfinityUtils:Warning("QuestieDB synchronization requires a timer.", "QuestieSync")
		return false
	end
	self.source = lib
	self.questieAvailable = true
	self.syncInProgress = true
	self.completed = false
	self.questsLoaded = 0
	return self:RunBatch(ids, 1)
end

function QuestieDBSync:RunBatch(ids, startIndex)
	local ok, err = pcall(self.SyncBatch, self, ids, startIndex)
	if not ok then
		self.syncInProgress = false
		self.completed = false
		InfinityUtils:Warning("QuestieDB synchronization failed: " .. tostring(err), "QuestieSync")
		return false
	end
	return true
end

function QuestieDBSync:SyncBatch(ids, startIndex)
	local last = math.min(startIndex + self.maxSyncBatch - 1, #ids)
	for index = startIndex, last do
		local id = ids[index]
		local name = self.source.Quest.name(id)
		local level = self.source.Quest.questLevel(id)
		if type(id) == "number" and type(name) == "string" and name ~= "" then
			InfinityQuestDB:RegisterQuest(id, { name = name, level = type(level) == "number" and level or 0 })
			self.questsLoaded = self.questsLoaded + 1
		end
	end
	if last < #ids then
		C_Timer.After(0, function() self:RunBatch(ids, last + 1) end)
	else
		self.syncInProgress = false
		self.completed = true
		InfinityUtils:Info("QuestieDB loaded: " .. self.questsLoaded .. " quests.", "QuestieSync")
		InfinityMessaging:Publish("quest_database_synced", self.questsLoaded)
	end
end

function QuestieDBSync:GetStatus()
	return {
		questieAvailable = self.questieAvailable,
		syncInProgress = self.syncInProgress,
		questsLoaded = self.questsLoaded,
	}
end

function QuestieDBSync:DisplayStatus()
	print("QuestieDB: " .. (self.questieAvailable and "available" or "unavailable")
		.. "; quests loaded: " .. self.questsLoaded)
end

return QuestieDBSync
