-- InfinityLoot UI Module
-- Main interface for loot management features

InfinityLootUI = {}

function InfinityLootUI:Toggle()
	if not _G.InfinityLootWindow then
		self:Create()
	else
		if _G.InfinityLootWindow:IsVisible() then
			_G.InfinityLootWindow:Hide()
		else
			_G.InfinityLootWindow:Show()
		end
	end
end

function InfinityLootUI:Create()
	local frame = InfinityUIFramework:CreateFrame("InfinityLootWindow", UIParent, 600, 400)
	frame:SetPoint("CENTER", 200, 0)
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame, 
		INFINITY_COLORS.PRIMARY .. "Loot Manager" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOP", 0, -10)
	title:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Tab buttons for DKP, Tracking, Economy, Commissions
	local tabs = {
		{ name = "DKP Manager", key = "dkp" },
		{ name = "Loot Tracker", key = "tracking" },
		{ name = "Economy", key = "economy" },
		{ name = "Commissions", key = "commissions" },
	}
	
	local currentTab = "dkp"
	
	for i, tab in ipairs(tabs) do
		local tabBtn = InfinityUIFramework:CreateButton(frame, tab.name, 100, 20, function()
			currentTab = tab.key
			self:ShowTab(frame, tab.key)
		end)
		tabBtn:SetPoint("TOPLEFT", 10 + (i-1) * 110, -35)
	end
	
	-- Content area
	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(580, 320)
	frame.contentArea:SetPoint("TOP", 0, -60)
	
	-- Show default tab
	self:ShowTab(frame, "dkp")
	
	return frame
end

function InfinityLootUI:ShowTab(frame, tabName)
	-- Clear previous content
	InfinityUtils:ClearContainer(frame.contentArea)
	
	if tabName == "dkp" then
		self:ShowDKPTab(frame)
	elseif tabName == "tracking" then
		self:ShowTrackingTab(frame)
	elseif tabName == "economy" then
		self:ShowEconomyTab(frame)
	elseif tabName == "commissions" then
		self:ShowCommissionsTab(frame)
	end
end

function InfinityLootUI:ShowDKPTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "DKP Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Stats
	local stats = InfinityLootManager:GetStatistics()
	local info = {
		"Active Raids: " .. stats.totalRaids,
		"Members: " .. stats.totalMembers,
		"Loot Awarded: " .. stats.totalLootAwarded,
		"Total DKP Spent: " .. stats.totalDkpSpent,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Action buttons
	y = y - 20
	local newRaidBtn = InfinityUIFramework:CreateButton(frame.contentArea, "New Raid", 100, 25, function()
		local raidId = InfinityLootManager:CreateRaid("New Raid", InfinityUtils:GetTimeStamp())
		InfinityUtils:Info("Created raid: " .. raidId, "InfinityLoot")
	end)
	newRaidBtn:SetPoint("TOPLEFT", 10, y)
end

function InfinityLootUI:ShowTrackingTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Loot Tracking" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Session stats
	local sessionStats = InfinityLootTracking:GetSessionStats()
	if sessionStats then
		local info = {
			"Session Value: " .. InfinityUtils:FormatGold(sessionStats.totalValue),
			"Gold/Hour: " .. InfinityUtils:FormatGold(sessionStats.goldPerHour),
			"Items Looted: " .. sessionStats.totalItems,
			"Kills: " .. sessionStats.kills,
			"Loot Per Hour: " .. sessionStats.lootPerHour,
			"Time: " .. InfinityUtils:FormatTime(sessionStats.elapsedSeconds),
		}
		
		for _, text in ipairs(info) do
			local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
			label:SetPoint("TOPLEFT", 10, y)
			y = y - 20
		end
	end
	
	-- Control buttons
	y = y - 20
	local pauseBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Pause", 70, 25, function()
		InfinityLootTracking:PauseSession()
	end)
	pauseBtn:SetPoint("TOPLEFT", 10, y)
	
	local resumeBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Resume", 70, 25, function()
		InfinityLootTracking:ResumeSession()
	end)
	resumeBtn:SetPoint("TOPLEFT", 90, y)
	
	local newBtn = InfinityUIFramework:CreateButton(frame.contentArea, "New Session", 100, 25, function()
		InfinityLootTracking:StartNewSession()
	end)
	newBtn:SetPoint("TOPLEFT", 170, y)
end

function InfinityLootUI:ShowEconomyTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Economy" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Summary
	local summary = InfinityLootEconomy:GetSummary()
	local info = {
		"Total Earned: " .. InfinityUtils:FormatGold(summary.totalEarned),
		"Total Spent: " .. InfinityUtils:FormatGold(summary.totalSpent),
		"Balance: " .. InfinityUtils:FormatGold(summary.balance),
		"Transactions: " .. summary.transactions,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Top merchants
	y = y - 20
	local merchantLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "Top Merchants:")
	merchantLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local merchants = InfinityLootEconomy:GetTopMerchants(5)
	for _, merchant in ipairs(merchants) do
		local text = merchant.name .. ": " .. InfinityUtils:FormatGold(merchant.amount)
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
end

function InfinityLootUI:ShowCommissionsTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Daily Commissions" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Stats
	local stats = InfinityLootCommissions:GetStatistics()
	local info = {
		"Registered Quests: " .. stats.totalQuestRegistered,
		"Total Completions: " .. stats.totalCompletions,
		"Completed Today: " .. stats.todayCompleted,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Available quests
	y = y - 20
	local availLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "Available Today:")
	availLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local available = InfinityLootCommissions:GetAvailableCommissions()
	for i, quest in ipairs(available) do
		if i > 5 then break end
		local text = quest.name .. " (" .. quest.questGiver .. ")"
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
end

return InfinityLootUI
