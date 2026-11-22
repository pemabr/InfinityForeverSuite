InfinityProfilerMonitor = {
	snapshots = {},
	maxSnapshots = 60,
	thresholds = { cpuWarning = 2, memoryWarning = 10240 },
}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Number(value)
	value = Public(value)
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then return value end
end

local function Call(label, fn, ...)
	local ok, value = pcall(fn, ...)
	if not ok then
		InfinityUtils:Warning(label .. ": " .. tostring(value), "Profiler")
		return nil
	end
	return Public(value)
end

function InfinityProfilerMonitor:CaptureSnapshot()
	local addons = _G.C_AddOns
	local getCount = addons and addons.GetNumAddOns or _G.GetNumAddOns
	local getInfo = addons and addons.GetAddOnInfo or _G.GetAddOnInfo
	local isLoaded = addons and addons.IsAddOnLoaded or _G.IsAddOnLoaded
	if type(getCount) ~= "function" or type(getInfo) ~= "function" or type(isLoaded) ~= "function" then
		InfinityUtils:Warning("Loaded-addon API unavailable.", "Profiler")
		return nil
	end
	local count = Number(Call("Addon count unavailable", getCount))
	if not count or count ~= math.floor(count) then
		InfinityUtils:Warning("Addon count unavailable.", "Profiler")
		return nil
	end

	local memoryAvailable = type(_G.UpdateAddOnMemoryUsage) == "function" and type(_G.GetAddOnMemoryUsage) == "function"
	if memoryAvailable then
		local ok, err = pcall(_G.UpdateAddOnMemoryUsage)
		if not ok then
			InfinityUtils:Warning("Memory update failed: " .. tostring(err), "Profiler")
			memoryAvailable = false
		end
	end
	local profiler = _G.C_AddOnProfiler
	local metrics = _G.Enum and _G.Enum.AddOnProfilerMetric
	local metric = metrics and Public(metrics.RecentAverageTime)
	local enabled = profiler and type(profiler.IsEnabled) == "function"
		and Call("CPU profiler status unavailable", profiler.IsEnabled)
	local cpuAvailable = enabled == true and type(profiler.GetAddOnMetric) == "function" and type(metric) == "number"

	local snapshot = {
		time = time(), addons = {}, alerts = {}, cpuAvailable = cpuAvailable,
		memoryAvailable = memoryAvailable, unknownAddons = 0, missingMemory = 0, missingCPU = 0,
	}
	local totalMemory = 0
	for index = 1, count do
		local name = Call("Addon name unavailable", getInfo, index)
		local loaded
		if type(name) == "string" and name ~= "" then loaded = Call("Addon state unavailable", isLoaded, index) end
		if loaded == true then
			local memory, cpu
			if memoryAvailable then memory = Number(Call("Addon memory unavailable", _G.GetAddOnMemoryUsage, name)) end
			if cpuAvailable then cpu = Number(Call("Addon CPU unavailable", profiler.GetAddOnMetric, name, metric)) end
			local entry = { name = name, memory = memory, cpu = cpu }
			snapshot.addons[#snapshot.addons + 1] = entry
			if memory == nil then snapshot.missingMemory = snapshot.missingMemory + 1 else totalMemory = totalMemory + memory end
			if cpu == nil then snapshot.missingCPU = snapshot.missingCPU + 1 end
			if memory and memory > self.thresholds.memoryWarning then
				snapshot.alerts[#snapshot.alerts + 1] = { addon = name, message = "Memory: " .. InfinityProfilerCore:FormatKB(memory) }
			end
			if cpu and cpu > self.thresholds.cpuWarning then
				snapshot.alerts[#snapshot.alerts + 1] = { addon = name, message = string.format("Recent CPU: %.3f ms", cpu) }
			end
		elseif loaded ~= false then
			snapshot.unknownAddons = snapshot.unknownAddons + 1
		end
	end
	table.sort(snapshot.addons, function(a, b) return a.name:lower() < b.name:lower() end)
	if memoryAvailable and snapshot.missingMemory == 0 and snapshot.unknownAddons == 0 then snapshot.totalMemory = totalMemory end
	self.current = snapshot
	self.snapshots[#self.snapshots + 1] = snapshot
	if #self.snapshots > self.maxSnapshots then table.remove(self.snapshots, 1) end
	return snapshot
end

function InfinityProfilerMonitor:SetCPUWarning(value)
	if not Number(value) or value == 0 then return false end
	self.thresholds.cpuWarning = value
	return true
end

function InfinityProfilerMonitor:SetMemoryWarning(value)
	if not Number(value) or value == 0 then return false end
	self.thresholds.memoryWarning = value
	return true
end

function InfinityProfilerMonitor:ClearSnapshots()
	self.snapshots, self.current = {}, nil
end

function InfinityProfilerMonitor:FormatEntry(entry)
	local cpu = entry.cpu and string.format("%.3f ms", entry.cpu) or "unavailable"
	local memory = entry.memory and InfinityProfilerCore:FormatKB(entry.memory) or "unavailable"
	return entry.name .. " | CPU recent: " .. cpu .. " | Memory: " .. memory
end
