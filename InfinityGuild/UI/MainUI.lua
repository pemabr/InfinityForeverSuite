-- InfinityGuild UI Module
-- Top-of-the-line Guild Roster, DKP Standings, Events & Raid Manager for WoW Forever

InfinityGuildUI = {
	currentTab = "roster",
}

function InfinityGuildUI:Toggle(focusTab)
	if not _G.InfinityGuildWindow then
		_G.InfinityGuildWindow = self:Create()
		if focusTab and _G.InfinityGuildWindow.tabBar then
			_G.InfinityGuildWindow.tabBar:SelectTab(focusTab)
		end
		_G.InfinityGuildWindow:Show()
		return
	end
	if focusTab then
		self.currentTab = focusTab
		if _G.InfinityGuildWindow.tabBar then
			_G.InfinityGuildWindow.tabBar:SelectTab(focusTab)
		end
		_G.InfinityGuildWindow:Show()
		return
	end
	if _G.InfinityGuildWindow:IsVisible() then
		_G.InfinityGuildWindow:Hide()
	else
		self:ShowTab(_G.InfinityGuildWindow, self.currentTab or "roster")
		_G.InfinityGuildWindow:Show()
	end
end

function InfinityGuildUI:FocusTab(tabName)
	self:Toggle(tabName)
end

function InfinityGuildUI:Create()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityGuildWindow",
		UIParent,
		720,
		480,
		"Infinity Guild Manager",
		"Roster, DKP & Events"
	)
	frame:SetPoint("CENTER", -60, 0)

	local tabs = {
		{ name = "Roster", key = "roster" },
		{ name = "DKP Standings", key = "dkp" },
		{ name = "Events", key = "events" },
		{ name = "Active Raids", key = "raiding" },
	}

	local tabBar = InfinityUIFramework:CreateTabBar(frame, tabs, function(key)
		InfinityGuildUI.currentTab = key
		InfinityGuildUI:ShowTab(frame, key)
	end, 696)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(696, 388)
	frame.contentArea:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	tabBar:SelectTab("roster")
	return frame
end

function InfinityGuildUI:ShowTab(frame, tabName)
	InfinityUIFramework:ClearContainer(frame.contentArea)
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

function InfinityGuildUI:ShowRosterTab(frame)
	local c = frame.contentArea
	local actionCard = InfinityUIFramework:CreateCard(c, 696, 72, "Guild Controls")
	actionCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local gNameLbl = InfinityUIFramework:CreateLabel(actionCard, "Guild Name:")
	gNameLbl:SetPoint("TOPLEFT", actionCard, "TOPLEFT", 12, -36)
	local gNameBox = InfinityUIFramework:CreateInputBox(actionCard, 180, 22)
	gNameBox:SetPoint("LEFT", gNameLbl, "RIGHT", 8, 0)
	local currentGuild = GetGuildInfo and GetGuildInfo("player") or "Infinity Vanguard"
	gNameBox:SetText(currentGuild or "Infinity Vanguard")

	local regBtn = InfinityUIFramework:CreateButton(actionCard, "Register Guild", 116, 24, function()
		local name = gNameBox:GetText()
		if name == "" then name = "Infinity Vanguard" end
		if InfinityGuildRoster and InfinityGuildRoster.RegisterGuild then
			InfinityGuildRoster:RegisterGuild(name, string.sub(name, 1, 3):upper(), 1)
			InfinityUIFramework:ShowNotification("Registered guild: " .. name, 2.5)
			InfinityGuildUI:ShowTab(frame, "roster")
		end
	end, true)
	regBtn:SetPoint("LEFT", gNameBox, "RIGHT", 10, 0)

	local syncBtn = InfinityUIFramework:CreateButton(actionCard, "Sync WoW Roster", 126, 24, function()
		if GuildRoster then pcall(GuildRoster) end
		if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
		local count = GetNumGuildMembers and GetNumGuildMembers() or 0
		InfinityUIFramework:ShowNotification("Synced live guild roster (" .. tostring(count) .. " members).", 2.5)
		InfinityGuildUI:ShowTab(frame, "roster")
	end)
	syncBtn:SetPoint("LEFT", regBtn, "RIGHT", 8, 0)

	local listCard = InfinityUIFramework:CreateCard(c, 696, 298, "Registered Guilds")
	listCard:SetPoint("TOPLEFT", actionCard, "BOTTOMLEFT", 0, -10)

	local guilds = (InfinityGuildRoster and InfinityGuildRoster.guilds) or {}
	local y = -34
	local idx = 0
	for guildName, guild in pairs(guilds) do
		idx = idx + 1
		local stats = InfinityGuildRoster:GetGuildStats(guildName) or { memberCount = 0, activeMembers = 0, averageLevel = 0, treasury = 0 }
		local row = InfinityUIFramework:CreateListRow(listCard, 672, 34, idx)
		row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)

		local l = InfinityUIFramework:CreateLabel(row, string.format("|cff38bdf8%s|r  (Lv %d)", guildName, guild.level or 1))
		l:SetPoint("LEFT", row, "LEFT", 10, 0)

		local r = InfinityUIFramework:CreateLabel(
			row,
			string.format("Members: |cffffffff%d|r (%d active)  |  Avg Lv: %.1f  |  Bank: %s",
				stats.memberCount or 0, stats.activeMembers or 0, stats.averageLevel or 0,
				(InfinityUtils and InfinityUtils.FormatGold) and InfinityUtils:FormatGold(stats.treasury or 0) or "0g")
		)
		r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		y = y - 38
	end

	if idx == 0 then
		local empty = InfinityUIFramework:CreateLabel(listCard, "|cff94a3b8No guilds registered yet. Click 'Register Guild' above to initialize.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -38)
	end
end

function InfinityGuildUI:ShowDKPTab(frame)
	local c = frame.contentArea
	local standings = {}
	if InfinityGuildRoster and InfinityGuildRoster.guilds and InfinityGuildDKP then
		for guildName, _ in pairs(InfinityGuildRoster.guilds) do
			standings = InfinityGuildDKP:GetDKPStandings(guildName) or {}
			break
		end
	end

	local topCard = InfinityUIFramework:CreateCard(c, 696, 300, "Guild DKP Leaderboard")
	topCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local maxDkp = 1
	for _, m in ipairs(standings) do
		if (m.dkp or 0) > maxDkp then maxDkp = m.dkp end
	end

	if #standings == 0 then
		local empty = InfinityUIFramework:CreateLabel(topCard, "|cff94a3b8No guild DKP standings recorded yet. Open /dkp or /officer to award points.|r")
		empty:SetPoint("TOPLEFT", topCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, member in ipairs(standings) do
			if i > 9 then break end
			local cr, cg, cb, cHex = InfinityUIFramework:GetClassColor(member.class)
			local bar = InfinityUIFramework:CreateStatusBar(topCard, 672, 24, cr, cg, cb)
			bar:SetPoint("TOPLEFT", topCard, "TOPLEFT", 12, y)
			local pct = ((member.dkp or 0) / maxDkp) * 100
			bar:SetBarData(pct, string.format("#%d  %s%s|r (%s)", i, cHex, member.name, tostring(member.class or "")), tostring(member.dkp or 0) .. " DKP")
			y = y - 27
		end
	end

	local syncBtn = InfinityUIFramework:CreateButton(c, "Broadcast DKP Sync", 150, 28, function()
		if InfinityGuildDKP and InfinityGuildDKP.SyncDKPWithGuild then
			InfinityGuildDKP:SyncDKPWithGuild()
		end
		InfinityUIFramework:ShowNotification("DKP ledger synced with guild.", 2.5)
	end, true)
	syncBtn:SetPoint("TOPLEFT", topCard, "BOTTOMLEFT", 0, -12)

	local dkpOpenBtn = InfinityUIFramework:CreateButton(c, "Open Full DKP Manager", 164, 28, function()
		if _G.InfinityDKPUI and _G.InfinityDKPUI.Toggle then _G.InfinityDKPUI:Toggle() end
	end)
	dkpOpenBtn:SetPoint("LEFT", syncBtn, "RIGHT", 10, 0)
end

function InfinityGuildUI:ShowEventsTab(frame)
	local c = frame.contentArea
	local formCard = InfinityUIFramework:CreateCard(c, 696, 74, "Schedule Guild Event")
	formCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local nameLbl = InfinityUIFramework:CreateLabel(formCard, "Title:")
	nameLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -36)
	local nameBox = InfinityUIFramework:CreateInputBox(formCard, 220, 22)
	nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
	nameBox:SetText("Naxxramas Progression")

	local createBtn = InfinityUIFramework:CreateButton(formCard, "Create Event (+24h)", 140, 24, function()
		local title = nameBox:GetText()
		if title == "" then title = "Guild Raid" end
		if InfinityGuildEvents and InfinityGuildEvents.CreateEvent then
			InfinityGuildEvents:CreateEvent(title, "raid", (InfinityUtils and InfinityUtils:GetTimeStamp() or time()) + 86400)
			InfinityUIFramework:ShowNotification("Scheduled event: " .. title, 2.5)
			InfinityGuildUI:ShowTab(frame, "events")
		end
	end, true)
	createBtn:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)

	local listCard = InfinityUIFramework:CreateCard(c, 696, 296, "Upcoming Guild Events (Next 7 Days)")
	listCard:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	local events = (InfinityGuildEvents and InfinityGuildEvents.GetUpcomingEvents) and InfinityGuildEvents:GetUpcomingEvents(7) or {}
	if #events == 0 then
		local empty = InfinityUIFramework:CreateLabel(listCard, "|cff94a3b8No upcoming events scheduled.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, ev in ipairs(events) do
			if i > 8 then break end
			local row = InfinityUIFramework:CreateListRow(listCard, 672, 26, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = InfinityUIFramework:CreateLabel(row, "|cff38bdf8" .. tostring(ev.name) .. "|r")
			l:SetPoint("LEFT", row, "LEFT", 10, 0)
			local r = InfinityUIFramework:CreateLabel(row, "|cfffbbf24" .. tostring(ev.type or "event"):upper() .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			y = y - 28
		end
	end
end

function InfinityGuildUI:ShowRaidingTab(frame)
	local c = frame.contentArea
	local formCard = InfinityUIFramework:CreateCard(c, 696, 74, "Launch Guild Raid")
	formCard:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local rBox = InfinityUIFramework:CreateInputBox(formCard, 220, 22)
	rBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -34)
	rBox:SetText("Naxxramas 40-Man")

	local createBtn = InfinityUIFramework:CreateButton(formCard, "Start Raid Session", 140, 24, function()
		local name = rBox:GetText()
		if name == "" then name = "Guild Raid" end
		if InfinityGuildEvents and InfinityGuildEvents.CreateRaid then
			InfinityGuildEvents:CreateRaid(name, "RAID", "40-Man")
			InfinityUIFramework:ShowNotification("Started raid: " .. name, 2.5)
			InfinityGuildUI:ShowTab(frame, "raiding")
		end
	end, true)
	createBtn:SetPoint("LEFT", rBox, "RIGHT", 10, 0)

	local listCard = InfinityUIFramework:CreateCard(c, 696, 296, "Active Raids")
	listCard:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	local activeRaids = (InfinityGuildEvents and InfinityGuildEvents.GetActiveRaids) and InfinityGuildEvents:GetActiveRaids() or {}
	if #activeRaids == 0 then
		local empty = InfinityUIFramework:CreateLabel(listCard, "|cff94a3b8No active raids right now.|r")
		empty:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, -36)
	else
		local y = -34
		for i, raid in ipairs(activeRaids) do
			if i > 6 then break end
			local stats = InfinityGuildEvents:GetRaidStats(raid.id) or { participantCount = 0, bossesFelled = 0, lootCount = 0 }
			local row = InfinityUIFramework:CreateListRow(listCard, 672, 34, i)
			row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)
			local l = InfinityUIFramework:CreateLabel(row, "|cff4ade80" .. tostring(raid.name) .. "|r (" .. tostring(raid.type or "RAID") .. ")")
			l:SetPoint("LEFT", row, "LEFT", 10, 0)
			local r = InfinityUIFramework:CreateLabel(row, string.format("Raiders: %d  |  Bosses: %d  |  Loot: %d", stats.participantCount or 0, stats.bossesFelled or 0, stats.lootCount or 0))
			r:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			y = y - 38
		end
	end
end

_G.InfinityGuildUI = InfinityGuildUI
return InfinityGuildUI
