-- InfinityDataCollector Network Sharing Module
-- Secure P2P data sharing between addon users

InfinityDataCollectorNetwork = {
	peers = {},
	pendingRequests = {},
	shareEnabled = true,
	shareFrequency = 300,  -- seconds between auto-shares
	lastShare = 0,
	requestTimeout = 30,   -- seconds
	maxPeers = 50,         -- max concurrent peers
	messageQueue = {},
}

-- Add a peer connection
function InfinityDataCollectorNetwork:AddPeer(playerName, realm)
	if not playerName or playerName == "" then
		return false
	end
	
	local peerKey = string.format("%s-%s", playerName, realm or GetRealmName())
	
	if not self.peers[peerKey] then
		if self:GetPeerCount() >= self.maxPeers then
			InfinityUtils:Warning("Max peers reached, cannot add " .. playerName, "Network")
			return false
		end
		
		self.peers[peerKey] = {
			name = playerName,
			realm = realm or GetRealmName(),
			lastContact = time(),
			dataVersion = 0,
			trust = 0,
			active = true,
		}
		
		InfinityUtils:Info("Peer added: " .. playerName, "Network")
		return true
	end
	
	self.peers[peerKey].lastContact = time()
	return true
end

-- Remove a peer connection
function InfinityDataCollectorNetwork:RemovePeer(playerName, realm)
	local peerKey = string.format("%s-%s", playerName, realm or GetRealmName())
	self.peers[peerKey] = nil
	InfinityUtils:Info("Peer removed: " .. playerName, "Network")
	return true
end

-- Get peer count
function InfinityDataCollectorNetwork:GetPeerCount()
	local count = 0
	for _ in pairs(self.peers) do count = count + 1 end
	return count
end

-- Get list of all peers
function InfinityDataCollectorNetwork:GetPeers()
	local peerList = {}
	for peerKey, peerData in pairs(self.peers) do
		if peerData.active then
			table.insert(peerList, peerData)
		end
	end
	return peerList
end

-- Request data from a peer
function InfinityDataCollectorNetwork:RequestDataFromPeer(playerName, realm, dataTypes)
	if not playerName then
		return false
	end
	
	local peerKey = string.format("%s-%s", playerName, realm or GetRealmName())
	
	if not self.peers[peerKey] then
		return false
	end
	
	local requestID = string.format("req_%d_%s", time(), playerName)
	
	self.pendingRequests[requestID] = {
		peerKey = peerKey,
		player = playerName,
		realm = realm or GetRealmName(),
		dataTypes = dataTypes or {"quests", "mobs", "nodes"},
		requestTime = time(),
		status = "pending",
		timeout = time() + self.requestTimeout,
		data = nil,
	}
	
	-- Send request via messaging system
	if InfinityMessaging then
		InfinityMessaging:Publish("DataCollector:RequestData", requestID, playerName, dataTypes)
	end
	
	InfinityUtils:Debug("Data request sent to: " .. playerName, "Network")
	return requestID
end

-- Handle data request from peer (should be called by messaging system)
function InfinityDataCollectorNetwork:HandleDataRequest(requestID, fromPlayer, dataTypes)
	if not self.shareEnabled then
		return false
	end
	
	-- Get our data
	local exportedData = InfinityDataCollectorCore:ExportData()
	
	-- Sanitize based on guild membership
	local sanitized = InfinityDataCollectorPrivacy:SanitizeDataExport(exportedData, fromPlayer)
	
	-- Send back only requested data types
	local response = {
		requestID = requestID,
		fromPlayer = UnitName("player"),
		realm = GetRealmName(),
		exportTime = time(),
		version = InfinityDataCollectorCore.version,
	}
	
	for _, dataType in ipairs(dataTypes or {}) do
		if sanitized[dataType] then
			response[dataType] = sanitized[dataType]
		end
	end
	
	-- Send response
	if InfinityMessaging then
		InfinityMessaging:Publish("DataCollector:DataResponse", requestID, response)
	end
	
	InfinityUtils:Debug("Data response sent to: " .. fromPlayer, "Network")
	return true
end

-- Handle data response from peer
function InfinityDataCollectorNetwork:HandleDataResponse(requestID, responseData)
	if not self.pendingRequests[requestID] then
		return false
	end
	
	local request = self.pendingRequests[requestID]
	request.data = responseData
	request.status = "complete"
	request.completeTime = time()
	
	-- Merge data with our own
	self:MergeReceivedData(responseData)
	
	InfinityUtils:Info("Data received from: " .. request.player, "Network")
	return true
end

-- Merge received data with our own
function InfinityDataCollectorNetwork:MergeReceivedData(receivedData)
	if not receivedData then
		return false
	end
	
	pcall(function()
		-- Merge quests
		if receivedData.quests then
			for questID, questData in pairs(receivedData.quests) do
				if questID and type(questData) == "table" then
					local existing = InfinityDataCollectorCore.gatheredData.quests[questID]
					if not existing then
						InfinityDataCollectorCore.gatheredData.quests[questID] = questData
					else
						-- Merge update timestamp
						existing.lastUpdated = math.max(existing.lastUpdated or 0, questData.lastUpdated or 0)
						existing.instances = (existing.instances or 0) + (questData.instances or 1)
					end
				end
			end
		end
		
		-- Merge mobs
		if receivedData.mobs then
			for mobID, mobData in pairs(receivedData.mobs) do
				if mobID and type(mobData) == "table" then
					local existing = InfinityDataCollectorCore.gatheredData.mobs[mobID]
					if not existing then
						InfinityDataCollectorCore.gatheredData.mobs[mobID] = mobData
					else
						existing.sightings = (existing.sightings or 0) + (mobData.sightings or 1)
					end
				end
			end
		end
		
		-- Merge nodes
		if receivedData.nodes then
			for nodeKey, nodeData in pairs(receivedData.nodes) do
				if nodeKey and type(nodeData) == "table" then
					local existing = InfinityDataCollectorCore.gatheredData.nodes[nodeKey]
					if not existing then
						InfinityDataCollectorCore.gatheredData.nodes[nodeKey] = nodeData
					else
						existing.sightings = (existing.sightings or 0) + (nodeData.sightings or 1)
					end
				end
			end
		end
		
		-- Merge drops
		if receivedData.drops then
			for dropKey, dropData in pairs(receivedData.drops) do
				if dropKey and type(dropData) == "table" then
					local existing = InfinityDataCollectorCore.gatheredData.drops[dropKey]
					if not existing then
						InfinityDataCollectorCore.gatheredData.drops[dropKey] = dropData
					else
						existing.sightings = (existing.sightings or 0) + (dropData.sightings or 1)
					end
				end
			end
		end
		
		-- Merge NPCs
		if receivedData.npcs then
			for npcID, npcData in pairs(receivedData.npcs) do
				if npcID and type(npcData) == "table" then
					local existing = InfinityDataCollectorCore.gatheredData.npcs[npcID]
					if not existing then
						InfinityDataCollectorCore.gatheredData.npcs[npcID] = npcData
					else
						existing.sightings = (existing.sightings or 0) + (npcData.sightings or 1)
					end
				end
			end
		end
	end)
	
	return true
end

-- Auto-share data to all connected peers
function InfinityDataCollectorNetwork:AutoShareData()
	if not self.shareEnabled then
		return false
	end
	
	local now = time()
	if (now - self.lastShare) < self.shareFrequency then
		return false
	end
	
	local peers = self:GetPeers()
	local dataTypes = {"quests", "mobs", "nodes"}
	
	for _, peerData in ipairs(peers) do
		self:RequestDataFromPeer(peerData.name, peerData.realm, dataTypes)
	end
	
	self.lastShare = now
	return true
end

-- Enable/disable network sharing
function InfinityDataCollectorNetwork:SetSharingEnabled(enabled)
	self.shareEnabled = not not enabled
	return self.shareEnabled
end

-- Set share frequency
function InfinityDataCollectorNetwork:SetShareFrequency(seconds)
	if type(seconds) == "number" and seconds > 0 then
		self.shareFrequency = seconds
		return true
	end
	return false
end

-- Get status of a pending request
function InfinityDataCollectorNetwork:GetRequestStatus(requestID)
	local request = self.pendingRequests[requestID]
	if not request then
		return nil
	end
	
	-- Check timeout
	if request.status == "pending" and time() > request.timeout then
		request.status = "timeout"
	end
	
	return {
		status = request.status,
		player = request.player,
		realm = request.realm,
		completeTime = request.completeTime,
		dataReceived = request.data ~= nil,
	}
end

-- Clean up old requests
function InfinityDataCollectorNetwork:CleanupRequests()
	local now = time()
	for requestID, request in pairs(self.pendingRequests) do
		if now > (request.timeout + 60) then  -- Remove 60 seconds after timeout
			self.pendingRequests[requestID] = nil
		end
	end
end

-- Get network statistics
function InfinityDataCollectorNetwork:GetNetworkStats()
	return {
		peerCount = self:GetPeerCount(),
		shareEnabled = self.shareEnabled,
		shareFrequency = self.shareFrequency,
		lastShare = self.lastShare,
		pendingRequests = self:CountTable(self.pendingRequests),
	}
end

function InfinityDataCollectorNetwork:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end
