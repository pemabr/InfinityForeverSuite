-- PluribusHive Classic Recipe Catalog (Vendor & Drop Sources)
-- Powers the "Unlearned Recipes" view inside Professions & native TradeSkill/Craft windows.
-- Every entry clearly marks sourceType ("VENDOR" or "DROP") plus NPC/Mob name, zone, and exact coordinates
-- so clicking any unlearned recipe immediately starts Pathfinder navigation (Compass + World Map + Minimap).

PluribusHiveRecipeCatalog = {}
_G.PluribusHiveRecipeCatalog = PluribusHiveRecipeCatalog

local PREFIX_PATTERNS = {
	"^recipe:%s*",
	"^plans:%s*",
	"^formula:%s*",
	"^pattern:%s*",
	"^schematic:%s*",
	"^manual:%s*",
	"^design:%s*",
	"^rezept:%s*",
	"^pläne:%s*",
	"^plaene:%s*",
	"^formel:%s*",
	"^muster:%s*",
	"^bauplan:%s*",
	"^handbuch:%s*",
	"^vorlage:%s*",
}

function PluribusHiveRecipeCatalog:NormalizeRecipeKey(str)
	local s = tostring(str or ""):lower():match("^%s*(.-)%s*$") or ""
	if s == "" then return "" end
	for _, pat in ipairs(PREFIX_PATTERNS) do
		s = s:gsub(pat, "")
	end
	s = s:gsub("[%p%s]+", " "):match("^%s*(.-)%s*$") or ""
	return s
end

-- Authentic Classic WoW Vendor & Drop Recipe Catalog across all crafting professions
-- Fields:
--   prof, name, nameDE, itemID (crafted item), recipeItemID (recipe scroll),
--   skill, sourceType ("VENDOR" | "DROP"), sourceName, zone, x, y, faction ("NEUTRAL"|"ALLIANCE"|"HORDE"), limited, note
PluribusHiveRecipeCatalog.ENTRIES = {
	-- =========================================================================
	-- ALCHEMY
	-- =========================================================================
	{
		prof = "Alchemy", name = "Minor Magic Resistance Potion", nameDE = "Schwacher Magiewiderstandstrank",
		itemID = 3384, recipeItemID = 3393, skill = 110, sourceType = "DROP",
		sourceName = "World Drop (Lv 18-30 Mobs)", zone = "Duskwood", x = 52.0, y = 42.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Alchemy", name = "Free Action Potion", nameDE = "Trank der freien Aktion",
		itemID = 5634, recipeItemID = 5642, skill = 150, sourceType = "VENDOR", limited = true,
		sourceName = "Ulthir (Darnassus)", zone = "Teldrassil", x = 55.3, y = 24.1, faction = "ALLIANCE",
		note = "Limited Stock · 18s",
	},
	{
		prof = "Alchemy", name = "Free Action Potion", nameDE = "Trank der freien Aktion",
		itemID = 5634, recipeItemID = 5642, skill = 150, sourceType = "VENDOR", limited = true,
		sourceName = "Kor'geld (Orgrimmar)", zone = "Durotar", x = 56.2, y = 34.4, faction = "HORDE",
		note = "Limited Stock · 18s",
	},
	{
		prof = "Alchemy", name = "Fire Protection Potion", nameDE = "Feuerschutztrank",
		itemID = 6049, recipeItemID = 6053, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Nandar Branson", zone = "Hillsbrad Foothills", x = 50.9, y = 57.1, faction = "ALLIANCE",
		note = "Limited Stock · 25s",
	},
	{
		prof = "Alchemy", name = "Fire Protection Potion", nameDE = "Feuerschutztrank",
		itemID = 6049, recipeItemID = 6053, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Jeeda", zone = "Stonetalon Mountains", x = 47.6, y = 61.6, faction = "HORDE",
		note = "Limited Stock · 25s",
	},
	{
		prof = "Alchemy", name = "Shadow Oil", nameDE = "Schattenöl",
		itemID = 3824, recipeItemID = 6068, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Bliztik", zone = "Duskwood", x = 18.0, y = 54.5, faction = "NEUTRAL",
		note = "Limited Stock · 25s",
	},
	{
		prof = "Alchemy", name = "Frost Protection Potion", nameDE = "Frostschutztrank",
		itemID = 6050, recipeItemID = 6056, skill = 190, sourceType = "VENDOR", limited = true,
		sourceName = "Bro'kin", zone = "Hillsbrad Foothills", x = 38.4, y = 38.8, faction = "NEUTRAL",
		note = "Limited Stock · 20s",
	},
	{
		prof = "Alchemy", name = "Nature Protection Potion", nameDE = "Naturschutztrank",
		itemID = 6052, recipeItemID = 6057, skill = 190, sourceType = "VENDOR", limited = true,
		sourceName = "Glyx Brewright", zone = "Stranglethorn Vale", x = 28.1, y = 78.1, faction = "NEUTRAL",
		note = "Limited Stock · 20s",
	},
	{
		prof = "Alchemy", name = "Frost Oil", nameDE = "Frostöl",
		itemID = 3829, recipeItemID = 14634, skill = 200, sourceType = "VENDOR", limited = true,
		sourceName = "Bro'kin", zone = "Hillsbrad Foothills", x = 38.4, y = 38.8, faction = "NEUTRAL",
		note = "Limited Stock · 25s",
	},
	{
		prof = "Alchemy", name = "Elixir of Greater Agility", nameDE = "Elixier der großen Beweglichkeit",
		itemID = 9187, recipeItemID = 9300, skill = 240, sourceType = "DROP",
		sourceName = "Deadwood & High-Lv Mobs", zone = "Felwood", x = 60.4, y = 18.2, faction = "NEUTRAL",
		note = "World Drop (Lv 45-55)",
	},
	{
		prof = "Alchemy", name = "Ghost Dye", nameDE = "Geisterfarbstoff",
		itemID = 9210, recipeItemID = 9302, skill = 245, sourceType = "VENDOR", limited = true,
		sourceName = "Logannas", zone = "Feralas", x = 32.7, y = 44.0, faction = "ALLIANCE",
		note = "Limited Stock · 90s",
	},
	{
		prof = "Alchemy", name = "Ghost Dye", nameDE = "Geisterfarbstoff",
		itemID = 9210, recipeItemID = 9302, skill = 245, sourceType = "VENDOR", limited = true,
		sourceName = "Bronk", zone = "Feralas", x = 76.1, y = 43.3, faction = "HORDE",
		note = "Limited Stock · 90s",
	},
	{
		prof = "Alchemy", name = "Limited Invulnerability Potion", nameDE = "Begrenzter Unverwundbarkeitstrank",
		itemID = 3387, recipeItemID = 3396, skill = 250, sourceType = "DROP",
		sourceName = "High-Level World Drop", zone = "Eastern Plaguelands", x = 58.0, y = 38.0, faction = "NEUTRAL",
		note = "World Drop (Lv 48-60)",
	},
	{
		prof = "Alchemy", name = "Mighty Rage Potion", nameDE = "Mächtiger Wuttrank",
		itemID = 13442, recipeItemID = 13476, skill = 255, sourceType = "DROP",
		sourceName = "Blackrock Slayer", zone = "Burning Steppes", x = 65.2, y = 37.8, faction = "NEUTRAL",
		note = "Drop ~4% · Burning Steppes",
	},
	{
		prof = "Alchemy", name = "Superior Mana Potion", nameDE = "Überragender Manatrank",
		itemID = 13443, recipeItemID = 13477, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Ulthir (Darnassus)", zone = "Teldrassil", x = 55.3, y = 24.1, faction = "ALLIANCE",
		note = "Limited Stock · 1g 20s",
	},
	{
		prof = "Alchemy", name = "Superior Mana Potion", nameDE = "Überragender Manatrank",
		itemID = 13443, recipeItemID = 13477, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Algernon (Undercity)", zone = "Tirisfal Glades", x = 51.8, y = 74.6, faction = "HORDE",
		note = "Limited Stock · 1g 20s",
	},
	{
		prof = "Alchemy", name = "Elixir of the Mongoose", nameDE = "Elixier des Mungos",
		itemID = 13452, recipeItemID = 13485, skill = 280, sourceType = "DROP",
		sourceName = "Jadefire Rogue / Legashi Rogue", zone = "Felwood", x = 40.8, y = 55.4, faction = "NEUTRAL",
		note = "Drop ~3.5% · Satyrs",
	},
	{
		prof = "Alchemy", name = "Greater Arcane Elixir", nameDE = "Großes Arkanelixier",
		itemID = 13454, recipeItemID = 13486, skill = 285, sourceType = "DROP",
		sourceName = "High-Level World Drop", zone = "Winterspring", x = 58.2, y = 44.5, faction = "NEUTRAL",
		note = "World Drop (Lv 55-60)",
	},
	{
		prof = "Alchemy", name = "Transmute: Arcanite", nameDE = "Transmutieren: Arkanit",
		itemID = 12360, recipeItemID = 12958, skill = 275, sourceType = "VENDOR",
		sourceName = "Alchemist Pestlezugg", zone = "Tanaris", x = 50.9, y = 27.0, faction = "NEUTRAL",
		note = "Always Available · 5g",
	},
	{
		prof = "Alchemy", name = "Major Healing Potion", nameDE = "Erheblicher Heiltrank",
		itemID = 13446, recipeItemID = 13480, skill = 275, sourceType = "VENDOR", limited = true,
		sourceName = "Evie Whirlbrew", zone = "Winterspring", x = 60.9, y = 37.8, faction = "NEUTRAL",
		note = "Limited Stock · 1g 50s",
	},
	{
		prof = "Alchemy", name = "Major Mana Potion", nameDE = "Erheblicher Manatrank",
		itemID = 13444, recipeItemID = 13493, skill = 295, sourceType = "DROP",
		sourceName = "Darkmaster Gandling", zone = "Western Plaguelands", x = 69.4, y = 73.1, faction = "NEUTRAL",
		note = "Scholomance Boss Drop",
	},
	{
		prof = "Alchemy", name = "Greater Fire Protection Potion", nameDE = "Großer Feuerschutztrank",
		itemID = 13457, recipeItemID = 13494, skill = 290, sourceType = "DROP",
		sourceName = "Firebrand Pyromancer (LBRS)", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Drop ~4% · LBRS",
	},
	{
		prof = "Alchemy", name = "Greater Nature Protection Potion", nameDE = "Großer Naturschutztrank",
		itemID = 13458, recipeItemID = 13496, skill = 290, sourceType = "DROP",
		sourceName = "Rotting Behemoth / Decaying Horror", zone = "Western Plaguelands", x = 63.8, y = 41.2, faction = "NEUTRAL",
		note = "Drop ~2% · WPL",
	},
	{
		prof = "Alchemy", name = "Greater Shadow Protection Potion", nameDE = "Großer Schattenschutztrank",
		itemID = 13459, recipeItemID = 13495, skill = 290, sourceType = "DROP",
		sourceName = "Dark Adept / Shadowmage", zone = "Eastern Plaguelands", x = 44.2, y = 66.5, faction = "NEUTRAL",
		note = "Drop ~3% · EPL",
	},
	{
		prof = "Alchemy", name = "Greater Arcane Protection Potion", nameDE = "Großer Arkanschutztrank",
		itemID = 13461, recipeItemID = 13497, skill = 290, sourceType = "DROP",
		sourceName = "Cobalt Mageweaver", zone = "Winterspring", x = 57.6, y = 50.8, faction = "NEUTRAL",
		note = "Drop ~4% · Mazthoril",
	},
	{
		prof = "Alchemy", name = "Living Action Potion", nameDE = "Trank der lebhaften Aktion",
		itemID = 20008, recipeItemID = 20013, skill = 285, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Exalted",
	},
	{
		prof = "Alchemy", name = "Mageblood Potion", nameDE = "Magierbluttrank",
		itemID = 20007, recipeItemID = 20011, skill = 275, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Revered",
	},
	{
		prof = "Alchemy", name = "Flask of the Titans", nameDE = "Fläschchen der Titanen",
		itemID = 13510, recipeItemID = 13518, skill = 300, sourceType = "DROP",
		sourceName = "General Drakkisath (UBRS)", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "UBRS Final Boss Drop",
	},
	{
		prof = "Alchemy", name = "Flask of Supreme Power", nameDE = "Fläschchen mit oberster Macht",
		itemID = 13512, recipeItemID = 13520, skill = 300, sourceType = "DROP",
		sourceName = "Ras Frostwhisper (Scholomance)", zone = "Western Plaguelands", x = 69.4, y = 73.1, faction = "NEUTRAL",
		note = "Scholomance Boss Drop",
	},
	{
		prof = "Alchemy", name = "Flask of Distilled Wisdom", nameDE = "Fläschchen mit destillierter Weisheit",
		itemID = 13511, recipeItemID = 13519, skill = 300, sourceType = "DROP",
		sourceName = "Balnazzar (Stratholme Live)", zone = "Eastern Plaguelands", x = 31.2, y = 14.0, faction = "NEUTRAL",
		note = "Stratholme Boss Drop",
	},

	-- =========================================================================
	-- BLACKSMITHING
	-- =========================================================================
	{
		prof = "Blacksmithing", name = "Silvered Bronze Shoulders", nameDE = "Versilberte Bronzeschultern",
		itemID = 3482, recipeItemID = 3609, skill = 125, sourceType = "DROP",
		sourceName = "World Drop (Lv 18-30)", zone = "Redridge Mountains", x = 44.0, y = 48.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Blacksmithing", name = "Moonsteel Broadsword", nameDE = "Mondstahlbreitschwert",
		itemID = 3847, recipeItemID = 12162, skill = 180, sourceType = "VENDOR", limited = true,
		sourceName = "Zarena Cromwind", zone = "Stranglethorn Vale", x = 28.4, y = 75.5, faction = "NEUTRAL",
		note = "Limited Stock · 44s",
	},
	{
		prof = "Blacksmithing", name = "Frost Tiger Blade", nameDE = "Frosttigerklinge",
		itemID = 3854, recipeItemID = 3871, skill = 200, sourceType = "DROP",
		sourceName = "Mid-Level World Drop", zone = "Arathi Highlands", x = 48.0, y = 52.0, faction = "NEUTRAL",
		note = "World Drop (Lv 35-45)",
	},
	{
		prof = "Blacksmithing", name = "Solid Iron Maul", nameDE = "Robuster Eisenschlägel",
		itemID = 3852, recipeItemID = 10858, skill = 155, sourceType = "VENDOR", limited = true,
		sourceName = "Jannos Ironwill", zone = "Arathi Highlands", x = 46.0, y = 47.7, faction = "ALLIANCE",
		note = "Limited Stock · 30s",
	},
	{
		prof = "Blacksmithing", name = "Solid Iron Maul", nameDE = "Robuster Eisenschlägel",
		itemID = 3852, recipeItemID = 10858, skill = 155, sourceType = "VENDOR", limited = true,
		sourceName = "Muuran", zone = "Desolace", x = 55.6, y = 56.5, faction = "HORDE",
		note = "Limited Stock · 30s",
	},
	{
		prof = "Blacksmithing", name = "Mithril Spurs", nameDE = "Mithrilsporen",
		itemID = 7969, recipeItemID = 7989, skill = 235, sourceType = "DROP",
		sourceName = "World Drop (Lv 40-50)", zone = "Tanaris", x = 56.0, y = 46.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Blacksmithing", name = "Thorium Shield Spike", nameDE = "Thoriumschildstachel",
		itemID = 12645, recipeItemID = 12824, skill = 275, sourceType = "DROP",
		sourceName = "High-Level World Drop", zone = "Eastern Plaguelands", x = 55.0, y = 48.0, faction = "NEUTRAL",
		note = "World Drop (Lv 53-60)",
	},
	{
		prof = "Blacksmithing", name = "Elemental Sharpening Stone", nameDE = "Elementarwetzstein",
		itemID = 18262, recipeItemID = 18264, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Blacksmithing", name = "Arcanite Reaper", nameDE = "Arkanitschnitter",
		itemID = 12784, recipeItemID = 12821, skill = 300, sourceType = "DROP",
		sourceName = "Bannok Grimaxe (LBRS)", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "LBRS Rare Boss Drop",
	},
	{
		prof = "Blacksmithing", name = "Lionheart Helm", nameDE = "Löwenherzhelm",
		itemID = 12640, recipeItemID = 12699, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World / Raid Drop", zone = "Winterspring", x = 58.0, y = 52.0, faction = "NEUTRAL",
		note = "Rare Lv 58-60 Drop",
	},
	{
		prof = "Blacksmithing", name = "Titanic Leggings", nameDE = "Gamaschen der Titanen",
		itemID = 22385, recipeItemID = 22388, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World / Raid Drop", zone = "Eastern Plaguelands", x = 62.0, y = 34.0, faction = "NEUTRAL",
		note = "Rare Lv 58-60 Drop",
	},
	{
		prof = "Blacksmithing", name = "Fiery Chain Girdle", nameDE = "Feuriger Kettengurt",
		itemID = 16989, recipeItemID = 17049, skill = 295, sourceType = "VENDOR",
		sourceName = "Lokhtos Darkbargainer (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "Thorium Brotherhood · Friendly",
	},
	{
		prof = "Blacksmithing", name = "Dark Iron Bracers", nameDE = "Dunkeleisenarmschienen",
		itemID = 17014, recipeItemID = 17051, skill = 295, sourceType = "VENDOR",
		sourceName = "Lokhtos Darkbargainer (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "Thorium Brotherhood · Friendly",
	},
	{
		prof = "Blacksmithing", name = "Dark Iron Helm", nameDE = "Dunkeleisenhelm",
		itemID = 19148, recipeItemID = 19206, skill = 300, sourceType = "VENDOR",
		sourceName = "Lokhtos Darkbargainer (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "Thorium Brotherhood · Exalted",
	},
	{
		prof = "Blacksmithing", name = "Darksoul Breastplate", nameDE = "Dunkelseelenbrustplatte",
		itemID = 19690, recipeItemID = 19776, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Revered",
	},
	{
		prof = "Blacksmithing", name = "Sageblade", nameDE = "Weisenklinge",
		itemID = 22383, recipeItemID = 22390, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World / Raid Drop", zone = "Silithus", x = 44.0, y = 42.0, faction = "NEUTRAL",
		note = "Rare Lv 60 Drop",
	},

	-- =========================================================================
	-- ENCHANTING
	-- =========================================================================
	{
		prof = "Enchanting", name = "Enchant Bracer - Minor Agility", nameDE = "Armschiene - Schwache Beweglichkeit",
		itemID = 6349, recipeItemID = 6349, skill = 80, sourceType = "VENDOR", limited = true,
		sourceName = "Dalria", zone = "Ashenvale", x = 35.1, y = 52.1, faction = "ALLIANCE",
		note = "Limited Stock · 10s",
	},
	{
		prof = "Enchanting", name = "Enchant Bracer - Minor Agility", nameDE = "Armschiene - Schwache Beweglichkeit",
		itemID = 6349, recipeItemID = 6349, skill = 80, sourceType = "VENDOR", limited = true,
		sourceName = "Kulwia", zone = "Stonetalon Mountains", x = 45.4, y = 59.4, faction = "HORDE",
		note = "Limited Stock · 10s",
	},
	{
		prof = "Enchanting", name = "Enchant Boots - Minor Speed", nameDE = "Stiefel - Schwaches Tempo",
		itemID = 11163, recipeItemID = 11163, skill = 225, sourceType = "DROP",
		sourceName = "World Drop (Lv 38-48)", zone = "Stranglethorn Vale", x = 42.0, y = 45.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Fiery Weapon", nameDE = "Waffe - Feurige Waffe",
		itemID = 11207, recipeItemID = 11207, skill = 265, sourceType = "DROP",
		sourceName = "Pyromancer Loregrain (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "BRD Boss Drop (~30%)",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Crusader", nameDE = "Waffe - Kreuzfahrer",
		itemID = 16252, recipeItemID = 16252, skill = 300, sourceType = "DROP",
		sourceName = "Scarlet Spellbinder / Archmage", zone = "Western Plaguelands", x = 54.4, y = 26.2, faction = "NEUTRAL",
		note = "Drop ~1.5% · Hearthglen / Tyr's Hand",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Lifestealing", nameDE = "Waffe - Lebensdiebstahl",
		itemID = 16254, recipeItemID = 16254, skill = 300, sourceType = "DROP",
		sourceName = "Spectral Researcher (Scholomance)", zone = "Western Plaguelands", x = 69.4, y = 73.1, faction = "NEUTRAL",
		note = "Scholomance Drop (~3%)",
	},
	{
		prof = "Enchanting", name = "Enchant Chest - Greater Stats", nameDE = "Brust - Große Werte",
		itemID = 16253, recipeItemID = 16253, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World Drop (Lv 56+)", zone = "Eastern Plaguelands", x = 60.0, y = 38.0, faction = "NEUTRAL",
		note = "Rare World Drop",
	},
	{
		prof = "Enchanting", name = "Enchant Bracer - Superior Stamina", nameDE = "Armschiene - Überragende Ausdauer",
		itemID = 16251, recipeItemID = 16251, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World Drop (Lv 55+)", zone = "Winterspring", x = 60.0, y = 42.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Enchanting", name = "Enchant Gloves - Greater Agility", nameDE = "Handschuhe - Große Beweglichkeit",
		itemID = 16244, recipeItemID = 16244, skill = 270, sourceType = "DROP",
		sourceName = "Legashi Rogue", zone = "Azshara", x = 52.8, y = 26.4, faction = "NEUTRAL",
		note = "Drop ~2.5% · Azshara",
	},
	{
		prof = "Enchanting", name = "Enchant Cloak - Greater Resistance", nameDE = "Umhang - Großer Widerstand",
		itemID = 16242, recipeItemID = 16242, skill = 265, sourceType = "DROP",
		sourceName = "Atal'ai Witch Doctor (Sunken Temple)", zone = "Swamp of Sorrows", x = 70.0, y = 53.0, faction = "NEUTRAL",
		note = "Sunken Temple Drop",
	},
	{
		prof = "Enchanting", name = "Runed Arcanite Rod", nameDE = "Runenverzierte Arkanitrute",
		itemID = 16207, recipeItemID = 16221, skill = 290, sourceType = "VENDOR", limited = true,
		sourceName = "Lorelae Wintersong", zone = "Felwood", x = 48.6, y = 40.2, faction = "NEUTRAL",
		note = "Moonglade Vendor · 2g 20s",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Agility (+15)", nameDE = "Waffe - Beweglichkeit (+15)",
		itemID = 19445, recipeItemID = 19445, skill = 290, sourceType = "VENDOR",
		sourceName = "Meilosh", zone = "Felwood", x = 65.7, y = 2.9, faction = "NEUTRAL",
		note = "Timbermaw Hold · Honored",
	},
	{
		prof = "Enchanting", name = "Enchant 2H Weapon - Agility (+25)", nameDE = "Zweihandwaffe - Beweglichkeit (+25)",
		itemID = 22392, recipeItemID = 22392, skill = 290, sourceType = "VENDOR",
		sourceName = "Meilosh", zone = "Felwood", x = 65.7, y = 2.9, faction = "NEUTRAL",
		note = "Timbermaw Hold · Honored",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Spell Power (+30)", nameDE = "Waffe - Zauberkraft (+30)",
		itemID = 18259, recipeItemID = 18259, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Enchanting", name = "Enchant Weapon - Healing Power (+55)", nameDE = "Waffe - Heilkraft (+55)",
		itemID = 18260, recipeItemID = 18260, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Enchanting", name = "Brilliant Wizard Oil", nameDE = "Hervorragendes Zauberöl",
		itemID = 20749, recipeItemID = 20753, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Friendly",
	},
	{
		prof = "Enchanting", name = "Brilliant Mana Oil", nameDE = "Hervorragendes Manaöl",
		itemID = 20748, recipeItemID = 20752, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Friendly",
	},

	-- =========================================================================
	-- ENGINEERING
	-- =========================================================================
	{
		prof = "Engineering", name = "Mechanical Squirrel Box", nameDE = "Kiste mit mechanischem Eichhörnchen",
		itemID = 4401, recipeItemID = 4408, skill = 75, sourceType = "DROP",
		sourceName = "World Drop (Lv 10-20)", zone = "Westfall", x = 44.0, y = 56.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Engineering", name = "Goblin Jumper Cables", nameDE = "Goblin-Überbrückungskabel",
		itemID = 7148, recipeItemID = 7561, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Mazk Snipeshot", zone = "Stranglethorn Vale", x = 28.5, y = 75.1, faction = "NEUTRAL",
		note = "Limited Stock · 20s",
	},
	{
		prof = "Engineering", name = "Gnomish Cloaking Device", nameDE = "Gnomisches Tarngerät",
		itemID = 4397, recipeItemID = 7742, skill = 200, sourceType = "VENDOR", limited = true,
		sourceName = "Zan Shivsproket", zone = "Hillsbrad Foothills", x = 86.2, y = 79.4, faction = "NEUTRAL",
		note = "Ravenholdt Manor · Limited",
	},
	{
		prof = "Engineering", name = "Deepdive Helmet", nameDE = "Tiefseetaucherhelm",
		itemID = 10506, recipeItemID = 10602, skill = 230, sourceType = "VENDOR", limited = true,
		sourceName = "Gagsprocket", zone = "The Barrens", x = 62.7, y = 36.3, faction = "NEUTRAL",
		note = "Ratchet · Limited Stock",
	},
	{
		prof = "Engineering", name = "Sniper Scope", nameDE = "Heckenschützen-Zielfernrohr",
		itemID = 10548, recipeItemID = 10607, skill = 240, sourceType = "DROP",
		sourceName = "World Drop (Lv 42-52)", zone = "Tanaris", x = 50.0, y = 42.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Engineering", name = "Thorium Widget", nameDE = "Thoriumapparat",
		itemID = 15994, recipeItemID = 16041, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Xizzer Fizzbolt", zone = "Winterspring", x = 60.8, y = 38.6, faction = "NEUTRAL",
		note = "Everlook · Limited Stock",
	},
	{
		prof = "Engineering", name = "Thorium Tube", nameDE = "Thoriumröhre",
		itemID = 16000, recipeItemID = 16046, skill = 275, sourceType = "VENDOR", limited = true,
		sourceName = "Xizzer Fizzbolt", zone = "Winterspring", x = 60.8, y = 38.6, faction = "NEUTRAL",
		note = "Everlook · Limited Stock",
	},
	{
		prof = "Engineering", name = "Goblin Jumper Cables XL", nameDE = "Goblin-Überbrückungskabel XL",
		itemID = 18587, recipeItemID = 18650, skill = 265, sourceType = "DROP",
		sourceName = "Plugger Spazzring (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "BRD Grim Guzzler Drop",
	},
	{
		prof = "Engineering", name = "Field Repair Bot 74A", nameDE = "Feldreparaturbot 74A",
		itemID = 18232, recipeItemID = 18232, skill = 300, sourceType = "DROP",
		sourceName = "Golem Lord Argelmach Floor Scroll (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "BRD Clickable Schematic",
	},
	{
		prof = "Engineering", name = "Arcanite Dragonling", nameDE = "Arkanitdrachling",
		itemID = 16022, recipeItemID = 16054, skill = 300, sourceType = "DROP",
		sourceName = "Cobalt Mageweaver", zone = "Winterspring", x = 57.6, y = 50.8, faction = "NEUTRAL",
		note = "Drop ~4% · Mazthoril",
	},
	{
		prof = "Engineering", name = "Hyper-Radiant Flame Reflector", nameDE = "Hyperstrahlender Flammenreflektor",
		itemID = 18638, recipeItemID = 18657, skill = 290, sourceType = "DROP",
		sourceName = "Solakar Flamewreath (UBRS)", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "UBRS Boss Drop",
	},
	{
		prof = "Engineering", name = "Gyrofreeze Ice Reflector", nameDE = "Gyrofrost-Eisreflektor",
		itemID = 18634, recipeItemID = 18652, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Xizzer Fizzbolt", zone = "Winterspring", x = 60.8, y = 38.6, faction = "NEUTRAL",
		note = "Everlook · Limited Stock",
	},
	{
		prof = "Engineering", name = "Ultra-Flash Shadow Reflector", nameDE = "Ultrablitz-Schattenreflektor",
		itemID = 18639, recipeItemID = 18658, skill = 300, sourceType = "DROP",
		sourceName = "Crimson Inquisitor (Stratholme)", zone = "Eastern Plaguelands", x = 31.2, y = 14.0, faction = "NEUTRAL",
		note = "Stratholme Live Drop",
	},
	{
		prof = "Engineering", name = "Biznicks 247x128 Accurascope", nameDE = "Biznicks 247x128 Zielfernrohr",
		itemID = 18283, recipeItemID = 18290, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Engineering", name = "Force Reactive Disk", nameDE = "Machtreaktive Scheibe",
		itemID = 18168, recipeItemID = 18291, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Engineering", name = "Core Marksman Rifle", nameDE = "Kernscharfschützengewehr",
		itemID = 18282, recipeItemID = 18292, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},

	-- =========================================================================
	-- LEATHERWORKING
	-- =========================================================================
	{
		prof = "Leatherworking", name = "Deviate Scale Gloves", nameDE = "Deviatschuppenhandschuhe",
		itemID = 6466, recipeItemID = 6474, skill = 105, sourceType = "DROP",
		sourceName = "Deviate Mobs (Wailing Caverns)", zone = "The Barrens", x = 46.2, y = 35.8, faction = "NEUTRAL",
		note = "Wailing Caverns Drop",
	},
	{
		prof = "Leatherworking", name = "Deviate Scale Belt", nameDE = "Deviatschuppengürtel",
		itemID = 6468, recipeItemID = 6475, skill = 115, sourceType = "DROP",
		sourceName = "Deviate Mobs (Wailing Caverns)", zone = "The Barrens", x = 46.2, y = 35.8, faction = "NEUTRAL",
		note = "Wailing Caverns Drop",
	},
	{
		prof = "Leatherworking", name = "Raptor Hide Harness", nameDE = "Raptorbalgharnisch",
		itemID = 4455, recipeItemID = 13287, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Tunkk", zone = "Arathi Highlands", x = 74.8, y = 36.4, faction = "HORDE",
		note = "Hammerfall · Limited Stock",
	},
	{
		prof = "Leatherworking", name = "Raptor Hide Belt", nameDE = "Raptorbalggürtel",
		itemID = 4456, recipeItemID = 13288, skill = 165, sourceType = "VENDOR", limited = true,
		sourceName = "Androd Fadran", zone = "Arathi Highlands", x = 45.1, y = 59.1, faction = "ALLIANCE",
		note = "Refuge Pointe · Limited Stock",
	},
	{
		prof = "Leatherworking", name = "Turtle Scale Gloves", nameDE = "Schildkrötenschuppenhandschuhe",
		itemID = 8187, recipeItemID = 8385, skill = 205, sourceType = "VENDOR", limited = true,
		sourceName = "Jandia", zone = "Thousand Needles", x = 46.1, y = 51.5, faction = "HORDE",
		note = "Freewind Post · Limited",
	},
	{
		prof = "Leatherworking", name = "Turtle Scale Gloves", nameDE = "Schildkrötenschuppenhandschuhe",
		itemID = 8187, recipeItemID = 8385, skill = 205, sourceType = "VENDOR", limited = true,
		sourceName = "Nioma", zone = "The Hinterlands", x = 13.4, y = 43.3, faction = "ALLIANCE",
		note = "Aerie Peak · Limited",
	},
	{
		prof = "Leatherworking", name = "Wicked Leather Gauntlets", nameDE = "Tückische Lederstulpen",
		itemID = 15083, recipeItemID = 15724, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Leonard Porter", zone = "Western Plaguelands", x = 43.0, y = 84.3, faction = "ALLIANCE",
		note = "Chillwind Camp · Limited",
	},
	{
		prof = "Leatherworking", name = "Wicked Leather Gauntlets", nameDE = "Tückische Lederstulpen",
		itemID = 15083, recipeItemID = 15724, skill = 260, sourceType = "VENDOR", limited = true,
		sourceName = "Werg Thickblade", zone = "Tirisfal Glades", x = 83.2, y = 69.7, faction = "HORDE",
		note = "The Bulwark · Limited",
	},
	{
		prof = "Leatherworking", name = "Devilsaur Gauntlets", nameDE = "Teufelssaurierstulpen",
		itemID = 15063, recipeItemID = 15758, skill = 290, sourceType = "VENDOR", limited = true,
		sourceName = "Nergal", zone = "Un'Goro Crater", x = 43.3, y = 7.7, faction = "NEUTRAL",
		note = "Marshal's Refuge · Limited",
	},
	{
		prof = "Leatherworking", name = "Devilsaur Leggings", nameDE = "Teufelssauriergamaschen",
		itemID = 15062, recipeItemID = 15772, skill = 300, sourceType = "DROP",
		sourceName = "Cloned Ooze / Primal Ooze", zone = "Un'Goro Crater", x = 52.4, y = 44.2, faction = "NEUTRAL",
		note = "Drop ~1.5% · Un'Goro Oozes",
	},
	{
		prof = "Leatherworking", name = "Frostsaber Boots", nameDE = "Frostsäblerstiefel",
		itemID = 15070, recipeItemID = 15740, skill = 275, sourceType = "DROP",
		sourceName = "Winterfall Totemic", zone = "Winterspring", x = 67.2, y = 37.8, faction = "NEUTRAL",
		note = "Drop ~4% · Winterfall Village",
	},
	{
		prof = "Leatherworking", name = "Stormshroud Armor", nameDE = "Sturmschleierrüstung",
		itemID = 15056, recipeItemID = 15764, skill = 300, sourceType = "DROP",
		sourceName = "Arkkoran Oracle", zone = "Azshara", x = 77.6, y = 42.4, faction = "NEUTRAL",
		note = "Drop ~2.5% · Azshara",
	},
	{
		prof = "Leatherworking", name = "Hide of the Wild", nameDE = "Balg der Wildnis",
		itemID = 18510, recipeItemID = 18518, skill = 300, sourceType = "DROP",
		sourceName = "Knot Thimblejack's Cache (Dire Maul)", zone = "Feralas", x = 59.1, y = 44.3, faction = "NEUTRAL",
		note = "Dire Maul North Cache",
	},
	{
		prof = "Leatherworking", name = "Shifting Cloak", nameDE = "Veränderlicher Umhang",
		itemID = 18511, recipeItemID = 18519, skill = 300, sourceType = "DROP",
		sourceName = "Knot Thimblejack's Cache (Dire Maul)", zone = "Feralas", x = 59.1, y = 44.3, faction = "NEUTRAL",
		note = "Dire Maul North Cache",
	},
	{
		prof = "Leatherworking", name = "Corehound Boots", nameDE = "Kernhundstiefel",
		itemID = 16982, recipeItemID = 17023, skill = 295, sourceType = "VENDOR",
		sourceName = "Lokhtos Darkbargainer (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "Thorium Brotherhood · Honored",
	},
	{
		prof = "Leatherworking", name = "Core Armor Kit", nameDE = "Kernrüstungsset",
		itemID = 18251, recipeItemID = 18252, skill = 300, sourceType = "DROP",
		sourceName = "Molten Core Bosses", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "Molten Core Raid Drop",
	},
	{
		prof = "Leatherworking", name = "Blood Tiger Breastplate", nameDE = "Bluttigerbrustplatte",
		itemID = 19685, recipeItemID = 19770, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Honored",
	},

	-- =========================================================================
	-- TAILORING
	-- =========================================================================
	{
		prof = "Tailoring", name = "Spidersilk Boots", nameDE = "Spinnenseidenstiefel",
		itemID = 4320, recipeItemID = 4348, skill = 125, sourceType = "DROP",
		sourceName = "World Drop (Lv 18-30)", zone = "Duskwood", x = 36.0, y = 46.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Tailoring", name = "Azure Silk Cloak", nameDE = "Azurblauer Seidenumhang",
		itemID = 7053, recipeItemID = 7087, skill = 175, sourceType = "VENDOR", limited = true,
		sourceName = "Borya (Orgrimmar)", zone = "Durotar", x = 63.0, y = 51.2, faction = "HORDE",
		note = "Limited Stock · 30s",
	},
	{
		prof = "Tailoring", name = "Azure Silk Cloak", nameDE = "Azurblauer Seidenumhang",
		itemID = 7053, recipeItemID = 7087, skill = 175, sourceType = "VENDOR", limited = true,
		sourceName = "Elynna (Darnassus)", zone = "Teldrassil", x = 64.4, y = 21.6, faction = "ALLIANCE",
		note = "Limited Stock · 30s",
	},
	{
		prof = "Tailoring", name = "Dreamweave Gloves", nameDE = "Traumzwirnhandschuhe",
		itemID = 10019, recipeItemID = 10311, skill = 225, sourceType = "DROP",
		sourceName = "World Drop (Lv 38-48)", zone = "Tanaris", x = 52.0, y = 48.0, faction = "NEUTRAL",
		note = "World Drop",
	},
	{
		prof = "Tailoring", name = "Runecloth Bag", nameDE = "Runenstofftasche",
		itemID = 14046, recipeItemID = 14468, skill = 260, sourceType = "VENDOR",
		sourceName = "Qia", zone = "Winterspring", x = 61.2, y = 37.2, faction = "NEUTRAL",
		note = "Everlook · 1g 20s",
	},
	{
		prof = "Tailoring", name = "Runecloth Gloves", nameDE = "Runenstoffhandschuhe",
		itemID = 13863, recipeItemID = 14481, skill = 275, sourceType = "VENDOR", limited = true,
		sourceName = "Qia", zone = "Winterspring", x = 61.2, y = 37.2, faction = "NEUTRAL",
		note = "Everlook · Limited Stock",
	},
	{
		prof = "Tailoring", name = "Mooncloth", nameDE = "Mondstoff",
		itemID = 14342, recipeItemID = 14483, skill = 250, sourceType = "VENDOR",
		sourceName = "Qia", zone = "Winterspring", x = 61.2, y = 37.2, faction = "NEUTRAL",
		note = "Everlook · Always Available",
	},
	{
		prof = "Tailoring", name = "Mooncloth Bag", nameDE = "Mondstofftasche",
		itemID = 14155, recipeItemID = 14510, skill = 300, sourceType = "DROP",
		sourceName = "High-Level World Drop (Lv 55+)", zone = "Eastern Plaguelands", x = 54.0, y = 42.0, faction = "NEUTRAL",
		note = "Rare World Drop",
	},
	{
		prof = "Tailoring", name = "Bottomless Bag", nameDE = "Bodenlose Tasche",
		itemID = 14156, recipeItemID = 14511, skill = 300, sourceType = "DROP",
		sourceName = "High-Level Raid / World Drop", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "18-Slot Bag · Rare Drop",
	},
	{
		prof = "Tailoring", name = "Felcloth Gloves", nameDE = "Teufelsstoffhandschuhe",
		itemID = 18407, recipeItemID = 18487, skill = 285, sourceType = "DROP",
		sourceName = "Jadefire Satyrs", zone = "Felwood", x = 40.8, y = 55.4, faction = "NEUTRAL",
		note = "Drop ~2% · Felwood",
	},
	{
		prof = "Tailoring", name = "Truefaith Vestments", nameDE = "Gewänder des wahren Glaubens",
		itemID = 14154, recipeItemID = 14512, skill = 300, sourceType = "DROP",
		sourceName = "Balnazzar (Stratholme Live)", zone = "Eastern Plaguelands", x = 31.2, y = 14.0, faction = "NEUTRAL",
		note = "Stratholme Boss Drop",
	},
	{
		prof = "Tailoring", name = "Robe of the Archmage", nameDE = "Robe des Erzmagiers",
		itemID = 14152, recipeItemID = 14513, skill = 300, sourceType = "DROP",
		sourceName = "Firebrand Pyromancer (LBRS)", zone = "Burning Steppes", x = 29.4, y = 38.2, faction = "NEUTRAL",
		note = "LBRS Drop (~5%)",
	},
	{
		prof = "Tailoring", name = "Robe of the Void", nameDE = "Robe der Leere",
		itemID = 14153, recipeItemID = 14514, skill = 300, sourceType = "DROP",
		sourceName = "Darkmaster Gandling (Scholomance)", zone = "Western Plaguelands", x = 69.4, y = 73.1, faction = "NEUTRAL",
		note = "Scholomance Final Boss",
	},
	{
		prof = "Tailoring", name = "Flarecore Mantle", nameDE = "Flimmerkernmantel",
		itemID = 16980, recipeItemID = 17017, skill = 300, sourceType = "VENDOR",
		sourceName = "Lokhtos Darkbargainer (BRD)", zone = "Searing Gorge", x = 35.1, y = 84.9, faction = "NEUTRAL",
		note = "Thorium Brotherhood · Friendly",
	},
	{
		prof = "Tailoring", name = "Bloodvine Vest", nameDE = "Blutrebenweste",
		itemID = 19682, recipeItemID = 19764, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Revered",
	},
	{
		prof = "Tailoring", name = "Bloodvine Leggings", nameDE = "Blutrebengamaschen",
		itemID = 19683, recipeItemID = 19765, skill = 300, sourceType = "VENDOR",
		sourceName = "Rin'wosho the Trader", zone = "Stranglethorn Vale", x = 15.1, y = 16.0, faction = "NEUTRAL",
		note = "Zandalar Tribe · Honored",
	},

	-- =========================================================================
	-- COOKING
	-- =========================================================================
	{
		prof = "Cooking", name = "Savory Deviate Delight", nameDE = "Pikantes Deviat-Supreme",
		itemID = 6657, recipeItemID = 6661, skill = 85, sourceType = "DROP",
		sourceName = "Barrens Humanoids & Beasts", zone = "The Barrens", x = 51.5, y = 30.3, faction = "NEUTRAL",
		note = "Barrens Zone Drop",
	},
	{
		prof = "Cooking", name = "Westfall Stew", nameDE = "Westfall-Eintopf",
		itemID = 733, recipeItemID = 728, skill = 75, sourceType = "VENDOR",
		sourceName = "Kriggon Talsone", zone = "Westfall", x = 36.2, y = 90.1, faction = "ALLIANCE",
		note = "Westfall Coast · 2s",
	},
	{
		prof = "Cooking", name = "Bristle Whisker Catfish", nameDE = "Stoppelfühlerwels",
		itemID = 4593, recipeItemID = 6330, skill = 100, sourceType = "VENDOR",
		sourceName = "Stuart Fleming", zone = "Wetlands", x = 8.1, y = 58.3, faction = "ALLIANCE",
		note = "Menethil Harbor · 12s",
	},
	{
		prof = "Cooking", name = "Bristle Whisker Catfish", nameDE = "Stoppelfühlerwels",
		itemID = 4593, recipeItemID = 6330, skill = 100, sourceType = "VENDOR",
		sourceName = "Derak Nightfall", zone = "Hillsbrad Foothills", x = 63.1, y = 19.3, faction = "HORDE",
		note = "Tarren Mill · 12s",
	},
	{
		prof = "Cooking", name = "Roast Raptor", nameDE = "Gerösteter Raptor",
		itemID = 12212, recipeItemID = 12233, skill = 175, sourceType = "VENDOR",
		sourceName = "Corporal Bluth", zone = "Stranglethorn Vale", x = 38.0, y = 3.0, faction = "ALLIANCE",
		note = "Rebel Camp · 50s",
	},
	{
		prof = "Cooking", name = "Roast Raptor", nameDE = "Gerösteter Raptor",
		itemID = 12212, recipeItemID = 12233, skill = 175, sourceType = "VENDOR",
		sourceName = "Nerrist", zone = "Stranglethorn Vale", x = 32.7, y = 29.2, faction = "HORDE",
		note = "Grom'gol · 50s",
	},
	{
		prof = "Cooking", name = "Dragonbreath Chili", nameDE = "Drachenodemchili",
		itemID = 12217, recipeItemID = 12240, skill = 200, sourceType = "VENDOR",
		sourceName = "Helenia Olden", zone = "Dustwallow Marsh", x = 66.4, y = 51.5, faction = "ALLIANCE",
		note = "Theramore · 70s",
	},
	{
		prof = "Cooking", name = "Dragonbreath Chili", nameDE = "Drachenodemchili",
		itemID = 12217, recipeItemID = 12240, skill = 200, sourceType = "VENDOR",
		sourceName = "Ogg'marr", zone = "Dustwallow Marsh", x = 36.7, y = 31.0, faction = "HORDE",
		note = "Brackenwall Village · 70s",
	},
	{
		prof = "Cooking", name = "Spotted Yellowtail", nameDE = "Tüpfelgelbschwanz",
		itemID = 6887, recipeItemID = 13940, skill = 225, sourceType = "VENDOR",
		sourceName = "Gikkix", zone = "Tanaris", x = 66.6, y = 22.1, faction = "NEUTRAL",
		note = "Steamwheedle Port · 1g 60s",
	},
	{
		prof = "Cooking", name = "Monster Omelette", nameDE = "Monsteromelett",
		itemID = 12218, recipeItemID = 16110, skill = 225, sourceType = "VENDOR",
		sourceName = "Himmik", zone = "Winterspring", x = 61.3, y = 39.1, faction = "NEUTRAL",
		note = "Everlook · 1g 20s",
	},
	{
		prof = "Cooking", name = "Tender Wolf Steak", nameDE = "Zartes Wolfsteak",
		itemID = 18045, recipeItemID = 18046, skill = 225, sourceType = "VENDOR",
		sourceName = "Dirge Quikcleave", zone = "Tanaris", x = 52.6, y = 28.1, faction = "NEUTRAL",
		note = "Gadgetzan · 1g 20s",
	},
	{
		prof = "Cooking", name = "Grilled Squid", nameDE = "Gegrillter Kalmar",
		itemID = 13928, recipeItemID = 13942, skill = 240, sourceType = "VENDOR",
		sourceName = "Gikkix", zone = "Tanaris", x = 66.6, y = 22.1, faction = "NEUTRAL",
		note = "Steamwheedle Port · 1g 60s",
	},
	{
		prof = "Cooking", name = "Nightfin Soup", nameDE = "Nachtflossensuppe",
		itemID = 13931, recipeItemID = 13945, skill = 250, sourceType = "VENDOR",
		sourceName = "Gikkix", zone = "Tanaris", x = 66.6, y = 22.1, faction = "NEUTRAL",
		note = "Steamwheedle Port · 2g",
	},
	{
		prof = "Cooking", name = "Baked Salmon", nameDE = "Gebackener Lachs",
		itemID = 13935, recipeItemID = 13949, skill = 275, sourceType = "VENDOR",
		sourceName = "Vivianna", zone = "Feralas", x = 31.3, y = 43.5, faction = "ALLIANCE",
		note = "Feathermoon · 2g 20s",
	},
	{
		prof = "Cooking", name = "Baked Salmon", nameDE = "Gebackener Lachs",
		itemID = 13935, recipeItemID = 13949, skill = 275, sourceType = "VENDOR",
		sourceName = "Sheendra Tallgrass", zone = "Feralas", x = 74.5, y = 42.8, faction = "HORDE",
		note = "Camp Mojache · 2g 20s",
	},
	{
		prof = "Cooking", name = "Runn Tum Tuber Surprise", nameDE = "Runn Tum Knolle Surprise",
		itemID = 18254, recipeItemID = 18267, skill = 275, sourceType = "DROP",
		sourceName = "Pusillin (Dire Maul East)", zone = "Feralas", x = 59.1, y = 44.3, faction = "NEUTRAL",
		note = "Dire Maul East Boss Drop",
	},
	{
		prof = "Cooking", name = "Smoked Desert Dumplings", nameDE = "Geräucherte Wüstenknödel",
		itemID = 20452, recipeItemID = 20452, skill = 285, sourceType = "VENDOR",
		sourceName = "Calandrath (Quest Chain)", zone = "Silithus", x = 51.8, y = 39.1, faction = "NEUTRAL",
		note = "Cenarion Hold · Desert Recipe",
	},

	-- =========================================================================
	-- FIRST AID
	-- =========================================================================
	{
		prof = "First Aid", name = "Expert First Aid - Under Wraps", nameDE = "Erste Hilfe für Experten",
		itemID = 16084, recipeItemID = 16084, skill = 125, sourceType = "VENDOR",
		sourceName = "Deneb Walker", zone = "Arathi Highlands", x = 27.0, y = 58.8, faction = "ALLIANCE",
		note = "Stromgarde Keep · 1g",
	},
	{
		prof = "First Aid", name = "Expert First Aid - Under Wraps", nameDE = "Erste Hilfe für Experten",
		itemID = 16084, recipeItemID = 16084, skill = 125, sourceType = "VENDOR",
		sourceName = "Balai Lok'Wein", zone = "Dustwallow Marsh", x = 36.5, y = 30.4, faction = "HORDE",
		note = "Brackenwall Village · 1g",
	},
	{
		prof = "First Aid", name = "Heavy Silk Bandage", nameDE = "Schwerer Seidenverband",
		itemID = 6451, recipeItemID = 16112, skill = 180, sourceType = "VENDOR",
		sourceName = "Deneb Walker", zone = "Arathi Highlands", x = 27.0, y = 58.8, faction = "ALLIANCE",
		note = "Stromgarde Keep · 22s",
	},
	{
		prof = "First Aid", name = "Heavy Silk Bandage", nameDE = "Schwerer Seidenverband",
		itemID = 6451, recipeItemID = 16112, skill = 180, sourceType = "VENDOR",
		sourceName = "Balai Lok'Wein", zone = "Dustwallow Marsh", x = 36.5, y = 30.4, faction = "HORDE",
		note = "Brackenwall Village · 22s",
	},
	{
		prof = "First Aid", name = "Mageweave Bandage", nameDE = "Magiestoffverband",
		itemID = 8544, recipeItemID = 16113, skill = 210, sourceType = "VENDOR",
		sourceName = "Deneb Walker", zone = "Arathi Highlands", x = 27.0, y = 58.8, faction = "ALLIANCE",
		note = "Stromgarde Keep · 50s",
	},
	{
		prof = "First Aid", name = "Mageweave Bandage", nameDE = "Magiestoffverband",
		itemID = 8544, recipeItemID = 16113, skill = 210, sourceType = "VENDOR",
		sourceName = "Balai Lok'Wein", zone = "Dustwallow Marsh", x = 36.5, y = 30.4, faction = "HORDE",
		note = "Brackenwall Village · 50s",
	},
	{
		prof = "First Aid", name = "Powerful Anti-Venom", nameDE = "Mächtiges Gegengift",
		itemID = 19440, recipeItemID = 19442, skill = 300, sourceType = "VENDOR",
		sourceName = "Quartermaster Miranda Breechlock", zone = "Eastern Plaguelands", x = 81.4, y = 59.8, faction = "NEUTRAL",
		note = "Argent Dawn · Honored",
	},
}

function PluribusHiveRecipeCatalog:GetPlayerFaction()
	if UnitFactionGroup then
		local f = UnitFactionGroup("player")
		if f == "Alliance" then return "ALLIANCE" end
		if f == "Horde" then return "HORDE" end
	end
	return "NEUTRAL"
end

function PluribusHiveRecipeCatalog:GetDisplayName(entry)
	if not entry then return "" end
	local lang = (_G.PluribusL and _G.PluribusL.GetLanguage and _G.PluribusL:GetLanguage()) or "enUS"
	if lang == "deDE" and entry.nameDE and entry.nameDE ~= "" then
		return entry.nameDE
	end
	return entry.name or ""
end

function PluribusHiveRecipeCatalog:IsEntryLearned(entry, learnedNameSet, learnedItemIDSet)
	if not entry then return false end
	if learnedItemIDSet then
		if entry.itemID and entry.itemID > 0 and learnedItemIDSet[entry.itemID] then
			return true
		end
	end
	if learnedNameSet then
		local kEN = self:NormalizeRecipeKey(entry.name)
		if kEN ~= "" and learnedNameSet[kEN] then return true end
		if entry.nameDE then
			local kDE = self:NormalizeRecipeKey(entry.nameDE)
			if kDE ~= "" and learnedNameSet[kDE] then return true end
		end
	end
	return false
end

-- Returns unlearned catalog recipes filtered by profession, faction, sourceType ("ALL"|"VENDOR"|"DROP"), and search query
function PluribusHiveRecipeCatalog:GetUnlearnedRecipes(profName, learnedNameSet, learnedItemIDSet, opts)
	opts = opts or {}
	local faction = opts.faction or self:GetPlayerFaction()
	local sourceFilter = opts.sourceFilter or "ALL"
	local q = tostring(opts.searchQuery or ""):lower():match("^%s*(.-)%s*$") or ""
	local wantProf = profName and profName ~= "" and profName ~= "ALL" and profName or nil
	local onlyProfs = opts.onlyProfs -- optional table { ["Alchemy"] = true, ... }

	local out = {}
	local seen = {}
	for _, entry in ipairs(self.ENTRIES) do
		local profOK = (not wantProf or entry.prof == wantProf)
			and (not onlyProfs or onlyProfs[entry.prof] == true)
		local factionOK = (entry.faction == "NEUTRAL" or faction == "NEUTRAL" or entry.faction == faction)
		local srcOK = (sourceFilter == "ALL" or entry.sourceType == sourceFilter)

		if profOK and factionOK and srcOK and not self:IsEntryLearned(entry, learnedNameSet, learnedItemIDSet) then
			local dedupeKey = entry.prof .. ":" .. self:NormalizeRecipeKey(entry.name)
			if not seen[dedupeKey] then
				local disp = self:GetDisplayName(entry)
				local matchesQ = (q == "")
					or disp:lower():find(q, 1, true)
					or (entry.name or ""):lower():find(q, 1, true)
					or (entry.nameDE or ""):lower():find(q, 1, true)
					or (entry.sourceName or ""):lower():find(q, 1, true)
					or (entry.zone or ""):lower():find(q, 1, true)
					or (entry.prof or ""):lower():find(q, 1, true)
					or (entry.sourceType or ""):lower():find(q, 1, true)
				if matchesQ then
					seen[dedupeKey] = true
					table.insert(out, entry)
				end
			end
		end
	end

	table.sort(out, function(a, b)
		if a.prof ~= b.prof then return a.prof < b.prof end
		if (a.skill or 0) ~= (b.skill or 0) then return (a.skill or 0) < (b.skill or 0) end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

return PluribusHiveRecipeCatalog
