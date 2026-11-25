-- PluribusHive Auctionator Module (Selling, Shopping Lists, Advanced Filters, To-Do Sync & Disenchant Sniper)
-- Strict Lua 5.1 / WoW Classic 1.12–1.15 & Warcraft Forever 1.60.1 compatible
-- Uniform flat Obsidian UI via PluribusUIFramework, zero taint on Blizzard secure frames

PluribusHiveAuctionator = {
	initialized = false,
	activeMode = nil, -- "sell" | "shop" | "de"
	-- Selling state
	bagItems = {},
	selectedBagItem = nil,
	competingListings = {},
	ownerAuctions = {},
	sellSubView = "bag", -- "bag" | "owner"
	-- Shopping state
	shoppingResults = {},
	activeSearchTerm = "",
	showAdvancedFilters = false,
	batchQueue = {},
	batchActive = false,
	-- Disenchant state
	deDeals = {},
	deLiveScanActive = false,
	deScanPage = 0,
	deScanCategoryIdx = 1,
	deLivePool = {},
	-- Pending query context
	pendingQueryKind = nil, -- "sell" | "shop" | "de" | "owner"
	pendingQueryTarget = nil,
	pendingQueryFilter = nil,
	-- UI refs
	views = {},
	_scanTip = nil,
}
_G.PluribusHiveAuctionator = PluribusHiveAuctionator

-- ============================================================================
-- CLASSIC 1.12 / 1.60.1 DISENCHANT EXPECTED VALUE TABLES
-- ============================================================================
-- Enchanting Reagent Item IDs
local DE_MAT = {
	STRANGE_DUST    = 10940,
	SOUL_DUST       = 11083,
	VISION_DUST     = 11137,
	DREAM_DUST      = 11176,
	ILLUSION_DUST   = 16204,

	L_MAGIC_ESS     = 10938,
	G_MAGIC_ESS     = 10939,
	L_ASTRAL_ESS    = 10998,
	G_ASTRAL_ESS    = 11082,
	L_MYSTIC_ESS    = 11134,
	G_MYSTIC_ESS    = 11135,
	L_NETHER_ESS    = 11174,
	G_NETHER_ESS    = 11175,
	L_ETERNAL_ESS   = 16202,
	G_ETERNAL_ESS   = 16203,

	S_GLIM_SHARD    = 10978,
	L_GLIM_SHARD    = 11084,
	S_GLOW_SHARD    = 11138,
	L_GLOW_SHARD    = 11139,
	S_RAD_SHARD     = 11177,
	L_RAD_SHARD     = 11178,
	S_BRIL_SHARD    = 14343,
	L_BRIL_SHARD    = 14344,

	NEXUS_CRYSTAL   = 20725,
}
PluribusHiveAuctionator.DE_MAT = DE_MAT

-- Conservative Classic fallback unit prices (copper) used ONLY if AH/Hive has no price yet
local DE_FALLBACK_COPPER = {
	[10940] = 350,    -- Strange Dust (3.5s)
	[11083] = 1800,   -- Soul Dust (18s)
	[11137] = 2200,   -- Vision Dust (22s)
	[11176] = 3500,   -- Dream Dust (35s)
	[16204] = 4500,   -- Illusion Dust (45s)

	[10938] = 800,    -- Lesser Magic Essence (8s)
	[10939] = 2400,   -- Greater Magic Essence (24s)
	[10998] = 2500,   -- Lesser Astral Essence (25s)
	[11082] = 7500,   -- Greater Astral Essence (75s)
	[11134] = 3000,   -- Lesser Mystic Essence (30s)
	[11135] = 9000,   -- Greater Mystic Essence (90s)
	[11174] = 5500,   -- Lesser Nether Essence (55s)
	[11175] = 16500,  -- Greater Nether Essence (1.65g)
	[16202] = 15000,  -- Lesser Eternal Essence (1.5g)
	[16203] = 45000,  -- Greater Eternal Essence (4.5g)

	[10978] = 2500,   -- Small Glimmering Shard (25s)
	[11084] = 6000,   -- Large Glimmering Shard (60s)
	[11138] = 6500,   -- Small Glowing Shard (65s)
	[11139] = 12000,  -- Large Glowing Shard (1.2g)
	[11177] = 15000,  -- Small Radiant Shard (1.5g)
	[11178] = 28000,  -- Large Radiant Shard (2.8g)
	[14343] = 22000,  -- Small Brilliant Shard (2.2g)
	[14344] = 42000,  -- Large Brilliant Shard (4.2g)

	[20725] = 120000, -- Nexus Crystal (12g)
}

local DE_MAT_NAMES = {
	[10940] = "Seltsamer Staub",
	[11083] = "Seelenstaub",
	[11137] = "Visionsstaub",
	[11176] = "Traumstaub",
	[16204] = "Illusionsstaub",
	[10938] = "Geringe Magieessenz",
	[10939] = "Große Magieessenz",
	[10998] = "Geringe Astralessenz",
	[11082] = "Große Astralessenz",
	[11134] = "Geringe Mystikessenz",
	[11135] = "Große Mystikessenz",
	[11174] = "Geringe Netheressenz",
	[11175] = "Große Netheressenz",
	[16202] = "Geringe ewige Essenz",
	[16203] = "Große ewige Essenz",
	[10978] = "Kleiner Glimmersplitter",
	[11084] = "Großer Glimmersplitter",
	[11138] = "Kleiner leuchtender Splitter",
	[11139] = "Großer leuchtender Splitter",
	[11177] = "Kleiner strahlender Splitter",
	[11178] = "Großer strahlender Splitter",
	[14343] = "Kleiner glänzender Splitter",
	[14344] = "Großer glänzender Splitter",
	[20725] = "Nexuskristall",
}

-- Brackets for Uncommon (Quality 2): dustId, dustAvg, essId, essAvg, shardId
local DE_GREEN_BRACKETS = {
	{ min = 5,  max = 15, dust = 10940, dustAvg = 1.5, ess = 10938, essAvg = 1.5, shard = 10978 },
	{ min = 16, max = 20, dust = 10940, dustAvg = 2.5, ess = 10939, essAvg = 1.5, shard = 10978 },
	{ min = 21, max = 25, dust = 10940, dustAvg = 5.0, ess = 10998, essAvg = 1.5, shard = 10978 },
	{ min = 26, max = 30, dust = 11083, dustAvg = 1.5, ess = 11082, essAvg = 1.5, shard = 11084 },
	{ min = 31, max = 35, dust = 11083, dustAvg = 3.5, ess = 11134, essAvg = 1.5, shard = 11138 },
	{ min = 36, max = 40, dust = 11137, dustAvg = 1.5, ess = 11135, essAvg = 1.5, shard = 11139 },
	{ min = 41, max = 45, dust = 11137, dustAvg = 3.5, ess = 11174, essAvg = 1.5, shard = 11177 },
	{ min = 46, max = 50, dust = 11176, dustAvg = 1.5, ess = 11175, essAvg = 1.5, shard = 11178 },
	{ min = 51, max = 55, dust = 11176, dustAvg = 3.5, ess = 16202, essAvg = 1.5, shard = 14343 },
	{ min = 56, max = 70, dust = 16204, dustAvg = 1.5, ess = 16203, essAvg = 1.5, shard = 14344 },
}

local DE_BLUE_BRACKETS = {
	{ min = 1,  max = 25, drops = { { id = 10978, prob = 1.00, avg = 1.0 } } },
	{ min = 26, max = 30, drops = { { id = 11084, prob = 1.00, avg = 1.0 } } },
	{ min = 31, max = 35, drops = { { id = 11138, prob = 1.00, avg = 1.0 } } },
	{ min = 36, max = 40, drops = { { id = 11139, prob = 1.00, avg = 1.0 } } },
	{ min = 41, max = 45, drops = { { id = 11177, prob = 1.00, avg = 1.0 } } },
	{ min = 46, max = 50, drops = { { id = 11178, prob = 1.00, avg = 1.0 } } },
	{ min = 51, max = 55, drops = { { id = 14343, prob = 0.995, avg = 1.0 }, { id = 20725, prob = 0.005, avg = 1.0 } } },
	{ min = 56, max = 75, drops = { { id = 14344, prob = 0.995, avg = 1.0 }, { id = 20725, prob = 0.005, avg = 1.0 } } },
}

local DE_EPIC_BRACKETS = {
	{ min = 1,  max = 45, drops = { { id = 11177, prob = 1.00, avg = 2.0 } } },
	{ min = 46, max = 50, drops = { { id = 11178, prob = 1.00, avg = 2.0 } } },
	{ min = 51, max = 55, drops = { { id = 14343, prob = 1.00, avg = 2.0 } } },
	{ min = 56, max = 99, drops = { { id = 20725, prob = 1.00, avg = 1.0 } } },
}

local WEAPON_EQUIP_LOCS = {
	INVTYPE_WEAPON = true,
	INVTYPE_2HWEAPON = true,
	INVTYPE_WEAPONMAINHAND = true,
	INVTYPE_WEAPONOFFHAND = true,
	INVTYPE_RANGED = true,
	INVTYPE_RANGEDRIGHT = true,
	INVTYPE_THROWN = true,
}

local ARMOR_EQUIP_LOCS = {
	INVTYPE_HEAD = true,
	INVTYPE_NECK = true,
	INVTYPE_SHOULDER = true,
	INVTYPE_CHEST = true,
	INVTYPE_ROBE = true,
	INVTYPE_WAIST = true,
	INVTYPE_LEGS = true,
	INVTYPE_FEET = true,
	INVTYPE_WRIST = true,
	INVTYPE_HAND = true,
	INVTYPE_FINGER = true,
	INVTYPE_TRINKET = true,
	INVTYPE_CLOAK = true,
	INVTYPE_SHIELD = true,
	INVTYPE_HOLDABLE = true,
}

-- Category mappings for Advanced Filters (German & English aliases)
local FILTER_CATEGORIES = {
	{ key = "ALL",        label = "Alle Kategorien", classID = nil },
	{ key = "WEAPON",     label = "Waffen",          classID = 2 },
	{ key = "ARMOR",      label = "Rüstung",         classID = 4 },
	{ key = "CONSUMABLE", label = "Verbrauchbar",    classID = 0 },
	{ key = "TRADE",      label = "Handwerkswaren",  classID = 7 },
	{ key = "RECIPE",     label = "Rezepte",         classID = 9 },
	{ key = "CONTAINER",  label = "Behälter",        classID = 1 },
}

local FILTER_QUALITIES = {
	{ key = -1, label = "Alle Qualitäten" },
	{ key = 1,  label = "Gewöhnlich+" },
	{ key = 2,  label = "|cff1eff00Ungewöhnlich+|r" },
	{ key = 3,  label = "|cff0070ddSelten+|r" },
	{ key = 4,  label = "|cffa335eeEpisch+|r" },
}

-- ============================================================================
-- PERSISTENT DB & DEFAULTS
-- ============================================================================
local function EnsureDB()
	local root = PluribusHive and PluribusHive:GetDB() or {}
	if type(root.auctionator) ~= "table" then
		root.auctionator = {}
	end
	local adb = root.auctionator
	if type(adb.shoppingLists) ~= "table" then
		adb.shoppingLists = {
			{
				id = "consumables",
				name = "Verbrauchsgüter & Raids",
				items = {
					{ term = "Großer Heiltrank", name = "Großer Heiltrank", qty = 10 },
					{ term = "Großer Manatrank", name = "Großer Manatrank", qty = 10 },
					{ term = "Mungo", name = "Mungo", qty = 5 },
				},
			},
			{
				id = "professions",
				name = "Berufe & Handwerk",
				items = {
					{ term = "Runenstoff", name = "Runenstoff", qty = 40 },
					{ term = "Thoriumerz", name = "Thoriumerz", qty = 20 },
				},
			},
		}
	end
	if not adb.activeListId then
		adb.activeListId = "__TODO__"
	end
	if type(adb.sellPrefs) ~= "table" then
		adb.sellPrefs = {
			duration = 2,        -- 1=12h, 2=24h, 3=48h
			undercutMode = "smart",
			bidRatio = 0.95,
		}
	end
	if type(adb.dePrefs) ~= "table" then
		adb.dePrefs = {
			minProfitCopper = 100,
			minMarginPct = 5,
			includeAhCut = true,
			maxQuality = 4,
		}
	end
	return adb
end

function PluribusHiveAuctionator:GetDB()
	return EnsureDB()
end

-- ============================================================================
-- DISENCHANT EXPECTED MEAN VALUE ENGINE
-- ============================================================================
function PluribusHiveAuctionator:GetReagentMarketPrice(matID)
	matID = tonumber(matID)
	if not matID then return 0, true end
	if _G.PluribusHiveAuction and _G.PluribusHiveAuction.GetPrice then
		local rec = _G.PluribusHiveAuction:GetPrice(matID)
		if rec and tonumber(rec.copper) and tonumber(rec.copper) > 0 then
			return math.floor(tonumber(rec.copper)), false
		end
	end
	return DE_FALLBACK_COPPER[matID] or 0, true
end

function PluribusHiveAuctionator:IsDisenchantable(quality, itemLevel, equipLoc, itemClassID)
	quality = tonumber(quality) or 0
	itemLevel = tonumber(itemLevel) or 0
	if quality < 2 or quality > 4 then return false, nil end
	if itemLevel < 5 then return false, nil end
	if equipLoc and WEAPON_EQUIP_LOCS[equipLoc] then
		return true, "WEAPON"
	end
	if equipLoc and ARMOR_EQUIP_LOCS[equipLoc] then
		return true, "ARMOR"
	end
	if tonumber(itemClassID) == 2 then return true, "WEAPON" end
	if tonumber(itemClassID) == 4 then return true, "ARMOR" end
	return false, nil
end

function PluribusHiveAuctionator:GetDisenchantDrops(quality, itemLevel, equipLoc, itemClassID)
	local ok, kind = self:IsDisenchantable(quality, itemLevel, equipLoc, itemClassID)
	if not ok then return nil end

	if quality == 2 then
		local bracket = DE_GREEN_BRACKETS[#DE_GREEN_BRACKETS]
		for _, b in ipairs(DE_GREEN_BRACKETS) do
			if itemLevel >= b.min and itemLevel <= b.max then
				bracket = b
				break
			end
		end
		if kind == "WEAPON" then
			return {
				{ id = bracket.dust,  prob = 0.20, avg = bracket.dustAvg },
				{ id = bracket.ess,   prob = 0.75, avg = bracket.essAvg },
				{ id = bracket.shard, prob = 0.05, avg = 1.0 },
			}
		else
			return {
				{ id = bracket.dust,  prob = 0.75, avg = bracket.dustAvg },
				{ id = bracket.ess,   prob = 0.20, avg = bracket.essAvg },
				{ id = bracket.shard, prob = 0.05, avg = 1.0 },
			}
		end
	elseif quality == 3 then
		local bracket = DE_BLUE_BRACKETS[#DE_BLUE_BRACKETS]
		for _, b in ipairs(DE_BLUE_BRACKETS) do
			if itemLevel >= b.min and itemLevel <= b.max then
				bracket = b
				break
			end
		end
		return bracket.drops
	elseif quality == 4 then
		local bracket = DE_EPIC_BRACKETS[#DE_EPIC_BRACKETS]
		for _, b in ipairs(DE_EPIC_BRACKETS) do
			if itemLevel >= b.min and itemLevel <= b.max then
				bracket = b
				break
			end
		end
		return bracket.drops
	end
	return nil
end

-- Returns { meanCopper, netCopper, isEstimated, drops = { { id, name, prob, avg, unitPrice, ev } } }
function PluribusHiveAuctionator:CalculateMeanDisenchantValue(itemID, quality, itemLevel, equipLoc, itemClassID)
	if itemID and (not quality or not itemLevel or not equipLoc) then
		local _, _, q, ilvl, _, _, _, _, eq, _, _, clsID = PluribusUtils:GetItemInfo(itemID)
		quality = quality or q
		itemLevel = itemLevel or ilvl
		equipLoc = equipLoc or eq
		itemClassID = itemClassID or clsID
	end
	local drops = self:GetDisenchantDrops(quality, itemLevel, equipLoc, itemClassID)
	if not drops then return nil end

	local total = 0
	local anyEstimated = false
	local details = {}
	for _, d in ipairs(drops) do
		local unitPrice, isEst = self:GetReagentMarketPrice(d.id)
		if isEst then anyEstimated = true end
		local ev = d.prob * d.avg * unitPrice
		total = total + ev
		local liveName = PluribusUtils and PluribusUtils:GetItemInfo(d.id)
		details[#details + 1] = {
			id = d.id,
			name = liveName or DE_MAT_NAMES[d.id] or ("Item #" .. tostring(d.id)),
			prob = d.prob,
			avg = d.avg,
			unitPrice = unitPrice,
			ev = math.floor(ev + 0.5),
		}
	end
	local meanCopper = math.floor(total + 0.5)
	if meanCopper <= 0 then return nil end
	local adb = EnsureDB()
	local netCopper = adb.dePrefs.includeAhCut and math.floor(meanCopper * 0.95) or meanCopper
	return {
		meanCopper = meanCopper,
		netCopper = netCopper,
		isEstimated = anyEstimated,
		drops = details,
	}
end

function PluribusHiveAuctionator:EvaluateDisenchantDeal(itemID, buyoutCopper, opts)
	opts = opts or {}
	buyoutCopper = tonumber(buyoutCopper) or 0
	if buyoutCopper <= 0 then return nil end
	local deInfo = self:CalculateMeanDisenchantValue(itemID, opts.quality, opts.itemLevel, opts.equipLoc, opts.itemClassID)
	if not deInfo or deInfo.meanCopper <= 0 then return nil end

	-- Strictly priced below mean disenchant value
	if buyoutCopper >= deInfo.meanCopper then return nil end

	local adb = EnsureDB()
	local compareVal = opts.rawMean and deInfo.meanCopper or deInfo.netCopper
	local profit = compareVal - buyoutCopper
	if profit <= 0 then return nil end
	local marginPct = math.floor((profit / buyoutCopper) * 100 + 0.5)
	if not opts.ignoreThresholds then
		if profit < (adb.dePrefs.minProfitCopper or 100) then return nil end
		if marginPct < (adb.dePrefs.minMarginPct or 5) then return nil end
	end

	return {
		itemID = itemID,
		name = opts.name or (PluribusUtils and PluribusUtils:GetItemInfo(itemID)) or ("Item #" .. tostring(itemID)),
		link = opts.link,
		quality = opts.quality or 2,
		itemLevel = opts.itemLevel or 0,
		buyout = buyoutCopper,
		meanDE = deInfo.meanCopper,
		netDE = deInfo.netCopper,
		profit = profit,
		marginPct = marginPct,
		isEstimated = deInfo.isEstimated,
		drops = deInfo.drops,
		auctionIndex = opts.auctionIndex,
		seller = opts.seller,
		source = opts.source or "live",
	}
end

-- ============================================================================
-- AUCTIONATOR ADVANCED FILTER PARSER & MATCHER
-- ============================================================================
-- Supports Auctionator semicolon syntax:
--   "Term";Category;MinLvl;MaxLvl;MinIlvl;MaxIlvl;MinPriceG;MaxPriceG;Quality
function PluribusHiveAuctionator:ParseSearchTerm(raw)
	raw = tostring(raw or ""):match("^%s*(.-)%s*$")
	local filter = {
		raw = raw,
		name = "",
		exact = false,
		category = "ALL",
		minLevel = nil,
		maxLevel = nil,
		minIlvl = nil,
		maxIlvl = nil,
		minPrice = nil, -- copper
		maxPrice = nil, -- copper
		minQuality = -1,
		usableOnly = false,
		belowMarketOnly = false,
	}
	if raw == "" then return filter end

	local parts = {}
	local startPos = 1
	while true do
		local sep = raw:find(";", startPos, true)
		if not sep then
			parts[#parts + 1] = raw:sub(startPos):match("^%s*(.-)%s*$")
			break
		end
		parts[#parts + 1] = raw:sub(startPos, sep - 1):match("^%s*(.-)%s*$")
		startPos = sep + 1
	end

	local namePart = parts[1] or ""
	if namePart:sub(1, 1) == '"' and namePart:sub(-1) == '"' and #namePart >= 2 then
		filter.exact = true
		filter.name = namePart:sub(2, -2)
	else
		filter.name = namePart
	end

	if parts[2] and parts[2] ~= "" then
		local cLow = parts[2]:lower()
		for _, cat in ipairs(FILTER_CATEGORIES) do
			if cat.key:lower() == cLow or cat.label:lower():find(cLow, 1, true) then
				filter.category = cat.key
				break
			end
		end
	end
	if tonumber(parts[3]) then filter.minLevel = tonumber(parts[3]) end
	if tonumber(parts[4]) then filter.maxLevel = tonumber(parts[4]) end
	if tonumber(parts[5]) then filter.minIlvl = tonumber(parts[5]) end
	if tonumber(parts[6]) then filter.maxIlvl = tonumber(parts[6]) end
	if tonumber(parts[7]) then filter.minPrice = math.floor(tonumber(parts[7]) * 10000) end
	if tonumber(parts[8]) then filter.maxPrice = math.floor(tonumber(parts[8]) * 10000) end
	if tonumber(parts[9]) then filter.minQuality = tonumber(parts[9]) end

	return filter
end

function PluribusHiveAuctionator:MatchesAdvancedFilter(listing, filter)
	if not listing or not filter then return true end
	local nameLow = tostring(listing.name or ""):lower()
	local qLow = tostring(filter.name or ""):lower()
	if qLow ~= "" then
		if filter.exact then
			if nameLow ~= qLow then return false end
		else
			if not nameLow:find(qLow, 1, true) then return false end
		end
	end

	if filter.category and filter.category ~= "ALL" then
		local wantedClassID = nil
		for _, cat in ipairs(FILTER_CATEGORIES) do
			if cat.key == filter.category then
				wantedClassID = cat.classID
				break
			end
		end
		if wantedClassID ~= nil and listing.classID ~= nil and tonumber(listing.classID) ~= wantedClassID then
			return false
		end
	end

	if filter.minQuality and filter.minQuality >= 0 then
		if (tonumber(listing.quality) or 0) < filter.minQuality then return false end
	end
	if filter.minLevel and listing.reqLevel then
		if tonumber(listing.reqLevel) < filter.minLevel then return false end
	end
	if filter.maxLevel and listing.reqLevel then
		if tonumber(listing.reqLevel) > filter.maxLevel then return false end
	end
	if filter.minIlvl and listing.itemLevel then
		if tonumber(listing.itemLevel) < filter.minIlvl then return false end
	end
	if filter.maxIlvl and listing.itemLevel then
		if tonumber(listing.itemLevel) > filter.maxIlvl then return false end
	end

	local unitPrice = tonumber(listing.unitPrice) or 0
	if filter.minPrice and unitPrice > 0 and unitPrice < filter.minPrice then return false end
	if filter.maxPrice and unitPrice > 0 and unitPrice > filter.maxPrice then return false end
	if filter.usableOnly and listing.canUse == false then return false end
	if filter.belowMarketOnly and listing.marketPct and listing.marketPct > 95 then return false end

	return true
end

-- ============================================================================
-- AUCTIONATOR SMART UNDERCUT & SELLING MATH
-- ============================================================================
function PluribusHiveAuctionator:CalculateUndercutPrice(lowestUnitCopper, marketCopper, vendorCopper, mode)
	mode = mode or EnsureDB().sellPrefs.undercutMode or "smart"
	lowestUnitCopper = tonumber(lowestUnitCopper) or 0
	marketCopper = tonumber(marketCopper) or 0
	vendorCopper = tonumber(vendorCopper) or 0

	local base = lowestUnitCopper > 0 and lowestUnitCopper or marketCopper
	local suggested
	if base > 0 then
		if lowestUnitCopper > 0 then
			if mode == "1c" then
				suggested = base - 1
			elseif mode == "1s" then
				suggested = (base > 100) and (base - 100) or (base - 1)
			elseif mode == "1pct" then
				suggested = math.floor(base * 0.99)
			else -- "smart"
				if base < 1000 then
					suggested = base - 1
				elseif base < 100000 then
					suggested = base - 100
				elseif base < 1000000 then
					suggested = base - 1000
				else
					suggested = base - 10000
				end
			end
		else
			suggested = base
		end
	elseif vendorCopper > 0 then
		suggested = math.floor(vendorCopper * 1.6)
	else
		suggested = 100
	end

	if suggested < 1 then suggested = 1 end
	local floorWarning = (vendorCopper > 0 and suggested < math.floor(vendorCopper * 1.06))
	return suggested, floorWarning
end

function PluribusHiveAuctionator:CopperToGSK(copper)
	copper = math.max(0, math.floor(tonumber(copper) or 0))
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	return g, s, c
end

function PluribusHiveAuctionator:GSKToCopper(g, s, c)
	return math.max(0, math.floor((tonumber(g) or 0) * 10000 + (tonumber(s) or 0) * 100 + (tonumber(c) or 0)))
end

-- ============================================================================
-- CLASSIC / MODERN AH ROW PARSER (FULL DETAILS)
-- ============================================================================
local function ParseFullClassicAuctionRow(listType, index)
	if not GetAuctionItemInfo then return nil end
	local name, texture, count, quality, canUse, level, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17 = GetAuctionItemInfo(listType, index)
	if not name then return nil end

	local minBid, buyoutPrice, bidAmount, owner, itemID
	if type(a7) == "string" then
		-- 1.14+/Classic Era/1.60.1
		minBid = tonumber(a8) or 0
		buyoutPrice = tonumber(a10) or 0
		bidAmount = tonumber(a11) or 0
		owner = a14
		itemID = tonumber(a17)
	else
		-- 1.12
		minBid = tonumber(a7) or 0
		buyoutPrice = tonumber(a9) or 0
		bidAmount = tonumber(a10) or 0
		owner = a12
		itemID = tonumber(a17)
	end

	local link = GetAuctionItemLink and GetAuctionItemLink(listType, index) or nil
	if not itemID and link and PluribusUtils then
		itemID = PluribusUtils:GetItemIDFromHyperlink(link)
	end

	local stack = math.max(1, tonumber(count) or 1)
	local effTotal = (buyoutPrice > 0 and buyoutPrice) or (bidAmount > 0 and bidAmount) or minBid
	local unitPrice = effTotal > 0 and math.max(1, math.floor(effTotal / stack)) or 0
	local unitBuyout = buyoutPrice > 0 and math.max(1, math.floor(buyoutPrice / stack)) or 0

	local _, _, infoQ, itemLevel, reqLevel, _, _, _, equipLoc, infoIcon, _, classID = PluribusUtils:GetItemInfo(link or itemID)
	local marketRec = itemID and _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(itemID)
	local marketCopper = marketRec and tonumber(marketRec.copper) or nil
	local marketPct = (marketCopper and marketCopper > 0 and unitPrice > 0)
		and math.floor((unitPrice / marketCopper) * 100 + 0.5) or nil

	return {
		index = index,
		itemID = itemID,
		name = name,
		link = link,
		icon = texture or infoIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
		count = stack,
		quality = tonumber(quality) or infoQ or 1,
		canUse = (canUse ~= false and canUse ~= 0),
		reqLevel = tonumber(level) or tonumber(reqLevel) or 0,
		itemLevel = tonumber(itemLevel) or 0,
		equipLoc = equipLoc,
		classID = classID,
		minBid = minBid,
		bidAmount = bidAmount,
		buyout = buyoutPrice,
		unitPrice = unitPrice,
		unitBuyout = unitBuyout,
		owner = owner or "",
		marketCopper = marketCopper,
		marketPct = marketPct,
	}
end

-- ============================================================================
-- BAG SCANNER FOR AUCTIONATOR SELLING (SOULBOUND-SAFE)
-- ============================================================================
local function IsBagSlotSoulbound(bag, slot)
	if C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
		local ok, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
		if ok and loc then
			local ok2, bound = pcall(C_Item.IsBound, loc)
			if ok2 then return bound == true end
		end
	end
	if not PluribusHiveAuctionator._scanTip then
		local tip = CreateFrame("GameTooltip", "PluribusAuctionatorScanTooltip", UIParent, "GameTooltipTemplate")
		tip:SetOwner(UIParent, "ANCHOR_NONE")
		PluribusHiveAuctionator._scanTip = tip
	end
	local tip = PluribusHiveAuctionator._scanTip
	tip:ClearLines()
	local ok = pcall(tip.SetBagItem, tip, bag, slot)
	if not ok then return false end
	local sbStr = _G.ITEM_SOULBOUND or "Soulbound"
	local bopStr = _G.ITEM_BIND_ON_PICKUP or "Binds when picked up"
	local bnetStr = _G.ITEM_BNETACCOUNTBOUND or "Account Bound"
	for i = 2, math.min(6, tip:NumLines() or 0) do
		local fs = _G["PluribusAuctionatorScanTooltipTextLeft" .. i]
		local txt = fs and fs:GetText()
		if txt and (txt == sbStr or txt == bopStr or txt == bnetStr or txt:find("Seelengebunden", 1, true)) then
			return true
		end
	end
	return false
end

function PluribusHiveAuctionator:ScanSellableBagItems()
	local byKey = {}
	local list = {}

	local getNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
	local getInfo = (C_Container and C_Container.GetContainerItemInfo) or nil
	if not getNumSlots then return list end

	for bag = 0, 4 do
		local slots = tonumber(getNumSlots(bag)) or 0
		for slot = 1, slots do
			local itemID, count, link, icon, quality, locked
			if getInfo then
				local info = getInfo(bag, slot)
				if info and info.itemID then
					itemID = info.itemID
					count = info.stackCount or 1
					link = info.hyperlink
					icon = info.iconFileID
					quality = info.quality
					locked = info.isLocked
				end
			elseif GetContainerItemInfo then
				local tex, cnt, lck, q, _, _, lnk, _, _, id = GetContainerItemInfo(bag, slot)
				itemID = id or (lnk and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(lnk))
				count = cnt or 1
				link = lnk
				icon = tex
				quality = q
				locked = lck
			end

			if itemID and not locked and not IsBagSlotSoulbound(bag, slot) then
				local name, iLink, iQ, itemLevel, _, _, _, maxStack, equipLoc, iIcon, sellPrice, classID = PluribusUtils:GetItemInfo(link or itemID)
				quality = quality or iQ or 1
				-- Skip quest/gray trash unless user specifically searches, keep quality >= 1
				if quality >= 1 and name then
					local key = tostring(itemID)
					local rec = byKey[key]
					if not rec then
						local marketRec = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(itemID)
						local marketCopper = marketRec and tonumber(marketRec.copper) or 0
						local deInfo = self:CalculateMeanDisenchantValue(itemID, quality, itemLevel, equipLoc, classID)
						rec = {
							itemID = itemID,
							name = name,
							link = link or iLink,
							icon = icon or iIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
							quality = quality,
							itemLevel = itemLevel or 0,
							equipLoc = equipLoc,
							classID = classID,
							maxStack = math.max(1, tonumber(maxStack) or 1),
							vendorPrice = tonumber(sellPrice) or 0,
							marketCopper = marketCopper,
							meanDE = deInfo and deInfo.meanCopper or 0,
							totalCount = 0,
							bag = bag,
							slot = slot,
							slotCount = count or 1,
						}
						byKey[key] = rec
						list[#list + 1] = rec
					end
					rec.totalCount = rec.totalCount + (count or 1)
				end
			end
		end
	end

	table.sort(list, function(a, b)
		local av = (a.marketCopper or 0) * (a.totalCount or 1)
		local bv = (b.marketCopper or 0) * (b.totalCount or 1)
		if av ~= bv then return av > bv end
		if a.quality ~= b.quality then return a.quality > b.quality end
		return (a.name or "") < (b.name or "")
	end)
	self.bagItems = list
	return list
end

-- ============================================================================
-- SHOPPING LISTS & SEAMLESS TO-DO LIST INTEGRATION
-- ============================================================================
function PluribusHiveAuctionator:GetLiveTodoShoppingItems()
	local out = {}
	if not _G.PluribusHiveProfessions or not _G.PluribusHiveProfessions.GetAggregatedShoppingMaterials then
		return out
	end
	local agg = _G.PluribusHiveProfessions:GetAggregatedShoppingMaterials() or {}
	for itemID, m in pairs(agg) do
		local id = tonumber(itemID) or tonumber(m.itemID)
		if id and id > 0 then
			local owned = _G.PluribusHiveProfessions:GetOwnedCount(id) or 0
			local qty = tonumber(m.qty) or 1
			local missing = math.max(0, qty - owned)
			local mode = _G.PluribusHiveProfessions:GetItemTodoMode(id) or "BUY"
			local name, link, quality, _, _, _, _, _, _, icon = PluribusUtils:GetItemInfo(id)
			local marketRec = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(id)
			local marketCopper = marketRec and tonumber(marketRec.copper) or 0
			out[#out + 1] = {
				itemID = id,
				name = name or ("Item #" .. tostring(id)),
				term = name or ("Item #" .. tostring(id)),
				link = link,
				quality = quality or 1,
				icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
				qty = qty,
				owned = owned,
				missing = missing,
				mode = mode,
				direct = m.direct == true,
				fromRecipes = m.fromRecipes,
				marketCopper = marketCopper,
				isTodo = true,
			}
		end
	end
	table.sort(out, function(a, b)
		if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
		if (a.mode == "BUY") ~= (b.mode == "BUY") then return a.mode == "BUY" end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

function PluribusHiveAuctionator:GetActiveShoppingList()
	local adb = EnsureDB()
	if adb.activeListId == "__TODO__" then
		return {
			id = "__TODO__",
			name = "To-Do Liste (Live)",
			isVirtualTodo = true,
			items = self:GetLiveTodoShoppingItems(),
		}
	end
	for _, sl in ipairs(adb.shoppingLists) do
		if sl.id == adb.activeListId then
			return sl
		end
	end
	adb.activeListId = "__TODO__"
	return self:GetActiveShoppingList()
end

function PluribusHiveAuctionator:CreateShoppingList(name)
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then return nil end
	local adb = EnsureDB()
	local id = "list_" .. tostring(time()) .. "_" .. tostring(math.random(100, 999))
	local sl = { id = id, name = name, items = {} }
	table.insert(adb.shoppingLists, sl)
	adb.activeListId = id
	return sl
end

function PluribusHiveAuctionator:DeleteActiveShoppingList()
	local adb = EnsureDB()
	if adb.activeListId == "__TODO__" then return false end
	for i, sl in ipairs(adb.shoppingLists) do
		if sl.id == adb.activeListId then
			table.remove(adb.shoppingLists, i)
			adb.activeListId = "__TODO__"
			return true
		end
	end
	return false
end

function PluribusHiveAuctionator:AddTermToActiveShoppingList(rawTerm, itemID, qty)
	rawTerm = tostring(rawTerm or ""):match("^%s*(.-)%s*$")
	if rawTerm == "" and not itemID then return false end
	local adb = EnsureDB()
	if adb.activeListId == "__TODO__" then
		-- Adding directly while viewing To-Do list adds straight into HiveProfessions To-Do!
		if itemID and _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.AddNeededMaterial then
			_G.PluribusHiveProfessions:AddNeededMaterial(itemID, qty or 20)
			return true
		end
		-- Try resolving itemID from AH price cache by name
		local resolvedID = self:FindItemIDByName(rawTerm)
		if resolvedID and _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.AddNeededMaterial then
			_G.PluribusHiveProfessions:AddNeededMaterial(resolvedID, qty or 20)
			return true
		end
		-- Fallback: add into first custom shopping list so text-only filter terms still work
		if #adb.shoppingLists == 0 then
			self:CreateShoppingList("Einkaufsliste")
		end
		adb.activeListId = adb.shoppingLists[1].id
	end
	local sl = self:GetActiveShoppingList()
	if sl and not sl.isVirtualTodo then
		sl.items = sl.items or {}
		local parsed = self:ParseSearchTerm(rawTerm)
		table.insert(sl.items, {
			term = rawTerm,
			name = parsed.name ~= "" and parsed.name or rawTerm,
			itemID = tonumber(itemID),
			qty = tonumber(qty) or 1,
		})
		return true
	end
	return false
end

function PluribusHiveAuctionator:RemoveItemFromActiveShoppingList(idx, itemID)
	local sl = self:GetActiveShoppingList()
	if not sl then return false end
	if sl.isVirtualTodo then
		if itemID and _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.RemoveNeededMaterial then
			return _G.PluribusHiveProfessions:RemoveNeededMaterial(itemID)
		end
		return false
	end
	if sl.items and sl.items[idx] then
		table.remove(sl.items, idx)
		return true
	end
	return false
end

function PluribusHiveAuctionator:FindItemIDByName(name)
	local q = tostring(name or ""):lower():match("^%s*(.-)%s*$")
	if q == "" then return nil end
	local db = PluribusHive and PluribusHive:GetDB()
	if db and db.prices then
		for id, rec in pairs(db.prices) do
			if type(rec) == "table" and rec.name and rec.name:lower() == q then
				return tonumber(id)
			end
		end
	end
	return nil
end

function PluribusHiveAuctionator:ToggleItemInTodo(itemID, qty)
	itemID = tonumber(itemID)
	if not itemID or not _G.PluribusHiveProfessions then return false end
	local agg = _G.PluribusHiveProfessions:GetAggregatedShoppingMaterials() or {}
	if agg[itemID] and agg[itemID].direct then
		_G.PluribusHiveProfessions:RemoveNeededMaterial(itemID)
		return false
	else
		_G.PluribusHiveProfessions:AddNeededMaterial(itemID, qty or 20)
		return true
	end
end

-- ============================================================================
-- LIVE AH QUERY DISPATCH (SELLING / SHOPPING / DISENCHANT)
-- ============================================================================
function PluribusHiveAuctionator:RunAHQuery(filter, kind, page)
	if not _G.PluribusHiveAuction or not _G.PluribusHiveAuction.ahOpen then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Bitte zuerst das Auktionshaus öffnen.|r", 2.5)
		end
		return false
	end

	filter = filter or self:ParseSearchTerm("")
	self.pendingQueryKind = kind or "shop"
	self.pendingQueryFilter = filter
	page = tonumber(page) or 0

	-- Modern C_AuctionHouse fallback
	if C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
		pcall(function()
			C_AuctionHouse.SendBrowseQuery({
				searchString = filter.name or "",
				sorts = { { sortOrder = 0, reverseSort = false } },
				filters = {},
			})
		end)
		return true
	end

	-- Classic QueryAuctionItems
	if QueryAuctionItems then
		if CanSendAuctionQuery then
			local ok, canQuery = pcall(CanSendAuctionQuery)
			if ok and not canQuery then
				if C_Timer and C_Timer.After then
					C_Timer.After(0.55, function()
						if _G.PluribusHiveAuction and _G.PluribusHiveAuction.ahOpen then
							PluribusHiveAuctionator:RunAHQuery(filter, kind, page)
						end
					end)
				end
				return false
			end
		end

		local classIndex = nil
		if filter.category and filter.category ~= "ALL" and GetAuctionItemClasses then
			local classes = { GetAuctionItemClasses() }
			local wanted = nil
			for _, cat in ipairs(FILTER_CATEGORIES) do
				if cat.key == filter.category then wanted = cat.classID; break end
			end
			-- Classic classIndex maps 1=Weapon, 2=Armor, 3=Container, 4=Consumable, 5=Trade Goods, 7=Recipe
			local classicMap = { [2] = 1, [4] = 2, [1] = 3, [0] = 4, [7] = 5, [9] = 7 }
			classIndex = wanted and classicMap[wanted] or nil
			if classIndex and not classes[classIndex] then classIndex = nil end
		end

		local minLvl = filter.minLevel or ""
		local maxLvl = filter.maxLevel or ""
		local qualityIdx = (filter.minQuality and filter.minQuality >= 0) and filter.minQuality or 0
		local usable = filter.usableOnly and true or false
		local exact = filter.exact and true or false

		if SortAuctionSetSort then
			pcall(SortAuctionSetSort, "list", "buyout", false)
		end
		local ok = pcall(QueryAuctionItems, filter.name or "", minLvl, maxLvl, page, usable, qualityIdx, false, exact, nil)
		if not ok then
			pcall(QueryAuctionItems, filter.name or "", minLvl, maxLvl, 0, classIndex or 0, 0, page, usable and 1 or 0, qualityIdx)
		end
		return true
	end

	return false
end

function PluribusHiveAuctionator:SearchItemForSelling(bagItem)
	if not bagItem then return end
	self.selectedBagItem = bagItem
	self.competingListings = {}
	self:RefreshSellPriceInputsFromCompetitors()
	if _G.PluribusHiveAuction and _G.PluribusHiveAuction.ahOpen then
		local filter = self:ParseSearchTerm('"' .. tostring(bagItem.name or "") .. '"')
		self:RunAHQuery(filter, "sell", 0)
	end
	self:RefreshActiveView()
end

function PluribusHiveAuctionator:ScanOwnerAuctions()
	self.ownerAuctions = {}
	if not GetNumAuctionItems then return end
	local ok, numOwner = pcall(GetNumAuctionItems, "owner")
	if not ok or not numOwner then return end
	for i = 1, numOwner do
		local row = ParseFullClassicAuctionRow("owner", i)
		if row then
			local lowest = row.marketCopper or 0
			local isUndercut = (lowest > 0 and row.unitBuyout > 0 and lowest < row.unitBuyout)
			row.isUndercut = isUndercut
			self.ownerAuctions[#self.ownerAuctions + 1] = row
		end
	end
	table.sort(self.ownerAuctions, function(a, b)
		if a.isUndercut ~= b.isUndercut then return a.isUndercut end
		return (a.name or "") < (b.name or "")
	end)
end

-- ============================================================================
-- DISENCHANT DEAL SCANNER (INSTANT CACHE + LIVE AH SNIPER)
-- ============================================================================
function PluribusHiveAuctionator:ScanCachedDisenchantDeals()
	local deals = {}
	local seenKeys = {}

	-- 1) First scan currently loaded live AH page ("list") so live buyouts have instant 1-click buy!
	if GetNumAuctionItems and _G.PluribusHiveAuction and _G.PluribusHiveAuction.ahOpen then
		local ok, numBatch = pcall(GetNumAuctionItems, "list")
		if ok and numBatch and numBatch > 0 then
			for i = 1, math.min(numBatch, 1000) do
				local row = ParseFullClassicAuctionRow("list", i)
				if row and row.buyout > 0 and row.count == 1 then
					local deal = self:EvaluateDisenchantDeal(row.itemID, row.buyout, {
						name = row.name,
						link = row.link,
						quality = row.quality,
						itemLevel = row.itemLevel,
						equipLoc = row.equipLoc,
						itemClassID = row.classID,
						auctionIndex = i,
						seller = row.owner,
						source = "live",
					})
					if deal then
						deals[#deals + 1] = deal
						seenKeys["live:" .. tostring(i)] = true
					end
				end
			end
		end
	end

	-- 2) Also include any accumulated live DE scan pool
	for _, d in ipairs(self.deLivePool or {}) do
		local k = "live:" .. tostring(d.auctionIndex or d.itemID)
		if not seenKeys[k] then
			deals[#deals + 1] = d
			seenKeys[k] = true
		end
	end

	-- 3) Supplement with cached AH prices (db.prices) so user immediately sees DE bargains even before paging
	local db = PluribusHive and PluribusHive:GetDB()
	if db and db.prices then
		local checked = 0
		for itemID, rec in pairs(db.prices) do
			if type(rec) == "table" and tonumber(rec.quality) and tonumber(rec.quality) >= 2 and tonumber(rec.quality) <= 4 then
				local p = tonumber(rec.minCopper) or tonumber(rec.copper) or 0
				if p > 0 then
					local id = tonumber(itemID)
					local name, link, q, ilvl, _, _, _, _, eq, _, _, clsID = PluribusUtils:GetItemInfo(id)
					if eq and eq ~= "" then
						local deal = self:EvaluateDisenchantDeal(id, p, {
							name = name or rec.name,
							link = link,
							quality = q or rec.quality,
							itemLevel = ilvl,
							equipLoc = eq,
							itemClassID = clsID,
							source = "cache",
						})
						if deal then
							deals[#deals + 1] = deal
						end
					end
				end
				checked = checked + 1
				if checked >= 1500 then break end
			end
		end
	end

	table.sort(deals, function(a, b)
		if (a.source == "live") ~= (b.source == "live") then return a.source == "live" end
		if a.profit ~= b.profit then return a.profit > b.profit end
		return a.marginPct > b.marginPct
	end)

	self.deDeals = deals
	return deals
end

function PluribusHiveAuctionator:StartLiveDisenchantScan()
	if not _G.PluribusHiveAuction or not _G.PluribusHiveAuction.ahOpen then
		self:ScanCachedDisenchantDeals()
		self:RefreshActiveView()
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24AH geschlossen — zeige Entzauber-Schnäppchen aus dem Cache.|r", 3)
		end
		return
	end
	self.deLiveScanActive = true
	self.deScanPage = 0
	self.deScanCategoryIdx = 1
	self.deLivePool = {}
	self:QueryNextDisenchantPage()
	self:RefreshActiveView()
end

function PluribusHiveAuctionator:StopLiveDisenchantScan()
	self.deLiveScanActive = false
	self:ScanCachedDisenchantDeals()
	self:RefreshActiveView()
end

function PluribusHiveAuctionator:QueryNextDisenchantPage()
	if not self.deLiveScanActive then return end
	local cats = { "ARMOR", "WEAPON" }
	local catKey = cats[self.deScanCategoryIdx]
	if not catKey then
		self.deLiveScanActive = false
		self:ScanCachedDisenchantDeals()
		self:RefreshActiveView()
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cff4ade80Entzaubern-Scan abgeschlossen: |r" .. tostring(#self.deDeals) .. " Deals gefunden!", 3)
		end
		return
	end
	local filter = self:ParseSearchTerm("")
	filter.category = catKey
	filter.minQuality = 2 -- Uncommon+
	self:RunAHQuery(filter, "de", self.deScanPage)
end

-- ============================================================================
-- HANDLE LIVE AH SEARCH RESULTS
-- ============================================================================
function PluribusHiveAuctionator:OnAuctionListUpdate()
	if not GetNumAuctionItems then return end
	local ok, numBatch, totalAuctions = pcall(GetNumAuctionItems, "list")
	if not ok or not numBatch then return end

	if self.pendingQueryKind == "sell" and self.selectedBagItem then
		local targetID = self.selectedBagItem.itemID
		local targetName = tostring(self.selectedBagItem.name or ""):lower()
		local me = (UnitName and UnitName("player")) or ""
		local comps = {}
		for i = 1, math.min(numBatch, 300) do
			local row = ParseFullClassicAuctionRow("list", i)
			if row and ((targetID and row.itemID == targetID) or row.name:lower() == targetName) then
				row.isMine = (me ~= "" and row.owner == me)
				comps[#comps + 1] = row
			end
		end
		table.sort(comps, function(a, b)
			local ap = (a.unitBuyout > 0 and a.unitBuyout) or a.unitPrice or 999999999
			local bp = (b.unitBuyout > 0 and b.unitBuyout) or b.unitPrice or 999999999
			return ap < bp
		end)
		self.competingListings = comps
		self.pendingQueryKind = nil
		self:RefreshSellPriceInputsFromCompetitors()
		self:RefreshActiveView()
		return
	end

	if self.pendingQueryKind == "de" and self.deLiveScanActive then
		for i = 1, math.min(numBatch, 500) do
			local row = ParseFullClassicAuctionRow("list", i)
			if row and row.buyout > 0 and row.count == 1 then
				local deal = self:EvaluateDisenchantDeal(row.itemID, row.buyout, {
					name = row.name,
					link = row.link,
					quality = row.quality,
					itemLevel = row.itemLevel,
					equipLoc = row.equipLoc,
					itemClassID = row.classID,
					auctionIndex = i,
					seller = row.owner,
					source = "live",
				})
				if deal then
					self.deLivePool[#self.deLivePool + 1] = deal
				end
			end
		end
		self:ScanCachedDisenchantDeals()
		self:RefreshActiveView()

		local maxPages = math.min(6, math.ceil((tonumber(totalAuctions) or 0) / 50))
		if self.deScanPage + 1 < maxPages and numBatch > 0 then
			self.deScanPage = self.deScanPage + 1
		else
			self.deScanPage = 0
			self.deScanCategoryIdx = self.deScanCategoryIdx + 1
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.45, function()
				if PluribusHiveAuctionator.deLiveScanActive then
					PluribusHiveAuctionator:QueryNextDisenchantPage()
				end
			end)
		end
		return
	end

	if self.pendingQueryKind == "shop" then
		local filter = self.pendingQueryFilter or self:ParseSearchTerm("")
		local results = {}
		for i = 1, math.min(numBatch, 500) do
			local row = ParseFullClassicAuctionRow("list", i)
			if row and self:MatchesAdvancedFilter(row, filter) then
				local deDeal = (row.buyout > 0 and row.count == 1) and self:EvaluateDisenchantDeal(row.itemID, row.buyout, {
					name = row.name,
					link = row.link,
					quality = row.quality,
					itemLevel = row.itemLevel,
					equipLoc = row.equipLoc,
					itemClassID = row.classID,
					ignoreThresholds = true,
				}) or nil
				row.deDeal = deDeal
				results[#results + 1] = row
			end
		end
		table.sort(results, function(a, b)
			local ap = (a.unitBuyout > 0 and a.unitBuyout) or a.unitPrice or 999999999
			local bp = (b.unitBuyout > 0 and b.unitBuyout) or b.unitPrice or 999999999
			return ap < bp
		end)
		if self.batchActive then
			for _, r in ipairs(results) do
				self.shoppingResults[#self.shoppingResults + 1] = r
			end
			self:ProcessNextBatchSearch()
		else
			self.shoppingResults = results
			self.pendingQueryKind = nil
		end
		self:RefreshActiveView()
	end
end

function PluribusHiveAuctionator:StartBatchSearchActiveList()
	local sl = self:GetActiveShoppingList()
	if not sl or not sl.items or #sl.items == 0 then return end
	self.batchQueue = {}
	for _, it in ipairs(sl.items) do
		if (not sl.isVirtualTodo) or ((it.missing or 0) > 0 and it.mode ~= "FARM") then
			self.batchQueue[#self.batchQueue + 1] = it.term or it.name
		end
	end
	if #self.batchQueue == 0 then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cff4ade80Alle To-Do Kauf-Items sind bereits vollständig vorhanden!|r", 2.5)
		end
		return
	end
	self.shoppingResults = {}
	self.batchActive = true
	self:ProcessNextBatchSearch()
end

function PluribusHiveAuctionator:ProcessNextBatchSearch()
	if #self.batchQueue == 0 then
		self.batchActive = false
		self.pendingQueryKind = nil
		table.sort(self.shoppingResults, function(a, b)
			return (a.marketPct or 100) < (b.marketPct or 100)
		end)
		self:RefreshActiveView()
		return
	end
	local term = table.remove(self.batchQueue, 1)
	local filter = self:ParseSearchTerm(term)
	if C_Timer and C_Timer.After then
		C_Timer.After(0.35, function()
			if PluribusHiveAuctionator.batchActive then
				PluribusHiveAuctionator:RunAHQuery(filter, "shop", 0)
			end
		end)
	else
		self:RunAHQuery(filter, "shop", 0)
	end
end

-- ============================================================================
-- HARDWARE-EVENT-SAFE POST / BUY / CANCEL ACTIONS
-- ============================================================================
function PluribusHiveAuctionator:PostSelectedAuction(unitBuyoutCopper, stackSize, numStacks, durationCode)
	local item = self.selectedBagItem
	if not item then return false end
	unitBuyoutCopper = math.max(1, math.floor(tonumber(unitBuyoutCopper) or 0))
	stackSize = math.max(1, math.min(item.maxStack or 1, math.floor(tonumber(stackSize) or 1)))
	numStacks = math.max(1, math.floor(tonumber(numStacks) or 1))
	durationCode = tonumber(durationCode) or EnsureDB().sellPrefs.duration or 2

	-- Re-locate a live bag slot containing this itemID
	local bag, slot = item.bag, item.slot
	local getNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
	local getID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
	if getNumSlots and getID then
		if getID(bag, slot) ~= item.itemID then
			bag, slot = nil, nil
			for b = 0, 4 do
				for s = 1, (getNumSlots(b) or 0) do
					if getID(b, s) == item.itemID then
						bag, slot = b, s
						break
					end
				end
				if bag then break end
			end
		end
	end
	if not bag or not slot then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfff87171Item nicht mehr in der Tasche gefunden.|r", 2.5)
		end
		return false
	end

	-- Modern C_AuctionHouse API path
	if C_AuctionHouse and ItemLocation and ItemLocation.CreateFromBagAndSlot then
		local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
		if C_AuctionHouse.PostCommodity and (item.maxStack or 1) > 1 then
			local ok = pcall(C_AuctionHouse.PostCommodity, loc, durationCode, stackSize * numStacks, unitBuyoutCopper)
			if ok then
				if _G.PluribusUIFramework then
					_G.PluribusUIFramework:ShowNotification("|cff4ade80Auktion erstellt:|r " .. item.name, 2.5)
				end
				return true
			end
		elseif C_AuctionHouse.PostItem then
			local ok = pcall(C_AuctionHouse.PostItem, loc, durationCode, stackSize, nil, unitBuyoutCopper * stackSize)
			if ok then
				if _G.PluribusUIFramework then
					_G.PluribusUIFramework:ShowNotification("|cff4ade80Auktion erstellt:|r " .. item.name, 2.5)
				end
				return true
			end
		end
	end

	-- Classic AH Posting API (hardware click required)
	local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
	if pickup and ClickAuctionSellItemButton and StartAuction then
		if ClearCursor then pcall(ClearCursor) end
		pcall(pickup, bag, slot)
		pcall(ClickAuctionSellItemButton)
		if ClearCursor then pcall(ClearCursor) end

		local stackBuyout = unitBuyoutCopper * stackSize
		local bidRatio = EnsureDB().sellPrefs.bidRatio or 0.95
		local stackBid = math.max(1, math.floor(stackBuyout * bidRatio))
		local ok, err = pcall(StartAuction, stackBid, stackBuyout, durationCode, stackSize, numStacks)
		if ok then
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification(
					string.format("|cff4ade80Auktion erstellt:|r %dx%d %s à %s", numStacks, stackSize, item.name, PluribusUtils:FormatGold(unitBuyoutCopper)),
					3
				)
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(0.4, function()
					PluribusHiveAuctionator:ScanSellableBagItems()
					PluribusHiveAuctionator:RefreshActiveView()
				end)
			end
			return true
		else
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("|cfff87171Auktion fehlgeschlagen: |r" .. tostring(err or ""), 3)
			end
		end
	end
	return false
end

function PluribusHiveAuctionator:BuyoutListing(auctionIndex, buyoutCopper, itemName)
	auctionIndex = tonumber(auctionIndex)
	buyoutCopper = tonumber(buyoutCopper)
	if not auctionIndex or not buyoutCopper or buyoutCopper <= 0 then return false end
	if PlaceAuctionBid then
		local ok = pcall(PlaceAuctionBid, "list", auctionIndex, buyoutCopper)
		if ok and _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification(
				"|cff4ade80Gekauft:|r " .. tostring(itemName or "Item") .. " (" .. PluribusUtils:FormatGold(buyoutCopper) .. ")",
				2.5
			)
		end
		return ok
	end
	return false
end

function PluribusHiveAuctionator:CancelOwnerAuction(ownerIndex, itemName)
	ownerIndex = tonumber(ownerIndex)
	if not ownerIndex or not CancelAuction then return false end
	local ok = pcall(CancelAuction, ownerIndex)
	if ok and _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cfffbbf24Auktion abgebrochen:|r " .. tostring(itemName or ""), 2.5)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.35, function()
			PluribusHiveAuctionator:ScanOwnerAuctions()
			PluribusHiveAuctionator:RefreshActiveView()
		end)
	end
	return ok
end

-- ============================================================================
-- UNIFORM OBSIDIAN UI VIEWS MOUNTED IN AH DRAWER PANEL
-- ============================================================================
function PluribusHiveAuctionator:RefreshSellPriceInputsFromCompetitors()
	local v = self.views.sell
	local item = self.selectedBagItem
	if not v or not item then return end

	local lowest = 0
	for _, c in ipairs(self.competingListings or {}) do
		local p = (c.unitBuyout > 0 and c.unitBuyout) or c.unitPrice or 0
		if p > 0 and (lowest == 0 or p < lowest) then
			lowest = p
		end
	end
	local suggested, floorWarn = self:CalculateUndercutPrice(lowest, item.marketCopper, item.vendorPrice)
	local g, s, c = self:CopperToGSK(suggested)
	v.goldBox:SetText(tostring(g))
	v.silverBox:SetText(tostring(s))
	v.copperBox:SetText(tostring(c))
	local defStack = math.min(item.maxStack or 1, item.totalCount or 1)
	local defNum = math.max(1, math.floor((item.totalCount or 1) / math.max(1, defStack)))
	v.stackBox:SetText(tostring(defStack))
	v.numStacksBox:SetText(tostring(defNum))

	local warnStr = floorWarn and " |cfff87171(Unter Händlerpreis!)|r" or ""
	local deTip = (item.meanDE and item.meanDE > suggested)
		and (" |cffa855f7[DE: " .. PluribusUtils:FormatGold(item.meanDE) .. "]|r") or ""
	v.selectedLbl:SetText(PluribusUtils:GetQualityColor(item.quality) .. tostring(item.name):sub(1, 26) .. "|r x" .. tostring(item.totalCount) .. deTip .. warnStr)
end

function PluribusHiveAuctionator:BuildSellView(panel)
	local UI = _G.PluribusUIFramework
	local container = CreateFrame("Frame", nil, panel)
	container:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -54)
	container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	container:Hide()

	-- Sub-mode bar: Bag Selling vs My Auctions (Undercut check)
	local bagModeBtn = UI:CreateButton(container, "Taschen-Verkauf", 142, 22, function()
		PluribusHiveAuctionator.sellSubView = "bag"
		PluribusHiveAuctionator:ScanSellableBagItems()
		PluribusHiveAuctionator:RefreshActiveView()
	end, true)
	bagModeBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

	local ownerModeBtn = UI:CreateButton(container, "Unterboten prüfen", 142, 22, function()
		PluribusHiveAuctionator.sellSubView = "owner"
		PluribusHiveAuctionator:ScanOwnerAuctions()
		PluribusHiveAuctionator:RefreshActiveView()
	end)
	ownerModeBtn:SetPoint("LEFT", bagModeBtn, "RIGHT", 6, 0)

	local refreshBtn = UI:CreateButton(container, "Scan", 88, 22, function()
		if PluribusHiveAuctionator.sellSubView == "owner" then
			PluribusHiveAuctionator:ScanOwnerAuctions()
		else
			PluribusHiveAuctionator:ScanSellableBagItems()
		end
		PluribusHiveAuctionator:RefreshActiveView()
	end)
	refreshBtn:SetPoint("LEFT", ownerModeBtn, "RIGHT", 6, 0)

	-- Top bag/owner virtual list
	local bagVList = UI:CreateVirtualScrollList(container, {
		width = 384,
		height = 152,
		rowHeight = 30,
		rowGap = 2,
		wheelStep = 2,
		createRow = function(vp, idx, w, h)
			local row = UI:CreateListRow(vp, w, h, idx, function()
				if row._bagItem then
					PluribusHiveAuctionator:SearchItemForSelling(row._bagItem)
				elseif row._ownerAuction then
					PluribusHiveAuctionator:CancelOwnerAuction(row._ownerAuction.index, row._ownerAuction.name)
				end
			end)
			local ic = row:CreateTexture(nil, "ARTWORK")
			ic:SetSize(22, 22)
			ic:SetPoint("LEFT", row, "LEFT", 4, 0)
			ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			row._ic = ic

			local nameL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			nameL:SetPoint("LEFT", ic, "RIGHT", 6, 0)
			row._nameL = nameL

			local priceL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			priceL:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			row._priceL = priceL
			row:Hide()
			return row
		end,
		bindRow = function(row, item)
			row._ic:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			if PluribusHiveAuctionator.sellSubView == "owner" then
				row._bagItem = nil
				row._ownerAuction = item
				local tag = item.isUndercut and "|cfff87171[Unterboten - Klick: Abbr.]|r " or "|cff4ade80[OK]|r "
				row._nameL:SetText(tag .. PluribusUtils:GetQualityColor(item.quality) .. tostring(item.name or ""):sub(1, 20) .. "|r x" .. tostring(item.count or 1))
				row._priceL:SetText("|cfffbbf24" .. PluribusUtils:FormatGold(item.unitBuyout > 0 and item.unitBuyout or item.unitPrice) .. "|r")
			else
				row._ownerAuction = nil
				row._bagItem = item
				local deTag = (item.meanDE and item.meanDE > (item.marketCopper or 0) and item.meanDE > 0) and " |cffa855f7[DE!]|r" or ""
				row._nameL:SetText(PluribusUtils:GetQualityColor(item.quality) .. tostring(item.name or ""):sub(1, 22) .. "|r |cff94a3b8x" .. tostring(item.totalCount) .. "|r" .. deTag)
				local pTxt = (item.marketCopper and item.marketCopper > 0)
					and ("|cfffbbf24" .. PluribusUtils:FormatGold(item.marketCopper) .. "|r")
					or "|cff64748bKein Preis|r"
				row._priceL:SetText(pTxt)
			end
		end,
	})
	bagVList:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)

	-- Selected item post controls card
	local postCard = CreateFrame("Frame", nil, container, BackdropTemplateMixin and "BackdropTemplate" or nil)
	postCard:SetSize(384, 114)
	postCard:SetPoint("TOPLEFT", bagVList, "BOTTOMLEFT", 0, -6)
	UI:ApplyBackdrop(postCard, 0.08, 0.11, 0.16, 0.96, 0.24, 0.34, 0.48, 0.85)

	local selectedLbl = UI:CreateLabel(postCard, "|cff94a3b8Wähle oben ein Taschen-Item zum Verkaufen|r", 0.9, 0.95, 1, "GameFontHighlightSmall")
	selectedLbl:SetPoint("TOPLEFT", postCard, "TOPLEFT", 8, -7)

	-- Price G / S / K row
	local pLbl = UI:CreateLabel(postCard, "Stückpreis:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	pLbl:SetPoint("TOPLEFT", postCard, "TOPLEFT", 8, -28)

	local goldBox = UI:CreateInputBox(postCard, 48, 20)
	goldBox:SetPoint("LEFT", pLbl, "RIGHT", 6, 0)
	local gLbl = UI:CreateLabel(postCard, "|cfffbbf24g|r", 1, 1, 1, "GameFontHighlightSmall")
	gLbl:SetPoint("LEFT", goldBox, "RIGHT", 3, 0)

	local silverBox = UI:CreateInputBox(postCard, 34, 20)
	silverBox:SetPoint("LEFT", gLbl, "RIGHT", 6, 0)
	local sLbl = UI:CreateLabel(postCard, "|cffcbd5e1s|r", 1, 1, 1, "GameFontHighlightSmall")
	sLbl:SetPoint("LEFT", silverBox, "RIGHT", 3, 0)

	local copperBox = UI:CreateInputBox(postCard, 34, 20)
	copperBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
	local cLbl = UI:CreateLabel(postCard, "|cffd97706k|r", 1, 1, 1, "GameFontHighlightSmall")
	cLbl:SetPoint("LEFT", copperBox, "RIGHT", 3, 0)

	-- Duration selector buttons (12h / 24h / 48h)
	local durBtns = {}
	local durLabels = { { 1, "12h" }, { 2, "24h" }, { 3, "48h" } }
	local prevDur = cLbl
	for _, dInfo in ipairs(durLabels) do
		local dCode, dText = dInfo[1], dInfo[2]
		local b = UI:CreateButton(postCard, dText, 34, 20, function()
			EnsureDB().sellPrefs.duration = dCode
			for code, btn in pairs(durBtns) do
				if btn.SetBackdropBorderColor then
					if code == dCode then
						btn:SetBackdropBorderColor(0.22, 0.74, 0.97, 1)
					else
						btn:SetBackdropBorderColor(0.25, 0.32, 0.42, 0.8)
					end
				end
			end
		end)
		b:SetPoint("LEFT", prevDur, "RIGHT", prevDur == cLbl and 14 or 4, 0)
		durBtns[dCode] = b
		prevDur = b
	end

	-- Stack Size / Num Stacks / Post Button
	local stLbl = UI:CreateLabel(postCard, "Stapel:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	stLbl:SetPoint("TOPLEFT", postCard, "TOPLEFT", 8, -56)

	local stackBox = UI:CreateInputBox(postCard, 40, 20)
	stackBox:SetPoint("LEFT", stLbl, "RIGHT", 6, 0)

	local xLbl = UI:CreateLabel(postCard, "x Anzahl:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	xLbl:SetPoint("LEFT", stackBox, "RIGHT", 8, 0)

	local numStacksBox = UI:CreateInputBox(postCard, 40, 20)
	numStacksBox:SetPoint("LEFT", xLbl, "RIGHT", 6, 0)

	local postBtn = UI:CreateButton(postCard, "Auktion erstellen", 156, 24, function()
		local unitCopper = PluribusHiveAuctionator:GSKToCopper(goldBox:GetText(), silverBox:GetText(), copperBox:GetText())
		local st = tonumber(stackBox:GetText()) or 1
		local num = tonumber(numStacksBox:GetText()) or 1
		PluribusHiveAuctionator:PostSelectedAuction(unitCopper, st, num, EnsureDB().sellPrefs.duration)
	end, true)
	postBtn:SetPoint("BOTTOMRIGHT", postCard, "BOTTOMRIGHT", -8, 8)

	local undercutBtn = UI:CreateButton(postCard, "Auto-Undercut", 104, 24, function()
		PluribusHiveAuctionator:RefreshSellPriceInputsFromCompetitors()
	end)
	undercutBtn:SetPoint("BOTTOMLEFT", postCard, "BOTTOMLEFT", 8, 8)

	-- Live competing auctions list
	local compLbl = UI:CreateLabel(container, "|cff38bdf8Aktuelle Konkurrenz im AH (Klick zum Unterbieten):|r", 1, 1, 1, "GameFontHighlightSmall")
	compLbl:SetPoint("TOPLEFT", postCard, "BOTTOMLEFT", 2, -6)

	local compVList = UI:CreateVirtualScrollList(container, {
		width = 384,
		height = 76,
		rowHeight = 22,
		rowGap = 2,
		wheelStep = 2,
		createRow = function(vp, idx, w, h)
			local row = UI:CreateListRow(vp, w, h, idx, function()
				if row._compPrice and row._compPrice > 1 then
					local undercut = PluribusHiveAuctionator:CalculateUndercutPrice(row._compPrice, 0, 0)
					local g, s, c = PluribusHiveAuctionator:CopperToGSK(undercut)
					goldBox:SetText(tostring(g))
					silverBox:SetText(tostring(s))
					copperBox:SetText(tostring(c))
				end
			end)
			local lTxt = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			lTxt:SetPoint("LEFT", row, "LEFT", 6, 0)
			local rTxt = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			rTxt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			row._lTxt = lTxt
			row._rTxt = rTxt
			row:Hide()
			return row
		end,
		bindRow = function(row, c)
			local p = (c.unitBuyout > 0 and c.unitBuyout) or c.unitPrice or 0
			row._compPrice = p
			local who = c.isMine and "|cff4ade80(Du)|r" or ("|cff94a3b8" .. tostring(c.owner or "?"):sub(1, 14) .. "|r")
			row._lTxt:SetText("x" .. tostring(c.count or 1) .. "  " .. who)
			row._rTxt:SetText("|cfffbbf24" .. PluribusUtils:FormatGold(p) .. "/Stk|r")
		end,
	})
	compVList:SetPoint("TOPLEFT", compLbl, "BOTTOMLEFT", -2, -3)

	self.views.sell = {
		root = container,
		bagVList = bagVList,
		compVList = compVList,
		selectedLbl = selectedLbl,
		goldBox = goldBox,
		silverBox = silverBox,
		copperBox = copperBox,
		stackBox = stackBox,
		numStacksBox = numStacksBox,
		bagModeBtn = bagModeBtn,
		ownerModeBtn = ownerModeBtn,
	}
	return container
end

function PluribusHiveAuctionator:BuildShoppingView(panel)
	local UI = _G.PluribusUIFramework
	local container = CreateFrame("Frame", nil, panel)
	container:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -54)
	container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	container:Hide()

	-- Row 1: Shopping list selector + New / Delete / Search All
	local listDropdown = nil
	local function GetListOptions()
		local adb = EnsureDB()
		local opts = { { key = "__TODO__", label = "|cff4ade80★ To-Do Liste (Live)|r" } }
		for _, sl in ipairs(adb.shoppingLists or {}) do
			opts[#opts + 1] = { key = sl.id, label = sl.name }
		end
		return opts
	end

	listDropdown = UI:CreateFlatDropdown(container, 174, 22, GetListOptions(), EnsureDB().activeListId, function(key)
		EnsureDB().activeListId = key
		PluribusHiveAuctionator:RefreshActiveView()
	end, "Liste wählen")
	listDropdown:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

	local searchAllBtn = UI:CreateButton(container, "Alle suchen", 76, 22, function()
		PluribusHiveAuctionator:StartBatchSearchActiveList()
	end, true)
	searchAllBtn:SetPoint("LEFT", listDropdown, "RIGHT", 4, 0)

	local newListBtn = UI:CreateButton(container, "+ Liste", 56, 22, function()
		local v = PluribusHiveAuctionator.views.shop
		local txt = v and v.searchBox and v.searchBox:GetText() or ""
		local name = txt:match("^%s*(.-)%s*$")
		if name == "" then
			name = "Liste " .. tostring(#EnsureDB().shoppingLists + 1)
		end
		PluribusHiveAuctionator:CreateShoppingList(name)
		if listDropdown.SetOptions then listDropdown:SetOptions(GetListOptions(), EnsureDB().activeListId) end
		PluribusHiveAuctionator:RefreshActiveView()
	end)
	newListBtn:SetPoint("LEFT", searchAllBtn, "RIGHT", 4, 0)

	local delListBtn = UI:CreateButton(container, "Entf.", 44, 22, function()
		if PluribusHiveAuctionator:DeleteActiveShoppingList() then
			if listDropdown.SetOptions then listDropdown:SetOptions(GetListOptions(), EnsureDB().activeListId) end
			PluribusHiveAuctionator:RefreshActiveView()
		end
	end)
	delListBtn:SetPoint("LEFT", newListBtn, "RIGHT", 4, 0)

	-- Row 2: Search input + Add to list + Filter toggle + Search button
	local searchBox = UI:CreateInputBox(container, 198, 22)
	searchBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)

	local function BuildCurrentFilter()
		local v = PluribusHiveAuctionator.views.shop
		local f = PluribusHiveAuctionator:ParseSearchTerm(searchBox:GetText() or "")
		if v then
			if v.selectedCategory and v.selectedCategory ~= "ALL" then f.category = v.selectedCategory end
			if v.selectedQuality and v.selectedQuality >= 0 then f.minQuality = v.selectedQuality end
			if tonumber(v.minLvlBox:GetText()) then f.minLevel = tonumber(v.minLvlBox:GetText()) end
			if tonumber(v.maxLvlBox:GetText()) then f.maxLevel = tonumber(v.maxLvlBox:GetText()) end
			if tonumber(v.minIlvlBox:GetText()) then f.minIlvl = tonumber(v.minIlvlBox:GetText()) end
			if tonumber(v.maxPriceGBox:GetText()) then f.maxPrice = math.floor(tonumber(v.maxPriceGBox:GetText()) * 10000) end
			if v.exactChecked then f.exact = true end
			if v.usableChecked then f.usableOnly = true end
			if v.belowMarketChecked then f.belowMarketOnly = true end
		end
		return f
	end

	local goSearchBtn = UI:CreateButton(container, "Suchen", 56, 22, function()
		PluribusHiveAuctionator.batchActive = false
		local f = BuildCurrentFilter()
		PluribusHiveAuctionator:RunAHQuery(f, "shop", 0)
	end, true)
	goSearchBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)

	local addTermBtn = UI:CreateButton(container, "+ Eintrag", 62, 22, function()
		local txt = searchBox:GetText() or ""
		if txt:match("%S") then
			PluribusHiveAuctionator:AddTermToActiveShoppingList(txt)
			PluribusHiveAuctionator:RefreshActiveView()
		end
	end)
	addTermBtn:SetPoint("LEFT", goSearchBtn, "RIGHT", 4, 0)

	local filterToggleBtn = UI:CreateButton(container, "Filter", 52, 22, function()
		PluribusHiveAuctionator.showAdvancedFilters = not PluribusHiveAuctionator.showAdvancedFilters
		PluribusHiveAuctionator:LayoutShoppingLists()
	end)
	filterToggleBtn:SetPoint("LEFT", addTermBtn, "RIGHT", 4, 0)

	-- Collapsible Advanced Filters Card
	local filterCard = CreateFrame("Frame", nil, container, BackdropTemplateMixin and "BackdropTemplate" or nil)
	filterCard:SetSize(384, 78)
	filterCard:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -54)
	UI:ApplyBackdrop(filterCard, 0.08, 0.11, 0.16, 0.96, 0.24, 0.34, 0.48, 0.85)
	filterCard:Hide()

	local shopState = {
		selectedCategory = "ALL",
		selectedQuality = -1,
		exactChecked = false,
		usableChecked = false,
		belowMarketChecked = false,
	}

	local catDrop = UI:CreateFlatDropdown(filterCard, 130, 20, FILTER_CATEGORIES, "ALL", function(k)
		shopState.selectedCategory = k
	end)
	catDrop:SetPoint("TOPLEFT", filterCard, "TOPLEFT", 6, -6)

	local qualDrop = UI:CreateFlatDropdown(filterCard, 130, 20, FILTER_QUALITIES, -1, function(k)
		shopState.selectedQuality = tonumber(k) or -1
	end)
	qualDrop:SetPoint("LEFT", catDrop, "RIGHT", 6, 0)

	local maxPLbl = UI:CreateLabel(filterCard, "Max G:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	maxPLbl:SetPoint("LEFT", qualDrop, "RIGHT", 8, 0)
	local maxPriceGBox = UI:CreateInputBox(filterCard, 50, 20)
	maxPriceGBox:SetPoint("LEFT", maxPLbl, "RIGHT", 4, 0)

	local lvlLbl = UI:CreateLabel(filterCard, "Lvl:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	lvlLbl:SetPoint("TOPLEFT", filterCard, "TOPLEFT", 6, -32)
	local minLvlBox = UI:CreateInputBox(filterCard, 34, 20)
	minLvlBox:SetPoint("LEFT", lvlLbl, "RIGHT", 4, 0)
	local dashLbl = UI:CreateLabel(filterCard, "-", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	dashLbl:SetPoint("LEFT", minLvlBox, "RIGHT", 2, 0)
	local maxLvlBox = UI:CreateInputBox(filterCard, 34, 20)
	maxLvlBox:SetPoint("LEFT", dashLbl, "RIGHT", 2, 0)

	local ilvlLbl = UI:CreateLabel(filterCard, "Min iLvl:", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	ilvlLbl:SetPoint("LEFT", maxLvlBox, "RIGHT", 8, 0)
	local minIlvlBox = UI:CreateInputBox(filterCard, 36, 20)
	minIlvlBox:SetPoint("LEFT", ilvlLbl, "RIGHT", 4, 0)

	local exactCB = UI:CreateCheckbox(filterCard, "Exakt", false, function(val) shopState.exactChecked = val end)
	exactCB:SetPoint("TOPLEFT", filterCard, "TOPLEFT", 6, -54)
	local usableCB = UI:CreateCheckbox(filterCard, "Benutzbar", false, function(val) shopState.usableChecked = val end)
	usableCB:SetPoint("LEFT", exactCB, "RIGHT", 58, 0)
	local dealCB = UI:CreateCheckbox(filterCard, "Unter Marktpreis", false, function(val) shopState.belowMarketChecked = val end)
	dealCB:SetPoint("LEFT", usableCB, "RIGHT", 76, 0)

	-- Active Shopping List / To-Do items virtual list
	local listHeaderLbl = UI:CreateLabel(container, "|cff4ade80Aktive Einkaufsliste:|r", 1, 1, 1, "GameFontHighlightSmall")
	listHeaderLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -56)

	local listVList = UI:CreateVirtualScrollList(container, {
		width = 384,
		height = 132,
		rowHeight = 28,
		rowGap = 2,
		wheelStep = 2,
		createRow = function(vp, idx, w, h)
			local row = UI:CreateListRow(vp, w, h, idx, function()
				if row._entry then
					local f = PluribusHiveAuctionator:ParseSearchTerm(row._entry.term or row._entry.name or "")
					if row._entry.isTodo then f.exact = true end
					searchBox:SetText(row._entry.term or row._entry.name or "")
					PluribusHiveAuctionator.batchActive = false
					PluribusHiveAuctionator:RunAHQuery(f, "shop", 0)
				end
			end)
			local nameL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			nameL:SetPoint("LEFT", row, "LEFT", 6, 0)
			row._nameL = nameL

			local rmBtn = UI:CreateButton(row, "X", 20, 18, function()
				if row._entry then
					PluribusHiveAuctionator:RemoveItemFromActiveShoppingList(row._entryIndex, row._entry.itemID)
					PluribusHiveAuctionator:RefreshActiveView()
				end
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			row._rmBtn = rmBtn

			local metaL = UI:CreateLabel(row, "", 0.78, 0.86, 0.94, "GameFontHighlightSmall")
			metaL:SetPoint("RIGHT", rmBtn, "LEFT", -6, 0)
			row._metaL = metaL
			row:Hide()
			return row
		end,
		bindRow = function(row, item, dataIdx)
			row._entry = item
			row._entryIndex = dataIdx
			if item.isTodo then
				local okTag = (item.missing == 0) and "|cff4ade80[OK]|r " or (item.mode == "FARM" and "|cff38bdf8[Farm]|r " or "|cfffbbf24[Kauf]|r ")
				local qCol = PluribusUtils:GetQualityColor(item.quality or 1)
				row._nameL:SetText(okTag .. qCol .. tostring(item.name or ""):sub(1, 20) .. "|r")
				local pStr = (item.marketCopper and item.marketCopper > 0) and (" ~" .. PluribusUtils:FormatGold(item.marketCopper)) or ""
				row._metaL:SetText(string.format("%d/%d%s", item.owned or 0, item.qty or 1, pStr))
				if item.direct then row._rmBtn:Show() else row._rmBtn:Hide() end
			else
				row._nameL:SetText("|cffcbd5e1" .. tostring(item.name or item.term or ""):sub(1, 28) .. "|r")
				row._metaL:SetText(item.qty and ("x" .. tostring(item.qty)) or "")
				row._rmBtn:Show()
			end
		end,
	})

	-- Live AH Search Results virtual list
	local resHeaderLbl = UI:CreateLabel(container, "|cff38bdf8Live AH Ergebnisse (Klick: Sofortkauf / +To-Do):|r", 1, 1, 1, "GameFontHighlightSmall")

	local resVList = UI:CreateVirtualScrollList(container, {
		width = 384,
		height = 148,
		rowHeight = 28,
		rowGap = 2,
		wheelStep = 2,
		createRow = function(vp, idx, w, h)
			local row = UI:CreateListRow(vp, w, h, idx)
			local nameL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			nameL:SetPoint("LEFT", row, "LEFT", 6, 0)
			row._nameL = nameL

			local buyBtn = UI:CreateButton(row, "Kauf", 42, 18, function()
				if row._res and row._res.buyout and row._res.buyout > 0 then
					PluribusHiveAuctionator:BuyoutListing(row._res.index, row._res.buyout, row._res.name)
				end
			end, true)
			buyBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			row._buyBtn = buyBtn

			local todoBtn = UI:CreateButton(row, "+TD", 32, 18, function()
				if row._res and row._res.itemID then
					PluribusHiveAuctionator:ToggleItemInTodo(row._res.itemID, 20)
					PluribusHiveAuctionator:RefreshActiveView()
				end
			end)
			todoBtn:SetPoint("RIGHT", buyBtn, "LEFT", -3, 0)
			row._todoBtn = todoBtn

			local priceL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			priceL:SetPoint("RIGHT", todoBtn, "LEFT", -6, 0)
			row._priceL = priceL
			row:Hide()
			return row
		end,
		bindRow = function(row, r)
			row._res = r
			local qCol = PluribusUtils:GetQualityColor(r.quality or 1)
			local deTag = r.deDeal and " |cffa855f7[DE+]|r" or ""
			row._nameL:SetText(qCol .. tostring(r.name or ""):sub(1, 17) .. "|r x" .. tostring(r.count or 1) .. deTag)
			local p = (r.unitBuyout > 0 and r.unitBuyout) or r.unitPrice or 0
			local pctCol = "|cffcbd5e1"
			local pctTxt = ""
			if r.marketPct then
				if r.marketPct <= 85 then pctCol = "|cff4ade80"
				elseif r.marketPct <= 105 then pctCol = "|cfffbbf24"
				else pctCol = "|cfff87171" end
				pctTxt = " " .. pctCol .. r.marketPct .. "%|r"
			end
			row._priceL:SetText("|cfffbbf24" .. PluribusUtils:FormatGold(p) .. "|r" .. pctTxt)
			if r.buyout and r.buyout > 0 then row._buyBtn:Show() else row._buyBtn:Hide() end
		end,
	})

	self.views.shop = {
		root = container,
		listDropdown = listDropdown,
		getListOptions = GetListOptions,
		searchBox = searchBox,
		filterCard = filterCard,
		listHeaderLbl = listHeaderLbl,
		listVList = listVList,
		resHeaderLbl = resHeaderLbl,
		resVList = resVList,
		minLvlBox = minLvlBox,
		maxLvlBox = maxLvlBox,
		minIlvlBox = minIlvlBox,
		maxPriceGBox = maxPriceGBox,
		selectedCategory = shopState.selectedCategory,
		selectedQuality = shopState.selectedQuality,
		exactChecked = shopState.exactChecked,
		usableChecked = shopState.usableChecked,
		belowMarketChecked = shopState.belowMarketChecked,
		stateRef = shopState,
	}
	-- Sync state getters cleanly
	self.views.shop.syncState = function()
		self.views.shop.selectedCategory = shopState.selectedCategory
		self.views.shop.selectedQuality = shopState.selectedQuality
		self.views.shop.exactChecked = shopState.exactChecked
		self.views.shop.usableChecked = shopState.usableChecked
		self.views.shop.belowMarketChecked = shopState.belowMarketChecked
	end
	self:LayoutShoppingLists()
	return container
end

function PluribusHiveAuctionator:LayoutShoppingLists()
	local v = self.views.shop
	if not v then return end
	if self.showAdvancedFilters then
		v.filterCard:Show()
		v.listHeaderLbl:ClearAllPoints()
		v.listHeaderLbl:SetPoint("TOPLEFT", v.filterCard, "BOTTOMLEFT", 2, -6)
		v.listVList:SetHeight(98)
		v.resVList:SetHeight(112)
	else
		v.filterCard:Hide()
		v.listHeaderLbl:ClearAllPoints()
		v.listHeaderLbl:SetPoint("TOPLEFT", v.root, "TOPLEFT", 2, -56)
		v.listVList:SetHeight(136)
		v.resVList:SetHeight(150)
	end
	v.listVList:ClearAllPoints()
	v.listVList:SetPoint("TOPLEFT", v.listHeaderLbl, "BOTTOMLEFT", -2, -3)
	v.resHeaderLbl:ClearAllPoints()
	v.resHeaderLbl:SetPoint("TOPLEFT", v.listVList, "BOTTOMLEFT", 2, -6)
	v.resVList:ClearAllPoints()
	v.resVList:SetPoint("TOPLEFT", v.resHeaderLbl, "BOTTOMLEFT", -2, -3)
end

function PluribusHiveAuctionator:BuildDisenchantView(panel)
	local UI = _G.PluribusUIFramework
	local container = CreateFrame("Frame", nil, panel)
	container:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -54)
	container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	container:Hide()

	local scanBtn = UI:CreateButton(container, "Live AH Entzauber-Scan", 170, 24, function()
		if PluribusHiveAuctionator.deLiveScanActive then
			PluribusHiveAuctionator:StopLiveDisenchantScan()
		else
			PluribusHiveAuctionator:StartLiveDisenchantScan()
		end
	end, true)
	scanBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

	local cacheBtn = UI:CreateButton(container, "Cache prüfen", 104, 24, function()
		PluribusHiveAuctionator:ScanCachedDisenchantDeals()
		PluribusHiveAuctionator:RefreshActiveView()
	end)
	cacheBtn:SetPoint("LEFT", scanBtn, "RIGHT", 6, 0)

	local cutCB = UI:CreateCheckbox(container, "-5% AH", EnsureDB().dePrefs.includeAhCut, function(val)
		EnsureDB().dePrefs.includeAhCut = val
		PluribusHiveAuctionator:ScanCachedDisenchantDeals()
		PluribusHiveAuctionator:RefreshActiveView()
	end)
	cutCB:SetPoint("LEFT", cacheBtn, "RIGHT", 8, 0)

	local statusLbl = UI:CreateLabel(container, "|cffa855f7Zeigt Items, die günstiger sind als ihr mittlerer Entzauberungswert.|r", 0.8, 0.85, 0.95, "GameFontHighlightSmall")
	statusLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -30)

	local deVList = UI:CreateVirtualScrollList(container, {
		width = 384,
		height = 336,
		rowHeight = 40,
		rowGap = 2,
		wheelStep = 2,
		createRow = function(vp, idx, w, h)
			local row = UI:CreateListRow(vp, w, h, idx, function()
				if row._deal and row._deal.name and _G.PluribusHiveAuction then
					_G.PluribusHiveAuction:SearchNativeAH(row._deal.name)
				end
			end)
			local topL = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
			topL:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
			local subL = UI:CreateLabel(row, "", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
			subL:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 4)

			local actBtn = UI:CreateButton(row, "Kaufen", 56, 22, function()
				local d = row._deal
				if not d then return end
				if d.source == "live" and d.auctionIndex then
					PluribusHiveAuctionator:BuyoutListing(d.auctionIndex, d.buyout, d.name)
				elseif _G.PluribusHiveAuction then
					_G.PluribusHiveAuction:SearchNativeAH(d.name)
				end
			end, true)
			actBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)

			local profitL = UI:CreateLabel(row, "", 0.3, 0.95, 0.5, "GameFontHighlightSmall")
			profitL:SetPoint("RIGHT", actBtn, "LEFT", -6, 0)

			row._topL = topL
			row._subL = subL
			row._actBtn = actBtn
			row._profitL = profitL
			row:Hide()
			return row
		end,
		bindRow = function(row, d)
			row._deal = d
			local qCol = PluribusUtils:GetQualityColor(d.quality or 2)
			local srcTag = d.source == "live" and "|cff4ade80[LIVE]|r " or "|cff94a3b8[Cache]|r "
			row._topL:SetText(srcTag .. qCol .. tostring(d.name or ""):sub(1, 24) .. "|r")
			row._subL:SetText(string.format(
				"Preis: |cfffbbf24%s|r  |  Ø DE: |cffa855f7%s|r%s",
				PluribusUtils:FormatGold(d.buyout),
				PluribusUtils:FormatGold(d.meanDE),
				d.isEstimated and " (Est)" or ""
			))
			row._profitL:SetText(string.format("|cff4ade80+%s (%d%%)|r", PluribusUtils:FormatGold(d.profit), d.marginPct or 0))
			if row._actBtn.SetText then
				row._actBtn:SetText(d.source == "live" and "Kaufen" or "Suchen")
			end
		end,
	})
	deVList:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -48)

	self.views.de = {
		root = container,
		scanBtn = scanBtn,
		statusLbl = statusLbl,
		deVList = deVList,
	}
	return container
end

function PluribusHiveAuctionator:AttachToPanel(panel)
	if not panel or panel._plbAuctionatorBuilt then return end
	panel._plbAuctionatorBuilt = true
	self:BuildSellView(panel)
	self:BuildShoppingView(panel)
	self:BuildDisenchantView(panel)
end

function PluribusHiveAuctionator:HideAllViews()
	self.activeMode = nil
	for _, v in pairs(self.views) do
		if v and v.root then v.root:Hide() end
	end
end

function PluribusHiveAuctionator:ShowMode(mode)
	self:HideAllViews()
	self.activeMode = mode
	if mode == "sell" and self.views.sell then
		self.views.sell.root:Show()
		self:ScanSellableBagItems()
		self:RefreshActiveView()
	elseif mode == "shop" and self.views.shop then
		self.views.shop.root:Show()
		self:RefreshActiveView()
	elseif mode == "de" and self.views.de then
		self.views.de.root:Show()
		self:ScanCachedDisenchantDeals()
		self:RefreshActiveView()
	end
end

function PluribusHiveAuctionator:OpenShoppingForItem(itemName)
	if not _G.PluribusHiveAuction or not _G.PluribusHiveAuction.ahOpen then return false end
	_G.PluribusHiveAuction:OpenTab("shop")
	local v = self.views.shop
	if v and v.searchBox and itemName and itemName ~= "" then
		v.searchBox:SetText(itemName)
		local f = self:ParseSearchTerm('"' .. tostring(itemName) .. '"')
		self:RunAHQuery(f, "shop", 0)
	end
	return true
end

function PluribusHiveAuctionator:RefreshActiveView()
	if self.activeMode == "sell" and self.views.sell then
		local v = self.views.sell
		if self.sellSubView == "owner" then
			v.bagVList:SetData(self.ownerAuctions or {}, false)
		else
			v.bagVList:SetData(self.bagItems or {}, false)
		end
		v.compVList:SetData(self.competingListings or {}, false)
	elseif self.activeMode == "shop" and self.views.shop then
		local v = self.views.shop
		if v.syncState then v.syncState() end
		local sl = self:GetActiveShoppingList()
		local items = (sl and sl.items) or {}
		if sl and sl.isVirtualTodo then
			local remCost = 0
			local remCount = 0
			for _, it in ipairs(items) do
				if (it.missing or 0) > 0 and it.mode ~= "FARM" then
					remCount = remCount + 1
					remCost = remCost + (it.missing * (it.marketCopper or 0))
				end
			end
			v.listHeaderLbl:SetText(string.format(
				"|cff4ade80★ To-Do Liste (Live):|r %d offen |cfffbbf24(~%s)|r",
				remCount, PluribusUtils:FormatGold(remCost)
			))
		else
			v.listHeaderLbl:SetText("|cff38bdf8Einkaufsliste:|r " .. tostring(sl and sl.name or "") .. " (" .. tostring(#items) .. ")")
		end
		v.listVList:SetData(items, false)
		v.resVList:SetData(self.shoppingResults or {}, false)
	elseif self.activeMode == "de" and self.views.de then
		local v = self.views.de
		if v.scanBtn and v.scanBtn.SetText then
			v.scanBtn:SetText(self.deLiveScanActive and "Scan stoppen" or "Live AH Entzauber-Scan")
		end
		if self.deLiveScanActive then
			v.statusLbl:SetText(string.format("|cff38bdf8Scanne AH (Seite %d)... %d Deals gefunden|r", (self.deScanPage or 0) + 1, #(self.deDeals or {})))
		else
			v.statusLbl:SetText(string.format("|cffa855f7%d Entzauber-Schnäppchen gefunden (Preis < Ø Entzauberwert)|r", #(self.deDeals or {})))
		end
		v.deVList:SetData(self.deDeals or {}, false)
	end
end

-- ============================================================================
-- INITIALIZATION & LIVE EVENT SYNC
-- ============================================================================
function PluribusHiveAuctionator:Initialize()
	if self.initialized then return end
	self.initialized = true
	EnsureDB()

	-- Seamless To-Do List live sync!
	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_TODO_CHANGED", function()
			if PluribusHiveAuctionator.activeMode == "shop" then
				PluribusHiveAuctionator:RefreshActiveView()
			end
		end)
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "AUCTION_ITEM_LIST_UPDATE", "AUCTION_OWNED_LIST_UPDATE", "BAG_UPDATE", "AUCTION_HOUSE_CLOSED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event)
		if event == "AUCTION_ITEM_LIST_UPDATE" then
			if PluribusHiveAuctionator.pendingQueryKind then
				PluribusHiveAuctionator:OnAuctionListUpdate()
			end
		elseif event == "AUCTION_OWNED_LIST_UPDATE" then
			if PluribusHiveAuctionator.activeMode == "sell" and PluribusHiveAuctionator.sellSubView == "owner" then
				PluribusHiveAuctionator:ScanOwnerAuctions()
				PluribusHiveAuctionator:RefreshActiveView()
			end
		elseif event == "BAG_UPDATE" then
			if PluribusHiveAuctionator.activeMode == "sell" then
				PluribusHiveAuctionator:ScanSellableBagItems()
				PluribusHiveAuctionator:RefreshActiveView()
			elseif PluribusHiveAuctionator.activeMode == "shop" and EnsureDB().activeListId == "__TODO__" then
				PluribusHiveAuctionator:RefreshActiveView()
			end
		elseif event == "AUCTION_HOUSE_CLOSED" then
			PluribusHiveAuctionator.deLiveScanActive = false
			PluribusHiveAuctionator.batchActive = false
			PluribusHiveAuctionator.pendingQueryKind = nil
		end
	end)
end

return PluribusHiveAuctionator
