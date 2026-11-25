-- PluribusHealer Initialization
local ADDON_NAME = "PluribusHealer"
local ADDON_VERSION = "1.4.0"
local initializedHealer = false

local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager and _G.PluribusAddonManager.RegisterAddon then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Unified HealBot + Decursive click-cast raid & party healing frames",
			author = "Pluribus Suite Team",
			category = "Combat",
			enabled = true,
			settings = {}
		})
	end
end

local function InitializePluribusHealer()
	if initializedHealer then return end
	if not PluribusCore or not PluribusDataManager then
		return
	end
	initializedHealer = true
	PluribusUtils:Info("PluribusHealer initializing...", "Healer")

	-- Initialize modules
	if PluribusHealer then pcall(function() PluribusHealer:Initialize() end) end
	if PluribusClickCast then pcall(function() PluribusClickCast:Initialize() end) end
	if PluribusHealingPrediction then pcall(function() PluribusHealingPrediction:Initialize() end) end
	if PluribusAuraTracking then pcall(function() PluribusAuraTracking:Initialize() end) end
	if PluribusRangeChecking then pcall(function() PluribusRangeChecking:Initialize() end) end
	if _G.PluribusHealDecursive then pcall(function() _G.PluribusHealDecursive:Initialize() end) end
	if _G.PluribusHealerUI then pcall(function() _G.PluribusHealerUI:Initialize() end) end

	-- Register globals
	_G.PluribusHealer = PluribusHealer
	_G.PluribusClickCast = PluribusClickCast
	_G.PluribusHealingPrediction = PluribusHealingPrediction
	_G.PluribusAuraTracking = PluribusAuraTracking
	_G.PluribusRangeChecking = PluribusRangeChecking

	RegisterAddonWithPluribusManager()

	-- Slash commands (/healer, /heal, /healbot, /hb, /decursive, /dcr)
	PluribusCommandRegistry:RegisterCommand("healer", function(args)
		local sub = args and args[1] and string.lower(args[1]) or ""
		local eng = _G.PluribusHealDecursive
		if sub == "frames" or sub == "grid" or sub == "toggle" then
			if eng then eng:ToggleGrid() end
		elseif sub == "show" or sub == "on" or sub == "solo" then
			if eng then
				eng.config.enabled = true
				eng.config.showSolo = true
				eng:SaveConfig()
				eng:RequestRebuild()
			end
		elseif sub == "hide" or sub == "off" then
			if eng then
				eng.config.enabled = false
				eng:SaveConfig()
				eng:RequestRebuild()
			end
		elseif sub == "muf" or sub == "decursive" then
			if eng then eng:ToggleCompactMUF() end
		elseif sub == "scale" and args[2] then
			if eng then
				eng.config.scale = math.max(0.6, math.min(1.6, tonumber(args[2]) or 1.0))
				eng:SaveConfig()
				eng:RequestRebuild()
			end
		elseif _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then
			_G.PluribusHealerUI:Toggle()
		elseif _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("HealBot")
		end
	end, { "heal", "healbot", "hb" })

	PluribusCommandRegistry:RegisterCommand("decursive", function(args)
		local sub = args and args[1] and string.lower(args[1]) or ""
		if sub == "config" or sub == "cfg" then
			if _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then
				_G.PluribusHealerUI:Toggle("decursive")
			elseif _G.PluribusMainFrame then
				_G.PluribusMainFrame.healSubTab = "decursive"
				_G.PluribusMainFrame:OpenToTab("HealBot")
			end
		else
			if _G.PluribusHealDecursive then
				_G.PluribusHealDecursive:ToggleCompactMUF()
			elseif _G.PluribusHealerUI then
				_G.PluribusHealerUI:Toggle("decursive")
			end
		end
	end, { "dcr", "decurse" })

	-- Healing prediction update loop
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function()
		if GetNumGroupMembers and GetNumGroupMembers() > 0 and PluribusHealingPrediction and PluribusHealingPrediction.ClearExpiredHeals then
			PluribusHealingPrediction:ClearExpiredHeals()
		end
	end)

	PluribusUtils:Info("PluribusHealer (Unified HealBot + Decursive) initialized successfully", "Healer")
	if PluribusMessaging and PLURIBUS_EVENTS then
		PluribusMessaging:Publish(PLURIBUS_EVENTS.FEATURE_ENABLED, "healer", true)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName ~= "PluribusHealer" then
		return
	end
	if PluribusCore and PluribusDataManager then
		InitializePluribusHealer()
		self:UnregisterAllEvents()
	end
end)


