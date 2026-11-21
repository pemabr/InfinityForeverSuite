-- InfinityDataCollector Initialization
-- Autonomous data gathering, database integration, and secure P2P sharing

local addonName = "InfinityDataCollector"
local addonVersion = "1.0.0"

if not InfinityCore then
	print("InfinityDataCollector: Waiting for InfinityCore...")
	return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	
	-- Initialize all modules
	InfinityDataCollectorHooks:Initialize()
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
			-- Enable auto-sync via timer
			local timerFrame = CreateFrame("Frame")
			local function OnUpdate()
				InfinityDataCollectorDBIntegration:AutoSync()
				InfinityDataCollectorNetwork:AutoShareData()
				InfinityDataCollectorNetwork:CleanupRequests()
			end
			timerFrame:SetScript("OnUpdate", function()
				OnUpdate()
			end)
			print("Auto-sync enabled - databases will sync every 30 minutes")
		end)
	end
	
	-- Setup periodic data gathering and sharing
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		-- Auto-sync databases every 30 minutes
		InfinityDataCollectorDBIntegration:AutoSync()
		
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
end)
