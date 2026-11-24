-- PluribusCore UI Framework
-- Top-of-the-line flat obsidian/light UI toolkit with BackdropTemplateMixin safety for WoW Forever (Interface 16001)

PluribusUIFramework = {
	theme = "obsidian",
	fonts = {},
	colors = {},
	windows = {},
}

PluribusUIFramework.CLASS_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43, "|cffc79c6e" },
	PALADIN = { 0.96, 0.55, 0.73, "|cfff58cba" },
	HUNTER  = { 0.67, 0.83, 0.45, "|cffabd473" },
	ROGUE   = { 1.00, 0.96, 0.41, "|cfffff569" },
	PRIEST  = { 1.00, 1.00, 1.00, "|cffffffff" },
	SHAMAN  = { 0.00, 0.44, 0.87, "|cff0070de" },
	MAGE    = { 0.41, 0.80, 0.94, "|cff69ccf0" },
	WARLOCK = { 0.58, 0.51, 0.79, "|cff9482c9" },
	DRUID   = { 1.00, 0.49, 0.04, "|cffff7d0a" },
}

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local FLAT_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function PluribusUIFramework:GetClassColor(className)
	local key = string.upper(tostring(className or "WARRIOR"):gsub("%s+", ""))
	local c = self.CLASS_COLORS[key] or { 0.22, 0.74, 0.97, "|cff38bdf8" }
	return c[1], c[2], c[3], c[4]
end

-- Safe Escape-to-close registration
function PluribusUIFramework:RegisterEscClose(frameName)
	if not frameName or type(UISpecialFrames) ~= "table" then return end
	for _, existing in ipairs(UISpecialFrames) do
		if existing == frameName then return end
	end
	table.insert(UISpecialFrames, frameName)
end

-- Safe backdrop helper compatible with WoW Classic / WoW Forever / Legacy clients
function PluribusUIFramework:ApplyBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
	if not frame then return end
	if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
		Mixin(frame, BackdropTemplateMixin)
	end
	if frame.SetBackdrop then
		frame:SetBackdrop(FLAT_BACKDROP)
		frame:SetBackdropColor(bgR or 0.07, bgG or 0.09, bgB or 0.13, bgA or 0.96)
		frame:SetBackdropBorderColor(borderR or 0.22, borderG or 0.28, borderB or 0.38, borderA or 0.9)
	else
		if not frame._plbBg then
			local bg = frame:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			frame._plbBg = bg
		end
		if frame._plbBg.SetColorTexture then
			frame._plbBg:SetColorTexture(bgR or 0.07, bgG or 0.09, bgB or 0.13, bgA or 0.96)
		else
			frame._plbBg:SetTexture(bgR or 0.07, bgG or 0.09, bgB or 0.13, bgA or 0.96)
		end
	end
end

-- Cleanly clear child frames and non-preserved regions inside a container
function PluribusUIFramework:ClearContainer(container)
	if not container then return end
	local children = { container:GetChildren() }
	for _, child in ipairs(children) do
		child:Hide()
		child:SetParent(nil)
	end
	local regions = { container:GetRegions() }
	for _, region in ipairs(regions) do
		if region and not region._plbPreserve then
			region:Hide()
		end
	end
end

function PluribusUIFramework:Initialize()
	if PluribusStorageManager and PluribusStorageManager.GetProfile then
		self.theme = PluribusStorageManager:GetProfile("theme", "obsidian")
	end
	self:LoadTheme(self.theme)
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("UI Framework initialized (" .. tostring(self.theme) .. ")", "UIFramework")
	end
end

function PluribusUIFramework:LoadTheme(themeName)
	self.theme = themeName or "obsidian"
	if PluribusStorageManager and PluribusStorageManager.SetProfile then
		PluribusStorageManager:SetProfile("theme", self.theme)
	end

	if self.theme == "light" then
		self:ApplyLightTheme()
	elseif self.theme == "classic" or self.theme == "default" then
		self:ApplyDefaultTheme()
	else
		self:ApplyDarkTheme()
	end

	if PluribusMessaging and PLURIBUS_EVENTS and PLURIBUS_EVENTS.UI_THEME_CHANGED then
		PluribusMessaging:Publish(PLURIBUS_EVENTS.UI_THEME_CHANGED, self.theme)
	end
end

function PluribusUIFramework:ApplyDefaultTheme()
	self.palette = {
		bg = { 0.06, 0.08, 0.12, 0.97 },
		header = { 0.10, 0.13, 0.19, 1.0 },
		panel = { 0.09, 0.12, 0.17, 0.96 },
		rowAlt = { 0.12, 0.15, 0.21, 0.85 },
		rowHover = { 0.16, 0.22, 0.32, 0.95 },
		border = { 0.22, 0.30, 0.42, 0.95 },
		accent = { 0.14, 0.50, 0.94, 1.0 },
		accentHover = { 0.22, 0.58, 1.00, 1.0 },
		gold = { 0.92, 0.72, 0.22, 1.0 },
		success = { 0.18, 0.76, 0.44, 1.0 },
		danger = { 0.88, 0.26, 0.28, 1.0 },
		text = { 0.95, 0.97, 1.0, 1.0 },
		muted = { 0.60, 0.68, 0.78, 1.0 },
	}
	self.colors = {
		primary = "|cff38bdf8",
		secondary = "|cff4ade80",
		gold = "|cfffbbf24",
		text = "|cffffffff",
		text_muted = "|cff94a3b8",
		success = "|cff4ade80",
		warning = "|cfffbbf24",
		error = "|cfff87171",
	}
end

function PluribusUIFramework:ApplyDarkTheme()
	self:ApplyDefaultTheme()
end

function PluribusUIFramework:ApplyLightTheme()
	self.palette = {
		bg = { 0.95, 0.96, 0.98, 0.98 },
		header = { 0.88, 0.91, 0.96, 1.0 },
		panel = { 1.0, 1.0, 1.0, 0.98 },
		rowAlt = { 0.93, 0.95, 0.98, 0.95 },
		rowHover = { 0.85, 0.90, 0.97, 1.0 },
		border = { 0.74, 0.79, 0.86, 1.0 },
		accent = { 0.11, 0.33, 0.86, 1.0 },
		accentHover = { 0.16, 0.41, 0.94, 1.0 },
		gold = { 0.80, 0.55, 0.08, 1.0 },
		success = { 0.12, 0.62, 0.34, 1.0 },
		danger = { 0.80, 0.20, 0.22, 1.0 },
		text = { 0.08, 0.11, 0.17, 1.0 },
		muted = { 0.38, 0.44, 0.54, 1.0 },
	}
	self.colors = {
		primary = "|cff1d4ed8",
		secondary = "|cff15803d",
		gold = "|cffb45309",
		text = "|cff0f172a",
		text_muted = "|cff64748b",
		success = "|cff16a34a",
		warning = "|cffd97706",
		error = "|cffdc2626",
	}
end

PluribusUIFramework:ApplyDefaultTheme()

-- Create a top-tier flat bordered window frame with accent hairline, draggable title bar & Escape close
function PluribusUIFramework:CreateFrame(name, parent, width, height, titleText, subtitleText)
	local p = self.palette
	local frame = CreateFrame("Frame", name, parent or UIParent, BACKDROP_TEMPLATE)
	frame:SetSize(width or 680, height or 480)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	self:ApplyBackdrop(frame, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local scale = self:GetUIScale()
	if scale and scale ~= 1.0 then
		pcall(frame.SetScale, frame, scale)
	end
	table.insert(self.windows, frame)

	if name then
		self:RegisterEscClose(name)
	end

	-- Top accent hairline
	local accentLine = frame:CreateTexture(nil, "OVERLAY")
	accentLine:SetHeight(2)
	accentLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	if accentLine.SetColorTexture then
		accentLine:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
	else
		accentLine:SetTexture(p.accent[1], p.accent[2], p.accent[3], 1)
	end
	accentLine._plbPreserve = true

	if titleText then
		local header = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
		header:SetHeight(36)
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -3)
		header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -3)
		self:ApplyBackdrop(header, p.header[1], p.header[2], p.header[3], p.header[4], p.border[1], p.border[2], p.border[3], 0.45)

		local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("LEFT", header, "LEFT", 12, 0)
		title:SetText(self.colors.primary .. titleText .. "|r")
		frame.titleText = title
		frame.header = header

		if subtitleText then
			local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
			sub:SetText(self.colors.text_muted .. subtitleText .. "|r")
			frame.subtitleText = sub
		end

		frame:SetMovable(true)
		frame:EnableMouse(true)
		header:EnableMouse(true)
		header:RegisterForDrag("LeftButton")
		header:SetScript("OnDragStart", function() frame:StartMoving() end)
		header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

		local closeBtn = self:CreateButton(header, "X", 24, 22, function()
			frame:Hide()
		end)
		closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
		frame.closeBtn = closeBtn
	end

	return frame
end

-- Create an elevated section card container
function PluribusUIFramework:CreateCard(parent, width, height, titleText)
	local p = self.palette
	local card = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	card:SetSize(width or 300, height or 140)
	self:ApplyBackdrop(card, p.panel[1], p.panel[2], p.panel[3], p.panel[4], p.border[1], p.border[2], p.border[3], 0.7)

	if titleText then
		local hdr = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hdr:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
		hdr:SetText(self.colors.gold .. titleText .. "|r")
		hdr._plbPreserve = true
		card.title = hdr
	end

	return card
end

-- Create a compact KPI metric tile
function PluribusUIFramework:CreateMetricTile(parent, width, height, labelText, valueText, colorHex)
	local card = self:CreateCard(parent, width or 140, height or 56)
	local val = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	val:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
	val:SetText((colorHex or self.colors.primary) .. tostring(valueText or "0") .. "|r")
	val._plbPreserve = true

	local lbl = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lbl:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
	lbl:SetText(self.colors.text_muted .. tostring(labelText or "") .. "|r")
	lbl._plbPreserve = true

	card.valueLabel = val
	card.nameLabel = lbl
	function card:SetValue(newVal, newColor)
		self.valueLabel:SetText((newColor or PluribusUIFramework.colors.primary) .. tostring(newVal) .. "|r")
	end
	return card
end

-- Create a real WoW StatusBar (for DPS/HPS meters, Boss Timers, Healer Bars, Skill Progress)
function PluribusUIFramework:CreateStatusBar(parent, width, height, r, g, b)
	local p = self.palette
	local holder = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	holder:SetSize(width or 300, height or 22)
	self:ApplyBackdrop(holder, 0.04, 0.06, 0.09, 0.95, p.border[1], p.border[2], p.border[3], 0.65)

	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar:SetStatusBarColor(r or p.accent[1], g or p.accent[2], b or p.accent[3], 0.92)

	local leftText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leftText:SetPoint("LEFT", bar, "LEFT", 7, 0)
	leftText:SetJustifyH("LEFT")

	local rightText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rightText:SetPoint("RIGHT", bar, "RIGHT", -7, 0)
	rightText:SetJustifyH("RIGHT")

	holder.bar = bar
	holder.leftText = leftText
	holder.rightText = rightText

	function holder:SetBarData(pct, leftStr, rightStr, cr, cg, cb)
		self.bar:SetValue(math.max(0, math.min(100, pct or 0)))
		if cr and cg and cb then
			self.bar:SetStatusBarColor(cr, cg, cb, 0.92)
		end
		if leftStr ~= nil then self.leftText:SetText(leftStr) end
		if rightStr ~= nil then self.rightText:SetText(rightStr) end
	end

	return holder
end

-- Create a unified horizontal tab bar with active state indicator
function PluribusUIFramework:CreateTabBar(parent, tabs, onSelect, totalWidth)
	local p = self.palette
	local bar = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	bar:SetSize(totalWidth or 640, 30)
	self:ApplyBackdrop(bar, p.header[1], p.header[2], p.header[3], 0.75, p.border[1], p.border[2], p.border[3], 0.5)

	bar.buttons = {}
	local count = math.max(1, #(tabs or {}))
	local btnW = math.floor(((totalWidth or 640) - 8 - (count - 1) * 4) / count)

	for i, tab in ipairs(tabs or {}) do
		local btn = self:CreateButton(bar, tab.label or tab.name, btnW, 24, function()
			for key, b in pairs(bar.buttons) do
				b:SetActiveState(key == tab.key)
			end
			if onSelect then onSelect(tab.key) end
		end)
		btn:SetPoint("LEFT", bar, "LEFT", 4 + (i - 1) * (btnW + 4), 0)
		bar.buttons[tab.key] = btn
	end

	function bar:SelectTab(key)
		for k, b in pairs(self.buttons) do
			b:SetActiveState(k == key)
		end
		if onSelect then onSelect(key) end
	end

	return bar
end

function PluribusUIFramework:GetUIScale()
	if _G.PluribusHive and _G.PluribusHive.GetConfig then
		local sc = tonumber(_G.PluribusHive:GetConfig().uiScale)
		if sc and sc >= 0.65 and sc <= 1.5 then return sc end
	end
	return 1.0
end

function PluribusUIFramework:SetUIScale(scale)
	scale = math.max(0.7, math.min(1.4, tonumber(scale) or 1.0))
	if _G.PluribusHive and _G.PluribusHive.SetConfig then
		_G.PluribusHive:SetConfig("uiScale", scale)
	end
	for _, win in ipairs(self.windows or {}) do
		if win and win.SetScale then
			pcall(win.SetScale, win, scale)
		end
	end
end

-- Authentic Adventure-Guide / SpellBook-style right-edge vertical side bookmark tab
-- opts = { icon, title, tooltip, onClick, xOffset, yOffset, spacing, size }
function PluribusUIFramework:CreateSideTab(hostFrame, index, opts)
	if not hostFrame then return nil end
	opts = opts or {}
	local p = self.palette
	local size = opts.size or 38
	local spacing = opts.spacing or 46
	local xOff = opts.xOffset ~= nil and opts.xOffset or -1
	local yOff = opts.yOffset ~= nil and opts.yOffset or (-42 - ((index or 1) - 1) * spacing)

	local tab = CreateFrame("Button", nil, hostFrame, BACKDROP_TEMPLATE)
	tab:SetSize(size, size)
	tab:SetFrameLevel((hostFrame:GetFrameLevel() or 5) + 4)
	tab:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", xOff, yOff)
	tab._baseX = xOff
	tab._baseY = yOff
	tab._host = hostFrame
	tab._isActive = false
	tab._plbSideTab = true

	-- Subtle WoW SpellBook side-tab bookmark silhouette backing + flat dark border
	local bgTab = tab:CreateTexture(nil, "BACKGROUND")
	bgTab:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	bgTab:SetSize(size + 24, size + 24)
	bgTab:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 10)
	bgTab:SetVertexColor(0.24, 0.30, 0.42, 0.92)
	tab.bgTab = bgTab

	self:ApplyBackdrop(tab, 0.08, 0.11, 0.17, 0.96, p.border[1], p.border[2], p.border[3], 0.95)

	-- Active left-edge accent indicator bar
	local activeStripe = tab:CreateTexture(nil, "OVERLAY")
	activeStripe:SetWidth(3)
	activeStripe:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
	activeStripe:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1)
	if activeStripe.SetColorTexture then
		activeStripe:SetColorTexture(0.22, 0.74, 0.97, 1)
	else
		activeStripe:SetTexture("Interface\\Buttons\\WHITE8X8")
		activeStripe:SetVertexColor(0.22, 0.74, 0.97, 1)
	end
	activeStripe:Hide()
	tab.activeStripe = activeStripe

	-- Crisp WoW icon
	local icon = tab:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
	icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
	icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tab.icon = icon

	-- Hover glow
	local hl = tab:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(icon)
	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.55)

	-- Optional compact badge count in bottom-right corner
	local badgeBg = tab:CreateTexture(nil, "OVERLAY")
	badgeBg:SetSize(16, 13)
	badgeBg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
	if badgeBg.SetColorTexture then
		badgeBg:SetColorTexture(0.07, 0.52, 0.32, 0.95)
	else
		badgeBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		badgeBg:SetVertexColor(0.07, 0.52, 0.32, 0.95)
	end
	badgeBg:Hide()
	tab.badgeBg = badgeBg

	local badgeText = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	badgeText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
	badgeText:SetTextColor(1, 1, 1, 1)
	badgeText:Hide()
	tab.badgeText = badgeText

	function tab:SetBadge(count, r, g, b)
		local n = tonumber(count) or 0
		if n > 0 then
			local txt = n > 99 and "99+" or tostring(n)
			self.badgeText:SetText(txt)
			self.badgeBg:SetWidth(n > 9 and 20 or 15)
			if r and g and b then
				if self.badgeBg.SetColorTexture then
					self.badgeBg:SetColorTexture(r, g, b, 0.95)
				else
					self.badgeBg:SetVertexColor(r, g, b, 0.95)
				end
			end
			self.badgeBg:Show()
			self.badgeText:Show()
		else
			self.badgeBg:Hide()
			self.badgeText:Hide()
		end
	end

	function tab:SetActiveState(active)
		self._isActive = active == true
		local pal = PluribusUIFramework.palette
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", self._host, "TOPRIGHT", self._baseX + (self._isActive and 3 or 0), self._baseY)
		if self._isActive then
			PluribusUIFramework:ApplyBackdrop(self, 0.13, 0.24, 0.42, 0.98, 0.22, 0.74, 0.97, 1)
			self.bgTab:SetVertexColor(0.22, 0.62, 0.95, 0.98)
			self.activeStripe:Show()
		else
			PluribusUIFramework:ApplyBackdrop(self, 0.08, 0.11, 0.17, 0.96, pal.border[1], pal.border[2], pal.border[3], 0.92)
			self.bgTab:SetVertexColor(0.24, 0.30, 0.42, 0.90)
			self.activeStripe:Hide()
		end
	end

	tab:SetScript("OnEnter", function(selfTab)
		if not selfTab._isActive then
			PluribusUIFramework:ApplyBackdrop(selfTab, 0.12, 0.18, 0.28, 0.98, 0.38, 0.78, 1.0, 1)
		end
		if GameTooltip and (opts.title or opts.tooltip) then
			GameTooltip:SetOwner(selfTab, "ANCHOR_RIGHT")
			GameTooltip:AddLine("|cff38bdf8" .. tostring(opts.title or "Pluribus") .. "|r", 1, 1, 1)
			if opts.tooltip then
				GameTooltip:AddLine(tostring(opts.tooltip), 0.84, 0.90, 0.96, true)
			end
			GameTooltip:Show()
		end
	end)

	tab:SetScript("OnLeave", function(selfTab)
		selfTab:SetActiveState(selfTab._isActive)
		if GameTooltip then GameTooltip:Hide() end
	end)

	if opts.onClick then
		tab:SetScript("OnClick", function(selfTab, mouseBtn)
			opts.onClick(selfTab, mouseBtn)
		end)
	end

	return tab
end

-- Bagnon-style visual item icon slot with quality border, stack count, location badge & full WoW tooltip
-- itemData = { itemID, name, link, quality, icon, count, isBank, isSurplus, owner, extraTooltip }
function PluribusUIFramework:CreateItemSlot(parent, size, itemData, onClick)
	size = size or 38
	itemData = itemData or {}
	local slot = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	slot:SetSize(size, size)
	slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local q = itemData.quality or 1
	local qr, qg, qb = 0.30, 0.38, 0.50
	if q >= 2 or q == 0 then
		if _G.PluribusUtils and _G.PluribusUtils.GetQualityRGB then
			qr, qg, qb = _G.PluribusUtils:GetQualityRGB(q)
		end
	end
	self:ApplyBackdrop(slot, 0.05, 0.07, 0.11, 0.96, qr, qg, qb, q >= 2 and 0.95 or 0.72)

	local iconTex = itemData.icon or (_G.PluribusUtils and _G.PluribusUtils:GetItemIcon(itemData.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
	local icon = slot:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
	icon:SetTexture(iconTex)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	slot.icon = icon

	local hl = slot:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(icon)
	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.45)

	-- Stack count in bottom-right
	local count = tonumber(itemData.count) or 1
	if count > 1 then
		local cntBg = slot:CreateTexture(nil, "OVERLAY")
		cntBg:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
		cntBg:SetSize(count >= 100 and 24 or 17, 12)
		if cntBg.SetColorTexture then
			cntBg:SetColorTexture(0, 0, 0, 0.72)
		else
			cntBg:SetTexture("Interface\\Buttons\\WHITE8X8")
			cntBg:SetVertexColor(0, 0, 0, 0.72)
		end

		local cntLbl = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		cntLbl:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
		cntLbl:SetText(tostring(count))
		cntLbl:SetTextColor(1, 1, 1, 1)
		slot.countText = cntLbl
	end

	-- Bank indicator badge (top-left blue B)
	if itemData.isBank then
		local bTag = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bTag:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -2)
		bTag:SetText("|cff60a5faB|r")
	end

	-- Guild surplus indicator pip (top-right emerald dot when a guildmate needs this surplus mat)
	if itemData.isSurplus then
		local pip = slot:CreateTexture(nil, "OVERLAY")
		pip:SetSize(7, 7)
		pip:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -3, -3)
		if pip.SetColorTexture then
			pip:SetColorTexture(0.29, 0.87, 0.50, 1)
		else
			pip:SetTexture("Interface\\Buttons\\WHITE8X8")
			pip:SetVertexColor(0.29, 0.87, 0.50, 1)
		end
	end

	slot:SetScript("OnEnter", function(selfSlot)
		if GameTooltip then
			GameTooltip:SetOwner(selfSlot, "ANCHOR_RIGHT")
			local ok = _G.PluribusUtils and _G.PluribusUtils:SetTooltipItem(GameTooltip, itemData.itemID, itemData.link)
			if not ok then
				GameTooltip:AddLine(itemData.name or ("Item #" .. tostring(itemData.itemID or "?")), 1, 1, 1)
			end
			if itemData.extraTooltip then
				GameTooltip:AddLine(itemData.extraTooltip, 0.45, 0.82, 1.0, true)
			end
			GameTooltip:Show()
		end
	end)

	slot:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	slot:SetScript("OnClick", function(selfSlot, mouseBtn)
		if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then
			local link = itemData.link
			if not link and itemData.itemID and _G.PluribusUtils then
				local _, resolvedLink = _G.PluribusUtils:GetItemInfo(itemData.itemID)
				link = resolvedLink
			end
			if link then
				pcall(ChatEdit_InsertLink, link)
				return
			end
		end
		if onClick then
			onClick(selfSlot, mouseBtn, itemData)
		end
	end)

	return slot
end

-- Create a zebra-striped hoverable list row
function PluribusUIFramework:CreateListRow(parent, width, height, index, onclick)
	local p = self.palette
	local row = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	row:SetSize(width or 500, height or 26)
	local base = (index % 2 == 0) and p.rowAlt or p.panel
	self:ApplyBackdrop(row, base[1], base[2], base[3], base[4], p.border[1], p.border[2], p.border[3], 0.35)

	row:SetScript("OnEnter", function(selfRow)
		PluribusUIFramework:ApplyBackdrop(selfRow, p.rowHover[1], p.rowHover[2], p.rowHover[3], p.rowHover[4], p.accent[1], p.accent[2], p.accent[3], 0.8)
	end)
	row:SetScript("OnLeave", function(selfRow)
		PluribusUIFramework:ApplyBackdrop(selfRow, base[1], base[2], base[3], base[4], p.border[1], p.border[2], p.border[3], 0.35)
	end)
	if onclick then
		row:SetScript("OnClick", onclick)
	end
	return row
end

-- Sleek flat styled button with hover highlight
function PluribusUIFramework:CreateButton(parent, text, width, height, onclick, isPrimary)
	local p = self.palette
	local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	btn:SetSize(width or 110, height or 26)

	local base = isPrimary and p.accent or p.panel
	local hover = isPrimary and p.accentHover or p.rowHover
	self:ApplyBackdrop(btn, base[1], base[2], base[3], 1, p.border[1], p.border[2], p.border[3], 0.9)

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("CENTER")
	fs:SetText(text or "")
	if isPrimary then
		fs:SetTextColor(1, 1, 1, 1)
	else
		fs:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
	end
	btn.label = fs

	btn:SetScript("OnEnter", function(selfBtn)
		PluribusUIFramework:ApplyBackdrop(selfBtn, hover[1], hover[2], hover[3], 1, p.accent[1], p.accent[2], p.accent[3], 1)
	end)
	btn:SetScript("OnLeave", function(selfBtn)
		local activeBase = selfBtn._isActive and p.accent or base
		PluribusUIFramework:ApplyBackdrop(selfBtn, activeBase[1], activeBase[2], activeBase[3], 1, p.border[1], p.border[2], p.border[3], 0.9)
	end)

	function btn:SetActiveState(active)
		self._isActive = active
		local bg = active and p.accent or base
		PluribusUIFramework:ApplyBackdrop(self, bg[1], bg[2], bg[3], 1, p.border[1], p.border[2], p.border[3], 0.9)
		if active then
			self.label:SetTextColor(1, 1, 1, 1)
		else
			self.label:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
		end
	end

	if onclick then
		btn:SetScript("OnClick", onclick)
	end

	return btn
end

function PluribusUIFramework:CreateLabel(parent, text, r, g, b, fontObject)
	local p = self.palette
	local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
	label:SetText(text or "")
	label:SetJustifyH("LEFT")
	label:SetTextColor(r or p.text[1], g or p.text[2], b or p.text[3], 1)
	return label
end

function PluribusUIFramework:CreateInputBox(parent, width, height, onchange)
	local p = self.palette
	local input = CreateFrame("EditBox", nil, parent, BACKDROP_TEMPLATE)
	input:SetSize(width or 160, height or 24)
	input:SetAutoFocus(false)
	input:SetFontObject("ChatFontNormal")
	input:SetTextInsets(6, 6, 0, 0)
	self:ApplyBackdrop(input, 0.04, 0.06, 0.09, 1, p.border[1], p.border[2], p.border[3], 1)

	input:SetScript("OnEscapePressed", function(selfBox) selfBox:ClearFocus() end)
	input:SetScript("OnEnterPressed", function(selfBox) selfBox:ClearFocus() end)

	if onchange then
		input:SetScript("OnTextChanged", onchange)
	end

	return input
end

function PluribusUIFramework:CreateEditBox(parent, width, height)
	return self:CreateInputBox(parent, width, height)
end

function PluribusUIFramework:CreateDropdown(parent, options, selected, onchange)
	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	local function DropdownInit(_, level)
		for _, option in ipairs(options or {}) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option
			info.value = option
			info.func = function()
				UIDropDownMenu_SetSelectedValue(dropdown, option)
				if onchange then onchange(option) end
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end
	UIDropDownMenu_Initialize(dropdown, DropdownInit)
	UIDropDownMenu_SetSelectedValue(dropdown, selected or (options and options[1]))
	return dropdown
end

function PluribusUIFramework:CreateScrollFrame(parent, name, width, height)
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	scroll:SetSize(width, height)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width - 24, height)
	scroll:SetScrollChild(content)
	scroll.content = content
	return scroll
end

function PluribusUIFramework:CreateCheckbox(parent, text, checked, onchange)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetChecked(checked == true)
	if text then
		local label = self:CreateLabel(checkbox, text)
		label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
		checkbox.label = label
	end
	if onchange then
		checkbox:SetScript("OnClick", function(selfBox)
			onchange(selfBox:GetChecked() == true)
		end)
	end
	return checkbox
end

-- Draggable Minimap Suite Launcher Button
function PluribusUIFramework:CreateMinimapButton()
	if _G.PluribusMinimapButton or not Minimap then
		return _G.PluribusMinimapButton
	end

	local btn = CreateFrame("Button", "PluribusMinimapButton", Minimap, BACKDROP_TEMPLATE)
	btn:SetSize(30, 30)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, -4)
	self:ApplyBackdrop(btn, 0.08, 0.14, 0.24, 0.96, 0.22, 0.62, 0.98, 1)

	local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	txt:SetPoint("CENTER", 0, 0)
	txt:SetText("|cff38bdf8PLB|r")

	-- Compact live HiveMind connectivity beacon dot on bottom-right corner of minimap button
	local statusDot = btn:CreateTexture(nil, "OVERLAY")
	statusDot:SetSize(7, 7)
	statusDot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
	if statusDot.SetColorTexture then
		statusDot:SetColorTexture(0.29, 0.87, 0.50, 1)
	else
		statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
		statusDot:SetVertexColor(0.29, 0.87, 0.50, 1)
	end
	btn.statusDot = statusDot

	local function RefreshOrbDot()
		local h = (_G.PluribusHive and _G.PluribusHive.GetNetworkHealth) and _G.PluribusHive:GetNetworkHealth() or nil
		if h and h.color then
			if btn.statusDot.SetColorTexture then
				btn.statusDot:SetColorTexture(h.color[1], h.color[2], h.color[3], 1)
			else
				btn.statusDot:SetVertexColor(h.color[1], h.color[2], h.color[3], 1)
			end
		end
		return h
	end

	local orbTick = 0
	btn:SetScript("OnUpdate", function(_, elapsed)
		orbTick = orbTick + (elapsed or 0)
		if orbTick >= 3 then
			orbTick = 0
			RefreshOrbDot()
		end
	end)

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetMovable(true)
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", function(selfBtn) selfBtn:StartMoving() end)
	btn:SetScript("OnDragStop", function(selfBtn) selfBtn:StopMovingOrSizing() end)

	btn:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			if IsShiftKeyDown and IsShiftKeyDown() then
				if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Toggle then
					_G.PluribusOfficerDashboard:Toggle()
				end
			elseif _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
				_G.PluribusSettingsPanel:Open()
			elseif _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Toggle then
				_G.PluribusSettingsPanel:Toggle()
			end
		else
			if _G.PluribusMainFrame and _G.PluribusMainFrame.Toggle then
				_G.PluribusMainFrame:Toggle()
			end
		end
	end)

	btn:SetScript("OnEnter", function(selfBtn)
		local h = RefreshOrbDot()
		if GameTooltip then
			GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
			GameTooltip:AddLine("|cff38bdf8Pluribus Suite|r", 1, 1, 1)
			if h then
				GameTooltip:AddDoubleLine("HiveMind Network:", h.hex .. h.label .. " (" .. tostring(h.score or 0) .. "%)|r", 0.72, 0.80, 0.90, 1, 1, 1)
				GameTooltip:AddDoubleLine("Data Sync:", string.format("%d peers · %s · DB v%d", h.onlinePeers or 0, h.syncFreshness or "Never", h.dbRevision or 1), 0.72, 0.80, 0.90, 0.90, 0.95, 1)
				GameTooltip:AddLine(" ")
			end
			GameTooltip:AddLine("Left-Click: Open Guild Hive Hub (/pluribus)", 0.8, 0.9, 1)
			GameTooltip:AddLine("Right-Click: Pluribus Settings Menu", 0.8, 0.9, 1)
			GameTooltip:AddLine("Shift + Right-Click: Officer Dashboard (/officer)", 0.7, 0.8, 0.9)
			GameTooltip:AddLine("Drag: Reposition button", 0.6, 0.7, 0.8)
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	-- Respect saved minimap orb visibility immediately
	if _G.PluribusHive and _G.PluribusHive.GetConfig and _G.PluribusHive:GetConfig().showMinimapOrb == false then
		btn:Hide()
	end

	return btn
end

function PluribusUIFramework:ShowNotification(message, duration)
	duration = duration or 3.5
	local notif = self:CreateFrame(nil, UIParent, 360, 44)
	notif:SetPoint("TOP", UIParent, "TOP", 0, -90)
	local msgLabel = self:CreateLabel(notif, message, nil, nil, nil, "GameFontHighlight")
	msgLabel:SetPoint("CENTER")
	local expireAt = GetTime() + duration
	notif:SetScript("OnUpdate", function(selfFrame)
		if GetTime() >= expireAt then
			selfFrame:Hide()
			selfFrame:SetScript("OnUpdate", nil)
		end
	end)
	notif:Show()
	return notif
end

_G.PluribusUIFramework = PluribusUIFramework
return PluribusUIFramework
