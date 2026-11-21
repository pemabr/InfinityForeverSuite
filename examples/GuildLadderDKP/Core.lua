local ADDON, D = ...
local C = D.Config
local SEP = "~"

--[[
  Guild Ladder DKP - core
  Same idea as Guild Ladder: every DKP change is an EVENT that every guild
  client stores and shares, and balances are worked out locally from the full
  history, so everyone agrees and nobody has to be online for it to work.

  Difference: the ledger is officer-only. Award / spend / adjust / decay / undo
  events only count if their author holds an officer rank on the live guild
  roster. Raiders only ever write their own wishlist.
]]

-- Filled in by UI.lua / Loot.lua
D.Refresh = function() end
D.Toast = function() end
D.handlers = {}       -- live message kinds -> function(parts, sender, channel)
D.roster = {}         -- guild roster: full name -> { rankIndex, class }
D.raid = {}           -- current raid: name -> { class, online, unit }
D.joinT = {}          -- raid session: name -> realm time first seen in the raid
D.ready = false

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
function D.Print(...) print("|cffe0b04fGuild Ladder DKP:|r", ...) end
local Print = D.Print

local function Secret(...)
  if not issecretvalue then return false end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return true end
  end
  return false
end
D.Secret = Secret

local function Pack(...)
  local t = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    t[i] = v == nil and "" or tostring(v)
  end
  return table.concat(t, SEP)
end
D.Pack = Pack

local function Clean(s, max)
  return (tostring(s or ""):gsub("[~|]", "")):sub(1, max or 60)
end
D.Clean = Clean

local function Copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = Copy(v) end
  return c
end
D.Copy = Copy

function D.Now() return GetServerTime() end

-- Item API: Forever runs the modern client, where these moved into C_Item
D.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
D.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- Realm clock as "HH:MM" minutes since midnight
function D.RealmMinutes()
  local h, m = GetGameTime()
  return (h or 0) * 60 + (m or 0)
end

-- Realm calendar date "YYYY-MM-DD" (the same for everyone, unlike date())
function D.RealmDate()
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    local ok, d = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if ok and d and d.year then return ("%04d-%02d-%02d"):format(d.year, d.month, d.monthDay) end
  end
  return date("!%Y-%m-%d", GetServerTime())
end

---------------------------------------------------------------------------
-- Names. Forever has "Firstname Lastname"; unit functions only give the
-- first name, addon-message senders and the guild roster give the full one.
---------------------------------------------------------------------------
local function Short(n) return n and Ambiguate(n, "none") or n end
D.Short = Short
local function FirstName(n) return n and n:match("^(%S+)") end
D.FirstName = FirstName

function D.SameName(a, b)
  if not a or not b then return false end
  return a == b or FirstName(a) == b or FirstName(b) == a
end

local function Me() return D.fullName or UnitName("player") end
D.Me = Me

-- every name we've seen, for turning "Skullcrank" into "Skullcrank Swampcheeks"
D.known = {}
local function Know(name)
  if name and name ~= "" and not Secret(name) then D.known[name] = true end
end
D.Know = Know

function D.Canon(name)
  if not name or name == "" or Secret(name) then return name end
  name = Short(name)
  if name:find(" ") then return name end
  local match, count = nil, 0
  for n in pairs(D.known) do
    if n == name then return n end
    if FirstName(n) == name and n:find(" ") then match, count = n, count + 1 end
  end
  if count == 1 then return match end
  return name
end

-- Forgiving form for matching Discord nicknames: lower case, no accents,
-- only the first word ("Skûllcrank (Tank)" / "Skull | Fury" -> "skullcrank" / "skull")
local ACCENTS = {
  ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a",
  ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
  ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o", ["ø"] = "o",
  ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u",
  ["ñ"] = "n", ["ç"] = "c", ["ý"] = "y", ["ÿ"] = "y", ["æ"] = "ae", ["ß"] = "ss",
}
-- v0.2.32: string.upper/lower only touch plain A-Z, so capital accented
-- letters (the first letter of most special names: "Ëlwyn", "Åsa") were never
-- folded and got dropped. Capitals are listed explicitly now.
local ACCENTS_UPPER = {
  ["À"] = "a", ["Á"] = "a", ["Â"] = "a", ["Ã"] = "a", ["Ä"] = "a", ["Å"] = "a",
  ["È"] = "e", ["É"] = "e", ["Ê"] = "e", ["Ë"] = "e",
  ["Ì"] = "i", ["Í"] = "i", ["Î"] = "i", ["Ï"] = "i",
  ["Ò"] = "o", ["Ó"] = "o", ["Ô"] = "o", ["Õ"] = "o", ["Ö"] = "o", ["Ø"] = "o",
  ["Ù"] = "u", ["Ú"] = "u", ["Û"] = "u", ["Ü"] = "u",
  ["Ñ"] = "n", ["Ç"] = "c", ["Ý"] = "y", ["Æ"] = "ae",
}
-- whole name, lower case, accents folded: "Ëlwyn" -> "elwyn"
function D.Fold(s)
  s = tostring(s or "")
  for k, v in pairs(ACCENTS_UPPER) do s = s:gsub(k, v) end
  s = s:lower()
  for k, v in pairs(ACCENTS) do s = s:gsub(k, v) end
  return s
end
function D.Normalize(s)
  -- letters plus any byte of a non-ASCII character we don't fold, so an
  -- unusual letter stays part of the word instead of splitting it
  return D.Fold(s):match("^[^%a\128-\255]*([%a\128-\255]+)") or ""
end

-- Typed name -> known full name ("thal" is not enough; "thalindra" is)
function D.ResolveName(input)
  local str = Clean(input, 40):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  if str == "" then return str end
  local low = str:lower()
  local match, count = nil, 0
  for n in pairs(D.known) do
    if n:lower() == low then return n end
    if (FirstName(n) or ""):lower() == low then match, count = n, count + 1 end
  end
  if count == 1 then return match end
  -- v0.2.32: typed "elwyn" or "ëlwyn" for Ëlwyn - match ignoring accents and
  -- capitals instead of inventing a new lower-case name in the ledger
  local fold = D.Fold(str)
  match, count = nil, 0
  for n in pairs(D.known) do
    if D.Fold(n) == fold then return n end
    if D.Fold(FirstName(n)) == fold then match, count = n, count + 1 end
  end
  if count == 1 then return match end
  return (str:gsub("(%S)(%S*)", function(a, b) return a:upper() .. b:lower() end))
end

---------------------------------------------------------------------------
-- Ranks (0 = Guild Master)
---------------------------------------------------------------------------
function D.MyRank()
  if not IsInGuild() then return nil end
  local _, _, rankIndex = GetGuildInfo("player")
  return rankIndex
end

function D.RankOf(name)
  if D.SameName(name, Me()) then return D.MyRank() end
  local r = D.roster[name]
  if not r then
    for n, x in pairs(D.roster) do if D.SameName(n, name) then r = x break end end
  end
  return r and r.rankIndex
end

function D.Cfg(key)
  local cfg = D.data and D.data.cfg
  local v = cfg and cfg[key]
  if v == nil then return C[key] end
  return v
end

function D.IsAdmin(name)
  local r = name and D.RankOf(name) or D.MyRank()
  return r ~= nil and r <= (tonumber(D.Cfg("ADMIN_RANK")) or C.ADMIN_RANK)
end
function D.IsGM() return D.MyRank() == 0 end

-- Admin events only count while their author holds the rank on the live roster
local function RankOk(name, maxRank)
  if not name or name == "" then return false end
  if not next(D.roster) then return true end -- roster not loaded yet
  local r = D.RankOf(name)
  return r ~= nil and r <= maxRank
end

---------------------------------------------------------------------------
-- Throttled send queue (GUILD for the ledger, RAID for auctions, WHISPER for bids)
---------------------------------------------------------------------------
local queue, cooldown = {}, 0
local THROTTLED = {}
if Enum and Enum.SendAddonMessageResult then
  local E = Enum.SendAddonMessageResult
  if E.AddonMessageThrottle then THROTTLED[E.AddonMessageThrottle] = true end
  if E.ChannelThrottle then THROTTLED[E.ChannelThrottle] = true end
end

-- Home group only. On this client BGs, arenas and LFG put you in an
-- "instance" group that bare IsInRaid()/IsInGroup() also report as true, so
-- queueing an arena used to pop Standings full of pugs and spam "You are not
-- in a raid group" from RAID-channel sends. A premade that's currently inside
-- a BG/arena doesn't count as a raid either. (v0.2.21)
local HOME = LE_PARTY_CATEGORY_HOME or 1
local function InPvP()
  local _, t = IsInInstance()
  return t == "pvp" or t == "arena"
end
function D.InRaid() return IsInRaid(HOME) and not InPvP() end
function D.InGroup() return IsInGroup(HOME) and not InPvP() end
function D.GroupSize() return GetNumGroupMembers(HOME) or 0 end

function D.GroupChannel()
  if D.InRaid() then return "RAID" end
  if D.InGroup() then return "PARTY" end
  return nil
end

-- Addon messages are capped at 255 bytes. Longer ones (big award lists, long
-- reasons) go out as numbered parts and are put back together on arrival.
local MAX_MSG, PART = 250, 220
local partTok = 0

-- v0.2.23: auction traffic gets its own lane that always goes first. Before
-- this, an auction queued up behind ledger sync (a bucket resend can be
-- hundreds of EV messages, throttled by Blizzard to ~1/sec) and reached the
-- raid long after bidding had closed - so nobody saw a popup.
local prioQ = {}
local PRIO = { AU = true, AT = true, AH = true, AX = true, AC = true, AB = true, AP = true, AR = true, AQ = true, AQR = true, VQ = true, VR = true }
local pending = {}      -- channel/target/msg -> true, so the same sync message isn't queued twice
D.commStats = { sent = 0, throttled = 0, dropped = 0, deduped = 0, prioSent = 0 }

-- While an auction is live (I'm running one, or I've got a bid popup open)
-- ledger sync waits, so bids and replies aren't fighting it for throttle.
function D.AuctionBusy()
  if D.auction then return true end
  local now = GetTime()
  for _, info in pairs(D.bidding or {}) do
    if info.endsLocal and now < info.endsLocal + 15 then return true end
  end
  return false
end

local function Key(item) return item.channel .. "\1" .. (item.target or "") .. "\1" .. item.msg end

local function Push(item, prio)
  if prio then prioQ[#prioQ + 1] = item return end
  local k = Key(item)
  if pending[k] then D.commStats.deduped = D.commStats.deduped + 1 return end
  pending[k] = true
  -- v0.2.41: a brand-new event of mine jumps ahead of sync resends
  if item.front then
    local pos = 1
    while queue[pos] and queue[pos].front do pos = pos + 1 end
    table.insert(queue, pos, item)
  else
    queue[#queue + 1] = item
  end
end

local function Send(msg, channel, target, front)
  channel = channel or "GUILD"
  if channel == "GROUP" then channel = D.GroupChannel() end
  if not channel then return end
  -- safety net: never send on RAID/PARTY from a BG/arena instance group
  if channel == "RAID" and not D.InRaid() then return end
  if channel == "PARTY" and not D.InGroup() then return end
  if channel == "GUILD" and not IsInGuild() then return end
  local prio = PRIO[msg:match("^(%u+)") or ""] or false
  if #msg <= MAX_MSG then
    Push({ msg = msg, channel = channel, target = target, tries = 0, prio = prio, front = front }, prio)
    return
  end
  partTok = (partTok + 1) % 10000
  local n = math.ceil(#msg / PART)
  for i = 1, n do
    local piece = msg:sub((i - 1) * PART + 1, i * PART)
    Push({ msg = "MP" .. SEP .. partTok .. SEP .. i .. SEP .. n .. SEP .. piece,
      channel = channel, target = target, tries = 0, prio = prio, front = front }, prio)
  end
end
D.Send = Send

C_Timer.NewTicker(0.2, function()
  if GetTime() < cooldown then return end
  local q
  if #prioQ > 0 then q = prioQ
  elseif #queue > 0 and not D.AuctionBusy() then q = queue
  else return end
  local item = table.remove(q, 1)
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, C.PREFIX, item.msg, item.channel, item.target)
  if not ok or result == false or THROTTLED[result] then
    item.tries = item.tries + 1
    D.commStats.throttled = D.commStats.throttled + 1
    -- auction messages keep trying (they matter right now); sync gives up after 5
    if item.tries < (item.prio and 30 or 5) then
      table.insert(q, 1, item)
    else
      D.commStats.dropped = D.commStats.dropped + 1
      if not item.prio then pending[Key(item)] = nil end
    end
    cooldown = GetTime() + (item.prio and 1 or 2)
  else
    D.commStats.sent = D.commStats.sent + 1
    if item.prio then D.commStats.prioSent = D.commStats.prioSent + 1
    else pending[Key(item)] = nil end
  end
end)

function D.CommStatus()
  local s = D.commStats
  Print(("Send queue: %d auction, %d sync%s. Since login: %d sent, %d throttled, %d dropped, %d duplicates skipped."):format(
    #prioQ, #queue, D.AuctionBusy() and " (sync paused for the auction)" or "", s.sent, s.throttled, s.dropped, s.deduped))
end

---------------------------------------------------------------------------
-- Chat that needs a key press or click (Forever blocks add-on chat otherwise).
-- D.Chat(msg, type, target, clicked): clicked = called straight from a button.
---------------------------------------------------------------------------
D.pendingChat = {}
local function RawChat(msg, chatType, target)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  return pcall(send, msg, chatType, nil, target)
end

function D.PostPendingChat()
  if D.DisarmKeyPost then D.DisarmKeyPost() end
  local list = D.pendingChat
  D.pendingChat = {}
  for _, c in ipairs(list) do RawChat(c.msg, c.chatType, c.target) end
end

function D.Chat(msg, chatType, target, clicked)
  if chatType == "RAID_WARNING" and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
    chatType = "RAID"
  end
  if (chatType == "RAID" or chatType == "RAID_WARNING") and not D.InRaid() then
    chatType = D.InGroup() and "PARTY" or nil
  end
  if not chatType then Print(msg) return end
  if D.practice and chatType ~= "WHISPER" then Print("[practice] " .. msg) return end
  if clicked then
    RawChat(msg, chatType, target)
  else
    table.insert(D.pendingChat, { msg = msg, chatType = chatType, target = target })
    if D.ArmKeyPost then D.ArmKeyPost() end
  end
end

---------------------------------------------------------------------------
-- Saved data
--   GuildLadderDKPDB.settings            window positions, toggles (this account)
--   GuildLadderDKPDB.guilds[<guild>]     events (the ledger), queue, counter, bench
---------------------------------------------------------------------------
local function Defaults(t, d)
  for k, v in pairs(d) do if t[k] == nil then t[k] = Copy(v) end end
  return t
end

local function InitDB()
  GuildLadderDKPDB = GuildLadderDKPDB or {}
  local db = GuildLadderDKPDB
  db.settings = Defaults(db.settings or {}, {
    minimap = true, minimapAngle = 160, popup = true, sound = true, autoNext = false, pos = {}, liveOnRaid = true,
    awardToasts = true,
    lootReveal = true, revealSound = true, -- v0.5.0
    bisTooltip = true, -- v0.6.0
    bisBestFor = true, gearAlts = true, -- v0.6.1
    raidPopup = true, raidBisOnly = false, -- v0.7.0
    wantSound = true, wantSoundId = 2, -- v0.7.1
    lootDock = true, dockCollapsed = false, -- v1.1.0
    tradeFill = true, tradeOpen = true, -- v1.2.0
    scales = {}, sizes = {}, -- v0.2.30: per-window scale and (Standings / Loot Queue) height
  })
  db.guilds = db.guilds or {}
  D.settings = db.settings
end

local function GuildKey() return (IsInGuild() and GetGuildInfo("player")) or "_solo" end

local function SelectGuild()
  local key = GuildKey()
  local g = Defaults(GuildLadderDKPDB.guilds[key] or {}, {
    events = {}, queue = {}, counter = 0, bench = {}, practice = {}, bridgeShared = nil, classCache = {},
  })
  GuildLadderDKPDB.guilds[key] = g
  D.db, D.guildKey = g, key
end

---------------------------------------------------------------------------
-- Events
--   id, k (kind), t (server time), by (author), p (player or "a,b,c"),
--   v (number or value), x (category / item id / key), r (reason / item name),
--   u (target id for undo), g (raid night "YYYY-MM-DD")
-- Admin kinds:  AW award, SP spend (item won), AD adjust, DC decay %, UN undo,
--               SB starting balance, IN item note, LK Discord link, CFG setting (GM)
--               SN raid session (x = session id, r = title, v = Raid-Helper id;
--               u = "C" created / "S" started; no u = created + started at once),
--               SE session end (x = id, p = attendees), BE bench (p = name, v 1/0, x = session id),
--               AO officer alt link (p = alt, x = main, "" = unlink)
-- Player kinds: WL wishlist, AL alt claims a main (p = alt, x = main, v 1/0),
--               AM main accepts an alt (p = main, x = alt, v 1/0). Author must be p.
---------------------------------------------------------------------------
local ADMIN_KINDS = { AW = true, SP = true, AD = true, DC = true, UN = true, SB = true, IN = true, LK = true, CFG = true,
  SN = true, SE = true, BE = true, AO = true }
D.ADMIN_KINDS = ADMIN_KINDS
-- written by the player themselves (author must be the player)
local PLAYER_KINDS = { WL = true, AL = true, AM = true }
-- Officer-written kinds introduced after the original design, deliberately
-- NOT in ADMIN_KINDS. Bucket() (below, for sync digests) sorts purely by
-- ADMIN_KINDS membership, and that table is read from each CLIENT'S OWN
-- version of this file - so a kind added here in, say, 0.2.18 buckets as "@"
-- on an updated client but falls through to "W:<p>" on anyone still running
-- 0.2.17, since their copy of ADMIN_KINDS doesn't have it. Two clients
-- disagreeing about which bucket the very same event belongs to is a digest
-- mismatch that re-syncing can never resolve - it looks like one stuck,
-- never-converging "1 entry different" for as long as versions differ.
-- Putting a new kind here instead keeps every version's bucketing identical
-- regardless of whether that version understands the kind - older clients
-- still store and pass it on over sync, they just don't display it.
-- (This bit GuildLadderDKP itself in 0.2.18: HD was added straight to
-- ADMIN_KINDS, which is exactly this bug. Moving it here in 0.2.19 fixes it
-- going forward - everyone just needs to be on 0.2.19+ for HD to sync clean.)
--   HL = historical loot (v0.2.14, CLM import). p = winner, v = price paid,
--        x = item id, r = item name, u = "OS" or nil, g = "CLM-YYYY-MM-DD",
--        t = when they won it. Record only, never touches a balance.
--   HD = hide/restore on Standings (v0.2.18). p = player, v = "1" hide /
--        "0" restore, latest wins. Record only, never touches a balance.
--   PD = raid award (v1.5.0, Podium). p = winner, u = award code, x / g = raid id, r = raid title, v = "1".
--        Record only, never touches a balance. Only the first officer to share a raid's awards counts.
local RECORD_KINDS = { HL = true, HD = true, PD = true }
D.RECORD_KINDS = RECORD_KINDS

-- v0.2.41: officer events are bucketed by (UTC) day instead of all in one "@"
-- bucket. With one bucket, any difference between two officers made everyone
-- resend the WHOLE ledger (700+ messages at ~1/sec) - new events, like Raid
-- ended, waited behind that for 15-20 minutes. Now only the day that differs
-- is resent. Digests use a new message kind (HW) so this never mixes with
-- older versions' "@" digests.
local function Bucket(e)
  if ADMIN_KINDS[e.k] then return "@" .. date("!%Y%m%d", tonumber(e.t) or 0) end
  return "W:" .. (e.p or "?")
end

local function Hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function EventMsg(e)
  return Pack("EV", e.id, e.k, e.t, e.by, e.p, e.v, e.x, e.r, e.u, e.g)
end

local function ParseEvent(p)
  local function s(i) return (p[i] and p[i] ~= "") and p[i] or nil end
  local e = { id = s(2), k = s(3), t = tonumber(p[4]), by = s(5), p = s(6), v = s(7), x = s(8), r = s(9), u = s(10), g = s(11) }
  if not e.id or not e.k or not e.t then return nil end
  if e.t > GetServerTime() + 3600 then return nil end -- clock nonsense
  return e
end

local function StoreEvent(e, store)
  store = store or D.db.events
  if store[e.id] then return false end
  e.h = Hash(e.id)
  store[e.id] = e
  return true
end

local computeQueued
local function ScheduleCompute()
  if computeQueued then return end
  computeQueued = true
  C_Timer.After(0.3, function()
    computeQueued = false
    D.Compute()
  end)
end
D.ScheduleCompute = ScheduleCompute

-- New event by me. In practice mode it goes to a throwaway store and is never sent.
local function NewEvent(e)
  if not D.db then return nil end
  e.t = e.t or GetServerTime()
  e.by = Me()
  D.db.counter = (D.db.counter or 0) + 1
  e.id = Clean(Me(), 40) .. "-" .. e.k .. D.db.counter .. "-" .. e.t
  for _, f in ipairs({ "p", "v", "x", "r", "u", "g" }) do
    if e[f] ~= nil then e[f] = Clean(e[f], f == "p" and 240 or 80) end
  end
  if D.practice then
    StoreEvent(e, D.db.practice)
  else
    StoreEvent(e)
    Send(EventMsg(e), nil, nil, true) -- v0.2.41: ahead of sync resends
  end
  if D.QueueAwardToast then D.QueueAwardToast(e) end
  if D.QueueLootReveal then D.QueueLootReveal(e) end -- v0.5.0
  ScheduleCompute()
  return e.id
end
D.NewEvent = NewEvent -- v1.5.0: Stats.lua writes the raid awards

---------------------------------------------------------------------------
-- Working out balances from the history
---------------------------------------------------------------------------
local function SplitNames(p)
  local t = {}
  for n in (p or ""):gmatch("[^,]+") do t[#t + 1] = n end
  return t
end
D.SplitNames = SplitNames

-- "## Version:" from the .toc, however the client exposes it this expansion
D.Version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"


---------------------------------------------------------------------------
-- Bot snapshot (v0.2.15): a small, pre-digested table written into
-- SavedVariables alongside the ledger, for an external Discord bot to read
-- instead of re-deriving balances/alts/ranks itself (that logic only runs
-- correctly in-client, with the live roster in memory). Shaped to match
-- what CLM's own "WoW DKP Bot Integration" snapshot looked like - per
-- player: dkp, class, recent history (point changes), recent loot - so a
-- bot already built against that shape needs only a new file path and
-- table name, not new parsing logic.
-- Capped per player so SavedVariables doesn't grow unbounded for a long-
-- tenured raider; the bot only ever shows the last handful anyway.
---------------------------------------------------------------------------
local SNAPSHOT_CAP = 25
local function TopN(list, n)
  local sorted = {}
  for i, v in ipairs(list) do sorted[i] = v end
  table.sort(sorted, function(a, b) return a.t > b.t end)
  local out = {}
  for i = 1, math.min(n, #sorted) do out[i] = sorted[i] end
  return out
end

local function WriteBotSnapshot(bal, items, hist)
  if not D.db then return end
  local players = {}
  for n, b in pairs(bal) do
    local loot = {}
    for i, it in ipairs(TopN(items[n] or {}, SNAPSHOT_CAP)) do
      loot[i] = { time = it.t, name = it.name, id = it.item, value = it.price, os = it.os, clm = it.clm }
    end
    local history = {}
    for i, h in ipairs(TopN(hist[n] or {}, SNAPSHOT_CAP)) do
      history[i] = { time = h.t, value = h.v, reason = h.r } -- v0.2.36: reason (e.g. "Weekly decay -20%")
    end
    players[n] = { dkp = b, class = D.ClassOf(n), history = history, loot = loot }
  end
  D.db.botSnapshot = { writtenAt = GetServerTime(), players = players }
end

local function SortEvents(list)
  table.sort(list, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.id < b.id
  end)
end

---------------------------------------------------------------------------
-- v0.5.0: Hall of Fame. Everything here is worked out from the ledger every
-- time D.Compute runs - nothing new is stored or synced, so it works on old
-- history too and never causes a sync mismatch between versions.
---------------------------------------------------------------------------
D.FAME = { STREAK = 4, VETERAN = 25, PREPARED = 5, COLLECTOR = 10 } -- badge thresholds

local function NewStat()
  return { earned = 0, spent = 0, items = 0, bosses = 0, prepared = 0, nights = 0 }
end

-- longest run of consecutive raid nights in `list` that `set` attended, and
-- the run still going at the latest night
local function Streaks(list, set)
  local best, run = 0, 0
  for _, g in ipairs(list) do
    if set[g] then
      run = run + 1
      if run > best then best = run end
    else
      run = 0
    end
  end
  return best, run
end

local function BuildFame(statsAll, statsNew, attend, nights, nightT, phaseStart, hidden, items, firstKill, bossNights)
  -- only nights somebody actually attended count (a raid that was created
  -- and never run must not break everyone's streak)
  local used = {}
  for _, set in pairs(attend) do for g in pairs(set) do used[g] = true end end
  local real, realNew = {}, {}
  for _, g in ipairs(nights) do
    if used[g] then
      real[#real + 1] = g
      if (nightT[g] or 0) >= phaseStart then realNew[#realNew + 1] = g end
    end
  end
  local fame = {
    stats = { all = statsAll, phase = statsNew },
    streak = { all = {}, phase = {} },
    top = { all = {}, phase = {} },
    wins = { all = {}, phase = {} },
    nightCount = { all = #real, phase = #realNew },
    phaseStart = phaseStart,
  }
  for pool, set in pairs(attend) do
    local sa = statsAll[pool] or NewStat(); statsAll[pool] = sa
    local sn = statsNew[pool] or NewStat(); statsNew[pool] = sn
    local ba, ca = Streaks(real, set)
    local bn, cn = Streaks(realNew, set)
    fame.streak.all[pool] = { best = ba, cur = ca }
    fame.streak.phase[pool] = { best = bn, cur = cn }
    local na, nn = 0, 0
    for _, g in ipairs(real) do if set[g] then na = na + 1 end end
    for _, g in ipairs(realNew) do if set[g] then nn = nn + 1 end end
    sa.nights, sn.nights = na, nn
  end

  -- guild-wide records (players hidden from Standings are left out)
  local FIELDS = { "spent", "items", "earned", "prepared", "bosses", "nights" }
  for _, scope in ipairs({ "all", "phase" }) do
    local top = fame.top[scope]
    for pool, st in pairs(fame.stats[scope]) do
      if not hidden[pool] then
        for _, f in ipairs(FIELDS) do
          local v = st[f] or 0
          local cur = top[f]
          if v > 0 and (not cur or v > cur.v or (v == cur.v and pool < cur.pool)) then
            top[f] = { pool = pool, v = v }
          end
        end
        local sk = fame.streak[scope][pool]
        if sk and sk.best > 0 then
          local cur = top.streak
          if not cur or sk.best > cur.v or (sk.best == cur.v and pool < cur.pool) then
            top.streak = { pool = pool, v = sk.best }
          end
        end
      end
    end
    -- priciest single wins
    local list = {}
    for pool, its in pairs(items) do
      if not hidden[pool] then
        for _, it in ipairs(its) do
          if (scope == "all" or (it.t or 0) >= phaseStart) and (tonumber(it.price) or 0) > 0 then
            list[#list + 1] = { who = pool, item = it.item, name = it.name, price = tonumber(it.price), t = it.t, os = it.os, clm = it.clm }
          end
        end
      end
    end
    table.sort(list, function(a, b)
      if a.price ~= b.price then return a.price > b.price end
      if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) > (b.t or 0) end
      return a.who < b.who
    end)
    for i = 1, math.min(5, #list) do fame.wins[scope][i] = list[i] end
  end

  -- first kill of each boss that this ledger has seen
  local fk = {}
  for key, r in pairs(firstKill) do
    local n, kills = 0, 0
    for _ in pairs(r.who) do n = n + 1 end
    for _ in pairs(bossNights[key] or {}) do kills = kills + 1 end
    fk[#fk + 1] = { boss = r.boss, t = r.t, raiders = n, kills = kills }
  end
  table.sort(fk, function(a, b) return a.t > b.t end)
  fame.firstKills = fk
  return fame
end

function D.Compute()
  if not D.db then return end
  local all = {}
  for _, e in pairs(D.db.events) do all[#all + 1] = e end
  if D.practice then for _, e in pairs(D.db.practice) do all[#all + 1] = e end end
  SortEvents(all)

  -- 1) GM settings first (they decide who counts as an officer)
  local cfg, bossValues = {}, {}
  for _, e in ipairs(all) do
    if e.k == "CFG" and RankOk(e.by, 0) and e.x then
      local boss = e.x:match("^BV:(.+)$")
      if boss then
        bossValues[boss] = tonumber(e.v)
      else
        local num = tonumber(e.v)
        cfg[e.x] = num ~= nil and num or e.v
      end
    end
  end
  local adminRank = tonumber(cfg.ADMIN_RANK) or C.ADMIN_RANK

  -- 2) Valid events, then undo
  local valid, undone, undoOf = {}, {}, {}
  for _, e in ipairs(all) do
    if ADMIN_KINDS[e.k] then
      if e.k ~= "CFG" and RankOk(e.by, adminRank) then valid[#valid + 1] = e end
    elseif PLAYER_KINDS[e.k] then
      if e.by and e.by == e.p then valid[#valid + 1] = e end
    elseif RECORD_KINDS[e.k] then
      if RankOk(e.by, adminRank) then valid[#valid + 1] = e end
    end
  end
  for _, e in ipairs(valid) do
    if e.k == "UN" and e.u and not undone[e.id] then undone[e.u] = true; undoOf[e.u] = e end
  end

  -- 3) Alt links. Both characters have to say so (the alt claims the main, the
  --    main accepts the alt), or an officer links them. Latest word wins.
  local claim, accept, officer = {}, {}, {}
  for _, e in ipairs(valid) do
    if not undone[e.id] then
      if e.k == "AL" then
        claim[e.p] = (e.v == "1" and e.x and e.x ~= "") and e.x or nil
      elseif e.k == "AM" and e.x then
        accept[e.p] = accept[e.p] or {}
        accept[e.p][e.x] = e.v == "1"
      elseif e.k == "AO" and e.p then
        officer[e.p] = (e.x and e.x ~= "") and e.x or false
      end
    end
  end
  local mainOf = {}
  for alt, main in pairs(claim) do
    if accept[main] and accept[main][alt] then mainOf[alt] = main end
  end
  for alt, main in pairs(officer) do mainOf[alt] = main or nil end
  for alt, main in pairs(mainOf) do -- one level only, no loops
    if mainOf[main] then mainOf[alt] = mainOf[main] ~= alt and mainOf[main] or nil end
  end
  local altsOf = {}
  for alt, main in pairs(mainOf) do
    altsOf[main] = altsOf[main] or {}
    table.insert(altsOf[main], alt)
  end
  local function Pool(n) return mainOf[n] or n end

  -- 4) Walk the ledger in order (everything about an alt counts for its main)
  local bal, items, attend, notes, links, wishes, hidden = {}, {}, {}, {}, {}, {}, {}
  local awards, pdOwner = {}, {} -- v1.5.0: Podium awards per player (pool): code -> times won
  local wishT = {} -- v0.3.1: item -> player -> when it went on their wishlist
  local nights, nightT = {}, {}
  local byNight = {} -- raid key -> { awards = {events}, spends = {events} }
  local function NightLog(e, kind)
    if not e.g then return end
    byNight[e.g] = byNight[e.g] or { awards = {}, spends = {} }
    table.insert(byNight[e.g][kind], e)
  end
  local sessions, benches = {}, {}
  local log = {}
  local hist = {} -- pool name -> { {t=,v=,r=}, ... } point changes, for the bot snapshot
  local decayLoss = {} -- v0.2.36: decay event id -> { pool name = DKP lost }
  local wonBy = {} -- item id -> { { who, t }, ... } every win, native or imported
  local function Won(e)
    local id = tonumber(e.x)
    if not id or not e.p then return end
    wonBy[id] = wonBy[id] or {}
    -- v0.2.38: price and spec too, for the bid pop-up's "won before" line
    table.insert(wonBy[id], { who = e.p, t = e.t, price = tonumber(e.v), os = e.u == "OS", clm = e.k == "HL" })
  end
  -- v0.5.0: Hall of Fame tallies, all-time and for the current phase
  local phaseStart = tonumber(cfg.PHASE_START) or 0
  local fameAll, fameNew, firstKill, bossNights = {}, {}, {}, {}
  local function FBump(m, t, field, n)
    local a = fameAll[m]; if not a then a = NewStat(); fameAll[m] = a end
    a[field] = a[field] + n
    if (t or 0) >= phaseStart then
      local b = fameNew[m]; if not b then b = NewStat(); fameNew[m] = b end
      b[field] = b[field] + n
    end
  end
  local function FameAward(e, names, amt)
    for _, n in ipairs(names) do
      local m = Pool(n)
      if amt > 0 then FBump(m, e.t, "earned", amt) end
      if e.x == "BOSS" then FBump(m, e.t, "bosses", 1) end
      if e.x == "CUSTOM" and (e.r or ""):find("^Prepared:") then FBump(m, e.t, "prepared", 1) end
    end
    if e.x == "BOSS" and e.g then
      local boss = ((e.r or ""):gsub("^Boss kill: ", ""))
      local key = boss:lower()
      bossNights[key] = bossNights[key] or {}
      bossNights[key][e.g] = true
      local fk = firstKill[key]
      if not fk or e.t < fk.t then
        fk = { boss = boss, t = e.t, g = e.g, who = {} }
        firstKill[key] = fk
      end
      if fk.g == e.g then
        for _, n in ipairs(names) do fk.who[Pool(n)] = true end
      end
    end
  end
  local function FameWin(e, m, price)
    FBump(m, e.t, "items", 1)
    FBump(m, e.t, "spent", price)
  end
  local function Night(g, t)
    if g and not nightT[g] then nightT[g] = t; nights[#nights + 1] = g end
  end
  local function Attend(n, g)
    n = Pool(n)
    attend[n] = attend[n] or {}
    attend[n][g] = true
  end
  -- sessions first, so an end in the same second still finds its start.
  -- A raid is created (SN u="C"), then started (SN u="S", same x). An SN with
  -- no u (0.2.6 and older, or Start with nothing created) is both at once.
  for _, e in ipairs(valid) do
    if e.k == "SN" and e.x and not undone[e.id] then
      local ses = sessions[e.x]
      if not ses then
        ses = { id = e.x, title = e.r, created = e.t, createdBy = e.by, cId = e.id, eventId = e.v, attendees = {} }
        sessions[e.x] = ses
        Night(e.x, e.t)
      end
      -- v0.2.34: raid leader when it was created/started - tells raid teams apart
      if e.p and e.p ~= "" and not ses.leader then ses.leader = e.p end
      if e.u ~= "C" and not ses.start then
        ses.start, ses.by, ses.snId = e.t, e.by, e.id
        if e.r and e.r ~= "" then ses.title = e.r end
      end
    end
  end
  -- v0.2.26: one boss award per character per boss per raid night. If two
  -- officers both award the same kill (or anyone awards it twice), the first
  -- one counts and the repeat is ignored for anyone it already paid. This also
  -- cleans up doubles already in the ledger from before this version.
  local walk, bossSeen, bossDupes = {}, {}, 0
  local decaySeen = {} -- v0.4.6
  for _, e in ipairs(valid) do
    if e.k == "AW" and e.x == "BOSS" and e.g and not undone[e.id] then
      local kept, dup = {}, false
      for _, n in ipairs(SplitNames(e.p)) do
        local key = e.g .. "\1" .. (e.r or "") .. "\1" .. n
        if bossSeen[key] then dup = true else bossSeen[key] = true; kept[#kept + 1] = n end
      end
      if not dup then
        walk[#walk + 1] = e
      else
        bossDupes = bossDupes + 1
        if #kept > 0 then
          local c = {}
          for f, v in pairs(e) do c[f] = v end
          c.p = table.concat(kept, ",")
          walk[#walk + 1] = c
        end
      end
    elseif e.k == "DC" and type(e.x) == "string" and e.x:find("^AUTO:") and not undone[e.id] then
      -- v0.4.6: one automatic decay per scheduled week; if two officers both
      -- post it (or one posts from an out-of-date ledger) the first one counts
      if not decaySeen[e.x] then decaySeen[e.x] = true; walk[#walk + 1] = e end
    else
      walk[#walk + 1] = e
    end
  end
  D.bossDupes = bossDupes

  for _, e in ipairs(walk) do
    local k, amt = e.k, tonumber(e.v) or 0
    if not undone[e.id] then
      if k == "AW" or k == "AD" or k == "SB" then
        local names = SplitNames(e.p)
        for _, n in ipairs(names) do
          local m = Pool(n)
          bal[m] = (bal[m] or 0) + amt
          hist[m] = hist[m] or {}
          table.insert(hist[m], { t = e.t, v = amt, r = e.r }) -- v0.2.36: reason for the bot
        end
        if k == "AW" and e.g then
          Night(e.g, e.t)
          NightLog(e, "awards")
          for _, n in ipairs(names) do Attend(n, e.g) end
        end
        if k == "AW" then FameAward(e, names, amt) end -- v0.5.0
      elseif k == "SP" and e.p then
        local m = Pool(e.p)
        bal[m] = (bal[m] or 0) - amt
        items[m] = items[m] or {}
        table.insert(items[m], { t = e.t, item = tonumber(e.x), name = e.r, price = amt, id = e.id, who = e.p, os = e.u == "OS" })
        hist[m] = hist[m] or {}
        table.insert(hist[m], { t = e.t, v = -amt, r = e.r }) -- v0.2.36: reason for the bot
        NightLog(e, "spends")
        Won(e)
        FameWin(e, m, amt) -- v0.5.0
      elseif k == "HL" and e.p then
        -- imported history: shows everywhere loot shows, balance untouched
        local m = Pool(e.p)
        items[m] = items[m] or {}
        table.insert(items[m], { t = e.t, item = tonumber(e.x), name = e.r, price = amt, id = e.id, who = e.p, os = e.u == "OS", clm = true })
        NightLog(e, "spends")
        -- its own night key ("CLM-..."), so it never joins the attendance window
        if e.g and (not nightT[e.g] or e.t < nightT[e.g]) then nightT[e.g] = e.t end
        Won(e)
        FameWin(e, m, amt) -- v0.5.0
      elseif k == "DC" then
        local pct = math.max(0, math.min(100, amt))
        -- v0.2.36: record what each player lost, so decay shows in their own
        -- log and in the bot's history instead of balances dropping silently
        local loss = {}
        for n, b in pairs(bal) do
          if b > 0 then
            local nb = math.floor(b * (100 - pct) / 100 + 0.5)
            if nb ~= b then
              loss[n] = b - nb
              hist[n] = hist[n] or {}
              table.insert(hist[n], { t = e.t, v = nb - b, r = ("Weekly decay -%d%%"):format(pct) })
            end
            bal[n] = nb
          end
        end
        decayLoss[e.id] = loss
      elseif k == "IN" and e.x then
        notes[tonumber(e.x) or e.x] = (e.r or e.v) and { note = e.r, min = tonumber(e.v) } or nil
      elseif k == "LK" and e.p then
        links[e.p] = (e.x and e.x ~= "") and e.x or nil -- v0.3.4: "" = unlinked
      elseif k == "HD" and e.p then
        hidden[Pool(e.p)] = (e.v == "1") or nil
      elseif k == "PD" and e.p and e.u then
        -- v1.5.0: one officer's award set per raid; a second officer sharing the same raid is ignored
        local key = e.x or e.g or ""
        pdOwner[key] = pdOwner[key] or e.by
        if pdOwner[key] == e.by then
          local m = Pool(e.p)
          awards[m] = awards[m] or {}
          awards[m][e.u] = (awards[m][e.u] or 0) + 1
        end
      elseif k == "WL" and e.x then
        local id = tonumber(e.x)
        if id then
          wishes[id] = wishes[id] or {}
          wishes[id][e.p] = (e.v == "1") or nil
          wishT[id] = wishT[id] or {}
          wishT[id][e.p] = (e.v == "1") and e.t or nil
        end
      elseif k == "SE" and e.x and sessions[e.x] then
        local ses = sessions[e.x]
        ses.ended = ses.ended or e.t
        ses.endedBy = ses.endedBy or e.by
        for _, n in ipairs(SplitNames(e.p)) do
          ses.attendees[Pool(n)] = true
          Attend(n, e.x)
        end
      elseif k == "BE" and e.p then
        local key = e.x or ""
        benches[key] = benches[key] or {}
        benches[key][e.p] = (e.v == "1") or nil
      end
    end
    if k ~= "WL" and k ~= "BE" and k ~= "AL" and k ~= "AM" then log[#log + 1] = e end
  end

  -- the raid session still open (the latest one started), and the latest
  -- raid that was created but not started yet
  -- v0.2.34: several officers can create the same raid at once (each before
  -- seeing the others'). Unended raids of the same team - same raid leader, or
  -- made within 10 minutes when the leader isn't known - within 6 hours are
  -- one raid: a started one wins, then the earliest. The rest are duplicates.
  local unended = {}
  for _, ses in pairs(sessions) do if not ses.ended then unended[#unended + 1] = ses end end
  table.sort(unended, function(a, b)
    if (a.start ~= nil) ~= (b.start ~= nil) then return a.start ~= nil end
    local ta, tb = a.start or a.created or 0, b.start or b.created or 0
    if ta ~= tb then return ta < tb end
    return a.id < b.id
  end)
  local function SameTeam(a, b)
    if math.abs((a.created or 0) - (b.created or 0)) > 6 * 3600 then return false end
    if a.leader and b.leader then return a.leader == b.leader end
    return math.abs((a.created or 0) - (b.created or 0)) <= 600
  end
  local kept = {}
  for _, ses in ipairs(unended) do
    for _, k in ipairs(kept) do
      if SameTeam(k, ses) then ses.dupOf = k.id break end
    end
    if not ses.dupOf then kept[#kept + 1] = ses end
  end
  -- newest first; open/planned stay as "the latest" for anything that wants one
  local openList, plannedList = {}, {}
  for _, ses in ipairs(kept) do
    if ses.start then openList[#openList + 1] = ses else plannedList[#plannedList + 1] = ses end
  end
  table.sort(openList, function(a, b) return a.start > b.start end)
  table.sort(plannedList, function(a, b) return a.created > b.created end)
  local open, planned = openList[1], plannedList[1]

  -- attendance over the last N raid nights / sessions
  table.sort(nights, function(a, b) return nightT[a] < nightT[b] end)
  local lastN = {}
  local N = tonumber(cfg.ATTENDANCE_RAIDS) or C.ATTENDANCE_RAIDS
  for i = math.max(1, #nights - N + 1), #nights do lastN[#lastN + 1] = nights[i] end
  local attendPct = {}
  for n, set in pairs(attend) do
    local c = 0
    for _, g in ipairs(lastN) do if set[g] then c = c + 1 end end
    attendPct[n] = #lastN > 0 and math.floor(100 * c / #lastN + 0.5) or 0
  end

  local fame = BuildFame(fameAll, fameNew, attend, nights, nightT, phaseStart, hidden, items, firstKill, bossNights) -- v0.5.0

  D.data = {
    fame = fame, -- v0.5.0
    awards = awards, -- v1.5.0
    cfg = cfg, bossValues = bossValues, bal = bal, items = items, attendPct = attendPct,
    nights = nights, notes = notes, links = links, wishes = wishes, wishT = wishT, -- v0.3.1
    log = log, undone = undone, undoOf = undoOf, hidden = hidden,
    mainOf = mainOf, altsOf = altsOf, claim = claim, accept = accept,
    sessions = sessions, openSession = open, plannedSession = planned, benches = benches, byNight = byNight, nightT = nightT,
    openList = openList, plannedList = plannedList, -- v0.2.34
    decayLoss = decayLoss, -- v0.2.36
    wonBy = wonBy,
  }
  if D.ready and D.FixDuplicateRaids then C_Timer.After(3, D.FixDuplicateRaids) end
  for n in pairs(bal) do Know(n) end
  WriteBotSnapshot(bal, items, hist)
  D.Refresh()
  if D.ready then D.BroadcastStandings() end
  if D.FlushAwardToasts then D.FlushAwardToasts() end
  if D.FlushLootReveals then D.FlushLootReveals() end -- v0.5.0
  if D.ready and D.CheckAltClaims then D.CheckAltClaims() end
end

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------
-- Balance by name; accepts a first name if it's unique
-- Alts share their main's DKP: the "pool" a character's DKP lives in
function D.Pool(name)
  if not name then return name end
  local c = D.Canon(name)
  local m = D.data and D.data.mainOf
  return m and (m[name] or m[c]) or c
end
function D.MainOf(name) local p = D.Pool(name); return p ~= D.Canon(name) and p or nil end
function D.AltsOf(name) return D.data and D.data.altsOf[D.Pool(name)] or {} end

function D.Balance(name)
  if not D.data or not name then return 0 end
  local b = D.data.bal[name]
  if b and not D.data.mainOf[name] then return b end
  local c = D.Pool(name)
  if D.data.bal[c] then return D.data.bal[c] end
  for n, v in pairs(D.snap) do if D.SameName(n, name) then return v end end
  return 0
end

function D.ItemsThisPhase(name)
  local list = D.data and D.data.items[D.Pool(name)] or {}
  local since = tonumber(D.Cfg("PHASE_START")) or 0
  local count, last = 0, nil
  for _, it in ipairs(list) do
    if it.t >= since then count = count + 1 end
    if not last or it.t > last then last = it.t end
  end
  return count, last
end

function D.Attendance(name)
  return D.data and D.data.attendPct[D.Pool(name)] or 0
end

function D.ItemNote(itemID) return D.data and D.data.notes[itemID] end

-- Everyone who's won this item (native awards + imported CLM history), newest
-- first, one entry per character: { { who = name, t = time, count = n }, ... }
function D.WonBy(itemID)
  local list = D.data and D.data.wonBy and D.data.wonBy[itemID]
  if not list then return {} end
  local sorted = {}
  for i, w in ipairs(list) do sorted[i] = w end
  table.sort(sorted, function(a, b) return a.t > b.t end)
  local out, seen = {}, {}
  for _, w in ipairs(sorted) do
    if seen[w.who] then
      seen[w.who].count = seen[w.who].count + 1
    else
      local row = { who = w.who, t = w.t, count = 1 }
      seen[w.who] = row
      out[#out + 1] = row
    end
  end
  return out
end

-- v0.7.2: ids that stand for the same loot: the item itself, a token's tier pieces,
-- a tier piece's token (the auction is for the token, wishes name the piece)
function D.SameLoot(itemID)
  local ids = { itemID }
  local B = D.BiS
  if B then
    local ti = B.TokenInfo(itemID)
    if ti then
      for _, pc in ipairs(ti.pieces) do ids[#ids + 1] = pc.id end
    else
      local tk = B.TokenOf(itemID)
      if tk then ids[#ids + 1] = tk.id end
    end
  end
  return ids
end

-- every recorded win of this item; for a tier piece also the wins of its token (w.via = token id)
function D.WinsFor(itemID)
  local out = {}
  local by = D.data and D.data.wonBy
  if not by then return out end
  for _, w in ipairs(by[itemID] or {}) do out[#out + 1] = w end
  local tk = D.BiS and D.BiS.TokenOf(itemID)
  if tk then
    for _, w in ipairs(by[tk.id] or {}) do
      local c = {}
      for k, v in pairs(w) do c[k] = v end
      c.via = tk.id
      out[#out + 1] = c
    end
  end
  return out
end

-- v1.0.0: is this character in the guild? (false only once the roster has loaded and they're not on it, so
-- nobody disappears while the roster is still coming in, or when you're not in a guild at all)
function D.IsGuildMember(name)
  if not name or not next(D.roster) then return true end
  if D.roster[name] then return true end
  for n in pairs(D.roster) do if D.SameName(n, name) then return true end end
  return false
end

function D.Wishers(itemID)
  local list, have = {}, {}
  local ids = D.SameLoot(itemID)
  for _, id in ipairs(ids) do
    local w = D.data and D.data.wishes[id]
    -- v0.3.1: someone who already won it isn't still wanting it
    -- v1.0.0: and someone who left the guild doesn't want anything from us any more
    if w then
      for n in pairs(w) do
        if not have[n] and D.IsGuildMember(n) and not D.WishWon(id, n) then have[n] = true; list[#list + 1] = n end
      end
    end
  end
  -- wishes made in Discord (/wish) come in through the bridge file
  local bw = D.bridge and D.bridge.wishlists
  if bw then
    local wanted = {}
    for _, id in ipairs(ids) do wanted[id] = true end
    for discordId, dids in pairs(bw) do
      for _, id in ipairs(dids) do
        if wanted[tonumber(id)] then
          local char = D.CharForDiscord(discordId)
          if char and D.IsGuildMember(char) then
            local dup = false
            for _, n in ipairs(list) do if n == char then dup = true end end
            if not dup then list[#list + 1] = char end
          end
        end
      end
    end
  end
  table.sort(list)
  return list
end

-- Live standings for the raid. Guild members work it out from their own ledger;
-- pugs (no ledger) get it from one officer's broadcast over RAID.
D.snap, D.snapT = {}, 0

function D.RaidStandings()
  local list = {}
  for name, r in pairs(D.raid) do
    list[#list + 1] = { name = name, dkp = D.Balance(name), class = r.class }
  end
  for _, name in ipairs(D.Bench()) do
    if not D.raid[name] then list[#list + 1] = { name = name, dkp = D.Balance(name), bench = true } end
  end
  table.sort(list, function(a, b)
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  return list
end

-- Officers whose word we take for raid-wide things (auctions, standings).
-- Pugs can't check another guild's ranks, so the raid leader and assists count too.
function D.TrustedOfficer(name)
  if D.IsAdmin(name) then return true end
  for i = 1, D.GroupSize() do
    local n, rank = GetRaidRosterInfo(i)
    if n and not Secret(n) and D.SameName(Short(n), name) then return (rank or 0) >= 1 end
  end
  return false
end

-- One officer in the raid shares standings: the first online officer by name
function D.IsStandingsBroadcaster()
  if not D.InRaid() or D.practice or not D.IsAdmin() then return false end
  local best
  for n, r in pairs(D.raid) do
    if r.online ~= false and D.IsAdmin(n) and (not best or n < best) then best = n end
  end
  return best == nil or D.SameName(best, Me())
end

local lastSnap, snapQueued, lastSnapStr = 0, false, nil
function D.BroadcastStandings(force)
  if snapQueued or not D.ready or not D.IsStandingsBroadcaster() then return end
  snapQueued = true
  C_Timer.After(math.max(0, 5 - (GetTime() - lastSnap)) + 1, function()
    snapQueued = false
    if not D.IsStandingsBroadcaster() then return end
    local parts = {}
    for _, s in ipairs(D.RaidStandings()) do parts[#parts + 1] = Clean(s.name, 40):gsub("[,:]", "") .. ":" .. s.dkp end
    local str = table.concat(parts, ",")
    if not force and str == lastSnapStr then return end
    lastSnapStr, lastSnap = str, GetTime()
    local chunks, cur, len = {}, {}, 0
    for _, p in ipairs(parts) do
      if len + #p > 200 and #cur > 0 then chunks[#chunks + 1] = table.concat(cur, ","); cur, len = {}, 0 end
      cur[#cur + 1] = p
      len = len + #p + 1
    end
    chunks[#chunks + 1] = table.concat(cur, ",")
    local tag = math.random(100, 999)
    for i, c in ipairs(chunks) do Send(Pack("SS", tag, i, #chunks, c), "RAID") end
  end)
end

local snapParts = {}
D.handlers.SS = function(p, sender, channel)
  if channel ~= "RAID" or not D.TrustedOfficer(sender) then return end
  local key = sender .. (p[2] or "")
  local i, n = tonumber(p[3]), tonumber(p[4])
  if not (i and n) then return end
  local st = snapParts[key] or { got = 0, map = {} }
  snapParts[key] = st
  for name, v in (p[5] or ""):gmatch("([^,:]+):(%-?%d+)") do st.map[name] = tonumber(v) end
  st.got = st.got + 1
  if st.got >= n then
    snapParts[key] = nil
    local before = D.Balance(Me())
    D.snap, D.snapT = st.map, GetServerTime()
    local after = D.Balance(Me())
    local an = D.lastAN
    if an and GetTime() - an.t < 60 and after > before and not D.roster[sender] and D.settings.awardToasts ~= false then
      D.lastAN = nil
      D.Toast(("DKP awarded  +%d"):format(after - before), ("%s · you now have %d"):format(an.reason or "", after))
    end
    D.Refresh()
  end
end
D.handlers.SQ = function(_, _, channel)
  if channel == "RAID" then D.BroadcastStandings(true) end
end

function D.Standings()
  local list = {}
  if not D.data then return list end
  for n, b in pairs(D.data.bal) do
    if not D.data.hidden[n] then list[#list + 1] = { name = n, dkp = b } end
  end
  table.sort(list, function(a, b)
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  return list
end

---------------------------------------------------------------------------
-- Officer actions (all go through the ledger)
---------------------------------------------------------------------------
local function NeedAdmin()
  if D.practice then return true end
  if not D.IsAdmin() then Print("Only officers can change DKP.") return false end
  return true
end

-- One event per ~200 characters of names (message size limit)
function D.WriteChunked(names, fields)
  local chunk, len = {}, 0
  local function Flush()
    if #chunk == 0 then return end
    local e = {}
    for k, v in pairs(fields) do e[k] = v end
    e.p = table.concat(chunk, ",")
    NewEvent(e)
    chunk, len = {}, 0
  end
  for _, n in ipairs(names) do
    if len + #n > 200 then Flush() end
    chunk[#chunk + 1] = n
    len = len + #n + 1
  end
  Flush()
end

---------------------------------------------------------------------------
-- Raid sessions: start / end. Awards and spends carry the session id, the
-- end event carries everyone who was there (attendance).
---------------------------------------------------------------------------
-- v0.2.34: raids belong to a raid team. A raid is "mine" when its creator,
-- starter or raid leader is in my raid group. With one raid going it's
-- everyone's (so it still works if the officer who made it leaves); with two
-- teams running at once each group gets its own.
local function MineRaid(ses)
  if not ses or not D.InRaid() then return false end
  for n in pairs(D.raid) do
    if (ses.leader and D.SameName(n, ses.leader)) or (ses.createdBy and D.SameName(n, ses.createdBy))
      or (ses.by and D.SameName(n, ses.by)) then return true end
  end
  return false
end
D.MineRaid = MineRaid

local function RaidFor(list)
  local d = D.data
  if not d or not list or #list == 0 then return nil end
  for _, ses in ipairs(list) do if MineRaid(ses) then return ses end end
  -- another raid is tied to my group, so these aren't
  for _, l in ipairs({ d.openList or {}, d.plannedList or {} }) do
    for _, ses in ipairs(l) do if MineRaid(ses) then return nil end end
  end
  if #(d.openList or {}) + #(d.plannedList or {}) == 1 then return list[1] end
  if not D.InRaid() then return list[1] end
  return nil
end

function D.OpenSession() return D.data and RaidFor(D.data.openList) end
-- created with Create raid, not started yet
function D.PlannedRaid() return D.data and RaidFor(D.data.plannedList) end

-- the raid leader's name right now (nil outside a group)
function D.RaidLeader()
  if D.InRaid() then
    for i = 1, D.GroupSize() do
      local n, rank = GetRaidRosterInfo(i)
      if n and not Secret(n) and rank == 2 then return D.Canon(Short(n)) end
    end
  end
  if UnitIsGroupLeader and UnitIsGroupLeader("player") then return Me() end
  return nil
end

-- v0.2.34: undo my own create of a raid another officer made first
-- (only the creator does it, so nobody undoes the same thing twice)
local fixedDup = {}
function D.FixDuplicateRaids()
  if not D.data or D.practice or not D.IsAdmin() then return end
  for _, ses in pairs(D.data.sessions) do
    if ses.dupOf and not ses.start and not ses.ended and ses.cId and not fixedDup[ses.cId]
      and not D.data.undone[ses.cId] and D.SameName(ses.createdBy or "", Me()) then
      fixedDup[ses.cId] = true
      D.Undo(ses.cId, "Duplicate raid - another officer created it first")
      Print(("Another officer created %s first - removed your copy."):format(ses.title or "the raid"))
    end
  end
end
-- the raid tonight's awards, loot and bench belong to: running, else created
function D.CurrentRaid() return D.OpenSession() or D.PlannedRaid() end

-- the key awards are grouped by: the current raid, else today's realm date
function D.NightKey()
  local s = D.CurrentRaid()
  return s and s.id or D.RealmDate()
end

local function NewSessionId()
  return "S" .. GetServerTime() .. Clean(D.FirstName(Me()), 12) .. ((D.db.counter or 0) + 1)
end

-- Has this raid already had this award (ONTIME / CLEAR)? Undone ones don't count.
function D.RaidAwardGiven(cat, key)
  key = key or D.NightKey()
  local night = D.data and D.data.byNight[key]
  if not night then return false end
  for _, e in ipairs(night.awards) do
    if e.x == cat and not D.data.undone[e.id] then return true end
  end
  return false
end

-- Everyone in the raid right now plus bench (sign-up bench and in-game bench)
local function RaidPlusBench()
  local chk, set, names = D.RaidCheck(), {}, {}
  for n in pairs(D.raid) do set[n] = true end
  for _, n in ipairs(chk.bench) do set[n] = true end
  for n in pairs(set) do names[#names + 1] = n end
  table.sort(names)
  return names
end

-- Step 1: Create raid. Nothing is awarded; bench, loot and awards from now on
-- belong to this raid. Officers can do this while people are still forming up.
function D.CreateRaid(title)
  if not NeedAdmin() then return end
  -- v0.2.34: one raid per raid team. CurrentRaid() is my group's raid (or,
  -- outside a raid, the latest one), so a second team can still make theirs.
  local cur = D.CurrentRaid()
  if cur then
    Print(("Can't create another raid: %s is already %s%s."):format(cur.title or "a raid",
      cur.start and "running" or "created", cur.createdBy and (" by " .. (D.FirstName(cur.createdBy) or cur.createdBy)) or ""))
    return
  end
  local ev = D.TonightEvent()
  title = (title and title ~= "") and title or (ev and ev.title) or ("Raid " .. D.RealmDate())
  NewEvent({ k = "SN", x = NewSessionId(), r = title, v = ev and ev.id or nil, u = "C", p = D.RaidLeader() })
  Print(("Raid created: %s. Press Start raid when it begins - everyone in the raid then gets the on-time bonus."):format(title))
end

-- Step 2: Start raid. Everyone in the raid (plus bench) gets the on-time award.
-- With no raid created first, this creates and starts one in a single step.
function D.StartSession(title)
  if not NeedAdmin() then return end
  if D.OpenSession() then Print("A raid is already running: " .. (D.OpenSession().title or "?")) return end
  local planned = D.PlannedRaid()
  local id
  if planned then
    id = planned.id
    title = (title and title ~= "") and title or planned.title
    NewEvent({ k = "SN", x = id, r = title, v = planned.eventId, u = "S", p = planned.leader or D.RaidLeader() })
  else
    local ev = D.TonightEvent()
    title = (title and title ~= "") and title or (ev and ev.title) or ("Raid " .. D.RealmDate())
    id = NewSessionId()
    NewEvent({ k = "SN", x = id, r = title, v = ev and ev.id or nil, u = "S", p = D.RaidLeader() })
  end
  D.db.seen = { [id] = {} }
  for n in pairs(D.raid) do D.db.seen[id][n] = true end
  Print("Raid started: " .. title)
  local amount = tonumber(D.Cfg("ONTIME")) or 0
  if amount <= 0 then return end
  if D.RaidAwardGiven("ONTIME", id) then Print("On-time was already given for this raid - not giving it again.") return end
  local names = RaidPlusBench()
  if #names == 0 then Print("Nobody in the raid yet, so no on-time award. Use the On-time button once they're in.") return end
  D.Award(names, amount, "On-time", "ONTIME", id)
end
-- Delete a raid made by mistake. Like every undo, nothing is erased: the start
-- event gets a correction, so the raid drops off the list (and the log shows who did it).
-- withDKP also undoes every award and item spend tagged to that raid.
function D.DeleteRaid(key, withDKP)
  if not NeedAdmin() or not D.data then return end
  local ses = D.data.sessions[key]
  local night = D.data.byNight[key]
  local n = 0
  if withDKP and night then
    for _, list in ipairs({ night.awards, night.spends }) do
      for _, e in ipairs(list) do
        if not D.data.undone[e.id] then D.Undo(e.id, "Raid deleted"); n = n + 1 end
      end
    end
  end
  if ses then -- undo both the create and the start
    local did = {}
    for _, eid in ipairs({ ses.snId or false, ses.cId or false }) do
      if eid and not did[eid] and not D.data.undone[eid] then did[eid] = true; D.Undo(eid, "Raid deleted") end
    end
  end
  Print(("Deleted %s%s."):format(ses and (ses.title or "raid") or ("raid night " .. key),
    withDKP and (" and undid %d award/loot entr%s"):format(n, n == 1 and "y" or "ies") or " (its DKP stays)"))
end

-- Upcoming Raid-Helper raids can't be deleted from here (Discord owns them),
-- but each person can hide one from their own list
function D.HideEvent(id)
  D.settings.hiddenEvents = D.settings.hiddenEvents or {}
  D.settings.hiddenEvents[tostring(id)] = true
  D.Refresh()
end

-- Step 3: End raid. withClear = everyone in the raid now (plus bench) gets the
-- full clear / raid completion award; then the attendance list is written.
function D.EndSession(withClear)
  if not NeedAdmin() then return end
  local ses = D.OpenSession()
  if not ses then
    local planned = D.PlannedRaid()
    if planned then
      Print(("%s was created but never started. Start it, or right-click it on the Raids tab to delete it."):format(planned.title or "The raid"))
    else
      Print("No raid is running.")
    end
    return
  end
  if D.PodiumBegin then pcall(D.PodiumBegin, ses) end -- v1.5.0: collect stats for the awards screen
  if withClear then
    local amount = tonumber(D.Cfg("CLEAR")) or 0
    if amount > 0 and D.RaidAwardGiven("CLEAR", ses.id) then
      Print("Full clear was already given for this raid - not giving it again.")
    elseif amount > 0 then
      local names = RaidPlusBench()
      if #names > 0 then D.Award(names, amount, "Full clear", "CLEAR", ses.id) end
    end
  end
  local set = {}
  for n in pairs((D.db.seen and D.db.seen[ses.id]) or {}) do set[n] = true end
  for n in pairs(D.raid) do set[n] = true end
  for _, n in ipairs(D.Bench()) do set[n] = true end
  local names = {}
  for n in pairs(set) do names[#names + 1] = n end
  table.sort(names)
  if #names == 0 then names = { Me() } end
  D.WriteChunked(names, { k = "SE", x = ses.id, r = ses.title })
  Print(("Raid ended: %s (%d attended)."):format(ses.title or "?", #names))
end

---------------------------------------------------------------------------
-- Award toasts: "+15 DKP, boss down". Guild members from the ledger; pugs
-- from the officer's AN note plus the next standings broadcast.
---------------------------------------------------------------------------
local awardToasts = {}
local function QueueAwardToast(e)
  if e.k ~= "AW" or GetServerTime() - (e.t or 0) > 300 then return end
  for _, n in ipairs(SplitNames(e.p)) do
    if D.SameName(n, Me()) then awardToasts[#awardToasts + 1] = e return end
  end
end
D.QueueAwardToast = QueueAwardToast

local TOAST_TITLE = { BOSS = "Boss down!", ONTIME = "On-time bonus", CLEAR = "Full clear!", BENCH = "Standby award" }
function D.FlushAwardToasts()
  if #awardToasts == 0 then return end
  local list = awardToasts
  awardToasts = {}
  if D.settings.awardToasts == false then return end
  -- v0.2.37: one toast per award, however many times it reaches us
  D.toastedAwards = D.toastedAwards or {}
  local now = GetTime()
  for _, e in ipairs(list) do
    local key = (e.x or "") .. "|" .. (e.r or "") .. "|" .. (e.g or "")
    local seen = D.toastedAwards[key]
    if seen and now - seen < 600 then e = nil else D.toastedAwards[key] = now end
    if e and not D.data.undone[e.id] then
      local amt = tonumber(e.v) or 0
      local reason = (e.r or ""):gsub("^Boss kill: ", "")
      D.Toast(("%s  %s%d DKP"):format(TOAST_TITLE[e.x] or "DKP awarded", amt >= 0 and "+" or "", amt),
        ("%s · you now have %d"):format(reason, D.Balance(Me())))
    end
  end
end

-- v0.5.0: loot reveal. An item award (SP) that reaches us right when it
-- happens pops a banner - if I won it, or the winner is in my raid / party.
-- Never for old events arriving in a catch-up sync, once per event.
local lootReveals = {}
function D.QueueLootReveal(e)
  if e.k ~= "SP" or not e.p or GetServerTime() - (e.t or 0) > 90 then return end
  lootReveals[#lootReveals + 1] = e
end

function D.FlushLootReveals()
  if #lootReveals == 0 then return end
  local list = lootReveals
  lootReveals = {}
  if D.settings.lootReveal == false or not D.ShowReveal then return end
  D.revealed = D.revealed or {}
  for _, e in ipairs(list) do
    local mine = D.SameName(e.p, Me())
    local inMyGroup = false -- the winner is in my raid / party (not some other team's raid)
    if not mine then
      for n in pairs(D.raid) do if D.SameName(n, e.p) then inMyGroup = true break end end
    end
    if not D.revealed[e.id] and not (D.data.undone and D.data.undone[e.id]) and (mine or inMyGroup or D.practice) then
      D.revealed[e.id] = true
      D.ShowReveal({
        item = tonumber(e.x), name = e.r, who = e.p, price = tonumber(e.v) or 0, os = e.u == "OS",
        mine = mine, left = mine and D.Balance(e.p) or nil,
      })
    end
  end
end

-- one player's tallies: stats, streak = { best, cur }
function D.FameStats(name, scope)
  local f = D.data and D.data.fame
  if not f or not name then return nil end
  scope = scope == "phase" and "phase" or "all"
  local pool = D.Pool(name)
  return f.stats[scope][pool], f.streak[scope][pool]
end

-- v0.7.3: badge art. Custom icons live in Media\Badges\<file>.tga (32-bit TGA, power-of-two size). A badge without
-- custom = true (a new one, say) falls back to the game icon named here. v0.7.4: all six have art.
D.BADGE_ART = {
  ["Iron Attendance"] = { file = "IronAttendance", custom = true, spell = 465 },       -- Devotion Aura
  ["Veteran"] = { file = "Veteran", custom = true, spell = 6673 },                     -- Battle Shout
  ["Big Spender"] = { file = "BigSpender", custom = true, path = "Interface\\Icons\\INV_Misc_Coin_02" },
  ["Top Bid"] = { file = "TopBid", custom = true, item = 29434 },                      -- Badge of Justice
  ["Flask Master"] = { file = "FlaskMaster", custom = true, item = 22854 },            -- Flask of Relentless Assault
  ["Collector"] = { file = "Collector", custom = true, item = 21841 },                 -- Netherweave Bag
}
local BADGE_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
function D.BadgeIcon(label)
  local a = D.BADGE_ART[label]
  if not a then return BADGE_FALLBACK end
  if a.custom then return "Interface\\AddOns\\GuildLadderDKP\\Media\\Badges\\" .. a.file .. ".tga" end
  local tex
  if a.spell and GetSpellTexture then tex = GetSpellTexture(a.spell) end
  if not tex and a.item and GetItemIcon then tex = GetItemIcon(a.item) end
  return tex or a.path or BADGE_FALLBACK
end
-- the icon as inline text (works in any FontString and tooltip line)
function D.BadgeInline(label, size)
  size = size or 16
  return ("|T%s:%d:%d|t"):format(tostring(D.BadgeIcon(label)), size, size)
end
-- all of a player's badge icons in a row, for the Standings list
function D.BadgeStrip(name, size, max)
  local out, n = {}, 0
  for _, b in ipairs(D.Badges(name)) do
    n = n + 1
    if max and n > max then break end
    out[#out + 1] = D.BadgeInline(b.label, size)
  end
  return table.concat(out, " ")
end

-- badges earned, all derived from the ledger: { { label, hex, tip }, ... }
function D.Badges(name)
  local f = D.data and D.data.fame
  local out = {}
  if not f or not name then return out end
  local pool = D.Pool(name)
  local s, st = f.stats.all[pool], f.streak.all[pool]
  local T = D.FAME
  local function Add(label, hex, tip) out[#out + 1] = { label = label, hex = hex, tip = tip } end
  if st and st.cur >= T.STREAK then Add("Iron Attendance", "ffe0b04f", ("%d raids in a row"):format(st.cur)) end
  if s and s.nights >= T.VETERAN then Add("Veteran", "ff9bc9ff", ("%d raids attended"):format(s.nights)) end
  local top = f.top.all
  if top.spent and top.spent.pool == pool then Add("Big Spender", "fff2a54a", ("most DKP spent (%d)"):format(top.spent.v)) end
  local w = f.wins.all[1]
  if w and w.who == pool then Add("Top Bid", "ffff7a6b", ("paid %d for %s"):format(w.price, w.name or "an item")) end
  if s and s.prepared >= T.PREPARED then Add("Flask Master", "ff8fe0c4", ("prepared for %d pulls"):format(s.prepared)) end
  if s and s.items >= T.COLLECTOR then Add("Collector", "ffc9a0ff", ("%d items won"):format(s.items)) end
  return out
end

D.handlers.AN = function(p, sender, channel)
  if channel ~= "RAID" or D.roster[sender] then return end -- guildies get it from the ledger
  D.lastAN = { amount = tonumber(p[2]) or 0, reason = p[3], cat = p[4], t = GetTime() }
end

-- names: list of players, amount, reason text, cat: ONTIME / BOSS / CLEAR / BENCH / CUSTOM
-- g: raid key to file it under (default: the current raid, else today)
function D.Award(names, amount, reason, cat, g)
  if not NeedAdmin() then return end
  amount = math.floor(tonumber(amount) or 0)
  if amount == 0 or #names == 0 then return end
  -- big raids go out in chunks so each message stays under the size limit
  D.WriteChunked(names, { k = "AW", v = amount, x = cat or "CUSTOM", r = reason, g = g or D.NightKey() })
  if D.InRaid() and not D.practice then Send(Pack("AN", amount, Clean(reason, 60), cat or "CUSTOM"), "RAID") end
  Print(("+%d to %d players: %s"):format(amount, #names, reason or ""))
end

function D.Adjust(name, amount, reason)
  if not NeedAdmin() then return end
  amount = math.floor(tonumber(amount) or 0)
  if amount == 0 or not name or name == "" then return end
  return NewEvent({ k = "AD", p = name, v = amount, r = reason or "Adjustment" })
end

-- Put a player back on (or onto) the Standings list, with no raid needed and
-- no minimum amount - unlike Adjust, 0 is allowed, since the point here may
-- just be to make them visible again (e.g. every one of their events got
-- undone). Once they're showing, right-click → Adjust sets the real number.
function D.AddPlayer(name, amount, reason)
  if not NeedAdmin() then return end
  name = D.Canon(name)
  if not name or name == "" then Print("Type a player name.") return end
  amount = math.floor(tonumber(amount) or 0)
  -- v0.2.35: typing the name of someone who was removed from standings now
  -- restores them (it used to add a +0 entry and leave them hidden)
  if D.data and D.data.hidden[D.Pool(name)] then
    D.SetHidden(name, false)
    if amount == 0 then return end
  end
  return NewEvent({ k = "AD", p = name, v = amount, r = reason or "Added to standings" })
end

-- Guild roster members with no ledger entry at all right now (never had one,
-- or everything they had got undone) - alts of someone already listed are
-- left off, so this doesn't invite creating a second, disconnected balance
-- for them under their own name.
function D.MissingPlayers()
  local list = {}
  if not D.roster then return list end
  for name in pairs(D.roster) do
    local canon = D.Canon(name)
    if D.Pool(canon) == canon and (not D.data or not D.data.bal[canon]) then
      list[#list + 1] = canon
    end
  end
  table.sort(list)
  return list
end

-- Hide/restore a player on Standings without touching their ledger history -
-- for people who've left (a guildie or a pug who stopped raiding with us).
-- Same append-only shape as everything else: an "HD" flag event, latest one
-- wins, nothing is deleted, so a later "+ Add player" (hidden players show
-- there too) brings them straight back with their old balance intact.
function D.SetHidden(name, hide)
  if not NeedAdmin() then return end
  name = D.Canon(name)
  if not name or name == "" then return end
  return NewEvent({ k = "HD", p = name, v = hide and "1" or "0",
    r = hide and "Removed from standings" or "Restored to standings" })
end

-- Players currently hidden (have a balance, just not shown) - offered
-- alongside MissingPlayers() in the "+ Add player" menu as "restore".
function D.HiddenPlayers()
  local list = {}
  if not D.data then return list end
  for n in pairs(D.data.hidden) do
    if D.data.bal[n] then list[#list + 1] = n end
  end
  table.sort(list)
  return list
end

-- Manually set a character's class for display (color-coding, the Discord
-- bot's "Cls" column). D.ClassOf normally learns this by seeing them in the
-- guild roster or your raid group; this is for pugs you haven't grouped
-- with yet, or whenever you'd rather not wait for that. Local to your own
-- client/account - not a ledger event, so it doesn't sync to other officers,
-- but it IS what the bot snapshot reads from, since that's written from
-- your account's SavedVariables.
function D.SetClassOverride(name, classFile)
  if not NeedAdmin() then return end
  if not D.db then return end
  D.db.classCache = D.db.classCache or {}
  D.db.classCache[D.Canon(name)] = classFile
  ScheduleCompute()
  D.Refresh()
end

-- spec: "MS" or "OS" (stored in u)
function D.Spend(name, amount, itemID, itemName, spec)
  if not NeedAdmin() then return end
  return NewEvent({ k = "SP", p = name, v = math.max(0, math.floor(tonumber(amount) or 0)), x = itemID, r = itemName,
    u = spec == "OS" and "OS" or nil, g = D.NightKey() })
end

function D.Undo(id, reason)
  if not NeedAdmin() then return end
  if D.data and D.data.undone[id] then Print("That entry is already undone.") return end
  return NewEvent({ k = "UN", u = id, r = reason or "Undo" })
end

function D.Decay(pct, autoKey)
  if autoKey then
    if not D.IsAdmin() then return end -- v0.4.6: the automatic one runs on any officer's client
  elseif not D.IsGM() and not D.practice then
    Print("Only the guild master can run decay.") return
  end
  pct = tonumber(pct) or tonumber(D.Cfg("DECAY_PCT"))
  if not pct or pct <= 0 then return end
  local ev = NewEvent({ k = "DC", v = pct, r = autoKey and "Weekly decay (automatic)" or "Weekly decay",
    x = autoKey and ("AUTO:" .. autoKey) or nil })
  -- v0.2.36: tell the guild, so nobody wonders where their DKP went
  if ev and not D.practice then
    -- the automatic one has no click behind it, so its chat line goes out on the next key press
    D.Chat(("Weekly DKP decay: -%d%% applied to every positive balance. Check your log (/dkp) to see yours.")
      :format(pct), "GUILD", nil, not autoKey)
    if autoKey then
      Print(("Weekly decay -%d%% applied automatically."):format(pct))
      if D.Toast then D.Toast("Weekly decay", ("-%d%% applied automatically"):format(pct)) end
    end
  end
  return ev
end

-- What decay would do, without doing it: { {name, before, after}, ... }
function D.DecayPreview(pct)
  pct = tonumber(pct) or tonumber(D.Cfg("DECAY_PCT")) or 0
  local list = {}
  for _, s in ipairs(D.Standings()) do
    local after = s.dkp > 0 and math.floor(s.dkp * (100 - pct) / 100 + 0.5) or s.dkp
    list[#list + 1] = { name = s.name, before = s.dkp, after = after }
  end
  return list
end

---------------------------------------------------------------------------
-- v0.4.6: automatic weekly decay. The GM picks a day and a realm time
-- (DECAY_AUTO / DECAY_DAY / DECAY_TIME). When that time has passed and no
-- decay has happened since, one online officer's add-on posts it: the officer
-- whose name sorts first goes after 30 s, the next one 2 minutes later, and so
-- on, each checking first that nobody beat them to it. Nobody online at the
-- time? The first officer on afterwards does it - once, however many weeks were
-- missed. It waits while a raid is running or an auction is open. The decay
-- carries the week's key ("AUTO:YYYY-MM-DD"), and the ledger only counts the
-- first one per key, so a stale ledger can't decay twice.
---------------------------------------------------------------------------
-- a timestamp whose UTC fields read as realm time, and the offset used
local function RealmEpoch()
  local now = GetServerTime()
  local u = date("!*t", now)
  local diff = D.RealmMinutes() - (u.hour * 60 + u.min)
  if diff > 720 then diff = diff - 1440 elseif diff < -720 then diff = diff + 1440 end
  return now + diff * 60, diff * 60
end

-- the latest scheduled time at or before now: key ("YYYY-MM-DD", realm date),
-- its server time, and its realm-time stamp (for showing it)
local function LastScheduled()
  local wday = tonumber(D.Cfg("DECAY_DAY"))
  local hh, mm = tostring(D.Cfg("DECAY_TIME") or ""):match("^(%d+):(%d+)$")
  if not wday or wday < 1 or wday > 7 or not hh then return nil end
  local want = tonumber(hh) * 60 + tonumber(mm)
  local rNow, off = RealmEpoch()
  local t = date("!*t", rNow)
  local nowMin = t.hour * 60 + t.min
  local back = (t.wday - wday) % 7
  if back == 0 and nowMin < want then back = 7 end
  local occR = rNow - back * 86400 + (want - nowMin) * 60 - t.sec
  return date("!%Y-%m-%d", occR), occR - off, occR
end

-- when the GM last switched it on or changed the day / time: earlier slots don't count
local function ScheduleSetAt()
  local latest = 0
  for _, e in pairs(D.db.events) do
    if e.k == "CFG" and (e.x == "DECAY_AUTO" or e.x == "DECAY_DAY" or e.x == "DECAY_TIME") and RankOk(e.by, 0)
        and (e.t or 0) > latest then
      latest = e.t
    end
  end
  return latest
end

-- key, server time of the slot - or nil when nothing is due
function D.DecayDue()
  if not D.db or not D.data then return nil end
  if (tonumber(D.Cfg("DECAY_AUTO")) or 0) ~= 1 then return nil end
  local key, at = LastScheduled()
  if not key or at <= ScheduleSetAt() then return nil end
  for _, e in pairs(D.db.events) do
    if e.k == "DC" and (e.t or 0) >= at - 60 then return nil end -- already decayed this week (by hand or automatically)
  end
  return key, at
end

local autoWait, onlineSince = {}, nil
function D.AutoDecayTick()
  if not D.ready or D.practice or not D.IsAdmin() then return end
  onlineSince = onlineSince or GetTime()
  if GetTime() - onlineSince < 180 then return end -- let my ledger sync for a few minutes after logging in
  local key = D.DecayDue()
  if not key then return end
  if D.auction or D.OpenSession() then return end -- not mid-raid, not mid-bid
  local list = { Me() }
  for _, n in ipairs((D.SyncSummary())) do list[#list + 1] = n end
  table.sort(list)
  local pos = 1
  for i, n in ipairs(list) do if n == Me() then pos = i end end
  if not autoWait[key] then
    autoWait[key] = GetTime() + 30 + (pos - 1) * 120
    return
  end
  if GetTime() < autoWait[key] then return end
  autoWait[key] = GetTime() + 600 -- if it somehow didn't land, try again in 10 minutes
  D.Decay(tonumber(D.Cfg("DECAY_PCT")), key)
end
C_Timer.NewTicker(60, function() pcall(D.AutoDecayTick) end)

-- one line for Settings > Data
function D.DecayStatusText()
  local pct = tostring(D.Cfg("DECAY_PCT"))
  if (tonumber(D.Cfg("DECAY_AUTO")) or 0) ~= 1 then return "Off - decay only runs when the guild master runs it by hand." end
  local key, _, occR = LastScheduled()
  if not key then return "Pick a day and a time." end
  if D.DecayDue() then return ("Due now (-%s%%): the next officer online applies it."):format(pct) end
  return ("Next: %s realm time, -%s%%"):format(date("!%a %b %d, %H:%M", occR + 7 * 86400), pct)
end

-- v0.4.6: a Raid-Helper event that already has a raid made from it
function D.EventHasRaid(id)
  if id == nil or not D.data or not D.data.sessions then return false end
  local key = tostring(id)
  for _, ses in pairs(D.data.sessions) do
    if ses.eventId ~= nil and tostring(ses.eventId) == key then return true end
  end
  return false
end

function D.SetConfig(key, value)
  if not D.IsGM() then Print("Only the guild master can change settings.") return end
  return NewEvent({ k = "CFG", x = key, v = value })
end

function D.SetBossValue(boss, value)
  if not D.IsGM() then Print("Only the guild master can change boss values.") return end
  return NewEvent({ k = "CFG", x = "BV:" .. Clean(boss, 60), v = value or "" })
end

function D.SetItemNote(itemID, note, minBid)
  if not NeedAdmin() then return end
  return NewEvent({ k = "IN", x = itemID, r = note, v = minBid })
end

function D.LinkDiscord(char, discordId)
  if not NeedAdmin() then return end
  -- v0.3.4: linking a sign-up to a character REPLACES whoever it was linked to
  -- before (it used to add a second link, so a wrong link couldn't be fixed)
  if D.data and discordId and discordId ~= "" then
    for other, id in pairs(D.data.links) do
      if id == discordId and other ~= char then NewEvent({ k = "LK", p = other, x = "" }) end
    end
  end
  return NewEvent({ k = "LK", p = char, x = discordId })
end

-- Events only I can write about myself (wishlist, alt links). Never practice.
local function PlayerEvent(k, x, v)
  if not D.db then return end
  if D.practice then Print("Not available in practice mode.") return end
  local e = { k = k, p = Me(), x = Clean(x, 80), v = v }
  e.t = GetServerTime()
  e.by = Me()
  D.db.counter = (D.db.counter or 0) + 1
  e.id = Clean(Me(), 40) .. "-" .. k .. D.db.counter .. "-" .. e.t
  StoreEvent(e)
  Send(EventMsg(e), nil, nil, true) -- v0.2.41: ahead of sync resends
  ScheduleCompute()
end

function D.Wish(itemID, on)
  if itemID then PlayerEvent("WL", itemID, on and "1" or "0") end
end

---------------------------------------------------------------------------
-- Alt linking. Each side says it once: the alt names its main, the main
-- accepts the alt. Characters on the same account do the main's half
-- automatically the next time the main logs in, so it's one click total.
-- Officers can link or unlink anyone directly (different accounts, mistakes).
---------------------------------------------------------------------------
local function AccountChars()
  GuildLadderDKPDB.chars = GuildLadderDKPDB.chars or {}
  local t = GuildLadderDKPDB.chars[D.guildKey] or {}
  GuildLadderDKPDB.chars[D.guildKey] = t
  return t
end

function D.MyOtherChars()
  local list = {}
  for name in pairs(AccountChars()) do
    if name ~= Me() then list[#list + 1] = name end
  end
  table.sort(list)
  return list
end

local function PendingAccepts()
  GuildLadderDKPDB.pendingAlt = GuildLadderDKPDB.pendingAlt or {}
  local t = GuildLadderDKPDB.pendingAlt[D.guildKey] or {}
  GuildLadderDKPDB.pendingAlt[D.guildKey] = t
  return t
end

-- I'm an alt of <main>
function D.ClaimMain(main)
  main = D.Canon(D.ResolveName(main))
  if not main or main == "" or main == Me() then return end
  PlayerEvent("AL", main, "1")
  AccountChars()[Me()].decided = true
  if AccountChars()[main] then
    -- same account: the main confirms by itself next login
    local pend = PendingAccepts()
    pend[main] = pend[main] or {}
    pend[main][Me()] = true
    Print(("Linked as an alt of %s. It finishes the next time you log in on %s."):format(main, main))
  else
    Print(("Asked to link as an alt of %s. %s has to accept (a popup shows when they're online), or an officer can link you."):format(main, main))
  end
end

function D.AcceptAlt(alt, yes)
  if not alt then return end
  PlayerEvent("AM", alt, yes == false and "0" or "1")
end

function D.UnlinkMe()
  local main = D.MainOf(Me())
  if main then PlayerEvent("AL", main, "0") end
  for _, alt in ipairs(D.AltsOf(Me())) do PlayerEvent("AM", alt, "0") end
  AccountChars()[Me()].decided = true
end

function D.MarkMain()
  AccountChars()[Me()].decided = true
end

function D.OfficerLink(alt, main)
  if not NeedAdmin() then return end
  alt = D.Canon(D.ResolveName(alt))
  main = main and main ~= "" and D.Canon(D.ResolveName(main)) or ""
  return NewEvent({ k = "AO", p = alt, x = main })
end

-- At login: finish same-account links, and ask once whether this is an alt
local function CheckAltsAtLogin()
  local mine = AccountChars()
  mine[Me()] = mine[Me()] or {}
  mine[Me()].class = select(2, UnitClass("player"))
  local pend = PendingAccepts()[Me()]
  if pend then
    for alt in pairs(pend) do
      if not (D.data.accept[Me()] and D.data.accept[Me()][alt]) then D.AcceptAlt(alt, true) end
    end
    PendingAccepts()[Me()] = nil
  end
  local linked = D.MainOf(Me()) or #D.AltsOf(Me()) > 0 or D.data.claim[Me()]
  if not linked and not mine[Me()].decided and #D.MyOtherChars() > 0 and D.AskAltLink then
    C_Timer.After(4, D.AskAltLink)
  end
end

-- Someone says they're my alt and I haven't answered: offer it
local askedAlt = {}
function D.CheckAltClaims()
  if not D.data then return end
  for alt, main in pairs(D.data.claim) do
    if main == Me() and not askedAlt[alt] and not (D.data.accept[Me()] and D.data.accept[Me()][alt] ~= nil) then
      askedAlt[alt] = true
      D.Toast("Alt link request", alt .. " says they're your alt. Click to accept.", function() D.AcceptAlt(alt, true) end)
    end
  end
end

-- v0.3.1: the win that fulfilled a wish - the player (or one of their alts /
-- their main) won the item after putting it on their wishlist. nil = still wanted.
function D.WishWon(itemID, name)
  if not D.data then return nil end
  local t = D.data.wishT and D.data.wishT[itemID] and D.data.wishT[itemID][name]
  local wins = D.WinsFor(itemID) -- v0.7.2: a tier piece counts its token's wins
  if not t or #wins == 0 then return nil end
  local pool = D.Pool(name)
  local best
  for _, w in ipairs(wins) do
    if (w.t or 0) >= t - 60 and D.Pool(w.who or "") == pool and (not best or w.t > best.t) then best = w end
  end
  return best
end

-- clear every won item off my wishlist
function D.ClearWonWishes()
  local n = 0
  for _, id in ipairs(D.MyWishes()) do
    if D.WishWon(id, Me()) then D.Wish(id, false); n = n + 1 end
  end
  return n
end

function D.MyWishes()
  local list = {}
  if not D.data then return list end
  for id, set in pairs(D.data.wishes) do
    if set[Me()] then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

-- Starting balances from Guild Ladder points (rate and cap from settings).
-- Reads Guild Ladder's own saved snapshot, so Guild Ladder needs to be installed.
function D.ImportLadder()
  if not D.IsGM() then Print("Only the guild master can import starting balances.") return end
  local g = GuildLadderDB and GuildLadderDB.guilds and GuildLadderDB.guilds[D.guildKey]
  local totals = g and g.snapshot and g.snapshot.totals
  if not totals then Print("No Guild Ladder points found for this guild. Open Guild Ladder once, then /reload.") return end
  local have = {}
  for _, e in ipairs(D.data.log) do
    if e.k == "SB" and not D.data.undone[e.id] then have[e.p] = true end
  end
  local rate, cap = tonumber(D.Cfg("DKP_RATE")) or 0.25, tonumber(D.Cfg("DKP_CAP")) or 200
  local n = 0
  for name, pts in pairs(totals) do
    local dkp = math.min(math.floor(math.max(pts, 0) * rate), cap)
    if dkp > 0 and not have[name] then
      NewEvent({ k = "SB", p = name, v = dkp, r = "Starting balance (" .. pts .. " ladder points)" })
      n = n + 1
    end
  end
  Print(("Starting balances written for %d players (already imported players skipped)."):format(n))
end

---------------------------------------------------------------------------
-- Minimal JSON decoder - just enough for CLM's `/clm export` (JSON format)
-- output: objects, arrays, strings, numbers, booleans.
---------------------------------------------------------------------------
local function JSONDecode(str)
  local pos = 1
  local function err(msg) error(("JSON error near position %d: %s"):format(pos, msg)) end
  local function skipWS() local _, e = str:find("^%s*", pos); pos = e + 1 end
  local parseValue

  local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
  local function utf8From(cp)
    if cp < 0x80 then return string.char(cp)
    elseif cp < 0x800 then return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    else return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40) end
  end
  -- Jumps straight to the next quote or backslash instead of walking one
  -- character at a time: a few months of CLM loot history is ~1 MB of JSON.
  local function parseString()
    pos = pos + 1
    local buf = {}
    while true do
      local s = str:find('["\\]', pos)
      if not s then err("unterminated string") end
      if s > pos then buf[#buf + 1] = str:sub(pos, s - 1) end
      pos = s
      if str:sub(pos, pos) == '"' then pos = pos + 1; break end
      local n = str:sub(pos + 1, pos + 1)
      if n == "u" then
        local cp = tonumber(str:sub(pos + 2, pos + 5), 16) or 63
        buf[#buf + 1] = utf8From(cp)
        pos = pos + 6
      else
        buf[#buf + 1] = ESCAPES[n] or n
        pos = pos + 2
      end
    end
    return table.concat(buf)
  end

  local function parseNumber()
    local s, e, num = str:find("^(%-?%d+%.?%d*[eE]?[+%-]?%d*)", pos)
    if not s then err("bad number") end
    pos = e + 1
    return tonumber(num)
  end

  local function parseArray()
    pos = pos + 1; skipWS()
    local arr = {}
    if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
    while true do
      arr[#arr + 1] = parseValue()
      skipWS()
      local c = str:sub(pos, pos)
      if c == "," then pos = pos + 1; skipWS()
      elseif c == "]" then pos = pos + 1; break
      else err("expected , or ] in array") end
    end
    return arr
  end

  local function parseObject()
    pos = pos + 1; skipWS()
    local obj = {}
    if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
    while true do
      skipWS()
      if str:sub(pos, pos) ~= '"' then err("expected string key") end
      local key = parseString()
      skipWS()
      if str:sub(pos, pos) ~= ":" then err("expected :") end
      pos = pos + 1; skipWS()
      obj[key] = parseValue()
      skipWS()
      local c = str:sub(pos, pos)
      if c == "," then pos = pos + 1
      elseif c == "}" then pos = pos + 1; break
      else err("expected , or } in object") end
    end
    return obj
  end

  parseValue = function()
    skipWS()
    local c = str:sub(pos, pos)
    if c == '"' then return parseString()
    elseif c == "{" then return parseObject()
    elseif c == "[" then return parseArray()
    elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
    elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
    elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
    elseif c:match("[%-%d]") then return parseNumber()
    else err("unexpected character '" .. c .. "'") end
  end

  skipWS()
  local ok, result = pcall(parseValue)
  if not ok then return nil, result end
  return result
end

---------------------------------------------------------------------------
-- Import from Core Loot Manager (`/clm export`, JSON format)
-- Standings: one-time starting balances (SB events), same already-have guard
--   as the Guild Ladder import above.
-- Loot History (v0.2.14): one HL record per item won, at the time it was
--   won. Records only - no balance changes (the standings import already has
--   every CLM spend taken out). Re-running skips items already imported, so a
--   long history can be pasted a month at a time.
---------------------------------------------------------------------------
local function ImportCLMRoster(roster)
  if not D.IsGM() then Print("Only the guild master can import CLM standings.") return end
  local have = {}
  for _, e in ipairs(D.data.log) do
    if e.k == "SB" and not D.data.undone[e.id] then have[e.p] = true end
  end
  local players = (roster.standings and roster.standings.player) or {}
  local n, skipped = 0, 0
  for _, pl in ipairs(players) do
    local name = pl.name and D.Canon(Short(pl.name))
    local dkp = math.floor(tonumber(pl.points) or 0)
    if name and name ~= "" then
      if have[name] then
        skipped = skipped + 1
      else
        NewEvent({ k = "SB", p = name, v = math.max(dkp, 0), r = "Starting balance (imported from CLM: " .. (roster.name or "?") .. ")" })
        have[name] = true
        n = n + 1
      end
    end
  end
  Print(("Imported %d player%s from CLM roster \"%s\" (%d already had a starting balance, skipped)."):format(n, n == 1 and "" or "s", roster.name or "?", skipped))
end
D.ImportCLMRoster = ImportCLMRoster -- used by the roster-picker menu in UI.lua

-- Raids that run past midnight stay on the night they started: anything
-- before 6 am counts for the day before. Uses the importing GM's clock; the
-- key is stored in the event, so everyone sees the same night.
local function CLMNightKey(t)
  return "CLM-" .. date("%Y-%m-%d", t - 6 * 3600)
end
D.CLMNightKey = CLMNightKey

local function LootKey(name, itemID, t) return (name or "") .. "#" .. tostring(itemID or "") .. "#" .. tostring(t or "") end

local function ImportCLMLootRoster(roster)
  if not D.IsGM() then Print("Only the guild master can import CLM loot history.") return end
  local have = {}
  for _, e in ipairs(D.data.log) do
    if e.k == "HL" and not D.data.undone[e.id] then have[LootKey(e.p, e.x, e.t)] = true end
  end
  local rows = {}
  for _, it in ipairs((roster.lootHistory and roster.lootHistory.item) or {}) do
    local ai = type(it.auctionInfo) == "table" and it.auctionInfo or {}
    local id = tonumber(it.id) or tonumber(ai.id)
    local t = tonumber(it.timestamp) or tonumber(ai.time)
    local name = it.player and D.Canon(Short(it.player))
    if id and t and name and name ~= "" then
      local spec = type(ai.names) == "table" and ai.names[it.player] or nil
      rows[#rows + 1] = { name = name, id = id, t = math.floor(t), price = math.max(0, math.floor(tonumber(it.points) or 0)),
        item = it.name, os = spec == "OS" }
    end
  end
  table.sort(rows, function(a, b) return a.t < b.t end)
  local n, skipped, nights, first, last = 0, 0, {}, nil, nil
  for _, r in ipairs(rows) do
    local key = LootKey(r.name, r.id, r.t)
    if have[key] then
      skipped = skipped + 1
    else
      local g = CLMNightKey(r.t)
      NewEvent({ k = "HL", t = r.t, p = r.name, v = r.price, x = r.id, r = r.item, u = r.os and "OS" or nil, g = g })
      have[key] = true
      nights[g] = true
      first, last = first or r.t, r.t
      n = n + 1
    end
  end
  local nn = 0
  for _ in pairs(nights) do nn = nn + 1 end
  Print(("Imported %d item%s from CLM roster \"%s\" across %d raid night%s%s (%d already imported, skipped). No DKP was changed."):format(
    n, n == 1 and "" or "s", roster.name or "?", nn, nn == 1 and "" or "s",
    first and (", " .. date("%b %d", first) .. " - " .. date("%b %d", last)) or "", skipped))
  if n > 0 and not D.practice then
    Print(("Sending to the guild takes about %s - stay online until then (if you don't, it catches up the next time you're on)."):format(
      n > 300 and (math.ceil(n / 300) .. " min") or (math.ceil(n / 5) .. " sec")))
  end
end
D.ImportCLMLootRoster = ImportCLMLootRoster

-- Take back every imported CLM loot record (GM; /dkp importclm undoloot)
-- v0.2.33: boss-kill awards logged while no raid was started - pug kills
-- awarded by officers on builds older than 0.2.32. An award belongs to a raid
-- through its night key (e.g); outside a raid that's just the date.
function D.StrayBossAwards()
  local out = {}
  if not D.data then return out end
  for _, e in ipairs(D.data.log) do
    if e.k == "AW" and e.x == "BOSS" and not D.data.undone[e.id] then
      local ses = e.g and D.data.sessions[e.g]
      if not (ses and ses.start and ses.start <= (e.t or 0) + 60) then out[#out + 1] = e end
    end
  end
  table.sort(out, function(a, b) return (a.t or 0) < (b.t or 0) end)
  return out
end

-- /dkp cleanup lists them, /dkp cleanup confirm undoes them (GM only)
function D.CleanupStrayBoss(confirm)
  if not D.IsGM() then Print("Only the guild master can do that.") return end
  local list = D.StrayBossAwards()
  if #list == 0 then Print("No boss-kill awards outside a started raid - nothing to clean up.") return end
  if not confirm then
    Print(("%d boss-kill award%s logged with no raid started:"):format(#list, #list == 1 and " was" or "s were"))
    for _, e in ipairs(list) do
      local n = #SplitNames(e.p)
      Print(("   %s  %s · %d player%s · +%s · by %s"):format(date("%b %d %H:%M", e.t or 0), e.r or "?",
        n, n == 1 and "" or "s", tostring(e.v or "?"), e.by or "?"))
    end
    Print("If those are all pug kills, type |cffe0b04f/dkp cleanup confirm|r to undo every one of them.")
    return
  end
  for _, e in ipairs(list) do D.Undo(e.id, "No raid started (pug kill)") end
  Print(("Undid %d boss-kill award%s. Players who only had DKP from those drop off the standings."):format(#list, #list == 1 and "" or "s"))
end

function D.UndoCLMLoot()
  if not D.IsGM() then Print("Only the guild master can do that.") return end
  local n = 0
  for _, e in ipairs(D.data.log) do
    if e.k == "HL" and not D.data.undone[e.id] then D.Undo(e.id, "CLM loot import removed"); n = n + 1 end
  end
  Print(("Removed %d imported CLM loot record%s."):format(n, n == 1 and "" or "s"))
end

-- One roster straight away, or a menu when the export has several
local function PickRoster(rosters, what, count, fn)
  if #rosters == 1 then fn(rosters[1]) return end
  if D.ShowMenu then
    local items = {}
    for _, r in ipairs(rosters) do
      items[#items + 1] = { ("%s (%d %s)"):format(r.name or "?", count(r), what), function() fn(r) end }
    end
    D.ShowMenu(UIParent, "Which CLM roster? (" .. what .. ")", items)
  else
    Print("That export has more than one roster; using the first one (" .. (rosters[1].name or "?") .. ").")
    fn(rosters[1])
  end
end

--- jsonText: the string pasted from CLM's `/clm export` (JSON format) -
--- Standings, Loot History, or both in one export.
function D.ImportCLM(jsonText)
  if not D.IsGM() then Print("Only the guild master can import from CLM.") return end
  if not jsonText or jsonText:gsub("%s", "") == "" then
    Print("Paste the JSON from CLM's /clm export first.")
    return
  end
  local ok, data = pcall(JSONDecode, jsonText)
  if not ok or type(data) ~= "table" then
    Print("Couldn't read that as JSON - make sure you copied the whole export string. (Very long exports: try a shorter time frame in CLM and import it in parts.)")
    return
  end
  local standings = data.standings and data.standings.roster
  local loot = data.lootHistory and data.lootHistory.roster
  local did = false
  if standings and #standings > 0 then
    did = true
    PickRoster(standings, "players", function(r) return #((r.standings and r.standings.player) or {}) end, ImportCLMRoster)
  end
  if loot and #loot > 0 then
    did = true
    PickRoster(loot, "items", function(r) return #((r.lootHistory and r.lootHistory.item) or {}) end, ImportCLMLootRoster)
  end
  if not did then
    Print("Nothing to import in that export. In CLM: /clm export, pick Standings and/or Loot History + JSON, then copy the whole string.")
  end
end

---------------------------------------------------------------------------
-- Guild roster and raid roster
---------------------------------------------------------------------------
function D.RequestRoster()
  if not IsInGuild() then return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
  elseif GuildRoster then GuildRoster() end
end

local function UpdateRoster()
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  if n == 0 then return end
  local r = {}
  for i = 1, n do
    local name, _, rankIndex, _, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
    if name and not Secret(name) then
      name = Short(name)
      r[name] = { rankIndex = rankIndex, class = classFile, online = online }
      if classFile and D.db then D.db.classCache = D.db.classCache or {}; D.db.classCache[name] = classFile end
      Know(name)
    end
  end
  D.roster = r
  ScheduleCompute()
end

function D.ClassOf(name)
  local x = D.raid[name] or D.roster[name]
  if not x then
    for n, v in pairs(D.raid) do if D.SameName(n, name) then x = v break end end
  end
  if not x then
    for n, v in pairs(D.roster) do if D.SameName(n, name) then x = v break end end
  end
  if x and x.class then return x.class end
  -- not currently grouped or in the guild (a pug, or offline before this
  -- session's roster synced) - fall back to whatever we've ever learned
  local cache = D.db and D.db.classCache
  if cache then
    local c = D.Canon(name)
    if cache[c] then return cache[c] end
    for n, cls in pairs(cache) do if D.SameName(n, name) then return cls end end
  end
  return nil
end

local function UpdateRaid()
  local r = {}
  local now = D.RealmMinutes()
  if D.InRaid() then
    for i = 1, D.GroupSize() do
      local name, _, _, _, _, classFile, _, online = GetRaidRosterInfo(i)
      if name and not Secret(name) then
        local full = D.Canon(Short(name))
        r[full] = { class = classFile, online = online, unit = "raid" .. i }
        if classFile and D.db then D.db.classCache = D.db.classCache or {}; D.db.classCache[full] = classFile end
      end
    end
  elseif D.InGroup() then
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
      if UnitExists(unit) then
        local name = UnitName(unit)
        if name and not Secret(name) then
          local full = unit == "player" and Me() or D.Canon(name)
          local classFile = select(2, UnitClass(unit))
          r[full] = { class = classFile, online = UnitIsConnected(unit), unit = unit }
          if classFile and D.db then D.db.classCache = D.db.classCache or {}; D.db.classCache[full] = classFile end
        end
      end
    end
  end
  -- join times, kept per raid night so a /reload doesn't make everyone "late".
  -- Whoever is already here the first time we look counts as on time (0):
  -- we can't know when they joined.
  local night = D.db.raidNight
  local key = D.NightKey()
  if not night or night.date ~= key then
    night = { date = key, join = {} }
    D.db.raidNight = night
  end
  local ses = D.OpenSession()
  if ses and D.InRaid() then -- everyone seen during the session counts as attending
    D.db.seen = D.db.seen or {}
    D.db.seen[ses.id] = D.db.seen[ses.id] or {}
    for n in pairs(r) do D.db.seen[ses.id][n] = true end
  end
  local first = next(night.join) == nil
  for n in pairs(r) do -- keyed by first name: full names may only show up once the roster loads
    local k = FirstName(n)
    if not night.join[k] then night.join[k] = first and 0 or now end
  end
  D.joinT = night.join
  D.raid = r
  local inRaid = D.InRaid()
  if inRaid and not D.wasInRaid then
    C_Timer.After(3, function() if D.InRaid() then Send(Pack("SQ"), "RAID") end end)
    if D.settings.liveOnRaid and D.ShowLive then D.ShowLive() end
    -- v0.2.34: no "Create tonight's raid?" pop-up any more - several officers
    -- clicking it at once made duplicate raids. Create it from Raid night.
  elseif not inRaid and D.wasInRaid and ses and D.IsAdmin() then
    D.Toast("End the raid?", (ses.title or "Raid") .. " is still running. Click for options.", function()
      if D.ShowEndMenu then D.ShowEndMenu() else D.EndSession(false) end
    end)
  end
  if not inRaid then wipe(D.snap) end
  D.wasInRaid = inRaid
  D.BroadcastStandings()
  D.Refresh()
end
D.UpdateRaid = UpdateRaid

function D.RaidNames()
  local list = {}
  for n in pairs(D.raid) do list[#list + 1] = n end
  table.sort(list)
  return list
end

---------------------------------------------------------------------------
-- Bridge: Raid-Helper sign-ups written by the Discord bot (read-only copy)
--   GuildLadderDKPBridge = {
--     updated = <unix time>,
--     events = { { id, title, start = <unix>, signups = {
--        { discordId, name, status = "signed"|"late"|"tentative"|"bench"|"absent", class, spec } } } },
--     links = { [discordId] = { "Character Name", ... } },
--     wishlists = { [discordId] = { itemID, ... } },
--   }
---------------------------------------------------------------------------
local function LoadBridge()
  D.bridge = Copy(GuildLadderDKPBridge or {}) -- never touch the original: the bot owns that file
end

-- The bridge data to actually use: our own file if it's the newest we know
-- of, otherwise the freshest copy an officer has shared over the guild
-- channel (so a raid night still has sign-ups even if whoever runs the
-- script never logs in that day).
function D.Bridge()
  local a = D.bridge
  local b = D.db and D.db.bridgeShared
  if not b or (a and (a.updated or 0) >= (b.updated or 0)) then return a or {} end
  return b
end

function D.CharForDiscord(discordId)
  if not discordId then return nil end
  if D.data then
    for char, id in pairs(D.data.links) do
      if id == discordId then return char end
    end
  end
  local l = D.Bridge().links and D.Bridge().links[discordId]
  if type(l) == "table" then return l[1] end
  if type(l) == "string" then return l end
  return nil
end

-- All characters linked to a Discord account (for alts)
function D.CharsForDiscord(discordId)
  local set, list = {}, {}
  if D.data then for char, id in pairs(D.data.links) do if id == discordId then set[char] = true end end end
  local l = D.Bridge().links and D.Bridge().links[discordId]
  if type(l) == "table" then for _, c in ipairs(l) do set[c] = true end elseif type(l) == "string" then set[l] = true end
  for c in pairs(set) do list[#list + 1] = c end
  return list
end

-- All Raid-Helper raids we know of, soonest first
function D.BridgeEvents()
  local list = {}
  for _, e in ipairs(D.Bridge().events or {}) do list[#list + 1] = e end
  table.sort(list, function(a, b) return (a.start or 0) < (b.start or 0) end)
  return list
end

---------------------------------------------------------------------------
-- Sharing sign-ups with the other officers (GUILD, officers only).
-- Whoever's file is newest sends it; everyone who receives it keeps their
-- own copy, so sign-ups are there for an officer running a raid even if the
-- person with the script never logs in that day. A field (|) separates
-- raids, (#) their fields, (;) sign-ups, (:) a sign-up's fields.
---------------------------------------------------------------------------
local function BField(s, max) return (Clean(s, max or 60):gsub("[#;:]", "")) end

local function EncodeBridge(b)
  local eparts = {}
  for _, e in ipairs(b.events or {}) do
    local sparts = {}
    for _, su in ipairs(e.signups or {}) do
      sparts[#sparts + 1] = table.concat({
        BField(su.discordId, 30), BField(su.name, 40), BField(su.status, 12), BField(su.class, 16), BField(su.spec, 16),
      }, ":")
    end
    eparts[#eparts + 1] = table.concat({ BField(e.id, 30), BField(e.title, 60), tostring(e.start or 0), table.concat(sparts, ";") }, "#")
  end
  local lparts = {}
  for discordId, chars in pairs(b.links or {}) do
    local list = type(chars) == "table" and chars or { chars }
    local cs = {}
    for _, c in ipairs(list) do cs[#cs + 1] = BField(c, 40) end
    lparts[#lparts + 1] = BField(discordId, 30) .. "#" .. table.concat(cs, "+")
  end
  return table.concat(eparts, "|"), table.concat(lparts, "|")
end

local function DecodeBridge(eventsStr, linksStr, updated, from)
  local events = {}
  if eventsStr ~= "" then
    for estr in (eventsStr .. "|"):gmatch("(.-)|") do
      local id, title, start, sstr = estr:match("^(.-)#(.-)#(%d*)#?(.*)$")
      if id then
        local signups = {}
        if sstr and sstr ~= "" then
          for sustr in (sstr .. ";"):gmatch("(.-);") do
            local did, name, status, class, spec = sustr:match("^(.-):(.-):(.-):(.-):(.*)$")
            if did then
              signups[#signups + 1] = { discordId = did, name = name, status = status ~= "" and status or "signed",
                class = class ~= "" and class or nil, spec = spec ~= "" and spec or nil }
            end
          end
        end
        events[#events + 1] = { id = id, title = title, start = tonumber(start) or 0, signups = signups }
      end
    end
  end
  local links = {}
  if linksStr ~= "" then
    for lstr in (linksStr .. "|"):gmatch("(.-)|") do
      local did, cs = lstr:match("^(.-)#(.*)$")
      if did then
        local chars = {}
        for c in (cs .. "+"):gmatch("(.-)%+") do if c ~= "" then chars[#chars + 1] = c end end
        links[did] = chars
      end
    end
  end
  return { updated = updated, events = events, links = links, from = from, t = GetServerTime() }
end

local lastBroadcastUpdated, lastBroadcastT = 0, 0
function D.BroadcastBridge(force)
  if not D.ready or not IsInGuild() or not D.IsAdmin() then return end
  local b = D.bridge
  if not b or (b.updated or 0) == 0 or b.test then return end -- nothing real to share, or it's test data
  if not force and b.updated == lastBroadcastUpdated and GetTime() - lastBroadcastT < 1800 then return end
  lastBroadcastUpdated, lastBroadcastT = b.updated, GetTime()
  local events, links = EncodeBridge(b)
  Send(Pack("BD", b.updated, events, links))
end

D.handlers.BD = function(p, sender, channel)
  if channel ~= "GUILD" or not D.IsAdmin(sender) then return end
  local updated = tonumber(p[2]) or 0
  local cur = D.db.bridgeShared
  if cur and (cur.updated or 0) >= updated then return end -- we already have this or newer
  if D.bridge and (D.bridge.updated or 0) >= updated then return end -- our own file is already current
  D.db.bridgeShared = DecodeBridge(p[3] or "", p[4] or "", updated, sender)
  Print(("Got raid sign-ups from %s (%s)."):format(D.FirstName(sender) or sender, date("%b %d, %H:%M", updated)))
  D.Refresh()
end

-- "does anyone have sign-ups?" - sent once at login if we have none ourselves
D.handlers.BQ = function(_, _, channel)
  if channel == "GUILD" then C_Timer.After(1 + math.random() * 3, function() D.BroadcastBridge(true) end) end
end

-- Test sign-ups without the Discord bot: a fake raid tonight (in memory only,
-- gone after /reload) built from the people in your group and guild.
function D.FakeSignups(off)
  if off then
    LoadBridge()
    Print("Test sign-ups removed.")
    D.Refresh()
    return
  end
  local now = GetServerTime()
  local ups, used, i = {}, {}, 0
  local function Add(name, status, class)
    i = i + 1
    ups[#ups + 1] = { discordId = "test" .. i, name = name, status = status, class = class }
  end
  local raid = D.RaidNames()
  for n, x in ipairs(raid) do
    local status = (n == 2 and "late") or (n == 3 and "tentative") or "signed"
    Add(FirstName(raid[n]), status, D.raid[raid[n]].class)
    used[raid[n]] = true
  end
  if #raid == 0 then Add(FirstName(Me()), "signed"); used[Me()] = true end
  -- one guildie on the bench, one who signed up but isn't here
  local extra = {}
  for n, r in pairs(D.roster) do if not used[n] and not D.SameName(n, Me()) then extra[#extra + 1] = n end end
  table.sort(extra)
  if extra[1] then Add(FirstName(extra[1]) .. " (Tank)", "bench") end
  if extra[2] then Add(FirstName(extra[2]), "signed") end
  if extra[3] then Add(FirstName(extra[3]), "absent") end
  Add("bigdave_88", "signed", "Warrior") -- nobody by that name: shows as unmatched
  D.bridge = Copy(D.bridge or {})
  D.bridge.updated = now
  D.bridge.test = true
  D.bridge.events = {
    { id = "test-tonight", title = "Test Raid (fake sign-ups)", start = now + 15 * 60, signups = ups },
    { id = "test-later", title = "Test Raid next week", start = now + 7 * 86400, signups = { ups[1] } },
  }
  Print(("Test sign-ups loaded: %d sign-ups for a raid starting in 15 min, plus one next week. /dkp testsignups off to remove (or /reload)."):format(#ups))
  D.Refresh()
end

function D.TonightEvent()
  local ev = D.Bridge().events
  if not ev then return nil end
  local now, best, bestGap = GetServerTime(), nil, 12 * 3600
  for _, e in ipairs(ev) do
    local gap = math.abs((e.start or 0) - now)
    if gap <= bestGap then best, bestGap = e, gap end
  end
  return best
end

-- Match a sign-up to a character: link first, then forgiving nickname match
function D.MatchSignup(s)
  local chars = D.CharsForDiscord(s.discordId)
  if #chars > 0 then
    -- prefer whichever of their characters is in the raid
    for _, c in ipairs(chars) do
      for n in pairs(D.raid) do if D.SameName(n, c) then return n end end
    end
    return chars[1]
  end
  -- v0.3.2: Raid-Helper names are Discord nicknames ("Ugly", "Naxx",
  -- "Moofoosa/Magickk", "sparklefart"). Try each part of the name, then a
  -- unique prefix ("Ugly" -> Uglymage), then a close spelling within the
  -- same class ("sparklefart" -> Sparklefahrt). Anything still unsure stays
  -- unmatched for an officer to Link once.
  local pool = {}
  for n in pairs(D.known) do pool[n] = true end
  for n in pairs(D.raid) do pool[n] = true end
  local function Unique(test)
    local match, count = nil, 0
    for n in pairs(pool) do
      if test(n, D.Normalize(FirstName(n))) and match ~= n then match, count = n, count + 1 end
    end
    return count == 1 and match or nil
  end
  local function SameClass(n) return not s.class or D.ClassOf(n) == s.class end
  local parts = {}
  for part in tostring(s.name or ""):gmatch("[^/|,;&%(%)%[%]]+") do
    local w = D.Normalize(part)
    if w ~= "" then parts[#parts + 1] = w end
  end
  for _, want in ipairs(parts) do -- 1. exact
    local m = Unique(function(_, mine) return mine == want end)
    if m then return m end
  end
  for _, want in ipairs(parts) do -- 2. unique prefix, same class
    if #want >= 3 then
      local m = Unique(function(n, mine) return mine:sub(1, #want) == want and SameClass(n) end)
      if m then return m end
    end
  end
  if s.class then
    for _, want in ipairs(parts) do -- 3. close spelling, same class
      if #want >= 5 then
        local m = Unique(function(n, mine)
          if D.ClassOf(n) ~= s.class then return false end
          local k = 0
          while k < #want and k < #mine and want:byte(k + 1) == mine:byte(k + 1) do k = k + 1 end
          return k >= 5 and k >= math.floor(math.min(#want, #mine) * 0.7)
        end)
        if m then return m end
      end
    end
  end
  return nil
end

-- The raid-night check: Raid-Helper sign-ups vs. who is actually here
function D.RaidCheck()
  local ev = D.TonightEvent()
  local res = { event = ev, onTime = {}, late = {}, noShow = {}, bench = {}, walkIn = {}, unmatched = {}, signed = 0 }
  local cutoff = 0
  local ses = D.OpenSession()
  if ses and ses.start then
    -- raid started: on time = was here when Start was pressed (realm minutes)
    cutoff = D.RealmMinutes() - math.floor((GetServerTime() - ses.start) / 60)
    if cutoff < 0 then cutoff = cutoff + 1440 end
    res.startedCutoff = true
  elseif not D.PlannedRaid() then
    local hh, mm = tostring(D.Cfg("ONTIME_CUTOFF") or ""):match("^(%d+):(%d+)$")
    if hh then cutoff = tonumber(hh) * 60 + tonumber(mm) end
  end

  local signedChars = {}
  if ev then
    for _, s in ipairs(ev.signups or {}) do
      local char = D.MatchSignup(s)
      if s.status ~= "absent" then res.signed = res.signed + 1 end
      if not char then
        if s.status ~= "absent" then res.unmatched[#res.unmatched + 1] = s end
      else
        signedChars[char] = s.status
        local inRaid = D.raid[char] ~= nil
        if s.status == "bench" and not inRaid then
          res.bench[#res.bench + 1] = char
        elseif s.status ~= "absent" and s.status ~= "bench" and not inRaid then
          res.noShow[#res.noShow + 1] = char
        end
      end
    end
  end
  for _, n in ipairs(D.Bench()) do -- bench added in game (by hand or !standby)
    local dup = false
    for _, b in ipairs(res.bench) do if b == n then dup = true end end
    if not dup and not D.raid[n] then res.bench[#res.bench + 1] = n end
  end
  for n in pairs(D.raid) do
    local joined = D.joinT[FirstName(n)] or 0
    if cutoff > 0 and joined > cutoff then
      res.late[#res.late + 1] = n
    else
      res.onTime[#res.onTime + 1] = n
    end
    if ev and not signedChars[n] then res.walkIn[#res.walkIn + 1] = n end
  end
  for _, k in ipairs({ "onTime", "late", "noShow", "bench", "walkIn" }) do table.sort(res[k]) end
  return res
end

-- One-click raid awards. Everyone here + bench, except on-time skips the late.
function D.AwardRaid(cat, bossName)
  local chk = D.RaidCheck()
  local names, amount, reason = {}, 0, ""
  local function Add(list) for _, n in ipairs(list) do names[#names + 1] = n end end
  if cat == "ONTIME" then
    Add(chk.onTime); Add(chk.bench)
    amount, reason = D.Cfg("ONTIME"), "On-time"
  elseif cat == "CLEAR" then
    Add(chk.onTime); Add(chk.late); Add(chk.bench)
    amount, reason = D.Cfg("CLEAR"), "Full clear"
  elseif cat == "BENCH" then
    Add(chk.bench)
    amount, reason = D.Cfg("BENCH"), "Bench / standby"
  elseif cat == "BOSS" then
    Add(chk.onTime); Add(chk.late); Add(chk.bench)
    amount = (D.BossValue and D.BossValue(bossName) or D.data.bossValues[bossName or ""]) or D.Cfg("BOSS_DEFAULT") -- v0.4.1
    reason = "Boss kill: " .. (bossName or "?")
  end
  if #names == 0 then Print("Nobody to award - are you in a raid?") return end
  D.Award(names, amount, reason, cat)
end

-- Bench is shared between officers (ledger events), per raid session
local function BenchKey() local s = D.CurrentRaid(); return s and s.id or "" end
function D.Bench()
  local list = {}
  local set = D.data and D.data.benches[BenchKey()]
  if set then for n in pairs(set) do list[#list + 1] = n end end
  table.sort(list)
  return list
end
function D.IsBenched(name)
  local set = D.data and D.data.benches[BenchKey()]
  return set and set[name] or false
end
function D.AddBench(name)
  name = D.Canon(D.ResolveName(name))
  if not name or name == "" or D.IsBenched(name) then return end
  if not NeedAdmin() then return end
  NewEvent({ k = "BE", p = name, v = "1", x = BenchKey() })
  return true
end
function D.RemoveBench(name)
  if not D.IsBenched(name) or not NeedAdmin() then return end
  NewEvent({ k = "BE", p = name, v = "0", x = BenchKey() })
  return true
end
function D.ClearBench()
  for _, n in ipairs(D.Bench()) do D.RemoveBench(n) end
end

---------------------------------------------------------------------------
-- Sync (same digest scheme as Guild Ladder, over GUILD)
---------------------------------------------------------------------------
local function Digest()
  local d = {}
  for _, e in pairs(D.db.events) do
    local b = Bucket(e)
    local x = d[b]
    if not x then x = { c = 0, h = 0 }; d[b] = x end
    x.c = x.c + 1
    x.h = (x.h + (e.h or Hash(e.id))) % 2147483647
  end
  return d
end

local lastDigest = 0
local function SendDigest(minGap)
  if not IsInGuild() or not D.db then return end
  if GetTime() - lastDigest < (minGap or 30) then return end
  lastDigest = GetTime()
  local chunks, cur, len = {}, {}, 0
  for b, x in pairs(Digest()) do
    local s = b .. ":" .. x.c .. ":" .. x.h
    if len + #s > 200 and #cur > 0 then
      chunks[#chunks + 1] = table.concat(cur, ",")
      cur, len = {}, 0
    end
    cur[#cur + 1] = s
    len = len + #s + 1
  end
  chunks[#chunks + 1] = table.concat(cur, ",")
  local tag = math.random(100, 999)
  for i, c in ipairs(chunks) do Send(Pack("HW", tag, i, #chunks, c)) end -- v0.2.41: HW = per-day buckets
end
D.SendDigest = SendDigest

-- Periodically ask the guild for digests so Sync status stays current even
-- when nobody's made a change recently (officers only: nobody else sends one back)
local function StartSyncTicker()
  C_Timer.NewTicker(180, function() if D.IsAdmin() then SendDigest(170) end end)
end
D.StartSyncTicker = StartSyncTicker

local seenBucket, sendQueued = {}, {}
local function SendBucket(b)
  sendQueued[b] = nil
  if seenBucket[b] and GetTime() - seenBucket[b] < 10 then return end -- someone else is on it
  seenBucket[b] = GetTime()
  local list = {}
  for _, e in pairs(D.db.events) do
    if Bucket(e) == b then list[#list + 1] = e end
  end
  SortEvents(list)
  for _, e in ipairs(list) do Send(EventMsg(e)) end
end

-- How far another officer's ledger is from mine, for the Sync status line.
-- diff = number of buckets that don't match (0 = in sync); nil if we have no
-- events of our own yet to compare against.
local function CompareDigest(theirs)
  local mine = Digest()
  if not next(mine) and not next(theirs) then return 0 end
  local diff, seen = 0, {}
  for b, x in pairs(mine) do
    seen[b] = true
    local y = theirs[b]
    if not y or y.c ~= x.c or y.h ~= x.h then diff = diff + 1 end
  end
  for b in pairs(theirs) do
    if not seen[b] then diff = diff + 1 end
  end
  return diff
end

-- name -> { t = realm time last heard a digest from them, diff = buckets mismatched }
-- Only officers write digests, so this only ever holds officers.
local syncStatus = {}
function D.SyncStatus() return syncStatus end

-- officers = { name, ... } online right now, besides me; synced/stale/mismatched
-- are counts among them. stale = no digest heard in the last 5 min (just logged
-- in, or an old version that doesn't send them). Sorted name list for a tooltip.
function D.SyncSummary()
  local officers, synced, stale, mismatched = {}, 0, 0, 0
  local now = GetServerTime()
  for name, r in pairs(D.roster) do
    if r.online and name ~= Me() and D.IsAdmin(name) then
      officers[#officers + 1] = name
      local st = syncStatus[name]
      if not st or now - st.t > 300 then stale = stale + 1
      elseif st.diff == 0 then synced = synced + 1
      else mismatched = mismatched + 1 end
    end
  end
  table.sort(officers)
  return officers, synced, stale, mismatched
end

local function OnDigest(theirs)
  local mine = Digest()
  for b, x in pairs(mine) do
    local y = theirs[b]
    if not y or x.c > y.c or (x.c == y.c and x.h ~= y.h) then
      if not sendQueued[b] then
        sendQueued[b] = true
        local delay = (b == "W:" .. Me() or (b:sub(1, 1) == "@" and D.IsAdmin())) and 1 or (2 + math.random() * 5)
        C_Timer.After(delay, function() SendBucket(b) end)
      end
    end
  end
  for b, y in pairs(theirs) do
    local x = mine[b]
    if not x or y.c > x.c or (x.c == y.c and x.h ~= y.h) then
      C_Timer.After(1 + math.random() * 4, function() SendDigest(30) end)
      return
    end
  end
end

---------------------------------------------------------------------------
-- Incoming addon messages
---------------------------------------------------------------------------
local hvParts = {}
local function OnMessage(msg, sender, channel)
  if not D.db then return end
  local p = { strsplit(SEP, msg) }
  local kind = p[1]
  if kind == "EV" then
    if channel ~= "GUILD" then return end -- the ledger only travels inside the guild
    local e = ParseEvent(p)
    if e then
      seenBucket[Bucket(e)] = GetTime()
      if StoreEvent(e) then
        D.QueueAwardToast(e)
        D.QueueLootReveal(e) -- v0.5.0
        ScheduleCompute()
      end
    end
  elseif kind == "HV" then
    return -- v0.2.41: pre-0.2.41 digest (one "@" bucket) - not comparable any more
  elseif kind == "HW" then
    if channel ~= "GUILD" then return end
    local key = sender .. (p[2] or "")
    local i, n = tonumber(p[3]), tonumber(p[4])
    if not (i and n) then return end
    local st = hvParts[key] or { got = 0, map = {} }
    hvParts[key] = st
    for b, c, h in string.gmatch(p[5] or "", "([^,]+):(%d+):(%d+)") do
      st.map[b] = { c = tonumber(c), h = tonumber(h) }
    end
    st.got = st.got + 1
    if st.got >= n then
      hvParts[key] = nil
      if D.IsAdmin(sender) then syncStatus[sender] = { t = GetServerTime(), diff = CompareDigest(st.map) } end
      OnDigest(st.map)
    end
  elseif D.handlers[kind] then
    D.handlers[kind](p, sender, channel)
  end
end

---------------------------------------------------------------------------
-- Boss kills: offer the award (officers in a raid)
---------------------------------------------------------------------------
-- v0.2.26: no more "click to award" - officers' clients award it themselves.
-- The raid leader's client goes first; other officers wait longer and only
-- step in if the award still isn't in the ledger (leader offline, no add-on,
-- not an officer). If two land anyway, Compute only counts the first.
function D.HasBossAward(bossName)
  if not D.db then return false end
  local g, r = D.NightKey(), "Boss kill: " .. (bossName or "?")
  for _, e in pairs(D.db.events) do
    if e.k == "AW" and e.x == "BOSS" and e.g == g and e.r == r then return true end
  end
  return false
end

local bossPending = {}
-- v0.2.32: only award when a raid has been started with Start Raid, and that
-- raid isn't a leftover from an earlier night. Pug raids earned DKP before.
local STALE_SESSION = 12 * 3600
local staleWarned
local function RaidRunning()
  local ses = D.OpenSession()
  if not ses or not ses.start then return false end
  -- v0.2.34: the raid must be this group's - its creator, starter or leader
  -- here, or a mostly-guild raid (covers the officer who made it leaving)
  if not D.MineRaid(ses) then
    local total, guild = 0, 0
    for n in pairs(D.raid) do
      total = total + 1
      if D.roster[n] then guild = guild + 1 else
        for g in pairs(D.roster) do if D.SameName(g, n) then guild = guild + 1 break end end
      end
    end
    if total == 0 or guild * 2 < total then return false end
  end
  if GetServerTime() - ses.start > STALE_SESSION then
    if not staleWarned then
      staleWarned = true
      Print("Boss kill not awarded: the open raid was started more than 12 hours ago. End it and start tonight's raid.")
    end
    return false
  end
  return true
end

local function OnBossKill(name)
  if not name or Secret(name) or not D.InRaid() or not D.IsAdmin() or D.practice then return end
  if not RaidRunning() then return end
  if bossPending[name] then return end
  bossPending[name] = true
  local leader = UnitIsGroupLeader("player")
  local wait = leader and 3 or (12 + math.random(0, 12))
  C_Timer.After(wait, function()
    bossPending[name] = nil
    if not D.InRaid() or not D.IsAdmin() or not RaidRunning() then return end
    if D.HasBossAward(name) then return end -- someone already did it
    local v = (D.BossValue and D.BossValue(name) or (D.data and D.data.bossValues[name])) or D.Cfg("BOSS_DEFAULT") -- v0.4.1
    D.AwardRaid("BOSS", name)
    D.Toast("Boss down: " .. name, ("Awarded +%d to the raid and bench automatically."):format(tonumber(v) or 0))
  end)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local myToken = tostring(math.random(100000, 999999)) .. tostring(math.floor(GetTime() * 1000))

local function Startup()
  if D.ready then return end
  SelectGuild()
  Know(Me())
  D.Compute()
  D.ready = true
  if D.LoadQueue then D.LoadQueue() end
  SendDigest(0)
  StartSyncTicker()
  D.RequestRoster()
  UpdateRaid()
  C_Timer.After(10, function() pcall(CheckAltsAtLogin) end)
  C_Timer.After(8, function()
    if D.bridge and (D.bridge.updated or 0) > 0 and not D.bridge.test then
      D.BroadcastBridge(true) -- I have the file: share it
    else
      Send(Pack("BQ")) -- I don't: ask if anyone else does
    end
  end)
end

-- Our own echo tells us our full name (GUILD if we have one, else the group)
local function LearnIdentity()
  local ch = IsInGuild() and "GUILD" or D.GroupChannel()
  if D.fullName or not ch then Startup() return end
  pcall(C_ChatInfo.SendAddonMessage, C.PREFIX, Pack("ME", myToken), ch)
  C_Timer.After(15, Startup)
end

local function OnGuildChanged()
  if not D.ready then return end
  if GuildKey() ~= D.guildKey then
    SelectGuild()
    D.Compute()
    if D.LoadQueue then D.LoadQueue() end
    SendDigest(0)
    D.RequestRoster()
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    InitDB()
    LoadBridge()
    C_ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
    for _, e in ipairs({
      "CHAT_MSG_ADDON", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GROUP_ROSTER_UPDATE", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD",
    }) do pcall(self.RegisterEvent, self, e) end
    if D.InitUI then D.InitUI() end
    if D.InitLoot then D.InitLoot() end
    C_Timer.After(6, LearnIdentity)
    C_Timer.NewTicker(60, function() D.RequestRoster() end)
    C_Timer.NewTicker(600, function() if D.ready then SendDigest(300); D.BroadcastBridge() end end)
    return
  end

  if event == "CHAT_MSG_ADDON" then
    local prefix, msg, channel, sender = ...
    if Secret(prefix, msg, sender) or prefix ~= C.PREFIX then return end
    sender = Short(sender)
    if msg == "ME" .. SEP .. myToken then
      if not D.fullName then
        D.fullName = sender
        Know(sender)
        Startup()
      end
      return
    end
    Know(sender)
    if sender == Me() then return end
    if not D.ready then return end
    local tok, i, n, piece = msg:match("^MP~(%d+)~(%d+)~(%d+)~(.*)$")
    if tok then
      D.parts = D.parts or {}
      local key = sender .. ":" .. tok
      local st = D.parts[key] or { got = 0, pieces = {}, t = GetTime() }
      D.parts[key] = st
      i, n = tonumber(i), tonumber(n)
      if not st.pieces[i] then st.pieces[i] = piece; st.got = st.got + 1 end
      if st.got < n then return end
      D.parts[key] = nil
      msg = table.concat(st.pieces, "", 1, n)
      for k, v in pairs(D.parts) do if GetTime() - v.t > 120 then D.parts[k] = nil end end -- drop stale halves
    end
    OnMessage(msg, sender, channel)
  elseif event == "GUILD_ROSTER_UPDATE" then
    UpdateRoster()
  elseif event == "PLAYER_GUILD_UPDATE" then
    C_Timer.After(3, OnGuildChanged)
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    if D.ready then UpdateRaid() end
  elseif event == "ENCOUNTER_END" then
    local _, encounterName, _, _, success = ...
    if success == 1 and D.ready then OnBossKill(encounterName) end
  end
end)

---------------------------------------------------------------------------
-- Version check (v0.2.24): /dkp versions asks the raid (or party, or the
-- online guild if you're not grouped) what build everyone is running.
-- Clients older than 0.2.24 don't know the question, so they show up under
-- "no reply" along with anyone who doesn't have the add-on at all.
---------------------------------------------------------------------------
local function VerNum(v)
  local t = {}
  for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return t
end
local function VerCmp(a, b)
  local x, y = VerNum(a), VerNum(b)
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then return p < q and -1 or 1 end
  end
  return 0
end
D.VerCmp = VerCmp

local verCheck
local function GroupNames()
  local list = {}
  local raid = IsInRaid(LE_PARTY_CATEGORY_HOME or 1)
  for i = 1, D.GroupSize() do
    local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    local n = UnitName(unit)
    if n and not Secret(n) then
      list[#list + 1] = { name = Short(GetUnitName(unit, true) or n), online = UnitIsConnected(unit) }
    end
  end
  return list
end

local function ReplyFrom(got, name)
  if got[name] then return got[name] end
  for n, v in pairs(got) do if D.SameName(n, name) then return v end end
end

function D.VersionCheck()
  if verCheck then Print("A version check is already running - give it a few seconds.") return end
  local ch = (D.InRaid() and "RAID") or (D.InGroup() and "PARTY") or (IsInGuild() and "GUILD") or nil
  if not ch then Print("Join a raid, a party or a guild first.") return end
  verCheck = { ch = ch, got = {} }
  Send(Pack("VQ", D.Version), ch) -- v0.2.30: the asker's build rides along (older clients ignore it)
  Print(("Checking add-on versions (%s)..."):format(ch:lower()))
  C_Timer.After(6, function()
    local vc = verCheck
    verCheck = nil
    local who = {}
    if vc.ch == "GUILD" then
      for n, r in pairs(D.roster) do if r.online then who[#who + 1] = { name = n, online = true } end end
    else
      who = GroupNames()
    end
    local newest = D.Version
    for _, v in pairs(vc.got) do if VerCmp(v, newest) > 0 then newest = v end end
    local current, behind, silent, offline = {}, {}, {}, {}
    for _, w in ipairs(who) do
      local short = FirstName(w.name) or w.name
      local v = D.SameName(w.name, Me()) and D.Version or ReplyFrom(vc.got, w.name)
      if v then
        if VerCmp(v, newest) >= 0 then current[#current + 1] = short
        else behind[#behind + 1] = short .. " |cffa7afba(" .. v .. ")|r" end
      elseif w.online == false then
        offline[#offline + 1] = short
      else
        silent[#silent + 1] = short
      end
    end
    table.sort(current); table.sort(behind); table.sort(silent); table.sort(offline)
    Print(("Newest version seen: |cffe0b04f%s|r"):format(newest))
    Print(("|cff8fe0c4Up to date (%d):|r %s"):format(#current, #current > 0 and table.concat(current, ", ") or "-"))
    if #behind > 0 then Print(("|cfff2a54aOut of date (%d):|r %s"):format(#behind, table.concat(behind, ", "))) end
    if #silent > 0 then
      Print(("|cffff7a6bNo reply (%d) - older than 0.2.24 or no add-on:|r %s"):format(#silent, table.concat(silent, ", ")))
    end
    if #offline > 0 then Print(("|cffa7afbaOffline (%d):|r %s"):format(#offline, table.concat(offline, ", "))) end
    if #behind == 0 and #silent == 0 then Print("Everyone who's online is up to date.") end
  end)
end

D.handlers.VQ = function(p, sender)
  Send(Pack("VR", D.Version), "WHISPER", sender)
  -- v0.2.30: whoever ran /dkp versions told us their build - note it if it's newer than ours
  local v = p[2]
  if v and v ~= "" and VerCmp(v, D.newestSeen or D.Version) > 0 then D.newestSeen = v end
end
D.handlers.VR = function(p, sender, channel)
  if verCheck and channel == "WHISPER" then verCheck.got[sender] = p[2] or "?" end
  -- v0.2.30: remember the newest build anyone has reported, for the minimap tooltip
  local v = p[2]
  if v and v ~= "?" and VerCmp(v, D.newestSeen or D.Version) > 0 then D.newestSeen = v end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function ItemIDFromText(text)
  local id = text and (text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
  return tonumber(id)
end
D.ItemIDFromText = ItemIDFromText

SLASH_GUILDLADDERDKP1 = "/dkp"
SLASH_GUILDLADDERDKP2 = "/gldkp"
SlashCmdList.GUILDLADDERDKP = function(input)
  local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    if D.Toggle then D.Toggle() end
  elseif cmd == "queue" or cmd == "loot" then
    if D.ToggleQueue then D.ToggleQueue() end
  elseif cmd == "bid" then
    if D.ReopenBid then D.ReopenBid() end
  elseif cmd == "cleanup" then
    D.CleanupStrayBoss(rest:lower() == "confirm") -- v0.2.33
  elseif cmd == "versions" or cmd == "version" or cmd == "ver" then
    D.VersionCheck()
  elseif cmd == "comms" then
    D.CommStatus()
  elseif cmd == "auction" or cmd == "bids" then
    if D.ShowAuction then D.ShowAuction() end
  elseif cmd == "alt" then
    if rest == "" then Print("Usage: /dkp alt MainName   (or /dkp alt off to unlink)") return end
    if rest:lower() == "off" then D.UnlinkMe() else D.ClaimMain(rest) end
  elseif cmd == "testsignups" then
    D.FakeSignups(rest:lower() == "off")
  elseif cmd == "link" then
    -- v0.3.3: /dkp link <Raid-Helper name> <character>  e.g. /dkp link Raj Jarts
    local who, char = rest:match("^(%S+)%s+(.+)$")
    local ev = D.TonightEvent()
    if not who or not ev then
      Print(ev and "Usage: /dkp link <Raid-Helper name> <character>" or "No Raid-Helper raid in the next 12 hours.")
    else
      local found
      for _, su in ipairs(ev.signups or {}) do
        if D.Fold(su.name or "") == D.Fold(who) then found = su end
      end
      if not found then
        Print(("No sign-up called %s on %s."):format(who, ev.title or "tonight's raid"))
      else
        local name = D.ResolveName(char)
        if not D.known[name] then
          Print(("No guild member or raider called %s - check the spelling."):format(char))
          return
        end
        D.LinkDiscord(name, found.discordId)
        Print(("%s's sign-ups now count as %s."):format(found.name, name))
      end
    end
  elseif cmd == "log" or cmd == "logs" then
    if D.Toggle then D.Toggle("logs") end -- v0.3.0
  elseif cmd == "raids" then
    if D.Toggle then D.Toggle("raids") end
  elseif cmd == "create" then
    D.CreateRaid(rest)
  elseif cmd == "start" then
    D.StartSession(rest)
  elseif cmd == "end" then
    D.EndSession(rest:lower() ~= "noclear")
  elseif cmd == "standings" or cmd == "s" or cmd == "live" then
    if D.ToggleLive then D.ToggleLive() end
  elseif cmd == "raid" then
    if D.Toggle then D.Toggle("raid") end
  elseif cmd == "enchants" then -- v1.3.0
    if D.ToggleEnchants then D.ToggleEnchants(true) end
  elseif cmd == "gems" then -- v1.4.0: its own window
    if D.ToggleGems then D.ToggleGems(true) end
  elseif cmd == "trade" then -- v1.2.0
    if D.TradeSlash then D.TradeSlash(rest) end
  elseif cmd == "dock" or cmd == "tracker" then -- v1.1.0
    if D.DockSlash then D.DockSlash(rest) end
  elseif cmd == "raidloot" then -- v0.7.0
    if D.ShowRaidLoot then D.ShowRaidLoot(rest ~= "" and rest or nil) end
  elseif cmd == "gear" or cmd == "plan" then -- v0.6.1
    if D.ToggleGearPlan then D.ToggleGearPlan() end
  elseif cmd == "bis" then -- v0.6.0
    if D.BiS then D.BiS.Slash(rest) end
  elseif cmd == "fame" or cmd == "hall" then
    if D.Toggle then D.Toggle("fame", true) end
  elseif cmd == "recap" then
    D.recapName = (rest ~= "") and D.ResolveName(rest) or nil
    if D.SetHallView then D.SetHallView("recap") end
    if D.Toggle then D.Toggle("fame", true) end
  elseif cmd == "reveal" then
    if rest:lower() == "off" or rest:lower() == "on" then
      D.settings.lootReveal = rest:lower() == "on"
      Print("Loot reveal banner " .. (D.settings.lootReveal and "on." or "off."))
    elseif D.ShowReveal then
      D.ShowReveal({ item = 32837, name = "Test item", who = Me(), price = 250, mine = true, left = D.Balance(Me()) })
    end
  elseif cmd == "wish" or cmd == "unwish" then
    local id = ItemIDFromText(rest)
    if not id then Print("Usage: /dkp wish [shift-click an item]") return end
    D.Wish(id, cmd == "wish")
    Print((cmd == "wish" and "Added to" or "Removed from") .. " your wishlist: " .. (select(2, D.GetItemInfo(id)) or ("item " .. id)))
  elseif cmd == "award" then
    local name, pts, reason = rest:match("^(.-)%s+(%-?%d+)%s*(.*)$")
    if not name or name == "" then Print("Usage: /dkp award Name 10 Reason") return end
    D.Adjust(D.ResolveName(name), tonumber(pts), reason ~= "" and reason or "Adjustment")
  elseif cmd == "bench" then
    if rest == "clear" then D.ClearBench() Print("Bench cleared.")
    elseif rest ~= "" then D.AddBench(rest) Print("Added to bench: " .. D.ResolveName(rest))
    else Print("Bench: " .. table.concat(D.Bench(), ", ")) end
  elseif cmd == "practice" then
    if D.SetPractice then D.SetPractice(not D.practice) end
  elseif cmd == "sync" then
    SendDigest(0)
    D.BroadcastBridge(true)
    Send(Pack("BQ"))
    Print("Asking the guild for anything you're missing.")
  elseif cmd == "minimap" then
    D.settings.minimap = not D.settings.minimap
    if D.UpdateMinimap then D.UpdateMinimap() end
  elseif cmd == "post" or cmd == "announce" then
    D.PostPendingChat()
  elseif cmd == "importclm" then
    if rest:lower() == "undoloot" then D.UndoCLMLoot() return end
    if D.AskImportCLM then D.AskImportCLM() else Print("Paste the JSON from /clm export into D.ImportCLM(text) - UI not loaded.") end
  elseif cmd == "podium" then -- v1.5.0
    if D.PodiumSlash then D.PodiumSlash(rest) end
  elseif cmd == "stats" then -- v1.4.1: temporary stats probe (Probe.lua)
    if D.StatsSlash then D.StatsSlash(rest) end
  elseif cmd == "ready" or cmd == "readiness" then
    if D.ReadySlash then D.ReadySlash(rest) end -- v0.4.0
  elseif cmd == "resetpos" then
    wipe(D.settings.pos)
    -- v0.2.30: sizes and scales reset along with positions
    if D.settings.scales then wipe(D.settings.scales) end
    if D.settings.sizes then wipe(D.settings.sizes) end
    Print("Window positions, sizes and scales reset - /reload to see them back at their defaults.")
  elseif cmd == "resetminimap" then
    if D.ResetMinimap then D.ResetMinimap() else Print("UI not loaded yet.") end
    Print("Minimap icon reset to its default spot.")
  else
    Print("/dkp  |  /dkp standings  |  /dkp logs  |  /dkp dock  |  /dkp trade  |  /dkp enchants  |  /dkp gems  |  /dkp gear  |  /dkp raidloot  |  /dkp bis  |  /dkp fame  |  /dkp recap [name]  |  /dkp reveal [on/off]  |  /dkp podium  |  /dkp queue  |  /dkp auction  |  /dkp bid  |  /dkp raid  |  /dkp wish [item]  |  /dkp unwish [item]  |  /dkp award Name 10 reason  |  /dkp bench Name / clear  |  /dkp create [title] / start / end (noclear)  |  /dkp alt Main / off  |  /dkp link RHname Character  |  /dkp importclm  |  /dkp practice  |  /dkp sync  |  /dkp comms  |  /dkp versions  |  /dkp cleanup  |  /dkp minimap  |  /dkp resetpos  |  /dkp resetminimap")
  end
end
