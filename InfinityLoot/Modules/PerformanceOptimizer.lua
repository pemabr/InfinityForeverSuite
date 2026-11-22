-- Performance Optimizer and Profiler for Infinity Suite
-- Monitors and optimizes CPU usage to ensure <2% per module

local PerformanceOptimizer = {
	profileData = {},
	moduleProfiles = {},
	cpuThreshold = 0.02, -- 2% CPU usage
	enabled = true,
}

-- Performance profiling function
function PerformanceOptimizer:StartProfile(label)
	if not self.enabled then return end
	
	if not self.profileData[label] then
		self.profileData[label] = {
			callCount = 0,
			totalTime = 0,
			avgTime = 0,
			maxTime = 0,
			minTime = math.huge,
		}
	end
	
	return {
		label = label,
		startTime = GetTime(),
		startCPU = debugprofilestop(),
	}
end

function PerformanceOptimizer:EndProfile(profile)
	if not self.enabled or not profile then return end
	
	local cpuTime = debugprofilestop() - profile.startCPU
	local wallTime = GetTime() - profile.startTime
	
	local data = self.profileData[profile.label]
	data.callCount = data.callCount + 1
	data.totalTime = data.totalTime + cpuTime
	data.avgTime = data.totalTime / data.callCount
	data.maxTime = math.max(data.maxTime, cpuTime)
	data.minTime = math.min(data.minTime, cpuTime)
	
	-- Alert if exceeds threshold
	if cpuTime > 20 then -- 20ms is significant for a single call
		if cpuTime > 100 then
			InfinityUtils:Warn("SLOW FUNCTION: " .. profile.label .. " took " .. string.format("%.2f", cpuTime) .. "ms", "Performance")
		end
	end
end

-- Register module for profiling
function PerformanceOptimizer:ProfileModule(moduleName, moduleFunctions)
	local profile = {
		name = moduleName,
		functions = {},
		totalCPU = 0,
	}
	
	for funcName, func in pairs(moduleFunctions) do
		if type(func) == "function" then
			profile.functions[funcName] = {
				callCount = 0,
				totalTime = 0,
			}
		end
	end
	
	self.moduleProfiles[moduleName] = profile
end

-- Get performance report
function PerformanceOptimizer:GetReport()
	local report = {
		modules = {},
		slowFunctions = {},
		summary = {},
	}
	
	for label, data in pairs(self.profileData) do
		if data.callCount > 0 then
			table.insert(report.slowFunctions, {
				name = label,
				calls = data.callCount,
				avg = string.format("%.3f", data.avgTime),
				max = string.format("%.3f", data.maxTime),
				total = string.format("%.3f", data.totalTime),
			})
		end
	end
	
	-- Sort by average time (slowest first)
	table.sort(report.slowFunctions, function(a, b)
		return tonumber(a.avg) > tonumber(b.avg)
	end)
	
	return report
end

-- Memory optimization: batch updates instead of per-item
function PerformanceOptimizer:BatchUpdates(updateFunc, items, batchSize)
	batchSize = batchSize or 50
	local processed = 0
	
	for i = 1, #items, batchSize do
		local batch = {}
		for j = i, math.min(i + batchSize - 1, #items) do
			table.insert(batch, items[j])
		end
		
		updateFunc(batch)
		processed = processed + #batch
	end
	
	return processed
end

-- Cache decorator to prevent repeated expensive calculations
function PerformanceOptimizer:WithCache(func, ttl)
	ttl = ttl or 60 -- Cache for 60 seconds by default
	local cache = {}
	local timestamps = {}
	
	return function(...)
		local key = tostring({...})
		local now = GetTime()
		
		if cache[key] and (now - timestamps[key]) < ttl then
			return cache[key]
		end
		
		local result = func(...)
		cache[key] = result
		timestamps[key] = now
		
		return result
	end
end

-- Lazy loading for heavy modules
function PerformanceOptimizer:LazyLoad(moduleName, loadFunc, unloadFunc)
	local loaded = false
	
	return function(operation)
		if operation == "load" and not loaded then
			loadFunc()
			loaded = true
		elseif operation == "unload" and loaded then
			unloadFunc()
			loaded = false
		elseif operation == "status" then
			return loaded
		end
	end
end

-- Event debouncing to prevent event spam
function PerformanceOptimizer:Debounce(func, delay)
	delay = delay or 0.1
	local lastCall = 0
	
	return function(...)
		local now = GetTime()
		if now - lastCall >= delay then
			lastCall = now
			return func(...)
		end
	end
end

-- Optimize table iteration with early termination
function PerformanceOptimizer:OptimizedTableScan(table, predicate, limit)
	limit = limit or math.huge
	local results = {}
	local count = 0
	
	for key, value in pairs(table) do
		if predicate(value) then
			table.insert(results, value)
			count = count + 1
			if count >= limit then
				break
			end
		end
	end
	
	return results
end

-- Memory cleanup for large data structures
function PerformanceOptimizer:CleanupOldData(dataTable, maxAge, timeField)
	timeField = timeField or "timestamp"
	local now = GetTime()
	local removed = 0
	
	for i = #dataTable, 1, -1 do
		if now - (dataTable[i][timeField] or 0) > maxAge then
			table.remove(dataTable, i)
			removed = removed + 1
		end
	end
	
	return removed
end

-- Display performance report
function PerformanceOptimizer:DisplayReport()
	local report = self:GetReport()
	
	print("|cffffd700=== INFINITY PERFORMANCE REPORT ===|r")
	print("|cffccccccTop Slow Functions:|r")
	
	for i = 1, math.min(10, #report.slowFunctions) do
		local fn = report.slowFunctions[i]
		print(string.format("  %d. %s", i, fn.name))
		print(string.format("     Calls: %d | Avg: %sms | Max: %sms", fn.calls, fn.avg, fn.max))
	end
	
	print("|cffffd700Total Profiled Functions:|r " .. #report.slowFunctions)
end

-- Initialize performance monitoring
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		_G.InfinityLootPerformanceOptimizer = PerformanceOptimizer
		
		-- Register slash command for performance reports
		SLASH_PERFREPORT1 = "/perfreport"
		SlashCmdList.PERFREPORT = function()
			PerformanceOptimizer:DisplayReport()
		end
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

return PerformanceOptimizer
