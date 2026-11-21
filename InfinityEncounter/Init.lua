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
	
	-- Event handling
	local combatFrame = CreateFrame("Frame")
	combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	combatFrame:RegisterEvent("UNIT_HEALTH")
	combatFrame:RegisterEvent("UNIT_DIED")
	combatFrame:RegisterEvent("ENCOUNTER_START")
	combatFrame:RegisterEvent("ENCOUNTER_END")
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			CD:OnCombatLogEvent(...)
			local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName = ...
			if subevent == "SPELL_CAST_SUCCESS" then
				Abilities:OnAbilityCast(select(12, ...), select(13, ...), 0, 30)
			end
		elseif event == "UNIT_HEALTH" then
			local unit = ...
			if UnitIsRaidBoss(unit) then
				local name = UnitName(unit)
				local health = UnitHealth(unit)
				local maxHealth = UnitHealthMax(unit)
				StatusBars:UpdateBar(name or "Boss", health, maxHealth)
			end
		elseif event == "ENCOUNTER_START" then
			local encounterID, encounterName, difficultyID = ...
			Encounters:StartEncounter(encounterName)
			Alerts:SendAlert("Encounter: " .. encounterName, Alerts.LEVEL_INFO)
		elseif event == "ENCOUNTER_END" then
			local encounterID, encounterName, difficultyID, groupSize, success = ...
			Encounters:EndEncounter(success == 1)
		end
	end)
	
	-- Timer update loop
	local timerFrame = CreateFrame("Frame")
	timerFrame:SetScript("OnUpdate", function()
		Timer:Update()
		UI:Update()
		CD:UpdateCombatState()
	end)
	
	print("InfinityEncounter loaded - Use /encounter to toggle window")
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



