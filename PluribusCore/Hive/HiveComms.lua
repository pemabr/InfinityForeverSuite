-- PluribusHive Comms & Core State
-- Unified, rate-limited, chunked guild hive-mind networking over C_ChatInfo ("PLBHIVE")
-- Default-ON sharing with per-category privacy controls and zero addon conflicts

local ADDON_PREFIX = "PLBHIVE"
local MAX_MSG_BYTES = 220
local SEND_INTERVAL_URGENT = 0.25
local SEND_INTERVAL_NORMAL = 0.45
local SEND_INTERVAL_BG = 1.15
local SEND_INTERVAL_COMBAT = 2.50
local AUTO_TRICKLE_INTERVAL = 180 -- Rotate one domain quietly every 3 min in background

-- Safe printable 64-char alphabet (excludes |, ~, \t, \r, \n, \0 for WoW SendAddonMessage safety)
local B64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local B64_INV = {}
for i = 1, #B64 do
	B64_INV[B64:sub(i, i)] = i - 1
end

PluribusHive = PluribusHive or {
	version = _G.PLURIBUS_SUITE_VERSION or "2.2.0",
	latestKnownVersion = _G.PLURIBUS_SUITE_VERSION or "2.2.0",
	initialized = false,
	prefixRegistered = false,
	handlers = {},
	sendQueue = {},
	urgentQueue = {},
	backgroundQueue = {},
	reassembly = {},
	members = {},
	recentEvents = {},
	chunkCounter = 0,
	lastSendTime = 0,
	lastHeartbeat = 0,
	bgTrickleStep = 0,
	stats = {
		messagesSent = 0,
		messagesReceived = 0,
		failedSends = 0,
		bytesRaw = 0,
		bytesSent = 0,
		lastOutboundAt = 0,
		lastInboundAt = 0,
		lastSyncRequestedAt = 0,
		lastSyncCompletedAt = 0,
	},
}
_G.PluribusHive = PluribusHive

-- Pure Lua 5.1 printable-ASCII LZ77 compressor (WoW SendAddonMessage safe, zero external deps)
-- Encodes matches >= 5 chars within 4095-byte window as "~<distHi><distLo><len>" (4 bytes)
function PluribusHive:Compress(input)
	if type(input) ~= "string" or #input < 24 then return input, false end
	local len = #input
	local out = {}
	local i = 1
	local lastSeen = {}

	while i <= len do
		local bestDist, bestLen = 0, 0
		if i + 4 <= len then
			local key = input:sub(i, i + 3)
			local prev = lastSeen[key]
			lastSeen[key] = i
			if prev and (i - prev) <= 4095 then
				local dist = i - prev
				local maxM = math.min(67, len - i + 1)
				local m = 4
				while m < maxM and input:byte(prev + m) == input:byte(i + m) do
					m = m + 1
				end
				if m >= 5 then
					bestDist = dist
					bestLen = m
				end
			end
		end

		if bestLen >= 5 then
			local hi = math.floor(bestDist / 64) + 1
			local lo = (bestDist % 64) + 1
			local lc = (bestLen - 4) + 1
			table.insert(out, "~" .. B64:sub(hi, hi) .. B64:sub(lo, lo) .. B64:sub(lc, lc))
			i = i + bestLen
		else
			local ch = input:sub(i, i)
			if ch == "~" then
				table.insert(out, "~~")
			else
				table.insert(out, ch)
			end
			i = i + 1
		end
	end

	local compressed = table.concat(out)
	if #compressed + 4 < len then
		return compressed, true
	end
	return input, false
end

function PluribusHive:Decompress(input)
	if type(input) ~= "string" or input == "" then return "" end
	local out = {}
	local outStr = ""
	local i = 1
	local len = #input

	while i <= len do
		local ch = input:sub(i, i)
		if ch == "~" then
			local nxt = input:sub(i + 1, i + 1)
			if nxt == "~" then
				outStr = outStr .. "~"
				i = i + 2
			elseif i + 3 <= len then
				local hi = B64_INV[nxt]
				local lo = B64_INV[input:sub(i + 2, i + 2)]
				local lc = B64_INV[input:sub(i + 3, i + 3)]
				if hi and lo and lc then
					local dist = hi * 64 + lo
					local matchLen = lc + 4
					local startPos = #outStr - dist + 1
					if startPos >= 1 then
						-- Byte-by-byte copy supports overlapping RLE-style LZ77 matches
						for k = 0, matchLen - 1 do
							local pos = startPos + k
							outStr = outStr .. outStr:sub(pos, pos)
						end
					end
					i = i + 4
				else
					outStr = outStr .. ch
					i = i + 1
				end
			else
				outStr = outStr .. ch
				i = i + 1
			end
		else
			local nextTilde = input:find("~", i, true)
			if nextTilde then
				outStr = outStr .. input:sub(i, nextTilde - 1)
				i = nextTilde
			else
				outStr = outStr .. input:sub(i)
				break
			end
		end
	end
	return outStr
end

PluribusHive.DEFAULT_CONFIG = {
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
	-- Native UI integration & unified suite settings
	attachSideTabs = true,
	autoScanAH = true,
	bagViewerMode = "grid",
	uiScale = 1.0,
	showMinimapOrb = true,
	compactMode = false,
	classColoredNames = true,
	enableAnalytics = true,
	enableDataCollector = true,
	enableNotifications = true,
	autoSaveInterval = 300,
	-- Distributed Zero-Lag Hive Compute settings
	computeEnabled = true,
	computeBudgetMs = 1.5,
	computeMinFps = 45,
	computePauseInInstances = true,
	computeIdleOnly = false,
	-- Guild Chat @Mention & Smart Sound Ping settings
	mentionsEnabled = true,
	mentionSoundEnabled = true,
	-- Pluribus GearAdvisor Tooltip & Cap Guardian settings
	showGearJudgeTooltips = true,
	-- Quality-of-Life: Auto-sell Poor (gray) junk items upon opening any vendor (hold Shift to bypass)
	autoSellJunk = true,
	-- Quality-of-Life: Auto-repair gear at vendors (hold Shift to bypass)
	-- Modes: "PERSONAL_ONLY" (default) | "PERSONAL_FIRST" | "GUILD_FIRST" | "GUILD_ONLY"
	autoRepair = true,
	autoRepairMode = "PERSONAL_ONLY",
	-- Quality-of-Life: Fast Auto-Loot (instant loot pickup when auto-loot is enabled)
	fastAutoLoot = true,
	-- Localization ("auto" | "deDE" | "enUS")
	language = "auto",
	-- Unified Pluribus Bag, Bank & Guild Bank UI (taint-safe, switchable back to Classic anytime via "Std")
	replaceNativeBags = true,
	-- Smart Pathfinder: avoid high-level zones & mobs and stay on roads
	navAvoidHighLevel = true,
	-- Smart Pathfinder: consider open-world guild Mages (portals) & Warlocks (summons)
	navUseGuildTransit = true,
	-- Raid/Party Marker Bar, Ready Check Inspector & On-Screen Cooldown Selection
	showRaidMarkerBar = true,
	autoShowReadyCheck = true,
	cdScope = "ALL", -- "GROUP" | "GUILD" | "ALL"
}

local function ExtractFirstToken(str)
	if not str or str == "" then return "" end
	local clean = tostring(str):gsub("%-.+$", ""):match("^%s*(.-)%s*$") or ""
	-- WoW Classic character base names never contain spaces; surnames/titles/realm suffixes follow the first space
	local first = clean:match("^(%S+)") or clean
	return first
end

function PluribusHive:NormalizeName(name)
	if not name then return "" end
	local clean = tostring(name):gsub("%-.+$", ""):match("^%s*(.-)%s*$") or ""
	-- Strip trailing realm name even if space-separated (e.g. "Leona Morgenröte" when realm or surname is appended)
	local realm = GetRealmName and GetRealmName() or ""
	if realm ~= "" then
		local rLow = realm:lower()
		local cLow = clean:lower()
		local suffix = " " .. rLow
		if #cLow > #suffix and cLow:sub(-#suffix) == suffix then
			clean = clean:sub(1, #clean - #suffix):match("^%s*(.-)%s*$") or clean
		end
	end
	local first = ExtractFirstToken(clean)
	if first ~= "" then
		-- Canonicalize capitalization only on ASCII a-z so UTF-8 umlauts (Ä/Ö/Ü/ä/ö/ü) are never corrupted
		local b = first:byte(1)
		if b and b >= 97 and b <= 122 then
			first = string.char(b - 32) .. first:sub(2)
		end
		return first
	end
	return clean
end

function PluribusHive:CanonicalKey(name)
	return ExtractFirstToken(self:NormalizeName(name)):lower()
end

function PluribusHive:SamePlayer(a, b)
	local ka = self:CanonicalKey(a)
	local kb = self:CanonicalKey(b)
	return ka ~= "" and ka == kb
end

function PluribusHive:GetPlayerShortName()
	local name = UnitName and UnitName("player") or "Unknown"
	return self:NormalizeName(name)
end

function PluribusHive:GetRealmKey()
	return (GetRealmName and GetRealmName()) or "DefaultRealm"
end

function PluribusHive:GetPlayerClass()
	if UnitClass then
		local _, classFile = UnitClass("player")
		return classFile or "WARRIOR"
	end
	return "WARRIOR"
end

function PluribusHive:GetPlayerRole()
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

function PluribusHive:GetDB()
	_G.PluribusCoreDB = _G.PluribusCoreDB or {}
	_G.PluribusCoreDB.hive = _G.PluribusCoreDB.hive or {}
	local db = _G.PluribusCoreDB.hive
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
	db.knownPeers = db.knownPeers or {}
	return db
end

-- Compare semantic versions ("2.2.0" vs "2.1.0"): returns 1 if a>b, -1 if a<b, 0 if equal
function PluribusHive:CompareVersions(a, b)
	local function parse(v)
		local s = tostring(v or "0.0.0"):gsub("^v", "")
		local maj, min, pat = s:match("(%d+)%.?(%d*)%.?(%d*)")
		return tonumber(maj) or 0, tonumber(min) or 0, tonumber(pat) or 0
	end
	local a1, a2, a3 = parse(a)
	local b1, b2, b3 = parse(b)
	if a1 ~= b1 then return a1 > b1 and 1 or -1 end
	if a2 ~= b2 then return a2 > b2 and 1 or -1 end
	if a3 ~= b3 then return a3 > b3 and 1 or -1 end
	return 0
end

function PluribusHive:GetLatestKnownVersion()
	local best = self.version or "2.2.0"
	if self.latestKnownVersion and self:CompareVersions(self.latestKnownVersion, best) > 0 then
		best = self.latestKnownVersion
	end
	local db = self:GetDB()
	for _, p in pairs(db.knownPeers or {}) do
		if p and p.version and self:CompareVersions(p.version, best) > 0 then
			best = p.version
		end
	end
	self.latestKnownVersion = best
	return best
end

function PluribusHive:RecordPeerVersion(rawName, version, meta)
	local norm = self:NormalizeName(rawName)
	local cKey = self:CanonicalKey(norm)
	if cKey == "" then return end
	local now = time()
	local db = self:GetDB()
	local prev = db.knownPeers[cKey] or {}
	local ver = (version and version ~= "") and tostring(version) or prev.version
	db.knownPeers[cKey] = {
		name = norm,
		version = ver,
		class = (meta and meta.class) or prev.class,
		level = (meta and meta.level) or prev.level,
		zone = (meta and meta.zone) or prev.zone,
		lastSeen = now,
	}
	if ver and self:CompareVersions(ver, self.latestKnownVersion or self.version) > 0 then
		self.latestKnownVersion = ver
	end
end

-- Robust addon prefix registration across 1.12, Classic 1.14/1.15, and Warcraft Forever 1.60.1
-- Note: Modern C_ChatInfo.RegisterAddonMessagePrefix returns Enum.RegisterAddonMessagePrefixResult:
--   0 = Success, 1 = DuplicatePrefix (already registered), or boolean true in Classic!
function PluribusHive:EnsurePrefixRegistered()
	if self.prefixRegistered == true then return true end
	if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
		local okCheck, already = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, ADDON_PREFIX)
		if okCheck and already then
			self.prefixRegistered = true
			return true
		end
	end
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local okCall, res = pcall(C_ChatInfo.RegisterAddonMessagePrefix, ADDON_PREFIX)
		if okCall and (res == true or res == 0 or res == 1 or res == nil) then
			self.prefixRegistered = true
			return true
		end
	elseif RegisterAddonMessagePrefix then
		local okCall, res = pcall(RegisterAddonMessagePrefix, ADDON_PREFIX)
		if okCall and (res == true or res == 0 or res == 1 or res == nil) then
			self.prefixRegistered = true
			return true
		end
	elseif (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage then
		-- 1.12-style client where SendAddonMessage works without explicit prefix registration
		self.prefixRegistered = true
		return true
	end
	return self.prefixRegistered == true
end

function PluribusHive:GetConfig()
	return self:GetDB().config
end

function PluribusHive:SetConfig(key, value)
	local cfg = self:GetConfig()
	cfg[key] = value
	if _G.PluribusMessaging then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_CONFIG_CHANGED", key, value) end)
	end
end

function PluribusHive:AddFeedEvent(category, text, extra)
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

function PluribusHive:RegisterHandler(msgType, fn)
	if not msgType or type(fn) ~= "function" then return end
	self.handlers[msgType] = self.handlers[msgType] or {}
	table.insert(self.handlers[msgType], fn)
end

function PluribusHive:CanSendChannel(channel)
	if channel == "GUILD" then
		return IsInGuild and IsInGuild() or false
	elseif channel == "RAID" then
		return IsInRaid and IsInRaid() or false
	elseif channel == "PARTY" then
		return IsInGroup and IsInGroup() or false
	end
	return true
end

local function SanitizeWireText(str)
	if type(str) ~= "string" then return "" end
	-- Modern WoW 1.15/1.60.1 C_ChatInfo.SendAddonMessage rejects control bytes (<0x20, including \t, \r, \n, \0) with InvalidMessage
	return (str:gsub("[%z\001-\031]", " "))
end

function PluribusHive:SendRaw(payload, channel, target, urgent, background, dedupKey)
	channel = channel or "GUILD"
	if not self:CanSendChannel(channel) then return false end
	if not payload or payload == "" then return false end

	payload = SanitizeWireText(payload)
	if payload == "" then return false end

	if self.stats then
		self.stats.bytesRaw = (self.stats.bytesRaw or 0) + #payload
	end

	-- Automatically LZ-compress larger payloads before chunking (100% printable ASCII framing: "Z:" instead of illegal "\t")
	local wirePayload = payload
	if #payload >= 48 then
		local comp, used = self:Compress(payload)
		if used then
			wirePayload = "Z:" .. comp
		end
	end

	local queue = urgent and self.urgentQueue or (background and self.backgroundQueue or self.sendQueue)

	-- Coalesce older unsent background snapshots of the same dedupKey so queues never bloat
	if dedupKey and #queue > 0 then
		for i = #queue, 1, -1 do
			if queue[i].dedupKey == dedupKey then
				table.remove(queue, i)
			end
		end
	end

	if #wirePayload <= MAX_MSG_BYTES then
		table.insert(queue, { msg = wirePayload, channel = channel, target = target, dedupKey = dedupKey })
		return true
	end

	-- Automatic chunking for larger payloads using printable-ASCII ":" framing (zero control chars!)
	self.chunkCounter = (self.chunkCounter + 1) % 9999
	local cid = tostring(self.chunkCounter)
	local chunkBodySize = MAX_MSG_BYTES - 18
	local total = math.ceil(#wirePayload / chunkBodySize)
	for i = 1, total do
		local startIdx = (i - 1) * chunkBodySize + 1
		local slice = wirePayload:sub(startIdx, startIdx + chunkBodySize - 1)
		local packet = string.format("C:%s:%d:%d:%s", cid, i, total, slice)
		table.insert(queue, { msg = packet, channel = channel, target = target, dedupKey = dedupKey })
	end
	return true
end

function PluribusHive:Send(msgType, body, channel, target, urgent)
	local cleanType = tostring(msgType or ""):gsub("[:%s%c]", "")
	local payload = cleanType .. ":" .. SanitizeWireText(body or "")
	-- Always prioritize peer discovery & handshake packets ahead of bulk background chunks
	local isDiscovery = (cleanType == "PING" or cleanType == "VER_REQ" or cleanType == "SYNC_REQ")
	local isUrgent = urgent == true or isDiscovery
	-- Route large bulk sync & compute messages through the gentle background trickle queue automatically
	local isBulk = (not isUrgent) and (cleanType == "BAGS" or cleanType == "BANK" or cleanType == "PROF" or cleanType == "RECIPES" or cleanType == "AH" or cleanType == "AHBATCH" or cleanType == "DBRES" or cleanType == "JOBRES" or cleanType == "TELEM")
	return self:SendRaw(payload, channel or "GUILD", target, isUrgent, isBulk, isBulk and cleanType or nil)
end

function PluribusHive:SendBackground(msgType, body, dedupKey, channel)
	local cleanType = tostring(msgType or ""):gsub("[:%s%c]", "")
	local payload = cleanType .. ":" .. SanitizeWireText(body or "")
	return self:SendRaw(payload, channel or "GUILD", nil, false, true, dedupKey or cleanType)
end

function PluribusHive:UnpackAndDispatch(senderShort, fullPayload, distribution)
	if not fullPayload or fullPayload == "" then return end
	if fullPayload:sub(1, 2) == "Z:" or fullPayload:sub(1, 2) == "Z\t" then
		fullPayload = self:Decompress(fullPayload:sub(3))
	end
	-- Support both new printable ":" framing and legacy "\t" framing for seamless upgrades
	local msgType, body = fullPayload:match("^([A-Za-z0-9_]+):(.*)$")
	if not msgType then
		msgType, body = fullPayload:match("^([^\t]+)\t?(.*)$")
	end
	if msgType and msgType ~= "" then
		self:DispatchMessage(senderShort, msgType, body or "", distribution)
	end
end

function PluribusHive:DispatchMessage(senderShort, msgType, body, distribution)
	-- Track member presence and inbound sync telemetry canonically (prevents duplicate member keys)
	local now = time()
	local cKey = self:CanonicalKey(senderShort)
	if cKey == "" then return end
	self.members[cKey] = self.members[cKey] or { name = senderShort }
	self.members[cKey].name = senderShort
	self.members[cKey].lastSeen = now
	self:RecordPeerVersion(senderShort, self.members[cKey].version, self.members[cKey])
	if self.stats then
		self.stats.messagesReceived = (self.stats.messagesReceived or 0) + 1
		self.stats.lastInboundAt = now
		if msgType == "BAGS" or msgType == "BANK" or msgType == "PROF" or msgType == "RECIPES" or msgType == "TAXLOG" or msgType == "DBRES" or msgType == "PING" then
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

function PluribusHive:OnAddonMessage(prefix, message, distribution, sender)
	if prefix ~= ADDON_PREFIX or type(message) ~= "string" then return end
	local senderShort = self:NormalizeName(sender)
	if senderShort == "" or self:SamePlayer(senderShort, self:GetPlayerShortName()) then
		return
	end

	-- Chunked packet reassembly: supports both printable "C:cid:idx:total:slice" and legacy "C\tcid\tidx\ttotal\tslice"
	local head2 = message:sub(1, 2)
	if head2 == "C:" or head2 == "C\t" then
		local cid, idxStr, totalStr, slice
		if head2 == "C:" then
			cid, idxStr, totalStr, slice = message:match("^C:([^:]+):(%d+):(%d+):(.*)$")
		else
			cid, idxStr, totalStr, slice = message:match("^C\t([^%s]+)\t(%d+)\t(%d+)\t(.*)$")
		end
		local idx, total = tonumber(idxStr), tonumber(totalStr)
		if not cid or not idx or not total or total > 64 then return end
		local key = self:CanonicalKey(senderShort) .. ":" .. cid
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
			self:UnpackAndDispatch(senderShort, table.concat(ordered), distribution)
		end
		return
	end

	self:UnpackAndDispatch(senderShort, message, distribution)
end

function PluribusHive:SendHeartbeat(requestFullSync)
	local inGuild = IsInGuild and IsInGuild() or false
	local grpChannel = nil
	if IsInRaid and IsInRaid() then
		grpChannel = "RAID"
	elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then
		grpChannel = "PARTY"
	end
	if not inGuild and not grpChannel then return end

	local cls = self:GetPlayerClass()
	local lvl = UnitLevel and UnitLevel("player") or 60
	local zone = GetRealZoneText and GetRealZoneText() or "Azeroth"
	local x, y, mapID = 0, 0, 0
	if PluribusUtils and PluribusUtils.GetUnitMapPosition then
		local px, py, mid = PluribusUtils:GetUnitMapPosition("player")
		x, y, mapID = px or 0, py or 0, mid or 0
	end
	local role = self:GetPlayerRole()
	local inInst = 0
	if IsInInstance then
		local okI, isInst, instType = pcall(IsInInstance)
		if okI and (isInst == true or (instType and instType ~= "" and instType ~= "none")) then
			inInst = 1
		end
	end
	local body = string.format("%s|%d|%s|%d|%.3f|%.3f|%s|%s|%d|%d",
		cls, lvl, zone:gsub("|", " "), mapID, x, y, role, self.version, requestFullSync and 1 or 0, inInst)
	if inGuild then
		self:Send("PING", body, "GUILD", nil, true)
	end
	if grpChannel then
		self:Send("PING", body, grpChannel, nil, true)
	end
	self.lastHeartbeat = GetTime()
end

function PluribusHive:RequestFullGuildSync()
	if not (IsInGuild and IsInGuild()) then return end
	if self.stats then
		self.stats.lastSyncRequestedAt = time()
	end
	self:EnsurePrefixRegistered()
	self:SendHeartbeat(true)
	self:Send("SYNC_REQ", self.version, "GUILD", nil, true)
end

function PluribusHive:RequestVersionCheck()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		pcall(C_GuildInfo.GuildRoster)
	elseif GuildRoster then
		pcall(GuildRoster)
	end
	self:EnsurePrefixRegistered()
	if IsInGuild and IsInGuild() then
		self:Send("VER_REQ", self.version, "GUILD", nil, true)
	end
	self:SendHeartbeat(false)
end

-- Full Guild Member Roster merged with live Hive presence & persisted addon versions
-- Classifies every guild member as: "CURRENT" (up-to-date), "OUTDATED", or "NONE" (no addon detected)
function PluribusHive:GetGuildMemberRoster()
	local now = time()
	local db = self:GetDB()
	local me = self:GetPlayerShortName()
	local meKey = self:CanonicalKey(me)
	local latestVer = self:GetLatestKnownVersion()

	-- Always keep self fresh in knownPeers
	self:RecordPeerVersion(me, self.version, {
		class = self:GetPlayerClass(),
		level = UnitLevel and UnitLevel("player") or 60,
		zone = GetRealZoneText and GetRealZoneText() or "Azeroth",
	})

	local liveByCanon = {}
	for rawName, info in pairs(self.members or {}) do
		local cKey = self:CanonicalKey(rawName)
		if cKey ~= "" and (now - (info.lastSeen or 0)) <= 600 then
			liveByCanon[cKey] = info
		end
	end

	local byCanon = {}
	local order = {}

	local function UpsertMember(entry)
		local cKey = self:CanonicalKey(entry.name)
		if cKey == "" then return end
		local existing = byCanon[cKey]
		if existing then
			if entry.online and not existing.online then existing.online = true end
			if entry.isSelf then existing.isSelf = true end
			if (not existing.rank or existing.rank == "") and entry.rank then existing.rank = entry.rank end
			if (not existing.zone or existing.zone == "" or existing.zone == "Azeroth") and entry.zone and entry.zone ~= "" then
				existing.zone = entry.zone
			end
			if entry.level and entry.level > (existing.level or 0) then existing.level = entry.level end
			if entry.class and entry.class ~= "" then existing.class = entry.class end
			return
		end
		entry.name = self:NormalizeName(entry.name)
		entry.canonKey = cKey
		byCanon[cKey] = entry
		table.insert(order, entry)
	end

	-- 1. Read WoW Guild Roster (compatible with 1.12, 1.14/1.15, and Warcraft Forever 1.60.1)
	if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
		local totalGuild = GetNumGuildMembers() or 0
		for i = 1, totalGuild do
			local ok, fullName, rank, rankIndex, level, classDisplay, zone, note, officerNote, online, status, classFile =
				pcall(GetGuildRosterInfo, i)
			if ok and fullName and fullName ~= "" then
				local isOnline = (online == true or online == 1)
				local cls = classFile
				if (not cls or cls == "") and classDisplay then
					cls = tostring(classDisplay):upper()
				end
				UpsertMember({
					name = fullName,
					rawName = fullName,
					rank = rank or "",
					rankIndex = tonumber(rankIndex) or 99,
					level = tonumber(level) or 0,
					class = cls or "WARRIOR",
					zone = (zone and zone ~= "") and zone or (isOnline and "Azeroth" or ""),
					note = note or "",
					online = isOnline,
					isSelf = self:SamePlayer(fullName, me),
				})
			end
		end
	end

	-- 2. Always guarantee self is in the list even before GuildRoster() arrives
	local px, py, mid = 0, 0, 0
	if PluribusUtils and PluribusUtils.GetUnitMapPosition then
		local x, y, m = PluribusUtils:GetUnitMapPosition("player")
		px, py, mid = x or 0, y or 0, m or 0
	end
	UpsertMember({
		name = me,
		rank = "",
		rankIndex = 0,
		level = UnitLevel and UnitLevel("player") or 60,
		class = self:GetPlayerClass(),
		zone = GetRealZoneText and GetRealZoneText() or "Azeroth",
		online = true,
		isSelf = true,
		x = px,
		y = py,
		mapID = mid,
	})

	-- 3. Include any live Hive peer not yet returned by GuildRoster()
	for cKey, info in pairs(liveByCanon) do
		if not byCanon[cKey] then
			UpsertMember({
				name = info.name or cKey,
				rank = "",
				rankIndex = 50,
				level = info.level or 60,
				class = info.class or "WARRIOR",
				zone = info.zone or "Azeroth",
				online = true,
				isSelf = (cKey == meKey),
			})
		end
	end

	-- 4. Attach Addon Version & Status Classification ("CURRENT" | "OUTDATED" | "NONE")
	local stats = {
		total = 0,
		online = 0,
		withAddon = 0,
		withAddonOnline = 0,
		current = 0,
		outdated = 0,
		none = 0,
		latestVersion = latestVer,
		isSelfOutdated = self:CompareVersions(self.version, latestVer) < 0,
	}

	for _, m in ipairs(order) do
		local cKey = m.canonKey
		local live = liveByCanon[cKey]
		local known = (db.knownPeers or {})[cKey]
		if live then
			m.x = live.x
			m.y = live.y
			m.mapID = live.mapID
			m.role = live.role
			m.inInstance = live.inInstance == true
			m.liveHive = true
			if live.zone and live.zone ~= "" then m.zone = live.zone end
			if live.class and live.class ~= "" then m.class = live.class end
			if live.level and live.level > 0 then m.level = live.level end
		end

		local ver = nil
		if m.isSelf then
			ver = self.version
			m.liveHive = true
			m.online = true
		elseif live and live.version and live.version ~= "" then
			ver = live.version
		elseif known and known.version and known.version ~= "" then
			ver = known.version
		end

		m.addonVersion = ver
		m.lastHiveSeen = (live and live.lastSeen) or (known and known.lastSeen) or nil

		if ver and ver ~= "" then
			if self:CompareVersions(ver, latestVer) < 0 then
				m.addonStatus = "OUTDATED"
				stats.outdated = stats.outdated + 1
			else
				m.addonStatus = "CURRENT"
				stats.current = stats.current + 1
			end
			stats.withAddon = stats.withAddon + 1
			if m.online then
				stats.withAddonOnline = stats.withAddonOnline + 1
			end
		else
			m.addonStatus = "NONE"
			stats.none = stats.none + 1
		end

		stats.total = stats.total + 1
		if m.online then stats.online = stats.online + 1 end
	end

	local statusWeight = { CURRENT = 1, OUTDATED = 2, NONE = 3 }
	table.sort(order, function(a, b)
		if a.online ~= b.online then return a.online end
		if a.isSelf ~= b.isSelf then return a.isSelf end
		local wa = statusWeight[a.addonStatus] or 9
		local wb = statusWeight[b.addonStatus] or 9
		if wa ~= wb then return wa < wb end
		return (a.name or "") < (b.name or "")
	end)

	return order, stats
end

-- Real-time connectivity and data-sync health summary for dashboard status indicators
function PluribusHive:GetNetworkHealth()
	local now = time()
	local inGuild = IsInGuild and IsInGuild() or false
	local prefixOk = self:EnsurePrefixRegistered()
	local members = self:GetOnlineMembers()
	local peers = math.max(0, #members - 1)
	local connectedNodes = inGuild and (1 + peers) or 1
	local queued = #(self.urgentQueue or {}) + #(self.sendQueue or {}) + #(self.backgroundQueue or {})

	local reassemblyCount = 0
	for _ in pairs(self.reassembly or {}) do
		reassemblyCount = reassemblyCount + 1
	end

	local dbStats = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.GetStats)
		and _G.PluribusHiveNetworkDB:GetStats()
		or { revision = 1, items = 0, quests = 0, npcs = 0, missing = 0 }

	local st = self.stats or {}
	local lastActivity = math.max(st.lastSyncCompletedAt or 0, st.lastInboundAt or 0, st.lastOutboundAt or 0)
	local lastSyncAge = (lastActivity > 0) and math.max(0, now - lastActivity) or nil

	local latestVer = self:GetLatestKnownVersion()
	local isSelfOutdated = self:CompareVersions(self.version, latestVer) < 0
	local outdatedPeers = 0
	for _, m in ipairs(members) do
		if not m.isSelf and m.version and self:CompareVersions(m.version, latestVer) < 0 then
			outdatedPeers = outdatedPeers + 1
		end
	end

	local L = _G.PluribusL
	local state, label, shortLabel, color, hex, score
	if not self.initialized or not prefixOk then
		state = "OFFLINE"
		label = "Offline (Addon Comms Unavailable)"
		shortLabel = "Offline"
		color = { 0.97, 0.44, 0.44 }
		hex = "|cfff87171"
		score = 0
	elseif not inGuild then
		state = "LOCAL"
		label = L and L:Get("HIVE_LOCAL_NO_GUILD") or "Local Active (No Guild)"
		shortLabel = "Local"
		color = { 0.98, 0.75, 0.14 }
		hex = "|cfffbbf24"
		score = 65
	elseif (st.failedSends or 0) >= 5 then
		state = "DEGRADED"
		label = "Degraded (Send Errors)"
		shortLabel = "Degraded"
		color = { 0.98, 0.75, 0.14 }
		hex = "|cfffbbf24"
		score = 65
	elseif queued > 0 or reassemblyCount > 0 then
		state = "SYNCING"
		label = string.format("Syncing (%d queued)", queued + reassemblyCount)
		shortLabel = "Syncing"
		color = { 0.22, 0.74, 0.97 }
		hex = "|cff38bdf8"
		score = 96
	elseif peers == 0 then
		-- You ARE online & connected to the Guild PLBHIVE channel (1/1 active Hive node!)
		state = "HEALTHY"
		label = L and L:Get("HIVE_ONLINE_SOLO") or "Online (1/1 · Solo Node)"
		shortLabel = "Online (1)"
		color = { 0.29, 0.87, 0.50 }
		hex = "|cff4ade80"
		score = 100
	else
		state = "HEALTHY"
		label = L and L:Get("HIVE_ONLINE_PEERS", connectedNodes) or string.format("Online & Synced (%d connected)", connectedNodes)
		shortLabel = string.format("Online (%d)", connectedNodes)
		color = { 0.29, 0.87, 0.50 }
		hex = "|cff4ade80"
		score = 100
	end

	local syncFreshness
	if not lastSyncAge then
		syncFreshness = peers == 0 and "Bereit (Solo)" or "Awaiting sync"
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
		connectedNodes = connectedNodes,
		outdatedPeers = outdatedPeers,
		latestVersion = latestVer,
		isSelfOutdated = isSelfOutdated,
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
		summary = string.format("HiveMind: %s · %d/%d · Rev v%d", shortLabel, connectedNodes, connectedNodes, dbStats.revision or 1),
	}
end

function PluribusHive:GetOnlineMembers()
	local list = {}
	local now = time()
	-- Include self
	local me = self:GetPlayerShortName()
	local px, py, mid = 0, 0, 0
	if PluribusUtils and PluribusUtils.GetUnitMapPosition then
		local x, y, m = PluribusUtils:GetUnitMapPosition("player")
		px, py, mid = x or 0, y or 0, m or 0
	end
	local selfInInst = false
	if IsInInstance then
		local okI, isInst, instType = pcall(IsInInstance)
		if okI and (isInst == true or (instType and instType ~= "" and instType ~= "none")) then
			selfInInst = true
		end
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
		inInstance = selfInInst,
		version = self.version,
		lastSeen = now,
		isSelf = true,
	})
	local seenCanon = {}
	seenCanon[self:CanonicalKey(me)] = true
	for name, info in pairs(self.members) do
		local cKey = self:CanonicalKey(name)
		if not self:SamePlayer(name, me) and cKey ~= "" and not seenCanon[cKey] and (now - (info.lastSeen or 0)) <= 600 then
			seenCanon[cKey] = true
			info.name = self:NormalizeName(info.name or name)
			table.insert(list, info)
		end
	end
	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
	return list
end

-- Trigger an immediate urgent peer discovery + roster refresh across Guild and Party/Raid
function PluribusHive:ForcePeerDiscovery()
	self:EnsurePrefixRegistered()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		pcall(C_GuildInfo.GuildRoster)
	elseif GuildRoster then
		pcall(GuildRoster)
	end
	local inGuild = IsInGuild and IsInGuild() or false
	self:SendHeartbeat(true)
	if inGuild then
		self:Send("VER_REQ", self.version, "GUILD", nil, true)
		self:Send("SYNC_REQ", self.version, "GUILD", nil, true)
	end
	local members = self:GetOnlineMembers()
	local stats = self.stats or {}
	return {
		inGuild = inGuild,
		peersOnline = math.max(0, #members - 1),
		sent = stats.sent or 0,
		failed = stats.failedSends or 0,
		lastError = stats.lastSendError,
	}
end

function PluribusHive:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:GetDB()

	-- Register PLBHIVE addon message prefix (handles Classic bool, 1.15/1.60.1 Enum=0/1, and 1.12 nil)
	self:EnsurePrefixRegistered()

	-- Handle presence heartbeats & version tracking (stored under canonical key to prevent duplicates)
	self:RegisterHandler("PING", function(sender, body)
		local cls, lvl, zone, mapID, x, y, role, ver, wantsSync, inInst =
			body:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?([^|]*)|?(.*)$")
		local peerVer = (ver and ver ~= "") and ver or "2.0.0"
		local cKey = self:CanonicalKey(sender)
		if cKey == "" then return end
		self.members[cKey] = {
			name = sender,
			class = cls ~= "" and cls or "WARRIOR",
			level = tonumber(lvl) or 60,
			zone = zone ~= "" and zone or "Azeroth",
			mapID = tonumber(mapID) or 0,
			x = tonumber(x) or 0,
			y = tonumber(y) or 0,
			role = role ~= "" and role or "DPS",
			inInstance = (inInst == "1"),
			version = peerVer,
			lastSeen = time(),
		}
		self:RecordPeerVersion(sender, peerVer, self.members[cKey])
		if _G.PluribusMessaging then
			pcall(function() _G.PluribusMessaging:Publish("HIVE_ROSTER_UPDATED", sender, peerVer) end)
		end
		if wantsSync == "1" and _G.PluribusMessaging then
			pcall(function() _G.PluribusMessaging:Publish("HIVE_PEER_REQUESTED_SYNC", sender) end)
		end
	end)

	self:RegisterHandler("VER_REQ", function(sender, peerVer)
		if peerVer and peerVer ~= "" then
			self:RecordPeerVersion(sender, peerVer)
		end
		-- Reply promptly with our current version & status
		self:SendHeartbeat(false)
	end)

	self:RegisterHandler("SYNC_REQ", function(sender, peerVer)
		if peerVer and peerVer ~= "" then
			self:RecordPeerVersion(sender, peerVer)
		end
		self:SendHeartbeat(false)
		if _G.PluribusMessaging then
			pcall(function() _G.PluribusMessaging:Publish("HIVE_PEER_REQUESTED_SYNC", sender) end)
		end
	end)

	-- Event & rate-limited pump frame
	local frame = CreateFrame("Frame")
	pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
	pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
	pcall(frame.RegisterEvent, frame, "ZONE_CHANGED_NEW_AREA")
	pcall(frame.RegisterEvent, frame, "GUILD_ROSTER_UPDATE")
	pcall(frame.RegisterEvent, frame, "GROUP_ROSTER_UPDATE")

	self._guildDiscoverySent = false

	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			PluribusHive:OnAddonMessage(...)
		elseif event == "PLAYER_ENTERING_WORLD" then
			PluribusHive:EnsurePrefixRegistered()
			if C_GuildInfo and C_GuildInfo.GuildRoster then
				pcall(C_GuildInfo.GuildRoster)
			elseif GuildRoster then
				pcall(GuildRoster)
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(3, function()
					PluribusHive:RequestFullGuildSync()
					PluribusHive:Send("VER_REQ", PluribusHive.version, "GUILD", nil, true)
				end)
				C_Timer.After(12, function()
					if IsInGuild and IsInGuild() then
						PluribusHive:SendHeartbeat(false)
						PluribusHive:Send("VER_REQ", PluribusHive.version, "GUILD", nil, true)
					end
				end)
			end
		elseif event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
			PluribusHive:SendHeartbeat(false)
		elseif event == "GUILD_ROSTER_UPDATE" then
			if not PluribusHive._guildDiscoverySent and IsInGuild and IsInGuild() then
				PluribusHive._guildDiscoverySent = true
				PluribusHive:EnsurePrefixRegistered()
				PluribusHive:RequestFullGuildSync()
				PluribusHive:Send("VER_REQ", PluribusHive.version, "GUILD", nil, true)
			end
			if _G.PluribusMessaging then
				pcall(function() _G.PluribusMessaging:Publish("HIVE_ROSTER_UPDATED") end)
			end
		end
	end)

	local pumpAccum = 0
	local cleanupAccum = 0
	local trickleAccum = 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		pumpAccum = pumpAccum + (elapsed or 0)
		cleanupAccum = cleanupAccum + (elapsed or 0)
		trickleAccum = trickleAccum + (elapsed or 0)

		-- Combat-aware adaptive trickle rate: urgent fast, normal steady, bulk background gentle bit-by-bit
		local inCombat = InCombatLockdown and InCombatLockdown() or false
		local nextItem = nil
		local sourceQueue = nil
		local neededInterval = SEND_INTERVAL_BG
		if #(PluribusHive.urgentQueue or {}) > 0 then
			neededInterval = SEND_INTERVAL_URGENT
			if pumpAccum >= neededInterval then
				sourceQueue = PluribusHive.urgentQueue
				nextItem = table.remove(sourceQueue, 1)
			end
		elseif #(PluribusHive.sendQueue or {}) > 0 then
			neededInterval = inCombat and SEND_INTERVAL_COMBAT or SEND_INTERVAL_NORMAL
			if pumpAccum >= neededInterval then
				sourceQueue = PluribusHive.sendQueue
				nextItem = table.remove(sourceQueue, 1)
			end
		elseif #(PluribusHive.backgroundQueue or {}) > 0 then
			neededInterval = inCombat and SEND_INTERVAL_COMBAT or SEND_INTERVAL_BG
			if pumpAccum >= neededInterval then
				sourceQueue = PluribusHive.backgroundQueue
				nextItem = table.remove(sourceQueue, 1)
			end
		end

		if nextItem then
			pumpAccum = 0
			if not PluribusHive.prefixRegistered then
				PluribusHive:EnsurePrefixRegistered()
			end
			if PluribusHive:CanSendChannel(nextItem.channel) then
				local ok, res = false, nil
				local wireMsg = SanitizeWireText(nextItem.msg)
				if C_ChatInfo and C_ChatInfo.SendAddonMessage then
					if nextItem.target ~= nil and nextItem.target ~= "" then
						ok, res = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, wireMsg, nextItem.channel, nextItem.target)
					else
						ok, res = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, wireMsg, nextItem.channel)
					end
				elseif SendAddonMessage then
					if nextItem.target ~= nil and nextItem.target ~= "" then
						ok, res = pcall(SendAddonMessage, ADDON_PREFIX, wireMsg, nextItem.channel, nextItem.target)
					else
						ok, res = pcall(SendAddonMessage, ADDON_PREFIX, wireMsg, nextItem.channel)
					end
				end

				-- Enum.SendAddonMessageResult: 0 = Success, 3 = AddonMessageThrottle, 9 = ChannelThrottleExceeded
				local sentOk = ok and (res == true or res == 0 or res == nil)
				local throttled = ok and (res == 3 or res == 9)
				if throttled and sourceQueue then
					nextItem._retries = (nextItem._retries or 0) + 1
					if nextItem._retries <= 4 then
						table.insert(sourceQueue, 1, nextItem)
						pumpAccum = -1.5
					elseif PluribusHive.stats then
						PluribusHive.stats.failedSends = (PluribusHive.stats.failedSends or 0) + 1
						PluribusHive.stats.lastSendError = res
					end
				elseif PluribusHive.stats then
					if sentOk then
						PluribusHive.stats.messagesSent = (PluribusHive.stats.messagesSent or 0) + 1
						PluribusHive.stats.bytesSent = (PluribusHive.stats.bytesSent or 0) + #wireMsg
						PluribusHive.stats.lastOutboundAt = time()
					else
						PluribusHive.stats.failedSends = (PluribusHive.stats.failedSends or 0) + 1
						PluribusHive.stats.lastSendError = res
					end
				end
			end
		end

		-- Quiet automatic staggered background sync: rotates ONE domain every few minutes so client is never spiked
		if trickleAccum >= AUTO_TRICKLE_INTERVAL then
			trickleAccum = 0
			if not inCombat and IsInGuild and IsInGuild() and #(PluribusHive.backgroundQueue or {}) < 8 then
				PluribusHive.bgTrickleStep = (PluribusHive.bgTrickleStep % 5) + 1
				local step = PluribusHive.bgTrickleStep
				if step == 1 and _G.PluribusHiveInventory and _G.PluribusHiveInventory.BroadcastBags then
					pcall(function() _G.PluribusHiveInventory:BroadcastBags() end)
				elseif step == 2 and _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.BroadcastProfessions then
					pcall(function() _G.PluribusHiveProfessions:BroadcastProfessions() end)
				elseif step == 3 and _G.PluribusHiveTax and _G.PluribusHiveTax.BroadcastMyLedger then
					pcall(function() _G.PluribusHiveTax:BroadcastMyLedger() end)
				elseif step == 4 and _G.PluribusHiveMail and _G.PluribusHiveMail.FlushOutboxFor then
					pcall(function() _G.PluribusHiveMail:FlushOutboxFor(nil) end)
				elseif step == 5 and _G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.CheckForNetworkUpdates then
					pcall(function() _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end)
				end
			end
		end

		if cleanupAccum >= 30 then
			cleanupAccum = 0
			local now = GetTime()
			for k, buf in pairs(PluribusHive.reassembly) do
				if (now - buf.created) > 45 then
					PluribusHive.reassembly[k] = nil
				end
			end
			if (now - PluribusHive.lastHeartbeat) >= 120 then
				PluribusHive:SendHeartbeat(false)
			end
		end
	end)

	self.frame = frame

	-- Initialize sub-modules safely
	if _G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.Initialize then pcall(function() _G.PluribusHiveNetworkDB:Initialize() end) end
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.Initialize then pcall(function() _G.PluribusHiveInventory:Initialize() end) end
	if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.Initialize then pcall(function() _G.PluribusHiveProfessions:Initialize() end) end
	if _G.PluribusHiveMail and _G.PluribusHiveMail.Initialize then pcall(function() _G.PluribusHiveMail:Initialize() end) end
	if _G.PluribusHiveTax and _G.PluribusHiveTax.Initialize then pcall(function() _G.PluribusHiveTax:Initialize() end) end
	if _G.PluribusHiveDistress and _G.PluribusHiveDistress.Initialize then pcall(function() _G.PluribusHiveDistress:Initialize() end) end
	if _G.PluribusHiveCooldowns and _G.PluribusHiveCooldowns.Initialize then pcall(function() _G.PluribusHiveCooldowns:Initialize() end) end
	if _G.PluribusHiveRaidTools and _G.PluribusHiveRaidTools.Initialize then pcall(function() _G.PluribusHiveRaidTools:Initialize() end) end
	if _G.PluribusHealDecursive and _G.PluribusHealDecursive.Initialize then pcall(function() _G.PluribusHealDecursive:Initialize() end) end
	if _G.PluribusHiveLFG and _G.PluribusHiveLFG.Initialize then pcall(function() _G.PluribusHiveLFG:Initialize() end) end
	if _G.PluribusHiveAuction and _G.PluribusHiveAuction.Initialize then pcall(function() _G.PluribusHiveAuction:Initialize() end) end
	if _G.PluribusHiveTooltips and _G.PluribusHiveTooltips.Initialize then pcall(function() _G.PluribusHiveTooltips:Initialize() end) end
	if _G.PluribusHiveUI and _G.PluribusHiveUI.Initialize then pcall(function() _G.PluribusHiveUI:Initialize() end) end
	if _G.PluribusHiveNativeTabs and _G.PluribusHiveNativeTabs.Initialize then pcall(function() _G.PluribusHiveNativeTabs:Initialize() end) end
	if _G.PluribusHiveCompute and _G.PluribusHiveCompute.Initialize then pcall(function() _G.PluribusHiveCompute:Initialize() end) end
	if _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.Initialize then pcall(function() _G.PluribusHiveGuildTransit:Initialize() end) end
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.Initialize then pcall(function() _G.PluribusHivePathfinder:Initialize() end) end
	if _G.PluribusHiveDynamicRoute and _G.PluribusHiveDynamicRoute.Initialize then pcall(function() _G.PluribusHiveDynamicRoute:Initialize() end) end
	if _G.PluribusHiveMentions and _G.PluribusHiveMentions.Initialize then pcall(function() _G.PluribusHiveMentions:Initialize() end) end
	if _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.Initialize then pcall(function() _G.PluribusHiveGearJudge:Initialize() end) end
end

return PluribusHive
