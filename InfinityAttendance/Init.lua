-- InfinityAttendance Initialization
-- Auto-attendance tracking

local addonName = "InfinityAttendance"
local addonVersion = "1.0.0"

-- Wait for dependencies
if not InfinityCore or not InfinityDKPEngine then
    print("InfinityAttendance: Waiting for InfinityCore and InfinityDKP...")
    return
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track member attendance",
			author = "Infinity Suite Team",
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
    local Tracker = InfinityAttendanceTracker or _G.InfinityAttendanceTracker
    local Statistics = InfinityAttendanceStats or _G.InfinityAttendanceStats
    local UI = InfinityAttendanceUI or _G.InfinityAttendanceUI
    
    if not Tracker or not Statistics or not UI then
        print("InfinityAttendance: ERROR - Failed to load modules")
        return
    end
    
    -- Initialize
    if UI.Initialize then
        UI:Initialize()
    end
    
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

