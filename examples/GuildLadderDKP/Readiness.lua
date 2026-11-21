local ADDON, D = ...
local C = D.Config
local Print = D.Print

--[[
  v0.4.0 Readiness (officers + GM only to see it)

  Two halves:
  1. BUFFS (flask / elixirs / food / scrolls): an officer's client reads every
     raid member's buffs itself. No add-on is needed on the raider's side.
     It re-scans every few seconds out of combat (so there is always a recent
     reading), and takes a snapshot when a boss is pulled (ENCOUNTER_START).
     Trash never triggers anything.
  2. GEAR (item level, missing enchants, empty sockets, weapon oil): only the
     player can see their own gear reliably, so each client reports it
     ("RR" message) when joining a raid, when its gear changes, or when an
     officer asks ("RQ"). Only officers store and show the reports.

  What counts (Req / Rec / Off per item) and how strict each boss is (Off /
  Standard / Strict) are GM settings, stored as CFG events like every other
  guild setting:  RD_FLASK RD_FOOD RD_ENCH RD_GEMS RD_SCROLL RD_OIL RD_MINILVL
  RD_DEFAULT RD_BONUS_ON RD_BONUS RD_JUDGE   and   "RB:<boss key>" per boss.
]]

local R = {}
D.Rd = R

R.gear = {}        -- player -> last gear report received
R.scan = {}        -- player -> last good buff reading
R.hist = {}        -- recent boss-pull snapshots, newest first
R.excluded = {}    -- players an officer excluded tonight
R.whispered = {}   -- player -> GetTime() of the last reminder
R.pullCount = {}   -- boss key -> pulls since the last kill
R.index = {}       -- night .. boss key -> { first = snapshot, kill = snapshot }
R.seen = {}        -- boss names the game has told us about

local EXPIRE = 10 * 60          -- a buff with less than this left counts as "running out"
local WHISPER_GAP = 120         -- seconds before the same player can be reminded again

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
R.RULES = {
  { "FLASK", "Flask or battle + guardian elixir" },
  { "FOOD", "Food (Well Fed)" },
  { "ENCH", "Enchants" },
  { "GEMS", "Empty gem sockets" },
  { "SCROLL", "Scrolls" },
  { "OIL", "Weapon oil / stone" },
}

function R.Rule(key)
  local v = D.Cfg("RD_" .. key)
  if v == "req" or v == "rec" or v == "off" then return v end
  return C["RD_" .. key] or "off"
end

function R.BossKey(name)
  local s = tostring(name or ""):lower()
  s = s:gsub("^the%s+", "")
  s = s:gsub("[^%w]", "")
  return s
end

-- "off" | "std" | "strict"
function R.BossLevel(name)
  local v = D.Cfg("RB:" .. R.BossKey(name))
  if v == "off" or v == "std" or v == "strict" then return v end
  v = D.Cfg("RD_DEFAULT")
  if v == "off" or v == "std" or v == "strict" then return v end
  return "std"
end

function R.SetBossLevel(name, level)
  return D.SetConfig("RB:" .. R.BossKey(name), level)
end

-- v0.4.1: boss kill values. The game's encounter name has to match the saved
-- one, so a value saved as "Illidari Council" still counts for "The Illidari
-- Council" (same name minus capitals, a leading "The" and punctuation).
function D.BossValueKey(name)
  local bv = D.data and D.data.bossValues
  if bv then
    if bv[name] ~= nil then return name end
    local k = R.BossKey(name)
    for n in pairs(bv) do
      if R.BossKey(n) == k then return n end
    end
  end
  return name
end

function D.BossValue(name)
  local bv = D.data and D.data.bossValues
  if not bv or not name then return nil end
  return bv[D.BossValueKey(name)]
end

-- Raids and their bosses (names as the game announces the encounter)
R.RAIDS = {
  { name = "Black Temple", bosses = { "High Warlord Naj'entus", "Supremus", "Shade of Akama", "Teron Gorefiend",
    "Gurtogg Bloodboil", "Reliquary of Souls", "Mother Shahraz", "The Illidari Council", "Illidan Stormrage" } },
  { name = "Mount Hyjal", inst = "Hyjal Summit", bosses = { "Rage Winterchill", "Anetheron", "Kaz'rogal", "Azgalor", "Archimonde" } },
  { name = "Sunwell Plateau", bosses = { "Kalecgos", "Brutallus", "Felmyst", "Eredar Twins", "M'uru", "Kil'jaeden" } },
  { name = "Zul'Aman", bosses = { "Nalorakk", "Akil'zon", "Jan'alai", "Halazzi", "Hex Lord Malacrass", "Zul'jin" } },
  { name = "Tempest Keep", bosses = { "Al'ar", "Void Reaver", "High Astromancer Solarian", "Kael'thas Sunstrider" } },
  { name = "Serpentshrine Cavern", bosses = { "Hydross the Unstable", "The Lurker Below", "Leotheras the Blind",
    "Fathom-Lord Karathress", "Morogrim Tidewalker", "Lady Vashj" } },
  { name = "Magtheridon's Lair", bosses = { "Magtheridon" } },
  { name = "Gruul's Lair", bosses = { "High King Maulgar", "Gruul the Dragonkiller" } },
  { name = "Karazhan", bosses = { "Attumen the Huntsman", "Moroes", "Maiden of Virtue", "The Curator", "Terestian Illhoof",
    "Shade of Aran", "Netherspite", "Prince Malchezaar", "Nightbane" } },
}

-- the raid we're standing in, if it is one of the above
function R.CurrentRaid()
  local inst = GetInstanceInfo and select(1, GetInstanceInfo())
  if not inst then return nil end
  inst = inst:lower()
  for i, rd in ipairs(R.RAIDS) do
    if rd.name:lower() == inst or (rd.inst and rd.inst:lower() == inst) then return i, rd end
  end
  return nil
end

---------------------------------------------------------------------------
-- Reading buffs
---------------------------------------------------------------------------
local FLASK_IDS = { [28518] = 1, [28519] = 1, [28520] = 1, [28521] = 1, [28540] = 1, [17626] = 1, [17627] = 1,
  [17628] = 1, [17629] = 1, [42735] = 1,
  [46837] = 1, [46838] = 1 }  -- Pure Death of Shattrath (the other Shattrath flasks are matched by name)
-- scroll buffs are named after the stat they give
local SCROLL_NAMES = { Agility = 1, Strength = 1, Intellect = 1, Spirit = 1, Stamina = 1, Armor = 1, Protection = 1 }

-- name, spellId, icon, expirationTime of buff #i (nil at the end)
local function AuraAt(unit, i)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
    if ok and a then return a.name, a.spellId, a.icon, a.expirationTime end
    return nil
  end
  if UnitAura then
    local ok, name, icon, _, _, _, exp, _, _, _, spellId = pcall(UnitAura, unit, i, "HELPFUL")
    if ok and name then return name, spellId, icon, exp end
  end
  return nil
end

-- Buffs recognised by spell id. The first group was read off real raiders with
-- /dkp ready scan; the second group is from memory and may need correcting.
local KNOWN = {
  [28503] = "elixir", [28509] = "elixir",   -- Major Shadow Power, Greater Mana Regeneration (Major Mageblood)
  [33077] = "scroll", [33082] = "scroll",   -- Agility, Strength (scrolls V)
  [33256] = "food",                         -- Well Fed
  -- from memory, not yet confirmed in game:
  [28497] = "elixir", [28490] = "elixir", [28491] = "elixir", [28493] = "elixir", [28501] = "elixir",
  [28514] = "elixir", [17538] = "elixir", [17539] = "elixir", [39627] = "elixir",
}
local KINDS = { flask = true, elixir = true, food = true, scroll = true }

-- "flask" | "elixir" | "food" | "scroll" | nil. v0.4.3: the guild master can teach
-- it more (/dkp ready add <id> <kind>, saved as "RDX:<id>"; "none" = ignore that buff).
local function Classify(name, id)
  if type(id) == "number" then
    local extra = D.Cfg("RDX:" .. id)
    if extra == "none" then return nil end
    if KINDS[extra] then return extra end
    if FLASK_IDS[id] then return "flask" end
    if KNOWN[id] then return KNOWN[id] end
  end
  if type(name) ~= "string" then return nil end
  if name:find("^Flask of") then return "flask" end
  -- v0.4.4: the Mark of the Illidari flasks (Shattrath Flask of ...) apply a buff
  -- called "<effect> of Shattrath", e.g. "Pure Death of Shattrath"
  if name:find(" of Shattrath$") then return "flask" end
  if name:find("Elixir") then return "elixir" end
  if name == "Well Fed" then return "food" end
  if SCROLL_NAMES[name] then return "scroll" end
  return nil
end

local function ScanUnit(unit)
  if not unit or not UnitExists(unit) then return nil end
  local r = { flask = false, elix = 0, food = false, scroll = 0, t = GetTime() }
  local now = GetTime()
  local soonest
  for i = 1, 40 do
    local name, id, _, exp = AuraAt(unit, i)
    if not name then break end
    if D.Secret(name, id, exp) then r.secret = true return r end
    local left = (type(exp) == "number" and exp > 0) and (exp - now) or nil
    local kind = Classify(name, id)
    if kind == "flask" or kind == "elixir" then
      if kind == "flask" then r.flask = true else r.elix = r.elix + 1 end
      if left then soonest = soonest and math.min(soonest, left) or left end
    elseif kind == "food" then
      r.food = true
      r.foodLeft = left
    elseif kind == "scroll" then
      r.scroll = r.scroll + 1
    end
  end
  r.flaskLeft = soonest
  return r
end

-- Re-read everyone's buffs. A reading the game hides keeps the last good one.
function R.ScanRaid()
  if not D.InRaid() then return end
  for name, info in pairs(D.raid) do
    if info.unit and info.online ~= false then
      local ok, s = pcall(ScanUnit, info.unit)
      if ok and s then
        if s.secret then
          if R.scan[name] then R.scan[name].stale = true end
        else
          R.scan[name] = s
        end
      end
    end
  end
  R.scanT = GetTime()
end

---------------------------------------------------------------------------
-- My own gear (what I report to the officers)
---------------------------------------------------------------------------
local SLOT = { [1] = "Head", [3] = "Shoulders", [5] = "Chest", [7] = "Legs", [8] = "Feet", [9] = "Wrists",
  [10] = "Hands", [15] = "Back", [16] = "Main hand", [17] = "Off hand" }
local ENCH_SLOTS = { 5, 7, 8, 9, 10, 15, 16, 17 }
local NEEDS = { [5] = true, [7] = true, [8] = true, [9] = true, [10] = true, [15] = true }
local ALL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
R.SLOT = SLOT

local function ItemLevel(link)
  local f = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
  if f then
    local ok, v = pcall(f, link)
    if ok and type(v) == "number" and v > 0 then return v end
  end
  if D.GetItemInfo then
    local ok, _, _, _, lvl = pcall(D.GetItemInfo, link)
    if ok and type(lvl) == "number" and lvl > 0 then return lvl end
  end
  return nil
end

local function EquipLoc(link)
  if not D.GetItemInfoInstant then return nil end
  local ok, _, _, _, loc = pcall(D.GetItemInfoInstant, link)
  if ok then return loc end
  return nil
end

local function EnchantNeeded(slot, link)
  if slot == 17 then
    local loc = EquipLoc(link)
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD"
  end
  if slot == 16 then return true end
  return NEEDS[slot] == true
end

local sockCache = {}
local function SocketCount(id)
  if not id then return 0 end
  if sockCache[id] ~= nil then return sockCache[id] end
  local f = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not f then return 0 end
  local ok, stats = pcall(f, "item:" .. id)
  if not ok or type(stats) ~= "table" then return 0 end
  local n = 0
  for k, v in pairs(stats) do
    if type(k) == "string" and k:find("^EMPTY_SOCKET_") then n = n + (tonumber(v) or 0) end
  end
  sockCache[id] = n
  return n
end

R.EnchantNeeded, R.SocketCount = EnchantNeeded, SocketCount -- v1.3.0: the Enchants & Gems window uses the same rules

-- 1 = a temporary weapon enchant (oil, stone, poison, imbue) is on EITHER weapon,
-- 0 = none, nil = no weapon. v0.4.2: either hand counts, for every class.
-- Melee leave the main hand bare on purpose (a stone there cancels a shaman's
-- Windfury), and hunters can use either hand.
local function OilState()
  if not GetInventoryItemLink("player", 16) then return nil end
  if not GetWeaponEnchantInfo then return nil end
  local ok, hasMH, _, _, _, hasOH = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  return (hasMH or hasOH) and 1 or 0
end

-- v0.4.5: scrolls only matter for melee and hunters. Casters and healers get
-- Intellect / Spirit from the raid's mage and priest buffs.
local MELEE = { WARRIOR = true, ROGUE = true, HUNTER = true }
local CASTER = { MAGE = true, PRIEST = true, WARLOCK = true }
-- hybrids: the talent tree (1-3) that counts as melee. Shaman 2 = Enhancement,
-- Druid 2 = Feral, Paladin 2 = Protection and 3 = Retribution.
local HYBRID_MELEE = { SHAMAN = { [2] = true }, DRUID = { [2] = true }, PALADIN = { [2] = true, [3] = true } }

-- the talent tree (1-3) I have the most points in, or nil if the game won't say
local function MainTalentTab()
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local ok, n = pcall(GetNumTalentTabs)
  if not ok or type(n) ~= "number" then return nil end
  local best, bestPts = nil, 0
  for i = 1, n do
    local ok2, a, _, c, _, e = pcall(GetTalentTabInfo, i)
    if ok2 then
      local pts = (type(a) == "string") and c or e -- older clients: name, icon, points; newer: id, name, desc, icon, points
      if type(pts) == "number" and pts > bestPts then best, bestPts = i, pts end
    end
  end
  return best
end

-- true = scrolls count, false = they don't, nil = a hybrid whose spec we don't know
function R.ScrollsApply(class, tab)
  if MELEE[class] then return true end
  if CASTER[class] then return false end
  local m = HYBRID_MELEE[class]
  if m and tab then return m[tab] == true end
  return nil
end

-- { ilvl, oil, ench = { slot, ... }, gems = { { slot, empty }, ... } }
function R.CollectGear()
  local floor = tonumber(D.Cfg("RD_MINILVL")) or 0
  local total, n = 0, 0
  local ench, gems = {}, {}
  for _, slot in ipairs(ALL_SLOTS) do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local id, e, g1, g2, g3, g4 = link:match("item:(%d+):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
      local ilvl = ItemLevel(link)
      if ilvl then total = total + ilvl; n = n + 1 end
      if not ilvl or ilvl >= floor then
        if EnchantNeeded(slot, link) and (tonumber(e) or 0) == 0 then ench[#ench + 1] = slot end
        local sockets = SocketCount(tonumber(id))
        if sockets > 0 then
          local filled = 0
          for _, g in ipairs({ g1, g2, g3, g4 }) do
            if (tonumber(g) or 0) ~= 0 then filled = filled + 1 end
          end
          if sockets - filled > 0 then gems[#gems + 1] = { slot, sockets - filled } end
        end
      end
    end
  end
  local _, class = UnitClass("player")
  return { ilvl = n > 0 and math.floor(total / n + 0.5) or 0, oil = OilState(), ench = ench, gems = gems, t = GetTime(),
    scroll = R.ScrollsApply(class, MainTalentTab()) }
end

-- my own report, kept for a few seconds so a refresh doesn't redo all of it
function R.SelfGear()
  if not R.self or GetTime() - R.self.t > 20 then R.self = R.CollectGear() end
  return R.self
end

local function EncodeReport(g)
  local gems = {}
  for _, x in ipairs(g.gems) do gems[#gems + 1] = x[1] .. ":" .. x[2] end
  return D.Pack("RR", 1, g.ilvl, g.oil == nil and "" or g.oil, table.concat(g.ench, ","), table.concat(gems, ","),
    g.scroll == nil and "" or (g.scroll and 1 or 0))
end

local function DecodeReport(p)
  local g = { ilvl = tonumber(p[3]) or 0, ench = {}, gems = {}, t = GetTime(), at = GetServerTime() }
  if p[4] ~= nil and p[4] ~= "" then g.oil = tonumber(p[4]) end
  for s in (p[5] or ""):gmatch("[^,]+") do
    local n = tonumber(s)
    if n then g.ench[#g.ench + 1] = n end
  end
  for s, c in (p[6] or ""):gmatch("(%d+):(%d+)") do g.gems[#g.gems + 1] = { tonumber(s), tonumber(c) } end
  if p[7] ~= nil and p[7] ~= "" then g.scroll = (p[7] == "1") end
  return g
end

function R.SendReport()
  local ch = D.GroupChannel()
  if not ch then return end
  R.self = nil
  D.Send(EncodeReport(R.SelfGear()), "GROUP")
end

-- a little random delay so 25 players don't all answer in the same second
function R.QueueReport(delay)
  if not D.InGroup() or R.reportPending then return end
  R.reportPending = true
  C_Timer.After(delay or (2 + math.random() * 10), function()
    R.reportPending = false
    R.SendReport()
  end)
end

-- officers: ask everybody for their gear (at most once a minute)
function R.RequestGear(force)
  if not D.InGroup() or not D.IsAdmin() then return end
  if not force and R.requestT and GetTime() - R.requestT < 60 then return end
  R.requestT = GetTime()
  D.Send(D.Pack("RQ"), "GROUP")
  R.QueueReport(1) -- my own too
end

D.handlers.RR = function(p, sender, channel)
  if channel ~= "RAID" and channel ~= "PARTY" then return end
  if not D.IsAdmin() then return end
  local name = D.Canon(sender)
  if not name then return end
  R.gear[name] = DecodeReport(p)
  if D.RefreshReadyUI then D.RefreshReadyUI() end
end

D.handlers.RQ = function(_, sender, channel)
  if channel ~= "RAID" and channel ~= "PARTY" then return end
  if not D.IsAdmin(sender) then return end
  R.QueueReport()
end

---------------------------------------------------------------------------
-- Judging one raider
---------------------------------------------------------------------------
local function TimeLeft(left)
  if not left then return "" end
  return ("%dm"):format(math.max(0, math.floor(left / 60)))
end
R.TimeLeft = TimeLeft

-- level: "std" (Req items flagged) or "strict" (Rec items count as Req too)
function R.Eval(name, level)
  local info = D.raid[name]
  local isMe = D.SameName(name, D.Me())
  local scan = R.scan[name]
  local gear = isMe and R.SelfGear() or R.gear[name]
  if isMe and gear then gear.oil = OilState() end
  local row = { name = name, class = info and info.class, missing = {}, short = {}, recs = {}, runout = {}, oks = {} }

  local function Eff(key)
    local r = R.Rule(key)
    if r == "rec" and level == "strict" then return "req" end
    return r
  end
  local function Miss(key, long, short)
    if Eff(key) == "req" then
      row.missing[#row.missing + 1] = long
      row.short[#row.short + 1] = short or long
      return "bad"
    end
    row.recs[#row.recs + 1] = long
    return "warn"
  end

  local noScan = (not scan) or scan.secret
  local function Buff(key, have, left, long, short, runName)
    if R.Rule(key) == "off" then return { state = "na" } end
    if noScan then return { state = "none" } end
    if have then
      if left and left < EXPIRE then
        row.expiring = true
        row.runout[#row.runout + 1] = ("%s runs out in %s"):format(runName, TimeLeft(left))
      end
      return { state = "ok", left = left }
    end
    return { state = Miss(key, long, short) }
  end

  local haveFlask = scan and (scan.flask or (scan.elix or 0) >= 2)
  local flaskLong = (scan and (scan.elix or 0) == 1 and not scan.flask) and "Second elixir (battle + guardian)"
    or "Flask or battle + guardian elixir"
  row.flask = Buff("FLASK", haveFlask, scan and scan.flaskLeft, flaskLong, "flask or elixirs", "Flask / elixir")
  row.food = Buff("FOOD", scan and scan.food, scan and scan.foodLeft, "Well Fed (food)", "food", "Food")
  -- scrolls only count for melee and hunters; a hybrid whose spec we can't tell is left alone
  local applies = gear and gear.scroll
  if applies == nil then applies = R.ScrollsApply(row.class) end
  if applies == true then
    row.scroll = Buff("SCROLL", scan and (scan.scroll or 0) > 0, nil, "Scroll buff", "scroll", "Scroll")
  else
    row.scroll = { state = "na" }
  end

  -- gear
  if R.Rule("ENCH") == "off" then
    row.ench = { state = "na" }
  elseif not gear then
    row.ench = { state = "none" }
  elseif #gear.ench == 0 then
    row.ench = { state = "ok" }
  else
    local names = {}
    for _, slot in ipairs(gear.ench) do names[#names + 1] = SLOT[slot] or ("slot " .. slot) end
    local st = Miss("ENCH", (#names == 1) and (names[1] .. ": no enchant") or ("No enchant: " .. table.concat(names, ", ")),
      "enchants (" .. table.concat(names, ", ") .. ")")
    row.ench = { state = st, n = #gear.ench }
  end
  if R.Rule("GEMS") == "off" then
    row.gems = { state = "na" }
  elseif not gear then
    row.gems = { state = "none" }
  elseif #gear.gems == 0 then
    row.gems = { state = "ok" }
  else
    local names, total = {}, 0
    for _, x in ipairs(gear.gems) do
      names[#names + 1] = SLOT[x[1]] or ("slot " .. x[1])
      total = total + x[2]
    end
    local st = Miss("GEMS", ("%d empty gem socket%s: %s"):format(total, total == 1 and "" or "s", table.concat(names, ", ")),
      "empty gem sockets (" .. table.concat(names, ", ") .. ")")
    row.gems = { state = st, n = total }
  end
  if R.Rule("OIL") == "off" then
    row.oil = { state = "na" }
  elseif not gear then
    row.oil = { state = "none" }
  elseif gear.oil == nil then
    row.oil = { state = "na" }
  elseif gear.oil == 1 then
    row.oil = { state = "ok" }
  else
    row.oil = { state = Miss("OIL", "Weapon oil / stone on either weapon", "weapon oil") }
  end
  row.ilvl = gear and gear.ilvl or nil
  row.hasGear = gear ~= nil
  row.hasBuffs = not noScan

  row.bad = 0
  row.prepared = true
  for _, k in ipairs({ "flask", "food", "scroll", "oil", "ench", "gems" }) do
    local s = row[k].state
    if s == "bad" then row.bad = row.bad + 1 end
    if s == "none" then row.nodata = true end
    local key = (k == "flask" and "FLASK") or (k == "food" and "FOOD") or (k == "scroll" and "SCROLL")
      or (k == "oil" and "OIL") or (k == "ench" and "ENCH") or "GEMS"
    if R.Rule(key) ~= "off" and Eff(key) == "req" and s ~= "ok" and s ~= "na" then row.prepared = false end
  end
  row.ready = row.bad == 0 and not row.nodata
  if row.hasGear and gear.oil == 1 then row.oks[#row.oks + 1] = "Weapon oil active" end
  if row.hasGear and #gear.gems == 0 and R.Rule("GEMS") ~= "off" then row.oks[#row.oks + 1] = "All sockets filled" end
  if row.ilvl and row.ilvl > 0 then row.oks[#row.oks + 1] = "Average item level " .. row.ilvl end
  return row
end

-- everyone in the raid, problems first, plus the counts for the pills
function R.BuildRows(level)
  local rows = {}
  local sum = { total = 0, ready = 0, flask = 0, food = 0, gear = 0, expiring = 0, nodata = 0 }
  for name, info in pairs(D.raid) do
    if info.online ~= false and not R.excluded[name] then
      local row = R.Eval(name, level)
      rows[#rows + 1] = row
      sum.total = sum.total + 1
      if row.ready then sum.ready = sum.ready + 1 end
      if row.flask.state == "bad" then sum.flask = sum.flask + 1 end
      if row.food.state == "bad" then sum.food = sum.food + 1 end
      if row.ench.state == "bad" or row.gems.state == "bad" then sum.gear = sum.gear + 1 end
      if row.expiring then sum.expiring = sum.expiring + 1 end
      if row.nodata then sum.nodata = sum.nodata + 1 end
    end
  end
  table.sort(rows, function(a, b)
    if (a.bad > 0) ~= (b.bad > 0) then return a.bad > 0 end
    if a.bad ~= b.bad then return a.bad > b.bad end
    if (a.nodata and true or false) ~= (b.nodata and true or false) then return a.nodata and true or false end
    if (a.expiring and true or false) ~= (b.expiring and true or false) then return a.expiring and true or false end
    return a.name < b.name
  end)
  return rows, sum
end

---------------------------------------------------------------------------
-- Boss pulls
---------------------------------------------------------------------------
local function OnEncounterStart(id, name)
  if not D.ready or not D.IsAdmin() or not D.InRaid() then return end
  if D.Secret(name) or type(name) ~= "string" then return end
  R.seen[name] = true
  local level = R.BossLevel(name)
  if level == "off" then return end
  pcall(R.ScanRaid) -- fresh where the game lets us, last good reading where it doesn't
  local key = R.BossKey(name)
  R.pullCount[key] = (R.pullCount[key] or 0) + 1
  local rows, sum = R.BuildRows(level)
  local snap = { boss = name, key = key, level = level, pull = R.pullCount[key], t = GetServerTime(),
    night = D.NightKey(), rows = rows, sum = sum }
  table.insert(R.hist, 1, snap)
  while #R.hist > 12 do table.remove(R.hist) end
  R.last = snap
  local slot = R.index[snap.night .. key] or {}
  R.index[snap.night .. key] = slot
  if not slot.first then slot.first = snap end
  if D.RefreshReadyUI then D.RefreshReadyUI() end
end

local function OnEncounterEnd(_, name, _, _, success)
  if success ~= 1 or type(name) ~= "string" or D.Secret(name) then return end
  local key = R.BossKey(name)
  R.pullCount[key] = nil
  local snap = R.last
  if snap and snap.key == key then
    snap.kill = true
    local slot = R.index[snap.night .. key] or {}
    R.index[snap.night .. key] = slot
    slot.kill = snap
  end
  if D.RefreshReadyUI then D.RefreshReadyUI() end
end

---------------------------------------------------------------------------
-- Reminders
---------------------------------------------------------------------------
local function WhisperTarget(name)
  local info = D.raid[name]
  if info and info.unit and UnitExists(info.unit) then
    local n = GetUnitName(info.unit, true)
    if n and not D.Secret(n) then return n end
  end
  return name
end

function R.WhisperText(row, boss, withRunout)
  local parts = {}
  for _, s in ipairs(row.short) do parts[#parts + 1] = s end
  if withRunout then
    for _, s in ipairs(row.runout) do parts[#parts + 1] = s:lower() end
  end
  if #parts == 0 then return nil end
  local msg = ("[Guild Ladder DKP] Before %s you're missing: %s."):format(boss or "the pull", table.concat(parts, ", "))
  if #msg > 250 then msg = msg:sub(1, 246) .. "..." end
  return msg
end

-- who can be reminded, with the text each would get
function R.WhisperList(rows, boss, opts)
  opts = opts or {}
  local list = {}
  for _, row in ipairs(rows) do
    local text = R.WhisperText(row, boss, opts.runout)
    if text and not D.SameName(row.name, D.Me()) then
      local bits = {}
      for _, s in ipairs(row.short) do bits[#bits + 1] = s end
      if opts.runout then for _, s in ipairs(row.runout) do bits[#bits + 1] = s:lower() end end
      list[#list + 1] = { name = row.name, class = row.class, text = text, short = table.concat(bits, ", "), row = row }
    end
  end
  return list
end

-- must be called from a click (chat from add-ons needs a hardware event)
function R.SendWhispers(list)
  local sent = 0
  for _, x in ipairs(list) do
    local last = R.whispered[x.name]
    if not last or GetTime() - last >= WHISPER_GAP then
      D.Chat(x.text, "WHISPER", WhisperTarget(x.name), true)
      R.whispered[x.name] = GetTime()
      sent = sent + 1
    end
  end
  return sent
end

function R.RaidSummary(rows, boss)
  local items = {}
  for _, row in ipairs(rows) do
    if #row.short > 0 then
      items[#items + 1] = (D.FirstName(row.name) or row.name) .. " (" .. table.concat(row.short, ", ") .. ")"
    end
  end
  if #items == 0 then return {} end
  local lines, cur = {}, ("Readiness for %s: "):format(boss or "the pull")
  for i, it in ipairs(items) do
    local piece = it .. (i < #items and "; " or "")
    if #cur + #piece > 240 then
      lines[#lines + 1] = cur
      cur = "... "
    end
    cur = cur .. piece
  end
  lines[#lines + 1] = cur
  return lines
end

function R.PostSummary(rows, boss)
  for _, line in ipairs(R.RaidSummary(rows, boss)) do D.Chat(line, "RAID", nil, true) end
end

---------------------------------------------------------------------------
-- Prepared bonus
---------------------------------------------------------------------------
function R.BonusReason(boss) return "Prepared: " .. D.Clean(boss, 50) end

function R.BonusGiven(boss)
  if not D.db then return false end
  local g, r = D.NightKey(), R.BonusReason(boss)
  for _, e in pairs(D.db.events) do
    if e.k == "AW" and e.g == g and e.r == r and not (D.data and D.data.undone[e.id]) then return true end
  end
  return false
end

-- the pull the bonus is judged on: the one that ended in the kill, or the first
function R.BonusSnapshot(boss)
  local key = R.BossKey(boss)
  local slot = R.index[D.NightKey() .. key]
  if not slot then return nil end
  if D.Cfg("RD_JUDGE") == "first" then return slot.first end
  return slot.kill or (R.last and R.last.key == key and R.last) or nil
end

function R.PostBonus(names, boss)
  local amount = tonumber(D.Cfg("RD_BONUS")) or 0
  if #names == 0 or amount <= 0 then return end
  D.Award(names, amount, R.BonusReason(boss), "CUSTOM")
end

---------------------------------------------------------------------------
-- Events + background scan
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED", "PLAYER_TALENT_UPDATE" }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ENCOUNTER_START" then
    OnEncounterStart(...)
  elseif event == "ENCOUNTER_END" then
    OnEncounterEnd(...)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    R.self = nil
    if D.ready and D.InGroup() then R.QueueReport(6) end
  elseif event == "PLAYER_TALENT_UPDATE" then
    R.self = nil
    if D.ready and D.InGroup() then R.QueueReport(6) end
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if (...) == "player" then
      R.self = nil
      if D.ready and D.InGroup() then R.QueueReport(4) end
    end
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    if D.ready and D.InRaid() then
      if not R.wasRaid then R.wasRaid = true; R.QueueReport() end
    else
      R.wasRaid = false
    end
  end
end)

-- a stone running out sends no event: notice it within 20 s and report
C_Timer.NewTicker(20, function()
  if not D.ready or not D.InGroup() then return end
  local oil = OilState()
  if oil ~= R.lastOil then
    R.lastOil = oil
    R.self = nil
    R.QueueReport(2)
  end
end)

C_Timer.NewTicker(6, function()
  if not D.ready or not D.InRaid() or not D.IsAdmin() then return end
  if UnitAffectingCombat("player") then return end
  pcall(R.ScanRaid)
end)

---------------------------------------------------------------------------
-- /dkp ready ...
---------------------------------------------------------------------------
function R.DebugUnit(unit)
  unit = (unit and unit ~= "") and unit or "target"
  if not UnitExists(unit) then Print("No such unit: " .. unit .. " (target someone first)") return end
  Print("Buffs on " .. tostring(UnitName(unit)) .. " (kind = how Readiness reads it):")
  for i = 1, 40 do
    local name, id, _, exp = AuraAt(unit, i)
    if not name then break end
    if D.Secret(name, id, exp) then Print("  the game is hiding this unit's buffs right now") break end
    local left = (type(exp) == "number" and exp > 0) and math.floor((exp - GetTime()) / 60) or nil
    Print(("  %s  (id %s)%s%s"):format(name, tostring(id), left and ("  " .. left .. "m left") or "",
      Classify(name, id) and ("  <- " .. Classify(name, id)) or ""))
  end
  Print("Wrong or missing? The guild master can fix it: /dkp ready add <id> <flask|elixir|food|scroll|none>")
end

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    if ok and type(info) == "table" and info.name then return info.name end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then return n end
  end
  return nil
end

function R.ReadySlash(rest)
  local a, b = (rest or ""):match("^(%S*)%s*(.-)$")
  a = (a or ""):lower()
  if a == "scan" or a == "buffs" then
    R.DebugUnit(b)
  elseif a == "gear" then
    local g = R.CollectGear()
    Print(("My gear: item level %d, weapon oil %s"):format(g.ilvl, g.oil == nil and "n/a" or (g.oil == 1 and "yes" or "NO")))
    for _, s in ipairs(g.ench) do Print("  no enchant: " .. (SLOT[s] or s)) end
    for _, x in ipairs(g.gems) do Print(("  empty sockets: %s x%d"):format(SLOT[x[1]] or x[1], x[2])) end
    if #g.ench == 0 and #g.gems == 0 then Print("  all enchants and sockets look fine") end
  elseif a == "bosses" then
    local list = {}
    for n in pairs(R.seen) do list[#list + 1] = n end
    table.sort(list)
    Print("Bosses seen this session: " .. (#list > 0 and table.concat(list, ", ") or "none yet"))
  elseif a == "request" then
    R.RequestGear(true)
    Print("Asked the raid to send their gear.")
  elseif a == "add" then
    local id, kind = b:match("^(%d+)%s+(%a+)$")
    kind = kind and kind:lower()
    if not id or not (KINDS[kind] or kind == "none") then
      Print("Usage: /dkp ready add <spell id> <flask|elixir|food|scroll|none>   (find ids with /dkp ready scan)")
    else
      D.SetConfig("RDX:" .. id, kind)
      Print(("Readiness will treat %s (id %s) as: %s."):format(SpellName(tonumber(id)) or "that buff", id, kind))
    end
  elseif a == "remove" then
    local id = b:match("^(%d+)$")
    if not id then
      Print("Usage: /dkp ready remove <spell id>")
    else
      D.SetConfig("RDX:" .. id, "")
      Print("Back to the built-in rule for id " .. id .. ".")
    end
  elseif a == "list" then
    local ids = {}
    for k, v in pairs(D.data and D.data.cfg or {}) do
      local id = type(k) == "string" and k:match("^RDX:(%d+)$")
      if id and v ~= "" then ids[#ids + 1] = { tonumber(id), tostring(v) } end
    end
    table.sort(ids, function(x, y) return x[1] < y[1] end)
    Print(#ids > 0 and "Buffs the guild master taught Readiness:" or "Nothing taught yet (only the built-in buffs).")
    for _, x in ipairs(ids) do Print(("  %d  %s  ->  %s"):format(x[1], SpellName(x[1]) or "?", x[2])) end
  else
    if D.Toggle then D.Toggle("ready") end
  end
end
D.ReadySlash = R.ReadySlash
