-- InfinityGatherNodes Module
-- Tracks gathering nodes and resource locations

InfinityGatherNodes = {}
InfinityGatherNodes.nodes = {}
InfinityGatherNodes.nodeTypes = { "HERB", "ORE", "WOOD", "WATER", "GAS" }

function InfinityGatherNodes:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGather", "nodes", {})
	self.nodes = storageData.nodes or {}
	InfinityUtils:Info("GatherNodes module initialized", "InfinityGather")
end

function InfinityGatherNodes:RecordNode(nodeType, locationName, x, y, z, respawnTime)
	local nodeId = "node_" .. InfinityUtils:GetTimeStamp()
	
	local node = {
		id = nodeId,
		type = nodeType or "HERB",
		location = locationName,
		x = x or 0,
		y = y or 0,
		z = z or 0,
		respawnTime = respawnTime or 300,
		lastSeen = InfinityUtils:GetTimeStamp(),
		timesFound = 1,
	}
	
	self.nodes[nodeId] = node
	self:SaveNodes()
	InfinityMessaging:Publish("node_found", { type = nodeType, location = locationName })
	
	return node
end

function InfinityGatherNodes:GetNodesByType(nodeType)
	local result = {}
	for nodeId, node in pairs(self.nodes) do
		if node.type == nodeType then
			table.insert(result, node)
		end
	end
	return result
end

function InfinityGatherNodes:GetNodesByLocation(locationName)
	local result = {}
	for nodeId, node in pairs(self.nodes) do
		if node.location == locationName then
			table.insert(result, node)
		end
	end
	return result
end

function InfinityGatherNodes:SaveNodes()
	InfinityStorageManager:SetFeatureSetting("InfinityGather", "nodes", { nodes = self.nodes })
	InfinityDataManager:UpdateSourceData("InfinityGather", "nodes", { nodes = self.nodes })
end

return InfinityGatherNodes
