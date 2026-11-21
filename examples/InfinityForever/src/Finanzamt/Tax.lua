-- Finanzamt – Steuerberechnung, Konten, Salden
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local floor, max, min = math.floor, math.max, math.min
-- neue Steuern / Verzugszinsen gelten für Tarife ohne eigene Einstellung erst ab diesen Zeitpunkten (nicht rückwirkend)
local NEW_TAX_SINCE = 1795089600 -- 19.11.2026 12:00 UTC
local INTEREST_SINCE = 1795694400 -- 26.11.2026 12:00 UTC (Verzugszinsen)
GS.INTEREST_SINCE = INTEREST_SINCE

GS.CATS = { "l", "q", "v", "a", "k", "x", "e", "r", "f", "o", "m", "mc", "kc", "al", "mt", "mr" } -- al: Alkohol-Einkäufe, mr: Reiten gelernt (1 je Charakter; mt = alte, fehlerhafte Erkennung, wird ignoriert) -- mc/kc: als doppelt markierte Käufe (Korrektur) -- m: Wareneinsatz (Handwerkswaren-Einkäufe) -- Loot, Quest, Händler, AH, Werbungskosten, ohne Addon eingenommen, AH-Anzahlungen, Rückkäufe, zurückgezahlte Anzahlungen

-- Progressiver Tarif mit Grenzsteuersätzen: zones = { {ab, satz}, ... }
function GS:Progressive(x, zones)
	local z = {}
	for _, e in ipairs(zones or {}) do
		if tonumber(e[1]) and tonumber(e[2]) then z[#z + 1] = { tonumber(e[1]), tonumber(e[2]) } end
	end
	table.sort(z, function(a, b) return a[1] < b[1] end)
	local tax = 0
	for i, e in ipairs(z) do
		local from = e[1]
		local to = z[i + 1] and z[i + 1][1] or math.huge
		if x > from then tax = tax + (min(x, to) - from) * e[2] end
	end
	return tax -- exakt; gerundet wird erst die Gesamtsteuer
end

function GS:EmptyWeek()
	return { l = 0, q = 0, v = 0, a = 0, k = 0, x = 0, e = 0, r = 0, f = 0, o = 0, m = 0, mc = 0, kc = 0, al = 0, mt = 0, mr = 0, i = {}, mi = {}, ci = {} }
end

function GS:AccountWeek(chars, w)
	local g = self:G()
	local sum = self:EmptyWeek()
	if not g then return sum end
	for _, c in ipairs(chars) do
		local r = g.reports[c]
		local d = r and r.w and r.w[w]
		if d then
			for _, k in ipairs(self.CATS) do sum[k] = sum[k] + (tonumber(d[k]) or 0) end
			for _, key in ipairs({ "i", "mi", "ci" }) do
				if type(d[key]) == "table" then
					for id, x in pairs(d[key]) do
						if type(x) == "table" then
							local s = sum[key][id] or { 0, 0 }
							s[1] = s[1] + (tonumber(x[1]) or 0)
							s[2] = s[2] + (tonumber(x[2]) or 0)
							sum[key][id] = s
						end
					end
				end
			end
		end
	end
	return sum
end

-- deposits: { [itemID] = Anzahl } – in dieser Woche in die Gildenbank eingelegt (Rücknahme des WK-Abzugs)
-- ahCarryIn: AH-Verlust aus Vorwochen (Verlustvortrag)
-- factor: Steuerfaktor des Kontos (Rang-Faktor, 0 = befreit); wird vor dem Abrunden angewendet
function GS:CalcTax(sum, w, deposits, ahCarryIn, factor)
	local T = self:GetEffective("tariff", w)
	-- AH-Saldo: Erlöse (inkl. zurückerstatteter Anzahlungen) minus gezahlte Anzahlungen minus Verlustvortrag
	ahCarryIn = ahCarryIn or 0
	local ahFees = sum.e or 0
	local ahRefund = sum.f or 0 -- mit der Verkaufspost zurückgezahlte Anzahlungen
	-- Wareneinsatz: eingekaufte Handwerkswaren (abzüglich der davon in die Gildenbank gelegten)
	-- ci: Korrektur doppelt gebuchter Käufe je Item (nur Betrag)
	local function itemCost(x, id)
		local c = sum.ci and sum.ci[id]
		return max(0, x[2] - (c and tonumber(c[2]) or 0))
	end
	local matRev = 0
	for id, cnt in pairs(deposits or {}) do
		local x = sum.mi and sum.mi[id]
		if x and x[1] > 0 then matRev = matRev + min(cnt, x[1]) * itemCost(x, id) / x[1] end
	end
	matRev = floor(matRev)
	local matGross = max(0, (sum.m or 0) - (sum.mc or 0))
	local matCost = max(0, matGross - matRev)
	local ahNet = sum.a + ahRefund - ahFees - matCost - ahCarryIn
	local ahCarryOut = 0
	if ahNet < 0 then
		ahCarryOut = -ahNet
		ahNet = 0
	end
	local evasion = sum.x or 0
	-- Händler-Einnahmen abzüglich Rückkäufe (nicht unter 0)
	local buyback = sum.r or 0
	local vendorNet = math.max(0, sum.v - buyback)
	local base = sum.l + sum.q + vendorNet + evasion -- ohne Addon eingenommenes Gold wird nachversteuert
	local rev = 0
	for id, cnt in pairs(deposits or {}) do
		local x = sum.i[id]
		if x and x[1] > 0 then rev = rev + min(cnt, x[1]) * itemCost(x, id) / x[1] end
	end
	rev = floor(rev)
	local wkActual = max(0, sum.k - (sum.kc or 0) - rev)
	local wkEff = max(T.pausch or 0, wkActual)
	local taxable = max(0, base - wkEff)
	local est = self:Progressive(taxable, T.zones)
	-- alle Steuerarten exakt (mit Nachkommastellen) – abgerundet wird erst die fällige Gesamtsteuer
	local soli = est * (T.soli or 0)
	local ust = ahNet * (T.ust or 0)
	local gew = max(0, ahNet - (T.gewFree or 0)) * (T.gew or 0)
	local EPS = 1e-6 -- gegen Gleitkomma-Ungenauigkeit (279,9999… -> 280)
	factor = factor or 1
	local total = floor((est + soli + ust + gew) * factor + EPS)
	local small = false
	if total > 0 and total < (T.minTax or 0) and evasion == 0 then
		total = 0
		small = true
	end
	-- Hinterziehungszuschlag auf das ohne Addon eingenommene Gold
	local penalty = evasion * (T.evasionPenalty or 0)
	-- Ergebnis: fällige Steuer auf volles Kupfer abgerundet
	if small then
		total = floor(penalty * factor + EPS)
	else
		total = floor((est + soli + ust + gew + penalty) * factor + EPS)
	end
	return {
		week = w, untaxed = sum.o or 0, loot = sum.l, quest = sum.q, vendor = vendorNet, vendorGross = sum.v, buyback = buyback, ah = sum.a, evasion = evasion, penalty = penalty,
		ahFees = ahFees, ahRefund = ahRefund, matCost = matCost, matGross = matGross, matRev = matRev, ahCarryIn = ahCarryIn, ahCarryOut = ahCarryOut, ahNet = ahNet,
		base = base, wkActual = wkActual, wkRev = rev, wkEff = wkEff, pausch = T.pausch or 0,
		taxable = taxable, est = est, soli = soli, ust = ust, gew = gew, total = total, small = small, factor = factor,
	}
end

function GS:KnownChars()
	local g = self:G()
	local set = {}
	if not g then return set end
	for c in pairs(g.reports) do set[self:ResolveName(c)] = true end
	for c in pairs(self.roster) do set[c] = true end
	for _, e in ipairs(g.bank) do set[self:ResolveName(e.c)] = true end
	for c, m in pairs(self:Links()) do
		set[c] = true
		set[m] = true
	end
	return set
end

-- Berechnet alle Konten (gecacht bis Invalidate oder Wochenwechsel)
function GS:Calc()
	local cur = self:CurrentWeek()
	if self._calc and self._calc.week == cur then return self._calc end
	local g = self:G()
	local calc = { week = cur, accounts = {} }
	self._calc = calc
	if not g then return calc end
	local accounts = calc.accounts

	local function acc(char)
		local m = self:AccountOf(char)
		local a = accounts[m]
		if not a then
			a = { main = m, chars = {}, charset = {}, bal = 0, bookings = {}, weeks = {}, deposits = {}, due = 0, taxTotal = 0 }
			accounts[m] = a
		end
		if not a.charset[char] then
			a.charset[char] = true
			table.insert(a.chars, char)
		end
		return a
	end

	for char in pairs(self:KnownChars()) do acc(char) end
	for _, a in pairs(accounts) do
		if not a.charset[a.main] then
			a.charset[a.main] = true
			table.insert(a.chars, a.main)
		end
	end

	-- Gildenbank
	local overrides = self:ValueOverrides()
	for _, e in ipairs(g.bank) do
		local a = acc(e.c)
		local w = self:WeekOf(e.t)
		local B = self:GetEffective("bank", w)
		local v, src = self:EntryValue(e, overrides)
		local amount, note = 0, nil
		if e.y == "D" then
			amount = e.n
		elseif e.y == "W" then
			amount = -e.n
		elseif e.y == "R" then
			if B.chargeRepair then amount = -e.n else note = L["nicht belastet"] end
		elseif e.y == "d" then
			amount = v
			a.deposits[w] = a.deposits[w] or {}
			a.deposits[w][e.i] = (a.deposits[w][e.i] or 0) + e.n
		elseif e.y == "w" then
			if B.free and B.free[e.b] then note = L["freier Tab"] else amount = -v end
		end
		a.bal = a.bal + amount
		table.insert(a.bookings, { t = e.t, kind = e.y, e = e, item = e.i, count = e.i > 0 and e.n or nil, v = v, src = src, amount = amount, note = note })
	end

	-- Korrekturbuchungen
	for _, x in ipairs(self:SortedADM("CORR")) do
		local d = x.d
		local v = tonumber(d.v)
		if type(d.a) == "string" and v then
			local a = acc(d.a)
			a.bal = a.bal + v
			table.insert(a.bookings, { t = x.tm, kind = "C", amount = v, v = v, note = (d.n or "") .. " (" .. x.au .. ")" })
		end
	end

	-- Erlass, Stundung, Einsprüche (Verwaltungsbuchungen)
	local relief = self:ReliefIndex()
	for main, r in pairs(relief) do
		if r.objections then acc(main).objections = r.objections end
	end

	-- Steuern
	local tcorr = self:TaxCorrIndex()
	local dueWeeks = self:GetLatest("tariff").dueWeeks or 1
	for _, a in pairs(accounts) do
		local rel = relief[a.main] or {}
		local weeks = {}
		for _, c in ipairs(a.chars) do
			local r = g.reports[c]
			if r and r.w then
				for w in pairs(r.w) do weeks[w] = true end
			end
		end
		-- chronologisch, damit AH-Verluste in die Folgewochen vorgetragen werden
		local sorted = {}
		for w in pairs(weeks) do sorted[#sorted + 1] = w end
		table.sort(sorted)
		local ahCarry = 0
		for _, w in ipairs(sorted) do
			local T = self:GetEffective("tariff", w)
			local taxChars, levelExempt = self:TaxableChars(a, T)
			local factor, reason = self:TaxFactor(a, w, T)
			local sum = self:AccountWeek(taxChars, w)
			self:ApplyTaxCorr(sum, tcorr[a.main] and tcorr[a.main][w])
			-- Erlass: Hinterziehung dieser Woche wird nicht versteuert
			local waived = 0
			if rel.waive and rel.waive[w] and (sum.x or 0) > 0 then
				waived = sum.x
				sum.x = 0
			end
			local res = self:CalcTax(sum, w, a.deposits[w], ahCarry, factor)
			self:ApplyExtraTaxes(res, a, taxChars, sum, w, T, factor)
			res.exemptReason, res.levelExempt = reason, levelExempt
			res.waived = waived
			ahCarry = res.ahCarryOut
			a.weeks[w] = res
			a.evasionTotal = (a.evasionTotal or 0) + (res.evasion or 0)
			if w < cur and res.total > 0 then
				a.bal = a.bal - res.total
				a.taxTotal = a.taxTotal + res.total
				local deferUntil = rel.defer and rel.defer[w]
				if w >= cur - dueWeeks then
					a.due = a.due + res.total
				elseif deferUntil and cur <= deferUntil then
					-- Stundung: noch nicht überfällig
					a.due = a.due + res.total
					res.deferredUntil = deferUntil
				end
				table.insert(a.bookings, { t = self:WeekStart(w + 1), kind = "T", amount = -res.total, v = res.total,
					note = res.deferredUntil and LF("Steuer %s (gestundet)", self:WeekLabel(w)) or LF("Steuer %s", self:WeekLabel(w)) })
			end
		end
		a.ahCarry = ahCarry
		self:ApplyInterest(a, rel, dueWeeks, cur)
		a.cur = a.weeks[cur] or self:CalcTax(self:EmptyWeek(), cur, nil, ahCarry, (self:TaxFactor(a, cur, self:GetEffective("tariff", cur))))
		if a.bal >= 0 then
			a.status = "quitt"
		elseif a.bal + a.due >= 0 then
			a.status = "offen"
		else
			a.status = "überfällig"
		end
		table.sort(a.bookings, function(x, y) return x.t > y.t end)
		table.sort(a.chars, function(x, y)
			if x == a.main then return true end
			if y == a.main then return false end
			return x < y
		end)
	end
	return calc
end

---------------------------------------------------------------------------
-- Verzugszinsen: nur in aktiven Spielwochen, mit Schonfrist, Bagatellgrenze und Deckel.
-- Verzinst wird nur überfällige Steuer (keine Zinseszinsen); Zahlungen tilgen zuerst die Steuer.
---------------------------------------------------------------------------
function GS:InterestSettings(w)
	local T = self:GetEffective("tariff", w)
	local D = self.DEFAULTS.tariff
	local function v(k)
		local x = T and tonumber(T[k])
		if x == nil then x = tonumber(D[k]) end
		return x or 0
	end
	return {
		rate = self:NewTariffValue(T, "interestRate", w, INTEREST_SINCE),
		minDays = v("interestMinDays"), minMinutes = v("interestMinMinutes"),
		grace = v("interestGrace"), min = v("interestMin"), cap = v("interestCap"),
	}
end

-- Online-Tage und Spielzeit des ganzen Kontos in Woche w
function GS:AccountActivity(a, w)
	local g = self:G()
	local mask, pt = 0, 0
	for _, c in ipairs(a.chars or {}) do
		local r = g and g.reports[c]
		local d = r and r.w and r.w[w]
		if d then
			local m = tonumber(d.od) or 0
			for i = 0, 6 do
				local b = 2 ^ i
				if self:HasBit(m, b) and not self:HasBit(mask, b) then mask = mask + b end
			end
			pt = pt + (tonumber(d.pt) or 0)
		end
	end
	local days = 0
	for i = 0, 6 do
		if self:HasBit(mask, 2 ^ i) then days = days + 1 end
	end
	return days, pt
end

-- zählt die Woche als aktive Spielwoche? (beide Grenzen 0 = jede Woche zählt)
function GS:IsActiveWeek(a, w, S)
	local days, pt = self:AccountActivity(a, w)
	return days >= (S.minDays or 0) and pt >= (S.minMinutes or 0) * 60, days, pt
end

function GS:ApplyInterest(a, rel, dueWeeks, cur)
	a.interest, a.interestTotal, a.interestNow, a.overdue = {}, 0, nil, {}
	local list = {}
	for _, b in ipairs(a.bookings) do list[#list + 1] = b end
	if #list == 0 then return end
	table.sort(list, function(x, y) return x.t < y.t end)
	local startW = self:WeekOf(INTEREST_SINCE)
	local first = self:WeekOf(list[1].t)
	local defer = rel and rel.defer or {}
	local bal, idx = 0, 1
	local grace, episode, peak = 0, 0, 0
	for x = first, cur do
		local stop = self:WeekStart(x + 1)
		while list[idx] and list[idx].t < stop do
			bal = bal + (list[idx].amount or 0)
			idx = idx + 1
		end
		local S = self:InterestSettings(x)
		-- überfällige Steuer zu Beginn der Woche x und noch nicht fällige Steuer
		local overdue, notDue = 0, 0
		for w, res in pairs(a.weeks) do
			if w <= x - 1 and (res.total or 0) > 0 then
				if w < x - dueWeeks and not (defer[w] and x <= defer[w]) then
					overdue = overdue + res.total
				else
					notDue = notDue + res.total
				end
			end
		end
		local base = math.min(overdue, math.max(0, -(bal + notDue)))
		a.overdue[x] = base -- Verlauf (auch für Erfolge)
		if x >= startW then
		local active, days, pt = self:IsActiveWeek(a, x, S)
		local info = { base = base, rate = S.rate, days = days, pt = pt, active = active, S = S }
		if S.rate <= 0 or base < math.max(1, S.min) then
			grace, episode, peak = 0, 0, 0
			info.none = true
		elseif not active then
			info.inactive = true
		elseif grace < S.grace then
			info.grace = true
			info.graceLeft = S.grace - grace
			if x < cur then grace = grace + 1 end
		else
			local p = math.max(peak, base)
			local z = math.floor(base * S.rate + 1e-6)
			if S.cap > 0 then z = math.min(z, math.max(0, math.floor(p * S.cap + 1e-6) - episode)) end
			info.z = z
			info.capped = S.cap > 0 and episode + z >= math.floor(p * S.cap + 1e-6)
			if x < cur then
				peak = p
				if z > 0 then
					episode = episode + z
					a.interestTotal = a.interestTotal + z
					a.bal = a.bal - z
					table.insert(a.bookings, { t = stop, kind = "Z", amount = -z, v = z,
						note = LF("Verzugszinsen %s (%s auf %s)", self:WeekLabel(x), self:FormatPercent(S.rate), self:FormatMoney(base, true)) })
				end
			end
		end
		if x < cur then a.interest[x] = info else a.interestNow = info end
		end
	end
end

-- Hinweis zu Verzugszinsen für die laufende Woche (nil = nichts anzuzeigen)
function GS:InterestLine(a)
	local n = a and a.interestNow
	local paid = a and a.interestTotal or 0
	local function act(S)
		local parts = {}
		if (S.minDays or 0) > 0 then parts[#parts + 1] = LF("%s Tagen", tostring(S.minDays)) end
		if (S.minMinutes or 0) > 0 then parts[#parts + 1] = LF("%s Min. Spielzeit", tostring(S.minMinutes)) end
		return #parts > 0 and LF(" (ab %s in der Woche)", table.concat(parts, " / ")) or ""
	end
	local line
	if n and not n.none then
		local S = n.S
		local pct = self:FormatPercent(n.rate)
		if n.grace then
			line = (n.graceLeft > 1 and LF("|cffffd100Verzugszinsen:|r noch %s aktive Wochen zinsfrei, danach %s pro aktiver Spielwoche", tostring(n.graceLeft), pct)
				or LF("|cffffd100Verzugszinsen:|r diese Woche noch zinsfrei, danach %s pro aktiver Spielwoche", pct)) .. act(S)
		elseif n.capped and (n.z or 0) <= 0 then
			line = L["|cffff8040Verzugszinsen:|r Höchstbetrag erreicht – es kommen keine weiteren dazu"]
		else
			line = LF("|cffff8040Verzugszinsen:|r %s auf %s, wenn du diese Woche spielst%s und nicht zahlst", pct, self:FormatMoney(n.base, true), act(S))
		end
	end
	if paid > 0 then
		local s = LF("|cffaaaaaaBisher angefallene Verzugszinsen: %s|r", self:FormatMoney(paid, true))
		line = line and (line .. "\n" .. s) or s
	end
	return line
end

-- Zahlungszeile für ein Konto: was ist gedeckt, was muss bis wann noch gezahlt werden (nil = nichts anzuzeigen)
function GS:PaymentLine(a)
	if not a then return nil end
	local cur = self:CurrentWeek()
	local dueAt = date("%d.%m.", self:WeekStart(cur + (self:GetLatest("tariff").dueWeeks or 1)))
	local due, bal = a.due or 0, a.bal or 0
	local last = a.weeks[cur - 1]
	local label = (last and math.abs((last.total or 0) - due) < 1) and L["Steuer letzte Woche"] or L["Steuer im Zahlungsziel"]
	if bal >= 0 then
		if due <= 0 then return nil end
		return "|cffffd100" .. label .. ":|r " .. self:FormatMoney(due) .. L[" |cff40ff40– aus dem Guthaben gedeckt|r"]
	end
	local open = -bal
	if a.status == "überfällig" then
		local overdue = -(bal + due)
		return LF("|cffff4040Zu zahlen: %s|r |cffff4040(davon überfällig %s)|r", self:FormatMoney(open), self:FormatMoney(overdue, true))
	end
	local covered = due - open
	return LF("|cffffd100Zu zahlen bis %s:|r %s", dueAt, self:FormatMoney(open))
		.. (covered > 0 and LF(" |cffaaaaaa(%s aus dem Guthaben gedeckt)|r", self:FormatMoney(covered, true)) or "")
end

function GS:AccountFor(char)
	local calc = self:Calc()
	return calc.accounts[self:AccountOf(char)]
end

GS.STATUS_COLOR = { ["quitt"] = "|cff40ff40", ["offen"] = "|cffffd100", ["überfällig"] = "|cffff4040" }

function GS:ColorStatus(s)
	return (self.STATUS_COLOR[s] or "|cffffffff") .. L[s] .. "|r"
end

-- Erlass/Stundung/Einsprüche je Konto: { [main] = { waive = {[w]=true}, defer = {[w]=bisWoche}, objections = {...} } }
function GS:ReliefIndex()
	local idx = {}
	local function of(a)
		local main = self:AccountOf(a)
		idx[main] = idx[main] or {}
		return idx[main]
	end
	local resolved = {}
	for _, e in ipairs(self:SortedADM("OBJR")) do
		if type(e.d.id) == "string" then resolved[e.d.id] = e end
	end
	for _, e in ipairs(self:SortedADM()) do
		local d = e.d
		local w = tonumber(d.w)
		if type(d.a) == "string" and w then
			if e.k == "WAIVE" then
				local r = of(d.a)
				r.waive = r.waive or {}
				r.waive[w] = true
			elseif e.k == "DEFER" then
				local r = of(d.a)
				r.defer = r.defer or {}
				local u = tonumber(d.u) or (w + 1)
				if not r.defer[w] or u > r.defer[w] then r.defer[w] = u end
			elseif e.k == "OBJ" then
				local r = of(d.a)
				r.objections = r.objections or {}
				local res = resolved[e.id]
				table.insert(r.objections, {
					id = e.id, author = e.au, time = e.tm, week = w, text = d.t or "",
					resolved = res ~= nil, decision = res and res.d.r, resolvedBy = res and res.au,
					reason = res and type(res.d.t) == "string" and res.d.t or nil, resolvedAt = res and res.tm,
				})
			end
		end
	end
	return idx
end

---------------------------------------------------------------------------
-- Befreiungen: Level-Grenze, Neulinge, Rang-Faktor
---------------------------------------------------------------------------
-- früheste Woche mit Addon-Daten in der ganzen Gilde (Einführung des Addons)
function GS:GuildFirstWeek()
	local g = self:G()
	local first
	for _, rep in pairs(g and g.reports or {}) do
		for w in pairs(rep.w or {}) do
			if not first or w < first then first = w end
		end
	end
	return first
end

-- früheste Woche mit Daten für ein Konto (Main + Twinks)
function GS:AccountFirstWeek(a)
	local g = self:G()
	local first
	for _, c in ipairs(a.chars or {}) do
		local rep = g and g.reports[c]
		for w in pairs(rep and rep.w or {}) do
			if not first or w < first then first = w end
		end
	end
	return first
end

-- Charaktere, deren Einnahmen besteuert werden (unter der Level-Grenze: steuerfrei)
function GS:CharLevel(name)
	if name == self.player and UnitLevel then return UnitLevel("player") end
	local r = self.roster[name]
	return r and r.level
end

function GS:TaxableChars(a, T)
	local limit = tonumber(T.exemptLevel) or 0
	if limit <= 0 then return a.chars, 0 end
	local list, exempt = {}, 0
	for _, c in ipairs(a.chars) do
		local lvl = self:CharLevel(c)
		if lvl and lvl > 0 and lvl < limit then exempt = exempt + 1 else list[#list + 1] = c end
	end
	return list, exempt
end

-- erstes Auftauchen im Gildenroster (Woche): Konto und ganze Gilde
function GS:SeenWeeks(a)
	local g = self:G()
	local seen = g and g.seen
	if not seen then return nil, nil end
	local acc, guild
	for name, t in pairs(seen) do
		if not guild or t < guild then guild = t end
	end
	for _, c in ipairs(a.chars or {}) do
		local t = seen[c]
		if t and (not acc or t < acc) then acc = t end
	end
	return acc and self:WeekOf(acc), guild and self:WeekOf(guild)
end

-- Steuerfaktor eines Kontos in Woche w: 0 = Neuling (befreit), sonst Rang-Faktor
function GS:TaxFactor(a, w, T)
	local weeks = tonumber(T.exemptWeeks) or 0
	if weeks > 0 then
		-- Neuling = erst nach Einführung des Addons im Gildenroster aufgetaucht
		-- (wer schon da war und das Addon nur später installiert, ist kein Neuling)
		local first, gfirst = self:SeenWeeks(a)
		if first and gfirst and first > gfirst and w < first + weeks then return 0, "Neuling" end
	end
	local ri = self:RankOf(a.main)
	local rf = ri and type(T.rankFactor) == "table" and tonumber(T.rankFactor[ri])
	if rf and rf >= 0 and rf ~= 1 then return rf, "Rang" end
	return 1, nil
end

-- Datenstand eines Kontos: wann hat der Besitzer zuletzt etwas geändert bzw. war unser Stand zuletzt synchron?
function GS:DataAge(a)
	local g = self:G()
	if not g or not a then return nil end
	local best
	for _, c in ipairs(a.chars or {}) do
		if c == self.player then return self:Now() end -- eigene Daten sind immer aktuell
		local rep = g.reports[c]
		for _, d in pairs(rep and rep.w or {}) do
			local t = tonumber(d.u) or tonumber(d.lt)
			if t and (not best or t > best) then best = t end
		end
		-- Heartbeat mit derselben Sequenz wie unsere Kopie: Stand war zu diesem Zeitpunkt aktuell
		local st = g.status[c]
		if st and st.hb and st.seq and rep and (rep.seq or 0) >= st.seq and (not best or st.hb > best) then best = st.hb end
	end
	return best
end

-- letzter bekannter Goldstand eines Charakters (aus dem Snapshot lg/lt); eigener Charakter: aktuell
function GS:CharGold(char)
	if char == self.player and GetMoney then return GetMoney(), self:Now() end
	local g = self:G()
	local rep = g and g.reports[char]
	local best
	for _, d in pairs(rep and rep.w or {}) do
		local lt, lg = tonumber(d.lt), tonumber(d.lg)
		if lt and lg and (not best or lt > best.lt) then best = { lg = lg, lt = lt } end
	end
	if best then return best.lg, best.lt end
end

-- Gesamtvermögen eines Kontos (Main + Twinks): Summe, Anzahl Charaktere ohne Angabe, ältester Stand
function GS:AccountWealth(a)
	local total, unknown, oldest = 0, 0, nil
	for _, c in ipairs(a and a.chars or {}) do
		local lg, lt = self:CharGold(c)
		if lg then
			total = total + lg
			if not oldest or lt < oldest then oldest = lt end
		else
			unknown = unknown + 1
		end
	end
	return total, unknown, oldest
end

-- Kennzahlen eines Kontos für die Statistik unter „Mein Konto“
-- n: Anzahl Wochen im Verlauf (bis einschließlich der laufenden)
function GS:AccountStats(a, n)
	n = n or 8
	local cur = self:CurrentWeek()
	local st = { loot = 0, quest = 0, vendor = 0, ah = 0, income = 0, tax = 0, taxIncome = 0, wk = 0, untaxed = 0,
		weeksWithData = 0, recent = {}, topWK = {} }
	local function inc(r) return (r.loot or 0) + (r.quest or 0) + (r.vendor or 0) + math.max(0, r.ahNet or 0) end
	local wkItems, repairs = {}, 0
	for w, r in pairs(a and a.weeks or {}) do
		local i = inc(r)
		st.loot, st.quest, st.vendor = st.loot + (r.loot or 0), st.quest + (r.quest or 0), st.vendor + (r.vendor or 0)
		st.ah = st.ah + math.max(0, r.ahNet or 0)
		st.income = st.income + i
		st.wk = st.wk + (r.wkActual or 0)
		st.untaxed = st.untaxed + (r.untaxed or 0)
		if i > 0 then st.weeksWithData = st.weeksWithData + 1 end
		if w < cur then
			st.tax = st.tax + (r.total or 0)
			st.taxIncome = st.taxIncome + i
		end
		if not st.best or i > st.best.income then st.best = { week = w, income = i } end
		local sum = self:AccountWeek(a.chars, w)
		local items = 0
		for id, x in pairs(sum.i or {}) do
			local c = sum.ci and sum.ci[id]
			local cost = math.max(0, (x[2] or 0) - (c and c[2] or 0)) -- doppelt gebuchte Käufe abziehen
			wkItems[id] = (wkItems[id] or 0) + cost
			items = items + cost
		end
		-- Werbungskosten ohne Item-Kauf sind Reparaturen
		repairs = repairs + math.max(0, (sum.k or 0) - (sum.kc or 0) - items)
	end
	for w = cur - n + 1, cur do
		local r = a and a.weeks[w]
		st.recent[#st.recent + 1] = {
			week = w, loot = r and r.loot or 0, quest = r and r.quest or 0, vendor = r and r.vendor or 0,
			ah = r and math.max(0, r.ahNet or 0) or 0, tax = r and r.total or 0, estimate = w >= cur,
		}
	end
	for id, cost in pairs(wkItems) do st.topWK[#st.topWK + 1] = { id = id, cost = cost } end
	if repairs > 0 then st.topWK[#st.topWK + 1] = { label = L["Reparaturen"], cost = repairs } end
	table.sort(st.topWK, function(x, y) return x.cost > y.cost end)
	st.rate = st.taxIncome > 0 and st.tax / st.taxIncome or 0
	st.avg = st.weeksWithData > 0 and st.income / st.weeksWithData or 0
	st.wealth, st.wealthUnknown = self:AccountWealth(a)
	return st
end

---------------------------------------------------------------------------
-- Korrektur einzelner Steuerposten durch Offiziere (Verwaltungsbuchung TCORR)
-- d = { a = Main, w = Woche, f = Posten, id = Item (optional), v = Betrag (+/-), n = Notiz }
---------------------------------------------------------------------------
GS.TCORR_FIELDS = {
	l = "Loot", q = "Quests", v = "Händler", a = "AH-Erlöse", e = "AH-Anzahlungen", f = "Zurückgezahlte Anzahlungen",
	k = "Werbungskosten", m = "Wareneinsatz",
}

function GS:TaxCorrIndex()
	local idx = {}
	for _, e in ipairs(self:SortedADM("TCORR")) do
		local d = e.d
		local w, v = tonumber(d.w), tonumber(d.v)
		if type(d.a) == "string" and w and v and self.TCORR_FIELDS[d.f] then
			local main = self:AccountOf(d.a)
			idx[main] = idx[main] or {}
			idx[main][w] = idx[main][w] or {}
			table.insert(idx[main][w], { f = d.f, id = tonumber(d.id), v = v, e = e })
		end
	end
	return idx
end

function GS:ApplyTaxCorr(sum, list)
	for _, c in ipairs(list or {}) do
		sum[c.f] = math.max(0, (sum[c.f] or 0) + c.v)
		local key = (c.f == "m" and "mi") or (c.f == "k" and "i") or nil
		local x = key and c.id and sum[key] and sum[key][c.id]
		if x then x[2] = math.max(0, x[2] + c.v) end
	end
	return sum
end

-- Posten eines Kontos in einer Woche für die Korrektur-Ansicht: erfasst, Korrektur, gilt
function GS:TaxPositions(main, w)
	local calc = self:Calc()
	local a = calc.accounts[main]
	if not a then return {} end
	local T = self:GetEffective("tariff", w)
	local raw = self:AccountWeek((self:TaxableChars(a, T)), w)
	local corr = {}
	for _, c in ipairs((self:TaxCorrIndex()[main] or {})[w] or {}) do
		local k = c.f .. "|" .. (c.id or "")
		corr[k] = (corr[k] or 0) + c.v
	end
	local rows = {}
	local function add(f, id, label, count, value)
		local k = f .. "|" .. (id or "")
		local cv = corr[k] or 0
		corr[k] = nil
		if (value or 0) == 0 and cv == 0 then return end
		rows[#rows + 1] = { f = f, id = id, label = label, count = count, raw = value or 0, corr = cv, cur = math.max(0, (value or 0) + cv) }
	end
	for _, f in ipairs({ "l", "q", "v", "a", "e", "f" }) do add(f, nil, L[self.TCORR_FIELDS[f]], nil, raw[f]) end
	-- Werbungskosten und Wareneinsatz je Item (eigene Gegenbuchungen „doppelt“ schon abgezogen)
	for _, spec in ipairs({ { f = "k", key = "i", fmt = L["Werbungskosten: %s"], rest = L["Werbungskosten: Reparaturen/Sonstiges"] },
		{ f = "m", key = "mi", fmt = L["Wareneinsatz: %s"], rest = L["Wareneinsatz: ohne Item"] } }) do
		local items = 0
		local ids = {}
		for id in pairs(raw[spec.key] or {}) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local x = raw[spec.key][id]
			local c = raw.ci and raw.ci[id]
			local cost = math.max(0, (x[2] or 0) - (c and c[2] or 0))
			items = items + cost
			add(spec.f, id, string.format(spec.fmt, self:ItemLabel(id)), x[1], cost)
		end
		local total = (raw[spec.f] or 0) - (spec.f == "m" and (raw.mc or 0) or (raw.kc or 0))
		local rest = math.max(0, total - items)
		add(spec.f, nil, spec.rest, nil, rest)
	end
	-- Korrekturen zu Posten, die es (nicht mehr) gibt
	for k, cv in pairs(corr) do
		local f, id = k:match("^(%a+)|(%d*)$")
		id = tonumber(id)
		rows[#rows + 1] = { f = f, id = id, label = (self.TCORR_FIELDS[f] and L[self.TCORR_FIELDS[f]] or f) .. (id and (": " .. self:ItemLabel(id)) or ""), raw = 0, corr = cv, cur = math.max(0, cv) }
	end
	return rows
end

---------------------------------------------------------------------------
-- Hundesteuer: fester Betrag pro Woche für jeden Jäger und Hexenmeister (Begleiter),
-- der in dieser Woche gespielt hat (Addon-Daten der Woche) und das Mindestlevel hat
---------------------------------------------------------------------------
GS.DOG_CLASSES = { HUNTER = true, WARLOCK = true }

-- Wert einer neuen Tarif-Einstellung: gespeicherter Wert, sonst Standard ab Einführung, davor 0
function GS:NewTariffValue(T, key, w, since)
	if T and T[key] ~= nil then return tonumber(T[key]) or 0 end
	if w >= self:WeekOf(since or NEW_TAX_SINCE) then return self.DEFAULTS.tariff[key] or 0 end
	return 0
end

function GS:DogTaxRate(T, w)
	local D = self.DEFAULTS.tariff
	return self:NewTariffValue(T, "dogTax", w), tonumber(T and T.dogTaxLevel) or D.dogTaxLevel
end

GS.CHURCH_CLASSES = { PRIEST = true, PALADIN = true }

-- Kirchenaustritt: Verwaltungsbuchung CHURCH { a = Konto, w = ab Woche, o = true (ausgetreten) / false (eingetreten) }
-- wirkt erst ab der nächsten Steuerwoche (wie beim Amt: nicht rückwirkend)
function GS:ChurchLeft(main, w)
	local state = false
	for _, e in ipairs(self:SortedADM("CHURCH")) do
		local d = e.d
		if type(d.a) == "string" and self:AccountOf(d.a) == main and tonumber(d.w) and tonumber(d.w) <= w then
			state = d.o and true or false
		end
	end
	return state
end

-- Stand ab der nächsten Woche (für die Anzeige: was gilt nach einem Austritt/Eintritt)
function GS:ChurchPending(main)
	return self:ChurchLeft(main, self:CurrentWeek() + 1)
end

function GS:SetChurchMember(member)
	local main = self:AccountOf(self.player)
	return self:CreateADM("CHURCH", { a = main, w = self:CurrentWeek() + 1, o = not member })
end

-- Zusatzsteuern nach der Einkommensteuer: Hunde-, Kirchen-, Alkohol- und Reittiersteuer
function GS:ApplyExtraTaxes(res, a, chars, sum, w, T, factor)
	factor = factor or 1
	self:ApplyDogTax(res, chars, w, T, factor)
	res.church, res.alc, res.mount, res.mountChars = 0, 0, 0, 0
	if factor <= 0 then return res end
	-- Kirchensteuer: Anteil der Einkommensteuer, wenn der Main Priester oder Paladin ist
	local cr = self:NewTariffValue(T, "churchTax", w)
	local mainInfo = a and self.roster[a.main]
	if cr > 0 and mainInfo and self.CHURCH_CLASSES[mainInfo.class] and not res.small and not self:ChurchLeft(a.main, w) then
		res.church = math.floor((res.est or 0) * cr * factor + 1e-6)
	end
	-- Alkoholsteuer: Anteil der Einkäufe alkoholischer Getränke
	local ar = self:NewTariffValue(T, "alcTax", w)
	if ar > 0 and (sum.al or 0) > 0 then
		res.alc = math.floor(sum.al * ar * factor + 1e-6)
		res.alcBase = sum.al
	end
	-- Reittiersteuer: je Charakter mit gelerntem Reiten, der in der Woche gespielt hat
	local mr = self:NewTariffValue(T, "mountTax", w)
	local n = math.floor(tonumber(sum.mr) or 0) -- nur die korrigierte Erkennung (mt hielt auch „Streitkolben“ für Reiten)
	if mr > 0 and n > 0 then
		res.mountChars = n
		res.mount = math.floor(n * mr * factor + 1e-6)
	end
	res.total = res.total + res.church + res.alc + res.mount
	return res
end

function GS:ApplyDogTax(res, chars, w, T, factor)
	local rate, minLevel = self:DogTaxRate(T, w)
	res.dog, res.dogChars = 0, 0
	if rate <= 0 or (factor or 1) <= 0 then return res end
	local g = self:G()
	local n = 0
	for _, c in ipairs(chars or {}) do
		local info = self.roster[c]
		local rep = g and g.reports[c]
		if info and self.DOG_CLASSES[info.class] and (info.level or 0) >= minLevel and rep and rep.w and rep.w[w] then
			n = n + 1
		end
	end
	if n > 0 then
		res.dogChars = n
		res.dog = math.floor(n * rate * (factor or 1) + 1e-6)
		res.total = res.total + res.dog
	end
	return res
end

---------------------------------------------------------------------------
-- Sparziele der Gilde (Verwaltungsbuchungen GOAL/GOALX): Fortschritt = festgesetzte Steuern seit dem Anlegen
---------------------------------------------------------------------------
function GS:Goals()
	local removed = {}
	for _, e in ipairs(self:SortedADM("GOALX")) do
		if type(e.d.id) == "string" then removed[e.d.id] = true end
	end
	local list = {}
	for _, e in ipairs(self:SortedADM("GOAL")) do
		local d = e.d
		local target, w = tonumber(d.v), tonumber(d.w)
		if not removed[e.id] and type(d.n) == "string" and target and target > 0 and w then
			list[#list + 1] = { id = e.id, name = d.n, target = target, week = w, author = e.au, time = e.tm }
		end
	end
	return list
end

-- erreicht: Gold in der Gildenbank (zuletzt gesehen; die gezahlten Steuern liegen dort schon drin).
-- Ist der Bankstand noch unbekannt: festgesetzte Steuern seit der Startwoche.
-- est: erwartete Steuer der laufenden Woche (noch nicht in der Bank); source: "bank" oder "tax"
function GS:GoalProgress(goal)
	local calc = self:Calc()
	local cur = calc.week
	local g = self:G()
	local paid, est = 0, 0
	for _, a in pairs(calc.accounts) do
		for w, r in pairs(a.weeks) do
			if w >= goal.week then
				if w < cur then paid = paid + (r.total or 0) else est = est + (r.total or 0) end
			end
		end
	end
	if g and g.bankMoney then return g.bankMoney.v, est, "bank", g.bankMoney.t end
	return paid, est, "tax"
end

-- Aufschlüsselung des Bankgolds für den Fortschrittsbalken:
--   Jede erfasste Gold-Einzahlung landet auf dem Konto des Einzahlers. Was davon noch als Guthaben (positiver Saldo)
--   da ist, ist „credit“; der Rest wurde für Steuern verbraucht („tax“). Gold, das sich nicht aus erfassten
--   Ein- und Auszahlungen erklärt (Altbestand vor dem Addon, Spenden ohne Log), ist „other“.
--   upcoming: Steuer der laufenden Woche, die noch nicht durch Guthaben gedeckt ist
function GS:GoalBreakdown(goal)
	local calc = self:Calc()
	local cur = calc.week
	local g = self:G()
	local taxSince, credit, upcoming = 0, 0, 0
	for _, a in pairs(calc.accounts) do
		for w, r in pairs(a.weeks) do
			if w >= goal.week and w < cur then taxSince = taxSince + (r.total or 0) end
		end
		local bal = math.max(0, a.bal or 0)
		credit = credit + bal
		local est = a.weeks[cur] and a.weeks[cur].total or 0
		upcoming = upcoming + math.max(0, est - bal)
	end
	local b = { upcoming = upcoming }
	if g and g.bankMoney then
		-- erfasster Netto-Goldfluss der Gildenbank (Einzahlungen minus Entnahmen und Reparaturen)
		local tracked = 0
		for _, e in ipairs(g.bank or {}) do
			if e.y == "D" then tracked = tracked + (e.n or 0)
			elseif e.y == "W" or e.y == "R" then tracked = tracked - (e.n or 0) end
		end
		local v = g.bankMoney.v
		b.known, b.t, b.bank = true, g.bankMoney.t, v
		b.other = math.max(0, v - math.max(0, tracked))
		local explained = v - b.other
		b.credit = math.min(explained, credit)
		b.tax = explained - b.credit
	else
		b.known, b.bank, b.credit, b.other, b.tax = false, taxSince, 0, 0, taxSince
	end
	return b
end

function GS:AddGoal(name, target)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return false, L["Bitte einen Namen für das Ziel angeben."] end
	if not target or target <= 0 then return false, L["Bitte einen Zielbetrag angeben (z. B. 50g)."] end
	return self:CreateADM("GOAL", { n = name:sub(1, 40), v = target, w = self:CurrentWeek() })
end

function GS:RemoveGoal(id)
	return self:CreateADM("GOALX", { id = id })
end

-- Einkommen einer Steuerwoche (Loot, Quests, Händler, AH-Gewinn)
function GS:WeekIncome(r)
	if not r then return 0 end
	return (r.loot or 0) + (r.quest or 0) + (r.vendor or 0) + math.max(0, r.ahNet or 0)
end

-- „Deine Woche im Überblick“ für den Steuerbescheid: kurze Zeilen (nil = abgeschlossene Woche ohne Daten)
function GS:WeekOverview(main, w)
	local calc = self:Calc()
	local a = calc.accounts[main]
	if not a or w >= calc.week then return nil end
	local r = a.weeks[w]
	if not r then return nil end
	local lines = {}
	local inc = self:WeekIncome(r)
	local prev = self:WeekIncome(a.weeks[w - 1])
	local cmp = ""
	if prev > 0 then
		local pct = math.floor((inc - prev) / prev * 100 + 0.5)
		if pct > 0 then cmp = LF(" |cff40ff40(+%d %% zur Vorwoche)|r", pct)
		elseif pct < 0 then cmp = LF(" |cffff8040(%d %% zur Vorwoche)|r", pct)
		else cmp = L[" |cffaaaaaa(wie in der Vorwoche)|r"] end
	end
	lines[#lines + 1] = LF("Eingenommen: %s", self:FormatMoney(inc)) .. cmp
	local tax = r.total or 0
	if tax > 0 then
		local rank, n = self:TaxRank(main, w)
		lines[#lines + 1] = LF("Steuer: %s", self:FormatMoney(tax))
			.. (inc > 0 and LF(" |cffaaaaaa(%s deines Einkommens)|r", self:FormatPercent(tax / inc)) or "")
		if rank then lines[#lines + 1] = LF("Platz %d von %d Steuerzahlern der Gilde", rank, n) end
	else
		lines[#lines + 1] = L["Steuer: |cff40ff40keine|r"]
	end
	for i, goal in ipairs(self:Goals()) do
		if i > 2 then break end
		local v = self:GoalProgress(goal)
		local pct = math.min(100, math.floor((v or 0) / goal.target * 100))
		lines[#lines + 1] = LF("Sparziel „%s“: %d %%", goal.name, pct)
			.. ((tax > 0 and w >= goal.week) and LF(" |cffaaaaaa– dein Beitrag diese Woche: %s|r", self:FormatMoney(tax, true)) or "")
	end
	return lines
end

-- Platz eines Kontos unter den Steuerzahlern einer Woche (nur Konten mit Steuer > 0)
function GS:TaxRank(main, w)
	if not main then return nil end
	local calc = self:Calc()
	local mine = calc.accounts[main] and calc.accounts[main].weeks[w]
	if not mine or (mine.total or 0) <= 0 then return nil end
	local rank, n = 1, 0
	for m, a in pairs(calc.accounts) do
		local r = a.weeks[w]
		if r and (r.total or 0) > 0 then
			n = n + 1
			if m ~= main and r.total > mine.total then rank = rank + 1 end
		end
	end
	return rank, n
end

-- Kennzahlen der ganzen Gilde für eine Woche (Reiter Statistik)
function GS:GuildMetrics(calc, w)
	local m = { accounts = 0, taxFree = 0, income = 0, tax = 0, wk = 0, openDebt = 0, overdueDebt = 0,
		bankIn = 0, bankOut = 0, wealth = 0 }
	for main, a in pairs(calc and calc.accounts or {}) do
		m.accounts = m.accounts + 1
		local r = a.weeks[w]
		local inc = r and ((r.loot or 0) + (r.quest or 0) + (r.vendor or 0) + math.max(0, r.ahNet or 0)) or 0
		m.income = m.income + inc
		m.tax = m.tax + (r and r.total or 0)
		m.wk = m.wk + (r and r.wkEff or 0)
		if not r or (r.total or 0) <= 0 then m.taxFree = m.taxFree + 1 end
		if inc > 0 and (not m.topEarner or inc > m.topEarner.income) then m.topEarner = { main = main, income = inc } end
		if (a.bal or 0) < 0 then
			m.openDebt = m.openDebt - a.bal
			if a.status == "überfällig" then m.overdueDebt = m.overdueDebt - a.bal end
		end
		for _, b in ipairs(a.bookings or {}) do
			if b.e and self:WeekOf(b.t) == w then
				if b.amount > 0 then m.bankIn = m.bankIn + b.amount elseif b.amount < 0 then m.bankOut = m.bankOut - b.amount end
			end
		end
		m.wealth = m.wealth + (self:AccountWealth(a))
	end
	m.rate = m.income > 0 and m.tax / m.income or 0
	return m
end

function GS:FormatDataAge(t)
	if not t then return L["|cff888888keine Daten|r"] end
	local age = self:Now() - t
	local color = age < 3600 and "|cff40ff40" or (age < 86400 and "|cffffd100" or "|cffff4040")
	return color .. self:FormatAgo(t) .. "|r"
end
