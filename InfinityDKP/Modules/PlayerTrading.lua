-- PlayerTrading Module
-- Allows guild members to trade DKP with each other

local InfinityDKPPlayerTrading = {}
_G.InfinityDKPPlayerTrading = InfinityDKPPlayerTrading

-- Configuration
InfinityDKPPlayerTrading.config = {
	enabled = true,
	maxTransferPerTrade = 1000, -- Max DKP in single trade
	minTransferAmount = 1, -- Minimum DKP per trade
	dailyTransferLimit = 5000, -- Max DKP transferred per player per day
	cooldownSeconds = 60, -- Cooldown between trades
	requireBothOnline = true, -- Both players must be online
	requireGuild = true, -- Both must be in same guild
	enableTradeLog = true, -- Log all trades for audit
}

-- Active trade offers (pending acceptance)
InfinityDKPPlayerTrading.tradeOffers = {} -- {offerId = {offerer, recipient, amount, timestamp, expires}}

-- Completed trades (audit trail)
InfinityDKPPlayerTrading.tradeHistory = {}

-- Player statistics
InfinityDKPPlayerTrading.playerStats = {} -- {playerName = {dailyTransferred, lastTradeTime, totalTraded}}

-- Trade locks (prevent spamming)
InfinityDKPPlayerTrading.tradeLocks = {} -- {playerName = {lastTradeTime, totalToday}}

-- Callbacks
InfinityDKPPlayerTrading.callbacks = {}

-- Next trade offer ID
InfinityDKPPlayerTrading.nextOfferId = 1

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- Set maximum transfer per single trade
-- @param amount: number (DKP)
-- @return success: bool
function InfinityDKPPlayerTrading:SetMaxTransferPerTrade(amount)
	amount = tonumber(amount) or 1000
	if amount < 1 then
		return false
	end
	
	self.config.maxTransferPerTrade = amount
	InfinityUtils:Info("Max transfer per trade set to " .. amount .. " DKP", "PlayerTrading")
	self:TriggerCallback("max_transfer_changed", amount)
	return true
end

--- Set daily transfer limit per player
-- @param amount: number (DKP)
-- @return success: bool
function InfinityDKPPlayerTrading:SetDailyTransferLimit(amount)
	amount = tonumber(amount) or 5000
	if amount < 1 then
		return false
	end
	
	self.config.dailyTransferLimit = amount
	InfinityUtils:Info("Daily transfer limit set to " .. amount .. " DKP", "PlayerTrading")
	self:TriggerCallback("daily_limit_changed", amount)
	return true
end

--- Set cooldown between trades
-- @param seconds: number
-- @return success: bool
function InfinityDKPPlayerTrading:SetTradeCooldown(seconds)
	seconds = tonumber(seconds) or 60
	if seconds < 0 then
		return false
	end
	
	self.config.cooldownSeconds = seconds
	InfinityUtils:Info("Trade cooldown set to " .. seconds .. " seconds", "PlayerTrading")
	self:TriggerCallback("cooldown_changed", seconds)
	return true
end

--- Enable/disable player trading
-- @param enabled: bool
-- @return success: bool
function InfinityDKPPlayerTrading:SetEnabled(enabled)
	self.config.enabled = enabled
	InfinityUtils:Info("Player trading " .. (enabled and "enabled" or "disabled"), "PlayerTrading")
	self:TriggerCallback("trading_enabled_changed", enabled)
	return true
end

--- Require both players online
-- @param required: bool
-- @return success: bool
function InfinityDKPPlayerTrading:SetRequireBothOnline(required)
	self.config.requireBothOnline = required
	InfinityUtils:Info("Require both online: " .. (required and "enabled" or "disabled"), "PlayerTrading")
	return true
end

--- Require same guild
-- @param required: bool
-- @return success: bool
function InfinityDKPPlayerTrading:SetRequireGuild(required)
	self.config.requireGuild = required
	InfinityUtils:Info("Require same guild: " .. (required and "enabled" or "disabled"), "PlayerTrading")
	return true
end

-- ============================================================================
-- TRADE OFFERS
-- ============================================================================

--- Create a trade offer (pending acceptance)
-- @param offererName: string (player initiating)
-- @param recipientName: string (player receiving)
-- @param dkpAmount: number
-- @param reason: string (optional)
-- @param expiresIn: number (seconds, default 300)
-- @return offerId: number or nil
function InfinityDKPPlayerTrading:CreateTradeOffer(offererName, recipientName, dkpAmount, reason, expiresIn)
	if not self.config.enabled or not offererName or not recipientName or not dkpAmount then
		return nil
	end
	
	-- Validate amount
	dkpAmount = tonumber(dkpAmount) or 0
	if dkpAmount < self.config.minTransferAmount or dkpAmount > self.config.maxTransferPerTrade then
		InfinityUtils:Warning("Invalid trade amount: " .. dkpAmount, "PlayerTrading")
		return nil
	end
	
	-- Can't trade with yourself
	if offererName == recipientName then
		InfinityUtils:Warning("Cannot trade with yourself", "PlayerTrading")
		return nil
	end
	
	-- Check if both players are in the same guild via live guild roster
	if self.config.requireGuild then
		local playerGuild = GetGuildInfo and GetGuildInfo("player") or nil
		if not playerGuild then
			InfinityUtils:Warning("You must be in a guild to trade DKP", "PlayerTrading")
			return nil
		end
		local function isInGuildRoster(targetName)
			if not targetName then return false end
			local shortTarget = targetName:match("^[^-]+"):lower()
			if UnitName and UnitName("player") and UnitName("player"):match("^[^-]+"):lower() == shortTarget then
				return true
			end
			if GetNumGuildMembers and GetGuildRosterInfo then
				for i = 1, GetNumGuildMembers() do
					local gName = GetGuildRosterInfo(i)
					if gName and gName:match("^[^-]+"):lower() == shortTarget then
						return true
					end
				end
			end
			return false
		end
		if not isInGuildRoster(offererName) or not isInGuildRoster(recipientName) then
			InfinityUtils:Warning("Both players must be members of " .. playerGuild, "PlayerTrading")
			return nil
		end
	end
	
	-- Check daily transfer limit for offerer
	local remaining = self:GetRemainingDailyTransferBudget(offererName)
	if dkpAmount > remaining then
		InfinityUtils:Warning("Daily transfer limit exceeded for " .. offererName, "PlayerTrading")
		return nil
	end
	
	-- Check cooldown
	if not self:CanTrade(offererName) then
		InfinityUtils:Warning("Trade cooldown active for " .. offererName, "PlayerTrading")
		return nil
	end
	
	-- Create offer
	local offerId = self.nextOfferId
	self.nextOfferId = self.nextOfferId + 1
	
	local offer = {
		id = offerId,
		offerer = offererName,
		recipient = recipientName,
		amount = dkpAmount,
		reason = reason or "DKP trade",
		timestamp = GetTime(),
		expiresAt = GetTime() + (expiresIn or 300),
		status = "pending",
	}
	
	self.tradeOffers[offerId] = offer
	
	-- Trigger callback
	self:TriggerCallback("trade_offer_created", offerId, offererName, recipientName, dkpAmount)
	
	InfinityUtils:Info("Trade offer created: " .. offererName .. " → " .. recipientName .. " (" .. dkpAmount .. " DKP)", "PlayerTrading")
	
	return offerId
end

--- Accept a trade offer
-- @param offerId: number
-- @param recipientName: string (must match recipient in offer)
-- @return success: bool
function InfinityDKPPlayerTrading:AcceptTradeOffer(offerId, recipientName)
	if not offerId or not recipientName then
		return false
	end
	
	local offer = self.tradeOffers[offerId]
	if not offer then
		InfinityUtils:Warning("Trade offer not found: " .. offerId, "PlayerTrading")
		return false
	end
	
	-- Verify recipient
	if offer.recipient ~= recipientName then
		InfinityUtils:Warning("Recipient mismatch for trade offer", "PlayerTrading")
		return false
	end
	
	-- Check if expired
	if GetTime() > offer.expiresAt then
		self.tradeOffers[offerId] = nil
		InfinityUtils:Warning("Trade offer expired", "PlayerTrading")
		return false
	end
	
	-- Execute trade
	return self:ExecuteTrade(offerId)
end

--- Reject/cancel a trade offer
-- @param offerId: number
-- @param cancellerName: string (offerer or recipient)
-- @return success: bool
function InfinityDKPPlayerTrading:CancelTradeOffer(offerId, cancellerName)
	if not offerId or not cancellerName then
		return false
	end
	
	local offer = self.tradeOffers[offerId]
	if not offer then
		return false
	end
	
	-- Only offerer or recipient can cancel
	if cancellerName ~= offer.offerer and cancellerName ~= offer.recipient then
		InfinityUtils:Warning("Not authorized to cancel this trade", "PlayerTrading")
		return false
	end
	
	-- Mark as cancelled
	offer.status = "cancelled"
	offer.cancelledBy = cancellerName
	offer.cancelledAt = GetTime()
	
	self:TriggerCallback("trade_offer_cancelled", offerId, cancellerName)
	
	InfinityUtils:Info("Trade offer cancelled: " .. offerId, "PlayerTrading")
	
	return true
end

-- ============================================================================
-- TRADE EXECUTION
-- ============================================================================

--- Execute a trade (transfer DKP)
-- @param offerId: number
-- @return success: bool
function InfinityDKPPlayerTrading:ExecuteTrade(offerId)
	local offer = self.tradeOffers[offerId]
	if not offer or offer.status ~= "pending" then
		return false
	end
	
	local offerer = offer.offerer
	local recipient = offer.recipient
	local amount = offer.amount
	
	-- Verify both have enough points
	if InfinityGuildRoster then
		local offererMember = InfinityGuildRoster.members[offerer]
		local recipientMember = InfinityGuildRoster.members[recipient]
		
		if offererMember and recipientMember then
			if (offererMember.dkpBalance or 0) < amount then
				InfinityUtils:Warning(offerer .. " has insufficient DKP (" .. (offererMember.dkpBalance or 0) .. "/" .. amount .. ")", "PlayerTrading")
				return false
			end
		end
	end
	
	-- Initialize player stats if needed
	if not self.playerStats[offerer] then
		self.playerStats[offerer] = {
			dailyTransferred = 0,
			lastTradeTime = 0,
			totalTraded = 0,
		}
	end
	if not self.playerStats[recipient] then
		self.playerStats[recipient] = {
			dailyTransferred = 0,
			lastTradeTime = 0,
			totalTraded = 0,
		}
	end
	
	-- Record the trade
	local trade = {
		id = offerId,
		offerer = offerer,
		recipient = recipient,
		amount = amount,
		reason = offer.reason,
		timestamp = date("%Y-%m-%d %H:%M:%S"),
		time = GetTime(),
	}
	
	-- Update player stats
	self.playerStats[offerer].dailyTransferred = self.playerStats[offerer].dailyTransferred + amount
	self.playerStats[offerer].lastTradeTime = GetTime()
	self.playerStats[offerer].totalTraded = self.playerStats[offerer].totalTraded + amount
	
	self.playerStats[recipient].lastTradeTime = GetTime()
	
	-- Log the trade
	table.insert(self.tradeHistory, trade)
	
	-- Record in Points module (deduct from offerer, add to recipient)
	if _G.InfinityDKPPoints then
		_G.InfinityDKPPoints:LogTransaction(offerer, "trade_sent", -amount, 
			"Traded " .. amount .. " DKP to " .. recipient .. ": " .. offer.reason)
		_G.InfinityDKPPoints:LogTransaction(recipient, "trade_received", amount, 
			"Received " .. amount .. " DKP from " .. offerer .. ": " .. offer.reason)
	end
	
	-- Mark offer as completed
	offer.status = "completed"
	offer.completedAt = GetTime()
	
	-- Trigger callback
	self:TriggerCallback("trade_completed", offerId, offerer, recipient, amount)
	
	InfinityUtils:Info("Trade completed: " .. offerer .. " → " .. recipient .. " (" .. amount .. " DKP)", "PlayerTrading")
	
	return true
end

-- ============================================================================
-- TRADE QUERIES
-- ============================================================================

--- Get active trade offers for a player
-- @param playerName: string (as offerer or recipient)
-- @return offers: table
function InfinityDKPPlayerTrading:GetActiveOffers(playerName)
	local activeOffers = {}
	
	for offerId, offer in pairs(self.tradeOffers) do
		-- Skip expired offers
		if GetTime() > offer.expiresAt then
			self.tradeOffers[offerId] = nil
		elseif offer.status == "pending" and (offer.offerer == playerName or offer.recipient == playerName) then
			table.insert(activeOffers, offer)
		end
	end
	
	return activeOffers
end

--- Get trade history for a player
-- @param playerName: string (as offerer or recipient)
-- @param limit: number (default 50)
-- @return trades: table
function InfinityDKPPlayerTrading:GetPlayerTradeHistory(playerName, limit)
	limit = limit or 50
	local playerTrades = {}
	
	for i = #self.tradeHistory, math.max(1, #self.tradeHistory - limit + 1), -1 do
		local trade = self.tradeHistory[i]
		if trade.offerer == playerName or trade.recipient == playerName then
			table.insert(playerTrades, trade)
		end
	end
	
	return playerTrades
end

--- Get player trading statistics
-- @param playerName: string
-- @return stats: table
function InfinityDKPPlayerTrading:GetPlayerTradeStats(playerName)
	local stats = self.playerStats[playerName]
	
	if not stats then
		return {
			totalTraded = 0,
			dailyTransferred = 0,
			lastTradeTime = "Never",
			remainingDailyBudget = self.config.dailyTransferLimit,
			tradeCount = 0,
		}
	end
	
	local tradeCount = 0
	for _, trade in ipairs(self.tradeHistory) do
		if trade.offerer == playerName then
			tradeCount = tradeCount + 1
		end
	end
	
	return {
		totalTraded = stats.totalTraded,
		dailyTransferred = stats.dailyTransferred,
		lastTradeTime = stats.lastTradeTime > 0 and 
			date("%Y-%m-%d %H:%M:%S", stats.lastTradeTime) or "Never",
		remainingDailyBudget = self:GetRemainingDailyTransferBudget(playerName),
		tradeCount = tradeCount,
		averagePerTrade = tradeCount > 0 and math.floor(stats.totalTraded / tradeCount) or 0,
	}
end

--- Get guild-wide trading statistics
-- @return stats: table
function InfinityDKPPlayerTrading:GetGuildTradeStats()
	local totalTraded = 0
	local playerCount = 0
	local tradeCount = #self.tradeHistory
	
	for playerName, stats in pairs(self.playerStats) do
		totalTraded = totalTraded + stats.totalTraded
		playerCount = playerCount + 1
	end
	
	return {
		totalTraded = totalTraded,
		playerCount = playerCount,
		tradeCount = tradeCount,
		averagePerPlayer = playerCount > 0 and math.floor(totalTraded / playerCount) or 0,
		averagePerTrade = tradeCount > 0 and math.floor(totalTraded / tradeCount) or 0,
	}
end

--- Export trade history for audit
-- @param limit: number (default 100)
-- @return historyString: string
function InfinityDKPPlayerTrading:ExportTradeHistory(limit)
	limit = limit or 100
	local export = "GUILD DKP TRADE HISTORY\n"
	export = export .. "=======================\n\n"
	
	for i = #self.tradeHistory, math.max(1, #self.tradeHistory - limit + 1), -1 do
		local trade = self.tradeHistory[i]
		export = export .. string.format("%s | %s → %s | %d DKP | %s\n",
			trade.timestamp, trade.offerer, trade.recipient, trade.amount, trade.reason)
	end
	
	return export
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if player can trade (cooldown not active)
-- @param playerName: string
-- @return canTrade: bool
function InfinityDKPPlayerTrading:CanTrade(playerName)
	local lock = self.tradeLocks[playerName]
	if not lock then
		return true
	end
	
	-- Check if cooldown has expired
	if GetTime() - lock.lastTradeTime >= self.config.cooldownSeconds then
		return true
	end
	
	return false
end

--- Get remaining daily transfer budget for a player
-- @param playerName: string
-- @return remainingBudget: number
function InfinityDKPPlayerTrading:GetRemainingDailyTransferBudget(playerName)
	local stats = self.playerStats[playerName]
	
	if not stats then
		return self.config.dailyTransferLimit
	end
	
	-- Check if it's a new day
	local today = date("%Y-%m-%d")
	local lastTradeDate = date("%Y-%m-%d", stats.lastTradeTime)
	
	if lastTradeDate ~= today then
		-- Reset daily counter
		stats.dailyTransferred = 0
		stats.lastTradeTime = GetTime()
		return self.config.dailyTransferLimit
	end
	
	return math.max(0, self.config.dailyTransferLimit - stats.dailyTransferred)
end

--- Get time until next trade is available
-- @param playerName: string
-- @return seconds: number (0 if ready)
function InfinityDKPPlayerTrading:GetTimeUntilNextTrade(playerName)
	local lock = self.tradeLocks[playerName]
	if not lock then
		return 0
	end
	
	local timeSinceLastTrade = GetTime() - lock.lastTradeTime
	local timeRemaining = self.config.cooldownSeconds - timeSinceLastTrade
	
	return math.max(0, timeRemaining)
end

--- Register callback for trading events
-- @param callback: function
function InfinityDKPPlayerTrading:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback event
-- @param event: string
-- @param ...: varargs
function InfinityDKPPlayerTrading:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return InfinityDKPPlayerTrading
