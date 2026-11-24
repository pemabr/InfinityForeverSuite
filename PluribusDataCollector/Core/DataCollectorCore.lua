-- PluribusDataCollector Core - Autonomous Data Gathering
-- Collects game data (quests, mobs, drops, nodes) without user input

PluribusDataCollectorCore = {
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

-- Quest data gathering
function PluribusDataCollectorCore:RecordQuestData(questID, questName, questLevel, questGiver, giver_x, giver_y, zone, objective, rewards)
	if type(questID) ~= "number" or questID <= 0 then
		return false
	end
	
	if not self.gatheredData.quests[questID] then
		self.gatheredData.quests[questID] = {
			id = questID,
			name = questName or "Unknown",
			level = questLevel or 0,
			giver = questGiver or "Unknown",
			giver_location = { x = giver_x or 0, y = giver_y or 0 },
			zone = zone or GetRealZoneText() or "Unknown",
			objective = objective or "Unknown",
			rewards = rewards or {},
			firstSeen = time(),
			lastUpdated = time(),
			instances = 0,
		}
	end
	
	self.lastUpdate.quest = time()
	self.gatheredData.quests[questID].instances = (self.gatheredData.quests[questID].instances or 0) + 1
	self.gatheredData.quests[questID].lastUpdated = time()
	
	return true
end

-- NPC data gathering (quest givers, vendors, etc)
function PluribusDataCollectorCore:RecordNPCData(npcID, npcName, npc_x, npc_y, zone, type_)
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
function PluribusDataCollectorCore:RecordMobData(mobID, mobName, mobLevel, mobType, mob_x, mob_y, zone, health, maxHealth)
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
function PluribusDataCollectorCore:RecordDropData(mobID, mobName, itemID, itemName, dropRate, rarity)
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
			dropRate = dropRate or 0,
			rarity = rarity or "common",
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
function PluribusDataCollectorCore:RecordNodeData(nodeType, nodeID, node_x, node_y, zone, nodeLevel, respawnTime)
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
function PluribusDataCollectorCore:GetQuestData(questID)
	return self.gatheredData.quests[questID]
end

function PluribusDataCollectorCore:GetNPCData(npcID)
	return self.gatheredData.npcs[npcID]
end

function PluribusDataCollectorCore:GetMobData(mobID)
	return self.gatheredData.mobs[mobID]
end

function PluribusDataCollectorCore:GetDropsForMob(mobID)
	local drops = {}
	for dropKey, dropData in pairs(self.gatheredData.drops) do
		if dropData.mobID == mobID then
			table.insert(drops, dropData)
		end
	end
	return drops
end

function PluribusDataCollectorCore:GetNodesByType(nodeType)
	local nodes = {}
	for nodeKey, nodeData in pairs(self.gatheredData.nodes) do
		if nodeData.type == nodeType then
			table.insert(nodes, nodeData)
		end
	end
	return nodes
end

-- Export data for sharing
function PluribusDataCollectorCore:ExportData()
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
function PluribusDataCollectorCore:GetStatistics()
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

function PluribusDataCollectorCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Enable/disable gathering
function PluribusDataCollectorCore:SetGatheringEnabled(enabled)
	self.gatheringEnabled = not not enabled
	return self.gatheringEnabled
end

function PluribusDataCollectorCore:IsGatheringEnabled()
	return self.gatheringEnabled
end
