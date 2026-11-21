-- Naxxramas Encounter Data
-- Bosses from the 40-man raid

local Naxxramas = {
	-- Arachnid Quarter
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
	
	-- The Plague Quarter
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
	
	-- The Military Quarter
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
	
	-- The Frost Wing
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

-- Register all Naxxramas bosses
function RegisterNaxxramasBosses(encounterDatabase)
	for _, boss in ipairs(Naxxramas) do
		encounterDatabase:RegisterEncounter(boss)
	end
	return #Naxxramas
end

return Naxxramas
