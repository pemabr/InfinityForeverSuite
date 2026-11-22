local Knowledge = { prefix = "InfinityKnow1", sequence = 0, queue = {}, maxRecords = 10000 }
_G.InfinityGuildKnowledge = Knowledge

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Field(value)
	value = Public(value)
	return type(value) == "string" and #value <= 75 and value:match("%S")
		and not value:find("[%z\1-\31~|]")
end

local function FullName(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" then return nil end
	local name, realm = value:match("^([^%-]+)%-(.+)$")
	if not name then
		name = value
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function GuildKey()
	if not _G.IsInGuild or not Public(IsInGuild()) or not _G.GetGuildInfo then return nil end
	local name, _, _, realm = GetGuildInfo("player")
	name, realm = Public(name), Public(realm)
	if type(name) ~= "string" or name == "" then return nil end
	if type(realm) ~= "string" or realm == "" then
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function Roster()
	if not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then return nil end
	local count = Public(GetNumGuildMembers())
	if not Integer(count, 10000, true) then return nil end
	local members, online = {}, {}
	local me = _G.UnitName and FullName(UnitName("player"))
	if not me then return nil end
	for index = 1, count do
		local name, _, _, _, _, _, _, _, connected = GetGuildRosterInfo(index)
		name, connected = Public(name), Public(connected)
		local key = FullName(name)
		if key then
			members[key] = name
			if connected and key ~= me then online[#online + 1] = { key = key, name = name } end
		end
	end
	table.sort(online, function(a, b) return a.key < b.key end)
	return members, online
end

local function Valid(record)
	record = Public(record)
	if type(record) ~= "table" then return false end
	local kind = Public(record.kind)
	if kind == "Q" then
		return Integer(record.id, 1000000000) and Integer(record.level, 1000, true) and Field(record.name)
	elseif kind == "D" then
		local rarity = Public(record.rarity)
		return Integer(record.mob, 1000000000) and Integer(record.item, 1000000000)
			and Field(record.mobName) and Field(record.itemName)
			and not (_G.issecretvalue and issecretvalue(record.rarity))
			and (rarity == nil or Integer(rarity, 10, true))
	end
	return false
end

local function Key(record)
	if record.kind == "Q" then return "Q:" .. record.id end
	return "D:" .. record.mob .. ":" .. record.item
end

local function Parts(record)
	if record.kind == "Q" then return { record.id, record.level, record.name } end
	return { record.mob, record.item, record.rarity == nil and "u" or record.rarity, record.mobName, record.itemName }
end

local function Payload(prefix, record)
	local parts = { prefix }
	for _, value in ipairs(Parts(record)) do parts[#parts + 1] = tostring(value) end
	return table.concat(parts, "~")
end

local function Parse(kind, body)
	if kind == "Q" then
		local id, level, name = body:match("^(%d+)~(%d+)~([^~]+)$")
		local record = { kind = kind, id = tonumber(id), level = tonumber(level), name = name }
		if Valid(record) then return record end
	elseif kind == "D" then
		local mob, item, rarity, mobName, itemName = body:match("^(%d+)~(%d+)~([%du]+)~([^~]+)~([^~]+)$")
		if not mob then return nil end
		local record = { kind = kind, mob = tonumber(mob), item = tonumber(item),
			rarity = rarity ~= "u" and tonumber(rarity) or nil, mobName = mobName, itemName = itemName }
		if rarity ~= "u" and record.rarity == nil then return nil end
		if Valid(record) then return record end
	end
end

function Knowledge:Valid(record) return Valid(record) end
function Knowledge:Key(record) return Key(record) end
function Knowledge:Payload(prefix, record) return Payload(prefix, record) end
function Knowledge:Parse(kind, body) return Parse(kind, body) end

function Knowledge:Copy(record, revision)
	return { kind = record.kind, id = record.id, level = record.level, name = record.name,
		mob = record.mob, item = record.item, rarity = record.rarity, mobName = record.mobName,
		itemName = record.itemName, revision = revision }
end

function Knowledge:Merge(previous, record)
	if record.kind == "Q" and previous.level == 0 and record.level > 0 then
		return { kind = "Q", id = previous.id, name = previous.name, level = record.level }
	elseif record.kind == "D" and previous.rarity == nil and record.rarity ~= nil then
		return { kind = "D", mob = previous.mob, item = previous.item, mobName = previous.mobName,
			itemName = previous.itemName, rarity = record.rarity }
	end
end

function Knowledge:Apply(copy)
	local core = InfinityDataCollectorCore
	if copy.kind == "Q" and not core.gatheredData.quests[copy.id] then
		core:RecordQuestData(copy.id, copy.name, copy.level, nil, nil, nil, nil, nil, nil)
	elseif copy.kind == "Q" then
		local quest = Public(core.gatheredData.quests[copy.id])
		if type(quest) == "table" and Public(quest.level) == 0 and copy.level > 0 then quest.level = copy.level end
	elseif copy.kind == "D" and not core.gatheredData.drops[copy.mob .. "_" .. copy.item] then
		core:RecordDropData(copy.mob, copy.mobName, copy.item, copy.itemName, nil, copy.rarity)
	elseif copy.kind == "D" then
		local drop = Public(core.gatheredData.drops[copy.mob .. "_" .. copy.item])
		if type(drop) == "table" and not (_G.issecretvalue and issecretvalue(drop.rarity))
			and drop.rarity == nil and copy.rarity ~= nil then drop.rarity = copy.rarity end
	end
end

function Knowledge:PublishCurrent()
	local hooks = _G.InfinityDataCollectorHooks
	local cached = type(hooks) == "table" and Public(hooks.questCache)
	if type(cached) == "table" then
		for id, quest in pairs(cached) do
			quest = Public(quest)
			if type(quest) == "table" then self:ObserveQuest(id, quest.name, quest.level) end
		end
	end
end

function Knowledge:Initialize()
	if self.initialized then return end
	local root = InfinityDataCollectorCore.db
	local storageKey = self.storageKey or "guildKnowledge"
	if root[storageKey] == nil then root[storageKey] = { enabled = false, guilds = {} } end
	local db = Public(root[storageKey])
	if type(db) ~= "table" or type(Public(db.enabled)) ~= "boolean" or type(Public(db.guilds)) ~= "table"
		or (_G.issecretvalue and issecretvalue(db.enabledGuild))
		or (db.enabledGuild ~= nil and type(db.enabledGuild) ~= "string")
		or (db.enabled and not db.enabledGuild) then
		InfinityUtils:Warning("Invalid guild knowledge settings.", "Knowledge")
		return
	end
	self.db, self.initialized = db, true
	if not (_G.C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage
		and _G.C_Timer and C_Timer.After and _G.GetTime and _G.time) then
		InfinityUtils:Warning("Live guild knowledge is unavailable.", "Knowledge")
		return
	end
	local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and issecretvalue(result)
	local duplicate = _G.Enum and Enum.RegisterAddonMessagePrefixResult
		and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register live guild knowledge.", "Knowledge")
		return
	end
	self.available = true
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("GUILD_ROSTER_UPDATE")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then self:OnMessage(...)
		else
			self.roster, self.rosterGuild = nil, nil
			if event == "PLAYER_ENTERING_WORLD" and db.enabled and _G.C_GuildInfo and C_GuildInfo.GuildRoster then
				C_GuildInfo.GuildRoster()
			end
			self:Schedule(10)
		end
	end)
	self.events = frame
	if db.enabled then self:Schedule(10) end
end

function Knowledge:State()
	if not self.available or not self.db.enabled then return nil end
	local guild = GuildKey()
	if not guild then return nil end
	if guild ~= self.db.enabledGuild then
		self:SetEnabled(false)
		InfinityUtils:Warning("Guild changed; live guild knowledge was disabled.", "Knowledge")
		return nil
	end
	if _G.issecretvalue and issecretvalue(self.db.guilds[guild]) then
		self:SetEnabled(false)
		InfinityUtils:Warning("Invalid saved guild knowledge; live sharing disabled.", "Knowledge")
		return nil
	end
	local state = Public(self.db.guilds[guild])
	if state == nil then
		local clock, uptime = Public(time()), Public(GetTime())
		if not Integer(clock, 100000000000) or type(uptime) ~= "number" or uptime ~= uptime or uptime < 0 or uptime >= math.huge then
			self:SetEnabled(false)
			InfinityUtils:Warning("Guild knowledge clock unavailable; live sharing disabled.", "Knowledge")
			return nil
		end
		state = { epoch = clock .. "-" .. math.floor(uptime * 1000), revision = 0, count = 0, records = {}, cursors = {} }
		self.db.guilds[guild] = state
	elseif type(state) ~= "table" or type(Public(state.epoch)) ~= "string"
		or not state.epoch:match("^%d+%-%d+$") or #state.epoch > 32
		or not Integer(state.revision, 1000000000, true) or not Integer(state.count, self.maxRecords, true)
		or type(Public(state.records)) ~= "table" or type(Public(state.cursors)) ~= "table" then
		self:SetEnabled(false)
		InfinityUtils:Warning("Invalid saved guild knowledge; live sharing disabled.", "Knowledge")
		return nil
	end
	if self.validatedState ~= state then
		local count, revisions = 0, {}
		for key, record in pairs(state.records) do
			record = Public(record)
			if type(key) ~= "string" or not self:Valid(record) or self:Key(record) ~= key
				or not Integer(record.revision, state.revision) or revisions[record.revision] then
				self:SetEnabled(false)
				InfinityUtils:Warning("Invalid saved guild knowledge records; live sharing disabled.", "Knowledge")
				return nil
			end
			revisions[record.revision], count = true, count + 1
		end
		if count ~= state.count then
			self:SetEnabled(false)
			InfinityUtils:Warning("Invalid saved guild knowledge record count; live sharing disabled.", "Knowledge")
			return nil
		end
		self.validatedState = state
	end
	return state, guild
end

function Knowledge:SetEnabled(enabled)
	if enabled and not self.available then
		InfinityUtils:Warning("Live guild knowledge is unavailable.", "Knowledge")
		return false
	end
	if not self.db then InfinityUtils:Warning("Guild knowledge settings unavailable.", "Knowledge"); return false end
	local guild = enabled and GuildKey()
	if enabled and not guild then
		InfinityUtils:Warning("Join a guild before enabling live knowledge.", "Knowledge")
		return false
	end
	self.db.enabled = not not enabled
	self.db.enabledGuild = guild or nil
	if self.db.enabled then
		if _G.C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
		self:Hello()
		self:Schedule(1)
		self:PublishCurrent()
	else
		self.queue, self.pull, self.scheduled, self.sending = {}, nil, nil, false
		self.sendGeneration = (self.sendGeneration or 0) + 1
		self.peers, self.lastHello, self.backoff, self.warnedCapacity, self.warnedQueue = nil, nil, nil, nil, nil
	end
	return self.db.enabled
end

function Knowledge:GetRoster()
	local guild = GuildKey()
	if not guild then return nil end
	if self.rosterGuild ~= guild or not self.roster then
		self.roster, self.online = Roster()
		self.rosterGuild = guild
	end
	return self.roster, self.online
end

function Knowledge:ScheduleSend(delay)
	local generation = self.sendGeneration or 0
	C_Timer.After(delay, function()
		if (self.sendGeneration or 0) == generation then self:SendNext() end
	end)
end

function Knowledge:Enqueue(messages, channel, target, guild, onSent)
	if self.backoff then return false end
	if #self.queue + #messages > 400 then
		if not self.warnedQueue then
			self.warnedQueue = true
			InfinityUtils:Warning("Guild knowledge queue is full; later sync will retry.", "Knowledge")
		end
		return false
	end
	self.warnedQueue = nil
	for _, message in ipairs(messages) do
		if type(message) ~= "string" or #message > 240 then
			InfinityUtils:Warning("Guild knowledge message is invalid.", "Knowledge")
			return false
		end
	end
	for index, message in ipairs(messages) do
		self.queue[#self.queue + 1] = { message = message, channel = channel, target = target, guild = guild,
			retries = 0, onSent = index == 1 and onSent or nil }
	end
	if not self.sending then self:SendNext() end
	return not self.backoff
end

function Knowledge:SendNext()
	local entry = self.queue[1]
	if not self.db.enabled or not entry then self.sending = false; return end
	if GuildKey() ~= entry.guild then
		self:SetEnabled(false)
		InfinityUtils:Warning("Guild changed; pending knowledge transfers stopped.", "Knowledge")
		return
	end
	if entry.target then
		local members = self:GetRoster()
		if not members or not members[FullName(entry.target)] then
			for index = #self.queue, 1, -1 do
				if self.queue[index].target == entry.target then
					local removed = table.remove(self.queue, index)
					if removed.onSent then removed.onSent(false) end
				end
			end
			InfinityUtils:Warning("Guild knowledge recipient is no longer in the roster.", "Knowledge")
			self.sending = true
			self:ScheduleSend(0.3)
			return
		end
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, entry.message, entry.channel, entry.target)
	local protected = _G.issecretvalue and issecretvalue(result)
	if ok and not protected and (result == nil or result == true or result == 0) then
		table.remove(self.queue, 1)
		if entry.onSent then entry.onSent(true) end
	elseif ok and not protected and (result == 3 or result == 8
		or (_G.Enum and Enum.SendAddonMessageResult
			and (result == Enum.SendAddonMessageResult.AddonMessageThrottle
				or result == Enum.SendAddonMessageResult.ChannelThrottle))) and entry.retries < 5 then
		entry.retries = entry.retries + 1
		self.sending = true
		self:ScheduleSend(2)
		return
	else
		self.queue, self.pull, self.sending = {}, nil, false
		local backoff = {}
		self.backoff = backoff
		InfinityUtils:Warning("Guild knowledge transfer failed; retrying later: "
			.. (protected and "protected result" or tostring(result)), "Knowledge")
		C_Timer.After(60, function() if self.backoff == backoff then self.backoff = nil end end)
		return
	end
	self.sending = true
	self:ScheduleSend(0.3)
end

function Knowledge:Add(record, localObservation)
	if not self:Valid(record) then
		if not self.warnedInvalid then
			self.warnedInvalid = true
			InfinityUtils:Warning("A guild observation was invalid or protected and was not shared.", "Knowledge")
		end
		return false
	end
	local state, guild = self:State()
	if not state then return false end
	local key = self:Key(record)
	if _G.issecretvalue and issecretvalue(state.records[key]) then
		self:SetEnabled(false)
		InfinityUtils:Warning("Invalid saved guild knowledge record; live sharing disabled.", "Knowledge")
		return false
	end
	local previous = state.records[key]
	if previous then
		if not self:Valid(previous) then
			self:SetEnabled(false)
			InfinityUtils:Warning("Invalid saved guild knowledge record; live sharing disabled.", "Knowledge")
			return false
		end
		record = self:Merge(previous, record)
		if not record then return false end
	end
	if (not previous and state.count >= self.maxRecords) or state.revision >= 1000000000 then
		if not self.warnedCapacity then
			self.warnedCapacity = true
			InfinityUtils:Warning("Guild knowledge storage limit reached; new records cannot be synchronized.", "Knowledge")
		end
		return false
	end
	state.revision = state.revision + 1
	if not previous then state.count = state.count + 1 end
	local copy = self:Copy(record, state.revision)
	state.records[key] = copy
	if localObservation then
		self:Enqueue({ self:Payload("L" .. copy.kind, copy) }, "GUILD", nil, guild)
	else
		self:Apply(copy)
	end
	return true
end

function Knowledge:ObserveQuest(id, name, level)
	if not self.available or not self.db.enabled then return end
	if _G.issecretvalue and issecretvalue(level) then
		if not self.warnedInvalid then
			self.warnedInvalid = true
			InfinityUtils:Warning("A guild observation was invalid or protected and was not shared.", "Knowledge")
		end
		return
	end
	self:Add({ kind = "Q", id = id, name = name, level = level or 0 }, true)
end

function Knowledge:ObserveDrop(mob, mobName, item, itemName, rarity)
	if not self.available or not self.db.enabled then return end
	mobName, itemName = Public(mobName), Public(itemName)
	if not mobName or not itemName then
		if not self.warnedDrop then
			self.warnedDrop = true
			InfinityUtils:Warning("Some drops lack source or item names and cannot be shared.", "Knowledge")
		end
		return
	end
	self:Add({ kind = "D", mob = mob, mobName = mobName, item = item, itemName = itemName, rarity = rarity }, true)
end

function Knowledge:Schedule(delay)
	if not self.available or not self.db.enabled or self.scheduled then return end
	local scheduled = {}
	self.scheduled = scheduled
	C_Timer.After(delay, function()
		if self.scheduled ~= scheduled or not self.db.enabled then return end
		self.scheduled = nil
		local now = Public(GetTime())
		if type(now) == "number" and now == now and now >= 0 and now < math.huge
			and (not self.lastHello or now - self.lastHello >= 300) then self:Hello() end
		self:SyncNext()
		self:Schedule(60)
	end)
end

function Knowledge:Hello()
	local _, guild = self:State()
	if not guild then return false end
	local now = Public(GetTime())
	if type(now) ~= "number" or now ~= now or now < 0 or now >= math.huge then return false end
	if not self:Enqueue({ "H" }, "GUILD", nil, guild) then return false end
	self.lastHello = now
	return true
end

function Knowledge:SyncNext()
	if not self.available or not self.db.enabled or self.pull then return false end
	local state, guild = self:State()
	local _, online = self:GetRoster()
	local now = Public(GetTime())
	if not state or not online or type(now) ~= "number" or now ~= now or now < 0 or now >= math.huge then return false end
	local candidates = {}
	for _, peer in ipairs(online) do
		local seen = self.peers and self.peers[peer.key]
		if seen and now >= seen and now - seen <= 900 then candidates[#candidates + 1] = peer end
	end
	if #candidates == 0 then return false end
	self.peerIndex = (self.peerIndex or 0) % #candidates + 1
	return self:Request(candidates[self.peerIndex], state, guild)
end

function Knowledge:Touch(pull)
	local now = Public(GetTime())
	if type(now) ~= "number" or now ~= now or now < 0 or now >= 1000000000000 then
		self.pull = nil
		InfinityUtils:Warning("Guild knowledge clock unavailable; sync stopped.", "Knowledge")
		return false
	end
	pull.deadline = now + 240
	return true
end

function Knowledge:Request(peer, state, guild)
	local cursor = Public(state.cursors[peer.key])
	local epoch, revision = "0", 0
	if type(cursor) == "table" and type(Public(cursor.epoch)) == "string"
		and cursor.epoch:match("^%d+%-%d+$") and #cursor.epoch <= 32
		and Integer(cursor.revision, 1000000000, true) then
		epoch, revision = cursor.epoch, cursor.revision
	end
	local now = Public(GetTime())
	if type(now) ~= "number" or now ~= now or now < 0 or now >= 1000000000000 then
		InfinityUtils:Warning("Guild knowledge clock unavailable.", "Knowledge")
		return
	end
	self.sequence = self.sequence + 1
	local token = tostring(math.floor(now * 1000)) .. "-" .. self.sequence
	local pull = { token = token, peer = peer, guild = guild, epoch = epoch, revision = revision }
	self.pull = pull
	local function Sent(ok)
		if self.pull ~= pull then return end
		if not ok then self.pull = nil; return end
		if not self:Touch(pull) then return end
		local function CheckTimeout()
			if self.pull ~= pull then return end
			local current = Public(GetTime())
			if type(current) ~= "number" or current ~= current or current < 0 or current >= 1000000000000 then
				self.pull = nil
				InfinityUtils:Warning("Guild knowledge clock unavailable; sync stopped.", "Knowledge")
			elseif current >= pull.deadline then
				self.pull = nil
				InfinityUtils:Warning("Guild knowledge sync timed out; another sync will retry.", "Knowledge")
			else
				C_Timer.After(pull.deadline - current, CheckTimeout)
			end
		end
		C_Timer.After(240, CheckTimeout)
	end
	if not self:Enqueue({ table.concat({ "R", token, epoch, revision }, "~") }, "WHISPER", peer.name, guild, Sent) then
		self.pull = nil
		return false
	end
	return self.pull == pull
end

function Knowledge:Reply(token, epoch, revision, sender, senderKey, guild)
	local state = self:State()
	if not state then return end
	if epoch ~= state.epoch or revision > state.revision then revision = 0 end
	local records = {}
	for key, record in pairs(state.records) do
		if type(key) ~= "string" or not self:Valid(record) or self:Key(record) ~= key
			or not Integer(record.revision, state.revision) then
			self:SetEnabled(false)
			InfinityUtils:Warning("Invalid saved guild knowledge; live sharing disabled.", "Knowledge")
			return
		end
		if record.revision > revision then records[#records + 1] = record end
	end
	table.sort(records, function(a, b) return a.revision < b.revision end)
	local count = math.min(#records, 100)
	local last = count > 0 and records[count].revision or revision
	local messages = { table.concat({ "B", token, state.epoch, revision, last, count, #records > count and 1 or 0 }, "~") }
	for index = 1, count do
		local record = records[index]
		messages[#messages + 1] = self:Payload(table.concat({ record.kind, token, index, record.revision }, "~"), record)
	end
	messages[#messages + 1] = "E~" .. token
	return self:Enqueue(messages, "WHISPER", sender, guild)
end

function Knowledge:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if not self.db or not self.db.enabled or prefix ~= self.prefix
		or (channel ~= "GUILD" and channel ~= "WHISPER") or type(message) ~= "string" or #message > 240 then return end
	local state, guild = self:State()
	local members = self:GetRoster()
	local senderKey = FullName(sender)
	local me = _G.UnitName and FullName(UnitName("player"))
	if not state or not members or not senderKey or not me or not members[senderKey] or senderKey == me then return end
	local now = Public(GetTime())
	if type(now) ~= "number" or now ~= now or now < 0 or now >= math.huge then return end
	self.peers = self.peers or {}
	local prior = self.peers[senderKey]
	self.peers[senderKey] = now
	if message == "H" then
		if channel == "GUILD" and (not prior or now < prior or now - prior > 900) then
			self:Enqueue({ "H" }, "WHISPER", sender, guild)
		end
		return
	end
	local kind, body = message:match("^L([QDNTPBI])~(.+)$")
	if kind and channel == "GUILD" then
		local record = self:Parse(kind, body)
		if record then self:Add(record, false) end
		return
	end
	if channel ~= "WHISPER" then return end
	local token, epoch, revision = message:match("^R~([%d%-]+)~([%d%-]+)~(%d+)$")
	if token then
		revision = tonumber(revision)
		if #token <= 32 and token:match("^%d+%-%d+$") and #epoch <= 32
			and (epoch == "0" or epoch:match("^%d+%-%d+$")) and Integer(revision, 1000000000, true) then
			self.replyTimes = self.replyTimes or {}
			local replyKey = guild .. ":" .. senderKey
			if not self.replyTimes[replyKey] or now - self.replyTimes[replyKey] >= 5 then
				if self:Reply(token, epoch, revision, sender, senderKey, guild) then self.replyTimes[replyKey] = now end
			end
		end
		return
	end
	local pull = self.pull
	if not pull or pull.guild ~= guild or pull.peer.key ~= senderKey then return end
	local base, last, count, more
	token, epoch, base, last, count, more = message:match("^B~([%d%-]+)~([%d%-]+)~(%d+)~(%d+)~(%d+)~([01])$")
	if token then
		base, last, count = tonumber(base), tonumber(last), tonumber(count)
		local expected = epoch == pull.epoch and pull.revision or 0
		if token ~= pull.token or pull.incoming or #epoch > 32 or not epoch:match("^%d+%-%d+$")
			or not Integer(base, 1000000000, true) or (base ~= expected and base ~= 0)
			or not Integer(last, 1000000000, true) or last < base
			or not Integer(count, 100, true) or (count == 0 and (last ~= base or more ~= "0")) then return end
		if not self:Touch(pull) then return end
		pull.incoming = { epoch = epoch, last = last, next = 1, count = count, more = more == "1", previous = base, records = {} }
		return
	end
	if message == "E~" .. pull.token then
		local incoming = pull.incoming
		if not incoming or incoming.next ~= incoming.count + 1 or incoming.previous ~= incoming.last then
			self.pull = nil
			InfinityUtils:Warning("Incomplete guild knowledge page; retry later.", "Knowledge")
			return
		end
		local new, seen = 0, {}
		for _, record in ipairs(incoming.records) do
			local key = self:Key(record)
			if not state.records[key] and not seen[key] then new, seen[key] = new + 1, true end
		end
		if state.count + new > self.maxRecords or state.revision + #incoming.records > 1000000000 then
			self.pull = nil
			if not self.warnedCapacity then
				self.warnedCapacity = true
				InfinityUtils:Warning("Guild knowledge storage limit reached; page not applied.", "Knowledge")
			end
			return
		end
		for _, record in ipairs(incoming.records) do self:Add(record, false) end
		state.cursors[senderKey] = { epoch = incoming.epoch, revision = incoming.last }
		self.pull = nil
		if incoming.more then self:Request(pull.peer, state, guild) end
		return
	end
	local index
	kind, token, index, revision, body = message:match("^([QDNTPBI])~([%d%-]+)~(%d+)~(%d+)~(.+)$")
	local incoming = pull.incoming
	if kind and token == pull.token and incoming then
		index, revision = tonumber(index), tonumber(revision)
		local record = self:Parse(kind, body)
		if not Integer(index, 100) or index ~= incoming.next or index > incoming.count
			or not Integer(revision, 1000000000) or revision <= incoming.previous or revision > incoming.last
			or not record then
			self.pull = nil
			InfinityUtils:Warning("Invalid guild knowledge page; retry later.", "Knowledge")
			return
		end
		if not self:Touch(pull) then return end
		incoming.next, incoming.previous = index + 1, revision
		incoming.records[index] = record
	end
end

return Knowledge
