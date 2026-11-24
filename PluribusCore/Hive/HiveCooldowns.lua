-- PluribusHive Cooldown Sharing & Cast-Monitoring Estimation
-- Shares own cooldowns via PLBHIVE and estimates nearby guildmates/party/raid cooldowns
-- via Blizzard-permitted UNIT_SPELLCAST_SUCCEEDED (zero blocked combat log APIs!)

PluribusHiveCooldowns = {
	initialized = false,
	tracked = {}, -- [playerName][spellID] = { player, class, spellID, name, category, duration, readyAt, estimated }
}
_G.PluribusHiveCooldowns = PluribusHiveCooldowns

-- Major Classic / Warcraft Forever cooldowns across all 9 classes
PluribusHiveCooldowns.SPELLS = {
	-- Battle Rez & Resurrection Saves
	[20484] = { name = "Rebirth", class = "DRUID", category = "BREZ", cd = 1800 },
	[20739] = { name = "Rebirth", class = "DRUID", category = "BREZ", cd = 1800 },
	[20742] = { name = "Rebirth", class = "DRUID", category = "BREZ", cd = 1800 },
	[20747] = { name = "Rebirth", class = "DRUID", category = "BREZ", cd = 1800 },
	[20748] = { name = "Rebirth", class = "DRUID", category = "BREZ", cd = 1800 },
	[20707] = { name = "Soulstone", class = "WARLOCK", category = "BREZ", cd = 1800 },
	[20608] = { name = "Reincarnation", class = "SHAMAN", category = "BREZ", cd = 3600 },
	[19752] = { name = "Divine Intervention", class = "PALADIN", category = "BREZ", cd = 3600 },
	-- External Defensives & Raid Saves
	[871]   = { name = "Shield Wall", class = "WARRIOR", category = "DEFENSIVE", cd = 1800 },
	[12975] = { name = "Last Stand", class = "WARRIOR", category = "DEFENSIVE", cd = 600 },
	[1161]  = { name = "Challenging Shout", class = "WARRIOR", category = "DEFENSIVE", cd = 600 },
	[633]   = { name = "Lay on Hands", class = "PALADIN", category = "DEFENSIVE", cd = 3600 },
	[2800]  = { name = "Lay on Hands", class = "PALADIN", category = "DEFENSIVE", cd = 3600 },
	[10310] = { name = "Lay on Hands", class = "PALADIN", category = "DEFENSIVE", cd = 3600 },
	[1022]  = { name = "Blessing of Protection", class = "PALADIN", category = "DEFENSIVE", cd = 300 },
	[5599]  = { name = "Blessing of Protection", class = "PALADIN", category = "DEFENSIVE", cd = 300 },
	[10278] = { name = "Blessing of Protection", class = "PALADIN", category = "DEFENSIVE", cd = 300 },
	[642]   = { name = "Divine Shield", class = "PALADIN", category = "DEFENSIVE", cd = 300 },
	[11958] = { name = "Ice Block", class = "MAGE", category = "DEFENSIVE", cd = 300 },
	[1856]  = { name = "Vanish", class = "ROGUE", category = "DEFENSIVE", cd = 300 },
	[5384]  = { name = "Feign Death", class = "HUNTER", category = "DEFENSIVE", cd = 30 },
	-- Raid Utility & Mana/Healing CDs
	[29166] = { name = "Innervate", class = "DRUID", category = "UTILITY", cd = 360 },
	[740]   = { name = "Tranquility", class = "DRUID", category = "UTILITY", cd = 300 },
	[6346]  = { name = "Fear Ward", class = "PRIEST", category = "UTILITY", cd = 30 },
	[10060] = { name = "Power Infusion", class = "PRIEST", category = "UTILITY", cd = 180 },
	[16190] = { name = "Mana Tide Totem", class = "SHAMAN", category = "UTILITY", cd = 300 },
	[2825]  = { name = "Bloodlust", class = "SHAMAN", category = "UTILITY", cd = 600 },
	[32182] = { name = "Heroism", class = "SHAMAN", category = "UTILITY", cd = 600 },
	[12051] = { name = "Evocation", class = "MAGE", category = "UTILITY", cd = 480 },
	[19801] = { name = "Tranquilizing Shot", class = "HUNTER", category = "UTILITY", cd = 20 },
	-- Interrupts / CC
	[2139]  = { name = "Counterspell", class = "MAGE", category = "INTERRUPT", cd = 30 },
	[1766]  = { name = "Kick", class = "ROGUE", category = "INTERRUPT", cd = 10 },
	[6552]  = { name = "Pummel", class = "WARRIOR", category = "INTERRUPT", cd = 10 },
	[8042]  = { name = "Earth Shock", class = "SHAMAN", category = "INTERRUPT", cd = 6 },
	[2094]  = { name = "Blind", class = "ROGUE", category = "INTERRUPT", cd = 300 },
}

function PluribusHiveCooldowns:RecordCooldown(playerName, classFile, spellID, duration, readyAt, estimated)
	if not playerName or not spellID then return end
	local meta = self.SPELLS[spellID]
	local spellName = (meta and meta.name) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or ("Spell #" .. spellID)
	local cat = (meta and meta.category) or "UTILITY"
	local dur = duration or (meta and meta.cd) or 60
	local finish = readyAt or (time() + dur)

	self.tracked[playerName] = self.tracked[playerName] or {}
	self.tracked[playerName][spellID] = {
		player = playerName,
		class = classFile or (meta and meta.class) or "WARRIOR",
		spellID = spellID,
		name = spellName,
		category = cat,
		duration = dur,
		readyAt = finish,
		estimated = estimated == true,
	}

	if _G.PluribusHiveUI and _G.PluribusHiveUI.RefreshCooldownOverlay then
		_G.PluribusHiveUI:RefreshCooldownOverlay()
	end
end

function PluribusHiveCooldowns:GetActiveCooldowns()
	local now = time()
	local list = {}
	for player, spells in pairs(self.tracked) do
		for spellID, entry in pairs(spells) do
			local remaining = (entry.readyAt or 0) - now
			if remaining > 0 then
				table.insert(list, {
					player = player,
					class = entry.class,
					spellID = spellID,
					name = entry.name,
					category = entry.category,
					duration = entry.duration,
					remaining = remaining,
					estimated = entry.estimated,
				})
			else
				spells[spellID] = nil
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
		local short = uName:gsub("%-.+$", "")
		if short == PluribusHive:GetPlayerShortName() then return end
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
