-- InfinityAnalytics Initialization
-- DPS/HPS Meter and Performance Analytics

local ADDON_NAME = "InfinityAnalytics"
local ADDON_VERSION = "1.0.0"

-- Load modules
InfinityAnalyticsMeter = require(ADDON_NAME .. ".Modules.Meter")
InfinityAnalyticsUI = require(ADDON_NAME .. ".UI.Main")

local function InitializeAnalytics()
	if not InfinityCore then
		InfinityUtils:Warning("InfinityCore not found, cannot initialize Analytics", ADDON_NAME)
		return
	end
	
	-- Initialize meter
	InfinityAnalyticsMeter:Initialize()
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("analytics", function(args)
		if not args or #args == 0 then
			InfinityAnalyticsUI:Toggle()
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "toggle" then
				InfinityAnalyticsUI:Toggle()
			elseif subcommand == "start" then
				local sessionName = args[2] or ("Combat " .. os.date("%H:%M:%S"))
				if InfinityAnalyticsMeter:StartSession(sessionName) then
					InfinityUtils:Info("Session started: " .. sessionName, ADDON_NAME)
				end
			elseif subcommand == "stop" then
				local session = InfinityAnalyticsMeter:EndSession()
				if session then
					InfinityUtils:Info("Session ended: " .. session.name, ADDON_NAME)
				end
			elseif subcommand == "clear" then
				InfinityAnalyticsMeter.combatLog = {}
				InfinityUtils:Info("Session history cleared", ADDON_NAME)
			end
		end
	end, {"meter", "dps", "hps"})
	
	-- Register keybind
	InfinityCommandRegistry:RegisterKeybind("TOGGLE_ANALYTICS", "Toggle Analytics Meter", function()
		InfinityAnalyticsUI:Toggle()
	end)
	
	-- Hook into combat log events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			if not InfinityAnalyticsMeter.currentSession then
				return
			end
			
			local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, targetGUID, targetName, targetFlags, spellID, spellName, school, amount, overkill = CombatLogGetCurrentEventInfo()
			
			if subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE" then
				InfinityAnalyticsMeter:RecordDamage(sourceName, targetName, spellName or "Auto Attack", amount or 0, school or 1)
			elseif subevent == "SPELL_HEAL" or subevent == "SPELL_ABSORBED" then
				InfinityAnalyticsMeter:RecordHealing(sourceName, targetName, spellName or "Unknown", amount or 0)
			end
		end
	end)
	
	InfinityUtils:Info("Analytics addon loaded v" .. ADDON_VERSION, ADDON_NAME)
end

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == ADDON_NAME then
		if InfinityCore then
			InitializeAnalytics()
		else
			-- Wait for core
			C_Timer.After(0.5, InitializeAnalytics)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
