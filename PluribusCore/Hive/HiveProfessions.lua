-- PluribusHive Professions, Craft Profits, Guild Recipe Directory & Shopping List
-- 1. Inline AH Craft Profit (Sell - Mats) on WoW's native Professions list & detail pane
-- 2. Profession-categorized Guild Recipe Directory (all professions & recipes, Whisper + In-Addon Mail/Letter + Add to Shopping List)
-- 3. Dropdown-driven Shopping List supporting BOTH Recipes (with auto-rolled-up reagents) AND individual Items/Materials
-- 4. Surplus Materials Guild Matcher + zero-overlap right-edge side tabs

PluribusHiveProfessions = {
	initialized = false,
	skillTabsAttached = false,
	tradeHooksInstalled = false,
	selectedCrafterProf = "ALL",
	selectedPickerCat = "RECIPES",
	selectedPickerQty = 10,
}
_G.PluribusHiveProfessions = PluribusHiveProfessions

local KNOWN_PROFESSIONS = {
	["Alchemy"] = true, ["Alchemie"] = true,
	["Blacksmithing"] = true, ["Schmiedekunst"] = true,
	["Enchanting"] = true, ["Verzauberkunst"] = true,
	["Engineering"] = true, ["Ingenieurskunst"] = true,
	["Herbalism"] = true, ["Kräuterkunde"] = true,
	["Leatherworking"] = true, ["Lederverarbeitung"] = true,
	["Mining"] = true, ["Bergbau"] = true,
	["Skinning"] = true, ["Kürschnerei"] = true,
	["Tailoring"] = true, ["Schneiderei"] = true,
	["Cooking"] = true, ["Kochkunst"] = true,
	["First Aid"] = true, ["Erste Hilfe"] = true,
	["Fishing"] = true, ["Angeln"] = true,
	["Jewelcrafting"] = true, ["Juwelenschleifen"] = true,
}

local PROF_CANONICAL = {
	["Alchemie"] = "Alchemy",
	["Schmiedekunst"] = "Blacksmithing",
	["Verzauberkunst"] = "Enchanting",
	["Ingenieurskunst"] = "Engineering",
	["Kräuterkunde"] = "Herbalism",
	["Lederverarbeitung"] = "Leatherworking",
	["Bergbau"] = "Mining",
	["Kürschnerei"] = "Skinning",
	["Schneiderei"] = "Tailoring",
	["Kochkunst"] = "Cooking",
	["Erste Hilfe"] = "First Aid",
	["Angeln"] = "Fishing",
	["Juwelenschleifen"] = "Jewelcrafting",
}

PluribusHiveProfessions.CRAFTING_PROFS = {
	"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
	"Leatherworking", "Tailoring", "Cooking", "First Aid", "Jewelcrafting",
}

-- Leveling material brackets by profession & skill range
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

-- Iconic Classic / Warcraft Forever baseline recipe catalog (automatically enriched with real guild-synced recipes!)
PluribusHiveProfessions.CATALOG_RECIPES = {
	Alchemy = {
		{ name = "Flask of the Titans", itemID = 13510, reagents = { { 13467, 1 }, { 13463, 30 }, { 13422, 10 }, { 8925, 1 } } },
		{ name = "Flask of Supreme Power", itemID = 13512, reagents = { { 13467, 1 }, { 13463, 30 }, { 13465, 10 }, { 8925, 1 } } },
		{ name = "Flask of Distilled Wisdom", itemID = 13511, reagents = { { 13467, 1 }, { 13463, 30 }, { 13467, 1 }, { 8925, 1 } } },
		{ name = "Elixir of the Mongoose", itemID = 13452, reagents = { { 13465, 2 }, { 13466, 2 }, { 8925, 1 } } },
		{ name = "Greater Arcane Elixir", itemID = 13454, reagents = { { 13463, 3 }, { 13465, 1 }, { 8925, 1 } } },
		{ name = "Major Mana Potion", itemID = 13444, reagents = { { 13463, 3 }, { 13467, 2 }, { 8925, 1 } } },
		{ name = "Major Healing Potion", itemID = 13446, reagents = { { 13464, 2 }, { 13465, 1 }, { 8925, 1 } } },
		{ name = "Transmute: Arcanite", itemID = 12360, reagents = { { 12359, 1 }, { 12363, 1 } } },
	},
	Blacksmithing = {
		{ name = "Lionheart Helm", itemID = 12640, reagents = { { 12359, 80 }, { 12360, 12 }, { 12800, 4 }, { 12799, 10 } } },
		{ name = "Titanic Leggings", itemID = 22385, reagents = { { 12360, 12 }, { 12359, 20 }, { 7076, 10 } } },
		{ name = "Elemental Sharpening Stone", itemID = 18262, reagents = { { 7067, 2 }, { 12365, 3 } } },
		{ name = "Arcanite Reaper", itemID = 12784, reagents = { { 12360, 20 }, { 12810, 6 }, { 12365, 2 } } },
	},
	Enchanting = {
		{ name = "Enchant Weapon - Crusader", itemID = 16252, reagents = { { 14344, 4 }, { 12811, 2 } } },
		{ name = "Enchant Weapon - Spell Power", itemID = 18259, reagents = { { 14344, 4 }, { 16203, 12 }, { 7078, 4 } } },
		{ name = "Enchant Chest - Greater Stats", itemID = 16253, reagents = { { 14344, 4 }, { 16204, 15 }, { 16203, 10 } } },
		{ name = "Enchant Gloves - Threat", itemID = 20726, reagents = { { 20725, 4 }, { 14344, 6 }, { 12655, 8 } } },
	},
	Engineering = {
		{ name = "Goblin Sapper Charge", itemID = 10646, reagents = { { 4306, 1 }, { 10561, 3 }, { 10559, 1 } } },
		{ name = "Dense Dynamite", itemID = 18641, reagents = { { 15992, 2 }, { 14047, 3 } } },
		{ name = "Field Repair Bot 74A", itemID = 18232, reagents = { { 12359, 12 }, { 7078, 2 }, { 7076, 2 } } },
		{ name = "Arcanite Dragonling", itemID = 16022, reagents = { { 12360, 10 }, { 15994, 6 }, { 12810, 8 } } },
	},
	Leatherworking = {
		{ name = "Hide of the Wild", itemID = 18510, reagents = { { 8170, 30 }, { 12803, 12 }, { 7080, 10 }, { 15407, 8 } } },
		{ name = "Devilsaur Gauntlets", itemID = 15063, reagents = { { 8170, 30 }, { 15417, 8 }, { 14341, 4 } } },
		{ name = "Devilsaur Leggings", itemID = 15062, reagents = { { 8170, 30 }, { 15417, 14 }, { 14341, 4 } } },
		{ name = "Onyxia Scale Cloak", itemID = 15138, reagents = { { 15410, 1 }, { 15407, 1 }, { 14341, 1 } } },
	},
	Tailoring = {
		{ name = "Robe of the Archmage", itemID = 14152, reagents = { { 14048, 12 }, { 7078, 10 }, { 7082, 10 }, { 7080, 10 } } },
		{ name = "Mooncloth Bag", itemID = 14155, reagents = { { 14048, 4 }, { 14342, 1 }, { 14341, 1 } } },
		{ name = "Bloodvine Vest", itemID = 19682, reagents = { { 19726, 4 }, { 14342, 3 }, { 14048, 4 } } },
		{ name = "Truefaith Vestments", itemID = 14154, reagents = { { 14048, 12 }, { 14342, 10 }, { 12803, 4 } } },
	},
	Cooking = {
		{ name = "Smoked Desert Dumplings", itemID = 20452, reagents = { { 20424, 1 }, { 3713, 1 } } },
		{ name = "Blessed Sunfruit", itemID = 13810, reagents = { { 13810, 1 } } },
		{ name = "Nightfin Soup", itemID = 13931, reagents = { { 13759, 1 }, { 159, 1 } } },
		{ name = "Grilled Squid", itemID = 13928, reagents = { { 13755, 1 }, { 3713, 1 } } },
	},
	["First Aid"] = {
		{ name = "Heavy Runecloth Bandage", itemID = 14530, reagents = { { 14047, 2 } } },
		{ name = "Heavy Mageweave Bandage", itemID = 8545, reagents = { { 4338, 2 } } },
	},
	Jewelcrafting = {
		{ name = "Heavy Golden Necklace", itemID = 21758, reagents = { { 3577, 2 }, { 3864, 1 } } },
	},
}

local function CanonicalProf(name)
	return PROF_CANONICAL[name] or name
end

local function EnsureShoppingDB()
	local db = PluribusHive:GetDB()
	db.myNeededMats = db.myNeededMats or {}
	db.myShoppingRecipes = db.myShoppingRecipes or {}
	db.guildRecipes = db.guildRecipes or {}
	return db
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

-- Calculate live craft profit for an open TradeSkill row: AH(item) * numMade - sum(AH(mat) * count)
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
		local pInfo = (ah and rID) and ah:GetPrice(rID) or nil
		local unitCopper = pInfo and pInfo.copper or nil
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
		profit = sellTotal - matCost
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

-- Calculate profit for any catalog/guild recipe table ({ itemID, reagents = { {id, count}, ... } })
function PluribusHiveProfessions:CalculateStoredRecipeProfit(recipe)
	if not recipe then return nil, nil, nil end
	local ah = _G.PluribusHiveAuction
	local sellInfo = (ah and recipe.itemID and recipe.itemID > 0) and ah:GetPrice(recipe.itemID) or nil
	local sell = sellInfo and sellInfo.copper or nil
	local matCost = 0
	local pricedMats = 0
	for _, rg in ipairs(recipe.reagents or {}) do
		local rid = rg[1] or rg.itemID
		local cnt = rg[2] or rg.count or 1
		local pInfo = (ah and rid) and ah:GetPrice(rid) or nil
		if pInfo and pInfo.copper then
			matCost = matCost + pInfo.copper * cnt
			pricedMats = pricedMats + 1
		end
	end
	if sell ~= nil and (#(recipe.reagents or {}) == 0 or pricedMats > 0) then
		return sell - matCost, sell, matCost
	end
	return nil, sell, matCost > 0 and matCost or nil
end

-- Return all open-profession recipes sorted by highest net AH profit first
function PluribusHiveProfessions:GetOpenProfessionProfits()
	local out = {}
	if not GetNumTradeSkills or not GetTradeSkillInfo then return out end
	local total = GetNumTradeSkills() or 0
	for i = 1, total do
		local info = self:CalculateRecipeProfit(i)
		if info then
			table.insert(out, info)
		end
	end
	table.sort(out, function(a, b)
		if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
		if a.profit and b.profit and a.profit ~= b.profit then return a.profit > b.profit end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

-- Inline profit text column inside WoW's native TradeSkillFrame list + Detail Profit bar + "+ Shopping List" button
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

	-- Selected recipe detail profit bar + 1-click "+ Shopping List" button
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

			local addShopBtn = UI:CreateButton(bar, "+ Shop", 58, 20, function()
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
				local profTxt = selInfo.profit ~= nil and self:FormatSignedGold(selInfo.profit) or "|cff94a3b8Scan AH|r"
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
		local p1, p2, arch, fish, cook, firstAid = GetProfessions()
		for _, idx in ipairs({ p1, p2, arch, fish, cook, firstAid }) do
			if idx then
				local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(idx)
				if name and not added[name] then
					local canon = CanonicalProf(name)
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
				if not added[canon] then
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

	-- Merge explicit items AND rolled-up recipe shopping list materials into guild-visible needs
	local db = EnsureShoppingDB()
	local combinedShop = self:GetAggregatedShoppingMaterials()
	for itemID, entry in pairs(combinedShop) do
		if type(itemID) == "number" and entry.qty > 0 then
			needs[itemID] = needs[itemID] or { itemID = itemID, prof = "Shopping List", level = 0, max = 0, qty = entry.qty }
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

-- Scan currently open TradeSkill window for BOTH skill-up reagents AND ALL known recipes (shared with guild!)
function PluribusHiveProfessions:ScanOpenTradeSkill()
	if not GetNumTradeSkills or not GetTradeSkillInfo or not GetTradeSkillNumReagents then return end
	local me = PluribusHive:GetPlayerShortName()
	local db = EnsureShoppingDB()
	local rec = db.guildProfs[me] or self:ScanMyProfessions()
	local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"

	db.guildRecipes[me] = db.guildRecipes[me] or {}
	local profRecipes = {}

	for i = 1, GetNumTradeSkills() do
		local rName, skillType = GetTradeSkillInfo(i)
		if rName and skillType ~= "header" and skillType ~= "subheader" then
			local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
			local craftedID = itemLink and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(itemLink) or 0
			local numReagents = GetTradeSkillNumReagents(i) or 0
			local reagents = {}

			for r = 1, numReagents do
				local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
				local _, _, reqCount = GetTradeSkillReagentInfo(i, r)
				local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
				if itemID and itemID > 0 then
					table.insert(reagents, { itemID, tonumber(reqCount) or 1 })
					if skillType == "optimal" or skillType == "medium" then
						rec.needs[itemID] = {
							itemID = itemID,
							prof = activeProf,
							level = 0,
							max = 300,
							qty = math.max((rec.needs[itemID] and rec.needs[itemID].qty) or 0, (reqCount or 1) * 5),
						}
					end
				end
			end

			table.insert(profRecipes, {
				name = rName,
				itemID = craftedID,
				reagents = reagents,
			})
		end
	end

	db.guildRecipes[me][activeProf] = profRecipes
	rec.updatedAt = time()
	self:BroadcastProfessions()
	self:BroadcastRecipes(activeProf)
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

-- Gently broadcast known recipes in the background (LZ-compressed & trickled bit by bit!)
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
-- PROFESSION-CATEGORIZED GUILD RECIPE DIRECTORY (NEVER SORTED BY PEOPLE!)
-- Returns { [profName] = { prof = profName, crafterCount = N, recipes = { { name, itemID, prof, reagents, crafters = { {name, class, level}, ... } } } } }
-- ============================================================================
function PluribusHiveProfessions:GetProfessionDirectory()
	local db = EnsureShoppingDB()
	local byProf = {}

	local function EnsureProf(pName)
		if not byProf[pName] then
			byProf[pName] = { prof = pName, recipeMap = {}, craftersSet = {} }
		end
		return byProf[pName]
	end

	-- 1. Seed all crafting professions and baseline recipes so every profession category is always visible
	for _, pName in ipairs(self.CRAFTING_PROFS) do
		local bucket = EnsureProf(pName)
		for _, catRec in ipairs(self.CATALOG_RECIPES[pName] or {}) do
			local rKey = catRec.name:lower()
			bucket.recipeMap[rKey] = {
				name = catRec.name,
				prof = pName,
				itemID = catRec.itemID or 0,
				reagents = catRec.reagents or {},
				crafters = {},
				isCatalog = true,
			}
		end
	end

	-- Build quick player skill lookup from db.guildProfs
	local playerProfMeta = {}
	for memberName, pRec in pairs(db.guildProfs or {}) do
		local norm = PluribusHive:NormalizeName(memberName)
		playerProfMeta[norm] = { class = pRec.class or "WARRIOR", levels = {} }
		for _, pr in ipairs(pRec.profs or {}) do
			local canon = CanonicalProf(pr.name)
			playerProfMeta[norm].levels[canon] = pr.level or 0
			local bucket = EnsureProf(canon)
			bucket.craftersSet[norm] = { name = norm, class = pRec.class or "WARRIOR", level = pr.level or 0, max = pr.max or 300 }
		end
	end

	-- 2. Merge all guild-synced real recipes into profession categories
	for memberName, profTable in pairs(db.guildRecipes or {}) do
		local norm = PluribusHive:NormalizeName(memberName)
		local pMeta = playerProfMeta[norm] or { class = "WARRIOR", levels = {} }
		for profName, rList in pairs(profTable or {}) do
			local canon = CanonicalProf(profName)
			local bucket = EnsureProf(canon)
			for _, r in ipairs(rList or {}) do
				if r.name and r.name ~= "" then
					local rKey = r.name:lower()
					local entry = bucket.recipeMap[rKey]
					if not entry then
						entry = {
							name = r.name,
							prof = canon,
							itemID = tonumber(r.itemID) or 0,
							reagents = r.reagents or {},
							crafters = {},
							isCatalog = false,
						}
						bucket.recipeMap[rKey] = entry
					else
						if (entry.itemID == 0) and (tonumber(r.itemID) or 0) > 0 then
							entry.itemID = tonumber(r.itemID)
						end
						if #(r.reagents or {}) > 0 then
							entry.reagents = r.reagents
						end
					end
					-- Add crafter without duplicates
					local already = false
					for _, c in ipairs(entry.crafters) do
						if PluribusHive:SamePlayer(c.name, norm) then already = true break end
					end
					if not already then
						table.insert(entry.crafters, {
							name = norm,
							class = pMeta.class,
							level = pMeta.levels[canon] or 300,
						})
					end
				end
			end
		end
	end

	-- Finalize sorted arrays per profession (recipes with guild crafters first, then alphabetical)
	local orderedCategories = {}
	for _, pName in ipairs(self.CRAFTING_PROFS) do
		local b = byProf[pName]
		if b then
			local recipes = {}
			for _, rec in pairs(b.recipeMap) do
				table.sort(rec.crafters, function(a, c2) return a.name < c2.name end)
				table.insert(recipes, rec)
			end
			table.sort(recipes, function(a, c2)
				if (#a.crafters > 0) ~= (#c2.crafters > 0) then return #a.crafters > 0 end
				return a.name < c2.name
			end)
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
	return orderedCategories
end

-- ============================================================================
-- SHOPPING LIST (RECIPES + ITEMS/MATERIALS)
-- ============================================================================
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
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff4ade80Added recipe to Shopping List:|r " .. recipe.name .. " (x" .. count .. ")", 3)
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

-- Roll up all explicitly added items PLUS reagents required by all saved recipes in Shopping List
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

-- Dropdown categories for the Shopping List Picker (no raw input box!)
function PluribusHiveProfessions:GetPickerCategories()
	local UI = _G.PluribusUIFramework
	return {
		{ key = "RECIPES",       label = "Recipes (Add Craft + Mats)", icon = "Interface\\Icons\\INV_Scroll_03" },
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
-- SURPLUS MATCHING (UNCHANGED CORE LOGIC, CLEANLY EXPOSED)
-- ============================================================================
function PluribusHiveProfessions:DoINeedItem(itemID)
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local mine = db.guildProfs[me]
	return mine and mine.needs and mine.needs[itemID] ~= nil or false
end

function PluribusHiveProfessions:GetGuildNeedsForItem(itemID)
	if not itemID then return {}, false end
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local iNeedIt = self:DoINeedItem(itemID)
	local neededBy = {}

	for memberName, rec in pairs(db.guildProfs or {}) do
		if not PluribusHive:SamePlayer(memberName, me) and rec.needs and rec.needs[itemID] then
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
				name = memberName,
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
-- REUSABLE GRAPHICAL RENDERERS (Shared cleanly by MainFrame & TradeSkill Drawer — zero duplicate code!)
-- ============================================================================

-- 1. Profession-Categorized Guild Recipes Directory (All Professions -> All Recipes -> Whisper / Write Letter / +Shop)
function PluribusHiveProfessions:RenderGuildRecipesDirectory(container, width, startY, onChanged)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local categories = self:GetProfessionDirectory()

	-- Build dropdown options with real WoW Profession Icons
	local dropOpts = { { key = "ALL", label = "All Professions (" .. #categories .. ")", icon = "Interface\\Icons\\INV_Misc_Book_09" } }
	for _, cat in ipairs(categories) do
		table.insert(dropOpts, {
			key = cat.prof,
			label = string.format("%s (%d recipes · %d crafters)", cat.prof, #cat.recipes, #cat.crafters),
			icon = UI:GetProfessionIcon(cat.prof),
		})
	end

	local filterLbl = UI:CreateLabel(container, "|cfffbbf24Profession:|r", 1, 1, 1)
	filterLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 5)

	local ddW = math.min(260, width - 86)
	local dd = UI:CreateFlatDropdown(container, ddW, 24, dropOpts, self.selectedCrafterProf or "ALL", function(key)
		PluribusHiveProfessions.selectedCrafterProf = key
		if onChanged then onChanged() end
	end)
	dd:SetPoint("LEFT", filterLbl, "RIGHT", 6, 0)
	y = y - 34

	local isCompact = width < 360
	for _, cat in ipairs(categories) do
		if self.selectedCrafterProf == "ALL" or self.selectedCrafterProf == cat.prof then
			-- Graphical Profession Category Header Bar
			local catBar = UI:CreateCard(container, width - 4, 28)
			catBar:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
			local pIcon = UI:CreateProfessionIcon(catBar, cat.prof, 20)
			pIcon:SetPoint("LEFT", catBar, "LEFT", 6, 0)
			local pTitle = UI:CreateLabel(catBar, string.format("|cff38bdf8%s|r  |cff94a3b8(%d recipes · %d guild crafters)|r", cat.prof, #cat.recipes, #cat.crafters), 1, 1, 1, "GameFontNormal")
			pTitle:SetPoint("LEFT", pIcon, "RIGHT", 8, 0)
			y = y - 32

			for idx, rec in ipairs(cat.recipes) do
				local rowH = isCompact and 48 or 42
				local row = UI:CreateListRow(container, width - 4, rowH, idx)
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

				local slot = UI:CreateItemSlot(row, 30, {
					itemID = rec.itemID > 0 and rec.itemID or nil,
					name = rec.name,
					quality = 2,
				})
				slot:SetPoint("LEFT", row, "LEFT", 5, 0)

				local netProfit = self:CalculateStoredRecipeProfit(rec)
				local profBadge = netProfit ~= nil and ("  " .. self:FormatSignedGold(netProfit)) or ""
				local l1 = UI:CreateLabel(row, "|cffffffff" .. rec.name:sub(1, isCompact and 22 or 34) .. "|r" .. profBadge)
				l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -1)

				-- Crafter list line
				local crafterNames = {}
				for _, cr in ipairs(rec.crafters) do
					local _, _, _, hex = UI:GetClassColor(cr.class)
					table.insert(crafterNames, hex .. cr.name .. "|r")
				end
				local crafterStr = #crafterNames > 0
					and ("Crafters: " .. table.concat(crafterNames, ", "))
					or "|cff64748bNo guild crafter synced yet (open profession to share)|r"
				local l2 = UI:CreateLabel(row, crafterStr, 0.72, 0.84, 0.94, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 7, 1)

				-- Action buttons: +Shop, Mail/Letter, and Whisper
				local shopBtn = UI:CreateButton(row, "+Shop", 48, 20, function()
					PluribusHiveProfessions:AddRecipeToShoppingList(rec, 1)
				end, true)
				shopBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

				local primaryCrafter = rec.crafters[1] and rec.crafters[1].name or (cat.crafters[1] and cat.crafters[1].name) or ""
				local mailBtn = UI:CreateButton(row, "Letter", 48, 20, function()
					if _G.PluribusHiveMail then
						_G.PluribusHiveMail:OpenComposer(
							primaryCrafter,
							"Craft Request: " .. rec.name,
							"Hi! Could you please craft " .. rec.name .. " for me? I can provide the materials!",
							{ itemID = rec.itemID, recipeName = rec.name }
						)
					end
				end)
				mailBtn:SetPoint("RIGHT", shopBtn, "LEFT", -4, 0)

				if not isCompact and primaryCrafter ~= "" and not PluribusHive:SamePlayer(primaryCrafter, PluribusHive:GetPlayerShortName()) then
					local wBtn = UI:CreateButton(row, "Whisper", 56, 20, function()
						if SendChatMessage then
							pcall(SendChatMessage, "Hey " .. primaryCrafter .. "! Could you craft " .. rec.name .. " for me?", "WHISPER", nil, primaryCrafter)
						elseif ChatFrame_SendTell then
							pcall(ChatFrame_SendTell, primaryCrafter)
						end
					end)
					wBtn:SetPoint("RIGHT", mailBtn, "LEFT", -4, 0)
				end

				y = y - (rowH + 2)
			end
			y = y - 6
		end
	end

	return y
end

-- 2. Craft Profits List (AH Sell - Mat Cost = Net Profit, sorted highest profit first)
function PluribusHiveProfessions:RenderCraftProfits(container, width, startY)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local profits = self:GetOpenProfessionProfits()
	local isCompact = width < 360

	if #profits == 0 then
		local card = UI:CreateBannerCard(container, width - 4, 56, "Interface\\Icons\\INV_Misc_Coin_02",
			"|cfffbbf24Open a Profession Window to Calculate Profits|r",
			"Open Alchemy, Blacksmithing, Tailoring, etc. Profits also show inline on every recipe row!",
			0.92, 0.72, 0.22)
		card:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
		return y - 64
	end

	local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"
	for idx, info in ipairs(profits) do
		if idx > 60 then break end
		local row = UI:CreateListRow(container, width - 4, 38, idx)
		row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

		local slot = UI:CreateItemSlot(row, 28, {
			itemID = info.itemID,
			name = info.name,
			link = info.itemLink,
			quality = 2,
			count = info.numMade,
		})
		slot:SetPoint("LEFT", row, "LEFT", 5, 0)

		local l1 = UI:CreateLabel(row, "|cffffffff" .. info.name:sub(1, isCompact and 20 or 32) .. "|r")
		l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -1)

		local sellStr = info.sellTotal and PluribusUtils:FormatGold(info.sellTotal) or "?"
		local matStr = PluribusUtils:FormatGold(info.matCost or 0)
		local l2 = UI:CreateLabel(row, string.format("Sell: %s  ·  Mats: %s", sellStr, matStr), 0.70, 0.80, 0.90, "GameFontHighlightSmall")
		l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 7, 1)

		local shopBtn = UI:CreateButton(row, "+Shop", 48, 20, function()
			PluribusHiveProfessions:AddRecipeToShoppingList({
				name = info.name,
				prof = activeProf,
				itemID = info.itemID or 0,
				reagents = info.reagents,
			}, 1)
		end, true)
		shopBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

		local pLbl = UI:CreateLabel(row, self:FormatSignedGold(info.profit), 1, 1, 1, "GameFontNormalSmall")
		pLbl:SetPoint("RIGHT", shopBtn, "LEFT", -8, 0)

		y = y - 40
	end
	return y
end

-- 3. Dropdown-Driven Shopping List Picker (Supports BOTH Recipes AND Items/Materials — ZERO raw input boxes!)
function PluribusHiveProfessions:RenderWishlistPicker(container, width, startY, onChanged)
	local UI = _G.PluribusUIFramework
	local y = startY or -4
	local isCompact = width < 380

	-- Top Controls Row: Category Dropdown + Quantity Cycle + Drag-and-Drop Button
	local ddW = isCompact and 172 or 246
	local dd = UI:CreateFlatDropdown(container, ddW, 26, self:GetPickerCategories(), self.selectedPickerCat or "RECIPES", function(key)
		PluribusHiveProfessions.selectedPickerCat = key
		if onChanged then onChanged() end
	end)
	dd:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

	local qtyCycle = { 1, 5, 10, 20, 40 }
	local qtyBtn = UI:CreateButton(container, "Qty: x" .. tostring(self.selectedPickerQty or 10), 66, 26, function()
		local cur = PluribusHiveProfessions.selectedPickerQty or 10
		local nxt = qtyCycle[1]
		for i, v in ipairs(qtyCycle) do
			if v == cur then nxt = qtyCycle[(i % #qtyCycle) + 1] break end
		end
		PluribusHiveProfessions.selectedPickerQty = nxt
		if onChanged then onChanged() end
	end)
	qtyBtn:SetPoint("LEFT", dd, "RIGHT", 6, 0)

	local dropW = isCompact and (width - ddW - 80) or 140
	local dropBtn = UI:CreateButton(container, isCompact and "Drop" or "Drop Item Here", math.max(46, dropW), 26, function()
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
	y = y - 34

	-- Picker Catalog List (either Recipes OR Materials from the chosen Dropdown Category)
	local pickerHdr = UI:CreateLabel(container, "|cff38bdf8Click to Add to Your Shopping List:|r", 1, 1, 1)
	pickerHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
	y = y - 18

	local db = EnsureShoppingDB()
	if self.selectedPickerCat == "RECIPES" then
		local dir = self:GetProfessionDirectory()
		local shown = 0
		for _, cat in ipairs(dir) do
			for _, rec in ipairs(cat.recipes) do
				if shown >= 12 then break end
				shown = shown + 1
				local row = UI:CreateListRow(container, width - 4, 34, shown)
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

				local slot = UI:CreateItemSlot(row, 26, { itemID = rec.itemID > 0 and rec.itemID or nil, name = rec.name, quality = 2 })
				slot:SetPoint("LEFT", row, "LEFT", 4, 0)

				local lbl = UI:CreateLabel(row, string.format("|cffffffff%s|r |cff94a3b8(%s)|r", rec.name:sub(1, isCompact and 18 or 34), cat.prof))
				lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)

				local addBtn = UI:CreateButton(row, "+ Recipe", 66, 20, function()
					PluribusHiveProfessions:AddRecipeToShoppingList(rec, math.min(10, PluribusHiveProfessions.selectedPickerQty or 1))
					if onChanged then onChanged() end
				end, true)
				addBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
				y = y - 36
			end
			if shown >= 12 then break end
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

			local toggleBtn = UI:CreateButton(row, already and "Added" or ("+ x" .. tostring(self.selectedPickerQty or 10)), 58, 20, function()
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
		if #items == 0 then
			local em = UI:CreateLabel(container, "No items in this category yet — pick another dropdown category or drag an item above.", 0.65, 0.75, 0.85, "GameFontHighlightSmall")
			em:SetPoint("TOPLEFT", container, "TOPLEFT", 6, y)
			y = y - 22
		end
	end

	-- Active Shopping List: Saved Recipes
	y = y - 8
	local recipeList = {}
	for _, r in pairs(db.myShoppingRecipes or {}) do table.insert(recipeList, r) end
	table.sort(recipeList, function(a, b) return (a.name or "") < (b.name or "") end)

	local recHdr = UI:CreateLabel(container, "|cfffbbf24My Shopping List — Recipes (" .. #recipeList .. "):|r", 1, 1, 1, "GameFontNormal")
	recHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
	y = y - 20

	for idx, r in ipairs(recipeList) do
		local row = UI:CreateListRow(container, width - 4, 36, idx)
		row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

		local slot = UI:CreateItemSlot(row, 28, { itemID = r.itemID > 0 and r.itemID or nil, name = r.name, quality = 2, count = r.count })
		slot:SetPoint("LEFT", row, "LEFT", 4, 0)

		local l1 = UI:CreateLabel(row, string.format("|cffffffff%s|r |cff4ade80x%d|r  |cff94a3b8(%s · %d mats)|r", r.name:sub(1, isCompact and 16 or 30), r.count or 1, r.prof or "", #(r.reagents or {})))
		l1:SetPoint("LEFT", slot, "RIGHT", 6, 0)

		local rmBtn = UI:CreateButton(row, "X", 24, 20, function()
			PluribusHiveProfessions:RemoveRecipeFromShoppingList(r.key)
			if onChanged then onChanged() end
		end)
		rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		y = y - 38
	end

	-- Active Shopping List: Aggregated Materials (Explicit Items + Rolled-Up Recipe Mats)
	y = y - 6
	local matMap = self:GetAggregatedShoppingMaterials()
	local matList = {}
	for _, m in pairs(matMap) do table.insert(matList, m) end
	table.sort(matList, function(a, b) return a.itemID < b.itemID end)

	local matHdr = UI:CreateLabel(container, "|cff4ade80My Shopping List — Materials & Items (" .. #matList .. "):|r", 1, 1, 1, "GameFontNormal")
	matHdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
	y = y - 20

	for idx, m in ipairs(matList) do
		local name, link, quality = PluribusUtils:GetItemInfo(m.itemID)
		local owned = self:GetOwnedCount(m.itemID)
		local haveCol = owned >= m.qty and "|cff4ade80" or "|cfffbbf24"
		local row = UI:CreateListRow(container, width - 4, 34, idx)
		row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

		local slot = UI:CreateItemSlot(row, 26, { itemID = m.itemID, name = name, link = link, quality = quality or 1, count = m.qty })
		slot:SetPoint("LEFT", row, "LEFT", 4, 0)

		local qCol = PluribusUtils:GetQualityColor(quality or 1)
		local lbl = UI:CreateLabel(row, string.format("%s%s|r  %s%d/%d|r", qCol, (name or ("Item #" .. m.itemID)):sub(1, isCompact and 16 or 28), haveCol, owned, m.qty))
		lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)

		if m.direct then
			local rmBtn = UI:CreateButton(row, "X", 24, 20, function()
				PluribusHiveProfessions:RemoveNeededMaterial(m.itemID)
				if onChanged then onChanged() end
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		else
			local tag = UI:CreateLabel(row, "|cff38bdf8Recipe Mat|r", 1, 1, 1, "GameFontHighlightSmall")
			tag:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		end
		y = y - 36
	end

	return y
end

-- Populate docked Profession Hive drawer (Craft Profits | Guild Recipes | Shopping List | Surplus Mats)
function PluribusHiveProfessions:RenderDrawerContent(drawer, mode)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local container = drawer.scrollContent
	UI:ClearContainer(container)
	drawer.activeMode = mode

	local titles = {
		profit   = "|cff4ade80Craft Profits (AH Sell - Mats)|r",
		crafters = "|cff38bdf8Guild Recipes by Profession|r",
		wishlist = "|cfffbbf24Shopping List (Recipes & Items)|r",
		surplus  = "|cff4ade80Surplus Mats Guild Needs|r",
	}
	if drawer.titleLbl then
		drawer.titleLbl:SetText(titles[mode] or "Pluribus Professions")
	end

	local y = -4
	local rowW = 304

	if mode == "profit" then
		y = self:RenderCraftProfits(container, rowW, y)
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
				local mailBtn = UI:CreateButton(row, "Letter", 48, 20, function()
					if _G.PluribusHiveMail then
						_G.PluribusHiveMail:OpenComposer(first.name, "Spare " .. m.name, "Hey! I have x" .. m.myCount .. " " .. m.name .. " spare for your " .. (first.prof or "profession") .. ".", { itemID = m.itemID })
					end
				end)
				mailBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
				local offerBtn = UI:CreateButton(row, "Offer", 44, 20, function()
					if SendChatMessage then
						pcall(SendChatMessage, string.format("Hey! I have x%d %s spare for your %s — want them?", m.myCount, m.link or m.name, first.prof or "profession"), "WHISPER", nil, first.name)
					end
				end, true)
				offerBtn:SetPoint("RIGHT", mailBtn, "LEFT", -3, 0)
			end
			y = y - 40
		end
		if #matches == 0 then
			local empty = UI:CreateLabel(container, "No surplus mat matches right now.\nWhen guildmates share professions, spare items you hold appear here automatically.", 0.68, 0.76, 0.86)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -8)
			empty:SetWidth(rowW - 12)
		end
	end

	container:SetHeight(math.max(300, math.abs(y) + 14))
end

-- Attach 4 compact right-edge side bookmark tabs cleanly BELOW native profession tabs (zero overlap!)
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

	local titleLbl = UI:CreateLabel(drawer, "Pluribus Professions", 0.22, 0.74, 0.97, "GameFontNormal")
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
		title = "Craft Profits (AH Sell - Mats)",
		tooltip = "Ranks every recipe in your open profession by live AH profit.",
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -236,
		onClick = function() ToggleDrawerMode("profit") end,
	})

	tabs.crafters = UI:CreateSideTab(hostFrame, 2, {
		icon = "Interface\\Icons\\Trade_BlackSmithing",
		title = "Guild Recipes (By Profession)",
		tooltip = "Browse all professions & recipes across the guild. Whisper, send a letter, or add to Shopping List.",
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -274,
		onClick = function() ToggleDrawerMode("crafters") end,
	})

	tabs.wishlist = UI:CreateSideTab(hostFrame, 3, {
		icon = "Interface\\Icons\\INV_Scroll_03",
		title = "Shopping List (Recipes & Items)",
		tooltip = "Dropdown picker to add recipes or materials to your Shopping List.",
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -312,
		onClick = function() ToggleDrawerMode("wishlist") end,
	})

	tabs.surplus = UI:CreateSideTab(hostFrame, 4, {
		icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
		title = "Surplus Mats Guild Needs",
		tooltip = "Items in YOUR bags/bank you don't need that guildmates need.",
		size = tabSize,
		spacing = tabSpacing,
		yOffset = -350,
		onClick = function() ToggleDrawerMode("surplus") end,
	})
	if tabs.surplus then tabs.surplus:SetBadge(surplusCount, 0.12, 0.62, 0.36) end

	local orderedTabs = { tabs.profit, tabs.crafters, tabs.wishlist, tabs.surplus }
	local function RepositionTabs()
		UI:LayoutSideTabs(hostFrame, orderedTabs, {
			preferredY = -236,
			minYOffset = -236,
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

	PluribusHive:RegisterHandler("PROF", function(sender, body)
		local cls, profStr, needStr = body:match("^([^|]*)|([^|]*)|(.*)$")
		local profs = {}
		if profStr and profStr ~= "" then
			for pName, curStr, maxStr in profStr:gmatch("([^:,]+):(%d+):(%d+)") do
				table.insert(profs, { name = pName, displayName = pName, level = tonumber(curStr) or 0, max = tonumber(maxStr) or 300 })
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
		db.guildProfs[sender] = {
			name = sender,
			class = cls ~= "" and cls or "WARRIOR",
			profs = profs,
			needs = needs,
			updatedAt = time(),
		}
	end)

	-- Receive guildmates' known recipes (background-compressed & trickled)
	PluribusHive:RegisterHandler("RECIPES", function(sender, body)
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
				table.insert(parsed, { name = rName, itemID = tonumber(idStr) or 0, reagents = reagents })
			end
		end
		local db = EnsureShoppingDB()
		db.guildRecipes[sender] = db.guildRecipes[sender] or {}
		db.guildRecipes[sender][canon] = parsed
		if db.guildProfs[sender] and cls ~= "" then
			db.guildProfs[sender].class = cls
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
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "ADDON_LOADED" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
			if C_Timer and C_Timer.After then
				C_Timer.After(9, function() PluribusHiveProfessions:BroadcastProfessions() end)
			end
		elseif event == "SKILL_LINES_CHANGED" then
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:BroadcastProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
		elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
			PluribusHiveProfessions:TryAttachNativeWindows()
			PluribusHiveProfessions:ScanOpenTradeSkill()
			PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
		elseif event == "TRADE_SKILL_UPDATE" then
			PluribusHiveProfessions:UpdateNativeTradeSkillProfits()
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_CraftUI" or arg1 == "Blizzard_Professions") then
			PluribusHiveProfessions:TryAttachNativeWindows()
		end
	end)
end

return PluribusHiveProfessions
