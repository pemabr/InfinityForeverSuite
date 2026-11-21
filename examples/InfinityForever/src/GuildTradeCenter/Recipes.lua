-- GTC_RECIPES
-- Gilden-Rezepte: scannt die eigenen Berufe, teilt die Rezept-IDs ueber den
-- Gildenkanal und zeigt alle Rezepte der Gilde im GTC-Fenster (Reiter "Rezepte").
--
-- Ressourcenschonend: keine OnUpdate-Schleifen, nur Ereignisse und kurze Timer.
-- Ueber das Netz gehen ausschliesslich komprimierte Rezept-IDs; Namen,
-- BoP-Status und Materialien loest jeder Client lokal auf und cached sie.
-- Kommunikation: nur GUILD (wie der GTC-Sync), eigener Praefix GTC_RCP.

local GTC = _G.GuildTradeCenter
if type(GTC) ~= "table" then
    return
end
local L = GTC.T

local R = { view = {}, list = {}, online = {}, roster = {}, profCounts = {}, total = 0 }
GTC.Recipes = R

local PREFIX, MAXTEXT = "GTC_RCP", 230
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local MAX_IDS_PER_PROF = 5000

local GetServerTime, GetTime = GetServerTime, GetTime
local tconcat, tsort = table.concat, table.sort

-- Berufe: [skillLineID] = { englischer Name, Icon, scanbar }
R.PROF = {
    [171] = { "Alchemy",        "Interface\\Icons\\Trade_Alchemy", true },
    [164] = { "Blacksmithing",  "Interface\\Icons\\Trade_BlackSmithing", true },
    [333] = { "Enchanting",     "Interface\\Icons\\Trade_Engraving", true },
    [202] = { "Engineering",    "Interface\\Icons\\Trade_Engineering", true },
    [773] = { "Inscription",    "Interface\\Icons\\INV_Inscription_Tradeskill01", true },
    [755] = { "Jewelcrafting",  "Interface\\Icons\\INV_Misc_Gem_01", true },
    [165] = { "Leatherworking", "Interface\\Icons\\Trade_LeatherWorking", true },
    [197] = { "Tailoring",      "Interface\\Icons\\Trade_Tailoring", true },
    [185] = { "Cooking",        "Interface\\Icons\\INV_Misc_Food_15", true },
    [186] = { "Mining",         "Interface\\Icons\\Trade_Mining", true },
    [129] = { "First Aid",      "Interface\\Icons\\Spell_Holy_SealOfSacrifice", true },
}

local function Log(tag, message)
    if GTC.Log then GTC:Log(tag, message) end
end

local requested, served, buffers, lastData, pendingReq = {}, {}, {}, {}, {}
local digestToken, lastDigestSeen = 0, 0
local rosterAt, rosterDirty = 0, true

-- ------------------------------------------------------------- Datenzugriff
local function Root()
    return type(GuildTradeCenterDB) == "table" and GuildTradeCenterDB or nil
end

local function Opts()
    local root = Root()
    if not root then return { hideBop = false, status = "all", autoScan = true } end
    local o = root.recipeOpts
    if type(o) ~= "table" then o = {}; root.recipeOpts = o end
    if o.hideBop == nil then o.hideBop = false end
    if o.status == nil then o.status = "all" end
    if o.autoScan == nil then o.autoScan = true end
    return o
end

local function Cache()
    local root = Root()
    if not root then return {} end
    if root.recipeCacheLocale ~= GetLocale() then
        root.recipeCache, root.recipeProfNames, root.recipeCacheLocale = {}, {}, GetLocale()
    end
    root.recipeCache = root.recipeCache or {}
    root.recipeProfNames = root.recipeProfNames or {}
    return root.recipeCache
end

-- Liefert den Rezept-Speicher des aktiven Gilden-Datenbereichs.
local function Store()
    local db = GTC.EnsureDB and GTC:EnsureDB() or GTC.db
    if type(db) ~= "table" or db.scopeType ~= "guild" then
        return nil
    end
    if type(db.recipes) ~= "table" or type(db.recipes.members) ~= "table" then
        db.recipes = { members = {} }
    end
    return db.recipes
end

local function MyName()
    if not R.me then
        local n = GetUnitName and GetUnitName("player", true) or UnitName("player")
        R.me = Ambiguate(n or L("Unbekannt"), "none")
    end
    return R.me
end

function R:ProfName(pid)
    local root = Root()
    Cache()
    local names = root and root.recipeProfNames
    if names and names[pid] then return names[pid] end
    local T = C_TradeSkillUI
    if T and T.GetProfessionInfoBySkillLineID then
        local info = T.GetProfessionInfoBySkillLineID(pid)
        if info and info.professionName and info.professionName ~= "" then
            if names then names[pid] = info.professionName end
            return info.professionName
        end
    end
    local p = self.PROF[pid]
    return p and p[1] or (L("Beruf ") .. pid)
end

function R:ProfIcon(pid)
    local p = self.PROF[pid]
    return p and p[2] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ------------------------------------------------------------- Gildenliste
local function RebuildRoster()
    local names, online, total = {}, {}, GetNumGuildMembers()
    for i = 1, total do
        local full, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if full then
            full = Ambiguate(full, "none")
            names[full] = true
            if isOnline then online[full] = true end
        end
    end
    online[MyName()] = true
    R.roster, R.online = names, online
    rosterAt, rosterDirty = GetTime(), false
    return total
end

local function EnsureRoster()
    if rosterDirty or GetTime() - rosterAt > 120 then
        RebuildRoster()
    end
end

function R:IsGuildMember(name)
    EnsureRoster()
    return self.roster[name] == true or name == MyName()
end

-- Entfernt Mitglieder, die die Gilde verlassen haben.
local function PruneMembers()
    local store = Store()
    if not store or not next(R.roster) then return end
    for name in pairs(store.members) do
        if not R.roster[name] and name ~= MyName() then
            store.members[name] = nil
            R.dirty = true
        end
    end
end

-- ----------------------------------------------------------------- Kodierung
local function B36(n)
    if n == 0 then return "0" end
    local t = {}
    while n > 0 do
        local r = n % 36
        t[#t + 1] = DIGITS:sub(r + 1, r + 1)
        n = (n - r) / 36
    end
    return string.reverse(tconcat(t))
end

local function EncodeChunks(ids, budget)
    local chunks, cur, len, prev = {}, {}, 0, nil
    for _, id in ipairs(ids) do
        local tok = (prev and #cur > 0) and B36(id - prev) or B36(id)
        if #cur > 0 and len + #tok + 1 > budget then
            chunks[#chunks + 1] = tconcat(cur, ",")
            cur, len, tok = {}, 0, B36(id)
        end
        cur[#cur + 1] = tok
        len = len + #tok + 1
        prev = id
    end
    if #cur > 0 then chunks[#chunks + 1] = tconcat(cur, ",") end
    return chunks
end

local function DecodeChunk(s, out)
    local prev
    for tok in s:gmatch("[^,]+") do
        local n = tonumber(tok, 36)
        if not n then return false end
        prev = prev and (prev + n) or n
        out[#out + 1] = prev
    end
    return true
end

-- ------------------------------------------------------------------ Senden
local queue, ticker = {}, nil
-- Nach einer Drosselung kurz pausieren: Vorher wurde viermal pro Sekunde erneut gesendet
-- (und jedes Mal protokolliert), obwohl das Spiel nur 1 Nachricht/s zulaesst.
local pauseUntil, throttleCount = 0, 0

local function Pump()
    if GetTime() < pauseUntil then return end
    local msg = table.remove(queue, 1)
    if msg then
        local res = C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD")
        local enum = Enum and Enum.SendAddonMessageResult
        local throttled = enum and enum.AddonMessageThrottle or 3
        local channelThrottled = enum and enum.ChannelThrottle or 8
        if res == throttled or res == channelThrottled then
            throttleCount = throttleCount + 1
            pauseUntil = GetTime() + 1.1
            if throttleCount == 1 or throttleCount % 20 == 0 then
                Log("RCP>", "gedrosselt (Ergebnis " .. tostring(res) .. ", " .. throttleCount .. "x), Queue=" .. #queue)
            end
            table.insert(queue, 1, msg)
        elseif res ~= nil and res ~= 0 and res ~= true then
            Log("ERR", "RCP Sendefehler Ergebnis=" .. tostring(res))
        end
    end
    if #queue == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function Send(msg)
    if not IsInGuild() then return end
    queue[#queue + 1] = msg
    if not ticker then ticker = C_Timer.NewTicker(0.25, Pump) end
end

local function KnownCount(store)
    local n = 0
    for _, m in pairs(store.members) do
        if next(m.profs) then n = n + 1 end
    end
    return n
end

-- Veroeffentlicht die Daten von `name` (Standard: ich selbst) im Gildenkanal.
function R:Publish(name)
    local store = Store()
    name = name or MyName()
    local m = store and store.members[name]
    if not m or not m.ts then return end
    local list = {}
    for pid, p in pairs(m.profs) do
        if #p.ids > 0 then list[#list + 1] = pid end
    end
    if #list == 0 then return end
    tsort(list)
    Log("RCP>", "Publish " .. name .. " Berufe=" .. #list .. " ts=" .. m.ts)
    Send(("M|%s|%d|%s"):format(name, m.ts, tconcat(list, ",")))
    for _, pid in ipairs(list) do
        local p = m.profs[pid]
        local head = ("P|%s|%d|%d|%d|%d|"):format(name, m.ts, pid, p.s or 0, p.m or 0)
        local chunks = EncodeChunks(p.ids, MAXTEXT - #head - 10)
        for i, c in ipairs(chunks) do
            Send(("%s%d/%d|%s"):format(head, i, #chunks, c))
        end
    end
end

function R:SendHello()
    local store = Store()
    if not store then return end
    local m = store.members[MyName()]
    Log("RCP>", "Hello ts=" .. tostring(m and m.ts or 0) .. " bekannt=" .. KnownCount(store))
    Send(("O|%d|%d"):format(m and m.ts or 0, KnownCount(store)))
end

local function SendDigest()
    local store = Store()
    if not store then return end
    local parts, len = {}, 0
    Log("RCP>", "Übersicht (Digest) gesendet")
    local function flush()
        if #parts > 0 then Send("D|" .. tconcat(parts, ";")) end
        parts, len = {}, 0
    end
    for name, m in pairs(store.members) do
        if m.ts and m.ts > 0 and next(m.profs) then
            local e = name .. ":" .. B36(m.ts)
            if len + #e + 1 > MAXTEXT - 4 then flush() end
            parts[#parts + 1] = e
            len = len + #e + 1
        end
    end
    flush()
end

-- ---------------------------------------------------------------- Empfangen
-- Fordert Daten eines Mitglieds an. Kurze Zufallsverzoegerung: Kommt die Antwort
-- fuer jemand anderen vorher an, wird die eigene Anfrage nicht mehr gesendet.
local function RequestData(name)
    local now = GetTime()
    if pendingReq[name] or (requested[name] and now - requested[name] < 120) then return end
    pendingReq[name] = true
    C_Timer.After(1 + math.random() * 4, function()
        if not pendingReq[name] then return end
        pendingReq[name] = nil
        requested[name] = GetTime()
        Log("RCP>", "Anfrage für " .. name)
        local store = Store()
        local m = store and store.members[name]
        Send(("R|%s|%d"):format(name, m and m.ts or 0))
    end)
end

local function Commit(name, ts, pid, s, m, ids)
    local store = Store()
    if not store or name == MyName() then return end
    local mem = store.members[name]
    if not mem then mem = { ts = 0, profs = {} }; store.members[name] = mem end
    if (mem.ts or 0) > ts then return end
    mem.ts = ts
    mem.profs[pid] = { s = s, m = m, ids = ids }
    Log("DATA", ("%s Beruf %d: %d Rezepte (ts %d)"):format(name, pid, #ids, ts))
    lastData[name] = GetTime()
    pendingReq[name] = nil
    R.dirty = true
    if R.OnDataChanged then R:OnDataChanged() end
end

function R:OnComm(text, channel, sender)
    if channel ~= "GUILD" or type(text) ~= "string" or #text > 255 then return end
    sender = Ambiguate(sender, "none")
    if sender == MyName() then return end
    if not self:IsGuildMember(sender) then
        local now = GetTime()
        if not self.rejectLog or now - self.rejectLog > 30 then
            self.rejectLog = now
            Log("RCP<", "ABGELEHNT (nicht in Gildenliste): " .. sender .. " Roster=" .. (next(self.roster) and "geladen" or "leer"))
        end
        return
    end
    local store = Store()
    if not store then
        Log("RCP<", "ignoriert (kein Gilden-Datenbereich): " .. sender)
        return
    end
    local f = { strsplit("|", text) }
    local op = f[1]
    if op ~= "P" then
        Log("RCP<", op .. " von " .. sender .. " (" .. #text .. " Zeichen)")
    end

    if op == "O" then
        local ts, known = tonumber(f[2]), tonumber(f[3])
        if not ts then return end
        self.peers[sender] = true
        local m = store.members[sender]
        if ts > 0 and (not m or (m.ts or 0) < ts) then RequestData(sender) end
        -- Wer mehr Mitglieder kennt, bietet (hoechstens einmal pro Welle) eine Uebersicht an.
        if KnownCount(store) > (known or 0) and GetTime() - lastDigestSeen > 90 then
            digestToken = digestToken + 1
            local tok = digestToken
            C_Timer.After(5 + math.random() * 20, function()
                if tok == digestToken and GetTime() - lastDigestSeen > 90 then
                    lastDigestSeen = GetTime()
                    SendDigest()
                end
            end)
        end

    elseif op == "D" then
        lastDigestSeen = GetTime()
        digestToken = digestToken + 1 -- eigene geplante Uebersicht verwerfen
        local n = 0
        for entry in (f[2] or ""):gmatch("[^;]+") do
            local name, t36 = entry:match("^(.+):(%w+)$")
            local ts = t36 and tonumber(t36, 36)
            if name and ts and name ~= MyName() and self.roster[name] then
                local m = store.members[name]
                if not m or (m.ts or 0) < ts then
                    RequestData(name)
                    n = n + 1
                    if n >= 60 then break end
                end
            end
        end

    elseif op == "R" then
        local name, reqTs = f[2], tonumber(f[3]) or 0
        local m = name and store.members[name]
        if not m or not m.ts or m.ts <= reqTs then return end
        local now = GetTime()
        if served[name] and now - served[name] < 60 then return end
        local owner = (name == MyName())
        local scheduled = now
        C_Timer.After(owner and (0.5 + math.random() * 1.5) or (2 + math.random() * 6), function()
            -- Hat inzwischen jemand anderes geantwortet? Dann schweigen.
            if not owner and lastData[name] and lastData[name] >= scheduled then return end
            if served[name] and GetTime() - served[name] < 60 then return end
            served[name] = GetTime()
            R:Publish(name)
        end)

    elseif op == "M" then
        local name, ts = f[2], tonumber(f[3])
        if not name or not ts or name == MyName() or not self.roster[name] then return end
        local mem = store.members[name]
        if mem and (mem.ts or 0) <= ts then
            local keep = {}
            for pid in (f[4] or ""):gmatch("%d+") do keep[tonumber(pid)] = true end
            for pid in pairs(mem.profs) do
                if not keep[pid] then
                    mem.profs[pid] = nil
                    R.dirty = true
                end
            end
            if R.dirty and self.OnDataChanged then self:OnDataChanged() end
        end

    elseif op == "P" then
        local name, ts, pid = f[2], tonumber(f[3]), tonumber(f[4])
        local s, m = tonumber(f[5]), tonumber(f[6])
        local part, parts = (f[7] or ""):match("^(%d+)/(%d+)$")
        part, parts = tonumber(part), tonumber(parts)
        if not (name and ts and pid and part and parts and f[8]) or parts > 100 or part > parts then return end
        if name == MyName() or not self.roster[name] then return end
        local key = name .. ":" .. pid
        local b = buffers[key]
        if not b or b.ts ~= ts or b.parts ~= parts then
            if b and b.ts > ts then return end
            b = { ts = ts, parts = parts, got = {}, at = GetTime() }
            buffers[key] = b
        end
        local ids = {}
        if not DecodeChunk(f[8], ids) then return end
        b.got[part] = ids
        for i = 1, parts do
            if not b.got[i] then return end
        end
        local all = {}
        for i = 1, parts do
            for _, id in ipairs(b.got[i]) do all[#all + 1] = id end
        end
        buffers[key] = nil
        if #all <= MAX_IDS_PER_PROF then
            Commit(name, ts, pid, s or 0, m or 0, all)
        end
    end
end

-- -------------------------------------------------------------------- Scan
function R:ScanOpenProfession()
    local T = C_TradeSkillUI
    if not (T and T.GetBaseProfessionInfo and T.GetAllRecipeIDs) then
        Log("SCAN", "API fehlt: GetBaseProfessionInfo/GetAllRecipeIDs")
        return false
    end
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then
        Log("SCAN", "übersprungen: verlinktes/Gilden-Berufsfenster")
        return false
    end
    local info = T.GetBaseProfessionInfo()
    if not info or not info.professionID or info.professionID == 0 then
        Log("SCAN", "kein offener Beruf (GetBaseProfessionInfo leer)")
        return false
    end
    local parent = info.parentProfessionID
    if not parent or parent == 0 then parent = info.professionID end
    local all = T.GetAllRecipeIDs()
    if not all or #all == 0 then
        Log("SCAN", "Beruf " .. tostring(info.professionID) .. ": GetAllRecipeIDs leer")
        return false
    end
    local store = Store()
    if not store then
        Log("SCAN", "kein Gilden-Datenbereich (Spieler in keiner Gilde?)")
        return false
    end

    local ids = {}
    for _, id in ipairs(all) do
        local ri = T.GetRecipeInfo(id)
        if ri and ri.learned then ids[#ids + 1] = id end
    end
    tsort(ids)

    local name = info.parentProfessionName
    if not name or name == "" then name = info.professionName end
    Cache()
    if name and name ~= "" then Root().recipeProfNames[parent] = name end

    local me = MyName()
    local mem = store.members[me]
    if not mem then mem = { ts = 0, profs = {} }; store.members[me] = mem end
    local p = mem.profs[parent]
    if not p then p = { sub = {}, ids = {} }; mem.profs[parent] = p end
    p.sub = p.sub or {}
    p.sub[info.professionID] = ids
    p.s, p.m = info.skillLevel or 0, info.maxSkillLevel or 0

    local set, merged = {}, {}
    for _, list in pairs(p.sub) do
        for _, id in ipairs(list) do
            if not set[id] then set[id] = true; merged[#merged + 1] = id end
        end
    end
    tsort(merged)

    local changed = #merged ~= #p.ids
    if not changed then
        for i = 1, #merged do
            if merged[i] ~= p.ids[i] then changed = true; break end
        end
    end
    p.ids = merged
    Log("SCAN", ("Beruf %d (%s): %d von %d Rezepten gelernt, geändert=%s"):format(
        parent, tostring(name), #merged, #all, tostring(changed)))
    if changed then
        mem.ts = GetServerTime()
        self:Publish()
        R.dirty = true
        if self.OnDataChanged then self:OnDataChanged() end
    end
    return true
end

-- Wird bei jedem TRADE_SKILL_LIST_UPDATE aufgerufen (entprellt).
function R:OnTradeSkillUpdate()
    self.tsToken = (self.tsToken or 0) + 1
    local tok = self.tsToken
    C_Timer.After(0.8, function()
        if tok ~= self.tsToken then return end
        local s = self.scan
        if s or self.logTsEvents then Log("SCAN", "TRADE_SKILL_LIST_UPDATE (Scan aktiv=" .. tostring(s ~= nil) .. ")") end
        if s then
            if s.waiting then
                s.waiting = false
                if self:ScanOpenProfession() then s.ok = s.ok + 1 end
                C_TradeSkillUI.CloseTradeSkill()
                C_Timer.After(0.3, function() self:ScanNext() end)
            end
        else
            self:ScanOpenProfession()
        end
    end)
end

function R:StartScan()
    local T = C_TradeSkillUI
    if not (T and T.OpenTradeSkill and T.GetBaseProfessionInfo) then
        GTC:Print(L("Die Berufs-API ist in diesem Client nicht verfügbar."))
        return false
    end
    if InCombatLockdown() or self.scan or not Store() then
        Log("SCAN", "Start abgelehnt: Kampf=" .. tostring(InCombatLockdown()) .. " läuft=" .. tostring(self.scan ~= nil)
            .. " Gilde=" .. tostring(Store() ~= nil))
        return false
    end
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        Log("SCAN", "API fehlt: GetProfessions/GetProfessionInfo")
        return false
    end
    local q = {}
    local a, b, c, d, e = GetProfessions()
    Log("SCAN", ("GetProfessions: %s, %s, %s, %s, %s"):format(tostring(a), tostring(b), tostring(c), tostring(d), tostring(e)))
    for _, idx in ipairs({ a or 0, b or 0, c or 0, d or 0, e or 0 }) do
        if idx > 0 then
            local pname, _, prank, _, _, _, skillLine = GetProfessionInfo(idx)
            Log("SCAN", ("Beruf Index %s: Name=%s Rang=%s skillLine=%s bekannt=%s"):format(
                tostring(idx), tostring(pname), tostring(prank), tostring(skillLine),
                tostring(skillLine ~= nil and self.PROF[skillLine] ~= nil)))
            if skillLine and self.PROF[skillLine] and self.PROF[skillLine][3] then q[#q + 1] = skillLine end
        end
    end
    -- Ersatzweg: alle bekannten Berufs-Skilllinien direkt vom Berufs-System.
    if #q == 0 and T.GetAllProfessionTradeSkillLines then
        local ok, lines = pcall(T.GetAllProfessionTradeSkillLines)
        Log("SCAN", "GetAllProfessionTradeSkillLines: ok=" .. tostring(ok) .. " Anzahl=" .. tostring(type(lines) == "table" and #lines or lines))
        if ok and type(lines) == "table" then
            local seen = {}
            for _, lineID in ipairs(lines) do
                local info = T.GetProfessionInfoBySkillLineID and T.GetProfessionInfoBySkillLineID(lineID)
                local parent = info and info.parentProfessionID
                if not parent or parent == 0 then parent = lineID end
                Log("SCAN", ("Skillline %s -> Eltern %s (%s)"):format(tostring(lineID), tostring(parent), tostring(info and info.professionName)))
                if self.PROF[parent] and self.PROF[parent][3] and not seen[parent] then
                    seen[parent] = true
                    q[#q + 1] = lineID
                end
            end
        end
    end
    Log("SCAN", "Berufe gefunden: " .. #q .. " (" .. tconcat(q, ",") .. ")")
    if #q == 0 then return false end
    self.scan = { queue = q, i = 0, ok = 0 }
    self.lastAutoScan = GetTime()
    if self.OnScanState then self:OnScanState(true) end
    self:ScanNext()
    return true
end

function R:ScanNext()
    local s = self.scan
    if not s then return end
    s.i = s.i + 1
    local id = s.queue[s.i]
    if not id then return self:EndScan() end
    s.waiting = true
    s.token = (s.token or 0) + 1
    local tok = s.token
    local okOpen, errOpen = pcall(C_TradeSkillUI.OpenTradeSkill, id)
    Log("SCAN", "OpenTradeSkill(" .. id .. ") ok=" .. tostring(okOpen) .. (okOpen and "" or (" Fehler=" .. tostring(errOpen))))
    if ProfessionsFrame then ProfessionsFrame:SetAlpha(0) end
    C_Timer.After(3.5, function()
        if self.scan == s and s.token == tok and s.waiting then
            Log("SCAN", "Zeitüberschreitung beim Beruf " .. id .. " (kein TRADE_SKILL_LIST_UPDATE), versuche trotzdem zu lesen")
            s.waiting = false
            if self:ScanOpenProfession() then s.ok = s.ok + 1 end
            C_TradeSkillUI.CloseTradeSkill()
            C_Timer.After(0.3, function() self:ScanNext() end)
        end
    end)
end

function R:EndScan()
    local s = self.scan
    self.scan = nil
    if ProfessionsFrame then ProfessionsFrame:SetAlpha(1) end
    if self.OnScanState then self:OnScanState(false) end
    Log("SCAN", "Scan beendet, erfolgreich gelesen: " .. tostring(s and s.ok))
    if s and s.ok == 0 then
        GTC:Print(L("Kein Beruf konnte automatisch gelesen werden. Öffne deine Berufsfenster einmal selbst - dann wird gescannt."))
    end
end

function R:AutoScan()
    if not Opts().autoScan or self.scan then
        Log("SCAN", "Auto-Scan übersprungen (aus oder läuft schon)")
        return
    end
    if self.lastAutoScan and GetTime() - self.lastAutoScan < 600 then
        Log("SCAN", "Auto-Scan übersprungen (jünger als 10 Minuten)")
        return
    end
    Log("SCAN", "Auto-Scan startet")
    self:StartScan()
end

-- ----------------------------------------- Rezept-Aufloesung (lokal, gecached)
local pendingItems, pendingCount = {}, 0

local function BindTypeOf(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    return (select(14, getInfo(itemID)))
end

function R:Resolve(id)
    local cache = Cache()
    local c = cache[id]
    if c and c.n and c.b ~= nil then return c end
    if not c then c = {}; cache[id] = c end
    local T = C_TradeSkillUI
    if not c.n then
        local ri = T and T.GetRecipeInfo and T.GetRecipeInfo(id)
        if ri then c.n, c.i = ri.name, ri.icon end
        if not c.n and C_Spell and C_Spell.GetSpellName then c.n = C_Spell.GetSpellName(id) end
        if not c.i and C_Spell and C_Spell.GetSpellTexture then c.i = C_Spell.GetSpellTexture(id) end
    end
    if c.o == nil and T and T.GetRecipeOutputItemData then
        local ok, od = pcall(T.GetRecipeOutputItemData, id)
        if ok and od and od.itemID then
            c.o = od.itemID
            if od.icon then c.i = od.icon end
        elseif c.n then
            c.o = false
        end
    end
    if c.o == false then
        c.b = 0
    elseif c.o and c.b == nil then
        local bind = BindTypeOf(c.o)
        if bind then
            c.b = bind
        elseif not pendingItems[c.o] then
            pendingItems[c.o] = true
            pendingCount = pendingCount + 1
            C_Item.RequestLoadItemDataByID(c.o)
            R.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end
    return c
end

function R:GetReagents(id)
    local c = self:Resolve(id)
    if c.r then return c.r end
    local T = C_TradeSkillUI
    if not (T and T.GetRecipeSchematic) then return nil end
    local ok, sch = pcall(T.GetRecipeSchematic, id, false)
    if not ok or not sch or not sch.reagentSlotSchematics then return nil end
    local basic = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
    local r = {}
    for _, slot in ipairs(sch.reagentSlotSchematics) do
        local first = slot.reagents and slot.reagents[1]
        if first and first.itemID and (slot.reagentType == nil or slot.reagentType == basic) then
            r[#r + 1] = first.itemID
            r[#r + 1] = slot.quantityRequired or 1
        end
    end
    c.r = r
    return r
end

local function ItemLoaded(itemID)
    if not pendingItems[itemID] then return end
    pendingItems[itemID] = nil
    pendingCount = pendingCount - 1
    if pendingCount <= 0 then R.frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
    R.itemToken = (R.itemToken or 0) + 1
    local tok = R.itemToken
    C_Timer.After(0.5, function()
        if tok ~= R.itemToken then return end
        for _, c in pairs(Cache()) do
            if c.o and c.b == nil then
                local bind = BindTypeOf(c.o)
                if bind then c.b = bind end
            end
        end
        if R.OnItemsResolved then R:OnItemsResolved() end
    end)
end

-- ------------------------------------------------------------ Index / Filter
function R:Rebuild()
    local store = Store()
    local idx, list, counts, total = {}, {}, {}, 0
    if store then
        for name, m in pairs(store.members) do
            for pid, p in pairs(m.profs) do
                for _, id in ipairs(p.ids) do
                    local e = idx[id]
                    if not e then
                        e = { id = id, prof = pid, cr = {} }
                        idx[id] = e
                        list[#list + 1] = e
                        counts[pid] = (counts[pid] or 0) + 1
                        total = total + 1
                    end
                    e.cr[#e.cr + 1] = name
                end
            end
        end
    end
    self.index, self.list, self.profCounts, self.total = idx, list, counts, total
    self.dirty = false
end

function R:Refilter(query)
    local o = Opts()
    local online = self.online
    local q = (query or ""):lower()
    local view = {}
    for _, e in ipairs(self.list) do
        local c = self:Resolve(e.id)
        local skip = (o.prof and e.prof ~= o.prof) or (o.hideBop and c.b == 1)
        if not skip then
            local vis = {}
            for _, name in ipairs(e.cr) do
                local isOn = online[name]
                if o.status == "all" or (o.status == "online" and isOn) or (o.status == "offline" and not isOn) then
                    vis[#vis + 1] = name
                end
            end
            if #vis == 0 then
                skip = true
            else
                tsort(vis, function(a, b)
                    local oa, ob = online[a] and 1 or 0, online[b] and 1 or 0
                    if oa ~= ob then return oa > ob end
                    return a < b
                end)
                e.vis = vis
                e.sn = (c.n or "~"):lower()
                if q ~= "" and not e.sn:find(q, 1, true) then
                    local hit = false
                    for _, name in ipairs(vis) do
                        if name:lower():find(q, 1, true) then hit = true; break end
                    end
                    skip = not hit
                end
            end
        end
        if not skip then view[#view + 1] = e end
    end
    tsort(view, function(a, b)
        if a.sn ~= b.sn then return a.sn < b.sn end
        return a.id < b.id
    end)
    self.view = view
end

-- ------------------------------------------------------------------ Ereignisse
local frame = CreateFrame("Frame")
R.frame = frame
R.peers = {}
frame:RegisterEvent("PLAYER_LOGIN")

local events = {}

function events.PLAYER_LOGIN()
    MyName()
    local T = C_TradeSkillUI
    Log("ENV", ("C_TradeSkillUI=%s Open=%s BaseInfo=%s AllRecipes=%s Schematic=%s OutputItem=%s GetProfessions=%s"):format(
        type(T), type(T and T.OpenTradeSkill), type(T and T.GetBaseProfessionInfo), type(T and T.GetAllRecipeIDs),
        type(T and T.GetRecipeSchematic), type(T and T.GetRecipeOutputItemData), type(GetProfessions)))
    Log("ENV", ("Spieler=%s Gilde=%s"):format(tostring(R.me), tostring(GetGuildInfo("player"))))
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    if IsInGuild() then
        C_Timer.After(10 + math.random() * 15, function()
            C_GuildInfo.GuildRoster()
            C_Timer.After(3, function() R:SendHello() end)
        end)
    end
end

function events.CHAT_MSG_ADDON(prefix, text, channel, sender)
    if prefix == PREFIX then R:OnComm(text, channel, sender) end
end

function events.TRADE_SKILL_LIST_UPDATE()
    R:OnTradeSkillUpdate()
end

function events.GUILD_ROSTER_UPDATE()
    rosterDirty = true
end

function events.GET_ITEM_INFO_RECEIVED(itemID)
    ItemLoaded(itemID)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local h = events[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok then
            Log("ERR", "Recipes " .. event .. ": " .. tostring(err))
            geterrorhandler()(err)
        end
    end
end)

-- ======================================================================
-- Oberflaeche: Reiter "Rezepte" im GTC-Fenster (Theme, Buttons und Rahmen
-- stammen aus UI.lua ueber GTC.UIKit)
-- ======================================================================
local ROWS, ROW_H = 9, 46
local STATUS_LABEL = { all = "Alle", online = "Online", offline = "Offline" }
local STATUS_NEXT = { all = "online", online = "offline", offline = "all" }

local function Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, 0.75, 0.84, 0.97, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Shift-Klick: Gegenstand ins Auktionshaus-Suchfeld oder in die Chat-Eingabe.
local function LinkItem(itemID, fallbackName)
    if not itemID or not IsShiftKeyDown() then return false end
    local name = C_Item.GetItemNameByID(itemID) or fallbackName
    local ah = AuctionHouseFrame
    local box = ah and ah:IsShown() and ah.SearchBar and ah.SearchBar.SearchBox
    if box and name then
        box:SetText(name)
        box:SetFocus()
        return true
    end
    local _, link = C_Item.GetItemInfo(itemID)
    if link then
        if HandleModifiedItemClick then return HandleModifiedItemClick(link) end
        return ChatEdit_InsertLink(link)
    end
    return false
end

function GTC:CreateRecipePanel(root, kit)
    local C = kit.Theme()
    local Button, Text, Backdrop, StyleEditBox = kit.Button, kit.Text, kit.Backdrop, kit.StyleEditBox
    local profBtns, rows, crafterRows, reagentRows = {}, {}, {}, {}
    local offset, updating = 0, false
    local searchBox, slider, btnBop, btnStatus, btnScan, btnAuto
    local footer, detail, empty, title

    local panel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    Backdrop(panel, C.listPanel, C.border)
    panel:Hide()

    local function SetActive(btn, on)
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(unpack(on and C.cyan or C.buttonText)) end
    end

    local function QueryText()
        local q = searchBox and searchBox:GetText() or ""
        return (q:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local UpdateList, UpdateDetail, UpdateProfs, UpdateFooter, Refilter

    local function SetupToggles()
        local o = Opts()
        btnBop:SetText(o.hideBop and L("BoP: versteckt") or L("BoP: sichtbar"))
        SetActive(btnBop, o.hideBop)
        btnStatus:SetText(L("Hersteller: ") .. L(STATUS_LABEL[o.status]))
        SetActive(btnStatus, o.status ~= "all")
        btnAuto:SetText(o.autoScan and L("Auto-Scan: an") or L("Auto-Scan: aus"))
        SetActive(btnAuto, o.autoScan)
    end

    -- ---------------------------------------------------------- Kopfbereich
    title = Text(panel, "GameFontNormal", "TOPLEFT", panel, "TOPLEFT", 16, -14)
    title:SetTextColor(unpack(C.gold))
    title:SetText(L("REZEPTE DER GILDE"))

    searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    StyleEditBox(searchBox)
    searchBox:SetSize(210, 24)
    searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 172, -36)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    hint:SetText(L("Rezept oder Handwerker"))
    hint:SetTextColor(unpack(C.muted))
    local tok = 0
    searchBox:SetScript("OnEditFocusGained", function() hint:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(box) hint:SetShown(box:GetText() == "") end)
    searchBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    searchBox:SetScript("OnTextChanged", function(box)
        hint:SetShown(box:GetText() == "" and not box:HasFocus())
        tok = tok + 1
        local t = tok
        C_Timer.After(0.25, function() if t == tok then Refilter() end end)
    end)
    Tip(searchBox, L("Suche"), L("Filtert nach Rezeptname oder Name eines Handwerkers."))

    btnBop = Button(panel, "", 120, 24)
    btnBop:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    btnBop:SetScript("OnClick", function()
        local o = Opts()
        o.hideBop = not o.hideBop
        SetupToggles(); Refilter()
    end)
    Tip(btnBop, L("BoP-Rezepte"), L("Blendet Rezepte aus, deren Ergebnis beim Aufheben gebunden ist."))

    btnStatus = Button(panel, "", 138, 24)
    btnStatus:SetPoint("LEFT", btnBop, "RIGHT", 6, 0)
    btnStatus:SetScript("OnClick", function()
        local o = Opts()
        o.status = STATUS_NEXT[o.status]
        SetupToggles(); Refilter()
    end)
    Tip(btnStatus, L("Hersteller-Status"), L("Wechselt zwischen allen, nur Online- und nur Offline-Herstellern."))

    local btnSync = Button(panel, "Sync", 62, 24)
    btnSync:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -36)
    btnSync:SetScript("OnClick", function()
        if (R.lastSync or 0) > GetTime() - 30 then GTC:Print(L("Bitte kurz warten.")) return end
        R.lastSync = GetTime()
        R:SendHello(); R:Publish()
        C_GuildInfo.GuildRoster()
        GTC:Print(L("Rezept-Abgleich gesendet."))
    end)
    Tip(btnSync, L("Mit Gilde abgleichen"), L("Sendet deine Rezepte und fragt fehlende Daten anderer Addon-Nutzer ab. Normalerweise passiert das automatisch."))

    btnScan = Button(panel, L("Berufe scannen"), 116, 24)
    btnScan:SetPoint("RIGHT", btnSync, "LEFT", -6, 0)
    btnScan:SetScript("OnClick", function()
        if not R:StartScan() then GTC:Print(L("Scan nicht möglich (Kampf, laufender Scan oder keine Gilde).")) end
    end)
    Tip(btnScan, L("Berufe scannen"), L("Liest deine Berufe aus und verteilt sie an die Gilde. Dabei öffnen sich kurz unsichtbar deine Berufsfenster. Nicht im Kampf möglich."))

    -- ---------------------------------------------------- Berufe (links)
    local left = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -70)
    left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 36)
    left:SetWidth(150)
    Backdrop(left, C.card, C.border)

    function UpdateProfs()
        local o = Opts()
        local order = {}
        for pid in pairs(R.profCounts) do order[#order + 1] = pid end
        tsort(order, function(a, b) return R:ProfName(a) < R:ProfName(b) end)
        table.insert(order, 1, 0)
        for i, pid in ipairs(order) do
            local b = profBtns[i]
            if not b then
                b = Button(left, "", 136, 30)
                b:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -6 - (i - 1) * 33)
                b.icon = b:CreateTexture(nil, "OVERLAY")
                b.icon:SetSize(20, 20)
                b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local fs = b:GetFontString()
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
                fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
                fs:SetJustifyH("LEFT")
                b:SetScript("OnClick", function(self)
                    Opts().prof = self.pid ~= 0 and self.pid or nil
                    UpdateProfs()
                    Refilter()
                end)
                Tip(b, L("Beruf filtern"), L("Zeigt nur Rezepte dieses Berufs. 'Alle Berufe' hebt den Filter auf."))
                profBtns[i] = b
            end
            b.pid = pid
            if pid == 0 then
                b.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
                b:SetText(L("Alle (") .. R.total .. ")")
            else
                b.icon:SetTexture(R:ProfIcon(pid))
                b:SetText(R:ProfName(pid) .. " (" .. R.profCounts[pid] .. ")")
            end
            SetActive(b, (pid == 0 and not o.prof) or pid == o.prof)
            b:Show()
        end
        for i = #order + 1, #profBtns do profBtns[i]:Hide() end
        if o.prof and not R.profCounts[o.prof] then o.prof = nil end
    end

    -- ------------------------------------------------------- Liste (Mitte)
    local listFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    listFrame:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 8, 0)
    listFrame:SetWidth(402)
    Backdrop(listFrame, C.card, C.border)
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(math.max(0, #R.view - ROWS), offset - delta * 2))
        UpdateList()
    end)

    empty = Text(listFrame, "GameFontHighlight", "CENTER", listFrame, "CENTER", 0, 0)
    empty:SetTextColor(unpack(C.muted))
    empty:SetWidth(340)
    empty:SetText(L("Keine Rezepte gefunden.\nScanne deine Berufe oder öffne einmal deine Berufsfenster."))

    slider = CreateFrame("Slider", nil, listFrame)
    slider:SetOrientation("VERTICAL")
    slider:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -4, -4)
    slider:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 4)
    slider:SetWidth(8)
    slider:SetObeyStepOnDrag(true)
    slider:SetValueStep(1)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.06)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(C.cyan[1], C.cyan[2], C.cyan[3], 0.7)
    thumb:SetSize(8, 40)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        offset = math.floor(v + 0.5)
        UpdateList()
    end)
    slider:Hide()

    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
        r:SetHeight(ROW_H - 4)
        r:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT", listFrame, "RIGHT", -18, 0)
        Backdrop(r, C.card, C.border)
        r.iconFrame = CreateFrame("Frame", nil, r, "BackdropTemplate")
        r.iconFrame:SetSize(34, 34)
        r.iconFrame:SetPoint("LEFT", r, "LEFT", 5, 0)
        Backdrop(r.iconFrame, C.iconPanel, C.gold)
        r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK")
        r.icon:SetPoint("TOPLEFT", 2, -2)
        r.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Text(r, "GameFontNormal", "TOPLEFT", r, "TOPLEFT", 46, -6)
        r.name:SetPoint("RIGHT", r, "RIGHT", -44, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.bop = Text(r, "GameFontHighlightSmall", "TOPRIGHT", r, "TOPRIGHT", -8, -7)
        r.bop:SetText("BoP")
        r.bop:SetTextColor(unpack(C.red))
        r.bop:Hide()
        r.crafters = Text(r, "GameFontHighlightSmall", "TOPLEFT", r, "TOPLEFT", 46, -23)
        r.crafters:SetPoint("RIGHT", r, "RIGHT", -8, 0)
        r.crafters:SetJustifyH("LEFT")
        r.crafters:SetWordWrap(false)
        r:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(C.cardHover))
            local e = self.e
            if not e then return end
            local c = Cache()[e.id] or {}
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if c.o then
                GameTooltip:SetItemByID(c.o)
            else
                GameTooltip:AddLine(c.n or (L("Rezept #") .. e.id), 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L("Klick: Materialien & Hersteller"), 0.6, 0.85, 1)
            GameTooltip:AddLine(L("Shift-Klick: Gegenstand in Chat oder Auktionshaus-Suche übernehmen"), 0.6, 0.85, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(C.card))
            GameTooltip:Hide()
        end)
        r:SetScript("OnClick", function(self)
            local e = self.e
            if not e then return end
            if IsShiftKeyDown() then
                local c = Cache()[e.id] or {}
                if LinkItem(c.o, c.n) then return end
            end
            R.sel = e.id
            UpdateList(); UpdateDetail()
        end)
        rows[i] = r
    end

    local function CrafterText(e)
        local vis, out = e.vis, {}
        for i = 1, math.min(3, #vis) do
            local n = vis[i]
            local col = R.online[n] and C.green or C.muted
            out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(col[1] * 255, col[2] * 255, col[3] * 255, n)
        end
        local s = table.concat(out, ", ")
        if #vis > 3 then s = s .. " +" .. (#vis - 3) end
        return s
    end

    function UpdateList()
        local view = R.view
        local n = #view
        local maxOff = math.max(0, n - ROWS)
        if offset > maxOff then offset = maxOff end
        updating = true
        slider:SetMinMaxValues(0, maxOff)
        slider:SetValue(offset)
        slider:SetShown(maxOff > 0)
        updating = false
        local cache = Cache()
        for i = 1, ROWS do
            local row, e = rows[i], view[offset + i]
            if e then
                local c = cache[e.id] or {}
                row.e = e
                row.icon:SetTexture(c.i or 134400)
                row.name:SetText(c.n or (L("Rezept #") .. e.id))
                local q = c.o and C_Item.GetItemQualityByID(c.o)
                local col = q and ITEM_QUALITY_COLORS[q]
                if col then row.name:SetTextColor(col.r, col.g, col.b) else row.name:SetTextColor(unpack(C.text)) end
                row.bop:SetShown(c.b == 1)
                row.crafters:SetText(CrafterText(e))
                if R.sel == e.id then
                    row:SetBackdropBorderColor(unpack(C.cyan))
                else
                    row:SetBackdropBorderColor(unpack(C.border))
                end
                row:Show()
            else
                row.e = nil
                row:Hide()
            end
        end
        empty:SetShown(n == 0)
    end

    -- ------------------------------------------------------ Details (rechts)
    detail = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 8, 0)
    detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 36)
    Backdrop(detail, C.detailPanel, C.border)

    detail.hint = Text(detail, "GameFontHighlight", "CENTER", detail, "CENTER", 0, 0)
    detail.hint:SetTextColor(unpack(C.muted))
    detail.hint:SetWidth(220)
    detail.hint:SetText(L("Wähle ein Rezept, um Materialien und Hersteller zu sehen."))

    detail.iconFrame = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    detail.iconFrame:SetSize(46, 46)
    detail.iconFrame:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -12)
    Backdrop(detail.iconFrame, C.iconPanel, C.gold)
    detail.icon = detail.iconFrame:CreateTexture(nil, "ARTWORK")
    detail.icon:SetPoint("TOPLEFT", 3, -3)
    detail.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    detail.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local head = CreateFrame("Frame", nil, detail)
    head:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -12)
    head:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -10, -12)
    head:SetHeight(46)
    head:EnableMouse(true)
    local function CurrentCache()
        return R.sel and Cache()[R.sel]
    end
    head:SetScript("OnMouseUp", function()
        local c = CurrentCache()
        if c then LinkItem(c.o, c.n) end
    end)
    head:SetScript("OnEnter", function(self)
        local c = CurrentCache()
        if not (c and c.o) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetItemByID(c.o)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("Shift-Klick: in Chat oder Auktionshaus-Suche übernehmen"), 0.6, 0.85, 1)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)

    detail.title = Text(detail, "GameFontNormal", "TOPLEFT", detail, "TOPLEFT", 68, -14)
    detail.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    detail.title:SetJustifyH("LEFT")
    detail.title:SetWordWrap(false)
    detail.sub = Text(detail, "GameFontHighlightSmall", "TOPLEFT", detail.title, "BOTTOMLEFT", 0, -6)
    detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    detail.sub:SetJustifyH("LEFT")
    detail.sub:SetWordWrap(false)
    detail.sub:SetTextColor(unpack(C.muted))

    detail.matHead = Text(detail, "GameFontNormal", "TOPLEFT", detail, "TOPLEFT", 12, -74)
    detail.matHead:SetTextColor(unpack(C.cyan))
    detail.matHead:SetText(L("MATERIALIEN"))
    detail.noMats = Text(detail, "GameFontHighlightSmall", "TOPLEFT", detail.matHead, "BOTTOMLEFT", 0, -8)
    detail.noMats:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    detail.noMats:SetJustifyH("LEFT")
    detail.noMats:SetJustifyV("TOP")
    detail.noMats:SetWordWrap(true)
    detail.noMats:SetHeight(40)
    detail.noMats:SetTextColor(unpack(C.muted))

    for i = 1, 8 do
        local r = CreateFrame("Frame", nil, detail)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", detail.matHead, "BOTTOMLEFT", 0, -6 - (i - 1) * 24)
        r:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
        r:EnableMouse(true)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.have = Text(r, "GameFontHighlightSmall", "RIGHT", r, "RIGHT", -2, 0)
        r.have:SetWidth(34)
        r.have:SetJustifyH("RIGHT")
        r.name = Text(r, "GameFontHighlightSmall", "LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.have, "LEFT", -4, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r:SetScript("OnMouseUp", function(self) LinkItem(self.itemID) end)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L("Rechts: Anzahl, die du besitzt (Taschen + Bank)"), 0.6, 0.85, 1)
            GameTooltip:AddLine(L("Shift-Klick: in Chat oder Auktionshaus-Suche übernehmen"), 0.6, 0.85, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        reagentRows[i] = r
    end

    detail.crHead = Text(detail, "GameFontNormal", "TOPLEFT", detail, "TOPLEFT", 12, -250)
    detail.crHead:SetTextColor(unpack(C.cyan))
    detail.crHead:SetText(L("HERSTELLER"))
    detail.more = Text(detail, "GameFontHighlightSmall", "TOPLEFT", detail, "TOPLEFT", 12, -400)
    detail.more:SetTextColor(unpack(C.muted))

    for i = 1, 9 do
        local r = CreateFrame("Button", nil, detail, "BackdropTemplate")
        r:SetHeight(22)
        Backdrop(r, C.card, C.border)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(8, 8)
        r.dot:SetPoint("LEFT", 8, 0)
        r.name = Text(r, "GameFontHighlightSmall", "LEFT", r.dot, "RIGHT", 8, 0)
        r.skill = Text(r, "GameFontHighlightSmall", "RIGHT", r, "RIGHT", -8, 0)
        r.skill:SetTextColor(unpack(C.muted))
        r:SetScript("OnClick", function(self)
            if self.player and self.player ~= R.me then ChatFrame_SendTell(self.player) end
        end)
        r:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(C.cardHover))
            local on = R.online[self.player]
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(self.player or "", 1, 1, 1)
            if on then
                GameTooltip:AddLine("Online", C.green[1], C.green[2], C.green[3])
            else
                GameTooltip:AddLine("Offline", C.muted[1], C.muted[2], C.muted[3])
            end
            if self.player ~= R.me then GameTooltip:AddLine(L("Klick: Flüsternachricht schreiben"), 0.6, 0.85, 1) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(C.card))
            GameTooltip:Hide()
        end)
        r:Hide()
        crafterRows[i] = r
    end

    function UpdateDetail()
        local d = detail
        local e = R.sel and R.index and R.index[R.sel]
        if not e then
            d.title:SetText("")
            d.sub:SetText("")
            d.iconFrame:Hide()
            d.hint:Show()
            d.matHead:Hide(); d.crHead:Hide(); d.more:Hide(); d.noMats:Hide()
            for _, r in ipairs(reagentRows) do r:Hide() end
            for _, r in ipairs(crafterRows) do r:Hide() end
            return
        end
        d.hint:Hide()
        local c = R:Resolve(e.id)
        d.iconFrame:Show()
        d.icon:SetTexture(c.i or 134400)
        d.title:SetText(c.n or (L("Rezept #") .. e.id))
        local q = c.o and C_Item.GetItemQualityByID(c.o)
        local col = q and ITEM_QUALITY_COLORS[q]
        if col then d.title:SetTextColor(col.r, col.g, col.b) else d.title:SetTextColor(unpack(C.gold)) end
        d.sub:SetText(R:ProfName(e.prof) .. (c.b == 1 and "  |cffff7070BoP|r" or ""))

        d.matHead:Show()
        local r = R:GetReagents(e.id)
        local n = r and math.min(8, #r / 2) or 0
        for i = 1, 8 do
            local row = reagentRows[i]
            if i <= n then
                local itemID, qty = r[i * 2 - 1], r[i * 2]
                row.itemID = itemID
                local name = C_Item.GetItemNameByID(itemID)
                if not name then C_Item.RequestLoadItemDataByID(itemID) end
                local have = C_Item.GetItemCount(itemID, true)
                row.icon:SetTexture(C_Item.GetItemIconByID(itemID) or 134400)
                row.name:SetText(qty .. "x " .. (name or ("Item " .. itemID)))
                local g = have >= qty and C.green or C.red
                row.have:SetTextColor(g[1], g[2], g[3])
                row.have:SetText(have)
                row:Show()
            else
                row:Hide()
            end
        end
        if n == 0 then
            d.noMats:SetText(r and L("Keine Materialien.") or L("Materialien unbekannt. Öffne den Beruf einmal im Spiel, dann werden sie gelesen."))
            d.noMats:Show()
        else
            d.noMats:Hide()
        end

        d.crHead:Show()
        d.crHead:ClearAllPoints()
        d.crHead:SetPoint("TOPLEFT", d.matHead, "BOTTOMLEFT", 0, -(math.max(n, 1) * 24 + 16))
        local vis = e.vis or e.cr
        local store = Store()
        for i = 1, 9 do
            local row, name = crafterRows[i], vis[i]
            if name then
                local isOn = R.online[name]
                row.player = name
                local dot = isOn and C.green or C.muted
                row.dot:SetColorTexture(dot[1], dot[2], dot[3], 1)
                row.name:SetText(name)
                row.name:SetTextColor(unpack(isOn and C.green or C.muted))
                local m = store and store.members[name]
                local p = m and m.profs[e.prof]
                row.skill:SetText(p and p.s and p.s > 0 and (p.s .. "/" .. (p.m or 0)) or "")
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", d.crHead, "BOTTOMLEFT", 0, -6 - (i - 1) * 24)
                row:SetPoint("RIGHT", d, "RIGHT", -10, 0)
                row:Show()
            else
                row:Hide()
            end
        end
        if #vis > 9 then
            d.more:SetText("+ " .. (#vis - 9) .. L(" weitere"))
            d.more:ClearAllPoints()
            d.more:SetPoint("TOPLEFT", d.crHead, "BOTTOMLEFT", 0, -6 - 9 * 24)
            d.more:Show()
        else
            d.more:Hide()
        end
    end

    -- ----------------------------------------------------------- Fusszeile
    footer = Text(panel, "GameFontHighlightSmall", "BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 12)
    footer:SetTextColor(unpack(C.muted))

    btnAuto = Button(panel, "", 124, 22)
    btnAuto:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 8)
    btnAuto:SetScript("OnClick", function()
        local o = Opts()
        o.autoScan = not o.autoScan
        SetupToggles()
    end)
    Tip(btnAuto, L("Auto-Scan"), L("Scannt deine Berufe automatisch beim Öffnen dieses Reiters (höchstens alle 10 Minuten)."))

    function UpdateFooter()
        local store = Store()
        local members, on = 0, 0
        if store then
            for name, m in pairs(store.members) do
                if next(m.profs) then
                    members = members + 1
                    if R.online[name] then on = on + 1 end
                end
            end
        end
        local users = 0
        for _ in pairs(R.peers) do users = users + 1 end
        footer:SetText((L("%d von %d Rezepten  |  %d Handwerker (%d online)  |  %d Addon-Nutzer gesehen")):format(
            #R.view, R.total, members, on, users + 1))
        title:SetText(L("REZEPTE DER GILDE  |  ") .. #R.view .. L(" Einträge"))
    end

    -- ------------------------------------------------------------ Steuerung
    function Refilter()
        if not panel:IsShown() then return end
        R:Refilter(QueryText())
        offset = 0
        UpdateList(); UpdateDetail(); UpdateFooter()
    end

    local resolveGen = 0
    local function ResolveBatch(i, gen)
        if gen ~= resolveGen then return end
        local list, n = R.list, 0
        while i <= #list and n < 200 do
            R:Resolve(list[i].id)
            i, n = i + 1, n + 1
        end
        if i <= #list then
            C_Timer.After(0, function() ResolveBatch(i, gen) end)
        else
            Refilter()
        end
    end

    function R:RefreshAll()
        if not panel:IsShown() then return end
        EnsureRoster()
        self:Rebuild()
        UpdateProfs()
        resolveGen = resolveGen + 1
        ResolveBatch(1, resolveGen)
    end

    function R:OnDataChanged()
        if not panel:IsShown() then return end
        self.dtok = (self.dtok or 0) + 1
        local t = self.dtok
        C_Timer.After(1, function()
            if t == self.dtok then R:RefreshAll() end
        end)
    end

    function R:OnItemsResolved()
        if panel:IsShown() then Refilter() end
    end

    function R:OnScanState(running)
        if not btnScan then return end
        btnScan:SetText(running and L("Scanne...") or L("Berufe scannen"))
        btnScan:SetEnabled(not running)
    end

    local rosterTicker
    panel:SetScript("OnShow", function()
        Log("UI", "Rezepte-Reiter geöffnet, Gilden-Datenbereich=" .. tostring(Store() ~= nil))
        panel:RegisterEvent("GUILD_ROSTER_UPDATE")
        C_GuildInfo.GuildRoster()
        rosterTicker = C_Timer.NewTicker(30, function() C_GuildInfo.GuildRoster() end)
        RebuildRoster()
        PruneMembers()
        SetupToggles()
        R:RefreshAll()
        R:AutoScan()
    end)
    panel:SetScript("OnHide", function()
        panel:UnregisterEvent("GUILD_ROSTER_UPDATE")
        if rosterTicker then rosterTicker:Cancel(); rosterTicker = nil end
        GameTooltip:Hide()
    end)

    -- Beim Wechsel der Gildenliste Online-Status aktualisieren (entprellt).
    local rtok = 0
    panel:SetScript("OnEvent", function()
        rtok = rtok + 1
        local t = rtok
        C_Timer.After(1, function()
            if t ~= rtok or not panel:IsShown() then return end
            RebuildRoster()
            Refilter()
        end)
    end)

    R.panel = panel
    return panel
end
