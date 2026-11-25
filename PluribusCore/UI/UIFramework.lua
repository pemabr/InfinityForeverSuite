-- PluribusCore UI Framework
-- Top-of-the-line flat obsidian/light UI toolkit with BackdropTemplateMixin safety for WoW Forever (Interface 16001)

PluribusUIFramework = {
	theme = "obsidian",
	fonts = {},
	colors = {},
	windows = {},
	windowStack = {},
	WINDOW_BASE_LEVEL = 20,
	WINDOW_LEVEL_STRIDE = 40,
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

PluribusUIFramework.PROFESSION_ICONS = {
	Alchemy = "Interface\\Icons\\Trade_Alchemy",
	Blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
	Enchanting = "Interface\\Icons\\Trade_Engraving",
	Engineering = "Interface\\Icons\\Trade_Engineering",
	Herbalism = "Interface\\Icons\\Trade_Herbalism",
	Leatherworking = "Interface\\Icons\\INV_Misc_ArmorKit_17",
	Mining = "Interface\\Icons\\Trade_Mining",
	Skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
	Tailoring = "Interface\\Icons\\Trade_Tailoring",
	Cooking = "Interface\\Icons\\INV_Misc_Food_15",
	["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
	Fishing = "Interface\\Icons\\Trade_Fishing",
	Jewelcrafting = "Interface\\Icons\\INV_Misc_Gem_01",
	Inscription = "Interface\\Icons\\INV_Inscription_Tradeskill01",
}

local PROFESSION_ICON_ALIASES = {
	["alchemy"] = "Alchemy", ["alchemie"] = "Alchemy", ["alchimie"] = "Alchemy",
	["blacksmithing"] = "Blacksmithing", ["schmiedekunst"] = "Blacksmithing", ["schmieden"] = "Blacksmithing",
	["enchanting"] = "Enchanting", ["verzauberkunst"] = "Enchanting", ["verzaubern"] = "Enchanting",
	["engineering"] = "Engineering", ["ingenieurskunst"] = "Engineering",
	["herbalism"] = "Herbalism", ["kräuterkunde"] = "Herbalism", ["kraeuterkunde"] = "Herbalism",
	["leatherworking"] = "Leatherworking", ["lederverarbeitung"] = "Leatherworking",
	["mining"] = "Mining", ["bergbau"] = "Mining",
	["skinning"] = "Skinning", ["kürschnerei"] = "Skinning", ["kuerschnerei"] = "Skinning",
	["tailoring"] = "Tailoring", ["schneiderei"] = "Tailoring",
	["cooking"] = "Cooking", ["kochkunst"] = "Cooking", ["kochen"] = "Cooking",
	["first aid"] = "First Aid", ["erste hilfe"] = "First Aid",
	["fishing"] = "Fishing", ["angeln"] = "Fishing",
	["jewelcrafting"] = "Jewelcrafting", ["juwelenschleifen"] = "Jewelcrafting", ["juwelierskunst"] = "Jewelcrafting",
	["inscription"] = "Inscription", ["inschriftenkunde"] = "Inscription",
}

PluribusUIFramework.CLASS_ICON_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE    = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE   = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID   = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },
	SHAMAN  = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST  = { 0.49609375, 0.7421875, 0.25, 0.5 },
	WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

function PluribusUIFramework:GetProfessionIcon(profName)
	local raw = tostring(profName or ""):match("^%s*(.-)%s*$") or ""
	if self.PROFESSION_ICONS[raw] then
		return self.PROFESSION_ICONS[raw]
	end
	local canon = PROFESSION_ICON_ALIASES[raw:lower()]
	if canon and self.PROFESSION_ICONS[canon] then
		return self.PROFESSION_ICONS[canon]
	end
	return "Interface\\Icons\\INV_Misc_Book_09"
end

function PluribusUIFramework:CreateIconBadge(parent, iconPath, size, borderR, borderG, borderB)
	size = size or 24
	local holder = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	holder:SetSize(size, size)
	self:ApplyBackdrop(holder, 0.04, 0.06, 0.10, 0.96, borderR or 0.32, borderG or 0.56, borderB or 0.84, 0.92)
	local tex = holder:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
	tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
	tex:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	holder.icon = tex
	return holder
end

function PluribusUIFramework:CreateClassIcon(parent, className, size)
	size = size or 20
	local key = string.upper(tostring(className or "WARRIOR"):gsub("%s+", ""))
	local coords = self.CLASS_ICON_COORDS[key] or self.CLASS_ICON_COORDS.WARRIOR
	local r, g, b = self:GetClassColor(key)
	local holder = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	holder:SetSize(size, size)
	self:ApplyBackdrop(holder, 0.04, 0.06, 0.10, 0.95, r, g, b, 0.85)
	local tex = holder:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
	tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
	tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
	tex:SetTexCoord(coords[1] + 0.015, coords[2] - 0.015, coords[3] + 0.015, coords[4] - 0.015)
	holder.icon = tex
	return holder
end

function PluribusUIFramework:CreateProfessionIcon(parent, profName, size)
	return self:CreateIconBadge(parent, self:GetProfessionIcon(profName), size or 22, 0.85, 0.68, 0.22)
end

-- Rich graphical banner header card with framed WoW icon emblem, colored left accent stripe, title & subtitle
function PluribusUIFramework:CreateBannerCard(parent, width, height, iconPath, titleText, subtitleText, accentR, accentG, accentB, rightReserve)
	local ar, ag, ab = accentR or 0.22, accentG or 0.74, accentB or 0.97
	local reserve = rightReserve ~= nil and rightReserve or 16
	local card = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	card:SetSize(width or 700, height or 58)
	self:ApplyBackdrop(card, 0.07, 0.10, 0.16, 0.96, ar * 0.65, ag * 0.65, ab * 0.65, 0.88)

	-- Subtle decorative highlight wash
	local wash = card:CreateTexture(nil, "BACKGROUND")
	wash:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
	wash:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
	wash:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
	wash:SetBlendMode("ADD")
	wash:SetVertexColor(ar, ag, ab, 0.14)
	wash._plbPreserve = true

	-- Left accent bar
	local stripe = card:CreateTexture(nil, "OVERLAY")
	stripe:SetWidth(4)
	stripe:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
	stripe:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)
	if stripe.SetColorTexture then
		stripe:SetColorTexture(ar, ag, ab, 0.95)
	else
		stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
		stripe:SetVertexColor(ar, ag, ab, 0.95)
	end
	stripe._plbPreserve = true

	local iconSize = math.min(40, (height or 58) - 16)
	local badge = self:CreateIconBadge(card, iconPath or "Interface\\Icons\\Spell_Nature_AstralRecalGroup", iconSize, ar, ag, ab)
	badge:SetPoint("LEFT", card, "LEFT", 12, 0)
	card.badge = badge

	local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", badge, "TOPRIGHT", 10, -2)
	title:SetPoint("RIGHT", card, "RIGHT", -reserve, 0)
	title:SetJustifyH("LEFT")
	if title.SetWordWrap then title:SetWordWrap(false) end
	title:SetText(titleText or "")
	title._plbPreserve = true
	card.titleLabel = title

	local sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
	sub:SetPoint("RIGHT", card, "RIGHT", -reserve, 0)
	sub:SetJustifyH("LEFT")
	if sub.SetWordWrap then sub:SetWordWrap(false) end
	sub:SetTextColor(0.76, 0.84, 0.92, 1)
	sub:SetText(subtitleText or "")
	sub._plbPreserve = true
	card.subLabel = sub

	function card:SetRightReserve(px)
		local r = math.max(12, tonumber(px) or 16)
		self.titleLabel:ClearAllPoints()
		self.titleLabel:SetPoint("TOPLEFT", self.badge, "TOPRIGHT", 10, -2)
		self.titleLabel:SetPoint("RIGHT", self, "RIGHT", -r, 0)
		self.subLabel:ClearAllPoints()
		self.subLabel:SetPoint("TOPLEFT", self.titleLabel, "BOTTOMLEFT", 0, -3)
		self.subLabel:SetPoint("RIGHT", self, "RIGHT", -r, 0)
	end

	return card
end

-- Taint-free flat themed dropdown menu (no Blizzard UIDropDownMenu taint!)
-- options = { { key/value = "k", label = "Label", icon = "Interface\\Icons\\..." }, ... }
function PluribusUIFramework:CreateFlatDropdown(parent, width, height, options, selectedKey, onSelect, placeholder)
	width = width or 190
	height = height or 26
	options = options or {}

	local function OptKey(opt)
		if not opt then return nil end
		if opt.key ~= nil then return opt.key end
		return opt.value
	end

	local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	btn:SetSize(width, height)
	self:ApplyBackdrop(btn, 0.08, 0.12, 0.19, 0.98, 0.26, 0.46, 0.72, 0.95)

	local iconTex = btn:CreateTexture(nil, "ARTWORK")
	iconTex:SetSize(height - 8, height - 8)
	iconTex:SetPoint("LEFT", btn, "LEFT", 5, 0)
	iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	iconTex:Hide()
	btn.iconTex = iconTex

	local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lbl:SetPoint("LEFT", btn, "LEFT", 8, 0)
	lbl:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
	lbl:SetJustifyH("LEFT")
	if lbl.SetWordWrap then lbl:SetWordWrap(false) end
	btn.label = lbl

	local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	arrow:SetPoint("RIGHT", btn, "RIGHT", -7, 0)
	arrow:SetText("|cff38bdf8v|r")
	btn.arrow = arrow

	btn._options = options
	btn._selectedKey = selectedKey

	local function FindOpt(k)
		if k == nil then return nil end
		for _, opt in ipairs(btn._options) do
			if OptKey(opt) == k then return opt end
		end
		return nil
	end

	local function UpdateDisplay(k)
		local opt = FindOpt(k)
		if not opt and not placeholder then
			opt = btn._options[1]
		end
		btn._selectedKey = opt and OptKey(opt) or k
		if opt and opt.icon then
			iconTex:SetTexture(opt.icon)
			iconTex:Show()
			lbl:ClearAllPoints()
			lbl:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
			lbl:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
		else
			iconTex:Hide()
			lbl:ClearAllPoints()
			lbl:SetPoint("LEFT", btn, "LEFT", 8, 0)
			lbl:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
		end
		lbl:SetText(opt and opt.label or tostring(placeholder or k or "Select..."))
	end
	UpdateDisplay(selectedKey)

	function btn:SetSelected(k)
		UpdateDisplay(k)
	end

	local function CloseMenu()
		if PluribusUIFramework._activeDropdownMenu then
			PluribusUIFramework._activeDropdownMenu:Hide()
			PluribusUIFramework._activeDropdownMenu = nil
		end
	end

	btn:SetScript("OnMouseDown", function(selfBtn)
		PluribusUIFramework:BringOwnerToFront(selfBtn)
	end)

	btn:SetScript("OnClick", function(selfBtn)
		PluribusUIFramework:BringOwnerToFront(selfBtn)
		if selfBtn._menu and selfBtn._menu:IsShown() then
			CloseMenu()
			return
		end
		CloseMenu()

		local rowH = 24
		local maxVis = math.min(#selfBtn._options, 12)
		if maxVis == 0 then return end
		local menuH = maxVis * rowH + 8
		local menu = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
		menu:SetSize(math.max(width, 210), menuH)
		menu:SetPoint("TOPLEFT", selfBtn, "BOTTOMLEFT", 0, -2)
		menu:SetFrameStrata("TOOLTIP")
		menu:SetFrameLevel(200)
		menu:SetClampedToScreen(true)
		menu:EnableMouse(true)
		PluribusUIFramework:ApplyBackdrop(menu, 0.06, 0.09, 0.14, 0.99, 0.22, 0.74, 0.97, 1)

		for idx, opt in ipairs(selfBtn._options) do
			if idx > maxVis then break end
			local oKey = OptKey(opt)
			local itemBtn = CreateFrame("Button", nil, menu, BACKDROP_TEMPLATE)
			itemBtn:SetSize(math.max(width, 210) - 6, rowH - 2)
			itemBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -4 - (idx - 1) * rowH)
			local isSel = (oKey == selfBtn._selectedKey)
			if isSel then
				PluribusUIFramework:ApplyBackdrop(itemBtn, 0.14, 0.34, 0.58, 0.96, 0.22, 0.74, 0.97, 0.9)
			else
				PluribusUIFramework:ApplyBackdrop(itemBtn, 0.08, 0.11, 0.17, 0.85, 0.18, 0.24, 0.34, 0.4)
			end

			local textOffset = 8
			if opt.icon then
				local ic = itemBtn:CreateTexture(nil, "ARTWORK")
				ic:SetSize(16, 16)
				ic:SetPoint("LEFT", itemBtn, "LEFT", 6, 0)
				ic:SetTexture(opt.icon)
				ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				textOffset = 27
			end

			local txt = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			txt:SetPoint("LEFT", itemBtn, "LEFT", textOffset, 0)
			txt:SetPoint("RIGHT", itemBtn, "RIGHT", -6, 0)
			txt:SetJustifyH("LEFT")
			if txt.SetWordWrap then txt:SetWordWrap(false) end
			txt:SetText(isSel and ("|cff38bdf8" .. tostring(opt.label or oKey) .. "|r") or tostring(opt.label or oKey))

			itemBtn:SetScript("OnEnter", function(sb)
				PluribusUIFramework:ApplyBackdrop(sb, 0.16, 0.26, 0.42, 0.98, 0.22, 0.74, 0.97, 1)
			end)
			itemBtn:SetScript("OnLeave", function(sb)
				if oKey == selfBtn._selectedKey then
					PluribusUIFramework:ApplyBackdrop(sb, 0.14, 0.34, 0.58, 0.96, 0.22, 0.74, 0.97, 0.9)
				else
					PluribusUIFramework:ApplyBackdrop(sb, 0.08, 0.11, 0.17, 0.85, 0.18, 0.24, 0.34, 0.4)
				end
			end)
			itemBtn:SetScript("OnClick", function()
				UpdateDisplay(oKey)
				CloseMenu()
				if onSelect then onSelect(oKey, opt) end
			end)
		end

		menu:SetScript("OnHide", function()
			if PluribusUIFramework._activeDropdownMenu == menu then
				PluribusUIFramework._activeDropdownMenu = nil
			end
		end)
		selfBtn:HookScript("OnHide", function()
			if menu:IsShown() then menu:Hide() end
		end)

		selfBtn._menu = menu
		PluribusUIFramework._activeDropdownMenu = menu
		menu:Show()
	end)

	return btn
end

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

-- Cleanly clear child frames and non-preserved regions inside a container (preserves NineSlice & backdrops!)
function PluribusUIFramework:ClearContainer(container)
	if not container then return end
	local children = { container:GetChildren() }
	for _, child in ipairs(children) do
		if child and child ~= container.NineSlice and not child._plbPreserve then
			child:Hide()
			child:SetParent(nil)
		end
	end
	local regions = { container:GetRegions() }
	for _, region in ipairs(regions) do
		if region and not region._plbPreserve then
			local layer = region.GetDrawLayer and region:GetDrawLayer() or nil
			if layer ~= "BACKGROUND" then
				region:Hide()
			end
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

-- Recursive subtree frame-level propagation so overlapping Pluribus windows never mush together
local function ApplySubtreeLevels(frame, level, depth)
	if not frame or depth > 12 then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if frame._plbIgnoreStackLevel then return end
	if frame.IsProtected and frame:IsProtected() then return end
	if frame.SetFrameLevel then
		pcall(frame.SetFrameLevel, frame, level)
	end
	if not frame.GetChildren then return end
	local parentStrata = frame.GetFrameStrata and frame:GetFrameStrata() or nil
	local children = { frame:GetChildren() }
	for _, child in ipairs(children) do
		if child and not child._plbIgnoreStackLevel and not (child.IsProtected and child:IsProtected()) then
			local cStrata = child.GetFrameStrata and child:GetFrameStrata() or parentStrata
			if not parentStrata or cStrata == parentStrata then
				local offset = child._plbLevelOffset or 1
				ApplySubtreeLevels(child, level + offset, depth + 1)
			end
		end
	end
end

-- Raise a managed Pluribus window cleanly on top of all other open Pluribus windows
function PluribusUIFramework:BringToFront(frame)
	if not frame then return end
	if InCombatLockdown and InCombatLockdown() then return end
	local stack = self.windowStack
	for i = #stack, 1, -1 do
		if stack[i] == frame or stack[i] == nil then
			table.remove(stack, i)
		end
	end
	table.insert(stack, frame)

	local slot = 0
	for _, win in ipairs(stack) do
		if win and win.IsShown and win:IsShown() then
			slot = slot + 1
			local baseLevel = self.WINDOW_BASE_LEVEL + (slot - 1) * self.WINDOW_LEVEL_STRIDE
			ApplySubtreeLevels(win, baseLevel, 0)
		end
	end
	-- Also ensure the target window gets the top band if it is in the middle of showing
	if frame.IsShown and not frame:IsShown() then
		local topLevel = self.WINDOW_BASE_LEVEL + slot * self.WINDOW_LEVEL_STRIDE
		ApplySubtreeLevels(frame, topLevel, 0)
	end
end

-- Walk up the parent chain from any clicked child widget and raise its owning Pluribus window
function PluribusUIFramework:BringOwnerToFront(widget)
	local cur = widget
	local hops = 0
	while cur and hops < 16 do
		if cur._plbManagedWindow then
			self:BringToFront(cur)
			return cur
		end
		cur = cur.GetParent and cur:GetParent() or nil
		hops = hops + 1
	end
	return nil
end

-- Register any top-level Pluribus window for automatic Z-order layering on show, click, and drag
function PluribusUIFramework:RegisterWindow(frame, dragHandle)
	if not frame or frame._plbManagedWindow then return frame end
	frame._plbManagedWindow = true
	if frame.SetFrameStrata then
		pcall(frame.SetFrameStrata, frame, "HIGH")
	end
	-- Disable Blizzard's naive +1 SetToplevel so our 40-level bands never collapse into colliding levels
	if frame.SetToplevel then
		pcall(frame.SetToplevel, frame, false)
	end

	local foundWin = false
	for _, w in ipairs(self.windows) do
		if w == frame then foundWin = true break end
	end
	if not foundWin then
		table.insert(self.windows, frame)
	end
	table.insert(self.windowStack, frame)

	if frame.HookScript then
		pcall(frame.HookScript, frame, "OnShow", function(selfFrame)
			PluribusUIFramework:BringToFront(selfFrame)
		end)
		pcall(frame.HookScript, frame, "OnMouseDown", function(selfFrame)
			PluribusUIFramework:BringToFront(selfFrame)
		end)
	end

	if dragHandle and dragHandle ~= frame and dragHandle.HookScript then
		pcall(dragHandle.HookScript, dragHandle, "OnMouseDown", function()
			PluribusUIFramework:BringToFront(frame)
		end)
	end

	self:BringToFront(frame)
	return frame
end

-- Create a top-tier flat bordered window frame with accent hairline, draggable title bar, Z-order stacking & Escape close
function PluribusUIFramework:CreateFrame(name, parent, width, height, titleText, subtitleText)
	local p = self.palette
	local frame = CreateFrame("Frame", name, parent or UIParent, BACKDROP_TEMPLATE)
	frame:SetSize(width or 680, height or 480)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	self:ApplyBackdrop(frame, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local scale = self:GetUIScale()
	if scale and scale ~= 1.0 then
		pcall(frame.SetScale, frame, scale)
	end

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

	local header = nil
	if titleText then
		header = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
		header:SetHeight(38)
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -3)
		header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -3)
		header._plbLevelOffset = 2
		self:ApplyBackdrop(header, p.header[1], p.header[2], p.header[3], p.header[4], p.border[1], p.border[2], p.border[3], 0.55)

		-- Subtle arcane crest icon + glow wash in window header
		local hWash = header:CreateTexture(nil, "BACKGROUND")
		hWash:SetAllPoints(header)
		hWash:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
		hWash:SetBlendMode("ADD")
		hWash:SetVertexColor(0.22, 0.62, 0.95, 0.16)

		local crest = header:CreateTexture(nil, "ARTWORK")
		crest:SetSize(24, 24)
		crest:SetPoint("LEFT", header, "LEFT", 8, 0)
		crest:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\InfinityOrb")
		frame.headerCrest = crest

		local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("LEFT", crest, "RIGHT", 8, 0)
		title:SetText(self.colors.primary .. titleText .. "|r")
		frame.titleText = title
		frame.header = header

		if subtitleText then
			local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
			sub:SetWidth(math.max(90, (width or 680) - 440))
			sub:SetJustifyH("LEFT")
			if sub.SetWordWrap then sub:SetWordWrap(false) end
			sub:SetText(self.colors.text_muted .. subtitleText .. "|r")
			frame.subtitleText = sub
		end

		frame:SetMovable(true)
		header:EnableMouse(true)
		header:RegisterForDrag("LeftButton")
		header:SetScript("OnMouseDown", function()
			PluribusUIFramework:BringToFront(frame)
		end)
		header:SetScript("OnDragStart", function()
			PluribusUIFramework:BringToFront(frame)
			frame:StartMoving()
		end)
		header:SetScript("OnDragStop", function()
			frame:StopMovingOrSizing()
			PluribusUIFramework:BringToFront(frame)
		end)

		local closeBtn = self:CreateButton(header, "X", 24, 22, function()
			frame:Hide()
		end)
		closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
		frame.closeBtn = closeBtn
	end

	-- Register top-level UIParent windows in the Z-order manager so moving/clicking brings them cleanly on top
	if not parent or parent == UIParent then
		self:RegisterWindow(frame, header)
	else
		table.insert(self.windows, frame)
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

	local rightText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rightText:SetPoint("RIGHT", bar, "RIGHT", -7, 0)
	rightText:SetJustifyH("RIGHT")
	if rightText.SetWordWrap then rightText:SetWordWrap(false) end

	local leftText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leftText:SetPoint("LEFT", bar, "LEFT", 7, 0)
	leftText:SetPoint("RIGHT", rightText, "LEFT", -8, 0)
	leftText:SetJustifyH("LEFT")
	if leftText.SetWordWrap then leftText:SetWordWrap(false) end

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

-- Inspect a native WoW window (and its parent if nested, e.g. SkillFrame inside CharacterFrame)
-- to find the lowest visible native right-edge tab so Pluribus side tabs NEVER overlap native tabs
function PluribusUIFramework:FindSafeSideTabStartY(hostFrame, tabCount, spacing, preferredY, minYOffset)
	local startY = preferredY or -46
	if minYOffset and minYOffset < startY then
		startY = minYOffset
	end
	if not hostFrame or not hostFrame.GetTop or not hostFrame.GetRight then
		return startY
	end

	local hostTop = hostFrame:GetTop()
	local hostRight = hostFrame:GetRight()
	if not hostTop or not hostRight then
		return startY
	end

	local lowestRelBottom = nil
	local function scanChildrenOf(container)
		if not container or not container.GetChildren then return end
		local children = { container:GetChildren() }
		for _, child in ipairs(children) do
			if child and not child._plbSideTab and not child._plbDrawer and child.IsShown and child:IsShown() then
				local cLeft = child.GetLeft and child:GetLeft()
				local cRight = child.GetRight and child:GetRight()
				local cTop = child.GetTop and child:GetTop()
				local cBottom = child.GetBottom and child:GetBottom()
				local cH = (cTop and cBottom) and (cTop - cBottom) or 0
				local cW = (cLeft and cRight) and (cRight - cLeft) or 0
				-- Detect native side tabs / right-edge bookmarks protruding near or past hostRight
				if cLeft and cRight and cTop and cBottom and cH >= 18 and cH <= 90 and cW <= 90 then
					if cRight >= (hostRight - 14) and cLeft >= (hostRight - 58) then
						local relBottom = cBottom - hostTop
						if relBottom < -10 and (not lowestRelBottom or relBottom < lowestRelBottom) then
							lowestRelBottom = relBottom
						end
					end
				end
			end
		end
	end

	scanChildrenOf(hostFrame)
	local parent = hostFrame.GetParent and hostFrame:GetParent()
	if parent and parent ~= UIParent and parent ~= WorldFrame then
		scanChildrenOf(parent)
	end

	-- Also check known Blizzard SpellBook / TradeSkill / Guild / Communities / Dungeon Finder native side tabs
	local function checkNativeTab(tabObj)
		if not tabObj or not tabObj.IsShown or not tabObj:IsShown() then return end
		local cRight = tabObj.GetRight and tabObj:GetRight()
		local cBottom = tabObj.GetBottom and tabObj:GetBottom()
		if cRight and cBottom and cRight >= (hostRight - 28) then
			local relBottom = cBottom - hostTop
			if relBottom < -10 and (not lowestRelBottom or relBottom < lowestRelBottom) then
				lowestRelBottom = relBottom
			end
		end
	end

	for _, fieldName in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPerksTab", "RecruitmentTab", "GuildNewsTab" }) do
		if hostFrame[fieldName] then checkNativeTab(hostFrame[fieldName]) end
		if parent and parent[fieldName] then checkNativeTab(parent[fieldName]) end
	end

	for i = 1, 12 do
		for _, prefix in ipairs({ "SpellBookSkillLineTab", "TradeSkillFrameTab", "ProfessionsFrameTab", "GuildFrameTab", "CommunitiesFrameTab", "PVEFrameTab", "LFGParentFrameTab" }) do
			local gTab = _G[prefix .. i]
			if gTab and gTab.IsShown and gTab:IsShown() then
				local p = gTab.GetParent and gTab:GetParent()
				if p == hostFrame or p == parent then
					checkNativeTab(gTab)
				end
			end
		end
	end

	if lowestRelBottom then
		local belowNative = math.floor(lowestRelBottom - 14)
		if belowNative < startY then
			startY = belowNative
		end
	end

	return startY
end

-- Position a vertical list of Pluribus side tabs cleanly below any native right-edge tabs on hostFrame
function PluribusUIFramework:LayoutSideTabs(hostFrame, tabList, opts)
	if not hostFrame or not tabList or #tabList == 0 then return end
	opts = opts or {}
	local spacing = opts.spacing or 44
	local xOff = opts.xOffset ~= nil and opts.xOffset or 0
	local startY = self:FindSafeSideTabStartY(hostFrame, #tabList, spacing, opts.preferredY or -46, opts.minYOffset)

	for i, tab in ipairs(tabList) do
		if tab then
			local yPos = startY - (i - 1) * spacing
			tab._baseX = xOff
			tab._baseY = yPos
			tab:ClearAllPoints()
			tab:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", xOff + (tab._isActive and 3 or 0), yPos)
		end
	end

	-- Keep an associated drawer cleanly aligned to the right of the tab column without overlapping it
	if opts.drawer and tabList[1] then
		local drawerGap = opts.drawerGap or ((opts.size or 38) + 10)
		local drawerY = opts.drawerYOffset ~= nil and opts.drawerYOffset or math.max(-14, startY + 6)
		opts.drawer:ClearAllPoints()
		opts.drawer:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", xOff + drawerGap, drawerY)
	end

	return startY
end

-- Authentic Adventure-Guide / SpellBook-style right-edge vertical side bookmark tab
-- opts = { icon, title, tooltip, onClick, xOffset, yOffset, spacing, size }
function PluribusUIFramework:CreateSideTab(hostFrame, index, opts)
	if not hostFrame then return nil end
	opts = opts or {}
	local p = self.palette
	local size = opts.size or 38
	local spacing = opts.spacing or 44
	local xOff = opts.xOffset ~= nil and opts.xOffset or 0
	local yOff = opts.yOffset ~= nil and opts.yOffset or (-44 - ((index or 1) - 1) * spacing)

	local tab = CreateFrame("Button", nil, hostFrame, BACKDROP_TEMPLATE)
	tab:SetSize(size, size)
	tab._plbLevelOffset = 14
	tab:SetFrameLevel((hostFrame:GetFrameLevel() or 5) + 14)
	tab:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", xOff, yOff)
	tab._baseX = xOff
	tab._baseY = yOff
	tab._host = hostFrame
	tab._isActive = false
	tab._plbSideTab = true

	-- Pure flat obsidian bookmark tab (eliminates classic SpellBook parchment patchwork)
	self:ApplyBackdrop(tab, p.panel[1], p.panel[2], p.panel[3], 0.96, p.border[1], p.border[2], p.border[3], 0.95)

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
			self.activeStripe:Show()
		else
			PluribusUIFramework:ApplyBackdrop(self, pal.panel[1], pal.panel[2], pal.panel[3], 0.96, pal.border[1], pal.border[2], pal.border[3], 0.92)
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

	tab:SetScript("OnMouseDown", function(selfTab)
		PluribusUIFramework:BringOwnerToFront(selfTab)
	end)

	if opts.onClick then
		tab:SetScript("OnClick", function(selfTab, mouseBtn)
			PluribusUIFramework:BringOwnerToFront(selfTab)
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

	slot:SetScript("OnMouseDown", function(selfSlot)
		PluribusUIFramework:BringOwnerToFront(selfSlot)
	end)

	slot:SetScript("OnClick", function(selfSlot, mouseBtn)
		PluribusUIFramework:BringOwnerToFront(selfSlot)
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
	row:SetScript("OnMouseDown", function(selfRow)
		PluribusUIFramework:BringOwnerToFront(selfRow)
	end)
	if onclick then
		row:SetScript("OnClick", function(selfRow, mouseBtn)
			PluribusUIFramework:BringOwnerToFront(selfRow)
			onclick(selfRow, mouseBtn)
		end)
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

	btn:SetScript("OnMouseDown", function(selfBtn)
		PluribusUIFramework:BringOwnerToFront(selfBtn)
	end)

	if onclick then
		btn:SetScript("OnClick", function(selfBtn, mouseBtn)
			PluribusUIFramework:BringOwnerToFront(selfBtn)
			onclick(selfBtn, mouseBtn)
		end)
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

	input:SetScript("OnMouseDown", function(selfBox)
		PluribusUIFramework:BringOwnerToFront(selfBox)
	end)
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

-- Taint-free flat obsidian skinning for native Blizzard Container / Bank / GuildBank ItemButtons.
-- NEVER writes custom Lua fields onto the secure ItemButton itself!
function PluribusUIFramework:SkinFlatItemSlot(btn, overlay)
	if not btn then return end
	local p = self.palette
	local btnName = btn.GetName and btn:GetName() or nil

	-- Hide Blizzard's beveled classic quickslot / parchment normal & border textures
	local nt = (btn.GetNormalTexture and btn:GetNormalTexture()) or (btnName and _G[btnName .. "NormalTexture"])
	if nt then
		pcall(nt.SetTexture, nt, nil)
		pcall(nt.SetAlpha, nt, 0)
	end
	for _, region in ipairs({
		btn.IconBorder,
		btn.SlotBackground,
		btn.BattlepayItemTexture,
		btn.NewItemTexture,
		btn.BagIndicator,
		btnName and _G[btnName .. "IconQuestTexture"],
	}) do
		if region and region.SetAlpha then
			pcall(region.SetAlpha, region, 0)
		end
	end

	-- Flat obsidian backing painted cleanly inside the non-interactive overlay (or btn BACKGROUND)
	local bgHost = overlay or btn
	local slotBg = bgHost:CreateTexture(nil, "BACKGROUND", nil, -6)
	slotBg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
	slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	if slotBg.SetColorTexture then
		slotBg:SetColorTexture(p.bg[1] * 0.85, p.bg[2] * 0.85, p.bg[3] * 0.95, 0.94)
	else
		slotBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		slotBg:SetVertexColor(p.bg[1] * 0.85, p.bg[2] * 0.85, p.bg[3] * 0.95, 0.94)
	end

	-- Crop & inset item icon so rounded Blizzard icon corners never peek out
	local icon = btn.icon or btn.Icon or (btnName and _G[btnName .. "IconTexture"])
	if icon then
		pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
		pcall(icon.ClearAllPoints, icon)
		pcall(icon.SetPoint, icon, "TOPLEFT", btn, "TOPLEFT", 2, -2)
		pcall(icon.SetPoint, icon, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
	end

	-- Replace classic golden highlight square with subtle flat cyan hover glow
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl then
		pcall(hl.ClearAllPoints, hl)
		pcall(hl.SetPoint, hl, "TOPLEFT", btn, "TOPLEFT", 2, -2)
		pcall(hl.SetPoint, hl, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
		if hl.SetColorTexture then
			pcall(hl.SetColorTexture, hl, 0.22, 0.74, 0.97, 0.22)
		else
			pcall(hl.SetTexture, hl, "Interface\\Buttons\\WHITE8X8")
			pcall(hl.SetVertexColor, hl, 0.22, 0.74, 0.97, 0.22)
		end
	end
end

-- Skin Blizzard's UIPanelScrollFrame scrollbar into a sleek flat obsidian rail (zero classic parchment chrome!)
function PluribusUIFramework:SkinScrollBar(scrollBar, uniqueName)
	if not scrollBar then return end
	local p = self.palette
	local sbName = scrollBar.GetName and scrollBar:GetName() or (uniqueName and (uniqueName .. "ScrollBar")) or nil

	-- Hide any classic textured track art regions
	if scrollBar.GetRegions then
		for _, reg in ipairs({ scrollBar:GetRegions() }) do
			if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" then
				pcall(reg.SetAlpha, reg, 0)
			end
		end
	end

	scrollBar:SetWidth(12)
	self:ApplyBackdrop(scrollBar, 0.04, 0.06, 0.10, 0.88, p.border[1], p.border[2], p.border[3], 0.55)

	local thumb = (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()) or (sbName and _G[sbName .. "ThumbTexture"])
	if thumb then
		thumb:SetWidth(8)
		if thumb.SetColorTexture then
			thumb:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.82)
		else
			thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
			thumb:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 0.82)
		end
		thumb:SetAlpha(1)
	end

	local upBtn = scrollBar.ScrollUpButton or (sbName and _G[sbName .. "ScrollUpButton"])
	local downBtn = scrollBar.ScrollDownButton or (sbName and _G[sbName .. "ScrollDownButton"])
	local function SkinArrowBtn(ab, glyph)
		if not ab then return end
		ab:SetSize(12, 12)
		if ab.GetNormalTexture and ab:GetNormalTexture() then ab:GetNormalTexture():SetAlpha(0) end
		if ab.GetPushedTexture and ab:GetPushedTexture() then ab:GetPushedTexture():SetAlpha(0) end
		if ab.GetDisabledTexture and ab:GetDisabledTexture() then ab:GetDisabledTexture():SetAlpha(0) end
		if ab.GetHighlightTexture and ab:GetHighlightTexture() then ab:GetHighlightTexture():SetAlpha(0) end
		self:ApplyBackdrop(ab, p.panel[1], p.panel[2], p.panel[3], 0.95, p.border[1], p.border[2], p.border[3], 0.7)
		if not ab._plbGlyph then
			local fs = ab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetPoint("CENTER", ab, "CENTER", 0, 0)
			fs:SetText(glyph)
			fs:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 1)
			ab._plbGlyph = fs
		end
	end
	SkinArrowBtn(upBtn, "^")
	SkinArrowBtn(downBtn, "v")
end

function PluribusUIFramework:CreateScrollFrame(parent, name, width, height)
	-- Append unique sequence suffix so UIPanelScrollFrameTemplate scrollbar globals NEVER collide on tab switches
	self._scrollSeq = (self._scrollSeq or 0) + 1
	local uniqueName = tostring(name or "PluribusScroll") .. "_" .. tostring(self._scrollSeq)
	local scroll = CreateFrame("ScrollFrame", uniqueName, parent, "UIPanelScrollFrameTemplate")
	scroll:SetSize(width, height)
	local sb = scroll.ScrollBar or _G[uniqueName .. "ScrollBar"]
	if sb then
		self:SkinScrollBar(sb, uniqueName)
	end
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(math.max(40, (width or 300) - 24), math.max(40, height or 200))
	scroll:SetScrollChild(content)
	scroll:Show()
	content:Show()
	scroll.content = content
	return scroll
end

-- True Windowed Virtual Scroll List:
-- Instantiates ONLY visible viewport row frames lazily on demand (O(visible) frames total
-- regardless of whether backing data has 50 or 50,000 items), supports smooth mouse wheel
-- and draggable proportional scrollbar, and defers heavy live hydration during rapid drags.
function PluribusUIFramework:CreateVirtualScrollList(parent, opts)
	opts = opts or {}
	local p = self.palette
	local width = tonumber(opts.width) or 724
	local height = tonumber(opts.height) or 290
	local rowHeight = tonumber(opts.rowHeight) or 34
	local rowGap = tonumber(opts.rowGap) or 2
	local stride = math.max(1, rowHeight + rowGap)
	local padTop = tonumber(opts.padTop) or 2
	local scrollBarWidth = tonumber(opts.scrollBarWidth) or 16
	local wheelStep = tonumber(opts.wheelStep) or 3
	local shiftWheelStep = tonumber(opts.shiftWheelStep) or 12
	local visibleCount = math.max(1, math.floor((height - padTop) / stride))
	local rowWidth = math.max(80, width - scrollBarWidth - 8)

	local viewport = CreateFrame("Frame", nil, parent)
	viewport:SetSize(width, height)
	viewport:EnableMouseWheel(true)
	if viewport.SetClipsChildren then
		viewport:SetClipsChildren(true)
	end

	-- Compact themed vertical scrollbar rail (up btn + slider + down btn)
	local upBtn = self:CreateButton(viewport, "^", scrollBarWidth, 16, nil)
	upBtn:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -2, -2)

	local downBtn = self:CreateButton(viewport, "v", scrollBarWidth, 16, nil)
	downBtn:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -2, 2)

	local trackHeight = math.max(32, height - 40)
	local slider = CreateFrame("Slider", nil, viewport, BACKDROP_TEMPLATE)
	slider:SetOrientation("VERTICAL")
	slider:SetWidth(scrollBarWidth)
	slider:SetPoint("TOPRIGHT", upBtn, "BOTTOMRIGHT", 0, -2)
	slider:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
	self:ApplyBackdrop(slider, 0.04, 0.06, 0.10, 0.92, p.border[1], p.border[2], p.border[3], 0.55)
	slider:SetMinMaxValues(0, 0)
	slider:SetValueStep(1)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end
	slider:SetValue(0)
	slider:EnableMouse(true)

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	if thumb.SetColorTexture then
		thumb:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.88)
	else
		thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
		thumb:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 0.88)
	end
	thumb:SetSize(math.max(8, scrollBarWidth - 4), 28)
	slider:SetThumbTexture(thumb)

	local dataList = {}
	local dataGen = 0
	local currentOffset = 0
	local lastRenderedOffset = -1
	local lastRenderedGen = -1
	local lastRenderedCount = -1
	local suppressSlider = false
	local isDragging = false
	local rowPool = {}
	local shownCount = 0

	-- Settle timer: after rapid scrollbar drag stops for 0.06s, hydrate live metadata on visible rows
	local settleFrame = CreateFrame("Frame", nil, viewport)
	settleFrame:Hide()
	local settleRem = 0
	local function HydrateVisibleAfterSettle()
		local total = #dataList
		local visEnd = math.min(total, currentOffset + visibleCount)
		if opts.bindRow then
			for slotIdx = 1, shownCount do
				local dataIdx = currentOffset + slotIdx
				local row = rowPool[slotIdx]
				local item = dataList[dataIdx]
				if row and item and row:IsShown() then
					opts.bindRow(row, item, dataIdx, slotIdx, false)
				end
			end
		end
		if opts.onSettle then
			opts.onSettle(currentOffset, total > 0 and (currentOffset + 1) or 0, visEnd, total)
		end
	end

	settleFrame:SetScript("OnUpdate", function(sf, elapsed)
		settleRem = settleRem - (elapsed or 0)
		if settleRem <= 0 then
			sf:Hide()
			if viewport:IsVisible() then
				HydrateVisibleAfterSettle()
			end
		end
	end)

	local function ScheduleSettle()
		settleRem = 0.06
		settleFrame:Show()
	end

	local function SyncScrollBar()
		local total = #dataList
		local maxOffset = math.max(0, total - visibleCount)
		if currentOffset > maxOffset then currentOffset = maxOffset end
		if currentOffset < 0 then currentOffset = 0 end

		suppressSlider = true
		slider:SetMinMaxValues(0, maxOffset)
		slider:SetValue(currentOffset)
		suppressSlider = false

		local scrollable = maxOffset > 0
		if scrollable then
			local ratio = math.min(1, visibleCount / math.max(1, total))
			local th = math.max(22, math.min(trackHeight - 4, math.floor(trackHeight * ratio)))
			thumb:SetHeight(th)
			slider:SetAlpha(1)
			slider:EnableMouse(true)
			upBtn:SetAlpha(currentOffset > 0 and 1 or 0.4)
			downBtn:SetAlpha(currentOffset < maxOffset and 1 or 0.4)
		else
			thumb:SetHeight(math.max(22, trackHeight - 4))
			slider:SetAlpha(0.32)
			slider:EnableMouse(false)
			upBtn:SetAlpha(0.32)
			downBtn:SetAlpha(0.32)
		end
	end

	local function RenderWindow(forceRebind, isFastScroll)
		local total = #dataList
		local maxOffset = math.max(0, total - visibleCount)
		if currentOffset > maxOffset then currentOffset = maxOffset end
		if currentOffset < 0 then currentOffset = 0 end

		if not forceRebind
			and currentOffset == lastRenderedOffset
			and dataGen == lastRenderedGen
			and total == lastRenderedCount then
			return
		end

		lastRenderedOffset = currentOffset
		lastRenderedGen = dataGen
		lastRenderedCount = total

		local visibleNow = 0
		for slotIdx = 1, visibleCount do
			local dataIdx = currentOffset + slotIdx
			local item = dataList[dataIdx]
			if item ~= nil then
				visibleNow = visibleNow + 1
				local row = rowPool[slotIdx]
				if not row and opts.createRow then
					row = opts.createRow(viewport, slotIdx, rowWidth, rowHeight)
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", viewport, "TOPLEFT", 2, -padTop - (slotIdx - 1) * stride)
					rowPool[slotIdx] = row
				end
				if row then
					if opts.bindRow then
						opts.bindRow(row, item, dataIdx, slotIdx, isFastScroll == true)
					end
					row:Show()
				end
			else
				local row = rowPool[slotIdx]
				if row then row:Hide() end
			end
		end
		shownCount = visibleNow

		for slotIdx = visibleNow + 1, #rowPool do
			if rowPool[slotIdx] then rowPool[slotIdx]:Hide() end
		end

		SyncScrollBar()
		if isFastScroll then
			ScheduleSettle()
		else
			settleFrame:Hide()
		end

		if opts.onScrollChanged then
			local firstIdx = total > 0 and (currentOffset + 1) or 0
			local lastIdx = math.min(total, currentOffset + visibleNow)
			opts.onScrollChanged(currentOffset, firstIdx, lastIdx, total)
		end
	end

	function viewport:SetOffset(newOffset, isFastScroll)
		local total = #dataList
		local maxOffset = math.max(0, total - visibleCount)
		local clamped = math.max(0, math.min(maxOffset, math.floor((tonumber(newOffset) or 0) + 0.5)))
		if clamped == currentOffset and lastRenderedGen == dataGen then
			return currentOffset
		end
		currentOffset = clamped
		RenderWindow(false, isFastScroll)
		return currentOffset
	end

	function viewport:ScrollBy(delta, isFastScroll)
		return self:SetOffset(currentOffset + (tonumber(delta) or 0), isFastScroll)
	end

	function viewport:ScrollToTop()
		return self:SetOffset(0, false)
	end

	function viewport:ScrollToBottom()
		return self:SetOffset(math.max(0, #dataList - visibleCount), false)
	end

	function viewport:SetData(items, preserveOffset)
		dataList = items or {}
		dataGen = dataGen + 1
		if not preserveOffset then
			currentOffset = 0
		else
			local maxOffset = math.max(0, #dataList - visibleCount)
			if currentOffset > maxOffset then currentOffset = maxOffset end
		end
		RenderWindow(true, false)
	end

	function viewport:RefreshVisible(forceRebind)
		if forceRebind then
			RenderWindow(true, false)
		else
			HydrateVisibleAfterSettle()
		end
	end

	function viewport:GetOffset() return currentOffset end
	function viewport:GetVisibleCount() return visibleCount end
	function viewport:GetShownCount() return shownCount end
	function viewport:GetRowPool() return rowPool end
	function viewport:GetDataCount() return #dataList end
	function viewport:GetVisibleRange()
		local total = #dataList
		if total <= 0 or shownCount <= 0 then return 0, 0, total end
		return currentOffset + 1, math.min(total, currentOffset + shownCount), total
	end

	upBtn:SetScript("OnClick", function()
		viewport:ScrollBy(-1, false)
	end)
	downBtn:SetScript("OnClick", function()
		viewport:ScrollBy(1, false)
	end)

	slider:SetScript("OnMouseDown", function()
		isDragging = true
	end)
	slider:SetScript("OnMouseUp", function()
		isDragging = false
		ScheduleSettle()
	end)
	slider:SetScript("OnValueChanged", function(_, value)
		if suppressSlider then return end
		local nextOff = math.floor((tonumber(value) or 0) + 0.5)
		local jump = math.abs(nextOff - currentOffset)
		viewport:SetOffset(nextOff, isDragging or jump > visibleCount)
	end)

	viewport:SetScript("OnMouseWheel", function(_, delta)
		local step = (IsShiftKeyDown and IsShiftKeyDown()) and shiftWheelStep or wheelStep
		viewport:ScrollBy(-(delta or 0) * step, false)
	end)

	viewport._slider = slider
	viewport._upBtn = upBtn
	viewport._downBtn = downBtn
	viewport._rowPool = rowPool
	SyncScrollBar()
	return viewport
end

function PluribusUIFramework:CreateCheckbox(parent, text, checked, onchange)
	local p = self.palette
	local checkbox = CreateFrame("CheckButton", nil, parent, BACKDROP_TEMPLATE)
	checkbox:SetSize(18, 18)
	self:ApplyBackdrop(checkbox, 0.04, 0.06, 0.10, 0.98, p.border[1], p.border[2], p.border[3], 0.95)

	local checkFill = checkbox:CreateTexture(nil, "ARTWORK")
	checkFill:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 3, -3)
	checkFill:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -3, 3)
	if checkFill.SetColorTexture then
		checkFill:SetColorTexture(0.22, 0.74, 0.97, 1)
	else
		checkFill:SetTexture("Interface\\Buttons\\WHITE8X8")
		checkFill:SetVertexColor(0.22, 0.74, 0.97, 1)
	end
	checkbox:SetCheckedTexture(checkFill)

	local hl = checkbox:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -1, 1)
	if hl.SetColorTexture then
		hl:SetColorTexture(0.22, 0.74, 0.97, 0.18)
	else
		hl:SetTexture("Interface\\Buttons\\WHITE8X8")
		hl:SetVertexColor(0.22, 0.74, 0.97, 0.18)
	end

	checkbox:SetChecked(checked == true)

	local function SyncVisual(selfBox)
		local isOn = selfBox:GetChecked() == true
		if isOn then
			PluribusUIFramework:ApplyBackdrop(selfBox, 0.08, 0.16, 0.28, 0.98, 0.22, 0.74, 0.97, 1)
		else
			PluribusUIFramework:ApplyBackdrop(selfBox, 0.04, 0.06, 0.10, 0.98, p.border[1], p.border[2], p.border[3], 0.95)
		end
	end
	SyncVisual(checkbox)

	if text then
		local label = self:CreateLabel(checkbox, text)
		label:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
		checkbox.label = label
	end

	checkbox:SetScript("OnClick", function(selfBox)
		PluribusUIFramework:BringOwnerToFront(selfBox)
		SyncVisual(selfBox)
		if onchange then
			onchange(selfBox:GetChecked() == true)
		end
	end)
	return checkbox
end

-- Draggable Minimap Suite Launcher Button
function PluribusUIFramework:CreateMinimapButton()
	if _G.PluribusMinimapButton or not Minimap then
		return _G.PluribusMinimapButton
	end

	-- True circular minimap orb with custom glowing Infinity symbol (zero ugly square box!)
	local btn = CreateFrame("Button", "PluribusMinimapButton", Minimap)
	btn:SetSize(32, 32)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)

	local function PositionOnRim(angleRad)
		local r = (Minimap:GetWidth() or 140) * 0.5 + 8
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angleRad) * r, math.sin(angleRad) * r)
	end
	local savedAngle = (_G.PluribusHive and _G.PluribusHive.GetConfig and tonumber(_G.PluribusHive:GetConfig().minimapAngle)) or math.rad(215)
	PositionOnRim(savedAngle)

	-- Circular Infinity Orb texture (64x64 anti-aliased RGBA TGA)
	local orbIcon = btn:CreateTexture(nil, "ARTWORK")
	orbIcon:SetAllPoints(btn)
	orbIcon:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\InfinityOrb")
	btn.orbIcon = orbIcon

	-- Authentic circular WoW minimap hover halo
	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
	hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
	hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	hl:SetBlendMode("ADD")

	-- Tiny circular HiveMind status pip on bottom-right rim
	local statusDot = btn:CreateTexture(nil, "OVERLAY")
	statusDot:SetSize(8, 8)
	statusDot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	statusDot:SetTexture("Interface\\COMMON\\Indicator-Green")
	btn.statusDot = statusDot

	local function RefreshOrbDot()
		local h = (_G.PluribusHive and _G.PluribusHive.GetNetworkHealth) and _G.PluribusHive:GetNetworkHealth() or nil
		if h and h.state then
			if h.state == "OFFLINE" then
				btn.statusDot:SetTexture("Interface\\COMMON\\Indicator-Red")
			elseif h.state == "DEGRADED" then
				btn.statusDot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
			else
				btn.statusDot:SetTexture("Interface\\COMMON\\Indicator-Green")
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
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", function(selfBtn)
		selfBtn._dragging = true
		selfBtn:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local sc = Minimap:GetEffectiveScale() or 1
			if mx and my and cx and cy then
				local ang = math.atan2((cy / sc) - my, (cx / sc) - mx)
				savedAngle = ang
				PositionOnRim(ang)
			end
		end)
	end)
	btn:SetScript("OnDragStop", function(selfBtn)
		selfBtn._dragging = false
		if _G.PluribusHive and _G.PluribusHive.SetConfig then
			_G.PluribusHive:SetConfig("minimapAngle", savedAngle)
		end
		selfBtn:SetScript("OnUpdate", function(_, elapsed)
			orbTick = orbTick + (elapsed or 0)
			if orbTick >= 3 then
				orbTick = 0
				RefreshOrbDot()
			end
		end)
	end)

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
			GameTooltip:AddLine("HealBot + Decursive: /healbot oder Hub-Tab", 0.45, 0.92, 0.68)
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
