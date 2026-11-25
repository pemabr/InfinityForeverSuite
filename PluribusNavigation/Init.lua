-- PluribusNavigation Initialization

local function InitializeNavigation()
	PluribusUtils:Info("PluribusNavigation initializing...", "Navigation")
	
	if not PluribusCore or not PluribusDataManager then
		PluribusUtils:Warning("PluribusCore not ready", "Navigation")
		return
	end
	
	-- Initialize modules
	if PluribusNavigator then pcall(function() PluribusNavigator:Initialize() end) end
	if PluribusQuestIntegration then pcall(function() PluribusQuestIntegration:Initialize() end) end
	if PluribusPathFinding then pcall(function() PluribusPathFinding:Initialize() end) end
	if PluribusWayPointUI then pcall(function() PluribusWayPointUI:Initialize() end) end
	if PluribusNavigationUI then pcall(function() PluribusNavigationUI:Initialize() end) end
	
	-- Register globals
	_G.PluribusNavigator = PluribusNavigator
	_G.PluribusQuestIntegration = PluribusQuestIntegration
	_G.PluribusPathFinding = PluribusPathFinding
	_G.PluribusWayPointUI = PluribusWayPointUI
	_G.PluribusNavigationUI = PluribusNavigationUI
	
	-- Slash commands (/nav, /navigate, /navigation, /way X Y Label, /nav skip, /nav route)
	PluribusCommandRegistry:RegisterCommand("nav", function(args)
		if not args or #args == 0 then
			PluribusNavigationUI:Toggle()
		elseif args[1] == "compass" or args[1] == "hud" then
			PluribusNavigationUI:ToggleCompassHUD()
		elseif args[1] == "clear" then
			PluribusNavigationUI:ClearWaypoint()
		elseif args[1] == "skip" then
			if _G.PluribusHiveDynamicRoute and _G.PluribusHiveDynamicRoute.SkipActiveStop then
				_G.PluribusHiveDynamicRoute:SkipActiveStop()
			end
		elseif args[1] == "route" then
			local sub = args[2] and tostring(args[2]):lower() or ""
			if _G.PluribusHiveDynamicRoute then
				if sub == "quests" or sub == "quest" then
					_G.PluribusHiveDynamicRoute:EnableSources(true, nil, true)
				elseif sub == "todos" or sub == "todo" then
					_G.PluribusHiveDynamicRoute:EnableSources(nil, true, true)
				elseif sub == "all" or sub == "both" then
					_G.PluribusHiveDynamicRoute:EnableSources(true, true, true)
				elseif sub == "restore" then
					_G.PluribusHiveDynamicRoute:RestoreAllSkipped()
				end
			end
			PluribusNavigationUI.selectedCat = "Route"
			PluribusNavigationUI:Toggle()
		elseif tonumber(args[1]) and tonumber(args[2]) then
			local label = table.concat(args, " ", 3)
			local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
			PluribusNavigationUI:SetWaypoint(label ~= "" and label or "Custom Pin", zone, tonumber(args[1]), tonumber(args[2]))
		elseif args[1] == "waypoint" and args[2] then
			local questId = tonumber(args[2])
			if questId then
				PluribusNavigator:SetObjective(questId)
			end
		else
			PluribusNavigationUI:Toggle()
		end
	end, {"navigate", "navigation", "way", "compass"})
	
	PluribusUtils:Info("PluribusNavigation initialized successfully (/nav, /way)", "Navigation")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.FEATURE_ENABLED, "navigation", true)
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Navigation tools",
			author = "Pluribus Suite Team",
			category = "Navigation",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusNavigation" then
		if PluribusCore and PluribusDataManager then
			InitializeNavigation()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if PluribusCore and PluribusDataManager then
						InitializeNavigation()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


