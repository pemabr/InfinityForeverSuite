-- PluribusHive Terrain NavMesh, Complete Azeroth Road/Barrier Topology & Game-Internal Map Integration
-- Replaces straight-line navigation with true terrain-, road-, and obstacle-aware pathfinding:
--   1. Complete Classic 1.60.1 Road, Pass, Bridge, Tunnel & Barrier topology for ALL Azeroth zones & capitals
--   2. Game-internal API integration:
--        - C_Map.GetWorldPosFromMapPos (real 3D world-yard zone calibration per uiMapID)
--        - C_Map.GetMapLinksForMap & C_AreaPoiInfo.GetAreaPOIForMap (internal gates, caves, bridges, ferries)
--        - C_Map.SetUserWaypoint + C_SuperTrack (turn-by-turn native waypoint sync to current road/mesh leg)
--   3. Live Walkable Breadcrumb NavMesh Recorder + Guild HiveMind Mesh Sync (MESHEDGE over PLBHIVE)
--   4. Runtime Stuck / Wall-Bump Obstacle Detector with automatic local re-routing around blocked terrain

PluribusHiveTerrainMesh = {
	initialized = false,
	zoneDimsCache = {},       -- [canonZone] = { w = yards, h = yards, measured = bool }
	internalNodesCache = {},  -- [canonZone] = { { id, x, y, label, kind }... }
	sessionObstacles = {},    -- [canonZone] = { { x1, y1, x2, y2, label, expiresAt }... }
	lastCell = nil,           -- { zone, gx, gy, x, y, t, surface }
	stuckTracker = nil,       -- { x, y, t, lastLegKey, bumps }
	lastNativeSyncKey = nil,
	lastRerouteAt = 0,
}
_G.PluribusHiveTerrainMesh = PluribusHiveTerrainMesh

local MESH_CELL_SIZE = 1.5 -- 1.5% map cell resolution (~35-65 yards depending on zone size)
local MAX_MESH_CELLS_PER_ZONE = 180
local MAX_MESH_EDGES_PER_ZONE = 360

-- Accurate Classic Azeroth zone dimensions in world yards (width, height)
-- Automatically refined at runtime via C_Map.GetWorldPosFromMapPos whenever available!
PluribusHiveTerrainMesh.ZONE_WORLD_DIMS = {
	-- Eastern Kingdoms
	["Elwynn Forest"]       = { w = 3470, h = 2314 },
	["Stormwind City"]      = { w = 1344, h = 896  },
	["Westfall"]            = { w = 3500, h = 2333 },
	["Redridge Mountains"]  = { w = 2170, h = 1447 },
	["Duskwood"]            = { w = 2700, h = 1800 },
	["Stranglethorn Vale"]  = { w = 6381, h = 4254 },
	["Dun Morogh"]          = { w = 4925, h = 3283 },
	["Ironforge"]           = { w = 790,  h = 527  },
	["Loch Modan"]          = { w = 2758, h = 1839 },
	["Wetlands"]            = { w = 4135, h = 2756 },
	["Arathi Highlands"]    = { w = 3600, h = 2400 },
	["Hillsbrad Foothills"] = { w = 3200, h = 2133 },
	["Alterac Mountains"]   = { w = 2800, h = 1867 },
	["Silverpine Forest"]   = { w = 4200, h = 2800 },
	["Tirisfal Glades"]     = { w = 4518, h = 3012 },
	["Undercity"]           = { w = 959,  h = 640  },
	["Western Plaguelands"] = { w = 4300, h = 2867 },
	["Eastern Plaguelands"] = { w = 3870, h = 2580 },
	["The Hinterlands"]     = { w = 3850, h = 2567 },
	["Badlands"]            = { w = 2487, h = 1658 },
	["Searing Gorge"]       = { w = 2231, h = 1487 },
	["Burning Steppes"]     = { w = 2929, h = 1953 },
	["Swamp of Sorrows"]    = { w = 2294, h = 1529 },
	["Blasted Lands"]       = { w = 3350, h = 2233 },
	["Deadwind Pass"]       = { w = 2500, h = 1667 },
	-- Kalimdor
	["Durotar"]             = { w = 5287, h = 3525 },
	["Orgrimmar"]           = { w = 1402, h = 935  },
	["The Barrens"]         = { w = 10133, h = 6756 },
	["Mulgore"]             = { w = 5137, h = 3425 },
	["Thunder Bluff"]       = { w = 1043, h = 695  },
	["Teldrassil"]          = { w = 5091, h = 3394 },
	["Darnassus"]           = { w = 1058, h = 705  },
	["Darkshore"]           = { w = 6550, h = 4367 },
	["Ashenvale"]           = { w = 5766, h = 3844 },
	["Stonetalon Mountains"]= { w = 4883, h = 3256 },
	["Desolace"]            = { w = 4496, h = 2997 },
	["Thousand Needles"]    = { w = 4400, h = 2933 },
	["Dustwallow Marsh"]    = { w = 5250, h = 3500 },
	["Tanaris"]             = { w = 6900, h = 4600 },
	["Feralas"]             = { w = 6950, h = 4633 },
	["Un'Goro Crater"]      = { w = 3700, h = 2467 },
	["Silithus"]            = { w = 3483, h = 2322 },
	["Felwood"]             = { w = 5750, h = 3833 },
	["Winterspring"]        = { w = 7100, h = 4733 },
	["Azshara"]             = { w = 5070, h = 3380 },
	["Moonglade"]           = { w = 2308, h = 1539 },
}

-- Extra German/English aliases & continent bounds for zones not in the base table
local EXTRA_ALIASES = {
	["alteracgebirge"] = "Alterac Mountains",
	["gebirgspass der totenwinde"] = "Deadwind Pass",
	["mondlichtung"] = "Moonglade",
	["moonglade"] = "Moonglade",
	["alterac mountains"] = "Alterac Mountains",
	["deadwind pass"] = "Deadwind Pass",
}

local EXTRA_CONTINENT_BOUNDS = {
	["Alterac Mountains"] = { cont = 1, l = 45.0, t = 31.5, w = 8.5, h = 7.0 },
	["Deadwind Pass"]     = { cont = 1, l = 51.0, t = 76.5, w = 5.0, h = 6.5 },
	["Moonglade"]         = { cont = 2, l = 50.5, t = 18.0, w = 6.5, h = 6.0 },
}

-- ============================================================================
-- COMPLETE CLASSIC AZEROTH ROAD & BARRIER EXTENSIONS (ALL REMAINING 22+ ZONES!)
-- ============================================================================
local EXTRA_ZONE_ROADS = {
	["Ironforge"] = {
		nodes = {
			gate        = { x = 14.5, y = 84.5, label = "Eisenschmiede-Tor" },
			commons     = { x = 28.0, y = 72.0, label = "Das allgemeine Viertel" },
			ah          = { x = 25.0, y = 74.5, label = "Auktionshaus" },
			bank        = { x = 35.5, y = 60.5, label = "Bank von Eisenschmiede" },
			mystic      = { x = 27.0, y = 26.0, label = "Mystikerviertel" },
			forlorn     = { x = 50.0, y = 18.0, label = "Die düstere Höhle" },
			military    = { x = 67.0, y = 72.0, label = "Militärviertel" },
			tinker      = { x = 68.5, y = 46.5, label = "Tüftlerstadt (Tiefenbahn)" },
			hall_exp    = { x = 74.0, y = 24.0, label = "Halle der Forscher" },
			great_forge = { x = 50.0, y = 44.0, label = "Die Große Schmiede" },
			high_seat   = { x = 40.5, y = 55.5, label = "Der Hohe Sitz" },
		},
		edges = {
			{ "gate", "commons" }, { "commons", "ah" }, { "commons", "bank" },
			{ "bank", "mystic" }, { "mystic", "forlorn" }, { "forlorn", "hall_exp" },
			{ "hall_exp", "tinker" }, { "tinker", "military" }, { "military", "commons" },
			{ "bank", "high_seat" }, { "high_seat", "great_forge" },
			{ "great_forge", "tinker" }, { "great_forge", "mystic" }, { "great_forge", "military" },
		},
	},
	["Loch Modan"] = {
		nodes = {
			north_pass  = { x = 21.0, y = 16.0, label = "Nordpass (Dun Morogh)" },
			south_pass  = { x = 20.5, y = 66.0, label = "Südpass (Dun Morogh)" },
			valley_kings= { x = 24.0, y = 72.5, label = "Tal der Könige" },
			thelsamar   = { x = 34.5, y = 49.0, label = "Thelsamar" },
			algaz_pass  = { x = 24.5, y = 18.5, label = "Dun-Algaz-Tunnel (Sumpfland)" },
			dam_west    = { x = 44.0, y = 14.0, label = "Steinwerkdamm West" },
			dam_east    = { x = 55.5, y = 13.5, label = "Steinwerkdamm Ost" },
			farstrider  = { x = 68.0, y = 55.0, label = "Oststraße (Weltenwanderer)" },
			lodge       = { x = 82.0, y = 64.5, label = "Jagdhütte der Weltenwanderer" },
			south_road  = { x = 47.0, y = 74.0, label = "Südstraße Loch Modan" },
			badlands_p  = { x = 47.0, y = 89.0, label = "Ödland-Pass" },
		},
		edges = {
			{ "north_pass", "algaz_pass" }, { "north_pass", "thelsamar" },
			{ "south_pass", "valley_kings" }, { "valley_kings", "thelsamar" },
			{ "thelsamar", "dam_west" }, { "dam_west", "dam_east" },
			{ "dam_east", "farstrider" }, { "farstrider", "lodge" },
			{ "valley_kings", "south_road" }, { "south_road", "badlands_p" },
			{ "south_road", "farstrider" },
		},
	},
	["Tirisfal Glades"] = {
		nodes = {
			deathknell  = { x = 31.5, y = 65.5, label = "Todesend-Straße" },
			west_road   = { x = 41.5, y = 55.0, label = "Weststraße Tirisfal" },
			brill       = { x = 60.5, y = 52.0, label = "Brill Kreuzung" },
			uc_zep      = { x = 61.6, y = 58.8, label = "Zeppelinturm Unterstadt" },
			uc_gate     = { x = 61.8, y = 65.2, label = "Unterstadt-Tor" },
			silverpine_p= { x = 55.0, y = 78.5, label = "Silberwald-Straße" },
			east_road   = { x = 73.5, y = 56.5, label = "Oststraße Bollwerk" },
			bulwark     = { x = 83.5, y = 69.5, label = "Das Bollwerk (WPL)" },
			sm_road     = { x = 78.5, y = 42.5, label = "Scharlachrotes Kloster Straße" },
			sm_gate     = { x = 85.2, y = 32.5, label = "Scharlachrotes Kloster" },
		},
		edges = {
			{ "deathknell", "west_road" }, { "west_road", "brill" },
			{ "brill", "uc_zep" }, { "uc_zep", "uc_gate" },
			{ "uc_gate", "silverpine_p" }, { "brill", "east_road" },
			{ "east_road", "bulwark" }, { "east_road", "sm_road" },
			{ "sm_road", "sm_gate" },
		},
	},
	["Undercity"] = {
		nodes = {
			courtyard   = { x = 66.0, y = 11.0, label = "Eingangshof (Aufzüge)" },
			outer_n     = { x = 66.0, y = 26.0, label = "Äußerer Ring Nord" },
			trade_ring  = { x = 66.0, y = 44.0, label = "Handelsviertel (Zentrum)" },
			apothecarium= { x = 52.0, y = 72.0, label = "Das Apothekarium" },
			war_quarter = { x = 78.0, y = 74.0, label = "Kriegsviertel" },
			magic_q     = { x = 82.0, y = 26.0, label = "Magieviertel" },
			rogue_q     = { x = 84.0, y = 56.0, label = "Schurkenviertel" },
			sewer_exit  = { x = 44.0, y = 30.0, label = "Kanalisations-Ausgang" },
		},
		edges = {
			{ "courtyard", "outer_n" }, { "outer_n", "trade_ring" },
			{ "trade_ring", "apothecarium" }, { "trade_ring", "war_quarter" },
			{ "trade_ring", "magic_q" }, { "trade_ring", "rogue_q" },
			{ "outer_n", "sewer_exit" }, { "outer_n", "magic_q" },
			{ "apothecarium", "war_quarter" }, { "war_quarter", "rogue_q" },
		},
	},
	["Silverpine Forest"] = {
		nodes = {
			tirisfal_p  = { x = 57.0, y = 8.0,  label = "Tirisfal-Straße" },
			north_road  = { x = 53.0, y = 26.0, label = "Nordstraße Silberwald" },
			sepulcher_j = { x = 49.5, y = 41.5, label = "Grabmal-Abzweigung" },
			sepulcher   = { x = 45.6, y = 42.6, label = "Das Grabmal" },
			sfk_road    = { x = 45.5, y = 60.0, label = "Burg Schattenfang Straße" },
			pyrewood    = { x = 44.5, y = 71.0, label = "Lohenscheit" },
			ambermill   = { x = 57.0, y = 62.5, label = "Mühlenbern-Straße" },
			hillsbrad_p = { x = 66.5, y = 79.0, label = "Vorgebirge-Pass" },
		},
		edges = {
			{ "tirisfal_p", "north_road" }, { "north_road", "sepulcher_j" },
			{ "sepulcher_j", "sepulcher" }, { "sepulcher_j", "sfk_road" },
			{ "sfk_road", "pyrewood" }, { "sepulcher_j", "ambermill" },
			{ "ambermill", "hillsbrad_p" },
		},
	},
	["Alterac Mountains"] = {
		nodes = {
			south_pass  = { x = 58.0, y = 86.0, label = "Südpass (Tarrens Mühle)" },
			mid_road    = { x = 51.0, y = 62.0, label = "Hauptstraße Alterac" },
			dalaran_rd  = { x = 28.0, y = 76.0, label = "Dalaran-Straße" },
			ruins_j     = { x = 42.5, y = 46.0, label = "Ruinen von Alterac" },
			chillwind_p = { x = 79.0, y = 43.0, label = "Zugwind-Pass (WPL)" },
		},
		edges = {
			{ "south_pass", "mid_road" }, { "mid_road", "dalaran_rd" },
			{ "mid_road", "ruins_j" }, { "mid_road", "chillwind_p" },
		},
	},
	["The Hinterlands"] = {
		nodes = {
			hillsbrad_p = { x = 9.0,  y = 58.0, label = "Vorgebirge-Pass" },
			aerie_peak  = { x = 14.5, y = 45.5, label = "Nistgipfel" },
			mid_road    = { x = 35.0, y = 55.0, label = "Zentralstraße Hinterland" },
			quel_danil  = { x = 32.0, y = 46.5, label = "Quel'Danil-Straße" },
			seradane    = { x = 54.0, y = 48.0, label = "Oststraße Jintha'Alor" },
			jintha_base = { x = 62.0, y = 68.0, label = "Jintha'Alor Aufgang" },
			revantusk   = { x = 77.5, y = 79.5, label = "Dorf der Bruchhauer" },
		},
		edges = {
			{ "hillsbrad_p", "aerie_peak" }, { "hillsbrad_p", "mid_road" },
			{ "aerie_peak", "mid_road" }, { "mid_road", "quel_danil" },
			{ "mid_road", "seradane" }, { "seradane", "jintha_base" },
			{ "jintha_base", "revantusk" },
		},
	},
	["Burning Steppes"] = {
		nodes = {
			redridge_p  = { x = 77.0, y = 75.5, label = "Rotkamm-Pass" },
			morgan      = { x = 84.3, y = 68.3, label = "Morgans Wacht" },
			east_road   = { x = 68.0, y = 56.0, label = "Oststraße Brennende Steppe" },
			flame_crest = { x = 65.0, y = 24.5, label = "Flammenkamm" },
			mid_road    = { x = 47.0, y = 50.0, label = "Hauptstraße Schwarzfels" },
			brm_gate    = { x = 29.4, y = 38.2, label = "Schwarzfels-Eingang" },
		},
		edges = {
			{ "redridge_p", "morgan" }, { "morgan", "east_road" },
			{ "east_road", "flame_crest" }, { "east_road", "mid_road" },
			{ "mid_road", "brm_gate" }, { "flame_crest", "brm_gate" },
		},
	},
	["Swamp of Sorrows"] = {
		nodes = {
			deadwind_p  = { x = 6.0,  y = 56.0, label = "Pass der Totenwinde" },
			west_road   = { x = 25.0, y = 53.0, label = "Weststraße Sumpf" },
			stonard     = { x = 46.5, y = 54.5, label = "Steinard" },
			blasted_p   = { x = 34.0, y = 78.0, label = "Pass Verwüstete Lande" },
			east_road   = { x = 64.0, y = 55.0, label = "Oststraße Tempel" },
			st_bridge   = { x = 70.0, y = 53.5, label = "Versunkener Tempel Brücke" },
			coast_road  = { x = 85.0, y = 56.0, label = "Nebelschilfküste" },
		},
		edges = {
			{ "deadwind_p", "west_road" }, { "west_road", "stonard" },
			{ "west_road", "blasted_p" }, { "stonard", "east_road" },
			{ "east_road", "st_bridge" }, { "east_road", "coast_road" },
		},
	},
	["Blasted Lands"] = {
		nodes = {
			swamp_pass  = { x = 51.5, y = 11.0, label = "Sumpf-Pass" },
			north_road  = { x = 55.0, y = 21.5, label = "Nordstraße Verwüstete Lande" },
			nethergarde = { x = 65.5, y = 24.3, label = "Burg Nethergarde" },
			mid_road    = { x = 54.0, y = 38.5, label = "Hauptstraße Dunkles Portal" },
			dark_portal = { x = 58.5, y = 56.0, label = "Das Dunkle Portal" },
			tainted_scar= { x = 35.0, y = 46.0, label = "Faulende Narbe Pfad" },
		},
		edges = {
			{ "swamp_pass", "north_road" }, { "north_road", "nethergarde" },
			{ "north_road", "mid_road" }, { "mid_road", "dark_portal" },
			{ "mid_road", "tainted_scar" },
		},
	},
	["Deadwind Pass"] = {
		nodes = {
			dusk_pass   = { x = 14.0, y = 52.0, label = "Dämmerwald-Pass" },
			mid_road    = { x = 44.0, y = 58.0, label = "Passstraße Totenwinde" },
			karazhan_j  = { x = 47.0, y = 72.0, label = "Karazhan-Zufahrt" },
			swamp_pass  = { x = 75.0, y = 56.0, label = "Sumpf-des-Elends-Pass" },
		},
		edges = {
			{ "dusk_pass", "mid_road" }, { "mid_road", "karazhan_j" },
			{ "mid_road", "swamp_pass" },
		},
	},
	["Mulgore"] = {
		nodes = {
			narache     = { x = 45.0, y = 78.0, label = "Camp Narache Straße" },
			bloodhoof   = { x = 47.5, y = 60.0, label = "Dorf der Bluthufe" },
			tb_south    = { x = 41.5, y = 36.5, label = "Donnerfels-Aufzug Süd" },
			tb_east     = { x = 47.0, y = 49.8, label = "Donnerfels-Straße" },
			barrens_gate= { x = 68.5, y = 60.0, label = "Brachland-Tor" },
		},
		edges = {
			{ "narache", "bloodhoof" }, { "bloodhoof", "tb_east" },
			{ "tb_east", "tb_south" }, { "bloodhoof", "barrens_gate" },
		},
	},
	["Thunder Bluff"] = {
		nodes = {
			lift_s      = { x = 35.0, y = 64.0, label = "Südaufzug" },
			lift_n      = { x = 51.0, y = 26.0, label = "Nordaufzug" },
			center      = { x = 46.0, y = 52.0, label = "Zentrale Anhöhe" },
			elder_rise  = { x = 72.0, y = 28.0, label = "Anhöhe der Ältesten" },
			spirit_rise = { x = 25.0, y = 24.0, label = "Anhöhe der Geister" },
			hunter_rise = { x = 58.0, y = 80.0, label = "Anhöhe der Jäger" },
		},
		edges = {
			{ "lift_s", "center" }, { "lift_n", "center" },
			{ "center", "elder_rise" }, { "center", "spirit_rise" },
			{ "center", "hunter_rise" },
		},
	},
	["Teldrassil"] = {
		nodes = {
			shadowglen  = { x = 59.0, y = 42.0, label = "Laubschattental Straße" },
			dolanaar    = { x = 55.5, y = 59.5, label = "Dolanaar" },
			west_road   = { x = 43.0, y = 56.0, label = "Weststraße Darnassus" },
			darn_gate   = { x = 36.5, y = 52.0, label = "Darnassus-Tor" },
			rutheran    = { x = 58.4, y = 94.0, label = "Rut'theran Hafen" },
		},
		edges = {
			{ "shadowglen", "dolanaar" }, { "dolanaar", "west_road" },
			{ "west_road", "darn_gate" }, { "darn_gate", "rutheran" },
		},
	},
	["Darnassus"] = {
		nodes = {
			gate        = { x = 30.0, y = 41.0, label = "Portal Rut'theran" },
			temple      = { x = 38.0, y = 80.0, label = "Tempel des Mondes" },
			warrior     = { x = 57.0, y = 42.0, label = "Terrasse der Krieger" },
			tradesmen   = { x = 60.0, y = 66.0, label = "Terrasse der Händler" },
			craftsmen   = { x = 60.0, y = 22.0, label = "Terrasse der Handwerker" },
			cenarion    = { x = 37.0, y = 22.0, label = "Enklave des Cenarius" },
		},
		edges = {
			{ "gate", "warrior" }, { "warrior", "tradesmen" },
			{ "tradesmen", "temple" }, { "warrior", "craftsmen" },
			{ "craftsmen", "cenarion" }, { "cenarion", "gate" },
		},
	},
	["Darkshore"] = {
		nodes = {
			north_road  = { x = 52.0, y = 24.0, label = "Nordstraße Dunkelküste" },
			auberdine   = { x = 37.0, y = 44.0, label = "Auberdine" },
			aub_dock    = { x = 33.2, y = 40.2, label = "Auberdine Pier" },
			mid_road    = { x = 41.0, y = 60.0, label = "Hauptstraße Dunkelküste" },
			south_road  = { x = 43.0, y = 78.0, label = "Südstraße Eschental" },
			ashen_pass  = { x = 43.5, y = 94.0, label = "Eschental-Pass" },
		},
		edges = {
			{ "north_road", "auberdine" }, { "auberdine", "aub_dock" },
			{ "auberdine", "mid_road" }, { "mid_road", "south_road" },
			{ "south_road", "ashen_pass" },
		},
	},
	["Stonetalon Mountains"] = {
		nodes = {
			barrens_p   = { x = 80.0, y = 88.0, label = "Brachland-Pass" },
			webwinder   = { x = 60.0, y = 68.0, label = "Weberpass Straße" },
			sun_rock    = { x = 46.5, y = 59.5, label = "Sonnenfels" },
			winds_road  = { x = 53.0, y = 46.0, label = "Steinkrallen-Hauptstraße" },
			peak        = { x = 36.5, y = 14.0, label = "Steinkrallengipfel" },
			charred_val = { x = 34.0, y = 68.0, label = "Verbranntes Tal (Desolace-Pass)" },
		},
		edges = {
			{ "barrens_p", "webwinder" }, { "webwinder", "sun_rock" },
			{ "webwinder", "winds_road" }, { "sun_rock", "winds_road" },
			{ "winds_road", "peak" }, { "sun_rock", "charred_val" },
		},
	},
	["Dustwallow Marsh"] = {
		nodes = {
			barrens_p   = { x = 29.0, y = 47.0, label = "Brachland-Pass" },
			brackenwall = { x = 36.0, y = 31.5, label = "Brackenwall" },
			mid_road    = { x = 46.0, y = 48.0, label = "Sumpfstraße Theramore" },
			sentry_pt   = { x = 55.5, y = 51.0, label = "Wachposten-Brücke" },
			theramore   = { x = 66.5, y = 51.5, label = "Insel Theramore" },
			ther_dock   = { x = 71.2, y = 56.4, label = "Theramore Hafen" },
			onyxia_rd   = { x = 52.0, y = 66.0, label = "Onyxias Hort Pfad" },
			onyxia      = { x = 52.2, y = 76.1, label = "Onyxias Hort" },
		},
		edges = {
			{ "barrens_p", "brackenwall" }, { "barrens_p", "mid_road" },
			{ "brackenwall", "mid_road" }, { "mid_road", "sentry_pt" },
			{ "sentry_pt", "theramore" }, { "theramore", "ther_dock" },
			{ "mid_road", "onyxia_rd" }, { "onyxia_rd", "onyxia" },
		},
	},
	["Silithus"] = {
		nodes = {
			ungoro_pass = { x = 80.0, y = 18.0, label = "Un'Goro-Pass" },
			north_road  = { x = 64.0, y = 26.0, label = "Nordstraße Silithus" },
			cenarion    = { x = 50.6, y = 34.5, label = "Burg Cenarius" },
			mid_road    = { x = 46.0, y = 54.0, label = "Südstraße Ahn'Qiraj" },
			aq_approach = { x = 35.0, y = 76.0, label = "Skarabäuswall Straße" },
			aq_gates    = { x = 28.6, y = 92.4, label = "Tore von Ahn'Qiraj" },
		},
		edges = {
			{ "ungoro_pass", "north_road" }, { "north_road", "cenarion" },
			{ "cenarion", "mid_road" }, { "mid_road", "aq_approach" },
			{ "aq_approach", "aq_gates" },
		},
	},
	["Winterspring"] = {
		nodes = {
			timbermaw   = { x = 28.0, y = 35.5, label = "Holzschlundfeste Ausgang" },
			west_road   = { x = 44.0, y = 36.5, label = "Weststraße Winterquell" },
			everlook    = { x = 61.5, y = 37.5, label = "Ewige Warte" },
			south_road  = { x = 58.0, y = 58.0, label = "Südstraße Frostsäbler" },
			darkwhisper = { x = 59.0, y = 78.0, label = "Dunkelflüsterschlucht" },
			north_road  = { x = 52.0, y = 22.0, label = "Nordpfad Frostsäblerfelsen" },
		},
		edges = {
			{ "timbermaw", "west_road" }, { "west_road", "everlook" },
			{ "west_road", "north_road" }, { "everlook", "south_road" },
			{ "south_road", "darkwhisper" },
		},
	},
	["Azshara"] = {
		nodes = {
			ashen_pass  = { x = 11.9, y = 77.6, label = "Eschental-Pass (Talrendis)" },
			valormok    = { x = 22.0, y = 52.0, label = "Valormok Straße" },
			mid_road    = { x = 34.0, y = 52.0, label = "Zentralstraße Azshara" },
			ruins_n     = { x = 42.0, y = 34.0, label = "Nordstraße Eldarath" },
			south_coast = { x = 48.0, y = 72.0, label = "Südstraße Küste" },
			azuregos    = { x = 56.1, y = 80.5, label = "Südküste Azshara" },
		},
		edges = {
			{ "ashen_pass", "valormok" }, { "valormok", "mid_road" },
			{ "mid_road", "ruins_n" }, { "mid_road", "south_coast" },
			{ "south_coast", "azuregos" },
		},
	},
	["Moonglade"] = {
		nodes = {
			timbermaw   = { x = 36.0, y = 72.0, label = "Holzschlundfeste Tunnel" },
			nighthaven  = { x = 54.0, y = 40.0, label = "Nachthafen" },
			lake_west   = { x = 42.0, y = 52.0, label = "Westufer Elune'ara" },
		},
		edges = {
			{ "timbermaw", "lake_west" }, { "lake_west", "nighthaven" },
		},
	},
}

local EXTRA_ZONE_BARRIERS = {
	["Ironforge"] = {
		-- Central lava pit around The Great Forge (forces routing around ring bridges!)
		{ 43.0, 38.0, 57.0, 38.0, "Lavagraben Nord" },
		{ 43.0, 50.0, 57.0, 50.0, "Lavagraben Süd" },
		{ 43.0, 38.0, 43.0, 50.0, "Lavagraben West" },
		{ 57.0, 38.0, 57.0, 50.0, "Lavagraben Ost" },
	},
	["Loch Modan"] = {
		-- The Loch central lake (forces routing around west/east shores or over Stonewrought Dam!)
		{ 47.0, 22.0, 58.0, 62.0, "Der Loch (See)" },
		{ 58.0, 22.0, 47.0, 62.0, "Der Loch (Ostbecken)" },
	},
	["Westfall"] = {
		-- Steep eastern ridge separating Moonbrook and Duskwood road
		{ 52.0, 56.0, 58.0, 74.0, "Westfall-Felskante" },
	},
	["Duskwood"] = {
		-- Twilight Grove mountain crater ring
		{ 44.0, 32.0, 52.0, 41.0, "Dämmerhain-Kraterwand" },
	},
	["Wetlands"] = {
		-- Southern mountain spine blocking direct Dun Modr / Dun Algaz line
		{ 22.0, 66.0, 46.0, 66.0, "Südmassiv Sumpfland" },
		{ 30.0, 24.0, 44.0, 42.0, "Nordklippe Sumpfland" },
	},
	["Arathi Highlands"] = {
		-- Thoradin's Wall (only open at gate 21.0, 30.0) & Stromgarde walls
		{ 21.0, 12.0, 21.0, 26.0, "Thoradinswall Nord" },
		{ 21.0, 34.0, 21.0, 60.0, "Thoradinswall Süd" },
		{ 23.0, 54.0, 30.0, 66.0, "Stromgarde-Mauern" },
	},
	["Hillsbrad Foothills"] = {
		-- Northern Alterac mountain wall & Southshore bay
		{ 24.0, 28.0, 52.0, 28.0, "Alterac-Steilwand" },
	},
	["Tirisfal Glades"] = {
		-- Brightwater Lake & Undercity ruins outer wall (open at main gate 61.8, 65.2)
		{ 65.0, 42.0, 74.0, 52.0, "Glanzwassersee" },
		{ 55.0, 65.0, 59.5, 65.0, "Ruinenmauer Lordaeron West" },
		{ 64.5, 65.0, 70.0, 65.0, "Ruinenmauer Lordaeron Ost" },
	},
	["Undercity"] = {
		-- Inner green slime canal (forces using ring bridges!)
		{ 58.0, 34.0, 74.0, 34.0, "Schleimkanal Nord" },
		{ 58.0, 54.0, 74.0, 54.0, "Schleimkanal Süd" },
	},
	["Silverpine Forest"] = {
		-- Lordamere Lake (east) & Shadowfang mountain wall
		{ 58.0, 22.0, 72.0, 52.0, "Lordameresee" },
	},
	["Western Plaguelands"] = {
		-- Darrowmere Lake (only passable via Caer Darrow bridge 65.5, 73.5!)
		{ 64.0, 62.0, 74.0, 70.0, "Darromersee Nord" },
		{ 64.0, 77.0, 74.0, 86.0, "Darromersee Süd" },
	},
	["Eastern Plaguelands"] = {
		-- Plaguewood & mountain divide around Stratholme
		{ 22.0, 24.0, 29.0, 36.0, "Pestwald-Felsgrat West" },
		{ 37.0, 20.0, 46.0, 34.0, "Pestwald-Felsgrat Ost" },
	},
	["The Hinterlands"] = {
		-- Central mountain ridge separating Aerie Peak & Jintha'Alor
		{ 40.0, 36.0, 54.0, 44.0, "Hinterland-Gebirgsgrat" },
	},
	["Burning Steppes"] = {
		-- Blackrock lava chasm & northern cliffs
		{ 42.0, 30.0, 58.0, 42.0, "Lavaspalte Brennende Steppe" },
	},
	["Swamp of Sorrows"] = {
		-- Pool of Tears deep swamp around Sunken Temple (use bridge at 70.0, 53.5!)
		{ 64.0, 44.0, 76.0, 48.0, "Tränenteich Nord" },
		{ 64.0, 58.0, 76.0, 62.0, "Tränenteich Süd" },
	},
	["Blasted Lands"] = {
		-- Tainted Scar chasm cliffs
		{ 40.0, 34.0, 48.0, 56.0, "Faulende Narbe Klippe" },
	},
	["Durotar"] = {
		-- Thunder Ridge / Southfury canyon cliffs
		{ 42.0, 20.0, 48.0, 34.0, "Donnergrat Klippe" },
		{ 39.0, 46.0, 46.0, 66.0, "Klingenhügel-Felsgrat" },
	},
	["The Barrens"] = {
		-- Stonetalon mountain wall & Wailing Caverns ridge
		{ 36.0, 34.0, 42.0, 52.0, "West-Steilwand Brachland" },
		{ 54.0, 50.0, 62.0, 64.0, "Ostgrat Brachland" },
	},
	["Mulgore"] = {
		-- Thunder Bluff plateau cliffs (only accessible via South/North lifts!)
		{ 35.0, 24.0, 48.0, 32.0, "Donnerfels-Steilwand" },
	},
	["Thunder Bluff"] = {
		-- Chasms between mesas (forces crossing wooden bridges via Center!)
		{ 36.0, 34.0, 42.0, 44.0, "Schlucht Geisteranhöhe" },
		{ 54.0, 34.0, 64.0, 44.0, "Schlucht Ältestenanhöhe" },
	},
	["Teldrassil"] = {
		-- Lake Al'Ameth & Darnassus cliffs
		{ 50.0, 66.0, 62.0, 76.0, "See von Al'Ameth" },
	},
	["Darkshore"] = {
		-- Eastern mountain wall
		{ 52.0, 42.0, 56.0, 78.0, "Ostgebirge Dunkelküste" },
	},
	["Ashenvale"] = {
		-- Central mountain ridge separating Astranaar & Felwood pass
		{ 42.0, 30.0, 52.0, 46.0, "Eschental-Felsgrat" },
	},
	["Stonetalon Mountains"] = {
		-- Deep mountain canyon walls
		{ 40.0, 34.0, 50.0, 54.0, "Steinkrallen-Canyonwand" },
	},
	["Desolace"] = {
		-- Maraudon canyon cliffs & Mannoroc ridge
		{ 42.0, 62.0, 56.0, 78.0, "Desolace-Felswand" },
	},
	["Dustwallow Marsh"] = {
		-- Theramore sea strait (forces crossing Sentry Point Bridge at 55.5, 51.0!)
		{ 58.0, 34.0, 62.0, 48.0, "Theramore-Meeresenge Nord" },
		{ 58.0, 55.0, 62.0, 70.0, "Theramore-Meeresenge Süd" },
	},
	["Felwood"] = {
		-- Toxic crater & eastern mountain wall
		{ 48.0, 34.0, 56.0, 50.0, "Teufelswald-Klippe" },
	},
	["Winterspring"] = {
		-- Ice Thistle mountain ridge
		{ 46.0, 44.0, 54.0, 66.0, "Eisdistel-Kamm" },
	},
	["Azshara"] = {
		-- High coastal cliffs separating plateau from Bay of Storms
		{ 44.0, 42.0, 62.0, 54.0, "Azshara-Steilküste" },
	},
	["Silithus"] = {
		-- Hive'Regal & Hive'Zora rock walls
		{ 54.0, 58.0, 68.0, 72.0, "Bau'Regal Felswand" },
	},
}

-- ============================================================================
-- REAL WORLD-YARD DISTANCE CALIBRATION (C_Map.GetWorldPosFromMapPos + Fallback)
-- ============================================================================
function PluribusHiveTerrainMesh:CalibrateCurrentZoneDims()
	local pf = _G.PluribusHivePathfinder
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
		return nil
	end
	local okM, mapID = pcall(C_Map.GetBestMapForUnit, "player")
	if not okM or not mapID or mapID <= 0 then return nil end

	local zoneName = (GetRealZoneText and GetRealZoneText()) or ""
	if C_Map.GetMapInfo then
		local okI, info = pcall(C_Map.GetMapInfo, mapID)
		if okI and info and info.name and info.name ~= "" then
			zoneName = info.name
		end
	end
	local cz = pf and pf:CanonicalZone(zoneName) or zoneName
	if not cz or cz == "" then return nil end

	local cached = self.zoneDimsCache[cz]
	if cached and cached.measured then
		return cached
	end

	-- Query WoW's internal 3D world-space transform at two reference map points (0.2,0.2) and (0.8,0.8)
	local ok1, _, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.2, 0.2))
	local ok2, _, p2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.8, 0.8))
	if ok1 and ok2 and p1 and p2 and p1.x and p2.x and p1.y and p2.y then
		-- In WoW world coords: world Y runs West(+)/East(-), world X runs North(+)/South(-)
		local spanW = math.abs(p2.y - p1.y) / 0.6
		local spanH = math.abs(p2.x - p1.x) / 0.6
		if spanW >= 350 and spanW <= 25000 and spanH >= 250 and spanH <= 25000 then
			local dims = { w = math.floor(spanW + 0.5), h = math.floor(spanH + 0.5), measured = true, mapID = mapID }
			self.zoneDimsCache[cz] = dims
			return dims
		end
	end
	return nil
end

function PluribusHiveTerrainMesh:GetZoneDims(zoneName)
	local pf = _G.PluribusHivePathfinder
	local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(zoneName)) or tostring(zoneName or "")
	local dims = self.zoneDimsCache[cz] or self.ZONE_WORLD_DIMS[cz]
	if dims then return dims.w, dims.h end
	return 3200, 2133 -- Standard Classic zone fallback (~32 yds/1% X, ~21.3 yds/1% Y)
end

function PluribusHiveTerrainMesh:DistanceYards(zoneName, ax, ay, bx, by)
	local w, h = self:GetZoneDims(zoneName)
	local dx = (((bx or 50) - (ax or 50)) / 100) * w
	local dy = (((by or 50) - (ay or 50)) / 100) * h
	return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================================
-- GAME-INTERNAL MAP WAYPOINT & PORTAL INGESTION (MapLinks, AreaPOIs, TaxiNodes)
-- ============================================================================
function PluribusHiveTerrainMesh:ScanInternalMapWaypoints(mapID, zoneName)
	local pf = _G.PluribusHivePathfinder
	local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(zoneName)) or tostring(zoneName or "")
	if cz == "" then return {} end

	if (not mapID or mapID <= 0) and C_Map and C_Map.GetBestMapForUnit then
		local okM, curMid = pcall(C_Map.GetBestMapForUnit, "player")
		if okM and curMid and curMid > 0 then
			local curZone = (GetRealZoneText and GetRealZoneText()) or ""
			if pf and pf:CanonicalZone(curZone) == cz then
				mapID = curMid
			end
		end
	end
	if not mapID or mapID <= 0 then
		return self.internalNodesCache[cz] or {}
	end
	if self.internalNodesCache[cz] and #self.internalNodesCache[cz] > 0 then
		return self.internalNodesCache[cz]
	end

	local collected = {}
	local seenCoord = {}
	local function PushNode(id, x, y, label, kind)
		if type(x) ~= "number" or type(y) ~= "number" then return end
		if x <= 0.5 or x >= 99.5 or y <= 0.5 or y >= 99.5 then return end
		local key = string.format("%d:%d", math.floor(x * 2), math.floor(y * 2))
		if seenCoord[key] then return end
		seenCoord[key] = true
		table.insert(collected, {
			id = id,
			x = math.floor(x * 10 + 0.5) / 10,
			y = math.floor(y * 10 + 0.5) / 10,
			label = (label and label ~= "") and tostring(label) or (cz .. " Wegpunkt"),
			kind = kind or "poi",
		})
	end

	-- 1. WoW Internal Map Links (zone border gates, dungeon portals, elevators, caves, trams)
	if C_Map and C_Map.GetMapLinksForMap then
		local ok, links = pcall(C_Map.GetMapLinksForMap, mapID)
		if ok and type(links) == "table" then
			for idx, lnk in ipairs(links) do
				if lnk and lnk.position and lnk.position.x and lnk.position.y then
					PushNode("maplink_" .. idx, lnk.position.x * 100, lnk.position.y * 100, lnk.name, "maplink")
				end
			end
		end
	end

	-- 2. WoW Internal Area POIs (bridges, towns, crossroads, docks, passes)
	if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
		local ok, poiIDs = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
		if ok and type(poiIDs) == "table" then
			for _, poiID in ipairs(poiIDs) do
				local okI, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
				if okI and info and info.position and info.position.x and info.position.y then
					PushNode("poi_" .. tostring(poiID), info.position.x * 100, info.position.y * 100, info.name, "poi")
				end
			end
		end
	end

	-- 3. WoW Internal Taxi/Flight Master Positions on this Map
	if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
		local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
		if ok and type(nodes) == "table" then
			for idx, tn in ipairs(nodes) do
				if tn and tn.position and tn.position.x and tn.position.y then
					PushNode("taxi_" .. idx, tn.position.x * 100, tn.position.y * 100, tn.name, "flight")
				end
			end
		end
	end

	self.internalNodesCache[cz] = collected
	return collected
end

-- ============================================================================
-- PERSISTENT WALKABLE TERRAIN NAVMESH (BREADCRUMB GRAPH + HIVEMIND SYNC)
-- ============================================================================
function PluribusHiveTerrainMesh:GetMeshDB()
	local pf = _G.PluribusHivePathfinder
	if pf and pf.GetDB then
		local pdb = pf:GetDB()
		pdb.terrainMesh = pdb.terrainMesh or {}
		return pdb.terrainMesh
	end
	self._fallbackMesh = self._fallbackMesh or {}
	return self._fallbackMesh
end

local function QuantizeCell(x, y)
	local gx = math.max(0, math.min(66, math.floor((tonumber(x) or 50) / MESH_CELL_SIZE)))
	local gy = math.max(0, math.min(66, math.floor((tonumber(y) or 50) / MESH_CELL_SIZE)))
	local cx = math.floor(((gx + 0.5) * MESH_CELL_SIZE) * 10 + 0.5) / 10
	local cy = math.floor(((gy + 0.5) * MESH_CELL_SIZE) * 10 + 0.5) / 10
	return gx, gy, cx, cy, tostring(gx) .. ":" .. tostring(gy)
end

local function CanonicalMeshEdgeKey(k1, k2)
	if k1 <= k2 then return k1 .. "|" .. k2 end
	return k2 .. "|" .. k1
end

function PluribusHiveTerrainMesh:GetZoneMesh(zoneName, createIfMissing)
	local pf = _G.PluribusHivePathfinder
	local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(zoneName)) or tostring(zoneName or "")
	if cz == "" then return nil end
	local mdb = self:GetMeshDB()
	if not mdb[cz] and createIfMissing then
		mdb[cz] = { cells = {}, edges = {}, cellCount = 0, edgeCount = 0 }
	end
	return mdb[cz]
end

function PluribusHiveTerrainMesh:RecordWalkableEdge(zoneName, x1, y1, x2, y2, surface, broadcast)
	local pf = _G.PluribusHivePathfinder
	local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(zoneName)) or tostring(zoneName or "")
	if cz == "" then return false end

	local gx1, gy1, cx1, cy1, k1 = QuantizeCell(x1, y1)
	local gx2, gy2, cx2, cy2, k2 = QuantizeCell(x2, y2)
	if k1 == k2 then return false end
	-- Reject teleports / jumps across non-adjacent cells (must be within 2 cells Chebyshev distance)
	if math.abs(gx2 - gx1) > 2 or math.abs(gy2 - gy1) > 2 then return false end

	local zm = self:GetZoneMesh(cz, true)
	local now = time()

	if not zm.cells[k1] then
		if (zm.cellCount or 0) >= MAX_MESH_CELLS_PER_ZONE then return false end
		zm.cells[k1] = { x = cx1, y = cy1, hits = 1, surface = surface or "ground", t = now }
		zm.cellCount = (zm.cellCount or 0) + 1
	else
		zm.cells[k1].hits = math.min(255, (zm.cells[k1].hits or 1) + 1)
		zm.cells[k1].t = now
	end

	if not zm.cells[k2] then
		if (zm.cellCount or 0) >= MAX_MESH_CELLS_PER_ZONE then return false end
		zm.cells[k2] = { x = cx2, y = cy2, hits = 1, surface = surface or "ground", t = now }
		zm.cellCount = (zm.cellCount or 0) + 1
	else
		zm.cells[k2].hits = math.min(255, (zm.cells[k2].hits or 1) + 1)
		zm.cells[k2].t = now
	end

	local ek = CanonicalMeshEdgeKey(k1, k2)
	local edge = zm.edges[ek]
	if not edge then
		if (zm.edgeCount or 0) >= MAX_MESH_EDGES_PER_ZONE then return false end
		zm.edges[ek] = { a = k1, b = k2, hits = 1, surface = surface or "ground", t = now }
		zm.edgeCount = (zm.edgeCount or 0) + 1
		edge = zm.edges[ek]
	else
		edge.hits = math.min(255, (edge.hits or 1) + 1)
		edge.t = now
	end

	-- Share verified walkable ground corridor with guildmates once traversed twice (zero spam!)
	if broadcast and edge.hits == 2 and PluribusHive and PluribusHive.SendBackground then
		local surfCode = (surface == "water") and "W" or "G"
		local payload = string.format("%s|%s|%s|%s", cz, k1, k2, surfCode)
		PluribusHive:SendBackground("MESHEDGE", payload, "ME:" .. cz .. ":" .. ek, "GUILD")
	end
	return true
end

function PluribusHiveTerrainMesh:ImportGuildMeshEdge(zoneName, k1, k2, surfCode)
	local gx1, gy1 = tostring(k1 or ""):match("^(%d+):(%d+)$")
	local gx2, gy2 = tostring(k2 or ""):match("^(%d+):(%d+)$")
	gx1, gy1, gx2, gy2 = tonumber(gx1), tonumber(gy1), tonumber(gx2), tonumber(gy2)
	if not (gx1 and gy1 and gx2 and gy2) then return false end
	if gx1 > 66 or gy1 > 66 or gx2 > 66 or gy2 > 66 then return false end
	local x1 = (gx1 + 0.5) * MESH_CELL_SIZE
	local y1 = (gy1 + 0.5) * MESH_CELL_SIZE
	local x2 = (gx2 + 0.5) * MESH_CELL_SIZE
	local y2 = (gy2 + 0.5) * MESH_CELL_SIZE
	return self:RecordWalkableEdge(zoneName, x1, y1, x2, y2, (surfCode == "W") and "water" or "ground", false)
end

-- ============================================================================
-- RUNTIME STUCK / OBSTACLE WALL-BUMP DETECTOR (AUTO-REROUTE AROUND WALLS!)
-- ============================================================================
function PluribusHiveTerrainMesh:AddSessionObstacle(zoneName, px, py, facingRad, label)
	local pf = _G.PluribusHivePathfinder
	local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(zoneName)) or tostring(zoneName or "")
	if cz == "" then return end
	self.sessionObstacles[cz] = self.sessionObstacles[cz] or {}
	local list = self.sessionObstacles[cz]

	-- Place a short perpendicular barrier segment ~1.2% in front of the player along their blocked heading
	local dirX = -math.sin(facingRad or 0)
	local dirY = -math.cos(facingRad or 0)
	local cx = px + dirX * 1.1
	local cy = py + dirY * 1.1
	local perpX = -dirY * 1.6
	local perpY = dirX * 1.6

	table.insert(list, {
		x1 = cx - perpX,
		y1 = cy - perpY,
		x2 = cx + perpX,
		y2 = cy + perpY,
		label = label or "Erkanntes Hindernis",
		expiresAt = time() + 600,
	})
	while #list > 24 do table.remove(list, 1) end
end

function PluribusHiveTerrainMesh:SegmentHitsSessionObstacle(zoneName, x1, y1, x2, y2)
	local pf = _G.PluribusHivePathfinder
	if not pf then return false, nil end
	local cz = pf:CanonicalZone(zoneName)
	local list = self.sessionObstacles[cz]
	if not list or #list == 0 then return false, nil end
	local now = time()
	for i = #list, 1, -1 do
		local ob = list[i]
		if ob.expiresAt and ob.expiresAt < now then
			table.remove(list, i)
		elseif pf:SegmentsIntersect(x1, y1, x2, y2, ob.x1, ob.y1, ob.x2, ob.y2) then
			return true, ob.label
		end
	end
	return false, nil
end

function PluribusHiveTerrainMesh:SegmentBlocked(zoneName, x1, y1, x2, y2)
	local pf = _G.PluribusHivePathfinder
	if not pf then return false, nil end
	local hitStatic, reasonStatic = pf:SegmentHitsBarrier(zoneName, x1, y1, x2, y2)
	if hitStatic then return true, reasonStatic end
	return self:SegmentHitsSessionObstacle(zoneName, x1, y1, x2, y2)
end

-- ============================================================================
-- TURN-BY-TURN NATIVE WOW WAYPOINT SYNC (C_Map.SetUserWaypoint + C_SuperTrack)
-- ============================================================================
function PluribusHiveTerrainMesh:SyncNativeWaypointToActiveLeg(leg)
	if not leg or not leg.x or not leg.y then return false end
	if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
		return false
	end

	local pf = _G.PluribusHivePathfinder
	local curZone = pf and pf:CanonicalZone((GetRealZoneText and GetRealZoneText()) or "") or ""
	local legZone = pf and pf:CanonicalZone(leg.zone or "") or ""
	if curZone == "" or legZone == "" or curZone ~= legZone then
		return false
	end

	local mapID = 0
	if C_Map.GetBestMapForUnit then
		local okM, mid = pcall(C_Map.GetBestMapForUnit, "player")
		if okM and mid and mid > 0 then mapID = mid end
	end
	if mapID <= 0 then return false end

	local key = string.format("%d:%.1f:%.1f", mapID, leg.x, leg.y)
	if self.lastNativeSyncKey == key then return true end
	self.lastNativeSyncKey = key

	pcall(function()
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, leg.x / 100, leg.y / 100))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)
		end
	end)
	return true
end

-- ============================================================================
-- HYBRID TERRAIN-AWARE INTRA-ZONE NAVMESH ROUTER (ROADS + MESH + MAP LINKS)
-- ============================================================================
function PluribusHiveTerrainMesh:ComputeTerrainPath(zone, sx, sy, dx, dy, speeds, opts)
	opts = opts or {}
	local pf = _G.PluribusHivePathfinder
	if not pf then return nil end

	local cz = pf:CanonicalZone(zone)
	local landSpeed = (speeds and speeds.landSpeed) or 7.0
	local waterSpeed = (speeds and speeds.waterSpeed) or 4.72
	local directDist = self:DistanceYards(cz, sx, sy, dx, dy)
	local directBlocked, blockedBy = self:SegmentBlocked(cz, sx, sy, dx, dy)

	local roadNet = pf.ZONE_ROADS and pf.ZONE_ROADS[cz]
	local zoneMesh = self:GetZoneMesh(cz, false)
	local internalNodes = self:ScanInternalMapWaypoints(opts.mapID, cz)

	local hasMesh = zoneMesh and (zoneMesh.edgeCount or 0) > 0
	local hasInternal = internalNodes and #internalNodes > 0

	-- Very short completely unobstructed stretch (< 75 yds): direct walk to destination
	if (not roadNet and not hasMesh and not hasInternal) or (directDist <= 75 and not directBlocked) then
		local eta = math.max(1, math.floor(directDist / landSpeed))
		return {
			{
				label = opts.destName or cz,
				zone = cz,
				x = dx,
				y = dy,
				mode = "road",
				isRoad = false,
				distYards = math.floor(directDist),
				etaSec = eta,
			},
		}, eta, false, nil
	end

	-- Assemble unified multi-layer zone navmesh:
	--   Layer A: Built-in Roads, Bridges, Gates, Tunnels & Mountain Passes (0.68x cost)
	--   Layer B: Verified Walkable Breadcrumb Mesh (learned + guild-synced) (0.82x cost)
	--   Layer C: Game-Internal MapLinks / AreaPOIs / TaxiNodes (auto-bridged unobstructed)
	--   Layer D: Unverified Off-Road Fallback (1.55x cost, 35.0x blocked through walls/mountains!)
	local pts = {
		__START__ = { x = sx, y = sy, label = "Start", layer = "end" },
		__END__   = { x = dx, y = dy, label = opts.destName or cz, layer = "end" },
	}
	local allNodeIds = {}

	if roadNet and roadNet.nodes then
		for rid, rn in pairs(roadNet.nodes) do
			local nid = "r:" .. tostring(rid)
			pts[nid] = { x = rn.x, y = rn.y, label = rn.label or rid, layer = "road" }
			table.insert(allNodeIds, nid)
		end
	end

	if hasMesh and zoneMesh.cells then
		for ck, cell in pairs(zoneMesh.cells) do
			local nid = "m:" .. tostring(ck)
			pts[nid] = { x = cell.x, y = cell.y, label = "Pfad (" .. cz .. ")", layer = "mesh", surface = cell.surface }
			table.insert(allNodeIds, nid)
		end
	end

	if hasInternal then
		for _, inNode in ipairs(internalNodes) do
			local nid = "i:" .. tostring(inNode.id)
			pts[nid] = { x = inNode.x, y = inNode.y, label = inNode.label, layer = "internal" }
			table.insert(allNodeIds, nid)
		end
	end

	local adj = {}
	local function AddLocalEdge(u, v, cost, mode, isRoad, distYds)
		adj[u] = adj[u] or {}
		table.insert(adj[u], { to = v, cost = cost, mode = mode or "road", isRoad = isRoad == true, distYds = distYds })
	end

	local ROAD_MULT = 0.68
	local MESH_MULT = 0.82
	local OFFROAD_MULT = 1.55
	local BARRIER_PENALTY = 35.0

	-- 1. Primary Road Network edges (guaranteed passable corridors, strongly preferred!)
	if roadNet and roadNet.edges then
		for _, e in ipairs(roadNet.edges) do
			local u, v = "r:" .. tostring(e[1]), "r:" .. tostring(e[2])
			if pts[u] and pts[v] then
				local d = self:DistanceYards(cz, pts[u].x, pts[u].y, pts[v].x, pts[v].y)
				local hitObs = self:SegmentHitsSessionObstacle(cz, pts[u].x, pts[u].y, pts[v].x, pts[v].y)
				local cost = (d / landSpeed) * (hitObs and BARRIER_PENALTY or ROAD_MULT)
				AddLocalEdge(u, v, cost, "road", true, d)
				AddLocalEdge(v, u, cost, "road", true, d)
			end
		end
	end

	-- 2. Verified Walkable Breadcrumb NavMesh edges (learned from real movement & guild sync!)
	if hasMesh and zoneMesh.edges then
		for _, me in pairs(zoneMesh.edges) do
			local u, v = "m:" .. tostring(me.a), "m:" .. tostring(me.b)
			if pts[u] and pts[v] then
				local d = self:DistanceYards(cz, pts[u].x, pts[u].y, pts[v].x, pts[v].y)
				local hit = self:SegmentBlocked(cz, pts[u].x, pts[u].y, pts[v].x, pts[v].y)
				local isWater = (me.surface == "water")
				local spd = isWater and waterSpeed or landSpeed
				local confBonus = (me.hits and me.hits >= 3) and 0.94 or 1.0
				local cost = (d / spd) * (hit and BARRIER_PENALTY or (MESH_MULT * confBonus))
				AddLocalEdge(u, v, cost, isWater and "water" or "road", not isWater, d)
				AddLocalEdge(v, u, cost, isWater and "water" or "road", not isWater, d)
			end
		end
	end

	-- 3. Stitch Breadcrumb Mesh & Game-Internal MapLink/POI nodes onto nearby unobstructed Road nodes
	if (hasMesh or hasInternal) and roadNet and roadNet.nodes then
		local roadIds = {}
		for rid in pairs(roadNet.nodes) do table.insert(roadIds, "r:" .. tostring(rid)) end

		for _, nid in ipairs(allNodeIds) do
			local np = pts[nid]
			if np.layer == "mesh" or np.layer == "internal" then
				local bestR, bestD = nil, 480 -- max 480 yds stitch to nearest clear road node
				for _, rid in ipairs(roadIds) do
					local rp = pts[rid]
					local d = self:DistanceYards(cz, np.x, np.y, rp.x, rp.y)
					if d < bestD and not self:SegmentBlocked(cz, np.x, np.y, rp.x, rp.y) then
						bestD = d
						bestR = rid
					end
				end
				if bestR then
					local cost = (bestD / landSpeed) * 1.12
					AddLocalEdge(nid, bestR, cost, "road", false, bestD)
					AddLocalEdge(bestR, nid, cost, "road", false, bestD)
				end
			end
		end
	end

	-- 4. Connect __START__ and __END__ to unobstructed road/mesh/internal nodes (strictly penalizing barriers!)
	for _, nid in ipairs(allNodeIds) do
		local np = pts[nid]
		local ds = self:DistanceYards(cz, sx, sy, np.x, np.y)
		if np.layer == "road" or np.layer == "internal" or ds <= 650 then
			local sHit = self:SegmentBlocked(cz, sx, sy, np.x, np.y)
			local sCost = (ds / landSpeed) * (sHit and BARRIER_PENALTY or OFFROAD_MULT)
			AddLocalEdge("__START__", nid, sCost, "road", false, ds)
		end

		local de = self:DistanceYards(cz, np.x, np.y, dx, dy)
		if np.layer == "road" or np.layer == "internal" or de <= 650 then
			local eHit = self:SegmentBlocked(cz, np.x, np.y, dx, dy)
			local eCost = (de / landSpeed) * (eHit and BARRIER_PENALTY or OFFROAD_MULT)
			AddLocalEdge(nid, "__END__", eCost, "road", false, de)
		end
	end

	-- 5. Direct __START__ -> __END__ off-road link (ONLY viable when clear of barriers AND shorter than road!)
	local directCost = (directDist / landSpeed) * (directBlocked and BARRIER_PENALTY or OFFROAD_MULT)
	AddLocalEdge("__START__", "__END__", directCost, "road", false, directDist)

	-- 6. A* Search over unified zone terrain navmesh (admissible heuristic = dist / (landSpeed / ROAD_MULT))
	local minCostPerYard = ROAD_MULT / math.max(landSpeed, waterSpeed, 1)
	local gScore = { __START__ = 0 }
	local fScore = { __START__ = directDist * minCostPerYard }
	local prev = {}
	local open = { __START__ = true }
	local closed = {}

	while true do
		local cur, bestF = nil, 1e12
		for id in pairs(open) do
			local fv = fScore[id] or 1e12
			if fv < bestF then
				bestF = fv
				cur = id
			end
		end
		if not cur or cur == "__END__" then break end
		open[cur] = nil
		closed[cur] = true

		local gCur = gScore[cur] or 1e12
		for _, edge in ipairs(adj[cur] or {}) do
			if not closed[edge.to] then
				local altG = gCur + edge.cost
				if altG < (gScore[edge.to] or 1e12) then
					gScore[edge.to] = altG
					local tp = pts[edge.to]
					local hRem = tp and (self:DistanceYards(cz, tp.x, tp.y, dx, dy) * minCostPerYard) or 0
					fScore[edge.to] = altG + hRem
					prev[edge.to] = { node = cur, edge = edge }
					open[edge.to] = true
				end
			end
		end
	end

	-- Reconstruct multi-waypoint terrain sequence
	local rawSeq = {}
	local cur = "__END__"
	while cur and cur ~= "__START__" do
		table.insert(rawSeq, 1, { id = cur, via = prev[cur] and prev[cur].edge or nil })
		cur = prev[cur] and prev[cur].node or nil
	end

	-- Collinear / dense-mesh waypoint smoothing (keeps every road corner & barrier turn, removes micro-stutter on straight mesh cells!)
	local seq = {}
	for i, step in ipairs(rawSeq) do
		local p = pts[step.id]
		if p then
			local prevStep = seq[#seq]
			local nextStep = rawSeq[i + 1]
			local keep = true
			if prevStep and nextStep and p.layer == "mesh" then
				local pp = pts[prevStep.id]
				local np = pts[nextStep.id]
				if pp and np and pp.layer == "mesh" and np.layer == "mesh" then
					local dSkip = self:DistanceYards(cz, pp.x, pp.y, np.x, np.y)
					if dSkip <= 160 and not self:SegmentBlocked(cz, pp.x, pp.y, np.x, np.y) then
						-- Check collinearity (cross product small -> straight trail cell, skip redundant midpoint)
						local vx1, vy1 = p.x - pp.x, p.y - pp.y
						local vx2, vy2 = np.x - p.x, np.y - p.y
						local l1 = math.sqrt(vx1 * vx1 + vy1 * vy1)
						local l2 = math.sqrt(vx2 * vx2 + vy2 * vy2)
						if l1 > 0.01 and l2 > 0.01 then
							local dot = (vx1 * vx2 + vy1 * vy2) / (l1 * l2)
							if dot > 0.96 then keep = false end
						end
					end
				end
			end
			if keep then table.insert(seq, step) end
		end
	end

	local legs = {}
	local totalEta = 0
	local lastX, lastY = sx, sy
	for i, step in ipairs(seq) do
		local p = pts[step.id]
		if p then
			local dYds = self:DistanceYards(cz, lastX, lastY, p.x, p.y)
			local isWater = (step.via and step.via.mode == "water")
			local legEta = math.max(1, math.floor(dYds / (isWater and waterSpeed or landSpeed)))
			if not (i == 1 and step.id ~= "__END__" and dYds < 32) then
				table.insert(legs, {
					label = p.label,
					zone = cz,
					x = p.x,
					y = p.y,
					mode = isWater and "water" or "road",
					isRoad = (p.layer == "road" or (step.via and step.via.isRoad)) == true,
					isMesh = (p.layer == "mesh") == true,
					distYards = math.floor(dYds),
					etaSec = legEta,
				})
				totalEta = totalEta + legEta
				lastX, lastY = p.x, p.y
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

-- ============================================================================
-- LIVE PLAYER MOVEMENT TRACKER (WALKABLE MESH RECORDER + STUCK/OFF-ROUTE CHECK)
-- ============================================================================
function PluribusHiveTerrainMesh:PollPlayerTerrain()
	local pf = _G.PluribusHivePathfinder
	if not pf then return end
	if IsInInstance then
		local inInst = IsInInstance()
		if inInst then
			self.lastCell = nil
			return
		end
	end
	if (UnitOnTaxi and UnitOnTaxi("player")) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or (IsFalling and IsFalling()) then
		self.lastCell = nil
		self.stuckTracker = nil
		return
	end

	local curZone = pf:CanonicalZone((GetRealZoneText and GetRealZoneText()) or "")
	if curZone == "" then return end

	local px, py = 0, 0
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end
	if px == 0 and py == 0 then return end

	local now = (GetTime and GetTime()) or 0
	local speed = (GetUnitSpeed and GetUnitSpeed("player")) or 0
	local surface = (IsSwimming and IsSwimming()) and "water" or "ground"

	-- 1. Walkable NavMesh Breadcrumb Recorder
	local gx, gy, _, _, ck = QuantizeCell(px, py)
	local prev = self.lastCell
	if prev and prev.zone == curZone then
		local dt = now - (prev.t or 0)
		local movedYds = self:DistanceYards(curZone, prev.x, prev.y, px, py)
		if dt > 0.15 and dt <= 6.0 and movedYds <= math.max(120, dt * 45) then
			if ck ~= prev.ck then
				self:RecordWalkableEdge(curZone, prev.x, prev.y, px, py, surface, true)
				self.lastCell = { zone = curZone, gx = gx, gy = gy, ck = ck, x = px, y = py, t = now, surface = surface }
			end
		elseif movedYds > 180 or dt > 6.0 then
			-- Teleport / Hearthstone / lag spike -> reset anchor cleanly
			self.lastCell = { zone = curZone, gx = gx, gy = gy, ck = ck, x = px, y = py, t = now, surface = surface }
		end
	else
		self.lastCell = { zone = curZone, gx = gx, gy = gy, ck = ck, x = px, y = py, t = now, surface = surface }
	end

	-- 2. Stuck / Wall-Bump Detection & Automatic Off-Route Re-Routing (only while actively navigating!)
	local route = pf.activeRoute
	if route and route.legs and #route.legs > 0 then
		local activeLeg = route.legs[pf.activeLegIndex or 1]
		if activeLeg and pf:CanonicalZone(activeLeg.zone) == curZone and (activeLeg.mode == "road" or activeLeg.mode == "water") then
			local legKey = string.format("%s:%.1f:%.1f", curZone, activeLeg.x or 0, activeLeg.y or 0)
			if speed > 1.5 and surface == "ground" then
				local st = self.stuckTracker
				if not st or st.legKey ~= legKey then
					self.stuckTracker = { x = px, y = py, t = now, legKey = legKey }
				elseif (now - st.t) >= 2.4 then
					local netMoved = self:DistanceYards(curZone, st.x, st.y, px, py)
					if netMoved < 6.5 and (now - (self.lastRerouteAt or 0)) >= 4.0 then
						-- Player is pushing into an unmapped wall/cliff/fence! Mark obstacle & re-route immediately!
						local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
						self:AddSessionObstacle(curZone, px, py, facing, "Hindernis erkannt")
						self.lastRerouteAt = now
						self.stuckTracker = { x = px, y = py, t = now, legKey = legKey }
						pf:SetRouteTo(curZone, px, py, route.destZone or curZone, route.destX or activeLeg.x, route.destY or activeLeg.y, route.destName)
						return
					end
					self.stuckTracker = { x = px, y = py, t = now, legKey = legKey }
				end
			else
				self.stuckTracker = nil
			end

			-- Dynamic off-route re-routing if player drifted far off the planned corridor in the same zone
			if pf:CanonicalZone(route.destZone) == curZone and (now - (self.lastRerouteAt or 0)) >= 5.0 then
				local distToLeg = self:DistanceYards(curZone, px, py, activeLeg.x, activeLeg.y)
				if distToLeg > math.max(380, (activeLeg.distYards or 250) * 1.65) then
					self.lastRerouteAt = now
					pf:SetRouteTo(curZone, px, py, route.destZone, route.destX, route.destY, route.destName)
				end
			end
		end
	else
		self.stuckTracker = nil
	end
end

-- ============================================================================
-- BOOTSTRAP: MERGE ALL EXTRA ZONES INTO HIVEPATHFINDER & HOOK EVENTS
-- ============================================================================
function PluribusHiveTerrainMesh:MergeTopologyIntoPathfinder()
	local pf = _G.PluribusHivePathfinder
	if not pf then return end

	pf.ZONE_ROADS = pf.ZONE_ROADS or {}
	for zName, data in pairs(EXTRA_ZONE_ROADS) do
		if not pf.ZONE_ROADS[zName] then
			pf.ZONE_ROADS[zName] = data
		end
	end

	pf.ZONE_BARRIERS = pf.ZONE_BARRIERS or {}
	for zName, bList in pairs(EXTRA_ZONE_BARRIERS) do
		if not pf.ZONE_BARRIERS[zName] then
			pf.ZONE_BARRIERS[zName] = bList
		end
	end

	pf.ZONE_CONTINENT_BOUNDS = pf.ZONE_CONTINENT_BOUNDS or {}
	for zName, b in pairs(EXTRA_CONTINENT_BOUNDS) do
		if not pf.ZONE_CONTINENT_BOUNDS[zName] then
			pf.ZONE_CONTINENT_BOUNDS[zName] = b
		end
	end

	-- Extend CanonicalZone for Alterac Mountains / Deadwind Pass / Moonglade
	if not pf._terrainAliasWrapped then
		pf._terrainAliasWrapped = true
		local origCanon = pf.CanonicalZone
		pf.CanonicalZone = function(selfPf, zoneName)
			if zoneName and zoneName ~= "" then
				local low = tostring(zoneName):lower():match("^%s*(.-)%s*$") or ""
				if EXTRA_ALIASES[low] then return EXTRA_ALIASES[low] end
			end
			return origCanon(selfPf, zoneName)
		end
	end
end

function PluribusHiveTerrainMesh:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:MergeTopologyIntoPathfinder()
	self:CalibrateCurrentZoneDims()

	-- Receive guild-synced walkable terrain mesh edges over PLBHIVE
	if PluribusHive and PluribusHive.RegisterHandler then
		PluribusHive:RegisterHandler("MESHEDGE", function(_, body)
			local zName, k1, k2, surf = tostring(body or ""):match("^([^|]+)|([^|]+)|([^|]+)|([GW])$")
			if zName and k1 and k2 then
				PluribusHiveTerrainMesh:ImportGuildMeshEdge(zName, k1, k2, surf)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function()
		PluribusHiveTerrainMesh.lastCell = nil
		PluribusHiveTerrainMesh.stuckTracker = nil
		PluribusHiveTerrainMesh:CalibrateCurrentZoneDims()
		local curZone = (GetRealZoneText and GetRealZoneText()) or ""
		if curZone ~= "" then
			PluribusHiveTerrainMesh:ScanInternalMapWaypoints(nil, curZone)
		end
	end)

	local accum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + (elapsed or 0)
		if accum < 0.35 then return end
		accum = 0
		PluribusHiveTerrainMesh:PollPlayerTerrain()
	end)
end

-- Merge static road/barrier topology immediately at load time so even pre-Initialize calls see ALL 40+ zones!
PluribusHiveTerrainMesh:MergeTopologyIntoPathfinder()

return PluribusHiveTerrainMesh
