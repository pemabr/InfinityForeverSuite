-- PluribusDataCollector Initialization
-- Autonomous data gathering, database integration, and secure P2P sharing

local addonName = "PluribusDataCollector"
local addonVersion = "1.0.0"

local initialized = false
local autoSyncEnabled = true

local function InitializeDataCollector()
	if initialized or not _G.PluribusCore then
		return  -- Will retry when PLURIBUS_DATA_LOADED fires
	end
	initialized = true

	-- Initialize all modules
	if PluribusDataCollectorHooks then pcall(function() PluribusDataCollectorHooks:Initialize() end) end
	PluribusDataCollectorDBIntegration:InitializeDefaultIntegrations()
	PluribusDataCollectorPrivacy:InitializeGuildMemberCache()
	
	-- Make modules global
	_G.PluribusDataCollector = PluribusDataCollectorCore
	_G.PluribusDataCollectorHooks = PluribusDataCollectorHooks
	_G.PluribusDataCollectorPrivacy = PluribusDataCollectorPrivacy
	_G.PluribusDataCollectorNetwork = PluribusDataCollectorNetwork
	_G.PluribusDataCollectorDBIntegration = PluribusDataCollectorDBIntegration
	_G.PluribusDataCollectorUI = PluribusDataCollectorUI
	
	-- Register with PluribusCore
	PluribusCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Pluribus",
		description = "Autonomous standalone data gathering, optional DB integration, and P2P sharing",
		enabled = true,
	})
	
	-- Register slash commands
	if PluribusCore.RegisterCommand then
		PluribusCore:RegisterCommand("/datacollector", "Open Data Collector window", function()
			PluribusDataCollectorUI:Toggle()
		end)
		
		PluribusCore:RegisterCommand("/datacollector stats", "Show data gathering statistics", function()
			PluribusDataCollectorUI:Show()
			PluribusDataCollectorUI:ShowTab("stats")
		end)
		
		PluribusCore:RegisterCommand("/datacollector settings", "Open data collector settings", function()
			PluribusDataCollectorUI:Show()
			PluribusDataCollectorUI:ShowTab("settings")
		end)
		
		PluribusCore:RegisterCommand("/datacollector network", "Show network status", function()
			PluribusDataCollectorUI:Show()
			PluribusDataCollectorUI:ShowTab("network")
		end)
		
		PluribusCore:RegisterCommand("/datacollector sync", "Sync native game data and optional external DBs", function()
			local results = PluribusDataCollectorDBIntegration:SyncAll()
			if #results == 0 then
				print("|cff00ccff[PluribusDataCollector]|r Standalone native gathering active (no optional external DBs installed).")
				return
			end
			for _, result in ipairs(results) do
				if result.success then
					print("|cff4ade80[PluribusDataCollector]|r Synced: " .. result.name)
				else
					print("|cff94a3b8[PluribusDataCollector]|r Skipped optional DB: " .. result.name)
				end
			end
		end)
		
		PluribusCore:RegisterCommand("/datacollector autosync", "Toggle auto-sync", function()
			autoSyncEnabled = not autoSyncEnabled
			print("|cff00ccff[PluribusDataCollector]|r Auto-sync " .. (autoSyncEnabled and "ENABLED" or "DISABLED"))
		end)
	end
	
	-- Setup throttled periodic data gathering and sharing (every 30s, never every frame)
	local updateFrame = CreateFrame("Frame")
	local syncElapsed = 0
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		syncElapsed = syncElapsed + (elapsed or 0)
		if syncElapsed < 30 then return end
		syncElapsed = 0

		if autoSyncEnabled then
			PluribusDataCollectorDBIntegration:AutoSync()
			PluribusDataCollectorNetwork:AutoShareData()
			PluribusDataCollectorNetwork:CleanupRequests()
		end
	end)
	
	-- Hook into guild events and late-loaded optional databases
	local guildFrame = CreateFrame("Frame")
	pcall(guildFrame.RegisterEvent, guildFrame, "GUILD_ROSTER_UPDATE")
	pcall(guildFrame.RegisterEvent, guildFrame, "PLAYER_ENTERING_WORLD")
	pcall(guildFrame.RegisterEvent, guildFrame, "ADDON_LOADED")
	guildFrame:SetScript("OnEvent", function(self, event, loadedAddon)
		if event == "GUILD_ROSTER_UPDATE" then
			PluribusDataCollectorPrivacy:RefreshGuildCache()
		elseif event == "PLAYER_ENTERING_WORLD" then
			PluribusDataCollectorDBIntegration:RefreshAvailability()
			pcall(function() PluribusDataCollectorHooks:GatherQuestLogData() end)
		elseif event == "ADDON_LOADED" and (
			loadedAddon == "Questie" or loadedAddon == "QuestieDB" or
			loadedAddon == "WowHeadDB" or loadedAddon == "WoWHeadDB" or
			loadedAddon == "GathererDB" or loadedAddon == "GatherMate2"
		) then
			PluribusDataCollectorDBIntegration:RefreshAvailability()
		end
	end)
	
	-- Register data sharing via messaging system
	if PluribusMessaging then
		PluribusMessaging:Subscribe("DataCollector:RequestData", function(requestID, fromPlayer, dataTypes)
			PluribusDataCollectorNetwork:HandleDataRequest(requestID, fromPlayer, dataTypes)
		end, 5)
		
		PluribusMessaging:Subscribe("DataCollector:DataResponse", function(requestID, responseData)
			PluribusDataCollectorNetwork:HandleDataResponse(requestID, responseData)
		end, 5)
	end
	
	-- Start standalone autonomous gathering + initial quest log scan
	PluribusDataCollectorHooks:Start()
	pcall(function() PluribusDataCollectorHooks:GatherQuestLogData() end)
	
	local stats = PluribusDataCollectorCore:GetStatistics()
	PluribusUtils:Info(
		string.format("PluribusDataCollector standalone active (%d quests, %d mobs, %d nodes) — /datacollector",
			stats.questCount or 0, stats.mobCount or 0, stats.nodeCount or 0),
		"DataCollector"
	)
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Collect game data",
			author = "Pluribus Suite Team",
			category = "Core",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		-- If PluribusCore is already loaded, initialize immediately
		if _G.PluribusCore then
			InitializeDataCollector()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeDataCollector()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeDataCollector()
		end
	end)
end


