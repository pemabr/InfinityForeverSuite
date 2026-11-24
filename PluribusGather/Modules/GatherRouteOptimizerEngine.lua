-- GatherRouteOptimizerEngine.lua - Optimal gathering route calculation
-- Part of PluribusGather addon suite
-- Calculates efficient paths between gathering nodes using distance optimization

local GatherRouteOptimizerEngine = {}
GatherRouteOptimizerEngine.enabled = false
GatherRouteOptimizerEngine.db = nil
GatherRouteOptimizerEngine.current_route = nil

-- Configuration
GatherRouteOptimizerEngine.config = {
    enabled = true,
    algorithm = "nearest_neighbor",
    max_route_distance = 10000,
}

function GatherRouteOptimizerEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    self.enabled = true
    
    self:Log("Initialized route optimizer engine")
end

function GatherRouteOptimizerEngine:CalculateRoute(nodeList, startX, startY, startZ)
    if not nodeList or #nodeList == 0 then
        return nil
    end
    
    if not startX then
        startX = 0
    end
    if not startY then
        startY = 0
    end
    if not startZ then
        startZ = 0
    end
    
    local route
    
    if self.config.algorithm == "nearest_neighbor" then
        route = self:_CalculateNearestNeighborRoute(nodeList, startX, startY, startZ)
    elseif self.config.algorithm == "distance_matrix" then
        route = self:_CalculateDistanceMatrixRoute(nodeList)
    else
        route = self:_CalculateNearestNeighborRoute(nodeList, startX, startY, startZ)
    end
    
    self.current_route = route
    
    return route
end

function GatherRouteOptimizerEngine:_CalculateNearestNeighborRoute(nodeList, startX, startY, startZ)
    if not nodeList or #nodeList == 0 then
        return nil
    end
    
    local route = {
        nodes = {},
        waypoints = {},
        total_distance = 0,
        estimated_time = 0,
    }
    
    local unvisited = {}
    for i, node in ipairs(nodeList) do
        table.insert(unvisited, {
            index = i,
            node = node,
            distance = self:_CalculateDistance(startX, startY, startZ, node.x, node.y, node.z)
        })
    end
    
    -- Sort by distance from start
    table.sort(unvisited, function(a, b)
        return a.distance < b.distance
    end)
    
    local currentX = startX
    local currentY = startY
    local currentZ = startZ
    local totalDistance = 0
    
    while #unvisited > 0 do
        -- Find nearest unvisited node
        local nearest = unvisited[1]
        
        -- Calculate distance to this node
        local distToNode = self:_CalculateDistance(currentX, currentY, currentZ, nearest.node.x, nearest.node.y, nearest.node.z)
        
        if totalDistance + distToNode > self.config.max_route_distance then
            break
        end
        
        table.insert(route.nodes, nearest.node)
        table.insert(route.waypoints, {
            x = nearest.node.x,
            y = nearest.node.y,
            z = nearest.node.z,
            distance = distToNode,
        })
        
        totalDistance = totalDistance + distToNode
        currentX = nearest.node.x
        currentY = nearest.node.y
        currentZ = nearest.node.z
        
        table.remove(unvisited, 1)
        
        -- Recalculate distances from new position
        for i = 1, #unvisited do
            unvisited[i].distance = self:_CalculateDistance(currentX, currentY, currentZ, unvisited[i].node.x, unvisited[i].node.y, unvisited[i].node.z)
        end
        
        table.sort(unvisited, function(a, b)
            return a.distance < b.distance
        end)
    end
    
    route.total_distance = totalDistance
    route.estimated_time = totalDistance / 7  -- Approximate: 7 yards per second average movement
    
    return route
end

function GatherRouteOptimizerEngine:_CalculateDistanceMatrixRoute(nodeList)
    if not nodeList or #nodeList == 0 then
        return nil
    end
    
    -- Simple greedy approximation of TSP
    -- Create distance matrix
    local n = #nodeList
    local distances = {}
    
    for i = 1, n do
        distances[i] = {}
        for j = 1, n do
            if i == j then
                distances[i][j] = 0
            else
                distances[i][j] = self:_CalculateDistance(
                    nodeList[i].x, nodeList[i].y, nodeList[i].z,
                    nodeList[j].x, nodeList[j].y, nodeList[j].z
                )
            end
        end
    end
    
    -- Greedy TSP approximation
    local route = {
        nodes = {},
        waypoints = {},
        total_distance = 0,
        estimated_time = 0,
    }
    
    local visited = {}
    local current = 1
    local totalDistance = 0
    
    for _ = 1, n do
        visited[current] = true
        table.insert(route.nodes, nodeList[current])
        table.insert(route.waypoints, {
            x = nodeList[current].x,
            y = nodeList[current].y,
            z = nodeList[current].z,
        })
        
        -- Find nearest unvisited
        local nearest = -1
        local minDist = math.huge
        
        for j = 1, n do
            if not visited[j] and distances[current][j] < minDist then
                minDist = distances[current][j]
                nearest = j
            end
        end
        
        if nearest > 0 then
            totalDistance = totalDistance + minDist
            route.waypoints[#route.waypoints].distance = minDist
            current = nearest
        end
    end
    
    route.total_distance = totalDistance
    route.estimated_time = totalDistance / 7
    
    return route
end

function GatherRouteOptimizerEngine:_CalculateDistance(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2)
end

function GatherRouteOptimizerEngine:OptimizeByNodeType(nodeDatabase, nodeType, startX, startY, startZ)
    if not nodeDatabase then
        return nil
    end
    
    local filtered = {}
    for _, node in pairs(nodeDatabase) do
        if node.type == nodeType then
            table.insert(filtered, node)
        end
    end
    
    if #filtered == 0 then
        return nil
    end
    
    return self:CalculateRoute(filtered, startX, startY, startZ)
end

function GatherRouteOptimizerEngine:OptimizeByZone(nodeDatabase, zone, startX, startY, startZ)
    if not nodeDatabase then
        return nil
    end
    
    local filtered = {}
    for _, node in pairs(nodeDatabase) do
        if node.zone == zone then
            table.insert(filtered, node)
        end
    end
    
    if #filtered == 0 then
        return nil
    end
    
    return self:CalculateRoute(filtered, startX, startY, startZ)
end

function GatherRouteOptimizerEngine:OptimizeByDistance(nodeDatabase, maxDistance, startX, startY, startZ)
    if not nodeDatabase then
        return nil
    end
    
    local filtered = {}
    for _, node in pairs(nodeDatabase) do
        local dist = self:_CalculateDistance(startX, startY, startZ, node.x, node.y, node.z)
        if dist <= maxDistance then
            table.insert(filtered, node)
        end
    end
    
    if #filtered == 0 then
        return nil
    end
    
    return self:CalculateRoute(filtered, startX, startY, startZ)
end

function GatherRouteOptimizerEngine:GetCurrentRoute()
    return self.current_route
end

function GatherRouteOptimizerEngine:PrintRoute(route)
    if not route then
        self:Log("No route to print")
        return
    end
    
    self:Log("Route with " .. #route.nodes .. " nodes")
    self:Log("Total distance: " .. math.floor(route.total_distance) .. " yards")
    self:Log("Estimated time: " .. math.floor(route.estimated_time) .. " seconds")
    
    for i, waypoint in ipairs(route.waypoints) do
        self:Log("  " .. i .. ": (" .. math.floor(waypoint.x) .. ", " .. math.floor(waypoint.y) .. ") - " .. 
                 (waypoint.distance and math.floor(waypoint.distance) or "start") .. " yards")
    end
end

function GatherRouteOptimizerEngine:ExportRouteAsWaypoints(route)
    if not route then
        return nil
    end
    
    local waypoints = {}
    for _, waypoint in ipairs(route.waypoints) do
        table.insert(waypoints, {
            x = waypoint.x,
            y = waypoint.y,
            z = waypoint.z,
        })
    end
    
    return waypoints
end

function GatherRouteOptimizerEngine:SetAlgorithm(algorithm)
    if algorithm == "nearest_neighbor" or algorithm == "distance_matrix" then
        self.config.algorithm = algorithm
        self:Log("Route algorithm set to " .. algorithm)
        return true
    end
    
    return false
end

function GatherRouteOptimizerEngine:GetStatus()
    return {
        enabled = self.enabled,
        algorithm = self.config.algorithm,
        current_route_nodes = self.current_route and #self.current_route.nodes or 0,
        current_route_distance = self.current_route and self.current_route.total_distance or 0,
    }
end

function GatherRouteOptimizerEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherRouteOptimizerEngine] " .. message)
    else
        print("[GatherRouteOptimizerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERROUTE1 = "/gatherroute"
    SlashCmdList["GATHERROUTE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "calculate" then
            if GatherRouteOptimizerEngine.current_route then
                GatherRouteOptimizerEngine:PrintRoute(GatherRouteOptimizerEngine.current_route)
            else
                print("No route calculated yet")
            end
        elseif cmd == "algorithm" then
            local algo = args ~= "" and args or "nearest_neighbor"
            if GatherRouteOptimizerEngine:SetAlgorithm(algo) then
                print("Algorithm set to " .. algo)
            else
                print("Unknown algorithm")
            end
        elseif cmd == "status" then
            local status = GatherRouteOptimizerEngine:GetStatus()
            print("Route Optimizer Status:")
            print("  Algorithm: " .. status.algorithm)
            print("  Current route nodes: " .. status.current_route_nodes)
            print("  Total distance: " .. math.floor(status.current_route_distance) .. " yards")
        else
            print("Route Optimizer Commands:")
            print("  /gatherroute calculate - Show current route")
            print("  /gatherroute algorithm [name] - Set algorithm (nearest_neighbor, distance_matrix)")
            print("  /gatherroute status - Show status")
        end
    end
end

return GatherRouteOptimizerEngine
