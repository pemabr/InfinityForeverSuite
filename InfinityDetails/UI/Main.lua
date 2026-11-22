-- InfinityDetails Main UI
-- Real-time Class-Colored StatusBar DPS / HPS / Threat / Deaths Meter for WoW Forever

local InfinityDetailsUI = {
	currentMode = "dps",
	lastUpdate = 0,
}
_G.InfinityDetailsUI = InfinityDetailsUI

function InfinityDetailsUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityDetailsMainFrame",
		UIParent,
		540,
		430,
		"Infinity Details",
		"Real-Time Combat Meters"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 140, 0)

	local tabs = {
		{ name = "Damage (DPS)", key = "dps" },
		{ name = "Healing (HPS)", key = "hps" },
		{ name = "Threat (TPS)", key = "threat" },
		{ name = "Deaths", key = "deaths" },
	}

	local tabBar = InfinityUIFramework:CreateTabBar(frame, tabs, function(mode)
		InfinityDetailsUI.currentMode = mode
		InfinityDetailsUI:Update(true)
	end, 516)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	-- Top toolbar (duration + reset + report)
	local durLbl = InfinityUIFramework:CreateLabel(frame, "|cff94a3b8Segment:|r Current  |  |cff94a3b8Duration:|r 0.0s")
	durLbl:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 4, -10)
	self.durationLabel = durLbl

	local reportBtn = InfinityUIFramework:CreateButton(frame, "Report", 72, 22, function()
		local mode = InfinityDetailsUI.currentMode
		if _G.InfinityDetailsMeters and _G.InfinityDetailsMeters.ExportMeter then
			local txt = _G.InfinityDetailsMeters:ExportMeter(mode, 5)
			if txt and txt ~= "" then
				print(txt)
				InfinityUIFramework:ShowNotification("Printed " .. mode:upper() .. " summary to chat.", 2.2)
			end
		end
	end)
	reportBtn:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", -2, -6)

	local resetBtn = InfinityUIFramework:CreateButton(frame, "Reset", 66, 22, function()
		if _G.InfinityDetailsActor and _G.InfinityDetailsActor.Clear then
			_G.InfinityDetailsActor:Clear()
		elseif _G.InfinityDetailsActor and _G.InfinityDetailsActor.actors then
			_G.InfinityDetailsActor.actors = {}
		end
		if _G.InfinityDetailsMeters then
			_G.InfinityDetailsMeters.duration = 0
			_G.InfinityDetailsMeters.start_time = nil
		end
		InfinityDetailsUI:Update(true)
		InfinityUIFramework:ShowNotification("Combat meter segment cleared.", 2)
	end)
	resetBtn:SetPoint("RIGHT", reportBtn, "LEFT", -6, 0)

	local listCard = InfinityUIFramework:CreateCard(frame, 516, 306)
	listCard:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -34)

	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityDetailsScroll", 502, 294)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)
	self.barsContainer = scroll.content

	frame:Hide()
	self.frame = frame
	self.initialized = true
	tabBar:SelectTab("dps")
end

function InfinityDetailsUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update(true) end
end

function InfinityDetailsUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update(true)
end

function InfinityDetailsUI:Update(force)
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	local now = GetTime and GetTime() or 0
	if not force and (now - self.lastUpdate) < 0.5 then return end
	self.lastUpdate = now

	local dur = (_G.InfinityDetailsMeters and _G.InfinityDetailsMeters.GetDuration) and _G.InfinityDetailsMeters:GetDuration() or 0
	if self.durationLabel then
		self.durationLabel:SetText(string.format("|cff94a3b8Mode:|r |cff38bdf8%s|r   |   |cff94a3b8Duration:|r |cffffffff%.1fs|r", self.currentMode:upper(), dur or 0))
	end

	InfinityUIFramework:ClearContainer(self.barsContainer)
	local entries = {}

	if self.currentMode == "dps" and _G.InfinityDetailsMeters then
		entries = _G.InfinityDetailsMeters:GetDPSMeter(15) or {}
	elseif self.currentMode == "hps" and _G.InfinityDetailsMeters then
		entries = _G.InfinityDetailsMeters:GetHPSMeter(15) or {}
	elseif self.currentMode == "threat" and _G.InfinityDetailsMeters then
		entries = _G.InfinityDetailsMeters:GetThreatMeter(15) or {}
	elseif self.currentMode == "deaths" and _G.InfinityDetailsDeaths and _G.InfinityDetailsDeaths.GetRecentDeaths then
		entries = _G.InfinityDetailsDeaths:GetRecentDeaths(15) or {}
	end

	if #entries == 0 then
		local empty = InfinityUIFramework:CreateLabel(self.barsContainer, "|cff94a3b8No combat data recorded in this segment yet. Enter combat to stream live bars.|r")
		empty:SetPoint("TOPLEFT", self.barsContainer, "TOPLEFT", 8, -10)
		self.barsContainer:SetHeight(280)
		return
	end

	local maxVal = 1
	for _, e in ipairs(entries) do
		local v = e.damage or e.healing or e.threat or 1
		if v > maxVal then maxVal = v end
	end

	local y = -2
	for idx, e in ipairs(entries) do
		if self.currentMode == "deaths" then
			local row = InfinityUIFramework:CreateListRow(self.barsContainer, 476, 26, idx)
			row:SetPoint("TOPLEFT", self.barsContainer, "TOPLEFT", 2, y)
			local l = InfinityUIFramework:CreateLabel(row, "|cfff87171[RIP]|r " .. tostring(e.player or e.name or "Unknown"))
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = InfinityUIFramework:CreateLabel(row, "|cff94a3b8" .. tostring(e.cause or e.time or "") .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 28
		else
			local cr, cg, cb, cHex = InfinityUIFramework:GetClassColor(e.class)
			local bar = InfinityUIFramework:CreateStatusBar(self.barsContainer, 476, 24, cr, cg, cb)
			bar:SetPoint("TOPLEFT", self.barsContainer, "TOPLEFT", 2, y)

			local primary = e.damage or e.healing or e.threat or 0
			local rate = e.dps or e.hps or e.tps or 0
			local pct = (primary / maxVal) * 100
			bar:SetBarData(
				pct,
				string.format("%d. %s%s|r", idx, cHex, tostring(e.name or "Unknown")),
				string.format("%d (%.1f/s)", math.floor(primary), rate)
			)
			bar:SetScript("OnClick", function()
				if _G.InfinityDetailsBreakdown and _G.InfinityDetailsBreakdown.ShowActor then
					_G.InfinityDetailsBreakdown:ShowActor(e)
				end
			end)
			y = y - 27
		end
	end

	self.barsContainer:SetHeight(math.max(280, -y + 10))
end

return InfinityDetailsUI
