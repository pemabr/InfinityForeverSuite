-- QuestRouteEngine.lua - Pathfinding to quest locations
-- Part of PluribusQuestie addon suite
-- Calculates and displays routes to quest objectives

local QuestRouteEngine = {}
QuestRouteEngine.enabled = false
QuestRouteEngine.db = nil
QuestRouteEngine.routes = {}
QuestRouteEngine.waypoints = {}

-- Configuration
QuestRouteEngine.config = {
    enabled = true,
    max_waypoints = 50,
    route_optimization = "shortest",  -- shortest, fastest, balanced
    avoid_hostile = true,
    use_flightpaths = false,
    use_portals = true,
}

function QuestRouteEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.routes then
        self.db.routes = {}
    end
    
    if not self.db.waypoints then
        self.db.waypoints = {}
    end
    
    self.routes = self.db.routes
    self.waypoints = self.db.waypoints
    self.enabled = true
    
    self:Log("Initialized quest route engine")
end

function QuestRouteEngine:CreateRoute(routeId, questId, startMapId, startX, startY, endMapId, endX, endY)
    if not routeId or not questId or not startMapId or not endMapId then
        return false
    end
    
    if not self.routes[questId] then
        self.routes[questId] = {}
    end
    
    local route = {
        id = routeId,
        quest_id = questId,
        start_map = startMapId,
        start_x = startX or 0,
        start_y = startY or 0,
        end_map = endMapId,
        end_x = endX or 0,
        end_y = endY or 0,
        waypoints = {},
        distance = 0,
        estimated_time = 0,
        created_at = GetTime(),
        active = false,
    }
    
    table.insert(self.routes[questId], route)
    self:Log("Created route: " .. routeId .. " for quest " .. questId)
    
    return true
end

function QuestRouteEngine:GetRoute(questId, routeId)
    if not questId or not self.routes[questId] then
        return nil
    end
    
    for _, route in ipairs(self.routes[questId]) do
        if route.id == routeId then
            return route
        end
    end
    
    return nil
end

function QuestRouteEngine:GetRoutesForQuest(questId)
    if not questId or not self.routes[questId] then
        return {}
    end
    
    return self.routes[questId]
end

function QuestRouteEngine:AddWaypoint(routeId, questId, sequence, mapId, x, y, waypointType)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return false
    end
    
    if #route.waypoints >= self.config.max_waypoints then
        self:Log("Max waypoints reached for route: " .. routeId)
        return false
    end
    
    local waypoint = {
        id = routeId .. "_" .. sequence,
        sequence = sequence,
        map_id = mapId,
        x = x,
        y = y,
        type = waypointType or "objective",  -- objective, npc, item_location, checkpoint
        visited = false,
        visited_at = nil,
    }
    
    table.insert(route.waypoints, waypoint)
    
    return true
end

function QuestRouteEngine:GetWaypoints(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return {}
    end
    
    return route.waypoints
end

function QuestRouteEngine:MarkWaypointVisited(questId, routeId, sequence)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return false
    end
    
    for _, waypoint in ipairs(route.waypoints) do
        if waypoint.sequence == sequence then
            waypoint.visited = true
            waypoint.visited_at = GetTime()
            self:Log("Marked waypoint visited: " .. sequence .. " on route " .. routeId)
            return true
        end
    end
    
    return false
end

function QuestRouteEngine:ActivateRoute(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return false
    end
    
    route.active = true
    self:Log("Activated route: " .. routeId)
    
    return true
end

function QuestRouteEngine:DeactivateRoute(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return false
    end
    
    route.active = false
    self:Log("Deactivated route: " .. routeId)
    
    return true
end

function QuestRouteEngine:CalculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function QuestRouteEngine:CalculateRouteDuration(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route or #route.waypoints < 2 then
        return 0
    end
    
    local totalDistance = 0
    local previousWaypoint = route.waypoints[1]
    
    for i = 2, #route.waypoints do
        local waypoint = route.waypoints[i]
        
        if waypoint.map_id == previousWaypoint.map_id then
            totalDistance = totalDistance + self:CalculateDistance(
                previousWaypoint.x, previousWaypoint.y,
                waypoint.x, waypoint.y
            )
        else
            totalDistance = totalDistance + 100
        end
        
        previousWaypoint = waypoint
    end
    
    route.distance = totalDistance
    route.estimated_time = math.ceil(totalDistance / 10)
    
    return route.estimated_time
end

function QuestRouteEngine:GetNextWaypoint(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return nil
    end
    
    for _, waypoint in ipairs(route.waypoints) do
        if not waypoint.visited then
            return waypoint
        end
    end
    
    return nil
end

function QuestRouteEngine:GetCurrentWaypointIndex(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return 0
    end
    
    for i, waypoint in ipairs(route.waypoints) do
        if not waypoint.visited then
            return i
        end
    end
    
    return #route.waypoints + 1
end

function QuestRouteEngine:GetRouteProgress(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route or #route.waypoints == 0 then
        return 0
    end
    
    local visited = 0
    
    for _, waypoint in ipairs(route.waypoints) do
        if waypoint.visited then
            visited = visited + 1
        end
    end
    
    return math.floor((visited / #route.waypoints) * 100)
end

function QuestRouteEngine:IsRouteCompleted(questId, routeId)
    local progress = self:GetRouteProgress(questId, routeId)
    return progress == 100
end

function QuestRouteEngine:ClearRoute(questId, routeId)
    local route = self:GetRoute(questId, routeId)
    if not route then
        return false
    end
    
    route.waypoints = {}
    route.distance = 0
    route.estimated_time = 0
    
    self:Log("Cleared waypoints for route: " .. routeId)
    
    return true
end

function QuestRouteEngine:DeleteRoute(questId, routeId)
    if not questId or not self.routes[questId] then
        return false
    end
    
    for i, route in ipairs(self.routes[questId]) do
        if route.id == routeId then
            table.remove(self.routes[questId], i)
            self:Log("Deleted route: " .. routeId)
            return true
        end
    end
    
    return false
end

function QuestRouteEngine:GetStatus()
    local totalRoutes = 0
    local activeRoutes = 0
    local totalWaypoints = 0
    
    for _, routes in pairs(self.routes) do
        for _, route in ipairs(routes) do
            totalRoutes = totalRoutes + 1
            if route.active then
                activeRoutes = activeRoutes + 1
            end
            totalWaypoints = totalWaypoints + #route.waypoints
        end
    end
    
    return {
        enabled = self.enabled,
        total_routes = totalRoutes,
        active_routes = activeRoutes,
        total_waypoints = totalWaypoints,
    }
end

function QuestRouteEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestRouteEngine] " .. message)
    else
        print("[QuestRouteEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTROUTE1 = "/questroute"
    SlashCmdList["QUESTROUTE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local questId = tonumber(args)
            if questId then
                local routes = QuestRouteEngine:GetRoutesForQuest(questId)
                print("Routes for Quest " .. questId .. ": " .. #routes)
                for i, route in ipairs(routes) do
                    print("  [" .. i .. "] " .. route.id .. " (" .. #route.waypoints .. " waypoints)")
                    print("       Distance: " .. math.floor(route.distance) .. " | Time: " .. route.estimated_time .. "s")
                end
            else
                print("Usage: /questroute list <questId>")
            end
        elseif cmd == "waypoints" then
            local parts = args:match("(%d+)%s+(%S+)")
            local questId = tonumber(parts:match("^(%d+)") or "0")
            local routeId = args:match("%s(%S+)$") or ""
            
            if questId > 0 and routeId ~= "" then
                local waypoints = QuestRouteEngine:GetWaypoints(questId, routeId)
                print("Waypoints for Route " .. routeId .. ": " .. #waypoints)
                for i, wp in ipairs(waypoints) do
                    local status = wp.visited and "✓" or " "
                    print("  [" .. status .. "] " .. i .. ". Map " .. wp.map_id .. " (" .. wp.type .. ")")
                end
            else
                print("Usage: /questroute waypoints <questId> <routeId>")
            end
        elseif cmd == "progress" then
            local parts = args:match("(%d+)%s+(%S+)")
            local questId = tonumber(parts:match("^(%d+)") or "0")
            local routeId = args:match("%s(%S+)$") or ""
            
            if questId > 0 and routeId ~= "" then
                local progress = QuestRouteEngine:GetRouteProgress(questId, routeId)
                local index = QuestRouteEngine:GetCurrentWaypointIndex(questId, routeId)
                local route = QuestRouteEngine:GetRoute(questId, routeId)
                
                print("Route Progress: " .. progress .. "%")
                print("Current Waypoint: " .. index .. "/" .. #route.waypoints)
            else
                print("Usage: /questroute progress <questId> <routeId>")
            end
        elseif cmd == "status" then
            local status = QuestRouteEngine:GetStatus()
            print("Quest Route System:")
            print("  Total Routes: " .. status.total_routes)
            print("  Active Routes: " .. status.active_routes)
            print("  Total Waypoints: " .. status.total_waypoints)
        else
            print("Quest Route Commands:")
            print("  /questroute list <questId> - List routes for quest")
            print("  /questroute waypoints <questId> <routeId> - Show waypoints")
            print("  /questroute progress <questId> <routeId> - Show route progress")
            print("  /questroute status - Show system status")
        end
    end
end

return QuestRouteEngine
