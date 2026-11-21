-- InfinityConsumables Initialization

local ADDON_NAME = "InfinityConsumables"
local ADDON_VERSION = "1.0.0"

-- Load modules
InfinityConsumables = require(ADDON_NAME .. ".Modules.Tracker")

local function InitializeConsumables()
	if not InfinityCore then
		InfinityUtils:Warning("InfinityCore not found, cannot initialize Consumables", ADDON_NAME)
		return
	end
	
	-- Initialize tracker
	InfinityConsumables:Initialize()
	
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

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == ADDON_NAME then
		if InfinityCore then
			InitializeConsumables()
		else
			C_Timer.After(0.5, InitializeConsumables)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
