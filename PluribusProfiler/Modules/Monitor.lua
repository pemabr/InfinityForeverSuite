-- PluribusProfiler Monitoring Module
-- Real-time monitoring and diagnostics

PluribusProfilerMonitor = {
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
function PluribusProfilerMonitor:Initialize()
	if self.updateFrame then
		return
	end
	
	self.updateFrame = CreateFrame("Frame")
	self.updateFrame:SetScript("OnUpdate", function(self, elapsed)
		PluribusProfilerMonitor:OnUpdate(elapsed)
	end)
	
	PluribusUtils:Info("Performance monitoring initialized", "Profiler")
end

-- Main monitoring loop
function PluribusProfilerMonitor:OnUpdate(elapsed)
	local now = time()
	
	-- Check addon metrics every sampling interval
	local metrics = PluribusProfilerCore:GetAllMetrics()
	
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
				string.format("Memory critical: %s", PluribusProfilerCore:FormatKB(addon.memory.current)))
		elseif addon.memory.current > self.thresholds.memoryWarning then
			self:CreateAlert(addonName, "warning_memory",
				string.format("Memory warning: %s", PluribusProfilerCore:FormatKB(addon.memory.current)))
		end
	end
end

-- Create a performance alert
function PluribusProfilerMonitor:CreateAlert(addonName, alertType, message)
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
function PluribusProfilerMonitor:GetActiveAlerts()
	local alerts = {}
	for _, alert in pairs(self.alerts) do
		table.insert(alerts, alert)
	end
	return alerts
end

-- Get alerts for specific addon
function PluribusProfilerMonitor:GetAddonAlerts(addonName)
	local alerts = {}
	for _, alert in pairs(self.alerts) do
		if alert.addon == addonName then
			table.insert(alerts, alert)
		end
	end
	return alerts
end

-- Clear alerts
function PluribusProfilerMonitor:ClearAlerts()
	self.alerts = {}
end

-- Set CPU warning threshold
function PluribusProfilerMonitor:SetCPUWarning(milliseconds)
	if type(milliseconds) == "number" and milliseconds > 0 then
		self.thresholds.cpuWarning = milliseconds
		return true
	end
	return false
end

-- Set CPU critical threshold
function PluribusProfilerMonitor:SetCPUCritical(milliseconds)
	if type(milliseconds) == "number" and milliseconds > 0 then
		self.thresholds.cpuCritical = milliseconds
		return true
	end
	return false
end

-- Set memory warning threshold
function PluribusProfilerMonitor:SetMemoryWarning(kilobytes)
	if type(kilobytes) == "number" and kilobytes > 0 then
		self.thresholds.memoryWarning = kilobytes
		return true
	end
	return false
end

-- Set memory critical threshold
function PluribusProfilerMonitor:SetMemoryCritical(kilobytes)
	if type(kilobytes) == "number" and kilobytes > 0 then
		self.thresholds.memoryCritical = kilobytes
		return true
	end
	return false
end

-- Get performance report
function PluribusProfilerMonitor:GenerateReport()
	local topCPU = PluribusProfilerCore:GetTopCPUConsumers(5)
	local topMemory = PluribusProfilerCore:GetTopMemoryConsumers(5)
	local systemMetrics = PluribusProfilerCore:GetSystemMetrics()
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
function PluribusProfilerMonitor:ExportReportAsText()
	local report = self:GenerateReport()
	local text = ""
	
	text = text .. "┌─ PLURIBUS PROFILER REPORT ─────────────────────┐\n"
	text = text .. string.format("│ Time: %s\n", date("%Y-%m-%d %H:%M:%S", report.timestamp))
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
			i, addon.name, PluribusProfilerCore:FormatKB(addon.memory))
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
function PluribusProfilerMonitor:Start()
	self:Initialize()
	PluribusUtils:Info("Performance monitoring started", "Profiler")
end

-- Stop monitoring
function PluribusProfilerMonitor:Stop()
	if self.updateFrame then
		self.updateFrame:Hide()
	end
	PluribusUtils:Info("Performance monitoring stopped", "Profiler")
end

-- Get addon diagnostics
function PluribusProfilerMonitor:GetAddonDiagnostics(addonName)
	local metrics = PluribusProfilerCore:GetAddonMetrics(addonName)
	if not metrics then
		return nil
	end
	
	local diagnostics = {
		name = metrics.name,
		version = metrics.version,
		status = metrics.status,
		uptime = PluribusProfilerCore:GetAddonUptime(addonName),
		
		cpu = {
			current = PluribusProfilerCore:FormatMS(metrics.cpu.current),
			average = PluribusProfilerCore:FormatMS(metrics.cpu.avg),
			peak = PluribusProfilerCore:FormatMS(metrics.cpu.peak),
			percent = PluribusProfilerCore:GetCPUPercent(addonName),
		},
		
		memory = {
			current = PluribusProfilerCore:FormatKB(metrics.memory.current),
			peak = PluribusProfilerCore:FormatKB(metrics.memory.peak),
		},
		
		performance = {
			calls = metrics.callCount,
			errors = metrics.errorCount,
			events = PluribusProfilerCore:CountTable(metrics.events),
			frames = PluribusProfilerCore:CountTable(metrics.frames),
		},
		
		alerts = self:GetAddonAlerts(addonName),
	}
	
	return diagnostics
end
