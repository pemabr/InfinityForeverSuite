-- PluribusGuild UI Module
-- Top-of-the-line Guild Roster, DKP Standings, Events & Raid Manager for WoW Forever

PluribusGuildUI = {
	currentTab = "roster",
}

function PluribusGuildUI:Toggle(focusTab)
	if not _G.PluribusGuildWindow then
		_G.PluribusGuildWindow = self:Create()
		if focusTab and _G.PluribusGuildWindow.tabBar then
			_G.PluribusGuildWindow.tabBar:SelectTab(focusTab)
		end
		_G.PluribusGuildWindow:Show()
		return
	end
	if focusTab then
		self.currentTab = focusTab
		if _G.PluribusGuildWindow.tabBar then
			_G.PluribusGuildWindow.tabBar:SelectTab(focusTab)
		end
		_G.PluribusGuildWindow:Show()
		return
	end
	if _G.PluribusGuildWindow:IsVisible() then
		_G.PluribusGuildWindow:Hide()
	else
		self:ShowTab(_G.PluribusGuildWindow, self.currentTab or "roster")
		_G.PluribusGuildWindow:Show()
	end
end

function PluribusGuildUI:FocusTab(tabName)
	self:Toggle(tabName)
end

function PluribusGuildUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusGuildWindow",
		UIParent,
		720,
		480,
		"Pluribus Guild Manager",
		"Roster, DKP & Events"
	)
	frame:SetPoint("CENTER", -60, 0)

	local tabs = {
		{ name = "Roster", key = "roster" },
		{ name = "DKP Standings", key = "dkp" },
		{ name = "Events", key = "events" },
		{ name = "Active Raids", key = "raiding" },
	}

	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(key)
		PluribusGuildUI.currentTab = key
		PluribusGuildUI:ShowTab(frame, key)
	end, 696)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(696, 388)
	frame.contentArea:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	tabBar:SelectTab("roster")
	return frame
end

function PluribusGuildUI:ShowTab(frame, tabName)
	PluribusUIFramework:ClearContainer(frame.contentArea)
	if tabName == "roster" then
		self:ShowRosterTab(frame)
	elseif tabName == "dkp" then
		self:ShowDKPTab(frame)
	elseif tabName == "events" then
		self:ShowEventsTab(frame)
	elseif tabName == "raiding" then
		self:ShowRaidingTab(frame)
	end
end

function PluribusGuildUI:ShowRosterTab(frame)
	local c = frame.contentArea
	local actionCard = PluribusUIFramework:CreateCard(c, 696, 72, "Guild Controls")
	actionCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local gNameLbl = PluribusUIFramework:CreateLabel(actionCard, "Guild Name:")
	gNameLbl:SetPoint("TOPLEFT", actionCard, "TOPLEFT", 12, -36)
	local gNameBox = PluribusUIFramework:CreateInputBox(actionCard, 180, 22)
	gNameBox:SetPoint("LEFT", gNameLbl, "RIGHT", 8, 0)
	local currentGuild = GetGuildInfo and GetGuildInfo("player") or "Pluribus Vanguard"
	gNameBox:SetText(currentGuild or "Pluribus Vanguard")

	local regBtn = PluribusUIFramework:CreateButton(actionCard, "Register Guild", 116, 24, function()
		local name = gNameBox:GetText()
		if name == "" then name = "Pluribus Vanguard" end
		if PluribusGuildRoster and PluribusGuildRoster.RegisterGuild then
			PluribusGuildRoster:RegisterGuild(name, string.sub(name, 1, 3):upper(), 1)
			PluribusUIFramework:ShowNotification("Registered guild: " .. name, 2.5)
			PluribusGuildUI:ShowTab(frame, "roster")
		end
	end, true)
	regBtn:SetPoint("LEFT", gNameBox, "RIGHT", 10, 0)

	local syncBtn = PluribusUIFramework:CreateButton(actionCard, "Sync WoW Roster", 126, 24, function()
		if GuildRoster then pcall(GuildRoster) end
		if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
		local count = GetNumGuildMembers and GetNumGuildMembers() or 0
		PluribusUIFramework:ShowNotification("Synced live guild roster (" .. tostring(count) .. " members).", 2.5)
		PluribusGuildUI:ShowTab(frame, "roster")
	end)
	syncBtn:SetPoint("LEFT", regBtn, "RIGHT", 8, 0)

	local listCard = PluribusUIFramework:CreateCard(c, 696, 298, "Registered Guilds")
	listCard:SetPoint("TOPLEFT", actionCard, "BOTTOMLEFT", 0, -10)

	local guilds = (PluribusGuildRoster and PluribusGuildRoster.guilds) or {}
	local y = -34
	local idx = 0
	for guildName, guild in pairs(guilds) do
		idx = idx + 1
		local stats = PluribusGuildRoster:GetGuildStats(guildName) or { memberCount = 0, activeMembers = 0, averageLevel = 0, treasury = 0 }
		local row = PluribusUIFramework:CreateListRow(listCard, 672, 34, idx)
		row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)

		local l = PluribusUIFramework:CreateLabel(row, string.format("|cff38bdf8%s|r  (Lv %d)", guildName, guild.level or 1))
		l:SetPoint("LEFT", row, "LEFT", 10, 0)

		local r = PluribusUIFramework:CreateLabel(
			row,
			string.format("Members: |cffffffff%d|r (%d active)  |  Avg Lv: %.1f  |  Bank: %s",
				stats.memberCount or 0, stats.activeMembers or 0, stats.averageLevel or 0,
				(PluribusUtils and PluribusUtils.FormatGold) and PluribusUtils:FormatGold(stats.treasury or 0) or "0g")
		)
		r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		y = y - 38
	end

	if idx == 0 then
		local empty = PluribusUIFramework:CreateLabel(listCard, "|cff94a3b8No guilds registered yet. Click 'Register Guild' above to initialize.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -38)
	end
end

function PluribusGuildUI:ShowDKPTab(frame)
	local c = frame.contentArea
	local standings = {}
	if PluribusGuildRoster and PluribusGuildRoster.guilds and PluribusGuildDKP then
		for guildName, _ in pairs(PluribusGuildRoster.guilds) do
			standings = PluribusGuildDKP:GetDKPStandings(guildName) or {}
			break
		end
	end

	local topCard = PluribusUIFramework:CreateCard(c, 696, 300, "Guild DKP Leaderboard")
	topCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local maxDkp = 1
	for _, m in ipairs(standings) do
		if (m.dkp or 0) > maxDkp then maxDkp = m.dkp end
	end

	if #standings == 0 then
		local empty = PluribusUIFramework:CreateLabel(topCard, "|cff94a3b8No guild DKP standings recorded yet. Open /dkp or /officer to award points.|r")
		empty:SetPoint("TOPLEFT", topCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, member in ipairs(standings) do
			if i > 9 then break end
			local cr, cg, cb, cHex = PluribusUIFramework:GetClassColor(member.class)
			local bar = PluribusUIFramework:CreateStatusBar(topCard, 672, 24, cr, cg, cb)
			bar:SetPoint("TOPLEFT", topCard, "TOPLEFT", 12, y)
			local pct = ((member.dkp or 0) / maxDkp) * 100
			bar:SetBarData(pct, string.format("#%d  %s%s|r (%s)", i, cHex, member.name, tostring(member.class or "")), tostring(member.dkp or 0) .. " DKP")
			y = y - 27
		end
	end

	local syncBtn = PluribusUIFramework:CreateButton(c, "Broadcast DKP Sync", 150, 28, function()
		if PluribusGuildDKP and PluribusGuildDKP.SyncDKPWithGuild then
			PluribusGuildDKP:SyncDKPWithGuild()
		end
		PluribusUIFramework:ShowNotification("DKP ledger synced with guild.", 2.5)
	end, true)
	syncBtn:SetPoint("TOPLEFT", topCard, "BOTTOMLEFT", 0, -12)

	local dkpOpenBtn = PluribusUIFramework:CreateButton(c, "Open Full DKP Manager", 164, 28, function()
		if _G.PluribusDKPUI and _G.PluribusDKPUI.Toggle then _G.PluribusDKPUI:Toggle() end
	end)
	dkpOpenBtn:SetPoint("LEFT", syncBtn, "RIGHT", 10, 0)
end

function PluribusGuildUI:ShowEventsTab(frame)
	local c = frame.contentArea
	local formCard = PluribusUIFramework:CreateCard(c, 696, 74, "Schedule Guild Event")
	formCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local nameLbl = PluribusUIFramework:CreateLabel(formCard, "Title:")
	nameLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -36)
	local nameBox = PluribusUIFramework:CreateInputBox(formCard, 220, 22)
	nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
	nameBox:SetText("Naxxramas Progression")

	local createBtn = PluribusUIFramework:CreateButton(formCard, "Create Event (+24h)", 140, 24, function()
		local title = nameBox:GetText()
		if title == "" then title = "Guild Raid" end
		if PluribusGuildEvents and PluribusGuildEvents.CreateEvent then
			PluribusGuildEvents:CreateEvent(title, "raid", (PluribusUtils and PluribusUtils:GetTimeStamp() or time()) + 86400)
			PluribusUIFramework:ShowNotification("Scheduled event: " .. title, 2.5)
			PluribusGuildUI:ShowTab(frame, "events")
		end
	end, true)
	createBtn:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)

	local listCard = PluribusUIFramework:CreateCard(c, 696, 296, "Upcoming Guild Events (Next 7 Days)")
	listCard:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	local events = (PluribusGuildEvents and PluribusGuildEvents.GetUpcomingEvents) and PluribusGuildEvents:GetUpcomingEvents(7) or {}
	if #events == 0 then
		local empty = PluribusUIFramework:CreateLabel(listCard, "|cff94a3b8No upcoming events scheduled.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, ev in ipairs(events) do
			if i > 8 then break end
			local row = PluribusUIFramework:CreateListRow(listCard, 672, 26, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = PluribusUIFramework:CreateLabel(row, "|cff38bdf8" .. tostring(ev.name) .. "|r")
			l:SetPoint("LEFT", row, "LEFT", 10, 0)
			local r = PluribusUIFramework:CreateLabel(row, "|cfffbbf24" .. tostring(ev.type or "event"):upper() .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			y = y - 28
		end
	end
end

function PluribusGuildUI:ShowRaidingTab(frame)
	local c = frame.contentArea
	local formCard = PluribusUIFramework:CreateCard(c, 696, 74, "Launch Guild Raid")
	formCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local rBox = PluribusUIFramework:CreateInputBox(formCard, 220, 22)
	rBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -34)
	rBox:SetText("Naxxramas 40-Man")

	local createBtn = PluribusUIFramework:CreateButton(formCard, "Start Raid Session", 140, 24, function()
		local name = rBox:GetText()
		if name == "" then name = "Guild Raid" end
		if PluribusGuildEvents and PluribusGuildEvents.CreateRaid then
			PluribusGuildEvents:CreateRaid(name, "RAID", "40-Man")
			PluribusUIFramework:ShowNotification("Started raid: " .. name, 2.5)
			PluribusGuildUI:ShowTab(frame, "raiding")
		end
	end, true)
	createBtn:SetPoint("LEFT", rBox, "RIGHT", 10, 0)

	local listCard = PluribusUIFramework:CreateCard(c, 696, 296, "Active Raids")
	listCard:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	local activeRaids = (PluribusGuildEvents and PluribusGuildEvents.GetActiveRaids) and PluribusGuildEvents:GetActiveRaids() or {}
	if #activeRaids == 0 then
		local empty = PluribusUIFramework:CreateLabel(listCard, "|cff94a3b8No active raids right now.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, raid in ipairs(activeRaids) do
			if i > 6 then break end
			local stats = PluribusGuildEvents:GetRaidStats(raid.id) or { participantCount = 0, bossesFelled = 0, lootCount = 0 }
			local row = PluribusUIFramework:CreateListRow(listCard, 672, 34, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = PluribusUIFramework:CreateLabel(row, "|cff4ade80" .. tostring(raid.name) .. "|r (" .. tostring(raid.type or "RAID") .. ")")
			l:SetPoint("LEFT", row, "LEFT", 10, 0)
			local r = PluribusUIFramework:CreateLabel(row, string.format("Raiders: %d  |  Bosses: %d  |  Loot: %d", stats.participantCount or 0, stats.bossesFelled or 0, stats.lootCount or 0))
			r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			y = y - 38
		end
	end
end

_G.PluribusGuildUI = PluribusGuildUI
return PluribusGuildUI
