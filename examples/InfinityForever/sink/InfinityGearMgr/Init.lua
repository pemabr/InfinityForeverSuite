-- InfinityGearMgr Initialization

local ADDON_NAME = "InfinityGearMgr"
local ADDON_VERSION = "1.0.0"

-- Load modules
InfinityGearTracker = require(ADDON_NAME .. ".Modules.Tracker")

local function InitializeGearManager()
	if not InfinityCore then
		InfinityUtils:Warning("InfinityCore not found, cannot initialize Gear Manager", ADDON_NAME)
		return
	end
	
	-- Initialize tracker
	InfinityGearTracker:Initialize()
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("gear", function(args)
		if not args or #args == 0 then
			local stats = InfinityGearTracker:GetStats()
			InfinityUtils:Info("Equipment Summary:", ADDON_NAME)
			InfinityUtils:Info("  Items: " .. stats.totalItems, ADDON_NAME)
			InfinityUtils:Info("  Avg iLevel: " .. stats.averageILevel, ADDON_NAME)
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "scan" then
				InfinityGearTracker:ScanEquipment()
				InfinityUtils:Info("Equipment scanned", ADDON_NAME)
			elseif subcommand == "list" then
				local equipment = InfinityGearTracker:GetAllEquipment()
				InfinityUtils:Info("Current Equipment:", ADDON_NAME)
				for _, item in ipairs(equipment) do
					InfinityUtils:Info("  " .. item.name .. " (iLvl: " .. item.level .. ")", ADDON_NAME)
				end
			elseif subcommand == "upgrades" then
				local upgrades = InfinityGearTracker:GetUpgradeItems()
				if #upgrades > 0 then
					InfinityUtils:Info("Potential Upgrades:", ADDON_NAME)
					for _, item in ipairs(upgrades) do
						InfinityUtils:Info("  " .. item.name .. " (iLvl: " .. item.level .. ")", ADDON_NAME)
					end
				else
					InfinityUtils:Info("No upgrades found", ADDON_NAME)
				end
			elseif subcommand == "export" then
				local export = InfinityGearTracker:ExportGear()
				InfinityUtils:Info("Gear exported for character: " .. export.character.name, ADDON_NAME)
			end
		end
	end, {"equipment", "equip"})
	
	-- Register keybind
	InfinityCommandRegistry:RegisterKeybind("SHOW_GEAR_STATS", "Show Gear Summary", function()
		local stats = InfinityGearTracker:GetStats()
		InfinityUtils:Info("iLevel: " .. stats.averageILevel, ADDON_NAME)
	end)
	
	-- Hook into equipment change events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
	eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "EQUIPMENT_SETS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
			InfinityGearTracker:ScanEquipment()
			InfinityMessaging:Publish("gear_changed", {
				stats = InfinityGearTracker:GetStats(),
			})
		end
	end)
	
	InfinityUtils:Info("Gear Manager addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	InfinityUtils:Info("Use |cff00ccff/gear|r for gear commands", ADDON_NAME)
end

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == ADDON_NAME then
		if InfinityCore then
			InitializeGearManager()
		else
			C_Timer.After(0.5, InitializeGearManager)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
