-- PluribusProfiler UI - Performance Dashboard
-- Displays real-time performance metrics and diagnostics

PluribusProfilerUI = {
	mainFrame = nil,
	displayMode = "overview",  -- overview, addon, alerts, timeline
	selectedAddon = nil,
	updateInterval = 0.5,
	lastUpdate = 0,
}

-- Create main UI frame
function PluribusProfilerUI:CreateMainFrame()
	if self.mainFrame then
		self.mainFrame:Show()
		return
	end
	
	local frame = CreateFrame("Frame", "PluribusProfilerMainFrame", UIParent)
	frame:SetSize(900, 650)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = {left = 11, right = 12, top = 12, bottom = 11}
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	
	-- Make frame movable
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	-- Title
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
	title:SetText("PLURIBUS PROFILER - Performance Dashboard")
	title:SetTextColor(0, 1, 0.5, 1)
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -15)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Tabs for different views
	self:CreateTabs(frame)
	
	-- Main content area
	local contentArea = CreateFrame("Frame", nil, frame)
	contentArea:SetSize(860, 550)
	contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
	contentArea:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tile = true, tileSize = 32,
		insets = {left = 5, right = 5, top = 5, bottom = 5}
	})
	contentArea:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
	
	self.contentArea = contentArea
	
	-- Update script
	frame:SetScript("OnUpdate", function(self, elapsed)
		PluribusProfilerUI:OnUpdate(elapsed)
	end)
	
	self.mainFrame = frame
	return frame
end

-- Create tab buttons
function PluribusProfilerUI:CreateTabs(parent)
	local tabs = {
		{name = "Overview", mode = "overview"},
		{name = "Addons", mode = "addon"},
		{name = "Alerts", mode = "alerts"},
		{name = "Timeline", mode = "timeline"},
	}
	
	local xOffset = 30
	for i, tab in ipairs(tabs) do
		local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		btn:SetSize(100, 25)
		btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset + (i-1) * 110, -55)
		btn:SetText(tab.name)
		btn:SetScript("OnClick", function()
			PluribusProfilerUI.displayMode = tab.mode
			PluribusProfilerUI:RefreshDisplay()
		end)
		
		if i == 1 then
			btn:SetEnabled(false)
		end
	end
end

-- Refresh the display
function PluribusProfilerUI:RefreshDisplay()
	if not self.mainFrame then
		return
	end
	
	-- Clear content area
	for _, child in ipairs({self.contentArea:GetChildren()}) do
		child:Hide()
	end
	
	if self.displayMode == "overview" then
		self:DisplayOverview()
	elseif self.displayMode == "addon" then
		self:DisplayAddonMetrics()
	elseif self.displayMode == "alerts" then
		self:DisplayAlerts()
	elseif self.displayMode == "timeline" then
		self:DisplayTimeline()
	end
end

-- Display overview
function PluribusProfilerUI:DisplayOverview()
	local report = PluribusProfilerMonitor:GenerateReport()
	local metrics = report.systemMetrics
	
	-- System metrics box
	local y = -20
	
	local function AddMetricLine(label, value, color)
		local text = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		text:SetText(string.format("%-40s: %s", label, value))
		if color then
			text:SetTextColor(color[1], color[2], color[3], 1)
		else
			text:SetTextColor(1, 1, 1, 1)
		end
		y = y - 25
		return text
	end
	
	AddMetricLine("Total Addons", tostring(metrics.addonCount))
	AddMetricLine("Total CPU Time", PluribusProfilerCore:FormatMS(metrics.totalCPU))
	AddMetricLine("Average CPU per Addon", PluribusProfilerCore:FormatMS(metrics.avgCPU))
	AddMetricLine("Total Memory", PluribusProfilerCore:FormatKB(metrics.totalMemory))
	AddMetricLine("Average Memory per Addon", PluribusProfilerCore:FormatKB(metrics.avgMemory))
	AddMetricLine("High CPU Addons", tostring(metrics.highCPUAddons), {1, 1, 0})
	AddMetricLine("Total Errors", tostring(metrics.totalErrors), {1, 0, 0})
	
	y = y - 20
	
	-- Top CPU consumers
	AddMetricLine("TOP CPU CONSUMERS", "", {0, 1, 0.5})
	
	for i, addon in ipairs(report.topCPUConsumers) do
		AddMetricLine(string.format("  %d. %s", i, addon.name),
			string.format("%.2f ms (%.1f%%)", addon.cpu, addon.percent),
			addon.percent > 5 and {1, 0, 0} or {1, 1, 1})
	end
	
	y = y - 20
	
	-- Top memory consumers
	AddMetricLine("TOP MEMORY CONSUMERS", "", {0, 1, 0.5})
	
	for i, addon in ipairs(report.topMemoryConsumers) do
		AddMetricLine(string.format("  %d. %s", i, addon.name),
			PluribusProfilerCore:FormatKB(addon.memory),
			addon.memory > 50 * 1024 and {1, 0, 0} or {1, 1, 1})
	end
end

-- Display addon metrics
function PluribusProfilerUI:DisplayAddonMetrics()
	local metrics = PluribusProfilerCore:GetAllMetrics()
	local sorted = {}
	
	for name, addon in pairs(metrics) do
		table.insert(sorted, {name = name, addon = addon})
	end
	
	table.sort(sorted, function(a, b)
		return (a.addon.cpu.avg or 0) > (b.addon.cpu.avg or 0)
	end)
	
	local y = -20
	
	local function AddLine(text, color)
		local t = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		t:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		t:SetText(text)
		if color then
			t:SetTextColor(color[1], color[2], color[3], 1)
		end
		y = y - 20
	end
	
	AddLine("ADDON PERFORMANCE METRICS", {0, 1, 0.5})
	
	for _, item in ipairs(sorted) do
		local addon = item.addon
		local cpuPercent = PluribusProfilerCore:GetCPUPercent(item.name)
		local cpuColor = cpuPercent > 10 and {1, 0, 0} or cpuPercent > 5 and {1, 1, 0} or {1, 1, 1}
		
		AddLine(string.format("%-30s CPU: %6.2f ms (%5.1f%%) | Mem: %8s",
			item.name, addon.cpu.avg or 0, cpuPercent, 
			PluribusProfilerCore:FormatKB(addon.memory.current or 0)), cpuColor)
	end
end

-- Display alerts
function PluribusProfilerUI:DisplayAlerts()
	local alerts = PluribusProfilerMonitor:GetActiveAlerts()
	
	local y = -20
	
	local function AddLine(text, color)
		local t = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		t:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		t:SetText(text)
		if color then
			t:SetTextColor(color[1], color[2], color[3], 1)
		end
		y = y - 20
	end
	
	if #alerts == 0 then
		AddLine("No active performance alerts", {0, 1, 0})
		AddLine("All addons performing within thresholds", {0.7, 0.7, 0.7})
		return
	end
	
	AddLine(string.format("ACTIVE ALERTS (%d)", #alerts), {1, 1, 0})
	
	for _, alert in ipairs(alerts) do
		local color = alert.type:find("critical") and {1, 0, 0} or {1, 1, 0}
		AddLine(string.format("%s [%s] x%d: %s",
			alert.addon, alert.type, alert.count, alert.message), color)
	end
end

-- Display real-time sampled memory & FPS timeline
function PluribusProfilerUI:DisplayTimeline()
	self.timelineSamples = self.timelineSamples or {}
	local memKB = (collectgarbage and collectgarbage("count")) or 0
	local fps = (GetFramerate and GetFramerate()) or 60
	table.insert(self.timelineSamples, {
		stamp = date and date("%H:%M:%S") or tostring(math.floor(GetTime and GetTime() or 0)),
		memKB = memKB,
		fps = fps,
	})
	while #self.timelineSamples > 10 do
		table.remove(self.timelineSamples, 1)
	end

	local header = PluribusUIFramework:CreateLabel(self.contentArea, "|cff38bdf8Live Memory & Framerate Timeline (Last 10 Samples)|r", nil, nil, nil, "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 12, -10)

	local maxMem = 1
	for _, s in ipairs(self.timelineSamples) do
		if s.memKB > maxMem then maxMem = s.memKB end
	end

	local y = -42
	for i = #self.timelineSamples, 1, -1 do
		local s = self.timelineSamples[i]
		local pct = (s.memKB / maxMem) * 100
		local r, g, b = 0.16, 0.56, 0.94
		if s.fps < 30 then
			r, g, b = 0.92, 0.28, 0.28
		elseif s.fps < 50 then
			r, g, b = 0.94, 0.68, 0.18
		end
		local bar = PluribusUIFramework:CreateStatusBar(self.contentArea, 500, 22, r, g, b)
		bar:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 12, y)
		bar:SetBarData(pct, string.format("[%s]  %.1f FPS", s.stamp, s.fps), string.format("%.1f MB Lua Heap", s.memKB / 1024))
		y = y - 26
	end
end

-- Update frame
function PluribusProfilerUI:OnUpdate(elapsed)
	self.lastUpdate = self.lastUpdate + elapsed
	
	if self.lastUpdate >= self.updateInterval then
		self:RefreshDisplay()
		self.lastUpdate = 0
	end
end

-- Toggle profiler UI
function PluribusProfilerUI:Toggle()
	if not self.mainFrame then
		self:CreateMainFrame()
	end
	
	if self.mainFrame:IsShown() then
		self.mainFrame:Hide()
	else
		self.mainFrame:Show()
		self:RefreshDisplay()
	end
end

-- Show profiler UI
function PluribusProfilerUI:Show()
	if not self.mainFrame then
		self:CreateMainFrame()
	end
	self.mainFrame:Show()
	self:RefreshDisplay()
end

-- Hide profiler UI
function PluribusProfilerUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end
