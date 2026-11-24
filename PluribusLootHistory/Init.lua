-- PluribusLootHistory Initialization

local ADDON_NAME = "PluribusLootHistory"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so PluribusLootHistory global is already created

local function InitializeLootHistory()
	-- Wait for PluribusCore to be fully loaded
	if not _G.PluribusCore or not _G.PluribusUtils or not _G.PluribusCommandRegistry then
		if _G.PluribusUtils then
			PluribusUtils:Warning("PluribusCore not fully loaded, deferring initialization", ADDON_NAME)
		end
		C_Timer.After(0.5, InitializeLootHistory)
		return
	end
	
	-- Initialize tracker
	if PluribusLootHistory and PluribusLootHistory.Initialize then
		if PluribusLootHistory then pcall(function() PluribusLootHistory:Initialize() end) end
	end
	
	-- Register addon with AddonManager

	
	 if _G.PluribusAddonManager then

	
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Track loot drops and distribution history",

	
			author = "Pluribus Suite Team",

	
			category = "Loot",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Register commands
	PluribusCommandRegistry:RegisterCommand("loothistory", function(args)
		local subcommand = string.lower(args[1] or "")
		if subcommand == "stats" then
			local stats = PluribusLootHistory:GetLootStats()
			PluribusUtils:Info("Loot Statistics:", ADDON_NAME)
			PluribusUtils:Info("Total items looted: " .. stats.totalItems, ADDON_NAME)
			PluribusUtils:Info("Players with loot: " .. stats.totalPlayers, ADDON_NAME)
		elseif subcommand == "clear" then
			PluribusLootHistory.lootLog = {}
			PluribusUtils:Info("Loot history cleared", ADDON_NAME)
		end
	end, {"lh", "lootlog"})
	
	PluribusUtils:Info("Loot History addon loaded v" .. ADDON_VERSION, ADDON_NAME)
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
			InitializeLootHistory()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeLootHistory()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeLootHistory()
		end
	end)
end


