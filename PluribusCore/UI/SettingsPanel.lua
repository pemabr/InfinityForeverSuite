-- PluribusCore Unified Settings Menu
-- Houses ALL suite, UI, HiveMind sharing/privacy, alerts, tooltips, market, and module settings
-- Registers natively inside WoW's Settings Menu (ESC -> Options -> AddOns -> Pluribus Suite)
-- AND opens cleanly on demand via the Settings button, Minimap Right-Click, or /pluribus settings

PluribusSettingsPanel = {
	categoryOrder = {
		"General & UI",
		"HiveMind Sharing",
		"Alerts, SOS & LFG",
		"Tooltips & Market",
		"Modules & Data",
		"Shortcuts & Guide",
	},
	currentCategory = "General & UI",
	blizzardCategory = nil,
	blizzardCanvas = nil,
	standaloneFrame = nil,
}
_G.PluribusSettingsPanel = PluribusSettingsPanel

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

-- Shared renderer used by BOTH Blizzard's native AddOns Settings panel AND the standalone Settings window
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

	local heading = UI:CreateLabel(c, "|cff38bdf8" .. category .. "|r", nil, nil, nil, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
	local y = -34

	if category == "General & UI" then
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
		y = AddCheckboxRow(c, rowW, y, "Auto-Sell Gray Trash at Vendors", "Automatically sell Poor (gray) junk items when opening any merchant (hold Shift to skip)", cfg.autoSellJunk ~= false, function(v)
			SetCfg("autoSellJunk", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Compact Mode", "Use denser row spacing in raid tables and lists", cfg.compactMode == true, function(v)
			SetCfg("compactMode", v)
		end)

	elseif category == "HiveMind Sharing" then
		-- Quick master actions
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

		y = AddCheckboxRow(c, rowW, y, "Show Draggable Guild Cooldown Strip", "Display a compact live bar overlay when guild cooldowns are active", cfg.showCooldownOverlay ~= false, function(v)
			SetCfg("showCooldownOverlay", v)
		end)

		y = AddCheckboxRow(c, rowW, y, "Enable Suite Toast Notifications", "Show clean auto-fading notices for auctions, syncs, and reminders", cfg.enableNotifications ~= false, function(v)
			SetCfg("enableNotifications", v)
		end)

	elseif category == "Tooltips & Market" then
		y = AddCheckboxRow(c, rowW, y, "Enable Enhanced Item Tooltips", "Master switch for all Pluribus tooltip information", cfg.showTooltips ~= false, function(v)
			SetCfg("showTooltips", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Sharpie's Gear Judge & Cap Guardian", "Display % Upgrade/Downgrade, Hit/Defense cap drop warnings, and Alt BoE upgrades", cfg.showGearJudgeTooltips ~= false, function(v)
			SetCfg("showGearJudgeTooltips", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show You / Alt / Guild Bag Counts", "Display how many of an item you, your alts, and guildmates hold", cfg.showTooltipCounts ~= false, function(v)
			SetCfg("showTooltipCounts", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Guild Profession Needs (Surplus)", "Highlight in emerald green when YOU don't need an item a guildmate needs", cfg.showTooltipProfNeeds ~= false, function(v)
			SetCfg("showTooltipProfNeeds", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Guild AH Market Prices & Vendor Value", "Display recent guild-synced AH buyout prices (unit & stack) + vendor sell price", cfg.showTooltipPrices ~= false, function(v)
			SetCfg("showTooltipPrices", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Show Hive / Wowhead Game DB Source", "Display cached drop/craft source and trigger silent P2P lookup on miss", cfg.showTooltipGameDB ~= false, function(v)
			SetCfg("showTooltipGameDB", v)
		end)
		y = AddCheckboxRow(c, rowW, y, "Auto-Full-Scan Auction House on Open (20m CD)", "Runs a full AH scan automatically when opening the AH (max once per 20 minutes)", cfg.autoScanAH ~= false, function(v)
			SetCfg("autoScanAH", v)
		end)

	elseif category == "Modules & Data" then
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
			{ "Unified Bags & Bank (/bags)", "One unified Bags & Bank viewer for You, Alts & Guildmates with Sell Gray Junk & AH Valuation." },
			{ "Sharpie's Gear Judge (/gearjudge, /xpbar)", "Tooltip % upgrades, Cap Guardian warnings, Alt BoE checks, The Laboratory, Roadmap, Talents & XP/Loot Bar." },
			{ "Hive Compute Guides (/guides)", "Distributed zero-lag guild compute calculates optimal Azeroth leveling & material farming guides." },
			{ "Navigation Compass (/nav, /way x y)", "Rotating floating Compass Arrow HUD + World Map side tab + live Guildmate GPS." },
			{ "Guild Mail & Guild Tax (/mail, /tax)", "Offline-capable Guild Mail inbox/composer + automatic loot/quest Guild Tax vault & banker payments." },
			{ "Officer Dashboard & Audit Log (/officer, /audit)", "Manage DKP/EPGP awards, view unified DKP/Loot/Tax transaction history & audit trails, filter by member, or export CSV." },
			{ "Auction House & Professions", "Open AH for 20m-CD full auto-scan; open any Profession for Craft Profits, Guild Recipes & Shopping List." },
		}
		for idx, t in ipairs(tips) do
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

-- Register Pluribus Suite natively inside WoW's ESC -> Options -> AddOns menu
function PluribusSettingsPanel:RegisterBlizzardSettings()
	if self.blizzardCanvas then return end
	local canvas = CreateFrame("Frame", "PluribusBlizzardSettingsCanvas", UIParent)
	canvas.name = "Pluribus Suite"
	canvas:SetSize(640, 520)

	local built = false
	canvas:SetScript("OnShow", function(selfCanvas)
		if not built and _G.PluribusUIFramework then
			built = true
			local w = math.max(580, math.floor(selfCanvas:GetWidth() or 640))
			local h = math.max(460, math.floor(selfCanvas:GetHeight() or 520))
			PluribusSettingsPanel:BuildSettingsShell(selfCanvas, w, h, true)
		elseif built then
			PluribusSettingsPanel:ShowCategory(selfCanvas, PluribusSettingsPanel.currentCategory or "General & UI")
		end
	end)

	self.blizzardCanvas = canvas

	if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory then
		local ok, category = pcall(_G.Settings.RegisterCanvasLayoutCategory, canvas, "Pluribus Suite")
		if ok and category then
			pcall(_G.Settings.RegisterAddOnCategory, category)
			self.blizzardCategory = category
		end
	elseif _G.InterfaceOptions_AddCategory then
		pcall(_G.InterfaceOptions_AddCategory, canvas)
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

-- Open Settings directly (opens Blizzard's native Settings menu when out of combat, or standalone frame)
function PluribusSettingsPanel:Open(categoryName)
	if categoryName then
		self.currentCategory = categoryName
	end
	if not (InCombatLockdown and InCombatLockdown()) then
		if self.blizzardCategory and _G.Settings and _G.Settings.OpenToCategory then
			local id = self.blizzardCategory.GetID and self.blizzardCategory:GetID() or self.blizzardCategory.ID
			if id then
				local ok = pcall(_G.Settings.OpenToCategory, id)
				if ok then return end
			end
		elseif self.blizzardCanvas and _G.InterfaceOptionsFrame_OpenToCategory then
			pcall(_G.InterfaceOptionsFrame_OpenToCategory, self.blizzardCanvas)
			pcall(_G.InterfaceOptionsFrame_OpenToCategory, self.blizzardCanvas)
			return
		end
	end
	local f = self:CreateSettingsFrame(UIParent)
	f:Show()
	self:ShowCategory(f, self.currentCategory or "General & UI")
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
		PluribusUtils:Info("Unified Settings Panel registered in Options > AddOns > Pluribus Suite", "SettingsPanel")
	end
end

return PluribusSettingsPanel
