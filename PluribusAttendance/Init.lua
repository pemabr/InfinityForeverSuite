-- PluribusAttendance Initialization
-- Auto-attendance tracking

local addonName = "PluribusAttendance"
local addonVersion = "1.0.0"

-- Wait for dependencies
if not PluribusCore or not PluribusDKPEngine then
    print("PluribusAttendance: Waiting for PluribusCore and PluribusDKP...")
    return
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track member attendance",
			author = "Pluribus Suite Team",
			category = "Guild",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Modules are loaded via .toc file, so globals are already created
    -- Use the globals that were created by the module files
    local Tracker = PluribusAttendanceTracker or _G.PluribusAttendanceTracker
    local Statistics = PluribusAttendanceStats or _G.PluribusAttendanceStats
    local UI = PluribusAttendanceUI or _G.PluribusAttendanceUI
    
    if not Tracker or not Statistics or not UI then
        print("PluribusAttendance: ERROR - Failed to load modules")
        return
    end
    
    -- Initialize
    if UI.Initialize then
        UI:Initialize()
    end
    
    -- Register with PluribusCore
    PluribusCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Pluribus",
        description = "Automatic raid attendance tracking and statistics",
        enabled = true,
    })
    
    -- Command registration
    if PluribusCore.RegisterCommand then
        PluribusCore:RegisterCommand("/attendance", "Toggle attendance window", function()
            UI:Toggle()
        end)
        
        PluribusCore:RegisterCommand("/attendance start", "Start raid tracking", function()
            Tracker:StartTracking()
            print("Raid attendance tracking started")
        end)
        
        PluribusCore:RegisterCommand("/attendance end", "End raid tracking", function()
            Tracker:EndTracking()
            print("Raid attendance tracking ended")
        end)
        
        PluribusCore:RegisterCommand("/attendance report", "Show attendance report", function()
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
    
    print("PluribusAttendance loaded - Use /attendance for tracking")
end)

