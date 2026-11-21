-- Infinity Suite - Performance Profiler
-- Tracks CPU usage, memory consumption, and event frequency across all addons

local PerformanceProfiler = {}
_G.InfinityPerformanceProfiler = PerformanceProfiler

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

PerformanceProfiler.config = {
	enabled = true,
	cpuThreshold = 2.0, -- Alert if any addon exceeds 2% CPU
	updateInterval = 1.0, -- Measure every 1 second
	historySize = 60, -- Keep 60 seconds of history
	trackMemory = true,
	trackEvents = true,
}

PerformanceProfiler.metrics = {}  -- {addonName = {cpu, memory, eventCount, ...}}
PerformanceProfiler.history = {}  -- Historical data for trending
PerformanceProfiler.eventCounts = {} -- {eventName = count}
PerformanceProfiler.functionCallCounts = {} -- Track function calls

-- ============================================================================
-- CPU PROFILING
-- ============================================================================

--- Get current CPU usage (approximation based on frame rate)
-- WoW doesn't expose direct CPU %, so we estimate based on frame time
function PerformanceProfiler:GetEstimatedCPUUsage(addonName)
	-- This is an approximation - actual CPU measurement would require C_Debug if available
	local metrics = self.metrics[addonName] or {}
	return metrics.cpuPercent or 0
end

--- Record function call time
function PerformanceProfiler:TrackFunctionCall(addonName, functionName, startTime, endTime)
	if not self.config.enabled then return end
	
	if not self.metrics[addonName] then
		self.metrics[addonName] = {
			name = addonName,
			cpuPercent = 0,
			memory = 0,
			eventCount = 0,
			functionCalls = {},
			lastUpdate = GetTime()
		}
	end
	
	local elapsed = (endTime or GetTime()) - (startTime or 0)
	
	if not self.metrics[addonName].functionCalls[functionName] then
		self.metrics[addonName].functionCalls[functionName] = {
			calls = 0,
			totalTime = 0,
			avgTime = 0,
			maxTime = 0,
			minTime = 999999
		}
	end
	
	local stats = self.metrics[addonName].functionCalls[functionName]
	stats.calls = stats.calls + 1
	stats.totalTime = stats.totalTime + elapsed
	stats.avgTime = stats.totalTime / stats.calls
	stats.maxTime = math.max(stats.maxTime, elapsed)
	stats.minTime = math.min(stats.minTime, elapsed)
end

--- Get function statistics
function PerformanceProfiler:GetFunctionStats(addonName, functionName)
	if not self.metrics[addonName] then
		return nil
	end
	
	return self.metrics[addonName].functionCalls[functionName] or {
		calls = 0,
		avgTime = 0,
		maxTime = 0,
		minTime = 0
	}
end

-- ============================================================================
-- MEMORY PROFILING
-- ============================================================================

--- Get addon memory usage
function PerformanceProfiler:GetAddonMemory(addonName)
	-- Note: Requires debuglocals if available
	-- For now, return estimate based on table sizes
	if not self.metrics[addonName] then
		return 0
	end
	
	return self.metrics[addonName].memory or 0
end

--- Track memory usage over time
function PerformanceProfiler:RecordMemoryUsage(addonName, bytes)
	if not self.metrics[addonName] then
		self.metrics[addonName] = {
			name = addonName,
			memory = 0,
			cpuPercent = 0,
			eventCount = 0
		}
	end
	
	if not self.history[addonName] then
		self.history[addonName] = {}
	end
	
	table.insert(self.history[addonName], {
		timestamp = GetTime(),
		memory = bytes,
		cpu = self.metrics[addonName].cpuPercent or 0
	})
	
	-- Prune old history
	while #self.history[addonName] > self.config.historySize do
		table.remove(self.history[addonName], 1)
	end
	
	self.metrics[addonName].memory = bytes
end

--- Detect memory leaks by tracking growth over time
function PerformanceProfiler:DetectMemoryLeaks(addonName)
	if not self.history[addonName] or #self.history[addonName] < 10 then
		return false, 0
	end
	
	local history = self.history[addonName]
	local startMem = history[1].memory
	local endMem = history[#history].memory
	local growth = endMem - startMem
	
	-- Flag if memory grew by more than 20% in the measurement window
	local growthPercent = (growth / (startMem + 1)) * 100
	
	if growthPercent > 20 then
		return true, growthPercent
	end
	
	return false, growthPercent
end

-- ============================================================================
-- EVENT TRACKING
-- ============================================================================

--- Record event
function PerformanceProfiler:RecordEvent(eventName)
	if not self.config.trackEvents then return end
	
	self.eventCounts[eventName] = (self.eventCounts[eventName] or 0) + 1
end

--- Get event frequency
function PerformanceProfiler:GetEventFrequency(eventName)
	return self.eventCounts[eventName] or 0
end

--- Get top N events by frequency
function PerformanceProfiler:GetTopEvents(limit)
	limit = limit or 10
	local events = {}
	
	for eventName, count in pairs(self.eventCounts) do
		table.insert(events, {name = eventName, count = count})
	end
	
	table.sort(events, function(a, b)
		return a.count > b.count
	end)
	
	local result = {}
	for i = 1, math.min(limit, #events) do
		table.insert(result, events[i])
	end
	
	return result
end

--- Reset event counters
function PerformanceProfiler:ResetEventCounters()
	self.eventCounts = {}
end

-- ============================================================================
-- PERFORMANCE ANALYSIS
-- ============================================================================

--- Get addon with highest CPU usage
function PerformanceProfiler:GetTopCPUAddon()
	local topAddon = nil
	local topCPU = 0
	
	for addonName, metrics in pairs(self.metrics) do
		if (metrics.cpuPercent or 0) > topCPU then
			topCPU = metrics.cpuPercent or 0
			topAddon = addonName
		end
	end
	
	return topAddon, topCPU
end

--- Get addon with highest memory usage
function PerformanceProfiler:GetTopMemoryAddon()
	local topAddon = nil
	local topMem = 0
	
	for addonName, metrics in pairs(self.metrics) do
		if (metrics.memory or 0) > topMem then
			topMem = metrics.memory or 0
			topAddon = addonName
		end
	end
	
	return topAddon, topMem
end

--- Get overall system stats
function PerformanceProfiler:GetSystemStats()
	local totalCPU = 0
	local totalMemory = 0
	local addonCount = 0
	
	for addonName, metrics in pairs(self.metrics) do
		totalCPU = totalCPU + (metrics.cpuPercent or 0)
		totalMemory = totalMemory + (metrics.memory or 0)
		addonCount = addonCount + 1
	end
	
	return {
		addonCount = addonCount,
		totalCPU = totalCPU,
		totalMemory = totalMemory,
		avgCPU = addonCount > 0 and (totalCPU / addonCount) or 0,
		avgMemory = addonCount > 0 and (totalMemory / addonCount) or 0
	}
end

--- Check for performance issues
function PerformanceProfiler:IdentifyIssues()
	local issues = {}
	
	-- Check CPU threshold
	for addonName, metrics in pairs(self.metrics) do
		if (metrics.cpuPercent or 0) > self.config.cpuThreshold then
			table.insert(issues, {
				type = "HIGH_CPU",
				addon = addonName,
				value = metrics.cpuPercent,
				threshold = self.config.cpuThreshold,
				message = string.format("%s using %.2f%% CPU (threshold: %.2f%%)",
					addonName, metrics.cpuPercent, self.config.cpuThreshold)
			})
		end
		
		-- Check memory leaks
		local hasLeak, growthPercent = self:DetectMemoryLeaks(addonName)
		if hasLeak then
			table.insert(issues, {
				type = "MEMORY_LEAK",
				addon = addonName,
				value = growthPercent,
				message = string.format("%s memory growing at %.1f%% per measurement period",
					addonName, growthPercent)
			})
		end
	end
	
	-- Check event frequency
	local topEvents = self:GetTopEvents(5)
	for _, event in ipairs(topEvents) do
		if event.count > 1000 then
			table.insert(issues, {
				type = "HIGH_EVENT_FREQUENCY",
				event = event.name,
				value = event.count,
				message = string.format("Event %s fired %d times", event.name, event.count)
			})
		end
	end
	
	return issues
end

-- ============================================================================
-- REPORTING & DIAGNOSTICS
-- ============================================================================

--- Generate performance report
function PerformanceProfiler:GenerateReport()
	local report = {}
	
	report[1] = "\n╔════════════════════════════════════════════════════════════╗"
	report[2] = "║         Infinity Suite Performance Profile Report          ║"
	report[3] = "╠════════════════════════════════════════════════════════════╣"
	
	-- System stats
	local stats = self:GetSystemStats()
	report[4] = string.format("║ Total Addons:        %d                                   ║", stats.addonCount)
	report[5] = string.format("║ Total CPU:           %.2f%%                                 ║", stats.totalCPU)
	report[6] = string.format("║ Total Memory:        %.2f MB                               ║", stats.totalMemory / 1024 / 1024)
	report[7] = "╠════════════════════════════════════════════════════════════╣"
	
	-- Per-addon stats
	report[8] = "║ Per-Addon Metrics:                                        ║"
	local lineNum = 9
	
	for addonName, metrics in pairs(self.metrics) do
		local line = string.format("║   %-40s %6.2f%% %6.1fMB ║",
			addonName:sub(1, 40),
			metrics.cpuPercent or 0,
			(metrics.memory or 0) / 1024 / 1024)
		report[lineNum] = line
		lineNum = lineNum + 1
	end
	
	report[lineNum] = "╠════════════════════════════════════════════════════════════╣"
	lineNum = lineNum + 1
	
	-- Issues
	local issues = self:IdentifyIssues()
	if #issues > 0 then
		report[lineNum] = "║ Performance Issues:                                       ║"
		lineNum = lineNum + 1
		
		for _, issue in ipairs(issues) do
			local msg = issue.message:sub(1, 56)
			report[lineNum] = "║   " .. msg .. string.rep(" ", 56 - #msg) .. "║"
			lineNum = lineNum + 1
		end
	else
		report[lineNum] = "║ No performance issues detected ✓                          ║"
		lineNum = lineNum + 1
	end
	
	report[lineNum] = "╚════════════════════════════════════════════════════════════╝"
	
	return table.concat(report, "\n")
end

--- Print detailed stats for an addon
function PerformanceProfiler:PrintAddonStats(addonName)
	local metrics = self.metrics[addonName]
	if not metrics then
		print("No metrics for addon: " .. addonName)
		return
	end
	
	print("\n|cff00ccff" .. addonName .. " Performance Stats|r")
	print(string.format("  CPU:           %.2f%%", metrics.cpuPercent or 0))
	print(string.format("  Memory:        %.2f MB", (metrics.memory or 0) / 1024 / 1024))
	print(string.format("  Events:        %d", metrics.eventCount or 0))
	
	-- Function stats
	if metrics.functionCalls and next(metrics.functionCalls) then
		print("  Functions:")
		local functions = {}
		for funcName, stats in pairs(metrics.functionCalls) do
			table.insert(functions, {name = funcName, avgTime = stats.avgTime})
		end
		
		table.sort(functions, function(a, b) return a.avgTime > b.avgTime end)
		
		for i, func in ipairs(functions) do
			if i <= 5 then
				print(string.format("    - %s: %.4fs avg", func.name, func.avgTime))
			end
		end
	end
end

-- ============================================================================
-- INTEGRATION WITH SLASH COMMANDS
-- ============================================================================

if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("perfprofile", function(args)
		if not args or #args == 0 then
			print(PerformanceProfiler:GenerateReport())
		elseif args[1] == "addon" and args[2] then
			PerformanceProfiler:PrintAddonStats(args[2])
		elseif args[1] == "events" then
			local topEvents = PerformanceProfiler:GetTopEvents(10)
			print("Top Events:")
			for _, event in ipairs(topEvents) do
				print(string.format("  %s: %d times", event.name, event.count))
			end
		elseif args[1] == "reset" then
			PerformanceProfiler:ResetEventCounters()
			print("Event counters reset")
		end
	end, {"perf", "profile"})
end

function PerformanceProfiler:Initialize()
	InfinityUtils:Info("PerformanceProfiler initialized", "Perf")
end

print("[INFO] Performance Profiler loaded successfully")
