-- InfinityProfiler Core - Performance Profiling Engine
-- Monitors addon CPU usage, memory, and performance metrics

InfinityProfilerCore = {
	addonMetrics = {},
	frameMetrics = {},
	eventMetrics = {},
	samplingInterval = 0.1,  -- seconds
	maxSamples = 300,  -- 30 seconds of data at 0.1s intervals
	profilingEnabled = false,
	version = 1,
}

-- Register an addon for profiling
function InfinityProfilerCore:RegisterAddon(addonName, addonVersion)
	if type(addonName) ~= "string" or addonName == "" then
		return false
	end
	
	if not self.addonMetrics[addonName] then
		self.addonMetrics[addonName] = {
			name = addonName,
			version = addonVersion or "unknown",
			cpu = {
				current = 0,
				avg = 0,
				peak = 0,
				samples = {},
			},
			memory = {
				current = 0,
				peak = 0,
				samples = {},
			},
			events = {},
			frames = {},
			status = "active",
			startTime = time(),
			lastUpdate = time(),
			callCount = 0,
			errorCount = 0,
		}
		
		InfinityUtils:Info("Addon registered for profiling: " .. addonName, "Profiler")
		return true
	end
	
	return false
end

-- Record CPU metric for an addon
function InfinityProfilerCore:RecordCPU(addonName, milliseconds)
	if not self.addonMetrics[addonName] then
		return false
	end
	
	local addon = self.addonMetrics[addonName]
	addon.cpu.current = milliseconds
	addon.cpu.peak = math.max(addon.cpu.peak, milliseconds)
	
	-- Keep rolling average of last 10 samples
	table.insert(addon.cpu.samples, milliseconds)
	if #addon.cpu.samples > 10 then
		table.remove(addon.cpu.samples, 1)
	end
	
	-- Calculate average
	local sum = 0
	for _, sample in ipairs(addon.cpu.samples) do
		sum = sum + sample
	end
	addon.cpu.avg = sum / #addon.cpu.samples
	
	addon.lastUpdate = time()
	addon.callCount = (addon.callCount or 0) + 1
	
	return true
end

-- Record memory metric for an addon
function InfinityProfilerCore:RecordMemory(addonName, kilobytes)
	if not self.addonMetrics[addonName] then
		return false
	end
	
	local addon = self.addonMetrics[addonName]
	addon.memory.current = kilobytes
	addon.memory.peak = math.max(addon.memory.peak, kilobytes)
	
	-- Keep rolling average of last 10 samples
	table.insert(addon.memory.samples, kilobytes)
	if #addon.memory.samples > 10 then
		table.remove(addon.memory.samples, 1)
	end
	
	addon.lastUpdate = time()
	
	return true
end

-- Record event execution time
function InfinityProfilerCore:RecordEvent(addonName, eventName, milliseconds)
	if not self.addonMetrics[addonName] then
		return false
	end
	
	if not self.addonMetrics[addonName].events[eventName] then
		self.addonMetrics[addonName].events[eventName] = {
			name = eventName,
			calls = 0,
			totalTime = 0,
			avgTime = 0,
			peakTime = 0,
		}
	end
	
	local event = self.addonMetrics[addonName].events[eventName]
	event.calls = event.calls + 1
	event.totalTime = event.totalTime + milliseconds
	event.avgTime = event.totalTime / event.calls
	event.peakTime = math.max(event.peakTime, milliseconds)
	
	return true
end

-- Record frame execution time
function InfinityProfilerCore:RecordFrame(addonName, frameName, milliseconds)
	if not self.addonMetrics[addonName] then
		return false
	end
	
	if not self.addonMetrics[addonName].frames[frameName] then
		self.addonMetrics[addonName].frames[frameName] = {
			name = frameName,
			calls = 0,
			totalTime = 0,
			avgTime = 0,
			peakTime = 0,
		}
	end
	
	local frame = self.addonMetrics[addonName].frames[frameName]
	frame.calls = frame.calls + 1
	frame.totalTime = frame.totalTime + milliseconds
	frame.avgTime = frame.totalTime / frame.calls
	frame.peakTime = math.max(frame.peakTime, milliseconds)
	
	return true
end

-- Record error occurrence
function InfinityProfilerCore:RecordError(addonName, errorMessage)
	if not self.addonMetrics[addonName] then
		return false
	end
	
	self.addonMetrics[addonName].errorCount = (self.addonMetrics[addonName].errorCount or 0) + 1
	
	if not self.addonMetrics[addonName].errors then
		self.addonMetrics[addonName].errors = {}
	end
	
	table.insert(self.addonMetrics[addonName].errors, {
		message = errorMessage,
		time = time(),
		count = 1,
	})
	
	-- Keep only last 50 errors
	if #self.addonMetrics[addonName].errors > 50 then
		table.remove(self.addonMetrics[addonName].errors, 1)
	end
	
	return true
end

-- Get addon metrics
function InfinityProfilerCore:GetAddonMetrics(addonName)
	return self.addonMetrics[addonName]
end

-- Get all addon metrics
function InfinityProfilerCore:GetAllMetrics()
	return self.addonMetrics
end

-- Get CPU usage for addon (percentage)
function InfinityProfilerCore:GetCPUPercent(addonName)
	local addon = self.addonMetrics[addonName]
	if not addon or not addon.cpu.avg then
		return 0
	end
	
	-- Rough estimate: assume 16ms frame time (60 FPS)
	return (addon.cpu.avg / 16) * 100
end

-- Get top N CPU consumers
function InfinityProfilerCore:GetTopCPUConsumers(limit)
	limit = limit or 5
	local sorted = {}
	
	for addonName, metrics in pairs(self.addonMetrics) do
		table.insert(sorted, {
			name = addonName,
			cpu = metrics.cpu.avg or 0,
			percent = self:GetCPUPercent(addonName),
		})
	end
	
	table.sort(sorted, function(a, b)
		return a.cpu > b.cpu
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

-- Get top N memory consumers
function InfinityProfilerCore:GetTopMemoryConsumers(limit)
	limit = limit or 5
	local sorted = {}
	
	for addonName, metrics in pairs(self.addonMetrics) do
		table.insert(sorted, {
			name = addonName,
			memory = metrics.memory.current or 0,
		})
	end
	
	table.sort(sorted, function(a, b)
		return a.memory > b.memory
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

-- Get total system metrics
function InfinityProfilerCore:GetSystemMetrics()
	local totalCPU = 0
	local totalMemory = 0
	local addonCount = 0
	local highCPUAddons = 0
	
	for addonName, metrics in pairs(self.addonMetrics) do
		totalCPU = totalCPU + (metrics.cpu.avg or 0)
		totalMemory = totalMemory + (metrics.memory.current or 0)
		addonCount = addonCount + 1
		
		if (metrics.cpu.avg or 0) > 1 then  -- > 1ms
			highCPUAddons = highCPUAddons + 1
		end
	end
	
	return {
		totalCPU = totalCPU,
		totalMemory = totalMemory,
		avgCPU = totalCPU / math.max(addonCount, 1),
		avgMemory = totalMemory / math.max(addonCount, 1),
		addonCount = addonCount,
		highCPUAddons = highCPUAddons,
		totalErrors = self:CountErrors(),
	}
end

-- Count total errors
function InfinityProfilerCore:CountErrors()
	local count = 0
	for addonName, metrics in pairs(self.addonMetrics) do
		count = count + (metrics.errorCount or 0)
	end
	return count
end

-- Get addon uptime
function InfinityProfilerCore:GetAddonUptime(addonName)
	if not self.addonMetrics[addonName] then
		return 0
	end
	
	return time() - self.addonMetrics[addonName].startTime
end

-- Get addon status report
function InfinityProfilerCore:GetStatusReport(addonName)
	local addon = self.addonMetrics[addonName]
	if not addon then
		return nil
	end
	
	local uptime = self:GetAddonUptime(addonName)
	
	return {
		name = addon.name,
		version = addon.version,
		status = addon.status,
		uptime = uptime,
		cpuAvg = addon.cpu.avg or 0,
		cpuPeak = addon.cpu.peak or 0,
		cpuPercent = self:GetCPUPercent(addonName),
		memCurrent = addon.memory.current or 0,
		memPeak = addon.memory.peak or 0,
		callCount = addon.callCount or 0,
		errorCount = addon.errorCount or 0,
		eventCount = self:CountTable(addon.events),
		frameCount = self:CountTable(addon.frames),
	}
end

-- Enable/disable profiling
function InfinityProfilerCore:SetProfilingEnabled(enabled)
	self.profilingEnabled = not not enabled
	return self.profilingEnabled
end

function InfinityProfilerCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Format milliseconds to readable string
function InfinityProfilerCore:FormatMS(ms)
	if ms < 0.1 then
		return string.format("%.3f ms", ms)
	elseif ms < 1 then
		return string.format("%.2f ms", ms)
	else
		return string.format("%.1f ms", ms)
	end
end

-- Format KB to readable string
function InfinityProfilerCore:FormatKB(kb)
	if kb < 1024 then
		return string.format("%.0f KB", kb)
	elseif kb < 1024 * 1024 then
		return string.format("%.1f MB", kb / 1024)
	else
		return string.format("%.1f GB", kb / (1024 * 1024))
	end
end
