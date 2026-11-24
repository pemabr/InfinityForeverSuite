-- InfinityDataCollector Initialization
-- Autonomous data gathering, database integration, and secure P2P sharing

local addonName = "InfinityDataCollector"
local addonVersion = "1.0.0"

local initialized = false
local autoSyncEnabled = true

local function InitializeDataCollector()
	if initialized or not _G.InfinityCore then
		return  -- Will retry when INFINITY_DATA_LOADED fires
	end
	initialized = true

	-- Initialize all modules
	if InfinityDataCollectorHooks then pcall(function() InfinityDataCollectorHooks:Initialize() end) end
	InfinityDataCollectorDBIntegration:InitializeDefaultIntegrations()
	InfinityDataCollectorPrivacy:InitializeGuildMemberCache()
	
	-- Make modules global
	_G.InfinityDataCollector = InfinityDataCollectorCore
	_G.InfinityDataCollectorHooks = InfinityDataCollectorHooks
	_G.InfinityDataCollectorPrivacy = InfinityDataCollectorPrivacy
	_G.InfinityDataCollectorNetwork = InfinityDataCollectorNetwork
	_G.InfinityDataCollectorDBIntegration = InfinityDataCollectorDBIntegration
	_G.InfinityDataCollectorUI = InfinityDataCollectorUI
	
	-- Register with InfinityCore
	InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Autonomous standalone data gathering, optional DB integration, and P2P sharing",
		enabled = true,
	})
	
	-- Register slash commands
	if InfinityCore.RegisterCommand then
		InfinityCore:RegisterCommand("/datacollector", "Open Data Collector window", function()
			InfinityDataCollectorUI:Toggle()
		end)
		
		InfinityCore:RegisterCommand("/datacollector stats", "Show data gathering statistics", function()
			InfinityDataCollectorUI:Show()
			InfinityDataCollectorUI:ShowTab("stats")
		end)
		
		InfinityCore:RegisterCommand("/datacollector settings", "Open data collector settings", function()
			InfinityDataCollectorUI:Show()
			InfinityDataCollectorUI:ShowTab("settings")
		end)
		
		InfinityCore:RegisterCommand("/datacollector network", "Show network status", function()
			InfinityDataCollectorUI:Show()
			InfinityDataCollectorUI:ShowTab("network")
		end)
		
		InfinityCore:RegisterCommand("/datacollector sync", "Sync native game data and optional external DBs", function()
			local results = InfinityDataCollectorDBIntegration:SyncAll()
			if #results == 0 then
				print("|cff00ccff[InfinityDataCollector]|r Standalone native gathering active (no optional external DBs installed).")
				return
			end
			for _, result in ipairs(results) do
				if result.success then
					print("|cff4ade80[InfinityDataCollector]|r Synced: " .. result.name)
				else
					print("|cff94a3b8[InfinityDataCollector]|r Skipped optional DB: " .. result.name)
				end
			end
		end)
		
		InfinityCore:RegisterCommand("/datacollector autosync", "Toggle auto-sync", function()
			autoSyncEnabled = not autoSyncEnabled
			print("|cff00ccff[InfinityDataCollector]|r Auto-sync " .. (autoSyncEnabled and "ENABLED" or "DISABLED"))
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
			InfinityDataCollectorDBIntegration:AutoSync()
			InfinityDataCollectorNetwork:AutoShareData()
			InfinityDataCollectorNetwork:CleanupRequests()
		end
	end)
	
	-- Hook into guild events and late-loaded optional databases
	local guildFrame = CreateFrame("Frame")
	pcall(guildFrame.RegisterEvent, guildFrame, "GUILD_ROSTER_UPDATE")
	pcall(guildFrame.RegisterEvent, guildFrame, "PLAYER_ENTERING_WORLD")
	pcall(guildFrame.RegisterEvent, guildFrame, "ADDON_LOADED")
	guildFrame:SetScript("OnEvent", function(self, event, loadedAddon)
		if event == "GUILD_ROSTER_UPDATE" then
			InfinityDataCollectorPrivacy:RefreshGuildCache()
		elseif event == "PLAYER_ENTERING_WORLD" then
			InfinityDataCollectorDBIntegration:RefreshAvailability()
			pcall(function() InfinityDataCollectorHooks:GatherQuestLogData() end)
		elseif event == "ADDON_LOADED" and (
			loadedAddon == "Questie" or loadedAddon == "QuestieDB" or
			loadedAddon == "WowHeadDB" or loadedAddon == "WoWHeadDB" or
			loadedAddon == "GathererDB" or loadedAddon == "GatherMate2"
		) then
			InfinityDataCollectorDBIntegration:RefreshAvailability()
		end
	end)
	
	-- Register data sharing via messaging system
	if InfinityMessaging then
		InfinityMessaging:Subscribe("DataCollector:RequestData", function(requestID, fromPlayer, dataTypes)
			InfinityDataCollectorNetwork:HandleDataRequest(requestID, fromPlayer, dataTypes)
		end, 5)
		
		InfinityMessaging:Subscribe("DataCollector:DataResponse", function(requestID, responseData)
			InfinityDataCollectorNetwork:HandleDataResponse(requestID, responseData)
		end, 5)
	end
	
	-- Start standalone autonomous gathering + initial quest log scan
	InfinityDataCollectorHooks:Start()
	pcall(function() InfinityDataCollectorHooks:GatherQuestLogData() end)
	
	local stats = InfinityDataCollectorCore:GetStatistics()
	InfinityUtils:Info(
		string.format("InfinityDataCollector standalone active (%d quests, %d mobs, %d nodes) — /datacollector",
			stats.questCount or 0, stats.mobCount or 0, stats.nodeCount or 0),
		"DataCollector"
	)
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Collect game data",
			author = "Infinity Suite Team",
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
		-- If InfinityCore is already loaded, initialize immediately
		if _G.InfinityCore then
			InitializeDataCollector()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeDataCollector()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeDataCollector()
		end
	end)
end


