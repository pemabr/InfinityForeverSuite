-- InfinityCore Officer Dashboard
-- Modern interactive guild management interface for WoW Forever officers (no placeholders)

local InfinityCore = InfinityCore or {}
InfinityCore.OfficerDashboard = {
	enabled = true,
	visible = false,
	frame = nil,
	config = {
		width = 820,
		height = 560,
	},
	tabs = {
		{ id = "overview", label = "Overview" },
		{ id = "dkp_management", label = "DKP & Awards" },
		{ id = "loot_audits", label = "Loot Audits" },
		{ id = "player_status", label = "Rankings" },
		{ id = "settings", label = "Settings" },
	},
	current_tab = "overview",
}

local Dashboard = InfinityCore.OfficerDashboard
_G.InfinityOfficerDashboard = Dashboard

local function EnsureUI()
	return _G.InfinityUIFramework
end

local function GetDKPEngine()
	return _G.InfinityDKPEngine
end

function Dashboard:Initialize()
	if self.frame then return end
	self:CreateFrame()
end

function Dashboard:CreateFrame()
	if self.frame then return end
	local UI = EnsureUI()

	local frame = UI:CreateFrame(
		"InfinityOfficerDashboard",
		UIParent,
		self.config.width,
		self.config.height,
		"InfinityForever — Officer Dashboard"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetScript("OnHide", function()
		Dashboard.visible = false
	end)

	-- Persistent visual HiveMind connectivity & data-sync health indicator in Officer Dashboard header
	if frame.header and _G.InfinityHiveUI and _G.InfinityHiveUI.CreateHealthBadge then
		local badge = _G.InfinityHiveUI:CreateHealthBadge(frame.header, function()
			if Dashboard.visible then Dashboard:RefreshContent() end
		end)
		if badge and frame.closeBtn then
			badge:SetPoint("RIGHT", frame.closeBtn, "LEFT", -8, 0)
			frame.healthBadge = badge
		end
	end

	-- Tab bar container
	local tabBar = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	tabBar:SetHeight(34)
	tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)
	tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -44)

	frame.tabs = {}
	local btnWidth = 152
	for idx, tabDef in ipairs(self.tabs) do
		local tabBtn = UI:CreateButton(tabBar, tabDef.label, btnWidth, 28, function()
			Dashboard:SwitchTab(tabDef.id)
		end)
		tabBtn:SetPoint("LEFT", tabBar, "LEFT", (idx - 1) * (btnWidth + 8), 0)
		frame.tabs[tabDef.id] = tabBtn
	end

	-- Content panel
	local content = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -84)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 14)
	UI:ApplyBackdrop(content, 0.09, 0.11, 0.16, 0.95, 0.22, 0.28, 0.38, 0.85)

	frame.content = content
	frame:Hide()
	self.frame = frame
end

function Dashboard:SwitchTab(tabId)
	self.current_tab = tabId
	for id, btn in pairs(self.frame.tabs) do
		btn:SetActiveState(id == tabId)
	end
	self:RefreshContent()
end

function Dashboard:RefreshContent()
	local UI = EnsureUI()
	local content = self.frame.content
	UI:ClearContainer(content)

	if self.current_tab == "overview" then
		self:ShowOverview(content)
	elseif self.current_tab == "dkp_management" then
		self:ShowDKPManagement(content)
	elseif self.current_tab == "loot_audits" then
		self:ShowLootAudits(content)
	elseif self.current_tab == "player_status" then
		self:ShowPlayerStatus(content)
	elseif self.current_tab == "settings" then
		self:ShowSettings(content)
	end
end

function Dashboard:ShowOverview(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local stats = engine and engine:GetStats() or { total_players = 0, total_ep = 0, total_gp = 0 }
	local memberCount = GetNumGuildMembers and GetNumGuildMembers() or stats.total_players
	local activeAuctions = (_G.InfinityLootAuctions and _G.InfinityLootAuctions.GetActiveAuctions)
		and #_G.InfinityLootAuctions:GetActiveAuctions() or 0

	local heading = UI:CreateLabel(parent, "Guild & Raid Summary", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	-- 4 KPI stat boxes
	local cards = {
		{ title = "Guild Members", value = tostring(memberCount) },
		{ title = "Tracked Raiders", value = tostring(stats.total_players) },
		{ title = "Total Effort Points", value = tostring(math.floor(stats.total_ep or 0)) },
		{ title = "Active Loot Auctions", value = tostring(activeAuctions) },
	}
	for i, card in ipairs(cards) do
		local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(182, 76)
		box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 192, -52)
		UI:ApplyBackdrop(box, 0.12, 0.15, 0.21, 1, 0.24, 0.31, 0.42, 0.9)

		local lbl = UI:CreateLabel(box, card.title, 0.65, 0.72, 0.82, "GameFontNormalSmall")
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)

		local val = UI:CreateLabel(box, card.value, 0.22, 0.74, 0.97, "GameFontNormalLarge")
		val:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 14)
	end

	-- Quick Actions
	local quickLabel = UI:CreateLabel(parent, "Quick Officer Actions", 0.95, 0.97, 1.0, "GameFontNormal")
	quickLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -150)

	local openAwardBtn = UI:CreateButton(parent, "Award EP / GP", 150, 28, function()
		Dashboard:SwitchTab("dkp_management")
	end, true)
	openAwardBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -176)

	local openAuctionsBtn = UI:CreateButton(parent, "Open Auction UI", 150, 28, function()
		if _G.InfinityLootAuctionUI and _G.InfinityLootAuctionUI.CreateAuctionFrame then
			_G.InfinityLootAuctionUI:CreateAuctionFrame()
		end
	end)
	openAuctionsBtn:SetPoint("LEFT", openAwardBtn, "RIGHT", 10, 0)

	local openDkpBtn = UI:CreateButton(parent, "Open DKP Window", 150, 28, function()
		if _G.InfinityDKPUI and _G.InfinityDKPUI.Show then
			_G.InfinityDKPUI:Show()
		end
	end)
	openDkpBtn:SetPoint("LEFT", openAuctionsBtn, "RIGHT", 10, 0)

	-- HiveMind Network Connectivity & Data-Sync Health Panel
	local health = (_G.InfinityHive and _G.InfinityHive.GetNetworkHealth)
		and _G.InfinityHive:GetNetworkHealth()
		or { state = "OFFLINE", label = "Offline", shortLabel = "Offline", color = { 0.97, 0.44, 0.44 }, hex = "|cfff87171", score = 0, isInGuild = false, onlinePeers = 0, queuedMessages = 0, messagesSent = 0, messagesReceived = 0, syncFreshness = "Never", dbRevision = 1, dbItems = 0 }

	if self.frame and self.frame.healthBadge and self.frame.healthBadge.Refresh then
		self.frame.healthBadge:Refresh()
	end

	local hiveCard = UI:CreateCard(parent, 758, 128, "Guild HiveMind Network Connectivity & Data-Sync Health")
	hiveCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -222)

	local hc = health.color or { 0.29, 0.87, 0.50 }
	local healthBar = UI:CreateStatusBar(hiveCard, 734, 22, hc[1], hc[2], hc[3])
	healthBar:SetPoint("TOPLEFT", hiveCard, "TOPLEFT", 12, -32)
	healthBar:SetBarData(
		health.score or 0,
		string.format("%s%s|r  ·  Protocol: INFHIVE (%s)", health.hex, health.label, health.isInGuild and "Guild Connected" or "No Guild"),
		string.format("%d%% Health", health.score or 0),
		hc[1], hc[2], hc[3]
	)

	local metricsStr = string.format(
		"Online Hive Peers: |cff38bdf8%d|r   ·   Last Sync: |cffffffff%s|r   ·   Queue: %d   ·   Packets: %d tx / %d rx   ·   Hive DB: |cfffbbf24Rev v%d (%d items)|r",
		health.onlinePeers or 0,
		health.syncFreshness or "Never",
		health.queuedMessages or 0,
		health.messagesSent or 0,
		health.messagesReceived or 0,
		health.dbRevision or 1,
		health.dbItems or 0
	)
	local mLbl = UI:CreateLabel(hiveCard, metricsStr, 0.82, 0.88, 0.95)
	mLbl:SetPoint("TOPLEFT", hiveCard, "TOPLEFT", 12, -64)

	local forceSyncBtn = UI:CreateButton(hiveCard, "Force Guild Hive Sync", 160, 24, function()
		if _G.InfinityHive then _G.InfinityHive:RequestFullGuildSync() end
		if _G.InfinityHiveNetworkDB then _G.InfinityHiveNetworkDB:CheckForNetworkUpdates() end
		Dashboard:RefreshContent()
	end, true)
	forceSyncBtn:SetPoint("BOTTOMLEFT", hiveCard, "BOTTOMLEFT", 12, 12)

	local openHiveBtn = UI:CreateButton(hiveCard, "Open Hive Hub", 130, 24, function()
		if _G.InfinityMainFrame and _G.InfinityMainFrame.OpenToTab then
			_G.InfinityMainFrame:OpenToTab("Hive Live")
		end
	end)
	openHiveBtn:SetPoint("LEFT", forceSyncBtn, "RIGHT", 10, 0)
end

function Dashboard:ShowDKPManagement(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()

	local heading = UI:CreateLabel(parent, "Award Points & Guild Decay", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	-- Inline real Award Points Form (replaces old 'Coming soon' stub)
	local nameLbl = UI:CreateLabel(parent, "Player Name:")
	nameLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -54)
	local nameBox = UI:CreateInputBox(parent, 180, 24)
	nameBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -72)
	if UnitName then
		nameBox:SetText(UnitName("target") or UnitName("player") or "")
	end

	local amtLbl = UI:CreateLabel(parent, "Amount:")
	amtLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 214, -54)
	local amtBox = UI:CreateInputBox(parent, 100, 24)
	amtBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 214, -72)
	amtBox:SetText("50")

	local reasonLbl = UI:CreateLabel(parent, "Reason:")
	reasonLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 332, -54)
	local reasonBox = UI:CreateInputBox(parent, 230, 24)
	reasonBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 332, -72)
	reasonBox:SetText("Boss Kill Bonus")

	local statusText = UI:CreateLabel(parent, "", 0.29, 0.87, 0.50)
	statusText:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -148)

	local awardEpBtn = UI:CreateButton(parent, "Award EP", 110, 26, function()
		local player = strtrim(nameBox:GetText() or "")
		local amt = tonumber(amtBox:GetText()) or 0
		local reason = strtrim(reasonBox:GetText() or "Manual Award")
		if player == "" or amt <= 0 then
			statusText:SetTextColor(0.97, 0.44, 0.44, 1)
			statusText:SetText("Enter a valid player name and positive point amount.")
			return
		end
		if engine then
			if not engine:GetPlayer(player) then
				engine:AddPlayer(player, "UNKNOWN", 1)
			end
			engine:AwardEP(player, amt, reason)
			statusText:SetTextColor(0.29, 0.87, 0.50, 1)
			statusText:SetText(string.format("Awarded +%d EP to %s (%s)", amt, player, reason))
		end
	end, true)
	awardEpBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -108)

	local awardGpBtn = UI:CreateButton(parent, "Charge GP", 110, 26, function()
		local player = strtrim(nameBox:GetText() or "")
		local amt = tonumber(amtBox:GetText()) or 0
		local reason = strtrim(reasonBox:GetText() or "Loot Award")
		if player == "" or amt <= 0 then
			statusText:SetTextColor(0.97, 0.44, 0.44, 1)
			statusText:SetText("Enter a valid player name and positive GP amount.")
			return
		end
		if engine then
			if not engine:GetPlayer(player) then
				engine:AddPlayer(player, "UNKNOWN", 1)
			end
			engine:AwardGP(player, amt, reason, reason)
			statusText:SetTextColor(0.98, 0.75, 0.14, 1)
			statusText:SetText(string.format("Charged +%d GP to %s (%s)", amt, player, reason))
		end
	end)
	awardGpBtn:SetPoint("LEFT", awardEpBtn, "RIGHT", 10, 0)

	-- Decay Controls
	local decayHeading = UI:CreateLabel(parent, "Scheduled Decay", 0.96, 0.98, 1.0, "GameFontNormal")
	decayHeading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -196)

	local decayBox = UI:CreateInputBox(parent, 70, 24)
	decayBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -220)
	decayBox:SetText("10")

	local decayBtn = UI:CreateButton(parent, "Apply Decay %", 140, 26, function()
		local pct = tonumber(decayBox:GetText()) or 10
		if pct <= 0 or pct > 50 then
			statusText:SetTextColor(0.97, 0.44, 0.44, 1)
			statusText:SetText("Decay must be between 1% and 50%.")
			return
		end
		if engine and engine.ApplyEPDecay then
			engine:ApplyEPDecay(pct)
			statusText:SetTextColor(0.29, 0.87, 0.50, 1)
			statusText:SetText(string.format("Applied %d%% decay to all tracked raiders.", pct))
		end
	end)
	decayBtn:SetPoint("LEFT", decayBox, "RIGHT", 10, 0)
end

function Dashboard:ShowLootAudits(parent)
	local UI = EnsureUI()
	local heading = UI:CreateLabel(parent, "Recent Loot Auction History", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local history = (_G.InfinityLootAuctions and _G.InfinityLootAuctions.GetAuctionHistory)
		and _G.InfinityLootAuctions:GetAuctionHistory(12) or {}

	if #history == 0 then
		local empty = UI:CreateLabel(parent, "No closed auctions logged yet. Use /loot auction create to start an auction.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -54)
		return
	end

	local y = -52
	for idx, entry in ipairs(history) do
		local line = string.format(
			"%d. %s  |  Winner: %s  |  Price: %d  |  Mode: %s",
			idx,
			entry.itemName or "Unknown Item",
			entry.winner or "No Bids",
			entry.winningBid or 0,
			entry.biddingMode or "open"
		)
		local row = UI:CreateLabel(parent, line)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
		y = y - 24
	end
end

function Dashboard:ShowPlayerStatus(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local heading = UI:CreateLabel(parent, "Live Priority Rankings", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local ranked = engine and engine:GetRankedPlayers() or {}
	if #ranked == 0 then
		local empty = UI:CreateLabel(parent, "No players tracked yet. Award EP on the DKP tab to register raiders.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -54)
		return
	end

	local header = UI:CreateLabel(parent, string.format("%-4s %-22s %-10s %-10s %-10s", "#", "Raider", "EP", "GP", "Priority"), 0.65, 0.72, 0.82)
	header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -50)

	local y = -74
	for i, player in ipairs(ranked) do
		if i > 14 then break end
		local row = UI:CreateLabel(
			parent,
			string.format("%-4d %-22s %-10d %-10d %-10.2f", i, player.name, player.ep or 0, player.gp or 0, player.priority or 0)
		)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
		y = y - 22
	end
end

function Dashboard:ShowSettings(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local heading = UI:CreateLabel(parent, "Point System & UI Theme", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local sysLbl = UI:CreateLabel(parent, "Active Loot Priority Mode:", 0.75, 0.80, 0.88)
	sysLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -54)

	local systems = {
		{ id = "epgp", label = "EPGP" },
		{ id = "dkp", label = "DKP" },
		{ id = "sk", label = "Suicide Kings" },
		{ id = "zero", label = "Zero-Sum" },
	}
	for i, sys in ipairs(systems) do
		local btn = UI:CreateButton(parent, sys.label, 120, 26, function()
			if engine and engine.SetSystemType then
				engine:SetSystemType(sys.id)
				Dashboard:RefreshContent()
			end
		end, engine and engine.system_type == sys.id)
		btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 130, -80)
	end

	local themeLbl = UI:CreateLabel(parent, "Interface Theme:", 0.75, 0.80, 0.88)
	themeLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -130)

	local darkBtn = UI:CreateButton(parent, "Obsidian Dark", 130, 26, function()
		UI:LoadTheme("obsidian")
		Dashboard:RefreshContent()
	end, UI.theme ~= "light")
	darkBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -156)

	local lightBtn = UI:CreateButton(parent, "Light Slate", 130, 26, function()
		UI:LoadTheme("light")
		Dashboard:RefreshContent()
	end, UI.theme == "light")
	lightBtn:SetPoint("LEFT", darkBtn, "RIGHT", 10, 0)
end

function Dashboard:Toggle()
	if self.visible then
		self:Hide()
	else
		self:Show()
	end
end

function Dashboard:Show()
	if not self.frame then
		self:CreateFrame()
	end
	self.visible = true
	self.frame:Show()
	self:SwitchTab(self.current_tab)
end

function Dashboard:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self.visible = false
end

if InfinityCore.SlashCommand then
	InfinityCore.SlashCommand:Register("dashboard", function(args)
		if args == "show" then
			Dashboard:Show()
		elseif args == "hide" then
			Dashboard:Hide()
		else
			Dashboard:Toggle()
		end
	end, "Open Officer Dashboard")
end

return InfinityCore.OfficerDashboard
