-- Navigation Module
local PluribusNavigator = {}
_G.PluribusNavigator = PluribusNavigator

PluribusNavigator.currentObjective = nil
PluribusNavigator.waypoints = {}
PluribusNavigator.routeMode = "shortest" -- shortest, direct, or manual

function PluribusNavigator:Initialize()
	PluribusUtils:Info("Navigator initialized", "Navigation")
end

function PluribusNavigator:SetObjective(questId, waypoint)
	self.currentObjective = {
		questId = questId,
		waypoint = waypoint or {},
		startTime = GetTime(),
	}
	PluribusMessaging:Publish("navigation_objective_changed", questId, waypoint)
end

function PluribusNavigator:AddWaypoint(x, y, zone, description)
	table.insert(self.waypoints, {
		x = x, y = y, zone = zone,
		description = description,
		added = GetTime(),
	})
	PluribusMessaging:Publish("navigation_waypoint_added", x, y, zone)
end

function PluribusNavigator:ClearWaypoints()
	self.waypoints = {}
	PluribusMessaging:Publish("navigation_waypoints_cleared")
end

function PluribusNavigator:GetNearestObjective()
	if not self.currentObjective then return nil end
	return self.currentObjective.waypoint
end

return PluribusNavigator
