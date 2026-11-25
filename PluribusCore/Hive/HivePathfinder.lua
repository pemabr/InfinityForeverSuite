-- PluribusHive Multi-Modal Azeroth Pathfinder Engine
-- Calculates real shortest-travel-time turn-by-turn routes across Azeroth 1.60.1:
--   1. Road & Zone-Pass Graph (guides along roads & mountain passes, NOT straight lines through mountains!)
--   2. Dynamic Land Speed (Foot / Ghost Wolf / Travel Form / Cheetah / 60% Mount / 100% Epic Mount)
--   3. Dynamic Water / Swim Speed (Normal Swim vs Druid Aquatic Form "Robbe" / Fishing Hook / Swim Buff)
--   4. Discovered Flight Points (auto-recorded on TAXIMAP_OPENED per character, faction-aware)
--   5. Guild-Synced Boat & Zeppelin Departure Timers (SHIPSYNC over PLBHIVE -> exact wait time!)
--   6. Level-Aware Hazard Avoidance (penalizes high-level zones/mobs relative to player level & prefers roads)

PluribusHivePathfinder = {
	initialized = false,
	activeRoute = nil,
	activeLegIndex = 1,
	activeLegStartedAt = 0,
	activeLegFromNode = nil,
	lastBoardedShip = nil,
	precomputeQueue = {},
	precomputeCursor = 1,
	backgroundRunning = false,
}
_G.PluribusHivePathfinder = PluribusHivePathfinder

local BASE_RUN_SPEED = 7.0 -- Classic WoW base run speed: 7 yards/sec
local BASE_SWIM_SPEED = 4.72 -- Classic WoW base swim speed: ~67% of run speed
local FLIGHT_SPEED = 32.0 -- Classic gryphon/wyvern average speed ~32 yds/sec

-- Classic 1.60.1 Boat & Zeppelin Schedules (periodSec = full round-trip cycle, sailSec = crossing time)
PluribusHivePathfinder.SHIP_ROUTES = {
	booty_ratchet = {
		id = "booty_ratchet",
		kind = "boat",
		from = "bb_dock",
		to = "ratchet_dock",
		fromLabel = "Booty Bay",
		toLabel = "Ratchet",
		cycleSec = 300,
		sailSec = 75,
		faction = "NEUTRAL",
	},
	menethil_auberdine = {
		id = "menethil_auberdine",
		kind = "boat",
		from = "menethil_dock",
		to = "auberdine_dock",
		fromLabel = "Menethil Harbor",
		toLabel = "Auberdine",
		cycleSec = 240,
		sailSec = 65,
		faction = "ALLIANCE",
	},
	menethil_theramore = {
		id = "menethil_theramore",
		kind = "boat",
		from = "menethil_dock",
		to = "theramore_dock",
		fromLabel = "Menethil Harbor",
		toLabel = "Theramore Isle",
		cycleSec = 280,
		sailSec = 80,
		faction = "ALLIANCE",
	},
	org_uc_zep = {
		id = "org_uc_zep",
		kind = "zeppelin",
		from = "org_zep",
		to = "uc_zep",
		fromLabel = "Orgrimmar",
		toLabel = "Undercity",
		cycleSec = 210,
		sailSec = 55,
		faction = "HORDE",
	},
	org_gg_zep = {
		id = "org_gg_zep",
		kind = "zeppelin",
		from = "org_zep",
		to = "gromgol_zep",
		fromLabel = "Orgrimmar",
		toLabel = "Grom'gol",
		cycleSec = 240,
		sailSec = 65,
		faction = "HORDE",
	},
	uc_gg_zep = {
		id = "uc_gg_zep",
		kind = "zeppelin",
		from = "uc_zep",
		to = "gromgol_zep",
		fromLabel = "Undercity",
		toLabel = "Grom'gol",
		cycleSec = 260,
		sailSec = 70,
		faction = "HORDE",
	},
}

-- Canonical German -> English zone name normalizer so graph matches both deDE and enUS clients
local ZONE_ALIASES = {
	["wald von elwynn"] = "Elwynn Forest",
	["sturmwind"] = "Stormwind City",
	["westfall"] = "Westfall",
	["rotkammgebirge"] = "Redridge Mountains",
	["dämmerwald"] = "Duskwood",
	["schlingendorntal"] = "Stranglethorn Vale",
	["dun morogh"] = "Dun Morogh",
	["eisenschmiede"] = "Ironforge",
	["loch modan"] = "Loch Modan",
	["sumpfland"] = "Wetlands",
	["arathihochland"] = "Arathi Highlands",
	["vorgebirge des hügellands"] = "Hillsbrad Foothills",
	["silberwald"] = "Silverpine Forest",
	["tirisfal"] = "Tirisfal Glades",
	["unterstadt"] = "Undercity",
	["westliche pestländer"] = "Western Plaguelands",
	["östliche pestländer"] = "Eastern Plaguelands",
	["hinterland"] = "The Hinterlands",
	["ödland"] = "Badlands",
	["sengende schlucht"] = "Searing Gorge",
	["brennende steppe"] = "Burning Steppes",
	["sümpfe des elends"] = "Swamp of Sorrows",
	["verwüstete lande"] = "Blasted Lands",
	["durotar"] = "Durotar",
	["orgrimmar"] = "Orgrimmar",
	["brachland"] = "The Barrens",
	["mulgore"] = "Mulgore",
	["donnerfels"] = "Thunder Bluff",
	["eschental"] = "Ashenvale",
	["dunkelküste"] = "Darkshore",
	["teldrassil"] = "Teldrassil",
	["darnassus"] = "Darnassus",
	["steinkrallengebirge"] = "Stonetalon Mountains",
	["desolace"] = "Desolace",
	["tausend nadeln"] = "Thousand Needles",
	["düstermarschen"] = "Dustwallow Marsh",
	["tanaris"] = "Tanaris",
	["feralas"] = "Feralas",
	["krater von un'goro"] = "Un'Goro Crater",
	["silithus"] = "Silithus",
	["teufelswald"] = "Felwood",
	["winterquell"] = "Winterspring",
	["azshara"] = "Azshara",
	["östliche königreiche"] = "Eastern Kingdoms",
	["eastern kingdoms"] = "Eastern Kingdoms",
	["kalimdor"] = "Kalimdor",
	["azeroth"] = "Azeroth",
}

function PluribusHivePathfinder:CanonicalZone(zoneName)
	if not zoneName or zoneName == "" then return "Elwynn Forest" end
	local low = tostring(zoneName):lower():match("^%s*(.-)%s*$") or ""
	return ZONE_ALIASES[low] or zoneName
end

-- Azeroth Multi-Modal Navigation Graph Nodes (Road junctions, Zone passes, Docks, Zeppelins, Flight Masters, Water crossings)
PluribusHivePathfinder.NODES = {
	-- Eastern Kingdoms (cont = 1)
	sw_gate        = { zone = "Elwynn Forest",       cont = 1, x = 32.0, y = 49.5, kind = "flight",   label = "Stormwind City",       minL = 1,  maxL = 12, faction = "ALLIANCE", fpNames = { "stormwind", "sturmwind" } },
	goldshire      = { zone = "Elwynn Forest",       cont = 1, x = 42.1, y = 65.9, kind = "road",     label = "Goldshire Crossroads", minL = 1,  maxL = 12, faction = "NEUTRAL" },
	elwynn_west    = { zone = "Elwynn Forest",       cont = 1, x = 24.5, y = 74.5, kind = "road",     label = "Westfall Bridge",      minL = 8,  maxL = 14, faction = "NEUTRAL" },
	elwynn_east    = { zone = "Elwynn Forest",       cont = 1, x = 84.5, y = 70.0, kind = "road",     label = "Eastvale / Redridge Pass", minL = 10, maxL = 16, faction = "NEUTRAL" },
	sentinel_hill  = { zone = "Westfall",            cont = 1, x = 56.5, y = 52.6, kind = "flight",   label = "Sentinel Hill",        minL = 10, maxL = 20, faction = "ALLIANCE", fpNames = { "sentinel hill", "späherkuppe" } },
	lakeshire      = { zone = "Redridge Mountains",  cont = 1, x = 30.6, y = 59.4, kind = "flight",   label = "Lakeshire",            minL = 15, maxL = 25, faction = "ALLIANCE", fpNames = { "lakeshire", "seenhain" } },
	darkshire      = { zone = "Duskwood",            cont = 1, x = 77.5, y = 44.3, kind = "flight",   label = "Darkshire",            minL = 18, maxL = 30, faction = "ALLIANCE", fpNames = { "darkshire", "dunkelhain" } },
	duskwood_south = { zone = "Duskwood",            cont = 1, x = 44.8, y = 86.2, kind = "road",     label = "STV North Road",       minL = 24, maxL = 32, faction = "NEUTRAL" },
	rebel_camp     = { zone = "Stranglethorn Vale",  cont = 1, x = 38.2, y = 4.2,  kind = "road",     label = "Rebel Camp Road",      minL = 30, maxL = 38, faction = "NEUTRAL" },
	gromgol_zep    = { zone = "Stranglethorn Vale",  cont = 1, x = 31.6, y = 29.2, kind = "zeppelin", label = "Grom'gol Zeppelin",    minL = 32, maxL = 42, faction = "HORDE",    fpNames = { "grom'gol" } },
	stv_water_cross= { zone = "Stranglethorn Vale",  cont = 1, x = 28.0, y = 56.0, kind = "water",    label = "STV West Coast Swim",  minL = 35, maxL = 43, faction = "NEUTRAL" },
	bb_dock        = { zone = "Stranglethorn Vale",  cont = 1, x = 26.8, y = 73.6, kind = "boat",     label = "Booty Bay Dock",       minL = 30, maxL = 45, faction = "NEUTRAL",  fpNames = { "booty bay", "beutebucht" } },
	ironforge      = { zone = "Dun Morogh",          cont = 1, x = 55.6, y = 47.8, kind = "flight",   label = "Ironforge",            minL = 1,  maxL = 12, faction = "ALLIANCE", fpNames = { "ironforge", "eisenschmiede" } },
	thelsamar      = { zone = "Loch Modan",          cont = 1, x = 33.9, y = 50.9, kind = "flight",   label = "Thelsamar",            minL = 10, maxL = 20, faction = "ALLIANCE", fpNames = { "thelsamar" } },
	menethil_dock  = { zone = "Wetlands",            cont = 1, x = 6.2,  y = 60.4, kind = "boat",     label = "Menethil Harbor",      minL = 20, maxL = 30, faction = "ALLIANCE", fpNames = { "menethil" } },
	wetlands_water = { zone = "Wetlands",            cont = 1, x = 18.0, y = 48.0, kind = "water",    label = "Wetlands Marsh Swim",  minL = 22, maxL = 28, faction = "NEUTRAL" },
	thandol_span   = { zone = "Wetlands",            cont = 1, x = 49.8, y = 12.2, kind = "road",     label = "Thandol Span Bridge",  minL = 25, maxL = 32, faction = "NEUTRAL" },
	refuge_pointe  = { zone = "Arathi Highlands",    cont = 1, x = 45.8, y = 46.1, kind = "flight",   label = "Refuge Pointe",        minL = 30, maxL = 40, faction = "ALLIANCE", fpNames = { "refuge pointe", "zuflucht" } },
	hammerfall     = { zone = "Arathi Highlands",    cont = 1, x = 73.1, y = 32.7, kind = "flight",   label = "Hammerfall",           minL = 30, maxL = 40, faction = "HORDE",    fpNames = { "hammerfall" } },
	southshore     = { zone = "Hillsbrad Foothills", cont = 1, x = 49.4, y = 52.3, kind = "flight",   label = "Southshore",           minL = 20, maxL = 32, faction = "ALLIANCE", fpNames = { "southshore", "süderstade" } },
	tarren_mill    = { zone = "Hillsbrad Foothills", cont = 1, x = 60.2, y = 18.7, kind = "flight",   label = "Tarren Mill",          minL = 20, maxL = 32, faction = "HORDE",    fpNames = { "tarren mill", "tarrens mühle" } },
	sepulcher      = { zone = "Silverpine Forest",   cont = 1, x = 45.6, y = 42.6, kind = "flight",   label = "The Sepulcher",        minL = 10, maxL = 20, faction = "HORDE",    fpNames = { "sepulcher", "grabmal" } },
	uc_zep         = { zone = "Tirisfal Glades",     cont = 1, x = 61.6, y = 58.8, kind = "zeppelin", label = "Undercity Zeppelin",   minL = 1,  maxL = 12, faction = "HORDE",    fpNames = { "undercity", "unterstadt" } },
	aerie_peak     = { zone = "The Hinterlands",     cont = 1, x = 11.1, y = 46.2, kind = "flight",   label = "Aerie Peak",           minL = 42, maxL = 50, faction = "ALLIANCE", fpNames = { "aerie peak", "nistgipfel" } },
	chillwind      = { zone = "Western Plaguelands", cont = 1, x = 42.9, y = 85.1, kind = "flight",   label = "Chillwind Camp",       minL = 50, maxL = 58, faction = "ALLIANCE", fpNames = { "chillwind", "zugwind" } },
	lights_hope    = { zone = "Eastern Plaguelands", cont = 1, x = 81.6, y = 59.3, kind = "flight",   label = "Light's Hope Chapel",  minL = 53, maxL = 60, faction = "NEUTRAL",  fpNames = { "light's hope", "kapelle des hoffnungsvollen lichts" } },
	kargath        = { zone = "Badlands",            cont = 1, x = 4.0,  y = 44.8, kind = "flight",   label = "Kargath",              minL = 35, maxL = 45, faction = "HORDE",    fpNames = { "kargath" } },
	thorium_point  = { zone = "Searing Gorge",       cont = 1, x = 37.9, y = 30.8, kind = "flight",   label = "Thorium Point",        minL = 45, maxL = 52, faction = "NEUTRAL",  fpNames = { "thorium" } },
	morgans_vigil  = { zone = "Burning Steppes",     cont = 1, x = 84.3, y = 68.3, kind = "flight",   label = "Morgan's Vigil / BRM", minL = 50, maxL = 58, faction = "ALLIANCE", fpNames = { "morgan", "flammenkamm" } },
	nethergarde    = { zone = "Blasted Lands",       cont = 1, x = 65.5, y = 24.3, kind = "flight",   label = "Nethergarde Keep",     minL = 48, maxL = 56, faction = "ALLIANCE", fpNames = { "nethergarde", "burg nethergarde" } },

	-- Kalimdor (cont = 2)
	org_zep        = { zone = "Durotar",             cont = 2, x = 50.8, y = 13.8, kind = "zeppelin", label = "Orgrimmar Zeppelin",   minL = 1,  maxL = 12, faction = "HORDE",    fpNames = { "orgrimmar" } },
	razor_hill     = { zone = "Durotar",             cont = 2, x = 52.0, y = 41.6, kind = "road",     label = "Razor Hill Road",      minL = 5,  maxL = 12, faction = "NEUTRAL" },
	crossroads     = { zone = "The Barrens",         cont = 2, x = 51.5, y = 30.3, kind = "flight",   label = "The Crossroads",       minL = 10, maxL = 22, faction = "HORDE",    fpNames = { "crossroads", "wegekreuz" } },
	ratchet_dock   = { zone = "The Barrens",         cont = 2, x = 63.1, y = 37.2, kind = "boat",     label = "Ratchet Dock",         minL = 12, maxL = 22, faction = "NEUTRAL",  fpNames = { "ratchet", "ratschet" } },
	camp_taurajo   = { zone = "The Barrens",         cont = 2, x = 44.5, y = 59.1, kind = "flight",   label = "Camp Taurajo",         minL = 18, maxL = 26, faction = "HORDE",    fpNames = { "taurajo" } },
	thunder_bluff  = { zone = "Mulgore",             cont = 2, x = 47.0, y = 49.8, kind = "flight",   label = "Thunder Bluff",        minL = 1,  maxL = 12, faction = "HORDE",    fpNames = { "thunder bluff", "donnerfels" } },
	darnassus      = { zone = "Teldrassil",          cont = 2, x = 58.4, y = 94.0, kind = "flight",   label = "Darnassus / Rut'theran", minL = 1, maxL = 12, faction = "ALLIANCE", fpNames = { "rut'theran", "darnassus", "teldrassil" } },
	auberdine_dock = { zone = "Darkshore",           cont = 2, x = 33.2, y = 40.2, kind = "boat",     label = "Auberdine Dock",       minL = 10, maxL = 20, faction = "ALLIANCE", fpNames = { "auberdine" } },
	astranaar      = { zone = "Ashenvale",           cont = 2, x = 34.4, y = 48.0, kind = "flight",   label = "Astranaar",            minL = 18, maxL = 30, faction = "ALLIANCE", fpNames = { "astranaar" } },
	splintertree   = { zone = "Ashenvale",           cont = 2, x = 73.2, y = 61.6, kind = "flight",   label = "Splintertree Post",    minL = 20, maxL = 30, faction = "HORDE",    fpNames = { "splintertree", "splitterholz" } },
	theramore_dock = { zone = "Dustwallow Marsh",    cont = 2, x = 71.2, y = 56.4, kind = "boat",     label = "Theramore Dock",       minL = 35, maxL = 45, faction = "ALLIANCE", fpNames = { "theramore" } },
	dustwallow_swim= { zone = "Dustwallow Marsh",    cont = 2, x = 58.0, y = 52.0, kind = "water",    label = "Dustwallow Bay Swim",  minL = 36, maxL = 42, faction = "NEUTRAL" },
	freewind_post  = { zone = "Thousand Needles",    cont = 2, x = 45.1, y = 49.1, kind = "flight",   label = "Freewind Post",        minL = 25, maxL = 35, faction = "HORDE",    fpNames = { "freewind", "freiwind" } },
	gadgetzan      = { zone = "Tanaris",             cont = 2, x = 51.0, y = 29.3, kind = "flight",   label = "Gadgetzan",            minL = 40, maxL = 50, faction = "NEUTRAL",  fpNames = { "gadgetzan" } },
	feathermoon    = { zone = "Feralas",             cont = 2, x = 30.2, y = 43.2, kind = "flight",   label = "Feathermoon",          minL = 40, maxL = 50, faction = "ALLIANCE", fpNames = { "feathermoon", "mondfeder" } },
	nijels_point   = { zone = "Desolace",            cont = 2, x = 64.7, y = 10.5, kind = "flight",   label = "Nijel's Point",        minL = 30, maxL = 40, faction = "ALLIANCE", fpNames = { "nijel", "schattenflucht" } },
	marshals_refuge= { zone = "Un'Goro Crater",      cont = 2, x = 45.2, y = 5.8,  kind = "flight",   label = "Marshal's Refuge",     minL = 48, maxL = 55, faction = "NEUTRAL",  fpNames = { "marshal" } },
	cenarion_hold  = { zone = "Silithus",            cont = 2, x = 50.6, y = 34.5, kind = "flight",   label = "Cenarion Hold",        minL = 55, maxL = 60, faction = "NEUTRAL",  fpNames = { "cenarion", "burg cenarius" } },
	emerald_sanc   = { zone = "Felwood",             cont = 2, x = 51.5, y = 82.2, kind = "flight",   label = "Emerald Sanctuary",    minL = 48, maxL = 55, faction = "NEUTRAL",  fpNames = { "talonbranch", "blutgift", "nachthaven" } },
	everlook       = { zone = "Winterspring",        cont = 2, x = 62.3, y = 36.6, kind = "flight",   label = "Everlook",             minL = 54, maxL = 60, faction = "NEUTRAL",  fpNames = { "everlook", "ewige warte" } },
	azshara_road   = { zone = "Azshara",             cont = 2, x = 11.9, y = 77.6, kind = "flight",   label = "Azshara Entrance",     minL = 48, maxL = 55, faction = "NEUTRAL",  fpNames = { "talrendis", "valormok" } },
}

-- Bi-directional road, water, flight, boat & zeppelin edges
PluribusHivePathfinder.EDGES = {
	-- Eastern Kingdoms Roads & Passes (isRoad = true gets safety & smoothness bonus)
	{ "sw_gate", "goldshire",       mode = "road",  dist = 650,  isRoad = true,  minL = 1 },
	{ "goldshire", "elwynn_west",   mode = "road",  dist = 900,  isRoad = true,  minL = 6 },
	{ "elwynn_west", "sentinel_hill", mode = "road", dist = 1100, isRoad = true, minL = 10 },
	{ "goldshire", "elwynn_east",   mode = "road",  dist = 1400, isRoad = true,  minL = 8 },
	{ "elwynn_east", "lakeshire",   mode = "road",  dist = 1150, isRoad = true,  minL = 15 },
	{ "goldshire", "darkshire",     mode = "road",  dist = 1750, isRoad = true,  minL = 18 },
	{ "lakeshire", "darkshire",     mode = "road",  dist = 1450, isRoad = true,  minL = 18 },
	{ "lakeshire", "morgans_vigil", mode = "road",  dist = 1900, isRoad = true,  minL = 50 },
	{ "darkshire", "nethergarde",   mode = "road",  dist = 2400, isRoad = true,  minL = 45 },
	{ "darkshire", "duskwood_south",mode = "road",  dist = 1250, isRoad = true,  minL = 22 },
	{ "duskwood_south", "rebel_camp", mode = "road", dist = 800, isRoad = true,  minL = 30 },
	{ "rebel_camp", "gromgol_zep",  mode = "road",  dist = 1450, isRoad = true,  minL = 32 },
	{ "gromgol_zep", "bb_dock",     mode = "road",  dist = 2100, isRoad = true,  minL = 35 },
	-- Water shortcut along STV coast (faster ONLY with Aquatic Form / Robbe / Swim buff!)
	{ "gromgol_zep", "stv_water_cross", mode = "water", dist = 820, isRoad = false, minL = 34 },
	{ "stv_water_cross", "bb_dock",     mode = "water", dist = 840, isRoad = false, minL = 34 },
	-- Deeprun Tram (Stormwind <-> Ironforge, fast Alliance rail!)
	{ "sw_gate", "ironforge",       mode = "road",  dist = 950,  isRoad = true,  minL = 1, faction = "ALLIANCE" },
	{ "ironforge", "thelsamar",     mode = "road",  dist = 1850, isRoad = true,  minL = 10 },
	{ "thelsamar", "menethil_dock", mode = "road",  dist = 2200, isRoad = true,  minL = 20 },
	{ "thelsamar", "kargath",       mode = "road",  dist = 1900, isRoad = true,  minL = 35 },
	{ "kargath", "thorium_point",   mode = "road",  dist = 1400, isRoad = true,  minL = 45 },
	{ "thorium_point", "morgans_vigil", mode = "road", dist = 1200, isRoad = true, minL = 50 },
	{ "menethil_dock", "thandol_span", mode = "road", dist = 2100, isRoad = true, minL = 24 },
	-- Wetlands water shortcut (swimmer shortcut vs long road)
	{ "menethil_dock", "wetlands_water", mode = "water", dist = 700, isRoad = false, minL = 22 },
	{ "wetlands_water", "thandol_span",  mode = "water", dist = 900, isRoad = false, minL = 24 },
	{ "thandol_span", "refuge_pointe", mode = "road", dist = 1500, isRoad = true, minL = 30 },
	{ "refuge_pointe", "hammerfall",   mode = "road", dist = 1100, isRoad = true, minL = 32 },
	{ "refuge_pointe", "southshore",   mode = "road", dist = 1900, isRoad = true, minL = 25 },
	{ "southshore", "tarren_mill",     mode = "road", dist = 1200, isRoad = true, minL = 22 },
	{ "southshore", "sepulcher",       mode = "road", dist = 1750, isRoad = true, minL = 15 },
	{ "sepulcher", "uc_zep",           mode = "road", dist = 1550, isRoad = true, minL = 10 },
	{ "tarren_mill", "aerie_peak",     mode = "road", dist = 1700, isRoad = true, minL = 42 },
	{ "tarren_mill", "chillwind",      mode = "road", dist = 1650, isRoad = true, minL = 50 },
	{ "uc_zep", "chillwind",           mode = "road", dist = 1950, isRoad = true, minL = 50 },
	{ "chillwind", "lights_hope",      mode = "road", dist = 2450, isRoad = true, minL = 53 },

	-- Kalimdor Roads & Passes
	{ "org_zep", "razor_hill",      mode = "road",  dist = 950,  isRoad = true,  minL = 1 },
	{ "razor_hill", "crossroads",   mode = "road",  dist = 1550, isRoad = true,  minL = 10 },
	{ "crossroads", "ratchet_dock", mode = "road",  dist = 980,  isRoad = true,  minL = 12 },
	{ "crossroads", "camp_taurajo", mode = "road",  dist = 1350, isRoad = true,  minL = 18 },
	{ "camp_taurajo", "thunder_bluff", mode = "road", dist = 1500, isRoad = true, minL = 10 },
	{ "crossroads", "splintertree", mode = "road",  dist = 1500, isRoad = true,  minL = 20 },
	{ "splintertree", "astranaar",  mode = "road",  dist = 1650, isRoad = true,  minL = 20 },
	{ "darnassus", "auberdine_dock",mode = "road",  dist = 1150, isRoad = true,  minL = 1, faction = "ALLIANCE" }, -- Rut'theran <-> Auberdine hippogryph shuttle
	{ "astranaar", "auberdine_dock",mode = "road",  dist = 1950, isRoad = true,  minL = 15 },
	{ "astranaar", "emerald_sanc",  mode = "road",  dist = 1800, isRoad = true,  minL = 48 },
	{ "emerald_sanc", "everlook",   mode = "road",  dist = 2300, isRoad = true,  minL = 54 },
	{ "splintertree", "azshara_road", mode = "road", dist = 1400, isRoad = true, minL = 48 },
	{ "camp_taurajo", "theramore_dock", mode = "road", dist = 2150, isRoad = true, minL = 35 },
	{ "camp_taurajo", "dustwallow_swim", mode = "water", dist = 950, isRoad = false, minL = 35 },
	{ "dustwallow_swim", "theramore_dock", mode = "water", dist = 620, isRoad = false, minL = 35 },
	{ "camp_taurajo", "freewind_post", mode = "road", dist = 1650, isRoad = true, minL = 25 },
	{ "freewind_post", "gadgetzan", mode = "road",  dist = 1850, isRoad = true,  minL = 40 },
	{ "freewind_post", "feathermoon", mode = "road", dist = 2400, isRoad = true, minL = 40 },
	{ "feathermoon", "nijels_point",mode = "road",  dist = 2250, isRoad = true,  minL = 35 },
	{ "astranaar", "nijels_point",  mode = "road",  dist = 2350, isRoad = true,  minL = 30 },
	{ "gadgetzan", "marshals_refuge", mode = "road", dist = 1950, isRoad = true, minL = 48 },
	{ "marshals_refuge", "cenarion_hold", mode = "road", dist = 1850, isRoad = true, minL = 55 },

	-- Flight Paths (ONLY usable if BOTH endpoints are discovered by this character!)
	{ "sw_gate", "sentinel_hill",   mode = "flight", dist = 1400, faction = "ALLIANCE" },
	{ "sw_gate", "lakeshire",       mode = "flight", dist = 1750, faction = "ALLIANCE" },
	{ "sw_gate", "darkshire",       mode = "flight", dist = 1650, faction = "ALLIANCE" },
	{ "sw_gate", "ironforge",       mode = "flight", dist = 2900, faction = "ALLIANCE" },
	{ "sw_gate", "bb_dock",         mode = "flight", dist = 3900, faction = "ALLIANCE" },
	{ "sw_gate", "morgans_vigil",   mode = "flight", dist = 2200, faction = "ALLIANCE" },
	{ "sw_gate", "nethergarde",     mode = "flight", dist = 3200, faction = "ALLIANCE" },
	{ "ironforge", "thelsamar",     mode = "flight", dist = 1600, faction = "ALLIANCE" },
	{ "ironforge", "menethil_dock", mode = "flight", dist = 1900, faction = "ALLIANCE" },
	{ "ironforge", "refuge_pointe", mode = "flight", dist = 3400, faction = "ALLIANCE" },
	{ "ironforge", "southshore",    mode = "flight", dist = 3600, faction = "ALLIANCE" },
	{ "ironforge", "thorium_point", mode = "flight", dist = 1800, faction = "ALLIANCE" },
	{ "ironforge", "chillwind",     mode = "flight", dist = 4800, faction = "ALLIANCE" },
	{ "ironforge", "lights_hope",   mode = "flight", dist = 6200, faction = "ALLIANCE" },
	{ "southshore", "aerie_peak",   mode = "flight", dist = 1600, faction = "ALLIANCE" },
	{ "chillwind", "lights_hope",   mode = "flight", dist = 2200, faction = "ALLIANCE" },
	{ "uc_zep", "sepulcher",        mode = "flight", dist = 1400, faction = "HORDE" },
	{ "uc_zep", "tarren_mill",      mode = "flight", dist = 2200, faction = "HORDE" },
	{ "uc_zep", "hammerfall",       mode = "flight", dist = 3300, faction = "HORDE" },
	{ "uc_zep", "kargath",          mode = "flight", dist = 4900, faction = "HORDE" },
	{ "uc_zep", "lights_hope",      mode = "flight", dist = 3600, faction = "HORDE" },
	{ "kargath", "thorium_point",   mode = "flight", dist = 1200, faction = "HORDE" },
	{ "kargath", "bb_dock",         mode = "flight", dist = 4600, faction = "HORDE" },
	{ "gromgol_zep", "bb_dock",     mode = "flight", dist = 1800, faction = "HORDE" },
	{ "org_zep", "crossroads",      mode = "flight", dist = 1700, faction = "HORDE" },
	{ "org_zep", "splintertree",    mode = "flight", dist = 1850, faction = "HORDE" },
	{ "org_zep", "thunder_bluff",   mode = "flight", dist = 3200, faction = "HORDE" },
	{ "org_zep", "gadgetzan",       mode = "flight", dist = 5400, faction = "HORDE" },
	{ "org_zep", "everlook",        mode = "flight", dist = 3800, faction = "HORDE" },
	{ "crossroads", "ratchet_dock", mode = "flight", dist = 900,  faction = "HORDE" },
	{ "crossroads", "camp_taurajo", mode = "flight", dist = 1200, faction = "HORDE" },
	{ "crossroads", "freewind_post",mode = "flight", dist = 2800, faction = "HORDE" },
	{ "darnassus", "auberdine_dock",mode = "flight", dist = 1200, faction = "ALLIANCE" },
	{ "auberdine_dock", "astranaar",mode = "flight", dist = 1750, faction = "ALLIANCE" },
	{ "auberdine_dock", "theramore_dock", mode = "flight", dist = 5200, faction = "ALLIANCE" },
	{ "auberdine_dock", "feathermoon", mode = "flight", dist = 5400, faction = "ALLIANCE" },
	{ "auberdine_dock", "nijels_point", mode = "flight", dist = 3800, faction = "ALLIANCE" },
	{ "auberdine_dock", "everlook", mode = "flight", dist = 3600, faction = "ALLIANCE" },
	{ "theramore_dock", "gadgetzan",mode = "flight", dist = 2600, faction = "ALLIANCE" },
	{ "gadgetzan", "marshals_refuge", mode = "flight", dist = 1700, faction = "NEUTRAL" },
	{ "marshals_refuge", "cenarion_hold", mode = "flight", dist = 1600, faction = "NEUTRAL" },

	-- Boat & Zeppelin Crossings (costs dynamically include guild-synced wait time!)
	{ "bb_dock", "ratchet_dock",      mode = "boat",     routeId = "booty_ratchet",      faction = "NEUTRAL" },
	{ "menethil_dock", "auberdine_dock", mode = "boat",  routeId = "menethil_auberdine", faction = "ALLIANCE" },
	{ "menethil_dock", "theramore_dock", mode = "boat",  routeId = "menethil_theramore", faction = "ALLIANCE" },
	{ "org_zep", "uc_zep",            mode = "zeppelin", routeId = "org_uc_zep",         faction = "HORDE" },
	{ "org_zep", "gromgol_zep",       mode = "zeppelin", routeId = "org_gg_zep",         faction = "HORDE" },
	{ "uc_zep", "gromgol_zep",        mode = "zeppelin", routeId = "uc_gg_zep",          faction = "HORDE" },
}

-- ============================================================================
-- PERSISTENT STORAGE (Discovered Flight Points + Guild-Synced Ship Timers)
-- ============================================================================
function PluribusHivePathfinder:GetDB()
	local db = PluribusHive:GetDB()
	db.pathfinder = db.pathfinder or {
		discoveredFP = {},     -- [charKey] = { [nodeId] = true }
		shipTimers = {},       -- [routeId] = { lastSeenAt = ts, reporter = name, synced = bool }
		shipDurations = {},    -- [routeId] = { avgSailSec = n, samples = n, avgCycleSec = n|nil, cycleSamples = n, updatedAt = ts, reporter = name }
		flightTimes = {},      -- ["from->to"] = { avgSec = n, samples = n, updatedAt = ts, reporter = name }
		routeCache = {},       -- [cacheKey] = { startNode, endNode, profileHash, legs, coreEtaSec, avoidsHazard, generation, improvedCount, computedAt, hasShip }
		edgeObservations = {}, -- [edgeKey] = { avgFactor = 1.0, samples = 0, updatedAt = ts }
		cacheMeta = { generation = 1, totalImprovements = 0, totalPrecomputed = 0, lastRefineAt = 0 },
	}
	local pdb = db.pathfinder
	pdb.discoveredFP = pdb.discoveredFP or {}
	pdb.shipTimers = pdb.shipTimers or {}
	pdb.shipDurations = pdb.shipDurations or {}
	pdb.flightTimes = pdb.flightTimes or {}
	pdb.routeCache = pdb.routeCache or {}
	pdb.edgeObservations = pdb.edgeObservations or {}
	pdb.cacheMeta = pdb.cacheMeta or { generation = 1, totalImprovements = 0, totalPrecomputed = 0, lastRefineAt = 0 }
	return pdb
end

local function CanonicalEdgeKey(u, v)
	u, v = tostring(u or ""), tostring(v or "")
	if u <= v then return u .. ":" .. v end
	return v .. ":" .. u
end

function PluribusHivePathfinder:GetObservedEdgeFactor(u, v)
	local pdb = self:GetDB()
	local obs = pdb.edgeObservations and pdb.edgeObservations[CanonicalEdgeKey(u, v)]
	if obs and obs.avgFactor and (obs.samples or 0) > 0 then
		return math.max(0.45, math.min(2.20, obs.avgFactor))
	end
	return 1.0
end

-- Self-learning travel telemetry: blends actual measured leg duration into the edge weight (clamped against AFK outliers)
function PluribusHivePathfinder:RecordObservedEdgeTime(fromNodeId, toNodeId, actualSec, expectedSec, broadcast)
	if not fromNodeId or not toNodeId or fromNodeId == toNodeId then return false end
	actualSec = tonumber(actualSec) or 0
	expectedSec = tonumber(expectedSec) or 0
	if actualSec < 3 or expectedSec < 3 then return false end
	local rawRatio = actualSec / expectedSec
	-- Reject extreme AFK pauses (>2.6x) or teleports/hearths (<0.35x) so observations stay clean
	if rawRatio < 0.35 or rawRatio > 2.60 then return false end
	local ratio = math.max(0.45, math.min(2.20, rawRatio))

	local pdb = self:GetDB()
	local key = CanonicalEdgeKey(fromNodeId, toNodeId)
	local rec = pdb.edgeObservations[key] or { avgFactor = 1.0, samples = 0, updatedAt = 0 }
	local n = math.min(20, rec.samples or 0)
	rec.avgFactor = math.floor((((rec.avgFactor or 1.0) * n + ratio) / (n + 1)) * 1000 + 0.5) / 1000
	rec.samples = (rec.samples or 0) + 1
	rec.updatedAt = time()
	pdb.edgeObservations[key] = rec

	if broadcast and PluribusHive and PluribusHive.SendBackground then
		local payload = string.format("%s|%s|%.3f", tostring(fromNodeId), tostring(toNodeId), rec.avgFactor)
		PluribusHive:SendBackground("EDGETIME", payload, "EDGE:" .. key, "GUILD")
	end
	self:ScheduleRouteRefinement("observed_travel")
	return true
end

function PluribusHivePathfinder:GetProfileHash(faction, playerLevel, speeds, discoveredFP, avoidHigh)
	local fpKeys = {}
	for k, v in pairs(discoveredFP or {}) do
		if v then table.insert(fpKeys, k) end
	end
	table.sort(fpKeys)
	local lvlBucket = math.floor((tonumber(playerLevel) or 60) / 3)
	local lSpd = math.floor((speeds and speeds.landSpeed or BASE_RUN_SPEED) * 10 + 0.5)
	local wSpd = math.floor((speeds and speeds.waterSpeed or BASE_SWIM_SPEED) * 10 + 0.5)
	return string.format("%s|%d|%d|%d|%d|%s",
		tostring(faction or "ALLIANCE"),
		lvlBucket,
		lSpd,
		wSpd,
		avoidHigh and 1 or 0,
		table.concat(fpKeys, ","))
end

function PluribusHivePathfinder:GetCacheStats()
	local pdb = self:GetDB()
	local count = 0
	for _ in pairs(pdb.routeCache or {}) do count = count + 1 end
	local obsCount = 0
	for _ in pairs(pdb.edgeObservations or {}) do obsCount = obsCount + 1 end
	local flightCount = 0
	for _ in pairs(pdb.flightTimes or {}) do flightCount = flightCount + 1 end
	local shipDurCount = 0
	for _ in pairs(pdb.shipDurations or {}) do shipDurCount = shipDurCount + 1 end
	local meta = pdb.cacheMeta or {}
	return {
		cachedRoutes = count,
		observedEdges = obsCount,
		recordedFlights = flightCount,
		recordedShips = shipDurCount,
		generation = meta.generation or 1,
		totalImprovements = meta.totalImprovements or 0,
		totalPrecomputed = meta.totalPrecomputed or 0,
		queueRemaining = math.max(0, #(self.precomputeQueue or {}) - (self.precomputeCursor or 1) + 1),
	}
end

function PluribusHivePathfinder:GetCharKey()
	local realm = PluribusHive and PluribusHive:GetRealmKey() or "Realm"
	local me = PluribusHive and PluribusHive:GetPlayerShortName() or "Player"
	return realm .. ":" .. me
end

function PluribusHivePathfinder:GetPlayerFaction()
	if UnitFactionGroup then
		local f = UnitFactionGroup("player")
		if f then return string.upper(f) end
	end
	return "ALLIANCE"
end

function PluribusHivePathfinder:GetDiscoveredFlightPoints()
	local pdb = self:GetDB()
	local ck = self:GetCharKey()
	pdb.discoveredFP[ck] = pdb.discoveredFP[ck] or {}
	return pdb.discoveredFP[ck]
end

function PluribusHivePathfinder:MatchFlightNodeByName(rawName)
	if not rawName or rawName == "" then return nil, nil end
	local low = tostring(rawName):lower()
	for nodeId, node in pairs(self.NODES) do
		if node.fpNames then
			for _, pat in ipairs(node.fpNames) do
				if low:find(pat, 1, true) then
					return nodeId, node.label
				end
			end
		end
	end
	return nil, nil
end

function PluribusHivePathfinder:RecordFlightPointByName(rawName)
	local nodeId, label = self:MatchFlightNodeByName(rawName)
	if not nodeId then return false end
	local fpMap = self:GetDiscoveredFlightPoints()
	local wasNew = not fpMap[nodeId]
	fpMap[nodeId] = true
	return wasNew, label, nodeId
end

function PluribusHivePathfinder:ScanOpenTaxiMap()
	if not NumTaxiNodes or not TaxiNodeName then return 0 end
	local count = NumTaxiNodes() or 0
	local newlyFound = 0
	self._taxiOriginNode = nil
	for i = 1, count do
		local nType = TaxiNodeGetType and TaxiNodeGetType(i) or "REACHABLE"
		if nType == "CURRENT" or nType == "REACHABLE" then
			local name = TaxiNodeName(i)
			local isNew, _, nodeId = self:RecordFlightPointByName(name)
			if isNew then newlyFound = newlyFound + 1 end
			if nType == "CURRENT" and nodeId then
				self._taxiOriginNode = nodeId
			end
		end
	end
	return newlyFound
end

-- ============================================================================
-- RECORDED ACTUAL FLIGHT & SHIP TRAVEL TIMES (FLIGHTTIME / SHIPTIME over PLBHIVE)
-- ============================================================================
function PluribusHivePathfinder:RecordFlightTime(fromNodeId, toNodeId, durationSec, reporter, broadcast, skipRefine)
	if not fromNodeId or not toNodeId or fromNodeId == toNodeId then return false end
	if not (self.NODES[fromNodeId] and self.NODES[toNodeId]) then return false end
	durationSec = math.floor((tonumber(durationSec) or 0) + 0.5)
	-- Sanity bounds: reject instant cancels (<10s) or disconnect pauses (>25m)
	if durationSec < 10 or durationSec > 1500 then return false end

	local pdb = self:GetDB()
	local key = tostring(fromNodeId) .. "->" .. tostring(toNodeId)
	local rec = pdb.flightTimes[key]
	if rec and rec.avgSec and (rec.samples or 0) > 0 then
		-- Reject extreme outliers (>2.5x or <0.4x of established guild average)
		local ratio = durationSec / math.max(1, rec.avgSec)
		if ratio < 0.40 or ratio > 2.50 then return false end
		local n = math.min(20, rec.samples or 0)
		rec.avgSec = math.floor(((rec.avgSec * n + durationSec) / (n + 1)) + 0.5)
		rec.samples = (rec.samples or 0) + 1
		rec.updatedAt = time()
		rec.reporter = reporter or PluribusHive:GetPlayerShortName()
	else
		pdb.flightTimes[key] = {
			avgSec = durationSec,
			samples = 1,
			updatedAt = time(),
			reporter = reporter or PluribusHive:GetPlayerShortName(),
		}
	end

	local stored = pdb.flightTimes[key]
	if broadcast and PluribusHive and PluribusHive.SendBackground then
		local payload = string.format("%s|%s|%d|%d", tostring(fromNodeId), tostring(toNodeId), stored.avgSec, stored.samples or 1)
		PluribusHive:SendBackground("FLIGHTTIME", payload, "FT:" .. key, "GUILD")
	end
	if not skipRefine then
		self:ScheduleRouteRefinement("flight_time")
	end
	return true, stored.avgSec
end

-- Returns flightSec, isMeasured (uses directed measurement first, then reverse pair, then distance estimate)
function PluribusHivePathfinder:GetFlightDurationSec(fromNodeId, toNodeId, fallbackDist)
	local pdb = self:GetDB()
	local ft = pdb.flightTimes
	if ft then
		local direct = ft[tostring(fromNodeId) .. "->" .. tostring(toNodeId)]
		if direct and direct.avgSec and direct.avgSec >= 10 then
			return direct.avgSec, true
		end
		local rev = ft[tostring(toNodeId) .. "->" .. tostring(fromNodeId)]
		if rev and rev.avgSec and rev.avgSec >= 10 then
			return rev.avgSec, true
		end
	end
	return math.floor(((fallbackDist or 2000) / FLIGHT_SPEED) + 8 + 0.5), false
end

function PluribusHivePathfinder:RecordShipDuration(routeId, sailSec, cycleSec, reporter, broadcast, skipRefine)
	local route = self.SHIP_ROUTES[routeId]
	if not route then return false end
	sailSec = tonumber(sailSec)
	cycleSec = tonumber(cycleSec)

	local baseSail = route.sailSec or 60
	local baseCycle = route.cycleSec or 180
	local validSail = sailSec and sailSec >= 20 and sailSec <= 240 and (sailSec / baseSail) >= 0.45 and (sailSec / baseSail) <= 2.20
	local validCycle = cycleSec and cycleSec >= 60 and cycleSec <= 600 and (cycleSec / baseCycle) >= 0.70 and (cycleSec / baseCycle) <= 1.35
	if not validSail and not validCycle then return false end

	local pdb = self:GetDB()
	local rec = pdb.shipDurations[routeId] or {
		avgSailSec = baseSail,
		samples = 0,
		avgCycleSec = nil,
		cycleSamples = 0,
		updatedAt = 0,
		reporter = reporter or PluribusHive:GetPlayerShortName(),
	}

	if validSail then
		local n = math.min(20, rec.samples or 0)
		local prev = (rec.samples or 0) > 0 and rec.avgSailSec or sailSec
		rec.avgSailSec = math.floor(((prev * n + sailSec) / (n + 1)) + 0.5)
		rec.samples = (rec.samples or 0) + 1
	end
	if validCycle then
		local cn = math.min(20, rec.cycleSamples or 0)
		local prevC = (rec.cycleSamples or 0) > 0 and rec.avgCycleSec or cycleSec
		rec.avgCycleSec = math.floor(((prevC * cn + cycleSec) / (cn + 1)) + 0.5)
		rec.cycleSamples = (rec.cycleSamples or 0) + 1
	end
	rec.updatedAt = time()
	rec.reporter = reporter or PluribusHive:GetPlayerShortName()
	pdb.shipDurations[routeId] = rec

	if broadcast and PluribusHive and PluribusHive.SendBackground then
		local payload = string.format("%s|%d|%d|%d",
			tostring(routeId),
			rec.avgSailSec or baseSail,
			rec.avgCycleSec or 0,
			rec.samples or 1
		)
		PluribusHive:SendBackground("SHIPTIME", payload, "ST:" .. tostring(routeId), "GUILD")
	end
	if not skipRefine then
		self:ScheduleRouteRefinement("ship_time")
	end
	return true, rec.avgSailSec, rec.avgCycleSec
end

function PluribusHivePathfinder:GetShipDurationSec(routeId)
	local route = self.SHIP_ROUTES[routeId]
	local baseSail = route and route.sailSec or 60
	local baseCycle = route and route.cycleSec or 180
	local pdb = self:GetDB()
	local rec = pdb.shipDurations and pdb.shipDurations[routeId]
	local sail = (rec and (rec.samples or 0) > 0 and rec.avgSailSec) or baseSail
	local cycle = (rec and (rec.cycleSamples or 0) > 0 and rec.avgCycleSec) or baseCycle
	local measured = (rec and ((rec.samples or 0) > 0 or (rec.cycleSamples or 0) > 0)) == true
	return sail, cycle, measured
end

-- Share a compact batch of measured flight & boat/zeppelin travel times when guild peers sync
function PluribusHivePathfinder:ShareRecordedTransitTimes()
	if not (PluribusHive and PluribusHive.SendBackground) then return 0 end
	local pdb = self:GetDB()
	local fEntries = {}
	for key, rec in pairs(pdb.flightTimes or {}) do
		if rec and rec.avgSec and rec.avgSec >= 10 then
			local u, v = key:match("^(.-)%->(.+)$")
			if u and v and u ~= "" and v ~= "" then
				table.insert(fEntries, string.format("%s>%s=%d", u, v, rec.avgSec))
				if #fEntries >= 18 then break end
			end
		end
	end
	if #fEntries > 0 then
		PluribusHive:SendBackground("TRANSITBATCH", "F|" .. table.concat(fEntries, ","), "TB:F", "GUILD")
	end
	local sEntries = {}
	for rid, rec in pairs(pdb.shipDurations or {}) do
		if rec and ((rec.samples or 0) > 0 or (rec.cycleSamples or 0) > 0) then
			table.insert(sEntries, string.format("%s=%d:%d", rid, rec.avgSailSec or 0, rec.avgCycleSec or 0))
		end
	end
	if #sEntries > 0 then
		PluribusHive:SendBackground("TRANSITBATCH", "S|" .. table.concat(sEntries, ","), "TB:S", "GUILD")
	end
	return #fEntries + #sEntries
end

-- ============================================================================
-- GUILD-SYNCED BOAT & ZEPPELIN TIMERS (SHIPSYNC over PLBHIVE)
-- ============================================================================
function PluribusHivePathfinder:RecordShipSighting(routeId, timestamp, reporter, broadcast)
	local route = self.SHIP_ROUTES[routeId]
	if not route then return end
	local pdb = self:GetDB()
	local ts = tonumber(timestamp) or time()
	local existing = pdb.shipTimers[routeId]
	if existing and (existing.lastSeenAt or 0) >= ts then
		return
	end
	-- If we have a recent previous sighting ~1 full cycle earlier, refine the measured cycle duration!
	if existing and existing.lastSeenAt and ts > existing.lastSeenAt then
		local delta = ts - existing.lastSeenAt
		local baseCycle = route.cycleSec or 180
		if delta >= (baseCycle * 0.75) and delta <= (baseCycle * 1.25) then
			self:RecordShipDuration(routeId, nil, delta, reporter, broadcast)
		end
	end
	pdb.shipTimers[routeId] = {
		lastSeenAt = ts,
		reporter = reporter or PluribusHive:GetPlayerShortName(),
		synced = true,
	}
	if broadcast and PluribusHive and PluribusHive.Send then
		PluribusHive:Send("SHIPSYNC", string.format("%s|%d", routeId, ts), "GUILD")
	end
end

-- Returns waitSec, sailSec, isGuildSynced
function PluribusHivePathfinder:GetShipTiming(routeId, nowSec)
	local route = self.SHIP_ROUTES[routeId]
	if not route then return 90, 60, false end
	local now = nowSec or time()
	local sailSec, cycleSec, hasMeasuredDur = self:GetShipDurationSec(routeId)
	local pdb = self:GetDB()
	local rec = pdb.shipTimers[routeId]
	if rec and rec.lastSeenAt and (now - rec.lastSeenAt) < 14400 then -- Valid for 4h of guild sightings
		local elapsed = math.max(0, now - rec.lastSeenAt)
		local phase = elapsed % cycleSec
		local waitSec = (phase < 18) and 0 or (cycleSec - phase)
		return math.floor(waitSec), sailSec, true
	end
	-- Fallback: expected average wait = half cycle when no guildmate has spotted the ship recently
	return math.floor(cycleSec * 0.5), sailSec, hasMeasuredDur
end

-- ============================================================================
-- DYNAMIC SPEED MODEL (Mount / Travel Form / Ghost Wolf / Aquatic Form "Robbe" / Hook)
-- ============================================================================
function PluribusHivePathfinder:GetMovementSpeeds()
	local landSpeed = BASE_RUN_SPEED
	local waterSpeed = BASE_SWIM_SPEED
	local landTag = "Fuß"
	local waterTag = "Schwimmen"

	local lvl = (UnitLevel and UnitLevel("player")) or 60
	local cls = (PluribusHive and PluribusHive:GetPlayerClass()) or "WARRIOR"

	-- Live UnitSpeed check (captures active mounts & buffs accurately!)
	if GetUnitSpeed then
		local ok, cur, run, _, swim = pcall(GetUnitSpeed, "player")
		if ok then
			if tonumber(run) and run > landSpeed then landSpeed = run end
			if tonumber(cur) and cur > landSpeed then landSpeed = cur end
			if tonumber(swim) and swim > waterSpeed then waterSpeed = swim end
		end
	end

	-- Inspect active buffs/forms (DE + EN) for Travel Form, Aquatic Form ("Robbe"), Ghost Wolf, Cheetah, Mounts, Swim Speed
	if UnitBuff then
		for i = 1, 32 do
			local ok, bName = pcall(UnitBuff, "player", i)
			if not ok or not bName then break end
			local low = tostring(bName):lower()
			if low:find("aquatic", 1, true) or low:find("wassergestalt", 1, true) or low:find("swim", 1, true) or low:find("schwimm", 1, true) then
				waterSpeed = math.max(waterSpeed, BASE_RUN_SPEED * 1.50)
				waterTag = "Wassergestalt/Robbe"
			elseif low:find("travel form", 1, true) or low:find("reisegestalt", 1, true) or low:find("ghost wolf", 1, true) or low:find("geisterwolf", 1, true) then
				landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.40)
				landTag = "Reisegestalt/Wolf"
			elseif low:find("cheetah", 1, true) or low:find("gepard", 1, true) or low:find("pack", 1, true) then
				landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.30)
				landTag = "Gepard"
			end
		end
	end

	-- Class / Level inherent capabilities even while currently standing indoors/unmounted
	if cls == "DRUID" and lvl >= 16 then
		waterSpeed = math.max(waterSpeed, BASE_RUN_SPEED * 1.50) -- Druid can shift to Aquatic Form ("Robbe") anytime!
		waterTag = "Wassergestalt (Robbe)"
		if lvl >= 30 then
			landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.40)
			if landTag == "Fuß" then landTag = "Reisegestalt" end
		end
	elseif cls == "SHAMAN" and lvl >= 20 then
		landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.40)
		if landTag == "Fuß" then landTag = "Geisterwolf" end
	elseif cls == "HUNTER" and lvl >= 20 then
		landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.30)
		if landTag == "Fuß" then landTag = "Aspekt des Geparden" end
	end

	-- Check equipped Fishing Pole / Hydrocane / Azure Silk Belt / Swim Hook in bags/equipped
	if GetInventoryItemID then
		local mh = GetInventoryItemID("player", 16)
		local waist = GetInventoryItemID("player", 6)
		if mh == 9452 or waist == 7052 then -- Hydrocane or Azure Silk Belt
			waterSpeed = math.max(waterSpeed, BASE_RUN_SPEED * 1.25)
			waterTag = "Schwimm-Item"
		end
	end

	-- Mount availability heuristic from IsMounted or Classic mount levels
	if IsMounted and IsMounted() then
		if landSpeed >= BASE_RUN_SPEED * 1.9 then
			landTag = "100% Mount"
		else
			landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.60)
			landTag = "60% Mount"
		end
	elseif lvl >= 60 then
		landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.85)
		landTag = "Mount"
	elseif lvl >= 40 then
		landSpeed = math.max(landSpeed, BASE_RUN_SPEED * 1.60)
		landTag = "60% Mount"
	end

	return {
		landSpeed = landSpeed,
		waterSpeed = waterSpeed,
		landTag = landTag,
		waterTag = waterTag,
	}
end

-- ============================================================================
-- DIJKSTRA MULTI-MODAL SHORTEST-TIME PATHFINDER (WITH HAZARD AVOIDANCE)
-- ============================================================================
local function NodeDistanceYards(ax, ay, bx, by, zoneName)
	if _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.DistanceYards and zoneName and zoneName ~= "" then
		return _G.PluribusHiveTerrainMesh:DistanceYards(zoneName, ax, ay, bx, by)
	end
	local dx = (bx or 50) - (ax or 50)
	local dy = (by or 50) - (ay or 50)
	return math.sqrt(dx * dx + dy * dy) * 28
end

function PluribusHivePathfinder:DistanceYards(zoneName, ax, ay, bx, by)
	return NodeDistanceYards(ax, ay, bx, by, zoneName)
end

-- Exact 2D segment intersection test (detects straight-line paths crossing mountain ridges, cliffs, or city walls)
local function Orient2D(ax, ay, bx, by, cx, cy)
	return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
end

local function OnSegment2D(ax, ay, bx, by, px, py)
	return px >= math.min(ax, bx) - 1e-6 and px <= math.max(ax, bx) + 1e-6
		and py >= math.min(ay, by) - 1e-6 and py <= math.max(ay, by) + 1e-6
end

function PluribusHivePathfinder:SegmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)
	local o1 = Orient2D(ax, ay, bx, by, cx, cy)
	local o2 = Orient2D(ax, ay, bx, by, dx, dy)
	local o3 = Orient2D(cx, cy, dx, dy, ax, ay)
	local o4 = Orient2D(cx, cy, dx, dy, bx, by)
	if ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0)) then
		return true
	end
	if math.abs(o1) < 1e-6 and OnSegment2D(ax, ay, bx, by, cx, cy) then return true end
	if math.abs(o2) < 1e-6 and OnSegment2D(ax, ay, bx, by, dx, dy) then return true end
	if math.abs(o3) < 1e-6 and OnSegment2D(cx, cy, dx, dy, ax, ay) then return true end
	if math.abs(o4) < 1e-6 and OnSegment2D(cx, cy, dx, dy, bx, by) then return true end
	return false
end

-- Real Classic Azeroth Intra-Zone Road Networks (junctions, bends, bridges, gates, mountain passes)
-- Each zone defines: nodes = { id = {x, y, label} }, edges = { {id1, id2} }
PluribusHivePathfinder.ZONE_ROADS = {
	["Elwynn Forest"] = {
		nodes = {
			sw_gate      = { x = 32.0, y = 49.5, label = "Stormwind Tor" },
			sw_road_bend = { x = 36.2, y = 57.5, label = "Straße nach Goldhain" },
			goldshire    = { x = 42.1, y = 65.9, label = "Goldhain Kreuzung" },
			northshire_j = { x = 48.2, y = 54.0, label = "Nordhain-Abzweigung" },
			northshire   = { x = 48.8, y = 42.5, label = "Abtei von Nordhain" },
			west_road    = { x = 33.5, y = 71.0, label = "Westfall-Straße" },
			west_bridge  = { x = 24.5, y = 74.5, label = "Westfall-Brücke" },
			east_road1   = { x = 55.0, y = 67.5, label = "Oststraße (Holzfällerlager)" },
			tower_azora  = { x = 64.5, y = 69.0, label = "Turm von Azora Straße" },
			eastvale     = { x = 77.5, y = 68.5, label = "Holzfällerlager Osttal" },
			redridge_pass= { x = 85.5, y = 70.5, label = "Rotkamm-Pass" },
			dusk_bridge  = { x = 43.2, y = 89.0, label = "Dämmerwald-Brücke" },
		},
		edges = {
			{ "sw_gate", "sw_road_bend" }, { "sw_road_bend", "goldshire" },
			{ "goldshire", "northshire_j" }, { "northshire_j", "northshire" },
			{ "goldshire", "west_road" }, { "west_road", "west_bridge" },
			{ "goldshire", "east_road1" }, { "east_road1", "tower_azora" },
			{ "tower_azora", "eastvale" }, { "eastvale", "redridge_pass" },
			{ "goldshire", "dusk_bridge" },
		},
	},
	["Stormwind City"] = {
		nodes = {
			gates      = { x = 66.2, y = 76.5, label = "Stadttor Sturmwind" },
			valley     = { x = 61.5, y = 71.0, label = "Tal der Helden" },
			trade      = { x = 56.5, y = 62.0, label = "Handelsdistrikt" },
			ah         = { x = 53.6, y = 59.8, label = "Auktionshaus" },
			canal_n    = { x = 51.0, y = 52.0, label = "Kanalbrücke Nord" },
			cathedral  = { x = 47.0, y = 44.0, label = "Kathedralenplatz" },
			mage_q     = { x = 43.5, y = 69.5, label = "Magierviertel" },
			dwarven    = { x = 61.0, y = 38.0, label = "Zwergendistrikt" },
			old_town   = { x = 71.5, y = 56.5, label = "Altstadt" },
			keep_bridge= { x = 74.5, y = 42.5, label = "Burgbrücke" },
		},
		edges = {
			{ "gates", "valley" }, { "valley", "trade" }, { "trade", "ah" },
			{ "trade", "canal_n" }, { "canal_n", "cathedral" }, { "canal_n", "dwarven" },
			{ "trade", "mage_q" }, { "trade", "old_town" }, { "old_town", "keep_bridge" },
			{ "dwarven", "keep_bridge" },
		},
	},
	["Westfall"] = {
		nodes = {
			elwynn_br  = { x = 62.0, y = 18.5, label = "Brücke nach Elwynn" },
			furlbrow   = { x = 57.0, y = 34.0, label = "Nordstraße Westfall" },
			sentinel   = { x = 56.5, y = 52.6, label = "Späherkuppe" },
			moonbrook  = { x = 45.0, y = 66.0, label = "Mondbruch-Straße" },
			deadmines  = { x = 42.6, y = 71.7, label = "Todesminen-Eingang" },
			dusk_road  = { x = 65.5, y = 62.0, label = "Straße nach Dämmerwald" },
			lighthouse = { x = 35.0, y = 83.5, label = "Südstraße Leuchtturm" },
		},
		edges = {
			{ "elwynn_br", "furlbrow" }, { "furlbrow", "sentinel" },
			{ "sentinel", "moonbrook" }, { "moonbrook", "deadmines" },
			{ "sentinel", "dusk_road" }, { "moonbrook", "lighthouse" },
		},
	},
	["Redridge Mountains"] = {
		nodes = {
			west_pass   = { x = 10.0, y = 72.0, label = "Elwynn-Pass" },
			three_corn  = { x = 18.5, y = 65.0, label = "Drei-Ecken-Kreuzung" },
			lake_bridge = { x = 29.5, y = 52.0, label = "Seenhain-Brücke" },
			lakeshire   = { x = 30.6, y = 46.5, label = "Seenhain" },
			north_road  = { x = 36.5, y = 34.0, label = "Nordstraße Rotkamm" },
			brm_pass    = { x = 32.0, y = 12.0, label = "Pass zur Brennenden Steppe" },
			east_road   = { x = 52.0, y = 44.0, label = "Oststraße Steinschlag" },
			stonewatch  = { x = 66.0, y = 49.0, label = "Burg Steinwacht Straße" },
			dusk_pass   = { x = 15.0, y = 85.0, label = "Dämmerwald-Pass" },
		},
		edges = {
			{ "west_pass", "three_corn" }, { "three_corn", "dusk_pass" },
			{ "three_corn", "lake_bridge" }, { "lake_bridge", "lakeshire" },
			{ "lakeshire", "north_road" }, { "north_road", "brm_pass" },
			{ "lakeshire", "east_road" }, { "east_road", "stonewatch" },
		},
	},
	["Duskwood"] = {
		nodes = {
			darkshire   = { x = 77.5, y = 44.3, label = "Dunkelhain" },
			crossroads  = { x = 45.0, y = 46.5, label = "Dämmerwald-Kreuzung" },
			raven_hill  = { x = 22.0, y = 47.0, label = "Rabenflucht-Straße" },
			west_bridge = { x = 9.0,  y = 60.0, label = "Westfall-Straße" },
			north_bridge= { x = 44.0, y = 17.5, label = "Elwynn-Brücke" },
			south_road  = { x = 44.8, y = 86.2, label = "Schlingendorntal-Pass" },
			deadwind_p  = { x = 88.5, y = 46.0, label = "Gebirgspass der Totenwinde" },
		},
		edges = {
			{ "deadwind_p", "darkshire" }, { "darkshire", "crossroads" },
			{ "crossroads", "north_bridge" }, { "crossroads", "south_road" },
			{ "crossroads", "raven_hill" }, { "raven_hill", "west_bridge" },
		},
	},
	["Stranglethorn Vale"] = {
		nodes = {
			rebel_camp  = { x = 38.2, y = 4.2,  label = "Rebellenlager Straße" },
			nesingwary  = { x = 35.6, y = 11.5, label = "Nesingwary-Abzweigung" },
			kurzen_j    = { x = 40.5, y = 16.5, label = "Nordstraße Dschungel" },
			zg_junc     = { x = 43.2, y = 24.5, label = "Zul'Gurub-Abzweigung" },
			gromgol_j   = { x = 39.2, y = 31.5, label = "Grom'gol-Kreuzung" },
			gromgol     = { x = 31.6, y = 29.2, label = "Basislager Grom'gol" },
			arena_road  = { x = 33.8, y = 45.0, label = "Gurubashi-Straße" },
			mid_road    = { x = 34.5, y = 57.5, label = "Südstraße Schlingendorntal" },
			bb_tunnel   = { x = 30.8, y = 68.5, label = "Beutebucht-Tunnel" },
			bb_dock     = { x = 26.8, y = 73.6, label = "Beutebucht" },
		},
		edges = {
			{ "rebel_camp", "nesingwary" }, { "nesingwary", "kurzen_j" },
			{ "kurzen_j", "zg_junc" }, { "zg_junc", "gromgol_j" },
			{ "gromgol_j", "gromgol" }, { "gromgol_j", "arena_road" },
			{ "arena_road", "mid_road" }, { "mid_road", "bb_tunnel" },
			{ "bb_tunnel", "bb_dock" },
		},
	},
	["Dun Morogh"] = {
		nodes = {
			if_gates    = { x = 53.5, y = 35.5, label = "Eisenschmiede-Tor" },
			kharanos    = { x = 47.0, y = 52.5, label = "Kharanos" },
			brewnall    = { x = 33.5, y = 49.0, label = "Weststraße Gnomeregan" },
			gnomeregan  = { x = 24.0, y = 39.8, label = "Gnomeregan-Eingang" },
			amberstill  = { x = 63.0, y = 50.5, label = "Oststraße Gehöft" },
			golbolar    = { x = 70.5, y = 54.0, label = "Steinbruch-Straße" },
			north_gate  = { x = 82.0, y = 38.0, label = "Nordtor-Pass (Loch Modan)" },
			south_gate  = { x = 84.5, y = 51.5, label = "Südtor-Pass (Loch Modan)" },
		},
		edges = {
			{ "if_gates", "kharanos" }, { "kharanos", "brewnall" }, { "brewnall", "gnomeregan" },
			{ "kharanos", "amberstill" }, { "amberstill", "golbolar" },
			{ "golbolar", "north_gate" }, { "golbolar", "south_gate" },
		},
	},
	["Tanaris"] = {
		nodes = {
			tn_pass     = { x = 51.0, y = 20.5, label = "Pass aus Tausend Nadeln" },
			gad_north   = { x = 51.2, y = 25.2, label = "Gadgetzan Nordtor" },
			gadgetzan   = { x = 51.0, y = 29.3, label = "Gadgetzan" },
			gad_east    = { x = 55.2, y = 28.5, label = "Gadgetzan Osttor" },
			steamwheedle= { x = 66.5, y = 23.5, label = "Dampfdruckpier-Straße" },
			zf_road     = { x = 43.0, y = 24.0, label = "Zul'Farrak-Straße" },
			zf_gate     = { x = 38.7, y = 20.0, label = "Zul'Farrak-Eingang" },
			mid_desert  = { x = 51.5, y = 43.5, label = "Zentralstraße Tanaris" },
			caverns_j   = { x = 58.0, y = 50.0, label = "Höhlen der Zeit Straße" },
			ungoro_road = { x = 37.0, y = 49.0, label = "Weststraße Un'Goro" },
			ungoro_pass = { x = 27.5, y = 57.5, label = "Un'Goro-Krater-Pass" },
			south_dunes = { x = 50.5, y = 64.0, label = "Südstraße Disteltal" },
			ulda_south  = { x = 45.0, y = 78.0, label = "Südpiste Uldum" },
		},
		edges = {
			{ "tn_pass", "gad_north" }, { "gad_north", "gadgetzan" },
			{ "gadgetzan", "gad_east" }, { "gad_east", "steamwheedle" },
			{ "gad_north", "zf_road" }, { "zf_road", "zf_gate" },
			{ "gad_east", "mid_desert" }, { "mid_desert", "caverns_j" },
			{ "mid_desert", "ungoro_road" }, { "ungoro_road", "ungoro_pass" },
			{ "mid_desert", "south_dunes" }, { "south_dunes", "ulda_south" },
		},
	},
	["Thousand Needles"] = {
		nodes = {
			great_lift  = { x = 32.0, y = 23.0, label = "Der Große Aufzug" },
			west_canyon = { x = 24.5, y = 34.0, label = "West-Canyon Straße" },
			feralas_pass= { x = 8.5,  y = 14.0, label = "Feralas-Pass" },
			mid_canyon  = { x = 44.5, y = 49.0, label = "Freiwindposten-Straße" },
			east_canyon = { x = 63.0, y = 56.0, label = "Ost-Canyon Straße" },
			shimmering  = { x = 77.5, y = 74.0, label = "Schimmernde Ebene" },
			tanaris_pass= { x = 75.0, y = 94.0, label = "Tanaris-Pass" },
		},
		edges = {
			{ "great_lift", "west_canyon" }, { "west_canyon", "feralas_pass" },
			{ "great_lift", "mid_canyon" }, { "mid_canyon", "east_canyon" },
			{ "east_canyon", "shimmering" }, { "shimmering", "tanaris_pass" },
		},
	},
	["The Barrens"] = {
		nodes = {
			ashen_pass  = { x = 49.0, y = 7.5,  label = "Eschental-Pass" },
			durotar_br  = { x = 62.0, y = 21.0, label = "Südfury-Brücke (Durotar)" },
			crossroads  = { x = 51.5, y = 30.3, label = "Das Wegekreuz" },
			ratchet_rd  = { x = 58.0, y = 34.5, label = "Ratschet-Straße" },
			ratchet     = { x = 63.1, y = 37.2, label = "Ratschet" },
			stonetalon_p= { x = 36.5, y = 28.0, label = "Steinkrallen-Pass" },
			gold_road_m = { x = 48.0, y = 46.5, label = "Goldstraße Mitte" },
			taurajo     = { x = 44.5, y = 59.1, label = "Camp Taurajo" },
			mulgore_pass= { x = 36.5, y = 59.5, label = "Mulgore-Tor" },
			dustwallow_p= { x = 51.5, y = 67.5, label = "Düstermarschen-Pass" },
			south_road  = { x = 45.5, y = 76.5, label = "Südstraße Brachland" },
			great_lift_n= { x = 44.2, y = 89.5, label = "Großer Aufzug (Tausend Nadeln)" },
		},
		edges = {
			{ "ashen_pass", "crossroads" }, { "durotar_br", "crossroads" },
			{ "crossroads", "ratchet_rd" }, { "ratchet_rd", "ratchet" },
			{ "crossroads", "stonetalon_p" }, { "crossroads", "gold_road_m" },
			{ "gold_road_m", "taurajo" }, { "taurajo", "mulgore_pass" },
			{ "taurajo", "dustwallow_p" }, { "taurajo", "south_road" },
			{ "south_road", "great_lift_n" },
		},
	},
	["Feralas"] = {
		nodes = {
			tn_pass     = { x = 88.0, y = 44.5, label = "Tausend-Nadeln-Pass" },
			mojache     = { x = 75.5, y = 44.5, label = "Camp Mojache" },
			mid_road    = { x = 60.5, y = 49.5, label = "Zentralstraße Feralas" },
			dm_junc     = { x = 59.5, y = 44.5, label = "Düsterbruch-Abzweigung" },
			desolace_p  = { x = 44.5, y = 11.5, label = "Desolace-Pass" },
			twin_col    = { x = 46.0, y = 32.0, label = "Nordstraße Zwillingskolosse" },
			west_road   = { x = 45.5, y = 46.5, label = "Weststraße Mondfeder" },
			ferry_dock  = { x = 43.5, y = 43.0, label = "Mondfeder-Fähre" },
			feathermoon = { x = 30.2, y = 43.2, label = "Mondfederfeste" },
		},
		edges = {
			{ "tn_pass", "mojache" }, { "mojache", "mid_road" },
			{ "mid_road", "dm_junc" }, { "mid_road", "west_road" },
			{ "west_road", "twin_col" }, { "twin_col", "desolace_p" },
			{ "west_road", "ferry_dock" }, { "ferry_dock", "feathermoon" },
		},
	},
	["Badlands"] = {
		nodes = {
			loch_pass   = { x = 51.0, y = 11.0, label = "Loch-Modan-Pass" },
			ulda_road   = { x = 44.0, y = 21.0, label = "Uldaman-Abzweigung" },
			ulda_gate   = { x = 42.5, y = 13.4, label = "Uldaman-Eingang" },
			mid_road    = { x = 35.0, y = 39.0, label = "Ödland-Hauptstraße" },
			kargath     = { x = 4.0,  y = 44.8, label = "Kargath" },
			sg_pass     = { x = 5.5,  y = 61.5, label = "Pass zur Sengenden Schlucht" },
			east_road   = { x = 62.0, y = 45.0, label = "Oststraße Ödland" },
		},
		edges = {
			{ "loch_pass", "ulda_road" }, { "ulda_road", "ulda_gate" },
			{ "ulda_road", "mid_road" }, { "mid_road", "kargath" },
			{ "kargath", "sg_pass" }, { "mid_road", "east_road" },
		},
	},
	["Searing Gorge"] = {
		nodes = {
			badlands_p  = { x = 76.0, y = 78.0, label = "Ödland-Pass" },
			east_rim    = { x = 64.0, y = 55.0, label = "Ostrand Kessel" },
			north_rim   = { x = 48.0, y = 26.5, label = "Nordstraße Thoriumspitze" },
			thorium     = { x = 37.9, y = 30.8, label = "Thoriumspitze" },
			west_rim    = { x = 24.5, y = 52.0, label = "Westrand Kessel" },
			brm_pass    = { x = 35.0, y = 84.5, label = "Schwarzfels-Eingang" },
		},
		edges = {
			{ "badlands_p", "east_rim" }, { "east_rim", "north_rim" },
			{ "north_rim", "thorium" }, { "thorium", "west_rim" },
			{ "west_rim", "brm_pass" }, { "east_rim", "brm_pass" },
		},
	},
	["Un'Goro Crater"] = {
		nodes = {
			tanaris_ramp= { x = 71.0, y = 76.0, label = "Tanaris-Rampe" },
			east_rim    = { x = 66.0, y = 48.0, label = "Ostpfad Un'Goro" },
			marshal     = { x = 45.2, y = 5.8,  label = "Marshals Zuflucht" },
			north_trail = { x = 48.0, y = 24.0, label = "Nordpfad Krater" },
			west_rim    = { x = 30.0, y = 44.0, label = "Westpfad Un'Goro" },
			silithus_p  = { x = 29.0, y = 22.0, label = "Silithus-Pass" },
			south_trail = { x = 47.0, y = 78.0, label = "Südpfad Krater" },
		},
		edges = {
			{ "tanaris_ramp", "east_rim" }, { "east_rim", "north_trail" },
			{ "north_trail", "marshal" }, { "north_trail", "silithus_p" },
			{ "north_trail", "west_rim" }, { "west_rim", "south_trail" },
			{ "south_trail", "tanaris_ramp" },
		},
	},
	["Durotar"] = {
		nodes = {
			org_gate    = { x = 46.0, y = 13.5, label = "Orgrimmar Haupttor" },
			org_zep     = { x = 50.8, y = 13.8, label = "Orgrimmar Zeppelinturm" },
			north_road  = { x = 51.5, y = 27.5, label = "Nordstraße Durotar" },
			razor_hill  = { x = 52.0, y = 41.6, label = "Klingenhügel" },
			west_bridge = { x = 35.5, y = 41.0, label = "Brachland-Brücke" },
			senjin_road = { x = 54.0, y = 63.0, label = "Südstraße Sen'jin" },
			senjin      = { x = 56.0, y = 74.5, label = "Sen'jin" },
		},
		edges = {
			{ "org_gate", "org_zep" }, { "org_gate", "north_road" },
			{ "org_zep", "north_road" }, { "north_road", "razor_hill" },
			{ "razor_hill", "west_bridge" }, { "razor_hill", "senjin_road" },
			{ "senjin_road", "senjin" },
		},
	},
	["Orgrimmar"] = {
		nodes = {
			gate        = { x = 49.0, y = 92.0, label = "Haupttor Orgrimmar" },
			valley_str  = { x = 51.5, y = 72.0, label = "Tal der Stärke" },
			ah          = { x = 55.6, y = 64.0, label = "Auktionshaus" },
			drag        = { x = 57.5, y = 52.0, label = "Die Gasse" },
			valley_hon  = { x = 73.0, y = 34.0, label = "Tal der Ehre" },
			valley_wis  = { x = 38.0, y = 42.0, label = "Tal der Weisheit" },
			cleft       = { x = 48.0, y = 50.0, label = "Kluft der Schatten" },
		},
		edges = {
			{ "gate", "valley_str" }, { "valley_str", "ah" },
			{ "valley_str", "drag" }, { "drag", "valley_hon" },
			{ "drag", "cleft" }, { "valley_str", "valley_wis" },
			{ "valley_wis", "drag" },
		},
	},
	["Eastern Plaguelands"] = {
		nodes = {
			wpl_pass    = { x = 11.5, y = 66.0, label = "Pass Westliche Pestländer" },
			darrow_j    = { x = 34.5, y = 68.5, label = "Darroheim-Straße" },
			corins      = { x = 55.5, y = 63.0, label = "Corins Kreuzung" },
			lights_hope = { x = 81.6, y = 59.3, label = "Kapelle d. hoffnungsvollen Lichts" },
			crown_guard = { x = 39.5, y = 52.0, label = "Kronenwache Straße" },
			strat_road  = { x = 32.0, y = 30.0, label = "Stratholme-Straße" },
			stratholme  = { x = 31.3, y = 15.7, label = "Stratholme-Tor" },
			naxx_road   = { x = 54.0, y = 36.0, label = "Nordost-Straße" },
		},
		edges = {
			{ "wpl_pass", "darrow_j" }, { "darrow_j", "corins" },
			{ "corins", "lights_hope" }, { "darrow_j", "crown_guard" },
			{ "crown_guard", "strat_road" }, { "strat_road", "stratholme" },
			{ "corins", "naxx_road" }, { "naxx_road", "crown_guard" },
		},
	},
	["Western Plaguelands"] = {
		nodes = {
			chillwind   = { x = 42.9, y = 85.1, label = "Zugwindlager" },
			bulwark     = { x = 27.0, y = 58.0, label = "Das Bollwerk" },
			andorhal_s  = { x = 43.0, y = 70.0, label = "Südstraße Andorhal" },
			andorhal_e  = { x = 52.0, y = 65.0, label = "Oststraße Andorhal" },
			scholo_br   = { x = 65.5, y = 73.5, label = "Caer-Darrow-Brücke" },
			scholomance = { x = 69.4, y = 72.9, label = "Scholomance" },
			epl_pass    = { x = 69.5, y = 52.0, label = "Pass Östliche Pestländer" },
			hearthglen_r= { x = 47.0, y = 40.0, label = "Herdweiler-Straße" },
		},
		edges = {
			{ "chillwind", "andorhal_s" }, { "bulwark", "andorhal_s" },
			{ "andorhal_s", "andorhal_e" }, { "andorhal_e", "scholo_br" },
			{ "scholo_br", "scholomance" }, { "andorhal_e", "epl_pass" },
			{ "andorhal_e", "hearthglen_r" },
		},
	},
	["Hillsbrad Foothills"] = {
		nodes = {
			silverpine_p= { x = 14.0, y = 42.0, label = "Silberwald-Pass" },
			southshore_j= { x = 49.0, y = 44.0, label = "Süderstade-Kreuzung" },
			southshore  = { x = 49.4, y = 52.3, label = "Süderstade" },
			tarren_mill = { x = 60.2, y = 18.7, label = "Tarrens Mühle" },
			east_road   = { x = 72.0, y = 46.0, label = "Oststraße Vorgebirge" },
			arathi_pass = { x = 84.5, y = 34.0, label = "Arathi-Pass" },
		},
		edges = {
			{ "silverpine_p", "southshore_j" }, { "southshore_j", "southshore" },
			{ "southshore_j", "tarren_mill" }, { "southshore_j", "east_road" },
			{ "east_road", "arathi_pass" },
		},
	},
	["Arathi Highlands"] = {
		nodes = {
			hillsbrad_p = { x = 21.0, y = 30.0, label = "Thoradinswall-Tor" },
			stromgarde_j= { x = 31.5, y = 45.0, label = "Stromgarde-Kreuzung" },
			refuge      = { x = 45.8, y = 46.1, label = "Die Zuflucht" },
			hammerfall_j= { x = 62.0, y = 42.0, label = "Hammerfall-Abzweigung" },
			hammerfall  = { x = 73.1, y = 32.7, label = "Hammerfall" },
			thandol_n   = { x = 45.5, y = 85.0, label = "Thandolübergang" },
		},
		edges = {
			{ "hillsbrad_p", "stromgarde_j" }, { "stromgarde_j", "refuge" },
			{ "refuge", "hammerfall_j" }, { "hammerfall_j", "hammerfall" },
			{ "refuge", "thandol_n" },
		},
	},
	["Wetlands"] = {
		nodes = {
			menethil    = { x = 9.5,  y = 59.5, label = "Hafen von Menethil" },
			west_road   = { x = 24.0, y = 56.0, label = "Weststraße Sumpfland" },
			mid_cross   = { x = 48.0, y = 51.0, label = "Sumpfland-Kreuzung" },
			dun_algaz   = { x = 53.5, y = 71.0, label = "Dun-Algaz-Tunnel (Loch Modan)" },
			north_road  = { x = 50.0, y = 30.0, label = "Nordstraße Thandol" },
			thandol     = { x = 49.8, y = 12.2, label = "Thandolübergang" },
		},
		edges = {
			{ "menethil", "west_road" }, { "west_road", "mid_cross" },
			{ "mid_cross", "dun_algaz" }, { "mid_cross", "north_road" },
			{ "north_road", "thandol" },
		},
	},
	["Ashenvale"] = {
		nodes = {
			darkshore_p = { x = 29.0, y = 18.0, label = "Dunkelküste-Pass" },
			maestra     = { x = 27.5, y = 36.0, label = "Maestras Posten" },
			astranaar   = { x = 34.4, y = 48.0, label = "Astranaar" },
			mid_road    = { x = 52.0, y = 56.0, label = "Silberwindstraße" },
			splintertree= { x = 73.2, y = 61.6, label = "Splitterholzposten" },
			barrens_p   = { x = 68.5, y = 85.0, label = "Brachland-Pass" },
			azshara_p   = { x = 94.0, y = 52.0, label = "Azshara-Pass" },
			felwood_p   = { x = 55.5, y = 34.0, label = "Teufelswald-Pass" },
		},
		edges = {
			{ "darkshore_p", "maestra" }, { "maestra", "astranaar" },
			{ "astranaar", "mid_road" }, { "mid_road", "splintertree" },
			{ "mid_road", "felwood_p" }, { "splintertree", "barrens_p" },
			{ "splintertree", "azshara_p" },
		},
	},
	["Felwood"] = {
		nodes = {
			ashen_pass  = { x = 54.0, y = 94.0, label = "Eschental-Pass" },
			emerald     = { x = 51.5, y = 82.2, label = "Smaragdrefugium" },
			mid_road    = { x = 46.5, y = 58.0, label = "Hauptstraße Teufelswald" },
			bloodvenom  = { x = 41.0, y = 45.0, label = "Blutgiftposten-Straße" },
			talonbranch = { x = 61.5, y = 26.0, label = "Nachtlaube-Abzweigung" },
			timbermaw   = { x = 64.5, y = 8.5,  label = "Holzschlundfeste Tunnel" },
		},
		edges = {
			{ "ashen_pass", "emerald" }, { "emerald", "mid_road" },
			{ "mid_road", "bloodvenom" }, { "bloodvenom", "talonbranch" },
			{ "talonbranch", "timbermaw" },
		},
	},
	["Desolace"] = {
		nodes = {
			stone_pass  = { x = 53.0, y = 10.0, label = "Steinkrallen-Pass" },
			nijels_j    = { x = 60.0, y = 19.0, label = "Nijelspitze-Straße" },
			nijels      = { x = 64.7, y = 10.5, label = "Nijelspitze" },
			kodo_road   = { x = 53.0, y = 45.0, label = "Kodo-Friedhof Straße" },
			maraudon_j  = { x = 39.0, y = 55.0, label = "Maraudon-Straße" },
			maraudon    = { x = 29.1, y = 62.5, label = "Maraudon-Eingang" },
			shadowprey  = { x = 25.0, y = 70.0, label = "Schattenflucht-Straße" },
			feralas_p   = { x = 42.5, y = 93.0, label = "Feralas-Pass" },
		},
		edges = {
			{ "stone_pass", "nijels_j" }, { "nijels_j", "nijels" },
			{ "nijels_j", "kodo_road" }, { "kodo_road", "maraudon_j" },
			{ "maraudon_j", "maraudon" }, { "maraudon_j", "shadowprey" },
			{ "kodo_road", "feralas_p" },
		},
	},
}

-- Impassable Mountain Ridges, Canyon Cliffs, City Walls & Pits per Zone
-- Straight segments intersecting any barrier are blocked so the router curves through gates, bridges & passes!
PluribusHivePathfinder.ZONE_BARRIERS = {
	["Elwynn Forest"] = {
		-- Northshire Valley mountain ring (open only at the south entrance near 48.2, 54.0)
		{ 43.0, 32.0, 44.5, 52.0, "Nordhain-Gebirge West" },
		{ 53.5, 32.0, 52.5, 52.0, "Nordhain-Gebirge Ost" },
		-- Stormwind southern/eastern city walls (open at gates 32.0, 49.5)
		{ 22.0, 50.0, 29.5, 51.0, "Stadtmauer Sturmwind" },
		{ 34.8, 49.5, 42.0, 40.0, "Stadtmauer Sturmwind Ost" },
	},
	["Stormwind City"] = {
		-- Canal walls between Trade/Cathedral/Dwarven/Old Town (forces routing over bridges!)
		{ 45.0, 56.0, 49.2, 53.0, "Kanalmauer West" },
		{ 53.2, 50.0, 59.0, 46.0, "Kanalmauer Nord" },
		{ 63.0, 52.0, 68.0, 62.0, "Kanalmauer Altstadt" },
	},
	["Redridge Mountains"] = {
		-- Lake Everstill & northern cliff ridge (forces crossing Lakeshire Bridge!)
		{ 20.0, 55.0, 27.5, 55.0, "See / Klippe West" },
		{ 32.0, 55.0, 54.0, 58.0, "Immerruhsee" },
		{ 14.0, 35.0, 28.0, 22.0, "Rotkamm-Steilwand" },
	},
	["Stranglethorn Vale"] = {
		-- Central mountain ridges dividing coast & jungle road + Booty Bay cliff wall (open at tunnel 30.8, 68.5)
		{ 26.0, 64.5, 29.5, 67.5, "Beutebucht-Felswand West" },
		{ 32.5, 67.5, 42.0, 66.0, "Beutebucht-Felswand Ost" },
		{ 44.0, 36.0, 48.0, 58.0, "Ost-Gebirgszug STV" },
	},
	["Dun Morogh"] = {
		-- Ironforge mountain ridge & Coldridge cliffs (forces tunnel/road around mountains!)
		{ 38.0, 41.0, 49.5, 39.0, "Eisenschmiede-Massiv West" },
		{ 56.5, 38.0, 68.0, 42.0, "Eisenschmiede-Massiv Ost" },
		{ 74.0, 41.0, 80.5, 46.0, "Ostgebirge Dun Morogh" },
	},
	["Tanaris"] = {
		-- Gadgetzan fortress walls (open at North 51.2,25.2 & East 55.2,28.5 gates!) + Western Zul'Farrak ridge
		{ 48.5, 26.0, 48.5, 32.0, "Gadgetzan Westmauer" },
		{ 48.5, 32.0, 55.0, 32.0, "Gadgetzan Südmauer" },
		{ 31.0, 25.0, 41.0, 38.0, "Zul'Farrak-Gebirgswand" },
		{ 57.0, 34.0, 65.0, 44.0, "Ostdünen-Felsgrat" },
	},
	["Thousand Needles"] = {
		-- Impassable canyon rim walls north & south of the canyon road
		{ 12.0, 24.0, 30.0, 20.0, "Canyon-Nordwand West" },
		{ 34.5, 24.0, 62.0, 44.0, "Canyon-Nordwand Ost" },
		{ 16.0, 44.0, 58.0, 66.0, "Canyon-Südwand" },
	},
	["Searing Gorge"] = {
		-- The Cauldron deep lava pit in the center (forces routing around North/East/West rim roads!)
		{ 32.0, 42.0, 58.0, 42.0, "Der Kessel (Nordkante)" },
		{ 32.0, 64.0, 58.0, 64.0, "Der Kessel (Südkante)" },
		{ 32.0, 42.0, 32.0, 64.0, "Der Kessel (Westkante)" },
		{ 58.0, 42.0, 58.0, 64.0, "Der Kessel (Ostkante)" },
	},
	["Un'Goro Crater"] = {
		-- Fire Plume Ridge volcano in the center of the crater (routes around rim trail!)
		{ 44.0, 38.0, 57.0, 56.0, "Feuersäulengrat Vulkan" },
		{ 57.0, 38.0, 44.0, 56.0, "Feuersäulengrat Flanke" },
	},
	["Feralas"] = {
		-- Twin Colossals & central mountain divide
		{ 49.0, 22.0, 54.0, 42.0, "Zwillingskolosse Felswand" },
		{ 36.0, 32.0, 41.0, 52.0, "Küsten-Steilwand" },
	},
	["Orgrimmar"] = {
		-- Canyon ridges separating Valley of Strength, Wisdom & Honor (forces routing through Drag / gates)
		{ 43.0, 58.0, 48.0, 46.0, "Canyonwand Weisheit" },
		{ 62.0, 62.0, 68.0, 44.0, "Canyonwand Ehre" },
	},
	["Badlands"] = {
		-- Central rock spine separating Uldaman road and southern valley
		{ 22.0, 26.0, 39.0, 31.0, "Ödland-Felsgrat West" },
		{ 49.0, 28.0, 66.0, 34.0, "Ödland-Felsgrat Ost" },
	},
}

function PluribusHivePathfinder:SegmentHitsBarrier(zone, x1, y1, x2, y2)
	local cz = self:CanonicalZone(zone)
	local barriers = self.ZONE_BARRIERS[cz]
	if not barriers then return false, nil end
	for _, b in ipairs(barriers) do
		if self:SegmentsIntersect(x1, y1, x2, y2, b[1], b[2], b[3], b[4]) then
			return true, b[5]
		end
	end
	return false, nil
end

function PluribusHivePathfinder:GetZoneContinent(zoneName)
	local cz = self:CanonicalZone(zoneName)
	local b = self.ZONE_CONTINENT_BOUNDS and self.ZONE_CONTINENT_BOUNDS[cz]
	if b and b.cont then return b.cont end
	for _, n in pairs(self.NODES or {}) do
		if n.zone == cz and n.cont then return n.cont end
	end
	return nil
end

-- True barrier-avoiding, road- & navmesh-preferring intra-zone A* router!
-- Combines built-in ZONE_ROADS, learned & guild-synced walkable TerrainMesh, game-internal MapLinks/AreaPOIs,
-- and strictly avoids ZONE_BARRIERS + runtime detected obstacles!
function PluribusHivePathfinder:ComputeIntraZonePath(zone, sx, sy, dx, dy, speeds, opts)
	if _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.ComputeTerrainPath then
		local tmLegs, tmEta, tmBlocked, tmReason = _G.PluribusHiveTerrainMesh:ComputeTerrainPath(zone, sx, sy, dx, dy, speeds, opts)
		if tmLegs and #tmLegs > 0 then
			return tmLegs, tmEta, tmBlocked, tmReason
		end
	end
	opts = opts or {}
	local cz = self:CanonicalZone(zone)
	local landSpeed = (speeds and speeds.landSpeed) or BASE_RUN_SPEED
	local directDist = NodeDistanceYards(sx, sy, dx, dy, cz)
	local directBlocked, blockedBy = self:SegmentHitsBarrier(cz, sx, sy, dx, dy)

	local roadNet = self.ZONE_ROADS[cz]
	-- Very short & completely unobstructed segment (< 95 yds): go straight to target
	if (not roadNet) or (directDist <= 95 and not directBlocked) then
		local eta = math.max(1, math.floor(directDist / landSpeed))
		return {
			{
				label = opts.destName or cz,
				zone = cz,
				x = dx,
				y = dy,
				mode = "road",
				distYards = math.floor(directDist),
				etaSec = eta,
			},
		}, eta, false
	end

	-- Assemble local zone graph: __START__, __END__, and all road junctions in this zone
	local pts = {
		__START__ = { x = sx, y = sy, label = "Start" },
		__END__   = { x = dx, y = dy, label = opts.destName or cz },
	}
	local roadIds = {}
	for rid, rn in pairs(roadNet.nodes or {}) do
		pts[rid] = { x = rn.x, y = rn.y, label = rn.label or rid, isRoad = true }
		table.insert(roadIds, rid)
	end

	local adj = {}
	local function AddLocalEdge(u, v, cost, isRoad, distYds)
		adj[u] = adj[u] or {}
		table.insert(adj[u], { to = v, cost = cost, isRoad = isRoad, distYds = distYds })
	end

	-- 1. Defined road segments (guaranteed passable, strong road speed/safety preference: 0.72x!)
	for _, e in ipairs(roadNet.edges or {}) do
		local u, v = e[1], e[2]
		if pts[u] and pts[v] then
			local d = NodeDistanceYards(pts[u].x, pts[u].y, pts[v].x, pts[v].y)
			local cost = (d / landSpeed) * 0.72
			AddLocalEdge(u, v, cost, true, d)
			AddLocalEdge(v, u, cost, true, d)
		end
	end

	-- 2. Connect START and END to nearby road nodes (blocking any link that cuts through a wall/mountain!)
	local OFFROAD_MULT = 1.42
	local BARRIER_PENALTY = 18.0
	for _, rid in ipairs(roadIds) do
		local rp = pts[rid]
		local ds = NodeDistanceYards(sx, sy, rp.x, rp.y)
		local sHit = self:SegmentHitsBarrier(cz, sx, sy, rp.x, rp.y)
		local sCost = (ds / landSpeed) * (sHit and BARRIER_PENALTY or OFFROAD_MULT)
		AddLocalEdge("__START__", rid, sCost, false, ds)

		local de = NodeDistanceYards(rp.x, rp.y, dx, dy)
		local eHit = self:SegmentHitsBarrier(cz, rp.x, rp.y, dx, dy)
		local eCost = (de / landSpeed) * (eHit and BARRIER_PENALTY or OFFROAD_MULT)
		AddLocalEdge(rid, "__END__", eCost, false, de)
	end

	-- 3. Direct START -> END off-road link (ONLY viable if clear of walls/mountains, and still penalized vs roads!)
	local directCost = (directDist / landSpeed) * (directBlocked and BARRIER_PENALTY or OFFROAD_MULT)
	AddLocalEdge("__START__", "__END__", directCost, false, directDist)

	-- 4. Dijkstra over local zone road graph
	local distMap = { __START__ = 0 }
	local prev = {}
	local visited = {}
	while true do
		local cur, best = nil, 1e12
		for id, d in pairs(distMap) do
			if not visited[id] and d < best then
				best = d
				cur = id
			end
		end
		if not cur or cur == "__END__" then break end
		visited[cur] = true
		for _, edge in ipairs(adj[cur] or {}) do
			if not visited[edge.to] then
				local alt = best + edge.cost
				if alt < (distMap[edge.to] or 1e12) then
					distMap[edge.to] = alt
					prev[edge.to] = { node = cur, edge = edge }
				end
			end
		end
	end

	-- Reconstruct multi-leg road path
	local seq = {}
	local cur = "__END__"
	while cur and cur ~= "__START__" do
		table.insert(seq, 1, { id = cur, via = prev[cur] and prev[cur].edge or nil })
		cur = prev[cur] and prev[cur].node or nil
	end

	local legs = {}
	local totalEta = 0
	for i, step in ipairs(seq) do
		local p = pts[step.id]
		if p then
			local dYds = step.via and step.via.distYds or 0
			local legEta = math.max(1, math.floor(dYds / landSpeed))
			-- Skip redundant start-adjacent road waypoint if player is already standing right on it (< 30 yds)
			if not (i == 1 and step.id ~= "__END__" and dYds < 30) then
				table.insert(legs, {
					label = p.label,
					zone = cz,
					x = p.x,
					y = p.y,
					mode = "road",
					isRoad = (step.via and step.via.isRoad) == true,
					distYards = math.floor(dYds),
					etaSec = legEta,
				})
				totalEta = totalEta + legEta
			end
		end
	end

	if #legs == 0 then
		local eta = math.max(1, math.floor(directDist / landSpeed))
		legs = {
			{
				label = opts.destName or cz,
				zone = cz,
				x = dx,
				y = dy,
				mode = "road",
				distYards = math.floor(directDist),
				etaSec = eta,
			},
		}
		totalEta = eta
	end

	return legs, totalEta, (directBlocked == true), blockedBy
end

local CITY_HUB_FALLBACK = {
	["Stormwind City"] = "sw_gate",
	["Ironforge"]      = "ironforge",
	["Darnassus"]      = "darnassus",
	["Orgrimmar"]      = "org_zep",
	["Undercity"]      = "uc_zep",
	["Thunder Bluff"]  = "thunder_bluff",
}

function PluribusHivePathfinder:FindNearestNode(zone, x, y, faction)
	local canon = self:CanonicalZone(zone)
	local cityNodeId = CITY_HUB_FALLBACK[canon]
	if cityNodeId and self.NODES[cityNodeId] then
		local cn = self.NODES[cityNodeId]
		if cn.faction == "NEUTRAL" or cn.faction == faction then
			return cityNodeId, 60
		end
	end
	local bestId, bestDist = nil, 999999
	for id, n in pairs(self.NODES) do
		if n.faction == "NEUTRAL" or n.faction == faction then
			if n.zone == canon then
				local d = NodeDistanceYards(x, y, n.x, n.y)
				if d < bestDist then
					bestDist = d
					bestId = id
				end
			end
		end
	end
	if bestId then return bestId, bestDist end
	-- Fallback: pick any node matching zone regardless of faction (road entrance)
	for id, n in pairs(self.NODES) do
		if n.zone == canon then
			local d = NodeDistanceYards(x, y, n.x, n.y)
			if d < bestDist then
				bestDist = d
				bestId = id
			end
		end
	end
	return bestId, bestDist
end

function PluribusHivePathfinder:ComputeRoute(startZone, startX, startY, destZone, destX, destY, opts)
	opts = opts or {}
	local sZone = self:CanonicalZone(startZone or (GetRealZoneText and GetRealZoneText()) or "Elwynn Forest")
	local dZone = self:CanonicalZone(destZone or sZone)
	local sx, sy = tonumber(startX) or 50, tonumber(startY) or 50
	local dx, dy = tonumber(destX) or 50, tonumber(destY) or 50
	local faction = opts.faction or self:GetPlayerFaction()
	local playerLevel = tonumber(opts.playerLevel) or (UnitLevel and UnitLevel("player")) or 60
	local cfg = PluribusHive and PluribusHive:GetConfig() or {}
	local avoidHigh = (opts.avoidHighLevel ~= nil) and opts.avoidHighLevel or (cfg.navAvoidHighLevel ~= false)
	local speeds = opts.speeds or self:GetMovementSpeeds()
	local discoveredFP = opts.discoveredFP or self:GetDiscoveredFlightPoints()

	-- Same-zone routing: ALWAYS respect roads, gates, bridges & mountain/wall barriers!
	if sZone == dZone then
		local intraLegs, intraEta, avoidedBarrier = self:ComputeIntraZonePath(sZone, sx, sy, dx, dy, speeds, { destName = opts.destName or dZone })
		return {
			legs = intraLegs,
			totalEtaSec = intraEta,
			avoidsHazard = avoidedBarrier == true,
			avoidedBarrier = avoidedBarrier == true,
			speeds = speeds,
			destName = opts.destName or dZone,
			destZone = dZone,
			destX = dx,
			destY = dy,
		}
	end

	local startNodeId, startToNodeDist = self:FindNearestNode(sZone, sx, sy, faction)
	local endNodeId, endFromNodeDist = self:FindNearestNode(dZone, dx, dy, faction)

	if not startNodeId or not endNodeId or startNodeId == endNodeId then
		local intraLegs, intraEta, avoidedBarrier = self:ComputeIntraZonePath(dZone, sx, sy, dx, dy, speeds, { destName = opts.destName or dZone })
		return {
			legs = intraLegs,
			totalEtaSec = intraEta,
			avoidsHazard = avoidedBarrier == true,
			avoidedBarrier = avoidedBarrier == true,
			speeds = speeds,
			destName = opts.destName or dZone,
			destZone = dZone,
			destX = dx,
			destY = dy,
		}
	end

	-- Collect live open-world guild Mage (portal) & Warlock (summon) transit edges if enabled
	local useGuildTransit = (opts.useGuildTransit ~= nil) and opts.useGuildTransit or (cfg.navUseGuildTransit ~= false)
	local guildTransitEdges = {}
	local transitSummary = nil
	if useGuildTransit and _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.BuildTransitEdges then
		guildTransitEdges, transitSummary = _G.PluribusHiveGuildTransit:BuildTransitEdges(startNodeId, faction, {
			useGuildTransit = true,
			guildMembers = opts.guildMembers,
			selfName = opts.selfName,
		})
	end

	-- Fast O(1) persistent route cache lookup (bypassed when live guild transit providers exist or deterministic opts are requested)
	local pdb = self:GetDB()
	local profileHash = self:GetProfileHash(faction, playerLevel, speeds, discoveredFP, avoidHigh)
	local pairKey = startNodeId .. "->" .. endNodeId
	local canUseCache = (not opts.bypassCache) and (opts.nowSec == nil) and (#guildTransitEdges == 0)
	if canUseCache then
		local cached = pdb.routeCache[pairKey]
		if cached and cached.profileHash == profileHash and cached.coreLegs then
			local age = time() - (cached.computedAt or 0)
			local maxAge = cached.hasShip and 90 or 1800
			if age <= maxAge then
				local legs = {}
				local totalEta = 0
				local firstN = self.NODES[startNodeId]
				if firstN and startToNodeDist > 45 then
					local entryLegs, entryEta = self:ComputeIntraZonePath(firstN.zone, sx, sy, firstN.x, firstN.y, speeds, { destName = firstN.label })
					for idxE, el in ipairs(entryLegs) do
						if idxE == #entryLegs then el.nodeId = startNodeId end
						table.insert(legs, el)
					end
					totalEta = totalEta + entryEta
				end
				for _, cl in ipairs(cached.coreLegs) do
					table.insert(legs, {
						label = cl.label,
						zone = cl.zone,
						x = cl.x,
						y = cl.y,
						nodeId = cl.nodeId,
						fromNodeId = cl.fromNodeId,
						mode = cl.mode,
						distYards = cl.distYards,
						etaSec = cl.etaSec,
						waitSec = cl.waitSec,
						isSynced = cl.isSynced,
						routeId = cl.routeId,
					})
					totalEta = totalEta + (cl.etaSec or 0)
				end
				local lastN = self.NODES[endNodeId]
				if lastN and lastN.zone == dZone then
					local exitLegs, exitEta = self:ComputeIntraZonePath(dZone, lastN.x, lastN.y, dx, dy, speeds, { destName = opts.destName or dZone })
					for idxX, xl in ipairs(exitLegs) do
						if idxX == #exitLegs then xl.nodeId = endNodeId end
						table.insert(legs, xl)
					end
					totalEta = totalEta + exitEta
				else
					local finalEta = math.max(2, math.floor((endFromNodeDist or 120) / speeds.landSpeed))
					table.insert(legs, {
						label = opts.destName or dZone,
						zone = dZone,
						x = dx,
						y = dy,
						nodeId = endNodeId,
						mode = "road",
						distYards = math.floor(endFromNodeDist or 0),
						etaSec = finalEta,
					})
					totalEta = totalEta + finalEta
				end
				return {
					legs = legs,
					totalEtaSec = totalEta,
					avoidsHazard = cached.avoidsHazard == true,
					speeds = speeds,
					destName = opts.destName or dZone,
					destZone = dZone,
					destX = dx,
					destY = dy,
					fromCache = true,
					generation = cached.generation or 1,
				}
			end
		end
	end

	-- Build adjacency list dynamically using player's speeds, discovered FPs, guild-synced ship timers, learned edge speeds & level hazard weights
	local adj = {}
	local function AddEdge(u, v, cost, meta)
		adj[u] = adj[u] or {}
		table.insert(adj[u], { to = v, cost = cost, meta = meta })
	end

	local hazardPenalized = false
	for _, e in ipairs(self.EDGES) do
		local u, v = e[1], e[2]
		local nu, nv = self.NODES[u], self.NODES[v]
		if nu and nv then
			local factionOK = (not e.faction or e.faction == "NEUTRAL" or e.faction == faction)
			if factionOK then
				local allowed = true
				local timeSec = 0
				local waitSec = 0
				local isSynced = false

				if e.mode == "flight" then
					if not (discoveredFP[u] and discoveredFP[v]) then
						allowed = false
					else
						local costUV, syncedUV = self:GetFlightDurationSec(u, v, e.dist)
						local costVU, syncedVU = self:GetFlightDurationSec(v, u, e.dist)
						AddEdge(u, v, costUV, {
							mode = "flight",
							dist = e.dist or 0,
							waitSec = 0,
							isSynced = syncedUV,
							routeId = nil,
							isRoad = false,
						})
						AddEdge(v, u, costVU, {
							mode = "flight",
							dist = e.dist or 0,
							waitSec = 0,
							isSynced = syncedVU,
							routeId = nil,
							isRoad = false,
						})
						allowed = false -- Directional edges already added above
					end
				elseif e.mode == "boat" or e.mode == "zeppelin" then
					local w, sail, synced = self:GetShipTiming(e.routeId, opts.nowSec)
					waitSec = w
					isSynced = synced
					timeSec = w + sail
				elseif e.mode == "water" then
					timeSec = ((e.dist or 900) / speeds.waterSpeed) * self:GetObservedEdgeFactor(u, v)
				else
					-- Road / land edge: roads get a 0.88x smooth/safe factor vs 1.22x offroad mob density, refined by real guild travel telemetry
					local roadFactor = e.isRoad and 0.88 or 1.22
					timeSec = ((e.dist or 1200) / speeds.landSpeed) * roadFactor * self:GetObservedEdgeFactor(u, v)
				end

				-- Level-aware hazard avoidance (penalizes edges through high-level zones/mobs!)
				if allowed and avoidHigh and e.mode ~= "flight" and e.mode ~= "boat" and e.mode ~= "zeppelin" then
					local edgeMinL = e.minL or math.max(nu.minL or 1, nv.minL or 1)
					local diff = edgeMinL - playerLevel
					if diff >= 8 then
						timeSec = timeSec * 4.5 + 240 -- Skull mobs: strongly avoid!
						hazardPenalized = true
					elseif diff >= 4 then
						timeSec = timeSec * 2.4 + 90 -- Red/high-orange zone: route around if possible
						hazardPenalized = true
					end
				end

				if allowed then
					local meta = {
						mode = e.mode,
						dist = e.dist or 0,
						waitSec = waitSec,
						isSynced = isSynced,
						routeId = e.routeId,
						isRoad = e.isRoad,
					}
					AddEdge(u, v, timeSec, meta)
					AddEdge(v, u, timeSec, meta)
				end
			end
		end
	end

	-- Inject dynamic open-world Guild Mage Portal & Warlock Summon transit edges
	for _, te in ipairs(guildTransitEdges) do
		if te.from and te.to and self.NODES[te.from] and self.NODES[te.to] then
			AddEdge(te.from, te.to, te.cost, te.meta)
		end
	end

	-- Standard Dijkstra over Azeroth graph
	local distMap = { [startNodeId] = 0 }
	local prev = {}
	local visited = {}

	while true do
		local cur, curBest = nil, 1e12
		for id, d in pairs(distMap) do
			if not visited[id] and d < curBest then
				curBest = d
				cur = id
			end
		end
		if not cur or cur == endNodeId then break end
		visited[cur] = true

		for _, edge in ipairs(adj[cur] or {}) do
			if not visited[edge.to] then
				local alt = curBest + edge.cost
				if alt < (distMap[edge.to] or 1e12) then
					distMap[edge.to] = alt
					prev[edge.to] = { node = cur, edge = edge }
				end
			end
		end
	end

	-- Reconstruct turn-by-turn legs
	local pathNodes = {}
	local cur = endNodeId
	if prev[cur] or cur == startNodeId then
		while cur do
			table.insert(pathNodes, 1, { id = cur, via = prev[cur] and prev[cur].edge or nil })
			cur = prev[cur] and prev[cur].node or nil
		end
	end

	local legs = {}
	local coreLegs = {}
	local totalEta = 0
	local coreEta = 0
	local hasShip = false
	local hasGuildTransit = false

	if #pathNodes > 1 then
		-- First leg: route along zone roads & around barriers onto start node
		local firstN = self.NODES[pathNodes[1].id]
		if firstN and startToNodeDist > 45 then
			local entryLegs, entryEta = self:ComputeIntraZonePath(firstN.zone, sx, sy, firstN.x, firstN.y, speeds, { destName = firstN.label })
			for idxE, el in ipairs(entryLegs) do
				if idxE == #entryLegs then el.nodeId = pathNodes[1].id end
				table.insert(legs, el)
			end
			totalEta = totalEta + entryEta
		end

		for i = 2, #pathNodes do
			local prevStep = pathNodes[i - 1]
			local step = pathNodes[i]
			local targetNode = self.NODES[step.id]
			local meta = step.via and step.via.meta or { mode = "road", dist = 800 }
			local legEta = math.max(2, math.floor((step.via and step.via.cost) or 20))
			if meta.mode == "boat" or meta.mode == "zeppelin" then hasShip = true end
			if meta.mode == "portal" or meta.mode == "summon" then hasGuildTransit = true end
			local legObj = {
				label = targetNode.label,
				zone = targetNode.zone,
				x = targetNode.x,
				y = targetNode.y,
				nodeId = step.id,
				fromNodeId = prevStep and prevStep.id or nil,
				mode = meta.mode,
				distYards = math.floor(meta.dist or 0),
				etaSec = legEta,
				waitSec = meta.waitSec or 0,
				isSynced = meta.isSynced == true,
				routeId = meta.routeId,
				providerName = meta.providerName,
				providerClass = meta.providerClass,
				providerLevel = meta.providerLevel,
				providerZone = meta.providerZone,
				spellLabel = meta.spellLabel,
				helperPenaltySec = meta.helperPenaltySec or 0,
				nearbyHelpers = meta.nearbyHelpers or 0,
			}
			-- Expand same-zone road legs through intermediate ZONE_ROADS / TerrainMesh waypoints (never cut straight across a zone!)
			local prevNode = prevStep and self.NODES[prevStep.id]
			if meta.mode == "road" and prevNode and prevNode.zone == targetNode.zone then
				local subLegs = self:ComputeIntraZonePath(targetNode.zone, prevNode.x, prevNode.y, targetNode.x, targetNode.y, speeds, { destName = targetNode.label })
				if subLegs and #subLegs > 1 then
					for sIdx, sl in ipairs(subLegs) do
						if sIdx == #subLegs then
							sl.nodeId = step.id
							sl.fromNodeId = prevStep.id
						end
						table.insert(legs, sl)
						table.insert(coreLegs, sl)
					end
				else
					table.insert(legs, legObj)
					table.insert(coreLegs, legObj)
				end
			else
				table.insert(legs, legObj)
				table.insert(coreLegs, legObj)
			end
			totalEta = totalEta + legEta
			coreEta = coreEta + legEta
		end
	end

	-- Save/upgrade core route in persistent routeCache (never store ephemeral player portal/summon legs in static cache)
	if not opts.noStore and not hasGuildTransit and #coreLegs > 0 then
		local prevCached = pdb.routeCache[pairKey]
		local improved = false
		local gen = 1
		if prevCached then
			gen = (prevCached.generation or 1) + 1
			if prevCached.coreEtaSec and coreEta < (prevCached.coreEtaSec - 1) then
				improved = true
				pdb.cacheMeta.totalImprovements = (pdb.cacheMeta.totalImprovements or 0) + 1
			end
		else
			pdb.cacheMeta.totalPrecomputed = (pdb.cacheMeta.totalPrecomputed or 0) + 1
		end
		pdb.routeCache[pairKey] = {
			startNode = startNodeId,
			endNode = endNodeId,
			profileHash = profileHash,
			coreLegs = coreLegs,
			coreEtaSec = coreEta,
			avoidsHazard = hazardPenalized,
			hasShip = hasShip,
			generation = gen,
			improved = improved,
			computedAt = time(),
		}
		pdb.cacheMeta.lastRefineAt = time()
	end

	-- Final leg: route along destination zone roads & around barriers to exact coordinates
	local lastN = self.NODES[endNodeId]
	if lastN and lastN.zone == dZone then
		local exitLegs, exitEta = self:ComputeIntraZonePath(dZone, lastN.x, lastN.y, dx, dy, speeds, { destName = opts.destName or dZone })
		for idxX, xl in ipairs(exitLegs) do
			if idxX == #exitLegs then xl.nodeId = endNodeId end
			table.insert(legs, xl)
		end
		totalEta = totalEta + exitEta
	else
		local finalEta = math.max(2, math.floor((endFromNodeDist or 120) / speeds.landSpeed))
		table.insert(legs, {
			label = opts.destName or dZone,
			zone = dZone,
			x = dx,
			y = dy,
			nodeId = endNodeId,
			mode = "road",
			distYards = math.floor(endFromNodeDist or 0),
			etaSec = finalEta,
		})
		totalEta = totalEta + finalEta
	end

	return {
		legs = legs,
		totalEtaSec = totalEta,
		avoidsHazard = hazardPenalized,
		hasGuildTransit = hasGuildTransit,
		transitSummary = transitSummary,
		speeds = speeds,
		destName = opts.destName or dZone,
		destZone = dZone,
		destX = dx,
		destY = dy,
		fromCache = false,
	}
end

function PluribusHivePathfinder:GetDiscoveredFlightCount()
	local fp = self:GetDiscoveredFlightPoints()
	local n = 0
	for _, v in pairs(fp or {}) do
		if v then n = n + 1 end
	end
	return n
end

function PluribusHivePathfinder:GetTravelProfile()
	local speeds = self:GetMovementSpeeds()
	local cfg = PluribusHive and PluribusHive:GetConfig() or {}
	local gtSum = (_G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.lastSummary) or { mages = 0, warlocks = 0, skippedInstanced = 0 }
	return {
		landSpeed = speeds.landSpeed,
		waterSpeed = speeds.waterSpeed,
		landMult = (speeds.landSpeed or BASE_RUN_SPEED) / BASE_RUN_SPEED,
		waterMult = (speeds.waterSpeed or BASE_SWIM_SPEED) / BASE_RUN_SPEED,
		landTag = speeds.landTag,
		waterTag = speeds.waterTag,
		avoidHighLevel = (cfg.navAvoidHighLevel ~= false),
		useGuildTransit = (cfg.navUseGuildTransit ~= false),
		guildMages = gtSum.mages or 0,
		guildWarlocks = gtSum.warlocks or 0,
	}
end

function PluribusHivePathfinder:BuildRouteSummary(route)
	if not route or not route.legs or #route.legs == 0 then
		return tostring(route and route.destZone or "Azeroth")
	end
	local modeNames = {
		road = "Road",
		water = "Water",
		flight = "Flight",
		boat = "Boat",
		zeppelin = "Zeppelin",
		portal = "Portal",
		summon = "Summon",
	}
	local seq = {}
	local lastM = nil
	for _, leg in ipairs(route.legs) do
		local m = tostring(leg.mode or "road"):lower()
		if m ~= lastM then
			local tok = modeNames[m] or "Road"
			if (m == "portal" or m == "summon") and leg.providerName then
				tok = tok .. "(" .. tostring(leg.providerName) .. ")"
			end
			table.insert(seq, tok)
			lastM = m
		end
	end
	local sec = math.floor(tonumber(route.totalEtaSec or route.totalSec) or 0)
	local etaStr = sec >= 60 and string.format("%dm %ds", math.floor(sec / 60), sec % 60) or string.format("%ds", sec)
	return string.format("%s (%s · %s)", tostring(route.destZone or "Azeroth"), table.concat(seq, " -> "), etaStr)
end

-- Classic Azeroth Zone Bounding Boxes on Continent Maps (0..100% left, top, width, height)
-- Enables drawing the full multi-zone flight/boat/road route when viewing Eastern Kingdoms or Kalimdor!
PluribusHivePathfinder.ZONE_CONTINENT_BOUNDS = {
	-- Eastern Kingdoms (cont = 1)
	["Tirisfal Glades"]      = { cont = 1, l = 38.0, t = 22.0, w = 13.5, h = 10.5 },
	["Undercity"]            = { cont = 1, l = 43.0, t = 27.5, w = 4.0,  h = 3.5  },
	["Silverpine Forest"]    = { cont = 1, l = 36.5, t = 31.5, w = 10.5, h = 11.5 },
	["Western Plaguelands"]  = { cont = 1, l = 49.5, t = 23.0, w = 10.5, h = 11.0 },
	["Eastern Plaguelands"]  = { cont = 1, l = 58.0, t = 21.5, w = 11.5, h = 11.0 },
	["Hillsbrad Foothills"]  = { cont = 1, l = 44.5, t = 36.0, w = 11.5, h = 9.0  },
	["The Hinterlands"]      = { cont = 1, l = 54.0, t = 34.0, w = 11.5, h = 10.0 },
	["Arathi Highlands"]     = { cont = 1, l = 52.0, t = 42.0, w = 10.5, h = 9.0  },
	["Wetlands"]             = { cont = 1, l = 47.0, t = 49.0, w = 12.5, h = 9.5  },
	["Dun Morogh"]           = { cont = 1, l = 41.5, t = 55.5, w = 12.5, h = 9.5  },
	["Ironforge"]            = { cont = 1, l = 46.5, t = 58.0, w = 3.5,  h = 3.0  },
	["Loch Modan"]           = { cont = 1, l = 53.0, t = 56.5, w = 9.5,  h = 8.5  },
	["Searing Gorge"]        = { cont = 1, l = 46.0, t = 63.0, w = 8.5,  h = 7.0  },
	["Badlands"]             = { cont = 1, l = 53.0, t = 63.5, w = 9.5,  h = 7.5  },
	["Burning Steppes"]      = { cont = 1, l = 48.0, t = 68.5, w = 9.5,  h = 7.5  },
	["Elwynn Forest"]        = { cont = 1, l = 39.0, t = 69.0, w = 10.5, h = 8.0  },
	["Stormwind City"]       = { cont = 1, l = 40.5, t = 70.5, w = 3.5,  h = 3.0  },
	["Westfall"]             = { cont = 1, l = 34.5, t = 74.5, w = 8.5,  h = 9.5  },
	["Redridge Mountains"]   = { cont = 1, l = 49.0, t = 73.5, w = 8.0,  h = 6.5  },
	["Duskwood"]             = { cont = 1, l = 42.5, t = 76.5, w = 9.5,  h = 7.5  },
	["Swamp of Sorrows"]     = { cont = 1, l = 54.0, t = 75.0, w = 9.5,  h = 7.5  },
	["Blasted Lands"]        = { cont = 1, l = 53.0, t = 80.5, w = 9.0,  h = 8.5  },
	["Stranglethorn Vale"]   = { cont = 1, l = 37.5, t = 82.0, w = 12.0, h = 14.5 },

	-- Kalimdor (cont = 2)
	["Teldrassil"]           = { cont = 2, l = 36.0, t = 9.5,  w = 10.5, h = 9.5  },
	["Darnassus"]            = { cont = 2, l = 38.0, t = 12.0, w = 3.5,  h = 3.0  },
	["Darkshore"]            = { cont = 2, l = 39.5, t = 21.0, w = 10.5, h = 14.0 },
	["Felwood"]              = { cont = 2, l = 46.5, t = 24.5, w = 9.5,  h = 13.0 },
	["Winterspring"]         = { cont = 2, l = 54.0, t = 18.0, w = 13.5, h = 13.5 },
	["Ashenvale"]            = { cont = 2, l = 43.0, t = 35.0, w = 13.5, h = 10.0 },
	["Azshara"]              = { cont = 2, l = 56.0, t = 31.5, w = 12.0, h = 10.5 },
	["Stonetalon Mountains"] = { cont = 2, l = 37.0, t = 42.5, w = 10.5, h = 11.5 },
	["The Barrens"]          = { cont = 2, l = 45.5, t = 44.0, w = 13.5, h = 18.5 },
	["Durotar"]              = { cont = 2, l = 56.5, t = 43.5, w = 9.0,  h = 11.5 },
	["Orgrimmar"]            = { cont = 2, l = 58.0, t = 44.0, w = 3.5,  h = 3.0  },
	["Mulgore"]              = { cont = 2, l = 40.5, t = 53.5, w = 9.5,  h = 11.0 },
	["Thunder Bluff"]        = { cont = 2, l = 43.5, t = 56.5, w = 3.5,  h = 3.0  },
	["Desolace"]             = { cont = 2, l = 33.5, t = 53.0, w = 10.0, h = 11.0 },
	["Dustwallow Marsh"]     = { cont = 2, l = 52.5, t = 59.0, w = 10.5, h = 10.0 },
	["Feralas"]              = { cont = 2, l = 32.5, t = 63.0, w = 13.5, h = 12.0 },
	["Thousand Needles"]     = { cont = 2, l = 46.5, t = 66.0, w = 12.5, h = 9.5  },
	["Tanaris"]              = { cont = 2, l = 50.0, t = 73.5, w = 12.5, h = 12.5 },
	["Un'Goro Crater"]       = { cont = 2, l = 43.0, t = 75.5, w = 9.0,  h = 9.5  },
	["Silithus"]             = { cont = 2, l = 35.0, t = 76.0, w = 9.5,  h = 11.0 },
}

-- Project a zone coordinate (0..100) onto either a matching zone map or a continent map ("Eastern Kingdoms" / "Kalimdor")
function PluribusHivePathfinder:ProjectCoordToViewedMap(zoneName, x, y, viewedZone)
	local cz = self:CanonicalZone(zoneName)
	local vz = self:CanonicalZone(viewedZone)
	if cz == vz then
		return tonumber(x) or 50, tonumber(y) or 50
	end
	local wantCont = nil
	if vz == "Eastern Kingdoms" then wantCont = 1
	elseif vz == "Kalimdor" then wantCont = 2 end
	if wantCont then
		local b = self.ZONE_CONTINENT_BOUNDS[cz]
		if b and b.cont == wantCont then
			local cx = b.l + ((tonumber(x) or 50) / 100) * b.w
			local cy = b.t + ((tonumber(y) or 50) / 100) * b.h
			return cx, cy
		end
	end
	return nil, nil
end

-- Returns { segments = { {x1,y1,x2,y2,mode,leg,legIdx}... }, pins = { {x,y,mode,label,zone,etaSec,waitSec,isSynced,isFinal,isNext,legIdx}... } }
-- for the currently viewed World Map (zone OR continent) or Minimap!
function PluribusHivePathfinder:GetRoutePathForMap(viewedZone, curZone, playerX, playerY)
	local route = self.activeRoute
	if not route or not route.legs or #route.legs == 0 then
		return { segments = {}, pins = {} }
	end

	local legs = route.legs
	local startIdx = math.max(1, self.activeLegIndex or 1)
	local segments = {}
	local pins = {}

	local prevX, prevY = nil, nil
	if curZone and playerX and playerY and (playerX > 0 or playerY > 0) then
		prevX, prevY = self:ProjectCoordToViewedMap(curZone, playerX, playerY, viewedZone)
	end

	for i = startIdx, #legs do
		local leg = legs[i]
		local lx, ly = self:ProjectCoordToViewedMap(leg.zone, leg.x, leg.y, viewedZone)
		local mode = tostring(leg.mode or "road"):lower()
		if lx and ly then
			if prevX and prevY then
				local dist = math.sqrt((lx - prevX) ^ 2 + (ly - prevY) ^ 2)
				if dist >= 0.4 then
					table.insert(segments, {
						x1 = prevX, y1 = prevY,
						x2 = lx, y2 = ly,
						mode = mode,
						leg = leg,
						legIdx = i,
					})
				end
			end
			table.insert(pins, {
				x = lx, y = ly,
				mode = mode,
				label = leg.label or leg.zone or "Waypoint",
				zone = leg.zone or viewedZone,
				etaSec = leg.etaSec or 0,
				waitSec = leg.waitSec or 0,
				isSynced = leg.isSynced == true,
				providerName = leg.providerName,
				providerClass = leg.providerClass,
				spellLabel = leg.spellLabel,
				helperPenaltySec = leg.helperPenaltySec or 0,
				nearbyHelpers = leg.nearbyHelpers or 0,
				isFinal = (i == #legs),
				isNext = (i == startIdx),
				legIdx = i,
			})
			prevX, prevY = lx, ly
		else
			prevX, prevY = nil, nil
		end
	end

	return { segments = segments, pins = pins }
end

-- Supports BOTH SetRouteTo(destName, destZone, destX, destY)
-- AND SetRouteTo(startZone, startX, startY, destZone, destX, destY, destName)
function PluribusHivePathfinder:SetRouteTo(a1, a2, a3, a4, a5, a6, a7)
	local startZone, px, py, destZone, destX, destY, destName
	if a5 ~= nil and a6 ~= nil then
		-- 6-7 arg signature: (startZone, startX, startY, destZone, destX, destY, destName)
		startZone = a1
		px = tonumber(a2) or 50
		py = tonumber(a3) or 50
		destZone = a4
		destX = tonumber(a5) or 50
		destY = tonumber(a6) or 50
		destName = a7 or destZone
	else
		-- 4 arg signature: (destName, destZone, destX, destY)
		destName = a1
		destZone = a2
		destX = tonumber(a3) or 50
		destY = tonumber(a4) or 50
		startZone = (GetRealZoneText and GetRealZoneText()) or "Elwynn Forest"
		px, py = 50, 50
		if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
			local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
			if ux and uy and (ux > 0 or uy > 0) then
				px, py = ux * 100, uy * 100
			end
		end
	end

	local route = self:ComputeRoute(startZone, px, py, destZone, destX, destY, { destName = destName })
	if route then
		route.startZone = self:CanonicalZone(startZone)
		route.startX = px
		route.startY = py
		route.totalSec = route.totalEtaSec or 0
		route.summary = self:BuildRouteSummary(route)
	end
	self.activeRoute = route
	self.activeLegIndex = 1
	self.activeLegStartedAt = time()
	if route and route.legs and route.legs[1] and _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.SyncNativeWaypointToActiveLeg then
		_G.PluribusHiveTerrainMesh.lastNativeSyncKey = nil
		_G.PluribusHiveTerrainMesh:SyncNativeWaypointToActiveLeg(route.legs[1])
	end
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_ROUTE_CHANGED", route) end)
	end
	return route
end

function PluribusHivePathfinder:ClearRoute()
	self.activeRoute = nil
	self.activeLegIndex = 1
	self.activeLegStartedAt = 0
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_ROUTE_CHANGED", nil) end)
	end
end

-- Returns current active leg, auto-advances when player reaches it, and records real leg travel times!
function PluribusHivePathfinder:GetActiveLeg(curZone, px, py)
	if not self.activeRoute or not self.activeRoute.legs or #self.activeRoute.legs == 0 then
		return nil
	end
	local canonCur = self:CanonicalZone(curZone)
	local legs = self.activeRoute.legs

	-- Auto-advance past reached legs (except the final destination) using calibrated zone yards
	local advanced = false
	while self.activeLegIndex < #legs do
		local leg = legs[self.activeLegIndex]
		local nextLeg = legs[self.activeLegIndex + 1]
		local reached = false
		if nextLeg and nextLeg.zone == canonCur and leg.zone ~= canonCur then
			reached = true
		elseif leg.zone == canonCur and px and py and (px > 0 or py > 0) then
			local d = NodeDistanceYards(px, py, leg.x, leg.y, canonCur)
			local reachRadius = (IsMounted and IsMounted()) and 50 or 38
			if d <= reachRadius then
				reached = true
			end
		end
		if reached then
			-- Passively learn real travel duration for road/water legs to continuously refine graph weights!
			if leg.fromNodeId and leg.nodeId and (leg.mode == "road" or leg.mode == "water") and (self.activeLegStartedAt or 0) > 0 then
				local elapsed = time() - self.activeLegStartedAt
				self:RecordObservedEdgeTime(leg.fromNodeId, leg.nodeId, elapsed, leg.etaSec or 0, true)
			end
			self.activeLegIndex = self.activeLegIndex + 1
			self.activeLegStartedAt = time()
			advanced = true
		else
			break
		end
	end

	local activeLeg = legs[self.activeLegIndex]
	if activeLeg and _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.SyncNativeWaypointToActiveLeg then
		_G.PluribusHiveTerrainMesh:SyncNativeWaypointToActiveLeg(activeLeg)
	end
	if advanced and _G.PluribusNavigationUI and _G.PluribusNavigationUI.RefreshWorldMapRoutePath then
		if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then
			_G.PluribusNavigationUI:RefreshWorldMapRoutePath()
		end
	end

	return activeLeg, self.activeLegIndex, #legs
end

function PluribusHivePathfinder:FormatLegSummary(leg)
	if not leg then return "" end
	local L = _G.PluribusL
	if leg.mode == "portal" then
		local who = leg.providerName and (" via " .. tostring(leg.providerName)) or ""
		return string.format("|cff60a5fa[%s]|r %s%s (~%ds)", L and L:Get("NAV_LEG_PORTAL") or "Mage Portal", leg.label, who, leg.etaSec or 45)
	elseif leg.mode == "summon" then
		local who = leg.providerName and (" via " .. tostring(leg.providerName)) or ""
		local penTxt = (leg.helperPenaltySec and leg.helperPenaltySec > 0) and string.format(", +%ds 2-Helper", leg.helperPenaltySec) or ""
		return string.format("|cffc084fc[%s]|r %s%s (~%ds%s)", L and L:Get("NAV_LEG_SUMMON") or "Warlock Summon", leg.label, who, leg.etaSec or 120, penTxt)
	elseif leg.mode == "flight" then
		local srcTag = leg.isSynced and "Hive" or (L and L:Get("NAV_ESTIMATED") or "Est.")
		return string.format("|cff38bdf8[%s]|r %s (%ds · %s)", L and L:Get("NAV_LEG_FLIGHT") or "Flight", leg.label, leg.etaSec or 0, srcTag)
	elseif leg.mode == "boat" or leg.mode == "zeppelin" then
		local kindTxt = (leg.mode == "zeppelin") and (L and L:Get("NAV_LEG_ZEPPELIN") or "Zeppelin") or (L and L:Get("NAV_LEG_BOAT") or "Boat")
		local syncTag = leg.isSynced and (L and L:Get("NAV_SYNCED") or "Guild-Synced") or (L and L:Get("NAV_ESTIMATED") or "Est.")
		return string.format("|cfffbbf24[%s]|r %s (%ds · %s)", kindTxt, leg.label, leg.waitSec or 0, syncTag)
	elseif leg.mode == "water" then
		return string.format("|cff22d3ee[%s]|r %s", L and L:Get("NAV_LEG_WATER") or "Water", leg.label)
	end
	return string.format("|cff4ade80[%s]|r %s", L and L:Get("NAV_LEG_ROAD") or "Road", leg.label)
end

-- Find nearest flight or dock/zeppelin node for live taxi & ship duration measurement
function PluribusHivePathfinder:FindNearestNodeByKinds(zone, x, y, kinds)
	local canon = self:CanonicalZone(zone)
	local bestId, bestDist = nil, 999999
	for id, n in pairs(self.NODES) do
		if n.zone == canon and kinds[n.kind] then
			local d = NodeDistanceYards(x, y, n.x, n.y)
			if d < bestDist then
				bestDist = d
				bestId = id
			end
		end
	end
	return bestId, bestDist
end

-- Live taxi flight & dock/zeppelin boarding tracker (runs inside the existing 0.25s OnUpdate slice)
function PluribusHivePathfinder:PollLiveTransit()
	local now = (GetTime and GetTime()) or 0
	local onTaxi = (UnitOnTaxi and UnitOnTaxi("player")) == true

	local curZone = self:CanonicalZone((GetRealZoneText and GetRealZoneText()) or "")
	local px, py = 50, 50
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end

	-- 1. Live Flight Duration Tracker
	if onTaxi and not self._wasOnTaxi then
		local pend = self._pendingTaxiFlight
		local isFreshPend = pend and (now - (pend.clickedAt or 0)) <= 12
		local fromId = (isFreshPend and pend.from) or self._taxiOriginNode
		if not fromId then
			local nearFP, distFP = self:FindNearestNodeByKinds(curZone, px, py, { flight = true, city = true, dock = true, zeppelin = true })
			if nearFP and distFP <= 350 and self.NODES[nearFP] and self.NODES[nearFP].fpNames then
				fromId = nearFP
			end
		end
		self._activeFlight = {
			from = fromId,
			to = isFreshPend and pend.to or nil,
			startAt = now,
		}
		self._pendingTaxiFlight = nil
	elseif (not onTaxi) and self._wasOnTaxi and self._activeFlight then
		local af = self._activeFlight
		self._activeFlight = nil
		local dur = math.floor((now - (af.startAt or now)) + 0.5)
		local toId = af.to
		if not toId then
			local nearFP, distFP = self:FindNearestNodeByKinds(curZone, px, py, { flight = true, city = true, dock = true, zeppelin = true })
			if nearFP and distFP <= 350 and self.NODES[nearFP] and self.NODES[nearFP].fpNames then
				toId = nearFP
			end
		end
		if af.from and toId and af.from ~= toId and dur >= 10 and dur <= 1500 then
			local ok, avg = self:RecordFlightTime(af.from, toId, dur, PluribusHive:GetPlayerShortName(), true)
			if ok and _G.PluribusUtils then
				local fromLbl = (self.NODES[af.from] and self.NODES[af.from].label) or af.from
				local toLbl = (self.NODES[toId] and self.NODES[toId].label) or toId
				_G.PluribusUtils:Info(string.format("Flugzeit gemessen & mit Gilde geteilt: %s -> %s (%ds, Ø %ds)", fromLbl, toLbl, dur, avg or dur), "Navigation")
			end
		end
	end
	self._wasOnTaxi = onTaxi

	-- 2. Live Dock / Zeppelin Boarding & Departure Tracker (measures actual boat/zeppelin crossing duration!)
	if not onTaxi and curZone ~= "" then
		local dockId, dockDist = self:FindNearestNodeByKinds(curZone, px, py, { dock = true, zeppelin = true })
		if dockId and dockDist <= 130 then
			local st = self._dockBoardState
			if not st or st.nodeId ~= dockId then
				self._dockBoardState = {
					nodeId = dockId,
					zone = curZone,
					nearAt = now,
					departedAt = nil,
					wasClose = (dockDist <= 55),
				}
			else
				st.nearAt = now
				if dockDist <= 55 then
					st.wasClose = true
					st.departedAt = nil -- Still on the pier / boarding platform
				elseif st.wasClose and not st.departedAt then
					-- Boat / zeppelin just pulled away from the pier!
					st.departedAt = now
				end
			end
		elseif self._dockBoardState then
			local st = self._dockBoardState
			if st.zone == curZone and st.wasClose and not st.departedAt and (now - (st.nearAt or 0)) <= 8 then
				st.departedAt = st.nearAt
			elseif (now - (st.nearAt or 0)) > 180 then
				self._dockBoardState = nil
			end
		end
	end
end

-- Passive Boat/Zeppelin crossing detector: measures actual sail duration AND broadcasts SHIPTIME + SHIPSYNC to guild!
function PluribusHivePathfinder:DetectShipCrossing(prevZone, newZone)
	local p = self:CanonicalZone(prevZone)
	local n = self:CanonicalZone(newZone)
	if p == n then return end
	local pairsToRoute = {
		["Stranglethorn Vale->The Barrens"] = "booty_ratchet",
		["The Barrens->Stranglethorn Vale"] = "booty_ratchet",
		["Wetlands->Darkshore"]             = "menethil_auberdine",
		["Darkshore->Wetlands"]             = "menethil_auberdine",
		["Wetlands->Dustwallow Marsh"]      = "menethil_theramore",
		["Dustwallow Marsh->Wetlands"]      = "menethil_theramore",
		["Durotar->Tirisfal Glades"]        = "org_uc_zep",
		["Tirisfal Glades->Durotar"]        = "org_uc_zep",
		["Durotar->Stranglethorn Vale"]     = "org_gg_zep",
		["Stranglethorn Vale->Durotar"]     = "org_gg_zep",
		["Tirisfal Glades->Stranglethorn Vale"] = "uc_gg_zep",
		["Stranglethorn Vale->Tirisfal Glades"] = "uc_gg_zep",
	}
	local rid = pairsToRoute[p .. "->" .. n]
	if rid then
		local nowT = (GetTime and GetTime()) or 0
		local me = PluribusHive:GetPlayerShortName()
		local st = self._dockBoardState
		if st and st.zone == p and st.departedAt then
			local measuredSail = math.floor((nowT - st.departedAt) + 0.5)
			local ok, avgSail = self:RecordShipDuration(rid, measuredSail, nil, me, true)
			if ok and _G.PluribusUtils then
				local route = self.SHIP_ROUTES[rid]
				_G.PluribusUtils:Info(string.format("Überfahrt gemessen & mit Gilde geteilt: %s (%ds, Ø %ds)",
					(route and route.name) or rid, measuredSail, avgSail or measuredSail), "Navigation")
			end
		end
		self._dockBoardState = nil

		-- Arrival timestamp minus learned sail duration gives exact departure anchor!
		local sailSec = self:GetShipDurationSec(rid)
		local depTs = time() - (sailSec or 60)
		self:RecordShipSighting(rid, depTs, me, true)
	end
end

-- ============================================================================
-- IMMEDIATE BACKGROUND PRE-COMPUTATION & CONTINUOUS REFINEMENT ENGINE
-- ============================================================================
function PluribusHivePathfinder:BuildPrecomputeQueue(reason)
	local myZone = self:CanonicalZone((GetRealZoneText and GetRealZoneText()) or "Elwynn Forest")
	local px, py = 50, 50
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end
	local faction = self:GetPlayerFaction()
	local startNodeId = self:FindNearestNode(myZone, px, py, faction)
	if not startNodeId then return end

	local seen = {}
	local queue = {}
	local function EnqueueTarget(destZone, dx, dy, destName, forceRecompute)
		local cZone = self:CanonicalZone(destZone)
		local targetNode = self:FindNearestNode(cZone, dx or 50, dy or 50, faction)
		if not targetNode or targetNode == startNodeId or seen[targetNode] then return end
		seen[targetNode] = true
		table.insert(queue, {
			startZone = myZone,
			sx = px,
			sy = py,
			destZone = cZone,
			dx = dx or 50,
			dy = dy or 50,
			destName = destName or cZone,
			forceRecompute = forceRecompute == true,
		})
	end

	-- Priority 1: Active To-Do & Shopping List farm targets (instant 1-click navigation!)
	if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.GetAggregatedShoppingMaterials
		and _G.PluribusHiveCompute and _G.PluribusHiveCompute.GetFarmRouteForItem then
		local ok, matMap = pcall(function() return _G.PluribusHiveProfessions:GetAggregatedShoppingMaterials() end)
		if ok and type(matMap) == "table" then
			for _, m in pairs(matMap) do
				local route = _G.PluribusHiveCompute:GetFarmRouteForItem(m.itemID)
				if route and route.zone then
					EnqueueTarget(route.zone, route.x, route.y, "To-Do: " .. route.zone, reason ~= "startup")
				end
			end
		end
	end

	-- Priority 2: Cached Leveling & Farming Guide stops
	if _G.PluribusHiveCompute and _G.PluribusHiveCompute.GetComputeDB then
		local cdb = _G.PluribusHiveCompute:GetComputeDB()
		for _, gKey in ipairs({ "LEVELING", "FARMING" }) do
			local g = cdb and cdb.cachedGuides and cdb.cachedGuides[gKey]
			if g and g.steps then
				for i = 1, math.min(8, #g.steps) do
					local st = g.steps[i]
					if st and st.zone then
						EnqueueTarget(st.zone, st.x, st.y, st.zone, reason ~= "startup")
					end
				end
			end
		end
	end

	-- Priority 3: All faction-accessible Azeroth graph hubs (capitals, docks, zeppelins, flight masters)
	local forceHubs = (reason == "refinement" or reason == "flight_point" or reason == "flight_time" or reason == "ship_time" or reason == "ship_sync" or reason == "observed_travel")
	for id, n in pairs(self.NODES) do
		if id ~= startNodeId and (n.faction == "NEUTRAL" or n.faction == faction) then
			EnqueueTarget(n.zone, n.x, n.y, n.label, forceHubs)
		end
	end

	self.precomputeQueue = queue
	self.precomputeCursor = 1
	self.backgroundRunning = (#queue > 0)
end

function PluribusHivePathfinder:ScheduleRouteRefinement(reason)
	local pdb = self:GetDB()
	pdb.cacheMeta.generation = (pdb.cacheMeta.generation or 1) + 1
	self:BuildPrecomputeQueue(reason or "refinement")
end

-- Computes 1-2 queued routes per slice while idle (pauses immediately in combat or FPS < 45!)
function PluribusHivePathfinder:StepBackgroundPrecompute()
	if not self.backgroundRunning or not self.precomputeQueue or self.precomputeCursor > #self.precomputeQueue then
		self.backgroundRunning = false
		return
	end
	if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
		return
	end
	if GetFramerate then
		local fps = GetFramerate() or 0
		if fps > 0 and fps < 45 then return end
	end

	local processed = 0
	while processed < 2 and self.precomputeCursor <= #self.precomputeQueue do
		local item = self.precomputeQueue[self.precomputeCursor]
		self.precomputeCursor = self.precomputeCursor + 1
		if item then
			pcall(function()
				PluribusHivePathfinder:ComputeRoute(
					item.startZone, item.sx, item.sy,
					item.destZone, item.dx, item.dy,
					{ destName = item.destName, bypassCache = item.forceRecompute }
				)
			end)
			processed = processed + 1
		end
	end

	if self.precomputeCursor > #self.precomputeQueue then
		self.backgroundRunning = false
	end
end

function PluribusHivePathfinder:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:GetDB()
	if _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.Initialize then
		_G.PluribusHiveTerrainMesh:Initialize()
	end

	-- Receive guild-synced boat/zeppelin timings, flight durations & edge speed factors
	if PluribusHive and PluribusHive.RegisterHandler then
		PluribusHive:RegisterHandler("SHIPSYNC", function(sender, body)
			local rid, tsStr = tostring(body or ""):match("^([^|]+)|(%d+)")
			if rid and tsStr then
				PluribusHivePathfinder:RecordShipSighting(rid, tonumber(tsStr), sender, false)
				PluribusHivePathfinder:ScheduleRouteRefinement("ship_sync")
			end
		end)
		-- Receive measured actual flight durations from guildmates
		PluribusHive:RegisterHandler("FLIGHTTIME", function(sender, body)
			local u, v, secStr = tostring(body or ""):match("^([^|]+)|([^|]+)|(%d+)")
			if u and v and secStr then
				PluribusHivePathfinder:RecordFlightTime(u, v, tonumber(secStr), sender, false)
			end
		end)
		-- Receive measured actual boat/zeppelin sail & cycle durations from guildmates
		PluribusHive:RegisterHandler("SHIPTIME", function(sender, body)
			local rid, sailStr, cycStr = tostring(body or ""):match("^([^|]+)|(%d+)|(%d+)")
			if rid and sailStr then
				local sVal = tonumber(sailStr)
				local cVal = tonumber(cycStr)
				PluribusHivePathfinder:RecordShipDuration(rid, (sVal and sVal > 0) and sVal or nil, (cVal and cVal > 0) and cVal or nil, sender, false)
			end
		end)
		-- Receive compact peer sync batch of recorded flight & boat/zeppelin travel times
		PluribusHive:RegisterHandler("TRANSITBATCH", function(sender, body)
			local kind, listStr = tostring(body or ""):match("^([FS])|(.*)$")
			local updated = false
			if kind == "F" and listStr then
				for u, v, secStr in listStr:gmatch("([^,>]+)>([^,=]+)=(%d+)") do
					if PluribusHivePathfinder:RecordFlightTime(u, v, tonumber(secStr), sender, false, true) then
						updated = true
					end
				end
				if updated then
					PluribusHivePathfinder:ScheduleRouteRefinement("flight_time")
				end
			elseif kind == "S" and listStr then
				for rid, sailStr, cycStr in listStr:gmatch("([^,=]+)=(%d+):(%d+)") do
					local sVal, cVal = tonumber(sailStr), tonumber(cycStr)
					if PluribusHivePathfinder:RecordShipDuration(rid, (sVal and sVal > 0) and sVal or nil, (cVal and cVal > 0) and cVal or nil, sender, false, true) then
						updated = true
					end
				end
				if updated then
					PluribusHivePathfinder:ScheduleRouteRefinement("ship_time")
				end
			end
		end)
		-- Receive peer-observed real edge travel speed factors to refine routes guild-wide
		PluribusHive:RegisterHandler("EDGETIME", function(_, body)
			local u, v, facStr = tostring(body or ""):match("^([^|]+)|([^|]+)|([^|]+)$")
			local fac = tonumber(facStr)
			if u and v and fac and fac >= 0.45 and fac <= 2.20 then
				local pdb = PluribusHivePathfinder:GetDB()
				local key = CanonicalEdgeKey(u, v)
				local rec = pdb.edgeObservations[key] or { avgFactor = 1.0, samples = 0, updatedAt = 0 }
				local n = math.min(20, rec.samples or 0)
				rec.avgFactor = math.floor((((rec.avgFactor or 1.0) * n + fac) / (n + 1)) * 1000 + 0.5) / 1000
				rec.samples = (rec.samples or 0) + 1
				rec.updatedAt = time()
				pdb.edgeObservations[key] = rec
			end
		end)
	end

	-- Secure post-hook on TakeTaxiNode to capture exact origin & destination flight node when flying
	if hooksecurefunc and _G.TakeTaxiNode then
		pcall(hooksecurefunc, "TakeTaxiNode", function(slotIndex)
			local destName = TaxiNodeName and TaxiNodeName(slotIndex)
			local destId = destName and PluribusHivePathfinder:MatchFlightNodeByName(destName) or nil
			PluribusHivePathfinder._pendingTaxiFlight = {
				from = PluribusHivePathfinder._taxiOriginNode,
				to = destId,
				clickedAt = (GetTime and GetTime()) or 0,
			}
		end)
	end

	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_TODO_CHANGED", function()
			PluribusHivePathfinder:BuildPrecomputeQueue("todo_changed")
		end)
		_G.PluribusMessaging:Subscribe("HIVE_COMPUTE_DONE", function()
			PluribusHivePathfinder:BuildPrecomputeQueue("guide_updated")
		end)
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(3, 8), function()
					PluribusHivePathfinder:ShareRecordedTransitTimes()
				end)
			end
		end)
	end

	local lastZone = (GetRealZoneText and GetRealZoneText()) or ""
	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "TAXIMAP_OPENED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LEVEL_UP" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, event)
		if event == "TAXIMAP_OPENED" then
			local newly = PluribusHivePathfinder:ScanOpenTaxiMap()
			if newly > 0 then
				if _G.PluribusUtils then
					_G.PluribusUtils:Info(string.format("Pathfinder: %d Flugpunkt(e) gespeichert — Routen werden optimiert.", newly), "Navigation")
				end
				PluribusHivePathfinder:ScheduleRouteRefinement("flight_point")
			end
		elseif event == "PLAYER_LEAVING_WORLD" then
			local st = PluribusHivePathfinder._dockBoardState
			if st and not st.departedAt then
				-- Loading screen started while boarding/standing at dock -> mark departure anchor
				local nowT = (GetTime and GetTime()) or 0
				st.departedAt = math.max(st.nearAt or nowT, nowT - 20)
			end
		elseif event == "PLAYER_LEVEL_UP" then
			PluribusHivePathfinder:ScheduleRouteRefinement("level_up")
		elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
			local cur = (GetRealZoneText and GetRealZoneText()) or ""
			if lastZone ~= "" and cur ~= "" and cur ~= lastZone then
				PluribusHivePathfinder:DetectShipCrossing(lastZone, cur)
			end
			if cur ~= "" then lastZone = cur end
			if C_Timer and C_Timer.After then
				C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 1.5 or 1.0, function()
					PluribusHivePathfinder:BuildPrecomputeQueue(event == "PLAYER_ENTERING_WORLD" and "startup" or "zone_change")
				end)
			else
				PluribusHivePathfinder:BuildPrecomputeQueue("startup")
			end
		end
	end)

	-- Zero-lag background precompute, live flight/ship timing telemetry & periodic continuous refinement ticker
	local sliceAccum = 0
	local refineAccum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		sliceAccum = sliceAccum + (elapsed or 0)
		refineAccum = refineAccum + (elapsed or 0)
		if sliceAccum >= 0.25 then
			sliceAccum = 0
			PluribusHivePathfinder:PollLiveTransit()
			PluribusHivePathfinder:StepBackgroundPrecompute()
		end
		-- Continuous periodic refinement pass every 60s (updates live boat/zeppelin windows & learned edge weights)
		if refineAccum >= 60 then
			refineAccum = 0
			if not PluribusHivePathfinder.backgroundRunning then
				PluribusHivePathfinder:ScheduleRouteRefinement("refinement")
			end
		end
	end)
end

return PluribusHivePathfinder
