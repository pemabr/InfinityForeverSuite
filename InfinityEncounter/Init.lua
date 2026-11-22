-- InfinityEncounter Initialization
-- Setup and integration with InfinityCore

local addonName = "InfinityEncounter"
local addonVersion = "1.0.0"
local initialized = false

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function InitializeEncounter()
	if initialized or not _G.InfinityCore then
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
	if Alerts and Alerts.Initialize then Alerts:Initialize() end
	local settings = _G.InfinityCore.GetDatabase and _G.InfinityCore:GetDatabase(addonName)
	Abilities:InitializeWatches(settings)
	if _G.InfinityEncounterPresets then InfinityEncounterPresets:Initialize(settings) end
	if _G.InfinityEncounterDBMBridge then InfinityEncounterDBMBridge:Initialize(settings) end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Encounter alerts and supported native timeline events",
		enabled = true,
	})
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		local function Register(command, description, callback)
			UI.actions = UI.actions or {}
			UI.actions[command] = callback
			_G.InfinityCore:RegisterCommand("/encounter" .. (command ~= "" and " " .. command or ""), description, callback)
		end
		Register("", "Toggle encounter window", function()
			UI:Toggle()
		end)
		Register("journal", "Show native encounter journal", function(args)
			local input = type(args) == "string" and args:match("^%s*(.-)%s*$") or ""
			if input == "" then
				UI:ShowJournal()
			elseif input:match("^%d+$") then
				UI:ShowJournal(tonumber(input))
			else
				print("Usage: /encounter journal [journal encounter ID]")
			end
		end)
		Register("dbm", "Toggle DBM live timers", function(args)
			local choice = type(args) == "string" and args:match("^%s*(%S+)%s*$")
			if choice == "on" or choice == "off" then
				if _G.InfinityEncounterDBMBridge then InfinityEncounterDBMBridge:SetEnabled(choice == "on") end
			else print("Usage: /encounter dbm on|off") end
		end)
		Register("dbm modules", "List loaded DBM modules", function(args)
			if _G.InfinityEncounterDBMBridge then InfinityEncounterDBMBridge:ListModules(type(args) == "string" and args or "") end
		end)
		Register("dbm import", "Manage DBM spell-ID imports", function(args)
			local input = type(args) == "string" and args:match("^%s*(%S+)%s*$")
			local bridge = _G.InfinityEncounterDBMBridge
			if not bridge then InfinityUtils:Warning("DBM import is unavailable.", "Encounter")
			elseif input == "on" or input == "off" then bridge:SetImportAllowed(input == "on")
			elseif input then bridge:ImportModule(input)
			else print("Usage: /encounter dbm import on|off|<module ID>") end
		end)
		Register("preset", "Manage boss watch presets", function(args)
			local input = type(args) == "string" and args:match("^%s*(.-)%s*$") or ""
			local action, rest = input:match("^(%S+)%s*(.-)$")
			local presets = _G.InfinityEncounterPresets
			if not presets then InfinityUtils:Warning("Boss presets are unavailable.", "Encounter"); return end
			if not action or action == "list" and rest == "" then presets:List()
			elseif action == "create" and rest ~= "" then presets:Create(rest)
			elseif action == "use" and rest ~= "" then presets:Use(rest)
			elseif action == "delete" and rest ~= "" then presets:Delete(rest)
			elseif action == "send" and rest ~= "" then presets:Send(rest)
			else print("Usage: /encounter preset list|create <name>|use <id|none>|delete <id>|send <id>") end
		end)
		Register("watch", "List watched boss spells", function()
			if not Abilities.watchedSpells then
				print("Encounter watch settings unavailable.")
				return
			end
			print("Watched boss spells: /encounter watch add <spell ID> [label] | remove <spell ID>")
			local ids = {}
			for id in pairs(Abilities.watchedSpells) do
				if type(id) == "number" then ids[#ids + 1] = id end
			end
			table.sort(ids)
			for _, id in ipairs(ids) do print(id .. " - " .. tostring(Abilities.watchedSpells[id])) end
			if #ids == 0 then print("No watched spells.") end
		end)
		Register("watch add", "Alert on a boss spell", function(args)
			local rawID, label
			if type(args) == "string" then rawID, label = args:match("^%s*(%d+)%s*(.-)%s*$") end
			local id = tonumber(rawID)
			if not id then print("Usage: /encounter watch add <spell ID> [label]"); return end
			if id <= 0 or id > 1000000000 then
				InfinityUtils:Warning("Invalid spell ID or alert label.", "Encounter")
				return
			end
			if not label or label == "" then
				local name = Public(InfinityUtils:GetSpellNameByID(id))
				label = type(name) == "string" and name or ("Spell " .. rawID)
			end
			if Abilities:SetWatch(id, label) then print("Watching boss spell " .. id .. ": " .. label) end
		end)
		Register("watch remove", "Stop watching a boss spell", function(args)
			local id = type(args) == "string" and args:match("^%s*(%d+)%s*$")
			if not id then print("Usage: /encounter watch remove <spell ID>"); return end
			if Abilities:RemoveWatch(tonumber(id)) then print("Stopped watching boss spell " .. id) end
		end)
		
		Register("reset", "Reset encounter data", function()
			Encounters:Reset()
			Abilities:Reset()
			Alerts:Clear()
			print("Encounter data reset")
		end)
		
		Register("test", "Test alert system", function()
			Alerts:SendAlert("Test Critical Alert!", Alerts.LEVEL_CRITICAL)
			Alerts:SendAbilityAlert("Test Ability", 10, "critical")
			print("Alerts tested")
		end)
		Register("timer", "Start a manual timer", function(args)
			local duration, name
			if type(args) == "string" then duration, name = args:match("^%s*(%S+)%s+(.+)%s*$") end
			duration = tonumber(duration)
			name = name and name:match("^%s*(.-)%s*$")
			if not duration or duration ~= duration or duration <= 0 or duration > 86400
				or not name or name == "" or #name > 80 then
				print("Usage: /encounter timer <seconds up to 86400> <name>")
				return
			end
			local timer = Timer:CreateTimer("manual:" .. name:lower(), name, duration, function(current)
				Alerts:SendAbilityAlert(current.name, 0)
			end)
			timer.onWarning = function(current, threshold, remaining)
				if threshold == 5 then Alerts:SendAbilityAlert(current.name, remaining) end
			end
			UI:Show()
			UI:Update()
			print("Manual timer started: " .. name)
		end)
		Register("timer stop", "Stop a manual timer", function(args)
			local name = type(args) == "string" and args:match("^%s*(.-)%s*$")
			if not name or name == "" or #name > 80 then
				print("Usage: /encounter timer stop <name>")
				return
			end
			local id = "manual:" .. name:lower()
			if not Timer:GetTimer(id) then
				print("Manual timer not found: " .. name)
				return
			end
			Timer:RemoveTimer(id)
			UI:Update()
			print("Manual timer stopped: " .. name)
		end)
	end
	
	-- Event handling using non-protected encounter & unit spellcast events (Forever 1.60.1 compatible)
	local combatFrame = CreateFrame("Frame")
	if InfinityUtils:CanUseCombatLogEvent() then
		pcall(combatFrame.RegisterEvent, combatFrame, "COMBAT_LOG_EVENT_UNFILTERED")
	end
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_SPELLCAST_SUCCEEDED")
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_SPELLCAST_START")
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_SPELLCAST_INTERRUPTED")
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_SPELLCAST_FAILED")
	pcall(combatFrame.RegisterEvent, combatFrame, "INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	pcall(combatFrame.RegisterEvent, combatFrame, "PLAYER_REGEN_DISABLED")
	pcall(combatFrame.RegisterEvent, combatFrame, "PLAYER_REGEN_ENABLED")
	pcall(combatFrame.RegisterEvent, combatFrame, "UNIT_HEALTH")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_START")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_END")
	pcall(combatFrame.RegisterEvent, combatFrame, "BOSS_KILL")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_TIMELINE_EVENT_ADDED")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_TIMELINE_EVENT_REMOVED")
	pcall(combatFrame.RegisterEvent, combatFrame, "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")

	local function SyncEncounterTimeline()
		if not (_G.C_EncounterTimeline and _G.C_EncounterTimeline.HasActiveEvents
			and _G.C_EncounterTimeline.GetEventState) then return end
		if not Public(_G.C_EncounterTimeline.HasActiveEvents()) then return end
		local list = _G.C_EncounterTimeline.GetEventList and Public(_G.C_EncounterTimeline.GetEventList())
		if type(list) ~= "table" then return end
		for _, eventID in ipairs(list) do
			eventID = Public(eventID)
			if type(eventID) == "number" or type(eventID) == "string" then
				local info = _G.C_EncounterTimeline.GetEventInfo and Public(_G.C_EncounterTimeline.GetEventInfo(eventID))
				local rem = _G.C_EncounterTimeline.GetEventTimeRemaining and Public(_G.C_EncounterTimeline.GetEventTimeRemaining(eventID))
				local state = Public(_G.C_EncounterTimeline.GetEventState(eventID))
				local label = type(info) == "table" and Public(info.spellName) or nil
				if not label and type(info) == "table" then label = Public(info.name) end
				if type(label) ~= "string" then label = "Boss Ability" end
				local tid = "et_" .. tostring(eventID)
				if (state ~= 0 and state ~= 1)
					or type(rem) ~= "number" or rem ~= rem or rem <= 0 or rem >= math.huge then
					Timer:RemoveTimer(tid)
				else
					local previous = Timer:GetTimer(tid)
					local timer = Timer:CreateTimer(tid, label, rem)
					if previous then
						timer.warnings = previous.warnings
						timer.lastRemaining = previous.lastRemaining
						for threshold in pairs(timer.warnings) do
							if rem > threshold + 1 then timer.warnings[threshold] = nil end
						end
					end
					timer.onWarning = function(current, threshold, remaining)
						if threshold == 5 then Alerts:SendAbilityAlert(current.name, remaining) end
					end
					if state == 1 then timer.pausedRemaining = rem end
				end
			end
		end
	end
	local timelineWarning = false
	local function TrySyncEncounterTimeline()
		local ok, err = pcall(SyncEncounterTimeline)
		if not ok and not timelineWarning then
			timelineWarning = true
			InfinityUtils:Warning("Encounter timeline unavailable: " .. tostring(err), "Encounter")
		end
	end
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local args = CombatLogGetCurrentEventInfo and {CombatLogGetCurrentEventInfo()} or {...}
			CD:OnCombatLogEvent(unpack(args))
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START"
			or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
			local unitTarget, _, spellID = ...
			unitTarget, spellID = Public(unitTarget), Public(spellID)
			local isBoss = type(unitTarget) == "string" and Public(InfinityUtils:IsRaidBoss(unitTarget))
			if not isBoss and type(unitTarget) == "string" and unitTarget:match("^boss[1-8]$") and _G.UnitExists then
				local exists = Public(UnitExists(unitTarget))
				isBoss = exists == true or exists == 1
			end
			if type(unitTarget) == "string" and (isBoss or event == "UNIT_SPELLCAST_INTERRUPTED"
				or event == "UNIT_SPELLCAST_FAILED") then
				Abilities:OnWatchedCast(event, unitTarget, spellID)
			end
			if event == "UNIT_SPELLCAST_SUCCEEDED" and type(unitTarget) == "string"
				and type(spellID) == "number" and isBoss then
				local spellName = Public(InfinityUtils:GetSpellNameByID(spellID))
				if type(spellName) ~= "string" then spellName = "Spell " .. spellID end
				Abilities:OnAbilityCast(spellID, spellName)
				local unitName = Public(UnitName(unitTarget))
				CD:TriggerCallback("ability_cast", type(unitName) == "string" and unitName or unitTarget, spellName, spellID)
			end
		elseif event == "UNIT_HEALTH" then
			local unit = Public(...)
			if type(unit) == "string" and Public(InfinityUtils:IsRaidBoss(unit)) then
				local name = Public(UnitName(unit))
				if type(name) ~= "string" then name = "Boss" end
				local health = UnitHealth(unit)
				local maxHealth = UnitHealthMax(unit)
				if not (_G.issecretvalue and (_G.issecretvalue(health) or _G.issecretvalue(maxHealth)))
					and type(health) == "number" and type(maxHealth) == "number" then
					StatusBars:UpdateBar(name or "Boss", health, maxHealth)
				end
			end
		elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "PLAYER_REGEN_DISABLED" then
			CD:UpdateCombatState()
		elseif event == "PLAYER_REGEN_ENABLED" then
			CD:UpdateCombatState()
		elseif event == "ENCOUNTER_START" then
			local encounterID, encounterName = ...
			encounterName = Public(encounterName)
			if type(encounterName) ~= "string" then encounterName = "Boss" end
			Encounters:StartEncounter(encounterName)
			Alerts:SendAlert("Encounter: " .. encounterName, Alerts.LEVEL_INFO)
			TrySyncEncounterTimeline()
		elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
			TrySyncEncounterTimeline()
		elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
			local eventID = Public(...)
			if (type(eventID) == "number" or type(eventID) == "string")
				and _G.C_EncounterTimeline and _G.C_EncounterTimeline.GetEventState then
				local state = Public(_G.C_EncounterTimeline.GetEventState(eventID))
				if state == 0 or state == 1 then
					TrySyncEncounterTimeline()
				else
					Timer:RemoveTimer("et_" .. tostring(eventID))
				end
			end
		elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
			local eventID = Public(...)
			if (type(eventID) == "number" or type(eventID) == "string") and Timer and Timer.RemoveTimer then
				Timer:RemoveTimer("et_" .. tostring(eventID))
			end
		elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
			local encounterID, encounterName, difficultyID, groupSize, success = ...
			success = Public(success)
			local won
			if event == "BOSS_KILL" or success == 1 then
				won = true
			elseif success == 0 then
				won = false
			end
			Encounters:EndEncounter(won)
			Abilities.activeWatchedCasts = {}
			local remove = {}
			for id in pairs(Timer.timers) do
				if type(id) == "string" and id:match("^et_") then remove[#remove + 1] = id end
			end
			for _, id in ipairs(remove) do Timer:RemoveTimer(id) end
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
	
	initialized = true
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



