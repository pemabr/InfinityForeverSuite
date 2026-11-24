-- PluribusRaid Initialization
-- Raid management addon with encounter tracking and assignments

local function InitializeRaid()
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusRaid")
		return
	end
	
	PluribusUtils:Info("PluribusRaid initializing...", "PluribusRaid")
	
	local Encounters = PluribusRaidEncounters or _G.PluribusRaidEncounters
	local Assignments = PluribusRaidAssignments or _G.PluribusRaidAssignments
	local UI = PluribusRaidUI or _G.PluribusRaidUI
	
	if Encounters then pcall(function() Encounters:Initialize() end) end
	if Assignments then pcall(function() Assignments:Initialize() end) end
	
	_G.PluribusRaidEncounters = Encounters
	_G.PluribusRaidAssignments = Assignments
	_G.PluribusRaidUI = UI
	
	PluribusDataManager:RegisterSource("PluribusRaid", { encounters = {}, assignments = {} })
	
	PluribusCommandRegistry:RegisterCommand({
		name = "raid",
		aliases = { "r" },
		description = "Open raid manager",
		func = function()
			PluribusRaidUI:Toggle()
		end,
	})
	
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_RAID_TOGGLE",
		description = "Toggle Raid Manager",
		defaultKey = "ALT-R",
		action = function()
			PluribusRaidUI:Toggle()
		end,
	})
	
	PluribusUtils:Info("PluribusRaid initialized successfully", "PluribusRaid")
	PluribusMessaging:Publish("raid_addon_loaded", { addon = "PluribusRaid" })
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Raid management",
			author = "Pluribus Suite Team",
			category = "Raid",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeRaid()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusRaid" then
		if _G.PluribusDataManager then
			InitializeRaid()
		end
	end
end)




