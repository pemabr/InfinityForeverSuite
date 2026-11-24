-- Advanced Point History Auditing Module
-- Provides comprehensive audit trails and analysis for all EPGP transactions

local PluribusPointAuditing = {}
_G.PluribusPointAuditing = PluribusPointAuditing

PluribusPointAuditing.queryCache = {} -- Cache expensive queries
PluribusPointAuditing.cacheExpiry = {} -- Cache invalidation timestamps
PluribusPointAuditing.cacheLifetime = 60 -- seconds

function PluribusPointAuditing:Initialize()
	PluribusUtils:Info("Point auditing system initialized", "Auditing")
end

-- Get all transactions within a time range
function PluribusPointAuditing:GetTransactionsByDateRange(startTime, endTime)
	local results = {}
	local history = PluribusLootEPGP.transactionHistory
	
	for i, transaction in ipairs(history) do
		if transaction.timestamp and transaction.timestamp >= startTime and transaction.timestamp <= endTime then
			table.insert(results, transaction)
		end
	end
	
	return results
end

-- Get all transactions of a specific type (ep_awarded, gp_awarded, etc.)
function PluribusPointAuditing:GetTransactionsByType(txType, limit)
	limit = limit or 100
	local results = {}
	local history = PluribusLootEPGP.transactionHistory
	
	for i = #history, math.max(1, #history - 1000) do
		if history[i] and history[i].type == txType then
			table.insert(results, history[i])
			if #results >= limit then break end
		end
	end
	
	return results
end

-- Calculate total EP gained by player in time range
function PluribusPointAuditing:GetPlayerEPGainedInRange(playerName, startTime, endTime)
	local total = 0
	local txns = self:GetTransactionsByDateRange(startTime, endTime)
	
	for _, txn in ipairs(txns) do
		if txn.playerName == playerName and txn.type == "ep_awarded" then
			total = total + (txn.amount or 0)
		end
	end
	
	return total
end

-- Calculate total GP spent by player in time range
function PluribusPointAuditing:GetPlayerGPSpentInRange(playerName, startTime, endTime)
	local total = 0
	local txns = self:GetTransactionsByDateRange(startTime, endTime)
	
	for _, txn in ipairs(txns) do
		if txn.playerName == playerName and txn.type == "gp_awarded" then
			total = total + (txn.amount or 0)
		end
	end
	
	return total
end

-- Get all EP sources for a player (break down by reason)
function PluribusPointAuditing:GetPlayerEPSources(playerName, limit)
	limit = limit or 100
	local sources = {}
	local history = PluribusLootEPGP.transactionHistory
	
	for i = #history, math.max(1, #history - 500) do
		if history[i] and history[i].playerName == playerName and history[i].type == "ep_awarded" then
			local reason = history[i].reason or "Unknown"
			if not sources[reason] then
				sources[reason] = { amount = 0, count = 0, timestamp = history[i].timestamp }
			end
			sources[reason].amount = sources[reason].amount + (history[i].amount or 0)
			sources[reason].count = sources[reason].count + 1
		end
	end
	
	-- Convert to array and sort by amount
	local result = {}
	for reason, data in pairs(sources) do
		table.insert(result, {
			reason = reason,
			amount = data.amount,
			count = data.count,
			timestamp = data.timestamp,
		})
	end
	
	table.sort(result, function(a, b) return a.amount > b.amount end)
	
	local final = {}
	for i = 1, math.min(limit, #result) do
		table.insert(final, result[i])
	end
	
	return final
end

-- Get all GP items for a player (break down by item)
function PluribusPointAuditing:GetPlayerGPItems(playerName, limit)
	limit = limit or 100
	local items = {}
	local history = PluribusLootEPGP.transactionHistory
	
	for i = #history, math.max(1, #history - 500) do
		if history[i] and history[i].playerName == playerName and history[i].type == "gp_awarded" then
			local itemName = history[i].itemName or "Unknown Item"
			if not items[itemName] then
				items[itemName] = { gp = 0, count = 0, timestamp = history[i].timestamp }
			end
			items[itemName].gp = items[itemName].gp + (history[i].amount or 0)
			items[itemName].count = items[itemName].count + 1
		end
	end
	
	-- Convert to array and sort by cost
	local result = {}
	for itemName, data in pairs(items) do
		table.insert(result, {
			itemName = itemName,
			gp = data.gp,
			count = data.count,
			avgCost = data.gp / data.count,
			timestamp = data.timestamp,
		})
	end
	
	table.sort(result, function(a, b) return a.gp > b.gp end)
	
	local final = {}
	for i = 1, math.min(limit, #result) do
		table.insert(final, result[i])
	end
	
	return final
end

-- Generate a comprehensive audit report for a player
function PluribusPointAuditing:GeneratePlayerAuditReport(playerName, numDays)
	numDays = numDays or 30
	local endTime = GetTime()
	local startTime = endTime - (numDays * 86400)
	
	local epGained = self:GetPlayerEPGainedInRange(playerName, startTime, endTime)
	local gpSpent = self:GetPlayerGPSpentInRange(playerName, startTime, endTime)
	local epSources = self:GetPlayerEPSources(playerName, 10)
	local gpItems = self:GetPlayerGPItems(playerName, 10)
	
	local report = {
		playerName = playerName,
		period = numDays .. " days",
		startTime = startTime,
		endTime = endTime,
		epGained = epGained,
		gpSpent = gpSpent,
		netPoints = epGained - gpSpent,
		epSources = epSources,
		gpItems = gpItems,
		reportTime = GetTime(),
	}
	
	return report
end

-- Check for suspicious activity (unusual patterns)
function PluribusPointAuditing:DetectAnomalies(playerName)
	local anomalies = {}
	local history = PluribusLootEPGP.transactionHistory
	local recentTxns = {}
	
	-- Get recent transactions for this player
	for i = #history, math.max(1, #history - 100) do
		if history[i] and history[i].playerName == playerName then
			table.insert(recentTxns, 1, history[i])
		end
	end
	
	-- Check for rapid GP awards (possible duplicate)
	for i = 1, #recentTxns - 1 do
		if recentTxns[i].type == "gp_awarded" and recentTxns[i+1].type == "gp_awarded" then
			local timeDiff = recentTxns[i].timestamp - recentTxns[i+1].timestamp
			if timeDiff < 2 then -- Less than 2 seconds apart
				table.insert(anomalies, {
					type = "rapid_gp_awards",
					severity = "MEDIUM",
					detail = "Two GP awards within 2 seconds",
					transactions = { recentTxns[i], recentTxns[i+1] },
				})
			end
		end
	end
	
	-- Check for large negative corrections
	for i, txn in ipairs(recentTxns) do
		if txn.type == "ep_awarded" and (txn.amount or 0) < -100 then
			table.insert(anomalies, {
				type = "large_ep_reduction",
				severity = "HIGH",
				detail = "Unusual EP reduction: " .. (txn.amount or 0) .. " EP",
				transaction = txn,
			})
		end
	end
	
	return anomalies
end

-- Export audit trail in JSON format
function PluribusPointAuditing:ExportAuditTrail(playerName, limit)
	limit = limit or 500
	local history = PluribusLootEPGP:GetPlayerTransactionHistory(playerName, limit)
	
	local json = "[\n"
	for i, txn in ipairs(history) do
		json = json .. "  {\n"
		json = json .. '    "timestamp": ' .. (txn.timestamp or 0) .. ",\n"
		json = json .. '    "type": "' .. (txn.type or "") .. '",\n'
		json = json .. '    "amount": ' .. (txn.amount or 0) .. ",\n"
		json = json .. '    "reason": "' .. (txn.reason or "") .. '"\n'
		json = json .. "  }"
		if i < #history then json = json .. "," end
		json = json .. "\n"
	end
	json = json .. "]\n"
	
	return json
end

return PluribusPointAuditing
