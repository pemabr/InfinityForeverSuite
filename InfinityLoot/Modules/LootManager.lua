-- InfinityLoot - Loot Manager Module
-- Extracted and adapted from ClassicLootManager
-- Handles DKP/EPGP loot distribution system

InfinityLootManager = {
	db = {},
	currentRaid = nil,
	lootList = {},
	version = "1.0.0",
}

-- Initialize the loot manager
function InfinityLootManager:Initialize()
	InfinityUtils:Info("LootManager initializing...", "InfinityLoot")
	
	-- Load saved data
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	
	-- Register core data structure
	self:RegisterDataStructures()
	
	InfinityUtils:Info("LootManager initialized", "InfinityLoot")
end

-- Register data structures with core
function InfinityLootManager:RegisterDataStructures()
	-- Register with data manager for aggregation
	InfinityDataManager:RegisterSource("loot_manager", function(data)
		InfinityUtils:Debug("Loot manager data updated", "InfinityLoot")
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
function InfinityLootManager:CreateRaid(raidName, raidDate)
	local raidId = self:GenerateId()
	
	local raid = {
		id = raidId,
		name = raidName,
		date = raidDate or InfinityUtils:GetTimeStamp(),
		members = {},
		lootAwarded = {},
		active = true,
	}
	
	self.db.raids[raidId] = raid
	self.currentRaid = raidId
	
	-- Update in core system
	InfinityDataManager:UpdateSourceData("loot_manager", {
		raids = self.db.raids,
		currentRaid = self.currentRaid,
	})
	
	InfinityUtils:Info("Raid created: " .. raidName, "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_manager", "raid_created", raidId)
	
	return raidId
end

-- Add member to current raid
function InfinityLootManager:AddRaidMember(raidId, characterName, dkp, role)
	if not self.db.raids[raidId] then
		return false
	end
	
	local member = {
		name = characterName,
		dkp = dkp or 0,
		ep = 0,  -- EPGP equivalent
		gp = 0,  -- EPGP equivalent
		role = role or "DPS",
		joinedAt = InfinityUtils:GetTimeStamp(),
	}
	
	self.db.raids[raidId].members[characterName] = member
	
	InfinityUtils:Debug("Member added to raid: " .. characterName, "InfinityLoot")
	
	return true
end

-- Award loot to member
function InfinityLootManager:AwardLoot(raidId, memberName, itemLink, dkpCost, dkpAdjustment)
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
		awardedAt = InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.raids[raidId].lootAwarded, lootRecord)
	
	InfinityUtils:Info(memberName .. " awarded: " .. itemLink, "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_manager", "loot_awarded", lootRecord)
	
	return true
end

-- Get DKP standings for raid
function InfinityLootManager:GetRaidStandings(raidId)
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
function InfinityLootManager:GetLootHistory(raidId, limit)
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
function InfinityLootManager:GenerateId()
	if not self.db.nextId then
		self.db.nextId = 1
	end
	local id = "raid_" .. self.db.nextId
	self.db.nextId = self.db.nextId + 1
	return id
end

-- Sync with guild or raid
function InfinityLootManager:SyncRaidData(raidId)
	if not self.db.raids[raidId] then
		return false
	end
	
	-- Publish raid data for other members to receive
	InfinityMessaging:Publish("LOOT_MANAGER_SYNC_REQUEST", raidId, self.db.raids[raidId])
	
	InfinityUtils:Info("Raid data synced: " .. raidId, "InfinityLoot")
	return true
end

-- Get statistics
function InfinityLootManager:GetStatistics()
	local stats = {
		totalRaids = 0,
		totalMembers = 0,
		totalLootAwarded = 0,
		totalDkpSpent = 0,
	}
	
	for _, raid in pairs(self.db.raids) do
		stats.totalRaids = stats.totalRaids + 1
		for _ in pairs(raid.members or {}) do stats.totalMembers = stats.totalMembers + 1 end
		stats.totalLootAwarded = stats.totalLootAwarded + (raid.lootAwarded and #raid.lootAwarded or 0)
		
		for _, loot in pairs(raid.lootAwarded or {}) do
			stats.totalDkpSpent = stats.totalDkpSpent + (loot.dkpCost or 0)
		end
	end
	
	return stats
end

return InfinityLootManager

