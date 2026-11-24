-- Pluribus Analytics UI
-- DPS/HPS meter display window

PluribusPerformanceAnalyticsUI = {}

function PluribusPerformanceAnalyticsUI:CreateMainWindow()
	if PluribusPerformanceAnalyticsMeterFrame then
		return PluribusPerformanceAnalyticsMeterFrame
	end

	local frame = PluribusUIFramework:CreateFrame(
		"PluribusPerformanceAnalyticsMeterFrame",
		UIParent,
		480,
		380,
		"Pluribus Performance Analytics",
		"DPS, HPS & Combat History"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:Hide()

	local tabs = {
		{ name = "DPS", key = "dps" },
		{ name = "HPS", key = "hps" },
		{ name = "History", key = "history" },
	}
	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(tabKey)
		PluribusPerformanceAnalyticsUI:ShowTab(tabKey)
	end, 456)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	local listCard = PluribusUIFramework:CreateCard(frame, 456, 286)
	listCard:SetPoint("TOP", tabBar, "BOTTOM", 0, -10)

	local scrollFrame = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusPerfAnalyticsScroll", 442, 272)
	scrollFrame:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)

	frame.scrollFrame = scrollFrame
	frame.content = scrollFrame.content
	frame.tabs = {}

	if PluribusMainFrame and PluribusMainFrame.RegisterTab then
		pcall(function() PluribusMainFrame:RegisterTab("Analytics", frame) end)
	end

	tabBar:SelectTab("dps")
	return frame
end

function PluribusPerformanceAnalyticsUI:ShowTab(tabName)
	local frame = PluribusPerformanceAnalyticsMeterFrame
	if not frame then
		return
	end

	PluribusUIFramework:ClearContainer(frame.content)

	if tabName == "dps" then
		self:ShowDPSTab()
	elseif tabName == "hps" then
		self:ShowHPSTab()
	elseif tabName == "history" then
		self:ShowHistoryTab()
	end
end

function PluribusPerformanceAnalyticsUI:ShowDPSTab()
	local frame = PluribusPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topDealers = PluribusPerformanceAnalyticsMeter:GetTopDamageDealer(10)
	
	for i, player in ipairs(topDealers) do
		local row = CreateFrame("Frame", nil, content)
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

function PluribusPerformanceAnalyticsUI:ShowHPSTab()
	local frame = PluribusPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topHealers = PluribusPerformanceAnalyticsMeter:GetTopHealer(10)
	
	for i, player in ipairs(topHealers) do
		local row = CreateFrame("Frame", nil, content)
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

function PluribusPerformanceAnalyticsUI:ShowHistoryTab()
	local frame = PluribusPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local history = PluribusPerformanceAnalyticsMeter:GetSessionHistory(10)
	
	for i, session in ipairs(history) do
		local row = CreateFrame("Frame", nil, content)
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

function PluribusPerformanceAnalyticsUI:Toggle()
	local frame = self:CreateMainWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		self:ShowTab("dps")
	end
end

return PluribusPerformanceAnalyticsUI

