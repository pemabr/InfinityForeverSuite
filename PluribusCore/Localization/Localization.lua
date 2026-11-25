-- PluribusCore Localization Engine (deDE + enUS)
-- Auto-detects WoW client locale via GetLocale() and supports live user language override
-- via Settings -> General & UI -> Language ("auto" | "deDE" | "enUS").

local EN = {
	-- Suite & Tabs
	SUITE_TITLE             = "Pluribus Suite",
	SUITE_SUBTITLE          = "Guild Hive Hub",
	SETTINGS                = "Settings",
	CLOSE                   = "Close",
	SEARCH                  = "Search:",
	ALL                     = "All",
	REFRESH                 = "Refresh",
	SAVE                    = "Save",
	DELETE                  = "Delete",
	CLEAR                   = "Clear",
	YES                     = "Yes",
	NO                      = "No",

	TAB_GUILD_HUB           = "Guild Hub",
	TAB_BAGS                = "Bags & Bank",
	TAB_PROFESSIONS         = "Professions",
	TAB_GEAR                = "GearAdvisor",
	TAB_MAIL                = "Guild Mail",
	TAB_TAX                 = "Guild Tax",
	TAB_NAV                 = "Nav & Guides",
	TAB_MARKET              = "Market & Tools",
	TAB_HEALBOT             = "HealBot",

	-- Bags & Unified Bag Replacement
	BAGS_ONLY               = "Bags",
	BANK_ONLY               = "Bank",
	SELL_GRAY_JUNK          = "Sell Gray Junk",
	SCAN_BAGS               = "Scan Bags",
	UNIFIED_BAG_MODE        = "Bag UI Mode",
	REPLACE_NATIVE_BAGS     = "Replace Native Bags with Pluribus Bag UI",
	REPLACE_NATIVE_BAGS_DESC= "Opens the unified Pluribus Backpack window instead of separate Blizzard bags (toggle anytime)",
	OPEN_NATIVE_BAGS        = "Native Bags",
	BAG_SLOTS_FREE          = "%d/%d free",
	BAG_EST_VALUE           = "Est. Value:",
	BAG_NO_JUNK             = "No gray trash items found in your bags.",
	BAG_OPEN_VENDOR_FIRST   = "Open any vendor/merchant first, then click Sell Gray Junk.",
	BAG_SOLD_JUNK           = "Auto-sold %d gray trash item(s) for %s.",

	-- Professions, Craft Profits & To-Do List
	PROF_GUILD_RECIPES      = "Guild Recipes",
	PROF_CRAFT_PROFITS      = "Craft Profits",
	PROF_TODO_LIST          = "To-Do & Shopping List",
	PROF_SURPLUS            = "Surplus Mats",
	PROF_ONLY_MINE          = "Only Mine",
	PROF_ALL_GUILD          = "All Guild",
	PROF_NO_RECIPES_YET     = "No real recipes scanned yet! Open your Profession window (e.g. Alchemy, Blacksmithing, Enchanting) once so Pluribus scans YOUR real recipes.",
	PROF_OPEN_FOR_PROFITS   = "Scan a Profession once (open Alchemy, Blacksmithing, Enchanting, etc.) and scan the AH to calculate live Craft Profits!",
	PROF_ADD_TODO           = "+ To-Do",
	PROF_WHISPER            = "Whisper",
	PROF_LETTER             = "Letter",
	PROF_PROFIT_COL         = "Net Profit (incl. 5% AH cut)",
	PROF_SELL_MATS          = "Sell: %s  ·  Mats: %s",
	TODO_TITLE              = "Interactive To-Do & Shopping List",
	TODO_SUBTITLE           = "Choose Buy (1-click AH search) or Farm (auto-calculated optimal farm route inline) for every item!",
	TODO_MODE_BUY           = "Buy (AH)",
	TODO_MODE_FARM          = "Farm (Route)",
	TODO_SEARCH_AH          = "Search AH",
	TODO_NAV_ROUTE          = "Navigate",
	TODO_OPEN_AH_HINT       = "Open the Auction House to search for '%s' automatically.",
	TODO_ROUTE_LABEL        = "Auto Farm Route: %s (%.1f, %.1f) · %s",
	TODO_ADDED_ITEM         = "Added to To-Do List:",
	TODO_ADDED_RECIPE       = "Added recipe to To-Do List:",
	TODO_EMPTY              = "Your To-Do List is empty. Pick a recipe or material above, or click '+ To-Do' in Recipes, Craft Profits, or AH Prices!",
	PROF_UNLEARNED          = "Unlearned Recipes",
	PROF_UNLEARNED_HINT     = "Click any unlearned recipe to navigate directly to its Vendor or Mob Drop location.",
	PROF_SOURCE_ALL         = "All",
	PROF_SOURCE_VENDOR      = "Vendor",
	PROF_SOURCE_DROP        = "Drop",
	PROF_SOURCE_LIMITED     = "Limited",
	PROF_CLICK_TO_NAV       = "Click to navigate",
	PROF_ALL_LEARNED        = "No matching unlearned recipes found for this filter!",
	PROF_MY_PROFS           = "My Professions",
	PROF_SKILL_REQ          = "Skill %d",

	-- Market & AH Search
	MARKET_AH_TITLE         = "Guild AH Prices & P2P Database",
	MARKET_SEARCH_PLACEHOLDER = "Search item name...",
	MARKET_SORT_RECENT      = "Recent",
	MARKET_SORT_PRICE       = "Price",
	MARKET_SORT_NAME        = "Name",
	MARKET_SEARCH_IN_AH     = "Search AH",
	MARKET_NO_MATCHES       = "No AH prices match your search.",
	MARKET_EMPTY            = "No AH prices cached yet. Open the Auction House once for an automatic scan.",

	-- GearAdvisor
	GEAR_TITLE              = "Pluribus GearAdvisor & Cap Guardian",
	GEAR_SUB_OVERVIEW       = "Cap Guardian",
	GEAR_SUB_LAB            = "Stat Laboratory",
	GEAR_SUB_ROADMAP        = "Upgrade Roadmap",
	GEAR_SUB_TALENTS        = "Talent Builds",
	GEAR_SUB_XPBAR          = "XP & Gold Bar",
	GEAR_UPGRADE            = "Upgrade",
	GEAR_DOWNGRADE          = "Downgrade",
	GEAR_SIDEGRADE          = "Sidegrade",
	GEAR_EQUIP              = "Equip",
	GEAR_BAG_UPGRADES       = "Equippable Bag Upgrades (%d):",
	GEAR_WEIGHTS_TITLE      = "Active Stat Weights (Click +/- to customize)",
	GEAR_WEIGHTS_RESET      = "Reset Weights",
	GEAR_TOOLTIP_LABEL      = "GearAdvisor:",
	GEAR_CAP_LABEL          = "Cap Guardian:",
	GEAR_ALT_BOE            = "Alt BoE Upgrade:",

	-- SOS Rescue Popup
	SOS_POPUP_TITLE         = "GUILD SOS — RESCUE NEEDED!",
	SOS_INVITE_NAV          = "Invite + Navigate",
	SOS_NAV_ONLY            = "Navigate Only",
	SOS_WHISPER_OMW         = "On my way to rescue you! Group invite sent!",
	SOS_WHISPER_NAV         = "On my way to help! Hold on!",
	SOS_OPEN_WORLD_ONLY     = "SOS is only active in the open world (disabled inside instances & raids).",
	SOS_SENT                = "Open-world SOS sent to nearby guildmates!",

	-- Navigation, Map Pins & Smart Pathfinder
	NAV_TITLE               = "Smart Azeroth Pathfinder & Guild GPS",
	NAV_COMPASS_SHOW        = "Show Compass",
	NAV_COMPASS_HIDE        = "Hide Compass",
	NAV_CLEAR_ROUTE         = "Clear Route",
	NAV_PIN_CURRENT         = "Pin Here",
	NAV_CAT_PINS            = "Map Pins",
	NAV_CAT_ROUTE           = "Active Route",
	NAV_CAT_RAIDS           = "Raids",
	NAV_CAT_DUNGEONS        = "Dungeons",
	NAV_CAT_CITIES          = "Cities",
	NAV_CAT_BOSSES          = "World Bosses",
	NAV_CAT_GUILD           = "Guild GPS",
	NAV_PINS_HINT           = "Alt + Left-Click on World Map starts Navigation · Ctrl + Left-Click saves a Pin · Right-Click a Pin deletes it.",
	NAV_PIN_ADDED           = "Map Pin saved: %s (%.1f, %.1f)",
	NAV_PIN_REMOVED         = "Map Pin deleted: %s",
	NAV_CLEAR_ALL_PINS      = "Delete All Pins",
	NAV_ROUTE_ADD_QUESTS    = "+ Quests",
	NAV_ROUTE_ADD_TODOS     = "+ To-Dos",
	NAV_ROUTE_ADD_BOTH      = "+ Quests & To-Dos",
	NAV_ROUTE_AUTO_ON       = "Auto-Sync: ON",
	NAV_ROUTE_AUTO_OFF      = "Auto-Sync: OFF",
	NAV_ROUTE_SKIP          = "Skip",
	NAV_ROUTE_RESTORE       = "Restore",
	NAV_ROUTE_RESTORE_ALL   = "Restore Skipped",
	NAV_ROUTE_SKIPPED_HDR   = "Temporarily Skipped (%d):",
	NAV_ROUTE_EMPTY         = "No active route stops yet. Click '+ Quests & To-Dos' above to build an auto-updating multi-stop route!",
	NAV_ROUTE_CLEAR         = "Clear",
	NAV_ROUTE_STOP_TAG      = "Stop %d/%d",
	TT_QUEST_GIVER          = "Quest Giver:",
	TT_QUEST_TURNIN         = "Quest Turn-In:",
	TT_QUEST_OBJECTIVE      = "Quest Target:",
	NAV_AVOID_HIGH_LEVEL    = "Avoid High-Level Zones & Mobs",
	NAV_AVOID_HIGH_LEVEL_DESC = "Routes along roads and avoids zones/mobs above your character level when navigating",
	NAV_LEG_ROAD            = "Road",
	NAV_LEG_OFFROAD         = "Path",
	NAV_LEG_WATER           = "Water Shortcut",
	NAV_LEG_FLIGHT          = "Flight Path",
	NAV_LEG_BOAT            = "Boat",
	NAV_LEG_ZEPPELIN        = "Zeppelin",
	NAV_LEG_PORTAL          = "Mage Portal",
	NAV_LEG_SUMMON          = "Warlock Summon",
	NAV_CAT_TRANSIT         = "Port & Summon",
	NAV_GUILD_TRANSIT_OPT   = "Use Open-World Guild Mages & Warlocks",
	NAV_GUILD_TRANSIT_DESC  = "Consider online guild Mages (portals) & Warlocks (summons, with 2-helper buffer) outside dungeons/raids",
	NAV_ASK_WHISPER         = "Whisper",
	NAV_TRANSIT_EMPTY       = "No eligible open-world guild Mages (Lv40+) or Warlocks (Lv20+) online right now.",
	NAV_TRANSIT_INSTANCED   = "%d guild Mage/Warlock(s) ignored (inside dungeon/raid/BG instance).",
	NAV_SYNCED              = "Guild-Synced",
	NAV_ESTIMATED           = "Estimated",
	NAV_HAZARD_AVOIDED      = "Safest route (avoids high-level mobs)",
	NAV_ARRIVED             = "Arrived! (<15 yds)",
	NAV_FP_DISCOVERED       = "Flight Point recorded for Pathfinder: %s",

	-- Guides Auto-Compute
	GUIDES_AUTO_COMPUTED    = "Auto-calculated (%s)",
	GUIDES_RECOMPUTE        = "Recalculate Now",

	-- Settings Categories & Language
	SET_LANGUAGE            = "Language / Sprache",
	SET_LANGUAGE_DESC       = "Auto-detects WoW client language or manually switch between Deutsch and English",
	SET_LANG_AUTO           = "Auto",
	SET_LANG_DE             = "Deutsch",
	SET_LANG_EN             = "English",
	SET_CAT_GENERAL         = "General & UI",
	SET_CAT_SHARING         = "HiveMind Sharing",
	SET_CAT_ALERTS          = "Alerts, SOS & LFG",
	SET_CAT_TOOLTIPS        = "Tooltips & Market",
	SET_CAT_MODULES         = "Modules & Data",
	SET_CAT_SHORTCUTS       = "Shortcuts & Guide",

	-- Guild Member Addon Roster & HiveMind Network Status
	HUB_SUB_OVERVIEW        = "Overview (LFG & Feed)",
	HUB_SUB_ROSTER          = "Member Roster (Addon Check)",
	ROSTER_CHECK_VERSIONS   = "Check Versions",
	ROSTER_FILTER_ALL       = "All",
	ROSTER_FILTER_ONLINE    = "Online",
	ROSTER_FILTER_CURRENT   = "Up-to-date",
	ROSTER_FILTER_OUTDATED  = "Outdated",
	ROSTER_FILTER_NONE      = "No Addon",
	ROSTER_STATUS_CURRENT   = "Up-to-date",
	ROSTER_STATUS_OUTDATED  = "Outdated",
	ROSTER_STATUS_NONE      = "No Addon",
	ROSTER_ONLINE           = "Online",
	ROSTER_OFFLINE          = "Offline",
	ROSTER_SELF_TAG         = "(You)",
	ROSTER_INVITE           = "Inv",
	ROSTER_SUMMARY          = "Online: %d/%d · |cff4ade80Up-to-date: %d|r · |cfffbbf24Outdated: %d|r · |cfff87171No Addon: %d|r · Latest: |cff38bdf8v%s|r",
	ROSTER_EMPTY            = "No guild members match this filter.",
	HIVE_ONLINE_SOLO        = "Online (1/1 · Solo Node)",
	HIVE_ONLINE_PEERS       = "Online & Synced (%d connected)",
	HIVE_LOCAL_NO_GUILD     = "Local Active (No Guild)",
	HIVE_OUTDATED_SELF      = "Your Pluribus version (v%s) is outdated! Guild latest: v%s",

	-- Raid Marker Bar, Pull Timer & Ready Check Inspector
	RAID_MARKER_BAR         = "Marker Bar",
	RAID_PULL_BTN           = "Pull",
	RAID_READY_BTN          = "Ready Check",
	RC_TITLE                = "Pluribus Ready Check — Buffs, Consumables & Durability",
	RC_SUBTITLE             = "Live party/raid check: active buffs, missing buffs/flask/food & armor durability",
	RC_POST_MISSING         = "Post Missing",
	CD_SUB_ACTIVE           = "Active Cooldowns",
	CD_SUB_CONFIG           = "On-Screen Selection",
	CD_SCOPE_GROUP          = "Group/Raid",
	CD_SCOPE_GUILD          = "Guild+Raid",
	CD_SCOPE_ALL            = "All",
	CD_PREVIEW              = "Preview",
	HEALER_UNIFIED_TITLE    = "Pluribus HealBot + Decursive",
}

local DE = {
	-- Suite & Tabs
	SUITE_TITLE             = "Pluribus Suite",
	SUITE_SUBTITLE          = "Gilden-Hive Zentrale",
	SETTINGS                = "Einstellungen",
	CLOSE                   = "Schließen",
	SEARCH                  = "Suche:",
	ALL                     = "Alle",
	REFRESH                 = "Aktualisieren",
	SAVE                    = "Speichern",
	DELETE                  = "Löschen",
	CLEAR                   = "Leeren",
	YES                     = "Ja",
	NO                      = "Nein",

	TAB_GUILD_HUB           = "Gilden-Hub",
	TAB_BAGS                = "Taschen & Bank",
	TAB_PROFESSIONS         = "Berufe & To-Do",
	TAB_GEAR                = "GearAdvisor",
	TAB_MAIL                = "Gildenpost",
	TAB_TAX                 = "Gildensteuer",
	TAB_NAV                 = "Navi & Guides",
	TAB_MARKET              = "Markt & Tools",
	TAB_HEALBOT             = "HealBot",

	-- Bags & Unified Bag Replacement
	BAGS_ONLY               = "Taschen",
	BANK_ONLY               = "Bank",
	SELL_GRAY_JUNK          = "Graues verkaufen",
	SCAN_BAGS               = "Scannen",
	UNIFIED_BAG_MODE        = "Rucksack-UI",
	REPLACE_NATIVE_BAGS     = "Standard-Rucksack durch Pluribus-Taschen ersetzen",
	REPLACE_NATIVE_BAGS_DESC= "Öffnet das einheitliche Pluribus-Rucksackfenster statt getrennter Standard-Taschen (jederzeit umschaltbar)",
	OPEN_NATIVE_BAGS        = "Standard-Taschen",
	BAG_SLOTS_FREE          = "%d/%d frei",
	BAG_EST_VALUE           = "Gesch. Wert:",
	BAG_NO_JUNK             = "Kein grauer Müll in deinen Taschen gefunden.",
	BAG_OPEN_VENDOR_FIRST   = "Öffne zuerst einen Händler, um grauen Müll zu verkaufen.",
	BAG_SOLD_JUNK           = "%d graue Müll-Gegenstände für %s verkauft.",

	-- Professions, Craft Profits & To-Do List
	PROF_GUILD_RECIPES      = "Gilden-Rezepte",
	PROF_CRAFT_PROFITS      = "Craft-Profite",
	PROF_TODO_LIST          = "To-Do & Einkaufsliste",
	PROF_SURPLUS            = "Überschuss-Mats",
	PROF_ONLY_MINE          = "Nur Meine",
	PROF_ALL_GUILD          = "Alle (Gilde)",
	PROF_NO_RECIPES_YET     = "Noch keine echten Rezepte eingelesen! Öffne einmal dein Berufsfenster (z. B. Alchemie, Schmiedekunst, Verzauberkunst), damit Pluribus DEINE Rezepte speichert.",
	PROF_OPEN_FOR_PROFITS   = "Öffne einmal einen Beruf (Alchemie, Schmiedekunst, Verzauberkunst etc.) und scanne das AH, um Live-Profite zu berechnen!",
	PROF_ADD_TODO           = "+ To-Do",
	PROF_WHISPER            = "Flüstern",
	PROF_LETTER             = "Brief",
	PROF_PROFIT_COL         = "Netto-Profit (inkl. 5% AH-Gebühr)",
	PROF_SELL_MATS          = "Verkauf: %s  ·  Mats: %s",
	TODO_TITLE              = "Interaktive To-Do & Einkaufsliste",
	TODO_SUBTITLE           = "Wähle pro Item 'Kaufen' (1-Klick AH-Suche) oder 'Farmen' (zeigt die errechnete Farm-Route direkt hier an)!",
	TODO_MODE_BUY           = "Kaufen (AH)",
	TODO_MODE_FARM          = "Farmen (Route)",
	TODO_SEARCH_AH          = "Im AH suchen",
	TODO_NAV_ROUTE          = "Navigieren",
	TODO_OPEN_AH_HINT       = "Öffne das Auktionshaus, um automatisch nach '%s' zu suchen.",
	TODO_ROUTE_LABEL        = "Auto-Farmroute: %s (%.1f, %.1f) · %s",
	TODO_ADDED_ITEM         = "Zur To-Do Liste hinzugefügt:",
	TODO_ADDED_RECIPE       = "Rezept zur To-Do Liste hinzugefügt:",
	TODO_EMPTY              = "Deine To-Do Liste ist leer. Wähle oben ein Rezept/Material oder klicke '+ To-Do' bei Rezepten, Profiten oder AH-Preisen!",
	PROF_UNLEARNED          = "Fehlende Rezepte",
	PROF_UNLEARNED_HINT     = "Klicke ein ungelern­tes Rezept an, um direkt zum Händler oder Drop-Mob zu navigieren.",
	PROF_SOURCE_ALL         = "Alle",
	PROF_SOURCE_VENDOR      = "Händler",
	PROF_SOURCE_DROP        = "Drop",
	PROF_SOURCE_LIMITED     = "Limitiert",
	PROF_CLICK_TO_NAV       = "Klicken zum Navigieren",
	PROF_ALL_LEARNED        = "Keine passenden ungelern­ten Rezepte für diesen Filter gefunden!",
	PROF_MY_PROFS           = "Meine Berufe",
	PROF_SKILL_REQ          = "Skill %d",

	-- Market & AH Search
	MARKET_AH_TITLE         = "Gilden-AH-Preisliste & P2P Datenbank",
	MARKET_SEARCH_PLACEHOLDER = "Gegenstand suchen...",
	MARKET_SORT_RECENT      = "Aktuell",
	MARKET_SORT_PRICE       = "Preis",
	MARKET_SORT_NAME        = "Name",
	MARKET_SEARCH_IN_AH     = "Im AH suchen",
	MARKET_NO_MATCHES       = "Keine AH-Preise für diese Suche gefunden.",
	MARKET_EMPTY            = "Noch keine AH-Preise gespeichert. Öffne einmal das Auktionshaus für den Auto-Scan.",

	-- GearAdvisor
	GEAR_TITLE              = "Pluribus GearAdvisor & Cap-Wächter",
	GEAR_SUB_OVERVIEW       = "Cap-Wächter",
	GEAR_SUB_LAB            = "Werte-Labor",
	GEAR_SUB_ROADMAP        = "Upgrade-Plan",
	GEAR_SUB_TALENTS        = "Talent-Builds",
	GEAR_SUB_XPBAR          = "EP & Gold-Leiste",
	GEAR_UPGRADE            = "Upgrade",
	GEAR_DOWNGRADE          = "Downgrade",
	GEAR_SIDEGRADE          = "Gleichwertig",
	GEAR_EQUIP              = "Anlegen",
	GEAR_BAG_UPGRADES       = "Anlegbare Upgrades in Taschen (%d):",
	GEAR_WEIGHTS_TITLE      = "Aktive Stat-Gewichtungen (Klicke +/- zum Anpassen)",
	GEAR_WEIGHTS_RESET      = "Gewichte zurücksetzen",
	GEAR_TOOLTIP_LABEL      = "GearAdvisor:",
	GEAR_CAP_LABEL          = "Cap-Wächter:",
	GEAR_ALT_BOE            = "Twink BoE-Upgrade:",

	-- SOS Rescue Popup
	SOS_POPUP_TITLE         = "GILDEN-SOS — HILFE BENÖTIGT!",
	SOS_INVITE_NAV          = "Einladen + Navi",
	SOS_NAV_ONLY            = "Nur Navi",
	SOS_WHISPER_OMW         = "Bin unterwegs zur Rettung! Gruppeneinladung ist raus!",
	SOS_WHISPER_NAV         = "Bin auf dem Weg zu dir! Durchhalten!",
	SOS_OPEN_WORLD_ONLY     = "SOS ist nur in der offenen Welt aktiv (in Instanzen & Raids deaktiviert).",
	SOS_SENT                = "Open-World SOS an nahe Gildenmitglieder gesendet!",

	-- Navigation, Map Pins & Smart Pathfinder
	NAV_TITLE               = "Smarter Azeroth-Pathfinder & Gilden-GPS",
	NAV_COMPASS_SHOW        = "Kompass zeigen",
	NAV_COMPASS_HIDE        = "Kompass ausbl.",
	NAV_CLEAR_ROUTE         = "Route löschen",
	NAV_PIN_CURRENT         = "Hier pinnen",
	NAV_CAT_PINS            = "Karten-Pins",
	NAV_CAT_ROUTE           = "Aktive Route",
	NAV_CAT_RAIDS           = "Raids",
	NAV_CAT_DUNGEONS        = "Dungeons",
	NAV_CAT_CITIES          = "Städte",
	NAV_CAT_BOSSES          = "Weltbosse",
	NAV_CAT_GUILD           = "Gilden-GPS",
	NAV_PINS_HINT           = "Alt + Linksklick auf der Weltkarte startet das Navi · Strg + Linksklick speichert einen Pin · Rechtsklick löscht Pins.",
	NAV_PIN_ADDED           = "Karten-Pin gespeichert: %s (%.1f, %.1f)",
	NAV_PIN_REMOVED         = "Karten-Pin gelöscht: %s",
	NAV_CLEAR_ALL_PINS      = "Alle Pins löschen",
	NAV_ROUTE_ADD_QUESTS    = "+ Quests",
	NAV_ROUTE_ADD_TODOS     = "+ To-Dos",
	NAV_ROUTE_ADD_BOTH      = "+ Quests & To-Dos",
	NAV_ROUTE_AUTO_ON       = "Auto-Sync: AN",
	NAV_ROUTE_AUTO_OFF      = "Auto-Sync: AUS",
	NAV_ROUTE_SKIP          = "Später",
	NAV_ROUTE_RESTORE       = "Zurück",
	NAV_ROUTE_RESTORE_ALL   = "Übersprungene holen",
	NAV_ROUTE_SKIPPED_HDR   = "Vorerst übersprungen (%d):",
	NAV_ROUTE_EMPTY         = "Noch keine Routen-Stopps. Klicke oben auf '+ Quests & To-Dos' für eine automatisch aktualisierte Route!",
	NAV_ROUTE_CLEAR         = "Leeren",
	NAV_ROUTE_STOP_TAG      = "Stopp %d/%d",
	TT_QUEST_GIVER          = "Questgeber:",
	TT_QUEST_TURNIN         = "Quest-Abgabe:",
	TT_QUEST_OBJECTIVE      = "Quest-Ziel:",
	NAV_AVOID_HIGH_LEVEL    = "Hochstufen-Gebiete & Mobs meiden",
	NAV_AVOID_HIGH_LEVEL_DESC = "Bevorzugt Straßen und umgeht Gebiete/Gegner über deinem Level beim Navigieren",
	NAV_LEG_ROAD            = "Straße",
	NAV_LEG_OFFROAD         = "Weg",
	NAV_LEG_WATER           = "Wasser-Abkürzung",
	NAV_LEG_FLIGHT          = "Flugpunkt",
	NAV_LEG_BOAT            = "Schiff",
	NAV_LEG_ZEPPELIN        = "Zeppelin",
	NAV_LEG_PORTAL          = "Magier-Portal",
	NAV_LEG_SUMMON          = "Hexer-Summon",
	NAV_CAT_TRANSIT         = "Port & Summon",
	NAV_GUILD_TRANSIT_OPT   = "Open-World Gilden-Magier & Hexer nutzen",
	NAV_GUILD_TRANSIT_DESC  = "Berücksichtigt Gilden-Magier (Portale) & Hexer (Summons inkl. 2-Helfer-Puffer) außerhalb von Dungeons/Raids",
	NAV_ASK_WHISPER         = "Flüstern",
	NAV_TRANSIT_EMPTY       = "Aktuell keine offenen Gilden-Magier (Lv40+) oder Hexer (Lv20+) außerhalb von Instanzen online.",
	NAV_TRANSIT_INSTANCED   = "%d Gilden-Magier/Hexer ignoriert (in Dungeon/Raid/BG-Instanz).",
	NAV_SYNCED              = "Gildensync",
	NAV_ESTIMATED           = "Geschätzt",
	NAV_HAZARD_AVOIDED      = "Sichere Route (umgeht hohe Mobs)",
	NAV_ARRIVED             = "Angekommen! (<15m)",
	NAV_FP_DISCOVERED       = "Flugpunkt für Pathfinder gespeichert: %s",

	-- Guides Auto-Compute
	GUIDES_AUTO_COMPUTED    = "Automatisch berechnet (%s)",
	GUIDES_RECOMPUTE        = "Neu berechnen",

	-- Settings Categories & Language
	SET_LANGUAGE            = "Sprache / Language",
	SET_LANGUAGE_DESC       = "Erkennt die WoW-Sprache automatisch oder wechselt direkt zwischen Deutsch und Englisch",
	SET_LANG_AUTO           = "Auto",
	SET_LANG_DE             = "Deutsch",
	SET_LANG_EN             = "English",
	SET_CAT_GENERAL         = "Allgemein & UI",
	SET_CAT_SHARING         = "HiveMind Teilen",
	SET_CAT_ALERTS          = "Alarme, SOS & LFG",
	SET_CAT_TOOLTIPS        = "Tooltips & Markt",
	SET_CAT_MODULES         = "Module & Daten",
	SET_CAT_SHORTCUTS       = "Befehle & Hilfe",

	-- Mitgliederliste (Addon-Status) & HiveMind Netzwerkstatus
	HUB_SUB_OVERVIEW        = "Übersicht (LFG & Feed)",
	HUB_SUB_ROSTER          = "Mitgliederliste (Addon-Check)",
	ROSTER_CHECK_VERSIONS   = "Versionen prüfen",
	ROSTER_FILTER_ALL       = "Alle",
	ROSTER_FILTER_ONLINE    = "Nur Online",
	ROSTER_FILTER_CURRENT   = "Aktuell",
	ROSTER_FILTER_OUTDATED  = "Veraltet",
	ROSTER_FILTER_NONE      = "Kein Addon",
	ROSTER_STATUS_CURRENT   = "Aktuell",
	ROSTER_STATUS_OUTDATED  = "Veraltet",
	ROSTER_STATUS_NONE      = "Kein Addon",
	ROSTER_ONLINE           = "Online",
	ROSTER_OFFLINE          = "Offline",
	ROSTER_SELF_TAG         = "(Du)",
	ROSTER_INVITE           = "Einl.",
	ROSTER_SUMMARY          = "Online: %d/%d · |cff4ade80Aktuell: %d|r · |cfffbbf24Veraltet: %d|r · |cfff87171Kein Addon: %d|r · Neueste: |cff38bdf8v%s|r",
	ROSTER_EMPTY            = "Keine Gildenmitglieder für diesen Filter gefunden.",
	HIVE_ONLINE_SOLO        = "Online (1/1 · Solo-Knoten)",
	HIVE_ONLINE_PEERS       = "Online & Synchron (%d verbunden)",
	HIVE_LOCAL_NO_GUILD     = "Lokal aktiv (Keine Gilde)",
	HIVE_OUTDATED_SELF      = "Deine Pluribus-Version (v%s) ist veraltet! Gilde nutzt: v%s",

	-- Raid Markierungsleiste, Pull-Timer & Bereitschaftscheck
	RAID_MARKER_BAR         = "Marker-Leiste",
	RAID_PULL_BTN           = "Pull",
	RAID_READY_BTN          = "Bereitschaft",
	RC_TITLE                = "Pluribus Bereitschaftscheck — Buffs, Tränke & Haltbarkeit",
	RC_SUBTITLE             = "Live Gruppen-/Raid-Prüfung: aktive Buffs, fehlende Consumables & Rüstungshaltbarkeit",
	RC_POST_MISSING         = "Fehlende posten",
	CD_SUB_ACTIVE           = "Aktive Cooldowns",
	CD_SUB_CONFIG           = "On-Screen Auswahl-Menü",
	CD_SCOPE_GROUP          = "Nur Gruppe/Raid",
	CD_SCOPE_GUILD          = "Gilde + Raid",
	CD_SCOPE_ALL            = "Alle",
	CD_PREVIEW              = "Test-Vorschau",
	HEALER_UNIFIED_TITLE    = "Pluribus HealBot + Decursive",
}

local DICTIONARIES = {
	enUS = EN,
	deDE = DE,
}

local function NormalizeLocaleCode(code)
	if not code or code == "auto" then return nil end
	local low = tostring(code):lower()
	if low == "de" or low == "dede" or low == "deat" or low == "dech" then return "deDE" end
	if low == "en" or low == "enus" or low == "engb" then return "enUS" end
	return DICTIONARIES[code] and code or nil
end

local overrideLocale = nil

PluribusL = {
	dictionaries = DICTIONARIES,
}

function PluribusL:GetLanguage()
	local ov = NormalizeLocaleCode(overrideLocale)
	if not ov and _G.PluribusHive and _G.PluribusHive.GetConfig then
		local cfg = _G.PluribusHive:GetConfig()
		if cfg and cfg.language and cfg.language ~= "auto" then
			ov = NormalizeLocaleCode(cfg.language)
		end
	end
	if ov and DICTIONARIES[ov] then
		return ov
	end
	local clientLoc = (GetLocale and GetLocale()) or "enUS"
	if clientLoc == "deDE" or clientLoc == "deAT" or clientLoc == "deCH" then
		return "deDE"
	end
	return "enUS"
end

function PluribusL:SetLanguage(lang)
	local norm = NormalizeLocaleCode(lang)
	overrideLocale = norm or nil
	if _G.PluribusHive and _G.PluribusHive.SetConfig then
		_G.PluribusHive:SetConfig("language", norm or "auto")
	end
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("PLURIBUS_LOCALE_CHANGED", self:GetLanguage()) end)
	end
end

function PluribusL:Get(key, ...)
	local lang = self:GetLanguage()
	local dict = DICTIONARIES[lang] or EN
	local str = dict[key] or EN[key] or tostring(key)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, str, ...)
		if ok then return formatted end
	end
	return str
end

function PluribusL:T(key, ...)
	return self:Get(key, ...)
end

setmetatable(PluribusL, {
	__index = function(tbl, key)
		if type(key) ~= "string" then return nil end
		local lang = tbl:GetLanguage()
		local dict = DICTIONARIES[lang] or EN
		return dict[key] or EN[key] or key
	end,
})

_G.PluribusL = PluribusL
_G.L = PluribusL
return PluribusL
