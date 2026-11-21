-- TaxSystem Module
-- Handles DKP taxation system: gold → DKP conversion
-- Guild masters can collect taxes from members

local InfinityDKPTaxSystem = {}
_G.InfinityDKPTaxSystem = InfinityDKPTaxSystem

-- Tax configuration
InfinityDKPTaxSystem.config = {
	taxRatePercentage = 5, -- Default 5% of gold earned
	dkpPerGold = 0.1, -- DKP per gold (can be edited directly)
	minTaxAmount = 10, -- Minimum gold to collect tax on
	maxTaxPerDay = 100, -- Maximum tax per day per player
	enabled = true,
	adminOnly = true, -- Only admins can configure taxes
	useDirectDKPAmount = false, -- If true, use dkpPerGold; if false, use taxRatePercentage
}

-- Blacklisted items (won't be taxed)
InfinityDKPTaxSystem.blacklistedItems = {} -- {itemId = true}

-- Whitelisted items (only these will be taxed if in whitelist mode)
InfinityDKPTaxSystem.whitelistedItems = {} -- {itemId = true}

-- Whitelist mode (if true, only whitelisted items taxed; if false, all except blacklisted)
InfinityDKPTaxSystem.whitelistMode = false

-- Tax records per player
InfinityDKPTaxSystem.taxRecords = {} -- {playerName = {totalTaxed=X, dailyTaxToday=Y, lastTaxDate=Z, transactions={...}}}

-- Tax history (audit trail)
InfinityDKPTaxSystem.taxHistory = {}

-- Callbacks
InfinityDKPTaxSystem.callbacks = {}

-- ============================================================================
-- TAX CONFIGURATION
-- ============================================================================

--- Set the tax rate (percentage)
-- @param percentage: 0-100 (e.g., 5 = 5%)
-- @return success: bool
function InfinityDKPTaxSystem:SetTaxRate(percentage)
	if not self:IsAdminOnly() then
		return false
	end
	
	percentage = tonumber(percentage) or 5
	if percentage < 0 or percentage > 100 then
		InfinityUtils:Warning("Tax rate must be 0-100%", "TaxSystem")
		return false
	end
	
	self.config.taxRatePercentage = percentage
	self.config.useDirectDKPAmount = false -- Switch to percentage mode
	
	InfinityUtils:Info("Tax rate set to " .. percentage .. "%", "TaxSystem")
	self:TriggerCallback("tax_rate_changed", percentage)
	return true
end

--- Set direct DKP per gold amount
-- Allows fine-grained control: e.g., 0.5 = 1 DKP per 2 gold, 1.0 = 1 DKP per 1 gold
-- @param dkpPerGold: number (e.g., 0.1 = 1 DKP per 10 gold)
-- @return success: bool
function InfinityDKPTaxSystem:SetDKPPerGold(dkpPerGold)
	if not self:IsAdminOnly() then
		return false
	end
	
	dkpPerGold = tonumber(dkpPerGold) or 0.1
	if dkpPerGold < 0 then
		InfinityUtils:Warning("DKP per gold must be >= 0", "TaxSystem")
		return false
	end
	
	self.config.dkpPerGold = dkpPerGold
	self.config.useDirectDKPAmount = true -- Switch to direct amount mode
	
	InfinityUtils:Info("DKP per gold set to " .. dkpPerGold, "TaxSystem")
	self:TriggerCallback("dkp_per_gold_changed", dkpPerGold)
	return true
end

--- Set minimum tax threshold
-- @param amount: gold amount
-- @return success: bool
function InfinityDKPTaxSystem:SetMinTaxAmount(amount)
	if not self:IsAdminOnly() then
		return false
	end
	
	amount = tonumber(amount) or 10
	if amount < 0 then
		return false
	end
	
	self.config.minTaxAmount = amount
	InfinityUtils:Info("Minimum tax amount set to " .. amount .. "g", "TaxSystem")
	self:TriggerCallback("min_tax_changed", amount)
	return true
end

--- Set maximum tax per day per player
-- @param amount: gold amount
-- @return success: bool
function InfinityDKPTaxSystem:SetMaxTaxPerDay(amount)
	if not self:IsAdminOnly() then
		return false
	end
	
	amount = tonumber(amount) or 100
	if amount < 0 then
		return false
	end
	
	self.config.maxTaxPerDay = amount
	InfinityUtils:Info("Max tax per day set to " .. amount .. "g", "TaxSystem")
	self:TriggerCallback("max_tax_changed", amount)
	return true
end

--- Enable/disable taxes
-- @param enabled: bool
-- @return success: bool
function InfinityDKPTaxSystem:SetEnabled(enabled)
	if not self:IsAdminOnly() then
		return false
	end
	
	self.config.enabled = enabled
	InfinityUtils:Info("Tax system " .. (enabled and "enabled" or "disabled"), "TaxSystem")
	self:TriggerCallback("tax_enabled_changed", enabled)
	return true
end

-- ============================================================================
-- TAX COLLECTION
-- ============================================================================

--- Collect tax on gold earnings (called when player earns gold)
-- @param playerName: string
-- @param goldEarned: number (amount of gold earned)
-- @param reason: string (quest reward, loot, etc.)
-- @return dkpAwarded: number (DKP given for tax payment)
function InfinityDKPTaxSystem:CollectTax(playerName, goldEarned, reason)
	if not self.config.enabled or not playerName or not goldEarned then
		return 0
	end
	
	goldEarned = tonumber(goldEarned) or 0
	
	-- Check if tax threshold met
	if goldEarned < self.config.minTaxAmount then
		return 0
	end
	
	-- Calculate tax amount
	local taxAmount = math.floor(goldEarned * self.config.taxRatePercentage / 100)
	if taxAmount <= 0 then
		return 0
	end
	
	-- Check daily tax limit
	if not self:CanApplyTax(playerName, taxAmount) then
		InfinityUtils:Warning("Daily tax limit exceeded for " .. playerName, "TaxSystem")
		return 0
	end
	
	-- Initialize player record if not exists
	if not self.taxRecords[playerName] then
		self.taxRecords[playerName] = {
			totalTaxed = 0,
			dailyTaxToday = 0,
			lastTaxDate = date("%Y-%m-%d"),
			transactions = {},
		}
	end
	
	-- Award DKP (calculate based on configuration mode)
	local dkpAwarded
	if self.config.useDirectDKPAmount then
		-- Direct amount: goldEarned * dkpPerGold
		dkpAwarded = math.floor(goldEarned * self.config.dkpPerGold)
	else
		-- Percentage mode: (goldEarned * taxRatePercentage / 100) / 10
		dkpAwarded = math.ceil(taxAmount / 10)
	end
	
	-- Record transaction
	local transaction = {
		playerName = playerName,
		goldTaxed = taxAmount,
		dkpAwarded = dkpAwarded,
		reason = reason or "Tax",
		timestamp = date("%Y-%m-%d %H:%M:%S"),
		time = GetTime(),
	}
	
	-- Update player record
	self.taxRecords[playerName].totalTaxed = self.taxRecords[playerName].totalTaxed + taxAmount
	self.taxRecords[playerName].dailyTaxToday = self.taxRecords[playerName].dailyTaxToday + taxAmount
	table.insert(self.taxRecords[playerName].transactions, transaction)
	
	-- Add to history
	table.insert(self.taxHistory, transaction)
	
	-- Award DKP points through Points module
	if _G.InfinityDKPPoints then
		_G.InfinityDKPPoints:LogTransaction(playerName, "tax_payment", dkpAwarded, 
			"Tax payment: " .. taxAmount .. "g (" .. reason .. ")")
	end
	
	-- Trigger callback
	self:TriggerCallback("tax_collected", playerName, taxAmount, dkpAwarded, reason)
	
	InfinityUtils:Info("Tax collected from " .. playerName .. ": " .. taxAmount .. "g → " .. dkpAwarded .. " DKP", "TaxSystem")
	
	return dkpAwarded
end

--- Check if tax can be applied (daily limit not exceeded)
-- @param playerName: string
-- @param taxAmount: number
-- @return canApply: bool
function InfinityDKPTaxSystem:CanApplyTax(playerName, taxAmount)
	local record = self.taxRecords[playerName]
	
	-- No record yet, first tax of session
	if not record then
		return taxAmount <= self.config.maxTaxPerDay
	end
	
	-- Check if it's a new day
	local today = date("%Y-%m-%d")
	if record.lastTaxDate ~= today then
		-- Reset daily tax counter
		record.dailyTaxToday = 0
		record.lastTaxDate = today
	end
	
	-- Check if adding this tax would exceed daily limit
	return (record.dailyTaxToday + taxAmount) <= self.config.maxTaxPerDay
end

--- Get remaining daily tax budget for a player
-- @param playerName: string
-- @return remainingBudget: number (gold)
function InfinityDKPTaxSystem:GetRemainingDailyTaxBudget(playerName)
	local record = self.taxRecords[playerName]
	if not record then
		return self.config.maxTaxPerDay
	end
	
	-- Check if it's a new day
	local today = date("%Y-%m-%d")
	if record.lastTaxDate ~= today then
		return self.config.maxTaxPerDay
	end
	
	return math.max(0, self.config.maxTaxPerDay - record.dailyTaxToday)
end

-- ============================================================================
-- TAX QUERIES & REPORTS
-- ============================================================================

--- Get tax statistics for a player
-- @param playerName: string
-- @return stats: table {totalTaxed, transactionCount, lastTax}
function InfinityDKPTaxSystem:GetPlayerTaxStats(playerName)
	local record = self.taxRecords[playerName]
	
	if not record then
		return {
			totalTaxed = 0,
			transactionCount = 0,
			lastTax = "Never",
			averageTaxPerDay = 0,
		}
	end
	
	return {
		totalTaxed = record.totalTaxed,
		transactionCount = #record.transactions,
		lastTax = record.transactions[#record.transactions] and 
			record.transactions[#record.transactions].timestamp or "Never",
		averageTaxPerDay = math.floor(record.totalTaxed / (#record.transactions + 1)),
		dailyTaxToday = record.dailyTaxToday,
		remainingBudget = self:GetRemainingDailyTaxBudget(playerName),
	}
end

--- Get tax transactions for a player
-- @param playerName: string
-- @param limit: number (default 50)
-- @return transactions: table
function InfinityDKPTaxSystem:GetPlayerTaxTransactions(playerName, limit)
	limit = limit or 50
	local record = self.taxRecords[playerName]
	
	if not record or not record.transactions then
		return {}
	end
	
	local result = {}
	for i = #record.transactions, math.max(1, #record.transactions - limit + 1), -1 do
		table.insert(result, record.transactions[i])
	end
	
	return result
end

--- Get guild-wide tax statistics
-- @return stats: table {totalCollected, playerCount, transactionCount}
function InfinityDKPTaxSystem:GetGuildTaxStats()
	local totalCollected = 0
	local playerCount = 0
	local transactionCount = #self.taxHistory
	
	for playerName, record in pairs(self.taxRecords) do
		totalCollected = totalCollected + record.totalTaxed
		playerCount = playerCount + 1
	end
	
	return {
		totalCollected = totalCollected,
		playerCount = playerCount,
		transactionCount = transactionCount,
		averagePerPlayer = playerCount > 0 and math.floor(totalCollected / playerCount) or 0,
		taxRate = self.config.taxRatePercentage .. "%",
	}
end

--- Export tax history for audit
-- @return historyString: string (formatted for display)
function InfinityDKPTaxSystem:ExportTaxHistory(limit)
	limit = limit or 100
	local export = "GUILD TAX HISTORY\n"
	export = export .. "=================\n\n"
	
	for i = #self.taxHistory, math.max(1, #self.taxHistory - limit + 1), -1 do
		local trans = self.taxHistory[i]
		export = export .. string.format("%s | %s | %dg → %d DKP | %s\n",
			trans.timestamp, trans.playerName, trans.goldTaxed, trans.dkpAwarded, trans.reason)
	end
	
	return export
end

-- ============================================================================
-- ITEM FILTERING (WHITELIST/BLACKLIST)
-- ============================================================================

--- Set whitelist mode (only listed items taxed)
-- @param enabled: bool
-- @return success: bool
function InfinityDKPTaxSystem:SetWhitelistMode(enabled)
	if not self:IsAdminOnly() then
		return false
	end
	
	self.whitelistMode = enabled
	InfinityUtils:Info("Whitelist mode " .. (enabled and "enabled" or "disabled"), "TaxSystem")
	self:TriggerCallback("whitelist_mode_changed", enabled)
	return true
end

--- Add item to whitelist (only these items will be taxed when whitelist mode on)
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPTaxSystem:WhitelistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	if not itemId or itemId == "" then
		return false
	end
	
	self.whitelistedItems[itemId] = true
	InfinityUtils:Info("Item " .. itemId .. " added to whitelist", "TaxSystem")
	self:TriggerCallback("item_whitelisted", itemId)
	return true
end

--- Remove item from whitelist
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPTaxSystem:UnwhitelistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	self.whitelistedItems[itemId] = nil
	InfinityUtils:Info("Item " .. itemId .. " removed from whitelist", "TaxSystem")
	self:TriggerCallback("item_unwhitelisted", itemId)
	return true
end

--- Add item to blacklist (this item won't be taxed)
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPTaxSystem:BlacklistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	if not itemId or itemId == "" then
		return false
	end
	
	self.blacklistedItems[itemId] = true
	InfinityUtils:Info("Item " .. itemId .. " added to blacklist", "TaxSystem")
	self:TriggerCallback("item_blacklisted", itemId)
	return true
end

--- Remove item from blacklist
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPTaxSystem:UnblacklistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	self.blacklistedItems[itemId] = nil
	InfinityUtils:Info("Item " .. itemId .. " removed from blacklist", "TaxSystem")
	self:TriggerCallback("item_unblacklisted", itemId)
	return true
end

--- Check if item should be taxed
-- @param itemId: number or string
-- @return shouldTax: bool
function InfinityDKPTaxSystem:ShouldTaxItem(itemId)
	itemId = tostring(itemId)
	
	if self.whitelistMode then
		-- Whitelist mode: only tax if whitelisted
		return self.whitelistedItems[itemId] == true
	else
		-- Blacklist mode: tax unless blacklisted
		return self.blacklistedItems[itemId] ~= true
	end
end

--- Get whitelist
-- @return items: table {itemId = true, ...}
function InfinityDKPTaxSystem:GetWhitelist()
	return self.whitelistedItems
end

--- Get blacklist
-- @return items: table {itemId = true, ...}
function InfinityDKPTaxSystem:GetBlacklist()
	return self.blacklistedItems
end

--- Clear whitelist
-- @return success: bool
function InfinityDKPTaxSystem:ClearWhitelist()
	if not self:IsAdminOnly() then
		return false
	end
	
	self.whitelistedItems = {}
	InfinityUtils:Info("Whitelist cleared", "TaxSystem")
	self:TriggerCallback("whitelist_cleared")
	return true
end

--- Clear blacklist
-- @return success: bool
function InfinityDKPTaxSystem:ClearBlacklist()
	if not self:IsAdminOnly() then
		return false
	end
	
	self.blacklistedItems = {}
	InfinityUtils:Info("Blacklist cleared", "TaxSystem")
	self:TriggerCallback("blacklist_cleared")
	return true
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if player is admin
-- @return isAdmin: bool
function InfinityDKPTaxSystem:IsAdminOnly()
	if not self.config.adminOnly then
		return true
	end
	
	-- Check if player is guild master or officer
	local playerName = UnitName("player")
	local guildName = GetGuildInfo("player")
	
	if not guildName then
		return false
	end
	
	-- Check if player is guild master or officer
	if InfinityGuildRoster then
		local playerName = UnitName("player")
		local player = InfinityGuildRoster.members[playerName]
		if player and (player.rank == "Guild Master" or player.rank == "Officer") then
			return true
		end
	end
	
	-- Fallback to basic guild master check
	local rank = UnitPVPRank("player")
	return true
end

--- Register callback for tax events
-- @param callback: function
function InfinityDKPTaxSystem:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback event
-- @param event: string
-- @param ...: varargs (event-specific data)
function InfinityDKPTaxSystem:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return InfinityDKPTaxSystem

