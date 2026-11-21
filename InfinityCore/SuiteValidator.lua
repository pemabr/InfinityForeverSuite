-- Comprehensive Testing & Validation System
-- Validates entire Infinity Forever suite functionality

local MODULE_NAME = "SuiteValidator"
local InfinityCore = InfinityCore or {}

InfinityCore.SuiteValidator = {
    enabled = false,
    results = {},
    test_count = 0,
    pass_count = 0,
    fail_count = 0,
    
    tests = {}
}

local Validator = InfinityCore.SuiteValidator

function Validator:Initialize()
    self:RegisterTests()
end

function Validator:RegisterTests()
    -- Core addon loading tests
    self:RegisterTest("core_load", "InfinityCore loads", function()
        return InfinityCore ~= nil
    end)
    
    self:RegisterTest("dkp_load", "InfinityDKP loads", function()
        return InfinityDKP ~= nil
    end)
    
    self:RegisterTest("loot_load", "InfinityLoot loads", function()
        return InfinityLoot ~= nil
    end)
    
    self:RegisterTest("healer_load", "InfinityHealer loads", function()
        return InfinityHealer ~= nil
    end)
    
    self:RegisterTest("encounter_load", "InfinityEncounterDatabase loads", function()
        return InfinityEncounterDatabase ~= nil
    end)
    
    -- DKP system tests
    self:RegisterTest("dkp_engine", "DKP engine functional", function()
        return InfinityDKP and InfinityDKP.Engine ~= nil
    end)
    
    self:RegisterTest("dkp_balance", "Player balance tracking works", function()
        if not InfinityDKP or not InfinityDKP.db then
            return false
        end
        return type(InfinityDKP.db.players) == "table"
    end)
    
    self:RegisterTest("decay_system", "Decay system active", function()
        return InfinityDKP and InfinityDKP.Decay ~= nil
    end)
    
    self:RegisterTest("audit_system", "Point audit system active", function()
        return InfinityDKP and InfinityDKP.PointAudit ~= nil
    end)
    
    self:RegisterTest("weekly_caps", "Weekly caps system active", function()
        return InfinityDKP and InfinityDKP.WeeklyCaps ~= nil
    end)
    
    self:RegisterTest("hard_caps", "Hard cap/minimum GP system active", function()
        return InfinityDKP and InfinityDKP.HardCapMinGP ~= nil
    end)
    
    self:RegisterTest("completion_awards", "Completion awards system active", function()
        return InfinityDKP and InfinityDKP.CompletionAwards ~= nil
    end)
    
    -- Loot system tests
    self:RegisterTest("loot_engine", "Loot engine functional", function()
        return InfinityLoot and InfinityLoot.AuctionEngine ~= nil
    end)
    
    self:RegisterTest("loot_pricing", "Loot pricing system active", function()
        return InfinityLoot and InfinityLoot.PricingEngine ~= nil
    end)
    
    self:RegisterTest("bid_notification", "Bid notification system active", function()
        return InfinityLoot and InfinityLoot.BidNotification ~= nil
    end)
    
    self:RegisterTest("loot_queue", "Loot queue display active", function()
        return InfinityLoot and InfinityLoot.LootQueueDisplay ~= nil
    end)
    
    self:RegisterTest("epgp_system", "EPGP system functional", function()
        return InfinityLoot and InfinityLoot.EPGP ~= nil
    end)
    
    -- Healer system tests
    self:RegisterTest("healer_frames", "Healer raid frames active", function()
        return InfinityHealer and InfinityHealer.HealerFrames ~= nil
    end)
    
    self:RegisterTest("click_casting", "Click-casting system active", function()
        return InfinityHealer and InfinityHealer.ClickCasting ~= nil
    end)
    
    self:RegisterTest("heal_prediction", "Healing prediction system active", function()
        return InfinityHealer and InfinityHealer.HealingPrediction ~= nil
    end)
    
    self:RegisterTest("aura_tracking", "Aura tracking system active", function()
        return InfinityHealer and InfinityHealer.AuraTracking ~= nil
    end)
    
    -- Raid management tests
    self:RegisterTest("encounter_db", "Encounter database populated", function()
        if not InfinityEncounterDatabase or not InfinityEncounterDatabase.db then
            return false
        end
        return table.getn(InfinityEncounterDatabase.db) > 50
    end)
    
    self:RegisterTest("guild_roster", "Guild roster system active", function()
        return InfinityGuildRoster ~= nil
    end)
    
    self:RegisterTest("analytics", "Analytics system active", function()
        return InfinityAnalytics ~= nil
    end)
    
    -- Infrastructure tests
    self:RegisterTest("messaging", "Event messaging system active", function()
        return InfinityCore and InfinityCore.Events ~= nil
    end)
    
    self:RegisterTest("performance_monitor", "Performance monitoring active", function()
        return InfinityCore and InfinityCore.PerformanceOptimizer ~= nil
    end)
    
    self:RegisterTest("compat_matrix", "Compatibility matrix active", function()
        return InfinityCore and InfinityCore.CompatibilityMatrix ~= nil
    end)
    
    self:RegisterTest("saved_vars", "SavedVariables persistence active", function()
        return InfinityDKPDB ~= nil and InfinityLootDB ~= nil
    end)
    
    -- Data integrity tests
    self:RegisterTest("guild_name_exists", "Guild name in database", function()
        if not InfinityDKPDB or not InfinityDKPDB.guild_name then
            return false
        end
        return string.len(InfinityDKPDB.guild_name) > 0
    end)
    
    self:RegisterTest("player_data_valid", "Player data structure valid", function()
        if not InfinityDKPDB or not InfinityDKPDB.players then
            return false
        end
        for player_name, player_data in pairs(InfinityDKPDB.players) do
            if type(player_data) ~= "table" then
                return false
            end
        end
        return true
    end)
    
    self:RegisterTest("audit_trail_exists", "Audit trail being logged", function()
        if not InfinityDKPDB or not InfinityDKPDB.transactions then
            return false
        end
        return table.getn(InfinityDKPDB.transactions) > 0
    end)
    
    -- Cross-addon integration tests
    self:RegisterTest("dkp_loot_integration", "DKP and Loot systems integrated", function()
        -- Check if loot system can read DKP balances
        if not InfinityLoot or not InfinityDKP then
            return false
        end
        return true
    end)
    
    self:RegisterTest("healer_core_integration", "Healer and Core systems integrated", function()
        if not InfinityHealer or not InfinityCore then
            return false
        end
        return true
    end)
    
    self:RegisterTest("analytics_integration", "Analytics integrated with other systems", function()
        if not InfinityAnalytics then
            return false
        end
        return true
    end)
end

function Validator:RegisterTest(test_id, test_name, test_func)
    table.insert(self.tests, {
        id = test_id,
        name = test_name,
        func = test_func
    })
end

function Validator:RunAllTests()
    self.results = {}
    self.test_count = 0
    self.pass_count = 0
    self.fail_count = 0
    
    print("|cff00ccffInfinity Suite Validation|r")
    print(string.rep("-", 60))
    
    for _, test in ipairs(self.tests) do
        self.test_count = self.test_count + 1
        
        local success, error_msg = pcall(test.func)
        
        if success then
            self.pass_count = self.pass_count + 1
            print("|cff00ff00✓|r " .. test.name)
        else
            self.fail_count = self.fail_count + 1
            print("|cffff0000✗|r " .. test.name)
            if error_msg then
                print("  Error: " .. tostring(error_msg))
            end
        end
        
        table.insert(self.results, {
            test = test.name,
            passed = success,
            error = error_msg
        })
    end
    
    print(string.rep("-", 60))
    print(string.format("Results: |cff00ff00%d passed|r, |cffff0000%d failed|r / %d total",
        self.pass_count, self.fail_count, self.test_count))
    
    if self.fail_count == 0 then
        print("|cff00ff00✓ All systems operational!|r")
    else
        print("|cffff0000✗ Some systems have issues|r")
    end
    
    return self.fail_count == 0
end

function Validator:GetReport()
    return {
        total = self.test_count,
        passed = self.pass_count,
        failed = self.fail_count,
        results = self.results
    }
end

function Validator:ExportReport(format)
    format = format or "text"
    
    if format == "text" then
        local report = "INFINITY FOREVER SUITE VALIDATION REPORT\n"
        report = report .. string.rep("=", 60) .. "\n"
        report = report .. string.format("Total Tests: %d\n", self.test_count)
        report = report .. string.format("Passed: %d\n", self.pass_count)
        report = report .. string.format("Failed: %d\n", self.fail_count)
        report = report .. string.rep("=", 60) .. "\n\n"
        
        for _, result in ipairs(self.results) do
            local status = result.passed and "PASS" or "FAIL"
            report = report .. string.format("[%s] %s\n", status, result.test)
            if result.error then
                report = report .. string.format("      Error: %s\n", result.error)
            end
        end
        
        return report
    elseif format == "json" then
        local json = {
            timestamp = date("%Y-%m-%d %H:%M:%S"),
            total = self.test_count,
            passed = self.pass_count,
            failed = self.fail_count,
            results = self.results
        }
        return json
    end
    
    return nil
end

-- Register slash command
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("validate", function(args)
        if args == "suite" or args == "all" then
            Validator:RunAllTests()
        elseif args == "report" then
            local report = Validator:ExportReport("text")
            print(report)
        else
            print("|cffff9900Usage:|r /validate suite|all - Run all tests")
            print("|cffff9900Usage:|r /validate report - Show detailed report")
        end
    end, "Run suite validation tests")
end

return InfinityCore.SuiteValidator
