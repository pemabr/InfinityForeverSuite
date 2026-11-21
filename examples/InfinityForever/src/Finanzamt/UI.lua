-- Finanzamt – Oberfläche und Slash-Befehle
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local floor = math.floor

local UI = {}
GS.UI = UI

local W, H = 840, 540
local PW, PH = 812, 470 -- Panelgröße

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function Label(parent, text, x, y, template)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	fs:SetText(text or "")
	fs._par, fs._px, fs._py = parent, x, y
	return fs
end

local function Button(parent, text, w, x, y, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", fn)
	b._par, b._px, b._py = parent, x, y
	return b
end

local function Edit(parent, w, x, y, onChange)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20)
	e:SetPoint("TOPLEFT", x + 6, y)
	e._par, e._px, e._py = parent, x + 6, y
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	if onChange then
		e:SetScript("OnTextChanged", function(self, user) if user then onChange(self) end end)
	end
	return e
end

local function Check(parent, x, y, text, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", x, y)
	c._par, c._px, c._py = parent, x, y
	local l = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	l:SetPoint("LEFT", c, "RIGHT", 2, 0)
	l:SetText(text or "")
	c.label = l
	if onClick then c:SetScript("OnClick", onClick) end
	return c
end

-- Element am unteren Rand seines Rahmens festmachen (wandert beim Vergrößern mit nach unten)
local function PinB(w)
	local par = w._par
	w:ClearAllPoints()
	w:SetPoint("TOPLEFT", par, "BOTTOMLEFT", w._px, (par.baseH or PH) + w._py)
	return w
end
-- Element am rechten Rand festmachen (wandert beim Verbreitern mit nach rechts)
local function PinR(w)
	local par = w._par
	w:ClearAllPoints()
	w:SetPoint("TOPLEFT", par, "TOPRIGHT", w._px - (par.baseW or PW), w._py)
	return w
end

local function Enable(w, on)
	if w and w.SetEnabled then w:SetEnabled(on and true or false) end
end

local function Money(c) return GS:FormatMoney(c) end

-- Erklär-Tooltips: Titel + Text (Text darf eine Funktion sein, dann wird er beim Anzeigen erzeugt)
function UI.AttachTip(frame, title, text)
	if not frame or not frame.SetScript then return end
	if frame.EnableMouse then frame:EnableMouse(true) end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title, 1, 0.82, 0)
		local t = type(text) == "function" and text() or text
		for line in ((t or "") .. "\n"):gmatch("(.-)\n") do GameTooltip:AddLine(line, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- unsichtbare Fläche über einem Text, die beim Drüberfahren erklärt
function UI.TipZone(parent, x, y, w, h, title, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("TOPLEFT", x, y)
	f:SetSize(w, h)
	UI.AttachTip(f, title, text)
	return f
end

-- kleiner "?"-Button mit allen Begriffen der Steueraufstellung
function UI.HelpButton(parent, x, y)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(22, 20)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText("?")
	UI.AttachTip(b, L["Was bedeutet was?"], function() return UI.GlossaryText() end)
	return b
end

function UI.GlossaryText()
	local T = GS:GetEffective("tariff", GS:CurrentWeek())
	local P = function(c) return GS:FormatMoney(c, true) end
	local zones = {}
	for _, z in ipairs(T.zones or {}) do zones[#zones + 1] = z end
	table.sort(zones, function(a, b) return a[1] < b[1] end)
	local free, parts = 0, {}
	for i, z in ipairs(zones) do
		if z[2] > 0 and free == 0 then free = z[1] end
		local to = zones[i + 1] and ("–" .. P(zones[i + 1][1])) or "+"
		parts[#parts + 1] = P(z[1]) .. to .. ": " .. GS:FormatPercent(z[2]) .. " %"
	end
	local lines = {
		LF("|cffffd100Grundfreibetrag:|r Die ersten %s Einkommen pro Woche sind steuerfrei.", P(free)),
		LF("|cffffd100Werbungskosten:|r Absetzbare Käufe (zum bezahlten Preis) und Reparaturen. Mindestens der Pauschbetrag von %s wird abgezogen.", P(T.pausch or 0)),
		L["|cffffd100Zu versteuerndes Einkommen:|r Loot + Quests + Händler (minus Rückkäufe) minus Werbungskosten."],
		LF("|cffffd100Einkommensteuer:|r progressiv – jeder Satz gilt nur für den Teil in seiner Stufe: %s.", table.concat(parts, ", ")),
		LF("|cffffd100Soli:|r %s %% auf die Einkommensteuer.", GS:FormatPercent(T.soli or 0)),
		LF("|cffffd100Umsatzsteuer:|r %s %% auf den AH-Gewinn.", GS:FormatPercent(T.ust or 0)),
		LF("|cffffd100Gewerbesteuer:|r %s %% auf den AH-Gewinn über %s pro Woche.", GS:FormatPercent(T.gew or 0), P(T.gewFree or 0)),
		L["|cffffd100AH-Gewinn:|r Verkaufserlös minus verlorene Anzahlungen minus Wareneinsatz (gekaufte Handwerkswaren wie Erz, Kräuter, Stoff). Verluste werden in die Folgewochen vorgetragen."],
		L["|cffffd100Steuerfrei:|r Gold von Spielern (Handel, Post) und aus der Gildenbank."],
		L["|cffffd100Saldo:|r Einzahlungen + Item-Einlagen minus Entnahmen und Steuern. Ab 0 bist du quitt."],
		L["|cffffd100Fällig:|r Die Steuer einer Woche ist bis zum Ende der Folgewoche zu zahlen."],
		L["|cffffd100Rundung:|r Nur die Gesamtsteuer wird auf volles Kupfer abgerundet."],
	}
	return table.concat(lines, "\n")
end

-- Fehler beim Aufbau eines Tabs abfangen und im Chat melden (sonst bleibt der Tab still leer)
local reportedErrors = {}
function UI.SafeCall(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local msg = tostring(err)
		if not reportedErrors[where .. msg] then
			reportedErrors[where .. msg] = true
			GS:Print(LF("|cffff4040Fehler in „%s“:|r %s", where, msg))
			GS:Print(L["Bitte diese Meldung an den Addon-Entwickler schicken."])
		end
	end
	return ok
end

-- Item-Namen vor dem Sortieren festhalten: GetItemInfo kann während des Sortierens
-- nachladen, dann wäre die Vergleichsfunktion inkonsistent ("invalid order function")
local function nameSnapshot(ids)
	local t = {}
	for _, id in ipairs(ids) do t[id] = GS:ItemName(id) end
	return t
end

function UI.Trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Bestätigungsdialog (WoW-StaticPopup mit Warnsymbol)
function UI.Confirm(text, onAccept, acceptLabel)
	if not StaticPopupDialogs or not StaticPopup_Show then
		GS:Print(L["Bestätigungsdialog nicht verfügbar – Aktion abgebrochen."])
		return
	end
	if not StaticPopupDialogs.FINANZAMT_CONFIRM then
		StaticPopupDialogs.FINANZAMT_CONFIRM = {
			text = "%s",
			button1 = L["Ja, sofort ändern"],
			button2 = L["Abbrechen"],
			OnAccept = function(_, data) if data then data() end end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			showAlert = true,
			preferredIndex = 3,
		}
	end
	StaticPopupDialogs.FINANZAMT_CONFIRM.button1 = acceptLabel or L["Ja, sofort ändern"]
	StaticPopup_Show("FINANZAMT_CONFIRM", text, nil, onAccept)
end

---------------------------------------------------------------------------
-- Steuern tilgen: offenen Betrag in die Gildenbank einzahlen
---------------------------------------------------------------------------
function GS:OutstandingTaxes()
	local a = self:G() and self:AccountFor(self.player)
	if not a then return 0 end
	return math.max(0, -math.floor(a.bal))
end

function GS:PayTaxes()
	if not self:G() then return end
	if not self.bankOpen then
		self:Print(L["Zum Tilgen muss die Gildenbank geöffnet sein."])
		return
	end
	if not DepositGuildBankMoney then
		self:Print(L["Dieser Client unterstützt keine Einzahlung per Addon."])
		return
	end
	local due = self:OutstandingTaxes()
	if due <= 0 then
		self:Print(L["Dein Konto ist ausgeglichen – nichts zu tilgen."])
		return
	end
	local amount = math.min(due, GetMoney())
	if amount <= 0 then
		self:Print(LF("Du hast kein Gold dabei. Offen sind %s.", self:FormatMoney(due)))
		return
	end
	local text = LF("Steuern tilgen:\n\n%s in die Gildenbank einzahlen?", self:FormatMoney(amount))
	if amount < due then
		text = text .. LF("\n\n|cffffd100Teilzahlung – insgesamt offen sind %s.|r", self:FormatMoney(due))
	end
	UI.Confirm(text, function()
		if not GS.bankOpen then
			GS:Print(L["Die Gildenbank wurde geschlossen – keine Einzahlung."])
			return
		end
		DepositGuildBankMoney(amount)
		GS:LogEvent("pay", amount)
		GS:Print(LF("Steuern getilgt: %s eingezahlt. Die Buchung erscheint, sobald das Bank-Log aktualisiert ist.", GS:FormatMoney(amount)))
		-- Geld-Log neu laden, damit die Einzahlung gleich verbucht wird
		C_Timer.After(2, function()
			if GS.bankOpen and QueryGuildBankLog then QueryGuildBankLog((MAX_GUILDBANK_TABS or 6) + 1) end
		end)
	end, L["Einzahlen"])
end

-- "Steuern tilgen" an der Gildenbank:
--   1) WoW-Gildenbankfenster sichtbar -> Button links neben "Entnehmen"
--   2) anderes Bank-UI (Baganator, Bagnon, ElvUI …) -> kleines Panel über dessen Fenster
--   3) nichts erkannt -> Panel frei schwebend (verschiebbar, Position wird gespeichert)
local inlineButton, taxPanel

local function taxTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(L["Finanzamt: Steuern tilgen"])
	local due = GS:OutstandingTaxes()
	if due > 0 then
		GameTooltip:AddLine(LF("Zahlt deinen offenen Betrag von %s ein (mit Bestätigung).", GS:FormatMoney(due)), 1, 1, 1, true)
	else
		GameTooltip:AddLine(L["Dein Konto ist ausgeglichen."], 0.4, 1, 0.4)
	end
	GameTooltip:Show()
end

local function styleTaxButton(b, withAmount)
	local due = GS:OutstandingTaxes()
	b:SetText((withAmount and due > 0) and LF("Steuern tilgen (%s)", GS:FormatMoney(due, true)) or L["Steuern tilgen"])
	local fs = b.GetFontString and b:GetFontString()
	local w = tonumber(fs and fs:GetStringWidth()) or 110
	b:SetWidth(math.max(110, math.ceil(w) + 24))
	if b.SetEnabled then b:SetEnabled(due > 0) end
end

local function visible(f) return f and f.IsVisible and f:IsVisible() and true or false end

-- Button im Blizzard-Gildenbankfenster per Text suchen (der Name unterscheidet sich je nach Client)
local function findBankButton(parent, label)
	local function scan(f, depth)
		if depth > 4 or not f.GetChildren then return nil end
		for _, c in ipairs({ f:GetChildren() }) do
			if c.GetObjectType and c:GetObjectType() == "Button" and c.GetText then
				local t = c:GetText()
				if type(t) == "string" and t:lower() == label:lower() then return c end
			end
			local r = scan(c, depth + 1)
			if r then return r end
		end
	end
	return scan(parent, 0)
end

-- wirklich sichtbar: angezeigt, nicht durchsichtig, nicht aus dem Bild geschoben
local function onScreen(f)
	if not visible(f) then return false end
	if f.GetEffectiveAlpha and (tonumber(f:GetEffectiveAlpha()) or 1) < 0.05 then return false end
	local l, b = tonumber(f.GetLeft and f:GetLeft()), tonumber(f.GetBottom and f:GetBottom())
	if not l or not b then return false end
	local sw = tonumber(UIParent.GetWidth and UIParent:GetWidth()) or 5000
	local sh = tonumber(UIParent.GetHeight and UIParent:GetHeight()) or 5000
	return l > -100 and b > -100 and l < sw * 3 and b < sh * 3
end

local function isInside(f, ancestor)
	if not ancestor then return false end
	local p, n = f, 0
	while p and n < 20 do
		if p == ancestor then return true end
		p = p.GetParent and p:GetParent()
		n = n + 1
	end
	return false
end

-- Beschriftungen, an denen ein "Entnehmen"-Button erkannt wird
local function withdrawLabels()
	local set = { ["entnehmen"] = true, ["withdraw"] = true, ["abheben"] = true }
	if type(_G.GUILDBANK_WITHDRAW) == "string" then set[_G.GUILDBANK_WITHDRAW:lower()] = true end
	if type(_G.WITHDRAW) == "string" then set[_G.WITHDRAW:lower()] = true end
	return set
end

local function cleanText(t)
	if type(t) ~= "string" then return nil end
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return (t:gsub("^%s+", ""):gsub("%s+$", "")):lower()
end

local function usable(b)
	return type(b) == "table" and b ~= inlineButton and b.GetObjectType ~= nil and onScreen(b)
end

-- sichtbaren "Entnehmen"-Button irgendeiner Bank-Oberfläche finden
-- Rückgabe: Button, Fundweg (für /gst debug)
local function findVisibleWithdraw()
	local labels = withdrawLabels()
	-- 1. WoW-Fenster
	local blizz = _G.GuildBankFrame
	if visible(blizz) then
		local b = rawget(blizz, "WithdrawButton") or _G.GuildBankFrameWithdrawButton
		if usable(b) then return b, "GuildBankFrame.WithdrawButton" end
		for label in pairs(labels) do
			b = findBankButton(blizz, label)
			if usable(b) then return b, "GuildBankFrame (Text)" end
		end
	end
	if not EnumerateFrames then return nil end
	-- 2. Schlüssel "WithdrawButton" an einem sichtbaren Fenster (Baganator & Co.)
	local textHit
	local f = EnumerateFrames()
	while f do
		if f ~= inlineButton and visible(f) then
			local wb = rawget(f, "WithdrawButton")
			if usable(wb) then
				return wb, ((f.GetName and f:GetName()) or "?") .. ".WithdrawButton"
			end
			-- 3. Text als Ausweichweg merken
			if not textHit and f.GetObjectType and f:GetObjectType() == "Button" and f.GetText then
				local t = cleanText(f:GetText())
				if t and labels[t] and onScreen(f) then textHit = f end
			end
		end
		f = EnumerateFrames(f)
	end
	if textHit then return textHit, "Text: " .. tostring(textHit.GetName and textHit:GetName()) end
	return nil
end

-- Fremdes Gildenbank-Fenster (Baganator & Co.) anhand des Frame-Namens finden
local OTHER_UIS = { "baganator", "bagnon", "elvui", "arkinventory", "adibags", "combuctor", "inventorian" }
local function findOtherBankFrame()
	if not EnumerateFrames then return nil end
	local best, bestArea
	local f = EnumerateFrames()
	while f do
		local name = f.GetName and f:GetName()
		if name and visible(f) then
			local lname = name:lower()
			if lname:find("guild") and not lname:find("^finanzamt") then
				for _, ui in ipairs(OTHER_UIS) do
					if lname:find(ui, 1, true) then
						local area = (f:GetWidth() or 0) * (f:GetHeight() or 0)
						if area > 30000 and (not best or area > bestArea) then best, bestArea = f, area end
						break
					end
				end
			end
		end
		f = EnumerateFrames(f)
	end
	return best
end

local function createTaxPanel()
	local f = CreateFrame("Frame", "FinanzamtTaxPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(260, 52)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		f:SetBackdropColor(0, 0, 0, 0.85)
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText("Finanzamt")
	f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.info:SetPoint("TOPLEFT", 10, -24)
	f.info:SetWidth(120)
	f.info:SetJustifyH("LEFT")
	f.button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.button:SetSize(110, 22)
	f.button:SetPoint("RIGHT", -8, 0)
	f.button:SetScript("OnClick", function() GS:PayTaxes() end)
	f.button:SetScript("OnEnter", taxTooltip)
	f.button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- verschiebbar, solange es nicht an einem Bankfenster hängt
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not self.attached then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if not self.attached then
			local s = self:GetScale()
			GS.db.taxPanel = { x = self:GetLeft() * s, y = self:GetTop() * s }
		end
	end)
	f:Hide()
	UI.taxPanel = f
	return f
end

local function updateTaxPanel()
	if not taxPanel then return end
	local due = GS:OutstandingTaxes()
	taxPanel.info:SetText(due > 0 and LF("Offen: %s", GS:FormatMoney(due)) or L["|cff40ff40Nichts offen|r"])
	styleTaxButton(taxPanel.button, false)
	taxPanel.button:SetWidth(110)
end

local function placeTaxUI()
	if not GS.bankOpen or not GS:G() then
		if taxPanel then taxPanel:Hide() end
		return
	end
	-- 1) sichtbarer "Entnehmen"-Button – egal ob vom WoW-Fenster oder von Baganator & Co.
	local anchor, how = findVisibleWithdraw()
	if GS.debug and how ~= UI.lastTaxAnchor then GS:Print(LF("Steuern-tilgen-Button: %s", how or L["kein Entnehmen-Button gefunden -> Panel"])) end
	UI.lastTaxAnchor = how
	if anchor then
		if not inlineButton then
			inlineButton = CreateFrame("Button", "FinanzamtTaxButton", UIParent, "UIPanelButtonTemplate")
			inlineButton:SetScript("OnClick", function() GS:PayTaxes() end)
			inlineButton:SetScript("OnEnter", taxTooltip)
			inlineButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
			UI.bankButton = inlineButton
		end
		local host = anchor.GetParent and anchor:GetParent() or UIParent
		inlineButton:SetParent(host)
		if inlineButton.SetFrameLevel and anchor.GetFrameLevel then inlineButton:SetFrameLevel((anchor:GetFrameLevel() or 1) + 1) end
		inlineButton:SetHeight(tonumber(anchor.GetHeight and anchor:GetHeight()) or 22)
		inlineButton:ClearAllPoints()
		if isInside(anchor, _G.GuildBankFrame) then
			-- WoW-Fenster: links neben "Entnehmen" ist Platz
			inlineButton:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
			inlineButton.mode = "left"
		else
			-- andere Bank-UIs: links steht oft Text (z. B. "Gesamt"), daher über "Entnehmen"
			inlineButton:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
			inlineButton.mode = "above"
		end
		styleTaxButton(inlineButton, true)
		inlineButton:Show()
		if taxPanel then taxPanel:Hide() end
		return
	end
	if inlineButton then inlineButton:Hide() end
	-- 2) / 3) eigenes Panel
	if not taxPanel then taxPanel = createTaxPanel() end
	updateTaxPanel()
	taxPanel:ClearAllPoints()
	local other = findOtherBankFrame()
	if other then
		taxPanel:SetPoint("BOTTOMRIGHT", other, "TOPRIGHT", 0, 2)
		taxPanel.attached = true
	else
		local pos = GS.db.taxPanel
		if pos and pos.x and pos.y then
			taxPanel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
		else
			taxPanel:SetPoint("TOP", UIParent, "TOP", 0, -140)
		end
		taxPanel.attached = false
	end
	taxPanel:Show()
end
UI.PlaceTaxUI = placeTaxUI

local function onBankShown()
	-- Bankfenster (auch von Baganator & Co.) erscheinen leicht verzögert -> mehrfach platzieren
	C_Timer.After(0.3, placeTaxUI)
	C_Timer.After(1.2, placeTaxUI)
	C_Timer.After(2.5, placeTaxUI)
	C_Timer.After(5, placeTaxUI)
	C_Timer.After(0.5, function() GS:Fire("STATUS_CHANGED") end)
	-- offene Steuer: einmal pro Besuch das Tilgen anbieten
	C_Timer.After(1.5, function() GS:OfferPaymentAtBank() end)
end
local function onBankHidden()
	if taxPanel then taxPanel:Hide() end
	GS._paymentOffered = false
end

function GS:OfferPaymentAtBank()
	if not self.bankOpen or self._paymentOffered or not self:G() then return end
	if self.db.reminders == false then return end
	if (InCombatLockdown and InCombatLockdown()) then return end
	if self:OutstandingTaxes() <= 0 then return end
	self._paymentOffered = true
	self:PayTaxes()
end
local function isBankerType(t)
	return Enum and Enum.PlayerInteractionType and t == Enum.PlayerInteractionType.GuildBanker
end
GS:On("GUILDBANKFRAME_OPENED", onBankShown)
GS:On("GUILDBANKFRAME_CLOSED", onBankHidden)
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(t) if isBankerType(t) then onBankShown() end end)
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(t) if isBankerType(t) then onBankHidden() end end)
GS:Register("DATA_CHANGED", function()
	if GS.bankOpen then GS:Debounce("taxbtn", 1, placeTaxUI) end
end)

local function SignedMoney(c)
	if not c or c == 0 then return "|cffaaaaaa" .. GS:FormatMoney(0) .. "|r" end
	if c > 0 then return "|cff40ff40+|r" .. GS:FormatMoney(c) end
	return "|cffff4040-|r" .. GS:FormatMoney(-c)
end

-- Tabelle mit Scrollbereich und Zeilenauswahl
-- alle Tabellen; beim Vergrößern des Fensters wachsen die, die bis an den rechten/unteren Rand reichen
UI.stretchTables = {}
local function CreateTable(parent, x, y, w, h, cols)
	local t = { cols = cols, rows = {}, data = {}, parts = {}, heads = {} }
	-- Spalten an die Innenbreite anpassen (Breite minus Scrollleiste), falls sie zu breit sind
	local inner = w - 26
	local total = 0
	for _, c in ipairs(cols) do total = total + c.w end
	if total > inner then
		local scale = inner / total
		local used = 0
		for i, c in ipairs(cols) do
			if i == #cols then
				c.w = inner - used
			else
				c.w = math.floor(c.w * scale)
				used = used + c.w
			end
		end
	end
	local cx = 0
	for ci, c in ipairs(cols) do
		c.baseW = c.w
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("TOPLEFT", x + cx + 4, y)
		fs:SetWidth(c.w - 6)
		fs:SetJustifyH(c.j or "LEFT")
		fs:SetText(c.title)
		t.parts[#t.parts + 1] = fs
		local z
		if c.tip then
			z = CreateFrame("Frame", nil, parent)
			z:SetPoint("TOPLEFT", x + cx, y + 2)
			z:SetSize(c.w, 14)
			UI.AttachTip(z, c.title, c.tip)
			t.parts[#t.parts + 1] = z
		end
		t.heads[ci] = { fs = fs, z = z }
		cx = cx + c.w
	end
	t.x, t.y, t.baseW, t.baseH, t.parent = x, y, w, h, parent
	local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", x, y - 16)
	sf:SetSize(w - 26, h - 16)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(w - 26, 1)
	sf:SetScrollChild(child)
	local bg = parent:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", sf, "TOPLEFT", -2, 2)
	bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 2, -2)
	bg:SetColorTexture(0, 0, 0, 0.25)
	t.child, t.w, t.sf = child, w - 26, sf
	t.parts[#t.parts + 1] = sf
	t.parts[#t.parts + 1] = bg
	UI.stretchTables[#UI.stretchTables + 1] = t

	-- neue Außengröße: Spalten anteilig verbreitern, Kopfzeile und Zeilen neu setzen
	function t:Resize(nw, nh)
		local inner = nw - 26
		local base = 0
		for _, c in ipairs(self.cols) do base = base + c.baseW end
		local used, px = 0, 0
		for ci, c in ipairs(self.cols) do
			if ci == #self.cols then c.w = math.max(10, inner - used) else c.w = math.floor(c.baseW * inner / base) end
			used = used + c.w
			local hd = self.heads[ci]
			hd.fs:ClearAllPoints()
			hd.fs:SetPoint("TOPLEFT", self.x + px + 4, self.y)
			hd.fs:SetWidth(c.w - 6)
			if hd.z then
				hd.z:ClearAllPoints()
				hd.z:SetPoint("TOPLEFT", self.x + px, self.y + 2)
				hd.z:SetSize(c.w, 14)
			end
			px = px + c.w
		end
		self.w = inner
		self.sf:SetSize(inner, nh - 16)
		self.child:SetWidth(inner)
		for _, row in ipairs(self.rows) do
			row:SetWidth(inner)
			local rx = 0
			for ci, c in ipairs(self.cols) do
				local fs = row.cells[ci]
				fs:ClearAllPoints()
				fs:SetPoint("LEFT", rx + 4, 0)
				fs:SetWidth(c.w - 6)
				rx = rx + c.w
			end
		end
	end

	function t:SetShown(on)
		for _, part in ipairs(self.parts) do
			if on then part:Show() else part:Hide() end
		end
	end

	function t:SetRows(data)
		local selKey = self.selectedKey
		self.data = data
		self.selected = nil
		for i, d in ipairs(data) do
			local row = self.rows[i]
			if not row then
				row = CreateFrame("Button", nil, self.child)
				row:SetSize(self.w, 16)
				row:SetPoint("TOPLEFT", 0, -(i - 1) * 16)
				row.sel = row:CreateTexture(nil, "BACKGROUND")
				row.sel:SetAllPoints()
				row.sel:SetColorTexture(0.3, 0.6, 1, 0.25)
				row.sel:Hide()
				row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
				row.cells = {}
				local px = 0
				for ci, c in ipairs(self.cols) do
					local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					fs:SetPoint("LEFT", px + 4, 0)
					fs:SetWidth(c.w - 6)
					fs:SetJustifyH(c.j or "LEFT")
					if fs.SetWordWrap then fs:SetWordWrap(false) end
					row.cells[ci] = fs
					px = px + c.w
				end
				-- Item-Tooltip beim Drüberfahren, Shift-Klick postet den Link
				row:SetScript("OnEnter", function(r)
					local d = self.data[r.index]
					if d and d.itemID and d.itemID > 0 then
						GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
						GameTooltip:SetHyperlink("item:" .. d.itemID)
						GameTooltip:Show()
					elseif d and d.tip then
						GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
						d.tip(GameTooltip)
						GameTooltip:Show()
					end
				end)
				row:SetScript("OnLeave", function() GameTooltip:Hide() end)
				row:SetScript("OnClick", function(r)
					local d = self.data[r.index]
					if d and d.chatLink and IsModifiedClick and IsModifiedClick("CHATLINK") then
						if ChatEdit_InsertLink then ChatEdit_InsertLink(d.chatLink) end
						return
					end
					if d and d.itemID and IsModifiedClick and IsModifiedClick("CHATLINK") then
						local _, link = GS.GetItemInfo(d.itemID)
						if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
						return
					end
					self.selected = r.index
					self.selectedKey = self.data[r.index] and self.data[r.index].key
					self:Highlight()
					if self.onSelect then self.onSelect(self.data[r.index]) end
				end)
				self.rows[i] = row
			end
			row.index = i
			for ci = 1, #self.cols do
				local v = d[ci]
				row.cells[ci]:SetText(v ~= nil and tostring(v) or "")
			end
			if selKey ~= nil and d.key == selKey then self.selected = i end
			row:Show()
		end
		for i = #data + 1, #self.rows do self.rows[i]:Hide() end
		self.child:SetHeight(math.max(1, #data * 16))
		if not self.selected then self.selectedKey = nil end
		self:Highlight()
	end

	function t:Highlight()
		for i, r in ipairs(self.rows) do
			if i == self.selected then r.sel:Show() else r.sel:Hide() end
		end
	end

	function t:Selected()
		return self.selected and self.data[self.selected]
	end

	return t
end

-- Auswahlliste zu einem Textfeld: Button „Liste“ öffnet die Kandidaten unter dem Feld, Tippen filtert.
-- candidates() liefert { { name = , hint = , level = }, ... }; onPick(name) nach der Auswahl (optional)
function UI.AttachPicker(parent, ed, x, y, listW, candidates, onPick, btnW)
	local list = CreateFrame("Frame", nil, parent)
	list:SetPoint("TOPLEFT", ed, "BOTTOMLEFT", -6, -2)
	list:SetSize(listW, 222)
	list:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
	local bg = list:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.05, 0.96)
	local tbl = CreateTable(list, 4, -4, listW - 8, 214, {
		{ title = L["Name"], w = math.floor((listW - 34) * 0.45) }, { title = L["Hinweis"], w = math.floor((listW - 34) * 0.55) },
	})
	list:Hide()
	local function fill()
		local filter = UI.Trim(ed:GetText() or ""):lower()
		local rows = {}
		for _, c in ipairs(candidates() or {}) do
			if filter == "" or c.name:lower():find(filter, 1, true) then
				rows[#rows + 1] = { c.name, c.hint or "", key = c.name, name = c.name }
			end
		end
		if #rows == 0 then rows[1] = { L["|cffaaaaaaNichts gefunden|r"], "", key = "" } end
		tbl:SetRows(rows)
	end
	tbl.onSelect = function(row)
		if row and row.name then
			ed:SetText(row.name)
			list:Hide()
			if onPick then onPick(row.name) end
		end
	end
	local b = Button(parent, L["Liste"], btnW or 54, x, y, function()
		if list:IsShown() then list:Hide() else list:Show(); fill() end
	end)
	local prev = ed:GetScript("OnTextChanged")
	ed:SetScript("OnTextChanged", function(self, user)
		if type(prev) == "function" then prev(self, user) end
		if user and list:IsShown() then fill() end
	end)
	b.list, b.listTable, b.fill = list, tbl, fill
	return b
end

-- Fenster zum Anlegen und Entfernen von Sparzielen (Offiziere)
local goalFrame
function UI.ShowGoalManager()
	if not goalFrame then
		local f = CreateFrame("Frame", "FinanzamtGoals", UIParent)
		f:SetSize(480, 330)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
		Label(f, L["Sparziele der Gilde"], 12, -10, "GameFontNormal")
		local hint = Label(f, L["|cffaaaaaaFortschritt = Gold in der Gildenbank (zuletzt gesehen von einem Mitglied mit Addon). Solange niemand die Bank geöffnet hat: Steuereinnahmen seit dem Anlegen.|r"], 12, -28, "GameFontHighlightSmall")
		hint:SetWidth(456)
		local tbl = CreateTable(f, 12, -64, 456, 168, {
			{ title = L["Ziel"], w = 170 }, { title = L["Betrag"], w = 90, j = "RIGHT" }, { title = L["Erreicht"], w = 90, j = "RIGHT" }, { title = L["Seit"], w = 80 },
		})
		Label(f, L["Name:"], 12, -246, "GameFontNormalSmall")
		local edN = Edit(f, 170, 12, -262)
		Label(f, L["Betrag:"], 196, -246, "GameFontNormalSmall")
		local edV = Edit(f, 90, 196, -262)
		local bAdd = Button(f, L["Anlegen"], 90, 300, -261, function()
			local ok, err = GS:AddGoal(edN:GetText(), GS:ParseMoney(edV:GetText()))
			if ok then edN:SetText(""); edV:SetText(""); GS:Print(L["Sparziel angelegt."]) else GS:Print(L[err]) end
			f.refresh()
		end)
		local bDel = Button(f, L["Ausgewähltes entfernen"], 170, 12, -296, function()
			local sel = tbl:Selected()
			if not sel or not sel.goal then GS:Print(L["Bitte ein Ziel auswählen."]) return end
			UI.Confirm(LF("Sparziel „%s“ entfernen?", sel.goal.name), function()
				local ok, err = GS:RemoveGoal(sel.goal.id)
				if not ok then GS:Print(L[err]) end
				f.refresh()
			end, L["Entfernen"])
		end)
		f.tbl, f.edN, f.edV, f.bAdd, f.bDel = tbl, edN, edV, bAdd, bDel
		f.refresh = function()
			local can = GS:HasRight(GS.player, "corr")
			Enable(bAdd, can); Enable(bDel, can)
			local rows = {}
			for _, gl in ipairs(GS:Goals()) do
				local paid = GS:GoalProgress(gl)
				rows[#rows + 1] = { gl.name, Money(gl.target), Money(paid), date("%d.%m.", GS:WeekStart(gl.week)), key = gl.id, goal = gl }
			end
			if #rows == 0 then rows[1] = { L["|cffaaaaaaNoch keine Ziele|r"], "", "", "", key = "" } end
			tbl:SetRows(rows)
		end
		GS:Register("DATA_CHANGED", function() if f:IsShown() then f.refresh() end end)
		tinsert(UISpecialFrames, "FinanzamtGoals")
		f:Hide()
		goalFrame = f
		UI.goalFrame = f
	end
	goalFrame:Show()
	goalFrame.refresh()
end

---------------------------------------------------------------------------
-- Hauptfenster
---------------------------------------------------------------------------
local frame
local panels = {}
local tabButtons = {}
local current

local TABS = {
	{ key = "konto",  title = "Mein Konto" },
	{ key = "gilde",  title = "Gilde" },
	{ key = "offi",   title = "Offiziere" },
	{ key = "tarif",  title = "Tarif" },
	{ key = "wk",     title = "Werbungskosten" },
	{ key = "bank",   title = "Gildenbank" },
	{ key = "rechte", title = "Rechte" },
	{ key = "stats",  title = "Statistik" },
	{ key = "log",    title = "Protokoll" },
	{ key = "einst",  title = "Einstellungen" },
}

local builders = {}
UI.stretchFrames = {} -- { frame, w, h }: wachsen mit dem Fenster (z. B. Unteransichten)
UI.relayoutHooks = {} -- function(dW, dH): eigene Anpassungen einzelner Tabs

local function showTab(key)
	current = key
	for k, p in pairs(panels) do
		if k == key then p:Show() else p:Hide() end
	end
	for _, b in ipairs(tabButtons) do
		if b.key == key then b:LockHighlight() else b:UnlockHighlight() end
	end
	local p = panels[key]
	if p and p.refresh then UI.SafeCall("Tab " .. key, p.refresh, true) end
end
UI.panels = panels

local function createFrame()
	local ok, f = pcall(CreateFrame, "Frame", "FinanzamtFrame", UIParent, "BasicFrameTemplateWithInset")
	if not ok or not f then
		f = CreateFrame("Frame", "FinanzamtFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32,
				insets = { left = 8, right = 8, top = 8, bottom = 8 },
			})
		end
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -4, -4)
	end
	f:SetSize(W, H)
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true)
	f:Hide()
	tinsert(UISpecialFrames, "FinanzamtFrame")

	-- Position, Größe und Zoom merken (in UIParent-Koordinaten)
	local MIN_SCALE, MAX_SCALE = 0.6, 1.6
	local function winDB()
		GS.db.window = GS.db.window or {}
		return GS.db.window
	end
	local function savePos()
		local s = f:GetScale()
		local left, top = f:GetLeft(), f:GetTop()
		if not left or not top then return end
		local w = winDB()
		w.left, w.top, w.scale = left * s, top * s, s
		w.w, w.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
	end
	local function applyPos()
		local w = winDB()
		local s = math.max(MIN_SCALE, math.min(MAX_SCALE, w.scale or 1))
		f:SetScale(s)
		f:SetSize(math.max(W, tonumber(w.w) or W), math.max(H, tonumber(w.h) or H))
		f:ClearAllPoints()
		if w.left and w.top then
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", w.left / s, w.top / s)
		else
			f:SetPoint("CENTER")
		end
	end
	UI.ResetWindow = function()
		GS.db.window = nil
		applyPos()
		if UI.Relayout then UI.Relayout() end
	end
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePos()
	end)
	applyPos()

	-- Griff unten rechts: Breite und Höhe unabhängig ändern; mit Strg: alles zoomen
	-- (linke obere Ecke bleibt stehen). Rechtsklick: Standardgröße.
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	grip:SetFrameLevel(f:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	grip:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then return end
		local s = f:GetScale()
		local left, top = f:GetLeft() * s, f:GetTop() * s
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
		local zoom = IsControlKeyDown and IsControlKeyDown()
		local maxW = tonumber(UIParent:GetWidth()) or 0
		local maxH = tonumber(UIParent:GetHeight()) or 0
		if maxW <= 0 then maxW = 4000 end
		if maxH <= 0 then maxH = 3000 end
		grip:SetScript("OnUpdate", function()
			local es = UIParent:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			cx, cy = cx / es, cy / es
			if zoom then
				local ns = math.max(MIN_SCALE, math.min(MAX_SCALE, (cx - left) / f:GetWidth()))
				f:SetScale(ns)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / ns, top / ns)
			else
				local sc = f:GetScale()
				local nw = math.max(W, math.min(maxW / sc, (cx - left) / sc))
				local nh = math.max(H, math.min(maxH / sc, (top - cy) / sc))
				f:SetSize(nw, nh)
			end
		end)
	end)
	grip:SetScript("OnMouseUp", function(_, button)
		grip:SetScript("OnUpdate", nil)
		if button == "RightButton" then
			UI.ResetWindow()
			GS:Print(L["Fenster auf Standardgröße zurückgesetzt."])
			return
		end
		savePos()
	end)
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Ziehen: Breite und Höhe ändern"])
		GameTooltip:AddLine(L["Strg + Ziehen: alles größer/kleiner (Zoom)"], 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L["Rechtsklick: Standardgröße und -position"], 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	UI.grip = grip

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("Finanzamt " .. GS.VERSION)

	-- Tab-Buttons passend zur Textbreite, nebeneinander
	local textW, sumText = {}, 0
	for i, tab in ipairs(TABS) do
		local b = Button(f, L[tab.title], 98, 0, -28, function() showTab(tab.key) end)
		local fs = b.GetFontString and b:GetFontString()
		textW[i] = math.ceil(tonumber(fs and fs:GetStringWidth()) or 80)
		sumText = sumText + textW[i]
		b.key = tab.key
		tabButtons[i] = b
	end
	local GAP = 3
	local avail = W - 24 - GAP * (#TABS - 1)
	local pad = math.max(8, math.min(26, math.floor((avail - sumText) / #TABS)))
	local tx = 12
	for i, b in ipairs(tabButtons) do
		local bw = textW[i] + pad
		if pad >= 26 then bw = math.max(70, bw) end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", tx, -28)
		b:SetWidth(bw)
		tx = tx + bw + GAP
	end

	for _, tab in ipairs(TABS) do
		local p = CreateFrame("Frame", nil, f)
		p:SetPoint("TOPLEFT", 14, -60)
		p:SetSize(PW, PH)
		p:Hide()
		panels[tab.key] = p
		p.refresh = builders[tab.key](p)
	end

	-- Größe übernehmen: Panels, mitwachsende Rahmen und Tabellen am rechten/unteren Rand
	local lastDW, lastDH
	UI.Relayout = function()
		local dW = math.max(0, math.floor(f:GetWidth() - W + 0.5))
		local dH = math.max(0, math.floor(f:GetHeight() - H + 0.5))
		if dW == lastDW and dH == lastDH then return end
		lastDW, lastDH = dW, dH
		UI.extraW, UI.extraH = dW, dH
		for _, p in pairs(panels) do p:SetSize(PW + dW, PH + dH) end
		for _, s in ipairs(UI.stretchFrames) do
			s.frame:SetSize(s.w + dW, s.h + dH)
		end
		for _, t in ipairs(UI.stretchTables) do
			local pw = t.parent.baseW or PW
			local ph = t.parent.baseH or PH
			local sw = (t.x + t.baseW) >= pw - 2
			local sh = (-t.y + t.baseH) >= ph - 2
			if sw or sh then t:Resize(t.baseW + (sw and dW or 0), t.baseH + (sh and dH or 0)) end
		end
		for _, fn in ipairs(UI.relayoutHooks) do pcall(fn, dW, dH) end
	end
	f:SetScript("OnSizeChanged", function() UI.Relayout() end)
	UI.Relayout()

	f:SetScript("OnShow", function() showTab(current or "konto") end)
	frame = f
end

---------------------------------------------------------------------------
-- Kampf: Fenster ausblenden und nach dem Kampf wieder zeigen
---------------------------------------------------------------------------
local reopenAfterCombat -- nil oder Tab-Schlüssel

local function inCombat()
	return (InCombatLockdown and InCombatLockdown()) and true or false
end

local function deferUntilCombatEnd(key)
	if not reopenAfterCombat then
		GS:Print(L["Im Kampf – das Fenster öffnet sich nach dem Kampf."])
	end
	reopenAfterCombat = key or current or "konto"
end

function UI:Toggle()
	if reopenAfterCombat and inCombat() then
		-- erneutes Drücken im Kampf bricht das spätere Öffnen ab
		reopenAfterCombat = nil
		GS:Print(L["Fenster wird nach dem Kampf nicht geöffnet."])
		return
	end
	if inCombat() and not (frame and frame:IsShown()) then
		deferUntilCombatEnd(current)
		return
	end
	if not frame then createFrame() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

function UI:ShowTab(key)
	if inCombat() then
		deferUntilCombatEnd(key)
		return
	end
	if not frame then createFrame() end
	if not frame:IsShown() then
		current = key
		frame:Show()
	else
		showTab(key)
	end
end

GS:On("PLAYER_REGEN_DISABLED", function()
	if frame and frame:IsShown() then
		reopenAfterCombat = current or "konto"
		frame:Hide()
	end
end)

GS:On("PLAYER_REGEN_ENABLED", function()
	local key = reopenAfterCombat
	reopenAfterCombat = nil
	if key then UI:ShowTab(key) end
end)

function UI:Refresh()
	if not frame or not frame:IsShown() or not current then return end
	local p = panels[current]
	if p and p.refresh then UI.SafeCall("Tab " .. current, p.refresh, false) end
end

local function scheduleRefresh()
	if frame and frame:IsShown() then GS:Debounce("ui", 0.5, function() UI:Refresh() end) end
end
GS:Register("DATA_CHANGED", scheduleRefresh)
GS:Register("EVENTS_CHANGED", scheduleRefresh)
GS:Register("SETTINGS_CHANGED", scheduleRefresh)
GS:Register("STATUS_CHANGED", scheduleRefresh)
GS:Register("ROSTER", scheduleRefresh)
GS:Register("ITEM_INFO", scheduleRefresh)

local function noGuild(p, msg)
	if not p.noGuild then
		p.noGuild = Label(p, "", 0, -200, "GameFontNormalLarge")
		p.noGuild:SetWidth(PW)
		p.noGuild:SetJustifyH("CENTER")
	end
	p.noGuild:SetText(msg or L["Du bist in keiner Gilde (oder die Gildendaten laden noch)."])
	p.noGuild:Show()
end

local KIND_LABEL = {
	d = "Item-Einlage", w = "Item-Entnahme", D = "Gold-Einzahlung", W = "Gold-Abhebung",
	R = "Gildenreparatur", C = "Korrektur", T = "Steuer", Z = "Verzugszinsen",
}

---------------------------------------------------------------------------
-- Mein Konto
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Statistik des eigenen Kontos (unter „Mein Konto“): Kennzahlen und Diagramme
---------------------------------------------------------------------------
local STAT_COLORS = {
	loot = { 0.25, 0.8, 0.3 }, quest = { 1, 0.82, 0 }, vendor = { 0.3, 0.6, 1 }, ah = { 0.72, 0.45, 1 },
	tax = { 1, 0.3, 0.3 },
}
local STAT_SOURCES = {
	{ key = "loot", label = "Loot" }, { key = "quest", label = "Quests" },
	{ key = "vendor", label = "Händler" }, { key = "ah", label = "AH-Gewinn" },
}

-- farbiges Kästchen für Legenden (Textur statt Sonderzeichen, das die WoW-Schrift evtl. nicht hat)
local function Swatch(c)
	return string.format("|TInterface\\Buttons\\WHITE8X8:10:10:0:0:8:8:0:8:0:8:%d:%d:%d|t", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

local function CreateAccountStats(p, X, Y)
	local v = { parts = {}, tex = {}, texUsed = 0, hot = {} }
	local function add(r) v.parts[#v.parts + 1] = r; return r end
	local function text(x, y, tpl, w, j)
		local fs = add(Label(p, "", x, y, tpl or "GameFontHighlightSmall"))
		if w then fs:SetWidth(w) end
		if j then fs:SetJustifyH(j) end
		return fs
	end
	-- Rechteck aus dem Texturen-Pool (wird bei jedem Zeichnen neu belegt)
	local function rect(x, y, w, h, c, a)
		v.texUsed = v.texUsed + 1
		local t = v.tex[v.texUsed]
		if not t then
			t = p:CreateTexture(nil, "ARTWORK")
			v.tex[v.texUsed] = t
		end
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
		t:SetSize(math.max(1, w), math.max(1, h))
		t:SetColorTexture(c[1], c[2], c[3], a or 1)
		t:Show()
		return t
	end

	-- Kennzahlen: 3 Spalten x 2 Zeilen
	v.kpi = {}
	for i = 1, 9 do
		v.kpi[i] = { label = text(0, 0, "GameFontDisableSmall"), value = text(0, 0, "GameFontHighlight") }
	end
	v.chartTitle = text(X, 0, "GameFontNormalSmall")
	v.axisMax = text(X, 0, "GameFontDisableSmall")
	v.weekLabels = {}
	for i = 1, 8 do v.weekLabels[i] = text(0, 0, "GameFontDisableSmall", 50, "CENTER") end
	v.chartLegend = text(X, 0, "GameFontDisableSmall")
	v.srcTitle = text(X, 0, "GameFontNormalSmall")
	v.srcLegend = {}
	for i = 1, 4 do v.srcLegend[i] = text(0, 0, "GameFontHighlightSmall", 210) end
	v.topTitle = text(X, 0, "GameFontNormalSmall")
	-- größte Werbungskosten: je Posten eine Zeile mit festem Abstand (Item-Symbole verschieben sonst den Text)
	v.topRows = {}
	for i = 1, 4 do
		local name = text(X, 0, "GameFontHighlightSmall")
		if name.SetWordWrap then name:SetWordWrap(false) end
		v.topRows[i] = { name = name, val = text(X, 0, "GameFontHighlightSmall", 110, "RIGHT") }
	end
	v.empty = text(X, Y - 160, "GameFontDisable")
	-- Tooltip-Flächen über den Balken
	for i = 1, 8 do
		local z = CreateFrame("Frame", nil, p)
		z:EnableMouse(true)
		z:SetScript("OnEnter", function(self)
			local d = self.data
			if not d then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(LF(d.estimate and "Laufende Woche %s" or "Woche %s", GS:WeekLabel(d.week)))
			for _, src in ipairs(STAT_SOURCES) do
				local c = STAT_COLORS[src.key]
				GameTooltip:AddDoubleLine(L[src.label], GS:FormatMoney(d[src.key], true), c[1], c[2], c[3], 1, 1, 1)
			end
			local c = STAT_COLORS.tax
			GameTooltip:AddDoubleLine(d.estimate and L["Steuer (geschätzt)"] or L["Steuer"],GS:FormatMoney(d.tax, true), c[1], c[2], c[3], 1, 1, 1)
			GameTooltip:Show()
		end)
		z:SetScript("OnLeave", function() GameTooltip:Hide() end)
		v.hot[i] = add(z)
	end

	function v:SetShown(on)
		self.shown = on
		for _, r in ipairs(self.parts) do if on then r:Show() else r:Hide() end end
		if not on then for _, t in ipairs(self.tex) do t:Hide() end end
	end

	function v:Render(a)
		if not self.shown then return end
		for _, t in ipairs(self.tex) do t:Hide() end
		self.texUsed = 0
		local W = PW - X + (UI.extraW or 0)
		local st = GS:AccountStats(a, 8)
		local y = Y

		-- Kennzahlen
		local tiles = {
			{ L["Einkommen gesamt"], Money(st.income) },
			{ L["Steuer gezahlt"], Money(st.tax) },
			{ L["Steuerquote"], string.format("%.1f %%", st.rate * 100) },
			{ L["Ø Einkommen je Woche"], Money(math.floor(st.avg)) },
			{ L["Beste Woche"], st.best and st.best.income > 0 and (Money(st.best.income) .. " |cffaaaaaa" .. date("%d.%m.", GS:WeekStart(st.best.week)) .. "|r") or "–" },
			{ L["Vermögen"], Money(st.wealth or 0) .. ((st.wealthUnknown or 0) > 0 and " |cff888888+?|r" or "") },
		}
		-- Steuer letzte Woche mit Trend, Rang in der Gilde, steuerfreie Eingänge
		local lastTax, prevTax = st.recent[#st.recent - 1].tax, st.recent[#st.recent - 2].tax
		local trend = ""
		if prevTax > 0 then
			local d = (lastTax - prevTax) / prevTax * 100
			trend = string.format(" %s%+d %%|r", d <= 0 and "|cff40ff40" or "|cffff8040", math.floor(d + (d >= 0 and 0.5 or -0.5)))
		end
		tiles[#tiles + 1] = { L["Steuer letzte Woche"], Money(lastTax) .. trend }
		local rank, n = GS:TaxRank(a and a.main, GS:CurrentWeek() - 1)
		tiles[#tiles + 1] = { L["Rang Steuerzahler (letzte W.)"], rank and LF("%d. von %d", rank, n) or "–" }
		tiles[#tiles + 1] = { L["Steuerfreie Eingänge"], Money(st.untaxed) }
		local tw = math.floor(W / 3)
		for i, k in ipairs(self.kpi) do
			local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
			local kx, ky = X + col * tw, y - row * 36
			k.label:ClearAllPoints(); k.label:SetPoint("TOPLEFT", p, "TOPLEFT", kx, ky)
			k.value:ClearAllPoints(); k.value:SetPoint("TOPLEFT", p, "TOPLEFT", kx, ky - 13)
			k.label:SetText(tiles[i][1]); k.value:SetText(tiles[i][2])
		end
		y = y - 116

		-- Balkendiagramm: Einkommen je Woche (gestapelt) und Steuer
		self.chartTitle:ClearAllPoints(); self.chartTitle:SetPoint("TOPLEFT", p, "TOPLEFT", X, y)
		self.chartTitle:SetText(L["Einkommen und Steuer der letzten 8 Wochen"])
		y = y - 18
		local CH = 110 + math.floor((UI.extraH or 0) * 0.6)
		local maxV = 1
		for _, d in ipairs(st.recent) do
			maxV = math.max(maxV, d.loot + d.quest + d.vendor + d.ah, d.tax)
		end
		local LX = X + 56
		local CW = W - 60
		self.axisMax:ClearAllPoints(); self.axisMax:SetPoint("TOPRIGHT", p, "TOPLEFT", LX - 4, y)
		self.axisMax:SetText(GS:FormatMoney(maxV, true))
		local base = y - CH
		rect(LX, y, 1, CH, { 1, 1, 1 }, 0.15)
		rect(LX, base, CW, 1, { 1, 1, 1 }, 0.3)
		rect(LX, y - CH / 2, CW, 1, { 1, 1, 1 }, 0.06)
		local slot = CW / #st.recent
		local bw = math.max(4, math.floor(slot * 0.5))
		local tbw = math.max(2, math.floor(slot * 0.16))
		for i, d in ipairs(st.recent) do
			local sx = LX + (i - 1) * slot + math.floor((slot - bw - tbw - 2) / 2)
			local stack = 0
			for _, src in ipairs(STAT_SOURCES) do
				local val = d[src.key]
				if val > 0 then
					local h = val / maxV * CH
					rect(sx, base + stack + h, bw, h, STAT_COLORS[src.key], d.estimate and 0.55 or 1)
					stack = stack + h
				end
			end
			if d.tax > 0 then
				local h = d.tax / maxV * CH
				rect(sx + bw + 2, base + h, tbw, h, STAT_COLORS.tax, d.estimate and 0.55 or 1)
			end
			local lbl = self.weekLabels[i]
			lbl:ClearAllPoints(); lbl:SetPoint("TOP", p, "TOPLEFT", LX + (i - 0.5) * slot, base - 3)
			lbl:SetText((d.estimate and "|cffffd100" or "") .. date("%d.%m.", GS:WeekStart(d.week)) .. (d.estimate and "|r" or ""))
			local z = self.hot[i]
			z:ClearAllPoints(); z:SetPoint("TOPLEFT", p, "TOPLEFT", LX + (i - 1) * slot, y)
			z:SetSize(slot, CH)
			z.data = d
		end
		y = base - 18
		local leg = {}
		for _, src in ipairs(STAT_SOURCES) do
			local c = STAT_COLORS[src.key]
			leg[#leg + 1] = Swatch(c) .. " " .. L[src.label]
		end
		leg[#leg + 1] = Swatch(STAT_COLORS.tax) .. L[" Steuer   |cff888888(blass: laufende Woche, geschätzt)|r"]
		self.chartLegend:ClearAllPoints(); self.chartLegend:SetPoint("TOPLEFT", p, "TOPLEFT", LX, y)
		self.chartLegend:SetText(table.concat(leg, "  "))
		y = y - 26

		-- Einkommensquellen gesamt: 100-%-Balken mit Legende
		self.srcTitle:ClearAllPoints(); self.srcTitle:SetPoint("TOPLEFT", p, "TOPLEFT", X, y)
		self.srcTitle:SetText(L["Woher dein Einkommen kommt (alle Wochen)"])
		y = y - 16
		local total = st.loot + st.quest + st.vendor + st.ah
		local bx = X
		local BW = W - 10
		rect(X, y, BW, 14, { 1, 1, 1 }, 0.08)
		for i, src in ipairs(STAT_SOURCES) do
			local val = st[src.key]
			if total > 0 and val > 0 then
				local w = val / total * BW
				rect(bx, y, w, 14, STAT_COLORS[src.key])
				bx = bx + w
			end
			local c = STAT_COLORS[src.key]
			local l = self.srcLegend[i]
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			l:ClearAllPoints(); l:SetPoint("TOPLEFT", p, "TOPLEFT", X + col * math.floor(BW / 2), y - 20 - row * 14)
			l:SetText(Swatch(c) .. string.format(" %s: %s |cffaaaaaa(%d %%)|r",
				L[src.label], GS:FormatMoney(val, true), total > 0 and math.floor(val / total * 100 + 0.5) or 0))
		end
		y = y - 56

		-- größte Werbungskosten
		self.topTitle:ClearAllPoints(); self.topTitle:SetPoint("TOPLEFT", p, "TOPLEFT", X, y)
		self.topTitle:SetText(LF("Werbungskosten: %s insgesamt – die größten Posten", GS:FormatMoney(st.wk, true)))
		local NW = math.min(260, W - 130)
		for i, row in ipairs(self.topRows) do
			local it = st.topWK[i]
			local ry = y - 17 - (i - 1) * 16
			row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", p, "TOPLEFT", X + 8, ry)
			row.name:SetWidth(NW)
			row.val:ClearAllPoints(); row.val:SetPoint("TOPLEFT", p, "TOPLEFT", X + 8 + NW, ry)
			if it then
				local label = it.label and ("|TInterface\\Icons\\Trade_BlackSmithing:14:14|t " .. L[it.label]) or GS:ItemLabel(it.id)
				row.name:SetText(label)
				row.val:SetText(Money(it.cost))
			elseif i == 1 then
				row.name:SetText(L["|cffaaaaaaNoch keine Werbungskosten erfasst.|r"])
				row.val:SetText("")
			else
				row.name:SetText(""); row.val:SetText("")
			end
		end
		self.empty:SetText(st.income > 0 and "" or L["Noch keine Einnahmen erfasst – die Diagramme füllen sich mit der Zeit."])
	end

	v:SetShown(false)
	return v
end

builders.konto = function(p)
	-- linke Spalte: Aufstellung scrollt, der Block darunter hängt am unteren Rand
	local LW, BOTTOM = 330, 60
	local isf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
	isf:SetPoint("TOPLEFT", 0, 0)
	isf:SetSize(LW - 22, PH - BOTTOM)
	local ichild = CreateFrame("Frame", nil, isf)
	ichild:SetSize(LW - 22, 1)
	isf:SetScrollChild(ichild)
	local info = UI.CreateKV(ichild, LW - 30)
	p.infoKV = info
	local function fitInfo()
		ichild:SetHeight(math.max(1, (info.height or 0) + 4))
	end
	UI.relayoutHooks[#UI.relayoutHooks + 1] = function(_, dH) isf:SetSize(LW - 22, PH - BOTTOM + dH) end

	UI.HelpButton(p, LW - 50, 2)

	PinB(Button(p, L["Steuerbescheid"], 120, 0, -(PH - 52), function() GS:ShowNotice() end))
	PinB(Button(p, L["Exportieren"], 110, 126, -(PH - 52), function() GS:ShowExport(GS:ExportAccountText(GS:AccountOf(GS.player))) end))
	PinB(Label(p, L["|cffaaaaaaMain-Charakter und persönliche Einstellungen: Reiter „Einstellungen“.|r"], 0, -(PH - 22), "GameFontHighlightSmall"))

	local view = "stats" -- stats | book | events
	local stats = CreateAccountStats(p, 350, -30)
	p.stats = stats
	UI.relayoutHooks[#UI.relayoutHooks + 1] = function() if stats.shown then p.refresh(false) end end
	local evTbl = CreateTable(p, 350, -28, PW - 350, PH - 28, {
		{ title = L["Zeit"], w = 82 }, { title = L["Ereignis"], w = 112 }, { title = L["Details"], w = 150 },
		{ title = L["Betrag"], w = 92, j = "RIGHT" },
	})
	evTbl:SetShown(false)
	p.evTable = evTbl
	local achTbl = CreateTable(p, 350, -28, PW - 350, PH - 28, {
		{ title = L["Erfolg"], w = 168 }, { title = L["Beschreibung"], w = 196 }, { title = L["Fortschritt"], w = 98, j = "RIGHT" },
	})
	achTbl:SetShown(false)
	p.achTable = achTbl
	local bBook, bEvents, bStats, bAch
	local function setView(v)
		view = v
		p.refresh(false)
	end
	p.setView = setView
	bStats = Button(p, L["Statistik"], 100, 350, 2, function() setView("stats") end)
	bBook = Button(p, L["Buchungen"], 110, 454, 2, function() setView("book") end)
	bEvents = Button(p, L["Letzte Ereignisse"], 140, 568, 2, function() setView("events") end)
	bAch = Button(p, L["Erfolge"], 90, 712, 2, function() setView("ach") end)
	local tbl = CreateTable(p, 350, -28, PW - 350, PH - 28, {
		{ title = L["Datum"], w = 82 }, { title = L["Art"], w = 92 }, { title = L["Item / Notiz"], w = 126 },
		{ title = L["Anz."], w = 40, j = "RIGHT" }, { title = L["Betrag"], w = 96, j = "RIGHT" },
	})

	return function(full)
		if not GS:G() then info:SetRows({}); noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		local a = GS:AccountFor(GS.player)
		if not a then return end
		local cur = GS:CurrentWeek()
		local c = a.cur
		local twinks = {}
		for _, ch in ipairs(a.chars) do
			if ch ~= a.main then twinks[#twinks + 1] = ch end
		end
		local last = a.weeks[cur - 1]
		local rows = {
			{ h = LF("Konto %s", a.main) },
		}
		if #twinks > 0 then rows[#rows + 1] = { t = LF("Twinks: %s", table.concat(twinks, ", ")), c = "|cffaaaaaa" } end
		rows[#rows + 1] = { l = L["Saldo"], v = SignedMoney(a.bal) }
		rows[#rows + 1] = { l = L["Status"], v = GS:ColorStatus(a.status) }
		local pay = GS:PaymentLine(a)
		if pay then rows[#rows + 1] = { t = pay } end
		UI.AddInterestRows(rows, a)
		rows[#rows + 1] = { t = LF("|cffffd100Zuordnung:|r %s", UI.ClaimStatusText()) }
		rows[#rows + 1] = { sp = true }
		for _, r in ipairs(UI.WeekRows(c, cur, true)) do rows[#rows + 1] = r end
		rows[#rows + 1] = { sp = true }
		if last then
			rows[#rows + 1] = { l = L["Letzte Woche festgesetzt"], v = Money(last.total), n = last.small and L["Kleinbetrag – Details im Steuerbescheid"] or L["Details im Steuerbescheid"] }
		else
			rows[#rows + 1] = { t = L["Letzte Woche: keine Daten"], c = "|cffaaaaaa" }
		end
		info:SetRows(rows); fitInfo()

		tbl:SetShown(view == "book")
		evTbl:SetShown(view == "events")
		stats:SetShown(view == "stats")
		achTbl:SetShown(view == "ach")
		if view == "ach" then achTbl:SetRows(UI.AchievementRows(a.main)) end
		if view == "book" then tbl:SetRows(UI.BookingRows(a)) end
		if view == "events" then evTbl:SetRows(UI.EventRows(a)) end
		if view == "stats" then stats:Render(a) end
		for b, k in pairs({ [bBook] = "book", [bEvents] = "events", [bStats] = "stats", [bAch] = "ach" }) do
			if view == k then b:LockHighlight() else b:UnlockHighlight() end
		end
	end
end

-- Steueraufstellung einer Woche als Zeilen:
--   { h = Überschrift } | { l = Bezeichnung, v = Betrag, n = Hinweis, c = Farbcode } | { t = Text, c = Farbcode } | { sp = true }
-- isOwn: Aufstellung des eigenen Kontos (für die neutrale Anzeige von Nachschätzungen)
function UI.WeekRows(c, week, isOwn)
	local rows = {}
	-- Betrag mit eingefärbten Ziffern (Münzbuchstaben behalten ihre Farbe)
	local COL = { inc = "|cff40ff40", out = "|cffff6060", tax = "|cffff9933", total = "|cffffd100", neutral = "|cffffffff", free = "|cffaaaaaa" }
	local function amt(v, kind, sign)
		local col = COL[kind] or COL.neutral
		local cc = math.floor(math.abs(v or 0) + 1e-6)
		local g, sv, k = math.floor(cc / 10000), math.floor(cc / 100) % 100, cc % 100
		local parts = {}
		if g > 0 then parts[#parts + 1] = col .. g .. "|r|cffffd700g|r" end
		if sv > 0 then parts[#parts + 1] = col .. sv .. "|r|cffc7c7cfs|r" end
		if k > 0 or #parts == 0 then parts[#parts + 1] = col .. k .. ((GS.Lang and GS:Lang() ~= "de") and "|r|cffeda55fc|r" or "|r|cffeda55fk|r") end
		return ((sign and cc > 0) and (col .. sign .. "|r") or "") .. table.concat(parts, " ")
	end
	local function kv(l, v, n, i, col, sw)
		rows[#rows + 1] = { l = l, v = v, n = n, i = i or 0, c = col, sw = sw }
	end
	local function tx(t, col, i) rows[#rows + 1] = { t = t, c = col, i = i or 0 } end
	local cur = GS:CurrentWeek()
	local title
	if week == cur then title = L["Laufende Woche"]
	elseif week == cur - 1 then title = L["Letzte Woche"]
	else title = L["Woche"] end
	rows[#rows + 1] = { h = title .. " |cffaaaaaa(" .. GS:WeekLabel(week) .. ")|r" }
	-- Einnahmen (Farbkästchen wie im Diagramm der Statistik)
	kv(L["Loot"], amt(c.loot, "inc"), nil, 0, nil, STAT_COLORS.loot)
	kv(L["Quests"], amt(c.quest, "inc"), nil, 0, nil, STAT_COLORS.quest)
	kv(L["Händler"], amt(c.vendor, "inc"), (c.buyback or 0) > 0 and LF("brutto %s, Rückkauf %s", GS:FormatMoney(c.vendorGross or 0, true), GS:FormatMoney(c.buyback, true)) or nil, 0, nil, STAT_COLORS.vendor)
	if (c.ahFees or 0) > 0 or (c.ahRefund or 0) > 0 or (c.ahCarryIn or 0) > 0 or (c.matGross or 0) > 0 then
		kv(L["AH-Verkäufe"], amt(c.ah, "inc"), nil, 0, nil, STAT_COLORS.ah)
		if (c.matGross or 0) > 0 then
			kv(L["– Wareneinsatz"], amt(c.matCost or 0, "out", "–"), (c.matRev or 0) > 0 and LF("%s in die Gildenbank gelegt", GS:FormatMoney(c.matRev, true)) or nil, 1)
		end
		local lost = (c.ahFees or 0) - (c.ahRefund or 0)
		kv(L["– Anzahlungen"], amt(math.max(0, lost), "out", "–"),
			LF("%s gezahlt, %s zurück", GS:FormatMoney(c.ahFees or 0, true), GS:FormatMoney(c.ahRefund or 0, true)), 1)
		if (c.ahCarryIn or 0) > 0 then kv(L["– Verlustvortrag"], amt(c.ahCarryIn, "out", "–"), nil, 1) end
		kv(L["= AH-Gewinn"], amt(c.ahNet or 0, "inc"), (c.ahCarryOut or 0) > 0 and LF("Verlust %s wird vorgetragen", GS:FormatMoney(c.ahCarryOut, true)) or nil, 1)
	else
		kv(L["AH-Erlöse"], amt(c.ah, "inc"), nil, 0, nil, STAT_COLORS.ah)
	end
	if (c.untaxed or 0) > 0 then kv(L["Steuerfrei (ohne Quelle)"], amt(c.untaxed, "free"), nil, 0, "|cffaaaaaa") end
	local officer = GS:CanSeeEvasion()
	if c.evasion and c.evasion > 0 then
		if officer then
			kv(L["Steuerhinterziehung"], amt(c.evasion, "out", "+"), L["ohne aktives Addon eingenommen, wird nachversteuert"]
				.. ((c.penalty or 0) > 0 and LF(", Zuschlag %s", GS:FormatMoney(c.penalty, true)) or ""), 0, "|cffff4040")
		elseif isOwn then
			kv(L["Nachschätzung"], amt(c.evasion + (c.penalty or 0), "out", "+"))
		end
	end
	if (c.waived or 0) > 0 and officer then kv(GS:Lang() == "de" and "Erlassen" or "Waived", amt(c.waived, "inc"), L["Hinterziehung wird nicht versteuert"], 1, "|cff40ff40") end
	local wkNote = LF("tatsächlich %s", GS:FormatMoney(c.wkActual or 0, true))
		.. ((c.wkEff == c.pausch and (c.wkActual or 0) < (c.pausch or 0)) and L[", Pauschbetrag angesetzt"] or "")
		.. ((c.wkRev or 0) > 0 and LF(", %s zurückgenommen (Gildenbank)", GS:FormatMoney(c.wkRev, true)) or "")
	kv(L["– Werbungskosten"], amt(c.wkEff, "out", "–"), wkNote)
	kv(L["= Zu versteuern"], amt(c.taxable, "neutral"), nil, 0, "|cffffffff")
	if c.exemptReason == "Neuling" then
		tx(L["Neulings-Befreiung: diese Woche steuerfrei"], "|cff40ff40", 1)
	elseif c.exemptReason == "Rang" then
		tx(LF("Rang-Faktor: %s %% der Steuer", GS:FormatPercent(c.factor or 1)), "|cff80c0ff", 1)
	end
	if (c.levelExempt or 0) > 0 then tx(LF("%s Charakter(e) unter der Level-Grenze steuerfrei", tostring(c.levelExempt)), "|cffaaaaaa", 1) end
	rows[#rows + 1] = { sp = true }
	-- Steuern: Zuschläge auf die Einkommensteuer eingerückt
	kv(L["Einkommensteuer"], amt(c.est, "tax"))
	kv(L["+ Solidaritätszuschlag"], amt(c.soli, "tax"), nil, 1)
	if (c.church or 0) > 0 then kv(L["+ Kirchensteuer"], amt(c.church, "tax"), nil, 1) end
	if (c.ust or 0) > 0 or (c.gew or 0) > 0 then
		kv(L["Umsatzsteuer"], amt(c.ust, "tax"), L["auf den AH-Gewinn"])
		if (c.gew or 0) > 0 then kv(L["+ Gewerbesteuer"], amt(c.gew, "tax"), nil, 1) end
	end
	if (c.dog or 0) > 0 then kv(L["Hundesteuer"], amt(c.dog, "tax"), LF("%s Jäger/Hexenmeister", tostring(c.dogChars))) end
	if (c.alc or 0) > 0 then kv(L["Alkoholsteuer"], amt(c.alc, "tax"), LF("auf %s Getränke", GS:FormatMoney(c.alcBase or 0, true))) end
	if (c.mount or 0) > 0 then kv(L["Reittiersteuer"], amt(c.mount, "tax"), LF("%s Charakter(e) mit Reittier", tostring(c.mountChars))) end
	kv(week >= cur and L["= Voraussichtliche Steuer"] or L["= Festgesetzte Steuer"], amt(c.total, "total"), c.small and L["Kleinbetrag, entfällt"] or nil, 0, "|cffffd100")
	if c.deferredUntil then tx(LF("Gestundet bis %s", date("%d.%m.", GS:WeekStart(c.deferredUntil + 1))), "|cff80c0ff", 1) end
	return rows
end

-- dieselbe Aufstellung als Textzeilen (Steuerbescheid, Export)
function UI.RowsToLines(lines, rows)
	for _, r in ipairs(rows) do
		if r.h then
			lines[#lines + 1] = "|cffffd100" .. r.h .. "|r"
		elseif r.l then
			lines[#lines + 1] = string.rep("  ", 1 + (r.i or 0)) .. (r.c or "") .. r.l .. ":|r " .. r.v .. (r.n and (" |cffaaaaaa(" .. r.n .. ")|r") or "")
		elseif r.t then
			lines[#lines + 1] = string.rep("  ", 1 + (r.i or 0)) .. (r.c or "") .. r.t .. "|r"
		else
			lines[#lines + 1] = " "
		end
	end
	return lines
end

function UI.AppendWeekLines(lines, c, week, isOwn)
	return UI.RowsToLines(lines, UI.WeekRows(c, week, isOwn))
end

-- zweispaltige Darstellung: Bezeichnung links, Betrag rechtsbündig, Hinweise klein darunter
function UI.CreateKV(parent, width)
	local kv = { pool = {}, used = 0, width = width }
	local function fs(tpl)
		kv.used = kv.used + 1
		local f = kv.pool[kv.used]
		if not f then
			f = parent:CreateFontString(nil, "OVERLAY", tpl)
			kv.pool[kv.used] = f
		end
		f:SetFontObject(tpl)
		f:ClearAllPoints()
		f:SetJustifyH("LEFT")
		if f.SetWordWrap then f:SetWordWrap(true) end
		f:SetWidth(0)
		f:Show()
		return f
	end
	local function height(f, fallback)
		local h = tonumber(f.GetStringHeight and f:GetStringHeight())
		return (h and h > 0) and h or fallback
	end
	function kv:SetRows(rows)
		self.used = 0
		local W, y = self.width, 0
		for _, r in ipairs(rows) do
			if r.h then
				local f = fs("GameFontNormal")
				f:SetPoint("TOPLEFT", 0, y)
				f:SetWidth(W)
				f:SetText(r.h)
				y = y - height(f, 14) - 4
			elseif r.l then
				local col = r.c or ""
				local x = 8 + (r.i or 0) * 12
				local l = fs("GameFontHighlightSmall")
				l:SetPoint("TOPLEFT", x, y)
				l:SetWidth(math.floor(W * 0.58) - x)
				if l.SetWordWrap then l:SetWordWrap(false) end
				l:SetText((r.sw and (Swatch(r.sw) .. " ") or "") .. col .. r.l .. (col ~= "" and "|r" or ""))
				local v = fs("GameFontHighlightSmall")
				v:SetPoint("TOPLEFT", math.floor(W * 0.5), y)
				v:SetWidth(W - math.floor(W * 0.5))
				v:SetJustifyH("RIGHT")
				if v.SetWordWrap then v:SetWordWrap(false) end
				v:SetText(r.v or "")
				y = y - 14
				if r.n then
					local n = fs("GameFontDisableSmall")
					n:SetPoint("TOPLEFT", x + 10, y)
					n:SetWidth(W - x - 10)
					n:SetText(r.n)
					y = y - height(n, 12) - 2
				end
			elseif r.t then
				local x = 8 + (r.i or 0) * 12
				local f = fs("GameFontHighlightSmall")
				f:SetPoint("TOPLEFT", x, y)
				f:SetWidth(W - x)
				f:SetText((r.c or "") .. r.t .. (r.c and "|r" or ""))
				y = y - height(f, 14) - 1
			else
				y = y - 8
			end
		end
		for i = self.used + 1, #self.pool do self.pool[i]:Hide() end
		self.height = -y
		return -y
	end
	return kv
end

local EVENT_LABEL = {
	l = "Loot", q = "Questbelohnung", v = "Händlerverkauf", a = "AH-Verkauf",
	wk = "Werbungskosten", rep = "Reparatur", rb = "Rückkauf", dep = "AH-Anzahlung",
	x = "|cffff4040Hinterziehung|r", pay = "|cff40ff40Steuer getilgt|r", ref = "Anzahlung zurück",
	o = "Sonstiges (steuerfrei)", pm = "Post (steuerfrei)", tr = "Handel (steuerfrei)", xc = "Nachschätzung (Absturz)",
	mat = "Wareneinsatz", alc = "Alkohol-Einkauf",
}
-- steuerfreie Eingänge: grau statt grün
local EVENT_FREE = { o = true, pm = true, tr = true }
-- Einnahmen (steuerpflichtig) grün mit +, Abzüge/Ausgaben grau mit –
local EVENT_SIGN = { l = 1, q = 1, v = 1, a = 1, x = 1, xc = 1, ref = 1, o = 1, pm = 1, tr = 1, mat = -1, alc = -1, wk = -1, rep = -1, rb = -1, dep = -1, pay = -1 }

function UI.EventRows(a)
	local list = {}
	for _, ch in ipairs(a and a.chars or { GS.player }) do
		local cdb = GS.db.chars[ch]
		for idx, e in ipairs(cdb and cdb.events or {}) do list[#list + 1] = { e = e, char = ch, idx = idx } end
	end
	-- neueste zuerst; bei gleicher Zeit das zuletzt erfasste zuerst
	table.sort(list, function(x, y)
		if x.e.t ~= y.e.t then return x.e.t > y.e.t end
		if x.idx ~= y.idx then return x.idx > y.idx end
		return x.char < y.char
	end)
	local officer = GS:CanSeeEvasion()
	local rows = {}
	for i, it in ipairs(list) do
		local e = it.e
		local details = ""
		if e.id then
			details = GS:ItemLabel(e.id) .. ((e.n or 1) > 1 and (" x" .. e.n) or "") .. (e.src and (" (" .. L[e.src] .. ")") or "")
		elseif (e.n or 1) > 1 then
			details = LF("%s Buchungen", tostring(e.n))
		end
		if not e.id and e.src then details = L[e.src] .. (details ~= "" and (", " .. details) or "") end
		if e.k == "o" then details = details .. (details ~= "" and " " or "") .. L["|cffaaaaaaQuelle unbekannt|r"] end
		if e.k == "wk" or e.k == "rep" then details = details .. (details ~= "" and " " or "") .. L["|cffaaaaaaabsetzbar|r"] end
		if e.k == "mat" then details = details .. (details ~= "" and " " or "") .. L["|cffaaaaaamindert AH-Gewinn|r"] end
		if e.k == "alc" then details = details .. (details ~= "" and " " or "") .. L["|cffaaaaaaAlkoholsteuer|r"] end
		if it.char ~= GS.player then details = details .. " |cffaaaaaa– " .. it.char .. "|r" end
		local amount = (EVENT_SIGN[e.k] or 1) > 0 and ((EVENT_FREE[e.k] and "|cffaaaaaa+|r" or "|cff40ff40+|r") .. Money(e.a)) or ("|cffaaaaaa–|r" .. Money(e.a))
		local label = EVENT_LABEL[e.k] and L[EVENT_LABEL[e.k]] or e.k
		if e.k == "x" and not officer then label = L["Nachschätzung"] end
		if e.dup then
			label = "|cff888888" .. label .. "|r"
			details = details .. L[" |cffff8040(doppelt, gegengebucht)|r"]
			amount = "|cff888888" .. GS:FormatMoney(e.a, true) .. "|r"
		end
		rows[#rows + 1] = { date("%d.%m. %H:%M", e.t), label, details, amount, key = i, itemID = e.id, ev = e, char = it.char }
	end
	if #rows == 0 then rows[1] = { "", L["|cffaaaaaaNoch keine Ereignisse erfasst.|r"], "", "", key = 0 } end
	return rows
end

function UI.BookingRows(a)
	local rows = {}
	for i, b in ipairs(a.bookings) do
		local what = b.note or ""
		if b.item and b.item > 0 then
			what = GS:ItemLabel(b.item) .. (b.note and (" – " .. b.note) or "")
			if GS:IsUnverified(b.src) then what = what .. L[" |cffff8040(ungeprüft)|r"] end
		end
		rows[#rows + 1] = { date("%d.%m. %H:%M", b.t), KIND_LABEL[b.kind] and L[KIND_LABEL[b.kind]] or b.kind, what, b.count or "", SignedMoney(b.amount), key = i, itemID = b.item }
	end
	return rows
end

-- Erfolge eines Kontos als Tabellenzeilen (nach Kategorie, mit Überschriften)
function UI.AchievementRows(main)
	local states = GS:AchievementStates(main)
	local done = 0
	for _, s in ipairs(states) do if s.done then done = done + 1 end end
	local own = main == GS:AccountOf(GS.player)
	local rows = { { LF("|cffffd100%d von %d Erfolgen|r", done, #states), own and L["|cffaaaaaaShift-Klick: Link in den Chat|r"] or "", "" } }
	local lastCat
	for i, s in ipairs(states) do
		local def = s.def
		if def.cat ~= lastCat then
			lastCat = def.cat
			rows[#rows + 1] = { "|cffffd100" .. GS:AchCat(def.cat) .. "|r", "", "" }
		end
		local ic = "|T" .. def.icon .. ":14:14|t "
		local dname, ddesc = GS:AchName(def), GS:AchDesc(def)
		local name = s.done and (ic .. "|cffffffff" .. dname .. "|r") or ("|cff777777" .. ic .. dname .. "|r")
		local stand = s.done and ("|cff40ff40" .. (s.seen and date("%d.%m.%y", s.seen) or L["erreicht"]) .. "|r")
			or ("|cffaaaaaa" .. GS:AchProgressText(s) .. "|r")
		rows[#rows + 1] = { name, s.done and ddesc or ("|cffaaaaaa" .. ddesc .. "|r"), stand, key = "ach" .. i,
			chatLink = (own and s.done) and GS:AchChatText(def.id) or nil,
			tip = function(tt)
				tt:AddLine("|T" .. def.icon .. ":22:22|t " .. dname, 1, 0.82, 0)
				tt:AddLine(ddesc, 1, 1, 1, true)
				tt:AddLine(" ")
				if s.done then
					tt:AddLine(s.seen and LF("Errungen am %s", date("%d.%m.%Y", s.seen)) or L["Errungen"], 0.6, 1, 0.6)
				end
				tt:AddLine(LF("Fortschritt: %s", GS:AchProgressText(s)), 0.8, 0.8, 0.8)
				if own and s.done then tt:AddLine(L["Shift-Klick: Link in den Chat"], 0.5, 0.5, 0.5) end
			end }
	end
	return rows
end

-- Erfolge-Ansicht öffnen (Klick auf das Banner)
function UI.ShowAchievements()
	UI:ShowTab("konto")
	local p = UI.panels and UI.panels.konto
	if p and p.setView then p.setView("ach") end
end

-- Hinweise zu Verzugszinsen als Zeilen (je Zeile ein Eintrag)
function UI.AddInterestRows(rows, a)
	local zl = GS:InterestLine(a)
	if not zl then return end
	for l in (zl .. "\n"):gmatch("(.-)\n") do rows[#rows + 1] = { t = l } end
end

-- Version für die Offiziersliste: eigene Meldung, sonst/neuer die des Kontos (über einen anderen Charakter)
function UI.VersionText(name, st)
	local v, vs, via = GS:AccountVersion(name)
	if v and via and via ~= name and (not st or not st.v or v > st.v) then
		return (vs or "?") .. LF(" |cffaaaaaa(über %s)|r", via)
	end
	return (st and st.vs) or "-"
end

-- Zuordnungsstatus des eigenen Charakters als Text (Mein Konto, Einstellungen)
function UI.ClaimStatusText()
	local claim = GS.db and GS.player and GS:MyChar().main
	local confirmed = GS:G() and GS:Links()[GS.player]
	if claim then
		if confirmed == claim then return LF("|cff40ff40Twink von %s (bestätigt)|r", claim) end
		return LF("|cffffd100Twink von %s – wartet auf Bestätigung durch einen Offizier|r", claim)
	elseif confirmed then
		return LF("Twink von %s (von einem Offizier zugeordnet)", confirmed)
	end
	local isMain = false
	for _, m in pairs(GS:G() and GS:Links() or {}) do if m == GS.player then isMain = true break end end
	return isMain and L["Main mit Twinks"] or L["|cffaaaaaaeigenes Konto (kein Twink)|r"]
end

---------------------------------------------------------------------------
-- Einstellungen (persönlich, nur für diesen Spieler)
---------------------------------------------------------------------------
builders.einst = function(p)
	Label(p, L["Persönliche Einstellungen – gelten nur für dich, nicht für die Gilde."], 0, 0, "GameFontHighlightSmall")
	Label(p, L["Chat"], 0, -24, "GameFontNormal")
	local cLoot = Check(p, 0, -40, L["Steuer in Geld-Meldungen anzeigen (Loot, Händler, Quests)"], function(self)
		GS.db.lootTaxMsg = self:GetChecked() and true or false
		p.refresh(false)
	end)
	local cDetail = Check(p, 16, -60, L["Bei steuerfreien Einnahmen den Restfreibetrag zeigen"], function(self)
		GS.db.lootTaxDetail = self:GetChecked() and true or false
	end)
	Label(p, L["Hinweise"], 0, -92, "GameFontNormal")
	local cNotice = Check(p, 0, -108, L["Steuerbescheid nach dem Reset automatisch anzeigen"], function(self)
		GS.db.noticeAuto = self:GetChecked() and true or false
	end)
	local cRem = Check(p, 0, -128, L["Erinnerungen (Fälligkeit, Tilgen an der Gildenbank anbieten)"], function(self)
		GS.db.reminders = self:GetChecked() and true or false
	end)
	local cTip = Check(p, 0, -148, L["Finanzamt-Infos in Item-Tooltips (absetzbar, Marktwert)"], function(self)
		GS.db.tooltipInfo = self:GetChecked() and true or false
	end)
	Label(p, L["Oberfläche"], 0, -180, "GameFontNormal")
	local cMini = Check(p, 0, -196, L["Minimap-Button anzeigen"], function()
		GS:ToggleMinimapButton()
		p.refresh(false)
	end)
	local cNews = Check(p, 190, -196, L["„Was ist neu?“ nach Updates zeigen"], function(self)
		GS.db.newsOff = (not self:GetChecked()) and true or nil
	end)
	p.cNews = cNews
	Button(p, L["Was ist neu?"], 110, 196, -226, function()
		local all = {}
		for _, c in ipairs(GS.CHANGES or {}) do if c.num <= GS.VERSION_NUM then all[#all + 1] = c end end
		GS:ShowChanges(all)
	end)
	Button(p, L["Fenster auf Standardgröße"], 190, 0, -226, function()
		UI.ResetWindow()
		GS:Print(L["Fenster auf Standardgröße zurückgesetzt."])
	end)
	Label(p, L["|cffaaaaaaAuch: Rechtsklick auf den Griff unten rechts oder /gst fenster.|r"], 0, -252, "GameFontHighlightSmall")
	Label(p, L["Fehlersuche"], 0, -278, "GameFontNormal")
	local cDebug = Check(p, 0, -294, L["Debug-Modus (zusätzliche Meldungen im Chat, wie /gst debug)"], function(self)
		GS.debug = self:GetChecked() and true or false
		GS.db.debug = GS.debug or nil
	end)
	local cDev = Check(p, 0, -316, L["Entwicklerversion (nicht veröffentlicht, nicht als neueste melden)"], function(self)
		GS.db.devVersion = self:GetChecked() and true or nil
		GS:SendHeartbeat()
	end)
	Label(p, "Sprache · Language", 0, -346, "GameFontNormal")
	local langBtns = {}
	for i, lang in ipairs(GS.LANGS) do
		local b = Button(p, GS.LANG_NAMES[lang], 90, (i - 1) * 96, -364, function()
			if GS:Lang() == lang then return end
			GS.db.lang = lang
			UI.Confirm(GS:LangText("Die Sprache wird nach dem Neuladen der Oberfläche umgestellt. Jetzt neu laden?", lang),
				function() ReloadUI() end, GS:LangText("Neu laden", lang))
			p.refresh(false)
		end)
		langBtns[lang] = b
	end
	p.langBtns = langBtns
	UI.AttachTip(cDev, L["Entwicklerversion"], L["Für Test-Versionen, die noch nicht veröffentlicht sind: Deine Versionsnummer wird nicht an die Gilde gemeldet. So bekommt niemand eine Update-Erinnerung wegen deiner Version, und die Offiziersliste zeigt andere nicht als veraltet."])
	p.cLoot, p.cDetail, p.cNotice, p.cTip, p.cRem, p.cMini, p.cDebug, p.cDev = cLoot, cDetail, cNotice, cTip, cRem, cMini, cDebug, cDev

	-- rechte Spalte: Main-Charakter (Twink-Zuordnung)
	local MX = 430
	Label(p, L["Erfolge"], MX, -196, "GameFontNormal")
	local cAchToast = Check(p, MX, -212, L["Banner bei neuen Erfolgen anzeigen"], function(self)
		GS.db.achToastOff = (not self:GetChecked()) and true or nil
	end)
	Button(p, L["Test"], 50, MX + 240, -212, function() GS:TestAchToast() end)
	local cAchChat = Check(p, MX, -234, L["Erfolge im Gildenchat melden (gilt für alle)"], function(self)
		local ok, err = GS:SetAchChat(self:GetChecked())
		if not ok then GS:Print(L[err or "Keine Berechtigung"]) end
		p.refresh(false)
	end)
	UI.AttachTip(cAchChat, L["Erfolge im Gildenchat"], L["Nur Offiziere mit dem Recht für Korrekturen können das umschalten. Ist es an, meldet das Addon neu errungene Erfolge jedes Mitglieds als klickbaren Link im Gildenchat."])
	p.cAchToast, p.cAchChat = cAchToast, cAchChat
	Label(p, L["Main-Charakter"], MX, -24, "GameFontNormal")
	local mDesc = Label(p, L["|cffaaaaaaNur auf Twinks eintragen. Main und Twinks teilen sich ein Steuerkonto; ein Offizier bestätigt die Zuordnung.|r"], MX, -42, "GameFontHighlightSmall")
	mDesc:SetWidth(PW - MX)
	local ed = Edit(p, 150, MX, -74)
	p.mainEdit = ed
	local list -- Auswahlliste (unten)
	local function save(name)
		name = UI.Trim(name or "")
		if name == "" then return end
		name = name:sub(1, 1):upper() .. name:sub(2)
		name = GS:ResolveName(name)
		if name == GS.player then
			GS:MyChar().main = nil
		else
			GS:MyChar().main = name
			if GS.rosterLoaded and not GS.roster[name] then
				GS:Print(LF("|cffffd100Hinweis:|r %s ist nicht in deiner Gilde – die Zuordnung wirkt erst, wenn beide in derselben Gilde sind.", name))
			end
		end
		ed:ClearFocus()
		if list then list:Hide() end
		GS:SendHeartbeat()
		GS:Fire("DATA_CHANGED")
		p.refresh(true)
	end
	local bList = Button(p, L["Liste"], 60, MX + 162, -73, function()
		if list:IsShown() then list:Hide() else list:Show(); p.fillList() end
	end)
	UI.AttachTip(bList, L["Charakter auswählen"], L["Mitglieder deiner Gilde. Charaktere desselben WoW-Accounts stehen oben.\nTippen im Feld filtert die Liste."])
	Button(p, L["Eintragen"], 80, MX + 226, -73, function() save(ed:GetText()) end)
	Button(p, L["Entfernen"], 74, MX + 310, -73, function()
		GS:MyChar().main = nil
		ed:SetText("")
		if list then list:Hide() end
		GS:SendHeartbeat()
		GS:Fire("DATA_CHANGED")
		p.refresh(true)
	end)
	local claimInfo = Label(p, "", MX, -102, "GameFontHighlightSmall")
	claimInfo:SetWidth(PW - MX)
	local guildWarn = Label(p, "", MX, -124, "GameFontHighlightSmall")
	guildWarn:SetWidth(PW - MX)
	guildWarn:SetJustifyV("TOP")
	p.claimInfo, p.guildWarn = claimInfo, guildWarn

	-- Kirchensteuer: Austritt / Wiedereintritt (gilt für das ganze Konto, ab der nächsten Woche)
	Label(p, L["Kirchensteuer"], MX, -300, "GameFontNormal")
	local churchInfo = Label(p, "", MX, -318, "GameFontHighlightSmall")
	churchInfo:SetWidth(PW - MX)
	local bChurch = Button(p, L["Aus der Kirche austreten"], 190, MX, -350, function()
		local main = GS:AccountOf(GS.player)
		local leaving = not GS:ChurchPending(main)
		local text = leaving
			and L["Aus der Kirche austreten?\n\nDein Konto zahlt ab der nächsten Steuerwoche keine Kirchensteuer mehr. Der Austritt ist für alle Offiziere sichtbar."]
			or L["Wieder in die Kirche eintreten?\n\nDein Konto zahlt ab der nächsten Steuerwoche wieder Kirchensteuer."]
		UI.Confirm(text, function()
			local ok, err = GS:SetChurchMember(not leaving)
			if ok then
				GS:Print(leaving and L["Kirchenaustritt erklärt – gilt ab der nächsten Steuerwoche."] or L["Wiedereintritt erklärt – gilt ab der nächsten Steuerwoche."])
			else
				GS:Print(L[err])
			end
			p.refresh(false)
		end, leaving and L["Austreten"] or L["Eintreten"])
	end)
	p.churchInfo, p.bChurch = churchInfo, bChurch

	-- Auswahlliste unter dem Feld
	list = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
	list:SetPoint("TOPLEFT", MX, -96)
	list:SetSize(PW - MX, 230)
	list:SetFrameLevel((p:GetFrameLevel() or 1) + 20)
	local lbg = list:CreateTexture(nil, "BACKGROUND")
	lbg:SetAllPoints()
	lbg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
	local ltbl = CreateTable(list, 4, -4, PW - MX - 8, 222, {
		{ title = L["Charakter"], w = 150 }, { title = L["Lvl"], w = 34, j = "RIGHT" }, { title = L["Hinweis"], w = 190 },
	})
	ltbl.onSelect = function(row) if row and row.name then ed:SetText(row.name); list:Hide() end end
	list:Hide()
	p.mainList, p.mainListTable = list, ltbl
	function p.fillList()
		local filter = UI.Trim(ed:GetText() or ""):lower()
		local rows = {}
		for _, c in ipairs(GS:MainCandidates()) do
			if filter == "" or c.name:lower():find(filter, 1, true) then
				rows[#rows + 1] = { c.name, c.level or "", c.hint or "", key = c.name, name = c.name }
			end
		end
		if #rows == 0 then
			rows[1] = { GS:G() and L["|cffaaaaaaKein passender Charakter|r"] or L["|cffaaaaaaKeine Gilde – keine Auswahl möglich|r"], "", "", key = "" }
		end
		ltbl:SetRows(rows)
	end
	ed:SetScript("OnTextChanged", function(_, user) if user and list:IsShown() then p.fillList() end end)
	ed:SetScript("OnEnterPressed", function(self) save(self:GetText()) end)

	return function(full)
		local claim = GS:MyChar().main
		if full and not ed:HasFocus() then ed:SetText(claim or "") end
		claimInfo:SetText(UI.ClaimStatusText())
		local warn = {}
		if not GS:G() then
			warn[#warn + 1] = L["|cffff4040Dieser Charakter ist in keiner Gilde.|r Zuordnung, Twink-Erkennung und Steuererfassung funktionieren erst, wenn er in der Gilde ist – vorher wird nichts gebucht oder synchronisiert."]
		end
		if claim and GS.rosterLoaded and not GS.roster[claim] then
			warn[#warn + 1] = LF("|cffffd100%s ist nicht in deiner Gilde.|r Die Zuordnung wirkt erst, wenn beide in derselben Gilde sind.", claim)
		end
		warn[#warn + 1] = L["|cffaaaaaaAutomatische Erkennung: Twinks werden erst vorgeschlagen, wenn sie in der Gilde sind und einmal mit Addon eingeloggt waren.|r"]
		guildWarn:SetText(table.concat(warn, "\n\n"))
		if list:IsShown() then p.fillList() end
		-- Kirchensteuer-Status
		if GS:G() then
			local main = GS:AccountOf(GS.player)
			local info = GS.roster[main]
			local cur = GS:CurrentWeek()
			local nowOut, nextOut = GS:ChurchLeft(main, cur), GS:ChurchPending(main)
			local liable = info and GS.CHURCH_CLASSES[info.class]
			local txt
			if not liable then
				txt = L["|cffaaaaaaNicht kirchensteuerpflichtig – nur Konten, deren Main Priester oder Paladin ist.|r"]
			elseif nowOut == nextOut then
				txt = nowOut and L["|cff40ff40Ausgetreten|r – dein Konto zahlt keine Kirchensteuer."] or L["Dein Konto zahlt Kirchensteuer (Main ist Priester oder Paladin)."]
			else
				txt = nextOut and L["|cffffd100Austritt erklärt|r – gilt ab der nächsten Steuerwoche."] or L["|cffffd100Wiedereintritt erklärt|r – gilt ab der nächsten Steuerwoche."]
			end
			churchInfo:SetText(txt)
			bChurch:SetText(nextOut and L["Wieder eintreten"] or L["Aus der Kirche austreten"])
			Enable(bChurch, liable and true or false)
		else
			churchInfo:SetText(L["|cffaaaaaaErst in einer Gilde verfügbar.|r"])
			Enable(bChurch, false)
		end
		cLoot:SetChecked(GS.db.lootTaxMsg ~= false)
		cDetail:SetChecked(GS.db.lootTaxDetail and true or false)
		cNotice:SetChecked(GS.db.noticeAuto ~= false)
		cTip:SetChecked(GS.db.tooltipInfo ~= false)
		cRem:SetChecked(GS.db.reminders ~= false)
		cMini:SetChecked(not (GS.db.minimap and GS.db.minimap.hide))
		cNews:SetChecked(not GS.db.newsOff)
		p.cAchToast:SetChecked(not GS.db.achToastOff)
		p.cAchChat:SetChecked(GS:G() and GS:AchChatEnabled() or false)
		Enable(p.cAchChat, GS:G() and GS:CanADM(GS.player, "ACHCHAT", { on = true }) or false)
		cDebug:SetChecked(GS.debug and true or false)
		cDev:SetChecked(GS.db.devVersion and true or false)
		Enable(cDetail, GS.db.lootTaxMsg ~= false)
		for lang, b in pairs(p.langBtns) do
			local fs = b.GetFontString and b:GetFontString()
			if fs then fs:SetTextColor(1, (GS.db.lang or GS:Lang()) == lang and 0.82 or 1, (GS.db.lang or GS:Lang()) == lang and 0 or 1) end
		end
	end
end

---------------------------------------------------------------------------
-- Gilde
---------------------------------------------------------------------------
local STATUS_ORDER = { ["überfällig"] = 1, ["offen"] = 2, ["quitt"] = 3 }

builders.gilde = function(p)
	local hint = Label(p, "", 0, 0, "GameFontNormalSmall")
	local TOP_H = 200
	-- zwei Varianten der Kontenliste: Offiziere sehen zusätzlich das Vermögen
	local function guildCols(officer)
		local cols = {
			{ title = L["Konto"], w = officer and 100 or 110 }, { title = L["Twinks"], w = officer and 90 or 100 },
			{ title = L["Saldo"], w = officer and 90 or 100, j = "RIGHT", tip = L["Einzahlungen und Item-Einlagen minus Entnahmen und festgesetzte Steuern. Ab 0 ist das Konto quitt."] },
			{ title = L["Status"], w = officer and 90 or 100, tip = L["quitt: nichts offen\noffen: Steuer festgesetzt, aber noch im Zahlungsziel\nüberfällig: Zahlungsziel verstrichen"] },
			{ title = officer and L["Steuer l. W."] or L["Steuer letzte W."], w = officer and 80 or 95, j = "RIGHT", tip = L["Festgesetzte Steuer der abgeschlossenen Woche."] },
			{ title = L["Laufende W."], w = officer and 80 or 85, j = "RIGHT", tip = L["Geschätzte Steuer der laufenden Woche – endgültig erst nach dem Reset."] },
		}
		if officer then
			cols[#cols + 1] = { title = L["Vermögen"], w = 95, j = "RIGHT", tip = L["Nur für Offiziere: Gold von Main und Twinks laut zuletzt gemeldetem Stand.\n|cff888888+?|r = mindestens ein Charakter ohne Angabe (nie mit Addon eingeloggt)."] }
		end
		cols[#cols + 1] = { title = L["Addon"], w = officer and 100 or 115, tip = L["Bester Addon-Status über Main und Twinks. „online ohne Addon“ hat als Warnung Vorrang."] }
		cols[#cols + 1] = { title = L["Stand"], w = officer and 70 or 80, tip = L["Wie alt die Daten dieses Kontos bei dir sind.\ngrün: unter 1 Std. · gelb: unter 1 Tag · rot: älter\n„Jetzt aktualisieren“ holt frische Daten."] }
		return cols
	end
	local tblMember = CreateTable(p, 0, -20, PW, TOP_H, guildCols(false))
	local tblOfficer = CreateTable(p, 0, -20, PW, TOP_H, guildCols(true))
	local tbl = tblMember

	-- Detailbereich
	local DY = -(TOP_H + 30)
	local LEFT_W = 330
	-- Details können länger sein als der Platz: scrollbar
	local DW = LEFT_W - 30
	local dsf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
	dsf:SetPoint("TOPLEFT", 0, DY)
	dsf:SetSize(DW, PH + DY)
	UI.relayoutHooks[#UI.relayoutHooks + 1] = function(_, dH) dsf:SetSize(DW, PH + DY + dH) end
	local dchild = CreateFrame("Frame", nil, dsf)
	dchild:SetSize(DW, 1)
	dsf:SetScrollChild(dchild)
	local detail = UI.CreateKV(dchild, DW - 24)
	p.detailKV = detail
	UI.HelpButton(p, DW - 26, DY + 2)
	local function fitDetail()
		dchild:SetHeight(math.max(1, (detail.height or 0) + 4))
	end

	local RX, RW = LEFT_W, PW - LEFT_W
	local mode = "weeks"
	local selectedMain, selectedWeek
	local bWeeks, bBook
	local weekTbl = CreateTable(p, RX, DY - 28, RW, PH + DY - 28, {
		{ title = L["Woche"], w = 78 }, { title = L["Einkünfte"], w = 64, j = "RIGHT" }, { title = L["AH-Gewinn"], w = 64, j = "RIGHT" },
		{ title = L["WK"], w = 58, j = "RIGHT" }, { title = L["ESt+Soli"], w = 62, j = "RIGHT" },
		{ title = L["USt+GewSt"], w = 66, j = "RIGHT" }, { title = L["Steuer"], w = 64, j = "RIGHT" },
	})
	local bookTbl = CreateTable(p, RX, DY - 28, RW, PH + DY - 28, {
		{ title = L["Datum"], w = 82 }, { title = L["Art"], w = 92 }, { title = L["Item / Notiz"], w = 138 },
		{ title = L["Anz."], w = 40, j = "RIGHT" }, { title = L["Betrag"], w = 104, j = "RIGHT" },
	})
	local function setMode(m)
		mode = m
		p.refresh(false)
	end
	bWeeks = Button(p, L["Steuerverlauf"], 116, RX, DY + 2, function() setMode("weeks") end)
	bBook = Button(p, L["Buchungen"], 96, RX + 120, DY + 2, function() setMode("book") end)
	PinR(Button(p, L["Übersicht exportieren"], 160, PW - 160, 4, function() GS:ShowExport(GS:ExportGuildText()) end))
	PinR(Button(p, L["Jetzt aktualisieren"], 150, PW - 316, 4, function()
		local ok, res = GS:ForceSync()
		if ok then
			GS:Print(LF("Aktualisierung angefordert – %s Mitglied(er) mit Addon online. Die Daten kommen in den nächsten Sekunden.", tostring(res)))
		else
			GS:Print(res)
		end
	end))

	-- Offiziere: Erlass und Stundung für die ausgewählte Woche
	local bWaive, bDefer
	local function selectedRes()
		local calc = GS:Calc()
		local a = selectedMain and calc.accounts[selectedMain]
		local w = selectedWeek or calc.week
		return a, w, a and w and a.weeks[w], calc.week
	end
	bWaive = Button(p, L["Erlass"], 90, RX + 220, DY + 2, function()
		local a, w, res = selectedRes()
		if not res or (res.evasion or 0) <= 0 then return end
		UI.Confirm(LF("Hinterziehung erlassen?\n\n%s, %s: %s werden nicht versteuert (z. B. Fehlalarm durch Post an einen Twink).",
			a.main, GS:WeekLabel(w), GS:FormatMoney(res.evasion)), function()
			local ok, err = GS:Waive(a.main, w)
			if not ok then GS:Print(L[err]) end
		end, L["Erlassen"])
	end)
	bDefer = Button(p, L["Stunden (+1 W.)"], 116, RX + 314, DY + 2, function()
		local a, w, res, cur = selectedRes()
		if not res or res.total <= 0 then return end
		local base = math.max(res.deferredUntil or 0, w + (GS:GetLatest("tariff").dueWeeks or 1), cur - 1)
		local untilW = base + 1
		UI.Confirm(LF("Steuer stunden?\n\n%s, %s: %s wird erst am %s fällig.",
			a.main, GS:WeekLabel(w), GS:FormatMoney(res.total), date(L["%d.%m."], GS:WeekStart(untilW + 1))), function()
			local ok, err = GS:Defer(a.main, w, untilW)
			if not ok then GS:Print(L[err]) end
		end, L["Stunden"])
	end)
	local function updateReliefButtons()
		local can = GS:HasRight(GS.player, "relief")
		local a, w, res, cur = selectedRes()
		if can then bWaive:Show(); bDefer:Show() else bWaive:Hide(); bDefer:Hide() end
		Enable(bWaive, can and res and (res.evasion or 0) > 0) -- auch für die laufende Woche
		Enable(bDefer, can and res and res.total > 0 and w < cur)
	end
	local emptyHint = Label(p, L["|cffaaaaaaKonto oben anklicken, um die Details zu sehen.|r"], 0, DY, "GameFontHighlightSmall")

	local function onSelect(row)
		if row then
			selectedMain = row.key
			selectedWeek = nil
			p.refresh(false)
		end
	end
	tblMember.onSelect, tblOfficer.onSelect = onSelect, onSelect
	weekTbl.onSelect = function(row)
		if row then
			selectedWeek = row.week
			p.refresh(false)
		end
	end

	local function renderDetail(calc)
		local a = selectedMain and calc.accounts[selectedMain]
		if not a then
			detail:SetRows({}); fitDetail()
			emptyHint:Show()
			weekTbl:SetRows({})
			bookTbl:SetRows({})
			return
		end
		emptyHint:Hide()
		local cur = calc.week
		local rows = { { h = LF("Konto %s", a.main) } }
		local officer = GS:CanSeeEvasion()
		for _, ch in ipairs(a.chars) do
			local st, col = GS:MemberStatus(ch)
			local gold
			if officer then
				local lg = GS:CharGold(ch)
				gold = lg and Money(lg) or "|cff888888?|r"
			end
			rows[#rows + 1] = { l = ch .. (ch == a.main and L[" |cffaaaaaa(Main)|r"] or ""), v = gold or (col .. L[st] .. "|r"), n = gold and (col .. L[st] .. "|r") or nil }
		end
		if officer then
			local total, unknown, oldest = GS:AccountWealth(a)
			rows[#rows + 1] = { l = L["Vermögen"], v = Money(total) .. (unknown > 0 and " |cff888888+?|r" or ""), n = oldest and LF("Stand: %s", GS:FormatTime(oldest)) or nil }
		end
		rows[#rows + 1] = { l = L["Saldo"], v = SignedMoney(a.bal) }
		rows[#rows + 1] = { l = L["Status"], v = GS:ColorStatus(a.status) }
		rows[#rows + 1] = { l = L["Steuern gesamt"], v = Money(a.taxTotal) }
		do
			local n, total = 0, 0
			for _, s in ipairs(GS:AchievementStates(a.main)) do
				total = total + 1
				if s.done then n = n + 1 end
			end
			rows[#rows + 1] = { l = L["Erfolge"], v = n .. " / " .. total }
		end
		local pay = GS:PaymentLine(a)
		if pay then rows[#rows + 1] = { t = pay } end
		UI.AddInterestRows(rows, a)
		rows[#rows + 1] = { l = L["Datenstand"], v = GS:FormatDataAge(GS:DataAge(a)) }
		rows[#rows + 1] = { sp = true }
		local w = selectedWeek or cur
		for _, r in ipairs(UI.WeekRows(a.weeks[w] or GS:CalcTax(GS:EmptyWeek(), w, nil), w, a.main == GS:AccountOf(GS.player))) do rows[#rows + 1] = r end
		detail:SetRows(rows); fitDetail()

		-- Steuerverlauf (neueste Woche zuerst)
		local weeks = {}
		for wk in pairs(a.weeks) do weeks[#weeks + 1] = wk end
		local hasCur = false
		for _, wk in ipairs(weeks) do if wk == cur then hasCur = true end end
		if not hasCur then weeks[#weeks + 1] = cur end
		table.sort(weeks, function(x, y) return x > y end)
		local rows = {}
		for _, wk in ipairs(weeks) do
			local r = a.weeks[wk] or GS:CalcTax(GS:EmptyWeek(), wk, nil)
			rows[#rows + 1] = {
				(wk == cur and "|cffffd100" or "") .. GS:WeekLabel(wk) .. (wk == cur and "|r" or ""),
				Money(r.base), Money(r.ahNet or r.ah), Money(r.wkEff), Money(r.est + r.soli), Money(r.ust + r.gew),
				(wk >= cur and "~" or "") .. Money(r.total), key = wk, week = wk,
			}
		end
		weekTbl.selectedKey = w
		weekTbl:SetRows(rows)
		bookTbl:SetRows(UI.BookingRows(a))
		updateReliefButtons()
	end

	p.weekTbl, p.bookTbl = weekTbl, bookTbl

	return function()
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		-- Umschaltung Steuerverlauf / Buchungen
		local showWeeks = mode == "weeks"
		weekTbl:SetShown(showWeeks)
		bookTbl:SetShown(not showWeeks)
		if showWeeks then bWeeks:LockHighlight(); bBook:UnlockHighlight() else bBook:LockHighlight(); bWeeks:UnlockHighlight() end
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		local calc = GS:Calc()
		local all = GS:HasRight(GS.player, "viewall")
		local own = GS:AccountOf(GS.player)
		local officer = GS:CanSeeEvasion()
		tbl = officer and tblOfficer or tblMember
		tblOfficer:SetShown(officer)
		tblMember:SetShown(not officer)
		local wealthSum = 0
		local list = {}
		for main, a in pairs(calc.accounts) do
			if all or main == own then list[#list + 1] = a end
		end
		table.sort(list, function(x, y)
			local ox, oy = STATUS_ORDER[x.status] or 9, STATUS_ORDER[y.status] or 9
			if ox ~= oy then return ox < oy end
			return x.main < y.main
		end)
		local rows = {}
		local nq, no, nu = 0, 0, 0
		for _, a in ipairs(list) do
			local twinks = {}
			for _, ch in ipairs(a.chars) do
				if ch ~= a.main then twinks[#twinks + 1] = ch end
			end
			local last = a.weeks[calc.week - 1]
			local st, col = GS:AccountAddonStatus(a)
			local row = {
				a.main, table.concat(twinks, ", "), SignedMoney(a.bal),
				GS:ColorStatus(a.status) .. (((a.evasionTotal or 0) > 0 and officer) and L[" |cffff4040(Hinterz.)|r"] or ""),
				Money(last and last.total or 0), Money(a.cur.total), key = a.main,
			}
			if officer then
				local total, unknown = GS:AccountWealth(a)
				wealthSum = wealthSum + total
				row[#row + 1] = Money(total) .. (unknown > 0 and " |cff888888+?|r" or "")
			end
			row[#row + 1] = col .. L[st] .. "|r"
			row[#row + 1] = GS:FormatDataAge(GS:DataAge(a))
			rows[#rows + 1] = row
			if a.status == "quitt" then nq = nq + 1 elseif a.status == "offen" then no = no + 1 else nu = nu + 1 end
		end
		hint:SetText(LF("%d Konten – |cff40ff40%d quitt|r, |cffffd100%d offen|r, |cffff4040%d überfällig|r%s%s",
			#list, nq, no, nu, all and "" or L["   (Du darfst nur dein eigenes Konto sehen.)"],
			officer and LF("   Vermögen gesamt: %s", Money(wealthSum)) or ""))
		-- Auswahl: nur sichtbare Konten, standardmäßig das eigene
		if not selectedMain or not (all or selectedMain == own) or not calc.accounts[selectedMain] then
			selectedMain = calc.accounts[own] and own or nil
			selectedWeek = nil
		end
		tbl.selectedKey = selectedMain
		tbl:SetRows(rows)
		renderDetail(calc)
	end
end

---------------------------------------------------------------------------
-- Offiziere
---------------------------------------------------------------------------
builders.offi = function(p)
	local denied = Label(p, L["|cffff4040Dein Rang darf die Offiziersliste nicht sehen.|r"], 0, -200, "GameFontNormalLarge")
	denied:SetWidth(PW)
	denied:SetJustifyH("CENTER")
	local body = CreateFrame("Frame", nil, p)
	body:SetAllPoints()
	local views, viewButtons, currentView = {}, {}, "status"
	local refreshers = {}

	local VIEWS = {
		{ key = "status", title = "Addon-Status" },
		{ key = "flags", title = "Auffälligkeiten" },
		{ key = "values", title = "Ungeprüfte Werte" },
		{ key = "twinks", title = "Twinks" },
		{ key = "corr", title = "Korrekturen" },
		{ key = "posten", title = "Steuerposten" },
		{ key = "prices", title = "AH-Preise" },
	}

	local function show(key)
		currentView = key
		for k, v in pairs(views) do
			if k == key then v:Show() else v:Hide() end
		end
		for _, b in ipairs(viewButtons) do
			if b.key == key then b:LockHighlight() else b:UnlockHighlight() end
		end
		if refreshers[key] then UI.SafeCall("Offiziere/" .. key, refreshers[key]) end
	end
	p.showView = show
	p.views = views

	for i, v in ipairs(VIEWS) do
		local b = Button(body, L[v.title], 112, (i - 1) * 115, 0, function() show(v.key) end)
		b.key = v.key
		viewButtons[i] = b
		local f = CreateFrame("Frame", nil, body)
		f:SetPoint("TOPLEFT", 0, -30)
		f:SetSize(PW, PH - 30)
		f.baseW, f.baseH = PW, PH - 30
		UI.stretchFrames[#UI.stretchFrames + 1] = { frame = f, w = PW, h = PH - 30 }
		f:Hide()
		views[v.key] = f
	end
	local VH = PH - 30

	-- Addon-Status
	do
		local f = views.status
		local tbl = CreateTable(f, 0, 0, PW, VH, {
			{ title = L["Name"], w = 110 }, { title = L["Rang"], w = 100 }, { title = L["Status"], w = 150 },
			{ title = L["Version"], w = 70 }, { title = L["Zuletzt gesehen"], w = 110 }, { title = L["Main (beansprucht)"], w = 120 },
			{ title = L["Konto"], w = 120 },
		})
		refreshers.status = function()
			local g = GS:G()
			local names = {}
			for n in pairs(GS.roster) do names[n] = true end
			for n in pairs(g.status) do names[n] = true end
			local list = {}
			for n in pairs(names) do list[#list + 1] = n end
			local order = { ["online ohne Addon"] = 1, ["veraltet"] = 2, ["veraltet (Version)"] = 2, ["aktiv (alte Version)"] = 3, ["nie gesehen"] = 4, ["offline"] = 5, ["aktiv"] = 6 }
			local stc = {}
			for _, n in ipairs(list) do stc[n] = { GS:MemberStatus(n) } end
			table.sort(list, function(a, b)
				local oa, ob = order[stc[a][1]] or 9, order[stc[b][1]] or 9
				if oa ~= ob then return oa < ob end
				return a < b
			end)
			local rows = {}
			for _, n in ipairs(list) do
				local st = g.status[n] or {}
				local r = GS.roster[n] or {}
				rows[#rows + 1] = {
					n, r.rank or L["|cffaaaaaa(nicht in Gilde)|r"], stc[n][2] .. L[stc[n][1]] .. "|r", UI.VersionText(n, st),
					st.hb and GS:FormatAgo(st.hb) or L["nie"], st.m or "", GS:AccountOf(n), key = n,
				}
			end
			tbl:SetRows(rows)
		end
	end

	-- Auffälligkeiten
	do
		local f = views.flags
		local tbl = CreateTable(f, 0, 0, PW, VH - 60, {
			{ title = L["Zeit"], w = 90 }, { title = L["Spieler"], w = 110 }, { title = L["Art"], w = 150 }, { title = L["Details"], w = 430 },
		})
		PinB(Label(f, L["Begründung für den Spieler (Einspruch):"], 0, -(VH - 52), "GameFontNormalSmall"))
		local edReason = PinB(Edit(f, 500, 250, -(VH - 56)))
		f.edReason = edReason
		PinB(Button(f, L["Liste leeren (nur lokal)"], 180, 0, -(VH - 24), function()
			wipe(GS:G().flags)
			refreshers.flags()
		end))
		local function resolveSelected(decision)
			local sel = tbl:Selected()
			if not sel or not sel.objId then GS:Print(L["Bitte einen Einspruch auswählen."]) return end
			local ok, err = GS:ResolveObjection(sel.objId, decision, edReason:GetText())
			if ok then
				GS:Print(decision == "angenommen" and L["Einspruch angenommen – der Spieler bekommt die Begründung angezeigt."]
					or L["Einspruch abgelehnt – der Spieler bekommt die Begründung angezeigt."])
				edReason:SetText("")
			else
				GS:Print(err)
			end
		end
		local bAccept = PinB(Button(f, L["Einspruch annehmen"], 150, 190, -(VH - 24), function() resolveSelected("angenommen") end))
		local bReject = PinB(Button(f, L["Einspruch ablehnen"], 150, 346, -(VH - 24), function() resolveSelected("abgelehnt") end))
		PinB(Label(f, L["Angenommen: Korrektur, Erlass oder Stundung bitte zusätzlich buchen."], 504, -(VH - 20), "GameFontDisableSmall")):SetWidth(PW - 504)
		refreshers.flags = function()
			local g = GS:G()
			local rows = {}
			local cur = GS:CurrentWeek()
			-- online gesehen, aber weder Bericht noch Heartbeat in der Woche
			for name, weeks in pairs(g.online) do
				for _, w in ipairs({ cur - 1, cur }) do
					if weeks[w] then
						local rep = g.reports[name]
						local st = g.status[name]
						local hasData = (rep and rep.w[w]) or (st and st.aw and st.aw[w])
						if not hasData then
							rows[#rows + 1] = { GS:WeekLabel(w), name, L["|cffff4040Keine Daten|r"], L["War online, hat aber keine Addon-Daten geliefert"], key = "o" .. name .. w }
						end
					end
				end
			end
			-- offene Einsprüche
			local canRelief = GS:HasRight(GS.player, "relief")
			Enable(bAccept, canRelief); Enable(bReject, canRelief)
			for _, a in pairs(GS:Calc().accounts) do
				for _, o in ipairs(a.objections or {}) do
					if not o.resolved then
						rows[#rows + 1] = { GS:WeekLabel(o.week), o.author, L["|cffffd100Einspruch|r"], LF("„%s“ (Konto %s)", o.text, a.main),
							key = "obj" .. o.id, objId = o.id }
					end
				end
			end
			-- Steuerhinterziehung: Gold eingenommen, während das Addon nicht lief
			local relief = GS:ReliefIndex()
			for name, rep in pairs(g.reports) do
				local rel = relief[GS:AccountOf(name)]
				for w, d in pairs(rep.w or {}) do
					local x = tonumber(d.x) or 0
					local waived = rel and rel.waive and rel.waive[w]
					if x > 0 and not waived then
						rows[#rows + 1] = {
							GS:WeekLabel(w), GS:ResolveName(name), L["|cffff4040Steuerhinterziehung|r"],
							LF("%s Gold eingenommen, während das Addon nicht aktiv war (wird nachversteuert)", GS:FormatMoney(x)),
							key = "x" .. name .. w,
						}
					end
				end
			end
			-- unbestätigte Twink-Ansprüche
			local links = GS:Links()
			for name, st in pairs(g.status) do
				if st.m and links[name] ~= st.m then
					rows[#rows + 1] = { "-", name, L["|cffffd100Twink unbestätigt|r"], LF("Beansprucht Main %s", st.m), key = "t" .. name }
				end
			end
			for i = #g.flags, 1, -1 do
				local fl = g.flags[i]
				rows[#rows + 1] = { GS:FormatTime(fl.time), L[fl.char], "|cffff8040" .. L[fl.kind] .. "|r", L[fl.text or ""], key = fl.key }
			end
			tbl:SetRows(rows)
		end
	end

	-- Ungeprüfte Werte
	do
		local f = views.values
		local tbl = CreateTable(f, 0, 0, PW, VH - 34, {
			{ title = L["Datum"], w = 90 }, { title = L["Spieler"], w = 100 }, { title = L["Art"], w = 95 }, { title = L["Item"], w = 170 },
			{ title = L["Menge"], w = 50, j = "RIGHT" }, { title = L["Wert"], w = 100, j = "RIGHT" }, { title = L["Quelle"], w = 170 },
		})
		PinB(Label(f, L["Gesamtwert:"], 0, -(VH - 26), "GameFontNormalSmall"))
		local ed = PinB(Edit(f, 110, 75, -(VH - 30)))
		local btn = PinB(Button(f, L["Wert festsetzen"], 130, 200, -(VH - 31), function()
			local sel = tbl:Selected()
			local v = GS:ParseMoney(ed:GetText())
			if not sel or not v or v < 0 then GS:Print(L["Bitte Eintrag auswählen und Wert eingeben (z. B. 1g 20s)."]) return end
			local ok, err = GS:SetEntryValue(sel.entry, v)
			if not ok then GS:Print(L[err]) end
			ed:SetText("")
		end))
		PinB(Label(f, L["Format: 1g 20s 5k"], 340, -(VH - 26), "GameFontDisableSmall"))
		tbl.onSelect = function(row) if row then ed:SetText(GS:FormatMoney(row.value, true)) end end
		refreshers.values = function()
			local g = GS:G()
			Enable(btn, GS:HasRight(GS.player, "values"))
			local ov = GS:ValueOverrides()
			local list = {}
			for _, e in ipairs(g.bank) do
				if e.i > 0 then
					local v, src = GS:EntryValue(e, ov)
					if GS:IsUnverified(src) then list[#list + 1] = { e = e, v = v, src = src } end
				end
			end
			table.sort(list, function(a, b) return a.e.t > b.e.t end)
			local rows = {}
			for _, x in ipairs(list) do
				local e = x.e
				rows[#rows + 1] = {
					GS:FormatTime(e.t), L[e.c], L[KIND_LABEL[e.y]], GS:ItemLabel(e.i), e.n, Money(x.v), L[GS.SOURCE_LABEL[x.src] or x.src],
					key = GS.BankKey(e) .. e.t, entry = e, value = x.v, itemID = e.i,
				}
			end
			tbl:SetRows(rows)
		end
	end

	-- Twinks
	do
		local f = views.twinks
		local tbl = CreateTable(f, 0, 0, PW, VH - 64, {
			{ title = L["Charakter"], w = 140 }, { title = L["Beansprucht Main"], w = 140 }, { title = L["Bestätigter Main"], w = 140 }, { title = L["Status"], w = 300 },
		})
		local bConfirm = PinB(Button(f, L["Anspruch bestätigen"], 150, 0, -(VH - 58), function()
			local sel = tbl:Selected()
			if not sel or not sel.claim then GS:Print(L["Bitte einen Charakter mit Anspruch auswählen."]) return end
			if GS:AccountOf(sel.claim) == GS:AccountOf(sel.char) then
				GS:Print(LF("%s gehört schon zum Konto %s – der Anspruch ist veraltet und passt sich von selbst an.", sel.char, GS:AccountOf(sel.char)))
				return
			end
			local ok, err = GS:CreateADM("LINK", { c = sel.char, m = sel.claim })
			if not ok then GS:Print(L[err]) end
		end))
		local bUnlink = PinB(Button(f, L["Zuordnung lösen"], 150, 156, -(VH - 58), function()
			local sel = tbl:Selected()
			if not sel then return end
			local ok, err = GS:CreateADM("UNLINK", { c = sel.char })
			if not ok then GS:Print(L[err]) end
		end))
		-- Main-Wechsel: der ausgewählte Twink wird Main, der bisherige Main und alle Twinks hängen dann an ihm
		local bSwitch = PinB(Button(f, L["Zum Main machen"], 150, 312, -(VH - 58), function()
			local sel = tbl:Selected()
			if not sel then GS:Print(L["Bitte den Twink auswählen, der Main werden soll."]) return end
			local old = GS:AccountOf(sel.char)
			if old == sel.char then GS:Print(LF("%s ist bereits Main seines Kontos.", sel.char)) return end
			UI.Confirm(LF("Main wechseln?\n\n%s wird Main des Kontos %s.\n%s und alle anderen Twinks werden %s zugeordnet.\n\nSaldo, Steuern und Verlauf bleiben im Konto.",
				sel.char, old, old, sel.char), function()
				local ok, res, others = GS:SwitchMain(sel.char)
				if ok then
					if #others > 0 then
						GS:Print(LF("%s ist jetzt Main (bisher %s, Twinks: %s).", sel.char, tostring(res), table.concat(others, ", ")))
					else
						GS:Print(LF("%s ist jetzt Main (bisher %s).", sel.char, tostring(res)))
					end
				else
					GS:Print(L[res])
				end
			end, L["Main wechseln"])
		end))
		UI.AttachTip(bSwitch, L["Zum Main machen"], L["Für Spieler, die ihren Hauptcharakter wechseln: Der ausgewählte Twink wird Main, der bisherige Main wird sein Twink. Das Konto mit Saldo und Steuern bleibt erhalten."])
		PinB(Label(f, L["Manuell – Twink:"], 0, -(VH - 26), "GameFontNormalSmall"))
		local edT = PinB(Edit(f, 110, 100, -(VH - 30)))
		PinB(Label(f, L["Main:"], 225, -(VH - 26), "GameFontNormalSmall"))
		local edM = PinB(Edit(f, 110, 260, -(VH - 30)))
		local bManual = PinB(Button(f, L["Zuordnen"], 100, 385, -(VH - 31), function()
			local t, m = GS:ResolveName(UI.Trim(edT:GetText())), GS:ResolveName(UI.Trim(edM:GetText()))
			if t == "" or m == "" or t == m then return end
			local ok, err = GS:CreateADM("LINK", { c = t, m = m })
			if not ok then GS:Print(L[err]) else edT:SetText(""); edM:SetText("") end
		end))
		refreshers.twinks = function()
			local g = GS:G()
			local can = GS:HasRight(GS.player, "twinks")
			Enable(bConfirm, can); Enable(bUnlink, can); Enable(bManual, can); Enable(bSwitch, can)
			local links = GS:Links()
			local names = {}
			for n, st in pairs(g.status) do if st.m then names[n] = true end end
			for n in pairs(links) do names[n] = true end
			local list = {}
			for n in pairs(names) do list[#list + 1] = n end
			table.sort(list)
			local rows = {}
			for _, n in ipairs(list) do
				local st = g.status[n] or {}
				local claim, conf = st.m, links[n]
				local status
				if claim and conf == claim then status = L["|cff40ff40bestätigt|r"]
				elseif claim and GS:AccountOf(claim) == GS:AccountOf(n) then
					-- z. B. nach einem Main-Wechsel: Anspruch zeigt noch auf den alten Main, gleiches Konto
					status = L["|cff40ff40bestätigt|r |cffaaaaaa(Anspruch veraltet, passt sich an)|r"]
					if not conf then status = status .. L[" |cffffd100· Main|r"] end
				elseif claim and conf then status = L["|cffffd100Anspruch weicht von Bestätigung ab|r"]
				elseif claim then status = L["|cffffd100wartet auf Bestätigung|r"]
				else status = L["bestätigt (ohne Anspruch im Addon)"] end
				-- vom Addon erkannt: Twink und Main senden dieselbe Account-Kennung
				local mainSt = g.status[claim or conf or ""]
				if st.ak and mainSt and mainSt.ak == st.ak then
					status = status .. L[" |cff40ff40· gleicher WoW-Account|r"]
				end
				rows[#rows + 1] = { n, claim or "-", conf or "-", status, key = n, char = n, claim = claim }
			end
			tbl:SetRows(rows)
		end
	end

	-- Korrekturen
	do
		local f = views.corr
		Label(f, L["Konto (Main):"], 0, 0, "GameFontNormalSmall")
		local edA = Edit(f, 120, 0, -16)
		Label(f, L["Betrag (+ gut / - belasten):"], 140, 0, "GameFontNormalSmall"):SetWidth(195)
		local edV = Edit(f, 120, 140, -16)
		Label(f, L["Notiz:"], 340, 0, "GameFontNormalSmall")
		local edN = Edit(f, 250, 340, -16)
		local bBook = Button(f, L["Buchen"], 100, 610, -15, function()
			local a = UI.Trim(edA:GetText())
			local v = GS:ParseMoney(edV:GetText())
			if a == "" or not v or v == 0 then GS:Print(L["Bitte Konto und Betrag angeben (z. B. -50s oder 1g)."]) return end
			local ok, err = GS:CreateADM("CORR", { a = GS:AccountOf(a), v = v, n = edN:GetText() })
			if not ok then GS:Print(L[err]) else edA:SetText(""); edV:SetText(""); edN:SetText("") end
		end)
		local tbl = CreateTable(f, 0, -50, PW, VH - 50, {
			{ title = L["Zeit"], w = 100 }, { title = L["Konto"], w = 120 }, { title = L["Betrag"], w = 110, j = "RIGHT" },
			{ title = L["Notiz"], w = 330 }, { title = L["Autor"], w = 120 },
		})
		refreshers.corr = function()
			Enable(bBook, GS:HasRight(GS.player, "corr"))
			local rows = {}
			local list = GS:SortedADM("CORR")
			for i = #list, 1, -1 do
				local x = list[i]
				rows[#rows + 1] = { GS:FormatTime(x.tm), x.d.a, SignedMoney(tonumber(x.d.v) or 0), x.d.n or "", x.au, key = x.id }
			end
			tbl:SetRows(rows)
		end
	end

	-- Steuerposten: einzelne Posten eines Kontos in einer Woche korrigieren (z. B. doppelt erfasster Wareneinsatz)
	do
		local f = views.posten
		local week
		Label(f, L["Konto (Main oder Twink):"], 0, 0, "GameFontNormalSmall")
		local edA = Edit(f, 130, 0, -16)
		-- Auswahlliste aller Konten (Main mit Twinks)
		local bPick = UI.AttachPicker(f, edA, 142, -15, 360, function()
			local out = {}
			for main, a in pairs(GS:Calc().accounts) do
				local tw = {}
				for _, ch in ipairs(a.chars) do if ch ~= main then tw[#tw + 1] = ch end end
				out[#out + 1] = { name = main, hint = #tw > 0 and LF("Twinks: %s", table.concat(tw, ", ")) or "" }
			end
			table.sort(out, function(x, y) return x.name < y.name end)
			return out
		end, function() f.refresh() end, 50)
		f.bPick = bPick
		local weekLabel = Label(f, "", 266, -20, "GameFontHighlight")
		Button(f, "<", 26, 200, -15, function() week = (week or GS:CurrentWeek()) - 1; f.refresh() end)
		Button(f, ">", 26, 230, -15, function() week = math.min(GS:CurrentWeek(), (week or GS:CurrentWeek()) + 1); f.refresh() end)
		local bShow = Button(f, L["Anzeigen"], 90, 420, -15, function() f.refresh() end)
		edA:SetScript("OnEnterPressed", function(self) self:ClearFocus(); f.refresh() end)
		local info = Label(f, L["|cffaaaaaaÄnderungen wirken auf Steuer, AH-Gewinn und Verlustvortrag dieser und aller Folgewochen.|r"], 520, -12, "GameFontHighlightSmall")
		info:SetWidth(PW - 520)
		local tbl = CreateTable(f, 0, -50, PW, VH - 50 - 64, {
			{ title = L["Posten"], w = 330 }, { title = L["Anz."], w = 50, j = "RIGHT" }, { title = L["Erfasst"], w = 120, j = "RIGHT" },
			{ title = L["Korrektur"], w = 120, j = "RIGHT" }, { title = L["Gilt"], w = 120, j = "RIGHT" },
		})
		PinB(Label(f, L["Ausgewählter Posten – richtiger Betrag:"], 0, -(VH - 56), "GameFontNormalSmall"))
		local edV = PinB(Edit(f, 110, 0, -(VH - 40)))
		PinB(Label(f, L["Notiz:"], 130, -(VH - 36), "GameFontNormalSmall"))
		local edN = PinB(Edit(f, 230, 170, -(VH - 40)))
		local function selected()
			local sel = tbl:Selected()
			return sel and sel.pos
		end
		local function book(delta, note)
			local main = GS:AccountOf(GS:ResolveName(UI.Trim(edA:GetText())))
			local pos = selected()
			if not pos or not week then return end
			local ok, err = GS:CreateADM("TCORR", { a = main, w = week, f = pos.f, id = pos.id, v = delta, n = note })
			if ok then
				GS:Print(LF("Steuerposten korrigiert: %s, %s, %s %s.", main, GS:WeekLabel(week), L[pos.label], GS:FormatMoney(delta)))
				edV:SetText(""); edN:SetText("")
			else
				GS:Print(L[err])
			end
		end
		local bFix = PinB(Button(f, L["Korrigieren"], 110, 420, -(VH - 41), function()
			local pos = selected()
			if not pos then GS:Print(L["Bitte zuerst einen Posten in der Liste auswählen."]) return end
			local v = GS:ParseMoney(edV:GetText())
			if not v or v < 0 then GS:Print(L["Bitte den richtigen Betrag angeben (z. B. 2g 26s 10k, 0 zum Streichen)."]) return end
			local delta = v - pos.cur
			if delta == 0 then GS:Print(L["Der Betrag stimmt schon."]) return end
			UI.Confirm(LF("Steuerposten korrigieren?\n\n%s\nvon %s auf %s\n\nDie Steuer dieses Kontos wird ab dieser Woche neu berechnet.",
				L[pos.label], GS:FormatMoney(pos.cur), GS:FormatMoney(v)), function()
				book(delta, UI.Trim(edN:GetText()))
			end, L["Korrigieren"])
		end))
		local bUndo = PinB(Button(f, L["Korrektur zurücknehmen"], 170, 536, -(VH - 41), function()
			local pos = selected()
			if not pos or (pos.corr or 0) == 0 then GS:Print(L["Dieser Posten hat keine Korrektur."]) return end
			book(-pos.corr, "Korrektur zurückgenommen")
		end))
		tbl.onSelect = function(row)
			if row and row.pos then
				local c = math.floor(row.pos.cur)
				edV:SetText(string.format(L["%dg %ds %dk"], math.floor(c / 10000), math.floor(c / 100) % 100, c % 100))
			end
		end
		f.edA, f.tbl, f.edV, f.edN, f.bFix, f.bUndo = edA, tbl, edV, edN, bFix, bUndo
		f.setWeek = function(w) week = w end
		f.refresh = function()
			week = week or GS:CurrentWeek()
			weekLabel:SetText(GS:WeekLabel(week) .. (week == GS:CurrentWeek() and L[" |cffaaaaaa(laufend)|r"] or ""))
			local can = GS:HasRight(GS.player, "corr")
			Enable(bFix, can); Enable(bUndo, can)
			local name = UI.Trim(edA:GetText())
			if name == "" then
				tbl:SetRows({ { L["|cffaaaaaaKonto eingeben und „Anzeigen“ klicken (oder Enter).|r"], "", "", "", "", key = 0 } })
				return
			end
			local main = GS:AccountOf(GS:ResolveName(name))
			local rows = {}
			for i, pos in ipairs(GS:TaxPositions(main, week)) do
				rows[#rows + 1] = {
					L[pos.label], pos.count or "", Money(pos.raw),
					pos.corr ~= 0 and SignedMoney(pos.corr) or "", Money(pos.cur), key = i, pos = pos, itemID = pos.id,
				}
			end
			if #rows == 0 then rows[1] = { LF("|cffaaaaaaKeine Posten für %s in dieser Woche.|r", main), "", "", "", "", key = 0 } end
			tbl:SetRows(rows)
		end
		refreshers.posten = function() f.refresh() end
	end

	-- AH-Preise
	do
		local f = views.prices
		local bScan = Button(f, L["AH komplett scannen"], 170, 0, 0, function()
			local ok, err = GS:StartScan()
			if ok then GS:Print(L["AH-Scan gestartet ..."]) else GS:Print(L[err]) end
		end)
		local bSend = Button(f, L["Preise an Gilde verteilen"], 190, 176, 0, function()
			local ok, res = GS:BroadcastPrices()
			if ok then GS:Print(LF("%s Preise an die Gilde gesendet.", tostring(res))) else GS:Print(L[res]) end
		end)
		local info = Label(f, "", 380, -4, "GameFontHighlightSmall")
		local tbl = CreateTable(f, 0, -32, PW, VH - 32, {
			{ title = L["Item"], w = 220 }, { title = L["Scan-Preis"], w = 110, j = "RIGHT" }, { title = L["Alter"], w = 100 },
			{ title = L["Auctionator"], w = 110, j = "RIGHT" }, { title = L["Händler"], w = 100, j = "RIGHT" },
		})
		refreshers.prices = function()
			local g = GS:G()
			Enable(bSend, GS:HasRight(GS.player, "prices"))
			local total = 0
			for _ in pairs(g.prices) do total = total + 1 end
			info:SetText(LF("%d Scan-Preise gespeichert", total) .. (GS:AuctionatorPrice(2589) ~= nil and L[", Auctionator aktiv"] or (Auctionator and L[", Auctionator geladen"] or L[", Auctionator nicht gefunden"])))
			local ids = {}
			for _, e in ipairs(g.bank) do if e.i > 0 then ids[e.i] = true end end
			for id in pairs(GS:GetLatest("wklist").items or {}) do ids[id] = true end
			local list = {}
			for id in pairs(ids) do list[#list + 1] = id end
			local names = nameSnapshot(list)
			table.sort(list, function(a, b)
				if names[a] ~= names[b] then return names[a] < names[b] end
				return a < b
			end)
			local rows = {}
			for _, id in ipairs(list) do
				local e = g.prices[id]
				local auc = GS:AuctionatorPrice(id)
				local vend = GS:VendorPrice(id)
				rows[#rows + 1] = {
					GS:ItemLabel(id), e and Money(e.p) or "-", e and GS:FormatAgo(e.t) or "-",
					auc and Money(auc) or "-", vend and Money(vend) or "-", key = id, itemID = id,
				}
			end
			tbl:SetRows(rows)
		end
	end

	return function()
		if not GS:G() then body:Hide(); denied:Hide(); noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		if not GS.rosterLoaded then GS:RequestRoster() end
		if not GS:HasRight(GS.player, "officer") then
			body:Hide()
			denied:SetText(GS.rosterLoaded
				and L["|cffff4040Dein Rang darf die Offiziersliste nicht sehen.|r\n|cffaaaaaa(/gst info zeigt die erkannten Ränge)|r"]
				or L["|cffffd100Gildenroster wird geladen ...|r"])
			denied:Show()
			return
		end
		denied:Hide()
		body:Show()
		show(currentView)
	end
end

---------------------------------------------------------------------------
-- Tarif
---------------------------------------------------------------------------
local TARIFF_FIELDS = {
	{ key = "soli", label = "Solidaritätszuschlag (% auf ESt)", kind = "pct", tip = "Zuschlag auf die Einkommensteuer, z. B. 5,5 %." },
	{ key = "ust", label = "Umsatzsteuer auf AH-Erlöse (%)", kind = "pct", tip = "Steuer auf den AH-Gewinn (Verkaufserlös minus verlorene Anzahlungen minus Wareneinsatz)." },
	{ key = "gew", label = "Gewerbesteuer auf AH-Erlöse (%)", kind = "pct", tip = "Zusätzliche Steuer für Vielverkäufer: gilt nur für den AH-Gewinn über dem Freibetrag." },
	{ key = "gewFree", label = "Gewerbesteuer-Freibetrag pro Woche", kind = "money", tip = "AH-Gewinn bis zu diesem Betrag pro Woche ist frei von Gewerbesteuer." },
	{ key = "pausch", label = "Werbungskosten-Pauschbetrag pro Woche", kind = "money", tip = "Dieser Betrag wird jede Woche als Werbungskosten abgezogen – auch ohne Käufe. Höhere echte Kosten ersetzen ihn." },
	{ key = "minTax", label = "Kleinbetragsgrenze (darunter keine Steuer)", kind = "money", tip = "Liegt die Wochensteuer darunter, entfällt sie ganz. 0 = aus (empfohlen, sonst springt die Steuer)." },
	{ key = "dueWeeks", label = "Zahlungsziel (Wochen nach Abrechnung)", kind = "int", min = 1, max = 8, tip = "Wie viele Wochen nach Ende der Steuerwoche gezahlt werden muss, bevor ein Konto „überfällig“ ist." },
	{ key = "resetDay", label = "Reset-Wochentag (1 = Mo bis 7 = So)", kind = "int", min = 1, max = 7, tip = "Wochentag des Server-Resets. Die Steuerwoche endet dort." },
	{ key = "resetHour", label = "Reset-Uhrzeit (Stunde, UTC)", kind = "int", min = 0, max = 23, tip = "Uhrzeit des Resets in UTC (Winterzeit: deutsche Uhrzeit minus 1 Std.)." },
	{ key = "activeMin", label = "Addon gilt als aktiv bis (Minuten ohne Signal)", kind = "int", min = 2, max = 60, tip = "So lange ohne Heartbeat gilt ein Mitglied noch als „aktiv“." },
	{ key = "staleDays", label = "Veraltet nach (Tagen ohne Signal)", kind = "int", min = 1, max = 90, tip = "So lange ohne Signal, bis ein Mitglied als „veraltet“ gilt." },
	{ key = "evasionPenalty", label = "Hinterziehungszuschlag (% auf Gold ohne Addon)", kind = "pct", tip = "Aufschlag auf Gold, das ohne aktives Addon eingenommen wurde (zusätzlich zur Nachversteuerung)." },
	{ key = "dogTax", label = "Hundesteuer pro Woche (Jäger/Hexer)", kind = "money", tip = "Fester Betrag pro Woche für jeden Jäger und Hexenmeister, der in der Woche gespielt hat. 0 = aus." },
	{ key = "dogTaxLevel", label = "Hundesteuer ab Level", kind = "int", min = 1, max = 100, tip = "Charaktere darunter zahlen keine Hundesteuer (Jäger bekommen ihr Tier mit Level 10)." },
	{ key = "churchTax", label = "Kirchensteuer (% auf ESt, Main Priester/Paladin)", kind = "pct", tip = "Zuschlag auf die Einkommensteuer für Konten, deren Main Priester oder Paladin ist. 0 = aus." },
	{ key = "alcTax", label = "Alkoholsteuer (% auf Getränke-Einkauf)", kind = "pct", tip = "Anteil des Kaufpreises alkoholischer Getränke (Händler und AH). 0 = aus." },
	{ key = "mountTax", label = "Reittiersteuer pro Woche und Charakter", kind = "money", tip = "Fester Betrag pro Woche für jeden Charakter, der Reiten gelernt und in der Woche gespielt hat. 0 = aus." },
	{ key = "exemptLevel", label = "Steuerfrei unter Level (0 = aus)", kind = "int", min = 0, max = 100, tip = "Charaktere unter diesem Level zahlen keine Steuer; ihre Einnahmen zählen nicht. 0 = aus." },
	{ key = "exemptWeeks", label = "Neulinge steuerfrei (Wochen, 0 = aus)", kind = "int", min = 0, max = 12, tip = "Wer erst nach Einführung des Addons in die Gilde kam, ist so viele Wochen steuerfrei. 0 = aus." },
	{ head = "Verzugszinsen (nur in aktiven Spielwochen)" },
	{ key = "interestRate", label = "Zinssatz pro aktiver Spielwoche", kind = "pct", tip = "Zinsen auf überfällige Steuer – nur für Wochen, in denen das Konto aktiv gespielt hat. Keine Zinseszinsen. 0 = aus." },
	{ key = "interestMinDays", label = "Aktive Woche ab Online-Tagen", kind = "int", min = 0, max = 7, tip = "An so vielen verschiedenen Tagen muss das Konto (irgendein Charakter) in der Woche online gewesen sein. 0 = egal." },
	{ key = "interestMinMinutes", label = "Aktive Woche ab Spielzeit (Minuten)", kind = "int", min = 0, max = 10080, tip = "So viele Minuten Spielzeit muss das Konto in der Woche haben. 0 = egal. Sind beide Grenzen 0, zählt jede Woche." },
	{ key = "interestGrace", label = "Zinsfreie aktive Wochen (Schonfrist)", kind = "int", min = 0, max = 12, tip = "So viele aktive Spielwochen nach Fälligkeit bleiben zinsfrei. 0 = Zinsen ab der ersten aktiven Woche." },
	{ key = "interestMin", label = "Bagatellgrenze (darunter keine Zinsen)", kind = "money", tip = "Überfällige Steuer unter diesem Betrag wird nicht verzinst." },
	{ key = "interestCap", label = "Höchstens (% des Rückstands insgesamt)", kind = "pct", tip = "Deckel: Zinsen insgesamt höchstens dieser Anteil des Rückstands. 0 = kein Deckel." },
}
local NZONES = 6

local function fmtField(kind, v)
	if kind == "pct" then return GS:FormatPercent(v) end
	if kind == "money" then return GS:FormatMoney(v, true) end
	return tostring(v or "")
end

builders.tarif = function(p)
	local info = Label(p, "", 0, 0, "GameFontHighlightSmall")
	info:SetWidth(PW)
	local function dirty() p.dirty = true end

	local zoneTitle = Label(p, L["Einkommensteuer-Zonen (pro Woche)"], 0, -40, "GameFontNormal")
	zoneTitle:SetWidth(310)
	if zoneTitle.SetWordWrap then zoneTitle:SetWordWrap(false) end
	local zoneEds = {}
	for i = 1, NZONES do
		local y = -64 - (i - 1) * 26
		Label(p, LF("Zone %d:  ab", i), 0, y - 4, "GameFontHighlightSmall")
		local from = Edit(p, 100, 84, y, dirty)
		Label(p, L["Satz %"], 199, y - 4, "GameFontHighlightSmall")
		local rate = Edit(p, 50, 244, y, dirty)
		zoneEds[i] = { from = from, rate = rate }
	end
	local zoneHint = Label(p, L["Grenzsteuersätze: Jeder Satz gilt nur für den Betrag innerhalb seiner Zone. Leere Zeilen werden ignoriert, die erste Zone (ab 0) ist der Grundfreibetrag."], 0, -64 - NZONES * 26, "GameFontDisableSmall")
	zoneHint:SetWidth(310)

	Label(p, L["Steuerfaktor je Rang (%)"], 0, -268, "GameFontNormal")
	local rankEds, rankLbls = {}, {}
	for r = 0, 9 do
		local col, row = r % 5, math.floor(r / 5)
		local x, y = col * 62, -288 - row * 26
		local l = Label(p, "", x, y - 4, "GameFontHighlightSmall")
		l:SetWidth(32)
		if l.SetWordWrap then l:SetWordWrap(false) end
		rankLbls[r] = l
		rankEds[r] = Edit(p, 24, x + 26, y, dirty)
	end

	-- Einstellungen rechts in einem Scrollbereich (die Liste ist länger als das Fenster)
	local FX, FY, FW = 326, -36, 462
	local FH = PH - 52 - 8 + FY -- bis über die Haken-/Knopfzeile
	local fsf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
	fsf:SetPoint("TOPLEFT", FX, FY)
	fsf:SetSize(FW, FH)
	local fch = CreateFrame("Frame", nil, fsf)
	fch:SetSize(FW, #TARIFF_FIELDS * 21 + 8)
	fsf:SetScrollChild(fch)
	UI.relayoutHooks[#UI.relayoutHooks + 1] = function(_, dH) fsf:SetSize(FW, FH + dH) end
	local fieldEds = {}
	for i, fdef in ipairs(TARIFF_FIELDS) do
		local y = -4 - (i - 1) * 21
		if fdef.head then
			Label(fch, L[fdef.head], 4, y - 6, "GameFontNormal")
		else
			Label(fch, L[fdef.label], 4, y - 4, "GameFontHighlightSmall")
			if fdef.tip then UI.TipZone(fch, 4, y, 300, 20, L[fdef.label], L[fdef.tip]) end
			fieldEds[fdef.key] = Edit(fch, 110, 314, y, dirty)
		end
	end

	local bSave, presetButtons = nil, {}
	local function load()
		local T = GS:GetLatest("tariff")
		for i = 1, NZONES do
			local z = T.zones[i]
			zoneEds[i].from:SetText(z and GS:FormatMoney(z[1], true) or "")
			zoneEds[i].rate:SetText(z and GS:FormatPercent(z[2]) or "")
		end
		for _, fdef in ipairs(TARIFF_FIELDS) do if not fdef.head then
			local v = T[fdef.key]
			if v == nil then v = GS.DEFAULTS.tariff[fdef.key] end -- neue Einstellung, im gespeicherten Tarif noch nicht vorhanden
			fieldEds[fdef.key]:SetText(fmtField(fdef.kind, v))
		end end
		local n = (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 0
		for r = 0, 9 do
			local shown = r < n
			local name = shown and GuildControlGetRankName and GuildControlGetRankName(r + 1) or ""
			rankLbls[r]:SetText(name)
			if shown then rankEds[r]:Show(); rankLbls[r]:Show() else rankEds[r]:Hide(); rankLbls[r]:Hide() end
			local f = type(T.rankFactor) == "table" and tonumber(T.rankFactor[r]) or 1
			rankEds[r]:SetText(tostring(floor(f * 100 + 0.5)))
		end
		p.dirty = false
	end

	local function collect()
		local data = GS:Copy(GS:GetLatest("tariff"))
		local zones = {}
		for i = 1, NZONES do
			local fs, rs = zoneEds[i].from:GetText(), zoneEds[i].rate:GetText()
			if fs:match("%S") or rs:match("%S") then
				local from, rate = GS:ParseMoney(fs), GS:ParsePercent(rs)
				if not from or from < 0 or not rate or rate < 0 or rate > 1 then
					return nil, LF("Zone %d ist ungültig.", i)
				end
				zones[#zones + 1] = { from, rate }
			end
		end
		table.sort(zones, function(a, b) return a[1] < b[1] end)
		if #zones == 0 or zones[1][1] ~= 0 then table.insert(zones, 1, { 0, 0 }) end
		data.zones = zones
		for _, fdef in ipairs(TARIFF_FIELDS) do if not fdef.head then
			local s = fieldEds[fdef.key]:GetText()
			local v
			if fdef.kind == "pct" then
				v = GS:ParsePercent(s)
				if not v or v < 0 or v > 1 then return nil, LF("%s: ungültiger Prozentwert.", L[fdef.label]) end
			elseif fdef.kind == "money" then
				v = GS:ParseMoney(s)
				if not v or v < 0 then return nil, LF("%s: ungültiger Betrag.", L[fdef.label]) end
			else
				v = tonumber(s)
				if not v or v < fdef.min or v > fdef.max then
					return nil, LF("%s: Wert zwischen %d und %d.", L[fdef.label], fdef.min, fdef.max)
				end
				v = floor(v)
			end
			data[fdef.key] = v
		end end
		local rf = {}
		for r = 0, 9 do
			if rankEds[r]:IsShown() then
				local s = rankEds[r]:GetText()
				local v = tonumber((s:gsub(",", ".")))
				if not v or v < 0 or v > 100 then return nil, LF("Steuerfaktor Rang %d: Wert zwischen 0 und 100.", r + 1) end
				if v ~= 100 then rf[r] = v / 100 end
			end
		end
		data.rankFactor = rf
		return data
	end

	local cNow = PinB(Check(p, 0, -(PH - 52), L["Sofort gültig (laufende Woche) – rückwirkend, mit Warnung"]))

	-- Speichern, bei "sofort gültig" erst nach Bestätigung
	local function doSave(data, presetName)
		local immediate = cNow:GetChecked() and true or false
		local function commit()
			local ok, res = GS:SaveSection("tariff", data, presetName, immediate)
			if ok then
				local what = presetName and LF("Preset „%s“ übernommen", L[presetName]) or L["Tarif gespeichert"]
				if res.now then
					GS:Print(LF("|cffff8040%s – gilt SOFORT für die laufende Woche (%s).|r", what, GS:WeekLabel(res.eff)))
				else
					GS:Print(LF("%s – gilt ab Woche %s.", what, GS:WeekLabel(res.eff)))
				end
				cNow:SetChecked(false)
				load()
				p.refresh(false)
			else
				GS:Print(L[res])
			end
		end
		if not immediate or #(GS:SectionList("tariff") or {}) == 0 then
			commit()
			return
		end
		local cur = GS:CurrentWeek()
		local text = LF("|cffff4040Achtung – rückwirkende Änderung!|r\n\nDer neue Tarif gilt sofort für die laufende Woche (%s). Alle Einnahmen dieser Woche, auch die bereits erfassten, werden damit neu besteuert.",
			GS:WeekLabel(cur))
		local latest = GS:GetLatestVersion("tariff")
		if latest and latest.eff > cur then
			text = text .. LF("\n\nDie für %s geplante Änderung (Version %s von %s) wird dadurch ersetzt.",
				GS:WeekLabel(latest.eff), tostring(latest.ver), tostring(latest.author))
		end
		text = text .. L["\n\nDie Änderung wird im Protokoll als „sofort“ vermerkt. Fortfahren?"]
		UI.Confirm(text, commit)
	end

	bSave = PinB(Button(p, L["Speichern"], 120, 0, -(PH - 26), function()
		local data, err = collect()
		if not data then GS:Print(err) return end
		doSave(data)
	end))
	PinB(Button(p, L["Verwerfen"], 100, 126, -(PH - 26), function() load(); p.refresh(false) end))
	PinB(Label(p, L["Presets:"], 250, -(PH - 22), "GameFontNormalSmall"))
	for i, pr in ipairs(GS.PRESETS) do
		presetButtons[i] = PinB(Button(p, L[pr.name], 90, 305 + (i - 1) * 96, -(PH - 26), function()
			local data = GS:Copy(GS:GetLatest("tariff"))
			for k, v in pairs(pr.data) do data[k] = GS:Copy(v) end
			doSave(data, pr.name)
		end))
	end

	return function(full)
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		if full or not p.dirty then load() end
		local canEdit = GS:HasRight(GS.player, "tariff")
		local canPreset = canEdit or GS:HasRight(GS.player, "preset")
		Enable(bSave, canEdit)
		Enable(cNow, canPreset)
		for _, b in ipairs(presetButtons) do Enable(b, canPreset) end
		local cur = GS:CurrentWeek()
		local _, effV = GS:GetEffective("tariff", cur)
		local latest = GS:GetLatestVersion("tariff")
		local txt
		if effV then
			txt = LF("Gültig diese Woche: Version %d von %s (%s)%s%s", effV.ver, effV.author, GS:FormatTime(effV.time),
				effV.preset and LF(" – Preset %s", L[effV.preset]) or "", effV.now and L[" |cffff8040(sofort geändert)|r"] or "")
		else
			txt = L["Gültig diese Woche: Standardwerte (Level 20)"]
		end
		if latest and latest ~= effV then
			txt = txt .. LF("\n|cffffd100Geplant ab %s: Version %d von %s|r", GS:WeekLabel(latest.eff), latest.ver, latest.author)
		end
		if not canEdit then txt = txt .. L["\n|cffaaaaaaDu darfst den Tarif nicht ändern.|r"] end
		info:SetText(txt)
	end
end

---------------------------------------------------------------------------
-- Werbungskosten-Liste
---------------------------------------------------------------------------
builders.wk = function(p)
	local info = Label(p, "", 0, 0, "GameFontHighlightSmall")
	info:SetWidth(PW)
	local work
	local weekOffset = 0      -- 0 = laufende Woche, -1 = letzte Woche
	local onlyUsed = false    -- nur Items mit Abzug anzeigen
	local tbl = CreateTable(p, 0, -40, 520, PH - 40, {
		{ title = L["Gruppe"], w = 80 }, { title = L["Item"], w = 160 },
		{ title = L["Marktwert"], w = 66, j = "RIGHT", tip = L["Aktueller AH-Preis – nur zur Orientierung. Abgesetzt wird immer der bezahlte Preis."] },
		{ title = L["Gekauft"], w = 46, j = "RIGHT", tip = L["Anzahl, die du in der gewählten Woche gekauft hast."] },
		{ title = L["Ø Kaufpreis"], w = 70, j = "RIGHT", tip = L["Durchschnittlich bezahlter Stückpreis (Händler oder AH)."] },
		{ title = L["Abgesetzt"], w = 68, j = "RIGHT", tip = L["Summe der bezahlten Preise – mindert dein zu versteuerndes Einkommen."] },
	})
	-- zweite Ansicht: Kaufliste (was wurde wann wo zu welchem Preis gekauft)
	local buyTbl = CreateTable(p, 0, -40, 520, PH - 40, {
		{ title = L["Datum"], w = 82 }, { title = L["Item"], w = 170 }, { title = L["Quelle"], w = 90 },
		{ title = L["Anz."], w = 40, j = "RIGHT" }, { title = L["Bezahlt"], w = 108, j = "RIGHT" },
	})
	buyTbl:SetShown(false)
	local showBuys = false
	p.buyTable = buyTbl
	local groupOf, groupOrder = {}, {}
	for gi, grp in ipairs(GS.WK_DEFAULT_GROUPS) do
		for _, id in ipairs(grp.ids) do
			groupOf[id] = grp.name
			groupOrder[id] = gi
		end
	end
	Label(p, L["Item hinzufügen (ID oder Shift-Klick):"], 540, -40, "GameFontNormalSmall"):SetWidth(270)
	local ed = Edit(p, 200, 540, -60)
	p.linkEdit = ed
	p.wkTable = tbl
	local bAdd, bDel, bSave, bDefaults, bWeek, cUsed, summary

	-- Werbungskosten des eigenen Kontos (Main + Twinks) für die gewählte Woche
	local function ownWK()
		local w = GS:CurrentWeek() + weekOffset
		local a = GS:AccountFor(GS.player)
		local chars = a and a.chars or { GS.player }
		local sum = GS:AccountWeek(chars, w)
		local res = (a and a.weeks[w]) or GS:CalcTax(sum, w, a and a.deposits[w])
		local itemCost = 0
		for _, x in pairs(sum.i) do itemCost = itemCost + (x[2] or 0) end
		return w, sum, res, itemCost, math.max(0, sum.k - itemCost)
	end

	local function render()
		local w, sum, res, itemCost, repair = ownWK()
		local ids = {}
		for id in pairs(work) do ids[id] = true end
		for id in pairs(sum.i) do ids[id] = true end -- auch Käufe von Items, die nicht mehr in der Liste stehen
		local list = {}
		for id in pairs(ids) do
			local used = sum.i[id] and sum.i[id][2] > 0
			if not onlyUsed or used then list[#list + 1] = id end
		end
		local names = nameSnapshot(list)
		table.sort(list, function(a, b)
			local ua, ub = (sum.i[a] and 1 or 0), (sum.i[b] and 1 or 0)
			if ua ~= ub then return ua > ub end -- abgesetzte Items zuerst
			local ga, gb = groupOrder[a] or 99, groupOrder[b] or 99
			if ga ~= gb then return ga < gb end
			if names[a] ~= names[b] then return names[a] < names[b] end
			return a < b
		end)
		local rows = {}
		for _, id in ipairs(list) do
			local price = GS:GetUnitPrice(id)
			local x = sum.i[id]
			local grp = L[groupOf[id] or "Eigene"]
			if not work[id] then grp = L["|cffff8040nicht in Liste|r"] end
			rows[#rows + 1] = {
				grp, GS:ItemLabel(id), price > 0 and Money(price) or "-",
				x and x[1] or "",
				(x and x[1] > 0) and Money(math.floor(x[2] / x[1])) or "",
				x and ("|cff40ff40" .. GS:FormatMoney(x[2], true) .. "|r") or "",
				key = id, id = id, itemID = id,
			}
		end
		tbl:SetRows(rows)

		-- Kaufliste: alle lokal bekannten Charaktere dieses Kontos (Main + Twinks auf diesem Account)
		local buys = {}
		local acc = GS:AccountFor(GS.player)
		for _, ch in ipairs(acc and acc.chars or { GS.player }) do
			local cdb = GS.db.chars[ch]
			for _, b in ipairs(cdb and cdb.purchases or {}) do
				buys[#buys + 1] = { b = b, char = ch }
			end
		end
		table.sort(buys, function(x, y) return x.b.t > y.b.t end)
		local brows = {}
		for i, e in ipairs(buys) do
			local b = e.b
			local unit = (b.n or 1) > 1 and LF(" |cffaaaaaa(%s/St.)|r", GS:FormatMoney(math.floor(b.c / b.n), true)) or ""
			brows[#brows + 1] = {
				date(L["%d.%m. %H:%M"], b.t), GS:ItemLabel(b.id), L[b.src or "?"] .. (e.char ~= GS.player and (" – " .. e.char) or ""),
				b.n or 1, Money(b.c) .. unit, key = i, itemID = b.id,
			}
		end
		buyTbl:SetRows(brows)
		tbl:SetShown(not showBuys)
		buyTbl:SetShown(showBuys)

		local lines = {
			LF("|cffffd100Deine Werbungskosten|r (%s, %s)", weekOffset == 0 and L["laufende Woche"] or L["letzte Woche"], GS:WeekLabel(w)),
			LF("Items: %s", Money(itemCost)),
			LF("Reparaturen: %s", Money(repair)),
		}
		if res.wkRev and res.wkRev > 0 then
			lines[#lines + 1] = LF("In Gildenbank gelegt: |cffff8040-%s|r", GS:FormatMoney(res.wkRev, true))
		end
		lines[#lines + 1] = LF("Tatsächlich: %s", Money(res.wkActual))
		lines[#lines + 1] = LF("Pauschbetrag: %s", Money(res.pausch))
		local viaPausch = res.wkActual < res.pausch
		lines[#lines + 1] = LF("|cffffd100Angesetzt: %s|r", Money(res.wkEff)) .. (viaPausch and L[" (Pauschbetrag)"] or L[" (tatsächliche Kosten)"])
		if viaPausch and res.wkActual > 0 then
			lines[#lines + 1] = LF("|cffaaaaaaNoch %s bis über dem Pauschbetrag.|r", GS:FormatMoney(res.pausch - res.wkActual, true))
		end
		summary:SetText(table.concat(lines, "\n"))
	end
	bAdd = Button(p, L["Hinzufügen"], 100, 540, -86, function()
		local s = ed:GetText()
		local id = tonumber(s:match("item:(%d+)")) or tonumber(s:match("^%s*(%d+)%s*$"))
		if not id then GS:Print(L["Keine gültige Item-ID."]) return end
		work[id] = true
		p.dirty = true
		ed:SetText("")
		render()
	end)
	bDel = Button(p, L["Ausgewähltes entfernen"], 170, 540, -116, function()
		local sel = tbl:Selected()
		if not sel then return end
		work[sel.id] = nil
		p.dirty = true
		render()
	end)
	bDefaults = Button(p, L["Standardliste ergänzen"], 170, 540, -146, function()
		local added = 0
		for id in pairs(GS:DefaultWKItems()) do
			if not work[id] then
				work[id] = true
				added = added + 1
			end
		end
		if added > 0 then p.dirty = true end
		if added > 0 then
			GS:Print(LF("%d Standard-Items ergänzt – zum Übernehmen „Liste speichern“ klicken.", added))
		else
			local total = 0
			for _ in pairs(GS:DefaultWKItems()) do total = total + 1 end
			GS:Print(LF("Alle %d Standard-Items sind bereits in der Liste – nichts zu tun.", total))
		end
		p.refresh(false)
	end)
	bSave = PinB(Button(p, L["Liste speichern"], 140, 540, -(PH - 26), function()
		local ok, res = GS:SaveSection("wklist", { items = GS:Copy(work) })
		if ok then
			GS:Print(LF("Werbungskosten-Liste gespeichert – gilt ab Woche %s.", GS:WeekLabel(res.eff)))
			p.dirty = false
		else
			GS:Print(L[res])
		end
	end))
	PinB(Button(p, L["Verwerfen"], 100, 686, -(PH - 26), function() p.dirty = false; p.refresh(true) end))
	Label(p, L["Käufe dieser Items (Händler/AH) und Reparaturen mindern dein zu versteuerndes Einkommen. Legst du ein abgesetztes Item in die Gildenbank, wird der Abzug zurückgenommen."], 540, -178, "GameFontDisableSmall"):SetWidth(265)
	bWeek = Button(p, L["Woche: laufend"], 130, 540, -232, function()
		weekOffset = (weekOffset == 0) and -1 or 0
		bWeek:SetText(weekOffset == 0 and L["Woche: laufend"] or L["Woche: letzte"])
		render()
	end)
	cUsed = Check(p, 676, -231, L["nur abgesetzte"], function(self)
		onlyUsed = self:GetChecked() and true or false
		render()
	end)
	local bBuys
	bBuys = Button(p, L["Ansicht: Itemliste"], 170, 540, -262, function()
		showBuys = not showBuys
		bBuys:SetText(showBuys and L["Ansicht: Meine Käufe"] or L["Ansicht: Itemliste"])
		render()
	end)
	summary = Label(p, "", 540, -292, "GameFontHighlightSmall")
	summary:SetWidth(265)
	if summary.SetSpacing then summary:SetSpacing(2) end

	return function(full)
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		if full and not p.dirty or not work then
			work = GS:Copy(GS:GetLatest("wklist").items or {})
		end
		local can = GS:HasRight(GS.player, "wklist")
		Enable(bAdd, can); Enable(bDel, can); Enable(bSave, can); Enable(bDefaults, can)
		local _, effV = GS:GetEffective("wklist", GS:CurrentWeek())
		-- was ist konfiguriert? Anzahl je Gruppe
		local total, perGroup, own = 0, {}, 0
		for id in pairs(work) do
			total = total + 1
			local gi = groupOrder[id]
			if gi then perGroup[gi] = (perGroup[gi] or 0) + 1 else own = own + 1 end
		end
		local parts = {}
		for gi, grp in ipairs(GS.WK_DEFAULT_GROUPS) do
			if perGroup[gi] then parts[#parts + 1] = L[grp.name] .. " " .. perGroup[gi] end
		end
		if own > 0 then parts[#parts + 1] = L["Eigene"] .. " " .. own end
		info:SetText((effV and LF("Gültige Liste: Version %s von %s", tostring(effV.ver), tostring(effV.author)) or L["Gültige Liste: Standardliste"])
			.. (p.dirty and L["   |cffffd100(ungespeicherte Änderungen)|r"] or "")
			.. (can and "" or L["   |cffaaaaaa(nur lesen)|r"])
			.. LF("\n|cffffd100Konfiguriert: %d Items|r", total) .. (#parts > 0 and (" – " .. table.concat(parts, " · ")) or "")
			.. L["   |cffaaaaaa+ Reparaturen zählen immer|r"])
		p.configuredCount = total
		UI.SafeCall("Werbungskosten-Liste", render)
	end
end

if type(ChatEdit_InsertLink) == "function" then
	hooksecurefunc("ChatEdit_InsertLink", function(link)
		local p = panels.wk
		if p and p.linkEdit and p.linkEdit:HasFocus() and link then
			p.linkEdit:SetText(link)
		end
	end)
end

---------------------------------------------------------------------------
-- Gildenbank
---------------------------------------------------------------------------
local SOURCES = { { "auctionator", "Auctionator, sonst Scan, sonst Händler" }, { "scan", "AH-Scan, sonst Händler" }, { "vendor", "nur Händlerpreis" } }

builders.bank = function(p)
	local info = Label(p, "", 0, 0, "GameFontHighlightSmall")
	info:SetWidth(PW)
	local function dirty() p.dirty = true end
	Label(p, L["Freie Tabs (Entnahmen werden nicht belastet):"], 0, -22, "GameFontNormalSmall")
	local tabChecks = {}
	for i = 1, 8 do
		tabChecks[i] = Check(p, (i - 1) * 100, -38, LF("Tab %d", i), dirty)
	end
	local cRepair = Check(p, 0, -66, L["Gildenreparaturen dem Konto belasten"], dirty)
	Label(p, L["Abschlag auf den Item-Wert (%):"], 300, -70, "GameFontHighlightSmall")
	local edDisc = Edit(p, 50, 490, -66, dirty)
	Label(p, L["Preisdaten max. Alter (Tage):"], 560, -70, "GameFontHighlightSmall")
	local edAge = Edit(p, 40, 740, -66, dirty)
	Label(p, L["Bewertung:"], 0, -98, "GameFontHighlightSmall")
	local srcIndex = 1
	local bSrc
	bSrc = Button(p, "", 240, 70, -94, function()
		srcIndex = srcIndex % #SOURCES + 1
		bSrc:SetText(L[SOURCES[srcIndex][2]])
		p.dirty = true
	end)
	local bSave = Button(p, L["Speichern"], 110, 330, -94, function()
		local disc = GS:ParsePercent(edDisc:GetText())
		local age = tonumber(edAge:GetText())
		if not disc or disc < 0 or disc > 1 then GS:Print(L["Ungültiger Abschlag."]) return end
		if not age or age < 1 or age > 90 then GS:Print(L["Alter muss zwischen 1 und 90 Tagen liegen."]) return end
		local free = {}
		for i = 1, 8 do if tabChecks[i]:GetChecked() then free[i] = true end end
		local ok, res = GS:SaveSection("bank", {
			free = free, chargeRepair = cRepair:GetChecked() and true or false,
			discount = disc, source = SOURCES[srcIndex][1], maxAge = floor(age),
		})
		if ok then
			GS:Print(LF("Gildenbank-Einstellungen gespeichert – gelten ab Woche %s.", GS:WeekLabel(res.eff)))
			p.dirty = false
		else
			GS:Print(L[res])
		end
	end)
	Button(p, L["Verwerfen"], 90, 446, -94, function() p.dirty = false; p.refresh(true) end)
	local bPay = Button(p, L["Steuern tilgen"], 120, 560, -94, function() GS:PayTaxes() end)
	local payInfo = Label(p, "", 686, -98, "GameFontHighlightSmall")
	payInfo:SetWidth(PW - 686)

	local tbl = CreateTable(p, 0, -128, PW, PH - 128, {
		{ title = L["Datum"], w = 90 }, { title = L["Spieler"], w = 100 }, { title = L["Art"], w = 105 }, { title = L["Item"], w = 170 },
		{ title = L["Menge"], w = 50, j = "RIGHT" }, { title = L["Tab"], w = 35, j = "RIGHT" }, { title = L["Wert"], w = 100, j = "RIGHT" },
		{ title = L["Quelle"], w = 135 },
	})

	local function load()
		local B = GS:GetLatest("bank")
		local names = {}
		for i = 1, 8 do
			local name = GetGuildBankTabInfo and GetGuildBankTabInfo(i)
			tabChecks[i].label:SetText(name and name ~= "" and name or LF("Tab %d", i))
			tabChecks[i]:SetChecked(B.free and B.free[i] and true or false)
		end
		cRepair:SetChecked(B.chargeRepair and true or false)
		edDisc:SetText(GS:FormatPercent(B.discount or 0))
		edAge:SetText(tostring(B.maxAge or 7))
		srcIndex = 1
		for i, s in ipairs(SOURCES) do if s[1] == B.source then srcIndex = i end end
		bSrc:SetText(L[SOURCES[srcIndex][2]])
		p.dirty = false
	end

	return function(full)
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		if full and not p.dirty then load() elseif not p.loaded then load() end
		p.loaded = true
		local due = GS:OutstandingTaxes()
		Enable(bPay, GS.bankOpen and due > 0)
		if due <= 0 then
			payInfo:SetText(L["|cff40ff40Nichts offen|r"])
		elseif GS.bankOpen then
			payInfo:SetText(LF("Offen: %s", Money(due)))
		else
			payInfo:SetText(LF("Offen: %s", Money(due)) .. L["\n|cffaaaaaaGildenbank öffnen|r"])
		end
		local can = GS:HasRight(GS.player, "bank")
		Enable(bSave, can); Enable(bSrc, can); Enable(cRepair, can)
		for i = 1, 8 do Enable(tabChecks[i], can) end
		local _, effV = GS:GetEffective("bank", GS:CurrentWeek())
		local lastRead = GS:LastBankRead()
		info:SetText((effV and LF("Gültig: Version %s von %s", tostring(effV.ver), tostring(effV.author)) or L["Gültig: Standardeinstellungen"])
			.. (can and "" or L["   |cffaaaaaa(nur lesen)|r"])
			.. L["   |cffffd100Log zuletzt gelesen:|r "] .. (lastRead and GS:FormatDataAge(lastRead) or L["|cff888888nie|r"]))
		local g = GS:G()
		local ov = GS:ValueOverrides()
		local list = {}
		for _, e in ipairs(g.bank) do list[#list + 1] = e end
		table.sort(list, function(a, b) return a.t > b.t end)
		local rows = {}
		for _, e in ipairs(list) do
			local v, src = GS:EntryValue(e, ov)
			rows[#rows + 1] = {
				GS:FormatTime(e.t), L[e.c], L[KIND_LABEL[e.y]], e.i > 0 and GS:ItemLabel(e.i) or "", e.i > 0 and e.n or "",
				e.b > 0 and e.b or "", Money(v), (GS:IsUnverified(src) and "|cffff8040" or "") .. L[GS.SOURCE_LABEL[src] or src] .. "|r",
				key = GS.BankKey(e) .. e.t, itemID = e.i,
			}
		end
		tbl:SetRows(rows)
	end
end

---------------------------------------------------------------------------
-- Rechte
---------------------------------------------------------------------------
builders.rechte = function(p)
	local info = Label(p, "", 0, 0, "GameFontHighlightSmall")
	info:SetWidth(PW)
	local LABEL_W, COL_W, MAXR = 270, 54, 10
	local rankLabels, checks = {}, {}
	for r = 0, MAXR - 1 do
		local l = Label(p, "", LABEL_W + r * COL_W, -30, "GameFontNormalSmall")
		l:SetWidth(COL_W - 2)
		l:SetJustifyH("CENTER")
		rankLabels[r] = l
	end
	for i, right in ipairs(GS.RIGHTS) do
		local y = -50 - (i - 1) * 28
		Label(p, L[right.label], 0, y - 5, "GameFontHighlightSmall"):SetWidth(LABEL_W - 6)
		checks[right.key] = {}
		for r = 0, MAXR - 1 do
			checks[right.key][r] = Check(p, LABEL_W + r * COL_W + 14, y, "", function() p.dirty = true end)
		end
	end
	local yb = -50 - #GS.RIGHTS * 28 - 6
	Label(p, L["Rechte-Matrix ändern: nur Gildenmeister (fest).  Der Gildenmeister hat immer alle Rechte."], 0, yb, "GameFontDisableSmall")
	local bSave = PinB(Button(p, L["Speichern"], 120, 0, -(PH - 26), function()
		local data = {}
		for _, right in ipairs(GS.RIGHTS) do
			data[right.key] = {}
			for r = 1, MAXR - 1 do
				if checks[right.key][r]:IsShown() and checks[right.key][r]:GetChecked() then data[right.key][r] = true end
			end
		end
		local ok, err = GS:SavePerms(data)
		if ok then GS:Print(L["Rechte gespeichert und an alle verteilt."]); p.dirty = false else GS:Print(L[err]) end
	end))
	PinB(Button(p, L["Verwerfen"], 100, 126, -(PH - 26), function() p.dirty = false; p.refresh(true) end))

	return function(full)
		if not GS:G() then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		local n = (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 0
		local isGM = GS:IsGM(GS.player)
		local perms = GS:GetPerms()
		for r = 0, MAXR - 1 do
			local shown = r < n
			local name = shown and GuildControlGetRankName(r + 1) or ""
			rankLabels[r]:SetText(name)
			for _, right in ipairs(GS.RIGHTS) do
				local c = checks[right.key][r]
				if shown then c:Show() else c:Hide() end
				if r == 0 then
					c:SetChecked(true)
					Enable(c, false)
				else
					if full or not p.dirty then c:SetChecked(perms[right.key] and perms[right.key][r] and true or false) end
					Enable(c, isGM)
				end
			end
		end
		Enable(bSave, isGM)
		local g = GS:G()
		local txt = g.perms and LF("Version %s von %s (%s)", tostring(g.perms.ver), tostring(g.perms.author), GS:FormatTime(g.perms.time)) or L["Standardrechte (Gildenmeister + Rang 2 = Offiziere)"]
		if not isGM then txt = txt .. L["   |cffaaaaaa(nur der Gildenmeister kann ändern)|r"] end
		if n == 0 then txt = txt .. L["\n|cffff8040Gildenränge noch nicht geladen.|r"] end
		info:SetText(txt)
	end
end

---------------------------------------------------------------------------
-- Protokoll
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Statistik
---------------------------------------------------------------------------
local STAT_WEEKS = 8

builders.stats = function(p)
	local denied = Label(p, L["|cffff4040Dein Rang darf die Konten der Gilde nicht sehen.|r"], 0, -200, "GameFontNormalLarge")
	denied:SetWidth(PW)
	denied:SetJustifyH("CENTER")
	local body = CreateFrame("Frame", nil, p)
	body:SetAllPoints()
	local selectedWeek

	-- Balkendiagramm: Steuereinnahmen der letzten Wochen
	Label(body, LF("Steuereinnahmen der Gilde (letzte %d Wochen)", STAT_WEEKS), 0, 0, "GameFontNormal")
	local CH_W, CH_H = 470, 170
	local chart = CreateFrame("Frame", nil, body)
	chart:SetPoint("TOPLEFT", 0, -40)
	chart:SetSize(CH_W, CH_H)
	local chartBg = chart:CreateTexture(nil, "BACKGROUND")
	chartBg:SetAllPoints()
	chartBg:SetColorTexture(0, 0, 0, 0.3)
	local SLOT = CH_W / STAT_WEEKS
	local bars = {}
	for i = 1, STAT_WEEKS do
		local b = {}
		b.tex = chart:CreateTexture(nil, "ARTWORK")
		b.tex:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * SLOT + 8, 0)
		b.tex:SetSize(SLOT - 16, 1)
		b.value = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.value:SetPoint("BOTTOM", b.tex, "TOP", 0, 2)
		b.label = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		b.label:SetPoint("TOP", chart, "BOTTOMLEFT", (i - 0.5) * SLOT, -4)
		b.click = CreateFrame("Button", nil, chart)
		b.click:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * SLOT, 0)
		b.click:SetSize(SLOT, CH_H)
		b.click:SetScript("OnClick", function(self)
			selectedWeek = self.week
			p.refresh(false)
		end)
		bars[i] = b
	end
	local chartHint = Label(body, L["|cffaaaaaaBalken anklicken = Woche unten aufschlüsseln. ~ = laufende Woche (geschätzt).|r"], 0, -(40 + CH_H + 22), "GameFontDisableSmall")

	-- rechte Spalte: Quote und Kennzahlen
	local kpi = Label(body, "", 500, 0, "GameFontHighlightSmall")
	kpi:SetWidth(PW - 500)
	kpi:SetJustifyV("TOP")
	if kpi.SetSpacing then kpi:SetSpacing(3) end

	-- unten links: Einnahmequellen der gewählten Woche
	local SY = -(40 + CH_H + 46)
	local srcTitle = Label(body, "", 0, SY, "GameFontNormal")
	local SOURCES_DEF = {
		{ key = "loot", label = L["Loot"], color = { 0.95, 0.8, 0.3 } },
		{ key = "quest", label = L["Quests"], color = { 0.4, 0.8, 1 } },
		{ key = "vendor", label = L["Händler"], color = { 0.6, 0.9, 0.5 } },
		{ key = "ahNet", label = L["AH-Gewinn"], color = { 0.9, 0.55, 0.9 } },
		{ key = "evasion", label = L["Hinterziehung"], color = { 1, 0.3, 0.3 }, officerOnly = true },
	}
	local SRC_W = 300
	local srcRows = {}
	for i, def in ipairs(SOURCES_DEF) do
		local y = SY - 22 - (i - 1) * 20
		local r = {}
		r.label = Label(body, def.label, 0, y, "GameFontHighlightSmall")
		r.bg = body:CreateTexture(nil, "BACKGROUND")
		r.bg:SetPoint("TOPLEFT", body, "TOPLEFT", 100, y + 1)
		r.bg:SetSize(SRC_W, 12)
		r.bg:SetColorTexture(0, 0, 0, 0.3)
		r.bar = body:CreateTexture(nil, "ARTWORK")
		r.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 100, y + 1)
		r.bar:SetSize(1, 12)
		r.bar:SetColorTexture(def.color[1], def.color[2], def.color[3], 0.9)
		r.value = Label(body, "", 100 + SRC_W + 8, y, "GameFontHighlightSmall")
		srcRows[i] = r
	end

	-- unten rechts: größte Steuerzahler der gewählten Woche
	local topTitle = Label(body, "", 500, SY, "GameFontNormal")
	local topText = Label(body, "", 500, SY - 22, "GameFontHighlightSmall")
	topText:SetWidth(PW - 500)
	topText:SetJustifyV("TOP")
	if topText.SetSpacing then topText:SetSpacing(3) end

	p.statBars = bars

	-- Aufteilung an die Fenstergröße anpassen: linke Spalte 60 %, rechte Spalte der Rest
	local VALUE_W, LABEL_W = 132, 90
	local function layout()
		local TW = PW + (UI.extraW or 0)
		local LW = math.floor(TW * 0.6)
		local RX = LW + 16
		CH_W, CH_H = LW, 170 + math.floor((UI.extraH or 0) * 0.6)
		chart:SetSize(CH_W, CH_H)
		SLOT = CH_W / STAT_WEEKS
		for i, b in ipairs(bars) do
			b.tex:ClearAllPoints()
			b.tex:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * SLOT + 8, 0)
			b.tex:SetWidth(SLOT - 16)
			b.label:ClearAllPoints()
			b.label:SetPoint("TOP", chart, "BOTTOMLEFT", (i - 0.5) * SLOT, -4)
			b.click:ClearAllPoints()
			b.click:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * SLOT, 0)
			b.click:SetSize(SLOT, CH_H)
		end
		chartHint:ClearAllPoints()
		chartHint:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(40 + CH_H + 22))
		kpi:ClearAllPoints()
		kpi:SetPoint("TOPLEFT", body, "TOPLEFT", RX, 0)
		kpi:SetWidth(TW - RX)
		local sy = -(40 + CH_H + 46)
		srcTitle:ClearAllPoints()
		srcTitle:SetPoint("TOPLEFT", body, "TOPLEFT", 0, sy)
		local barW = math.max(40, LW - LABEL_W - VALUE_W - 8)
		for i, r in ipairs(srcRows) do
			local y = sy - 22 - (i - 1) * 20
			r.label:ClearAllPoints(); r.label:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
			r.label:SetWidth(LABEL_W - 4)
			r.bg:ClearAllPoints(); r.bg:SetPoint("TOPLEFT", body, "TOPLEFT", LABEL_W, y + 1)
			r.bg:SetSize(barW, 12)
			r.bar:ClearAllPoints(); r.bar:SetPoint("TOPLEFT", body, "TOPLEFT", LABEL_W, y + 1)
			r.value:ClearAllPoints(); r.value:SetPoint("TOPLEFT", body, "TOPLEFT", LABEL_W + barW + 8, y)
			r.value:SetWidth(VALUE_W)
		end
		SRC_W = barW
		topText:SetWidth(TW - RX)
		p.rightX = RX
		p.leftW, p.srcY = LW, sy
	end

	-- Sparziele (unter den Einnahmequellen, linke Spalte)
	-- Balken in Abschnitten: Steuern, Guthaben der Mitglieder, sonstiges Bankgold, diese Woche erwartet
	local GOAL_SEGS = {
		{ key = "tax", label = L["bezahlte Steuern"], color = { 0.25, 0.8, 0.3 } },
		{ key = "credit", label = L["Guthaben der Mitglieder"], color = { 0.3, 0.6, 1 } },
		{ key = "other", label = L["ohne Zuordnung"], color = { 1, 0.75, 0.2 } },
		{ key = "upcoming", label = L["diese Woche erwartet"], color = { 0.65, 0.95, 0.65 }, alpha = 0.45 },
	}
	local goalTitle = Label(body, L["Sparziele der Gilde"], 0, 0, "GameFontNormal")
	local goalLegend = Label(body, "", 0, 0, "GameFontDisableSmall")
	local bManage = Button(body, L["Verwalten"], 90, 0, 0, function() UI.ShowGoalManager() end)
	local goalRows = {}
	for i = 1, 6 do
		local r = { segs = {} }
		r.label = Label(body, "", 0, 0, "GameFontHighlightSmall")
		r.bg = body:CreateTexture(nil, "BACKGROUND")
		r.bg:SetColorTexture(0, 0, 0, 0.35)
		for j, sg in ipairs(GOAL_SEGS) do
			local t = body:CreateTexture(nil, "ARTWORK")
			t:SetColorTexture(sg.color[1], sg.color[2], sg.color[3], sg.alpha or 0.95)
			r.segs[j] = t
		end
		-- Tooltip mit der Aufschlüsselung
		r.hot = CreateFrame("Frame", nil, body)
		r.hot:EnableMouse(true)
		r.hot:SetScript("OnEnter", function(self)
			local d = self.data
			if not d then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(d.name .. ": " .. GS:FormatMoney(d.target, true))
			for _, sg in ipairs(GOAL_SEGS) do
				local v = d.b[sg.key] or 0
				if v > 0 then GameTooltip:AddDoubleLine(sg.label, GS:FormatMoney(v, true), sg.color[1], sg.color[2], sg.color[3], 1, 1, 1) end
			end
			if d.b.known then
				GameTooltip:AddLine(LF("Gildenbank gesamt %s, Stand %s", GS:FormatMoney(d.b.bank, true), GS:FormatAgo(d.b.t)), 0.7, 0.7, 0.7)
			else
				GameTooltip:AddLine(L["Gildenbank noch nicht gesehen – gezählt werden die Steuereinnahmen."], 0.7, 0.7, 0.7, true)
			end
			GameTooltip:Show()
		end)
		r.hot:SetScript("OnLeave", function() GameTooltip:Hide() end)
		goalRows[i] = r
	end
	local goalMore = Label(body, "", 0, 0, "GameFontDisableSmall")
	p.goalRows = goalRows
	local function renderGoals()
		local LW, gy = p.leftW, p.srcY - 22 - 5 * 20 - 10
		goalTitle:ClearAllPoints(); goalTitle:SetPoint("TOPLEFT", body, "TOPLEFT", 0, gy)
		bManage:ClearAllPoints(); bManage:SetPoint("TOPLEFT", body, "TOPLEFT", LW - 90, gy + 4)
		if GS:HasRight(GS.player, "corr") then bManage:Show() else bManage:Hide() end
		local goals = GS:Goals()
		local bm = GS:G() and GS:G().bankMoney
		goalTitle:SetText(L["Sparziele der Gilde"] .. " " .. (bm and LF("|cffaaaaaa(Gildenbank %s, Stand %s)|r", Money(bm.v), GS:FormatAgo(bm.t))
			or L["|cffaaaaaa(Gildenbank noch nicht gesehen)|r"]))
		local leg = {}
		for _, sg in ipairs(GOAL_SEGS) do leg[#leg + 1] = Swatch(sg.color) .. " " .. sg.label end
		goalLegend:ClearAllPoints(); goalLegend:SetPoint("TOPLEFT", body, "TOPLEFT", 0, gy - 16)
		goalLegend:SetText(#goals > 0 and table.concat(leg, "   ") or "")
		local top = gy - 32
		local TH = PH + (UI.extraH or 0)
		local fit = math.max(1, math.min(#goalRows, math.floor((TH + top - 4) / 30)))
		local BW = LW - 10
		for i, r in ipairs(goalRows) do
			local gl = goals[i]
			local y = top - (i - 1) * 30
			r.label:ClearAllPoints(); r.label:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
			r.label:SetWidth(BW)
			r.bg:ClearAllPoints(); r.bg:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y - 14)
			r.bg:SetSize(BW, 10)
			r.hot:ClearAllPoints(); r.hot:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
			r.hot:SetSize(BW, 26)
			if gl and i <= fit then
				local b = GS:GoalBreakdown(gl)
				local have = (b.tax or 0) + (b.credit or 0) + (b.other or 0)
				local done = have >= gl.target
				r.label:SetText((done and "|cff40ff40" or "") .. gl.name .. (done and L[" – erreicht!|r"] or "") .. LF(":  %s von %s", Money(have), Money(gl.target))
					.. string.format(" |cffaaaaaa(%d %%%s)|r", math.floor(math.min(1, have / gl.target) * 100),
						(b.upcoming or 0) > 0 and LF(", +~%s diese Woche", GS:FormatMoney(b.upcoming, true)) or ""))
				-- Abschnitte nebeneinander, gekappt am Ziel
				local x = 0
				for j, sg in ipairs(GOAL_SEGS) do
					local t = r.segs[j]
					local v = b[sg.key] or 0
					local w = math.floor(BW * v / gl.target + 0.5)
					w = math.min(w, BW - x)
					t:ClearAllPoints()
					if w >= 1 then
						t:SetPoint("TOPLEFT", body, "TOPLEFT", x, y - 14)
						t:SetSize(w, 10)
						t:Show()
						x = x + w
					else
						t:Hide()
					end
				end
				r.hot.data = { name = gl.name, target = gl.target, b = b }
				r.label:Show(); r.bg:Show(); r.hot:Show()
			else
				for _, t in ipairs(r.segs) do t:Hide() end
				r.hot.data = nil
				r.hot:Hide()
				if i == 1 and not gl then
					r.label:SetText(GS:HasRight(GS.player, "corr") and L["|cffaaaaaaNoch keine Sparziele – über „Verwalten“ anlegen.|r"] or L["|cffaaaaaaNoch keine Sparziele.|r"])
					r.label:Show(); r.bg:Hide()
				else
					r.label:Hide(); r.bg:Hide()
				end
			end
		end
		goalMore:ClearAllPoints(); goalMore:SetPoint("TOPLEFT", body, "TOPLEFT", 0, top - fit * 30)
		goalMore:SetText(#goals > fit and LF("+%d weitere (Fenster größer ziehen oder „Verwalten“)", #goals - fit) or "")
	end
	-- „Größte Steuerzahler“ direkt unter den Kennzahlen der rechten Spalte
	local function placeTop()
		local h = tonumber(kpi.GetStringHeight and kpi:GetStringHeight()) or 330
		local ty = -(math.ceil(h) + 14)
		topTitle:ClearAllPoints(); topTitle:SetPoint("TOPLEFT", body, "TOPLEFT", p.rightX, ty)
		topText:ClearAllPoints(); topText:SetPoint("TOPLEFT", body, "TOPLEFT", p.rightX, ty - 20)
	end
	UI.relayoutHooks[#UI.relayoutHooks + 1] = function() if p:IsShown() then p.refresh(false) end end

	return function()
		layout()
		if not GS:G() then body:Hide(); denied:Hide(); noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		if not GS:HasRight(GS.player, "viewall") then
			body:Hide()
			denied:Show()
			return
		end
		denied:Hide()
		body:Show()
		local calc = GS:Calc()
		local cur = calc.week
		selectedWeek = selectedWeek or (cur - 1)
		local officer = GS:CanSeeEvasion()

		-- Wochensummen
		local totals, maxTotal = {}, 1
		for i = 1, STAT_WEEKS do
			local w = cur - STAT_WEEKS + i
			local sum = 0
			for _, a in pairs(calc.accounts) do
				local r = a.weeks[w] or (w == cur and a.cur) or nil
				if r then sum = sum + (r.total or 0) end
			end
			totals[i] = { w = w, sum = sum }
			if sum > maxTotal then maxTotal = sum end
		end
		for i, t in ipairs(totals) do
			local b = bars[i]
			local h = math.max(1, math.floor((CH_H - 18) * t.sum / maxTotal))
			b.tex:SetHeight(h)
			if t.w == selectedWeek then
				b.tex:SetColorTexture(1, 0.85, 0.3, 1)
			elseif t.w == cur then
				b.tex:SetColorTexture(0.6, 0.6, 0.6, 0.7)
			else
				b.tex:SetColorTexture(0.85, 0.65, 0.2, 0.85)
			end
			b.value:SetText((t.w == cur and "~" or "") .. GS:FormatMoney(t.sum, true))
			b.label:SetText(date(L["%d.%m."], GS:WeekStart(t.w)))
			b.click.week = t.w
		end

		-- Kennzahlen
		local nq, no, nu, total = 0, 0, 0, 0
		local allTax = 0
		for _, a in pairs(calc.accounts) do
			total = total + 1
			allTax = allTax + (a.taxTotal or 0)
			if a.status == "quitt" then nq = nq + 1 elseif a.status == "offen" then no = no + 1 else nu = nu + 1 end
		end
		-- Addon-Nutzer: alle, von deren Konto es Addon-Daten gibt (auch offline); „aktiv“ = Lebenszeichen in den letzten Tagen
		local members, active, recent = 0, 0, 0
		local staleSec = (GS:GetLatest("tariff").staleDays or 7) * 86400
		for name in pairs(GS.roster) do
			members = members + 1
			local last = name == GS.player and GS:Now() or GS:LastAddonSign(name)
			if last then
				active = active + 1
				if GS:Now() - last <= staleSec then recent = recent + 1 end
			end
		end
		local lastSum = totals[STAT_WEEKS - 1] and totals[STAT_WEEKS - 1].sum or 0
		local prevSum = totals[STAT_WEEKS - 2] and totals[STAT_WEEKS - 2].sum or 0
		local pct = function(x, n) return n > 0 and math.floor(x * 100 / n + 0.5) or 0 end
		local m = GS:GuildMetrics(calc, cur - 1)
		local trend = ""
		if prevSum > 0 then
			local d = (lastSum - prevSum) / prevSum * 100
			trend = LF(" %s(%+d %% zur Vorwoche)|r", d >= 0 and "|cff40ff40" or "|cffff8040", math.floor(d + (d >= 0 and 0.5 or -0.5)))
		end
		local lines = {
			L["|cffffd100Zahlungsmoral|r"],
			LF("  |cff40ff40%d quitt|r · |cffffd100%d offen|r · |cffff4040%d überfällig|r", nq, no, nu),
			LF("  Quote quitt: |cffffffff%d %%|r von %d Konten", pct(nq, total), total),
			LF("  Offene Steuern: %s", Money(m.openDebt)) .. (m.overdueDebt > 0 and LF(" |cffff4040(davon überfällig %s)|r", GS:FormatMoney(m.overdueDebt, true)) or ""),
			" ",
			L["|cffffd100Addon-Abdeckung|r"],
			LF("  %d von %d Mitgliedern nutzen das Addon (%d %%)", active, members, pct(active, members)),
			LF("  |cffaaaaaadavon %d in den letzten %d Tagen gesehen|r", recent, GS:GetLatest("tariff").staleDays or 7),
			" ",
			L["|cffffd100Steuern|r"],
			LF("  letzte Woche: %s", Money(lastSum)) .. trend,
			LF("  Ø pro Konto: %s", Money(total > 0 and math.floor(lastSum / total) or 0)),
			LF("  insgesamt: %s", Money(allTax)),
			LF("  Steuerquote der Gilde: %.1f %% |cffaaaaaa(letzte Woche)|r", m.rate * 100),
			LF("  steuerfrei geblieben: %d von %d Konten", m.taxFree, m.accounts),
			" ",
			L["|cffffd100Wirtschaft letzte Woche|r"],
			LF("  Einkommen der Gilde: %s", Money(m.income)),
			LF("  Werbungskosten abgesetzt: %s", Money(m.wk)),
			LF("  Gildenbank: %s eingezahlt, %s entnommen", Money(m.bankIn), Money(m.bankOut)),
		}
		if m.topEarner then
			lines[#lines + 1] = LF("  Bester Verdiener: %s – %s", m.topEarner.main, Money(m.topEarner.income))
		end
		if officer then
			lines[#lines + 1] = LF("  Vermögen der Gilde: %s |cffaaaaaa(nur Offiziere)|r", Money(m.wealth))
		end
		kpi:SetText(table.concat(lines, "\n"))
		placeTop()
		renderGoals()

		-- Einnahmequellen der gewählten Woche
		srcTitle:SetText(LF("Einnahmequellen – %s", GS:WeekLabel(selectedWeek)) .. (selectedWeek == cur and L[" (laufend)"] or ""))
		local sums, maxSrc, allSrc = {}, 1, 0
		for i, def in ipairs(SOURCES_DEF) do
			local v = 0
			if not def.officerOnly or officer then
				for _, a in pairs(calc.accounts) do
					local r = a.weeks[selectedWeek]
					if r then v = v + math.max(0, r[def.key] or 0) end
				end
			end
			sums[i] = v
			if v > maxSrc then maxSrc = v end
			allSrc = allSrc + v
		end
		for i, def in ipairs(SOURCES_DEF) do
			local r = srcRows[i]
			local visible = not def.officerOnly or officer
			for _, part in ipairs({ r.label, r.bg, r.bar, r.value }) do
				if visible then part:Show() else part:Hide() end
			end
			if visible then
				r.bar:SetWidth(math.max(1, math.floor(SRC_W * sums[i] / maxSrc)))
				r.value:SetText(Money(sums[i]) .. " |cffaaaaaa(" .. pct(sums[i], allSrc) .. " %)|r")
			end
		end

		-- größte Steuerzahler
		topTitle:SetText(LF("Größte Steuerzahler – %s", date(L["%d.%m."], GS:WeekStart(selectedWeek))))
		local list = {}
		for main, a in pairs(calc.accounts) do
			local r = a.weeks[selectedWeek]
			if r and r.total > 0 then list[#list + 1] = { main = main, tax = r.total } end
		end
		table.sort(list, function(x, y)
			if x.tax ~= y.tax then return x.tax > y.tax end
			return x.main < y.main
		end)
		local lines = {}
		for i = 1, math.min(5, #list) do
			lines[#lines + 1] = i .. ". " .. list[i].main .. " – " .. Money(list[i].tax)
		end
		if #lines == 0 then lines[1] = L["|cffaaaaaaKeine Steuern in dieser Woche.|r"] end
		topText:SetText(table.concat(lines, "\n"))
	end
end

local SECTION_LABEL = { tariff = "Tarif", wklist = "Werbungskosten-Liste", bank = "Gildenbank-Einstellungen" }

builders.log = function(p)
	local tbl = CreateTable(p, 0, 0, PW, PH, {
		{ title = L["Zeit"], w = 100 }, { title = L["Autor"], w = 110 }, { title = L["Art"], w = 170 }, { title = L["Details"], w = 400 },
	})
	return function()
		local g = GS:G()
		if not g then noGuild(p); return end
		if p.noGuild then p.noGuild:Hide() end
		local list = {}
		for _, name in ipairs(GS.SECTIONS) do
			for _, v in ipairs(g.sections[name]) do
				list[#list + 1] = { v.time, v.author, LF("%s geändert", L[SECTION_LABEL[name]]),
					LF("Version %s, gültig ab %s", tostring(v.ver), GS:WeekLabel(v.eff)) .. (v.preset and LF(", Preset %s", L[v.preset]) or "")
					.. (v.now and L[" |cffff8040(sofort, rückwirkend für die laufende Woche)|r"] or "") }
			end
		end
		if g.perms then
			list[#list + 1] = { g.perms.time, g.perms.author, L["Rechte-Matrix geändert"], LF("Version %s", tostring(g.perms.ver)) }
		end
		for _, e in pairs(g.adm) do
			local d = e.d
			local kind, det
			if e.k == "LINK" then kind, det = L["Twink zugeordnet"], LF("%s zu %s", tostring(d.c), tostring(d.m))
			elseif e.k == "UNLINK" then kind, det = L["Twink-Zuordnung gelöst"], tostring(d.c)
			elseif e.k == "CHURCH" then kind, det = d.o and L["Kirchenaustritt"] or L["Kirchen-Wiedereintritt"], LF("%s, ab %s", tostring(d.a), GS:WeekLabel(tonumber(d.w) or 0))
			elseif e.k == "GOAL" then kind, det = L["Sparziel angelegt"], tostring(d.n) .. ": " .. GS:FormatMoney(tonumber(d.v) or 0)
			elseif e.k == "GOALX" then kind, det = L["Sparziel entfernt"], tostring(d.id)
			elseif e.k == "TCORR" then kind, det = L["Steuerposten korrigiert"], tostring(d.a) .. ", " .. GS:WeekLabel(tonumber(d.w) or 0) .. ", "
				.. L[GS.TCORR_FIELDS[d.f] or tostring(d.f)] .. (tonumber(d.id) and (" " .. GS:ItemLabel(tonumber(d.id))) or "")
				.. ": " .. GS:FormatMoney(tonumber(d.v) or 0) .. " " .. L[d.n or ""]
			elseif e.k == "CORR" then kind, det = L["Korrekturbuchung"], tostring(d.a) .. ": " .. GS:FormatMoney(tonumber(d.v) or 0) .. " " .. (d.n or "")
			elseif e.k == "VAL" then kind, det = L["Item-Wert festgesetzt"], GS:FormatMoney(tonumber(d.v) or 0) .. " (" .. tostring(d.k) .. ")"
			elseif e.k == "WAIVE" then kind, det = L["Erlass (Hinterziehung)"], tostring(d.a) .. ", " .. GS:WeekLabel(tonumber(d.w) or 0)
			elseif e.k == "DEFER" then kind, det = L["Stundung"], LF("%s, %s bis %s", tostring(d.a), GS:WeekLabel(tonumber(d.w) or 0), date(L["%d.%m."], GS:WeekStart((tonumber(d.u) or 0) + 1)))
			elseif e.k == "OBJ" then kind, det = L["Einspruch eingelegt"], tostring(d.a) .. ", " .. GS:WeekLabel(tonumber(d.w) or 0) .. LF(": „%s“", tostring(d.t))
			elseif e.k == "OBJR" then kind, det = L["Einspruch bearbeitet"], L[tostring(d.r)] .. (type(d.t) == "string" and LF(": „%s“", d.t) or "")
			end
			if e.k ~= "WAIVE" or GS:CanSeeEvasion() then
				list[#list + 1] = { e.tm, e.au, kind or e.k, det or "" }
			end
		end
		table.sort(list, function(a, b) return a[1] > b[1] end)
		local rows = {}
		for i, x in ipairs(list) do
			rows[#rows + 1] = { GS:FormatTime(x[1]), x[2], x[3], x[4], key = i }
		end
		tbl:SetRows(rows)
	end
end

---------------------------------------------------------------------------
-- Slash-Befehle und Login-Hinweis
---------------------------------------------------------------------------
SLASH_FINANZAMT1 = "/gst"
SLASH_FINANZAMT2 = "/steuer"
SLASH_FINANZAMT3 = "/finanzamt"
SlashCmdList.FINANZAMT = function(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		UI:Toggle()
	elseif cmd == "main" then
		if arg == "" then
			GS:MyChar().main = nil
			GS:Print(L["Main-Zuordnung entfernt."])
		else
			GS:MyChar().main = arg:sub(1, 1):upper() .. arg:sub(2)
			GS:Print(LF("Main beansprucht: %s (wartet auf Bestätigung durch einen Offizier).", GS:MyChar().main))
		end
		GS:SendHeartbeat()
	elseif cmd == "sync" then
		local ok, res = GS:ForceSync()
		if ok then
			GS:Print(LF("Aktualisierung angefordert – %s Mitglied(er) mit Addon online.", tostring(res)))
		else
			GS:Print(L[res])
		end
	elseif cmd == "scan" then
		local ok, err = GS:StartScan()
		GS:Print(ok and L["AH-Scan gestartet ..."] or L[err])
	elseif cmd == "status" then
		local a = GS:G() and GS:AccountFor(GS.player)
		if a then
			GS:Print(LF("Saldo %s, Status %s, laufende Woche voraussichtlich %s.", SignedMoney(a.bal), GS:ColorStatus(a.status), Money(a.cur.total)))
		end
		local ss = GS.sendStats
		if ss then GS:Print(LF("Sync-Versand: %d gesendet, %d gedrosselt (wiederholt), %d verworfen, %d Fehler.", ss.sent, ss.throttled, ss.dropped, ss.errors)) end
	elseif cmd == "debug" then
		GS.debug = not GS.debug
		GS.db.debug = GS.debug or nil -- bleibt über /reload und Neustart erhalten
		GS:Print(GS.debug and L["Debug an (bleibt nach /reload aktiv, /gst debug schaltet aus)"] or L["Debug aus"])
	elseif cmd == "beute" or cmd == "loot" then
		local opt = (arg or ""):lower()
		if opt == "kurz" or opt == "short" then
			GS.db.lootTaxMsg, GS.db.lootTaxDetail = true, false
		elseif opt == "lang" or opt == "long" then
			GS.db.lootTaxMsg, GS.db.lootTaxDetail = true, true
		elseif opt == "an" or opt == "on" then
			GS.db.lootTaxMsg = true
		elseif opt == "aus" or opt == "off" then
			GS.db.lootTaxMsg = false
		else
			GS.db.lootTaxMsg = (GS.db.lootTaxMsg == false)
		end
		GS:Print(LF("Steuer in Loot-Meldungen: %s.", GS.db.lootTaxMsg == false and L["aus"]
			or (GS.db.lootTaxDetail and L["an (ausführlich mit Restfreibetrag)"] or L["an (kurz)"])))
		UI:Refresh()
	elseif cmd == "bescheid" or cmd == "assessment" then
		GS:ShowNotice()
	elseif cmd == "export" then
		local opt = (arg or ""):lower()
		if opt == "gilde" or opt == "guild" then GS:ShowExport(GS:ExportGuildText()) else GS:ShowExport(GS:ExportAccountText(GS:AccountOf(GS.player))) end
	elseif cmd == "tilgen" or cmd == "pay" then
		GS:PayTaxes()
	elseif cmd == "neu" or cmd == "new" then
		local all = {}
		for _, c in ipairs(GS.CHANGES or {}) do if c.num <= GS.VERSION_NUM then all[#all + 1] = c end end
		GS:ShowChanges(all)
	elseif cmd == "fenster" or cmd == "window" then
		GS.db.window = nil
		if UI.ResetWindow then UI.ResetWindow() end
		GS:Print(L["Fenstergröße und -position zurückgesetzt."])
	elseif cmd == "erfolgtest" then
		GS:TestAchToast()
	elseif cmd == "erfolgchat" then
		local opt = (arg or ""):lower()
		if opt == "senden" or opt == "send" then GS:TestAchChatSend() else GS:TestAchChat() end
	elseif cmd == "erfolge" or cmd == "achievements" then
		UI.ShowAchievements()
	elseif cmd == "minimap" then
		GS:ToggleMinimapButton()
	elseif cmd == "info" then
		GS:RankDiagnose()
	elseif cmd == "sprache" or cmd == "lang" or cmd == "language" then
		local lang = (arg or ""):lower()
		if lang == "deutsch" or lang == "german" then lang = "de" elseif lang == "english" or lang == "englisch" then lang = "en" end
		if lang == "de" or lang == "en" then
			GS:SetLang(lang, true)
		else
			GS:ShowLangPicker()
		end
	else
		GS:Print(L["Befehle: /gst (Fenster), /gst main <Name>, /gst status, /gst sync, /gst scan, /gst info, /gst bescheid, /gst export [gilde], /gst tilgen, /gst beute [kurz|lang|aus], /gst minimap, /gst fenster, /gst neu, /gst erfolge, /gst erfolgtest, /gst erfolgchat [senden], /gst debug"])
	end
end

GS:Register("GUILD_READY", function()
	C_Timer.After(40, function()
		local a = GS:G() and GS:AccountFor(GS.player)
		if not a then return end
		if a.status == "überfällig" then
			GS:Print(LF("|cffff4040Deine Gildensteuer ist überfällig!|r Saldo: %s – bitte in die Gildenbank einzahlen. (/gst)", SignedMoney(a.bal)))
		elseif a.status == "offen" then
			GS:Print(LF("Offene Gildensteuer: %s – fällig bis zum nächsten Reset. (/gst)", Money(-a.bal)))
		end
	end)
end)
