-- GTC_PROFESSIONS (v1.1.7)
-- Berufs-Inserate: Ein Angebot/Gesuch kann statt eines Gegenstands einen Beruf
-- enthalten (z. B. [Schmiedekunst]). Ein Klick darauf zeigt alle Rezepte, die der
-- Ersteller in diesem Beruf kennt (Daten aus dem Gilden-Rezeptabgleich, Recipes.lua).
--
-- Abwaertskompatibilitaet: Das Sync-Format verlangt weiterhin eine Item-ID. Berufs-
-- Inserate tragen deshalb ein ungebundenes "Platzhalter-Item" des Berufs (z. B. den
-- Schmiedehammer) plus die neuen Felder `profession` (skillLineID) und optional
-- `professionLink` (nativer Berufs-Link des Spiels). Aeltere GTC-Versionen ignorieren
-- die neuen Felder und zeigen das Platzhalter-Item mit der Beschreibung an.

local GTC = _G.GuildTradeCenter
if type(GTC) ~= "table" then
    return
end
local L = GTC.T

local P = {}
GTC.Prof = P

P.LINK_COLOR = "ffffd000"

-- [skillLineID] = { englischer Name, deutscher Name, Icon }
P.INFO = {
    [171] = { "Alchemy",        "Alchemie",          "Interface\\Icons\\Trade_Alchemy" },
    [164] = { "Blacksmithing",  "Schmiedekunst",     "Interface\\Icons\\Trade_BlackSmithing" },
    [333] = { "Enchanting",     "Verzauberkunst",    "Interface\\Icons\\Trade_Engraving" },
    [202] = { "Engineering",    "Ingenieurskunst",   "Interface\\Icons\\Trade_Engineering" },
    [773] = { "Inscription",    "Inschriftenkunde",  "Interface\\Icons\\INV_Inscription_Tradeskill01" },
    [755] = { "Jewelcrafting",  "Juwelierskunst",    "Interface\\Icons\\INV_Misc_Gem_01" },
    [165] = { "Leatherworking", "Lederverarbeitung", "Interface\\Icons\\Trade_LeatherWorking" },
    [197] = { "Tailoring",      "Schneiderei",       "Interface\\Icons\\Trade_Tailoring" },
    [185] = { "Cooking",        "Kochkunst",         "Interface\\Icons\\INV_Misc_Food_15" },
    [186] = { "Mining",         "Bergbau",           "Interface\\Icons\\Trade_Mining" },
    [129] = { "First Aid",      "Erste Hilfe",       "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
}

-- Weitere Namen, unter denen ein Beruf im Link stehen kann.
local EXTRA_NAMES = {
    ["smelting"] = 186, ["verhüttung"] = 186,
    ["juwelenschleifen"] = 755,
}

-- Platzhalter-Items (ungebunden, in allen Spielversionen vorhanden). Das erste Item,
-- das der Client kennt, wird verwendet.
P.TOKEN_ITEMS = {
    [171] = { 3371 },          -- Leere Phiole
    [164] = { 5956 },          -- Schmiedehammer
    [333] = { 10940 },         -- Seltsamer Staub
    [202] = { 6219 },          -- Bogenlichtschraubenschluessel
    [773] = { 39354, 39505 },  -- Leichtes Pergament / Inschriftenset
    [755] = { 20815, 774 },    -- Juwelierset / Malachit
    [165] = { 2318 },          -- Leichtes Leder
    [197] = { 2996 },          -- Leinenstoffballen
    [185] = { 2678 },          -- Milde Gewuerze
    [186] = { 2901 },          -- Spitzhacke
    [129] = { 1251 },          -- Leinenverband
}

-- Berufs-Zauber (alle Raenge) fuer das Erkennen nativer Berufs-Links.
local SPELLS = {
    [171] = { 2259, 3101, 3464, 11611, 28596, 51304 },
    [164] = { 2018, 3100, 3538, 9785, 29844, 51300 },
    [333] = { 7411, 7412, 7413, 13920, 28029, 51313 },
    [202] = { 4036, 4037, 4038, 12656, 30350, 51306 },
    [773] = { 45357, 45358, 45359, 45360, 45361, 45363 },
    [755] = { 25229, 25230, 28894, 28895, 28897, 51311 },
    [165] = { 2108, 3104, 3811, 10662, 32549, 51302 },
    [197] = { 3908, 3909, 3910, 12180, 26790, 51309 },
    [185] = { 2550, 3102, 3413, 18260, 33359, 51296 },
    [186] = { 2575, 2576, 3564, 10248, 29354, 50310, 2656 },
    [129] = { 3273, 3274, 7924, 10846, 27028, 45542 },
}
local SPELL_TO_PROF = {}
for pid, list in pairs(SPELLS) do
    for _, spellID in ipairs(list) do SPELL_TO_PROF[spellID] = pid end
end

local function lower(s)
    return type(s) == "string" and s:lower() or ""
end

function P:IsKnown(pid)
    return type(pid) == "number" and self.INFO[pid] ~= nil
end

-- Angezeigter (lokalisierter) Name des Berufs.
function P:Name(pid)
    local R = GTC.Recipes
    if R and R.ProfName then
        local ok, name = pcall(R.ProfName, R, pid)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    local info = self.INFO[pid]
    if not info then return L("Beruf ") .. tostring(pid) end
    return (GTC.GetLanguage and GTC.GetLanguage() == "de") and info[2] or info[1]
end

function P:Icon(pid)
    local info = self.INFO[pid]
    return info and info[3] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Ermittelt den Beruf zu einem Namen ("Schmiedekunst", "Blacksmithing", ...).
function P:FromName(name)
    local n = lower(name):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then return nil end
    for pid, info in pairs(self.INFO) do
        if n == lower(info[1]) or n == lower(info[2]) or n == lower(self:Name(pid)) then
            return pid
        end
    end
    return EXTRA_NAMES[n]
end

-- Platzhalter-Item fuer das Sync-Format.
function P:TokenItem(pid)
    local list = self.TOKEN_ITEMS[pid]
    if not list then return nil end
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    for _, itemID in ipairs(list) do
        if type(instant) ~= "function" then return itemID end
        local ok, id = pcall(instant, itemID)
        if ok and id then return itemID end
    end
    return list[1]
end

function P:RequestTokenItem(pid)
    local itemID = self:TokenItem(pid)
    if itemID and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return itemID
end

-- GTC-eigener Berufs-Link (nur innerhalb von GTC klickbar, nicht im Chat versendbar).
function P:BuildLink(pid)
    if not self:IsKnown(pid) then return nil end
    return ("|c%s|Hgtcprof:%d|h[%s]|h|r"):format(self.LINK_COLOR, pid, self:Name(pid))
end

-- Prueft einen nativen Berufs-Link ("|Htrade:...|h[Name]|h") auf erlaubte Zeichen.
-- Gesyncte Links stammen von anderen Spielern, daher streng filtern.
function P:SanitizeNativeLink(link)
    if type(link) ~= "string" or #link > 400 then return nil end
    local color, data, name = link:match("^|c(%x%x%x%x%x%x%x%x)|Htrade:([%w%-:%+/=_]+)|h%[([^%]|]+)%]|h|r$")
    if not data then
        data, name = link:match("^|Htrade:([%w%-:%+/=_]+)|h%[([^%]|]+)%]|h$")
        color = self.LINK_COLOR
    end
    if not data or #name > 64 then return nil end
    return ("|c%s|Htrade:%s|h[%s]|h|r"):format(color, data, name), data, name
end

-- Beruf eines nativen Berufs-Links bestimmen. Formate je Spielversion verschieden:
--   trade:<GUID>:<SpellID>:<SkillLineID>   (aktuelle Clients)
--   trade:<SpellID>:<Skill>:<Max>:<GUID>:<Daten>   (aeltere Clients)
local function ProfFromNative(data, name)
    local fields = {}
    for part in (data .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = part end
    -- 1. Berufs-Zauber (eindeutig)
    for _, f in ipairs(fields) do
        local n = tonumber(f)
        if n and SPELL_TO_PROF[n] then return SPELL_TO_PROF[n] end
    end
    -- 2. Name im Link
    local byName = P:FromName(name)
    if byName then return byName end
    -- 3. SkillLineID als letztes Zahlenfeld (aktuelles Format)
    local last = tonumber(fields[#fields])
    if last and P.INFO[last] then return last end
    return nil
end

-- Liest Beruf und ggf. nativen Link aus dem Text des Item-Feldes.
-- Rueckgabe: pid, nativerLink (oder nil)
function P:Parse(text)
    if type(text) ~= "string" or text == "" then return nil end
    local own = tonumber(text:match("|Hgtcprof:(%d+)|h"))
    if own and self:IsKnown(own) then return own, nil end

    local full = text:match("(|c%x%x%x%x%x%x%x%x|Htrade:[^|]+|h%[[^%]|]+%]|h|r)")
        or text:match("(|Htrade:[^|]+|h%[[^%]|]+%]|h)")
    if full then
        local clean, data, name = self:SanitizeNativeLink(full)
        if clean then
            local pid = ProfFromNative(data, name)
            if pid then return pid, clean end
        end
    end
    return nil
end

-- Beruf eines Inserats (nil, wenn es ein normales Item-Inserat ist).
function P:EntryProfession(entry)
    if type(entry) ~= "table" then return nil end
    local pid = tonumber(entry.profession)
    if pid and self:IsKnown(pid) then return pid end
    return nil
end

function P:DisplayLink(entry)
    local pid = self:EntryProfession(entry)
    return pid and self:BuildLink(pid) or nil
end

-- Anzahl der Rezepte, die der Ersteller des Inserats in diesem Beruf kennt.
function P:RecipeInfo(entry)
    local pid = self:EntryProfession(entry)
    local R = GTC.Recipes
    if not pid or not (R and R.MemberProfInfo) then return nil end
    return R:MemberProfInfo(entry.character, pid)
end

-- Eigene Berufe fuer das Auswahlmenue: Rezept-Scan, GetProfessions und Fertigkeiten.
function P:OwnProfessions()
    local own = {}
    local R = GTC.Recipes
    if R and R.OwnProfessions then
        local ok, list = pcall(R.OwnProfessions, R)
        if ok and type(list) == "table" then
            for pid, info in pairs(list) do own[pid] = info end
        end
    end
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local ok, a, b, c, d, e, f = pcall(GetProfessions)
        if ok then
            for _, index in ipairs({ a, b, c, d, e, f }) do
                local ok2, name, _, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, index)
                local pid = ok2 and (self.INFO[tonumber(skillLine) or -1] and tonumber(skillLine) or self:FromName(name))
                if pid and not own[pid] then own[pid] = { s = rank, m = maxRank } end
            end
        end
    end
    if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        local ok, count = pcall(GetNumSkillLines)
        for i = 1, (ok and tonumber(count) or 0) do
            local ok2, name, isHeader, _, rank, _, _, maxRank = pcall(GetSkillLineInfo, i)
            local pid = ok2 and not isHeader and self:FromName(name)
            if pid and not own[pid] then own[pid] = { s = rank, m = maxRank } end
        end
    end
    return own
end

-- Nativer Link, falls das Berufsfenster dieses Berufs gerade offen ist.
function P:CurrentNativeLink(pid)
    local T = C_TradeSkillUI
    if not (T and type(T.GetTradeSkillListLink) == "function" and type(T.GetBaseProfessionInfo) == "function") then
        return nil
    end
    local ok, info = pcall(T.GetBaseProfessionInfo)
    if not ok or type(info) ~= "table" or tonumber(info.professionID) ~= pid then return nil end
    local ok2, link = pcall(T.GetTradeSkillListLink)
    if ok2 then return (self:SanitizeNativeLink(link)) end
    return nil
end

-- Zeigt die Rezepte des Inserat-Erstellers im Reiter "Rezepte".
function P:ShowRecipes(entry, onBack)
    local pid = self:EntryProfession(entry)
    if not pid then return false end
    if type(GTC.ShowCrafterRecipes) ~= "function" then
        GTC:Print(L("Das Rezepte-Modul ist nicht verfügbar."))
        return false
    end
    GTC:ShowCrafterRecipes(entry.character, pid, onBack)
    return true
end

-- Oeffnet den nativen Berufs-Link (Blizzard-Berufsfenster), falls vorhanden.
function P:OpenNative(entry, owner)
    local link = type(entry) == "table" and self:SanitizeNativeLink(entry.professionLink)
    if not link then return false end
    local raw, text = link:match("|H(trade:[^|]+)|h(%[[^%]]+%])|h")
    if not raw then return false end
    if type(SetItemRef) == "function" then
        local ok = pcall(SetItemRef, raw, text, "LeftButton", owner or DEFAULT_CHAT_FRAME)
        return ok
    end
    return false
end

-- Tooltip fuer ein Berufs-Inserat.
function P:FillTooltip(tooltip, entry)
    local pid = self:EntryProfession(entry)
    if not pid then return false end
    tooltip:AddLine(self:Name(pid), 1, 0.82, 0)
    tooltip:AddLine((entry.kind == "wanted" and L("Gesucht von: ") or L("Angeboten von: ")) .. tostring(entry.character or "?"), 1, 1, 1)
    local info = self:RecipeInfo(entry)
    if info and info.count then
        local skill = (info.s and info.s > 0) and ("  (" .. info.s .. (info.m and info.m > 0 and ("/" .. info.m) or "") .. ")") or ""
        tooltip:AddLine((L("%d bekannte Rezepte")):format(info.count) .. skill, 0.3, 0.9, 0.4)
    elseif entry.kind ~= "wanted" then
        tooltip:AddLine(L("Rezepte noch nicht synchronisiert"), 0.7, 0.7, 0.7)
    end
    return true
end
