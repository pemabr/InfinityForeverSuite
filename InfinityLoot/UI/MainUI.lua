-- InfinityLoot UI Module
-- Top-of-the-line tabbed Loot, DKP, Session Tracking, Economy, and Commissions interface

InfinityLootUI = {
	currentTab = "dkp",
}

function InfinityLootUI:Toggle()
	if not _G.InfinityLootWindow then
		_G.InfinityLootWindow = self:Create()
		_G.InfinityLootWindow:Show()
		return
	end
	if _G.InfinityLootWindow:IsVisible() then
		_G.InfinityLootWindow:Hide()
	else
		self:ShowTab(_G.InfinityLootWindow, self.currentTab or "dkp")
		_G.InfinityLootWindow:Show()
	end
end

function InfinityLootUI:Create()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityLootWindow",
		UIParent,
		680,
		460,
		"Infinity Loot Manager",
		"DKP, Live Tracking & Economy"
	)
	frame:SetPoint("CENTER", 80, 0)

	local tabs = {
		{ name = "DKP & Raids", key = "dkp" },
		{ name = "Loot Tracker", key = "tracking" },
		{ name = "Economy", key = "economy" },
		{ name = "Commissions", key = "commissions" },
	}

	local tabBar = InfinityUIFramework:CreateTabBar(frame, tabs, function(key)
		InfinityLootUI.currentTab = key
		InfinityLootUI:ShowTab(frame, key)
	end, 656)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(656, 368)
	frame.contentArea:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	tabBar:SelectTab("dkp")
	return frame
end

function InfinityLootUI:ShowTab(frame, tabName)
	InfinityUIFramework:ClearContainer(frame.contentArea)
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
	local c = frame.contentArea
	local stats = (InfinityLootManager and InfinityLootManager.GetStatistics) and InfinityLootManager:GetStatistics() or {
		totalRaids = 0, totalMembers = 0, totalLootAwarded = 0, totalDkpSpent = 0
	}

	local t1 = InfinityUIFramework:CreateMetricTile(c, 154, 62, "Active Raids", stats.totalRaids or 0, "|cff38bdf8")
	t1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local t2 = InfinityUIFramework:CreateMetricTile(c, 154, 62, "Guild Members", stats.totalMembers or 0, "|cff4ade80")
	t2:SetPoint("LEFT", t1, "RIGHT", 12, 0)
	local t3 = InfinityUIFramework:CreateMetricTile(c, 154, 62, "Items Awarded", stats.totalLootAwarded or 0, "|cfffbbf24")
	t3:SetPoint("LEFT", t2, "RIGHT", 12, 0)
	local t4 = InfinityUIFramework:CreateMetricTile(c, 154, 62, "Total DKP Spent", stats.totalDkpSpent or 0, "|cffa855f7")
	t4:SetPoint("LEFT", t3, "RIGHT", 12, 0)

	local formCard = InfinityUIFramework:CreateCard(c, 654, 118, "Raid & Auction Quick Actions")
	formCard:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -14)

	local raidLbl = InfinityUIFramework:CreateLabel(formCard, "Raid Name:")
	raidLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -36)
	local raidInput = InfinityUIFramework:CreateInputBox(formCard, 200, 24)
	raidInput:SetPoint("LEFT", raidLbl, "RIGHT", 8, 0)
	raidInput:SetText("Naxxramas 40")

	local newRaidBtn = InfinityUIFramework:CreateButton(formCard, "Create Raid", 110, 24, function()
		local name = raidInput:GetText()
		if name == "" then name = "Guild Raid" end
		if InfinityLootManager and InfinityLootManager.CreateRaid then
			local raidId = InfinityLootManager:CreateRaid(name, InfinityUtils and InfinityUtils:GetTimeStamp() or time())
			InfinityUIFramework:ShowNotification("Created raid: " .. tostring(name) .. " (" .. tostring(raidId) .. ")", 3)
			InfinityLootUI:ShowTab(frame, "dkp")
		end
	end, true)
	newRaidBtn:SetPoint("LEFT", raidInput, "RIGHT", 10, 0)

	local auctionDeskBtn = InfinityUIFramework:CreateButton(formCard, "Open Live Auction Desk", 170, 26, function()
		if _G.InfinityAuctionUI and _G.InfinityAuctionUI.ShowAuctionFrame then
			_G.InfinityAuctionUI:ShowAuctionFrame()
		end
	end, true)
	auctionDeskBtn:SetPoint("TOPLEFT", raidLbl, "BOTTOMLEFT", 0, -22)

	local dkpWinBtn = InfinityUIFramework:CreateButton(formCard, "Open Full DKP Ledger", 156, 26, function()
		if _G.InfinityDKPUI and _G.InfinityDKPUI.Toggle then
			_G.InfinityDKPUI:Toggle()
		end
	end)
	dkpWinBtn:SetPoint("LEFT", auctionDeskBtn, "RIGHT", 10, 0)

	local officerBtn = InfinityUIFramework:CreateButton(formCard, "Officer Dashboard", 140, 26, function()
		if _G.InfinityOfficerDashboard and _G.InfinityOfficerDashboard.Toggle then
			_G.InfinityOfficerDashboard:Toggle()
		end
	end)
	officerBtn:SetPoint("LEFT", dkpWinBtn, "RIGHT", 10, 0)
end

function InfinityLootUI:ShowTrackingTab(frame)
	local c = frame.contentArea
	local s = (InfinityLootTracking and InfinityLootTracking.GetSessionStats) and InfinityLootTracking:GetSessionStats() or {
		totalValue = 0, goldPerHour = 0, totalItems = 0, kills = 0, lootPerHour = 0, elapsedSeconds = 0
	}

	local fmtGold = function(v) return (InfinityUtils and InfinityUtils.FormatGold) and InfinityUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end
	local fmtTime = function(v) return (InfinityUtils and InfinityUtils.FormatTime) and InfinityUtils:FormatTime(v or 0) or (tostring(v or 0) .. "s") end

	local m1 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Session Value", fmtGold(s.totalValue), "|cfffbbf24")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Gold / Hour", fmtGold(s.goldPerHour), "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Elapsed Time", fmtTime(s.elapsedSeconds), "|cff38bdf8")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local infoCard = InfinityUIFramework:CreateCard(c, 654, 110, "Live Farming Session")
	infoCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local summary = InfinityUIFramework:CreateLabel(
		infoCard,
		string.format("Items Looted: |cffffffff%d|r    |    Mobs Killed: |cffffffff%d|r    |    Loot / Hour: |cff38bdf8%.1f|r",
			s.totalItems or 0, s.kills or 0, s.lootPerHour or 0)
	)
	summary:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 12, -36)

	local pauseBtn = InfinityUIFramework:CreateButton(infoCard, "Pause", 90, 26, function()
		if InfinityLootTracking then InfinityLootTracking:PauseSession() end
		InfinityUIFramework:ShowNotification("Loot tracking paused.", 2)
	end)
	pauseBtn:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -18)

	local resumeBtn = InfinityUIFramework:CreateButton(infoCard, "Resume", 90, 26, function()
		if InfinityLootTracking then InfinityLootTracking:ResumeSession() end
		InfinityUIFramework:ShowNotification("Loot tracking resumed.", 2)
	end)
	resumeBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 8, 0)

	local newBtn = InfinityUIFramework:CreateButton(infoCard, "Start New Session", 140, 26, function()
		if InfinityLootTracking then InfinityLootTracking:StartNewSession() end
		InfinityUIFramework:ShowNotification("Started new loot tracking session.", 2)
		InfinityLootUI:ShowTab(frame, "tracking")
	end, true)
	newBtn:SetPoint("LEFT", resumeBtn, "RIGHT", 8, 0)
end

function InfinityLootUI:ShowEconomyTab(frame)
	local c = frame.contentArea
	local sum = (InfinityLootEconomy and InfinityLootEconomy.GetSummary) and InfinityLootEconomy:GetSummary() or {
		totalEarned = 0, totalSpent = 0, balance = 0, transactions = 0
	}
	local fmtGold = function(v) return (InfinityUtils and InfinityUtils.FormatGold) and InfinityUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end

	local m1 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Total Earned", fmtGold(sum.totalEarned), "|cff4ade80")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Total Spent", fmtGold(sum.totalSpent), "|cfff87171")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Net Balance (" .. tostring(sum.transactions or 0) .. " tx)", fmtGold(sum.balance), "|cfffbbf24")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = InfinityUIFramework:CreateCard(c, 654, 260, "Top Vendors & Merchants")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local merchants = (InfinityLootEconomy and InfinityLootEconomy.GetTopMerchants) and InfinityLootEconomy:GetTopMerchants(8) or {}
	if #merchants == 0 then
		local empty = InfinityUIFramework:CreateLabel(listCard, "|cff94a3b8No merchant transactions recorded yet. Sell or purchase items in-game to populate.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, m in ipairs(merchants) do
			local row = InfinityUIFramework:CreateListRow(listCard, 630, 24, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = InfinityUIFramework:CreateLabel(row, tostring(m.name))
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = InfinityUIFramework:CreateLabel(row, fmtGold(m.amount))
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 26
		end
	end
end

function InfinityLootUI:ShowCommissionsTab(frame)
	local c = frame.contentArea
	local stats = (InfinityLootCommissions and InfinityLootCommissions.GetStatistics) and InfinityLootCommissions:GetStatistics() or {
		totalQuestRegistered = 0, totalCompletions = 0, todayCompleted = 0
	}

	local m1 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Registered Quests", stats.totalQuestRegistered or 0, "|cff38bdf8")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Total Completions", stats.totalCompletions or 0, "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = InfinityUIFramework:CreateMetricTile(c, 210, 62, "Completed Today", stats.todayCompleted or 0, "|cfffbbf24")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = InfinityUIFramework:CreateCard(c, 654, 260, "Available Daily Commissions")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local available = (InfinityLootCommissions and InfinityLootCommissions.GetAvailableCommissions) and InfinityLootCommissions:GetAvailableCommissions() or {}
	if #available == 0 then
		local empty = InfinityUIFramework:CreateLabel(listCard, "|cff94a3b8No commissions available right now.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, quest in ipairs(available) do
			if i > 8 then break end
			local row = InfinityUIFramework:CreateListRow(listCard, 630, 24, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = InfinityUIFramework:CreateLabel(row, tostring(quest.name))
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = InfinityUIFramework:CreateLabel(row, "|cff94a3b8" .. tostring(quest.questGiver or "") .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 26
		end
	end
end

_G.InfinityLootUI = InfinityLootUI
return InfinityLootUI
