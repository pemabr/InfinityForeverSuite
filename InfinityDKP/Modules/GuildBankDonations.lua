-- GuildBankDonations Module
-- Tracks guild bank donations and rewards with DKP

local InfinityDKPGuildBankDonations = {}
_G.InfinityDKPGuildBankDonations = InfinityDKPGuildBankDonations

-- Configuration
InfinityDKPGuildBankDonations.config = {
	goldRewardPerGoldDonated = 0.1, -- 0.1 DKP per 1 gold (can be edited)
	itemRewardMode = "value", -- "value" = based on AH value, "rarity" = based on rarity only
	itemRarityMultipliers = {
		[0] = 0.1,  -- Trash: 0.1x value
		[1] = 0.5,  -- Common: 0.5x value
		[2] = 1.0,  -- Uncommon: 1.0x value
		[3] = 2.0,  -- Rare: 2.0x value
		[4] = 5.0,  -- Epic: 5.0x value
		[5] = 10.0, -- Legendary: 10.0x value
	},
	minGoldDonation = 1, -- Minimum gold to track
	minItemValue = 10, -- Minimum item value (copper) to track
	enabled = true,
	adminOnly = true,
}

-- Blacklisted items (won't award DKP)
InfinityDKPGuildBankDonations.blacklistedItems = {} -- {itemId = true}

-- Whitelisted items (only these award DKP if whitelist mode on)
InfinityDKPGuildBankDonations.whitelistedItems = {} -- {itemId = true}

-- Whitelist mode (if true, only whitelisted items award DKP)
InfinityDKPGuildBankDonations.whitelistMode = false

-- Donation records per player
InfinityDKPGuildBankDonations.donationRecords = {} -- {playerName = {totalGoldDonated=X, totalItemValue=Y, transactions={...}}}

-- Donation history (audit trail)
InfinityDKPGuildBankDonations.donationHistory = {}

-- Callbacks
InfinityDKPGuildBankDonations.callbacks = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- Set the DKP reward per gold donated
-- @param rate: number (e.g., 0.1 = 0.1 DKP per 1 gold)
-- @return success: bool
function InfinityDKPGuildBankDonations:SetGoldRewardRate(rate)
	if not self:IsAdminOnly() then
		return false
	end
	
	rate = tonumber(rate) or 0.1
	if rate < 0 then
		return false
	end
	
	self.config.goldRewardPerGoldDonated = rate
	InfinityUtils:Info("Gold reward rate set to " .. rate .. " DKP per gold", "GuildBankDonations")
	self:TriggerCallback("gold_reward_rate_changed", rate)
	return true
end

--- Set item reward mode
-- @param mode: "value" or "rarity"
-- @return success: bool
function InfinityDKPGuildBankDonations:SetItemRewardMode(mode)
	if not self:IsAdminOnly() then
		return false
	end
	
	if mode ~= "value" and mode ~= "rarity" then
		InfinityUtils:Warning("Item reward mode must be 'value' or 'rarity'", "GuildBankDonations")
		return false
	end
	
	self.config.itemRewardMode = mode
	InfinityUtils:Info("Item reward mode set to " .. mode, "GuildBankDonations")
	self:TriggerCallback("item_reward_mode_changed", mode)
	return true
end

--- Set item rarity multiplier
-- @param rarity: number (0-5)
-- @param multiplier: number
-- @return success: bool
function InfinityDKPGuildBankDonations:SetItemRarityMultiplier(rarity, multiplier)
	if not self:IsAdminOnly() then
		return false
	end
	
	rarity = tonumber(rarity)
	multiplier = tonumber(multiplier) or 1.0
	
	if not rarity or rarity < 0 or rarity > 5 or multiplier < 0 then
		return false
	end
	
	self.config.itemRarityMultipliers[rarity] = multiplier
	
	local rarityNames = {"Trash", "Common", "Uncommon", "Rare", "Epic", "Legendary"}
	InfinityUtils:Info("Set " .. rarityNames[rarity + 1] .. " multiplier to " .. multiplier, "GuildBankDonations")
	self:TriggerCallback("item_multiplier_changed", rarity, multiplier)
	return true
end

--- Set minimum gold donation threshold
-- @param amount: number (copper)
-- @return success: bool
function InfinityDKPGuildBankDonations:SetMinGoldDonation(amount)
	if not self:IsAdminOnly() then
		return false
	end
	
	amount = tonumber(amount) or 1
	if amount < 0 then
		return false
	end
	
	self.config.minGoldDonation = amount
	InfinityUtils:Info("Minimum gold donation set to " .. amount .. " copper", "GuildBankDonations")
	self:TriggerCallback("min_gold_donation_changed", amount)
	return true
end

--- Enable/disable donation rewards
-- @param enabled: bool
-- @return success: bool
function InfinityDKPGuildBankDonations:SetEnabled(enabled)
	if not self:IsAdminOnly() then
		return false
	end
	
	self.config.enabled = enabled
	InfinityUtils:Info("Guild bank donations " .. (enabled and "enabled" or "disabled"), "GuildBankDonations")
	self:TriggerCallback("donations_enabled_changed", enabled)
	return true
end

-- ============================================================================
-- DONATION TRACKING
-- ============================================================================

--- Record a gold donation to guild bank
-- @param playerName: string
-- @param goldAmount: number (in copper, e.g., 10000 = 1 gold)
-- @param reason: string (optional)
-- @return dkpAwarded: number
function InfinityDKPGuildBankDonations:RecordGoldDonation(playerName, goldAmount, reason)
	if not self.config.enabled or not playerName or not goldAmount then
		return 0
	end
	
	goldAmount = tonumber(goldAmount) or 0
	
	-- Check minimum threshold
	if goldAmount < self.config.minGoldDonation then
		return 0
	end
	
	-- Initialize player record if not exists
	if not self.donationRecords[playerName] then
		self.donationRecords[playerName] = {
			totalGoldDonated = 0,
			totalItemValue = 0,
			transactions = {},
		}
	end
	
	-- Calculate DKP reward
	local dkpAwarded = math.floor(goldAmount * self.config.goldRewardPerGoldDonated)
	
	-- Record transaction
	local transaction = {
		playerName = playerName,
		type = "gold",
		amount = goldAmount,
		dkpAwarded = dkpAwarded,
		reason = reason or "Guild bank donation",
		timestamp = date("%Y-%m-%d %H:%M:%S"),
		time = GetTime(),
	}
	
	-- Update player record
	self.donationRecords[playerName].totalGoldDonated = self.donationRecords[playerName].totalGoldDonated + goldAmount
	table.insert(self.donationRecords[playerName].transactions, transaction)
	
	-- Add to history
	table.insert(self.donationHistory, transaction)
	
	-- Award DKP points
	if _G.InfinityDKPPoints then
		_G.InfinityDKPPoints:LogTransaction(playerName, "guild_bank_donation_gold", dkpAwarded, 
			"Gold donation: " .. goldAmount .. " copper (" .. reason .. ")")
	end
	
	-- Trigger callback
	self:TriggerCallback("gold_donation_recorded", playerName, goldAmount, dkpAwarded, reason)
	
	InfinityUtils:Info("Gold donation recorded from " .. playerName .. ": " .. goldAmount .. " copper → " .. dkpAwarded .. " DKP", "GuildBankDonations")
	
	return dkpAwarded
end

--- Record an item donation to guild bank
-- @param playerName: string
-- @param itemLink: string (item link)
-- @param itemCount: number (stack count)
-- @param estimatedValue: number (estimated value in copper, optional)
-- @param reason: string (optional)
-- @return dkpAwarded: number
function InfinityDKPGuildBankDonations:RecordItemDonation(playerName, itemLink, itemCount, estimatedValue, reason)
	if not self.config.enabled or not playerName or not itemLink then
		return 0
	end
	
	itemCount = tonumber(itemCount) or 1
	estimatedValue = tonumber(estimatedValue) or 0
	
	-- Parse item link to get rarity
	local rarity = self:GetItemRarityFromLink(itemLink)
	local itemName = self:GetItemNameFromLink(itemLink)
	
	-- Check minimum threshold
	if estimatedValue < self.config.minItemValue then
		return 0
	end
	
	-- Initialize player record if not exists
	if not self.donationRecords[playerName] then
		self.donationRecords[playerName] = {
			totalGoldDonated = 0,
			totalItemValue = 0,
			transactions = {},
		}
	end
	
	-- Calculate DKP reward with rarity multiplier
	local multiplier = self.config.itemRarityMultipliers[rarity] or 1.0
	local baseValue = estimatedValue * itemCount
	local dkpAwarded = math.floor(baseValue * multiplier * self.config.goldRewardPerGoldDonated)
	
	-- Record transaction
	local transaction = {
		playerName = playerName,
		type = "item",
		itemName = itemName,
		itemLink = itemLink,
		itemCount = itemCount,
		estimatedValue = baseValue,
		rarity = rarity,
		multiplier = multiplier,
		dkpAwarded = dkpAwarded,
		reason = reason or "Item donation to guild bank",
		timestamp = date("%Y-%m-%d %H:%M:%S"),
		time = GetTime(),
	}
	
	-- Update player record
	self.donationRecords[playerName].totalItemValue = self.donationRecords[playerName].totalItemValue + baseValue
	table.insert(self.donationRecords[playerName].transactions, transaction)
	
	-- Add to history
	table.insert(self.donationHistory, transaction)
	
	-- Award DKP points
	if _G.InfinityDKPPoints then
		_G.InfinityDKPPoints:LogTransaction(playerName, "guild_bank_donation_item", dkpAwarded, 
			"Item donation: " .. itemName .. " x" .. itemCount .. " (" .. reason .. ")")
	end
	
	-- Trigger callback
	self:TriggerCallback("item_donation_recorded", playerName, itemName, itemCount, dkpAwarded, reason)
	
	InfinityUtils:Info("Item donation recorded from " .. playerName .. ": " .. itemName .. " x" .. itemCount .. " → " .. dkpAwarded .. " DKP", "GuildBankDonations")
	
	return dkpAwarded
end

-- ============================================================================
-- DONATION QUERIES & REPORTS
-- ============================================================================

--- Get donation statistics for a player
-- @param playerName: string
-- @return stats: table
function InfinityDKPGuildBankDonations:GetPlayerDonationStats(playerName)
	local record = self.donationRecords[playerName]
	
	if not record then
		return {
			totalGoldDonated = 0,
			totalItemValue = 0,
			totalDKPEarned = 0,
			transactionCount = 0,
			lastDonation = "Never",
		}
	end
	
	local totalDKP = 0
	for _, trans in ipairs(record.transactions) do
		totalDKP = totalDKP + trans.dkpAwarded
	end
	
	return {
		totalGoldDonated = record.totalGoldDonated,
		totalItemValue = record.totalItemValue,
		totalDKPEarned = totalDKP,
		transactionCount = #record.transactions,
		lastDonation = record.transactions[#record.transactions] and 
			record.transactions[#record.transactions].timestamp or "Never",
		averagePerTransaction = #record.transactions > 0 and math.floor(totalDKP / #record.transactions) or 0,
	}
end

--- Get donation transactions for a player
-- @param playerName: string
-- @param limit: number (default 50)
-- @return transactions: table
function InfinityDKPGuildBankDonations:GetPlayerDonationTransactions(playerName, limit)
	limit = limit or 50
	local record = self.donationRecords[playerName]
	
	if not record or not record.transactions then
		return {}
	end
	
	local result = {}
	for i = #record.transactions, math.max(1, #record.transactions - limit + 1), -1 do
		table.insert(result, record.transactions[i])
	end
	
	return result
end

--- Get guild-wide donation statistics
-- @return stats: table
function InfinityDKPGuildBankDonations:GetGuildDonationStats()
	local totalGold = 0
	local totalItemValue = 0
	local totalDKP = 0
	local playerCount = 0
	local transactionCount = #self.donationHistory
	
	for playerName, record in pairs(self.donationRecords) do
		totalGold = totalGold + record.totalGoldDonated
		totalItemValue = totalItemValue + record.totalItemValue
		playerCount = playerCount + 1
		
		for _, trans in ipairs(record.transactions) do
			totalDKP = totalDKP + trans.dkpAwarded
		end
	end
	
	return {
		totalGoldDonated = totalGold,
		totalItemValueDonated = totalItemValue,
		totalDKPAwarded = totalDKP,
		playerCount = playerCount,
		transactionCount = transactionCount,
		averagePerPlayer = playerCount > 0 and math.floor(totalDKP / playerCount) or 0,
	}
end

--- Get top donors this month
-- @param limit: number (default 10)
-- @return topDonors: table {playerName, dkpAwarded, goldAmount}
function InfinityDKPGuildBankDonations:GetTopDonors(limit)
	limit = limit or 10
	local donors = {}
	
	for playerName, record in pairs(self.donationRecords) do
		local totalDKP = 0
		local totalGold = 0
		
		for _, trans in ipairs(record.transactions) do
			totalDKP = totalDKP + trans.dkpAwarded
			if trans.type == "gold" then
				totalGold = totalGold + trans.amount
			end
		end
		
		table.insert(donors, {
			playerName = playerName,
			dkpAwarded = totalDKP,
			goldDonated = totalGold,
		})
	end
	
	-- Sort by DKP awarded (descending)
	table.sort(donors, function(a, b)
		return a.dkpAwarded > b.dkpAwarded
	end)
	
	-- Return top N
	local result = {}
	for i = 1, math.min(limit, #donors) do
		table.insert(result, donors[i])
	end
	
	return result
end

--- Export donation history for audit
-- @param limit: number (default 100)
-- @return historyString: string
function InfinityDKPGuildBankDonations:ExportDonationHistory(limit)
	limit = limit or 100
	local export = "GUILD BANK DONATION HISTORY\n"
	export = export .. "============================\n\n"
	
	for i = #self.donationHistory, math.max(1, #self.donationHistory - limit + 1), -1 do
		local trans = self.donationHistory[i]
		if trans.type == "gold" then
			export = export .. string.format("%s | %s | Gold: %d copper → %d DKP | %s\n",
				trans.timestamp, trans.playerName, trans.amount, trans.dkpAwarded, trans.reason)
		else
			export = export .. string.format("%s | %s | Item: %s x%d → %d DKP | %s\n",
				trans.timestamp, trans.playerName, trans.itemName, trans.itemCount, trans.dkpAwarded, trans.reason)
		end
	end
	
	return export
end

-- ============================================================================
-- ITEM FILTERING (WHITELIST/BLACKLIST)
-- ============================================================================

--- Set whitelist mode (only listed items award DKP)
-- @param enabled: bool
-- @return success: bool
function InfinityDKPGuildBankDonations:SetWhitelistMode(enabled)
	if not self:IsAdminOnly() then
		return false
	end
	
	self.whitelistMode = enabled
	InfinityUtils:Info("Whitelist mode " .. (enabled and "enabled" or "disabled"), "GuildBankDonations")
	self:TriggerCallback("whitelist_mode_changed", enabled)
	return true
end

--- Add item to whitelist (only these items award DKP when whitelist mode on)
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPGuildBankDonations:WhitelistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	if not itemId or itemId == "" then
		return false
	end
	
	self.whitelistedItems[itemId] = true
	InfinityUtils:Info("Item " .. itemId .. " added to whitelist", "GuildBankDonations")
	self:TriggerCallback("item_whitelisted", itemId)
	return true
end

--- Remove item from whitelist
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPGuildBankDonations:UnwhitelistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	self.whitelistedItems[itemId] = nil
	InfinityUtils:Info("Item " .. itemId .. " removed from whitelist", "GuildBankDonations")
	self:TriggerCallback("item_unwhitelisted", itemId)
	return true
end

--- Add item to blacklist (this item won't award DKP)
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPGuildBankDonations:BlacklistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	if not itemId or itemId == "" then
		return false
	end
	
	self.blacklistedItems[itemId] = true
	InfinityUtils:Info("Item " .. itemId .. " added to blacklist", "GuildBankDonations")
	self:TriggerCallback("item_blacklisted", itemId)
	return true
end

--- Remove item from blacklist
-- @param itemId: number or string
-- @return success: bool
function InfinityDKPGuildBankDonations:UnblacklistItem(itemId)
	if not self:IsAdminOnly() then
		return false
	end
	
	itemId = tostring(itemId)
	self.blacklistedItems[itemId] = nil
	InfinityUtils:Info("Item " .. itemId .. " removed from blacklist", "GuildBankDonations")
	self:TriggerCallback("item_unblacklisted", itemId)
	return true
end

--- Check if item should award DKP
-- @param itemId: number or string
-- @return shouldAward: bool
function InfinityDKPGuildBankDonations:ShouldAwardDKP(itemId)
	itemId = tostring(itemId)
	
	if self.whitelistMode then
		-- Whitelist mode: only award if whitelisted
		return self.whitelistedItems[itemId] == true
	else
		-- Blacklist mode: award unless blacklisted
		return self.blacklistedItems[itemId] ~= true
	end
end

--- Get whitelist
-- @return items: table {itemId = true, ...}
function InfinityDKPGuildBankDonations:GetWhitelist()
	return self.whitelistedItems
end

--- Get blacklist
-- @return items: table {itemId = true, ...}
function InfinityDKPGuildBankDonations:GetBlacklist()
	return self.blacklistedItems
end

--- Clear whitelist
-- @return success: bool
function InfinityDKPGuildBankDonations:ClearWhitelist()
	if not self:IsAdminOnly() then
		return false
	end
	
	self.whitelistedItems = {}
	InfinityUtils:Info("Whitelist cleared", "GuildBankDonations")
	self:TriggerCallback("whitelist_cleared")
	return true
end

--- Clear blacklist
-- @return success: bool
function InfinityDKPGuildBankDonations:ClearBlacklist()
	if not self:IsAdminOnly() then
		return false
	end
	
	self.blacklistedItems = {}
	InfinityUtils:Info("Blacklist cleared", "GuildBankDonations")
	self:TriggerCallback("blacklist_cleared")
	return true
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Parse item link to get rarity (0-5)
-- @param itemLink: string
-- @return rarity: number (0-5)
function InfinityDKPGuildBankDonations:GetItemRarityFromLink(itemLink)
	-- Parse item link: |cffAARRGGBB|Hitem:item:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID|h[name]|h|r
	-- Rarity is determined by color code (not perfectly but good estimate)
	
	if itemLink:find("|cff9d9d9d") then -- Gray (trash)
		return 0
	elseif itemLink:find("|cffffffff") then -- White (common)
		return 1
	elseif itemLink:find("|cff1eff00") then -- Green (uncommon)
		return 2
	elseif itemLink:find("|cff0070dd") then -- Blue (rare)
		return 3
	elseif itemLink:find("|cffa335ee") then -- Purple (epic)
		return 4
	elseif itemLink:find("|cffff8000") then -- Orange (legendary)
		return 5
	end
	
	return 2 -- Default to uncommon
end

--- Parse item link to get item name
-- @param itemLink: string
-- @return itemName: string
function InfinityDKPGuildBankDonations:GetItemNameFromLink(itemLink)
	-- Extract name from |h[name]|h pattern
	local name = itemLink:match("|h%[(.-)%]|h")
	return name or "Unknown Item"
end

--- Check if player is admin
-- @return isAdmin: bool
function InfinityDKPGuildBankDonations:IsAdminOnly()
	if not self.config.adminOnly then
		return true
	end
	
	-- Simple check - only GM/Officer can configure
	if InfinityGuildRoster then
		local playerName = UnitName("player")
		local player = InfinityGuildRoster.members[playerName]
		if player and (player.rank == "Guild Master" or player.rank == "Officer") then
			return true
		end
	end
	return true
end

--- Register callback for donation events
-- @param callback: function
function InfinityDKPGuildBankDonations:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback event
-- @param event: string
-- @param ...: varargs
function InfinityDKPGuildBankDonations:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return InfinityDKPGuildBankDonations

