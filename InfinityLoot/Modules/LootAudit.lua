-- Loot System Audit Module
-- Comprehensive auditing of EPGP, loot awards, and transactions

local LootAudit = {
	auditLog = {}, -- {timestamp = {action, details}}
	suspiciousActions = {},
	statistics = {
		totalEpgpTransactions = 0,
		totalGoldDistributed = 0,
		uniquePlayers = {},
		anomalies = 0,
	},
}

_G.InfinityLootAudit = LootAudit

-- Initialize audit system
function LootAudit:Initialize()
	InfinityUtils:Info("Loot audit system initialized", "Loot")
	
	-- Subscribe to all loot events
	InfinityMessaging:Subscribe("epgp_awarded", function(player, ep, gp, reason)
		LootAudit:LogEPGPAward(player, ep, gp, reason)
	end)
	
	InfinityMessaging:Subscribe("loot_awarded", function(player, item, value)
		LootAudit:LogLootAward(player, item, value)
	end)
	
	InfinityMessaging:Subscribe("dkp_trade", function(from, to, amount)
		LootAudit:LogDKPTrade(from, to, amount)
	end)
	
	InfinityMessaging:Subscribe("dkp_tax", function(player, amount, source)
		LootAudit:LogDKPTax(player, amount, source)
	end)
	
	InfinityMessaging:Subscribe("dkp_donation", function(player, amount, item)
		LootAudit:LogDKPDonation(player, amount, item)
	end)
end

-- Log EPGP award
function LootAudit:LogEPGPAward(player, ep, gp, reason)
	local timestamp = GetServerTime()
	
	local logEntry = {
		timestamp = timestamp,
		action = "epgp_award",
		player = player,
		ep = ep,
		gp = gp,
		reason = reason,
		source = UnitName("player"),
		guildName = GetGuildInfo("player"),
	}
	
	table.insert(self.auditLog, logEntry)
	
	-- Update statistics
	self.statistics.totalEpgpTransactions = self.statistics.totalEpgpTransactions + 1
	if not self.statistics.uniquePlayers[player] then
		self.statistics.uniquePlayers[player] = true
	end
	
	-- Check for anomalies
	if ep > 100 or gp > 100 then
		self:FlagAnomaly("Large EPGP award", logEntry)
	end
	
	self:CheckForSuspiciousPatterns(player)
end

-- Log loot award
function LootAudit:LogLootAward(player, item, value)
	local timestamp = GetServerTime()
	
	local logEntry = {
		timestamp = timestamp,
		action = "loot_awarded",
		player = player,
		item = item,
		value = value,
		source = UnitName("player"),
		guildName = GetGuildInfo("player"),
	}
	
	table.insert(self.auditLog, logEntry)
	self.statistics.totalGoldDistributed = self.statistics.totalGoldDistributed + value
end

-- Log DKP trade
function LootAudit:LogDKPTrade(from, to, amount)
	local timestamp = GetServerTime()
	
	local logEntry = {
		timestamp = timestamp,
		action = "dkp_trade",
		from = from,
		to = to,
		amount = amount,
		verified = false,
	}
	
	table.insert(self.auditLog, logEntry)
	
	-- Check for suspicious patterns
	self:CheckForTradeAnomalies(from, to, amount)
end

-- Log DKP taxation
function LootAudit:LogDKPTax(player, amount, source)
	local timestamp = GetServerTime()
	
	local logEntry = {
		timestamp = timestamp,
		action = "dkp_tax",
		player = player,
		amount = amount,
		source = source, -- gold or auction house value
	}
	
	table.insert(self.auditLog, logEntry)
end

-- Log DKP donation
function LootAudit:LogDKPDonation(player, amount, item)
	local timestamp = GetServerTime()
	
	local logEntry = {
		timestamp = timestamp,
		action = "dkp_donation",
		player = player,
		amount = amount,
		item = item,
	}
	
	table.insert(self.auditLog, logEntry)
end

-- Flag anomaly
function LootAudit:FlagAnomaly(description, details)
	table.insert(self.suspiciousActions, {
		timestamp = GetServerTime(),
		description = description,
		details = details,
		severity = "medium",
		reviewed = false,
	})
	
	self.statistics.anomalies = self.statistics.anomalies + 1
end

-- Check for suspicious patterns
function LootAudit:CheckForSuspiciousPatterns(player)
	-- Count awards to this player in last hour
	local oneHourAgo = GetServerTime() - 3600
	local recentAwards = 0
	local totalEP = 0
	local totalGP = 0
	
	for _, entry in ipairs(self.auditLog) do
		if entry.player == player and entry.timestamp > oneHourAgo and entry.action == "epgp_award" then
			recentAwards = recentAwards + 1
			totalEP = totalEP + (entry.ep or 0)
			totalGP = totalGP + (entry.gp or 0)
		end
	end
	
	-- Flag if excessive
	if recentAwards > 10 then
		self:FlagAnomaly("Excessive awards to " .. player .. " (" .. recentAwards .. " in 1 hour)", {
			player = player,
			recentAwards = recentAwards,
			totalEP = totalEP,
			totalGP = totalGP,
		})
	end
	
	-- Flag if unusual EP/GP ratio
	if totalEP > 0 and totalGP > 0 then
		local ratio = totalEP / totalGP
		if ratio < 0.5 or ratio > 2.0 then
			self:FlagAnomaly("Unusual EP/GP ratio for " .. player .. " (" .. string.format("%.2f", ratio) .. ")", {
				player = player,
				ratio = ratio,
			})
		end
	end
end

-- Check for trade anomalies
function LootAudit:CheckForTradeAnomalies(from, to, amount)
	-- Check if large trade
	if amount > 100 then
		self:FlagAnomaly("Large DKP trade: " .. from .. " -> " .. to .. " (" .. amount .. " DKP)", {
			from = from,
			to = to,
			amount = amount,
		})
	end
	
	-- Check for trade chains
	local recentTrades = 0
	local oneHourAgo = GetServerTime() - 3600
	
	for _, entry in ipairs(self.auditLog) do
		if entry.action == "dkp_trade" and entry.timestamp > oneHourAgo then
			if entry.from == from or entry.to == from then
				recentTrades = recentTrades + 1
			end
		end
	end
	
	if recentTrades > 5 then
		self:FlagAnomaly(from .. " involved in " .. recentTrades .. " trades in 1 hour", {
			player = from,
			tradeCount = recentTrades,
		})
	end
end

-- Get audit report
function LootAudit:GetAuditReport(timeframe)
	timeframe = timeframe or 86400 -- Default 1 day
	local cutoffTime = GetServerTime() - timeframe
	
	local report = {
		timeframe = timeframe,
		generatedAt = GetServerTime(),
		totalTransactions = 0,
		totalGoldMoved = 0,
		playersInvolved = {},
		anomalies = {},
		recommendations = {},
	}
	
	-- Analyze logs
	for _, entry in ipairs(self.auditLog) do
		if entry.timestamp > cutoffTime then
			report.totalTransactions = report.totalTransactions + 1
			
			if entry.action == "loot_awarded" then
				report.totalGoldMoved = report.totalGoldMoved + (entry.value or 0)
			end
			
			-- Track players
			local player = entry.player or entry.from
			if player then
				if not report.playersInvolved[player] then
					report.playersInvolved[player] = {
						count = 0,
						totalValue = 0,
					}
				end
				report.playersInvolved[player].count = report.playersInvolved[player].count + 1
			end
		end
	end
	
	-- Include anomalies
	for _, anomaly in ipairs(self.suspiciousActions) do
		if not anomaly.reviewed then
			table.insert(report.anomalies, anomaly)
		end
	end
	
	-- Generate recommendations
	if #report.anomalies > 0 then
		table.insert(report.recommendations, "Review " .. #report.anomalies .. " flagged anomalies")
	end
	
	return report
end

-- Display audit summary
function LootAudit:DisplaySummary(timeframe)
	timeframe = timeframe or 86400
	local report = self:GetAuditReport(timeframe)
	
	local hours = timeframe / 3600
	
	print("|cffffd700=== LOOT AUDIT SUMMARY ===|r")
	print("Period: Last " .. string.format("%.1f", hours) .. " hours")
	print("Total Transactions: " .. report.totalTransactions)
	print("Total Gold Moved: " .. InfinityUtils:FormatNumber(report.totalGoldMoved))
	print("Players Involved: " .. InfinityUtils:TableSize(report.playersInvolved))
	
	if #report.anomalies > 0 then
		print("\n|cffff0000Anomalies Detected:|r " .. #report.anomalies)
		for i, anomaly in ipairs(report.anomalies) do
			if i <= 5 then
				print("  " .. i .. ". " .. anomaly.description .. " (" .. anomaly.severity .. ")")
			end
		end
		if #report.anomalies > 5 then
			print("  ... and " .. (#report.anomalies - 5) .. " more")
		end
	else
		print("\n|cff00ff00No anomalies detected|r")
	end
	
	if #report.recommendations > 0 then
		print("\n|cffccccccRecommendations:|r")
		for _, rec in ipairs(report.recommendations) do
			print("  - " .. rec)
		end
	end
end

-- Export audit log
function LootAudit:ExportLog(filename)
	filename = filename or "LootAudit_" .. GetServerTime() .. ".log"
	
	-- This would save to a file - in WoW this would be SavedVariables
	InfinityStorageManager:SaveData("audit_logs", self.auditLog)
	InfinityUtils:Info("Audit log exported to SavedVariables", "Loot")
end

-- Clear audit log (admin only)
function LootAudit:ClearLog()
	self.auditLog = {}
	self.suspiciousActions = {}
	self.statistics = {
		totalEpgpTransactions = 0,
		totalGoldDistributed = 0,
		uniquePlayers = {},
		anomalies = 0,
	}
	InfinityUtils:Info("Audit log cleared", "Loot")
end

return LootAudit
