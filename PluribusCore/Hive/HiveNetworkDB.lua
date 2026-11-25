-- PluribusHive On-Demand Network Game Database
-- Guild P2P on-demand item/quest/NPC lookup (DBREQ / DBRES) + periodic revision sync (DBVER)
-- Works standalone with built-in/Wowhead-synced PluribusWowheadCache AND integrates optional QuestieDB / WoWHeadDB / GathererDB

PluribusHiveNetworkDB = {
	initialized = false,
	pendingRequests = {},
	missingQueue = {},
	lastVersionCheck = 0,
	lastPeerBroadcast = 0,
	dataRevision = 1,
	_countsInitialized = false,
	_counts = { items = 0, quests = 0, npcs = 0, missing = 0 },
}
_G.PluribusHiveNetworkDB = PluribusHiveNetworkDB

function PluribusHiveNetworkDB:GetDataRevision()
	return self.dataRevision or 1
end

function PluribusHiveNetworkDB:EnsureCounts(forceRefresh)
	if self._countsInitialized and not forceRefresh then
		return self._counts
	end
	local store = self:GetStore()
	local items, quests, npcs, missing = 0, 0, 0, 0
	for _ in pairs(store.items) do items = items + 1 end
	for _ in pairs(store.quests) do quests = quests + 1 end
	for _ in pairs(store.npcs) do npcs = npcs + 1 end
	for _ in pairs(self.missingQueue) do missing = missing + 1 end
	self._counts = { items = items, quests = quests, npcs = npcs, missing = missing }
	self._countsInitialized = true
	return self._counts
end

function PluribusHiveNetworkDB:SyncCachedStats()
	local store = self:GetStore()
	local c = self._counts or { items = 0, quests = 0, npcs = 0, missing = 0 }
	local stats = self._cachedStats
	if not stats then
		stats = {}
		self._cachedStats = stats
	end
	stats.revision = store.revision or 1
	stats.items = c.items or 0
	stats.quests = c.quests or 0
	stats.npcs = c.npcs or 0
	stats.missing = c.missing or 0
	stats.hasQuestieDB = _G.QuestieDB ~= nil
	stats.hasWowheadDB = (_G.WoWHeadDB ~= nil or _G.WowHeadDB ~= nil)
	stats.hasGathererDB = (_G.GathererDB ~= nil or _G.GatherMate2 ~= nil)
	return stats
end

local VERSION_CHECK_INTERVAL = 900 -- 15 minutes periodic network update check

local function SafeClean(str)
	return tostring(str or ""):gsub("[|\t\r\n]", " "):sub(1, 140)
end

function PluribusHiveNetworkDB:GetStore()
	local db = PluribusHive:GetDB()
	db.gameDB = db.gameDB or { revision = 1, updatedAt = 0, items = {}, quests = {}, npcs = {} }
	db.gameDB.items = db.gameDB.items or {}
	db.gameDB.quests = db.gameDB.quests or {}
	db.gameDB.npcs = db.gameDB.npcs or {}
	return db.gameDB
end

-- Merge bundled / companion-fetched PluribusWowheadCache into persistent Hive DB
function PluribusHiveNetworkDB:SeedFromWowheadCache()
	local cache = _G.PluribusWowheadCache
	if type(cache) ~= "table" then return 0 end
	local store = self:GetStore()
	local added = 0

	if (cache.revision or 1) > (store.revision or 0) then
		store.revision = cache.revision
		store.updatedAt = cache.updatedAt or time()
	end

	local newItems, newQuests, newNpcs = 0, 0, 0
	for id, entry in pairs(cache.items or {}) do
		local numID = tonumber(id)
		if numID and type(entry) == "table" then
			local existing = store.items[numID]
			if not existing or (cache.revision or 1) >= (existing.rev or 0) then
				if not existing then newItems = newItems + 1 end
				store.items[numID] = {
					id = numID,
					name = entry.name or ("Item #" .. numID),
					quality = entry.quality or 1,
					ilvl = entry.ilvl or 0,
					source = entry.source or "",
					rev = cache.revision or 1,
					via = "Wowhead",
				}
				added = added + 1
			end
		end
	end

	for id, entry in pairs(cache.quests or {}) do
		local numID = tonumber(id)
		if numID and type(entry) == "table" then
			local existing = store.quests[numID]
			if not existing or (cache.revision or 1) >= (existing.rev or 0) then
				if not existing then newQuests = newQuests + 1 end
				store.quests[numID] = {
					id = numID,
					name = entry.name or ("Quest #" .. numID),
					level = entry.level or 0,
					zone = entry.zone or "",
					summary = entry.summary or "",
					rev = cache.revision or 1,
					via = "Wowhead",
				}
				added = added + 1
			end
		end
	end

	for id, entry in pairs(cache.npcs or {}) do
		local numID = tonumber(id)
		if numID and type(entry) == "table" then
			local existing = store.npcs[numID]
			if not existing or (cache.revision or 1) >= (existing.rev or 0) then
				if not existing then newNpcs = newNpcs + 1 end
				store.npcs[numID] = {
					id = numID,
					name = entry.name or ("NPC #" .. numID),
					zone = entry.zone or "",
					note = entry.note or "",
					rev = cache.revision or 1,
					via = "Wowhead",
				}
				added = added + 1
			end
		end
	end

	if added > 0 then
		if self._countsInitialized then
			self._counts.items = (self._counts.items or 0) + newItems
			self._counts.quests = (self._counts.quests or 0) + newQuests
			self._counts.npcs = (self._counts.npcs or 0) + newNpcs
		end
		self.dataRevision = (self.dataRevision or 1) + 1
		if self._countsInitialized then
			self:SyncCachedStats()
		end
	end

	return added
end

-- Query optional external databases (QuestieDB / WoWHeadDB) if installed, never required
function PluribusHiveNetworkDB:LookupOptionalExternal(kind, id)
	id = tonumber(id)
	if not id then return nil end

	-- Optional WoWHeadDB
	local wh = _G.WoWHeadDB or _G.WowHeadDB
	if type(wh) == "table" then
		if kind == "item" and wh.items and wh.items[id] then
			local e = wh.items[id]
			return { id = id, name = e.name or ("Item #" .. id), quality = e.quality or 1, ilvl = e.ilvl or 0, source = e.source or e.drop or "WoWHeadDB", via = "WoWHeadDB" }
		elseif kind == "quest" and wh.quests and wh.quests[id] then
			local e = wh.quests[id]
			return { id = id, name = e.name or ("Quest #" .. id), level = e.level or 0, zone = e.zone or "", summary = e.summary or "WoWHeadDB", via = "WoWHeadDB" }
		elseif kind == "npc" and wh.npcs and wh.npcs[id] then
			local e = wh.npcs[id]
			return { id = id, name = e.name or ("NPC #" .. id), zone = e.zone or "", note = e.note or "WoWHeadDB", via = "WoWHeadDB" }
		end
	end

	-- Optional QuestieDB
	if kind == "quest" and _G.QuestieDB and _G.QuestieDB.GetQuest then
		local ok, q = pcall(_G.QuestieDB.GetQuest, _G.QuestieDB, id)
		if ok and type(q) == "table" and q.name then
			return { id = id, name = q.name, level = q.level or 0, zone = tostring(q.zoneOrSort or ""), summary = "QuestieDB", via = "QuestieDB" }
		end
	end

	return nil
end

function PluribusHiveNetworkDB:GetEntry(kind, id)
	id = tonumber(id)
	if not id then return nil end
	local store = self:GetStore()
	local bucket = (kind == "quest" and store.quests) or (kind == "npc" and store.npcs) or store.items
	if bucket[id] then
		return bucket[id]
	end
	local ext = self:LookupOptionalExternal(kind, id)
	if ext then
		bucket[id] = ext
		if self._countsInitialized then
			local k = (kind == "quest" and "quests") or (kind == "npc" and "npcs") or "items"
			self._counts[k] = (self._counts[k] or 0) + 1
			self:SyncCachedStats()
		end
		self.dataRevision = (self.dataRevision or 1) + 1
		return ext
	end
	return nil
end

function PluribusHiveNetworkDB:GetItem(itemID)
	return self:GetEntry("item", itemID)
end

function PluribusHiveNetworkDB:GetQuest(questID)
	return self:GetEntry("quest", questID)
end

-- Request missing data on-demand from guild peers (rate-limited per ID)
function PluribusHiveNetworkDB:RequestEntry(kind, id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if self:GetEntry(kind, id) then return true end
	if not PluribusHive:GetConfig().shareGameDB then return false end

	local key = kind .. ":" .. id
	local now = GetTime()
	if self.pendingRequests[key] and (now - self.pendingRequests[key]) < 120 then
		return false
	end
	self.pendingRequests[key] = now
	if not self.missingQueue[key] and self._countsInitialized then
		self._counts.missing = (self._counts.missing or 0) + 1
		self:SyncCachedStats()
	end
	self.missingQueue[key] = { kind = kind, id = id, seenAt = time() }

	PluribusHive:Send("DBREQ", string.format("%s|%d", kind, id), "GUILD")
	return true
end

function PluribusHiveNetworkDB:RequestItem(itemID)
	return self:RequestEntry("item", itemID)
end

function PluribusHiveNetworkDB:RequestQuest(questID)
	return self:RequestEntry("quest", questID)
end

-- Broadcast a version beacon so guildmates with newer Wowhead cache revisions can share updates
function PluribusHiveNetworkDB:CheckForNetworkUpdates()
	if not PluribusHive:GetConfig().shareGameDB then return end
	local stats = self:GetStats()
	self.lastVersionCheck = GetTime()
	PluribusHive:Send("DBVER", string.format("%d|%d", stats.revision or 1, stats.items or 0), "GUILD")
end

-- Share a compact batch of newer entries to a guildmate requesting updates
function PluribusHiveNetworkDB:SendRecentDelta(target, peerRev)
	local store = self:GetStore()
	local sent = 0
	for id, e in pairs(store.items) do
		if (e.rev or 1) > (peerRev or 0) then
			local payload = string.format("item|%d|%s|%d|%d|%s|%d",
				id, SafeClean(e.name), e.quality or 1, e.ilvl or 0, SafeClean(e.source), e.rev or store.revision or 1)
			PluribusHive:Send("DBRES", payload, target and "WHISPER" or "GUILD", target)
			sent = sent + 1
			if sent >= 25 then break end
		end
	end
end

function PluribusHiveNetworkDB:GetStats(forceRefresh)
	self:EnsureCounts(forceRefresh == true)
	return self:SyncCachedStats()
end

function PluribusHiveNetworkDB:GetMissingIDsString(kind)
	kind = kind or "item"
	local ids = {}
	for _, m in pairs(self.missingQueue) do
		if m.kind == kind then
			table.insert(ids, tostring(m.id))
		end
	end
	table.sort(ids)
	return table.concat(ids, ", ")
end

function PluribusHiveNetworkDB:Initialize()
	if self.initialized then return end
	self.initialized = true

	self:SeedFromWowheadCache()

	-- Respond to on-demand guild item/quest/NPC lookups
	PluribusHive:RegisterHandler("DBREQ", function(sender, body)
		if not PluribusHive:GetConfig().shareGameDB then return end
		local kind, idStr = body:match("^([^|]+)|(%d+)$")
		local id = tonumber(idStr)
		if not kind or not id then return end

		local entry = PluribusHiveNetworkDB:GetEntry(kind, id)
		if entry then
			local store = PluribusHiveNetworkDB:GetStore()
			if kind == "item" then
				local payload = string.format("item|%d|%s|%d|%d|%s|%d",
					id, SafeClean(entry.name), entry.quality or 1, entry.ilvl or 0, SafeClean(entry.source), entry.rev or store.revision or 1)
				PluribusHive:Send("DBRES", payload, "GUILD")
			elseif kind == "quest" then
				local payload = string.format("quest|%d|%s|%d|0|%s|%d",
					id, SafeClean(entry.name), entry.level or 0, SafeClean(entry.zone .. (entry.summary ~= "" and (" - " .. entry.summary) or "")), entry.rev or store.revision or 1)
				PluribusHive:Send("DBRES", payload, "GUILD")
			elseif kind == "npc" then
				local payload = string.format("npc|%d|%s|0|0|%s|%d",
					id, SafeClean(entry.name), SafeClean(entry.zone .. (entry.note ~= "" and (" - " .. entry.note) or "")), entry.rev or store.revision or 1)
				PluribusHive:Send("DBRES", payload, "GUILD")
			end
		end
	end)

	-- Receive P2P game database records from guildmates
	PluribusHive:RegisterHandler("DBRES", function(sender, body)
		local kind, idStr, name, n1, n2, desc, revStr = body:match("^([^|]+)|(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
		local id = tonumber(idStr)
		if not kind or not id or not name or name == "" then return end

		local store = PluribusHiveNetworkDB:GetStore()
		local rev = tonumber(revStr) or store.revision or 1
		if rev > (store.revision or 1) then
			store.revision = rev
			store.updatedAt = time()
		end

		if kind == "item" then
			local isNew = store.items[id] == nil
			store.items[id] = { id = id, name = name, quality = tonumber(n1) or 1, ilvl = tonumber(n2) or 0, source = desc or "", rev = rev, via = "Hive:" .. sender }
			if isNew and PluribusHiveNetworkDB._countsInitialized then
				PluribusHiveNetworkDB._counts.items = (PluribusHiveNetworkDB._counts.items or 0) + 1
			end
		elseif kind == "quest" then
			local isNew = store.quests[id] == nil
			store.quests[id] = { id = id, name = name, level = tonumber(n1) or 0, zone = desc or "", summary = "", rev = rev, via = "Hive:" .. sender }
			if isNew and PluribusHiveNetworkDB._countsInitialized then
				PluribusHiveNetworkDB._counts.quests = (PluribusHiveNetworkDB._counts.quests or 0) + 1
			end
		elseif kind == "npc" then
			local isNew = store.npcs[id] == nil
			store.npcs[id] = { id = id, name = name, zone = desc or "", note = "", rev = rev, via = "Hive:" .. sender }
			if isNew and PluribusHiveNetworkDB._countsInitialized then
				PluribusHiveNetworkDB._counts.npcs = (PluribusHiveNetworkDB._counts.npcs or 0) + 1
			end
		end

		local mKey = kind .. ":" .. id
		if PluribusHiveNetworkDB.missingQueue[mKey] ~= nil and PluribusHiveNetworkDB._countsInitialized then
			PluribusHiveNetworkDB._counts.missing = math.max(0, (PluribusHiveNetworkDB._counts.missing or 0) - 1)
		end
		PluribusHiveNetworkDB.missingQueue[mKey] = nil
		PluribusHiveNetworkDB.dataRevision = (PluribusHiveNetworkDB.dataRevision or 1) + 1
		if PluribusHiveNetworkDB._countsInitialized then
			PluribusHiveNetworkDB:SyncCachedStats()
		end
	end)

	-- Periodic revision beacon: if we have a newer Wowhead revision than a guildmate, push delta updates!
	PluribusHive:RegisterHandler("DBVER", function(sender, body)
		if not PluribusHive:GetConfig().shareGameDB then return end
		local peerRevStr = body:match("^(%d+)")
		local peerRev = tonumber(peerRevStr) or 1
		local store = PluribusHiveNetworkDB:GetStore()
		if (store.revision or 1) > peerRev then
			local now = GetTime()
			if (now - PluribusHiveNetworkDB.lastPeerBroadcast) >= 30 then
				PluribusHiveNetworkDB.lastPeerBroadcast = now
				PluribusHiveNetworkDB:SendRecentDelta(sender, peerRev)
				PluribusHive:AddFeedEvent("DB", string.format("Shared Wowhead DB rev %d updates with %s", store.revision, sender))
			end
		end
	end)

	-- Late-load support if PluribusData loads after PluribusCore
	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "ADDON_LOADED")
	pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(_, event, addonName)
		if event == "ADDON_LOADED" and (addonName == "PluribusData" or addonName == "WoWHeadDB" or addonName == "QuestieDB") then
			PluribusHiveNetworkDB:SeedFromWowheadCache()
		elseif event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveNetworkDB:SeedFromWowheadCache()
			if C_Timer and C_Timer.After then
				C_Timer.After(12, function() PluribusHiveNetworkDB:CheckForNetworkUpdates() end)
			end
		end
	end)

	-- Periodic 15-minute network update check
	local checkAccum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		checkAccum = checkAccum + (elapsed or 0)
		if checkAccum >= VERSION_CHECK_INTERVAL then
			checkAccum = 0
			PluribusHiveNetworkDB:CheckForNetworkUpdates()
		end
	end)
end

return PluribusHiveNetworkDB
