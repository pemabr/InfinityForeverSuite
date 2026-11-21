-- InfinityProfiler - Initialization
-- Addon-level performance profiling and monitoring system

local addonName = "InfinityProfiler"
local addonVersion = "1.0"

-- Verify InfinityCore is loaded
if not InfinityCore then
	error("InfinityProfiler requires InfinityCore")
	return
end

-- Register with InfinityCore
InfinityCore:RegisterAddon(addonName, addonVersion, {
	description = "Addon-level CPU/memory diagnostics and performance monitoring",
	author = "Infinity Suite",
	category = "analytics",
})

-- Load core modules
local basePath = "Interface\\AddOns\\InfinityForever\\sink\\InfinityProfiler\\"

-- Load core
dofile(basePath .. "Core\\ProfilerCore.lua")

-- Load modules
dofile(basePath .. "Modules\\Monitor.lua")

-- Load UI
dofile(basePath .. "UI\\Main.lua")

-- Register addon with profiler
InfinityProfilerCore:RegisterAddon(addonName, addonVersion)

-- Initialize monitoring
InfinityProfilerMonitor:Initialize()

-- Slash command handler
local function HandleProfilerCommand(msg)
	msg = msg:trim():lower()
	
	if msg == "show" or msg == "ui" then
		InfinityProfilerUI:Show()
		InfinityUtils:Info("Profiler UI opened", addonName)
	
	elseif msg == "hide" then
		InfinityProfilerUI:Hide()
		InfinityUtils:Info("Profiler UI closed", addonName)
	
	elseif msg == "toggle" then
		InfinityProfilerUI:Toggle()
	
	elseif msg == "report" then
		local text = InfinityProfilerMonitor:ExportReportAsText()
		print(text)
	
	elseif msg == "clear" then
		InfinityProfilerMonitor:ClearAlerts()
		InfinityUtils:Info("Alerts cleared", addonName)
	
	elseif msg:find("^threshold cpu ") then
		local value = tonumber(msg:match("^threshold cpu (.+)$"))
		if value and value > 0 then
			InfinityProfilerMonitor:SetCPUWarning(value)
			InfinityUtils:Info(string.format("CPU warning threshold set to %.2f ms", value), addonName)
		else
			InfinityUtils:Error("Invalid threshold value", addonName)
		end
	
	elseif msg:find("^threshold memory ") then
		local value = tonumber(msg:match("^threshold memory (.+)$"))
		if value and value > 0 then
			InfinityProfilerMonitor:SetMemoryWarning(value * 1024)  -- Convert MB to KB
			InfinityUtils:Info(string.format("Memory warning threshold set to %.1f MB", value), addonName)
		else
			InfinityUtils:Error("Invalid threshold value", addonName)
		end
	
	elseif msg:find("^addon ") then
		local addonName = msg:match("^addon (.+)$")
		local diag = InfinityProfilerMonitor:GetAddonDiagnostics(addonName)
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
			InfinityUtils:Error("Addon not found: " .. addonName, addonName)
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
InfinityCore:RegisterSlashCommand("profiler", HandleProfilerCommand, "profiler")

-- Setup event handling for addon initialization
local function OnAddonInitialized(addonName)
	-- When other addons load, register them with profiler
	if addonName ~= "InfinityCore" and addonName ~= "InfinityProfiler" then
		if addonName:find("^Infinity") then
			InfinityProfilerCore:RegisterAddon(addonName, "1.0")
		end
	end
end

-- Hook into InfinityCore's addon registration
local originalRegisterAddon = InfinityCore.RegisterAddon
function InfinityCore:RegisterAddon(name, version, config)
	local result = originalRegisterAddon(self, name, version, config)
	if result then
		InfinityProfilerCore:RegisterAddon(name, version)
	end
	return result
end

-- Initialize
InfinityProfilerMonitor:Start()
InfinityUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
