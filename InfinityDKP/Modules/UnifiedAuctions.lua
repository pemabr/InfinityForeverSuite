-- UnifiedAuctionSystem Module  
-- Removes tier system (MS/OS/Offspec/Bank) and uses single pool
-- All guild members bid on all items equally

local InfinityDKPUnifiedAuctions = {}
_G.InfinityDKPUnifiedAuctions = InfinityDKPUnifiedAuctions

-- Configuration
InfinityDKPUnifiedAuctions.config = {
	enabled = true,
	defaultBiddingMode = "open", -- open, closed, vickrey, etc
	minBidIncrement = 1, -- Minimum bid increment
	defaultDuration = 300, -- 5 minutes
	antiSnipeDuration = 10, -- Extend duration if bid within X seconds
}

-- Active auctions (unified pool, no tiers)
InfinityDKPUnifiedAuctions.activeAuctions = {}

-- Auction history
InfinityDKPUnifiedAuctions.auctionHistory = {}

-- Callbacks
InfinityDKPUnifiedAuctions.callbacks = {}

-- Next auction ID
InfinityDKPUnifiedAuctions.nextAuctionId = 1

-- ============================================================================
-- AUCTION MANAGEMENT
-- ============================================================================

--- Create a unified auction (no tiers)
-- @param itemLink: string
-- @param startingBid: number
-- @param duration: number (seconds, default 300)
-- @param minimumBid: number (optional)
-- @return auctionId: number or nil
function InfinityDKPUnifiedAuctions:CreateAuction(itemLink, startingBid, duration, minimumBid)
	if not itemLink then
		return nil
	end
	
	local auctionId = self.nextAuctionId
	self.nextAuctionId = self.nextAuctionId + 1
	
	startingBid = tonumber(startingBid) or 1
	duration = tonumber(duration) or self.config.defaultDuration
	minimumBid = tonumber(minimumBid) or startingBid
	
	-- Parse item name from link
	local itemName = self:GetItemNameFromLink(itemLink)
	
	local auction = {
		id = auctionId,
		itemLink = itemLink,
		itemName = itemName,
		startingBid = startingBid,
		minimumBid = minimumBid,
		currentHighBid = startingBid,
		highestBidder = nil,
		startTime = GetTime(),
		duration = duration,
		endTime = GetTime() + duration,
		status = "active",
		bids = {}, -- Unified bid pool (no tiers)
		winner = nil,
		winningBid = nil,
		createdBy = UnitName("player"),
		guildName = GetGuildInfo("player"),
	}
	
	table.insert(self.activeAuctions, auction)
	
	-- Trigger callback
	self:TriggerCallback("auction_created", auctionId, itemName, startingBid)
	
	InfinityUtils:Info("Unified auction created: " .. itemName .. " (ID: " .. auctionId .. ")", "UnifiedAuctions")
	
	return auctionId
end

--- Place a bid on auction (unified pool)
-- @param auctionId: number
-- @param playerName: string
-- @param bidAmount: number
-- @return success: bool
function InfinityDKPUnifiedAuctions:PlaceBid(auctionId, playerName, bidAmount)
	if not auctionId or not playerName or not bidAmount then
		return false
	end
	
	-- Find auction
	local auction = nil
	for _, a in ipairs(self.activeAuctions) do
		if a.id == auctionId then
			auction = a
			break
		end
	end
	
	if not auction then
		InfinityUtils:Warning("Auction not found: " .. auctionId, "UnifiedAuctions")
		return false
	end
	
	-- Check if auction is still active
	if GetTime() > auction.endTime then
		InfinityUtils:Warning("Auction has ended", "UnifiedAuctions")
		return false
	end
	
	bidAmount = tonumber(bidAmount) or 0
	
	-- Validate bid amount
	if bidAmount <= auction.currentHighBid then
		InfinityUtils:Warning("Bid must be higher than current bid (" .. auction.currentHighBid .. ")", "UnifiedAuctions")
		return false
	end
	
	if bidAmount < (auction.currentHighBid + self.config.minBidIncrement) then
		InfinityUtils:Warning("Bid increment too small (minimum " .. self.config.minBidIncrement .. ")", "UnifiedAuctions")
		return false
	end
	
	-- Record bid in unified pool
	local bid = {
		player = playerName,
		amount = bidAmount,
		timestamp = GetTime(),
	}
	
	table.insert(auction.bids, bid)
	auction.currentHighBid = bidAmount
	auction.highestBidder = playerName
	
	-- Check for anti-snipe extension
	if GetTime() > (auction.endTime - self.config.antiSnipeDuration) then
		-- Extend auction
		auction.endTime = GetTime() + self.config.antiSnipeDuration
		self:TriggerCallback("auction_extended", auctionId, playerName)
		InfinityUtils:Info("Auction extended due to anti-snipe protection", "UnifiedAuctions")
	end
	
	-- Trigger callback
	self:TriggerCallback("bid_placed", auctionId, playerName, bidAmount)
	
	InfinityUtils:Info("Bid placed on auction " .. auctionId .. ": " .. playerName .. " @ " .. bidAmount .. " DKP", "UnifiedAuctions")
	
	return true
end

--- Close an auction and determine winner
-- @param auctionId: number
-- @return winner: string or nil
function InfinityDKPUnifiedAuctions:CloseAuction(auctionId)
	-- Find auction
	local auctionIndex = nil
	local auction = nil
	for i, a in ipairs(self.activeAuctions) do
		if a.id == auctionId then
			auction = a
			auctionIndex = i
			break
		end
	end
	
	if not auction then
		InfinityUtils:Warning("Auction not found: " .. auctionId, "UnifiedAuctions")
		return nil
	end
	
	-- Mark as closed
	auction.status = "closed"
	auction.endTime = GetTime()
	
	-- Determine winner (highest bidder from unified pool)
	if auction.highestBidder then
		auction.winner = auction.highestBidder
		auction.winningBid = auction.currentHighBid
	end
	
	-- Move to history
	table.insert(self.auctionHistory, auction)
	table.remove(self.activeAuctions, auctionIndex)
	
	-- Trigger callback
	self:TriggerCallback("auction_closed", auctionId, auction.winner, auction.winningBid)
	
	if auction.winner then
		InfinityUtils:Info("Auction " .. auctionId .. " closed - Winner: " .. auction.winner .. " @ " .. auction.winningBid .. " DKP", "UnifiedAuctions")
	else
		InfinityUtils:Info("Auction " .. auctionId .. " closed - No bids", "UnifiedAuctions")
	end
	
	return auction.winner
end

-- ============================================================================
-- AUCTION QUERIES
-- ============================================================================

--- Get active auctions
-- @return auctions: table
function InfinityDKPUnifiedAuctions:GetActiveAuctions()
	return self.activeAuctions
end

--- Get auction details
-- @param auctionId: number
-- @return auction: table or nil
function InfinityDKPUnifiedAuctions:GetAuctionDetails(auctionId)
	for _, auction in ipairs(self.activeAuctions) do
		if auction.id == auctionId then
			return auction
		end
	end
	
	-- Check history
	for _, auction in ipairs(self.auctionHistory) do
		if auction.id == auctionId then
			return auction
		end
	end
	
	return nil
end

--- Get auction history
-- @param limit: number (default 50)
-- @return auctions: table
function InfinityDKPUnifiedAuctions:GetAuctionHistory(limit)
	limit = limit or 50
	local result = {}
	
	for i = #self.auctionHistory, math.max(1, #self.auctionHistory - limit + 1), -1 do
		table.insert(result, self.auctionHistory[i])
	end
	
	return result
end

--- Get auctions won by player
-- @param playerName: string
-- @param limit: number (default 50)
-- @return auctions: table
function InfinityDKPUnifiedAuctions:GetPlayerWins(playerName, limit)
	limit = limit or 50
	local wins = {}
	
	for i = #self.auctionHistory, math.max(1, #self.auctionHistory - limit + 1), -1 do
		local auction = self.auctionHistory[i]
		if auction.winner == playerName then
			table.insert(wins, auction)
		end
	end
	
	return wins
end

--- Get player auction statistics
-- @param playerName: string
-- @return stats: table
function InfinityDKPUnifiedAuctions:GetPlayerAuctionStats(playerName)
	local wins = 0
	local totalSpent = 0
	local lastWin = "Never"
	
	for _, auction in ipairs(self.auctionHistory) do
		if auction.winner == playerName then
			wins = wins + 1
			totalSpent = totalSpent + auction.winningBid
			lastWin = auction.startTime and 
				date("%Y-%m-%d %H:%M:%S", auction.startTime) or "Never"
		end
	end
	
	return {
		wins = wins,
		totalSpent = totalSpent,
		lastWin = lastWin,
		averagePerItem = wins > 0 and math.floor(totalSpent / wins) or 0,
	}
end

--- Get guild auction statistics
-- @return stats: table
function InfinityDKPUnifiedAuctions:GetGuildAuctionStats()
	local totalAuctions = #self.auctionHistory
	local totalDKPSpent = 0
	local playersParticipated = {}
	
	for _, auction in ipairs(self.auctionHistory) do
		if auction.winner then
			totalDKPSpent = totalDKPSpent + auction.winningBid
			playersParticipated[auction.winner] = true
		end
	end
	
	return {
		totalAuctions = totalAuctions,
		totalDKPSpent = totalDKPSpent,
		activeAuctions = #self.activeAuctions,
		uniqueWinners = self:CountTable(playersParticipated),
		averagePerAuction = totalAuctions > 0 and math.floor(totalDKPSpent / totalAuctions) or 0,
	}
end

--- Export auction history
-- @param limit: number (default 100)
-- @return historyString: string
function InfinityDKPUnifiedAuctions:ExportAuctionHistory(limit)
	limit = limit or 100
	local export = "GUILD AUCTION HISTORY (UNIFIED SYSTEM)\n"
	export = export .. "======================================\n\n"
	
	for i = #self.auctionHistory, math.max(1, #self.auctionHistory - limit + 1), -1 do
		local a = self.auctionHistory[i]
		if a.winner then
			export = export .. string.format("%s | %s | %s → %d DKP\n",
				a.startTime and date("%Y-%m-%d %H:%M:%S", a.startTime) or "?", 
				a.itemName, a.winner, a.winningBid)
		else
			export = export .. string.format("%s | %s | No bids\n",
				a.startTime and date("%Y-%m-%d %H:%M:%S", a.startTime) or "?",
				a.itemName)
		end
	end
	
	return export
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Parse item name from item link
-- @param itemLink: string
-- @return itemName: string
function InfinityDKPUnifiedAuctions:GetItemNameFromLink(itemLink)
	-- Extract name from |h[name]|h pattern
	local name = itemLink:match("|h%[(.-)%]|h")
	return name or "Unknown Item"
end

--- Count entries in table
-- @param tbl: table
-- @return count: number
function InfinityDKPUnifiedAuctions:CountTable(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--- Register callback
-- @param callback: function
function InfinityDKPUnifiedAuctions:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback event
-- @param event: string
-- @param ...: varargs
function InfinityDKPUnifiedAuctions:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return InfinityDKPUnifiedAuctions
