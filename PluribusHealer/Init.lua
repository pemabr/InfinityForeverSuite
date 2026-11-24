-- PluribusHealer Initialization

local function InitializePluribusHealer()
	PluribusUtils:Info("PluribusHealer initializing...", "Healer")
	
	if not PluribusCore or not PluribusDataManager then
		PluribusUtils:Warning("PluribusCore not ready", "Healer")
		return
	end
	
	-- Initialize modules
	if PluribusHealer then pcall(function() PluribusHealer:Initialize() end) end
	if PluribusClickCast then pcall(function() PluribusClickCast:Initialize() end) end
	if PluribusHealingPrediction then pcall(function() PluribusHealingPrediction:Initialize() end) end
	if PluribusAuraTracking then pcall(function() PluribusAuraTracking:Initialize() end) end
	if PluribusRangeChecking then pcall(function() PluribusRangeChecking:Initialize() end) end
	if PluribusHealerUI then pcall(function() PluribusHealerUI:Initialize() end) end
	
	-- Register globals
	_G.PluribusHealer = PluribusHealer
	_G.PluribusClickCast = PluribusClickCast
	_G.PluribusHealingPrediction = PluribusHealingPrediction
	_G.PluribusAuraTracking = PluribusAuraTracking
	_G.PluribusRangeChecking = PluribusRangeChecking
	_G.PluribusHealerUI = PluribusHealerUI
	
	-- Slash commands
	PluribusCommandRegistry:RegisterCommand("healer", function(args)
		if not args or #args == 0 then
			PluribusHealerUI:Toggle()
		elseif args[1] == "frames" then
			PluribusHealer:ToggleFrames()
		elseif args[1] == "scale" and args[2] then
			PluribusHealer:SetFrameScale(tonumber(args[2]) or 1)
		end
	end, {"heal"})
	
	-- Healing prediction update loop
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(f, elapsed)
		if GetNumGroupMembers() > 0 then
			PluribusHealingPrediction:ClearExpiredHeals()
		end
	end)
	
	PluribusUtils:Info("PluribusHealer initialized successfully", "Healer")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.FEATURE_ENABLED, "healer", true)
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Healer tools",
			author = "Pluribus Suite Team",
			category = "Combat",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusHealer" then
		if PluribusCore and PluribusDataManager then
			InitializePluribusHealer()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if PluribusCore and PluribusDataManager then
						InitializePluribusHealer()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


