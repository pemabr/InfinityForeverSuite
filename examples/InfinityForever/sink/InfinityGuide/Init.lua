-- InfinityGuide Initialization
-- Quest tracking and in-game guide addon

local function InitializeGuide()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGuide")
		return
	end
	
	InfinityUtils:Info("InfinityGuide initializing...", "InfinityGuide")
	
	local Quests = require("InfinityGuide.Modules.Quests")
	local Guides = require("InfinityGuide.Modules.Guides")
	local UI = require("InfinityGuide.UI.MainUI")
	
	Quests:Initialize()
	Guides:Initialize()
	
	_G.InfinityGuideQuests = Quests
	_G.InfinityGuideGuides = Guides
	_G.InfinityGuideUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGuide", { quests = {}, guides = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "guide",
		aliases = { "quest", "q" },
		description = "Open quest guide",
		func = function() InfinityGuideUI:Toggle() end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GUIDE_TOGGLE",
		description = "Toggle Guide",
		defaultKey = "ALT-Q",
		action = function() InfinityGuideUI:Toggle() end,
	})
	
	InfinityUtils:Info("InfinityGuide initialized successfully", "InfinityGuide")
	InfinityMessaging:Publish("guide_addon_loaded", { addon = "InfinityGuide" })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeGuide()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityGuide" then
		if _G.InfinityDataManager then
			InitializeGuide()
		end
	end
end)


