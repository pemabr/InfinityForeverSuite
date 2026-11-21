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
	
	-- Event handling using non-protected encounter & unit spellcast events (Forever 1.60.1 compatible)
	local combatFrame = CreateFrame("Frame")
	if InfinityUtils:CanUseCombatLogEvent() then
		pcall(combatFrame.RegisterEvent, combatFrame, "COMBAT_LOG_EVENT_UNFILTERED")
	end
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_SPELLCAST_SUCCEEDED")
	pcall(combatFrame.RegisterEvent, combatFrame, "INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	pcall(combatFrame.RegisterEvent, combatFrame, "PLAYER_REGEN_DISABLED")
	pcall(combatFrame.RegisterEvent, combatFrame, "PLAYER_REGEN_ENABLED")
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_HEALTH")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_START")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_END")
	pcall(combatFrame.RegisterEvent, combatFrame, "BOSS_KILL")
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local args = CombatLogGetCurrentEventInfo and {CombatLogGetCurrentEventInfo()} or {...}
			CD:OnCombatLogEvent(unpack(args))
			local subevent = args[2]
			if subevent == "SPELL_CAST_SUCCESS" then
				Abilities:OnAbilityCast(args[12], args[13], 0, 30)
			end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unitTarget, _, spellID = ...
			if InfinityUtils:IsRaidBoss(unitTarget) and spellID then
				local spellName = InfinityUtils:GetSpellNameByID(spellID) or ("Spell " .. tostring(spellID))
				Abilities:OnAbilityCast(spellID, spellName, 0, 30)
				CD:TriggerCallback("ability_cast", UnitName(unitTarget) or unitTarget, spellName, spellID)
			end
		elseif event == "UNIT_HEALTH" then
			local unit = ...
			if InfinityUtils:IsRaidBoss(unit) then
				local name = UnitName(unit)
				local health = UnitHealth(unit)
				local maxHealth = UnitHealthMax(unit)
				if not (_G.issecretvalue and (_G.issecretvalue(health) or _G.issecretvalue(maxHealth))) then
					StatusBars:UpdateBar(name or "Boss", health, maxHealth)
				end
			end
		elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "PLAYER_REGEN_DISABLED" then
			CD:UpdateCombatState()
		elseif event == "PLAYER_REGEN_ENABLED" then
			CD:UpdateCombatState()
		elseif event == "ENCOUNTER_START" then
			local encounterID, encounterName = ...
			Encounters:StartEncounter(encounterName)
			Alerts:SendAlert("Encounter: " .. tostring(encounterName or encounterID), Alerts.LEVEL_INFO)
		elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
			local encounterID, encounterName, difficultyID, groupSize, success = ...
			local won = (event == "BOSS_KILL") or (success == 1)
			Encounters:EndEncounter(won)
		end
	end)
	
	-- Timer update loop (throttled to 10Hz)
	local timerFrame = CreateFrame("Frame")
	local timerElapsed = 0
	timerFrame:SetScript("OnUpdate", function(_, elapsed)
		timerElapsed = timerElapsed + (elapsed or 0)
		if timerElapsed < 0.1 then return end
		timerElapsed = 0
		if Timer and Timer.Update then pcall(function() Timer:Update() end) end
		if UI and UI.Update then pcall(function() UI:Update() end) end
		if CD and CD.UpdateCombatState then pcall(function() CD:UpdateCombatState() end) end
	end)
	
	print("InfinityEncounter loaded - Use /encounter to toggle window")
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



