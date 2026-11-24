-- PluribusGatherRoutes Module
-- Manages and optimizes gathering routes

PluribusGatherRoutes = {}
PluribusGatherRoutes.routes = {}

function PluribusGatherRoutes:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGather", "routes", {})
	self.routes = storageData.routes or {}
	PluribusUtils:Info("GatherRoutes module initialized", "PluribusGather")
end

function PluribusGatherRoutes:CreateRoute(routeName, targetTypes, description)
	local routeId = "route_" .. PluribusUtils:GetTimeStamp()
	
	local route = {
		id = routeId,
		name = routeName,
		targetTypes = targetTypes or { "HERB" },
		description = description,
		nodes = {},
		created = PluribusUtils:GetTimeStamp(),
		efficiency = 0,
	}
	
	self.routes[routeId] = route
	self:SaveRoutes()
	PluribusMessaging:Publish("route_created", { routeName = routeName })
	
	return route
end

function PluribusGatherRoutes:AddNodeToRoute(routeId, nodeId, sequence)
	if not self.routes[routeId] then return nil end
	
	local node = {
		nodeId = nodeId,
		sequence = sequence or (#self.routes[routeId].nodes + 1),
	}
	
	table.insert(self.routes[routeId].nodes, node)
	self:SaveRoutes()
	
	return node
end

function PluribusGatherRoutes:GetOptimizedRoutes()
	local optimized = {}
	for routeId, route in pairs(self.routes) do
		table.insert(optimized, {
			id = routeId,
			name = route.name,
			nodeCount = #route.nodes,
			efficiency = route.efficiency,
		})
	end
	table.sort(optimized, function(a, b) return a.efficiency > b.efficiency end)
	return optimized
end

function PluribusGatherRoutes:SaveRoutes()
	PluribusStorageManager:SetFeatureSetting("PluribusGather", "routes", { routes = self.routes })
	PluribusDataManager:UpdateSourceData("PluribusGather", "routes", { routes = self.routes })
end

return PluribusGatherRoutes
