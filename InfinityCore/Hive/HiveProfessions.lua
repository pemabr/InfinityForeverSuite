-- InfinityHive Professions & Guild Material-Matcher
-- Shares profession levels, recipes, and needed skill-up materials across the guild
-- Matches YOUR surplus materials to guildmates who need them & embeds tabs inside WoW's Skill/Professions window

InfinityHiveProfessions = {
	initialized = false,
	skillTabsAttached = false,
	tradeTabsAttached = false,
}
_G.InfinityHiveProfessions = InfinityHiveProfessions

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
InfinityHiveProfessions.LEVELING_MATS = {
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

function InfinityHiveProfessions:ScanMyProfessions()
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
	local db = InfinityHive:GetDB()
	for itemID, qty in pairs(db.myNeededMats or {}) do
		if type(itemID) == "number" and qty > 0 then
			needs[itemID] = needs[itemID] or { itemID = itemID, prof = "Wishlist", level = 0, max = 0, qty = qty }
			needs[itemID].qty = qty
		end
	end

	-- Save my own record into guildProfs
	local me = InfinityHive:GetPlayerShortName()
	db.guildProfs[me] = {
		name = me,
		class = InfinityHive:GetPlayerClass(),
		profs = profs,
		needs = needs,
		updatedAt = time(),
	}
	return db.guildProfs[me]
end

-- Scan currently open TradeSkill window for exact orange/yellow skill-up reagents
function InfinityHiveProfessions:ScanOpenTradeSkill()
	if not GetNumTradeSkills or not GetTradeSkillInfo or not GetTradeSkillNumReagents then return end
	local me = InfinityHive:GetPlayerShortName()
	local db = InfinityHive:GetDB()
	local rec = db.guildProfs[me] or self:ScanMyProfessions()
	local activeProf = GetTradeSkillLine and CanonicalProf(GetTradeSkillLine()) or "Profession"

	for i = 1, GetNumTradeSkills() do
		local _, skillType = GetTradeSkillInfo(i)
		if skillType == "optimal" or skillType == "medium" then
			local numReagents = GetTradeSkillNumReagents(i) or 0
			for r = 1, numReagents do
				local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
				local _, _, reqCount = GetTradeSkillReagentInfo(i, r)
				local itemID = link and InfinityUtils and InfinityUtils:GetItemIDFromHyperlink(link)
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

function InfinityHiveProfessions:BroadcastProfessions()
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareProfessions then return end
	local me = InfinityHive:GetPlayerShortName()
	local db = InfinityHive:GetDB()
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
	InfinityHive:Send("PROF", payload, "GUILD")
end

function InfinityHiveProfessions:DoINeedItem(itemID)
	local me = InfinityHive:GetPlayerShortName()
	local db = InfinityHive:GetDB()
	local mine = db.guildProfs[me]
	return mine and mine.needs and mine.needs[itemID] ~= nil or false
end

-- Returns guildmates who need this item to level their professions + whether YOU don't need it
function InfinityHiveProfessions:GetGuildNeedsForItem(itemID)
	if not itemID then return {}, false end
	local me = InfinityHive:GetPlayerShortName()
	local db = InfinityHive:GetDB()
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
function InfinityHiveProfessions:GetMySurplusMatches()
	if not _G.InfinityHiveInventory then return {} end
	local myRec = _G.InfinityHiveInventory:GetMyAltRecord()
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
				local name, link, quality = InfinityUtils:GetItemInfo(itemID)
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

function InfinityHiveProfessions:AddNeededMaterial(itemID, qty)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return false end
	local db = InfinityHive:GetDB()
	db.myNeededMats[itemID] = tonumber(qty) or 20
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	return true
end

function InfinityHiveProfessions:RemoveNeededMaterial(itemID)
	itemID = tonumber(itemID)
	if not itemID then return false end
	local db = InfinityHive:GetDB()
	db.myNeededMats[itemID] = nil
	self:ScanMyProfessions()
	self:BroadcastProfessions()
	return true
end

-- Embed clean, native-feeling Hive tabs directly onto WoW's SkillFrame & TradeSkillFrame/ProfessionsFrame
function InfinityHiveProfessions:AttachToSkillWindow(hostFrame, key)
	if not hostFrame or hostFrame._infHiveAttached or not _G.InfinityUIFramework then return end
	hostFrame._infHiveAttached = true

	local tabNeeds = _G.InfinityUIFramework:CreateButton(hostFrame, "Guild Needs", 92, 22, function()
		if _G.InfinityMainFrame and _G.InfinityMainFrame.OpenToTab then
			_G.InfinityMainFrame:OpenToTab("Professions")
		end
	end, true)
	tabNeeds:SetFrameStrata("HIGH")
	tabNeeds:SetPoint("TOPRIGHT", hostFrame, "TOPRIGHT", -34, -4)

	local tabCrafters = _G.InfinityUIFramework:CreateButton(hostFrame, "Hive Craft", 84, 22, function()
		if _G.InfinityMainFrame and _G.InfinityMainFrame.OpenToTab then
			_G.InfinityMainFrame:OpenToTab("Professions")
		end
	end, false)
	tabCrafters:SetFrameStrata("HIGH")
	tabCrafters:SetPoint("RIGHT", tabNeeds, "LEFT", -6, 0)
end

function InfinityHiveProfessions:TryAttachNativeWindows()
	if _G.SkillFrame then self:AttachToSkillWindow(_G.SkillFrame, "skill") end
	if _G.TradeSkillFrame then self:AttachToSkillWindow(_G.TradeSkillFrame, "tradeskill") end
	if _G.ProfessionsFrame then self:AttachToSkillWindow(_G.ProfessionsFrame, "professions") end
end

function InfinityHiveProfessions:Initialize()
	if self.initialized then return end
	self.initialized = true

	InfinityHive:RegisterHandler("PROF", function(sender, body)
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
		local db = InfinityHive:GetDB()
		db.guildProfs[sender] = {
			name = sender,
			class = cls ~= "" and cls or "WARRIOR",
			profs = profs,
			needs = needs,
			updatedAt = time(),
		}
	end)

	if _G.InfinityMessaging then
		_G.InfinityMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(2, 6), function()
					InfinityHiveProfessions:BroadcastProfessions()
				end)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "ADDON_LOADED" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "PLAYER_ENTERING_WORLD" then
			InfinityHiveProfessions:ScanMyProfessions()
			InfinityHiveProfessions:TryAttachNativeWindows()
			if C_Timer and C_Timer.After then
				C_Timer.After(7, function() InfinityHiveProfessions:BroadcastProfessions() end)
			end
		elseif event == "SKILL_LINES_CHANGED" then
			InfinityHiveProfessions:ScanMyProfessions()
			InfinityHiveProfessions:BroadcastProfessions()
			InfinityHiveProfessions:TryAttachNativeWindows()
		elseif event == "TRADE_SKILL_SHOW" then
			InfinityHiveProfessions:TryAttachNativeWindows()
			InfinityHiveProfessions:ScanOpenTradeSkill()
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_Professions") then
			InfinityHiveProfessions:TryAttachNativeWindows()
		end
	end)
end

return InfinityHiveProfessions
