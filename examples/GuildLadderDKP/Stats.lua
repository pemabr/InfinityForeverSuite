local ADDON, D = ...
local Print = D.Print

--[[
  v1.5.0 PODIUM, part 1: stats + awards (the screen itself is in Podium.lua)

  1. TRACKER (every raider): while I'm inside a raid instance, my own client
     counts MY damage / healing / damage taken / deaths / interrupts / dispels
     (and my pet's damage) from the combat log, split into boss and trash.
     Nothing is sent while it counts. Totals live in GuildLadderDKPDB.stats.me
     (saved on /reload and logout) and reset when a new raid night starts.
  2. COLLECTING (officer): End raid asks the raid for totals (XQ). Each raider's
     add-on whispers its totals back (XR). 5 seconds later the awards are drawn.
  3. DRAW (S.Draw): each award has a rule for "did this apply tonight?" and a
     score for how clearly someone won it. A weighted random draw picks one
     headline (always a good one) and four more, never the same person or
     award twice, at most 2 roasts. The seed is the raid id, so a re-run gives
     the same result unless the officer rerolls.
  4. SHARE: the officer reviews the screen (reroll if wanted), then shares it.
     Sharing writes one PD ledger event per winner (record only, no DKP) and
     sends the screen to the raid (XH header + XE entries, ~60 bytes each).
]]

local S = {}
D.Stats = S

local function Short(n) return n and (tostring(n):gsub("%-.*$", "")) end
local function Num(v) return math.floor((tonumber(v) or 0) + 0.5) end

---------------------------------------------------------------------------
-- Award list. Codes are stored in the ledger, so never rename a code.
---------------------------------------------------------------------------
local function Big(v)
  v = tonumber(v) or 0
  if v >= 1000000 then return ("%.1fM"):format(v / 1000000) end
  if v >= 1000 then return ("%dK"):format(math.floor(v / 1000 + 0.5)) end
  return tostring(math.floor(v))
end
S.Big = Big

local CAN_INT = { WARRIOR = true, ROGUE = true, SHAMAN = true, MAGE = true, WARLOCK = true }

local function Median(list)
  if #list == 0 then return 0 end
  local t = {}
  for i, v in ipairs(list) do t[i] = v end
  table.sort(t)
  local n = #t
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- players not yet used, passing a filter, sorted by a value (highest first)
local function Rank(env, used, filter, field, ascending)
  local out = {}
  for _, p in ipairs(env.players) do
    if not used[p.name] and (not filter or filter(p)) then
      local v = type(field) == "function" and field(p) or p[field]
      if v then out[#out + 1] = { p = p, v = v } end
    end
  end
  table.sort(out, function(a, b)
    if a.v ~= b.v then
      if ascending then return a.v < b.v end
      return a.v > b.v
    end
    return a.p.name < b.p.name
  end)
  return out
end

-- how clearly the winner won: 0 = a photo finish, 1 = nobody came close
local function Margin(r)
  if #r < 2 then return 0.6 end
  local a, b = r[1].v, r[2].v
  if a <= 0 then return 0 end
  return math.min(1, math.max(0, (a - b) / a))
end

local function Ledger(env, used, tbl, minimum)
  local out = {}
  for name, v in pairs(tbl or {}) do
    local p = env.byName[name]
    if p and not used[p.name] and v >= minimum then out[#out + 1] = { p = p, v = v } end
  end
  table.sort(out, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.p.name < b.p.name end)
  return out
end

local function Clock(mins)
  mins = tonumber(mins) or 0
  return ("%d:%02d"):format(math.floor(mins / 60) % 24, mins % 60)
end

-- kind: pos / roast. head: weight boost when picking the headline.
local DEFS = {
  { code = "BS", name = "Boss Slayer", kind = "pos", head = 1.6, flavor = "Saved the big numbers for the big guys.",
    text = function(v) return Big(v) .. " boss damage" end,
    eval = function(env, used)
      if env.nDps < 3 then return end
      local r = Rank(env, used, function(p) return p.eff == "D" and p.bossDmg > 0 end, "bossDmg")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "LL", name = "Lifeline", kind = "pos", head = 1.5, flavor = "Kept the whole raid breathing.",
    text = function(v) return Big(v) .. " healing" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.eff == "H" and p.heal > 0 end, "heal")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "TW", name = "The Wall", kind = "pos", head = 1.5, flavor = "Stood in the fire so nobody else had to.",
    text = function(v) return Big(v) .. " damage taken" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.eff == "T" and p.taken > 0 and p.deaths <= 1 end, "taken")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "IM", name = "Immortal", kind = "pos", head = 1.2, flavor = "Everyone else hit the floor. Not this one.",
    text = function(v) return ("0 deaths (raid: %d)"):format(v) end,
    eval = function(env, used)
      if env.deaths < 4 then return end
      local r = Rank(env, used, function(p) return p.deaths == 0 and (p.dmg + p.heal) > 0 end, function(p) return p.dmg + p.heal end)
      if #r > 0 then return r[1].p, env.deaths, math.min(1, env.deaths / (#env.players * 1.5)) end
    end },
  { code = "SI", name = "Silencer", kind = "pos", flavor = "Nothing finished casting on their watch.",
    text = function(v) return v .. " interrupts" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.ints >= 3 end, "ints")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "PU", name = "Purifier", kind = "pos", flavor = "Cleansed everything the boss threw at us.",
    text = function(v) return v .. " dispels" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.disp >= 5 end, "disp")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "BP", name = "Best Prepared", kind = "pos", flavor = "Flask. Food. Scrolls. Ready for anything.",
    text = function(v) return "Prepared for " .. v .. " pulls" end,
    eval = function(env, used)
      local r = Ledger(env, used, env.ctx.prepared, 3)
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "HH", name = "Heavy Hitter", kind = "pos", flavor = "Everything they touched fell over.",
    text = function(v) return Big(v) .. " damage" end,
    eval = function(env, used)
      if env.nDps < 3 then return end
      local r = Rank(env, used, function(p) return p.eff == "D" and p.dmg > 0 end, "dmg")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "TC", name = "Trash Compactor", kind = "pos", flavor = "Cleared the trash. Left the bosses to the rest.",
    text = function(v) return Big(v) .. " trash damage" end,
    eval = function(env, used)
      if env.nDps < 3 then return end
      local r = Rank(env, used, function(p) return p.eff == "D" and p.trashDmg > 0 end, "trashDmg")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },

  { code = "FI", name = "Floor Inspector", kind = "roast", flavor = "Spent more time on the floor than anyone.",
    text = function(v) return v .. " deaths" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.deaths >= 2 end, "deaths")
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "PA", name = "Pacifist", kind = "roast", flavor = "Believes the bosses deserve a second chance.",
    text = function(v) return "Only " .. Big(v) .. " damage on bosses" end,
    eval = function(env, used)
      if env.nDps < 4 or env.medBoss <= 0 then return end
      local r = Rank(env, used, function(p) return p.eff == "D" end, "bossDmg", true)
      if #r > 0 and r[1].v < env.medBoss * 0.5 then return r[1].p, r[1].v, 1 - r[1].v / env.medBoss end
    end },
  { code = "EP", name = "Earplugs", kind = "roast", flavor = "Couldn't hear the kick call. Never can.",
    text = function() return "0 interrupts" end,
    eval = function(env, used)
      if env.totalInts < 4 then return end
      local r = Rank(env, used, function(p) return CAN_INT[p.class] and p.ints == 0 and (p.dmg + p.heal) > 0 end, "dmg")
      if #r > 0 then
        local pick = r[math.floor(env.rnd() * #r) + 1]
        return pick.p, 0, 0.35
      end
    end },
  { code = "DS", name = "Damage Sponge", kind = "roast", flavor = "Soaked up everything. Nobody asked them to.",
    text = function(v) return Big(v) .. " damage taken" end,
    eval = function(env, used)
      local r = Rank(env, used, function(p) return p.eff ~= "T" and p.taken > 0 end, "taken")
      if #r >= 3 and r[1].v >= r[2].v * 1.4 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "FL", name = "Fashionably Late", kind = "roast", flavor = "The raid waited. They arrived like it was planned.",
    text = function(v) return "Showed up at " .. Clock(v) end,
    eval = function(env, used)
      local r = Ledger(env, used, env.ctx.late, 0)
      if #r > 0 then return r[1].p, r[1].v, 0.5 end
    end },
  { code = "LG", name = "Loot Goblin", kind = "roast", flavor = "Never met a drop they didn't want.",
    text = function(v) return v .. " items won" end,
    eval = function(env, used)
      local r = Ledger(env, used, env.ctx.items, 2)
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
  { code = "BW", name = "Big Spender", kind = "roast", flavor = "Cleaned out the bank account in one night.",
    text = function(v) return v .. " DKP spent" end,
    eval = function(env, used)
      local r = Ledger(env, used, env.ctx.spent, 1)
      if #r > 0 then return r[1].p, r[1].v, Margin(r) end
    end },
}
S.DEFS = DEFS
local BYCODE = {}
for _, d in ipairs(DEFS) do BYCODE[d.code] = d end
S.BYCODE = BYCODE

function D.PodiumAwardName(code) return BYCODE[code] and BYCODE[code].name or code end

---------------------------------------------------------------------------
-- v1.6.0: award icons. One 64x64 32-bit TGA per award code in Media\Awards\.
-- Gold ring = good award, purple ring = roast. Codes never change, so the
-- file name is looked up by code.
---------------------------------------------------------------------------
local ART_DIR = "Interface\\AddOns\\GuildLadderDKP\\Media\\Awards\\"
local ART = {
  BS = "BossSlayer", LL = "Lifeline", TW = "TheWall", IM = "Immortal", SI = "Silencer", PU = "Purifier",
  BP = "BestPrepared", HH = "HeavyHitter", TC = "TrashCompactor",
  FI = "FloorInspector", PA = "Pacifist", EP = "Earplugs", DS = "DamageSponge", FL = "FashionablyLate",
  LG = "LootGoblin", BW = "BigSpenderRoast",
}
local ART_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local ORDER = {}
for i, d in ipairs(DEFS) do ORDER[d.code] = i end
local COUNT_HEX, POS_RGB, ROAST_RGB = "ffe0b04f", { 0.35, 0.82, 1 }, { 1, 0.35, 0.65 }

function D.AwardIcon(code)
  local f = ART[code]
  return f and (ART_DIR .. f .. ".tga") or ART_FALLBACK
end
-- the icon as inline text (works in any FontString and tooltip line)
function D.AwardInline(code, size)
  size = size or 16
  return ("|T%s:%d:%d|t"):format(D.AwardIcon(code), size, size)
end
function D.AwardKind(code) return BYCODE[code] and BYCODE[code].kind or "pos" end
function D.AwardFlavor(code) return BYCODE[code] and BYCODE[code].flavor or "" end
function D.AwardColor(code) -- r, g, b for the award's name (blue = award, pink = roast)
  local c = D.AwardKind(code) == "roast" and ROAST_RGB or POS_RGB
  return c[1], c[2], c[3]
end
-- the guild setting that turns the joke awards off also hides them on profiles
function D.PodiumRoastsOn() return tonumber(D.Cfg and D.Cfg("PODIUM_ROASTS")) ~= 0 end

---------------------------------------------------------------------------
-- The draw
---------------------------------------------------------------------------
local function MakeRng(seed)
  local h = 5381
  for i = 1, #seed do h = (h * 33 + seed:byte(i)) % 2147483647 end
  return function()
    h = (h * 1103515245 + 12345) % 2147483648
    return h / 2147483648
  end
end

-- env.players: { name, class, role (T/H/D/F), dmg, bossDmg, trashDmg, heal, taken, deaths, ints, disp }
-- env.ctx: { items = {name=n}, spent = {name=dkp}, prepared = {name=n}, late = {name=minutes} }
local function PrepEnv(env)
  env.byName = {}
  local takenOther, bossDps = {}, {}
  for _, p in ipairs(env.players) do
    env.byName[p.name] = p
    for _, f in ipairs({ "dmg", "bossDmg", "trashDmg", "heal", "taken", "deaths", "ints", "disp" }) do p[f] = tonumber(p[f]) or 0 end
    if p.role ~= "T" then takenOther[#takenOther + 1] = p.taken end
  end
  -- ledger-only people (late, loot...) get a record with no stats
  for _, tbl in ipairs({ env.ctx.items or {}, env.ctx.spent or {}, env.ctx.prepared or {}, env.ctx.late or {} }) do
    for name in pairs(tbl) do
      if not env.byName[name] then
        local p = { name = name, class = D.ClassOf and D.ClassOf(name) or nil, role = "D", noStats = true,
          dmg = 0, bossDmg = 0, trashDmg = 0, heal = 0, taken = 0, deaths = 0, ints = 0, disp = 0 }
        env.byName[name] = p
      end
    end
  end
  local medTaken = Median(takenOther)
  env.deaths, env.totalInts, env.nDps = 0, 0, 0
  for _, p in ipairs(env.players) do
    -- effective role: a Feral druid counts as a tank only if they took tank-sized damage
    if p.role == "F" then p.eff = (medTaken > 0 and p.taken >= medTaken * 1.5) and "T" or "D" else p.eff = p.role or "D" end
    env.deaths = env.deaths + p.deaths
    env.totalInts = env.totalInts + p.ints
    if p.eff == "D" then env.nDps = env.nDps + 1; bossDps[#bossDps + 1] = p.bossDmg end
  end
  for name, p in pairs(env.byName) do p.eff = p.eff or "D" end
  env.medBoss = Median(bossDps)
end

function S.Draw(env, seed)
  env.rnd = MakeRng(seed or "seed")
  env.ctx = env.ctx or {}
  PrepEnv(env)
  local used, taken, roasts = {}, {}, 0

  local function Round(posOnly, boostHead, roastCap)
    local cands, wsum = {}, 0
    for _, d in ipairs(DEFS) do
      local skip = taken[d.code] or (posOnly and d.kind ~= "pos")
        or (d.kind == "roast" and (not env.roasts or roasts >= roastCap))
      if not skip then
        local ok, p, v, sc = pcall(d.eval, env, used)
        if ok and p then
          local w = 0.25 + (sc or 0.3)
          if boostHead and d.head then w = w * d.head end
          if env.last then
            if env.last.codes and env.last.codes[d.code] then w = w * 0.5 end
            if env.last.names and env.last.names[p.name] then w = w * 0.6 end
          end
          cands[#cands + 1] = { d = d, p = p, v = v, w = w }
          wsum = wsum + w
        end
      end
    end
    if #cands == 0 then return nil end
    local x = env.rnd() * wsum
    for _, c in ipairs(cands) do
      x = x - c.w
      if x <= 0 then return c end
    end
    return cands[#cands]
  end

  local function Take(c)
    used[c.p.name] = true
    taken[c.d.code] = true
    if c.d.kind == "roast" then roasts = roasts + 1 end
    return { code = c.d.code, name = c.p.name, class = c.p.class, val = c.v, kind = c.d.kind, award = c.d.name,
      flavor = c.d.flavor, text = c.d.text(c.v) }
  end

  local picks, extra = {}, {}
  local head = Round(true, true, 2) or Round(false, true, 2)
  if head then picks[1] = Take(head) end
  for _ = 1, 4 do
    local c = Round(false, false, 2)
    if c then picks[#picks + 1] = Take(c) end
  end
  for _ = 1, 2 do
    local c = Round(false, false, 3)
    if c then extra[#extra + 1] = Take(c) end
  end
  if #picks < 3 then return nil end
  return { picks = picks, extra = extra }
end

---------------------------------------------------------------------------
-- 1. Tracker (my own numbers)
---------------------------------------------------------------------------
local FIELDS = { "dmg", "bossDmg", "trashDmg", "heal", "taken", "deaths", "ints", "disp" }

local function Fresh()
  local t = { t0 = GetServerTime(), act = GetServerTime(), wipes = 0, boss = 0 }
  for _, f in ipairs(FIELDS) do t[f] = 0 end
  return t
end

local cur
local meGUID, petGUID, bossActive

function S.Cur()
  if not cur and D.db then
    D.db.stats = D.db.stats or {}
    D.db.stats.me = D.db.stats.me or Fresh()
    cur = D.db.stats.me
  end
  return cur
end

local function Rollover()
  if not D.db then return end
  S.Cur()
  if not cur then return end
  if cur.reported or (GetServerTime() - (cur.act or 0)) > 12 * 3600 then
    cur = Fresh()
    D.db.stats.me = cur
  end
end

function S.Reset()
  if not D.db then return end
  D.db.stats = D.db.stats or {}
  cur = Fresh()
  D.db.stats.me = cur
end

local DMG = { SPELL_DAMAGE = true, RANGE_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, DAMAGE_SHIELD = true }
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local Secret = D.Secret or function() return false end

local function Amount(v)
  if Secret(v) then return 0 end
  return tonumber(v) or 0
end

local function OnCLEU()
  if not cur then return end
  local ts, sub, hide, sg, sn, sf, srf, dg, dn, df, drf, a12, a13, a14, a15, a16 = CombatLogGetCurrentEventInfo()
  local mine = sg == meGUID
  local pet = (not mine) and petGUID ~= nil and sg == petGUID
  if mine or pet then
    if sub == "SWING_DAMAGE" or DMG[sub] then
      local amt = Amount(sub == "SWING_DAMAGE" and a12 or a15)
      cur.dmg = cur.dmg + amt
      if bossActive then cur.bossDmg = cur.bossDmg + amt else cur.trashDmg = cur.trashDmg + amt end
    elseif mine and HEAL[sub] then
      cur.heal = cur.heal + math.max(0, Amount(a15) - Amount(a16))
    elseif sub == "SPELL_INTERRUPT" then
      cur.ints = cur.ints + 1
    elseif mine and sub == "SPELL_DISPEL" then
      cur.disp = cur.disp + 1
    end
  end
  if dg == meGUID then
    if sub == "UNIT_DIED" then
      cur.deaths = cur.deaths + 1
    elseif sub == "SWING_DAMAGE" then
      cur.taken = cur.taken + Amount(a12)
    elseif DMG[sub] then
      cur.taken = cur.taken + Amount(a15)
    end
  end
end

local frame = CreateFrame("Frame")
local cleuOn = false
function S.Update()
  if not D.db then return end
  S.Cur()
  meGUID = UnitGUID("player")
  petGUID = UnitExists("pet") and UnitGUID("pet") or nil
  local _, itype = IsInInstance()
  local want = itype == "raid"
  if want and not cleuOn then
    local ok = pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
    cleuOn = ok
  elseif not want and cleuOn then
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    cleuOn = false
  end
  if want then Rollover() end
end

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "UNIT_PET" }) do
  pcall(frame.RegisterEvent, frame, e)
end
frame:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    pcall(OnCLEU)
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(1.5, S.Update)
  elseif event == "UNIT_PET" then
    if a1 == "player" then petGUID = UnitExists("pet") and UnitGUID("pet") or nil end
  elseif event == "ENCOUNTER_START" then
    if cur then Rollover(); S.Cur(); bossActive = true; cur.act = GetServerTime() end
  elseif event == "ENCOUNTER_END" then
    bossActive = false
    if cur then
      cur.act = GetServerTime()
      if a5 == 1 then cur.boss = cur.boss + 1 else cur.wipes = cur.wipes + 1 end
    end
  end
end)

-- the talent tree I have most points in (same idea as Readiness.lua)
local function MainTab()
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local ok, n = pcall(GetNumTalentTabs)
  if not ok or type(n) ~= "number" then return nil end
  local best, bestPts = nil, 0
  for i = 1, n do
    local ok2, a, _, c, _, e = pcall(GetTalentTabInfo, i)
    if ok2 then
      local pts = (type(a) == "string") and c or e
      if type(pts) == "number" and pts > bestPts then best, bestPts = i, pts end
    end
  end
  return best
end

-- T tank, H healer, D damage, F feral druid (decided later from damage taken)
local function RoleOf(class, tab)
  if class == "WARRIOR" then return tab == 3 and "T" or "D" end
  if class == "PALADIN" then return tab == 1 and "H" or (tab == 2 and "T" or "D") end
  if class == "DRUID" then return tab == 3 and "H" or (tab == 2 and "F" or "D") end
  if class == "PRIEST" then return tab == 3 and "D" or "H" end
  if class == "SHAMAN" then return tab == 3 and "H" or "D" end
  return "D"
end

function S.MyRecord()
  S.Cur()
  local _, class = UnitClass("player")
  local rec = { name = Short(D.Me()), class = class, role = RoleOf(class, MainTab()) }
  for _, f in ipairs(FIELDS) do rec[f] = Num(cur and cur[f]) end
  rec.wipes = cur and cur.wipes or 0
  rec.boss = cur and cur.boss or 0
  return rec
end

---------------------------------------------------------------------------
-- 2. Collecting (officer) and replying (raiders)
---------------------------------------------------------------------------
D.handlers = D.handlers or {}

D.handlers.XQ = function(p, sender, channel)
  if (channel ~= "RAID" and channel ~= "PARTY") or not D.IsAdmin(sender) then return end
  if D.SameName(sender, D.Me()) then return end
  if not S.Cur() then return end
  local r = S.MyRecord()
  if (r.dmg + r.heal + r.taken) <= 0 then return end
  cur.reported = p[2] or true
  D.Send(D.Pack("XR", p[2], r.class, r.role, r.dmg, r.bossDmg, r.trashDmg, r.heal, r.taken, r.deaths, r.ints, r.disp, r.wipes, r.boss),
    "WHISPER", sender)
end

D.handlers.XR = function(p, sender)
  local col = S.collect
  if not col or p[2] ~= col.sid then return end
  local name = Short(sender)
  col.board[name] = { name = name, class = p[3], role = p[4], dmg = Num(p[5]), bossDmg = Num(p[6]), trashDmg = Num(p[7]),
    heal = Num(p[8]), taken = Num(p[9]), deaths = Num(p[10]), ints = Num(p[11]), disp = Num(p[12]) }
end

-- what the ledger knows about tonight
function S.LedgerContext(ses)
  local ctx = { items = {}, spent = {}, prepared = {}, late = {}, bosses = 0 }
  local night = D.data and D.data.byNight and D.data.byNight[ses.id]
  if night then
    for _, e in ipairs(night.spends or {}) do
      local who = Short(e.p)
      if who then
        ctx.items[who] = (ctx.items[who] or 0) + 1
        ctx.spent[who] = (ctx.spent[who] or 0) + (tonumber(e.v) or 0)
      end
    end
    local bossSeen = {}
    for _, e in ipairs(night.awards or {}) do
      if e.x == "BOSS" and e.r and not bossSeen[e.r] then bossSeen[e.r] = true; ctx.bosses = ctx.bosses + 1 end
      if e.x == "CUSTOM" and (e.r or ""):find("^Prepared:") then
        for _, n in ipairs(D.SplitNames(e.p)) do
          local who = Short(n)
          ctx.prepared[who] = (ctx.prepared[who] or 0) + 1
        end
      end
    end
  end
  local ok, chk = pcall(D.RaidCheck)
  if ok and chk then
    for _, n in ipairs(chk.late or {}) do ctx.late[Short(n)] = D.joinT and D.joinT[D.FirstName(n)] or 0 end
  end
  return ctx
end

local function Duration(secs)
  secs = math.max(0, math.floor(secs or 0))
  local h, m = math.floor(secs / 3600), math.floor((secs % 3600) / 60)
  if h > 0 then return ("%dh %02dm"):format(h, m) end
  return ("%dm"):format(m)
end

local function SummaryLine(bosses, secs, wipes, deaths)
  local parts = {}
  if bosses and bosses > 0 then parts[#parts + 1] = ("%d boss%s down"):format(bosses, bosses == 1 and "" or "es") end
  if secs and secs > 0 then parts[#parts + 1] = Duration(secs) end
  if wipes and wipes > 0 then parts[#parts + 1] = ("%d wipe%s"):format(wipes, wipes == 1 and "" or "s") end
  parts[#parts + 1] = ("%d death%s"):format(deaths or 0, deaths == 1 and "" or "s")
  return table.concat(parts, "  ·  ")
end

local function Remember(screen)
  if not D.db or screen.test then return end
  D.db.stats = D.db.stats or {}
  local h = D.db.stats.history or {}
  table.insert(h, 1, { title = screen.title, summary = screen.summary, picks = screen.picks, extra = screen.extra, t = GetServerTime() })
  while #h > 5 do table.remove(h) end
  D.db.stats.history = h
end

local function MemoryOf(picks, extra)
  local last = { codes = {}, names = {} }
  for _, l in ipairs({ picks, extra or {} }) do
    for _, p in ipairs(l) do last.codes[p.code] = true; last.names[p.name] = true end
  end
  return last
end

-- turn a draw into a screen for Podium.lua
local function BuildScreen(col, res)
  local s = {
    title = col.title, summary = col.summary, picks = res.picks, extra = res.extra, sid = col.sid, test = col.test,
    preview = col.preview, demo = col.demo, -- v1.5.1: demo = fake raid (shows your own model on every card, also in practice mode)
  }
  s.onReroll = function() col.reroll = (col.reroll or 0) + 1; S.ShowDraw(col) end
  s.onPost = col.canPost and function() S.Post(col) end or nil
  return s
end

function S.ShowDraw(col)
  local env = { players = col.players, ctx = col.ctx, roasts = tonumber(D.Cfg("PODIUM_ROASTS")) ~= 0,
    last = D.db and D.db.stats and D.db.stats.last }
  -- Draw reads and fills the player records, so give it fresh copies
  local copies = {}
  for i, p in ipairs(col.players) do local c = {}; for k, v in pairs(p) do c[k] = v end; copies[i] = c end
  env.players = copies
  local res = S.Draw(env, tostring(col.sid) .. "|" .. (col.reroll or 0))
  if not res then
    Print(("Not enough stats for the awards (%d players reported). Raiders need the add-on, and the raid needs a few fights."):format(#col.players))
    return
  end
  col.res = res
  col.deathsTotal = env.deaths
  col.summary = SummaryLine(col.bosses, col.secs, col.wipes, env.deaths)
  if D.Podium and D.Podium.Show then D.Podium.Show(BuildScreen(col, res)) end
end

function S.Finish()
  local col = S.collect
  if not col then return end
  col.players = {}
  for _, rec in pairs(col.board) do col.players[#col.players + 1] = rec end
  table.sort(col.players, function(a, b) return a.name < b.name end)
  col.preview = true
  S.ShowDraw(col)
end

-- officer: End raid calls this (Core.lua D.EndSession) before the raid is ended
function D.PodiumBegin(ses)
  if not ses or tonumber(D.Cfg("PODIUM_ON")) == 0 then return end
  local mine = S.MyRecord()
  S.collect = {
    sid = ses.id, title = ses.title or "Raid", ses = ses, board = { [mine.name] = mine }, ctx = S.LedgerContext(ses),
    canPost = true, reroll = 0, wipes = mine.wipes, secs = ses.start and (GetServerTime() - ses.start) or 0,
  }
  S.collect.bosses = S.collect.ctx.bosses
  if cur then cur.reported = ses.id end
  if D.InRaid() and not D.practice then D.Send(D.Pack("XQ", ses.id), "RAID") end
  Print("Collecting raid stats for the awards screen...")
  C_Timer.After(5, S.Finish)
end

-- /dkp podium end: run it again later for the last raid
function S.Redo()
  local ses = D.OpenSession and D.OpenSession()
  if not ses and D.data then
    for _, s in pairs(D.data.sessions or {}) do
      if s.ended and s.start and (not ses or s.ended > ses.ended) then ses = s end
    end
  end
  if not ses then Print("No raid to run the awards for.") return end
  D.PodiumBegin(ses)
end

---------------------------------------------------------------------------
-- 4. Sharing: ledger events + broadcast
---------------------------------------------------------------------------
function S.Post(col)
  if col.posted or not col.res then return end
  if not (D.IsAdmin() or D.practice) then Print("Only officers can share the awards.") return end
  col.posted = true
  local all = {}
  for _, p in ipairs(col.res.picks) do all[#all + 1] = p end
  for _, p in ipairs(col.res.extra) do all[#all + 1] = p end
  local ses = col.ses
  for _, p in ipairs(all) do
    D.NewEvent({ k = "PD", p = D.Canon(p.name), u = p.code, v = "1", x = ses.id, g = ses.id, r = ses.title })
  end
  if D.db then
    D.db.stats = D.db.stats or {}
    D.db.stats.last = MemoryOf(col.res.picks, col.res.extra)
  end
  if D.InRaid() and not D.practice then
    local nonce = GetServerTime() % 100000
    D.Send(D.Pack("XH", ses.id, nonce, #all, D.Clean(col.title, 40), col.bosses or 0, col.secs or 0, col.wipes or 0, col.deathsTotal or 0), "RAID")
    for i, p in ipairs(all) do
      D.Send(D.Pack("XE", ses.id, nonce, i, p.code, D.Clean(p.name, 24), p.class or "", Num(p.val)), "RAID")
    end
  end
  Remember({ title = col.title, summary = col.summary, picks = col.res.picks, extra = col.res.extra })
  Print(D.practice and "Awards shared (practice: nothing was sent, and the profile counts are practice only)."
    or "Awards shared with the raid and saved to the ledger.")
  col.preview = false
  S.ShowDraw(col)
end

-- raiders receive a screen
local rx = {}
local function Assemble(key)
  local st = rx[key]
  if not st or st.done then return end
  st.done = true
  local picks, extra = {}, {}
  for i = 1, st.count do
    local e = st.entries[i]
    local d = e and BYCODE[e.code]
    if d then
      local item = { code = e.code, name = e.name, class = e.class ~= "" and e.class or nil, val = e.val, kind = d.kind,
        award = d.name, flavor = d.flavor, text = d.text(e.val) }
      if #picks < 5 then picks[#picks + 1] = item else extra[#extra + 1] = item end
    end
  end
  if #picks < 1 then return end
  local screen = { title = st.title, summary = SummaryLine(st.bosses, st.secs, st.wipes, st.deaths), picks = picks, extra = extra, sid = st.sid }
  Remember(screen)
  if D.settings and D.settings.podiumShow == false then
    Print("The raid awards are ready: /dkp podium")
  elseif D.Podium and D.Podium.Show then
    D.Podium.Show(screen)
  end
end

D.handlers.XH = function(p, sender, channel)
  if channel ~= "RAID" or not D.IsAdmin(sender) or D.SameName(sender, D.Me()) then return end
  local key = (p[2] or "") .. ":" .. (p[3] or "")
  rx[key] = { sid = p[2], count = tonumber(p[4]) or 0, title = p[5], bosses = tonumber(p[6]) or 0, secs = tonumber(p[7]) or 0,
    wipes = tonumber(p[8]) or 0, deaths = tonumber(p[9]) or 0, entries = {}, got = 0 }
  C_Timer.After(4, function() Assemble(key) end)
end

D.handlers.XE = function(p, sender, channel)
  if channel ~= "RAID" or not D.IsAdmin(sender) then return end
  local key = (p[2] or "") .. ":" .. (p[3] or "")
  local st = rx[key]
  if not st or st.done then return end
  local i = tonumber(p[4])
  if not i then return end
  st.entries[i] = { code = p[5], name = p[6], class = p[7] or "", val = tonumber(p[8]) or 0 }
  st.got = st.got + 1
  if st.got >= st.count then Assemble(key) end
end

---------------------------------------------------------------------------
-- Profile numbers (used by UI.lua's player card)
---------------------------------------------------------------------------
function D.PodiumAwardCounts(name)
  local a = D.data and D.data.awards
  local t = a and a[D.Pool(name)]
  if not t then return {} end
  local roasts = D.PodiumRoastsOn()
  local out = {}
  for code, n in pairs(t) do
    local kind = D.AwardKind(code)
    if roasts or kind ~= "roast" then
      out[#out + 1] = { code = code, name = D.PodiumAwardName(code), n = n, kind = kind, order = ORDER[code] or 99 }
    end
  end
  -- v1.6.0: good awards first, then roasts; most-won first inside each
  table.sort(out, function(x, y)
    if x.kind ~= y.kind then return x.kind ~= "roast" end
    if x.n ~= y.n then return x.n > y.n end
    return x.order < y.order
  end)
  return out
end

-- v1.6.0: a row of award icons with a gold "x3" after any won more than once.
-- max = how many to show; the rest become "+N".
function D.PodiumAwardStrip(name, size, max)
  local list = D.PodiumAwardCounts(name)
  if #list == 0 then return "" end
  max = max or #list
  local parts = {}
  for i = 1, math.min(#list, max) do
    local e = list[i]
    parts[#parts + 1] = D.AwardInline(e.code, size or 18) .. (e.n > 1 and ("|c" .. COUNT_HEX .. "x" .. e.n .. "|r") or "")
  end
  local s = table.concat(parts, "  ")
  if #list > max then s = s .. ("  |cffa7afba+%d|r"):format(#list - max) end
  return s
end

-- v1.6.0: hover list of everything a player has won
function D.ShowPodiumAwardTip(owner, name)
  if not owner or not name then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine((D.FirstName and D.FirstName(name) or name) .. "  ·  podium awards", 1, 1, 1)
  local list = D.PodiumAwardCounts(name)
  if #list == 0 then
    GameTooltip:AddLine("None yet. Raid awards are shared by an officer at End raid.", 0.65, 0.69, 0.73, true)
  end
  for _, e in ipairs(list) do
    local r, g, b = D.AwardColor(e.code)
    GameTooltip:AddDoubleLine(D.AwardInline(e.code, 16) .. " " .. e.name .. (e.kind == "roast" and "  (roast)" or ""),
      "x" .. e.n, r, g, b, 0.88, 0.69, 0.31)
  end
  GameTooltip:Show()
end

-- v1.6.0: the Hall of Fame "Awards" view. Returns the 16 awards in DEFS order, each { code, def, total, best,
-- who = {pools holding the record} }, plus { decorated = {pool, n}, roasted = {pool, n} } (most awards / most
-- roasts). Players removed from Standings are skipped, like in the other records.
function D.PodiumAwardLeaders()
  local rows, by = {}, {}
  for i, d in ipairs(DEFS) do rows[i] = { code = d.code, def = d, total = 0, best = 0, who = {} }; by[d.code] = rows[i] end
  local hidden = D.data and D.data.hidden or {}
  local good, bad = {}, {}
  for pool, t in pairs(D.data and D.data.awards or {}) do
    if not hidden[pool] then
      for code, n in pairs(t) do
        local o = by[code]
        if o and n > 0 then
          o.total = o.total + n
          if n > o.best then o.best = n; o.who = { pool } elseif n == o.best then o.who[#o.who + 1] = pool end
          local bucket = o.def.kind == "roast" and bad or good
          bucket[pool] = (bucket[pool] or 0) + n
        end
      end
    end
  end
  for _, o in ipairs(rows) do table.sort(o.who) end
  local function Top(bucket)
    local best
    for pool, n in pairs(bucket) do
      if not best or n > best[2] or (n == best[2] and pool < best[1]) then best = { pool, n } end
    end
    return best
  end
  return rows, { decorated = Top(good), roasted = Top(bad) }
end

function D.PodiumAwardLine(name, max)
  local list = D.PodiumAwardCounts(name)
  if #list == 0 then return "|cffa7afbaNone yet|r" end
  local parts = {}
  for i = 1, math.min(#list, max or 3) do parts[#parts + 1] = ("%s x%d"):format(list[i].name, list[i].n) end
  local s = table.concat(parts, ", ")
  if #list > (max or 3) then s = s .. (" |cffa7afba(+%d more)|r"):format(#list - (max or 3)) end
  return s
end

---------------------------------------------------------------------------
-- Test data: a fake raid, so the screen can be tried without a raid
---------------------------------------------------------------------------
local FALLBACK_NAMES = { "Stonegut", "Ashwen", "Lumenrae", "Dalorrian", "Vordus", "Fenra", "Brizul", "Jorwen", "Thalok", "Kaelthrandor",
  "Pyrelle", "Grimtusk", "Vexxa", "Oakhollow", "Mirelle", "Torvan", "Sylvara", "Bruknar", "Ellisandra", "Gorvak", "Nimue", "Halvard",
  "Zephyra", "Dunmar", "Ysolde" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

function S.TestData(count, seed)
  count = count or 25
  local r = MakeRng("test" .. (seed or (GetServerTime() .. math.random())))
  local pool = {}
  if D.roster then
    for n, x in pairs(D.roster) do pool[#pool + 1] = { name = Short(n), class = x.class } end
    table.sort(pool, function(a, b) return a.name < b.name end)
  end
  local names = {}
  local used = {}
  local guard = 0
  while #names < count and guard < 2000 do
    guard = guard + 1
    local pick
    if #pool > 0 and r() < 0.9 then
      local c = pool[math.floor(r() * #pool) + 1]
      if not used[c.name] then pick = { name = c.name, class = c.class } end
    else
      local n = FALLBACK_NAMES[math.floor(r() * #FALLBACK_NAMES) + 1]
      if not used[n] then pick = { name = n } end
    end
    if pick then used[pick.name] = true; names[#names + 1] = pick end
    if #names >= count or (#pool == 0 and #names >= #FALLBACK_NAMES) then break end
  end
  local players, ctx = {}, { items = {}, spent = {}, prepared = {}, late = {}, bosses = 9 }
  for i, n in ipairs(names) do
    local class = n.class or CLASSES[math.floor(r() * #CLASSES) + 1]
    local role = "D"
    if i <= 2 then class = (i == 1) and "WARRIOR" or "PALADIN"; role = "T"
    elseif i <= 7 then class = (i % 2 == 0) and "PRIEST" or "SHAMAN"; role = "H" end
    local dpsBase = 600000 + r() * 2600000
    local p = { name = n.name, class = class, role = role,
      dmg = role == "D" and dpsBase * 1.4 or dpsBase * 0.2, bossDmg = role == "D" and dpsBase or dpsBase * 0.1,
      trashDmg = role == "D" and dpsBase * 0.4 or dpsBase * 0.1, heal = role == "H" and (1500000 + r() * 4000000) or 0,
      taken = role == "T" and (2500000 + r() * 2000000) or ((200000 + r() * 900000) * (r() < 0.15 and 2.4 or 1)),
      deaths = r() < 0.55 and math.floor(r() * 4) or 0, ints = CAN_INT[class] and math.floor(r() * 9) or 0,
      disp = (class == "PRIEST" or class == "PALADIN" or class == "SHAMAN" or class == "MAGE") and math.floor(r() * 12) or 0 }
    players[#players + 1] = p
    if r() < 0.25 then ctx.items[p.name] = 1 + math.floor(r() * 3); ctx.spent[p.name] = ctx.items[p.name] * (20 + math.floor(r() * 90)) end
    if r() < 0.1 then ctx.prepared[p.name] = 3 + math.floor(r() * 5) end
    if r() < 0.06 then ctx.late[p.name] = 19 * 60 + 12 + math.floor(r() * 25) end
  end
  return players, ctx
end

function S.Test(count)
  local players, ctx = S.TestData(count)
  local col = { sid = "TEST" .. GetServerTime(), title = "Test Raid", players = players, ctx = ctx, reroll = 0, test = true, demo = true,
    bosses = 9, secs = 4080, wipes = 2, preview = false }
  -- in practice mode the share button writes to the practice ledger so the profile cards can be tried
  if D.practice then
    col.canPost = true
    col.preview = true
    col.ses = { id = col.sid, title = col.title }
    col.test = false
  end
  S.ShowDraw(col)
end

---------------------------------------------------------------------------
-- /dkp podium ...
---------------------------------------------------------------------------
function D.PodiumSlash(rest)
  local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  sub = (sub or ""):lower()
  if sub == "" then
    D.Podium.OpenSaved(1)
  elseif sub == "history" then
    D.Podium.OpenSaved(tonumber(arg) or 1)
  elseif sub == "test" then
    S.Test(tonumber(arg))
  elseif sub == "end" then
    if not D.IsAdmin() and not D.practice then Print("Only officers can run the awards.") return end
    S.Redo()
  elseif sub == "reset" then
    S.Reset()
    Print("Your stats for tonight were cleared.")
  elseif sub == "status" then
    local r = S.MyRecord()
    Print(("Podium stats since %s: damage %s (boss %s, trash %s), healing %s, taken %s, deaths %d, interrupts %d, dispels %d. Counting: %s."):format(
      date("%H:%M", cur and cur.t0 or GetServerTime()), Big(r.dmg), Big(r.bossDmg), Big(r.trashDmg), Big(r.heal), Big(r.taken),
      r.deaths, r.ints, r.disp, cleuOn and "yes (in a raid)" or "no (only inside a raid instance)"))
  elseif sub == "roasts" then
    if arg == "on" or arg == "off" then
      if D.SetConfig then D.SetConfig("PODIUM_ROASTS", arg == "on" and 1 or 0) end
      Print("Roast awards " .. (arg == "on" and "on." or "off.") .. " (guild setting, GM only)")
    else
      Print("Roast awards are " .. (tonumber(D.Cfg("PODIUM_ROASTS")) ~= 0 and "on" or "off") .. ". /dkp podium roasts on|off (GM)")
    end
  elseif sub == "auto" then
    if arg == "on" or arg == "off" then
      if D.SetConfig then D.SetConfig("PODIUM_ON", arg == "on" and 1 or 0) end
      Print("Awards at End raid " .. (arg == "on" and "on." or "off.") .. " (guild setting, GM only)")
    else
      Print("Awards at End raid are " .. (tonumber(D.Cfg("PODIUM_ON")) ~= 0 and "on" or "off") .. ". /dkp podium auto on|off (GM)")
    end
  elseif sub == "show" then
    D.settings.podiumShow = not (arg == "off")
    Print("Showing the awards screen when an officer shares it: " .. (D.settings.podiumShow and "on" or "off"))
  elseif sub == "anim" or sub == "anims" or sub == "cam" then
    D.Podium.Tune(sub, arg)
  else
    Print("/dkp podium  |  history [n]  |  test [players]  |  end (officer: run the awards again)  |  status  |  reset  |  show on|off  |  roasts on|off (GM)  |  auto on|off (GM)  |  anim <id>  |  anims <head|pos|roast> <ids>  |  cam <scale> <height>")
  end
end

-- start counting if I'm already in a raid when the add-on loads
C_Timer.After(5, function() if D.db then S.Update() end end)
