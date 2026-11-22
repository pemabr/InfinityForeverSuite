-- InfinityDetails Initialization
-- Combat parsing and performance metrics

local addonName = "InfinityDetails"
local addonVersion = "1.0.0"
local initialized = false

local function InitializeNativeDetails()
	if not InfinityDetailsUI or not InfinityCommandRegistry or not InfinityUIFramework then
		error("InfinityDetails required modules unavailable")
	end
	local UI = InfinityDetailsUI
	UI:Initialize()
	InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Native combat damage and healing meters",
		enabled = true,
	})
	InfinityCommandRegistry:RegisterCommand("details", function(args)
		local command = args and args[1]
		if not command then
			UI:Toggle()
		elseif command == "dps" then
			print(UI:BuildReport("damage"))
		elseif command == "hps" then
			print(UI:BuildReport("healing"))
		elseif command == "report" then
			print(UI:BuildReport("damage") .. "\n" .. UI:BuildReport("healing"))
		elseif command == "breakdown" then
			UI:Show()
			print("Click a public source to view its spell breakdown.")
		elseif command == "damage" or command == "healing" or command == "absorbs"
			or command == "taken" or command == "interrupts" or command == "dispels" then
			UI.metric, UI.selected = command, nil
			UI:Show()
		elseif command == "threat" or command == "deaths" then
			print("This report is not available from the native meter.")
		else
			print("Usage: /details [damage|healing|absorbs|taken|interrupts|dispels|dps|hps|report|breakdown]")
		end
	end)
	local updateFrame = CreateFrame("Frame")
	local elapsed = 0
	updateFrame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 0.5 then
			elapsed = 0
			UI:Update()
		end
	end)
	print("InfinityDetails loaded - Use /details for native combat metrics")
end

local function InitializeDetails()
	if initialized then return end
	if not _G.InfinityCore then
		return
	end
	if _G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionFromType then
		InitializeNativeDetails()
		initialized = true
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local Parser = InfinityDetailsCombatParser or _G.InfinityDetailsCombatParser
	local Actor = InfinityDetailsActor or _G.InfinityDetailsActor
	local Meters = InfinityDetailsMeters or _G.InfinityDetailsMeters
	local Segments = InfinityDetailsSegments or _G.InfinityDetailsSegments
	local Threat = InfinityDetailsThreat or _G.InfinityDetailsThreat
	local Deaths = InfinityDetailsDeaths or _G.InfinityDetailsDeaths
	local Reports = InfinityDetailsReports or _G.InfinityDetailsReports
	local UI = InfinityDetailsUI or _G.InfinityDetailsUI
	local Breakdown = InfinityDetailsBreakdown or _G.InfinityDetailsBreakdown
	
	-- Initialize
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	if Breakdown and Breakdown.Initialize then
		if Breakdown then pcall(function() Breakdown:Initialize() end) end
	end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Real-time combat metrics - DPS/HPS/Threat analysis",
		enabled = true,
	})
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		_G.InfinityCore:RegisterCommand("/details", "Toggle Details window", function()
			UI:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/details breakdown", "Show actor breakdown", function()
			Breakdown:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/details report", "Generate full report", function()
			local report = Reports:GenerateFullReport()
			print(report)
		end)
		
		_G.InfinityCore:RegisterCommand("/details dps", "Show DPS report", function()
			local report = Reports:GenerateDPSReport()
			print(report)
		end)
		
		_G.InfinityCore:RegisterCommand("/details hps", "Show HPS report", function()
			local report = Reports:GenerateHPSReport()
			print(report)
		end)
		
		_G.InfinityCore:RegisterCommand("/details threat", "Show threat report", function()
			local report = Reports:GenerateThreatReport()
			print(report)
		end)
		
		_G.InfinityCore:RegisterCommand("/details deaths", "Show death report", function()
			local report = Reports:GenerateDeathReport()
			print(report)
		end)
	end
	
	-- Event handling
	local combatFrame = CreateFrame("Frame")
	if InfinityUtils:CanUseCombatLogEvent() then
		pcall(combatFrame.RegisterEvent, combatFrame, "COMBAT_LOG_EVENT_UNFILTERED")
	end
	combatFrame:RegisterEvent("ENCOUNTER_START")
	combatFrame:RegisterEvent("ENCOUNTER_END")
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			-- Parse combat events
			if Parser:IsParsing() then
				Parser:OnCombatLogEvent(...)
				
				local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
					  destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool,
					  amount, overkill = ...
				
				-- Update actor model based on event type
				if subevent:find("DAMAGE") then
					local sourceActor = Actor:GetOrCreateActor(sourceGUID, sourceName, nil, true)
					local isCrit = subevent:find("CRIT") ~= nil
					sourceActor:RecordDamage(amount or 0, overkill, isCrit)
				elseif subevent:find("HEAL") then
					local sourceActor = Actor:GetOrCreateActor(sourceGUID, sourceName, nil, true)
					local isCrit = subevent:find("CRIT") ~= nil
					sourceActor:RecordHealing(amount or 0, 0, isCrit)
				elseif subevent == "UNIT_DIED" then
					Deaths:RecordDeath(destName)
				end
			end
		elseif event == "ENCOUNTER_START" then
			Parser:StartParsing()
			Meters:Start()
			Segments:StartSegment(select(2, ...), select(2, ...))
		elseif event == "ENCOUNTER_END" then
			Parser:StopParsing()
			Meters:Stop()
			Segments:EndSegment()
		end
	end)
	
	-- Update loop (throttled to 10Hz) + C_DamageMeter sync for Forever 1.60.1
	local updateFrame = CreateFrame("Frame")
	local updateElapsed = 0
	local dmElapsed = 0
	local function SyncFromDamageMeter()
		if not (_G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionFromType) then return end
		local isSec = _G.issecretvalue
		local dmgSeg = _G.C_DamageMeter.GetCombatSessionFromType(1, 0) or _G.C_DamageMeter.GetCombatSessionFromType(0, 0)
		if dmgSeg and dmgSeg.combatSources then
			for _, src in ipairs(dmgSeg.combatSources) do
				local name = src.name
				local guid = src.sourceGUID or name
				local amt = src.totalAmount
				local cls = src.classFilename
				if name and amt and not (isSec and (isSec(name) or isSec(guid) or isSec(amt))) then
					local actor = Actor:GetOrCreateActor(guid, name, (not (isSec and isSec(cls))) and cls or nil, true)
					actor.damage_total = amt
					actor.damage_hits = math.max(actor.damage_hits or 0, 1)
					actor.damage_avg = amt / actor.damage_hits
				end
			end
			if dmgSeg.durationSeconds and not (isSec and isSec(dmgSeg.durationSeconds)) and dmgSeg.durationSeconds > 0 then
				Meters.duration = dmgSeg.durationSeconds
			end
		end
		local healSeg = _G.C_DamageMeter.GetCombatSessionFromType(1, 2) or _G.C_DamageMeter.GetCombatSessionFromType(0, 2)
		if healSeg and healSeg.combatSources then
			for _, src in ipairs(healSeg.combatSources) do
				local name = src.name
				local guid = src.sourceGUID or name
				local amt = src.totalAmount
				local cls = src.classFilename
				if name and amt and not (isSec and (isSec(name) or isSec(guid) or isSec(amt))) then
					local actor = Actor:GetOrCreateActor(guid, name, (not (isSec and isSec(cls))) and cls or nil, true)
					actor.healing_total = amt
					actor.healing_hits = math.max(actor.healing_hits or 0, 1)
				end
			end
		end
	end
	updateFrame:SetScript("OnUpdate", function(_, elapsed)
		updateElapsed = updateElapsed + (elapsed or 0)
		dmElapsed = dmElapsed + (elapsed or 0)
		if dmElapsed >= 0.5 then
			dmElapsed = 0
			pcall(SyncFromDamageMeter)
		end
		if updateElapsed < 0.1 then return end
		updateElapsed = 0
		if Meters and Meters.Update then pcall(function() Meters:Update() end) end
		if UI and UI.Update then pcall(function() UI:Update() end) end
		if Breakdown and Breakdown.Update then pcall(function() Breakdown:Update() end) end
	end)
	
	print("InfinityDetails loaded - Use /details for metrics")
	initialized = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.InfinityCore then
			InitializeDetails()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		InitializeDetails()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeDetails()
		end
	end)
end



