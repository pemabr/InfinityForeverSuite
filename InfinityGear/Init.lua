-- InfinityGear Initialization
-- Gear management and equipment tracking addon

local function InitializeGear()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGear")
		return
	end
	
	InfinityUtils:Info("InfinityGear initializing...", "InfinityGear")
	
	local Equipment = InfinityGearEquipment or _G.InfinityGearEquipment
	local Consumables = InfinityGearConsumables or _G.InfinityGearConsumables
	local UI = InfinityGearUI or _G.InfinityGearUI
	
	if Equipment then pcall(function() Equipment:Initialize() end) end
	if Consumables then pcall(function() Consumables:Initialize() end) end
	if UI and UI.Initialize then UI:Initialize() end
	
	_G.InfinityGearEquipment = Equipment
	_G.InfinityGearConsumables = Consumables
	_G.InfinityGearUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGear", { equipment = {}, consumables = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "infgear",
		aliases = {},
		description = "Open gear manager",
		func = function() InfinityGearUI:Toggle() end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GEAR_TOGGLE",
		description = "Toggle Gear Manager",
		defaultKey = "ALT-E",
		action = function() InfinityGearUI:Toggle() end,
	})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityGear", "1.1.0", {
			description = "Manage gear",
			author = "Infinity Suite Team",
			category = "Gear",
			enabled = true,
			settings = {}
		})
	end
	
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
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)




