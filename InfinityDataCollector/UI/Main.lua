-- InfinityDataCollector UI - Statistics and Settings

InfinityDataCollectorUI = {
	mainFrame = nil,
	tabs = {},
	currentTab = "stats",
}

-- Initialize UI
function InfinityDataCollectorUI:Initialize()
	if self.mainFrame then
		return
	end
	
	-- Main frame
	local frame = CreateFrame("Frame", "InfinityDataCollectorFrame", UIParent, "BasicFrameTemplate")
	frame:SetSize(500, 400)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	frame:SetTitle("Infinity Data Collector")
	
	-- Close button already in BasicFrameTemplate
	
	-- Tab buttons
	local statsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	statsBtn:SetSize(80, 20)
	statsBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	statsBtn:SetText("Statistics")
	statsBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("stats")
	end)
	
	local settingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settingsBtn:SetSize(80, 20)
	settingsBtn:SetPoint("LEFT", statsBtn, "RIGHT", 5, 0)
	settingsBtn:SetText("Settings")
	settingsBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("settings")
	end)
	
	local networkBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	networkBtn:SetSize(80, 20)
	networkBtn:SetPoint("LEFT", settingsBtn, "RIGHT", 5, 0)
	networkBtn:SetText("Network")
	networkBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("network")
	end)
	
	-- Statistics tab
	local statsTab = CreateFrame("Frame", nil, frame)
	statsTab:SetSize(480, 320)
	statsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	
	local statsText = statsTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	statsText:SetPoint("TOPLEFT", statsTab, "TOPLEFT", 0, 0)
	statsText:SetText("Data Gathering Statistics\n\n")
	
	self.tabs["stats"] = {
		frame = statsTab,
		text = statsText,
		refreshFunc = function()
			InfinityDataCollectorUI:RefreshStatistics()
		end
	}
	
	-- Settings tab
	local settingsTab = CreateFrame("Frame", nil, frame)
	settingsTab:SetSize(480, 320)
	settingsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	settingsTab:Hide()
	
	-- Gathering toggle
	local gatheringToggle = CreateFrame("CheckButton", nil, settingsTab, "UICheckButtonTemplate")
	gatheringToggle:SetSize(20, 20)
	gatheringToggle:SetPoint("TOPLEFT", settingsTab, "TOPLEFT", 0, -10)
	gatheringToggle:SetChecked(InfinityDataCollectorCore:IsGatheringEnabled())
	gatheringToggle:SetScript("OnClick", function(self)
		InfinityDataCollectorCore:SetGatheringEnabled(self:GetChecked())
	end)
	
	local gatheringLabel = settingsTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	gatheringLabel:SetPoint("LEFT", gatheringToggle, "RIGHT", 5, 0)
	gatheringLabel:SetText("Enable Data Gathering")
	
	-- Sharing toggle
	local sharingToggle = CreateFrame("CheckButton", nil, settingsTab, "UICheckButtonTemplate")
	sharingToggle:SetSize(20, 20)
	sharingToggle:SetPoint("TOPLEFT", gatheringToggle, "BOTTOMLEFT", 0, -20)
	sharingToggle:SetChecked(InfinityDataCollectorNetwork.shareEnabled)
	sharingToggle:SetScript("OnClick", function(self)
		InfinityDataCollectorNetwork:SetSharingEnabled(self:GetChecked())
	end)
	
	local sharingLabel = settingsTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sharingLabel:SetPoint("LEFT", sharingToggle, "RIGHT", 5, 0)
	sharingLabel:SetText("Enable Network Sharing")
	
	-- Sanitization level
	local sanitizationLabel = settingsTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sanitizationLabel:SetPoint("TOPLEFT", sharingToggle, "BOTTOMLEFT", 0, -20)
	sanitizationLabel:SetText("Sanitization Level:")
	
	local sanitizationDropdown = CreateFrame("Frame", "InfinityDataCollectorSanitization", settingsTab, "UIDropDownMenuTemplate")
	sanitizationDropdown:SetPoint("TOPLEFT", sanitizationLabel, "BOTTOMLEFT", 0, -5)
	
	local sanitizationOptions = {
		{text = "None (Full Data)", value = "none"},
		{text = "Guild (Guild Members Only)", value = "guild"},
		{text = "Anonymous (Basic Data)", value = "anonymous"},
	}
	
	sanitizationDropdown:SetScript("OnShow", function()
		UIDropDownMenu_Initialize(sanitizationDropdown, function()
			for _, option in ipairs(sanitizationOptions) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.text
				info.value = option.value
				info.checked = option.value == InfinityDataCollectorPrivacy:GetSanitizationLevel()
				info.func = function()
					InfinityDataCollectorPrivacy:SetSanitizationLevel(option.value)
					UIDropDownMenu_SetSelectedValue(sanitizationDropdown, option.value)
				end
				UIDropDownMenu_AddButton(info, nil)
			end
		end)
	end)
	
	self.tabs["settings"] = {
		frame = settingsTab,
		gatheringToggle = gatheringToggle,
		sharingToggle = sharingToggle,
		sanitizationDropdown = sanitizationDropdown,
	}
	
	-- Network tab
	local networkTab = CreateFrame("Frame", nil, frame)
	networkTab:SetSize(480, 320)
	networkTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	networkTab:Hide()
	
	local networkText = networkTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	networkText:SetPoint("TOPLEFT", networkTab, "TOPLEFT", 0, 0)
	networkText:SetText("Network Status\n\n")
	
	self.tabs["network"] = {
		frame = networkTab,
		text = networkText,
		refreshFunc = function()
			InfinityDataCollectorUI:RefreshNetworkStatus()
		end
	}
	
	self.mainFrame = frame
	
	-- Refresh initial tab
	self:ShowTab("stats")
	
	return frame
end

-- Show a specific tab
function InfinityDataCollectorUI:ShowTab(tabName)
	if not self.tabs[tabName] then
		return
	end
	
	-- Hide all tabs
	for name, tabData in pairs(self.tabs) do
		if tabData.frame then
			tabData.frame:Hide()
		end
	end
	
	-- Show selected tab
	self.tabs[tabName].frame:Show()
	self.currentTab = tabName
	
	-- Refresh if function exists
	if self.tabs[tabName].refreshFunc then
		self.tabs[tabName].refreshFunc()
	end
end

-- Refresh statistics display
function InfinityDataCollectorUI:RefreshStatistics()
	if not self.tabs["stats"] or not self.tabs["stats"].text then
		return
	end
	
	local stats = InfinityDataCollectorCore:GetStatistics()
	local gatheringStats = InfinityDataCollectorHooks:GetGatheringStats()
	local networkStats = InfinityDataCollectorNetwork:GetNetworkStats()
	
	local text = string.format(
		"Data Gathering Statistics\n\n" ..
		"Collected Data:\n" ..
		"  Quests: %d\n" ..
		"  Mobs: %d\n" ..
		"  Drops: %d\n" ..
		"  Nodes: %d\n" ..
		"  NPCs: %d\n\n" ..
		"Last Updates:\n" ..
		"  Quests: %s\n" ..
		"  Mobs: %s\n" ..
		"  Nodes: %s\n\n" ..
		"Network:\n" ..
		"  Connected Peers: %d\n" ..
		"  Pending Requests: %d\n" ..
		"  Sharing: %s\n",
		stats.questCount or 0,
		stats.mobCount or 0,
		stats.dropCount or 0,
		stats.nodeCount or 0,
		stats.npcCount or 0,
		self:FormatTime(stats.lastQuestUpdate),
		self:FormatTime(stats.lastMobUpdate),
		self:FormatTime(stats.lastNodeUpdate),
		networkStats.peerCount,
		networkStats.pendingRequests,
		networkStats.shareEnabled and "Enabled" or "Disabled"
	)
	
	self.tabs["stats"].text:SetText(text)
end

-- Refresh network status display
function InfinityDataCollectorUI:RefreshNetworkStatus()
	if not self.tabs["network"] or not self.tabs["network"].text then
		return
	end
	
	local networkStats = InfinityDataCollectorNetwork:GetNetworkStats()
	local peers = InfinityDataCollectorNetwork:GetPeers()
	
	local peerList = "Connected Peers:\n"
	for i, peer in ipairs(peers) do
		peerList = peerList .. string.format("  %d. %s (%s)\n", i, peer.name, peer.realm)
	end
	
	local text = string.format(
		"Network Status\n\n" ..
		"Total Connected: %d\n" ..
		"Sharing Enabled: %s\n" ..
		"Share Frequency: %d seconds\n" ..
		"Last Share: %s\n" ..
		"Pending Requests: %d\n\n" ..
		"%s",
		networkStats.peerCount,
		networkStats.shareEnabled and "Yes" or "No",
		networkStats.shareFrequency,
		self:FormatTime(networkStats.lastShare),
		networkStats.pendingRequests,
		peerList
	)
	
	self.tabs["network"].text:SetText(text)
end

-- Format timestamp for display
function InfinityDataCollectorUI:FormatTime(timestamp)
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

-- Toggle UI visibility
function InfinityDataCollectorUI:Toggle()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:SetShown(not self.mainFrame:IsShown())
end

-- Show UI
function InfinityDataCollectorUI:Show()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:Show()
end

-- Hide UI
function InfinityDataCollectorUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end
