local ADDON, D = ...

-- Defaults. Everything marked (GM) can be changed in game by the Guild Master
-- on the Settings tab; those changes are synced to everyone and win over this file.
D.Config = {
  PREFIX = "GLDKP",          -- addon message prefix (max 16 chars)

  ADMIN_RANK = 1,            -- (GM) ranks 0..this can award, spend, undo and run loot

  -- Raid awards (GM)
  ONTIME = 10,
  CLEAR = 20,                -- full clear
  BENCH = 10,                -- standby: what bench players get for the night
  ONTIME_CUTOFF = "19:00",   -- realm time; joined later = late (no on-time award)
  PODIUM_ON = 1,             -- (GM) 1 = End raid collects stats and shows the awards screen
  PODIUM_ROASTS = 1,         -- (GM) 1 = the joke awards (Floor Inspector, Loot Goblin...) can be drawn
  BOSS_DEFAULT = 10,         -- used for a boss that has no value of its own

  -- Auctions (GM)
  AUCTION_MODE = "sealed",   -- "sealed" (Vickrey: winner pays the 2nd-highest bid) or "open"
  MIN_BID = 10,
  BID_STEP = 5,
  AUCTION_TIME = 30,         -- seconds
  VICKREY_PLUS = 0,          -- add this to the 2nd-highest bid (some guilds use +1)
  TIE_RULE = "roll",         -- "roll" (tied bidders /roll 1-100), "first" (earliest bid wins) or "balance" (higher balance wins)
  OS_PRICE = 0,              -- off spec: 0 = bid like normal (only wins if nobody bids main spec), >0 = fixed price
  SNIPE_WINDOW = 5,          -- anti-snipe: a bid with less than this many seconds left...
  SNIPE_EXTEND = 5,          -- ...resets the timer to this many seconds (0 = off)
  USABLE_ONLY = 1,           -- 1 = reject bids on items the bidder's class can't use
  ALLOW_NEGATIVE = 0,        -- 1 = bids above your balance are allowed

  -- Loot queue
  QUEUE_QUALITY = 4,         -- auto-add looted items of this quality and up (3 rare, 4 epic)
  TRADE_WINDOW = 7200,       -- fallback trade timer (seconds) if the tooltip can't be read
  WARN_YELLOW = 1800,        -- row turns yellow under 30 min
  WARN_RED = 600,            -- row turns red under 10 min (and a toast pops)

  -- Decay (GM)
  DECAY_PCT = 10,

  -- Starting balance from Guild Ladder points (GM)
  DKP_RATE = 0.25,
  DKP_CAP = 200,

  PHASE_START = 0,           -- (GM) server time; "items this phase" counts from here

  ATTENDANCE_RAIDS = 10,     -- attendance % over the last N raid nights

  BIS_PHASE = 3,             -- (GM) v0.6.0: which BiS list phase verdicts use: 0 Pre-raid, 1-5 = P1-P5

  -- Automatic weekly decay (GM) - v0.4.6. Day: 1 Sunday ... 7 Saturday; time is realm time
  DECAY_AUTO = 0,
  DECAY_DAY = 3,
  DECAY_TIME = "03:00",

  -- Readiness (GM) - v0.4.0. Per item: "req" (flagged red), "rec" (flagged amber, red on Strict bosses), "off"
  RD_FLASK = "req",          -- flask, or battle + guardian elixir
  RD_FOOD = "req",           -- Well Fed
  RD_ENCH = "req",           -- missing enchants
  RD_GEMS = "req",           -- empty gem sockets
  RD_SCROLL = "rec",
  RD_OIL = "rec",            -- weapon oil / stone / poison
  RD_MINILVL = 100,          -- gear checks skip items below this item level
  RD_DEFAULT = "std",        -- bosses with no setting of their own: "off", "std" or "strict"
  RD_BONUS_ON = 0,           -- 1 = the Prepared bonus button is shown on Readiness
  RD_BONUS = 5,              -- DKP per boss
  RD_JUDGE = "kill",         -- judged on the "kill" pull or the "first" pull
}

-- Keys the GM can change in game, with how to show them on the Settings tab.
D.SETTING_ORDER = {
  { "ADMIN_RANK", "Officer rank (0 = GM only)", "int" },
  { "ONTIME", "On-time award", "int" },
  { "CLEAR", "Full clear award", "int" },
  { "BENCH", "Bench / standby award", "int" },
  { "ONTIME_CUTOFF", "On-time cutoff (realm time, HH:MM)", "text" },
  { "BOSS_DEFAULT", "Boss kill (no value set)", "int" },
  { "AUCTION_MODE", "Auction mode (sealed / open)", "text" },
  { "MIN_BID", "Minimum bid", "int" },
  { "BID_STEP", "Bid step", "int" },
  { "AUCTION_TIME", "Auction length (seconds)", "int" },
  { "VICKREY_PLUS", "Sealed: add to 2nd-highest bid", "int" },
  { "TIE_RULE", "Tie rule (roll / first / balance)", "text" },
  { "OS_PRICE", "Off spec price (0 = bid normally)", "int" },
  { "SNIPE_WINDOW", "Anti-snipe: last N seconds", "int" },
  { "SNIPE_EXTEND", "Anti-snipe: reset timer to N sec", "int" },
  { "USABLE_ONLY", "Reject unusable items (1 / 0)", "int" },
  { "ALLOW_NEGATIVE", "Allow bids above balance (1 / 0)", "int" },
  { "DECAY_PCT", "Weekly decay %", "int" },
  { "DKP_RATE", "Ladder points to DKP rate", "num" },
  { "DKP_CAP", "Starting balance cap", "int" },
  { "BIS_PHASE", "BiS list phase (0 pre-raid, 1-5)", "int" }, -- v0.6.0
}

-- Which armor and weapons each class can use (classic rules, by item subclass).
-- Armor subclass: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield. 0 misc (rings, necks, trinkets) = everyone.
-- Weapon subclass: 0 1h axe, 1 2h axe, 2 bow, 3 gun, 4 1h mace, 5 2h mace, 6 polearm, 7 1h sword,
-- 8 2h sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
D.CAN_USE = {
  WARRIOR = { armor = { 1, 2, 3, 4, 6 }, weapon = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 } },
  PALADIN = { armor = { 1, 2, 3, 4, 6 }, weapon = { 0, 1, 4, 5, 6, 7, 8 } },
  HUNTER  = { armor = { 1, 2, 3 },       weapon = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 } },
  ROGUE   = { armor = { 1, 2 },          weapon = { 0, 2, 3, 4, 7, 13, 15, 16, 18 } },
  PRIEST  = { armor = { 1 },             weapon = { 4, 10, 15, 19 } },
  SHAMAN  = { armor = { 1, 2, 3, 6 },    weapon = { 0, 1, 4, 5, 10, 13, 15 } },
  MAGE    = { armor = { 1 },             weapon = { 7, 10, 15, 19 } },
  WARLOCK = { armor = { 1 },             weapon = { 7, 10, 15, 19 } },
  DRUID   = { armor = { 1, 2 },          weapon = { 4, 5, 10, 13, 15 } },
}
