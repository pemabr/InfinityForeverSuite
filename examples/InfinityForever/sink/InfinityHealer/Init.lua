-- InfinityHealer Initialization

local function InitializeInfinityHealer()
	InfinityUtils:Info("InfinityHealer initializing...", "Healer")
	
	if not InfinityCore or not InfinityDataManager then
		InfinityUtils:Warning("InfinityCore not ready", "Healer")
		return
	end
	
	-- Initialize modules
	InfinityHealer:Initialize()
	InfinityClickCast:Initialize()
	InfinityHealingPrediction:Initialize()
	InfinityAuraTracking:Initialize()
	InfinityRangeChecking:Initialize()
	InfinityHealerUI:Initialize()
	
	-- Register globals
	_G.InfinityHealer = InfinityHealer
	_G.InfinityClickCast = InfinityClickCast
	_G.InfinityHealingPrediction = InfinityHealingPrediction
	_G.InfinityAuraTracking = InfinityAuraTracking
	_G.InfinityRangeChecking = InfinityRangeChecking
	_G.InfinityHealerUI = InfinityHealerUI
	
	-- Slash commands
	InfinityCommandRegistry:RegisterCommand("healer", function(args)
		if not args or #args == 0 then
			InfinityHealerUI:Toggle()
		elseif args[1] == "frames" then
			InfinityHealer:ToggleFrames()
		elseif args[1] == "scale" and args[2] then
			InfinityHealer:SetFrameScale(tonumber(args[2]) or 1)
		end
	end, {"heal"})
	
	-- Healing prediction update loop
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(f, elapsed)
		if GetNumGroupMembers() > 0 then
			InfinityHealingPrediction:ClearExpiredHeals()
		end
	end)
	
	InfinityUtils:Info("InfinityHealer initialized successfully", "Healer")
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, "healer", true)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityHealer" then
		if InfinityCore and InfinityDataManager then
			InitializeInfinityHealer()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if InfinityCore and InfinityDataManager then
						InitializeInfinityHealer()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
