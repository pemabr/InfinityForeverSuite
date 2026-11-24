-- PluribusQoL Initialization
-- Quality of life improvements and UI tweaks addon

local function InitializeQoL()
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusQoL")
		return
	end
	
	PluribusUtils:Info("PluribusQoL initializing...", "PluribusQoL")
	
	local Tweaks = PluribusQoLTweaks or _G.PluribusQoLTweaks
	local Macros = PluribusQoLMacros or _G.PluribusQoLMacros
	local UI = PluribusQoLUI or _G.PluribusQoLUI
	
	if Tweaks then pcall(function() Tweaks:Initialize() end) end
	if Macros then pcall(function() Macros:Initialize() end) end
	
	_G.PluribusQoLTweaks = Tweaks
	_G.PluribusQoLMacros = Macros
	_G.PluribusQoLUI = UI
	
	PluribusDataManager:RegisterSource("PluribusQoL", { tweaks = {}, macros = {} })
	
	PluribusCommandRegistry:RegisterCommand({
		name = "qol",
		aliases = { "tweaks", "settings" },
		description = "Open QoL settings",
		func = function() PluribusQoLUI:Toggle() end,
	})
	
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_QOL_TOGGLE",
		description = "Toggle QoL Settings",
		defaultKey = "ALT-T",
		action = function() PluribusQoLUI:Toggle() end,
	})
	
	PluribusUtils:Info("PluribusQoL initialized successfully", "PluribusQoL")
	PluribusMessaging:Publish("qol_addon_loaded", { addon = "PluribusQoL" })
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Quality of Life",
			author = "Pluribus Suite Team",
			category = "QoL",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeQoL()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusQoL" then
		if _G.PluribusDataManager then
			InitializeQoL()
		end
	end
end)




