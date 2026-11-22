-- InfinityDataCollector Initialization
-- Local data gathering and optional guild snapshots

local addonName = "InfinityDataCollector"
local addonVersion = "1.0.0"
local isInitialized = false
local autoSyncEnabled = true

local function InitializeDataCollector()
	if isInitialized or not _G.InfinityCore then
		return  -- Already initialized or waiting for INFINITY_DATA_LOADED
	end
	-- Initialize all modules
	InfinityDataCollectorCore:Initialize()
	InfinityDataCollectorHooks:Initialize()
	InfinityDataCollectorNetwork:Initialize()
	InfinityGuildKnowledge:Initialize()
	InfinityGuildGatherKnowledge:Initialize()
	InfinityGuildRecipes:Initialize()
	InfinityGuildQuestPositions:Initialize()
	InfinityGuildBossReports:Initialize()
	InfinityGuildBagReports:Initialize()
	InfinityDataCollectorDBIntegration:InitializeDefaultIntegrations()
	InfinityDataCollectorPrivacy:InitializeGuildMemberCache()
	
	-- Make modules global
	_G.InfinityDataCollector = InfinityDataCollectorCore
	_G.InfinityDataCollectorHooks = InfinityDataCollectorHooks
	_G.InfinityDataCollectorPrivacy = InfinityDataCollectorPrivacy
	_G.InfinityDataCollectorNetwork = InfinityDataCollectorNetwork
	_G.InfinityDataCollectorDBIntegration = InfinityDataCollectorDBIntegration
	_G.InfinityDataCollectorUI = InfinityDataCollectorUI
	function InfinityDataCollectorUI:GetAutoSyncEnabled() return autoSyncEnabled end
	function InfinityDataCollectorUI:ToggleAutoSync()
		autoSyncEnabled = not autoSyncEnabled
		print("Auto-sync " .. (autoSyncEnabled and "enabled" or "disabled"))
		return autoSyncEnabled
	end
	function InfinityDataCollectorUI:SyncExternalDatabases()
		local results = InfinityDataCollectorDBIntegration:SyncAll()
		for _, result in ipairs(results) do
			if result.success then
				print("✓ Synced: " .. result.name)
			else
				print("✗ Failed: " .. result.name)
			end
		end
	end
	InfinityDataCollectorUI:RegisterBlizzardSettings()
	
	-- Register with InfinityCore
	InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Local data gathering and optional guild snapshots",
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
			InfinityDataCollectorUI:SyncExternalDatabases()
		end)
		
		InfinityCore:RegisterCommand("/datacollector autosync", "Toggle auto-sync", function()
			InfinityDataCollectorUI:ToggleAutoSync()
		end)
		InfinityCore:RegisterCommand("/datacollector guild", "Guild collector snapshot", function(args)
			local command, option = (args or ""):match("^%s*(%S+)%s*(%S*)%s*$")
			if command == "send" then
				InfinityDataCollectorNetwork:Send()
			elseif command == "enable" then
				if InfinityDataCollectorNetwork:SetSharingEnabled(true) then print("Collector guild sync enabled.") end
			elseif command == "disable" then
				InfinityDataCollectorNetwork:SetSharingEnabled(false)
				print("Collector guild sync disabled.")
			elseif command == "apply" then
				InfinityDataCollectorNetwork:Apply()
			elseif command == "discard" then
				InfinityDataCollectorNetwork:Discard()
			elseif command == "live" and (option == "on" or option == "off") then
				local enabled = InfinityGuildKnowledge:SetEnabled(option == "on")
				if enabled then print("Live guild quest/drop knowledge enabled.")
				elseif option == "off" then print("Live guild quest/drop knowledge disabled.") end
			elseif command == "live" and option == "sync" then
				if InfinityGuildKnowledge:SyncNext() then print("Guild knowledge sync requested.")
				else InfinityUtils:Warning("Live knowledge is disabled, busy, or has no online peer yet.", "Network") end
			elseif command == "nodes" and (option == "on" or option == "off") then
				local enabled = InfinityGuildGatherKnowledge:SetEnabled(option == "on")
				if enabled then print("Guild gathering positions enabled.")
				elseif option == "off" then print("Guild gathering positions disabled.") end
			elseif command == "nodes" and option == "sync" then
				if InfinityGuildGatherKnowledge:SyncNext() then print("Guild gathering positions sync requested.")
				else InfinityUtils:Warning("Guild positions are disabled, busy, or have no online peer yet.", "Network") end
			elseif command == "recipes" and (option == "on" or option == "off") then
				local enabled = InfinityGuildRecipes:SetEnabled(option == "on")
				if enabled then print("Guild recipe reports enabled.")
				elseif option == "off" then print("Guild recipe reports disabled.") end
			elseif command == "recipes" and option == "sync" then
				if InfinityGuildRecipes:SyncNext() then print("Guild recipe sync requested.")
				else InfinityUtils:Warning("Guild recipes are disabled, busy, or have no online peer yet.", "Network") end
			elseif command == "recipes" and option == "" then
				InfinityGuildRecipes:Toggle()
			elseif command == "offers" and (option == "on" or option == "off") then
				local enabled = InfinityGuildQuestPositions:SetEnabled(option == "on")
				if enabled then print("Guild quest-offer positions enabled.")
				elseif option == "off" then print("Guild quest-offer positions disabled.") end
			elseif command == "offers" and option == "sync" then
				if InfinityGuildQuestPositions:SyncNext() then print("Guild quest-offer position sync requested.")
				else InfinityUtils:Warning("Guild quest offers are disabled, busy, or have no online peer yet.", "Network") end
			elseif command == "bosses" and (option == "on" or option == "off") then
				local enabled = InfinityGuildBossReports:SetEnabled(option == "on")
				if enabled then print("Guild boss reports enabled.")
				elseif option == "off" then print("Guild boss reports disabled.") end
			elseif command == "bosses" and option == "sync" then
				if InfinityGuildBossReports:SyncNext() then print("Guild boss report sync requested.")
				else InfinityUtils:Warning("Guild boss reports are disabled, busy, or have no online peer yet.", "Network") end
			elseif command == "bags" and (option == "on" or option == "off") then
				local enabled = InfinityGuildBagReports:SetEnabled(option == "on")
				if enabled then print("Guild bag reports enabled.")
				elseif option == "off" then print("Guild bag reports disabled.") end
			elseif command == "bags" and option == "sync" then
				if InfinityGuildBagReports:SyncNext() then print("Guild bag report sync requested.")
				else InfinityUtils:Warning("Guild bag reports are disabled, busy, or have no online peer yet.", "Network") end
			elseif command == "bags" and option == "" then
				InfinityGuildBagReports:Toggle()
			else
				local status = InfinityDataCollectorNetwork:GetNetworkStats()
				print("Collector guild sync: " .. (status.available and (status.shareEnabled and "enabled" or "disabled") or "unavailable")
					.. (status.pendingCount and (". Pending: " .. status.pendingCount .. " records from " .. status.sender) or "")
					.. ". Live knowledge: " .. (InfinityGuildKnowledge.db and InfinityGuildKnowledge.db.enabled and "on" or "off")
					.. ". Guild positions: " .. (InfinityGuildGatherKnowledge.db and InfinityGuildGatherKnowledge.db.enabled and "on" or "off")
					.. ". Guild recipes: " .. (InfinityGuildRecipes.db and InfinityGuildRecipes.db.enabled and "on" or "off")
					.. ". Guild offers: " .. (InfinityGuildQuestPositions.db and InfinityGuildQuestPositions.db.enabled and "on" or "off")
					.. ". Guild bosses: " .. (InfinityGuildBossReports.db and InfinityGuildBossReports.db.enabled and "on" or "off")
					.. ". Guild bags: " .. (InfinityGuildBagReports.db and InfinityGuildBagReports.db.enabled and "on" or "off")
					.. ". /datacollector guild enable|disable|send|apply|discard|live|nodes|recipes|offers|bosses|bags on|off|sync")
			end
		end)
	end
	
	-- Check optional external databases periodically.
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
		
	end)
	
	-- Hook into guild events for member updates
	local guildFrame = CreateFrame("Frame")
	guildFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	guildFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "GUILD_ROSTER_UPDATE" then
			InfinityDataCollectorPrivacy:RefreshGuildCache()
		end
	end)
	
	-- Start gathering
	if InfinityDataCollectorCore:IsGatheringEnabled() then InfinityDataCollectorHooks:GatherQuestLogData() end
	isInitialized = true
	
	print("InfinityDataCollector loaded")
	print("  - Data gathering: " .. (InfinityDataCollectorCore:IsGatheringEnabled() and "ACTIVE" or "DISABLED"))
	print("  - Guild sync: " .. (InfinityDataCollectorNetwork.available and
		(InfinityDataCollectorNetwork.shareEnabled and "enabled" or "disabled") or "unavailable"))
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


