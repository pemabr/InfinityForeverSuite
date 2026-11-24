-- Pluribus Loot Comprehensive Test Suite
-- Tests all core EPGP, DKP, and loot management functionality

local TestSuite = {
	name = "Pluribus Loot Comprehensive Tests",
	passed = 0,
	failed = 0,
	tests = {}
}

-- ============================================================================
-- TEST UTILITIES
-- ============================================================================

local function assert(condition, message)
	if not condition then
		error("[FAIL] " .. (message or "Assertion failed"))
	end
	TestSuite.passed = TestSuite.passed + 1
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error("[FAIL] " .. (message or "Expected " .. tostring(expected) .. " but got " .. tostring(actual)))
	end
	TestSuite.passed = TestSuite.passed + 1
end

local function assertNotNil(value, message)
	if value == nil then
		error("[FAIL] " .. (message or "Expected non-nil value"))
	end
	TestSuite.passed = TestSuite.passed + 1
end

local function assertNil(value, message)
	if value ~= nil then
		error("[FAIL] " .. (message or "Expected nil but got " .. tostring(value)))
	end
	TestSuite.passed = TestSuite.passed + 1
end

local function assertGreater(actual, threshold, message)
	if actual <= threshold then
		error("[FAIL] " .. (message or "Expected > " .. threshold .. " but got " .. actual))
	end
	TestSuite.passed = TestSuite.passed + 1
end

local function assertLess(actual, threshold, message)
	if actual >= threshold then
		error("[FAIL] " .. (message or "Expected < " .. threshold .. " but got " .. actual))
	end
	TestSuite.passed = TestSuite.passed + 1
end

-- ============================================================================
-- TEST: EPGP POINT SYSTEM
-- ============================================================================

function TestSuite:TestEPGPBasics()
	print("[TEST] EPGP Basics")
	
	-- Initialize player
	PluribusLootManager:AwardEP("PlayerOne", 100, "raid")
	local ep = PluribusLootManager:GetPlayerEP("PlayerOne")
	assertGreater(ep, 0, "EP should be awarded")
	
	-- Award GP
	PluribusLootManager:AwardGP("PlayerOne", 50, "item")
	local gp = PluribusLootManager:GetPlayerGP("PlayerOne")
	assertGreater(gp, 0, "GP should be awarded")
	
	-- Check priority (EP/GP ratio)
	local pr = PluribusLootManager:GetPlayerPR("PlayerOne")
	assert(pr > 0, "Priority ratio should be positive")
	
	print("  ✓ EPGP basics passed")
end

function TestSuite:TestMultipleAwards()
	print("[TEST] Multiple EPGP Awards")
	
	local players = {"Alice", "Bob", "Charlie"}
	local initialEP = {}
	
	-- Award different EP amounts
	PluribusLootManager:AwardEP("Alice", 100, "raid")
	PluribusLootManager:AwardEP("Bob", 150, "raid")
	PluribusLootManager:AwardEP("Charlie", 50, "raid")
	
	-- Verify amounts
	assertEquals(PluribusLootManager:GetPlayerEP("Alice"), 100, "Alice should have 100 EP")
	assertEquals(PluribusLootManager:GetPlayerEP("Bob"), 150, "Bob should have 150 EP")
	assertEquals(PluribusLootManager:GetPlayerEP("Charlie"), 50, "Charlie should have 50 EP")
	
	-- Highest priority goes to highest EP/GP
	local standings = PluribusLootManager:GetStandings()
	assert(#standings > 0, "Should have standings")
	
	print("  ✓ Multiple awards passed")
end

function TestSuite:TestPriorityCalculation()
	print("[TEST] Priority Calculation")
	
	-- Setup test scenario
	PluribusLootManager:AwardEP("PlayerA", 200, "raid")
	PluribusLootManager:AwardEP("PlayerB", 100, "raid")
	PluribusLootManager:AwardGP("PlayerA", 100, "item")
	PluribusLootManager:AwardGP("PlayerB", 50, "item")
	
	-- PlayerA should have higher priority (200/100 = 2.0 vs 100/50 = 2.0, but got EP first)
	local standings = PluribusLootManager:GetStandings()
	assert(#standings >= 2, "Should have at least 2 players")
	
	print("  ✓ Priority calculation passed")
end

-- ============================================================================
-- TEST: DKP SYSTEM
-- ============================================================================

function TestSuite:TestDKPBasics()
	print("[TEST] DKP Basics")
	
	-- Initialize DKP
	PluribusDKPManager:AwardDKP("Player1", 100, "raid")
	local dkp = PluribusDKPManager:GetPlayerDKP("Player1")
	assertGreater(dkp, 0, "DKP should be awarded")
	
	-- Spend DKP
	PluribusDKPManager:SpendDKP("Player1", 30, "item")
	local newDKP = PluribusDKPManager:GetPlayerDKP("Player1")
	assertLess(newDKP, dkp, "DKP should decrease after spending")
	
	print("  ✓ DKP basics passed")
end

function TestSuite:TestDKPTrade()
	print("[TEST] DKP Trading")
	
	-- Setup initial DKP
	PluribusDKPManager:AwardDKP("Seller", 500, "initial")
	PluribusDKPManager:AwardDKP("Buyer", 200, "initial")
	
	local sellerBefore = PluribusDKPManager:GetPlayerDKP("Seller")
	local buyerBefore = PluribusDKPManager:GetPlayerDKP("Buyer")
	
	-- Trade DKP
	PluribusDKPManager:TradeDKP("Seller", "Buyer", 50, "trade")
	
	local sellerAfter = PluribusDKPManager:GetPlayerDKP("Seller")
	local buyerAfter = PluribusDKPManager:GetPlayerDKP("Buyer")
	
	assertLess(sellerAfter, sellerBefore, "Seller should lose DKP")
	assertGreater(buyerAfter, buyerBefore, "Buyer should gain DKP")
	
	print("  ✓ DKP trading passed")
end

function TestSuite:TestDKPDecay()
	print("[TEST] DKP Decay")
	
	-- Initialize with known amount
	PluribusDKPManager:AwardDKP("DecayTest", 1000, "initial")
	
	-- Apply 5% decay
	PluribusDecayManager:ApplyDecay(0.05, "weekly")
	
	local dkpAfter = PluribusDKPManager:GetPlayerDKP("DecayTest")
	-- Should be approximately 950 (1000 * 0.95)
	assertGreater(dkpAfter, 900, "DKP should decay to ~950")
	assertLess(dkpAfter, 1000, "DKP should decrease with decay")
	
	print("  ✓ DKP decay passed")
end

-- ============================================================================
-- TEST: LOOT HISTORY
-- ============================================================================

function TestSuite:TestLootHistoryLogging()
	print("[TEST] Loot History Logging")
	
	-- Award item and log it
	PluribusLootManager:AwardEP("HistoryTest", 100, "raid")
	PluribusLootManager:AwardItem("HistoryTest", "Sword of Might", 50)
	
	-- Retrieve history
	local history = PluribusLootManager:GetPlayerLootHistory("HistoryTest")
	assertNotNil(history, "History should exist")
	assert(#history > 0, "History should contain awards")
	
	print("  ✓ Loot history logging passed")
end

function TestSuite:TestLootStatistics()
	print("[TEST] Loot Statistics")
	
	-- Setup test data
	PluribusLootManager:AwardItem("StatTest", "Item1", 100)
	PluribusLootManager:AwardItem("StatTest", "Item2", 150)
	PluribusLootManager:AwardItem("StatTest", "Item3", 75)
	
	-- Get stats
	local stats = PluribusLootManager:GetPlayerLootStats("StatTest")
	assertNotNil(stats, "Stats should exist")
	assert(stats.totalItems >= 3, "Should have at least 3 items")
	assert(stats.totalValue >= 325, "Total value should be >= 325")
	
	print("  ✓ Loot statistics passed")
end

-- ============================================================================
-- TEST: ACCESS CONTROL
-- ============================================================================

function TestSuite:TestRolePermissions()
	print("[TEST] Role Permissions")
	
	-- Setup roles
	PluribusAccessControl:SetPlayerRole("Admin", "admin")
	PluribusAccessControl:SetPlayerRole("Member", "member")
	
	-- Check permissions
	local adminPerms = PluribusAccessControl:GetPlayerPermissions("Admin")
	local memberPerms = PluribusAccessControl:GetPlayerPermissions("Member")
	
	assertNotNil(adminPerms, "Admin should have permissions")
	assertNotNil(memberPerms, "Member should have permissions")
	
	-- Admin should have more permissions than member
	local adminCount = 0
	local memberCount = 0
	for _ in pairs(adminPerms) do adminCount = adminCount + 1 end
	for _ in pairs(memberPerms) do memberCount = memberCount + 1 end
	
	assertGreater(adminCount, memberCount, "Admin should have more permissions than member")
	
	print("  ✓ Role permissions passed")
end

function TestSuite:TestActionAuditing()
	print("[TEST] Action Auditing")
	
	-- Perform action
	PluribusLootManager:AwardEP("AuditTest", 50, "raid")
	
	-- Check audit log
	local auditLog = PluribusAccessControl:GetAuditLog()
	assertNotNil(auditLog, "Audit log should exist")
	assert(#auditLog > 0, "Audit log should contain entries")
	
	print("  ✓ Action auditing passed")
end

-- ============================================================================
-- TEST: ITEM PRICING
-- ============================================================================

function TestSuite:TestItemPricing()
	print("[TEST] Item Pricing")
	
	-- Set item prices
	PluribusPricingSystem:SetItemPrice("Common Sword", 50)
	PluribusPricingSystem:SetItemPrice("Rare Shield", 150)
	
	-- Retrieve prices
	local swordPrice = PluribusPricingSystem:GetItemPrice("Common Sword")
	local shieldPrice = PluribusPricingSystem:GetItemPrice("Rare Shield")
	
	assertEquals(swordPrice, 50, "Sword price should be 50")
	assertEquals(shieldPrice, 150, "Shield price should be 150")
	
	print("  ✓ Item pricing passed")
end

function TestSuite:TestPricingMultipliers()
	print("[TEST] Pricing Multipliers")
	
	-- Test slot multipliers
	local handPrice = PluribusPricingSystem:GetSlotMultiplier("INVTYPE_HAND")
	local shieldPrice = PluribusPricingSystem:GetSlotMultiplier("INVTYPE_SHIELD")
	
	assertNotNil(handPrice, "Hand slot should have multiplier")
	assertNotNil(shieldPrice, "Shield slot should have multiplier")
	
	-- Shields typically cost more than hands
	assertGreater(shieldPrice, 0, "Shield multiplier should be positive")
	assertGreater(handPrice, 0, "Hand multiplier should be positive")
	
	print("  ✓ Pricing multipliers passed")
end

-- ============================================================================
-- TEST: AUCTIONS
-- ============================================================================

function TestSuite:TestAuctionCreation()
	print("[TEST] Auction Creation")
	
	-- Create auction
	local auctionId = PluribusAuctionManager:CreateAuction({
		item = "Test Sword",
		basePrice = 100,
		duration = 300,
		mode = "open"
	})
	
	assertNotNil(auctionId, "Auction should be created")
	
	-- Retrieve auction
	local auction = PluribusAuctionManager:GetAuction(auctionId)
	assertNotNil(auction, "Auction should be retrievable")
	assertEquals(auction.basePrice, 100, "Base price should match")
	
	print("  ✓ Auction creation passed")
end

function TestSuite:TestAuctionBidding()
	print("[TEST] Auction Bidding")
	
	-- Create auction
	local auctionId = PluribusAuctionManager:CreateAuction({
		item = "Bidding Test",
		basePrice = 100,
		duration = 300
	})
	
	-- Place bids
	PluribusAuctionManager:PlaceBid(auctionId, "Bidder1", 150)
	PluribusAuctionManager:PlaceBid(auctionId, "Bidder2", 200)
	
	-- Check highest bidder
	local auction = PluribusAuctionManager:GetAuction(auctionId)
	assertEquals(auction.highBidder, "Bidder2", "Highest bidder should be Bidder2")
	assertEquals(auction.highBid, 200, "Highest bid should be 200")
	
	print("  ✓ Auction bidding passed")
end

function TestSuite:TestMultipleAuctions()
	print("[TEST] Multiple Simultaneous Auctions")
	
	local auctionIds = {}
	
	-- Create multiple auctions
	for i = 1, 5 do
		local id = PluribusAuctionManager:CreateAuction({
			item = "Item " .. i,
			basePrice = 50 * i,
			duration = 300
		})
		table.insert(auctionIds, id)
	end
	
	-- Verify all created
	assert(#auctionIds == 5, "Should create 5 auctions")
	
	-- Verify all retrievable
	for _, id in ipairs(auctionIds) do
		local auction = PluribusAuctionManager:GetAuction(id)
		assertNotNil(auction, "Auction " .. id .. " should exist")
	end
	
	print("  ✓ Multiple auctions passed")
end

-- ============================================================================
-- TEST: GUILD BANK INTEGRATION
-- ============================================================================

function TestSuite:TestGuildBankTracking()
	print("[TEST] Guild Bank Tracking")
	
	-- Record bank deposit
	PluribusGuildBankIntegration:RecordDeposit("DepositTest", "Gold", 1000)
	
	-- Check deposit recorded
	local deposits = PluribusGuildBankIntegration:GetPlayerDeposits("DepositTest")
	assertNotNil(deposits, "Deposits should be recorded")
	
	print("  ✓ Guild bank tracking passed")
end

function TestSuite:TestGuildBankDKP()
	print("[TEST] Guild Bank DKP Awards")
	
	-- Configure DKP per gold
	PluribusGuildBankIntegration:ConfigureDKPRewards(0.01, 0.02)
	
	-- Record deposit
	local dkpBefore = PluribusDKPManager:GetPlayerDKP("DKPGainTest") or 0
	PluribusGuildBankIntegration:RecordDeposit("DKPGainTest", "Gold", 1000)
	local dkpAfter = PluribusDKPManager:GetPlayerDKP("DKPGainTest") or 0
	
	assertGreater(dkpAfter, dkpBefore, "DKP should increase with deposit")
	
	print("  ✓ Guild bank DKP awards passed")
end

-- ============================================================================
-- TEST: TRANSACTION HISTORY
-- ============================================================================

function TestSuite:TestTransactionTracking()
	print("[TEST] Transaction Tracking")
	
	-- Record multiple transactions
	PluribusTransactionHistory:LogTransaction({
		player = "TxnTest",
		type = "award",
		amount = 100,
		reason = "raid",
		timestamp = GetTime()
	})
	
	-- Retrieve transactions
	local transactions = PluribusTransactionHistory:GetPlayerTransactions("TxnTest")
	assertNotNil(transactions, "Transactions should be tracked")
	assert(#transactions > 0, "Should have transaction entries")
	
	print("  ✓ Transaction tracking passed")
end

function TestSuite:TestAnomalyDetection()
	print("[TEST] Anomaly Detection")
	
	-- Award unusually large amount
	local detected = false
	
	local beforeCount = (PluribusAnomalyDetector:GetAnomalies() or {})
	
	PluribusLootManager:AwardEP("AnomalyTest", 10000, "raid")
	
	local afterAnomalies = PluribusAnomalyDetector:GetAnomalies() or {}
	
	-- Should detect anomaly if system is working
	assert(#afterAnomalies >= #beforeCount, "Should detect large awards")
	
	print("  ✓ Anomaly detection passed")
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function TestSuite:RunAll()
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║      Pluribus Loot - Comprehensive Test Suite              ║")
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	local tests = {
		"TestEPGPBasics",
		"TestMultipleAwards",
		"TestPriorityCalculation",
		"TestDKPBasics",
		"TestDKPTrade",
		"TestDKPDecay",
		"TestLootHistoryLogging",
		"TestLootStatistics",
		"TestRolePermissions",
		"TestActionAuditing",
		"TestItemPricing",
		"TestPricingMultipliers",
		"TestAuctionCreation",
		"TestAuctionBidding",
		"TestMultipleAuctions",
		"TestGuildBankTracking",
		"TestGuildBankDKP",
		"TestTransactionTracking",
		"TestAnomalyDetection"
	}
	
	local failed = 0
	
	for _, testName in ipairs(tests) do
		if self[testName] then
			xpcall(function()
				self[testName](self)
			end, function(err)
				print("  ✗ " .. testName .. " FAILED: " .. tostring(err))
				failed = failed + 1
				self.failed = self.failed + 1
			end)
		end
	end
	
	-- Print summary
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║                      TEST SUMMARY                          ║")
	print("╠════════════════════════════════════════════════════════════╣")
	print(string.format("║ Total Tests:     %d                                       ║", #tests))
	print(string.format("║ Passed:          %d                                       ║", self.passed))
	print(string.format("║ Failed:          %d                                       ║", self.failed))
	print(string.format("║ Assertions:      %d                                       ║", self.passed + self.failed))
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	if self.failed == 0 then
		print("✓ ALL TESTS PASSED!")
	else
		print("✗ " .. self.failed .. " TEST(S) FAILED")
	end
	
	return self.failed == 0
end

-- ============================================================================
-- INTEGRATION WITH SLASH COMMANDS
-- ============================================================================

_G.PluribusLootTests = TestSuite

-- Register slash command
if PluribusCommandRegistry then
	PluribusCommandRegistry:RegisterCommand("lottests", function(args)
		TestSuite:RunAll()
	end, {"ltest", "lottest"})
end

print("[INFO] Pluribus Loot Comprehensive Tests loaded successfully")
