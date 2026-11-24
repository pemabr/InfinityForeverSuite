-- InfinityHive Comms & Core State
-- Unified, rate-limited, chunked guild hive-mind networking over C_ChatInfo ("INFHIVE")
-- Default-ON sharing with per-category privacy controls and zero addon conflicts

local ADDON_PREFIX = "INFHIVE"
local MAX_MSG_BYTES = 220
local SEND_INTERVAL = 0.22

InfinityHive = InfinityHive or {
	version = "2.0.0",
	initialized = false,
	prefixRegistered = false,
	handlers = {},
	sendQueue = {},
	urgentQueue = {},
	reassembly = {},
	members = {},
	recentEvents = {},
	chunkCounter = 0,
	lastSendTime = 0,
	lastHeartbeat = 0,
	stats = {
		messagesSent = 0,
		messagesReceived = 0,
		failedSends = 0,
		lastOutboundAt = 0,
		lastInboundAt = 0,
		lastSyncRequestedAt = 0,
		lastSyncCompletedAt = 0,
	},
}
_G.InfinityHive = InfinityHive

InfinityHive.DEFAULT_CONFIG = {
	-- All sharing ON by default for true guild hive-mind experience
	shareBags = true,
	shareBank = true,
	shareProfessions = true,
	shareCooldowns = true,
	shareDistress = true,
	shareLFG = true,
	shareAuctionPrices = true,
	shareWorldEvents = true,
	shareGameDB = true,
	-- Display preferences (clean & non-intrusive by default)
	showDistressAlerts = true,
	distressHpThreshold = 35,
	distressMaxDistance = 0.18,
	showLFGMatches = true,
	showTooltips = true,
	showTooltipCounts = true,
	showTooltipProfNeeds = true,
	showTooltipPrices = true,
	showTooltipGameDB = true,
	showCooldownOverlay = true,
	myRole = "AUTO",
}

function InfinityHive:GetPlayerShortName()
	local name = UnitName and UnitName("player") or "Unknown"
	return (name:gsub("%-.+$", ""))
end

function InfinityHive:GetRealmKey()
	return (GetRealmName and GetRealmName()) or "DefaultRealm"
end

function InfinityHive:GetPlayerClass()
	if UnitClass then
		local _, classFile = UnitClass("player")
		return classFile or "WARRIOR"
	end
	return "WARRIOR"
end

function InfinityHive:GetPlayerRole()
	local cfg = self:GetConfig()
	if cfg.myRole and cfg.myRole ~= "AUTO" then
		return cfg.myRole
	end
	local cls = self:GetPlayerClass()
	if cls == "PRIEST" then return "HEALER"
	elseif cls == "WARRIOR" then return "TANK"
	elseif cls == "PALADIN" or cls == "DRUID" or cls == "SHAMAN" then return "HYBRID"
	end
	return "DPS"
end

function InfinityHive:GetDB()
	_G.InfinityCoreDB = _G.InfinityCoreDB or {}
	_G.InfinityCoreDB.hive = _G.InfinityCoreDB.hive or {}
	local db = _G.InfinityCoreDB.hive
	db.config = db.config or {}
	for k, v in pairs(self.DEFAULT_CONFIG) do
		if db.config[k] == nil then
			db.config[k] = v
		end
	end
	db.alts = db.alts or {}
	db.guildBags = db.guildBags or {}
	db.guildProfs = db.guildProfs or {}
	db.myNeededMats = db.myNeededMats or {}
	db.prices = db.prices or {}
	db.gameDB = db.gameDB or { revision = 1, items = {}, quests = {}, npcs = {} }
	db.lfgPosts = db.lfgPosts or {}
	db.rares = db.rares or {}
	db.questZones = db.questZones or {}
	return db
end

function InfinityHive:GetConfig()
	return self:GetDB().config
end

function InfinityHive:SetConfig(key, value)
	local cfg = self:GetConfig()
	cfg[key] = value
	if _G.InfinityMessaging then
		pcall(function() _G.InfinityMessaging:Publish("HIVE_CONFIG_CHANGED", key, value) end)
	end
end

function InfinityHive:AddFeedEvent(category, text, extra)
	table.insert(self.recentEvents, 1, {
		time = time(),
		category = category or "HIVE",
		text = text or "",
		extra = extra,
	})
	while #self.recentEvents > 60 do
		table.remove(self.recentEvents)
	end
end

function InfinityHive:RegisterHandler(msgType, fn)
	if not msgType or type(fn) ~= "function" then return end
	self.handlers[msgType] = self.handlers[msgType] or {}
	table.insert(self.handlers[msgType], fn)
end

function InfinityHive:CanSendChannel(channel)
	if channel == "GUILD" then
		return IsInGuild and IsInGuild() or false
	elseif channel == "RAID" then
		return IsInRaid and IsInRaid() or false
	elseif channel == "PARTY" then
		return IsInGroup and IsInGroup() or false
	end
	return true
end

function InfinityHive:SendRaw(payload, channel, target, urgent)
	channel = channel or "GUILD"
	if not self:CanSendChannel(channel) then return false end
	if not payload or payload == "" then return false end

	local queue = urgent and self.urgentQueue or self.sendQueue

	if #payload <= MAX_MSG_BYTES then
		table.insert(queue, { msg = payload, channel = channel, target = target })
		return true
	end

	-- Automatic chunking for larger payloads (full bags/bank/professions/DB sync)
	self.chunkCounter = (self.chunkCounter + 1) % 9999
	local cid = tostring(self.chunkCounter)
	local chunkBodySize = MAX_MSG_BYTES - 18
	local total = math.ceil(#payload / chunkBodySize)
	for i = 1, total do
		local startIdx = (i - 1) * chunkBodySize + 1
		local slice = payload:sub(startIdx, startIdx + chunkBodySize - 1)
		local packet = string.format("C\t%s\t%d\t%d\t%s", cid, i, total, slice)
		table.insert(queue, { msg = packet, channel = channel, target = target })
	end
	return true
end

function InfinityHive:Send(msgType, body, channel, target, urgent)
	local payload = msgType .. "\t" .. (body or "")
	return self:SendRaw(payload, channel or "GUILD", target, urgent)
end

function InfinityHive:DispatchMessage(senderShort, msgType, body, distribution)
	-- Track member presence and inbound sync telemetry automatically
	local now = time()
	self.members[senderShort] = self.members[senderShort] or { name = senderShort }
	self.members[senderShort].lastSeen = now
	if self.stats then
		self.stats.messagesReceived = (self.stats.messagesReceived or 0) + 1
		self.stats.lastInboundAt = now
		if msgType == "BAGS" or msgType == "BANK" or msgType == "PROF" or msgType == "DBRES" or msgType == "PING" then
			self.stats.lastSyncCompletedAt = now
		end
	end

	local list = self.handlers[msgType]
	if list then
		for _, fn in ipairs(list) do
			pcall(fn, senderShort, body, distribution)
		end
	end
end

function InfinityHive:OnAddonMessage(prefix, message, distribution, sender)
	if prefix ~= ADDON_PREFIX or type(message) ~= "string" then return end
	local senderShort = tostring(sender or ""):gsub("%-.+$", "")
	if senderShort == "" or senderShort == self:GetPlayerShortName() then
		return
	end

	-- Chunked packet reassembly: C \t cid \t idx \t total \t slice
	if message:sub(1, 2) == "C\t" then
		local cid, idxStr, totalStr, slice = message:match("^C\t([^%s]+)\t(%d+)\t(%d+)\t(.*)$")
		local idx, total = tonumber(idxStr), tonumber(totalStr)
		if not cid or not idx or not total or total > 64 then return end
		local key = senderShort .. ":" .. cid
		local buf = self.reassembly[key]
		if not buf then
			buf = { parts = {}, received = 0, total = total, created = GetTime() }
			self.reassembly[key] = buf
		end
		if not buf.parts[idx] then
			buf.parts[idx] = slice
			buf.received = buf.received + 1
		end
		if buf.received >= buf.total then
			local ordered = {}
			for i = 1, buf.total do
				ordered[i] = buf.parts[i] or ""
			end
			self.reassembly[key] = nil
			local full = table.concat(ordered)
			local mType, mBody = full:match("^([^\t]+)\t?(.*)$")
			if mType then
				self:DispatchMessage(senderShort, mType, mBody or "", distribution)
			end
		end
		return
	end

	local msgType, body = message:match("^([^\t]+)\t?(.*)$")
	if msgType then
		self:DispatchMessage(senderShort, msgType, body or "", distribution)
	end
end

function InfinityHive:SendHeartbeat(requestFullSync)
	if not (IsInGuild and IsInGuild()) then return end
	local cls = self:GetPlayerClass()
	local lvl = UnitLevel and UnitLevel("player") or 60
	local zone = GetRealZoneText and GetRealZoneText() or "Azeroth"
	local x, y, mapID = 0, 0, 0
	if InfinityUtils and InfinityUtils.GetUnitMapPosition then
		local px, py, mid = InfinityUtils:GetUnitMapPosition("player")
		x, y, mapID = px or 0, py or 0, mid or 0
	end
	local role = self:GetPlayerRole()
	local body = string.format("%s|%d|%s|%d|%.3f|%.3f|%s|%s|%d",
		cls, lvl, zone:gsub("|", " "), mapID, x, y, role, self.version, requestFullSync and 1 or 0)
	self:Send("PING", body, "GUILD")
	self.lastHeartbeat = GetTime()
end

function InfinityHive:RequestFullGuildSync()
	if not (IsInGuild and IsInGuild()) then return end
	if self.stats then
		self.stats.lastSyncRequestedAt = time()
	end
	self:SendHeartbeat(true)
	self:Send("SYNC_REQ", self.version, "GUILD")
end

-- Real-time connectivity and data-sync health summary for dashboard status indicators
function InfinityHive:GetNetworkHealth()
	local now = time()
	local inGuild = IsInGuild and IsInGuild() or false
	local prefixOk = self.prefixRegistered == true
	local members = self:GetOnlineMembers()
	local peers = math.max(0, #members - 1)
	local queued = #(self.urgentQueue or {}) + #(self.sendQueue or {})

	local reassemblyCount = 0
	for _ in pairs(self.reassembly or {}) do
		reassemblyCount = reassemblyCount + 1
	end

	local dbStats = (_G.InfinityHiveNetworkDB and _G.InfinityHiveNetworkDB.GetStats)
		and _G.InfinityHiveNetworkDB:GetStats()
		or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }

	local st = self.stats or {}
	local lastActivity = math.max(st.lastSyncCompletedAt or 0, st.lastInboundAt or 0, st.lastOutboundAt or 0)
	local lastSyncAge = (lastActivity > 0) and math.max(0, now - lastActivity) or nil

	local state, label, shortLabel, color, hex, score
	if not self.initialized or not inGuild or not prefixOk then
		state = "OFFLINE"
		label = not inGuild and "Offline (No Guild)" or "Offline (Prefix)"
		shortLabel = "Offline"
		color = { 0.97, 0.44, 0.44 }
		hex = "|cfff87171"
		score = 0
	elseif queued > 0 or reassemblyCount > 0 then
		state = "SYNCING"
		label = string.format("Syncing (%d queued)", queued + reassemblyCount)
		shortLabel = "Syncing"
		color = { 0.22, 0.74, 0.97 }
		hex = "|cff38bdf8"
		score = 92
	elseif (st.failedSends or 0) >= 3 or (peers == 0 and (st.messagesReceived or 0) == 0) then
		state = "DEGRADED"
		label = peers == 0 and "Standby (0 Guild Peers)" or "Degraded"
		shortLabel = peers == 0 and "Standby" or "Degraded"
		color = { 0.98, 0.75, 0.14 }
		hex = "|cfffbbf24"
		score = peers == 0 and 78 or 60
	else
		state = "HEALTHY"
		label = "Connected & Synced"
		shortLabel = "Healthy"
		color = { 0.29, 0.87, 0.50 }
		hex = "|cff4ade80"
		score = 100
	end

	local syncFreshness
	if not lastSyncAge then
		syncFreshness = "Awaiting first sync"
	elseif lastSyncAge < 60 then
		syncFreshness = lastSyncAge .. "s ago"
	elseif lastSyncAge < 3600 then
		syncFreshness = math.floor(lastSyncAge / 60) .. "m ago"
	else
		syncFreshness = math.floor(lastSyncAge / 3600) .. "h ago"
	end

	return {
		state = state,
		label = label,
		shortLabel = shortLabel,
		color = color,
		hex = hex,
		score = score,
		isInGuild = inGuild,
		prefixRegistered = prefixOk,
		onlinePeers = peers,
		queuedMessages = queued,
		reassemblyCount = reassemblyCount,
		messagesSent = st.messagesSent or 0,
		messagesReceived = st.messagesReceived or 0,
		failedSends = st.failedSends or 0,
		lastSyncAgeSec = lastSyncAge,
		syncFreshness = syncFreshness,
		dbRevision = dbStats.revision or 1,
		dbItems = dbStats.items or 0,
		dbMissing = dbStats.missing or 0,
		summary = string.format("HiveMind: %s · %d peers · Rev v%d", shortLabel, peers, dbStats.revision or 1),
	}
end

function InfinityHive:GetOnlineMembers()
	local list = {}
	local now = time()
	-- Include self
	local me = self:GetPlayerShortName()
	local px, py, mid = 0, 0, 0
	if InfinityUtils and InfinityUtils.GetUnitMapPosition then
		local x, y, m = InfinityUtils:GetUnitMapPosition("player")
		px, py, mid = x or 0, y or 0, m or 0
	end
	table.insert(list, {
		name = me,
		class = self:GetPlayerClass(),
		level = UnitLevel and UnitLevel("player") or 60,
		zone = GetRealZoneText and GetRealZoneText() or "Azeroth",
		mapID = mid,
		x = px,
		y = py,
		role = self:GetPlayerRole(),
		lastSeen = now,
		isSelf = true,
	})
	for name, info in pairs(self.members) do
		if name ~= me and (now - (info.lastSeen or 0)) <= 600 then
			table.insert(list, info)
		end
	end
	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
	return list
end

function InfinityHive:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:GetDB()

	-- Register INFHIVE addon message prefix
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		self.prefixRegistered = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
	elseif RegisterAddonMessagePrefix then
		self.prefixRegistered = RegisterAddonMessagePrefix(ADDON_PREFIX)
	end

	-- Handle presence heartbeats
	self:RegisterHandler("PING", function(sender, body)
		local cls, lvl, zone, mapID, x, y, role, ver, wantsSync =
			body:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
		self.members[sender] = {
			name = sender,
			class = cls ~= "" and cls or "WARRIOR",
			level = tonumber(lvl) or 60,
			zone = zone ~= "" and zone or "Azeroth",
			mapID = tonumber(mapID) or 0,
			x = tonumber(x) or 0,
			y = tonumber(y) or 0,
			role = role ~= "" and role or "DPS",
			version = ver or "2.0.0",
			lastSeen = time(),
		}
		if wantsSync == "1" and _G.InfinityMessaging then
			pcall(function() _G.InfinityMessaging:Publish("HIVE_PEER_REQUESTED_SYNC", sender) end)
		end
	end)

	self:RegisterHandler("SYNC_REQ", function(sender)
		if _G.InfinityMessaging then
			pcall(function() _G.InfinityMessaging:Publish("HIVE_PEER_REQUESTED_SYNC", sender) end)
		end
	end)

	-- Event & rate-limited pump frame
	local frame = CreateFrame("Frame")
	pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
	pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
	pcall(frame.RegisterEvent, frame, "ZONE_CHANGED_NEW_AREA")

	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			InfinityHive:OnAddonMessage(...)
		elseif event == "PLAYER_ENTERING_WORLD" then
			if C_Timer and C_Timer.After then
				C_Timer.After(4, function()
					InfinityHive:RequestFullGuildSync()
				end)
			end
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			InfinityHive:SendHeartbeat(false)
		end
	end)

	local pumpAccum = 0
	local cleanupAccum = 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		pumpAccum = pumpAccum + (elapsed or 0)
		cleanupAccum = cleanupAccum + (elapsed or 0)

		if pumpAccum >= SEND_INTERVAL then
			pumpAccum = 0
			local nextItem = table.remove(InfinityHive.urgentQueue, 1) or table.remove(InfinityHive.sendQueue, 1)
			if nextItem and InfinityHive:CanSendChannel(nextItem.channel) then
				local ok = false
				if C_ChatInfo and C_ChatInfo.SendAddonMessage then
					ok = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, nextItem.msg, nextItem.channel, nextItem.target)
				elseif SendAddonMessage then
					ok = pcall(SendAddonMessage, ADDON_PREFIX, nextItem.msg, nextItem.channel, nextItem.target)
				end
				if InfinityHive.stats then
					if ok then
						InfinityHive.stats.messagesSent = (InfinityHive.stats.messagesSent or 0) + 1
						InfinityHive.stats.lastOutboundAt = time()
					else
						InfinityHive.stats.failedSends = (InfinityHive.stats.failedSends or 0) + 1
					end
				end
			end
		end

		if cleanupAccum >= 30 then
			cleanupAccum = 0
			local now = GetTime()
			for k, buf in pairs(InfinityHive.reassembly) do
				if (now - buf.created) > 45 then
					InfinityHive.reassembly[k] = nil
				end
			end
			if (now - InfinityHive.lastHeartbeat) >= 120 then
				InfinityHive:SendHeartbeat(false)
			end
		end
	end)

	self.frame = frame

	-- Initialize sub-modules safely
	if _G.InfinityHiveNetworkDB and _G.InfinityHiveNetworkDB.Initialize then pcall(function() _G.InfinityHiveNetworkDB:Initialize() end) end
	if _G.InfinityHiveInventory and _G.InfinityHiveInventory.Initialize then pcall(function() _G.InfinityHiveInventory:Initialize() end) end
	if _G.InfinityHiveProfessions and _G.InfinityHiveProfessions.Initialize then pcall(function() _G.InfinityHiveProfessions:Initialize() end) end
	if _G.InfinityHiveDistress and _G.InfinityHiveDistress.Initialize then pcall(function() _G.InfinityHiveDistress:Initialize() end) end
	if _G.InfinityHiveCooldowns and _G.InfinityHiveCooldowns.Initialize then pcall(function() _G.InfinityHiveCooldowns:Initialize() end) end
	if _G.InfinityHiveLFG and _G.InfinityHiveLFG.Initialize then pcall(function() _G.InfinityHiveLFG:Initialize() end) end
	if _G.InfinityHiveAuction and _G.InfinityHiveAuction.Initialize then pcall(function() _G.InfinityHiveAuction:Initialize() end) end
	if _G.InfinityHiveTooltips and _G.InfinityHiveTooltips.Initialize then pcall(function() _G.InfinityHiveTooltips:Initialize() end) end
	if _G.InfinityHiveUI and _G.InfinityHiveUI.Initialize then pcall(function() _G.InfinityHiveUI:Initialize() end) end
end

return InfinityHive
