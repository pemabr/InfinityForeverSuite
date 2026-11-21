-- Finanzamt – Gildenbank-Log: Auslesen, Bewerten, Zusammenführen
--
-- Eintrag: { y = Typ, c = Charakter, i = ItemID (0 = Gold), n = Menge bzw. Kupfer, b = Tab,
--            t = geschätzte Zeit, ot = Zeitpunkt der ersten Beobachtung, v = Wert (Kupfer), s = Preisquelle }
-- Typen: d = Item-Einlage, w = Item-Entnahme, D = Gold-Einzahlung, W = Gold-Abhebung, R = Gildenreparatur
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local floor, abs = math.floor, math.abs

local function key(e)
	return e.y .. "|" .. e.c .. "|" .. e.i .. "|" .. e.n .. "|" .. e.b
end
GS.BankKey = key

GS.BANK_TYPE_LABEL = {
	d = "Item-Einlage",
	w = "Item-Entnahme",
	D = "Gold-Einzahlung",
	W = "Gold-Abhebung",
	R = "Gildenreparatur",
}

local function sane(e)
	if type(e) ~= "table" then return nil end
	local y = e.y
	if not GS.BANK_TYPE_LABEL[y] then return nil end
	local c = type(e.c) == "string" and e.c or nil
	local i, n, b, t = tonumber(e.i), tonumber(e.n), tonumber(e.b), tonumber(e.t)
	if not c or not i or not n or not b or not t or n <= 0 then return nil end
	return {
		y = y, c = c, i = floor(i), n = floor(n), b = floor(b), t = floor(t),
		ot = tonumber(e.ot), v = tonumber(e.v), s = type(e.s) == "string" and e.s or nil,
	}
end

local function index(bank)
	local idx = {}
	for _, e in ipairs(bank) do
		local k = key(e)
		local l = idx[k]
		if not l then
			l = {}
			idx[k] = l
		end
		l[#l + 1] = e
	end
	return idx
end

function GS:ValueEntry(e)
	if e.i == 0 then
		e.v, e.s = e.n, "gold"
		return
	end
	local unit, src = self:GetUnitPrice(e.i)
	local B = self:GetEffective("bank", self:CurrentWeek())
	e.v = floor((unit or 0) * e.n * (1 - (B.discount or 0)))
	e.s = src
end

-- list: Einträge; isLocal: aus eigener Beobachtung (dann neu bewerten)
function GS:MergeBankEntries(list, isLocal)
	local g = self:G()
	if not g then return false end
	local now = self:Now()
	local groups = {}
	for _, raw in ipairs(list) do
		local e = sane(raw)
		if e then
			local k = key(e)
			groups[k] = groups[k] or {}
			table.insert(groups[k], e)
		end
	end
	local idx = index(g.bank)
	local changed = false
	for k, inc in pairs(groups) do
		table.sort(inc, function(a, b) return a.t < b.t end)
		local stored = idx[k] or {}
		idx[k] = stored
		local used = {}
		for _, e in ipairs(inc) do
			local best, bestd
			for si, s in ipairs(stored) do
				if not used[si] then
					local d = abs(s.t - e.t)
					if d <= self.TOL and (not bestd or d < bestd) then best, bestd = si, d end
				end
			end
			if best then
				used[best] = true
				if not isLocal and e.ot and e.v then
					local s = stored[best]
					local sot = s.ot or math.huge
					-- deterministisch: frühere Beobachtung gewinnt (Zeit und Wert)
					if e.ot < sot or (e.ot == sot and (e.v < (s.v or 0) or (e.v == s.v and e.t < s.t))) then
						if s.v ~= e.v or s.t ~= e.t or s.s ~= e.s or s.ot ~= e.ot then
							s.v, s.s, s.ot, s.t = e.v, e.s, e.ot, e.t
							changed = true
						end
					end
				end
			else
				if isLocal or not e.v then
					e.ot = e.ot or now
					self:ValueEntry(e)
				end
				e.ot = e.ot or now
				g.bank[#g.bank + 1] = e
				stored[#stored + 1] = e
				used[#stored] = true
				changed = true
			end
		end
	end
	if changed then
		self:Invalidate()
		self:Fire("DATA_CHANGED")
	end
	return changed
end

-- Digest pro Woche (gleich, sobald beide Seiten denselben Stand haben)
function GS:BankDigest()
	local g = self:G()
	local d = {}
	if not g then return d end
	local perWeek = {}
	for _, e in ipairs(g.bank) do
		local w = self:WeekOf(e.t)
		perWeek[w] = perWeek[w] or {}
		table.insert(perWeek[w], key(e) .. "|" .. e.t .. "|" .. (e.v or 0))
	end
	for w, l in pairs(perWeek) do
		table.sort(l)
		d[w] = self:Hash(table.concat(l, ";"))
	end
	return d
end

function GS:BankEntriesOfWeek(w)
	local g = self:G()
	local out = {}
	if not g then return out end
	for _, e in ipairs(g.bank) do
		if self:WeekOf(e.t) == w then
			out[#out + 1] = { y = e.y, c = e.c, i = e.i, n = e.n, b = e.b, t = e.t, ot = e.ot, v = e.v, s = e.s }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Festgesetzte Werte (VAL-Verwaltungsbuchungen)
---------------------------------------------------------------------------
function GS:ValueOverrides()
	local map = {}
	for _, a in ipairs(self:SortedADM("VAL")) do
		local d = a.d
		if type(d.k) == "string" and tonumber(d.t) and tonumber(d.v) then
			map[d.k] = map[d.k] or {}
			table.insert(map[d.k], d)
		end
	end
	return map
end

function GS:EntryValue(e, overrides)
	if e.i == 0 then return e.n, "gold" end
	local l = overrides and overrides[key(e)]
	if l then
		local best, bestd
		for _, d in ipairs(l) do
			local dist = abs(d.t - e.t)
			if dist <= self.TOL * 2 and (not bestd or dist <= bestd) then best, bestd = d, dist end
		end
		if best then return floor(best.v), "manual" end
	end
	return e.v or 0, e.s or "none"
end

function GS:SetEntryValue(e, value)
	return self:CreateADM("VAL", { k = key(e), t = e.t, v = floor(value) })
end

---------------------------------------------------------------------------
-- Auslesen des Logs beim Öffnen der Gildenbank
---------------------------------------------------------------------------
local MONEY_TYPE = { deposit = "D", withdraw = "W", repair = "R" }

local function logTime(now, y, m, d, h)
	local hours = (((y or 0) * 365 + (m or 0) * 30 + (d or 0)) * 24) + (h or 0)
	return floor(now - hours * 3600 - 1800)
end

-- WoW zeigt je Tab (und für Gold) nur die letzten Einträge. Ist das Log voll und der älteste Eintrag jünger
-- als das letzte Auslesen (von irgendwem in der Gilde), können dazwischen Einträge verloren sein.
local LOG_MAX = 25
local function checkLogGap(key, n, oldest, now)
	local g = GS:G()
	g.bankRead = g.bankRead or {}
	local prev = g.bankRead[key]
	if n <= 0 then return end -- Tab (noch) nicht geladen oder leer
	if prev and n >= LOG_MAX and oldest and oldest > prev + 7200 then
		local tabName = key == 0 and "Gold" or ((GetGuildBankTabInfo and GetGuildBankTabInfo(key)) or ("Tab " .. key))
		local shown = key == 0 and L["Gold"] or tabName
		local text = LF("Log „%s“ war voll: Einträge zwischen %s und %s fehlen womöglich. Gildenbank öfter mit Addon öffnen.",
			shown, date("%d.%m. %H:%M", prev), date("%d.%m. %H:%M", oldest))
		GS:Flag("Gildenbank", "Log-Lücke " .. tabName, text, GS:WeekOf(oldest))
		if GS:HasRight(GS.player, "officer") then GS:Print(L["|cffff8040Gildenbank:|r "] .. text) end
	end
	if not prev or now > prev then g.bankRead[key] = now end
end

-- Lesezeitpunkte anderer übernehmen (spätester gewinnt)
function GS:MergeBankRead(br)
	local g = self:G()
	if not g or type(br) ~= "table" then return end
	g.bankRead = g.bankRead or {}
	local now = self:Now()
	for k, t in pairs(br) do
		k, t = tonumber(k), tonumber(t)
		if k and t and t <= now + 300 and t > (g.bankRead[k] or 0) then g.bankRead[k] = t end
	end
end

-- Gold in der Gildenbank (zuletzt gesehen, mit der Gilde geteilt): { v = Kupfer, t = Zeitpunkt }
function GS:MergeBankMoney(bm)
	local g = self:G()
	if not g or type(bm) ~= "table" then return false end
	local v, t = tonumber(bm.v or bm[1]), tonumber(bm.t or bm[2])
	if not v or not t or v < 0 or t > self:Now() + 300 then return false end
	if g.bankMoney and (g.bankMoney.t or 0) >= t then return false end
	g.bankMoney = { v = v, t = t }
	self:Fire("DATA_CHANGED")
	return true
end

function GS:NoteBankMoney()
	if not GetGuildBankMoney or not self:G() then return end
	local v = GetGuildBankMoney()
	if self.debug then self:Print(LF("Gildenbank-Gold gelesen: %s", tostring(v))) end
	if not v or v <= 0 then return end -- 0 = noch nicht geladen
	local g = self:G()
	if g.bankMoney and g.bankMoney.v == v and self:Now() - (g.bankMoney.t or 0) < 60 then return end
	if self:MergeBankMoney({ v = v, t = self:Now() }) then
		self:Debounce("bankmoney", 3, function() GS:Broadcast({ t = "BM", bm = GS:G().bankMoney }) end)
	end
end

function GS:LastBankRead()
	local g = self:G()
	local best
	for _, t in pairs(g and g.bankRead or {}) do
		if not best or t > best then best = t end
	end
	return best
end

function GS:ReadBankLogs()
	if not self:G() or not GetNumGuildBankTransactions then return end
	local now = self:Now()
	local obs = {}
	local ntabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
	for tab = 1, ntabs do
		local n = GetNumGuildBankTransactions(tab) or 0
		local oldest
		for i = 1, n do
			local _, _, _, _, _, _, y0, m0, d0, h0 = GetGuildBankTransaction(tab, i)
			local t0 = logTime(now, y0, m0, d0, h0)
			if not oldest or t0 < oldest then oldest = t0 end
		end
		checkLogGap(tab, n, oldest, now)
		for i = 1, n do
			local typ, name, link, count, _, _, y, m, d, h = GetGuildBankTransaction(tab, i)
			if name and link and (typ == "deposit" or typ == "withdraw") then
				local id = tonumber(link:match("item:(%d+)"))
				if id then
					obs[#obs + 1] = {
						y = (typ == "deposit") and "d" or "w", c = self:ResolveName(name), i = id,
						n = count or 1, b = tab, t = logTime(now, y, m, d, h),
					}
				end
			end
		end
	end
	if GetNumGuildBankMoneyTransactions then
		local n = GetNumGuildBankMoneyTransactions() or 0
		local oldest
		for i = 1, n do
			local _, _, _, y0, m0, d0, h0 = GetGuildBankMoneyTransaction(i)
			local t0 = logTime(now, y0, m0, d0, h0)
			if not oldest or t0 < oldest then oldest = t0 end
		end
		checkLogGap(0, n, oldest, now)
		for i = 1, n do
			local typ, name, amount, y, m, d, h = GetGuildBankMoneyTransaction(i)
			local yy = MONEY_TYPE[typ]
			if yy and name and amount and amount > 0 then
				obs[#obs + 1] = { y = yy, c = self:ResolveName(name), i = 0, n = amount, b = 0, t = logTime(now, y, m, d, h) }
			end
		end
	end
	if #obs > 0 and self:MergeBankEntries(obs, true) then
		self:ScheduleBankBroadcast()
	end
end

function GS:BankOpened()
	if self.bankOpen then return end
	self.bankOpen = true
	-- Goldstand der Gildenbank: ist erst nach einem Moment geladen, deshalb mehrfach versuchen
	for _, d in ipairs({ 0.5, 2, 5 }) do
		C_Timer.After(d, function() if GS.bankOpen then GS:NoteBankMoney() end end)
	end
	if not QueryGuildBankLog then return end
	local ntabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
	local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
	local step = 0
	for tab = 1, ntabs do
		C_Timer.After(0.4 * step, function() if GS.bankOpen then QueryGuildBankLog(tab) end end)
		step = step + 1
	end
	C_Timer.After(0.4 * step, function() if GS.bankOpen then QueryGuildBankLog(moneyTab) end end)
	C_Timer.After(0.4 * step + 2, function() GS:ReadBankLogs() end)
end

function GS:BankClosed()
	if not self.bankOpen then return end
	self.bankOpen = false
	self.bankClosedAt = GetTime()
	self:ReadBankLogs()
	self:Fire("STATUS_CHANGED")
end

GS:On("GUILDBANKFRAME_OPENED", function() GS:BankOpened() end)
GS:On("GUILDBANK_UPDATE_MONEY", function() if GS.bankOpen then GS:NoteBankMoney() end end)
GS:On("GUILDBANKFRAME_CLOSED", function() GS:BankClosed() end)
GS:On("GUILDBANKLOG_UPDATE", function()
	GS:Debounce("banklog", 1, function() GS:ReadBankLogs() end)
end)

local function isBanker(t)
	return Enum and Enum.PlayerInteractionType and t == Enum.PlayerInteractionType.GuildBanker
end
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(t) if isBanker(t) then GS:BankOpened() end end)
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(t) if isBanker(t) then GS:BankClosed() end end)

-- Offiziere erinnern, wenn das Gildenbank-Log lange von niemandem gelesen wurde (Einträge gehen sonst verloren)
GS:Register("GUILD_READY", function()
	C_Timer.After(90, function()
		if not GS:G() or not GS:HasRight(GS.player, "officer") then return end
		local last = GS:LastBankRead()
		if last and GS:Now() - last > 3 * 86400 then
			GS:Print(LF("|cffff8040Gildenbank:|r Das Log wurde seit %s von niemandem mit Addon gelesen. Bitte die Gildenbank öffnen, sonst gehen ältere Einträge verloren.",
				GS:FormatAgo(last)))
		end
	end)
end)
