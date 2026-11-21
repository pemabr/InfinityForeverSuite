-- InfinityAttendance Initialization
-- Auto-attendance tracking

local addonName = "InfinityAttendance"
local addonVersion = "1.0.0"

-- Wait for dependencies
if not InfinityCore or not InfinityDKPEngine then
    print("InfinityAttendance: Waiting for InfinityCore and InfinityDKP...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local Tracker = require("InfinityAttendance.Modules.Tracker")
    local Statistics = require("InfinityAttendance.Modules.Statistics")
    local UI = require("InfinityAttendance.UI.Main")
    
    -- Make modules global
    _G.InfinityAttendanceTracker = Tracker
    _G.InfinityAttendanceStats = Statistics
    
    -- Initialize
    UI:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Automatic raid attendance tracking and statistics",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/attendance", "Toggle attendance window", function()
            UI:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/attendance start", "Start raid tracking", function()
            Tracker:StartTracking()
            print("Raid attendance tracking started")
        end)
        
        InfinityCore:RegisterCommand("/attendance end", "End raid tracking", function()
            Tracker:EndTracking()
            print("Raid attendance tracking ended")
        end)
        
        InfinityCore:RegisterCommand("/attendance report", "Show attendance report", function()
            local report = Statistics:GetAttendanceReport()
            print(report)
        end)
    end
    
    -- Event handling for automatic tracking
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_START" then
            if Tracker.auto_tracking then
                Tracker:StartTracking(select(2, ...))
            end
        elseif event == "ENCOUNTER_END" then
            if Tracker.auto_tracking then
                Tracker:EndTracking()
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            local raid = Tracker:GetCurrentRaid()
            if raid and Tracker.auto_tracking then
                Tracker:ScanRaid(raid)
            end
        end
    end)
    
    print("InfinityAttendance loaded - Use /attendance for tracking")
end)
