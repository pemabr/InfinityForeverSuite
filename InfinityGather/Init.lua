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
	
	_G.InfinityGatherNodes = Nodes
	_G.InfinityGatherRoutes = Routes
	_G.InfinityGatherUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGather", { nodes = {}, routes = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "gather",
		aliases = { "farm" },
		description = "Open gather manager",
		func = function() InfinityGatherUI:Toggle() end,
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
		end
	end
end)




