-- PluribusGuide Initialization
-- Quest tracking and in-game guide addon

local function InitializeGuide()
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusGuide")
		return
	end
	
	PluribusUtils:Info("PluribusGuide initializing...", "PluribusGuide")
	
	local Quests = PluribusGuideQuests or _G.PluribusGuideQuests
	local Guides = PluribusGuideGuides or _G.PluribusGuideGuides
	local UI = PluribusGuideUI or _G.PluribusGuideUI
	
	if Quests then pcall(function() Quests:Initialize() end) end
	if Guides then pcall(function() Guides:Initialize() end) end
	
	_G.PluribusGuideQuests = Quests
	_G.PluribusGuideGuides = Guides
	_G.PluribusGuideUI = UI
	
	PluribusDataManager:RegisterSource("PluribusGuide", { quests = {}, guides = {} })
	
	PluribusCommandRegistry:RegisterCommand({
		name = "guide",
		aliases = { "plbguide" },
		description = "Open quest guide",
		func = function() PluribusGuideUI:Toggle() end,
	})
	
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_GUIDE_TOGGLE",
		description = "Toggle Guide",
		defaultKey = "ALT-Q",
		action = function() PluribusGuideUI:Toggle() end,
	})
	
	PluribusUtils:Info("PluribusGuide initialized successfully", "PluribusGuide")
	PluribusMessaging:Publish("guide_addon_loaded", { addon = "PluribusGuide" })
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "In-game guides",
			author = "Pluribus Suite Team",
			category = "Guide",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeGuide()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusGuide" then
		if _G.PluribusDataManager then
			InitializeGuide()
		end
	end
end)




