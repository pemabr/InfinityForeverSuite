-- PluribusHive Guild Chat @Mention & Smart Sound Ping System
-- Supports @PlayerName, @Profession, @Class, @Race, @Role, and @guild/@all in Guild & Officer chat.
-- Automatically suppresses sounds in combat, dungeons, raids, and battlegrounds — queuing pings
-- to play afterward ONLY if the player has NOT written in guild chat since the mention arrived.

PluribusHiveMentions = {
	initialized = false,
	pendingQueue = {},   -- { { sender, message, tags, timestamp } }
	recentMentions = {}, -- History for Guild Hub display
	lastOwnGuildMsgAt = 0,
	lastSoundPlayedAt = 0,
}
_G.PluribusHiveMentions = PluribusHiveMentions

local CLASS_ALIASES = {
	warrior = "WARRIOR", war = "WARRIOR", warr = "WARRIOR", warriors = "WARRIOR",
	paladin = "PALADIN", pala = "PALADIN", pally = "PALADIN", paladins = "PALADIN",
	hunter = "HUNTER", hunt = "HUNTER", huntard = "HUNTER", hunters = "HUNTER",
	rogue = "ROGUE", rog = "ROGUE", rogues = "ROGUE",
	priest = "PRIEST", priests = "PRIEST",
	shaman = "SHAMAN", sham = "SHAMAN", shammy = "SHAMAN", shamans = "SHAMAN",
	mage = "MAGE", mages = "MAGE",
	warlock = "WARLOCK", lock = "WARLOCK", warlocks = "WARLOCK", locks = "WARLOCK",
	druid = "DRUID", dudu = "DRUID", drood = "DRUID", druids = "DRUID",
}

local RACE_ALIASES = {
	human = "human", humans = "human",
	dwarf = "dwarf", dwarves = "dwarf",
	nightelf = "nightelf", nelf = "nightelf", ne = "nightelf", nightelves = "nightelf",
	gnome = "gnome", gnomes = "gnome",
	orc = "orc", orcs = "orc",
	undead = "scourge", scourge = "scourge", ud = "scourge", forsaken = "scourge",
	tauren = "tauren", taurens = "tauren", cow = "tauren",
	troll = "troll", trolls = "troll",
	highelf = "highelf", bloodelf = "bloodelf", goblin = "goblin",
}

local PROF_ALIASES = {
	alchemy = "alchemy", alch = "alchemy", alchemist = "alchemy", alchemists = "alchemy",
	blacksmithing = "blacksmithing", blacksmith = "blacksmithing", bs = "blacksmithing", smith = "blacksmithing",
	enchanting = "enchanting", ench = "enchanting", enchanter = "enchanting", enchanters = "enchanting",
	engineering = "engineering", eng = "engineering", engi = "engineering", engineer = "engineering", engineers = "engineering",
	herbalism = "herbalism", herb = "herbalism", herbalist = "herbalism", herbs = "herbalism",
	leatherworking = "leatherworking", lw = "leatherworking", leatherworker = "leatherworking",
	mining = "mining", mine = "mining", miner = "mining", miners = "mining",
	skinning = "skinning", skin = "skinning", skinner = "skinning",
	tailoring = "tailoring", tailor = "tailoring", tailors = "tailoring",
	cooking = "cooking", cook = "cooking", chef = "cooking",
	firstaid = "firstaid", fa = "firstaid",
	fishing = "fishing", fish = "fishing", angler = "fishing",
}

local ROLE_ALIASES = {
	tank = "TANK", tanks = "TANK",
	healer = "HEALER", healers = "HEALER", heal = "HEALER", heals = "HEALER",
	dps = "DPS",
}

local BROADCAST_ALIASES = {
	guild = true, all = true, everyone = true, here = true,
}

local function CleanToken(raw)
	if not raw then return "" end
	return tostring(raw):lower():gsub("[^%w]", "")
end

function PluribusHiveMentions:GetPlayerProfile()
	local myName = PluribusHive and PluribusHive:GetPlayerShortName() or (UnitName and UnitName("player") or "")
	local myClass = PluribusHive and PluribusHive:GetPlayerClass() or "WARRIOR"
	local myRole = PluribusHive and PluribusHive:GetPlayerRole() or "DPS"

	local raceLoc, raceEn = "", ""
	if UnitRace then
		local r1, r2 = UnitRace("player")
		raceLoc = CleanToken(r1)
		raceEn = CleanToken(r2)
	end

	local profSet = {}
	if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.GetMyProfessions then
		local myProfs = _G.PluribusHiveProfessions:GetMyProfessions() or {}
		for _, p in ipairs(myProfs) do
			local pn = CleanToken(p.name)
			if pn ~= "" then
				profSet[pn] = true
				local mapped = PROF_ALIASES[pn]
				if mapped then profSet[mapped] = true end
			end
		end
	end

	return {
		name = CleanToken(myName),
		class = tostring(myClass):upper(),
		role = tostring(myRole):upper(),
		raceLoc = raceLoc,
		raceEn = raceEn,
		professions = profSet,
	}
end

function PluribusHiveMentions:ExtractTokens(message)
	local tokens = {}
	local seen = {}
	for raw in tostring(message or ""):gmatch("@([%w%-_']+)") do
		local tok = CleanToken(raw)
		if tok ~= "" and not seen[tok] then
			seen[tok] = true
			table.insert(tokens, { raw = "@" .. raw, clean = tok })
		end
	end
	return tokens
end

function PluribusHiveMentions:MatchMessageForPlayer(message, profile)
	profile = profile or self:GetPlayerProfile()
	local tokens = self:ExtractTokens(message)
	local matched = {}

	for _, t in ipairs(tokens) do
		local tok = t.clean
		if tok == profile.name and profile.name ~= "" then
			table.insert(matched, t.raw)
		elseif BROADCAST_ALIASES[tok] then
			table.insert(matched, t.raw)
		elseif CLASS_ALIASES[tok] and CLASS_ALIASES[tok] == profile.class then
			table.insert(matched, t.raw)
		elseif ROLE_ALIASES[tok] and ROLE_ALIASES[tok] == profile.role then
			table.insert(matched, t.raw)
		elseif RACE_ALIASES[tok] and (RACE_ALIASES[tok] == profile.raceEn or RACE_ALIASES[tok] == profile.raceLoc or tok == profile.raceLoc) then
			table.insert(matched, t.raw)
		elseif (tok == profile.raceEn or tok == profile.raceLoc) and tok ~= "" then
			table.insert(matched, t.raw)
		else
			local profKey = PROF_ALIASES[tok] or tok
			if profile.professions and (profile.professions[profKey] or profile.professions[tok]) then
				table.insert(matched, t.raw)
			end
		end
	end

	return matched
end

-- True when in combat, dungeon, raid, arena, or battleground (suppress sound & queue instead)
function PluribusHiveMentions:IsSuppressedContext()
	if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
		return true, "combat"
	end
	if IsInInstance then
		local inInst, instType = IsInInstance()
		if inInst and instType ~= "none" then
			return true, instType or "instance"
		end
	end
	return false, nil
end

function PluribusHiveMentions:PlayPingSound()
	local cfg = PluribusHive and PluribusHive:GetConfig() or {}
	if cfg.mentionSoundEnabled == false then return end

	local now = GetTime and GetTime() or 0
	if (now - (self.lastSoundPlayedAt or 0)) < 1.5 then return end
	self.lastSoundPlayedAt = now

	local played = false
	if PlaySound then
		if SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
			played = pcall(PlaySound, SOUNDKIT.TELL_MESSAGE, "Master")
		elseif SOUNDKIT and SOUNDKIT.READY_CHECK then
			played = pcall(PlaySound, SOUNDKIT.READY_CHECK, "Master")
		else
			played = pcall(PlaySound, 3081, "Master")
		end
	end
	if not played and PlaySoundFile then
		pcall(PlaySoundFile, "Sound\\Interface\\iTellMessage.ogg", "Master")
	end
end

function PluribusHiveMentions:DeliverNotification(entries, wasQueued)
	if not entries or #entries == 0 then return end
	self:PlayPingSound()

	local latest = entries[#entries]
	local tagStr = table.concat(latest.tags or {}, " ")
	local prefix = wasQueued and "|cfffbbf24[Queued @Mention]|r " or "|cfffbbf24[@Mention]|r "
	local summary
	if #entries == 1 then
		summary = string.format("%s|cff38bdf8%s|r (%s): %s", prefix, tostring(latest.sender), tagStr, tostring(latest.message):sub(1, 70))
	else
		summary = string.format("%s%d guild mentions while busy — latest from |cff38bdf8%s|r (%s)", prefix, #entries, tostring(latest.sender), tagStr)
	end

	if _G.PluribusUIFramework and _G.PluribusUIFramework.ShowNotification then
		_G.PluribusUIFramework:ShowNotification(summary, 5.0)
	end
	if _G.PluribusUtils and _G.PluribusUtils.Info then
		_G.PluribusUtils:Info(summary, "Mention")
	end
end

-- Called when leaving combat or exiting an instance/raid
function PluribusHiveMentions:FlushPendingQueue()
	if #self.pendingQueue == 0 then return end
	if self:IsSuppressedContext() then return end

	-- Only deliver mentions that arrived AFTER the player's last guild chat message!
	local surviving = {}
	for _, entry in ipairs(self.pendingQueue) do
		if (entry.timestamp or 0) > (self.lastOwnGuildMsgAt or 0) then
			table.insert(surviving, entry)
		end
	end
	self.pendingQueue = {}

	if #surviving > 0 then
		self:DeliverNotification(surviving, true)
	end
end

function PluribusHiveMentions:HandleGuildChat(message, sender)
	local cfg = PluribusHive and PluribusHive:GetConfig() or {}
	if cfg.mentionsEnabled == false then return end

	local senderShort = PluribusHive and PluribusHive:NormalizeName(sender) or tostring(sender or "")
	local me = PluribusHive and PluribusHive:GetPlayerShortName() or ""
	local now = time()

	-- If YOU wrote in guild chat, mark timestamp so any older queued mentions are NOT played!
	if PluribusHive and PluribusHive:SamePlayer(senderShort, me) then
		self.lastOwnGuildMsgAt = now
		-- Immediately prune any queued mentions older than/equal to now
		for i = #self.pendingQueue, 1, -1 do
			if (self.pendingQueue[i].timestamp or 0) <= now then
				table.remove(self.pendingQueue, i)
			end
		end
		return
	end

	if not message or not message:find("@", 1, true) then return end

	local matchedTags = self:MatchMessageForPlayer(message)
	if #matchedTags == 0 then return end

	local entry = {
		sender = senderShort,
		message = message,
		tags = matchedTags,
		timestamp = now,
	}

	table.insert(self.recentMentions, 1, entry)
	while #self.recentMentions > 25 do
		table.remove(self.recentMentions)
	end

	if PluribusHive and PluribusHive.AddFeedEvent then
		PluribusHive:AddFeedEvent("PING", string.format("%s mentioned %s: %s", senderShort, table.concat(matchedTags, " "), message:sub(1, 36)))
	end

	local suppressed = self:IsSuppressedContext()
	if suppressed then
		table.insert(self.pendingQueue, entry)
		while #self.pendingQueue > 15 do
			table.remove(self.pendingQueue, 1)
		end
	else
		self:DeliverNotification({ entry }, false)
	end
end

function PluribusHiveMentions:Initialize()
	if self.initialized then return end
	self.initialized = true

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER",
		"PLAYER_REGEN_ENABLED",
		"ZONE_CHANGED_NEW_AREA",
		"PLAYER_ENTERING_WORLD",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" then
			PluribusHiveMentions:HandleGuildChat(arg1, arg2)
		elseif event == "PLAYER_REGEN_ENABLED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
			if C_Timer and C_Timer.After then
				C_Timer.After(1.2, function()
					PluribusHiveMentions:FlushPendingQueue()
				end)
			else
				PluribusHiveMentions:FlushPendingQueue()
			end
		end
	end)

	-- Subtle taint-safe chat highlight for @mentions matching you in Guild/Officer chat
	if ChatFrame_AddMessageEventFilter then
		local function MentionFilter(_, _, msg, author, ...)
			if type(msg) == "string" and msg:find("@", 1, true) then
				local senderShort = PluribusHive and PluribusHive:NormalizeName(author) or ""
				local me = PluribusHive and PluribusHive:GetPlayerShortName() or ""
				if not (PluribusHive and PluribusHive:SamePlayer(senderShort, me)) then
					local tags = PluribusHiveMentions:MatchMessageForPlayer(msg)
					if #tags > 0 then
						local highlighted = msg
						for _, tg in ipairs(tags) do
							local esc = tg:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
							highlighted = highlighted:gsub(esc, "|cfffbbf24" .. tg .. "|r")
						end
						return false, highlighted, author, ...
					end
				end
			end
			return false, msg, author, ...
		end
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_GUILD", MentionFilter)
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_OFFICER", MentionFilter)
	end
end

return PluribusHiveMentions
