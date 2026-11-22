-- Navigation Module
local InfinityNavigator = {}
_G.InfinityNavigator = InfinityNavigator

InfinityNavigator.currentObjective = nil
InfinityNavigator.waypoints = {}
InfinityNavigator.routeMode = "shortest" -- shortest, direct, or manual

function InfinityNavigator:Initialize()
	InfinityUtils:Info("Navigator initialized", "Navigation")
end

function InfinityNavigator:SetObjective(questId, waypoint)
	self.currentObjective = {
		questId = questId,
		waypoint = waypoint or {},
		startTime = GetTime(),
	}
	InfinityMessaging:Publish("navigation_objective_changed", questId, waypoint)
end

function InfinityNavigator:AddWaypoint(x, y, zone, description)
	table.insert(self.waypoints, {
		x = x, y = y, zone = zone,
		description = description,
		added = GetTime(),
	})
	InfinityMessaging:Publish("navigation_waypoint_added", x, y, zone)
end

function InfinityNavigator:ClearWaypoints()
	self.waypoints = {}
	InfinityMessaging:Publish("navigation_waypoints_cleared")
end

function InfinityNavigator:GetNearestObjective()
	if not self.currentObjective then return nil end
	return self.currentObjective.waypoint
end

return InfinityNavigator
