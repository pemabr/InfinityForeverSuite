-- InfinityProfiler - Initialization
-- Addon-level performance profiling and monitoring system

local addonName = "InfinityProfiler"
local addonVersion = "1.0"

local function InitializeProfiler()
	if not _G.InfinityCore then
		return
	end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, addonVersion, {
		description = "Addon-level CPU/memory diagnostics and performance monitoring",
		author = "Infinity Suite",
		category = "analytics",
	})
	
	-- Core modules should be loaded via .toc, access as globals
	local ProfilerCore = _G.InfinityProfilerCore
	local Monitor = _G.InfinityProfilerMonitor
	local UI = _G.InfinityProfilerUI
	
	if not ProfilerCore or not Monitor or not UI then
		return
	end
	
	-- Register addon with profiler
	ProfilerCore:RegisterAddon(addonName, addonVersion)
	
	-- Initialize monitoring
	if Monitor then pcall(function() Monitor:Initialize() end) end
	
	-- Slash command handler
	local function HandleProfilerCommand(msg)
		msg = msg:trim():lower()
		
		if msg == "show" or msg == "ui" then
			UI:Show()
			_G.InfinityUtils:Info("Profiler UI opened", addonName)
		
		elseif msg == "hide" then
			UI:Hide()
			_G.InfinityUtils:Info("Profiler UI closed", addonName)
		
		elseif msg == "toggle" then
			UI:Toggle()
		
		elseif msg == "report" then
			local text = Monitor:ExportReportAsText()
			print(text)
		
		elseif msg == "clear" then
			Monitor:ClearAlerts()
			_G.InfinityUtils:Info("Alerts cleared", addonName)
		
		elseif msg:find("^threshold cpu ") then
			local value = tonumber(msg:match("^threshold cpu (.+)$"))
			if value and value > 0 then
				Monitor:SetCPUWarning(value)
				_G.InfinityUtils:Info(string.format("CPU warning threshold set to %.2f ms", value), addonName)
			else
				_G.InfinityUtils:Error("Invalid threshold value", addonName)
			end
		
		elseif msg:find("^threshold memory ") then
			local value = tonumber(msg:match("^threshold memory (.+)$"))
			if value and value > 0 then
				Monitor:SetMemoryWarning(value * 1024)  -- Convert MB to KB
				_G.InfinityUtils:Info(string.format("Memory warning threshold set to %.1f MB", value), addonName)
			else
				_G.InfinityUtils:Error("Invalid threshold value", addonName)
			end
		
		elseif msg:find("^addon ") then
			local addonName = msg:match("^addon (.+)$")
			local diag = Monitor:GetAddonDiagnostics(addonName)
			if diag then
				print(string.format("\n=== %s DIAGNOSTICS ===", diag.name))
				print(string.format("Version: %s", diag.version))
				print(string.format("Status: %s", diag.status))
				print(string.format("Uptime: %.0f seconds", diag.uptime))
				print("\nCPU:")
				print(string.format("  Current: %s", diag.cpu.current))
				print(string.format("  Average: %s", diag.cpu.average))
				print(string.format("  Peak: %s", diag.cpu.peak))
				print(string.format("  Percent: %.1f%%", diag.cpu.percent))
				print("\nMemory:")
				print(string.format("  Current: %s", diag.memory.current))
				print(string.format("  Peak: %s", diag.memory.peak))
				print("\nPerformance:")
				print(string.format("  Calls: %d", diag.performance.calls))
				print(string.format("  Errors: %d", diag.performance.errors))
				print(string.format("  Events: %d", diag.performance.events))
				print(string.format("  Frames: %d", diag.performance.frames))
				
				if #diag.alerts > 0 then
					print("\nAlerts:")
					for _, alert in ipairs(diag.alerts) do
						print(string.format("  • [%s] %s (x%d)", alert.type, alert.message, alert.count))
					end
				end
			else
				_G.InfinityUtils:Error("Addon not found: " .. addonName, addonName)
			end
		
		else
			print("\n=== INFINITY PROFILER ===")
			print("Usage:")
			print("  /infinity profiler show          - Show profiler UI")
			print("  /infinity profiler hide          - Hide profiler UI")
			print("  /infinity profiler toggle        - Toggle profiler UI")
			print("  /infinity profiler report        - Print performance report")
			print("  /infinity profiler clear         - Clear all alerts")
			print("  /infinity profiler threshold cpu <ms>    - Set CPU warning threshold")
			print("  /infinity profiler threshold memory <mb> - Set memory warning threshold")
			print("  /infinity profiler addon <name>  - Get diagnostics for addon")
		end
	end
	
	-- Register slash command
	_G.InfinityCore:RegisterSlashCommand("profiler", HandleProfilerCommand, "profiler")
	
	-- Hook into InfinityCore's addon registration
	local originalRegisterAddon = _G.InfinityCore.RegisterAddon
	function _G.InfinityCore:RegisterAddon(name, versionOrConfig, maybeConfig)
		local result = originalRegisterAddon(self, name, versionOrConfig, maybeConfig)
		if result then
			local ver = type(versionOrConfig) == "table" and (versionOrConfig.version or "1.0.0") or versionOrConfig
			ProfilerCore:RegisterAddon(name, ver)
		end
		return result
	end
	
	-- Start monitoring
	Monitor:Start()
	_G.InfinityUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.InfinityCore then
			InitializeProfiler()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		InitializeProfiler()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeProfiler()
		end
	end)
end


