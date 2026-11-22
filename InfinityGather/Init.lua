-- InfinityGather Initialization
-- Gathering and resource tracking addon

local function InitializeGather()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGather")
		return
	end
	
	InfinityUtils:Info("InfinityGather initializing...", "InfinityGather")
	
	local Nodes = InfinityGatherNodes or _G.InfinityGatherNodes
	local Routes = InfinityGatherRoutes or _G.InfinityGatherRoutes
	local UI = InfinityGatherUI or _G.InfinityGatherUI
	
	if Nodes then pcall(function() Nodes:Initialize() end) end
	if Routes then pcall(function() Routes:Initialize() end) end
	if UI and UI.Initialize then UI:Initialize() end
	if _G.InfinityGatherMateSource then InfinityGatherMateSource:Initialize() end
	
	_G.InfinityGatherNodes = Nodes
	_G.InfinityGatherRoutes = Routes
	_G.InfinityGatherUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGather", { nodes = {}, routes = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "gather",
		aliases = { "farm" },
		description = "Open gather manager",
		func = function(args)
			if not args or not args[1] or args[1] == "" then
				InfinityGatherUI:Toggle()
			elseif args[1] == "source" and (args[2] == "on" or args[2] == "off") and not args[3] then
				InfinityGatherMateSource:SetEnabled(args[2] == "on")
			elseif args[1] == "source" and args[2] == "status" and not args[3] then
				print("GatherMate2 live source: " .. InfinityGatherMateSource.choice
					.. (InfinityGatherMateSource:Available() and " (available)" or " (unavailable)"))
			else
				InfinityUtils:Warning("Usage: /gather [source on|off|status]", "Gather")
			end
		end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GATHER_TOGGLE",
		description = "Toggle Gather Manager",
		defaultKey = "ALT-H",
		action = function() InfinityGatherUI:Toggle() end,
	})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityGather", "1.0.0", {
			description = "Track gathering",
			author = "Infinity Suite Team",
			category = "Gathering",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info("InfinityGather initialized successfully", "InfinityGather")
	InfinityMessaging:Publish("gather_addon_loaded", { addon = "InfinityGather" })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeGather()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityGather" then
		if _G.InfinityDataManager then
			InitializeGather()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)




