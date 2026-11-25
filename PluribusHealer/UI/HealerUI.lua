-- PluribusHealer Unified Studio UI (HealBot + Decursive)
-- Configures the live combat-safe SecureUnitButtonTemplate healing grid,
-- Click-Casting spells (7 combos + class defaults), Decursive Cleanse spells,
-- Compact MUF Mode, HoT/Range/Aggro/Alert options, and Interactive Raid Preview.

local PluribusHealerUI = {
	mainWindow = nil,
	currentTab = "clickcast",
	previewUnits = {
		{ name = "Kaelen",    class = "WARRIOR", hp = 64, maxHp = 100, debuff = "Magic" },
		{ name = "Vaelor",    class = "PALADIN", hp = 84, maxHp = 100, debuff = nil },
		{ name = "Seraphina", class = "PRIEST",  hp = 92, maxHp = 100, debuff = "Disease" },
		{ name = "Sylvara",   class = "MAGE",    hp = 54, maxHp = 100, debuff = "Curse" },
		{ name = "Thorn",     class = "DRUID",   hp = 79, maxHp = 100, debuff = "Poison" },
		{ name = "Ragnar",    class = "ROGUE",   hp = 46, maxHp = 100, debuff = nil },
		{ name = "Lyra",      class = "HUNTER",  hp = 96, maxHp = 100, debuff = nil },
		{ name = "Mordecai",  class = "WARLOCK", hp = 61, maxHp = 100, debuff = "Magic" },
	},
}
_G.PluribusHealerUI = PluribusHealerUI

local function GetEngine()
	return _G.PluribusHealDecursive
end

local function GetCfg()
	local eng = GetEngine()
	if eng and eng.config then return eng.config end
	return {
		enabled = true,
		showSolo = false,
		locked = false,
		compactMUF = false,
		frameWidth = 114,
		frameHeight = 42,
		columns = 5,
		scale = 1.0,
		showIncomingHeals = true,
		showHoTTimers = true,
		fadeOutOfRange = true,
		showAggro = true,
		highlightDebuffs = true,
		onlyDispellable = true,
		alertSound = true,
		cleansePrimary = "",
		cleanseSecondary = "",
		bindings = {},
	}
end

function PluribusHealerUI:Initialize()
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Unified HealBot + Decursive UI initialized", "Healer")
	end
end

function PluribusHealerUI:SaveAndApply()
	local eng = GetEngine()
	if eng then
		eng:SaveConfig()
		eng:RequestRebuild()
	end
	local cfg = GetCfg()
	if _G.PluribusClickCast and _G.PluribusClickCast.BindSpell then
		for combo, spell in pairs(cfg.bindings or {}) do
			pcall(function() _G.PluribusClickCast:BindSpell(combo, spell) end)
		end
	end
end

function PluribusHealerUI:Toggle(initialTab)
	if initialTab then self.currentTab = initialTab end
	if not self.mainWindow then
		self:CreateMainWindow()
	end
	if self.mainWindow:IsShown() and not initialTab then
		self.mainWindow:Hide()
	else
		if self.mainWindow.tabBar then
			self.mainWindow.tabBar:SelectTab(self.currentTab or "clickcast")
		else
			self:ShowTab(self.currentTab or "clickcast")
		end
		self.mainWindow:Show()
	end
end

function PluribusHealerUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusHealerMainWindow",
		UIParent,
		740,
		520,
		"Pluribus HealBot + Decursive",
		"Vereinte Raid-Heilframes, Klick-Zauber & 1-Klick Entzauberung"
	)
	frame:SetPoint("CENTER")

	-- Quick Action Header Bar
	local eng = GetEngine()
	local toggleGridBtn = PluribusUIFramework:CreateButton(frame, "Live-Grid An/Aus", 122, 22, function()
		if eng then eng:ToggleGrid() end
		PluribusHealerUI:ShowTab(PluribusHealerUI.currentTab)
	end, true)
	toggleGridBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -44)

	local mufToggleBtn = PluribusUIFramework:CreateButton(frame, "Decursive MUF", 112, 22, function()
		if eng then eng:ToggleCompactMUF() end
		PluribusHealerUI:ShowTab(PluribusHealerUI.currentTab)
	end)
	mufToggleBtn:SetPoint("RIGHT", toggleGridBtn, "LEFT", -6, 0)

	local tabs = {
		{ name = "HealBot Klick-Zauber", key = "clickcast" },
		{ name = "Decursive & Auren",    key = "decursive" },
		{ name = "Grid & Layout",        key = "layout" },
		{ name = "Test-Vorschau",        key = "preview" },
	}

	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(key)
		PluribusHealerUI.currentTab = key
		PluribusHealerUI:ShowTab(key)
	end, 472)
	tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
	frame.tabBar = tabBar

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetSize(712, 424)
	frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)

	self.mainWindow = frame
	tabBar:SelectTab(self.currentTab or "clickcast")
end

function PluribusHealerUI:ShowTab(tabKey)
	if not self.mainWindow or not self.mainWindow.content then return end
	local c = self.mainWindow.content
	local UI = PluribusUIFramework
	UI:ClearContainer(c)

	local cfg = GetCfg()
	local eng = GetEngine()

	if tabKey == "clickcast" then
		local card = UI:CreateCard(c, 712, 370, "HealBot Klick-Zauber (Kampfsichere SecureUnitButton-Frames)")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)

		local combos = {
			{ key = "Left-Click",   label = "Linksklick" },
			{ key = "Right-Click",  label = "Rechtsklick" },
			{ key = "Middle-Click", label = "Mittelklick" },
			{ key = "Shift+Left",   label = "Shift + Links" },
			{ key = "Shift+Right",  label = "Shift + Rechts" },
			{ key = "Ctrl+Left",    label = "Strg + Links" },
			{ key = "Alt+Left",     label = "Alt + Links" },
		}
		local inputs = {}
		local y = -34
		for _, item in ipairs(combos) do
			local lbl = UI:CreateLabel(card, "|cff38bdf8" .. item.label .. "|r")
			lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 16, y)

			local box = UI:CreateInputBox(card, 270, 24)
			box:SetPoint("TOPLEFT", card, "TOPLEFT", 136, y + 4)
			box:SetText((cfg.bindings and cfg.bindings[item.key]) or "")
			inputs[item.key] = box

			local bindBtn = UI:CreateButton(card, "Übernehmen", 96, 24, function()
				cfg.bindings = cfg.bindings or {}
				cfg.bindings[item.key] = box:GetText()
				PluribusHealerUI:SaveAndApply()
				UI:ShowNotification("Belegt: " .. item.label .. " -> " .. tostring(box:GetText()), 2.2)
			end)
			bindBtn:SetPoint("LEFT", box, "RIGHT", 10, 0)

			y = y - 40
		end

		local hint = UI:CreateLabel(card, "|cff94a3b8Tipp: Zaubernamen werden automatisch in deiner WoW-Sprache (Deutsch/Englisch) geladen.|r", nil, nil, nil, "GameFontHighlightSmall")
		hint:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 10)

		local saveBtn = UI:CreateButton(c, "Alle Klick-Zauber speichern", 190, 28, function()
			cfg.bindings = cfg.bindings or {}
			for key, box in pairs(inputs) do
				cfg.bindings[key] = box:GetText()
			end
			PluribusHealerUI:SaveAndApply()
			UI:ShowNotification("|cff4ade80HealBot Klick-Zauber aktiv & gespeichert.|r", 2.5)
		end, true)
		saveBtn:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -10)

		local defBtn = UI:CreateButton(c, "Klassen-Standard laden", 168, 28, function()
			if eng then eng:ResetClassDefaults() end
			PluribusHealerUI:ShowTab("clickcast")
			UI:ShowNotification("|cff38bdf8Klassen-Standardzauber automatisch geladen.|r", 2.5)
		end)
		defBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)

	elseif tabKey == "decursive" then
		local card = UI:CreateCard(c, 712, 370, "Decursive 1-Klick Entzauberung & HoT-Anzeige")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)

		local cls = eng and eng:GetPlayerClass() or "PRIEST"
		local dispTypes = eng and eng.CLASS_DISPEL_TYPES[cls] or {}
		local canList = {}
		for dt, ok in pairs(dispTypes) do
			if ok then table.insert(canList, dt) end
		end
		table.sort(canList)
		local canStr = #canList > 0 and table.concat(canList, ", ") or "Keine eigenen Dispels"

		local clsInfo = UI:CreateLabel(card, string.format("Deine Klasse: |cfffbbf24%s|r  ·  Entfernbar: |cff4ade80%s|r", cls, canStr))
		clsInfo:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -34)

		local c1Lbl = UI:CreateLabel(card, "|cff38bdf8Primär-Cleanse (Linksklick):|r")
		c1Lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -66)
		local c1Box = UI:CreateInputBox(card, 230, 24)
		c1Box:SetPoint("TOPLEFT", card, "TOPLEFT", 214, -62)
		c1Box:SetText(cfg.cleansePrimary or "")

		local c2Lbl = UI:CreateLabel(card, "|cffa855f7Sekundär-Cleanse (Rechtsklick):|r")
		c2Lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -100)
		local c2Box = UI:CreateInputBox(card, 230, 24)
		c2Box:SetPoint("TOPLEFT", card, "TOPLEFT", 214, -96)
		c2Box:SetText(cfg.cleanseSecondary or "")

		local saveCleanse = UI:CreateButton(card, "Cleanse speichern", 132, 24, function()
			cfg.cleansePrimary = c1Box:GetText()
			cfg.cleanseSecondary = c2Box:GetText()
			PluribusHealerUI:SaveAndApply()
			UI:ShowNotification("|cff4ade80Decursive Cleanse-Zauber gespeichert.|r", 2.4)
		end, true)
		saveCleanse:SetPoint("LEFT", c1Box, "RIGHT", 10, 0)

		local cbDebuff = UI:CreateCheckbox(card, "Decursive Debuff-Hervorhebung & 1-Klick Cleanse-Quadrat aktivieren", cfg.highlightDebuffs ~= false, function(v)
			cfg.highlightDebuffs = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbDebuff:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -138)

		local cbOnly = UI:CreateCheckbox(card, "Nur von meiner Klasse entfernbare Debuffs hervorheben", cfg.onlyDispellable ~= false, function(v)
			cfg.onlyDispellable = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbOnly:SetPoint("TOPLEFT", cbDebuff, "BOTTOMLEFT", 0, -6)

		local cbSound = UI:CreateCheckbox(card, "Warnton abspielen, sobald ein neuer entfernbarer Debuff auftritt", cfg.alertSound ~= false, function(v)
			cfg.alertSound = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbSound:SetPoint("TOPLEFT", cbOnly, "BOTTOMLEFT", 0, -6)

		local cbMuf = UI:CreateCheckbox(card, "Kompakter Decursive MUF-Modus (kleine 1-Klick Quadrate statt breiter Balken)", cfg.compactMUF == true, function(v)
			cfg.compactMUF = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbMuf:SetPoint("TOPLEFT", cbSound, "BOTTOMLEFT", 0, -6)

		local cbHot = UI:CreateCheckbox(card, "Aktive HoT-Timer anzeigen (Erneuerung, Verjüngung, Nachwachsen, Schild)", cfg.showHoTTimers ~= false, function(v)
			cfg.showHoTTimers = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbHot:SetPoint("TOPLEFT", cbMuf, "BOTTOMLEFT", 0, -6)

		local keyLbl = UI:CreateLabel(card, "|cff94a3b8Farblegende:|r  |cff38bdf8Magie [M]|r   |cffa855f7Fluch [F]|r   |cff4ade80Gift [G]|r   |cfffbbf24Krankheit [K]|r")
		keyLbl:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 14)

	elseif tabKey == "layout" then
		local card = UI:CreateCard(c, 712, 370, "Raid-/Gruppen-Grid Geometrie & Verhalten")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)

		local cbEn = UI:CreateCheckbox(card, "Vereintes HealBot + Decursive Live-Grid aktivieren", cfg.enabled ~= false, function(v)
			cfg.enabled = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbEn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -34)

		local cbSolo = UI:CreateCheckbox(card, "Auch Solo anzeigen (ideal zum Positionieren & Testen)", cfg.showSolo == true, function(v)
			cfg.showSolo = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbSolo:SetPoint("TOPLEFT", cbEn, "BOTTOMLEFT", 0, -4)

		local cbLock = UI:CreateCheckbox(card, "Position sperren (kein versehentliches Verschieben)", cfg.locked == true, function(v)
			cfg.locked = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbLock:SetPoint("TOPLEFT", cbSolo, "BOTTOMLEFT", 0, -4)

		local cbInc = UI:CreateCheckbox(card, "Eingehende Heilung (Heal Prediction) auf Balken anzeigen", cfg.showIncomingHeals ~= false, function(v)
			cfg.showIncomingHeals = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbInc:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -4)

		local cbRange = UI:CreateCheckbox(card, "Spieler außerhalb 40m Reichweite verblassen", cfg.fadeOutOfRange ~= false, function(v)
			cfg.fadeOutOfRange = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbRange:SetPoint("TOPLEFT", cbInc, "BOTTOMLEFT", 0, -4)

		local cbAggro = UI:CreateCheckbox(card, "Roten Aggro-Rahmen bei hoher Bedrohung anzeigen", cfg.showAggro ~= false, function(v)
			cfg.showAggro = v
			PluribusHealerUI:SaveAndApply()
		end)
		cbAggro:SetPoint("TOPLEFT", cbRange, "BOTTOMLEFT", 0, -4)

		-- Width, Height, Columns Steppers
		local wLbl = UI:CreateLabel(card, "Breite: |cfffbbf24" .. tostring(cfg.frameWidth or 114) .. "px|r")
		wLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -228)
		local wMin = UI:CreateButton(card, "-10", 40, 22, function()
			cfg.frameWidth = math.max(74, (cfg.frameWidth or 114) - 10)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		wMin:SetPoint("LEFT", wLbl, "RIGHT", 14, 0)
		local wPlu = UI:CreateButton(card, "+10", 40, 22, function()
			cfg.frameWidth = math.min(180, (cfg.frameWidth or 114) + 10)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		wPlu:SetPoint("LEFT", wMin, "RIGHT", 4, 0)

		local hLbl = UI:CreateLabel(card, "Höhe: |cfffbbf24" .. tostring(cfg.frameHeight or 42) .. "px|r")
		hLbl:SetPoint("LEFT", wPlu, "RIGHT", 28, 0)
		local hMin = UI:CreateButton(card, "-4", 36, 22, function()
			cfg.frameHeight = math.max(26, (cfg.frameHeight or 42) - 4)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		hMin:SetPoint("LEFT", hLbl, "RIGHT", 12, 0)
		local hPlu = UI:CreateButton(card, "+4", 36, 22, function()
			cfg.frameHeight = math.min(72, (cfg.frameHeight or 42) + 4)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		hPlu:SetPoint("LEFT", hMin, "RIGHT", 4, 0)

		local cLbl = UI:CreateLabel(card, "Spalten: |cfffbbf24" .. tostring(cfg.columns or 5) .. "|r")
		cLbl:SetPoint("LEFT", hPlu, "RIGHT", 28, 0)
		local cMin = UI:CreateButton(card, "-", 28, 22, function()
			cfg.columns = math.max(1, (cfg.columns or 5) - 1)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		cMin:SetPoint("LEFT", cLbl, "RIGHT", 10, 0)
		local cPlu = UI:CreateButton(card, "+", 28, 22, function()
			cfg.columns = math.min(8, (cfg.columns or 5) + 1)
			PluribusHealerUI:SaveAndApply()
			PluribusHealerUI:ShowTab("layout")
		end)
		cPlu:SetPoint("LEFT", cMin, "RIGHT", 4, 0)

	elseif tabKey == "preview" then
		local card = UI:CreateCard(c, 712, 360, "Interaktive HealBot + Decursive Vorschau (Linksklick = Heilen · Rechtsklick / Strg = Entzaubern)")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)

		local cols = 4
		for i, u in ipairs(self.previewUnits) do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			local cr, cg, cb, cHex = UI:GetClassColor(u.class)
			local bar = UI:CreateStatusBar(card, 162, 46, cr, cg, cb)
			bar:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + col * 172, -42 - row * 60)

			local debuffTag = u.debuff and (" |cfff87171[" .. u.debuff .. "]|r") or ""
			bar:SetBarData(u.hp, cHex .. u.name .. "|r" .. debuffTag, tostring(u.hp) .. "%")
			bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")

			bar:SetScript("OnClick", function(_, mouseBtn)
				if mouseBtn == "RightButton" or (IsControlKeyDown and IsControlKeyDown()) then
					if u.debuff then
						local sp = cfg.cleansePrimary ~= "" and cfg.cleansePrimary or (cfg.bindings and cfg.bindings["Ctrl+Left"]) or "Cleanse"
						UI:ShowNotification("|cff38bdf8Decursive:|r " .. u.debuff .. " von " .. u.name .. " entfernt (" .. sp .. ")", 2.2)
						u.debuff = nil
					end
				else
					local sp = (cfg.bindings and cfg.bindings["Left-Click"]) or "Heilung"
					u.hp = math.min(100, u.hp + 24)
					UI:ShowNotification("|cff4ade80HealBot:|r " .. sp .. " auf " .. u.name, 2.0)
				end
				PluribusHealerUI:ShowTab("preview")
			end)
		end

		local simBtn = UI:CreateButton(c, "Raid-Schaden & Debuffs simulieren", 220, 26, function()
			local types = { "Magic", "Curse", "Poison", "Disease" }
			for idx, u in ipairs(self.previewUnits) do
				u.hp = math.max(18, u.hp - math.random(12, 34))
				if idx % 2 == 1 then
					u.debuff = types[math.random(1, #types)]
				end
			end
			PluribusHealerUI:ShowTab("preview")
		end, true)
		simBtn:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -10)
	end
end

return PluribusHealerUI
