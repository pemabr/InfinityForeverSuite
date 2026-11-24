-- Integration Test Suite - Verify all modules load and function

local MODULE_NAME = "IntegrationTests"
local PluribusCore = PluribusCore or {}

PluribusCore.IntegrationTests = {
    test_results = {},
    test_count = 0,
    pass_count = 0,
    fail_count = 0
}

local Tests = PluribusCore.IntegrationTests

function Tests:RegisterTest(name, test_func)
    self.test_results[name] = {
        status = "pending",
        message = "",
        duration = 0
    }
    self.test_count = self.test_count + 1
end

function Tests:RunTest(name, test_func)
    local start_time = GetTime()
    
    local success, result = pcall(test_func)
    local duration = GetTime() - start_time
    
    if success then
        self.test_results[name] = {
            status = "pass",
            message = result or "OK",
            duration = duration
        }
        self.pass_count = self.pass_count + 1
        return true
    else
        self.test_results[name] = {
            status = "fail",
            message = result or "Unknown error",
            duration = duration
        }
        self.fail_count = self.fail_count + 1
        return false
    end
end

function Tests:TestAddonLoads(addon_name)
    return Tests:RunTest("addon_load_" .. addon_name, function()
        if _G[addon_name] then
            return "Addon loaded"
        end
        error("Addon not loaded: " .. addon_name)
    end)
end

function Tests:TestModuleLoads(addon_name, module_name)
    return Tests:RunTest("module_load_" .. addon_name .. "_" .. module_name, function()
        local addon = _G[addon_name]
        if not addon then
            error("Addon not found: " .. addon_name)
        end
        
        if addon[module_name] then
            return "Module loaded"
        end
        error("Module not found: " .. module_name)
    end)
end

function Tests:TestEventSystem()
    return Tests:RunTest("event_system_initialization", function()
        if not PluribusCore.Events then
            error("Event system not initialized")
        end
        
        if not PluribusCore.Events.Register or not PluribusCore.Events.Fire then
            error("Event system missing methods")
        end
        
        return "Event system operational"
    end)
end

function Tests:TestDatabaseSystem()
    return Tests:RunTest("database_system_initialization", function()
        if not PluribusCore.db then
            error("Database not initialized")
        end
        
        return "Database operational"
    end)
end

function Tests:TestSlashCommands()
    return Tests:RunTest("slash_command_registration", function()
        if not PluribusCore.SlashCommand then
            error("Slash command system not found")
        end
        
        if not PluribusCore.SlashCommand.Register then
            error("Slash command Register method missing")
        end
        
        return "Slash command system operational"
    end)
end

function Tests:TestDKPSystem()
    return Tests:RunTest("dkp_system_core", function()
        local PluribusDKP = _G.PluribusDKP
        if not PluribusDKP then
            error("PluribusDKP not loaded")
        end
        
        if not PluribusDKP.db or not PluribusDKP.db.players then
            error("DKP database not initialized")
        end
        
        if not PluribusDKP.Award or not PluribusDKP.Award.GiveDKP then
            error("DKP Award system not found")
        end
        
        return "DKP system operational"
    end)
end

function Tests:TestLootSystem()
    return Tests:RunTest("loot_system_core", function()
        local PluribusLoot = _G.PluribusLoot
        if not PluribusLoot then
            error("PluribusLoot not loaded")
        end
        
        if not PluribusLoot.db or not PluribusLoot.db.loot_history then
            error("Loot database not initialized")
        end
        
        return "Loot system operational"
    end)
end

function Tests:TestHealerSystem()
    return Tests:RunTest("healer_tracking_system", function()
        local PluribusHealer = _G.PluribusHealer
        if not PluribusHealer then
            error("PluribusHealer not loaded")
        end
        
        if not PluribusHealer.db or not PluribusHealer.db.healing_data then
            error("Healer database not initialized")
        end
        
        return "Healer system operational"
    end)
end

function Tests:TestOfficerDashboard()
    return Tests:RunTest("officer_dashboard_module", function()
        if not PluribusCore.OfficerDashboard then
            error("Officer dashboard not loaded")
        end
        
        if not PluribusCore.OfficerDashboard.Open or not PluribusCore.OfficerDashboard.SwitchTab then
            error("Officer dashboard missing methods")
        end
        
        return "Officer dashboard operational"
    end)
end

function Tests:TestPodium()
    return Tests:RunTest("podium_leaderboard_module", function()
        local PluribusDKP = _G.PluribusDKP
        if not PluribusDKP.Podium then
            error("Podium leaderboard not loaded")
        end
        
        if not PluribusDKP.Podium.GetStandings then
            error("Podium missing GetStandings method")
        end
        
        return "Podium leaderboard operational"
    end)
end

function Tests:TestLootReclaim()
    return Tests:RunTest("loot_reclaim_module", function()
        local PluribusLoot = _G.PluribusLoot
        if not PluribusLoot.LootReclaim then
            error("Loot Reclaim not loaded")
        end
        
        if not PluribusLoot.LootReclaim.RecoverLoot then
            error("Loot Reclaim missing RecoverLoot method")
        end
        
        return "Loot Reclaim operational"
    end)
end

function Tests:TestLootExporter()
    return Tests:RunTest("loot_exporter_module", function()
        local PluribusLoot = _G.PluribusLoot
        if not PluribusLoot.LootExporter then
            error("Loot Exporter not loaded")
        end
        
        if not PluribusLoot.LootExporter.ExportLootHistoryCSV then
            error("Loot Exporter missing CSV export")
        end
        
        return "Loot Exporter operational"
    end)
end

function Tests:TestCombatAnalytics()
    return Tests:RunTest("combat_analytics_module", function()
        local PluribusAnalytics = _G.PluribusAnalytics
        if not PluribusAnalytics.CombatAnalytics then
            error("Combat Analytics not loaded")
        end
        
        if not PluribusAnalytics.CombatAnalytics.RecordEvent then
            error("Combat Analytics missing RecordEvent method")
        end
        
        return "Combat Analytics operational"
    end)
end

function Tests:TestLootAnalytics()
    return Tests:RunTest("loot_analytics_module", function()
        local PluribusAnalytics = _G.PluribusAnalytics
        if not PluribusAnalytics.LootAnalytics then
            error("Loot Analytics not loaded")
        end
        
        if not PluribusAnalytics.LootAnalytics.GetPlayerLootComparison then
            error("Loot Analytics missing comparison method")
        end
        
        return "Loot Analytics operational"
    end)
end

function Tests:TestBuffTracker()
    return Tests:RunTest("buff_tracker_module", function()
        local PluribusAnalytics = _G.PluribusAnalytics
        if not PluribusAnalytics.BuffTracker then
            error("Buff Tracker not loaded")
        end
        
        if not PluribusAnalytics.BuffTracker.GetBuffCoverage then
            error("Buff Tracker missing GetBuffCoverage method")
        end
        
        return "Buff Tracker operational"
    end)
end

function Tests:TestCompositionOptimizer()
    return Tests:RunTest("composition_optimizer_module", function()
        local PluribusAnalytics = _G.PluribusAnalytics
        if not PluribusAnalytics.CompositionOptimizer then
            error("Composition Optimizer not loaded")
        end
        
        if not PluribusAnalytics.CompositionOptimizer.AnalyzeComposition then
            error("Composition Optimizer missing AnalyzeComposition method")
        end
        
        return "Composition Optimizer operational"
    end)
end

function Tests:TestSuiteValidator()
    return Tests:RunTest("suite_validator_module", function()
        if not PluribusCore.SuiteValidator then
            error("Suite Validator not loaded")
        end
        
        if not PluribusCore.SuiteValidator.RunAllTests then
            error("Suite Validator missing RunAllTests method")
        end
        
        return "Suite Validator operational"
    end)
end

function Tests:RunAllIntegrationTests()
    print("|cff00ccffRunning Integration Test Suite...|r")
    print(string.rep("=", 60))
    
    self.test_count = 0
    self.pass_count = 0
    self.fail_count = 0
    self.test_results = {}
    
    -- Test core systems
    self:TestEventSystem()
    self:TestDatabaseSystem()
    self:TestSlashCommands()
    
    -- Test addon loads
    self:TestAddonLoads("PluribusCore")
    self:TestAddonLoads("PluribusDKP")
    self:TestAddonLoads("PluribusLoot")
    self:TestAddonLoads("PluribusHealer")
    self:TestAddonLoads("PluribusAnalytics")
    
    -- Test systems
    self:TestDKPSystem()
    self:TestLootSystem()
    self:TestHealerSystem()
    
    -- Test modules
    self:TestOfficerDashboard()
    self:TestPodium()
    self:TestLootReclaim()
    self:TestLootExporter()
    self:TestCombatAnalytics()
    self:TestLootAnalytics()
    self:TestBuffTracker()
    self:TestCompositionOptimizer()
    self:TestSuiteValidator()
    
    -- Print results
    print("")
    for test_name, result in pairs(self.test_results) do
        local status_color = result.status == "pass" and "|cff00ff00✓|r" or "|cffff0000✗|r"
        local duration_str = string.format("%.3fs", result.duration)
        
        print(string.format(
            "%s %-40s [%s]",
            status_color,
            test_name,
            duration_str
        ))
        
        if result.status == "fail" then
            print(string.format("  Error: %s", result.message))
        end
    end
    
    print("")
    print(string.rep("=", 60))
    print(string.format(
        "|cff00ff00%d passed|r, |cffff0000%d failed|r out of %d tests",
        self.pass_count,
        self.fail_count,
        self.test_count
    ))
    
    if self.fail_count == 0 then
        print("|cff00ff00✓ All integration tests passed!|r")
        return true
    else
        print("|cffff0000✗ Some tests failed. Check above for details.|r")
        return false
    end
end

-- Register command
if PluribusCore.SlashCommand then
    PluribusCore.SlashCommand:Register("integrationtest", function(args)
        Tests:RunAllIntegrationTests()
    end, "Run integration tests")
end

return PluribusCore.IntegrationTests
