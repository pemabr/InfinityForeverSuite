-- PluribusConsumables Initialization

local ADDON_NAME = "PluribusConsumables"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so PluribusConsumables global is already created

local function InitializeConsumables()
	if not PluribusCore then
		PluribusUtils:Warning("PluribusCore not found, cannot initialize Consumables", ADDON_NAME)
		return
	end
	
	-- Register addon with AddonManager

	
	 if _G.PluribusAddonManager then

	
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Track and manage consumables, potions, and buffs",

	
			author = "Pluribus Suite Team",

	
			category = "Inventory",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Initialize tracker
	if PluribusConsumables then pcall(function() PluribusConsumables:Initialize() end) end
	
	-- Register commands
	PluribusCommandRegistry:RegisterCommand("consumables", function(args)
		local subcommand = string.lower(args[1] or "")
		if subcommand == "scan" then
			PluribusConsumables:ScanInventory()
			PluribusUtils:Info("Inventory scanned", ADDON_NAME)
		elseif subcommand == "list" then
			local consumables = PluribusConsumables:GetAllConsumables()
			PluribusUtils:Info("Consumables in inventory:", ADDON_NAME)
			for _, cons in ipairs(consumables) do
				PluribusUtils:Info("  " .. cons.name .. " x" .. cons.count, ADDON_NAME)
			end
		elseif subcommand == "buffs" then
			local status = PluribusConsumables:GetBuffStatus()
			PluribusUtils:Info("Active buffs: " .. status.activeBuffs, ADDON_NAME)
		end
	end, {"cons", "buff"})
	
	-- Hook into aura events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("UNIT_AURA")
	eventFrame:SetScript("OnEvent", function(self, event, unit)
		if unit == "player" then
			-- Rescan buffs
			PluribusConsumables:ScanInventory()
		end
	end)
	
	PluribusUtils:Info("Consumables addon loaded v" .. ADDON_VERSION, ADDON_NAME)
end

-- Hook into addon loaded and PluribusCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If PluribusCore is already loaded, initialize immediately
		if _G.PluribusCore and _G.PluribusUtils and _G.PluribusCommandRegistry then
			InitializeConsumables()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeConsumables()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeConsumables()
		end
	end)
end


