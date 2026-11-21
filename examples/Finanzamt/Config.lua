-- Finanzamt – Einstellungen, Presets, Rechte-Matrix, Verwaltungsbuchungen, Auffälligkeiten
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local G1, S1 = 10000, 100

---------------------------------------------------------------------------
-- Rechte
---------------------------------------------------------------------------
GS.RIGHTS = {
	{ key = "tariff",  label = "Tarif, Freibeträge und Sätze ändern" },
	{ key = "preset",  label = "Tarif-Preset übernehmen" },
	{ key = "wklist",  label = "Werbungskosten-Itemliste pflegen" },
	{ key = "bank",    label = "Gildenbank-Einstellungen (freie Tabs, Bewertung)" },
	{ key = "values",  label = "Item-Werte festsetzen" },
	{ key = "corr",    label = "Korrekturbuchungen" },
	{ key = "relief",  label = "Erlass, Stundung und Einsprüche bearbeiten" },
	{ key = "twinks",  label = "Twink-Zuordnungen bestätigen/lösen" },
	{ key = "prices",  label = "AH-Preisscan an alle verteilen" },
	{ key = "officer", label = "Offiziersliste sehen" },
	{ key = "viewall", label = "Konten aller Mitglieder sehen" },
}

GS.SECTIONS = { "tariff", "wklist", "bank" }
GS.SECTION_RIGHT = { tariff = "tariff", wklist = "wklist", bank = "bank" }
GS.ADM_RIGHT = {
	LINK = "twinks", UNLINK = "twinks", CORR = "corr", VAL = "values",
	TCORR = "corr",
	CHURCH = "self",   -- Kirchenaustritt / Wiedereintritt (jeder für sein Konto)
	GOAL = "corr",     -- Sparziel anlegen
	GOALX = "corr",    -- Sparziel entfernen    -- Korrektur eines Steuerpostens (z. B. doppelt erfasster Wareneinsatz)
	WAIVE = "relief",  -- Erlass (Hinterziehung einer Woche)
	DEFER = "relief",  -- Stundung (Steuer einer Woche später fällig)
	OBJ = "self",      -- Einspruch gegen den eigenen Steuerbescheid (jeder für sein Konto)
	OBJR = "relief",   -- Einspruch bearbeitet
	ACHCHAT = "corr",  -- Erfolge im Gildenchat melden (an/aus für die ganze Gilde)
}

---------------------------------------------------------------------------
-- Standardwerte (ausgelegt auf eine Gilde um Level 20)
---------------------------------------------------------------------------
GS.PRESET_FIELDS = { zones = true, soli = true, ust = true, gew = true, gewFree = true, pausch = true, minTax = true }

local function presetData(scale)
	return {
		zones = { { 0, 0 }, { 50 * S1 * scale, 0.02 }, { 5 * G1 * scale, 0.04 }, { 20 * G1 * scale, 0.06 } },
		soli = 0.055,
		ust = 0.019,
		gew = 0.01,
		gewFree = 10 * G1 * scale,
		pausch = 10 * S1 * scale,
		minTax = 1 * S1 * scale,
	}
end

local tariff = presetData(1)
tariff.dueWeeks = 1
tariff.resetDay = 3   -- Mittwoch
tariff.resetHour = 4  -- 04:00 UTC
tariff.activeMin = 3
tariff.staleDays = 7
tariff.evasionPenalty = 0 -- Zuschlag auf ohne Addon eingenommenes Gold (zusätzlich zur Nachversteuerung)
tariff.exemptLevel = 0  -- Charaktere unter diesem Level sind steuerfrei (0 = aus)
tariff.exemptWeeks = 1  -- Neulinge: steuerfrei in ihren ersten N Wochen (0 = aus)
tariff.dogTax = 1 * S1  -- Hundesteuer: fester Betrag pro Woche je Jäger/Hexenmeister (0 = aus)
tariff.dogTaxLevel = 10 -- Hundesteuer erst ab diesem Level (Jäger bekommen ihr Tier mit 10)
tariff.churchTax = 0.08 -- Kirchensteuer: Anteil der Einkommensteuer, wenn der Main Priester oder Paladin ist
tariff.alcTax = 0.20    -- Alkoholsteuer: Anteil des Kaufpreises von alkoholischen Getränken
tariff.mountTax = 2 * S1 -- Reittiersteuer: pro Woche je Charakter mit gelerntem Reiten
-- Verzugszinsen: nur in Wochen, in denen das Konto aktiv gespielt hat (Spieler ohne Zeit werden nicht gedrängt)
tariff.interestRate = 0.05      -- Zinssatz pro aktiver Spielwoche auf überfällige Steuern (0 = aus)
tariff.interestMinDays = 2      -- Woche zählt als aktiv ab so vielen Online-Tagen (alle Charaktere des Kontos)
tariff.interestMinMinutes = 0   -- ... und ab so vielen Minuten Spielzeit in der Woche (0 = egal)
tariff.interestGrace = 1        -- so viele aktive Wochen nach Fälligkeit bleiben zinsfrei
tariff.interestMin = 50 * S1    -- Bagatellgrenze: kleinere Rückstände werden nicht verzinst
tariff.interestCap = 0.25       -- Deckel: Zinsen insgesamt höchstens dieser Anteil des Rückstands (0 = kein Deckel)
tariff.rankFactor = {}  -- Steuerfaktor je Rang-Index (z. B. [3] = 0.5 für 50 %), fehlend = 100 %

GS.DEFAULTS = {
	tariff = tariff,
	wklist = { items = {} }, -- wird unten aus GS.WK_DEFAULT_GROUPS befüllt
	bank = {
		free = {},
		chargeRepair = true,
		discount = 0,
		source = "auctionator",
		maxAge = 7,
	},
}

-- Standard-Werbungskosten: Items, die Klassenfähigkeiten verbrauchen oder beibringen.
-- Alle IDs geprüft gegen wowhead.com/forever (Stand 09.11.2026).
GS.WK_DEFAULT_GROUPS = {
	{ name = "Druide", ids = {
		17034, 17035, 17036, 17037, 17038, -- Ahorn-, Schlingdorn-, Eschenholz-, Hainbuchen-, Eisenholzsamen (Wiedergeburt)
		17021, 17026,                      -- Wilde Beeren, Wilder Dornwurz (Gabe der Wildnis)
	} },
	{ name = "Magier", ids = {
		17020,        -- Arkanes Pulver (Arkane Brillanz)
		17031, 17032, -- Rune der Teleportation, Rune der Portale
		17056,        -- Leichte Feder (Langsamer Fall)
	} },
	{ name = "Priester", ids = {
		17028, 17029, -- Heilige Kerze, Geweihte Kerze (Gebet der Seelenstärke)
	} },
	{ name = "Paladin", ids = {
		17033, -- Symbol der Göttlichkeit (Göttliches Eingreifen)
		21177, -- Symbol der Könige (Große Segen)
	} },
	{ name = "Schamane", ids = {
		17030,                    -- Ankh (Reinkarnation)
		17057, 17058,             -- Schimmernde Fischschuppen, Fischöl (Wasseratmung / Wasserwandeln)
		5175, 5176, 5177, 5178,   -- Erd-, Feuer-, Wasser-, Lufttotem
	} },
	{ name = "Schurke", ids = {
		5140, 5530, 5060,                 -- Blitzstrahlpulver, Blendungspulver, Diebeswerkzeug
		2928, 2930, 5173, 8923, 8924,     -- Gift-Reagenzien
		3371, 3372, 8925,                 -- Phiolen
	} },
	{ name = "Hexenmeister", ids = {
		6265, 5565, 16583, -- Seelensplitter, Höllenstein, Dämonenstatuette
	} },
	{ name = "Jäger (Munition)", ids = {
		2512, 2515, 3030, 11285, -- Pfeile
		2516, 2519, 3033, 11284, -- Kugeln
	} },
	{ name = "Forever: Fertigkeitsbücher", ids = {
		211779, -- Verständnis-Talisman
		203754, 203755, 207972, 208185, 208800, 208860, 210177,
		209843, 209844, 209845, 209846, 209847, 209848, 209849, 209850, 209851,
		213165, 215683, 215815, 215816, 215817, 215820, 215822, 215824,
		220345, 220346, 220347, 220348, 220349, 220350, 220352, 220353,
		228132, 228133, 228134, 228135, 228136, 228138, 228140, 228141,
	} },
	{ name = "Proviant (Händler)", ids = {
		159, 1179, 1205, 1708, 1645, 8766,        -- Quellwasser, Eiskalte Milch, Melonensaft, Süßer Nektar, Mondbeerensaft, Morgentau
		4540, 4541, 4542, 4544, 4601, 8950,       -- Brot
		117, 2287, 3770, 3771, 4599, 8952,        -- Fleisch
		4536, 4537, 4538, 4539, 4602, 8953,       -- Obst
		2070, 414, 422, 1707, 3927, 8932,         -- Käse
		787, 4592, 4593, 4594, 21552, 8957,       -- Fisch
		4604, 4605, 4606, 4607, 4608, 8948,       -- Pilze
	} },
	{ name = "Raid-Consumables", ids = {
		13510, 13511, 13512, 13513,               -- Fläschchen
		13456, 13457, 13458, 13459, 13461,        -- Große Schutztränke
		13446, 13444,                             -- Erhebliche Heil-/Manatränke
	} },
}

-- Alkoholische Getränke (für die Alkoholsteuer); Händler- und Festtagsgetränke aus Classic
GS.ALCOHOL_ITEMS = {}
for _, id in ipairs({
	2723, 2593, 2594, 2595, 2596,      -- Pinot Noir, Sturmwind-Portwein, Zwergenhonigmet, Ödlandbourbon, Zwergenstarkbier
	2686, 2894, 3703, 4600, 4595,      -- Donnerbräu, Rhapsodiemalz, Süderstade-Stout, Kirschgrog, Dschungelrebenwein
	1939, 1941, 1942, 9260, 9360, 9361, -- Süßer Rum, Merlot, Mondschein, Flüchtiger Rum, Cuergos Gold
	12003, 18287, 18288, 19221, 19222,  -- Dunkles Zwergenlager, Dunkelbräu, Melassefeuerwasser, Dunkelmond-Reserve, Billiges Bier
	20709, 21114, 21151, 17196, 17402, 17403, -- Rumsey Rum, Festtagsgeist, Winterbräu, Dampfdruck-Sprudelgeist
}) do GS.ALCOHOL_ITEMS[id] = true end

function GS:DefaultWKItems()
	local items = {}
	for _, grp in ipairs(self.WK_DEFAULT_GROUPS) do
		for _, id in ipairs(grp.ids) do items[id] = true end
	end
	return items
end

GS.DEFAULTS.wklist.items = GS:DefaultWKItems()

GS.PRESETS = {
	{ name = "Level 20", data = presetData(1) },
	{ name = "Level 40", data = presetData(5) },
	{ name = "Level 60", data = presetData(20) },
}

function GS:GetPreset(name)
	for _, p in ipairs(self.PRESETS) do
		if p.name == name then return p.data end
	end
end

function GS:FillDefaults(data, def)
	if type(data) ~= "table" then return data end
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = self:Copy(v) end
	end
	return data
end

---------------------------------------------------------------------------
-- Versionierte Einstellungs-Abschnitte
---------------------------------------------------------------------------
local function vid(v) return v.ver .. ":" .. v.time .. ":" .. (v.author or "") end
local function vless(a, b)
	if a.ver ~= b.ver then return a.ver < b.ver end
	if a.time ~= b.time then return a.time < b.time end
	return (a.author or "") < (b.author or "")
end
GS.VersionId = vid

function GS:SectionList(name)
	local g = self:G()
	return g and g.sections[name] or nil
end

function GS:GetLatest(name)
	local l = self:SectionList(name)
	if l and #l > 0 then return l[#l].data end
	return self.DEFAULTS[name]
end

function GS:GetLatestVersion(name)
	local l = self:SectionList(name)
	return l and l[#l]
end

function GS:GetEffective(name, week)
	local l = self:SectionList(name)
	if l then
		for i = #l, 1, -1 do
			if l[i].eff <= week then return l[i].data, l[i] end
		end
	end
	return self.DEFAULTS[name]
end

function GS:SectionHash(name)
	local l = self:SectionList(name) or {}
	local ids = {}
	for _, v in ipairs(l) do ids[#ids + 1] = vid(v) end
	return self:Hash(table.concat(ids, ","))
end

function GS:ValidateSection(name, v, list)
	if self:HasRight(v.author, self.SECTION_RIGHT[name]) then return true end
	if name == "tariff" and v.preset and self:HasRight(v.author, "preset") then
		local p = self:GetPreset(v.preset)
		if not p then return false end
		local prev = self.DEFAULTS.tariff
		for i = #list, 1, -1 do
			if vless(list[i], v) then prev = list[i].data; break end
		end
		for k, val in pairs(v.data) do
			local expect = p[k]
			if expect == nil then expect = prev[k] end
			if self:Canon(val) ~= self:Canon(expect) then return false end
		end
		return true
	end
	return false
end

-- Rückgabe: true (neu), false (doppelt/ungültig), "denied"
function GS:AddSectionVersion(name, v)
	local g = self:G()
	if not g then return false end
	local list = g.sections[name]
	if not list then return false end
	if type(v) ~= "table" or type(v.data) ~= "table" or not tonumber(v.ver) or not tonumber(v.time)
		or not tonumber(v.eff) or type(v.author) ~= "string" then
		return false
	end
	local id = vid(v)
	for _, e in ipairs(list) do
		if vid(e) == id then return false end
	end
	if not self:ValidateSection(name, v, list) then return "denied" end
	self:FillDefaults(v.data, self.DEFAULTS[name])
	list[#list + 1] = v
	table.sort(list, vless)
	self:Invalidate()
	self:Fire("SETTINGS_CHANGED", name)
	return true
end

-- immediate = true: gilt schon für die laufende Woche (rückwirkend für deren bisherige Einnahmen)
function GS:SaveSection(name, data, presetName, immediate)
	local g = self:G()
	if not g then return false, L["Keine Gilde"] end
	local allowed = self:HasRight(self.player, self.SECTION_RIGHT[name])
		or (presetName and self:HasRight(self.player, "preset"))
	if not allowed then return false, L["Keine Berechtigung"] end
	local list = g.sections[name]
	local cur = self:CurrentWeek()
	local maxVer = 0
	for _, e in ipairs(list) do
		if e.ver > maxVer then maxVer = e.ver end
	end
	local v = {
		ver = maxVer + 1,
		time = self:Now(),
		author = self.player,
		eff = (#list == 0 or immediate) and cur or (cur + 1),
		data = self:Copy(data),
		preset = presetName,
		now = (immediate and #list > 0) and true or nil,
	}
	local ok = self:AddSectionVersion(name, v)
	if ok == true then
		self:Broadcast({ t = "SEC", n = name, l = { v } })
		return true, v
	end
	return false, L["Abgelehnt"]
end

---------------------------------------------------------------------------
-- Rechte-Matrix
---------------------------------------------------------------------------
function GS:DefaultPerms()
	local p = {}
	for _, r in ipairs(self.RIGHTS) do p[r.key] = { [1] = true } end
	p.viewall = {}
	for i = 0, 9 do p.viewall[i] = true end
	return p
end

function GS:GetPerms()
	local g = self:G()
	if g and g.perms then return g.perms.data end
	if not self._defaultPerms then self._defaultPerms = self:DefaultPerms() end
	return self._defaultPerms
end

function GS:PermsVer()
	local g = self:G()
	return g and g.perms and g.perms.ver or 0
end

function GS:HasRight(name, right)
	local ri = self:RankOf(name)
	if ri == nil then return false end
	if ri == 0 then return true end
	if right == "perms" then return false end
	local p = self:GetPerms()
	local entry = p[right]
	-- neue Rechte, die in einer älteren gespeicherten Matrix fehlen -> Standard verwenden
	if entry == nil then entry = self:DefaultPerms()[right] end
	return (entry and entry[ri]) and true or false
end

-- Hinterziehungen bleiben geheim: nur wer die Offiziersliste sehen darf, sieht sie
function GS:CanSeeEvasion()
	return self:HasRight(self.player, "officer")
end

-- Recht für eine Verwaltungsbuchung prüfen ("self" = nur für das eigene Konto)
function GS:CanADM(author, kind, data)
	local right = self.ADM_RIGHT[kind]
	if not right then return false end
	if right == "self" then
		return self:RankOf(author) ~= nil and type(data) == "table" and type(data.a) == "string"
			and self:AccountOf(author) == self:AccountOf(data.a)
	end
	return self:HasRight(author, right)
end

function GS:SetPermsObj(obj)
	local g = self:G()
	if not g then return false end
	if type(obj) ~= "table" or type(obj.data) ~= "table" or not tonumber(obj.ver) or not tonumber(obj.time)
		or type(obj.author) ~= "string" then
		return false
	end
	local cur = g.perms
	if cur then
		if obj.ver < cur.ver then return false end
		if obj.ver == cur.ver and obj.time <= cur.time then return false end
	end
	if not self:IsGM(obj.author) then return "denied" end
	g.perms = obj
	self:Invalidate()
	self:Fire("SETTINGS_CHANGED", "perms")
	return true
end

function GS:SavePerms(data)
	if not self:IsGM(self.player) then return false, L["Nur der Gildenmeister darf die Rechte ändern"] end
	local obj = { ver = self:PermsVer() + 1, time = self:Now(), author = self.player, data = self:Copy(data) }
	local ok = self:SetPermsObj(obj)
	if ok == true then
		self:Broadcast({ t = "PRM", o = obj })
		return true
	end
	return false, L["Abgelehnt"]
end

---------------------------------------------------------------------------
-- Verwaltungsbuchungen (Twinks, Korrekturen, Item-Werte)
---------------------------------------------------------------------------
function GS:AddADM(e)
	local g = self:G()
	if not g then return false end
	if type(e) ~= "table" or type(e.id) ~= "string" or type(e.au) ~= "string" or not tonumber(e.tm)
		or not self.ADM_RIGHT[e.k] or type(e.d) ~= "table" then
		return false
	end
	if g.adm[e.id] then return false end
	if not self:CanADM(e.au, e.k, e.d) then return "denied" end
	g.adm[e.id] = e
	self:Invalidate()
	self:Fire("DATA_CHANGED")
	return true
end

function GS:CreateADM(kind, data)
	if not self:G() then return false, L["Keine Gilde"] end
	if not self:CanADM(self.player, kind, data) then return false, L["Keine Berechtigung"] end
	local now = self:Now()
	local e = { id = self.player .. ":" .. now .. ":" .. math.random(100000, 999999), au = self.player, tm = now, k = kind, d = data }
	local ok = self:AddADM(e)
	if ok == true then
		self:Broadcast({ t = "ADM", l = { e } })
		return true
	end
	return false, L["Abgelehnt"]
end

function GS:ADMHash()
	local g = self:G()
	if not g then return 0 end
	local ids = {}
	for id in pairs(g.adm) do ids[#ids + 1] = id end
	table.sort(ids)
	return self:Hash(table.concat(ids, ","))
end

function GS:SortedADM(kind)
	local g = self:G()
	local list = {}
	if not g then return list end
	for _, e in pairs(g.adm) do
		if not kind or e.k == kind or (kind == "LINK" and e.k == "UNLINK") then list[#list + 1] = e end
	end
	table.sort(list, function(a, b)
		if a.tm ~= b.tm then return a.tm < b.tm end
		return a.id < b.id
	end)
	return list
end

-- Bestätigte Twink-Zuordnungen: char -> main
function GS:Links()
	if self._links then return self._links end
	local map = {}
	for _, e in ipairs(self:SortedADM("LINK")) do
		local c, m = self:ResolveName(e.d.c), self:ResolveName(e.d.m)
		if type(c) == "string" then
			if e.k == "LINK" and type(m) == "string" and m ~= c then map[c] = m else map[c] = nil end
		end
	end
	self._links = map
	return map
end

function GS:AccountOf(char)
	char = self:ResolveName(char)
	local links = self:Links()
	local m = links[char]
	if not m then return char end
	local m2 = links[m]
	if m2 and m2 ~= char then return m2 end
	return m
end

-- Twink wird Main seines Kontos (Spieler wechselt seinen Hauptcharakter).
-- Saldo, Steuern, Erlass usw. werden über AccountOf zugeordnet und wandern deshalb automatisch mit.
function GS:SwitchMain(newMain)
	newMain = self:ResolveName(newMain)
	if type(newMain) ~= "string" or newMain == "" then return false, L["Kein Charakter angegeben"] end
	local old = self:AccountOf(newMain)
	if old == newMain then return false, LF("%s ist bereits Main seines Kontos", newMain) end
	if not self:HasRight(self.player, "twinks") then return false, L["Keine Berechtigung"] end
	local others = {}
	for c, m in pairs(self:Links()) do
		if c ~= newMain and self:AccountOf(c) == old then others[#others + 1] = c end
	end
	table.sort(others)
	local ok, err = self:CreateADM("UNLINK", { c = newMain })
	if not ok then return false, err end
	ok, err = self:CreateADM("LINK", { c = old, m = newMain })
	if not ok then return false, err end
	for _, c in ipairs(others) do
		ok, err = self:CreateADM("LINK", { c = c, m = newMain })
		if not ok then return false, err end
	end
	self:Invalidate()
	return true, old, others
end

-- eigenen Main-Anspruch an Zuordnungen anpassen (z. B. nach einem Main-Wechsel durch einen Offizier)
function GS:NormalizeClaim()
	if not self.db or not self.player or not self:G() then return end
	local c = self:MyChar()
	if not c.main then return end
	local acc = self:AccountOf(c.main)
	if acc == self.player then
		c.main = nil -- ich bin jetzt selbst der Main
	elseif acc ~= c.main then
		c.main = acc -- beanspruchter Main ist inzwischen Twink eines anderen Mains
	end
end

function GS:Invalidate()
	self._links = nil
	self._calc = nil
end

---------------------------------------------------------------------------
-- Auffälligkeiten
---------------------------------------------------------------------------
function GS:Flag(char, kind, text, week)
	local g = self:G()
	if not g or not char then return end
	local key = char .. "|" .. kind .. "|" .. tostring(week or "")
	for _, f in ipairs(g.flags) do
		if f.key == key then
			f.time = self:Now()
			f.text = text
			return
		end
	end
	table.insert(g.flags, { key = key, char = char, kind = kind, text = text, time = self:Now(), week = week })
	while #g.flags > 200 do table.remove(g.flags, 1) end
	self:Fire("DATA_CHANGED")
end
