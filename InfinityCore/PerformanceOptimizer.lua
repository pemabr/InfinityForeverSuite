-- High Performance Optimization System
-- Monitors CPU usage, memory, and network bandwidth
-- Throttles expensive operations during combat

local PerformanceOptimizer = {
	config = {
		enableMonitoring = true,
		cpuThreshold = 2.0, -- Max CPU % per addon
		memoryThreshold = 50, -- Max MB growth
		networkThreshold = 10, -- Max KB/s during non-combat
		throttleInCombat = true, -- Reduce data sharing during combat
		profileInterval = 1.0, -- Seconds between profiling
		reportInterval = 60.0, -- Seconds between reports
	},
	
	profiling = {
		cpuUsage = {}, -- {addonName = {current = n, avg = n, peak = n}}
		memoryUsage = {}, -- {addonName = {current = n, start = n, growth = n}}
		networkUsage = {}, -- {addonName = {bytesOut = n, bytesIn = n}}
		samples = {}, -- {addonName = count}
	},
	
	metrics = {
		startTime = time(),
		lastProfileTime = time(),
		lastReportTime = time(),
		inCombat = false,
	},

	initialized = false,
	enabled = false,
}

_G.InfinityPerformanceOptimizer = PerformanceOptimizer

function PerformanceOptimizer:Initialize()
	if self.initialized then
		return
	end
	self.initialized = true
	self.enabled = true

	if InfinityUtils and InfinityUtils.Info then
		InfinityUtils:Info("Performance Optimizer initialized", "Core")
	end
	
	-- Hook combat events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	
	frame:SetScript("OnEvent", function(f, event)
		if not PerformanceOptimizer.enabled then return end
		if event == "PLAYER_REGEN_DISABLED" then
			PerformanceOptimizer.metrics.inCombat = true
			PerformanceOptimizer:OnEnterCombat()
		elseif event == "PLAYER_REGEN_ENABLED" then
			PerformanceOptimizer.metrics.inCombat = false
			PerformanceOptimizer:OnExitCombat()
		end
	end)
	
	-- Start profiling timer
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(self.config.profileInterval, function()
			if PerformanceOptimizer.enabled then
				PerformanceOptimizer:ProfileFrame()
			end
		end)
		
		-- Start reporting timer
		C_Timer.NewTicker(self.config.reportInterval, function()
			if PerformanceOptimizer.enabled then
				PerformanceOptimizer:GenerateReport()
			end
		end)
	end
end

function PerformanceOptimizer:Enable()
	self.enabled = true
	self.config.enableMonitoring = true
	if not self.initialized then
		self:Initialize()
	end
end

function PerformanceOptimizer:Disable()
	self.enabled = false
	self.config.enableMonitoring = false
end

function PerformanceOptimizer:GetReport()
	return self:GenerateReport()
end

function PerformanceOptimizer:OnEnterCombat()
	-- Reduce data transmission during combat
	if InfinityMessaging and InfinityMessaging.SetThrottleMode then
		InfinityMessaging:SetThrottleMode("aggressive")
	end
end

function PerformanceOptimizer:OnExitCombat()
	-- Resume normal data transmission
	if InfinityMessaging and InfinityMessaging.SetThrottleMode then
		InfinityMessaging:SetThrottleMode("normal")
	end
end

function PerformanceOptimizer:ProfileFrame()
	-- Get memory usage (approximation using GC stats)
	local gcMem = collectgarbage("count")
	
	-- Profile key addons
	local addons = {
		"InfinityCore",
		"InfinityDKP",
		"InfinityLoot",
		"InfinityRaid",
		"InfinityGuild",
	}
	
	for _, addonName in ipairs(addons) do
		if not self.profiling.cpuUsage[addonName] then
			self.profiling.cpuUsage[addonName] = {
				current = 0,
				avg = 0,
				peak = 0,
			}
			self.profiling.memoryUsage[addonName] = {
				current = 0,
				start = gcMem,
				growth = 0,
			}
			self.profiling.samples[addonName] = 0
		end
		
		-- Update memory growth
		self.profiling.memoryUsage[addonName].current = gcMem
		self.profiling.memoryUsage[addonName].growth = (gcMem - self.profiling.memoryUsage[addonName].start) / 1024
		
		-- Update samples
		self.profiling.samples[addonName] = (self.profiling.samples[addonName] or 0) + 1
	end
	
	self.metrics.lastProfileTime = time()
end

function PerformanceOptimizer:GenerateReport()
	local report = {
		timestamp = time(),
		inCombat = self.metrics.inCombat,
		uptime = time() - self.metrics.startTime,
		addons = {},
		warnings = {},
	}
	
	-- Compile addon metrics
	for addonName, cpuStats in pairs(self.profiling.cpuUsage) do
		local memStats = self.profiling.memoryUsage[addonName]
		
		report.addons[addonName] = {
			cpu = cpuStats.current,
			memory = memStats.growth,
			samples = self.profiling.samples[addonName],
		}
		
		-- Check thresholds
		if memStats.growth > self.config.memoryThreshold then
			table.insert(report.warnings, {
				addon = addonName,
				type = "MEMORY",
				value = memStats.growth,
				threshold = self.config.memoryThreshold,
			})
		end
	end
	
	self.metrics.lastReportTime = time()
	return report
end

function PerformanceOptimizer:GetMetrics(addonName)
	return {
		cpu = self.profiling.cpuUsage[addonName],
		memory = self.profiling.memoryUsage[addonName],
		samples = self.profiling.samples[addonName],
	}
end

function PerformanceOptimizer:IsOptimizationNeeded()
	local report = self:GenerateReport()
	
	for addonName, metrics in pairs(report.addons) do
		if metrics.memory > self.config.memoryThreshold then
			return true, addonName, "MEMORY"
		end
	end
	
	return false
end

function PerformanceOptimizer:OptimizeAddon(addonName)
	InfinityUtils:Warning("Triggering optimization for " .. addonName, "Core")
	
	-- Force garbage collection
	collectgarbage("collect")
	
	-- Clear caches if addon supports it
	if _G[addonName] and _G[addonName].ClearCache then
		_G[addonName]:ClearCache()
	end
	
	-- Request explicit optimization
	if _G[addonName] and _G[addonName].Optimize then
		_G[addonName]:Optimize()
	end
end

function PerformanceOptimizer:PrintMetrics()
	local report = self:GenerateReport()
	
	print("|cffffd700=== Performance Metrics ===|r")
	print("Uptime: " .. self:FormatTime(report.uptime))
	print("In Combat: " .. tostring(report.inCombat))
	print("")
	
	for addonName, metrics in pairs(report.addons) do
		print(addonName .. ":")
		print("  Memory Growth: " .. string.format("%.2f MB", metrics.memory))
		print("  Samples: " .. metrics.samples)
	end
	
	if #report.warnings > 0 then
		print("")
		print("|cffff0000⚠ Warnings:|r")
		for _, warning in ipairs(report.warnings) do
			print(string.format("  %s exceeded %s (%.2f / %.2f)",
				warning.addon, warning.type, warning.value, warning.threshold))
		end
	end
end

function PerformanceOptimizer:FormatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%dh %dm %ds", hours, minutes, secs)
end

function PerformanceOptimizer:ResetMetrics()
	self.profiling = {
		cpuUsage = {},
		memoryUsage = {},
		networkUsage = {},
		samples = {},
	}
	self.metrics.startTime = time()
	InfinityUtils:Info("Performance metrics reset", "Core")
end

function PerformanceOptimizer:IsInCombat()
	return self.metrics.inCombat
end

function PerformanceOptimizer:ShouldThrottleNetworking()
	return self.config.throttleInCombat and self.metrics.inCombat
end

function PerformanceOptimizer:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Performance Optimizer config updated: " .. key .. " = " .. tostring(value), "Core")
	end
end

return PerformanceOptimizer
