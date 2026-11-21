-- InfinityNavigation Initialization

local function InitializeNavigation()
	InfinityUtils:Info("InfinityNavigation initializing...", "Navigation")
	
	if not InfinityCore or not InfinityDataManager then
		InfinityUtils:Warning("InfinityCore not ready", "Navigation")
		return
	end
	
	-- Initialize modules
	if InfinityNavigator then pcall(function() InfinityNavigator:Initialize() end) end
	if InfinityQuestIntegration then pcall(function() InfinityQuestIntegration:Initialize() end) end
	if InfinityPathFinding then pcall(function() InfinityPathFinding:Initialize() end) end
	if InfinityWayPointUI then pcall(function() InfinityWayPointUI:Initialize() end) end
	if InfinityNavigationUI then pcall(function() InfinityNavigationUI:Initialize() end) end
	
	-- Register globals
	_G.InfinityNavigator = InfinityNavigator
	_G.InfinityQuestIntegration = InfinityQuestIntegration
	_G.InfinityPathFinding = InfinityPathFinding
	_G.InfinityWayPointUI = InfinityWayPointUI
	_G.InfinityNavigationUI = InfinityNavigationUI
	
	-- Slash commands
	InfinityCommandRegistry:RegisterCommand("nav", function(args)
		if not args or #args == 0 then
			InfinityNavigationUI:Toggle()
		elseif args[1] == "waypoint" and args[2] then
			local questId = tonumber(args[2])
			if questId then
				InfinityNavigator:SetObjective(questId)
			end
		end
	end, {"navigate", "navigation"})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityNavigation", "1.2.0", {
			description = "Navigation tools",
			author = "Infinity Suite Team",
			category = "Navigation",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info("InfinityNavigation initialized successfully", "Navigation")
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, "navigation", true)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityNavigation" then
		if InfinityCore and InfinityDataManager then
			InitializeNavigation()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if InfinityCore and InfinityDataManager then
						InitializeNavigation()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


