-- PluribusWorldBoss Initialization
-- World boss respawn tracking with notifications and guild sharing

local addonName = "PluribusWorldBoss"
local addonVersion = "1.0.0"

local function InitializeWorldBoss()
	if not _G.PluribusCore then
		return
	end
	
	if not _G.PluribusDataCollector then
		return
	end
	
	-- Initialize modules
	if PluribusWorldBossTimers then pcall(function() PluribusWorldBossTimers:Initialize() end) end
	PluribusWorldBossUI:StartAutoUpdate()
	
	-- Make modules global
	_G.PluribusWorldBoss = PluribusWorldBossCore
	_G.PluribusWorldBossTimers = PluribusWorldBossTimers
	_G.PluribusWorldBossUI = PluribusWorldBossUI
	
	-- Register with PluribusCore
	_G.PluribusCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Pluribus",
		description = "World boss respawn tracking with notifications and guild sharing",
		enabled = true,
	})
	
	-- Register slash commands
	if _G.PluribusCore.RegisterCommand then
		_G.PluribusCore:RegisterCommand("/worldboss", "Toggle world boss tracker", function()
			PluribusWorldBossUI:Toggle()
		end)
		
		_G.PluribusCore:RegisterCommand("/worldboss show", "Show boss timer window", function()
			PluribusWorldBossUI:Show()
		end)
		
		_G.PluribusCore:RegisterCommand("/worldboss hide", "Hide boss timer window", function()
			PluribusWorldBossUI:Hide()
		end)
		
		_G.PluribusCore:RegisterCommand("/worldboss register", "Register a world boss", function(bossID, bossName)
			if bossID and bossName then
				PluribusWorldBossCore:RegisterBoss(tonumber(bossID), bossName, GetRealZoneText(), 14400)
				print("Registered boss: " .. bossName)
			else
				print("Usage: /worldboss register <id> <name>")
			end
		end)
		
		_G.PluribusCore:RegisterCommand("/worldboss kill", "Record a boss kill", function(bossID)
			if bossID then
				PluribusWorldBossCore:RecordBossKill(tonumber(bossID), UnitName("player"), GetGuildInfo("player"))
				local boss = PluribusWorldBossCore:GetBossInfo(tonumber(bossID))
				if boss then
					print("Recorded kill: " .. boss.name .. " - Next respawn in " .. 
						PluribusWorldBossCore:FormatTimeRemaining(boss.respawnTime))
				end
			else
				print("Usage: /worldboss kill <boss_id>")
			end
		end)
		
		_G.PluribusCore:RegisterCommand("/worldboss status", "Show current boss statuses", function()
			local bosses = PluribusWorldBossCore:GetAllBosses()
			print("|cFFFFD700World Boss Status|r")
			for _, boss in ipairs(bosses) do
				local timer = PluribusWorldBossCore:GetRespawnTimer(boss.id)
				if timer then
					local timeLeft = PluribusWorldBossCore:GetTimeToRespawn(boss.id)
					print(string.format("  %s: %s", boss.name, 
						PluribusWorldBossCore:FormatTimeRemaining(timeLeft)))
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
			if not PluribusWorldBossCore:GetBossInfo(encounterID) then
				PluribusWorldBossCore:RegisterBoss(encounterID, encounterName, GetRealZoneText(), 14400)
			end
			
			-- Record kill
			PluribusWorldBossCore:RecordBossKill(encounterID, UnitName("player"), GetGuildInfo("player") or "Unknown")
			
			-- Notify guild
			if IsInGuild() then
				SendChatMessage("|cFFFFD700[World Boss]|r " .. encounterName .. " killed! Next respawn: ~4 hours", "GUILD")
			end
		end
	end)
	
	-- Hook into data collector for P2P sharing
	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("DataCollector:RequestData", function(requestID, fromPlayer, dataTypes)
			-- Share world boss data if requested
			if table.concat(dataTypes):find("worldboss") then
				local bossData = PluribusWorldBossCore:ExportBossData()
				_G.PluribusMessaging:Publish("DataCollector:DataResponse", requestID, {
					worldboss = bossData
				})
			end
		end, 5)
	end
	
	-- Register classic world bosses (expandable with more)
	PluribusWorldBossCore:RegisterBoss(1, "Azuregos", "Azshara", 48000)
	PluribusWorldBossCore:RegisterBoss(2, "Lord Kazzak", "The Tainted Scar", 43200)
	PluribusWorldBossCore:RegisterBoss(3, "The Four Dragons of Nightmare", "Duskwood", 14400)
	PluribusWorldBossCore:RegisterBoss(4, "Taerar", "Ashenvale", 14400)
	PluribusWorldBossCore:RegisterBoss(5, "Ysondre", "Hinterlands", 14400)
	PluribusWorldBossCore:RegisterBoss(6, "Lethendris", "Feralas", 14400)
	
	print("PluribusWorldBoss loaded")
	print("  - Respawn tracking: ACTIVE")
	print("  - Notifications: " .. (PluribusWorldBossCore.notificationEnabled and "ENABLED" or "DISABLED"))
	print("  - Guild sharing: " .. (PluribusWorldBossCore.guildSharingEnabled and "ENABLED" or "DISABLED"))
	print("  - Use /worldboss for tracker window")
	print("  - Use /worldboss status for quick status")
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "World bosses",
			author = "Pluribus Suite Team",
			category = "Raid",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.PluribusCore and _G.PluribusDataCollector then
			InitializeWorldBoss()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		InitializeWorldBoss()
	end
end)

if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeWorldBoss()
		end
	end)
end


