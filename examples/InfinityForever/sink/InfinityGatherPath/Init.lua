-- InfinityGatherPath Initialization
-- Gathering optimization and node database

local addonName = "InfinityGatherPath"
local addonVersion = "1.0.0"

if not InfinityCore then
    print("InfinityGatherPath: Waiting for InfinityCore...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local NodeDB = require("InfinityGatherPath.Core.NodeDatabase")
    local Routes = require("InfinityGatherPath.Modules.Routes")
    local Optimization = require("InfinityGatherPath.Modules.Optimization")
    local NodeMarkers = require("InfinityGatherPath.Modules.NodeMarkers")
    local UI = require("InfinityGatherPath.UI.Main")
    
    -- Make modules global
    _G.InfinityNodeDB = NodeDB
    _G.InfinityRoutes = Routes
    _G.InfinityOptimization = Optimization
    _G.InfinityNodeMarkers = NodeMarkers
    
    -- Initialize
    UI:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Gathering routes, optimization, and node database (GatherPath replacement)",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/gatherpath", "Toggle GatherPath window", function()
            UI:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/gatherpath record", "Record current node", function()
            local zone = GetRealZoneText()
            if zone then
                local x, y = GetPlayerMapPosition("player")
                if x and y then
                    NodeDB:RecordNode("herb", x * 100, y * 100, zone, 300)
                    print("Node recorded in " .. zone)
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/gatherpath optimize", "Optimize current route", function()
            local zone = GetRealZoneText()
            if zone then
                local nodes = NodeDB:GetNodesByZone(zone)
                if #nodes > 0 then
                    local optimized = Optimization:OptimizeRoute(nodes)
                    local distance = Optimization:CalculateTotalDistance(optimized)
                    print(string.format("Route optimized: %d nodes, %.0f yards", #optimized, distance))
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/gatherpath nodes", "Show node count", function()
            print("Total nodes recorded: " .. NodeDB:GetNodeCount())
        end)
    end
    
    -- Event handling for gathering
    local gatherFrame = CreateFrame("Frame")
    gatherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    gatherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    
    gatherFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_REGEN_ENABLED" then
            -- Out of combat - safe to record nodes
            UI:Update()
        end
    end)
    
    print("InfinityGatherPath loaded - Use /gatherpath for route management")
end)
