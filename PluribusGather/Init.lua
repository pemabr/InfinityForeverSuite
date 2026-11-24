-- PluribusGather Initialization
-- Gathering and resource tracking addon

local function InitializeGather()
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusGather")
		return
	end
	
	PluribusUtils:Info("PluribusGather initializing...", "PluribusGather")
	
	local Nodes = PluribusGatherNodes or _G.PluribusGatherNodes
	local Routes = PluribusGatherRoutes or _G.PluribusGatherRoutes
	local UI = PluribusGatherUI or _G.PluribusGatherUI
	
	if Nodes then pcall(function() Nodes:Initialize() end) end
	if Routes then pcall(function() Routes:Initialize() end) end
	
	_G.PluribusGatherNodes = Nodes
	_G.PluribusGatherRoutes = Routes
	_G.PluribusGatherUI = UI
	
	PluribusDataManager:RegisterSource("PluribusGather", { nodes = {}, routes = {} })
	
	PluribusCommandRegistry:RegisterCommand({
		name = "gather",
		aliases = { "farm" },
		description = "Open gather manager",
		func = function() PluribusGatherUI:Toggle() end,
	})
	
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_GATHER_TOGGLE",
		description = "Toggle Gather Manager",
		defaultKey = "ALT-H",
		action = function() PluribusGatherUI:Toggle() end,
	})
	
	PluribusUtils:Info("PluribusGather initialized successfully", "PluribusGather")
	PluribusMessaging:Publish("gather_addon_loaded", { addon = "PluribusGather" })
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track gathering",
			author = "Pluribus Suite Team",
			category = "Gathering",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeGather()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusGather" then
		if _G.PluribusDataManager then
			InitializeGather()
		end
	end
end)




