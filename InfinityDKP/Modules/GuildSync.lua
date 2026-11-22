local GuildSync = {
	prefix = "InfinityDKP1",
	maxPlayers = 1000,
	sequence = 0,
}
_G.InfinityDKPGuildSync = GuildSync

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Realm()
	local realm = _G.GetNormalizedRealmName and Public(_G.GetNormalizedRealmName())
	if type(realm) ~= "string" or realm == "" then
		realm = _G.GetRealmName and Public(_G.GetRealmName())
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return realm:gsub("%s+", ""):lower()
end

local function FullName(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" then return nil end
	local name, realm = value:match("^([^%-]+)%-(.+)$")
	if not name then name, realm = value, Realm() end
	if not realm or name == "" or realm == "" then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function GuildKey()
	if not _G.IsInGuild or not Public(_G.IsInGuild()) or not _G.GetGuildInfo then return nil end
	local guild, _, _, realm = _G.GetGuildInfo("player")
	guild, realm = Public(guild), Public(realm)
	if type(guild) ~= "string" or guild == "" then return nil end
	if type(realm) ~= "string" or realm == "" then realm = Realm() end
	if not realm then return nil end
	return guild:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function LocalGuildMaster()
	if not GuildKey() then return false end
	local _, _, rank = _G.GetGuildInfo("player")
	return Public(rank) == 0
end

local function GuildMaster(sender)
	local target = FullName(sender)
	if not target or not GuildKey() or not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then return false end
	local count = Public(_G.GetNumGuildMembers())
	if type(count) ~= "number" or count ~= count or count < 0 or count > 10000
		or count ~= math.floor(count) then return false end
	for index = 1, count do
		local name, _, rank = _G.GetGuildRosterInfo(index)
		name, rank = Public(name), Public(rank)
		if name and FullName(name) == target then return rank == 0 end
	end
	return false
end

function GuildSync:GetGuildKey() return GuildKey() end
function GuildSync:GetFullName(value) return FullName(value) end
function GuildSync:IsLocalGuildMaster() return LocalGuildMaster() end
function GuildSync:IsGuildMaster(sender) return GuildMaster(sender) end

function GuildSync:IsLocalGuildAdministrator()
	if type(_G.GetGuildInfo) ~= "function" then return false end
	local guild, _, rank = _G.GetGuildInfo("player")
	local rankProtected = _G.issecretvalue and _G.issecretvalue(rank)
	guild, rank = Public(guild), Public(rank)
	if type(guild) ~= "string" or guild == "" then return false end
	local leader = type(_G.IsGuildLeader) == "function" and _G.IsGuildLeader()
	local leaderProtected = _G.issecretvalue and _G.issecretvalue(leader)
	leader = Public(leader)
	if leader == true or (type(rank) == "number" and (rank == 0 or rank == 1)) then return true end
	if rankProtected or leaderProtected then return false end
	local name = type(_G.UnitName) == "function" and Public(_G.UnitName("player"))
	local roster = _G.InfinityGuildRoster
	local members = type(roster) == "table" and Public(roster.members)
	local member = type(members) == "table" and type(name) == "string" and Public(members[name])
	local memberRank = type(member) == "table" and Public(member.rank)
	if memberRank == "Guild Master" or memberRank == "Officer" then return true end
	local access = _G.InfinityLootAccessControl
	if type(access) == "table" and type(access.GetPlayerRole) == "function" and type(name) == "string" then
		local role = Public(access:GetPlayerRole(name))
		if role == "admin" then return true end
	end
	return false
end

function GuildSync:IsGuildMember(sender)
	local target = FullName(sender)
	if not target or not GuildKey() or not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then return false end
	local count = Public(_G.GetNumGuildMembers())
	if type(count) ~= "number" or count ~= count or count < 0 or count > 10000
		or count ~= math.floor(count) then return false end
	for index = 1, count do
		local name = Public(_G.GetGuildRosterInfo(index))
		if FullName(name) == target then return true end
	end
	return false
end

function GuildSync:MarkSnapshotsStale(reason)
	local changed = false
	if self.incoming and not self.incoming.stale then self.incoming.stale, changed = true, true end
	if self.pending and not self.pending.stale then self.pending.stale, changed = true, true end
	local engine = _G.InfinityDKPEngine
	local backup = engine and type(engine.db) == "table" and engine.db.syncBackup
	if _G.issecretvalue and (issecretvalue(backup) or (type(backup) == "table" and issecretvalue(backup.stale))) then
		InfinityUtils:Warning("Sync undo state is protected and cannot be updated.", "DKP Sync")
	elseif type(backup) == "table" and not backup.stale then
		backup.stale, changed = true, true
	end
	if changed then
		InfinityUtils:Warning((reason or "A guild trade was finalized")
			.. "; older snapshots or the sync undo may no longer be valid.", "DKP Sync")
	end
end

local function SafeField(value, maxLength)
	return type(value) == "string" and value ~= "" and #value <= maxLength
		and not value:find("[%z\1-\31~|]")
end

local function Finite(value, allowNegative)
	return type(value) == "number" and value == value and value < math.huge
		and value > -math.huge and (allowNegative or value >= 0)
end

local function ValidSystem(value)
	return value == "epgp" or value == "dkp" or value == "sk" or value == "zero"
end

function GuildSync:Initialize()
	if self.initialized then return end
	self.initialized = true
	if not (_G.C_ChatInfo and _G.C_ChatInfo.RegisterAddonMessagePrefix and _G.C_ChatInfo.SendAddonMessage) then
		return
	end
	local ok, result = pcall(_G.C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and _G.issecretvalue(result)
	result = Public(result)
	local duplicate = _G.Enum and _G.Enum.RegisterAddonMessagePrefixResult
		and _G.Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register DKP guild messages: " .. (protected and "protected result" or tostring(result)), "DKP Sync")
		return
	end
	self.available = true
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			self:OnMessage(...)
		elseif _G.C_GuildInfo and _G.C_GuildInfo.GuildRoster and GuildKey() then
			_G.C_GuildInfo.GuildRoster()
		end
	end)
	self.frame = frame
	if _G.C_GuildInfo and _G.C_GuildInfo.GuildRoster and GuildKey() then
		_G.C_GuildInfo.GuildRoster()
	end
end

function GuildSync:Send()
	if not self.available or not (_G.C_Timer and _G.C_Timer.After) then
		InfinityUtils:Warning("Guild sync is unavailable on this client.", "DKP Sync")
		return false
	end
	if not LocalGuildMaster() then
		InfinityUtils:Warning("Only the guild master can send a DKP snapshot.", "DKP Sync")
		return false
	end
	if self.outgoing then
		InfinityUtils:Warning("A DKP snapshot is already being sent.", "DKP Sync")
		return false
	end
	local engine = InfinityDKPEngine
	if not ValidSystem(engine.system_type) then
		InfinityUtils:Warning("Invalid local DKP system.", "DKP Sync")
		return false
	end
	local names = {}
	for name in pairs(engine.players) do names[#names + 1] = name end
	if #names == 0 or #names > self.maxPlayers then
		InfinityUtils:Warning("Cannot send an empty or oversized DKP snapshot.", "DKP Sync")
		return false
	end
	local seen = {}
	for _, name in ipairs(names) do
		local nameKey = FullName(name)
		if not SafeField(name, 80) or not nameKey or seen[nameKey] then
			InfinityUtils:Warning("A player name cannot be sent safely.", "DKP Sync")
			return false
		end
		seen[nameKey] = true
	end
	table.sort(names)
	self.sequence = self.sequence + 1
	local token = tostring(math.floor(GetTime() * 1000)) .. "-" .. self.sequence
	local messages = { "B~" .. token .. "~" .. #names .. "~" .. engine.system_type }
	for index, name in ipairs(names) do
		local player = engine.players[name]
		local wireName = name:find("-", 1, true) and name or (name .. "-" .. Realm())
		if type(player) ~= "table" then
			InfinityUtils:Warning("Invalid local player data: " .. name, "DKP Sync")
			return false
		end
		local class = player.class
		local ep, gp, dkp, position = player.ep, player.gp, player.dkp, player.sk_position
		if class == nil then class = "UNKNOWN" end
		if ep == nil then ep = 0 end
		if gp == nil then gp = 0 end
		if dkp == nil then dkp = 0 end
		if position == nil then position = 999 end
		if not SafeField(wireName, 80) or not SafeField(class, 32) or not Finite(ep) or not Finite(gp) or not Finite(dkp, true)
			or not Finite(position) or position ~= math.floor(position) then
			InfinityUtils:Warning("Invalid local point data: " .. name, "DKP Sync")
			return false
		end
		local message = string.format("P~%s~%d~%s~%s~%.17g~%.17g~%.17g~%.17g",
			token, index, wireName, class, ep, gp, dkp, position)
		if #message > 240 then
			InfinityUtils:Warning("DKP snapshot entry is too long: " .. name, "DKP Sync")
			return false
		end
		messages[#messages + 1] = message
	end
	messages[#messages + 1] = "E~" .. token .. "~" .. #names
	self.outgoing = { messages = messages, index = 1, retries = 0, guild = GuildKey() }
	print("Sending " .. #names .. " local DKP players to the guild.")
	self:SendNext()
	return true
end

function GuildSync:SendNext()
	local queue = self.outgoing
	if not queue then return end
	if GuildKey() ~= queue.guild or not LocalGuildMaster() then
		self.outgoing = nil
		InfinityUtils:Warning("DKP snapshot stopped: guild or permission changed.", "DKP Sync")
		return
	end
	local ok, result = pcall(_G.C_ChatInfo.SendAddonMessage, self.prefix, queue.messages[queue.index], "GUILD")
	local protected = _G.issecretvalue and _G.issecretvalue(result)
	result = Public(result)
	if ok and not protected and (result == nil or result == true or result == 0) then
		queue.index, queue.retries = queue.index + 1, 0
		if queue.index > #queue.messages then
			self.outgoing = nil
			print("DKP snapshot sent; members must apply it explicitly.")
			return
		end
		_G.C_Timer.After(0.2, function() self:SendNext() end)
		return
	end
	local results = _G.Enum and _G.Enum.SendAddonMessageResult
	local throttled = not protected and (result == 3 or result == 8
		or (results and (result == results.AddonMessageThrottle or result == results.ChannelThrottle))
	)
	if ok and throttled and queue.retries < 5 then
		queue.retries = queue.retries + 1
		_G.C_Timer.After(2, function() self:SendNext() end)
		return
	end
	self.outgoing = nil
	InfinityUtils:Warning("DKP snapshot failed to send: " .. (protected and "protected result" or tostring(result)), "DKP Sync")
end

function GuildSync:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if prefix ~= self.prefix or channel ~= "GUILD" or type(message) ~= "string" or #message > 240
		or not GuildKey() then return end
	local me = _G.UnitName and Public(_G.UnitName("player"))
	if FullName(sender) == FullName(me) then return end
	local senderKey, guild = FullName(sender), GuildKey()
	local token, count, system = message:match("^B~([%d%-]+)~(%d+)~(%a+)$")
	if token then
		count = tonumber(count)
		if self.pending or not count or count < 1 or count > self.maxPlayers
			or not ValidSystem(system) or not GuildMaster(sender) then return end
		local incoming = { sender = sender, senderKey = senderKey, guild = guild, token = token,
			count = count, system = system, nextIndex = 1, players = {}, seen = {} }
		self.incoming = incoming
		if _G.C_Timer and _G.C_Timer.After then
			_G.C_Timer.After(math.max(60, count * 2 + 30), function()
				if self.incoming == incoming then
					self.incoming = nil
					InfinityUtils:Warning("DKP snapshot timed out before completion.", "DKP Sync")
				end
			end)
		end
		return
	end
	local incoming = self.incoming
	if not incoming or incoming.senderKey ~= senderKey or incoming.guild ~= guild then return end
	local index, name, class, ep, gp, dkp, position
	token, index, name, class, ep, gp, dkp, position =
		message:match("^P~([%d%-]+)~(%d+)~([^~]+)~([^~]+)~([^~]+)~([^~]+)~([^~]+)~([^~]+)$")
	if token then
		index, ep, gp, dkp, position = tonumber(index), tonumber(ep), tonumber(gp), tonumber(dkp), tonumber(position)
		local nameKey = FullName(name)
		if token ~= incoming.token or index ~= incoming.nextIndex or index > incoming.count
			or not SafeField(name, 80) or not nameKey or incoming.seen[nameKey] or not SafeField(class, 32)
			or not Finite(ep) or not Finite(gp) or not Finite(dkp, true)
			or not Finite(position) or position ~= math.floor(position) then
			self.incoming = nil
			InfinityUtils:Warning("Invalid or incomplete DKP snapshot received.", "DKP Sync")
			return
		end
		local shortName, playerRealm = name:match("^([^%-]+)%-(.+)$")
		local localName = shortName and playerRealm:gsub("%s+", ""):lower() == Realm() and shortName or name
		incoming.players[localName] = {
			name = localName, class = class, ep = ep, gp = gp, dkp = dkp, sk_position = position,
		}
		incoming.seen[nameKey] = true
		incoming.nextIndex = incoming.nextIndex + 1
		return
	end
	token, count = message:match("^E~([%d%-]+)~(%d+)$")
	if not token then return end
	self.incoming = nil
	if token ~= incoming.token or tonumber(count) ~= incoming.count or incoming.nextIndex ~= incoming.count + 1
		or not GuildMaster(sender) then
		InfinityUtils:Warning("Incomplete DKP snapshot received.", "DKP Sync")
		return
	end
	self.pending = incoming
	print("DKP snapshot from " .. sender .. ": " .. incoming.count .. " players (" .. incoming.system
		.. "). /dkp sync apply replaces local points; /dkp sync discard ignores it.")
end

function GuildSync:Apply()
	local pending = self.pending
	if not pending then
		InfinityUtils:Warning("No DKP snapshot is waiting.", "DKP Sync")
		return false
	end
	if pending.stale then
		InfinityUtils:Warning("This DKP snapshot predates local point changes; discard it and request a new one.", "DKP Sync")
		return false
	end
	if GuildKey() ~= pending.guild or not GuildMaster(pending.sender) then
		self.pending = nil
		InfinityUtils:Warning("DKP snapshot discarded: guild or sender permissions changed.", "DKP Sync")
		return false
	end
	local engine, now = InfinityDKPEngine, time()
	local oldPlayers = {}
	for name, player in pairs(engine.players) do
		local key = FullName(name)
		if key then oldPlayers[key] = player end
	end
	for name, player in pairs(pending.players) do
		local old = oldPlayers[FullName(name)]
		player.rank = type(old) == "table" and old.rank or 1
		player.join_date = type(old) == "table" and old.join_date or now
		player.last_seen = now
		player.notes = type(old) == "table" and old.notes or ""
	end
	engine.db.syncBackup = { players = engine.players, system_type = engine.system_type }
	engine.db.players, engine.db.system_type = pending.players, pending.system
	engine.players, engine.system_type = engine.db.players, engine.db.system_type
	self.pending = nil
	if _G.InfinityDKPUI then _G.InfinityDKPUI:Update() end
	print("DKP snapshot applied. /dkp sync undo restores the previous local points.")
	return true
end

function GuildSync:Undo()
	local engine = InfinityDKPEngine
	local backup = engine.db.syncBackup
	if (_G.issecretvalue and (issecretvalue(backup) or (type(backup) == "table"
		and (issecretvalue(backup.players) or issecretvalue(backup.system_type)))))
		or type(backup) ~= "table" or type(backup.players) ~= "table" or not ValidSystem(backup.system_type) then
		InfinityUtils:Warning("No valid DKP sync backup exists.", "DKP Sync")
		return false
	end
	if (_G.issecretvalue and issecretvalue(backup.stale)) or backup.stale then
		InfinityUtils:Warning("Cannot undo: local points changed after the snapshot was applied.", "DKP Sync")
		return false
	end
	engine.db.players, engine.db.system_type = backup.players, backup.system_type
	engine.players, engine.system_type = engine.db.players, engine.db.system_type
	engine.db.syncBackup = nil
	if _G.InfinityDKPUI then _G.InfinityDKPUI:Update() end
	print("Previous local DKP points restored.")
	return true
end

function GuildSync:Discard()
	if not self.pending then
		InfinityUtils:Warning("No DKP snapshot is waiting.", "DKP Sync")
		return false
	end
	self.pending = nil
	print("Pending DKP snapshot discarded.")
	return true
end

return GuildSync
