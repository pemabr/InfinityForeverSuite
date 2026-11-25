-- PluribusHive Cooldown Sharing, Cast-Monitoring Estimation & Customizable On-Screen Selection
-- Shares own cooldowns via PLBHIVE and estimates nearby guildmates/party/raid cooldowns
-- via Blizzard-permitted UNIT_SPELLCAST_SUCCEEDED (zero blocked combat log APIs!)
-- Supports per-ability On-Screen selection, scope filtering (Group/Raid vs Guild+Raid vs All), and presets.

PluribusHiveCooldowns = {
	initialized = false,
	tracked = {}, -- [playerName][spellKey] = { player, class, spellID, spellKey, name, category, duration, readyAt, estimated }
}
_G.PluribusHiveCooldowns = PluribusHiveCooldowns

-- Canonical ability catalog (used for the On-Screen Cooldown Selection Menu!)
PluribusHiveCooldowns.CATALOG = {
	-- Battle Rez & Resurrection Saves
	{ key = "Rebirth",              de = "Wiedergeburt",           class = "DRUID",   category = "BREZ",      cd = 1800, defaultOn = true,  ids = { 20484, 20739, 20742, 20747, 20748 } },
	{ key = "Soulstone",            de = "Seelenstein",            class = "WARLOCK", category = "BREZ",      cd = 1800, defaultOn = true,  ids = { 20707, 20762, 20763, 20764, 20765 } },
	{ key = "Reincarnation",        de = "Reinkarnation",          class = "SHAMAN",  category = "BREZ",      cd = 3600, defaultOn = true,  ids = { 20608 } },
	{ key = "Divine Intervention",  de = "Göttliches Eingreifen",  class = "PALADIN", category = "BREZ",      cd = 3600, defaultOn = true,  ids = { 19752 } },
	-- Tank & Defensives
	{ key = "Shield Wall",          de = "Schildwall",             class = "WARRIOR", category = "DEFENSIVE", cd = 1800, defaultOn = true,  ids = { 871 } },
	{ key = "Last Stand",           de = "Letztes Gefecht",        class = "WARRIOR", category = "DEFENSIVE", cd = 600,  defaultOn = true,  ids = { 12975 } },
	{ key = "Challenging Shout",    de = "Herausforderungsruf",    class = "WARRIOR", category = "DEFENSIVE", cd = 600,  defaultOn = true,  ids = { 1161 } },
	{ key = "Challenging Roar",     de = "Herausforderndes Gebrüll", class = "DRUID", category = "DEFENSIVE", cd = 600,  defaultOn = true,  ids = { 5209 } },
	{ key = "Lay on Hands",         de = "Handauflegung",          class = "PALADIN", category = "DEFENSIVE", cd = 3600, defaultOn = true,  ids = { 633, 2800, 10310 } },
	{ key = "Blessing of Protection", de = "Segen des Schutzes",   class = "PALADIN", category = "DEFENSIVE", cd = 300,  defaultOn = true,  ids = { 1022, 5599, 10278 } },
	{ key = "Divine Shield",        de = "Gottesschild",           class = "PALADIN", category = "DEFENSIVE", cd = 300,  defaultOn = false, ids = { 642, 1020 } },
	{ key = "Ice Block",            de = "Eisblock",               class = "MAGE",    category = "DEFENSIVE", cd = 300,  defaultOn = false, ids = { 11958 } },
	{ key = "Vanish",               de = "Verschwinden",           class = "ROGUE",   category = "DEFENSIVE", cd = 300,  defaultOn = false, ids = { 1856, 1857 } },
	{ key = "Feign Death",          de = "Totstellen",             class = "HUNTER",  category = "DEFENSIVE", cd = 30,   defaultOn = false, ids = { 5384 } },
	-- Healer & Utility
	{ key = "Innervate",            de = "Anregen",                class = "DRUID",   category = "UTILITY",   cd = 360,  defaultOn = true,  ids = { 29166 } },
	{ key = "Tranquility",          de = "Gelassenheit",           class = "DRUID",   category = "UTILITY",   cd = 300,  defaultOn = true,  ids = { 740, 8918, 9862, 9863 } },
	{ key = "Power Infusion",       de = "Seele der Macht",        class = "PRIEST",  category = "UTILITY",   cd = 180,  defaultOn = true,  ids = { 10060 } },
	{ key = "Fear Ward",            de = "Furchtzauberschutz",     class = "PRIEST",  category = "UTILITY",   cd = 30,   defaultOn = true,  ids = { 6346 } },
	{ key = "Mana Tide Totem",      de = "Totem der Manaflut",     class = "SHAMAN",  category = "UTILITY",   cd = 300,  defaultOn = true,  ids = { 16190, 17354, 17359 } },
	{ key = "Evocation",            de = "Hervorrufung",           class = "MAGE",    category = "UTILITY",   cd = 480,  defaultOn = false, ids = { 12051 } },
	{ key = "Tranquilizing Shot",   de = "Einlullender Schuss",    class = "HUNTER",  category = "UTILITY",   cd = 20,   defaultOn = true,  ids = { 19801 } },
	-- Raid Offensive
	{ key = "Bloodlust",            de = "Kampfrausch",            class = "SHAMAN",  category = "OFFENSIVE", cd = 600,  defaultOn = true,  ids = { 2825 } },
	{ key = "Heroism",              de = "Heldentum",              class = "SHAMAN",  category = "OFFENSIVE", cd = 600,  defaultOn = true,  ids = { 32182 } },
	{ key = "Death Wish",           de = "Todeswunsch",            class = "WARRIOR", category = "OFFENSIVE", cd = 180,  defaultOn = false, ids = { 12292 } },
	{ key = "Recklessness",         de = "Tollkühnheit",           class = "WARRIOR", category = "OFFENSIVE", cd = 1800, defaultOn = false, ids = { 1719 } },
	{ key = "Arcane Power",         de = "Arkane Macht",           class = "MAGE",    category = "OFFENSIVE", cd = 180,  defaultOn = false, ids = { 12042 } },
	{ key = "Adrenaline Rush",      de = "Adrenalinrausch",        class = "ROGUE",   category = "OFFENSIVE", cd = 300,  defaultOn = false, ids = { 13750 } },
	{ key = "Rapid Fire",           de = "Schnellfeuer",           class = "HUNTER",  category = "OFFENSIVE", cd = 300,  defaultOn = false, ids = { 3045 } },
	-- Interrupts & CC
	{ key = "Counterspell",         de = "Gegenzauber",            class = "MAGE",    category = "INTERRUPT", cd = 30,   defaultOn = false, ids = { 2139 } },
	{ key = "Kick",                 de = "Tritt",                  class = "ROGUE",   category = "INTERRUPT", cd = 10,   defaultOn = false, ids = { 1766 } },
	{ key = "Pummel",               de = "Zuschlagen",             class = "WARRIOR", category = "INTERRUPT", cd = 10,   defaultOn = false, ids = { 6552 } },
	{ key = "Earth Shock",          de = "Erdschock",              class = "SHAMAN",  category = "INTERRUPT", cd = 6,    defaultOn = false, ids = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 } },
	{ key = "Blind",                de = "Blenden",                class = "ROGUE",   category = "INTERRUPT", cd = 300,  defaultOn = false, ids = { 2094 } },
	{ key = "Psychic Scream",       de = "Psychischer Schrei",     class = "PRIEST",  category = "INTERRUPT", cd = 30,   defaultOn = false, ids = { 8122, 8124, 10888, 10890 } },
}

-- Fast spellID -> metadata lookup built automatically from CATALOG
PluribusHiveCooldowns.SPELLS = {}
PluribusHiveCooldowns.BY_KEY = {}
for _, item in ipairs(PluribusHiveCooldowns.CATALOG) do
	PluribusHiveCooldowns.BY_KEY[item.key] = item
	for _, id in ipairs(item.ids) do
		PluribusHiveCooldowns.SPELLS[id] = {
			key = item.key,
			name = item.key,
			de = item.de,
			class = item.class,
			category = item.category,
			cd = item.cd,
		}
	end
end

function PluribusHiveCooldowns:GetDisplayName(item)
	if not item then return "" end
	local lang = (_G.PluribusL and _G.PluribusL.GetLanguage) and _G.PluribusL:GetLanguage() or "enUS"
	if lang == "deDE" and item.de and item.de ~= "" then
		return item.de
	end
	return item.key or item.name or ""
end

function PluribusHiveCooldowns:GetSelectionMap()
	local cfg = (_G.PluribusHive and PluribusHive:GetConfig()) or {}
	if type(cfg.trackedCooldowns) ~= "table" then
		cfg.trackedCooldowns = {}
		for _, item in ipairs(self.CATALOG) do
			cfg.trackedCooldowns[item.key] = item.defaultOn == true
		end
	end
	return cfg.trackedCooldowns
end

function PluribusHiveCooldowns:IsSpellSelected(spellKey)
	if not spellKey then return true end
	local map = self:GetSelectionMap()
	if map[spellKey] == nil then
		local meta = self.BY_KEY[spellKey]
		return meta and (meta.defaultOn == true) or true
	end
	return map[spellKey] == true
end

function PluribusHiveCooldowns:SetSpellSelected(spellKey, enabled)
	if not spellKey then return end
	local map = self:GetSelectionMap()
	map[spellKey] = enabled == true
	if _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

function PluribusHiveCooldowns:ApplyPreset(preset)
	local map = self:GetSelectionMap()
	for _, item in ipairs(self.CATALOG) do
		if preset == "ALL" then
			map[item.key] = true
		elseif preset == "NONE" then
			map[item.key] = false
		elseif preset == "TANK_HEAL" then
			map[item.key] = (item.category == "BREZ" or item.category == "DEFENSIVE" or item.category == "UTILITY")
		else
			-- "RAID" default
			map[item.key] = item.defaultOn == true
		end
	end
	if _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

function PluribusHiveCooldowns:GetScope()
	local cfg = (_G.PluribusHive and PluribusHive:GetConfig()) or {}
	return cfg.cdScope or "ALL" -- "GROUP" | "GUILD" | "ALL"
end

function PluribusHiveCooldowns:SetScope(scope)
	if _G.PluribusHive then
		PluribusHive:SetConfig("cdScope", scope or "ALL")
	end
	if _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

local function IsPlayerInMyGroup(playerName)
	if not playerName or not _G.PluribusHive then return false end
	if PluribusHive:SamePlayer(playerName, PluribusHive:GetPlayerShortName()) then return true end
	if IsInRaid and IsInRaid() then
		local n = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
		for i = 1, n do
			local uName = UnitName("raid" .. i)
			if uName and PluribusHive:SamePlayer(uName, playerName) then return true end
		end
	elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then
		for i = 1, 4 do
			local uName = UnitName("party" .. i)
			if uName and PluribusHive:SamePlayer(uName, playerName) then return true end
		end
	end
	return false
end

function PluribusHiveCooldowns:RecordCooldown(playerName, classFile, spellID, duration, readyAt, estimated)
	if not playerName or not spellID then return end
	local normPlayer = _G.PluribusHive and PluribusHive:NormalizeName(playerName) or playerName
	local meta = self.SPELLS[spellID]
	local spellKey = (meta and meta.key) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or ("Spell #" .. spellID)
	local displayName = meta and self:GetDisplayName(meta) or spellKey
	local cat = (meta and meta.category) or "UTILITY"
	local dur = duration or (meta and meta.cd) or 60
	local finish = readyAt or (time() + dur)

	self.tracked[normPlayer] = self.tracked[normPlayer] or {}
	self.tracked[normPlayer][spellKey] = {
		player = normPlayer,
		class = classFile or (meta and meta.class) or "WARRIOR",
		spellID = spellID,
		spellKey = spellKey,
		name = displayName,
		category = cat,
		duration = dur,
		readyAt = finish,
		estimated = estimated == true,
	}

	if _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

function PluribusHiveCooldowns:TriggerPreviewCooldowns()
	local now = time()
	local me = _G.PluribusHive and PluribusHive:GetPlayerShortName() or "Du"
	self:RecordCooldown(me, "DRUID", 20484, 20, now + 18, false)
	self:RecordCooldown("Tank-Demo", "WARRIOR", 871, 20, now + 14, false)
	self:RecordCooldown("Heiler-Demo", "DRUID", 29166, 20, now + 11, true)
	if _G.PluribusHiveUI then
		_G.PluribusHiveUI.cdPinned = true
		if _G.PluribusHive then PluribusHive:SetConfig("showCooldownOverlay", true) end
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

function PluribusHiveCooldowns:GetActiveCooldowns(ignoreFilter)
	local now = time()
	local scope = self:GetScope()
	local list = {}
	for player, spells in pairs(self.tracked) do
		for spellKey, entry in pairs(spells) do
			local remaining = (entry.readyAt or 0) - now
			if remaining > 0 then
				local allowedSpell = ignoreFilter or self:IsSpellSelected(entry.spellKey or spellKey)
				local allowedScope = ignoreFilter
					or scope == "ALL"
					or (scope == "GROUP" and (IsPlayerInMyGroup(player) or player:find("%-Demo$")))
					or (scope == "GUILD")
				if allowedSpell and allowedScope then
					local meta = self.BY_KEY[entry.spellKey or spellKey]
					table.insert(list, {
						player = player,
						class = entry.class,
						spellID = entry.spellID,
						spellKey = entry.spellKey or spellKey,
						name = meta and self:GetDisplayName(meta) or entry.name,
						category = entry.category,
						duration = entry.duration,
						remaining = remaining,
						estimated = entry.estimated,
					})
				end
			else
				spells[spellKey] = nil
			end
		end
	end
	table.sort(list, function(a, b)
		if a.category ~= b.category then return a.category < b.category end
		return a.remaining < b.remaining
	end)
	return list
end

function PluribusHiveCooldowns:OnUnitSpellCast(unit, spellID)
	if not unit or not spellID or PluribusUtils:IsSecret(spellID) then return end
	local meta = self.SPELLS[spellID]
	if not meta then return end

	if unit == "player" then
		local me = PluribusHive:GetPlayerShortName()
		local cls = PluribusHive:GetPlayerClass()
		local cd = meta.cd
		if PluribusUtils and PluribusUtils.GetSpellCooldown then
			local _, actualDur = PluribusUtils:GetSpellCooldown(spellID)
			if actualDur and not PluribusUtils:IsSecret(actualDur) and actualDur > 2 then
				cd = math.floor(actualDur)
			end
		end
		local readyAt = time() + cd
		self:RecordCooldown(me, cls, spellID, cd, readyAt, false)

		if PluribusHive:GetConfig().shareCooldowns then
			local channel = (IsInRaid and IsInRaid()) and "RAID" or ((IsInGroup and IsInGroup()) and "PARTY" or "GUILD")
			local payload = string.format("%s|%d|%d|%d", cls, spellID, cd, readyAt)
			PluribusHive:Send("CD", payload, channel, nil, true)
			if channel ~= "GUILD" and IsInGuild and IsInGuild() then
				PluribusHive:Send("CD", payload, "GUILD")
			end
		end
		return
	end

	-- Cast-monitoring estimation for party/raid/nearby guildmates (even without the addon!)
	if UnitIsPlayer and UnitIsPlayer(unit) then
		local uName = UnitName(unit)
		if not uName or PluribusUtils:IsSecret(uName) then return end
		local short = PluribusHive:NormalizeName(uName)
		if PluribusHive:SamePlayer(short, PluribusHive:GetPlayerShortName()) then return end
		local _, cls = UnitClass(unit)
		self:RecordCooldown(short, cls or meta.class, spellID, meta.cd, time() + meta.cd, true)
	end
end

function PluribusHiveCooldowns:Initialize()
	if self.initialized then return end
	self.initialized = true

	PluribusHive:RegisterHandler("CD", function(sender, body)
		local cls, spellIDStr, durStr, readyStr = body:match("^([^|]*)|(%d+)|(%d+)|(%d+)$")
		local spellID = tonumber(spellIDStr)
		local dur = tonumber(durStr)
		local readyAt = tonumber(readyStr)
		if spellID and dur and readyAt then
			PluribusHiveCooldowns:RecordCooldown(sender, cls, spellID, dur, readyAt, false)
		end
	end)

	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "UNIT_SPELLCAST_SUCCEEDED")
	f:SetScript("OnEvent", function(_, _, unit, _, spellID)
		PluribusHiveCooldowns:OnUnitSpellCast(unit, spellID)
	end)
end

return PluribusHiveCooldowns
