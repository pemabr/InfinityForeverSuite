-- Infinity Loot History - Advanced Loot Tracking
-- Tracks all loot drops with player statistics and analytics

local InfinityLootHistory = {
	lootLog = {},
	playerStats = {},
	maxLogSize = 10000,
	version = 1,
}
_G.InfinityLootHistoryTracker = InfinityLootHistory

function InfinityLootHistory:Initialize()
	InfinityDataManager:RegisterSource("loot_history", function(data) end)
	InfinityUtils:Info("Loot History initialized", "LootHistory")
end

function InfinityLootHistory:Clear()
	self.lootLog, self.playerStats = {}, {}
end

function InfinityLootHistory:RecordLoot(itemID, itemName, rarity, dropSource, recipients)
	if not itemID or not itemName then
		return false
	end
	
	local entry = {
		timestamp = InfinityUtils:GetTimeStamp(),
		itemID = itemID,
		itemName = itemName,
		rarity = rarity or 0,
		dropSource = dropSource or "Unknown",
		recipients = recipients or {},
		session = InfinityCharacterManager:GetCurrentCharacter().name,
	}
	
	table.insert(self.lootLog, entry)
	
	-- Limit log size
	if #self.lootLog > self.maxLogSize then
		table.remove(self.lootLog, 1)
	end
	
	-- Update player statistics
	for _, recipient in ipairs(recipients or {}) do
		if not self.playerStats[recipient] then
			self.playerStats[recipient] = {
				name = recipient,
				lootCount = 0,
				lootValue = 0,
				itemsReceived = {},
			}
		end
		self.playerStats[recipient].lootCount = self.playerStats[recipient].lootCount + 1
		table.insert(self.playerStats[recipient].itemsReceived, itemName)
	end
	
	InfinityMessaging:Publish("loot_recorded", { item = itemName, recipients = recipients })
	return true
end

function InfinityLootHistory:GetLootBySource(source, limit)
	limit = limit or 50
	local result = {}
	
	for i = #self.lootLog, math.max(1, #self.lootLog - limit + 1), -1 do
		local entry = self.lootLog[i]
		if entry.dropSource == source or source == "all" then
			table.insert(result, entry)
		end
		if #result >= limit then
			break
		end
	end
	
	return result
end

function InfinityLootHistory:GetPlayerLootStats(playerName)
	return self.playerStats[playerName]
end

function InfinityLootHistory:GetLootStats()
	local stats = {
		totalItems = #self.lootLog,
		totalPlayers = 0,
		rarityBreakdown = {},
		topRecipients = {},
	}
	
	-- Count rarity
	for _, entry in ipairs(self.lootLog) do
		local rarity = entry.rarity or 0
		stats.rarityBreakdown[rarity] = (stats.rarityBreakdown[rarity] or 0) + 1
	end
	
	-- Get top recipients
	local sorted = {}
	for playerName, playerStat in pairs(self.playerStats) do
		table.insert(sorted, playerStat)
	end
	table.sort(sorted, function(a, b)
		return a.lootCount > b.lootCount
	end)
	
	for i = 1, math.min(10, #sorted) do
		table.insert(stats.topRecipients, sorted[i])
	end
	
	stats.totalPlayers = #sorted
	
	return stats
end

function InfinityLootHistory:ExportLootLog(limit)
	limit = limit or #self.lootLog
	local result = {}
	
	for i = #self.lootLog, math.max(1, #self.lootLog - limit + 1), -1 do
		table.insert(result, InfinityUtils:DeepCopy(self.lootLog[i]))
	end
	
	return result
end

function InfinityLootHistory:ClearOldLoot(daysOld)
	daysOld = daysOld or 30
	local cutoffTime = InfinityUtils:GetTimeStamp() - (daysOld * 86400)
	local removed = 0
	
	for i = #self.lootLog, 1, -1 do
		if self.lootLog[i].timestamp < cutoffTime then
			table.remove(self.lootLog, i)
			removed = removed + 1
		end
	end
	
	InfinityUtils:Info("Removed " .. removed .. " old loot entries", "LootHistory")
	return removed
end

return InfinityLootHistory
