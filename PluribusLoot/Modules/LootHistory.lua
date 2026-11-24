-- Loot History & Analytics Module
-- Tracks loot awards with comprehensive analytics and reporting

local PluribusLootHistory = {}
_G.PluribusLootHistory = PluribusLootHistory

-- Configuration
PluribusLootHistory.config = {
	maxHistoryEntries = 50000, -- Keep last 50k loot awards
	enableAnalytics = true,
	enableExport = true,
	adminOnly = true,
}

-- Data storage
PluribusLootHistory.lootLog = {} -- Complete loot history
PluribusLootHistory.sessionLoot = {} -- Session-based loot tracking
PluribusLootHistory.playerStats = {} -- {playerName = {totalAwards, totalValue, averageValue, ...}}
PluribusLootHistory.itemStats = {} -- {itemId = {awardCount, totalValue, lastAwarded, ...}}

-- Callbacks
PluribusLootHistory.callbacks = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize loot history system
function PluribusLootHistory:Initialize()
	PluribusUtils:Info("Loot History system initialized", "LootHistory")
end

-- ============================================================================
-- LOOT LOGGING
-- ============================================================================

--- Record a loot award
-- @param lootEntry: table {playerName, itemName, itemId, itemLink, value, reason, timestamp}
-- @return success: bool
function PluribusLootHistory:LogLootAward(lootEntry)
	if not lootEntry or not lootEntry.playerName then
		return false
	end
	
	-- Sanitize and prepare entry
	local entry = {
		timestamp = lootEntry.timestamp or PluribusUtils:GetTimeStamp(),
		playerName = lootEntry.playerName,
		itemName = lootEntry.itemName or "Unknown Item",
		itemId = lootEntry.itemId,
		itemLink = lootEntry.itemLink,
		value = lootEntry.value or 0,
		reason = lootEntry.reason or "Loot Award",
		raidId = lootEntry.raidId,
		source = lootEntry.source or "unknown",
	}
	
	-- Add to log
	table.insert(self.lootLog, entry)
	
	-- Keep log size under control
	if #self.lootLog > self.config.maxHistoryEntries then
		table.remove(self.lootLog, 1)
	end
	
	-- Update statistics
	self:UpdatePlayerStats(lootEntry.playerName, entry.value)
	self:UpdateItemStats(lootEntry.itemId or lootEntry.itemName, entry.value)
	
	-- Trigger callback
	self:TriggerCallback("loot_awarded", entry)
	
	return true
end

--- Record multiple loot awards at once
-- @param lootEntries: table of loot entries
-- @return success: bool
function PluribusLootHistory:LogBatchLootAwards(lootEntries)
	if not lootEntries or #lootEntries == 0 then
		return false
	end
	
	local count = 0
	for _, entry in ipairs(lootEntries) do
		if self:LogLootAward(entry) then
			count = count + 1
		end
	end
	
	PluribusUtils:Info("Logged " .. count .. " loot awards", "LootHistory")
	self:TriggerCallback("batch_loot_logged", count)
	
	return true
end

-- ============================================================================
-- STATISTICS & ANALYTICS
-- ============================================================================

--- Update player statistics
-- @param playerName: string
-- @param lootValue: number
function PluribusLootHistory:UpdatePlayerStats(playerName, lootValue)
	if not playerName then return end
	
	if not self.playerStats[playerName] then
		self.playerStats[playerName] = {
			name = playerName,
			totalAwards = 0,
			totalValue = 0,
			averageValue = 0,
			maxSingleValue = 0,
			minSingleValue = 999999999,
			lastAwardTime = 0,
		}
	end
	
	local stats = self.playerStats[playerName]
	stats.totalAwards = stats.totalAwards + 1
	stats.totalValue = stats.totalValue + lootValue
	stats.averageValue = math.floor(stats.totalValue / stats.totalAwards)
	stats.maxSingleValue = math.max(stats.maxSingleValue, lootValue)
	stats.minSingleValue = math.min(stats.minSingleValue, lootValue)
	stats.lastAwardTime = PluribusUtils:GetTimeStamp()
end

--- Update item statistics
-- @param itemId: number or string
-- @param lootValue: number
function PluribusLootHistory:UpdateItemStats(itemId, lootValue)
	if not itemId then return end
	
	itemId = tostring(itemId)
	
	if not self.itemStats[itemId] then
		self.itemStats[itemId] = {
			itemId = itemId,
			awardCount = 0,
			totalValue = 0,
			averageValue = 0,
			lastAwardedTime = 0,
			awardedTo = {}, -- {playerName = count}
		}
	end
	
	local stats = self.itemStats[itemId]
	stats.awardCount = stats.awardCount + 1
	stats.totalValue = stats.totalValue + lootValue
	stats.averageValue = math.floor(stats.totalValue / stats.awardCount)
	stats.lastAwardedTime = PluribusUtils:GetTimeStamp()
end

--- Get player loot statistics
-- @param playerName: string
-- @return stats: table
function PluribusLootHistory:GetPlayerStats(playerName)
	return self.playerStats[playerName]
end

--- Get item loot statistics
-- @param itemId: number or string
-- @return stats: table
function PluribusLootHistory:GetItemStats(itemId)
	return self.itemStats[tostring(itemId)]
end

--- Get top loot recipients
-- @param limit: number (default 10)
-- @param sortBy: string ("value", "count", or "average")
-- @return topPlayers: table
function PluribusLootHistory:GetTopLootRecipients(limit, sortBy)
	limit = limit or 10
	sortBy = sortBy or "value"
	
	local sorted = {}
	for playerName, stats in pairs(self.playerStats) do
		table.insert(sorted, stats)
	end
	
	-- Sort by specified metric
	table.sort(sorted, function(a, b)
		if sortBy == "count" then
			return a.totalAwards > b.totalAwards
		elseif sortBy == "average" then
			return a.averageValue > b.averageValue
		else
			return a.totalValue > b.totalValue
		end
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

--- Get most awarded items
-- @param limit: number (default 10)
-- @return topItems: table
function PluribusLootHistory:GetMostAwardedItems(limit)
	limit = limit or 10
	
	local sorted = {}
	for itemId, stats in pairs(self.itemStats) do
		table.insert(sorted, stats)
	end
	
	table.sort(sorted, function(a, b)
		return a.awardCount > b.awardCount
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

--- Get most valuable items
-- @param limit: number (default 10)
-- @return topItems: table
function PluribusLootHistory:GetMostValuableItems(limit)
	limit = limit or 10
	
	local sorted = {}
	for itemId, stats in pairs(self.itemStats) do
		table.insert(sorted, stats)
	end
	
	table.sort(sorted, function(a, b)
		return a.totalValue > b.totalValue
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

--- Get loot value analysis
-- @return analysis: table {totalValue, averageValue, highestAward, lowestAward, totalAwards}
function PluribusLootHistory:GetLootAnalysis()
	local analysis = {
		totalValue = 0,
		averageValue = 0,
		highestAward = 0,
		lowestAward = 999999999,
		totalAwards = 0,
	}
	
	for _, entry in ipairs(self.lootLog) do
		analysis.totalValue = analysis.totalValue + entry.value
		analysis.totalAwards = analysis.totalAwards + 1
		analysis.highestAward = math.max(analysis.highestAward, entry.value)
		analysis.lowestAward = math.min(analysis.lowestAward, entry.value)
	end
	
	if analysis.totalAwards > 0 then
		analysis.averageValue = math.floor(analysis.totalValue / analysis.totalAwards)
	else
		analysis.lowestAward = 0
	end
	
	return analysis
end

-- ============================================================================
-- FILTERING & QUERYING
-- ============================================================================

--- Get loot for a specific player
-- @param playerName: string
-- @param limit: number (default 100)
-- @return loot: table
function PluribusLootHistory:GetPlayerLootHistory(playerName, limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.lootLog, 1, -1 do
		if #result >= limit then break end
		local entry = self.lootLog[i]
		if entry.playerName == playerName then
			table.insert(result, entry)
		end
	end
	
	return result
end

--- Get loot by date range
-- @param startTime: number (Unix timestamp)
-- @param endTime: number (Unix timestamp)
-- @return loot: table
function PluribusLootHistory:GetLootByDateRange(startTime, endTime)
	local result = {}
	
	for _, entry in ipairs(self.lootLog) do
		if entry.timestamp >= startTime and entry.timestamp <= endTime then
			table.insert(result, entry)
		end
	end
	
	return result
end

--- Get loot by raid
-- @param raidId: string
-- @return loot: table
function PluribusLootHistory:GetRaidLoot(raidId)
	local result = {}
	
	for _, entry in ipairs(self.lootLog) do
		if entry.raidId == raidId then
			table.insert(result, entry)
		end
	end
	
	return result
end

--- Get loot for specific item
-- @param itemId: number or string
-- @param limit: number (default 50)
-- @return loot: table
function PluribusLootHistory:GetItemAwardHistory(itemId, limit)
	limit = limit or 50
	itemId = tostring(itemId)
	local result = {}
	
	for i = #self.lootLog, 1, -1 do
		if #result >= limit then break end
		local entry = self.lootLog[i]
		if tostring(entry.itemId) == itemId then
			table.insert(result, entry)
		end
	end
	
	return result
end

-- ============================================================================
-- EXPORT & REPORTING
-- ============================================================================

--- Export loot history as string
-- @param limit: number (default 500)
-- @return historyString: string
function PluribusLootHistory:ExportLootHistory(limit)
	limit = limit or 500
	local export = "LOOT HISTORY REPORT\n"
	export = export .. "===================\n\n"
	
	for i = #self.lootLog, math.max(1, #self.lootLog - limit + 1), -1 do
		local entry = self.lootLog[i]
		local timestamp = PluribusUtils:FormatTimeStamp(entry.timestamp) or "Unknown"
		export = export .. string.format("[%s] %s received %s (Value: %d) - %s\n",
			timestamp, entry.playerName, entry.itemName, entry.value, entry.reason)
	end
	
	return export
end

--- Export player comparison report
-- @return reportString: string
function PluribusLootHistory:ExportPlayerComparisonReport()
	local report = "LOOT DISTRIBUTION REPORT\n"
	report = report .. "========================\n\n"
	
	local players = self:GetTopLootRecipients(50, "value")
	
	for rank, player in ipairs(players) do
		report = report .. string.format("%d. %s - %d awards, Total: %d, Avg: %d\n",
			rank, player.name, player.totalAwards, player.totalValue, player.averageValue)
	end
	
	return report
end

--- Export item popularity report
-- @return reportString: string
function PluribusLootHistory:ExportItemPopularityReport()
	local report = "ITEM POPULARITY REPORT\n"
	report = report .. "=====================\n\n"
	
	local items = self:GetMostAwardedItems(50)
	
	for rank, item in ipairs(items) do
		report = report .. string.format("%d. Item %s - Awarded %d times, Total Value: %d\n",
			rank, item.itemId, item.awardCount, item.totalValue)
	end
	
	return report
end

--- Export comprehensive JSON report
-- @return jsonString: string
function PluribusLootHistory:ExportAsJSON()
	local json = {
		version = "1.0",
		exportTime = PluribusUtils:GetTimeStamp(),
		summary = self:GetLootAnalysis(),
		recentLoot = {},
		topPlayers = self:GetTopLootRecipients(20, "value"),
		topItems = self:GetMostAwardedItems(20),
	}
	
	-- Add recent loot (last 100)
	for i = #self.lootLog, math.max(1, #self.lootLog - 99), -1 do
		table.insert(json.recentLoot, self.lootLog[i])
	end
	
	-- Simple JSON encoding (not full JSON library)
	local jsonStr = "{\n"
	jsonStr = jsonStr .. '  "version": "1.0",\n'
	jsonStr = jsonStr .. '  "exportTime": ' .. json.exportTime .. ',\n'
	jsonStr = jsonStr .. '  "summary": {\n'
	jsonStr = jsonStr .. '    "totalValue": ' .. json.summary.totalValue .. ',\n'
	jsonStr = jsonStr .. '    "totalAwards": ' .. json.summary.totalAwards .. ',\n'
	jsonStr = jsonStr .. '    "averageValue": ' .. json.summary.averageValue .. '\n'
	jsonStr = jsonStr .. '  }\n'
	jsonStr = jsonStr .. "}\n"
	
	return jsonStr
end

-- ============================================================================
-- SESSION MANAGEMENT
-- ============================================================================

--- Start a loot session (usually for a raid)
-- @param sessionName: string
-- @param sessionId: string (optional, generated if not provided)
-- @return sessionId: string
function PluribusLootHistory:StartSession(sessionName, sessionId)
	sessionId = sessionId or ("session_" .. PluribusUtils:GetTimeStamp())
	
	self.sessionLoot[sessionId] = {
		name = sessionName,
		startTime = PluribusUtils:GetTimeStamp(),
		endTime = nil,
		lootCount = 0,
		totalValue = 0,
		loot = {},
	}
	
	PluribusUtils:Info("Session started: " .. sessionName, "LootHistory")
	self:TriggerCallback("session_started", sessionId, sessionName)
	
	return sessionId
end

--- End a loot session
-- @param sessionId: string
-- @return success: bool
function PluribusLootHistory:EndSession(sessionId)
	if not self.sessionLoot[sessionId] then
		return false
	end
	
	self.sessionLoot[sessionId].endTime = PluribusUtils:GetTimeStamp()
	
	local session = self.sessionLoot[sessionId]
	local duration = session.endTime - session.startTime
	
	PluribusUtils:Info("Session ended: " .. session.name .. " (" .. math.floor(duration/60) .. " minutes, " .. session.lootCount .. " items)", "LootHistory")
	self:TriggerCallback("session_ended", sessionId, session.lootCount, session.totalValue)
	
	return true
end

--- Add loot to current session
-- @param sessionId: string
-- @param lootEntry: table
-- @return success: bool
function PluribusLootHistory:AddToSession(sessionId, lootEntry)
	if not self.sessionLoot[sessionId] then
		return false
	end
	
	local session = self.sessionLoot[sessionId]
	table.insert(session.loot, lootEntry)
	session.lootCount = session.lootCount + 1
	session.totalValue = session.totalValue + (lootEntry.value or 0)
	
	return true
end

--- Get session statistics
-- @param sessionId: string
-- @return stats: table
function PluribusLootHistory:GetSessionStats(sessionId)
	if not self.sessionLoot[sessionId] then
		return nil
	end
	
	local session = self.sessionLoot[sessionId]
	return {
		name = session.name,
		startTime = session.startTime,
		endTime = session.endTime,
		duration = (session.endTime or PluribusUtils:GetTimeStamp()) - session.startTime,
		lootCount = session.lootCount,
		totalValue = session.totalValue,
		averageValue = session.lootCount > 0 and math.floor(session.totalValue / session.lootCount) or 0,
	}
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if admin
-- @return isAdmin: bool
function PluribusLootHistory:IsAdminOnly()
	if not self.config.adminOnly then
		return true
	end
	
	-- Check with access control if available
	if PluribusLootAccessControl and PluribusLootAccessControl.HasPermission then
		return PluribusLootAccessControl:HasPermission(UnitName("player"), "audit_loot")
	end
	
	return true
end

--- Register callback
-- @param callback: function
function PluribusLootHistory:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback
-- @param event: string
-- @param ...: varargs
function PluribusLootHistory:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return PluribusLootHistory
