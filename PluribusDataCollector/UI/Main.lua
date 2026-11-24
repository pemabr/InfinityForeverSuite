-- PluribusDataCollector UI - Statistics, Optional Data Sources, Settings & Network
-- Modern Flat PluribusUIFramework design (100% Warcraft Forever 1.60.1 compatible)

PluribusDataCollectorUI = {
	mainFrame = nil,
	tabs = {},
	currentTab = "stats",
}

function PluribusDataCollectorUI:Initialize()
	if self.mainFrame then
		return self.mainFrame
	end

	local frame = PluribusUIFramework:CreateFrame(
		"PluribusDataCollectorFrame",
		UIParent,
		540,
		430,
		"Pluribus Data Collector",
		"Standalone Gathering & Optional External DB Sources"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	local tabBar = PluribusUIFramework:CreateTabBar(frame, {
		{ name = "Statistics", key = "stats" },
		{ name = "Data Sources", key = "sources" },
		{ name = "Settings", key = "settings" },
		{ name = "Network", key = "network" },
	}, function(tabKey)
		PluribusDataCollectorUI:ShowTab(tabKey)
	end, 516)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	local bodyCard = PluribusUIFramework:CreateCard(frame, 516, 336)
	bodyCard:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	-- Statistics tab
	local statsTab = CreateFrame("Frame", nil, bodyCard)
	statsTab:SetAllPoints(bodyCard)
	local statsText = PluribusUIFramework:CreateLabel(statsTab, "Loading statistics...")
	statsText:SetPoint("TOPLEFT", statsTab, "TOPLEFT", 14, -14)
	statsText:SetWidth(488)
	statsText:SetJustifyH("LEFT")
	statsText:SetWordWrap(true)

	self.tabs["stats"] = {
		frame = statsTab,
		text = statsText,
		refreshFunc = function()
			PluribusDataCollectorUI:RefreshStatistics()
		end,
	}

	-- Data Sources tab (Native + optional QuestieDB, WoWHeadDB, GathererDB)
	local sourcesTab = CreateFrame("Frame", nil, bodyCard)
	sourcesTab:SetAllPoints(bodyCard)
	sourcesTab:Hide()

	local sourcesHeader = PluribusUIFramework:CreateLabel(
		sourcesTab,
		"|cff94a3b8Native live data runs standalone. Optional databases (QuestieDB, WoWHeadDB, GathererDB) activate automatically when installed.|r"
	)
	sourcesHeader:SetPoint("TOPLEFT", sourcesTab, "TOPLEFT", 14, -12)
	sourcesHeader:SetWidth(488)
	sourcesHeader:SetJustifyH("LEFT")
	sourcesHeader:SetWordWrap(true)

	local sourcesList = CreateFrame("Frame", nil, sourcesTab)
	sourcesList:SetPoint("TOPLEFT", sourcesHeader, "BOTTOMLEFT", 0, -10)
	sourcesList:SetSize(488, 210)

	local syncBtn = PluribusUIFramework:CreateButton(sourcesTab, "Sync Active Sources", 160, 26, function()
		local results = PluribusDataCollectorDBIntegration:SyncAll()
		local count = 0
		for _, r in ipairs(results) do
			if r.success then count = count + 1 end
		end
		PluribusDataCollectorUI:RefreshDataSources()
		PluribusDataCollectorUI:RefreshStatistics()
		PluribusUIFramework:ShowNotification("Synced " .. count .. " active data source(s).", 2)
	end, true)
	syncBtn:SetPoint("BOTTOMLEFT", sourcesTab, "BOTTOMLEFT", 14, 14)

	local rescanBtn = PluribusUIFramework:CreateButton(sourcesTab, "Re-Detect Optional DBs", 170, 26, function()
		PluribusDataCollectorDBIntegration:RefreshAvailability()
		PluribusDataCollectorUI:RefreshDataSources()
		PluribusUIFramework:ShowNotification("Re-scanned optional databases.", 2)
	end, false)
	rescanBtn:SetPoint("LEFT", syncBtn, "RIGHT", 10, 0)

	self.tabs["sources"] = {
		frame = sourcesTab,
		list = sourcesList,
		refreshFunc = function()
			PluribusDataCollectorUI:RefreshDataSources()
		end,
	}

	-- Settings tab
	local settingsTab = CreateFrame("Frame", nil, bodyCard)
	settingsTab:SetAllPoints(bodyCard)
	settingsTab:Hide()

	local gatheringToggle = PluribusUIFramework:CreateCheckbox(
		settingsTab,
		"Enable Autonomous Live Data Gathering",
		PluribusDataCollectorCore:IsGatheringEnabled(),
		function(checked)
			PluribusDataCollectorCore:SetGatheringEnabled(checked)
		end
	)
	gatheringToggle:SetPoint("TOPLEFT", settingsTab, "TOPLEFT", 14, -18)

	local sharingToggle = PluribusUIFramework:CreateCheckbox(
		settingsTab,
		"Enable Guild/Peer Network Sharing",
		PluribusDataCollectorNetwork.shareEnabled,
		function(checked)
			PluribusDataCollectorNetwork:SetSharingEnabled(checked)
		end
	)
	sharingToggle:SetPoint("TOPLEFT", gatheringToggle, "BOTTOMLEFT", 0, -14)

	local privacyTitle = PluribusUIFramework:CreateLabel(settingsTab, "|cfffbbf24Privacy Sanitization Level:|r")
	privacyTitle:SetPoint("TOPLEFT", sharingToggle, "BOTTOMLEFT", 0, -20)

	local levels = {
		{ label = "None (Full)", value = "none" },
		{ label = "Guild Only", value = "guild" },
		{ label = "Anonymous", value = "anonymous" },
	}
	local prevBtn = nil
	local privacyButtons = {}
	for _, opt in ipairs(levels) do
		local btn = PluribusUIFramework:CreateButton(settingsTab, opt.label, 120, 26, function()
			PluribusDataCollectorPrivacy:SetSanitizationLevel(opt.value)
			PluribusDataCollectorUI:RefreshSettings()
			PluribusUIFramework:ShowNotification("Privacy level set to: " .. opt.label, 2)
		end, false)
		if prevBtn then
			btn:SetPoint("LEFT", prevBtn, "RIGHT", 8, 0)
		else
			btn:SetPoint("TOPLEFT", privacyTitle, "BOTTOMLEFT", 0, -10)
		end
		btn._optValue = opt.value
		table.insert(privacyButtons, btn)
		prevBtn = btn
	end

	local privacyStatus = PluribusUIFramework:CreateLabel(settingsTab, "")
	privacyStatus:SetPoint("TOPLEFT", privacyTitle, "BOTTOMLEFT", 0, -46)

	self.tabs["settings"] = {
		frame = settingsTab,
		gatheringToggle = gatheringToggle,
		sharingToggle = sharingToggle,
		privacyButtons = privacyButtons,
		privacyStatus = privacyStatus,
		refreshFunc = function()
			PluribusDataCollectorUI:RefreshSettings()
		end,
	}

	-- Network tab
	local networkTab = CreateFrame("Frame", nil, bodyCard)
	networkTab:SetAllPoints(bodyCard)
	networkTab:Hide()

	local networkText = PluribusUIFramework:CreateLabel(networkTab, "Loading network status...")
	networkText:SetPoint("TOPLEFT", networkTab, "TOPLEFT", 14, -14)
	networkText:SetWidth(488)
	networkText:SetJustifyH("LEFT")
	networkText:SetWordWrap(true)

	self.tabs["network"] = {
		frame = networkTab,
		text = networkText,
		refreshFunc = function()
			PluribusDataCollectorUI:RefreshNetworkStatus()
		end,
	}

	frame:Hide()
	self.mainFrame = frame
	tabBar:SelectTab("stats")
	return frame
end

function PluribusDataCollectorUI:ShowTab(tabName)
	if not self.tabs[tabName] then
		return
	end
	for _, tabData in pairs(self.tabs) do
		if tabData.frame then
			tabData.frame:Hide()
		end
	end
	self.tabs[tabName].frame:Show()
	self.currentTab = tabName
	if self.tabs[tabName].refreshFunc then
		self.tabs[tabName].refreshFunc()
	end
end

function PluribusDataCollectorUI:RefreshDataSources()
	local tab = self.tabs["sources"]
	if not tab or not tab.list then return end
	PluribusUIFramework:ClearContainer(tab.list)

	local statuses = PluribusDataCollectorDBIntegration:GetAllIntegrationStatuses()
	local y = 0
	for idx, info in ipairs(statuses) do
		local row = PluribusUIFramework:CreateListRow(tab.list, 488, 38, idx)
		row:SetPoint("TOPLEFT", tab.list, "TOPLEFT", 0, y)

		local stateBadge
		if info.name == "native" then
			stateBadge = "|cff4ade80ACTIVE (STANDALONE)|r"
		elseif info.available and info.enabled then
			stateBadge = "|cff4ade80INSTALLED & ACTIVE|r"
		elseif info.available and not info.enabled then
			stateBadge = "|cfffbbf24INSTALLED (PAUSED)|r"
		else
			stateBadge = "|cff94a3b8OPTIONAL · NOT INSTALLED|r"
		end

		local title = PluribusUIFramework:CreateLabel(row, "|cffffffff" .. tostring(info.source or info.name) .. "|r")
		title:SetPoint("LEFT", row, "LEFT", 10, 6)

		local sub = PluribusUIFramework:CreateLabel(row, "|cff94a3b8Last sync: " .. self:FormatTime(info.lastSync) .. "|r")
		sub:SetPoint("LEFT", row, "LEFT", 10, -8)

		local badge = PluribusUIFramework:CreateLabel(row, stateBadge)
		badge:SetPoint("RIGHT", row, "RIGHT", info.available and info.name ~= "native" and -92 or -10, 0)

		if info.available and info.name ~= "native" then
			local toggleBtn = PluribusUIFramework:CreateButton(row, info.enabled and "Disable" or "Enable", 74, 22, function()
				PluribusDataCollectorDBIntegration:SetIntegrationEnabled(info.name, not info.enabled)
				PluribusDataCollectorUI:RefreshDataSources()
			end, not info.enabled)
			toggleBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		end

		y = y - 42
	end
end

function PluribusDataCollectorUI:RefreshSettings()
	local tab = self.tabs["settings"]
	if not tab then return end
	if tab.privacyStatus then
		tab.privacyStatus:SetText("|cff94a3b8Active Privacy Level: |cff38bdf8" .. tostring(PluribusDataCollectorPrivacy:GetSanitizationLevel()) .. "|r")
	end
end

function PluribusDataCollectorUI:RefreshStatistics()
	if not self.tabs["stats"] or not self.tabs["stats"].text then
		return
	end

	local stats = PluribusDataCollectorCore:GetStatistics()
	local networkStats = PluribusDataCollectorNetwork:GetNetworkStats()
	local sources = PluribusDataCollectorDBIntegration:GetAllIntegrationStatuses()
	local activeSources = {}
	for _, s in ipairs(sources) do
		if s.available and s.enabled then
			table.insert(activeSources, s.source or s.name)
		end
	end

	local text = string.format(
		"|cfffbbf24Collected Local Data|r\n" ..
		"  Quests: %d   ·   Mobs: %d   ·   Drops: %d\n" ..
		"  Nodes: %d   ·   NPCs: %d\n\n" ..
		"|cfffbbf24Last Updates|r\n" ..
		"  Quests: %s   ·   Mobs: %s   ·   Nodes: %s\n\n" ..
		"|cfffbbf24Active Data Sources|r\n" ..
		"  %s\n\n" ..
		"|cfffbbf24Peer Network|r\n" ..
		"  Connected Peers: %d   ·   Pending Requests: %d   ·   Sharing: %s",
		stats.questCount or 0,
		stats.mobCount or 0,
		stats.dropCount or 0,
		stats.nodeCount or 0,
		stats.npcCount or 0,
		self:FormatTime(stats.lastQuestUpdate),
		self:FormatTime(stats.lastMobUpdate),
		self:FormatTime(stats.lastNodeUpdate),
		#activeSources > 0 and table.concat(activeSources, ", ") or "Native WoW Live Data",
		networkStats.peerCount or 0,
		networkStats.pendingRequests or 0,
		networkStats.shareEnabled and "Enabled" or "Disabled"
	)

	self.tabs["stats"].text:SetText(text)
end

function PluribusDataCollectorUI:RefreshNetworkStatus()
	if not self.tabs["network"] or not self.tabs["network"].text then
		return
	end

	local networkStats = PluribusDataCollectorNetwork:GetNetworkStats()
	local peers = PluribusDataCollectorNetwork:GetPeers()

	local peerList = "Connected Peers:\n"
	if #peers == 0 then
		peerList = peerList .. "  (None connected yet)"
	else
		for i, peer in ipairs(peers) do
			peerList = peerList .. string.format("  %d. %s (%s)\n", i, peer.name, peer.realm)
		end
	end

	local text = string.format(
		"|cfffbbf24Network Status|r\n\n" ..
		"Total Connected: %d\n" ..
		"Sharing Enabled: %s\n" ..
		"Share Frequency: %d seconds\n" ..
		"Last Share: %s\n" ..
		"Pending Requests: %d\n\n" ..
		"%s",
		networkStats.peerCount or 0,
		networkStats.shareEnabled and "Yes" or "No",
		networkStats.shareFrequency or 0,
		self:FormatTime(networkStats.lastShare),
		networkStats.pendingRequests or 0,
		peerList
	)

	self.tabs["network"].text:SetText(text)
end

function PluribusDataCollectorUI:FormatTime(timestamp)
	if not timestamp or timestamp == 0 then
		return "Never"
	end

	local secondsAgo = time() - timestamp
	if secondsAgo < 60 then
		return "Just now"
	elseif secondsAgo < 3600 then
		return string.format("%d min ago", math.floor(secondsAgo / 60))
	elseif secondsAgo < 86400 then
		return string.format("%d hours ago", math.floor(secondsAgo / 3600))
	else
		return string.format("%d days ago", math.floor(secondsAgo / 86400))
	end
end

function PluribusDataCollectorUI:Toggle()
	if not self.mainFrame then
		self:Initialize()
	end
	self.mainFrame:SetShown(not self.mainFrame:IsShown())
	if self.mainFrame:IsShown() then
		self:ShowTab(self.currentTab or "stats")
	end
end

function PluribusDataCollectorUI:Show()
	if not self.mainFrame then
		self:Initialize()
	end
	self.mainFrame:Show()
	self:ShowTab(self.currentTab or "stats")
end

function PluribusDataCollectorUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end
