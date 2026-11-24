-- PluribusLoot UI Module
-- Top-of-the-line tabbed Loot, DKP, Session Tracking, Economy, and Commissions interface

PluribusLootUI = {
	currentTab = "dkp",
}

function PluribusLootUI:Toggle()
	if not _G.PluribusLootWindow then
		_G.PluribusLootWindow = self:Create()
		_G.PluribusLootWindow:Show()
		return
	end
	if _G.PluribusLootWindow:IsVisible() then
		_G.PluribusLootWindow:Hide()
	else
		self:ShowTab(_G.PluribusLootWindow, self.currentTab or "dkp")
		_G.PluribusLootWindow:Show()
	end
end

function PluribusLootUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusLootWindow",
		UIParent,
		680,
		460,
		"Pluribus Loot Manager",
		"DKP, Live Tracking & Economy"
	)
	frame:SetPoint("CENTER", 80, 0)

	local tabs = {
		{ name = "DKP & Raids", key = "dkp" },
		{ name = "Loot Tracker", key = "tracking" },
		{ name = "Economy", key = "economy" },
		{ name = "Commissions", key = "commissions" },
	}

	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(key)
		PluribusLootUI.currentTab = key
		PluribusLootUI:ShowTab(frame, key)
	end, 656)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(656, 368)
	frame.contentArea:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	tabBar:SelectTab("dkp")
	return frame
end

function PluribusLootUI:ShowTab(frame, tabName)
	PluribusUIFramework:ClearContainer(frame.contentArea)
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

function PluribusLootUI:ShowDKPTab(frame)
	local c = frame.contentArea
	local stats = (PluribusLootManager and PluribusLootManager.GetStatistics) and PluribusLootManager:GetStatistics() or {
		totalRaids = 0, totalMembers = 0, totalLootAwarded = 0, totalDkpSpent = 0
	}

	local t1 = PluribusUIFramework:CreateMetricTile(c, 154, 62, "Active Raids", stats.totalRaids or 0, "|cff38bdf8")
	t1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local t2 = PluribusUIFramework:CreateMetricTile(c, 154, 62, "Guild Members", stats.totalMembers or 0, "|cff4ade80")
	t2:SetPoint("LEFT", t1, "RIGHT", 12, 0)
	local t3 = PluribusUIFramework:CreateMetricTile(c, 154, 62, "Items Awarded", stats.totalLootAwarded or 0, "|cfffbbf24")
	t3:SetPoint("LEFT", t2, "RIGHT", 12, 0)
	local t4 = PluribusUIFramework:CreateMetricTile(c, 154, 62, "Total DKP Spent", stats.totalDkpSpent or 0, "|cffa855f7")
	t4:SetPoint("LEFT", t3, "RIGHT", 12, 0)

	local formCard = PluribusUIFramework:CreateCard(c, 654, 118, "Raid & Auction Quick Actions")
	formCard:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -14)

	local raidLbl = PluribusUIFramework:CreateLabel(formCard, "Raid Name:")
	raidLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -36)
	local raidInput = PluribusUIFramework:CreateInputBox(formCard, 200, 24)
	raidInput:SetPoint("LEFT", raidLbl, "RIGHT", 8, 0)
	raidInput:SetText("Naxxramas 40")

	local newRaidBtn = PluribusUIFramework:CreateButton(formCard, "Create Raid", 110, 24, function()
		local name = raidInput:GetText()
		if name == "" then name = "Guild Raid" end
		if PluribusLootManager and PluribusLootManager.CreateRaid then
			local raidId = PluribusLootManager:CreateRaid(name, PluribusUtils and PluribusUtils:GetTimeStamp() or time())
			PluribusUIFramework:ShowNotification("Created raid: " .. tostring(name) .. " (" .. tostring(raidId) .. ")", 3)
			PluribusLootUI:ShowTab(frame, "dkp")
		end
	end, true)
	newRaidBtn:SetPoint("LEFT", raidInput, "RIGHT", 10, 0)

	local auctionDeskBtn = PluribusUIFramework:CreateButton(formCard, "Open Live Auction Desk", 170, 26, function()
		if _G.PluribusAuctionUI and _G.PluribusAuctionUI.ShowAuctionFrame then
			_G.PluribusAuctionUI:ShowAuctionFrame()
		end
	end, true)
	auctionDeskBtn:SetPoint("TOPLEFT", raidLbl, "BOTTOMLEFT", 0, -22)

	local dkpWinBtn = PluribusUIFramework:CreateButton(formCard, "Open Full DKP Ledger", 156, 26, function()
		if _G.PluribusDKPUI and _G.PluribusDKPUI.Toggle then
			_G.PluribusDKPUI:Toggle()
		end
	end)
	dkpWinBtn:SetPoint("LEFT", auctionDeskBtn, "RIGHT", 10, 0)

	local officerBtn = PluribusUIFramework:CreateButton(formCard, "Officer Dashboard", 140, 26, function()
		if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Toggle then
			_G.PluribusOfficerDashboard:Toggle()
		end
	end)
	officerBtn:SetPoint("LEFT", dkpWinBtn, "RIGHT", 10, 0)
end

function PluribusLootUI:ShowTrackingTab(frame)
	local c = frame.contentArea
	local s = (PluribusLootTracking and PluribusLootTracking.GetSessionStats) and PluribusLootTracking:GetSessionStats() or {
		totalValue = 0, goldPerHour = 0, totalItems = 0, kills = 0, lootPerHour = 0, elapsedSeconds = 0
	}

	local fmtGold = function(v) return (PluribusUtils and PluribusUtils.FormatGold) and PluribusUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end
	local fmtTime = function(v) return (PluribusUtils and PluribusUtils.FormatTime) and PluribusUtils:FormatTime(v or 0) or (tostring(v or 0) .. "s") end

	local m1 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Session Value", fmtGold(s.totalValue), "|cfffbbf24")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Gold / Hour", fmtGold(s.goldPerHour), "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Elapsed Time", fmtTime(s.elapsedSeconds), "|cff38bdf8")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local infoCard = PluribusUIFramework:CreateCard(c, 654, 110, "Live Farming Session")
	infoCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local summary = PluribusUIFramework:CreateLabel(
		infoCard,
		string.format("Items Looted: |cffffffff%d|r    |    Mobs Killed: |cffffffff%d|r    |    Loot / Hour: |cff38bdf8%.1f|r",
			s.totalItems or 0, s.kills or 0, s.lootPerHour or 0)
	)
	summary:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 12, -36)

	local pauseBtn = PluribusUIFramework:CreateButton(infoCard, "Pause", 90, 26, function()
		if PluribusLootTracking then PluribusLootTracking:PauseSession() end
		PluribusUIFramework:ShowNotification("Loot tracking paused.", 2)
	end)
	pauseBtn:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -18)

	local resumeBtn = PluribusUIFramework:CreateButton(infoCard, "Resume", 90, 26, function()
		if PluribusLootTracking then PluribusLootTracking:ResumeSession() end
		PluribusUIFramework:ShowNotification("Loot tracking resumed.", 2)
	end)
	resumeBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 8, 0)

	local newBtn = PluribusUIFramework:CreateButton(infoCard, "Start New Session", 140, 26, function()
		if PluribusLootTracking then PluribusLootTracking:StartNewSession() end
		PluribusUIFramework:ShowNotification("Started new loot tracking session.", 2)
		PluribusLootUI:ShowTab(frame, "tracking")
	end, true)
	newBtn:SetPoint("LEFT", resumeBtn, "RIGHT", 8, 0)
end

function PluribusLootUI:ShowEconomyTab(frame)
	local c = frame.contentArea
	local sum = (PluribusLootEconomy and PluribusLootEconomy.GetSummary) and PluribusLootEconomy:GetSummary() or {
		totalEarned = 0, totalSpent = 0, balance = 0, transactions = 0
	}
	local fmtGold = function(v) return (PluribusUtils and PluribusUtils.FormatGold) and PluribusUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end

	local m1 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Total Earned", fmtGold(sum.totalEarned), "|cff4ade80")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Total Spent", fmtGold(sum.totalSpent), "|cfff87171")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Net Balance (" .. tostring(sum.transactions or 0) .. " tx)", fmtGold(sum.balance), "|cfffbbf24")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = PluribusUIFramework:CreateCard(c, 654, 260, "Top Vendors & Merchants")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local merchants = (PluribusLootEconomy and PluribusLootEconomy.GetTopMerchants) and PluribusLootEconomy:GetTopMerchants(8) or {}
	if #merchants == 0 then
		local empty = PluribusUIFramework:CreateLabel(listCard, "|cff94a3b8No merchant transactions recorded yet. Sell or purchase items in-game to populate.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, m in ipairs(merchants) do
			local row = PluribusUIFramework:CreateListRow(listCard, 630, 24, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = PluribusUIFramework:CreateLabel(row, tostring(m.name))
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = PluribusUIFramework:CreateLabel(row, fmtGold(m.amount))
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 26
		end
	end
end

function PluribusLootUI:ShowCommissionsTab(frame)
	local c = frame.contentArea
	local stats = (PluribusLootCommissions and PluribusLootCommissions.GetStatistics) and PluribusLootCommissions:GetStatistics() or {
		totalQuestRegistered = 0, totalCompletions = 0, todayCompleted = 0
	}

	local m1 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Registered Quests", stats.totalQuestRegistered or 0, "|cff38bdf8")
	m1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	local m2 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Total Completions", stats.totalCompletions or 0, "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(c, 210, 62, "Completed Today", stats.todayCompleted or 0, "|cfffbbf24")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = PluribusUIFramework:CreateCard(c, 654, 260, "Available Daily Commissions")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

	local available = (PluribusLootCommissions and PluribusLootCommissions.GetAvailableCommissions) and PluribusLootCommissions:GetAvailableCommissions() or {}
	if #available == 0 then
		local empty = PluribusUIFramework:CreateLabel(listCard, "|cff94a3b8No commissions available right now.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, quest in ipairs(available) do
			if i > 8 then break end
			local row = PluribusUIFramework:CreateListRow(listCard, 630, 24, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = PluribusUIFramework:CreateLabel(row, tostring(quest.name))
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = PluribusUIFramework:CreateLabel(row, "|cff94a3b8" .. tostring(quest.questGiver or "") .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 26
		end
	end
end

_G.PluribusLootUI = PluribusLootUI
return PluribusLootUI
