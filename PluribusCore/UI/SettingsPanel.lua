-- PluribusCore Unified Settings Menu
-- Houses ALL suite, UI, HiveMind sharing/privacy, alerts, tooltips, market, and module settings
-- Registers natively inside WoW's Settings Menu tree (ESC -> Options -> AddOns -> Pluribus Suite + native subcategories!)
-- AND shows live Online/Offline status for all optional database addons (QuestieDB, WoWHeadDB, GatherMate2, GathererDB, etc.)

PluribusSettingsPanel = {
	categoryOrder = {
		"General & UI",
		"HealBot & Decursive",
		"HiveMind Sharing",
		"Alerts, SOS & LFG",
		"Tooltips & Market",
		"Modules & Data",
		"Shortcuts & Guide",
	},
	currentCategory = "General & UI",
	blizzardCategory = nil,
	blizzardCanvas = nil,
	blizzardSubCategories = {},
	blizzardSubCanvases = {},
	standaloneFrame = nil,
}
_G.PluribusSettingsPanel = PluribusSettingsPanel

-- Optional external database & companion addons supported by Pluribus
PluribusSettingsPanel.OPTIONAL_DATABASE_ADDONS = {
	{
		key = "QuestieDB",
		name = "Questie / QuestieDB",
		desc = "Quest-, NPC-, Ziel- & Mob-Tooltip-Datenbank",
		addonNames = { "Questie", "QuestieDB" },
		globals = { "QuestieDB", "Questie" },
	},
	{
		key = "WoWHeadDB",
		name = "WoWHeadDB",
		desc = "Item-Quellen, Drop-Tabellen, Quests & NPCs",
		addonNames = { "WoWHeadDB", "WowHeadDB" },
		globals = { "WoWHeadDB", "WowHeadDB" },
	},
	{
		key = "GatherMate2",
		name = "GatherMate2",
		desc = "Kräuter-, Erz-, Schatz- & Angel-Knotenpunkte",
		addonNames = { "GatherMate2", "GatherMate2_Data" },
		globals = { "GatherMate2", "GatherMate2HerbDB", "GatherMate2MineDB" },
	},
	{
		key = "GathererDB",
		name = "GathererDB / Gatherer",
		desc = "Klassische Sammel-Knotendatenbank",
		addonNames = { "GathererDB", "GathererDB_Wowhead", "Gatherer" },
		globals = { "GathererDB", "Gatherer" },
	},
	{
		key = "Auctionator",
		name = "Auctionator",
		desc = "Optionaler sekundärer AH-Preis-Feed",
		addonNames = { "Auctionator" },
		globals = { "Auctionator" },
	},
	{
		key = "TradeSkillMaster",
		name = "TradeSkillMaster (TSM)",
		desc = "Optionale Marktpreis-Bewertung",
		addonNames = { "TradeSkillMaster" },
		globals = { "TSM_API", "TradeSkillMaster" },
	},
	{
		key = "ShortestPathForever",
		name = "ShortestPathForever / TomTom",
		desc = "Optionale Wegpunkt- & Pfad-Integration",
		addonNames = { "ShortestPathForever", "TomTom" },
		globals = { "ShortestPathForever", "TomTom" },
	},
}

local function CheckAddOnLoadedSafe(addonName)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
		if ok and loaded then return true end
	end
	if IsAddOnLoaded then
		local ok, loaded = pcall(IsAddOnLoaded, addonName)
		if ok and loaded then return true end
	end
	return false
end

local function CheckAddOnInstalledSafe(addonName)
	if C_AddOns and C_AddOns.GetAddOnInfo then
		local ok, name = pcall(C_AddOns.GetAddOnInfo, addonName)
		if ok and name then return true end
	end
	if GetAddOnInfo then
		local ok, name = pcall(GetAddOnInfo, addonName)
		if ok and name then return true end
	end
	return false
end

function PluribusSettingsPanel:GetOptionalDatabaseStatus()
	local results = {}
	local onlineCount = 0

	for _, entry in ipairs(self.OPTIONAL_DATABASE_ADDONS) do
		local isOnline = false
		local isInstalled = false
		local matchedName = nil

		for _, gName in ipairs(entry.globals or {}) do
			if _G[gName] ~= nil then
				isOnline = true
				isInstalled = true
				matchedName = gName
				break
			end
		end

		for _, aName in ipairs(entry.addonNames or {}) do
			if CheckAddOnLoadedSafe(aName) then
				isOnline = true
				isInstalled = true
				matchedName = matchedName or aName
			elseif CheckAddOnInstalledSafe(aName) then
				isInstalled = true
				matchedName = matchedName or aName
			end
		end

		if isOnline then
			onlineCount = onlineCount + 1
		end

		results[#results + 1] = {
			key = entry.key,
			name = entry.name,
			desc = entry.desc,
			online = isOnline,
			installed = isInstalled,
			matchedName = matchedName,
			statusText = isOnline and "Online" or (isInstalled and "Offline (Deaktiviert)" or "Offline"),
		}
	end

	return results, onlineCount, #results
end

local function GetCfg()
	if _G.PluribusHive and _G.PluribusHive.GetConfig then
		return _G.PluribusHive:GetConfig()
	end
	return {}
end

local function SetCfg(key, val)
	if _G.PluribusHive and _G.PluribusHive.SetConfig then
		_G.PluribusHive:SetConfig(key, val)
	end
	if key == "showMinimapOrb" and _G.PluribusMinimapButton then
		_G.PluribusMinimapButton:SetShown(val == true)
	elseif key == "uiScale" and _G.PluribusUIFramework and _G.PluribusUIFramework.SetUIScale then
		_G.PluribusUIFramework:SetUIScale(val)
	elseif key == "showCooldownOverlay" and _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	elseif key == "showRaidMarkerBar" and _G.PluribusHiveRaidTools and _G.PluribusHiveRaidTools.UpdateMarkerBarVisibility then
		_G.PluribusHiveRaidTools:UpdateMarkerBarVisibility()
	elseif key == "replaceNativeBags" and _G.PluribusHiveInventory and _G.PluribusHiveInventory.SyncNativeBagHooks then
		_G.PluribusHiveInventory:SyncNativeBagHooks()
	elseif key == "language" and _G.PluribusL and _G.PluribusL.SetLanguage then
		_G.PluribusL:SetLanguage(val)
	end
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("PLURIBUS_SETTING_CHANGED", "Pluribus", key, val) end)
	end
end

function PluribusSettingsPanel:GetSetting(_, key)
	return GetCfg()[key]
end

function PluribusSettingsPanel:SetSetting(_, key, value)
	SetCfg(key, value)
	return true
end

function PluribusSettingsPanel:ResetToDefaults()
	if _G.PluribusHive and _G.PluribusHive.DEFAULT_CONFIG then
		for k, v in pairs(_G.PluribusHive.DEFAULT_CONFIG) do
			SetCfg(k, v)
		end
	end
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:LoadTheme("obsidian")
		_G.PluribusUIFramework:SetUIScale(1.0)
		_G.PluribusUIFramework:ShowNotification("|cff4ade80Pluribus settings reset to defaults.|r", 2.5)
	end
end

-- Full-width single-category shell for Blizzard's native Settings category tree (NO redundant nested sidebar!)
function PluribusSettingsPanel:BuildNativeCategoryShell(parent, categoryName, width, height)
	local UI = _G.PluribusUIFramework
	local w = math.max(560, math.floor(width or 620))
	local h = math.max(440, math.floor(height or 500))

	local hdr = UI:CreateLabel(parent, "|cff38bdf8Pluribus Suite — " .. tostring(categoryName) .. "|r", 1, 1, 1, "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -12)

	local subText = (categoryName == "General & UI")
		and "Haupt-Einstellungen · Weitere Bereiche direkt links im nativen AddOns-Baum unter Pluribus Suite."
		or "Einstellungen für " .. tostring(categoryName) .. " (Teil von Pluribus Suite)."
	local sub = UI:CreateLabel(parent, subText, 0.68, 0.78, 0.88, "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)

	local resetBtn = UI:CreateButton(parent, "Reset Defaults", 112, 22, function()
		PluribusSettingsPanel:ResetToDefaults()
		PluribusSettingsPanel:ShowCategory(parent, categoryName)
	end)
	resetBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, -12)

	local bodyW = w - 28
	local bodyH = h - 58
	local contentCard = UI:CreateCard(parent, bodyW, bodyH)
	contentCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -46)

	local safeKey = tostring(categoryName):gsub("[^%w]", "")
	local scroll = UI:CreateScrollFrame(contentCard, "PluribusNativeSettingsScroll_" .. safeKey, bodyW - 16, bodyH - 16)
	scroll:SetPoint("TOPLEFT", contentCard, "TOPLEFT", 8, -8)

	parent.contentFrame = scroll.content
	parent.contentWidth = bodyW - 44
	parent.categoryButtons = nil
	parent._isNativeCategory = true
	parent._fixedCategory = categoryName

	self:ShowCategory(parent, categoryName)
end

-- Standalone fallback window shell (used only when opened out-of-tree, e.g. in combat via /pluribus settings)
function PluribusSettingsPanel:BuildSettingsShell(parent, width, height, isEmbedded)
	local UI = _G.PluribusUIFramework
	local w = width or 640
	local h = height or 470
	local topOff = isEmbedded and -42 or -48
	local bodyH = h - (isEmbedded and 54 or 64)

	if isEmbedded then
		local hdr = UI:CreateLabel(parent, "|cff38bdf8Pluribus Suite — Settings|r", 1, 1, 1, "GameFontNormalLarge")
		hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
		local sub = UI:CreateLabel(parent, "All Pluribus HiveMind, UI, Tooltip, Alert & Module preferences in one place.", 0.68, 0.78, 0.88, "GameFontHighlightSmall")
		sub:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
	end

	local catW = 158
	local catCard = UI:CreateCard(parent, catW, bodyH)
	catCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, topOff)
	parent.categoryButtons = {}

	for idx, catName in ipairs(self.categoryOrder) do
		local btn = UI:CreateButton(catCard, catName, catW - 16, 28, function()
			PluribusSettingsPanel:ShowCategory(parent, catName)
		end)
		btn:SetPoint("TOPLEFT", catCard, "TOPLEFT", 8, -10 - (idx - 1) * 34)
		parent.categoryButtons[catName] = btn
	end

	local resetBtn = UI:CreateButton(catCard, "Reset Defaults", catW - 16, 24, function()
		PluribusSettingsPanel:ResetToDefaults()
		PluribusSettingsPanel:ShowCategory(parent, PluribusSettingsPanel.currentCategory or "General & UI")
	end)
	resetBtn:SetPoint("BOTTOMLEFT", catCard, "BOTTOMLEFT", 8, 10)

	local contentW = w - catW - 34
	local contentCard = UI:CreateCard(parent, contentW, bodyH)
	contentCard:SetPoint("TOPLEFT", catCard, "TOPRIGHT", 10, 0)

	local scrollName = isEmbedded and "PluribusBlizzSettingsScroll" or "PluribusStandaloneSettingsScroll"
	local scroll = UI:CreateScrollFrame(contentCard, scrollName, contentW - 16, bodyH - 16)
	scroll:SetPoint("TOPLEFT", contentCard, "TOPLEFT", 8, -8)
	parent.contentFrame = scroll.content
	parent.contentWidth = contentW - 42

	self:ShowCategory(parent, self.currentCategory or "General & UI")
end

local function AddCheckboxRow(container, rowW, y, label, desc, checked, onChange)
	local UI = _G.PluribusUIFramework
	local row = UI:CreateCard(container, rowW, 48)
	row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

	local cb = UI:CreateCheckbox(row, label, checked, onChange)
	cb:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
	if cb.label then
		cb.label:SetFontObject("GameFontNormal")
	end

	if desc then
		local dLbl = UI:CreateLabel(row, "|cff94a3b8" .. desc .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		dLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -27)
		dLbl:SetWidth(rowW - 48)
	end
	return y - 54
end

local function AddChoiceRow(container, rowW, y, label, desc, options, activeVal, onSelect)
	local UI = _G.PluribusUIFramework
	local row = UI:CreateCard(container, rowW, 56)
	row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

	local lbl = UI:CreateLabel(row, label, 0.94, 0.96, 1.0, "GameFontNormal")
	lbl:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -7)

	if desc then
		local dLbl = UI:CreateLabel(row, "|cff94a3b8" .. desc .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		dLbl:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
		dLbl:SetWidth(rowW - 20)
	end

	local xOff = -10
	for i = #options, 1, -1 do
		local opt = options[i]
		local optLabel = type(opt) == "table" and opt.label or tostring(opt)
		local optVal = type(opt) == "table" and opt.value or opt
		local btnW = math.max(54, math.min(92, (#optLabel * 7) + 18))
		local btn = UI:CreateButton(row, optLabel, btnW, 22, function()
			onSelect(optVal)
		end, activeVal == optVal)
		btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", xOff, -8)
		xOff = xOff - (btnW + 6)
	end
	return y - 62
end

-- Renders the Optional Database Addons Online/Offline status panel
local function AddOptionalDatabasesCard(container, rowW, y, shell, category)
	local UI = _G.PluribusUIFramework
	local statuses, onlineCount, totalCount = PluribusSettingsPanel:GetOptionalDatabaseStatus()
	local netStats = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.GetStats)
		and _G.PluribusHiveNetworkDB:GetStats() or { items = 0, quests = 0, npcs = 0 }

	local rowH = 26
	local cardH = 56 + (#statuses * rowH) + 28
	local card = UI:CreateCard(container, rowW, cardH)
	card:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

	local title = UI:CreateLabel(
		card,
		string.format("|cff38bdf8Optionale Datenbank-Addons|r  |cff94a3b8(%d/%d online)|r", onlineCount, totalCount),
		1, 1, 1, "GameFontNormal"
	)
	title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)

	local sub = UI:CreateLabel(
		card,
		string.format("|cff94a3b8Pluribus P2P-Cache aktiv (%d Items, %d Quests, %d NPCs) · Externe DB-Addons werden automatisch eingebunden.|r",
			netStats.items or 0, netStats.quests or 0, netStats.npcs or 0),
		nil, nil, nil, "GameFontHighlightSmall"
	)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	sub:SetWidth(rowW - 110)

	local refreshBtn = UI:CreateButton(card, "Aktualisieren", 92, 20, function()
		PluribusSettingsPanel:ShowCategory(shell, category)
	end)
	refreshBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)

	local iy = -46
	for _, st in ipairs(statuses) do
		local line = CreateFrame("Frame", nil, card)
		line:SetSize(rowW - 16, rowH - 2)
		line:SetPoint("TOPLEFT", card, "TOPLEFT", 8, iy)

		local dot = line:CreateTexture(nil, "ARTWORK")
		dot:SetSize(8, 8)
		dot:SetPoint("LEFT", line, "LEFT", 4, 0)
		if st.online then
			dot:SetColorTexture(0.29, 0.87, 0.50, 1)
		elseif st.installed then
			dot:SetColorTexture(0.98, 0.75, 0.15, 1)
		else
			dot:SetColorTexture(0.45, 0.52, 0.62, 0.85)
		end

		local nameL = UI:CreateLabel(line, st.name, 0.94, 0.96, 1.0, "GameFontHighlightSmall")
		nameL:SetPoint("LEFT", dot, "RIGHT", 8, 0)

		local descL = UI:CreateLabel(line, "|cff94a3b8— " .. st.desc .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		descL:SetPoint("LEFT", nameL, "RIGHT", 6, 0)

		local statusCol = st.online and "|cff4ade80" or (st.installed and "|cfffbbf24" or "|cff94a3b8")
		local statusL = UI:CreateLabel(line, statusCol .. st.statusText .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		statusL:SetPoint("RIGHT", line, "RIGHT", -4, 0)

		iy = iy - rowH
	end

	return y - (cardH + 8)
end

function PluribusSettingsPanel:ShowCategory(shell, category)
	if not shell or not shell.contentFrame then return end
	local UI = _G.PluribusUIFramework
	self.currentCategory = category

	for name, btn in pairs(shell.categoryButtons or {}) do
		btn:SetActiveState(name == category)
	end

	local c = shell.contentFrame
	local rowW = shell.contentWidth or 420
	UI:ClearContainer(c)
	local cfg = GetCfg()

	local y = -6
	if not shell._isNativeCategory then
		local heading = UI:CreateLabel(c, "|cff38bdf8" .. category .. "|r", nil, nil, nil, "GameFontNormalLarge")
		heading:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
		y = -34
	end

	if category == "General & UI" then
		-- Show optional database addons online/offline status right on the main Settings page too
		y = AddOptionalDatabasesCard(c, rowW, y, shell, category)

		y = AddChoiceRow(c, rowW, y, "Language / Sprache", "Switch interface language (Auto detects WoW client locale)", {
			{ label = "Auto", value = "auto" },
			{ label = "Deutsch", value = "de" },
			{ label = "English", value = "en" },
		}, cfg.language or "auto", function(val)
			SetCfg("language", val)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddChoiceRow(c, rowW, y, "Suite Theme", "Switch color palette across Pluribus windows", {
			{ label = "Obsidian", value = "obsidian" },
			{ label = "Light Slate", value = "light" },
		}, UI.theme == "light" and "light" or "obsidian", function(val)
			UI:LoadTheme(val)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		-- UI Scale stepper row
		local scaleRow = UI:CreateCard(c, rowW, 54)
		scaleRow:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		local sLbl = UI:CreateLabel(scaleRow, "UI Scale", 0.94, 0.96, 1.0, "GameFontNormal")
		sLbl:SetPoint("TOPLEFT", scaleRow, "TOPLEFT", 10, -7)
		local sDesc = UI:CreateLabel(scaleRow, "|cff94a3b8Applies immediately to all Pluribus suite windows|r", nil, nil, nil, "GameFontHighlightSmall")
		sDesc:SetPoint("TOPLEFT", sLbl, "BOTTOMLEFT", 0, -4)
		local curScale = tonumber(cfg.uiScale) or 1.0
		local valText = UI:CreateLabel(scaleRow, "|cfffbbf24" .. string.format("%.2fx", curScale) .. "|r")
		valText:SetPoint("RIGHT", scaleRow, "RIGHT", -76, 0)
		local minusBtn = UI:CreateButton(scaleRow, "-", 24, 22, function()
			local nv = math.max(0.70, math.floor(((tonumber(GetCfg().uiScale) or 1.0) - 0.05) * 100 + 0.5) / 100)
			SetCfg("uiScale", nv)
			valText:SetText("|cfffbbf24" .. string.format("%.2fx", nv) .. "|r")
		end)
		minusBtn:SetPoint("RIGHT", scaleRow, "RIGHT", -40, 0)
		local plusBtn = UI:CreateButton(scaleRow, "+", 24, 22, function()
			local nv = math.min(1.40, math.floor(((tonumber(GetCfg().uiScale) or 1.0) + 0.05) * 100 + 0.5) / 100)
			SetCfg("uiScale", nv)
			valText:SetText("|cfffbbf24" .. string.format("%.2fx", nv) .. "|r")
		end)
		plusBtn:SetPoint("RIGHT", scaleRow, "RIGHT", -10, 0)
		y = y - 60

		y = AddChoiceRow(c, rowW, y, "Default Bag Viewer Mode", "Show Alt & Guild bags as visual icon grids or a compact list", {
			{ label = "Icon Grid", value = "grid" },
			{ label = "List View", value = "list" },
		}, cfg.bagViewerMode or "grid", function(val)
			SetCfg("bagViewerMode", val)
			if _G.PluribusHiveUI then
				_G.PluribusHiveUI.invViewMode = val
				_G.PluribusHiveUI:RefreshInventoryViewer()
			end
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddCheckboxRow(c, rowW, y, "Attach Side Tabs to Game Windows", "Adventure-Guide-style side tabs on Professions, Bags, Bank, Guild, AH & Quests", cfg.attachSideTabs ~= false, function(v)
			SetCfg("attachSideTabs", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Minimap Orb (PLB)", "Quick launcher & live HiveMind status dot around the minimap", cfg.showMinimapOrb ~= false, function(v)
			SetCfg("showMinimapOrb", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Class Colored Names", "Color guild and alt character names by WoW class", cfg.classColoredNames ~= false, function(v)
			SetCfg("classColoredNames", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Unified Pluribus UI (Taschen, Bank & Gildenbank)", "Verwendet die einheitliche Pluribus-UI für Taschen, Bank und Gildenbank (jederzeit via 'Std' umschaltbar)", cfg.replaceNativeBags == true, function(v)
			SetCfg("replaceNativeBags", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Pathfinder: Avoid High-Level Zones & Mobs", "Prefer roads, safe passes, flight paths & boats over dangerous high-level shortcuts", cfg.navAvoidHighLevel ~= false, function(v)
			SetCfg("navAvoidHighLevel", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Pathfinder: Guild Mage Portals & Warlock Summons", "Include open-world online guild Mages (portals) & Warlocks (summons with 2-helper buffer) outside dungeons/raids", cfg.navUseGuildTransit ~= false, function(v)
			SetCfg("navUseGuildTransit", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Auto-Sell Gray Trash at Vendors", "Automatically sell Poor (gray) junk items when opening any merchant (hold Shift to skip)", cfg.autoSellJunk ~= false, function(v)
			SetCfg("autoSellJunk", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Auto-Repair Gear at Vendors", "Automatically repair damaged gear when talking to a repair merchant (hold Shift to skip)", cfg.autoRepair ~= false, function(v)
			SetCfg("autoRepair", v)
		end)

		-- 4-mode Auto-Repair Payment Source selector
		local repRow = UI:CreateCard(c, rowW, 70)
		repRow:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
		local repLbl = UI:CreateLabel(repRow, "Auto-Reparatur: Zahlungsquelle", 0.94, 0.96, 1.0, "GameFontNormal")
		repLbl:SetPoint("TOPLEFT", repRow, "TOPLEFT", 10, -7)
		local repDesc = UI:CreateLabel(repRow, "|cff94a3b8Standard: nur eigenes Gold. Optional mit Gildenbank-Priorität oder nur Gildenbank.|r", nil, nil, nil, "GameFontHighlightSmall")
		repDesc:SetPoint("TOPLEFT", repLbl, "BOTTOMLEFT", 0, -2)
		repDesc:SetWidth(rowW - 20)
		local activeRepMode = cfg.autoRepairMode or "PERSONAL_ONLY"
		local repModes = {
			{ label = "Nur Eigenes", value = "PERSONAL_ONLY", w = 88 },
			{ label = "Eigenes > Gilde", value = "PERSONAL_FIRST", w = 104 },
			{ label = "Gilde > Eigenes", value = "GUILD_FIRST", w = 104 },
			{ label = "Nur Gilde", value = "GUILD_ONLY", w = 78 },
		}
		local prevRepBtn = nil
		for _, rm in ipairs(repModes) do
			local b = UI:CreateButton(repRow, rm.label, rm.w, 22, function()
				SetCfg("autoRepairMode", rm.value)
				PluribusSettingsPanel:ShowCategory(shell, category)
			end, activeRepMode == rm.value)
			if prevRepBtn then
				b:SetPoint("LEFT", prevRepBtn, "RIGHT", 6, 0)
			else
				b:SetPoint("BOTTOMLEFT", repRow, "BOTTOMLEFT", 10, 8)
			end
			prevRepBtn = b
		end
		y = y - 76

		y = AddCheckboxRow(c, rowW, y, "Fast Auto-Loot", "Instantly loot all items when opening corpses/chests with auto-loot enabled", cfg.fastAutoLoot ~= false, function(v)
			SetCfg("fastAutoLoot", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Compact Mode", "Use denser row spacing in raid tables and lists", cfg.compactMode == true, function(v)
			SetCfg("compactMode", v)
		end)

	elseif category == "HealBot & Decursive" then
		local hd = _G.PluribusHealDecursive
		if not hd then
			local errL = UI:CreateLabel(c, "|cfff87171HealBot-Engine nicht geladen. Bitte /reload ausführen.|r", 1, 1, 1, "GameFontNormal")
			errL:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y)
			y = y - 32
		else
			local hcfg = hd.config
			-- Quick action buttons bar
			local openFullBtn = UI:CreateButton(c, "Klick-Zauber & Vorschau öffnen (/healbot)", 254, 24, function()
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("HealBot")
				end
			end, true)
			openFullBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

			local resetClsBtn = UI:CreateButton(c, "Klassen-Standard", 132, 24, function()
				hd:ResetClassDefaults()
				PluribusSettingsPanel:ShowCategory(shell, category)
			end)
			resetClsBtn:SetPoint("LEFT", openFullBtn, "RIGHT", 8, 0)
			y = y - 34

			y = AddCheckboxRow(c, rowW, y, "HealBot + Decursive aktivieren", "Schaltet das Klick-Heilungs- & Decursive-Grid ein oder aus", hcfg.enabled ~= false, function(v)
				hcfg.enabled = v
				hd:SaveConfig()
				hd:RequestRebuild()
			end)

			y = AddCheckboxRow(c, rowW, y, "Immer anzeigen (auch Solo / Selbstheilung)", "Zeigt dein eigenes HealBot-Feld auch ohne Gruppe/Raid an — ideal zum Selbstheilen & Bannen", hcfg.showSolo == true, function(v)
				if hd.SetAlwaysShow then
					hd:SetAlwaysShow(v)
				else
					hcfg.showSolo = v
					if v then hcfg.enabled = true end
					hd:SaveConfig()
					hd:RequestRebuild()
				end
			end)

			y = AddCheckboxRow(c, rowW, y, "Kompakter Decursive MUF-Modus", "Kleine farbige Debuff-Quadrate (Linksklick = Primär-Cleanse, Rechtsklick = Sekundär)", hcfg.compactMUF == true, function(v)
				hcfg.compactMUF = v
				hd:SaveConfig()
				hd:RequestRebuild()
			end)

			y = AddCheckboxRow(c, rowW, y, "Grid-Position sperren", "Verhindert versehentliches Verschieben mit der Maus", hcfg.locked == true, function(v)
				hcfg.locked = v
				hd:SaveConfig()
			end)

			y = AddCheckboxRow(c, rowW, y, "Eingehende Heilungen anzeigen", "Zeigt laufende Heilzauber anderer Heiler als grüne Vorschau", hcfg.showIncomingHeals ~= false, function(v)
				hcfg.showIncomingHeals = v
				hd:SaveConfig()
			end)

			y = AddCheckboxRow(c, rowW, y, "HoT-Timer anzeigen (Erneuerung, Verjüngung, Schild)", "Zeigt aktive HoTs & Restsekunden rechts unten auf jedem Feld", hcfg.showHoTTimers ~= false, function(v)
				hcfg.showHoTTimers = v
				hd:SaveConfig()
			end)

			y = AddCheckboxRow(c, rowW, y, "Nur selbst bannbare Debuffs hervorheben", "Blendet Debuffs aus, die deine Klasse nicht entfernen kann", hcfg.onlyDispellable ~= false, function(v)
				hcfg.onlyDispellable = v
				hd:SaveConfig()
			end)

			y = AddCheckboxRow(c, rowW, y, "Decursive Warnton bei neuem Debuff", "Spielt einen dezenten Klang ab, sobald ein bannbarer Debuff auftritt", hcfg.alertSound ~= false, function(v)
				hcfg.alertSound = v
				hd:SaveConfig()
			end)

			y = AddCheckboxRow(c, rowW, y, "Außer Reichweite ausblenden & Aggro-Rahmen", "Dimmt Einheiten über 40m und markiert Bedrohung mit rotem Rahmen", hcfg.fadeOutOfRange ~= false, function(v)
				hcfg.fadeOutOfRange = v
				hcfg.showAggro = v
				hd:SaveConfig()
			end)

			-- Quick Click-Cast & Cleanse summary card
			local bindCard = UI:CreateCard(c, rowW, 92)
			bindCard:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
			local b = hcfg.bindings or {}
			local bTitle = UI:CreateLabel(bindCard, "|cff38bdf8Aktive Klick-Zauber & Cleanse-Belegung|r", 1, 1, 1, "GameFontNormal")
			bTitle:SetPoint("TOPLEFT", bindCard, "TOPLEFT", 10, -8)
			local bLine1 = UI:CreateLabel(bindCard, string.format(
				"Links: |cff4ade80%s|r  ·  Rechts: |cff38bdf8%s|r  ·  Mitte: |cfffbbf24%s|r",
				(b["Left-Click"] and b["Left-Click"] ~= "") and b["Left-Click"] or "Ziel",
				(b["Right-Click"] and b["Right-Click"] ~= "") and b["Right-Click"] or "-",
				(b["Middle-Click"] and b["Middle-Click"] ~= "") and b["Middle-Click"] or "-"
			), 0.85, 0.90, 0.96, "GameFontHighlightSmall")
			bLine1:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -6)
			local bLine2 = UI:CreateLabel(bindCard, string.format(
				"Shift+L: |cffcbd5e1%s|r  ·  Strg+L: |cffcbd5e1%s|r  ·  Cleanse: |cffa855f7%s|r / |cffa855f7%s|r",
				(b["Shift+Left"] and b["Shift+Left"] ~= "") and b["Shift+Left"] or "-",
				(b["Ctrl+Left"] and b["Ctrl+Left"] ~= "") and b["Ctrl+Left"] or "-",
				(hcfg.cleansePrimary and hcfg.cleansePrimary ~= "") and hcfg.cleansePrimary or "-",
				(hcfg.cleanseSecondary and hcfg.cleanseSecondary ~= "") and hcfg.cleanseSecondary or "-"
			), 0.78, 0.86, 0.94, "GameFontHighlightSmall")
			bLine2:SetPoint("TOPLEFT", bLine1, "BOTTOMLEFT", 0, -4)
			local bHint = UI:CreateLabel(bindCard, "|cff94a3b8Zum Bearbeiten einzelner Zauber oben auf 'Klick-Zauber & Vorschau öffnen' klicken (oder /healbot).|r", nil, nil, nil, "GameFontHighlightSmall")
			bHint:SetPoint("TOPLEFT", bLine2, "BOTTOMLEFT", 0, -6)
			y = y - 98
		end

	elseif category == "HiveMind Sharing" then
		local allOnBtn = UI:CreateButton(c, "Share All (Hive Default)", 160, 24, function()
			for _, k in ipairs({ "shareBags", "shareBank", "shareProfessions", "shareCooldowns", "shareDistress", "shareLFG", "shareAuctionPrices", "shareWorldEvents", "shareGameDB" }) do
				SetCfg(k, true)
			end
			PluribusSettingsPanel:ShowCategory(shell, category)
		end, true)
		allOnBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

		local allOffBtn = UI:CreateButton(c, "Pause All Sharing", 136, 24, function()
			for _, k in ipairs({ "shareBags", "shareBank", "shareProfessions", "shareCooldowns", "shareDistress", "shareLFG", "shareAuctionPrices", "shareWorldEvents", "shareGameDB" }) do
				SetCfg(k, false)
			end
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)
		allOffBtn:SetPoint("LEFT", allOnBtn, "RIGHT", 8, 0)
		y = y - 34

		local shareOpts = {
			{ key = "shareBags", label = "Share My Bags", desc = "Allow guildmates to browse your bags with icons & tooltips" },
			{ key = "shareBank", label = "Share My Bank", desc = "Allow guildmates to inspect your cached bank contents" },
			{ key = "shareProfessions", label = "Share Professions & Needed Materials", desc = "Highlight your needed leveling mats on guildmates' tooltips" },
			{ key = "shareCooldowns", label = "Share Major Cooldowns", desc = "Broadcast Rebirth, Shield Wall, Innervate, Lust & major utility casts" },
			{ key = "shareDistress", label = "Send Open-World Danger / SOS Pings", desc = "Alert nearby guildmates in open world only (never in raids/instances)" },
			{ key = "shareLFG", label = "Share & Sync Smart Guild LFG Posts", desc = "Match guild group requests to players of the right class, role & level" },
			{ key = "shareAuctionPrices", label = "Share Scanned Auction House Prices", desc = "Keep guild item tooltips updated with recent AH buyout values" },
			{ key = "shareWorldEvents", label = "Share Rares, Gather Nodes & Same-Quests", desc = "Broadcast spotted rares, herb/ore nodes, and active quest overlap" },
			{ key = "shareGameDB", label = "Participate in P2P Wowhead DB Sync", desc = "Automatically share cached item/quest/NPC data across guild peers" },
		}
		for _, opt in ipairs(shareOpts) do
			y = AddCheckboxRow(c, rowW, y, opt.label, opt.desc, cfg[opt.key] ~= false, function(v)
				SetCfg(opt.key, v)
			end)
		end

	elseif category == "Alerts, SOS & LFG" then
		y = AddCheckboxRow(c, rowW, y, "Nearby Open-World Rescue Alerts", "Show non-intrusive toast only when a guildmate in danger is close enough to save", cfg.showDistressAlerts ~= false, function(v)
			SetCfg("showDistressAlerts", v)
		end)

		y = AddChoiceRow(c, rowW, y, "SOS Auto-Alert HP Threshold", "Automatically send an open-world SOS if your HP drops below:", {
			{ label = "25%", value = 25 },
			{ label = "35%", value = 35 },
			{ label = "50%", value = 50 },
		}, cfg.distressHpThreshold or 35, function(v)
			SetCfg("distressHpThreshold", v)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddChoiceRow(c, rowW, y, "Rescue Alert Max Distance", "Only alert you if the guildmate in trouble is within reach", {
			{ label = "Close", value = 0.12 },
			{ label = "Medium", value = 0.18 },
			{ label = "Wide", value = 0.30 },
		}, cfg.distressMaxDistance or 0.18, function(v)
			SetCfg("distressMaxDistance", v)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddCheckboxRow(c, rowW, y, "Smart Guild LFG Match Toasts", "Notify you only when a guild LFG matches your class, role & level", cfg.showLFGMatches ~= false, function(v)
			SetCfg("showLFGMatches", v)
		end)

		y = AddChoiceRow(c, rowW, y, "Preferred LFG Role", "Used when matching guild group requests to your character", {
			{ label = "AUTO", value = "AUTO" },
			{ label = "TANK", value = "TANK" },
			{ label = "HEALER", value = "HEALER" },
			{ label = "DPS", value = "DPS" },
		}, cfg.myRole or "AUTO", function(v)
			SetCfg("myRole", v)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddCheckboxRow(c, rowW, y, "Enable Guild Chat @Mention Pings", "Highlight & chime when someone @mentions you, your class, race, or profession in /g", cfg.mentionsEnabled ~= false, function(v)
			SetCfg("mentionsEnabled", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Play Smart @Mention Notification Sound", "Mutes during combat/dungeons/raids & replays after only if you haven't chatted in /g", cfg.mentionSoundEnabled ~= false, function(v)
			SetCfg("mentionSoundEnabled", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Show Draggable Guild Cooldown Strip", "Display a compact live bar overlay for your selected Raid & Guild cooldowns (/cdconfig)", cfg.showCooldownOverlay ~= false, function(v)
			SetCfg("showCooldownOverlay", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Auto-Show Group & Raid Marker Bar", "Display floating Raid Target Icons, World Pins, Pull Timer & Ready Check bar in Party/Raid (/markerbar)", cfg.showRaidMarkerBar ~= false, function(v)
			SetCfg("showRaidMarkerBar", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Auto-Open Ready Check Buff & Durability Inspector", "Show active/missing buffs, consumables & armor durability % on Ready Check (/readycheck)", cfg.autoShowReadyCheck ~= false, function(v)
			SetCfg("autoShowReadyCheck", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Enable Suite Toast Notifications", "Show clean auto-fading notices for auctions, syncs, and reminders", cfg.enableNotifications ~= false, function(v)
			SetCfg("enableNotifications", v)
		end)

	elseif category == "Tooltips & Market" then
		y = AddCheckboxRow(c, rowW, y, "Enable Enhanced Item Tooltips", "Master switch for all Pluribus tooltip information", cfg.showTooltips ~= false, function(v)
			SetCfg("showTooltips", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Pluribus GearAdvisor & Cap Guardian", "Display real stat-parsed % Upgrade/Downgrade, Hit/Defense cap warnings, and Alt BoE upgrades", cfg.showGearJudgeTooltips ~= false, function(v)
			SetCfg("showGearJudgeTooltips", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show You / Alt / Guild Bag Counts", "Display how many of an item you, your alts, and guildmates hold", cfg.showTooltipCounts ~= false, function(v)
			SetCfg("showTooltipCounts", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Guild Profession Needs (Surplus)", "Highlight in emerald green when YOU don't need an item a guildmate needs", cfg.showTooltipProfNeeds ~= false, function(v)
			SetCfg("showTooltipProfNeeds", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Guild AH Market Prices, Vendor & Mean DE Value", "Display guild-synced AH buyout prices, vendor sell price & expected Disenchant value", cfg.showTooltipPrices ~= false, function(v)
			SetCfg("showTooltipPrices", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Hive / Wowhead Game DB Source", "Display cached drop/craft source and trigger silent P2P lookup on miss", cfg.showTooltipGameDB ~= false, function(v)
			SetCfg("showTooltipGameDB", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Auto-Full-Scan Auction House on Open (20m CD)", "Runs a full AH scan automatically when opening the AH (max once per 20 minutes)", cfg.autoScanAH ~= false, function(v)
			SetCfg("autoScanAH", v)
		end)

	elseif category == "Modules & Data" then
		y = AddOptionalDatabasesCard(c, rowW, y, shell, category)

		y = AddCheckboxRow(c, rowW, y, "Enable Distributed Hive Compute Mesh", "Split leveling & farming guide math across idle guildmates with strict zero-lag caps", cfg.computeEnabled ~= false, function(v)
			SetCfg("computeEnabled", v)
		end)

		y = AddChoiceRow(c, rowW, y, "Hive Compute CPU Slice Cap (Zero-Lag)", "Maximum milliseconds per 10Hz frame slice when computing guild guides", {
			{ label = "0.8ms", value = 0.8 },
			{ label = "1.5ms", value = 1.5 },
			{ label = "3.0ms", value = 3.0 },
		}, tonumber(cfg.computeBudgetMs) or 1.5, function(v)
			SetCfg("computeBudgetMs", v)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddChoiceRow(c, rowW, y, "Minimum FPS Guard", "Automatically pause distributed compute whenever client FPS drops below:", {
			{ label = "30 FPS", value = 30 },
			{ label = "45 FPS", value = 45 },
			{ label = "60 FPS", value = 60 },
		}, tonumber(cfg.computeMinFps) or 45, function(v)
			SetCfg("computeMinFps", v)
			PluribusSettingsPanel:ShowCategory(shell, category)
		end)

		y = AddCheckboxRow(c, rowW, y, "Pause Compute Inside Dungeons & Raids", "Always suspend background guide math during combat and inside instances", cfg.computePauseInInstances ~= false, function(v)
			SetCfg("computePauseInInstances", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Enable Combat Analytics", "Track real-time DPS/HPS/encounter segments (taint-safe, zero CLEU)", cfg.enableAnalytics ~= false, function(v)
			SetCfg("enableAnalytics", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Enable Passive Data Collector", "Record quest, drop, and gather node sightings for your guild", cfg.enableDataCollector ~= false, function(v)
			SetCfg("enableDataCollector", v)
		end)

		local openModsBtn = UI:CreateButton(c, "Manage All 27 Suite Addons (in Hub -> Market & Tools)", rowW - 8, 28, function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Modules")
			end
		end, true)
		openModsBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y - 4)
		y = y - 40

	elseif category == "Shortcuts & Guide" then
		local tips = {
			{ "Circular Infinity Minimap Orb", "Left-Click: Guild Hub (/pluribus) · Right-Click: Settings · Shift+Right-Click: Officer Console." },
			{ "Guild Chat @Mentions", "Type @Player, @Mage, @Dwarf, @Alchemy, @Healer, or @guild in /g! Sound queues during combat/instances & skips if they already replied." },
			{ "Dungeon Finder Smart LFG Tab", "Open WoW's Dungeon Finder (I) -> click the Smart Guild LFG side tab to post & join guild groups." },
			{ "Unified Bags, Bank & Guild Bank (/bags)", "One taint-free Unified UI for Bags, Bank & Guild Bank with sorting, category filters, Auto-Sell Trash, Auto-Repair & Fast Auto-Loot." },
			{ "Auctionator Selling, Shopping Lists & Disenchant Sniper", "Open the AH for 1-click Selling/Undercut, Shopping Lists with Advanced Filters, Live To-Do Sync & Disenchant Deals below mean DE value." },
			{ "To-Do & Einkaufsliste (/todo, /einkaufsliste)", "Per-item Buy (1-click AH Shopping tab) or Farm mode (inline calculated Farm Route + 1-click Navigate)." },
			{ "Pluribus GearAdvisor (/gearadvisor, /xpbar)", "Real EN+DE tooltip stat parser, customizable stat weights, Bag Upgrade Scanner, Cap Guardian, Roadmap & XP Bar." },
			{ "Auto-Calculated Guides (/guides)", "Automatically computes optimal Leveling & Farming guides in the background under strict zero-lag FPS guards." },
			{ "Smart Terrain/NavMesh Pathfinder (/nav, /way x y)", "Terrain-, road-, pass- & obstacle-aware routing using game-internal waypoints and learned walkable mesh. Alt+Click World Map to set pins." },
			{ "SOS Rescue Popup (/sos)", "Sends open-world SOS alerts with a 1-click [Einladen + Navi] popup for nearby guildmates." },
			{ "Guild Mail, Open-All & Guild Tax (/mail, /tax)", "1-click 'Alle öffnen' at the WoW Mailbox (skips COD), offline Guild Mail & automatic Guild Tax vault/banker payments." },
			{ "Officer Dashboard & Audit Log (/plbofficer, /audit)", "Manage DKP/EPGP awards, view unified DKP/Loot/Tax transaction history & audit trails, filter by member, or export CSV." },
			{ "Raid Marker Bar & Pull Timer (/markerbar, /pull 10)", "Auto-appears in Party/Raid with 8 target icons, 8 world pins, Pull countdown & Ready Check." },
			{ "Ready Check Inspector (/readycheck, /rc)", "Shows every member's active/missing buffs, flasks, food & armor durability % with 1-click chat report." },
			{ "On-Screen Cooldown Selection (/cdconfig)", "Choose exact Raid & Guild ability cooldowns to display on-screen with Scope filters & presets." },
			{ "Unified HealBot + Decursive (/healbot, /decursive)", "Combat-safe click-cast party/raid grid + 1-click Decursive cleanse squares & compact MUF mode." },
		}
		for _, t in ipairs(tips) do
			local row = UI:CreateCard(c, rowW, 44)
			row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
			local l1 = UI:CreateLabel(row, "|cff38bdf8" .. t[1] .. "|r", nil, nil, nil, "GameFontNormal")
			l1:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -5)
			local l2 = UI:CreateLabel(row, "|cffcbd5e1" .. t[2] .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -3)
			l2:SetWidth(rowW - 20)
			y = y - 48
		end
	end

	c:SetHeight(math.max(360, math.abs(y) + 14))
end

local function CreateBlizzardCategoryCanvas(canvasName, displayName, categoryKey, parentName)
	local canvas = CreateFrame("Frame", canvasName, UIParent)
	canvas.name = displayName
	if parentName then
		canvas.parent = parentName
	end
	canvas:SetSize(640, 520)
	canvas:Hide()

	local built = false
	canvas:SetScript("OnShow", function(selfCanvas)
		if not built and _G.PluribusUIFramework then
			built = true
			local w = math.max(580, math.floor(selfCanvas:GetWidth() or 640))
			local h = math.max(460, math.floor(selfCanvas:GetHeight() or 520))
			PluribusSettingsPanel:BuildNativeCategoryShell(selfCanvas, categoryKey, w, h)
		elseif built then
			PluribusSettingsPanel:ShowCategory(selfCanvas, categoryKey)
		end
	end)
	return canvas
end

-- Register Pluribus Suite AND all its subcategories directly into WoW's native Settings / Interface Options tree!
function PluribusSettingsPanel:RegisterBlizzardSettings()
	if self.blizzardCanvas then return end

	local rootCanvas = CreateBlizzardCategoryCanvas("PluribusBlizzardSettingsCanvas", "Pluribus Suite", "General & UI", nil)
	self.blizzardCanvas = rootCanvas
	self.blizzardSubCanvases = { ["General & UI"] = rootCanvas }
	self.blizzardSubCategories = {}

	if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory then
		local ok, rootCat = pcall(_G.Settings.RegisterCanvasLayoutCategory, rootCanvas, "Pluribus Suite")
		if ok and rootCat then
			pcall(_G.Settings.RegisterAddOnCategory, rootCat)
			self.blizzardCategory = rootCat
			self.blizzardSubCategories["General & UI"] = rootCat

			if _G.Settings.RegisterCanvasLayoutSubcategory then
				for _, catName in ipairs(self.categoryOrder) do
					if catName ~= "General & UI" then
						local safe = catName:gsub("[^%w]", "")
						local subCanvas = CreateBlizzardCategoryCanvas("PluribusBlizzSubCanvas_" .. safe, catName, catName, "Pluribus Suite")
						self.blizzardSubCanvases[catName] = subCanvas
						local okSub, subCat = pcall(_G.Settings.RegisterCanvasLayoutSubcategory, rootCat, subCanvas, catName)
						if okSub and subCat then
							self.blizzardSubCategories[catName] = subCat
						end
					end
				end
			end
		end
	elseif _G.InterfaceOptions_AddCategory then
		pcall(_G.InterfaceOptions_AddCategory, rootCanvas)
		for _, catName in ipairs(self.categoryOrder) do
			if catName ~= "General & UI" then
				local safe = catName:gsub("[^%w]", "")
				local subCanvas = CreateBlizzardCategoryCanvas("PluribusBlizzSubCanvas_" .. safe, catName, catName, "Pluribus Suite")
				self.blizzardSubCanvases[catName] = subCanvas
				pcall(_G.InterfaceOptions_AddCategory, subCanvas)
			end
		end
	end
end

function PluribusSettingsPanel:CreateSettingsFrame(parent)
	if self.standaloneFrame then return self.standaloneFrame end
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusSettingsFrame",
		parent or UIParent,
		680,
		500,
		"Pluribus Suite — Settings",
		"All Preferences (Also in ESC > Options > AddOns)"
	)
	frame:SetPoint("CENTER")
	self:BuildSettingsShell(frame, 680, 500, false)
	frame:Hide()
	self.standaloneFrame = frame
	return frame
end

-- Open Settings directly to the requested native subcategory (or standalone frame during combat)
function PluribusSettingsPanel:Open(categoryName)
	local targetCat = categoryName or "General & UI"
	self.currentCategory = targetCat

	if not (InCombatLockdown and InCombatLockdown()) then
		if _G.Settings and _G.Settings.OpenToCategory then
			local catObj = (self.blizzardSubCategories and self.blizzardSubCategories[targetCat]) or self.blizzardCategory
			if catObj then
				local id = catObj.GetID and catObj:GetID() or catObj.ID
				if id then
					local ok = pcall(_G.Settings.OpenToCategory, id)
					if ok then return end
				end
			end
		elseif _G.InterfaceOptionsFrame_OpenToCategory then
			local targetCanvas = (self.blizzardSubCanvases and self.blizzardSubCanvases[targetCat]) or self.blizzardCanvas
			if targetCanvas then
				pcall(_G.InterfaceOptionsFrame_OpenToCategory, targetCanvas)
				pcall(_G.InterfaceOptionsFrame_OpenToCategory, targetCanvas)
				return
			end
		end
	end

	local f = self:CreateSettingsFrame(UIParent)
	f:Show()
	self:ShowCategory(f, targetCat)
end

function PluribusSettingsPanel:Toggle()
	local f = self:CreateSettingsFrame(UIParent)
	if f:IsVisible() then
		f:Hide()
	else
		f:Show()
		self:ShowCategory(f, self.currentCategory or "General & UI")
	end
end

function PluribusSettingsPanel:Initialize()
	self:RegisterBlizzardSettings()
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Unified Settings Panel registered in Options > AddOns > Pluribus Suite (with native subcategories)", "SettingsPanel")
	end
end

return PluribusSettingsPanel
