-- Finanzamt – Kern: Events, Hilfsfunktionen, Datenbank, Steuerwochen, Gildenroster
local ADDON, ns = ...
local GS = {}
ns.GS = GS
_G.Finanzamt = GS

GS.VERSION = "1.0.14"
GS.VERSION_NUM = 16
GS.PREFIX = "FINANZAMT"
GS.TOL = 7200 -- Toleranz (Sekunden) beim Zusammenführen von Bank-Log-Einträgen

local floor, abs = math.floor, math.abs

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}

function GS:On(event, fn)
	local list = handlers[event]
	if not list then
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then return false end
		list = {}
		handlers[event] = list
	end
	list[#list + 1] = fn
	return true
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end)

-- interne Nachrichten
local callbacks = {}
function GS:Register(msg, fn)
	callbacks[msg] = callbacks[msg] or {}
	table.insert(callbacks[msg], fn)
end
function GS:Fire(msg, ...)
	local list = callbacks[msg]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end

local debounces = {}
function GS:Debounce(key, sec, fn)
	if debounces[key] then return end
	debounces[key] = true
	C_Timer.After(sec, function()
		debounces[key] = nil
		fn()
	end)
end

-- Ticker, der einen Fehler übersteht: Blizzards C_Timer.NewTicker plant den nächsten Lauf erst nach dem
-- Aufruf ein – wirft die Funktion einmal einen Fehler, läuft der Ticker nie wieder (z. B. kein Heartbeat mehr).
function GS:Ticker(sec, fn)
	return C_Timer.NewTicker(sec, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
	end)
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
function GS:Now()
	if GetServerTime then return GetServerTime() end
	return time()
end

function GS:Print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Finanzamt:|r " .. string.join(" ", tostringall(...)))
end

function GS:Short(name)
	if not name then return nil end
	return (name:gsub("%-.*$", ""))
end

function GS:Copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = self:Copy(v) end
	return c
end

-- Deterministische Textform (für Hashes und Vergleiche)
function GS:Canon(v)
	local t = type(v)
	if t == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then return ta < tb end
			return a < b
		end)
		local out = {}
		for _, k in ipairs(keys) do out[#out + 1] = self:Canon(k) .. "=" .. self:Canon(v[k]) end
		return "{" .. table.concat(out, ",") .. "}"
	elseif t == "number" then
		if v == floor(v) then return string.format("%.0f", v) end
		return string.format("%.6g", v)
	end
	return tostring(v)
end

function GS:Hash(str)
	local h = 5381
	for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end
	return h
end

local GOLD, SILVER, COPPER, COPPER_EN = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fk|r", "|cffeda55fc|r"
function GS:FormatMoney(c, plain)
	c = tonumber(c) or 0
	local sign = ""
	if c < 0 then sign = "-"; c = -c end
	c = floor(c + 1e-6) -- auf volles Kupfer abrunden
	local g, s, k = floor(c / 10000), floor(c / 100) % 100, c % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. (plain and "g" or GOLD) end
	if s > 0 then parts[#parts + 1] = s .. (plain and "s" or SILVER) end
	if k > 0 or #parts == 0 then
		local en = GS.Lang and GS:Lang() ~= "de"
		parts[#parts + 1] = k .. (plain and (en and "c" or "k") or (en and COPPER_EN or COPPER))
	end
	return sign .. table.concat(parts, " ")
end

-- "1g 20s 5k", "-30s", "150" (= Kupfer)
function GS:ParseMoney(str)
	if not str then return nil end
	str = str:lower():gsub("%s+", "")
	if str == "" then return nil end
	local neg = false
	if str:sub(1, 1) == "-" then neg = true; str = str:sub(2) end
	if str:match("^%d+$") then
		local v = tonumber(str)
		return neg and -v or v
	end
	local total, matched = 0, false
	local rest = str:gsub("(%d+)([gskc])", function(n, u)
		matched = true
		n = tonumber(n)
		if u == "g" then total = total + n * 10000
		elseif u == "s" then total = total + n * 100
		else total = total + n end
		return ""
	end)
	if not matched or rest ~= "" then return nil end
	return neg and -total or total
end

function GS:ParsePercent(str)
	if not str then return nil end
	local s = str:gsub(",", "."):gsub("%%", ""):gsub("%s+", "")
	local v = tonumber(s)
	if not v then return nil end
	return v / 100
end

function GS:FormatPercent(f)
	local s = string.format("%.2f", (f or 0) * 100):gsub("%.?0+$", "")
	return (s:gsub("%.", ","))
end

function GS:FormatTime(t)
	if not t then return "-" end
	return date("%d.%m. %H:%M", t)
end

function GS:FormatAgo(t)
	local L = GS.L
	if not t then return L["nie"] end
	local d = self:Now() - t
	if d < 120 then return L["gerade eben"] end
	if d < 7200 then return GS.LF("%d Min.", floor(d / 60)) end
	if d < 172800 then return GS.LF("%d Std.", floor(d / 3600)) end
	return GS.LF("%d Tage", floor(d / 86400))
end

-- Kompatibilität: neuere Clients (auch WoW Forever) haben viele alte globale
-- Funktionen nur noch unter C_Item / C_MerchantFrame
function GS.GetItemInfo(id)
	if not id then return nil end
	local f = _G.GetItemInfo or (C_Item and C_Item.GetItemInfo)
	if not f then return nil end
	return f(id)
end

-- Stapelgröße eines Händler-Items (alte API: GetMerchantItemInfo, neue: C_MerchantFrame.GetItemInfo)
function GS.MerchantStack(index)
	if _G.GetMerchantItemInfo then
		local _, _, _, stack = _G.GetMerchantItemInfo(index)
		return stack
	end
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
		if ok and type(info) == "table" then return info.stackCount end
	end
	return nil
end

-- Item-ID eines Händler-Items
function GS.MerchantItemID(index)
	if _G.GetMerchantItemID then return _G.GetMerchantItemID(index) end
	local link = _G.GetMerchantItemLink and _G.GetMerchantItemLink(index)
	return link and tonumber(link:match("item:(%d+)"))
end

-- Item-Daten: Namen kennt der Client erst nach einer Server-Anfrage
local requestedItems = {}
function GS:RequestItem(id)
	if not id or requestedItems[id] then return end
	requestedItems[id] = true
	if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
end

function GS:ItemName(id)
	if not id or id == 0 then return GS.L["Gold"] end
	local name = GS.GetItemInfo(id)
	if name then return name end
	self:RequestItem(id)
	return "Item #" .. id
end

function GS:ItemIcon(id)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and icon then return icon end
	end
	if _G.GetItemIcon then
		local icon = _G.GetItemIcon(id)
		if icon then return icon end
	end
	return select(10, GS.GetItemInfo(id))
end

-- Icon + Name in Qualitätsfarbe (für Tabellen)
function GS:ItemLabel(id)
	if not id or id == 0 then return GS.L["Gold"] end
	local name, _, quality = GS.GetItemInfo(id)
	local txt
	if name then
		local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
		txt = (c and c.hex) and (c.hex .. name .. "|r") or name
	else
		self:RequestItem(id)
		txt = "Item #" .. id .. GS.L[" |cff888888(lädt ...)|r"]
	end
	local icon = self:ItemIcon(id)
	if icon then txt = "|T" .. icon .. ":14:14|t " .. txt end
	return txt
end

GS:On("GET_ITEM_INFO_RECEIVED", function()
	GS:Debounce("iteminfo", 0.5, function() GS:Fire("ITEM_INFO") end)
end)

---------------------------------------------------------------------------
-- Steuerwochen (Reset konfigurierbar, Zeiten in UTC)
---------------------------------------------------------------------------
local BASE = 1704067200 -- Montag, 01.01.2024 00:00 UTC

function GS:Anchor()
	local cal = self:GetLatest("tariff")
	return BASE + ((cal.resetDay or 3) - 1) * 86400 + (cal.resetHour or 4) * 3600
end

function GS:WeekOf(t)
	return floor(((t or self:Now()) - self:Anchor()) / 604800)
end

function GS:CurrentWeek()
	return self:WeekOf(self:Now())
end

function GS:WeekStart(w)
	return self:Anchor() + w * 604800
end

function GS:WeekLabel(w)
	local s = self:WeekStart(w)
	return date("%d.%m.", s) .. " – " .. date("%d.%m.", s + 604800 - 1)
end

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
function GS:G()
	if self.g then return self.g end
	if not self.db then return nil end
	local db = self.db
	local guid = UnitGUID and UnitGUID("player")
	db.guildByGUID = db.guildByGUID or {}
	local gname = GetGuildInfo("player")
	local key
	if gname then
		key = gname .. "@" .. (GetRealmName() or "?")
		if guid then
			db.guildByGUID[guid] = key
			db.names = db.names or {}
			if self.player and not db.names[guid] then db.names[guid] = self.player end
		end
	else
		-- direkt nach dem Login kennt WoW den Gildennamen noch nicht: zuletzt bekannte Gilde verwenden
		if not IsInGuild() or not guid or not db.guildByGUID[guid] then return nil end
		key = db.guildByGUID[guid]
		self.guildFromCache = true
	end
	db.guilds = db.guilds or {}
	local g = db.guilds[key]
	if not g then
		g = {}
		db.guilds[key] = g
	end
	g.sections = g.sections or {}
	for _, name in ipairs(self.SECTIONS) do
		g.sections[name] = g.sections[name] or {}
		for _, v in ipairs(g.sections[name]) do self:FillDefaults(v.data, self.DEFAULTS[name]) end
	end
	g.reports = g.reports or {}
	g.bank = g.bank or {}
	g.adm = g.adm or {}
	g.status = g.status or {}
	g.flags = g.flags or {}
	g.online = g.online or {}
	g.prices = g.prices or {}
	self.g = g
	self.guildKey = key
	return g
end

function GS:TryGuild()
	if not self.db then return end
	-- vorläufig aus dem Speicher geladen: prüfen, ob die Gilde noch stimmt
	if self.g and self.guildFromCache then
		local gname = GetGuildInfo("player")
		if gname then
			self.guildFromCache = false
			local key = gname .. "@" .. (GetRealmName() or "?")
			local guid = UnitGUID and UnitGUID("player")
			if guid then self.db.guildByGUID[guid] = key end
			if key ~= self.guildKey then
				-- Gilde gewechselt: auf die richtige Gilde umschalten
				self.g = nil
				if self.Invalidate then self:Invalidate() end
				if self:G() then self:Fire("GUILD_READY") end
			end
		end
		return
	end
	if self.g then return end
	if not IsInGuild() then return end
	if self:G() then
		self:Fire("GUILD_READY")
	end
end

GS:On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	FinanzamtDB = FinanzamtDB or {}
	FinanzamtDB.chars = FinanzamtDB.chars or {}
	FinanzamtDB.names = FinanzamtDB.names or {}
	-- zufällige Kennung dieses WoW-Accounts (keine echten Account-Daten), um Twinks zu erkennen
	if not FinanzamtDB.accountToken then
		FinanzamtDB.accountToken = string.format("%06x%06x", math.random(0, 0xffffff), math.random(0, 0xffffff))
	end
	GS.db = FinanzamtDB
	GS.debug = FinanzamtDB.debug and true or false -- Debug-Modus übersteht /reload
	GS.player = GS:InitialPlayerName()
	GS:Fire("DB_READY")
end)

-- Gespeicherter voller Name (pro Charakter-GUID), sonst UnitName
function GS:InitialPlayerName()
	local guid = UnitGUID and UnitGUID("player")
	local stored = guid and self.db and self.db.names and self.db.names[guid]
	return stored or self:Short(UnitName("player"))
end

GS:On("PLAYER_LOGIN", function()
	if GS.debug then C_Timer.After(3, function() GS:Print(GS.L["Debug-Modus ist aktiv (/gst debug zum Ausschalten)."]) end) end
	GS.player = GS:InitialPlayerName()
	GS:TryGuild()
	C_Timer.After(3, function() GS:RequestRoster() end)
end)
GS:On("PLAYER_GUILD_UPDATE", function() GS:TryGuild() end)

function GS:MyChar()
	local c = self.db.chars[self.player]
	if not c then
		c = {}
		self.db.chars[self.player] = c
	end
	return c
end

---------------------------------------------------------------------------
-- Gildenroster
---------------------------------------------------------------------------
GS.roster = {}
GS.rosterLoaded = false
GS.onlineSince = {}

function GS:RequestRoster()
	if not IsInGuild() then return end
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end

function GS:UpdateRoster()
	local n = GetNumGuildMembers()
	if not n or n == 0 then return end
	local now = self:Now()
	local roster = {}
	local alias, ambiguous = {}, {}
	local myGUID = UnitGUID and UnitGUID("player")
	local myName
	for i = 1, n do
		local name, rankName, rankIndex, level, _, _, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
		if name then
			name = self:Short(name)
			roster[name] = { rank = rankName, rankIndex = rankIndex, level = level, online = online, class = class, guid = guid }
			if online then
				self.onlineSince[name] = self.onlineSince[name] or now
			else
				self.onlineSince[name] = nil
			end
			if myGUID and guid == myGUID then myName = name end
			-- WoW Forever: Vor- und Nachname -> Vorname als Alias, wenn eindeutig
			local firstName = name:match("^(%S+)%s")
			if firstName then
				if alias[firstName] and alias[firstName] ~= name then ambiguous[firstName] = true else alias[firstName] = name end
			end
		end
	end
	for k in pairs(ambiguous) do alias[k] = nil end
	for k in pairs(roster) do alias[k] = nil end -- echte Namen haben Vorrang
	self.roster = roster
	-- erstes Auftauchen im Gildenroster merken (für die Neulings-Befreiung, wird per Sync abgeglichen)
	local g = self.g
	if g then
		g.seen = g.seen or {}
		for name in pairs(roster) do
			if not g.seen[name] then g.seen[name] = now end
		end
	end
	self.nameAlias = alias
	if not myName then
		local base = self:Short(UnitName("player"))
		myName = (roster[base] and base) or alias[base]
	end
	if myName and myName ~= self.player then self:SetPlayerName(myName) end
	self:MigrateAliases()
	if self.Invalidate then self:Invalidate() end
	local first = not self.rosterLoaded
	self.rosterLoaded = true
	self:Fire("ROSTER", first)
end

-- Kurz- oder Vorname -> voller Name laut Gildenroster
function GS:ResolveName(name)
	if type(name) ~= "string" or name == "" then return name end
	name = self:Short(name)
	if self.roster[name] then return name end
	local a = self.nameAlias and self.nameAlias[name]
	return a or name
end

-- Eigenen Namen korrigieren (z. B. "Milchbart" -> "Milchbart Eineuter") und eigene Daten umziehen
function GS:SetPlayerName(new)
	local old = self.player
	self.player = new
	if not self.db then return end
	local guid = UnitGUID and UnitGUID("player")
	if guid then
		self.db.names = self.db.names or {}
		self.db.names[guid] = new
	end
	if not old or old == new then return end
	local migrated = false
	local chars = self.db.chars
	if chars[old] then
		if not chars[new] then chars[new] = chars[old] end
		chars[old] = nil
	end
	local g = self:G()
	if g then
		local o = g.reports[old]
		if o then
			migrated = true
			-- getrennt erfasste Daten desselben Charakters -> addieren
			local nrep = g.reports[new] or { seq = 0, w = {} }
			for w, d in pairs(o.w or {}) do
				local t = nrep.w[w]
				if not t then
					nrep.w[w] = d
				else
					for _, k in ipairs(self.CATS) do t[k] = (t[k] or 0) + (d[k] or 0) end
					t.pt = (t.pt or 0) + (d.pt or 0)
					t.od = math.max(t.od or 0, d.od or 0)
					for _, key in ipairs({ "i", "mi", "ci", "ai" }) do
						t[key] = t[key] or {}
						for id, x in pairs(d[key] or {}) do
							local y = t[key][id] or { 0, 0 }
							t[key][id] = { y[1] + (x[1] or 0), y[2] + (x[2] or 0) }
						end
					end
				end
			end
			nrep.seq = (nrep.seq or 0) + (o.seq or 0) + 1
			for _, d in pairs(nrep.w) do d.s = nrep.seq end
			g.reports[new] = nrep
			g.reports[old] = nil
		end
		g.status[old] = nil
	end
	self:Invalidate()
	self:Fire("DATA_CHANGED")
	if migrated then
		self:Print(GS.LF("Charaktername erkannt: %s – Daten von „%s“ übernommen.", new, old))
		if self.ScheduleOwnBroadcast then self:ScheduleOwnBroadcast() end
	end
end

-- Kopien anderer Spieler, die unter dem Vornamen gespeichert wurden, auf den vollen Namen umziehen
function GS:MigrateAliases()
	local g = self:G()
	if not g or not self.MergeReport then return end
	local moved = false
	-- erst sammeln, dann umziehen (Tabelle darf beim Durchlaufen keine neuen Schlüssel bekommen)
	local toMove = {}
	for k in pairs(g.reports) do
		local full = self:ResolveName(k)
		if full ~= k and k ~= self.player then toMove[#toMove + 1] = { k, full } end
	end
	for _, x in ipairs(toMove) do
		local rep = g.reports[x[1]]
		g.reports[x[1]] = nil
		self:MergeReport(x[2], rep.seq, rep.w, nil)
		moved = true
	end
	-- Gildenbank-Einträge umbenennen und dabei entstandene Doppelte zusammenführen
	-- nur die umbenannten Einträge gegen die übrigen abgleichen; gleiche Einträge
	-- untereinander bleiben getrennt (das waren schon vorher zwei echte Buchungen)
	if self.MergeBankEntries then
		local keep, renamed = {}, {}
		for _, e in ipairs(g.bank) do
			local full = self:ResolveName(e.c)
			if full ~= e.c then
				e.c = full
				renamed[#renamed + 1] = e
			else
				keep[#keep + 1] = e
			end
		end
		if #renamed > 0 then
			g.bank = keep
			self:MergeBankEntries(renamed, false)
			moved = true
		end
	end
	local stMove = {}
	for k in pairs(g.status) do
		local full = self:ResolveName(k)
		if full ~= k then stMove[#stMove + 1] = { k, full } end
	end
	for _, x in ipairs(stMove) do
		local st, cur = g.status[x[1]], g.status[x[2]]
		if not cur or (st.hb or 0) > (cur.hb or 0) then g.status[x[2]] = st end
		g.status[x[1]] = nil
		moved = true
	end
	if moved then self:Invalidate() end
end

GS:On("GUILD_ROSTER_UPDATE", function()
	GS:TryGuild()
	GS:UpdateRoster()
end)

-- Rang-Index über den Rangnamen bestimmen (0 = Gildenmeister), unabhängig davon,
-- ob der Client die Ränge ab 0 oder ab 1 zählt
function GS:RankIndexFromName(rankName)
	if not rankName or not GuildControlGetNumRanks or not GuildControlGetRankName then return nil end
	local n = GuildControlGetNumRanks() or 0
	for i = 1, n do
		if GuildControlGetRankName(i) == rankName then return i - 1 end
	end
end

function GS:RankOf(name)
	if name and name == self.player then
		if IsGuildLeader and IsGuildLeader() then return 0 end
		local _, rankName, rankIndex = GetGuildInfo("player")
		local ri = self:RankIndexFromName(rankName)
		if ri then return ri end
		if type(rankIndex) == "number" then return rankIndex end
	end
	local r = self.roster[name]
	if not r then return nil end
	local ri = self:RankIndexFromName(r.rank)
	if ri then return ri end
	return r.rankIndex
end

function GS:IsGM(name)
	return self:RankOf(name) == 0
end

-- Diagnose für /gst info
function GS:RankDiagnose()
	local gname, rankName, rankIndex = GetGuildInfo("player")
	local r = self.roster[self.player]
	local cnt = 0
	for _ in pairs(self.roster) do cnt = cnt + 1 end
	local ranks = {}
	local n = (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 0
	for i = 1, n do ranks[#ranks + 1] = i .. "=" .. tostring(GuildControlGetRankName(i)) end
	local L = GS.L
	self:Print(L["Spieler:"], tostring(self.player), "UnitName:", tostring(UnitName("player")),
		L["GUID im Roster:"], tostring(r and r.guid and r.guid == (UnitGUID and UnitGUID("player"))), L["Gilde:"], tostring(gname))
	self:Print(L["GetGuildInfo-Rang:"], tostring(rankName), "Index:", tostring(rankIndex),
		"IsGuildLeader:", tostring(IsGuildLeader and IsGuildLeader()))
	self:Print(L["Roster geladen:"], tostring(self.rosterLoaded), L["Mitglieder:"], cnt,
		L["eigener Eintrag:"], r and (tostring(r.rank) .. " / " .. tostring(r.rankIndex)) or L["fehlt"])
	self:Print(L["Ränge:"], table.concat(ranks, ", "))
	self:Print(L["Erkannter Rang-Index:"], tostring(self:RankOf(self.player)),
		L["Offiziersliste:"], tostring(self:HasRight(self.player, "officer")))
	self:Print(L["AH-Scan-Variante:"], tostring(self.ScanMode and self:ScanMode() or "?"),
		L["Auctionator-Preise:"], tostring(self:AuctionatorPrice(2589) ~= nil))
end
