-- InfinityGear Initialization
-- Gear management and equipment tracking addon

local function InitializeGear()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGear")
		return
	end
	
	InfinityUtils:Info("InfinityGear initializing...", "InfinityGear")
	
	local Equipment = require("InfinityGear.Modules.Equipment")
	local Consumables = require("InfinityGear.Modules.Consumables")
	local UI = require("InfinityGear.UI.MainUI")
	
	Equipment:Initialize()
	Consumables:Initialize()
	
	_G.InfinityGearEquipment = Equipment
	_G.InfinityGearConsumables = Consumables
	_G.InfinityGearUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGear", { equipment = {}, consumables = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "gear",
		aliases = { "equipment", "e" },
		description = "Open gear manager",
		func = function() InfinityGearUI:Toggle() end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GEAR_TOGGLE",
		description = "Toggle Gear Manager",
		defaultKey = "ALT-E",
		action = function() InfinityGearUI:Toggle() end,
	})
	
	InfinityUtils:Info("InfinityGear initialized successfully", "InfinityGear")
	InfinityMessaging:Publish("gear_addon_loaded", { addon = "InfinityGear" })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeGear()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityGear" then
		if _G.InfinityDataManager then
			InitializeGear()
		end
	end
end)


