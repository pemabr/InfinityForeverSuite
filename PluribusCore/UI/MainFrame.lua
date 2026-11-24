-- PluribusCore Main Frame — Guild Hive-Mind Command Hub
-- Adventure-Guide-style right-edge side tabs, visual icon-grid Bags/Bank, item icons & tooltips,
-- unified Settings access in header, and working launchers for all 27 Pluribus Suite addons

PluribusMainFrame = {
	currentTab = "Hive Live",
	profSubTab = "surplus", -- surplus | crafters | wishlist
	bagChar = nil,
	bagFilter = "ALL",
}
_G.PluribusMainFrame = PluribusMainFrame

local SIDE_TABS = {
	{ key = "Hive Live",   icon = "Interface\\Icons\\Spell_Nature_AstralRecalGroup", title = "Hive Live",       tooltip = "HiveMind Network Health, Smart Guild LFG, Online Peers & Live Feed" },
	{ key = "Bags & Bank", icon = "Interface\\Icons\\INV_Misc_Bag_08",               title = "Bags & Bank",     tooltip = "Visual Bagnon-style icon grids for Alts & Sharing Guildmates" },
	{ key = "Professions", icon = "Interface\\Icons\\Trade_BlackSmithing",           title = "Professions",     tooltip = "Surplus Mats Guild Needs, Guild Crafters & Material Wishlist" },
	{ key = "Cooldowns",   icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",       title = "Cooldowns",       tooltip = "Live Shared & Cast-Estimated Guild/Raid Cooldowns" },
	{ key = "Market & DB", icon = "Interface\\Icons\\INV_Misc_Coin_02",              title = "Market & DB",     tooltip = "Guild-Synced AH Prices & P2P Wowhead Network Database" },
	{ key = "Modules",     icon = "Interface\\Icons\\INV_Misc_Gear_01",              title = "Suite Modules",   tooltip = "Launch or manage all 27 Pluribus Suite addons" },
}

-- Direct launcher mapping for all 27 actual Pluribus Suite addons (zero dead buttons!)
local ADDON_LAUNCHERS = {
	PluribusCore                 = function() PluribusMainFrame:OpenToTab("Hive Live") end,
	PluribusAttendance           = function() if _G.PluribusAttendanceUI and _G.PluribusAttendanceUI.Toggle then _G.PluribusAttendanceUI:Toggle() end end,
	PluribusCalendar             = function() if _G.PluribusCalendarUI and _G.PluribusCalendarUI.Toggle then _G.PluribusCalendarUI:Toggle() end end,
	PluribusConsumables          = function() if _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Toggle then _G.PluribusConsumablesUI:Toggle() elseif _G.PluribusConsumablesUI and _G.PluribusConsumablesUI.Show then _G.PluribusConsumablesUI:Show() end end,
	PluribusDKP                  = function() if _G.PluribusDKPUI and _G.PluribusDKPUI.Toggle then _G.PluribusDKPUI:Toggle() elseif _G.PluribusDKPUI and _G.PluribusDKPUI.Show then _G.PluribusDKPUI:Show() end end,
	PluribusData                 = function() if _G.PluribusDataUI and _G.PluribusDataUI.Toggle then _G.PluribusDataUI:Toggle() else PluribusMainFrame:OpenToTab("Market & DB") end end,
	PluribusDataCollector        = function() if _G.PluribusDataCollectorUI and _G.PluribusDataCollectorUI.Toggle then _G.PluribusDataCollectorUI:Toggle() else PluribusMainFrame:OpenToTab("Market & DB") end end,
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
	local mainFrame = UI:CreateFrame("PluribusMainWindow", UIParent, 780, 520, "Pluribus — Guild Hive Hub", "Warcraft Forever")
	mainFrame:SetPoint("CENTER")

	if mainFrame.closeBtn then
		mainFrame.closeBtn:SetScript("OnClick", function()
			mainFrame:Hide()
			if _G.PluribusMessaging then
				pcall(function() _G.PluribusMessaging:Publish("PLURIBUS_WINDOW_HIDDEN", "MainWindow") end)
			end
		end)
	end

	-- Settings button right in header (opens unified ESC > Options > AddOns > Pluribus Suite menu)
	if mainFrame.header and mainFrame.closeBtn then
		local settingsBtn = UI:CreateButton(mainFrame.header, "Settings", 72, 22, function()
			if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
				_G.PluribusSettingsPanel:Open()
			end
		end)
		settingsBtn:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", -6, 0)
		mainFrame.settingsBtn = settingsBtn

		-- Persistent visual HiveMind connectivity & data-sync health indicator in dashboard header
		if _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBadge then
			local badge = _G.PluribusHiveUI:CreateHealthBadge(mainFrame.header, function()
				if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() then
					PluribusMainFrame:ShowTab(_G.PluribusMainWindow, PluribusMainFrame.currentTab or "Hive Live")
				end
			end)
			if badge then
				badge:SetPoint("RIGHT", settingsBtn, "LEFT", -8, 0)
				mainFrame.healthBadge = badge
			end
		end
	end

	-- Adventure-Guide-style right-edge vertical side bookmark tabs
	mainFrame.sideTabs = {}
	for idx, def in ipairs(SIDE_TABS) do
		local tab = UI:CreateSideTab(mainFrame, idx, {
			icon = def.icon,
			title = def.title,
			tooltip = def.tooltip,
			yOffset = -46 - (idx - 1) * 48,
			onClick = function()
				PluribusMainFrame:ShowTab(mainFrame, def.key)
			end,
		})
		mainFrame.sideTabs[def.key] = tab
	end

	-- Expanded main content container (no cluttered horizontal tab bar!)
	local contentFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -48)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
	UI:ApplyBackdrop(contentFrame, 0.08, 0.10, 0.15, 0.96, 0.22, 0.28, 0.38, 0.85)
	mainFrame.contentFrame = contentFrame

	-- Refresh uncached remote item icons automatically while Bags/Professions/Market tabs are visible
	local cachePending = false
	mainFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	mainFrame:SetScript("OnEvent", function(selfF, ev)
		if ev == "GET_ITEM_INFO_RECEIVED" and selfF:IsVisible() and not cachePending then
			local t = PluribusMainFrame.currentTab
			if t == "Bags & Bank" or t == "Professions" or t == "Market & DB" then
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

	self:ShowTab(mainFrame, self.currentTab or "Hive Live")
	return mainFrame
end

function PluribusMainFrame:OpenToTab(tabName)
	if tabName == "Privacy" or tabName == "Settings" then
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open("HiveMind Sharing")
		end
		return
	end
	local f = self:Create()
	f:Show()
	self:ShowTab(f, tabName or "Hive Live")
end

function PluribusMainFrame:ShowTab(frame, tabName)
	if tabName == "Privacy" or tabName == "Settings" then
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open("HiveMind Sharing")
		end
		return
	end
	local UI = _G.PluribusUIFramework
	self.currentTab = tabName
	frame.contentFrame:SetScript("OnUpdate", nil)
	UI:ClearContainer(frame.contentFrame)

	for name, tab in pairs(frame.sideTabs or {}) do
		tab:SetActiveState(name == tabName)
	end

	-- Keep surplus mats badge fresh on the Professions side tab
	if frame.sideTabs and frame.sideTabs["Professions"] and _G.PluribusHiveProfessions then
		local cnt = #(_G.PluribusHiveProfessions:GetMySurplusMatches() or {})
		frame.sideTabs["Professions"]:SetBadge(cnt, 0.12, 0.62, 0.36)
	end

	if tabName == "Hive Live" then
		self:ShowHiveLiveTab(frame)
	elseif tabName == "Bags & Bank" then
		self:ShowBagsTab(frame)
	elseif tabName == "Professions" then
		self:ShowProfessionsTab(frame)
	elseif tabName == "Cooldowns" then
		self:ShowCooldownsTab(frame)
	elseif tabName == "Market & DB" then
		self:ShowMarketDBTab(frame)
	elseif tabName == "Modules" then
		self:ShowModulesTab(frame)
	end
end

-- ============================================================================
-- TAB 1: HIVE LIVE (Guild Presence, Smart LFG, Quest Overlap, Rares & Feed)
-- ============================================================================
function PluribusMainFrame:ShowHiveLiveTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
	local lfgPosts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}
	local surplus = (_G.PluribusHiveProfessions and _G.PluribusHiveProfessions:GetMySurplusMatches()) or {}

	if frame.healthBadge and frame.healthBadge.Refresh then
		frame.healthBadge:Refresh()
	end

	-- Visual HiveMind Connectivity & Data-Sync Health Banner (live auto-updating)
	local yTop = -12
	if _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBanner then
		local banner = _G.PluribusHiveUI:CreateHealthBanner(p, 728, function()
			PluribusMainFrame:ShowTab(frame, "Hive Live")
		end)
		if banner then
			banner:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop)
			yTop = yTop - 66
		end
	end

	-- Quick Action Bar
	local bagsBtn = UI:CreateButton(p, "Bags & Bank Viewer", 136, 24, function()
		if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer() end
	end, true)
	bagsBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop)

	local cdBtn = UI:CreateButton(p, "Cooldown Strip", 114, 24, function()
		if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
	end)
	cdBtn:SetPoint("LEFT", bagsBtn, "RIGHT", 8, 0)

	local officerBtn = UI:CreateButton(p, "Officer Console", 118, 24, function()
		if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Show then
			_G.PluribusOfficerDashboard:Show()
		end
	end)
	officerBtn:SetPoint("LEFT", cdBtn, "RIGHT", 8, 0)

	local profBtn = UI:CreateButton(p, "Surplus Mats (" .. tostring(#surplus) .. ")", 130, 24, function()
		PluribusMainFrame:ShowTab(frame, "Professions")
	end)
	profBtn:SetPoint("LEFT", officerBtn, "RIGHT", 8, 0)

	local sosBtn = UI:CreateButton(p, "Open-World SOS", 142, 24, function()
		if _G.PluribusHiveDistress then
			local sent = _G.PluribusHiveDistress:BroadcastSOS(true)
			if not sent and _G.PluribusUtils then
				_G.PluribusUtils:Warning("SOS is disabled inside instances and raids.", "Hive")
			end
			PluribusMainFrame:ShowTab(frame, "Hive Live")
		end
	end)
	sosBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, yTop)

	-- Quick Post Guild LFG Row
	local lfgCard = UI:CreateCard(p, 728, 44)
	lfgCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop - 32)
	local lfgLbl = UI:CreateLabel(lfgCard, "|cff38bdf8Quick Guild LFG:|r", 1, 1, 1)
	lfgLbl:SetPoint("LEFT", lfgCard, "LEFT", 10, 0)

	local actBox = UI:CreateInputBox(lfgCard, 250, 24)
	actBox:SetPoint("LEFT", lfgLbl, "RIGHT", 8, 0)
	actBox:SetText("Strat UD / BRD")

	local roleBox = UI:CreateInputBox(lfgCard, 78, 24)
	roleBox:SetPoint("LEFT", actBox, "RIGHT", 8, 0)
	roleBox:SetText("ANY")

	local postLfgBtn = UI:CreateButton(lfgCard, "Post Smart LFG", 118, 24, function()
		if _G.PluribusHiveLFG then
			_G.PluribusHiveLFG:PostLFG(actBox:GetText(), roleBox:GetText())
			PluribusMainFrame:ShowTab(frame, "Hive Live")
		end
	end, true)
	postLfgBtn:SetPoint("LEFT", roleBox, "RIGHT", 8, 0)

	local hintLbl = UI:CreateLabel(lfgCard, "Matches role & level", 0.60, 0.68, 0.78)
	hintLbl:SetPoint("LEFT", postLfgBtn, "RIGHT", 8, 0)

	-- Left Column: Online Guild Hive Members + Quest Overlap
	local leftCard = UI:CreateCard(p, 356, 286, "Online Hive Peers (" .. tostring(#members) .. ") & Same-Quest")
	leftCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop - 84)
	local leftScroll = UI:CreateScrollFrame(leftCard, "PluribusHubMembersScroll", 340, 252)
	leftScroll:SetPoint("TOPLEFT", leftCard, "TOPLEFT", 8, -28)
	local ly = -2
	for idx, m in ipairs(members) do
		local row = UI:CreateListRow(leftScroll.content, 316, 24, idx, function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer(m.name) end
		end)
		row:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 0, ly)
		local _, _, _, hex = UI:GetClassColor(m.class)
		local lbl = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d %s|r", hex, m.name, m.level or 60, m.role or ""))
		lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
		local zLbl = UI:CreateLabel(row, tostring(m.zone or ""):sub(1, 20), 0.72, 0.80, 0.90)
		zLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		ly = ly - 26
	end

	local overlaps = (_G.PluribusHiveDistress and _G.PluribusHiveDistress:GetGuildmatesOnSameQuest()) or {}
	if #overlaps > 0 then
		ly = ly - 6
		local oHdr = UI:CreateLabel(leftScroll.content, "|cff4ade80Guildmates on Your Active Quests:|r")
		oHdr:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 4, ly)
		ly = ly - 18
		for _, o in ipairs(overlaps) do
			local oLbl = UI:CreateLabel(leftScroll.content, string.format("• %s — %s (%s)", o.member, o.questTitle:sub(1, 26), o.zone), 0.80, 0.96, 0.84)
			oLbl:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 6, ly)
			ly = ly - 16
		end
	end
	leftScroll.content:SetHeight(math.max(240, math.abs(ly) + 12))

	-- Right Column: Active Guild LFG & Live Hive Feed
	local rightCard = UI:CreateCard(p, 364, 286, "Live Hive Feed (LFG · Rares · SOS)")
	rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
	local rightScroll = UI:CreateScrollFrame(rightCard, "PluribusHubFeedScroll", 348, 252)
	rightScroll:SetPoint("TOPLEFT", rightCard, "TOPLEFT", 8, -28)
	local ry = -2

	for idx, post in ipairs(lfgPosts) do
		local row = UI:CreateListRow(rightScroll.content, 324, 30, idx, function()
			if SendChatMessage and post.sender ~= PluribusHive:GetPlayerShortName() then
				pcall(SendChatMessage, "Hey! Invite for " .. post.activity .. "?", "WHISPER", nil, post.sender)
			end
		end)
		row:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 0, ry)
		local l1 = UI:CreateLabel(row, "|cff38bdf8[LFG]|r " .. post.sender .. ": " .. post.activity .. " (Lv " .. (post.minLevel or 1) .. "-" .. (post.maxLevel or 60) .. ")")
		l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		local l2 = UI:CreateLabel(row, "Click to whisper for invite", 0.58, 0.72, 0.86)
		l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
		ry = ry - 32
	end

	local feed = (_G.PluribusHive and _G.PluribusHive.recentEvents) or {}
	for i, ev in ipairs(feed) do
		if i > 18 then break end
		local col = (ev.category == "SOS" and "|cfff87171") or (ev.category == "RARE" and "|cfffbbf24") or "|cff38bdf8"
		local lbl = UI:CreateLabel(rightScroll.content, col .. "[" .. ev.category .. "]|r " .. tostring(ev.text):sub(1, 52))
		lbl:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 4, ry)
		ry = ry - 18
	end
	if #lfgPosts == 0 and #feed == 0 then
		local empty = UI:CreateLabel(rightScroll.content, "Hive network listening on PLBHIVE guild channel.\nRares, SOS alerts, LFG matches & DB syncs appear here.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 6, -8)
	end
	rightScroll.content:SetHeight(math.max(240, math.abs(ry) + 12))
end

-- ============================================================================
-- TAB 2: BAGS & BANK (Visual Icon Grid + Character Switcher + Cross-Guild Search)
-- ============================================================================
function PluribusMainFrame:ShowBagsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame
	if not _G.PluribusHiveInventory then return end

	local chars = _G.PluribusHiveInventory:GetInspectableCharacters()
	if not self.bagChar and #chars > 0 then
		self.bagChar = chars[1].name
	end

	local searchLbl = UI:CreateLabel(p, "Search:", 0.75, 0.82, 0.90)
	searchLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -18)

	local searchBox = UI:CreateInputBox(p, 210, 24)
	searchBox:SetPoint("LEFT", searchLbl, "RIGHT", 6, 0)

	local fAll, fBags, fBank
	local itemScroll = nil
	local summaryLbl = nil

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
			if selected then
				local bagItems = (PluribusMainFrame.bagFilter ~= "BANK") and BuildEntries(selected.bags, selected.name, false, "") or {}
				local bankItems = (PluribusMainFrame.bagFilter ~= "BAGS") and BuildEntries(selected.bank, selected.name, true, "") or {}
				local _, _, _, hex = UI:GetClassColor(selected.class)
				summaryLbl:SetText(string.format("%s%s|r (Lv %d)  ·  |cfffbbf24%s|r  ·  %d bags / %d bank",
					hex, selected.name, selected.level or 60, PluribusUtils:FormatGold(selected.gold or 0), #bagItems, #bankItems))
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

	fAll = UI:CreateButton(p, "All", 46, 24, function() SetFilter("ALL") end)
	fAll:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
	fAll:SetActiveState(self.bagFilter == "ALL")

	fBags = UI:CreateButton(p, "Bags", 52, 24, function() SetFilter("BAGS") end)
	fBags:SetPoint("LEFT", fAll, "RIGHT", 4, 0)
	fBags:SetActiveState(self.bagFilter == "BAGS")

	fBank = UI:CreateButton(p, "Bank", 52, 24, function() SetFilter("BANK") end)
	fBank:SetPoint("LEFT", fBags, "RIGHT", 4, 0)
	fBank:SetActiveState(self.bagFilter == "BANK")

	local popoutBtn = UI:CreateButton(p, "Pop-Out Bag Viewer", 142, 24, function()
		if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer(PluribusMainFrame.bagChar) end
	end, true)
	popoutBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	-- Left character list
	local charCard = UI:CreateCard(p, 196, 404, "Characters")
	charCard:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
	local charScroll = UI:CreateScrollFrame(charCard, "PluribusHubBagCharScroll", 182, 368)
	charScroll:SetPoint("TOPLEFT", charCard, "TOPLEFT", 6, -28)

	local cy = -2
	for idx, ch in ipairs(chars) do
		local row = UI:CreateListRow(charScroll.content, 160, 32, idx, function()
			PluribusMainFrame.bagChar = ch.name
			searchBox:SetText("")
			PluribusMainFrame:ShowTab(frame, "Bags & Bank")
		end)
		row:SetPoint("TOPLEFT", charScroll.content, "TOPLEFT", 0, cy)
		local _, _, _, hex = UI:GetClassColor(ch.class)
		local tag = (ch.group == "YOU" and "|cff38bdf8[You]|r ") or (ch.group == "ALT" and "|cff4ade80[Alt]|r ") or "|cfffbbf24[Guild]|r "
		local l1 = UI:CreateLabel(row, tag .. hex .. ch.name .. "|r")
		l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		local l2 = UI:CreateLabel(row, PluribusUtils:FormatGold(ch.gold or 0), 0.72, 0.80, 0.88, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
		if ch.name == self.bagChar then
			UI:ApplyBackdrop(row, 0.14, 0.34, 0.62, 0.95, 0.22, 0.74, 0.97, 1)
		end
		cy = cy - 34
	end
	charScroll.content:SetHeight(math.max(360, math.abs(cy) + 10))

	-- Right visual item icon grid panel
	local gridCard = UI:CreateCard(p, 520, 404)
	gridCard:SetPoint("TOPLEFT", charCard, "TOPRIGHT", 8, 0)

	summaryLbl = UI:CreateLabel(gridCard, "", 0.86, 0.92, 0.98, "GameFontNormal")
	summaryLbl:SetPoint("TOPLEFT", gridCard, "TOPLEFT", 10, -9)

	itemScroll = UI:CreateScrollFrame(gridCard, "PluribusHubBagsScroll", 500, 366)
	itemScroll:SetPoint("TOPLEFT", gridCard, "TOPLEFT", 10, -30)

	searchBox:SetScript("OnTextChanged", RenderBagGrid)
	RenderBagGrid()
end

-- ============================================================================
-- TAB 3: PROFESSIONS (Surplus Matcher with Icons/Tooltips, Crafters, Drag-Drop Wishlist)
-- ============================================================================
function PluribusMainFrame:ShowProfessionsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local function SwitchSub(mode)
		PluribusMainFrame.profSubTab = mode
		PluribusMainFrame:ShowTab(frame, "Professions")
	end

	local subSurplus = UI:CreateButton(p, "Surplus Mats Guild Needs", 180, 26, function() SwitchSub("surplus") end)
	subSurplus:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	subSurplus:SetActiveState(self.profSubTab == "surplus")

	local subCrafters = UI:CreateButton(p, "Guild Crafters Directory", 170, 26, function() SwitchSub("crafters") end)
	subCrafters:SetPoint("LEFT", subSurplus, "RIGHT", 8, 0)
	subCrafters:SetActiveState(self.profSubTab == "crafters")

	local subWish = UI:CreateButton(p, "My Material Wishlist", 150, 26, function() SwitchSub("wishlist") end)
	subWish:SetPoint("LEFT", subCrafters, "RIGHT", 8, 0)
	subWish:SetActiveState(self.profSubTab == "wishlist")

	local rescanBtn = UI:CreateButton(p, "Scan & Share Mine", 136, 26, function()
		if _G.PluribusHiveProfessions then
			_G.PluribusHiveProfessions:ScanMyProfessions()
			_G.PluribusHiveProfessions:BroadcastProfessions()
		end
		PluribusMainFrame:ShowTab(frame, "Professions")
	end, true)
	rescanBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local scroll = UI:CreateScrollFrame(p, "PluribusHubProfScroll", 724, 404)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)
	local y = -4

	if self.profSubTab == "surplus" then
		local matches = (_G.PluribusHiveProfessions and _G.PluribusHiveProfessions:GetMySurplusMatches()) or {}
		local info = UI:CreateLabel(scroll.content, "Items in YOUR bags/bank that YOU don't need, which guildmates need to skill up (also on side tabs in Professions!):", 0.75, 0.85, 0.94)
		info:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 24

		for idx, m in ipairs(matches) do
			local row = UI:CreateListRow(scroll.content, 696, 40, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local slot = UI:CreateItemSlot(row, 32, {
				itemID = m.itemID, name = m.name, link = m.link, quality = m.quality, count = m.myCount, isSurplus = true,
			})
			slot:SetPoint("LEFT", row, "LEFT", 6, 0)

			local qCol = PluribusUtils:GetQualityColor(m.quality)
			local who = {}
			for _, nd in ipairs(m.neededBy) do
				table.insert(who, string.format("%s (%s %d)", nd.name, nd.prof, nd.level or 0))
			end
			local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff4ade80(You have x%d surplus)|r", qCol, m.name, m.myCount))
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -1)
			local l2 = UI:CreateLabel(row, "Needed by: " .. table.concat(who, ", "), 0.72, 0.84, 0.94)
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 8, 1)

			local firstTarget = m.neededBy[1] and m.neededBy[1].name
			if firstTarget then
				local offerBtn = UI:CreateButton(row, "Whisper " .. firstTarget, 126, 22, function()
					if SendChatMessage then
						local itemRef = m.link or m.name
						pcall(SendChatMessage, string.format("Hey! I have x%d %s spare for your %s — want them?", m.myCount, itemRef, m.neededBy[1].prof or "profession"), "WHISPER", nil, firstTarget)
					end
				end, true)
				offerBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			end
			y = y - 42
		end

		if #matches == 0 then
			local empty = UI:CreateLabel(scroll.content, "No surplus matches right now. As guildmates log in and open their professions,\nany spare mats you have that they need will appear here, on Professions side tabs, and on item tooltips!", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 6)
		end
	elseif self.profSubTab == "crafters" then
		local db = PluribusHive:GetDB()
		local list = {}
		for _, rec in pairs(db.guildProfs or {}) do table.insert(list, rec) end
		table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

		for idx, rec in ipairs(list) do
			local pStrs = {}
			for _, pr in ipairs(rec.profs or {}) do
				table.insert(pStrs, string.format("%s (%d/%d)", pr.displayName or pr.name, pr.level or 0, pr.max or 300))
			end
			local row = UI:CreateListRow(scroll.content, 696, 28, idx, function()
				if ChatFrame_SendTell and rec.name ~= PluribusHive:GetPlayerShortName() then
					pcall(ChatFrame_SendTell, rec.name)
				end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local _, _, _, hex = UI:GetClassColor(rec.class)
			local l1 = UI:CreateLabel(row, hex .. rec.name .. "|r")
			l1:SetPoint("LEFT", row, "LEFT", 8, 0)
			local l2 = UI:CreateLabel(row, #pStrs > 0 and table.concat(pStrs, "  ·  ") or "No professions scanned yet", 0.80, 0.88, 0.96)
			l2:SetPoint("LEFT", row, "LEFT", 140, 0)
			y = y - 30
		end
	else
		local info = UI:CreateLabel(scroll.content, "Drag & drop any item below, or enter an item name, Shift-Click link, or Item ID to share with guildmates:", 0.78, 0.85, 0.92)
		info:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 28

		local dropBtn = UI:CreateButton(scroll.content, "Drop Item Here", 136, 26, function()
			if GetCursorInfo then
				local kind, itemID = GetCursorInfo()
				if kind == "item" and itemID and _G.PluribusHiveProfessions then
					_G.PluribusHiveProfessions:AddNeededMaterial(itemID, 20)
					if ClearCursor then pcall(ClearCursor) end
					PluribusMainFrame:ShowTab(frame, "Professions")
				end
			end
		end)
		dropBtn:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		dropBtn:SetScript("OnReceiveDrag", function()
			if GetCursorInfo then
				local kind, itemID = GetCursorInfo()
				if kind == "item" and itemID and _G.PluribusHiveProfessions then
					_G.PluribusHiveProfessions:AddNeededMaterial(itemID, 20)
					if ClearCursor then pcall(ClearCursor) end
					PluribusMainFrame:ShowTab(frame, "Professions")
				end
			end
		end)

		local idBox = UI:CreateInputBox(scroll.content, 220, 26)
		idBox:SetPoint("LEFT", dropBtn, "RIGHT", 8, 0)
		idBox:SetText("")

		local qtyBox = UI:CreateInputBox(scroll.content, 56, 26)
		qtyBox:SetPoint("LEFT", idBox, "RIGHT", 8, 0)
		qtyBox:SetText("20")

		local addBtn = UI:CreateButton(scroll.content, "Add to Wishlist", 122, 26, function()
			if _G.PluribusHiveProfessions then
				local resolved = _G.PluribusHiveProfessions:ResolveItemID(idBox:GetText())
				if resolved then
					_G.PluribusHiveProfessions:AddNeededMaterial(resolved, tonumber(qtyBox:GetText()) or 20)
					PluribusMainFrame:ShowTab(frame, "Professions")
				else
					UI:ShowNotification("|cfffbbf24Drop an item, Shift-Click a link, or type an item name/ID.|r", 3)
				end
			end
		end, true)
		addBtn:SetPoint("LEFT", qtyBox, "RIGHT", 8, 0)
		y = y - 38

		local db = PluribusHive:GetDB()
		local idx = 0
		for itemID, qty in pairs(db.myNeededMats or {}) do
			idx = idx + 1
			local name, link, quality = PluribusUtils:GetItemInfo(itemID)
			local row = UI:CreateListRow(scroll.content, 696, 36, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local slot = UI:CreateItemSlot(row, 28, {
				itemID = itemID, name = name, link = link, quality = quality or 1, count = qty,
			})
			slot:SetPoint("LEFT", row, "LEFT", 6, 0)

			local qCol = PluribusUtils:GetQualityColor(quality or 1)
			local lbl = UI:CreateLabel(row, string.format("%s%s|r (#%d)  —  Want x%d", qCol, name or ("Item #" .. itemID), itemID, qty))
			lbl:SetPoint("LEFT", slot, "RIGHT", 8, 0)

			local rmBtn = UI:CreateButton(row, "Remove", 72, 20, function()
				_G.PluribusHiveProfessions:RemoveNeededMaterial(itemID)
				PluribusMainFrame:ShowTab(frame, "Professions")
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 38
		end
	end

	scroll.content:SetHeight(math.max(380, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 4: COOLDOWNS (Live Shared + Cast-Monitored Estimates)
-- ============================================================================
function PluribusMainFrame:ShowCooldownsTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local hdr = UI:CreateLabel(p, "Guild & Raid Cooldowns (Shared + Cast-Estimated)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	local toggleStrip = UI:CreateButton(p, "Toggle Floating Strip (/hive cd)", 196, 26, function()
		if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
	end, true)
	toggleStrip:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local sub = UI:CreateLabel(p, "Tracks exact cooldowns from guildmates + automatically estimates nearby casts [Est] via UNIT_SPELLCAST_SUCCEEDED.", 0.68, 0.76, 0.86)
	sub:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -42)

	local scroll = UI:CreateScrollFrame(p, "PluribusHubCDScroll", 724, 384)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -68)

	local active = (_G.PluribusHiveCooldowns and _G.PluribusHiveCooldowns:GetActiveCooldowns()) or {}
	local y = -4
	for _, cd in ipairs(active) do
		local r, g, b = UI:GetClassColor(cd.class)
		local bar = UI:CreateStatusBar(scroll.content, 696, 24, r, g, b)
		bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		local pct = math.max(0, math.min(100, (cd.remaining / math.max(1, cd.duration)) * 100))
		local est = cd.estimated and " |cff94a3b8[Estimated]|r" or " |cff4ade80[Exact]|r"
		bar:SetBarData(pct, string.format("[%s] %s — %s%s", cd.category, cd.player, cd.name, est), PluribusUtils:FormatTime(cd.remaining), r, g, b)
		y = y - 28
	end

	if #active == 0 then
		local empty = UI:CreateLabel(scroll.content, "All tracked guild & raid cooldowns are currently READY!\nCast Rebirth, Shield Wall, Innervate, Soulstone, Bloodlust, etc. to see live sync.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -12)
	end
	scroll.content:SetHeight(math.max(360, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 5: MARKET & GAME DB (Guild AH Prices with Icons/Tooltips + P2P Wowhead DB)
-- ============================================================================
function PluribusMainFrame:ShowMarketDBTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local stats = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB:GetStats()) or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }

	local dbCard = UI:CreateCard(p, 724, 118, "On-Demand Wowhead & Guild P2P Network Database")
	dbCard:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)

	local statusStr = string.format(
		"Revision: |cfffbbf24v%d|r   ·   Cached: |cff38bdf8%d items|r, %d quests, %d NPCs   ·   Pending P2P misses: %d",
		stats.revision, stats.items, stats.quests, stats.npcs, stats.missing
	)
	local sLbl = UI:CreateLabel(dbCard, statusStr)
	sLbl:SetPoint("TOPLEFT", dbCard, "TOPLEFT", 12, -30)

	local optStr = string.format("Optional External DBs:  QuestieDB %s  ·  WoWHeadDB %s  ·  GathererDB %s",
		stats.hasQuestieDB and "|cff4ade80Detected|r" or "|cff94a3b8Optional (Standalone OK)|r",
		stats.hasWowheadDB and "|cff4ade80Detected|r" or "|cff94a3b8Optional|r",
		stats.hasGathererDB and "|cff4ade80Detected|r" or "|cff94a3b8Optional|r"
	)
	local oLbl = UI:CreateLabel(dbCard, optStr)
	oLbl:SetPoint("TOPLEFT", dbCard, "TOPLEFT", 12, -52)

	local checkNetBtn = UI:CreateButton(dbCard, "Check Guild Network for DB Updates", 230, 24, function()
		if _G.PluribusHiveNetworkDB then
			_G.PluribusHiveNetworkDB:CheckForNetworkUpdates()
			if _G.PluribusUtils then _G.PluribusUtils:Info("Sent Guild P2P DB version check (DBVER).", "HiveDB") end
		end
		PluribusMainFrame:ShowTab(frame, "Market & DB")
	end, true)
	checkNetBtn:SetPoint("BOTTOMLEFT", dbCard, "BOTTOMLEFT", 12, 10)

	local missingIds = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB:GetMissingIDsString("item")) or ""
	if missingIds ~= "" then
		local mLbl = UI:CreateLabel(dbCard, "Missing IDs (paste in Companion):", 0.72, 0.80, 0.90)
		mLbl:SetPoint("LEFT", checkNetBtn, "RIGHT", 12, 0)
		local mBox = UI:CreateInputBox(dbCard, 190, 22)
		mBox:SetPoint("LEFT", mLbl, "RIGHT", 6, 0)
		mBox:SetText(missingIds)
	end

	local ahHdr = UI:CreateLabel(p, "Guild-Synced Auction House Prices (also on right-edge side tabs inside the Auction House!)", 0.95, 0.80, 0.25)
	ahHdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -140)

	local scroll = UI:CreateScrollFrame(p, "PluribusHubAHScroll", 724, 288)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -162)

	local db = PluribusHive:GetDB()
	local prices = {}
	for itemID, info in pairs(db.prices or {}) do
		local name, link, quality = PluribusUtils:GetItemInfo(itemID)
		table.insert(prices, {
			itemID = itemID,
			name = name or ("Item #" .. itemID),
			link = link,
			quality = quality or 1,
			copper = info.copper or 0,
			reporter = info.reporter or "?",
			seenAt = info.seenAt or 0,
		})
	end
	table.sort(prices, function(a, b) return (a.seenAt or 0) > (b.seenAt or 0) end)

	local y = -2
	for idx, pr in ipairs(prices) do
		if idx > 60 then break end
		local row = UI:CreateListRow(scroll.content, 696, 32, idx)
		row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

		local slot = UI:CreateItemSlot(row, 24, {
			itemID = pr.itemID, name = pr.name, link = pr.link, quality = pr.quality,
		})
		slot:SetPoint("LEFT", row, "LEFT", 6, 0)

		local qCol = PluribusUtils:GetQualityColor(pr.quality)
		local l1 = UI:CreateLabel(row, qCol .. pr.name .. "|r  |cff94a3b8(#" .. pr.itemID .. ")|r")
		l1:SetPoint("LEFT", slot, "RIGHT", 8, 0)
		local l2 = UI:CreateLabel(row, "|cfffbbf24" .. PluribusUtils:FormatGold(pr.copper) .. "|r  |cff94a3b8by " .. pr.reporter .. "|r")
		l2:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		row:SetScript("OnEnter", function(selfRow)
			if GameTooltip then
				GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
				local ok = PluribusUtils:SetTooltipItem(GameTooltip, pr.itemID, pr.link)
				if not ok then GameTooltip:AddLine(pr.name, 1, 1, 1) end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

		y = y - 34
	end
	if #prices == 0 then
		local empty = UI:CreateLabel(scroll.content, "Open the Auction House to browse or click 'Scan Page' in the docked Pluribus Market drawer to share prices.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -12)
	end
	scroll.content:SetHeight(math.max(270, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 6: SUITE MODULES (Scrollable Launcher for ALL 27 Pluribus Suite Addons)
-- ============================================================================
function PluribusMainFrame:ShowModulesTab(frame)
	local UI = _G.PluribusUIFramework
	local p = frame.contentFrame

	local hdr = UI:CreateLabel(p, "Pluribus Suite Modules (All 27 Addons — Launch or Toggle)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	local settingsHint = UI:CreateButton(p, "All Settings", 98, 24, function()
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open()
		end
	end)
	settingsHint:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local scroll = UI:CreateScrollFrame(p, "PluribusHubModulesScroll", 724, 408)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -44)

	local addons = (_G.PluribusAddonManager and _G.PluribusAddonManager.GetAllAddons)
		and _G.PluribusAddonManager:GetAllAddons() or {}
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
				PluribusMainFrame:ShowTab(frame, "Modules")
			end
		end)
		toggleBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

		local openBtn = UI:CreateButton(row, "Open", 64, 22, function()
			PluribusMainFrame:LaunchAddon(addon.name)
		end, true)
		openBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -6, 0)

		y = y - 30
	end

	scroll.content:SetHeight(math.max(390, math.abs(y) + 12))
end

function PluribusMainFrame:Toggle()
	if _G.PluribusMainWindow then
		if _G.PluribusMainWindow:IsVisible() then
			_G.PluribusMainWindow:Hide()
		else
			_G.PluribusMainWindow:Show()
			self:ShowTab(_G.PluribusMainWindow, self.currentTab or "Hive Live")
		end
	else
		self:Create():Show()
	end
end

return PluribusMainFrame
