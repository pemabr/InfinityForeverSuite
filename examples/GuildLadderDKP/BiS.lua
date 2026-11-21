--[[
  Guild Ladder DKP - BiS upgrade verdicts (v0.6.0), gear plan + Loon-style tooltip (v0.6.1), raid loot (v0.7.0)

  Reads the optional data add-on GuildLadderDKP_BiS_TBC (global
  GuildLadderDKP_BiSData, built from Loon Best In Slot by tools/loon_to_bis.py)
  and tells THIS raider, on their own client, what an item means for them:
  BIS / Alt / not listed for their spec in the guild's BiS phase, compared with
  what they wear right now, plus the item-level difference.

  Nothing here touches the ledger or the sync: no data add-on, no verdict, and
  everything else works exactly as before.

  Phases: 0 = Pre-raid, 1-5 = P1-P5. The guild master picks the phase
  (BIS_PHASE, Settings > Data). Spec comes from talents unless the raider picks
  one (My DKP page, or /dkp bis spec <name>).
]]
local ADDON, D = ...
local B = {}
D.BiS = B

local PHASE_NAME = { [0] = "Pre-raid", "P1", "P2", "P3", "P4", "P5" }
local PHASE_RAIDS = {
  [0] = "Pre-raid", "P1 · Karazhan, Gruul, Magtheridon", "P2 · SSC, Tempest Keep",
  "P3 · Hyjal, Black Temple", "P4 · Zul'Aman", "P5 · Sunwell",
}
B.PHASE_NAME, B.PHASE_RAIDS = PHASE_NAME, PHASE_RAIDS

-- talent tab (most points) -> list name, TBC tab order
local TALENT_SPEC = {
  WARRIOR = { "Arms", "Fury", "Protection" },
  PALADIN = { "Holy", "Protection", "Retribution" },
  HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
  ROGUE   = { "Dps", "Dps", "Dps" },
  PRIEST  = { "Holy", "Holy", "Shadow" },        -- no Discipline list: Disc starts on Holy
  SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
  MAGE    = { "Arcane", "Fire", "Frost" },
  WARLOCK = { "Affliction", "Demonology", "Destruction" },
  DRUID   = { "Balance", "Cat", "Restoration" }, -- Feral starts on Cat; bears pick Bear
}
local SPEC_LABEL = { Dps = "DPS" }
function B.SpecLabel(spec) return spec and (SPEC_LABEL[spec] or spec) or "?" end

local RANK = { BIS = 3, Alt = 2 } -- off the list = 1, empty slot = 0
local SLOT_EQUIP = { head = "INVTYPE_HEAD", neck = "INVTYPE_NECK", shoulder = "INVTYPE_SHOULDER", back = "INVTYPE_CLOAK",
  chest = "INVTYPE_CHEST", wrist = "INVTYPE_WRIST", hands = "INVTYPE_HAND", waist = "INVTYPE_WAIST", legs = "INVTYPE_LEGS",
  feet = "INVTYPE_FEET", ring = "INVTYPE_FINGER", trinket = "INVTYPE_TRINKET", mh = "INVTYPE_WEAPONMAINHAND",
  oh = "INVTYPE_WEAPONOFFHAND", ["2h"] = "INVTYPE_2HWEAPON", ["1h"] = "INVTYPE_WEAPON", ranged = "INVTYPE_RANGED" }

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
function B.Data()
  local d = _G.GuildLadderDKP_BiSData
  if type(d) ~= "table" or type(d.lists) ~= "table" then return nil, "nodata" end
  -- TBC lists mean nothing in a pre-TBC game (WoW Forever at 60)
  if d.era == "TBC" and GetExpansionLevel then
    local ok, lvl = pcall(GetExpansionLevel)
    if ok and lvl == 0 then return nil, "era" end
  end
  return d
end

local cache = {}
-- One spec's list for one phase: { items = { [id] = entry }, slots = { [slot] = { entry, ... } }, order = { slot, ... } }
-- entry = { id, tier = "BIS"|"Alt", slot, note }
function B.List(class, spec, phase)
  local d = B.Data()
  if not d or not class or not spec or not phase then return nil end
  local key = class .. "|" .. spec .. "|" .. phase
  local c = cache[key]
  if c ~= nil then return c or nil end
  local raw = d.lists[class] and d.lists[class][spec] and d.lists[class][spec][phase]
  if type(raw) ~= "string" then cache[key] = false return nil end
  local list = { items = {}, slots = {}, order = {} }
  for chunk in raw:gmatch("[^;]+") do
    local slot, ids = chunk:match("^([^=]+)=(.*)$")
    if slot then
      if not list.slots[slot] then list.slots[slot] = {}; list.order[#list.order + 1] = slot end
      for tok in ids:gmatch("[^,]+") do
        local t, id, note = tok:match("^([ab])(%d+)%.?(.*)$")
        id = tonumber(id)
        if id then
          local e = { id = id, tier = (t == "b") and "BIS" or "Alt", slot = slot, note = (note ~= "" and note) or nil }
          local old = list.items[id]
          -- same item listed for two slots (a 1-hander as main and off hand): keep the better tier
          if not old or RANK[e.tier] > RANK[old.tier] then list.items[id] = e end
          table.insert(list.slots[slot], e)
        end
      end
    end
  end
  cache[key] = list
  return list
end

-- specs with a list for a class, in a stable order
function B.Specs(class)
  local d = B.Data()
  local t = {}
  if d and d.lists[class] then
    for spec in pairs(d.lists[class]) do t[#t + 1] = spec end
    table.sort(t)
  end
  return t
end

---------------------------------------------------------------------------
-- Who am I, which phase
---------------------------------------------------------------------------
local function TalentTab()
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

local function Store()
  GuildLadderDKPDB = GuildLadderDKPDB or {}
  GuildLadderDKPDB.bisSpec = GuildLadderDKPDB.bisSpec or {}
  return GuildLadderDKPDB.bisSpec
end

function B.MyClass() return select(2, UnitClass("player")) end

function B.AutoSpec(class)
  local map = TALENT_SPEC[class or ""]
  local tab = TalentTab()
  local spec = map and tab and map[tab]
  local d = B.Data()
  if spec and d and d.lists[class] and d.lists[class][spec] then return spec end
  return nil
end

-- class, spec, isAuto. spec is nil when nothing fits (no talents yet, no list)
function B.MySpec()
  local class = B.MyClass()
  local d = B.Data()
  local manual = Store()[D.Me()]
  if manual and d and d.lists[class] and d.lists[class][manual] then return class, manual, false end
  return class, B.AutoSpec(class), true
end

-- nil = back to automatic
function B.SetSpec(spec)
  Store()[D.Me()] = spec
  if D.Refresh then D.Refresh() end
end

function B.Phase()
  local p = math.floor(tonumber(D.Cfg("BIS_PHASE")) or 3)
  return math.max(0, math.min(5, p))
end

---------------------------------------------------------------------------
-- The verdict
-- opts.ilvl / opts.equipLoc: pass them when my item cache may be empty (the
-- auctioneer sends them with the auction). opts.phase: judge against another
-- phase's list than the guild's (the gear plan and raid loot look-ahead).
-- Returns v = { class, spec, phase, id, tier, note, slot, later, earlier,
--   vs = { slot, id, name, ilvl, tier, rank } (the equipped item it would replace),
--   kind = "upgrade" | "same" | "down" | "have" | nil, delta = ilvl difference }
-- or nil, reason ("nodata", "era", "nospec", "nolist", "noitem").
---------------------------------------------------------------------------
function B.Verdict(itemID, opts)
  itemID = tonumber(itemID)
  if not itemID then return nil, "noitem" end
  local d, why = B.Data()
  if not d then return nil, why end
  local class, spec = B.MySpec()
  if not spec then return nil, "nospec" end
  local phase = math.max(0, math.min(5, math.floor(tonumber(opts and opts.phase) or B.Phase())))
  local list = B.List(class, spec, phase)
  if not list then return nil, "nolist" end
  -- a tier token: judge the piece it makes for my class (the best one for my spec)
  local ti = B.TokenInfo(itemID)
  if ti then
    local mine = ti.byClass[class]
    if not mine then return { class = class, spec = spec, phase = phase, id = itemID, token = itemID, notMyClass = true } end
    local best, bestScore
    for _, pc in ipairs(mine) do
      local pv = B.Verdict(pc.id, { phase = phase })
      if pv then
        local score = (pv.tier and RANK[pv.tier] or 1) * 10 + (pv.kind == "upgrade" and 3 or (pv.kind == "same" and 1 or 0))
        if not bestScore or score > bestScore then best, bestScore = pv, score; pv.pieceName = pc.name end
      end
    end
    if not best then return nil, "nolist" end
    best.token, best.piece = itemID, best.id
    return best
  end
  local v = { class = class, spec = spec, phase = phase, id = itemID }
  local e = list.items[itemID]
  if e then v.tier, v.note, v.slot = e.tier, e.note, e.slot end
  for p = phase + 1, 5 do
    local l = B.List(class, spec, p)
    local x = l and l.items[itemID]
    if x then v.later = { phase = p, tier = x.tier } break end
  end
  if not e then
    for p = phase - 1, 0, -1 do
      local l = B.List(class, spec, p)
      local x = l and l.items[itemID]
      if x then v.earlier = { phase = p, tier = x.tier } break end
    end
  end

  -- what would it replace?
  opts = opts or {}
  local ilvl, equipLoc = tonumber(opts.ilvl), opts.equipLoc
  if (not equipLoc or equipLoc == "") and D.GetItemInfoInstant then
    local ok, _, _, _, loc = pcall(D.GetItemInfoInstant, itemID)
    if ok then equipLoc = loc end
  end
  if not ilvl and D.GetItemInfo then
    local ok, _, _, _, il = pcall(D.GetItemInfo, itemID)
    if ok then ilvl = tonumber(il) end
  end
  -- the game couldn't tell me the slot (item never seen)? the BiS list knows it
  if (not equipLoc or equipLoc == "") and e then equipLoc = SLOT_EQUIP[e.slot] end
  local slots = equipLoc and D.EQUIP_SLOTS and D.EQUIP_SLOTS[equipLoc]
  if slots and GetInventoryItemID then
    local worst
    for _, s in ipairs(slots) do
      local id = GetInventoryItemID("player", s)
      local cur = { slot = s, id = id, rank = 0, ilvl = 0 }
      if id then
        if id == itemID then v.have = true end
        local x = list.items[id]
        cur.tier = x and x.tier or nil
        cur.rank = x and RANK[x.tier] or 1
        local ok, name, _, _, il = pcall(D.GetItemInfo, id)
        if ok then cur.name, cur.ilvl = name, tonumber(il) end
      end
      if not worst or cur.rank < worst.rank or (cur.rank == worst.rank and (cur.ilvl or 0) < (worst.ilvl or 0)) then
        worst = cur
      end
    end
    v.vs = worst
  end
  local mine = e and RANK[e.tier] or 1
  if v.have then
    v.kind = "have"
  elseif v.vs then
    if mine > v.vs.rank then v.kind = "upgrade" elseif mine == v.vs.rank then v.kind = "same" else v.kind = "down" end
    if ilvl and v.vs.id and v.vs.ilvl then v.delta = ilvl - v.vs.ilvl end
  end
  return v
end

local function Delta(v)
  if not v.delta or v.delta == 0 then return "" end
  return (v.delta > 0 and " +" or " ") .. v.delta .. " ilvl"
end

-- short text for the bid popup chip, and a style: "bis" | "alt" | "soft" | "muted"
function B.Chip(v)
  local P = PHASE_NAME[v.phase] or "?"
  if v.notMyClass then return "Token · none on your lists", "muted" end
  local T = v.token and "token " or "" -- a tier token that makes my piece
  if v.tier then
    local base = v.tier .. " " .. P
    local style = v.tier == "BIS" and "bis" or "alt"
    if v.kind == "have" then return base .. " · you have the " .. (v.token and "piece" or "item"), "muted" end
    if v.kind == "upgrade" then return base .. " · " .. T .. "upgrade" .. Delta(v), style end
    if v.kind == "same" then return base .. " · " .. T .. "same tier as yours" .. Delta(v), "soft" end
    if v.kind == "down" then return base .. " · you wear better", "muted" end
    return base, style -- nothing to compare with
  end
  if v.later then return ("Future %s %s"):format(v.later.tier, PHASE_NAME[v.later.phase] or "?"), "soft" end
  return ("Not on %s %s list"):format(B.SpecLabel(v.spec), P), "muted"
end

---------------------------------------------------------------------------
-- Tooltip lines, Loon-style colours (v0.6.1)
-- Each line: { left, right = <text or nil>, base = "text" | "muted" | "good" | "blue" | "gold" }
-- left / right carry their own colour codes; base is the colour of anything
-- outside them. Nothing at all for items on no list.
---------------------------------------------------------------------------
local HEX = { BIS = "ffff8000", Alt = "ff4fd1c5", muted = "ffa7afba", good = "ff8fe08f", blue = "ff7fb2ff", gold = "ffe0b04f" }
local CLASS_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local function C(hex, text) return "|c" .. hex .. text .. "|r" end
local function ClassHex(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return "ffffffff" end
  return c.colorStr or ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end
local function ClassIcon(class)
  local t = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if not t then return "" end
  return ("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:14:14:0:0:256:256:%d:%d:%d:%d|t "):format(
    t[1] * 256, t[2] * 256, t[3] * 256, t[4] * 256)
end
local function TierText(tier, note)
  return C(HEX[tier] or HEX.muted, tier .. (note and (" (" .. note .. ")") or ""))
end
B.ClassHex, B.ClassIcon, B.TierText, B.HEX = ClassHex, ClassIcon, TierText, HEX

local function Worn(vs)
  local name = vs.name or ("item " .. tostring(vs.id))
  return vs.tier and (("%s (%s)"):format(name, TierText(vs.tier))) or name
end

-- who else lists an item in a phase: { { class, tier, specs = { ... } }, ... }, BIS rows first
local best = {}
function B.BestFor(itemID, phase)
  itemID = tonumber(itemID)
  local d = B.Data()
  if not d or not itemID then return {} end
  phase = phase or B.Phase()
  local idx = best[phase]
  if not idx then
    idx = {}
    for class, specs in pairs(d.lists) do
      for spec in pairs(specs) do
        local l = B.List(class, spec, phase)
        if l then
          for id, e in pairs(l.items) do
            idx[id] = idx[id] or {}
            table.insert(idx[id], { class = class, spec = spec, tier = e.tier })
          end
        end
      end
    end
    best[phase] = idx
  end
  local rows, byKey, seenSpec = {}, {}, {}
  local ids = { itemID }
  local ti = B.TokenInfo(itemID) -- a token is wanted by whoever lists any piece it makes
  if ti then ids = {}; for _, pc in ipairs(ti.pieces) do ids[#ids + 1] = pc.id end end
  for _, id in ipairs(ids) do
    for _, x in ipairs(idx[id] or {}) do
      local key = x.class .. "|" .. x.tier
      local r = byKey[key]
      if not r then r = { class = x.class, tier = x.tier, specs = {} }; byKey[key] = r; rows[#rows + 1] = r end
      if not seenSpec[key .. "|" .. x.spec] then
        seenSpec[key .. "|" .. x.spec] = true
        r.specs[#r.specs + 1] = x.spec
      end
    end
  end
  local order = {}
  for i, c in ipairs(CLASS_ORDER) do order[c] = i end
  for _, r in ipairs(rows) do table.sort(r.specs) end
  table.sort(rows, function(a, b)
    if a.tier ~= b.tier then return RANK[a.tier] > RANK[b.tier] end
    return (order[a.class] or 99) < (order[b.class] or 99)
  end)
  return rows
end

function B.TooltipLines(itemID)
  local out = {}
  if D.settings and D.settings.bisTooltip == false then return out end
  local d = B.Data()
  if not d then return out end
  local v = B.Verdict(itemID)
  local phase = B.Phase()
  local P = PHASE_NAME[phase] or "?"
  if v then
    local who = C(ClassHex(v.class), B.SpecLabel(v.spec))
    if v.tier then
      out[#out + 1] = { who .. " " .. C(HEX.muted, P), right = TierText(v.tier, v.note), base = "text" }
      if v.kind == "have" then
        out[#out + 1] = { "  You have it", base = "muted" }
      elseif v.kind == "upgrade" and v.vs and v.vs.id then
        out[#out + 1] = { "  Upgrade over " .. Worn(v.vs) .. (v.delta and v.delta ~= 0 and (" · " .. (v.delta > 0 and "+" or "") .. v.delta .. " ilvl") or ""), base = "good" }
      elseif v.kind == "upgrade" then
        out[#out + 1] = { "  Upgrade · your slot is empty", base = "good" }
      elseif v.kind == "same" then
        out[#out + 1] = { "  Same tier as your " .. Worn(v.vs) .. (v.delta and v.delta ~= 0 and (" · " .. (v.delta > 0 and "+" or "") .. v.delta .. " ilvl") or ""), base = "blue" }
      elseif v.kind == "down" then
        out[#out + 1] = { "  You wear better: " .. Worn(v.vs), base = "muted" }
      end
    end
    if v.later then
      out[#out + 1] = { who .. " " .. C(HEX.muted, PHASE_NAME[v.later.phase] .. " · later phase"), right = TierText(v.later.tier), base = "text" }
    elseif v.earlier and not v.tier then
      out[#out + 1] = { who .. " " .. C(HEX.muted, PHASE_NAME[v.earlier.phase] .. " · earlier phase"), right = TierText(v.earlier.tier), base = "muted" }
    end
  end
  -- a tier token: which pieces it turns into (mine first, with my spec's tier)
  local ti = B.TokenInfo(itemID)
  if ti then
    local myClass, mySpec = B.MySpec()
    local mine = mySpec and B.List(myClass, mySpec, phase)
    out[#out + 1] = { C(HEX.gold, "Token for:"), base = "text" }
    local others = {}
    for _, cls in ipairs(CLASS_ORDER) do
      local ps = ti.byClass[cls]
      if ps then
        if cls == myClass then
          for _, pc in ipairs(ps) do
            local e = mine and mine.items[pc.id]
            out[#out + 1] = { "  " .. ClassIcon(cls) .. C(ClassHex(cls), pc.name), right = e and TierText(e.tier, e.note) or nil, base = "text" }
          end
        else
          others[#others + 1] = C(ClassHex(cls), CLASS_NAME[cls] or cls)
        end
      end
    end
    if #others > 0 then
      out[#out + 1] = { "  " .. (#(ti.byClass[myClass] or {}) > 0 and (C(HEX.muted, "Also: ")) or "") .. table.concat(others, C(HEX.muted, ", ")), base = "text" }
    end
  end
  -- Best for: everyone else this phase (like Loon's "Best for")
  if not (D.settings and D.settings.bisBestFor == false) then
    local myClass, mySpec = B.MySpec()
    local rows = {}
    for _, r in ipairs(B.BestFor(itemID, phase)) do
      local specs = {}
      for _, sp in ipairs(r.specs) do
        if not (r.class == myClass and sp == mySpec) then specs[#specs + 1] = B.SpecLabel(sp) end
      end
      if #specs > 0 then rows[#rows + 1] = { class = r.class, tier = r.tier, specs = specs } end
    end
    if #rows > 0 then
      out[#out + 1] = { C(HEX.gold, "Best for (" .. P .. "):"), base = "text" }
      local MAX = 6
      for i = 1, math.min(MAX, #rows) do
        local r = rows[i]
        out[#out + 1] = { "  " .. ClassIcon(r.class) .. C(ClassHex(r.class), (CLASS_NAME[r.class] or r.class) .. " " .. table.concat(r.specs, ", ")),
          right = TierText(r.tier), base = "text" }
      end
      if #rows > MAX then out[#out + 1] = { ("  +%d more"):format(#rows - MAX), base = "muted" } end
    end
  end
  -- where it drops (raid items): "Black Temple - Illidan Stormrage"
  local sx = B.SourceOf(itemID)
  if sx then
    local tail = ""
    if sx.kind == "t" then
      local tk = B.TokenOf(itemID)
      tail = C(HEX.muted, "  (drops as " .. (tk and tk.name or "a tier token") .. ")")
    elseif sx.kind == "k" then
      tail = C(HEX.muted, "  (tier token)")
    end
    out[#out + 1] = { C(HEX.blue, sx.zone .. " - " .. B.BossLabel(sx.boss)) .. tail, base = "text" }
  end
  return out
end

---------------------------------------------------------------------------
-- Gear plan (v0.6.1): one row per slot group - what I wear, its tier, and the
-- BIS / Alt targets from my list for a phase. Read-only; the window does the
-- wishing.
---------------------------------------------------------------------------
B.GROUPS = {
  { "head", "Head", { 1 }, { "head" } },
  { "neck", "Neck", { 2 }, { "neck" } },
  { "shoulder", "Shoulder", { 3 }, { "shoulder" } },
  { "back", "Back", { 15 }, { "back" } },
  { "chest", "Chest", { 5 }, { "chest" } },
  { "wrist", "Wrist", { 9 }, { "wrist" } },
  { "hands", "Hands", { 10 }, { "hands" } },
  { "waist", "Waist", { 6 }, { "waist" } },
  { "legs", "Legs", { 7 }, { "legs" } },
  { "feet", "Feet", { 8 }, { "feet" } },
  { "ring", "Rings", { 11, 12 }, { "ring" } },
  { "trinket", "Trinkets", { 13, 14 }, { "trinket" } },
  { "mh", "Main hand", { 16 }, { "mh", "2h", "1h" } },
  { "oh", "Off hand", { 17 }, { "oh", "1h" } },
  { "ranged", "Ranged / relic", { 18 }, { "ranged" } },
}

-- rows = { { key, label, worn = { { slot, id, tier } }, targets = { entry, ... } } }, summary
-- summary = { bis = slots worn at BIS, total = equipment slots counted }
function B.Plan(phase, withAlts)
  local d, why = B.Data()
  if not d then return nil, why end
  local class, spec = B.MySpec()
  if not spec then return nil, "nospec" end
  phase = phase or B.Phase()
  local list = B.List(class, spec, phase)
  if not list then return nil, "nolist" end
  local rows, atBis, total = {}, 0, 0
  for _, g in ipairs(B.GROUPS) do
    local row = { key = g[1], label = g[2], worn = {}, targets = {} }
    local wornSet = {}
    for _, s in ipairs(g[3]) do
      local id = GetInventoryItemID and GetInventoryItemID("player", s)
      local x = id and list.items[id]
      row.worn[#row.worn + 1] = { slot = s, id = id, tier = x and x.tier or nil }
      if id then wornSet[id] = true end
      total = total + 1
      if x and x.tier == "BIS" then atBis = atBis + 1 end
    end
    local seen = {}
    for _, tier in ipairs(withAlts == false and { "BIS" } or { "BIS", "Alt" }) do
      for _, ls in ipairs(g[4]) do
        for _, e in ipairs(list.slots[ls] or {}) do
          local entry = list.items[e.id]
          if entry.tier == tier and not seen[e.id] and not wornSet[e.id] then
            seen[e.id] = true
            row.targets[#row.targets + 1] = entry
          end
        end
      end
    end
    rows[#rows + 1] = row
  end
  return rows, { bis = atBis, total = total, class = class, spec = spec, phase = phase }
end


---------------------------------------------------------------------------
-- Raid loot (v0.7.0): BiSSources_TBC.lua says which boss drops which item.
-- B.RaidLoot(zone) = the items from that raid that are upgrades for ME (on my
-- spec's list for the phase, better than what I wear), per boss.
---------------------------------------------------------------------------
-- progression order; second value = the phase the raid belongs to
B.RAIDS = {
  { "Karazhan", 1 }, { "Gruul's Lair", 1 }, { "Magtheridon's Lair", 1 },
  { "Serpentshrine Cavern", 2 }, { "Tempest Keep", 2 },
  { "Hyjal Summit", 3 }, { "Black Temple", 3 }, { "Zul'Aman", 4 }, { "Sunwell Plateau", 5 },
}
local ZONE_ALIAS = {
  ["mount hyjal"] = "Hyjal Summit", ["the battle for mount hyjal"] = "Hyjal Summit", ["the eye"] = "Tempest Keep",
  ["tempest keep: the eye"] = "Tempest Keep", ["serpentshrine"] = "Serpentshrine Cavern", ["sunwell"] = "Sunwell Plateau",
  ["black temple"] = "Black Temple", ["karazhan"] = "Karazhan", ["zulaman"] = "Zul'Aman", ["gruul"] = "Gruul's Lair",
  ["magtheridon"] = "Magtheridon's Lair",
}
local function Norm(s)
  s = tostring(s or ""):lower()
  s = s:gsub("\226\128\152", "'"):gsub("\226\128\153", "'"):gsub("`", "'") -- typographic apostrophes
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function B.Sources()
  local s = _G.GuildLadderDKP_BiSSources
  if type(s) == "table" and type(s.zones) == "table" then return s end
  return nil
end

---------------------------------------------------------------------------
-- Tier tokens (v0.7.2). The boss drops (and the auction is for) the TOKEN;
-- the BiS lists, wishlists and tooltips name the tier PIECE. BiSSources_TBC.lua
-- carries token -> pieces (with class and name) so the two can be tied together.
---------------------------------------------------------------------------
local tokenInfo, pieceToken
local function BuildTokens()
  if tokenInfo then return end
  tokenInfo, pieceToken = {}, {}
  local src = B.Sources()
  local raw = src and src.tokens
  if type(raw) ~= "table" then return end
  for tid, row in pairs(raw) do
    local info = { id = tid, name = row[1], pieces = {}, byClass = {} }
    for i = 2, #row do
      local cls, id, name = tostring(row[i]):match("^([%u%?]+):(%d+):(.*)$")
      id = tonumber(id)
      if id then
        local pc = { id = id, class = cls, name = name }
        info.pieces[#info.pieces + 1] = pc
        info.byClass[cls] = info.byClass[cls] or {}
        table.insert(info.byClass[cls], pc)
        pieceToken[id] = pieceToken[id] or tid
      end
    end
    tokenInfo[tid] = info
  end
end

-- the token record when `id` IS a token: { id, name, pieces = { {id, class, name} }, byClass = { CLASS = { piece, ... } } }
function B.TokenInfo(id) BuildTokens(); return tokenInfo[tonumber(id) or 0] end
-- the token record a tier PIECE is made from, or nil
function B.TokenOf(pieceID) BuildTokens(); local t = pieceToken[tonumber(pieceID) or 0]; return t and tokenInfo[t] or nil end
-- ids of the pieces a token makes for `class` (default: mine); {} when `id` is not a token
function B.PiecesOf(tokenID, class)
  local ti = B.TokenInfo(tokenID)
  local out = {}
  if ti then for _, pc in ipairs(ti.byClass[class or B.MyClass()] or {}) do out[#out + 1] = pc.id end end
  return out
end

-- canonical zone name for an instance / raid name, or nil
function B.ZoneFor(name)
  local src = B.Sources()
  if not src or not name or name == "" then return nil end
  local n = Norm(name)
  for zone in pairs(src.zones) do if Norm(zone) == n then return zone end end
  local a = ZONE_ALIAS[n]
  if a and src.zones[a] then return a end
  return nil
end

-- the raid instance I'm standing in (a name B.ZoneFor knows), or nil
function B.CurrentRaidZone()
  if not IsInInstance then return nil end
  local inInst, kind = IsInInstance()
  if not inInst or kind ~= "raid" then return nil end
  local name = GetInstanceInfo and select(1, GetInstanceInfo())
  local zone = B.ZoneFor(name)
  if not zone and D.Rd and D.Rd.CurrentRaid then
    local _, rd = D.Rd.CurrentRaid()
    if rd then zone = B.ZoneFor(rd.inst or rd.name) or B.ZoneFor(rd.name) end
  end
  return zone
end

-- default raid for the guild's phase: the last raid of that phase
function B.DefaultRaid()
  local gp = B.Phase()
  local pick
  for _, r in ipairs(B.RAIDS) do if r[2] <= gp then pick = r[1] end end
  return pick or B.RAIDS[1][1]
end

local PSEUDO = { ["trash drop"] = "Trash", ["various bosses"] = "Various bosses", ["timed event"] = "Timed event" }
function B.BossLabel(boss) return PSEUDO[Norm(boss)] or boss end

local zoneCache = {}
-- zone -> { order = { { key = boss, label = display }, ... }, bosses = { [boss] = { { kind, id }, ... } } }
local function ZoneBosses(zone)
  if zoneCache[zone] then return zoneCache[zone] end
  local src = B.Sources()
  local raw = src and src.zones[zone]
  if not raw then return nil end
  local z = { order = {}, bosses = {} }
  local known = {}
  if D.Rd and D.Rd.RAIDS then
    for _, rd in ipairs(D.Rd.RAIDS) do
      if B.ZoneFor(rd.inst or rd.name) == zone or B.ZoneFor(rd.name) == zone then
        for i, b in ipairs(rd.bosses) do known[Norm(b)] = i end
      end
    end
  end
  for boss, ids in pairs(raw) do
    local list = {}
    for tok in ids:gmatch("[^,]+") do
      local k, id = tok:match("^(%a)(%d+)$")
      if k then list[#list + 1] = { kind = k, id = tonumber(id) } end
    end
    z.bosses[boss] = list
    z.order[#z.order + 1] = { key = boss, label = B.BossLabel(boss) }
  end
  -- known bosses in kill order, then events / odds and ends, trash last
  local function Rank(e)
    local n = Norm(e.key)
    if known[n] then return 1, known[n] end
    if n == "trash drop" or n == "various bosses" then return 3, 0 end
    return 2, 0
  end
  table.sort(z.order, function(a, b)
    local ra, ia = Rank(a); local rb, ib = Rank(b)
    if ra ~= rb then return ra < rb end
    if ia ~= ib then return ia < ib end
    return a.key < b.key
  end)
  zoneCache[zone] = z
  return z
end

local srcIndex
-- { zone, boss, kind } for an item that drops in a raid, or nil
function B.SourceOf(itemID)
  local src = B.Sources()
  if not src then return nil end
  if not srcIndex then
    srcIndex = {}
    for _, r in ipairs(B.RAIDS) do
      local z = ZoneBosses(r[1])
      if z then
        for _, e in ipairs(z.order) do
          for _, it in ipairs(z.bosses[e.key]) do
            if not srcIndex[it.id] then srcIndex[it.id] = { zone = r[1], boss = e.key, kind = it.kind } end
          end
        end
      end
    end
  end
  return srcIndex[tonumber(itemID)]
end

-- opts.phase (default: the guild's), opts.bisOnly, opts.all (also items that are no upgrade)
-- returns bosses = { { key, label, items = { { id, tier, note, slot, kind, srcKind, delta, vs } } } } (only bosses with items),
-- summary = { zone, phase, class, spec, upgrades, bis, bosses }   or nil, reason
function B.RaidLoot(zone, opts)
  opts = opts or {}
  local d, why = B.Data()
  if not d then return nil, why end
  if not B.Sources() then return nil, "nosources" end
  local class, spec = B.MySpec()
  if not spec then return nil, "nospec" end
  zone = B.ZoneFor(zone)
  local z = zone and ZoneBosses(zone)
  if not z then return nil, "nozone" end
  local phase = math.max(0, math.min(5, math.floor(tonumber(opts.phase) or B.Phase())))
  local list = B.List(class, spec, phase)
  if not list then return nil, "nolist" end
  local out, upgrades, bis = {}, 0, 0
  for _, e in ipairs(z.order) do
    local items, seen = {}, {}
    for _, s in ipairs(z.bosses[e.key]) do
      local entry = list.items[s.id]
      if entry and not seen[s.id] and not (opts.bisOnly and entry.tier ~= "BIS") then
        local v = B.Verdict(s.id, { phase = phase })
        if v and (opts.all or v.kind == "upgrade") then
          seen[s.id] = true
          items[#items + 1] = { id = s.id, tier = entry.tier, note = entry.note, slot = entry.slot, kind = v.kind, srcKind = s.kind,
            delta = v.delta, vs = v.vs }
        end
      end
    end
    if #items > 0 then
      table.sort(items, function(a, b)
        if a.tier ~= b.tier then return RANK[a.tier] > RANK[b.tier] end
        return a.id < b.id
      end)
      for _, it in ipairs(items) do
        if it.kind == "upgrade" then upgrades = upgrades + 1; if it.tier == "BIS" then bis = bis + 1 end end
      end
      out[#out + 1] = { key = e.key, label = e.label, items = items }
    end
  end
  return out, { zone = zone, phase = phase, class = class, spec = spec, upgrades = upgrades, bis = bis, bosses = #out }
end


---------------------------------------------------------------------------
-- Gems and enchants (v1.3.0). Loon lists BiS gems (item ids) and enchants (spell ids) per spec and phase; the lists add
-- up (a phase includes the earlier ones). A worn item's link only carries Blizzard's own enchant number, which can't be
-- matched to a spell id from here, so the check says whether a slot IS enchanted and the list says WHAT is best. Gems are
-- socketed by item id, so those are compared exactly.
---------------------------------------------------------------------------
local function InfoRow(tbl, id)
  local s = B.Sources()
  local t = s and s[tbl]
  local r = t and t[tonumber(id) or 0]
  if r then return { name = r[1], source = r[2], location = r[3] } end
end
function B.EnchantInfo(id) return InfoRow("enchantInfo", id) end
function B.GemInfo(id) return InfoRow("gemInfo", id) end

local gemCache, enchCache = {}, {}

-- BiS gems up to a phase: { { id, meta, phase }, ... }, meta gems first then the newest phase first
function B.Gems(class, spec, phase)
  local d = B.Data()
  local raw = d and d.gems and d.gems[class] and d.gems[class][spec]
  if not raw then return {} end
  phase = math.max(0, math.min(5, math.floor(tonumber(phase) or B.Phase())))
  local key = class .. "|" .. spec .. "|" .. phase
  if gemCache[key] then return gemCache[key] end
  local out, seen = {}, {}
  for ph = phase, 0, -1 do
    local s = raw[ph]
    if type(s) == "string" then
      for tok in s:gmatch("[^,]+") do
        local id, m = tok:match("^(%d+)(m?)$")
        id = tonumber(id)
        if id and not seen[id] then
          seen[id] = true
          out[#out + 1] = { id = id, meta = (m == "m"), phase = ph }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.meta ~= b.meta then return a.meta end
    if a.phase ~= b.phase then return a.phase > b.phase end
    return a.id < b.id
  end)
  gemCache[key] = out
  return out
end

-- set of BiS gem ids up to a phase
function B.GemSet(class, spec, phase)
  local set = {}
  for _, g in ipairs(B.Gems(class, spec, phase)) do set[g.id] = g end
  return set
end

-- BiS enchants up to a phase: { [slot] = { { id, phase, top }, ... } } newest first; slot = head shoulder back chest wrist
-- hands legs feet ring mh oh ranged ("any hand" weapon enchants count for both hands, armor kits for shoulder and legs)
function B.Enchants(class, spec, phase)
  local d = B.Data()
  local raw = d and d.enchants and d.enchants[class] and d.enchants[class][spec]
  if not raw then return {} end
  phase = math.max(0, math.min(5, math.floor(tonumber(phase) or B.Phase())))
  local key = class .. "|" .. spec .. "|" .. phase
  if enchCache[key] then return enchCache[key] end
  local out, seen = {}, {}
  local ALSO = { ["1h"] = { "mh", "oh" }, ["shoulder~legs"] = { "shoulder", "legs" } }
  for ph = phase, 0, -1 do
    local s = raw[ph]
    if type(s) == "string" then
      for chunk in s:gmatch("[^;]+") do
        local slot, ids = chunk:match("^([^=]+)=(.*)$")
        if slot then
          for _, target in ipairs(ALSO[slot] or { slot }) do
            for tok in ids:gmatch("[^,]+") do
              local id = tonumber(tok)
              local k = target .. ":" .. tostring(id)
              if id and not seen[k] then
                seen[k] = true
                out[target] = out[target] or {}
                table.insert(out[target], { id = id, phase = ph })
              end
            end
          end
        end
      end
    end
  end
  for _, list in pairs(out) do
    local top = list[1].phase
    for _, e in ipairs(list) do e.top = (e.phase == top) end
  end
  enchCache[key] = out
  return out
end

-- the rows of the Enchants & Gems window: key, label, inventory slot, enchant list key
B.GEARROWS = {
  { "head", "Head", 1, "head" }, { "neck", "Neck", 2 }, { "shoulder", "Shoulder", 3, "shoulder" },
  { "back", "Back", 15, "back" }, { "chest", "Chest", 5, "chest" }, { "wrist", "Wrist", 9, "wrist" },
  { "hands", "Hands", 10, "hands" }, { "waist", "Waist", 6 }, { "legs", "Legs", 7, "legs" }, { "feet", "Feet", 8, "feet" },
  { "ring1", "Ring", 11, "ring" }, { "ring2", "Ring", 12, "ring" }, { "mh", "Main hand", 16, "mh" },
  { "oh", "Off hand", 17, "oh" }, { "ranged", "Ranged", 18, "ranged" },
}

---------------------------------------------------------------------------
-- v1.4.0: gem colours, which sockets a gem fits, and what an item's sockets look like (for the Gems window)
---------------------------------------------------------------------------
local GEM_SUB = { [0] = "red", [1] = "blue", [2] = "yellow", [3] = "purple", [4] = "green", [5] = "orange",
  [6] = "meta", [7] = "simple", [8] = "prismatic" }
local colorCache = {}
-- the gem's colour from the game's item data (no server round trip); nil if the game doesn't say
function B.GemColor(id)
  id = tonumber(id)
  if not id then return nil end
  if colorCache[id] ~= nil then return colorCache[id] or nil end
  local col
  if D.GetItemInfoInstant then
    local ok, _, _, _, _, _, classID, subID = pcall(D.GetItemInfoInstant, id)
    if ok and classID == 3 then col = GEM_SUB[subID] end
    colorCache[id] = col or false
  end
  return col
end

-- socket colour -> gem colours that fit it (1 = the pure colour, 2 = a hybrid, 3 = prismatic)
B.SOCKETS = { "meta", "red", "yellow", "blue" }
local FITS = {
  meta = { meta = 1 },
  red = { red = 1, orange = 2, purple = 2, prismatic = 3 },
  yellow = { yellow = 1, orange = 2, green = 2, prismatic = 3 },
  blue = { blue = 1, purple = 2, green = 2, prismatic = 3 },
}
B.SOCKET_FITS = FITS
function B.GemFits(id, socket, meta)
  local c = meta and "meta" or B.GemColor(id)
  return c and FITS[socket] and FITS[socket][c] or nil
end

-- the phase's BiS gems grouped by the socket they fit: { { socket = "meta", gems = { { id, meta, phase }, ... } }, ... }
-- A pure colour comes before a hybrid, then the list's own order. A hybrid shows under both its colours. Gems whose
-- colour the game didn't report land in a last "other" group so nothing on the list is hidden.
function B.GemsBySocket(class, spec, phase)
  local list = B.Gems(class, spec, phase)
  local out, placed = {}, {}
  for _, s in ipairs(B.SOCKETS) do
    local grp = { socket = s, gems = {} }
    for i, g in ipairs(list) do
      local rank = B.GemFits(g.id, s, g.meta)
      if rank then
        grp.gems[#grp.gems + 1] = { id = g.id, meta = g.meta, phase = g.phase, rank = rank, order = i }
        placed[g.id] = true
      end
    end
    table.sort(grp.gems, function(a, b)
      if a.rank ~= b.rank then return a.rank < b.rank end
      return a.order < b.order
    end)
    out[#out + 1] = grp
  end
  local other = { socket = "other", gems = {} }
  for _, g in ipairs(list) do
    if not placed[g.id] then other.gems[#other.gems + 1] = { id = g.id, meta = g.meta, phase = g.phase } end
  end
  if #other.gems > 0 then out[#out + 1] = other end
  return out
end

-- the first BiS gem that fits a socket colour (pure colour first); nil if none
function B.GemForSocket(groups, socket)
  for _, grp in ipairs(groups or {}) do
    if grp.socket == socket then return grp.gems[1] end
  end
end

-- An item's empty sockets (by colour, in the item's order) and its socket bonus, read from the item's tooltip:
-- the game's item stats only give socket counts, and only the tooltip says which ones are still empty.
local socketText, bonusPat, gemScan
local function SocketTexts()
  if socketText then return socketText end
  socketText = {}
  for _, c in ipairs({ "RED", "YELLOW", "BLUE", "META", "PRISMATIC" }) do
    local t = _G["EMPTY_SOCKET_" .. c]
    if type(t) == "string" then socketText[t] = c:lower() end
  end
  return socketText
end
local function InvLines(slot)
  local out = {}
  if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if ok and type(data) == "table" and data.lines then
      for _, l in ipairs(data.lines) do
        local c = l.leftColor
        out[#out + 1] = { text = l.leftText, r = c and c.r, g = c and c.g }
      end
      return out
    end
  end
  if not CreateFrame then return out end
  if not gemScan then gemScan = CreateFrame("GameTooltip", "GuildLadderDKPGemScanTip", nil, "GameTooltipTemplate") end
  gemScan:SetOwner(WorldFrame, "ANCHOR_NONE")
  gemScan:ClearLines()
  if not pcall(gemScan.SetInventoryItem, gemScan, "player", slot) then return out end
  for i = 1, gemScan:NumLines() do
    local fs = _G["GuildLadderDKPGemScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t then
      local r, g = fs:GetTextColor()
      out[#out + 1] = { text = t, r = r, g = g }
    end
  end
  return out
end
function B.SocketScan(slot)
  local res = { empty = {} }
  local ok, lines = pcall(InvLines, slot)
  if not ok or type(lines) ~= "table" then return res end
  local st = SocketTexts()
  if not bonusPat and type(ITEM_SOCKET_BONUS) == "string" then
    local p = ITEM_SOCKET_BONUS:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)")
    bonusPat = "^" .. p .. "$"
  end
  for _, l in ipairs(lines) do
    local t = l.text
    if type(t) == "string" then
      local ok2, c = pcall(function() return st[t] end)
      if ok2 and c then
        res.empty[#res.empty + 1] = c
      elseif bonusPat then
        local ok3, b = pcall(string.match, t, bonusPat)
        if ok3 and b then
          res.bonus = b
          res.bonusOn = (tonumber(l.g) or 0) > 0.8 and (tonumber(l.r) or 1) < 0.5 -- green = active, grey = not
        end
      end
    end
  end
  return res
end

-- what I wear against the BiS enchants and gems of a phase
-- row = { key, label, slot, link, itemId, enchantID, enchanted, needs, bis = { enchant entries }, gems = { {id, bis} },
--         sockets, empty, emptyColors (v1.4.0), bonus, bonusOn }; summary = { class, spec, phase, needed, done, sockets, filled, bisGems, empty }
function B.GearCheck(phase)
  local d, why = B.Data()
  if not d then return nil, why end
  local class, spec = B.MySpec()
  if not spec then return nil, "nospec" end
  phase = math.max(0, math.min(5, math.floor(tonumber(phase) or B.Phase())))
  local ench, set = B.Enchants(class, spec, phase), B.GemSet(class, spec, phase)
  local R = D.Rd
  local rows = {}
  local sum = { class = class, spec = spec, phase = phase, needed = 0, done = 0, sockets = 0, filled = 0, bisGems = 0, empty = 0 }
  for _, def in ipairs(B.GEARROWS) do
    local row = { key = def[1], label = def[2], slot = def[3], bis = def[4] and ench[def[4]] or {}, gems = {}, sockets = 0, empty = 0 }
    local link = GetInventoryItemLink and GetInventoryItemLink("player", def[3])
    if link then
      local id, e, g1, g2, g3, g4 = link:match("item:(%d+):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
      row.link, row.itemId = link, tonumber(id)
      row.enchantID = tonumber(e) or 0
      row.enchanted = row.enchantID ~= 0
      if R and R.EnchantNeeded then row.needs = R.EnchantNeeded(def[3], link) and #row.bis > 0 else row.needs = #row.bis > 0 end
      for _, g in ipairs({ g1, g2, g3, g4 }) do
        local gid = tonumber(g) or 0
        if gid ~= 0 then row.gems[#row.gems + 1] = { id = gid, bis = set[gid] ~= nil } end
      end
      row.sockets = (R and R.SocketCount and R.SocketCount(row.itemId)) or 0
      row.empty = math.max(0, row.sockets - #row.gems)
      -- v1.4.0: colours of the empty sockets + the socket bonus (from the tooltip)
      local sc = B.SocketScan(def[3])
      row.emptyColors, row.bonus, row.bonusOn = sc.empty, sc.bonus, sc.bonusOn
      if #sc.empty > row.empty then row.empty = #sc.empty; row.sockets = #row.gems + row.empty end
      if row.needs then sum.needed = sum.needed + 1; if row.enchanted then sum.done = sum.done + 1 end end
      sum.sockets = sum.sockets + math.max(row.sockets, #row.gems)
      sum.filled = sum.filled + #row.gems
      sum.empty = sum.empty + row.empty
      for _, g in ipairs(row.gems) do if g.bis then sum.bisGems = sum.bisGems + 1 end end
    else
      row.needs = #row.bis > 0 and def[3] ~= 17 and def[3] ~= 18
      if row.needs then sum.needed = sum.needed + 1 end
    end
    rows[#rows + 1] = row
  end
  return rows, sum
end

-- choices for the "My BiS spec" dropdown
function B.SpecOptions()
  local class = B.MyClass()
  local auto = B.AutoSpec(class)
  local t = { { "auto", "BiS: auto" .. (auto and (" (" .. B.SpecLabel(auto) .. ")") or "") } }
  for _, s in ipairs(B.Specs(class)) do t[#t + 1] = { s, "BiS: " .. B.SpecLabel(s) } end
  return t
end

function B.SpecValue()
  local _, spec, auto = B.MySpec()
  if auto then
    return "auto", "BiS: auto" .. (spec and (" (" .. B.SpecLabel(spec) .. ")") or "")
  end
  return spec, "BiS: " .. B.SpecLabel(spec)
end

---------------------------------------------------------------------------
-- /dkp bis ...
---------------------------------------------------------------------------
function B.Slash(rest)
  local Print = D.Print
  rest = rest or ""
  local a, b = rest:match("^(%S*)%s*(.-)%s*$")
  a = (a or ""):lower()
  local d, why = B.Data()
  if a == "spec" then
    if not d then Print("No BiS lists loaded.") return end
    if b == "" or b:lower() == "auto" then
      B.SetSpec(nil)
      local _, spec = B.MySpec()
      Print("BiS spec: automatic (" .. (spec and B.SpecLabel(spec) or "no talents yet") .. ").")
      return
    end
    for _, s in ipairs(B.Specs(B.MyClass())) do
      if s:lower() == b:lower() or B.SpecLabel(s):lower() == b:lower() then
        B.SetSpec(s)
        Print("BiS spec: " .. B.SpecLabel(s) .. ".")
        return
      end
    end
    local names = {}
    for _, s in ipairs(B.Specs(B.MyClass())) do names[#names + 1] = B.SpecLabel(s) end
    Print("Pick one of: " .. table.concat(names, ", ") .. ", or auto.")
  elseif a == "tooltip" then
    D.settings.bisTooltip = (b:lower() ~= "off")
    Print("BiS lines on item tooltips " .. (D.settings.bisTooltip and "on." or "off."))
  elseif a == "bestfor" then
    D.settings.bisBestFor = (b:lower() ~= "off")
    Print("\"Best for\" list on item tooltips " .. (D.settings.bisBestFor and "on." or "off."))
  elseif a == "gear" or a == "plan" then
    if D.ToggleGearPlan then D.ToggleGearPlan(true) end
  elseif a == "enchants" then
    if D.ToggleEnchants then D.ToggleEnchants(true) end
  elseif a == "gems" then -- v1.4.0: its own window
    if D.ToggleGems then D.ToggleGems(true) end
  elseif a == "raid" or a == "raidloot" then
    if D.ShowRaidLoot then D.ShowRaidLoot(b ~= "" and b or nil) end
  elseif a == "sound" then
    local list = D.WantSounds()
    local bl = b:lower()
    if bl == "on" or bl == "off" then
      D.settings.wantSound = (bl == "on")
      Print("Special sound for wishlist / BIS-upgrade auctions " .. (D.settings.wantSound and "on." or "off."))
    elseif tonumber(b) and list[tonumber(b)] then
      D.settings.wantSoundId = tonumber(b)
      Print("Special auction sound: " .. D.PlayWantSound(tonumber(b)) .. ".")
    else
      Print("Auction sound for items on your wishlist or BIS upgrades: " .. (D.settings.wantSound ~= false and "on" or "off")
        .. ", using " .. list[tonumber(D.settings.wantSoundId) or 2][1] .. ".")
      for i, s in ipairs(list) do Print(("  /dkp bis sound %d  -  %s"):format(i, s[1])) end
      Print("  /dkp bis sound on|off")
      D.PlayWantSound()
    end
  elseif a == "raidpopup" then
    D.settings.raidPopup = (b:lower() ~= "off")
    Print("Raid loot popup on entering a raid " .. (D.settings.raidPopup and "on." or "off."))
  elseif a ~= "" and D.ItemIDFromText and D.ItemIDFromText(rest) then
    local v, r = B.Verdict(D.ItemIDFromText(rest))
    if not v then Print("No BiS verdict (" .. tostring(r) .. ").") return end
    Print(B.Chip(v))
    for _, l in ipairs(B.TooltipLines(v.id)) do Print(l[1]) end
  else
    if not d then
      Print(why == "era" and "BiS lists are for TBC; this game is not TBC, so they are off."
        or "No BiS lists loaded (BiSData_TBC.lua is missing from the add-on folder).")
      return
    end
    local class, spec, auto = B.MySpec()
    Print(("BiS lists %s (%s). You: %s%s. Guild phase: %s."):format(tostring(d.version), tostring(d.source),
      spec and B.SpecLabel(spec) or "no spec yet", auto and " (auto)" or "", PHASE_RAIDS[B.Phase()]))
    Print("/dkp gear  ·  /dkp raidloot [raid]  ·  /dkp bis spec <name|auto>  ·  /dkp bis tooltip on|off  ·  /dkp bis bestfor on|off  ·  /dkp bis raidpopup on|off  ·  /dkp bis sound  ·  /dkp bis <item link>")
  end
end
