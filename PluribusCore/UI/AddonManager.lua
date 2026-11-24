-- PluribusCore Addon Manager UI
-- Modern flat addon browser, search, enable/disable toggle, and quick window launcher

PluribusAddonManager = {
	addons = {},
	currentAddon = nil,
}

local QUICK_OPENERS = {
	PluribusCore                 = function() if _G.PluribusMainFrame then _G.PluribusMainFrame:Toggle() end end,
	PluribusAttendance           = function() if _G.PluribusAttendanceUI and _G.PluribusAttendanceUI.Toggle then _G.PluribusAttendanceUI:Toggle() end end,
	PluribusCalendar             = function() if _G.PluribusCalendarUI and _G.PluribusCalendarUI.Toggle then _G.PluribusCalendarUI:Toggle() end end,
	PluribusConsumables          = function() if _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Toggle then _G.PluribusConsumablesUI:Toggle() elseif _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Show then _G.PluribusConsumablesUI:Show() end end,
	PluribusDKP                  = function() if _G.PluribusDKPUI and _G.PluribusDKPUI.Toggle then _G.PluribusDKPUI:Toggle() elseif _G.PluribusDKPUI and _G.PluribusDKPUI.Show then _G.PluribusDKPUI:Show() end end,
	PluribusData                 = function() if _G.PluribusDataUI and _G.PluribusDataUI.Toggle then _G.PluribusDataUI:Toggle() elseif _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Market & DB") end end,
	PluribusDataCollector        = function() if _G.PluribusDataCollectorUI and _G.PluribusDataCollectorUI.Toggle then _G.PluribusDataCollectorUI:Toggle() elseif _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Market & DB") end end,
	PluribusDetails              = function() if _G.PluribusDetailsUI and _G.PluribusDetailsUI.Toggle then _G.PluribusDetailsUI:Toggle() end end,
	PluribusEncounter            = function() if _G.PluribusEncounterUI and _G.PluribusEncounterUI.Toggle then _G.PluribusEncounterUI:Toggle() end end,
	PluribusGather               = function() if _G.PluribusGatherUI and _G.PluribusGatherUI.Toggle then _G.PluribusGatherUI:Toggle() end end,
	PluribusGatherPath           = function() if _G.PluribusGatherPathUI and _G.PluribusGatherPathUI.Toggle then _G.PluribusGatherPathUI:Toggle() end end,
	PluribusGear                 = function() if _G.PluribusGearUI and _G.PluribusGearUI.Toggle then _G.PluribusGearUI:Toggle() end end,
	PluribusGearMgr              = function() if _G.PluribusGearMgrUI and _G.PluribusGearMgrUI.Toggle then _G.PluribusGearMgrUI:Toggle() elseif _G.PluribusGearUI and _G.PluribusGearUI.Toggle then _G.PluribusGearUI:Toggle() end end,
	PluribusGuide                = function() if _G.PluribusGuideUI and _G.PluribusGuideUI.Toggle then _G.PluribusGuideUI:Toggle() end end,
	PluribusGuild                = function() if _G.PluribusGuildUI and _G.PluribusGuildUI.Toggle then _G.PluribusGuildUI:Toggle() end end,
	PluribusHealer               = function() if _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then _G.PluribusHealerUI:Toggle() elseif _G.PluribusHealerFrames and _G.PluribusHealerFrames.ToggleRaidFrames then _G.PluribusHealerFrames:ToggleRaidFrames() end end,
	PluribusInventory            = function() if _G.PluribusInventoryUI and _G.PluribusInventoryUI.Toggle then _G.PluribusInventoryUI:Toggle() elseif _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer() end end,
	PluribusLoot                 = function() if _G.PluribusLootUI and _G.PluribusLootUI.Toggle then _G.PluribusLootUI:Toggle() elseif _G.PluribusLootAuctionUI and _G.PluribusLootAuctionUI.CreateAuctionFrame then _G.PluribusLootAuctionUI:CreateAuctionFrame() end end,
	PluribusLootHistory          = function() if _G.PluribusLootHistoryUI and _G.PluribusLootHistoryUI.Toggle then _G.PluribusLootHistoryUI:Toggle() elseif _G.PluribusLootUI and _G.PluribusLootUI.Toggle then _G.PluribusLootUI:Toggle() end end,
	PluribusNavigation           = function() if _G.PluribusNavigationUI and _G.PluribusNavigationUI.Toggle then _G.PluribusNavigationUI:Toggle() end end,
	PluribusPerformanceAnalytics = function() if _G.PluribusPerformanceUI and _G.PluribusPerformanceUI.Toggle then _G.PluribusPerformanceUI:Toggle() end end,
	PluribusProfiler             = function() if _G.PluribusProfilerUI and _G.PluribusProfilerUI.Toggle then _G.PluribusProfilerUI:Toggle() end end,
	PluribusQoL                  = function() if _G.PluribusQoLUI and _G.PluribusQoLUI.Toggle then _G.PluribusQoLUI:Toggle() end end,
	PluribusQuestie              = function() if _G.PluribusQuestieUI and _G.PluribusQuestieUI.Toggle then _G.PluribusQuestieUI:Toggle() end end,
	PluribusRaid                 = function() if _G.PluribusRaidUI and _G.PluribusRaidUI.Toggle then _G.PluribusRaidUI:Toggle() end end,
	PluribusRosterMgr            = function() if _G.PluribusRosterUI and _G.PluribusRosterUI.Toggle then _G.PluribusRosterUI:Toggle() elseif _G.PluribusOfficerDashboard then _G.PluribusOfficerDashboard:Toggle() end end,
	PluribusWorldBoss            = function() if _G.PluribusWorldBossUI and _G.PluribusWorldBossUI.Toggle then _G.PluribusWorldBossUI:Toggle() end end,
}

function PluribusAddonManager:Initialize()
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Addon Manager initialized", "AddonManager")
	end
end

function PluribusAddonManager:RegisterAddon(name, version, config)
	config = config or {}
	self.addons[name] = {
		name = name,
		version = version or config.version or "1.0.0",
		enabled = config.enabled ~= false,
		description = config.description or "Pluribus Suite module",
		author = config.author or "Pluribus",
		category = config.category or "General",
		settings = config.settings or {},
	}
end

function PluribusAddonManager:GetAddonInfo(name)
	return self.addons[name]
end

function PluribusAddonManager:GetAllAddons()
	local addonList = {}
	for _, info in pairs(self.addons) do
		table.insert(addonList, info)
	end
	table.sort(addonList, function(a, b) return a.name < b.name end)
	return addonList
end

function PluribusAddonManager:IsAddonEnabled(name)
	return self.addons[name] and self.addons[name].enabled or false
end

function PluribusAddonManager:SetAddonEnabled(name, enabled)
	if self.addons[name] then
		self.addons[name].enabled = enabled
		if PluribusStorageManager and PluribusStorageManager.SetAddonSetting then
			PluribusStorageManager:SetAddonSetting(name, "enabled", enabled)
		end
		if PluribusMessaging and PluribusMessaging.Publish then
			PluribusMessaging:Publish("PLURIBUS_ADDON_STATE_CHANGED", name, enabled)
		end
		return true
	end
	return false
end

function PluribusAddonManager:CreateManagerWindow()
	local mainFrame = PluribusUIFramework:CreateFrame(
		"PluribusAddonManagerWindow",
		UIParent,
		740,
		500,
		"Pluribus Suite — Addon Manager",
		"WoW Forever (16001)"
	)
	mainFrame:SetPoint("CENTER")

	-- Persistent HiveMind connectivity & data-sync status indicator in Addon Manager header
	if mainFrame.header and _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBadge then
		local badge = _G.PluribusHiveUI:CreateHealthBadge(mainFrame.header, function()
			if mainFrame:IsVisible() then
				PluribusAddonManager:RefreshAddonList(mainFrame)
			end
		end)
		if badge and mainFrame.closeBtn then
			badge:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", -8, 0)
			mainFrame.healthBadge = badge
		end
	end

	-- Search bar row
	local searchLabel = PluribusUIFramework:CreateLabel(mainFrame, "Filter Addons:")
	searchLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -50)

	local searchBox = PluribusUIFramework:CreateInputBox(mainFrame, 210, 24, function()
		PluribusAddonManager:RefreshAddonList(mainFrame)
	end)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
	mainFrame.searchBox = searchBox

	local refreshBtn = PluribusUIFramework:CreateButton(mainFrame, "Refresh", 86, 24, function()
		PluribusAddonManager:RefreshAddonList(mainFrame)
	end)
	refreshBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -46)

	local settingsBtn = PluribusUIFramework:CreateButton(mainFrame, "Settings", 86, 24, function()
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open()
		end
	end)
	settingsBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -8, 0)

	-- Left list scroll
	local listCard = PluribusUIFramework:CreateCard(mainFrame, 250, 405)
	listCard:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -82)

	local listScroll = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusAddonListScroll", 236, 392)
	listScroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)
	mainFrame.addonList = listScroll.content
	mainFrame.listScroll = listScroll

	-- Right details card
	local detailsFrame = PluribusUIFramework:CreateCard(mainFrame, 456, 405)
	detailsFrame:SetPoint("TOPLEFT", listCard, "TOPRIGHT", 10, 0)
	mainFrame.detailsFrame = detailsFrame

	self:RefreshAddonList(mainFrame)
	return mainFrame
end

function PluribusAddonManager:RefreshAddonList(mainFrame)
	if not mainFrame or not mainFrame.addonList then return end
	PluribusUIFramework:ClearContainer(mainFrame.addonList)

	local searchText = (mainFrame.searchBox and mainFrame.searchBox:GetText() or ""):lower()
	local y = -2
	local addons = self:GetAllAddons()
	local firstMatch = nil

	for idx, addonInfo in ipairs(addons) do
		local matches = searchText == ""
			or addonInfo.name:lower():find(searchText, 1, true)
			or (addonInfo.description or ""):lower():find(searchText, 1, true)
			or (addonInfo.category or ""):lower():find(searchText, 1, true)

		if matches then
			if not firstMatch then firstMatch = addonInfo end
			local row = PluribusUIFramework:CreateListRow(mainFrame.addonList, 210, 28, idx, function()
				PluribusAddonManager.currentAddon = addonInfo.name
				PluribusAddonManager:ShowAddonDetails(mainFrame, addonInfo)
			end)
			row:SetPoint("TOPLEFT", mainFrame.addonList, "TOPLEFT", 2, y)

			local nameLbl = PluribusUIFramework:CreateLabel(row, addonInfo.name)
			nameLbl:SetPoint("LEFT", row, "LEFT", 8, 0)

			local badge = addonInfo.enabled and "|cff4ade80ON|r" or "|cfff87171OFF|r"
			local statusLbl = PluribusUIFramework:CreateLabel(row, badge)
			statusLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)

			y = y - 30
		end
	end

	mainFrame.addonList:SetHeight(math.max(380, -y + 10))
	if firstMatch and (not self.currentAddon or not self.addons[self.currentAddon]) then
		self.currentAddon = firstMatch.name
	end
	if self.currentAddon and self.addons[self.currentAddon] then
		self:ShowAddonDetails(mainFrame, self.addons[self.currentAddon])
	end
end

function PluribusAddonManager:ShowAddonDetails(mainFrame, addonInfo)
	if not mainFrame or not mainFrame.detailsFrame or not addonInfo then return end
	PluribusUIFramework:ClearContainer(mainFrame.detailsFrame)

	local parent = mainFrame.detailsFrame
	local title = PluribusUIFramework:CreateLabel(parent, "|cff38bdf8" .. addonInfo.name .. "|r", nil, nil, nil, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local statusStr = addonInfo.enabled and "|cff4ade80ENABLED|r" or "|cfff87171DISABLED|r"
	local statusBadge = PluribusUIFramework:CreateLabel(parent, statusStr)
	statusBadge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -18)

	local meta = PluribusUIFramework:CreateLabel(
		parent,
		string.format("|cff94a3b8Version:|r %s   |cff94a3b8Category:|r %s   |cff94a3b8Author:|r %s",
			tostring(addonInfo.version), tostring(addonInfo.category), tostring(addonInfo.author))
	)
	meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

	local descCard = PluribusUIFramework:CreateCard(parent, 424, 110, "Overview")
	descCard:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -16)

	local descText = PluribusUIFramework:CreateLabel(descCard, addonInfo.description or "No description available.")
	descText:SetPoint("TOPLEFT", descCard, "TOPLEFT", 12, -30)
	descText:SetWidth(400)
	descText:SetWordWrap(true)

	local toggleBtn = PluribusUIFramework:CreateButton(
		parent,
		addonInfo.enabled and "Disable Module" or "Enable Module",
		130,
		28,
		function()
			PluribusAddonManager:SetAddonEnabled(addonInfo.name, not addonInfo.enabled)
			PluribusAddonManager:RefreshAddonList(mainFrame)
		end
	)
	toggleBtn:SetPoint("TOPLEFT", descCard, "BOTTOMLEFT", 0, -16)

	local opener = QUICK_OPENERS[addonInfo.name]
	if opener then
		local openBtn = PluribusUIFramework:CreateButton(parent, "Open Addon Window", 150, 28, function()
			pcall(opener)
		end, true)
		openBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 10, 0)
	end

	-- Live Guild HiveMind Network & Data-Sync Health Strip inside Addon Manager
	if _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBanner then
		local banner = _G.PluribusHiveUI:CreateHealthBanner(parent, 424, function()
			PluribusAddonManager:RefreshAddonList(mainFrame)
		end)
		if banner then
			banner:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
		end
	end
end

function PluribusAddonManager:Toggle()
	if not _G.PluribusAddonManagerWindow then
		_G.PluribusAddonManagerWindow = self:CreateManagerWindow()
		_G.PluribusAddonManagerWindow:Show()
		return
	end
	if _G.PluribusAddonManagerWindow:IsVisible() then
		_G.PluribusAddonManagerWindow:Hide()
	else
		self:RefreshAddonList(_G.PluribusAddonManagerWindow)
		_G.PluribusAddonManagerWindow:Show()
	end
end

_G.PluribusAddonManager = PluribusAddonManager
return PluribusAddonManager
