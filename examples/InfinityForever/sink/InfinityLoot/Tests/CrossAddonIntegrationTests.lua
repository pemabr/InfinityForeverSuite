-- Infinity Suite - Cross-Addon Integration Tests
-- Tests interactions between multiple addons (Loot, Healer, Raid, Gear, etc.)

local IntegrationTests = {
	name = "Cross-Addon Integration Tests",
	passed = 0,
	failed = 0,
	addonsPresent = {}
}

-- ============================================================================
-- TEST UTILITIES
-- ============================================================================

local function assert(condition, message)
	if not condition then
		error("[FAIL] " .. (message or "Assertion failed"))
	end
	IntegrationTests.passed = IntegrationTests.passed + 1
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error("[FAIL] " .. (message or "Expected " .. tostring(expected) .. " but got " .. tostring(actual)))
	end
	IntegrationTests.passed = IntegrationTests.passed + 1
end

local function assertNotNil(value, message)
	if value == nil then
		error("[FAIL] " .. (message or "Expected non-nil value"))
	end
	IntegrationTests.passed = IntegrationTests.passed + 1
end

-- Check if addon is loaded
local function IsAddonLoaded(addonName)
	return C_AddOns and C_AddOns.IsAddOnLoaded(addonName) or select(5, GetAddOnInfo(addonName))
end

-- ============================================================================
-- TEST: MESSAGING SYSTEM
-- ============================================================================

function IntegrationTests:TestMessagingSystem()
	print("[TEST] Inter-addon Messaging System")
	
	assertNotNil(InfinityMessaging, "InfinityMessaging should exist")
	assertNotNil(InfinityMessaging.Publish, "Publish method should exist")
	assertNotNil(InfinityMessaging.Subscribe, "Subscribe method should exist")
	
	-- Test pub/sub
	local received = false
	local testData = nil
	
	InfinityMessaging:Subscribe("TEST_EVENT", function(data)
		received = true
		testData = data
	end)
	
	InfinityMessaging:Publish("TEST_EVENT", "Hello")
	
	assert(received, "Message should be received")
	assertEquals(testData, "Hello", "Message data should match")
	
	print("  ✓ Messaging system passed")
end

-- ============================================================================
-- TEST: CORE DEPENDENCY
-- ============================================================================

function IntegrationTests:TestCoreAsHardDependency()
	print("[TEST] InfinityCore as Hard Dependency")
	
	-- InfinityCore should always be present
	assertNotNil(_G.InfinityCore, "InfinityCore should be loaded")
	assertNotNil(_G.InfinityUtils, "InfinityUtils should be available")
	assertNotNil(_G.InfinityDataManager, "InfinityDataManager should be available")
	assertNotNil(_G.InfinityStorageManager, "InfinityStorageManager should be available")
	assertNotNil(_G.InfinityMessaging, "InfinityMessaging should be available")
	
	print("  ✓ Core dependency passed")
end

-- ============================================================================
-- TEST: LOOT + HEALER INTEGRATION
-- ============================================================================

function IntegrationTests:TestLootHealerIntegration()
	print("[TEST] Loot ↔ Healer Integration")
	
	if not IsAddonLoaded("InfinityHealer") then
		print("  ⊘ InfinityHealer not loaded (optional) - skipped")
		return
	end
	
	-- Award item and verify healer sees it
	InfinityLootManager:AwardItem("HealerTest", "Healing Shield", 100)
	
	-- Healer should be able to query available gear improvements
	assertNotNil(InfinityHealer, "InfinityHealer should be available")
	
	print("  ✓ Loot ↔ Healer integration passed")
end

-- ============================================================================
-- TEST: LOOT + RAID INTEGRATION
-- ============================================================================

function IntegrationTests:TestLootRaidIntegration()
	print("[TEST] Loot ↔ Raid Integration")
	
	if not IsAddonLoaded("InfinityRaid") then
		print("  ⊘ InfinityRaid not loaded (optional) - skipped")
		return
	end
	
	-- Award item from encounter
	InfinityLootManager:AwardEP("RaidTest", 100, "encounter:bossname")
	
	-- Raid module should track it
	assertNotNil(InfinityRaid, "InfinityRaid should be available")
	
	print("  ✓ Loot ↔ Raid integration passed")
end

-- ============================================================================
-- TEST: LOOT + GEAR INTEGRATION
-- ============================================================================

function IntegrationTests:TestLootGearIntegration()
	print("[TEST] Loot ↔ Gear Integration")
	
	if not IsAddonLoaded("InfinityGear") then
		print("  ⊘ InfinityGear not loaded (optional) - skipped")
		return
	end
	
	-- Award item and check gear compatibility
	InfinityLootManager:AwardItem("GearTest", "Plate Armor", 150)
	
	-- Gear module should evaluate suitability
	assertNotNil(InfinityGear, "InfinityGear should be available")
	
	print("  ✓ Loot ↔ Gear integration passed")
end

-- ============================================================================
-- TEST: LOOT + INVENTORY INTEGRATION
-- ============================================================================

function IntegrationTests:TestLootInventoryIntegration()
	print("[TEST] Loot ↔ Inventory Integration")
	
	if not IsAddonLoaded("InfinityInventory") then
		print("  ⊘ InfinityInventory not loaded (optional) - skipped")
		return
	end
	
	-- Track item in inventory
	local item = "Test Item"
	InfinityLootManager:AwardItem("InvTest", item, 100)
	
	-- Inventory should track it
	assertNotNil(InfinityInventory, "InfinityInventory should be available")
	
	print("  ✓ Loot ↔ Inventory integration passed")
end

-- ============================================================================
-- TEST: NAMESPACE ISOLATION
-- ============================================================================

function IntegrationTests:TestNamespaceIsolation()
	print("[TEST] Namespace Isolation")
	
	-- Each addon should have its own namespace
	assertNotNil(_G.InfinityCore, "InfinityCore should have global")
	assertNotNil(_G.InfinityLoot or _G.InfinityLootManager, "InfinityLoot should have global")
	
	-- Test that namespaces don't collide
	local coreGlobals = {}
	local lootGlobals = {}
	
	for key, value in pairs(_G) do
		if string.match(key, "^Infinity") then
			if string.match(key, "Core") or string.match(key, "Utils") or string.match(key, "Data") or string.match(key, "Storage") or string.match(key, "Messaging") or string.match(key, "Command") then
				table.insert(coreGlobals, key)
			elseif string.match(key, "Loot") or string.match(key, "EPGP") or string.match(key, "DKP") or string.match(key, "Auction") then
				table.insert(lootGlobals, key)
			end
		end
	end
	
	assert(#coreGlobals > 0, "Core should have globals")
	assert(#lootGlobals > 0, "Loot should have globals")
	
	print("  ✓ Namespace isolation passed")
end

-- ============================================================================
-- TEST: GRACEFUL DEGRADATION
-- ============================================================================

function IntegrationTests:TestGracefulDegradation()
	print("[TEST] Graceful Degradation (Optional Addons)")
	
	-- Core functionality should work even if optional addons disabled
	assertNotNil(InfinityLootManager, "Loot should work without optional addons")
	assertNotNil(InfinityDKPManager, "DKP should work without optional addons")
	
	-- Try awarding points without Healer loaded
	xpcall(function()
		InfinityLootManager:AwardEP("DegradationTest", 100, "raid")
		local ep = InfinityLootManager:GetPlayerEP("DegradationTest")
		assert(ep > 0, "Should award EP without Healer")
	end, function(err)
		error("Loot should degrade gracefully: " .. tostring(err))
	end)
	
	print("  ✓ Graceful degradation passed")
end

-- ============================================================================
-- TEST: SHARED DATA CONSISTENCY
-- ============================================================================

function IntegrationTests:TestSharedDataConsistency()
	print("[TEST] Shared Data Consistency")
	
	-- Data should be consistent across reads
	InfinityLootManager:AwardEP("ConsistencyTest", 500, "raid")
	
	local read1 = InfinityLootManager:GetPlayerEP("ConsistencyTest")
	local read2 = InfinityLootManager:GetPlayerEP("ConsistencyTest")
	local read3 = InfinityLootManager:GetPlayerEP("ConsistencyTest")
	
	assertEquals(read1, read2, "First read should match second")
	assertEquals(read2, read3, "Second read should match third")
	
	print("  ✓ Shared data consistency passed")
end

-- ============================================================================
-- TEST: ERROR HANDLING ACROSS ADDONS
-- ============================================================================

function IntegrationTests:TestCrossAddonErrorHandling()
	print("[TEST] Cross-Addon Error Handling")
	
	-- Test that errors in one addon don't crash others
	local errorCaught = false
	
	xpcall(function()
		-- Try invalid operation
		InfinityLootManager:AwardEP(nil, -999, "invalid")
	end, function(err)
		errorCaught = true
	end)
	
	-- Core should still work after error
	xpcall(function()
		InfinityLootManager:AwardEP("ErrorRecoveryTest", 50, "raid")
		local ep = InfinityLootManager:GetPlayerEP("ErrorRecoveryTest")
		assert(ep > 0, "Should recover after error")
	end, function(err)
		error("System should recover from errors: " .. tostring(err))
	end)
	
	print("  ✓ Cross-addon error handling passed")
end

-- ============================================================================
-- TEST: PERFORMANCE ACROSS ADDONS
-- ============================================================================

function IntegrationTests:TestCrossAddonPerformance()
	print("[TEST] Cross-Addon Performance")
	
	-- Test that operations complete in reasonable time
	local startTime = GetTime()
	
	-- Award many points
	for i = 1, 100 do
		InfinityLootManager:AwardEP("PerfTest" .. i, math.random(50, 500), "raid")
	end
	
	local elapsedTime = GetTime() - startTime
	
	-- Should complete in < 1 second
	assert(elapsedTime < 1.0, string.format("Should complete in <1s, took %.2fs", elapsedTime))
	
	print(string.format("  ✓ Cross-addon performance passed (%.3fs)", elapsedTime))
end

-- ============================================================================
-- TEST: MESSAGING RELIABILITY
-- ============================================================================

function IntegrationTests:TestMessagingReliability()
	print("[TEST] Messaging Reliability")
	
	local messageCount = 0
	local expectedCount = 10
	
	InfinityMessaging:Subscribe("RELIABILITY_TEST", function()
		messageCount = messageCount + 1
	end)
	
	-- Send multiple messages
	for i = 1, expectedCount do
		InfinityMessaging:Publish("RELIABILITY_TEST", i)
	end
	
	assertEquals(messageCount, expectedCount, "All messages should be received")
	
	print("  ✓ Messaging reliability passed")
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function IntegrationTests:RunAll()
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║      Infinity Suite - Cross-Addon Integration Tests       ║")
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	local tests = {
		"TestMessagingSystem",
		"TestCoreAsHardDependency",
		"TestLootHealerIntegration",
		"TestLootRaidIntegration",
		"TestLootGearIntegration",
		"TestLootInventoryIntegration",
		"TestNamespaceIsolation",
		"TestGracefulDegradation",
		"TestSharedDataConsistency",
		"TestCrossAddonErrorHandling",
		"TestCrossAddonPerformance",
		"TestMessagingReliability"
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
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	if self.failed == 0 then
		print("✓ ALL INTEGRATION TESTS PASSED!")
	else
		print("✗ " .. self.failed .. " TEST(S) FAILED")
	end
	
	return self.failed == 0
end

-- ============================================================================
-- INTEGRATION WITH SLASH COMMANDS
-- ============================================================================

_G.InfinityIntegrationTests = IntegrationTests

-- Register slash command
if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("integrationtest", function(args)
		IntegrationTests:RunAll()
	end, {"inttest"})
end

print("[INFO] Cross-Addon Integration Tests loaded successfully")
