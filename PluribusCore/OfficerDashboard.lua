-- PluribusCore Officer Dashboard
-- Modern interactive guild management interface for WoW Forever officers
-- Features a persistent, guild-synced Transaction History & Forensic Audit Trail
-- aggregating DKP/EPGP awards, loot distributions, auction outcomes, guild tax, and officer audit actions.

local PluribusCore = PluribusCore or {}
PluribusCore.OfficerDashboard = {
	enabled = true,
	visible = false,
	frame = nil,
	exportFrame = nil,
	hooksAttached = false,
	hiveHandlerRegistered = false,
	config = {
		width = 880,
		height = 590,
		maxTransactions = 2000,
	},
	tabs = {
		{ id = "overview", label = "Overview" },
		{ id = "dkp_management", label = "DKP & Awards" },
		{ id = "tx_history", label = "Tx History" },
		{ id = "loot_audits", label = "Loot Audits" },
		{ id = "player_status", label = "Rankings" },
		{ id = "settings", label = "Settings" },
	},
	current_tab = "overview",
	txFilterCategory = "ALL",   -- ALL | DKP | LOOT | AUDIT | TAX
	txFilterTimeframe = 0,      -- 0 (All) | 86400 (24h) | 604800 (7d) | 2592000 (30d)
	txSearchQuery = "",
	txSelectedId = nil,
	txShowManualForm = false,
	txManualKind = "LOOT",      -- LOOT | AUDIT
}

local Dashboard = PluribusCore.OfficerDashboard
_G.PluribusOfficerDashboard = Dashboard

local function EnsureUI()
	return _G.PluribusUIFramework
end

local function GetDKPEngine()
	return _G.PluribusDKPEngine
end

local function TrimStr(s)
	if not s then return "" end
	if strtrim then return strtrim(tostring(s)) end
	return tostring(s):match("^%s*(.-)%s*$") or ""
end

local function NormalizePlayer(name)
	if _G.PluribusHive and _G.PluribusHive.NormalizeName then
		local n = _G.PluribusHive:NormalizeName(name)
		if n ~= "" then return n end
	end
	return TrimStr(tostring(name or "")):gsub("%-.+$", "")
end

local function GetCurrentOfficerName()
	local n = UnitName and UnitName("player") or "Officer"
	return NormalizePlayer(n)
end

local function LookupClassForMember(memberName)
	local clean = NormalizePlayer(memberName)
	if clean == "" then return nil end
	local engine = GetDKPEngine()
	if engine and engine.GetPlayer then
		local p = engine:GetPlayer(clean)
		if p and p.class and p.class ~= "UNKNOWN" then
			return p.class
		end
	end
	if _G.PluribusHive and _G.PluribusHive.members then
		local m = _G.PluribusHive.members[clean]
		if m and m.class then return m.class end
	end
	if _G.PluribusHive and _G.PluribusHive.GetDB then
		local db = _G.PluribusHive:GetDB()
		if db and db.guildBags and db.guildBags[clean] and db.guildBags[clean].class then
			return db.guildBags[clean].class
		end
	end
	return nil
end

local function FormatShortTime(ts)
	ts = tonumber(ts) or 0
	if ts <= 0 then return "--:--" end
	local diff = math.max(0, time() - ts)
	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return date and date("%H:%M", ts) or string.format("%dh ago", math.floor(diff / 3600))
	else
		return date and date("%m/%d %H:%M", ts) or string.format("%dd ago", math.floor(diff / 86400))
	end
end

local function FormatFullTimestamp(ts)
	ts = tonumber(ts) or 0
	if ts <= 0 then return "Unknown" end
	if date then
		return date("%Y-%m-%d %H:%M:%S", ts)
	end
	return tostring(ts)
end

local function FormatGoldCompact(copper)
	copper = math.floor(tonumber(copper) or 0)
	if _G.PluribusUtils and _G.PluribusUtils.FormatGold then
		return _G.PluribusUtils:FormatGold(copper)
	end
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	if g > 0 then
		return string.format("%dg %ds", g, s)
	elseif s > 0 then
		return string.format("%ds %dc", s, c)
	end
	return string.format("%dc", c)
end

local function EnsureTransactionStore()
	_G.PluribusCoreDB = _G.PluribusCoreDB or {}
	local db = _G.PluribusCoreDB
	if type(db.officerTransactionLog) ~= "table" then
		db.officerTransactionLog = {}
	end
	if type(db.officerTxSeq) ~= "number" then
		db.officerTxSeq = #db.officerTransactionLog
	end
	return db.officerTransactionLog, db
end

-- Build a core identity key (paired with a sliding 5-second timestamp window so boundary ticks never duplicate)
local function BuildTxCoreKey(tx)
	return string.format("%s|%s|%s|%s|%s",
		tostring(tx.category or "AUDIT"),
		tostring(tx.action or "LOG"),
		NormalizePlayer(tx.player or ""):lower(),
		tostring(math.floor((tonumber(tx.amount) or 0) * 100)),
		TrimStr(tx.itemName or ""):lower()
	)
end

local function IsSameTransaction(a, b)
	if BuildTxCoreKey(a) ~= BuildTxCoreKey(b) then return false end
	return math.abs((tonumber(a.timestamp) or 0) - (tonumber(b.timestamp) or 0)) <= 5
end

local CATEGORY_META = {
	DKP = { label = "DKP", hex = "|cff4ade80", r = 0.29, g = 0.87, b = 0.50 },
	LOOT = { label = "LOOT", hex = "|cffc084fc", r = 0.75, g = 0.52, b = 0.99 },
	AUDIT = { label = "AUDIT", hex = "|cff38bdf8", r = 0.22, g = 0.74, b = 0.97 },
	TAX = { label = "TAX", hex = "|cfffbbf24", r = 0.98, g = 0.75, b = 0.14 },
}

local ACTION_LABELS = {
	EP_AWARD = "EP Award",
	GP_CHARGE = "GP Charge",
	DKP_AWARD = "DKP Award",
	DKP_SPEND = "DKP Spend",
	DECAY = "Guild Decay",
	LOOT_DIST = "Loot Dist.",
	AUCTION_WIN = "Auction Win",
	AUCTION_OPEN = "Auction Open",
	SYSTEM_CHANGE = "Mode Change",
	PLAYER_ADDED = "Raider Added",
	PLAYER_REMOVED = "Raider Removed",
	TAX_PAID = "Tax Paid",
	TAX_ACCRUED = "Tax Accrued",
	MANUAL_AUDIT = "Officer Note",
}

local function SanitizePipe(s)
	return tostring(s or ""):gsub("|", "/"):gsub("[\r\n]+", " ")
end

-- ============================================================================
-- PERSISTENT TRANSACTION LOGGER & HIVE SYNC
-- ============================================================================
function Dashboard:RecordTransaction(txData, skipBroadcast)
	if type(txData) ~= "table" then return nil end
	local store, db = EnsureTransactionStore()

	local ts = tonumber(txData.timestamp) or time()
	local cat = tostring(txData.category or "AUDIT"):upper()
	if not CATEGORY_META[cat] then cat = "AUDIT" end

	local entry = {
		id = txData.id,
		timestamp = ts,
		category = cat,
		action = tostring(txData.action or "MANUAL_AUDIT"):upper(),
		player = NormalizePlayer(txData.player or "Guild"),
		officer = NormalizePlayer(txData.officer or GetCurrentOfficerName()),
		amount = tonumber(txData.amount) or 0,
		unit = tostring(txData.unit or ""),
		beforeVal = txData.beforeVal ~= nil and tonumber(txData.beforeVal) or nil,
		afterVal = txData.afterVal ~= nil and tonumber(txData.afterVal) or nil,
		itemName = TrimStr(txData.itemName or ""),
		itemLink = txData.itemLink,
		reason = TrimStr(txData.reason or ""),
		source = tostring(txData.source or "OfficerDashboard"),
	}

	if entry.player == "" then entry.player = "Guild" end
	if entry.officer == "" then entry.officer = GetCurrentOfficerName() end

	-- Avoid immediate duplicates across any 5s sliding window (e.g., OfficerDashboard + DKPEngine callback)
	for i = 1, math.min(25, #store) do
		if IsSameTransaction(store[i], entry) then
			-- Enrich existing entry if the newer copy has before/after or itemLink
			if store[i].beforeVal == nil and entry.beforeVal ~= nil then
				store[i].beforeVal = entry.beforeVal
				store[i].afterVal = entry.afterVal
			end
			if (not store[i].itemLink) and entry.itemLink then
				store[i].itemLink = entry.itemLink
			end
			return store[i]
		end
	end

	db.officerTxSeq = (db.officerTxSeq or #store) + 1
	if not entry.id or entry.id == "" then
		entry.id = string.format("TX-%04d", db.officerTxSeq)
	end

	table.insert(store, 1, entry)
	while #store > (self.config.maxTransactions or 2000) do
		table.remove(store)
	end

	-- Sync compact audit record to fellow online guild officers over PLBHIVE
	if not skipBroadcast and _G.PluribusHive and _G.PluribusHive.Send then
		local payload = table.concat({
			SanitizePipe(entry.id),
			tostring(entry.timestamp),
			SanitizePipe(entry.category),
			SanitizePipe(entry.action),
			SanitizePipe(entry.player),
			SanitizePipe(entry.officer),
			tostring(entry.amount),
			SanitizePipe(entry.unit),
			entry.beforeVal ~= nil and tostring(entry.beforeVal) or "",
			entry.afterVal ~= nil and tostring(entry.afterVal) or "",
			SanitizePipe(entry.itemName),
			SanitizePipe(entry.reason),
		}, "|")
		pcall(function()
			_G.PluribusHive:Send("OFFTX", payload, "GUILD")
		end)
	end

	-- Live-refresh dashboard if currently viewing Tx History or Overview
	if self.visible and self.frame and (self.current_tab == "tx_history" or self.current_tab == "overview") then
		self:RefreshContent()
	end

	return entry
end

-- Attach idempotent real-time hooks across DKP, LootHistory, Auctions, and HiveComms
function Dashboard:AttachAuditHooks()
	local engine = GetDKPEngine()
	if engine and engine.RegisterCallback and not engine._plbOfficerAuditHooked then
		engine._plbOfficerAuditHooked = true
		engine:RegisterCallback(function(event, a, b, c, d)
			if event == "ep_awarded" then
				local p = engine.GetPlayer and engine:GetPlayer(a)
				local afterEp = p and (p.ep or 0) or nil
				local amt = tonumber(b) or 0
				local beforeEp = afterEp and (afterEp - amt) or nil
				Dashboard:RecordTransaction({
					category = "DKP",
					action = "EP_AWARD",
					player = a,
					amount = amt,
					unit = "EP",
					beforeVal = beforeEp,
					afterVal = afterEp,
					reason = c or "EP Award",
					source = "DKPEngine",
				})
			elseif event == "gp_awarded" then
				local p = engine.GetPlayer and engine:GetPlayer(a)
				local afterGp = p and (p.gp or 0) or nil
				local amt = tonumber(b) or 0
				local beforeGp = afterGp and (afterGp - amt) or nil
				Dashboard:RecordTransaction({
					category = "DKP",
					action = "GP_CHARGE",
					player = a,
					amount = amt,
					unit = "GP",
					beforeVal = beforeGp,
					afterVal = afterGp,
					itemName = tostring(c or ""),
					reason = tostring(d or c or "Loot GP Charge"),
					source = "DKPEngine",
				})
			elseif event == "decay_applied" then
				local pct = tonumber(a) or 0
				local stats = engine.GetStats and engine:GetStats() or {}
				Dashboard:RecordTransaction({
					category = "AUDIT",
					action = "DECAY",
					player = "All Raiders",
					amount = pct,
					unit = "%",
					reason = string.format("Applied %d%% EP decay across %d tracked raiders", pct, stats.total_players or 0),
					source = "DKPEngine",
				})
			elseif event == "system_changed" then
				Dashboard:RecordTransaction({
					category = "AUDIT",
					action = "SYSTEM_CHANGE",
					player = "Guild Policy",
					reason = "Switched active loot priority mode to " .. tostring(a or "EPGP"):upper(),
					source = "OfficerDashboard",
				})
			elseif event == "player_added" then
				Dashboard:RecordTransaction({
					category = "AUDIT",
					action = "PLAYER_ADDED",
					player = a,
					reason = "Added raider to DKP/EPGP roster",
					source = "DKPEngine",
				})
			elseif event == "player_removed" then
				Dashboard:RecordTransaction({
					category = "AUDIT",
					action = "PLAYER_REMOVED",
					player = a,
					reason = "Removed raider from DKP/EPGP roster",
					source = "DKPEngine",
				})
			end
		end)
	end

	if _G.PluribusLootHistory and _G.PluribusLootHistory.RegisterCallback and not _G.PluribusLootHistory._plbOfficerAuditHooked then
		_G.PluribusLootHistory._plbOfficerAuditHooked = true
		pcall(function()
			_G.PluribusLootHistory:RegisterCallback(function(event, entry)
				if event == "loot_awarded" and type(entry) == "table" then
					Dashboard:RecordTransaction({
						timestamp = tonumber(entry.timestamp) or time(),
						category = "LOOT",
						action = "LOOT_DIST",
						player = entry.playerName or "Unknown",
						amount = tonumber(entry.value) or 0,
						unit = "GP",
						itemName = entry.itemName or "Unknown Item",
						itemLink = entry.itemLink,
						reason = entry.reason or "Loot Distribution",
						source = "LootHistory",
					})
				end
			end)
		end)
	end

	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe and not self.hooksAttached then
		self.hooksAttached = true
		pcall(function()
			_G.PluribusMessaging:Subscribe("auction_completed", function(data)
				if type(data) ~= "table" then return end
				Dashboard:RecordTransaction({
					category = "LOOT",
					action = "AUCTION_WIN",
					player = data.winner or "No Bids",
					amount = tonumber(data.winningBid) or 0,
					unit = "DKP",
					itemName = data.itemName or "Auction Item",
					itemLink = data.itemLink,
					reason = string.format("Closed %s auction", tostring(data.biddingMode or "open")),
					source = "LootAuction",
				})
			end)
		end)
	end

	if _G.PluribusHive and _G.PluribusHive.RegisterHandler and not self.hiveHandlerRegistered then
		self.hiveHandlerRegistered = true
		_G.PluribusHive:RegisterHandler("OFFTX", function(sender, body)
			if type(body) ~= "string" or body == "" then return end
			if _G.PluribusHive:SamePlayer(sender, _G.PluribusHive:GetPlayerShortName()) then return end
			local parts = {}
			local startIdx = 1
			while true do
				local sep = body:find("|", startIdx, true)
				if sep then
					table.insert(parts, body:sub(startIdx, sep - 1))
					startIdx = sep + 1
				else
					table.insert(parts, body:sub(startIdx))
					break
				end
			end
			if #parts >= 6 then
				Dashboard:RecordTransaction({
					id = parts[1],
					timestamp = tonumber(parts[2]) or time(),
					category = parts[3] or "AUDIT",
					action = parts[4] or "MANUAL_AUDIT",
					player = parts[5] or "Guild",
					officer = parts[6] ~= "" and parts[6] or NormalizePlayer(sender),
					amount = tonumber(parts[7]) or 0,
					unit = parts[8] or "",
					beforeVal = parts[9] ~= "" and tonumber(parts[9]) or nil,
					afterVal = parts[10] ~= "" and tonumber(parts[10]) or nil,
					itemName = parts[11] or "",
					reason = parts[12] or "",
					source = "HiveSync",
				}, true)
			end
		end)
	end
end

-- Aggregate persistent officer ledger + external DKP/Loot/Tax histories into one unified, deduplicated view
function Dashboard:GetUnifiedTransactions(filters)
	filters = filters or {}
	local store = EnsureTransactionStore()
	local merged = {}
	local seenByKey = {}

	local function AddIfNew(tx)
		if type(tx) ~= "table" then return end
		local key = BuildTxCoreKey(tx)
		local bucket = seenByKey[key]
		if bucket then
			local ts = tonumber(tx.timestamp) or 0
			for _, prevTs in ipairs(bucket) do
				if math.abs(ts - prevTs) <= 5 then
					return
				end
			end
			table.insert(bucket, ts)
		else
			seenByKey[key] = { tonumber(tx.timestamp) or 0 }
		end
		table.insert(merged, tx)
	end

	-- 1. Primary persistent officer ledger
	for _, tx in ipairs(store) do
		AddIfNew(tx)
	end

	-- 2. Historical PointAudit entries (if PluribusDKP PointAudit has older records)
	if _G.PluribusPointAudit and type(_G.PluribusPointAudit.transactionLog) == "table" then
		for _, entry in ipairs(_G.PluribusPointAudit.transactionLog) do
			if type(entry) == "table" then
				local t = tostring(entry.type or "award"):lower()
				local act = (t == "spend") and "DKP_SPEND" or (t == "decay" and "DECAY" or "DKP_AWARD")
				local cat = (t == "decay" or t == "adjust") and "AUDIT" or "DKP"
				AddIfNew({
					id = "PA-" .. tostring(entry.id or 0),
					timestamp = tonumber(entry.timestamp) or 0,
					category = cat,
					action = act,
					player = NormalizePlayer(entry.player or "Unknown"),
					officer = NormalizePlayer(entry.admin or "System"),
					amount = tonumber(entry.amount) or 0,
					unit = "DKP",
					beforeVal = tonumber(entry.before),
					afterVal = tonumber(entry.after),
					itemName = "",
					reason = tostring(entry.reason or ""),
					source = tostring(entry.source or "PointAudit"),
				})
			end
		end
	end

	-- 3. Historical PluribusDKPPoints session entries
	if _G.PluribusDKPPoints and type(_G.PluribusDKPPoints.point_history) == "table" then
		for idx, tr in ipairs(_G.PluribusDKPPoints.point_history) do
			if type(tr) == "table" then
				AddIfNew({
					id = "PT-" .. tostring(idx),
					timestamp = tonumber(tr.epoch) or time(),
					category = "DKP",
					action = tostring(tr.type or "DKP_AWARD"):upper(),
					player = NormalizePlayer(tr.player or "Unknown"),
					officer = "DKP",
					amount = tonumber(tr.amount) or 0,
					unit = tostring(tr.type or "DKP"):upper(),
					itemName = "",
					reason = tostring(tr.reason or ""),
					source = "DKPPoints",
				})
			end
		end
	end

	-- 4. Historical PluribusLootHistory entries
	if _G.PluribusLootHistory and type(_G.PluribusLootHistory.lootLog) == "table" then
		for idx, entry in ipairs(_G.PluribusLootHistory.lootLog) do
			if type(entry) == "table" then
				AddIfNew({
					id = "LH-" .. tostring(idx),
					timestamp = tonumber(entry.timestamp) or time(),
					category = "LOOT",
					action = "LOOT_DIST",
					player = NormalizePlayer(entry.playerName or "Unknown"),
					officer = "MasterLooter",
					amount = tonumber(entry.value) or 0,
					unit = "GP",
					itemName = tostring(entry.itemName or "Unknown Item"),
					itemLink = entry.itemLink,
					reason = tostring(entry.reason or "Loot Distribution"),
					source = tostring(entry.source or "LootHistory"),
				})
			end
		end
	end

	-- 5. Closed PluribusLootAuctions history
	if _G.PluribusLootAuctions and _G.PluribusLootAuctions.GetAuctionHistory then
		local ok, hist = pcall(function() return _G.PluribusLootAuctions:GetAuctionHistory(100) end)
		if ok and type(hist) == "table" then
			for idx, a in ipairs(hist) do
				if type(a) == "table" then
					AddIfNew({
						id = "AUC-" .. tostring(a.id or idx),
						timestamp = tonumber(a.closedAt or a.timestamp) or time(),
						category = "LOOT",
						action = "AUCTION_WIN",
						player = NormalizePlayer(a.winner or "No Bids"),
						officer = NormalizePlayer(a.createdBy or "Auctioneer"),
						amount = tonumber(a.winningBid) or 0,
						unit = "DKP",
						itemName = tostring(a.itemName or "Unknown Item"),
						itemLink = a.itemLink,
						reason = string.format("Auction (%s)", tostring(a.biddingMode or "open")),
						source = "LootAuction",
					})
				end
			end
		end
	end

	-- 6. Guild Tax Vault history (from PluribusHiveTax)
	if _G.PluribusHive and _G.PluribusHive.GetDB then
		local hdb = _G.PluribusHive:GetDB()
		local taxHist = hdb and hdb.tax and hdb.tax.history
		local me = _G.PluribusHive:GetPlayerShortName()
		if type(taxHist) == "table" then
			for idx, th in ipairs(taxHist) do
				if type(th) == "table" then
					local isPaid = tostring(th.kind or ""):upper() == "PAID"
					AddIfNew({
						id = "TAX-" .. tostring(idx),
						timestamp = tonumber(th.time) or 0,
						category = "TAX",
						action = isPaid and "TAX_PAID" or "TAX_ACCRUED",
						player = me,
						officer = "Treasury",
						amount = tonumber(th.copper) or 0,
						unit = "COPPER",
						itemName = "",
						reason = tostring(th.note or "Guild Tax"),
						source = "GuildTax",
					})
				end
			end
		end
	end

	-- Sort newest first (tie-break by ID descending)
	table.sort(merged, function(a, b)
		local ta, tb = tonumber(a.timestamp) or 0, tonumber(b.timestamp) or 0
		if ta ~= tb then return ta > tb end
		return tostring(a.id or "") > tostring(b.id or "")
	end)

	-- Apply interactive filters
	local catFilter = tostring(filters.category or "ALL"):upper()
	local timeframe = tonumber(filters.timeframeSec) or 0
	local cutoff = timeframe > 0 and (time() - timeframe) or 0
	local query = TrimStr(filters.query or ""):lower()

	local filtered = {}
	for _, tx in ipairs(merged) do
		local passCat = (catFilter == "ALL") or (tx.category == catFilter)
		local passTime = (cutoff == 0) or ((tonumber(tx.timestamp) or 0) >= cutoff)
		local passQuery = true
		if query ~= "" then
			local hay = table.concat({
				tostring(tx.id or ""),
				tostring(tx.player or ""),
				tostring(tx.officer or ""),
				tostring(tx.itemName or ""),
				tostring(tx.reason or ""),
				tostring(tx.action or ""),
				tostring(tx.category or ""),
				tostring(tx.source or ""),
			}, " "):lower()
			passQuery = hay:find(query, 1, true) ~= nil
		end
		if passCat and passTime and passQuery then
			table.insert(filtered, tx)
		end
	end

	return filtered, #merged
end

function Dashboard:GetTransactionSummary(list)
	local summary = {
		total = #(list or {}),
		dkpCount = 0,
		lootCount = 0,
		auditCount = 0,
		taxCount = 0,
		netEP = 0,
		netGP = 0,
		uniqueMembers = 0,
	}
	local seenPlayers = {}
	for _, tx in ipairs(list or {}) do
		if tx.category == "DKP" then
			summary.dkpCount = summary.dkpCount + 1
		elseif tx.category == "LOOT" then
			summary.lootCount = summary.lootCount + 1
		elseif tx.category == "TAX" then
			summary.taxCount = summary.taxCount + 1
		else
			summary.auditCount = summary.auditCount + 1
		end
		if tx.unit == "EP" then
			summary.netEP = summary.netEP + (tonumber(tx.amount) or 0)
		elseif tx.unit == "GP" then
			summary.netGP = summary.netGP + (tonumber(tx.amount) or 0)
		end
		local pl = NormalizePlayer(tx.player or ""):lower()
		if pl ~= "" and pl ~= "guild" and pl ~= "all raiders" and pl ~= "guild policy" and not seenPlayers[pl] then
			seenPlayers[pl] = true
			summary.uniqueMembers = summary.uniqueMembers + 1
		end
	end
	return summary
end

local function StripWowFormatting(val)
	local s = tostring(val or "")
	-- Extract readable text from WoW hyperlinks: |Hitem:...|h[Item Name]|h -> [Item Name]
	s = s:gsub("|H[^|]*|h(.-)|h", "%1")
	-- Strip WoW color codes |cAARRGGBB and |r
	s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
	s = s:gsub("|r", "")
	-- Strip inline texture escapes |T...|t
	s = s:gsub("|T.-|t", "")
	return s
end

local function CsvEscape(val, delim)
	delim = delim or ","
	local s = StripWowFormatting(val):gsub("\"", "\"\"")
	if s:find("[" .. delim .. "\r\n\"]") then
		return "\"" .. s .. "\""
	end
	return s
end

function Dashboard:ExportTransactionsCSV(list, options)
	options = options or {}
	local delim = (options.format == "TSV") and "\t" or ","
	local headers = { "ID", "Timestamp", "Category", "Action", "Member", "Amount", "Unit", "Before", "After", "Item", "Reason", "Officer", "Source" }
	local lines = { table.concat(headers, delim) }
	for _, tx in ipairs(list or {}) do
		table.insert(lines, table.concat({
			CsvEscape(tx.id, delim),
			CsvEscape(FormatFullTimestamp(tx.timestamp), delim),
			CsvEscape(tx.category, delim),
			CsvEscape(tx.action, delim),
			CsvEscape(tx.player, delim),
			CsvEscape(tx.amount, delim),
			CsvEscape(tx.unit, delim),
			CsvEscape(tx.beforeVal ~= nil and tx.beforeVal or "", delim),
			CsvEscape(tx.afterVal ~= nil and tx.afterVal or "", delim),
			CsvEscape(tx.itemName ~= "" and tx.itemName or (tx.itemLink or ""), delim),
			CsvEscape(tx.reason, delim),
			CsvEscape(tx.officer, delim),
			CsvEscape(tx.source, delim),
		}, delim))
	end
	return table.concat(lines, "\n")
end

function Dashboard:GetTransactionsForExportScope(scope, customMember)
	scope = tostring(scope or "FILTERED"):upper()
	if customMember and customMember ~= "" then
		local list = self:GetUnifiedTransactions({ category = "ALL", query = customMember })
		return list, "Member: " .. customMember
	elseif scope == "ALL" then
		local list = self:GetUnifiedTransactions({ category = "ALL", timeframeSec = 0, query = "" })
		return list, "All Audit Trails"
	elseif scope == "DKP" then
		local all = self:GetUnifiedTransactions({ category = "ALL", timeframeSec = 0, query = "" })
		local dkp = {}
		for _, tx in ipairs(all) do
			if tx.category == "DKP" or tx.action == "DECAY" then
				table.insert(dkp, tx)
			end
		end
		return dkp, "DKP & Decay Logs"
	elseif scope == "LOOT" then
		local list = self:GetUnifiedTransactions({ category = "LOOT", timeframeSec = 0, query = "" })
		return list, "Loot & Auctions"
	elseif scope == "AUDIT" then
		local list = self:GetUnifiedTransactions({ category = "AUDIT", timeframeSec = 0, query = "" })
		return list, "Officer Audit Trails"
	else
		local list = self:GetUnifiedTransactions({
			category = self.txFilterCategory,
			timeframeSec = self.txFilterTimeframe,
			query = self.txSearchQuery,
		})
		return list, "Current Filtered View"
	end
end

function Dashboard:FormatAuditChatLine(tx)
	if not tx then return "" end
	local deltaStr = ""
	if tx.unit == "COPPER" then
		deltaStr = FormatGoldCompact(tx.amount)
	elseif (tonumber(tx.amount) or 0) ~= 0 then
		deltaStr = string.format("%+d %s", tonumber(tx.amount) or 0, tx.unit ~= "" and tx.unit or "pts")
	end
	local balStr = (tx.beforeVal ~= nil and tx.afterVal ~= nil)
		and string.format(" (%d->%d)", math.floor(tx.beforeVal), math.floor(tx.afterVal))
		or ""
	local itemPart = (tx.itemLink and tx.itemLink ~= "") and (" " .. tx.itemLink) or (tx.itemName ~= "" and (" [" .. tx.itemName .. "]") or "")
	local reasonPart = tx.reason ~= "" and (" - " .. tx.reason) or ""
	return string.format("[Pluribus Audit %s] %s | %s: %s%s%s%s (by %s)",
		tostring(tx.id or "TX"),
		ACTION_LABELS[tx.action] or tostring(tx.action or "LOG"),
		tostring(tx.player or "Guild"),
		deltaStr,
		balStr,
		itemPart,
		reasonPart,
		tostring(tx.officer or "Officer")
	)
end

function Dashboard:OpenExportDialog(initialScope, customMember)
	self.exportScope = tostring(initialScope or "FILTERED"):upper()
	self.exportFormat = self.exportFormat or "CSV"
	self.exportMember = customMember
	local list, scopeLabel = self:GetTransactionsForExportScope(self.exportScope, self.exportMember)
	local payload = self:ExportTransactionsCSV(list, { format = self.exportFormat })
	self:ShowExportModal(payload, #list, scopeLabel)
end

function Dashboard:ShowExportModal(csvText, rowCount, scopeLabel)
	local UI = EnsureUI()
	if not UI then return end
	if not self.exportFrame then
		local ef = UI:CreateFrame("PluribusOfficerExportModal", UIParent, 680, 444, "Export Audit Trails & DKP Logs (CSV)")
		ef:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

		-- Scope & Format toolbar inside export modal
		ef.scopeButtons = {}
		local scopes = {
			{ id = "FILTERED", label = "Filtered View", w = 96 },
			{ id = "ALL", label = "All Audit Trails", w = 104 },
			{ id = "DKP", label = "DKP Logs", w = 82 },
			{ id = "LOOT", label = "Loot & Auctions", w = 104 },
		}
		local sx = 14
		for _, sc in ipairs(scopes) do
			local sBtn = UI:CreateButton(ef, sc.label, sc.w, 22, function()
				Dashboard.exportMember = nil
				Dashboard:OpenExportDialog(sc.id)
			end)
			sBtn:SetPoint("TOPLEFT", ef, "TOPLEFT", sx, -42)
			ef.scopeButtons[sc.id] = sBtn
			sx = sx + sc.w + 6
		end

		ef.csvBtn = UI:CreateButton(ef, "CSV (,)", 64, 22, function()
			Dashboard.exportFormat = "CSV"
			Dashboard:OpenExportDialog(Dashboard.exportScope or "FILTERED", Dashboard.exportMember)
		end, true)
		ef.csvBtn:SetPoint("TOPRIGHT", ef, "TOPRIGHT", -88, -42)

		ef.tsvBtn = UI:CreateButton(ef, "TSV (Tab)", 70, 22, function()
			Dashboard.exportFormat = "TSV"
			Dashboard:OpenExportDialog(Dashboard.exportScope or "FILTERED", Dashboard.exportMember)
		end, false)
		ef.tsvBtn:SetPoint("TOPRIGHT", ef, "TOPRIGHT", -14, -42)

		local hint = UI:CreateLabel(ef, "Press Ctrl+C to copy CSV for Excel, Google Sheets, or Discord.", 0.72, 0.80, 0.90, "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", ef, "TOPLEFT", 14, -70)
		hint:SetWidth(652)
		hint:SetWordWrap(false)
		ef.hint = hint

		local scroll = UI:CreateScrollFrame(ef, "PluribusOfficerExportScroll", 650, 304)
		scroll:SetPoint("TOPLEFT", ef, "TOPLEFT", 14, -90)

		local eb = CreateFrame("EditBox", nil, scroll.content)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject("ChatFontNormal")
		eb:SetWidth(618)
		eb:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, -4)
		eb:SetScript("OnEscapePressed", function(selfBox) selfBox:ClearFocus(); ef:Hide() end)
		ef.editBox = eb
		ef.scroll = scroll

		local selectBtn = UI:CreateButton(ef, "Select All (Ctrl+C)", 136, 26, function()
			eb:SetFocus()
			eb:HighlightText()
		end, true)
		selectBtn:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", 14, 12)

		local saveSvBtn = UI:CreateButton(ef, "Save to SavedVariables", 164, 26, function()
			local _, db = EnsureTransactionStore()
			db.lastCsvExport = {
				exportedAt = FormatFullTimestamp(time()),
				epoch = time(),
				scope = Dashboard.exportMember and ("MEMBER:" .. Dashboard.exportMember) or (Dashboard.exportScope or "FILTERED"),
				format = Dashboard.exportFormat or "CSV",
				rowCount = ef._lastRowCount or 0,
				data = eb:GetText() or "",
			}
			UI:ShowNotification("|cff4ade80Saved CSV snapshot to SavedVariables/PluribusCore.lua (reload/logout to flush to disk).|r", 4)
		end)
		saveSvBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)

		local closeBtn = UI:CreateButton(ef, "Close", 90, 26, function()
			ef:Hide()
		end)
		closeBtn:SetPoint("BOTTOMRIGHT", ef, "BOTTOMRIGHT", -14, 12)

		self.exportFrame = ef
	end

	local ef = self.exportFrame
	local activeScope = self.exportMember and "" or (self.exportScope or "FILTERED")
	for scId, btn in pairs(ef.scopeButtons or {}) do
		btn:SetActiveState(scId == activeScope)
	end
	if ef.csvBtn then ef.csvBtn:SetActiveState((self.exportFormat or "CSV") == "CSV") end
	if ef.tsvBtn then ef.tsvBtn:SetActiveState(self.exportFormat == "TSV") end

	ef._lastRowCount = rowCount or 0
	local fmtName = self.exportFormat == "TSV" and "TSV" or "CSV"
	ef.hint:SetText(string.format("|cff38bdf8%s|r  ·  %d transaction(s) (%d chars, %s)  —  Press Ctrl+C to copy or save to SavedVariables.",
		tostring(scopeLabel or "Export"),
		rowCount or 0,
		#(csvText or ""),
		fmtName
	))
	ef.editBox:SetText(csvText or "")
	local lineCount = 1
	for _ in tostring(csvText or ""):gmatch("\n") do lineCount = lineCount + 1 end
	ef.scroll.content:SetHeight(math.max(290, lineCount * 16 + 24))
	ef:Show()
	UI:BringToFront(ef)
	ef.editBox:SetFocus()
	ef.editBox:HighlightText()
end

-- ============================================================================
-- DASHBOARD WINDOW & TAB NAVIGATION
-- ============================================================================
function Dashboard:Initialize()
	self:AttachAuditHooks()
	if self.frame then return end
	self:CreateFrame()
end

function Dashboard:CreateFrame()
	if self.frame then return end
	local UI = EnsureUI()
	self:AttachAuditHooks()

	local frame = UI:CreateFrame(
		"PluribusOfficerDashboard",
		UIParent,
		self.config.width,
		self.config.height,
		"Pluribus — Officer Dashboard"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetScript("OnHide", function()
		Dashboard.visible = false
	end)

	-- Persistent visual HiveMind connectivity & data-sync health indicator in Officer Dashboard header
	if frame.header and _G.PluribusHiveUI and _G.PluribusHiveUI.CreateHealthBadge then
		local badge = _G.PluribusHiveUI:CreateHealthBadge(frame.header, function()
			if Dashboard.visible then Dashboard:RefreshContent() end
		end)
		if badge and frame.closeBtn then
			badge:SetPoint("RIGHT", frame.closeBtn, "LEFT", -8, 0)
			frame.healthBadge = badge
		end
	end

	-- Tab bar container (6 cleanly fitted buttons across 856px)
	local tabBar = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	tabBar:SetHeight(34)
	tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)
	tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -44)

	frame.tabs = {}
	local count = #self.tabs
	local gap = 6
	local availW = self.config.width - 24
	local btnWidth = math.floor((availW - gap * (count - 1)) / count)
	for idx, tabDef in ipairs(self.tabs) do
		local tabBtn = UI:CreateButton(tabBar, tabDef.label, btnWidth, 28, function()
			Dashboard:SwitchTab(tabDef.id)
		end)
		tabBtn:SetPoint("LEFT", tabBar, "LEFT", (idx - 1) * (btnWidth + gap), 0)
		frame.tabs[tabDef.id] = tabBtn
	end

	-- Content panel
	local content = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -84)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 14)
	UI:ApplyBackdrop(content, 0.09, 0.11, 0.16, 0.95, 0.22, 0.28, 0.38, 0.85)

	frame.content = content
	frame:Hide()
	self.frame = frame
end

function Dashboard:OpenTransactionHistory(playerFilter, category)
	if not self.frame then
		self:CreateFrame()
	end
	if playerFilter ~= nil then
		self.txSearchQuery = NormalizePlayer(playerFilter)
	end
	if category then
		self.txFilterCategory = tostring(category):upper()
	end
	self.visible = true
	self.frame:Show()
	self:SwitchTab("tx_history")
end

function Dashboard:SwitchTab(tabId)
	self.current_tab = tabId or "overview"
	if self.frame and self.frame.tabs then
		for id, btn in pairs(self.frame.tabs) do
			btn:SetActiveState(id == self.current_tab)
		end
	end
	self:RefreshContent()
end

function Dashboard:RefreshContent()
	if not self.frame or not self.frame.content then return end
	local UI = EnsureUI()
	local content = self.frame.content
	UI:ClearContainer(content)

	local ok, err = pcall(function()
		if self.current_tab == "overview" then
			self:ShowOverview(content)
		elseif self.current_tab == "dkp_management" then
			self:ShowDKPManagement(content)
		elseif self.current_tab == "tx_history" then
			self:ShowTransactionHistory(content)
		elseif self.current_tab == "loot_audits" then
			self:ShowLootAudits(content)
		elseif self.current_tab == "player_status" then
			self:ShowPlayerStatus(content)
		elseif self.current_tab == "settings" then
			self:ShowSettings(content)
		end
	end)

	if not ok then
		local errLbl = UI:CreateLabel(content, "|cfff87171Officer Dashboard render error: " .. tostring(err) .. "|r")
		errLbl:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	end

	-- Re-apply frame level ordering so newly created scroll frames & cards never render behind backdrop
	UI:BringToFront(self.frame)
end

-- ============================================================================
-- TAB 1: OVERVIEW (KPIs + Quick Actions + Recent Audit Preview + Hive Health)
-- ============================================================================
function Dashboard:ShowOverview(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local stats = engine and engine:GetStats() or { total_players = 0, total_ep = 0, total_gp = 0 }
	local memberCount = GetNumGuildMembers and GetNumGuildMembers() or stats.total_players
	local allTx, totalTxCount = self:GetUnifiedTransactions({})

	local heading = UI:CreateLabel(parent, "Guild & Raid Command Summary", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14)

	-- 4 KPI stat boxes
	local cards = {
		{ title = "Guild Members", value = tostring(memberCount), color = { 0.22, 0.74, 0.97 } },
		{ title = "Tracked Raiders", value = tostring(stats.total_players), color = { 0.29, 0.87, 0.50 } },
		{ title = "Total Effort Points", value = tostring(math.floor(stats.total_ep or 0)), color = { 0.98, 0.75, 0.14 } },
		{ title = "Logged Audit Events", value = tostring(totalTxCount or 0), color = { 0.75, 0.52, 0.99 } },
	}
	for i, card in ipairs(cards) do
		local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(198, 68)
		box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 208, -44)
		UI:ApplyBackdrop(box, 0.12, 0.15, 0.21, 1, 0.24, 0.31, 0.42, 0.9)

		local lbl = UI:CreateLabel(box, card.title, 0.65, 0.72, 0.82, "GameFontNormalSmall")
		lbl:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -10)

		local val = UI:CreateLabel(box, card.value, card.color[1], card.color[2], card.color[3], "GameFontNormalLarge")
		val:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 12)
	end

	-- Quick Actions Row
	local openAwardBtn = UI:CreateButton(parent, "Award EP / GP", 154, 26, function()
		Dashboard:SwitchTab("dkp_management")
	end, true)
	openAwardBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -124)

	local openTxBtn = UI:CreateButton(parent, "Transaction History", 154, 26, function()
		Dashboard:SwitchTab("tx_history")
	end)
	openTxBtn:SetPoint("LEFT", openAwardBtn, "RIGHT", 10, 0)

	local openAuctionsBtn = UI:CreateButton(parent, "Open Auction UI", 154, 26, function()
		if _G.PluribusLootAuctionUI and _G.PluribusLootAuctionUI.CreateAuctionFrame then
			_G.PluribusLootAuctionUI:CreateAuctionFrame()
		end
	end)
	openAuctionsBtn:SetPoint("LEFT", openTxBtn, "RIGHT", 10, 0)

	local openDkpBtn = UI:CreateButton(parent, "Open DKP Window", 154, 26, function()
		if _G.PluribusDKPUI and _G.PluribusDKPUI.Show then
			_G.PluribusDKPUI:Show()
		end
	end)
	openDkpBtn:SetPoint("LEFT", openAuctionsBtn, "RIGHT", 10, 0)

	local openTaxBtn = UI:CreateButton(parent, "Guild Tax Vault", 154, 26, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("Guild Tax")
		end
	end)
	openTaxBtn:SetPoint("LEFT", openDkpBtn, "RIGHT", 10, 0)

	-- Recent Transactions & Audit Trail Preview Card
	local recentCard = UI:CreateCard(parent, 824, 152, "Recent Officer Transactions & Audit Trail")
	recentCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -162)

	local viewAllBtn = UI:CreateButton(recentCard, "Full Audit Log (" .. tostring(totalTxCount) .. ")", 136, 20, function()
		Dashboard:SwitchTab("tx_history")
	end)
	viewAllBtn:SetPoint("TOPRIGHT", recentCard, "TOPRIGHT", -10, -7)

	if #allTx == 0 then
		local empty = UI:CreateLabel(recentCard, "|cff94a3b8No transactions recorded yet. Award EP/GP, distribute loot, or click 'Full Audit Log' to record an officer audit entry.|r", nil, nil, nil, "GameFontHighlightSmall")
		empty:SetPoint("TOPLEFT", recentCard, "TOPLEFT", 12, -38)
		empty:SetWidth(790)
	else
		local ry = -32
		for idx = 1, math.min(4, #allTx) do
			local tx = allTx[idx]
			local meta = CATEGORY_META[tx.category] or CATEGORY_META.AUDIT
			local row = UI:CreateListRow(recentCard, 800, 26, idx, function()
				Dashboard.txSelectedId = tx.id
				Dashboard:SwitchTab("tx_history")
			end)
			row:SetPoint("TOPLEFT", recentCard, "TOPLEFT", 12, ry)

			local tLbl = UI:CreateLabel(row, "|cff94a3b8" .. FormatShortTime(tx.timestamp) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			tLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
			tLbl:SetWidth(68)
			tLbl:SetWordWrap(false)

			local tagLbl = UI:CreateLabel(row, meta.hex .. "[" .. meta.label .. "]|r", nil, nil, nil, "GameFontHighlightSmall")
			tagLbl:SetPoint("LEFT", row, "LEFT", 80, 0)
			tagLbl:SetWidth(58)
			tagLbl:SetWordWrap(false)

			local cls = LookupClassForMember(tx.player)
			local _, _, _, pHex = UI:GetClassColor(cls)
			local pLbl = UI:CreateLabel(row, pHex .. tostring(tx.player) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			pLbl:SetPoint("LEFT", row, "LEFT", 142, 0)
			pLbl:SetWidth(120)
			pLbl:SetWordWrap(false)

			local detail = tx.itemName ~= "" and tx.itemName or (ACTION_LABELS[tx.action] or tx.action)
			if tx.unit == "COPPER" then
				detail = FormatGoldCompact(tx.amount) .. " — " .. (tx.reason ~= "" and tx.reason or detail)
			elseif (tonumber(tx.amount) or 0) ~= 0 then
				local bal = (tx.beforeVal ~= nil and tx.afterVal ~= nil)
					and string.format(" (%d -> %d)", math.floor(tx.beforeVal), math.floor(tx.afterVal))
					or ""
				detail = string.format("%+d %s%s · %s", tonumber(tx.amount) or 0, tx.unit, bal, tx.reason ~= "" and tx.reason or detail)
			elseif tx.reason ~= "" then
				detail = detail .. " · " .. tx.reason
			end
			local dLbl = UI:CreateLabel(row, "|cffe2e8f0" .. detail .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			dLbl:SetPoint("LEFT", row, "LEFT", 268, 0)
			dLbl:SetWidth(415)
			dLbl:SetWordWrap(false)

			local oLbl = UI:CreateLabel(row, "|cff94a3b8by " .. tostring(tx.officer or "Officer") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			oLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			oLbl:SetWidth(104)
			oLbl:SetJustifyH("RIGHT")
			oLbl:SetWordWrap(false)

			ry = ry - 28
		end
	end

	-- HiveMind Network Connectivity & Data-Sync Health Panel
	local health = (_G.PluribusHive and _G.PluribusHive.GetNetworkHealth)
		and _G.PluribusHive:GetNetworkHealth()
		or { state = "OFFLINE", label = "Offline", shortLabel = "Offline", color = { 0.97, 0.44, 0.44 }, hex = "|cfff87171", score = 0, isInGuild = false, onlinePeers = 0, queuedMessages = 0, messagesSent = 0, messagesReceived = 0, syncFreshness = "Never", dbRevision = 1, dbItems = 0 }

	if self.frame and self.frame.healthBadge and self.frame.healthBadge.Refresh then
		self.frame.healthBadge:Refresh()
	end

	local hiveCard = UI:CreateCard(parent, 824, 134, "Guild HiveMind Network Connectivity & Data-Sync Health")
	hiveCard:SetPoint("TOPLEFT", recentCard, "BOTTOMLEFT", 0, -10)

	local hc = health.color or { 0.29, 0.87, 0.50 }
	local healthBar = UI:CreateStatusBar(hiveCard, 800, 22, hc[1], hc[2], hc[3])
	healthBar:SetPoint("TOPLEFT", hiveCard, "TOPLEFT", 12, -32)
	healthBar:SetBarData(
		health.score or 0,
		string.format("%s%s|r  ·  Protocol: PLBHIVE (%s)", health.hex, health.label, health.isInGuild and "Guild Connected" or "No Guild"),
		string.format("%d%% Health", health.score or 0),
		hc[1], hc[2], hc[3]
	)

	local metricsStr = string.format(
		"Online Hive Peers: |cff38bdf8%d|r   ·   Last Sync: |cffffffff%s|r   ·   Queue: %d   ·   Packets: %d tx / %d rx   ·   Hive DB: |cfffbbf24Rev v%d (%d items)|r",
		health.onlinePeers or 0,
		health.syncFreshness or "Never",
		health.queuedMessages or 0,
		health.messagesSent or 0,
		health.messagesReceived or 0,
		health.dbRevision or 1,
		health.dbItems or 0
	)
	local mLbl = UI:CreateLabel(hiveCard, metricsStr, 0.82, 0.88, 0.95)
	mLbl:SetPoint("TOPLEFT", hiveCard, "TOPLEFT", 12, -64)
	mLbl:SetWidth(796)
	mLbl:SetWordWrap(false)

	local forceSyncBtn = UI:CreateButton(hiveCard, "Force Guild Hive Sync", 160, 24, function()
		if _G.PluribusHive then _G.PluribusHive:RequestFullGuildSync() end
		if _G.PluribusHiveNetworkDB then _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end
		Dashboard:RefreshContent()
	end, true)
	forceSyncBtn:SetPoint("BOTTOMLEFT", hiveCard, "BOTTOMLEFT", 12, 12)

	local openHiveBtn = UI:CreateButton(hiveCard, "Open Guild Hub", 130, 24, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("Guild Hub")
		end
	end)
	openHiveBtn:SetPoint("LEFT", forceSyncBtn, "RIGHT", 10, 0)
end

-- ============================================================================
-- TAB 2: DKP & AWARDS (Forensic Audit Logging on Every Award / GP / Decay)
-- ============================================================================
function Dashboard:ShowDKPManagement(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()

	local heading = UI:CreateLabel(parent, "Award Points & Guild Decay (Auto-Logged to Audit Trail)", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14)

	local formCard = UI:CreateCard(parent, 824, 152, "Manual EP / GP Award & Scheduled Decay")
	formCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -42)

	local nameLbl = UI:CreateLabel(formCard, "Player Name:", 0.75, 0.82, 0.90, "GameFontHighlightSmall")
	nameLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -32)
	local nameBox = UI:CreateInputBox(formCard, 170, 24)
	nameBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -48)
	if UnitName then
		nameBox:SetText(NormalizePlayer(UnitName("target") or UnitName("player") or ""))
	end

	local amtLbl = UI:CreateLabel(formCard, "Points:", 0.75, 0.82, 0.90, "GameFontHighlightSmall")
	amtLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 196, -32)
	local amtBox = UI:CreateInputBox(formCard, 86, 24)
	amtBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 196, -48)
	amtBox:SetText("50")

	local reasonLbl = UI:CreateLabel(formCard, "Reason / Item Name:", 0.75, 0.82, 0.90, "GameFontHighlightSmall")
	reasonLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 296, -32)
	local reasonBox = UI:CreateInputBox(formCard, 270, 24)
	reasonBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 296, -48)
	reasonBox:SetText("Boss Kill Bonus")

	local decayLbl = UI:CreateLabel(formCard, "Decay %:", 0.75, 0.82, 0.90, "GameFontHighlightSmall")
	decayLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 584, -32)
	local decayBox = UI:CreateInputBox(formCard, 66, 24)
	decayBox:SetPoint("TOPLEFT", formCard, "TOPLEFT", 584, -48)
	decayBox:SetText("10")

	local statusText = UI:CreateLabel(formCard, "|cff94a3b8Every EP award, GP charge, and guild decay is recorded with before/after balances.|r", nil, nil, nil, "GameFontHighlightSmall")
	statusText:SetPoint("BOTTOMLEFT", formCard, "BOTTOMLEFT", 12, 12)
	statusText:SetWidth(796)
	statusText:SetWordWrap(false)

	local awardEpBtn = UI:CreateButton(formCard, "Award EP", 118, 26, function()
		local player = NormalizePlayer(nameBox:GetText() or "")
		local amt = tonumber(amtBox:GetText()) or 0
		local reason = TrimStr(reasonBox:GetText() or "Manual Award")
		if player == "" or amt <= 0 then
			statusText:SetText("|cfff87171Enter a valid player name and positive point amount.|r")
			return
		end
		if engine then
			if not engine:GetPlayer(player) then
				engine:AddPlayer(player, LookupClassForMember(player) or "UNKNOWN", 1)
			end
			local beforeEp = (engine:GetPlayer(player) and engine:GetPlayer(player).ep) or 0
			engine:AwardEP(player, amt, reason)
			local afterEp = (engine:GetPlayer(player) and engine:GetPlayer(player).ep) or (beforeEp + amt)
			Dashboard:RecordTransaction({
				category = "DKP",
				action = "EP_AWARD",
				player = player,
				amount = amt,
				unit = "EP",
				beforeVal = beforeEp,
				afterVal = afterEp,
				reason = reason,
				source = "OfficerDashboard",
			})
		else
			Dashboard:RecordTransaction({
				category = "DKP",
				action = "EP_AWARD",
				player = player,
				amount = amt,
				unit = "EP",
				reason = reason,
				source = "OfficerDashboard",
			})
		end
		Dashboard:RefreshContent()
	end, true)
	awardEpBtn:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -84)

	local awardGpBtn = UI:CreateButton(formCard, "Charge GP", 118, 26, function()
		local player = NormalizePlayer(nameBox:GetText() or "")
		local amt = tonumber(amtBox:GetText()) or 0
		local reason = TrimStr(reasonBox:GetText() or "Loot Award")
		if player == "" or amt <= 0 then
			statusText:SetText("|cfff87171Enter a valid player name and positive GP amount.|r")
			return
		end
		if engine then
			if not engine:GetPlayer(player) then
				engine:AddPlayer(player, LookupClassForMember(player) or "UNKNOWN", 1)
			end
			local beforeGp = (engine:GetPlayer(player) and engine:GetPlayer(player).gp) or 0
			engine:AwardGP(player, amt, reason, reason)
			local afterGp = (engine:GetPlayer(player) and engine:GetPlayer(player).gp) or (beforeGp + amt)
			Dashboard:RecordTransaction({
				category = "DKP",
				action = "GP_CHARGE",
				player = player,
				amount = amt,
				unit = "GP",
				beforeVal = beforeGp,
				afterVal = afterGp,
				itemName = reason,
				reason = reason,
				source = "OfficerDashboard",
			})
		else
			Dashboard:RecordTransaction({
				category = "DKP",
				action = "GP_CHARGE",
				player = player,
				amount = amt,
				unit = "GP",
				itemName = reason,
				reason = reason,
				source = "OfficerDashboard",
			})
		end
		Dashboard:RefreshContent()
	end)
	awardGpBtn:SetPoint("LEFT", awardEpBtn, "RIGHT", 10, 0)

	local decayBtn = UI:CreateButton(formCard, "Apply Decay %", 136, 26, function()
		local pct = tonumber(decayBox:GetText()) or 10
		if pct <= 0 or pct > 50 then
			statusText:SetText("|cfff87171Decay must be between 1% and 50%.|r")
			return
		end
		if engine and engine.ApplyEPDecay then
			engine:ApplyEPDecay(pct)
		end
		Dashboard:RecordTransaction({
			category = "AUDIT",
			action = "DECAY",
			player = "All Raiders",
			amount = pct,
			unit = "%",
			reason = string.format("Officer triggered %d%% EP decay", pct),
			source = "OfficerDashboard",
		})
		Dashboard:RefreshContent()
	end)
	decayBtn:SetPoint("TOPLEFT", formCard, "TOPLEFT", 584, -84)

	-- Recent DKP Awards Ledger Card
	local recentDKP = self:GetUnifiedTransactions({ category = "DKP" })
	local listCard = UI:CreateCard(parent, 824, 272, "Recent DKP / EP / GP Transactions (" .. tostring(#recentDKP) .. ")")
	listCard:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	local openFullBtn = UI:CreateButton(listCard, "Open Full Tx History", 136, 20, function()
		Dashboard.txFilterCategory = "DKP"
		Dashboard:SwitchTab("tx_history")
	end)
	openFullBtn:SetPoint("TOPRIGHT", listCard, "TOPRIGHT", -10, -7)

	local exportDkpBtn = UI:CreateButton(listCard, "Export DKP CSV", 114, 20, function()
		Dashboard:OpenExportDialog("DKP")
	end, true)
	exportDkpBtn:SetPoint("RIGHT", openFullBtn, "LEFT", -6, 0)

	local scroll = UI:CreateScrollFrame(listCard, "PluribusOfficerDKPRecentScroll", 802, 228)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 10, -32)

	if #recentDKP == 0 then
		local empty = UI:CreateLabel(scroll.content, "|cff94a3b8No DKP/EP/GP awards logged yet. Use Award EP or Charge GP above to record your first entry.|r")
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
		scroll.content:SetHeight(220)
	else
		local y = -2
		for idx, tx in ipairs(recentDKP) do
			if idx > 40 then break end
			local row = UI:CreateListRow(scroll.content, 774, 26, idx, function()
				Dashboard.txSelectedId = tx.id
				Dashboard:OpenTransactionHistory(tx.player, "ALL")
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local tLbl = UI:CreateLabel(row, "|cff94a3b8" .. FormatShortTime(tx.timestamp) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			tLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
			tLbl:SetWidth(72)
			tLbl:SetWordWrap(false)

			local pCls = LookupClassForMember(tx.player)
			local _, _, _, pHex = UI:GetClassColor(pCls)
			local pLbl = UI:CreateLabel(row, pHex .. tostring(tx.player) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			pLbl:SetPoint("LEFT", row, "LEFT", 84, 0)
			pLbl:SetWidth(120)
			pLbl:SetWordWrap(false)

			local isGp = tx.action == "GP_CHARGE" or tx.action == "DKP_SPEND"
			local amtColor = isGp and "|cfffbbf24" or "|cff4ade80"
			local aLbl = UI:CreateLabel(row, string.format("%s%+d %s|r", amtColor, tonumber(tx.amount) or 0, tx.unit ~= "" and tx.unit or "DKP"), nil, nil, nil, "GameFontHighlightSmall")
			aLbl:SetPoint("LEFT", row, "LEFT", 210, 0)
			aLbl:SetWidth(86)
			aLbl:SetWordWrap(false)

			local balStr = (tx.beforeVal ~= nil and tx.afterVal ~= nil)
				and string.format("|cff94a3b8%d -> %d|r  ", math.floor(tx.beforeVal), math.floor(tx.afterVal))
				or ""
			local rLbl = UI:CreateLabel(row, balStr .. "|cffe2e8f0" .. tostring(tx.reason or "") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			rLbl:SetPoint("LEFT", row, "LEFT", 302, 0)
			rLbl:SetWidth(352)
			rLbl:SetWordWrap(false)

			local oLbl = UI:CreateLabel(row, "|cff94a3b8" .. tostring(tx.officer or "Officer") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			oLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			oLbl:SetWidth(100)
			oLbl:SetJustifyH("RIGHT")
			oLbl:SetWordWrap(false)

			y = y - 28
		end
		scroll.content:SetHeight(math.max(220, math.abs(y) + 8))
	end
end

-- ============================================================================
-- TAB 3: DETAILED TRANSACTION HISTORY & FORENSIC AUDIT TRAIL
-- ============================================================================
function Dashboard:ShowTransactionHistory(parent)
	local UI = EnsureUI()

	local list, totalAll = self:GetUnifiedTransactions({
		category = self.txFilterCategory,
		timeframeSec = self.txFilterTimeframe,
		query = self.txSearchQuery,
	})
	local summary = self:GetTransactionSummary(list)

	-- Ensure selected ID points to a valid visible row if available
	local selectedTx = nil
	for _, tx in ipairs(list) do
		if tx.id == self.txSelectedId then
			selectedTx = tx
			break
		end
	end
	if not selectedTx and list[1] then
		selectedTx = list[1]
		self.txSelectedId = selectedTx.id
	end

	-- 1. Compact KPI Summary Strip (4 live metrics)
	local kpis = {
		{ title = "Matching Events", val = string.format("%d / %d", summary.total, totalAll or 0), color = { 0.22, 0.74, 0.97 } },
		{ title = "DKP Awards", val = string.format("%d (%+d EP / %+d GP)", summary.dkpCount, math.floor(summary.netEP), math.floor(summary.netGP)), color = { 0.29, 0.87, 0.50 } },
		{ title = "Loot Distributions", val = tostring(summary.lootCount), color = { 0.75, 0.52, 0.99 } },
		{ title = "Audit & Tax Trails", val = string.format("%d audit · %d tax", summary.auditCount, summary.taxCount), color = { 0.98, 0.75, 0.14 } },
	}
	for i, k in ipairs(kpis) do
		local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(200, 44)
		box:SetPoint("TOPLEFT", parent, "TOPLEFT", 14 + (i - 1) * 209, -10)
		UI:ApplyBackdrop(box, 0.12, 0.15, 0.21, 1, 0.24, 0.31, 0.42, 0.85)
		local l = UI:CreateLabel(box, k.title, 0.65, 0.72, 0.82, "GameFontHighlightSmall")
		l:SetPoint("TOPLEFT", box, "TOPLEFT", 9, -5)
		l:SetWidth(182)
		l:SetWordWrap(false)
		local v = UI:CreateLabel(box, k.val, k.color[1], k.color[2], k.color[3], "GameFontNormalSmall")
		v:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 9, 6)
		v:SetWidth(182)
		v:SetWordWrap(false)
	end

	-- 2. Filter & Search Toolbar
	local toolCard = UI:CreateCard(parent, 828, 66)
	toolCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -60)

	local cats = {
		{ id = "ALL", label = "All", w = 44 },
		{ id = "DKP", label = "DKP Awards", w = 84 },
		{ id = "LOOT", label = "Loot Dist.", w = 74 },
		{ id = "AUDIT", label = "Audit Trail", w = 78 },
		{ id = "TAX", label = "Tax", w = 44 },
	}
	local cx = 8
	for _, cDef in ipairs(cats) do
		local btn = UI:CreateButton(toolCard, cDef.label, cDef.w, 22, function()
			Dashboard.txFilterCategory = cDef.id
			Dashboard:RefreshContent()
		end, self.txFilterCategory == cDef.id)
		btn:SetPoint("TOPLEFT", toolCard, "TOPLEFT", cx, -8)
		cx = cx + cDef.w + 5
	end

	-- Timeframe buttons on right side of row 1
	local times = {
		{ sec = 0, label = "All", w = 36 },
		{ sec = 86400, label = "24h", w = 38 },
		{ sec = 604800, label = "7d", w = 34 },
		{ sec = 2592000, label = "30d", w = 38 },
	}
	local txX = -8
	for i = #times, 1, -1 do
		local tDef = times[i]
		local btn = UI:CreateButton(toolCard, tDef.label, tDef.w, 22, function()
			Dashboard.txFilterTimeframe = tDef.sec
			Dashboard:RefreshContent()
		end, self.txFilterTimeframe == tDef.sec)
		btn:SetPoint("TOPRIGHT", toolCard, "TOPRIGHT", txX, -8)
		txX = txX - (tDef.w + 4)
	end

	-- Search & Actions Row 2 inside toolbar
	local sLbl = UI:CreateLabel(toolCard, "Search Member / Item / Reason:", 0.72, 0.80, 0.90, "GameFontHighlightSmall")
	sLbl:SetPoint("BOTTOMLEFT", toolCard, "BOTTOMLEFT", 10, 12)

	local searchBox = UI:CreateInputBox(toolCard, 240, 22)
	searchBox:SetPoint("LEFT", sLbl, "RIGHT", 8, 0)
	searchBox:SetText(self.txSearchQuery or "")
	searchBox:SetScript("OnEnterPressed", function(selfBox)
		selfBox:ClearFocus()
		Dashboard.txSearchQuery = TrimStr(selfBox:GetText() or "")
		Dashboard:RefreshContent()
	end)

	local applyBtn = UI:CreateButton(toolCard, "Filter", 56, 22, function()
		Dashboard.txSearchQuery = TrimStr(searchBox:GetText() or "")
		Dashboard:RefreshContent()
	end, true)
	applyBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)

	local clearBtn = UI:CreateButton(toolCard, "Clear", 52, 22, function()
		Dashboard.txSearchQuery = ""
		Dashboard.txFilterCategory = "ALL"
		Dashboard.txFilterTimeframe = 0
		Dashboard:RefreshContent()
	end)
	clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 5, 0)

	local exportBtn = UI:CreateButton(toolCard, "Export CSV", 92, 22, function()
		Dashboard:OpenExportDialog("FILTERED")
	end, true)
	exportBtn:SetPoint("BOTTOMRIGHT", toolCard, "BOTTOMRIGHT", -8, 8)

	local logToggleBtn = UI:CreateButton(toolCard, self.txShowManualForm and "Hide Form" or "+ Log Loot / Audit", 122, 22, function()
		Dashboard.txShowManualForm = not Dashboard.txShowManualForm
		Dashboard:RefreshContent()
	end, self.txShowManualForm)
	logToggleBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)

	-- 3. Optional Inline Manual Loot Distribution / Officer Audit Entry Form
	local listTopY = -132
	local listHeight = 244
	if self.txShowManualForm then
		local mCard = UI:CreateCard(parent, 828, 62)
		mCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -132)
		listTopY = -200
		listHeight = 176

		local lootModeBtn = UI:CreateButton(mCard, "Loot Dist.", 74, 22, function()
			Dashboard.txManualKind = "LOOT"
			Dashboard:RefreshContent()
		end, self.txManualKind == "LOOT")
		lootModeBtn:SetPoint("TOPLEFT", mCard, "TOPLEFT", 8, -8)

		local auditModeBtn = UI:CreateButton(mCard, "Audit Note", 78, 22, function()
			Dashboard.txManualKind = "AUDIT"
			Dashboard:RefreshContent()
		end, self.txManualKind == "AUDIT")
		auditModeBtn:SetPoint("LEFT", lootModeBtn, "RIGHT", 4, 0)

		local mMember = UI:CreateInputBox(mCard, 118, 22)
		mMember:SetPoint("LEFT", auditModeBtn, "RIGHT", 8, 0)
		mMember:SetText(NormalizePlayer((UnitName and (UnitName("target") or UnitName("player"))) or ""))

		local mItem = UI:CreateInputBox(mCard, 176, 22)
		mItem:SetPoint("LEFT", mMember, "RIGHT", 6, 0)
		mItem:SetText(self.txManualKind == "LOOT" and "Item Name or Shift-Click" or "Policy / Audit Subject")

		local mCost = UI:CreateInputBox(mCard, 56, 22)
		mCost:SetPoint("LEFT", mItem, "RIGHT", 6, 0)
		mCost:SetText(self.txManualKind == "LOOT" and "100" or "0")

		local mReason = UI:CreateInputBox(mCard, 180, 22)
		mReason:SetPoint("LEFT", mCost, "RIGHT", 6, 0)
		mReason:SetText(self.txManualKind == "LOOT" and "Main Spec Award" or "Officer Audit Entry")

		local saveBtn = UI:CreateButton(mCard, "Record", 72, 22, function()
			local pl = NormalizePlayer(mMember:GetText() or "")
			local itemTxt = TrimStr(mItem:GetText() or "")
			local costVal = tonumber(mCost:GetText()) or 0
			local rsn = TrimStr(mReason:GetText() or "")
			if pl == "" then pl = "Guild" end
			if Dashboard.txManualKind == "LOOT" then
				Dashboard:RecordTransaction({
					category = "LOOT",
					action = "LOOT_DIST",
					player = pl,
					amount = costVal,
					unit = costVal > 0 and "GP" or "",
					itemName = itemTxt,
					reason = rsn ~= "" and rsn or "Manual Loot Distribution",
					source = "OfficerDashboard",
				})
				if _G.PluribusLootHistory and _G.PluribusLootHistory.LogLootAward then
					pcall(function()
						_G.PluribusLootHistory:LogLootAward({
							playerName = pl,
							itemName = itemTxt,
							value = costVal,
							reason = rsn,
							source = "OfficerDashboard",
						})
					end)
				end
			else
				Dashboard:RecordTransaction({
					category = "AUDIT",
					action = "MANUAL_AUDIT",
					player = pl,
					amount = costVal,
					unit = costVal ~= 0 and "DKP" or "",
					itemName = itemTxt,
					reason = rsn ~= "" and rsn or itemTxt,
					source = "OfficerDashboard",
				})
			end
			Dashboard.txShowManualForm = false
			Dashboard:RefreshContent()
		end, true)
		saveBtn:SetPoint("RIGHT", mCard, "RIGHT", -8, 12)

		local guideLbl = UI:CreateLabel(mCard, "|cff94a3b8Fields: [Member]  [Item / Subject]  [Cost]  [Reason] — Syncs automatically to online guild officers over PLBHIVE.|r", nil, nil, nil, "GameFontHighlightSmall")
		guideLbl:SetPoint("BOTTOMLEFT", mCard, "BOTTOMLEFT", 10, 8)
		guideLbl:SetWidth(804)
		guideLbl:SetWordWrap(false)
	end

	-- 4. Scrollable Detailed Transaction Table
	local tableCard = UI:CreateCard(parent, 828, listHeight)
	tableCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, listTopY)

	-- Column Header Strip
	local colHdr = CreateFrame("Frame", nil, tableCard, BackdropTemplateMixin and "BackdropTemplate" or nil)
	colHdr:SetSize(810, 22)
	colHdr:SetPoint("TOPLEFT", tableCard, "TOPLEFT", 9, -7)
	UI:ApplyBackdrop(colHdr, 0.14, 0.18, 0.26, 0.95, 0.24, 0.31, 0.42, 0.7)

	local cols = {
		{ x = 8, w = 72, text = "TIME" },
		{ x = 82, w = 68, text = "TYPE" },
		{ x = 152, w = 116, text = "MEMBER" },
		{ x = 272, w = 190, text = "DELTA / ITEM" },
		{ x = 466, w = 232, text = "BALANCE / AUDIT DETAILS" },
		{ x = 702, w = 96, text = "OFFICER" },
	}
	for _, col in ipairs(cols) do
		local hl = UI:CreateLabel(colHdr, col.text, 0.68, 0.76, 0.88, "GameFontHighlightSmall")
		hl:SetPoint("LEFT", colHdr, "LEFT", col.x, 0)
		hl:SetWidth(col.w)
		hl:SetWordWrap(false)
	end

	local scroll = UI:CreateScrollFrame(tableCard, "PluribusOfficerTxHistoryScroll", 810, listHeight - 36)
	scroll:SetPoint("TOPLEFT", tableCard, "TOPLEFT", 9, -31)

	if #list == 0 then
		local emptyMsg = (totalAll or 0) == 0
			and "No guild transactions recorded yet. Award EP/GP, complete a loot auction, or click '+ Log Loot / Audit' above."
			or "No transactions match the current category, timeframe, or search filter. Click 'Clear' to view all."
		local empty = UI:CreateLabel(scroll.content, "|cff94a3b8" .. emptyMsg .. "|r")
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 10, -14)
		empty:SetWidth(760)
		scroll.content:SetHeight(listHeight - 40)
	else
		local y = -2
		for idx, tx in ipairs(list) do
			if idx > 120 then break end
			local meta = CATEGORY_META[tx.category] or CATEGORY_META.AUDIT
			local isSelected = (selectedTx and tx.id == selectedTx.id)
			local row = UI:CreateListRow(scroll.content, 782, 26, idx, function()
				Dashboard.txSelectedId = tx.id
				Dashboard:RefreshContent()
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			if isSelected then
				UI:ApplyBackdrop(row, 0.14, 0.24, 0.38, 0.95, 0.22, 0.74, 0.97, 0.9)
			end

			-- Item tooltip hover when row has an itemLink
			if tx.itemLink and tx.itemLink ~= "" then
				row:HookScript("OnEnter", function(selfRow)
					if GameTooltip then
						GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
						pcall(GameTooltip.SetHyperlink, GameTooltip, tx.itemLink)
						GameTooltip:Show()
					end
				end)
				row:HookScript("OnLeave", function()
					if GameTooltip then GameTooltip:Hide() end
				end)
			end

			local timeLbl = UI:CreateLabel(row, "|cff94a3b8" .. FormatShortTime(tx.timestamp) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			timeLbl:SetPoint("LEFT", row, "LEFT", 6, 0)
			timeLbl:SetWidth(72)
			timeLbl:SetWordWrap(false)

			local typeLbl = UI:CreateLabel(row, meta.hex .. (ACTION_LABELS[tx.action] or meta.label) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			typeLbl:SetPoint("LEFT", row, "LEFT", 80, 0)
			typeLbl:SetWidth(70)
			typeLbl:SetWordWrap(false)

			local pCls = LookupClassForMember(tx.player)
			local _, _, _, pHex = UI:GetClassColor(pCls)
			local memLbl = UI:CreateLabel(row, pHex .. tostring(tx.player or "Guild") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			memLbl:SetPoint("LEFT", row, "LEFT", 152, 0)
			memLbl:SetWidth(114)
			memLbl:SetWordWrap(false)

			-- Delta / Item summary
			local deltaText = ""
			if tx.category == "LOOT" then
				local itemDisp = (tx.itemLink and tx.itemLink ~= "") and tx.itemLink or (tx.itemName ~= "" and tx.itemName or "Loot Item")
				if (tonumber(tx.amount) or 0) > 0 then
					deltaText = string.format("%s |cfffbbf24(%d %s)|r", itemDisp, math.floor(tx.amount), tx.unit ~= "" and tx.unit or "GP")
				else
					deltaText = itemDisp
				end
			elseif tx.unit == "COPPER" then
				deltaText = "|cfffbbf24" .. FormatGoldCompact(tx.amount) .. "|r"
			elseif (tonumber(tx.amount) or 0) ~= 0 then
				local colHex = (tx.action == "GP_CHARGE" or tx.action == "DKP_SPEND" or tx.action == "DECAY") and "|cfffbbf24" or "|cff4ade80"
				local sign = (tx.action == "DECAY") and "-" or (tx.amount > 0 and "+" or "")
				deltaText = string.format("%s%s%d %s|r", colHex, sign, math.floor(tx.amount), tx.unit ~= "" and tx.unit or "pts")
				if tx.itemName ~= "" and tx.itemName ~= tx.reason then
					deltaText = deltaText .. " · " .. tx.itemName
				end
			else
				deltaText = "|cff94a3b8" .. (tx.itemName ~= "" and tx.itemName or (ACTION_LABELS[tx.action] or "Audit")) .. "|r"
			end
			local deltaLbl = UI:CreateLabel(row, deltaText, nil, nil, nil, "GameFontHighlightSmall")
			deltaLbl:SetPoint("LEFT", row, "LEFT", 270, 0)
			deltaLbl:SetWidth(188)
			deltaLbl:SetWordWrap(false)

			-- Before -> After balance + reason
			local detailParts = {}
			if tx.beforeVal ~= nil and tx.afterVal ~= nil then
				table.insert(detailParts, string.format("|cff38bdf8[%d -> %d]|r", math.floor(tx.beforeVal), math.floor(tx.afterVal)))
			end
			if tx.reason and tx.reason ~= "" then
				table.insert(detailParts, "|cffe2e8f0" .. tx.reason .. "|r")
			end
			local detailLbl = UI:CreateLabel(row, table.concat(detailParts, " "), nil, nil, nil, "GameFontHighlightSmall")
			detailLbl:SetPoint("LEFT", row, "LEFT", 464, 0)
			detailLbl:SetWidth(230)
			detailLbl:SetWordWrap(false)

			local offLbl = UI:CreateLabel(row, "|cff94a3b8" .. tostring(tx.officer or "Officer") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
			offLbl:SetPoint("LEFT", row, "LEFT", 700, 0)
			offLbl:SetWidth(76)
			offLbl:SetWordWrap(false)

			y = y - 28
		end
		scroll.content:SetHeight(math.max(listHeight - 40, math.abs(y) + 8))
	end

	-- 5. Forensic Audit Inspector Footer Card
	local inspCard = UI:CreateCard(parent, 828, 102, selectedTx and ("Forensic Audit Inspector · " .. tostring(selectedTx.id or "TX")) or "Forensic Audit Inspector")
	inspCard:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 12)

	if not selectedTx then
		local noSel = UI:CreateLabel(inspCard, "|cff94a3b8Click any transaction row above to inspect its full audit trail, balances, officer attribution, and chat sharing actions.|r", nil, nil, nil, "GameFontHighlightSmall")
		noSel:SetPoint("TOPLEFT", inspCard, "TOPLEFT", 12, -36)
		noSel:SetWidth(800)
	else
		local meta = CATEGORY_META[selectedTx.category] or CATEGORY_META.AUDIT
		local balSummary = (selectedTx.beforeVal ~= nil and selectedTx.afterVal ~= nil)
			and string.format("Balance: |cff38bdf8%d -> %d %s|r", math.floor(selectedTx.beforeVal), math.floor(selectedTx.afterVal), selectedTx.unit or "")
			or ("Source: |cffcbd5e1" .. tostring(selectedTx.source or "OfficerDashboard") .. "|r")

		local line1 = UI:CreateLabel(inspCard, string.format(
			"%s%s|r  ·  Member: |cffffffff%s|r  ·  Officer: |cffcbd5e1%s|r  ·  When: |cff94a3b8%s|r  ·  %s",
			meta.hex,
			ACTION_LABELS[selectedTx.action] or tostring(selectedTx.action),
			tostring(selectedTx.player or "Guild"),
			tostring(selectedTx.officer or "Officer"),
			FormatFullTimestamp(selectedTx.timestamp),
			balSummary
		), nil, nil, nil, "GameFontHighlightSmall")
		line1:SetPoint("TOPLEFT", inspCard, "TOPLEFT", 12, -30)
		line1:SetWidth(800)
		line1:SetWordWrap(false)

		local itemStr = (selectedTx.itemLink and selectedTx.itemLink ~= "") and selectedTx.itemLink
			or (selectedTx.itemName ~= "" and selectedTx.itemName or "—")
		local line2 = UI:CreateLabel(inspCard, string.format(
			"Item / Subject: |cffe2e8f0%s|r   ·   Reason: |cffcbd5e1%s|r",
			itemStr,
			selectedTx.reason ~= "" and selectedTx.reason or "None"
		), nil, nil, nil, "GameFontHighlightSmall")
		line2:SetPoint("TOPLEFT", inspCard, "TOPLEFT", 12, -49)
		line2:SetWidth(540)
		line2:SetWordWrap(false)

		-- Inspector Quick Action Buttons
		local filterMemberBtn = UI:CreateButton(inspCard, "Member Trail", 102, 22, function()
			Dashboard.txSearchQuery = NormalizePlayer(selectedTx.player or "")
			Dashboard.txFilterCategory = "ALL"
			Dashboard:RefreshContent()
		end)
		filterMemberBtn:SetPoint("BOTTOMLEFT", inspCard, "BOTTOMLEFT", 12, 10)

		local postOfficerBtn = UI:CreateButton(inspCard, "Post to /o", 86, 22, function()
			local msg = Dashboard:FormatAuditChatLine(selectedTx)
			if SendChatMessage and IsInGuild and IsInGuild() then
				pcall(SendChatMessage, msg, "OFFICER")
			elseif _G.PluribusUtils then
				_G.PluribusUtils:Print(msg, "Audit")
			end
		end)
		postOfficerBtn:SetPoint("LEFT", filterMemberBtn, "RIGHT", 6, 0)

		local postGuildBtn = UI:CreateButton(inspCard, "Post to /g", 86, 22, function()
			local msg = Dashboard:FormatAuditChatLine(selectedTx)
			if SendChatMessage and IsInGuild and IsInGuild() then
				pcall(SendChatMessage, msg, "GUILD")
			elseif _G.PluribusUtils then
				_G.PluribusUtils:Print(msg, "Audit")
			end
		end)
		postGuildBtn:SetPoint("LEFT", postOfficerBtn, "RIGHT", 6, 0)

		local clearFilterBtn = UI:CreateButton(inspCard, "Show All Members", 124, 22, function()
			Dashboard.txSearchQuery = ""
			Dashboard:RefreshContent()
		end)
		clearFilterBtn:SetPoint("BOTTOMRIGHT", inspCard, "BOTTOMRIGHT", -12, 10)

		local exportMemberBtn = UI:CreateButton(inspCard, "Export Member CSV", 132, 22, function()
			Dashboard:OpenExportDialog("ALL", NormalizePlayer(selectedTx.player or ""))
		end)
		exportMemberBtn:SetPoint("RIGHT", clearFilterBtn, "LEFT", -6, 0)
	end
end

-- ============================================================================
-- TAB 4: LOOT AUDITS (Scrollable Loot Auction & Distribution Audit View)
-- ============================================================================
function Dashboard:ShowLootAudits(parent)
	local UI = EnsureUI()
	local heading = UI:CreateLabel(parent, "Loot Distributions & Closed Auctions", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14)

	local openFullBtn = UI:CreateButton(parent, "Filter in Tx History", 136, 24, function()
		Dashboard:OpenTransactionHistory("", "LOOT")
	end)
	openFullBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -12)

	local exportLootBtn = UI:CreateButton(parent, "Export Loot CSV", 122, 24, function()
		Dashboard:OpenExportDialog("LOOT")
	end, true)
	exportLootBtn:SetPoint("RIGHT", openFullBtn, "LEFT", -8, 0)

	local lootTx = self:GetUnifiedTransactions({ category = "LOOT" })
	local card = UI:CreateCard(parent, 824, 424, "Recorded Loot Events (" .. tostring(#lootTx) .. ")")
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -46)

	local scroll = UI:CreateScrollFrame(card, "PluribusOfficerLootAuditScroll", 802, 382)
	scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -32)

	if #lootTx == 0 then
		local empty = UI:CreateLabel(scroll.content, "|cff94a3b8No loot distributions or closed auctions logged yet. Use /loot auction create or '+ Log Loot / Audit' in Tx History.|r")
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 8, -10)
		empty:SetWidth(760)
		scroll.content:SetHeight(360)
		return
	end

	local y = -2
	for idx, entry in ipairs(lootTx) do
		if idx > 80 then break end
		local row = UI:CreateListRow(scroll.content, 774, 28, idx, function()
			Dashboard.txSelectedId = entry.id
			Dashboard:OpenTransactionHistory(entry.player, "LOOT")
		end)
		row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

		if entry.itemLink and entry.itemLink ~= "" then
			row:HookScript("OnEnter", function(selfRow)
				if GameTooltip then
					GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
					pcall(GameTooltip.SetHyperlink, GameTooltip, entry.itemLink)
					GameTooltip:Show()
				end
			end)
			row:HookScript("OnLeave", function()
				if GameTooltip then GameTooltip:Hide() end
			end)
		end

		local tLbl = UI:CreateLabel(row, "|cff94a3b8" .. FormatShortTime(entry.timestamp) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		tLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
		tLbl:SetWidth(72)
		tLbl:SetWordWrap(false)

		local itemDisp = (entry.itemLink and entry.itemLink ~= "") and entry.itemLink or (entry.itemName ~= "" and entry.itemName or "Unknown Item")
		local iLbl = UI:CreateLabel(row, "|cffc084fc" .. itemDisp .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		iLbl:SetPoint("LEFT", row, "LEFT", 86, 0)
		iLbl:SetWidth(220)
		iLbl:SetWordWrap(false)

		local pCls = LookupClassForMember(entry.player)
		local _, _, _, pHex = UI:GetClassColor(pCls)
		local wLbl = UI:CreateLabel(row, "Winner: " .. pHex .. tostring(entry.player or "No Bids") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		wLbl:SetPoint("LEFT", row, "LEFT", 314, 0)
		wLbl:SetWidth(160)
		wLbl:SetWordWrap(false)

		local cLbl = UI:CreateLabel(row, string.format("|cfffbbf24%d %s|r", math.floor(entry.amount or 0), entry.unit ~= "" and entry.unit or "GP"), nil, nil, nil, "GameFontHighlightSmall")
		cLbl:SetPoint("LEFT", row, "LEFT", 482, 0)
		cLbl:SetWidth(80)
		cLbl:SetWordWrap(false)

		local rLbl = UI:CreateLabel(row, "|cff94a3b8" .. tostring(entry.reason or "") .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		rLbl:SetPoint("LEFT", row, "LEFT", 568, 0)
		rLbl:SetWidth(196)
		rLbl:SetWordWrap(false)

		y = y - 30
	end
	scroll.content:SetHeight(math.max(360, math.abs(y) + 8))
end

-- ============================================================================
-- TAB 5: RANKINGS (With 1-Click Per-Member Audit Trail Drill-Down)
-- ============================================================================
function Dashboard:ShowPlayerStatus(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local heading = UI:CreateLabel(parent, "Live Priority Rankings (Click Audit to Inspect Member History)", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14)

	local ranked = engine and engine:GetRankedPlayers() or {}
	local card = UI:CreateCard(parent, 824, 424, "Tracked Raiders (" .. tostring(#ranked) .. ")")
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -46)

	local scroll = UI:CreateScrollFrame(card, "PluribusOfficerRankingsScroll", 802, 382)
	scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -32)

	if #ranked == 0 then
		local empty = UI:CreateLabel(scroll.content, "|cff94a3b8No players tracked yet. Award EP on the DKP & Awards tab to register raiders.|r")
		empty:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 8, -10)
		scroll.content:SetHeight(360)
		return
	end

	local y = -2
	for i, player in ipairs(ranked) do
		local row = UI:CreateListRow(scroll.content, 774, 28, i, function()
			Dashboard:OpenTransactionHistory(player.name, "ALL")
		end)
		row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

		local rankLbl = UI:CreateLabel(row, "|cff94a3b8#" .. tostring(i) .. "|r", nil, nil, nil, "GameFontHighlightSmall")
		rankLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
		rankLbl:SetWidth(36)

		local _, _, _, pHex = UI:GetClassColor(player.class)
		local nameLbl = UI:CreateLabel(row, pHex .. tostring(player.name) .. "|r", nil, nil, nil, "GameFontNormalSmall")
		nameLbl:SetPoint("LEFT", row, "LEFT", 48, 0)
		nameLbl:SetWidth(180)
		nameLbl:SetWordWrap(false)

		local epLbl = UI:CreateLabel(row, string.format("EP: |cff4ade80%d|r", math.floor(player.ep or 0)), nil, nil, nil, "GameFontHighlightSmall")
		epLbl:SetPoint("LEFT", row, "LEFT", 240, 0)
		epLbl:SetWidth(110)

		local gpLbl = UI:CreateLabel(row, string.format("GP: |cfffbbf24%d|r", math.floor(player.gp or 0)), nil, nil, nil, "GameFontHighlightSmall")
		gpLbl:SetPoint("LEFT", row, "LEFT", 360, 0)
		gpLbl:SetWidth(110)

		local prLbl = UI:CreateLabel(row, string.format("Priority: |cff38bdf8%.2f|r", tonumber(player.priority) or 0), nil, nil, nil, "GameFontHighlightSmall")
		prLbl:SetPoint("LEFT", row, "LEFT", 480, 0)
		prLbl:SetWidth(140)

		local auditBtn = UI:CreateButton(row, "Audit Trail", 92, 20, function()
			Dashboard:OpenTransactionHistory(player.name, "ALL")
		end)
		auditBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		y = y - 30
	end
	scroll.content:SetHeight(math.max(360, math.abs(y) + 8))
end

-- ============================================================================
-- TAB 6: SETTINGS
-- ============================================================================
function Dashboard:ShowSettings(parent)
	local UI = EnsureUI()
	local engine = GetDKPEngine()
	local heading = UI:CreateLabel(parent, "Point System & UI Theme", 0.96, 0.98, 1.0, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)

	local sysLbl = UI:CreateLabel(parent, "Active Loot Priority Mode:", 0.75, 0.80, 0.88)
	sysLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -54)

	local systems = {
		{ id = "epgp", label = "EPGP" },
		{ id = "dkp", label = "DKP" },
		{ id = "sk", label = "Suicide Kings" },
		{ id = "zero", label = "Zero-Sum" },
	}
	for i, sys in ipairs(systems) do
		local btn = UI:CreateButton(parent, sys.label, 120, 26, function()
			if engine and engine.SetSystemType then
				engine:SetSystemType(sys.id)
				Dashboard:RefreshContent()
			end
		end, engine and engine.system_type == sys.id)
		btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 130, -80)
	end

	local themeLbl = UI:CreateLabel(parent, "Interface Theme:", 0.75, 0.80, 0.88)
	themeLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -130)

	local darkBtn = UI:CreateButton(parent, "Obsidian Dark", 130, 26, function()
		UI:LoadTheme("obsidian")
		Dashboard:RefreshContent()
	end, UI.theme ~= "light")
	darkBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -156)

	local lightBtn = UI:CreateButton(parent, "Light Slate", 130, 26, function()
		UI:LoadTheme("light")
		Dashboard:RefreshContent()
	end, UI.theme == "light")
	lightBtn:SetPoint("LEFT", darkBtn, "RIGHT", 10, 0)

	local suiteLbl = UI:CreateLabel(parent, "Full Suite & HiveMind Settings:", 0.75, 0.80, 0.88)
	suiteLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -206)

	local allSettingsBtn = UI:CreateButton(parent, "Open Unified Pluribus Settings", 220, 28, function()
		if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
			_G.PluribusSettingsPanel:Open()
		end
	end, true)
	allSettingsBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -232)
end

function Dashboard:Toggle()
	if self.visible then
		self:Hide()
	else
		self:Show()
	end
end

function Dashboard:Show()
	if not self.frame then
		self:CreateFrame()
	end
	self:AttachAuditHooks()
	self.visible = true
	self.frame:Show()
	self:SwitchTab(self.current_tab)
end

function Dashboard:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self.visible = false
end

if PluribusCore.SlashCommand then
	PluribusCore.SlashCommand:Register("dashboard", function(args)
		if args == "show" then
			Dashboard:Show()
		elseif args == "hide" then
			Dashboard:Hide()
		elseif args == "history" or args == "audit" then
			Dashboard:OpenTransactionHistory("", "ALL")
		else
			Dashboard:Toggle()
		end
	end, "Open Officer Dashboard")
end

return PluribusCore.OfficerDashboard
