-- PluribusLoot Auction System
-- Supports 7 bidding modes: Open, Closed, Vickrey, Anonymous, Tiered, Anti-Snipe
-- Also handles DKP/EPGP point system integration

PluribusLootAuctions = {
	db = {},
	activeAuctions = {},
	auctionHistory = {},
	settings = {
		defaultBiddingMode = "open",
		defaultAntisnipenDuration = 10, -- seconds
		maxConcurrentAuctions = 5,
		enableCompressionAbovePlayerCount = 10, -- Don't send all bids if >10 players
	},
	version = "1.0.0",
}

-- Initialize auction system
function PluribusLootAuctions:Initialize()
	PluribusUtils:Info("Auctions system initializing...", "PluribusLoot")
	self.db = PluribusStorageManager:GetFeatureSettings(PLURIBUS_FEATURES.LOOT) or {}
	PluribusUtils:Info("Auctions system initialized", "PluribusLoot")
end

-- ============================================================================
-- AUCTION CREATION & MANAGEMENT
-- ============================================================================

-- Create new auction
-- biddingMode: "open", "closed", "vickrey", "anonymous", "tiered", "antisnipe"
function PluribusLootAuctions:CreateAuction(itemLink, biddingMode, duration, options)
	local auctionId = self:GenerateAuctionId()
	
	biddingMode = biddingMode or self.settings.defaultBiddingMode
	duration = duration or 60 -- Default 1 minute
	options = options or {}
	
	-- Validate bidding mode
	if not self:IsValidBiddingMode(biddingMode) then
		PluribusUtils:Warning("Invalid bidding mode: " .. tostring(biddingMode), "Auctions")
		return nil
	end
	
	local auction = {
		id = auctionId,
		itemLink = itemLink,
		itemName = self:ExtractItemName(itemLink),
		biddingMode = biddingMode,
		startTime = GetTime(),
		duration = duration,
		endTime = GetTime() + duration,
		status = "active",
		bids = {}, -- Table of bids: {player=X, amount=Y, timestamp=Z}
		winner = nil,
		winningBid = nil,
		
		-- Options per bidding mode
		minimumBid = options.minimumBid or 0,
		bidIncrement = options.bidIncrement or 1,
		antiSnipeDuration = options.antiSnipeDuration or self.settings.defaultAntisnipenDuration,
		startingBid = options.startingBid or 0,
		
		-- Tiered auction options
		tierLevels = options.tierLevels or {"MS", "OS", "Offspec", "Bank"}, -- Main Spec, Off Spec, Offspec, Bank
		tierBids = {}, -- {tier="MS", bids={...}}
		
		-- Anonymous mode tracking
		bidderIds = {}, -- Map playerName -> anonymousId for anonymous auctions
		nextBidderId = 1,
		
		-- Metadata
		createdBy = UnitName("player"),
		guildName = GetGuildInfo("player"),
	}
	
	-- Initialize tier structure for tiered auctions
	if biddingMode == "tiered" then
		for _, tier in ipairs(auction.tierLevels) do
			auction.tierBids[tier] = {}
		end
	end
	
	-- Validate concurrent auctions
	if #self.activeAuctions >= self.settings.maxConcurrentAuctions then
		PluribusUtils:Warning("Maximum concurrent auctions reached (" .. self.settings.maxConcurrentAuctions .. ")", "Auctions")
		return nil
	end
	
	table.insert(self.activeAuctions, auction)
	
	-- Publish event
	PluribusMessaging:Publish("auction_created", {
		auctionId = auctionId,
		itemName = auction.itemName,
		biddingMode = biddingMode,
		duration = duration,
	})
	
	PluribusUtils:Info("Auction created: " .. auction.itemName .. " (" .. biddingMode .. ")", "Auctions")
	return auctionId
end

-- Place a bid on an auction
function PluribusLootAuctions:PlaceBid(auctionId, playerName, bidAmount, tierLevel)
	local auction = self:GetAuction(auctionId)
	if not auction then
		PluribusUtils:Warning("Auction not found: " .. tostring(auctionId), "Auctions")
		return false
	end
	
	-- Validate auction is still active
	if auction.status ~= "active" then
		PluribusUtils:Warning("Auction is not active", "Auctions")
		return false
	end
	
	-- Validate bid amount
	if bidAmount < auction.minimumBid then
		PluribusUtils:Warning("Bid below minimum (" .. auction.minimumBid .. ")", "Auctions")
		return false
	end
	
	-- Check for anti-snipe extension
	if auction.biddingMode == "antisnipe" then
		self:ExtendAuctionIfNeeded(auctionId)
	end
	
	-- Handle bidding mode-specific logic
	if auction.biddingMode == "tiered" then
		return self:PlaceTieredBid(auction, playerName, bidAmount, tierLevel)
	elseif auction.biddingMode == "anonymous" then
		return self:PlaceAnonymousBid(auction, playerName, bidAmount)
	elseif auction.biddingMode == "closed" then
		return self:PlaceClosedBid(auction, playerName, bidAmount)
	else
		-- Open, Vickrey, Anti-Snipe all use standard bidding
		return self:PlaceStandardBid(auction, playerName, bidAmount)
	end
end

-- Standard bid placement (open, vickrey, antisnipe modes)
function PluribusLootAuctions:PlaceStandardBid(auction, playerName, bidAmount)
	-- Check if player already has a bid
	local existingBidIndex = nil
	for idx, bid in ipairs(auction.bids) do
		if bid.player == playerName then
			existingBidIndex = idx
			break
		end
	end
	
	-- Remove old bid if outbid
	if existingBidIndex then
		table.remove(auction.bids, existingBidIndex)
	end
	
	-- Add new bid
	local bid = {
		player = playerName,
		amount = bidAmount,
		timestamp = GetTime(),
	}
	
	table.insert(auction.bids, bid)
	
	-- Sort bids (highest first)
	table.sort(auction.bids, function(a, b)
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return a.timestamp < b.timestamp -- Earlier bid wins tiebreaker
	end)
	
	-- Publish bid update (compress if many players)
	local playerCount = self:GetUniquePlayerCount()
	if playerCount > self.settings.enableCompressionAbovePlayerCount then
		-- Send only highest bid
		PluribusMessaging:Publish("auction_bid_update", {
			auctionId = auction.id,
			topBidder = auction.bids[1].player,
			topBid = auction.bids[1].amount,
		})
	else
		-- Send all bids (not in combat mode)
		if not UnitAffectingCombat("player") then
			PluribusMessaging:Publish("auction_bids_full", {
				auctionId = auction.id,
				bids = PluribusUtils:DeepCopy(auction.bids),
			})
		end
	end
	
	PluribusUtils:Debug(playerName .. " bid " .. bidAmount .. " on " .. auction.itemName, "Auctions")
	return true
end

-- Closed bid placement (bids hidden from others)
function PluribusLootAuctions:PlaceClosedBid(auction, playerName, bidAmount)
	-- Same as standard bid, but don't broadcast to network
	local existingBidIndex = nil
	for idx, bid in ipairs(auction.bids) do
		if bid.player == playerName then
			existingBidIndex = idx
			break
		end
	end
	
	if existingBidIndex then
		table.remove(auction.bids, existingBidIndex)
	end
	
	local bid = {
		player = playerName,
		amount = bidAmount,
		timestamp = GetTime(),
	}
	
	table.insert(auction.bids, bid)
	
	-- Sort but DON'T publish to network (closed auction)
	table.sort(auction.bids, function(a, b)
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return a.timestamp < b.timestamp
	end)
	
	PluribusUtils:Debug("Closed bid received: " .. playerName, "Auctions")
	return true
end

-- Anonymous bid placement
function PluribusLootAuctions:PlaceAnonymousBid(auction, playerName, bidAmount)
	-- Assign anonymous ID if not already done
	if not auction.bidderIds[playerName] then
		auction.bidderIds[playerName] = "Bidder " .. auction.nextBidderId
		auction.nextBidderId = auction.nextBidderId + 1
	end
	
	local anonymousId = auction.bidderIds[playerName]
	
	-- Remove old bid if outbid
	local existingBidIndex = nil
	for idx, bid in ipairs(auction.bids) do
		if bid.anonymousId == anonymousId then
			existingBidIndex = idx
			break
		end
	end
	
	if existingBidIndex then
		table.remove(auction.bids, existingBidIndex)
	end
	
	-- Add anonymous bid
	local bid = {
		player = playerName, -- Store actual name internally for winner determination
		anonymousId = anonymousId, -- Display name in auction
		amount = bidAmount,
		timestamp = GetTime(),
	}
	
	table.insert(auction.bids, bid)
	
	table.sort(auction.bids, function(a, b)
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return a.timestamp < b.timestamp
	end)
	
	-- Publish only anonymous ID (not player name)
	PluribusMessaging:Publish("auction_bid_update", {
		auctionId = auction.id,
		topBidder = auction.bids[1].anonymousId,
		topBid = auction.bids[1].amount,
	})
	
	PluribusUtils:Debug("Anonymous bid received: " .. anonymousId, "Auctions")
	return true
end

-- Tiered bid placement (MS, OS, Offspec, Bank)
function PluribusLootAuctions:PlaceTieredBid(auction, playerName, bidAmount, tierLevel)
	tierLevel = tierLevel or "OS" -- Default to Off-Spec
	
	-- Validate tier level
	local validTier = false
	for _, tier in ipairs(auction.tierLevels) do
		if tier == tierLevel then
			validTier = true
			break
		end
	end
	
	if not validTier then
		PluribusUtils:Warning("Invalid tier level: " .. tierLevel, "Auctions")
		return false
	end
	
	-- Remove old bid from same player in this tier
	local tierBidTable = auction.tierBids[tierLevel]
	for idx, bid in ipairs(tierBidTable) do
		if bid.player == playerName then
			table.remove(tierBidTable, idx)
			break
		end
	end
	
	-- Add new bid to tier
	local bid = {
		player = playerName,
		amount = bidAmount,
		timestamp = GetTime(),
		tier = tierLevel,
	}
	
	table.insert(tierBidTable, bid)
	
	-- Sort tier bids
	table.sort(tierBidTable, function(a, b)
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return a.timestamp < b.timestamp
	end)
	
	-- Publish tier update
	PluribusMessaging:Publish("auction_tier_bid", {
		auctionId = auction.id,
		tier = tierLevel,
		topBidder = tierBidTable[1].player,
		topBid = tierBidTable[1].amount,
	})
	
	PluribusUtils:Debug(playerName .. " tiered bid " .. bidAmount .. " as " .. tierLevel, "Auctions")
	return true
end

-- Close auction and determine winner
function PluribusLootAuctions:CloseAuction(auctionId)
	local auction = self:GetAuction(auctionId)
	if not auction then
		PluribusUtils:Warning("Auction not found: " .. tostring(auctionId), "Auctions")
		return nil
	end
	
	auction.status = "closed"
	auction.endTime = GetTime() -- Override end time to now
	
	-- Determine winner based on bidding mode
	local winner = nil
	local winningBid = nil
	
	if auction.biddingMode == "vickrey" then
		-- Second-highest bid wins at second-highest price
		if #auction.bids >= 2 then
			winner = auction.bids[1].player
			winningBid = auction.bids[2].amount -- Pay second price
		elseif #auction.bids == 1 then
			winner = auction.bids[1].player
			winningBid = auction.minimumBid -- Pay minimum
		end
	elseif auction.biddingMode == "tiered" then
		-- Highest tier gets highest bidder
		for _, tier in ipairs(auction.tierLevels) do
			if #auction.tierBids[tier] > 0 then
				local topBid = auction.tierBids[tier][1]
				winner = topBid.player
				winningBid = topBid.amount
				break
			end
		end
	else
		-- Standard, Open, Closed, Anonymous, Anti-Snipe: highest bid wins
		if #auction.bids > 0 then
			winner = auction.bids[1].player
			winningBid = auction.bids[1].amount
		end
	end
	
	auction.winner = winner
	auction.winningBid = winningBid
	
	-- Record in history
	table.insert(self.auctionHistory, {
		auctionId = auctionId,
		itemName = auction.itemName,
		winner = winner,
		winningBid = winningBid,
		closedTime = GetTime(),
		biddingMode = auction.biddingMode,
	})
	
	-- Remove from active auctions
	for idx, active in ipairs(self.activeAuctions) do
		if active.id == auctionId then
			table.remove(self.activeAuctions, idx)
			break
		end
	end
	
	-- Publish winner announcement
	PluribusMessaging:Publish("auction_closed", {
		auctionId = auctionId,
		itemName = auction.itemName,
		winner = winner,
		winningBid = winningBid,
		biddingMode = auction.biddingMode,
	})
	
	if winner then
		PluribusUtils:Info(winner .. " won: " .. auction.itemName .. " for " .. winningBid, "Auctions")
	else
		PluribusUtils:Info("Auction closed with no bids: " .. auction.itemName, "Auctions")
	end
	
	return {
		winner = winner,
		winningBid = winningBid,
		itemName = auction.itemName,
	}
end

-- ============================================================================
-- ANTI-SNIPE PROTECTION
-- ============================================================================

-- Check if auction needs anti-snipe extension
function PluribusLootAuctions:ExtendAuctionIfNeeded(auctionId)
	local auction = self:GetAuction(auctionId)
	if not auction or auction.biddingMode ~= "antisnipe" then
		return false
	end
	
	local timeRemaining = auction.endTime - GetTime()
	
	-- If a bid was placed in last anti-snipe duration, extend
	if #auction.bids > 0 then
		local lastBidTime = auction.bids[1].timestamp
		local timeSinceLastBid = GetTime() - lastBidTime
		
		if timeSinceLastBid < auction.antiSnipeDuration then
			-- Extend auction
			auction.endTime = GetTime() + auction.antiSnipeDuration
			
			PluribusMessaging:Publish("auction_extended", {
				auctionId = auctionId,
				newEndTime = auction.endTime,
				reason = "anti-snipe",
			})
			
			PluribusUtils:Debug("Auction extended due to anti-snipe: " .. auction.itemName, "Auctions")
			return true
		end
	end
	
	return false
end

-- ============================================================================
-- GETTER FUNCTIONS
-- ============================================================================

function PluribusLootAuctions:GetAuction(auctionId)
	for _, auction in ipairs(self.activeAuctions) do
		if auction.id == auctionId then
			return auction
		end
	end
	return nil
end

function PluribusLootAuctions:GetActiveAuctions()
	local active = {}
	for _, auction in ipairs(self.activeAuctions) do
		if auction.status == "active" and GetTime() < auction.endTime then
			table.insert(active, PluribusUtils:DeepCopy(auction))
		end
	end
	return active
end

function PluribusLootAuctions:GetAuctionHistory(limit)
	limit = limit or 50
	local result = {}
	for i = #self.auctionHistory, math.max(1, #self.auctionHistory - limit + 1), -1 do
		table.insert(result, self.auctionHistory[i])
	end
	return result
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function PluribusLootAuctions:IsValidBiddingMode(mode)
	local validModes = {
		"open",
		"closed",
		"vickrey",
		"anonymous",
		"tiered",
		"antisnipe",
	}
	for _, validMode in ipairs(validModes) do
		if mode == validMode then
			return true
		end
	end
	return false
end

function PluribusLootAuctions:GenerateAuctionId()
	if not self.db.nextAuctionId then
		self.db.nextAuctionId = 1
	end
	local id = "auction_" .. self.db.nextAuctionId
	self.db.nextAuctionId = self.db.nextAuctionId + 1
	return id
end

function PluribusLootAuctions:ExtractItemName(itemLink)
	-- Parse item link to get item name
	-- Format: |cff[color]|H[type]:[id]:[extra]|h[name]|h|r
	if not itemLink then return "Unknown Item" end
	
	local name = string.match(itemLink, "%|h%[(.-)%]%|h")
	return name or "Unknown Item"
end

function PluribusLootAuctions:GetUniquePlayerCount()
	-- Count unique players in active auctions
	local players = {}
	for _, auction in ipairs(self.activeAuctions) do
		for _, bid in ipairs(auction.bids) do
			players[bid.player] = true
		end
	end
	
	local count = 0
	for _ in pairs(players) do
		count = count + 1
	end
	return count
end

-- ============================================================================
-- PERFORMANCE MONITORING
-- ============================================================================

function PluribusLootAuctions:GetStats()
	return {
		activeAuctions = #self.activeAuctions,
		totalBids = self:CountTotalBids(),
		historySize = #self.auctionHistory,
		totalAuctionsClosed = #self.auctionHistory,
	}
end

function PluribusLootAuctions:CountTotalBids()
	local total = 0
	for _, auction in ipairs(self.activeAuctions) do
		total = total + #auction.bids
	end
	return total
end

return PluribusLootAuctions
