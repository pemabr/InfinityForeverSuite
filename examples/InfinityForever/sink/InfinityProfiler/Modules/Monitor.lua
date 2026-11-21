-- InfinityProfiler Monitoring Module
-- Real-time monitoring and diagnostics

InfinityProfilerMonitor = {
	monitoring = {},
	alerts = {},
	thresholds = {
		cpuWarning = 2.0,      -- ms
		cpuCritical = 5.0,     -- ms
		memoryWarning = 10240, -- 10 MB
		memoryCritical = 50 * 1024, -- 50 MB
	},
	samplingInterval = 0.5,  -- seconds
	updateFrame = nil,
}

-- Initialize monitoring
function InfinityProfilerMonitor:Initialize()
	if self.updateFrame then
		return
	end
	
	self.updateFrame = CreateFrame("Frame")
	self.updateFrame:SetScript("OnUpdate", function(self, elapsed)
		InfinityProfilerMonitor:OnUpdate(elapsed)
	end)
	
	InfinityUtils:Info("Performance monitoring initialized", "Profiler")
end

-- Main monitoring loop
function InfinityProfilerMonitor:OnUpdate(elapsed)
	local now = time()
	
	-- Check addon metrics every sampling interval
	local metrics = InfinityProfilerCore:GetAllMetrics()
	
	for addonName, addon in pairs(metrics) do
		-- Check CPU thresholds
		if addon.cpu.avg > self.thresholds.cpuCritical then
			self:CreateAlert(addonName, "critical_cpu", 
				string.format("CPU critical: %.2f ms", addon.cpu.avg))
		elseif addon.cpu.avg > self.thresholds.cpuWarning then
			self:CreateAlert(addonName, "warning_cpu",
				string.format("CPU warning: %.2f ms", addon.cpu.avg))
		end
		
		-- Check memory thresholds
		if addon.memory.current > self.thresholds.memoryCritical then
			self:CreateAlert(addonName, "critical_memory",
				string.format("Memory critical: %s", InfinityProfilerCore:FormatKB(addon.memory.current)))
		elseif addon.memory.current > self.thresholds.memoryWarning then
			self:CreateAlert(addonName, "warning_memory",
				string.format("Memory warning: %s", InfinityProfilerCore:FormatKB(addon.memory.current)))
		end
	end
end

-- Create a performance alert
function InfinityProfilerMonitor:CreateAlert(addonName, alertType, message)
	local alertKey = addonName .. "_" .. alertType
	
	if not self.alerts[alertKey] then
		self.alerts[alertKey] = {
			addon = addonName,
			type = alertType,
			message = message,
			createdAt = time(),
			count = 1,
			lastOccurrence = time(),
		}
	else
		self.alerts[alertKey].count = self.alerts[alertKey].count + 1
		self.alerts[alertKey].lastOccurrence = time()
		self.alerts[alertKey].message = message
	end
end

-- Get active alerts
function InfinityProfilerMonitor:GetActiveAlerts()
	local alerts = {}
	for _, alert in pairs(self.alerts) do
		table.insert(alerts, alert)
	end
	return alerts
end

-- Get alerts for specific addon
function InfinityProfilerMonitor:GetAddonAlerts(addonName)
	local alerts = {}
	for _, alert in pairs(self.alerts) do
		if alert.addon == addonName then
			table.insert(alerts, alert)
		end
	end
	return alerts
end

-- Clear alerts
function InfinityProfilerMonitor:ClearAlerts()
	self.alerts = {}
end

-- Set CPU warning threshold
function InfinityProfilerMonitor:SetCPUWarning(milliseconds)
	if type(milliseconds) == "number" and milliseconds > 0 then
		self.thresholds.cpuWarning = milliseconds
		return true
	end
	return false
end

-- Set CPU critical threshold
function InfinityProfilerMonitor:SetCPUCritical(milliseconds)
	if type(milliseconds) == "number" and milliseconds > 0 then
		self.thresholds.cpuCritical = milliseconds
		return true
	end
	return false
end

-- Set memory warning threshold
function InfinityProfilerMonitor:SetMemoryWarning(kilobytes)
	if type(kilobytes) == "number" and kilobytes > 0 then
		self.thresholds.memoryWarning = kilobytes
		return true
	end
	return false
end

-- Set memory critical threshold
function InfinityProfilerMonitor:SetMemoryCritical(kilobytes)
	if type(kilobytes) == "number" and kilobytes > 0 then
		self.thresholds.memoryCritical = kilobytes
		return true
	end
	return false
end

-- Get performance report
function InfinityProfilerMonitor:GenerateReport()
	local topCPU = InfinityProfilerCore:GetTopCPUConsumers(5)
	local topMemory = InfinityProfilerCore:GetTopMemoryConsumers(5)
	local systemMetrics = InfinityProfilerCore:GetSystemMetrics()
	local alerts = self:GetActiveAlerts()
	
	local report = {
		timestamp = time(),
		systemMetrics = systemMetrics,
		topCPUConsumers = topCPU,
		topMemoryConsumers = topMemory,
		activeAlerts = #alerts,
		alertDetails = alerts,
		thresholds = self.thresholds,
	}
	
	return report
end

-- Export report as text
function InfinityProfilerMonitor:ExportReportAsText()
	local report = self:GenerateReport()
	local text = ""
	
	text = text .. "┌─ INFINITY PROFILER REPORT ─────────────────────┐\n"
	text = text .. string.format("│ Time: %s\n", os.date("%Y-%m-%d %H:%M:%S", report.timestamp))
	text = text .. string.format("│ Total Addons: %d\n", report.systemMetrics.addonCount)
	text = text .. "├────────────────────────────────────────────────┤\n"
	
	text = text .. "│ TOP CPU CONSUMERS:\n"
	for i, addon in ipairs(report.topCPUConsumers) do
		text = text .. string.format("│  %d. %s: %.2f ms (%.1f%%)\n", 
			i, addon.name, addon.cpu, addon.percent)
	end
	
	text = text .. "├────────────────────────────────────────────────┤\n"
	text = text .. "│ TOP MEMORY CONSUMERS:\n"
	for i, addon in ipairs(report.topMemoryConsumers) do
		text = text .. string.format("│  %d. %s: %s\n",
			i, addon.name, InfinityProfilerCore:FormatKB(addon.memory))
	end
	
	text = text .. "├────────────────────────────────────────────────┤\n"
	text = text .. string.format("│ ACTIVE ALERTS: %d\n", report.activeAlerts)
	
	for _, alert in ipairs(report.alertDetails) do
		text = text .. string.format("│  • %s: %s (x%d)\n", alert.addon, alert.message, alert.count)
	end
	
	text = text .. "└────────────────────────────────────────────────┘\n"
	
	return text
end

-- Start monitoring
function InfinityProfilerMonitor:Start()
	self:Initialize()
	InfinityUtils:Info("Performance monitoring started", "Profiler")
end

-- Stop monitoring
function InfinityProfilerMonitor:Stop()
	if self.updateFrame then
		self.updateFrame:Hide()
	end
	InfinityUtils:Info("Performance monitoring stopped", "Profiler")
end

-- Get addon diagnostics
function InfinityProfilerMonitor:GetAddonDiagnostics(addonName)
	local metrics = InfinityProfilerCore:GetAddonMetrics(addonName)
	if not metrics then
		return nil
	end
	
	local diagnostics = {
		name = metrics.name,
		version = metrics.version,
		status = metrics.status,
		uptime = InfinityProfilerCore:GetAddonUptime(addonName),
		
		cpu = {
			current = InfinityProfilerCore:FormatMS(metrics.cpu.current),
			average = InfinityProfilerCore:FormatMS(metrics.cpu.avg),
			peak = InfinityProfilerCore:FormatMS(metrics.cpu.peak),
			percent = InfinityProfilerCore:GetCPUPercent(addonName),
		},
		
		memory = {
			current = InfinityProfilerCore:FormatKB(metrics.memory.current),
			peak = InfinityProfilerCore:FormatKB(metrics.memory.peak),
		},
		
		performance = {
			calls = metrics.callCount,
			errors = metrics.errorCount,
			events = InfinityProfilerCore:CountTable(metrics.events),
			frames = InfinityProfilerCore:CountTable(metrics.frames),
		},
		
		alerts = self:GetAddonAlerts(addonName),
	}
	
	return diagnostics
end
