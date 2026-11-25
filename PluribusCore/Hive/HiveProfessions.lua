-- PluribusHive Professions, Craft Profits, Real Guild Recipe Directory & Interactive To-Do List
-- 1. Scans YOUR real recipes across Classic TradeSkill, Classic Craft (Enchanting), and C_TradeSkillUI
-- 2. Guild Recipe Directory shows ONLY real recipes owned by you or synced guildmates (NO phantom unowned catalog!)
--    with live Search Box + "Only Mine / All Guild" toggle + Profession filter
-- 3. Craft Profits works from BOTH open profession AND saved scanned recipes, with Classic vendor-reagent fallback + 5% AH cut
-- 4. Interactive To-Do & Shopping List: per-item choice between "Buy (AH)" (1-click AH search) or "Farm (Route)"
--    (automatically renders the calculated optimal farming route inline + 1-click Navigate!)

PluribusHiveProfessions = {
	initialized = false,
	skillTabsAttached = false,
	tradeHooksInstalled = false,
	selectedCrafterProf = "ALL",
	onlyMyRecipes = false,
	recipeSearchQuery = "",
	profitSearchQuery = "",
	selectedPickerCat = "MY_RECIPES",
	selectedPickerQty = 10,
	unlearnedProf = "MY_PROFS",
	unlearnedSource = "ALL", -- "ALL" | "VENDOR" | "DROP"
	unlearnedSearchQuery = "",
}
_G.PluribusHiveProfessions = PluribusHiveProfessions

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local KNOWN_PROFESSIONS = {
	["Alchemy"] = true, ["Alchemie"] = true, ["Alchimie"] = true,
	["Blacksmithing"] = true, ["Schmiedekunst"] = true, ["Schmieden"] = true,
	["Enchanting"] = true, ["Verzauberkunst"] = true, ["Verzaubern"] = true,
	["Engineering"] = true, ["Ingenieurskunst"] = true,
	["Herbalism"] = true, ["Kräuterkunde"] = true,
	["Leatherworking"] = true, ["Lederverarbeitung"] = true,
	["Mining"] = true, ["Bergbau"] = true,
	["Skinning"] = true, ["Kürschnerei"] = true,
	["Tailoring"] = true, ["Schneiderei"] = true,
	["Cooking"] = true, ["Kochkunst"] = true, ["Kochen"] = true,
	["First Aid"] = true, ["Erste Hilfe"] = true,
	["Fishing"] = true, ["Angeln"] = true,
	["Jewelcrafting"] = true, ["Juwelenschleifen"] = true, ["Juwelierskunst"] = true,
	["Inscription"] = true, ["Inschriftenkunde"] = true,
}

local PROF_CANONICAL = {
	["alchemy"] = "Alchemy", ["alchemie"] = "Alchemy", ["alchimie"] = "Alchemy",
	["blacksmithing"] = "Blacksmithing", ["schmiedekunst"] = "Blacksmithing", ["schmieden"] = "Blacksmithing",
	["enchanting"] = "Enchanting", ["verzauberkunst"] = "Enchanting", ["verzaubern"] = "Enchanting",
	["engineering"] = "Engineering", ["ingenieurskunst"] = "Engineering",
	["herbalism"] = "Herbalism", ["kräuterkunde"] = "Herbalism", ["kraeuterkunde"] = "Herbalism",
	["leatherworking"] = "Leatherworking", ["lederverarbeitung"] = "Leatherworking",
	["mining"] = "Mining", ["bergbau"] = "Mining",
	["skinning"] = "Skinning", ["kürschnerei"] = "Skinning", ["kuerschnerei"] = "Skinning",
	["tailoring"] = "Tailoring", ["schneiderei"] = "Tailoring",
	["cooking"] = "Cooking", ["kochkunst"] = "Cooking", ["kochen"] = "Cooking",
	["first aid"] = "First Aid", ["erste hilfe"] = "First Aid",
	["fishing"] = "Fishing", ["angeln"] = "Fishing",
	["jewelcrafting"] = "Jewelcrafting", ["juwelenschleifen"] = "Jewelcrafting", ["juwelierskunst"] = "Jewelcrafting",
	["inscription"] = "Inscription", ["inschriftenkunde"] = "Inscription",
}

local PROF_DISPLAY_DE = {
	Alchemy = "Alchimie",
	Blacksmithing = "Schmiedekunst",
	Enchanting = "Verzauberkunst",
	Engineering = "Ingenieurskunst",
	Herbalism = "Kräuterkunde",
	Leatherworking = "Lederverarbeitung",
	Mining = "Bergbau",
	Skinning = "Kürschnerei",
	Tailoring = "Schneiderei",
	Cooking = "Kochkunst",
	["First Aid"] = "Erste Hilfe",
	Fishing = "Angeln",
	Jewelcrafting = "Juwelenschleifen",
	Inscription = "Inschriftenkunde",
}

PluribusHiveProfessions.CRAFTING_PROFS = {
	"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
	"Leatherworking", "Tailoring", "Cooking", "First Aid", "Jewelcrafting",
}

-- Classic 1.60.1 Vendor-sold reagents (copper) so Craft Profits never breaks when vendor mats aren't on the AH
PluribusHiveProfessions.VENDOR_REAGENT_PRICES = {
	[3371] = 5,      -- Empty Vial
	[3372] = 40,     -- Leaded Vial
	[8925] = 250,    -- Crystal Vial
	[18256] = 4000,  -- Imbued Vial
	[2320] = 10,     -- Coarse Thread
	[2321] = 100,    -- Fine Thread
	[4291] = 500,    -- Silken Thread
	[8343] = 2000,   -- Heavy Silken Thread
	[14341] = 5000,  -- Rune Thread
	[2880] = 100,    -- Weak Flux
	[3466] = 2000,   -- Strong Flux
	[3857] = 500,    -- Coal
	[4289] = 50,     -- Salt
	[2678] = 10,     -- Mild Spices
	[2692] = 40,     -- Hot Spices
	[3713] = 160,    -- Soothing Spices
	[159] = 5,       -- Refreshing Spring Water
	[1179] = 25,     -- Ice Cold Milk
	[2324] = 25,     -- Bleach
	[2325] = 1000,   -- Black Dye
	[2604] = 50,     -- Red Dye
	[2605] = 100,    -- Green Dye
	[4340] = 350,    -- Gray Dye
	[4341] = 500,    -- Yellow Dye
	[4342] = 2500,   -- Purple Dye
	[6260] = 50,     -- Blue Dye
	[6261] = 1000,   -- Orange Dye
	[10290] = 2500,  -- Pink Dye
	[4399] = 200,    -- Wooden Stock
	[4400] = 2000,   -- Heavy Stock
	[4470] = 38,     -- Simple Wood
	[11291] = 4500,  -- Star Wood
	[6217] = 124,    -- Copper Rod
	[6338] = 500,    -- Silver Rod
	[11128] = 2500,  -- Golden Rod
	[11144] = 5000,  -- Truesilver Rod
	[16206] = 20000, -- Arcanite Rod
}

-- Leveling material brackets by profession & skill range (used for surplus matching & To-Do material picker)
PluribusHiveProfessions.LEVELING_MATS = {
	Alchemy = {
		{ 1, 75, { 765, 2447, 3371 } },
		{ 75, 150, { 2449, 2450, 785, 2453, 3372 } },
		{ 150, 225, { 3355, 3356, 3357, 3821 } },
		{ 225, 300, { 3818, 3820, 8831, 8838, 13463, 13464, 13465, 13466, 13468 } },
	},
	Blacksmithing = {
		{ 1, 75, { 2840, 2835 } },
		{ 75, 150, { 2841, 2842, 2836 } },
		{ 150, 225, { 3575, 3859, 2838, 7912 } },
		{ 225, 300, { 3860, 12359, 12365, 12360, 12810 } },
	},
	Engineering = {
		{ 1, 75, { 2840, 2835, 2589 } },
		{ 75, 150, { 2841, 2836, 2592 } },
		{ 150, 225, { 3575, 3860, 2838, 7912, 4306 } },
		{ 225, 300, { 3860, 12359, 12365, 14047, 15994 } },
	},
	Enchanting = {
		{ 1, 75, { 10940, 10938, 10939 } },
		{ 75, 150, { 11083, 10998, 11082 } },
		{ 150, 225, { 11137, 11134, 11135, 11176 } },
		{ 225, 300, { 11176, 16204, 16202, 16203, 14344, 20725 } },
	},
	Leatherworking = {
		{ 1, 75, { 2318, 2934 } },
		{ 75, 150, { 2319, 4232 } },
		{ 150, 225, { 4234, 4304 } },
		{ 225, 300, { 4304, 8170, 8169, 15407 } },
	},
	Tailoring = {
		{ 1, 75, { 2589 } },
		{ 75, 150, { 2592, 4306 } },
		{ 150, 225, { 4306, 4338 } },
		{ 225, 300, { 4338, 14047, 14256, 14342 } },
	},
	["First Aid"] = {
		{ 1, 80, { 2589 } },
		{ 80, 150, { 2592 } },
		{ 150, 225, { 4306, 4338 } },
		{ 225, 300, { 14047 } },
	},
	Cooking = {
		{ 1, 100, { 2672, 2673, 769 } },
		{ 100, 225, { 3730, 3731, 12203 } },
		{ 225, 300, { 12208, 12205, 13754, 13759 } },
	},
}

local function CanonicalProf(name)
	local raw = tostring(name or ""):match("^%s*(.-)%s*$") or ""
	if raw == "" or raw == "UNKNOWN" or (_G.UNKNOWN and raw == _G.UNKNOWN) then
		return nil
	end
	return PROF_CANONICAL[raw:lower()] or raw
end

function PluribusHiveProfessions:GetProfessionDisplayName(profName)
	local canon = CanonicalProf(profName) or tostring(profName or "Profession")
	local lang = (_G.PluribusL and _G.PluribusL.GetLanguage and _G.PluribusL:GetLanguage()) or "enUS"
	if lang == "deDE" and PROF_DISPLAY_DE[canon] then
		return PROF_DISPLAY_DE[canon]
	end
	return canon
end

local function EnsureShoppingDB()
	local db = PluribusHive:GetDB()
	db.myNeededMats = db.myNeededMats or {}
	db.myShoppingRecipes = db.myShoppingRecipes or {}
	db.guildRecipes = db.guildRecipes or {}
	db.guildProfs = db.guildProfs or {}
	db.todoModes = db.todoModes or {} -- [itemID] = "BUY" | "FARM"
	return db
end

-- One-time cleanup of legacy scrambled recipe buckets (pre-v2 off-by-one swaps & uncanonical German keys like "Alchimie")
function PluribusHiveProfessions:SanitizeStoredRecipes(forceClearSelf)
	local db = EnsureShoppingDB()
	if (db.recipesSchemaVersion or 0) < 2 then
		db.guildRecipes = {}
		db.recipesSchemaVersion = 2
		return
	end
	if forceClearSelf then
		local me = PluribusHive:GetPlayerShortName()
		db.guildRecipes[me] = {}
		return
	end
	for owner, profTbl in pairs(db.guildRecipes or {}) do
		if type(profTbl) == "table" then
			local normalized = {}
			for pName, rList in pairs(profTbl) do
				local canon = CanonicalProf(pName)
				if canon and type(rList) == "table" and #rList > 0 then
					if not normalized[canon] or #rList > #normalized[canon] then
						normalized[canon] = rList
					end
				end
			end
			db.guildRecipes[owner] = normalized
		end
	end
end

-- Deduplicate legacy character keys in guildProfs & guildRecipes (e.g. "leona" vs "Leona Morgenröte")
-- Rebuilds tables cleanly without inserting new keys during pairs() (safe in Lua 5.1!)
function PluribusHiveProfessions:PruneDuplicateOwners()
	local db = EnsureShoppingDB()
	local me = PluribusHive:GetPlayerShortName()
	local meKey = PluribusHive:CanonicalKey(me)

	local function dedupeTable(tbl, mergeFn)
		if type(tbl) ~= "table" then return {} end
		local byCanon = {}
		local keys = {}
		for k in pairs(tbl) do table.insert(keys, k) end
		for _, k in ipairs(keys) do
			local v = tbl[k]
			local canon = PluribusHive:CanonicalKey(k)
			local norm = (canon == meKey) and me or PluribusHive:NormalizeName(k)
			if canon ~= "" and type(v) == "table" then
				if not byCanon[canon] then
					byCanon[canon] = { key = norm, val = v }
				else
					mergeFn(byCanon[canon].val, v)
				end
			end
		end
		local rebuilt = {}
		for _, entry in pairs(byCanon) do
			rebuilt[entry.key] = entry.val
		end
		return rebuilt
	end

	db.guildProfs = dedupeTable(db.guildProfs, function(dst, src)
		if (src.updatedAt or 0) > (dst.updatedAt or 0) then
			dst.profs = src.profs or dst.profs
			dst.needs = src.needs or dst.needs
			dst.updatedAt = src.updatedAt
		end
	end)
	db.guildRecipes = dedupeTable(db.guildRecipes, function(dst, src)
		for pName, rList in pairs(src or {}) do
			if not dst[pName] or #(rList or {}) > #(dst[pName] or {}) then
				dst[pName] = rList
			end
		end
	end)
end

-- Format signed profit copper cleanly (+emerald / -crimson)
function PluribusHiveProfessions:FormatSignedGold(copper)
	if copper == nil then return "|cff64748b--|r" end
	local n = math.floor(tonumber(copper) or 0)
	local sign = n >= 0 and "+" or "-"
	local col = n >= 0 and "|cff4ade80" or "|cfff87171"
	local absVal = math.abs(n)
	if absVal == 0 then return "|cff94a3b80c|r" end
	local g = math.floor(absVal / 10000)
	local s = math.floor((absVal % 10000) / 100)
	local c = absVal % 100
	if g > 0 then
		return string.format("%s%s%dg %ds|r", col, sign, g, s)
	elseif s > 0 then
		return string.format("%s%s%ds %dc|r", col, sign, s, c)
	end
	return string.format("%s%s%dc|r", col, sign, c)
end

function PluribusHiveProfessions:GetReagentUnitPrice(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return nil, false end
	local ah = _G.PluribusHiveAuction
	local pInfo = ah and ah:GetPrice(itemID) or nil
	if pInfo and pInfo.copper and pInfo.copper > 0 then
		return pInfo.copper, false
	end
	local vPrice = self.VENDOR_REAGENT_PRICES[itemID]
	if vPrice then
		return vPrice, true
	end
	-- Fallback to vendor sell * 4 if available (better than nil for vendor items)
	local sellPrice = tonumber((select(11, PluribusUtils:GetItemInfo(itemID))))
	if sellPrice and sellPrice > 0 then
		return sellPrice * 4, true
	end
	return nil, false
end

-- Calculate live craft profit for an open TradeSkill row (includes 5% AH cut + vendor reagent fallback!)
function PluribusHiveProfessions:CalculateRecipeProfit(skillIndex)
	if not skillIndex or not GetTradeSkillInfo then return nil end
	local skillName, skillType = GetTradeSkillInfo(skillIndex)
	if not skillName or skillType == "header" or skillType == "subheader" then return nil end

	local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(skillIndex)
	local itemID = itemLink and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(itemLink) or nil
	local minMade = 1
	if GetTradeSkillNumMade then
		local mn, mx = GetTradeSkillNumMade(skillIndex)
		minMade = math.max(1, math.floor(((tonumber(mn) or 1) + (tonumber(mx) or tonumber(mn) or 1)) / 2))
	end

	local ah = _G.PluribusHiveAuction
	local sellInfo = (ah and itemID) and ah:GetPrice(itemID) or nil
	local sellEach = sellInfo and sellInfo.copper or nil
	local sellTotal = sellEach and (sellEach * minMade) or nil

	local reagents = {}
	local matCost = 0
	local missingMatCount = 0
	local numReagents = (GetTradeSkillNumReagents and GetTradeSkillNumReagents(skillIndex)) or 0
	for r = 1, numReagents do
		local rLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(skillIndex, r)
		local rName, _, reqCount, haveCount = GetTradeSkillReagentInfo and GetTradeSkillReagentInfo(skillIndex, r)
		local rID = rLink and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(rLink) or nil
		local rCount = tonumber(reqCount) or 1
		local unitCopper = self:GetReagentUnitPrice(rID)
		if unitCopper then
			matCost = matCost + (unitCopper * rCount)
		else
			missingMatCount = missingMatCount + 1
		end
		table.insert(reagents, {
			itemID = rID,
			name = rName or (rID and ("Item #" .. rID)) or "Reagent",
			link = rLink,
			count = rCount,
			have = tonumber(haveCount) or 0,
			unitCopper = unitCopper,
		})
	end

	local profit = nil
	if sellTotal ~= nil and (numReagents == 0 or missingMatCount < numReagents) then
		profit = math.floor(sellTotal * 0.95) - matCost -- includes 5% AH deposit/cut
	end

	return {
		skillIndex = skillIndex,
		name = skillName,
		skillType = skillType,
		itemID = itemID,
		itemLink = itemLink,
		numMade = minMade,
		sellEach = sellEach,
		sellTotal = sellTotal,
		matCost = matCost,
		profit = profit,
		missingSell = (sellTotal == nil),
		missingMatCount = missingMatCount,
		reagents = reagents,
	}
end

-- Calculate profit for any saved recipe table ({ name, itemID, numMade, reagents = { {id, count}, ... } })
function PluribusHiveProfessions:CalculateStoredRecipeProfit(recipe)
	if not recipe then return nil, nil, nil end
	local ah = _G.PluribusHiveAuction
	local sellInfo = (ah and recipe.itemID and recipe.itemID > 0) and ah:GetPrice(recipe.itemID) or nil
	local numMade = math.max(1, tonumber(recipe.numMade) or 1)
	local sell = sellInfo and sellInfo.copper and (sellInfo.copper * numMade) or nil
	local matCost = 0
	local pricedMats = 0
	for _, rg in ipairs(recipe.reagents or {}) do
		local rid = rg[1] or rg.itemID
		local cnt = rg[2] or rg.count or 1
		local unitCopper = self:GetReagentUnitPrice(rid)
		if unitCopper then
			matCost = matCost + unitCopper * cnt
			pricedMats = pricedMats + 1
		end
	end
	if sell ~= nil and (#(recipe.reagents or {}) == 0 or pricedMats > 0) then
		return math.floor(sell * 0.95) - matCost, sell, matCost
	end
	return nil, sell, matCost > 0 and matCost or nil
end

-- Return ALL craft profits from BOTH open TradeSkill/Craft AND saved scanned recipes (so Craft Profits ALWAYS works!)
function PluribusHiveProfessions:GetAllCraftProfits(searchQuery)
	local out = {}
	local seen = {}
	local q = tostring(searchQuery or ""):lower():match("^%s*(.-)%s*$") or ""

	-- 1. Open TradeSkill window (live)
	if _G.TradeSkillFrame and _G.TradeSkillFrame:IsShown() and GetNumTradeSkills and GetTradeSkillInfo then
		local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"
		local total = GetNumTradeSkills() or 0
		for i = 1, total do
			local info = self:CalculateRecipeProfit(i)
			if info then
				info.prof = activeProf
				local key = (activeProf .. ":" .. info.name):lower()
				if not seen[key] then
					seen[key] = true
					if q == "" or info.name:lower():find(q, 1, true) or activeProf:lower():find(q, 1, true) then
						table.insert(out, info)
					end
				end
			end
		end
	end

	-- 2. Saved scanned recipes for MY character (works even when profession window is closed!)
	local db = EnsureShoppingDB()
	local me = PluribusHive:GetPlayerShortName()
	local myRecs = db.guildRecipes[me] or {}
	for profName, rList in pairs(myRecs) do
		local canon = CanonicalProf(profName)
		for _, rec in ipairs(rList or {}) do
			if rec.name and rec.name ~= "" then
				local key = (canon .. ":" .. rec.name):lower()
				if not seen[key] then
					seen[key] = true
					if q == "" or rec.name:lower():find(q, 1, true) or canon:lower():find(q, 1, true) then
						local net, sellTotal, matCost = self:CalculateStoredRecipeProfit(rec)
						local _, link = (rec.itemID and rec.itemID > 0) and PluribusUtils:GetItemInfo(rec.itemID) or nil, nil
						table.insert(out, {
							name = rec.name,
							prof = canon,
							itemID = rec.itemID or 0,
							itemLink = link,
							numMade = tonumber(rec.numMade) or 1,
							sellTotal = sellTotal,
							matCost = matCost or 0,
							profit = net,
							reagents = rec.reagents or {},
						})
					end
				end
			end
		end
	end

	table.sort(out, function(a, b)
		if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
		if a.profit and b.profit and a.profit ~= b.profit then return a.profit > b.profit end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

function PluribusHiveProfessions:GetOpenProfessionProfits()
	return self:GetAllCraftProfits(self.profitSearchQuery)
end

-- Inline profit text column inside WoW's native TradeSkillFrame list + Detail Profit bar + "+ To-Do" button
function PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
	if not _G.TradeSkillFrame or not _G.TradeSkillFrame:IsShown() then return end
	local offset = (FauxScrollFrame_GetOffset and _G.TradeSkillListScrollFrame and FauxScrollFrame_GetOffset(_G.TradeSkillListScrollFrame)) or 0
	local numSkills = (GetNumTradeSkills and GetNumTradeSkills()) or 0
	local maxBtns = _G.TRADE_SKILLS_DISPLAYED or 25

	for i = 1, maxBtns do
		local btn = _G["TradeSkillSkill" .. i]
		if btn then
			if not btn._plbProfitText then
				local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				fs:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
				fs:SetJustifyH("RIGHT")
				btn._plbProfitText = fs
			end
			local skillIdx = i + offset
			if btn:IsShown() and skillIdx <= numSkills then
				local info = self:CalculateRecipeProfit(skillIdx)
				if info then
					if info.profit ~= nil then
						btn._plbProfitText:SetText(self:FormatSignedGold(info.profit))
					else
						btn._plbProfitText:SetText("|cff64748b--|r")
					end
					btn._plbProfitText:Show()
				else
					btn._plbProfitText:Hide()
				end
			else
				btn._plbProfitText:Hide()
			end
		end
	end

	local detailParent = _G.TradeSkillDetailScrollChildFrame or _G.TradeSkillFrame
	if detailParent and GetTradeSkillSelectionIndex then
		local selIdx = GetTradeSkillSelectionIndex()
		local selInfo = selIdx and selIdx > 0 and self:CalculateRecipeProfit(selIdx) or nil
		if not detailParent._plbProfitBar and _G.PluribusUIFramework then
			local UI = _G.PluribusUIFramework
			local bar = CreateFrame("Frame", nil, detailParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			bar:SetSize(296, 26)
			bar:SetPoint("TOPLEFT", detailParent, "TOPLEFT", 4, -2)
			UI:ApplyBackdrop(bar, 0.06, 0.09, 0.15, 0.94, 0.22, 0.56, 0.84, 0.85)

			local lbl = UI:CreateLabel(bar, "", 0.88, 0.94, 1.0, "GameFontHighlightSmall")
			lbl:SetPoint("LEFT", bar, "LEFT", 6, 0)
			bar.lbl = lbl

			local addShopBtn = UI:CreateButton(bar, L("PROF_ADD_TODO"), 64, 20, function()
				if bar._selInfo then
					local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"
					PluribusHiveProfessions:AddRecipeToShoppingList({
						name = bar._selInfo.name,
						prof = activeProf,
						itemID = bar._selInfo.itemID or 0,
						reagents = bar._selInfo.reagents,
					}, 1)
				end
			end, true)
			addShopBtn:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
			bar.addShopBtn = addShopBtn
			detailParent._plbProfitBar = bar
		end

		local bar = detailParent._plbProfitBar
		if bar then
			if selInfo then
				bar._selInfo = selInfo
				local sellTxt = selInfo.sellTotal and PluribusUtils:FormatGold(selInfo.sellTotal) or "?"
				local matTxt = PluribusUtils:FormatGold(selInfo.matCost or 0)
				local profTxt = selInfo.profit ~= nil and self:FormatSignedGold(selInfo.profit) or "|cff94a3b8AH?|r"
				bar.lbl:SetText(string.format("|cfffbbf24AH:|r %s  |cff94a3b8Mats:|r %s  %s", sellTxt, matTxt, profTxt))
				bar:Show()
			else
				bar:Hide()
			end
		end
	end
end

function PluribusHiveProfessions:HookTradeSkillProfitDisplay()
	if self.tradeHooksInstalled then return end
	if hooksecurefunc and _G.TradeSkillFrame_Update then
		self.tradeHooksInstalled = true
		pcall(hooksecurefunc, "TradeSkillFrame_Update", function()
			PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
		end)
	end
end

function PluribusHiveProfessions:ScanMyProfessions()
	local profs = {}
	local added = {}

	if GetProfessions and GetProfessionInfo then
		-- Numeric 1..6 iteration (NEVER ipairs!) because Classic has nil for Archaeology (slot 3)
		local slots = { GetProfessions() }
		for i = 1, 6 do
			local idx = slots[i]
			if idx then
				local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(idx)
				local canon = CanonicalProf(name)
				if canon and not added[canon] then
					added[canon] = true
					table.insert(profs, { name = canon, displayName = name, level = skillLevel or 0, max = maxSkillLevel or 300 })
				end
			end
		end
	end

	if #profs == 0 and GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
			if skillName and not isHeader and KNOWN_PROFESSIONS[skillName] then
				local canon = CanonicalProf(skillName)
				if canon and not added[canon] then
					added[canon] = true
					table.insert(profs, { name = canon, displayName = skillName, level = skillRank or 0, max = skillMaxRank or 300 })
				end
			end
		end
	end

	local needs = {}
	for _, p in ipairs(profs) do
		local brackets = self.LEVELING_MATS[p.name]
		if brackets and p.level < (p.max or 300) then
			for _, br in ipairs(brackets) do
				if p.level >= br[1] - 10 and p.level <= br[2] + 15 then
					for _, itemID in ipairs(br[3]) do
						needs[itemID] = { itemID = itemID, prof = p.name, level = p.level, max = p.max, qty = 20 }
					end
				end
			end
		end
	end

	local db = EnsureShoppingDB()
	local combinedShop = self:GetAggregatedShoppingMaterials()
	for itemID, entry in pairs(combinedShop) do
		if type(itemID) == "number" and entry.qty > 0 then
			needs[itemID] = needs[itemID] or { itemID = itemID, prof = "To-Do", level = 0, max = 0, qty = entry.qty }
			needs[itemID].qty = math.max(needs[itemID].qty or 0, entry.qty)
		end
	end

	local me = PluribusHive:GetPlayerShortName()
	db.guildProfs[me] = {
		name = me,
		class = PluribusHive:GetPlayerClass(),
		profs = profs,
		needs = needs,
		updatedAt = time(),
	}
	return db.guildProfs[me]
end

local function ComputeRecipeFingerprint(list)
	if not list or #list == 0 then return "" end
	local parts = {}
	local n = math.min(5, #list)
	for i = 1, n do
		table.insert(parts, tostring(list[i].name or ""))
	end
	return tostring(#list) .. "|" .. table.concat(parts, ";")
end

-- Debounced scan scheduler so switching professions NEVER reads stale recipes from the previous profession frame!
function PluribusHiveProfessions:ScheduleTradeSkillScan(delay)
	self._scanToken = (self._scanToken or 0) + 1
	local myToken = self._scanToken
	if C_Timer and C_Timer.After then
		C_Timer.After(delay or 0.25, function()
			if PluribusHiveProfessions._scanToken == myToken then
				PluribusHiveProfessions:ScanOpenTradeSkill()
			end
		end)
	else
		self:ScanOpenTradeSkill()
	end
end

-- Scan currently open Classic TradeSkill, Classic Craft (Enchanting!), OR C_TradeSkillUI!
-- Strictly verifies frame visibility, non-linked own profession, before/after profession consistency, and stale-buffer fingerprint!
function PluribusHiveProfessions:ScanOpenTradeSkill(isRetry)
	-- Never scan someone else's linked or guild profession window as our own!
	if IsTradeSkillLinked and IsTradeSkillLinked() then return end
	if IsTradeSkillGuild and IsTradeSkillGuild() then return end
	if C_TradeSkillUI then
		if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return end
		if C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() then return end
	end

	local me = PluribusHive:GetPlayerShortName()
	local db = EnsureShoppingDB()
	local rec = db.guildProfs[me] or self:ScanMyProfessions()
	db.guildRecipes[me] = db.guildRecipes[me] or {}

	local scannedProf = nil
	local profRecipes = {}

	local tradeShown = (_G.TradeSkillFrame and _G.TradeSkillFrame:IsShown()) == true
	local craftShown = (_G.CraftFrame and _G.CraftFrame:IsShown()) == true
	local modernReady = C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() == true

	-- Path A: Classic TradeSkill API (ONLY when TradeSkillFrame is genuinely open!)
	if tradeShown and GetNumTradeSkills and GetTradeSkillInfo and (GetNumTradeSkills() or 0) > 0 then
		local rawBefore = GetTradeSkillLine and GetTradeSkillLine()
		local profBefore = CanonicalProf(rawBefore)
		if not profBefore then return end
		local total = GetNumTradeSkills() or 0
		for i = 1, total do
			local rName, skillType = GetTradeSkillInfo(i)
			if rName and skillType ~= "header" and skillType ~= "subheader" then
				local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
				local craftedID = itemLink and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(itemLink) or 0
				local minMade = 1
				if GetTradeSkillNumMade then
					local mn, mx = GetTradeSkillNumMade(i)
					minMade = math.max(1, math.floor(((tonumber(mn) or 1) + (tonumber(mx) or tonumber(mn) or 1)) / 2))
				end
				local numReagents = (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)) or 0
				local reagents = {}
				for r = 1, numReagents do
					local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
					local _, _, reqCount = GetTradeSkillReagentInfo and GetTradeSkillReagentInfo(i, r)
					local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if itemID and itemID > 0 then
						table.insert(reagents, { itemID, tonumber(reqCount) or 1 })
						if skillType == "optimal" or skillType == "medium" then
							rec.needs[itemID] = {
								itemID = itemID,
								prof = profBefore,
								level = 0,
								max = 300,
								qty = math.max((rec.needs[itemID] and rec.needs[itemID].qty) or 0, (tonumber(reqCount) or 1) * 5),
							}
						end
					end
				end
				table.insert(profRecipes, {
					name = rName,
					itemID = craftedID,
					numMade = minMade,
					reagents = reagents,
				})
			end
		end
		local profAfter = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine())
		if profAfter ~= profBefore then return end
		scannedProf = profBefore
	-- Path B: Classic Craft API (ONLY when CraftFrame is genuinely open, e.g. Enchanting!)
	elseif craftShown and GetNumCrafts and GetCraftInfo and (GetNumCrafts() or 0) > 0 then
		local craftLine = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
		local profBefore = CanonicalProf(craftLine)
		if not profBefore then return end
		for i = 1, GetNumCrafts() do
			local cName, _, cType = GetCraftInfo(i)
			if cName and cType ~= "header" then
				local itemLink = GetCraftItemLink and GetCraftItemLink(i)
				local craftedID = itemLink and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(itemLink) or 0
				local numReagents = (GetCraftNumReagents and GetCraftNumReagents(i)) or 0
				local reagents = {}
				for r = 1, numReagents do
					local link = GetCraftReagentItemLink and GetCraftReagentItemLink(i, r)
					local _, _, reqCount = GetCraftReagentInfo and GetCraftReagentInfo(i, r)
					local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if itemID and itemID > 0 then
						table.insert(reagents, { itemID, tonumber(reqCount) or 1 })
					end
				end
				table.insert(profRecipes, {
					name = cName,
					itemID = craftedID,
					numMade = 1,
					reagents = reagents,
				})
			end
		end
		local profAfter = GetCraftDisplaySkillLine and CanonicalProf(GetCraftDisplaySkillLine())
		if profAfter ~= profBefore then return end
		scannedProf = profBefore
	-- Path C: Modern C_TradeSkillUI (ONLY when C_TradeSkillUI reports Ready!)
	elseif modernReady and C_TradeSkillUI.GetAllRecipeIDs then
		local okIds, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
		if okIds and type(ids) == "table" and #ids > 0 then
			local infoLine = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
			local profBefore = CanonicalProf(infoLine and infoLine.professionName)
			if not profBefore then return end
			for _, rid in ipairs(ids) do
				local okR, rInfo = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
				if okR and rInfo and rInfo.learned and rInfo.name then
					local reagents = {}
					local craftedID = 0
					if C_TradeSkillUI.GetRecipeSchematic then
						local okS, schem = pcall(C_TradeSkillUI.GetRecipeSchematic, rid, false)
						if okS and schem then
							craftedID = tonumber(schem.outputItemID) or 0
							for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
								local rg = slot.reagents and slot.reagents[1]
								if rg and rg.itemID then
									table.insert(reagents, { tonumber(rg.itemID), tonumber(slot.quantityRequired) or 1 })
								end
							end
						end
					end
					table.insert(profRecipes, {
						name = rInfo.name,
						itemID = craftedID,
						numMade = 1,
						reagents = reagents,
					})
				end
			end
			scannedProf = profBefore
		end
	end

	if scannedProf and #profRecipes > 0 then
		-- Cross-profession stale-buffer guard: never save identical recipe list from a just-closed different profession!
		local fp = ComputeRecipeFingerprint(profRecipes)
		if fp ~= "" then
			for otherProf, otherList in pairs(db.guildRecipes[me] or {}) do
				if otherProf ~= scannedProf and ComputeRecipeFingerprint(otherList) == fp then
					if not isRetry and C_Timer and C_Timer.After then
						C_Timer.After(0.35, function()
							PluribusHiveProfessions:ScanOpenTradeSkill(true)
						end)
					end
					return
				end
			end
		end

		db.guildRecipes[me][scannedProf] = profRecipes
		rec.updatedAt = time()
		self:BroadcastProfessions()
		self:BroadcastRecipes(scannedProf)
	end
end

function PluribusHiveProfessions:BroadcastProfessions()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareProfessions then return end
	local me = PluribusHive:GetPlayerShortName()
	local db = EnsureShoppingDB()
	local rec = db.guildProfs[me] or self:ScanMyProfessions()

	local profParts = {}
	for _, p in ipairs(rec.profs or {}) do
		table.insert(profParts, string.format("%s:%d:%d", p.name, p.level or 0, p.max or 300))
	end
	local needParts = {}
	for itemID, n in pairs(rec.needs or {}) do
		table.insert(needParts, string.format("%d:%s:%d", itemID, (n.prof or ""):gsub("[,:|]", ""), n.qty or 10))
	end

	local payload = string.format("%s|%s|%s",
		rec.class or "WARRIOR",
		table.concat(profParts, ","),
		table.concat(needParts, ",")
	)
	PluribusHive:SendBackground("PROF", payload, "PROF")
end

function PluribusHiveProfessions:BroadcastRecipes(onlyProf)
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareProfessions then return end
	local me = PluribusHive:GetPlayerShortName()
	local db = EnsureShoppingDB()
	local myRecs = db.guildRecipes[me] or {}
	local cls = PluribusHive:GetPlayerClass()

	for profName, rList in pairs(myRecs) do
		if not onlyProf or profName == onlyProf then
			local parts = {}
			for idx, r in ipairs(rList) do
				if idx > 80 then break end
				local rgParts = {}
				for _, rg in ipairs(r.reagents or {}) do
					table.insert(rgParts, string.format("%d*%d", rg[1] or 0, rg[2] or 1))
				end
				local cleanName = tostring(r.name or ""):gsub("[|;,^]", " ")
				table.insert(parts, string.format("%s^%d^%s", cleanName, tonumber(r.itemID) or 0, table.concat(rgParts, ",")))
			end
			if #parts > 0 then
				local payload = string.format("%s|%s|%s", cls, profName, table.concat(parts, ";"))
				PluribusHive:SendBackground("RECIPES", payload, "RECIPES:" .. profName)
			end
		end
	end
end

-- ============================================================================
-- REAL OWNED-ONLY GUILD RECIPE DIRECTORY (NO PHANTOM UNOWNED RECIPES!)
-- Supports live searchQuery & onlyMine toggle.
-- ============================================================================
function PluribusHiveProfessions:GetProfessionDirectory(searchQuery, onlyMine)
	local db = EnsureShoppingDB()
	local me = PluribusHive:GetPlayerShortName()
	local q = tostring(searchQuery or ""):lower():match("^%s*(.-)%s*$") or ""
	local byProf = {}

	local function EnsureProf(pName)
		if not byProf[pName] then
			byProf[pName] = { prof = pName, recipeMap = {}, craftersSet = {} }
		end
		return byProf[pName]
	end

	-- Build player skill lookup from db.guildProfs
	local playerProfMeta = {}
	for memberName, pRec in pairs(db.guildProfs or {}) do
		local norm = PluribusHive:NormalizeName(memberName)
		local canonMember = PluribusHive:CanonicalKey(norm)
		playerProfMeta[canonMember] = { name = norm, class = pRec.class or "WARRIOR", levels = {} }
		for _, pr in ipairs(pRec.profs or {}) do
			local canon = CanonicalProf(pr.name)
			playerProfMeta[canonMember].levels[canon] = pr.level or 0
		end
	end

	-- Merge ONLY real scanned recipes owned by YOU or synced guildmates
	for memberName, profTable in pairs(db.guildRecipes or {}) do
		local norm = PluribusHive:NormalizeName(memberName)
		local isMe = PluribusHive:SamePlayer(norm, me)
		if (not onlyMine) or isMe then
			local canonMember = PluribusHive:CanonicalKey(norm)
			local pMeta = playerProfMeta[canonMember] or { name = norm, class = isMe and PluribusHive:GetPlayerClass() or "WARRIOR", levels = {} }
			for profName, rList in pairs(profTable or {}) do
				local canon = CanonicalProf(profName)
				for _, r in ipairs(rList or {}) do
					if r.name and r.name ~= "" then
						-- Apply search filter (matches recipe name, profession, crafter, or reagent name)
						local matchesQuery = (q == "")
							or r.name:lower():find(q, 1, true)
							or canon:lower():find(q, 1, true)
							or norm:lower():find(q, 1, true)
						if not matchesQuery then
							for _, rg in ipairs(r.reagents or {}) do
								local rid = rg[1] or rg.itemID
								local rName = rid and PluribusUtils:GetItemInfo(rid)
								if rName and rName:lower():find(q, 1, true) then
									matchesQuery = true
									break
								end
							end
						end

						if matchesQuery then
							local bucket = EnsureProf(canon)
							bucket.craftersSet[canonMember] = { name = norm, class = pMeta.class, level = pMeta.levels[canon] or 300 }
							local rKey = r.name:lower()
							local entry = bucket.recipeMap[rKey]
							if not entry then
								entry = {
									name = r.name,
									prof = canon,
									itemID = tonumber(r.itemID) or 0,
									numMade = tonumber(r.numMade) or 1,
									reagents = r.reagents or {},
									crafters = {},
								}
								bucket.recipeMap[rKey] = entry
							else
								if (entry.itemID == 0) and (tonumber(r.itemID) or 0) > 0 then
									entry.itemID = tonumber(r.itemID)
								end
								if #(r.reagents or {}) > 0 and #(entry.reagents or {}) == 0 then
									entry.reagents = r.reagents
								end
							end
							local already = false
							for _, c in ipairs(entry.crafters) do
								if PluribusHive:SamePlayer(c.name, norm) then already = true break end
							end
							if not already then
								table.insert(entry.crafters, {
									name = norm,
									class = pMeta.class,
									level = pMeta.levels[canon] or 300,
									isMe = isMe,
								})
							end
						end
					end
				end
			end
		end
	end

	-- Finalize sorted categories (only professions that actually have owned recipes!)
	local orderedCategories = {}
	local visited = {}
	local function PushProf(pName)
		local b = byProf[pName]
		if not b or visited[pName] then return end
		visited[pName] = true
		local recipes = {}
		for _, rec in pairs(b.recipeMap) do
			if #rec.crafters > 0 then
				table.sort(rec.crafters, function(a, c2)
					if a.isMe ~= c2.isMe then return a.isMe end
					return a.name < c2.name
				end)
				table.insert(recipes, rec)
			end
		end
		if #recipes > 0 then
			table.sort(recipes, function(a, c2) return a.name < c2.name end)
			local allCrafters = {}
			for _, cr in pairs(b.craftersSet) do table.insert(allCrafters, cr) end
			table.sort(allCrafters, function(a, c2) return (a.level or 0) > (c2.level or 0) end)
			table.insert(orderedCategories, {
				prof = pName,
				recipes = recipes,
				crafters = allCrafters,
			})
		end
	end

	for _, pName in ipairs(self.CRAFTING_PROFS) do PushProf(pName) end
	for pName in pairs(byProf) do PushProf(pName) end
	return orderedCategories
end

-- ============================================================================
-- INTERACTIVE TO-DO & SHOPPING LIST (BUY IN AH vs AUTO FARM ROUTE!)
-- ============================================================================
function PluribusHiveProfessions:GetItemTodoMode(itemID)
	local db = EnsureShoppingDB()
	local m = db.todoModes[tonumber(itemID) or 0]
	if m == "FARM" then return "FARM" end
	return "BUY"
end

function PluribusHiveProfessions:SetItemTodoMode(itemID, mode)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return end
	local db = EnsureShoppingDB()
	db.todoModes[itemID] = (mode == "FARM") and "FARM" or "BUY"
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_TODO_CHANGED", itemID) end)
	end
end

function PluribusHiveProfessions:AddRecipeToShoppingList(recipe, craftCount)
	if not recipe or not recipe.name then return false end
	local db = EnsureShoppingDB()
	local key = (recipe.prof or "Craft") .. ":" .. recipe.name
	local count = math.max(1, tonumber(craftCount) or 1)
	local reagents = {}
	for _, rg in ipairs(recipe.reagents or {}) do
		local rid = rg[1] or rg.itemID
		local cnt = rg[2] or rg.count or 1
		if rid and rid > 0 then
			table.insert(reagents, { itemID = rid, count = cnt })
		end
	end

	if db.myShoppingRecipes[key] then
		db.myShoppingRecipes[key].count = (db.myShoppingRecipes[key].count or 1) + count
		if #reagents > 0 then db.myShoppingRecipes[key].reagents = reagents end
	else
		db.myShoppingRecipes[key] = {
			key = key,
			name = recipe.name,
			prof = recipe.prof or "Profession",
			itemID = tonumber(recipe.itemID) or 0,
			count = count,
			reagents = reagents,
			addedAt = time(),
		}
	end
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_TODO_CHANGED", key) end)
	end
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff4ade80" .. L("TODO_ADDED_RECIPE") .. "|r " .. recipe.name .. " (x" .. count .. ")", 3)
	end
	return true
end

function PluribusHiveProfessions:RemoveRecipeFromShoppingList(key)
	local db = EnsureShoppingDB()
	if db.myShoppingRecipes[key] then
		db.myShoppingRecipes[key] = nil
		self:ScanMyProfessions()
		self:BroadcastProfessions()
		return true
	end
	return false
end

function PluribusHiveProfessions:AddNeededMaterial(itemID, qty)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return false end
	local db = EnsureShoppingDB()
	db.myNeededMats[itemID] = tonumber(qty) or 20
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_TODO_CHANGED", itemID) end)
	end
	if _G.PluribusUIFramework then
		local iName = PluribusUtils:GetItemInfo(itemID) or ("Item #" .. itemID)
		_G.PluribusUIFramework:ShowNotification("|cff4ade80" .. L("TODO_ADDED_ITEM") .. "|r " .. iName .. " (x" .. tostring(db.myNeededMats[itemID]) .. ")", 2.5)
	end
	return true
end

function PluribusHiveProfessions:RemoveNeededMaterial(itemID)
	itemID = tonumber(itemID)
	if not itemID then return false end
	local db = EnsureShoppingDB()
	db.myNeededMats[itemID] = nil
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	return true
end

function PluribusHiveProfessions:GetAggregatedShoppingMaterials()
	local db = EnsureShoppingDB()
	local map = {}
	for itemID, qty in pairs(db.myNeededMats or {}) do
		local id = tonumber(itemID)
		if id and id > 0 and (tonumber(qty) or 0) > 0 then
			map[id] = { itemID = id, qty = tonumber(qty), direct = true, fromRecipes = {} }
		end
	end
	for _, rec in pairs(db.myShoppingRecipes or {}) do
		local mult = math.max(1, tonumber(rec.count) or 1)
		for _, rg in ipairs(rec.reagents or {}) do
			local id = tonumber(rg.itemID or rg[1])
			local need = (tonumber(rg.count or rg[2]) or 1) * mult
			if id and id > 0 and need > 0 then
				if not map[id] then
					map[id] = { itemID = id, qty = 0, direct = false, fromRecipes = {} }
				end
				map[id].qty = map[id].qty + need
				table.insert(map[id].fromRecipes, rec.name)
			end
		end
	end
	return map
end

function PluribusHiveProfessions:GetOwnedCount(itemID)
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.GetMyAltRecord then
		local rec = _G.PluribusHiveInventory:GetMyAltRecord()
		return ((rec.bags and rec.bags[itemID]) or 0) + ((rec.bank and rec.bank[itemID]) or 0)
	end
	return (GetItemCount and GetItemCount(itemID, true)) or 0
end

function PluribusHiveProfessions:GetPickerCategories()
	local UI = _G.PluribusUIFramework
	return {
		{ key = "MY_RECIPES",    label = L("PROF_ONLY_MINE") .. " (" .. L("PROF_GUILD_RECIPES") .. ")", icon = "Interface\\Icons\\INV_Scroll_03" },
		{ key = "OPEN_PROF",     label = "Open Profession Reagents",   icon = "Interface\\Icons\\Trade_BlackSmithing" },
		{ key = "Alchemy",       label = "Alchemy & Herbs",            icon = UI and UI:GetProfessionIcon("Alchemy") },
		{ key = "Blacksmithing", label = "Mining & Blacksmithing",     icon = UI and UI:GetProfessionIcon("Blacksmithing") },
		{ key = "Enchanting",    label = "Enchanting Dusts & Shards",  icon = UI and UI:GetProfessionIcon("Enchanting") },
		{ key = "Tailoring",     label = "Tailoring & Cloth",          icon = UI and UI:GetProfessionIcon("Tailoring") },
		{ key = "Leatherworking",label = "Leatherworking & Hides",     icon = UI and UI:GetProfessionIcon("Leatherworking") },
		{ key = "Engineering",   label = "Engineering Parts",          icon = UI and UI:GetProfessionIcon("Engineering") },
		{ key = "Cooking",       label = "Cooking & First Aid",        icon = UI and UI:GetProfessionIcon("Cooking") },
		{ key = "MY_BAGS",       label = "My Bags & Guild Items",      icon = "Interface\\Icons\\INV_Misc_Bag_08" },
		{ key = "AH_ITEMS",      label = "AH Scanned Items",           icon = "Interface\\Icons\\INV_Misc_Coin_02" },
	}
end

function PluribusHiveProfessions:GetItemsForPickerCategory(catKey)
	local seen = {}
	local out = {}
	local function addItem(id)
		id = tonumber(id)
		if not id or id <= 0 or seen[id] then return end
		seen[id] = true
		local name, link, quality = PluribusUtils:GetItemInfo(id)
		table.insert(out, { itemID = id, name = name or ("Item #" .. id), link = link, quality = quality or 1 })
	end

	if catKey == "OPEN_PROF" then
		if GetNumTradeSkills and GetTradeSkillNumReagents and GetTradeSkillReagentItemLink then
			for i = 1, GetNumTradeSkills() do
				local _, st = GetTradeSkillInfo(i)
				if st ~= "header" and st ~= "subheader" then
					for r = 1, (GetTradeSkillNumReagents(i) or 0) do
						local link = GetTradeSkillReagentItemLink(i, r)
						local id = link and PluribusUtils:GetItemIDFromHyperlink(link)
						if id then addItem(id) end
					end
				end
			end
		end
	elseif catKey == "MY_BAGS" then
		if _G.PluribusHiveInventory then
			local myRec = _G.PluribusHiveInventory:GetMyAltRecord()
			for id in pairs(myRec.bags or {}) do addItem(id) end
			for id in pairs(myRec.bank or {}) do addItem(id) end
		end
	elseif catKey == "AH_ITEMS" then
		local db = PluribusHive:GetDB()
		for id in pairs(db.prices or {}) do addItem(id) end
	elseif self.LEVELING_MATS[catKey] then
		for _, br in ipairs(self.LEVELING_MATS[catKey]) do
			for _, id in ipairs(br[3]) do addItem(id) end
		end
	end

	table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
	return out
end

-- ============================================================================
-- SURPLUS MATCHING & GUILD NEEDS SUMMARY
-- ============================================================================
function PluribusHiveProfessions:DoINeedItem(itemID)
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local mine = db.guildProfs[me]
	return mine and mine.needs and mine.needs[itemID] ~= nil or false
end

function PluribusHiveProfessions:GetAllGuildNeeds()
	self:PruneDuplicateOwners()
	local db = EnsureShoppingDB()
	local byItem = {}
	local seenMember = {}
	for memberName, rec in pairs(db.guildProfs or {}) do
		local cKey = PluribusHive:CanonicalKey(memberName)
		if cKey ~= "" and not seenMember[cKey] then
			seenMember[cKey] = true
			local norm = PluribusHive:NormalizeName(memberName)
			for itemID, n in pairs(rec.needs or {}) do
				local id = tonumber(itemID)
				if id and id > 0 then
					byItem[id] = byItem[id] or {}
					table.insert(byItem[id], { name = norm, prof = n.prof, qty = n.qty or 10 })
				end
			end
		end
	end
	return byItem
end

function PluribusHiveProfessions:GetGuildNeedsForItem(itemID)
	if not itemID then return {}, false end
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local iNeedIt = self:DoINeedItem(itemID)
	local neededBy = {}
	local seenCanon = {}

	for memberName, rec in pairs(db.guildProfs or {}) do
		local cKey = PluribusHive:CanonicalKey(memberName)
		if cKey ~= "" and not seenCanon[cKey] and not PluribusHive:SamePlayer(memberName, me) and rec.needs and rec.needs[itemID] then
			seenCanon[cKey] = true
			local n = rec.needs[itemID]
			local profLevel = n.level or 0
			local profMax = n.max or 300
			for _, p in ipairs(rec.profs or {}) do
				if p.name == n.prof then
					profLevel = p.level
					profMax = p.max
					break
				end
			end
			table.insert(neededBy, {
				name = PluribusHive:NormalizeName(memberName),
				class = rec.class or "WARRIOR",
				prof = n.prof or "Profession",
				level = profLevel,
				max = profMax,
				qty = n.qty or 10,
			})
		end
	end

	table.sort(neededBy, function(a, b) return a.name < b.name end)
	return neededBy, (not iNeedIt)
end

function PluribusHiveProfessions:GetMySurplusMatches()
	if not _G.PluribusHiveInventory then return {} end
	local myRec = _G.PluribusHiveInventory:GetMyAltRecord()
	local combined = {}
	for id, cnt in pairs(myRec.bags or {}) do combined[id] = (combined[id] or 0) + cnt end
	for id, cnt in pairs(myRec.bank or {}) do combined[id] = (combined[id] or 0) + cnt end

	local matches = {}
	for itemID, qty in pairs(combined) do
		if qty > 0 then
			local neededBy, isSurplus = self:GetGuildNeedsForItem(itemID)
			if isSurplus and #neededBy > 0 then
				local name, link, quality = PluribusUtils:GetItemInfo(itemID)
				table.insert(matches, {
					itemID = itemID,
					name = name or ("Item #" .. itemID),
					link = link,
					quality = quality or 1,
					myCount = qty,
					neededBy = neededBy,
				})
			end
		end
	end

	table.sort(matches, function(a, b) return a.name < b.name end)
	return matches
end

-- ============================================================================
-- REUSABLE GRAPHICAL RENDERERS (Shared cleanly by MainFrame & TradeSkill Drawer)
-- ============================================================================

-- 1. Real Owned-Only Guild Recipes Directory WITH LIVE SEARCH + "Nur Meine / Alle Gilde"
function PluribusHiveProfessions:RenderGuildRecipesDirectory(container, width, startY, onChanged)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local isCompact = width < 380

	-- Top Controls Row: Live Search Box (keeps focus while filtering listContainer below!) + Mine/All Toggle
	local sLbl = UI:CreateLabel(container, "|cfffbbf24" .. L("SEARCH") .. "|r", 1, 1, 1)
	sLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 5)

	local sBoxW = isCompact and 130 or 200
	local searchBox = UI:CreateInputBox(container, sBoxW, 24)
	searchBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
	searchBox:SetText(self.recipeSearchQuery or "")

	local listHolder = CreateFrame("Frame", nil, container)
	listHolder:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y - 66)
	listHolder:SetWidth(width)
	listHolder:SetHeight(240)

	local function PopulateList()
		UI:ClearContainer(listHolder)
		local ly = 0
		local categories = PluribusHiveProfessions:GetProfessionDirectory(PluribusHiveProfessions.recipeSearchQuery, PluribusHiveProfessions.onlyMyRecipes)

		if #categories == 0 then
			local card = UI:CreateBannerCard(listHolder, width - 4, 62, "Interface\\Icons\\Trade_BlackSmithing",
				"|cfffbbf24" .. L("PROF_GUILD_RECIPES") .. "|r",
				L("PROF_NO_RECIPES_YET"),
				0.92, 0.72, 0.22)
			card:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)
			ly = ly - 68
			listHolder:SetHeight(math.max(120, math.abs(ly) + 8))
			container:SetHeight(math.max(300, math.abs(y - 66) + math.abs(ly) + 20))
			return
		end

		for _, cat in ipairs(categories) do
			if PluribusHiveProfessions.selectedCrafterProf == "ALL" or PluribusHiveProfessions.selectedCrafterProf == cat.prof then
				local catBar = UI:CreateCard(listHolder, width - 4, 28)
				catBar:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)
				local pIcon = UI:CreateProfessionIcon(catBar, cat.prof, 20)
				pIcon:SetPoint("LEFT", catBar, "LEFT", 6, 0)
				local dispProf = PluribusHiveProfessions:GetProfessionDisplayName(cat.prof)
				local pTitle = UI:CreateLabel(catBar, string.format("|cff38bdf8%s|r  |cff94a3b8(%d · %d)|r", dispProf, #cat.recipes, #cat.crafters), 1, 1, 1, "GameFontNormal")
				pTitle:SetPoint("LEFT", pIcon, "RIGHT", 8, 0)
				ly = ly - 32

				for idx, rec in ipairs(cat.recipes) do
					local rowH = isCompact and 48 or 42
					local row = UI:CreateListRow(listHolder, width - 4, rowH, idx)
					row:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)

					local slot = UI:CreateItemSlot(row, 30, {
						itemID = rec.itemID > 0 and rec.itemID or nil,
						name = rec.name,
						quality = 2,
					})
					slot:SetPoint("LEFT", row, "LEFT", 5, 0)

					local netProfit = PluribusHiveProfessions:CalculateStoredRecipeProfit(rec)
					local profBadge = netProfit ~= nil and ("  " .. PluribusHiveProfessions:FormatSignedGold(netProfit)) or ""
					local l1 = UI:CreateLabel(row, "|cffffffff" .. rec.name:sub(1, isCompact and 20 or 34) .. "|r" .. profBadge)
					l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -1)

					local crafterNames = {}
					for ci, cr in ipairs(rec.crafters) do
						if ci <= 4 then
							local _, _, _, hex = UI:GetClassColor(cr.class)
							table.insert(crafterNames, hex .. cr.name .. "|r")
						end
					end
					if #rec.crafters > 4 then
						table.insert(crafterNames, "+" .. (#rec.crafters - 4))
					end
					local l2 = UI:CreateLabel(row, table.concat(crafterNames, ", "), 0.72, 0.84, 0.94, "GameFontHighlightSmall")
					l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 7, 1)

					local shopBtn = UI:CreateButton(row, L("PROF_ADD_TODO"), 56, 20, function()
						PluribusHiveProfessions:AddRecipeToShoppingList(rec, 1)
					end, true)
					shopBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

					local primaryCrafter = rec.crafters[1] and rec.crafters[1].name or ""
					if primaryCrafter ~= "" and not PluribusHive:SamePlayer(primaryCrafter, PluribusHive:GetPlayerShortName()) then
						local mailBtn = UI:CreateButton(row, L("PROF_LETTER"), 48, 20, function()
							if _G.PluribusHiveMail then
								_G.PluribusHiveMail:OpenComposer(
									primaryCrafter,
									"Craft: " .. rec.name,
									"Hi! Could you craft " .. rec.name .. " for me?",
									{ itemID = rec.itemID, recipeName = rec.name }
								)
							end
						end)
						mailBtn:SetPoint("RIGHT", shopBtn, "LEFT", -4, 0)

						if not isCompact then
							local wBtn = UI:CreateButton(row, L("PROF_WHISPER"), 62, 20, function()
								if SendChatMessage then
									pcall(SendChatMessage, "Hi " .. primaryCrafter .. "! Kannst du mir " .. rec.name .. " herstellen?", "WHISPER", nil, primaryCrafter)
								elseif ChatFrame_SendTell then
									pcall(ChatFrame_SendTell, primaryCrafter)
								end
							end)
							wBtn:SetPoint("RIGHT", mailBtn, "LEFT", -4, 0)
						end
					end

					ly = ly - (rowH + 2)
				end
				ly = ly - 6
			end
		end

		listHolder:SetHeight(math.max(180, math.abs(ly) + 10))
		container:SetHeight(math.max(300, math.abs(y - 66) + math.abs(ly) + 24))
	end

	local mineBtn, allBtn
	mineBtn = UI:CreateButton(container, L("PROF_ONLY_MINE"), isCompact and 68 or 86, 24, function()
		PluribusHiveProfessions.onlyMyRecipes = true
		mineBtn:SetActiveState(true)
		allBtn:SetActiveState(false)
		PopulateList()
	end)
	mineBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	mineBtn:SetActiveState(self.onlyMyRecipes == true)

	allBtn = UI:CreateButton(container, L("PROF_ALL_GUILD"), isCompact and 68 or 92, 24, function()
		PluribusHiveProfessions.onlyMyRecipes = false
		mineBtn:SetActiveState(false)
		allBtn:SetActiveState(true)
		PopulateList()
	end)
	allBtn:SetPoint("LEFT", mineBtn, "RIGHT", 4, 0)
	allBtn:SetActiveState(self.onlyMyRecipes ~= true)

	-- Second Row: Profession Filter Dropdown + Reset/Rescan button
	local allCats = self:GetProfessionDirectory("", false)
	local dropOpts = { { key = "ALL", label = L("ALL") .. " (" .. #allCats .. ")", icon = "Interface\\Icons\\INV_Misc_Book_09" } }
	for _, cat in ipairs(allCats) do
		table.insert(dropOpts, {
			key = cat.prof,
			label = string.format("%s (%d)", self:GetProfessionDisplayName(cat.prof), #cat.recipes),
			icon = UI:GetProfessionIcon(cat.prof),
		})
	end
	local dd = UI:CreateFlatDropdown(container, math.min(220, width - 92), 24, dropOpts, self.selectedCrafterProf or "ALL", function(key)
		PluribusHiveProfessions.selectedCrafterProf = key
		PopulateList()
	end)
	dd:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 32)

	local resetBtn = UI:CreateButton(container, "Reset", 62, 24, function()
		PluribusHiveProfessions:SanitizeStoredRecipes(true)
		PluribusHiveProfessions.selectedCrafterProf = "ALL"
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Eigene Rezepte zurückgesetzt — öffne deine Berufe zum Neu-Einlesen.|r", 3.5)
		end
		if onChanged then onChanged() else PopulateList() end
	end)
	resetBtn:SetPoint("LEFT", dd, "RIGHT", 6, 0)

	searchBox:SetScript("OnTextChanged", function(selfBox)
		PluribusHiveProfessions.recipeSearchQuery = selfBox:GetText() or ""
		PopulateList()
	end)

	PopulateList()
	return y - 66 - (listHolder:GetHeight() or 200)
end

-- 2. Craft Profits List (Works from BOTH open profession AND saved scanned recipes + live search + vendor fallback!)
function PluribusHiveProfessions:RenderCraftProfits(container, width, startY)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local isCompact = width < 380

	local sLbl = UI:CreateLabel(container, "|cfffbbf24" .. L("SEARCH") .. "|r", 1, 1, 1)
	sLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 5)

	local searchBox = UI:CreateInputBox(container, isCompact and 150 or 220, 24)
	searchBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
	searchBox:SetText(self.profitSearchQuery or "")

	local cutHint = UI:CreateLabel(container, "|cff94a3b8" .. L("PROF_PROFIT_COL") .. "|r", 0.75, 0.85, 0.95, "GameFontHighlightSmall")
	cutHint:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

	local listHolder = CreateFrame("Frame", nil, container)
	listHolder:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y - 34)
	listHolder:SetWidth(width)
	listHolder:SetHeight(240)

	local function PopulateProfits()
		UI:ClearContainer(listHolder)
		local ly = 0
		local profits = PluribusHiveProfessions:GetAllCraftProfits(PluribusHiveProfessions.profitSearchQuery)

		if #profits == 0 then
			local card = UI:CreateBannerCard(listHolder, width - 4, 62, "Interface\\Icons\\INV_Misc_Coin_02",
				"|cfffbbf24" .. L("PROF_CRAFT_PROFITS") .. "|r",
				L("PROF_OPEN_FOR_PROFITS"),
				0.92, 0.72, 0.22)
			card:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)
			ly = ly - 68
			listHolder:SetHeight(math.max(120, math.abs(ly) + 8))
			container:SetHeight(math.max(300, math.abs(y - 34) + math.abs(ly) + 20))
			return
		end

		for idx, info in ipairs(profits) do
			if idx > 80 then break end
			local row = UI:CreateListRow(listHolder, width - 4, 40, idx)
			row:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)

			local slot = UI:CreateItemSlot(row, 28, {
				itemID = info.itemID and info.itemID > 0 and info.itemID or nil,
				name = info.name,
				link = info.itemLink,
				quality = 2,
				count = info.numMade,
			})
			slot:SetPoint("LEFT", row, "LEFT", 5, 0)

			local l1 = UI:CreateLabel(row, "|cffffffff" .. info.name:sub(1, isCompact and 18 or 34) .. "|r |cff94a3b8(" .. (info.prof or "") .. ")|r")
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -1)

			local sellStr = info.sellTotal and PluribusUtils:FormatGold(info.sellTotal) or "?"
			local matStr = PluribusUtils:FormatGold(info.matCost or 0)
			local l2 = UI:CreateLabel(row, L("PROF_SELL_MATS", sellStr, matStr), 0.70, 0.80, 0.90, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 7, 1)

			local shopBtn = UI:CreateButton(row, L("PROF_ADD_TODO"), 56, 20, function()
				PluribusHiveProfessions:AddRecipeToShoppingList({
					name = info.name,
					prof = info.prof or "Profession",
					itemID = info.itemID or 0,
					reagents = info.reagents,
				}, 1)
			end, true)
			shopBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

			local pLbl = UI:CreateLabel(row, PluribusHiveProfessions:FormatSignedGold(info.profit), 1, 1, 1, "GameFontNormalSmall")
			pLbl:SetPoint("RIGHT", shopBtn, "LEFT", -8, 0)

			ly = ly - 42
		end

		listHolder:SetHeight(math.max(180, math.abs(ly) + 10))
		container:SetHeight(math.max(300, math.abs(y - 34) + math.abs(ly) + 24))
	end

	searchBox:SetScript("OnTextChanged", function(selfBox)
		PluribusHiveProfessions.profitSearchQuery = selfBox:GetText() or ""
		PopulateProfits()
	end)

	PopulateProfits()
	return y - 34 - (listHolder:GetHeight() or 200)
end

-- 3. Interactive To-Do & Einkaufsliste (Choose BUY -> 1-click AH Search OR FARM -> Inline Calculated Farm Route + Navigate!)
function PluribusHiveProfessions:RenderWishlistPicker(container, width, startY, onChanged)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local isCompact = width < 380
	local db = EnsureShoppingDB()

	-- Banner explaining the Buy vs Farm workflow
	local banner = UI:CreateBannerCard(container, width - 4, 48, "Interface\\Icons\\INV_Scroll_03",
		"|cfffbbf24" .. L("TODO_TITLE") .. "|r",
		L("TODO_SUBTITLE"),
		0.92, 0.72, 0.22)
	banner:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
	y = y - 54

	-- ACTIVE TO-DO MATERIALS LIST FIRST (Front & Center!)
	local matMap = self:GetAggregatedShoppingMaterials()
	local matList = {}
	for _, m in pairs(matMap) do table.insert(matList, m) end
	table.sort(matList, function(a, b) return a.itemID < b.itemID end)

	local matHdr = UI:CreateLabel(container, "|cff4ade80" .. L("PROF_TODO_LIST") .. " (" .. #matList .. "):|r", 1, 1, 1, "GameFontNormal")
	matHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)

	local isPopOpen = self.todoPopoutFrame and self.todoPopoutFrame:IsShown()
	local popBtn = UI:CreateButton(container, isPopOpen and "Popout schließen" or "Als Popout öffnen", isCompact and 112 or 136, 20, function()
		PluribusHiveProfessions:ToggleTodoPopout()
		if onChanged then onChanged() end
	end, not isPopOpen)
	popBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, y + 2)
	y = y - 24

	if #matList == 0 then
		local em = UI:CreateLabel(container, L("TODO_EMPTY"), 0.70, 0.80, 0.90)
		em:SetPoint("TOPLEFT", container, "TOPLEFT", 6, y)
		em:SetWidth(width - 16)
		y = y - 34
	else
		for idx, m in ipairs(matList) do
			local name, link, quality = PluribusUtils:GetItemInfo(m.itemID)
			local displayName = name or ("Item #" .. m.itemID)
			local owned = self:GetOwnedCount(m.itemID)
			local rem = math.max(0, (m.qty or 1) - owned)
			local haveCol = owned >= m.qty and "|cff4ade80" or "|cfffbbf24"
			local mode = self:GetItemTodoMode(m.itemID)
			local rowH = (mode == "FARM") and 72 or 52

			local row = UI:CreateListRow(container, width - 4, rowH, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 28, { itemID = m.itemID, name = displayName, link = link, quality = quality or 1, count = m.qty })
			slot:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -6)

			local qCol = PluribusUtils:GetQualityColor(quality or 1)
			local lbl = UI:CreateLabel(row, string.format("%s%s|r  %s%d/%d|r", qCol, displayName:sub(1, isCompact and 16 or 30), haveCol, owned, m.qty))
			lbl:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, 0)

			-- Right-side controls: [X] + [Farmen] + [Kaufen]
			local rightAnchor = row
			if m.direct then
				local rmBtn = UI:CreateButton(row, "X", 22, 20, function()
					PluribusHiveProfessions:RemoveNeededMaterial(m.itemID)
					if onChanged then onChanged() end
				end)
				rmBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
				rightAnchor = rmBtn
			end

			local farmToggle = UI:CreateButton(row, L("TODO_MODE_FARM"), isCompact and 62 or 92, 20, function()
				PluribusHiveProfessions:SetItemTodoMode(m.itemID, "FARM")
				if onChanged then onChanged() end
			end)
			if rightAnchor == row then
				farmToggle:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
			else
				farmToggle:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0)
			end
			farmToggle:SetActiveState(mode == "FARM")

			local buyToggle = UI:CreateButton(row, L("TODO_MODE_BUY"), isCompact and 58 or 84, 20, function()
				PluribusHiveProfessions:SetItemTodoMode(m.itemID, "BUY")
				if onChanged then onChanged() end
			end)
			buyToggle:SetPoint("RIGHT", farmToggle, "LEFT", -4, 0)
			buyToggle:SetActiveState(mode == "BUY")

			-- Action / Info Strip right inside the To-Do row!
			if mode == "BUY" then
				local ahInfo = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(m.itemID)
				local priceTxt
				if ahInfo and ahInfo.copper and ahInfo.copper > 0 then
					local totalNeed = ahInfo.copper * math.max(1, rem)
					priceTxt = string.format("|cfffbbf24AH:|r %s/ea  ·  Rest (%d): |cfffef08a%s|r",
						PluribusUtils:FormatGold(ahInfo.copper), rem, PluribusUtils:FormatGold(totalNeed))
				else
					priceTxt = "|cff94a3b8AH: -- (Im AH suchen)|r"
				end
				local subLbl = UI:CreateLabel(row, priceTxt, 0.80, 0.88, 0.96, "GameFontHighlightSmall")
				subLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 7)

				local ahBtn = UI:CreateButton(row, L("TODO_SEARCH_AH"), isCompact and 78 or 98, 20, function()
				if _G.PluribusHiveAuction and _G.PluribusHiveAuction.ahOpen and _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.OpenShoppingForItem then
					_G.PluribusHiveAuctionator:OpenShoppingForItem(displayName)
				elseif _G.PluribusHiveAuction and _G.PluribusHiveAuction.SearchNativeAH then
					_G.PluribusHiveAuction:SearchNativeAH(displayName)
				end
				end, true)
				ahBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
			else
				-- FARM MODE: Automatically display calculated optimal farm route INLINE right here!
				local route = _G.PluribusHiveCompute and _G.PluribusHiveCompute.GetFarmRouteForItem
					and _G.PluribusHiveCompute:GetFarmRouteForItem(m.itemID, displayName)
				local routeLine1, routeLine2
				if route then
					routeLine1 = string.format("|cff4ade80%s|r", L("TODO_ROUTE_LABEL", route.zone, route.x or 50, route.y or 50, route.source or "World"))
					routeLine2 = string.format("|cff94a3b8%s|r", tostring(route.note or route.yieldText or ""))
				else
					routeLine1 = "|cff4ade80Auto-Farmroute: Azeroth Open World|r"
					routeLine2 = "|cff94a3b8Navigiere zur nächsten Farmzone|r"
				end
				local r1 = UI:CreateLabel(row, routeLine1, 0.72, 0.96, 0.80, "GameFontHighlightSmall")
				r1:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -28)
				r1:SetWidth(width - 144)

				local r2 = UI:CreateLabel(row, routeLine2, 0.70, 0.80, 0.90, "GameFontHighlightSmall")
				r2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 6)
				r2:SetWidth(width - 144)

				local navBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), isCompact and 72 or 90, 22, function()
					if route and _G.PluribusNavigationUI then
						_G.PluribusNavigationUI:SetWaypoint("Farm: " .. displayName, route.zone, route.x or 50, route.y or 50)
					end
				end, true)
				navBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 6)
			end

			y = y - (rowH + 3)
		end
	end

	-- Saved Recipes in To-Do List
	local recipeList = {}
	for _, r in pairs(db.myShoppingRecipes or {}) do table.insert(recipeList, r) end
	if #recipeList > 0 then
		y = y - 6
		table.sort(recipeList, function(a, b) return (a.name or "") < (b.name or "") end)
		local recHdr = UI:CreateLabel(container, "|cfffbbf24To-Do Rezepte (" .. #recipeList .. "):|r", 1, 1, 1, "GameFontNormal")
		recHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
		y = y - 20
		for idx, r in ipairs(recipeList) do
			local row = UI:CreateListRow(container, width - 4, 34, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
			local slot = UI:CreateItemSlot(row, 26, { itemID = r.itemID > 0 and r.itemID or nil, name = r.name, quality = 2, count = r.count })
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)
			local l1 = UI:CreateLabel(row, string.format("|cffffffff%s|r |cff4ade80x%d|r  |cff94a3b8(%s · %d Mats)|r", r.name:sub(1, isCompact and 16 or 30), r.count or 1, r.prof or "", #(r.reagents or {})))
			l1:SetPoint("LEFT", slot, "RIGHT", 6, 0)
			local rmBtn = UI:CreateButton(row, "X", 24, 20, function()
				PluribusHiveProfessions:RemoveRecipeFromShoppingList(r.key)
				if onChanged then onChanged() end
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			y = y - 36
		end
	end

	-- QUICK ADD PICKER BELOW (Category Dropdown + Qty + Drag-Drop)
	y = y - 10
	local pickerHdr = UI:CreateLabel(container, "|cff38bdf8" .. L("PROF_ADD_TODO") .. ":|r", 1, 1, 1, "GameFontNormal")
	pickerHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
	y = y - 20

	local ddW = isCompact and 160 or 236
	local dd = UI:CreateFlatDropdown(container, ddW, 24, self:GetPickerCategories(), self.selectedPickerCat or "MY_RECIPES", function(key)
		PluribusHiveProfessions.selectedPickerCat = key
		if onChanged then onChanged() end
	end)
	dd:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

	local qtyCycle = { 1, 5, 10, 20, 40 }
	local qtyBtn = UI:CreateButton(container, "x" .. tostring(self.selectedPickerQty or 10), 48, 24, function()
		local cur = PluribusHiveProfessions.selectedPickerQty or 10
		local nxt = qtyCycle[1]
		for i, v in ipairs(qtyCycle) do
			if v == cur then nxt = qtyCycle[(i % #qtyCycle) + 1] break end
		end
		PluribusHiveProfessions.selectedPickerQty = nxt
		if onChanged then onChanged() end
	end)
	qtyBtn:SetPoint("LEFT", dd, "RIGHT", 6, 0)

	local dropBtn = UI:CreateButton(container, isCompact and "Drop" or "Item hier ablegen", isCompact and 54 or 130, 24, function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveProfessions:AddNeededMaterial(itemID, PluribusHiveProfessions.selectedPickerQty or 10)
				if ClearCursor then pcall(ClearCursor) end
				if onChanged then onChanged() end
			end
		end
	end)
	dropBtn:SetPoint("LEFT", qtyBtn, "RIGHT", 6, 0)
	dropBtn:SetScript("OnReceiveDrag", function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveProfessions:AddNeededMaterial(itemID, PluribusHiveProfessions.selectedPickerQty or 10)
				if ClearCursor then pcall(ClearCursor) end
				if onChanged then onChanged() end
			end
		end
	end)
	y = y - 30

	if self.selectedPickerCat == "MY_RECIPES" then
		local dir = self:GetProfessionDirectory("", true)
		local shown = 0
		for _, cat in ipairs(dir) do
			for _, rec in ipairs(cat.recipes) do
				if shown >= 12 then break end
				shown = shown + 1
				local row = UI:CreateListRow(container, width - 4, 32, shown)
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
				local slot = UI:CreateItemSlot(row, 24, { itemID = rec.itemID > 0 and rec.itemID or nil, name = rec.name, quality = 2 })
				slot:SetPoint("LEFT", row, "LEFT", 4, 0)
				local lbl = UI:CreateLabel(row, string.format("|cffffffff%s|r |cff94a3b8(%s)|r", rec.name:sub(1, isCompact and 18 or 34), cat.prof))
				lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)
				local addBtn = UI:CreateButton(row, L("PROF_ADD_TODO"), 60, 20, function()
					PluribusHiveProfessions:AddRecipeToShoppingList(rec, math.min(10, PluribusHiveProfessions.selectedPickerQty or 1))
					if onChanged then onChanged() end
				end, true)
				addBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
				y = y - 34
			end
			if shown >= 12 then break end
		end
		if shown == 0 then
			local em = UI:CreateLabel(container, L("PROF_NO_RECIPES_YET"), 0.68, 0.78, 0.88, "GameFontHighlightSmall")
			em:SetPoint("TOPLEFT", container, "TOPLEFT", 6, y)
			em:SetWidth(width - 14)
			y = y - 30
		end
	else
		local items = self:GetItemsForPickerCategory(self.selectedPickerCat)
		local limit = math.min(#items, 12)
		for idx = 1, limit do
			local it = items[idx]
			local already = db.myNeededMats[it.itemID] ~= nil
			local row = UI:CreateListRow(container, width - 4, 32, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
			local slot = UI:CreateItemSlot(row, 24, { itemID = it.itemID, name = it.name, link = it.link, quality = it.quality })
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)
			local ahInfo = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(it.itemID)
			local priceStr = ahInfo and (" · |cfffbbf24" .. PluribusUtils:FormatGold(ahInfo.copper) .. "|r") or ""
			local qCol = PluribusUtils:GetQualityColor(it.quality)
			local lbl = UI:CreateLabel(row, qCol .. it.name:sub(1, isCompact and 18 or 30) .. "|r" .. priceStr)
			lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)
			local toggleBtn = UI:CreateButton(row, already and "OK" or ("+ x" .. tostring(self.selectedPickerQty or 10)), 58, 20, function()
				if already then
					PluribusHiveProfessions:RemoveNeededMaterial(it.itemID)
				else
					PluribusHiveProfessions:AddNeededMaterial(it.itemID, PluribusHiveProfessions.selectedPickerQty or 10)
				end
				if onChanged then onChanged() end
			end, not already)
			toggleBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			y = y - 34
		end
	end

	return y
end

-- ============================================================================
-- UNLEARNED PROFESSION RECIPES (VENDOR / DROP BADGES + 1-CLICK NAVIGATION)
-- ============================================================================
function PluribusHiveProfessions:GetOpenProfessionName()
	if _G.TradeSkillFrame and _G.TradeSkillFrame:IsShown() and GetTradeSkillLine then
		local canon = CanonicalProf(GetTradeSkillLine())
		if canon then return canon end
	end
	if _G.CraftFrame and _G.CraftFrame:IsShown() and GetCraftDisplaySkillLine then
		local canon = CanonicalProf(GetCraftDisplaySkillLine())
		if canon then return canon end
	end
	if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() and C_TradeSkillUI.GetBaseProfessionInfo then
		local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
		if ok and info and info.professionName then
			local canon = CanonicalProf(info.professionName)
			if canon then return canon end
		end
	end
	return nil
end

function PluribusHiveProfessions:GetMyProfessionSet()
	local db = EnsureShoppingDB()
	local me = PluribusHive:GetPlayerShortName()
	local rec = db.guildProfs[me]
	if not rec or not rec.profs or #rec.profs == 0 then
		rec = self:ScanMyProfessions()
	end
	local set = {}
	local count = 0
	for _, p in ipairs((rec and rec.profs) or {}) do
		local canon = CanonicalProf(p.name)
		if canon then
			set[canon] = true
			count = count + 1
		end
	end
	return set, count
end

function PluribusHiveProfessions:GetLearnedRecipeSets(profFilter)
	local catalog = _G.PluribusHiveRecipeCatalog
	local normFn = function(s)
		if catalog and catalog.NormalizeRecipeKey then
			return catalog:NormalizeRecipeKey(s)
		end
		return tostring(s or ""):lower():match("^%s*(.-)%s*$") or ""
	end

	local learnedNames = {}
	local learnedIDs = {}
	local wantProf = (profFilter and profFilter ~= "" and profFilter ~= "ALL" and profFilter ~= "MY_PROFS") and CanonicalProf(profFilter) or nil

	-- 1. Stored recipes scanned for MY character
	local db = EnsureShoppingDB()
	local me = PluribusHive:GetPlayerShortName()
	local myRecs = db.guildRecipes[me] or {}
	for pName, rList in pairs(myRecs) do
		local canon = CanonicalProf(pName)
		if not wantProf or canon == wantProf then
			for _, r in ipairs(rList or {}) do
				local k = normFn(r.name)
				if k ~= "" then learnedNames[k] = true end
				if r.itemID and tonumber(r.itemID) and tonumber(r.itemID) > 0 then
					learnedIDs[tonumber(r.itemID)] = true
				end
			end
		end
	end

	-- 2. Live currently open TradeSkill / Craft / C_TradeSkillUI window (instant updates right after learning a recipe!)
	local openProf = self:GetOpenProfessionName()
	if openProf and (not wantProf or openProf == wantProf) then
		if _G.TradeSkillFrame and _G.TradeSkillFrame:IsShown() and GetNumTradeSkills and GetTradeSkillInfo then
			for i = 1, (GetNumTradeSkills() or 0) do
				local rName, sType = GetTradeSkillInfo(i)
				if rName and sType ~= "header" and sType ~= "subheader" then
					local k = normFn(rName)
					if k ~= "" then learnedNames[k] = true end
					local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
					local id = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if id and id > 0 then learnedIDs[id] = true end
				end
			end
		elseif _G.CraftFrame and _G.CraftFrame:IsShown() and GetNumCrafts and GetCraftInfo then
			for i = 1, (GetNumCrafts() or 0) do
				local cName, _, cType = GetCraftInfo(i)
				if cName and cType ~= "header" then
					local k = normFn(cName)
					if k ~= "" then learnedNames[k] = true end
					local link = GetCraftItemLink and GetCraftItemLink(i)
					local id = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if id and id > 0 then learnedIDs[id] = true end
				end
			end
		elseif C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() and C_TradeSkillUI.GetAllRecipeIDs then
			local okIds, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
			if okIds and type(ids) == "table" then
				for _, rid in ipairs(ids) do
					local okR, rInfo = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
					if okR and rInfo and rInfo.learned and rInfo.name then
						local k = normFn(rInfo.name)
						if k ~= "" then learnedNames[k] = true end
					end
				end
			end
		end
	end

	return learnedNames, learnedIDs
end

function PluribusHiveProfessions:NavigateToRecipeSource(entry)
	if not entry then return false end
	local catalog = _G.PluribusHiveRecipeCatalog
	local dispName = (catalog and catalog:GetDisplayName(entry)) or entry.name or "Recipe"
	local tag = (entry.sourceType == "VENDOR") and L("PROF_SOURCE_VENDOR") or L("PROF_SOURCE_DROP")
	local wpTitle = string.format("[%s] %s (%s)", tag, tostring(entry.sourceName or entry.zone), dispName)

	if _G.PluribusNavigationUI and _G.PluribusNavigationUI.SetWaypoint then
		_G.PluribusNavigationUI:SetWaypoint(wpTitle, entry.zone, entry.x or 50, entry.y or 50)
		return true
	elseif _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.SetRouteTo then
		_G.PluribusHivePathfinder:SetRouteTo(wpTitle, entry.zone, entry.x or 50, entry.y or 50)
		return true
	end
	return false
end

-- 4. Unlearned Recipes Directory (Clearly shows Vendor vs Drop + Click any recipe to navigate!)
function PluribusHiveProfessions:RenderUnlearnedRecipes(container, width, startY, onChanged, forcedProf)
	local UI = _G.PluribusUIFramework
	local catalog = _G.PluribusHiveRecipeCatalog
	local y = startY or -4
	local isCompact = width < 380

	if not catalog then
		local em = UI:CreateLabel(container, "Recipe catalog not loaded.", 0.85, 0.55, 0.55)
		em:SetPoint("TOPLEFT", container, "TOPLEFT", 6, y)
		return y - 30
	end

	local openProf = forcedProf or self:GetOpenProfessionName()
	local myProfSet, myProfCount = self:GetMyProfessionSet()

	-- Default active profession cleanly: open profession in native drawer, else user's own professions or ALL
	local activeProf = forcedProf
	if not activeProf then
		activeProf = self.unlearnedProf or (myProfCount > 0 and "MY_PROFS" or "ALL")
		if activeProf == "MY_PROFS" and myProfCount == 0 then
			activeProf = "ALL"
		end
	end

	-- Row 1: Search Box + Source Filter Buttons (All | Vendor | Drop)
	local sLbl = UI:CreateLabel(container, "|cfffbbf24" .. L("SEARCH") .. "|r", 1, 1, 1)
	sLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 5)

	local sBoxW = isCompact and 104 or 190
	local searchBox = UI:CreateInputBox(container, sBoxW, 24)
	searchBox:SetPoint("LEFT", sLbl, "RIGHT", 6, 0)
	searchBox:SetText(self.unlearnedSearchQuery or "")

	local listHolder = CreateFrame("Frame", nil, container)
	local topOffset = forcedProf and 52 or 84
	listHolder:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y - topOffset)
	listHolder:SetWidth(width)
	listHolder:SetHeight(240)

	local function PopulateUnlearned()
		UI:ClearContainer(listHolder)
		local ly = 0

		local filterProf = (activeProf == "ALL" or activeProf == "MY_PROFS") and nil or activeProf
		local onlyProfs = (activeProf == "MY_PROFS" and myProfCount > 0) and myProfSet or nil
		local learnedNames, learnedIDs = PluribusHiveProfessions:GetLearnedRecipeSets(filterProf)

		local entries = catalog:GetUnlearnedRecipes(filterProf, learnedNames, learnedIDs, {
			sourceFilter = PluribusHiveProfessions.unlearnedSource or "ALL",
			searchQuery = PluribusHiveProfessions.unlearnedSearchQuery or "",
			onlyProfs = onlyProfs,
		})

		if #entries == 0 then
			local card = UI:CreateBannerCard(listHolder, width - 4, 58, "Interface\\Icons\\INV_Scroll_03",
				"|cff4ade80" .. L("PROF_UNLEARNED") .. "|r",
				L("PROF_ALL_LEARNED"),
				0.29, 0.87, 0.50)
			card:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)
			ly = ly - 64
			listHolder:SetHeight(math.max(120, math.abs(ly) + 8))
			container:SetHeight(math.max(300, math.abs(y - topOffset) + math.abs(ly) + 20))
			return
		end

		local lastProf = nil
		for idx, entry in ipairs(entries) do
			if idx > 90 then break end
			if (not forcedProf) and entry.prof ~= lastProf then
				lastProf = entry.prof
				local catBar = UI:CreateCard(listHolder, width - 4, 24)
				catBar:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)
				local pIcon = UI:CreateProfessionIcon(catBar, entry.prof, 18)
				pIcon:SetPoint("LEFT", catBar, "LEFT", 6, 0)
				local pTitle = UI:CreateLabel(catBar, "|cff38bdf8" .. PluribusHiveProfessions:GetProfessionDisplayName(entry.prof) .. "|r", 1, 1, 1, "GameFontNormalSmall")
				pTitle:SetPoint("LEFT", pIcon, "RIGHT", 6, 0)
				ly = ly - 27
			end

			local rowH = isCompact and 48 or 44
			local row = UI:CreateListRow(listHolder, width - 4, rowH, idx, function()
				PluribusHiveProfessions:NavigateToRecipeSource(entry)
			end)
			row:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 2, ly)

			local dispName = catalog:GetDisplayName(entry)
			local slot = UI:CreateItemSlot(row, 30, {
				itemID = (entry.recipeItemID and entry.recipeItemID > 0) and entry.recipeItemID or entry.itemID,
				name = dispName,
				quality = entry.sourceType == "DROP" and 3 or 2,
			})
			slot:SetPoint("LEFT", row, "LEFT", 5, 0)

			local isVendor = (entry.sourceType == "VENDOR")
			local srcBadge
			if isVendor then
				srcBadge = entry.limited
					and ("|cfffbbf24[" .. L("PROF_SOURCE_VENDOR") .. " · " .. L("PROF_SOURCE_LIMITED") .. "]|r")
					or ("|cff4ade80[" .. L("PROF_SOURCE_VENDOR") .. "]|r")
			else
				srcBadge = "|cfff97316[" .. L("PROF_SOURCE_DROP") .. "]|r"
			end
			local skillTxt = entry.skill and string.format(" |cff94a3b8(%d)|r", entry.skill) or ""
			local maxNameLen = isCompact and 16 or 32
			local l1 = UI:CreateLabel(row, string.format("%s |cffffffff%s|r%s", srcBadge, dispName:sub(1, maxNameLen), skillTxt))
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -1)
			l1:SetPoint("RIGHT", row, "RIGHT", isCompact and -54 or -86, 0)
			if l1.SetWordWrap then l1:SetWordWrap(false) end

			local locLine = string.format("%s · |cff38bdf8%s|r (%.0f, %.0f)",
				tostring(entry.sourceName or "?"):sub(1, isCompact and 18 or 30),
				tostring(entry.zone or "Azeroth"),
				entry.x or 50, entry.y or 50)
			if (not isCompact) and entry.note and entry.note ~= "" then
				locLine = locLine .. " · |cff94a3b8" .. tostring(entry.note) .. "|r"
			end
			local l2 = UI:CreateLabel(row, locLine, 0.78, 0.86, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 7, 1)
			l2:SetPoint("RIGHT", row, "RIGHT", isCompact and -54 or -86, 0)
			if l2.SetWordWrap then l2:SetWordWrap(false) end

			local navBtn = UI:CreateButton(row, isCompact and "Nav" or L("TODO_NAV_ROUTE"), isCompact and 44 or 76, 22, function()
				PluribusHiveProfessions:NavigateToRecipeSource(entry)
			end, true)
			navBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

			-- Rich hover tooltip on row showing full recipe source details
			row:SetScript("OnEnter", function(selfRow)
				if selfRow._bg then selfRow._bg:SetColorTexture(0.14, 0.22, 0.34, 0.92) end
				GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
				GameTooltip:SetText("|cffffffff" .. dispName .. "|r")
				GameTooltip:AddLine(string.format("%s · %s", PluribusHiveProfessions:GetProfessionDisplayName(entry.prof), L("PROF_SKILL_REQ", entry.skill or 1)), 0.65, 0.82, 0.96)
				if isVendor then
					GameTooltip:AddLine(L("PROF_SOURCE_VENDOR") .. ": " .. tostring(entry.sourceName), 0.29, 0.87, 0.50)
				else
					GameTooltip:AddLine(L("PROF_SOURCE_DROP") .. ": " .. tostring(entry.sourceName), 0.98, 0.55, 0.16)
				end
				GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", tostring(entry.zone), entry.x or 50, entry.y or 50), 0.22, 0.74, 0.97)
				if entry.note and entry.note ~= "" then
					GameTooltip:AddLine(tostring(entry.note), 0.88, 0.84, 0.62)
				end
				GameTooltip:AddLine(L("PROF_CLICK_TO_NAV"), 0.29, 0.87, 0.50)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function(selfRow)
				if selfRow._bg then
					local alt = (idx % 2 == 0)
					selfRow._bg:SetColorTexture(alt and 0.08 or 0.06, alt and 0.11 or 0.09, alt and 0.17 or 0.14, 0.85)
				end
				GameTooltip:Hide()
			end)

			ly = ly - (rowH + 2)
		end

		listHolder:SetHeight(math.max(180, math.abs(ly) + 10))
		container:SetHeight(math.max(300, math.abs(y - topOffset) + math.abs(ly) + 24))
	end

	local btnAll, btnVendor, btnDrop
	local function SetSource(src)
		PluribusHiveProfessions.unlearnedSource = src
		btnAll:SetActiveState(src == "ALL")
		btnVendor:SetActiveState(src == "VENDOR")
		btnDrop:SetActiveState(src == "DROP")
		PopulateUnlearned()
	end

	btnAll = UI:CreateButton(container, L("PROF_SOURCE_ALL"), isCompact and 38 or 54, 24, function() SetSource("ALL") end)
	btnAll:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	btnAll:SetActiveState((self.unlearnedSource or "ALL") == "ALL")

	btnVendor = UI:CreateButton(container, L("PROF_SOURCE_VENDOR"), isCompact and 54 or 76, 24, function() SetSource("VENDOR") end)
	btnVendor:SetPoint("LEFT", btnAll, "RIGHT", 4, 0)
	btnVendor:SetActiveState(self.unlearnedSource == "VENDOR")

	btnDrop = UI:CreateButton(container, L("PROF_SOURCE_DROP"), isCompact and 44 or 62, 24, function() SetSource("DROP") end)
	btnDrop:SetPoint("LEFT", btnVendor, "RIGHT", 4, 0)
	btnDrop:SetActiveState(self.unlearnedSource == "DROP")

	if not forcedProf then
		-- Row 2: Profession Filter Dropdown + Hint
		local dropOpts = {}
		if myProfCount > 0 then
			table.insert(dropOpts, { key = "MY_PROFS", label = L("PROF_MY_PROFS"), icon = "Interface\\Icons\\Trade_BlackSmithing" })
		end
		table.insert(dropOpts, { key = "ALL", label = L("ALL"), icon = "Interface\\Icons\\INV_Misc_Book_09" })
		for _, pName in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking", "First Aid" }) do
			table.insert(dropOpts, {
				key = pName,
				label = self:GetProfessionDisplayName(pName),
				icon = UI:GetProfessionIcon(pName),
			})
		end

		local dd = UI:CreateFlatDropdown(container, isCompact and 170 or 210, 24, dropOpts, activeProf, function(key)
			PluribusHiveProfessions.unlearnedProf = key
			activeProf = key
			PopulateUnlearned()
		end)
		dd:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 32)

		local hint = UI:CreateLabel(container, "|cff94a3b8" .. L("PROF_UNLEARNED_HINT") .. "|r", 0.72, 0.84, 0.94, "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 62)
		hint:SetWidth(width - 10)
	else
		local hint = UI:CreateLabel(container, "|cff38bdf8" .. self:GetProfessionDisplayName(forcedProf) .. ":|r |cff94a3b8" .. L("PROF_UNLEARNED_HINT") .. "|r", 0.72, 0.84, 0.94, "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 32)
		hint:SetWidth(width - 10)
	end

	searchBox:SetScript("OnTextChanged", function(selfBox)
		PluribusHiveProfessions.unlearnedSearchQuery = selfBox:GetText() or ""
		PopulateUnlearned()
	end)

	PopulateUnlearned()
	return y - topOffset - (listHolder:GetHeight() or 200)
end

-- Populate docked Profession Hive drawer
function PluribusHiveProfessions:RenderDrawerContent(drawer, mode)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local container = drawer.scrollContent
	UI:ClearContainer(container)
	drawer.activeMode = mode

	local titles = {
		profit    = "|cff4ade80" .. L("PROF_CRAFT_PROFITS") .. "|r",
		unlearned = "|cfffbbf24" .. L("PROF_UNLEARNED") .. "|r",
		crafters  = "|cff38bdf8" .. L("PROF_GUILD_RECIPES") .. "|r",
		wishlist  = "|cfffbbf24" .. L("PROF_TODO_LIST") .. "|r",
		surplus   = "|cff4ade80" .. L("PROF_SURPLUS") .. "|r",
	}
	if drawer.titleLbl then
		drawer.titleLbl:SetText(titles[mode] or L("TAB_PROFESSIONS"))
	end

	local y = -4
	local rowW = 304

	if mode == "profit" then
		y = self:RenderCraftProfits(container, rowW, y)
	elseif mode == "unlearned" then
		local openProf = self:GetOpenProfessionName()
		y = self:RenderUnlearnedRecipes(container, rowW, y, function()
			PluribusHiveProfessions:RenderDrawerContent(drawer, "unlearned")
		end, openProf)
	elseif mode == "crafters" then
		y = self:RenderGuildRecipesDirectory(container, rowW, y, function()
			PluribusHiveProfessions:RenderDrawerContent(drawer, "crafters")
		end)
	elseif mode == "wishlist" then
		y = self:RenderWishlistPicker(container, rowW, y, function()
			PluribusHiveProfessions:RenderDrawerContent(drawer, "wishlist")
		end)
	else
		local matches = self:GetMySurplusMatches()
		for idx, m in ipairs(matches) do
			local row = UI:CreateListRow(container, rowW - 4, 38, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 30, {
				itemID = m.itemID, name = m.name, link = m.link, quality = m.quality, count = m.myCount, isSurplus = true,
			})
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)

			local qCol = PluribusUtils:GetQualityColor(m.quality)
			local first = m.neededBy[1]
			local l1 = UI:CreateLabel(row, qCol .. (m.name or ("Item #" .. m.itemID)):sub(1, 18) .. "|r")
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, -1)

			local whoStr = first and string.format("%s (%s)", first.name, first.prof) or "Guild"
			local l2 = UI:CreateLabel(row, whoStr, 0.70, 0.84, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, 1)

			if first and first.name then
				local mailBtn = UI:CreateButton(row, L("PROF_LETTER"), 48, 20, function()
					if _G.PluribusHiveMail then
						_G.PluribusHiveMail:OpenComposer(first.name, "Spare " .. m.name, "Hey! I have x" .. m.myCount .. " " .. m.name .. " spare for your " .. (first.prof or "profession") .. ".", { itemID = m.itemID })
					end
				end)
				mailBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			end
			y = y - 40
		end
		if #matches == 0 then
			local empty = UI:CreateLabel(container, "No surplus mat matches right now.", 0.68, 0.76, 0.86)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -8)
			empty:SetWidth(rowW - 12)
		end
	end

	container:SetHeight(math.max(300, math.abs(y) + 14))
end

function PluribusHiveProfessions:AttachToSkillWindow(hostFrame, key)
	if not hostFrame or hostFrame._plbHiveAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	hostFrame._plbHiveAttached = true

	local UI = _G.PluribusUIFramework
	local drawer = CreateFrame("Frame", "PluribusProfDrawer_" .. tostring(key or "main"), hostFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	drawer:SetSize(340, 420)
	drawer:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", 46, -14)
	drawer:SetFrameStrata(hostFrame:GetFrameStrata() or "HIGH")
	drawer:SetFrameLevel((hostFrame:GetFrameLevel() or 5) + 10)
	drawer._plbDrawer = true
	UI:ApplyBackdrop(drawer, 0.06, 0.08, 0.13, 0.97, 0.22, 0.30, 0.42, 0.95)

	local titleLbl = UI:CreateLabel(drawer, L("TAB_PROFESSIONS"), 0.22, 0.74, 0.97, "GameFontNormal")
	titleLbl:SetPoint("TOPLEFT", drawer, "TOPLEFT", 12, -10)
	drawer.titleLbl = titleLbl

	local closeBtn = UI:CreateButton(drawer, "X", 22, 20, function()
		drawer:Hide()
		for _, t in pairs(hostFrame._plbProfTabs or {}) do t:SetActiveState(false) end
	end)
	closeBtn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -8, -8)

	local scroll = UI:CreateScrollFrame(drawer, "PluribusProfDrawerScroll_" .. tostring(key or "main"), 324, 374)
	scroll:SetPoint("TOPLEFT", drawer, "TOPLEFT", 8, -36)
	drawer.scrollContent = scroll.content
	drawer:Hide()
	hostFrame._plbProfDrawer = drawer

	local tabs = {}
	hostFrame._plbProfTabs = tabs

	local function ToggleDrawerMode(mode)
		if drawer:IsVisible() and drawer.activeMode == mode then
			drawer:Hide()
			for _, t in pairs(tabs) do t:SetActiveState(false) end
			return
		end
		for k, t in pairs(tabs) do t:SetActiveState(k == mode) end
		drawer:Show()
		PluribusHiveProfessions:RenderDrawerContent(drawer, mode)
	end

	local surplusCount = #(self:GetMySurplusMatches() or {})
	local tabSize = 34
	local tabSpacing = 38

	tabs.profit = UI:CreateSideTab(hostFrame, 1, {
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		title = L("PROF_CRAFT_PROFITS"),
		tooltip = L("PROF_PROFIT_COL"),
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -236,
		onClick = function() ToggleDrawerMode("profit") end,
	})

	tabs.unlearned = UI:CreateSideTab(hostFrame, 2, {
		icon = "Interface\\Icons\\INV_Misc_Note_01",
		title = L("PROF_UNLEARNED"),
		tooltip = L("PROF_UNLEARNED_HINT"),
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -274,
		onClick = function() ToggleDrawerMode("unlearned") end,
	})

	tabs.crafters = UI:CreateSideTab(hostFrame, 3, {
		icon = "Interface\\Icons\\Trade_BlackSmithing",
		title = L("PROF_GUILD_RECIPES"),
		tooltip = L("PROF_GUILD_RECIPES"),
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -312,
		onClick = function() ToggleDrawerMode("crafters") end,
	})

	tabs.wishlist = UI:CreateSideTab(hostFrame, 4, {
		icon = "Interface\\Icons\\INV_Scroll_03",
		title = L("PROF_TODO_LIST"),
		tooltip = L("TODO_SUBTITLE"),
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -350,
		onClick = function() ToggleDrawerMode("wishlist") end,
	})

	tabs.surplus = UI:CreateSideTab(hostFrame, 5, {
		icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
		title = L("PROF_SURPLUS"),
		tooltip = L("PROF_SURPLUS"),
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -388,
		onClick = function() ToggleDrawerMode("surplus") end,
	})
	if tabs.surplus then tabs.surplus:SetBadge(surplusCount, 0.12, 0.62, 0.36) end

	local orderedTabs = { tabs.profit, tabs.unlearned, tabs.crafters, tabs.wishlist, tabs.surplus }
	local function RepositionTabs()
		UI:LayoutSideTabs(hostFrame, orderedTabs, {
			preferredY = -198,
			minYOffset = -198,
			spacing = tabSpacing,
			size = tabSize,
			drawer = drawer,
			drawerGap = tabSize + 12,
			drawerYOffset = -14,
		})
	end
	hostFrame._plbRepositionProfTabs = RepositionTabs
	RepositionTabs()

	if hostFrame.HookScript then
		pcall(hostFrame.HookScript, hostFrame, "OnShow", function()
			RepositionTabs()
			if C_Timer and C_Timer.After then
				C_Timer.After(0.05, RepositionTabs)
			end
			if tabs.surplus then
				tabs.surplus:SetBadge(#(PluribusHiveProfessions:GetMySurplusMatches() or {}), 0.12, 0.62, 0.36)
			end
		end)
	end
end

function PluribusHiveProfessions:TryAttachNativeWindows()
	if _G.SkillFrame then self:AttachToSkillWindow(_G.SkillFrame, "skill") end
	if _G.TradeSkillFrame then
		self:AttachToSkillWindow(_G.TradeSkillFrame, "tradeskill")
		self:HookTradeSkillProfitDisplay()
	end
	if _G.CraftFrame then self:AttachToSkillWindow(_G.CraftFrame, "craft") end
	if _G.ProfessionsFrame then self:AttachToSkillWindow(_G.ProfessionsFrame, "professions") end
end

function PluribusHiveProfessions:Initialize()
	if self.initialized then return end
	self.initialized = true
	EnsureShoppingDB()
	self:PruneDuplicateOwners()

	PluribusHive:RegisterHandler("PROF", function(sender, body)
		local normSender = PluribusHive:NormalizeName(sender)
		local cls, profStr, needStr = body:match("^([^|]*)|([^|]*)|(.*)$")
		local profs = {}
		if profStr and profStr ~= "" then
			for pName, curStr, maxStr in profStr:gmatch("([^:,]+):(%d+):(%d+)") do
				table.insert(profs, { name = CanonicalProf(pName), displayName = pName, level = tonumber(curStr) or 0, max = tonumber(maxStr) or 300 })
			end
		end
		local needs = {}
		if needStr and needStr ~= "" then
			for idStr, pName, qtyStr in needStr:gmatch("(%d+):([^:,]*):(%d+)") do
				local id = tonumber(idStr)
				if id then
					needs[id] = { itemID = id, prof = pName, qty = tonumber(qtyStr) or 10 }
				end
			end
		end
		local db = EnsureShoppingDB()
		db.guildProfs[normSender] = {
			name = normSender,
			class = cls ~= "" and cls or "WARRIOR",
			profs = profs,
			needs = needs,
			updatedAt = time(),
		}
	end)

	PluribusHive:RegisterHandler("RECIPES", function(sender, body)
		local normSender = PluribusHive:NormalizeName(sender)
		local cls, profName, listStr = body:match("^([^|]*)|([^|]*)|(.*)$")
		if not profName or profName == "" then return end
		local canon = CanonicalProf(profName)
		local parsed = {}
		for chunk in (listStr or ""):gmatch("([^;]+)") do
			local rName, idStr, rgStr = chunk:match("^([^%^]+)%^(%d+)%^(.*)$")
			if rName and rName ~= "" then
				local reagents = {}
				for rid, rcnt in (rgStr or ""):gmatch("(%d+)%*(%d+)") do
					table.insert(reagents, { tonumber(rid), tonumber(rcnt) or 1 })
				end
				table.insert(parsed, { name = rName, itemID = tonumber(idStr) or 0, numMade = 1, reagents = reagents })
			end
		end
		local db = EnsureShoppingDB()
		db.guildRecipes[normSender] = db.guildRecipes[normSender] or {}
		db.guildRecipes[normSender][canon] = parsed
		if db.guildProfs[normSender] and cls ~= "" then
			db.guildProfs[normSender].class = cls
		end
	end)

	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(4, 10), function()
					PluribusHiveProfessions:BroadcastProfessions()
					PluribusHiveProfessions:BroadcastRecipes()
				end)
			end
		end)
		_G.PluribusMessaging:Subscribe("HIVE_TODO_CHANGED", function()
			if PluribusHiveProfessions.todoPopoutFrame and PluribusHiveProfessions.todoPopoutFrame:IsShown() then
				PluribusHiveProfessions:RefreshTodoPopout()
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "ADDON_LOADED", "BAG_UPDATE_DELAYED" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveProfessions:SanitizeStoredRecipes(false)
			PluribusHiveProfessions:PruneDuplicateOwners()
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
			if C_Timer and C_Timer.After then
				C_Timer.After(9, function()
					PluribusHiveProfessions:BroadcastProfessions()
					PluribusHiveProfessions:BroadcastRecipes()
				end)
			end
		elseif event == "BAG_UPDATE_DELAYED" then
			if PluribusHiveProfessions.todoPopoutFrame and PluribusHiveProfessions.todoPopoutFrame:IsShown() then
				PluribusHiveProfessions:RefreshTodoPopout()
			end
		elseif event == "SKILL_LINES_CHANGED" then
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:BroadcastProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
		elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
			PluribusHiveProfessions:TryAttachNativeWindows()
			PluribusHiveProfessions:ScheduleTradeSkillScan(0.25)
			PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
			for _, host in ipairs({ _G.TradeSkillFrame, _G.CraftFrame, _G.ProfessionsFrame }) do
				if host and host:IsShown() and host._plbProfDrawer and host._plbProfDrawer:IsShown() and host._plbProfDrawer.activeMode == "unlearned" then
					PluribusHiveProfessions:RenderDrawerContent(host._plbProfDrawer, "unlearned")
				end
			end
		elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
			PluribusHiveProfessions:ScheduleTradeSkillScan(0.25)
			PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_CraftUI" or arg1 == "Blizzard_Professions") then
			PluribusHiveProfessions:TryAttachNativeWindows()
		end
	end)
end

-- ============================================================================
-- FLOATING TO-DO & SHOPPING LIST POPOUT WINDOW
-- ============================================================================
function PluribusHiveProfessions:EnsureTodoPopout()
	if self.todoPopoutFrame then return self.todoPopoutFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local W, H = 370, 420
	local f = UI:CreateFrame("PluribusTodoPopoutFrame", UIParent, W, H, "To-Do & Einkaufsliste", "Live Popout")
	f:SetPoint("RIGHT", UIParent, "RIGHT", -32, 40)
	f:SetClampedToScreen(true)
	f:SetFrameStrata("HIGH")
	f._expandedHeight = H
	f._collapsed = false

	-- Header buttons: Collapse [-] and Hub [Hub] (placed left of the default close X button)
	if f.header then
		local collapseBtn = UI:CreateButton(f.header, "-", 22, 20, function()
			f._collapsed = not f._collapsed
			if f._collapsed then
				f.bodyWrap:Hide()
				f:SetHeight(42)
				collapseBtn:SetText("+")
			else
				f:SetHeight(f._expandedHeight)
				f.bodyWrap:Show()
				collapseBtn:SetText("-")
				PluribusHiveProfessions:RefreshTodoPopout()
			end
		end)
		collapseBtn:SetPoint("RIGHT", f.header, "RIGHT", -34, 0)
		f.collapseBtn = collapseBtn

		local hubBtn = UI:CreateButton(f.header, "Hub", 44, 20, function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame.profSubTab = "wishlist"
				_G.PluribusMainFrame:OpenToTab("Professions")
			end
		end)
		hubBtn:SetPoint("RIGHT", collapseBtn, "LEFT", -4, 0)
		f.hubBtn = hubBtn

		local routeBtn = UI:CreateButton(f.header, "+ Route", 56, 20, function()
			if _G.PluribusHiveDynamicRoute and _G.PluribusHiveDynamicRoute.EnableSources then
				_G.PluribusHiveDynamicRoute:EnableSources(nil, true, true)
			end
		end, true)
		routeBtn:SetPoint("RIGHT", hubBtn, "LEFT", -4, 0)
		f.routeBtn = routeBtn
	end

	-- Body wrapper so collapsing cleanly hides everything below the header
	local bodyWrap = CreateFrame("Frame", nil, f)
	bodyWrap:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
	bodyWrap:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f.bodyWrap = bodyWrap

	-- Top summary & drag-drop quick-add bar
	local topBar = CreateFrame("Frame", nil, bodyWrap, BackdropTemplateMixin and "BackdropTemplate" or nil)
	topBar:SetSize(W - 16, 30)
	topBar:SetPoint("TOPLEFT", bodyWrap, "TOPLEFT", 8, -4)
	UI:ApplyBackdrop(topBar, 0.07, 0.10, 0.16, 0.92, 0.20, 0.30, 0.45, 0.70)

	local summaryLbl = UI:CreateLabel(topBar, "0/0 erledigt", 0.85, 0.92, 1.0, "GameFontHighlightSmall")
	summaryLbl:SetPoint("LEFT", topBar, "LEFT", 8, 0)
	f.summaryLbl = summaryLbl

	local dropBtn = UI:CreateButton(topBar, "+ Item ablegen", 96, 20, function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveProfessions:AddNeededMaterial(itemID, PluribusHiveProfessions.selectedPickerQty or 10)
				if ClearCursor then pcall(ClearCursor) end
				PluribusHiveProfessions:RefreshTodoPopout()
			else
				UI:ShowNotification("|cff38bdf8Ziehe ein Item aus dem Rucksack auf diesen Button, um es zur To-Do Liste hinzuzufügen.|r", 3)
			end
		end
	end)
	dropBtn:SetPoint("RIGHT", topBar, "RIGHT", -5, 0)
	dropBtn:SetScript("OnReceiveDrag", function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveProfessions:AddNeededMaterial(itemID, PluribusHiveProfessions.selectedPickerQty or 10)
				if ClearCursor then pcall(ClearCursor) end
				PluribusHiveProfessions:RefreshTodoPopout()
			end
		end
	end)
	summaryLbl:SetPoint("RIGHT", dropBtn, "LEFT", -6, 0)
	if summaryLbl.SetWordWrap then summaryLbl:SetWordWrap(false) end

	-- Scroll list for active To-Do items
	local scroll = UI:CreateScrollFrame(bodyWrap, "PluribusTodoPopoutScroll", W - 16, H - 86)
	scroll:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -6)
	f.scroll = scroll

	f:Hide()
	self.todoPopoutFrame = f
	return f
end

function PluribusHiveProfessions:RefreshTodoPopout()
	local f = self.todoPopoutFrame
	if not f or not f:IsShown() or f._collapsed then return end
	local UI = _G.PluribusUIFramework
	if not UI then return end

	local c = f.scroll.content
	UI:ClearContainer(c)

	local db = EnsureShoppingDB()
	local matMap = self:GetAggregatedShoppingMaterials()
	local matList = {}
	for _, m in pairs(matMap) do table.insert(matList, m) end
	table.sort(matList, function(a, b)
		local aDone = (self:GetOwnedCount(a.itemID) >= (a.qty or 1))
		local bDone = (self:GetOwnedCount(b.itemID) >= (b.qty or 1))
		if aDone ~= bDone then return not aDone end
		return a.itemID < b.itemID
	end)

	local doneCount = 0
	local totalAhCopper = 0
	for _, m in ipairs(matList) do
		local owned = self:GetOwnedCount(m.itemID)
		local rem = math.max(0, (m.qty or 1) - owned)
		if rem <= 0 then
			doneCount = doneCount + 1
		elseif self:GetItemTodoMode(m.itemID) == "BUY" then
			local ahInfo = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(m.itemID)
			if ahInfo and ahInfo.copper and ahInfo.copper > 0 then
				totalAhCopper = totalAhCopper + (ahInfo.copper * rem)
			end
		end
	end

	local sumTxt = string.format("|cff4ade80%d/%d erledigt|r", doneCount, #matList)
	if totalAhCopper > 0 then
		sumTxt = sumTxt .. "  ·  |cfffbbf24AH: " .. PluribusUtils:FormatGold(totalAhCopper) .. "|r"
	end
	f.summaryLbl:SetText(sumTxt)

	local rowW = 326
	local y = -2

	if #matList == 0 then
		local em = UI:CreateLabel(c, L("TODO_EMPTY"), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
		em:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -8)
		em:SetWidth(rowW - 12)
		c:SetHeight(120)
		return
	end

	for idx, m in ipairs(matList) do
		local name, link, quality = PluribusUtils:GetItemInfo(m.itemID)
		local displayName = name or ("Item #" .. m.itemID)
		local owned = self:GetOwnedCount(m.itemID)
		local qty = m.qty or 1
		local rem = math.max(0, qty - owned)
		local isDone = (rem <= 0)
		local mode = self:GetItemTodoMode(m.itemID)

		local row = UI:CreateListRow(c, rowW, 46, idx)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

		local slot = UI:CreateItemSlot(row, 26, { itemID = m.itemID, name = displayName, link = link, quality = quality or 1, count = qty })
		slot:SetPoint("LEFT", row, "LEFT", 5, 0)

		local qCol = isDone and "|cff4ade80" or PluribusUtils:GetQualityColor(quality or 1)
		local countCol = isDone and "|cff4ade80" or "|cfffbbf24"
		local prefix = isDone and "[OK] " or ""
		local titleLbl = UI:CreateLabel(row, string.format("%s%s%s|r", qCol, prefix, displayName:sub(1, 20)), 1, 1, 1, "GameFontHighlightSmall")
		titleLbl:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, 3)

		local countLbl = UI:CreateLabel(row, string.format("%s%d/%d|r", countCol, owned, qty), 1, 1, 1, "GameFontHighlightSmall")
		countLbl:SetPoint("LEFT", titleLbl, "RIGHT", 5, 0)

		-- Right buttons: [X] (if direct), [Action: AH/Nav], [Mode toggle]
		local rightAnchor = row
		if m.direct then
			local rmBtn = UI:CreateButton(row, "X", 20, 20, function()
				PluribusHiveProfessions:RemoveNeededMaterial(m.itemID)
				PluribusHiveProfessions:RefreshTodoPopout()
			end)
			rmBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
			rightAnchor = rmBtn
		end

		if mode == "BUY" then
			local ahBtn = UI:CreateButton(row, "AH", 34, 20, function()
				if _G.PluribusHiveAuction and _G.PluribusHiveAuction.ahOpen and _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.OpenShoppingForItem then
					_G.PluribusHiveAuctionator:OpenShoppingForItem(displayName)
				elseif _G.PluribusHiveAuction and _G.PluribusHiveAuction.SearchNativeAH then
					_G.PluribusHiveAuction:SearchNativeAH(displayName)
				end
			end, true)
			if rightAnchor == row then
				ahBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
			else
				ahBtn:SetPoint("RIGHT", rightAnchor, "LEFT", -3, 0)
			end
			rightAnchor = ahBtn

			local ahInfo = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(m.itemID)
			local subTxt
			if ahInfo and ahInfo.copper and ahInfo.copper > 0 then
				subTxt = "|cfffbbf24AH:|r " .. PluribusUtils:FormatGold(ahInfo.copper) .. "/ea"
			else
				subTxt = "|cff94a3b8Modus: Kaufen (AH)|r"
			end
			local subLbl = UI:CreateLabel(row, subTxt, 0.78, 0.86, 0.94, "GameFontHighlightSmall")
			subLbl:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, -3)
		else
			local route = _G.PluribusHiveCompute and _G.PluribusHiveCompute.GetFarmRouteForItem
				and _G.PluribusHiveCompute:GetFarmRouteForItem(m.itemID, displayName)
			local navBtn = UI:CreateButton(row, "Nav", 36, 20, function()
				if route and _G.PluribusNavigationUI then
					_G.PluribusNavigationUI:SetWaypoint("Farm: " .. displayName, route.zone, route.x or 50, route.y or 50)
				end
			end, true)
			if rightAnchor == row then
				navBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
			else
				navBtn:SetPoint("RIGHT", rightAnchor, "LEFT", -3, 0)
			end
			rightAnchor = navBtn

			local zoneTxt = route and ("|cff4ade80" .. tostring(route.zone) .. string.format(" (%.0f, %.0f)|r", route.x or 50, route.y or 50)) or "|cff4ade80Farm-Modus|r"
			local subLbl = UI:CreateLabel(row, zoneTxt, 0.72, 0.96, 0.80, "GameFontHighlightSmall")
			subLbl:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, -3)
		end

		local modeSwitch = UI:CreateButton(row, mode == "BUY" and "Farm" or "AH", 38, 18, function()
			PluribusHiveProfessions:SetItemTodoMode(m.itemID, mode == "BUY" and "FARM" or "BUY")
			PluribusHiveProfessions:RefreshTodoPopout()
		end)
		modeSwitch:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 3)

		y = y - 49
	end

	-- Also show queued recipes compactly at the bottom
	local recipeList = {}
	for _, r in pairs(db.myShoppingRecipes or {}) do table.insert(recipeList, r) end
	if #recipeList > 0 then
		y = y - 4
		table.sort(recipeList, function(a, b) return (a.name or "") < (b.name or "") end)
		local rHdr = UI:CreateLabel(c, "|cfffbbf24Rezepte (" .. #recipeList .. "):|r", 1, 1, 1, "GameFontNormalSmall")
		rHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		y = y - 16
		for idx, r in ipairs(recipeList) do
			local rRow = UI:CreateListRow(c, rowW, 28, idx)
			rRow:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)
			local rLbl = UI:CreateLabel(rRow, string.format("|cffffffff%s|r |cff4ade80x%d|r", (r.name or ""):sub(1, 28), r.count or 1), 1, 1, 1, "GameFontHighlightSmall")
			rLbl:SetPoint("LEFT", rRow, "LEFT", 8, 0)
			local rRm = UI:CreateButton(rRow, "X", 20, 18, function()
				PluribusHiveProfessions:RemoveRecipeFromShoppingList(r.key)
				PluribusHiveProfessions:RefreshTodoPopout()
			end)
			rRm:SetPoint("RIGHT", rRow, "RIGHT", -4, 0)
			y = y - 30
		end
	end

	c:SetHeight(math.max(260, math.abs(y) + 10))
end

function PluribusHiveProfessions:OpenTodoPopout()
	local f = self:EnsureTodoPopout()
	if not f then return end
	f:Show()
	if _G.PluribusUIFramework then _G.PluribusUIFramework:BringToFront(f) end
	self:RefreshTodoPopout()
end

function PluribusHiveProfessions:CloseTodoPopout()
	if self.todoPopoutFrame then
		self.todoPopoutFrame:Hide()
	end
end

function PluribusHiveProfessions:ToggleTodoPopout()
	local f = self:EnsureTodoPopout()
	if not f then return end
	if f:IsShown() then
		f:Hide()
	else
		self:OpenTodoPopout()
	end
end

return PluribusHiveProfessions
