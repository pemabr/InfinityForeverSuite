-- InfinityDataCollector Initialization
-- Autonomous data gathering, database integration, and secure P2P sharing

local addonName = "InfinityDataCollector"
local addonVersion = "1.0.0"
local isInitialized = false
local autoSyncEnabled = true

local function InitializeDataCollector()
	if isInitialized or not _G.InfinityCore then
		return  -- Already initialized or waiting for INFINITY_DATA_LOADED
	end
	isInitialized = true

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
		description = "Autonomous data gathering, database integration, and secure P2P sharing",
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
		
		InfinityCore:RegisterCommand("/datacollector sync", "Force database sync", function()
			local results = InfinityDataCollectorDBIntegration:SyncAll()
			for _, result in ipairs(results) do
				if result.success then
					print("✓ Synced: " .. result.name)
				else
					print("✗ Failed: " .. result.name)
				end
			end
		end)
		
		InfinityCore:RegisterCommand("/datacollector autosync", "Toggle auto-sync", function()
			autoSyncEnabled = not autoSyncEnabled
			print("Auto-sync " .. (autoSyncEnabled and "enabled" or "disabled"))
		end)
	end
	
	-- Setup periodic data gathering and sharing (throttled every 10 seconds)
	local updateFrame = CreateFrame("Frame")
	local syncElapsed = 0
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		syncElapsed = syncElapsed + (elapsed or 0)
		if syncElapsed < 10 then
			return
		end
		syncElapsed = 0
		
		if autoSyncEnabled then
			InfinityDataCollectorDBIntegration:AutoSync()
		end
		
		-- Auto-share data to peers
		InfinityDataCollectorNetwork:AutoShareData()
		
		-- Clean up old requests
		InfinityDataCollectorNetwork:CleanupRequests()
	end)
	
	-- Hook into guild events for member updates
	local guildFrame = CreateFrame("Frame")
	guildFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	guildFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "GUILD_ROSTER_UPDATE" then
			InfinityDataCollectorPrivacy:RefreshGuildCache()
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
	
	-- Start gathering
	InfinityDataCollectorHooks:Start()
	
	print("InfinityDataCollector loaded")
	print("  - Autonomous data gathering: ACTIVE")
	print("  - Privacy level: " .. InfinityDataCollectorPrivacy:GetSanitizationLevel())
	print("  - Network sharing: " .. (InfinityDataCollectorNetwork.shareEnabled and "ENABLED" or "DISABLED"))
	print("  - Use /datacollector for UI")
	print("  - Use /datacollector sync to sync external databases")
	print("  - Collected: " .. InfinityDataCollectorCore:GetStatistics().questCount .. " quests, " ..
		InfinityDataCollectorCore:GetStatistics().mobCount .. " mobs, " ..
		InfinityDataCollectorCore:GetStatistics().nodeCount .. " nodes")
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


