-- InfinityGearMgr Initialization

local ADDON_NAME = "InfinityGearMgr"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so InfinityGearTracker global is already created

local function InitializeGearManager()
	-- Wait for InfinityCore to be fully loaded
	if not _G.InfinityCore or not _G.InfinityUtils or not _G.InfinityCommandRegistry then
		InfinityUtils:Warning("InfinityCore not fully loaded, deferring initialization", ADDON_NAME)
		C_Timer.After(0.5, InitializeGearManager)
		return
	end
	
	-- Initialize tracker
	if InfinityGearTracker and InfinityGearTracker.Initialize then
		if InfinityGearTracker then pcall(function() InfinityGearTracker:Initialize() end) end
	end
	
	-- Register addon with AddonManager
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage your character's gear, equipment sets, and optimize your build",
			author = "Infinity Suite Team",
			category = "Gear",
			enabled = true,
			settings = {}
		})
	end
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
			InitializeGearManager()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeGearManager()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeGearManager()
		end
	end)
end

