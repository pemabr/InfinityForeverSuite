InfinityProfilerUI = { displayMode = "addons" }

function InfinityProfilerUI:CreateMainFrame()
	if self.mainFrame then return self.mainFrame end
	local frame = InfinityUIFramework:CreateListWindow("InfinityProfilerMainFrame", "Profiler snapshots", 750, 500)
	local buttons = {
		{ "Addons", function() self.displayMode = "addons"; self:RefreshDisplay() end },
		{ "Alerts", function() self.displayMode = "alerts"; self:RefreshDisplay() end },
		{ "Timeline", function() self.displayMode = "timeline"; self:RefreshDisplay() end },
		{ "Capture", function() self:Capture() end },
		{ "Thresholds", function() self:ShowThresholds() end },
		{ "Clear", function()
			local snapshots = InfinityProfilerMonitor.snapshots
			if not self.pendingClear or self.pendingClear.list ~= snapshots or self.pendingClear.count ~= #snapshots
				or self.pendingClear.last ~= snapshots[#snapshots] then
				self.pendingClear = { list = snapshots, count = #snapshots, last = snapshots[#snapshots] }
				frame.status:SetText("Clear profiler snapshots? Click Clear again.")
			else
				self.pendingClear = nil
				InfinityProfilerMonitor:ClearSnapshots()
				self:RefreshDisplay()
			end
		end },
	}
	for i, entry in ipairs(buttons) do
		local button = InfinityUIFramework:CreateButton(frame, entry[1], 100, 22, entry[2])
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 15 + (i - 1) * 105, -36)
	end
	self.mainFrame = frame
	return frame
end

function InfinityProfilerUI:ShowThresholds()
	if not self.thresholdFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityProfilerThresholdWindow", "Profiler thresholds", 600, 350)
		local label = InfinityUIFramework:CreateLabel(frame, "Value")
		label:SetPoint("TOPLEFT", 20, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(150, 20)
		input:SetPoint("TOPLEFT", 70, -38)
		input:SetAutoFocus(false)
		input:SetMaxLetters(20)
		local function SetThreshold(kind)
			local value = input:GetText()
			if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
			value = type(value) == "string" and tonumber(value) or nil
			local monitor = InfinityProfilerMonitor
			local ok = kind == "cpu" and monitor:SetCPUWarning(value)
				or kind == "memory" and value and monitor:SetMemoryWarning(value * 1024)
			if not ok then
				InfinityUtils:Warning("Enter a positive finite threshold.", "Profiler")
				return
			end
			frame.status:SetText("Threshold saved for this session. Capture again to update alerts.")
		end
		frame:SetItems({
			{ text = "Set CPU warning | Value in milliseconds", onClick = function() SetThreshold("cpu") end },
			{ text = "Set memory warning | Value in MB", onClick = function() SetThreshold("memory") end },
		})
		frame.status:SetText("Enter a positive threshold and choose its unit.")
		self.thresholdFrame, self.thresholdInput = frame, input
	end
	self.thresholdFrame:Show()
end

function InfinityProfilerUI:Capture()
	local snapshot = InfinityProfilerMonitor:CaptureSnapshot()
	self:RefreshDisplay()
	return snapshot
end

function InfinityProfilerUI:RefreshDisplay()
	if not self.mainFrame then return end
	local monitor, rows = InfinityProfilerMonitor, {}
	local snapshot = monitor.current
	if not snapshot then
		self.mainFrame.status:SetText("No snapshot. Click Capture.")
	elseif self.displayMode == "timeline" then
		for i = #monitor.snapshots, 1, -1 do
			local sample = monitor.snapshots[i]
			local total = sample.totalMemory and InfinityProfilerCore:FormatKB(sample.totalMemory) or "unavailable"
			rows[#rows + 1] = { text = date("%H:%M:%S", sample.time) .. " | Loaded addons: "
				.. #sample.addons .. " | Total memory: " .. total }
		end
	elseif self.displayMode == "alerts" then
		for _, alert in ipairs(snapshot.alerts) do
			rows[#rows + 1] = { text = alert.addon .. " | " .. alert.message }
		end
		if #rows == 0 then rows[1] = { text = "No measured threshold alerts; unavailable data excluded." } end
	else
		for _, entry in ipairs(snapshot.addons) do
			rows[#rows + 1] = { text = monitor:FormatEntry(entry) }
		end
		if #rows == 0 then rows[1] = { text = "No readable loaded addons found." } end
	end
	if snapshot then
		local cpu = snapshot.cpuAvailable and ("missing " .. snapshot.missingCPU) or "unavailable"
		local memory = snapshot.memoryAvailable and ("missing " .. snapshot.missingMemory) or "unavailable"
		self.mainFrame.status:SetText(string.format("Snapshot %s | CPU: %s | Memory: %s | Unknown addons: %d",
			date("%H:%M:%S", snapshot.time), cpu, memory, snapshot.unknownAddons))
	end
	self.mainFrame:SetItems(rows)
end

function InfinityProfilerUI:Toggle()
	local frame = self:CreateMainFrame()
	if frame:IsShown() then self.pendingClear = nil; frame:Hide() else self:Show() end
end

function InfinityProfilerUI:Show()
	self.pendingClear = nil
	local frame = self:CreateMainFrame()
	frame:Show()
	if InfinityProfilerMonitor.current then self:RefreshDisplay() else self:Capture() end
end

function InfinityProfilerUI:Hide()
	self.pendingClear = nil
	if self.mainFrame then self.mainFrame:Hide() end
end
