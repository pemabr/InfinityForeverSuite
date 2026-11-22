local GuildPresets = { prefix = "InfinityGdP1", sequence = 0, handlers = {} }
_G.InfinityGuideGuildPresets = GuildPresets

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Field(value, limit)
	value = Public(value)
	return type(value) == "string" and value:match("%S") and #value <= limit
		and not value:find("[%z\1-\31|]")
end

local function Realm()
	local realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
	if type(realm) ~= "string" or realm == "" then realm = _G.GetRealmName and Public(GetRealmName()) end
	return type(realm) == "string" and realm ~= "" and realm:gsub("%s+", ""):lower() or nil
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
	if not _G.IsInGuild or not Public(IsInGuild()) or not _G.GetGuildInfo then return nil end
	local guild, _, _, realm = GetGuildInfo("player")
	guild, realm = Public(guild), Public(realm)
	if type(guild) ~= "string" or guild == "" then return nil end
	if type(realm) ~= "string" or realm == "" then realm = Realm() end
	if not realm then return nil end
	return guild:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function Member(sender)
	local target = FullName(sender)
	if not target or not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then return false end
	local count = Public(GetNumGuildMembers())
	if not Integer(count, 10000, true) then return false end
	for index = 1, count do
		local name = Public(GetGuildRosterInfo(index))
		if FullName(name) == target then return true end
	end
	return false
end

local function Encode(value)
	return (value:gsub(".", function(char) return string.format("%02x", string.byte(char)) end))
end

local function Decode(value, maximum)
	if type(value) ~= "string" or #value == 0 or #value > maximum * 2
		or #value % 2 ~= 0 or value:find("[^%x]") then return nil end
	return (value:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

local function Token(value)
	return type(value) == "string" and #value <= 32 and value:match("^%d+%-%d+$") ~= nil
end

function GuildPresets:Initialize()
	if self.initialized then return end
	self.initialized = true
	local store = InfinityStorageManager:GetFeatureSetting("InfinityGuide", "guildPresets", {})
	if type(Public(store)) ~= "table" then
		InfinityUtils:Warning("Invalid saved guild preset data.", "Guide")
		return
	end
	self.store = store
	if not (_G.C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage
		and _G.C_Timer and C_Timer.After and _G.GetTime) then
		InfinityUtils:Warning("Guild guide sharing is unavailable.", "Guide")
		return
	end
	local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and issecretvalue(result)
	local duplicate = _G.Enum and Enum.RegisterAddonMessagePrefixResult
		and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register guild guide messages.", "Guide")
		return
	end
	self.available = true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		StaticPopupDialogs.INFINITY_GUIDE_GUILD_PRESET = {
			text = "Guild preset '%s' from %s. Save and republish to the guild without selecting it?",
			button1 = "Save",
			button2 = "Discard",
			OnAccept = function(_, data) if GuildPresets.pending == data then GuildPresets:Accept() end end,
			OnCancel = function(_, data) if GuildPresets.pending == data then GuildPresets:Discard() end end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
	end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("GUILD_ROSTER_UPDATE")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then self:OnMessage(...)
		else
			local guild = GuildKey()
			if event == "PLAYER_ENTERING_WORLD" and _G.C_GuildInfo and C_GuildInfo.GuildRoster and guild then C_GuildInfo.GuildRoster() end
			self:ScheduleRequest(guild)
		end
	end)
	self.frame = frame
	if _G.C_GuildInfo and C_GuildInfo.GuildRoster and GuildKey() then C_GuildInfo.GuildRoster() end
	if _G.IsLoggedIn and Public(IsLoggedIn()) then self:ScheduleRequest(GuildKey()) end
end

function GuildPresets:ScheduleRequest(guild)
	if guild and self.requestedGuild ~= guild and self.scheduledGuild ~= guild then
		self.scheduledGuild = guild
		C_Timer.After(10, function()
			if self.scheduledGuild ~= guild then return end
			self.scheduledGuild = nil
			if GuildKey() == guild and self.requestedGuild ~= guild then self:Request() end
		end)
	elseif not guild then self.requestedGuild, self.scheduledGuild = nil, nil end
end

function GuildPresets:State(guild)
	if type(self.store) ~= "table" then
		InfinityUtils:Warning("Guild preset storage is unavailable.", "Guide")
		return nil
	end
	local state = self.store[guild]
	if _G.issecretvalue and issecretvalue(state) then
		InfinityUtils:Warning("Invalid saved guild preset data.", "Guide")
		return nil
	end
	if state == nil then
		state = { published = {}, seen = {} }
		self.store[guild] = state
	elseif type(state) ~= "table" or type(Public(state.published)) ~= "table" or type(Public(state.seen)) ~= "table" then
		InfinityUtils:Warning("Invalid saved guild preset data.", "Guide")
		return nil
	end
	return state
end

function GuildPresets:SaveState()
	InfinityStorageManager:SetFeatureSetting("InfinityGuide", "guildPresets", self.store)
end

local function Fingerprint(preset)
	local parts = { preset.kind or "G", tostring(#preset.name), preset.name }
	for _, step in ipairs(preset.steps) do
		parts[#parts + 1] = tostring(step.questID or step.itemID or 0)
		parts[#parts + 1] = tostring(#step.description)
		parts[#parts + 1] = step.description
	end
	local text = table.concat(parts, "~")
	local first, second = 0, 0
	for i = 1, #text do
		local byte = text:byte(i)
		first = (first * 31 + byte) % 2147483647
		second = (second * 37 + byte) % 2147483629
	end
	return first .. "-" .. second .. "-" .. #text
end

local function RememberState(state, pending)
	local fingerprint = Fingerprint(pending)
	for _, value in ipairs(state.seen) do if Public(value) == fingerprint then return false end end
	state.seen[#state.seen + 1] = fingerprint
	if #state.seen > 1000 then table.remove(state.seen, 1) end
	return true
end

function GuildPresets:Remember(pending)
	local state = self:State(pending.guild)
	if not state or not RememberState(state, pending) then return end
	self:SaveState()
end

function GuildPresets:PublishReceived(pending, id)
	local state = self:State(pending.guild)
	if not state or not Field(id, 80) then return false end
	local key = (pending.kind or "G") .. ":" .. id
	local count = 0
	for _ in pairs(state.published) do count = count + 1 end
	if state.published[key] == nil and count >= 100 then
		InfinityUtils:Warning("Preset saved locally, but the publication limit is reached.", "Guide")
		return false
	end
	local copy = { name = pending.name, kind = pending.kind, steps = {} }
	for index, step in ipairs(pending.steps) do
		copy.steps[index] = { description = step.description, questID = step.questID, itemID = step.itemID }
	end
	state.published[key] = copy
	self:SaveState()
	return true
end

function GuildPresets:Known(pending)
	local state = self:State(pending.guild)
	if not state then return true end
	local fingerprint = Fingerprint(pending)
	for _, value in ipairs(state.seen) do if Public(value) == fingerprint then return true end end
	if self.pending and self.pending.guild == pending.guild and Fingerprint(self.pending) == fingerprint then return true end
	for _, value in ipairs(self.waiting or {}) do
		if value.guild == pending.guild and Fingerprint(value) == fingerprint then return true end
	end
	return false
end

function GuildPresets:SendControl(message, channel, target, retries, guild)
	retries, guild = retries or 0, guild or GuildKey()
	if not guild or GuildKey() ~= guild or (target and not Member(target)) then
		InfinityUtils:Warning("Guild changed or sync recipient is unavailable.", "Guide")
		return false
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, message, channel, target)
	local protected = _G.issecretvalue and issecretvalue(result)
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0) then
		local results = _G.Enum and Enum.SendAddonMessageResult
		local throttled = not protected and (result == 3 or result == 8
			or (results and (result == results.AddonMessageThrottle or result == results.ChannelThrottle)))
		if ok and throttled and retries < 5 then
			C_Timer.After(2, function() self:SendControl(message, channel, target, retries + 1, guild) end)
			return true
		end
		if message ~= "R~2" then
			self.lastRequest, self.lastRequestGuild, self.requestedGuild = nil, nil, nil
		end
		InfinityUtils:Warning("Guild preset request failed: " .. (protected and "protected result" or tostring(result)), "Guide")
		return false
	end
	return true
end

function GuildPresets:Request()
	local guild = GuildKey()
	if not self.available or not guild then
		InfinityUtils:Warning("Guild preset sync is unavailable or you are not in a guild.", "Guide")
		return false
	end
	if self.lastRequestGuild == guild and self.lastRequest and GetTime() - self.lastRequest < 60 then
		InfinityUtils:Warning("Wait before requesting guild presets again.", "Guide")
		return false
	end
	local count = _G.GetNumGuildMembers and Public(GetNumGuildMembers())
	if not Integer(count, 10000) then
		InfinityUtils:Warning("Guild roster is not ready; request presets again after it loads.", "Guide")
		return false
	end
	local state = self:State(guild)
	if not state or not self:SendControl(next(state.published) and "R~1~1" or "R~1~0", "GUILD") then return false end
	self.lastRequest, self.lastRequestGuild = GetTime(), guild
	self.requestedGuild = guild
	print("Requested published presets from online guild members.")
	return true
end

function GuildPresets:NextReply()
	if self.outgoing or not self.replies or #self.replies == 0 then return end
	local reply = table.remove(self.replies, 1)
	if GuildKey() ~= reply.guild or not Member(reply.target) then
		InfinityUtils:Warning("Guild preset sync recipient is no longer available.", "Guide")
		return self:NextReply()
	end
	self.batch = reply.batch
	self.outgoing = { guild = reply.guild, target = reply.target, automatic = true,
		messages = table.remove(self.batch, 1), index = 1, retries = 0 }
	self:SendNext()
end

function GuildPresets:Reply(sender, senderKey, guild)
	local now = GetTime()
	self.replyTimes = self.replyTimes or {}
	local replyKey = guild .. ":" .. senderKey
	if self.replyTimes[replyKey] and now - self.replyTimes[replyKey] < 60 then return end
	local state = self:State(guild)
	if not state then return end
	local keys = {}
	for key in pairs(state.published) do
		if type(key) ~= "string" then InfinityUtils:Warning("Invalid published preset ID.", "Guide"); return end
		keys[#keys + 1] = key
	end
	if #keys == 0 then return end
	if #keys > 100 then InfinityUtils:Warning("Too many published presets for sync.", "Guide"); return end
	table.sort(keys)
	local batch = {}
	for _, key in ipairs(keys) do
		local entry = Public(state.published[key])
		local kind = type(entry) == "table" and Public(entry.kind)
		if type(entry) ~= "table" or (_G.issecretvalue and issecretvalue(entry.kind))
			or (kind ~= nil and kind ~= "E" and kind ~= "S") then
			InfinityUtils:Warning("Invalid published preset.", "Guide")
			return
		end
		local messages = self:BuildMessages(nil, entry, kind)
		if not messages then return end
		batch[#batch + 1] = messages
	end
	self.replies = self.replies or {}
	if #self.replies >= 10 then InfinityUtils:Warning("Guild preset sync queue is full.", "Guide"); return end
	self.replyTimes[replyKey] = now
	self.replies[#self.replies + 1] = { target = sender, guild = guild, batch = batch }
	self:NextReply()
end

function GuildPresets:SendNext()
	local outgoing = self.outgoing
	if not outgoing then return false end
	if GuildKey() ~= outgoing.guild then
		self.outgoing, self.batch = nil, nil
		InfinityUtils:Warning("Guild changed; preset transfer stopped.", "Guide")
		self:NextReply()
		return false
	end
	local channel = outgoing.target and "WHISPER" or "GUILD"
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, outgoing.messages[outgoing.index], channel, outgoing.target)
	local protected = _G.issecretvalue and issecretvalue(result)
	if ok and not protected and (result == nil or result == true or result == 0) then
		outgoing.index, outgoing.retries = outgoing.index + 1, 0
		if outgoing.index > #outgoing.messages then
			self.outgoing = nil
			if self.batch and #self.batch > 0 then
				self.outgoing = { guild = outgoing.guild, target = outgoing.target, automatic = outgoing.automatic,
					messages = table.remove(self.batch, 1), index = 1, retries = 0 }
				return self:SendNext()
			end
			self.batch = nil
			if not outgoing.automatic then print("Preset published and sent; guild members can choose whether to save it.") end
			self:NextReply()
		else
			C_Timer.After(0.2, function() if self.outgoing == outgoing then self:SendNext() end end)
		end
		return true
	end
	local results = _G.Enum and Enum.SendAddonMessageResult
	local throttled = not protected and (result == 3 or result == 8
		or (results and (result == results.AddonMessageThrottle or result == results.ChannelThrottle)))
	if ok and throttled and outgoing.retries < 5 then
		outgoing.retries = outgoing.retries + 1
		C_Timer.After(2, function() if self.outgoing == outgoing then self:SendNext() end end)
		return true
	end
	self.outgoing, self.batch = nil, nil
	InfinityUtils:Warning("Guild preset transfer failed: " .. (protected and "protected result" or tostring(result)), "Guide")
	self:NextReply()
	return false
end

function GuildPresets:BuildMessages(id, preset, kind)
	local guide = preset or Public(InfinityGuideGuides.guides[id])
	local steps = type(guide) == "table" and Public(guide.steps)
	if type(guide) ~= "table" or not Field(guide.name, 80) or type(steps) ~= "table" or #steps > 200 then
		InfinityUtils:Warning("Guide not found or cannot be shared safely.", "Guide")
		return nil
	end
	if (_G.issecretvalue and issecretvalue(guide.content)) or (guide.content ~= nil and guide.content ~= "") then
		InfinityUtils:Warning("Guides with separate content cannot be shared; use steps instead.", "Guide")
		return nil
	end
	self.sequence = self.sequence + 1
	local token = tostring(math.floor(GetTime() * 1000)) .. "-" .. self.sequence
	local header = table.concat({ "B", token, #steps, Encode(guide.name) }, "~")
	local messages = { kind and (header .. "~" .. kind) or header }
	for key in pairs(steps) do
		if not Integer(key, 200) or key > #steps then
			InfinityUtils:Warning("Guide contains invalid step indexes.", "Guide")
			return nil
		end
	end
	for index = 1, #steps do
		local step = Public(steps[index])
		local reference
		if type(step) == "table" then
			if kind == "S" then reference = Public(step.itemID)
			else reference = Public(step.questID) end
		end
		if type(step) ~= "table" or not Field(step.description, 60)
			or (_G.issecretvalue and issecretvalue(step.questID))
			or (_G.issecretvalue and issecretvalue(step.itemID))
			or (_G.issecretvalue and issecretvalue(step.images))
			or (step.images ~= nil and (type(step.images) ~= "table" or next(step.images)))
			or (reference ~= nil and not Integer(reference, 1000000000))
			or (kind == "S" and not Integer(reference, 1000000000)) then
			InfinityUtils:Warning("Guide contains a step that cannot be shared safely.", "Guide")
			return nil
		end
		messages[#messages + 1] = table.concat({ "S", token, index, reference or 0, Encode(step.description) }, "~")
	end
	messages[#messages + 1] = "E~" .. token
	for _, message in ipairs(messages) do
		if #message > 240 then InfinityUtils:Warning("Guide message is too long.", "Guide"); return nil end
	end
	return messages
end

function GuildPresets:Send(id, all, preset, kind)
	local guild = GuildKey()
	if not self.available or not guild then
		InfinityUtils:Warning("Guild guide sharing is unavailable or you are not in a guild.", "Guide")
		return false
	end
	if self.outgoing then InfinityUtils:Warning("A guild guide transfer is already running.", "Guide"); return false end
	local ids = {}
	if preset then
		if (kind ~= "E" and kind ~= "S") or not self.handlers[kind] or not Field(id, 80) then
			InfinityUtils:Warning("Unsupported guild preset type.", "Guide")
			return false
		end
		ids[1] = id
	elseif all then
		for key in pairs(InfinityGuideGuides.guides) do
			if not Field(key, 80) then InfinityUtils:Warning("Invalid guide ID.", "Guide"); return false end
			ids[#ids + 1] = key
		end
		table.sort(ids)
	else ids[1] = id end
	if #ids > 100 then InfinityUtils:Warning("Too many guides to share at once.", "Guide"); return false end
	local batch, publications = {}, {}
	local function Add(key, item, typeID)
		if not Field(key, 80) then InfinityUtils:Warning("Invalid preset ID.", "Guide"); return false end
		local messages = self:BuildMessages(nil, item, typeID)
		if not messages then return false end
		local copy = { name = item.name, kind = typeID, steps = {} }
		for index, step in ipairs(item.steps) do
			copy.steps[index] = { description = step.description, questID = step.questID, itemID = step.itemID }
		end
		batch[#batch + 1] = messages
		publications[(typeID or "G") .. ":" .. key] = copy
		return true
	end
	for _, guideID in ipairs(ids) do
		local item = preset or Public(InfinityGuideGuides.guides[guideID])
		if not Add(guideID, item, kind) then return false end
	end
	if all then
		for typeID, handler in pairs(self.handlers) do
			local presets = handler.list()
			if not presets then return false end
			for _, entry in ipairs(presets) do
				if #batch >= 100 then
					InfinityUtils:Warning("Too many presets to share at once.", "Guide")
					return false
				end
				if type(entry) ~= "table" or not Add(entry.id, entry.preset, typeID) then return false end
			end
		end
	end
	if #batch == 0 then InfinityUtils:Warning("No presets to share.", "Guide"); return false end
	local state = self:State(guild)
	if not state then return false end
	local count = 0
	for _ in pairs(state.published) do count = count + 1 end
	for key in pairs(publications) do if state.published[key] == nil then count = count + 1 end end
	if count > 100 then InfinityUtils:Warning("Published preset limit reached; unpublish old presets first.", "Guide"); return false end
	for key, item in pairs(publications) do
		state.published[key] = item
		RememberState(state, item)
	end
	self:SaveState()

	self.batch = batch
	self.outgoing = { guild = guild, messages = table.remove(batch, 1), index = 1, retries = 0 }
	return self:SendNext()
end

function GuildPresets:GetPublished()
	local guild = GuildKey()
	local state = guild and self:State(guild)
	if not state then InfinityUtils:Warning("Guild preset sharing is unavailable.", "Guide"); return nil end
	local keys = {}
	for key in pairs(state.published) do
		if not Field(key, 80) then InfinityUtils:Warning("Invalid published preset ID.", "Guide"); return nil end
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

function GuildPresets:Published()
	local keys = self:GetPublished()
	if not keys then return end
	print("Published preset IDs: " .. (#keys > 0 and table.concat(keys, ", ") or "none"))
end

function GuildPresets:Unpublish(key)
	local guild = GuildKey()
	local state = guild and self:State(guild)
	if not state then InfinityUtils:Warning("Guild preset sharing is unavailable.", "Guide"); return false end
	if key == "all" then
		state.published = {}
	elseif type(key) == "string" and state.published[key] ~= nil then
		state.published[key] = nil
	else
		InfinityUtils:Warning("Published preset not found.", "Guide")
		return false
	end
	if self.outgoing then
		self.outgoing, self.batch, self.replies = nil, nil, nil
		print("Ongoing preset transfers canceled.")
	end
	self:SaveState()
	print("Preset publication removed. Copies already received are unchanged.")
	return true
end

function GuildPresets:RegisterType(kind, save, list)
	if (kind ~= "E" and kind ~= "S") or type(save) ~= "function" or type(list) ~= "function" then return false end
	self.handlers[kind] = { save = save, list = list }
	return true
end

function GuildPresets:NotifyPending()
	local pending = self.pending
	if not pending then return end
	local kind = pending.kind == "E" and "boss preset" or pending.kind == "S" and "shopping list" or "guide"
	print("Guild " .. kind .. " received: " .. pending.name .. " from " .. pending.sender .. ". /infguide guild accept or discard.")
	if _G.StaticPopup_Show and _G.StaticPopupDialogs then
		StaticPopup_Show("INFINITY_GUIDE_GUILD_PRESET", pending.name, pending.sender, pending)
	end
end

function GuildPresets:AdvancePending()
	self.pending = self.waiting and table.remove(self.waiting, 1) or nil
	local pending = self.pending
	if pending then
		C_Timer.After(0, function() if self.pending == pending then self:NotifyPending() end end)
	end
end

function GuildPresets:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if prefix ~= self.prefix or (channel ~= "GUILD" and channel ~= "WHISPER")
		or type(message) ~= "string" or #message > 240 then return end
	local guild, senderKey = GuildKey(), FullName(sender)
	local me = _G.UnitName and FullName(Public(UnitName("player")))
	if not guild or not senderKey or not me or senderKey == me or not Member(sender) then return end
	if (message == "R~1~0" or message == "R~1~1") and channel == "GUILD" then
		self:Reply(sender, senderKey, guild)
		self.reverseTimes = self.reverseTimes or {}
		local reverseKey = guild .. ":" .. senderKey
		if message == "R~1~1" and (not self.reverseTimes[reverseKey] or GetTime() - self.reverseTimes[reverseKey] >= 60) then
			if self:SendControl("R~2", "WHISPER", sender) then self.reverseTimes[reverseKey] = GetTime() end
		end
		return
	elseif message == "R~2" and channel == "WHISPER" then
		self:Reply(sender, senderKey, guild)
		return
	end
	self.incoming = self.incoming or {}
	local incomingKey = channel .. ":" .. senderKey
	local token, count, encoded, kind = message:match("^B~([%d%-]+)~(%d+)~(%x+)~([ES])$")
	if not token then token, count, encoded = message:match("^B~([%d%-]+)~(%d+)~(%x+)$") end
	if token then
		if kind and not self.handlers[kind] then
			InfinityUtils:Warning("Received unsupported guild preset type.", "Guide")
			return
		end
		count = tonumber(count)
		local name = Decode(encoded, 80)
		local active = 0
		for _ in pairs(self.incoming) do active = active + 1 end
		if not Token(token) or not Integer(count, 200, true) or not Field(name, 80) then return end
		if self.incoming[incomingKey] or active >= 20 or (self.waiting and #self.waiting >= 99) then
			InfinityUtils:Warning("Guild preset transfer could not start; sync again later.", "Guide")
			return
		end
		local incoming = { token = token, count = count, sender = sender, senderKey = senderKey,
			guild = guild, name = name, steps = {}, kind = kind, channel = channel }
		self.incoming[incomingKey] = incoming
		C_Timer.After(math.max(60, count * 2 + 30), function()
			if self.incoming[incomingKey] == incoming then
				self.incoming[incomingKey] = nil
				InfinityUtils:Warning("Guild guide transfer timed out.", "Guide")
			end
		end)
		return
	end
	local incoming = self.incoming[incomingKey]
	if not incoming or incoming.senderKey ~= senderKey or incoming.guild ~= guild then return end
	local endToken = message:match("^E~([%d%-]+)$")
	if endToken then
		if endToken ~= incoming.token then return end
		self.incoming[incomingKey] = nil
		if #incoming.steps ~= incoming.count then
			InfinityUtils:Warning("Incomplete guild guide received; discarded.", "Guide")
			return
		end
		if channel == "WHISPER" and self:Known(incoming) then return end
		if self.pending and self.waiting and #self.waiting >= 99 then
			InfinityUtils:Warning("Guild preset review queue is full.", "Guide")
			return
		end
		if self.pending then
			self.waiting = self.waiting or {}
			self.waiting[#self.waiting + 1] = incoming
			print("Another guild preset is waiting for review.")
		else
			self.pending = incoming
			self:NotifyPending()
		end
		return
	end
	local index, quest
	token, index, quest, encoded = message:match("^S~([%d%-]+)~(%d+)~(%d+)~(%x+)$")
	if token and token == incoming.token then
		index, quest = tonumber(index), tonumber(quest)
		local description = Decode(encoded, 60)
		if not Integer(index, 200) or index ~= #incoming.steps + 1 or index > incoming.count
			or not Integer(quest, 1000000000, true) or not Field(description, 60) then
			self.incoming[incomingKey] = nil
			InfinityUtils:Warning("Invalid guild guide data; transfer discarded.", "Guide")
			return
		end
		if incoming.kind == "S" then
			incoming.steps[index] = { description = description, itemID = quest > 0 and quest or nil }
		else
			incoming.steps[index] = { description = description, questID = quest > 0 and quest or nil }
		end
	end
end

function GuildPresets:Accept()
	local pending = self.pending
	if not pending or pending.guild ~= GuildKey() or not Member(pending.sender) then
		InfinityUtils:Warning("No guild guide is available for this guild.", "Guide")
		return false
	end
	local id
	if pending.kind then
		local handler = self.handlers[pending.kind]
		id = handler and handler.save(pending.name, pending.steps)
		if not id then
			InfinityUtils:Warning("Could not save guild preset.", "Guide")
			return false
		end
	else
		local guide = InfinityGuideGuides:CreateFromSteps(pending.name, "Guild", pending.steps)
		if not guide then return false end
		id = guide.id
		print("Saved guild guide " .. guide.id .. ". Select it in My Guides.")
		if InfinityGuideUI and InfinityGuideUI.guideFrame and InfinityGuideUI.guideFrame:IsShown() then
			InfinityGuideUI:RefreshGuides()
		end
	end
	if not self:PublishReceived(pending, id) then
		InfinityUtils:Warning("The saved guild preset could not be republished.", "Guide")
	end
	self:Remember(pending)
	self:AdvancePending()
	return true
end

function GuildPresets:Discard()
	local key = self.incoming and next(self.incoming)
	if not self.pending and not key then
		InfinityUtils:Warning("No guild guide transfer to discard.", "Guide")
		return false
	end
	if self.pending then
		self:Remember(self.pending)
		self:AdvancePending()
	else self.incoming[key] = nil end
	print("Guild guide discarded.")
	return true
end

return GuildPresets
