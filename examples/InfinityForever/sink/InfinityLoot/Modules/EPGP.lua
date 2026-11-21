-- InfinityLoot EPGP System
-- Effort Points / Gear Points loot distribution

InfinityLootEPGP = {
	players = {},
	settings = {
		epPerKill = 100,
		gpBaseValue = 1,
		decayPercent = 10,
		decayInterval = 86400, -- 24 hours
	},
	transactionHistory = {}, -- Complete audit trail
	version = 1,
}

function InfinityLootEPGP:Initialize()
	InfinityUtils:Info("EPGP system initialized", "EPGP")
end

function InfinityLootEPGP:AddPlayer(playerName, ep, gp)
	if not playerName or playerName == "" then
		return false
	end
	
	ep = ep or 0
	gp = gp or 0
	
	if not self.players[playerName] then
		self.players[playerName] = {
			name = playerName,
			ep = ep,
			gp = gp,
			priority = 0, -- ep / max(gp, 1)
			lootCount = 0,
			lastUpdated = InfinityUtils:GetTimeStamp(),
		}
		
		-- Log player creation
		self:LogTransaction({
			type = "player_created",
			playerName = playerName,
			oldEP = 0,
			newEP = ep,
			oldGP = 0,
			newGP = gp,
			reason = "Player added to system",
		})
	else
		self.players[playerName].ep = ep
		self.players[playerName].gp = gp
		self.players[playerName].lastUpdated = InfinityUtils:GetTimeStamp()
	end
	
	self:UpdatePlayerPriority(playerName)
	InfinityMessaging:Publish("epgp_updated", { player = playerName })
	return true
end

function InfinityLootEPGP:AwardEP(playerName, amount, reason)
	if not self.players[playerName] then
		return false
	end
	
	local oldEP = self.players[playerName].ep
	self.players[playerName].ep = self.players[playerName].ep + amount
	local newEP = self.players[playerName].ep
	
	self:UpdatePlayerPriority(playerName)
	self:LogTransaction({
		type = "ep_awarded",
		playerName = playerName,
		oldEP = oldEP,
		newEP = newEP,
		amount = amount,
		reason = reason or "EP Award",
	})
	
	InfinityMessaging:Publish("ep_awarded", { player = playerName, amount = amount })
	
	InfinityUtils:Info(playerName .. " awarded " .. amount .. " EP (Total: " .. newEP .. ")", "EPGP")
	return true
end

function InfinityLootEPGP:AwardGP(playerName, itemName, value, reason)
	if not self.players[playerName] then
		return false
	end
	
	local gpValue = value or self.settings.gpBaseValue
	local oldGP = self.players[playerName].gp
	self.players[playerName].gp = self.players[playerName].gp + gpValue
	self.players[playerName].lootCount = self.players[playerName].lootCount + 1
	local newGP = self.players[playerName].gp
	
	self:UpdatePlayerPriority(playerName)
	self:LogTransaction({
		type = "gp_awarded",
		playerName = playerName,
		oldGP = oldGP,
		newGP = newGP,
		amount = gpValue,
		item = itemName,
		reason = reason or ("GP Award: " .. itemName),
	})
	
	InfinityMessaging:Publish("gp_awarded", { player = playerName, item = itemName, value = gpValue })
	
	InfinityUtils:Info(playerName .. " awarded " .. gpValue .. " GP for " .. itemName, "EPGP")
	return true
end

function InfinityLootEPGP:UpdatePlayerPriority(playerName)
	if not self.players[playerName] then
		return
	end
	
	local player = self.players[playerName]
	player.priority = player.ep / math.max(player.gp, 1)
end

function InfinityLootEPGP:GetPlayerInfo(playerName)
	if not self.players[playerName] then
		return nil
	end
	
	local player = InfinityUtils:DeepCopy(self.players[playerName])
	player.priority = math.floor(player.priority * 100) / 100 -- Round to 2 decimals
	return player
end

function InfinityLootEPGP:GetPriority()
	local sorted = {}
	
	for playerName, playerData in pairs(self.players) do
		table.insert(sorted, playerData)
	end
	
	-- Sort by priority (highest first)
	table.sort(sorted, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.ep > b.ep
	end)
	
	return sorted
end

function InfinityLootEPGP:DecayEP()
	local decayMultiplier = 1 - (self.settings.decayPercent / 100)
	
	for playerName, playerData in pairs(self.players) do
		local oldEP = playerData.ep
		playerData.ep = math.floor(playerData.ep * decayMultiplier)
		
		self:LogTransaction({
			type = "ep_decayed",
			playerName = playerName,
			oldEP = oldEP,
			newEP = playerData.ep,
			reason = "Decay: " .. self.settings.decayPercent .. "%",
		})
		
		self:UpdatePlayerPriority(playerName)
	end
	
	InfinityMessaging:Publish("epgp_decayed", { percent = self.settings.decayPercent })
	InfinityUtils:Info("EP decayed by " .. self.settings.decayPercent .. "%", "EPGP")
	return true
end

function InfinityLootEPGP:ResetPlayer(playerName)
	if not self.players[playerName] then
		return false
	end
	
	local oldEP = self.players[playerName].ep
	local oldGP = self.players[playerName].gp
	
	self.players[playerName].ep = 0
	self.players[playerName].gp = 0
	self.players[playerName].priority = 0
	self.players[playerName].lootCount = 0
	
	self:LogTransaction({
		type = "player_reset",
		playerName = playerName,
		oldEP = oldEP,
		oldGP = oldGP,
		newEP = 0,
		newGP = 0,
		reason = "Player reset",
	})
	
	InfinityMessaging:Publish("epgp_reset", { player = playerName })
	InfinityUtils:Info(playerName .. " EPGP reset", "EPGP")
	return true
end

function InfinityLootEPGP:GetStats()
	local stats = {
		totalPlayers = 0,
		totalEP = 0,
		totalGP = 0,
		averageEP = 0,
		averageGP = 0,
		topPlayer = nil,
		lowestPlayer = nil,
	}
	
	local sorted = self:GetPriority()
	
	for _, player in ipairs(sorted) do
		stats.totalPlayers = stats.totalPlayers + 1
		stats.totalEP = stats.totalEP + player.ep
		stats.totalGP = stats.totalGP + player.gp
	end
	
	if stats.totalPlayers > 0 then
		stats.averageEP = math.floor(stats.totalEP / stats.totalPlayers)
		stats.averageGP = math.floor(stats.totalGP / stats.totalPlayers)
		stats.topPlayer = sorted[1]
		stats.lowestPlayer = sorted[#sorted]
	end
	
	return stats
end

function InfinityLootEPGP:ExportEPGP()
	return {
		players = InfinityUtils:DeepCopy(self.players),
		settings = InfinityUtils:DeepCopy(self.settings),
		exportTime = InfinityUtils:GetTimeStamp(),
	}
end

-- ============================================================================
-- TRANSACTION HISTORY & AUDITING
-- ============================================================================

--- Log a transaction
-- @param transaction: table {type, playerName, oldEP, newEP, oldGP, newGP, reason, ...}
function InfinityLootEPGP:LogTransaction(transaction)
	transaction = transaction or {}
	transaction.timestamp = InfinityUtils:GetTimeStamp()
	
	table.insert(self.transactionHistory, transaction)
	
	-- Keep only last 10,000 transactions to prevent memory bloat
	if #self.transactionHistory > 10000 then
		table.remove(self.transactionHistory, 1)
	end
end

--- Get transaction history for a player
-- @param playerName: string
-- @param limit: number (default 100)
-- @return transactions: table
function InfinityLootEPGP:GetPlayerTransactionHistory(playerName, limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.transactionHistory, 1, -1 do
		if #result >= limit then break end
		local trans = self.transactionHistory[i]
		if trans.playerName == playerName then
			table.insert(result, trans)
		end
	end
	
	return result
end

--- Get all transactions of a specific type
-- @param transactionType: string (e.g., "ep_awarded", "gp_awarded", "player_reset")
-- @param limit: number (default 100)
-- @return transactions: table
function InfinityLootEPGP:GetTransactionsByType(transactionType, limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.transactionHistory, 1, -1 do
		if #result >= limit then break end
		local trans = self.transactionHistory[i]
		if trans.type == transactionType then
			table.insert(result, trans)
		end
	end
	
	return result
end

--- Get transactions in a date range
-- @param playerName: string (optional, nil for all players)
-- @param startTime: number (Unix timestamp)
-- @param endTime: number (Unix timestamp)
-- @return transactions: table
function InfinityLootEPGP:GetTransactionsByDateRange(startTime, endTime, playerName)
	local result = {}
	
	for _, trans in ipairs(self.transactionHistory) do
		if trans.timestamp >= startTime and trans.timestamp <= endTime then
			if not playerName or trans.playerName == playerName then
				table.insert(result, trans)
			end
		end
	end
	
	return result
end

--- Get EP change history for player
-- @param playerName: string
-- @param limit: number (default 100)
-- @return history: table {timestamp, oldEP, newEP, change, reason}
function InfinityLootEPGP:GetPlayerEPHistory(playerName, limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.transactionHistory, 1, -1 do
		if #result >= limit then break end
		local trans = self.transactionHistory[i]
		if trans.playerName == playerName and (trans.type == "ep_awarded" or trans.type == "ep_decayed") then
			table.insert(result, {
				timestamp = trans.timestamp,
				type = trans.type,
				oldValue = trans.oldEP,
				newValue = trans.newEP,
				change = trans.newEP - trans.oldEP,
				reason = trans.reason,
			})
		end
	end
	
	return result
end

--- Get GP change history for player
-- @param playerName: string
-- @param limit: number (default 100)
-- @return history: table {timestamp, oldGP, newGP, change, reason}
function InfinityLootEPGP:GetPlayerGPHistory(playerName, limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.transactionHistory, 1, -1 do
		if #result >= limit then break end
		local trans = self.transactionHistory[i]
		if trans.playerName == playerName and trans.type == "gp_awarded" then
			table.insert(result, {
				timestamp = trans.timestamp,
				type = trans.type,
				oldValue = trans.oldGP,
				newValue = trans.newGP,
				change = trans.newGP - trans.oldGP,
				item = trans.item,
				reason = trans.reason,
			})
		end
	end
	
	return result
end

--- Export transaction history
-- @param limit: number (default 500)
-- @return historyString: string
function InfinityLootEPGP:ExportTransactionHistory(limit)
	limit = limit or 500
	local export = "EPGP TRANSACTION HISTORY\n"
	export = export .. "========================\n\n"
	
	for i = #self.transactionHistory, math.max(1, #self.transactionHistory - limit + 1), -1 do
		local trans = self.transactionHistory[i]
		local timestamp = InfinityUtils:FormatTimeStamp(trans.timestamp) or "Unknown"
		
		if trans.type == "ep_awarded" then
			export = export .. string.format("[%s] %s: EP %d→%d (+%d) - %s\n",
				timestamp, trans.playerName, trans.oldEP, trans.newEP, trans.amount, trans.reason)
		elseif trans.type == "gp_awarded" then
			export = export .. string.format("[%s] %s: GP %d→%d (+%d) for %s - %s\n",
				timestamp, trans.playerName, trans.oldGP, trans.newGP, trans.amount, trans.item, trans.reason)
		elseif trans.type == "ep_decayed" then
			export = export .. string.format("[%s] %s: EP %d→%d (decay) - %s\n",
				timestamp, trans.playerName, trans.oldEP, trans.newEP, trans.reason)
		elseif trans.type == "player_reset" then
			export = export .. string.format("[%s] %s: RESET EP %d→0, GP %d→0\n",
				timestamp, trans.playerName, trans.oldEP, trans.oldGP)
		elseif trans.type == "player_created" then
			export = export .. string.format("[%s] %s: Created with EP=%d, GP=%d\n",
				timestamp, trans.playerName, trans.newEP, trans.newGP)
		else
			export = export .. string.format("[%s] %s: %s - %s\n",
				timestamp, trans.playerName, trans.type, trans.reason)
		end
	end
	
	return export
end

--- Get transaction statistics
-- @return stats: table
function InfinityLootEPGP:GetTransactionStats()
	local stats = {
		totalTransactions = #self.transactionHistory,
		epAwardedTransactions = 0,
		gpAwardedTransactions = 0,
		decayTransactions = 0,
		resetTransactions = 0,
		totalEPAwarded = 0,
		totalGPAwarded = 0,
	}
	
	for _, trans in ipairs(self.transactionHistory) do
		if trans.type == "ep_awarded" then
			stats.epAwardedTransactions = stats.epAwardedTransactions + 1
			stats.totalEPAwarded = stats.totalEPAwarded + (trans.amount or 0)
		elseif trans.type == "gp_awarded" then
			stats.gpAwardedTransactions = stats.gpAwardedTransactions + 1
			stats.totalGPAwarded = stats.totalGPAwarded + (trans.amount or 0)
		elseif trans.type == "ep_decayed" then
			stats.decayTransactions = stats.decayTransactions + 1
		elseif trans.type == "player_reset" then
			stats.resetTransactions = stats.resetTransactions + 1
		end
	end
	
	return stats
end

return InfinityLootEPGP
