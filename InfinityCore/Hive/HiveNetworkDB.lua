-- InfinityHive On-Demand Network Game Database
-- Guild P2P on-demand item/quest/NPC lookup (DBREQ / DBRES) + periodic revision sync (DBVER)
-- Works standalone with built-in/Wowhead-synced InfinityWowheadCache AND integrates optional QuestieDB / WoWHeadDB / GathererDB

InfinityHiveNetworkDB = {
	initialized = false,
	pendingRequests = {},
	missingQueue = {},
	lastVersionCheck = 0,
	lastPeerBroadcast = 0,
}
_G.InfinityHiveNetworkDB = InfinityHiveNetworkDB

local VERSION_CHECK_INTERVAL = 900 -- 15 minutes periodic network update check

local function SafeClean(str)
	return tostring(str or ""):gsub("[|\t\r\n]", " "):sub(1, 140)
end

function InfinityHiveNetworkDB:GetStore()
	local db = InfinityHive:GetDB()
	db.gameDB = db.gameDB or { revision = 1, updatedAt = 0, items = {}, quests = {}, npcs = {} }
	db.gameDB.items = db.gameDB.items or {}
	db.gameDB.quests = db.gameDB.quests or {}
	db.gameDB.npcs = db.gameDB.npcs or {}
	return db.gameDB
end

-- Merge bundled / companion-fetched InfinityWowheadCache into persistent Hive DB
function InfinityHiveNetworkDB:SeedFromWowheadCache()
	local cache = _G.InfinityWowheadCache
	if type(cache) ~= "table" then return 0 end
	local store = self:GetStore()
	local added = 0

	if (cache.revision or 1) > (store.revision or 0) then
		store.revision = cache.revision
		store.updatedAt = cache.updatedAt or time()
	end

	for id, entry in pairs(cache.items or {}) do
		local numID = tonumber(id)
		if numID and type(entry) == "table" then
			local existing = store.items[numID]
			if not existing or (cache.revision or 1) >= (existing.rev or 0) then
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

	return added
end

-- Query optional external databases (QuestieDB / WoWHeadDB) if installed, never required
function InfinityHiveNetworkDB:LookupOptionalExternal(kind, id)
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

function InfinityHiveNetworkDB:GetEntry(kind, id)
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
		return ext
	end
	return nil
end

function InfinityHiveNetworkDB:GetItem(itemID)
	return self:GetEntry("item", itemID)
end

function InfinityHiveNetworkDB:GetQuest(questID)
	return self:GetEntry("quest", questID)
end

-- Request missing data on-demand from guild peers (rate-limited per ID)
function InfinityHiveNetworkDB:RequestEntry(kind, id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if self:GetEntry(kind, id) then return true end
	if not InfinityHive:GetConfig().shareGameDB then return false end

	local key = kind .. ":" .. id
	local now = GetTime()
	if self.pendingRequests[key] and (now - self.pendingRequests[key]) < 120 then
		return false
	end
	self.pendingRequests[key] = now
	self.missingQueue[key] = { kind = kind, id = id, seenAt = time() }

	InfinityHive:Send("DBREQ", string.format("%s|%d", kind, id), "GUILD")
	return true
end

function InfinityHiveNetworkDB:RequestItem(itemID)
	return self:RequestEntry("item", itemID)
end

function InfinityHiveNetworkDB:RequestQuest(questID)
	return self:RequestEntry("quest", questID)
end

-- Broadcast a version beacon so guildmates with newer Wowhead cache revisions can share updates
function InfinityHiveNetworkDB:CheckForNetworkUpdates()
	if not InfinityHive:GetConfig().shareGameDB then return end
	local store = self:GetStore()
	local itemCount = 0
	for _ in pairs(store.items) do itemCount = itemCount + 1 end
	self.lastVersionCheck = GetTime()
	InfinityHive:Send("DBVER", string.format("%d|%d", store.revision or 1, itemCount), "GUILD")
end

-- Share a compact batch of newer entries to a guildmate requesting updates
function InfinityHiveNetworkDB:SendRecentDelta(target, peerRev)
	local store = self:GetStore()
	local sent = 0
	for id, e in pairs(store.items) do
		if (e.rev or 1) > (peerRev or 0) then
			local payload = string.format("item|%d|%s|%d|%d|%s|%d",
				id, SafeClean(e.name), e.quality or 1, e.ilvl or 0, SafeClean(e.source), e.rev or store.revision or 1)
			InfinityHive:Send("DBRES", payload, target and "WHISPER" or "GUILD", target)
			sent = sent + 1
			if sent >= 25 then break end
		end
	end
end

function InfinityHiveNetworkDB:GetStats()
	local store = self:GetStore()
	local items, quests, npcs, missing = 0, 0, 0, 0
	for _ in pairs(store.items) do items = items + 1 end
	for _ in pairs(store.quests) do quests = quests + 1 end
	for _ in pairs(store.npcs) do npcs = npcs + 1 end
	for _ in pairs(self.missingQueue) do missing = missing + 1 end

	return {
		revision = store.revision or 1,
		items = items,
		quests = quests,
		npcs = npcs,
		missing = missing,
		hasQuestieDB = _G.QuestieDB ~= nil,
		hasWowheadDB = (_G.WoWHeadDB ~= nil or _G.WowHeadDB ~= nil),
		hasGathererDB = (_G.GathererDB ~= nil or _G.GatherMate2 ~= nil),
	}
end

function InfinityHiveNetworkDB:GetMissingIDsString(kind)
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

function InfinityHiveNetworkDB:Initialize()
	if self.initialized then return end
	self.initialized = true

	self:SeedFromWowheadCache()

	-- Respond to on-demand guild item/quest/NPC lookups
	InfinityHive:RegisterHandler("DBREQ", function(sender, body)
		if not InfinityHive:GetConfig().shareGameDB then return end
		local kind, idStr = body:match("^([^|]+)|(%d+)$")
		local id = tonumber(idStr)
		if not kind or not id then return end

		local entry = InfinityHiveNetworkDB:GetEntry(kind, id)
		if entry then
			local store = InfinityHiveNetworkDB:GetStore()
			if kind == "item" then
				local payload = string.format("item|%d|%s|%d|%d|%s|%d",
					id, SafeClean(entry.name), entry.quality or 1, entry.ilvl or 0, SafeClean(entry.source), entry.rev or store.revision or 1)
				InfinityHive:Send("DBRES", payload, "GUILD")
			elseif kind == "quest" then
				local payload = string.format("quest|%d|%s|%d|0|%s|%d",
					id, SafeClean(entry.name), entry.level or 0, SafeClean(entry.zone .. (entry.summary ~= "" and (" - " .. entry.summary) or "")), entry.rev or store.revision or 1)
				InfinityHive:Send("DBRES", payload, "GUILD")
			elseif kind == "npc" then
				local payload = string.format("npc|%d|%s|0|0|%s|%d",
					id, SafeClean(entry.name), SafeClean(entry.zone .. (entry.note ~= "" and (" - " .. entry.note) or "")), entry.rev or store.revision or 1)
				InfinityHive:Send("DBRES", payload, "GUILD")
			end
		end
	end)

	-- Receive P2P game database records from guildmates
	InfinityHive:RegisterHandler("DBRES", function(sender, body)
		local kind, idStr, name, n1, n2, desc, revStr = body:match("^([^|]+)|(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
		local id = tonumber(idStr)
		if not kind or not id or not name or name == "" then return end

		local store = InfinityHiveNetworkDB:GetStore()
		local rev = tonumber(revStr) or store.revision or 1
		if rev > (store.revision or 1) then
			store.revision = rev
			store.updatedAt = time()
		end

		if kind == "item" then
			store.items[id] = { id = id, name = name, quality = tonumber(n1) or 1, ilvl = tonumber(n2) or 0, source = desc or "", rev = rev, via = "Hive:" .. sender }
		elseif kind == "quest" then
			store.quests[id] = { id = id, name = name, level = tonumber(n1) or 0, zone = desc or "", summary = "", rev = rev, via = "Hive:" .. sender }
		elseif kind == "npc" then
			store.npcs[id] = { id = id, name = name, zone = desc or "", note = "", rev = rev, via = "Hive:" .. sender }
		end

		InfinityHiveNetworkDB.missingQueue[kind .. ":" .. id] = nil
	end)

	-- Periodic revision beacon: if we have a newer Wowhead revision than a guildmate, push delta updates!
	InfinityHive:RegisterHandler("DBVER", function(sender, body)
		if not InfinityHive:GetConfig().shareGameDB then return end
		local peerRevStr = body:match("^(%d+)")
		local peerRev = tonumber(peerRevStr) or 1
		local store = InfinityHiveNetworkDB:GetStore()
		if (store.revision or 1) > peerRev then
			local now = GetTime()
			if (now - InfinityHiveNetworkDB.lastPeerBroadcast) >= 30 then
				InfinityHiveNetworkDB.lastPeerBroadcast = now
				InfinityHiveNetworkDB:SendRecentDelta(sender, peerRev)
				InfinityHive:AddFeedEvent("DB", string.format("Shared Wowhead DB rev %d updates with %s", store.revision, sender))
			end
		end
	end)

	-- Late-load support if InfinityData loads after InfinityCore
	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "ADDON_LOADED")
	pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(_, event, addonName)
		if event == "ADDON_LOADED" and (addonName == "InfinityData" or addonName == "WoWHeadDB" or addonName == "QuestieDB") then
			InfinityHiveNetworkDB:SeedFromWowheadCache()
		elseif event == "PLAYER_ENTERING_WORLD" then
			InfinityHiveNetworkDB:SeedFromWowheadCache()
			if C_Timer and C_Timer.After then
				C_Timer.After(12, function() InfinityHiveNetworkDB:CheckForNetworkUpdates() end)
			end
		end
	end)

	-- Periodic 15-minute network update check
	local checkAccum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		checkAccum = checkAccum + (elapsed or 0)
		if checkAccum >= VERSION_CHECK_INTERVAL then
			checkAccum = 0
			InfinityHiveNetworkDB:CheckForNetworkUpdates()
		end
	end)
end

return InfinityHiveNetworkDB
