-- Infinity Analytics UI
-- DPS/HPS meter display window

InfinityPerformanceAnalyticsUI = {}

function InfinityPerformanceAnalyticsUI:CreateMainWindow()
	if InfinityPerformanceAnalyticsMeterFrame then
		return InfinityPerformanceAnalyticsMeterFrame
	end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityPerformanceAnalyticsMeterFrame",
		UIParent,
		480,
		380,
		"Infinity Performance Analytics",
		"DPS, HPS & Combat History"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:Hide()

	local tabs = {
		{ name = "DPS", key = "dps" },
		{ name = "HPS", key = "hps" },
		{ name = "History", key = "history" },
	}
	local tabBar = InfinityUIFramework:CreateTabBar(frame, tabs, function(tabKey)
		InfinityPerformanceAnalyticsUI:ShowTab(tabKey)
	end, 456)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	local listCard = InfinityUIFramework:CreateCard(frame, 456, 286)
	listCard:SetPoint("TOP", tabBar, "BOTTOM", 0, -10)

	local scrollFrame = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityPerfAnalyticsScroll", 442, 272)
	scrollFrame:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)

	frame.scrollFrame = scrollFrame
	frame.content = scrollFrame.content
	frame.tabs = {}

	if InfinityMainFrame and InfinityMainFrame.RegisterTab then
		pcall(function() InfinityMainFrame:RegisterTab("Analytics", frame) end)
	end

	tabBar:SelectTab("dps")
	return frame
end

function InfinityPerformanceAnalyticsUI:ShowTab(tabName)
	local frame = InfinityPerformanceAnalyticsMeterFrame
	if not frame then
		return
	end

	InfinityUIFramework:ClearContainer(frame.content)

	if tabName == "dps" then
		self:ShowDPSTab()
	elseif tabName == "hps" then
		self:ShowHPSTab()
	elseif tabName == "history" then
		self:ShowHistoryTab()
	end
end

function InfinityPerformanceAnalyticsUI:ShowDPSTab()
	local frame = InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topDealers = InfinityPerformanceAnalyticsMeter:GetTopDamageDealer(10)
	
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

function InfinityPerformanceAnalyticsUI:ShowHPSTab()
	local frame = InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local topHealers = InfinityPerformanceAnalyticsMeter:GetTopHealer(10)
	
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

function InfinityPerformanceAnalyticsUI:ShowHistoryTab()
	local frame = InfinityPerformanceAnalyticsMeterFrame
	local content = frame.content
	
	local history = InfinityPerformanceAnalyticsMeter:GetSessionHistory(10)
	
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

function InfinityPerformanceAnalyticsUI:Toggle()
	local frame = self:CreateMainWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		self:ShowTab("dps")
	end
end

return InfinityPerformanceAnalyticsUI

