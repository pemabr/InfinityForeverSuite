-- Pluribus GearAdvisor & Cap Guardian Engine (Warcraft Forever 1.60.1)
-- Genuine Classic 1.60.1 theorycrafting & gear evaluation suite:
--   1. Dual EN + DE Hidden Tooltip + GetItemStats Parser (accurate Spell/Heal Power, School Power, Hit/Crit %, MP5, Defense, Weapon DPS & Speed)
--   2. Authentic Classic 1.60.1 Profiles for ALL 9 Classes & Major Specs + User-Editable Custom Stat Weights
--   3. Accurate Slot Logic: 2H vs MH+OH combined evaluation, weaker Ring/Trinket/1H comparison, slow-MH weapon bonus
--   4. Live Cap Guardian: Hit / Spell Hit / Defense caps with below-cap drop warnings
--   5. Equippable Bag Upgrade Scanner with 1-Click Equip + Green Bag Arrows + Look-Ahead
--   6. Stat Laboratory, Dungeon/Raid Upgrade Roadmap, Talent Builds, and Floating /xpbar

PluribusGearAdvisor = {
	initialized = false,
	subTab = "overview", -- overview | lab | roadmap | talents | xpbar
	labSlot = "INVTYPE_CHEST",
	labCandidateLink = nil,
	xpBarFrame = nil,
	scanTooltip = nil,
	statCache = {},
	session = {
		startedAt = 0,
		xpGained = 0,
		copperLooted = 0,
		ahValueLooted = 0,
		itemsLooted = 0,
	},
}
_G.PluribusGearAdvisor = PluribusGearAdvisor
_G.PluribusHiveGearJudge = PluribusGearAdvisor -- Backward-compatible global alias for internal hooks

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local EQUIP_SLOTS = {
	INVTYPE_HEAD = { 1 },
	INVTYPE_NECK = { 2 },
	INVTYPE_SHOULDER = { 3 },
	INVTYPE_CLOAK = { 15 },
	INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 },
	INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 },
	INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 },
	INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_HOLDABLE = { 17 },
	INVTYPE_SHIELD = { 17 },
	INVTYPE_RANGED = { 18 },
	INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 },
}

local SLOT_LABELS = {
	INVTYPE_HEAD = "Head / Kopf", INVTYPE_NECK = "Neck / Hals", INVTYPE_SHOULDER = "Shoulder / Schulter",
	INVTYPE_CLOAK = "Back / Rücken", INVTYPE_CHEST = "Chest / Brust", INVTYPE_WRIST = "Wrist / Handgelenk",
	INVTYPE_HAND = "Hands / Hände", INVTYPE_WAIST = "Waist / Taille", INVTYPE_LEGS = "Legs / Beine",
	INVTYPE_FEET = "Feet / Füße", INVTYPE_FINGER = "Ring", INVTYPE_TRINKET = "Trinket / Schmuck",
	INVTYPE_WEAPON = "1H Weapon", INVTYPE_2HWEAPON = "2H Weapon",
	INVTYPE_SHIELD = "Shield / Offhand", INVTYPE_RANGED = "Ranged / Wand",
}

-- Authentic Classic 1.60.1 Class & Spec Profiles (all 9 classes, complete major specs!)
local SPEC_PROFILES = {
	WARRIOR = {
		Fury = {
			label = "Warrior — Fury Dual-Wield",
			caps = { hit = 6, crit = 35, defense = 0 },
			preferSlowMH = true,
			weights = { STR = 2.1, AGI = 1.6, STA = 0.5, AP = 1.0, CRIT = 28.0, HIT = 32.0, DPS = 10.5, ARMOR = 0.02 },
			talents = "17/34/0 Fury Raid (Cruelty 5, Flurry 5, Bloodthirst 1, Impale 2)",
		},
		Arms = {
			label = "Warrior — Arms 2H / Leveling",
			caps = { hit = 6, crit = 30, defense = 0 },
			preferSlowMH = true,
			weights = { STR = 2.2, AGI = 1.4, STA = 0.8, AP = 1.0, CRIT = 25.0, HIT = 26.0, DPS = 12.0, ARMOR = 0.04 },
			talents = "31/20/0 Arms (Mortal Strike 1, Sweeping Strikes 1, Cruelty 5)",
		},
		Protection = {
			label = "Warrior — Protection Tank",
			caps = { hit = 6, defense = 440 },
			weights = { STA = 2.6, DEF = 3.2, DODGE = 20.0, PARRY = 20.0, BLOCK = 14.0, STR = 1.1, AGI = 1.4, HIT = 22.0, ARMOR = 0.16, DPS = 4.5 },
			talents = "11/5/35 Prot (Defiance 5, Shield Slam 1, Tactical Mastery 5)",
		},
	},
	PALADIN = {
		Holy = {
			label = "Paladin — Holy Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.8, SP = 1.2, INT = 2.0, MP5 = 4.6, SPELLCRIT = 22.0, STA = 0.7, SPI = 0.4, ARMOR = 0.04 },
			talents = "31/20/0 Holy (Divine Favor 1, Illumination 5, Blessing of Kings 1)",
		},
		Protection = {
			label = "Paladin — Protection Tank",
			caps = { defense = 440 },
			weights = { STA = 2.5, DEF = 3.0, SP = 1.4, INT = 1.1, BLOCK = 16.0, DODGE = 18.0, PARRY = 18.0, ARMOR = 0.16, STR = 0.8 },
			talents = "11/31/9 Prot (Consecration 1, Holy Shield 1, Blessing of Sanctuary 1)",
		},
		Retribution = {
			label = "Paladin — Retribution / Leveling",
			caps = { hit = 6 },
			preferSlowMH = true,
			weights = { STR = 2.1, AGI = 1.3, STA = 0.9, INT = 0.7, AP = 0.95, CRIT = 22.0, HIT = 24.0, DPS = 11.5, SP = 0.6 },
			talents = "11/7/33 Retribution (Seal of Command 1, Vengeance 5, Consecration 1)",
		},
	},
	HUNTER = {
		Marksmanship = {
			label = "Hunter — Marksmanship Raid",
			caps = { hit = 9 },
			weights = { AGI = 2.5, RAP = 1.05, AP = 0.9, CRIT = 28.0, HIT = 32.0, INT = 0.6, STA = 0.6, DPS = 11.5 },
			talents = "20/31/0 Trueshot Aura (Lethal Shots 5, Mortal Shots 5, Trueshot Aura 1)",
		},
		BeastMastery = {
			label = "Hunter — Beast Mastery Leveling",
			caps = { hit = 6 },
			weights = { AGI = 2.3, RAP = 1.0, AP = 0.9, CRIT = 22.0, HIT = 24.0, INT = 0.8, STA = 0.9, SPI = 0.5, DPS = 11.0 },
			talents = "31/20/0 Beast Mastery (Bestial Wrath 1, Frenzy 5, Aimed Shot 1)",
		},
	},
	ROGUE = {
		Combat = {
			label = "Rogue — Combat Swords",
			caps = { hit = 9 },
			preferSlowMH = true,
			weights = { AGI = 2.2, STR = 1.05, AP = 1.0, CRIT = 24.0, HIT = 29.0, STA = 0.5, DPS = 10.5 },
			talents = "19/32/0 Combat Swords (Precision 5, Blade Flurry 1, Adrenaline Rush 1)",
		},
		Daggers = {
			label = "Rogue — Combat / Seal Fate Daggers",
			caps = { hit = 9 },
			weights = { AGI = 2.3, STR = 1.0, AP = 1.0, CRIT = 27.0, HIT = 28.0, STA = 0.5, DPS = 10.0 },
			talents = "15/31/5 Combat Daggers (Opportunity 5, Imp. Backstab 3, Adrenaline Rush 1)",
		},
	},
	PRIEST = {
		Holy = {
			label = "Priest — Holy / Disc Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.9, SP = 1.2, INT = 1.8, SPI = 1.6, MP5 = 4.8, STA = 0.7, SPELLCRIT = 12.0 },
			talents = "21/30/0 PI/Holy (Meditation 3, Spiritual Guidance 5, Inner Focus 1)",
		},
		Shadow = {
			label = "Priest — Shadow DPS / Leveling",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, SHADOW = 2.0, SPELLHIT = 20.0, INT = 1.2, SPI = 1.1, STA = 0.8, SPELLCRIT = 13.0, MP5 = 2.5 },
			talents = "14/0/37 Shadow (Spirit Tap 5, Shadow Weaving 5, Shadowform 1)",
		},
	},
	SHAMAN = {
		Restoration = {
			label = "Shaman — Restoration Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.9, SP = 1.2, MP5 = 5.0, INT = 1.8, STA = 0.8, SPELLCRIT = 14.0, SPI = 0.5 },
			talents = "0/5/46 Resto (Mana Tide 1, Nature's Swiftness 1, Healing Way 3)",
		},
		Elemental = {
			label = "Shaman — Elemental Caster",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, NATURE = 2.0, FIRE = 1.5, SPELLCRIT = 22.0, SPELLHIT = 20.0, INT = 1.5, MP5 = 3.5, STA = 0.8 },
			talents = "30/0/21 Ele/Resto (Elemental Mastery 1, Nature's Swiftness 1)",
		},
		Enhancement = {
			label = "Shaman — Enhancement / Leveling",
			caps = { hit = 6 },
			preferSlowMH = true,
			weights = { STR = 2.0, AGI = 1.5, INT = 0.9, STA = 1.0, AP = 0.95, CRIT = 22.0, HIT = 24.0, DPS = 10.5, SP = 0.7 },
			talents = "0/31/20 Enh/Resto (Flurry 5, Stormstrike 1, Nature's Guidance 3)",
		},
	},
	MAGE = {
		Frost = {
			label = "Mage — Frost DPS / Leveling",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, FROST = 2.0, SPELLHIT = 22.0, SPELLCRIT = 16.0, INT = 1.4, STA = 0.7, SPI = 0.5, MP5 = 2.2 },
			talents = "17/0/34 Winter's Chill (Ice Shards 5, Ice Barrier 1, Arcane Subtlety 2)",
		},
		Fire = {
			label = "Mage — Fire Raid DPS",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, FIRE = 2.0, SPELLCRIT = 24.0, SPELLHIT = 23.0, INT = 1.3, STA = 0.6, MP5 = 2.0 },
			talents = "17/31/3 Fire (Ignite 5, Combustion 1, Arcane Concentration 5)",
		},
	},
	WARLOCK = {
		Affliction = {
			label = "Warlock — SM/Ruin & Leveling",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, SHADOW = 2.0, SPELLHIT = 21.0, SPELLCRIT = 16.0, STA = 1.2, INT = 1.1, SPI = 0.4, MP5 = 1.8 },
			talents = "30/0/21 SM/Ruin (Shadow Mastery 5, Nightfall 2, Ruin 1)",
		},
		Destruction = {
			label = "Warlock — DS/Ruin Raid",
			caps = { spellHit = 16 },
			weights = { SP = 2.1, SHADOW = 2.1, FIRE = 1.6, SPELLHIT = 24.0, SPELLCRIT = 21.0, STA = 0.9, INT = 1.0 },
			talents = "7/21/23 DS/Ruin (Demonic Sacrifice 1, Ruin 1, Imp. Shadow Bolt 5)",
		},
	},
	DRUID = {
		Restoration = {
			label = "Druid — Restoration Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.9, SP = 1.2, INT = 1.7, SPI = 1.5, MP5 = 4.8, STA = 0.8 },
			talents = "24/0/27 Moonglow (Nature's Swiftness 1, Moonglow 3, Gift of Nature 5)",
		},
		FeralCat = {
			label = "Druid — Feral Cat DPS",
			caps = { hit = 9 },
			weights = { STR = 2.2, AGI = 2.3, STA = 0.8, AP = 1.0, CRIT = 24.0, HIT = 28.0, DPS = 0.0 },
			talents = "14/32/5 Feral Cat (Furor 5, Heart of the Wild 5, Leader of the Pack 1)",
		},
		FeralBear = {
			label = "Druid — Feral Bear Tank",
			caps = { hit = 6, defense = 420 },
			weights = { STA = 2.8, AGI = 2.2, ARMOR = 0.28, DEF = 2.4, DODGE = 22.0, STR = 1.4, HIT = 20.0, AP = 0.8 },
			talents = "0/36/15 Bear Tank (Thick Hide 5, Feral Instinct 5, Furor 5)",
		},
		Balance = {
			label = "Druid — Balance Moonkin",
			caps = { spellHit = 16 },
			weights = { SP = 2.0, ARCANE = 1.9, NATURE = 1.9, SPELLCRIT = 20.0, SPELLHIT = 20.0, INT = 1.5, MP5 = 3.8, STA = 0.7 },
			talents = "31/0/20 Moonkin (Moonkin Form 1, Vengeance 5, Nature's Grace 1)",
		},
	},
}

local ROADMAP_SOURCES = {
	{ name = "Ragefire Chasm",       zone = "Orgrimmar",           x = 52.8, y = 49.0, minL = 13, maxL = 18, tier = "Dungeon", faction = "Horde",    highlights = { "Chasm Belt", "Cursed Felblade", "Subterranean Cape" }, ilvl = 17 },
	{ name = "Deadmines",            zone = "Westfall",            x = 42.6, y = 71.7, minL = 17, maxL = 24, tier = "Dungeon", faction = "Both",     highlights = { "Cruel Barb", "Defias Chest", "Smite's Hammer", "Emberstone Staff" }, ilvl = 22 },
	{ name = "Wailing Caverns",      zone = "The Barrens",         x = 46.0, y = 35.7, minL = 17, maxL = 24, tier = "Dungeon", faction = "Both",     highlights = { "Fang Set", "Crescent Staff", "Wingblade", "Living Root" }, ilvl = 22 },
	{ name = "Shadowfang Keep",      zone = "Silverpine Forest",   x = 44.8, y = 67.8, minL = 22, maxL = 30, tier = "Dungeon", faction = "Both",     highlights = { "Robes of Arugal", "Meteor Shard", "Shadowfang", "Assassin's Blade" }, ilvl = 27 },
	{ name = "Blackfathom Deeps",    zone = "Ashenvale",           x = 14.5, y = 13.9, minL = 24, maxL = 32, tier = "Dungeon", faction = "Both",     highlights = { "Strike of the Hydra", "Rod of the Sleepwalker", "Gravestone Scepter" }, ilvl = 29 },
	{ name = "The Stockade",         zone = "Stormwind City",      x = 40.6, y = 55.8, minL = 24, maxL = 31, tier = "Dungeon", faction = "Alliance", highlights = { "Quest Rewards", "Kam's Walking Stick", "Bruegal's Knuckles" }, ilvl = 28 },
	{ name = "Gnomeregan",           zone = "Dun Morogh",          x = 24.0, y = 39.8, minL = 29, maxL = 38, tier = "Dungeon", faction = "Both",     highlights = { "Triprunner Dungarees", "Hydrocane", "Electrocutioner Leg", "Thermaplugg's Left Arm" }, ilvl = 35 },
	{ name = "Razorfen Kraul",       zone = "The Barrens",         x = 42.2, y = 89.6, minL = 29, maxL = 38, tier = "Dungeon", faction = "Both",     highlights = { "Corpsemaker", "Quillward Harness", "Heart of Agamaggan", "Swinetusk Shank" }, ilvl = 35 },
	{ name = "Scarlet Monastery",    zone = "Tirisfal Glades",     x = 85.3, y = 32.2, minL = 32, maxL = 42, tier = "Dungeon", faction = "Both",     highlights = { "Herod's Shoulder", "Ravager", "Whitemane's Chapeau", "Hypnotic Blade", "Illusionary Rod" }, ilvl = 40 },
	{ name = "Razorfen Downs",       zone = "The Barrens",         x = 49.0, y = 94.0, minL = 36, maxL = 45, tier = "Dungeon", faction = "Both",     highlights = { "Vanquisher's Sword", "Coldrage Dagger", "Icemetal Barbute", "Robes of the Lich" }, ilvl = 43 },
	{ name = "Uldaman",              zone = "Badlands",            x = 42.5, y = 13.4, minL = 39, maxL = 47, tier = "Dungeon", faction = "Both",     highlights = { "Stoneslayer", "Grimlok's Charge", "Galgann's Firehammer", "Archaedic Stone" }, ilvl = 46 },
	{ name = "Zul'Farrak",           zone = "Tanaris",             x = 38.7, y = 20.0, minL = 42, maxL = 50, tier = "Dungeon", faction = "Both",     highlights = { "Jang'thraze", "Carrot on a Stick", "Big Bad Pauldrons", "Zum'rah's Vexing Cane" }, ilvl = 49 },
	{ name = "Maraudon",             zone = "Desolace",            x = 29.1, y = 62.5, minL = 45, maxL = 53, tier = "Dungeon", faction = "Both",     highlights = { "Blackstone Ring", "Thrash Blade", "Princess's Ring", "Satyr's Bow", "Gatorbite Axe" }, ilvl = 52 },
	{ name = "Sunken Temple",        zone = "Swamp of Sorrows",    x = 70.0, y = 53.2, minL = 49, maxL = 56, tier = "Dungeon", faction = "Both",     highlights = { "Dragon's Call", "Featherskin Cape", "Atal'ai Spaulders", "Class Quest Rewards" }, ilvl = 55 },
	{ name = "Blackrock Depths",     zone = "Burning Steppes",     x = 29.4, y = 38.3, minL = 52, maxL = 60, tier = "Dungeon", faction = "Both",     highlights = { "Hand of Justice", "Savage Gladiator Chain", "Ironfoe", "Briarwood Reed", "Ban'thok Sash" }, ilvl = 58 },
	{ name = "Dire Maul",            zone = "Feralas",             x = 59.1, y = 44.3, minL = 56, maxL = 60, tier = "Dungeon", faction = "Both",     highlights = { "Tribute Buffs & Loot", "Mindtap Talisman", "Tarnished Elven Ring", "Quel'Serrar" }, ilvl = 61 },
	{ name = "Stratholme",           zone = "Eastern Plaguelands", x = 31.3, y = 15.7, minL = 57, maxL = 60, tier = "Dungeon", faction = "Both",     highlights = { "Cape of the Black Baron", "Mask of the Unforgiven", "Truefaith Patterns", "Diana's Pearl" }, ilvl = 61 },
	{ name = "Scholomance",          zone = "Western Plaguelands", x = 69.4, y = 72.9, minL = 57, maxL = 60, tier = "Dungeon", faction = "Both",     highlights = { "Cadaverous Armor", "Shadowcraft / Valor", "Ancient Bone Bow", "Dark Runes" }, ilvl = 61 },
	{ name = "Upper Blackrock Spire", zone = "Burning Steppes",    x = 29.4, y = 38.3, minL = 58, maxL = 60, tier = "Dungeon", faction = "Both",     highlights = { "Dal'Rend's Set", "Truestrike Shoulders", "Blackhand's Breadth", "Briarwood Reed" }, ilvl = 63 },
	{ name = "Zul'Gurub (20er)",     zone = "Stranglethorn Vale",  x = 53.8, y = 17.6, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 54, highlights = { "Bloodvine / ZG Enchants", "Jin'do's Hexxer", "Cloak of Consumption", "Zandalar Gear" }, ilvl = 66 },
	{ name = "Ruins of AQ (AQ20)",   zone = "Silithus",            x = 28.6, y = 92.4, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 56, highlights = { "Cenarion Circle Sets", "Crossbow of Imminent Doom", "Bracers of Brutality", "Spellbooks" }, ilvl = 68 },
	{ name = "Molten Core",          zone = "Blackrock Mountain",  x = 29.4, y = 38.3, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 56, highlights = { "Tier 1 Sets", "Onslaught Girdle", "Choker of the Fire Lord", "Perdition's Blade" }, ilvl = 69 },
	{ name = "Onyxia's Lair",        zone = "Dustwallow Marsh",    x = 52.2, y = 76.1, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 56, highlights = { "Tier 2 Helms", "Onyxia Tooth Pendant", "Vis'kag the Bloodletter", "18-Slot Bag" }, ilvl = 71 },
	{ name = "Blackwing Lair",       zone = "Blackrock Mountain",  x = 29.4, y = 38.3, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 63, highlights = { "Tier 2 Sets", "Drake Fang Talisman", "Neltharion's Tear", "Ashkandi" }, ilvl = 76 },
	{ name = "Ahn'Qiraj (AQ40)",     zone = "Silithus",            x = 28.6, y = 92.4, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 69, highlights = { "Tier 2.5 Sets", "Dark Edge of Insanity", "Death's Sting", "Eye of C'Thun" }, ilvl = 82 },
	{ name = "Naxxramas",            zone = "Eastern Plaguelands", x = 39.8, y = 26.2, minL = 60, maxL = 60, tier = "Raid",    faction = "Both",     minIlvlRec = 74, highlights = { "Tier 3 Sets", "Hungering Cold", "Atiesh", "Slayer's Crest" }, ilvl = 89 },
}

-- Strict level-aware & progression-aware Upgrade Roadmap planner:
-- Never recommends Raids (Naxxramas, AQ40, BWL, MC, ZG...) to leveling characters (< Lv 58),
-- and at Lv 60 orders Pre-BiS dungeons & entry raids before T2/T2.5/T3 based on equipped avg iLvl!
function PluribusGearAdvisor:BuildUpgradeRoadmap(playerLevel, avgIlvl, playerFaction)
	local myLvl = math.max(1, math.min(60, tonumber(playerLevel) or (UnitLevel and UnitLevel("player")) or 60))
	local myIlvl = tonumber(avgIlvl) or 0
	if myIlvl <= 0 then myIlvl = math.max(10, myLvl) end
	local fac = playerFaction
	if not fac and UnitFactionGroup then
		local ok, f = pcall(UnitFactionGroup, "player")
		if ok then fac = f end
	end

	local current, upcoming = {}, {}
	for _, src in ipairs(ROADMAP_SOURCES) do
		local factionOk = (not src.faction) or src.faction == "Both" or (not fac) or (src.faction == fac)
		if factionOk then
			local isRaid = (src.tier == "Raid")
			-- Hard gate: Raids are strictly Endgame (Lv 58-60) — never shown to Lv 44!
			if (not isRaid) or myLvl >= 58 then
				local ilvlDelta = src.ilvl - myIlvl
				if myLvl >= 58 then
					-- Level 58-60 endgame progression: exclude low-level leveling dungeons (< 52)
					if src.maxL >= 58 then
						local minRec = src.minIlvlRec or 0
						if isRaid and myLvl < 60 then
							-- Lv 58-59: show entry raids only as upcoming, never as immediate #1
							if minRec <= 58 then
								table.insert(upcoming, { src = src, score = 20, ilvlDelta = ilvlDelta, fitTag = "Ab Lv 60" })
							end
						elseif isRaid and myIlvl < (minRec - 8) then
							-- Fresh Lv 60 (e.g. iLvl 52): put BWL/AQ40/Naxxramas in upcoming until geared
							if myIlvl >= (minRec - 18) then
								table.insert(upcoming, { src = src, score = math.max(5, 40 - (minRec - myIlvl)), ilvlDelta = ilvlDelta, fitTag = "Erst ab Ø iLvl " .. minRec })
							end
						else
							-- Ideal progression step: peak score when ilvlDelta is +4..+14
							local stepScore
							if ilvlDelta <= -4 then
								stepScore = math.max(1, 12 + ilvlDelta)
							elseif ilvlDelta <= 14 then
								stepScore = 60 + ilvlDelta * 2.5
							else
								stepScore = math.max(15, 95 - (ilvlDelta - 14) * 3.2)
							end
							if isRaid and myIlvl < minRec then
								stepScore = stepScore - ((minRec - myIlvl) * 4)
							end
							local fitTag = (ilvlDelta >= 3 and ilvlDelta <= 14) and "Ideal" or (ilvlDelta > 14 and "Schwer" or "Farm / BiS")
							table.insert(current, { src = src, score = math.floor(stepScore * 10 + 0.5) / 10, ilvlDelta = ilvlDelta, fitTag = fitTag })
						end
					end
				else
					-- Leveling character (Lv 1-57): ONLY level-appropriate dungeons!
					local inCurrentRange = (myLvl >= src.minL - 2) and (myLvl <= src.maxL + 4)
					local inUpcomingRange = (not inCurrentRange) and (src.minL > myLvl + 2) and (src.minL <= myLvl + 8)
					if inCurrentRange then
						local midL = (src.minL + src.maxL) * 0.5
						local distFromMid = math.abs(myLvl - midL)
						local lvlScore = math.max(10, 65 - distFromMid * 6.5)
						local gainBonus = math.max(-10, math.min(25, (ilvlDelta + 4) * 2.0))
						local totalScore = math.floor((lvlScore + gainBonus) * 10 + 0.5) / 10
						local fitTag
						if myLvl >= src.minL and myLvl <= src.maxL then
							fitTag = "Ideal"
						elseif myLvl < src.minL then
							fitTag = "Knapp (+" .. (src.minL - myLvl) .. " Lv)"
						else
							fitTag = "Leicht"
						end
						table.insert(current, { src = src, score = totalScore, ilvlDelta = ilvlDelta, fitTag = fitTag })
					elseif inUpcomingRange then
						local lvlsAway = src.minL - myLvl
						table.insert(upcoming, { src = src, score = math.max(1, 30 - lvlsAway * 3), ilvlDelta = ilvlDelta, fitTag = "In " .. lvlsAway .. " Lv" })
					end
				end
			end
		end
	end

	table.sort(current, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.src.minL < b.src.minL
	end)
	table.sort(upcoming, function(a, b)
		if a.src.minL ~= b.src.minL then return a.src.minL < b.src.minL end
		return a.src.ilvl < b.src.ilvl
	end)
	return current, upcoming
end

-- ============================================================================
-- PERSISTENT STORAGE & CUSTOM STAT WEIGHTS
-- ============================================================================
function PluribusGearAdvisor:GetGearDB()
	local db = PluribusHive:GetDB()
	db.gearAdvisor = db.gearAdvisor or db.gearJudge or {
		specOverride = {},
		customWeights = {}, -- [class:spec] = { [STAT] = weight }
		altGear = {},
		showXpBar = false,
	}
	db.gearAdvisor.customWeights = db.gearAdvisor.customWeights or {}
	db.gearAdvisor.specOverride = db.gearAdvisor.specOverride or {}
	db.gearAdvisor.altGear = db.gearAdvisor.altGear or {}
	return db.gearAdvisor
end

function PluribusGearAdvisor:GetActiveProfile(classOverride, specOverride)
	local cls = classOverride or (PluribusHive and PluribusHive:GetPlayerClass()) or "WARRIOR"
	local classTable = SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR
	local gdb = self:GetGearDB()
	local me = PluribusHive and PluribusHive:GetPlayerShortName() or "Player"
	local chosenSpec = specOverride or (not classOverride and gdb.specOverride[me])

	local baseKey, baseProf
	if chosenSpec and classTable[chosenSpec] then
		baseKey, baseProf = chosenSpec, classTable[chosenSpec]
	elseif not classOverride and GetTalentTabInfo then
		local bestTab, bestPts = nil, -1
		for tab = 1, 3 do
			local ok, name, _, pts = pcall(GetTalentTabInfo, tab)
			if ok and name and (tonumber(pts) or 0) > bestPts then
				bestPts = tonumber(pts) or 0
				bestTab = name
			end
		end
		if bestTab and bestPts > 0 then
			local low = bestTab:lower()
			for k, v in pairs(classTable) do
				if low:find(k:lower(), 1, true) then
					baseKey, baseProf = k, v
					break
				end
			end
		end
	end
	if not baseProf then
		for k, v in pairs(classTable) do
			baseKey, baseProf = k, v
			break
		end
	end

	-- Apply user-edited custom weights cleanly without mutating defaults
	local wKey = cls .. ":" .. tostring(baseKey)
	local custom = gdb.customWeights[wKey]
	if custom then
		local merged = {}
		for k, v in pairs(baseProf.weights or {}) do merged[k] = v end
		for k, v in pairs(custom) do merged[k] = v end
		return baseKey, {
			label = baseProf.label,
			caps = baseProf.caps,
			preferSlowMH = baseProf.preferSlowMH,
			talents = baseProf.talents,
			weights = merged,
		}
	end
	return baseKey, baseProf
end

function PluribusGearAdvisor:AdjustCustomWeight(statKey, delta)
	local cls = PluribusHive:GetPlayerClass()
	local specKey, profile = self:GetActiveProfile()
	local gdb = self:GetGearDB()
	local wKey = cls .. ":" .. tostring(specKey)
	gdb.customWeights[wKey] = gdb.customWeights[wKey] or {}
	local cur = (gdb.customWeights[wKey][statKey] ~= nil) and gdb.customWeights[wKey][statKey] or (profile.weights[statKey] or 0)
	local nextVal = math.max(0, math.floor((cur + delta) * 10 + 0.5) / 10)
	gdb.customWeights[wKey][statKey] = nextVal
	self.statCache = {}
end

function PluribusGearAdvisor:ResetCustomWeights()
	local cls = PluribusHive:GetPlayerClass()
	local specKey = self:GetActiveProfile()
	local gdb = self:GetGearDB()
	gdb.customWeights[cls .. ":" .. tostring(specKey)] = nil
	self.statCache = {}
end

-- ============================================================================
-- DUAL EN + DE HIDDEN TOOLTIP + GetItemStats REAL STAT PARSER
-- ============================================================================
function PluribusGearAdvisor:GetScanTooltip()
	if not self.scanTooltip then
		local tt = CreateFrame("GameTooltip", "PluribusGearAdvisorScanTT", UIParent, "GameTooltipTemplate")
		tt:SetOwner(UIParent, "ANCHOR_NONE")
		tt._plbIsScanner = true
		self.scanTooltip = tt
	end
	return self.scanTooltip
end

function PluribusGearAdvisor:ParseTooltipLine(line, stats)
	if type(line) ~= "string" or line == "" then return end
	local clean = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local low = clean:lower()

	-- Primary stats (EN + DE)
	local v = tonumber(clean:match("%+(%d+)%s+Strength")) or tonumber(clean:match("%+(%d+)%s+Stärke"))
	if v then stats.STR = stats.STR + v return end
	v = tonumber(clean:match("%+(%d+)%s+Agility")) or tonumber(clean:match("%+(%d+)%s+Beweglichkeit"))
	if v then stats.AGI = stats.AGI + v return end
	v = tonumber(clean:match("%+(%d+)%s+Stamina")) or tonumber(clean:match("%+(%d+)%s+Ausdauer"))
	if v then stats.STA = stats.STA + v return end
	v = tonumber(clean:match("%+(%d+)%s+Intellect")) or tonumber(clean:match("%+(%d+)%s+Intelligenz"))
	if v then stats.INT = stats.INT + v return end
	v = tonumber(clean:match("%+(%d+)%s+Spirit")) or tonumber(clean:match("%+(%d+)%s+Willenskraft"))
	if v then stats.SPI = stats.SPI + v return end

	-- Armor (EN + DE)
	v = tonumber(clean:match("^(%d+)%s+Armor")) or tonumber(clean:match("^(%d+)%s+Rüstung"))
	if v then stats.ARMOR = math.max(stats.ARMOR, v) return end

	-- Weapon DPS & Speed (EN + DE, handles decimal comma in German!)
	local dpsStr = clean:match("%(([%d%.%,]+)%s+damage per second%)") or clean:match("%(([%d%.%,]+)%s+Schaden pro Sekunde%)")
	if dpsStr then
		stats.DPS = math.max(stats.DPS, tonumber((dpsStr:gsub(",", "."))) or 0)
		return
	end
	local spdStr = clean:match("Speed%s+([%d%.%,]+)") or clean:match("Tempo%s+([%d%.%,]+)")
	if spdStr then
		stats.SPEED = tonumber((spdStr:gsub(",", "."))) or stats.SPEED
		return
	end

	-- Equip / Anlegen secondary stats (EN + DE)
	local num = tonumber(clean:match("(%d+)"))
	if not num then return end

	if low:find("healing done by spells", 1, true) or low:find("heilung durch zauber", 1, true) or low:find("healing spells", 1, true) then
		stats.HEAL = stats.HEAL + num
	elseif low:find("damage and healing done by magical", 1, true) or low:find("schaden und heilung durch magische", 1, true) or low:find("spell power", 1, true) or low:find("zaubermacht", 1, true) then
		stats.SP = stats.SP + num
		stats.HEAL = stats.HEAL + num
	elseif low:find("shadow spells", 1, true) or low:find("schattenzauber", 1, true) then
		stats.SHADOW = stats.SHADOW + num
	elseif low:find("frost spells", 1, true) or low:find("frostzauber", 1, true) then
		stats.FROST = stats.FROST + num
	elseif low:find("fire spells", 1, true) or low:find("feuerzauber", 1, true) then
		stats.FIRE = stats.FIRE + num
	elseif low:find("nature spells", 1, true) or low:find("naturzauber", 1, true) then
		stats.NATURE = stats.NATURE + num
	elseif low:find("arcane spells", 1, true) or low:find("arkanzauber", 1, true) then
		stats.ARCANE = stats.ARCANE + num
	elseif low:find("ranged attack power", 1, true) or low:find("distanzangriffskraft", 1, true) then
		stats.RAP = stats.RAP + num
	elseif low:find("attack power", 1, true) or low:find("angriffskraft", 1, true) then
		stats.AP = stats.AP + num
	elseif (low:find("chance to hit with spells", 1, true) or low:find("trefferchance mit zaubern", 1, true)) then
		stats.SPELLHIT = stats.SPELLHIT + num
	elseif (low:find("chance to hit", 1, true) or low:find("trefferchance", 1, true)) then
		stats.HIT = stats.HIT + num
	elseif (low:find("critical strike with spells", 1, true) or low:find("kritischen zaubertreffer", 1, true)) then
		stats.SPELLCRIT = stats.SPELLCRIT + num
	elseif (low:find("critical strike", 1, true) or low:find("kritischen treffer", 1, true)) then
		stats.CRIT = stats.CRIT + num
	elseif low:find("mana per 5", 1, true) or low:find("mana alle 5", 1, true) then
		stats.MP5 = stats.MP5 + num
	elseif low:find("defense", 1, true) or low:find("verteidigung", 1, true) then
		stats.DEF = stats.DEF + num
	elseif low:find("dodge", 1, true) or low:find("auszuweichen", 1, true) or low:find("ausweichwertung", 1, true) then
		stats.DODGE = stats.DODGE + num
	elseif low:find("parry", 1, true) or low:find("parieren", 1, true) then
		stats.PARRY = stats.PARRY + num
	elseif low:find("block", 1, true) or low:find("blocken", 1, true) then
		stats.BLOCK = stats.BLOCK + num
	end
end

function PluribusGearAdvisor:ExtractItemStats(itemLinkOrID)
	local stats = {
		STR = 0, AGI = 0, STA = 0, INT = 0, SPI = 0,
		AP = 0, RAP = 0, CRIT = 0, HIT = 0,
		SP = 0, HEAL = 0, SHADOW = 0, FROST = 0, FIRE = 0, NATURE = 0, ARCANE = 0,
		SPELLCRIT = 0, SPELLHIT = 0, MP5 = 0,
		DEF = 0, DODGE = 0, PARRY = 0, BLOCK = 0,
		ARMOR = 0, DPS = 0, SPEED = 0,
	}
	if not itemLinkOrID then return stats, nil, 0, 0, 1, nil, nil end

	local name, link, quality, ilvl, reqLevel, _, _, _, equipLoc = PluribusUtils:GetItemInfo(itemLinkOrID)
	local target = link or itemLinkOrID
	local cacheKey = tostring(target)

	if self.statCache[cacheKey] then
		local c = self.statCache[cacheKey]
		return c.stats, c.equipLoc, c.ilvl, c.reqLevel, c.quality, c.name, c.link
	end

	-- Pass 1: Scan real rendered item tooltip text (accurate in Classic 1.60.1 EN + DE!)
	-- Guarded with _scanningTooltip so TooltipDataProcessor never re-enters ExtractItemStats
	local ttParsedAny = false
	if not self._scanningTooltip and type(target) == "string" and target:find("item:", 1, true) then
		local tt = self:GetScanTooltip()
		if tt and tt.SetHyperlink then
			self._scanningTooltip = true
			tt:ClearLines()
			local ok = pcall(tt.SetHyperlink, tt, target)
			if ok then
				local nLines = tt:NumLines() or 0
				for i = 2, nLines do
					local lfs = _G["PluribusGearAdvisorScanTTTextLeft" .. i]
					local rfs = _G["PluribusGearAdvisorScanTTTextRight" .. i]
					local lTxt = lfs and lfs:GetText()
					local rTxt = rfs and rfs:GetText()
					if lTxt then self:ParseTooltipLine(lTxt, stats) ttParsedAny = true end
					if rTxt then self:ParseTooltipLine(rTxt, stats) end
				end
			end
			self._scanningTooltip = false
		end
	end

	-- Pass 2: Merge GetItemStats (fills anything tooltip didn't expose)
	if GetItemStats and target then
		local ok, raw = pcall(GetItemStats, target)
		if ok and type(raw) == "table" then
			local function takeMax(k, val)
				if val and val > (stats[k] or 0) then stats[k] = val end
			end
			takeMax("STR", raw["ITEM_MOD_STRENGTH_SHORT"])
			takeMax("AGI", raw["ITEM_MOD_AGILITY_SHORT"])
			takeMax("STA", raw["ITEM_MOD_STAMINA_SHORT"])
			takeMax("INT", raw["ITEM_MOD_INTELLECT_SHORT"])
			takeMax("SPI", raw["ITEM_MOD_SPIRIT_SHORT"])
			takeMax("AP", raw["ITEM_MOD_ATTACK_POWER_SHORT"])
			takeMax("RAP", raw["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"])
			takeMax("CRIT", (raw["ITEM_MOD_CRIT_RATING_SHORT"] or 0) + (raw["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] or 0))
			takeMax("HIT", (raw["ITEM_MOD_HIT_RATING_SHORT"] or 0) + (raw["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0))
			takeMax("SP", (raw["ITEM_MOD_SPELL_POWER_SHORT"] or 0) + (raw["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] or 0))
			takeMax("HEAL", raw["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or stats.SP)
			takeMax("SPELLCRIT", raw["ITEM_MOD_CRIT_SPELL_RATING_SHORT"])
			takeMax("SPELLHIT", raw["ITEM_MOD_HIT_SPELL_RATING_SHORT"])
			takeMax("MP5", raw["ITEM_MOD_POWER_REGEN0_SHORT"])
			takeMax("DEF", raw["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"])
			takeMax("DODGE", raw["ITEM_MOD_DODGE_RATING_SHORT"])
			takeMax("PARRY", raw["ITEM_MOD_PARRY_RATING_SHORT"])
			takeMax("BLOCK", raw["ITEM_MOD_BLOCK_RATING_SHORT"])
			takeMax("ARMOR", raw["RESISTANCE0_NAME"])
			takeMax("DPS", raw["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"])
		end
	end

	local resIlvl = tonumber(ilvl) or 0
	local resReq = tonumber(reqLevel) or 0
	local resQual = tonumber(quality) or 1
	if ttParsedAny or resIlvl > 0 then
		self.statCache[cacheKey] = {
			stats = stats, equipLoc = equipLoc, ilvl = resIlvl,
			reqLevel = resReq, quality = resQual, name = name, link = link,
		}
	end
	return stats, equipLoc, resIlvl, resReq, resQual, name, link
end

function PluribusGearAdvisor:GetCurrentCapTotals()
	local totals = { hit = 0, spellHit = 0, defense = (UnitLevel and UnitLevel("player") or 60) * 5, crit = 0, avgIlvl = 0, equippedCount = 0 }
	if not GetInventoryItemLink then return totals end
	local ilvlSum = 0
	for slot = 1, 18 do
		if slot ~= 4 then
			local link = GetInventoryItemLink("player", slot)
			if link then
				local st, _, ilvl = self:ExtractItemStats(link)
				totals.hit = totals.hit + (st.HIT or 0)
				totals.spellHit = totals.spellHit + (st.SPELLHIT or 0)
				totals.defense = totals.defense + (st.DEF or 0)
				totals.crit = totals.crit + (st.CRIT or 0) + (st.SPELLCRIT or 0)
				if ilvl and ilvl > 0 then
					ilvlSum = ilvlSum + ilvl
					totals.equippedCount = totals.equippedCount + 1
				end
			end
		end
	end
	if totals.equippedCount > 0 then
		totals.avgIlvl = math.floor(ilvlSum / totals.equippedCount + 0.5)
	end
	return totals
end

function PluribusGearAdvisor:ScoreItem(itemLinkOrID, profile, capTotals)
	local stats, equipLoc, ilvl, reqLevel, quality, name, link = self:ExtractItemStats(itemLinkOrID)
	if not equipLoc or not EQUIP_SLOTS[equipLoc] then
		return nil
	end
	local _, activeProf = self:GetActiveProfile()
	profile = profile or activeProf
	capTotals = capTotals or self:GetCurrentCapTotals()

	local w = profile.weights or {}
	local caps = profile.caps or {}
	local score = 0

	for k, val in pairs(stats) do
		if val ~= 0 and w[k] then
			local mult = 1.0
			if k == "HIT" and caps.hit and caps.hit > 0 and capTotals.hit >= caps.hit then
				mult = 0.25
			elseif k == "SPELLHIT" and caps.spellHit and caps.spellHit > 0 and capTotals.spellHit >= caps.spellHit then
				mult = 0.25
			elseif k == "DEF" and caps.defense and caps.defense > 0 and capTotals.defense >= caps.defense then
				mult = 0.35
			end
			score = score + (val * w[k] * mult)
		end
	end

	-- Slow Main-Hand weapon bonus for Melee instant-strike specs (Mortal Strike, Sinister Strike, Stormstrike, Seal of Command)
	if profile.preferSlowMH and (stats.SPEED or 0) >= 2.4 and (stats.DPS or 0) > 0 and
		(equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") then
		score = score + ((stats.SPEED - 2.2) * (stats.DPS * 0.45))
	end

	if score <= 0 and ilvl > 0 then
		score = ilvl * (1 + (math.max(1, quality) - 1) * 0.22)
	end

	return {
		score = math.floor(score * 10 + 0.5) / 10,
		stats = stats,
		equipLoc = equipLoc,
		ilvl = ilvl,
		reqLevel = reqLevel,
		quality = quality,
		name = name,
		link = link,
	}
end

-- Accurate Slot Comparison: 2H compares against MH + OH combined; Rings/Trinkets/1H compare against the weaker equipped slot!
function PluribusGearAdvisor:EvaluateItem(itemLinkOrID)
	local specKey, profile = self:GetActiveProfile()
	local capTotals = self:GetCurrentCapTotals()
	local cand = self:ScoreItem(itemLinkOrID, profile, capTotals)
	if not cand then return nil end

	local slotIds = EQUIP_SLOTS[cand.equipLoc]
	if not slotIds then return nil end

	local bestEqLink, bestEqEval = nil, nil
	local compareScore = 0
	local isEquipped = false

	if cand.equipLoc == "INVTYPE_2HWEAPON" then
		-- 2H replaces BOTH Mainhand (16) AND Offhand (17)
		local mhLink = GetInventoryItemLink and GetInventoryItemLink("player", 16) or nil
		local ohLink = GetInventoryItemLink and GetInventoryItemLink("player", 17) or nil
		local mhEval = mhLink and self:ScoreItem(mhLink, profile, capTotals) or nil
		local ohEval = ohLink and self:ScoreItem(ohLink, profile, capTotals) or nil
		compareScore = (mhEval and mhEval.score or 0) + (ohEval and ohEval.score or 0)
		bestEqLink = mhLink
		bestEqEval = mhEval
		if cand.link and mhLink and cand.link == mhLink then isEquipped = true end
	else
		local worstScore = nil
		for _, sId in ipairs(slotIds) do
			local eqLink = GetInventoryItemLink and GetInventoryItemLink("player", sId) or nil
			if cand.link and eqLink and cand.link == eqLink then
				isEquipped = true
			end
			if eqLink then
				local eqEval = self:ScoreItem(eqLink, profile, capTotals)
				local sc = eqEval and eqEval.score or 0
				if not worstScore or sc < worstScore then
					worstScore = sc
					bestEqLink = eqLink
					bestEqEval = eqEval
				end
			else
				worstScore = 0
				bestEqLink = nil
				bestEqEval = nil
				break
			end
		end
		compareScore = worstScore or 0
	end

	local delta = cand.score - compareScore
	local pct
	if compareScore <= 0 then
		pct = cand.score > 0 and 100 or 0
	else
		pct = math.floor(((delta / compareScore) * 100) * 10 + 0.5) / 10
	end

	local capWarning = nil
	local caps = profile.caps or {}
	if bestEqEval then
		local eqSt = bestEqEval.stats or {}
		local cSt = cand.stats or {}
		if caps.hit and caps.hit > 0 and capTotals.hit >= caps.hit and (capTotals.hit - (eqSt.HIT or 0) + (cSt.HIT or 0)) < caps.hit then
			capWarning = string.format("Hit < %d%% Cap!", caps.hit)
		elseif caps.spellHit and caps.spellHit > 0 and capTotals.spellHit >= caps.spellHit and (capTotals.spellHit - (eqSt.SPELLHIT or 0) + (cSt.SPELLHIT or 0)) < caps.spellHit then
			capWarning = string.format("Spell Hit < %d%% Cap!", caps.spellHit)
		elseif caps.defense and caps.defense > 0 and capTotals.defense >= caps.defense and (capTotals.defense - (eqSt.DEF or 0) + (cSt.DEF or 0)) < caps.defense then
			capWarning = string.format("Defense < %d Cap!", caps.defense)
		end
	end

	return {
		equippable = true,
		specName = specKey,
		candidate = cand,
		equipped = bestEqEval,
		equippedLink = bestEqLink,
		delta = delta,
		pct = pct,
		pctDelta = pct,
		isUpgrade = (not isEquipped) and (pct >= 0.5),
		isEquipped = isEquipped,
		capWarning = capWarning,
	}
end

function PluribusGearAdvisor:SnapshotMyGearForAlts()
	local gdb = self:GetGearDB()
	local me = PluribusHive:GetPlayerShortName()
	local specKey, profile = self:GetActiveProfile()
	local capTotals = self:GetCurrentCapTotals()
	local slots = {}

	if GetInventoryItemLink then
		for equipLoc, ids in pairs(EQUIP_SLOTS) do
			local minScore = nil
			for _, sid in ipairs(ids) do
				local link = GetInventoryItemLink("player", sid)
				local sc = 0
				if link then
					local ev = self:ScoreItem(link, profile, capTotals)
					sc = ev and ev.score or 0
				end
				if not minScore or sc < minScore then minScore = sc end
			end
			slots[equipLoc] = minScore or 0
		end
	end

	gdb.altGear[me] = {
		name = me,
		class = PluribusHive:GetPlayerClass(),
		level = UnitLevel and UnitLevel("player") or 60,
		spec = specKey,
		avgIlvl = capTotals.avgIlvl or 0,
		slots = slots,
		updatedAt = time(),
	}
end

function PluribusGearAdvisor:GetAltUpgradesForItem(itemLinkOrID)
	local gdb = self:GetGearDB()
	local me = PluribusHive:GetPlayerShortName()
	local _, equipLoc = self:ExtractItemStats(itemLinkOrID)
	if not equipLoc or not EQUIP_SLOTS[equipLoc] then return {} end

	local out = {}
	for altName, alt in pairs(gdb.altGear or {}) do
		if not PluribusHive:SamePlayer(altName, me) then
			local _, altProf = self:GetActiveProfile(alt.class, alt.spec)
			local cand = self:ScoreItem(itemLinkOrID, altProf, { hit = 0, spellHit = 0, defense = 300 })
			local eqScore = (alt.slots and alt.slots[equipLoc]) or 0
			if cand and cand.score > eqScore + 1 then
				local pct = eqScore > 0 and math.floor(((cand.score - eqScore) / eqScore) * 100 + 0.5) or 100
				if pct >= 2 then
					table.insert(out, { name = altName, class = alt.class, pct = pct })
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.pct > b.pct end)
	return out
end

-- ============================================================================
-- EQUIPPABLE BAG UPGRADES (WITH 1-CLICK EQUIP) & LOOK-AHEAD
-- ============================================================================
function PluribusGearAdvisor:GetEquippableBagUpgrades()
	local myLvl = UnitLevel and UnitLevel("player") or 60
	local list = {}
	if not (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots) then return list end

	for bag = 0, 4 do
		local slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
		for slot = 1, slots do
			local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
			if link then
				local ev = self:EvaluateItem(link)
				if ev and ev.isUpgrade and ev.candidate and (ev.candidate.reqLevel or 0) <= myLvl then
					table.insert(list, {
						bag = bag,
						slot = slot,
						link = link,
						name = ev.candidate.name or "Upgrade",
						equipLoc = ev.candidate.equipLoc,
						quality = ev.candidate.quality,
						pct = ev.pct,
						delta = ev.delta,
						capWarning = ev.capWarning,
					})
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.pct > b.pct end)
	return list
end

function PluribusGearAdvisor:GetUpcomingBagUpgrades()
	local myLvl = UnitLevel and UnitLevel("player") or 60
	local upcoming = {}
	if not (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots) then return upcoming end

	for bag = 0, 4 do
		local slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
		for slot = 1, slots do
			local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
			if link then
				local ev = self:EvaluateItem(link)
				if ev and ev.isUpgrade and ev.candidate and (ev.candidate.reqLevel or 0) > myLvl then
					table.insert(upcoming, {
						name = ev.candidate.name or "Upgrade",
						link = link,
						reqLevel = ev.candidate.reqLevel,
						pct = ev.pct,
					})
				end
			end
		end
	end
	table.sort(upcoming, function(a, b)
		if a.reqLevel ~= b.reqLevel then return a.reqLevel < b.reqLevel end
		return a.pct > b.pct
	end)
	return upcoming
end

local bagUpgradeArrows = {}

function PluribusGearAdvisor:RefreshBagUpgradeArrows()
	if InCombatLockdown and InCombatLockdown() then return end
	local myLvl = UnitLevel and UnitLevel("player") or 60
	for bagIdx = 1, 5 do
		local cf = _G["ContainerFrame" .. bagIdx]
		if cf and cf:IsShown() then
			local bagID = cf.GetID and cf:GetID() or (bagIdx - 1)
			local size = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID)) or (GetContainerNumSlots and GetContainerNumSlots(bagID)) or 0
			for btnIdx = 1, size do
				local btn = _G["ContainerFrame" .. bagIdx .. "Item" .. btnIdx]
				if btn then
					local arr = bagUpgradeArrows[btn]
					if not arr then
						arr = btn:CreateTexture(nil, "OVERLAY")
						arr:SetSize(14, 14)
						arr:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
						arr:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
						arr:SetVertexColor(0.22, 0.96, 0.45, 1)
						arr:Hide()
						bagUpgradeArrows[btn] = arr
					end
					local slotID = btn.GetID and btn:GetID() or btnIdx
					local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bagID, slotID)) or (GetContainerItemLink and GetContainerItemLink(bagID, slotID))
					local show = false
					if link then
						local ev = self:EvaluateItem(link)
						if ev and ev.isUpgrade and ev.candidate and (ev.candidate.reqLevel or 0) <= myLvl then
							show = true
						end
					end
					arr:SetShown(show)
				end
			end
		end
	end
end

-- ============================================================================
-- GEAR-AWARE XP & LOOT BAR HUD (/xpbar)
-- ============================================================================
function PluribusGearAdvisor:GetSessionRates()
	local elapsedHrs = math.max(1 / 60, (time() - (self.session.startedAt or time())) / 3600)
	local xpHr = math.floor((self.session.xpGained or 0) / elapsedHrs)
	local goldHr = math.floor(((self.session.copperLooted or 0) + (self.session.ahValueLooted or 0)) / elapsedHrs)
	local curXp = UnitXP and UnitXP("player") or 0
	local maxXp = math.max(1, UnitXPMax and UnitXPMax("player") or 100)
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	local remXp = math.max(0, maxXp - curXp)
	local ttlMin = xpHr > 0 and math.floor((remXp / xpHr) * 60) or nil
	return {
		curXp = curXp, maxXp = maxXp, rested = rested,
		pct = math.floor((curXp / maxXp) * 1000 + 0.5) / 10,
		xpHr = xpHr, goldHr = goldHr, ttlMin = ttlMin,
	}
end

function PluribusGearAdvisor:ToggleXPBar(forceShow)
	local UI = _G.PluribusUIFramework
	if not UI then return end
	local gdb = self:GetGearDB()

	if not self.xpBarFrame then
		local f = CreateFrame("Frame", "PluribusGearXPBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(440, 38)
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 118)
		f:SetFrameStrata("MEDIUM")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		UI:ApplyBackdrop(f, 0.05, 0.07, 0.12, 0.94, 0.24, 0.34, 0.48, 0.95)

		local bar = UI:CreateStatusBar(f, 424, 16, 0.48, 0.32, 0.92)
		bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
		f.bar = bar

		local sub = UI:CreateLabel(f, "", 0.78, 0.88, 0.96, "GameFontHighlightSmall")
		sub:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 4)
		f.sub = sub

		local closeX = UI:CreateButton(f, "x", 16, 14, function()
			f:Hide()
			gdb.showXpBar = false
		end)
		closeX:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 3)

		f:SetScript("OnUpdate", function(selfF, el)
			selfF._acc = (selfF._acc or 0) + (el or 0)
			if selfF._acc < 1.5 then return end
			selfF._acc = 0
			PluribusGearAdvisor:RefreshXPBar()
		end)
		self.xpBarFrame = f
	end

	local show = (forceShow ~= nil) and forceShow or (not self.xpBarFrame:IsVisible())
	gdb.showXpBar = show
	self.xpBarFrame:SetShown(show)
	if show then self:RefreshXPBar() end
end

function PluribusGearAdvisor:RefreshXPBar()
	local f = self.xpBarFrame
	if not f or not f:IsVisible() then return end
	local r = self:GetSessionRates()
	local ttlTxt = r.ttlMin and (r.ttlMin .. "m") or "—"
	f.bar:SetBarData(r.pct,
		string.format("Lv %d  ·  %.1f%% XP  (Rested: %d)", UnitLevel and UnitLevel("player") or 60, r.pct, r.rested),
		string.format("%dk XP/h · %s", math.floor(r.xpHr / 1000), ttlTxt),
		0.48, 0.32, 0.92)

	local up = self:GetUpcomingBagUpgrades()
	local nextTxt = up[1] and string.format("|cff4ade80Next: Lv%d %s (+%.1f%%)|r", up[1].reqLevel, tostring(up[1].name):sub(1, 18), up[1].pct) or ""
	f.sub:SetText(string.format("|cfffbbf24Farm: %s/h|r  %s", PluribusUtils:FormatGold(r.goldHr), nextTxt))
end

-- ============================================================================
-- MAINFRAME EMBEDDED UI: PLURIBUS GEARADVISOR
-- ============================================================================
function PluribusGearAdvisor:RenderPanel(parent, width, height, onRefresh)
	local UI = _G.PluribusUIFramework
	if not UI or not parent then return end
	local w = width or 726
	local h = height or 444
	local specKey, profile = self:GetActiveProfile()
	local caps = self:GetCurrentCapTotals()
	local cls = PluribusHive:GetPlayerClass()

	local banner = UI:CreateBannerCard(parent, w, 54, "Interface\\Icons\\INV_Misc_Gear_01",
		"|cfffbbf24" .. L("GEAR_TITLE") .. "|r  |cff94a3b8(" .. (profile.label or specKey) .. ")|r",
		string.format("Avg iLvl: |cff38bdf8%d|r  ·  Hit: |cff4ade80%d%%|r  ·  Spell Hit: |cff38bdf8%d%%|r  ·  Defense: |cfffbbf24%d|r",
			caps.avgIlvl or 0, caps.hit or 0, caps.spellHit or 0, caps.defense or 300),
		0.92, 0.72, 0.22)
	banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)

	local specOpts = {}
	for k in pairs(SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR) do
		table.insert(specOpts, { value = k, label = k })
	end
	table.sort(specOpts, function(a, b) return a.label < b.label end)

	local specDrop = UI:CreateFlatDropdown(banner, 146, 24, specOpts, specKey, function(val)
		local gdb = PluribusGearAdvisor:GetGearDB()
		gdb.specOverride[PluribusHive:GetPlayerShortName()] = val
		PluribusGearAdvisor:SnapshotMyGearForAlts()
		if onRefresh then onRefresh() end
	end, "Spec...")
	specDrop:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	local defs = {
		{ id = "overview", label = L("GEAR_SUB_OVERVIEW"), w = 118 },
		{ id = "lab",      label = L("GEAR_SUB_LAB"),      w = 122 },
		{ id = "roadmap",  label = L("GEAR_SUB_ROADMAP"),  w = 126 },
		{ id = "talents",  label = L("GEAR_SUB_TALENTS"),  w = 114 },
		{ id = "xpbar",    label = L("GEAR_SUB_XPBAR"),    w = 118 },
	}
	local prevBtn = nil
	for _, d in ipairs(defs) do
		local b = UI:CreateButton(parent, d.label, d.w, 24, function()
			PluribusGearAdvisor.subTab = d.id
			if onRefresh then onRefresh() end
		end)
		if prevBtn then
			b:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
		else
			b:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)
		end
		b:SetActiveState(self.subTab == d.id)
		prevBtn = b
	end

	local scroll = UI:CreateScrollFrame(parent, "PluribusGearAdvisorScroll", w, h - 104)
	scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -40)
	local y = -2

	if self.subTab == "overview" then
		-- 1. Cap Guardian bars
		local pCaps = profile.caps or {}
		local capBars = {}
		if (pCaps.hit or 0) > 0 then
			table.insert(capBars, { label = "Melee / Ranged Hit Cap", cur = caps.hit, target = pCaps.hit, unit = "%" })
		end
		if (pCaps.spellHit or 0) > 0 then
			table.insert(capBars, { label = "Spell Hit Cap (Raid Boss)", cur = caps.spellHit, target = pCaps.spellHit, unit = "%" })
		end
		if (pCaps.defense or 0) > 0 then
			table.insert(capBars, { label = "Crit-Immunity Defense Cap", cur = caps.defense, target = pCaps.defense, unit = " Def" })
		end
		for _, cb in ipairs(capBars) do
			local pct = math.min(100, math.floor((cb.cur / math.max(1, cb.target)) * 100))
			local capped = cb.cur >= cb.target
			local bar = UI:CreateStatusBar(scroll.content, w - 28, 24, capped and 0.22 or 0.92, capped and 0.78 or 0.64, capped and 0.44 or 0.16)
			bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			bar:SetBarData(pct, cb.label, string.format("%d / %d%s %s", cb.cur, cb.target, cb.unit, capped and "(CAPPED)" or "(Need More)"))
			y = y - 28
		end

		-- 2. Equippable Bag Upgrades right here with 1-Click Equip!
		local bagUpgrades = self:GetEquippableBagUpgrades()
		if #bagUpgrades > 0 then
			local bHdr = UI:CreateLabel(scroll.content, "|cff4ade80" .. L("GEAR_BAG_UPGRADES", #bagUpgrades) .. "|r", 1, 1, 1, "GameFontNormal")
			bHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 4)
			y = y - 24
			for idx, up in ipairs(bagUpgrades) do
				local row = UI:CreateListRow(scroll.content, w - 28, 34, idx)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
				local itemID = PluribusUtils:GetItemIDFromHyperlink(up.link)
				local slotIcon = UI:CreateItemSlot(row, 26, { itemID = itemID, link = up.link, quality = up.quality })
				slotIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
				local warnStr = up.capWarning and (" |cfffbbf24[" .. up.capWarning .. "]|r") or ""
				local l1 = UI:CreateLabel(row, string.format("%s  |cff4ade80+%.1f%% %s|r%s", up.link or up.name, up.pct, L("GEAR_UPGRADE"), warnStr))
				l1:SetPoint("LEFT", slotIcon, "RIGHT", 8, 0)

				local eqBtn = UI:CreateButton(row, L("GEAR_EQUIP"), 72, 22, function()
					if InCombatLockdown and InCombatLockdown() then return end
					if EquipItemByName and up.link then
						pcall(EquipItemByName, up.link)
					elseif C_Container and C_Container.PickupContainerItem and AutoEquipCursorItem then
						pcall(C_Container.PickupContainerItem, up.bag, up.slot)
						pcall(AutoEquipCursorItem)
					elseif PickupContainerItem and AutoEquipCursorItem then
						pcall(PickupContainerItem, up.bag, up.slot)
						pcall(AutoEquipCursorItem)
					end
					if C_Timer and C_Timer.After then
						C_Timer.After(0.3, function() if onRefresh then onRefresh() end end)
					end
				end, true)
				eqBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 36
			end
			y = y - 6
		end

		-- 3. Equipped Priority Upgrade Slots (Weakest First)
		local eqList = {}
		if GetInventoryItemLink then
			for slot = 1, 18 do
				if slot ~= 4 then
					local link = GetInventoryItemLink("player", slot)
					if link then
						local ev = self:ScoreItem(link, profile, caps)
						if ev then
							table.insert(eqList, { slot = slot, link = link, ev = ev })
						end
					end
				end
			end
		end
		table.sort(eqList, function(a, b) return a.ev.score < b.ev.score end)

		local sHdr = UI:CreateLabel(scroll.content, "|cfffbbf24Weakest Equipped Slots (Click -> Stat Laboratory):|r")
		sHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 2)
		y = y - 22

		for idx, item in ipairs(eqList) do
			local row = UI:CreateListRow(scroll.content, w - 28, 34, idx, function()
				PluribusGearAdvisor.labSlot = item.ev.equipLoc
				PluribusGearAdvisor.subTab = "lab"
				if onRefresh then onRefresh() end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

			local itemID = PluribusUtils:GetItemIDFromHyperlink(item.link)
			local slotIcon = UI:CreateItemSlot(row, 26, { itemID = itemID, link = item.link, quality = item.ev.quality })
			slotIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, string.format("%s  |cff94a3b8(%s · iLvl %d)|r", item.link or item.ev.name or "Slot", SLOT_LABELS[item.ev.equipLoc] or item.ev.equipLoc, item.ev.ilvl))
			l1:SetPoint("LEFT", slotIcon, "RIGHT", 8, 0)

			local scLbl = UI:CreateLabel(row, string.format("|cff38bdf8Score: %.1f|r", item.ev.score))
			scLbl:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			y = y - 36
		end

	elseif self.subTab == "lab" then
		-- STAT LABORATORY: Side-by-Side Comparison + Editable Custom Stat Weights!
		local slotOpts = {}
		for k, lbl in pairs(SLOT_LABELS) do
			table.insert(slotOpts, { value = k, label = lbl })
		end
		table.sort(slotOpts, function(a, b) return a.label < b.label end)

		local sDrop = UI:CreateFlatDropdown(scroll.content, 178, 24, slotOpts, self.labSlot, function(v)
			PluribusGearAdvisor.labSlot = v
			PluribusGearAdvisor.labCandidateLink = nil
			if onRefresh then onRefresh() end
		end, "Slot...")
		sDrop:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

		local bagCands = {}
		for bag = 0, 4 do
			local num = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
			for s = 1, num do
				local link = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, s)) or (GetContainerItemLink and GetContainerItemLink(bag, s))
				if link then
					local _, loc, _, _, _, nm = self:ExtractItemStats(link)
					if loc == self.labSlot or (self.labSlot == "INVTYPE_CHEST" and loc == "INVTYPE_ROBE") then
						table.insert(bagCands, { value = link, label = nm or "Bag Item" })
					end
				end
			end
		end
		if not self.labCandidateLink and bagCands[1] then
			self.labCandidateLink = bagCands[1].value
		end

		local cDrop = UI:CreateFlatDropdown(scroll.content, 280, 24,
			#bagCands > 0 and bagCands or { { value = "", label = "No matching items in bags" } },
			self.labCandidateLink or "",
			function(v)
				PluribusGearAdvisor.labCandidateLink = v ~= "" and v or nil
				if onRefresh then onRefresh() end
			end,
			"Bag Item...")
		cDrop:SetPoint("LEFT", sDrop, "RIGHT", 8, 0)
		y = y - 34

		local sIds = EQUIP_SLOTS[self.labSlot] or { 5 }
		local eqLink = GetInventoryItemLink and GetInventoryItemLink("player", sIds[1]) or nil
		local eqEval = eqLink and self:ScoreItem(eqLink, profile, caps) or nil
		local candEval = self.labCandidateLink and self:EvaluateItem(self.labCandidateLink) or nil

		local halfW = math.floor((w - 36) / 2)
		local leftCard = UI:CreateCard(scroll.content, halfW, 174, "Equipped")
		leftCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		local lTxt = eqEval
			and string.format("%s\n\n|cff38bdf8Score: %.1f|r  (iLvl %d)\nStr %d · Agi %d · Sta %d · Int %d · Spi %d\nSP %d · Heal %d · AP %d · Hit %d%% · Crit %d%% · DPS %.1f",
				eqLink or "", eqEval.score, eqEval.ilvl, eqEval.stats.STR, eqEval.stats.AGI, eqEval.stats.STA, eqEval.stats.INT, eqEval.stats.SPI, eqEval.stats.SP, eqEval.stats.HEAL, eqEval.stats.AP, eqEval.stats.HIT, eqEval.stats.CRIT, eqEval.stats.DPS)
			or "Empty Slot (Score: 0)"
		local lLbl = UI:CreateLabel(leftCard, lTxt, 0.88, 0.93, 0.98)
		lLbl:SetPoint("TOPLEFT", leftCard, "TOPLEFT", 10, -28)
		lLbl:SetWidth(halfW - 20)

		local rightCard = UI:CreateCard(scroll.content, halfW, 174, "Candidate")
		rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
		local rTxt
		if candEval and candEval.candidate then
			local c = candEval.candidate
			local vCol = candEval.pct >= 0 and "|cff4ade80+" or "|cfff87171"
			local warn = candEval.capWarning and ("\n|cfffbbf24WARN: " .. candEval.capWarning .. "|r") or ""
			rTxt = string.format("%s\n\n%s%.1f%% (%+.1f)|r%s  (iLvl %d)\nStr %d · Agi %d · Sta %d · Int %d · Spi %d\nSP %d · Heal %d · AP %d · Hit %d%% · Crit %d%% · DPS %.1f",
				c.link or c.name or "", vCol, candEval.pct, candEval.delta, warn, c.ilvl, c.stats.STR, c.stats.AGI, c.stats.STA, c.stats.INT, c.stats.SPI, c.stats.SP, c.stats.HEAL, c.stats.AP, c.stats.HIT, c.stats.CRIT, c.stats.DPS)
		else
			rTxt = "Select any matching item from your bags above to simulate exact stats & Cap Guardian impact."
		end
		local rLbl = UI:CreateLabel(rightCard, rTxt, 0.88, 0.93, 0.98)
		rLbl:SetPoint("TOPLEFT", rightCard, "TOPLEFT", 10, -28)
		rLbl:SetWidth(halfW - 20)
		y = y - 184

		-- Editable Custom Stat Weights Grid
		local wHdr = UI:CreateLabel(scroll.content, "|cfffbbf24" .. L("GEAR_WEIGHTS_TITLE") .. "|r", 1, 1, 1, "GameFontNormal")
		wHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		local rstBtn = UI:CreateButton(scroll.content, L("GEAR_WEIGHTS_RESET"), 134, 20, function()
			PluribusGearAdvisor:ResetCustomWeights()
			if onRefresh then onRefresh() end
		end)
		rstBtn:SetPoint("TOPRIGHT", scroll.content, "TOPRIGHT", -26, y + 2)
		y = y - 24

		local statKeys = {}
		for k in pairs(profile.weights or {}) do table.insert(statKeys, k) end
		table.sort(statKeys)
		local colW = math.floor((w - 36) / 2)
		for idx, sk in ipairs(statKeys) do
			local col = (idx - 1) % 2
			local rowIdx = math.floor((idx - 1) / 2)
			local rx = 2 + col * (colW + 6)
			local ry = y - rowIdx * 28
			local row = UI:CreateListRow(scroll.content, colW, 25, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", rx, ry)
			local lbl = UI:CreateLabel(row, string.format("|cff38bdf8%s|r:  |cffffffff%.1f|r", sk, profile.weights[sk] or 0))
			lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
			local plusB = UI:CreateButton(row, "+", 22, 18, function()
				PluribusGearAdvisor:AdjustCustomWeight(sk, 0.5)
				if onRefresh then onRefresh() end
			end, true)
			plusB:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			local minusB = UI:CreateButton(row, "-", 22, 18, function()
				PluribusGearAdvisor:AdjustCustomWeight(sk, -0.5)
				if onRefresh then onRefresh() end
			end)
			minusB:SetPoint("RIGHT", plusB, "LEFT", -3, 0)
		end
		y = y - (math.ceil(#statKeys / 2) * 28) - 10

	elseif self.subTab == "roadmap" then
		local myLvl = UnitLevel and UnitLevel("player") or 60
		local myIlvl = (caps.avgIlvl and caps.avgIlvl > 0) and caps.avgIlvl or math.max(10, myLvl)
		local ranked, upcoming = self:BuildUpgradeRoadmap(myLvl, myIlvl)

		local rmHdr = UI:CreateLabel(scroll.content, string.format(
			"|cff38bdf8Passende Upgrade-Ziele für Level %d|r  |cff94a3b8(Ø iLvl %d · Raids erst ab Lv 60)|r",
			myLvl, myIlvl), 1, 1, 1, "GameFontNormal")
		rmHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 2)
		y = y - 24

		local function RenderRoadmapRow(idx, r, isUpcoming)
			local s = r.src
			local row = UI:CreateListRow(scroll.content, w - 28, 44, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

			local ic = s.tier == "Raid" and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_Key_14"
			local br = isUpcoming and 0.45 or (s.tier == "Raid" and 0.92 or 0.22)
			local bg = isUpcoming and 0.52 or (s.tier == "Raid" and 0.62 or 0.74)
			local bb = isUpcoming and 0.64 or (s.tier == "Raid" and 0.18 or 0.97)
			local badge = UI:CreateIconBadge(row, ic, 32, br, bg, bb)
			badge:SetPoint("LEFT", row, "LEFT", 6, 0)

			local tagCol = isUpcoming and "|cff94a3b8" or (r.fitTag == "Ideal" and "|cff4ade80" or "|cfffbbf24")
			local deltaStr = (r.ilvlDelta or 0) >= 0 and ("|cff4ade80+" .. tostring(math.floor(r.ilvlDelta or 0)) .. " iLvl|r") or ("|cff94a3b8" .. tostring(math.floor(r.ilvlDelta or 0)) .. " iLvl|r")
			local titleCol = isUpcoming and "|cffcbd5e1" or "|cfffbbf24"
			local prefix = isUpcoming and "" or ("#" .. idx .. " ")
			local l1 = UI:CreateLabel(row, string.format("%s%s%s|r %s[%s]|r |cff94a3b8(%s · Lv %d-%d · ~iLvl %d)|r  %s",
				titleCol, prefix, s.name, tagCol, tostring(r.fitTag or ""), s.tier, s.minL, s.maxL, s.ilvl, deltaStr))
			l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)

			local l2 = UI:CreateLabel(row, table.concat(s.highlights, ", "), 0.74, 0.84, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

			local navBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 88, 22, function()
				if _G.PluribusNavigationUI then
					_G.PluribusNavigationUI:SetWaypoint(s.name, s.zone, s.x, s.y)
				end
			end, not isUpcoming)
			navBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 46
		end

		if #ranked == 0 then
			local em = UI:CreateLabel(scroll.content,
				string.format("|cff94a3b8Auf Level %d lohnt sich Quest- & Open-World-Gear — erste Dungeons starten ab Level 13-17.|r", myLvl),
				0.78, 0.86, 0.94)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, y - 4)
			y = y - 28
		else
			for idx, r in ipairs(ranked) do
				RenderRoadmapRow(idx, r, false)
			end
		end

		if #upcoming > 0 then
			y = y - 6
			local uHdr = UI:CreateLabel(scroll.content, "|cff94a3b8Demnächst erreichbar (nächste Stufen):|r", 1, 1, 1, "GameFontNormalSmall")
			uHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			y = y - 20
			for idx, r in ipairs(upcoming) do
				RenderRoadmapRow(idx, r, true)
			end
		end

	elseif self.subTab == "talents" then
		local tCard = UI:CreateBannerCard(scroll.content, w - 28, 62, "Interface\\Icons\\Ability_Marksmanship",
			"|cff38bdf8" .. (profile.label or specKey) .. "|r",
			profile.talents or "Classic 1.60.1 Build",
			0.22, 0.74, 0.97)
		tCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		y = y - 70

		local allSpecs = SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR
		for sKey, sDef in pairs(allSpecs) do
			local card = UI:CreateCard(scroll.content, w - 28, 62, sDef.label)
			card:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			local lbl = UI:CreateLabel(card, "|cfffbbf24Build:|r " .. tostring(sDef.talents), 0.86, 0.92, 0.98)
			lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -28)
			local useBtn = UI:CreateButton(card, sKey == specKey and "Active" or "Select", 90, 22, function()
				local gdb = PluribusGearAdvisor:GetGearDB()
				gdb.specOverride[PluribusHive:GetPlayerShortName()] = sKey
				if onRefresh then onRefresh() end
			end, sKey == specKey)
			useBtn:SetPoint("RIGHT", card, "RIGHT", -10, -4)
			y = y - 68
		end

	else
		local r = self:GetSessionRates()
		local toggleBtn = UI:CreateButton(scroll.content, (self.xpBarFrame and self.xpBarFrame:IsVisible()) and "Hide /xpbar" or "Show /xpbar", 180, 26, function()
			PluribusGearAdvisor:ToggleXPBar()
			if onRefresh then onRefresh() end
		end, true)
		toggleBtn:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		y = y - 36

		local statCard = UI:CreateCard(scroll.content, w - 28, 76, "Session XP & Loot")
		statCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		local sTxt = string.format("XP: |cff38bdf8%.1f%%|r (%d/%d · Rested %d)  ·  |cff4ade80%dk XP/h|r\nGold + AH Loot: |cfffbbf24%s/h|r  ·  Items: %d",
			r.pct, r.curXp, r.maxXp, r.rested, math.floor(r.xpHr / 1000), PluribusUtils:FormatGold(r.goldHr), self.session.itemsLooted or 0)
		local sLbl = UI:CreateLabel(statCard, sTxt, 0.88, 0.94, 0.98)
		sLbl:SetPoint("TOPLEFT", statCard, "TOPLEFT", 10, -28)
		y = y - 84

		local up = self:GetUpcomingBagUpgrades()
		local uHdr = UI:CreateLabel(scroll.content, "|cff4ade80Upcoming Bag Upgrades (" .. #up .. "):|r")
		uHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 20
		for idx, it in ipairs(up) do
			local row = UI:CreateListRow(scroll.content, w - 28, 30, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			local l1 = UI:CreateLabel(row, string.format("Lv %d — %s  |cff4ade80+%.1f%%|r", it.reqLevel, it.link or it.name, it.pct))
			l1:SetPoint("LEFT", row, "LEFT", 8, 0)
			y = y - 32
		end
	end

	scroll.content:SetHeight(math.max(300, math.abs(y) + 14))
end

function PluribusGearAdvisor:Initialize()
	if self.initialized then return end
	self.initialized = true
	self.session.startedAt = time()
	self:GetGearDB()

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_EQUIPMENT_CHANGED",
		"BAG_UPDATE_DELAYED",
		"CHAT_MSG_COMBAT_XP_GAIN",
		"CHAT_MSG_MONEY",
		"CHAT_MSG_LOOT",
		"QUEST_TURNED_IN",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusGearAdvisor:SnapshotMyGearForAlts()
			if PluribusGearAdvisor:GetGearDB().showXpBar then
				PluribusGearAdvisor:ToggleXPBar(true)
			end
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			PluribusGearAdvisor.statCache = {}
			PluribusGearAdvisor:SnapshotMyGearForAlts()
			PluribusGearAdvisor:RefreshBagUpgradeArrows()
		elseif event == "BAG_UPDATE_DELAYED" then
			PluribusGearAdvisor:RefreshBagUpgradeArrows()
		elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and type(arg1) == "string" then
			local xp = tonumber(arg1:match("(%d+)%s+experience")) or tonumber(arg1:match("(%d+)%s+Erfahrung")) or tonumber(arg1:match("(%d+)")) or 0
			PluribusGearAdvisor.session.xpGained = (PluribusGearAdvisor.session.xpGained or 0) + xp
		elseif event == "QUEST_TURNED_IN" then
			local xp = tonumber(arg2) or 0
			PluribusGearAdvisor.session.xpGained = (PluribusGearAdvisor.session.xpGained or 0) + xp
		elseif event == "CHAT_MSG_MONEY" and type(arg1) == "string" then
			local g = tonumber(arg1:match("(%d+)%s*Gold")) or 0
			local s = tonumber(arg1:match("(%d+)%s*Silver")) or tonumber(arg1:match("(%d+)%s*Silber")) or 0
			local c = tonumber(arg1:match("(%d+)%s*Copper")) or tonumber(arg1:match("(%d+)%s*Kupfer")) or 0
			PluribusGearAdvisor.session.copperLooted = (PluribusGearAdvisor.session.copperLooted or 0) + g * 10000 + s * 100 + c
		elseif event == "CHAT_MSG_LOOT" and type(arg1) == "string" then
			local id = tonumber(arg1:match("item:(%d+)"))
			if id then
				local qty = tonumber(arg1:match("x(%d+)")) or 1
				PluribusGearAdvisor.session.itemsLooted = (PluribusGearAdvisor.session.itemsLooted or 0) + qty
				if _G.PluribusHiveAuction and _G.PluribusHiveAuction.GetPrice then
					local p = _G.PluribusHiveAuction:GetPrice(id)
					if p and p.copper and p.copper > 0 then
						PluribusGearAdvisor.session.ahValueLooted = (PluribusGearAdvisor.session.ahValueLooted or 0) + (p.copper * qty)
					end
				end
			end
		end
	end)

	if hooksecurefunc and _G.ContainerFrame_Update then
		pcall(hooksecurefunc, "ContainerFrame_Update", function()
			PluribusGearAdvisor:RefreshBagUpgradeArrows()
		end)
	end
end

return PluribusGearAdvisor
