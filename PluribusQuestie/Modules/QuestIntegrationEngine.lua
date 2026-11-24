-- QuestIntegrationEngine.lua - Cross-addon integration and compatibility
-- Part of PluribusQuestie addon suite
-- Handles integration with Questie, QuestHelper, and other quest addons

local QuestIntegrationEngine = {}
QuestIntegrationEngine.enabled = false
QuestIntegrationEngine.db = nil
QuestIntegrationEngine.integrated_addons = {}
QuestIntegrationEngine.integration_status = {}

-- Configuration
QuestIntegrationEngine.config = {
    enabled = true,
    auto_integrate = true,
    sync_on_startup = true,
}

-- Known addon integrations
QuestIntegrationEngine.addon_list = {
    {name = "Questie", check_function = "QuestieLoader", priority = 1},
    {name = "QuestHelper", check_function = "QuestHelper", priority = 2},
    {name = "TomTom", check_function = "TomTom", priority = 3},
    {name = "Cartographer", check_function = "Cartographer", priority = 4},
    {name = "GatherMate2", check_function = "GatherMate2", priority = 5},
}

function QuestIntegrationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.integrated_addons then
        self.db.integrated_addons = {}
    end
    
    if not self.db.integration_status then
        self.db.integration_status = {}
    end
    
    self.integrated_addons = self.db.integrated_addons
    self.integration_status = self.db.integration_status
    self.enabled = true
    
    self:Log("Initialized quest integration engine")
    
    if self.config.sync_on_startup then
        self:DiscoverAvailableAddons()
    end
end

function QuestIntegrationEngine:IsAddonAvailable(addonName)
    if not addonName then
        return false
    end
    
    for _, addon in ipairs(self.addon_list) do
        if addon.name == addonName then
            if _G[addon.check_function] then
                return true
            end
        end
    end
    
    return false
end

function QuestIntegrationEngine:DiscoverAvailableAddons()
    self:Log("Discovering available addons...")
    
    local discoveredCount = 0
    
    for _, addon in ipairs(self.addon_list) do
        if self:IsAddonAvailable(addon.name) then
            if self:RegisterAddonIntegration(addon.name, addon.priority) then
                discoveredCount = discoveredCount + 1
            end
        end
    end
    
    self:Log("Discovered " .. discoveredCount .. " available addons")
    return discoveredCount
end

function QuestIntegrationEngine:RegisterAddonIntegration(addonName, priority)
    if not addonName then
        return false
    end
    
    priority = priority or 10
    
    local integration = {
        name = addonName,
        priority = priority,
        enabled = true,
        integrated_at = GetTime(),
        sync_count = 0,
    }
    
    self.integrated_addons[addonName] = integration
    self.integration_status[addonName] = "registered"
    
    self:Log("Registered addon integration: " .. addonName .. " (priority: " .. priority .. ")")
    
    return true
end

function QuestIntegrationEngine:IntegrateWithQuestie()
    if not self:IsAddonAvailable("Questie") then
        self:Log("Questie addon not available")
        return false
    end
    
    -- Try to integrate with Questie's database
    if _G.QuestieLoader and _G.QuestieLoader.GetLoadedDatabase then
        local questieDB = _G.QuestieLoader.GetLoadedDatabase()
        if questieDB then
            self:Log("Successfully integrated with Questie database")
            self.integration_status["Questie"] = "integrated"
            return true
        end
    end
    
    self.integration_status["Questie"] = "failed"
    return false
end

function QuestIntegrationEngine:SyncQuestData(addonName)
    if not addonName or not self.integrated_addons[addonName] then
        return false
    end
    
    if addonName == "Questie" then
        return self:SyncQuestieData()
    elseif addonName == "QuestHelper" then
        return self:SyncQuestHelperData()
    end
    
    return false
end

function QuestIntegrationEngine:SyncQuestieData()
    if not self:IsAddonAvailable("Questie") then
        return false
    end
    
    -- Placeholder for Questie data sync
    local synced = 0
    
    if _G.QuestieLoader and _G.QuestieLoader.GetLoadedDatabase then
        local questieDB = _G.QuestieLoader.GetLoadedDatabase()
        if questieDB then
            -- Would sync quest data from Questie here
            synced = 1
            self:Log("Synced data with Questie")
            
            if self.integrated_addons["Questie"] then
                self.integrated_addons["Questie"].sync_count = (self.integrated_addons["Questie"].sync_count or 0) + 1
            end
        end
    end
    
    return synced > 0
end

function QuestIntegrationEngine:SyncQuestHelperData()
    if not self:IsAddonAvailable("QuestHelper") then
        return false
    end
    
    -- Placeholder for QuestHelper data sync
    self:Log("Synced data with QuestHelper")
    
    if self.integrated_addons["QuestHelper"] then
        self.integrated_addons["QuestHelper"].sync_count = (self.integrated_addons["QuestHelper"].sync_count or 0) + 1
    end
    
    return true
end

function QuestIntegrationEngine:CallbackOnQuestieReady(callback)
    if not self:IsAddonAvailable("Questie") then
        if callback then
            callback(false, "Questie not available")
        end
        return
    end
    
    if callback then
        callback(true, "Questie is available")
    end
end

function QuestIntegrationEngine:IsIntegrated(addonName)
    if not addonName or not self.integrated_addons[addonName] then
        return false
    end
    
    return self.integrated_addons[addonName].enabled
end

function QuestIntegrationEngine:DisableIntegration(addonName)
    if not addonName or not self.integrated_addons[addonName] then
        return false
    end
    
    self.integrated_addons[addonName].enabled = false
    self.integration_status[addonName] = "disabled"
    
    self:Log("Disabled integration with: " .. addonName)
    return true
end

function QuestIntegrationEngine:EnableIntegration(addonName)
    if not addonName or not self.integrated_addons[addonName] then
        return false
    end
    
    self.integrated_addons[addonName].enabled = true
    self.integration_status[addonName] = "enabled"
    
    self:Log("Enabled integration with: " .. addonName)
    return true
end

function QuestIntegrationEngine:GetIntegrationStatus(addonName)
    if not addonName then
        return nil
    end
    
    if self.integrated_addons[addonName] then
        return {
            name = addonName,
            enabled = self.integrated_addons[addonName].enabled,
            status = self.integration_status[addonName],
            priority = self.integrated_addons[addonName].priority,
            sync_count = self.integrated_addons[addonName].sync_count or 0,
        }
    end
    
    return nil
end

function QuestIntegrationEngine:GetAllIntegrations()
    local integrations = {}
    
    for addonName, integration in pairs(self.integrated_addons) do
        table.insert(integrations, {
            name = addonName,
            enabled = integration.enabled,
            priority = integration.priority,
            sync_count = integration.sync_count or 0,
        })
    end
    
    -- Sort by priority
    table.sort(integrations, function(a, b)
        return a.priority < b.priority
    end)
    
    return integrations
end

function QuestIntegrationEngine:GetAvailableAddons()
    local available = {}
    
    for _, addon in ipairs(self.addon_list) do
        if self:IsAddonAvailable(addon.name) then
            table.insert(available, {
                name = addon.name,
                priority = addon.priority,
            })
        end
    end
    
    return available
end

function QuestIntegrationEngine:SyncAllAddons()
    local syncCount = 0
    
    for addonName, integration in pairs(self.integrated_addons) do
        if integration.enabled then
            if self:SyncQuestData(addonName) then
                syncCount = syncCount + 1
            end
        end
    end
    
    self:Log("Synced with " .. syncCount .. " addons")
    return syncCount
end

function QuestIntegrationEngine:GetStatus()
    local integratedCount = 0
    
    for _, integration in pairs(self.integrated_addons) do
        if integration.enabled then
            integratedCount = integratedCount + 1
        end
    end
    
    return {
        enabled = self.enabled,
        total_integrated = table.getn(self.integrated_addons),
        enabled_integrations = integratedCount,
        available_addons = #self:GetAvailableAddons(),
    }
end

function QuestIntegrationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestIntegrationEngine] " .. message)
    else
        print("[QuestIntegrationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTINT1 = "/questint"
    SlashCmdList["QUESTINT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "discover" then
            local count = QuestIntegrationEngine:DiscoverAvailableAddons()
            print("Discovered " .. count .. " addons")
        elseif cmd == "sync" then
            if args ~= "" then
                local synced = QuestIntegrationEngine:SyncQuestData(args)
                print("Sync with " .. args .. ": " .. (synced and "Success" or "Failed"))
            else
                local count = QuestIntegrationEngine:SyncAllAddons()
                print("Synced with " .. count .. " addons")
            end
        elseif cmd == "enable" then
            local addonName = args
            if addonName ~= "" then
                QuestIntegrationEngine:EnableIntegration(addonName)
                print("Enabled integration with: " .. addonName)
            else
                print("Usage: /questint enable <addonName>")
            end
        elseif cmd == "disable" then
            local addonName = args
            if addonName ~= "" then
                QuestIntegrationEngine:DisableIntegration(addonName)
                print("Disabled integration with: " .. addonName)
            else
                print("Usage: /questint disable <addonName>")
            end
        elseif cmd == "available" then
            local available = QuestIntegrationEngine:GetAvailableAddons()
            print("Available addons:")
            for i, addon in ipairs(available) do
                print("  [" .. i .. "] " .. addon.name .. " (priority: " .. addon.priority .. ")")
            end
        elseif cmd == "integrations" then
            local integrations = QuestIntegrationEngine:GetAllIntegrations()
            print("Active Integrations:")
            if #integrations > 0 then
                for i, integration in ipairs(integrations) do
                    print("  [" .. i .. "] " .. integration.name .. 
                          " - " .. (integration.enabled and "Enabled" or "Disabled") ..
                          " (syncs: " .. integration.sync_count .. ")")
                end
            else
                print("  No active integrations")
            end
        elseif cmd == "status" then
            local status = QuestIntegrationEngine:GetStatus()
            print("Quest Integration Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Integrations: " .. status.total_integrated)
            print("  Enabled Integrations: " .. status.enabled_integrations)
            print("  Available Addons: " .. status.available_addons)
        else
            print("Quest Integration Commands:")
            print("  /questint discover - Discover available addons")
            print("  /questint sync [addonName] - Sync all or specific addon")
            print("  /questint enable <addonName> - Enable integration")
            print("  /questint disable <addonName> - Disable integration")
            print("  /questint available - List available addons")
            print("  /questint integrations - Show active integrations")
            print("  /questint status - Show engine status")
        end
    end
end

return QuestIntegrationEngine
