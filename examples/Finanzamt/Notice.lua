-- Finanzamt – Steuerbescheid, Einspruch, Erlass/Stundung, Export
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local UI = GS.UI

---------------------------------------------------------------------------
-- Aktionen (Verwaltungsbuchungen, werden an die Gilde verteilt)
---------------------------------------------------------------------------
function GS:Waive(main, week)
	return self:CreateADM("WAIVE", { a = main, w = week })
end

function GS:Defer(main, week, untilWeek)
	return self:CreateADM("DEFER", { a = main, w = week, u = untilWeek })
end

function GS:FileObjection(week, text)
	text = UI.Trim(text or ""):sub(1, 200)
	if text == "" then return false, L["Bitte eine Begründung angeben."] end
	return self:CreateADM("OBJ", { a = self:AccountOf(self.player), w = week, t = text })
end

function GS:ResolveObjection(id, decision, reason)
	reason = UI.Trim(reason or ""):sub(1, 250)
	if reason == "" then return false, L["Bitte eine Begründung für den Spieler eingeben."] end
	return self:CreateADM("OBJR", { id = id, r = decision, t = reason })
end

---------------------------------------------------------------------------
-- Antwort auf einen Einspruch: dem Spieler anzeigen, bis er sie als gelesen markiert
-- (gespeichert accountweit, damit die Meldung auf allen Charakteren des Kontos erscheint)
---------------------------------------------------------------------------
function GS:UnreadObjectionReplies()
	local out = {}
	if not self.db or not self:G() then return out end
	local a = self:AccountFor(self.player)
	local seen = self.db.objSeen or {}
	for _, o in ipairs(a and a.objections or {}) do
		if o.resolved and not seen[o.id] then out[#out + 1] = o end
	end
	table.sort(out, function(x, y) return (x.resolvedAt or 0) < (y.resolvedAt or 0) end)
	return out
end

function GS:MarkObjectionRead(id)
	self.db.objSeen = self.db.objSeen or {}
	self.db.objSeen[id] = true
end

function GS:ObjectionReplyText(o)
	local lines = {
		L["Finanzamt – Antwort auf deinen Einspruch"],
		"",
		LF("Steuerbescheid %s: %s", self:WeekLabel(o.week), GS.ObjectionState(o)) .. (o.resolvedBy and LF(" von %s", o.resolvedBy) or ""),
		"",
		LF("Begründung: %s", o.reason or L["|cffaaaaaa(keine Begründung angegeben)|r"]),
		"",
		LF("|cffaaaaaaDein Einspruch: „%s“|r", o.text or ""),
	}
	return table.concat(lines, "\n")
end

-- nächste ungelesene Antwort anzeigen (eine nach der anderen)
function GS:ShowObjectionReplies()
	if self._objPopupOpen then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	local o = self:UnreadObjectionReplies()[1]
	if not o or (self._objLater and self._objLater[o.id]) then return end
	if not StaticPopupDialogs.FINANZAMT_OBJREPLY then
		StaticPopupDialogs.FINANZAMT_OBJREPLY = {
			text = "%s",
			button1 = L["Gelesen"],
			button2 = L["Später"],
			OnAccept = function(_, data)
				GS._objPopupOpen = false
				GS:MarkObjectionRead(data)
				GS:Fire("DATA_CHANGED")
				C_Timer.After(0.5, function() GS:ShowObjectionReplies() end)
			end,
			OnCancel = function(_, data)
				GS._objPopupOpen = false
				-- „Später“: in dieser Sitzung nicht mehr nachfragen, beim nächsten Login wieder
				GS._objLater = GS._objLater or {}
				GS._objLater[data] = true
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	self._objPopupOpen = true
	local dlg = StaticPopup_Show("FINANZAMT_OBJREPLY", self:ObjectionReplyText(o))
	if dlg then dlg.data = o.id else self._objPopupOpen = false end
end

GS:Register("GUILD_READY", function()
	C_Timer.After(30, function() GS:ShowObjectionReplies() end)
end)
GS:Register("DATA_CHANGED", function()
	if GS._objCheckPending then return end
	GS._objCheckPending = true
	C_Timer.After(3, function()
		GS._objCheckPending = false
		GS:ShowObjectionReplies()
	end)
end)

function GS:ObjectionFor(a, week)
	local list = a and a.objections or {}
	for i = #list, 1, -1 do
		if list[i].week == week then return list[i] end
	end
end

local function objectionState(o)
	if not o then return nil end
	if not o.resolved then return L["|cffffd100offen|r"] end
	if o.decision == "angenommen" then return L["|cff40ff40angenommen|r"] end
	if o.decision == "abgelehnt" then return L["|cffff4040abgelehnt|r"] end
	return L["erledigt"]
end
GS.ObjectionState = objectionState

---------------------------------------------------------------------------
-- Export (Text für Discord, als Codeblock)
---------------------------------------------------------------------------
local function P(c) return GS:FormatMoney(c, true) end

local function weekPlain(lines, c, week, label)
	lines[#lines + 1] = LF("%s (%s)", label, GS:WeekLabel(week))
	lines[#lines + 1] = LF("  Loot %s | Quests %s | Händler %s", P(c.loot), P(c.quest), P(c.vendor))
		.. ((c.buyback or 0) > 0 and LF(" (nach Rückkauf %s)", P(c.buyback)) or "")
	if (c.ahFees or 0) > 0 or (c.ahRefund or 0) > 0 or (c.ahCarryIn or 0) > 0 then
		lines[#lines + 1] = LF("  AH-Verkäufe %s | Anzahlungen %s gezahlt, %s zurück", P(c.ah), P(c.ahFees or 0), P(c.ahRefund or 0))
			.. ((c.ahCarryIn or 0) > 0 and LF(" | Verlustvortrag %s", P(c.ahCarryIn)) or "") .. LF(" = AH-Gewinn %s", P(c.ahNet or 0))
	else
		lines[#lines + 1] = LF("  AH-Erlöse %s", P(c.ah))
	end
	lines[#lines + 1] = LF("  Werbungskosten: tatsächlich %s, angesetzt %s", P(c.wkActual), P(c.wkEff))
	if (c.evasion or 0) > 0 then
		if GS:CanSeeEvasion() then
			lines[#lines + 1] = LF("  Ohne Addon eingenommen (nachversteuert): %s", P(c.evasion))
		else
			lines[#lines + 1] = LF("  Nachschätzung: %s", P(c.evasion + (c.penalty or 0)))
		end
	end
	if (c.waived or 0) > 0 and GS:CanSeeEvasion() then lines[#lines + 1] = LF("  Erlassen: %s", P(c.waived)) end
	lines[#lines + 1] = LF("  Zu versteuern: %s", P(c.taxable))
	lines[#lines + 1] = LF("  ESt %s + Soli %s + USt %s + GewSt %s", P(c.est), P(c.soli), P(c.ust), P(c.gew))
		.. ((c.dog or 0) > 0 and LF(" + Hundesteuer %s", P(c.dog)) or "")
		.. ((c.church or 0) > 0 and LF(" + Kirchensteuer %s", P(c.church)) or "")
		.. ((c.alc or 0) > 0 and LF(" + Alkoholsteuer %s", P(c.alc)) or "")
		.. ((c.mount or 0) > 0 and LF(" + Reittiersteuer %s", P(c.mount)) or "")
		.. ((c.penalty or 0) > 0 and LF(" + Zuschlag %s", P(c.penalty)) or "")
	lines[#lines + 1] = LF("  Steuer: %s", P(c.total)) .. (c.small and L[" (Kleinbetrag, entfällt)"] or "")
		.. (c.deferredUntil and LF(" (gestundet bis %s)", GS:WeekLabel(c.deferredUntil)) or "")
end

function GS:ExportAccountText(main)
	local calc = self:Calc()
	local a = calc.accounts[main]
	if not a then return L["Kein Konto gefunden."] end
	local cur = calc.week
	local twinks = {}
	for _, ch in ipairs(a.chars) do if ch ~= a.main then twinks[#twinks + 1] = ch end end
	local lines = {
		L["Finanzamt – Steuerbescheid"],
		LF("Konto: %s", a.main) .. (#twinks > 0 and LF(" (Twinks: %s)", table.concat(twinks, ", ")) or ""),
		LF("Saldo: %s – %s", P(a.bal), L[a.status]),
		"",
	}
	if a.weeks[cur - 1] then
		weekPlain(lines, a.weeks[cur - 1], cur - 1, L["Letzte Woche"])
		lines[#lines + 1] = LF("  Fällig bis: %s", date("%d.%m. %H:%M", self:WeekStart(cur + (self:GetLatest("tariff").dueWeeks or 1))))
			.. ((a.bal >= 0 and (a.weeks[cur - 1].total or 0) > 0) and L[" (aus dem Guthaben gedeckt)"] or "")
		lines[#lines + 1] = ""
	end
	weekPlain(lines, a.cur, cur, L["Laufende Woche (voraussichtlich)"])
	return "```\n" .. table.concat(lines, "\n") .. "\n```"
end

local function pad(s, n)
	s = tostring(s)
	local len = #s:gsub("[\128-\191]", "") -- UTF-8: Umlaute zählen einfach
	if len >= n then return s end
	return s .. string.rep(" ", n - len)
end
local function lpad(s, n)
	s = tostring(s)
	if #s >= n then return s end
	return string.rep(" ", n - #s) .. s
end

function GS:ExportGuildText()
	local calc = self:Calc()
	local all = self:HasRight(self.player, "viewall")
	local own = self:AccountOf(self.player)
	local list = {}
	for main, a in pairs(calc.accounts) do
		if all or main == own then list[#list + 1] = a end
	end
	local order = { ["überfällig"] = 1, ["offen"] = 2, ["quitt"] = 3 }
	table.sort(list, function(x, y)
		local ox, oy = order[x.status] or 9, order[y.status] or 9
		if ox ~= oy then return ox < oy end
		return x.main < y.main
	end)
	local lines = {
		LF("Finanzamt – Gildenübersicht %s", date("%d.%m.%Y")),
		"",
		pad(L["Konto"], 22) .. lpad(L["Saldo"], 14) .. "  " .. pad(L["Status"], 12) .. lpad(L["Steuer letzte W."], 18),
		string.rep("-", 68),
	}
	local nq, no, nu, sumTax = 0, 0, 0, 0
	for _, a in ipairs(list) do
		local last = a.weeks[calc.week - 1]
		local tax = last and last.total or 0
		sumTax = sumTax + tax
		lines[#lines + 1] = pad(a.main, 22) .. lpad(P(a.bal), 14) .. "  " .. pad(L[a.status], 12) .. lpad(P(tax), 18)
		if a.status == "quitt" then nq = nq + 1 elseif a.status == "offen" then no = no + 1 else nu = nu + 1 end
	end
	lines[#lines + 1] = string.rep("-", 68)
	lines[#lines + 1] = LF("%d Konten: %d quitt, %d offen, %d überfällig – Steuern letzte Woche gesamt: %s",
		#list, nq, no, nu, P(sumTax))
	return "```\n" .. table.concat(lines, "\n") .. "\n```"
end

---------------------------------------------------------------------------
-- Export-Fenster (Text markieren und mit Strg+C kopieren)
---------------------------------------------------------------------------
local exportFrame

local function dialogBackdrop(f)
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
	end
end

local function makeMovable(f)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
end

function GS:ShowExport(text)
	if not exportFrame then
		local f = CreateFrame("Frame", "FinanzamtExportFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(560, 400)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		dialogBackdrop(f)
		makeMovable(f)
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -16)
		title:SetText(L["Export – markieren und mit Strg+C kopieren"])
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -6, -6)
		local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 20, -40)
		sf:SetPoint("BOTTOMRIGHT", -38, 46)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		eb:SetWidth(490)
		eb:SetScript("OnEscapePressed", function() f:Hide() end)
		sf:SetScrollChild(eb)
		f.eb = eb
		local bSel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		bSel:SetSize(140, 22)
		bSel:SetPoint("BOTTOMLEFT", 20, 16)
		bSel:SetText(L["Alles markieren"])
		bSel:SetScript("OnClick", function() eb:SetFocus(); eb:HighlightText() end)
		local bClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		bClose:SetSize(110, 22)
		bClose:SetPoint("BOTTOMRIGHT", -20, 16)
		bClose:SetText(L["Schließen"])
		bClose:SetScript("OnClick", function() f:Hide() end)
		tinsert(UISpecialFrames, "FinanzamtExportFrame")
		f:Hide()
		exportFrame = f
		UI.exportFrame = f
	end
	exportFrame.eb:SetText(text or "")
	exportFrame:Show()
	exportFrame.eb:SetFocus()
	exportFrame.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Steuerbescheid
---------------------------------------------------------------------------
local notice
local pendingNotice

local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function objectionPopup(week)
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	if not StaticPopupDialogs.FINANZAMT_OBJECTION then
		local function accept(self, data)
			local eb = self.editBox or self.EditBox
			local ok, err = GS:FileObjection(data, eb and eb:GetText() or "")
			if ok then
				GS:Print(L["Einspruch eingelegt – die Offiziere sehen ihn unter „Auffälligkeiten“."])
			else
				GS:Print(err)
			end
		end
		StaticPopupDialogs.FINANZAMT_OBJECTION = {
			text = L["Einspruch gegen den Steuerbescheid\n%s\n\nBegründung:"],
			button1 = L["Einlegen"],
			button2 = L["Abbrechen"],
			hasEditBox = 1,
			maxLetters = 200,
			OnAccept = accept,
			EditBoxOnEnterPressed = function(self)
				local parent = self:GetParent()
				accept(parent, parent.data)
				parent:Hide()
			end,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show("FINANZAMT_OBJECTION", GS:WeekLabel(week), nil, week)
end
GS.ObjectionPopup = objectionPopup

local function createNotice()
	local f = CreateFrame("Frame", "FinanzamtNoticeFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(460, 420)
	f:SetPoint("CENTER", 0, 40)
	f:SetFrameStrata("DIALOG")
	dialogBackdrop(f)
	makeMovable(f)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -18)
	title:SetText(L["Steuerbescheid"])
	UI.HelpButton(f, 20, -14)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("TOPLEFT", 24, -48)
	f.text:SetWidth(412)
	f.text:SetJustifyH("LEFT")
	f.text:SetJustifyV("TOP")
	if f.text.SetSpacing then f.text:SetSpacing(3) end

	local function btn(label, w, x, fn)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(w, 22)
		b:SetPoint("BOTTOMLEFT", x, 18)
		b:SetText(label)
		b:SetScript("OnClick", fn)
		return b
	end
	f.bPay = btn(L["Jetzt tilgen"], 104, 20, function() GS:PayTaxes() end)
	f.bPay:SetScript("OnEnter", function(self)
		if not GS.bankOpen then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(L["Zum Tilgen die Gildenbank öffnen."], 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	f.bPay:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.bObj = btn(L["Einspruch"], 100, 128, function() objectionPopup(f.week) end)
	f.bExp = btn(L["Exportieren"], 104, 232, function() GS:ShowExport(GS:ExportAccountText(GS:AccountOf(GS.player))) end)
	f.bClose = btn(L["Schließen"], 100, 340, function() f:Hide() end)
	tinsert(UISpecialFrames, "FinanzamtNoticeFrame")
	f:Hide()
	UI.noticeFrame = f
	return f
end

function GS:RenderNotice()
	if not notice or not self:G() then return end
	local calc = self:Calc()
	local main = self:AccountOf(self.player)
	local a = calc.accounts[main]
	local week = notice.week
	local lines = {}
	if not a then
		lines[1] = L["Kein Konto gefunden."]
	else
		local twinks = {}
		for _, ch in ipairs(a.chars) do if ch ~= a.main then twinks[#twinks + 1] = ch end end
		lines[#lines + 1] = LF("|cffffd100Konto:|r %s", a.main) .. (#twinks > 0 and LF("  (Twinks: %s)", table.concat(twinks, ", ")) or "")
		lines[#lines + 1] = " "
		local ov = self:WeekOverview(a.main, week)
		if ov then
			lines[#lines + 1] = L["|cffffd100Deine Woche im Überblick|r"]
			for _, l in ipairs(ov) do lines[#lines + 1] = "  " .. l end
			lines[#lines + 1] = " "
		end
		local res = a.weeks[week]
		if res then
			UI.AppendWeekLines(lines, res, week, true)
			if week < calc.week then
				local dueW = week + 1 + (self:GetLatest("tariff").dueWeeks or 1)
				lines[#lines + 1] = LF("  Fällig bis: %s", date("%d.%m. %H:%M", self:WeekStart(res.deferredUntil and (res.deferredUntil + 1) or dueW)))
					.. ((a.bal >= 0 and res.total > 0) and L[" |cff40ff40– aus dem Guthaben gedeckt|r"] or "")
			end
		else
			lines[#lines + 1] = LF("|cffaaaaaaFür %s liegen keine Steuerdaten vor.|r", self:WeekLabel(week))
		end
		lines[#lines + 1] = " "
		lines[#lines + 1] = LF("|cffffd100Kontostand:|r %s   |cffffd100Status:|r %s", self:FormatMoney(a.bal), self:ColorStatus(a.status))
		local pay = self:PaymentLine(a)
		if pay then lines[#lines + 1] = pay end
		local zl = self:InterestLine(a)
		if zl then
			for l in (zl .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
		end
		local o = self:ObjectionFor(a, week)
		if o then
			lines[#lines + 1] = " "
			lines[#lines + 1] = LF("|cffffd100Einspruch:|r %s – „%s“", objectionState(o), o.text)
				.. (o.resolvedBy and LF(" (bearbeitet von %s)", o.resolvedBy) or "")
			if o.reason then lines[#lines + 1] = LF("|cffffd100Begründung:|r %s", o.reason) end
		end
		if notice.bObj.SetEnabled then notice.bObj:SetEnabled(res ~= nil and not (o and not o.resolved)) end
		if notice.bPay.SetEnabled then notice.bPay:SetEnabled(GS.bankOpen and (self:OutstandingTaxes() or 0) > 0) end
	end
	notice.text:SetText(table.concat(lines, "\n"))
	-- Fensterhöhe an den Text anpassen (Überblick + Bescheid können lang werden)
	local th = tonumber(notice.text.GetStringHeight and notice.text:GetStringHeight())
	if th then notice:SetHeight(math.max(420, math.floor(th) + 48 + 56)) end
end

function GS:ShowNotice(week)
	if not self:G() then
		self:Print(L["Keine Gildendaten."])
		return
	end
	week = week or (self:CurrentWeek() - 1)
	if inCombat() then
		pendingNotice = week
		self:Print(L["Im Kampf – der Steuerbescheid öffnet sich nach dem Kampf."])
		return
	end
	if not notice then notice = createNotice() end
	notice.week = week
	self:RenderNotice()
	notice:Show()
end

-- nach dem Reset einmal automatisch anzeigen
function GS:MaybeShowNotice()
	if not self:G() or self.db.noticeAuto == false or not self.db.lang then return end
	local cur = self:CurrentWeek()
	local c = self:MyChar()
	if c.noticeWeek == cur - 1 then return end
	local a = self:AccountFor(self.player)
	if not a or not a.weeks[cur - 1] then return end
	-- einmal pro Konto: wurde der Bescheid schon auf einem anderen Charakter des Kontos gezeigt?
	local g = self:G()
	g.noticeSeen = g.noticeSeen or {}
	c.noticeWeek = cur - 1
	if g.noticeSeen[a.main] == cur - 1 then return end
	g.noticeSeen[a.main] = cur - 1
	self:ShowNotice(cur - 1)
end

GS:Register("GUILD_READY", function()
	-- nach Sync und Hinterziehungs-Prüfung
	C_Timer.After(55, function() GS:MaybeShowNotice() end)
end)
GS:Register("STATUS_CHANGED", function()
	if GS.g and GS._noticeReady then GS:MaybeShowNotice() end
end)
GS:Register("GUILD_READY", function() C_Timer.After(56, function() GS._noticeReady = true end) end)
GS:Register("DATA_CHANGED", function()
	if notice and notice:IsShown() then GS:Debounce("notice", 0.5, function() GS:RenderNotice() end) end
end)
GS:On("PLAYER_REGEN_ENABLED", function()
	if pendingNotice then
		local w = pendingNotice
		pendingNotice = nil
		GS:ShowNotice(w)
	end
end)

---------------------------------------------------------------------------
-- Erinnerung vor der Fälligkeit (letzte 24 Stunden, höchstens alle 6 Stunden)
---------------------------------------------------------------------------
function GS:CheckDueReminder()
	if not self:G() or self.db.reminders == false then return end
	local due = self:OutstandingTaxes()
	if due <= 0 then return end
	local a = self:AccountFor(self.player)
	if not a or a.status == "überfällig" then return end -- dafür gibt es die Login-Warnung
	local cur = self:CurrentWeek()
	local dueAt = self:WeekStart(cur + (self:GetLatest("tariff").dueWeeks or 1))
	local left = dueAt - self:Now()
	if left <= 0 or left > 86400 then return end
	local c = self:MyChar()
	local key = cur .. ":" .. math.floor(left / 21600)
	if c.dueReminded == key then return end
	c.dueReminded = key
	self:Print(LF("|cffffd100Erinnerung:|r Deine Gildensteuer von %s ist bis %s fällig (noch %d Std.). Tilgen: Gildenbank öffnen oder /gst tilgen.", self:FormatMoney(due), date("%d.%m. %H:%M", dueAt), math.max(1, math.floor(left / 3600))))
end

GS:Register("GUILD_READY", function() C_Timer.After(60, function() GS:CheckDueReminder() end) end)
GS:Register("STATUS_CHANGED", function()
	if GS._noticeReady then GS:Debounce("duereminder", 5, function() GS:CheckDueReminder() end) end
end)

---------------------------------------------------------------------------
-- Twinks automatisch erkennen: andere Charaktere dieses WoW-Accounts in derselben Gilde
---------------------------------------------------------------------------
function GS:AccountCharsInGuild()
	local db, list, seen = self.db, {}, {}
	local myGUID = UnitGUID and UnitGUID("player")
	if not db or not self.guildKey then return list end
	local function add(name)
		if name and name ~= self.player and not seen[name] and self.roster[name] then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	-- Charaktere, die auf diesem Rechner/Account schon mit Addon eingeloggt waren
	for guid, key in pairs(db.guildByGUID or {}) do
		if key == self.guildKey and guid ~= myGUID then add(db.names and db.names[guid]) end
	end
	-- Charaktere mit derselben Account-Kennung im Heartbeat (auch von anderen Rechnern)
	local g = self:G()
	if g and db.accountToken then
		for name, st in pairs(g.status) do
			if st.ak == db.accountToken then add(name) end
		end
	end
	table.sort(list)
	return list
end

-- Auswahl für das Main-Feld: Gildenmitglieder, Charaktere desselben WoW-Accounts zuerst, dann Mains, dann alle
function GS:MainCandidates()
	local out = {}
	if not self:G() then return out end
	local same = {}
	for _, n in ipairs(self:AccountCharsInGuild()) do same[n] = true end
	local links = self:Links()
	local isMain = {}
	for _, m in pairs(links) do isMain[m] = true end
	for name, info in pairs(self.roster or {}) do
		if name ~= self.player then
			local hint, prio = nil, 3
			if links[name] then
				hint, prio = LF("Twink von %s", self:AccountOf(name)), 4
			elseif isMain[name] then
				hint, prio = L["Main"], 2
			end
			if same[name] then
				hint = L["|cff40ff40gleicher WoW-Account|r"] .. (hint and (" · " .. hint) or "")
				prio = 1
			end
			out[#out + 1] = { name = name, level = info.level, hint = hint, prio = prio }
		end
	end
	table.sort(out, function(a, b)
		if a.prio ~= b.prio then return a.prio < b.prio end
		return a.name < b.name
	end)
	return out
end

function GS:SuggestMain()
	if not self:G() or not self.rosterLoaded then return nil end
	local c = self:MyChar()
	local links = self:Links()
	if c.main or c.noAutoTwink or links[self.player] then return nil end
	-- dieser Charakter ist selbst schon bestätigter Main anderer Twinks
	for _, m in pairs(links) do if m == self.player then return nil end end
	local others = self:AccountCharsInGuild()
	-- 1. Auf diesem Account gibt es schon ein bestätigtes Konto (Main mit Twinks): dessen Main vorschlagen
	local confirmed = {}
	for _, name in ipairs(others) do
		local main = self:AccountOf(name)
		local isMain = false
		for _, m in pairs(links) do if m == name then isMain = true break end end
		if links[name] or isMain then
			if main ~= self.player then confirmed[main] = true end
		end
	end
	local list = {}
	for m in pairs(confirmed) do list[#list + 1] = m end
	table.sort(list)
	if #list > 0 then return list[1] end
	-- 2. sonst: Charakter mit dem höchsten Level, wenn er mindestens so hoch ist wie dieser
	local myLevel = self:CharLevel(self.player) or 0
	local best, bestLevel
	for _, name in ipairs(others) do
		local lvl = (self.roster[name] and self.roster[name].level) or 0
		if not best or lvl > bestLevel then best, bestLevel = name, lvl end
	end
	if best and bestLevel >= myLevel then return best end
	return nil
end

function GS:MaybeAskTwink()
	local main = self:SuggestMain()
	if not main or self._twinAsked then return end
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	if InCombatLockdown and InCombatLockdown() then return end
	self._twinAsked = true
	if not StaticPopupDialogs.FINANZAMT_TWINK then
		StaticPopupDialogs.FINANZAMT_TWINK = {
			text = L["Finanzamt\n\n%s ist auf demselben WoW-Account in der Gilde.\nIst dieser Charakter ein Twink von %s?\n\n(Main und Twinks teilen sich ein Steuerkonto. Ein Offizier bestätigt die Zuordnung.)"],
			button1 = L["Ja, Twink"],
			button2 = L["Nein"],
			OnAccept = function(_, data)
				GS:MyChar().main = data
				GS:SendHeartbeat()
				GS:Print(LF("Als Twink von %s gemeldet – wartet auf Bestätigung durch einen Offizier.", data))
				GS:Fire("DATA_CHANGED")
			end,
			OnCancel = function(_, _, reason)
				if reason == "clicked" then GS:MyChar().noAutoTwink = true end
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show("FINANZAMT_TWINK", main, main, main)
end

GS:Register("ROSTER", function(first)
	if first then C_Timer.After(25, function() GS:MaybeAskTwink() end) end
end)
