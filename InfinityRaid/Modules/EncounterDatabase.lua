-- Encounter Database
-- Database of raid encounters with mechanics, composition requirements, and tactics

local EncounterDatabase = {
	encounters = {}, -- {bossId = encounterData}
	currentEncounter = nil,
	
	config = {
		enableDebugOutput = false,
	},
}

_G.InfinityEncounterDatabase = EncounterDatabase

-- Initialize encounter database
function EncounterDatabase:Initialize()
	InfinityUtils:Info("Encounter database initialized", "Raid")
	
	-- Register some example encounters
	self:RegisterDefaultEncounters()
	
	-- Listen for encounter events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ENCOUNTER_START")
	frame:RegisterEvent("ENCOUNTER_END")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "ENCOUNTER_START" then
			EncounterDatabase:OnEncounterStart(...)
		elseif event == "ENCOUNTER_END" then
			EncounterDatabase:OnEncounterEnd(...)
		end
	end)
end

-- Register default encounters
function EncounterDatabase:RegisterDefaultEncounters()
	-- Molten Core bosses
	local moltenCoreBosses = {
		{
			id = 1, name = "Lucifron", zone = "Molten Core", level = 60, health = 75000,
			mechanics = {"Curse of Weakness", "Dispels heal (dangerous)"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 3},
			tactics = "Dispel curses regularly. Tank and spank.",
			loot = {{name = "Perdition's Blade", rarity = 4}, {name = "Mana Focusing Crystal", rarity = 3}}
		},
		{
			id = 2, name = "Heigan the Unclean", zone = "Naxxramas", level = 60, health = 283200,
			mechanics = {"Disease Cloud", "Eruptions (ground effect)", "Teleport"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Move out of disease cloud. Tank positioning critical.",
			loot = {{name = "Leggings of Polished Bone", rarity = 4}, {name = "Soulrender", rarity = 4}}
		},
		{
			id = 3, name = "Taerar", zone = "World Dragons", level = 60, health = 150000,
			mechanics = {"Silence", "Healing add summons", "Mana drain"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 8},
			tactics = "CC healing adds immediately. Silence dispel essential.",
			loot = {{name = "Dragon's Bite", rarity = 4}}
		},
		{
			id = 4, name = "Ysondre", zone = "World Dragons", level = 60, health = 150000,
			mechanics = {"Heal", "Deep Roots (DoT)", "Summons whelps"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 8},
			tactics = "Burn adds. Interrupt heals when possible.",
			loot = {{name = "Pendant of the Dragonslayer", rarity = 4}}
		},
		{
			id = 5, name = "Lethargus", zone = "World Dragons", level = 60, health = 150000,
			mechanics = {"Sleep effect", "High melee damage", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 8},
			tactics = "Wake sleepers. High tank damage incoming.",
			loot = {{name = "Dragon's Breath Helm", rarity = 4}}
		},
		{
			id = 6, name = "Azuregos", zone = "Azshara", level = 60, health = 200000,
			mechanics = {"Arcane explosion", "Magic reflector", "Summons adds"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 10},
			tactics = "Manage adds. Tank swaps for reflector.",
			loot = {{name = "Head of Azuregos", rarity = 4}, {name = "Staff of the Void", rarity = 4}}
		},
	}
	
	-- Blackwing Lair bosses
	local blackwingBosses = {
		{
			id = 7, name = "Razorgore the Untamed", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Orb of Power (MC add)", "Breath attacks", "High melee"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "One player runs eggs, kills one at a time. Control adds.",
			loot = {{name = "Claw of the Black Drake", rarity = 4}}
		},
		{
			id = 8, name = "Vaelastrasz the Corrupt", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Burning Adrenaline (threat)", "Flame breath", "Healing"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Manage Adrenaline targets. Keep off healers.",
			loot = {{name = "Drake Talon Pauldrons", rarity = 4}}
		},
		{
			id = 9, name = "Broodlord Lashlayer", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Mortal Strike", "Cleave", "High damage"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 15},
			tactics = "Tank and spank. Heavy raid healing.",
			loot = {{name = "Broodlord's Leggings", rarity = 4}}
		},
	}
	
	-- World bosses
	local worldBosses = {
		{
			id = 20, name = "Onyxia", zone = "Onyxia's Lair", level = 60, health = 780000,
			mechanics = {"Deep Breath (phase)", "Void summons", "Tail swipe"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 18},
			tactics = "Phase transitions are critical. Burn phase 2 fast.",
			loot = {{name = "Spinal Reaper", rarity = 4}, {name = "Pristine Dragon Egg", rarity = 4}}
		},
	}
	
	-- Zul'Farrak bosses (5-man dungeon)
	local zulfarak = {
		{
			id = 21, name = "Gahz'rilla", zone = "Zul'Farrak", level = 45, health = 65000,
			mechanics = {"Water spout", "Summons serpents", "High melee damage"},
			compositionRequirements = {minTanks = 1, minHealers = 1, minDPS = 3},
			tactics = "Manage adds. Tank must handle the boss.",
			loot = {{name = "Gahz'rilla Fang", rarity = 4}}
		},
		{
			id = 22, name = "Hakkar", zone = "Zul'Farrak", level = 46, health = 75000,
			mechanics = {"Poison cloud", "Enrage", "Mind control adds"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 2},
			tactics = "Cure poison frequently. Interrupt casting.",
			loot = {{name = "Skul's Ghastly Gown", rarity = 3}}
		},
	}
	
	-- World Dragons (outdoor world bosses)
	local worldDragons = {
		{
			id = 23, name = "Emeriss", zone = "Duskwood", level = 52, health = 180000,
			mechanics = {"Silence", "Healing", "High damage"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "Silence dispel essential. Interrupt heals.",
			loot = {{name = "Emeriss's Claw", rarity = 4}}
		},
		{
			id = 24, name = "Taerar", zone = "Feralas", level = 52, health = 180000,
			mechanics = {"Silence", "Healing add summons", "Mana drain"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "CC healing adds immediately. Silence dispel essential.",
			loot = {{name = "Dragon's Bite", rarity = 4}}
		},
		{
			id = 25, name = "Ysondre", zone = "Ashenvale", level = 52, health = 180000,
			mechanics = {"Heal", "Deep Roots (DoT)", "Summons whelps"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "Burn adds. Interrupt heals when possible.",
			loot = {{name = "Pendant of the Dragonslayer", rarity = 4}}
		},
	}
	
	-- Blackrock Spire bosses (5 and 10 man)
	local blackrockSpire = {
		{
			id = 26, name = "Highlord Kruul", zone = "Blackrock Spire", level = 50, health = 120000,
			mechanics = {"Felstorm", "Summons demons", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Manage demon adds. Heavy tank damage.",
			loot = {{name = "Spire of Blackrock", rarity = 4}}
		},
		{
			id = 27, name = "Rend Blackhand", zone = "Blackrock Spire", level = 51, health = 150000,
			mechanics = {"Charge", "Enrage", "Phase 2 adds"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Phase 2: burn adds fast. High damage incoming.",
			loot = {{name = "Blastershot Launcher", rarity = 4}}
		},
	}
	
	-- World Dragons cont'd (more spawns)
	local worldDragons2 = {
		{
			id = 28, name = "Lethargus", zone = "Tanaris", level = 52, health = 180000,
			mechanics = {"Sleep effect", "High melee damage", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "Wake sleepers. High tank damage incoming.",
			loot = {{name = "Dragon's Breath Helm", rarity = 4}}
		},
		{
			id = 29, name = "Azuregos", zone = "Azshara", level = 55, health = 200000,
			mechanics = {"Arcane explosion", "Magic reflector", "Summons adds"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 8},
			tactics = "Manage adds. Tank swaps for reflector.",
			loot = {{name = "Head of Azuregos", rarity = 4}, {name = "Staff of the Void", rarity = 4}}
		},
	}
	
	-- Blackwing Lair additional bosses
	local blackwingAdditional = {
		{
			id = 30, name = "Firemaw", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Flame breath", "Summons guards", "Wing flap knockback"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Kill guards before DPS goes all out. Manage breath.",
			loot = {{name = "Claw of the Black Drake", rarity = 4}}
		},
		{
			id = 31, name = "Ebonroc", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Flameburst", "Shadow breath", "Knockback"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Move out of AoE patterns. Heavy raid damage.",
			loot = {{name = "Drake Talon Pauldrons", rarity = 4}}
		},
		{
			id = 32, name = "Flamegor", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Wingbuffet", "Flame breath", "High melee"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Tank and spank. Heavy raid healing required.",
			loot = {{name = "Broodlord's Leggings", rarity = 4}}
		},
		{
			id = 33, name = "Chromaggus", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Dual breath", "Enrage", "High damage phases"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Manage breath combos. Burn phases fast.",
			loot = {{name = "Chromatically Tempered Sword", rarity = 4}}
		},
		{
			id = 34, name = "Nefarian", zone = "Blackwing Lair", level = 60, health = 580000,
			mechanics = {"Shadowflame", "Class curses", "Phase 2 adds", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Cleanse class debuffs. Control adds phase 2.",
			loot = {{name = "Head of Nefarian", rarity = 4}, {name = "Nefarian's Tail", rarity = 4}}
		},
	}
	
	-- Molten Core additional bosses
	local moltenCoreAdditional = {
		{
			id = 35, name = "Magmadar", zone = "Molten Core", level = 60, health = 150000,
			mechanics = {"Panic", "Magma splash", "Summons lava adds"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Tank swaps for splash damage. Manage adds.",
			loot = {{name = "Magmadar Claw", rarity = 4}}
		},
		{
			id = 36, name = "Gehennas", zone = "Molten Core", level = 60, health = 180000,
			mechanics = {"Curse of Weakness", "Healing", "Rain of Fire"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Cleanse curses. Move out of Rain of Fire.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 37, name = "Sulfuron Harbinger", zone = "Molten Core", level = 60, health = 240000,
			mechanics = {"Heal", "Summons adds", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "Kill adds before boss enrages. Interrupt heals.",
			loot = {{name = "Sulfuras Hand of Ragnaros", rarity = 4}}
		},
		{
			id = 38, name = "Golemagg the Incinerator", zone = "Molten Core", level = 60, health = 180000,
			mechanics = {"Incendiary Cloud", "Summons golems", "High melee"},
			compositionRequirements = {minTanks = 2, minHealers = 2, minDPS = 6},
			tactics = "Manage 3 adds per golemagg death. Heavy tank damage.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 39, name = "Shazzrah", zone = "Molten Core", level = 60, health = 150000,
			mechanics = {"Arcane explosion", "Teleport", "Mana burn", "Silencing"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Tank positioning critical (spread). Silence cleanse.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 40, name = "Baron Geddon", zone = "Molten Core", level = 60, health = 180000,
			mechanics = {"Inferno", "Ignite Mana", "Knockback"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Manage Inferno cooldown. Mana management critical.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 41, name = "Garr", zone = "Molten Core", level = 60, health = 150000,
			mechanics = {"Summons adds", "Knockback", "Immolate"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Kill adds in order. Tank swaps.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 42, name = "Ragnaros", zone = "Molten Core", level = 60, health = 450000,
			mechanics = {"Melee attacks", "Knockback", "Submerge phase", "Hand spawns"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Phase 1: kill hands. Phase 2: maximize DPS. Run from knockback.",
			loot = {{name = "Perdition's Blade", rarity = 4}, {name = "Sulfuras", rarity = 5}}
		},
	}
	
	-- Register all bosses
	for _, boss in ipairs(moltenCoreBosses) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(blackwingBosses) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(worldBosses) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(zulfarak) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(worldDragons) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(blackrockSpire) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(worldDragons2) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(blackwingAdditional) do
		self:RegisterEncounter(boss)
	end
	for _, boss in ipairs(moltenCoreAdditional) do
		self:RegisterEncounter(boss)
	end
	
	-- Naxxramas bosses
	local naxxramasBosses = {
		{
			id = 50, name = "Anub'Rekhan", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Summons impales", "Poison cloud", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Tank swaps for spike damage. Manage adds.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 51, name = "Grand Widow Faerlina", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Poison bolt volley", "Enrage", "Silence"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 16},
			tactics = "Silence cleanse priority. Heavy raid AoE damage.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 52, name = "Maexxna", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Web spray", "Summons spiders", "Cocoon (crowd control)"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Break cocooned players. Manage spider adds.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 53, name = "Noth the Plaguebringer", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Plague cloud", "Teleport", "Summons adds", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Manage teleport positioning. Control summoned adds.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 54, name = "Heigan the Unclean", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Plague cloud", "Eruption waves", "Teleport"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 16},
			tactics = "Move out of waves. Healing management critical.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 55, name = "Loatheb", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Heal block", "Spore summons", "High damage"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Manage spore summons. DPS through damage reduction phase.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 56, name = "Instructor Razuvious", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Uncontrollable Frenzy", "Enrage", "Summons ghoul trainers"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Mind control ghoul trainers to control boss. Tank and spank.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 57, name = "Gothik the Harvester", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Phase 1: adds", "Phase 2: single combat", "Heal spectral"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Phase 1: manage adds on both sides. Phase 2: burn fast.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 58, name = "Four Horsemen", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Cursed marks", "Bladestorm", "Marks of champions", "Enrage"},
			compositionRequirements = {minTanks = 4, minHealers = 4, minDPS = 12},
			tactics = "Perfect tank rotation essential. Mark target focus.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 59, name = "Sapphiron", zone = "Naxxramas", level = 60, health = 540000,
			mechanics = {"Frost breath", "Flying phase", "Summons skeletons"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Move out of frost breath. Manage flying phase.",
			loot = {{name = "Pendant of the Netherling", rarity = 4}}
		},
		{
			id = 60, name = "Kel'Thuzad", zone = "Naxxramas", level = 60, health = 580000,
			mechanics = {"Phase 1: adds", "Phase 2: frost bolts", "Mind control", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Phase 1: kill adds in order. Phase 2: heavy burn.",
			loot = {{name = "Head of Kel'Thuzad", rarity = 4}, {name = "Kel'Thuzad's Leggings", rarity = 4}}
		},
	}
	
	for _, boss in ipairs(naxxramasBosses) do
		self:RegisterEncounter(boss)
	end
	
	-- Temple of Ahn'Qiraj (AQ40) bosses
	local aq40Bosses = {
		{
			id = 61, name = "The Prophet Skeram", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons images", "Phase shift", "Silence"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 16},
			tactics = "Kill images before DPS. Tank main image.",
			loot = {{name = "Skeram's Jewel", rarity = 4}}
		},
		{
			id = 62, name = "Siliss", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons eggs", "High magic damage", "Poison"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 16},
			tactics = "Destroy eggs fast. Heavy magic resistance.",
			loot = {{name = "Siliss Scale", rarity = 4}}
		},
		{
			id = 63, name = "Battleguard Sartura", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Melee attacks", "Knockback", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 15},
			tactics = "High tank damage. Keep distance from knockback.",
			loot = {{name = "Sartura's Armor", rarity = 4}}
		},
		{
			id = 64, name = "Fankriss the Unyielding", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons eggs", "Hive tunnel phase", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 16},
			tactics = "Destroy eggs. Manage tunnel adds.",
			loot = {{name = "Fankriss Exoskeleton", rarity = 4}}
		},
		{
			id = 65, name = "Viscidus", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Freeze mechanic", "Poison", "Cleave"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 17},
			tactics = "Freeze then shatter. Healing minimal.",
			loot = {{name = "Viscidus Armor", rarity = 4}}
		},
		{
			id = 66, name = "Princess Huhuran", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Poison nova", "Stun", "Summons adds"},
			compositionRequirements = {minTanks = 1, minHealers = 4, minDPS = 15},
			tactics = "Remove poison stacks. Manage adds.",
			loot = {{name = "Huhuran's Regal", rarity = 4}}
		},
		{
			id = 67, name = "Taerar", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons adds", "Summons sleepwalkers", "High damage"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Kill adds in priority order. Focus on sleep targets.",
			loot = {{name = "Taerar Essence", rarity = 4}}
		},
		{
			id = 68, name = "Ysondre", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons adds", "High damage phases", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Kill adds on spawn. Heavy DPS required.",
			loot = {{name = "Ysondre's Jewel", rarity = 4}}
		},
		{
			id = 69, name = "Lethiss", zone = "Temple of Ahn'Qiraj", level = 60, health = 540000,
			mechanics = {"Summons adds", "Poison damage", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Kill adds immediately. Tank swaps.",
			loot = {{name = "Lethiss Scale", rarity = 4}}
		},
		{
			id = 70, name = "C'Thun", zone = "Temple of Ahn'Qiraj", level = 60, health = 580000,
			mechanics = {"Phase 1: weak points", "Phase 2: tentacles", "Eye opens", "High damage"},
			compositionRequirements = {minTanks = 2, minHealers = 5, minDPS = 13},
			tactics = "Destroy weak points in order. Phase 2: burn phase.",
			loot = {{name = "Eye of C'Thun", rarity = 5}, {name = "C'Thun's Armor", rarity = 4}}
		},
	}
	
	for _, boss in ipairs(aq40Bosses) do
		self:RegisterEncounter(boss)
	end
	
	-- Additional World Bosses & Outdoor Encounters
	local worldBossesAdditional = {
		{
			id = 71, name = "Azuregos", zone = "Azshara", level = 55, health = 200000,
			mechanics = {"Arcane explosion", "Magic reflector", "Summons adds"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 8},
			tactics = "Manage adds. Tank swaps for reflector.",
			loot = {{name = "Head of Azuregos", rarity = 4}, {name = "Staff of the Void", rarity = 4}}
		},
		{
			id = 72, name = "Lord Taerar", zone = "Feralas", level = 52, health = 180000,
			mechanics = {"Summons adds", "Sleep effect", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Kill adds in order. Manage sleep.",
			loot = {{name = "Dragon's Breath Helm", rarity = 4}}
		},
		{
			id = 73, name = "Lethargus", zone = "Tanaris", level = 52, health = 180000,
			mechanics = {"Sleep effect", "High melee damage", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 5},
			tactics = "Wake sleepers. High tank damage.",
			loot = {{name = "Dragon's Breath Helm", rarity = 4}}
		},
		{
			id = 74, name = "Manadarr", zone = "Feralas", level = 51, health = 170000,
			mechanics = {"Summons adds", "Mana drain", "Arcane explosions"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Kill adds immediately. Manage mana drain.",
			loot = {{name = "Mana Focusing Crystal", rarity = 3}}
		},
		{
			id = 75, name = "Ebonroc", zone = "Blackwing Lair", level = 60, health = 540000,
			mechanics = {"Flameburst", "Shadow breath", "Knockback"},
			compositionRequirements = {minTanks = 2, minHealers = 4, minDPS = 14},
			tactics = "Move out of AoE. Heavy raid damage.",
			loot = {{name = "Drake Talon Pauldrons", rarity = 4}}
		},
		{
			id = 76, name = "Taerar (Green)', zone = "Ashenvale", level = 51, health = 150000,
			mechanics = {"Summons sleepwalkers", "High melee", "Poison"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Focus sleep targets. Tank swaps.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 77, name = "Ysondre", zone = "Ashenvale", level = 51, health = 150000,
			mechanics = {"Summons adds", "High damage phases", "Enrage"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Kill adds on spawn. Heavy DPS.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 78, name = "Lethiss (Green)", zone = "Duskwood", level = 51, health = 150000,
			mechanics = {"Summons adds", "Poison damage", "Cleave"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Kill adds fast. Tank swaps.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 79, name = "Blackstone Lord", zone = "Blackrock Spire", level = 55, health = 250000,
			mechanics = {"Summons guards", "High melee", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 8},
			tactics = "Kill guards before DPS. Tank swaps.",
			loot = {{name = "Blackstone Armor", rarity = 4}}
		},
		{
			id = 80, name = "Flamewaker Destroyer", zone = "Molten Core", level = 55, health = 200000,
			mechanics = {"Flame breath", "Summons adds", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Manage adds. Move from breath.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
	}
	
	for _, boss in ipairs(worldBossesAdditional) do
		self:RegisterEncounter(boss)
	end
	
	-- Dragons of Nightmare & Additional World Bosses
	local dragonsOfNightmare = {
		{
			id = 81, name = "Emeriss of the Talon", zone = "Feralas", level = 51, health = 150000,
			mechanics = {"Summons adds", "High damage", "Enrage"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Kill adds on spawn. High DPS.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 82, name = "Mana Furnace", zone = "Tanaris", level = 50, health = 140000,
			mechanics = {"Mana drain", "Arcane explosions", "Summons constructs"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Manage constructs. Mana management.",
			loot = {{name = "Mana Core", rarity = 3}}
		},
		{
			id = 83, name = "Hive'Ashi Worm Queen", zone = "Silithus", level = 55, health = 200000,
			mechanics = {"Summons eggs", "Poison", "Enrage"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Destroy eggs fast. Poison management.",
			loot = {{name = "Silithid Armor", rarity = 4}}
		},
		{
			id = 84, name = "Colossus of Ahn'Qiraj", zone = "Silithus", level = 55, health = 200000,
			mechanics = {"Melee attacks", "Knockback", "Enrage"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 8},
			tactics = "High tank damage. Manage knockback.",
			loot = {{name = "Silithid Armor", rarity = 4}}
		},
		{
			id = 85, name = "Shadow of Hakkar", zone = "Tanaris", level = 50, health = 140000,
			mechanics = {"Shadow damage", "Drain life", "Summons adds"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Manage adds. Heavy healing.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 86, name = "Fire Elemental Lord", zone = "Molten Core", level = 54, health = 180000,
			mechanics = {"Flame burst", "Summons adds", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Kill adds quickly. Manage burst damage.",
			loot = {{name = "Perdition's Blade", rarity = 4}}
		},
		{
			id = 87, name = "Water Elemental Lord", zone = "Blackrock", level = 54, health = 180000,
			mechanics = {"Water burst", "Flood", "Summons adds"},
			compositionRequirements = {minTanks = 1, minHealers = 3, minDPS = 6},
			tactics = "Move out of floods. Manage adds.",
			loot = {{name = "Blackstone Armor", rarity = 4}}
		},
		{
			id = 88, name = "Nightmare Dragon Spawn", zone = "Ashenvale", level = 51, health = 150000,
			mechanics = {"Summons adds", "Nightmare aura", "High damage"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Quick spawn kills. Aura damage management.",
			loot = {{name = "Pendant of the Void", rarity = 3}}
		},
		{
			id = 89, name = "Wyvern Guardian", zone = "Ashenvale", level = 50, health = 140000,
			mechanics = {"Melee attacks", "Wing buffet", "Poison"},
			compositionRequirements = {minTanks = 1, minHealers = 2, minDPS = 7},
			tactics = "Tank positioning. Avoid knockback.",
			loot = {{name = "Dragon Armor", rarity = 3}}
		},
		{
			id = 90, name = "Qiraji Brood Lord", zone = "Silithus", level = 56, health = 220000,
			mechanics = {"Summons eggs", "High melee", "Cleave"},
			compositionRequirements = {minTanks = 2, minHealers = 3, minDPS = 8},
			tactics = "Destroy eggs. Tank swaps for cleave.",
			loot = {{name = "Silithid Armor", rarity = 4}}
		},
	}
	
	for _, boss in ipairs(dragonsOfNightmare) do
		self:RegisterEncounter(boss)
	end
	
	local totalBosses = table.maxn(moltenCoreBosses) + table.maxn(blackwingBosses) + table.maxn(worldBosses) +
		table.maxn(zulfarak) + table.maxn(worldDragons) + table.maxn(blackrockSpire) +
		table.maxn(worldDragons2) + table.maxn(blackwingAdditional) + table.maxn(moltenCoreAdditional) + table.maxn(naxxramasBosses) + table.maxn(aq40Bosses) + table.maxn(worldBossesAdditional) + table.maxn(dragonsOfNightmare)
	
	InfinityUtils:Info("Registered " .. totalBosses .. " boss encounters", "Raid")
end

-- Register encounter
function EncounterDatabase:RegisterEncounter(encounterData)
	if encounterData.id then
		self.encounters[encounterData.id] = encounterData
		InfinityUtils:Info("Encounter registered: " .. (encounterData.name or "Unknown"), "Raid")
	end
end

-- Called when encounter starts
function EncounterDatabase:OnEncounterStart(encounterId, encounterName, difficultyID, numPlayers, bossIDs)
	self.currentEncounter = encounterId
	InfinityUtils:Info("Encounter started: " .. (encounterName or "Unknown"), "Raid")
	
	-- Notify subscribers
	InfinityMessaging:Publish("encounter_started", encounterId, encounterName)
end

-- Called when encounter ends
function EncounterDatabase:OnEncounterEnd(encounterId, encounterName, difficultyID, numPlayers, success, bossIDs)
	InfinityUtils:Info("Encounter ended: " .. (encounterName or "Unknown") .. " - " .. (success and "SUCCESS" or "FAILURE"), "Raid")
	
	self.currentEncounter = nil
	
	-- Notify subscribers
	InfinityMessaging:Publish("encounter_ended", encounterId, encounterName, success)
end

-- Get encounter data
function EncounterDatabase:GetEncounter(encounterId)
	return self.encounters[encounterId]
end

-- Get current encounter
function EncounterDatabase:GetCurrentEncounter()
	if self.currentEncounter then
		return self.encounters[self.currentEncounter]
	end
	return nil
end

-- Get encounter mechanics
function EncounterDatabase:GetMechanics(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if encounter then
		return encounter.mechanics or {}
	end
	return {}
end

-- Get composition requirements
function EncounterDatabase:GetCompositionRequirements(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if encounter then
		return encounter.compositionRequirements or {}
	end
	return {}
end

-- Get encounter tactics
function EncounterDatabase:GetTactics(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if encounter then
		return encounter.tactics or ""
	end
	return ""
end

-- Get encounter loot
function EncounterDatabase:GetLoot(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if encounter then
		return encounter.loot or {}
	end
	return {}
end

-- Check composition against encounter requirements
function EncounterDatabase:CheckComposition(encounterId, composition)
	local requirements = self:GetCompositionRequirements(encounterId)
	local issues = {}
	
	if requirements.minTanks and composition.tanks < requirements.minTanks then
		table.insert(issues, "Need " .. requirements.minTanks .. " tanks, have " .. composition.tanks)
	end
	
	if requirements.minHealers and composition.healers < requirements.minHealers then
		table.insert(issues, "Need " .. requirements.minHealers .. " healers, have " .. composition.healers)
	end
	
	if requirements.minDPS and composition.dps < requirements.minDPS then
		table.insert(issues, "Need " .. requirements.minDPS .. " DPS, have " .. composition.dps)
	end
	
	return #issues == 0, issues
end

-- Display encounter information
function EncounterDatabase:DisplayEncounter(encounterId)
	local encounter = self:GetEncounter(encounterId)
	
	if not encounter then
		print("Encounter not found")
		return
	end
	
	print("|cffffd700=== " .. encounter.name .. " ===|r")
	print("Zone: " .. encounter.zone)
	print("Level: " .. encounter.level)
	print("Health: " .. encounter.health .. " HP")
	
	print("\n|cffccccccMechanics:|r")
	if encounter.mechanics and #encounter.mechanics > 0 then
		for _, mechanic in ipairs(encounter.mechanics) do
			print("  • " .. mechanic)
		end
	end
	
	print("\n|cffccccccComposition Requirements:|r")
	local req = encounter.compositionRequirements
	print("  Tanks: " .. (req.minTanks or 0))
	print("  Healers: " .. (req.minHealers or 0))
	print("  DPS: " .. (req.minDPS or 0))
	
	print("\n|cffccccccTactics:|r")
	print(encounter.tactics or "No tactics available")
	
	print("\n|cffccccccLoot:|r")
	if encounter.loot and #encounter.loot > 0 then
		for _, item in ipairs(encounter.loot) do
			local rarityColor = {
				"|cff9d9d9d", -- Poor
				"|cffffffff", -- Common
				"|cff1eff00", -- Uncommon
				"|cff0070dd", -- Rare
				"|cffa335ee", -- Epic
			}
			local color = rarityColor[item.rarity + 1] or "|cffffffff"
			print("  " .. color .. item.name .. "|r")
		end
	end
end

-- Get all encounters in zone
function EncounterDatabase:GetEncountersInZone(zone)
	local zoneEncounters = {}
	
	for _, encounter in pairs(self.encounters) do
		if encounter.zone == zone then
			table.insert(zoneEncounters, encounter)
		end
	end
	
	return zoneEncounters
end

return EncounterDatabase
