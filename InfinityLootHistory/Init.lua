-- InfinityLootHistory Initialization

local ADDON_NAME = "InfinityLootHistory"
local ADDON_VERSION = "1.0.0"

local InfinityLootHistory

local function InitializeLootHistory()
	-- Wait for InfinityCore to be fully loaded
	if not _G.InfinityCore or not _G.InfinityUtils or not _G.InfinityCommandRegistry then
		if _G.InfinityUtils then
			InfinityUtils:Warning("InfinityCore not fully loaded, deferring initialization", ADDON_NAME)
		end
		C_Timer.After(0.5, InitializeLootHistory)
		return
	end
	InfinityLootHistory = _G.InfinityLootHistoryTracker
	if not InfinityLootHistory then
		InfinityUtils:Error("Loot history tracker unavailable.", ADDON_NAME)
		return
	end
	
	-- Initialize tracker
	if InfinityLootHistory and InfinityLootHistory.Initialize then
		if InfinityLootHistory then pcall(function() InfinityLootHistory:Initialize() end) end
	end
	
	-- Register addon with AddonManager

	
	 if _G.InfinityAddonManager then

	
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Track loot drops and distribution history",

	
			author = "Infinity Suite Team",

	
			category = "Loot",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("lootlog", function(args)
		local subcommand = string.lower(args[1] or "")
		if subcommand == "stats" then
			local stats = InfinityLootHistory:GetLootStats()
			InfinityUtils:Info("Loot Statistics:", ADDON_NAME)
			InfinityUtils:Info("Total items looted: " .. stats.totalItems, ADDON_NAME)
			InfinityUtils:Info("Players with loot: " .. stats.totalPlayers, ADDON_NAME)
		elseif subcommand == "clear" then
			InfinityLootHistory:Clear()
			InfinityUtils:Info("Loot history cleared", ADDON_NAME)
		end
	end, {})
	
	InfinityUtils:Info("Loot History addon loaded v" .. ADDON_VERSION, ADDON_NAME)
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
			InitializeLootHistory()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeLootHistory()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeLootHistory()
		end
	end)
end


