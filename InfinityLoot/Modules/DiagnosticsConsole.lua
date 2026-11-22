-- Infinity Suite Diagnostics and Debug Console
-- Provides comprehensive debugging tools for all addons

local DiagnosticsConsole = {
	logBuffer = {},
	maxLogSize = 1000,
	debugMode = false,
	enableLogging = true,
}

-- Log a debug message
function DiagnosticsConsole:Log(message, source, level)
	level = level or "INFO"
	source = source or "Debug"
	local timestamp = date("%H:%M:%S", GetTime())
	
	local logEntry = {
		timestamp = timestamp,
		level = level,
		source = source,
		message = message,
		time = GetTime(),
	}
	
	table.insert(self.logBuffer, logEntry)
	
	-- Trim buffer if too large
	if #self.logBuffer > self.maxLogSize then
		table.remove(self.logBuffer, 1)
	end
	
	if self.debugMode then
		local color = {
			INFO = "|cff00ccff",
			WARN = "|cffff9900",
			ERROR = "|cffff0000",
			DEBUG = "|cff888888",
		}
		
		print((color[level] or "|cffcccccc") .. "[" .. timestamp .. " " .. source .. "] " .. message .. "|r")
	end
end

-- Get addon status
function DiagnosticsConsole:GetAddonStatus()
	local status = {
		timestamp = GetTime(),
		addons = {},
	}
	
	local addonNames = {
		"InfinityCore",
		"InfinityLoot",
		"InfinityHealer",
		"InfinityNavigation",
		"InfinityInventory",
		"InfinityRaid",
		"InfinityGear",
	}
	
	for _, addonName in ipairs(addonNames) do
		local loaded = IsAddOnLoaded(addonName)
		status.addons[addonName] = {
			loaded = loaded,
			version = loaded and "1.0" or "N/A",
			module = loaded and _G[string.match(addonName, "Infinity%w+")] ~= nil or false,
		}
	end
	
	return status
end

-- Memory usage analysis
function DiagnosticsConsole:AnalyzeMemory()
	local memory = {
		timestamp = GetTime(),
		modules = {},
	}
	
	-- Estimate sizes of major data structures
	if InfinityLootEPGP and InfinityLootEPGP.playerData then
		local count = 0
		for _ in pairs(InfinityLootEPGP.playerData) do
			count = count + 1
		end
		memory.modules.epgp = {
			players = count,
			estimatedSize = count * 200, -- ~200 bytes per player
		}
	end
	
	if InfinityLootHistory and InfinityLootHistory.awards then
		memory.modules.lootHistory = {
			awards = #InfinityLootHistory.awards,
			estimatedSize = #InfinityLootHistory.awards * 150,
		}
	end
	
	if InfinityPointAuditing and InfinityPointAuditing.transactions then
		memory.modules.pointAuditing = {
			transactions = #InfinityPointAuditing.transactions,
			estimatedSize = #InfinityPointAuditing.transactions * 100,
		}
	end
	
	return memory
end

-- Get event registry
function DiagnosticsConsole:GetEventRegistry()
	local registry = {
		timestamp = GetTime(),
		activeFrames = 0,
		eventCounts = {},
	}
	
	-- Count registered event listeners (approximation)
	local events = {
		"ADDON_LOADED",
		"PLAYER_ENTERING_WORLD",
		"LOOT_OPENED",
		"LOOT_CLOSED",
		"CHAT_MSG_SYSTEM",
		"GROUP_ROSTER_UPDATE",
		"COMBAT_LOG_EVENT_UNFILTERED",
	}
	
	for _, event in ipairs(events) do
		registry.eventCounts[event] = "tracked"
	end
	
	return registry
end

-- Display full diagnostics report
function DiagnosticsConsole:DisplayFullReport()
	print("|cffffd700=== INFINITY SUITE DIAGNOSTICS ===|r\n")
	
	-- Addon Status
	print("|cffccccccAddon Status:|r")
	local addonStatus = self:GetAddonStatus()
	for addonName, info in pairs(addonStatus.addons) do
		local status = info.loaded and "|cff00ff00✓|r" or "|cffff0000✗|r"
		print("  " .. status .. " " .. addonName .. " (v" .. info.version .. ")")
	end
	
	-- Memory Usage
	print("\n|cffccccccMemory Usage:|r")
	local memoryInfo = self:AnalyzeMemory()
	local totalMemory = 0
	for moduleName, info in pairs(memoryInfo.modules) do
		local sizeKB = info.estimatedSize / 1024
		print(string.format("  %s: %d items (~%.1f KB)", moduleName, 
			info.players or info.awards or info.transactions, sizeKB))
		totalMemory = totalMemory + info.estimatedSize
	end
	print(string.format("  Total: ~%.1f KB", totalMemory / 1024))
	
	-- Event Registry
	print("\n|cffccccccActive Events:|r")
	local eventRegistry = self:GetEventRegistry()
	for event in pairs(eventRegistry.eventCounts) do
		print("  - " .. event)
	end
	
	-- Data Integrity
	print("\n|cffccccccData Integrity:|r")
	if _G.InfinityDataIntegrityVerifier then
		local report = _G.InfinityDataIntegrityVerifier:GenerateReport()
		print("  Errors: " .. report.totalErrors)
		print("  Warnings: " .. report.totalWarnings)
	else
		print("  Verifier not loaded")
	end
	
	-- Performance
	print("\n|cffccccccPerformance:|r")
	if _G.InfinityPerformanceOptimizer then
		local perfReport = _G.InfinityPerformanceOptimizer:GetReport()
		print("  Profiled functions: " .. #perfReport.slowFunctions)
		if #perfReport.slowFunctions > 0 then
			print("  Slowest: " .. perfReport.slowFunctions[1].name .. " (" .. perfReport.slowFunctions[1].avg .. "ms avg)")
		end
	else
		print("  Profiler not loaded")
	end
	
	print("\n|cffffd700=== END DIAGNOSTICS ===|r")
end

-- Display recently logged events
function DiagnosticsConsole:DisplayRecentLogs(count)
	count = count or 20
	
	print("|cffffd700=== RECENT LOG ENTRIES (Last " .. count .. ") ===|r\n")
	
	local startIdx = math.max(1, #self.logBuffer - count + 1)
	for i = startIdx, #self.logBuffer do
		local entry = self.logBuffer[i]
		local color = {
			INFO = "|cff00ccff",
			WARN = "|cffff9900",
			ERROR = "|cffff0000",
			DEBUG = "|cff888888",
		}
		
		print((color[entry.level] or "|cffcccccc") .. "[" .. entry.timestamp .. " " .. entry.source .. "] " 
			.. entry.message .. "|r")
	end
	
	print("\n|cffffd700Total log entries: " .. #self.logBuffer .. "|r")
end

-- Export logs to string for external review
function DiagnosticsConsole:ExportLogs()
	local logText = "=== INFINITY SUITE DIAGNOSTIC LOGS ===\n"
	logText = logText .. "Exported: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
	
	for i, entry in ipairs(self.logBuffer) do
		logText = logText .. string.format("[%s %s] %s: %s\n", 
			entry.timestamp, entry.level, entry.source, entry.message)
	end
	
	return logText
end

-- Enable/disable debug mode
function DiagnosticsConsole:SetDebugMode(enabled)
	self.debugMode = enabled
	if enabled then
		print("|cff00ff00Debug mode enabled|r")
	else
		print("|cffff0000Debug mode disabled|r")
	end
end

-- Register slash commands
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		_G.InfinityDiagnosticsConsole = DiagnosticsConsole
		
		SLASH_DIAGNOSTICS1 = "/diag"
		SLASH_DIAGNOSTICS2 = "/diagnostics"
		SlashCmdList.DIAGNOSTICS = function()
			DiagnosticsConsole:DisplayFullReport()
		end
		
		SLASH_LOGS1 = "/logs"
		SlashCmdList.LOGS = function(msg)
			local count = tonumber(msg) or 20
			DiagnosticsConsole:DisplayRecentLogs(count)
		end
		
		SLASH_DEBUG1 = "/infinitydebug"
		SlashCmdList.DEBUG = function(msg)
			if msg == "on" then
				DiagnosticsConsole:SetDebugMode(true)
			elseif msg == "off" then
				DiagnosticsConsole:SetDebugMode(false)
			else
				print("Usage: /infinitydebug on|off")
			end
		end
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

return DiagnosticsConsole
