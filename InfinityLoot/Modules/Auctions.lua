-- InfinityLoot Auction System
-- Supports 7 bidding modes: Open, Closed, Vickrey, Anonymous, Tiered, Anti-Snipe
-- Also handles DKP/EPGP point system integration

InfinityLootAuctions = {
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

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function PositiveInteger(value, maximum)
	return type(value) == "number" and value == value and value > 0
		and value <= maximum and value == math.floor(value)
end

-- Initialize auction system
function InfinityLootAuctions:Initialize()
	InfinityUtils:Info("Auctions system initializing...", "InfinityLoot")
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	InfinityUtils:Info("Auctions system initialized", "InfinityLoot")
end

-- ============================================================================
-- AUCTION CREATION & MANAGEMENT
-- ============================================================================

-- Create new auction
-- biddingMode: "open", "closed", "vickrey", "anonymous", "tiered", "antisnipe"
function InfinityLootAuctions:CreateAuction(itemLink, biddingMode, duration, options)
	if _G.issecretvalue and (issecretvalue(itemLink) or issecretvalue(biddingMode)
		or issecretvalue(duration) or issecretvalue(options)) then
		InfinityUtils:Warning("Protected auction input.", "Auctions")
		return nil
	end
	itemLink, biddingMode, duration = Public(itemLink), Public(biddingMode), Public(duration)
	biddingMode = biddingMode or self.settings.defaultBiddingMode
	duration = duration or 60
	options = options or {}
	if type(itemLink) ~= "string" or not itemLink:match("|Hitem:%d+")
		or #itemLink > 1024 or not PositiveInteger(duration, 86400) or type(options) ~= "table" then
		InfinityUtils:Warning("Invalid auction item or duration.", "Auctions")
		return nil
	end
	if _G.issecretvalue and (issecretvalue(options.minimumBid) or issecretvalue(options.bidIncrement)
		or issecretvalue(options.antiSnipeDuration) or issecretvalue(options.tierLevels)) then
		InfinityUtils:Warning("Protected auction options.", "Auctions")
		return nil
	end
	local minimumBid = options.minimumBid == nil and 1 or Public(options.minimumBid)
	local bidIncrement = options.bidIncrement == nil and 1 or Public(options.bidIncrement)
	local antiSnipeDuration = options.antiSnipeDuration == nil and self.settings.defaultAntisnipenDuration or Public(options.antiSnipeDuration)
	if not PositiveInteger(minimumBid, 1000000000) or not PositiveInteger(bidIncrement, 1000000000)
		or not PositiveInteger(antiSnipeDuration, 86400) then
		InfinityUtils:Warning("Invalid auction bid or increment.", "Auctions")
		return nil
	end
	local tierLevels = options.tierLevels or { "MS", "OS", "Offspec", "Bank" }
	if type(tierLevels) ~= "table" or #tierLevels == 0 then
		InfinityUtils:Warning("Invalid auction tiers.", "Auctions")
		return nil
	end
	local seen = {}
	for _, tier in ipairs(tierLevels) do
		if (_G.issecretvalue and issecretvalue(tier)) or type(tier) ~= "string" or tier == ""
			or seen[tier] then
			InfinityUtils:Warning("Invalid auction tiers.", "Auctions")
			return nil
		end
		seen[tier] = true
	end
	-- Validate bidding mode
	if not self:IsValidBiddingMode(biddingMode) then
		InfinityUtils:Warning("Invalid bidding mode: " .. tostring(biddingMode), "Auctions")
		return nil
	end
	
	if #self.activeAuctions >= self.settings.maxConcurrentAuctions then
		InfinityUtils:Warning("Maximum concurrent auctions reached (" .. self.settings.maxConcurrentAuctions .. ")", "Auctions")
		return nil
	end
	local auctionId = self:GenerateAuctionId()
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
		minimumBid = minimumBid,
		bidIncrement = bidIncrement,
		antiSnipeDuration = antiSnipeDuration,
		startingBid = options.startingBid or 0,
		
		-- Tiered auction options
		tierLevels = tierLevels,
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
	
	table.insert(self.activeAuctions, auction)
	if _G.C_Timer and C_Timer.After then
		local function Check()
			if self:GetAuction(auctionId) ~= auction then return end
			local remaining = auction.endTime - GetTime()
			if remaining > 0 then C_Timer.After(remaining, Check) else self:CloseAuction(auctionId) end
		end
		C_Timer.After(duration, Check)
	else
		InfinityUtils:Warning("Auction timer unavailable; close the auction manually.", "Auctions")
	end
	
	-- Publish event
	InfinityMessaging:Publish("auction_created", {
		auctionId = auctionId,
		itemName = auction.itemName,
		biddingMode = biddingMode,
		duration = duration,
	})
	
	InfinityUtils:Info("Auction created: " .. auction.itemName .. " (" .. biddingMode .. ")", "Auctions")
	return auctionId
end

-- Place a bid on an auction
function InfinityLootAuctions:PlaceBid(auctionId, playerName, bidAmount, tierLevel)
	auctionId, playerName, bidAmount, tierLevel = Public(auctionId), Public(playerName), Public(bidAmount), Public(tierLevel)
	if type(auctionId) ~= "string" or type(playerName) ~= "string" or not playerName:match("%S")
		or not PositiveInteger(bidAmount, 1000000000) then
		InfinityUtils:Warning("Invalid auction bid.", "Auctions")
		return false
	end
	local auction = self:GetAuction(auctionId)
	if not auction then
		InfinityUtils:Warning("Auction not found: " .. tostring(auctionId), "Auctions")
		return false
	end
	
	-- Validate auction is still active
	if auction.status ~= "active" or GetTime() >= auction.endTime then
		InfinityUtils:Warning("Auction is not active", "Auctions")
		return false
	end
	
	-- Validate bid amount
	if bidAmount < auction.minimumBid then
		InfinityUtils:Warning("Bid below minimum (" .. auction.minimumBid .. ")", "Auctions")
		return false
	end
	
	if (auction.biddingMode == "open" or auction.biddingMode == "antisnipe") and auction.bids[1]
		and bidAmount < auction.bids[1].amount + auction.bidIncrement then
		InfinityUtils:Warning("Bid must exceed the current high bid by the increment.", "Auctions")
		return false
	end
	
	-- Handle bidding mode-specific logic
	if auction.biddingMode == "tiered" then
		return self:PlaceTieredBid(auction, playerName, bidAmount, tierLevel)
	elseif auction.biddingMode == "anonymous" then
		return self:PlaceAnonymousBid(auction, playerName, bidAmount)
	elseif auction.biddingMode == "closed" or auction.biddingMode == "vickrey" then
		return self:PlaceClosedBid(auction, playerName, bidAmount)
	else
		-- Open, Vickrey, Anti-Snipe all use standard bidding
		local result = self:PlaceStandardBid(auction, playerName, bidAmount)
		if result and auction.biddingMode == "antisnipe" then self:ExtendAuctionIfNeeded(auctionId) end
		return result
	end
end

-- Standard bid placement (open, vickrey, antisnipe modes)
function InfinityLootAuctions:PlaceStandardBid(auction, playerName, bidAmount)
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
		InfinityMessaging:Publish("auction_bid_update", {
			auctionId = auction.id,
			topBidder = auction.bids[1].player,
			topBid = auction.bids[1].amount,
		})
	else
		-- Send all bids (not in combat mode)
		if not UnitAffectingCombat("player") then
			InfinityMessaging:Publish("auction_bids_full", {
				auctionId = auction.id,
				bids = InfinityUtils:DeepCopy(auction.bids),
			})
		end
	end
	
	InfinityUtils:Debug(playerName .. " bid " .. bidAmount .. " on " .. auction.itemName, "Auctions")
	return true
end

-- Closed bid placement (bids hidden from others)
function InfinityLootAuctions:PlaceClosedBid(auction, playerName, bidAmount)
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
	
	InfinityUtils:Debug("Closed bid received: " .. playerName, "Auctions")
	return true
end

-- Anonymous bid placement
function InfinityLootAuctions:PlaceAnonymousBid(auction, playerName, bidAmount)
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
	InfinityMessaging:Publish("auction_bid_update", {
		auctionId = auction.id,
		topBidder = auction.bids[1].anonymousId,
		topBid = auction.bids[1].amount,
	})
	
	InfinityUtils:Debug("Anonymous bid received: " .. anonymousId, "Auctions")
	return true
end

-- Tiered bid placement (MS, OS, Offspec, Bank)
function InfinityLootAuctions:PlaceTieredBid(auction, playerName, bidAmount, tierLevel)
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
		InfinityUtils:Warning("Invalid tier level: " .. tierLevel, "Auctions")
		return false
	end
	
	-- A player can hold only one tier bid per auction.
	for _, tier in ipairs(auction.tierLevels) do
		local bids = auction.tierBids[tier]
		for index = #bids, 1, -1 do
			if bids[index].player == playerName then table.remove(bids, index) end
		end
	end
	local tierBidTable = auction.tierBids[tierLevel]
	
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
	InfinityMessaging:Publish("auction_tier_bid", {
		auctionId = auction.id,
		tier = tierLevel,
		topBidder = tierBidTable[1].player,
		topBid = tierBidTable[1].amount,
	})
	
	InfinityUtils:Debug(playerName .. " tiered bid " .. bidAmount .. " as " .. tierLevel, "Auctions")
	return true
end

-- Close auction and determine winner
function InfinityLootAuctions:CloseAuction(auctionId)
	local auction = self:GetAuction(auctionId)
	if not auction then
		InfinityUtils:Warning("Auction not found: " .. tostring(auctionId), "Auctions")
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
		id = auctionId,
		itemLink = auction.itemLink,
		itemName = auction.itemName,
		winner = winner,
		winningBid = winningBid,
		winnerPrice = winningBid,
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
	InfinityMessaging:Publish("auction_closed", {
		auctionId = auctionId,
		itemName = auction.itemName,
		winner = winner,
		winningBid = winningBid,
		biddingMode = auction.biddingMode,
	})
	
	if winner then
		InfinityUtils:Info(winner .. " won: " .. auction.itemName .. " for " .. winningBid, "Auctions")
		print(string.format("Local auction %s: %s won %s for %d; award item and points manually.",
			auctionId, winner, auction.itemName, winningBid))
	else
		InfinityUtils:Info("Auction closed with no bids: " .. auction.itemName, "Auctions")
		print("Local auction " .. auctionId .. " closed without bids.")
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
function InfinityLootAuctions:ExtendAuctionIfNeeded(auctionId)
	local auction = self:GetAuction(auctionId)
	if not auction or auction.biddingMode ~= "antisnipe" then
		return false
	end
	
	local timeRemaining = auction.endTime - GetTime()
	
	-- If a bid was placed in last anti-snipe duration, extend
	if #auction.bids > 0 then
		if timeRemaining < auction.antiSnipeDuration then
			-- Extend auction
			auction.endTime = GetTime() + auction.antiSnipeDuration
			
			InfinityMessaging:Publish("auction_extended", {
				auctionId = auctionId,
				newEndTime = auction.endTime,
				reason = "anti-snipe",
			})
			
			InfinityUtils:Debug("Auction extended due to anti-snipe: " .. auction.itemName, "Auctions")
			return true
		end
	end
	
	return false
end

-- ============================================================================
-- GETTER FUNCTIONS
-- ============================================================================

function InfinityLootAuctions:GetAuction(auctionId)
	for _, auction in ipairs(self.activeAuctions) do
		if auction.id == auctionId then
			return auction
		end
	end
	return nil
end

function InfinityLootAuctions:GetActiveAuctions()
	local active = {}
	for _, auction in ipairs(self.activeAuctions) do
		if auction.status == "active" and GetTime() < auction.endTime then
			table.insert(active, InfinityUtils:DeepCopy(auction))
		end
	end
	return active
end

function InfinityLootAuctions:GetAuctionHistory(limit)
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

function InfinityLootAuctions:IsValidBiddingMode(mode)
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

function InfinityLootAuctions:GenerateAuctionId()
	if not self.db.nextAuctionId then
		self.db.nextAuctionId = 1
	end
	local id = "auction_" .. self.db.nextAuctionId
	self.db.nextAuctionId = self.db.nextAuctionId + 1
	return id
end

function InfinityLootAuctions:ExtractItemName(itemLink)
	-- Parse item link to get item name
	-- Format: |cff[color]|H[type]:[id]:[extra]|h[name]|h|r
	if not itemLink then return "Unknown Item" end
	
	local name = string.match(itemLink, "%|h%[(.-)%]%|h")
	return name or "Unknown Item"
end

function InfinityLootAuctions:GetUniquePlayerCount()
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

function InfinityLootAuctions:GetStats()
	return {
		activeAuctions = #self.activeAuctions,
		totalBids = self:CountTotalBids(),
		historySize = #self.auctionHistory,
		totalAuctionsClosed = #self.auctionHistory,
	}
end

function InfinityLootAuctions:CountTotalBids()
	local total = 0
	for _, auction in ipairs(self.activeAuctions) do
		total = total + #auction.bids
	end
	return total
end

return InfinityLootAuctions
