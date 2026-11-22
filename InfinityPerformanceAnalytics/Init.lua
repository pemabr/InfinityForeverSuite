-- InfinityPerformanceAnalytics Initialization
-- DPS/HPS Meter and Performance Analytics

local ADDON_NAME = "InfinityPerformanceAnalytics"
local ADDON_VERSION = "1.0.0"
local initialized = false

local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track and analyze combat statistics",
			author = "Infinity Suite Team",
			category = "Analytics",
			enabled = true,
			settings = {{}}
		})
	end
end

-- Modules are loaded via .toc file, so InfinityPerformanceAnalyticsMeter and InfinityPerformanceAnalyticsUI globals are already created

local function InitializeAnalytics()
	if initialized then return end
	if not _G.InfinityCore then
		if _G.InfinityUtils then
			_G.InfinityUtils:Warning("InfinityCore not found, cannot initialize Analytics", ADDON_NAME)
		end
		return
	end
	
	-- Register addon with manager (safely)
	pcall(RegisterAddonWithInfinityManager)
	
	-- Initialize meter (safely)
	if _G.InfinityPerformanceAnalyticsMeter then 
		pcall(function() _G.InfinityPerformanceAnalyticsMeter:Initialize() end) 
	end
	
	-- Register commands (safely)
	if _G.InfinityCommandRegistry and _G.InfinityCommandRegistry.RegisterCommand then
		pcall(function()
			_G.InfinityCommandRegistry:RegisterCommand("analytics", function(args)
				if not args or #args == 0 then
					if _G.InfinityPerformanceAnalyticsUI then
						_G.InfinityPerformanceAnalyticsUI:Toggle()
					end
				else
					local subcommand = string.lower(args[1] or "")
					if subcommand == "toggle" then
						if _G.InfinityPerformanceAnalyticsUI then
							_G.InfinityPerformanceAnalyticsUI:Toggle()
						end
					elseif subcommand == "start" then
						if _G.InfinityPerformanceAnalyticsMeter and _G.InfinityPerformanceAnalyticsMeter.StartSession then
							local sessionName = args[2] or ("Combat " .. date("%H:%M:%S"))
							if _G.InfinityPerformanceAnalyticsMeter:StartSession(sessionName) then
								_G.InfinityUtils:Info("Session started: " .. sessionName, ADDON_NAME)
							end
						end
					elseif subcommand == "stop" then
						if _G.InfinityPerformanceAnalyticsMeter and _G.InfinityPerformanceAnalyticsMeter.EndSession then
							local session = _G.InfinityPerformanceAnalyticsMeter:EndSession()
							if session then
								_G.InfinityUtils:Info("Session ended: " .. session.name, ADDON_NAME)
							end
						end
					elseif subcommand == "clear" then
						if _G.InfinityPerformanceAnalyticsMeter then
							_G.InfinityPerformanceAnalyticsMeter.combatLog = {}
							_G.InfinityUtils:Info("Session history cleared", ADDON_NAME)
						end
					end
				end
			end, {"meter", "dps", "hps"})
		end)
	end
	
	-- Register keybind (safely)
	if _G.InfinityCommandRegistry and _G.InfinityCommandRegistry.RegisterKeybind then
		pcall(function()
			_G.InfinityCommandRegistry:RegisterKeybind("TOGGLE_ANALYTICS", "Toggle Analytics Meter", function()
				if _G.InfinityPerformanceAnalyticsUI then
					_G.InfinityPerformanceAnalyticsUI:Toggle()
				end
			end)
		end)
	end
	
	-- Hook into combat log events (legacy) and C_DamageMeter / Encounter events (Forever 1.60.1)
	if _G.InfinityUtils and _G.InfinityUtils.CanUseCombatLogEvent and _G.InfinityUtils:CanUseCombatLogEvent() then
		pcall(function()
			local eventFrame = CreateFrame("Frame")
			eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			eventFrame:SetScript("OnEvent", function(self, event)
				if event == "COMBAT_LOG_EVENT_UNFILTERED" then
					if not _G.InfinityPerformanceAnalyticsMeter or not _G.InfinityPerformanceAnalyticsMeter.currentSession then
						return
					end
					
					local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, targetGUID, targetName, targetFlags, spellID, spellName, school, amount, overkill = CombatLogGetCurrentEventInfo()
					
					if subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE" then
						if _G.InfinityPerformanceAnalyticsMeter.RecordDamage then
							_G.InfinityPerformanceAnalyticsMeter:RecordDamage(sourceName, targetName, spellName or "Auto Attack", amount or 0, school or 1)
						end
					elseif subevent == "SPELL_HEAL" or subevent == "SPELL_ABSORBED" then
						if _G.InfinityPerformanceAnalyticsMeter.RecordHealing then
							_G.InfinityPerformanceAnalyticsMeter:RecordHealing(sourceName, targetName, spellName or "Unknown", amount or 0)
						end
					end
				end
			end)
		end)
	end
	
	-- Forever 1.60.1 C_DamageMeter & encounter session integration
	pcall(function()
		local dmFrame = CreateFrame("Frame")
		dmFrame:RegisterEvent("ENCOUNTER_START")
		dmFrame:RegisterEvent("ENCOUNTER_END")
		dmFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		dmFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		local function SyncDamageMeterToAnalytics()
			local meter = _G.InfinityPerformanceAnalyticsMeter
			if not meter then return end
			if not (_G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionFromType) then
				meter.sampleStatus = "Native meter unavailable"
				return
			end
			if not meter.currentSession then
				meter:StartSession("Combat " .. date("%H:%M:%S"))
			end
			local function Public(value)
				if _G.issecretvalue and _G.issecretvalue(value) then return nil end
				return value
			end
			local enums = _G.Enum or {}
			local session = enums.DamageMeterSessionType and enums.DamageMeterSessionType.Current or 1
			local types = enums.DamageMeterType or {}
			local incomplete, failure = false, nil
			local function Sample(metric, field)
				local ok, segment = pcall(_G.C_DamageMeter.GetCombatSessionFromType, session, metric)
				segment = Public(segment)
				if not ok then
					incomplete = true
					failure = "Native meter read failed: " .. tostring(segment or "protected error")
					return
				end
				local sources = type(segment) == "table" and Public(segment.combatSources)
				if type(sources) ~= "table" then incomplete = true; return end
				local total, values, partial = 0, {}, false
				for _, raw in ipairs(sources) do
					local source = Public(raw)
					local name = type(source) == "table" and Public(source.name)
					local amount = type(source) == "table" and Public(source.totalAmount)
					if type(name) ~= "string" or name == "" or type(amount) ~= "number"
						or amount ~= amount or amount < 0 or amount >= math.huge then
						partial = true
					else
						values[name] = amount
						total = total + amount
					end
				end
				if partial then incomplete = true; return end
				for name, player in pairs(meter.players) do player[field] = values[name] or 0 end
				for name, amount in pairs(values) do
					meter.players[name] = meter.players[name] or { name = name, totalDamage = 0, totalHealing = 0, damageEvents = {}, healingEvents = {}, spells = {} }
					meter.players[name][field] = amount
				end
				meter.currentSession[field] = total
			end
			Sample(types.DamageDone or 0, "totalDamage")
			Sample(types.HealingDone or 2, "totalHealing")
			meter.sampleStatus = incomplete and "Native sample incomplete or protected" or "Public native sample"
			local warning = failure or "Native analytics sample incomplete or protected; previous values retained."
			if incomplete and meter.warnedIncomplete ~= warning then
				InfinityUtils:Warning(warning, ADDON_NAME)
			end
			meter.warnedIncomplete = incomplete and warning or nil
		end
		dmFrame:SetScript("OnEvent", function(_, ev, _, encName)
			local meter = _G.InfinityPerformanceAnalyticsMeter
			if not meter then return end
			if _G.issecretvalue and _G.issecretvalue(encName) then encName = nil end
			if ev == "ENCOUNTER_START" or ev == "PLAYER_REGEN_DISABLED" then
				if not meter.currentSession then
					meter:StartSession(encName or ("Combat " .. date("%H:%M:%S")))
				end
			elseif ev == "ENCOUNTER_END" or ev == "PLAYER_REGEN_ENABLED" then
				SyncDamageMeterToAnalytics()
				if meter.currentSession then
					meter:EndSession()
				end
			end
		end)
		local dmTick = 0
		dmFrame:SetScript("OnUpdate", function(_, elapsed)
			dmTick = dmTick + (elapsed or 0)
			if dmTick < 1.0 then return end
			dmTick = 0
			local inCombat = _G.UnitAffectingCombat and _G.UnitAffectingCombat("player")
			if _G.issecretvalue and _G.issecretvalue(inCombat) then inCombat = nil end
			if inCombat then
				SyncDamageMeterToAnalytics()
			end
		end)
	end)
	
	if _G.InfinityUtils then
		_G.InfinityUtils:Info("Analytics addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	end
	initialized = true
end

-- Hook into addon loaded and InfinityCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If InfinityCore is already loaded, initialize immediately
		if _G.InfinityCore and _G.InfinityUtils and _G.InfinityCommandRegistry then
			InitializeAnalytics()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeAnalytics()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeAnalytics()
		end
	end)
end



