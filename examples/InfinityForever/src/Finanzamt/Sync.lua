-- Finanzamt – Gilden-Sync, Heartbeat, Replikate, Plausibilitätschecks
--
-- Nachrichten (serialisierte Tabellen, bei Bedarf in Teile zerlegt):
--   HB   Heartbeat (Version, beanspruchter Main, eigene Sequenznummer, Konfig-Hash)
--   DIG  Digest aller bekannten Daten -> Gegenseite schickt, was fehlt
--   RQ   Anfrage nach Berichten eines Charakters ab Sequenznummer
--   REP  Wochenberichte eines Charakters
--   BNK  Gildenbank-Einträge
--   ADM  Verwaltungsbuchungen
--   SEC  Einstellungs-Versionen eines Abschnitts
--   PRM  Rechte-Matrix
--   PRC  AH-Preise
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local S = GS.Ser
local floor, max = math.floor, math.max

local HB_INTERVAL = 60
local SEND_INTERVAL = 0.35
local CHUNK = 238

---------------------------------------------------------------------------
-- Versand mit Drosselung
---------------------------------------------------------------------------
local queue = {}
local ticker

local function rawSend(text, dist, target)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		return C_ChatInfo.SendAddonMessage(GS.PREFIX, text, dist, target)
	elseif SendAddonMessage then
		return SendAddonMessage(GS.PREFIX, text, dist, target)
	end
end

-- Neuere Clients drosseln Addon-Nachrichten (kleiner Vorrat, dann etwa 1 pro Sekunde) und verwerfen
-- den Rest still. Das Ergebnis wird geprüft: gedrosselte Nachrichten bleiben in der Schlange und werden
-- später erneut versucht, statt verloren zu gehen.
local MAX_TRIES = 12
local lastPump = 0
GS.sendStats = { sent = 0, throttled = 0, dropped = 0, errors = 0 }
local function sendFailed(ok, res)
	if not ok then return true end
	if res == false then return true end
	if type(res) == "number" and res ~= 0 then return true end -- Enum.SendAddonMessageResult: 0 = Erfolg
	return false
end

local function pump()
	lastPump = GetTime()
	local item = queue[1]
	if not item then
		if ticker then ticker:Cancel(); ticker = nil end
		return
	end
	if item[2] == "GUILD" and not IsInGuild() then table.remove(queue, 1) return end
	local ok, res = pcall(rawSend, item[1], item[2], item[3])
	if sendFailed(ok, res) then
		item.tries = (item.tries or 0) + 1
		if not ok then GS.sendStats.errors = GS.sendStats.errors + 1 else GS.sendStats.throttled = GS.sendStats.throttled + 1 end
		if item.tries < MAX_TRIES then return end -- beim nächsten Takt noch einmal
		GS.sendStats.dropped = GS.sendStats.dropped + 1
		if GS.debug then GS:Print(LF("Sync: Nachricht verworfen (%s).", tostring(ok and res or "Fehler"))) end
	else
		GS.sendStats.sent = GS.sendStats.sent + 1
	end
	table.remove(queue, 1)
end

local function enqueue(text, dist, target, prio)
	if #queue > 2000 then return end
	if prio then table.insert(queue, 1, { text, dist, target }) else queue[#queue + 1] = { text, dist, target } end
	-- Wächter: ein Ticker, der seit Sekunden nicht mehr läuft, ist tot (z. B. nach einem Fehler) -> neu starten
	if ticker and GetTime() - lastPump > 5 then
		ticker:Cancel()
		ticker = nil
	end
	if not ticker then
		lastPump = GetTime()
		ticker = C_Timer.NewTicker(SEND_INTERVAL, pump)
	end
end

local msgCounter = 0
function GS:Send(msg, dist, target, prio)
	local data = S.Serialize(msg)
	if #data <= CHUNK + 10 then
		enqueue("S" .. data, dist, target, prio)
		return
	end
	msgCounter = (msgCounter + 1) % 1679616
	local id = string.format("%04x", (msgCounter + math.random(0, 4095) * 16) % 65536)
	local n = math.ceil(#data / CHUNK)
	for i = 1, n do
		enqueue("M" .. id .. ":" .. i .. ":" .. n .. ":" .. data:sub((i - 1) * CHUNK + 1, i * CHUNK), dist, target)
	end
end

function GS:Broadcast(msg, prio)
	if IsInGuild() then self:Send(msg, "GUILD", nil, prio) end
end

function GS:Whisper(target, msg)
	self:Send(msg, "WHISPER", target)
end

---------------------------------------------------------------------------
-- Empfang
---------------------------------------------------------------------------
local buffers = {}
local H = {}
local pending = {}

local function dispatch(sender, msg)
	if type(msg) ~= "table" or type(msg.t) ~= "string" then return end
	-- jede Nachricht beweist, dass das Addon beim Absender läuft (auch wenn sein Heartbeat ausbleibt)
	local g = GS:G()
	if g then
		local st = g.status[sender] or {}
		g.status[sender] = st
		st.rx = GS:Now()
	end
	local h = H[msg.t]
	if not h then return end
	h(sender, msg)
end

GS:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	if prefix ~= GS.PREFIX or not sender then return end
	sender = GS:ResolveName(sender)
	if sender == GS.player or not GS:G() then return end
	local kind = text:sub(1, 1)
	if kind == "S" then
		dispatch(sender, S.Deserialize(text:sub(2)))
	elseif kind == "M" then
		local id, i, n, part = text:match("^M(%x+):(%d+):(%d+):(.*)$")
		i, n = tonumber(i), tonumber(n)
		if not id or not i or not n or n > 500 then return end
		local key = sender .. ":" .. id
		local b = buffers[key]
		if not b then
			b = { n = n, parts = {}, got = 0, time = GetTime() }
			buffers[key] = b
		end
		if not b.parts[i] then
			b.parts[i] = part
			b.got = b.got + 1
		end
		if b.got >= b.n then
			buffers[key] = nil
			dispatch(sender, S.Deserialize(table.concat(b.parts)))
		end
	end
end)

GS:Ticker(30, function()
	local t = GetTime()
	for k, b in pairs(buffers) do
		if t - b.time > 300 then buffers[k] = nil end
	end
end)

-- Nachrichten, die Rechteprüfung brauchen, warten auf das Gildenroster
local function needRoster(fn)
	if GS.rosterLoaded then
		fn()
	else
		pending[#pending + 1] = fn
		GS:RequestRoster()
	end
end

GS:Register("ROSTER", function()
	if #pending == 0 then return end
	local list = pending
	pending = {}
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
end)

---------------------------------------------------------------------------
-- Digest / Konfig-Hash
---------------------------------------------------------------------------
function GS:ConfigHash()
	local parts = {}
	for _, n in ipairs(self.SECTIONS) do parts[#parts + 1] = self:SectionHash(n) end
	parts[#parts + 1] = self:PermsVer()
	parts[#parts + 1] = self:ADMHash()
	return self:Hash(table.concat(parts, ":"))
end

function GS:BuildDigest(isReply)
	local g = self:G()
	local r = {}
	for c, rep in pairs(g.reports) do r[c] = rep.seq or 0 end
	local x = {}
	for _, n in ipairs(self.SECTIONS) do x[n] = self:SectionHash(n) end
	return { t = "DIG", r = r, b = self:BankDigest(), br = g.bankRead, bm = g.bankMoney, a = self:ADMHash(), x = x, p = self:PermsVer(), fs = g.seen, rp = isReply or nil }
end

local lastDigTo = {}
function GS:RequestSync(peer, force)
	if not peer or not self:G() then return end
	local t = GetTime()
	if not force and lastDigTo[peer] and t - lastDigTo[peer] < 120 then return end
	lastDigTo[peer] = t
	self:Whisper(peer, self:BuildDigest(false))
end

---------------------------------------------------------------------------
-- Senden von Daten
---------------------------------------------------------------------------
local function copyWeek(d)
	local out = { s = d.s or 0 }
	for _, k in ipairs(GS.CATS) do out[k] = d[k] or 0 end
	if type(d.i) == "table" and next(d.i) then out.i = d.i end
	if type(d.mi) == "table" and next(d.mi) then out.mi = d.mi end
	if type(d.ci) == "table" and next(d.ci) then out.ci = d.ci end
	if type(d.ai) == "table" and next(d.ai) then out.ai = d.ai end -- Alkohol je Getränk (Anzahl, Preis)
	if d.lt and d.lg then out.lg, out.lt = d.lg, d.lt end -- Goldstand-Snapshot
	if d.u then out.u = d.u end -- Zeitpunkt der letzten Änderung
	if d.od then out.od = d.od end -- Online-Tage (Bitmaske)
	if d.pt then out.pt = d.pt end -- Spielzeit in Sekunden
	return out
end

function GS:SendReports(char, target, since)
	local g = self:G()
	local rep = g and g.reports[char]
	if not rep then return end
	since = since or 0
	local w = {}
	local any = false
	for week, d in pairs(rep.w) do
		if (d.s or 0) > since then
			w[week] = copyWeek(d)
			any = true
		end
	end
	if not any then return end
	local msg = { t = "REP", c = char, s = rep.seq, w = w }
	if target then self:Whisper(target, msg) else self:Broadcast(msg) end
end

local lastOwnSent = 0
function GS:ScheduleOwnBroadcast()
	self:Debounce("ownrep", 20, function()
		local rep = GS:OwnReport()
		if not rep then return end
		GS:SendReports(GS.player, nil, lastOwnSent)
		lastOwnSent = rep.seq
	end)
end

function GS:ScheduleBankBroadcast()
	self:Debounce("bankbc", 10, function()
		local cur = GS:CurrentWeek()
		local l = GS:BankEntriesOfWeek(cur)
		local prev = GS:BankEntriesOfWeek(cur - 1)
		for _, e in ipairs(prev) do l[#l + 1] = e end
		if #l > 0 then GS:Broadcast({ t = "BNK", l = l, br = GS:G().bankRead }) end
	end)
end

---------------------------------------------------------------------------
-- Berichte zusammenführen (Werte können innerhalb einer Woche nur steigen)
---------------------------------------------------------------------------
function GS:MergeReport(char, seq, weeks, sender)
	local g = self:G()
	if type(char) ~= "string" or type(weeks) ~= "table" then return end
	char = self:ResolveName(char)
	seq = tonumber(seq) or 0
	local rep = g.reports[char]
	if not rep then
		rep = { seq = 0, w = {} }
		g.reports[char] = rep
	end
	local changed, decreased = false, false
	for week, d in pairs(weeks) do
		week = tonumber(week)
		if week and type(d) == "table" then
			local cur = rep.w[week]
			if not cur then
				cur = { l = 0, q = 0, v = 0, a = 0, k = 0, i = {}, s = 0 }
				rep.w[week] = cur
			end
			for _, k in ipairs(self.CATS) do
				local nv = floor(tonumber(d[k]) or 0)
				local ov = cur[k] or 0
				if nv > ov then
					cur[k] = nv
					changed = true
				elseif nv < ov then
					decreased = true
				end
			end
			-- Spielaktivität: wächst innerhalb der Woche nur (Bitmaske bekommt nur Bits dazu)
			for _, k in ipairs({ "od", "pt" }) do
				local nv = tonumber(d[k])
				if nv and nv > (tonumber(cur[k]) or 0) then
					cur[k] = floor(nv)
					changed = true
				end
			end
			for _, key in ipairs({ "i", "mi", "ci", "ai" }) do
				if type(d[key]) == "table" then
					cur[key] = cur[key] or {}
					for id, x in pairs(d[key]) do
						id = tonumber(id)
						if id and type(x) == "table" then
							local o = cur[key][id] or { 0, 0 }
							local n1, c1 = tonumber(x[1]) or 0, tonumber(x[2]) or 0
							if n1 > o[1] or c1 > o[2] then
								cur[key][id] = { max(o[1], n1), max(o[2], c1) }
								changed = true
							end
						end
					end
				end
			end
			-- Goldstand: neuester Snapshot gewinnt (Gold darf auch sinken)
			local lt, lg = tonumber(d.lt), tonumber(d.lg)
			-- eigener Goldstand von vor dem Login (z. B. nach Absturz von der Gilde zurückgespielt)
			if char == self.player and lt and lg and self.NotePreLoginSnapshot then self:NotePreLoginSnapshot(lg, lt) end
			if lt and lg and lt > (cur.lt or 0) then
				cur.lt, cur.lg = lt, lg
				changed = true
			end
			cur.s = max(cur.s or 0, tonumber(d.s) or 0)
			local u = tonumber(d.u)
			if u and u > (cur.u or 0) then cur.u = u; changed = true end
		end
	end
	if seq > (rep.seq or 0) then rep.seq = seq end
	if decreased and sender == char then
		self:Flag(char, "Werte gesunken", L["Eigener Bericht enthielt niedrigere Werte als bereits bekannt"])
	end
	if changed then
		self:Invalidate()
		self:Fire("DATA_CHANGED")
	end
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------
local rollbackNotified = {}

H.HB = function(sender, msg)
	local g = GS:G()
	local st = g.status[sender] or {}
	g.status[sender] = st
	local nowT = GS:Now()
	if st.hb then
		-- vorherige Heartbeats merken (für die Absturz-Rückfrage LSQ)
		if nowT - st.hb > 90 then st.hbEnd = st.hb end
		st.hbPrev = st.hb
	end
	st.hb = nowT
	-- Entwicklerversion (dv): zählt nicht als veröffentlichte Version
	st.v = tonumber(msg.v)
	st.dev = tonumber(msg.dv) and true or nil
	st.vs = type(msg.vs) == "string" and msg.vs or nil
	st.m = type(msg.m) == "string" and msg.m or nil
	st.ak = type(msg.ak) == "string" and msg.ak or st.ak -- Account-Kennung (Twink-Erkennung)
	st.aw = st.aw or {}
	st.aw[GS:CurrentWeek()] = true
	if st.v and st.v > GS.VERSION_NUM then GS:RemindUpdate() end
	local s = tonumber(msg.s) or 0
	st.seq = s
	local rep = g.reports[sender]
	local mySeq = rep and rep.seq or 0
	if s > mySeq then
		GS:Whisper(sender, { t = "RQ", c = sender, s = mySeq })
	elseif s < mySeq then
		-- Daten beim Besitzer verschwunden oder zurückgesetzt -> markieren und zurückspielen
		if not rollbackNotified[sender] then
			rollbackNotified[sender] = true
			GS:Flag(sender, "Rücksprung", LF("Sequenz %d statt bekannter %d – Daten gelöscht oder zurückgesetzt?", s, mySeq))
			GS:SendReports(sender, sender, s)
		end
	end
	if msg.c and msg.c ~= GS:ConfigHash() then GS:RequestSync(sender) end
	GS:Fire("STATUS_CHANGED")
end

-- erzwungenes Update: alle schicken ihre aktuellen Daten
local lastPullFrom = {}
H.PULL = function(sender, msg)
	local t = GetTime()
	if lastPullFrom[sender] and t - lastPullFrom[sender] < 30 then return end
	lastPullFrom[sender] = t
	-- leicht versetzt antworten, damit nicht alle gleichzeitig senden
	C_Timer.After(math.random() * 3, function()
		GS:SendHeartbeat()
		local rep = GS:OwnReport()
		if rep then
			local cur = GS:CurrentWeek()
			local w = {}
			for week, dd in pairs(rep.w) do
				if week >= cur - 1 then w[week] = copyWeek(dd) end
			end
			if next(w) then GS:Whisper(sender, { t = "REP", c = GS.player, s = rep.seq, w = w }) end
		end
	end)
end

local lastForce = 0
function GS:ForceSync()
	if not self:G() then return false, L["Keine Gilde"] end
	local t = GetTime()
	if t - lastForce < 30 then
		return false, LF("Bitte noch %d Sekunden warten.", math.ceil(30 - (t - lastForce)))
	end
	lastForce = t
	self:Broadcast({ t = "PULL" })
	local peers = self:ActivePeers()
	for i, peer in ipairs(peers) do
		C_Timer.After(i * 1.5, function() GS:RequestSync(peer, true) end)
	end
	return true, #peers
end

-- Rückfrage nach einem Login mit Goldzuwachs: Wann lief das Addon des Fragenden zuletzt (vor seinem Login)?
local lastLSQ = {}
H.LSQ = function(sender, msg)
	local since = tonumber(msg.since)
	if not since then return end
	local t = GetTime()
	if lastLSQ[sender] and t - lastLSQ[sender] < 60 then return end
	lastLSQ[sender] = t
	local st = GS:G().status[sender]
	local best
	if st then
		for _, v in ipairs({ st.hb or false, st.hbPrev or false, st.hbEnd or false }) do
			v = tonumber(v)
			if v and v < since and (not best or v > best) then best = v end
		end
	end
	C_Timer.After(math.random() * 2, function()
		GS:Whisper(sender, { t = "LSA", hb = best })
		-- fehlende Daten zurückspielen
		GS:SendReports(sender, sender, tonumber(msg.s) or 0)
	end)
end

H.LSA = function(sender, msg)
	if GS.NoteSeenReply then GS:NoteSeenReply(msg.hb) end
end

H.RQ = function(sender, msg)
	if type(msg.c) ~= "string" then return end
	GS:SendReports(msg.c, sender, tonumber(msg.s) or 0)
end

H.REP = function(sender, msg)
	GS:MergeReport(msg.c, msg.s, msg.w, sender)
end

H.BNK = function(sender, msg)
	if type(msg.l) == "table" then GS:MergeBankEntries(msg.l, false) end
	GS:MergeBankRead(msg.br)
end

H.BM = function(sender, msg)
	GS:MergeBankMoney(msg.bm)
end

H.ADM = function(sender, msg)
	if type(msg.l) ~= "table" then return end
	needRoster(function()
		for _, e in ipairs(msg.l) do
			if GS:AddADM(e) == "denied" then
				GS:Flag(e.au or sender, "Unberechtigt", LF("Verwaltungsbuchung (%s) ohne Recht verworfen", tostring(e.k)))
			end
		end
	end)
end

H.SEC = function(sender, msg)
	if type(msg.l) ~= "table" or not GS.SECTION_RIGHT[msg.n] then return end
	needRoster(function()
		for _, v in ipairs(msg.l) do
			if GS:AddSectionVersion(msg.n, v) == "denied" then
				GS:Flag(type(v.author) == "string" and v.author or sender, "Unberechtigt", LF("Einstellungsänderung (%s) ohne Recht verworfen", tostring(msg.n)))
			end
		end
	end)
end

H.PRM = function(sender, msg)
	needRoster(function()
		if GS:SetPermsObj(msg.o) == "denied" then
			GS:Flag(sender, "Unberechtigt", L["Rechte-Matrix von Nicht-Gildenmeister verworfen"])
		end
	end)
end

H.PRC = function(sender, msg)
	needRoster(function() GS:ReceivePrices(sender, msg) end)
end

H.DIG = function(sender, msg)
	local g = GS:G()
	-- Berichte, die die Gegenseite nicht (vollständig) hat
	-- erstes Auftauchen im Roster: frühester bekannter Zeitpunkt gilt
	if type(msg.fs) == "table" then
		g.seen = g.seen or {}
		local changed = false
		for name, t in pairs(msg.fs) do
			t = tonumber(t)
			if type(name) == "string" and t and t > 0 and (not g.seen[name] or t < g.seen[name]) then
				g.seen[name] = t
				changed = true
			end
		end
		if changed then GS:Invalidate() end
	end
	GS:MergeBankRead(msg.br)
	GS:MergeBankMoney(msg.bm)
	local theirR = type(msg.r) == "table" and msg.r or {}
	for c, rep in pairs(g.reports) do
		local theirs = tonumber(theirR[c]) or 0
		if (rep.seq or 0) > theirs then GS:SendReports(c, sender, theirs) end
	end
	-- Gildenbank-Wochen mit abweichendem Stand
	local theirB = type(msg.b) == "table" and msg.b or {}
	for w, h in pairs(GS:BankDigest()) do
		if theirB[w] ~= h then
			local l = GS:BankEntriesOfWeek(w)
			if #l > 0 then GS:Whisper(sender, { t = "BNK", l = l }) end
		end
	end
	-- Verwaltungsbuchungen
	if msg.a ~= GS:ADMHash() then
		local l = {}
		for _, e in pairs(g.adm) do l[#l + 1] = e end
		if #l > 0 then GS:Whisper(sender, { t = "ADM", l = l }) end
	end
	-- Einstellungen
	local theirX = type(msg.x) == "table" and msg.x or {}
	for _, n in ipairs(GS.SECTIONS) do
		if theirX[n] ~= GS:SectionHash(n) and #g.sections[n] > 0 then
			GS:Whisper(sender, { t = "SEC", n = n, l = g.sections[n] })
		end
	end
	if g.perms and (tonumber(msg.p) or 0) < g.perms.ver then
		GS:Whisper(sender, { t = "PRM", o = g.perms })
	end
	if not msg.rp then GS:Whisper(sender, GS:BuildDigest(true)) end
end

---------------------------------------------------------------------------
-- Heartbeat und periodischer Abgleich
---------------------------------------------------------------------------
function GS:SendHeartbeat()
	local g = self:G()
	if not g then return end
	local rep = self:OwnReport()
	self:NormalizeClaim()
	if self.UpdateRidingFlag then self:UpdateRidingFlag() end
	local claim = self:MyChar().main
	-- Entwicklerversion: Versionsnummer nicht als „v“ melden, damit andere sie nicht für die neueste halten
	-- (auch ältere Addon-Versionen werten nur „v“ aus)
	local dev = self.db.devVersion and true or false
	local v = (not dev) and self.VERSION_NUM or nil
	local vs = self.VERSION .. (dev and " (Dev)" or "")
	-- Vorrang: der Heartbeat soll nicht hinter einem großen Abgleich in der Warteschlange hängen
	self:Broadcast({
		t = "HB", v = v, dv = dev and self.VERSION_NUM or nil, vs = vs, m = claim,
		s = rep and rep.seq or 0, c = self:ConfigHash(), ak = self.db.accountToken,
	}, true)
	local st = g.status[self.player] or {}
	g.status[self.player] = st
	st.hb, st.v, st.vs, st.m, st.ak = self:Now(), v, vs, claim, self.db.accountToken
	st.dev = dev or nil
end

-- neueste veröffentlichte Version in der Gilde (Heartbeats der letzten 14 Tage, ohne Entwicklerversionen)
function GS:NewestReleasedVersion()
	local g = self:G()
	local best, bestS, who
	if not g then return nil end
	local now = self:Now()
	for name, st in pairs(g.status) do
		if name ~= self.player and st.v and not st.dev and st.hb and now - st.hb < 14 * 86400 then
			if not best or st.v > best then best, bestS, who = st.v, st.vs, name end
		end
	end
	return best, bestS, who
end

-- Erinnerung an ein Update: im Chat einmal pro Sitzung, als Fenster höchstens einmal am Tag
function GS:RemindUpdate()
	local newest, vs, who = self:NewestReleasedVersion()
	if not newest or newest <= self.VERSION_NUM then return false end
	if not self._updateNagged then
		self._updateNagged = true
		self:Print(LF("|cffff8040Deine Version %s ist veraltet|r – %s nutzt schon %s. Bitte das Addon aktualisieren (z. B. über CurseForge), damit Steuern und Sync richtig laufen.",
			self.VERSION, who or L["jemand"], vs or L["eine neuere"]))
	end
	local today = date("%Y-%m-%d", self:Now())
	if self.db.updatePopupDay ~= today and StaticPopupDialogs and StaticPopup_Show and not (InCombatLockdown and InCombatLockdown()) then
		self.db.updatePopupDay = today
		if not StaticPopupDialogs.FINANZAMT_UPDATE then
			StaticPopupDialogs.FINANZAMT_UPDATE = {
				text = "%s", button1 = OKAY or "OK",
				timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
			}
		end
		StaticPopup_Show("FINANZAMT_UPDATE", LF("Finanzamt\n\nDeine Version %s ist veraltet.\n%s nutzt schon %s.\n\nBitte das Addon aktualisieren, damit Steuern und Sync richtig laufen.",
			self.VERSION, who or L["Ein Gildenmitglied"], vs or L["eine neuere Version"]))
	end
	return true
end
GS:Register("GUILD_READY", function() C_Timer.After(60, function() GS:RemindUpdate() end) end)

function GS:ActivePeers()
	local g = self:G()
	local list = {}
	if not g then return list end
	local now = self:Now()
	local timeout = (self:GetLatest("tariff").activeMin or 3) * 60
	for name, st in pairs(g.status) do
		if name ~= self.player and st.hb and now - st.hb < timeout then
			local r = self.roster[name]
			if not r or r.online then list[#list + 1] = name end
		end
	end
	return list
end

function GS:PickPeer()
	local peers = self:ActivePeers()
	if #peers == 0 then return nil end
	table.sort(peers, function(a, b)
		local oa, ob = self:HasRight(a, "officer"), self:HasRight(b, "officer")
		if oa ~= ob then return oa end
		return a < b
	end)
	if self:HasRight(peers[1], "officer") then return peers[1] end
	return peers[math.random(1, #peers)]
end

local function initialSync(attempt)
	local peer = GS:PickPeer()
	if peer then
		GS:RequestSync(peer, true)
	elseif attempt < 10 then
		C_Timer.After(60, function() initialSync(attempt + 1) end)
	end
end

-- "Online ohne Addon" / "Keine Daten trotz Online-Zeit" beobachten
local function observeOnline()
	local g = GS:G()
	if not g then return end
	local now = GS:Now()
	local week = GS:CurrentWeek()
	for name, since in pairs(GS.onlineSince) do
		if now - since > 300 then
			g.online[name] = g.online[name] or {}
			g.online[name][week] = true
		end
	end
end

local started = false
GS:Register("GUILD_READY", function()
	if started then return end
	started = true
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(GS.PREFIX)
	elseif RegisterAddonMessagePrefix then
		RegisterAddonMessagePrefix(GS.PREFIX)
	end
	GS:OwnReport()
	C_Timer.After(5, function() GS:SendHeartbeat() end)
	GS:Ticker(HB_INTERVAL, function()
		GS:SendHeartbeat()
		GS:RequestRoster()
		observeOnline()
		GS:Fire("STATUS_CHANGED")
	end)
	C_Timer.After(20, function() initialSync(1) end)
	GS:Ticker(900, function()
		local peer = GS:PickPeer()
		if peer then GS:RequestSync(peer) end
	end)
	-- Eigene Daten der laufenden Woche einmal verteilen
	C_Timer.After(15, function()
		GS:SendReports(GS.player, nil, 0)
		local rep = GS:OwnReport()
		lastOwnSent = rep and rep.seq or 0
	end)
end)

-- Addon-Status eines Kontos (Main + Twinks): Warnung "online ohne Addon" zuerst, sonst der beste Status
local STATUS_RANK = {
	["online ohne Addon"] = 1, ["aktiv"] = 2, ["aktiv (alte Version)"] = 3, ["offline"] = 4,
	["veraltet (Version)"] = 5, ["veraltet"] = 6, ["nie gesehen"] = 7,
}
function GS:AccountAddonStatus(a)
	local bestSt, bestCol, bestChar
	for _, ch in ipairs(a and a.chars or {}) do
		local st, col = self:MemberStatus(ch)
		if not bestSt or (STATUS_RANK[st] or 9) < (STATUS_RANK[bestSt] or 9) then
			bestSt, bestCol, bestChar = st, col, ch
		end
	end
	if not bestSt then return self:MemberStatus(a and a.main) end
	-- Twink statt Main: Namen dazuschreiben
	if bestChar ~= a.main and bestSt ~= "nie gesehen" then bestSt = bestSt .. " (Twink)" end
	return bestSt, bestCol
end

-- Version des Kontos: neueste gemeldete Version über alle Charaktere desselben Kontos
-- (Main/Twinks laut Zuordnung oder gleiche Account-Kennung). Ein Twink, der länger nicht eingeloggt war,
-- übernimmt so die Version, die das Konto auf einem anderen Charakter schon nutzt.
-- Rückgabe: v, vs, Charakter, letzter Heartbeat des Kontos
function GS:AccountVersion(name)
	local g = self:G()
	if not g then return nil end
	local own = g.status[name]
	local acc = self:AccountOf(name)
	local ak = own and own.ak
	local bestV, bestS, bestC, lastHb
	for n, s in pairs(g.status) do
		if n == name or self:AccountOf(n) == acc or (ak and s.ak == ak) then
			if s.v and (not bestV or s.v > bestV) then bestV, bestS, bestC = s.v, s.vs, n end
			if s.hb and (not lastHb or s.hb > lastHb) then lastHb = s.hb end
		end
	end
	return bestV, bestS, bestC, lastHb
end

-- Letztes Lebenszeichen des Addons für ein Konto: Heartbeat (nur wenn man gleichzeitig online war) oder
-- Zeitpunkt der letzten Änderung in den Wochenberichten (werden über andere Mitglieder weitergereicht).
-- nil = von diesem Konto nie Addon-Daten gesehen
function GS:LastAddonSign(name)
	local g = self:G()
	if not g then return nil end
	local _, _, _, last = self:AccountVersion(name)
	local acc = self:AccountOf(name)
	for n, rep in pairs(g.reports) do
		if (n == name or self:AccountOf(n) == acc) and type(rep.w) == "table" then
			for w, d in pairs(rep.w) do
				local t = tonumber(d.u) or (next(d) and self:WeekStart(w)) or nil
				if t and (not last or t > last) then last = t end
			end
		end
	end
	return last
end

-- Status eines Mitglieds für die Offiziersliste
function GS:MemberStatus(name)
	local g = self:G()
	local st = g and g.status[name]
	local r = self.roster[name]
	local now = self:Now()
	local T = self:GetLatest("tariff")
	local timeout = (T.activeMin or 3) * 60
	-- Vergleich mit der neuesten veröffentlichten Version (eine eigene Entwicklerversion zählt nicht)
	local newest = (self.db and self.db.devVersion) and 0 or self.VERSION_NUM
	if g then
		for _, s in pairs(g.status) do
			if s.v and s.v > newest then newest = s.v end
		end
	end
	if name == self.player then return "aktiv", "|cff40ff40" end
	-- Version und letzter Heartbeat des ganzen Kontos (andere Charaktere desselben Kontos zählen mit)
	local accV, _, _, accHb = self:AccountVersion(name)
	local ver = accV or (st and st.v)
	if st and st.hb and now - st.hb < timeout then
		if ver and ver < newest then return "aktiv (alte Version)", "|cffffd100" end
		return "aktiv", "|cff40ff40"
	end
	-- kein frischer Heartbeat, aber andere Lebenszeichen: Nachrichten des Spielers oder neue Wochendaten
	-- (die Spielzeit wird beim Spielen alle 15 Minuten verteilt)
	if r and r.online then
		local sign = math.max(st and st.rx or 0, self:LastAddonSign(name) or 0)
		if now - sign < 20 * 60 then
			if ver and ver < newest then return "aktiv (alte Version)", "|cffffd100" end
			return "aktiv", "|cff40ff40"
		end
	end
	if r and r.online and self.onlineSince[name] and now - self.onlineSince[name] > timeout then
		return "online ohne Addon", "|cffff4040"
	end
	if st and st.hb then
		local last = math.max(st.hb, accHb or 0)
		if now - last > (T.staleDays or 7) * 86400 then return "veraltet", "|cffff8040" end
		if ver and ver < newest then return "veraltet (Version)", "|cffff8040" end
		return "offline", "|cffaaaaaa"
	end
	-- kein eigener Heartbeat: Berichte oder andere Charaktere des Kontos zeigen trotzdem, dass das Addon läuft
	local last = self:LastAddonSign(name)
	if last then
		if now - last > (T.staleDays or 7) * 86400 then return "veraltet", "|cffff8040" end
		if ver and ver < newest then return "veraltet (Version)", "|cffff8040" end
		return "offline", "|cffaaaaaa"
	end
	return "nie gesehen", "|cffff8040"
end
