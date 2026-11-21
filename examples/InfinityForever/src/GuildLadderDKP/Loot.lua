local ADDON, D = ...
local C = D.Config
local Pack, Send, Print, Secret = D.Pack, D.Send, D.Print, D.Secret

--[[
  Loot queue + auctions.
  - Tradeable items the loot officer picks up land in the queue automatically;
    Alt-click adds anything from bags, the loot window or a chat link.
  - Rows sync to the other officers in the raid; each row has a HOLDER (whoever
    has the item in their bags). Only the holder runs its auction.
  - Flow: start -> bids (popup over RAID or "!bid 40" whispers) -> close ->
    award (writes the DKP spend) -> awaiting trade -> traded -> row clears.
]]

D.remote = {}    -- other officers' rows: uid -> row
D.auction = nil  -- the auction I'm running
D.bidding = {}   -- auctions I can bid on: aid -> info (from AU messages)

local function Now() return GetServerTime() end
local function Me() return D.Me() end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
-- v1.0.0: an item the client hasn't loaded yet comes back empty. Remember that something is waiting (D.itemPending)
-- and ask the client to load it; UI.lua refreshes the windows when GET_ITEM_INFO_RECEIVED says it arrived, so lists
-- no longer show "Item 32331" until you scroll.
local requestedItems = {}
local function ItemInfo(item)
  local name, link, quality, ilvl, _, _, _, _, equipLoc, icon = D.GetItemInfo(item)
  if not name and item then
    D.itemPending = true
    local id = tonumber(item)
    if id and not requestedItems[id] and C_Item and C_Item.RequestLoadItemDataByID then
      requestedItems[id] = true
      pcall(C_Item.RequestLoadItemDataByID, id)
    end
  end
  return name, link, quality, ilvl, equipLoc, icon
end
D.ItemInfo = ItemInfo

function D.ItemIcon(itemID)
  if D.GetItemInfoInstant then
    local _, _, _, _, icon = D.GetItemInfoInstant(itemID)
    if icon then return icon end
  end
  return select(6, ItemInfo(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function D.ItemLink(itemID)
  return select(2, ItemInfo(itemID)) or ("item:" .. tostring(itemID))
end

function D.ItemName(itemID)
  return (ItemInfo(itemID)) or ("Item " .. tostring(itemID))
end

function D.QualityColor(itemID)
  local q = select(3, ItemInfo(itemID)) or 1
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-- Turn a GlobalStrings format ("You receive loot: %s.") into a Lua pattern
local function FormatToPattern(fmt)
  if not fmt then return nil end
  fmt = fmt:gsub("%%%d%$", "%%") -- "%1$s" style positional args
  fmt = fmt:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
  fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. fmt
end

---------------------------------------------------------------------------
-- Bags (old and new container APIs)
---------------------------------------------------------------------------
local CT = C_Container
local function NumSlots(bag)
  if CT and CT.GetContainerNumSlots then return CT.GetContainerNumSlots(bag) end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function SlotItemID(bag, slot)
  if CT and CT.GetContainerItemID then return CT.GetContainerItemID(bag, slot) end
  return GetContainerItemID and GetContainerItemID(bag, slot)
end
local function Pickup(bag, slot) if CT then CT.PickupContainerItem(bag, slot) else PickupContainerItem(bag, slot) end end

local function FindInBags(itemID)
  local found = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (NumSlots(bag) or 0) do
      if SlotItemID(bag, slot) == itemID then found[#found + 1] = { bag = bag, slot = slot } end
    end
  end
  return found
end
D.FindInBags = FindInBags

-- Trade timer from the tooltip ("...for the next 1 hour 42 min."), in seconds, or nil
local TRADE_PAT = FormatToPattern(BIND_TRADE_TIME_REMAINING)
local scanTip
local function TooltipLines(bag, slot)
  local lines = {}
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do
        if l.leftText and not Secret(l.leftText) then lines[#lines + 1] = l.leftText end
      end
      return lines
    end
  end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "GuildLadderDKPScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  if not pcall(scanTip.SetBagItem, scanTip, bag, slot) then return lines end
  for i = 1, scanTip:NumLines() do
    local fs = _G["GuildLadderDKPScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t and not Secret(t) then lines[#lines + 1] = t end
  end
  return lines
end

local function TradeSecondsLeft(bag, slot)
  if not TRADE_PAT then return nil end
  for _, line in ipairs(TooltipLines(bag, slot)) do
    local dur = line:match(TRADE_PAT)
    if dur then
      local h = tonumber(dur:match("(%d+) hour")) or 0
      local m = tonumber(dur:match("(%d+) min")) or 0
      local s = tonumber(dur:match("(%d+) sec")) or 0
      return h * 3600 + m * 60 + s
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Who can use what
---------------------------------------------------------------------------
local RELIC = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }
local CLASS_LINE = FormatToPattern(ITEM_CLASSES_ALLOWED)

-- returns true, or false + reason
function D.CanUse(itemID, classFile)
  if not classFile or not itemID or not D.GetItemInfoInstant then return true end
  local _, _, _, equipLoc, _, classID, subID = D.GetItemInfoInstant(itemID)
  local rules = D.CAN_USE[classFile]
  if rules and classID == 4 and subID and subID > 0 and equipLoc ~= "INVTYPE_CLOAK" then
    if RELIC[subID] then
      if RELIC[subID] ~= classFile then return false, "wrong class for this relic" end
    else
      local ok = false
      for _, s in ipairs(rules.armor) do if s == subID then ok = true end end
      if not ok then return false, "can't wear " .. (select(3, D.GetItemInfoInstant(itemID)) or "this armor"):lower() end
    end
  elseif rules and classID == 2 and subID then
    local ok = false
    for _, s in ipairs(rules.weapon) do if s == subID then ok = true end end
    if not ok then return false, "can't use " .. (select(3, D.GetItemInfoInstant(itemID)) or "this weapon"):lower() end
  end
  -- "Classes: Priest, Mage" (tier tokens and class items)
  if CLASS_LINE and C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if ok and data and data.lines then
      local mine = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
      for _, l in ipairs(data.lines) do
        local list = l.leftText and not Secret(l.leftText) and l.leftText:match(CLASS_LINE)
        if list and mine and not list:find(mine, 1, true) then return false, "class item for " .. list end
      end
    end
  end
  return true
end

-- Is it an item-level upgrade over what I'm wearing in that slot?
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
D.EQUIP_SLOTS = SLOTS -- v0.6.0: BiS.lua uses it too
-- ilvl/equipLoc: pass these in when the local item cache might be empty (a
-- bidder who's never seen the item) and they came from the auctioneer instead.
function D.IsUpgrade(itemID, ilvl, equipLoc)
  if not ilvl or not equipLoc then
    local _, _, _, i2, e2 = ItemInfo(itemID)
    ilvl, equipLoc = ilvl or i2, equipLoc or e2
  end
  local slots = equipLoc and SLOTS[equipLoc]
  if not slots or not ilvl then return nil end -- unknown, not "no"
  if not D.CanUse(itemID, select(2, UnitClass("player"))) then return false end
  local worst
  for _, s in ipairs(slots) do
    local link = GetInventoryItemLink("player", s)
    local have = link and select(4, D.GetItemInfo(link)) or 0
    if not worst or have < worst then worst = have end
  end
  return ilvl > (worst or 0)
end

---------------------------------------------------------------------------
-- The queue
---------------------------------------------------------------------------
local function MyRows() return D.db and D.db.queue or {} end

function D.LoadQueue()
  -- rows from an old session: drop practice rows, keep the rest
  local keep = {}
  for _, r in ipairs(MyRows()) do
    if not r.practice then
      if r.status == "auction" then r.status = "pending" end
      keep[#keep + 1] = r
    end
  end
  D.db.queue = keep
  wipe(D.remote)
  C_Timer.After(2, D.ReconcileBags)
  C_Timer.After(4, function() Send(Pack("QR"), "GROUP") end)
end

-- Every row I can see, mine and other officers', sorted for the window
function D.QueueRows()
  local list = {}
  for _, r in ipairs(MyRows()) do list[#list + 1] = r end
  for _, r in pairs(D.remote) do list[#list + 1] = r end
  local order = { auction = 1, pending = 2, won = 3 }
  table.sort(list, function(a, b)
    local oa, ob = order[a.status] or 9, order[b.status] or 9
    if oa ~= ob then return oa < ob end
    if (a.skip or 0) ~= (b.skip or 0) then return (a.skip or 0) < (b.skip or 0) end
    return (a.expires or 0) < (b.expires or 0)
  end)
  return list
end

function D.FindRow(uid)
  for i, r in ipairs(MyRows()) do if r.uid == uid then return r, i end end
  return D.remote[uid], nil
end

local function Broadcast(r)
  if r.practice and not D.InGroup() then return end
  Send(Pack("QU", r.uid, r.item, r.holder, r.status, r.winner, r.price, r.expires, r.practice and "P" or ""), "GROUP")
end

local function Changed(r)
  if r then Broadcast(r) end
  if D.RefreshQueue then D.RefreshQueue() end
end

local function RemoveRow(uid, why)
  local rows = MyRows()
  for i, r in ipairs(rows) do
    if r.uid == uid then
      table.remove(rows, i)
      if not (r.practice and not D.InGroup()) then Send(Pack("QD", uid), "GROUP") end
      if why then Print(D.ItemLink(r.item) .. " - " .. why) end
      break
    end
  end
  if D.RefreshQueue then D.RefreshQueue() end
end
D.RemoveRow = RemoveRow

local function NewRow(itemID, inBags, expires)
  D.db.qcounter = (D.db.qcounter or 0) + 1
  local r = {
    uid = D.Clean(D.FirstName(Me()), 20) .. D.db.qcounter .. "x" .. (Now() % 100000),
    item = itemID, holder = Me(), status = "pending", lootT = Now(),
    expires = expires or (Now() + (tonumber(D.Cfg("TRADE_WINDOW")) or 7200)),
    inBags = inBags, practice = D.practice or nil,
  }
  table.insert(MyRows(), r)
  Changed(r)
  return r
end

---------------------------------------------------------------------------
-- v0.2.31: duplicate copies. Every tradeable copy in the holder's bags gets
-- its own row, so after one copy is awarded the next is still in the queue.
---------------------------------------------------------------------------
-- Copies taken out of the queue (DE / bank / removed / no bids) that are still
-- in the bags, so the check below doesn't put them straight back.
local function Released()
  D.db.released = D.db.released or {}
  return D.db.released
end

-- copies in my bags that still have a trade timer (fresh raid loot, not my own bound gear)
local function TradeableCount(itemID)
  local n = 0
  for _, s in ipairs(FindInBags(itemID)) do
    if TradeSecondsLeft(s.bag, s.slot) then n = n + 1 end
  end
  return n
end

-- add a row for each tradeable copy of itemID that has none; returns how many were added
local function AddMissingCopies(itemID)
  if not D.db or D.practice or not D.IsAdmin() then return 0 end
  local tradeable = TradeableCount(itemID)
  if tradeable == 0 then return 0 end
  local rows = 0
  for _, r in ipairs(MyRows()) do
    if r.item == itemID and r.inBags and not r.practice then rows = rows + 1 end
  end
  local free = tradeable - rows
  local rel = Released()
  -- a released copy only counts while it's still here
  rel[itemID] = math.min(rel[itemID] or 0, math.max(0, free))
  if rel[itemID] == 0 then rel[itemID] = nil end
  local missing = free - (rel[itemID] or 0)
  for _ = 1, missing do NewRow(itemID, true, nil) end
  if missing > 0 then
    Print(("Another copy of %s is in your bags - added to the queue (%d total)."):format(D.ItemLink(itemID), rows + missing))
    C_Timer.After(1, D.UpdateTimers)
  end
  return math.max(0, missing)
end
D.AddMissingCopies = AddMissingCopies

-- Add an item (link or id). source = "loot" (auto) or "manual" (Alt-click)
function D.AddToQueue(item, source)
  if not D.db then return end
  if not (D.practice or D.IsAdmin()) then return end
  local itemID = tonumber(type(item) == "string" and item:match("item:(%d+)") or item)
  if not itemID then return end
  local spots = FindInBags(itemID)
  local queued = 0
  for _, r in ipairs(MyRows()) do if r.item == itemID and r.inBags then queued = queued + 1 end end
  if source == "manual" and #spots > 0 and queued >= #spots then
    Print(D.ItemLink(itemID) .. " is already in the queue.")
    return
  end
  -- v0.2.31: putting a copy back by hand cancels one "released" copy
  if source == "manual" and D.db.released and D.db.released[itemID] then
    D.db.released[itemID] = D.db.released[itemID] > 1 and D.db.released[itemID] - 1 or nil
  end
  local r = NewRow(itemID, #spots > queued, nil)
  if source == "manual" then Print("Added to loot queue: " .. D.ItemLink(itemID)) end
  C_Timer.After(1, D.UpdateTimers)
  if D.ShowQueue then D.ShowQueue() end
  return r
end

-- Read real trade timers from the bags (earliest timer goes to the oldest row)
function D.UpdateTimers()
  if not D.db then return end
  local byItem = {}
  for _, r in ipairs(MyRows()) do
    if r.inBags and (r.status == "pending" or r.status == "won" or r.status == "auction") then
      byItem[r.item] = byItem[r.item] or {}
      table.insert(byItem[r.item], r)
    end
  end
  for itemID, rows in pairs(byItem) do
    local times = {}
    for _, s in ipairs(FindInBags(itemID)) do
      local left = TradeSecondsLeft(s.bag, s.slot)
      if left then times[#times + 1] = left end
    end
    table.sort(times)
    table.sort(rows, function(a, b) return a.lootT < b.lootT end)
    for i, r in ipairs(rows) do
      if times[i] then
        local exp = Now() + times[i]
        if math.abs(exp - (r.expires or 0)) > 90 then r.expires = exp; Broadcast(r) end
      end
    end
  end
  if D.RefreshQueue then D.RefreshQueue() end
end

-- Items that left my bags: traded to the winner (or given away / banked / DE'd)
function D.ReconcileBags()
  if not D.db then return end
  local counts, rowsByItem = {}, {}
  for _, r in ipairs(MyRows()) do
    if r.inBags then
      rowsByItem[r.item] = rowsByItem[r.item] or {}
      table.insert(rowsByItem[r.item], r)
    elseif r.holder == Me() and #FindInBags(r.item) > 0 then
      r.inBags = true -- handed to me by another officer, now it's here
      rowsByItem[r.item] = rowsByItem[r.item] or {}
      table.insert(rowsByItem[r.item], r)
    end
  end
  for itemID, rows in pairs(rowsByItem) do
    counts[itemID] = #FindInBags(itemID)
    local extra = #rows - counts[itemID]
    if extra > 0 then
      -- won rows first (that's a finished trade), then the oldest pending ones
      table.sort(rows, function(a, b)
        if (a.status == "won") ~= (b.status == "won") then return a.status == "won" end
        return a.lootT < b.lootT
      end)
      for i = 1, extra do
        local r = rows[i]
        if r.status == "won" then
          RemoveRow(r.uid, "traded to " .. (r.winner or "?") .. ".")
        else
          RemoveRow(r.uid, "left your bags, removed from the queue.")
        end
      end
    end
  end
  -- v0.2.31: any item I'm queueing - make sure every copy I carry has a row
  local seen = {}
  for _, r in ipairs(MyRows()) do
    if r.holder == Me() and not r.practice and not seen[r.item] then
      seen[r.item] = true
      AddMissingCopies(r.item)
    end
  end
end

-- Row buttons
function D.RowOutcome(uid, outcome)
  local r = D.FindRow(uid)
  if not r or r.holder ~= Me() then Print("Only the officer holding the item can do that.") return end
  if r.status == "auction" then Print("Finish or cancel the auction first.") return end
  if outcome == "skip" then
    r.skip = (r.skip or 0) + 1
    Changed(r)
  else
    local label = ({ de = "marked for disenchant", bank = "marked for the guild bank", nobids = "no bids", remove = "removed from the queue" })[outcome] or outcome
    -- v0.2.31: still in the bags, but out of the queue on purpose - don't re-add it
    if r.inBags and not r.practice then Released()[r.item] = (Released()[r.item] or 0) + 1 end
    r.status = "done"
    RemoveRow(uid, label .. ".")
  end
end

function D.HandOff(uid, name)
  local r, i = D.FindRow(uid)
  if not r or not i then Print("You can only hand off items you hold.") return end
  name = D.Canon(D.ResolveName(name))
  if not name or name == "" then return end
  r.holder = name
  r.inBags = nil
  Broadcast(r)
  table.remove(MyRows(), i)
  D.remote[uid] = r
  Print(("Handed off %s to %s - trade it to them."):format(D.ItemLink(r.item), name))
  if D.RefreshQueue then D.RefreshQueue() end
end

---------------------------------------------------------------------------
-- Running an auction (the holder's client)
---------------------------------------------------------------------------
local ticker
local function Cfg(k) return D.Cfg(k) end

local function MinBid(itemID)
  local note = D.ItemNote(itemID)
  return math.max(tonumber(note and note.min) or 0, tonumber(Cfg("MIN_BID")) or 0)
end

-- Main spec bids always beat off spec bids; then highest amount; then the tie rule
local function SortedBids(a)
  local list = {}
  for name, b in pairs(a.bids) do
    list[#list + 1] = { name = name, amount = b.amount, t = b.t, via = b.via, spec = b.spec or "MS" }
  end
  local byBalance = Cfg("TIE_RULE") == "balance"
  local score = a.roll and a.roll.score
  table.sort(list, function(x, y)
    if x.spec ~= y.spec then return x.spec == "MS" end
    if x.amount ~= y.amount then return x.amount > y.amount end
    if score then -- roll-off: higher roll first
      local sx, sy = score[x.name] or -1, score[y.name] or -1
      if sx ~= sy then return sx > sy end
    end
    if byBalance then
      local bx, by = D.Balance(x.name), D.Balance(y.name)
      if bx ~= by then return bx > by end
    end
    return x.t < y.t
  end)
  return list
end
D.SortedBids = SortedBids

-- What a bidder pays if they win: their bid (open), the next bid below theirs
-- of the same spec (sealed), or the fixed off spec price
local function PriceAt(a, list, idx)
  local win = list[idx]
  local osPrice = tonumber(Cfg("OS_PRICE")) or 0
  if win.spec == "OS" and osPrice > 0 then return osPrice end
  if a.mode ~= "sealed" then return win.amount end
  -- next bid of the same spec (an OS bid never sets an MS price)
  local second
  for i = idx + 1, #list do
    if list[i].spec == win.spec then second = list[i].amount break end
  end
  second = second or a.min
  local price = math.min(win.amount, second + (tonumber(Cfg("VICKREY_PLUS")) or 0))
  return math.max(price, a.min)
end

-- Winner and price for the current bids (the natural winner: highest bid,
-- then the tie rule)
function D.AuctionResult(a)
  a = a or D.auction
  if not a then return nil end
  local list = SortedBids(a)
  if #list == 0 then return nil end
  return list[1].name, PriceAt(a, list, 1), list, list[1].spec
end

-- Price a given bidder would pay
function D.PriceFor(a, name)
  a = a or D.auction
  if not a or not name then return nil end
  local list = SortedBids(a)
  for i, b in ipairs(list) do
    if b.name == name then return PriceAt(a, list, i), b.spec end
  end
end

-- Who the Award button gives it to: the bidder the officer picked, else the
-- natural winner. nil while a roll-off is still waiting on rolls.
function D.AuctionPick(a)
  a = a or D.auction
  if not a then return nil end
  if a.pick and a.bids[a.pick] then
    local price, spec = D.PriceFor(a, a.pick)
    return a.pick, price, spec, true
  end
  a.pick = nil
  if a.roll and not a.roll.done then return nil end
  local who, price, _, spec = D.AuctionResult(a)
  return who, price, spec, false
end

-- Officer clicks a bidder row: pick them as the winner (click again = back to automatic)
function D.PickBidder(name)
  local a = D.auction
  if not a then return end
  a.pick = (a.pick ~= name and a.bids[name]) and name or nil
  if D.RefreshAuction then D.RefreshAuction() end
end

---------------------------------------------------------------------------
-- Ties: roll-off (TIE_RULE = "roll"). When bidding closes with the top bids
-- equal, the tied players /roll 1-100; highest wins, a tied roll rolls again.
-- score = round * 1000 + roll, so anyone still in a later round ranks above
-- whoever dropped out earlier.
---------------------------------------------------------------------------
local function TopTie(a)
  local list = SortedBids(a)
  local top = list[1]
  if not top then return nil end
  local names = {}
  for _, b in ipairs(list) do
    if b.spec == top.spec and b.amount == top.amount then names[#names + 1] = b.name end
  end
  if #names < 2 then return nil end
  table.sort(names)
  return names, top.amount
end

local function AnnounceRolls(a, names, again, clicked)
  local short = {}
  for i, n in ipairs(names) do short[i] = D.FirstName(n) end
  D.Chat((again and "Roll tie for %s - %s roll again! /roll" or "Tie for %s at %d DKP: %s - /roll now!"):format(
    D.ItemLink(a.item), again and table.concat(short, ", ") or a.roll.amount, table.concat(short, ", ")),
    "RAID_WARNING", nil, clicked)
end

local function StartRollOff(a, clicked)
  if Cfg("TIE_RULE") ~= "roll" or a.roll then return end
  local names, amount = TopTie(a)
  if not names then return end
  a.roll = { round = 1, amount = amount, waiting = {}, rolled = {}, score = {} }
  for _, n in ipairs(names) do a.roll.waiting[n] = true; a.roll.score[n] = 1000 end
  Print(("Tie at %d DKP between %s - roll-off called."):format(amount, table.concat(names, ", ")))
  AnnounceRolls(a, names, false, clicked)
end

-- A /roll from the system chat line
function D.OnRoll(name, roll, lo, hi)
  local a = D.auction
  local r = a and a.roll
  if not r or r.done or lo ~= 1 or hi ~= 100 then return end
  local who
  for n in pairs(r.waiting) do if D.SameName(n, name) or D.SameName(n, D.Canon(name)) then who = n end end
  if not who or r.rolled[who] then return end -- not in the roll-off, or already rolled this round
  r.rolled[who] = roll
  r.score[who] = r.round * 1000 + roll
  Print(("%s rolled %d."):format(who, roll))
  for n in pairs(r.waiting) do
    if not r.rolled[n] then if D.RefreshAuction then D.RefreshAuction() end return end
  end
  -- everyone rolled: highest wins, or the ones tied on top roll again
  local best, top = -1, {}
  for n, v in pairs(r.rolled) do
    if v > best then best, top = v, { n } elseif v == best then top[#top + 1] = n end
  end
  if #top == 1 then
    r.done = true
    Print(("%s wins the roll-off (%d). Press Award."):format(top[1], best))
  else
    table.sort(top)
    r.round = r.round + 1
    r.waiting, r.rolled = {}, {}
    for _, n in ipairs(top) do r.waiting[n] = true; r.score[n] = r.round * 1000 end
    AnnounceRolls(a, top, true, false)
  end
  if D.RefreshAuction then D.RefreshAuction() end
end

-- "Name rolls 57 (1-100)", built from the game's own string so it follows the client language
local rollPattern
function D.ParseRoll(text)
  if not rollPattern then
    rollPattern = FormatToPattern(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)") .. "$"
  end
  local name, roll, lo, hi = text:match(rollPattern)
  if name then return name, tonumber(roll), tonumber(lo), tonumber(hi) end
end

local function AuctionTick(clicked)
  local a = D.auction
  if not a then if ticker then ticker:Cancel(); ticker = nil end return end
  if not a.closed and GetTime() >= a.endsLocal then
    a.closed = true
    StartRollOff(a, clicked)
    local who, price = D.AuctionResult(a)
    if a.roll and not a.roll.done then
      -- printed by StartRollOff
    elseif who then
      Print(("Bidding closed on %s: %s, %d DKP. Press Award in the auction window."):format(D.ItemLink(a.item), who, price))
    else
      Print("Bidding closed on " .. D.ItemLink(a.item) .. " with no bids.")
    end
    if D.settings.sound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
    -- v0.2.22: if the window got closed mid-auction, put the bids back up
    if D.ShowAuction then D.ShowAuction() end
  end
  if D.RefreshAuction then D.RefreshAuction() end
end

-- clicked = called from a button (lets the raid warning go out right away)
function D.StartAuction(uid, clicked)
  if D.auction then Print("Finish the current auction first.") return end
  local r = D.FindRow(uid)
  if not r then return end
  if r.holder ~= Me() then Print(("%s is holding that item - they run its auction."):format(r.holder)) return end
  if r.status ~= "pending" then return end
  if not D.practice and not D.InRaid() then Print("Auctions only run in a raid (or turn on practice mode).") return end
  local mode = Cfg("AUCTION_MODE") == "open" and "open" or "sealed"
  local secs = tonumber(Cfg("AUCTION_TIME")) or 30
  D.db.acounter = (D.db.acounter or 0) + 1
  local a = {
    aid = r.uid .. "#" .. D.db.acounter, uid = r.uid, item = r.item, mode = mode,
    min = MinBid(r.item), step = tonumber(Cfg("BID_STEP")) or 5,
    endsLocal = GetTime() + secs, ends = Now() + secs, bids = {}, passes = {}, rejected = {},
    practice = D.practice or nil,
  }
  D.auction = a
  r.status = "auction"
  Changed(r)
  -- I'm holding the item, so its full info is cached here even if a bidder's
  -- client has never seen it; send it along so their popup shows the real
  -- name instead of "Item <id>".
  local iName, _, iQuality, iLevel, iEquipLoc = ItemInfo(a.item)
  Send(Pack("AU", a.aid, a.item, a.mode, a.min, a.step, secs, a.practice and "P" or "", tonumber(Cfg("OS_PRICE")) or 0,
    iName and D.Clean(iName, 80) or "", iQuality or "", iLevel or "", iEquipLoc or ""), "GROUP")
  -- v0.2.23: say it again a few seconds in, with the time actually left, for
  -- anyone whose client missed the first one. 0.2.23+ clients ignore repeats.
  C_Timer.After(4, function()
    local cur = D.auction
    if cur ~= a or cur.closed then return end
    local left = math.floor(cur.endsLocal - GetTime())
    if left < 3 then return end
    Send(Pack("AU", a.aid, a.item, a.mode, a.min, a.step, left, a.practice and "P" or "", tonumber(Cfg("OS_PRICE")) or 0,
      iName and D.Clean(iName, 80) or "", iQuality or "", iLevel or "", iEquipLoc or ""), "GROUP")
  end)
  local link = D.ItemLink(a.item)
  local note = D.ItemNote(a.item)
  -- v0.2.31: tell the raid when more copies are coming
  local copies = 0
  for _, q in ipairs(MyRows()) do
    if q.item == a.item and (q.status == "pending" or q.status == "auction") then copies = copies + 1 end
  end
  local more = copies > 1 and (" [%d copies - one at a time]"):format(copies) or ""
  D.Chat(("Bidding open: %s%s - min %d, %ds%s. No add-on? Whisper me !bid <amount> or !pass"):format(
    link, more, a.min, secs, note and note.note and (" (" .. note.note .. ")") or ""), "RAID_WARNING", nil, clicked)
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTicker(0.5, function() AuctionTick(false) end)
  -- I can bid on my own auction too
  D.OnAuctionOpen({ aid = a.aid, item = a.item, mode = a.mode, min = a.min, step = a.step,
    endsLocal = a.endsLocal, from = Me(), practice = a.practice, osPrice = tonumber(Cfg("OS_PRICE")) or 0,
    itemName = iName, itemQuality = iQuality, itemLevel = iLevel, equipLoc = iEquipLoc })
  if D.ShowAuction then D.ShowAuction() end
end

function D.ExtendAuction(secs)
  local a = D.auction
  if not a then return end
  secs = secs or 10
  a.closed = false
  a.endsLocal = math.max(a.endsLocal, GetTime()) + secs
  local left = math.floor(a.endsLocal - GetTime())
  Send(Pack("AT", a.aid, left), "GROUP")
  if D.bidding[a.aid] then D.bidding[a.aid].endsLocal = a.endsLocal end
  a.roll = nil -- reopened: any roll-off starts over when it closes again
  if ticker == nil then ticker = C_Timer.NewTicker(0.5, function() AuctionTick(false) end) end
  if D.RefreshAuction then D.RefreshAuction() end
  if D.UpdateBidPopup then D.UpdateBidPopup() end
end

function D.CloseAuctionNow()
  local a = D.auction
  if not a then return end
  a.endsLocal = GetTime()
  Send(Pack("AT", a.aid, 0), "GROUP")
  AuctionTick(true)
end

local function EndAuction()
  if ticker then ticker:Cancel(); ticker = nil end
  local a = D.auction
  D.auction = nil
  if a then D.bidding[a.aid] = nil end
  if D.HideBidPopup and a then D.HideBidPopup(a.aid) end
  if D.RefreshAuction then D.RefreshAuction() end
end

function D.CancelAuction()
  local a = D.auction
  if not a then return end
  Send(Pack("AC", a.aid), "GROUP")
  local r = D.FindRow(a.uid)
  if r then r.status = "pending"; Changed(r) end
  EndAuction()
  Print("Auction cancelled - the item is back in the queue.")
end

local function NextPending()
  for _, r in ipairs(D.QueueRows()) do
    if r.status == "pending" and r.holder == Me() then return r end
  end
end

-- Award to the picked / winning bidder, or to a name and price given by hand
-- (any bidder, or someone who didn't bid at all)
function D.AwardAuction(clicked, name, price)
  local a = D.auction
  if not a then return end
  local spec
  if name then
    name = D.Canon(name)
    local p2, s2 = D.PriceFor(a, name)
    price, spec = price or p2, s2
    if not price then Print("Give a price for someone who didn't bid.") return end
  else
    local p
    name, p, spec = D.AuctionPick(a)
    price = p
    if not name then
      if a.roll and not a.roll.done then
        Print("Waiting for the roll-off - or click a bidder to pick the winner yourself.")
      else
        Print("No bids - use No bids / Disenchant / Bank on the queue row.")
      end
      return
    end
  end
  price = math.max(0, math.floor(tonumber(price) or 0))
  local itemName = D.ItemName(a.item)
  D.Spend(name, price, a.item, itemName, spec)
  local r = D.FindRow(a.uid)
  if r then
    r.status, r.winner, r.price = "won", name, price
    Changed(r)
  end
  Send(Pack("AX", a.aid, name, price), "GROUP")
  D.Chat(("%s has been awarded to %s for %d DKP%s"):format(D.ItemLink(a.item), name, price,
    spec == "OS" and " (off spec)" or ""), "RAID", nil, clicked)
  if D.OnAuctionResult then D.OnAuctionResult(a.aid, name, price) end
  EndAuction()
  -- v1.2.0: the award was a click, so the winner's trade window can be opened right away (items fill in by themselves)
  if clicked and not a.practice and D.settings.tradeOpen ~= false and r then D.TradeWinner(r, true) end
  if not a.practice then AddMissingCopies(a.item) end -- v0.2.31
  if D.settings.autoNext then
    C_Timer.After(4, function()
      local nxt = NextPending()
      if nxt and not D.auction then D.StartAuction(nxt.uid, false) end
    end)
  end
end

-- No sale: "nobids" (default), or straight to "de" / "bank" from the
-- auction window (v0.2.29) instead of having to go back to the queue
function D.NoBidsAuction(outcome)
  local a = D.auction
  if not a then return end
  outcome = outcome or "nobids"
  local item = a.item
  Send(Pack("AC", a.aid), "GROUP")
  local r = D.FindRow(a.uid)
  if r then r.status = "pending"; Changed(r) end
  EndAuction()
  if r then D.RowOutcome(r.uid, outcome) end
  if outcome == "de" or outcome == "bank" then
    D.Chat(("%s will be %s."):format(D.ItemLink(item), outcome == "de" and "disenchanted" or "sent to the guild bank"),
      "RAID", nil, true)
  end
end

---------------------------------------------------------------------------
-- Receiving bids (auctioneer)
---------------------------------------------------------------------------
local function Reply(name, via, aid, ok, text)
  if via == "self" then return end
  if via == "addon" then
    Send(Pack("AR", aid, ok and "1" or "0", text), "WHISPER", name)
  else
    D.Chat("[DKP] " .. text, "WHISPER", name, false)
  end
end

-- via: "addon", "whisper" or "self"; spec: "MS" (default) or "OS"
local function TakeBid(name, amount, via, spec)
  local a = D.auction
  if not a or a.closed then
    if via == "whisper" then D.Chat("[DKP] No auction is open right now.", "WHISPER", name, false) end
    return
  end
  name = D.Canon(name)
  spec = spec == "OS" and "OS" or "MS"
  local osPrice = tonumber(Cfg("OS_PRICE")) or 0
  amount = math.floor(tonumber(amount) or -1)
  if spec == "OS" and osPrice > 0 then amount = osPrice end -- fixed off spec price
  local bal = D.Balance(name)
  local class = D.ClassOf(name)
  local why
  if amount < a.min and not (spec == "OS" and osPrice > 0) then
    why = ("Minimum bid is %d."):format(a.min)
  elseif a.mode == "open" then
    local top
    for _, b in ipairs(SortedBids(a)) do if b.spec == spec then top = b break end end
    if top and top.name ~= name and amount < top.amount + a.step then
      why = ("Bid at least %d (current high %d)."):format(top.amount + a.step, top.amount)
    end
  end
  if not why and not a.practice and tonumber(Cfg("ALLOW_NEGATIVE")) ~= 1 and amount > bal then
    why = ("You only have %d DKP."):format(bal)
  end
  if not why and tonumber(Cfg("USABLE_ONLY")) == 1 then
    local ok, reason = D.CanUse(a.item, class)
    if not ok then why = "Rejected: " .. reason .. "." end
  end
  if why then
    a.rejected[name] = why
    Reply(name, via, a.aid, false, why)
  else
    a.rejected[name] = nil
    a.passes[name] = nil
    a.bids[name] = { amount = amount, t = GetTime(), via = via, spec = spec }
    Reply(name, via, a.aid, true, ("Bid received: %d%s."):format(amount, spec == "OS" and " off spec" or ""))
    if a.mode == "open" then Send(Pack("AH", a.aid, name, amount, spec), "GROUP") end
    -- anti-snipe: a bid in the last few seconds buys everyone a few more
    local window, extend = tonumber(Cfg("SNIPE_WINDOW")) or 0, tonumber(Cfg("SNIPE_EXTEND")) or 0
    local left = a.endsLocal - GetTime()
    if window > 0 and extend > 0 and left < window then
      a.endsLocal = GetTime() + extend
      Send(Pack("AT", a.aid, extend), "GROUP")
      if D.bidding[a.aid] then D.bidding[a.aid].endsLocal = a.endsLocal end
      if D.UpdateBidPopup then D.UpdateBidPopup() end
    end
  end
  if D.RefreshAuction then D.RefreshAuction() end
end
D.TakeBid = TakeBid

local function TakePass(name)
  local a = D.auction
  if not a then return end
  name = D.Canon(name)
  a.bids[name] = nil
  a.passes[name] = true
  if D.RefreshAuction then D.RefreshAuction() end
end

-- "!bid 40", "!pass", "!dkp" whispers (players without the add-on, incl. pugs)
local function OnWhisper(text, sender)
  if Secret(text, sender) or not text then return end
  local low = text:lower()
  local cmd, arg = low:match("^%s*!(%a+)%s*(%d*)")
  if not cmd then return end
  sender = D.Short(sender)
  if cmd == "bid" or cmd == "ms" then
    TakeBid(sender, arg, "whisper", low:find("%f[%a]os%f[%A]") and "OS" or "MS")
  elseif cmd == "os" then
    TakeBid(sender, arg, "whisper", "OS")
  elseif cmd == "standby" and D.IsAdmin() then
    local name = D.Canon(sender)
    if low:find("off") then
      D.RemoveBench(name)
      D.Chat("[DKP] You're off the bench list.", "WHISPER", sender, false)
    else
      local added = D.AddBench(name)
      D.Chat(added and "[DKP] You're on the bench list - you'll get standby DKP." or "[DKP] You're already on the bench list.",
        "WHISPER", sender, false)
    end
  elseif cmd == "pass" then
    TakePass(sender)
    D.Chat("[DKP] Pass noted.", "WHISPER", sender, false)
  elseif cmd == "dkp" and D.IsAdmin() then
    D.Chat(("[DKP] You have %d DKP."):format(D.Balance(D.Canon(sender))), "WHISPER", sender, false)
  end
end

---------------------------------------------------------------------------
-- Bidding (every raider's client)
---------------------------------------------------------------------------
local TrustedAuctioneer = function(name) return D.TrustedOfficer(name) end

-- v0.7.1: a different sound when the item is on MY wishlist or is a BIS upgrade for me
-- (the plain "auction started" sound is for everything else). /dkp bis sound ...
local function WantSounds()
  local K = SOUNDKIT or {}
  return {
    { "Level up", K.LEVELUP or 888 },
    { "Quest complete", K.IG_QUEST_LIST_COMPLETE or 878 },
    { "Alarm", K.ALARM_CLOCK_WARNING_3 or 12867 },
    { "Coins", K.LOOT_WINDOW_COIN_SOUND or 120 },
  }
end
D.WantSounds = WantSounds

-- true, "wish" | "bis" when I'd want this auction's item
function D.WantsItem(info)
  local id = tonumber(info and info.item)
  if not id then return false end
  local ok, list = pcall(D.MyWishes)
  if ok then
    local mine = {}
    for _, w in ipairs(list) do mine[w] = true end
    if mine[id] then return true, "wish" end
    -- a token auction: wishing for the tier piece it makes for my class counts
    if D.BiS then for _, pid in ipairs(D.BiS.PiecesOf(id)) do if mine[pid] then return true, "wish" end end end
  end
  if D.BiS then
    local okv, v = pcall(D.BiS.Verdict, id, { ilvl = info.itemLevel, equipLoc = info.equipLoc })
    if okv and v and v.tier == "BIS" and v.kind == "upgrade" then return true, "bis" end
  end
  return false
end

function D.PlayWantSound(n)
  local list = WantSounds()
  local s = list[tonumber(n or D.settings.wantSoundId) or 2] or list[2]
  pcall(PlaySound, s[2])
  return s[1]
end

function D.OnAuctionOpen(info)
  D.bidding[info.aid] = info
  info.myBal = D.Balance(D.Me())
  if not IsInGuild() or not D.data or not D.data.bal[D.Me()] then
    -- pugs (or anyone with an empty ledger) ask the auctioneer for their balance
    if info.from ~= D.Me() then Send(Pack("AQ", info.aid), "WHISPER", info.from) end
  end
  if D.settings.popup and D.ShowBidPopup then D.ShowBidPopup(info) end
  if D.settings.sound then
    if D.settings.wantSound ~= false and D.WantsItem(info) then
      D.PlayWantSound() -- instead of the usual sound
    else
      PlaySound(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960)
    end
  end
end

function D.SendBid(aid, amount, spec)
  local info = D.bidding[aid]
  if not info then return end
  spec = spec == "OS" and "OS" or "MS"
  if info.from == D.Me() then
    TakeBid(D.Me(), amount, "self", spec)
    local a = D.auction
    local why = a and a.rejected[D.Canon(D.Me())]
    info.status = why or ("Bid received: %d%s."):format(amount, spec == "OS" and " off spec" or "")
    info.ok = not why
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  else
    Send(Pack("AB", aid, amount, spec), "WHISPER", info.from)
    info.status = "Sending..."
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  end
end

function D.SendPass(aid)
  local info = D.bidding[aid]
  if not info then return end
  if info.from == D.Me() then TakePass(D.Me()) else Send(Pack("AP", aid), "WHISPER", info.from) end
  info.status, info.ok, info.passed = "Passed.", true, true
  if D.HideBidPopup then D.HideBidPopup(aid) end
  -- v0.2.26: changed your mind? The reopen bar stays up after a pass too.
  if D.ShowBidBar and info.endsLocal > GetTime() then D.ShowBidBar(info) end
end

---------------------------------------------------------------------------
-- Live messages
---------------------------------------------------------------------------
local H = D.handlers

H.AU = function(p, sender)
  local aid, item, mode, min, step, secs = p[2], tonumber(p[3]), p[4], tonumber(p[5]), tonumber(p[6]), tonumber(p[7])
  if not (aid and item and secs) or not TrustedAuctioneer(sender) then return end
  -- a repeat of an auction I already have (or already finished): just sync the clock
  D.seenAuctions = D.seenAuctions or {}
  if D.seenAuctions[aid] then
    local info = D.bidding[aid]
    if info then
      info.endsLocal = GetTime() + secs
      if D.UpdateBidPopup then D.UpdateBidPopup() end
    end
    return
  end
  D.seenAuctions[aid] = true
  -- name/quality/ilvl/equip slot from the auctioneer, who's holding the item -
  -- fills in for my own item cache if I've never seen this item before
  D.OnAuctionOpen({ aid = aid, item = item, mode = mode, min = min or 0, step = step or 5,
    endsLocal = GetTime() + secs, from = sender, practice = p[8] == "P" or nil, osPrice = tonumber(p[9]) or 0,
    itemName = p[10] and p[10] ~= "" and p[10] or nil, itemQuality = tonumber(p[11]),
    itemLevel = tonumber(p[12]), equipLoc = p[13] and p[13] ~= "" and p[13] or nil })
end
H.AT = function(p, sender)
  local info = D.bidding[p[2] or ""]
  if info and D.SameName(info.from, sender) then
    info.endsLocal = GetTime() + (tonumber(p[3]) or 0)
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  end
end
H.AH = function(p, sender)
  local info = D.bidding[p[2] or ""]
  if info and D.SameName(info.from, sender) then
    info.high, info.highName = tonumber(p[4]), p[3]
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  end
end
H.AX = function(p, sender)
  local aid, name, price = p[2], p[3], tonumber(p[4])
  local info = D.bidding[aid or ""]
  if info and D.SameName(info.from, sender) then
    D.bidding[aid] = nil
    if D.HideBidPopup then D.HideBidPopup(aid) end
    if name and D.SameName(name, D.Me()) then
      D.Toast("You won " .. (info.itemName or D.ItemName(info.item)) .. "!", ("%d DKP. Trade %s to get it."):format(price or 0, sender))
    end
  end
end
H.AC = function(p, sender)
  local info = D.bidding[p[2] or ""]
  if info and D.SameName(info.from, sender) then
    D.bidding[p[2]] = nil
    if D.HideBidPopup then D.HideBidPopup(p[2]) end
  end
end
H.AB = function(p, sender, channel)
  if channel ~= "WHISPER" then return end
  local a = D.auction
  if a and a.aid == p[2] then TakeBid(sender, p[3], "addon", p[4]) end
end
H.AP = function(p, sender, channel)
  if channel ~= "WHISPER" then return end
  local a = D.auction
  if a and a.aid == p[2] then TakePass(sender) end
end
H.AR = function(p, sender, channel)
  local info = D.bidding[p[2] or ""]
  if channel == "WHISPER" and info and D.SameName(info.from, sender) then
    info.ok = p[3] == "1"
    info.status = p[4]
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  end
end
H.AQ = function(p, sender, channel) -- balance question from a bidder
  if channel == "WHISPER" and D.auction and D.auction.aid == p[2] then
    Send(Pack("AQR", p[2], D.Balance(D.Canon(sender))), "WHISPER", sender)
  end
end
H.AQR = function(p, sender, channel)
  local info = D.bidding[p[2] or ""]
  if channel == "WHISPER" and info and D.SameName(info.from, sender) then
    info.myBal = tonumber(p[3]) or info.myBal
    if D.UpdateBidPopup then D.UpdateBidPopup() end
  end
end

-- queue rows from other officers
H.QU = function(p, sender)
  local uid = p[2]
  if not uid then return end
  if not (D.IsAdmin(sender) or p[9] == "P") then return end
  local holder = p[4]
  if holder and D.SameName(holder, D.Me()) then
    -- handed to me: it's my row now
    for _, r in ipairs(MyRows()) do if r.uid == uid then return end end
    local r = { uid = uid, item = tonumber(p[3]), holder = D.Me(), status = p[5] ~= "auction" and p[5] or "pending",
      winner = p[6] ~= "" and p[6] or nil, price = tonumber(p[7]), expires = tonumber(p[8]), lootT = Now(),
      practice = p[9] == "P" or nil }
    table.insert(MyRows(), r)
    D.remote[uid] = nil
    Print(("%s handed you %s."):format(sender, D.ItemLink(r.item)))
    C_Timer.After(1, D.ReconcileBags)
  else
    D.remote[uid] = { uid = uid, item = tonumber(p[3]), holder = holder, status = p[5], winner = p[6] ~= "" and p[6] or nil,
      price = tonumber(p[7]), expires = tonumber(p[8]), lootT = 0 }
  end
  if D.RefreshQueue then D.RefreshQueue() end
end
H.QD = function(p)
  if p[2] then D.remote[p[2]] = nil end
  if D.RefreshQueue then D.RefreshQueue() end
end
H.QR = function()
  if not D.IsAdmin() and not D.practice then return end
  C_Timer.After(math.random() * 3, function() for _, r in ipairs(MyRows()) do Broadcast(r) end end)
end

---------------------------------------------------------------------------
-- Trading the item to the winner
---------------------------------------------------------------------------
local tradeTarget
local function WonRowsFor(name)
  local list = {}
  for _, r in ipairs(MyRows()) do
    if r.status == "won" and r.winner and D.SameName(r.winner, name) and #FindInBags(r.item) > 0 then list[#list + 1] = r end
  end
  return list
end

-- v1.2.0: auto trade. What the game allows: opening a trade and putting items into it are fine for an add-on; accepting
-- the trade (AcceptTrade) needs a real click, so the final Trade button is always yours.
local fillToken = 0
local function TradeHas(itemID)
  for i = 1, (MAX_TRADE_ITEMS or 7) - 1 do
    local link = GetTradePlayerItemLink and GetTradePlayerItemLink(i)
    if link and tonumber(link:match("item:(%d+)")) == itemID then return true end
  end
  return false
end

-- the unit token of a group member by name ("raid7", "party2"), or nil
local function UnitFor(name)
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, (raid and n or math.max(0, n - 1)) do
    local unit = (raid and "raid" or "party") .. i
    local un = UnitName(unit)
    if un and not Secret(un) and D.SameName(un, name) then return unit end
  end
end

-- Opens a trade with the winner of a won row. Only from a click ("clicked"): that is what lets the game open the window.
function D.TradeWinner(row, clicked)
  if not row or row.status ~= "won" or not row.winner or row.holder ~= Me() then return false end
  if D.SameName(row.winner, Me()) then return false end
  if not clicked then return false end
  if TradeFrame and TradeFrame:IsShown() then return false end
  local who = D.FirstName(row.winner) or row.winner
  local unit = UnitFor(row.winner)
  if not unit then Print(("%s isn't in your group."):format(who)) return false end
  if CheckInteractDistance and not CheckInteractDistance(unit, 2) then
    Print(("%s is too far away to trade - get within about 10 yards and click again."):format(who))
    return false
  end
  local ok = pcall(InitiateTrade, unit)
  return ok
end

-- Puts every won item the trade partner is owed into the trade window, one after another (the server needs a moment
-- between slots). If something could not be placed, the old "ADD ... TO TRADE" button shows up as a fallback.
function D.AutoFillTrade()
  fillToken = fillToken + 1
  local my = fillToken
  if D.HideTradeButton then D.HideTradeButton() end
  local budget = #WonRowsFor(tradeTarget or "") * 3 + 3
  local function Step()
    if my ~= fillToken or not tradeTarget or not (TradeFrame and TradeFrame:IsShown()) then return end
    budget = budget - 1
    local placed = budget > 0 and D.PlaceNextTradeItem()
    if placed then
      C_Timer.After(0.35, Step)
    else
      local missing = {}
      for _, r in ipairs(WonRowsFor(tradeTarget)) do if not TradeHas(r.item) then missing[#missing + 1] = r end end
      if #missing > 0 and D.ShowTradeButton then D.ShowTradeButton(missing) end
    end
  end
  C_Timer.After(0.2, Step)
end

function D.TradeSlash(rest)
  local a, b = (rest or ""):lower():match("^(%S*)%s*(%S*)")
  if (a == "fill" or a == "open") and (b == "on" or b == "off") then
    D.settings[a == "fill" and "tradeFill" or "tradeOpen"] = (b == "on")
  end
  Print(("Auto trade: fill the trade window %s, open the trade after an award click %s. /dkp trade fill on|off  ·  /dkp trade open on|off")
    :format(D.settings.tradeFill ~= false and "ON" or "off", D.settings.tradeOpen ~= false and "ON" or "off"))
  Print("(You always click Trade yourself - the game doesn't let an add-on accept a trade.)")
end

local function OnTradeShow()
  local name = UnitName("NPC")
  if not name or Secret(name) then tradeTarget = nil return end
  tradeTarget = D.Canon(name)
  local rows = WonRowsFor(tradeTarget)
  if #rows == 0 then return end
  if D.settings.tradeFill ~= false then D.AutoFillTrade()
  elseif D.ShowTradeButton then D.ShowTradeButton(rows) end
end

-- One click puts the next won item into the trade window
function D.PlaceNextTradeItem()
  if not tradeTarget then return end
  for _, r in ipairs(WonRowsFor(tradeTarget)) do
    local already = false
    for i = 1, (MAX_TRADE_ITEMS or 7) - 1 do
      local link = GetTradePlayerItemLink and GetTradePlayerItemLink(i)
      local id = link and tonumber(link:match("item:(%d+)"))
      if id == r.item then already = true end
    end
    if not already then
      local spot = FindInBags(r.item)[1]
      if spot then
        for i = 1, (MAX_TRADE_ITEMS or 7) - 1 do
          if not GetTradePlayerItemInfo(i) then
            ClearCursor()
            Pickup(spot.bag, spot.slot)
            ClickTradeButton(i)
            return true
          end
        end
      end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Practice mode
---------------------------------------------------------------------------
function D.SetPractice(on)
  if not D.db then return end
  if not on and D.auction then D.CancelAuction() end
  D.practice = on or nil
  if not on then
    wipe(D.db.practice)
    local keep = {}
    for _, r in ipairs(MyRows()) do if not r.practice then keep[#keep + 1] = r end end
    D.db.queue = keep
  end
  Print(on and "Practice mode ON - auctions work anywhere, nothing touches the real ledger or raid chat."
    or "Practice mode off - practice entries thrown away.")
  D.Compute()
  if D.RefreshQueue then D.RefreshQueue() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local LOOT_SELF = FormatToPattern(LOOT_ITEM_SELF)
local LOOT_SELF_MULTI = FormatToPattern(LOOT_ITEM_SELF_MULTIPLE)

-- v0.4.6: looted epics are only queued while there is a raid in the add-on
-- (created or running, in the last 12 hours), so a non-DKP run doesn't fill
-- the queue. Alt-click still adds an item by hand.
local function RaidActive()
  local now = D.Now()
  local open = D.OpenSession and D.OpenSession()
  if open and now - (open.start or 0) < 12 * 3600 then return true end
  local planned = D.PlannedRaid and D.PlannedRaid()
  return planned ~= nil and now - (planned.created or 0) < 12 * 3600
end

local function OnLootMsg(msg)
  if not msg or Secret(msg) then return end
  if not D.practice and not (D.InRaid() and D.IsAdmin()) then return end
  -- v0.2.31: "You receive loot: [Item]x2." used to add one row; add one per copy
  local link, qty
  if LOOT_SELF_MULTI then link, qty = msg:match(LOOT_SELF_MULTI) end
  if not link and LOOT_SELF then link = msg:match(LOOT_SELF) end
  if not link then return end
  local itemID = tonumber(link:match("item:(%d+)"))
  if not itemID then return end
  local quality = select(3, D.GetItemInfo(itemID))
  if quality and quality >= (tonumber(D.Cfg("QUEUE_QUALITY")) or 4) then
    if not D.practice and not RaidActive() then return end
    for _ = 1, math.max(1, math.min(10, tonumber(qty) or 1)) do D.AddToQueue(itemID, "loot") end
  end
end

local warned = {}
local function CheckWarnings()
  local red = tonumber(D.Cfg("WARN_RED")) or 600
  for _, r in ipairs(MyRows()) do
    local left = (r.expires or 0) - Now()
    -- v0.4.6: only items this character is holding (the queue is shared by all my characters)
    if r.status ~= "done" and left > 0 and left < red and not warned[r.uid] and D.SameName(r.holder or "", Me()) then
      warned[r.uid] = true
      D.Toast("Trade window closing", D.ItemName(r.item) .. (" - %d min left"):format(math.ceil(left / 60)),
        function() if D.ShowQueue then D.ShowQueue() end end)
    end
  end
end

function D.InitLoot()
  if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", function(link)
    if link and type(link) == "string" and IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()
        and link:find("item:", 1, true) and (D.practice or D.IsAdmin()) then
      D.AddToQueue(link, "manual")
    end
  end) end
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_LOOT", "CHAT_MSG_WHISPER", "CHAT_MSG_SYSTEM", "TRADE_SHOW", "TRADE_CLOSED", "BAG_UPDATE_DELAYED" }) do
    pcall(f.RegisterEvent, f, e)
  end
  local bagPending
  f:SetScript("OnEvent", function(_, event, ...)
    if not D.ready then return end
    if event == "CHAT_MSG_LOOT" then
      OnLootMsg((...))
    elseif event == "CHAT_MSG_WHISPER" then
      local text, sender = ...
      if D.auction or (text and not Secret(text) and (text:match("^%s*!dkp") or text:lower():match("^%s*!standby"))) then
        OnWhisper(text, sender)
      end
    elseif event == "CHAT_MSG_SYSTEM" then
      local text = ...
      if D.auction and D.auction.roll and text and not Secret(text) then
        local name, roll, lo, hi = D.ParseRoll(text)
        if name then D.OnRoll(name, roll, lo, hi) end
      end
    elseif event == "TRADE_SHOW" then
      OnTradeShow()
    elseif event == "TRADE_CLOSED" then
      tradeTarget = nil
      fillToken = fillToken + 1 -- v1.2.0: stop an auto-fill that was still running
      if D.HideTradeButton then D.HideTradeButton() end
      C_Timer.After(1.5, D.ReconcileBags)
    elseif event == "BAG_UPDATE_DELAYED" then
      if not bagPending then
        bagPending = true
        C_Timer.After(2, function() bagPending = false; D.ReconcileBags() end)
      end
    end
  end)
  C_Timer.NewTicker(60, function()
    if not D.ready then return end
    D.UpdateTimers()
    CheckWarnings()
  end)
end
