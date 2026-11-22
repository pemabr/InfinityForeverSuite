-- Infinity Analytics UI
-- DPS/HPS meter display window

InfinityPerformanceAnalyticsUI = {}

function InfinityPerformanceAnalyticsUI:CreateMainWindow()
	if _G.InfinityPerformanceAnalyticsMeterFrame then
		return _G.InfinityPerformanceAnalyticsMeterFrame
	end
	
	local frame = CreateFrame("Frame", "InfinityPerformanceAnalyticsMeterFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(400, 300)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(300, 200)
	elseif frame.SetMinResize then
		frame:SetMinResize(300, 200)
	end
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
	end)
	frame:Hide()
	
	-- Title
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
	title:SetText("Analytics")
	
	-- Tabs
	local tabContainer = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	tabContainer:SetSize(380, 25)
	tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
	
	local tabs = {"DPS", "HPS", "History"}
	for i, tabName in ipairs(tabs) do
		local tab = CreateFrame("Button", nil, tabContainer)
		tab:SetSize(80, 25)
		tab:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", (i-1) * 90, 0)
		tab:SetNormalFontObject(GameFontNormal)
		tab:SetText(tabName)
		tab:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
		tab:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")
		tab:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight")
		
		tab:SetScript("OnClick", function()
			InfinityPerformanceAnalyticsUI:ShowTab(tabName:lower())
		end)
	end
	local start = InfinityUIFramework:CreateButton(frame, "Start", 80, 22, function()
		local meter = InfinityPerformanceAnalyticsMeter
		if meter.currentSession then
			InfinityUtils:Warning("An analytics session is already active.", "Analytics")
		else
			meter:StartSession("Combat " .. date("%H:%M:%S"))
		end
		self:ShowTab(self.selectedTab or "dps")
	end)
	start:SetPoint("TOPLEFT", 10, -65)
	local finish = InfinityUIFramework:CreateButton(frame, "End", 80, 22, function()
		if not InfinityPerformanceAnalyticsMeter:EndSession() then
			InfinityUtils:Warning("No analytics session is active.", "Analytics")
		end
		self:ShowTab(self.selectedTab or "dps")
	end)
	finish:SetPoint("LEFT", start, "RIGHT", 6, 0)
	local clear = InfinityUIFramework:CreateButton(frame, "Clear", 80, 22, function()
		local log = InfinityPerformanceAnalyticsMeter.combatLog
		local pending = self.confirmClear
		local matches = pending and pending.log == log and #pending.entries == #log
		if matches then
			for index, entry in ipairs(log) do
				if pending.entries[index] ~= entry then matches = false; break end
			end
		end
		if not matches then
			self.confirmClear = { log = log, entries = {} }
			for index, entry in ipairs(log) do self.confirmClear.entries[index] = entry end
			frame.status:SetText("Clear session history? Click Clear again.")
		else
			self.confirmClear = nil
			InfinityPerformanceAnalyticsMeter.combatLog = {}
			self:ShowTab(self.selectedTab or "history")
		end
	end)
	clear:SetPoint("LEFT", finish, "RIGHT", 6, 0)
	local refresh = InfinityUIFramework:CreateButton(frame, "Refresh", 80, 22, function()
		self:ShowTab(self.selectedTab or "dps")
	end)
	refresh:SetPoint("LEFT", clear, "RIGHT", 6, 0)
	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.status:SetPoint("BOTTOMLEFT", 10, 8)
	
	-- Content area with scroll
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -95)
	scrollFrame:SetSize(380, 175)
	
	local content = CreateFrame("Frame", nil, scrollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetSize(380, 1)
	scrollFrame:SetScrollChild(content)
	
	frame.scrollFrame = scrollFrame
	frame.content = content
	frame.tabs = {}
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
	
	if _G.InfinityMainFrame and _G.InfinityMainFrame.RegisterTab then
		_G.InfinityMainFrame:RegisterTab("Analytics", frame)
	end
	
	return frame
end

function InfinityPerformanceAnalyticsUI:ShowTab(tabName)
	local frame = _G.InfinityPerformanceAnalyticsMeterFrame
	if not frame then
		return
	end
	self.selectedTab = tabName
	self.confirmClear = nil
	frame.status:SetText((InfinityPerformanceAnalyticsMeter.currentSession and "Session active" or "Session stopped")
		.. " | " .. (InfinityPerformanceAnalyticsMeter.sampleStatus or "No native sample") .. " | Session only")
	
	-- Clear content
	for i, child in ipairs({frame.content:GetChildren()}) do
		child:Hide()
		child:SetParent(nil)
	end
	
	if tabName == "dps" then
		self:ShowDPSTab()
	elseif tabName == "hps" then
		self:ShowHPSTab()
	elseif tabName == "history" then
		self:ShowHistoryTab()
	end
end

function InfinityPerformanceAnalyticsUI:ShowDPSTab()
	local frame = _G.InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topDealers = InfinityPerformanceAnalyticsMeter:GetTopDamageDealer(10)
	
	for i, player in ipairs(topDealers) do
		player = InfinityPerformanceAnalyticsMeter:GetPlayerStats(player.name) or player
		local row = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
		row:SetSize(360, 20)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 25)
		
		-- Player name
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("LEFT", row, "LEFT", 5, 0)
		name:SetText(player.name or "Unknown")
		
		-- DPS
		local dps = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		dps:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		dps:SetText(string.format("%d DPS", player.dps or 0))
	end
	
	-- Update content height
	content:SetHeight(math.max(20 * #topDealers, 100))
end

function InfinityPerformanceAnalyticsUI:ShowHPSTab()
	local frame = _G.InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topHealers = InfinityPerformanceAnalyticsMeter:GetTopHealer(10)
	
	for i, player in ipairs(topHealers) do
		player = InfinityPerformanceAnalyticsMeter:GetPlayerStats(player.name) or player
		local row = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
		row:SetSize(360, 20)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 25)
		
		-- Player name
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("LEFT", row, "LEFT", 5, 0)
		name:SetText(player.name or "Unknown")
		
		-- HPS
		local hps = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hps:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		hps:SetText(string.format("%d HPS", player.hps or 0))
	end
	
	-- Update content height
	content:SetHeight(math.max(20 * #topHealers, 100))
end

function InfinityPerformanceAnalyticsUI:ShowHistoryTab()
	local frame = _G.InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local history = InfinityPerformanceAnalyticsMeter:GetSessionHistory(10)
	
	for i, session in ipairs(history) do
		local row = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
		row:SetSize(360, 20)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 25)
		
		-- Session name
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("LEFT", row, "LEFT", 5, 0)
		name:SetText(session.name or "Unknown")
		
		-- Duration
		local duration = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		duration:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		local mins = math.floor((session.duration or 0) / 60)
		duration:SetText(string.format("%d min", mins))
	end
	
	-- Update content height
	content:SetHeight(math.max(20 * #history, 100))
end

function InfinityPerformanceAnalyticsUI:Toggle()
	local frame = self:CreateMainWindow()
	if frame:IsShown() then
		self.confirmClear = nil
		frame:Hide()
	else
		frame:Show()
		self:ShowTab("dps")
	end
end

return InfinityPerformanceAnalyticsUI

