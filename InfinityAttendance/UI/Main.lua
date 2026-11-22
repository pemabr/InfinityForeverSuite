-- InfinityAttendance Main UI
-- Live Raid Attendance Tracker, Roster Scanner, Boss EP Awarder, and Attendance Rate Bars

local InfinityAttendanceUI = {}
_G.InfinityAttendanceUI = InfinityAttendanceUI

function InfinityAttendanceUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityAttendanceMainFrame",
		UIParent,
		640,
		460,
		"Infinity Attendance",
		"Raid Presence & EP Automation"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", -120, 0)

	-- Action toolbar
	local startBtn = InfinityUIFramework:CreateButton(frame, "Start Raid", 96, 26, function()
		if _G.InfinityAttendanceTracker and _G.InfinityAttendanceTracker.StartTracking then
			local zone = (GetRealZoneText and GetRealZoneText()) or "Naxxramas"
			_G.InfinityAttendanceTracker:StartTracking(zone)
			InfinityUIFramework:ShowNotification("Started raid attendance for " .. tostring(zone), 2.5)
			InfinityAttendanceUI:Update()
		end
	end, true)
	startBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local scanBtn = InfinityUIFramework:CreateButton(frame, "Scan Raid", 96, 26, function()
		if _G.InfinityAttendanceTracker and _G.InfinityAttendanceTracker.ScanRaid then
			local raid = _G.InfinityAttendanceTracker:GetCurrentRaid()
			if not raid then
				raid = _G.InfinityAttendanceTracker:StartTracking((GetRealZoneText and GetRealZoneText()) or "Guild Raid")
			end
			_G.InfinityAttendanceTracker:ScanRaid(raid)
			InfinityUIFramework:ShowNotification("Scanned active raid roster.", 2.2)
			InfinityAttendanceUI:Update()
		end
	end)
	scanBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)

	local epBtn = InfinityUIFramework:CreateButton(frame, "Award +10 EP", 104, 26, function()
		if _G.InfinityDKPEngine and _G.InfinityDKPEngine.AwardEP then
			local raid = _G.InfinityAttendanceTracker and _G.InfinityAttendanceTracker:GetCurrentRaid()
			local awarded = 0
			if raid and raid.attendees then
				for playerName, _ in pairs(raid.attendees) do
					pcall(function() _G.InfinityDKPEngine:AwardEP(playerName, 10, "Attendance Bonus") end)
					awarded = awarded + 1
				end
			end
			InfinityUIFramework:ShowNotification("Awarded +10 EP to " .. tostring(awarded) .. " attendees.", 2.5)
		else
			InfinityUIFramework:ShowNotification("InfinityDKP engine not loaded.", 2.5)
		end
	end)
	epBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)

	local endBtn = InfinityUIFramework:CreateButton(frame, "End Raid", 90, 26, function()
		if _G.InfinityAttendanceTracker and _G.InfinityAttendanceTracker.EndTracking then
			_G.InfinityAttendanceTracker:EndTracking()
			InfinityUIFramework:ShowNotification("Ended raid attendance session.", 2.5)
			InfinityAttendanceUI:Update()
		end
	end)
	endBtn:SetPoint("LEFT", epBtn, "RIGHT", 8, 0)

	local autoCb = InfinityUIFramework:CreateCheckbox(frame, "Auto-Track Bosses", true, function(val)
		if _G.InfinityAttendanceTracker then
			_G.InfinityAttendanceTracker.auto_tracking = val
		end
	end)
	autoCb:SetPoint("LEFT", endBtn, "RIGHT", 12, 0)

	-- Dynamic body area
	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(616, 368)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -80)

	frame:Hide()
	self.frame = frame
	self.initialized = true
end

function InfinityAttendanceUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update() end
end

function InfinityAttendanceUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update()
end

function InfinityAttendanceUI:Update()
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	local b = self.frame.body
	InfinityUIFramework:ClearContainer(b)

	local tracker = _G.InfinityAttendanceTracker
	local currentRaid = tracker and tracker.GetCurrentRaid and tracker:GetCurrentRaid() or nil
	local raids = (tracker and tracker.raids) or {}
	local totalRaids = 0
	for _ in pairs(raids) do totalRaids = totalRaids + 1 end

	local presentCount = 0
	if currentRaid and currentRaid.attendees then
		for _ in pairs(currentRaid.attendees) do presentCount = presentCount + 1 end
	end

	local m1 = InfinityUIFramework:CreateMetricTile(b, 196, 58, "Tracked Raids", totalRaids, "|cff38bdf8")
	m1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local m2 = InfinityUIFramework:CreateMetricTile(b, 196, 58, "Current Attendees", presentCount, "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 14, 0)
	local m3 = InfinityUIFramework:CreateMetricTile(b, 196, 58, "Session Status", currentRaid and "ACTIVE" or "IDLE", currentRaid and "|cff4ade80" or "|cff94a3b8")
	m3:SetPoint("LEFT", m2, "RIGHT", 14, 0)

	local listCard = InfinityUIFramework:CreateCard(b, 616, 294, "Player Attendance Rates & Report")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -12)

	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityAttendanceScroll", 600, 254)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	local content = scroll.content

	local playerCounts = {}
	for _, r in pairs(raids) do
		if r.attendees then
			for pName, _ in pairs(r.attendees) do
				playerCounts[pName] = (playerCounts[pName] or 0) + 1
			end
		end
	end

	local rows = {}
	for pName, cnt in pairs(playerCounts) do
		table.insert(rows, { name = pName, count = cnt, pct = totalRaids > 0 and ((cnt / totalRaids) * 100) or 100 })
	end
	table.sort(rows, function(a, c) return a.pct > c.pct end)

	if #rows == 0 then
		local report = (_G.InfinityAttendanceStats and _G.InfinityAttendanceStats.GetAttendanceReport) and _G.InfinityAttendanceStats:GetAttendanceReport() or "No raids tracked yet. Click 'Start Raid' or pull a boss to begin automatic attendance tracking."
		local empty = InfinityUIFramework:CreateLabel(content, "|cff94a3b8" .. tostring(report) .. "|r")
		empty:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6)
		empty:SetWidth(560)
		empty:SetWordWrap(true)
		content:SetHeight(240)
	else
		local y = -2
		for idx, item in ipairs(rows) do
			local bar = InfinityUIFramework:CreateStatusBar(content, 572, 24, 0.18, 0.76, 0.44)
			bar:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
			bar:SetBarData(item.pct, string.format("%d. %s", idx, item.name), string.format("%d/%d raids (%.0f%%)", item.count, math.max(1, totalRaids), item.pct))
			y = y - 27
		end
		content:SetHeight(math.max(240, -y + 10))
	end
end

return InfinityAttendanceUI
