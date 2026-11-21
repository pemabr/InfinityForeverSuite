-- If we are on a SoD realm, ignore everything in this file
if C_Seasons and C_Seasons.GetActiveSeason and C_Seasons.GetActiveSeason() == 2 then return end

-----------------------------------------------------------------------
-- Upvalued Lua API.
-----------------------------------------------------------------------
local _G = getfenv(0)
local string = _G.string
local format = string.format

-- WoW

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local addonname, private = ...
local AtlasLoot = _G.AtlasLoot
local data = AtlasLoot.ItemDB:Add(addonname, 1, AtlasLoot.CLASSIC_VERSION_NUM)

local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales

local NORMAL_DIFF = data:AddDifficulty(AL["Normal"], "n", 1, nil, true)
local ALLIANCE_DIFF
local HORDE_DIFF
local LOAD_DIFF
if UnitFactionGroup("player") == "Horde" then
	HORDE_DIFF = data:AddDifficulty(FACTION_HORDE, "horde", nil, 1)
	ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE, "alliance", nil, 1)
	LOAD_DIFF = HORDE_DIFF
else
	ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE, "alliance", nil, 1)
	HORDE_DIFF = data:AddDifficulty(FACTION_HORDE, "horde", nil, 1)
	LOAD_DIFF = ALLIANCE_DIFF
end

local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")
local SET_ITTYPE = data:AddItemTableType("Set", "Item")
local ICON_ITTYPE = data:AddItemTableType("Dummy")

local QUEST_EXTRA_ITTYPE = data:AddExtraItemTableType("Quest")
local PRICE_EXTRA_ITTYPE = data:AddExtraItemTableType("Price")
local SET_EXTRA_ITTYPE = data:AddExtraItemTableType("Set")

local PVP_CONTENT = data:AddContentType(AL["Battlegrounds"], ATLASLOOT_PVP_COLOR)
local GENERAL_CONTENT = data:AddContentType(GENERAL, ATLASLOOT_RAID40_COLOR)
local FOREVER_PVP_CONTENT = data:AddContentType("Forever", { 0.30, 0.50, 0.70, 1 })

local HORDE, ALLIANCE, RANK_FORMAT = "Horde", "Alliance", AL["|cff33ff99Rank:|r %s"]
local GetRankName, GetRankIcon = AtlasLoot.Data.Requirements.GetPvPRankName, AtlasLoot.Data.Requirements.GetPvPRankIcon
local PVP_RANKS = {
	name = AL["PvP Ranks"],
	TableType = ICON_ITTYPE,
	ExtraList = true,
	[NORMAL_DIFF] = {
		{ 1,  136782,          FACTION_HORDE },
		{ 2,  GetRankIcon(1),  GetRankName(1, HORDE),     format(RANK_FORMAT, 1) },
		{ 3,  GetRankIcon(2),  GetRankName(2, HORDE),     format(RANK_FORMAT, 2) },
		{ 4,  GetRankIcon(3),  GetRankName(3, HORDE),     format(RANK_FORMAT, 3) },
		{ 5,  GetRankIcon(4),  GetRankName(4, HORDE),     format(RANK_FORMAT, 4) },
		{ 6,  GetRankIcon(5),  GetRankName(5, HORDE),     format(RANK_FORMAT, 5) },
		{ 7,  GetRankIcon(6),  GetRankName(6, HORDE),     format(RANK_FORMAT, 6) },
		{ 8,  GetRankIcon(7),  GetRankName(7, HORDE),     format(RANK_FORMAT, 7) },
		{ 9,  GetRankIcon(8),  GetRankName(8, HORDE),     format(RANK_FORMAT, 8) },
		{ 10, GetRankIcon(9),  GetRankName(9, HORDE),     format(RANK_FORMAT, 9) },
		{ 11, GetRankIcon(10), GetRankName(10, HORDE),    format(RANK_FORMAT, 10) },
		{ 12, GetRankIcon(11), GetRankName(11, HORDE),    format(RANK_FORMAT, 11) },
		{ 13, GetRankIcon(12), GetRankName(12, HORDE),    format(RANK_FORMAT, 12) },
		{ 14, GetRankIcon(13), GetRankName(13, HORDE),    format(RANK_FORMAT, 13) },
		{ 15, GetRankIcon(14), GetRankName(14, HORDE),    format(RANK_FORMAT, 14) },
		{ 16, 136781,          FACTION_ALLIANCE },
		{ 17, GetRankIcon(1),  GetRankName(1, ALLIANCE),  format(RANK_FORMAT, 1) },
		{ 18, GetRankIcon(2),  GetRankName(2, ALLIANCE),  format(RANK_FORMAT, 2) },
		{ 19, GetRankIcon(3),  GetRankName(3, ALLIANCE),  format(RANK_FORMAT, 3) },
		{ 20, GetRankIcon(4),  GetRankName(4, ALLIANCE),  format(RANK_FORMAT, 4) },
		{ 21, GetRankIcon(5),  GetRankName(5, ALLIANCE),  format(RANK_FORMAT, 5) },
		{ 22, GetRankIcon(6),  GetRankName(6, ALLIANCE),  format(RANK_FORMAT, 6) },
		{ 23, GetRankIcon(7),  GetRankName(7, ALLIANCE),  format(RANK_FORMAT, 7) },
		{ 24, GetRankIcon(8),  GetRankName(8, ALLIANCE),  format(RANK_FORMAT, 8) },
		{ 25, GetRankIcon(9),  GetRankName(9, ALLIANCE),  format(RANK_FORMAT, 9) },
		{ 26, GetRankIcon(10), GetRankName(10, ALLIANCE), format(RANK_FORMAT, 10) },
		{ 27, GetRankIcon(11), GetRankName(11, ALLIANCE), format(RANK_FORMAT, 11) },
		{ 28, GetRankIcon(12), GetRankName(12, ALLIANCE), format(RANK_FORMAT, 12) },
		{ 29, GetRankIcon(13), GetRankName(13, ALLIANCE), format(RANK_FORMAT, 13) },
		{ 30, GetRankIcon(14), GetRankName(14, ALLIANCE), format(RANK_FORMAT, 14) },
	},
}

--[[
0 - Unknown
1 - Hated
2 - Hostile
3 - Unfriendly
4 - Neutral
5 - Friendly
6 - Honored
7 - Revered
8 - Exalted
]] --

data["AlteracValley"] = {
	MapID = 2597,
	AtlasMapID = "AlteracValley",
	ContentType = PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2.5,
	items = {
		{ -- AVRepExalted
			name = _G["FACTION_STANDING_LABEL8"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f730rep8" },

				{ 2,  19312 }, -- Lei of the Lifegiver
				{ 3,  19315 }, -- Therazane's Touch
				{ 4,  19308 }, -- Tome of Arcane Domination
				{ 5,  19311 }, -- Tome of Fiery Arcana
				{ 6,  19309 }, -- Tome of Shadow Force
				{ 7,  19310 }, -- Tome of the Ice Lord
				{ 8,  19325 }, -- Don Julio's Band
				{ 9,  21563 }, -- Don Rodrigo's Band
				{ 10, 19321 }, -- The Immovable Object
				{ 11, 19324 }, -- The Lobotomizer
				{ 12, 19323 }, -- The Unstoppable Force

				{ 17, 19030 }, -- Stormpike Battle Charger
			},
			[HORDE_DIFF] = {
				{ 1,  "f729rep8" },

				{ 2,  19312 }, -- Lei of the Lifegiver
				{ 3,  19315 }, -- Therazane's Touch
				{ 4,  19308 }, -- Tome of Arcane Domination
				{ 5,  19311 }, -- Tome of Fiery Arcana
				{ 6,  19309 }, -- Tome of Shadow Force
				{ 7,  19310 }, -- Tome of the Ice Lord
				{ 8,  19325 }, -- Don Julio's Band
				{ 9,  21563 }, -- Don Rodrigo's Band
				{ 10, 19321 }, -- The Immovable Object
				{ 11, 19324 }, -- The Lobotomizer
				{ 12, 19323 }, -- The Unstoppable Force

				{ 17, 19029 }, -- Horn of the Frostwolf Howler
			},
		},
		{ -- AVRepRevered
			name = _G["FACTION_STANDING_LABEL7"],
			[ALLIANCE_DIFF] = {
				{ 1, "f730rep7" },
				{ 2, 19045 }, -- Stormpike Battle Standard
				{ 3, 19320 }, -- Gnoll Skin Bandolier
				{ 4, 19319 }, -- Harpy Hide Quiver
				{ 5, 19100 }, -- Electrified Dagger
				{ 6, 19104 }, -- Stormstrike Hammer
				{ 7, 19102 }, -- Crackling Staff
			},
			[HORDE_DIFF] = {
				{ 1, "f729rep7" },
				{ 2, 19046 }, -- Frostwolf Battle Standard
				{ 3, 19320 }, -- Gnoll Skin Bandolier
				{ 4, 19319 }, -- Harpy Hide Quiver
				{ 5, 19099 }, -- Glacial Blade
				{ 6, 19103 }, -- Frostbite
				{ 7, 19101 }, -- Whiteout Staff
			},
		},
		{ -- AVRepHonored
			name = _G["FACTION_STANDING_LABEL6"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f730rep6" },
				{ 2,  19098 }, -- Stormpike Sage's Pendant
				{ 3,  19097 }, -- Stormpike Soldier's Pendant
				{ 4,  19086 }, -- Stormpike Sage's Cloak
				{ 5,  19084 }, -- Stormpike Soldier's Cloak
				{ 6,  19094 }, -- Stormpike Cloth Girdle
				{ 7,  19093 }, -- Stormpike Leather Girdle
				{ 8,  19092 }, -- Stormpike Mail Girdle
				{ 9,  19091 }, -- Stormpike Plate Girdle
				{ 17, 19316 }, -- Ice Threaded Arrow
				{ 18, 19317 }, -- Ice Threaded Bullet
				{ 19, 19301 }, -- Alterac Manna Biscuit
				{ 20, 17348 }, -- Major Healing Draught
				{ 21, 17351 }, -- Major Mana Draught
			},
			[HORDE_DIFF] = {
				{ 1,  "f729rep6" },
				{ 2,  19096 }, -- Frostwolf Advisor's Pendant
				{ 3,  19095 }, -- Frostwolf Legionnaire's Pendant
				{ 4,  19085 }, -- Frostwolf Advisor's Cloak
				{ 5,  19083 }, -- Frostwolf Legionnaire's Cloak
				{ 6,  19090 }, -- Frostwolf Cloth Belt
				{ 7,  19089 }, -- Frostwolf Leather Belt
				{ 8,  19088 }, -- Frostwolf Mail Belt
				{ 9,  19087 }, -- Frostwolf Plate Belt
				{ 17, 19316 }, -- Ice Threaded Arrow
				{ 18, 19317 }, -- Ice Threaded Bullet
				{ 19, 19301 }, -- Alterac Manna Biscuit
				{ 20, 17348 }, -- Major Healing Draught
				{ 21, 17351 }, -- Major Mana Draught
			},
		},
		{ -- AVRepFriendly
			name = _G["FACTION_STANDING_LABEL5"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f730rep5" },
				{ 2,  19318 }, -- Bottled Alterac Spring Water
				{ 3,  19307 }, -- Alterac Heavy Runecloth Bandage
				{ 4,  17349 }, -- Superior Healing Draught
				{ 5,  17352 }, -- Superior Mana Draught
				{ 17, 19032 }, -- Stormpike Battle Tabard
			},
			[HORDE_DIFF] = {
				{ 1,  "f729rep5" },
				{ 2,  19318 }, --  Spring Water
				{ 3,  19307 }, -- Alterac Heavy Runecloth Bandage
				{ 4,  17349 }, -- Superior Healing Draught
				{ 5,  17352 }, -- Superior Mana Draught
				{ 17, 19031 }, -- Frostwolf Battle Tabard
			},
		},
		PVP_RANKS,
	},
}

data["WarsongGulch"] = {
	MapID = 3277,
	AtlasMapID = "WarsongGulch",
	ContentType = PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2.5,
	items = {
		{ -- WSGRepExalted
			name = _G["FACTION_STANDING_LABEL8"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f890rep8" },
				{ 2,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepExalted4049
				{ 3,  19597 },                 -- Dryad's Wrist Bindings
				{ 4,  19590 },                 -- Forest Stalker's Bracers
				{ 5,  19584 },                 -- Windtalker's Wristguards
				{ 6,  19581 },                 -- Berserker Bracers
				{ 8,  "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepExalted5059
				{ 9,  19596 },                 -- Dryad's Wrist Bindings
				{ 10, 19589 },                 -- Forest Stalker's Bracers
				{ 11, 19583 },                 -- Windtalker's Wristguards
				{ 12, 19580 },                 -- Berserker Bracers
				{ 17, "INV_Box_01", nil, "60",      nil }, -- WSGRepExalted60
				{ 18, 19595 },                 -- Dryad's Wrist Bindings
				{ 19, 19587 },                 -- Forest Stalker's Bracers
				{ 20, 19582 },                 -- Windtalker's Wristguards
				{ 21, 19578 },                 -- Berserker Bracers
				{ 22, 22752 },                 -- Sentinel's Silk Leggings
				{ 23, 22749 },                 -- Sentinel's Leather Pants
				{ 24, 22750 },                 -- Sentinel's Lizardhide Pants
				{ 25, 22748 },                 -- Sentinel's Chain Leggings
				{ 26, 22753 },                 -- Sentinel's Lamellar Legguards
				{ 27, 22672 },                 -- Sentinel's Plate Legguards
				{ 28, 19506 },                 -- Silverwing Battle Tabard
			},
			[HORDE_DIFF] = {
				{ 1,  "f889rep8" },
				{ 2,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepExalted4049
				{ 3,  19597 },                 -- Dryad's Wrist Bindings
				{ 4,  19590 },                 -- Forest Stalker's Bracers
				{ 5,  19584 },                 -- Windtalker's Wristguards
				{ 6,  19581 },                 -- Berserker Bracers
				{ 8,  "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepExalted5059
				{ 9,  19596 },                 -- Dryad's Wrist Bindings
				{ 10, 19589 },                 -- Forest Stalker's Bracers
				{ 11, 19583 },                 -- Windtalker's Wristguards
				{ 12, 19580 },                 -- Berserker Bracers
				{ 17, "INV_Box_01", nil, "60",      nil }, -- WSGRepExalted60
				{ 18, 19595 },                 -- Dryad's Wrist Bindings
				{ 19, 19587 },                 -- Forest Stalker's Bracers
				{ 20, 19582 },                 -- Windtalker's Wristguards
				{ 21, 19578 },                 -- Berserker Bracers
				{ 22, 22747 },                 -- Outrider's Silk Leggings
				{ 23, 22740 },                 -- Outrider's Leather Pants
				{ 24, 22741 },                 -- Outrider's Lizardhide Pants
				{ 25, 22673 },                 -- Outrider's Chain Leggings
				{ 26, 22676 },                 -- Outrider's Mail Leggings
				{ 27, 22651 },                 -- Outrider's Plate Legguards
				{ 28, 19505 },                 -- Warsong Battle Tabard
			},
		},
		{ -- WSGRepRevered
			name = _G["FACTION_STANDING_LABEL7"],
			[ALLIANCE_DIFF] = {
				{ 1,   "f890rep7" },
				{ 2,   "INV_Box_01", nil, "10 - 19", nil }, -- WSGRepRevered1019
				{ 3,   20438 },                 -- Outrunner's Bow
				{ 4,   20443 },                 -- Sentinel's Blade
				{ 5,   20440 },                 -- Protector's Sword
				{ 6,   20434 },                 -- Lorekeeper's Staff
				{ 8,   "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepRevered2029
				{ 9,   19565 },                 -- Outrunner's Bow
				{ 10,  19549 },                 -- Sentinel's Blade
				{ 11,  19557 },                 -- Protector's Sword
				{ 12,  19573 },                 -- Lorekeeper's Staff
				{ 17,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepRevered3039
				{ 18,  19564 },                 -- Outrunner's Bow
				{ 19,  19548 },                 -- Sentinel's Blade
				{ 20,  19556 },                 -- Protector's Sword
				{ 21,  19572 },                 -- Lorekeeper's Staff
				{ 23,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepRevered4049
				{ 24,  19563 },                 -- Outrunner's Bow
				{ 25,  19547 },                 -- Sentinel's Blade
				{ 26,  19555 },                 -- Protector's Sword
				{ 27,  19571 },                 -- Lorekeeper's Staff
				{ 101, "f890rep7" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepRevered5059
				{ 103, 19562 },                 -- Outrunner's Bow
				{ 104, 19546 },                 -- Sentinel's Blade
				{ 105, 19554 },                 -- Protector's Sword
				{ 106, 19570 },                 -- Lorekeeper's Staff
			},
			[HORDE_DIFF] = {
				{ 1,   "f889rep7" },
				{ 2,   "INV_Box_01", nil, "10 - 19", nil }, -- WSGRepRevered1019
				{ 3,   20437 },                 -- Outrider's Bow
				{ 4,   20441 },                 -- Scout's Blade
				{ 5,   20430 },                 -- Legionnaire's Sword
				{ 6,   20425 },                 -- Advisor's Gnarled Staff
				{ 8,   "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepRevered2029
				{ 9,   19561 },                 -- Outrider's Bow
				{ 10,  19545 },                 -- Scout's Blade
				{ 11,  19553 },                 -- Legionnaire's Sword
				{ 12,  19569 },                 -- Advisor's Gnarled Staff
				{ 17,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepRevered3039
				{ 18,  19560 },                 -- Outrider's Bow
				{ 19,  19544 },                 -- Scout's Blade
				{ 20,  19552 },                 -- Legionnaire's Sword
				{ 21,  19568 },                 -- Advisor's Gnarled Staff
				{ 23,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepRevered4049
				{ 24,  19559 },                 -- Outrider's Bow
				{ 25,  19543 },                 -- Scout's Blade
				{ 26,  19551 },                 -- Legionnaire's Sword
				{ 27,  19567 },                 -- Advisor's Gnarled Staff
				{ 101, "f889rep7" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepRevered5059
				{ 103, 19558 },                 -- Outrider's Bow
				{ 104, 19542 },                 -- Scout's Blade
				{ 105, 19550 },                 -- Legionnaire's Sword
				{ 106, 19566 },                 -- Advisor's Gnarled Staff
			},
		},
		{ -- WSGRepHonored
			name = _G["FACTION_STANDING_LABEL6"],
			[ALLIANCE_DIFF] = {
				{ 1,   "f890rep6" },
				{ 2,   "INV_Box_01", nil, "10 - 19", nil }, -- WSGRepHonored1019
				{ 3,   20444 },                 -- Sentinel's Medallion
				{ 4,   20428 },                 -- Caretaker's Cape
				{ 5,   20431 },                 -- Lorekeeper's Ring
				{ 6,   20439 },                 -- Protector's Band
				{ 8,   "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepHonored2029
				{ 9,   19541 },                 -- Sentinel's Medallion
				{ 10,  19533 },                 -- Caretaker's Cape
				{ 11,  19525 },                 -- Lorekeeper's Ring
				{ 12,  19517 },                 -- Protector's Band
				{ 17,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepHonored3039
				{ 18,  19540 },                 -- Sentinel's Medallion
				{ 19,  19532 },                 -- Caretaker's Cape
				{ 20,  19524 },                 -- Lorekeeper's Ring
				{ 21,  19515 },                 -- Protector's Band
				{ 23,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepHonored4049
				{ 24,  19539 },                 -- Sentinel's Medallion
				{ 25,  19531 },                 -- Caretaker's Cape
				{ 26,  19523 },                 -- Lorekeeper's Ring
				{ 27,  19516 },                 -- Protector's Band
				{ 28,  17348 },                 -- Major Healing Draught
				{ 29,  17351 },                 -- Major Mana Draught
				{ 101, "f890rep6" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepHonored5059
				{ 103, 19538 },                 -- Sentinel's Medallion
				{ 104, 19530 },                 -- Caretaker's Cape
				{ 105, 19522 },                 -- Lorekeeper's Ring
				{ 106, 19514 },                 -- Protector's Band
			},
			[HORDE_DIFF] = {
				{ 1,   "f889rep6" },
				{ 2,   "INV_Box_01", nil, "10 - 19", nil }, -- WSGRepHonored1019
				{ 3,   20442 },                 -- Scout's Medallion
				{ 4,   20427 },                 -- Battle Healer's Cloak
				{ 5,   20426 },                 -- Advisor's Ring
				{ 6,   20429 },                 -- Legionnaire's Band
				{ 8,   "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepHonored2029
				{ 9,   19537 },                 -- Scout's Medallion
				{ 10,  19529 },                 -- Battle Healer's Cloak
				{ 11,  19521 },                 -- Advisor's Ring
				{ 12,  19513 },                 -- Legionnaire's Band
				{ 17,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepHonored3039
				{ 18,  19536 },                 -- Scout's Medallion
				{ 19,  19528 },                 -- Battle Healer's Cloak
				{ 20,  19520 },                 -- Advisor's Ring
				{ 21,  19512 },                 -- Legionnaire's Band
				{ 23,  "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepHonored4049
				{ 24,  19535 },                 -- Scout's Medallion
				{ 25,  19527 },                 -- Battle Healer's Cloak
				{ 26,  19519 },                 -- Advisor's Ring
				{ 27,  19511 },                 -- Legionnaire's Band
				{ 28,  17348 },                 -- Major Healing Draught
				{ 29,  17351 },                 -- Major Mana Draught
				{ 101, "f889rep6" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- WSGRepHonored5059
				{ 103, 19534 },                 -- Scout's Medallion
				{ 104, 19526 },                 -- Battle Healer's Cloak
				{ 105, 19518 },                 -- Advisor's Ring
				{ 106, 19510 },                 -- Legionnaire's Band
			},
		},
		{ -- WSGRepFriendly
			name = _G["FACTION_STANDING_LABEL5"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f890rep5" },
				{ 2,  "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepFriendly2029
				{ 3,  21568 },                 -- Rune of Duty
				{ 4,  21566 },                 -- Rune of Perfection
				{ 5,  19062 },                 -- Warsong Gulch Field Ration
				{ 6,  19068 },                 -- Warsong Gulch Silk Bandage
				{ 8,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepFriendly3039
				{ 9,  19061 },                 -- Warsong Gulch Iron Ration
				{ 10, 19067 },                 -- Warsong Gulch Mageweave Bandage
				{ 11, 17349 },                 -- Superior Healing Draught
				{ 12, 17352 },                 -- Superior Mana Draught
				{ 17, "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepFriendly4049
				{ 18, 21567 },                 -- Rune of Duty
				{ 19, 21565 },                 -- Rune of Perfection
				{ 20, 19060 },                 -- Warsong Gulch Enriched Ration
				{ 21, 19066 },                 -- Warsong Gulch Runecloth Bandage
			},
			[HORDE_DIFF] = {
				{ 1,  "f889rep5" },
				{ 2,  "INV_Box_01", nil, "20 - 29", nil }, -- WSGRepFriendly2029
				{ 3,  21568 },                 -- Rune of Duty
				{ 4,  21566 },                 -- Rune of Perfection
				{ 5,  19062 },                 -- Warsong Gulch Field Ration
				{ 6,  19068 },                 -- Warsong Gulch Silk Bandage
				{ 8,  "INV_Box_01", nil, "30 - 39", nil }, -- WSGRepFriendly3039
				{ 9,  19061 },                 -- Warsong Gulch Iron Ration
				{ 10, 19067 },                 -- Warsong Gulch Mageweave Bandage
				{ 11, 17349 },                 -- Superior Healing Draught
				{ 12, 17352 },                 -- Superior Mana Draught
				{ 17, "INV_Box_01", nil, "40 - 49", nil }, -- WSGRepFriendly4049
				{ 18, 21567 },                 -- Rune of Duty
				{ 19, 21565 },                 -- Rune of Perfection
				{ 20, 19060 },                 -- Warsong Gulch Enriched Ration
				{ 21, 19066 },                 -- Warsong Gulch Runecloth Bandage
			},
		},
		PVP_RANKS,
	},
}

data["ArathiBasin"] = {
	MapID = 3358,
	AtlasMapID = "ArathiBasin",
	ContentType = PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 3,
	items = {
		{ -- ABRepExalted
			name = _G["FACTION_STANDING_LABEL8"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f509rep8" },
				{ 2,  20061 }, -- Highlander's Epaulets
				{ 3,  20060 }, -- Highlander's Lizardhide Shoulders
				{ 4,  20059 }, -- Highlander's Leather Shoulders
				{ 5,  20055 }, -- Highlander's Chain Pauldrons
				{ 6,  20058 }, -- Highlander's Lamellar Spaulders
				{ 7,  20057 }, -- Highlander's Plate Spaulders
				{ 8,  20073 }, -- Cloak of the Honor Guard
				{ 9,  20070 }, -- Sageclaw
				{ 10, 20069 }, -- Ironbark Staff
				{ 17, 20132 }, -- Arathor Battle Tabard
			},
			[HORDE_DIFF] = {
				{ 1,  "f510rep8" },
				{ 2,  20176 }, -- Defiler's Epaulets
				{ 3,  20175 }, -- Defiler's Lizardhide Shoulders
				{ 4,  20194 }, -- Defiler's Leather Shoulders
				{ 5,  20158 }, -- Defiler's Chain Pauldrons
				{ 6,  20203 }, -- Defiler's Mail Pauldrons
				{ 7,  20212 }, -- Defiler's Plate Spaulders
				{ 8,  20068 }, -- Deathguard's Cloak
				{ 9,  20214 }, -- Mindfang
				{ 10, 20220 }, -- Ironbark Staff
				{ 17, 20131 }, -- Battle Tabard of the Defilers
			},
		},
		{ -- ABRepRevered
			name = _G["FACTION_STANDING_LABEL7"],
			[ALLIANCE_DIFF] = {
				{ 1,   "f509rep7" },
				{ 2,   "INV_Box_01", nil, "20 - 29", nil }, -- ABRepRevered2029
				{ 3,   20096 },                 -- Highlander's Cloth Boots
				{ 4,   20114 },                 -- Highlander's Leather Boots
				{ 5,   20102 },                 -- Highlander's Lizardhide Boots
				{ 6,   20093 },                 -- Highlander's Chain Greaves
				{ 7,   20111 },                 -- Highlander's Lamellar Greaves
				{ 8,   20129 },                 -- Highlander's Plate Greaves
				{ 10,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepRevered3039
				{ 11,  20095 },                 -- Highlander's Cloth Boots
				{ 12,  20113 },                 -- Highlander's Leather Boots
				{ 13,  20101 },                 -- Highlander's Lizardhide Boots
				{ 17,  "INV_Box_01", nil, "40 - 49", nil }, -- ABRepRevered4049
				{ 18,  20094 },                 -- Highlander's Cloth Boots
				{ 19,  20112 },                 -- Highlander's Leather Boots
				{ 20,  20100 },                 -- Highlander's Lizardhide Boots
				{ 21,  20091 },                 -- Highlander's Chain Greaves
				{ 22,  20109 },                 -- Highlander's Lamellar Greaves
				{ 23,  20127 },                 -- Highlander's Plate Greaves
				{ 24,  20092 },                 -- Highlander's Chain Greaves
				{ 25,  20110 },                 -- Highlander's Lamellar Greaves
				{ 26,  20128 },                 -- Highlander's Plate Greaves
				{ 101, "f509rep7" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepRevered5059
				{ 103, 20054 },                 -- Highlander's Cloth Boots
				{ 104, 20052 },                 -- Highlander's Leather Boots
				{ 105, 20053 },                 -- Highlander's Lizardhide Boots
				{ 106, 20050 },                 -- Highlander's Chain Greaves
				{ 107, 20049 },                 -- Highlander's Lamellar Greaves
				{ 108, 20048 },                 -- Highlander's Plate Greaves
			},
			[HORDE_DIFF] = {
				{ 1,   "f510rep7" },
				{ 2,   "INV_Box_01", nil, "20 - 29", nil }, -- ABRepRevered2029
				{ 3,   20162 },                 -- Defiler's Cloth Boots
				{ 4,   20188 },                 -- Defiler's Leather Boots
				{ 5,   20169 },                 -- Defiler's Lizardhide Boots
				{ 6,   20157 },                 -- Defiler's Chain Greaves
				{ 7,   20201 },                 -- Defiler's Mail Greaves
				{ 8,   20210 },                 -- Defiler's Plate Greaves
				{ 10,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepRevered3039
				{ 11,  20161 },                 -- Defiler's Cloth Boots
				{ 12,  20187 },                 -- Defiler's Leather Boots
				{ 13,  20168 },                 -- Defiler's Lizardhide Boots
				{ 17,  "INV_Box_01", nil, "40 - 49", nil }, -- ABRepRevered4049
				{ 18,  20160 },                 -- Defiler's Cloth Boots
				{ 19,  20189 },                 -- Defiler's Leather Boots
				{ 20,  20170 },                 -- Defiler's Lizardhide Boots
				{ 21,  20155 },                 -- Defiler's Chain Greaves
				{ 22,  20202 },                 -- Defiler's Mail Greaves
				{ 23,  20211 },                 -- Defiler's Plate Greaves
				{ 24,  20156 },                 -- Defiler's Chain Greaves
				{ 25,  20200 },                 -- Defiler's Mail Greaves
				{ 26,  20209 },                 -- Defiler's Plate Greaves
				{ 101, "f510rep7" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepRevered5059
				{ 103, 20159 },                 -- Defiler's Cloth Boots
				{ 104, 20186 },                 -- Defiler's Leather Boots
				{ 105, 20167 },                 -- Defiler's Lizardhide Boots
				{ 106, 20154 },                 -- Defiler's Chain Greaves
				{ 107, 20199 },                 -- Defiler's Mail Greaves
				{ 108, 20208 },                 -- Defiler's Plate Greaves
			},
		},
		{ -- ABRepHonored
			name = _G["FACTION_STANDING_LABEL6"],
			[ALLIANCE_DIFF] = {
				{ 1,   "f509rep6" },
				{ 2,   "INV_Box_01", nil, "20 - 29", nil }, -- ABRepHonored2029
				{ 3,   20099 },                 -- Highlander's Cloth Girdle
				{ 4,   20117 },                 -- Highlander's Leather Girdle
				{ 5,   20105 },                 -- Highlander's Lizardhide Girdle
				{ 6,   20090 },                 -- Highlander's Chain Girdle
				{ 7,   20108 },                 -- Highlander's Lamellar Girdle
				{ 8,   20126 },                 -- Highlander's Plate Girdle
				{ 10,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepHonored3039
				{ 11,  20098 },                 -- Highlander's Cloth Girdle
				{ 12,  20116 },                 -- Highlander's Leather Girdle
				{ 13,  20104 },                 -- Highlander's Lizardhide Girdle
				{ 17,  "INV_Box_01", nil, "40 - 49", nil }, -- ABRepHonored4049
				{ 18,  20097 },                 -- Highlander's Cloth Girdle
				{ 19,  20115 },                 -- Highlander's Leather Girdle
				{ 20,  20103 },                 -- Highlander's Lizardhide Girdle
				{ 21,  20088 },                 -- Highlander's Chain Girdle
				{ 22,  20106 },                 -- Highlander's Lamellar Girdle
				{ 23,  20124 },                 -- Highlander's Plate Girdle
				{ 24,  20089 },                 -- Highlander's Chain Girdle
				{ 25,  20107 },                 -- Highlander's Lamellar Girdle
				{ 26,  20125 },                 -- Highlander's Plate Girdle
				{ 101, "f509rep6" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepHonored5059
				{ 103, 20047 },                 -- Highlander's Cloth Girdle
				{ 104, 20045 },                 -- Highlander's Leather Girdle
				{ 105, 20046 },                 -- Highlander's Lizardhide Girdle
				{ 106, 20043 },                 -- Highlander's Chain Girdle
				{ 107, 20042 },                 -- Highlander's Lamellar Girdle
				{ 108, 20041 },                 -- Highlander's Plate Girdle
			},
			[HORDE_DIFF] = {
				{ 1,   "f510rep6" },
				{ 2,   "INV_Box_01", nil, "20 - 29", nil }, -- ABRepHonored2029
				{ 3,   20164 },                 -- Defiler's Cloth Girdle
				{ 4,   20191 },                 -- Defiler's Leather Girdle
				{ 5,   20172 },                 -- Defiler's Lizardhide Girdle
				{ 6,   20152 },                 -- Defiler's Chain Girdle
				{ 7,   20197 },                 -- Defiler's Mail Girdle
				{ 8,   20207 },                 -- Defiler's Plate Girdle
				{ 10,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepHonored3039
				{ 11,  20166 },                 -- Defiler's Cloth Girdle
				{ 12,  20192 },                 -- Defiler's Leather Girdle
				{ 13,  20173 },                 -- Defiler's Lizardhide Girdle
				{ 17,  "INV_Box_01", nil, "40 - 49", nil }, -- ABRepHonored4049
				{ 18,  20165 },                 -- Defiler's Cloth Girdle
				{ 19,  20193 },                 -- Defiler's Leather Girdle
				{ 20,  20174 },                 -- Defiler's Lizardhide Girdle
				{ 21,  20151 },                 -- Defiler's Chain Girdle
				{ 22,  20196 },                 -- Defiler's Mail Girdle
				{ 23,  20205 },                 -- Defiler's Plate Girdle
				{ 24,  20153 },                 -- Defiler's Chain Girdle
				{ 25,  20198 },                 -- Defiler's Mail Girdle
				{ 26,  20206 },                 -- Defiler's Plate Girdle
				{ 101, "f510rep6" },
				{ 102, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepHonored5059
				{ 103, 20163 },                 -- Defiler's Cloth Girdle
				{ 104, 20190 },                 -- Defiler's Leather Girdle
				{ 105, 20171 },                 -- Defiler's Lizardhide Girdle
				{ 106, 20150 },                 -- Defiler's Chain Girdle
				{ 107, 20195 },                 -- Defiler's Mail Girdle
				{ 108, 20204 },                 -- Defiler's Plate Girdle
			},
		},
		{ -- ABRepFriendly
			name = _G["FACTION_STANDING_LABEL5"],
			[ALLIANCE_DIFF] = {
				{ 1,  "f509rep5" },
				{ 2,  "INV_Box_01", nil, "20 - 29", nil }, -- ABRepFriendly2029
				{ 3,  21119 },                 -- Talisman of Arathor
				{ 4,  20226 },                 -- Highlander's Field Ration
				{ 5,  20244 },                 -- Highlander's Silk Bandage
				{ 7,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepFriendly3039
				{ 8,  21118 },                 -- Talisman of Arathor
				{ 9,  20227 },                 -- Highlander's Iron Ration
				{ 10, 20237 },                 -- Highlander's Mageweave Bandage
				{ 11, 17349 },                 -- Superior Healing Draught
				{ 12, 17352 },                 -- Superior Mana Draught
				{ 17, "INV_Box_01", nil, "40 - 49", nil }, -- ABRepFriendly4049
				{ 18, 21117 },                 -- Talisman of Arathor
				{ 19, 20225 },                 -- Highlander's Enriched Ration
				{ 20, 20243 },                 -- Highlander's Runecloth Bandage
				{ 22, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepFriendly5059
				{ 23, 20071 },                 -- Talisman of Arathor
			},
			[HORDE_DIFF] = {
				{ 1,  "f510rep5" },
				{ 2,  "INV_Box_01", nil, "20 - 29", nil }, -- ABRepFriendly2029
				{ 3,  21120 },                 -- Defiler's Talisman
				{ 4,  20223 },                 -- Defiler's Field Ration
				{ 5,  20235 },                 -- Defiler's Silk Bandage
				{ 7,  "INV_Box_01", nil, "30 - 39", nil }, -- ABRepFriendly3039
				{ 8,  21116 },                 -- Defiler's Talisman
				{ 9,  20224 },                 -- Defiler's Iron Ration
				{ 10, 20232 },                 -- Defiler's Mageweave Bandage
				{ 11, 17349 },                 -- Superior Healing Draught
				{ 12, 17352 },                 -- Superior Mana Draught
				{ 17, "INV_Box_01", nil, "40 - 49", nil }, -- ABRepFriendly4049
				{ 18, 21115 },                 -- Defiler's Talisman
				{ 19, 20222 },                 -- Defiler's Enriched Ration
				{ 20, 20234 },                 -- Defiler's Runecloth Bandage
				{ 22, "INV_Box_01", nil, "50 - 59", nil }, -- ABRepFriendly5059
				{ 23, 20072 },                 -- Defiler's Talisman
			},
		},
		PVP_RANKS,
	},
}

data["ClassSets"] = {
	name = AL["Class Sets"],
	ContentType = GENERAL_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	TableType = SET_ITTYPE,
	ContentPhase = 2,
	items = {
		{ -- Epic
			name = ALIL["Epic"],
			ContentPhase = 2,
			[ALLIANCE_DIFF] = {
				{ 1,  392 }, -- Warlock
				{ 3,  389 }, -- Priest
				{ 16, 388 }, -- Mage
				{ 5,  394 }, -- Rogue
				{ 20, 397 }, -- Druid
				{ 7,  395 }, -- Hunter
				{ 9,  384 }, -- Warrior
				{ 24, 402 }, -- Paladin
			},

			[HORDE_DIFF] = {
				{ 1,  391 }, -- Warlock
				{ 3,  390 }, -- Priest
				{ 16, 387 }, -- Mage
				{ 5,  393 }, -- Rogue
				{ 20, 398 }, -- Druid
				{ 7,  396 }, -- Hunter
				{ 9,  383 }, -- Warrior
				{ 22, 386 }, -- Shaman
			},
		},
		{ -- Rare
			name = ALIL["Rare"],
			ContentPhase = 2,
			[ALLIANCE_DIFF] = {
				{ 1,  547 }, -- Warlock
				{ 3,  549 }, -- Priest
				{ 16, 546 }, -- Mage
				{ 5,  548 }, -- Rogue
				{ 20, 551 }, -- Druid
				{ 7,  550 }, -- Hunter
				{ 9,  545 }, -- Warrior
				{ 24, 544 }, -- Paladin
			},

			[HORDE_DIFF] = {
				{ 1,  541 }, -- Warlock
				{ 3,  540 }, -- Priest
				{ 16, 542 }, -- Mage
				{ 5,  522 }, -- Rogue
				{ 20, 539 }, -- Druid
				{ 7,  543 }, -- Hunter
				{ 9,  537 }, -- Warrior
				{ 22, 538 }, -- Shaman
			},
		},
		PVP_RANKS,
	},
}

data["Armor"] = {
	name = AL["Armor"],
	ContentType = GENERAL_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = {
		{ -- PVPWeapons
			name = AL["Armor"],
			[ALLIANCE_DIFF] = {
				{ 1,  18664 }, -- A Treatise on Military Ranks

				{ 3,  18443 }, -- Master Sergeant's Insignia
				{ 4,  18444 }, -- Master Sergeant's Insignia
				{ 5,  18442 }, -- Master Sergeant's Insignia

				{ 7,  18456 }, -- Sergeant Major's Silk Cuffs
				{ 8,  18457 }, -- Sergeant Major's Silk Cuffs

				{ 10, 18452 }, -- Sergeant Major's Leather Armsplints
				{ 11, 18453 }, -- Sergeant Major's Leather Armsplints

				{ 13, 18448 }, -- Sergeant Major's Chain Armguards
				{ 14, 18449 }, -- Sergeant Major's Chain Armguards

				{ 16, 15196 }, -- Private's Tabard

				{ 18, 16342 }, -- Sergeant's Cape
				{ 19, 18441 }, -- Sergeant's Cape
				{ 20, 18440 }, -- Sergeant's Cape

				{ 22, 18445 }, -- Sergeant Major's Plate Wristguards
				{ 23, 18447 }, -- Sergeant Major's Plate Wristguards

				{ 25, 18454 }, -- Sergeant Major's Dragonhide Armsplints
				{ 26, 18455 }, -- Sergeant Major's Dragonhide Armsplints

			},
			[HORDE_DIFF] = {
				{ 1,  18675 }, -- Military Ranks of the Horde & Alliance

				{ 3,  16335 }, -- Senior Sergeant's Insignia
				{ 4,  18428 }, -- Senior Sergeant's Insignia
				{ 5,  15200 }, -- Senior Sergeant's Insignia

				{ 7,  16486 }, -- First Sergeant's Silk Cuffs
				{ 8,  18437 }, -- First Sergeant's Silk Cuffs

				{ 10, 16497 }, -- First Sergeant's Leather Armguards
				{ 11, 18435 }, -- First Sergeant's Leather Armguards

				{ 13, 18429 }, -- First Sergeant's Plate Bracers
				{ 14, 18430 }, -- First Sergeant's Plate Bracers

				{ 16, 15197 }, -- Scout's Tabard

				{ 18, 18461 }, -- Sergeant's Cloak
				{ 19, 16341 }, -- Sergeant's Cloak
				{ 20, 18427 }, -- Sergeant's Cloak

				{ 22, 16532 }, -- First Sergeant's Mail Wristguards
				{ 23, 18432 }, -- First Sergeant's Mail Wristguards

				{ 25, 18434 }, -- First Sergeant's Dragonhide Armguards
				{ 26, 18436 }, -- First Sergeant's Dragonhide Armguards

			},
		},
		PVP_RANKS,
	},
}

data["Weapons"] = {
	name = AL["Weapons"],
	ContentType = GENERAL_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = {
		{ -- PVPWeapons
			name = AL["Weapons"],
			[ALLIANCE_DIFF] = {
				{ 1,  18827 }, -- Grand Marshal's Handaxe
				{ 2,  18830 }, -- Grand Marshal's Sunderer
				{ 3,  18838 }, -- Grand Marshal's Dirk
				{ 4,  23451 }, -- Grand Marshal's Mageblade
				{ 5,  18843 }, -- Grand Marshal's Right Hand Blade
				{ 6,  18847 }, -- Grand Marshal's Left Hand Blade
				{ 7,  18865 }, -- Grand Marshal's Punisher
				{ 8,  23454 }, -- Grand Marshal's Warhammer
				{ 9,  23455 }, -- Grand Marshal's Demolisher
				{ 10, 18867 }, -- Grand Marshal's Battle Hammer
				{ 11, 12584 }, -- Grand Marshal's Longsword
				{ 12, 23456 }, -- Grand Marshal's Swiftblade
				{ 13, 18876 }, -- Grand Marshal's Claymore
				{ 16, 18869 }, -- Grand Marshal's Glaive
				{ 17, 18873 }, -- Grand Marshal's Stave
				{ 18, 18833 }, -- Grand Marshal's Bullseye
				{ 19, 18836 }, -- Grand Marshal's Repeater
				{ 20, 18855 }, -- Grand Marshal's Hand Cannon
				{ 21, 18825 }, -- Grand Marshal's Aegis
				{ 22, 23452 }, -- Grand Marshal's Tome of Power
				{ 23, 23453 }, -- Grand Marshal's Tome of Restoration
			},
			[HORDE_DIFF] = {
				{ 1,  18828 }, -- High Warlord's Cleaver
				{ 2,  18831 }, -- High Warlord's Battle Axe
				{ 3,  18840 }, -- High Warlord's Razor
				{ 4,  23466 }, -- High Warlord's Spellblade
				{ 5,  18844 }, -- High Warlord's Right Claw
				{ 6,  18848 }, -- High Warlord's Left Claw
				{ 7,  18866 }, -- High Warlord's Bludgeon
				{ 8,  23464 }, -- High Warlord's Battle Mace
				{ 9,  23465 }, -- High Warlord's Destroyer
				{ 10, 18868 }, -- High Warlord's Pulverizer
				{ 11, 16345 }, -- High Warlord's Blade
				{ 12, 23467 }, -- High Warlord's Quickblade
				{ 13, 18877 }, -- High Warlord's Greatsword
				{ 16, 18871 }, -- High Warlord's Pig Sticker
				{ 17, 18874 }, -- High Warlord's War Staff
				{ 18, 18835 }, -- High Warlord's Recurve
				{ 19, 18837 }, -- High Warlord's Crossbow
				{ 20, 18860 }, -- High Warlord's Street Sweeper
				{ 21, 18826 }, -- High Warlord's Shield Wall
				{ 22, 23468 }, -- High Warlord's Tome of Destruction
				{ 23, 23469 }, -- High Warlord's Tome of Mending
			},
		},
		PVP_RANKS,
	},
}

data["PvPMounts"] = {
	name = ALIL["Mounts"],
	ContentType = GENERAL_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	CorrespondingFields = private.MOUNTS_LINK,
	items = {
		{ -- PvPMountsPvP
			name = ALIL["Mounts"],
			[ALLIANCE_DIFF] = {
				{ 1, 19030 }, -- Stormpike Battle Charger
				{ 3, 18244 }, -- Black War Ram
				{ 4, 18243 }, -- Black Battlestrider
				{ 5, 18241 }, -- Black War Steed Bridle
				{ 6, 18242 }, -- Reins of the Black War Tiger
			},
			[HORDE_DIFF] = {
				{ 1, 19029 }, -- Horn of the Frostwolf Howler
				{ 3, 18245 }, -- Horn of the Black War Wolf
				{ 4, 18247 }, -- Black War Kodo
				{ 5, 18246 }, -- Whistle of the Black War Raptor
				{ 6, 18248 }, -- Red Skeletal Warhorse
			},
		},
		PVP_RANKS,
	},
}

data["Insignia"] = {
	name = AL["Insignia"],
	ContentType = GENERAL_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = {
		{
			name = AL["Insignia"],
			[ALLIANCE_DIFF] = {
				{ 1, 18854 }, -- Warrior
				{ 2, 18856 }, -- Hunter
				{ 3, 18857 }, -- Rogue
				{ 4, 18858 }, -- Warlock
				{ 5, 18862 }, -- Priest
				{ 6, 18863 }, -- Druid
				{ 7, 18864 }, -- Paladin
				{ 8, 18859 }, -- Mage

			},
			[HORDE_DIFF] = {
				{ 1, 18834 }, -- Warrior
				{ 2, 18846 }, -- Hunter
				{ 3, 18849 }, -- Rogue
				{ 4, 18852 }, -- Warlock
				{ 5, 18851 }, -- Priest
				{ 6, 18853 }, -- Druid
				{ 7, 18845 }, -- Shaman
				{ 8, 18850 }, -- Mage
			},
		},
		PVP_RANKS,
	},
}

-----------------------------------------------------------------------
-- Forever PvP Content
-----------------------------------------------------------------------

-- Localized class names fallback
local CL = _G.LOCALIZED_CLASS_NAMES_MALE or {}
local CL_DRUID   = CL["DRUID"]   or "Druid"
local CL_HUNTER  = CL["HUNTER"]  or "Hunter"
local CL_MAGE    = CL["MAGE"]    or "Mage"
local CL_PALADIN = CL["PALADIN"] or "Paladin"
local CL_PRIEST  = CL["PRIEST"]  or "Priest"
local CL_ROGUE   = CL["ROGUE"]   or "Rogue"
local CL_SHAMAN  = CL["SHAMAN"]  or "Shaman"
local CL_WARLOCK = CL["WARLOCK"] or "Warlock"
local CL_WARRIOR = CL["WARRIOR"] or "Warrior"

-- Helper to automatically slot items across AtlasLoot pages (30 items per page)
local function CreatePVPPage(name, itemIDs)
	local function BuildSlots()
		local list = {}
		for i, id in ipairs(itemIDs) do
			local page = math.floor((i - 1) / 30)
			local slot = (page * 100) + ((i - 1) % 30) + 1
			list[#list + 1] = { slot, id }
		end
		return list
	end

	return {
		name = name,
		[ALLIANCE_DIFF] = BuildSlots(),
		[HORDE_DIFF] = BuildSlots(),
	}
end

-----------------------------------------------------------------------
-- Forever: Armor (Epic & Rare Class Sets)
-----------------------------------------------------------------------
data["ForeverArmor"] = {
	name = AL["Armor"],
	ContentType = FOREVER_PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = {
		-- Epic Armor
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_DRUID), {
			272760, 272761, 272758, 272757, 272754, 272768, 272756, 273402, 272759, 272515, 272519, 273394, 272520, 272514, 272518, 273406, 273414, 272521, 273413, 272517, 272516, 273400, 273393, 273392, 273398, 273401, 273419, 273390, 273415, 273403, 273395, 273399, 273391, 273397, 273411, 273389, 273404, 273410, 273412, 273396, 273416, 273405, 273407, 273409, 273417, 273420, 273408, 273418
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_HUNTER), {
			272774, 272531, 272777, 272775, 272530, 272772, 272536, 272534, 272771, 272532, 272533, 272776, 272537, 272535, 272770, 272773
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_MAGE), {
			272498, 272500, 272752, 272504, 272501, 272503, 272750, 272505, 272499, 272748, 272502, 272751, 272747, 272753, 272746, 272749
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_PALADIN), {
			272783, 272838, 273334, 274239, 272785, 273332, 278468, 274241, 274253, 274236, 274255, 273331, 274252, 272781, 274238, 272778, 272782, 274237, 272780, 274251, 272784, 273328, 273330, 274240, 272779, 273329, 274250, 274254, 274235, 273327, 273333, 274234, 274248, 274249
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_PRIEST), {
			273421, 272570, 272820, 272575, 272574, 272821, 273433, 272818, 272824, 272571, 273429, 273435, 272819, 273434, 272576, 272577, 273423, 273424, 273428, 273431, 272572, 272823, 273436, 272822, 272825, 273422, 273426, 273432, 272573, 273425, 273427, 273430
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_ROGUE), {
			272764, 272762, 272527, 272766, 272528, 272763, 272755, 272526, 272767, 272525, 272765, 272769, 272524, 272529, 272523, 272522
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_SHAMAN), {
			273336, 273343, 273341, 272838, 274203, 274188, 278468, 272543, 272538, 273340, 273344, 272545, 274198, 272542, 274187, 273345, 273348, 274202, 274211, 274183, 274190, 274206, 272539, 273349, 273342, 272544, 273351, 274205, 273338, 274184, 274207, 274213, 274199, 273350, 273339, 274204, 274185, 273337, 274189, 274209, 272540, 274210, 273347, 274201, 274208, 272541, 274200, 274212, 273346, 274186
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_WARLOCK), {
			272559, 272560, 272802, 272554, 272558, 272805, 272804, 272556, 272561, 272807, 272808, 272803, 272555, 272806, 272809, 272557
		}),
		CreatePVPPage(format("%s - %s", ALIL["Epic"], CL_WARRIOR), {
			272787, 272789, 272509, 272838, 272786, 272507, 278468, 272506, 272788, 272510, 272793, 272508, 272792, 272512, 272513, 272791, 272511, 272790
		}),

		-- Rare (Blue) Armor
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_DRUID), {
			272733, 272471, 272578, 273374, 272469, 272462, 272732, 272709, 273375, 273377, 273380, 272642, 272614, 272730, 272731, 272641, 272669, 272472, 272589, 272470, 272627, 273379, 273386, 272670, 272705, 272626, 273387, 272656, 273373, 272464, 272606, 272707, 274968, 273371, 273368, 272699, 273378, 273383, 273382, 272834, 273367, 273384, 272711, 273385, 272461, 272463, 273381, 272582, 273369, 273370, 272835, 273388
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_HUNTER), {
			272737, 272736, 272578, 272640, 272715, 272735, 272491, 272713, 272734, 272496, 272490, 272589, 272495, 272483, 272712, 272492, 274968, 272699, 272830, 272494
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_MAGE), {
			274969, 272722, 272725, 272459, 272457, 272680, 272703, 272723, 272589, 272455, 272724, 272453, 272701, 272458, 272700, 272454, 272456, 272702
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_PALADIN), {
			272745, 272743, 274231, 272855, 274233, 274246, 272854, 272718, 272719, 272744, 274227, 274230, 272742, 274247, 274232, 274256, 274226, 272852, 273363, 274245, 272589, 273365, 274244, 272721, 274968, 272720, 274258, 272699, 274228, 273364, 272853, 274229, 274257, 274259, 273366
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_PRIEST), {
			272650, 273448, 272611, 272634, 272677, 272816, 272565, 272562, 272678, 272649, 272564, 272817, 272589, 272814, 272569, 272812, 273443, 272567, 272815, 272563, 272568, 274968, 272619, 272699, 272810, 273447, 273445, 272566, 272813, 272811, 272663, 275437, 273444, 273450, 273449
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_ROGUE), {
			272727, 272726, 272729, 274969, 272475, 272474, 272728, 272708, 272704, 272473, 272476, 272467, 274968, 272608, 272699, 272465, 272706, 272710, 272468
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_SHAMAN), {
			274192, 274196, 274181, 272647, 273358, 274217, 272489, 274178, 274194, 274218, 272609, 272486, 274177, 274180, 272648, 274176, 274220, 272487, 272589, 272625, 274179, 274193, 273360, 272617, 274197, 272488, 274222, 272485, 272484, 273355, 274195, 273356, 274968, 274219, 272497, 272699, 273353, 273357, 274182, 273359, 273352, 274214, 274221, 272636, 274224, 273372, 274225, 274215, 274223, 273362, 273361
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_WARLOCK), {
			272671, 272549, 272801, 272643, 272552, 272800, 272657, 272548, 272553, 272794, 272796, 272589, 272630, 274968, 272699, 272795, 272551, 272797, 272550
		}),
		CreatePVPPage(format("%s - %s", ALIL["Rare"], CL_WARRIOR), {
			272741, 272637, 272738, 272739, 272480, 272479, 272716, 272740, 272717, 272478, 272477, 272481, 272579, 272589, 273324, 274968, 272699, 272828, 273325
		}),

		PVP_RANKS,
	},
}

-----------------------------------------------------------------------
-- Forever: Weapons
-----------------------------------------------------------------------
data["ForeverWeapons"] = {
	name = AL["Weapons"],
	ContentType = FOREVER_PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = {
		CreatePVPPage(format("%s %s", ALIL["Epic"], AL["Weapons"]), {
			272851, 272848, 272682, 272452, 272693, 272594, 272681, 272858, 272601, 272683,
			272593, 272604, 272841, 272596, 272850, 272857, 272856, 272840, 272603, 272849,
			272843, 272846, 272595, 272684, 272602, 272842, 272845, 272859, 272599, 272839,
			272844, 272592, 272597, 272598, 272847, 272600
		}),
		PVP_RANKS,
	},
}

-----------------------------------------------------------------------
-- Forever: Mounts
-----------------------------------------------------------------------
data["ForeverMounts"] = {
	name = ALIL["Mounts"],
	ContentType = FOREVER_PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	CorrespondingFields = private.MOUNTS_LINK,
	items = data["PvPMounts"].items,
}

-----------------------------------------------------------------------
-- Forever: Insignia
-----------------------------------------------------------------------
data["ForeverInsignia"] = {
	name = AL["Insignia"],
	ContentType = FOREVER_PVP_CONTENT,
	LoadDifficulty = LOAD_DIFF,
	ContentPhase = 2,
	items = data["Insignia"].items,
}