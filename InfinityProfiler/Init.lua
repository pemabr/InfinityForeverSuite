local addonName = "InfinityProfiler"
local initialized = false

local function InitializeProfiler()
	if initialized then return end
	if not InfinityCore or not InfinityProfilerCore or not InfinityProfilerMonitor
		or not InfinityProfilerUI or not InfinityUIFramework then
		InfinityUtils:Error("Profiler modules unavailable.", addonName)
		return
	end
	initialized = true
	InfinityCore:RegisterAddon(addonName, "1.0", {
		description = "On-demand addon CPU and memory snapshots",
		author = "Infinity Suite",
		category = "analytics",
	})
	InfinityCore:RegisterSlashCommand("profiler", function(message)
		local input = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
		local command, args = input:match("^(%S+)%s*(.-)$")
		command = command and command:lower() or ""
		local monitor, ui = InfinityProfilerMonitor, InfinityProfilerUI
		if command == "" or command == "show" or command == "ui" then
			ui:Show()
		elseif command == "hide" then
			ui:Hide()
		elseif command == "toggle" then
			ui:Toggle()
		elseif command == "capture" or command == "report" then
			local snapshot = monitor:CaptureSnapshot()
			if snapshot then
				print("Profiler snapshot (CPU: recent average; memory: KB):")
				for _, entry in ipairs(snapshot.addons) do print(monitor:FormatEntry(entry)) end
				print(string.format("Missing CPU: %d; memory: %d; unknown addons: %d",
					snapshot.missingCPU, snapshot.missingMemory, snapshot.unknownAddons))
			end
			ui:RefreshDisplay()
		elseif command == "clear" then
			monitor:ClearSnapshots()
			ui:RefreshDisplay()
			print("Profiler snapshots cleared.")
		elseif command == "addon" and args ~= "" then
			local snapshot = monitor.current
			local found
			for _, entry in ipairs(snapshot and snapshot.addons or {}) do
				if entry.name:lower() == args:lower() then found = entry; break end
			end
			if found then print(monitor:FormatEntry(found))
			else print("Addon not found in the current snapshot; capture first.") end
		elseif command == "threshold" then
			local kind, raw = args:match("^(%S+)%s+(%S+)$")
			local value = tonumber(raw)
			local ok = kind == "cpu" and monitor:SetCPUWarning(value)
				or kind == "memory" and value and monitor:SetMemoryWarning(value * 1024)
			if ok then print("Threshold updated; capture again to refresh alerts.")
			else print("Usage: /profiler threshold cpu <ms> | memory <MB>") end
		else
			print("Usage: /profiler [show|hide|toggle|capture|report|clear|addon <name>|threshold cpu <ms>|threshold memory <MB>]")
		end
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
	if name == addonName then
		InitializeProfiler()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
