-- InfinityQoL Initialization
-- Quality of life improvements and UI tweaks addon

local function InitializeQoL()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityQoL")
		return
	end
	
	InfinityUtils:Info("InfinityQoL initializing...", "InfinityQoL")
	
	local Tweaks = InfinityQoLTweaks or _G.InfinityQoLTweaks
	local Macros = InfinityQoLMacros or _G.InfinityQoLMacros
	local UI = InfinityQoLUI or _G.InfinityQoLUI
	
	if Tweaks then pcall(function() Tweaks:Initialize() end) end
	if Macros then pcall(function() Macros:Initialize() end) end
	
	_G.InfinityQoLTweaks = Tweaks
	_G.InfinityQoLMacros = Macros
	_G.InfinityQoLUI = UI
	
	InfinityDataManager:RegisterSource("InfinityQoL", { tweaks = {}, macros = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "qol",
		aliases = { "tweaks", "settings" },
		description = "Open QoL settings",
		func = function() InfinityQoLUI:Toggle() end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_QOL_TOGGLE",
		description = "Toggle QoL Settings",
		defaultKey = "ALT-T",
		action = function() InfinityQoLUI:Toggle() end,
	})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityQoL", "1.0.0", {
			description = "Quality of Life",
			author = "Infinity Suite Team",
			category = "QoL",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info("InfinityQoL initialized successfully", "InfinityQoL")
	InfinityMessaging:Publish("qol_addon_loaded", { addon = "InfinityQoL" })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeQoL()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityQoL" then
		if _G.InfinityDataManager then
			InitializeQoL()
		end
	end
end)




