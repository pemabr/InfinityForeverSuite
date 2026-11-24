-- PluribusDetails Initialization
-- Combat parsing and performance metrics

local addonName = "PluribusDetails"
local addonVersion = "1.0.0"

local function InitializeDetails()
	if not _G.PluribusCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local Parser = PluribusDetailsCombatParser or _G.PluribusDetailsCombatParser
	local Actor = PluribusDetailsActor or _G.PluribusDetailsActor
	local Meters = PluribusDetailsMeters or _G.PluribusDetailsMeters
	local Segments = PluribusDetailsSegments or _G.PluribusDetailsSegments
	local Threat = PluribusDetailsThreat or _G.PluribusDetailsThreat
	local Deaths = PluribusDetailsDeaths or _G.PluribusDetailsDeaths
	local Reports = PluribusDetailsReports or _G.PluribusDetailsReports
	local UI = PluribusDetailsUI or _G.PluribusDetailsUI
	local Breakdown = PluribusDetailsBreakdown or _G.PluribusDetailsBreakdown
	
	-- Initialize
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	if Breakdown and Breakdown.Initialize then
		if Breakdown then pcall(function() Breakdown:Initialize() end) end
	end
	
	-- Register with PluribusCore
	_G.PluribusCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Pluribus",
		description = "Real-time combat metrics - DPS/HPS/Threat analysis",
		enabled = true,
	})
	
	-- Command registration
	if _G.PluribusCore.RegisterCommand then
		_G.PluribusCore:RegisterCommand("/details", "Toggle Details window", function()
			UI:Toggle()
		end)
		
		_G.PluribusCore:RegisterCommand("/details breakdown", "Show actor breakdown", function()
			Breakdown:Toggle()
		end)
		
		_G.PluribusCore:RegisterCommand("/details report", "Generate full report", function()
			local report = Reports:GenerateFullReport()
			print(report)
		end)
		
		_G.PluribusCore:RegisterCommand("/details dps", "Show DPS report", function()
			local report = Reports:GenerateDPSReport()
			print(report)
		end)
		
		_G.PluribusCore:RegisterCommand("/details hps", "Show HPS report", function()
			local report = Reports:GenerateHPSReport()
			print(report)
		end)
		
		_G.PluribusCore:RegisterCommand("/details threat", "Show threat report", function()
			local report = Reports:GenerateThreatReport()
			print(report)
		end)
		
		_G.PluribusCore:RegisterCommand("/details deaths", "Show death report", function()
			local report = Reports:GenerateDeathReport()
			print(report)
		end)
	end
	
	local function SyncFromNativeDamageMeter()
		if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions) then
			return
		end
		if C_DamageMeter.IsDamageMeterAvailable then
			local okAvail, avail = pcall(C_DamageMeter.IsDamageMeterAvailable)
			if not okAvail or not avail then return end
		end

		local okSessions, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
		if not okSessions or type(sessions) ~= "table" or #sessions == 0 then
			return
		end

		local latest = sessions[#sessions]
		local sessionID = latest and latest.sessionID
		if not sessionID or not C_DamageMeter.GetCombatSessionFromID then
			return
		end

		local dmgType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
		local healType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone) or 2

		local okDmg, dmgSession = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, dmgType)
		if okDmg and type(dmgSession) == "table" and type(dmgSession.combatSources) == "table" and Actor then
			for _, src in ipairs(dmgSession.combatSources) do
				local name = src.name
				local amount = src.totalAmount
				if name and not PluribusUtils:IsSecret(name) and amount and not PluribusUtils:IsSecret(amount) then
					local guid = (src.sourceGUID and not PluribusUtils:IsSecret(src.sourceGUID)) and src.sourceGUID or name
					local classFile = (src.classFilename and not PluribusUtils:IsSecret(src.classFilename)) and src.classFilename or nil
					local actorObj = Actor:GetOrCreateActor(guid, name, classFile, true)
					if actorObj then
						actorObj.damage_total = tonumber(amount) or actorObj.damage_total or 0
						if src.amountPerSecond and not PluribusUtils:IsSecret(src.amountPerSecond) then
							actorObj.dps = tonumber(src.amountPerSecond) or 0
						end
					end
				end
			end
		end

		local okHeal, healSession = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, healType)
		if okHeal and type(healSession) == "table" and type(healSession.combatSources) == "table" and Actor then
			for _, src in ipairs(healSession.combatSources) do
				local name = src.name
				local amount = src.totalAmount
				if name and not PluribusUtils:IsSecret(name) and amount and not PluribusUtils:IsSecret(amount) then
					local guid = (src.sourceGUID and not PluribusUtils:IsSecret(src.sourceGUID)) and src.sourceGUID or name
					local classFile = (src.classFilename and not PluribusUtils:IsSecret(src.classFilename)) and src.classFilename or nil
					local actorObj = Actor:GetOrCreateActor(guid, name, classFile, true)
					if actorObj then
						actorObj.healing_total = tonumber(amount) or actorObj.healing_total or 0
						if src.amountPerSecond and not PluribusUtils:IsSecret(src.amountPerSecond) then
							actorObj.hps = tonumber(src.amountPerSecond) or 0
						end
					end
				end
			end
		end
	end

	-- Blizzard-safe event handling (uses permitted C_DamageMeter & encounter events; never registers blocked COMBAT_LOG_EVENT_UNFILTERED)
	local combatFrame = CreateFrame("Frame")
	for _, ev in ipairs({
		"ENCOUNTER_START",
		"ENCOUNTER_END",
		"PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED",
		"DAMAGE_METER_COMBAT_SESSION_UPDATED",
		"DAMAGE_METER_CURRENT_SESSION_UPDATED",
	}) do
		pcall(combatFrame.RegisterEvent, combatFrame, ev)
	end
	
	combatFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "ENCOUNTER_START" then
			local _, encounterName = ...
			if Parser and Parser.StartParsing then Parser:StartParsing() end
			if Meters and Meters.Start then Meters:Start() end
			if Segments and Segments.StartSegment then Segments:StartSegment(encounterName or "Encounter", encounterName or "Encounter") end
		elseif event == "ENCOUNTER_END" then
			SyncFromNativeDamageMeter()
			if Parser and Parser.StopParsing then Parser:StopParsing() end
			if Meters and Meters.Stop then Meters:Stop() end
			if Segments and Segments.EndSegment then Segments:EndSegment() end
			if UI and UI.Update then UI:Update(true) end
		elseif event == "PLAYER_REGEN_DISABLED" then
			if Meters and Meters.Start then Meters:Start() end
		elseif event == "PLAYER_REGEN_ENABLED" then
			SyncFromNativeDamageMeter()
			if Meters and Meters.Stop then Meters:Stop() end
			if UI and UI.Update then UI:Update(true) end
		elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" or event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
			SyncFromNativeDamageMeter()
		end
	end)
	
	-- Throttled update loop (2Hz, only while window is shown)
	local updateFrame = CreateFrame("Frame")
	local elapsedAcc = 0
	updateFrame:SetScript("OnUpdate", function(_, elapsed)
		elapsedAcc = elapsedAcc + (elapsed or 0)
		if elapsedAcc < 0.5 then return end
		elapsedAcc = 0
		if Meters and Meters.Update then Meters:Update() end
		if UI and UI.frame and UI.frame:IsShown() then
			SyncFromNativeDamageMeter()
			if UI.Update then UI:Update() end
		end
		if Breakdown and Breakdown.frame and Breakdown.frame:IsShown() and Breakdown.Update then
			Breakdown:Update()
		end
	end)
	
	print("PluribusDetails loaded (C_DamageMeter mode) - Use /details for metrics")
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Combat statistics",
			author = "Pluribus Suite Team",
			category = "Combat",
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
		if _G.PluribusCore then
			InitializeDetails()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		InitializeDetails()
	end
end)

if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeDetails()
		end
	end)
end



