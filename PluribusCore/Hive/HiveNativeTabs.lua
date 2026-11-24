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
	drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", 42, -16)
	drawer:SetFrameStrata("HIGH")
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
		yOffset = -52,
		onClick = function() ToggleDrawer("live") end,
	})

	tabs.bags = UI:CreateSideTab(host, 2, {
		icon = "Interface\\Icons\\INV_Misc_Bag_08",
		title = "Guild & Alt Bags Viewer",
		tooltip = "Browse Alts' and sharing Guildmates' bags & banks with icons and tooltips.",
		yOffset = -98,
		onClick = function()
			if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer() end
		end,
	})

	tabs.cooldowns = UI:CreateSideTab(host, 3, {
		icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
		title = "Guild Cooldowns",
		tooltip = "View shared & cast-estimated guild/raid cooldowns.",
		yOffset = -144,
		onClick = function() ToggleDrawer("cooldowns") end,
	})

	tabs.settings = UI:CreateSideTab(host, 4, {
		icon = "Interface\\Icons\\Trade_Engineering",
		title = "Pluribus Settings",
		tooltip = "Open all Pluribus Suite & HiveMind settings.",
		yOffset = -190,
		onClick = function()
			if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
				_G.PluribusSettingsPanel:Open()
			end
		end,
	})
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
	drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", 42, -16)
	drawer:SetFrameStrata("HIGH")
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
end

function PluribusHiveNativeTabs:TryAttachAll()
	if _G.GuildFrame then self:AttachToGuildWindow(_G.GuildFrame, "guild") end
	if _G.CommunitiesFrame then self:AttachToGuildWindow(_G.CommunitiesFrame, "communities") end
	if _G.FriendsFrame then self:AttachToGuildWindow(_G.FriendsFrame, "friends") end
	if _G.QuestLogFrame then self:AttachToQuestWindow(_G.QuestLogFrame, "questlog") end
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
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_GuildUI" or arg1 == "Blizzard_Communities") then
			PluribusHiveNativeTabs:TryAttachAll()
		end
	end)
end

return PluribusHiveNativeTabs
