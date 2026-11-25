-- PluribusHive Distributed Compute Mesh (Optimal Leveling & Material Farming Guides)
-- Pools gathered guild game resources (live AH prices, Guild Shopping List demand,
-- passive zone XP/loot/gather telemetry, and Azeroth 1.60.1 route data) and splits
-- optimization work across idle guild members under strict anti-lag CPU & FPS budgets.

PluribusHiveCompute = {
	initialized = false,
	activeJob = nil,
	activeCoroutine = nil,
	activeShardIdx = nil,
	workerStatus = "IDLE_READY", -- IDLE_READY | COMPUTING | PAUSED_COMBAT | PAUSED_INSTANCE | PAUSED_FPS | PAUSED_MOVING | OPTED_OUT
	lastSliceMs = 0,
	totalShardsComputed = 0,
	peerCapabilities = {}, -- [name] = { enabled = bool, budgetMs = num, lastSeen = ts }
	subView = "leveling",  -- leveling | farming | mesh
	selectedBracket = "AUTO",
	selectedPriority = "BALANCED",
	selectedFarmTarget = "GUILD_NEEDS",
	zoneSession = { zone = nil, enteredAt = 0, xp = 0, copper = 0, items = {} },
	catalogCursor = 1,
	lastRefinementAt = 0,
	refinementCursor = 1,
}
_G.PluribusHiveCompute = PluribusHiveCompute

local TICK_INTERVAL = 0.10 -- Run compute slices at most 10 Hz (<1.5% idle CPU at 1.5ms budget)
local SHARD_STEAL_TIMEOUT = 10 -- Reassign unclaimed/stalled shards after 10s so jobs always finish
local TELEM_SHARE_INTERVAL = 300
local REFINE_INTERVAL = 18 -- Run continuous background route refinement every 18s while idle

local function NowMs()
	if debugprofilestop then
		return debugprofilestop()
	end
	return (GetTime and GetTime() or 0) * 1000
end

-- ============================================================================
-- AZEROTH 1.60.1 KNOWLEDGE BASE (Enriched live by Hive Telemetry + AH Prices)
-- ============================================================================
local LEVELING_ZONES = {
	{ id = "elwynn",     zone = "Elwynn Forest",       minL = 1,  maxL = 12, x = 42.1, y = 65.9, cont = 1, baseXpHr = 7800,  baseGoldHr = 1200,  questHub = "Goldshire & Northshire",        mobs = "Kobolds, Defias, Wolves",          soloSafe = 1.00 },
	{ id = "durotar",    zone = "Durotar",             minL = 1,  maxL = 12, x = 52.0, y = 41.6, cont = 2, baseXpHr = 7700,  baseGoldHr = 1150,  questHub = "Razor Hill & Sen'jin",          mobs = "Quilboar, Scorpids, Kul Tiras",    soloSafe = 1.00 },
	{ id = "dunmorogh",  zone = "Dun Morogh",          minL = 1,  maxL = 12, x = 47.0, y = 52.5, cont = 1, baseXpHr = 7600,  baseGoldHr = 1250,  questHub = "Kharanos & Amberstill",         mobs = "Troggs, Frostmane Trolls",         soloSafe = 1.00 },
	{ id = "barrens",    zone = "The Barrens",         minL = 10, maxL = 25, x = 51.5, y = 30.3, cont = 2, baseXpHr = 14800, baseGoldHr = 4200,  questHub = "Crossroads & Ratchet",          mobs = "Raptors, Centaurs, Quilboar",      soloSafe = 0.96 },
	{ id = "westfall",   zone = "Westfall",            minL = 10, maxL = 20, x = 56.5, y = 52.6, cont = 1, baseXpHr = 13600, baseGoldHr = 3900,  questHub = "Sentinel Hill",                 mobs = "Defias, Gnolls, Harvest Golems",   soloSafe = 0.92 },
	{ id = "lochmodan",  zone = "Loch Modan",          minL = 10, maxL = 20, x = 35.4, y = 48.2, cont = 1, baseXpHr = 13400, baseGoldHr = 3700,  questHub = "Thelsamar & Farstrider Lodge",  mobs = "Troggs, Crocolisks, Ogres",        soloSafe = 0.96 },
	{ id = "darkshore",  zone = "Darkshore",           minL = 10, maxL = 20, x = 37.3, y = 43.9, cont = 2, baseXpHr = 14500, baseGoldHr = 3600,  questHub = "Auberdine Loop",                mobs = "Murlocs, Bears, Satyrs",           soloSafe = 0.98 },
	{ id = "redridge",   zone = "Redridge Mountains",  minL = 15, maxL = 25, x = 29.8, y = 44.3, cont = 1, baseXpHr = 16900, baseGoldHr = 5400,  questHub = "Lakeshire",                     mobs = "Blackrock Orcs, Gnolls",           soloSafe = 0.84 },
	{ id = "duskwood",   zone = "Duskwood",            minL = 18, maxL = 30, x = 73.8, y = 44.2, cont = 1, baseXpHr = 19800, baseGoldHr = 7800,  questHub = "Darkshire & Raven Hill",        mobs = "Undead, Worgen, Spiders",          soloSafe = 0.88 },
	{ id = "hillsbrad",  zone = "Hillsbrad Foothills", minL = 20, maxL = 32, x = 62.4, y = 19.8, cont = 1, baseXpHr = 21600, baseGoldHr = 9200,  questHub = "Tarren Mill / Southshore",      mobs = "Yetis, Syndicate, Nagas",          soloSafe = 0.80 },
	{ id = "ashenvale",  zone = "Ashenvale",           minL = 18, maxL = 30, x = 36.6, y = 49.6, cont = 2, baseXpHr = 19200, baseGoldHr = 8100,  questHub = "Astranaar / Splintertree",      mobs = "Furbolgs, Satyrs, Elementals",     soloSafe = 0.85 },
	{ id = "shimmering", zone = "Thousand Needles",    minL = 25, maxL = 35, x = 78.1, y = 77.1, cont = 2, baseXpHr = 24800, baseGoldHr = 11400, questHub = "Mirage Raceway (Shimmering Flats)", mobs = "Silithid, Basilisks, Turtles", soloSafe = 0.96 },
	{ id = "stv",        zone = "Stranglethorn Vale",  minL = 30, maxL = 45, x = 35.6, y = 10.6, cont = 1, baseXpHr = 31200, baseGoldHr = 17500, questHub = "Nesingwary Camp & Booty Bay",   mobs = "Panthers, Raptors, Trolls, Pirates", soloSafe = 0.72 },
	{ id = "arathi",     zone = "Arathi Highlands",    minL = 30, maxL = 40, x = 45.8, y = 46.1, cont = 1, baseXpHr = 26400, baseGoldHr = 18900, questHub = "Refuge Pointe / Hammerfall",    mobs = "Elementals, Ogres, Raptors",       soloSafe = 0.88 },
	{ id = "desolace",   zone = "Desolace",            minL = 30, maxL = 40, x = 56.2, y = 59.4, cont = 2, baseXpHr = 25900, baseGoldHr = 15200, questHub = "Nijel's / Shadowprey",          mobs = "Centaurs, Demons, Nagas",          soloSafe = 0.94 },
	{ id = "badlands",   zone = "Badlands",            minL = 35, maxL = 45, x = 25.9, y = 44.8, cont = 1, baseXpHr = 29800, baseGoldHr = 26500, questHub = "Kargath & Dustbowl",            mobs = "Rock Elementals, Whelps, Ogres",   soloSafe = 0.92 },
	{ id = "tanaris",    zone = "Tanaris",             minL = 40, maxL = 50, x = 51.5, y = 28.6, cont = 2, baseXpHr = 35600, baseGoldHr = 28400, questHub = "Gadgetzan & Steamwheedle",      mobs = "Wastewander, Pirates, Ogres",      soloSafe = 0.93 },
	{ id = "feralas",    zone = "Feralas",             minL = 40, maxL = 50, x = 30.2, y = 43.2, cont = 2, baseXpHr = 34400, baseGoldHr = 25800, questHub = "Feathermoon / Camp Mojache",    mobs = "Yetis, Gnolls, Hippogryphs",       soloSafe = 0.95 },
	{ id = "hinterlands",zone = "The Hinterlands",     minL = 42, maxL = 50, x = 14.3, y = 44.7, cont = 1, baseXpHr = 36200, baseGoldHr = 27200, questHub = "Aerie Peak / Revantusk",        mobs = "Trolls, Wolves, Owlbeasts",        soloSafe = 0.91 },
	{ id = "searing",    zone = "Searing Gorge",       minL = 45, maxL = 52, x = 38.6, y = 28.2, cont = 1, baseXpHr = 39800, baseGoldHr = 34200, questHub = "Thorium Point",                 mobs = "Dark Iron Dwarves, Elementals",    soloSafe = 0.89 },
	{ id = "ungoro",     zone = "Un'Goro Crater",      minL = 48, maxL = 55, x = 43.6, y = 8.4,  cont = 2, baseXpHr = 44600, baseGoldHr = 39800, questHub = "Marshal's Refuge",              mobs = "Devilsaurs, Gorillas, Oozes",      soloSafe = 0.90 },
	{ id = "felwood",    zone = "Felwood",             minL = 48, maxL = 55, x = 51.3, y = 82.1, cont = 2, baseXpHr = 43200, baseGoldHr = 44500, questHub = "Emerald Sanctuary & Bloodvenom",mobs = "Satyrs, Timbermaw, Elementals",    soloSafe = 0.88 },
	{ id = "wpl",        zone = "Western Plaguelands", minL = 51, maxL = 58, x = 42.9, y = 84.5, cont = 1, baseXpHr = 49800, baseGoldHr = 46800, questHub = "Chillwind / Bulwark Cauldrons", mobs = "Scourge, Scarlet Crusade",         soloSafe = 0.87 },
	{ id = "epl",        zone = "Eastern Plaguelands", minL = 53, maxL = 60, x = 81.5, y = 59.3, cont = 1, baseXpHr = 53200, baseGoldHr = 58500, questHub = "Light's Hope Chapel",           mobs = "Scourge, Scarlet, Plaguehounds",   soloSafe = 0.82 },
	{ id = "winterspring",zone = "Winterspring",       minL = 54, maxL = 60, x = 61.2, y = 38.4, cont = 2, baseXpHr = 51800, baseGoldHr = 61000, questHub = "Everlook",                      mobs = "Frostsabers, Furbolgs, Yetis",     soloSafe = 0.89 },
	{ id = "silithus",   zone = "Silithus",            minL = 55, maxL = 60, x = 51.8, y = 39.2, cont = 2, baseXpHr = 50500, baseGoldHr = 64000, questHub = "Cenarion Hold",                 mobs = "Twilight Cultists, Silithid",      soloSafe = 0.80 },
}

local FARM_SPOTS = {
	{ id = "fel_herb",   zone = "Felwood",              x = 42.4, y = 44.2, cat = "Herbalism",  title = "Plaguebloom & Gromsblood Circuit",   items = { { id = 13466, rate = 14 }, { id = 8846, rate = 18 }, { id = 13463, rate = 10 } }, baseGoldHr = 380000, level = 52 },
	{ id = "epl_herb",   zone = "Eastern Plaguelands",  x = 58.2, y = 36.4, cat = "Herbalism",  title = "Plaguebloom & Black Lotus Loop",     items = { { id = 13466, rate = 18 }, { id = 13468, rate = 1 },  { id = 13464, rate = 12 } }, baseGoldHr = 520000, level = 58 },
	{ id = "azsh_herb",  zone = "Azshara",              x = 54.6, y = 50.8, cat = "Herbalism",  title = "Dreamfoil & Mountain Silversage",    items = { { id = 13463, rate = 22 }, { id = 13465, rate = 16 }, { id = 13464, rate = 10 } }, baseGoldHr = 440000, level = 50 },
	{ id = "stv_herb",   zone = "Stranglethorn Vale",   x = 34.5, y = 38.2, cat = "Herbalism",  title = "Fadeleaf, Goldthorn & Wild Steelbloom", items = { { id = 3818, rate = 24 }, { id = 3821, rate = 18 }, { id = 3355, rate = 16 } }, baseGoldHr = 210000, level = 35 },
	{ id = "epl_mine",   zone = "Eastern Plaguelands",  x = 46.8, y = 29.4, cat = "Mining",     title = "Rich Thorium & Arcane Crystal Run",  items = { { id = 10620, rate = 34 }, { id = 12363, rate = 2 },  { id = 12365, rate = 22 } }, baseGoldHr = 560000, level = 58 },
	{ id = "ung_mine",   zone = "Un'Goro Crater",       x = 64.2, y = 38.5, cat = "Mining",     title = "Perimeter Rich Thorium Loop",        items = { { id = 10620, rate = 38 }, { id = 12363, rate = 2 },  { id = 12365, rate = 24 } }, baseGoldHr = 510000, level = 52 },
	{ id = "bad_mine",   zone = "Badlands",             x = 52.4, y = 36.0, cat = "Mining",     title = "Mithril & Solid Stone + Elemental Earth", items = { { id = 3858, rate = 36 }, { id = 7912, rate = 28 }, { id = 7067, rate = 9 } }, baseGoldHr = 310000, level = 42 },
	{ id = "arathi_mine",zone = "Arathi Highlands",     x = 56.0, y = 62.4, cat = "Mining",     title = "Iron, Mithril & Elemental Fire",     items = { { id = 2772, rate = 30 }, { id = 3858, rate = 18 }, { id = 7068, rate = 8 } }, baseGoldHr = 280000, level = 38 },
	{ id = "ung_skin",   zone = "Un'Goro Crater",       x = 50.4, y = 62.0, cat = "Skinning",   title = "Devilsaur & Rugged Leather Hunt",    items = { { id = 15417, rate = 5 }, { id = 8170, rate = 38 }, { id = 8171, rate = 4 } }, baseGoldHr = 490000, level = 55 },
	{ id = "ws_skin",    zone = "Winterspring",         x = 66.2, y = 44.5, cat = "Skinning",   title = "Yeti Cave Rugged Leather & Frostmaul", items = { { id = 8170, rate = 44 }, { id = 8171, rate = 5 }, { id = 14047, rate = 24 } }, baseGoldHr = 370000, level = 58 },
	{ id = "fer_skin",   zone = "Feralas",              x = 53.0, y = 55.6, cat = "Skinning",   title = "Thick Leather & Rugged Hide Cave",   items = { { id = 4304, rate = 48 }, { id = 8169, rate = 5 } }, baseGoldHr = 260000, level = 46 },
	{ id = "wpl_cloth",  zone = "Western Plaguelands",  x = 46.0, y = 17.8, cat = "Cloth & Elementals", title = "Hearthglen Runecloth & Righteous Orbs", items = { { id = 14047, rate = 58 }, { id = 12811, rate = 1 }, { id = 14344, rate = 2 } }, baseGoldHr = 470000, level = 57 },
	{ id = "fel_elem",   zone = "Felwood",              x = 40.5, y = 19.6, cat = "Cloth & Elementals", title = "Jaedenar & Irontree Essence of Water / Felcloth", items = { { id = 7080, rate = 6 }, { id = 14256, rate = 9 }, { id = 14047, rate = 34 } }, baseGoldHr = 460000, level = 54 },
	{ id = "sil_elem",   zone = "Silithus",             x = 24.4, y = 17.8, cat = "Cloth & Elementals", title = "NW Elemental Essence of Air / Earth", items = { { id = 7082, rate = 6 }, { id = 7076, rate = 5 }, { id = 7067, rate = 12 } }, baseGoldHr = 530000, level = 58 },
	{ id = "tan_cloth",  zone = "Tanaris",              x = 68.4, y = 41.2, cat = "Cloth & Elementals", title = "Southsea Pirates Mageweave & Lockboxes", items = { { id = 4338, rate = 62 }, { id = 4306, rate = 20 } }, baseGoldHr = 240000, level = 44 },
	{ id = "azsh_fish",  zone = "Azshara",              x = 68.5, y = 62.2, cat = "Fishing",    title = "Bay of Storms Stonescale Eel & Essence of Water", items = { { id = 13422, rate = 26 }, { id = 7080, rate = 4 }, { id = 13759, rate = 18 } }, baseGoldHr = 410000, level = 54 },
}

-- ============================================================================
-- PERSISTENT STORAGE & ANTI-LAG GUARD
-- ============================================================================
function PluribusHiveCompute:GetComputeDB()
	local db = PluribusHive:GetDB()
	db.compute = db.compute or {
		telemetry = {},      -- [zone] = { xpSamples, xpHrAvg, goldHrAvg, items = { [id]=count }, updatedAt }
		cachedGuides = {},   -- [fullKey] = { kind, param, priority, createdAt, refinedAt, refinementPass, savedTravelSec, workers = {}, steps = {} }
		stats = { totalRefinements = 0, totalTravelSavedSec = 0 },
	}
	db.compute.telemetry = db.compute.telemetry or {}
	db.compute.cachedGuides = db.compute.cachedGuides or {}
	db.compute.stats = db.compute.stats or { totalRefinements = 0, totalTravelSavedSec = 0 }
	return db.compute
end

function PluribusHiveCompute:MakeGuideCacheKey(kind, param, priority)
	kind = tostring(kind or "LEVELING")
	param = tostring(param or (kind == "LEVELING" and "AUTO" or "GUILD_NEEDS"))
	priority = tostring(priority or (kind == "LEVELING" and "BALANCED" or "GOLD"))
	return kind .. ":" .. param .. ":" .. priority
end

function PluribusHiveCompute:GetCachedGuide(kind, param, priority)
	local cdb = self:GetComputeDB()
	local fullKey = self:MakeGuideCacheKey(kind, param, priority)
	if cdb.cachedGuides[fullKey] and cdb.cachedGuides[fullKey].steps and #cdb.cachedGuides[fullKey].steps > 0 then
		return cdb.cachedGuides[fullKey], fullKey
	end
	if cdb.cachedGuides[kind] and cdb.cachedGuides[kind].steps and #cdb.cachedGuides[kind].steps > 0 then
		return cdb.cachedGuides[kind], kind
	end
	return nil, fullKey
end

function PluribusHiveCompute:GetRouteCacheSummary()
	local cdb = self:GetComputeDB()
	local guideCount = 0
	for k, g in pairs(cdb.cachedGuides or {}) do
		if k:find(":", 1, true) and g and g.steps and #g.steps > 0 then
			guideCount = guideCount + 1
		end
	end
	local pfStats = (_G.PluribusHivePathfinder and _G.PluribusHivePathfinder.GetCacheStats)
		and _G.PluribusHivePathfinder:GetCacheStats() or { cachedRoutes = 0, totalImprovements = 0, observedEdges = 0 }
	return {
		cachedGuides = guideCount,
		cachedPaths = pfStats.cachedRoutes or 0,
		refinements = (cdb.stats and cdb.stats.totalRefinements or 0) + (pfStats.totalImprovements or 0),
		savedTravelSec = cdb.stats and cdb.stats.totalTravelSavedSec or 0,
		observedEdges = pfStats.observedEdges or 0,
	}
end

function PluribusHiveCompute:GetBudgetConfig()
	local cfg = PluribusHive:GetConfig()
	return {
		enabled = cfg.computeEnabled ~= false,
		budgetMs = tonumber(cfg.computeBudgetMs) or 1.5,
		minFps = tonumber(cfg.computeMinFps) or 45,
		pauseInInstances = cfg.computePauseInInstances ~= false,
		idleOnly = cfg.computeIdleOnly == true,
	}
end

-- Strict safety check before running ANY compute slice — guarantees zero lag!
function PluribusHiveCompute:CanRunComputeSlice()
	local b = self:GetBudgetConfig()
	if not b.enabled then
		self.workerStatus = "OPTED_OUT"
		return false, "OPTED_OUT"
	end
	if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
		self.workerStatus = "PAUSED_COMBAT"
		return false, "PAUSED_COMBAT"
	end
	if b.pauseInInstances and IsInInstance then
		local inInst = IsInInstance()
		if inInst then
			self.workerStatus = "PAUSED_INSTANCE"
			return false, "PAUSED_INSTANCE"
		end
	end
	if GetFramerate then
		local fps = GetFramerate() or 0
		if fps > 0 and fps < b.minFps then
			self.workerStatus = "PAUSED_FPS"
			return false, "PAUSED_FPS"
		end
	end
	if b.idleOnly and GetUnitSpeed then
		local spd = GetUnitSpeed("player") or 0
		if spd > 0.1 then
			self.workerStatus = "PAUSED_MOVING"
			return false, "PAUSED_MOVING"
		end
	end
	return true, "READY"
end

function PluribusHiveCompute:GetStatusLabel()
	local st = self.workerStatus
	if st == "COMPUTING" then return "|cff38bdf8Computing Shard|r"
	elseif st == "PAUSED_COMBAT" then return "|cfff87171Paused (In Combat)|r"
	elseif st == "PAUSED_INSTANCE" then return "|cfffbbf24Paused (Instance)|r"
	elseif st == "PAUSED_FPS" then return "|cfffbbf24Paused (FPS Guard)|r"
	elseif st == "PAUSED_MOVING" then return "|cff94a3b8Paused (Moving)|r"
	elseif st == "OPTED_OUT" then return "|cff94a3b8Opted Out|r"
	else return "|cff4ade80Idle Ready|r" end
end

-- ============================================================================
-- PASSIVE WORLD RESOURCE TELEMETRY (Gathers real guild XP/Gold/Loot yields)
-- ============================================================================
function PluribusHiveCompute:FlushZoneSession()
	local zs = self.zoneSession
	if not zs or not zs.zone or zs.enteredAt == 0 then return end
	local elapsedSec = math.max(1, time() - zs.enteredAt)
	if elapsedSec < 60 or (zs.xp == 0 and zs.copper == 0 and next(zs.items) == nil) then return end

	local cdb = self:GetComputeDB()
	local zRec = cdb.telemetry[zs.zone] or { samples = 0, xpHr = 0, goldHr = 0, items = {}, updatedAt = 0 }
	local hrs = elapsedSec / 3600
	local sampleXpHr = math.floor(zs.xp / hrs)
	local sampleGoldHr = math.floor(zs.copper / hrs)
	local n = math.min(20, zRec.samples or 0)
	if sampleXpHr > 0 then
		zRec.xpHr = math.floor(((zRec.xpHr * n) + sampleXpHr) / (n + 1))
	end
	if sampleGoldHr > 0 then
		zRec.goldHr = math.floor(((zRec.goldHr * n) + sampleGoldHr) / (n + 1))
	end
	for itemID, cnt in pairs(zs.items) do
		zRec.items[itemID] = math.min(9999, (zRec.items[itemID] or 0) + cnt)
	end
	zRec.samples = (zRec.samples or 0) + 1
	zRec.updatedAt = time()
	cdb.telemetry[zs.zone] = zRec

	-- Trickle compact telemetry delta to guild in background
	if PluribusHive:GetConfig().shareWorldEvents ~= false and PluribusHive:CanSendChannel("GUILD") then
		local itemParts = {}
		local c = 0
		for id, cnt in pairs(zs.items) do
			table.insert(itemParts, id .. ":" .. cnt)
			c = c + 1
			if c >= 6 then break end
		end
		local payload = string.format("%s|%d|%d|%s", zs.zone:gsub("|", " "), zRec.xpHr, zRec.goldHr, table.concat(itemParts, ","))
		PluribusHive:SendBackground("TELEM", payload, "TELEM:" .. zs.zone, "GUILD")
	end

	zs.enteredAt = time()
	zs.xp = 0
	zs.copper = 0
	zs.items = {}
end

-- ============================================================================
-- DISTRIBUTED WORKER LIST & DETERMINISTIC SHARDING
-- ============================================================================
function PluribusHiveCompute:GetEligibleWorkers()
	local workers = {}
	local me = PluribusHive:GetPlayerShortName()
	local now = time()
	if self:GetBudgetConfig().enabled then
		table.insert(workers, me)
	end
	for _, m in ipairs(PluribusHive:GetOnlineMembers()) do
		if not m.isSelf and m.name and m.name ~= "" then
			local cap = self.peerCapabilities[m.name]
			if not cap or cap.enabled ~= false then
				table.insert(workers, m.name)
			end
		end
	end
	if #workers == 0 then
		table.insert(workers, me) -- Always allow explicit local compute when user clicks Compute
	end
	table.sort(workers)
	return workers
end

function PluribusHiveCompute:GetItemValueCopper(itemID)
	if _G.PluribusHiveAuction and _G.PluribusHiveAuction.GetPrice then
		local p = _G.PluribusHiveAuction:GetPrice(itemID)
		if p and ((p.copper and p.copper > 0) or (p.buyout and p.buyout > 0)) then
			return p.copper or p.buyout
		end
	end
	local db = PluribusHive:GetDB()
	local pr = db.prices and db.prices[itemID]
	if pr and ((pr.copper and pr.copper > 0) or (pr.buyout and pr.buyout > 0)) then
		return pr.copper or pr.buyout
	end
	local FALLBACK = {
		[13468] = 650000, [12363] = 550000, [12811] = 350000, [15417] = 180000,
		[7080] = 160000,  [7082] = 180000,  [7076] = 85000,   [13466] = 28000,
		[13463] = 18000,  [13465] = 22000,  [13464] = 12000,  [8846] = 14000,
		[10620] = 9500,   [12365] = 4500,   [8170] = 6500,    [14047] = 3200,
		[14256] = 26000,  [13422] = 18000,  [7067] = 35000,   [7068] = 42000,
		[3858] = 5500,    [7912] = 4200,    [4338] = 2100,    [4304] = 3600,
		[3818] = 7500,    [3821] = 6200,    [3355] = 4800,    [2772] = 3200,
	}
	return FALLBACK[itemID] or 4500
end

-- Classic 1.60.1 per-item farm route knowledge base (used inline inside the To-Do List!)
local ITEM_FARM_ROUTES = {
	-- Herbs
	[765]   = { zone = "Elwynn Forest",       x = 48.0, y = 52.0, source = "Silverleaf / Silberblatt",     yieldHr = 40 },
	[2447]  = { zone = "Elwynn Forest",       x = 42.5, y = 64.0, source = "Peacebloom / Friedensblume",   yieldHr = 45 },
	[2449]  = { zone = "The Barrens",         x = 46.2, y = 38.4, source = "Earthroot / Erdwurzel",        yieldHr = 28 },
	[785]   = { zone = "Loch Modan",          x = 44.0, y = 56.0, source = "Mageroyal / Maguskönigskraut", yieldHr = 30 },
	[2450]  = { zone = "Hillsbrad Foothills", x = 52.0, y = 44.0, source = "Briarthorn / Wilddornrose",    yieldHr = 32 },
	[2453]  = { zone = "Redridge Mountains",  x = 34.0, y = 48.0, source = "Bruiseweed / Beulengras",      yieldHr = 28 },
	[3355]  = { zone = "Stranglethorn Vale",  x = 35.0, y = 26.0, source = "Wild Steelbloom",              yieldHr = 24 },
	[3356]  = { zone = "Swamp of Sorrows",    x = 46.0, y = 48.0, source = "Kingsblood / Königsblut",      yieldHr = 30 },
	[3357]  = { zone = "Swamp of Sorrows",    x = 62.0, y = 38.0, source = "Liferoot / Lebenswurz",        yieldHr = 26 },
	[3818]  = { zone = "Swamp of Sorrows",    x = 54.0, y = 52.0, source = "Fadeleaf / Blassblatt",        yieldHr = 24 },
	[3820]  = { zone = "Stranglethorn Vale",  x = 26.0, y = 44.0, source = "Stranglekelp (Water/Küste)",   yieldHr = 34 },
	[3821]  = { zone = "Arathi Highlands",    x = 46.0, y = 58.0, source = "Goldthorn / Golddorn",         yieldHr = 26 },
	[8831]  = { zone = "Hinterlands",         x = 52.0, y = 46.0, source = "Purple Lotus / Lila Lotus",    yieldHr = 18 },
	[8838]  = { zone = "Feralas",             x = 56.0, y = 54.0, source = "Sungrass / Sonnengras",        yieldHr = 28 },
	[8846]  = { zone = "Felwood",             x = 42.4, y = 44.2, source = "Gromsblood / Gromsblut",       yieldHr = 22 },
	[13463] = { zone = "Azshara",             x = 54.6, y = 50.8, source = "Dreamfoil / Traumblatt",       yieldHr = 24 },
	[13464] = { zone = "Azshara",             x = 46.0, y = 56.0, source = "Golden Sansam",                yieldHr = 26 },
	[13465] = { zone = "Winterspring",        x = 56.0, y = 44.0, source = "Mountain Silversage",          yieldHr = 20 },
	[13466] = { zone = "Eastern Plaguelands", x = 58.2, y = 36.4, source = "Plaguebloom / Pestblüte",      yieldHr = 20 },
	[13467] = { zone = "Winterspring",        x = 64.0, y = 52.0, source = "Icecap / Eiskappe",            yieldHr = 22 },
	[13468] = { zone = "Eastern Plaguelands", x = 58.2, y = 36.4, source = "Black Lotus / Schwarzer Lotus",yieldHr = 1 },
	-- Ores, Bars & Stones
	[2770]  = { zone = "Durotar",             x = 48.0, y = 36.0, source = "Copper Vein / Kupferader",     yieldHr = 48 },
	[2840]  = { zone = "Elwynn Forest",       x = 62.0, y = 50.0, source = "Copper Vein -> Smelt",         yieldHr = 48 },
	[2771]  = { zone = "Redridge Mountains",  x = 42.0, y = 36.0, source = "Tin Vein / Zinnader",          yieldHr = 38 },
	[2841]  = { zone = "Hillsbrad Foothills", x = 54.0, y = 36.0, source = "Tin + Copper -> Bronze",       yieldHr = 34 },
	[2772]  = { zone = "Arathi Highlands",    x = 56.0, y = 62.4, source = "Iron Deposit / Eisenvorkommen",yieldHr = 36 },
	[3575]  = { zone = "Arathi Highlands",    x = 56.0, y = 62.4, source = "Iron Deposit -> Smelt",        yieldHr = 36 },
	[3858]  = { zone = "Badlands",            x = 52.4, y = 36.0, source = "Mithril Deposit Perimeter",    yieldHr = 40 },
	[3860]  = { zone = "Badlands",            x = 52.4, y = 36.0, source = "Mithril Deposit -> Smelt",     yieldHr = 40 },
	[10620] = { zone = "Un'Goro Crater",      x = 64.2, y = 38.5, source = "Rich Thorium Loop",            yieldHr = 38 },
	[12359] = { zone = "Un'Goro Crater",      x = 64.2, y = 38.5, source = "Rich Thorium -> Smelt",        yieldHr = 38 },
	[12363] = { zone = "Eastern Plaguelands", x = 46.8, y = 29.4, source = "Rich Thorium -> Arcane Crystal",yieldHr = 2 },
	[12360] = { zone = "Eastern Plaguelands", x = 46.8, y = 29.4, source = "Rich Thorium + Transmute",     yieldHr = 2 },
	[12365] = { zone = "Un'Goro Crater",      x = 64.2, y = 38.5, source = "Thorium Veins (Dense Stone)",  yieldHr = 28 },
	[7912]  = { zone = "Badlands",            x = 52.4, y = 36.0, source = "Mithril Veins (Solid Stone)",  yieldHr = 30 },
	-- Cloth
	[2589]  = { zone = "Westfall",            x = 46.0, y = 66.0, source = "Defias Humanoids (Linen)",     yieldHr = 70 },
	[2592]  = { zone = "Hillsbrad Foothills", x = 62.0, y = 32.0, source = "Syndicate / Dun Garok (Wool)", yieldHr = 60 },
	[4306]  = { zone = "Scarlet Monastery",   x = 85.3, y = 32.2, source = "Scarlet Humanoids (Silk)",     yieldHr = 75 },
	[4338]  = { zone = "Tanaris",             x = 68.4, y = 41.2, source = "Southsea Pirates (Mageweave)", yieldHr = 64 },
	[14047] = { zone = "Western Plaguelands", x = 46.0, y = 17.8, source = "Hearthglen / Tyr's Hand (Rune)",yieldHr = 60 },
	[14256] = { zone = "Felwood",             x = 40.5, y = 19.6, source = "Jaedenar Satyrs (Felcloth)",   yieldHr = 10 },
	-- Leather & Scales
	[2318]  = { zone = "Westfall",            x = 48.0, y = 44.0, source = "Coyotes & Boars (Light)",      yieldHr = 55 },
	[2319]  = { zone = "Hillsbrad Foothills", x = 48.0, y = 38.0, source = "Yetis & Bears (Medium)",       yieldHr = 50 },
	[4234]  = { zone = "Stranglethorn Vale",  x = 34.0, y = 36.0, source = "Panthers & Raptors (Heavy)",   yieldHr = 48 },
	[4304]  = { zone = "Feralas",             x = 53.0, y = 55.6, source = "Yeti Cave (Thick Leather)",    yieldHr = 50 },
	[8170]  = { zone = "Winterspring",        x = 66.2, y = 44.5, source = "Yeti Cave (Rugged Leather)",   yieldHr = 46 },
	[15417] = { zone = "Un'Goro Crater",      x = 50.4, y = 62.0, source = "Devilsaurs (Loop)",            yieldHr = 5 },
	-- Elementals & Essences & Fish
	[7067]  = { zone = "Badlands",            x = 18.0, y = 42.0, source = "Rock Elementals (Earth)",      yieldHr = 12 },
	[7068]  = { zone = "Arathi Highlands",    x = 56.0, y = 62.4, source = "Burning Exile (Fire)",         yieldHr = 10 },
	[7076]  = { zone = "Silithus",            x = 24.4, y = 17.8, source = "NW Twilight/Earth Elementals", yieldHr = 6 },
	[7078]  = { zone = "Felwood",             x = 42.0, y = 24.0, source = "Searing/Fire Elementals",      yieldHr = 5 },
	[7080]  = { zone = "Felwood",             x = 40.5, y = 19.6, source = "Irontree Water Elementals",    yieldHr = 6 },
	[7082]  = { zone = "Silithus",            x = 24.4, y = 17.8, source = "Dust Stormers (Air)",          yieldHr = 6 },
	[12811] = { zone = "Eastern Plaguelands", x = 31.3, y = 15.7, source = "Stratholme Live (Orbs)",       yieldHr = 2 },
	[13422] = { zone = "Azshara",             x = 68.5, y = 62.2, source = "Bay of Storms (Stonescale)",   yieldHr = 28 },
	[13759] = { zone = "Feralas",             x = 45.0, y = 48.0, source = "Nightfin Snapper (Night)",     yieldHr = 24 },
}

function PluribusHiveCompute:GetFarmRouteForItem(itemID, itemName)
	itemID = tonumber(itemID)
	local cdb = self:GetComputeDB()
	local telemetry = cdb.telemetry or {}

	-- 1. Check live guild telemetry for observed zones dropping this exact item
	local bestTelemZone, bestTelemCount = nil, 0
	if itemID and itemID > 0 then
		for zName, tRec in pairs(telemetry) do
			local cnt = tRec.items and tRec.items[itemID] or 0
			if cnt > bestTelemCount then
				bestTelemCount = cnt
				bestTelemZone = zName
			end
		end
	end

	-- 2. Direct per-item Classic route database
	local direct = itemID and ITEM_FARM_ROUTES[itemID] or nil
	if direct then
		local goldHr = math.floor(self:GetItemValueCopper(itemID) * (direct.yieldHr or 10))
		return {
			zone = direct.zone,
			x = direct.x,
			y = direct.y,
			source = direct.source,
			yieldHr = direct.yieldHr,
			yieldText = string.format("~%d/h · ~%s/h", direct.yieldHr or 10, PluribusUtils:FormatGold(goldHr)),
			note = bestTelemZone and ("Guild Telemetry: " .. bestTelemZone) or string.format("~%d/h (%s)", direct.yieldHr or 10, direct.source),
		}
	end

	-- 3. Search multi-drop FARM_SPOTS
	if itemID and itemID > 0 then
		for _, spot in ipairs(FARM_SPOTS) do
			for _, drop in ipairs(spot.items or {}) do
				if drop.id == itemID then
					return {
						zone = spot.zone,
						x = spot.x,
						y = spot.y,
						source = spot.title,
						yieldHr = drop.rate,
						yieldText = string.format("~%d/h · %s", drop.rate or 10, spot.cat),
						note = spot.title,
					}
				end
			end
		end
	end

	-- 4. Guild telemetry fallback if observed in the world
	if bestTelemZone then
		for _, z in ipairs(LEVELING_ZONES) do
			if z.zone == bestTelemZone then
				return {
					zone = z.zone,
					x = z.x,
					y = z.y,
					source = "Guild Loot Telemetry (" .. bestTelemCount .. "x)",
					yieldHr = 10,
					note = z.mobs,
				}
			end
		end
	end

	-- 5. Fallback by player's current level bracket from auto-computed leveling guide
	local myLvl = UnitLevel and UnitLevel("player") or 30
	local bestZone = LEVELING_ZONES[1]
	for _, z in ipairs(LEVELING_ZONES) do
		if myLvl >= z.minL and myLvl <= z.maxL then
			bestZone = z
			break
		end
	end
	return {
		zone = bestZone.zone,
		x = bestZone.x,
		y = bestZone.y,
		source = bestZone.mobs or "Open World",
		yieldHr = 10,
		note = "Recommended zone for Lv " .. myLvl .. " (" .. tostring(itemName or "Mat") .. ")",
	}
end

-- Ordered catalog of ALL core guides pre-computed & cached automatically in the background (not waiting on user requests!)
local AUTO_COMPUTE_CATALOG = {
	{ kind = "LEVELING", param = "AUTO",               priority = "BALANCED" },
	{ kind = "FARMING",  param = "GUILD_NEEDS",        priority = "GOLD" },
	{ kind = "FARMING",  param = "BEST_GOLD",          priority = "GOLD" },
	{ kind = "LEVELING", param = "AUTO",               priority = "XP" },
	{ kind = "LEVELING", param = "AUTO",               priority = "SAFE" },
	{ kind = "FARMING",  param = "Herbalism",          priority = "GOLD" },
	{ kind = "FARMING",  param = "Mining",             priority = "GOLD" },
	{ kind = "FARMING",  param = "Skinning",           priority = "GOLD" },
	{ kind = "FARMING",  param = "Cloth & Elementals", priority = "GOLD" },
	{ kind = "FARMING",  param = "Fishing",            priority = "GOLD" },
	{ kind = "LEVELING", param = "1-15",               priority = "BALANCED" },
	{ kind = "LEVELING", param = "15-30",              priority = "BALANCED" },
	{ kind = "LEVELING", param = "30-45",              priority = "BALANCED" },
	{ kind = "LEVELING", param = "45-60",              priority = "BALANCED" },
	{ kind = "LEVELING", param = "1-60",               priority = "BALANCED" },
}

-- Estimate real travel seconds between two route steps using warm Pathfinder cache (fallback to continent/coord heuristic)
local function EstimateStepTravelSec(a, b)
	if not a or not b then return 0 end
	if a.zone == b.zone then
		local dx = (b.x or 50) - (a.x or 50)
		local dy = (b.y or 50) - (a.y or 50)
		return math.floor(math.sqrt(dx * dx + dy * dy) * 3.5)
	end
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.ComputeRoute then
		local ok, r = pcall(function()
			return _G.PluribusHivePathfinder:ComputeRoute(a.zone, a.x or 50, a.y or 50, b.zone, b.x or 50, b.y or 50, { noStore = false })
		end)
		if ok and r and r.totalEtaSec then
			return r.totalEtaSec
		end
	end
	return 180
end

local function ComputeTourTravelSec(steps)
	local total = 0
	for i = 1, (#steps - 1) do
		total = total + EstimateStepTravelSec(steps[i], steps[i + 1])
	end
	return total
end

-- Continuous 2-Opt & live-economy refinement pass on a cached guide (runs silently in idle background!)
function PluribusHiveCompute:RefineCachedGuide(cacheKey)
	local cdb = self:GetComputeDB()
	local guide = cdb.cachedGuides[cacheKey]
	if not guide or not guide.steps or #guide.steps < 2 then return false, 0 end

	local steps = guide.steps
	local improved = false
	local savedSec = 0

	-- Step 1: Re-score with freshest AH prices, To-Do demand & guild telemetry
	local telemetry = cdb.telemetry or {}
	local demand = self:GetGuildDemandMap()
	if guide.kind == "FARMING" then
		for _, st in ipairs(steps) do
			local spotDef = nil
			for _, sp in ipairs(FARM_SPOTS) do
				if sp.id == st.id then spotDef = sp break end
			end
			if spotDef then
				local t = telemetry[spotDef.zone]
				local ahGoldHr = 0
				local demandScore = 0
				for _, drop in ipairs(spotDef.items) do
					local price = self:GetItemValueCopper(drop.id)
					local boost = (t and t.items and t.items[drop.id]) and 1.15 or 1.0
					ahGoldHr = ahGoldHr + math.floor(price * drop.rate * boost)
					demandScore = demandScore + (demand[drop.id] or 0) * 120000
				end
				local newGold = math.max(spotDef.baseGoldHr, ahGoldHr)
				local newScore = (guide.param == "GUILD_NEEDS") and (newGold + demandScore * 3) or newGold
				if math.abs((st.goldHr or 0) - newGold) >= 5000 or math.abs((st.score or 0) - newScore) >= 10000 then
					st.goldHr = math.floor(newGold)
					st.score = math.floor(newScore)
					st.demandHits = math.floor(demandScore / 120000)
					st.calibrated = (t and (t.samples or 0) > 0) and true or false
					improved = true
				end
			end
		end
	else
		for _, st in ipairs(steps) do
			local t = telemetry[st.zone]
			if t and (t.samples or 0) > 0 and not st.calibrated then
				st.calibrated = true
				if t.xpHr and t.xpHr > 0 then
					st.xpHr = math.floor((st.xpHr or t.xpHr) * 0.6 + t.xpHr * 0.4)
				end
				if t.goldHr and t.goldHr > 0 then
					st.goldHr = math.floor((st.goldHr or t.goldHr) * 0.6 + t.goldHr * 0.4)
				end
				improved = true
			end
		end
	end

	-- Step 2: 2-Opt / adjacent travel-time optimization pass (eliminates unnecessary continent ping-pong!)
	local beforeTravel = ComputeTourTravelSec(steps)
	local n = math.min(#steps, 10)
	local bestGain = 0
	local bestI, bestJ = nil, nil

	for i = 1, n - 1 do
		for j = i + 1, n do
			-- For LEVELING guides, preserve monotonic level progression (only swap overlapping level brackets!)
			local legalSwap = true
			if guide.kind == "LEVELING" then
				local a, b = steps[i], steps[j]
				if math.abs((a.minL or 1) - (b.minL or 1)) > 5 then
					legalSwap = false
				end
			else
				-- For FARMING guides, only swap stops with comparable value (within 25%) so #1 hotspot stays near top
				local sa, sb = math.max(1, steps[i].score or 1), math.max(1, steps[j].score or 1)
				if math.abs(sa - sb) / math.max(sa, sb) > 0.25 then
					legalSwap = false
				end
			end

			if legalSwap then
				steps[i], steps[j] = steps[j], steps[i]
				local candTravel = ComputeTourTravelSec(steps)
				local gain = beforeTravel - candTravel
				if gain > bestGain + 8 then
					bestGain = gain
					bestI, bestJ = i, j
				end
				-- Revert test swap
				steps[i], steps[j] = steps[j], steps[i]
			end
		end
	end

	if bestI and bestJ and bestGain > 8 then
		steps[bestI], steps[bestJ] = steps[bestJ], steps[bestI]
		savedSec = math.floor(bestGain)
		improved = true
	end

	guide.refinementPass = (guide.refinementPass or 1) + 1
	guide.refinedAt = time()
	guide.totalTravelSec = ComputeTourTravelSec(steps)
	if savedSec > 0 then
		guide.savedTravelSec = (guide.savedTravelSec or 0) + savedSec
		cdb.stats.totalTravelSavedSec = (cdb.stats.totalTravelSavedSec or 0) + savedSec
	end
	if improved then
		cdb.stats.totalRefinements = (cdb.stats.totalRefinements or 0) + 1
		if _G.PluribusMessaging then
			pcall(function() _G.PluribusMessaging:Publish("HIVE_COMPUTE_DONE", guide.kind) end)
		end
	end

	return improved, savedSec
end

-- Auto-calculate & continuously pre-warm ALL core guides quietly in background (zero lag!)
function PluribusHiveCompute:AutoCalculateGuidesIfStale(forceKind, forceParam, forcePriority)
	local cdb = self:GetComputeDB()
	local now = time()
	local STALE_SEC = 900 -- 15 minutes full re-shard freshness
	if self.activeJob and not self.activeJob.done then return end

	if forceKind then
		local p = forceParam or (forceKind == "LEVELING" and (self.selectedBracket or "AUTO") or (self.selectedFarmTarget or "GUILD_NEEDS"))
		local pr = forcePriority or (forceKind == "LEVELING" and (self.selectedPriority or "BALANCED") or "GOLD")
		self:StartJob(forceKind, p, pr, nil, nil, nil, true)
		return
	end

	-- Walk the full catalog and immediately compute any missing or stale route (starting from highest-priority user routes!)
	for i = 1, #AUTO_COMPUTE_CATALOG do
		local idx = ((self.catalogCursor - 1 + i - 1) % #AUTO_COMPUTE_CATALOG) + 1
		local entry = AUTO_COMPUTE_CATALOG[idx]
		local fullKey = self:MakeGuideCacheKey(entry.kind, entry.param, entry.priority)
		local cached = cdb.cachedGuides[fullKey]
		if not cached or not cached.steps or #cached.steps == 0 or (now - (cached.createdAt or 0)) > STALE_SEC then
			self.catalogCursor = (idx % #AUTO_COMPUTE_CATALOG) + 1
			self:StartJob(entry.kind, entry.param, entry.priority, nil, nil, nil, true)
			return
		end
	end
end

-- Continuously improves already-cached guides one by one whenever the worker is idle!
function PluribusHiveCompute:RunIdleRefinementTick()
	if self.activeJob and not self.activeJob.done then return end
	local canRun = self:CanRunComputeSlice()
	if not canRun then return end

	local cdb = self:GetComputeDB()
	local now = time()

	-- First check if any catalog route is still missing/stale and kick off background shard job
	for _, entry in ipairs(AUTO_COMPUTE_CATALOG) do
		local fullKey = self:MakeGuideCacheKey(entry.kind, entry.param, entry.priority)
		local cached = cdb.cachedGuides[fullKey]
		if not cached or not cached.steps or #cached.steps == 0 then
			self:StartJob(entry.kind, entry.param, entry.priority, nil, nil, nil, true)
			return
		end
	end

	-- All catalog routes exist -> continuously refine one cached guide every REFINE_INTERVAL seconds!
	if (now - (self.lastRefinementAt or 0)) < REFINE_INTERVAL then return end
	self.lastRefinementAt = now

	local keys = {}
	for k, g in pairs(cdb.cachedGuides or {}) do
		if k:find(":", 1, true) and g and g.steps and #g.steps >= 2 then
			table.insert(keys, k)
		end
	end
	if #keys == 0 then return end
	table.sort(keys)

	local idx = ((self.refinementCursor - 1) % #keys) + 1
	self.refinementCursor = (idx % #keys) + 1
	self:RefineCachedGuide(keys[idx])
end

function PluribusHiveCompute:GetGuildDemandMap()
	local demand = {}
	if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.GetAllGuildNeeds then
		local needs = _G.PluribusHiveProfessions:GetAllGuildNeeds() or {}
		for itemID, whoList in pairs(needs) do
			demand[tonumber(itemID) or 0] = #whoList
		end
	end
	local db = PluribusHive:GetDB()
	for idStr, entry in pairs(db.myNeededMats or {}) do
		local id = tonumber(idStr) or 0
		if id > 0 then
			local qty = type(entry) == "table" and (entry.qty or 1) or 1
			demand[id] = (demand[id] or 0) + math.max(1, math.ceil(qty / 5))
		end
	end
	return demand
end

-- ============================================================================
-- SHARD BUILDER & TIME-SLICED COROUTINE EVALUATOR (ZERO-LAG)
-- ============================================================================
local function BuildShardsForJob(kind, param, priority)
	local shards = {}
	if kind == "LEVELING" then
		local minL, maxL = 1, 60
		if param == "AUTO" then
			local cur = UnitLevel and UnitLevel("player") or 30
			minL = math.max(1, cur - 2)
			maxL = math.min(60, cur + 14)
		else
			local a, b = tostring(param):match("^(%d+)%-(%d+)$")
			minL = tonumber(a) or 1
			maxL = tonumber(b) or 60
		end
		local candidates = {}
		for _, z in ipairs(LEVELING_ZONES) do
			if z.maxL >= minL and z.minL <= maxL then
				table.insert(candidates, z)
			end
		end
		if #candidates == 0 then candidates = LEVELING_ZONES end
		-- Group into 4-6 lightweight shards so multiple guildmates can evaluate in parallel
		local shardSize = math.max(2, math.ceil(#candidates / 5))
		for i = 1, #candidates, shardSize do
			local batch = {}
			for j = i, math.min(#candidates, i + shardSize - 1) do
				table.insert(batch, candidates[j])
			end
			table.insert(shards, { idx = #shards + 1, items = batch, minL = minL, maxL = maxL, priority = priority })
		end
	else
		-- FARMING
		local candidates = {}
		for _, spot in ipairs(FARM_SPOTS) do
			if param == "GUILD_NEEDS" or param == "BEST_GOLD" or spot.cat == param then
				table.insert(candidates, spot)
			end
		end
		if #candidates == 0 then candidates = FARM_SPOTS end
		local shardSize = math.max(2, math.ceil(#candidates / 5))
		for i = 1, #candidates, shardSize do
			local batch = {}
			for j = i, math.min(#candidates, i + shardSize - 1) do
				table.insert(batch, candidates[j])
			end
			table.insert(shards, { idx = #shards + 1, items = batch, target = param })
		end
	end
	return shards
end

-- Coroutine worker that yields automatically whenever slice time hits budgetMs!
function PluribusHiveCompute:CreateShardCoroutine(job, shard)
	local telemetry = self:GetComputeDB().telemetry or {}
	local demand = self:GetGuildDemandMap()
	local myZone = GetRealZoneText and GetRealZoneText() or ""

	return coroutine.create(function()
		local results = {}
		local sliceStart = NowMs()
		local budgetMs = self:GetBudgetConfig().budgetMs

		local function MaybeYield()
			local spent = NowMs() - sliceStart
			if spent >= budgetMs then
				self.lastSliceMs = spent
				coroutine.yield("SLICE")
				sliceStart = NowMs()
				budgetMs = self:GetBudgetConfig().budgetMs
			end
		end

		if job.kind == "LEVELING" then
			local prio = shard.priority or "BALANCED"
			for _, z in ipairs(shard.items) do
				-- Merge live guild telemetry if observed
				local t = telemetry[z.zone]
				local xpHr = (t and t.xpHr and t.xpHr > 0) and math.floor(z.baseXpHr * 0.55 + t.xpHr * 0.45) or z.baseXpHr
				local goldHr = (t and t.goldHr and t.goldHr > 0) and math.floor(z.baseGoldHr * 0.55 + t.goldHr * 0.45) or z.baseGoldHr
				local guildBonus = (t and (t.samples or 0) > 0) and 1.08 or 1.0

				-- Multi-pass local route smoothing & travel cost estimation
				local travelPenalty = (z.zone == myZone) and 0 or (z.cont == 1 and 4 or 6)
				local overlap = math.max(1, math.min(z.maxL, shard.maxL) - math.max(z.minL, shard.minL) + 1)
				local score = 0
				for iter = 1, 8 do
					local wXp = (prio == "XP") and 1.35 or (prio == "SAFE" and 0.90 or 1.05)
					local wGold = (prio == "BALANCED") and 0.45 or 0.20
					local wSafe = (prio == "SAFE") and 1.50 or 0.65
					score = ((xpHr / 100) * wXp + (goldHr / 1000) * wGold) * (0.75 + 0.25 * z.soloSafe * wSafe) * guildBonus + overlap * 18 - travelPenalty * 6
					if iter % 4 == 0 then MaybeYield() end
				end

				table.insert(results, {
					id = z.id,
					zone = z.zone,
					x = z.x,
					y = z.y,
					minL = z.minL,
					maxL = z.maxL,
					xpHr = math.floor(xpHr),
					goldHr = math.floor(goldHr),
					detail = z.questHub .. " · " .. z.mobs,
					score = math.floor(score),
					calibrated = (t and (t.samples or 0) > 0) and true or false,
				})
				MaybeYield()
			end
		else
			-- MATERIAL FARMING optimization using live AH prices + Guild Wishlist demand + observed telemetry
			for _, spot in ipairs(shard.items) do
				local t = telemetry[spot.zone]
				local ahGoldHr = 0
				local demandScore = 0
				local primaryItemId = spot.items[1] and spot.items[1].id or 0
				local matParts = {}

				for _, drop in ipairs(spot.items) do
					local price = self:GetItemValueCopper(drop.id)
					local observedBoost = (t and t.items and t.items[drop.id]) and 1.15 or 1.0
					local rate = drop.rate * observedBoost
					ahGoldHr = ahGoldHr + math.floor(price * rate)
					local dem = demand[drop.id] or 0
					demandScore = demandScore + dem * 120000
					local iName = PluribusUtils:GetItemInfo(drop.id) or ("Item #" .. drop.id)
					table.insert(matParts, iName .. (dem > 0 and " [NEED]" or ""))
					MaybeYield()
				end

				local estGoldHr = math.max(spot.baseGoldHr, ahGoldHr)
				local score = estGoldHr
				if shard.target == "GUILD_NEEDS" then
					score = estGoldHr + demandScore * 3
				end
				if spot.zone == myZone then
					score = score * 1.08
				end

				table.insert(results, {
					id = spot.id,
					zone = spot.zone,
					x = spot.x,
					y = spot.y,
					cat = spot.cat,
					title = spot.title,
					primaryItemId = primaryItemId,
					goldHr = math.floor(estGoldHr),
					demandHits = math.floor(demandScore / 120000),
					detail = table.concat(matParts, ", "),
					score = math.floor(score),
					calibrated = (t and (t.samples or 0) > 0) and true or false,
				})
				MaybeYield()
			end
		end

		self.lastSliceMs = NowMs() - sliceStart
		return results
	end)
end

-- ============================================================================
-- JOB DISPATCH, RESULT MERGING & P2P COORDINATION
-- ============================================================================
local function EncodeShardResults(results)
	local parts = {}
	for _, r in ipairs(results or {}) do
		local detailClean = tostring(r.detail or ""):gsub("[|;^]", " "):sub(1, 56)
		local titleClean = tostring(r.title or r.zone or ""):gsub("[|;^]", " "):sub(1, 36)
		table.insert(parts, string.format("%s^%s^%.1f^%.1f^%d^%d^%d^%d^%d^%s^%s",
			tostring(r.id or ""),
			tostring(r.zone or ""):gsub("[|;^]", " "),
			tonumber(r.x) or 50,
			tonumber(r.y) or 50,
			tonumber(r.minL) or tonumber(r.primaryItemId) or 0,
			tonumber(r.maxL) or tonumber(r.demandHits) or 0,
			tonumber(r.xpHr) or 0,
			tonumber(r.goldHr) or 0,
			tonumber(r.score) or 0,
			titleClean,
			detailClean))
	end
	return table.concat(parts, ";")
end

local function DecodeShardResults(str, kind)
	local out = {}
	for entry in tostring(str or ""):gmatch("[^;]+") do
		local id, zone, xs, ys, a, b, xpHr, goldHr, score, title, detail =
			entry:match("^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^?(.*)$")
		if id and zone then
			local row = {
				id = id, zone = zone, x = tonumber(xs) or 50, y = tonumber(ys) or 50,
				xpHr = tonumber(xpHr) or 0, goldHr = tonumber(goldHr) or 0,
				score = tonumber(score) or 0, title = title, detail = detail,
			}
			if kind == "LEVELING" then
				row.minL = tonumber(a) or 1
				row.maxL = tonumber(b) or 60
			else
				row.primaryItemId = tonumber(a) or 0
				row.demandHits = tonumber(b) or 0
			end
			table.insert(out, row)
		end
	end
	return out
end

function PluribusHiveCompute:StartJob(kind, param, priority, fromPeer, remoteJobId, remoteWorkers, silent)
	kind = kind or "LEVELING"
	param = param or (kind == "LEVELING" and "AUTO" or "GUILD_NEEDS")
	priority = priority or (kind == "LEVELING" and "BALANCED" or "GOLD")

	local shards = BuildShardsForJob(kind, param, priority)
	local workers = (remoteWorkers and #remoteWorkers > 0) and remoteWorkers or self:GetEligibleWorkers()
	local jobId = remoteJobId or (PluribusHive:GetPlayerShortName():sub(1, 5) .. tostring(time() % 100000))
	local now = time()

	local shardStates = {}
	for i, s in ipairs(shards) do
		local assigned = workers[((i - 1) % #workers) + 1]
		shardStates[i] = {
			idx = i,
			data = s,
			assignedTo = assigned,
			status = "QUEUED", -- QUEUED | WORKING | DONE
			worker = assigned,
			ms = 0,
			results = nil,
			assignedAt = now,
		}
	end

	self.activeJob = {
		id = jobId,
		kind = kind,
		param = param,
		priority = priority,
		requester = fromPeer or PluribusHive:GetPlayerShortName(),
		startedAt = now,
		workers = workers,
		shards = shardStates,
		completedCount = 0,
		totalShards = #shardStates,
		done = false,
		silent = silent == true,
	}
	self.activeCoroutine = nil
	self.activeShardIdx = nil

	if not fromPeer then
		-- Broadcast job spec to guild so idle guildmates claim their assigned shards!
		local wList = table.concat(workers, ",")
		local body = string.format("%s|%s|%s|%s|%d|%s", jobId, kind, tostring(param), tostring(priority), #shardStates, wList)
		if silent and PluribusHive.SendBackground then
			PluribusHive:SendBackground("JOBREQ", body, "JOBREQ:" .. kind .. ":" .. tostring(param), "GUILD")
		else
			PluribusHive:Send("JOBREQ", body, "GUILD")
			PluribusHive:AddFeedEvent("COMPUTE", string.format("Started %s guide across %d worker(s) (%d shards)", kind == "LEVELING" and "Leveling" or "Farming", #workers, #shardStates))
		end
	end

	return self.activeJob
end

function PluribusHiveCompute:FinalizeJob(job)
	if not job or job.done then return end
	job.done = true
	self.workerStatus = "IDLE_READY"

	local merged = {}
	local workerCounts = {}
	for _, sh in ipairs(job.shards) do
		if sh.worker then
			workerCounts[sh.worker] = (workerCounts[sh.worker] or 0) + 1
		end
		for _, r in ipairs(sh.results or {}) do
			r.computedBy = sh.worker
			table.insert(merged, r)
		end
	end

	if job.kind == "LEVELING" then
		table.sort(merged, function(a, b)
			if (a.minL or 1) ~= (b.minL or 1) then return (a.minL or 1) < (b.minL or 1) end
			return (a.score or 0) > (b.score or 0)
		end)
	else
		table.sort(merged, function(a, b)
			return (a.score or 0) > (b.score or 0)
		end)
	end

	local cdb = self:GetComputeDB()
	local cacheKey = job.kind == "LEVELING" and "LEVELING" or "FARMING"
	local fullKey = self:MakeGuideCacheKey(job.kind, job.param, job.priority)
	local prev = cdb.cachedGuides[fullKey]
	local guideObj = {
		jobId = job.id,
		kind = job.kind,
		param = job.param,
		priority = job.priority,
		createdAt = time(),
		refinedAt = time(),
		refinementPass = (prev and prev.refinementPass or 0) + 1,
		savedTravelSec = prev and prev.savedTravelSec or 0,
		workers = workerCounts,
		totalShards = job.totalShards,
		steps = merged,
	}
	cdb.cachedGuides[fullKey] = guideObj
	-- Keep top-level alias updated when matching the active user selection or default
	if (job.kind == "LEVELING" and job.param == (self.selectedBracket or "AUTO"))
		or (job.kind == "FARMING" and job.param == (self.selectedFarmTarget or "GUILD_NEEDS"))
		or not cdb.cachedGuides[cacheKey] then
		cdb.cachedGuides[cacheKey] = guideObj
	end

	-- Immediately run first 2-Opt travel refinement pass on the newly built guide!
	pcall(function() self:RefineCachedGuide(fullKey) end)

	if not job.silent and _G.PluribusUIFramework and _G.PluribusUIFramework.ShowNotification then
		local wNames = {}
		for wn in pairs(workerCounts) do table.insert(wNames, wn) end
		_G.PluribusUIFramework:ShowNotification(
			string.format("|cff4ade80Hive %s Guide optimiert!|r (%d Stationen · %d Helfer)",
				job.kind == "LEVELING" and "Leveling" or "Farming", #merged, math.max(1, #wNames)),
			3.5)
	end
	if _G.PluribusMessaging then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_COMPUTE_DONE", cacheKey) end)
	end

	-- Immediately continue pre-computing the next uncached route in the background catalog!
	if C_Timer and C_Timer.After then
		C_Timer.After(2.0, function()
			PluribusHiveCompute:AutoCalculateGuidesIfStale()
		end)
	end
end

function PluribusHiveCompute:ApplyShardResult(jobId, shardIdx, workerName, msSpent, results)
	local job = self.activeJob
	if not job or job.id ~= jobId then return end
	local sh = job.shards[shardIdx]
	if not sh or sh.status == "DONE" then return end

	sh.status = "DONE"
	sh.worker = workerName
	sh.ms = tonumber(msSpent) or 0
	sh.results = results
	job.completedCount = (job.completedCount or 0) + 1

	if self.activeShardIdx == shardIdx then
		self.activeCoroutine = nil
		self.activeShardIdx = nil
	end

	if job.completedCount >= job.totalShards then
		self:FinalizeJob(job)
	end
end

function PluribusHiveCompute:PickNextLocalShard()
	local job = self.activeJob
	if not job or job.done then return nil end
	local me = PluribusHive:GetPlayerShortName()
	local now = time()

	-- Pass 1: Claim shards specifically assigned to me
	for _, sh in ipairs(job.shards) do
		if sh.status == "QUEUED" and PluribusHive:SamePlayer(sh.assignedTo, me) then
			return sh
		end
	end
	-- Pass 2: Work-stealing if another peer is in combat/low-FPS/offline past SHARD_STEAL_TIMEOUT
	for _, sh in ipairs(job.shards) do
		if sh.status ~= "DONE" and (now - (sh.assignedAt or job.startedAt)) >= SHARD_STEAL_TIMEOUT then
			sh.assignedTo = me
			sh.assignedAt = now
			return sh
		end
	end
	return nil
end

function PluribusHiveCompute:StepScheduler()
	local job = self.activeJob
	if not job or job.done then
		local ok = self:CanRunComputeSlice()
		if ok then
			self.workerStatus = "IDLE_READY"
			self:RunIdleRefinementTick()
		end
		return
	end

	local canRun = self:CanRunComputeSlice()
	if not canRun then
		-- Automatically pause without losing coroutine progress!
		return
	end

	if not self.activeCoroutine then
		local sh = self:PickNextLocalShard()
		if not sh then
			self.workerStatus = "IDLE_READY"
			return
		end
		sh.status = "WORKING"
		sh.worker = PluribusHive:GetPlayerShortName()
		self.activeShardIdx = sh.idx
		self.activeCoroutine = self:CreateShardCoroutine(job, sh)
		PluribusHive:Send("JOBCLAIM", string.format("%s|%d", job.id, sh.idx), "GUILD")
	end

	self.workerStatus = "COMPUTING"
	local ok, res = coroutine.resume(self.activeCoroutine)
	if not ok then
		-- Fail-safe cleanup
		self.activeCoroutine = nil
		self.activeShardIdx = nil
		self.workerStatus = "IDLE_READY"
		return
	end

	if coroutine.status(self.activeCoroutine) == "dead" then
		local finishedIdx = self.activeShardIdx
		local ms = math.floor((self.lastSliceMs or 0.5) * 10 + 0.5) / 10
		self.totalShardsComputed = (self.totalShardsComputed or 0) + 1
		self.activeCoroutine = nil
		self.activeShardIdx = nil
		self:ApplyShardResult(job.id, finishedIdx, PluribusHive:GetPlayerShortName(), ms, res or {})

		-- Share tiny compressed shard output with guild via background trickle queue
		local encoded = EncodeShardResults(res or {})
		PluribusHive:SendBackground("JOBRES",
			string.format("%s|%d|%.1f|%s", job.id, finishedIdx, ms, encoded),
			"JOBRES:" .. job.id .. ":" .. finishedIdx,
			"GUILD")
	end
end

-- ============================================================================
-- CLEAN, GRAPHICAL EMBEDDED UI FOR MAINFRAME ("Nav & Guides" -> "Hive Guides")
-- ============================================================================
function PluribusHiveCompute:RenderPanel(parent, width, height, onRefresh)
	local UI = _G.PluribusUIFramework
	if not UI or not parent then return end
	local w = width or 724
	local h = height or 410
	local b = self:GetBudgetConfig()
	local workers = self:GetEligibleWorkers()
	local job = self.activeJob

	-- Top Graphical Mesh Status & Live Auto-Cache Refinement Banner
	local cacheSum = self:GetRouteCacheSummary()
	local savedTxt = (cacheSum.savedTravelSec or 0) > 0 and string.format("  ·  |cff4ade80-%ds Reisezeit|r", cacheSum.savedTravelSec) or ""
	local statusLine = string.format("%s · Worker: |cff38bdf8%d|r · Cache: |cff4ade80%d Guides / %d Pfade|r · Optimierungen: |cfffbbf24%d|r%s",
		self:GetStatusLabel(), #workers, cacheSum.cachedGuides, cacheSum.cachedPaths, cacheSum.refinements, savedTxt)
	local banner = UI:CreateBannerCard(parent, w, 54, "Interface\\Icons\\Spell_Arcane_MindMastery",
		"|cff38bdf8Hive Auto-Routen & Kontinuierliche Optimierung|r", statusLine, 0.22, 0.74, 0.97)
	banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

	local budgetDrop = UI:CreateFlatDropdown(banner, 174, 24, {
		{ value = 0,   label = "Off (Opt Out)" },
		{ value = 0.8, label = "Ultra-Light (0.8ms)" },
		{ value = 1.5, label = "Balanced (1.5ms)" },
		{ value = 3.0, label = "Generous (3.0ms)" },
	}, b.enabled and b.budgetMs or 0, function(val)
		if val == 0 then
			PluribusHive:SetConfig("computeEnabled", false)
		else
			PluribusHive:SetConfig("computeEnabled", true)
			PluribusHive:SetConfig("computeBudgetMs", val)
		end
		if onRefresh then onRefresh() end
	end, "CPU Budget...")
	budgetDrop:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	-- Sub-mode buttons: Leveling Guide | Material Farming | Active Mesh Jobs
	local btnLvl = UI:CreateButton(parent, "Leveling Guide", 136, 24, function()
		PluribusHiveCompute.subView = "leveling"
		if onRefresh then onRefresh() end
	end)
	btnLvl:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)
	btnLvl:SetActiveState(self.subView == "leveling")

	local btnFarm = UI:CreateButton(parent, "Material Farming", 142, 24, function()
		PluribusHiveCompute.subView = "farming"
		if onRefresh then onRefresh() end
	end)
	btnFarm:SetPoint("LEFT", btnLvl, "RIGHT", 6, 0)
	btnFarm:SetActiveState(self.subView == "farming")

	local jobTag = (job and not job.done) and string.format(" (%d/%d)", job.completedCount, job.totalShards) or ""
	local btnMesh = UI:CreateButton(parent, "Mesh Workers" .. jobTag, 136, 24, function()
		PluribusHiveCompute.subView = "mesh"
		if onRefresh then onRefresh() end
	end)
	btnMesh:SetPoint("LEFT", btnFarm, "RIGHT", 6, 0)
	btnMesh:SetActiveState(self.subView == "mesh")

	local instCb = UI:CreateCheckbox(parent, "Pause in Raids/Dungeons", b.pauseInInstances, function(v)
		PluribusHive:SetConfig("computePauseInInstances", v)
	end)
	instCb:SetPoint("RIGHT", banner, "RIGHT", -6, -42)

	local bodyY = -92
	local cdb = self:GetComputeDB()

	if self.subView == "leveling" then
		-- Controls bar: Bracket Dropdown + Priority Dropdown + Instant Re-Optimize button
		local brDrop = UI:CreateFlatDropdown(parent, 186, 24, {
			{ value = "AUTO",  label = "Auto (My Current Level)" },
			{ value = "1-15",  label = "Levels 1 – 15" },
			{ value = "15-30", label = "Levels 15 – 30" },
			{ value = "30-45", label = "Levels 30 – 45" },
			{ value = "45-60", label = "Levels 45 – 60" },
			{ value = "1-60",  label = "Full Journey (1 – 60)" },
		}, self.selectedBracket, function(v)
			PluribusHiveCompute.selectedBracket = v
			local g = PluribusHiveCompute:GetCachedGuide("LEVELING", v, PluribusHiveCompute.selectedPriority)
			if not g or g.param ~= v then
				PluribusHiveCompute:AutoCalculateGuidesIfStale("LEVELING", v, PluribusHiveCompute.selectedPriority)
			end
			if onRefresh then onRefresh() end
		end, "Level Bracket...")
		brDrop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, bodyY)

		local prDrop = UI:CreateFlatDropdown(parent, 174, 24, {
			{ value = "BALANCED", label = "XP + Gold Balanced" },
			{ value = "XP",       label = "Fastest XP/hr" },
			{ value = "SAFE",     label = "Safest Solo Route" },
		}, self.selectedPriority, function(v)
			PluribusHiveCompute.selectedPriority = v
			local g = PluribusHiveCompute:GetCachedGuide("LEVELING", PluribusHiveCompute.selectedBracket, v)
			if not g or g.priority ~= v then
				PluribusHiveCompute:AutoCalculateGuidesIfStale("LEVELING", PluribusHiveCompute.selectedBracket, v)
			end
			if onRefresh then onRefresh() end
		end, "Route Goal...")
		prDrop:SetPoint("LEFT", brDrop, "RIGHT", 8, 0)

		local goBtn = UI:CreateButton(parent, "Jetzt neu optimieren", 156, 24, function()
			PluribusHiveCompute:StartJob("LEVELING", PluribusHiveCompute.selectedBracket, PluribusHiveCompute.selectedPriority)
			if onRefresh then onRefresh() end
		end, true)
		goBtn:SetPoint("LEFT", prDrop, "RIGHT", 8, 0)

		local scroll = UI:CreateScrollFrame(parent, "PluribusComputeLvlScroll", w, h - 126)
		scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, bodyY - 32)
		local y = -2

		local guide = self:GetCachedGuide("LEVELING", self.selectedBracket, self.selectedPriority)
		if job and job.kind == "LEVELING" and not job.done then
			local pct = math.floor((job.completedCount / math.max(1, job.totalShards)) * 100)
			local bar = UI:CreateStatusBar(scroll.content, w - 28, 24, 0.22, 0.74, 0.97)
			bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			bar:SetBarData(pct, string.format("Auto-Berechnung & Verfeinerung läuft (%d/%d Shards · %d Peers)...", job.completedCount, job.totalShards, #job.workers), pct .. "%")
			y = y - 32
		end

		if guide and guide.steps and #guide.steps > 0 then
			local passLbl = UI:CreateLabel(scroll.content, string.format(
				"|cff4ade80Gecacht & aktiv verbessert|r  ·  Pass #%d  ·  Gesamtreisezeit: ~%ds%s",
				guide.refinementPass or 1,
				guide.totalTravelSec or 0,
				(guide.savedTravelSec and guide.savedTravelSec > 0) and (" (|cff4ade80-" .. guide.savedTravelSec .. "s optimiert|r)") or ""
			), 0.75, 0.88, 0.96, "GameFontHighlightSmall")
			passLbl:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			y = y - 18

			for idx, st in ipairs(guide.steps) do
				local row = UI:CreateListRow(scroll.content, w - 28, 44, idx)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

				local badge = UI:CreateIconBadge(row, "Interface\\Icons\\INV_Misc_Map_01", 32, 0.22, 0.74, 0.97)
				badge:SetPoint("LEFT", row, "LEFT", 6, 0)

				local calTag = st.calibrated and " |cff4ade80[Hive Telemetry]|r" or ""
				local l1 = UI:CreateLabel(row, string.format("|cfffbbf24#%d %s|r |cff94a3b8(Lv %d-%d)|r  |cff4ade80~%dk XP/h|r · |cfffbbf24%s/h|r%s",
					idx, st.zone, st.minL or 1, st.maxL or 60, math.floor((st.xpHr or 0) / 1000), PluribusUtils:FormatGold(st.goldHr or 0), calTag))
				l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)

				local l2 = UI:CreateLabel(row, string.format("%s  ·  Shard by: %s", tostring(st.detail or ""):sub(1, 56), tostring(st.computedBy or "Local")), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

				local navBtn = UI:CreateButton(row, "Set Compass", 92, 22, function()
					if _G.PluribusNavigationUI then
						_G.PluribusNavigationUI:SetWaypoint("Lv" .. (st.minL or 1) .. ": " .. st.zone, st.zone, st.x or 50, st.y or 50)
					end
				end, true)
				navBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 46
			end
		else
			self:AutoCalculateGuidesIfStale("LEVELING", self.selectedBracket, self.selectedPriority)
			local em = UI:CreateLabel(scroll.content, "Route wird gerade automatisch im Hintergrund berechnet, gecacht und fortlaufend optimiert...", 0.70, 0.80, 0.90)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
			em:SetWidth(w - 40)
		end
		scroll.content:SetHeight(math.max(240, math.abs(y) + 12))

	elseif self.subView == "farming" then
		local tgDrop = UI:CreateFlatDropdown(parent, 236, 24, {
			{ value = "GUILD_NEEDS",       label = "Guild Shopping List & Needs (Best)" },
			{ value = "BEST_GOLD",         label = "Highest Gold/hr (Live AH Prices)" },
			{ value = "Herbalism",         label = "Herbalism Hotspots" },
			{ value = "Mining",            label = "Mining & Arcane Crystal Routes" },
			{ value = "Skinning",          label = "Skinning & Devilsaur Routes" },
			{ value = "Cloth & Elementals",label = "Cloth, Orbs & Elemental Essences" },
			{ value = "Fishing",           label = "Fishing & Stonescale Routes" },
		}, self.selectedFarmTarget, function(v)
			PluribusHiveCompute.selectedFarmTarget = v
			local g = PluribusHiveCompute:GetCachedGuide("FARMING", v, "GOLD")
			if not g or g.param ~= v then
				PluribusHiveCompute:AutoCalculateGuidesIfStale("FARMING", v, "GOLD")
			end
			if onRefresh then onRefresh() end
		end, "Farming Target...")
		tgDrop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, bodyY)

		local goBtn = UI:CreateButton(parent, "Jetzt neu optimieren", 168, 24, function()
			PluribusHiveCompute:StartJob("FARMING", PluribusHiveCompute.selectedFarmTarget, "GOLD")
			if onRefresh then onRefresh() end
		end, true)
		goBtn:SetPoint("LEFT", tgDrop, "RIGHT", 8, 0)

		local scroll = UI:CreateScrollFrame(parent, "PluribusComputeFarmScroll", w, h - 126)
		scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, bodyY - 32)
		local y = -2

		local guide = self:GetCachedGuide("FARMING", self.selectedFarmTarget, "GOLD")
		if job and job.kind == "FARMING" and not job.done then
			local pct = math.floor((job.completedCount / math.max(1, job.totalShards)) * 100)
			local bar = UI:CreateStatusBar(scroll.content, w - 28, 24, 0.29, 0.87, 0.50)
			bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			bar:SetBarData(pct, string.format("AH-Preise & Gildenbedarf werden automatisch optimiert (%d/%d Shards)...", job.completedCount, job.totalShards), pct .. "%")
			y = y - 32
		end

		if guide and guide.steps and #guide.steps > 0 then
			local passLbl = UI:CreateLabel(scroll.content, string.format(
				"|cff4ade80Gecacht & aktiv verbessert|r  ·  Pass #%d  ·  Tour-Reisezeit: ~%ds%s",
				guide.refinementPass or 1,
				guide.totalTravelSec or 0,
				(guide.savedTravelSec and guide.savedTravelSec > 0) and (" (|cff4ade80-" .. guide.savedTravelSec .. "s optimiert|r)") or ""
			), 0.75, 0.88, 0.96, "GameFontHighlightSmall")
			passLbl:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			y = y - 18

			for idx, st in ipairs(guide.steps) do
				local row = UI:CreateListRow(scroll.content, w - 28, 46, idx)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

				local slot = UI:CreateItemSlot(row, 34, {
					itemID = st.primaryItemId or 13466,
					name = st.title or st.zone,
					quality = (st.demandHits and st.demandHits > 0) and 3 or 2,
				})
				slot:SetPoint("LEFT", row, "LEFT", 6, 0)

				local needTag = (st.demandHits and st.demandHits > 0) and " |cff4ade80[GUILD NEED]|r" or ""
				local l1 = UI:CreateLabel(row, string.format("|cfffbbf24#%d %s|r — |cffffffff%s|r  |cff4ade80~%s/h|r%s",
					idx, st.zone, tostring(st.title or ""):sub(1, 28), PluribusUtils:FormatGold(st.goldHr or 0), needTag))
				l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -1)

				local l2 = UI:CreateLabel(row, string.format("Drops: %s  ·  By: %s", tostring(st.detail or ""):sub(1, 52), tostring(st.computedBy or "Local")), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 8, 1)

				local navBtn = UI:CreateButton(row, "Set Compass", 92, 22, function()
					if _G.PluribusNavigationUI then
						_G.PluribusNavigationUI:SetWaypoint("Farm: " .. (st.zone or "Spot"), st.zone, st.x or 50, st.y or 50)
					end
				end, true)
				navBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 48
			end
		else
			self:AutoCalculateGuidesIfStale("FARMING", self.selectedFarmTarget, "GOLD")
			local em = UI:CreateLabel(scroll.content, "Farm-Route wird gerade automatisch aus AH-Preisen, To-Do-Bedarf und Telemetrie berechnet und gecacht...", 0.70, 0.80, 0.90)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
			em:SetWidth(w - 40)
		end
		scroll.content:SetHeight(math.max(240, math.abs(y) + 12))

	else
		-- ACTIVE MESH WORKERS & SHARDS INSPECTOR
		local scroll = UI:CreateScrollFrame(parent, "PluribusComputeMeshScroll", w, h - 98)
		scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, bodyY)
		local y = -2

		local info = UI:CreateLabel(scroll.content, string.format(
			"|cff38bdf8Anti-Lag Protection Active:|r Work is sliced into <= %.1fms chunks at 10Hz max, pauses immediately in combat, pauses when FPS < %d, and uses LZ77-compressed background trickle packets.",
			b.budgetMs, b.minFps), 0.78, 0.86, 0.94)
		info:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		info:SetWidth(w - 34)
		y = y - 36

		if job then
			local hdr = UI:CreateLabel(scroll.content, string.format("|cfffbbf24Latest Mesh Job (%s — %s): %d / %d Shards Done|r", job.kind, tostring(job.param), job.completedCount, job.totalShards))
			hdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			y = y - 20
			for idx, sh in ipairs(job.shards) do
				local row = UI:CreateListRow(scroll.content, w - 28, 30, idx)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
				local col = (sh.status == "DONE" and "|cff4ade80") or (sh.status == "WORKING" and "|cff38bdf8") or "|cfffbbf24"
				local l1 = UI:CreateLabel(row, string.format("Shard #%d/%d  ·  Assigned Worker: |cffffffff%s|r  ·  %d zones", sh.idx, job.totalShards, tostring(sh.worker or sh.assignedTo), #(sh.data and sh.data.items or {})))
				l1:SetPoint("LEFT", row, "LEFT", 8, 0)
				local stLbl = UI:CreateLabel(row, string.format("%s%s|r%s", col, sh.status, (sh.ms and sh.ms > 0) and string.format(" (%.1fms)", sh.ms) or ""))
				stLbl:SetPoint("RIGHT", row, "RIGHT", -10, 0)
				y = y - 32
			end
		else
			local em = UI:CreateLabel(scroll.content, "No distributed mesh job run this session yet. Start a Leveling Guide or Material Farming calculation to watch shards split cleanly across idle guildmates!", 0.70, 0.80, 0.90)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			em:SetWidth(w - 34)
		end
		scroll.content:SetHeight(math.max(240, math.abs(y) + 12))
	end
end

-- ============================================================================
-- INITIALIZATION & P2P PROTOCOL HOOKS
-- ============================================================================
function PluribusHiveCompute:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:GetComputeDB()

	-- Receive distributed compute job requests from guildmates
	PluribusHive:RegisterHandler("JOBREQ", function(sender, body)
		local jobId, kind, param, priority, _, wList = body:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|(%d+)|?(.*)$")
		if not jobId or not kind then return end
		local workers = {}
		for wn in tostring(wList or ""):gmatch("[^,]+") do
			if wn ~= "" then table.insert(workers, wn) end
		end
		-- Join the distributed job if our compute worker is enabled
		if PluribusHiveCompute:GetBudgetConfig().enabled then
			PluribusHiveCompute:StartJob(kind, param, priority, sender, jobId, workers)
		end
	end)

	PluribusHive:RegisterHandler("JOBCLAIM", function(sender, body)
		local jobId, idxStr = body:match("^([^|]+)|(%d+)$")
		local idx = tonumber(idxStr)
		local job = PluribusHiveCompute.activeJob
		if job and job.id == jobId and idx and job.shards[idx] and job.shards[idx].status ~= "DONE" then
			job.shards[idx].status = "WORKING"
			job.shards[idx].worker = sender
			job.shards[idx].assignedAt = time()
		end
	end)

	PluribusHive:RegisterHandler("JOBRES", function(sender, body)
		local jobId, idxStr, msStr, encoded = body:match("^([^|]+)|(%d+)|([^|]+)|?(.*)$")
		local idx = tonumber(idxStr)
		local job = PluribusHiveCompute.activeJob
		if job and job.id == jobId and idx then
			local decoded = DecodeShardResults(encoded, job.kind)
			PluribusHiveCompute:ApplyShardResult(jobId, idx, sender, tonumber(msStr) or 0, decoded)
		end
	end)

	-- Receive passive world resource telemetry from guildmates
	PluribusHive:RegisterHandler("TELEM", function(_, body)
		local zone, xpStr, goldStr, itemsStr = body:match("^([^|]+)|(%d+)|(%d+)|?(.*)$")
		if not zone or zone == "" then return end
		local cdb = PluribusHiveCompute:GetComputeDB()
		local rec = cdb.telemetry[zone] or { samples = 0, xpHr = 0, goldHr = 0, items = {}, updatedAt = 0 }
		local xpHr, goldHr = tonumber(xpStr) or 0, tonumber(goldStr) or 0
		local n = math.min(20, rec.samples or 0)
		if xpHr > 0 then rec.xpHr = math.floor(((rec.xpHr * n) + xpHr) / (n + 1)) end
		if goldHr > 0 then rec.goldHr = math.floor(((rec.goldHr * n) + goldHr) / (n + 1)) end
		for idS, cntS in tostring(itemsStr or ""):gmatch("(%d+):(%d+)") do
			local id, cnt = tonumber(idS), tonumber(cntS)
			if id and cnt then
				rec.items[id] = math.min(9999, (rec.items[id] or 0) + cnt)
			end
		end
		rec.samples = (rec.samples or 0) + 1
		rec.updatedAt = time()
		cdb.telemetry[zone] = rec
	end)

	-- Event frame for passive telemetry, auto-guide calculation, + throttled 10Hz zero-lag scheduler
	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "QUEST_TURNED_IN" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	self.zoneSession.zone = GetRealZoneText and GetRealZoneText() or "Azeroth"
	self.zoneSession.enteredAt = time()

	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_TODO_CHANGED", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(1.5, function()
					PluribusHiveCompute:AutoCalculateGuidesIfStale("FARMING", "GUILD_NEEDS", "GOLD")
				end)
			end
		end)
		_G.PluribusMessaging:Subscribe("HIVE_AH_UPDATED", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(2.0, function()
					PluribusHiveCompute:AutoCalculateGuidesIfStale("FARMING", "BEST_GOLD", "GOLD")
				end)
			end
		end)
	end

	f:SetScript("OnEvent", function(_, event, arg1, arg2)
		local zs = PluribusHiveCompute.zoneSession
		if event == "PLAYER_ENTERING_WORLD" then
			if C_Timer and C_Timer.After then
				C_Timer.After(2.0, function()
					PluribusHiveCompute:AutoCalculateGuidesIfStale()
				end)
			else
				PluribusHiveCompute:AutoCalculateGuidesIfStale()
			end
		elseif event == "PLAYER_LEVEL_UP" then
			if C_Timer and C_Timer.After then
				C_Timer.After(2.0, function()
					PluribusHiveCompute:AutoCalculateGuidesIfStale("LEVELING", "AUTO", PluribusHiveCompute.selectedPriority or "BALANCED")
				end)
			end
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			PluribusHiveCompute:FlushZoneSession()
			zs.zone = GetRealZoneText and GetRealZoneText() or "Azeroth"
			zs.enteredAt = time()
			-- Immediately re-rank active routes around the player's newly entered zone
			PluribusHiveCompute.lastRefinementAt = 0
		elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and type(arg1) == "string" then
			local xp = tonumber(arg1:match("(%d+)%s+experience")) or tonumber(arg1:match("(%d+)%s+Erfahrung")) or tonumber(arg1:match("(%d+)")) or 0
			if xp > 0 then zs.xp = (zs.xp or 0) + xp end
		elseif event == "QUEST_TURNED_IN" then
			local xp = tonumber(arg2) or 0
			if xp > 0 then zs.xp = (zs.xp or 0) + xp end
		elseif event == "CHAT_MSG_LOOT" and type(arg1) == "string" then
			local id = tonumber(arg1:match("item:(%d+)"))
			if id then
				local qty = tonumber(arg1:match("x(%d+)")) or 1
				zs.items[id] = (zs.items[id] or 0) + qty
			end
		elseif event == "CHAT_MSG_MONEY" and type(arg1) == "string" then
			local g = tonumber(arg1:match("(%d+)%s*Gold")) or 0
			local s = tonumber(arg1:match("(%d+)%s*Silver")) or tonumber(arg1:match("(%d+)%s*Silber")) or 0
			local c = tonumber(arg1:match("(%d+)%s*Copper")) or tonumber(arg1:match("(%d+)%s*Kupfer")) or 0
			local total = g * 10000 + s * 100 + c
			if total > 0 then zs.copper = (zs.copper or 0) + total end
		end
	end)

	local tickAccum = 0
	local telemAccum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		tickAccum = tickAccum + (elapsed or 0)
		telemAccum = telemAccum + (elapsed or 0)
		if tickAccum >= TICK_INTERVAL then
			tickAccum = 0
			PluribusHiveCompute:StepScheduler()
		end
		if telemAccum >= TELEM_SHARE_INTERVAL then
			telemAccum = 0
			PluribusHiveCompute:FlushZoneSession()
		end
	end)
end

return PluribusHiveCompute
