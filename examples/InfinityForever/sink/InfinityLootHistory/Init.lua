-- InfinityLootHistory Initialization

local ADDON_NAME = "InfinityLootHistory"
local ADDON_VERSION = "1.0.0"

-- Load modules
InfinityLootHistory = require(ADDON_NAME .. ".Modules.Tracker")

local function InitializeLootHistory()
	if not InfinityCore then
		InfinityUtils:Warning("InfinityCore not found, cannot initialize Loot History", ADDON_NAME)
		return
	end
	
	-- Initialize tracker
	InfinityLootHistory:Initialize()
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("loothistory", function(args)
		local subcommand = string.lower(args[1] or "")
		if subcommand == "stats" then
			local stats = InfinityLootHistory:GetLootStats()
			InfinityUtils:Info("Loot Statistics:", ADDON_NAME)
			InfinityUtils:Info("Total items looted: " .. stats.totalItems, ADDON_NAME)
			InfinityUtils:Info("Players with loot: " .. stats.totalPlayers, ADDON_NAME)
		elseif subcommand == "clear" then
			InfinityLootHistory.lootLog = {}
			InfinityUtils:Info("Loot history cleared", ADDON_NAME)
		end
	end, {"lh", "lootlog"})
	
	InfinityUtils:Info("Loot History addon loaded v" .. ADDON_VERSION, ADDON_NAME)
end

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == ADDON_NAME then
		if InfinityCore then
			InitializeLootHistory()
		else
			C_Timer.After(0.5, InitializeLootHistory)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
