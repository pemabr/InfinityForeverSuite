-- InfinityGatherRoutes Module
-- Manages and optimizes gathering routes

InfinityGatherRoutes = {}
InfinityGatherRoutes.routes = {}

function InfinityGatherRoutes:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGather", "routes", {})
	self.routes = storageData.routes or {}
	InfinityUtils:Info("GatherRoutes module initialized", "InfinityGather")
end

function InfinityGatherRoutes:CreateRoute(routeName, targetTypes, description)
	local routeId = "route_" .. InfinityUtils:GetTimeStamp()
	
	local route = {
		id = routeId,
		name = routeName,
		targetTypes = targetTypes or { "HERB" },
		description = description,
		nodes = {},
		created = InfinityUtils:GetTimeStamp(),
		efficiency = 0,
	}
	
	self.routes[routeId] = route
	self:SaveRoutes()
	InfinityMessaging:Publish("route_created", { routeName = routeName })
	
	return route
end

function InfinityGatherRoutes:AddNodeToRoute(routeId, nodeId, sequence)
	if not self.routes[routeId] then return nil end
	
	local node = {
		nodeId = nodeId,
		sequence = sequence or (#self.routes[routeId].nodes + 1),
	}
	
	table.insert(self.routes[routeId].nodes, node)
	self:SaveRoutes()
	
	return node
end

function InfinityGatherRoutes:GetOptimizedRoutes()
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

function InfinityGatherRoutes:SaveRoutes()
	InfinityStorageManager:SetFeatureSetting("InfinityGather", "routes", { routes = self.routes })
	InfinityDataManager:UpdateSourceData("InfinityGather", "routes", { routes = self.routes })
end

return InfinityGatherRoutes
