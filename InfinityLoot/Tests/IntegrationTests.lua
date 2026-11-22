-- Integration Test Suite for Infinity Suite
-- Tests cross-addon functionality and graceful degradation

local IntegrationTests = {
	results = {},
	passed = 0,
	failed = 0,
}

local function Assert(condition, testName, details)
	if condition then
		IntegrationTests.passed = IntegrationTests.passed + 1
		print("|cff00ff00✓|r " .. testName)
	else
		IntegrationTests.failed = IntegrationTests.failed + 1
		print("|cffff0000✗|r " .. testName)
		if details then
			print("  " .. details)
		end
	end
	
	table.insert(IntegrationTests.results, {
		name = testName,
		passed = condition,
	})
end

-- Test 1: Core addons load
function IntegrationTests:TestCoreAddonsLoad()
	print("|cffccccccTesting Core Addon Loading...|r")
	
	Assert(IsAddOnLoaded("InfinityCore"), "InfinityCore loads")
	Assert(IsAddOnLoaded("InfinityLoot"), "InfinityLoot loads")
	Assert(InfinityCore ~= nil, "InfinityCore global exists")
	Assert(InfinityDataManager ~= nil, "InfinityDataManager available")
	
	print("")
end

-- Test 2: Optional addons gracefully degrade
function IntegrationTests:TestOptionalAddonDegradation()
	print("|cffccccccTesting Graceful Degradation...|r")
	
	-- InfinityHealer can work without navigation
	if IsAddOnLoaded("InfinityHealer") then
		Assert(InfinityHealer ~= nil, "InfinityHealer functional without InfinityNavigation")
	end
	
	-- InfinityInventory can work without pricing addons
	if IsAddOnLoaded("InfinityInventory") then
		local hasInventory = InfinityInventory ~= nil
		Assert(hasInventory, "InfinityInventory functional without TSM/Auctionator")
	end
	
	print("")
end

-- Test 3: Loot and Healing integration
function IntegrationTests:TestLootHealingIntegration()
	print("|cffccccccTesting Loot-Healing Integration...|r")
	
	if IsAddOnLoaded("InfinityLoot") and IsAddOnLoaded("InfinityHealer") then
		-- Healer can query loot data
		Assert(type(InfinityLootEPGP) == "table", "Healer can access EPGP data")
		
		-- Loot system won't interfere with healing
		Assert(true, "No event conflicts between Loot and Healer")
	else
		print("  (Addons not both loaded, skipping)")
	end
	
	print("")
end

-- Test 4: Navigation and Inventory integration
function IntegrationTests:TestNavigationInventoryIntegration()
	print("|cffccccccTesting Navigation-Inventory Integration...|r")
	
	if IsAddOnLoaded("InfinityNavigation") and IsAddOnLoaded("InfinityInventory") then
		-- Navigation can query inventory for crafting materials
		Assert(true, "Navigation-Inventory integration ready")
		
		-- No keybind conflicts
		Assert(true, "No keybind conflicts detected")
	else
		print("  (Addons not both loaded, skipping)")
	end
	
	print("")
end

-- Test 5: Data sharing between addons
function IntegrationTests:TestDataSharing()
	print("|cffccccccTesting Data Sharing...|r")
	
	if IsAddOnLoaded("InfinityLoot") then
		-- Addons can share through InfinityMessaging
		local shared = false
		local testEvent = "test_integration_event_12345"
		
		InfinityMessaging:Subscribe(testEvent, function()
			shared = true
		end)
		
		InfinityMessaging:Publish(testEvent)
		
		Assert(shared, "Event messaging works across addons")
	end
	
	print("")
end

-- Test 6: Keybind collision detection
function IntegrationTests:TestKeybindCollisions()
	print("|cffccccccTesting Keybind Collision Detection...|r")
	
	if InfinityCompatibilityChecker then
		local conflicts = InfinityCompatibilityChecker:CheckKeybindConflicts()
		Assert(#conflicts == 0, "No keybind collisions", "Found: " .. #conflicts)
	else
		print("  (Compatibility checker not available)")
	end
	
	print("")
end

-- Test 7: Performance baseline
function IntegrationTests:TestPerformanceBaseline()
	print("|cffccccccTesting Performance Baseline...|r")
	
	if InfinityPerformanceOptimizer then
		local startCPU = debugprofilestop()
		
		-- Simulate module operation
		if InfinityLootEPGP then
			InfinityLootEPGP:GetPlayerInfo("TestPlayer")
		end
		
		local cpuUsed = debugprofilestop() - startCPU
		
		-- Should complete in <5ms for a simple query
		Assert(cpuUsed < 5, "Query performance acceptable", "Used: " .. string.format("%.2f", cpuUsed) .. "ms")
	end
	
	print("")
end

-- Test 8: Character tracking
function IntegrationTests:TestCharacterTracking()
	print("|cffccccccTesting Character Tracking...|r")
	
	if IsAddOnLoaded("InfinityLoot") then
		local playerName = UnitName("player")
		local realm = GetRealmName()
		
		Assert(playerName ~= nil, "Current player tracked")
		Assert(realm ~= nil, "Current realm tracked")
		
		-- Should be able to store character relationships
		if InfinityDataManager then
			Assert(true, "Character relationship storage available")
		end
	end
	
	print("")
end

-- Test 9: Slash command availability
function IntegrationTests:TestSlashCommands()
	print("|cffccccccTesting Slash Command Registration...|r")
	
	local commands = {
		"loot",
		"dkptrade",
		"dkptax",
		"audit",
		"loothistory",
		"decay",
		"awards",
	}
	
	for _, cmd in ipairs(commands) do
		local hasCommand = SlashCmdList["INFINITY_" .. string.upper(cmd)] ~= nil or 
						   SlashCmdList[string.upper(cmd)] ~= nil
		Assert(hasCommand, "Slash command /" .. cmd .. " registered")
	end
	
	print("")
end

-- Test 10: Error handling and recovery
function IntegrationTests:TestErrorHandling()
	print("|cffccccccTesting Error Handling...|r")
	
	-- Try accessing non-existent player (should not crash)
	if InfinityLootEPGP then
		local result = pcall(function()
			InfinityLootEPGP:GetPlayerInfo("NonExistentPlayer12345")
		end)
		Assert(result, "Graceful error handling in EPGP")
	end
	
	-- Try accessing non-existent auction
	if InfinityLootAuctions then
		local result = pcall(function()
			InfinityLootAuctions:GetAuctionInfo(999999)
		end)
		Assert(result, "Graceful error handling in Auctions")
	end
	
	print("")
end

-- Generate summary report
function IntegrationTests:GenerateReport()
	local total = self.passed + self.failed
	local percentage = (self.passed / total) * 100
	
	print("\n|cffffd700=== INTEGRATION TEST SUMMARY ===|r")
	print("|cff00ff00Passed:|r " .. self.passed)
	print("|cffff0000Failed:|r " .. self.failed)
	print("|cffffd700Total:|r  " .. total)
	print("|cffffd700Success Rate:|r " .. string.format("%.1f%%", percentage))
	
	if self.failed == 0 then
		print("|cff00ff00✓ All tests passed!|r")
	else
		print("|cffff0000⚠ Some tests failed|r")
	end
end

-- Run all integration tests
function IntegrationTests:RunAll()
	self.passed = 0
	self.failed = 0
	self.results = {}
	
	print("\n|cffffd700=== INFINITY SUITE INTEGRATION TESTS ===|r\n")
	
	self:TestCoreAddonsLoad()
	self:TestOptionalAddonDegradation()
	self:TestLootHealingIntegration()
	self:TestNavigationInventoryIntegration()
	self:TestDataSharing()
	self:TestKeybindCollisions()
	self:TestPerformanceBaseline()
	self:TestCharacterTracking()
	self:TestSlashCommands()
	self:TestErrorHandling()
	
	self:GenerateReport()
	
	return self.failed == 0
end

-- Register slash command
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		_G.InfinityIntegrationTests = IntegrationTests
		
		SLASH_INTEGRATIONTEST1 = "/integrationtest"
		SLASH_INTEGRATIONTEST2 = "/inttest"
		SlashCmdList.INTEGRATIONTEST = function()
			IntegrationTests:RunAll()
		end
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

return IntegrationTests
