-- Finanzamt – Erfassung des eigenen Einkommens und der Werbungskosten
--
-- Jede Goldänderung (PLAYER_MONEY) wird anhand des Kontexts eingeordnet:
--   Loot (Lootfenster/Geld-Chatmeldung), Quest (Abgabe), Händler (Verkauf), AH (Verkaufs-Post)
--   Handel, Spieler-Post und Gildenbank sind steuerfrei.
--   Händlerkäufe, AH-Käufe und Reparaturen werden auf Werbungskosten geprüft.
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF

local ctx = {}
local claims = {}
local lastMoney
local recentMail = {}

local function now() return GetTime() end

local function addClaim(c)
	c.created = now()
	c.expires = c.created + (c.ttl or 5)
	claims[#claims + 1] = c
end

local function cleanClaims()
	local t = now()
	local mailOpen = GS.MailOpen and GS.MailOpen()
	for i = #claims, 1, -1 do
		local c = claims[i]
		-- Post-Geld kann bei Lag deutlich später ankommen: solange der Briefkasten offen ist, bis zu 5 Minuten warten
		local keep = c.kind == "mail" and mailOpen and (t - c.created) < 300
		if c.expires < t and not keep then table.remove(claims, i) end
	end
end

---------------------------------------------------------------------------
-- Eigener Wochenbericht
---------------------------------------------------------------------------
function GS:OwnReport()
	local g = self:G()
	if not g then return nil end
	local r = g.reports[self.player]
	if not r then
		r = { seq = 0, w = {} }
		g.reports[self.player] = r
	end
	return r
end

function GS:OwnWeek()
	local r = self:OwnReport()
	if not r then return nil end
	if self.FlushDeferred and not self._flushing then
		self._flushing = true
		self:FlushDeferred()
		self._flushing = false
	end
	local w = self:CurrentWeek()
	local d = r.w[w]
	if not d then
		d = { l = 0, q = 0, v = 0, a = 0, k = 0, x = 0, e = 0, r = 0, f = 0, o = 0, m = 0, mc = 0, kc = 0, al = 0, mt = 0, mr = 0, i = {}, mi = {}, ci = {}, s = 0 }
		r.w[w] = d
	end
	return d, r
end

function GS:TouchOwn()
	local d, r = self:OwnWeek()
	if not d then return end
	r.seq = r.seq + 1
	d.s = r.seq
	d.u = self:Now() -- Zeitpunkt der letzten Änderung (für den Datenstand bei den anderen)
	self:Invalidate()
	self:Fire("DATA_CHANGED")
	self:ScheduleOwnBroadcast()
end

-- Ereignisprotokoll (nur lokal, pro Charakter, die letzten 200 Einträge)
-- k: l Loot, q Quest, v Händlerverkauf, a AH-Verkauf, wk Werbungskosten-Kauf, rep Reparatur,
--    rb Rückkauf, dep AH-Anzahlung, x Hinterziehung, pay Steuer getilgt,
--    o sonstiger Eingang (steuerfrei), pm Spieler-Post, tr Handel, xc Nachschätzung nach Absturz,
--    mat Wareneinsatz (Handwerkswaren für den AH-Handel)
local MERGE_KINDS = { l = true, v = true, dep = true, o = true }
function GS:LogEvent(kind, amount, extra)
	if not self.db or not amount or amount <= 0 then return end
	local c = self:MyChar()
	c.events = c.events or {}
	local now = self:Now()
	local last = c.events[#c.events]
	-- viele kleine Loot-/Verkaufs-Buchungen kurz hintereinander zu einer Zeile zusammenfassen
	if last and MERGE_KINDS[kind] and last.k == kind and (now - last.t) < 60 and not (extra and extra.id) then
		last.a = last.a + amount
		last.n = (last.n or 1) + 1
		last.t = now
	else
		local e = { t = now, k = kind, a = amount }
		if extra then for key, v in pairs(extra) do e[key] = v end end
		table.insert(c.events, e)
		while #c.events > 200 do table.remove(c.events, 1) end
	end
	self:Fire("EVENTS_CHANGED")
end

-- Buchungen, die eintreffen, bevor die Gildendaten geladen sind, werden nachgeholt
local deferred = {}
function GS:DeferBooking(fn)
	if #deferred < 200 then deferred[#deferred + 1] = fn end
end
-- zurückgehaltene Buchungen ausführen (sobald die Gildendaten da sind, egal auf welchem Weg)
function GS:FlushDeferred()
	if #deferred == 0 then return end
	local list = deferred
	deferred = {}
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
end
GS:Register("GUILD_READY", function() GS:FlushDeferred() end)

function GS:AddIncome(cat, amount)
	if amount <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddIncome(cat, amount) end) end
	d[cat] = (d[cat] or 0) + amount
	-- zuletzt verbuchtes Einkommen (Loot, Quest, Händler) für die Steuer-Anzeige in Chatmeldungen
	if cat == "l" or cat == "q" or cat == "v" or cat == "a" then self.lastLoot = { amount = amount, t = GetTime(), cat = cat } end
	if cat == "v" then self.merchantSales = (self.merchantSales or 0) + amount end
	self:TouchOwn()
	self:LogEvent(cat, amount)
	if self.debug then self:Print(L["Einkommen"], cat, self:FormatMoney(amount)) end
	if cat == "q" then
		local bookedAt = GetTime()
		C_Timer.After(1.5, function() GS:QuestRewardNotice(amount, bookedAt) end)
	end
end

-- Goldeingang ohne erkennbare Quelle: bleibt steuerfrei, wird aber gezählt und mit der Gilde geteilt
function GS:AddUntaxed(amount, where)
	if not amount or amount <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddUntaxed(amount, where) end) end
	d.o = (d.o or 0) + amount
	self:TouchOwn()
	self:LogEvent("o", amount, where and { src = where } or nil)
	if self.debug then
		self:Print(LF("Sonstiger Goldeingang (steuerfrei): %s", self:FormatMoney(amount)) .. (where and (" – " .. L[where]) or ""))
	end
end

function GS:IsDeductible(itemID)
	if not itemID then return false end
	local wl = self:GetEffective("wklist", self:CurrentWeek())
	return wl.items and wl.items[itemID] and true or false
end

-- Handwerkswaren (Erze, Barren, Kräuter, Stoffe, Leder …): Einkauf zählt als Wareneinsatz gegen den AH-Gewinn
function GS:IsTradeGood(itemID)
	if not itemID then return false end
	local classID
	local inst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if inst then classID = select(6, inst(itemID)) end
	if not classID then classID = select(12, GS.GetItemInfo(itemID)) end
	local TG = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
	return classID ~= nil and classID == TG
end

function GS:AddMaterial(itemID, count, cost, source)
	if not cost or cost <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddMaterial(itemID, count, cost, source) end) end
	count = count or 1
	d.m = (d.m or 0) + cost
	d.mi = d.mi or {}
	local x = d.mi[itemID] or { 0, 0 }
	x[1] = x[1] + count
	x[2] = x[2] + cost
	d.mi[itemID] = x
	self:TouchOwn()
	self:LogEvent("mat", cost, { id = itemID, n = count, src = source })
	if self.debug then
		local _, link = GS.GetItemInfo(itemID)
		self:Print(LF("Wareneinsatz erfasst: %s x%d für %s (%s) – mindert den AH-Gewinn",
			link or self:ItemName(itemID), count, self:FormatMoney(cost), L[source or "Kauf"]))
	end
end

-- source: "Händler" oder "Auktionshaus"; cost = tatsächlich bezahlter Gesamtpreis
function GS:IsAlcohol(itemID)
	return itemID and self.ALCOHOL_ITEMS[itemID] and true or false
end

-- Alkohol-Einkauf merken (Grundlage der Alkoholsteuer)
function GS:AddAlcohol(itemID, count, cost, source)
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddAlcohol(itemID, count, cost, source) end) end
	d.al = (d.al or 0) + cost
	if itemID then -- je Getränk merken (für Erfolge wie „Feierabendbier“)
		d.ai = d.ai or {}
		local x = d.ai[itemID] or { 0, 0 }
		d.ai[itemID] = { x[1] + (count or 1), x[2] + cost }
	end
	self:TouchOwn()
	self:LogEvent("alc", cost, { id = itemID, n = count or 1, src = source })
	if self.debug then self:Print(LF("Alkohol-Einkauf erfasst: %s für %s – fällt unter die Alkoholsteuer", self:ItemName(itemID), self:FormatMoney(cost))) end
end

-- Reiten gelernt? Sprachunabhängig über Zauber-IDs und „schon einmal aufgesessen“ (keine Fertigkeitsnamen:
-- die Suche nach „reit“ traf auch „Streitkolben“). Ergebnis kurz zwischengespeichert.
GS.RIDING_SPELLS = {
	824, 825, 826, 828, 10861, 10906, 10907, 18995, -- Reitfertigkeiten der Völker (Pferd, Wolf, Widder, Tiger, Raptor, Untote, Roboschreiter, Kodo)
	33388, 33391, 34090, 34091, 90265,              -- Reiten (Lehrling bis Meister)
	13819, 23214, 34769, 34767,                     -- Paladin: Schlachtross, Streitross
	5784, 23161,                                    -- Hexenmeister: Teufelsross, Schreckensross
}
local ridingCache, ridingAt
local function spellKnown(id)
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if IsSpellKnown and IsSpellKnown(id) then return true end
	return false
end
-- sitzt der Charakter gerade auf einem Reittier? (Flugroute zählt nicht) – merkt sich das dauerhaft je Charakter
function GS:NoteMounted()
	if not IsMounted or not IsMounted() then return false end
	if UnitOnTaxi and UnitOnTaxi("player") then return false end
	local c = self.db and self.player and self:MyChar()
	if c and not c.rodeMount then
		c.rodeMount = true
		ridingAt = nil
	end
	return true
end
function GS:ResetRidingCache() ridingAt = nil end
function GS:HasRiding()
	if ridingAt and GetTime() - ridingAt >= 0 and GetTime() - ridingAt < 60 then return ridingCache end
	local found = false
	for _, id in ipairs(self.RIDING_SPELLS) do
		if spellKnown(id) then found = true break end
	end
	if not found then
		self:NoteMounted()
		local c = self.db and self.player and self.db.chars and self.db.chars[self.player]
		found = c and c.rodeMount and true or false
	end
	ridingCache, ridingAt = found, GetTime()
	return found
end

-- Spielaktivität der Woche (Grundlage der Verzugszinsen):
-- od = Bitmaske der Online-Tage (Bit 0 = erster Tag nach dem Reset), pt = Spielzeit in Sekunden
local ACT_TICK = 60
local ptUnsent = 0
function GS:DayBit(t, w)
	local day = math.floor((t - self:WeekStart(w)) / 86400)
	if day < 0 then day = 0 elseif day > 6 then day = 6 end
	return 2 ^ day
end
function GS:HasBit(mask, b) return math.floor((tonumber(mask) or 0) / b) % 2 == 1 end
function GS:NoteActivity(seconds)
	local d = self:OwnWeek()
	if not d then return end
	local b = self:DayBit(self:Now(), self:CurrentWeek())
	local changed = false
	if not self:HasBit(d.od, b) then
		d.od = (tonumber(d.od) or 0) + b
		changed = true
	end
	if seconds and seconds > 0 then
		d.pt = (tonumber(d.pt) or 0) + seconds
		ptUnsent = ptUnsent + seconds
		if ptUnsent >= 900 then changed = true end -- Spielzeit höchstens alle 15 Minuten verteilen
	end
	if changed then
		ptUnsent = 0
		self:TouchOwn()
	end
end
GS:Register("GUILD_READY", function()
	GS:NoteActivity(0)
	if not GS._actTicker then
		GS._actTicker = GS:Ticker(ACT_TICK, function() GS:NoteActivity(ACT_TICK) end)
	end
end)

-- Reiten in den Wochendaten vermerken (Grundlage der Reittiersteuer, je Charakter und Woche)
function GS:UpdateRidingFlag()
	if not self:HasRiding() then return end
	local d = self:OwnWeek()
	if not d or (d.mr or 0) >= 1 then return end
	d.mr = 1
	self:TouchOwn()
end
GS:On("SKILL_LINES_CHANGED", function() ridingAt = nil; GS:UpdateRidingFlag() end)
GS:On("SPELLS_CHANGED", function() ridingAt = nil end)
-- Aufsitzen erkennen (Reittier-Buff); nur bei Änderung neu prüfen
GS:On("UNIT_AURA", function(unit)
	if unit == "player" and GS:NoteMounted() then GS:UpdateRidingFlag() end
end)
GS:Register("GUILD_READY", function() C_Timer.After(5, function() GS:UpdateRidingFlag() end) end)

function GS:AddPurchase(itemID, count, cost, source)
	if not cost or cost <= 0 then return end
	if self:IsAlcohol(itemID) then self:AddAlcohol(itemID, count, cost, source) end
	if not self:IsDeductible(itemID) then
		-- nicht auf der Werbungskosten-Liste: Handwerkswaren zählen als Wareneinsatz
		if self:IsTradeGood(itemID) then self:AddMaterial(itemID, count, cost, source) end
		return
	end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddPurchase(itemID, count, cost, source) end) end
	count = count or 1
	d.k = (d.k or 0) + cost
	d.i = d.i or {}
	local x = d.i[itemID] or { 0, 0 }
	x[1] = x[1] + count
	x[2] = x[2] + cost
	d.i[itemID] = x
	self:TouchOwn()
	-- persönliche Kaufliste (nur lokal, zum Nachvollziehen)
	local c = self:MyChar()
	c.purchases = c.purchases or {}
	table.insert(c.purchases, { t = self:Now(), id = itemID, n = count, c = cost, src = source or "?" })
	while #c.purchases > 100 do table.remove(c.purchases, 1) end
	self:LogEvent("wk", cost, { id = itemID, n = count, src = source })
	local _, link = GS.GetItemInfo(itemID)
	local unit = count > 1 and LF(", %s/Stück", self:FormatMoney(math.floor(cost / count))) or ""
	self:Print(LF("Werbungskosten erfasst: %s x%d für %s (%s%s)", link or self:ItemName(itemID), count,
		self:FormatMoney(cost), L[source or "Kauf"], unit))
end

-- (Selbst-Gegenbuchung „Doppelt“ entfernt: Korrekturen nur noch durch Offiziere unter Steuerposten.
--  Bereits gebuchte Korrekturen mc/kc/ci werden weiter verrechnet.)

-- weitere Stück zu einem schon bezahlten Kauf (AH-Lieferung in mehreren Briefen): nur die Menge erhöhen
function GS:AddPurchaseCount(itemID, count)
	if not itemID or not count or count <= 0 then return end
	local key = self:IsDeductible(itemID) and "i" or (self:IsTradeGood(itemID) and "mi") or nil
	if not key then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddPurchaseCount(itemID, count) end) end
	d[key] = d[key] or {}
	local x = d[key][itemID] or { 0, 0 }
	x[1] = x[1] + count
	d[key][itemID] = x
	self:TouchOwn()
	if self.debug then
		self:Print(LF("Weitere Lieferung desselben AH-Kaufs: %s x%d (Preis schon erfasst)", self:ItemName(itemID), count))
	end
end

-- Rückkauf beim Händler: mindert die Händler-Einnahmen (eigener Posten, da Werte beim Sync nur steigen)
function GS:AddBuyback(cost)
	if cost <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddBuyback(cost) end) end
	d.r = (d.r or 0) + cost
	if self.merchantSales then self.merchantSales = math.max(0, self.merchantSales - cost) end
	self:TouchOwn()
	self:LogEvent("rb", cost)
	self:Print(LF("Rückkauf verrechnet: %s – Händler-Einnahmen gemindert.", self:FormatMoney(cost)))
end

-- zurückgezahlte AH-Anzahlung (kommt mit der Verkaufspost)
function GS:AddAHRefund(amount)
	if amount <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddAHRefund(amount) end) end
	d.f = (d.f or 0) + amount
	self:TouchOwn()
	self:LogEvent("ref", amount)
end

-- AH-Anzahlung beim Einstellen: wird mit den AH-Erlösen verrechnet
-- (bei Verkauf kommt sie mit der Verkaufspost zurück, bei Ablauf/Abbruch ist sie verloren)
function GS:AddAHDeposit(cost)
	if cost <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddAHDeposit(cost) end) end
	d.e = (d.e or 0) + cost
	self:TouchOwn()
	self:LogEvent("dep", cost)
	if self.debug then self:Print(LF("AH-Anzahlung erfasst: %s", self:FormatMoney(cost))) end
end

function GS:AddRepair(cost)
	if cost <= 0 then return end
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:AddRepair(cost) end) end
	d.k = (d.k or 0) + cost
	self:TouchOwn()
	self:LogEvent("rep", cost)
	self:Print(LF("Reparatur als Werbungskosten erfasst: %s", self:FormatMoney(cost)))
end

---------------------------------------------------------------------------
-- Goldänderungen einordnen
---------------------------------------------------------------------------
local function recent(key, sec) return ctx[key] and (now() - ctx[key]) < sec end

-- Post-Geld verbuchen (AH-Verkauf: Erlös + zurückgezahlte Anzahlung)
local function bookMail(c, amount)
	if not c.ah then
		GS:LogEvent("pm", amount)
		return
	end
	local sale = c.sale and math.min(c.sale, amount) or amount
	GS:AddIncome("a", sale)
	GS.mailAHSale = (GS.mailAHSale or 0) + sale
	if amount - sale > 0 then GS:AddAHRefund(amount - sale) end
	GS.mailAH = (GS.mailAH or 0) + amount
	GS.lastMailAH = { total = amount, sale = sale, t = GetTime() }
end

-- mehrere Briefe, deren Gold WoW zu einer Änderung zusammenfasst: eine Auswahl der Post-Erwartungen,
-- deren Summe genau passt (in beliebiger Reihenfolge; ältere Erwartungen zuerst probiert)
local MAIL_SUM_MAX = 12
local function matchMailSum(delta)
	local idx = {}
	for i, c in ipairs(claims) do
		if c.kind == "mail" then
			if c.amount == delta then return false end -- genau ein Brief passt: den nehmen (unten)
			if #idx < MAIL_SUM_MAX then idx[#idx + 1] = i end
		end
	end
	if #idx < 2 then return false end
	local pick = {}
	local function search(k, rest)
		if rest == 0 then return #pick >= 2 end
		if k > #idx or rest < 0 then return false end
		local c = claims[idx[k]]
		if c.amount <= rest then
			pick[#pick + 1] = idx[k]
			if search(k + 1, rest - c.amount) then return true end
			pick[#pick] = nil
		end
		return search(k + 1, rest)
	end
	if not search(1, delta) then return false end
	for k = #pick, 1, -1 do
		local cc = table.remove(claims, pick[k])
		bookMail(cc, cc.amount)
	end
	return true
end

-- Goldeingänge ohne Quelle, die noch auf eine nachträgliche Loot-Meldung warten
local unknownGains = {}
local UNKNOWN_WAIT = 2
function GS:SettleUnknownGain(p)
	for i, x in ipairs(unknownGains) do
		if x == p then
			table.remove(unknownGains, i)
			GS:AddUntaxed(p.amount, p.where)
			return
		end
	end
end
-- Loot-Meldung kam nach der Goldänderung: wartende Eingänge sind Beute
function GS:LootMessageArrived()
	if #unknownGains == 0 then return end
	local list = unknownGains
	unknownGains = {}
	for _, p in ipairs(list) do GS:AddIncome("l", p.amount) end
end

local function classify(delta)
	cleanClaims()
	if delta > 0 and matchMailSum(delta) then return end
	-- 1. erwartete Buchungen (Post, Käufe, Reparatur)
	for i, c in ipairs(claims) do
		if c.kind == "mail" and delta > 0 and delta == c.amount then
			table.remove(claims, i)
			bookMail(c, delta)
			return
		elseif c.kind == "buy" and delta < 0 then
			table.remove(claims, i)
			GS:AddPurchase(c.item, c.count, -delta, "Händler")
			return
		elseif c.kind == "buyback" and delta < 0 then
			-- Rückkauf beim Händler: macht einen Verkauf rückgängig
			table.remove(claims, i)
			GS:AddBuyback(-delta)
			return
		elseif c.kind == "repair" and delta < 0 then
			table.remove(claims, i)
			GS:AddRepair(-delta)
			return
		elseif c.kind == "ahbuy" and delta < 0 then
			-- Sofort-/Sammelkauf im AH: jetzt buchen, der spätere Brief wird nur abgeglichen
			table.remove(claims, i)
			GS:AddPurchase(c.item, c.count, -delta, "Auktionshaus")
			GS:NoteAHBuy(c.item, c.count)
			return
		elseif c.kind == "bid" and delta < 0 then
			-- Gebot/Sofortkauf im AH: kein Einkommen, kein Verlust (Kauf wird über die Post verbucht)
			table.remove(claims, i)
			return
		elseif c.kind == "deposit" and delta < 0 then
			-- mehrere Stapel = mehrere Anzahlungen aus einem Aufruf
			c.count = (c.count or 1) - 1
			if c.count <= 0 then table.remove(claims, i) end
			GS:AddAHDeposit(-delta)
			return
		end
	end

	if delta > 0 then
		-- steuerfrei: Handel, Gildenbank, Spieler-Post
		if ctx.trade or recent("tradeClosed", 3) then
			GS:LogEvent("tr", delta)
			return
		end
		if GS.bankOpen or (GS.bankClosedAt and (now() - GS.bankClosedAt) < 3) then return end
		if ctx.loot or recent("lootClosed", 2) or recent("moneyMsg", 2) then
			GS:AddIncome("l", delta)
		elseif ctx.questFrame or recent("quest", 3) then
			GS:AddIncome("q", delta)
		elseif ctx.merchant then
			GS:AddIncome("v", delta)
		else
			-- keiner Quelle zuzuordnen (NPC-Gespräch, Erstattung, verspätete Post …): steuerfrei, aber sichtbar.
			-- Beuteanteil in der Gruppe: die Chatzeile (CHAT_MSG_MONEY) kommt oft erst nach der Goldänderung,
			-- deshalb kurz warten, ob sie noch eintrifft.
			local where = (GS.MailOpen and GS.MailOpen()) and "Briefkasten" or nil
			local p = { amount = delta, where = where }
			unknownGains[#unknownGains + 1] = p
			C_Timer.After(UNKNOWN_WAIT, function() GS:SettleUnknownGain(p) end)
		end
	else
		if ctx.merchant and InRepairMode and InRepairMode() then
			GS:AddRepair(-delta)
		end
	end
end

---------------------------------------------------------------------------
-- Goldstand-Abgleich (Steuerhinterziehung)
--
-- Der Goldstand wird bei jeder Änderung als Snapshot (lg = Gold, lt = Zeit) im eigenen
-- Wochenbericht gespeichert und mit der Gilde synchronisiert. Beim Login wird der aktuelle
-- Goldstand mit dem letzten bekannten Snapshot verglichen: Ist mehr Gold da, wurde es
-- eingenommen, während das Addon nicht lief -> Steuerhinterziehung (x).
-- Die Prüfung wartet kurz, damit nach einem Absturz die Daten der Gilde zurückkommen können.
---------------------------------------------------------------------------
local EVASION_DELAY = 45
local loginMoney, loginTime
local evasionChecked = false
local preLogin -- letzter bekannter Goldstand VOR diesem Login: { lg, lt }

-- Kandidat für den Goldstand vor dem Login merken (eigene Daten oder von der Gilde zurückgespielt)
function GS:NotePreLoginSnapshot(lg, lt)
	lg, lt = tonumber(lg), tonumber(lt)
	if not lg or not lt or not loginTime or lt > loginTime then return end
	if not preLogin or lt > preLogin.lt then preLogin = { lg = lg, lt = lt } end
end

local function capturePreLogin()
	if GS._preLoginCaptured or not loginTime then return end
	local r = GS:OwnReport()
	if not r then return end
	GS._preLoginCaptured = true
	local snap = GS:LastGoldSnapshot(loginTime)
	if snap then GS:NotePreLoginSnapshot(snap.lg, snap.lt) end
end

-- Goldstand nach jeder Goldänderung merken (nicht beim Ausloggen: dort meldet WoW teils schon 0 Gold)
function GS:UpdateGoldSnapshot(broadcast)
	capturePreLogin() -- alten Stand sichern, bevor er überschrieben wird
	local d = self:OwnWeek()
	if not d then return self:DeferBooking(function() self:UpdateGoldSnapshot(true) end) end
	d.lg = GetMoney()
	d.lt = self:Now()
	if broadcast then self:TouchOwn() end
end

function GS:LastGoldSnapshot(before)
	local r = self:OwnReport()
	local best
	if not r then return nil end
	for _, d in pairs(r.w) do
		if d.lt and d.lg and (not before or d.lt <= before) and (not best or d.lt > best.lt) then best = d end
	end
	return best
end

-- Rückfrage bei der Gilde (LSQ): Antworten zählen, spätesten Heartbeat VOR diesem Login merken
local seenBefore, seenReplies, evasionAttempt, evasionBusy = nil, 0, 0, false
function GS:NoteSeenReply(hb)
	seenReplies = seenReplies + 1
	hb = tonumber(hb)
	if hb and loginTime and hb < loginTime and (not seenBefore or hb > seenBefore) then seenBefore = hb end
end

function GS:CheckEvasion()
	if evasionChecked or evasionBusy or not loginMoney then return end
	if not self:OwnReport() then return end -- noch keine Gilde: später erneut (GUILD_READY)
	capturePreLogin()
	local snap = preLogin
	-- Goldstand genau 0 stammt praktisch immer aus dem alten Logout-Fehler -> als unbekannt behandeln
	if snap and (snap.lg or 0) <= 0 then snap = nil end
	local gap = snap and (loginMoney - snap.lg) or 0
	if gap > 0 and seenReplies == 0 and evasionAttempt < 5 then
		-- erst die Gilde fragen: Sie spielt fehlende Daten zurück und sagt, ob das Addon nach dem
		-- letzten sauberen Logout noch lief (dann war es ein Absturz, keine Hinterziehung)
		evasionBusy = true
		evasionAttempt = evasionAttempt + 1
		local rep = self:OwnReport()
		self:Broadcast({ t = "LSQ", since = loginTime, s = rep and rep.seq or 0 })
		C_Timer.After(15, function()
			evasionBusy = false
			-- keine Antwort (niemand mit Addon online): in 2 Minuten erneut, höchstens 5 Versuche
			if seenReplies > 0 then GS:CheckEvasion() else C_Timer.After(105, function() GS:CheckEvasion() end) end
		end)
		return
	end
	evasionChecked = true
	if gap > 0 then
		local d = self:OwnWeek()
		local prevLogout = self._prevLogout
		if seenBefore and prevLogout and seenBefore > prevLogout + 30 then
			-- Addon lief nach dem letzten gespeicherten Logout weiter -> Absturz, Daten nicht gespeichert:
			-- Zuwachs als normales Einkommen nachschätzen (ohne Hinterziehungs-Vermerk)
			d.l = (d.l or 0) + gap
			self:LogEvent("xc", gap)
			self:Print(LF("Nach einem Absturz fehlten Daten: Der Goldzuwachs von %s seit %s wird als normales Einkommen nachgeschätzt.",
				self:FormatMoney(gap), self:FormatTime(snap.lt)))
		else
			d.x = (d.x or 0) + gap
			self:LogEvent("x", gap)
			-- geheim: nur Offiziere bekommen eine Meldung
			if self:CanSeeEvasion() then
				self:Print(LF("|cffff4040Steuerhinterziehung erfasst:|r Dein Gold ist seit %s um %s gestiegen, während das Addon nicht aktiv war. Der Betrag wird nachversteuert.",
					self:FormatTime(snap.lt), self:FormatMoney(gap)))
			end
		end
	end
	self:UpdateGoldSnapshot(true)
end

function GS:EvasionPending() return not evasionChecked end

-- Prüfung für diesen Login vorbereiten (Goldstand beim Login merken, Prüfung nach kurzer Wartezeit)
function GS:BeginLoginCheck(money)
	loginMoney = money or GetMoney()
	loginTime = self:Now()
	self.loginTime = loginTime
	evasionChecked = false
	preLogin = nil
	seenBefore, seenReplies, evasionAttempt, evasionBusy = nil, 0, 0, false
	self._preLoginCaptured = false
	-- letzter sauber gespeicherter Logout dieses Charakters (bei einem Absturz fehlt der neuere)
	self._prevLogout = self.db and self.player and self:MyChar().lastLogout
	capturePreLogin()
	C_Timer.After(EVASION_DELAY, function() GS:CheckEvasion() end)
end

GS:On("PLAYER_ENTERING_WORLD", function()
	lastMoney = GetMoney()
	if not loginMoney then GS:BeginLoginCheck(lastMoney) end
end)
GS:Register("GUILD_READY", function()
	C_Timer.After(EVASION_DELAY, function() GS:CheckEvasion() end)
end)

-- sauberer Logout/Reload: Zeitpunkt merken (wird nur dann gespeichert, bei einem Absturz nicht)
GS:On("PLAYER_LOGOUT", function()
	if GS.db and GS.player then GS:MyChar().lastLogout = GS:Now() end
end)

GS:On("PLAYER_MONEY", function()
	local m = GetMoney()
	if not lastMoney then lastMoney = m return end
	local delta = m - lastMoney
	lastMoney = m
	if delta ~= 0 then -- auch ohne Gildendaten einordnen; die Buchung wird dann nachgeholt
		classify(delta)
		GS:UpdateGoldSnapshot(true)
	end
end)

---------------------------------------------------------------------------
-- Kontext
---------------------------------------------------------------------------
GS:On("LOOT_OPENED", function() ctx.loot = true end)
GS:On("LOOT_CLOSED", function() ctx.loot = false; ctx.lootClosed = now() end)
GS:On("CHAT_MSG_MONEY", function() ctx.moneyMsg = now(); GS:LootMessageArrived() end)
GS:On("QUEST_COMPLETE", function() ctx.questFrame = true end)
GS:On("QUEST_FINISHED", function()
	if ctx.questFrame then ctx.quest = now() end
	ctx.questFrame = false
end)
GS:On("QUEST_TURNED_IN", function() ctx.quest = now() end)
GS:On("MERCHANT_SHOW", function()
	ctx.merchant = true
	GS.merchantSales = 0 -- Summe der Verkäufe dieser Händler-Sitzung (für die Sammelmeldung)
end)
GS:On("MERCHANT_CLOSED", function()
	ctx.merchant = false
	ctx.merchantClosed = now()
end)
GS:On("TRADE_SHOW", function() ctx.trade = true end)
GS:On("TRADE_CLOSED", function() ctx.trade = false; ctx.tradeClosed = now() end)
GS:On("MAIL_SHOW", function()
	ctx.mail = true
	GS.mailAH = 0 -- AH-Geld dieser Briefkasten-Sitzung (für die Sammelmeldung)
	GS.mailAHSale = 0
end)
GS:On("MAIL_CLOSED", function()
	ctx.mail = false
	ctx.mailClosed = now()
end)

-- neuere Clients (auch Forever) melden Öffnen/Schließen teils nur über den Interaction Manager
local function interactionType(name)
	return Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[name]
end
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(t)
	if t == interactionType("MailInfo") and ctx.mail then
		ctx.mail = false
		ctx.mailClosed = now()
	elseif t == interactionType("Merchant") and ctx.merchant then
		ctx.merchant = false
		ctx.merchantClosed = now()
	end
end)

-- Fenster wirklich offen? (falls ein Schließen-Ereignis fehlt, bleibt der Zustand sonst hängen)
local function frameOpen(flag, frameName)
	if not ctx[flag] then return false end
	local f = _G[frameName]
	if f and f.IsShown and not f:IsShown() then
		ctx[flag] = false
		ctx[flag .. "Closed"] = now()
		return false
	end
	return true
end
GS.MailOpen = function() return frameOpen("mail", "MailFrame") end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------
local function itemIDFromLink(link)
	return link and tonumber(link:match("item:(%d+)"))
end

local function hook(name, fn)
	if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

hook("BuyMerchantItem", function(index, qty)
	local id = GS.MerchantItemID(index)
	local stack = GS.MerchantStack(index)
	addClaim({ kind = "buy", item = id, count = qty or stack or 1 })
end)

hook("BuybackItem", function() addClaim({ kind = "buyback" }) end)

hook("RepairAllItems", function(guildBank)
	if not guildBank then addClaim({ kind = "repair" }) end
end)

-- Auktionshaus: Einstellen (Anzahlung) und Bieten/Kaufen, alte und neue AH-API
local function hookTable(tbl, name, fn)
	if type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
end
-- Classic-AH: Blizzard nutzt StartAuction, neuere Clients und TradeSkillMaster PostAuction (gleiche Argumente).
-- Ruft eine die andere auf, darf die Anzahlung nur einmal erwartet werden.
local lastDepositHook
local function onPostAuction(_, _, _, _, numStacks)
	local t = now()
	if lastDepositHook == t then return end
	lastDepositHook = t
	addClaim({ kind = "deposit", count = tonumber(numStacks) or 1, ttl = 15 })
end
hook("StartAuction", onPostAuction)
hook("PostAuction", onPostAuction)
hookTable(C_AuctionHouse, "PostItem", function() addClaim({ kind = "deposit", ttl = 10 }) end)
hookTable(C_AuctionHouse, "PostCommodity", function() addClaim({ kind = "deposit", ttl = 10 }) end)
-- Kauf im AH: Sofortkauf und Sammelkauf werden direkt beim Kauf gebucht (Preis = tatsächliche Goldänderung).
-- Nur ein Gebot, das noch überboten werden kann, bucht weiterhin der Brief beim Abholen.
hook("PlaceAuctionBid", function(listType, index, bid)
	local id, count, buyout
	if GetAuctionItemInfo then
		local info = { GetAuctionItemInfo(listType, index) }
		count, buyout, id = tonumber(info[3]), tonumber(info[10]), tonumber(info[17])
	end
	if not id and GetAuctionItemLink then id = itemIDFromLink(GetAuctionItemLink(listType, index)) end
	if id and buyout and buyout > 0 and tonumber(bid) and tonumber(bid) >= buyout then
		addClaim({ kind = "ahbuy", item = id, count = count or 1, ttl = 30 })
	else
		addClaim({ kind = "bid" })
	end
end)
hookTable(C_AuctionHouse, "PlaceBid", function() addClaim({ kind = "bid" }) end)
hookTable(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, quantity)
	if tonumber(itemID) then
		addClaim({ kind = "ahbuy", item = tonumber(itemID), count = tonumber(quantity) or 1, ttl = 30 })
	else
		addClaim({ kind = "bid" })
	end
end)

-- Kennung eines Briefs, um doppelte Hook-Aufrufe für denselben Brief zu erkennen.
-- Nach dem Abholen rückt der nächste Brief auf denselben Platz – bei gleichem Artikel und Preis sieht er
-- gleich aus. Briefanzahl und Restlaufzeit unterscheiden ihn trotzdem.
local function mailKey(index)
	local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(index)
	local n = GetInboxNumItems and GetInboxNumItems() or 0
	return (sender or "") .. "|" .. (subject or "") .. "|" .. (money or 0) .. "|" .. index
		.. "|" .. tostring(n) .. "|" .. tostring(daysLeft or "")
end

local function onMailMoney(index)
	local _, _, _, _, money = GetInboxHeaderInfo(index)
	if not money or money <= 0 then return end
	local k = "m" .. mailKey(index)
	if recentMail[k] and (now() - recentMail[k]) < 5 then return end
	recentMail[k] = now()
	local invoiceType, _, _, bid, _, deposit, consignment
	if GetInboxInvoiceInfo then invoiceType, _, _, bid, _, deposit, consignment = GetInboxInvoiceInfo(index) end
	local claim = { kind = "mail", amount = money, ah = (invoiceType == "seller"), ttl = 60 }
	if claim.ah and tonumber(bid) then
		-- echter Verkaufserlös = Gebot minus AH-Anteil; der Rest der Post ist die zurückgezahlte Anzahlung
		claim.sale = math.max(0, tonumber(bid) - (tonumber(consignment) or 0))
	end
	addClaim(claim)
end

-- Ein AH-Kauf großer Mengen kommt als mehrere Briefe (je ein Stapel), jede Rechnung nennt aber den Gesamtpreis.
-- Deshalb Briefe desselben Kaufs (Item, Preis, Verkäufer) zusammenfassen und den Preis nur einmal ansetzen.
-- Gespeichert pro Charakter, damit ein /reload zwischen den Briefen nichts doppelt bucht.
local AH_BUY_WINDOW = 600
local AH_BOUGHT_WINDOW = 3 * 86400
local function ahStore(key)
	local c = GS.db and GS.player and GS:MyChar()
	if not c then return {} end
	c[key] = c[key] or {}
	return c[key]
end

-- beim Kauf gebucht: Menge merken, die noch per Post kommt
function GS:NoteAHBuy(itemID, count)
	if not itemID then return end
	local list = ahStore("ahBought")
	list[#list + 1] = { id = itemID, left = count or 1, t = GS:Now() }
	while #list > 50 do table.remove(list, 1) end
end
-- Brief zu einem beim Kauf gebuchten Kauf? Dann nur abgleichen (true)
function GS:ConsumeAHBuy(itemID, count)
	local list = ahStore("ahBought")
	local t = GS:Now()
	for i = #list, 1, -1 do
		local b = list[i]
		if t - (b.t or 0) > AH_BOUGHT_WINDOW or (b.left or 0) <= 0 then table.remove(list, i) end
	end
	for _, b in ipairs(list) do
		if b.id == itemID and b.left > 0 then
			b.left = b.left - (count or 1)
			return true
		end
	end
	return false
end

local mailArrived = {} -- je Item: angekommene Menge aus Briefen (für den Abgleich mehrerer Briefe)
local function onMailItem(index, attach)
	if not GetInboxInvoiceInfo then return end
	local invoiceType, _, seller, bid, _, _, _, _, _, totalCount = GetInboxInvoiceInfo(index)
	if invoiceType ~= "buyer" or not bid or bid <= 0 then return end
	local k = "i" .. mailKey(index) .. "|" .. (attach or 1)
	if recentMail[k] and (now() - recentMail[k]) < 5 then return end
	recentMail[k] = now()
	local link = GetInboxItemLink and GetInboxItemLink(index, attach or 1)
	local id = itemIDFromLink(link)
	if not id then return end
	local count = select(4, GetInboxItem(index, attach or 1)) or 1
	-- erst buchen, wenn das Item wirklich in der Tasche ankommt (volle Taschen: Herausnehmen schlägt fehl,
	-- dann darf der Brief weder verrechnet noch gebucht werden)
	local before = GetItemCount and GetItemCount(id)
	if not before then
		GS:BookAHMailItem(id, count, bid, seller, totalCount)
		return
	end
	-- mehrere Briefe mit demselben Item kurz nacheinander: jeder muss seine eigene Menge ankommen sehen
	local claimed0 = mailArrived[id] or 0
	local tries = 0
	local function check()
		tries = tries + 1
		local gained = (GetItemCount(id) or 0) - before - ((mailArrived[id] or 0) - claimed0)
		if gained >= count then
			mailArrived[id] = (mailArrived[id] or 0) + count
			GS:BookAHMailItem(id, count, bid, seller, totalCount)
		elseif tries < 8 then
			C_Timer.After(0.5, check)
		else
			recentMail[k] = nil -- nicht angekommen: späterer Versuch zählt neu
			if GS.debug then GS:Print(LF("AH-Lieferung %s x%d nicht angekommen (Taschen voll?) – nichts gebucht.", GS:ItemName(id), count)) end
		end
	end
	C_Timer.After(0.3, check)
end

-- AH-Brief mit Item, das angekommen ist: mit dem Kauf abgleichen oder als Kauf buchen
function GS:BookAHMailItem(id, count, bid, seller, totalCount)
	-- schon beim Kauf gebucht (Sofort-/Sammelkauf): nichts mehr buchen
	if GS:ConsumeAHBuy(id, count) then
		if GS.debug then GS:Print(LF("AH-Lieferung %s x%d – schon beim Kauf erfasst.", GS:ItemName(id), count)) end
		return
	end
	-- sonst (gewonnenes Gebot): Briefe desselben Kaufs zusammenfassen
	local ahBuys = ahStore("ahMail")
	local key = id .. "|" .. bid .. "|" .. tostring(seller or "")
	for kk, x in pairs(ahBuys) do if GS:Now() - (x.t or 0) > AH_BUY_WINDOW then ahBuys[kk] = nil end end
	local p = ahBuys[key]
	totalCount = tonumber(totalCount)
	if totalCount and totalCount > count then
		-- Gesamtmenge bekannt: Preis anteilig, der letzte Brief bekommt den Rest (keine Rundungsfehler)
		if not p or (p.left or 0) <= 0 then
			p = { left = totalCount, cost = bid }
			ahBuys[key] = p
		end
		p.t = GS:Now()
		local price = (p.left - count <= 0) and p.cost or math.floor(bid * count / totalCount + 0.5)
		p.left, p.cost = p.left - count, p.cost - price
		GS:AddPurchase(id, count, price, "Auktionshaus")
	elseif p then
		-- weiterer Brief desselben Kaufs: Preis ist schon gebucht, nur die Menge ergänzen
		p.t = GS:Now()
		GS:AddPurchaseCount(id, count)
	else
		ahBuys[key] = { t = GS:Now() }
		GS:AddPurchase(id, count, bid, "Auktionshaus")
	end
end

-- Post wird VOR dem Abholen gelesen (wie TradeSkillMaster): nach dem Aufruf kann der Client Betrag
-- und Anhang des Briefs schon geleert haben, dann fehlte die Erwartung und AH-Gold galt als "Sonstiges".
-- Die Mail-Funktionen sind nicht geschützt, ein Ersetzen ist daher unbedenklich; Fehler im eigenen Teil
-- dürfen das Abholen nie verhindern.
local function preHook(name, fn)
	local orig = _G[name]
	if type(orig) ~= "function" then return end
	_G[name] = function(...)
		local ok, err = pcall(fn, ...)
		if not ok and GS.debug then GS:Print("Post-Hook " .. name .. ": " .. tostring(err)) end
		return orig(...)
	end
end
preHook("TakeInboxMoney", function(index) onMailMoney(index) end)
preHook("TakeInboxItem", function(index, attach) onMailItem(index, attach) end)
preHook("AutoLootMailItem", function(index)
	onMailMoney(index)
	onMailItem(index, 1)
end)

---------------------------------------------------------------------------
-- Loot-Meldung um die Steuer ergänzen:
-- "Ihr erhaltet Beute: 2 Silber." -> "Ihr erhaltet Beute: 2 Silber (10 Kupfer Steuer)."
---------------------------------------------------------------------------
local function escapePattern(s)
	return (s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- Betrag (Kupfer) aus einer lokalisierten Geld-Meldung lesen
function GS:ParseCoinMessage(msg)
	if type(msg) ~= "string" then return nil end
	local low = msg:lower()
	-- je Münzart einzeln: 1. WoW-Textvorlage, 2. Münz-Symbol, 3. Wort (de/en)
	local COINS = {
		{ mult = 10000, fmt = _G.GOLD_AMOUNT or "%d Gold", tex = "gold", words = { "gold" } },
		{ mult = 100, fmt = _G.SILVER_AMOUNT or "%d Silber", tex = "silver", words = { "silber", "silver" } },
		{ mult = 1, fmt = _G.COPPER_AMOUNT or "%d Kupfer", tex = "copper", words = { "kupfer", "copper" } },
	}
	local function num(n)
		return n and tonumber((n:gsub("[%.,]", "")))
	end
	local total, found = 0, false
	for _, c in ipairs(COINS) do
		local n
		if type(c.fmt) == "string" and c.fmt:find("%d", 1, true) then
			n = num(msg:match((escapePattern(c.fmt):gsub("%%d", "([%%d%%.,]+)"))))
		end
		if not n then
			n = num(low:match("([%d%.,]+)%s*|t[^|]*" .. c.tex)) or num(low:match("([%d%.,]+)%s*|a:[^|]*" .. c.tex))
		end
		if not n then
			for _, w in ipairs(c.words) do
				n = num(low:match("([%d%.,]+)%s*" .. w))
				if n then break end
			end
		end
		if n then
			total = total + n * c.mult
			found = true
		end
	end
	return found and total or nil
end

-- zusätzliche Einkommensteuer + Soli, die dieser Loot in der laufenden Woche auslöst
function GS:LootTaxPreview(amount)
	local a = self:G() and self:AccountFor(self.player)
	if not a or not amount or amount <= 0 then return nil end
	local cur = self:CurrentWeek()
	local base = self:AccountWeek(a.chars, cur)
	-- ist der Loot schon gebucht? (Goldänderung und Chatmeldung kommen in beliebiger Reihenfolge)
	local included = (self.lastLoot and self.lastLoot.amount == amount and (GetTime() - self.lastLoot.t) < 2)
		-- Sammelmeldung des Händlers ("Erhalten: …") nach dem Schließen: Verkäufe sind schon gebucht
		or ((ctx.merchant or recent("merchantClosed", 5)) and self.merchantSales == amount and amount > 0)
	local before, after = self:Copy(base), self:Copy(base)
	local T = self:GetEffective("tariff", cur)
	local factor = self:TaxFactor(a, cur, T)
	-- eigener Charakter unter der Level-Grenze: steuerfrei
	local lvl = self:CharLevel(self.player)
	if (tonumber(T.exemptLevel) or 0) > 0 and lvl and lvl > 0 and lvl < T.exemptLevel then factor = 0 end
	-- Briefkasten: AH-Geld (Erlös + zurückgezahlte Anzahlungen) -> Umsatz-/Gewerbesteuer statt Einkommensteuer
	-- gerade gebuchter Loot/Quest/Händler-Betrag ist nie Post
	local lootLike = self.lastLoot and self.lastLoot.cat ~= "a" and self.lastLoot.amount == amount
		and (GetTime() - self.lastLoot.t) < 3
	local mailCtx = not lootLike and (frameOpen("mail", "MailFrame") or recent("mailClosed", 5))
	local lm = self.lastMailAH
	local single = lm and lm.total == amount and (GetTime() - lm.t) < 3
	local isAH = mailCtx and ((self.mailAH or 0) == amount or single)
	if mailCtx and not isAH then return nil end -- Post von Spielern o. Ä.: keine Angabe
	if isAH then
		-- Beträge dieser Sitzung sind schon gebucht: Woche ohne sie mit Woche mit ihnen vergleichen
		local ahNow = a.weeks[cur]
		local carry = ahNow and ahNow.ahCarryIn or 0
		local sale = math.min(before.a, single and lm.sale or (self.mailAHSale or amount))
		before.a = math.max(0, before.a - sale)
		before.f = math.max(0, (before.f or 0) - math.max(0, amount - sale))
		local tb = self:CalcTax(before, cur, a.deposits[cur], carry, factor)
		local ta = self:CalcTax(after, cur, a.deposits[cur], carry, factor)
		local function ahTax(t) return math.floor((t.ust + t.gew) * factor + 1e-6) end
		return math.max(0, ahTax(ta) - ahTax(tb)), nil, math.max(0, (ta.ust + ta.gew - tb.ust - tb.gew) * factor)
	end
	if included then before.l = math.max(0, before.l - amount) else after.l = after.l + amount end
	local tb = self:CalcTax(before, cur, a.deposits[cur], nil, factor)
	local ta = self:CalcTax(after, cur, a.deposits[cur], nil, factor)
	-- verbleibender steuerfreier Betrag diese Woche (Grundfreibetrag + angesetzte Werbungskosten)
	local threshold
	for _, z in ipairs(self:GetEffective("tariff", cur).zones or {}) do
		if tonumber(z[2]) and z[2] > 0 and (not threshold or z[1] < threshold) then threshold = z[1] end
	end
	local free = threshold and math.max(0, threshold + ta.wkEff - ta.base) or nil
	local function rounded(t) return math.floor((t.est + t.soli) * factor + 1e-6) end
	if factor == 0 then free = nil end
	-- dritter Wert: exakte (ungerundete) Zusatzsteuer, um "unter 1 Kupfer" von "steuerfrei" zu unterscheiden
	return math.max(0, rounded(ta) - rounded(tb)), free, math.max(0, (ta.est + ta.soli - tb.est - tb.soli) * factor)
end

-- Betrag mit Münz-Symbolen (wie in den WoW-Meldungen)
local COIN_ICON = {
	"|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
	"|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
	"|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
local function coinText(c)
	c = math.floor((c or 0) + 1e-6)
	local f = _G.GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
	if f then
		local ok, t = pcall(f, c)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	local g, sv, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. COIN_ICON[1] end
	if sv > 0 then parts[#parts + 1] = sv .. COIN_ICON[2] end
	if k > 0 or #parts == 0 then parts[#parts + 1] = k .. COIN_ICON[3] end
	return table.concat(parts, " ")
end
GS.CoinText = coinText

local lastFilter = {}
local function moneyFilter(_, _, msg, ...)
	if not GS.db or GS.db.lootTaxMsg == false or type(msg) ~= "string" then return false end
	-- jedes Chatfenster ruft den Filter auf -> Ergebnis kurz zwischenspeichern
	if lastFilter.msg == msg and (GetTime() - lastFilter.t) < 1 then return false, lastFilter.out, ... end
	local amount = GS:ParseCoinMessage(msg)
	local txt = amount and GS:TaxSuffix(amount)
	if not txt then return false end
	local body, dot = msg:match("^(.-)(%.?)$")
	local out = body .. " " .. txt .. dot
	lastFilter = { msg = msg, t = GetTime(), out = out }
	GS.lastAnnotated = GetTime()
	return false, out, ...
end

-- farbiger Steuer-Zusatz für einen Betrag: "(4 Kupfer Steuer)" / "(steuerfrei)"; nil = keine Angabe möglich
function GS:TaxSuffix(amount)
	local tax, free, exact = self:LootTaxPreview(amount)
	if not tax then return nil end
	local ORANGE, GREEN = "|cffff9933", "|cff40ff40"
	if tax <= 0 and (exact or 0) > 1e-6 then
		-- über dem Freibetrag, aber weniger als 1 Kupfer Steuer: nicht "steuerfrei" nennen
		return ORANGE .. LF("(unter %s Steuer)", "|r" .. coinText(1) .. ORANGE) .. "|r"
	end
	if tax > 0 then
		return ORANGE .. LF("(%s Steuer)", "|r" .. coinText(tax) .. ORANGE) .. "|r"
	elseif free and free > 0 and self.db.lootTaxDetail then
		return GREEN .. LF("(steuerfrei, noch %s frei)", "|r" .. coinText(free) .. GREEN) .. "|r"
	end
	return GREEN .. L["(steuerfrei)"] .. "|r"
end

-- Questbelohnungen zeigt Forever teils nicht im Chat: dann eine eigene Meldung ausgeben
function GS:QuestRewardNotice(amount, bookedAt)
	if not self.db or self.db.lootTaxMsg == false then return end
	if self.lastAnnotated and self.lastAnnotated >= bookedAt then return end -- Chatzeile wurde schon ergänzt
	local txt = self:TaxSuffix(amount)
	if not txt then return end
	self:Print(LF("Questbelohnung %s %s", coinText(amount), txt))
end
GS.LootMoneyFilter = moneyFilter

-- Händlerverkauf ("Erhalten: 62 Kupfer") und Questgeld kommen je nach Client über andere Kanäle.
-- Dort nur ergänzen, wenn Händler/Quest offen ist oder gerade Einkommen verbucht wurde.
local function contextFilter(self, event, msg, ...)
	local relevant = ctx.merchant or recent("merchantClosed", 5) or ctx.questFrame or recent("quest", 3)
		or frameOpen("mail", "MailFrame") or recent("mailClosed", 5)
		or (GS.lastLoot and (GetTime() - GS.lastLoot.t) < 2)
	if not relevant then return false end
	return moneyFilter(self, event, msg, ...)
end
GS.ContextMoneyFilter = contextFilter

-- Manche Meldungen (z. B. Händler-Sammelmeldung "Erhalten: 19" in Forever oder von Verkaufs-Addons)
-- kommen ohne Chat-Event direkt ins Chatfenster. Deshalb zusätzlich die Ausgabe der Chatfenster ergänzen.
local function annotateText(text, chatID)
	if type(text) ~= "string" or not GS.db or GS.db.lootTaxMsg == false then return text end
	-- schon ergänzt (über den Event-Filter) oder eigene Meldung
	if text:find("steuerfrei", 1, true) or text:find("Steuer)", 1, true) or text:find("Finanzamt", 1, true)
		or text:find(L["steuerfrei"], 1, true) or text:find(L["Steuer)"], 1, true) then return text end
	-- nur Meldungen des Spiels ergänzen, keine Ausgaben anderer Addons (z. B. Mastercraft, Verkaufs-Addons)
	if not GS.IsGameMoneyChat(chatID) then
		if GS:ParseCoinMessage(text) then GS:DebugMoneyLine(text, L["keine Spielmeldung (anderes Addon?)"]) end
		return text
	end
	local relevant = ctx.merchant or recent("merchantClosed", 5) or ctx.questFrame or recent("quest", 3)
		or frameOpen("mail", "MailFrame") or recent("mailClosed", 5)
		or (GS.lastLoot and (GetTime() - GS.lastLoot.t) < 2)
	local amount = GS:ParseCoinMessage(text)
	if not relevant then
		if amount then GS:DebugMoneyLine(text, L["kein Händler/Quest/Briefkasten-Zusammenhang"]) end
		return text
	end
	local _, out = moneyFilter(nil, "ADDMESSAGE", text)
	if not out then
		GS:DebugMoneyLine(text, amount and LF("Betrag %s erkannt, aber keine Steuerberechnung (z. B. Spielerpost)", GS:FormatMoney(amount, true))
			or L["kein Geldbetrag erkannt"])
	end
	return out or text
end

-- Sieht die Zeile nach einem Geldbetrag aus? Münz-Symbol oder Zahl direkt vor einem Münz-Wort
-- ("3 Kupfer", "12 Silberstücke", "1 gold") – aber nicht Items wie "Kupferbarren" oder "Goldbarren".
local COIN_WORDS = { "kupfer", "silber", "gold", "copper", "silver" }
local COIN_SUFFIX = { "", "stücke", "stück", "münzen", "münze" }
function GS.LooksLikeMoney(text)
	if type(text) ~= "string" then return false end
	local low = text:lower()
	if low:find("ui%-goldicon") or low:find("ui%-silvericon") or low:find("ui%-coppericon")
		or low:find("moneyframe") or low:find("coin%-") then return true end
	for _, w in ipairs(COIN_WORDS) do
		local pos = 1
		while true do
			local s, e = low:find("%d[%d%.,]*%s*" .. w, pos)
			if not s then break end
			local rest = low:sub(e + 1)
			for _, suf in ipairs(COIN_SUFFIX) do
				if rest:sub(1, #suf) == suf then
					local nextc = rest:sub(#suf + 1, #suf + 1)
					-- danach kein weiterer Buchstabe (sonst Teil eines Item-Namens)
					if nextc == "" or not nextc:find("[%a\128-\255]") then return true end
				end
			end
			pos = e + 1
		end
	end
	return false
end

-- Stammt die Zeile vom Spiel? Das Spiel gibt Chatzeilen mit der Kennung des Chat-Typs aus
-- (AddMessage(text, r, g, b, id, ...)); Addons schreiben meist nur AddMessage(text[, r, g, b]).
-- Sprachunabhängig: nur System-, Geld-, Loot- und Währungsmeldungen bekommen den Steuer-Hinweis.
local GAME_MONEY_TYPES = { "SYSTEM", "MONEY", "LOOT", "CURRENCY" }
function GS.IsGameMoneyChat(id)
	if type(id) ~= "number" or type(ChatTypeInfo) ~= "table" then return false end
	for _, t in ipairs(GAME_MONEY_TYPES) do
		local info = ChatTypeInfo[t]
		if info and info.id == id then return true end
	end
	return false
end

-- /gst debug: warum eine Geld-Zeile (nicht) ergänzt wurde
function GS:DebugMoneyLine(text, reason)
	if not self.debug then return end
	if not GS.LooksLikeMoney(text) then return end
	local shown = text:gsub("|", "||")
	C_Timer.After(0, function() GS:Print(LF("Debug Geld-Meldung: %s – Text: %s", reason, shown)) end)
end
GS.AnnotateChatText = annotateText

local function hookChatFrames()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf and type(cf.AddMessage) == "function" and not cf.finanzamtHooked then
			local orig = cf.AddMessage
			cf.AddMessage = function(self, text, ...)
				local ok, newText = pcall(annotateText, text, select(4, ...))
				return orig(self, ok and newText or text, ...)
			end
			cf.finanzamtHooked = true
		end
	end
end
GS.HookChatFrames = hookChatFrames
GS:On("PLAYER_LOGIN", hookChatFrames)
GS:On("UPDATE_CHAT_WINDOWS", hookChatFrames)

if ChatFrame_AddMessageEventFilter then
	ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", moneyFilter)
	for _, ev in ipairs({ "CHAT_MSG_SYSTEM", "CHAT_MSG_CURRENCY", "CHAT_MSG_LOOT" }) do
		ChatFrame_AddMessageEventFilter(ev, contextFilter)
	end
end
