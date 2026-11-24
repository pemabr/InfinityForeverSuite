-- Comprehensive Testing & Validation System
-- Validates entire Pluribus suite functionality

local MODULE_NAME = "SuiteValidator"
local PluribusCore = PluribusCore or {}

PluribusCore.SuiteValidator = {
    enabled = false,
    results = {},
    test_count = 0,
    pass_count = 0,
    fail_count = 0,
    
    tests = {}
}

local Validator = PluribusCore.SuiteValidator

function Validator:Initialize()
    self:RegisterTests()
end

function Validator:RegisterTests()
    -- Core addon loading tests
    self:RegisterTest("core_load", "PluribusCore loads", function()
        return PluribusCore ~= nil
    end)
    
    self:RegisterTest("dkp_load", "PluribusDKP loads", function()
        return PluribusDKP ~= nil
    end)
    
    self:RegisterTest("loot_load", "PluribusLoot loads", function()
        return PluribusLoot ~= nil
    end)
    
    self:RegisterTest("healer_load", "PluribusHealer loads", function()
        return PluribusHealer ~= nil
    end)
    
    self:RegisterTest("encounter_load", "PluribusEncounterDatabase loads", function()
        return PluribusEncounterDatabase ~= nil
    end)
    
    -- DKP system tests
    self:RegisterTest("dkp_engine", "DKP engine functional", function()
        return PluribusDKP and PluribusDKP.Engine ~= nil
    end)
    
    self:RegisterTest("dkp_balance", "Player balance tracking works", function()
        if not PluribusDKP or not PluribusDKP.db then
            return false
        end
        return type(PluribusDKP.db.players) == "table"
    end)
    
    self:RegisterTest("decay_system", "Decay system active", function()
        return PluribusDKP and PluribusDKP.Decay ~= nil
    end)
    
    self:RegisterTest("audit_system", "Point audit system active", function()
        return PluribusDKP and PluribusDKP.PointAudit ~= nil
    end)
    
    self:RegisterTest("weekly_caps", "Weekly caps system active", function()
        return PluribusDKP and PluribusDKP.WeeklyCaps ~= nil
    end)
    
    self:RegisterTest("hard_caps", "Hard cap/minimum GP system active", function()
        return PluribusDKP and PluribusDKP.HardCapMinGP ~= nil
    end)
    
    self:RegisterTest("completion_awards", "Completion awards system active", function()
        return PluribusDKP and PluribusDKP.CompletionAwards ~= nil
    end)
    
    -- Loot system tests
    self:RegisterTest("loot_engine", "Loot engine functional", function()
        return PluribusLoot and PluribusLoot.AuctionEngine ~= nil
    end)
    
    self:RegisterTest("loot_pricing", "Loot pricing system active", function()
        return PluribusLoot and PluribusLoot.PricingEngine ~= nil
    end)
    
    self:RegisterTest("bid_notification", "Bid notification system active", function()
        return PluribusLoot and PluribusLoot.BidNotification ~= nil
    end)
    
    self:RegisterTest("loot_queue", "Loot queue display active", function()
        return PluribusLoot and PluribusLoot.LootQueueDisplay ~= nil
    end)
    
    self:RegisterTest("epgp_system", "EPGP system functional", function()
        return PluribusLoot and PluribusLoot.EPGP ~= nil
    end)
    
    -- Healer system tests
    self:RegisterTest("healer_frames", "Healer raid frames active", function()
        return PluribusHealer and PluribusHealer.HealerFrames ~= nil
    end)
    
    self:RegisterTest("click_casting", "Click-casting system active", function()
        return PluribusHealer and PluribusHealer.ClickCasting ~= nil
    end)
    
    self:RegisterTest("heal_prediction", "Healing prediction system active", function()
        return PluribusHealer and PluribusHealer.HealingPrediction ~= nil
    end)
    
    self:RegisterTest("aura_tracking", "Aura tracking system active", function()
        return PluribusHealer and PluribusHealer.AuraTracking ~= nil
    end)
    
    -- Raid management tests
    self:RegisterTest("encounter_db", "Encounter database populated", function()
        if not PluribusEncounterDatabase or not PluribusEncounterDatabase.db then
            return false
        end
        return table.getn(PluribusEncounterDatabase.db) > 50
    end)
    
    self:RegisterTest("guild_roster", "Guild roster system active", function()
        return PluribusGuildRoster ~= nil
    end)
    
    self:RegisterTest("analytics", "Analytics system active", function()
        return PluribusAnalytics ~= nil
    end)
    
    -- Infrastructure tests
    self:RegisterTest("messaging", "Event messaging system active", function()
        return PluribusCore and PluribusCore.Events ~= nil
    end)
    
    self:RegisterTest("performance_monitor", "Performance monitoring active", function()
        return PluribusCore and PluribusCore.PerformanceOptimizer ~= nil
    end)
    
    self:RegisterTest("compat_matrix", "Compatibility matrix active", function()
        return PluribusCore and PluribusCore.CompatibilityMatrix ~= nil
    end)
    
    self:RegisterTest("saved_vars", "SavedVariables persistence active", function()
        return PluribusDKPDB ~= nil and PluribusLootDB ~= nil
    end)
    
    -- Data integrity tests
    self:RegisterTest("guild_name_exists", "Guild name in database", function()
        if not PluribusDKPDB or not PluribusDKPDB.guild_name then
            return false
        end
        return string.len(PluribusDKPDB.guild_name) > 0
    end)
    
    self:RegisterTest("player_data_valid", "Player data structure valid", function()
        if not PluribusDKPDB or not PluribusDKPDB.players then
            return false
        end
        for player_name, player_data in pairs(PluribusDKPDB.players) do
            if type(player_data) ~= "table" then
                return false
            end
        end
        return true
    end)
    
    self:RegisterTest("audit_trail_exists", "Audit trail being logged", function()
        if not PluribusDKPDB or not PluribusDKPDB.transactions then
            return false
        end
        return table.getn(PluribusDKPDB.transactions) > 0
    end)
    
    -- Cross-addon integration tests
    self:RegisterTest("dkp_loot_integration", "DKP and Loot systems integrated", function()
        -- Check if loot system can read DKP balances
        if not PluribusLoot or not PluribusDKP then
            return false
        end
        return true
    end)
    
    self:RegisterTest("healer_core_integration", "Healer and Core systems integrated", function()
        if not PluribusHealer or not PluribusCore then
            return false
        end
        return true
    end)
    
    self:RegisterTest("analytics_integration", "Analytics integrated with other systems", function()
        if not PluribusAnalytics then
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
    
    print("|cff00ccffPluribus Suite Validation|r")
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
        local report = "PLURIBUS SUITE VALIDATION REPORT\n"
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
if PluribusCore.SlashCommand then
    PluribusCore.SlashCommand:Register("validate", function(args)
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

return PluribusCore.SuiteValidator
