-- InfinityRaid Initialization
-- Raid management addon with encounter tracking and assignments

local function InitializeRaid()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityRaid")
		return
	end
	
	InfinityUtils:Info("InfinityRaid initializing...", "InfinityRaid")
	
	local Encounters = InfinityRaidEncounters or _G.InfinityRaidEncounters
	local Assignments = InfinityRaidAssignments or _G.InfinityRaidAssignments
	local UI = InfinityRaidUI or _G.InfinityRaidUI
	
	if Encounters then pcall(function() Encounters:Initialize() end) end
	if Assignments then pcall(function() Assignments:Initialize() end) end
	
	_G.InfinityRaidEncounters = Encounters
	_G.InfinityRaidAssignments = Assignments
	_G.InfinityRaidUI = UI
	
	InfinityDataManager:RegisterSource("InfinityRaid", { encounters = {}, assignments = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "raid",
		aliases = { "r" },
		description = "Open raid manager",
		func = function()
			InfinityRaidUI:Toggle()
		end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_RAID_TOGGLE",
		description = "Toggle Raid Manager",
		defaultKey = "ALT-R",
		action = function()
			InfinityRaidUI:Toggle()
		end,
	})
	
	InfinityUtils:Info("InfinityRaid initialized successfully", "InfinityRaid")
	InfinityMessaging:Publish("raid_addon_loaded", { addon = "InfinityRaid" })
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Raid management",
			author = "Infinity Suite Team",
			category = "Raid",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeRaid()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityRaid" then
		if _G.InfinityDataManager then
			InitializeRaid()
		end
	end
end)




