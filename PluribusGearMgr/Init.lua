-- PluribusGearMgr Initialization

local ADDON_NAME = "PluribusGearMgr"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so PluribusGearTracker global is already created

local function InitializeGearManager()
	-- Wait for PluribusCore to be fully loaded
	if not _G.PluribusCore or not _G.PluribusUtils or not _G.PluribusCommandRegistry then
		PluribusUtils:Warning("PluribusCore not fully loaded, deferring initialization", ADDON_NAME)
		C_Timer.After(0.5, InitializeGearManager)
		return
	end
	
	-- Initialize tracker
	if PluribusGearTracker and PluribusGearTracker.Initialize then
		if PluribusGearTracker then pcall(function() PluribusGearTracker:Initialize() end) end
	end
	
	-- Register addon with AddonManager
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage your character's gear, equipment sets, and optimize your build",
			author = "Pluribus Suite Team",
			category = "Gear",
			enabled = true,
			settings = {}
		})
	end
	PluribusCommandRegistry:RegisterCommand("gear", function(args)
		if not args or #args == 0 then
			local stats = PluribusGearTracker:GetStats()
			PluribusUtils:Info("Equipment Summary:", ADDON_NAME)
			PluribusUtils:Info("  Items: " .. stats.totalItems, ADDON_NAME)
			PluribusUtils:Info("  Avg iLevel: " .. stats.averageILevel, ADDON_NAME)
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "scan" then
				PluribusGearTracker:ScanEquipment()
				PluribusUtils:Info("Equipment scanned", ADDON_NAME)
			elseif subcommand == "list" then
				local equipment = PluribusGearTracker:GetAllEquipment()
				PluribusUtils:Info("Current Equipment:", ADDON_NAME)
				for _, item in ipairs(equipment) do
					PluribusUtils:Info("  " .. item.name .. " (iLvl: " .. item.level .. ")", ADDON_NAME)
				end
			elseif subcommand == "upgrades" then
				local upgrades = PluribusGearTracker:GetUpgradeItems()
				if #upgrades > 0 then
					PluribusUtils:Info("Potential Upgrades:", ADDON_NAME)
					for _, item in ipairs(upgrades) do
						PluribusUtils:Info("  " .. item.name .. " (iLvl: " .. item.level .. ")", ADDON_NAME)
					end
				else
					PluribusUtils:Info("No upgrades found", ADDON_NAME)
				end
			elseif subcommand == "export" then
				local export = PluribusGearTracker:ExportGear()
				PluribusUtils:Info("Gear exported for character: " .. export.character.name, ADDON_NAME)
			end
		end
	end, {"equipment", "equip"})
	
	-- Register keybind
	PluribusCommandRegistry:RegisterKeybind("SHOW_GEAR_STATS", "Show Gear Summary", function()
		local stats = PluribusGearTracker:GetStats()
		PluribusUtils:Info("iLevel: " .. stats.averageILevel, ADDON_NAME)
	end)
	
	-- Hook into equipment change events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
	eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "EQUIPMENT_SETS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
			PluribusGearTracker:ScanEquipment()
			PluribusMessaging:Publish("gear_changed", {
				stats = PluribusGearTracker:GetStats(),
			})
		end
	end)
	
	PluribusUtils:Info("Gear Manager addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	PluribusUtils:Info("Use |cff00ccff/gear|r for gear commands", ADDON_NAME)
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
			InitializeGearManager()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeGearManager()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeGearManager()
		end
	end)
end

