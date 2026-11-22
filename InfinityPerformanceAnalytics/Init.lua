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
	
	-- Hook into combat log events (safely)
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



