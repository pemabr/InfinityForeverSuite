-- PluribusCore Main Frame — Unified Guild Command Hub
-- Clean, uncluttered, graphical 8-tab architecture with zero redundant chrome:
--   1. Guild Hub      (Online Peers with Class Crests, @Mentions, Smart LFG, Live Feed, Open-World SOS)
--   2. Bags & Bank    (THE ONE unified Bag/Bank Icon Grid + Sell Gray Junk + Bag Valuation)
--   3. Professions    (Guild Recipes by Profession, Craft Profits, Recipe+Item Shopping List, Surplus Mats)
--   4. GearAdvisor    (Pluribus GearAdvisor: Cap Guardian, Stat Laboratory, Upgrade Roadmap, Talents & XP Bar)
--   5. Guild Mail     (In-Addon Inbox/Sent + Write Letter/Message Composer)
--   6. Guild Tax      (Guild Vault Balance, Auto-Tracking, Mail Tax to Banker, Compliance Ledger & Rate Config)
--   7. Nav & Guides   (Smart Pathfinder & Map Pins | Auto-Calculated Leveling & Farming Guides)
--   8. Market & Tools (Searchable Guild AH Prices & P2P DB, Raid Cooldowns, All 27 Suite Addons)

PluribusMainFrame = {
	currentTab = "Guild Hub",
	hubSubTab = "overview",    -- overview | roster
	rosterFilter = "ALL",      -- ALL | ONLINE | CURRENT | OUTDATED | NONE
	rosterSearchQuery = "",
	profSubTab = "crafters",   -- crafters | profit | wishlist | surplus
	mailSubTab = "inbox",      -- inbox | sent
	taxSubTab  = "ledger",     -- ledger | policy | history
	navSubTab  = "compass",    -- compass | guides
	toolsSubTab = "market",    -- market | cooldowns | modules
	healSubTab = "clickcast",  -- clickcast | decursive | layout | preview
	cdSubTab   = "active",     -- active | config
	bagChar = nil,
	bagFilter = "ALL",
	ahSearchQuery = "",
	ahSortMode = "recent",     -- recent | price | name
}
_G.PluribusMainFrame = PluribusMainFrame

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local SIDE_TABS = {
	{ key = "Guild Hub",      lKey = "TAB_GUILD_HUB",   icon = "Interface\\Icons\\Spell_Nature_AstralRecalGroup", title = "Guild Hub",      tooltip = "Online Guild Peers, @Mentions, Smart Guild LFG, Live Feed & SOS" },
	{ key = "Bags & Bank",    lKey = "TAB_BAGS",        icon = "Interface\\Icons\\INV_Misc_Bag_08",               title = "Bags & Bank",    tooltip = "Unified Bags & Bank viewer + Optional Backpack Replacement + Junk Sell" },
	{ key = "Professions",    lKey = "TAB_PROFESSIONS", icon = "Interface\\Icons\\Trade_BlackSmithing",           title = "Professions",    tooltip = "Real Guild Recipes, Craft Profits, Interactive To-Do & Shopping List (Buy/Farm)" },
	{ key = "GearAdvisor",    lKey = "TAB_GEAR",        icon = "Interface\\Icons\\INV_Helmet_74",                 title = "GearAdvisor",    tooltip = "Pluribus GearAdvisor: Cap Guardian, Stat Laboratory, Upgrade Roadmap, Talents & XP Bar" },
	{ key = "Guild Mail",     lKey = "TAB_MAIL",        icon = "Interface\\Icons\\INV_Letter_15",                 title = "Guild Mail",     tooltip = "In-Addon Guild Messages (Online/Offline) & WoW Mailbox Letter Composer" },
	{ key = "Guild Tax",      lKey = "TAB_TAX",         icon = "Interface\\Icons\\INV_Misc_Coin_02",              title = "Guild Tax",      tooltip = "Guild Treasury Tax Tracker, Auto-Loot/Quest Tax, Pay Banker & Compliance Ledger" },
	{ key = "Nav & Guides",   lKey = "TAB_NAV",         icon = "Interface\\Icons\\INV_Misc_Map_01",               title = "Nav & Guides",   tooltip = "Smart Azeroth Pathfinder, Map Pins & Auto-Calculated Leveling/Farming Guides" },
	{ key = "HealBot",        lKey = "TAB_HEALBOT",     icon = "Interface\\Icons\\Spell_Holy_FlashHeal",          title = "HealBot",        tooltip = "HealBot + Decursive: Klick-Heilung, 1-Klick Entzauberung, Live-Raid-Grid & Vorschau (/healbot)" },
	{ key = "Market & Tools", lKey = "TAB_MARKET",      icon = "Interface\\Icons\\Trade_Engineering",             title = "Market & Tools", tooltip = "Searchable Guild AH Prices & P2P DB, Raid Cooldowns, and All 27 Suite Addons" },
}

-- Direct launcher mapping for all 27 actual Pluribus Suite addons
local ADDON_LAUNCHERS = {
	PluribusCore                 = function() PluribusMainFrame:OpenToTab("Guild Hub") end,
	PluribusAttendance           = function() if _G.PluribusAttendanceUI and _G.PluribusAttendanceUI.Toggle then _G.PluribusAttendanceUI:Toggle() end end,
	PluribusCalendar             = function() if _G.PluribusCalendarUI and _G.PluribusCalendarUI.Toggle then _G.PluribusCalendarUI:Toggle() end end,
	PluribusConsumables          = function() if _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Toggle then _G.PluribusConsumablesUI:Toggle() elseif _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Show then _G.PluribusConsumablesUI:Show() end end,
	PluribusDKP                  = function() if _G.PluribusDKPUI and _G.PluribusDKPUI.Toggle then _G.PluribusDKPUI:Toggle() elseif _G.PluribusDKPUI and _G.PluribusDKPUI.Show then _G.PluribusDKPUI:Show() end end,
	PluribusData                 = function() if _G.PluribusDataUI and _G.PluribusDataUI.Toggle then _G.PluribusDataUI:Toggle() else PluribusMainFrame:OpenToTab("Market & Tools") end end,
	PluribusDataCollector        = function() if _G.PluribusDataCollectorUI and _G.PluribusDataCollectorUI.Toggle then _G.PluribusDataCollectorUI:Toggle() else PluribusMainFrame:OpenToTab("Market & Tools") end end,
	PluribusDetails              = function() if _G.PluribusDetailsUI and _G.PluribusDetailsUI.Toggle then _G.PluribusDetailsUI:Toggle() end end,
	PluribusEncounter            = function() if _G.PluribusEncounterUI and _G.PluribusEncounterUI.Toggle then _G.PluribusEncounterUI:Toggle() end end,
	PluribusGather               = function() if _G.PluribusGatherUI and _G.PluribusGatherUI.Toggle then _G.PluribusGatherUI:Toggle() end end,
	PluribusGatherPath           = function() if _G.PluribusGatherPathUI and _G.PluribusGatherPathUI.Toggle then _G.PluribusGatherPathUI:Toggle() end end,
	PluribusGear                 = function() PluribusMainFrame:OpenToTab("GearAdvisor") end,
	PluribusGearMgr              = function() if _G.PluribusGearMgrUI and _G.PluribusGearMgrUI.Toggle then _G.PluribusGearMgrUI:Toggle() else PluribusMainFrame:OpenToTab("GearAdvisor") end end,
	PluribusGuide                = function() PluribusMainFrame.navSubTab = "guides" PluribusMainFrame:OpenToTab("Nav & Guides") end,
	PluribusGuild                = function() if _G.PluribusGuildUI and _G.PluribusGuildUI.Toggle then _G.PluribusGuildUI:Toggle() end end,
	PluribusHealer               = function() PluribusMainFrame:OpenToTab("HealBot") end,
	PluribusInventory            = function() PluribusMainFrame:OpenToTab("Bags & Bank") end,
	PluribusLoot                 = function() if _G.PluribusLootUI and _G.PluribusLootUI.Toggle then _G.PluribusLootUI:Toggle() elseif _G.PluribusLootAuctionUI and _G.PluribusLootAuctionUI.CreateAuctionFrame then _G.PluribusLootAuctionUI:CreateAuctionFrame() end end,
	PluribusLootHistory          = function() if _G.PluribusLootHistoryUI and _G.PluribusLootHistoryUI.Toggle then _G.PluribusLootHistoryUI:Toggle() elseif _G.PluribusLootUI and _G.PluribusLootUI.Toggle then _G.PluribusLootUI:Toggle() end end,
	PluribusNavigation           = function() PluribusMainFrame.navSubTab = "compass" PluribusMainFrame:OpenToTab("Nav & Guides") end,
	PluribusPerformanceAnalytics = function() if _G.PluribusPerformanceUI and _G.PluribusPerformanceUI.Toggle then _G.PluribusPerformanceUI:Toggle() end end,
	PluribusProfiler             = function() if _G.PluribusProfilerUI and _G.PluribusProfilerUI.Toggle then _G.PluribusProfilerUI:Toggle() end end,
	PluribusQoL                  = function() if _G.PluribusQoLUI and _G.PluribusQoLUI.Toggle then _G.PluribusQoLUI:Toggle() end end,
	PluribusQuestie              = function() if _G.PluribusQuestieUI and _G.PluribusQuestieUI.Toggle then _G.PluribusQuestieUI:Toggle() end end,
	PluribusRaid                 = function() if _G.PluribusRaidUI and _G.PluribusRaidUI.Toggle then _G.PluribusRaidUI:Toggle() end end,
	PluribusRosterMgr            = function() if _G.PluribusRosterUI and _G.PluribusRosterUI.Toggle then _G.PluribusRosterUI:Toggle() elseif _G.PluribusOfficerDashboard then _G.PluribusOfficerDashboard:Toggle() end end,
	PluribusWorldBoss            = function() if _G.PluribusWorldBossUI and _G.PluribusWorldBossUI.Toggle then _G.PluribusWorldBossUI:Toggle() end end,
}

function PluribusMainFrame:LaunchAddon(addonName)
	local fn = ADDON_LAUNCHERS[addonName]
	if fn then
		local ok = pcall(fn)
		if ok then return true end
	end
	if _G.PluribusCommandRegistry and _G.PluribusCommandRegistry.ExecuteCommand then
		local short = addonName:gsub("^Pluribus", ""):lower()
		pcall(function() _G.PluribusCommandRegistry:ExecuteCommand(short, "") end)
	end
	return false
end

function PluribusMainFrame:Create()
	if _G.PluribusMainWindow then
		return _G.PluribusMainWindow
	end

	local UI = _G.PluribusUIFramework
	local mainFrame = UI:CreateFrame("PluribusMainWindow", UIParent, 780, 520, "Pluribus Suite", "Guild Hive Hub")
	mainFrame:SetPoint("CENTER")

	if mainFrame.closeBtn then
		mainFrame.closeBtn:SetScript("OnClick", function()
			mainFrame:Hide()
			if _G.PluribusMessaging then
				pcall(function() _G.PluribusMessaging:Publish("PLURIBUS_WINDOW_HIDDEN", "MainWindow") end)
			end
		end)
	end

	-- Clean Header Controls: ONE compact Settings button + ONE live HiveMind Sync badge (zero redundant banners!)
	if mainFrame.header and mainFrame.closeBtn then
		local settingsBtn = UI:CreateButton(mainFrame.header, "Settings", 70, 22, function()
			if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
				_G.PluribusSettingsPanel:Open()
			end
		end)
		settingsBtn:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", -6, 0)
		mainFrame.settingsBtn = settingsBtn

		if _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBadge then
			local badge = _G.PluribusHiveUI:CreateHealthBadge(mainFrame.header, function()
				if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() then
					PluribusMainFrame:ShowTab(_G.PluribusMainWindow, PluribusMainFrame.currentTab or "Guild Hub")
				end
			end)
			if badge then
				badge:SetPoint("RIGHT", settingsBtn, "LEFT", -8, 0)
				mainFrame.healthBadge = badge
			end
		end
	end

	-- 8 Clean Adventure-Guide-style right-edge side bookmark tabs
	mainFrame.sideTabs = {}
	for idx, def in ipairs(SIDE_TABS) do
		local tab = UI:CreateSideTab(mainFrame, idx, {
			icon = def.icon,
			title = def.title,
			tooltip = def.tooltip,
			size = 36,
			spacing = 42,
			yOffset = -48 - (idx - 1) * 42,
			onClick = function()
				PluribusMainFrame:ShowTab(mainFrame, def.key)
			end,
		})
		mainFrame.sideTabs[def.key] = tab
	end

	local contentFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -48)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
	UI:ApplyBackdrop(contentFrame, 0.07, 0.09, 0.14, 0.96, 0.22, 0.28, 0.38, 0.85)
	mainFrame.contentFrame = contentFrame
	self.frame = mainFrame

	local cachePending = false
	local marketMetaPending = false
	mainFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	mainFrame:SetScript("OnEvent", function(selfF, ev, arg1)
		if ev == "GET_ITEM_INFO_RECEIVED" and selfF:IsVisible() then
			local t = PluribusMainFrame.currentTab
			-- Fast surgical path for AH Market & P2P DB: patch ONLY visible rows in-place,
			-- NEVER tear down the tab or steal search input focus!
			if t == "Market & Tools" and PluribusMainFrame.toolsSubTab == "market" then
				local itemID = tonumber(arg1)
				if not marketMetaPending and PluribusMainFrame:HasPendingMarketItem(itemID) then
					marketMetaPending = true
					if C_Timer and C_Timer.After then
						C_Timer.After(0.20, function()
							marketMetaPending = false
							if selfF:IsVisible() and PluribusMainFrame.currentTab == "Market & Tools" and PluribusMainFrame.toolsSubTab == "market" then
								PluribusMainFrame:RefreshVisibleMarketRows()
							end
						end)
					else
						marketMetaPending = false
						PluribusMainFrame:RefreshVisibleMarketRows()
					end
				end
				return
			end
			if not cachePending and (t == "Bags & Bank" or t == "Professions" or t == "GearAdvisor") then
				cachePending = true
				if C_Timer and C_Timer.After then
					C_Timer.After(0.3, function()
						cachePending = false
						if selfF:IsVisible() then
							PluribusMainFrame:ShowTab(selfF, PluribusMainFrame.currentTab)
						end
					end)
				else
					cachePending = false
				end
			end
		end
	end)

	-- Guard against ever opening to a blank content pane
	mainFrame:HookScript("OnShow", function(selfF)
		if not selfF._plbHasRendered then
			PluribusMainFrame:ShowTab(selfF, PluribusMainFrame.currentTab or "Guild Hub")
		end
	end)
	mainFrame:HookScript("OnHide", function()
		if _G.PluribusHiveAuction and _G.PluribusHiveAuction.CancelMarketQuery then
			_G.PluribusHiveAuction:CancelMarketQuery("mainFrame")
		end
	end)

	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("PLURIBUS_LOCALE_CHANGED", function()
			if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() then
				PluribusMainFrame:ShowTab(_G.PluribusMainWindow, PluribusMainFrame.currentTab or "Guild Hub")
			end
		end)
		local rosterRefreshPending = false
		_G.PluribusMessaging:Subscribe("HIVE_ROSTER_UPDATED", function()
			if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible()
				and PluribusMainFrame.currentTab == "Guild Hub"
				and not rosterRefreshPending then
				rosterRefreshPending = true
				local doRefresh = function()
					rosterRefreshPending = false
					if not (_G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() and PluribusMainFrame.currentTab == "Guild Hub") then
						return
					end
					if PluribusMainFrame.hubSubTab == "roster" and PluribusMainFrame._refreshRosterList then
						pcall(PluribusMainFrame._refreshRosterList)
					elseif PluribusMainFrame.hubSubTab ~= "roster" then
						PluribusMainFrame:ShowTab(_G.PluribusMainWindow, "Guild Hub")
					end
				end
				if C_Timer and C_Timer.After then
					C_Timer.After(0.4, doRefresh)
				else
					doRefresh()
				end
			end
		end)
	end

	self:ShowTab(mainFrame, self.currentTab or "Guild Hub")
	return mainFrame
end

-- Map legacy tab names gracefully so existing slash commands & external links never break
local TAB_ALIASES = {
	["Hive Live"]   = "Guild Hub",
	["Gear Judge"]  = "GearAdvisor",
	["To-Do"]       = "Professions",
	["Shopping"]    = "Professions",
	["Navigation"]  = "Nav & Guides",
	["Guides"]      = "Nav & Guides",
	["Compute"]     = "Nav & Guides",
	["Market & DB"]    = "Market & Tools",
	["Cooldowns"]      = "Market & Tools",
	["CooldownConfig"] = "Market & Tools",
	["Modules"]        = "Market & Tools",
	["Healer"]         = "HealBot",
	["Decursive"]      = "HealBot",
	["HealBot & Decursive"] = "HealBot",
}

function PluribusMainFrame:OpenToTab(tabName)
	if tabName == "Privacy" or tabName == "Settings" then
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open(tabName == "Privacy" and "HiveMind Sharing" or nil)
		end
		return
	end
	if tabName == "Cooldowns" then
		self.toolsSubTab = "cooldowns"
		self.cdSubTab = "active"
	elseif tabName == "CooldownConfig" then
		self.toolsSubTab = "cooldowns"
		self.cdSubTab = "config"
	elseif tabName == "Modules" then self.toolsSubTab = "modules"
	elseif tabName == "Market & DB" then self.toolsSubTab = "market"
	elseif tabName == "Guides" or tabName == "Compute" then self.navSubTab = "guides"
	elseif tabName == "Navigation" then self.navSubTab = "compass"
	elseif tabName == "Roster" then self.hubSubTab = "roster"
	elseif tabName == "To-Do" or tabName == "Shopping" then self.profSubTab = "wishlist" end

	if tabName == "Roster" then tabName = "Guild Hub" end

	local resolved = TAB_ALIASES[tabName] or tabName or "Guild Hub"
	local f = self:Create()
	f:Show()
	self:ShowTab(f, resolved)
end

function PluribusMainFrame:HasPendingMarketItem(itemID)
	local mp = self.frame and self.frame._plbMarketPanel
	if not mp or not mp._pendingVisibleItemIDs then return false end
	if itemID == nil then
		return next(mp._pendingVisibleItemIDs) ~= nil
	end
	return mp._pendingVisibleItemIDs[itemID] == true
end

function PluribusMainFrame:RefreshVisibleMarketRows()
	local mp = self.frame and self.frame._plbMarketPanel
	if mp and mp:IsVisible() and mp._RefreshVisibleRowsMetadata then
		mp:_RefreshVisibleRowsMetadata()
	end
end

function PluribusMainFrame:RefreshMarketPanelIfVisible()
	if not self.frame or not self.frame:IsVisible() then return end
	if self.currentTab ~= "Market & Tools" or self.toolsSubTab ~= "market" then return end
	local mp = self.frame._plbMarketPanel
	if mp and mp:IsVisible() and mp._RequestData then
		if mp._UpdateBanner then mp:_UpdateBanner() end
		mp:_RequestData(true)
	end
end

function PluribusMainFrame:RefreshSideBadges(frame, forceSurplus)
	if not frame or not frame.sideTabs then return end
	if frame.sideTabs["Professions"] and _G.PluribusHiveProfessions then
		local now = GetTime and GetTime() or 0
		local needFresh = forceSurplus or self.currentTab == "Professions" or self.currentTab == "Bags & Bank"
			or (self._surplusBadgeAt == nil) or ((now - self._surplusBadgeAt) >= 10)
		if needFresh then
			self._surplusBadgeCount = #(_G.PluribusHiveProfessions:GetMySurplusMatches() or {})
			self._surplusBadgeAt = now
		end
		frame.sideTabs["Professions"]:SetBadge(self._surplusBadgeCount or 0, 0.12, 0.62, 0.36)
	end
	if frame.sideTabs["Guild Mail"] and _G.PluribusHiveMail then
		local unread = _G.PluribusHiveMail:GetUnreadCount()
		frame.sideTabs["Guild Mail"]:SetBadge(unread, 0.85, 0.62, 0.14)
	end
	if frame.sideTabs["Guild Tax"] and _G.PluribusHiveTax then
		local due = _G.PluribusHiveTax:GetBalanceDue()
		local goldDue = math.floor(due / 10000)
		frame.sideTabs["Guild Tax"]:SetBadge(goldDue > 0 and goldDue or 0, 0.82, 0.32, 0.24)
	end
end

function PluribusMainFrame:ShowTab(frame, tabName)
	if not frame or not frame.contentFrame then return end
	if tabName == "Privacy" or tabName == "Settings" then
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open(tabName == "Privacy" and "HiveMind Sharing" or nil)
		end
		return
	end
	tabName = TAB_ALIASES[tabName] or tabName or "Guild Hub"
	local UI = _G.PluribusUIFramework
	self.currentTab = tabName
	frame.contentFrame:SetScript("OnUpdate", nil)
	if frame._plbMarketPanel then
		frame._plbMarketPanel:Hide()
	end
	if tabName ~= "Market & Tools" and _G.PluribusHiveAuction and _G.PluribusHiveAuction.CancelMarketQuery then
		_G.PluribusHiveAuction:CancelMarketQuery("mainFrame")
	end
	UI:ClearContainer(frame.contentFrame)
	frame._plbHasRendered = true

	for name, tab in pairs(frame.sideTabs or {}) do
		tab:SetActiveState(name == tabName)
	end
	if frame.healthBadge and frame.healthBadge.Refresh then
		frame.healthBadge:Refresh()
	end
	self:RefreshSideBadges(frame)

	local ok, err = pcall(function()
		if tabName == "Guild Hub" then
			self:ShowGuildHubTab(frame)
		elseif tabName == "Bags & Bank" then
			self:ShowBagsTab(frame)
		elseif tabName == "Professions" then
			self:ShowProfessionsTab(frame)
		elseif tabName == "GearAdvisor" then
			self:ShowGearJudgeTab(frame)
		elseif tabName == "Guild Mail" then
			self:ShowGuildMailTab(frame)
		elseif tabName == "Guild Tax" then
			self:ShowGuildTaxTab(frame)
		elseif tabName == "Nav & Guides" then
			self:ShowNavigationTab(frame)
		elseif tabName == "HealBot" then
			self:ShowHealBotTab(frame)
		elseif tabName == "Market & Tools" then
			self:ShowMarketToolsTab(frame)
		else
			self:ShowGuildHubTab(frame)
		end
	end)

	if not ok then
		local errCard = UI:CreateBannerCard(frame.contentFrame, 720, 66, "Interface\\Icons\\INV_Misc_QuestionMark",
			"|cfff87171Tab Render Recovery (" .. tostring(tabName) .. ")|r",
			tostring(err or "Unknown error"):sub(1, 95), 0.88, 0.26, 0.28, 120)
		errCard:SetPoint("TOPLEFT", frame.contentFrame, "TOPLEFT", 14, -14)
		local retryBtn = UI:CreateButton(errCard, "Reload Tab", 96, 24, function()
			PluribusMainFrame:ShowTab(frame, tabName)
		end, true)
		retryBtn:SetPoint("RIGHT", errCard, "RIGHT", -10, 0)
	end

	-- Re-apply subtree frame levels so newly built cards/scrollframes ALWAYS render cleanly above contentFrame!
	UI:BringToFront(frame)
end

-- ============================================================================
-- TAB 1: GUILD HUB (Overview: LFG & Feed | Member Roster & Addon Version Check)
-- ============================================================================
function PluribusMainFrame:ShowGuildHubTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	self._refreshRosterList = nil

	local roster, rStats = {}, { total = 0, online = 0, withAddon = 0, withAddonOnline = 0, current = 0, outdated = 0, none = 0, latestVersion = "2.2.0", isSelfOutdated = false }
	if _G.PluribusHive and _G.PluribusHive.GetGuildMemberRoster then
		roster, rStats = _G.PluribusHive:GetGuildMemberRoster()
	end

	local function SwitchHub(sub)
		PluribusMainFrame.hubSubTab = sub
		PluribusMainFrame:ShowTab(frame, "Guild Hub")
	end

	-- Clean top subtab bar + SOS button
	local bOverview = UI:CreateButton(p, L("HUB_SUB_OVERVIEW"), 184, 24, function() SwitchHub("overview") end)
	bOverview:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
	bOverview:SetActiveState(self.hubSubTab ~= "roster")

	local rosterBtnLabel = string.format("%s (%d/%d)", L("HUB_SUB_ROSTER"), rStats.withAddon or 0, rStats.total or 0)
	local bRoster = UI:CreateButton(p, rosterBtnLabel, 244, 24, function()
		if _G.PluribusHive and _G.PluribusHive.RequestVersionCheck then
			_G.PluribusHive:RequestVersionCheck()
		end
		SwitchHub("roster")
	end)
	bRoster:SetPoint("LEFT", bOverview, "RIGHT", 6, 0)
	bRoster:SetActiveState(self.hubSubTab == "roster")

	local sosBtn = UI:CreateButton(p, "Open-World SOS", 122, 24, function()
		if _G.PluribusHiveDistress then
			local sent = _G.PluribusHiveDistress:BroadcastSOS(true)
			if not sent and _G.PluribusUtils then
				_G.PluribusUtils:Warning(L("SOS_OPEN_WORLD_ONLY"), "Hive")
			end
			PluribusMainFrame:ShowTab(frame, "Guild Hub")
		end
	end)
	sosBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -10)

	local officerBtn = UI:CreateButton(p, "Officer Console", 112, 24, function()
		if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Show then
			_G.PluribusOfficerDashboard:Show()
		end
	end)
	officerBtn:SetPoint("RIGHT", sosBtn, "LEFT", -6, 0)

	-- ========================================================================
	-- SUBTAB B: FULL GUILD MEMBER ROSTER WITH ADDON VERSION STATUS
	-- ========================================================================
	if self.hubSubTab == "roster" then
		local sumCard = UI:CreateCard(p, 728, 38)
		sumCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -42)

		local sumText = UI:CreateLabel(sumCard, L("ROSTER_SUMMARY",
			rStats.online or 0, rStats.total or 0,
			rStats.current or 0, rStats.outdated or 0, rStats.none or 0,
			tostring(rStats.latestVersion or "2.2.0")), 0.90, 0.94, 0.98, "GameFontHighlightSmall")
		sumText:SetPoint("LEFT", sumCard, "LEFT", 10, 0)

		local checkBtn = UI:CreateButton(sumCard, L("ROSTER_CHECK_VERSIONS"), 134, 22, function()
			if _G.PluribusHive and _G.PluribusHive.RequestVersionCheck then
				_G.PluribusHive:RequestVersionCheck()
			end
			if PluribusMainFrame._refreshRosterList then
				PluribusMainFrame._refreshRosterList()
			end
		end, true)
		checkBtn:SetPoint("RIGHT", sumCard, "RIGHT", -8, 0)

		-- Search & Filter bar (OUTSIDE scroll content so typing never loses focus!)
		local toolCard = UI:CreateCard(p, 728, 36)
		toolCard:SetPoint("TOPLEFT", sumCard, "BOTTOMLEFT", 0, -6)

		local sLbl = UI:CreateLabel(toolCard, L("SEARCH"), 0.78, 0.85, 0.94, "GameFontHighlightSmall")
		sLbl:SetPoint("LEFT", toolCard, "LEFT", 10, 0)

		local searchBox = UI:CreateInputBox(toolCard, 176, 22)
		searchBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
		searchBox:SetText(self.rosterSearchQuery or "")

		local filterDefs = {
			{ key = "ALL",      label = L("ROSTER_FILTER_ALL"),      w = 54 },
			{ key = "ONLINE",   label = L("ROSTER_FILTER_ONLINE"),   w = 82 },
			{ key = "CURRENT",  label = L("ROSTER_FILTER_CURRENT"),  w = 72 },
			{ key = "OUTDATED", label = L("ROSTER_FILTER_OUTDATED"), w = 74 },
			{ key = "NONE",     label = L("ROSTER_FILTER_NONE"),     w = 82 },
		}
		local filterBtns = {}
		local prevBtn = searchBox

		local scroll = UI:CreateScrollFrame(p, "PluribusHubRosterScroll", 728, 322)
		scroll:SetPoint("TOPLEFT", toolCard, "BOTTOMLEFT", 0, -6)

		local function RenderRosterRows()
			local curRoster, curStats = {}, rStats
			if _G.PluribusHive and _G.PluribusHive.GetGuildMemberRoster then
				curRoster, curStats = _G.PluribusHive:GetGuildMemberRoster()
			end
			sumText:SetText(L("ROSTER_SUMMARY",
				curStats.online or 0, curStats.total or 0,
				curStats.current or 0, curStats.outdated or 0, curStats.none or 0,
				tostring(curStats.latestVersion or "2.2.0")))

			for k, fb in pairs(filterBtns) do
				fb:SetActiveState((PluribusMainFrame.rosterFilter or "ALL") == k)
			end

			UI:ClearContainer(scroll.content)
			local q = (PluribusMainFrame.rosterSearchQuery or ""):lower():match("^%s*(.-)%s*$")
			local mode = PluribusMainFrame.rosterFilter or "ALL"
			local y = -2
			local shown = 0

			if curStats.isSelfOutdated then
				local warn = UI:CreateBannerCard(scroll.content, 698, 42, "Interface\\Icons\\INV_Misc_Bell_01",
					"|cfffbbf24" .. L("HIVE_OUTDATED_SELF", tostring(_G.PluribusHive.version or "2.2.0"), tostring(curStats.latestVersion or "2.2.0")) .. "|r",
					"Bitte aktualisiere dein Pluribus Addon-Paket.", 0.96, 0.72, 0.14)
				warn:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
				y = y - 48
			end

			for _, m in ipairs(curRoster) do
				local passFilter = (mode == "ALL")
					or (mode == "ONLINE" and m.online)
					or (mode == "CURRENT" and m.addonStatus == "CURRENT")
					or (mode == "OUTDATED" and m.addonStatus == "OUTDATED")
					or (mode == "NONE" and m.addonStatus == "NONE")

				if passFilter and q ~= "" then
					local hay = (tostring(m.name or "") .. " " .. tostring(m.rank or "") .. " " .. tostring(m.zone or "") .. " " .. tostring(m.addonVersion or "")):lower()
					if not hay:find(q, 1, true) then
						passFilter = false
					end
				end

				if passFilter then
					shown = shown + 1
					local row = UI:CreateListRow(scroll.content, 698, 30, shown, function()
						if m.addonStatus ~= "NONE" then
							PluribusMainFrame.bagChar = m.name
							PluribusMainFrame:ShowTab(frame, "Bags & Bank")
						end
					end)
					row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

					-- Online/Offline indicator dot
					local dot = row:CreateTexture(nil, "OVERLAY")
					dot:SetSize(7, 7)
					dot:SetPoint("LEFT", row, "LEFT", 6, 0)
					if dot.SetColorTexture then
						if m.online then dot:SetColorTexture(0.29, 0.87, 0.50, 1)
						else dot:SetColorTexture(0.45, 0.50, 0.58, 0.7) end
					else
						dot:SetTexture("Interface\\Buttons\\WHITE8X8")
						if m.online then dot:SetVertexColor(0.29, 0.87, 0.50, 1)
						else dot:SetVertexColor(0.45, 0.50, 0.58, 0.7) end
					end

					local cIcon = UI:CreateClassIcon(row, m.class, 20)
					cIcon:SetPoint("LEFT", dot, "RIGHT", 5, 0)

					local _, _, _, hex = UI:GetClassColor(m.class)
					local selfTag = m.isSelf and (" |cff38bdf8" .. L("ROSTER_SELF_TAG") .. "|r") or ""
					local nameStr = string.format("%s%s|r%s |cff94a3b8Lv%d|r", hex, m.name, selfTag, m.level or 0)
					local lName = UI:CreateLabel(row, nameStr)
					lName:SetPoint("LEFT", cIcon, "RIGHT", 6, 0)
					lName:SetWidth(178)
					if lName.SetWordWrap then lName:SetWordWrap(false) end

					-- Rank + Zone / Offline
					local locText = m.online
						and ((m.zone and m.zone ~= "") and m.zone or L("ROSTER_ONLINE"))
						or ("|cff64748b" .. L("ROSTER_OFFLINE") .. "|r")
					local metaStr = (m.rank and m.rank ~= "")
						and string.format("|cff94a3b8%s|r · %s", m.rank:sub(1, 14), locText)
						or locText
					local lMeta = UI:CreateLabel(row, metaStr, 0.72, 0.80, 0.90, "GameFontHighlightSmall")
					lMeta:SetPoint("LEFT", lName, "RIGHT", 6, 0)
					lMeta:SetWidth(182)
					if lMeta.SetWordWrap then lMeta:SetWordWrap(false) end

					-- Color-coded Addon Status Badge (Aktuell / Veraltet / Kein Addon)
					local statusText
					if m.addonStatus == "CURRENT" then
						statusText = string.format("|cff4ade80%s v%s|r", L("ROSTER_STATUS_CURRENT"), tostring(m.addonVersion))
					elseif m.addonStatus == "OUTDATED" then
						statusText = string.format("|cfffbbf24%s (v%s)|r", L("ROSTER_STATUS_OUTDATED"), tostring(m.addonVersion))
					else
						statusText = "|cfff87171" .. L("ROSTER_STATUS_NONE") .. "|r"
					end
					local lStatus = UI:CreateLabel(row, statusText, 1, 1, 1, "GameFontHighlightSmall")
					lStatus:SetPoint("LEFT", lMeta, "RIGHT", 6, 0)
					lStatus:SetWidth(148)
					if lStatus.SetWordWrap then lStatus:SetWordWrap(false) end

					-- Right quick actions (Mail + Invite / GPS)
					if not m.isSelf then
						local mailBtn = UI:CreateButton(row, "Mail", 40, 20, function()
							if _G.PluribusHiveMail then _G.PluribusHiveMail:OpenComposer(m.name, "Hallo " .. m.name, "") end
						end)
						mailBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)

						if m.online then
							local invBtn = UI:CreateButton(row, L("ROSTER_INVITE"), 42, 20, function()
								if C_PartyInfo and C_PartyInfo.InviteUnit then
									pcall(C_PartyInfo.InviteUnit, m.rawName or m.name)
								elseif InviteUnit then
									pcall(InviteUnit, m.rawName or m.name)
								end
							end, m.addonStatus ~= "NONE")
							invBtn:SetPoint("RIGHT", mailBtn, "LEFT", -4, 0)
						end
					end

					y = y - 32
				end
			end

			if shown == 0 then
				local em = UI:CreateLabel(scroll.content, L("ROSTER_EMPTY"), 0.68, 0.78, 0.88)
				em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 10, -14)
			end
			scroll.content:SetHeight(math.max(304, math.abs(y) + 12))
		end

		for _, fd in ipairs(filterDefs) do
			local btn = UI:CreateButton(toolCard, fd.label, fd.w, 22, function()
				PluribusMainFrame.rosterFilter = fd.key
				RenderRosterRows()
			end)
			btn:SetPoint("LEFT", prevBtn, "RIGHT", prevBtn == searchBox and 10 or 4, 0)
			filterBtns[fd.key] = btn
			prevBtn = btn
		end

		searchBox:SetScript("OnTextChanged", function(selfBox)
			PluribusMainFrame.rosterSearchQuery = selfBox:GetText() or ""
			RenderRosterRows()
		end)

		self._refreshRosterList = RenderRosterRows
		RenderRosterRows()
		return
	end

	-- ========================================================================
	-- SUBTAB A: GUILD HUB OVERVIEW (Online Peers w/ Version Badge + LFG & Feed)
	-- ========================================================================
	local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
	local lfgPosts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}
	local latestVer = rStats.latestVersion or (_G.PluribusHive and _G.PluribusHive.version) or "2.2.0"

	local postCard = UI:CreateCard(p, 728, 40)
	postCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -42)

	local lfgLbl = UI:CreateLabel(postCard, "|cff38bdf8LFG Activity:|r", 1, 1, 1)
	lfgLbl:SetPoint("LEFT", postCard, "LEFT", 10, 0)

	local actBox = UI:CreateInputBox(postCard, 310, 22)
	actBox:SetPoint("LEFT", lfgLbl, "RIGHT", 8, 0)
	actBox:SetText("Strat UD / BRD / Raid")

	local roleBox = UI:CreateInputBox(postCard, 78, 22)
	roleBox:SetPoint("LEFT", actBox, "RIGHT", 8, 0)
	roleBox:SetText("ANY")

	local postLfgBtn = UI:CreateButton(postCard, "Post Smart LFG", 124, 22, function()
		if _G.PluribusHiveLFG then
			_G.PluribusHiveLFG:PostLFG(actBox:GetText(), roleBox:GetText())
			PluribusMainFrame:ShowTab(frame, "Guild Hub")
		end
	end, true)
	postLfgBtn:SetPoint("LEFT", roleBox, "RIGHT", 8, 0)

	-- Left Column: Online Hive Peers with Class Crests, Version Badge + Instant Sync / Letter / GPS Actions
	local leftCard = UI:CreateCard(p, 360, 356, string.format("Online Peers (%d) · Gilde: %d/%d", #members, rStats.withAddon or 0, rStats.total or 0))
	leftCard:SetPoint("TOPLEFT", postCard, "BOTTOMLEFT", 0, -8)

	local syncPeersBtn = UI:CreateButton(leftCard, "Gilde Sync", 74, 20, function()
		if _G.PluribusHive and _G.PluribusHive.ForcePeerDiscovery then
			local res = _G.PluribusHive:ForcePeerDiscovery()
			if not res.inGuild then
				UI:ShowNotification("|cfffbbf24Du bist aktuell in keiner Gilde — Sync nur für Gruppe/Raid gesendet.|r", 3.2)
			elseif (res.failed or 0) > 0 and res.lastError then
				UI:ShowNotification(string.format("|cfffbbf24Gilden-Sync gesendet (%d Peers) · Hinweis: Fehlercode %s|r", res.peersOnline or 0, tostring(res.lastError)), 3.5)
			else
				UI:ShowNotification(string.format("|cff4ade80Gilden-Sync gesendet · %d andere Pluribus-Spieler online.|r", res.peersOnline or 0), 3.0)
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(1.6, function()
					if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() and PluribusMainFrame.currentTab == "Guild Hub" then
						PluribusMainFrame:ShowTab(_G.PluribusMainWindow, "Guild Hub")
					end
				end)
			end
		end
	end, true)
	syncPeersBtn:SetPoint("TOPRIGHT", leftCard, "TOPRIGHT", -6, -4)

	local leftScroll = UI:CreateScrollFrame(leftCard, "PluribusHubMembersScroll", 344, 320)
	leftScroll:SetPoint("TOPLEFT", leftCard, "TOPLEFT", 8, -28)
	local ly = -2

	for idx, m in ipairs(members) do
		local row = UI:CreateListRow(leftScroll.content, 318, 30, idx, function()
			PluribusMainFrame.bagChar = m.name
			PluribusMainFrame:ShowTab(frame, "Bags & Bank")
		end)
		row:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 0, ly)

		local cIcon = UI:CreateClassIcon(row, m.class, 22)
		cIcon:SetPoint("LEFT", row, "LEFT", 5, 0)

		local _, _, _, hex = UI:GetClassColor(m.class)
		local ver = m.version or (_G.PluribusHive and _G.PluribusHive.version) or "2.2.0"
		local isOutdated = _G.PluribusHive and _G.PluribusHive.CompareVersions and _G.PluribusHive:CompareVersions(ver, latestVer) < 0
		local verTag = isOutdated and (" |cfffbbf24v" .. ver .. "!|r") or (" |cff4ade80v" .. ver .. "|r")
		local rightPad = m.isSelf and -8 or -92
		local l1 = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d|r%s", hex, m.name, m.level or 60, verTag))
		l1:SetPoint("TOPLEFT", cIcon, "TOPRIGHT", 6, -1)
		l1:SetPoint("RIGHT", row, "RIGHT", rightPad, 0)
		if l1.SetWordWrap then l1:SetWordWrap(false) end

		local l2 = UI:CreateLabel(row, tostring(m.zone or "Azeroth"), 0.68, 0.78, 0.88, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", cIcon, "BOTTOMRIGHT", 6, 1)
		l2:SetPoint("RIGHT", row, "RIGHT", rightPad, 0)
		if l2.SetWordWrap then l2:SetWordWrap(false) end

		if not m.isSelf then
			local mailBtn = UI:CreateButton(row, "Mail", 42, 20, function()
				if _G.PluribusHiveMail then _G.PluribusHiveMail:OpenComposer(m.name, "Hello " .. m.name, "") end
			end)
			mailBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

			local gpsBtn = UI:CreateButton(row, "GPS", 38, 20, function()
				if _G.PluribusNavigationUI then
					_G.PluribusNavigationUI:SetWaypoint(m.name, m.zone or "Azeroth", (m.x or 0.5) * 100, (m.y or 0.5) * 100, m.mapID)
				end
			end, true)
			gpsBtn:SetPoint("RIGHT", mailBtn, "LEFT", -3, 0)
		end
		ly = ly - 32
	end

	local overlaps = (_G.PluribusHiveDistress and _G.PluribusHiveDistress:GetGuildmatesOnSameQuest()) or {}
	if #overlaps > 0 then
		ly = ly - 6
		local oHdr = UI:CreateLabel(leftScroll.content, "|cff4ade80Same-Quest Guildmates:|r")
		oHdr:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 4, ly)
		ly = ly - 18
		for _, o in ipairs(overlaps) do
			local oLbl = UI:CreateLabel(leftScroll.content, string.format("• %s — %s", o.member, o.questTitle:sub(1, 28)), 0.80, 0.96, 0.84)
			oLbl:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 6, ly)
			ly = ly - 16
		end
	end
	leftScroll.content:SetHeight(math.max(304, math.abs(ly) + 12))

	-- Right Column: Active Guild LFG & Live Activity Feed
	local rightCard = UI:CreateCard(p, 360, 356, "Live Guild Feed (LFG · Rares · Mail · Tax · SOS)")
	rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
	local rightScroll = UI:CreateScrollFrame(rightCard, "PluribusHubFeedScroll", 344, 320)
	rightScroll:SetPoint("TOPLEFT", rightCard, "TOPLEFT", 8, -28)
	local ry = -2

	for idx, post in ipairs(lfgPosts) do
		local row = UI:CreateListRow(rightScroll.content, 318, 32, idx, function()
			if SendChatMessage and post.sender ~= PluribusHive:GetPlayerShortName() then
				pcall(SendChatMessage, "Hey! Invite for " .. post.activity .. "?", "WHISPER", nil, post.sender)
			end
		end)
		row:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 0, ry)
		local l1 = UI:CreateLabel(row, "|cff38bdf8[LFG]|r " .. post.sender .. ": " .. tostring(post.activity):sub(1, 24))
		l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		local l2 = UI:CreateLabel(row, "Lv " .. (post.minLevel or 1) .. "-" .. (post.maxLevel or 60) .. " · Click to whisper", 0.58, 0.72, 0.86, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
		ry = ry - 34
	end

	local feed = (_G.PluribusHive and _G.PluribusHive.recentEvents) or {}
	for i, ev in ipairs(feed) do
		if i > 20 then break end
		local col = (ev.category == "SOS" and "|cfff87171")
			or (ev.category == "RARE" and "|cfffbbf24")
			or (ev.category == "TAX" and "|cff4ade80")
			or (ev.category == "MAIL" and "|cfffbbf24")
			or "|cff38bdf8"
		local lbl = UI:CreateLabel(rightScroll.content, col .. "[" .. ev.category .. "]|r " .. tostring(ev.text):sub(1, 48))
		lbl:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 4, ry)
		ry = ry - 18
	end
	if #lfgPosts == 0 and #feed == 0 then
		local empty = UI:CreateLabel(rightScroll.content, "HiveMind ist online und bereit.\nGilden-LFG, Rares, SOS, Post & Steuern erscheinen hier live.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 6, -8)
		empty:SetWidth(310)
	end
	rightScroll.content:SetHeight(math.max(304, math.abs(ry) + 12))
end

-- ============================================================================
-- TAB 2: BAGS & BANK (Visual Icon Grid + Class Crests + Cross-Guild Search)
-- ============================================================================
function PluribusMainFrame:ShowBagsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	if not _G.PluribusHiveInventory then return end

	local chars = _G.PluribusHiveInventory:GetInspectableCharacters()
	if not self.bagChar and #chars > 0 then self.bagChar = chars[1].name end

	local searchLbl = UI:CreateLabel(p, "Search:", 0.75, 0.82, 0.90)
	searchLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -18)
	local searchBox = UI:CreateInputBox(p, 196, 24)
	searchBox:SetPoint("LEFT", searchLbl, "RIGHT", 6, 0)

	local fAll, fBags, fBank, itemScroll, summaryLbl

	-- Helper: Sell all Poor (gray) junk items via unified HiveInventory handler (auto-runs at vendors too!)
	local function SellGrayJunk()
		if _G.PluribusHiveInventory and _G.PluribusHiveInventory.SellGrayTrash then
			_G.PluribusHiveInventory:SellGrayTrash(false)
		end
	end

	local function ComputeItemsValueCopper(items)
		local total = 0
		for _, it in ipairs(items or {}) do
			local ah = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(it.itemID)
			local vendorUnit = tonumber((select(11, PluribusUtils:GetItemInfo(it.itemID)))) or 0
			local unit = (ah and ah.copper and ah.copper > 0) and ah.copper or vendorUnit
			total = total + unit * (tonumber(it.count) or 1)
		end
		return total
	end

	local function BuildEntries(tbl, ownerName, isBank, query)
		local out = {}
		for id, cnt in pairs(tbl or {}) do
			if cnt and cnt > 0 then
				local name, link, quality, _, _, _, _, _, _, icon = PluribusUtils:GetItemInfo(id)
				icon = icon or PluribusUtils:GetItemIcon(id)
				local dName = name or ("Item #" .. tostring(id))
				if query == "" or dName:lower():find(query, 1, true) or tostring(id) == query then
					table.insert(out, {
						itemID = id, name = dName, link = link, quality = quality or 1, icon = icon,
						count = cnt, isBank = isBank, owner = ownerName,
					})
				end
			end
		end
		table.sort(out, function(a, b)
			if (a.quality or 1) ~= (b.quality or 1) then return (a.quality or 1) > (b.quality or 1) end
			return a.name < b.name
		end)
		return out
	end

	local function RenderBagGrid()
		if not itemScroll then return end
		UI:ClearContainer(itemScroll.content)
		local query = (searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$")
		local endY = -4

		if query ~= "" then
			local matches = _G.PluribusHiveInventory:SearchAll(query)
			local list = {}
			for _, m in ipairs(matches) do
				local cnt = (PluribusMainFrame.bagFilter == "BAGS" and m.bags) or (PluribusMainFrame.bagFilter == "BANK" and m.bank) or m.total
				if cnt > 0 then
					table.insert(list, {
						itemID = m.itemID, name = m.name, link = m.link, quality = m.quality,
						icon = m.icon or PluribusUtils:GetItemIcon(m.itemID), count = cnt,
						isBank = (m.bags == 0 and m.bank > 0), owner = m.owner,
					})
				end
			end
			summaryLbl:SetText(string.format("|cff38bdf8Search across All Alts & Guild:|r %d matches", #list))
			endY = _G.PluribusHiveUI:RenderItemGrid(itemScroll.content, list, {
				cols = 11, slotSize = 38, gap = 5, startY = -4, showOwnerInTooltip = true,
				emptyText = "No items match your search across alts or guildmates.",
			})
		else
			local selected = nil
			for _, ch in ipairs(chars) do
				if ch.name == PluribusMainFrame.bagChar then selected = ch break end
			end
			if not selected and chars[1] then
				selected = chars[1]
				PluribusMainFrame.bagChar = selected.name
			end
			if selected then
				local bagItems = (PluribusMainFrame.bagFilter ~= "BANK") and BuildEntries(selected.bags, selected.name, false, "") or {}
				local bankItems = (PluribusMainFrame.bagFilter ~= "BAGS") and BuildEntries(selected.bank, selected.name, true, "") or {}
				local bagVal = ComputeItemsValueCopper(bagItems) + ComputeItemsValueCopper(bankItems)
				local _, _, _, hex = UI:GetClassColor(selected.class)
				summaryLbl:SetText(string.format("%s%s|r Lv%d · |cfffbbf24%s|r · Est. Value: |cff4ade80%s|r",
					hex, selected.name, selected.level or 60, PluribusUtils:FormatGold(selected.gold or 0), PluribusUtils:FormatGold(bagVal)))
				local curY = -4
				if PluribusMainFrame.bagFilter ~= "BANK" then
					curY = _G.PluribusHiveUI:RenderItemGrid(itemScroll.content, bagItems, {
						cols = 11, slotSize = 38, gap = 5, startY = curY,
						headerText = string.format("|cff38bdf8Bags|r (%d stacks)", #bagItems),
					})
				end
				if PluribusMainFrame.bagFilter ~= "BAGS" then
					curY = _G.PluribusHiveUI:RenderItemGrid(itemScroll.content, bankItems, {
						cols = 11, slotSize = 38, gap = 5, startY = curY,
						headerText = string.format("|cff60a5faBank|r (%d stacks)", #bankItems),
						emptyText = "No bank items cached yet. Open Bank once on this character to sync!",
					})
				end
				endY = curY
			end
		end
		itemScroll.content:SetHeight(math.max(350, math.abs(endY) + 12))
	end

	local function SetFilter(mode)
		PluribusMainFrame.bagFilter = mode
		fAll:SetActiveState(mode == "ALL")
		fBags:SetActiveState(mode == "BAGS")
		fBank:SetActiveState(mode == "BANK")
		RenderBagGrid()
	end

	fAll = UI:CreateButton(p, "All", 42, 24, function() SetFilter("ALL") end)
	fAll:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
	fAll:SetActiveState(self.bagFilter == "ALL")

	fBags = UI:CreateButton(p, "Bags", 48, 24, function() SetFilter("BAGS") end)
	fBags:SetPoint("LEFT", fAll, "RIGHT", 4, 0)
	fBags:SetActiveState(self.bagFilter == "BAGS")

	fBank = UI:CreateButton(p, "Bank", 48, 24, function() SetFilter("BANK") end)
	fBank:SetPoint("LEFT", fBags, "RIGHT", 4, 0)
	fBank:SetActiveState(self.bagFilter == "BANK")

	local junkBtn = UI:CreateButton(p, L("SELL_GRAY_JUNK"), 88, 24, SellGrayJunk)
	junkBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local sortBagsBtn = UI:CreateButton(p, "Sortieren", 68, 24, function()
		if _G.PluribusHiveInventory and _G.PluribusHiveInventory.SortPhysicalBags then
			_G.PluribusHiveInventory:SortPhysicalBags()
		end
	end, true)
	sortBagsBtn:SetPoint("RIGHT", junkBtn, "LEFT", -4, 0)

	local trashCount = (_G.PluribusHiveInventory and _G.PluribusHiveInventory.GetCustomTrashCount and _G.PluribusHiveInventory:GetCustomTrashCount()) or 0
	local trashBtn = UI:CreateButton(p, string.format("Trash (%d)", trashCount), 66, 24, function()
		if _G.PluribusHiveInventory then
			if GetCursorInfo then
				local kind, itemID = GetCursorInfo()
				if kind == "item" and itemID then
					_G.PluribusHiveInventory:ToggleCustomTrash(itemID)
					if ClearCursor then pcall(ClearCursor) end
					PluribusMainFrame:ShowTab(frame, "Bags & Bank")
					return
				end
			end
			_G.PluribusHiveInventory:ToggleTrashManagerWindow()
		end
	end)
	trashBtn:SetPoint("RIGHT", sortBagsBtn, "LEFT", -4, 0)
	trashBtn:SetScript("OnReceiveDrag", function()
		if _G.PluribusHiveInventory and GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				_G.PluribusHiveInventory:ToggleCustomTrash(itemID)
				if ClearCursor then pcall(ClearCursor) end
				PluribusMainFrame:ShowTab(frame, "Bags & Bank")
			end
		end
	end)

	local replaceOn = _G.PluribusHive and _G.PluribusHive:GetConfig().replaceNativeBags == true
	local bagUiBtn = UI:CreateButton(p, L("UNIFIED_BAG_MODE") .. (replaceOn and ": AN" or ""), 82, 24, function()
		if _G.PluribusHive then
			local nextVal = not (_G.PluribusHive:GetConfig().replaceNativeBags == true)
			_G.PluribusHive:SetConfig("replaceNativeBags", nextVal)
			if _G.PluribusHiveInventory then
				if _G.PluribusHiveInventory.SyncNativeBagHooks then
					_G.PluribusHiveInventory:SyncNativeBagHooks()
				elseif _G.PluribusHiveInventory.SyncNativeBagSuppression then
					_G.PluribusHiveInventory:SyncNativeBagSuppression()
				end
				if nextVal and _G.PluribusHiveInventory.ToggleUnifiedBagWindow then
					_G.PluribusHiveInventory:ToggleUnifiedBagWindow(true)
				elseif not nextVal and _G.PluribusHiveInventory.unifiedBagFrame and _G.PluribusHiveInventory.unifiedBagFrame:IsShown() then
					_G.PluribusHiveInventory.unifiedBagFrame:Hide()
				end
			end
			PluribusMainFrame:ShowTab(frame, "Bags & Bank")
		end
	end, replaceOn)
	bagUiBtn:SetPoint("RIGHT", trashBtn, "LEFT", -4, 0)

	local syncBagBtn = UI:CreateButton(p, L("SCAN_BAGS"), 62, 24, function()
		if _G.PluribusHiveInventory then
			_G.PluribusHiveInventory:ScanBags()
			_G.PluribusHiveInventory:BroadcastBags()
		end
		PluribusMainFrame:ShowTab(frame, "Bags & Bank")
	end, true)
	syncBagBtn:SetPoint("RIGHT", bagUiBtn, "LEFT", -4, 0)

	local charCard = UI:CreateCard(p, 198, 404, "Characters (" .. #chars .. ")")
	charCard:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
	local charScroll = UI:CreateScrollFrame(charCard, "PluribusHubBagCharScroll", 184, 368)
	charScroll:SetPoint("TOPLEFT", charCard, "TOPLEFT", 6, -28)

	local cy = -2
	for idx, ch in ipairs(chars) do
		local row = UI:CreateListRow(charScroll.content, 162, 34, idx, function()
			PluribusMainFrame.bagChar = ch.name
			searchBox:SetText("")
			PluribusMainFrame:ShowTab(frame, "Bags & Bank")
		end)
		row:SetPoint("TOPLEFT", charScroll.content, "TOPLEFT", 0, cy)

		local cIcon = UI:CreateClassIcon(row, ch.class, 22)
		cIcon:SetPoint("LEFT", row, "LEFT", 5, 0)

		local _, _, _, hex = UI:GetClassColor(ch.class)
		local tag = (ch.group == "YOU" and "|cff38bdf8[You]|r ") or (ch.group == "ALT" and "|cff4ade80[Alt]|r ") or "|cfffbbf24[Guild]|r "
		local l1 = UI:CreateLabel(row, tag .. hex .. ch.name .. "|r")
		l1:SetPoint("TOPLEFT", cIcon, "TOPRIGHT", 6, -1)
		l1:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		if l1.SetWordWrap then l1:SetWordWrap(false) end

		local l2 = UI:CreateLabel(row, PluribusUtils:FormatGold(ch.gold or 0), 0.72, 0.80, 0.88, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", cIcon, "BOTTOMRIGHT", 6, 1)
		l2:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		if l2.SetWordWrap then l2:SetWordWrap(false) end

		if ch.name == self.bagChar then
			UI:ApplyBackdrop(row, 0.14, 0.34, 0.62, 0.95, 0.22, 0.74, 0.97, 1)
		end
		cy = cy - 36
	end
	charScroll.content:SetHeight(math.max(360, math.abs(cy) + 10))

	local gridCard = UI:CreateCard(p, 518, 404)
	gridCard:SetPoint("TOPLEFT", charCard, "TOPRIGHT", 8, 0)
	summaryLbl = UI:CreateLabel(gridCard, "", 0.86, 0.92, 0.98, "GameFontNormal")
	summaryLbl:SetPoint("TOPLEFT", gridCard, "TOPLEFT", 10, -9)
	summaryLbl:SetPoint("RIGHT", gridCard, "RIGHT", -10, 0)
	if summaryLbl.SetWordWrap then summaryLbl:SetWordWrap(false) end
	itemScroll = UI:CreateScrollFrame(gridCard, "PluribusHubBagsScroll", 498, 366)
	itemScroll:SetPoint("TOPLEFT", gridCard, "TOPLEFT", 10, -30)

	searchBox:SetScript("OnTextChanged", RenderBagGrid)
	RenderBagGrid()
end

-- ============================================================================
-- TAB 3: PROFESSIONS (Guild Recipes by Prof | Craft Profits | Shopping List | Surplus Mats)
-- ============================================================================
function PluribusMainFrame:ShowProfessionsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	local profs = _G.PluribusHiveProfessions
	if not profs then return end

	local function SwitchSub(mode)
		PluribusMainFrame.profSubTab = mode
		PluribusMainFrame:ShowTab(frame, "Professions")
	end

	local subCrafters = UI:CreateButton(p, L("PROF_GUILD_RECIPES"), 116, 26, function() SwitchSub("crafters") end)
	subCrafters:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	subCrafters:SetActiveState(self.profSubTab == "crafters")

	local subUnlearned = UI:CreateButton(p, L("PROF_UNLEARNED"), 126, 26, function() SwitchSub("unlearned") end)
	subUnlearned:SetPoint("LEFT", subCrafters, "RIGHT", 5, 0)
	subUnlearned:SetActiveState(self.profSubTab == "unlearned")

	local subProfit = UI:CreateButton(p, L("PROF_CRAFT_PROFITS"), 102, 26, function() SwitchSub("profit") end)
	subProfit:SetPoint("LEFT", subUnlearned, "RIGHT", 5, 0)
	subProfit:SetActiveState(self.profSubTab == "profit")

	local subShop = UI:CreateButton(p, L("PROF_TODO_LIST"), 144, 26, function() SwitchSub("wishlist") end)
	subShop:SetPoint("LEFT", subProfit, "RIGHT", 5, 0)
	subShop:SetActiveState(self.profSubTab == "wishlist")

	local subSurplus = UI:CreateButton(p, L("PROF_SURPLUS"), 104, 26, function() SwitchSub("surplus") end)
	subSurplus:SetPoint("LEFT", subShop, "RIGHT", 5, 0)
	subSurplus:SetActiveState(self.profSubTab == "surplus")

	local popoutBtn = UI:CreateButton(p, "Popout", 76, 26, function()
		if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.ToggleTodoPopout then
			_G.PluribusHiveProfessions:ToggleTodoPopout()
			PluribusMainFrame:ShowTab(frame, "Professions")
		end
	end, true)
	popoutBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local scroll = UI:CreateScrollFrame(p, "PluribusHubProfScroll", 724, 404)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
	local y = -4

	if self.profSubTab == "crafters" then
		y = profs:RenderGuildRecipesDirectory(scroll.content, 698, y, function()
			PluribusMainFrame:ShowTab(frame, "Professions")
		end)
	elseif self.profSubTab == "unlearned" then
		y = profs:RenderUnlearnedRecipes(scroll.content, 698, y, function()
			PluribusMainFrame:ShowTab(frame, "Professions")
		end)
	elseif self.profSubTab == "profit" then
		y = profs:RenderCraftProfits(scroll.content, 698, y)
	elseif self.profSubTab == "wishlist" then
		y = profs:RenderWishlistPicker(scroll.content, 698, y, function()
			PluribusMainFrame:ShowTab(frame, "Professions")
		end)
	else
		local matches = profs:GetMySurplusMatches() or {}
		for idx, m in ipairs(matches) do
			local row = UI:CreateListRow(scroll.content, 694, 40, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 32, {
				itemID = m.itemID, name = m.name, link = m.link, quality = m.quality, count = m.myCount, isSurplus = true,
			})
			slot:SetPoint("LEFT", row, "LEFT", 6, 0)

			local qCol = PluribusUtils:GetQualityColor(m.quality)
			local who = {}
			for _, nd in ipairs(m.neededBy) do
				table.insert(who, string.format("%s (%s %d)", nd.name, nd.prof, nd.level or 0))
			end
			local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff4ade80(You have x%d spare)|r", qCol, m.name, m.myCount))
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -1)
			l1:SetPoint("RIGHT", row, "RIGHT", -174, 0)
			if l1.SetWordWrap then l1:SetWordWrap(false) end
			local l2 = UI:CreateLabel(row, "Needed by: " .. table.concat(who, ", "), 0.72, 0.84, 0.94)
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 8, 1)
			l2:SetPoint("RIGHT", row, "RIGHT", -174, 0)
			if l2.SetWordWrap then l2:SetWordWrap(false) end

			local firstTarget = m.neededBy[1] and m.neededBy[1].name
			if firstTarget then
				local mailBtn = UI:CreateButton(row, "Write Letter", 86, 22, function()
					if _G.PluribusHiveMail then
						_G.PluribusHiveMail:OpenComposer(firstTarget, "Spare " .. m.name, "Hey! I have x" .. m.myCount .. " " .. m.name .. " spare for your " .. (m.neededBy[1].prof or "profession") .. ".", { itemID = m.itemID })
					end
				end)
				mailBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

				local offerBtn = UI:CreateButton(row, "Whisper", 68, 22, function()
					if SendChatMessage then
						pcall(SendChatMessage, string.format("Hey! I have x%d %s spare for your %s — want them?", m.myCount, m.link or m.name, m.neededBy[1].prof or "profession"), "WHISPER", nil, firstTarget)
					end
				end, true)
				offerBtn:SetPoint("RIGHT", mailBtn, "LEFT", -6, 0)
			end
			y = y - 42
		end
		if #matches == 0 then
			local empty = UI:CreateBannerCard(scroll.content, 694, 54, "Interface\\Icons\\INV_Misc_Bag_10_Green",
				"|cff4ade80No Surplus Matches Right Now|r",
				"As guildmates sync professions & shopping lists, any spare materials in your bags/bank appear here.",
				0.29, 0.87, 0.50)
			empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			y = y - 62
		end
	end

	scroll.content:SetHeight(math.max(380, math.abs(y) + 14))
end

-- ============================================================================
-- TAB 4: PLURIBUS GEARADVISOR (Cap Guardian, Stat Laboratory, Roadmap, Talents, XP Bar)
-- ============================================================================
function PluribusMainFrame:ShowGearJudgeTab(frame)
	local p = frame.contentFrame
	if _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.RenderPanel then
		_G.PluribusHiveGearJudge:RenderPanel(p, 728, 444, function()
			PluribusMainFrame:ShowTab(frame, "GearAdvisor")
		end)
	else
		local lbl = _G.PluribusUIFramework:CreateLabel(p, "GearAdvisor module is loading...", 0.85, 0.72, 0.35)
		lbl:SetPoint("CENTER")
	end
end

-- ============================================================================
-- TAB 5: GUILD MAIL (In-Addon Inbox / Sent + Write Letter & Addon Message Composer)
-- ============================================================================
function PluribusMainFrame:ShowGuildMailTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	local mail = _G.PluribusHiveMail
	if not mail then return end

	local unread = mail:GetUnreadCount()
	local banner = UI:CreateBannerCard(p, 728, 54, "Interface\\Icons\\INV_Letter_15",
		"|cfffbbf24Guild Mail & Craft Orders|r",
		string.format("%d unread in-addon messages · Offline messages queue and auto-deliver when peers come online.", unread),
		0.92, 0.72, 0.22, 184)
	banner:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)

	local composeBtn = UI:CreateButton(banner, "+ Write Message / Letter", 162, 26, function()
		mail:OpenComposer("", "", "")
	end, true)
	composeBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	local inboxBtn = UI:CreateButton(p, "Inbox (" .. #mail:GetInbox() .. ")", 118, 24, function()
		PluribusMainFrame.mailSubTab = "inbox"
		PluribusMainFrame:ShowTab(frame, "Guild Mail")
	end)
	inboxBtn:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)
	inboxBtn:SetActiveState(self.mailSubTab == "inbox")

	local sentBtn = UI:CreateButton(p, "Sent (" .. #mail:GetSent() .. ")", 118, 24, function()
		PluribusMainFrame.mailSubTab = "sent"
		PluribusMainFrame:ShowTab(frame, "Guild Mail")
	end)
	sentBtn:SetPoint("LEFT", inboxBtn, "RIGHT", 6, 0)
	sentBtn:SetActiveState(self.mailSubTab == "sent")

	local scroll = UI:CreateScrollFrame(p, "PluribusHubMailScroll", 726, 352)
	scroll:SetPoint("TOPLEFT", inboxBtn, "BOTTOMLEFT", 0, -8)

	local list = self.mailSubTab == "sent" and mail:GetSent() or mail:GetInbox()
	local y = -2
	for idx, msg in ipairs(list) do
		local row = UI:CreateListRow(scroll.content, 698, 54, idx, function()
			if PluribusMainFrame.mailSubTab == "inbox" and not msg.read then
				mail:MarkRead(msg.id)
				PluribusMainFrame:ShowTab(frame, "Guild Mail")
			end
		end)
		row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

		local iconPath = (msg.itemID and msg.itemID > 0 and PluribusUtils:GetItemIcon(msg.itemID))
			or (msg.read and "Interface\\Icons\\INV_Letter_15" or "Interface\\Icons\\INV_Letter_18")
		local badge = UI:CreateIconBadge(row, iconPath, 34, msg.read and 0.36 or 0.96, msg.read and 0.44 or 0.78, msg.read and 0.56 or 0.22)
		badge:SetPoint("LEFT", row, "LEFT", 6, 0)

		local peerTag = self.mailSubTab == "sent"
			and ("To: |cff38bdf8" .. tostring(msg.to) .. "|r  " .. (msg.delivered and "|cff4ade80[Delivered]|r" or "|cfffbbf24[Queued]|r"))
			or ((not msg.read and "|cfffbbf24[NEW]|r " or "") .. "From: |cff38bdf8" .. tostring(msg.from) .. "|r")
		local mailRightPad = (self.mailSubTab == "inbox") and -94 or -38
		local l1 = UI:CreateLabel(row, peerTag .. "  —  |cffffffff" .. tostring(msg.subject):sub(1, 34) .. "|r")
		l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -2)
		l1:SetPoint("RIGHT", row, "RIGHT", mailRightPad, 0)
		if l1.SetWordWrap then l1:SetWordWrap(false) end

		local l2 = UI:CreateLabel(row, tostring(msg.body or ""), 0.74, 0.82, 0.90, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 2)
		l2:SetPoint("RIGHT", row, "RIGHT", mailRightPad, 0)
		if l2.SetWordWrap then l2:SetWordWrap(false) end

		local delBtn = UI:CreateButton(row, "X", 24, 20, function()
			mail:DeleteMessage(msg.id, PluribusMainFrame.mailSubTab == "sent")
			PluribusMainFrame:ShowTab(frame, "Guild Mail")
		end)
		delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

		if self.mailSubTab == "inbox" then
			local replyBtn = UI:CreateButton(row, "Reply", 54, 20, function()
				mail:MarkRead(msg.id)
				mail:OpenComposer(msg.from, "Re: " .. tostring(msg.subject), "")
			end, true)
			replyBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
		end

		y = y - 56
	end

	if #list == 0 then
		local em = UI:CreateLabel(scroll.content, self.mailSubTab == "sent" and "No sent guild messages yet." or "Your Guild Mail inbox is empty. Click '+ Write Message / Letter' above or message any crafter directly!", 0.68, 0.78, 0.88)
		em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
	end
	scroll.content:SetHeight(math.max(330, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 5: GUILD TAX (Treasury Vault, Auto-Tracking, Mail Banker & Officer Policy)
-- ============================================================================
function PluribusMainFrame:ShowGuildTaxTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	local tax = _G.PluribusHiveTax
	if not tax then return end

	local pol = tax:GetPolicy()
	local myRec = tax:GetMyRecord()
	local myDue = tax:GetBalanceDue(myRec)
	local ledger, totals = tax:GetGuildLedger()

	-- Graphical Treasury Vault Banner
	local statusTxt = pol.enabled
		and string.format("Rate: |cfffbbf24%d%%|r  ·  Banker: |cff38bdf8%s|r  ·  Guild Collected: |cff4ade80%s|r  ·  Total Due: |cfff87171%s|r",
			pol.ratePct or 0,
			pol.bankerName ~= "" and pol.bankerName or "Not Set",
			PluribusUtils:FormatGold(totals.totalPaid),
			PluribusUtils:FormatGold(totals.totalDue))
		or "Guild Tax is currently paused. Configure rate & banker under Tax Policy."

	local banner = UI:CreateBannerCard(p, 728, 56, "Interface\\Icons\\INV_Misc_Coin_02",
		"|cfffbbf24Guild Treasury & Tax Vault|r", statusTxt, 0.92, 0.72, 0.22, 178)
	banner:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)

	local payBtn = UI:CreateButton(banner, myDue > 0 and ("Mail Tax (" .. PluribusUtils:FormatGold(myDue) .. ")") or "All Paid!", 156, 26, function()
		tax:MailTaxToBanker()
	end, myDue > 0)
	payBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	-- Personal Tax Progress Bar Strip
	local myPct = (myRec.taxAccrued or 0) > 0 and math.min(100, math.floor(((myRec.taxPaid or 0) / myRec.taxAccrued) * 100 + 0.5)) or 100
	local myBar = UI:CreateStatusBar(p, 560, 24, myDue > 0 and 0.92 or 0.22, myDue > 0 and 0.64 or 0.78, myDue > 0 and 0.16 or 0.44)
	myBar:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)
	myBar:SetBarData(myPct,
		string.format("Your Tax: Paid %s / Accrued %s", PluribusUtils:FormatGold(myRec.taxPaid or 0), PluribusUtils:FormatGold(myRec.taxAccrued or 0)),
		string.format("Owed: %s (%d%%)", PluribusUtils:FormatGold(myDue), myPct))

	local logPayBtn = UI:CreateButton(p, "Mark Paid", 80, 24, function()
		if myDue > 0 then
			tax:RecordPayment(myDue, "Manual Vault Deposit")
			PluribusMainFrame:ShowTab(frame, "Guild Tax")
		else
			UI:ShowNotification("|cff4ade80Your guild tax balance is already 0g!|r", 2.5)
		end
	end, true)
	logPayBtn:SetPoint("LEFT", myBar, "RIGHT", 8, 0)

	local testBtn = UI:CreateButton(p, "+10g Loot", 72, 24, function()
		tax:RecordTaxableIncome(100000, "Manual Entry")
		PluribusMainFrame:ShowTab(frame, "Guild Tax")
	end)
	testBtn:SetPoint("LEFT", logPayBtn, "RIGHT", 6, 0)

	-- Sub-tabs: Guild Ledger | Tax Policy & Rate | My History
	local subLedger = UI:CreateButton(p, "Guild Tax Ledger (" .. #ledger .. ")", 164, 24, function()
		PluribusMainFrame.taxSubTab = "ledger"
		PluribusMainFrame:ShowTab(frame, "Guild Tax")
	end)
	subLedger:SetPoint("TOPLEFT", myBar, "BOTTOMLEFT", 0, -8)
	subLedger:SetActiveState(self.taxSubTab == "ledger")

	local subPolicy = UI:CreateButton(p, "Tax Policy & Rate", 142, 24, function()
		PluribusMainFrame.taxSubTab = "policy"
		PluribusMainFrame:ShowTab(frame, "Guild Tax")
	end)
	subPolicy:SetPoint("LEFT", subLedger, "RIGHT", 6, 0)
	subPolicy:SetActiveState(self.taxSubTab == "policy")

	local subHist = UI:CreateButton(p, "My Tax History", 124, 24, function()
		PluribusMainFrame.taxSubTab = "history"
		PluribusMainFrame:ShowTab(frame, "Guild Tax")
	end)
	subHist:SetPoint("LEFT", subPolicy, "RIGHT", 6, 0)
	subHist:SetActiveState(self.taxSubTab == "history")

	local scroll = UI:CreateScrollFrame(p, "PluribusHubTaxScroll", 726, 314)
	scroll:SetPoint("TOPLEFT", subLedger, "BOTTOMLEFT", 0, -8)
	local y = -2

	if self.taxSubTab == "ledger" then
		for idx, r in ipairs(ledger) do
			local row = UI:CreateListRow(scroll.content, 698, 36, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local cIcon = UI:CreateClassIcon(row, r.class, 24)
			cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

			local _, _, _, hex = UI:GetClassColor(r.class)
			local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff94a3b8Paid: %s / Accrued: %s|r",
				hex, r.name, PluribusUtils:FormatGold(r.taxPaid), PluribusUtils:FormatGold(r.taxAccrued)))
			l1:SetPoint("LEFT", cIcon, "RIGHT", 8, 0)

			local dueTxt = r.balanceDue > 0
				and ("|cfff87171Owed: " .. PluribusUtils:FormatGold(r.balanceDue) .. "|r")
				or "|cff4ade80Paid 100%|r"
			local dueLbl = UI:CreateLabel(row, dueTxt)
			dueLbl:SetPoint("RIGHT", row, "RIGHT", r.isSelf and -10 or -84, 0)

			if not r.isSelf and r.balanceDue > 0 then
				local remBtn = UI:CreateButton(row, "Remind", 66, 20, function()
					if _G.PluribusHiveMail then
						_G.PluribusHiveMail:OpenComposer(r.name, "Guild Tax Reminder",
							string.format("Friendly guild reminder: your current guild tax balance is %s (Banker: %s).", PluribusUtils:FormatGold(r.balanceDue), pol.bankerName ~= "" and pol.bankerName or "Guild Bank"))
					end
				end)
				remBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			end
			y = y - 38
		end
	elseif self.taxSubTab == "policy" then
		local rateCard = UI:CreateCard(scroll.content, 696, 62, "Guild Tax Rate (% of Loot, Quest & AH Gold)")
		rateCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		for i, pct in ipairs({ 0, 5, 10, 15, 20 }) do
			local b = UI:CreateButton(rateCard, pct .. "%", 68, 24, function()
				tax:UpdatePolicy({ enabled = pct > 0, ratePct = pct }, true)
				PluribusMainFrame:ShowTab(frame, "Guild Tax")
			end, pol.ratePct == pct and (pct == 0 or pol.enabled))
			b:SetPoint("TOPLEFT", rateCard, "TOPLEFT", 12 + (i - 1) * 76, -28)
		end
		y = y - 70

		local bankCard = UI:CreateCard(scroll.content, 696, 60, "Guild Banker Character (Auto-Detects Mailed & Traded Tax Payments)")
		bankCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		local bBox = UI:CreateInputBox(bankCard, 220, 24)
		bBox:SetPoint("TOPLEFT", bankCard, "TOPLEFT", 12, -28)
		bBox:SetText(pol.bankerName or "")
		local saveBanker = UI:CreateButton(bankCard, "Save & Sync Policy to Guild", 196, 24, function()
			tax:UpdatePolicy({ bankerName = bBox:GetText() }, true)
			UI:ShowNotification("|cff4ade80Synced Guild Tax policy to guild!|r", 3)
			PluribusMainFrame:ShowTab(frame, "Guild Tax")
		end, true)
		saveBanker:SetPoint("LEFT", bBox, "RIGHT", 10, 0)
		y = y - 68

		local cb1 = UI:CreateCheckbox(scroll.content, "Loot-Gold automatisch besteuern (CHAT_MSG_MONEY + Loot-Delta)", pol.taxLootGold == true, function(v)
			tax:UpdatePolicy({ taxLootGold = v }, true)
		end)
		cb1:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 30

		local cb2 = UI:CreateCheckbox(scroll.content, "Quest-Gold automatisch besteuern (QUEST_TURNED_IN + Quest-Belohnung)", pol.taxQuestGold == true, function(v)
			tax:UpdatePolicy({ taxQuestGold = v }, true)
		end)
		cb2:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 30

		local cb3 = UI:CreateCheckbox(scroll.content, "AH-Verkäufe automatisch besteuern (Auktionshaus-Post / Einkommen)", pol.taxAuctionSales == true, function(v)
			tax:UpdatePolicy({ taxAuctionSales = v }, true)
		end)
		cb3:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 30

		local cb4 = UI:CreateCheckbox(scroll.content, "Händler-Verkäufe automatisch besteuern (Vendor / Merchant)", pol.taxVendorSales == true, function(v)
			tax:UpdatePolicy({ taxVendorSales = v }, true)
		end)
		cb4:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 34
	else
		local db = PluribusHive:GetDB()
		local hist = (db.tax and db.tax.history) or {}
		for idx, h in ipairs(hist) do
			local row = UI:CreateListRow(scroll.content, 698, 28, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local tag = h.kind == "PAID" and "|cff4ade80[PAID]|r " or "|cfffbbf24[TAX]|r "
			local l1 = UI:CreateLabel(row, tag .. PluribusUtils:FormatGold(h.copper or 0) .. "  —  " .. tostring(h.note or ""))
			l1:SetPoint("LEFT", row, "LEFT", 8, 0)
			y = y - 30
		end
		if #hist == 0 then
			local em = UI:CreateLabel(scroll.content, "No tax entries recorded yet. Loot gold or turn in quests to see automatic tracking!", 0.68, 0.78, 0.88)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
		end
	end

	scroll.content:SetHeight(math.max(290, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 7: NAV & GUIDES (Compass Arrow HUD + Distributed Hive Compute Guides)
-- ============================================================================
function PluribusMainFrame:ShowNavigationTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local function SwitchNav(mode)
		PluribusMainFrame.navSubTab = mode
		PluribusMainFrame:ShowTab(frame, "Nav & Guides")
	end

	local bCompass = UI:CreateButton(p, "Compass & Waypoints", 168, 26, function() SwitchNav("compass") end)
	bCompass:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -10)
	bCompass:SetActiveState(self.navSubTab ~= "guides")

	local bGuides = UI:CreateButton(p, "Hive Compute Guides (Leveling & Farming)", 272, 26, function() SwitchNav("guides") end)
	bGuides:SetPoint("LEFT", bCompass, "RIGHT", 6, 0)
	bGuides:SetActiveState(self.navSubTab == "guides")

	local holder = CreateFrame("Frame", nil, p)
	holder:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
	holder:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

	if self.navSubTab == "guides" then
		if _G.PluribusHiveCompute and _G.PluribusHiveCompute.RenderPanel then
			_G.PluribusHiveCompute:RenderPanel(holder, 728, 404, function()
				PluribusMainFrame:ShowTab(frame, "Nav & Guides")
			end)
		else
			local lbl = UI:CreateLabel(holder, "Hive Compute Engine is loading...", 0.85, 0.72, 0.35)
			lbl:SetPoint("CENTER")
		end
	else
		if _G.PluribusNavigationUI and _G.PluribusNavigationUI.RenderEmbedded then
			_G.PluribusNavigationUI:RenderEmbedded(holder, 728, 404, function()
				PluribusMainFrame:ShowTab(frame, "Nav & Guides")
			end)
		else
			local lbl = UI:CreateLabel(holder, "Enable PluribusNavigation addon in your WoW AddOns list to use Compass Navigation.", 0.85, 0.72, 0.35)
			lbl:SetPoint("CENTER")
		end
	end
end

-- ============================================================================
-- TAB 7: MARKET & TOOLS (AH Prices & P2P DB | Raid Cooldowns | All 27 Suite Addons)
-- ============================================================================
function PluribusMainFrame:ShowMarketToolsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local function SwitchTool(mode)
		PluribusMainFrame.toolsSubTab = mode
		PluribusMainFrame:ShowTab(frame, "Market & Tools")
	end

	local bMarket = UI:CreateButton(p, "AH Market & P2P DB", 156, 26, function() SwitchTool("market") end)
	bMarket:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	bMarket:SetActiveState(self.toolsSubTab == "market")

	local bCd = UI:CreateButton(p, "Raid Cooldowns", 136, 26, function() SwitchTool("cooldowns") end)
	bCd:SetPoint("LEFT", bMarket, "RIGHT", 6, 0)
	bCd:SetActiveState(self.toolsSubTab == "cooldowns")

	local bMods = UI:CreateButton(p, "All 27 Suite Addons", 150, 26, function() SwitchTool("modules") end)
	bMods:SetPoint("LEFT", bCd, "RIGHT", 6, 0)
	bMods:SetActiveState(self.toolsSubTab == "modules")

	if self.toolsSubTab ~= "market" and _G.PluribusHiveAuction and _G.PluribusHiveAuction.CancelMarketQuery then
		_G.PluribusHiveAuction:CancelMarketQuery("mainFrame")
	end

	if self.toolsSubTab == "cooldowns" then
		local cdMod = _G.PluribusHiveCooldowns
		local rtMod = _G.PluribusHiveRaidTools

		-- Top-right quick Raid Tools launch buttons
		local stripBtn = UI:CreateButton(p, "Overlay An/Aus", 112, 26, function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
		end, true)
		stripBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

		local rcBtn = UI:CreateButton(p, L("RAID_READY_BTN"), 94, 26, function()
			if rtMod and rtMod.OpenReadyCheckWindow then rtMod:OpenReadyCheckWindow(true) end
		end)
		rcBtn:SetPoint("RIGHT", stripBtn, "LEFT", -6, 0)

		local barBtn = UI:CreateButton(p, L("RAID_MARKER_BAR"), 92, 26, function()
			if rtMod and rtMod.ToggleMarkerBar then rtMod:ToggleMarkerBar() end
		end)
		barBtn:SetPoint("RIGHT", rcBtn, "LEFT", -6, 0)

		-- Second toolbar: Active vs On-Screen Selection Menu + Scope filter + Preview
		local subActive = UI:CreateButton(p, L("CD_SUB_ACTIVE"), 130, 22, function()
			PluribusMainFrame.cdSubTab = "active"
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		subActive:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -44)
		subActive:SetActiveState(self.cdSubTab ~= "config")

		local subCfg = UI:CreateButton(p, L("CD_SUB_CONFIG"), 156, 22, function()
			PluribusMainFrame.cdSubTab = "config"
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		subCfg:SetPoint("LEFT", subActive, "RIGHT", 6, 0)
		subCfg:SetActiveState(self.cdSubTab == "config")

		local curScope = (cdMod and cdMod.GetScope and cdMod:GetScope()) or "ALL"
		local scGroup = UI:CreateButton(p, L("CD_SCOPE_GROUP"), 108, 22, function()
			if cdMod then cdMod:SetScope("GROUP") end
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		scGroup:SetPoint("LEFT", subCfg, "RIGHT", 16, 0)
		scGroup:SetActiveState(curScope == "GROUP")

		local scGuild = UI:CreateButton(p, L("CD_SCOPE_GUILD"), 88, 22, function()
			if cdMod then cdMod:SetScope("GUILD") end
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		scGuild:SetPoint("LEFT", scGroup, "RIGHT", 4, 0)
		scGuild:SetActiveState(curScope == "GUILD")

		local scAll = UI:CreateButton(p, L("CD_SCOPE_ALL"), 52, 22, function()
			if cdMod then cdMod:SetScope("ALL") end
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		scAll:SetPoint("LEFT", scGuild, "RIGHT", 4, 0)
		scAll:SetActiveState(curScope == "ALL")

		local prevBtn = UI:CreateButton(p, L("CD_PREVIEW"), 92, 22, function()
			if cdMod and cdMod.TriggerPreviewCooldowns then cdMod:TriggerPreviewCooldowns() end
			PluribusMainFrame:ShowTab(frame, "Market & Tools")
		end)
		prevBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -44)

		if self.cdSubTab == "config" and cdMod and cdMod.CATALOG then
			-- Preset bar
			local pLbl = UI:CreateLabel(p, "|cff94a3b8Vorlagen:|r", 0.72, 0.80, 0.90, "GameFontHighlightSmall")
			pLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -74)

			local presets = {
				{ id = "RAID",      label = "Raid-Standard" },
				{ id = "TANK_HEAL", label = "Tank & Heiler" },
				{ id = "ALL",       label = "Alle an" },
				{ id = "NONE",      label = "Alle aus" },
			}
			local px = 76
			for _, pr in ipairs(presets) do
				local pb = UI:CreateButton(p, pr.label, 98, 20, function()
					cdMod:ApplyPreset(pr.id)
					PluribusMainFrame:ShowTab(frame, "Market & Tools")
				end)
				pb:SetPoint("TOPLEFT", p, "TOPLEFT", px, -70)
				px = px + 104
			end

			local selectedCount = 0
			for _, item in ipairs(cdMod.CATALOG) do
				if cdMod:IsSpellSelected(item.key) then selectedCount = selectedCount + 1 end
			end
			local cntLbl = UI:CreateLabel(p, string.format("|cff38bdf8%d / %d aktiv On-Screen|r", selectedCount, #cdMod.CATALOG), 1, 1, 1, "GameFontHighlightSmall")
			cntLbl:SetPoint("TOPRIGHT", p, "TOPRIGHT", -18, -74)

			local scroll = UI:CreateScrollFrame(p, "PluribusHubCDConfigScroll", 724, 348)
			scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -96)

			local catOrder = {
				{ id = "BREZ",      title = "Battle Rez & Raid-Rettung" },
				{ id = "DEFENSIVE", title = "Tank & Defensive Cooldowns" },
				{ id = "UTILITY",   title = "Heiler & Raid-Utility" },
				{ id = "OFFENSIVE", title = "Offensive Raid-Cooldowns" },
				{ id = "INTERRUPT", title = "Unterbrechungen & CC" },
			}

			local y = -4
			for _, cat in ipairs(catOrder) do
				local catItems = {}
				for _, item in ipairs(cdMod.CATALOG) do
					if item.category == cat.id then table.insert(catItems, item) end
				end
				if #catItems > 0 then
					local hdr = UI:CreateLabel(scroll.content, "|cfffbbf24" .. cat.title .. "|r", nil, nil, nil, "GameFontNormal")
					hdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
					y = y - 22

					local rows = math.ceil(#catItems / 2)
					for idx, item in ipairs(catItems) do
						local col = (idx - 1) % 2
						local rowIdx = math.floor((idx - 1) / 2)
						local rx = col * 348
						local ry = y - rowIdx * 28

						local _, _, _, hex = UI:GetClassColor(item.class)
						local disp = cdMod:GetDisplayName(item)
						local cdText = PluribusUtils:FormatTime(item.cd)
						local lblText = string.format("%s%s|r |cff94a3b8(%s)|r", hex, disp, cdText)
						local isOn = cdMod:IsSpellSelected(item.key)

						local cb = UI:CreateCheckbox(scroll.content, lblText, isOn, function(checked)
							cdMod:SetSpellSelected(item.key, checked)
							local n = 0
							for _, it in ipairs(cdMod.CATALOG) do
								if cdMod:IsSpellSelected(it.key) then n = n + 1 end
							end
							cntLbl:SetText(string.format("|cff38bdf8%d / %d aktiv On-Screen|r", n, #cdMod.CATALOG))
						end)
						cb:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", rx + 4, ry)
					end
					y = y - rows * 28 - 8
				end
			end
			scroll.content:SetHeight(math.max(336, math.abs(y) + 12))
		else
			local scroll = UI:CreateScrollFrame(p, "PluribusHubCDScroll", 724, 372)
			scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -74)
			local active = (cdMod and cdMod:GetActiveCooldowns()) or {}
			local y = -4
			for _, cd in ipairs(active) do
				local r, g, b = UI:GetClassColor(cd.class)
				local bar = UI:CreateStatusBar(scroll.content, 696, 24, r, g, b)
				bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
				local pct = math.max(0, math.min(100, (cd.remaining / math.max(1, cd.duration)) * 100))
				local est = cd.estimated and " |cff94a3b8[Est]|r" or " |cff4ade80[Exact]|r"
				bar:SetBarData(pct, string.format("[%s] %s — %s%s", cd.category, cd.player, cd.name, est), PluribusUtils:FormatTime(cd.remaining), r, g, b)
				y = y - 28
			end
			if #active == 0 then
				local em = UI:CreateBannerCard(scroll.content, 694, 58, "Interface\\Icons\\Spell_Holy_BorrowedTime",
					"|cff4ade80Alle ausgewählten Gilden- & Raid-Cooldowns sind bereit|r",
					"Klicke oben auf 'On-Screen Auswahl-Menü', um genau festzulegen welche Fähigkeiten angezeigt werden, oder 'Test-Vorschau'.",
					0.29, 0.87, 0.50)
				em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			end
			scroll.content:SetHeight(math.max(350, math.abs(y) + 12))
		end
	elseif self.toolsSubTab == "modules" then
		local scroll = UI:CreateScrollFrame(p, "PluribusHubModulesScroll", 724, 402)
		scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)
		local addons = (_G.PluribusAddonManager and _G.PluribusAddonManager.GetAllAddons) and _G.PluribusAddonManager:GetAllAddons() or {}
		table.sort(addons, function(a, b) return (a.name or "") < (b.name or "") end)
		local y = -2
		for idx, addon in ipairs(addons) do
			local isEnabled = addon.enabled == true
			local row = UI:CreateListRow(scroll.content, 696, 28, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local badge = isEnabled and "|cff4ade80ON|r " or "|cfff87171OFF|r"
			local lbl = UI:CreateLabel(row, badge .. "  |cffffffff" .. addon.name .. "|r  |cff94a3b8v" .. tostring(addon.version or "1.0") .. "|r")
			lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
			local toggleBtn = UI:CreateButton(row, isEnabled and "Disable" or "Enable", 74, 22, function()
				if _G.PluribusAddonManager then
					_G.PluribusAddonManager:SetAddonEnabled(addon.name, not isEnabled)
					PluribusMainFrame:ShowTab(frame, "Market & Tools")
				end
			end)
			toggleBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			local openBtn = UI:CreateButton(row, "Open", 64, 22, function()
				PluribusMainFrame:LaunchAddon(addon.name)
			end, true)
			openBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -6, 0)
			y = y - 30
		end
		scroll.content:SetHeight(math.max(380, math.abs(y) + 12))
	else
		-- Persistent, preserved Market & P2P DB panel with TRUE Windowed Virtual Scrolling:
		-- Lazily instantiates ONLY the <=8 rows visible in the viewport (even across 15,000+ AH items),
		-- defers live GetItemInfo hydration during rapid scrollbar drags, and skips redundant row updates.
		local JUMP_STEP = 25
		local mp = frame._plbMarketPanel
		if not mp then
			mp = CreateFrame("Frame", nil, p)
			mp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
			mp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
			mp._plbPreserve = true
			frame._plbMarketPanel = mp

			local banner = UI:CreateBannerCard(mp, 724, 52, "Interface\\Icons\\INV_Misc_Coin_02",
				"|cfffbbf24" .. L("MARKET_AH_TITLE") .. "|r",
				"",
				0.92, 0.72, 0.22)
			banner:SetPoint("TOPLEFT", mp, "TOPLEFT", 14, -4)
			mp._banner = banner

			local sLbl = UI:CreateLabel(mp, "|cfffbbf24" .. L("SEARCH") .. "|r", 1, 1, 1)
			sLbl:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 2, -11)
			mp._searchLbl = sLbl

			local searchBox = UI:CreateInputBox(mp, 224, 24)
			searchBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
			mp._searchBox = searchBox

			mp._currentResults = {}
			mp._totalCached = 0
			mp._isIndexing = false
			mp._scannedCount = 0
			mp._visibleRecords = {}
			mp._pendingVisibleItemIDs = {}

			local topBtn, prevJumpBtn, nextJumpBtn, bottomBtn, rangeInfoLbl

			local function ApplyRowItemMetadata(row, pr, isFastScroll)
				local liveName, liveLink, liveQuality, liveIcon = nil, nil, nil, nil
				if not isFastScroll then
					liveName, liveLink, liveQuality, _, _, _, _, _, _, liveIcon = PluribusUtils:GetItemInfo(pr.itemID)
					if not liveName then
						mp._pendingVisibleItemIDs[pr.itemID] = true
					else
						mp._pendingVisibleItemIDs[pr.itemID] = nil
					end
				end

				local displayName = liveName or pr.name or (pr.info and pr.info.name) or ("Item #" .. tostring(pr.itemID))
				local quality = liveQuality or pr.quality or (pr.info and pr.info.quality) or 1
				if pr.info then
					if liveName and liveName ~= "" and not pr.info.name then pr.info.name = liveName end
					if liveQuality ~= nil and pr.info.quality == nil then pr.info.quality = liveQuality end
				end

				local iconTex = liveIcon
					or (not isFastScroll and PluribusUtils and PluribusUtils:GetItemIcon(pr.itemID))
					or (pr.info and pr.info._cachedIcon)
					or "Interface\\Icons\\INV_Misc_QuestionMark"
				if liveIcon and pr.info then
					pr.info._cachedIcon = liveIcon
				end

				row._slot.icon:SetTexture(iconTex)
				local qr, qg, qb = 0.30, 0.38, 0.50
				if (quality >= 2 or quality == 0) and PluribusUtils and PluribusUtils.GetQualityRGB then
					qr, qg, qb = PluribusUtils:GetQualityRGB(quality)
				end
				if row._slot.SetBackdropBorderColor then
					row._slot:SetBackdropBorderColor(qr, qg, qb, quality >= 2 and 0.95 or 0.72)
				end
				row._slot._itemData = { itemID = pr.itemID, name = displayName, link = liveLink, quality = quality }
				row._itemID = pr.itemID
				row._itemName = displayName
				row._boundResolved = (liveName ~= nil)

				local qCol = PluribusUtils:GetQualityColor(quality)
				row._nameLbl:SetText(qCol .. displayName:sub(1, 34) .. "|r")
			end

			local function CreateMarketVirtualRow(viewport, slotIdx, rowW, rowH)
				local row = UI:CreateListRow(viewport, rowW, rowH, slotIdx)

				local slot = CreateFrame("Button", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
				slot:SetSize(26, 26)
				slot:SetPoint("LEFT", row, "LEFT", 6, 0)
				UI:ApplyBackdrop(slot, 0.05, 0.07, 0.11, 0.96, 0.30, 0.38, 0.50, 0.75)

				local icon = slot:CreateTexture(nil, "ARTWORK")
				icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
				icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
				icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				slot.icon = icon

				local hl = slot:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints(icon)
				hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
				hl:SetBlendMode("ADD")
				hl:SetAlpha(0.45)

				slot:SetScript("OnEnter", function(selfSlot)
					if not GameTooltip then return end
					local d = selfSlot._itemData
					if not d then return end
					GameTooltip:SetOwner(selfSlot, "ANCHOR_RIGHT")
					local ok = _G.PluribusUtils and _G.PluribusUtils:SetTooltipItem(GameTooltip, d.itemID, d.link)
					if not ok then
						GameTooltip:AddLine(d.name or ("Item #" .. tostring(d.itemID or "?")), 1, 1, 1)
					end
					GameTooltip:Show()
				end)
				slot:SetScript("OnLeave", function()
					if GameTooltip then GameTooltip:Hide() end
				end)

				local nameLbl = UI:CreateLabel(row, "")
				nameLbl:SetPoint("LEFT", slot, "RIGHT", 8, 0)

				local todoBtn = UI:CreateButton(row, L("PROF_ADD_TODO"), 56, 20, function()
					if row._itemID and _G.PluribusHiveProfessions then
						_G.PluribusHiveProfessions:AddNeededMaterial(row._itemID, 10)
					end
				end)
				todoBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

				local ahBtn = UI:CreateButton(row, L("MARKET_SEARCH_IN_AH"), 84, 20, function()
					if row._itemName and _G.PluribusHiveAuction and _G.PluribusHiveAuction.SearchNativeAH then
						_G.PluribusHiveAuction:SearchNativeAH(row._itemName)
					end
				end, true)
				ahBtn:SetPoint("RIGHT", todoBtn, "LEFT", -4, 0)

				local priceLbl = UI:CreateLabel(row, "")
				priceLbl:SetPoint("RIGHT", ahBtn, "LEFT", -10, 0)

				row._slot = slot
				row._nameLbl = nameLbl
				row._priceLbl = priceLbl
				row:Hide()
				return row
			end

			local emptyLbl
			local vlist

			local function UpdateFooterControls(offset, firstIdx, lastIdx, totalMatches)
				PluribusMainFrame.ahScrollOffset = offset or 0
				local maxOffset = math.max(0, (totalMatches or 0) - (vlist and vlist:GetVisibleCount() or 8))

				if (totalMatches or 0) == 0 then
					mp._pendingVisibleItemIDs = {}
					mp._visibleRecords = {}
					if mp._isIndexing then
						emptyLbl:SetText("|cff38bdf8Indexiere AH-Datenbank...|r")
					else
						emptyLbl:SetText((mp._totalCached or 0) > 0 and L("MARKET_NO_MATCHES") or L("MARKET_EMPTY"))
					end
					emptyLbl:Show()
				else
					emptyLbl:Hide()
				end

				if mp._isIndexing then
					rangeInfoLbl:SetText(string.format("|cff38bdf8Indexiere... (%d gescannt)|r", mp._scannedCount or 0))
				elseif (totalMatches or 0) > 0 then
					rangeInfoLbl:SetText(string.format("Zeige %d–%d  |cff94a3b8von %d %s (Mausrad / Balken)|r",
						firstIdx or 1, lastIdx or 1, totalMatches, totalMatches == 1 and "Item" or "Items"))
				else
					rangeInfoLbl:SetText("|cff94a3b80 Items|r")
				end

				local canUp = (not mp._isIndexing) and (offset or 0) > 0
				local canDown = (not mp._isIndexing) and (offset or 0) < maxOffset
				for _, b in ipairs({ topBtn, prevJumpBtn }) do
					if b then
						if b.SetEnabled then b:SetEnabled(canUp) end
						b:SetAlpha(canUp and 1 or 0.42)
					end
				end
				for _, b in ipairs({ nextJumpBtn, bottomBtn }) do
					if b then
						if b.SetEnabled then b:SetEnabled(canDown) end
						b:SetAlpha(canDown and 1 or 0.42)
					end
				end
			end

			vlist = UI:CreateVirtualScrollList(mp, {
				width = 724,
				height = 290,
				rowHeight = 34,
				rowGap = 2,
				wheelStep = 3,
				shiftWheelStep = 12,
				createRow = CreateMarketVirtualRow,
				bindRow = function(row, pr, dataIdx, slotIdx, isFastScroll)
					if slotIdx == 1 then
						mp._pendingVisibleItemIDs = {}
						mp._visibleRecords = {}
					end
					mp._visibleRecords[slotIdx] = pr

					local copperVal = pr.copper or 0
					local repStr = tostring(pr.reporter or "?")
					local sameItem = (row._boundItemID == pr.itemID and row._boundCopper == copperVal and row._boundReporter == repStr)
					if sameItem and (isFastScroll or row._boundResolved) then
						return
					end

					ApplyRowItemMetadata(row, pr, isFastScroll)
					if not sameItem then
						row._priceLbl:SetText("|cfffbbf24" .. PluribusUtils:FormatGold(copperVal) .. "|r  |cff94a3b8(" .. repStr .. ")|r")
						row._boundItemID = pr.itemID
						row._boundCopper = copperVal
						row._boundReporter = repStr
					end
				end,
				onScrollChanged = function(offset, firstIdx, lastIdx, totalMatches)
					UpdateFooterControls(offset, firstIdx, lastIdx, totalMatches)
				end,
			})
			vlist:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -36)
			mp._vlist = vlist
			mp._rowPool = vlist:GetRowPool()

			emptyLbl = UI:CreateLabel(vlist, "", 0.68, 0.78, 0.88)
			emptyLbl:SetPoint("TOPLEFT", vlist, "TOPLEFT", 8, -10)
			emptyLbl:Hide()
			mp._emptyLbl = emptyLbl

			-- Compact virtual-scroll footer with live range indicator & quick jump buttons
			local footerBar = CreateFrame("Frame", nil, mp)
			footerBar:SetSize(724, 24)
			footerBar:SetPoint("TOPLEFT", vlist, "BOTTOMLEFT", 0, -4)

			topBtn = UI:CreateButton(footerBar, "<<", 32, 22, function()
				if not mp._isIndexing then vlist:ScrollToTop() end
			end)
			topBtn:SetPoint("LEFT", footerBar, "LEFT", 0, 0)

			prevJumpBtn = UI:CreateButton(footerBar, "-" .. JUMP_STEP, 44, 22, function()
				if not mp._isIndexing then vlist:ScrollBy(-JUMP_STEP, false) end
			end)
			prevJumpBtn:SetPoint("LEFT", topBtn, "RIGHT", 4, 0)

			bottomBtn = UI:CreateButton(footerBar, ">>", 32, 22, function()
				if not mp._isIndexing then vlist:ScrollToBottom() end
			end)
			bottomBtn:SetPoint("RIGHT", footerBar, "RIGHT", 0, 0)

			nextJumpBtn = UI:CreateButton(footerBar, "+" .. JUMP_STEP, 44, 22, function()
				if not mp._isIndexing then vlist:ScrollBy(JUMP_STEP, false) end
			end)
			nextJumpBtn:SetPoint("RIGHT", bottomBtn, "LEFT", -4, 0)

			rangeInfoLbl = UI:CreateLabel(footerBar, "", 0.72, 0.82, 0.94)
			rangeInfoLbl:SetPoint("CENTER", footerBar, "CENTER", 0, 0)

			function mp:_UpdateBanner()
				local stats = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB:GetStats()) or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }
				if self._banner and self._banner.titleLabel then
					self._banner.titleLabel:SetText("|cfffbbf24" .. L("MARKET_AH_TITLE") .. " (Rev v" .. tostring(stats.revision or 1) .. ")|r")
				end
				if self._banner and self._banner.subLabel then
					self._banner.subLabel:SetText(string.format("Cached: %d items, %d quests, %d NPCs · Virtual scroll + frame-budgeted AH scan.", stats.items or 0, stats.quests or 0, stats.npcs or 0))
				end
			end

			function mp:_RefreshVisibleRowsMetadata()
				local pool = vlist:GetRowPool()
				local shown = vlist:GetShownCount()
				for i = 1, shown do
					local row = pool[i]
					local pr = self._visibleRecords[i]
					if row and pr and row:IsShown() and self._pendingVisibleItemIDs[pr.itemID] then
						ApplyRowItemMetadata(row, pr, false)
					end
				end
			end

			function mp:_RequestData(preserveOffset)
				if not _G.PluribusHiveAuction or not _G.PluribusHiveAuction.QueryMarketPricesAsync then
					self._currentResults = {}
					self._totalCached = 0
					self._isIndexing = false
					vlist:SetData({}, false)
					return
				end
				_G.PluribusHiveAuction:QueryMarketPricesAsync({
					owner = "mainFrame",
					query = PluribusMainFrame.ahSearchQuery or "",
					sortMode = PluribusMainFrame.ahSortMode or "recent",
					budgetMs = 2.5,
					previewSize = vlist:GetVisibleCount(),
					onProgress = function(previewItems, scannedCount)
						if not mp:IsVisible() then return end
						mp._isIndexing = true
						mp._scannedCount = scannedCount or 0
						mp._totalCached = scannedCount or 0
						vlist:SetData(previewItems or {}, false)
					end,
					onComplete = function(sortedItems, totalCached)
						if not mp:IsVisible() then return end
						mp._currentResults = sortedItems or {}
						mp._totalCached = totalCached or 0
						mp._isIndexing = false
						vlist:SetData(mp._currentResults, preserveOffset == true)
						if preserveOffset and (PluribusMainFrame.ahScrollOffset or 0) > 0 then
							vlist:SetOffset(PluribusMainFrame.ahScrollOffset, false)
						end
					end,
				})
			end

			local sortRecentBtn, sortPriceBtn, sortNameBtn
			local function SyncSortButtons()
				local m = PluribusMainFrame.ahSortMode or "recent"
				sortRecentBtn:SetActiveState(m == "recent")
				sortPriceBtn:SetActiveState(m == "price")
				sortNameBtn:SetActiveState(m == "name")
			end
			mp._SyncSortButtons = SyncSortButtons

			local function SetSort(m)
				if PluribusMainFrame.ahSortMode == m and not mp._isIndexing then return end
				PluribusMainFrame.ahSortMode = m
				PluribusMainFrame.ahScrollOffset = 0
				SyncSortButtons()
				mp:_RequestData(false)
			end

			sortRecentBtn = UI:CreateButton(mp, L("MARKET_SORT_RECENT"), 68, 24, function() SetSort("recent") end)
			sortRecentBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

			sortPriceBtn = UI:CreateButton(mp, L("MARKET_SORT_PRICE"), 62, 24, function() SetSort("price") end)
			sortPriceBtn:SetPoint("LEFT", sortRecentBtn, "RIGHT", 4, 0)

			sortNameBtn = UI:CreateButton(mp, L("MARKET_SORT_NAME"), 62, 24, function() SetSort("name") end)
			sortNameBtn:SetPoint("LEFT", sortPriceBtn, "RIGHT", 4, 0)

			-- 0.20s search debounce so rapid typing never re-scans DB on every keystroke
			local searchDebounce = CreateFrame("Frame", nil, mp)
			searchDebounce:Hide()
			local debounceRem = 0
			searchDebounce:SetScript("OnUpdate", function(sf, elapsed)
				debounceRem = debounceRem - (elapsed or 0)
				if debounceRem <= 0 then
					sf:Hide()
					if mp:IsVisible() then
						mp:_RequestData(false)
					end
				end
			end)

			searchBox:SetScript("OnTextChanged", function(selfBox, isUserInput)
				if isUserInput == false then return end
				PluribusMainFrame.ahSearchQuery = selfBox:GetText() or ""
				PluribusMainFrame.ahScrollOffset = 0
				debounceRem = 0.20
				searchDebounce:Show()
			end)
		end

		if mp._searchBox and mp._searchBox:GetText() ~= (self.ahSearchQuery or "") then
			mp._searchBox:SetText(self.ahSearchQuery or "")
		end
		if mp._SyncSortButtons then mp._SyncSortButtons() end
		if mp._UpdateBanner then mp:_UpdateBanner() end
		mp:Show()
		mp:_RequestData(true)
	end
end

function PluribusMainFrame:ShowHealBotTab(frame)
	local content = frame.content
	local hd = _G.PluribusHealDecursive
	if hd and not hd.initialized and hd.Initialize then
		hd:Initialize()
	end
	if not hd then
		local err = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		err:SetPoint("TOPLEFT", 18, -24)
		err:SetText("|cfff87171HealBot-Engine nicht geladen. Bitte /reload ausführen.|r")
		return
	end

	local cfg = hd.config
	local activeSub = self.healSubTab or "clickcast"
	local cls = hd.GetPlayerClass and hd:GetPlayerClass() or "PRIEST"
	local gridVisible = (hd.gridFrame and hd.gridFrame:IsShown()) or false

	-- Header Status & Quick-Launch Banner
	local banner = UI:CreateCard(content, 720, 74)
	banner:SetPoint("TOPLEFT", 14, -12)

	local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -10)
	title:SetText("|cff38bdf8Pluribus HealBot + Decursive|r")

	local stateStr = cfg.enabled
		and (gridVisible and "|cff4ade80Live-Grid aktiv|r" or "|cfffbbf24Bereit (in Gruppe/Raid oder Solo aktivieren)|r")
		or "|cfff87171Deaktiviert|r"
	local modeStr = cfg.compactMUF and "Kompakt-MUF" or "HealBot + Cleanse"
	local sub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", 14, -30)
	sub:SetText(string.format("Status: %s  ·  Modus: |cff38bdf8%s|r  ·  Klasse: |cfffbbf24%s|r", stateStr, modeStr, cls))

	local hint = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 14, -48)
	hint:SetTextColor(0.58, 0.66, 0.76)
	hint:SetText("Befehle: /healbot, /hb, /healer, /decursive  ·  Ziehen am Grid-Rand zum Verschieben")

	local toggleGridBtn = UI:CreateButton(banner, (cfg.enabled and gridVisible) and "Grid ausblenden" or "Live-Grid zeigen", 132, 26, function()
		if cfg.enabled and gridVisible then
			cfg.enabled = false
		else
			cfg.enabled = true
			if not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then
				cfg.showSolo = true
			end
		end
		hd:SaveConfig()
		hd:RequestRebuild()
		PluribusMainFrame:ShowTab(frame, "HealBot")
	end)
	toggleGridBtn:SetPoint("TOPRIGHT", -12, -10)
	if cfg.enabled and gridVisible then
		toggleGridBtn:SetBackdropColor(0.10, 0.30, 0.22, 0.96)
		toggleGridBtn:SetBackdropBorderColor(0.24, 0.80, 0.48, 0.95)
	else
		toggleGridBtn:SetBackdropColor(0.10, 0.24, 0.38, 0.96)
		toggleGridBtn:SetBackdropBorderColor(0.22, 0.74, 0.98, 0.95)
	end

	local mufBtn = UI:CreateButton(banner, cfg.compactMUF and "Modus: MUF" or "Modus: HealBot", 112, 26, function()
		hd:ToggleCompactMUF()
		PluribusMainFrame:ShowTab(frame, "HealBot")
	end)
	mufBtn:SetPoint("RIGHT", toggleGridBtn, "LEFT", -6, 0)

	local soloBtn = UI:CreateButton(banner, cfg.showSolo and "Immer an (Solo): AN" or "Immer an (Solo): AUS", 136, 26, function()
		if hd.SetAlwaysShow then
			hd:SetAlwaysShow(not cfg.showSolo)
		else
			cfg.showSolo = not cfg.showSolo
			if cfg.showSolo then cfg.enabled = true end
			hd:SaveConfig()
			hd:RequestRebuild()
		end
		PluribusMainFrame:ShowTab(frame, "HealBot")
	end, cfg.showSolo == true)
	soloBtn:SetPoint("RIGHT", mufBtn, "LEFT", -6, 0)

	local resetBtn = UI:CreateButton(banner, "Standard", 76, 22, function()
		hd:ResetClassDefaults()
		UI:ShowNotification("Klassen-Standardzauber wiederhergestellt.", 2.0)
		PluribusMainFrame:ShowTab(frame, "HealBot")
	end)
	resetBtn:SetPoint("BOTTOMRIGHT", -12, 8)

	-- Sub-navigation strip
	local subTabs = {
		{ key = "clickcast", label = "Klick-Zauber" },
		{ key = "decursive", label = "Decursive & Auren" },
		{ key = "layout",    label = "Grid & Layout" },
		{ key = "preview",   label = "Vorschau" },
	}
	for i, st in ipairs(subTabs) do
		local b = UI:CreateButton(content, st.label, 146, 24, function()
			PluribusMainFrame.healSubTab = st.key
			PluribusMainFrame:ShowTab(frame, "HealBot")
		end)
		b:SetPoint("TOPLEFT", 14 + (i - 1) * 152, -94)
		if activeSub == st.key then
			b:SetBackdropColor(0.12, 0.28, 0.42, 0.96)
			b:SetBackdropBorderColor(0.22, 0.74, 0.98, 0.95)
		end
	end

	local body = UI:CreateCard(content, 720, 416)
	body:SetPoint("TOPLEFT", 14, -124)

	if activeSub == "clickcast" then
		local hdr = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hdr:SetPoint("TOPLEFT", 14, -12)
		hdr:SetText("|cff38bdf8HealBot Klick-Zauber-Belegung (Combat-Safe SecureUnitButton)|r")

		local desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		desc:SetPoint("TOPLEFT", 14, -30)
		desc:SetTextColor(0.66, 0.74, 0.84)
		desc:SetText("Zaubernamen exakt wie im Zauberbuch eintragen (automatisch passend zur Spielsprache vorbelegt).")

		local slots = {
			{ key = "Left-Click",   label = "Linksklick" },
			{ key = "Right-Click",  label = "Rechtsklick" },
			{ key = "Middle-Click", label = "Mittelklick" },
			{ key = "Shift+Left",   label = "Shift + Linksklick" },
			{ key = "Shift+Right",  label = "Shift + Rechtsklick" },
			{ key = "Ctrl+Left",    label = "Strg + Linksklick" },
			{ key = "Alt+Left",     label = "Alt + Linksklick" },
		}
		local boxes = {}
		for idx, s in ipairs(slots) do
			local y = -58 - (idx - 1) * 42
			local lbl = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			lbl:SetPoint("TOPLEFT", 18, y - 5)
			lbl:SetWidth(160)
			lbl:SetJustifyH("LEFT")
			lbl:SetText(s.label .. ":")

			local eb = UI:CreateEditBox(body, 290, 26, "Zaubername oder leer...")
			eb:SetPoint("TOPLEFT", 186, y)
			eb:SetText((cfg.bindings and cfg.bindings[s.key]) or "")
			boxes[s.key] = eb

			local clearB = UI:CreateButton(body, "Leeren", 66, 24, function()
				eb:SetText("")
			end)
			clearB:SetPoint("LEFT", eb, "RIGHT", 8, 0)
		end

		local saveBtn = UI:CreateButton(body, "Klick-Zauber speichern & anwenden", 240, 28, function()
			cfg.bindings = cfg.bindings or {}
			for _, s in ipairs(slots) do
				local txt = strtrim and strtrim(boxes[s.key]:GetText() or "") or (boxes[s.key]:GetText() or "")
				cfg.bindings[s.key] = txt
			end
			hd:SaveConfig()
			hd:RequestRebuild()
			UI:ShowNotification("HealBot Klick-Zauber gespeichert!", 2.0)
		end)
		saveBtn:SetPoint("BOTTOMLEFT", 18, 16)
		saveBtn:SetBackdropColor(0.10, 0.30, 0.22, 0.96)
		saveBtn:SetBackdropBorderColor(0.24, 0.80, 0.48, 0.95)

	elseif activeSub == "decursive" then
		local hdr = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hdr:SetPoint("TOPLEFT", 14, -12)
		hdr:SetText("|cff38bdf8Decursive Entzaubern & Raid-Auren|r")

		local lbl1 = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		lbl1:SetPoint("TOPLEFT", 18, -46)
		lbl1:SetText("Primärer Cleanse-Zauber (Ecke Linksklick):")
		local eb1 = UI:CreateEditBox(body, 260, 26, "z.B. Magiebannung / Fluch aufheben")
		eb1:SetPoint("TOPLEFT", 286, -42)
		eb1:SetText(cfg.cleansePrimary or "")

		local lbl2 = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		lbl2:SetPoint("TOPLEFT", 18, -82)
		lbl2:SetText("Sekundärer Cleanse-Zauber (Ecke Rechtsklick):")
		local eb2 = UI:CreateEditBox(body, 260, 26, "z.B. Krankheit / Vergiftung aufheben")
		eb2:SetPoint("TOPLEFT", 286, -78)
		eb2:SetText(cfg.cleanseSecondary or "")

		local saveCleanse = UI:CreateButton(body, "Cleanse-Zauber speichern", 180, 26, function()
			cfg.cleansePrimary = strtrim and strtrim(eb1:GetText() or "") or (eb1:GetText() or "")
			cfg.cleanseSecondary = strtrim and strtrim(eb2:GetText() or "") or (eb2:GetText() or "")
			hd:SaveConfig()
			hd:RequestRebuild()
			UI:ShowNotification("Decursive Cleanse-Zauber gespeichert!", 2.0)
		end)
		saveCleanse:SetPoint("TOPLEFT", 18, -116)

		local toggles = {
			{ key = "highlightDebuffs",  label = "Debuffs farbig hervorheben (Magie / Fluch / Gift / Krankheit)" },
			{ key = "onlyDispellable",   label = "Nur Debuffs anzeigen, die meine Klasse bannen kann" },
			{ key = "alertSound",        label = "Decursive-Warnton bei neuem bannbarem Debuff abspielen" },
			{ key = "showIncomingHeals", label = "Eingehende Heilungen (HealComm / IncomingHeal) anzeigen" },
			{ key = "showHoTTimers",     label = "Aktive HoT-Timer (Erneuerung, Verjüngung, Schild...) anzeigen" },
			{ key = "showAggro",         label = "Bedrohungs-/Aggro-Rahmen bei angegriffenen Spielern" },
			{ key = "fadeOutOfRange",    label = "Spieler außerhalb der Heilreichweite (40m) ausblassen" },
		}
		for i, t in ipairs(toggles) do
			local cb = UI:CreateCheckbox(body, t.label, cfg[t.key] == true, function(checked)
				cfg[t.key] = checked
				hd:SaveConfig()
				hd:RequestRebuild()
			end)
			cb:SetPoint("TOPLEFT", 18, -156 - (i - 1) * 32)
		end

	elseif activeSub == "layout" then
		local hdr = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hdr:SetPoint("TOPLEFT", 14, -12)
		hdr:SetText("|cff38bdf8Grid-Geometrie & Positionierung|r")

		local controls = {
			{ key = "columns",     label = "Spalten pro Zeile", step = 1,    min = 1,  max = 10, fmt = "%d" },
			{ key = "frameWidth",  label = "Kachel-Breite (px)", step = 8,   min = 76, max = 180, fmt = "%d px" },
			{ key = "frameHeight", label = "Kachel-Höhe (px)",   step = 4,   min = 28, max = 72, fmt = "%d px" },
			{ key = "scale",       label = "Skalierung",         step = 0.05,min = 0.7,max = 1.5, fmt = "%.2fx" },
		}
		for i, c in ipairs(controls) do
			local y = -52 - (i - 1) * 44
			local lbl = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			lbl:SetPoint("TOPLEFT", 18, y - 5)
			lbl:SetText(c.label .. ":")

			local valFS = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			valFS:SetPoint("TOPLEFT", 210, y - 5)
			valFS:SetText(string.format(c.fmt, cfg[c.key] or c.min))

			local minusBtn = UI:CreateButton(body, "-", 28, 24, function()
				local nv = math.max(c.min, (cfg[c.key] or c.min) - c.step)
				cfg[c.key] = math.floor(nv * 100 + 0.5) / 100
				hd:SaveConfig()
				hd:RequestRebuild()
				PluribusMainFrame:ShowTab(frame, "HealBot")
			end)
			minusBtn:SetPoint("TOPLEFT", 288, y)

			local plusBtn = UI:CreateButton(body, "+", 28, 24, function()
				local nv = math.min(c.max, (cfg[c.key] or c.min) + c.step)
				cfg[c.key] = math.floor(nv * 100 + 0.5) / 100
				hd:SaveConfig()
				hd:RequestRebuild()
				PluribusMainFrame:ShowTab(frame, "HealBot")
			end)
			plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 6, 0)
		end

		local lockCB = UI:CreateCheckbox(body, "Grid-Position sperren (verhindert versehentliches Verschieben)", cfg.locked == true, function(checked)
			cfg.locked = checked
			hd:SaveConfig()
			hd:RequestRebuild()
		end)
		lockCB:SetPoint("TOPLEFT", 18, -242)

		local centerBtn = UI:CreateButton(body, "Position zurücksetzen (Mitte)", 200, 28, function()
			cfg.point = { "CENTER", 0, -140 }
			cfg.enabled = true
			if not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then
				cfg.showSolo = true
			end
			hd:SaveConfig()
			hd:RequestRebuild()
			UI:ShowNotification("HealBot-Grid in der Bildschirmmitte positioniert.", 2.0)
			PluribusMainFrame:ShowTab(frame, "HealBot")
		end)
		centerBtn:SetPoint("TOPLEFT", 18, -286)

	else
		-- Visual 5-player preview card
		local hdr = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hdr:SetPoint("TOPLEFT", 14, -12)
		hdr:SetText("|cff38bdf8Live-Vorschau (5er-Gruppe · HealBot + Decursive)|r")

		local subP = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		subP:SetPoint("TOPLEFT", 14, -32)
		subP:SetTextColor(0.66, 0.74, 0.84)
		subP:SetText("Vorschau mit Aggro-Rand, eingehender Heilung, HoT-Timer, Decursive-Ecke und Reichweiten-Ausblassung:")

		local samples = {
			{ name = "Krieger (Tank)", pct = 0.62, inc = 0.22, r = 0.78, g = 0.61, b = 0.43, aggro = true,  hot = "R 9s", debuff = nil,     oor = false },
			{ name = "Priester (Du)",  pct = 0.94, inc = 0.00, r = 0.95, g = 0.95, b = 0.98, aggro = false, hot = "S",    debuff = nil,     oor = false },
			{ name = "Magier",         pct = 0.48, inc = 0.18, r = 0.41, g = 0.80, b = 0.94, aggro = false, hot = nil,    debuff = "Magic", oor = false },
			{ name = "Schurke",        pct = 0.75, inc = 0.00, r = 1.00, g = 0.96, b = 0.41, aggro = false, hot = "V 6s", debuff = "Poison",oor = false },
			{ name = "Jäger (45m)",    pct = 0.88, inc = 0.00, r = 0.67, g = 0.83, b = 0.45, aggro = false, hot = nil,    debuff = nil,     oor = true  },
		}

		for idx, s in ipairs(samples) do
			local tile = CreateFrame("Frame", nil, body, "BackdropTemplate")
			tile:SetSize(128, 52)
			tile:SetPoint("TOPLEFT", 18 + (idx - 1) * 136, -68)
			tile:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Buttons\\WHITE8x8",
				edgeSize = s.aggro and 2 or 1,
			})
			tile:SetBackdropColor(0.05, 0.07, 0.11, 0.96)
			if s.aggro then
				tile:SetBackdropBorderColor(0.96, 0.26, 0.26, 1)
			elseif s.debuff == "Magic" then
				tile:SetBackdropBorderColor(0.22, 0.74, 0.98, 1)
			elseif s.debuff == "Poison" then
				tile:SetBackdropBorderColor(0.24, 0.86, 0.44, 1)
			else
				tile:SetBackdropBorderColor(0.20, 0.28, 0.40, 0.9)
			end
			tile:SetAlpha(s.oor and 0.45 or 1.0)

			local hpBar = tile:CreateTexture(nil, "ARTWORK")
			hpBar:SetTexture("Interface\\Buttons\\WHITE8x8")
			hpBar:SetPoint("TOPLEFT", 2, -2)
			hpBar:SetPoint("BOTTOMLEFT", 2, 2)
			hpBar:SetWidth(math.max(4, math.floor(124 * s.pct)))
			hpBar:SetVertexColor(s.r * 0.65, s.g * 0.65, s.b * 0.65, 0.92)

			if s.inc > 0 then
				local incTex = tile:CreateTexture(nil, "ARTWORK")
				incTex:SetTexture("Interface\\Buttons\\WHITE8x8")
				incTex:SetPoint("TOPLEFT", hpBar, "TOPRIGHT", 0, 0)
				incTex:SetPoint("BOTTOMLEFT", hpBar, "BOTTOMRIGHT", 0, 0)
				incTex:SetWidth(math.floor(124 * s.inc))
				incTex:SetVertexColor(0.22, 0.92, 0.54, 0.48)
			end

			local nameFS = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			nameFS:SetPoint("TOPLEFT", 6, -6)
			nameFS:SetText(s.name)

			local pctFS = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			pctFS:SetPoint("BOTTOMLEFT", 6, 6)
			pctFS:SetText(string.format("%d%%", math.floor(s.pct * 100)))

			if s.hot then
				local hotFS = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				hotFS:SetPoint("BOTTOMRIGHT", -6, 6)
				hotFS:SetText("|cff4ade80" .. s.hot .. "|r")
			end

			if s.debuff then
				local corner = tile:CreateTexture(nil, "OVERLAY")
				corner:SetTexture("Interface\\Buttons\\WHITE8x8")
				corner:SetSize(16, 16)
				corner:SetPoint("TOPRIGHT", -3, -3)
				if s.debuff == "Magic" then
					corner:SetVertexColor(0.22, 0.74, 0.98, 0.95)
				else
					corner:SetVertexColor(0.24, 0.86, 0.44, 0.95)
				end
				local tagFS = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				tagFS:SetPoint("CENTER", corner, "CENTER", 0, 0)
				tagFS:SetText(s.debuff == "Magic" and "M" or "G")
			end
		end

		local launchBtn = UI:CreateButton(body, "Echtes Live-Grid jetzt auf Bildschirm anzeigen", 310, 30, function()
			cfg.enabled = true
			cfg.showSolo = true
			hd:SaveConfig()
			hd:RequestRebuild()
			UI:ShowNotification("HealBot Live-Grid aktiviert! Mit der Maus verschiebbar.", 2.5)
			PluribusMainFrame:ShowTab(frame, "HealBot")
		end)
		launchBtn:SetPoint("TOPLEFT", 18, -144)
		launchBtn:SetBackdropColor(0.10, 0.30, 0.22, 0.96)
		launchBtn:SetBackdropBorderColor(0.24, 0.80, 0.48, 0.95)
	end
end

function PluribusMainFrame:Toggle()
	if _G.PluribusMainWindow then
		if _G.PluribusMainWindow:IsVisible() then
			_G.PluribusMainWindow:Hide()
		else
			_G.PluribusMainWindow:Show()
			self:ShowTab(_G.PluribusMainWindow, self.currentTab or "Guild Hub")
		end
	else
		self:Create():Show()
	end
end

return PluribusMainFrame
