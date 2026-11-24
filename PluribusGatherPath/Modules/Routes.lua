-- Routes Module
-- Create and manage gathering routes

local PluribusRoutes = {}
_G.PluribusRoutes = PluribusRoutes

PluribusRoutes.routes = {}
PluribusRoutes.callbacks = {}

function PluribusRoutes:CreateRoute(routeName, zone, nodeType, nodes)
    local routeID = "route_" .. routeName:lower():gsub(" ", "_")
    
    self.routes[routeID] = {
        id = routeID,
        name = routeName,
        zone = zone,
        type = nodeType,
        nodes = nodes or {},
        created_time = GetTime(),
        total_distance = 0,
        estimated_time = 0,
        profit_estimate = 0,
    }
    
    self:TriggerCallback("route_created", routeName)
    return routeID
end

function PluribusRoutes:GetRoute(routeID)
    return self.routes[routeID]
end

function PluribusRoutes:GetRoutes()
    return self.routes
end

function PluribusRoutes:GetRoutesByZone(zone)
    local result = {}
    
    for routeID, route in pairs(self.routes) do
        if route.zone == zone then
            table.insert(result, route)
        end
    end
    
    return result
end

function PluribusRoutes:AddNodeToRoute(routeID, node)
    local route = self.routes[routeID]
    if not route then return false end
    
    table.insert(route.nodes, node)
    return true
end

function PluribusRoutes:RemoveRoute(routeID)
    self.routes[routeID] = nil
    return true
end

function PluribusRoutes:ExportRoute(routeID)
    local route = self.routes[routeID]
    if not route then return nil end
    
    return {
        name = route.name,
        zone = route.zone,
        type = route.type,
        nodes = route.nodes,
        distance = route.total_distance,
        time = route.estimated_time,
    }
end

function PluribusRoutes:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusRoutes:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusRoutes
