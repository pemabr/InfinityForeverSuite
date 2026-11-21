-- InfinityConsumables Initialization

local ADDON_NAME = "InfinityConsumables"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so InfinityConsumables global is already created

local function InitializeConsumables()
	if not InfinityCore then
		InfinityUtils:Warning("InfinityCore not found, cannot initialize Consumables", ADDON_NAME)
		return
	end
	
	-- Register addon with AddonManager

	
	 if _G.InfinityAddonManager then

	
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Track and manage consumables, potions, and buffs",

	
			author = "Infinity Suite Team",

	
			category = "Inventory",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Initialize tracker
	if InfinityConsumables then pcall(function() InfinityConsumables:Initialize() end) end
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("consumables", function(args)
		local subcommand = string.lower(args[1] or "")
		if subcommand == "scan" then
			InfinityConsumables:ScanInventory()
			InfinityUtils:Info("Inventory scanned", ADDON_NAME)
		elseif subcommand == "list" then
			local consumables = InfinityConsumables:GetAllConsumables()
			InfinityUtils:Info("Consumables in inventory:", ADDON_NAME)
			for _, cons in ipairs(consumables) do
				InfinityUtils:Info("  " .. cons.name .. " x" .. cons.count, ADDON_NAME)
			end
		elseif subcommand == "buffs" then
			local status = InfinityConsumables:GetBuffStatus()
			InfinityUtils:Info("Active buffs: " .. status.activeBuffs, ADDON_NAME)
		end
	end, {"cons", "buff"})
	
	-- Hook into aura events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("UNIT_AURA")
	eventFrame:SetScript("OnEvent", function(self, event, unit)
		if unit == "player" then
			-- Rescan buffs
			InfinityConsumables:ScanInventory()
		end
	end)
	
	InfinityUtils:Info("Consumables addon loaded v" .. ADDON_VERSION, ADDON_NAME)
end

-- Hook into addon loaded and InfinityCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If InfinityCore is already loaded, initialize immediately
		if _G.InfinityCore and _G.InfinityUtils and _G.InfinityCommandRegistry then
			InitializeConsumables()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeConsumables()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeConsumables()
		end
	end)
end


