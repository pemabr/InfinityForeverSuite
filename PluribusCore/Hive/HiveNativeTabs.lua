-- PluribusHive Native Window Side Tabs
-- Attaches Adventure-Guide-style right-edge side bookmark tabs directly to WoW's Guild / Social
-- and Quest Log windows so every Hive feature lives right where players naturally expect it.

PluribusHiveNativeTabs = {
	initialized = false,
}
_G.PluribusHiveNativeTabs = PluribusHiveNativeTabs

local function RenderGuildDrawer(drawer, mode)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local c = drawer.scrollContent
	UI:ClearContainer(c)
	drawer.activeMode = mode

	local y = -4
	local w = 304

	if mode == "live" then
		drawer.titleLbl:SetText("|cff38bdf8Pluribus Guild Hive & LFG|r")

		if _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBanner then
			local banner = _G.PluribusHiveUI:CreateHealthBanner(c, w, function()
				RenderGuildDrawer(drawer, "live")
			end)
			if banner then
				banner:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
				y = y - 82
			end
		end

		-- Quick Smart LFG post bar right inside the Guild window
		local lfgLbl = UI:CreateLabel(c, "|cff38bdf8Post Smart Guild LFG:|r", 1, 1, 1)
		lfgLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		y = y - 18

		local actBox = UI:CreateInputBox(c, 162, 22)
		actBox:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		actBox:SetText("Dungeon / Group")

		local roleBox = UI:CreateInputBox(c, 58, 22)
		roleBox:SetPoint("LEFT", actBox, "RIGHT", 4, 0)
		roleBox:SetText("ANY")

		local postBtn = UI:CreateButton(c, "Post", 68, 22, function()
			if _G.PluribusHiveLFG then
				_G.PluribusHiveLFG:PostLFG(actBox:GetText(), roleBox:GetText())
				RenderGuildDrawer(drawer, "live")
			end
		end, true)
		postBtn:SetPoint("LEFT", roleBox, "RIGHT", 4, 0)
		y = y - 30

		-- Active Smart LFG posts
		local posts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}
		if #posts > 0 then
			local pHdr = UI:CreateLabel(c, "|cfffbbf24Active Guild LFG (" .. #posts .. "):|r")
			pHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
			y = y - 18
			for idx, post in ipairs(posts) do
				local row = UI:CreateListRow(c, w, 30, idx, function()
					if SendChatMessage and post.sender ~= PluribusHive:GetPlayerShortName() then
						pcall(SendChatMessage, "Hey! Invite for " .. post.activity .. "?", "WHISPER", nil, post.sender)
					end
				end)
				row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
				local l1 = UI:CreateLabel(row, "|cff38bdf8" .. post.sender .. ":|r " .. tostring(post.activity):sub(1, 24))
				l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
				local l2 = UI:CreateLabel(row, "Lv " .. (post.minLevel or 1) .. "-" .. (post.maxLevel or 60) .. " · Click to whisper", 0.65, 0.78, 0.90, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
				y = y - 32
			end
			y = y - 6
		end

		-- Online Hive Guild Members (click to view bags!)
		local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
		local mHdr = UI:CreateLabel(c, "|cff4ade80Online Hive Peers (" .. #members .. ") — Click to inspect bags:|r")
		mHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		y = y - 18
		for idx, m in ipairs(members) do
			local row = UI:CreateListRow(c, w, 24, idx, function()
				if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer(m.name) end
			end)
			row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
			local _, _, _, hex = UI:GetClassColor(m.class)
			local lbl = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d %s|r", hex, m.name, m.level or 60, m.role or ""))
			lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
			local zLbl = UI:CreateLabel(row, tostring(m.zone or ""):sub(1, 16), 0.72, 0.80, 0.90, "GameFontHighlightSmall")
			zLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 26
		end
	elseif mode == "cooldowns" then
		drawer.titleLbl:SetText("|cff38bdf8Guild & Raid Cooldowns|r")

		local stripBtn = UI:CreateButton(c, "Toggle Floating Cooldown Strip", w - 4, 24, function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
		end, true)
		stripBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		y = y - 32

		local active = (_G.PluribusHiveCooldowns and _G.PluribusHiveCooldowns:GetActiveCooldowns()) or {}
		for _, cd in ipairs(active) do
			local r, g, b = UI:GetClassColor(cd.class)
			local bar = UI:CreateStatusBar(c, w, 22, r, g, b)
			bar:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
			local pct = math.max(0, math.min(100, (cd.remaining / math.max(1, cd.duration)) * 100))
			local est = cd.estimated and " [Est]" or ""
			bar:SetBarData(pct, string.format("%s — %s%s", cd.player, cd.name, est), PluribusUtils:FormatTime(cd.remaining), r, g, b)
			y = y - 26
		end
		if #active == 0 then
			local empty = UI:CreateLabel(c, "All tracked major guild cooldowns are READY!\nMajor casts (Rebirth, Shield Wall, Innervate, Soulstone, Lust) sync automatically.", 0.68, 0.76, 0.86)
			empty:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y - 4)
			empty:SetWidth(w - 12)
		end
	end

	c:SetHeight(math.max(320, math.abs(y) + 12))
end

function PluribusHiveNativeTabs:AttachToGuildWindow(host, key)
	if not host or host._plbGuildTabsAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	host._plbGuildTabsAttached = true

	local UI = _G.PluribusUIFramework

	local drawer = CreateFrame("Frame", "PluribusGuildDrawer_" .. tostring(key or "guild"), host, BackdropTemplateMixin and "BackdropTemplate" or nil)
	drawer:SetSize(340, 412)
	drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", 48, -16)
	drawer:SetFrameStrata(host:GetFrameStrata() or "HIGH")
	drawer:SetFrameLevel((host:GetFrameLevel() or 5) + 10)
	drawer._plbDrawer = true
	UI:ApplyBackdrop(drawer, 0.06, 0.08, 0.13, 0.97, 0.22, 0.30, 0.42, 0.95)

	local titleLbl = UI:CreateLabel(drawer, "Pluribus Guild Hive", 0.22, 0.74, 0.97, "GameFontNormal")
	titleLbl:SetPoint("TOPLEFT", drawer, "TOPLEFT", 12, -10)
	drawer.titleLbl = titleLbl

	local closeBtn = UI:CreateButton(drawer, "X", 22, 20, function()
		drawer:Hide()
		for _, t in pairs(host._plbGuildTabs or {}) do t:SetActiveState(false) end
	end)
	closeBtn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -8, -8)

	local scroll = UI:CreateScrollFrame(drawer, "PluribusGuildDrawerScroll_" .. tostring(key or "guild"), 324, 366)
	scroll:SetPoint("TOPLEFT", drawer, "TOPLEFT", 8, -36)
	drawer.scrollContent = scroll.content
	drawer:Hide()

	local tabs = {}
	host._plbGuildTabs = tabs

	local function ToggleDrawer(mode)
		if drawer:IsVisible() and drawer.activeMode == mode then
			drawer:Hide()
			for _, t in pairs(tabs) do t:SetActiveState(false) end
			return
		end
		for k, t in pairs(tabs) do t:SetActiveState(k == mode) end
		drawer:Show()
		RenderGuildDrawer(drawer, mode)
	end

	tabs.live = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\Spell_Nature_AstralRecalGroup",
		title = "Pluribus Hive Live & LFG",
		tooltip = "Live HiveMind health, online peers, and Smart Guild LFG matching.",
		yOffset = -278,
		onClick = function() ToggleDrawer("live") end,
	})

	tabs.bags = UI:CreateSideTab(host, 2, {
		icon = "Interface\\Icons\\INV_Misc_Bag_08",
		title = "Guild & Alt Bags Viewer",
		tooltip = "Open unified Bags & Bank viewer for You, Alts & sharing Guildmates.",
		yOffset = -322,
		onClick = function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer() end
		end,
	})

	tabs.mail = UI:CreateSideTab(host, 3, {
		icon = "Interface\\Icons\\INV_Letter_15",
		title = "Guild Mail & Letters",
		tooltip = "Open Guild Mail inbox, offline messages, and letter composer.",
		yOffset = -366,
		onClick = function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guild Mail")
			end
		end,
	})

	tabs.tax = UI:CreateSideTab(host, 4, {
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		title = "Guild Tax Vault",
		tooltip = "Open Guild Treasury Tax ledger, auto-tracking & banker payments.",
		yOffset = -410,
		onClick = function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guild Tax")
			end
		end,
	})

	local orderedGuildTabs = { tabs.live, tabs.bags, tabs.mail, tabs.tax }
	local function RelayoutGuild()
		-- Start safely below Blizzard's 4 right-edge native Guild/Communities tabs (-65 to -255)
		UI:LayoutSideTabs(host, orderedGuildTabs, {
			preferredY = -278,
			minYOffset = -278,
			spacing = 44,
			drawer = drawer,
			drawerGap = 48,
			drawerYOffset = -24,
		})
	end
	RelayoutGuild()
	if host.HookScript then
		pcall(host.HookScript, host, "OnShow", function()
			RelayoutGuild()
			if C_Timer and C_Timer.After then C_Timer.After(0.05, RelayoutGuild) end
		end)
	end
end

local function RenderQuestDrawer(drawer)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local c = drawer.scrollContent
	UI:ClearContainer(c)

	local y = -4
	local w = 294

	local overlaps = (_G.PluribusHiveDistress and _G.PluribusHiveDistress:GetGuildmatesOnSameQuest()) or {}
	local qHdr = UI:CreateLabel(c, "|cff4ade80Guildmates on Your Active Quests (" .. #overlaps .. "):|r")
	qHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
	y = y - 20

	for idx, o in ipairs(overlaps) do
		local row = UI:CreateListRow(c, w, 34, idx, function()
			if SendChatMessage then
				pcall(SendChatMessage, "Hey! Want to team up for '" .. tostring(o.questTitle) .. "'?", "WHISPER", nil, o.member)
			end
		end)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		local l1 = UI:CreateLabel(row, "|cffffffff" .. tostring(o.member) .. "|r  |cff94a3b8(" .. tostring(o.zone) .. ")|r")
		l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		local l2 = UI:CreateLabel(row, tostring(o.questTitle):sub(1, 34) .. " · Click to whisper", 0.66, 0.90, 0.74, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)
		y = y - 36
	end
	if #overlaps == 0 then
		local empty = UI:CreateLabel(c, "No online guildmates currently share your active quests.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y)
		y = y - 24
	end

	y = y - 10
	local db = PluribusHive:GetDB()
	local rares = {}
	local now = time()
	for _, r in pairs(db.rares or {}) do
		if (now - (r.seenAt or 0)) <= 3600 then
			table.insert(rares, r)
		end
	end
	table.sort(rares, function(a, b) return (a.seenAt or 0) > (b.seenAt or 0) end)

	local rHdr = UI:CreateLabel(c, "|cfffbbf24Recently Spotted Guild Rares (" .. #rares .. "):|r")
	rHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
	y = y - 20

	for idx, r in ipairs(rares) do
		local row = UI:CreateListRow(c, w, 34, idx, function()
			if _G.PluribusHiveDistress then
				_G.PluribusHiveDistress:SetRescueWaypoint(r.mapID, r.x, r.y, r.name)
			end
		end)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		local l1 = UI:CreateLabel(row, "|cfffbbf24" .. tostring(r.name) .. "|r  |cff94a3b8(" .. tostring(r.zone) .. ")|r")
		l1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		local l2 = UI:CreateLabel(row, string.format("Spotted by %s (%.1f, %.1f) · Click for Waypoint", r.spottedBy or "?", (r.x or 0) * 100, (r.y or 0) * 100), 0.74, 0.82, 0.90, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)
		y = y - 36
	end
	if #rares == 0 then
		local empty = UI:CreateLabel(c, "Target any rare mob or world boss in the open world to broadcast it to your guild!", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y)
		empty:SetWidth(w - 12)
		y = y - 30
	end

	c:SetHeight(math.max(300, math.abs(y) + 12))
end

function PluribusHiveNativeTabs:AttachToQuestWindow(host, key)
	if not host or host._plbQuestTabAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	host._plbQuestTabAttached = true

	local UI = _G.PluribusUIFramework
	local drawer = CreateFrame("Frame", "PluribusQuestDrawer_" .. tostring(key or "quest"), host, BackdropTemplateMixin and "BackdropTemplate" or nil)
	drawer:SetSize(330, 396)
	drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", 48, -16)
	drawer:SetFrameStrata(host:GetFrameStrata() or "HIGH")
	drawer:SetFrameLevel((host:GetFrameLevel() or 5) + 10)
	drawer._plbDrawer = true
	UI:ApplyBackdrop(drawer, 0.06, 0.08, 0.13, 0.97, 0.22, 0.30, 0.42, 0.95)

	local titleLbl = UI:CreateLabel(drawer, "|cff4ade80Pluribus Guild Quests & Rares|r", 1, 1, 1, "GameFontNormal")
	titleLbl:SetPoint("TOPLEFT", drawer, "TOPLEFT", 12, -10)

	local closeBtn = UI:CreateButton(drawer, "X", 22, 20, function()
		drawer:Hide()
		if host._plbQuestSideTab then host._plbQuestSideTab:SetActiveState(false) end
	end)
	closeBtn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -8, -8)

	local scroll = UI:CreateScrollFrame(drawer, "PluribusQuestDrawerScroll_" .. tostring(key or "quest"), 314, 350)
	scroll:SetPoint("TOPLEFT", drawer, "TOPLEFT", 8, -36)
	drawer.scrollContent = scroll.content
	drawer:Hide()

	local tab = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Misc_Map_01",
		title = "Guild Same-Quest & Rares",
		tooltip = "See guildmates working on your current quests & recently spotted rares.",
		yOffset = -56,
		onClick = function(selfTab)
			if drawer:IsVisible() then
				drawer:Hide()
				selfTab:SetActiveState(false)
			else
				drawer:Show()
				selfTab:SetActiveState(true)
				RenderQuestDrawer(drawer)
			end
		end,
	})
	host._plbQuestSideTab = tab
	local function RelayoutQuest()
		UI:LayoutSideTabs(host, { tab }, {
			preferredY = -56,
			minYOffset = -56,
			spacing = 44,
			drawer = drawer,
			drawerGap = 48,
			drawerYOffset = -16,
		})
	end
	RelayoutQuest()
	if host.HookScript then
		pcall(host.HookScript, host, "OnShow", function()
			RelayoutQuest()
			if C_Timer and C_Timer.After then C_Timer.After(0.05, RelayoutQuest) end
		end)
	end
end

-- ============================================================================
-- Dungeon Finder (PVEFrame / LFGParentFrame / GroupFinderFrame) Smart Guild LFG Tab
-- ============================================================================

local DUNGEON_PRESETS = {
	{ key = "Deadmines / WC",      label = "Deadmines / WC (18-24)" },
	{ key = "Scarlet Monastery",   label = "Scarlet Monastery (30-42)" },
	{ key = "Zul'Farrak",          label = "Zul'Farrak (42-48)" },
	{ key = "Maraudon / ST",       label = "Maraudon / Sunken Temple (46-54)" },
	{ key = "Blackrock Depths",    label = "Blackrock Depths (52-60)" },
	{ key = "LBRS / UBRS",         label = "LBRS / UBRS (56-60)" },
	{ key = "Stratholme",          label = "Stratholme Live / UD (58-60)" },
	{ key = "Scholomance",         label = "Scholomance (58-60)" },
	{ key = "Dire Maul",           label = "Dire Maul E / W / N (56-60)" },
	{ key = "ZG / AQ20",           label = "Zul'Gurub / AQ20 (60 Raid)" },
	{ key = "MC / Onyxia / BWL",   label = "MC / Onyxia / BWL (60 Raid)" },
}

local ROLE_PRESETS = {
	{ key = "ANY",    label = "Any Role" },
	{ key = "TANK",   label = "Need Tank" },
	{ key = "HEALER", label = "Need Healer" },
	{ key = "DPS",    label = "Need DPS" },
}

local function RenderDungeonFinderDrawer(drawer)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local c = drawer.scrollContent
	UI:ClearContainer(c)

	local w = 312
	local y = -4

	local chosenDungeon = drawer.selectedDungeon or "Stratholme"
	local chosenRole = drawer.selectedRole or "ANY"

	local hdr = UI:CreateLabel(c, "|cff38bdf8Post Smart Guild LFG (Auto-Matches Roles & Levels):|r", 1, 1, 1, "GameFontHighlightSmall")
	hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
	y = y - 18

	local dDrop = UI:CreateFlatDropdown(c, 198, 24, DUNGEON_PRESETS, chosenDungeon, function(val)
		drawer.selectedDungeon = val
	end)
	dDrop:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

	local rDrop = UI:CreateFlatDropdown(c, 108, 24, ROLE_PRESETS, chosenRole, function(val)
		drawer.selectedRole = val
	end)
	rDrop:SetPoint("LEFT", dDrop, "RIGHT", 6, 0)
	y = y - 30

	local noteBox = UI:CreateInputBox(c, 222, 22)
	noteBox:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
	noteBox:SetText(drawer.customNote or "")

	local postBtn = UI:CreateButton(c, "Post LFG", 84, 22, function()
		local note = (noteBox:GetText() or ""):match("^%s*(.-)%s*$")
		drawer.customNote = note
		local act = drawer.selectedDungeon or chosenDungeon
		if note ~= "" then act = act .. " (" .. note .. ")" end
		if _G.PluribusHiveLFG and _G.PluribusHiveLFG.PostLFG then
			_G.PluribusHiveLFG:PostLFG(act, drawer.selectedRole or chosenRole)
		end
		RenderDungeonFinderDrawer(drawer)
	end, true)
	postBtn:SetPoint("LEFT", noteBox, "RIGHT", 6, 0)
	y = y - 32

	-- Active Smart Guild LFG posts
	local posts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}
	local pHdr = UI:CreateLabel(c, "|cfffbbf24Active Guild Groups (" .. #posts .. "):|r")
	pHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
	y = y - 18

	local me = _G.PluribusHive and _G.PluribusHive:GetPlayerShortName() or ""
	for idx, post in ipairs(posts) do
		local row = UI:CreateListRow(c, w, 36, idx)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

		local cIcon = UI:CreateClassIcon(row, post.class or "WARRIOR", 22)
		cIcon:SetPoint("LEFT", row, "LEFT", 5, 0)

		local l1 = UI:CreateLabel(row, "|cff38bdf8" .. tostring(post.sender) .. "|r: " .. tostring(post.activity):sub(1, 22))
		l1:SetPoint("TOPLEFT", cIcon, "TOPRIGHT", 6, -1)
		l1:SetPoint("RIGHT", row, "RIGHT", -104, 0)
		if l1.SetWordWrap then l1:SetWordWrap(false) end

		local l2 = UI:CreateLabel(row, string.format("Lv %d-%d · Need: %s", post.minLevel or 1, post.maxLevel or 60, tostring(post.neededRole or "ANY")), 0.65, 0.78, 0.90, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", cIcon, "BOTTOMRIGHT", 6, 1)
		l2:SetPoint("RIGHT", row, "RIGHT", -104, 0)
		if l2.SetWordWrap then l2:SetWordWrap(false) end

		if post.sender ~= me then
			local invBtn = UI:CreateButton(row, "Inv", 36, 20, function()
				if InviteUnit then pcall(InviteUnit, post.sender)
				elseif C_PartyInfo and C_PartyInfo.InviteUnit then pcall(C_PartyInfo.InviteUnit, post.sender) end
			end)
			invBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

			local wspBtn = UI:CreateButton(row, "Whisper", 56, 20, function()
				if SendChatMessage then
					pcall(SendChatMessage, "Hey! Invite for " .. tostring(post.activity) .. "?", "WHISPER", nil, post.sender)
				end
			end, true)
			wspBtn:SetPoint("RIGHT", invBtn, "LEFT", -4, 0)
		end
		y = y - 38
	end
	if #posts == 0 then
		local empty = UI:CreateLabel(c, "No active Guild LFG listings yet. Pick a dungeon above and click 'Post LFG' to alert matching guildmates!", 0.65, 0.74, 0.84)
		empty:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		empty:SetWidth(w - 8)
		y = y - 34
	end

	y = y - 6
	local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
	local mHdr = UI:CreateLabel(c, "|cff4ade80Online Guildmates Ready to Group (" .. #members .. "):|r")
	mHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
	y = y - 18

	for idx, m in ipairs(members) do
		local row = UI:CreateListRow(c, w, 26, idx, function()
			if not m.isSelf and InviteUnit then pcall(InviteUnit, m.name) end
		end)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		local cIcon = UI:CreateClassIcon(row, m.class, 18)
		cIcon:SetPoint("LEFT", row, "LEFT", 5, 0)
		local _, _, _, hex = UI:GetClassColor(m.class)
		local lbl = UI:CreateLabel(row, string.format("%s%s|r |cff94a3b8Lv%d %s|r", hex, m.name, m.level or 60, m.role or ""))
		lbl:SetPoint("LEFT", cIcon, "RIGHT", 6, 0)
		lbl:SetPoint("RIGHT", row, "RIGHT", -84, 0)
		if lbl.SetWordWrap then lbl:SetWordWrap(false) end

		local zLbl = UI:CreateLabel(row, tostring(m.zone or ""):sub(1, 14), 0.70, 0.80, 0.90, "GameFontHighlightSmall")
		zLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		y = y - 28
	end

	c:SetHeight(math.max(320, math.abs(y) + 12))
end

function PluribusHiveNativeTabs:AttachToDungeonFinder(host, key)
	if not host or host._plbLFGTabAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	host._plbLFGTabAttached = true

	local UI = _G.PluribusUIFramework
	local drawer = CreateFrame("Frame", "PluribusLFGDrawer_" .. tostring(key or "pve"), host, BackdropTemplateMixin and "BackdropTemplate" or nil)
	drawer:SetSize(348, 412)
	drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", 48, -16)
	drawer:SetFrameStrata(host:GetFrameStrata() or "HIGH")
	drawer:SetFrameLevel((host:GetFrameLevel() or 5) + 14)
	drawer._plbDrawer = true
	UI:ApplyBackdrop(drawer, 0.06, 0.08, 0.13, 0.98, 0.22, 0.74, 0.97, 0.95)

	local titleLbl = UI:CreateLabel(drawer, "|cff38bdf8Smart Guild LFG (Dungeon Finder)|r", 1, 1, 1, "GameFontNormal")
	titleLbl:SetPoint("TOPLEFT", drawer, "TOPLEFT", 12, -10)

	local closeBtn = UI:CreateButton(drawer, "X", 22, 20, function()
		drawer:Hide()
		if host._plbLFGSideTab then host._plbLFGSideTab:SetActiveState(false) end
	end)
	closeBtn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -8, -8)

	local scroll = UI:CreateScrollFrame(drawer, "PluribusLFGDrawerScroll_" .. tostring(key or "pve"), 332, 366)
	scroll:SetPoint("TOPLEFT", drawer, "TOPLEFT", 8, -36)
	drawer.scrollContent = scroll.content
	drawer:Hide()

	local tab = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Misc_GroupLooking",
		title = "Smart Guild LFG",
		tooltip = "Post & join Guild Dungeon/Raid groups right inside WoW's Dungeon Finder!",
		yOffset = -56,
		onClick = function(selfTab)
			if drawer:IsVisible() then
				drawer:Hide()
				selfTab:SetActiveState(false)
			else
				drawer:Show()
				selfTab:SetActiveState(true)
				RenderDungeonFinderDrawer(drawer)
			end
		end,
	})
	host._plbLFGSideTab = tab

	local function RelayoutLFG()
		local posts = (_G.PluribusHiveLFG and _G.PluribusHiveLFG:GetActivePosts()) or {}
		tab:SetBadge(#posts, 0.12, 0.62, 0.36)
		UI:LayoutSideTabs(host, { tab }, {
			preferredY = -56,
			minYOffset = -56,
			spacing = 44,
			drawer = drawer,
			drawerGap = 48,
			drawerYOffset = -16,
		})
	end
	RelayoutLFG()
	if host.HookScript then
		pcall(host.HookScript, host, "OnShow", function()
			RelayoutLFG()
			if C_Timer and C_Timer.After then C_Timer.After(0.05, RelayoutLFG) end
		end)
	end
end

function PluribusHiveNativeTabs:TryAttachAll()
	if _G.GuildFrame then self:AttachToGuildWindow(_G.GuildFrame, "guild") end
	if _G.CommunitiesFrame then self:AttachToGuildWindow(_G.CommunitiesFrame, "communities") end
	if _G.FriendsFrame then self:AttachToGuildWindow(_G.FriendsFrame, "friends") end
	if _G.QuestLogFrame then self:AttachToQuestWindow(_G.QuestLogFrame, "questlog") end
	if _G.PVEFrame then self:AttachToDungeonFinder(_G.PVEFrame, "pve") end
	if _G.LFGParentFrame then self:AttachToDungeonFinder(_G.LFGParentFrame, "lfgparent") end
	if _G.GroupFinderFrame then self:AttachToDungeonFinder(_G.GroupFinderFrame, "groupfinder") end
end

function PluribusHiveNativeTabs:Initialize()
	if self.initialized then return end
	self.initialized = true

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveNativeTabs:TryAttachAll()
		elseif event == "ADDON_LOADED" and (
			arg1 == "Blizzard_GuildUI"
			or arg1 == "Blizzard_Communities"
			or arg1 == "Blizzard_PVEUI"
			or arg1 == "Blizzard_LookingForGroupUI"
			or arg1 == "Blizzard_GroupFinder_VanillaStyle"
		) then
			PluribusHiveNativeTabs:TryAttachAll()
		end
	end)

	if hooksecurefunc then
		if _G.PVEFrame_ShowFrame then
			pcall(hooksecurefunc, "PVEFrame_ShowFrame", function()
				PluribusHiveNativeTabs:TryAttachAll()
			end)
		end
		if _G.ToggleLFGParentFrame then
			pcall(hooksecurefunc, "ToggleLFGParentFrame", function()
				PluribusHiveNativeTabs:TryAttachAll()
			end)
		end
	end
end

return PluribusHiveNativeTabs
