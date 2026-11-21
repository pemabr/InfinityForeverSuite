-- Loot History Tests
-- Comprehensive test suite for LootHistory module

local Tests = {}

function Tests:RunAll()
    local passed = 0
    local failed = 0
    
    print("=== Loot History Test Suite ===\n")
    
    -- Test 1: Basic logging
    if self:TestBasicLogging() then
        passed = passed + 1
        print("✓ Test 1: Basic Logging")
    else
        failed = failed + 1
        print("✗ Test 1: Basic Logging FAILED")
    end
    
    -- Test 2: Player statistics
    if self:TestPlayerStats() then
        passed = passed + 1
        print("✓ Test 2: Player Statistics")
    else
        failed = failed + 1
        print("✗ Test 2: Player Statistics FAILED")
    end
    
    -- Test 3: Item statistics
    if self:TestItemStats() then
        passed = passed + 1
        print("✓ Test 3: Item Statistics")
    else
        failed = failed + 1
        print("✗ Test 3: Item Statistics FAILED")
    end
    
    -- Test 4: Top recipients query
    if self:TestTopRecipients() then
        passed = passed + 1
        print("✓ Test 4: Top Recipients")
    else
        failed = failed + 1
        print("✗ Test 4: Top Recipients FAILED")
    end
    
    -- Test 5: Player history query
    if self:TestPlayerHistory() then
        passed = passed + 1
        print("✓ Test 5: Player History Query")
    else
        failed = failed + 1
        print("✗ Test 5: Player History Query FAILED")
    end
    
    -- Test 6: Session management
    if self:TestSessionManagement() then
        passed = passed + 1
        print("✓ Test 6: Session Management")
    else
        failed = failed + 1
        print("✗ Test 6: Session Management FAILED")
    end
    
    -- Test 7: Batch logging
    if self:TestBatchLogging() then
        passed = passed + 1
        print("✓ Test 7: Batch Logging")
    else
        failed = failed + 1
        print("✗ Test 7: Batch Logging FAILED")
    end
    
    -- Test 8: Export functionality
    if self:TestExport() then
        passed = passed + 1
        print("✓ Test 8: Export Functionality")
    else
        failed = failed + 1
        print("✗ Test 8: Export Functionality FAILED")
    end
    
    -- Test 9: Date range filtering
    if self:TestDateRangeFiltering() then
        passed = passed + 1
        print("✓ Test 9: Date Range Filtering")
    else
        failed = failed + 1
        print("✗ Test 9: Date Range Filtering FAILED")
    end
    
    -- Test 10: History size limit
    if self:TestHistorySizeLimit() then
        passed = passed + 1
        print("✓ Test 10: History Size Limit")
    else
        failed = failed + 1
        print("✗ Test 10: History Size Limit FAILED")
    end
    
    print("\n=== Test Results ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    
    return failed == 0
end

function Tests:TestBasicLogging()
    -- Clear history
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    InfinityLootHistory.itemStats = {}
    
    -- Log a single entry
    local success = InfinityLootHistory:LogLootAward({
        playerName = "TestPlayer",
        itemName = "TestItem",
        itemId = 12345,
        value = 100,
        reason = "Test Award"
    })
    
    if not success then
        return false
    end
    
    -- Verify entry was added
    if #InfinityLootHistory.lootLog ~= 1 then
        return false
    end
    
    local entry = InfinityLootHistory.lootLog[1]
    return entry.playerName == "TestPlayer" and entry.value == 100
end

function Tests:TestPlayerStats()
    -- Clear history
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    -- Log multiple entries
    InfinityLootHistory:LogLootAward({playerName = "Player1", value = 100})
    InfinityLootHistory:LogLootAward({playerName = "Player1", value = 150})
    InfinityLootHistory:LogLootAward({playerName = "Player1", value = 50})
    
    -- Get stats
    local stats = InfinityLootHistory:GetPlayerStats("Player1")
    
    if not stats then
        return false
    end
    
    -- Verify calculations
    local expectedTotal = 300
    local expectedAvg = 100
    local expectedMax = 150
    local expectedMin = 50
    local expectedCount = 3
    
    return stats.totalValue == expectedTotal and
           stats.averageValue == expectedAvg and
           stats.maxSingleValue == expectedMax and
           stats.minSingleValue == expectedMin and
           stats.totalAwards == expectedCount
end

function Tests:TestItemStats()
    -- Clear history
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.itemStats = {}
    
    -- Log multiple entries for same item
    InfinityLootHistory:LogLootAward({itemId = 100, value = 50})
    InfinityLootHistory:LogLootAward({itemId = 100, value = 75})
    
    -- Get stats
    local stats = InfinityLootHistory:GetItemStats(100)
    
    if not stats then
        return false
    end
    
    return stats.awardCount == 2 and stats.totalValue == 125 and stats.averageValue == 62
end

function Tests:TestTopRecipients()
    -- Clear and populate
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    InfinityLootHistory:LogLootAward({playerName = "A", value = 300})
    InfinityLootHistory:LogLootAward({playerName = "B", value = 200})
    InfinityLootHistory:LogLootAward({playerName = "C", value = 100})
    
    local top = InfinityLootHistory:GetTopLootRecipients(2, "value")
    
    if not top or #top ~= 2 then
        return false
    end
    
    -- Should be A (300), then B (200)
    return top[1].name == "A" and top[2].name == "B"
end

function Tests:TestPlayerHistory()
    -- Clear and populate
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    InfinityLootHistory:LogLootAward({playerName = "Player1", itemName = "Item1", value = 100})
    InfinityLootHistory:LogLootAward({playerName = "Player2", itemName = "Item2", value = 50})
    InfinityLootHistory:LogLootAward({playerName = "Player1", itemName = "Item3", value = 150})
    
    local history = InfinityLootHistory:GetPlayerLootHistory("Player1")
    
    if not history or #history ~= 2 then
        return false
    end
    
    -- Most recent first
    return history[1].itemName == "Item3" and history[2].itemName == "Item1"
end

function Tests:TestSessionManagement()
    -- Start session
    local sessionId = InfinityLootHistory:StartSession("TestSession")
    
    if not sessionId then
        return false
    end
    
    -- Add loot
    local success = InfinityLootHistory:AddToSession(sessionId, {
        playerName = "Player1",
        value = 100
    })
    
    if not success then
        return false
    end
    
    -- End session
    success = InfinityLootHistory:EndSession(sessionId)
    
    if not success then
        return false
    end
    
    -- Get stats
    local stats = InfinityLootHistory:GetSessionStats(sessionId)
    
    return stats and stats.lootCount == 1 and stats.totalValue == 100
end

function Tests:TestBatchLogging()
    -- Clear history
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    -- Log batch
    local success = InfinityLootHistory:LogBatchLootAwards({
        {playerName = "P1", value = 100},
        {playerName = "P2", value = 150},
        {playerName = "P3", value = 200},
    })
    
    if not success then
        return false
    end
    
    return #InfinityLootHistory.lootLog == 3
end

function Tests:TestExport()
    -- Clear and populate
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    InfinityLootHistory:LogLootAward({playerName = "Player1", itemName = "Item1", value = 100})
    
    -- Test plain text export
    local export = InfinityLootHistory:ExportLootHistory()
    
    if not export or type(export) ~= "string" then
        return false
    end
    
    -- Should contain header
    if not export:find("LOOT HISTORY REPORT") then
        return false
    end
    
    -- Test JSON export
    local json = InfinityLootHistory:ExportAsJSON()
    
    if not json or type(json) ~= "string" then
        return false
    end
    
    -- Should contain basic JSON structure
    return json:find('"version"') ~= nil
end

function Tests:TestDateRangeFiltering()
    -- Clear and populate
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    local now = InfinityUtils and InfinityUtils:GetTimeStamp() or os.time()
    
    -- Log with different timestamps
    InfinityLootHistory:LogLootAward({playerName = "P1", value = 100, timestamp = now - 1000})
    InfinityLootHistory:LogLootAward({playerName = "P2", value = 150, timestamp = now})
    InfinityLootHistory:LogLootAward({playerName = "P3", value = 200, timestamp = now + 1000})
    
    -- Query middle range
    local filtered = InfinityLootHistory:GetLootByDateRange(now - 500, now + 500)
    
    return filtered and #filtered == 1 and filtered[1].value == 150
end

function Tests:TestHistorySizeLimit()
    -- Clear history
    InfinityLootHistory.lootLog = {}
    InfinityLootHistory.playerStats = {}
    
    -- Temporarily reduce max entries for testing
    local oldMax = InfinityLootHistory.config.maxHistoryEntries
    InfinityLootHistory.config.maxHistoryEntries = 5
    
    -- Log 10 entries (should trim to 5)
    for i = 1, 10 do
        InfinityLootHistory:LogLootAward({playerName = "P" .. i, value = i * 100})
    end
    
    -- Restore max
    InfinityLootHistory.config.maxHistoryEntries = oldMax
    
    if #InfinityLootHistory.lootLog > 5 then
        return false
    end
    
    -- Should have entries 6-10 (oldest trimmed)
    return InfinityLootHistory.lootLog[1].playerName == "P6"
end

-- Run tests when called
local function RunTests()
    if not InfinityLootHistory then
        print("Error: InfinityLootHistory not found")
        return false
    end
    
    return Tests:RunAll()
end

-- Register as global for slash command
_G.LootHistoryTests = Tests

return Tests
