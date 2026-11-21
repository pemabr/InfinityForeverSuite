-- InfinityDataCollector Database Integration Module
-- Integration with external databases like QuestieDB, WowHead, etc

InfinityDataCollectorDBIntegration = {
	integrations = {},
	cacheData = {},
	version = 1,
}

-- Register an external database integration
function InfinityDataCollectorDBIntegration:RegisterDatabase(dbName, dbSource, updateCallback)
	if type(dbName) ~= "string" or dbName == "" then
		return false
	end
	
	if not self.integrations[dbName] then
		self.integrations[dbName] = {
			name = dbName,
			source = dbSource,
			updateCallback = updateCallback,
			enabled = true,
			lastSync = 0,
			syncInterval = 3600,  -- 1 hour
			status = "not_loaded",
		}
		
		InfinityUtils:Info("Database integration registered: " .. dbName, "DBIntegration")
		return true
	end
	
	return false
end

-- Sync with QuestieDB
function InfinityDataCollectorDBIntegration:SyncQuestieDB()
	local integration = self.integrations["questiedb"]
	if integration then
		integration.lastSync = time()
	end
	if not _G.QuestieDB then
		if integration and integration.status ~= "not_loaded" then
			integration.status = "not_loaded"
			InfinityUtils:Info("QuestieDB not found, skipping sync", "DBIntegration")
		end
		return false
	end
	
	local ok = pcall(function()
		local questDB = _G.QuestieDB.questData or {}
		local npcDB = _G.QuestieDB.npcData or {}
		
		-- Import quests
		for questID, questData in pairs(questDB) do
			if type(questID) == "number" and questID > 0 and type(questData) == "table" then
				local questName = questData.name or questData.title or "Unknown"
				local questLevel = questData.level or questData.minLevel or 0
				local zone = questData.zone or "Unknown"
				local objectives = questData.objectives or questData.description or ""
				
				-- Record quest
				InfinityDataCollectorCore:RecordQuestData(questID, questName, questLevel, nil, 0, 0, zone, objectives, {})
			end
		end
		
		-- Import NPCs (quest givers)
		for npcID, npcData in pairs(npcDB) do
			if type(npcID) == "number" and npcID > 0 and type(npcData) == "table" then
				local npcName = npcData.name or "Unknown"
				local zone = npcData.zone or "Unknown"
				local x = npcData.x or 0
				local y = npcData.y or 0
				local npcType = "npc"
				
				if npcData.questGiver then
					npcType = "quest_giver"
				end
				
				InfinityDataCollectorCore:RecordNPCData(npcID, npcName, x, y, zone, npcType)
			end
		end
		
		if integration then
			integration.status = "synced"
			integration.lastSync = time()
		end
		
		InfinityUtils:Info("QuestieDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Sync with WowHead data (if available)
function InfinityDataCollectorDBIntegration:SyncWowHeadDB()
	local integration = self.integrations["wowheaddb"]
	if integration then
		integration.lastSync = time()
	end
	if not _G.WowHeadDB then
		if integration and integration.status ~= "not_loaded" then
			integration.status = "not_loaded"
			InfinityUtils:Info("WowHeadDB not found, skipping sync", "DBIntegration")
		end
		return false
	end
	
	local ok = pcall(function()
		local mobDB = _G.WowHeadDB.mobs or {}
		local dropDB = _G.WowHeadDB.drops or {}
		
		-- Import mobs
		for mobID, mobData in pairs(mobDB) do
			if type(mobID) == "number" and mobID > 0 and type(mobData) == "table" then
				local mobName = mobData.name or "Unknown"
				local mobLevel = mobData.level or 0
				local mobType = mobData.type or "unknown"
				local zone = mobData.zone or "Unknown"
				local health = mobData.health or 0
				
				InfinityDataCollectorCore:RecordMobData(mobID, mobName, mobLevel, mobType, 0, 0, zone, 0, health)
			end
		end
		
		-- Import drops
		for dropKey, dropData in pairs(dropDB) do
			if type(dropData) == "table" and dropData.mobID and dropData.itemID then
				local mobID = dropData.mobID
				local mobName = dropData.mobName or "Unknown"
				local itemID = dropData.itemID
				local itemName = dropData.itemName or "Unknown"
				local dropRate = dropData.dropRate or 0
				local rarity = dropData.rarity or "common"
				
				InfinityDataCollectorCore:RecordDropData(mobID, mobName, itemID, itemName, dropRate, rarity)
			end
		end
		
		if integration then
			integration.status = "synced"
			integration.lastSync = time()
		end
		
		InfinityUtils:Info("WowHeadDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Sync with GathererDB
function InfinityDataCollectorDBIntegration:SyncGathererDB()
	local integration = self.integrations["gathererdb"]
	if integration then
		integration.lastSync = time()
	end
	if not _G.GathererDB then
		if integration and integration.status ~= "not_loaded" then
			integration.status = "not_loaded"
			InfinityUtils:Info("GathererDB not found, skipping sync", "DBIntegration")
		end
		return false
	end
	
	local ok = pcall(function()
		local nodeDB = _G.GathererDB.nodes or {}
		
		-- Import nodes
		for nodeType, nodes in pairs(nodeDB) do
			if type(nodes) == "table" then
				for nodeID, nodeData in pairs(nodes) do
					if type(nodeData) == "table" and nodeData.x and nodeData.y then
						local zone = nodeData.zone or "Unknown"
						local x = nodeData.x
						local y = nodeData.y
						local level = nodeData.level or 0
						local respawnTime = nodeData.respawnTime or 300
						
						InfinityDataCollectorCore:RecordNodeData(nodeType, nodeID, x, y, zone, level, respawnTime)
					end
				end
			end
		end
		
		if integration then
			integration.status = "synced"
			integration.lastSync = time()
		end
		
		InfinityUtils:Info("GathererDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Perform all configured syncs
function InfinityDataCollectorDBIntegration:SyncAll()
	local synced = {}
	
	for dbName, integration in pairs(self.integrations) do
		if integration.enabled then
			if dbName == "questiedb" then
				table.insert(synced, {name = dbName, success = self:SyncQuestieDB()})
			elseif dbName == "wowheaddb" then
				table.insert(synced, {name = dbName, success = self:SyncWowHeadDB()})
			elseif dbName == "gathererdb" then
				table.insert(synced, {name = dbName, success = self:SyncGathererDB()})
			end
		end
	end
	
	return synced
end

-- Enable/disable an integration
function InfinityDataCollectorDBIntegration:SetIntegrationEnabled(dbName, enabled)
	if self.integrations[dbName] then
		self.integrations[dbName].enabled = not not enabled
		return true
	end
	return false
end

-- Set sync interval for a database
function InfinityDataCollectorDBIntegration:SetSyncInterval(dbName, seconds)
	if self.integrations[dbName] and type(seconds) == "number" and seconds > 0 then
		self.integrations[dbName].syncInterval = seconds
		return true
	end
	return false
end

-- Auto-sync databases (call this periodically)
function InfinityDataCollectorDBIntegration:AutoSync()
	local now = time()
	local synced = {}
	
	for dbName, integration in pairs(self.integrations) do
		if integration.enabled and (now - integration.lastSync) >= integration.syncInterval then
			integration.lastSync = now
			if dbName == "questiedb" then
				if _G.QuestieDB then
					table.insert(synced, {name = dbName, success = self:SyncQuestieDB()})
				else
					integration.status = "not_loaded"
				end
			elseif dbName == "wowheaddb" then
				if _G.WowHeadDB then
					table.insert(synced, {name = dbName, success = self:SyncWowHeadDB()})
				else
					integration.status = "not_loaded"
				end
			elseif dbName == "gathererdb" then
				if _G.GathererDB then
					table.insert(synced, {name = dbName, success = self:SyncGathererDB()})
				else
					integration.status = "not_loaded"
				end
			end
		end
	end
	
	return synced
end

-- Get integration status
function InfinityDataCollectorDBIntegration:GetIntegrationStatus(dbName)
	if self.integrations[dbName] then
		return {
			name = self.integrations[dbName].name,
			enabled = self.integrations[dbName].enabled,
			status = self.integrations[dbName].status,
			lastSync = self.integrations[dbName].lastSync,
			syncInterval = self.integrations[dbName].syncInterval,
		}
	end
	return nil
end

-- Get all integration statuses
function InfinityDataCollectorDBIntegration:GetAllIntegrationStatuses()
	local statuses = {}
	for dbName in pairs(self.integrations) do
		table.insert(statuses, self:GetIntegrationStatus(dbName))
	end
	return statuses
end

-- Initialize default database integrations
function InfinityDataCollectorDBIntegration:InitializeDefaultIntegrations()
	self:RegisterDatabase("questiedb", "QuestieDB", nil)
	self:RegisterDatabase("wowheaddb", "WowHeadDB", nil)
	self:RegisterDatabase("gathererdb", "GathererDB", nil)
	
	-- Set default sync intervals
	self:SetSyncInterval("questiedb", 3600)    -- 1 hour
	self:SetSyncInterval("wowheaddb", 7200)    -- 2 hours
	self:SetSyncInterval("gathererdb", 1800)   -- 30 minutes
end
