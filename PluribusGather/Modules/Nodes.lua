-- PluribusGatherNodes Module
-- Tracks gathering nodes and resource locations

PluribusGatherNodes = {}
PluribusGatherNodes.nodes = {}
PluribusGatherNodes.nodeTypes = { "HERB", "ORE", "WOOD", "WATER", "GAS" }

function PluribusGatherNodes:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGather", "nodes", {})
	self.nodes = storageData.nodes or {}
	PluribusUtils:Info("GatherNodes module initialized", "PluribusGather")
end

function PluribusGatherNodes:RecordNode(nodeType, locationName, x, y, z, respawnTime)
	local nodeId = "node_" .. PluribusUtils:GetTimeStamp()
	
	local node = {
		id = nodeId,
		type = nodeType or "HERB",
		location = locationName,
		x = x or 0,
		y = y or 0,
		z = z or 0,
		respawnTime = respawnTime or 300,
		lastSeen = PluribusUtils:GetTimeStamp(),
		timesFound = 1,
	}
	
	self.nodes[nodeId] = node
	self:SaveNodes()
	PluribusMessaging:Publish("node_found", { type = nodeType, location = locationName })
	
	return node
end

function PluribusGatherNodes:GetNodesByType(nodeType)
	local result = {}
	for nodeId, node in pairs(self.nodes) do
		if node.type == nodeType then
			table.insert(result, node)
		end
	end
	return result
end

function PluribusGatherNodes:GetNodesByLocation(locationName)
	local result = {}
	for nodeId, node in pairs(self.nodes) do
		if node.location == locationName then
			table.insert(result, node)
		end
	end
	return result
end

function PluribusGatherNodes:SaveNodes()
	PluribusStorageManager:SetFeatureSetting("PluribusGather", "nodes", { nodes = self.nodes })
	PluribusDataManager:UpdateSourceData("PluribusGather", "nodes", { nodes = self.nodes })
end

return PluribusGatherNodes
