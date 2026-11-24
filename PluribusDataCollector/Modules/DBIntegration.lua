-- PluribusDataCollector Database Integration Module
-- Integration with external databases like QuestieDB, WowHead, etc

PluribusDataCollectorDBIntegration = {
	integrations = {},
	cacheData = {},
	version = 1,
}

-- Dynamic optional DB resolvers (handles naming/case variants across addons)
function PluribusDataCollectorDBIntegration:GetQuestieDB()
	return _G.QuestieDB or (_G.QuestieLoader and _G.QuestieLoader.ImportModule and select(2, pcall(_G.QuestieLoader.ImportModule, _G.QuestieLoader, "QuestieDB"))) or nil
end

function PluribusDataCollectorDBIntegration:GetWowHeadDB()
	return _G.WowHeadDB or _G.WoWHeadDB or _G.WowheadDB or nil
end

function PluribusDataCollectorDBIntegration:GetGathererDB()
	return _G.GathererDB or _G.GatherMate2DB or nil
end

-- Register an external or native database integration
function PluribusDataCollectorDBIntegration:RegisterDatabase(dbName, dbSource, updateCallback, isAvailable)
	if type(dbName) ~= "string" or dbName == "" then
		return false
	end
	
	if not self.integrations[dbName] then
		local available = (isAvailable == nil) and true or (not not isAvailable)
		self.integrations[dbName] = {
			name = dbName,
			source = dbSource,
			updateCallback = updateCallback,
			enabled = available,
			userDisabled = false,
			available = available,
			lastSync = 0,
			syncInterval = 3600,  -- 1 hour
			status = available and "ready" or "optional_not_installed",
		}
		
		PluribusUtils:Debug("Database integration registered: " .. dbName .. " (" .. self.integrations[dbName].status .. ")", "DBIntegration")
		return true
	end
	
	return false
end

-- Dynamically re-check optional external DBs (handles addons that load alphabetically later)
function PluribusDataCollectorDBIntegration:RefreshAvailability()
	local checks = {
		questiedb = self:GetQuestieDB() ~= nil,
		wowheaddb = self:GetWowHeadDB() ~= nil,
		gathererdb = self:GetGathererDB() ~= nil,
	}
	for dbName, isAvail in pairs(checks) do
		local entry = self.integrations[dbName]
		if entry then
			local wasAvail = entry.available
			entry.available = isAvail
			if isAvail then
				if not entry.userDisabled then
					entry.enabled = true
				end
				if entry.status == "optional_not_installed" then
					entry.status = "ready"
				end
				if not wasAvail then
					PluribusUtils:Info("Optional data source detected: " .. entry.source, "DBIntegration")
				end
			else
				entry.enabled = false
				entry.status = "optional_not_installed"
			end
		end
	end
end

-- Sync native live game data (100% standalone, no external DBs required)
function PluribusDataCollectorDBIntegration:SyncNativeGameData()
	local ok = pcall(function()
		if PluribusDataCollectorHooks and PluribusDataCollectorHooks.GatherQuestLogData then
			PluribusDataCollectorHooks:GatherQuestLogData()
		end
		if PluribusDataCollectorHooks and PluribusDataCollectorHooks.GatherTargetMobData then
			PluribusDataCollectorHooks:GatherTargetMobData()
		end
	end)
	if self.integrations["native"] then
		self.integrations["native"].status = ok and "synced" or "ready"
		self.integrations["native"].lastSync = time()
	end
	return ok
end

-- Sync with QuestieDB (optional)
function PluribusDataCollectorDBIntegration:SyncQuestieDB()
	local qdb = self:GetQuestieDB()
	if not qdb then
		if self.integrations["questiedb"] then
			self.integrations["questiedb"].available = false
			self.integrations["questiedb"].status = "optional_not_installed"
			self.integrations["questiedb"].lastSync = time()
			self.integrations["questiedb"].enabled = false
		end
		PluribusUtils:Debug("Optional QuestieDB not installed; using standalone live quest data", "DBIntegration")
		return false
	end
	
	local ok = pcall(function()
		local questDB = qdb.questData or qdb.Quest or {}
		local npcDB = qdb.npcData or qdb.NPC or {}
		
		for questID, questData in pairs(questDB) do
			if type(questID) == "number" and questID > 0 and type(questData) == "table" then
				local questName = questData.name or questData.title or questData[1] or "Unknown"
				local questLevel = questData.level or questData.minLevel or questData[7] or 0
				local zone = questData.zone or "Unknown"
				local objectives = questData.objectives or questData.description or ""
				
				PluribusDataCollectorCore:RecordQuestData(questID, questName, questLevel, nil, 0, 0, zone, objectives, {})
			end
		end
		
		for npcID, npcData in pairs(npcDB) do
			if type(npcID) == "number" and npcID > 0 and type(npcData) == "table" then
				local npcName = npcData.name or npcData[1] or "Unknown"
				local zone = npcData.zone or "Unknown"
				local x = npcData.x or 0
				local y = npcData.y or 0
				local npcType = npcData.questGiver and "quest_giver" or "npc"
				
				PluribusDataCollectorCore:RecordNPCData(npcID, npcName, x, y, zone, npcType)
			end
		end
		
		if self.integrations["questiedb"] then
			self.integrations["questiedb"].available = true
			self.integrations["questiedb"].status = "synced"
			self.integrations["questiedb"].lastSync = time()
		end
		
		PluribusUtils:Info("Optional QuestieDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Sync with WowHead data (optional)
function PluribusDataCollectorDBIntegration:SyncWowHeadDB()
	local whdb = self:GetWowHeadDB()
	if not whdb then
		if self.integrations["wowheaddb"] then
			self.integrations["wowheaddb"].available = false
			self.integrations["wowheaddb"].status = "optional_not_installed"
			self.integrations["wowheaddb"].lastSync = time()
			self.integrations["wowheaddb"].enabled = false
		end
		PluribusUtils:Debug("Optional WowHeadDB not installed; using standalone live mob/loot data", "DBIntegration")
		return false
	end
	
	local ok = pcall(function()
		local mobDB = whdb.mobs or whdb.Mobs or {}
		local dropDB = whdb.drops or whdb.Drops or {}
		
		for mobID, mobData in pairs(mobDB) do
			if type(mobID) == "number" and mobID > 0 and type(mobData) == "table" then
				local mobName = mobData.name or "Unknown"
				local mobLevel = mobData.level or 0
				local mobType = mobData.type or "unknown"
				local zone = mobData.zone or "Unknown"
				local health = mobData.health or 0
				
				PluribusDataCollectorCore:RecordMobData(mobID, mobName, mobLevel, mobType, 0, 0, zone, 0, health)
			end
		end
		
		for _, dropData in pairs(dropDB) do
			if type(dropData) == "table" and dropData.mobID and dropData.itemID then
				PluribusDataCollectorCore:RecordDropData(
					dropData.mobID,
					dropData.mobName or "Unknown",
					dropData.itemID,
					dropData.itemName or "Unknown",
					dropData.dropRate or 0,
					dropData.rarity or "common"
				)
			end
		end
		
		if self.integrations["wowheaddb"] then
			self.integrations["wowheaddb"].available = true
			self.integrations["wowheaddb"].status = "synced"
			self.integrations["wowheaddb"].lastSync = time()
		end
		
		PluribusUtils:Info("Optional WowHeadDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Sync with GathererDB / GatherMate2 (optional)
function PluribusDataCollectorDBIntegration:SyncGathererDB()
	local gdb = self:GetGathererDB()
	if not gdb then
		if self.integrations["gathererdb"] then
			self.integrations["gathererdb"].available = false
			self.integrations["gathererdb"].status = "optional_not_installed"
			self.integrations["gathererdb"].lastSync = time()
			self.integrations["gathererdb"].enabled = false
		end
		PluribusUtils:Debug("Optional GathererDB not installed; using standalone live gathering recorder", "DBIntegration")
		return false
	end
	
	local ok = pcall(function()
		local nodeDB = gdb.nodes or gdb
		
		for nodeType, nodes in pairs(nodeDB) do
			if type(nodes) == "table" then
				for nodeID, nodeData in pairs(nodes) do
					if type(nodeData) == "table" and nodeData.x and nodeData.y then
						PluribusDataCollectorCore:RecordNodeData(
							tostring(nodeType),
							nodeID,
							nodeData.x,
							nodeData.y,
							nodeData.zone or "Unknown",
							nodeData.level or 0,
							nodeData.respawnTime or 300
						)
						if _G.PluribusNodeDB and _G.PluribusNodeDB.RecordNode then
							pcall(function()
								_G.PluribusNodeDB:RecordNode(tostring(nodeType), nodeData.x, nodeData.y, nodeData.zone or "Unknown", nodeData.respawnTime or 300)
							end)
						end
					end
				end
			end
		end
		
		if self.integrations["gathererdb"] then
			self.integrations["gathererdb"].available = true
			self.integrations["gathererdb"].status = "synced"
			self.integrations["gathererdb"].lastSync = time()
		end
		
		PluribusUtils:Info("Optional GathererDB sync complete", "DBIntegration")
	end)
	
	return ok
end

-- Perform all active syncs (always includes standalone native data + any installed optional DBs)
function PluribusDataCollectorDBIntegration:SyncAll()
	self:RefreshAvailability()
	local synced = {}
	
	for dbName, integration in pairs(self.integrations) do
		if integration.enabled then
			if dbName == "native" then
				table.insert(synced, {name = "Native WoW Data (Standalone)", success = self:SyncNativeGameData()})
			elseif dbName == "questiedb" and integration.available then
				table.insert(synced, {name = integration.source, success = self:SyncQuestieDB()})
			elseif dbName == "wowheaddb" and integration.available then
				table.insert(synced, {name = integration.source, success = self:SyncWowHeadDB()})
			elseif dbName == "gathererdb" and integration.available then
				table.insert(synced, {name = integration.source, success = self:SyncGathererDB()})
			end
		end
	end
	
	return synced
end

-- Enable/disable an integration
function PluribusDataCollectorDBIntegration:SetIntegrationEnabled(dbName, enabled)
	if self.integrations[dbName] then
		local flag = not not enabled
		self.integrations[dbName].enabled = flag
		self.integrations[dbName].userDisabled = not flag
		return true
	end
	return false
end

-- Set sync interval for a database
function PluribusDataCollectorDBIntegration:SetSyncInterval(dbName, seconds)
	if self.integrations[dbName] and type(seconds) == "number" and seconds > 0 then
		self.integrations[dbName].syncInterval = seconds
		return true
	end
	return false
end

-- Auto-sync databases (call this periodically)
function PluribusDataCollectorDBIntegration:AutoSync()
	self:RefreshAvailability()
	local now = time()
	local synced = {}
	
	for dbName, integration in pairs(self.integrations) do
		if integration.enabled and (now - (integration.lastSync or 0)) >= (integration.syncInterval or 1800) then
			if dbName == "native" then
				table.insert(synced, {name = dbName, success = self:SyncNativeGameData()})
			elseif dbName == "questiedb" and integration.available then
				table.insert(synced, {name = dbName, success = self:SyncQuestieDB()})
			elseif dbName == "wowheaddb" and integration.available then
				table.insert(synced, {name = dbName, success = self:SyncWowHeadDB()})
			elseif dbName == "gathererdb" and integration.available then
				table.insert(synced, {name = dbName, success = self:SyncGathererDB()})
			end
		end
	end
	
	return synced
end

-- Get integration status
function PluribusDataCollectorDBIntegration:GetIntegrationStatus(dbName)
	local e = self.integrations[dbName]
	if e then
		return {
			name = e.name,
			source = e.source,
			enabled = e.enabled,
			available = e.available,
			status = e.status,
			lastSync = e.lastSync,
			syncInterval = e.syncInterval,
		}
	end
	return nil
end

-- Get all integration statuses
function PluribusDataCollectorDBIntegration:GetAllIntegrationStatuses()
	self:RefreshAvailability()
	local order = { "native", "questiedb", "wowheaddb", "gathererdb" }
	local statuses = {}
	local added = {}
	for _, dbName in ipairs(order) do
		if self.integrations[dbName] then
			table.insert(statuses, self:GetIntegrationStatus(dbName))
			added[dbName] = true
		end
	end
	for dbName in pairs(self.integrations) do
		if not added[dbName] then
			table.insert(statuses, self:GetIntegrationStatus(dbName))
		end
	end
	return statuses
end

-- Initialize default database integrations (standalone native always active; external DBs optional & auto-detected)
function PluribusDataCollectorDBIntegration:InitializeDefaultIntegrations()
	self:RegisterDatabase("native", "Native WoW Live Data", nil, true)
	self:RegisterDatabase("questiedb", "QuestieDB (Optional)", nil, self:GetQuestieDB() ~= nil)
	self:RegisterDatabase("wowheaddb", "WoWHeadDB (Optional)", nil, self:GetWowHeadDB() ~= nil)
	self:RegisterDatabase("gathererdb", "GathererDB / GatherMate2 (Optional)", nil, self:GetGathererDB() ~= nil)
	
	-- Set default sync intervals
	self:SetSyncInterval("native", 300)        -- 5 minutes
	self:SetSyncInterval("questiedb", 3600)    -- 1 hour (when installed)
	self:SetSyncInterval("wowheaddb", 7200)    -- 2 hours (when installed)
	self:SetSyncInterval("gathererdb", 1800)   -- 30 minutes (when installed)
end
