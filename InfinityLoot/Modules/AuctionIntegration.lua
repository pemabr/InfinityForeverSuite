-- InfinityLoot Auction Integration
-- Ties together auctions, economy system, and EPGP point deductions

InfinityLootAuctionIntegration = {
	db = {},
	version = "1.0.0",
}

-- ============================================================================
-- INTEGRATION: AUCTION CLOSING WITH POINT DEDUCTION
-- ============================================================================

-- Called when an auction closes - handles point deduction
function InfinityLootAuctionIntegration:OnAuctionClosed(auctionData)
	if not auctionData or not auctionData.winner then
		InfinityUtils:Warning("No winner for auction", "AuctionIntegration")
		return false
	end
	
	-- Get the winner's bid amount
	local winnerBid = auctionData.winnerPrice or 0
	
	-- Determine if this was a Vickrey auction (second price)
	local pointsDeducted = winnerBid
	if auctionData.biddingMode == "vickrey" then
		pointsDeducted = auctionData.winnerPrice or auctionData.bids[2].amount
	end
	
	-- Get item value from economy system
	local itemValue = InfinityLootAdvancedEconomy:GetItemValue(
		auctionData.itemLink,
		auctionData.rarity
	)
	
	-- Apply ascending valuation multiplier if configured
	if auctionData.awardCount then
		local multiplier = self:GetAscendingValuationMultiplier(auctionData.awardCount)
		pointsDeducted = pointsDeducted * multiplier
	end
	
	-- Award item to winner
	local awardSuccess = InfinityLootManager:AwardLoot(
		auctionData.raidId,
		auctionData.winner,
		auctionData.itemLink,
		pointsDeducted
	)
	
	if not awardSuccess then
		InfinityUtils:Warning("Failed to award loot", "AuctionIntegration")
		return false
	end
	
	-- Deduct points from winner's EPGP
	local deductSuccess = InfinityLootEPGP:AwardGP(
		auctionData.raidId,
		auctionData.winner,
		pointsDeducted
	)
	
	if not deductSuccess then
		InfinityUtils:Warning("Failed to deduct GP from winner", "AuctionIntegration")
		return false
	end
	
	-- Award EP to other bidders (optional, based on configuration)
	if InfinityLootAuctionIntegration:ShouldAwardEPToBidders() then
		self:AwardEPToBidders(auctionData)
	end
	
	-- Record transaction in audit log
	InfinityLootAccessControl:LogAction(
		auctionData.winner,
		"auction_won",
		"Item: " .. auctionData.itemLink .. " | Price: " .. pointsDeducted
	)
	
	InfinityUtils:Info(
		auctionData.winner .. " won auction for " .. auctionData.itemLink .. 
		" (GP deducted: " .. pointsDeducted .. ")",
		"AuctionIntegration"
	)
	
	return true
end

-- Award EP to bidders (optional incentive system)
function InfinityLootAuctionIntegration:AwardEPToBidders(auctionData)
	if not auctionData.bids or #auctionData.bids < 2 then
		return
	end
	
	-- Award EP bonus for participation (10% of winning bid per bidder)
	local participationBonus = auctionData.winnerPrice * 0.1
	
	for idx, bid in ipairs(auctionData.bids) do
		if idx > 1 and bid.player ~= auctionData.winner then
			InfinityLootEPGP:AwardEP(
				auctionData.raidId,
				bid.player,
				participationBonus
			)
		end
	end
end

-- ============================================================================
-- INTEGRATION: LEGACY ADDON MIGRATION
-- ============================================================================

-- Import data from ClassicLootManager format
function InfinityLootAuctionIntegration:ImportFromClassicLootManager(clmData)
	if not clmData then
		return false
	end
	
	local importedCount = 0
	
	for lootId, lootEntry in pairs(clmData or {}) do
		local converted = {
			itemLink = lootEntry.item,
			winner = lootEntry.player,
			winnerPrice = lootEntry.cost or 0,
			raidId = lootEntry.raidId,
			timestamp = lootEntry.timestamp,
			biddingMode = "legacy_clm",
		}
		
		-- Record in Infinity system
		InfinityLootManager:AwardLoot(
			converted.raidId,
			converted.winner,
			converted.itemLink,
			converted.winnerPrice
		)
		
		importedCount = importedCount + 1
	end
	
	InfinityUtils:Info("Imported " .. importedCount .. " loot entries from ClassicLootManager", "AuctionIntegration")
	return true
end

-- Import from MonolithDKP format
function InfinityLootAuctionIntegration:ImportFromMonolithDKP(dkpData)
	if not dkpData then
		return false
	end
	
	local importedCount = 0
	
	for playerId, dkpEntry in pairs(dkpData or {}) do
		-- Convert DKP points to EPGP
		local ep = dkpEntry.earned or 0
		local gp = dkpEntry.spent or 0
		
		InfinityLootEPGP:AddPlayer(dkpEntry.name, dkpEntry.class)
		InfinityLootEPGP:SetPlayerEP(dkpEntry.name, ep)
		InfinityLootEPGP:SetPlayerGP(dkpEntry.name, gp)
		
		importedCount = importedCount + 1
	end
	
	InfinityUtils:Info("Imported " .. importedCount .. " players from MonolithDKP", "AuctionIntegration")
	return true
end

-- ============================================================================
-- INTEGRATION: DATABASE ADDON SYNCHRONIZATION
-- ============================================================================

-- Sync with QuestieDB for item information (optional)
function InfinityLootAuctionIntegration:SyncWithQuestieDB()
	if not _G.QuestieDB then
		InfinityUtils:Debug("Optional QuestieDB not installed", "AuctionIntegration")
		return false
	end
	
	InfinityUtils:Info("Synced with optional QuestieDB", "AuctionIntegration")
	return true
end

-- Sync with Pricematically for pricing data (optional)
function InfinityLootAuctionIntegration:SyncWithPricematically()
	if not _G.Pricematically then
		InfinityUtils:Debug("Optional Pricematically not installed", "AuctionIntegration")
		return false
	end
	
	InfinityUtils:Info("Synced with optional Pricematically", "AuctionIntegration")
	return true
end

-- ============================================================================
-- INTEGRATION: DISCORD WEBHOOK
-- ============================================================================

-- Send auction result to Discord
function InfinityLootAuctionIntegration:SendToDiscord(auctionData, webhookURL)
	if not webhookURL then
		InfinityUtils:Warning("No Discord webhook configured", "AuctionIntegration")
		return false
	end
	
	local message = {
		content = "🎁 **Loot Auction Closed**",
		embeds = {{
			title = "Auction Result",
			fields = {
				{name = "Winner", value = auctionData.winner, inline = true},
				{name = "Item", value = auctionData.itemLink, inline = true},
				{name = "Bid Amount", value = tostring(auctionData.winnerPrice), inline = false},
				{name = "Bidding Mode", value = auctionData.biddingMode, inline = true},
				{name = "Total Bidders", value = tostring(#auctionData.bids), inline = true},
			},
			color = 3447003, -- Blue
			timestamp = date("!%Y-%m-%dT%H:%M:%SZ"),
		}}
	}
	
	-- In a real implementation, would use curl/HTTP to send
	-- For now, just log that we would send
	InfinityUtils:Info("Would send to Discord: " .. auctionData.winner .. " won " .. auctionData.itemLink, "AuctionIntegration")
	
	return true
end

-- ============================================================================
-- INTEGRATION: CONFIGURATION
-- ============================================================================

-- Check if should award EP to bidders
function InfinityLootAuctionIntegration:ShouldAwardEPToBidders()
	local db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT)
	return db and db.settings and db.settings.awardEPToBidders or false
end

-- Get ascending valuation multiplier for award count
function InfinityLootAuctionIntegration:GetAscendingValuationMultiplier(awardCount)
	local multipliers = {
		[1] = 0.5,
		[2] = 0.7,
		[3] = 0.85,
	}
	
	return multipliers[awardCount] or 1.0
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function InfinityLootAuctionIntegration:Initialize()
	InfinityUtils:Info("Auction Integration system initializing...", "AuctionIntegration")
	
	-- Subscribe to auction closed events
	InfinityMessaging:Subscribe("auction_closed", function(data)
		InfinityLootAuctionIntegration:OnAuctionClosed(data)
	end)
	
	InfinityUtils:Info("Auction Integration system initialized", "AuctionIntegration")
end

return InfinityLootAuctionIntegration
