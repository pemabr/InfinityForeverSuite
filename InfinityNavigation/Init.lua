local initialized = false

local function InitializeNavigation()
	if initialized then return end
	if not InfinityCore or not InfinityCommandRegistry or not InfinityUIFramework
		or not InfinityNavigator or not InfinityWayPointUI or not InfinityNavigationUI
		or not InfinityQuestIntegration or not InfinityPathFinding then
		error("Navigation modules unavailable")
	end
	InfinityNavigator:Initialize()
	InfinityQuestIntegration:Initialize()
	InfinityPathFinding:Initialize()
	InfinityCommandRegistry:RegisterCommand("nav", function(args)
		local command = args and args[1]
		if not command then
			InfinityNavigationUI:Toggle()
		elseif command == "waypoint" or command == "quest" then
			if not args[2] then print("Usage: /nav quest <quest ID>")
			else InfinityNavigator:SetObjective(tonumber(args[2])) end
		elseif command == "add" then
			local mapID, x, y = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
			local name = args[5] and table.concat(args, " ", 5)
			local ok, result
			if x and y then ok, result = InfinityNavigator:AddWaypoint(x / 100, y / 100, mapID, name) end
			if not ok then
				print("Usage: /nav add <map ID> <x percent> <y percent> <name>. " .. (result or "Invalid coordinates."))
			else
				print("Waypoint saved. Click it in /nav to track it.")
				InfinityWayPointUI:Refresh()
			end
		elseif command == "here" then
			local name = args[2] and table.concat(args, " ", 2) or "Saved position"
			local ok, result = InfinityNavigator:SavePlayerPosition(name)
			if not ok then InfinityUtils:Warning(result, "Navigation")
			else print("Position saved."); InfinityWayPointUI:Refresh() end
		elseif command == "remove" then
			if InfinityNavigator:RemoveWaypoint(tonumber(args[2])) then
				print("Waypoint removed.")
				InfinityWayPointUI:Refresh()
			else print("Usage: /nav remove <waypoint number>") end
		elseif command == "clear" then
			InfinityNavigator:ClearWaypoints()
			InfinityWayPointUI:Refresh()
			print("Saved waypoints cleared; the active map marker is unchanged.")
		else
			print("Usage: /nav [quest <quest ID>|add <map ID> <x%> <y%> <name>|here [name]|remove <number>|clear]")
		end
	end, { "navigate", "navigation" })
	InfinityCore:RegisterAddon("InfinityNavigation", {
		version = "1.2.0", description = "Saved waypoints and native quest navigation",
		author = "Infinity Suite Team", category = "Navigation", enabled = true, settings = {},
	})
	initialized = true
	InfinityUtils:Info("InfinityNavigation initialized", "Navigation")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
	if addonName == "InfinityNavigation" then InitializeNavigation() end
end)
