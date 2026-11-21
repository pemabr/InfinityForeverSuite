-- InfinityDetails Initialization
-- Combat parsing and performance metrics

local addonName = "InfinityDetails"
local addonVersion = "1.0.0"

local function InitializeDetails()
	if not _G.InfinityCore then
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
	
	-- Update loop (throttled to 10Hz)
	local updateFrame = CreateFrame("Frame")
	local updateElapsed = 0
	updateFrame:SetScript("OnUpdate", function(_, elapsed)
		updateElapsed = updateElapsed + (elapsed or 0)
		if updateElapsed < 0.1 then return end
		updateElapsed = 0
		if Meters and Meters.Update then pcall(function() Meters:Update() end) end
		if UI and UI.Update then pcall(function() UI:Update() end) end
		if Breakdown and Breakdown.Update then pcall(function() Breakdown:Update() end) end
	end)
	
	print("InfinityDetails loaded - Use /details for metrics")
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



