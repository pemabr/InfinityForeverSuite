-- PluribusProfiler - Initialization
-- Addon-level performance profiling and monitoring system

local addonName = "PluribusProfiler"
local addonVersion = "1.0"

local profilerInitialized = false

local function InitializeProfiler()
	if profilerInitialized or not _G.PluribusCore then
		return
	end
	profilerInitialized = true
	
	-- Register with PluribusCore
	_G.PluribusCore:RegisterAddon(addonName, addonVersion, {
		description = "Addon-level CPU/memory diagnostics and performance monitoring",
		author = "Pluribus Suite",
		category = "analytics",
	})
	
	-- Core modules should be loaded via .toc, access as globals
	local ProfilerCore = _G.PluribusProfilerCore
	local Monitor = _G.PluribusProfilerMonitor
	local UI = _G.PluribusProfilerUI
	
	if not ProfilerCore or not Monitor or not UI then
		return
	end
	
	-- Register addon with profiler
	ProfilerCore:RegisterAddon(addonName, addonVersion)
	
	-- Initialize monitoring
	if Monitor then pcall(function() Monitor:Initialize() end) end
	
	-- Slash command handler
	local function HandleProfilerCommand(msg)
		if type(msg) == "table" then
			msg = table.concat(msg, " ")
		end
		msg = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()
		
		if msg == "" or msg == "show" or msg == "ui" then
			UI:Show()
			_G.PluribusUtils:Info("Profiler UI opened", addonName)
		
		elseif msg == "hide" then
			UI:Hide()
			_G.PluribusUtils:Info("Profiler UI closed", addonName)
		
		elseif msg == "toggle" then
			UI:Toggle()
		
		elseif msg == "report" then
			local text = Monitor:ExportReportAsText()
			print(text)
		
		elseif msg == "clear" then
			Monitor:ClearAlerts()
			_G.PluribusUtils:Info("Alerts cleared", addonName)
		
		elseif msg:find("^threshold cpu ") then
			local value = tonumber(msg:match("^threshold cpu (.+)$"))
			if value and value > 0 then
				Monitor:SetCPUWarning(value)
				_G.PluribusUtils:Info(string.format("CPU warning threshold set to %.2f ms", value), addonName)
			else
				_G.PluribusUtils:Error("Invalid threshold value", addonName)
			end
		
		elseif msg:find("^threshold memory ") then
			local value = tonumber(msg:match("^threshold memory (.+)$"))
			if value and value > 0 then
				Monitor:SetMemoryWarning(value * 1024)  -- Convert MB to KB
				_G.PluribusUtils:Info(string.format("Memory warning threshold set to %.1f MB", value), addonName)
			else
				_G.PluribusUtils:Error("Invalid threshold value", addonName)
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
				_G.PluribusUtils:Error("Addon not found: " .. addonName, addonName)
			end
		
		else
			print("\n=== PLURIBUS PROFILER ===")
			print("Usage:")
			print("  /pluribus profiler show          - Show profiler UI")
			print("  /pluribus profiler hide          - Hide profiler UI")
			print("  /pluribus profiler toggle        - Toggle profiler UI")
			print("  /pluribus profiler report        - Print performance report")
			print("  /pluribus profiler clear         - Clear all alerts")
			print("  /pluribus profiler threshold cpu <ms>    - Set CPU warning threshold")
			print("  /pluribus profiler threshold memory <mb> - Set memory warning threshold")
			print("  /pluribus profiler addon <name>  - Get diagnostics for addon")
		end
	end
	
	-- Register slash command
	if _G.PluribusCore.RegisterSlashCommand then
		_G.PluribusCore:RegisterSlashCommand("profiler", HandleProfilerCommand, "profiler")
	elseif _G.PluribusCommandRegistry and _G.PluribusCommandRegistry.RegisterCommand then
		_G.PluribusCommandRegistry:RegisterCommand("profiler", function(args, raw)
			HandleProfilerCommand(raw or "")
		end, { "prof" })
	end
	
	-- Hook into PluribusCore's addon registration
	if type(_G.PluribusCore.RegisterAddon) == "function" then
		local originalRegisterAddon = _G.PluribusCore.RegisterAddon
		function _G.PluribusCore:RegisterAddon(name, version, config)
			local result = originalRegisterAddon(self, name, version, config)
			if result and ProfilerCore and ProfilerCore.RegisterAddon then
				local resolvedVersion = type(version) == "string" and version or (type(version) == "table" and version.version) or "1.0"
				pcall(function() ProfilerCore:RegisterAddon(name, resolvedVersion) end)
			end
			return result
		end
	end
	
	-- Start monitoring
	if Monitor and Monitor.Start then
		pcall(function() Monitor:Start() end)
	end
	if _G.PluribusUtils and _G.PluribusUtils.Info then
		_G.PluribusUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
	end
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Performance profiling",
			author = "Pluribus Suite Team",
			category = "Tools",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.PluribusCore then
			InitializeProfiler()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		InitializeProfiler()
	end
end)

if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeProfiler()
		end
	end)
end


