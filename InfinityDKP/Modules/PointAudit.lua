-- Point History Auditing & Query System
-- Provides comprehensive query and analysis functions for DKP transaction history
-- Enables tracing of every point change with detailed audit trails

local PointAudit = {
	config = {
		enableAuditing = true,
		maxHistoryEntries = 10000,
		retentionDays = 90, -- Keep raw data for 90 days, then archive
		enableDetailedLogging = true,
		auditLevel = "normal", -- normal, detailed, forensic
	},
	
	transactionLog = {}, -- {id = {timestamp, player, amount, reason, before, after, type, metadata}}
	queryCache = {}, -- Cache query results for performance
	cacheTimeout = 300, -- 5 minutes
}

_G.InfinityPointAudit = PointAudit

function PointAudit:Initialize()
	InfinityUtils:Info("Point Audit system initialized", "DKP")
	self:LoadAuditData()
	self:PurgeOldEntries()
end

function PointAudit:RecordTransaction(txData)
	if not self.config.enableAuditing then return end
	
	local id = #self.transactionLog + 1
	
	-- Create audit entry
	local entry = {
		id = id,
		timestamp = time(),
		player = txData.player or "Unknown",
		amount = txData.amount or 0,
		reason = txData.reason or "No reason provided",
		type = txData.type or "unknown", -- award, spend, adjust, decay, etc.
		before = txData.before or 0,
		after = txData.after or txData.before + txData.amount,
		metadata = txData.metadata or {},
		
		-- Additional forensic data
		source = txData.source or "Direct", -- UI, API, Automation, etc.
		admin = txData.admin or "System",
		guildRank = txData.guildRank or "Unknown",
	}
	
	-- Add to log
	self.transactionLog[id] = entry
	
	-- Enforce size limit
	if #self.transactionLog > self.config.maxHistoryEntries then
		table.remove(self.transactionLog, 1) -- Remove oldest
	end
	
	self:SaveAuditData()
	self:InvalidateCache()
end

function PointAudit:GetPlayerHistory(playerName, limit)
	limit = limit or 100
	local results = {}
	
	-- Check cache first
	local cacheKey = "player_" .. playerName .. "_" .. limit
	if self.queryCache[cacheKey] and (time() - self.queryCache[cacheKey].time) < self.cacheTimeout then
		return self.queryCache[cacheKey].data
	end
	
	-- Query log
	local count = 0
	for id = #self.transactionLog, 1, -1 do
		if count >= limit then break end
		local entry = self.transactionLog[id]
		if entry.player:lower() == playerName:lower() then
			table.insert(results, entry)
			count = count + 1
		end
	end
	
	-- Cache result
	self.queryCache[cacheKey] = {
		data = results,
		time = time(),
	}
	
	return results
end

function PointAudit:GetTransactionsByDateRange(startDate, endDate)
	local results = {}
	local startTime = startDate or time() - (90 * 86400) -- Default 90 days
	local endTime = endDate or time()
	
	for id, entry in pairs(self.transactionLog) do
		if entry.timestamp >= startTime and entry.timestamp <= endTime then
			table.insert(results, entry)
		end
	end
	
	-- Sort by timestamp descending
	table.sort(results, function(a, b) return a.timestamp > b.timestamp end)
	
	return results
end

function PointAudit:GetTransactionsByType(txType)
	local results = {}
	
	for id, entry in pairs(self.transactionLog) do
		if entry.type == txType then
			table.insert(results, entry)
		end
	end
	
	return results
end

function PointAudit:GetTransactionsByReason(reasonPattern)
	local results = {}
	
	for id, entry in pairs(self.transactionLog) do
		if string.match(entry.reason, reasonPattern) then
			table.insert(results, entry)
		end
	end
	
	return results
end

function PointAudit:GetPlayerPointsAt(playerName, timestamp)
	timestamp = timestamp or time()
	local points = 0
	
	for id, entry in pairs(self.transactionLog) do
		if entry.timestamp <= timestamp and entry.player:lower() == playerName:lower() then
			points = entry.after
		end
	end
	
	return points
end

function PointAudit:GetPointsChangeOverTime(playerName, days)
	days = days or 7
	local dayData = {}
	local now = time()
	
	for d = days, 0, -1 do
		local dayStart = now - (d * 86400)
		local dayEnd = dayStart + 86400
		
		dayData[d] = {
			date = date("%Y-%m-%d", dayStart),
			earned = 0,
			spent = 0,
			net = 0,
		}
		
		-- Sum all transactions for this player on this day
		for id, entry in pairs(self.transactionLog) do
			if entry.player:lower() == playerName:lower() and 
			   entry.timestamp >= dayStart and entry.timestamp < dayEnd then
				
				if entry.type == "award" or entry.type == "completion" or entry.type == "bosskill" then
					dayData[d].earned = dayData[d].earned + entry.amount
				elseif entry.type == "spend" or entry.type == "bid" then
					dayData[d].spent = dayData[d].spent + math.abs(entry.amount)
				end
			end
		end
		
		dayData[d].net = dayData[d].earned - dayData[d].spent
	end
	
	return dayData
end

function PointAudit:DetectAnomalies(playerName)
	local anomalies = {}
	local history = self:GetPlayerHistory(playerName, 1000)
	
	-- Check for large swings
	for i = 2, #history do
		local prev = history[i]
		local curr = history[i-1]
		
		local change = math.abs(curr.amount)
		if change > 500 then
			table.insert(anomalies, {
				type = "LARGE_CHANGE",
				value = change,
				entry = curr,
				severity = "HIGH",
			})
		end
	end
	
	-- Check for rapid transactions
	local rapidCount = 0
	local lastTime = 0
	for i = 1, #history do
		local entry = history[i]
		if entry.timestamp - lastTime < 10 then
			rapidCount = rapidCount + 1
		else
			rapidCount = 0
		end
		
		if rapidCount > 5 then
			table.insert(anomalies, {
				type = "RAPID_TRANSACTIONS",
				count = rapidCount,
				entry = entry,
				severity = "MEDIUM",
			})
		end
		
		lastTime = entry.timestamp
	end
	
	-- Check for negative points (shouldn't happen)
	for i = 1, #history do
		local entry = history[i]
		if entry.after < 0 then
			table.insert(anomalies, {
				type = "NEGATIVE_BALANCE",
				value = entry.after,
				entry = entry,
				severity = "CRITICAL",
			})
		end
	end
	
	return anomalies
end

function PointAudit:GetAuditTrail(playerName, limit)
	limit = limit or 50
	local trail = {}
	local history = self:GetPlayerHistory(playerName, limit)
	
	for i = #history, 1, -1 do
		local entry = history[i]
		table.insert(trail, {
			time = date("%H:%M:%S", entry.timestamp),
			type = entry.type,
			amount = entry.amount,
			before = entry.before,
			after = entry.after,
			reason = entry.reason,
			admin = entry.admin,
		})
	end
	
	return trail
end

function PointAudit:PrintPlayerHistory(playerName, limit)
	limit = limit or 20
	local history = self:GetPlayerHistory(playerName, limit)
	
	print("|cffffd700=== DKP History for " .. playerName .. " ===|r")
	print("Transaction ID | Date/Time | Type | Amount | Before | After | Reason")
	print(string.rep("-", 120))
	
	for i = #history, 1, -1 do
		local entry = history[i]
		local timeStr = date("%m/%d %H:%M", entry.timestamp)
		local amountStr = string.format("%+6.0f", entry.amount)
		
		print(string.format("%3d | %s | %10s | %s | %6.0f | %6.0f | %s",
			entry.id, timeStr, entry.type, amountStr, entry.before, entry.after, entry.reason))
	end
end

function PointAudit:ExportAuditTrail(playerName, format)
	format = format or "text"
	
	if format == "csv" then
		local csv = "ID,Timestamp,Player,Type,Amount,Before,After,Reason,Admin\n"
		local history = self:GetPlayerHistory(playerName, 1000)
		
		for _, entry in ipairs(history) do
			csv = csv .. string.format("%d,%d,%s,%s,%d,%d,%d,%s,%s\n",
				entry.id,
				entry.timestamp,
				entry.player,
				entry.type,
				entry.amount,
				entry.before,
				entry.after,
				entry.reason,
				entry.admin)
		end
		
		return csv
	
	elseif format == "json" then
		local json = "[\n"
		local history = self:GetPlayerHistory(playerName, 1000)
		
		for i, entry in ipairs(history) do
			json = json .. string.format('{"id":%d,"timestamp":%d,"player":"%s","type":"%s","amount":%d,"before":%d,"after":%d,"reason":"%s","admin":"%s"}',
				entry.id,
				entry.timestamp,
				entry.player,
				entry.type,
				entry.amount,
				entry.before,
				entry.after,
				entry.reason,
				entry.admin)
			
			if i < #history then json = json .. ",\n" end
		end
		
		json = json .. "\n]"
		return json
	
	else -- text format
		local text = "=== Audit Trail for " .. playerName .. " ===\n"
		text = text .. "Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
		
		local trail = self:GetAuditTrail(playerName, 50)
		for _, entry in ipairs(trail) do
			text = text .. string.format("[%s] %s: %+d (%d → %d) - %s\n",
				entry.time, entry.type, entry.amount, entry.before, entry.after, entry.reason)
		end
		
		return text
	end
end

function PointAudit:FindTransactionsInRange(startAmount, endAmount)
	local results = {}
	
	for id, entry in pairs(self.transactionLog) do
		if entry.amount >= startAmount and entry.amount <= endAmount then
			table.insert(results, entry)
		end
	end
	
	return results
end

function PointAudit:GetTopTransactions(limit, field)
	field = field or "amount"
	limit = limit or 10
	local results = {}
	
	for id, entry in pairs(self.transactionLog) do
		table.insert(results, entry)
	end
	
	-- Sort by specified field
	table.sort(results, function(a, b)
		return math.abs(a[field]) > math.abs(b[field])
	end)
	
	-- Return top N
	local final = {}
	for i = 1, math.min(limit, #results) do
		table.insert(final, results[i])
	end
	
	return final
end

function PointAudit:GenerateAuditReport(playerName)
	local history = self:GetPlayerHistory(playerName, 1000)
	local anomalies = self:DetectAnomalies(playerName)
	
	local report = {
		player = playerName,
		generated = time(),
		transactionCount = #history,
		anomalyCount = #anomalies,
		totalEarned = 0,
		totalSpent = 0,
		netChange = 0,
	}
	
	-- Calculate totals
	for _, entry in ipairs(history) do
		if entry.type == "award" or entry.type == "completion" or entry.type == "bosskill" then
			report.totalEarned = report.totalEarned + entry.amount
		elseif entry.type == "spend" or entry.type == "bid" then
			report.totalSpent = report.totalSpent + math.abs(entry.amount)
		end
	end
	
	report.netChange = report.totalEarned - report.totalSpent
	
	return report
end

function PointAudit:PrintAnomalies(playerName)
	local anomalies = self:DetectAnomalies(playerName)
	
	if #anomalies == 0 then
		print("|cff00ff00✓ No anomalies detected for " .. playerName .. "|r")
		return
	end
	
	print("|cffff0000⚠ Anomalies detected for " .. playerName .. ":|r")
	for i, anomaly in ipairs(anomalies) do
		print(string.format("  %d. %s (Severity: %s)", i, anomaly.type, anomaly.severity))
		if anomaly.entry then
			print(string.format("     Transaction ID %d: %+d points (%s)", 
				anomaly.entry.id, anomaly.entry.amount, anomaly.entry.reason))
		end
	end
end

function PointAudit:PurgeOldEntries()
	local cutoffTime = time() - (self.config.retentionDays * 86400)
	local purged = 0
	
	for id = #self.transactionLog, 1, -1 do
		if self.transactionLog[id].timestamp < cutoffTime then
			table.remove(self.transactionLog, id)
			purged = purged + 1
		end
	end
	
	if purged > 0 then
		InfinityUtils:Info("Purged " .. purged .. " old audit entries", "DKP")
		self:SaveAuditData()
	end
end

function PointAudit:InvalidateCache()
	self.queryCache = {}
end

function PointAudit:SaveAuditData()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
	end
	
	_G.InfinityForeverSavedData.pointAudit = {
		transactionLog = self.transactionLog,
		config = self.config,
	}
end

function PointAudit:LoadAuditData()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
		return
	end
	
	local savedData = _G.InfinityForeverSavedData.pointAudit or {}
	self.transactionLog = savedData.transactionLog or {}
	
	if savedData.config then
		for key, value in pairs(savedData.config) do
			self.config[key] = value
		end
	end
end

return PointAudit
