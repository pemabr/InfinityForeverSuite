-- Finanzamt – „Was ist neu?“: einmal pro Version nach dem Update anzeigen
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF

-- neueste Version zuerst; num = VERSION_NUM der Version
GS.CHANGES = {
	{ num = 16, version = "1.0.14", items = {
		"AH-Gold aus dem Briefkasten wird zuverlässig als AH-Verkauf erkannt, auch mit „Alle öffnen“",
		"Zwei gleiche AH-Briefe werden beide gebucht",
		"Mit TradeSkillMaster eingestellte Auktionen: Anzahlung wird erfasst",
		"Icon im Erfolgsbanner sauber eingerahmt",
	} },
	{ num = 15, version = "1.0.13", items = {
		"Englische Sprache – Auswahl beim ersten Start oder unter Einstellungen",
		"Mitglieder mit Addon werden nicht mehr als „ohne Addon“ angezeigt",
		"AH-Käufe bei voller Tasche werden nicht mehr doppelt gebucht",
		"Steuerbescheid bei offener Gildenbank repariert",
	} },
	{ num = 14, version = "1.0.12", items = {
		"Reittiersteuer nur noch für Charaktere, die wirklich reiten können",
	} },
	{ num = 13, version = "1.0.11", items = {
		"Steuer-Erfolge mit Banner – Liste unter Mein Konto, Erfolge",
		"Erfolge auf Wunsch im Gildenchat (Offiziere schalten das ein)",
		"Verzugszinsen – nur in Wochen, in denen du spielst",
		"Steuerbescheid mit „Deine Woche im Überblick“",
		"Bescheid kommt nur noch einmal pro Konto",
	} },
	{ num = 12, version = "1.0.10", items = {
		"Neue Steuern: Hunde-, Kirchen-, Alkohol- und Reittiersteuer",
		"Kirchenaustritt unter Einstellungen",
		"Sparziele der Gilde mit Fortschrittsbalken (Reiter Statistik)",
		"Antworten auf Einsprüche werden dir angezeigt",
		"Übersichtlichere Aufstellung unter Mein Konto",
		"Hinweis, wenn eine neuere Version verfügbar ist",
	} },
	{ num = 11, version = "1.0.9", items = {
		"AH-Käufe werden nicht mehr doppelt gebucht",
		"Reparaturen in der Statistik",
	} },
	{ num = 10, version = "1.0.8", items = {
		"Zeigt, ob deine Steuer schon gedeckt ist",
		"Main-Charakter jetzt unter Einstellungen wählen",
	} },
	{ num = 9, version = "1.0.7", items = {
		"Statistik mit Diagrammen unter Mein Konto",
		"Neuer Reiter Einstellungen",
		"Fenster frei in Breite und Höhe ziehbar",
	} },
}

-- Änderungen seit der zuletzt gesehenen Version (beim ersten Mal nur die aktuelle)
function GS:UnseenChanges()
	local seen = self.db and self.db.newsSeen
	local out = {}
	for _, c in ipairs(self.CHANGES) do
		if c.num <= self.VERSION_NUM and (seen == nil and c.num == self.VERSION_NUM or seen ~= nil and c.num > seen) then
			out[#out + 1] = c
		end
	end
	return out
end

function GS:ChangesText(list)
	local lines = {}
	for i, c in ipairs(list) do
		if i > 1 then lines[#lines + 1] = " " end
		lines[#lines + 1] = "|cffffd100" .. LF("Version %s", c.version) .. "|r"
		for _, it in ipairs(c.items) do lines[#lines + 1] = "  – " .. L[it] end
	end
	return table.concat(lines, "\n")
end

local frame
function GS:ShowChanges(list)
	list = list or { self.CHANGES[1] }
	if #list == 0 then return end
	if not frame then
		local f = CreateFrame("Frame", "FinanzamtNews", UIParent)
		f:SetSize(460, 340)
		f:SetPoint("CENTER", 0, 60)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)
		local edge = f:CreateTexture(nil, "BORDER")
		edge:SetPoint("TOPLEFT", 0, 0)
		edge:SetPoint("TOPRIGHT", 0, 0)
		edge:SetHeight(3)
		edge:SetColorTexture(1, 0.82, 0, 0.8)
		local icon = f:CreateTexture(nil, "ARTWORK")
		icon:SetSize(28, 28)
		icon:SetPoint("TOPLEFT", 12, -12)
		icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 48, -14)
		title:SetText(L["Finanzamt – Was ist neu?"])
		local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", 48, -32)
		sub:SetText(LF("Version %s", GS.VERSION))
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
		local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 14, -54)
		sf:SetSize(410, 236)
		local child = CreateFrame("Frame", nil, sf)
		child:SetSize(410, 1)
		sf:SetScrollChild(child)
		local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 0, 0)
		text:SetWidth(400)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		if text.SetSpacing then text:SetSpacing(4) end
		local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		ok:SetSize(120, 24)
		ok:SetPoint("BOTTOM", 0, 12)
		ok:SetText(L["Alles klar"])
		ok:SetScript("OnClick", function() f:Hide() end)
		f.text, f.child = text, child
		tinsert(UISpecialFrames, "FinanzamtNews")
		frame = f
		GS.newsFrame = f
	end
	frame.text:SetText(self:ChangesText(list))
	local h = tonumber(frame.text.GetStringHeight and frame.text:GetStringHeight()) or 0
	frame.child:SetHeight(math.max(1, h + 8))
	frame:Show()
end

-- nach dem Login einmal zeigen, was seit der letzten gesehenen Version neu ist
function GS:MaybeShowChanges()
	if not self.db or not self.db.lang then return end -- erst nach der Sprachwahl
	local list = self:UnseenChanges()
	if #list == 0 or self.db.newsOff then -- abgeschaltet: trotzdem als gesehen merken
		self.db.newsSeen = math.max(self.db.newsSeen or 0, self.VERSION_NUM)
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self._newsAfterCombat = true
		return
	end
	self.db.newsSeen = self.VERSION_NUM -- als gesehen merken, sobald es angezeigt wurde
	self:ShowChanges(list)
end

GS:On("PLAYER_LOGIN", function() C_Timer.After(8, function() GS:MaybeShowChanges() end) end)
GS:Register("LANG_CHOSEN", function() GS:MaybeShowChanges() end)
GS:On("PLAYER_REGEN_ENABLED", function()
	if GS._newsAfterCombat then
		GS._newsAfterCombat = false
		GS:MaybeShowChanges()
	end
end)
