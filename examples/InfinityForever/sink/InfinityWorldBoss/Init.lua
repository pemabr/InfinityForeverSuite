-- InfinityWorldBoss Initialization
-- World boss respawn tracking with notifications and guild sharing

local addonName = "InfinityWorldBoss"
local addonVersion = "1.0.0"

if not InfinityCore then
	print("InfinityWorldBoss: Waiting for InfinityCore...")
	return
end

if not InfinityDataCollector then
	print("InfinityWorldBoss: Waiting for InfinityDataCollector...")
	return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	
	-- Initialize modules
	InfinityWorldBossTimers:Initialize()
	InfinityWorldBossUI:StartAutoUpdate()
	
	-- Make modules global
	_G.InfinityWorldBoss = InfinityWorldBossCore
	_G.InfinityWorldBossTimers = InfinityWorldBossTimers
	_G.InfinityWorldBossUI = InfinityWorldBossUI
	
	-- Register with InfinityCore
	InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "World boss respawn tracking with notifications and guild sharing",
		enabled = true,
	})
	
	-- Register slash commands
	if InfinityCore.RegisterCommand then
		InfinityCore:RegisterCommand("/worldboss", "Toggle world boss tracker", function()
			InfinityWorldBossUI:Toggle()
		end)
		
		InfinityCore:RegisterCommand("/worldboss show", "Show boss timer window", function()
			InfinityWorldBossUI:Show()
		end)
		
		InfinityCore:RegisterCommand("/worldboss hide", "Hide boss timer window", function()
			InfinityWorldBossUI:Hide()
		end)
		
		InfinityCore:RegisterCommand("/worldboss register", "Register a world boss", function(bossID, bossName)
			if bossID and bossName then
				InfinityWorldBossCore:RegisterBoss(tonumber(bossID), bossName, GetRealZoneText(), 14400)
				print("Registered boss: " .. bossName)
			else
				print("Usage: /worldboss register <id> <name>")
			end
		end)
		
		InfinityCore:RegisterCommand("/worldboss kill", "Record a boss kill", function(bossID)
			if bossID then
				InfinityWorldBossCore:RecordBossKill(tonumber(bossID), UnitName("player"), GetGuildInfo("player"))
				local boss = InfinityWorldBossCore:GetBossInfo(tonumber(bossID))
				if boss then
					print("Recorded kill: " .. boss.name .. " - Next respawn in " .. 
						InfinityWorldBossCore:FormatTimeRemaining(boss.respawnTime))
				end
			else
				print("Usage: /worldboss kill <boss_id>")
			end
		end)
		
		InfinityCore:RegisterCommand("/worldboss status", "Show current boss statuses", function()
			local bosses = InfinityWorldBossCore:GetAllBosses()
			print("|cFFFFD700World Boss Status|r")
			for _, boss in ipairs(bosses) do
				local timer = InfinityWorldBossCore:GetRespawnTimer(boss.id)
				if timer then
					local timeLeft = InfinityWorldBossCore:GetTimeToRespawn(boss.id)
					print(string.format("  %s: %s", boss.name, 
						InfinityWorldBossCore:FormatTimeRemaining(timeLeft)))
				else
					print(string.format("  %s: Alive", boss.name))
				end
			end
		end)
	end
	
	-- Set up encounter tracking hook for automatic boss kills
	local encounterFrame = CreateFrame("Frame")
	encounterFrame:RegisterEvent("ENCOUNTER_END")
	encounterFrame:SetScript("OnEvent", function(self, event, encounterID, encounterName, difficultyID, groupSize, success)
		if event == "ENCOUNTER_END" and success then
			-- Register boss if not already registered
			if not InfinityWorldBossCore:GetBossInfo(encounterID) then
				InfinityWorldBossCore:RegisterBoss(encounterID, encounterName, GetRealZoneText(), 14400)
			end
			
			-- Record kill
			InfinityWorldBossCore:RecordBossKill(encounterID, UnitName("player"), GetGuildInfo("player") or "Unknown")
			
			-- Notify guild
			if IsInGuild() then
				SendChatMessage("|cFFFFD700[World Boss]|r " .. encounterName .. " killed! Next respawn: ~4 hours", "GUILD")
			end
		end
	end)
	
	-- Hook into data collector for P2P sharing
	if InfinityMessaging then
		InfinityMessaging:Subscribe("DataCollector:RequestData", function(requestID, fromPlayer, dataTypes)
			-- Share world boss data if requested
			if table.concat(dataTypes):find("worldboss") then
				local bossData = InfinityWorldBossCore:ExportBossData()
				InfinityMessaging:Publish("DataCollector:DataResponse", requestID, {
					worldboss = bossData
				})
			end
		end, 5)
	end
	
	-- Register classic world bosses (expandable with more)
	InfinityWorldBossCore:RegisterBoss(1, "Azuregos", "Azshara", 48000)
	InfinityWorldBossCore:RegisterBoss(2, "Lord Kazzak", "The Tainted Scar", 43200)
	InfinityWorldBossCore:RegisterBoss(3, "The Four Dragons of Nightmare", "Duskwood", 14400)
	InfinityWorldBossCore:RegisterBoss(4, "Taerar", "Ashenvale", 14400)
	InfinityWorldBossCore:RegisterBoss(5, "Ysondre", "Hinterlands", 14400)
	InfinityWorldBossCore:RegisterBoss(6, "Lethendris", "Feralas", 14400)
	
	print("InfinityWorldBoss loaded")
	print("  - Respawn tracking: ACTIVE")
	print("  - Notifications: " .. (InfinityWorldBossCore.notificationEnabled and "ENABLED" or "DISABLED"))
	print("  - Guild sharing: " .. (InfinityWorldBossCore.guildSharingEnabled and "ENABLED" or "DISABLED"))
	print("  - Use /worldboss for tracker window")
	print("  - Use /worldboss status for quick status")
end)
