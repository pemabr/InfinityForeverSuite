-- InfinityRaid UI Module
-- Full Classic / WoW Forever Raid Boss Browser, Tactics Announcer & Composition Readiness UI

InfinityRaidUI = {
	selectedZone = "Naxxramas",
	selectedBoss = nil,
}

local FALLBACK_BOSSES = {
	{ id = 1, name = "Anub'Rekhan", zone = "Naxxramas", level = 63, health = 2160000, mechanics = { "Locust Swarm (kiting required)", "Impale", "Crypt Guard spawns" }, compositionRequirements = { minTanks = 2, minHealers = 8, minDPS = 25 }, tactics = "OT picks up Crypt Guards. Tank kites boss clockwise around outer rim during Locust Swarm.", loot = { { name = "Band of Unanswered Prayers", rarity = 4 }, { name = "Cryptfiend Silk Cloak", rarity = 4 } } },
	{ id = 2, name = "Patchwerk", zone = "Naxxramas", level = 63, health = 3850000, mechanics = { "Hateful Strike every 1.2s", "Frenzy at 5%", "7-minute Enrage" }, compositionRequirements = { minTanks = 4, minHealers = 12, minDPS = 24 }, tactics = "Assign dedicated healer pairs to each Hateful Strike off-tank. Pure DPS check.", loot = { { name = "Severance", rarity = 4 }, { name = "Band of Reanimation", rarity = 4 } } },
	{ id = 3, name = "Loatheb", zone = "Naxxramas", level = 63, health = 5200000, mechanics = { "Corrupted Mind (60s heal lock)", "Inevitable Doom", "Spore +50% Crit" }, compositionRequirements = { minTanks = 2, minHealers = 10, minDPS = 28 }, tactics = "Strict 5-second healer rotation. Rotate DPS groups onto spores and stack shadow pots.", loot = { { name = "Brimstone Staff", rarity = 4 }, { name = "Loatheb's Reflection", rarity = 4 } } },
	{ id = 4, name = "Sapphiron", zone = "Naxxramas", level = 63, health = 3400000, mechanics = { "Frost Aura", "Life Drain (decurse fast)", "Ice Bolt & Frost Breath" }, compositionRequirements = { minTanks = 2, minHealers = 12, minDPS = 26 }, tactics = "Stack Frost Resistance gear. Hide behind Ice Block players during air phase Frost Breath.", loot = { { name = "Slayer's Crest", rarity = 4 }, { name = "The Restrained Essence of Sapphiron", rarity = 4 } } },
	{ id = 5, name = "Kel'Thuzad", zone = "Naxxramas", level = 63, health = 3500000, mechanics = { "Frostbolt interrupt", "Void Zone", "Frost Blast", "Chains of Kel'Thuzad" }, compositionRequirements = { minTanks = 4, minHealers = 12, minDPS = 24 }, tactics = "Interrupt single-target Frostbolt! Spread 10 yards for Frost Blast, step out of Void Zones immediately.", loot = { { name = "Might of Menethil", rarity = 4 }, { name = "Hungering Cold", rarity = 4 }, { name = "Phylactery of Kel'Thuzad", rarity = 4 } } },
	{ id = 6, name = "Ragnaros", zone = "Molten Core", level = 63, health = 1100000, mechanics = { "Wrath of Ragnaros knockback", "Sons of Flame submerge", "Magma Blast" }, compositionRequirements = { minTanks = 3, minHealers = 8, minDPS = 25 }, tactics = "Melee out before Wrath knockback. Stack Fire Resistance and banish/kill Sons of Flame at 3:00.", loot = { { name = "Bonereaver's Edge", rarity = 4 }, { name = "Perdition's Blade", rarity = 4 } } },
	{ id = 7, name = "Nefarian", zone = "Blackwing Lair", level = 63, health = 2165000, mechanics = { "Shadow Flame (Onyxia Cloak)", "Class Calls", "Bellowing Roar fear" }, compositionRequirements = { minTanks = 2, minHealers = 9, minDPS = 25 }, tactics = "Equip Onyxia Scale Cloak. Prepare Fear Ward/Berserker Rage for Bellowing Roar and handle Class Calls.", loot = { { name = "Ashkandi, Greatsword of the Brotherhood", rarity = 4 }, { name = "Neltharion's Tear", rarity = 4 } } },
	{ id = 8, name = "C'Thun", zone = "Ahn'Qiraj", level = 63, health = 1000000, mechanics = { "Eye Beam chain", "Dark Glare rotation", "Stomach phase tentacles" }, compositionRequirements = { minTanks = 2, minHealers = 10, minDPS = 28 }, tactics = "Enter room in staggered groups to avoid Eye Beam chains. Kill tentacles first and weaken C'Thun in stomach.", loot = { { name = "Dark Edge of Insanity", rarity = 4 }, { name = "Death's Sting", rarity = 4 } } },
}

local function getAllBosses()
	local db = _G.EncounterDatabase or _G.InfinityRaidEncounters
	if db and db.encounters and type(db.encounters) == "table" and #db.encounters > 0 then
		return db.encounters
	end
	return FALLBACK_BOSSES
end

local function scanLiveRaidComp()
	local total = (GetNumGroupMembers and GetNumGroupMembers()) or 0
	if total == 0 then
		return 1, 0, 0, 1
	end
	local tanks, healers, dps = 0, 0, 0
	local isRaid = IsInRaid and IsInRaid()
	local prefix = isRaid and "raid" or "party"
	for i = 1, total do
		local unit = (not isRaid and i == total) and "player" or (prefix .. i)
		if UnitExists and UnitExists(unit) then
			local _, cls = UnitClass(unit)
			local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
			if role == "TANK" or (role == "NONE" and cls == "WARRIOR") then
				tanks = tanks + 1
			elseif role == "HEALER" or (role == "NONE" and (cls == "PRIEST" or cls == "DRUID" or cls == "PALADIN" or cls == "SHAMAN")) then
				healers = healers + 1
			else
				dps = dps + 1
			end
		end
	end
	return total, tanks, healers, dps
end

function InfinityRaidUI:Toggle()
	if not _G.InfinityRaidWindow then
		_G.InfinityRaidWindow = self:Create()
		_G.InfinityRaidWindow:Show()
		return
	end
	if _G.InfinityRaidWindow:IsVisible() then
		_G.InfinityRaidWindow:Hide()
	else
		self:Refresh(_G.InfinityRaidWindow)
		_G.InfinityRaidWindow:Show()
	end
end

function InfinityRaidUI:Create()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityRaidWindow",
		UIParent,
		760,
		510,
		"Infinity Raid Command",
		"Boss Tactics, Loot & Raid Comp"
	)
	frame:SetPoint("CENTER")

	local zoneTabs = {
		{ name = "Naxxramas", key = "Naxxramas" },
		{ name = "Blackwing Lair", key = "Blackwing Lair" },
		{ name = "Molten Core", key = "Molten Core" },
		{ name = "Ahn'Qiraj", key = "Ahn'Qiraj" },
		{ name = "All Raids", key = "ALL" },
	}

	local tabBar = InfinityUIFramework:CreateTabBar(frame, zoneTabs, function(zoneKey)
		InfinityRaidUI.selectedZone = zoneKey
		InfinityRaidUI.selectedBoss = nil
		InfinityRaidUI:Refresh(frame)
	end, 736)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	-- Left boss list card
	local listCard = InfinityUIFramework:CreateCard(frame, 236, 412, "Encounters")
	listCard:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -10)
	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityRaidBossScroll", 222, 376)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -30)
	frame.bossList = scroll.content

	-- Right detail card
	local detailCard = InfinityUIFramework:CreateCard(frame, 490, 412)
	detailCard:SetPoint("TOPLEFT", listCard, "TOPRIGHT", 10, 0)
	frame.detailCard = detailCard

	tabBar:SelectTab("Naxxramas")
	return frame
end

function InfinityRaidUI:Refresh(frame)
	if not frame then return end
	InfinityUIFramework:ClearContainer(frame.bossList)

	local all = getAllBosses()
	local filtered = {}
	for _, b in ipairs(all) do
		local zoneStr = tostring(b.zone or "")
		if self.selectedZone == "ALL" or zoneStr:lower():find(self.selectedZone:lower(), 1, true) then
			table.insert(filtered, b)
		end
	end
	if #filtered == 0 then filtered = FALLBACK_BOSSES end

	local y = -2
	for idx, boss in ipairs(filtered) do
		if not self.selectedBoss then self.selectedBoss = boss end
		local row = InfinityUIFramework:CreateListRow(frame.bossList, 198, 28, idx, function()
			InfinityRaidUI.selectedBoss = boss
			InfinityRaidUI:RenderBossDetails(frame, boss)
		end)
		row:SetPoint("TOPLEFT", frame.bossList, "TOPLEFT", 2, y)

		local lbl = InfinityUIFramework:CreateLabel(row, tostring(boss.name))
		lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
		local lv = InfinityUIFramework:CreateLabel(row, "|cfffbbf24Lv" .. tostring(boss.level or 63) .. "|r")
		lv:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 30
	end

	frame.bossList:SetHeight(math.max(360, -y + 10))
	if self.selectedBoss then
		self:RenderBossDetails(frame, self.selectedBoss)
	end
end

function InfinityRaidUI:RenderBossDetails(frame, boss)
	local d = frame.detailCard
	InfinityUIFramework:ClearContainer(d)

	local title = InfinityUIFramework:CreateLabel(d, "|cff38bdf8" .. tostring(boss.name) .. "|r", nil, nil, nil, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -14)

	local sub = InfinityUIFramework:CreateLabel(
		d,
		string.format("|cff94a3b8Zone:|r %s   |cff94a3b8Level:|r %s   |cff94a3b8HP:|r |cfff87171%s|r",
			tostring(boss.zone or "Raid"), tostring(boss.level or 63), tostring(boss.health or "Unknown"))
	)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	-- Live Raid Comp vs Required Comp
	local total, tanks, healers, dps = scanLiveRaidComp()
	local req = boss.compositionRequirements or { minTanks = 2, minHealers = 8, minDPS = 20 }
	local compCard = InfinityUIFramework:CreateCard(d, 462, 62, "Live Raid Readiness (" .. tostring(total) .. " in group)")
	compCard:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)

	local tCol = tanks >= (req.minTanks or 2) and "|cff4ade80" or "|cfffbbf24"
	local hCol = healers >= (req.minHealers or 6) and "|cff4ade80" or "|cfffbbf24"
	local dCol = dps >= (req.minDPS or 15) and "|cff4ade80" or "|cfffbbf24"
	local compText = InfinityUIFramework:CreateLabel(
		compCard,
		string.format("Tanks: %s%d/%d|r     Healers: %s%d/%d|r     DPS: %s%d/%d|r",
			tCol, tanks, req.minTanks or 2, hCol, healers, req.minHealers or 6, dCol, dps, req.minDPS or 15)
	)
	compText:SetPoint("TOPLEFT", compCard, "TOPLEFT", 12, -32)

	-- Key Mechanics
	local mechCard = InfinityUIFramework:CreateCard(d, 462, 96, "Key Mechanics")
	mechCard:SetPoint("TOPLEFT", compCard, "BOTTOMLEFT", 0, -10)
	local my = -28
	for i, m in ipairs(boss.mechanics or {}) do
		if i > 4 then break end
		local ml = InfinityUIFramework:CreateLabel(mechCard, "|cfff87171•|r " .. tostring(m))
		ml:SetPoint("TOPLEFT", mechCard, "TOPLEFT", 12, my)
		my = my - 16
	end

	-- Tactics
	local tacCard = InfinityUIFramework:CreateCard(d, 462, 82, "Officer Tactics Summary")
	tacCard:SetPoint("TOPLEFT", mechCard, "BOTTOMLEFT", 0, -10)
	local tacText = InfinityUIFramework:CreateLabel(tacCard, tostring(boss.tactics or "Standard tank-and-spank positioning."))
	tacText:SetPoint("TOPLEFT", tacCard, "TOPLEFT", 12, -28)
	tacText:SetWidth(438)
	tacText:SetWordWrap(true)

	-- Notable Loot
	local lootStr = ""
	for i, item in ipairs(boss.loot or {}) do
		local color = (item.rarity == 5 and "|cffff8000") or (item.rarity == 4 and "|cffa335ee") or "|cff0070dd"
		lootStr = lootStr .. (i > 1 and ", " or "") .. color .. "[" .. tostring(item.name) .. "]|r"
	end
	local lootLbl = InfinityUIFramework:CreateLabel(d, "|cfffbbf24Notable Loot:|r " .. (lootStr ~= "" and lootStr or "See Atlas"))
	lootLbl:SetPoint("TOPLEFT", tacCard, "BOTTOMLEFT", 0, -10)
	lootLbl:SetWidth(462)
	lootLbl:SetWordWrap(true)

	-- Announce button
	local announceBtn = InfinityUIFramework:CreateButton(d, "Announce Tactics to Raid", 174, 26, function()
		local msg = "[InfinityRaid] " .. tostring(boss.name) .. ": " .. tostring(boss.tactics or "")
		if SendChatMessage then
			local channel = (IsInRaid and IsInRaid()) and "RAID" or ((IsInGroup and IsInGroup()) and "PARTY" or "SAY")
			pcall(SendChatMessage, msg, channel)
		end
		InfinityUIFramework:ShowNotification("Announced " .. tostring(boss.name) .. " tactics.", 2.5)
	end, true)
	announceBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)

	local pullBtn = InfinityUIFramework:CreateButton(d, "Start 10s Pull Timer", 148, 26, function()
		if _G.InfinityEncounterTimer and _G.InfinityEncounterTimer.CreateTimer then
			_G.InfinityEncounterTimer:CreateTimer("Pull: " .. tostring(boss.name), 10)
		end
		if _G.InfinityEncounterUI and _G.InfinityEncounterUI.Show then
			_G.InfinityEncounterUI:Show()
		end
		InfinityUIFramework:ShowNotification("10s Pull timer started for " .. tostring(boss.name), 2.5)
	end)
	pullBtn:SetPoint("LEFT", announceBtn, "RIGHT", 10, 0)
end

_G.InfinityRaidUI = InfinityRaidUI
return InfinityRaidUI
