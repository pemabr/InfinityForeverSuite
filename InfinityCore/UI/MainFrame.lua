-- InfinityCore Main Frame — Guild Hive-Mind Command Hub
-- Sleek, functional 7-tab command center for Warcraft Forever (Interface 16001)

InfinityMainFrame = {
	currentTab = "Hive Live",
	profSubTab = "surplus", -- surplus | crafters | wishlist
}
_G.InfinityMainFrame = InfinityMainFrame

local TABS = {
	"Hive Live",
	"Bags & Bank",
	"Professions",
	"Cooldowns",
	"Market & DB",
	"Modules",
	"Privacy",
}

-- Direct launcher mapping for all suite addons (zero dead buttons!)
local ADDON_LAUNCHERS = {
	InfinityCore          = function() InfinityMainFrame:OpenToTab("Hive Live") end,
	InfinityDKP           = function() if _G.InfinityDKPUI and _G.InfinityDKPUI.Show then _G.InfinityDKPUI:Show() end end,
	InfinityLoot          = function() if _G.InfinityLootAuctionUI and _G.InfinityLootAuctionUI.CreateAuctionFrame then _G.InfinityLootAuctionUI:CreateAuctionFrame() end end,
	InfinityOfficer       = function() if _G.InfinityOfficerDashboard and _G.InfinityOfficerDashboard.Show then _G.InfinityOfficerDashboard:Show() end end,
	InfinityRosterMgr     = function() if _G.InfinityRosterUI and _G.InfinityRosterUI.Show then _G.InfinityRosterUI:Show() elseif _G.SlashCmdList and _G.SlashCmdList["INFINITYROSTER"] then _G.SlashCmdList["INFINITYROSTER"]("") end end,
	InfinityGuildSync     = function() if _G.InfinityHive then _G.InfinityHive:RequestFullGuildSync() end end,
	InfinityGuildBank     = function() if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer() end end,
	InfinityCalendar      = function() if _G.InfinityCalendarUI and _G.InfinityCalendarUI.Show then _G.InfinityCalendarUI:Show() end end,
	InfinityDetails       = function() if _G.InfinityDetailsUI and _G.InfinityDetailsUI.Toggle then _G.InfinityDetailsUI:Toggle() elseif _G.InfinityDetailsUI and _G.InfinityDetailsUI.Show then _G.InfinityDetailsUI:Show() end end,
	InfinityEncounter     = function() if _G.InfinityEncounterUI and _G.InfinityEncounterUI.Show then _G.InfinityEncounterUI:Show() end end,
	InfinityHealer        = function() if _G.InfinityHealerFrames and _G.InfinityHealerFrames.Show then _G.InfinityHealerFrames:Show() end end,
	InfinityConsumables   = function() if _G.InfinityConsumablesUI and _G.InfinityConsumablesUI.Show then _G.InfinityConsumablesUI:Show() end end,
	InfinityGear          = function() if _G.InfinityGearUI and _G.InfinityGearUI.Show then _G.InfinityGearUI:Show() end end,
	InfinityGearAudit     = function() if _G.InfinityGearAuditUI and _G.InfinityGearAuditUI.Show then _G.InfinityGearAuditUI:Show() end end,
	InfinityGather        = function() if _G.InfinityGatherUI and _G.InfinityGatherUI.Show then _G.InfinityGatherUI:Show() end end,
	InfinityAuction       = function() InfinityMainFrame:OpenToTab("Market & DB") end,
	InfinityGuide         = function() if _G.InfinityGuideUI and _G.InfinityGuideUI.Show then _G.InfinityGuideUI:Show() end end,
	InfinityPathFinding   = function() if _G.InfinityPathFindingUI and _G.InfinityPathFindingUI.Show then _G.InfinityPathFindingUI:Show() end end,
	InfinityLeveling      = function() if _G.InfinityLevelingUI and _G.InfinityLevelingUI.Show then _G.InfinityLevelingUI:Show() end end,
	InfinityQuestTracker  = function() if _G.InfinityQuestTrackerUI and _G.InfinityQuestTrackerUI.Show then _G.InfinityQuestTrackerUI:Show() end end,
	InfinityQuests        = function() if _G.InfinityQuestsUI and _G.InfinityQuestsUI.Show then _G.InfinityQuestsUI:Show() end end,
	InfinityCombat        = function() if _G.InfinityCombatUI and _G.InfinityCombatUI.Show then _G.InfinityCombatUI:Show() end end,
	InfinityAchievements  = function() if _G.InfinityAchievementsUI and _G.InfinityAchievementsUI.Show then _G.InfinityAchievementsUI:Show() end end,
	InfinityReputation    = function() if _G.InfinityReputationUI and _G.InfinityReputationUI.Show then _G.InfinityReputationUI:Show() end end,
	InfinityQoL           = function() if _G.InfinityQoLUI and _G.InfinityQoLUI.Show then _G.InfinityQoLUI:Show() end end,
	InfinityProfiler      = function() if _G.InfinityProfilerUI and _G.InfinityProfilerUI.Show then _G.InfinityProfilerUI:Show() end end,
	InfinityData          = function() InfinityMainFrame:OpenToTab("Market & DB") end,
	InfinityDataCollector = function() InfinityMainFrame:OpenToTab("Market & DB") end,
}

function InfinityMainFrame:LaunchAddon(addonName)
	local fn = ADDON_LAUNCHERS[addonName]
	if fn then
		local ok = pcall(fn)
		if ok then return true end
	end
	if _G.InfinityCommandRegistry and _G.InfinityCommandRegistry.ExecuteCommand then
		local short = addonName:gsub("^Infinity", ""):lower()
		pcall(function() _G.InfinityCommandRegistry:ExecuteCommand(short, "") end)
	end
	return false
end

function InfinityMainFrame:Create()
	if _G.InfinityMainWindow then
		return _G.InfinityMainWindow
	end

	local UI = _G.InfinityUIFramework
	local mainFrame = UI:CreateFrame("InfinityMainWindow", UIParent, 780, 530, "InfinityForever — Guild Hive Hub", "Interface 16001")
	mainFrame:SetPoint("CENTER")

	if mainFrame.closeBtn then
		mainFrame.closeBtn:SetScript("OnClick", function()
			mainFrame:Hide()
			if _G.InfinityMessaging then
				pcall(function() _G.InfinityMessaging:Publish("INFINITY_WINDOW_HIDDEN", "MainWindow") end)
			end
		end)
	end

	-- Persistent visual HiveMind connectivity & data-sync health indicator in dashboard header
	if mainFrame.header and _G.InfinityHiveUI and _G.InfinityHiveUI.CreateHealthBadge then
		local badge = _G.InfinityHiveUI:CreateHealthBadge(mainFrame.header, function()
			if _G.InfinityMainWindow and _G.InfinityMainWindow:IsVisible() then
				InfinityMainFrame:ShowTab(_G.InfinityMainWindow, InfinityMainFrame.currentTab or "Hive Live")
			end
		end)
		if badge and mainFrame.closeBtn then
			badge:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", -8, 0)
			mainFrame.healthBadge = badge
		end
	end

	-- 7 evenly sized tabs fitting cleanly inside 780px width
	mainFrame.tabButtons = {}
	local tabWidth = 102
	for i, tabName in ipairs(TABS) do
		local tabBtn = UI:CreateButton(mainFrame, tabName, tabWidth, 26, function()
			self:ShowTab(mainFrame, tabName)
		end)
		tabBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14 + (i - 1) * (tabWidth + 6), -44)
		mainFrame.tabButtons[tabName] = tabBtn
	end

	-- Main content container
	local contentFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -78)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
	UI:ApplyBackdrop(contentFrame, 0.08, 0.10, 0.15, 0.96, 0.22, 0.28, 0.38, 0.85)
	mainFrame.contentFrame = contentFrame

	self:ShowTab(mainFrame, self.currentTab or "Hive Live")
	return mainFrame
end

function InfinityMainFrame:OpenToTab(tabName)
	local f = self:Create()
	f:Show()
	self:ShowTab(f, tabName or "Hive Live")
end

function InfinityMainFrame:ShowTab(frame, tabName)
	local UI = _G.InfinityUIFramework
	self.currentTab = tabName
	frame.contentFrame:SetScript("OnUpdate", nil)
	UI:ClearContainer(frame.contentFrame)

	for name, btn in pairs(frame.tabButtons or {}) do
		btn:SetActiveState(name == tabName)
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
	elseif tabName == "Privacy" then
		self:ShowPrivacyTab(frame)
	end
end

-- ============================================================================
-- TAB 1: HIVE LIVE (Guild Presence, Smart LFG, Quest Overlap, Rares & Feed)
-- ============================================================================
function InfinityMainFrame:ShowHiveLiveTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local members = (_G.InfinityHive and _G.InfinityHive:GetOnlineMembers()) or {}
	local lfgPosts = (_G.InfinityHiveLFG and _G.InfinityHiveLFG:GetActivePosts()) or {}
	local surplus = (_G.InfinityHiveProfessions and _G.InfinityHiveProfessions:GetMySurplusMatches()) or {}
	local health = (_G.InfinityHive and _G.InfinityHive.GetNetworkHealth)
		and _G.InfinityHive:GetNetworkHealth()
		or { state = "OFFLINE", shortLabel = "Offline", label = "Offline", color = { 0.97, 0.44, 0.44 }, hex = "|cfff87171", score = 0, onlinePeers = 0, queuedMessages = 0, syncFreshness = "Never", dbRevision = 1, dbItems = 0 }

	if frame.healthBadge and frame.healthBadge.Refresh then
		frame.healthBadge:Refresh()
	end

	-- Visual HiveMind Connectivity & Data-Sync Health Banner (live auto-updating)
	local yTop = -12
	if _G.InfinityHiveUI and _G.InfinityHiveUI.CreateHealthBanner then
		local banner = _G.InfinityHiveUI:CreateHealthBanner(p, 728, function()
			InfinityMainFrame:ShowTab(frame, "Hive Live")
		end)
		if banner then
			banner:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop)
			yTop = yTop - 66
		end
	end

	-- Quick Action Bar
	local bagsBtn = UI:CreateButton(p, "Hive Bags & Bank", 132, 24, function()
		if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer() end
	end, true)
	bagsBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop)

	local cdBtn = UI:CreateButton(p, "Cooldown Strip", 118, 24, function()
		if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleCooldownOverlay() end
	end)
	cdBtn:SetPoint("LEFT", bagsBtn, "RIGHT", 8, 0)

	local officerBtn = UI:CreateButton(p, "Officer Dashboard", 130, 24, function()
		if _G.InfinityOfficerDashboard and _G.InfinityOfficerDashboard.Show then
			_G.InfinityOfficerDashboard:Show()
		end
	end)
	officerBtn:SetPoint("LEFT", cdBtn, "RIGHT", 8, 0)

	local profBtn = UI:CreateButton(p, "Surplus Mats (" .. tostring(#surplus) .. ")", 134, 24, function()
		InfinityMainFrame:ShowTab(frame, "Professions")
	end)
	profBtn:SetPoint("LEFT", officerBtn, "RIGHT", 8, 0)

	local sosBtn = UI:CreateButton(p, "Send Open-World SOS", 156, 24, function()
		if _G.InfinityHiveDistress then
			local sent = _G.InfinityHiveDistress:BroadcastSOS(true)
			if not sent and _G.InfinityUtils then
				_G.InfinityUtils:Warning("SOS is disabled inside instances and raids.", "Hive")
			end
			InfinityMainFrame:ShowTab(frame, "Hive Live")
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
		if _G.InfinityHiveLFG then
			local act = actBox:GetText()
			local role = roleBox:GetText()
			_G.InfinityHiveLFG:PostLFG(act, role)
			InfinityMainFrame:ShowTab(frame, "Hive Live")
		end
	end, true)
	postLfgBtn:SetPoint("LEFT", roleBox, "RIGHT", 8, 0)

	local hintLbl = UI:CreateLabel(lfgCard, "Matches role & level", 0.60, 0.68, 0.78)
	hintLbl:SetPoint("LEFT", postLfgBtn, "RIGHT", 8, 0)

	-- Left Column: Online Guild Hive Members + Quest Overlap
	local leftCard = UI:CreateCard(p, 356, 266, "Online Hive Members (" .. tostring(#members) .. ") & Same-Quest")
	leftCard:SetPoint("TOPLEFT", p, "TOPLEFT", 12, yTop - 84)
	local leftScroll = UI:CreateScrollFrame(leftCard, "InfinityHubMembersScroll", 340, 232)
	leftScroll:SetPoint("TOPLEFT", leftCard, "TOPLEFT", 8, -28)
	local ly = -2
	for idx, m in ipairs(members) do
		local row = UI:CreateListRow(leftScroll.content, 316, 24, idx, function()
			if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer(m.name) end
		end)
		row:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 0, ly)
		local _, _, _, hex = UI:GetClassColor(m.class)
		local lbl = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d %s|r", hex, m.name, m.level or 60, m.role or ""))
		lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
		local zLbl = UI:CreateLabel(row, tostring(m.zone or ""):sub(1, 20), 0.72, 0.80, 0.90)
		zLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		ly = ly - 26
	end

	local overlaps = (_G.InfinityHiveDistress and _G.InfinityHiveDistress:GetGuildmatesOnSameQuest()) or {}
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
	leftScroll.content:SetHeight(math.max(220, math.abs(ly) + 12))

	-- Right Column: Active Guild LFG & Live Hive Feed (Rares / SOS / Events)
	local rightCard = UI:CreateCard(p, 364, 266, "Live Hive Feed (LFG · Rares · SOS)")
	rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
	local rightScroll = UI:CreateScrollFrame(rightCard, "InfinityHubFeedScroll", 348, 232)
	rightScroll:SetPoint("TOPLEFT", rightCard, "TOPLEFT", 8, -28)
	local ry = -2

	for idx, post in ipairs(lfgPosts) do
		local row = UI:CreateListRow(rightScroll.content, 324, 30, idx, function()
			if SendChatMessage and post.sender ~= InfinityHive:GetPlayerShortName() then
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

	local feed = (_G.InfinityHive and _G.InfinityHive.recentEvents) or {}
	for i, ev in ipairs(feed) do
		if i > 18 then break end
		local col = (ev.category == "SOS" and "|cfff87171") or (ev.category == "RARE" and "|cfffbbf24") or "|cff38bdf8"
		local lbl = UI:CreateLabel(rightScroll.content, col .. "[" .. ev.category .. "]|r " .. tostring(ev.text):sub(1, 52))
		lbl:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 4, ry)
		ry = ry - 18
	end
	if #lfgPosts == 0 and #feed == 0 then
		local empty = UI:CreateLabel(rightScroll.content, "Hive network listening on guild channel.\nRares, SOS alerts, LFG matches & DB syncs appear here.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 6, -8)
	end
	rightScroll.content:SetHeight(math.max(220, math.abs(ry) + 12))
end

-- ============================================================================
-- TAB 2: BAGS & BANK (Cross-Guild Search + Character Quick Launcher)
-- ============================================================================
function InfinityMainFrame:ShowBagsTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local hdr = UI:CreateLabel(p, "Guild & Alt Bags / Bank Network", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	local openBagBtn = UI:CreateButton(p, "Open Bagnon-Style Viewer (/bags)", 216, 26, function()
		if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer() end
	end, true)
	openBagBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local searchLbl = UI:CreateLabel(p, "Search across ALL Alts & Sharing Guildmates:", 0.75, 0.82, 0.90)
	searchLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)

	local resultsScroll = UI:CreateScrollFrame(p, "InfinityHubBagsScroll", 724, 344)
	resultsScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -84)

	local function RenderResults(query)
		UI:ClearContainer(resultsScroll.content)
		if not _G.InfinityHiveInventory then return end
		local y = -2
		local q = tostring(query or ""):match("^%s*(.-)%s*$")

		if q ~= "" then
			local matches = _G.InfinityHiveInventory:SearchAll(q)
			for idx, it in ipairs(matches) do
				if idx > 80 then break end
				local row = UI:CreateListRow(resultsScroll.content, 696, 24, idx, function()
					if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer(it.owner) end
				end)
				row:SetPoint("TOPLEFT", resultsScroll.content, "TOPLEFT", 0, y)
				local qCol = InfinityUtils:GetQualityColor(it.quality)
				local _, _, _, cHex = UI:GetClassColor(it.ownerClass)
				local l1 = UI:CreateLabel(row, qCol .. it.name .. "|r")
				l1:SetPoint("LEFT", row, "LEFT", 8, 0)
				local l2 = UI:CreateLabel(row, string.format("%s%s|r  ·  x%d (%d bag, %d bank)", cHex, it.owner, it.total, it.bags, it.bank))
				l2:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				y = y - 26
			end
			if #matches == 0 then
				local empty = UI:CreateLabel(resultsScroll.content, "No matching items found across alts or sharing guildmates.", 0.65, 0.72, 0.82)
				empty:SetPoint("TOPLEFT", resultsScroll.content, "TOPLEFT", 6, -10)
			end
		else
			local chars = _G.InfinityHiveInventory:GetInspectableCharacters()
			for idx, ch in ipairs(chars) do
				local bagItems, bankItems = 0, 0
				for _ in pairs(ch.bags or {}) do bagItems = bagItems + 1 end
				for _ in pairs(ch.bank or {}) do bankItems = bankItems + 1 end

				local row = UI:CreateListRow(resultsScroll.content, 696, 30, idx, function()
					if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleInventoryViewer(ch.name) end
				end)
				row:SetPoint("TOPLEFT", resultsScroll.content, "TOPLEFT", 0, y)
				local _, _, _, cHex = UI:GetClassColor(ch.class)
				local tag = (ch.group == "YOU" and "|cff38bdf8[YOU]|r ") or (ch.group == "ALT" and "|cff4ade80[ALT]|r ") or "|cfffbbf24[GUILD]|r "
				local l1 = UI:CreateLabel(row, tag .. cHex .. ch.name .. "|r  (Lv " .. (ch.level or 60) .. ")")
				l1:SetPoint("LEFT", row, "LEFT", 8, 0)
				local l2 = UI:CreateLabel(row, string.format("%d bag stacks · %d bank stacks · |cfffbbf24%s|r  (Click to open)",
					bagItems, bankItems, InfinityUtils:FormatGold(ch.gold or 0)), 0.80, 0.86, 0.94)
				l2:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				y = y - 32
			end
		end
		resultsScroll.content:SetHeight(math.max(330, math.abs(y) + 12))
	end

	local searchBox = UI:CreateInputBox(p, 320, 24, function(selfBox)
		RenderResults(selfBox:GetText())
	end)
	searchBox:SetPoint("LEFT", searchLbl, "RIGHT", 10, 0)

	RenderResults("")
end

-- ============================================================================
-- TAB 3: PROFESSIONS (Surplus Matcher, Guild Crafters, Wishlist)
-- ============================================================================
function InfinityMainFrame:ShowProfessionsTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local subSurplus, subCrafters, subWish
	local function SwitchSub(mode)
		InfinityMainFrame.profSubTab = mode
		InfinityMainFrame:ShowTab(frame, "Professions")
	end

	subSurplus = UI:CreateButton(p, "Surplus Mats Guild Needs", 180, 26, function() SwitchSub("surplus") end)
	subSurplus:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	subSurplus:SetActiveState(self.profSubTab == "surplus")

	subCrafters = UI:CreateButton(p, "Guild Crafters Directory", 170, 26, function() SwitchSub("crafters") end)
	subCrafters:SetPoint("LEFT", subSurplus, "RIGHT", 8, 0)
	subCrafters:SetActiveState(self.profSubTab == "crafters")

	subWish = UI:CreateButton(p, "My Material Wishlist", 150, 26, function() SwitchSub("wishlist") end)
	subWish:SetPoint("LEFT", subCrafters, "RIGHT", 8, 0)
	subWish:SetActiveState(self.profSubTab == "wishlist")

	local rescanBtn = UI:CreateButton(p, "Scan & Share Mine", 136, 26, function()
		if _G.InfinityHiveProfessions then
			_G.InfinityHiveProfessions:ScanMyProfessions()
			_G.InfinityHiveProfessions:BroadcastProfessions()
		end
		InfinityMainFrame:ShowTab(frame, "Professions")
	end, true)
	rescanBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local scroll = UI:CreateScrollFrame(p, "InfinityHubProfScroll", 724, 376)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)
	local y = -4

	if self.profSubTab == "surplus" then
		local matches = (_G.InfinityHiveProfessions and _G.InfinityHiveProfessions:GetMySurplusMatches()) or {}
		local info = UI:CreateLabel(scroll.content, "Items sitting in YOUR bags/bank that YOU don't need, which guildmates need to level up their professions:", 0.75, 0.85, 0.94)
		info:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 24

		for idx, m in ipairs(matches) do
			local row = UI:CreateListRow(scroll.content, 696, 34, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local qCol = InfinityUtils:GetQualityColor(m.quality)
			local who = {}
			for _, nd in ipairs(m.neededBy) do
				table.insert(who, string.format("%s (%s %d)", nd.name, nd.prof, nd.level or 0))
			end
			local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff4ade80(You have x%d surplus)|r", qCol, m.name, m.myCount))
			l1:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -3)
			local l2 = UI:CreateLabel(row, "Needed by: " .. table.concat(who, ", "), 0.72, 0.84, 0.94)
			l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 3)

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
			y = y - 36
		end

		if #matches == 0 then
			local empty = UI:CreateLabel(scroll.content, "No surplus matches right now. As guildmates log in and open their professions,\nany spare mats you have that they need will appear right here and on item tooltips!", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 6)
		end
	elseif self.profSubTab == "crafters" then
		local db = InfinityHive:GetDB()
		local list = {}
		for _, rec in pairs(db.guildProfs or {}) do
			table.insert(list, rec)
		end
		table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

		for idx, rec in ipairs(list) do
			local pStrs = {}
			for _, pr in ipairs(rec.profs or {}) do
				table.insert(pStrs, string.format("%s (%d/%d)", pr.displayName or pr.name, pr.level or 0, pr.max or 300))
			end
			local row = UI:CreateListRow(scroll.content, 696, 28, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local _, _, _, hex = UI:GetClassColor(rec.class)
			local l1 = UI:CreateLabel(row, hex .. rec.name .. "|r")
			l1:SetPoint("LEFT", row, "LEFT", 8, 0)
			local l2 = UI:CreateLabel(row, #pStrs > 0 and table.concat(pStrs, "  ·  ") or "No professions scanned yet", 0.80, 0.88, 0.96)
			l2:SetPoint("LEFT", row, "LEFT", 140, 0)
			y = y - 30
		end
	else
		local info = UI:CreateLabel(scroll.content, "Add extra items (by Item ID) that you want guildmates to see as needed on their tooltips:", 0.78, 0.85, 0.92)
		info:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 28

		local idBox = UI:CreateInputBox(scroll.content, 120, 24)
		idBox:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		idBox:SetText("13463")

		local qtyBox = UI:CreateInputBox(scroll.content, 64, 24)
		qtyBox:SetPoint("LEFT", idBox, "RIGHT", 8, 0)
		qtyBox:SetText("20")

		local addBtn = UI:CreateButton(scroll.content, "Add Needed Item ID", 140, 24, function()
			if _G.InfinityHiveProfessions then
				_G.InfinityHiveProfessions:AddNeededMaterial(tonumber(idBox:GetText()), tonumber(qtyBox:GetText()) or 20)
				InfinityMainFrame:ShowTab(frame, "Professions")
			end
		end, true)
		addBtn:SetPoint("LEFT", qtyBox, "RIGHT", 8, 0)
		y = y - 38

		local db = InfinityHive:GetDB()
		local idx = 0
		for itemID, qty in pairs(db.myNeededMats or {}) do
			idx = idx + 1
			local name, _, quality = InfinityUtils:GetItemInfo(itemID)
			local row = UI:CreateListRow(scroll.content, 696, 26, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local qCol = InfinityUtils:GetQualityColor(quality or 1)
			local lbl = UI:CreateLabel(row, string.format("%s%s|r (#%d)  —  Want x%d", qCol, name or ("Item #" .. itemID), itemID, qty))
			lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
			local rmBtn = UI:CreateButton(row, "Remove", 72, 20, function()
				_G.InfinityHiveProfessions:RemoveNeededMaterial(itemID)
				InfinityMainFrame:ShowTab(frame, "Professions")
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 28
		end
	end

	scroll.content:SetHeight(math.max(360, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 4: COOLDOWNS (Live Shared + Cast-Monitored Estimates)
-- ============================================================================
function InfinityMainFrame:ShowCooldownsTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local hdr = UI:CreateLabel(p, "Guild & Raid Cooldowns (Shared + Cast-Estimated)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	local toggleStrip = UI:CreateButton(p, "Toggle Floating Strip (/hive cd)", 196, 26, function()
		if _G.InfinityHiveUI then _G.InfinityHiveUI:ToggleCooldownOverlay() end
	end, true)
	toggleStrip:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)

	local sub = UI:CreateLabel(p, "Tracks exact cooldowns from guildmates + automatically estimates nearby casts [Est] via UNIT_SPELLCAST_SUCCEEDED.", 0.68, 0.76, 0.86)
	sub:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -42)

	local scroll = UI:CreateScrollFrame(p, "InfinityHubCDScroll", 724, 356)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -68)

	local active = (_G.InfinityHiveCooldowns and _G.InfinityHiveCooldowns:GetActiveCooldowns()) or {}
	local y = -4
	for idx, cd in ipairs(active) do
		local r, g, b = UI:GetClassColor(cd.class)
		local bar = UI:CreateStatusBar(scroll.content, 696, 24, r, g, b)
		bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		local pct = math.max(0, math.min(100, (cd.remaining / math.max(1, cd.duration)) * 100))
		local est = cd.estimated and " |cff94a3b8[Estimated]|r" or " |cff4ade80[Exact]|r"
		bar:SetBarData(pct, string.format("[%s] %s — %s%s", cd.category, cd.player, cd.name, est), InfinityUtils:FormatTime(cd.remaining), r, g, b)
		y = y - 28
	end

	if #active == 0 then
		local empty = UI:CreateLabel(scroll.content, "All tracked guild & raid cooldowns are currently READY!\nCast Rebirth, Shield Wall, Innervate, Soulstone, Bloodlust, etc. to see live sync.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -12)
	end
	scroll.content:SetHeight(math.max(340, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 5: MARKET & GAME DB (Guild AH Prices + On-Demand P2P Wowhead DB)
-- ============================================================================
function InfinityMainFrame:ShowMarketDBTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local stats = (_G.InfinityHiveNetworkDB and _G.InfinityHiveNetworkDB:GetStats()) or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }

	-- Top DB Status Card
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
		if _G.InfinityHiveNetworkDB then
			_G.InfinityHiveNetworkDB:CheckForNetworkUpdates()
			if _G.InfinityUtils then _G.InfinityUtils:Info("Sent Guild P2P DB version check (DBVER).", "HiveDB") end
		end
		InfinityMainFrame:ShowTab(frame, "Market & DB")
	end, true)
	checkNetBtn:SetPoint("BOTTOMLEFT", dbCard, "BOTTOMLEFT", 12, 10)

	local missingIds = (_G.InfinityHiveNetworkDB and _G.InfinityHiveNetworkDB:GetMissingIDsString("item")) or ""
	if missingIds ~= "" then
		local mLbl = UI:CreateLabel(dbCard, "Missing IDs (paste in Companion Wowhead Sync):", 0.72, 0.80, 0.90)
		mLbl:SetPoint("LEFT", checkNetBtn, "RIGHT", 12, 0)
		local mBox = UI:CreateInputBox(dbCard, 190, 22)
		mBox:SetPoint("LEFT", mLbl, "RIGHT", 6, 0)
		mBox:SetText(missingIds)
	end

	-- Bottom Guild AH Prices List
	local ahHdr = UI:CreateLabel(p, "Guild-Synced Auction House Prices (also docked directly inside the Auction House window!)", 0.95, 0.80, 0.25)
	ahHdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -140)

	local scroll = UI:CreateScrollFrame(p, "InfinityHubAHScroll", 724, 260)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -162)

	local db = InfinityHive:GetDB()
	local prices = {}
	for itemID, info in pairs(db.prices or {}) do
		local name, _, quality = InfinityUtils:GetItemInfo(itemID)
		table.insert(prices, {
			itemID = itemID,
			name = name or ("Item #" .. itemID),
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
		local row = UI:CreateListRow(scroll.content, 696, 24, idx)
		row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
		local qCol = InfinityUtils:GetQualityColor(pr.quality)
		local l1 = UI:CreateLabel(row, qCol .. pr.name .. "|r  |cff94a3b8(#" .. pr.itemID .. ")|r")
		l1:SetPoint("LEFT", row, "LEFT", 8, 0)
		local l2 = UI:CreateLabel(row, "|cfffbbf24" .. InfinityUtils:FormatGold(pr.copper) .. "|r  |cff94a3b8by " .. pr.reporter .. "|r")
		l2:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 26
	end
	if #prices == 0 then
		local empty = UI:CreateLabel(scroll.content, "Open the Auction House and click 'Scan Page' in the embedded Hive Market panel to share prices with your guild.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -12)
	end
	scroll.content:SetHeight(math.max(250, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 6: MODULES (Scrollable Launcher for ALL 27 InfinityForever Addons)
-- ============================================================================
function InfinityMainFrame:ShowModulesTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame

	local hdr = UI:CreateLabel(p, "InfinityForever Suite Modules (All 27 Addons — Launch or Toggle)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	local scroll = UI:CreateScrollFrame(p, "InfinityHubModulesScroll", 724, 380)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -44)

	local addons = (_G.InfinityAddonManager and _G.InfinityAddonManager.GetAllAddons)
		and _G.InfinityAddonManager:GetAllAddons() or {}
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
			if _G.InfinityAddonManager then
				_G.InfinityAddonManager:SetAddonEnabled(addon.name, not isEnabled)
				InfinityMainFrame:ShowTab(frame, "Modules")
			end
		end)
		toggleBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

		local openBtn = UI:CreateButton(row, "Open", 64, 22, function()
			InfinityMainFrame:LaunchAddon(addon.name)
		end, true)
		openBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -6, 0)

		y = y - 30
	end

	scroll.content:SetHeight(math.max(370, math.abs(y) + 12))
end

-- ============================================================================
-- TAB 7: PRIVACY & SETTINGS (Default-ON Hive Controls, Role, Distress, Theme)
-- ============================================================================
function InfinityMainFrame:ShowPrivacyTab(frame)
	local UI = _G.InfinityUIFramework
	local p = frame.contentFrame
	local cfg = InfinityHive:GetConfig()

	local hdr = UI:CreateLabel(p, "Guild Hive-Mind Privacy & Display Controls (Shared ON by Default)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)

	-- Left column: Sharing Permissions
	local shareCard = UI:CreateCard(p, 356, 376, "What You Share With Your Guild")
	shareCard:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)

	local shareOpts = {
		{ key = "shareBags", label = "Share My Bags (viewable by guildmates)" },
		{ key = "shareBank", label = "Share My Bank (viewable by guildmates)" },
		{ key = "shareProfessions", label = "Share My Professions & Needed Materials" },
		{ key = "shareCooldowns", label = "Share My Major Cooldowns" },
		{ key = "shareDistress", label = "Send Open-World Danger / SOS Pings" },
		{ key = "shareLFG", label = "Share & Sync Smart Guild LFG Posts" },
		{ key = "shareAuctionPrices", label = "Share Scanned Auction House Prices" },
		{ key = "shareWorldEvents", label = "Share Rares, Nodes & Active Quests" },
		{ key = "shareGameDB", label = "Participate in P2P Wowhead DB Sync" },
	}
	local sy = -32
	for _, opt in ipairs(shareOpts) do
		local cb = UI:CreateCheckbox(shareCard, opt.label, cfg[opt.key], function(val)
			InfinityHive:SetConfig(opt.key, val)
		end)
		cb:SetPoint("TOPLEFT", shareCard, "TOPLEFT", 10, sy)
		sy = sy - 34
	end

	-- Right column: Display, Role, Distress Threshold & Theme
	local dispCard = UI:CreateCard(p, 360, 376, "Alerts, Tooltips, Role & Theme")
	dispCard:SetPoint("TOPLEFT", shareCard, "TOPRIGHT", 8, 0)

	local dispOpts = {
		{ key = "showDistressAlerts", label = "Show Nearby Open-World Rescue Alerts" },
		{ key = "showLFGMatches", label = "Show Smart Guild LFG Match Toasts" },
		{ key = "showTooltips", label = "Enrich Item Tooltips (Bags / Needs / AH / DB)" },
		{ key = "showCooldownOverlay", label = "Show Draggable Guild Cooldown Strip" },
	}
	local dy = -32
	for _, opt in ipairs(dispOpts) do
		local cb = UI:CreateCheckbox(dispCard, opt.label, cfg[opt.key], function(val)
			InfinityHive:SetConfig(opt.key, val)
		end)
		cb:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 10, dy)
		dy = dy - 34
	end

	-- Preferred Role Selector (for Smart LFG matching)
	local roleLbl = UI:CreateLabel(dispCard, "My Preferred LFG Role:", 0.80, 0.86, 0.94)
	roleLbl:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14, dy - 8)
	local roles = { "AUTO", "TANK", "HEALER", "DPS" }
	for i, r in ipairs(roles) do
		local btn = UI:CreateButton(dispCard, r, 78, 22, function()
			InfinityHive:SetConfig("myRole", r)
			InfinityMainFrame:ShowTab(frame, "Privacy")
		end, cfg.myRole == r)
		btn:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14 + (i - 1) * 84, dy - 30)
	end

	-- Distress HP% Threshold
	local hpLbl = UI:CreateLabel(dispCard, "Open-World SOS Auto-Alert HP Threshold:", 0.80, 0.86, 0.94)
	hpLbl:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14, dy - 66)
	for i, pct in ipairs({ 25, 35, 50 }) do
		local btn = UI:CreateButton(dispCard, pct .. "% HP", 96, 22, function()
			InfinityHive:SetConfig("distressHpThreshold", pct)
			InfinityMainFrame:ShowTab(frame, "Privacy")
		end, cfg.distressHpThreshold == pct)
		btn:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14 + (i - 1) * 104, dy - 88)
	end

	-- Theme Toggle
	local thLbl = UI:CreateLabel(dispCard, "Suite Theme:", 0.80, 0.86, 0.94)
	thLbl:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14, dy - 124)
	local darkBtn = UI:CreateButton(dispCard, "Obsidian Dark", 150, 24, function()
		UI:LoadTheme("obsidian")
		InfinityMainFrame:ShowTab(frame, "Privacy")
	end, UI.theme ~= "light")
	darkBtn:SetPoint("TOPLEFT", dispCard, "TOPLEFT", 14, dy - 146)

	local lightBtn = UI:CreateButton(dispCard, "Light Slate", 150, 24, function()
		UI:LoadTheme("light")
		InfinityMainFrame:ShowTab(frame, "Privacy")
	end, UI.theme == "light")
	lightBtn:SetPoint("LEFT", darkBtn, "RIGHT", 10, 0)
end

function InfinityMainFrame:Toggle()
	if _G.InfinityMainWindow then
		if _G.InfinityMainWindow:IsVisible() then
			_G.InfinityMainWindow:Hide()
		else
			_G.InfinityMainWindow:Show()
			self:ShowTab(_G.InfinityMainWindow, self.currentTab or "Hive Live")
		end
	else
		self:Create():Show()
	end
end

return InfinityMainFrame
