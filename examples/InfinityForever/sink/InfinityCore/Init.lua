-- InfinityCore Initialization
-- Main addon entry point

local function InitializeInfinityCore()
	-- Initialize utilities first
	_G.InfinityUtils = InfinityUtils
	
	-- Initialize storage
	InfinityStorageManager:Initialize(InfinityCoreDB)
	_G.InfinityStorageManager = InfinityStorageManager
	_G.InfinityCoreDB = InfinityCoreDB
	
	-- Initialize core managers
	_G.InfinityDataManager = InfinityDataManager
	_G.InfinityMessaging = InfinityMessaging
	_G.InfinityEventRouter = InfinityEventRouter
	_G.InfinityCommandRegistry = InfinityCommandRegistry
	_G.InfinityUIFramework = InfinityUIFramework
	_G.InfinityMainFrame = InfinityMainFrame
	
	-- Initialize character manager
	local CharacterManager = require("InfinityCore.Core.CharacterManager")
	CharacterManager:Initialize()
	_G.InfinityCharacterManager = CharacterManager
	
	-- Initialize event router
	InfinityEventRouter:Initialize()
	
	-- Initialize UI framework
	InfinityUIFramework:Initialize()
	
	-- Initialize data collection and sharing modules
	InfinityDataCollector:Initialize()
	InfinityDataSanitizer:Initialize()
	InfinityQuestieDBIntegration:Initialize()
	
	-- Register core commands
	InfinityCommandRegistry:RegisterCommand("infinity", function(args, msg)
		if not args or #args == 0 then
			InfinityMainFrame:Toggle()
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "toggle" then
				InfinityMainFrame:Toggle()
			elseif subcommand == "debug" then
				InfinityUtils:Info("=== Infinity Suite Debug Info ===", "Core")
				
				local dataStats = InfinityDataManager:GetStatistics()
				InfinityUtils:Info("Data Sources: " .. dataStats.enabledSources .. "/" .. dataStats.totalSources, "Core")
				InfinityUtils:Info("Cached Data Points: " .. dataStats.totalDataPoints, "Core")
				
				local eventStats = InfinityEventRouter:GetStatistics()
				InfinityUtils:Info("WoW Events: " .. eventStats.registeredEvents, "Core")
				InfinityUtils:Info("Event Listeners: " .. eventStats.activeListeners .. "/" .. eventStats.totalListeners, "Core")
				
				local cmdStats = InfinityCommandRegistry:GetStatistics()
				InfinityUtils:Info("Commands: " .. cmdStats.commandCount, "Core")
				InfinityUtils:Info("Keybinds: " .. cmdStats.keybindCount, "Core")
				
				local charStats = InfinityCharacterManager:GetCharacterStats()
				InfinityUtils:Info("Characters: " .. charStats.totalCharacters .. " (" .. charStats.mains .. " mains, " .. charStats.twinks .. " twinks)", "Core")
			elseif subcommand == "help" then
				InfinityUtils:Info("/infinity - Toggle main window", "Core")
				InfinityUtils:Info("/infinity toggle - Toggle main window", "Core")
				InfinityUtils:Info("/infinity debug - Show debug information", "Core")
				InfinityUtils:Info("/infinity help - Show this help text", "Core")
			elseif subcommand == "chars" then
				local currentChar = InfinityCharacterManager:GetCurrentCharacter()
				InfinityUtils:Info("Current: " .. currentChar.name .. " (Level " .. currentChar.level .. " " .. currentChar.class .. ")", "Core")
				
				if currentChar.isMain then
					local twinks = InfinityCharacterManager:GetTwinks(currentChar.name)
					if #twinks > 0 then
						InfinityUtils:Info("Twinks:", "Core")
						for _, twink in ipairs(twinks) do
							InfinityUtils:Info("  - " .. twink.name .. " (Level " .. twink.level .. " " .. twink.class .. ")", "Core")
						end
					end
				elseif currentChar.linkedTo then
					InfinityUtils:Info("Linked to main: " .. currentChar.linkedTo, "Core")
				end
			elseif subcommand == "data" then
				InfinityDataCollector:DisplayStats()
			elseif subcommand == "sanitize" then
				InfinityDataSanitizer:DisplayStatus()
			elseif subcommand == "questie" then
				InfinityQuestieDBIntegration:DisplayStatus()
			end
		end
	end, {"inf", "suite"})
	
	-- Register core keybinds
	InfinityCommandRegistry:RegisterKeybind("TOGGLE_MAIN_WINDOW", "Toggle Infinity Suite", function()
		InfinityMainFrame:Toggle()
	end)
	
	InfinityUtils:Info(INFINITY_COLORS.PRIMARY .. "Infinity Suite v" .. INFINITY_SUITE_VERSION .. " loaded successfully!" .. INFINITY_COLORS.RESET, "Core")
	InfinityUtils:Info("Use |cff00ccff/infinity|r to open the main window", "Core")
	InfinityUtils:Info("Use |cff00ccff/infinity chars|r to see your character links", "Core")
	InfinityUtils:Info("Use |cff00ccff/infinity data|r to see data collection stats", "Core")
	
	-- Trigger data loaded event
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_LOADED)
end

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == INFINITY_CORE_NAME then
		InitializeInfinityCore()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
