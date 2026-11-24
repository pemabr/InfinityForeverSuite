-- PluribusHive Gear Judge Engine (Sharpie's Gear Judge Suite Integration)
-- Complete real-time theorycrafting & gear evaluation suite for Warcraft Forever 1.60.1:
--   1. Context-Aware Tooltips: Exact % Upgrade/Downgrade based on class, level & active talent spec
--   2. Cap Guardian: Live Hit / Spell Hit / Defense cap tracking with below-cap drop warnings
--   3. Alt-Friendly BoE Checking (Roster): Shows which of your alts a BoE item upgrades
--   4. Bag / Vendor / Quest Upgrade Arrows: Crisp green up-arrows on bag items that upgrade you
--   5. The Laboratory: Side-by-side gear & weapon comparator with stat + cap delta breakdown
--   6. Upgrade Roadmap: Ranks Classic dungeons & raids by upgrade value with 1-click Compass nav
--   7. Talents Guide: Integrated Classic 1.60.1 leveling/raid/PvP talent templates synced to spec
--   8. Gear-Aware XP & Loot Bar (/xpbar): Live XP/hr, Rested XP, Gold/hr & upcoming bag gear look-ahead

PluribusHiveGearJudge = {
	initialized = false,
	subTab = "overview", -- overview | lab | roadmap | talents | xpbar
	labSlot = "INVTYPE_CHEST",
	labCandidateLink = nil,
	xpBarFrame = nil,
	session = {
		startedAt = 0,
		xpGained = 0,
		copperLooted = 0,
		ahValueLooted = 0,
		itemsLooted = 0,
	},
}
_G.PluribusHiveGearJudge = PluribusHiveGearJudge

-- Classic 1.60.1 EquipLoc -> Inventory Slot IDs
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
	INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder",
	INVTYPE_CLOAK = "Back", INVTYPE_CHEST = "Chest", INVTYPE_WRIST = "Wrist",
	INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs",
	INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring", INVTYPE_TRINKET = "Trinket",
	INVTYPE_WEAPON = "1H Weapon", INVTYPE_2HWEAPON = "2H Weapon",
	INVTYPE_SHIELD = "Shield / Offhand", INVTYPE_RANGED = "Ranged / Wand",
}

-- Dynamic Classic 1.60.1 Spec Profiles (Stat Weights + Stat Caps)
local SPEC_PROFILES = {
	WARRIOR = {
		Fury = {
			label = "Warrior — Fury / Arms DPS",
			caps = { hit = 6, crit = 35, defense = 0 },
			weights = { STR = 2.1, AGI = 1.4, STA = 0.6, AP = 1.0, CRIT = 22.0, HIT = 26.0, DPS = 9.0, ARMOR = 0.03 },
			talents = "17/34/0 Fury Raid (Cruelty 5, Flurry 5, Bloodthirst 1, Impale 2)",
		},
		Protection = {
			label = "Warrior — Protection Tank",
			caps = { hit = 6, defense = 440 },
			weights = { STA = 2.4, DEF = 2.8, DODGE = 18.0, PARRY = 18.0, BLOCK = 12.0, STR = 1.1, AGI = 1.2, HIT = 18.0, ARMOR = 0.14, DPS = 4.0 },
			talents = "11/5/35 Prot (Defiance 5, Shield Slam 1, Tactical Mastery 5)",
		},
	},
	PALADIN = {
		Holy = {
			label = "Paladin — Holy Healer",
			caps = { spellHit = 0 },
			weights = { INT = 1.9, HEAL = 1.6, SP = 1.2, MP5 = 4.2, SPELLCRIT = 20.0, STA = 0.7, SPI = 0.4, ARMOR = 0.04 },
			talents = "31/20/0 Holy (Divine Favor 1, Illumination 5, Blessing of Kings 1)",
		},
		Retribution = {
			label = "Paladin — Retribution / Leveling",
			caps = { hit = 6 },
			weights = { STR = 2.0, AGI = 1.2, STA = 0.9, INT = 0.6, AP = 0.9, CRIT = 20.0, HIT = 22.0, DPS = 10.0, SP = 0.5 },
			talents = "11/7/33 Retribution (Seal of Command 1, Vengeance 5, Consecration 1)",
		},
	},
	HUNTER = {
		Marksmanship = {
			label = "Hunter — Marks / BM DPS",
			caps = { hit = 9 },
			weights = { AGI = 2.4, RAP = 1.0, AP = 0.9, CRIT = 24.0, HIT = 28.0, INT = 0.5, STA = 0.6, DPS = 10.5 },
			talents = "20/31/0 Trueshot Aura (Lethal Shots 5, Mortal Shots 5, Trueshot Aura 1)",
		},
	},
	ROGUE = {
		Combat = {
			label = "Rogue — Combat Swords / Daggers",
			caps = { hit = 9 },
			weights = { AGI = 2.1, STR = 1.0, AP = 1.0, CRIT = 22.0, HIT = 27.0, STA = 0.5, DPS = 9.5 },
			talents = "19/32/0 Combat Swords (Precision 5, Blade Flurry 1, Adrenaline Rush 1)",
		},
	},
	PRIEST = {
		Holy = {
			label = "Priest — Holy / Disc Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.8, SP = 1.2, INT = 1.7, SPI = 1.4, MP5 = 4.5, STA = 0.7, SPELLCRIT = 12.0 },
			talents = "21/30/0 PI/Holy (Meditation 3, Spiritual Guidance 5, Inner Focus 1)",
		},
		Shadow = {
			label = "Priest — Shadow DPS / Leveling",
			caps = { spellHit = 16 },
			weights = { SP = 1.9, SHADOW = 1.9, SPELLHIT = 19.0, INT = 1.2, SPI = 1.0, STA = 0.8, SPELLCRIT = 13.0 },
			talents = "14/0/37 Shadow (Spirit Tap 5, Shadow Weaving 5, Shadowform 1)",
		},
	},
	SHAMAN = {
		Restoration = {
			label = "Shaman — Restoration Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.8, SP = 1.2, MP5 = 4.8, INT = 1.7, STA = 0.8, SPELLCRIT = 14.0, SPI = 0.5 },
			talents = "0/5/46 Resto (Mana Tide 1, Nature's Swiftness 1, Healing Way 3)",
		},
		Enhancement = {
			label = "Shaman — Enhancement / Leveling",
			caps = { hit = 6 },
			weights = { STR = 1.9, AGI = 1.4, INT = 0.8, STA = 1.0, AP = 0.9, CRIT = 20.0, HIT = 22.0, DPS = 9.5, SP = 0.6 },
			talents = "0/31/20 Enh/Resto (Flurry 5, Stormstrike 1, Nature's Guidance 3)",
		},
	},
	MAGE = {
		Frost = {
			label = "Mage — Frost / Fire DPS",
			caps = { spellHit = 16 },
			weights = { SP = 1.9, FROST = 1.9, FIRE = 1.8, SPELLHIT = 21.0, SPELLCRIT = 17.0, INT = 1.3, STA = 0.6, SPI = 0.4 },
			talents = "17/0/34 Winter's Chill (Ice Shards 5, Ice Barrier 1, Arcane Subtlety 2)",
		},
	},
	WARLOCK = {
		Affliction = {
			label = "Warlock — SM/Ruin & Leveling",
			caps = { spellHit = 16 },
			weights = { SP = 1.9, SHADOW = 1.9, SPELLHIT = 20.0, SPELLCRIT = 16.0, STA = 1.1, INT = 1.1, SPI = 0.4 },
			talents = "30/0/21 SM/Ruin (Shadow Mastery 5, Nightfall 2, Ruin 1)",
		},
	},
	DRUID = {
		Restoration = {
			label = "Druid — Restoration Healer",
			caps = { spellHit = 0 },
			weights = { HEAL = 1.8, SP = 1.2, INT = 1.6, SPI = 1.3, MP5 = 4.5, STA = 0.8 },
			talents = "24/0/27 Moonglow (Nature's Swiftness 1, Moonglow 3, Gift of Nature 5)",
		},
		Feral = {
			label = "Druid — Feral Cat / Bear",
			caps = { hit = 6 },
			weights = { STR = 2.0, AGI = 2.1, STA = 1.4, AP = 1.0, CRIT = 20.0, HIT = 24.0, ARMOR = 0.08, DPS = 4.0 },
			talents = "14/32/5 HotW Feral (Heart of the Wild 5, Leader of the Pack 1, Furor 5)",
		},
	},
}

-- Classic 1.60.1 Dungeon & Raid Upgrade Roadmap Database (with coords for 1-click Compass!)
local ROADMAP_SOURCES = {
	{ name = "Deadmines",          zone = "Westfall",            x = 42.6, y = 71.7, minL = 17, maxL = 24, tier = "Dungeon", highlights = { "Cruel Barb", "Defias Chest", "Smite's Hammer", "Emberstone Staff" }, ilvl = 22 },
	{ name = "Wailing Caverns",    zone = "The Barrens",         x = 46.0, y = 35.7, minL = 17, maxL = 24, tier = "Dungeon", highlights = { "Fang Set", "Crescent Staff", "Wingblade" }, ilvl = 22 },
	{ name = "Scarlet Monastery",  zone = "Tirisfal Glades",     x = 85.3, y = 32.2, minL = 30, maxL = 42, tier = "Dungeon", highlights = { "Herod's Shoulder", "Ravager", "Whitemane's Chapeau", "Hypnotic Blade" }, ilvl = 39 },
	{ name = "Zul'Farrak",         zone = "Tanaris",             x = 38.7, y = 20.0, minL = 42, maxL = 50, tier = "Dungeon", highlights = { "Jang'thraze", "Carrot on a Stick", "Big Bad Pauldrons", "Zum'rah's Vexing Cane" }, ilvl = 48 },
	{ name = "Maraudon",           zone = "Desolace",            x = 29.1, y = 62.5, minL = 45, maxL = 53, tier = "Dungeon", highlights = { "Blackstone Ring", "Thrash Blade", "Princess's Ring", "Satyr's Bow" }, ilvl = 51 },
	{ name = "Blackrock Depths",   zone = "Burning Steppes",     x = 29.4, y = 38.3, minL = 52, maxL = 60, tier = "Dungeon", highlights = { "Hand of Justice", "Savage Gladiator Chain", "Ironfoe", "Briarwood Reed" }, ilvl = 58 },
	{ name = "Stratholme",         zone = "Eastern Plaguelands", x = 31.3, y = 15.7, minL = 56, maxL = 60, tier = "Dungeon", highlights = { "Cape of the Black Baron", "Mask of the Unforgiven", "Truefaith Patterns", "Diana's Pearl" }, ilvl = 61 },
	{ name = "Scholomance",        zone = "Western Plaguelands", x = 69.4, y = 72.9, minL = 56, maxL = 60, tier = "Dungeon", highlights = { "Cadaverous Armor", "Shadowcraft / Valor", "Ancient Bone Bow", "Dark Runes" }, ilvl = 61 },
	{ name = "Upper Blackrock Spire", zone = "Burning Steppes",  x = 29.4, y = 38.3, minL = 58, maxL = 60, tier = "Dungeon", highlights = { "Dal'Rend's Set", "Truestrike Shoulders", "Blackhand's Breadth", "Reed" }, ilvl = 63 },
	{ name = "Molten Core",        zone = "Blackrock Mountain",  x = 29.4, y = 38.3, minL = 60, maxL = 60, tier = "Raid",    highlights = { "Tier 1 Sets", "Onslaught Girdle", "Choker of the Fire Lord", "Perdition's Blade" }, ilvl = 68 },
	{ name = "Blackwing Lair",     zone = "Blackrock Mountain",  x = 29.4, y = 38.3, minL = 60, maxL = 60, tier = "Raid",    highlights = { "Tier 2 Sets", "Drake Fang Talisman", "Neltharion's Tear", "Ashkandi" }, ilvl = 76 },
	{ name = "Ahn'Qiraj (AQ40)",   zone = "Silithus",            x = 28.6, y = 92.4, minL = 60, maxL = 60, tier = "Raid",    highlights = { "Tier 2.5 Sets", "Dark Edge of Insanity", "Death's Sting", "Eye of C'Thun" }, ilvl = 82 },
	{ name = "Naxxramas",          zone = "Eastern Plaguelands", x = 39.8, y = 26.2, minL = 60, maxL = 60, tier = "Raid",    highlights = { "Tier 3 Sets", "Hungering Cold", "Atiesh", "Slayer's Crest" }, ilvl = 89 },
}

-- ============================================================================
-- PROFILE DETECTION, STAT EXTRACTION & CAP GUARDIAN
-- ============================================================================
function PluribusHiveGearJudge:GetGearDB()
	local db = PluribusHive:GetDB()
	db.gearJudge = db.gearJudge or {
		specOverride = {}, -- [charName] = specKey
		altGear = {},      -- [charName] = { class, level, spec, slots = { [equipLoc] = score } }
		showXpBar = false,
	}
	return db.gearJudge
end

function PluribusHiveGearJudge:GetActiveProfile(classOverride, specOverride)
	local cls = classOverride or (PluribusHive and PluribusHive:GetPlayerClass()) or "WARRIOR"
	local classTable = SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR
	local gdb = self:GetGearDB()
	local me = PluribusHive and PluribusHive:GetPlayerShortName() or "Player"
	local chosenSpec = specOverride or (not classOverride and gdb.specOverride[me])

	if chosenSpec and classTable[chosenSpec] then
		return chosenSpec, classTable[chosenSpec]
	end

	-- Auto-detect from WoW talent tree points spent when available
	if not classOverride and GetTalentTabInfo then
		local bestTab, bestPts = nil, -1
		for tab = 1, 3 do
			local ok, name, _, pts = pcall(GetTalentTabInfo, tab)
			if ok and name and (tonumber(pts) or 0) > bestPts then
				bestPts = tonumber(pts) or 0
				bestTab = name
			end
		end
		if bestTab and bestPts > 0 then
			for k in pairs(classTable) do
				if bestTab:lower():find(k:lower(), 1, true) then
					return k, classTable[k]
				end
			end
		end
	end

	-- Default first spec for class
	for k, v in pairs(classTable) do
		return k, v
	end
end

function PluribusHiveGearJudge:ExtractItemStats(itemLinkOrID)
	local stats = {
		STR = 0, AGI = 0, STA = 0, INT = 0, SPI = 0,
		AP = 0, RAP = 0, CRIT = 0, HIT = 0,
		SP = 0, HEAL = 0, SHADOW = 0, FROST = 0, FIRE = 0,
		SPELLCRIT = 0, SPELLHIT = 0, MP5 = 0,
		DEF = 0, DODGE = 0, PARRY = 0, BLOCK = 0,
		ARMOR = 0, DPS = 0,
	}
	if not itemLinkOrID then return stats, nil, 0, 0 end

	local name, link, quality, ilvl, reqLevel, _, _, _, equipLoc = PluribusUtils:GetItemInfo(itemLinkOrID)
	local target = link or itemLinkOrID
	if GetItemStats and target then
		local ok, raw = pcall(GetItemStats, target)
		if ok and type(raw) == "table" then
			stats.STR = raw["ITEM_MOD_STRENGTH_SHORT"] or 0
			stats.AGI = raw["ITEM_MOD_AGILITY_SHORT"] or 0
			stats.STA = raw["ITEM_MOD_STAMINA_SHORT"] or 0
			stats.INT = raw["ITEM_MOD_INTELLECT_SHORT"] or 0
			stats.SPI = raw["ITEM_MOD_SPIRIT_SHORT"] or 0
			stats.AP = raw["ITEM_MOD_ATTACK_POWER_SHORT"] or 0
			stats.RAP = raw["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] or 0
			stats.CRIT = (raw["ITEM_MOD_CRIT_RATING_SHORT"] or 0) + (raw["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] or 0)
			stats.HIT = (raw["ITEM_MOD_HIT_RATING_SHORT"] or 0) + (raw["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0)
			stats.SP = (raw["ITEM_MOD_SPELL_POWER_SHORT"] or 0) + (raw["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] or 0)
			stats.HEAL = raw["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or stats.SP
			stats.SPELLCRIT = raw["ITEM_MOD_CRIT_SPELL_RATING_SHORT"] or 0
			stats.SPELLHIT = raw["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0
			stats.MP5 = raw["ITEM_MOD_POWER_REGEN0_SHORT"] or 0
			stats.DEF = raw["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
			stats.DODGE = raw["ITEM_MOD_DODGE_RATING_SHORT"] or 0
			stats.PARRY = raw["ITEM_MOD_PARRY_RATING_SHORT"] or 0
			stats.BLOCK = raw["ITEM_MOD_BLOCK_RATING_SHORT"] or 0
			stats.ARMOR = raw["RESISTANCE0_NAME"] or 0
			stats.DPS = raw["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"] or 0
		end
	end
	return stats, equipLoc, tonumber(ilvl) or 0, tonumber(reqLevel) or 0, tonumber(quality) or 1, name, link
end

-- Cap Guardian: scan all currently equipped slots to measure live Hit / Spell Hit / Defense totals
function PluribusHiveGearJudge:GetCurrentCapTotals()
	local totals = { hit = 0, spellHit = 0, defense = (UnitLevel and UnitLevel("player") or 60) * 5, crit = 0, avgIlvl = 0, equippedCount = 0 }
	if not GetInventoryItemLink then return totals end
	local ilvlSum = 0
	for slot = 1, 18 do
		if slot ~= 4 then -- skip shirt
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

-- Score an item contextually with Cap Guardian diminishing-returns awareness
function PluribusHiveGearJudge:ScoreItem(itemLinkOrID, profile, capTotals)
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
			-- Cap Guardian: if already over cap, reduce excess Hit / SpellHit / Defense value!
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

	-- Baseline item-level floor so early green/blue items without secondary stats still evaluate cleanly
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

-- Compare an item against currently equipped gear in its matching slot(s) + Cap Guardian warning
function PluribusHiveGearJudge:EvaluateItem(itemLinkOrID)
	local _, profile = self:GetActiveProfile()
	local capTotals = self:GetCurrentCapTotals()
	local cand = self:ScoreItem(itemLinkOrID, profile, capTotals)
	if not cand then return nil end

	local slotIds = EQUIP_SLOTS[cand.equipLoc]
	if not slotIds then return nil end

	local bestEqLink, bestEqEval = nil, nil
	local worstScore = nil
	for _, sId in ipairs(slotIds) do
		local eqLink = GetInventoryItemLink and GetInventoryItemLink("player", sId) or nil
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

	local eqScore = worstScore or 0
	local delta = cand.score - eqScore
	local pct
	if eqScore <= 0 then
		pct = cand.score > 0 and 100 or 0
	else
		pct = math.floor(((delta / eqScore) * 100) * 10 + 0.5) / 10
	end

	-- Cap Guardian drop warning
	local capWarning = nil
	local caps = profile.caps or {}
	if bestEqEval then
		local eqSt = bestEqEval.stats or {}
		local cSt = cand.stats or {}
		if caps.hit and caps.hit > 0 and capTotals.hit >= caps.hit and (capTotals.hit - (eqSt.HIT or 0) + (cSt.HIT or 0)) < caps.hit then
			capWarning = string.format("Drops Hit below %d%% cap!", caps.hit)
		elseif caps.spellHit and caps.spellHit > 0 and capTotals.spellHit >= caps.spellHit and (capTotals.spellHit - (eqSt.SPELLHIT or 0) + (cSt.SPELLHIT or 0)) < caps.spellHit then
			capWarning = string.format("Drops Spell Hit below %d%% cap!", caps.spellHit)
		elseif caps.defense and caps.defense > 0 and capTotals.defense >= caps.defense and (capTotals.defense - (eqSt.DEF or 0) + (cSt.DEF or 0)) < caps.defense then
			capWarning = string.format("Drops Defense below %d cap!", caps.defense)
		end
	end

	-- Check if item is identical to equipped
	local isEquipped = false
	if cand.link and bestEqLink and cand.link == bestEqLink then
		isEquipped = true
	end

	return {
		candidate = cand,
		equipped = bestEqEval,
		equippedLink = bestEqLink,
		delta = delta,
		pct = pct,
		isUpgrade = (not isEquipped) and (pct >= 0.5),
		isEquipped = isEquipped,
		capWarning = capWarning,
	}
end

-- Save current character's slot scores for Alt-Friendly BoE tooltips (SGJ Roster)
function PluribusHiveGearJudge:SnapshotMyGearForAlts()
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

function PluribusHiveGearJudge:GetAltUpgradesForItem(itemLinkOrID)
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
-- BAG UPGRADE ARROWS & LOOK-AHEAD SCANNER
-- ============================================================================
function PluribusHiveGearJudge:GetUpcomingBagUpgrades()
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

function PluribusHiveGearJudge:RefreshBagUpgradeArrows()
	local myLvl = UnitLevel and UnitLevel("player") or 60
	for bagIdx = 1, 5 do
		local cf = _G["ContainerFrame" .. bagIdx]
		if cf and cf:IsShown() then
			local bagID = cf.GetID and cf:GetID() or (bagIdx - 1)
			local size = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID)) or (GetContainerNumSlots and GetContainerNumSlots(bagID)) or 0
			for btnIdx = 1, size do
				local btn = _G["ContainerFrame" .. bagIdx .. "Item" .. btnIdx]
				if btn then
					if not btn._plbUpgArrow then
						local arr = btn:CreateTexture(nil, "OVERLAY")
						arr:SetSize(14, 14)
						arr:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
						arr:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
						arr:SetVertexColor(0.22, 0.96, 0.45, 1)
						arr:Hide()
						btn._plbUpgArrow = arr
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
					btn._plbUpgArrow:SetShown(show)
				end
			end
		end
	end
end

-- ============================================================================
-- GEAR-AWARE XP & LOOT BAR HUD (/xpbar)
-- ============================================================================
function PluribusHiveGearJudge:GetSessionRates()
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

function PluribusHiveGearJudge:ToggleXPBar(forceShow)
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
			PluribusHiveGearJudge:RefreshXPBar()
		end)
		self.xpBarFrame = f
	end

	local show = (forceShow ~= nil) and forceShow or (not self.xpBarFrame:IsVisible())
	gdb.showXpBar = show
	self.xpBarFrame:SetShown(show)
	if show then self:RefreshXPBar() end
end

function PluribusHiveGearJudge:RefreshXPBar()
	local f = self.xpBarFrame
	if not f or not f:IsVisible() then return end
	local r = self:GetSessionRates()
	local ttlTxt = r.ttlMin and (r.ttlMin .. "m to ding") or "—"
	f.bar:SetBarData(r.pct,
		string.format("Lv %d  ·  %.1f%% XP  (Rested: %d)", UnitLevel and UnitLevel("player") or 60, r.pct, r.rested),
		string.format("%dk XP/h · %s", math.floor(r.xpHr / 1000), ttlTxt),
		0.48, 0.32, 0.92)

	local up = self:GetUpcomingBagUpgrades()
	local nextTxt = up[1] and string.format("|cff4ade80Next Bag Gear: Lv%d %s (+%.1f%%)|r", up[1].reqLevel, tostring(up[1].name):sub(1, 18), up[1].pct) or "No locked upgrades in bags"
	f.sub:SetText(string.format("|cfffbbf24Farm: %s/h|r  ·  %s", PluribusUtils:FormatGold(r.goldHr), nextTxt))
end

-- ============================================================================
-- MAINFRAME EMBEDDED UI: GEAR JUDGE (Overview | Lab | Roadmap | Talents | XP)
-- ============================================================================
function PluribusHiveGearJudge:RenderPanel(parent, width, height, onRefresh)
	local UI = _G.PluribusUIFramework
	if not UI or not parent then return end
	local w = width or 726
	local h = height or 444
	local specKey, profile = self:GetActiveProfile()
	local caps = self:GetCurrentCapTotals()
	local cls = PluribusHive:GetPlayerClass()

	-- Graphical Header Banner with Spec Switcher Dropdown
	local banner = UI:CreateBannerCard(parent, w, 54, "Interface\\Icons\\INV_Misc_Gear_01",
		"|cfffbbf24Gear Judge & Cap Guardian|r  |cff94a3b8(" .. (profile.label or specKey) .. ")|r",
		string.format("Avg iLvl: |cff38bdf8%d|r  ·  Hit: |cff4ade80%d%%|r  ·  Spell Hit: |cff38bdf8%d%%|r  ·  Defense: |cfffbbf24%d|r",
			caps.avgIlvl or 0, caps.hit or 0, caps.spellHit or 0, caps.defense or 300),
		0.92, 0.72, 0.22)
	banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)

	local specOpts = {}
	for k, v in pairs(SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR) do
		table.insert(specOpts, { value = k, label = k })
	end
	table.sort(specOpts, function(a, b) return a.label < b.label end)

	local specDrop = UI:CreateFlatDropdown(banner, 146, 24, specOpts, specKey, function(val)
		local gdb = PluribusHiveGearJudge:GetGearDB()
		gdb.specOverride[PluribusHive:GetPlayerShortName()] = val
		PluribusHiveGearJudge:SnapshotMyGearForAlts()
		if onRefresh then onRefresh() end
	end, "Spec...")
	specDrop:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	-- 5 clean subtabs
	local defs = {
		{ id = "overview", label = "Cap Guardian", w = 114 },
		{ id = "lab",      label = "The Laboratory", w = 122 },
		{ id = "roadmap",  label = "Upgrade Roadmap", w = 132 },
		{ id = "talents",  label = "Talents Guide", w = 114 },
		{ id = "xpbar",    label = "XP & Loot Bar", w = 116 },
	}
	local prevBtn = nil
	for _, d in ipairs(defs) do
		local b = UI:CreateButton(parent, d.label, d.w, 24, function()
			PluribusHiveGearJudge.subTab = d.id
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

	local scroll = UI:CreateScrollFrame(parent, "PluribusGearJudgeScroll", w, h - 104)
	scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -40)
	local y = -2

	if self.subTab == "overview" then
		-- Cap Guardian visual bars
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

		-- Active Stat Weights Card
		local wParts = {}
		for k, v in pairs(profile.weights or {}) do
			table.insert(wParts, string.format("|cff38bdf8%s|r %.1f", k, v))
		end
		table.sort(wParts)
		local wCard = UI:CreateCard(scroll.content, w - 28, 54, "Dynamic Stat Weights (" .. (profile.label or specKey) .. ")")
		wCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y - 4)
		local wLbl = UI:CreateLabel(wCard, table.concat(wParts, "  ·  "), 0.85, 0.92, 0.98, "GameFontHighlightSmall")
		wLbl:SetPoint("TOPLEFT", wCard, "TOPLEFT", 10, -24)
		wLbl:SetWidth(w - 48)
		y = y - 66

		-- Equipped Gear Score Breakdown + Weakest Slots to Upgrade Next
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

		local sHdr = UI:CreateLabel(scroll.content, "|cfffbbf24Priority Upgrade Slots (Lowest Score First — Click to Open in Lab):|r")
		sHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 20

		for idx, item in ipairs(eqList) do
			local row = UI:CreateListRow(scroll.content, w - 28, 34, idx, function()
				PluribusHiveGearJudge.labSlot = item.ev.equipLoc
				PluribusHiveGearJudge.subTab = "lab"
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
		-- THE LABORATORY: Side-by-Side Equipped vs Bag/Candidate Comparator
		local slotOpts = {}
		for k, lbl in pairs(SLOT_LABELS) do
			table.insert(slotOpts, { value = k, label = lbl })
		end
		table.sort(slotOpts, function(a, b) return a.label < b.label end)

		local sDrop = UI:CreateFlatDropdown(scroll.content, 170, 24, slotOpts, self.labSlot, function(v)
			PluribusHiveGearJudge.labSlot = v
			PluribusHiveGearJudge.labCandidateLink = nil
			if onRefresh then onRefresh() end
		end, "Pick Slot...")
		sDrop:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

		-- Gather bag items matching selected slot
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
				PluribusHiveGearJudge.labCandidateLink = v ~= "" and v or nil
				if onRefresh then onRefresh() end
			end,
			"Compare Against Bag Item...")
		cDrop:SetPoint("LEFT", sDrop, "RIGHT", 8, 0)
		y = y - 34

		local sIds = EQUIP_SLOTS[self.labSlot] or { 5 }
		local eqLink = GetInventoryItemLink and GetInventoryItemLink("player", sIds[1]) or nil
		local eqEval = eqLink and self:ScoreItem(eqLink, profile, caps) or nil
		local candEval = self.labCandidateLink and self:EvaluateItem(self.labCandidateLink) or nil

		local halfW = math.floor((w - 36) / 2)
		local leftCard = UI:CreateCard(scroll.content, halfW, 180, "Currently Equipped")
		leftCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		local lTxt = eqEval
			and string.format("%s\n\n|cff38bdf8Judge Score: %.1f|r\niLvl: %d\nStr %d · Agi %d · Sta %d · Int %d\nSP %d · AP %d · Hit %d%% · Crit %d%%",
				eqLink or "", eqEval.score, eqEval.ilvl, eqEval.stats.STR, eqEval.stats.AGI, eqEval.stats.STA, eqEval.stats.INT, eqEval.stats.SP, eqEval.stats.AP, eqEval.stats.HIT, eqEval.stats.CRIT)
			or "Empty Slot (Score: 0)"
		local lLbl = UI:CreateLabel(leftCard, lTxt, 0.88, 0.93, 0.98)
		lLbl:SetPoint("TOPLEFT", leftCard, "TOPLEFT", 10, -30)
		lLbl:SetWidth(halfW - 20)

		local rightCard = UI:CreateCard(scroll.content, halfW, 180, "Laboratory Candidate")
		rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
		local rTxt
		if candEval and candEval.candidate then
			local c = candEval.candidate
			local vCol = candEval.pct >= 0 and "|cff4ade80+" or "|cfff87171"
			local warn = candEval.capWarning and ("\n|cfffbbf24WARN: " .. candEval.capWarning .. "|r") or ""
			rTxt = string.format("%s\n\n%s%.1f%% (%+.1f score)|r%s\niLvl: %d\nStr %d · Agi %d · Sta %d · Int %d\nSP %d · AP %d · Hit %d%% · Crit %d%%",
				c.link or c.name or "", vCol, candEval.pct, candEval.delta, warn, c.ilvl, c.stats.STR, c.stats.AGI, c.stats.STA, c.stats.INT, c.stats.SP, c.stats.AP, c.stats.HIT, c.stats.CRIT)
		else
			rTxt = "Select any matching item from your bags in the dropdown above to simulate the exact stat & Cap Guardian impact!"
		end
		local rLbl = UI:CreateLabel(rightCard, rTxt, 0.88, 0.93, 0.98)
		rLbl:SetPoint("TOPLEFT", rightCard, "TOPLEFT", 10, -30)
		rLbl:SetWidth(halfW - 20)
		y = y - 190

	elseif self.subTab == "roadmap" then
		-- UPGRADE ROADMAP: Personalized Dungeon & Raid Leaderboard with 1-click Compass
		local myLvl = UnitLevel and UnitLevel("player") or 60
		local myIlvl = caps.avgIlvl or math.max(10, myLvl)
		local ranked = {}
		for _, src in ipairs(ROADMAP_SOURCES) do
			local lvlFit = (myLvl >= src.minL - 4 and myLvl <= src.maxL + 8) and 1.25 or 0.55
			local gain = math.max(0, src.ilvl - myIlvl + 8) * lvlFit
			table.insert(ranked, { src = src, score = math.floor(gain * 10) / 10 })
		end
		table.sort(ranked, function(a, b) return a.score > b.score end)

		for idx, r in ipairs(ranked) do
			local s = r.src
			local row = UI:CreateListRow(scroll.content, w - 28, 44, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)

			local ic = s.tier == "Raid" and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_Key_14"
			local badge = UI:CreateIconBadge(row, ic, 32, s.tier == "Raid" and 0.92 or 0.22, s.tier == "Raid" and 0.62 or 0.74, s.tier == "Raid" and 0.18 or 0.97)
			badge:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, string.format("|cfffbbf24#%d %s|r |cff94a3b8(%s · Lv %d-%d · ~iLvl %d)|r  |cff4ade80+%.0f Upgrade Index|r",
				idx, s.name, s.tier, s.minL, s.maxL, s.ilvl, r.score))
			l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)

			local l2 = UI:CreateLabel(row, "Key Upgrades: " .. table.concat(s.highlights, ", "), 0.74, 0.84, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

			local navBtn = UI:CreateButton(row, "Set Compass", 92, 22, function()
				if _G.PluribusNavigationUI then
					_G.PluribusNavigationUI:SetWaypoint(s.name, s.zone, s.x, s.y)
				end
			end, true)
			navBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 46
		end

	elseif self.subTab == "talents" then
		-- TALENTS GUIDE: Synced to active class & Gear Judge stat weights
		local tCard = UI:CreateBannerCard(scroll.content, w - 28, 62, "Interface\\Icons\\Ability_Marksmanship",
			"|cff38bdf8Recommended Build for " .. (profile.label or specKey) .. "|r",
			profile.talents or "Standard Classic 1.60.1 Raid / Leveling Build",
			0.22, 0.74, 0.97)
		tCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		y = y - 70

		local allSpecs = SPEC_PROFILES[cls] or SPEC_PROFILES.WARRIOR
		for sKey, sDef in pairs(allSpecs) do
			local card = UI:CreateCard(scroll.content, w - 28, 62, sDef.label)
			card:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			local lbl = UI:CreateLabel(card, "|cfffbbf24Template:|r " .. tostring(sDef.talents), 0.86, 0.92, 0.98)
			lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -28)
			local useBtn = UI:CreateButton(card, sKey == specKey and "Active Spec" or "Use Profile", 102, 22, function()
				local gdb = PluribusHiveGearJudge:GetGearDB()
				gdb.specOverride[PluribusHive:GetPlayerShortName()] = sKey
				if onRefresh then onRefresh() end
			end, sKey == specKey)
			useBtn:SetPoint("RIGHT", card, "RIGHT", -10, -4)
			y = y - 68
		end

	else
		-- GEAR-AWARE XP & LOOT BAR CONTROLS + BAG LOOK-AHEAD
		local r = self:GetSessionRates()
		local toggleBtn = UI:CreateButton(scroll.content, (self.xpBarFrame and self.xpBarFrame:IsVisible()) and "Hide Floating XP & Farm Bar" or "Show Floating XP & Farm Bar (/xpbar)", 280, 26, function()
			PluribusHiveGearJudge:ToggleXPBar()
			if onRefresh then onRefresh() end
		end, true)
		toggleBtn:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		y = y - 36

		local statCard = UI:CreateCard(scroll.content, w - 28, 76, "Live Session XP & Loot Tracker")
		statCard:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
		local sTxt = string.format("XP Progress: |cff38bdf8%.1f%%|r (%d/%d · Rested %d)  ·  Rate: |cff4ade80%dk XP/hr|r\nLooted Gold + AH Value: |cfffbbf24%s/hr|r  ·  Items Looted: %d",
			r.pct, r.curXp, r.maxXp, r.rested, math.floor(r.xpHr / 1000), PluribusUtils:FormatGold(r.goldHr), self.session.itemsLooted or 0)
		local sLbl = UI:CreateLabel(statCard, sTxt, 0.88, 0.94, 0.98)
		sLbl:SetPoint("TOPLEFT", statCard, "TOPLEFT", 10, -28)
		y = y - 84

		local up = self:GetUpcomingBagUpgrades()
		local uHdr = UI:CreateLabel(scroll.content, "|cff4ade80Upcoming Bag Upgrades Look-Ahead (" .. #up .. "):|r")
		uHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
		y = y - 20
		for idx, it in ipairs(up) do
			local row = UI:CreateListRow(scroll.content, w - 28, 30, idx)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 2, y)
			local l1 = UI:CreateLabel(row, string.format("Unlock at |cfffbbf24Lv %d|r — %s  |cff4ade80+%.1f%% Upgrade|r", it.reqLevel, it.link or it.name, it.pct))
			l1:SetPoint("LEFT", row, "LEFT", 8, 0)
			y = y - 32
		end
		if #up == 0 then
			local em = UI:CreateLabel(scroll.content, "No higher-level upgrades waiting in your bags right now. Any equippable bag upgrades for your current level show a green up-arrow automatically!", 0.70, 0.80, 0.90)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y)
			em:SetWidth(w - 36)
		end
	end

	scroll.content:SetHeight(math.max(300, math.abs(y) + 14))
end

function PluribusHiveGearJudge:Initialize()
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
			PluribusHiveGearJudge:SnapshotMyGearForAlts()
			if PluribusHiveGearJudge:GetGearDB().showXpBar then
				PluribusHiveGearJudge:ToggleXPBar(true)
			end
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			PluribusHiveGearJudge:SnapshotMyGearForAlts()
			PluribusHiveGearJudge:RefreshBagUpgradeArrows()
		elseif event == "BAG_UPDATE_DELAYED" then
			PluribusHiveGearJudge:RefreshBagUpgradeArrows()
		elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and type(arg1) == "string" then
			local xp = tonumber(arg1:match("(%d+)%s+experience")) or tonumber(arg1:match("(%d+)")) or 0
			PluribusHiveGearJudge.session.xpGained = (PluribusHiveGearJudge.session.xpGained or 0) + xp
		elseif event == "QUEST_TURNED_IN" then
			local xp = tonumber(arg2) or 0
			PluribusHiveGearJudge.session.xpGained = (PluribusHiveGearJudge.session.xpGained or 0) + xp
		elseif event == "CHAT_MSG_MONEY" and type(arg1) == "string" then
			local g = tonumber(arg1:match("(%d+)%s*Gold")) or 0
			local s = tonumber(arg1:match("(%d+)%s*Silver")) or 0
			local c = tonumber(arg1:match("(%d+)%s*Copper")) or 0
			PluribusHiveGearJudge.session.copperLooted = (PluribusHiveGearJudge.session.copperLooted or 0) + g * 10000 + s * 100 + c
		elseif event == "CHAT_MSG_LOOT" and type(arg1) == "string" then
			local id = tonumber(arg1:match("item:(%d+)"))
			if id then
				local qty = tonumber(arg1:match("x(%d+)")) or 1
				PluribusHiveGearJudge.session.itemsLooted = (PluribusHiveGearJudge.session.itemsLooted or 0) + qty
				if _G.PluribusHiveAuction and _G.PluribusHiveAuction.GetPrice then
					local p = _G.PluribusHiveAuction:GetPrice(id)
					if p and p.copper and p.copper > 0 then
						PluribusHiveGearJudge.session.ahValueLooted = (PluribusHiveGearJudge.session.ahValueLooted or 0) + (p.copper * qty)
					end
				end
			end
		end
	end)

	-- Hook native bag updates so green upgrade arrows refresh automatically
	if hooksecurefunc and _G.ContainerFrame_Update then
		pcall(hooksecurefunc, "ContainerFrame_Update", function()
			PluribusHiveGearJudge:RefreshBagUpgradeArrows()
		end)
	end
end

return PluribusHiveGearJudge
