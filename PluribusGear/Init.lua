-- PluribusGear Initialization
-- Gear management and equipment tracking addon

local function InitializeGear()
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusGear")
		return
	end
	
	PluribusUtils:Info("PluribusGear initializing...", "PluribusGear")
	
	local Equipment = PluribusGearEquipment or _G.PluribusGearEquipment
	local Consumables = PluribusGearConsumables or _G.PluribusGearConsumables
	local UI = PluribusGearUI or _G.PluribusGearUI
	
	if Equipment then pcall(function() Equipment:Initialize() end) end
	if Consumables then pcall(function() Consumables:Initialize() end) end
	
	_G.PluribusGearEquipment = Equipment
	_G.PluribusGearConsumables = Consumables
	_G.PluribusGearUI = UI
	
	PluribusDataManager:RegisterSource("PluribusGear", { equipment = {}, consumables = {} })
	
	PluribusCommandRegistry:RegisterCommand({
		name = "gear",
		aliases = { "equipment", "plbgear" },
		description = "Open gear advisor",
		func = function() PluribusGearUI:Toggle() end,
	})
	
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_GEAR_TOGGLE",
		description = "Toggle Gear Manager",
		defaultKey = "ALT-E",
		action = function() PluribusGearUI:Toggle() end,
	})
	
	PluribusUtils:Info("PluribusGear initialized successfully", "PluribusGear")
	PluribusMessaging:Publish("gear_addon_loaded", { addon = "PluribusGear" })
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage gear",
			author = "Pluribus Suite Team",
			category = "Gear",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeGear()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusGear" then
		if _G.PluribusDataManager then
			InitializeGear()
		end
	end
end)




