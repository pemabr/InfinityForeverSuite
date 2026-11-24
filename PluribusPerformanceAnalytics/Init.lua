-- PluribusPerformanceAnalytics Initialization
-- DPS/HPS Meter and Performance Analytics

local ADDON_NAME = "PluribusPerformanceAnalytics"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so PluribusPerformanceAnalyticsMeter and PluribusPerformanceAnalyticsUI globals are already created

local function InitializeAnalytics()
	if not _G.PluribusCore then
		if _G.PluribusUtils then
			_G.PluribusUtils:Warning("PluribusCore not found, cannot initialize Analytics", ADDON_NAME)
		end
		return
	end
	
	-- Register addon with manager (safely)
	pcall(RegisterAddonWithPluribusManager)
	
	-- Initialize meter (safely)
	if _G.PluribusPerformanceAnalyticsMeter then 
		pcall(function() _G.PluribusPerformanceAnalyticsMeter:Initialize() end) 
	end
	
	-- Register commands (safely)
	if _G.PluribusCommandRegistry and _G.PluribusCommandRegistry.RegisterCommand then
		pcall(function()
			_G.PluribusCommandRegistry:RegisterCommand("analytics", function(args)
				if not args or #args == 0 then
					if _G.PluribusPerformanceAnalyticsUI then
						_G.PluribusPerformanceAnalyticsUI:Toggle()
					end
				else
					local subcommand = string.lower(args[1] or "")
					if subcommand == "toggle" then
						if _G.PluribusPerformanceAnalyticsUI then
							_G.PluribusPerformanceAnalyticsUI:Toggle()
						end
					elseif subcommand == "start" then
						if _G.PluribusPerformanceAnalyticsMeter and _G.PluribusPerformanceAnalyticsMeter.StartSession then
							local sessionName = args[2] or ("Combat " .. date("%H:%M:%S"))
							if _G.PluribusPerformanceAnalyticsMeter:StartSession(sessionName) then
								_G.PluribusUtils:Info("Session started: " .. sessionName, ADDON_NAME)
							end
						end
					elseif subcommand == "stop" then
						if _G.PluribusPerformanceAnalyticsMeter and _G.PluribusPerformanceAnalyticsMeter.EndSession then
							local session = _G.PluribusPerformanceAnalyticsMeter:EndSession()
							if session then
								_G.PluribusUtils:Info("Session ended: " .. session.name, ADDON_NAME)
							end
						end
					elseif subcommand == "clear" then
						if _G.PluribusPerformanceAnalyticsMeter then
							_G.PluribusPerformanceAnalyticsMeter.combatLog = {}
							_G.PluribusUtils:Info("Session history cleared", ADDON_NAME)
						end
					end
				end
			end, {"meter", "dps", "hps"})
		end)
	end
	
	-- Register keybind (safely)
	if _G.PluribusCommandRegistry and _G.PluribusCommandRegistry.RegisterKeybind then
		pcall(function()
			_G.PluribusCommandRegistry:RegisterKeybind("TOGGLE_ANALYTICS", "Toggle Analytics Meter", function()
				if _G.PluribusPerformanceAnalyticsUI then
					_G.PluribusPerformanceAnalyticsUI:Toggle()
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
			if not _G.PluribusPerformanceAnalyticsMeter or not _G.PluribusPerformanceAnalyticsMeter.currentSession then
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
							if src.name and not _G.PluribusUtils:IsSecret(src.name) and src.totalAmount and not _G.PluribusUtils:IsSecret(src.totalAmount) then
								if _G.PluribusPerformanceAnalyticsMeter.RecordDamage then
									_G.PluribusPerformanceAnalyticsMeter:RecordDamage(src.name, "Encounter", "Total", tonumber(src.totalAmount) or 0, 1)
								end
							end
						end
					end
				end
			end
		end)
	end)
	
	if _G.PluribusUtils then
		_G.PluribusUtils:Info("Analytics addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	end
end


-- Register with PluribusAddonManager if available
local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Track and analyze combat statistics",
			author = "Pluribus Suite Team",
			category = "Analytics",
			enabled = true,
			settings = {}
		})
	end
end
-- Hook into addon loaded and PluribusCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If PluribusCore is already loaded, initialize immediately
		if _G.PluribusCore and _G.PluribusUtils and _G.PluribusCommandRegistry then
			InitializeAnalytics()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeAnalytics()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeAnalytics()
		end
	end)
end



