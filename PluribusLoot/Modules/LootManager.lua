-- PluribusLoot - Loot Manager Module
-- Extracted and adapted from ClassicLootManager
-- Handles DKP/EPGP loot distribution system

PluribusLootManager = {
	db = {},
	currentRaid = nil,
	lootList = {},
	version = "1.0.0",
}

-- Initialize the loot manager
function PluribusLootManager:Initialize()
	PluribusUtils:Info("LootManager initializing...", "PluribusLoot")
	
	-- Load saved data
	self.db = PluribusStorageManager:GetFeatureSettings(PLURIBUS_FEATURES.LOOT) or {}
	
	-- Register core data structure
	self:RegisterDataStructures()
	
	PluribusUtils:Info("LootManager initialized", "PluribusLoot")
end

-- Register data structures with core
function PluribusLootManager:RegisterDataStructures()
	-- Register with data manager for aggregation
	PluribusDataManager:RegisterSource("loot_manager", function(data)
		PluribusUtils:Debug("Loot manager data updated", "PluribusLoot")
	end)
	
	-- Initialize default structure
	if not self.db.raids then
		self.db.raids = {}
	end
	
	if not self.db.standings then
		self.db.standings = {}
	end
	
	if not self.db.loot then
		self.db.loot = {}
	end
	
	if not self.db.settings then
		self.db.settings = {
			system = "dkp",  -- "dkp" or "epgp"
			defaultDkpPerKill = 100,
			defaultEpgpEp = 100,
			defaultEpgpGp = 1,
		}
	end
end

-- Create a new raid
function PluribusLootManager:CreateRaid(raidName, raidDate)
	local raidId = self:GenerateId()
	
	local raid = {
		id = raidId,
		name = raidName,
		date = raidDate or PluribusUtils:GetTimeStamp(),
		members = {},
		lootAwarded = {},
		active = true,
	}
	
	self.db.raids[raidId] = raid
	self.currentRaid = raidId
	
	-- Update in core system
	PluribusDataManager:UpdateSourceData("loot_manager", {
		raids = self.db.raids,
		currentRaid = self.currentRaid,
	})
	
	PluribusUtils:Info("Raid created: " .. raidName, "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_manager", "raid_created", raidId)
	
	return raidId
end

-- Add member to current raid
function PluribusLootManager:AddRaidMember(raidId, characterName, dkp, role)
	if not self.db.raids[raidId] then
		return false
	end
	
	local member = {
		name = characterName,
		dkp = dkp or 0,
		ep = 0,  -- EPGP equivalent
		gp = 0,  -- EPGP equivalent
		role = role or "DPS",
		joinedAt = PluribusUtils:GetTimeStamp(),
	}
	
	self.db.raids[raidId].members[characterName] = member
	
	PluribusUtils:Debug("Member added to raid: " .. characterName, "PluribusLoot")
	
	return true
end

-- Award loot to member
function PluribusLootManager:AwardLoot(raidId, memberName, itemLink, dkpCost, dkpAdjustment)
	if not self.db.raids[raidId] or not self.db.raids[raidId].members[memberName] then
		return false
	end
	
	local member = self.db.raids[raidId].members[memberName]
	local previousDkp = member.dkp
	
	-- Adjust DKP
	member.dkp = member.dkp - (dkpCost or 10)
	if dkpAdjustment then
		member.dkp = member.dkp + dkpAdjustment
	end
	
	-- Record loot award
	local lootRecord = {
		memberId = memberName,
		itemLink = itemLink,
		dkpCost = dkpCost or 10,
		previousDkp = previousDkp,
		newDkp = member.dkp,
		awardedAt = PluribusUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.raids[raidId].lootAwarded, lootRecord)
	
	PluribusUtils:Info(memberName .. " awarded: " .. itemLink, "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_manager", "loot_awarded", lootRecord)
	
	return true
end

-- Get DKP standings for raid
function PluribusLootManager:GetRaidStandings(raidId)
	if not self.db.raids[raidId] then
		return {}
	end
	
	local standings = {}
	for memberName, memberData in pairs(self.db.raids[raidId].members) do
		table.insert(standings, {
			name = memberName,
			dkp = memberData.dkp,
			role = memberData.role,
			joinedAt = memberData.joinedAt,
		})
	end
	
	-- Sort by DKP descending
	table.sort(standings, function(a, b)
		return a.dkp > b.dkp
	end)
	
	return standings
end

-- Get loot history
function PluribusLootManager:GetLootHistory(raidId, limit)
	if not self.db.raids[raidId] then
		return {}
	end
	
	limit = limit or 50
	local history = self.db.raids[raidId].lootAwarded
	
	-- Return most recent first
	local result = {}
	for i = #history, math.max(1, #history - limit + 1), -1 do
		table.insert(result, history[i])
	end
	
	return result
end

-- Helper function to generate unique IDs
function PluribusLootManager:GenerateId()
	if not self.db.nextId then
		self.db.nextId = 1
	end
	local id = "raid_" .. self.db.nextId
	self.db.nextId = self.db.nextId + 1
	return id
end

-- Sync with guild or raid
function PluribusLootManager:SyncRaidData(raidId)
	if not self.db.raids[raidId] then
		return false
	end
	
	-- Publish raid data for other members to receive
	PluribusMessaging:Publish("LOOT_MANAGER_SYNC_REQUEST", raidId, self.db.raids[raidId])
	
	PluribusUtils:Info("Raid data synced: " .. raidId, "PluribusLoot")
	return true
end

-- Get statistics
function PluribusLootManager:GetStatistics()
	local stats = {
		totalRaids = 0,
		totalMembers = 0,
		totalLootAwarded = 0,
		totalDkpSpent = 0,
	}
	
	for _, raid in pairs(self.db.raids) do
		stats.totalRaids = stats.totalRaids + 1
		stats.totalMembers = stats.totalMembers + (raid.members and #raid.members or 0)
		stats.totalLootAwarded = stats.totalLootAwarded + (raid.lootAwarded and #raid.lootAwarded or 0)
		
		for _, loot in pairs(raid.lootAwarded or {}) do
			stats.totalDkpSpent = stats.totalDkpSpent + (loot.dkpCost or 0)
		end
	end
	
	return stats
end

return PluribusLootManager

