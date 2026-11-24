-- InfinityCore Addon Manager UI
-- Modern flat addon browser, search, enable/disable toggle, and quick window launcher

InfinityAddonManager = {
	addons = {},
	currentAddon = nil,
}

local QUICK_OPENERS = {
	InfinityCore = function() if _G.InfinityMainFrame then _G.InfinityMainFrame:Toggle() end end,
	InfinityDKP = function() if _G.InfinityDKPUI then _G.InfinityDKPUI:Toggle() end end,
	InfinityLoot = function() if _G.InfinityLootUI then _G.InfinityLootUI:Toggle() end end,
	InfinityGuild = function() if _G.InfinityGuildUI then _G.InfinityGuildUI:Toggle() end end,
	InfinityRaid = function() if _G.InfinityRaidUI then _G.InfinityRaidUI:Toggle() end end,
	InfinityHealer = function() if _G.InfinityHealerUI then _G.InfinityHealerUI:Toggle() end end,
	InfinityDetails = function() if _G.InfinityDetailsUI then _G.InfinityDetailsUI:Toggle() end end,
	InfinityEncounter = function() if _G.InfinityEncounterUI then _G.InfinityEncounterUI:Toggle() end end,
	InfinityAttendance = function() if _G.InfinityAttendanceUI then _G.InfinityAttendanceUI:Toggle() end end,
	InfinityCalendar = function() if _G.InfinityCalendarUI then _G.InfinityCalendarUI:Toggle() end end,
	InfinityWorldBoss = function() if _G.InfinityWorldBossUI then _G.InfinityWorldBossUI:Toggle() end end,
	InfinityQuestie = function() if _G.InfinityQuestieUI then _G.InfinityQuestieUI:Toggle() end end,
	InfinityGather = function() if _G.InfinityGatherUI then _G.InfinityGatherUI:Toggle() end end,
	InfinityGatherPath = function() if _G.InfinityGatherPathUI then _G.InfinityGatherPathUI:Toggle() end end,
	InfinityGear = function() if _G.InfinityGearUI then _G.InfinityGearUI:Toggle() end end,
	InfinityInventory = function() if _G.InfinityInventoryUI then _G.InfinityInventoryUI:Toggle() end end,
	InfinityNavigation = function() if _G.InfinityNavigationUI then _G.InfinityNavigationUI:Toggle() end end,
	InfinityGuide = function() if _G.InfinityGuideUI then _G.InfinityGuideUI:Toggle() end end,
	InfinityQoL = function() if _G.InfinityQoLUI then _G.InfinityQoLUI:Toggle() end end,
	InfinityProfiler = function() if _G.InfinityProfilerUI then _G.InfinityProfilerUI:Toggle() end end,
	InfinityPerformanceAnalytics = function() if _G.InfinityPerformanceUI then _G.InfinityPerformanceUI:Toggle() end end,
	InfinityData = function() if _G.InfinityDataUI then _G.InfinityDataUI:Toggle() end end,
	InfinityDataCollector = function() if _G.InfinityDataCollectorUI then _G.InfinityDataCollectorUI:Toggle() end end,
}

function InfinityAddonManager:Initialize()
	if InfinityUtils and InfinityUtils.Info then
		InfinityUtils:Info("Addon Manager initialized", "AddonManager")
	end
end

function InfinityAddonManager:RegisterAddon(name, version, config)
	config = config or {}
	self.addons[name] = {
		name = name,
		version = version or config.version or "1.0.0",
		enabled = config.enabled ~= false,
		description = config.description or "Infinity Forever Suite module",
		author = config.author or "Infinity Forever",
		category = config.category or "General",
		settings = config.settings or {},
	}
end

function InfinityAddonManager:GetAddonInfo(name)
	return self.addons[name]
end

function InfinityAddonManager:GetAllAddons()
	local addonList = {}
	for _, info in pairs(self.addons) do
		table.insert(addonList, info)
	end
	table.sort(addonList, function(a, b) return a.name < b.name end)
	return addonList
end

function InfinityAddonManager:IsAddonEnabled(name)
	return self.addons[name] and self.addons[name].enabled or false
end

function InfinityAddonManager:SetAddonEnabled(name, enabled)
	if self.addons[name] then
		self.addons[name].enabled = enabled
		if InfinityStorageManager and InfinityStorageManager.SetAddonSetting then
			InfinityStorageManager:SetAddonSetting(name, "enabled", enabled)
		end
		if InfinityMessaging and InfinityMessaging.Publish then
			InfinityMessaging:Publish("INFINITY_ADDON_STATE_CHANGED", name, enabled)
		end
		return true
	end
	return false
end

function InfinityAddonManager:CreateManagerWindow()
	local mainFrame = InfinityUIFramework:CreateFrame(
		"InfinityAddonManagerWindow",
		UIParent,
		740,
		500,
		"Infinity Suite — Addon Manager",
		"WoW Forever (16001)"
	)
	mainFrame:SetPoint("CENTER")

	-- Persistent HiveMind connectivity & data-sync status indicator in Addon Manager header
	if mainFrame.header and _G.InfinityHiveUI and _G.InfinityHiveUI.CreateHealthBadge then
		local badge = _G.InfinityHiveUI:CreateHealthBadge(mainFrame.header, function()
			if mainFrame:IsVisible() then
				InfinityAddonManager:RefreshAddonList(mainFrame)
			end
		end)
		if badge and mainFrame.closeBtn then
			badge:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", -8, 0)
			mainFrame.healthBadge = badge
		end
	end

	-- Search bar row
	local searchLabel = InfinityUIFramework:CreateLabel(mainFrame, "Filter Addons:")
	searchLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -50)

	local searchBox = InfinityUIFramework:CreateInputBox(mainFrame, 210, 24, function()
		InfinityAddonManager:RefreshAddonList(mainFrame)
	end)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
	mainFrame.searchBox = searchBox

	local refreshBtn = InfinityUIFramework:CreateButton(mainFrame, "Refresh", 86, 24, function()
		InfinityAddonManager:RefreshAddonList(mainFrame)
	end)
	refreshBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -46)

	-- Left list scroll
	local listCard = InfinityUIFramework:CreateCard(mainFrame, 250, 405)
	listCard:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -82)

	local listScroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityAddonListScroll", 236, 392)
	listScroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)
	mainFrame.addonList = listScroll.content
	mainFrame.listScroll = listScroll

	-- Right details card
	local detailsFrame = InfinityUIFramework:CreateCard(mainFrame, 456, 405)
	detailsFrame:SetPoint("TOPLEFT", listCard, "TOPRIGHT", 10, 0)
	mainFrame.detailsFrame = detailsFrame

	self:RefreshAddonList(mainFrame)
	return mainFrame
end

function InfinityAddonManager:RefreshAddonList(mainFrame)
	if not mainFrame or not mainFrame.addonList then return end
	InfinityUIFramework:ClearContainer(mainFrame.addonList)

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
			local row = InfinityUIFramework:CreateListRow(mainFrame.addonList, 210, 28, idx, function()
				InfinityAddonManager.currentAddon = addonInfo.name
				InfinityAddonManager:ShowAddonDetails(mainFrame, addonInfo)
			end)
			row:SetPoint("TOPLEFT", mainFrame.addonList, "TOPLEFT", 2, y)

			local nameLbl = InfinityUIFramework:CreateLabel(row, addonInfo.name)
			nameLbl:SetPoint("LEFT", row, "LEFT", 8, 0)

			local badge = addonInfo.enabled and "|cff4ade80ON|r" or "|cfff87171OFF|r"
			local statusLbl = InfinityUIFramework:CreateLabel(row, badge)
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

function InfinityAddonManager:ShowAddonDetails(mainFrame, addonInfo)
	if not mainFrame or not mainFrame.detailsFrame or not addonInfo then return end
	InfinityUIFramework:ClearContainer(mainFrame.detailsFrame)

	local parent = mainFrame.detailsFrame
	local title = InfinityUIFramework:CreateLabel(parent, "|cff38bdf8" .. addonInfo.name .. "|r", nil, nil, nil, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local statusStr = addonInfo.enabled and "|cff4ade80ENABLED|r" or "|cfff87171DISABLED|r"
	local statusBadge = InfinityUIFramework:CreateLabel(parent, statusStr)
	statusBadge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -18)

	local meta = InfinityUIFramework:CreateLabel(
		parent,
		string.format("|cff94a3b8Version:|r %s   |cff94a3b8Category:|r %s   |cff94a3b8Author:|r %s",
			tostring(addonInfo.version), tostring(addonInfo.category), tostring(addonInfo.author))
	)
	meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

	local descCard = InfinityUIFramework:CreateCard(parent, 424, 110, "Overview")
	descCard:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -16)

	local descText = InfinityUIFramework:CreateLabel(descCard, addonInfo.description or "No description available.")
	descText:SetPoint("TOPLEFT", descCard, "TOPLEFT", 12, -30)
	descText:SetWidth(400)
	descText:SetWordWrap(true)

	local toggleBtn = InfinityUIFramework:CreateButton(
		parent,
		addonInfo.enabled and "Disable Module" or "Enable Module",
		130,
		28,
		function()
			InfinityAddonManager:SetAddonEnabled(addonInfo.name, not addonInfo.enabled)
			InfinityAddonManager:RefreshAddonList(mainFrame)
		end
	)
	toggleBtn:SetPoint("TOPLEFT", descCard, "BOTTOMLEFT", 0, -16)

	local opener = QUICK_OPENERS[addonInfo.name]
	if opener then
		local openBtn = InfinityUIFramework:CreateButton(parent, "Open Addon Window", 150, 28, function()
			pcall(opener)
		end, true)
		openBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 10, 0)
	end

	-- Live Guild HiveMind Network & Data-Sync Health Strip inside Addon Manager
	if _G.InfinityHiveUI and _G.InfinityHiveUI.CreateHealthBanner then
		local banner = _G.InfinityHiveUI:CreateHealthBanner(parent, 424, function()
			InfinityAddonManager:RefreshAddonList(mainFrame)
		end)
		if banner then
			banner:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
		end
	end
end

function InfinityAddonManager:Toggle()
	if not _G.InfinityAddonManagerWindow then
		_G.InfinityAddonManagerWindow = self:CreateManagerWindow()
		_G.InfinityAddonManagerWindow:Show()
		return
	end
	if _G.InfinityAddonManagerWindow:IsVisible() then
		_G.InfinityAddonManagerWindow:Hide()
	else
		self:RefreshAddonList(_G.InfinityAddonManagerWindow)
		_G.InfinityAddonManagerWindow:Show()
	end
end

_G.InfinityAddonManager = InfinityAddonManager
return InfinityAddonManager
