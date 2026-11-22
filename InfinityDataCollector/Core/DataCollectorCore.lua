-- InfinityDataCollector Core - Autonomous Data Gathering
-- Collects game data (quests, mobs, drops, nodes) without user input

InfinityDataCollectorCore = {
	gatheringEnabled = true,
	gatheredData = {
		quests = {},
		mobs = {},
		drops = {},
		nodes = {},
		npcs = {},
	},
	version = 1,
	lastUpdate = {},
}

function InfinityDataCollectorCore:Initialize()
	local db = InfinityCore:GetDatabase("InfinityDataCollector")
	if type(db) ~= "table" then error("Data collector database unavailable") end
	if db.gatheredData == nil then db.gatheredData = { quests = {}, mobs = {}, drops = {}, nodes = {}, npcs = {} } end
	if db.lastUpdate == nil then db.lastUpdate = {} end
	if db.gatheringEnabled == nil then db.gatheringEnabled = true end
	if type(db.gatheredData) ~= "table" or type(db.lastUpdate) ~= "table"
		or type(db.gatheringEnabled) ~= "boolean" then error("Invalid saved data collector settings") end
	for _, key in ipairs({ "quests", "mobs", "drops", "nodes", "npcs" }) do
		if type(db.gatheredData[key]) ~= "table" then error("Invalid saved collector data: " .. key) end
	end
	self.db = db
	self.gatheredData = db.gatheredData
	self.lastUpdate = db.lastUpdate
	self.gatheringEnabled = db.gatheringEnabled
end

-- Quest data gathering
function InfinityDataCollectorCore:RecordQuestData(questID, questName, questLevel, questGiver, giver_x, giver_y, zone, objective, rewards)
	if type(questID) ~= "number" or questID <= 0 then
		return false
	end
	
	if not self.gatheredData.quests[questID] then
		self.gatheredData.quests[questID] = {
			id = questID,
			name = questName or "Unknown",
			level = questLevel or 0,
			giver = questGiver or "Unknown",
			giver_location = type(giver_x) == "number" and type(giver_y) == "number"
				and (giver_x ~= 0 or giver_y ~= 0) and { x = giver_x, y = giver_y } or nil,
			zone = zone or "Unknown",
			objective = objective or "Unknown",
			rewards = rewards or {},
			firstSeen = time(),
			lastUpdated = time(),
			instances = 0,
		}
	end
	local quest = self.gatheredData.quests[questID]
	if questName and questName ~= "Unknown" then quest.name = questName end
	if questLevel and questLevel > 0 then quest.level = questLevel end
	if questGiver and questGiver ~= "Unknown" then quest.giver = questGiver end
	if zone and zone ~= "Unknown" then quest.zone = zone end
	if objective and objective ~= "" and objective ~= "Unknown" then quest.objective = objective end

	self.lastUpdate.quest = time()
	self.gatheredData.quests[questID].instances = (self.gatheredData.quests[questID].instances or 0) + 1
	self.gatheredData.quests[questID].lastUpdated = time()
	
	return true
end

-- NPC data gathering (quest givers, vendors, etc)
function InfinityDataCollectorCore:RecordNPCData(npcID, npcName, npc_x, npc_y, zone, type_)
	if type(npcID) ~= "number" or npcID <= 0 then
		return false
	end
	
	if not self.gatheredData.npcs[npcID] then
		self.gatheredData.npcs[npcID] = {
			id = npcID,
			name = npcName or "Unknown",
			locations = {},
			type = type_ or "unknown",
			firstSeen = time(),
			lastUpdated = time(),
			sightings = 0,
		}
	end
	
	-- Record location
	local locKey = string.format("%s_%.0f_%.0f", zone or "unknown", npc_x or 0, npc_y or 0)
	if not self.gatheredData.npcs[npcID].locations[locKey] then
		self.gatheredData.npcs[npcID].locations[locKey] = {
			zone = zone or GetRealZoneText() or "Unknown",
			x = npc_x or 0,
			y = npc_y or 0,
			sightings = 0,
		}
	end
	
	self.gatheredData.npcs[npcID].locations[locKey].sightings = (self.gatheredData.npcs[npcID].locations[locKey].sightings or 0) + 1
	self.gatheredData.npcs[npcID].sightings = (self.gatheredData.npcs[npcID].sightings or 0) + 1
	self.lastUpdate.npc = time()
	
	return true
end

-- Mob data gathering (health, type, etc)
function InfinityDataCollectorCore:RecordMobData(mobID, mobName, mobLevel, mobType, mob_x, mob_y, zone, health, maxHealth)
	if type(mobID) ~= "number" or mobID <= 0 then
		return false
	end
	
	if not self.gatheredData.mobs[mobID] then
		self.gatheredData.mobs[mobID] = {
			id = mobID,
			name = mobName or "Unknown",
			level = mobLevel or 0,
			type = mobType or "unknown",
			locations = {},
			avgHealth = maxHealth or 0,
			sightings = 0,
			firstSeen = time(),
			lastUpdated = time(),
		}
	end
	
	-- Record location
	local locKey = string.format("%s_%.0f_%.0f", zone or "unknown", mob_x or 0, mob_y or 0)
	if not self.gatheredData.mobs[mobID].locations[locKey] then
		self.gatheredData.mobs[mobID].locations[locKey] = {
			zone = zone or GetRealZoneText() or "Unknown",
			x = mob_x or 0,
			y = mob_y or 0,
			sightings = 0,
		}
	end
	
	self.gatheredData.mobs[mobID].locations[locKey].sightings = (self.gatheredData.mobs[mobID].locations[locKey].sightings or 0) + 1
	self.gatheredData.mobs[mobID].sightings = (self.gatheredData.mobs[mobID].sightings or 0) + 1
	
	-- Update average health
	if maxHealth and maxHealth > 0 then
		self.gatheredData.mobs[mobID].avgHealth = maxHealth
	end
	
	self.lastUpdate.mob = time()
	
	return true
end

-- Drop data gathering (what items drop from what mobs)
function InfinityDataCollectorCore:RecordDropData(mobID, mobName, itemID, itemName, dropRate, rarity)
	if type(mobID) ~= "number" or mobID <= 0 or type(itemID) ~= "number" or itemID <= 0 then
		return false
	end
	
	local dropKey = string.format("%d_%d", mobID, itemID)
	
	if not self.gatheredData.drops[dropKey] then
		self.gatheredData.drops[dropKey] = {
			mobID = mobID,
			mobName = mobName or "Unknown",
			itemID = itemID,
			itemName = itemName or "Unknown",
			dropRate = dropRate,
			rarity = rarity,
			sightings = 0,
			firstSeen = time(),
			lastUpdated = time(),
		}
	end
	
	self.gatheredData.drops[dropKey].sightings = (self.gatheredData.drops[dropKey].sightings or 0) + 1
	self.gatheredData.drops[dropKey].lastUpdated = time()
	self.lastUpdate.drop = time()
	
	return true
end

-- Gathering node data (herbs, ore, fish, etc)
function InfinityDataCollectorCore:RecordNodeData(nodeType, nodeID, node_x, node_y, zone, nodeLevel, respawnTime)
	if type(nodeType) ~= "string" or nodeType == "" or type(nodeID) ~= "number" or nodeID <= 0 then
		return false
	end
	
	local nodeKey = string.format("%s_%d", nodeType, nodeID)
	
	if not self.gatheredData.nodes[nodeKey] then
		self.gatheredData.nodes[nodeKey] = {
			type = nodeType,
			id = nodeID,
			locations = {},
			level = nodeLevel or 0,
			respawnTime = respawnTime or 300,
			sightings = 0,
			firstSeen = time(),
			lastUpdated = time(),
		}
	end
	
	-- Record location
	local locKey = string.format("%.0f_%.0f", node_x or 0, node_y or 0)
	if not self.gatheredData.nodes[nodeKey].locations[locKey] then
		self.gatheredData.nodes[nodeKey].locations[locKey] = {
			zone = zone or GetRealZoneText() or "Unknown",
			x = node_x or 0,
			y = node_y or 0,
			sightings = 0,
			lastSeen = time(),
		}
	end
	
	self.gatheredData.nodes[nodeKey].locations[locKey].sightings = (self.gatheredData.nodes[nodeKey].locations[locKey].sightings or 0) + 1
	self.gatheredData.nodes[nodeKey].locations[locKey].lastSeen = time()
	self.gatheredData.nodes[nodeKey].sightings = (self.gatheredData.nodes[nodeKey].sightings or 0) + 1
	self.lastUpdate.node = time()
	
	return true
end

-- Query functions
function InfinityDataCollectorCore:GetQuestData(questID)
	return self.gatheredData.quests[questID]
end

function InfinityDataCollectorCore:GetNPCData(npcID)
	return self.gatheredData.npcs[npcID]
end

function InfinityDataCollectorCore:GetMobData(mobID)
	return self.gatheredData.mobs[mobID]
end

function InfinityDataCollectorCore:GetDropsForMob(mobID)
	local drops = {}
	for dropKey, dropData in pairs(self.gatheredData.drops) do
		if dropData.mobID == mobID then
			table.insert(drops, dropData)
		end
	end
	return drops
end

function InfinityDataCollectorCore:GetNodesByType(nodeType)
	local nodes = {}
	for nodeKey, nodeData in pairs(self.gatheredData.nodes) do
		if nodeData.type == nodeType then
			table.insert(nodes, nodeData)
		end
	end
	return nodes
end

-- Export data for sharing
function InfinityDataCollectorCore:ExportData()
	return {
		quests = self.gatheredData.quests,
		mobs = self.gatheredData.mobs,
		drops = self.gatheredData.drops,
		nodes = self.gatheredData.nodes,
		npcs = self.gatheredData.npcs,
		exportTime = time(),
		version = self.version,
	}
end

-- Get statistics
function InfinityDataCollectorCore:GetStatistics()
	return {
		questCount = self:CountTable(self.gatheredData.quests),
		mobCount = self:CountTable(self.gatheredData.mobs),
		dropCount = self:CountTable(self.gatheredData.drops),
		nodeCount = self:CountTable(self.gatheredData.nodes),
		npcCount = self:CountTable(self.gatheredData.npcs),
		lastQuestUpdate = self.lastUpdate.quest,
		lastMobUpdate = self.lastUpdate.mob,
		lastNodeUpdate = self.lastUpdate.node,
		lastDropUpdate = self.lastUpdate.drop,
	}
end

function InfinityDataCollectorCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Enable/disable gathering
function InfinityDataCollectorCore:SetGatheringEnabled(enabled)
	self.gatheringEnabled = not not enabled
	if self.db then self.db.gatheringEnabled = self.gatheringEnabled end
	return self.gatheringEnabled
end

function InfinityDataCollectorCore:IsGatheringEnabled()
	return self.gatheringEnabled
end
