-- PluribusCore Data Manager
-- Centralized data aggregation and normalization

PluribusDataManager = {
	cache = {},
	callbacks = {},
	version = 1,
}

-- Register a data source (called by feature addons)
function PluribusDataManager:RegisterSource(sourceName, updateCallback)
	-- Input validation
	if type(sourceName) ~= "string" or sourceName == "" then
		PluribusUtils:Warning("RegisterSource: sourceName must be a non-empty string", "DataManager")
		return false
	end
	
	if updateCallback and type(updateCallback) ~= "function" then
		PluribusUtils:Warning("RegisterSource: updateCallback must be a function or nil", "DataManager")
		return false
	end
	
	if not self.cache[sourceName] then
		self.cache[sourceName] = {
			data = {},
			lastUpdate = nil,
			callback = updateCallback,
			enabled = false,
		}
		PluribusUtils:Info("Data source registered: " .. sourceName, "DataManager")
		return true
	end
	PluribusUtils:Warning("Data source already registered: " .. sourceName, "DataManager")
	return false
end

-- Enable/disable a data source
function PluribusDataManager:SetSourceEnabled(sourceName, enabled)
	if type(sourceName) ~= "string" or sourceName == "" then
		PluribusUtils:Warning("SetSourceEnabled: sourceName must be a non-empty string", "DataManager")
		return false
	end
	
	if self.cache[sourceName] then
		self.cache[sourceName].enabled = not not enabled
		if self.cache[sourceName].enabled then
			PluribusUtils:Info("Data source enabled: " .. sourceName, "DataManager")
		else
			PluribusUtils:Info("Data source disabled: " .. sourceName, "DataManager")
		end
		return true
	end
	PluribusUtils:Warning("SetSourceEnabled: source not found: " .. sourceName, "DataManager")
	return false
end

-- Update data from a source
function PluribusDataManager:UpdateSourceData(sourceName, data)
	if type(sourceName) ~= "string" or sourceName == "" then
		PluribusUtils:Warning("UpdateSourceData: sourceName must be a non-empty string", "DataManager")
		return false
	end
	
	if not self.cache[sourceName] then
		PluribusUtils:Warning("UpdateSourceData: source not registered: " .. sourceName, "DataManager")
		return false
	end
	
	-- Data can be any type, we'll handle it safely
	local success = pcall(function()
		self.cache[sourceName].data = PluribusUtils:DeepCopy(data)
		self.cache[sourceName].lastUpdate = PluribusUtils:GetTimeStamp()
	end)
	
	if not success then
		PluribusUtils:Warning("UpdateSourceData: failed to copy data for source: " .. sourceName, "DataManager")
		return false
	end
	
	-- Trigger callbacks for this data change
	self:TriggerCallbacks(sourceName, "UPDATED", data)
	
	return true
end

-- Get data from a source
function PluribusDataManager:GetSourceData(sourceName)
	if type(sourceName) ~= "string" or sourceName == "" then
		PluribusUtils:Warning("GetSourceData: sourceName must be a non-empty string", "DataManager")
		return nil
	end
	
	if self.cache[sourceName] then
		return self.cache[sourceName].data
	end
	return nil
end

-- Register a callback for data changes
function PluribusDataManager:RegisterCallback(sourceName, eventType, callback)
	if type(sourceName) ~= "string" or sourceName == "" then
		PluribusUtils:Warning("RegisterCallback: sourceName must be a non-empty string", "DataManager")
		return false
	end
	
	if type(eventType) ~= "string" or eventType == "" then
		PluribusUtils:Warning("RegisterCallback: eventType must be a non-empty string", "DataManager")
		return false
	end
	
	if type(callback) ~= "function" then
		PluribusUtils:Warning("RegisterCallback: callback must be a function", "DataManager")
		return false
	end
	
	if not self.callbacks[sourceName] then
		self.callbacks[sourceName] = {}
	end
	if not self.callbacks[sourceName][eventType] then
		self.callbacks[sourceName][eventType] = {}
	end
	
	table.insert(self.callbacks[sourceName][eventType], callback)
	return true
end

-- Trigger all callbacks for a data change
function PluribusDataManager:TriggerCallbacks(sourceName, eventType, data)
	if not self.callbacks[sourceName] or not self.callbacks[sourceName][eventType] then
		return
	end
	
	for _, callback in ipairs(self.callbacks[sourceName][eventType]) do
		if type(callback) == "function" then
			pcall(callback, data)
		end
	end
end

-- Get all cached data (for backup/export)
function PluribusDataManager:GetAllData()
	local result = {}
	for sourceName, sourceData in pairs(self.cache) do
		result[sourceName] = PluribusUtils:DeepCopy(sourceData.data)
	end
	return result
end

-- Get statistics about cached data
function PluribusDataManager:GetStatistics()
	local stats = {
		totalSources = 0,
		enabledSources = 0,
		totalDataPoints = 0,
		lastUpdateTime = nil,
	}
	
	for sourceName, sourceData in pairs(self.cache) do
		stats.totalSources = stats.totalSources + 1
		if sourceData.enabled then
			stats.enabledSources = stats.enabledSources + 1
		end
		
		if type(sourceData.data) == "table" then
			stats.totalDataPoints = stats.totalDataPoints + #sourceData.data
		else
			stats.totalDataPoints = stats.totalDataPoints + 1
		end
		
		if sourceData.lastUpdate then
			if not stats.lastUpdateTime or sourceData.lastUpdate > stats.lastUpdateTime then
				stats.lastUpdateTime = sourceData.lastUpdate
			end
		end
	end
	
	return stats
end

-- Clear data from a source (for cleanup)
function PluribusDataManager:ClearSourceData(sourceName)
	if self.cache[sourceName] then
		self.cache[sourceName].data = {}
		self.cache[sourceName].lastUpdate = nil
		PluribusUtils:Info("Data cleared for source: " .. sourceName, "DataManager")
		return true
	end
	return false
end

-- Clear all data (careful!)
function PluribusDataManager:ClearAllData()
	for sourceName, _ in pairs(self.cache) do
		self:ClearSourceData(sourceName)
	end
	PluribusUtils:Warning("All cached data cleared!", "DataManager")
end

return PluribusDataManager
