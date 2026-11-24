-- InfinityPerformanceAnalytics Initialization
-- DPS/HPS Meter and Performance Analytics

local ADDON_NAME = "InfinityPerformanceAnalytics"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so InfinityPerformanceAnalyticsMeter and InfinityPerformanceAnalyticsUI globals are already created

local function InitializeAnalytics()
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
	
	-- Sync combat metrics via permitted C_DamageMeter API (no blocked COMBAT_LOG_EVENT_UNFILTERED)
	pcall(function()
		local eventFrame = CreateFrame("Frame")
		for _, ev in ipairs({
			"DAMAGE_METER_COMBAT_SESSION_UPDATED",
			"PLAYER_REGEN_DISABLED",
			"PLAYER_REGEN_ENABLED",
		}) do
			pcall(eventFrame.RegisterEvent, eventFrame, ev)
		end
		eventFrame:SetScript("OnEvent", function(self, event)
			if not _G.InfinityPerformanceAnalyticsMeter or not _G.InfinityPerformanceAnalyticsMeter.currentSession then
				return
			end
			if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetCombatSessionFromID then
				local okS, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
				if okS and type(sessions) == "table" and #sessions > 0 then
					local sid = sessions[#sessions].sessionID
					local dmgType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
					local okD, dSession = pcall(C_DamageMeter.GetCombatSessionFromID, sid, dmgType)
					if okD and type(dSession) == "table" and type(dSession.combatSources) == "table" then
						for _, src in ipairs(dSession.combatSources) do
							if src.name and not _G.InfinityUtils:IsSecret(src.name) and src.totalAmount and not _G.InfinityUtils:IsSecret(src.totalAmount) then
								if _G.InfinityPerformanceAnalyticsMeter.RecordDamage then
									_G.InfinityPerformanceAnalyticsMeter:RecordDamage(src.name, "Encounter", "Total", tonumber(src.totalAmount) or 0, 1)
								end
							end
						end
					end
				end
			end
		end)
	end)
	
	if _G.InfinityUtils then
		_G.InfinityUtils:Info("Analytics addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	end
end


-- Register with InfinityAddonManager if available
local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track and analyze combat statistics",
			author = "Infinity Suite Team",
			category = "Analytics",
			enabled = true,
			settings = {}
		})
	end
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



