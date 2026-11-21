local ADDON, D = ...

--[[
  v1.4.1 STATS PROBE (temporary, read-only)

  Purpose: find out, on a real client, what stats data the next release
  (end-of-raid awards) can use. It changes NOTHING: no ledger events, no sync,
  no settings. It only looks and reports.

    /dkp stats          run the report (starts the combat-log listener the first time)
    /dkp stats reset    clear the listener's counters
    /dkp stats stop     stop the listener

  The report opens in a window with the text already selected: press Ctrl+C,
  then paste it into the chat with Claude.

  What it checks: client + build, the game's own damage meter (C_DamageMeter),
  Details (version, segments, which fields a player's record has, whether
  everyone in the group shows up), Skada, whether this add-on may listen to the
  combat log at all, and whether 3D models + animations can be created.
]]

local P = {}
D.Probe = P

local lines

local function L(fmt, ...)
  local ok, s = pcall(string.format, fmt, ...)
  lines[#lines + 1] = ok and s or tostring(fmt)
end

local function N(x)
  x = tonumber(x) or 0
  local s = tostring(math.floor(x + 0.5))
  local k
  repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
  return s
end

local function Short(n) return n and (tostring(n):gsub("%-.*$", "")) end

local function Section(title)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "=== " .. title .. " ==="
end

local function Guard(title, fn)
  local ok, err = pcall(fn)
  if not ok then L("  (error in %s: %s)", title, tostring(err)) end
end

-- readable dump of a table's plain fields (numbers / short strings / booleans)
local function Fields(t, max)
  local keys = {}
  for k, v in pairs(t) do
    local tv = type(v)
    if type(k) == "string" and (tv == "number" or tv == "string" or tv == "boolean") then keys[#keys + 1] = k end
  end
  table.sort(keys)
  local parts = {}
  for i = 1, math.min(#keys, max or 40) do
    local v = t[keys[i]]
    if issecretvalue and issecretvalue(v) then v = "<secret>"
    elseif type(v) == "number" then v = N(v) elseif type(v) == "string" then v = v:sub(1, 24) else v = tostring(v) end
    parts[#parts + 1] = keys[i] .. "=" .. v
  end
  if #keys > (max or 40) then parts[#parts + 1] = ("... +%d more"):format(#keys - (max or 40)) end
  return table.concat(parts, ", ")
end

local function TableKeys(t, max)
  local keys = {}
  for k, v in pairs(t) do
    if type(k) == "string" and type(v) == "table" then keys[#keys + 1] = k end
  end
  table.sort(keys)
  if #keys > (max or 30) then
    local extra = #keys - (max or 30)
    for i = #keys, (max or 30) + 1, -1 do keys[i] = nil end
    keys[#keys + 1] = "+" .. extra .. " more"
  end
  return table.concat(keys, ", ")
end

---------------------------------------------------------------------------
-- Group roster (GUID -> name), used by the combat-log listener and the
-- "is everyone in Details?" test
---------------------------------------------------------------------------
local guidName, petOwner = {}, {}
local function RefreshGUIDs()
  wipe(guidName); wipe(petOwner)
  local function add(unit)
    if UnitExists(unit) then
      local g = UnitGUID(unit)
      local n = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
      if g and n then guidName[g] = n end
      local pu = unit == "player" and "pet" or (unit .. "pet")
      if UnitExists(pu) then
        local pg = UnitGUID(pu)
        if pg and n then petOwner[pg] = n end
      end
    end
  end
  add("player")
  if IsInRaid and IsInRaid() then
    for i = 1, GetNumGroupMembers() do add("raid" .. i) end
  else
    for i = 1, 4 do add("party" .. i) end
  end
end

local function GroupNames()
  local out, seen = {}, {}
  for _, n in pairs(guidName) do
    local s = Short(n)
    if not seen[s] then seen[s] = true; out[#out + 1] = s end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------
-- Combat-log listener (our own counting, group members + their pets only)
---------------------------------------------------------------------------
local cleu = { on = false }
local function ResetCleu()
  cleu.total, cleu.group, cleu.since = 0, 0, time()
  cleu.dmg, cleu.heal, cleu.ints, cleu.disp, cleu.deaths, cleu.seen = {}, {}, {}, {}, {}, {}
  cleu.forbidden = cleu.forbidden or {}
end
ResetCleu()

local DMG = { SPELL_DAMAGE = true, RANGE_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, DAMAGE_SHIELD = true }
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function Add(t, k, v) t[k] = (t[k] or 0) + v end

local function OnCLEU()
  cleu.total = cleu.total + 1
  local ts, sub, hide, sg, sn, sf, srf, dg, dn, df, drf, a12, a13, a14, a15, a16 = CombatLogGetCurrentEventInfo()
  local owner = guidName[sg] or petOwner[sg]
  if owner then
    cleu.group = cleu.group + 1
    cleu.seen[Short(owner)] = true
    if sub == "SWING_DAMAGE" then
      Add(cleu.dmg, Short(owner), tonumber(a12) or 0)
    elseif DMG[sub] then
      Add(cleu.dmg, Short(owner), tonumber(a15) or 0)
    elseif HEAL[sub] then
      Add(cleu.heal, Short(owner), math.max(0, (tonumber(a15) or 0) - (tonumber(a16) or 0)))
    elseif sub == "SPELL_INTERRUPT" then
      Add(cleu.ints, Short(owner), 1)
    elseif sub == "SPELL_DISPEL" then
      Add(cleu.disp, Short(owner), 1)
    end
  end
  if sub == "UNIT_DIED" and guidName[dg] then
    Add(cleu.deaths, Short(guidName[dg]), 1)
    cleu.seen[Short(guidName[dg])] = true
  end
end

local function StartCleu()
  if cleu.on then return true end
  if not cleu.frame then
    cleu.frame = CreateFrame("Frame")
    cleu.frame:SetScript("OnEvent", function(_, event, a1, a2)
      if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local ok, err = pcall(OnCLEU)
        if not ok and not cleu.err then cleu.err = tostring(err) end
      elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        RefreshGUIDs()
      elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        if a1 == ADDON then cleu.forbidden[#cleu.forbidden + 1] = event .. ": " .. tostring(a2) end
      end
    end)
  end
  RefreshGUIDs()
  cleu.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  cleu.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(cleu.frame.RegisterEvent, cleu.frame, "ADDON_ACTION_FORBIDDEN")
  pcall(cleu.frame.RegisterEvent, cleu.frame, "ADDON_ACTION_BLOCKED")
  local ok, err = pcall(cleu.frame.RegisterEvent, cleu.frame, "COMBAT_LOG_EVENT_UNFILTERED")
  cleu.regOk, cleu.regErr = ok, err
  cleu.on = ok
  return ok
end

local function StopCleu()
  if cleu.frame then cleu.frame:UnregisterAllEvents() end
  cleu.on = false
end

---------------------------------------------------------------------------
-- Report sections
---------------------------------------------------------------------------
local function ClientSection()
  Section("CLIENT")
  local v, b, d, toc = GetBuildInfo()
  L("Game %s build %s (%s), interface %s", tostring(v), tostring(b), tostring(d), tostring(toc))
  L("WOW_PROJECT_ID=%s  GetExpansionLevel=%s", tostring(WOW_PROJECT_ID), GetExpansionLevel and tostring(GetExpansionLevel()) or "n/a")
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  L("Guild Ladder DKP version: %s", get and tostring(get(ADDON, "Version")) or "?")
  L("Faction: %s   Realm: %s", tostring(UnitFactionGroup("player")), tostring(GetRealmName and GetRealmName()))
  L("In group: %s   raid: %s   members: %s",
    tostring(IsInGroup and IsInGroup()), tostring(IsInRaid and IsInRaid()), tostring(GetNumGroupMembers and GetNumGroupMembers() or 0))
end

local function BuiltinSection()
  Section("BUILT-IN DAMAGE METER (C_DamageMeter)")
  if type(C_DamageMeter) ~= "table" then
    L("C_DamageMeter: NOT present")
    return
  end
  local names = {}
  for k, v in pairs(C_DamageMeter) do names[#names + 1] = k .. (type(v) == "function" and "()" or "") end
  table.sort(names)
  L("C_DamageMeter: PRESENT. Members: %s", table.concat(names, ", "))
  if Enum and Enum.DamageMeterType then
    local e = {}
    for k, v in pairs(Enum.DamageMeterType) do e[#e + 1] = k .. "=" .. tostring(v) end
    table.sort(e)
    L("Enum.DamageMeterType: %s", table.concat(e, ", "))
  end
  if C_DamageMeter.IsDamageMeterAvailable then
    local ok, a, b = pcall(C_DamageMeter.IsDamageMeterAvailable)
    L("IsDamageMeterAvailable: %s %s %s", tostring(ok), tostring(a), tostring(b))
  end
end


-- v1.4.2: a close look at the game's own meter (Blizzard C_DamageMeter)
local function Safe(v)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  return v
end
local function SafeN(v)
  v = Safe(v)
  if type(v) == "number" then return N(v) end
  return tostring(v)
end
local function SortedEnum(e)
  local out = {}
  if type(e) == "table" then for k, v in pairs(e) do out[#out + 1] = { k = k, v = v } end end
  table.sort(out, function(a, b) return tostring(a.v) < tostring(b.v) end)
  return out
end

local function MeterDeep()
  Section("BUILT-IN METER, DEEP LOOK")
  local M = _G.C_DamageMeter
  if type(M) ~= "table" then L("C_DamageMeter not present."); return end
  local cv
  pcall(function() cv = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("damageMeterEnabled") end)
  L("CVar damageMeterEnabled = %s | issecretvalue() exists: %s | in instance: %s",
    tostring(cv), tostring(type(issecretvalue) == "function"), tostring((select(2, IsInInstance()))))
  local sess = SortedEnum(Enum and Enum.DamageMeterSessionType)
  local parts = {}
  for _, e in ipairs(sess) do parts[#parts + 1] = e.k .. "=" .. tostring(e.v) end
  L("Enum.DamageMeterSessionType: %s", #parts > 0 and table.concat(parts, ", ") or "missing")

  local ok, list = pcall(M.GetAvailableCombatSessions)
  if ok and type(list) == "table" then
    L("Available sessions: %d", #list)
    for i = 1, math.min(#list, 8) do L("  #%d: %s", i, type(list[i]) == "table" and Fields(list[i], 12) or tostring(list[i])) end
  else
    L("GetAvailableCombatSessions failed: %s", tostring(list))
  end
  for _, e in ipairs(sess) do
    local ok2, d = pcall(M.GetSessionDurationSeconds, e.v)
    L("Duration of session %s: %s", e.k, ok2 and SafeN(d) or ("error " .. tostring(d)))
  end

  local metrics = { "DamageDone", "HealingDone", "DamageTaken", "Interrupts", "Dispels", "Deaths", "Absorbs", "AvoidableDamageTaken" }
  local gnames = GroupNames()
  local me = Short(UnitName("player"))
  for _, e in ipairs(sess) do
    L("")
    L("-- session %s --", e.k)
    for mi, mname in ipairs(metrics) do
      local mval = Enum.DamageMeterType and Enum.DamageMeterType[mname]
      if mval ~= nil then
        local okc, sdata = pcall(M.GetCombatSessionFromType, e.v, mval)
        if not okc then
          L("[%s] error: %s", mname, tostring(sdata))
        elseif type(sdata) ~= "table" then
          L("[%s] returned %s", mname, tostring(sdata))
        else
          local src = sdata.combatSources
          local n = type(src) == "table" and #src or 0
          local top = {}
          for i = 1, math.min(n, 4) do
            local r = src[i]
            if type(r) == "table" then top[#top + 1] = ("%s %s"):format(tostring(Safe(r.name)), SafeN(r.totalAmount)) end
          end
          L("[%s] sources=%d | top: %s", mname, n, #top > 0 and table.concat(top, "; ") or "-")
          if mi == 1 then
            L("   session fields: %s", Fields(sdata, 20))
            L("   session sub-tables: %s", TableKeys(sdata))
            if n > 0 and type(src[1]) == "table" then
              L("   source #1 fields: %s", Fields(src[1], 30))
              L("   source #1 sub-tables: %s", TableKeys(src[1]))
            end
            -- coverage of the group
            if #gnames > 1 then
              local have = {}
              for i = 1, n do
                local r = src[i]
                if type(r) == "table" and not (issecretvalue and issecretvalue(r.name)) and r.name then have[Short(r.name)] = true end
              end
              local missing = {}
              for _, g in ipairs(gnames) do if not have[g] then missing[#missing + 1] = g end end
              L("   GROUP COVERAGE: %d of %d group members present%s", #gnames - #missing, #gnames,
                #missing > 0 and (". Missing: " .. table.concat(missing, ", ")) or ".")
            end
            -- my own number vs the add-on's own count
            for i = 1, n do
              local r = src[i]
              if type(r) == "table" and not (issecretvalue and issecretvalue(r.name)) and r.name and Short(r.name) == me then
                L("   MY TOTAL: meter %s | this add-on's own count %s (counting since %s)", SafeN(r.totalAmount), N(cleu.dmg[me]),
                  date("%H:%M:%S", cleu.since))
              end
            end
            -- per-source detail (spell breakdown) for the first source
            if n > 0 and type(src[1]) == "table" then
              local guid
              for k, v in pairs(src[1]) do
                if type(v) == "string" and not (issecretvalue and issecretvalue(v)) and v:match("^Player%-") then guid = v end
              end
              if guid then
                local okd, det = pcall(M.GetCombatSessionSourceFromType, e.v, mval, guid)
                if okd and type(det) == "table" then
                  L("   source detail fields: %s", Fields(det, 20))
                  for k, v in pairs(det) do
                    if type(v) == "table" then
                      L("   source detail '%s': %d entries; first: %s", tostring(k), #v, type(v[1]) == "table" and Fields(v[1], 16) or tostring(v[1]))
                    end
                  end
                else
                  L("   source detail failed: %s", tostring(det))
                end
              else
                L("   (no player GUID field found on source #1)")
              end
            end
          end
        end
      end
    end
  end
end

local function MeterAddonsSection()
  Section("METER ADDONS LOADED")
  L("Details: %s   Skada: %s   Recount: %s   ElvUI: %s",
    _G.Details and "YES" or "no", _G.Skada and "YES" or "no", _G.Recount and "YES" or "no", _G.ElvUI and "YES" or "no")
end

-- one Details segment -> readable line(s); returns damage actors (list) for reuse
local function Actors(cont)
  local out = {}
  if not cont then return out end
  pcall(function() for _, a in cont:ListActors() do out[#out + 1] = a end end)
  if #out == 0 then pcall(function() for _, a in ipairs(cont._ActorTable or {}) do out[#out + 1] = a end end) end
  return out
end
local function ActorName(a) return a.nome or a.name end

local function DetailsSection()
  Section("DETAILS")
  local Dt = _G.Details
  if not Dt then L("Details is not loaded."); return end
  L("Details loaded. userversion=%s  version=%s  build_counter=%s", tostring(Dt.userversion), tostring(Dt.version), tostring(Dt.build_counter))
  local fns = {}
  for _, n in ipairs({ "GetCurrentCombat", "GetCombat", "GetActor", "GetOverallCombat", "GetCombatSegments", "GetDamageDone", "GetPlayer" }) do
    fns[#fns + 1] = n .. "=" .. (type(Dt[n]) == "function" and "yes" or "no")
  end
  L("Functions: %s", table.concat(fns, " "))
  local consts = {}
  for _, n in ipairs({ "DETAILS_ATTRIBUTE_DAMAGE", "DETAILS_ATTRIBUTE_HEAL", "DETAILS_ATTRIBUTE_MISC", "DETAILS_SUBATTRIBUTE_INTERRUPT",
    "DETAILS_SUBATTRIBUTE_DISPELL", "DETAILS_SUBATTRIBUTE_DEATH", "DETAILS_SEGMENTID_OVERALL", "DETAILS_SEGMENTID_CURRENT" }) do
    consts[#consts + 1] = n:gsub("^DETAILS_", "") .. "=" .. tostring(_G[n])
  end
  L("Constants: %s", table.concat(consts, " "))
  L("Segments kept: %s | overall resets - on new boss: %s, on new challenge: %s, on logout: %s",
    tostring(Dt.segments_amount), tostring(Dt.overall_clear_newboss), tostring(Dt.overall_clear_newchallenge), tostring(Dt.overall_clear_logout))

  local function Seg(i)
    local ok, c = pcall(Dt.GetCombat, Dt, i)
    if ok and type(c) == "table" then return c end
  end

  -- find segments: overall (-1), current (0), then 1..
  local list = {}
  local ov = _G.DETAILS_SEGMENTID_OVERALL or -1
  local c = Seg(ov); if c then list[#list + 1] = { id = ov, label = "overall", c = c } end
  c = Seg(0); if c then list[#list + 1] = { id = 0, label = "current", c = c } end
  for i = 1, 25 do
    c = Seg(i)
    if not c then break end
    list[#list + 1] = { id = i, label = "history " .. i, c = c }
  end
  L("Segments found: %d", #list)

  local gnames = GroupNames()
  local groupSet = {}
  for _, n in ipairs(gnames) do groupSet[n] = true end

  local best -- the segment used for the "is everyone there?" test
  for _, s in ipairs(list) do
    Guard("segment " .. s.label, function()
      local cb = s.c
      local boss = cb.is_boss
      local bossName = type(boss) == "table" and (boss.name or boss.encounter or boss.index) or nil
      local ctime
      pcall(function() ctime = cb:GetCombatTime() end)
      local dmg = Actors(select(2, pcall(cb.GetContainer, cb, _G.DETAILS_ATTRIBUTE_DAMAGE or 1)))
      local rows, groupCount = {}, 0
      for _, a in ipairs(dmg) do
        if a.grupo then groupCount = groupCount + 1 end
        if a.grupo and (a.total or 0) > 0 then rows[#rows + 1] = a end
      end
      table.sort(rows, function(x, y) return (x.total or 0) > (y.total or 0) end)
      local top = {}
      for i = 1, math.min(3, #rows) do top[#top + 1] = ("%s %s"):format(Short(ActorName(rows[i])) or "?", N(rows[i].total)) end
      L("[%s] boss=%s trash=%s time=%ss | damage actors=%d (group-flagged=%d) | top: %s",
        s.label, tostring(bossName), tostring(cb.is_trash), tostring(ctime and math.floor(ctime) or "?"),
        #dmg, groupCount, #top > 0 and table.concat(top, "; ") or "-")
      if (s.label == "overall" or not best) and #rows > 0 then best = { s = s, rows = rows, dmg = dmg } end
      if s.label == "overall" and #rows > 0 then best = { s = s, rows = rows, dmg = dmg } end
    end)
  end

  if not best then
    L("No segment with group damage yet. Fight something (a dummy works), then run /dkp stats again.")
    return
  end
  P.detailsTotals = {}
  for _, a in ipairs(best.dmg) do
    if a.grupo and ActorName(a) then P.detailsTotals[Short(ActorName(a))] = a.total or 0 end
  end

  -- field dumps from a real player record
  Guard("damage actor fields", function()
    local a = best.rows[1]
    L("")
    L("Damage record fields (%s, from %s): %s", Short(ActorName(a)), best.s.label, Fields(a, 60))
    L("  sub-tables: %s", TableKeys(a))
  end)
  Guard("healing", function()
    local cont = select(2, pcall(best.s.c.GetContainer, best.s.c, _G.DETAILS_ATTRIBUTE_HEAL or 2))
    local acts = Actors(cont)
    local rows = {}
    for _, a in ipairs(acts) do if a.grupo and (a.total or 0) > 0 then rows[#rows + 1] = a end end
    table.sort(rows, function(x, y) return (x.total or 0) > (y.total or 0) end)
    if #rows > 0 then
      L("Healing: %d group healers. Top: %s %s. Fields: %s", #rows, Short(ActorName(rows[1])), N(rows[1].total), Fields(rows[1], 40))
    else
      L("Healing: no group healer records in this segment.")
    end
  end)
  Guard("misc", function()
    local cont = select(2, pcall(best.s.c.GetContainer, best.s.c, _G.DETAILS_ATTRIBUTE_MISC or 4))
    local acts = Actors(cont)
    local withInt, withDisp, shown = 0, 0, false
    for _, a in ipairs(acts) do
      if a.grupo then
        if (a.interrupt or 0) > 0 then withInt = withInt + 1 end
        if (a.dispell or 0) > 0 then withDisp = withDisp + 1 end
        if not shown and (a.interrupt or a.dispell or a.cc_break) then
          L("Misc record fields (%s): %s", Short(ActorName(a)) or "?", Fields(a, 40))
          shown = true
        end
      end
    end
    L("Misc: %d records; group players with interrupts: %d, with dispels: %d", #acts, withInt, withDisp)
    pcall(function()
      local cb = best.s.c
      local deaths = (type(cb.GetCombatDeaths) == "function" and cb:GetCombatDeaths()) or cb.last_events_tables
      L("Deaths data: %s", type(deaths) == "table" and ("table with " .. #deaths .. " entries") or tostring(deaths))
    end)
  end)

  -- the range test
  Guard("range test", function()
    if #gnames <= 1 then
      L("Range test: needs a group (run it again in a party or raid after a fight).")
      return
    end
    local present, missing = 0, {}
    local have = {}
    for _, a in ipairs(best.dmg) do if ActorName(a) then have[Short(ActorName(a))] = a.total or 0 end end
    for _, n in ipairs(gnames) do
      if have[n] and have[n] > 0 then present = present + 1 else missing[#missing + 1] = n end
    end
    L("RANGE TEST (%s): %d of %d group members have damage in Details%s", best.s.label, present, #gnames,
      #missing > 0 and (". Missing: " .. table.concat(missing, ", ")) or ".")
  end)
end

local function SkadaSection()
  Section("SKADA")
  local Sk = _G.Skada
  if not Sk then L("Skada is not loaded."); return end
  L("Skada loaded. version=%s", tostring(Sk.version or Sk.revision))
  local sets = Sk.char and Sk.char.sets
  L("Saved sets: %s", type(sets) == "table" and tostring(#sets) or "n/a")
  for _, key in ipairs({ "current", "total" }) do
    Guard("skada " .. key, function()
      local set = Sk[key]
      if type(set) ~= "table" then L("Skada.%s: none", key); return end
      local np = type(set.players) == "table" and #set.players or 0
      L("Skada.%s: set fields: %s | players=%d", key, Fields(set, 20), np)
      if np > 0 then L("  first player: %s", Fields(set.players[1], 40)) end
    end)
  end
end

local function CleuSection()
  Section("COMBAT LOG LISTENER (this add-on counting its own)")
  L("Listener running: %s | register ok: %s%s", tostring(cleu.on), tostring(cleu.regOk),
    cleu.regErr and (" | " .. tostring(cleu.regErr)) or "")
  if cleu.frame then
    local ok, reg = pcall(cleu.frame.IsEventRegistered, cleu.frame, "COMBAT_LOG_EVENT_UNFILTERED")
    L("IsEventRegistered(COMBAT_LOG_EVENT_UNFILTERED): %s", ok and tostring(reg) or "error")
  end
  L("Blocked-action messages about this add-on: %s", #cleu.forbidden > 0 and table.concat(cleu.forbidden, " | ") or "none")
  if cleu.err then L("First handler error: %s", cleu.err) end
  L("Counting since %s: %s events total, %s from my group (+pets)", date("%H:%M:%S", cleu.since), N(cleu.total), N(cleu.group))

  local gnames = GroupNames()
  local seen, missing = 0, {}
  for _, n in ipairs(gnames) do if cleu.seen[n] then seen = seen + 1 else missing[#missing + 1] = n end end
  L("Group members seen in the log: %d of %d%s", seen, #gnames, #missing > 0 and (". Not seen: " .. table.concat(missing, ", ")) or "")

  local rows = {}
  for n, v in pairs(cleu.dmg) do rows[#rows + 1] = { n = n, v = v } end
  table.sort(rows, function(a, b) return a.v > b.v end)
  for i = 1, math.min(8, #rows) do
    local n = rows[i].n
    local det = P.detailsTotals and P.detailsTotals[n]
    L("  %-14s dmg %s | heal %s | int %s | disp %s | died %s%s", n, N(rows[i].v), N(cleu.heal[n]), N(cleu.ints[n]), N(cleu.disp[n]),
      N(cleu.deaths[n]), det and (" | Details dmg " .. N(det)) or "")
  end
  L("(To compare fairly: /dkp stats reset AND /details reset before the fight, then run the report right after.)")
end

local function ModelSection()
  Section("3D MODELS (for the podium)")
  if not P.model then
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
    if ok and m then m:Hide(); P.model = m else P.modelErr = tostring(m) end
  end
  local m = P.model
  if not m then L("Could not create a PlayerModel: %s", tostring(P.modelErr)); return end
  local have = {}
  for _, n in ipairs({ "SetUnit", "SetAnimation", "SetCamDistanceScale", "SetPortraitZoom", "SetPosition", "SetFacing", "SetModelScale",
    "ClearModel", "SetRotation", "SetCamera", "SetCustomCamera", "SetModel", "GetModelFileID" }) do
    have[#have + 1] = n .. "=" .. (type(m[n]) == "function" and "yes" or "no")
  end
  L("PlayerModel created. Methods: %s", table.concat(have, " "))
  L("SetUnit('player'): %s   SetAnimation(0): %s", tostring((pcall(m.SetUnit, m, "player"))),
    m.SetAnimation and tostring((pcall(m.SetAnimation, m, 0))) or "n/a")
  L("DressUpModel template: %s   ModelScene: %s", type(_G.DressUpModelFrameMixin) ~= "nil" and "yes" or "n/a",
    type(_G.ModelSceneMixin) ~= "nil" and "yes" or "n/a")
end

---------------------------------------------------------------------------
-- Window with selectable text
---------------------------------------------------------------------------
local function Window()
  if P.win then return P.win end
  local f = CreateFrame("Frame", "GuildLadderDKPProbe", UIParent)
  f:SetSize(700, 480)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.93)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText("Guild Ladder DKP stats probe - the text is selected: press Ctrl+C, then paste it to Claude")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local again = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  again:SetSize(90, 22); again:SetPoint("TOPRIGHT", -34, -8); again:SetText("Run again")
  again:SetScript("OnClick", function() P.Run() end)
  local scroll = CreateFrame("ScrollFrame", "GuildLadderDKPProbeScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -38)
  scroll:SetPoint("BOTTOMRIGHT", -32, 12)
  local eb = CreateFrame("EditBox", nil, scroll)
  eb:SetMultiLine(true)
  eb:SetFontObject(ChatFontNormal)
  eb:SetWidth(640)
  eb:SetAutoFocus(false)
  pcall(eb.SetMaxLetters, eb, 0)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  scroll:SetScrollChild(eb)
  f.eb = eb
  tinsert(UISpecialFrames, "GuildLadderDKPProbe")
  P.win = f
  return f
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------
function P.Run()
  lines = {}
  L("GUILD LADDER DKP STATS PROBE   %s   (character %s)", date("%Y-%m-%d %H:%M:%S"), tostring(UnitName("player")))
  Guard("listener", function() StartCleu() end)
  Guard("client", ClientSection)
  Guard("builtin", BuiltinSection)
  Guard("meterdeep", MeterDeep)
  Guard("meters", MeterAddonsSection)
  P.detailsTotals = nil
  Guard("details", DetailsSection)
  Guard("skada", SkadaSection)
  Guard("cleu", CleuSection)
  Guard("models", ModelSection)
  local f = Window()
  f:Show()
  f.eb:SetText(table.concat(lines, "\n"))
  f.eb:SetCursorPosition(0)
  f.eb:SetFocus()
  f.eb:HighlightText()
end

function D.StatsSlash(rest)
  local sub = (rest or ""):lower():match("^(%S*)")
  if sub == "reset" then
    ResetCleu()
    D.Print("Stats probe counters cleared.")
  elseif sub == "stop" then
    StopCleu()
    D.Print("Stats probe listener stopped.")
  else
    local ok, err = pcall(P.Run)
    if not ok then D.Print("Stats probe failed: " .. tostring(err)) end
  end
end
