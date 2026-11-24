-- InfinityEncounter Initialization
-- Setup and integration with InfinityCore

local addonName = "InfinityEncounter"
local addonVersion = "1.0.0"

local function InitializeEncounter()
	if not _G.InfinityCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local CD = InfinityEncounterCD or _G.InfinityEncounterCD
	local Timer = InfinityEncounterTimer or _G.InfinityEncounterTimer
	local EncDB = InfinityEncounterDB or _G.InfinityEncounterDB
	local Encounters = InfinityEncounterMgr or _G.InfinityEncounterMgr
	local Abilities = InfinityEncounterAbilities or _G.InfinityEncounterAbilities
	local Alerts = InfinityEncounterAlerts or _G.InfinityEncounterAlerts
	local StatusBars = InfinityEncounterStatusBars or _G.InfinityEncounterStatusBars
	local UI = InfinityEncounterUI or _G.InfinityEncounterUI
	
	-- Initialize
	if EncDB and EncDB.Initialize then
		if EncDB then pcall(function() EncDB:Initialize() end) end
	end
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Complete encounter timers and boss ability tracking (DBM replacement)",
		enabled = true,
	})
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		_G.InfinityCore:RegisterCommand("/encounter", "Toggle encounter window", function()
			UI:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/encounter reset", "Reset encounter data", function()
			Encounters:Reset()
			Abilities:Reset()
			Alerts:Clear()
			print("Encounter data reset")
		end)
		
		_G.InfinityCore:RegisterCommand("/encounter test", "Test alert system", function()
			Alerts:SendAlert("Test Critical Alert!", Alerts.LEVEL_CRITICAL)
			Alerts:SendAbilityAlert("Test Ability", 10, "critical")
			print("Alerts tested")
		end)
	end
	
	local function IsSecret(val)
		return issecretvalue ~= nil and issecretvalue(val) or false
	end

	local function IsRaidBossUnit(unit)
		if not unit or type(unit) ~= "string" or not UnitExists(unit) then
			return false
		end
		if unit:match("^boss%d+$") then
			return true
		end
		local classification = UnitClassification and UnitClassification(unit)
		if not IsSecret(classification) and classification == "worldboss" then
			return true
		end
		local level = UnitLevel and UnitLevel(unit)
		if not IsSecret(level) and level == -1 then
			return true
		end
		return false
	end

	-- Blizzard-safe event handling (no restricted COMBAT_LOG_EVENT_UNFILTERED)
	local combatFrame = CreateFrame("Frame")
	for _, ev in ipairs({
		"UNIT_HEALTH",
		"PLAYER_TARGET_CHANGED",
		"PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED",
		"ENCOUNTER_START",
		"ENCOUNTER_END",
		"START_PLAYER_COUNTDOWN",
		"CANCEL_PLAYER_COUNTDOWN",
	}) do
		pcall(combatFrame.RegisterEvent, combatFrame, ev)
	end
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "UNIT_HEALTH" or event == "PLAYER_TARGET_CHANGED" then
			local unit = event == "UNIT_HEALTH" and (...) or "target"
			if IsRaidBossUnit(unit) then
				local name = UnitName(unit)
				local health = UnitHealth(unit)
				local maxHealth = UnitHealthMax(unit)
				if not IsSecret(name) and not IsSecret(health) and not IsSecret(maxHealth) then
					if StatusBars and StatusBars.UpdateBar then
						StatusBars:UpdateBar(name or "Boss", health, maxHealth)
					end
				end
			end
		elseif event == "START_PLAYER_COUNTDOWN" then
			local _, timeRemaining = ...
			local secs = tonumber(timeRemaining) or 10
			if Timer and Timer.CreateTimer then
				Timer:CreateTimer("Pull Countdown", secs)
			end
			if Alerts and Alerts.SendAlert then
				Alerts:SendAlert(string.format("Pull in %d seconds!", secs), Alerts.LEVEL_WARNING)
			end
		elseif event == "CANCEL_PLAYER_COUNTDOWN" then
			if Timer and Timer.timers then
				Timer.timers = {}
			end
		elseif event == "ENCOUNTER_START" then
			local encounterID, encounterName = ...
			if Encounters and Encounters.StartEncounter then
				Encounters:StartEncounter(encounterName)
			end
			if Alerts and Alerts.SendAlert then
				Alerts:SendAlert("Encounter: " .. tostring(encounterName or "Unknown"), Alerts.LEVEL_INFO)
			end
			-- Load known encounter ability timers from built-in EncounterDB (no combat log needed)
			if EncDB and EncDB.GetEncounter and Timer and Timer.CreateTimer then
				local data = EncDB:GetEncounter(encounterName)
				if data and type(data.abilities) == "table" then
					for _, ab in ipairs(data.abilities) do
						if ab.name and (ab.cooldown or ab.timer) then
							Timer:CreateTimer(ab.name, ab.cooldown or ab.timer)
						end
					end
				end
			end
		elseif event == "ENCOUNTER_END" then
			local encounterID, encounterName, difficultyID, groupSize, success = ...
			if Encounters and Encounters.EndEncounter then
				Encounters:EndEncounter(success == 1)
			end
		end
	end)
	
	-- Timer update loop (throttled to ~10Hz)
	local timerFrame = CreateFrame("Frame")
	local elapsedAcc = 0
	timerFrame:SetScript("OnUpdate", function(_, elapsed)
		elapsedAcc = elapsedAcc + (elapsed or 0)
		if elapsedAcc < 0.1 then return end
		elapsedAcc = 0
		if Timer and Timer.Update then Timer:Update() end
		if UI and UI.frame and UI.frame:IsShown() and UI.Update then UI:Update() end
		if CD and CD.UpdateCombatState then CD:UpdateCombatState() end
	end)
	
	print("InfinityEncounter loaded (1.60.1 safe mode) - Use /encounter to toggle window")
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track encounters",
			author = "Infinity Suite Team",
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
		if _G.InfinityCore then
			InitializeEncounter()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		InitializeEncounter()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeEncounter()
		end
	end)
end



