-- Infinity Data Storage System
-- Central repository for all shared game data
-- Handles persistent storage and querying

local InfinityData = {
	storage = {
		quests = {}, -- {questID = questData}
		mobs = {}, -- {mobID = mobData}
		drops = {}, -- {itemID = dropData}
		nodes = {}, -- {nodeID = nodeData}
	},
	
	config = {
		enablePersistentStorage = true,
		maxStoredItems = 10000,
		cacheExpiry = 86400 * 30, -- 30 days
	},
}

_G.InfinityData = InfinityData

function InfinityData:Initialize()
	InfinityUtils:Info("Data Storage system initialized", "Data")
	
	-- Load persisted data from SavedVariables
	self:LoadFromPersistence()
end

-- Quest Storage
function InfinityData:StoreQuest(questID, questData)
	if not questID then return end
	
	self.storage.quests[questID] = questData
	questData.lastModified = time()
	
	-- Persist if enabled
	if self.config.enablePersistentStorage then
		self:PersistData()
	end
	
	InfinityMessaging:Publish("data_stored", "quest", questID)
end

function InfinityData:GetQuest(questID)
	return self.storage.quests[questID]
end

function InfinityData:CompleteQuest(questID)
	local questData = self.storage.quests[questID]
	if questData then
		questData.completed = true
		questData.completedAt = time()
		questData.lastModified = time()
		
		if self.config.enablePersistentStorage then
			self:PersistData()
		end
	end
end

function InfinityData:GetAllQuests()
	return self.storage.quests
end

function InfinityData:SearchQuests(query)
	local results = {}
	local lowerQuery = string.lower(query)
	
	for id, questData in pairs(self.storage.quests) do
		if questData.name and string.lower(questData.name):find(lowerQuery, 1, true) then
			table.insert(results, questData)
		end
	end
	
	return results
end

-- Mob Storage
function InfinityData:StoreMob(mobID, mobData)
	if not mobID then return end
	
	self.storage.mobs[mobID] = mobData
	mobData.lastModified = time()
	
	if self.config.enablePersistentStorage then
		self:PersistData()
	end
	
	InfinityMessaging:Publish("data_stored", "mob", mobID)
end

function InfinityData:GetMob(mobID)
	return self.storage.mobs[mobID]
end

function InfinityData:RecordMobKill(mobID)
	local mobData = self.storage.mobs[mobID]
	if mobData then
		mobData.kills = (mobData.kills or 0) + 1
		mobData.lastKilledAt = time()
		mobData.lastModified = time()
		
		if self.config.enablePersistentStorage then
			self:PersistData()
		end
	end
end

function InfinityData:GetAllMobs()
	return self.storage.mobs
end

function InfinityData:SearchMobs(query)
	local results = {}
	local lowerQuery = string.lower(query)
	
	for id, mobData in pairs(self.storage.mobs) do
		if mobData.name and string.lower(mobData.name):find(lowerQuery, 1, true) then
			table.insert(results, mobData)
		end
	end
	
	return results
end

function InfinityData:GetMobsByZone(zone)
	local results = {}
	
	for id, mobData in pairs(self.storage.mobs) do
		if mobData.zone == zone then
			table.insert(results, mobData)
		end
	end
	
	return results
end

-- Drop Storage
function InfinityData:StoreDrop(itemID, dropData)
	if not itemID then return end
	
	-- Store as array since multiple mobs can drop same item
	if not self.storage.drops[itemID] then
		self.storage.drops[itemID] = {}
	end
	
	-- Check for duplicates
	for _, existing in ipairs(self.storage.drops[itemID]) do
		if existing.source == dropData.source then
			existing.count = (existing.count or 1) + 1
			existing.lastSeen = time()
			return
		end
	end
	
	-- New drop record
	dropData.firstSeen = dropData.firstSeen or time()
	dropData.lastSeen = time()
	dropData.lastModified = time()
	table.insert(self.storage.drops[itemID], dropData)
	
	if self.config.enablePersistentStorage then
		self:PersistData()
	end
	
	InfinityMessaging:Publish("data_stored", "drop", itemID)
end

function InfinityData:GetDrop(itemID)
	return self.storage.drops[itemID]
end

function InfinityData:GetAllDrops()
	return self.storage.drops
end

function InfinityData:GetDropsByItem(itemID)
	return self.storage.drops[itemID] or {}
end

function InfinityData:GetDropsBySource(sourceName)
	local results = {}
	
	for itemID, dropArray in pairs(self.storage.drops) do
		for _, dropData in ipairs(dropArray) do
			if dropData.source == sourceName then
				table.insert(results, dropData)
			end
		end
	end
	
	return results
end

-- Node Storage
function InfinityData:StoreNode(nodeID, nodeData)
	if not nodeID then return end
	
	self.storage.nodes[nodeID] = nodeData
	nodeData.lastModified = time()
	
	if self.config.enablePersistentStorage then
		self:PersistData()
	end
	
	InfinityMessaging:Publish("data_stored", "node", nodeID)
end

function InfinityData:GetNode(nodeID)
	return self.storage.nodes[nodeID]
end

function InfinityData:RecordNodeGathering(nodeID)
	local nodeData = self.storage.nodes[nodeID]
	if nodeData then
		nodeData.gatherings = (nodeData.gatherings or 0) + 1
		nodeData.lastGatheredAt = time()
		nodeData.lastModified = time()
		
		if self.config.enablePersistentStorage then
			self:PersistData()
		end
	end
end

function InfinityData:GetAllNodes()
	return self.storage.nodes
end

function InfinityData:SearchNodes(query)
	local results = {}
	local lowerQuery = string.lower(query)
	
	for id, nodeData in pairs(self.storage.nodes) do
		if nodeData.name and string.lower(nodeData.name):find(lowerQuery, 1, true) then
			table.insert(results, nodeData)
		end
	end
	
	return results
end

function InfinityData:GetNodesByZone(zone, nodeType)
	local results = {}
	
	for id, nodeData in pairs(self.storage.nodes) do
		if nodeData.zone == zone then
			if not nodeType or nodeData.type == nodeType then
				table.insert(results, nodeData)
			end
		end
	end
	
	return results
end

-- Persistence
function InfinityData:PersistData()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
	end
	
	_G.InfinityForeverSavedData.questsDB = self.storage.quests
	_G.InfinityForeverSavedData.mobsDB = self.storage.mobs
	_G.InfinityForeverSavedData.dropsDB = self.storage.drops
	_G.InfinityForeverSavedData.nodesDB = self.storage.nodes
	_G.InfinityForeverSavedData.lastSaved = time()
	
	InfinityUtils:Debug("Data persisted to SavedVariables", "Data")
end

function InfinityData:LoadFromPersistence()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
		return
	end
	
	self.storage.quests = _G.InfinityForeverSavedData.questsDB or {}
	self.storage.mobs = _G.InfinityForeverSavedData.mobsDB or {}
	self.storage.drops = _G.InfinityForeverSavedData.dropsDB or {}
	self.storage.nodes = _G.InfinityForeverSavedData.nodesDB or {}
	
	local questCount = table.getn(self.storage.quests) or 0
	local mobCount = table.getn(self.storage.mobs) or 0
	local dropCount = table.getn(self.storage.drops) or 0
	local nodeCount = table.getn(self.storage.nodes) or 0
	
	InfinityUtils:Info(string.format("Loaded from persistence: %d quests, %d mobs, %d drops, %d nodes", 
		questCount, mobCount, dropCount, nodeCount), "Data")
end

-- Cleanup & Maintenance
function InfinityData:CleanupExpiredData()
	local now = time()
	local expiry = self.config.cacheExpiry
	
	-- Remove old quest data
	for id, questData in pairs(self.storage.quests) do
		if questData.lastModified and (now - questData.lastModified) > expiry then
			self.storage.quests[id] = nil
		end
	end
	
	-- Similar for mobs, drops, nodes...
	
	if self.config.enablePersistentStorage then
		self:PersistData()
	end
	
	InfinityUtils:Info("Cleaned up expired data", "Data")
end

function InfinityData:ClearAll()
	self.storage.quests = {}
	self.storage.mobs = {}
	self.storage.drops = {}
	self.storage.nodes = {}
	self:PersistData()
	InfinityUtils:Info("All data cleared", "Data")
end

function InfinityData:GetStorageStats()
	return {
		quests = table.getn(self.storage.quests) or 0,
		mobs = table.getn(self.storage.mobs) or 0,
		drops = table.getn(self.storage.drops) or 0,
		nodes = table.getn(self.storage.nodes) or 0,
	}
end

function InfinityData:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Data Storage config updated: " .. key .. " = " .. tostring(value), "Data")
	end
end

return InfinityData
