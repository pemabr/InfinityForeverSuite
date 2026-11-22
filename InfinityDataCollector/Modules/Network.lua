local Network = { prefix = "InfinityDC1", maxRecords = 1000, sequence = 0, shareEnabled = false }
_G.InfinityDataCollectorNetwork = Network

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, allowZero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (allowZero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Field(value)
	value = Public(value)
	return type(value) == "string" and value:match("%S") and #value <= 75 and not value:find("[%z\1-\31~|]")
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
	local guild, _, _, realm = GetGuildInfo("player")
	guild, realm = Public(guild), Public(realm)
	if type(guild) ~= "string" or guild == "" then return nil end
	if type(realm) ~= "string" or realm == "" then
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return guild:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

function Network:Initialize()
	if self.initialized then return end
	local db = InfinityDataCollectorCore.db
	if db.network == nil then db.network = { enabled = false } end
	if type(db.network) ~= "table" or type(db.network.enabled) ~= "boolean" then
		error("Invalid saved data collector network settings")
	end
	self.db = db.network
	self.initialized = true
	if not (_G.C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage
		and _G.C_Timer and C_Timer.After) then
		InfinityUtils:Warning("Data collector guild sync is unavailable on this client.", "Network")
		return
	end
	local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and issecretvalue(result)
	local duplicate = _G.Enum and Enum.RegisterAddonMessagePrefixResult
		and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register data collector guild messages.", "Network")
		return
	end
	self.available, self.shareEnabled = true, self.db.enabled
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, _, ...) self:OnMessage(...) end)
	self.frame = frame
end

function Network:SetSharingEnabled(enabled)
	if enabled and not self.available then
		InfinityUtils:Warning("Data collector guild sync is unavailable on this client.", "Network")
		return false
	end
	self.shareEnabled = not not enabled
	self.db.enabled = self.shareEnabled
	if not self.shareEnabled then self.incoming, self.outgoing = nil, nil end
	return self.shareEnabled
end

function Network:SendNext()
	local outgoing = self.outgoing
	if not outgoing then return false end
	if GuildKey() ~= outgoing.guild then
		self.outgoing = nil
		InfinityUtils:Warning("Guild changed; collector snapshot was not sent.", "Network")
		return false
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, outgoing.messages[outgoing.index], "GUILD")
	local protected = _G.issecretvalue and issecretvalue(result)
	if ok and not protected and (result == nil or result == true or result == 0) then
		outgoing.index, outgoing.retries = outgoing.index + 1, 0
		if outgoing.index > #outgoing.messages then
			self.outgoing = nil
			print("Collector snapshot sent. Guild members must apply it explicitly.")
		else
			C_Timer.After(0.2, function()
				if self.outgoing == outgoing then self:SendNext() end
			end)
		end
		return true
	end
	local results = _G.Enum and Enum.SendAddonMessageResult
	local throttled = not protected and (result == 3 or result == 8
		or (results and (result == results.AddonMessageThrottle or result == results.ChannelThrottle)))
	if ok and throttled and outgoing.retries < 5 then
		outgoing.retries = outgoing.retries + 1
		C_Timer.After(2, function()
			if self.outgoing == outgoing then self:SendNext() end
		end)
		return true
	else
		self.outgoing = nil
		InfinityUtils:Warning("Collector snapshot could not be sent: "
			.. (protected and "protected result" or tostring(result)), "Network")
		return false
	end
end

function Network:Send()
	if not self.available or not self.shareEnabled then
		InfinityUtils:Warning("Enable collector guild sync before sending.", "Network")
		return false
	end
	local guild = GuildKey()
	if not guild then
		InfinityUtils:Warning("Join a guild before sending a collector snapshot.", "Network")
		return false
	end
	if self.outgoing then
		InfinityUtils:Warning("A collector snapshot is already being sent.", "Network")
		return false
	end
	local data, records, seen = InfinityDataCollectorCore.gatheredData, {}, {}
	for id, quest in pairs(data.quests) do
		quest = Public(quest)
		local level = type(quest) == "table" and Public(quest.level)
		local protected = type(quest) == "table" and _G.issecretvalue and issecretvalue(quest.level)
		if not Integer(id, 1000000000) or type(quest) ~= "table" or protected or not Field(quest.name)
			or (level ~= nil and not Integer(level, 1000, true)) then
			InfinityUtils:Warning("A quest cannot be sent safely.", "Network")
			return false
		end
		records[#records + 1] = { "Q", id, level or 0, quest.name }
	end
	for _, drop in pairs(data.drops) do
		drop = Public(drop)
		local rarity = type(drop) == "table" and Public(drop.rarity)
		local protected = type(drop) == "table" and _G.issecretvalue and issecretvalue(drop.rarity)
		if type(drop) ~= "table" or not Integer(drop.mobID, 1000000000)
			or not Integer(drop.itemID, 1000000000) or not Field(drop.mobName) or not Field(drop.itemName)
			or protected or (rarity ~= nil and not Integer(rarity, 10, true)) then
			InfinityUtils:Warning("A drop cannot be sent safely.", "Network")
			return false
		end
		local key = drop.mobID .. ":" .. drop.itemID
		if seen[key] then
			InfinityUtils:Warning("Duplicate drops cannot be sent.", "Network")
			return false
		end
		seen[key] = true
		records[#records + 1] = { "D", drop.mobID, drop.itemID, rarity == nil and "u" or rarity, drop.mobName, drop.itemName }
	end
	if #records > self.maxRecords then
		InfinityUtils:Warning("Collector snapshot exceeds 1000 records.", "Network")
		return false
	end
	self.sequence = self.sequence + 1
	local token = tostring(time()) .. "-" .. self.sequence
	local messages = { "B~" .. token .. "~" .. #records }
	for index, record in ipairs(records) do
		local parts = { record[1], token, tostring(index) }
		for i = 2, #record do parts[#parts + 1] = tostring(record[i]) end
		local message = table.concat(parts, "~")
		if #message > 240 then
			InfinityUtils:Warning("A collector record is too long to send.", "Network")
			return false
		end
		messages[#messages + 1] = message
	end
	messages[#messages + 1] = "E~" .. token
	self.outgoing = { messages = messages, index = 1, retries = 0, guild = guild }
	return self:SendNext()
end

function Network:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if not self.shareEnabled or prefix ~= self.prefix or channel ~= "GUILD"
		or type(message) ~= "string" or #message > 240 then return end
	local guild, senderKey = GuildKey(), FullName(sender)
	local me = _G.UnitName and Public(UnitName("player"))
	local myKey = FullName(me)
	if not guild or not senderKey or not myKey or senderKey == myKey then return end
	local token, count = message:match("^B~([%d%-]+)~(%d+)$")
	if token then
		count = tonumber(count)
		if not Integer(count, self.maxRecords, true) or self.pending or self.incoming then return end
		local incoming = { token = token, sender = sender, senderKey = senderKey, guild = guild, count = count,
			nextIndex = 1, quests = {}, drops = {} }
		self.incoming = incoming
		C_Timer.After(math.max(60, count * 2 + 30), function()
			if self.incoming == incoming then
				self.incoming = nil
				InfinityUtils:Warning("Collector snapshot timed out.", "Network")
			end
		end)
		return
	end
	local incoming = self.incoming
	if not incoming or incoming.senderKey ~= senderKey or incoming.guild ~= guild then return end
	local endToken = message:match("^E~([%d%-]+)$")
	if endToken then
		if endToken == incoming.token then
			if incoming.nextIndex == incoming.count + 1 then
				self.pending, self.incoming = incoming, nil
				print("Collector snapshot from " .. sender .. ": " .. incoming.count .. " records. /datacollector guild apply or discard.")
			else
				self.incoming = nil
				InfinityUtils:Warning("Incomplete collector snapshot rejected.", "Network")
			end
		end
		return
	end
	local recordToken, index, id, level, name = message:match("^Q~([%d%-]+)~(%d+)~(%d+)~(%d+)~([^~]+)$")
	if recordToken then
		index, id, level = tonumber(index), tonumber(id), tonumber(level)
		if recordToken ~= incoming.token or index ~= incoming.nextIndex or index > incoming.count
			or not Integer(id, 1000000000) or not Integer(level, 1000, true) or not Field(name)
			or incoming.quests[id] then return end
		incoming.quests[id] = { name = name, level = level }
		incoming.nextIndex = incoming.nextIndex + 1
		return
	end
	local mob, item, rarity, mobName, itemName
	recordToken, index, mob, item, rarity, mobName, itemName =
		message:match("^D~([%d%-]+)~(%d+)~(%d+)~(%d+)~([%du]+)~([^~]+)~([^~]+)$")
	if recordToken then
		index, mob, item = tonumber(index), tonumber(mob), tonumber(item)
		local rarityText = rarity
		rarity = rarityText == "u" and nil or tonumber(rarityText)
		local key = mob .. "_" .. item
		if recordToken ~= incoming.token or index ~= incoming.nextIndex or index > incoming.count
			or not Integer(mob, 1000000000) or not Integer(item, 1000000000)
			or (rarityText ~= "u" and not Integer(rarity, 10, true))
			or not Field(mobName) or not Field(itemName) or incoming.drops[key] then return end
		incoming.drops[key] = { mobID = mob, itemID = item, rarity = rarity, mobName = mobName, itemName = itemName }
		incoming.nextIndex = incoming.nextIndex + 1
	end
end

function Network:Apply()
	if not self.pending then
		InfinityUtils:Warning("No collector snapshot is pending.", "Network")
		return false
	end
	if GuildKey() ~= self.pending.guild then
		InfinityUtils:Warning("Guild changed; discard the collector snapshot.", "Network")
		return false
	end
	local core, pending = InfinityDataCollectorCore, self.pending
	local quests, drops = 0, 0
	for id, quest in pairs(pending.quests) do
		if not core.gatheredData.quests[id] then
			core:RecordQuestData(id, quest.name, quest.level, nil, nil, nil, nil, nil, nil)
			quests = quests + 1
		end
	end
	for key, drop in pairs(pending.drops) do
		if not core.gatheredData.drops[key] then
			core:RecordDropData(drop.mobID, drop.mobName, drop.itemID, drop.itemName, nil, drop.rarity)
			drops = drops + 1
		end
	end
	self.pending = nil
	print(string.format("Collector snapshot applied: %d new quests, %d new drops; existing records unchanged.", quests, drops))
	return true
end

function Network:Discard()
	if not self.pending and not self.incoming then
		InfinityUtils:Warning("No collector snapshot is pending or arriving.", "Network")
		return false
	end
	self.pending, self.incoming = nil, nil
	print("Collector snapshot discarded.")
	return true
end

function Network:GetNetworkStats()
	return { available = not not self.available, shareEnabled = self.shareEnabled,
		pendingCount = self.pending and self.pending.count, sender = self.pending and self.pending.sender,
		sending = self.outgoing ~= nil, receiving = self.incoming ~= nil }
end

return Network
