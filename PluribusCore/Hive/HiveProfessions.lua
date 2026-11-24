-- PluribusHive Professions & Guild Material-Matcher
-- Shares profession levels, recipes, and needed skill-up materials across the guild
-- Matches YOUR surplus materials to guildmates who need them & embeds tabs inside WoW's Skill/Professions window

PluribusHiveProfessions = {
	initialized = false,
	skillTabsAttached = false,
	tradeTabsAttached = false,
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

-- Normalize localized profession names to canonical English keys for matching
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

-- Classic / Warcraft Forever leveling material brackets by profession & skill range
-- { minSkill, maxSkill, itemIDs }
PluribusHiveProfessions.LEVELING_MATS = {
	Alchemy = {
		{ 1, 75, { 765, 2447, 3371 } },               -- Silverleaf, Peacebloom, Empty Vial
		{ 75, 150, { 2449, 2450, 785, 2453, 3372 } }, -- Earthroot, Briarthorn, Mageroyal, Bruiseweed
		{ 150, 225, { 3355, 3356, 3357, 3821 } },     -- Wild Steelbloom, Kingsblood, Liferoot, Goldthorn
		{ 225, 300, { 3818, 3820, 8831, 8838, 13463, 13464, 13465, 13466 } }, -- Fadeleaf, Stranglekelp, Purple Lotus, Sungrass, Dreamfoil, Golden Sansam, Mountain Silversage, Plaguebloom
	},
	Blacksmithing = {
		{ 1, 75, { 2840, 2835 } },                    -- Copper Bar, Rough Stone
		{ 75, 150, { 2841, 2842, 2836 } },            -- Bronze Bar, Silver Bar, Coarse Stone
		{ 150, 225, { 3575, 3859, 2838, 7912 } },     -- Iron Bar, Steel Bar, Heavy Stone, Solid Stone
		{ 225, 300, { 3860, 12359, 12365, 12360 } },  -- Mithril Bar, Thorium Bar, Dense Stone, Arcanite Bar
	},
	Engineering = {
		{ 1, 75, { 2840, 2835, 2589 } },              -- Copper Bar, Rough Stone, Linen Cloth
		{ 75, 150, { 2841, 2836, 2592 } },            -- Bronze Bar, Coarse Stone, Wool Cloth
		{ 150, 225, { 3575, 3860, 2838, 7912, 4306 } }, -- Iron/Mithril Bar, Heavy/Solid Stone, Silk Cloth
		{ 225, 300, { 3860, 12359, 12365, 14047 } },  -- Mithril/Thorium Bar, Dense Stone, Runecloth
	},
	Enchanting = {
		{ 1, 75, { 10940, 10938, 10939 } },           -- Strange Dust, Lesser/Greater Magic Essence
		{ 75, 150, { 11083, 10998, 11082 } },         -- Soul Dust, Astral Essences
		{ 150, 225, { 11137, 11134, 11135, 11176 } }, -- Vision Dust, Mystic Essences, Dream Dust
		{ 225, 300, { 11176, 16204, 16202, 16203, 14344 } }, -- Dream Dust, Illusion Dust, Eternal Essences, Large Brilliant Shard
	},
	Leatherworking = {
		{ 1, 75, { 2318, 2934 } },                    -- Light Leather, Ruined Leather Scraps
		{ 75, 150, { 2319, 4232 } },                  -- Medium Leather, Medium Hide
		{ 150, 225, { 4234, 4304 } },                 -- Heavy Leather, Thick Leather
		{ 225, 300, { 4304, 8170, 8169 } },           -- Thick Leather, Rugged Leather, Thick Hide
	},
	Tailoring = {
		{ 1, 75, { 2589 } },                          -- Linen Cloth
		{ 75, 150, { 2592, 4306 } },                  -- Wool Cloth, Silk Cloth
		{ 150, 225, { 4306, 4338 } },                 -- Silk Cloth, Mageweave Cloth
		{ 225, 300, { 4338, 14047, 14256 } },         -- Mageweave Cloth, Runecloth, Felcloth
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
	return PROF_CANONICAL[name] or name
end

function PluribusHiveProfessions:ScanMyProfessions()
	local profs = {}
	local added = {}

	-- Modern C_TradeSkillUI / GetProfessions API
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

	-- Classic GetNumSkillLines / GetSkillLineInfo fallback
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

	-- Compute needed leveling materials automatically from profession brackets + open TradeSkill orange/yellow recipes + wishlist
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

	-- Also merge explicit user wishlist
	local db = PluribusHive:GetDB()
	for itemID, qty in pairs(db.myNeededMats or {}) do
		if type(itemID) == "number" and qty > 0 then
			needs[itemID] = needs[itemID] or { itemID = itemID, prof = "Wishlist", level = 0, max = 0, qty = qty }
			needs[itemID].qty = qty
		end
	end

	-- Save my own record into guildProfs
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

-- Scan currently open TradeSkill window for exact orange/yellow skill-up reagents
function PluribusHiveProfessions:ScanOpenTradeSkill()
	if not GetNumTradeSkills or not GetTradeSkillInfo or not GetTradeSkillNumReagents then return end
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local rec = db.guildProfs[me] or self:ScanMyProfessions()
	local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"

	for i = 1, GetNumTradeSkills() do
		local _, skillType = GetTradeSkillInfo(i)
		if skillType == "optimal" or skillType == "medium" then
			local numReagents = GetTradeSkillNumReagents(i) or 0
			for r = 1, numReagents do
				local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
				local _, _, reqCount = GetTradeSkillReagentInfo(i, r)
				local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
				if itemID and itemID > 0 then
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
	end
	rec.updatedAt = time()
	self:BroadcastProfessions()
end

function PluribusHiveProfessions:BroadcastProfessions()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareProfessions then return end
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
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
	PluribusHive:Send("PROF", payload, "GUILD")
end

function PluribusHiveProfessions:DoINeedItem(itemID)
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local mine = db.guildProfs[me]
	return mine and mine.needs and mine.needs[itemID] ~= nil or false
end

-- Returns guildmates who need this item to level their professions + whether YOU don't need it
function PluribusHiveProfessions:GetGuildNeedsForItem(itemID)
	if not itemID then return {}, false end
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local iNeedIt = self:DoINeedItem(itemID)
	local neededBy = {}

	for memberName, rec in pairs(db.guildProfs or {}) do
		if memberName ~= me and rec.needs and rec.needs[itemID] then
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

-- Cross-references YOUR bags/bank against guildmates' profession needs (only items YOU don't need!)
function PluribusHiveProfessions:GetMySurplusMatches()
	if not _G.PluribusHiveInventory then return {} end
	local myRec = _G.PluribusHiveInventory:GetMyAltRecord()
	local combined = {}
	for id, cnt in pairs(myRec.bags or {}) do
		combined[id] = (combined[id] or 0) + cnt
	end
	for id, cnt in pairs(myRec.bank or {}) do
		combined[id] = (combined[id] or 0) + cnt
	end

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

function PluribusHiveProfessions:AddNeededMaterial(itemID, qty)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return false end
	local db = PluribusHive:GetDB()
	db.myNeededMats[itemID] = tonumber(qty) or 20
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	return true
end

function PluribusHiveProfessions:RemoveNeededMaterial(itemID)
	itemID = tonumber(itemID)
	if not itemID then return false end
	local db = PluribusHive:GetDB()
	db.myNeededMats[itemID] = nil
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	return true
end

-- Resolve an item ID from numeric ID, item hyperlink, or item name in bags/HiveDB
function PluribusHiveProfessions:ResolveItemID(input)
	if not input then return nil end
	local raw = tostring(input):match("^%s*(.-)%s*$")
	if raw == "" then return nil end
	local directNum = tonumber(raw)
	if directNum and directNum > 0 then return directNum end
	local linkID = PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(raw)
	if linkID and linkID > 0 then return linkID end

	-- Search WoW client cache directly
	if PluribusUtils then
		local _, resolvedLink = PluribusUtils:GetItemInfo(raw)
		if resolvedLink then
			local id = PluribusUtils:GetItemIDFromHyperlink(resolvedLink)
			if id and id > 0 then return id end
		end
	end

	-- Search Hive Network DB & player's bags by name substring
	local needle = raw:lower()
	if _G.PluribusHiveInventory then
		local matches = _G.PluribusHiveInventory:SearchAll(needle)
		if matches and matches[1] and matches[1].itemID then
			return matches[1].itemID
		end
	end
	local db = PluribusHive:GetDB()
	for id, entry in pairs((db.gameDB and db.gameDB.items) or {}) do
		if entry.name and entry.name:lower():find(needle, 1, true) then
			return tonumber(id)
		end
	end
	if _G.PluribusWowheadCache and _G.PluribusWowheadCache.items then
		for id, entry in pairs(_G.PluribusWowheadCache.items) do
			if entry.name and entry.name:lower():find(needle, 1, true) then
				return tonumber(id)
			end
		end
	end
	return nil
end

-- Populate a docked Profession Hive drawer (Surplus Mats | Guild Crafters | Wishlist)
function PluribusHiveProfessions:RenderDrawerContent(drawer, mode)
	if not drawer or not drawer.scrollContent or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local container = drawer.scrollContent
	UI:ClearContainer(container)
	drawer.activeMode = mode

	local titles = {
		surplus = "|cff4ade80Surplus Mats Guild Needs|r",
		crafters = "|cff38bdf8Guild Crafters Directory|r",
		wishlist = "|cfffbbf24My Material Wishlist|r",
	}
	if drawer.titleLbl then
		drawer.titleLbl:SetText(titles[mode] or "Pluribus Professions")
	end

	local y = -4
	local rowW = 294

	if mode == "surplus" then
		local matches = self:GetMySurplusMatches()
		for idx, m in ipairs(matches) do
			local row = UI:CreateListRow(container, rowW, 38, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 30, {
				itemID = m.itemID,
				name = m.name,
				link = m.link,
				quality = m.quality,
				count = m.myCount,
				isSurplus = true,
			})
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)

			local qCol = PluribusUtils:GetQualityColor(m.quality)
			local first = m.neededBy[1]
			local l1 = UI:CreateLabel(row, qCol .. (m.name or ("Item #" .. m.itemID)):sub(1, 20) .. "|r")
			l1:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, -1)

			local whoStr = first and string.format("%s (%s)", first.name, first.prof) or "Guild"
			if #m.neededBy > 1 then whoStr = whoStr .. " +" .. (#m.neededBy - 1) end
			local l2 = UI:CreateLabel(row, whoStr, 0.70, 0.84, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, 1)

			if first and first.name then
				local offerBtn = UI:CreateButton(row, "Offer", 52, 22, function()
					if SendChatMessage then
						local itemRef = m.link or m.name
						pcall(SendChatMessage, string.format("Hey! I have x%d %s spare for your %s — want them?", m.myCount, itemRef, first.prof or "profession"), "WHISPER", nil, first.name)
					end
				end, true)
				offerBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			end
			y = y - 40
		end
		if #matches == 0 then
			local empty = UI:CreateLabel(container, "No surplus mat matches right now.\nWhen guildmates share professions, spare items you hold appear here automatically.", 0.68, 0.76, 0.86)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -8)
			empty:SetWidth(rowW - 12)
		end
	elseif mode == "crafters" then
		local db = PluribusHive:GetDB()
		local list = {}
		for _, rec in pairs(db.guildProfs or {}) do
			table.insert(list, rec)
		end
		table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

		for idx, rec in ipairs(list) do
			local pStrs = {}
			for _, pr in ipairs(rec.profs or {}) do
				table.insert(pStrs, string.format("%s %d", pr.displayName or pr.name, pr.level or 0))
			end
			local row = UI:CreateListRow(container, rowW, 34, idx, function()
				if ChatFrame_SendTell and rec.name ~= PluribusHive:GetPlayerShortName() then
					pcall(ChatFrame_SendTell, rec.name)
				end
			end)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local _, _, _, hex = UI:GetClassColor(rec.class)
			local l1 = UI:CreateLabel(row, hex .. rec.name .. "|r")
			l1:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -3)
			local l2 = UI:CreateLabel(row, #pStrs > 0 and table.concat(pStrs, " · ") or "Scanning...", 0.74, 0.84, 0.94, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 3)
			l2:SetWidth(rowW - 16)
			y = y - 36
		end
	else
		-- Intuitive Drop-Item OR Type Name/Link/ID Wishlist
		local dropBtn = UI:CreateButton(container, "Drop Item Here to Add to Wishlist", rowW - 4, 28, function()
			if GetCursorInfo then
				local kind, itemID = GetCursorInfo()
				if kind == "item" and itemID then
					PluribusHiveProfessions:AddNeededMaterial(itemID, 20)
					if ClearCursor then pcall(ClearCursor) end
					PluribusHiveProfessions:RenderDrawerContent(drawer, "wishlist")
				end
			end
		end, false)
		dropBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
		dropBtn:SetScript("OnReceiveDrag", function()
			if GetCursorInfo then
				local kind, itemID = GetCursorInfo()
				if kind == "item" and itemID then
					PluribusHiveProfessions:AddNeededMaterial(itemID, 20)
					if ClearCursor then pcall(ClearCursor) end
					PluribusHiveProfessions:RenderDrawerContent(drawer, "wishlist")
				end
			end
		end)
		y = y - 34

		local inputBox = UI:CreateInputBox(container, 184, 24)
		inputBox:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)
		inputBox:SetText("")

		local qtyBox = UI:CreateInputBox(container, 42, 24)
		qtyBox:SetPoint("LEFT", inputBox, "RIGHT", 4, 0)
		qtyBox:SetText("20")

		local addBtn = UI:CreateButton(container, "Add", 56, 24, function()
			local resolved = PluribusHiveProfessions:ResolveItemID(inputBox:GetText())
			if resolved then
				PluribusHiveProfessions:AddNeededMaterial(resolved, tonumber(qtyBox:GetText()) or 20)
				PluribusHiveProfessions:RenderDrawerContent(drawer, "wishlist")
			elseif _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("|cfffbbf24Drop an item, Shift-Click a link, or type an exact item name/ID.|r", 3)
			end
		end, true)
		addBtn:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
		y = y - 32

		local hint = UI:CreateLabel(container, "Tip: Drag any item above or type its name / ID", 0.62, 0.72, 0.82, "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)
		y = y - 20

		local db = PluribusHive:GetDB()
		local idx = 0
		for itemID, qty in pairs(db.myNeededMats or {}) do
			idx = idx + 1
			local name, link, quality = PluribusUtils:GetItemInfo(itemID)
			local row = UI:CreateListRow(container, rowW, 34, idx)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 26, {
				itemID = itemID,
				name = name,
				link = link,
				quality = quality or 1,
				count = qty,
			})
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)

			local qCol = PluribusUtils:GetQualityColor(quality or 1)
			local lbl = UI:CreateLabel(row, qCol .. (name or ("Item #" .. itemID)):sub(1, 22) .. "|r  |cff94a3b8x" .. tostring(qty) .. "|r")
			lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)

			local rmBtn = UI:CreateButton(row, "X", 24, 20, function()
				PluribusHiveProfessions:RemoveNeededMaterial(itemID)
				PluribusHiveProfessions:RenderDrawerContent(drawer, "wishlist")
			end)
			rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			y = y - 36
		end
	end

	container:SetHeight(math.max(300, math.abs(y) + 12))
end

-- Attach Adventure-Guide-style right-edge side bookmark tabs + docked drawer onto WoW's Skill / TradeSkill / Craft / Professions window
function PluribusHiveProfessions:AttachToSkillWindow(hostFrame, key)
	if not hostFrame or hostFrame._plbHiveAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	hostFrame._plbHiveAttached = true

	local UI = _G.PluribusUIFramework

	-- Docked side drawer that lives right beside the native Professions window (closes automatically with it)
	local drawer = CreateFrame("Frame", "PluribusProfDrawer_" .. tostring(key or "main"), hostFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	drawer:SetSize(332, 412)
	drawer:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT", 42, -14)
	drawer:SetFrameStrata("HIGH")
	UI:ApplyBackdrop(drawer, 0.06, 0.08, 0.13, 0.97, 0.22, 0.30, 0.42, 0.95)

	local titleLbl = UI:CreateLabel(drawer, "Pluribus Professions", 0.22, 0.74, 0.97, "GameFontNormal")
	titleLbl:SetPoint("TOPLEFT", drawer, "TOPLEFT", 12, -10)
	drawer.titleLbl = titleLbl

	local closeBtn = UI:CreateButton(drawer, "X", 22, 20, function()
		drawer:Hide()
		for _, t in pairs(hostFrame._plbProfTabs or {}) do t:SetActiveState(false) end
	end)
	closeBtn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -8, -8)

	local scanBtn = UI:CreateButton(drawer, "Sync", 48, 20, function()
		PluribusHiveProfessions:ScanMyProfessions()
		PluribusHiveProfessions:ScanOpenTradeSkill()
		PluribusHiveProfessions:BroadcastProfessions()
		PluribusHiveProfessions:RenderDrawerContent(drawer, drawer.activeMode or "surplus")
	end, true)
	scanBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

	local scroll = UI:CreateScrollFrame(drawer, "PluribusProfDrawerScroll_" .. tostring(key or "main"), 316, 366)
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
	local yStart = (key == "skill") and -62 or -46

	tabs.surplus = UI:CreateSideTab(hostFrame, 1, {
		icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
		title = "Guild Surplus Mats",
		tooltip = "Items in YOUR bags/bank you don't need that guildmates need to skill up.",
		yOffset = yStart,
		onClick = function() ToggleDrawerMode("surplus") end,
	})
	if tabs.surplus then tabs.surplus:SetBadge(surplusCount, 0.12, 0.62, 0.36) end

	tabs.crafters = UI:CreateSideTab(hostFrame, 2, {
		icon = "Interface\\Icons\\Trade_BlackSmithing",
		title = "Guild Crafters",
		tooltip = "Browse all guildmates' professions & skill levels. Click to whisper.",
		yOffset = yStart - 46,
		onClick = function() ToggleDrawerMode("crafters") end,
	})

	tabs.wishlist = UI:CreateSideTab(hostFrame, 3, {
		icon = "Interface\\Icons\\INV_Scroll_03",
		title = "My Material Wishlist",
		tooltip = "Drag & drop or type materials you need so guildmates see them on tooltips.",
		yOffset = yStart - 92,
		onClick = function() ToggleDrawerMode("wishlist") end,
	})

	-- Refresh badge count whenever the profession window opens
	if hostFrame.HookScript then
		pcall(hostFrame.HookScript, hostFrame, "OnShow", function()
			if tabs.surplus then
				local cnt = #(PluribusHiveProfessions:GetMySurplusMatches() or {})
				tabs.surplus:SetBadge(cnt, 0.12, 0.62, 0.36)
			end
		end)
	end
end

function PluribusHiveProfessions:TryAttachNativeWindows()
	if _G.SkillFrame then self:AttachToSkillWindow(_G.SkillFrame, "skill") end
	if _G.TradeSkillFrame then self:AttachToSkillWindow(_G.TradeSkillFrame, "tradeskill") end
	if _G.CraftFrame then self:AttachToSkillWindow(_G.CraftFrame, "craft") end
	if _G.ProfessionsFrame then self:AttachToSkillWindow(_G.ProfessionsFrame, "professions") end
end

function PluribusHiveProfessions:Initialize()
	if self.initialized then return end
	self.initialized = true

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
		local db = PluribusHive:GetDB()
		db.guildProfs[sender] = {
			name = sender,
			class = cls ~= "" and cls or "WARRIOR",
			profs = profs,
			needs = needs,
			updatedAt = time(),
		}
	end)

	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(2, 6), function()
					PluribusHiveProfessions:BroadcastProfessions()
				end)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "CRAFT_SHOW", "ADDON_LOADED" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
			if C_Timer and C_Timer.After then
				C_Timer.After(7, function() PluribusHiveProfessions:BroadcastProfessions() end)
			end
		elseif event == "SKILL_LINES_CHANGED" then
			PluribusHiveProfessions:ScanMyProfessions()
			PluribusHiveProfessions:BroadcastProfessions()
			PluribusHiveProfessions:TryAttachNativeWindows()
		elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
			PluribusHiveProfessions:TryAttachNativeWindows()
			PluribusHiveProfessions:ScanOpenTradeSkill()
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_CraftUI" or arg1 == "Blizzard_Professions") then
			PluribusHiveProfessions:TryAttachNativeWindows()
		end
	end)
end

return PluribusHiveProfessions
