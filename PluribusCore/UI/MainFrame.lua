-- PluribusCore Main Frame — Unified Guild Command Hub
-- Clean, uncluttered, graphical 8-tab architecture with zero redundant chrome:
--   1. Guild Hub      (Online Peers with Class Crests, @Mentions, Smart LFG, Live Feed, Open-World SOS)
--   2. Bags & Bank    (THE ONE unified Bag/Bank Icon Grid + Sell Gray Junk + Bag Valuation)
--   3. Professions    (Guild Recipes by Profession, Craft Profits, Recipe+Item Shopping List, Surplus Mats)
--   4. Gear Judge     (Sharpie's Gear Judge: Cap Guardian, The Laboratory, Upgrade Roadmap, Talents & XP Bar)
--   5. Guild Mail     (In-Addon Inbox/Sent + Write Letter/Message Composer)
--   6. Guild Tax      (Guild Vault Balance, Auto-Tracking, Mail Tax to Banker, Compliance Ledger & Rate Config)
--   7. Nav & Guides   (Compass Arrow HUD & Guild GPS | Distributed Hive Compute Leveling & Farming Guides)
--   8. Market & Tools (Guild AH Prices & P2P DB, Raid Cooldowns, All 27 Suite Addons)

PluribusMainFrame = {
	currentTab = "Guild Hub",
	profSubTab = "crafters",   -- crafters | profit | wishlist | surplus
	mailSubTab = "inbox",      -- inbox | sent
	taxSubTab  = "ledger",     -- ledger | policy | history
	navSubTab  = "compass",    -- compass | guides
	toolsSubTab = "market",    -- market | cooldowns | modules
	bagChar = nil,
	bagFilter = "ALL",
}
_G.PluribusMainFrame = PluribusMainFrame

local SIDE_TABS = {
	{ key = "Guild Hub",      icon = "Interface\\Icons\\Spell_Nature_AstralRecalGroup", title = "Guild Hub",      tooltip = "Online Guild Peers, @Mentions, Smart Guild LFG, Live Feed & SOS" },
	{ key = "Bags & Bank",    icon = "Interface\\Icons\\INV_Misc_Bag_08",               title = "Bags & Bank",    tooltip = "Unified Bags & Bank viewer for You, Alts & Guildmates + Junk Sell & Valuation" },
	{ key = "Professions",    icon = "Interface\\Icons\\Trade_BlackSmithing",           title = "Professions",    tooltip = "Guild Recipes (By Profession), Craft Profits, Shopping List & Surplus Mats" },
	{ key = "Gear Judge",     icon = "Interface\\Icons\\INV_Helmet_74",                 title = "Gear Judge",     tooltip = "Sharpie's Gear Judge: Cap Guardian, The Laboratory, Upgrade Roadmap, Talents & XP Bar" },
	{ key = "Guild Mail",     icon = "Interface\\Icons\\INV_Letter_15",                 title = "Guild Mail",     tooltip = "In-Addon Guild Messages (Online/Offline) & WoW Mailbox Letter Composer" },
	{ key = "Guild Tax",      icon = "Interface\\Icons\\INV_Misc_Coin_02",              title = "Guild Tax",      tooltip = "Guild Treasury Tax Tracker, Auto-Loot/Quest Tax, Pay Banker & Compliance Ledger" },
	{ key = "Nav & Guides",   icon = "Interface\\Icons\\INV_Misc_Map_01",               title = "Nav & Guides",   tooltip = "Compass Arrow HUD & Guild GPS + Zero-Lag Distributed Hive Compute Leveling/Farming Guides" },
	{ key = "Market & Tools", icon = "Interface\\Icons\\Trade_Engineering",             title = "Market & Tools", tooltip = "Guild AH Prices & P2P DB, Raid Cooldowns, and All 27 Pluribus Suite Addons" },
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
	PluribusGear                 = function() PluribusMainFrame:OpenToTab("Gear Judge") end,
	PluribusGearMgr              = function() if _G.PluribusGearMgrUI and _G.PluribusGearMgrUI.Toggle then _G.PluribusGearMgrUI:Toggle() else PluribusMainFrame:OpenToTab("Gear Judge") end end,
	PluribusGuide                = function() PluribusMainFrame.navSubTab = "guides" PluribusMainFrame:OpenToTab("Nav & Guides") end,
	PluribusGuild                = function() if _G.PluribusGuildUI and _G.PluribusGuildUI.Toggle then _G.PluribusGuildUI:Toggle() end end,
	PluribusHealer               = function() if _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then _G.PluribusHealerUI:Toggle() elseif _G.PluribusHealerFrames and _G.PluribusHealerFrames.ToggleRaidFrames then _G.PluribusHealerFrames:ToggleRaidFrames() end end,
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
	mainFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	mainFrame:SetScript("OnEvent", function(selfF, ev)
		if ev == "GET_ITEM_INFO_RECEIVED" and selfF:IsVisible() and not cachePending then
			local t = PluribusMainFrame.currentTab
			if t == "Bags & Bank" or t == "Professions" or t == "Market & Tools" or t == "Gear Judge" then
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

	self:ShowTab(mainFrame, self.currentTab or "Guild Hub")
	return mainFrame
end

-- Map legacy tab names gracefully so existing slash commands & external links never break
local TAB_ALIASES = {
	["Hive Live"]   = "Guild Hub",
	["Navigation"]  = "Nav & Guides",
	["Guides"]      = "Nav & Guides",
	["Compute"]     = "Nav & Guides",
	["Market & DB"] = "Market & Tools",
	["Cooldowns"]   = "Market & Tools",
	["Modules"]     = "Market & Tools",
}

function PluribusMainFrame:OpenToTab(tabName)
	if tabName == "Privacy" or tabName == "Settings" then
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open(tabName == "Privacy" and "HiveMind Sharing" or nil)
		end
		return
	end
	if tabName == "Cooldowns" then self.toolsSubTab = "cooldowns"
	elseif tabName == "Modules" then self.toolsSubTab = "modules"
	elseif tabName == "Market & DB" then self.toolsSubTab = "market"
	elseif tabName == "Guides" or tabName == "Compute" then self.navSubTab = "guides"
	elseif tabName == "Navigation" then self.navSubTab = "compass" end

	local resolved = TAB_ALIASES[tabName] or tabName or "Guild Hub"
	local f = self:Create()
	f:Show()
	self:ShowTab(f, resolved)
end

function PluribusMainFrame:RefreshSideBadges(frame)
	if not frame or not frame.sideTabs then return end
	if frame.sideTabs["Professions"] and _G.PluribusHiveProfessions then
		local cnt = #(_G.PluribusHiveProfessions:GetMySurplusMatches() or {})
		frame.sideTabs["Professions"]:SetBadge(cnt, 0.12, 0.62, 0.36)
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
		elseif tabName == "Gear Judge" then
			self:ShowGearJudgeTab(frame)
		elseif tabName == "Guild Mail" then
			self:ShowGuildMailTab(frame)
		elseif tabName == "Guild Tax" then
			self:ShowGuildTaxTab(frame)
		elseif tabName == "Nav & Guides" then
			self:ShowNavigationTab(frame)
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
-- TAB 1: GUILD HUB (Uncluttered Peers with Class Crests, Smart LFG, Live Feed)
-- ============================================================================
function PluribusMainFrame:ShowGuildHubTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
	local lfgPosts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}

	-- Sleek Graphical Smart LFG + @Mention + SOS Bar (explicit rightReserve prevents text overlap!)
	local lfgCard = UI:CreateBannerCard(p, 728, 52, "Interface\\Icons\\Spell_Nature_AstralRecalGroup",
		"|cff38bdf8Guild Hub · Smart LFG · @Mentions|r",
		"Use @Player, @Class, @Race, @Profession in /g to ping guildmates (queues during combat/instances).",
		0.22, 0.74, 0.97, 142)
	lfgCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)

	local sosBtn = UI:CreateButton(lfgCard, "Open-World SOS", 122, 24, function()
		if _G.PluribusHiveDistress then
			local sent = _G.PluribusHiveDistress:BroadcastSOS(true)
			if not sent and _G.PluribusUtils then
				_G.PluribusUtils:Warning("SOS is disabled inside instances and raids.", "Hive")
			end
			PluribusMainFrame:ShowTab(frame, "Guild Hub")
		end
	end)
	sosBtn:SetPoint("RIGHT", lfgCard, "RIGHT", -10, 0)

	local postCard = UI:CreateCard(p, 728, 40)
	postCard:SetPoint("TOPLEFT", lfgCard, "BOTTOMLEFT", 0, -8)

	local lfgLbl = UI:CreateLabel(postCard, "|cff38bdf8LFG Activity:|r", 1, 1, 1)
	lfgLbl:SetPoint("LEFT", postCard, "LEFT", 10, 0)

	local actBox = UI:CreateInputBox(postCard, 290, 22)
	actBox:SetPoint("LEFT", lfgLbl, "RIGHT", 8, 0)
	actBox:SetText("Strat UD / BRD / Raid")

	local roleBox = UI:CreateInputBox(postCard, 76, 22)
	roleBox:SetPoint("LEFT", actBox, "RIGHT", 8, 0)
	roleBox:SetText("ANY")

	local postLfgBtn = UI:CreateButton(postCard, "Post Smart LFG", 118, 22, function()
		if _G.PluribusHiveLFG then
			_G.PluribusHiveLFG:PostLFG(actBox:GetText(), roleBox:GetText())
			PluribusMainFrame:ShowTab(frame, "Guild Hub")
		end
	end, true)
	postLfgBtn:SetPoint("LEFT", roleBox, "RIGHT", 8, 0)

	local officerBtn = UI:CreateButton(postCard, "Officer Console", 108, 22, function()
		if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Show then
			_G.PluribusOfficerDashboard:Show()
		end
	end)
	officerBtn:SetPoint("RIGHT", postCard, "RIGHT", -8, 0)

	-- Left Column: Online Guild Peers with Class Crests + Instant Letter / GPS Actions
	local leftCard = UI:CreateCard(p, 360, 336, "Online Guild Peers (" .. tostring(#members) .. ")")
	leftCard:SetPoint("TOPLEFT", postCard, "BOTTOMLEFT", 0, -8)
	local leftScroll = UI:CreateScrollFrame(leftCard, "PluribusHubMembersScroll", 344, 300)
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
		local rightPad = m.isSelf and -8 or -92
		local l1 = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d|r", hex, m.name, m.level or 60))
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
	leftScroll.content:SetHeight(math.max(290, math.abs(ly) + 12))

	-- Right Column: Active Guild LFG & Live Activity Feed
	local rightCard = UI:CreateCard(p, 360, 336, "Live Guild Feed (LFG · Rares · Mail · Tax · SOS)")
	rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
	local rightScroll = UI:CreateScrollFrame(rightCard, "PluribusHubFeedScroll", 344, 300)
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
		local empty = UI:CreateLabel(rightScroll.content, "Hive network quietly syncing in the background (LZ-compressed).\nGuild LFG, Rares, SOS, Mail & Tax events appear here live.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 6, -8)
		empty:SetWidth(310)
	end
	rightScroll.content:SetHeight(math.max(290, math.abs(ry) + 12))
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
			local unit = (ah and ah.copper and ah.copper > 0) and ah.copper or (tonumber(select(11, PluribusUtils:GetItemInfo(it.itemID))) or 0)
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

	local junkBtn = UI:CreateButton(p, "Sell Gray Junk", 104, 24, SellGrayJunk)
	junkBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local syncBagBtn = UI:CreateButton(p, "Scan Bags", 80, 24, function()
		if _G.PluribusHiveInventory then
			_G.PluribusHiveInventory:ScanBags()
			_G.PluribusHiveInventory:BroadcastBags()
		end
		PluribusMainFrame:ShowTab(frame, "Bags & Bank")
	end, true)
	syncBagBtn:SetPoint("RIGHT", junkBtn, "LEFT", -6, 0)

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

	local subCrafters = UI:CreateButton(p, "Guild Recipes (By Prof)", 172, 26, function() SwitchSub("crafters") end)
	subCrafters:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	subCrafters:SetActiveState(self.profSubTab == "crafters")

	local subProfit = UI:CreateButton(p, "Craft Profits", 118, 26, function() SwitchSub("profit") end)
	subProfit:SetPoint("LEFT", subCrafters, "RIGHT", 6, 0)
	subProfit:SetActiveState(self.profSubTab == "profit")

	local subShop = UI:CreateButton(p, "Shopping List", 122, 26, function() SwitchSub("wishlist") end)
	subShop:SetPoint("LEFT", subProfit, "RIGHT", 6, 0)
	subShop:SetActiveState(self.profSubTab == "wishlist")

	local subSurplus = UI:CreateButton(p, "Surplus Mats", 118, 26, function() SwitchSub("surplus") end)
	subSurplus:SetPoint("LEFT", subShop, "RIGHT", 6, 0)
	subSurplus:SetActiveState(self.profSubTab == "surplus")

	local scroll = UI:CreateScrollFrame(p, "PluribusHubProfScroll", 724, 404)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
	local y = -4

	if self.profSubTab == "crafters" then
		y = profs:RenderGuildRecipesDirectory(scroll.content, 698, y, function()
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
-- TAB 4: SHARPIE'S GEAR JUDGE (Cap Guardian, Laboratory, Roadmap, Talents, XP Bar)
-- ============================================================================
function PluribusMainFrame:ShowGearJudgeTab(frame)
	local p = frame.contentFrame
	if _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.RenderPanel then
		_G.PluribusHiveGearJudge:RenderPanel(p, 728, 444, function()
			PluribusMainFrame:ShowTab(frame, "Gear Judge")
		end)
	else
		local lbl = _G.PluribusUIFramework:CreateLabel(p, "Gear Judge module is loading...", 0.85, 0.72, 0.35)
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
		local rateCard = UI:CreateCard(scroll.content, 696, 62, "Guild Tax Rate (% of Looted & Quest Gold)")
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

		local cb1 = UI:CreateCheckbox(scroll.content, "Automatically tax looted gold (CHAT_MSG_MONEY)", pol.taxLootGold == true, function(v)
			tax:UpdatePolicy({ taxLootGold = v }, true)
		end)
		cb1:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 30

		local cb2 = UI:CreateCheckbox(scroll.content, "Automatically tax quest gold rewards (QUEST_TURNED_IN)", pol.taxQuestGold == true, function(v)
			tax:UpdatePolicy({ taxQuestGold = v }, true)
		end)
		cb2:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
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

	if self.toolsSubTab == "cooldowns" then
		local stripBtn = UI:CreateButton(p, "Toggle Floating Strip", 150, 26, function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
		end, true)
		stripBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

		local scroll = UI:CreateScrollFrame(p, "PluribusHubCDScroll", 724, 402)
		scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)
		local active = (_G.PluribusHiveCooldowns and _G.PluribusHiveCooldowns:GetActiveCooldowns()) or {}
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
			local em = UI:CreateBannerCard(scroll.content, 694, 54, "Interface\\Icons\\Spell_Holy_BorrowedTime",
				"|cff4ade80All Tracked Guild & Raid Cooldowns Ready|r",
				"Major casts (Rebirth, Shield Wall, Innervate, Soulstone, Bloodlust) sync automatically.",
				0.29, 0.87, 0.50)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		end
		scroll.content:SetHeight(math.max(360, math.abs(y) + 12))
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
		local stats = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB:GetStats()) or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }
		local banner = UI:CreateBannerCard(p, 724, 56, "Interface\\Icons\\INV_Misc_Coin_02",
			"|cfffbbf24Guild AH Market & P2P Wowhead DB (Rev v" .. stats.revision .. ")|r",
			string.format("Cached: %d items, %d quests, %d NPCs · Auto-full-scans AH on open (20m CD) & syncs in background.", stats.items, stats.quests, stats.npcs),
			0.92, 0.72, 0.22)
		banner:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)

		local scroll = UI:CreateScrollFrame(p, "PluribusHubAHScroll", 724, 338)
		scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)

		local db = PluribusHive:GetDB()
		local prices = {}
		for itemID, info in pairs(db.prices or {}) do
			local name, link, quality = PluribusUtils:GetItemInfo(itemID)
			table.insert(prices, {
				itemID = itemID, name = name or ("Item #" .. itemID), link = link, quality = quality or 1,
				copper = info.copper or 0, reporter = info.reporter or "?", seenAt = info.seenAt or 0,
			})
		end
		table.sort(prices, function(a, b) return (a.seenAt or 0) > (b.seenAt or 0) end)

		local y = -2
		for idx, pr in ipairs(prices) do
			if idx > 80 then break end
			local row = UI:CreateListRow(scroll.content, 696, 34, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local slot = UI:CreateItemSlot(row, 26, { itemID = pr.itemID, name = pr.name, link = pr.link, quality = pr.quality })
			slot:SetPoint("LEFT", row, "LEFT", 6, 0)
			local qCol = PluribusUtils:GetQualityColor(pr.quality)
			local l1 = UI:CreateLabel(row, qCol .. pr.name .. "|r")
			l1:SetPoint("LEFT", slot, "RIGHT", 8, 0)
			local l2 = UI:CreateLabel(row, "|cfffbbf24" .. PluribusUtils:FormatGold(pr.copper) .. "|r  |cff94a3b8by " .. pr.reporter .. "|r")
			l2:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 36
		end
		if #prices == 0 then
			local em = UI:CreateLabel(scroll.content, "Open the Auction House once — Pluribus auto-scans all listings (20m CD) and powers tooltips & craft profits.", 0.68, 0.78, 0.88)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
		end
		scroll.content:SetHeight(math.max(300, math.abs(y) + 12))
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
