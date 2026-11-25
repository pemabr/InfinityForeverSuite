-- PluribusHive Auction House Integration & Guild Price Network
-- Full Auction House Auto-Scan on Open (with 20-minute persisted cooldown)
-- Clean, mutually exclusive right-edge side tabs (starts closed on AH open, zero overlap)

PluribusHiveAuction = {
	initialized = false,
	attachedFrame = nil,
	panel = nil,
	sideTabs = nil,
	lastScanTime = 0,
	activeTab = nil, -- nil (closed) | "needs" | "prices"
	ahOpen = false,
	FULL_SCAN_COOLDOWN = 20 * 60, -- 20 minutes in seconds
	fullScanActive = false,
	fullScanProcessing = false,
	fullScanMode = nil, -- "getall" | "paged" | "replicate"
	fullScanPage = 0,
	fullScanTotalPages = 0,
	fullScanSeen = {},
	fullScanMeta = {},
	fullScanProcessed = 0,
	fullScanTotal = 0,
	fullScanMaxPct = 0,
	fullScanStatusText = "",
	priceRevision = 1,
	_queryCache = {},
	_queryCacheOrder = {},
	_queryWorkers = {},
	_needsBadgeCount = 0,
	_needsBadgeAt = 0,
}
_G.PluribusHiveAuction = PluribusHiveAuction

function PluribusHiveAuction:GetPriceRevision()
	return self.priceRevision or 1
end

function PluribusHiveAuction:BumpPriceRevision()
	self.priceRevision = (self.priceRevision or 1) + 1
	self._queryCache = {}
	self._queryCacheOrder = {}
end

function PluribusHiveAuction:GetFullScanCooldownRemaining(nowSec)
	local now = nowSec or time()
	local db = PluribusHive:GetDB()
	local lastAt = tonumber(db and db.lastFullAHScanAt) or 0
	if lastAt <= 0 then return 0 end
	local elapsed = now - lastAt
	if elapsed < 0 then return 0 end
	local rem = self.FULL_SCAN_COOLDOWN - elapsed
	return rem > 0 and rem or 0
end

function PluribusHiveAuction:CanAutoFullScan(nowSec)
	local cfg = PluribusHive:GetConfig()
	if cfg.autoScanAH == false then return false end
	if self.fullScanActive then return false end
	return self:GetFullScanCooldownRemaining(nowSec) <= 0
end

function PluribusHiveAuction:FormatCooldownText(remSec)
	remSec = math.max(0, math.floor(tonumber(remSec) or 0))
	if remSec <= 0 then return "Ready" end
	local mins = math.floor(remSec / 60)
	local secs = remSec % 60
	return string.format("%dm %02ds", mins, secs)
end

function PluribusHiveAuction:RecordPrice(itemID, unitCopper, reporter, broadcast, itemName, itemQuality)
	itemID = tonumber(itemID)
	unitCopper = tonumber(unitCopper)
	if not itemID or not unitCopper or unitCopper <= 0 then return end

	local db = PluribusHive:GetDB()
	local existing = db.prices[itemID]
	local now = time()

	local avg = unitCopper
	if existing and existing.copper and (now - (existing.seenAt or 0)) < 21600 then
		avg = math.floor((existing.copper * 0.6) + (unitCopper * 0.4))
	end

	local cachedName = itemName or (existing and existing.name) or nil
	local cachedQuality = itemQuality or (existing and existing.quality) or nil

	db.prices[itemID] = {
		itemID = itemID,
		name = cachedName,
		quality = cachedQuality,
		copper = avg,
		minCopper = (existing and existing.minCopper and (now - (existing.seenAt or 0)) < 3600)
			and math.min(existing.minCopper, unitCopper) or unitCopper,
		reporter = reporter or PluribusHive:GetPlayerShortName(),
		seenAt = now,
	}
	self:BumpPriceRevision()

	if broadcast and PluribusHive:GetConfig().shareAuctionPrices then
		PluribusHive:Send("AH", string.format("%d|%d|%d", itemID, avg, now), "GUILD")
	end
end

-- Auto-detect 1.12 vs 1.14+/Classic/Warcraft Forever GetAuctionItemInfo return signature
-- 1.14+: name, tex, count, qual, canUse, lvl, levelColHeader(string), minBid, minInc, buyoutPrice, bidAmt, ..., itemId(#17)
-- 1.12 : name, tex, count, qual, canUse, lvl, minBid(number),         minInc, buyoutPrice, bidAmt
local function ParseClassicAuctionRow(listType, index)
	if not GetAuctionItemInfo then return nil, nil, nil, nil end
	local name, _, count, qual, _, _, a7, a8, a9, a10, a11, _, _, _, _, _, a17 = GetAuctionItemInfo(listType, index)
	local minBid, buyoutPrice, bidAmount, itemID
	if type(a7) == "string" then
		minBid = tonumber(a8) or 0
		buyoutPrice = tonumber(a10) or 0
		bidAmount = tonumber(a11) or 0
		itemID = tonumber(a17)
	else
		minBid = tonumber(a7) or 0
		buyoutPrice = tonumber(a9) or 0
		bidAmount = tonumber(a10) or 0
		itemID = tonumber(a17)
	end
	if not itemID and GetAuctionItemLink then
		local link = GetAuctionItemLink(listType, index)
		itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link) or nil
	end
	local effectivePrice = (buyoutPrice > 0 and buyoutPrice)
		or (bidAmount > 0 and bidAmount)
		or (minBid > 0 and minBid)
		or 0
	if not itemID or effectivePrice <= 0 then return nil, nil, nil, nil end
	local stack = (tonumber(count) and tonumber(count) > 0) and tonumber(count) or 1
	return itemID, math.max(1, math.floor(effectivePrice / stack)), name, tonumber(qual)
end

function PluribusHiveAuction:GetPrice(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	local db = PluribusHive:GetDB()
	local rec = db.prices[itemID] or db.prices[tostring(itemID)]
	if rec and rec.copper and rec.copper > 0 then
		return rec
	end
	-- Secondary fallback: read Auctionator API if user also runs Auctionator
	if _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1 and _G.Auctionator.API.v1.GetAuctionPriceByItemID then
		local ok, p = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemID, "PluribusCore", itemID)
		if ok and tonumber(p) and tonumber(p) > 0 then
			return { itemID = itemID, copper = tonumber(p), minCopper = tonumber(p), reporter = "Auctionator", seenAt = time() }
		end
	end
	return nil
end

function PluribusHiveAuction:UpdateStatusBar()
	if not self.panel or not self.panel.scanStatusLbl then return end
	if self.fullScanActive then
		self.panel.scanStatusLbl:SetText("|cff38bdf8" .. (self.fullScanStatusText ~= "" and self.fullScanStatusText or "Full AH scan in progress...") .. "|r")
	else
		local rem = self:GetFullScanCooldownRemaining()
		if rem > 0 then
			self.panel.scanStatusLbl:SetText("|cff94a3b8Full AH auto-scan CD: |cfffbbf24" .. self:FormatCooldownText(rem) .. "|r")
		else
			self.panel.scanStatusLbl:SetText("|cff4ade80Full AH scan ready (20m CD)|r")
		end
	end
end

-- Commit all prices gathered during a full AH scan in 3ms frame slices (zero FPS drop!) + 1 compressed guild AHBATCH packet
function PluribusHiveAuction:FinishFullScan(aborted)
	if not self.fullScanActive then return end
	local seen = self.fullScanSeen or {}
	local seenMeta = self.fullScanMeta or {}
	local me = PluribusHive:GetPlayerShortName()
	local db = PluribusHive:GetDB()
	local now = time()

	-- Build fast flat list so commit can be frame-sliced without freezing FPS
	local keys = {}
	for itemID in pairs(seen) do
		table.insert(keys, itemID)
	end
	local totalUnique = #keys

	self.fullScanActive = false
	self.fullScanProcessing = false
	self.fullScanMode = nil
	self.fullScanSeen = {}
	self.fullScanMeta = {}
	self.fullScanTotal = 0
	self.fullScanMaxPct = 0
	self.fullScanStatusText = ""
	if self.scanFrame then self.scanFrame:SetScript("OnUpdate", nil) end

	if not aborted or totalUnique >= 25 then
		db.lastFullAHScanAt = now
	end

	-- Commit directly to db.prices with lightweight 3ms frame budget
	local commitIdx = 1
	local function FinishCommit()
		-- Broadcast up to 50 priority prices in ONE single compressed AHBATCH message (instead of 40 separate packets!)
		if PluribusHive:GetConfig().shareAuctionPrices and totalUnique > 0 then
			local guildNeeds = {}
			for _, n in ipairs(self:GetAllGuildNeededItems() or {}) do
				guildNeeds[n.itemID] = true
			end
			local batch = {}
			for _, itemID in ipairs(keys) do
				if guildNeeds[itemID] then
					table.insert(batch, 1, itemID .. ":" .. seen[itemID])
				elseif #batch < 60 then
					table.insert(batch, itemID .. ":" .. seen[itemID])
				end
			end
			while #batch > 50 do table.remove(batch) end
			if #batch > 0 then
				PluribusHive:SendBackground("AHBATCH", tostring(now) .. "|" .. table.concat(batch, ","), "AHBATCH", "GUILD")
			end
		end

		self:BumpPriceRevision()
		self:UpdateStatusBar()
		if _G.PluribusUtils then
			if aborted then
				_G.PluribusUtils:Info("AH scan paused (" .. tostring(totalUnique) .. " items saved).", "HiveMarket")
			else
				_G.PluribusUtils:Info("Fast AH scan complete: " .. tostring(totalUnique) .. " unique item prices updated (next auto-scan in 20m).", "HiveMarket")
			end
		end
		if self.panel and self.panel:IsVisible() then
			self:RefreshPanel()
		end
		if _G.PluribusMainFrame and _G.PluribusMainFrame.RefreshMarketPanelIfVisible then
			_G.PluribusMainFrame:RefreshMarketPanelIfVisible()
		end
	end

	local sliceFrame = self.scanFrame or CreateFrame("Frame")
	self.scanFrame = sliceFrame
	sliceFrame:SetScript("OnUpdate", function(f)
		local startMs = debugprofilestop and debugprofilestop() or (GetTime() * 1000)
		local budgetMs = 3.0
		while commitIdx <= totalUnique do
			local itemID = keys[commitIdx]
			local unitPrice = seen[itemID]
			local existing = db.prices[itemID]
			local avg = unitPrice
			if existing and existing.copper and (now - (existing.seenAt or 0)) < 21600 then
				avg = math.floor((existing.copper * 0.6) + (unitPrice * 0.4))
			end
			local meta = seenMeta[itemID]
			db.prices[itemID] = {
				itemID = itemID,
				name = (meta and meta.name) or (existing and existing.name) or nil,
				quality = (meta and meta.quality) or (existing and existing.quality) or nil,
				copper = avg,
				minCopper = (existing and existing.minCopper and (now - (existing.seenAt or 0)) < 3600)
					and math.min(existing.minCopper, unitPrice) or unitPrice,
				reporter = me,
				seenAt = now,
			}
			commitIdx = commitIdx + 1
			if (commitIdx % 120) == 0 then
				local spent = (debugprofilestop and debugprofilestop() or (GetTime() * 1000)) - startMs
				if spent >= budgetMs then return end
			end
		end
		f:SetScript("OnUpdate", nil)
		FinishCommit()
	end)
end

-- Auctionator-style zero-lag OnUpdate frame-budgeted slicer for Classic getAll dump (max 4.0ms/frame, monotonic progress, NEVER restarts on repeated AUCTION_ITEM_LIST_UPDATE!)
function PluribusHiveAuction:ProcessGetAllBatch(totalCount)
	totalCount = tonumber(totalCount) or 0
	if totalCount <= 0 then
		if not self.fullScanProcessing then
			self:FinishFullScan(false)
		end
		return
	end
	if self.fullScanProcessing then
		-- Repeated AUCTION_ITEM_LIST_UPDATE while already slicing: extend totalCount smoothly without EVER resetting idx!
		if totalCount > (self.fullScanTotal or 0) then
			self.fullScanTotal = totalCount
		end
		return
	end

	local getInfo = GetAuctionItemInfo
	if not getInfo then
		self:FinishFullScan(true)
		return
	end

	self.fullScanProcessing = true
	self.fullScanTotal = totalCount
	self.fullScanMaxPct = 0
	local idx = 1
	local seen = self.fullScanSeen
	local seenMeta = self.fullScanMeta or {}
	self.fullScanMeta = seenMeta
	local sliceFrame = self.scanFrame or CreateFrame("Frame")
	self.scanFrame = sliceFrame
	local lastUiUpdate = 0

	sliceFrame:SetScript("OnUpdate", function(f)
		if not PluribusHiveAuction.fullScanActive or PluribusHiveAuction.fullScanMode ~= "getall" then
			f:SetScript("OnUpdate", nil)
			return
		end
		local targetTotal = PluribusHiveAuction.fullScanTotal or totalCount
		local startMs = debugprofilestop and debugprofilestop() or (GetTime() * 1000)
		local budgetMs = 4.0
		while idx <= targetTotal do
			local name, _, count, qual, _, _, a7, a8, a9, a10, a11, _, _, _, _, _, a17 = getInfo("list", idx)
			local itemID = a17
			if itemID then
				if name and name ~= "" and not seenMeta[itemID] then
					seenMeta[itemID] = { name = name, quality = tonumber(qual) }
				end
				local buyout, bid, minBid
				if type(a7) == "string" then
					minBid, buyout, bid = a8 or 0, a10 or 0, a11 or 0
				else
					minBid, buyout, bid = a7 or 0, a9 or 0, a10 or 0
				end
				local eff = (buyout > 0 and buyout) or (bid > 0 and bid) or (minBid > 0 and minBid) or 0
				if eff > 0 then
					local stack = (count and count > 0) and count or 1
					local unitPrice = math.floor(eff / stack)
					if unitPrice < 1 then unitPrice = 1 end
					local prev = seen[itemID]
					if not prev or unitPrice < prev then
						seen[itemID] = unitPrice
					end
				end
			end
			idx = idx + 1
			if (idx % 150) == 0 then
				local spent = (debugprofilestop and debugprofilestop() or (GetTime() * 1000)) - startMs
				if spent >= budgetMs then break end
			end
		end

		local done = math.min(idx - 1, targetTotal)
		PluribusHiveAuction.fullScanProcessed = done
		local rawPct = math.min(100, math.floor((done / math.max(1, targetTotal)) * 100))
		if rawPct > (PluribusHiveAuction.fullScanMaxPct or 0) then
			PluribusHiveAuction.fullScanMaxPct = rawPct
		end
		local nowT = GetTime()
		if (nowT - lastUiUpdate) >= 0.15 or idx > targetTotal then
			lastUiUpdate = nowT
			PluribusHiveAuction.fullScanStatusText = string.format("Fast Scan: %d%% (%d/%d)", PluribusHiveAuction.fullScanMaxPct, done, targetTotal)
			PluribusHiveAuction:UpdateStatusBar()
		end

		if idx > targetTotal then
			-- Check once if more items arrived before concluding
			local okN, liveBatch = pcall(GetNumAuctionItems, "list")
			if okN and tonumber(liveBatch) and tonumber(liveBatch) > targetTotal then
				PluribusHiveAuction.fullScanTotal = tonumber(liveBatch)
				return
			end
			f:SetScript("OnUpdate", nil)
			PluribusHiveAuction:FinishFullScan(false)
		end
	end)
end

-- Request next page in a Classic paged full AH scan
function PluribusHiveAuction:QueryNextPagedScan()
	if not self.fullScanActive or self.fullScanMode ~= "paged" or not self.ahOpen then
		return
	end
	if not CanSendAuctionQuery or not QueryAuctionItems then
		self:FinishFullScan(true)
		return
	end
	local canQuery = CanSendAuctionQuery()
	if canQuery then
		self.fullScanStatusText = string.format(
			"Scanning AH page %d%s...",
			self.fullScanPage + 1,
			self.fullScanTotalPages > 0 and (" / " .. self.fullScanTotalPages) or ""
		)
		self:UpdateStatusBar()
		pcall(QueryAuctionItems, "", nil, nil, 0, 0, self.fullScanPage, false, false, false)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(0.35, function()
			PluribusHiveAuction:QueryNextPagedScan()
		end)
	end
end

-- Process a Classic page result during paged full scan
function PluribusHiveAuction:ProcessPagedScanUpdate()
	if not self.fullScanActive or self.fullScanMode ~= "paged" or not GetNumAuctionItems then return end
	local ok, numBatch, totalAuctions = pcall(GetNumAuctionItems, "list")
	if not ok then return end
	numBatch = tonumber(numBatch) or 0
	totalAuctions = tonumber(totalAuctions) or numBatch
	self.fullScanTotalPages = math.max(1, math.ceil(totalAuctions / 50))

	self.fullScanMeta = self.fullScanMeta or {}
	for i = 1, numBatch do
		local itemID, unitPrice, name, qual = ParseClassicAuctionRow("list", i)
		if itemID and unitPrice and unitPrice > 0 then
			if name and name ~= "" and not self.fullScanMeta[itemID] then
				self.fullScanMeta[itemID] = { name = name, quality = qual }
			end
			if not self.fullScanSeen[itemID] or unitPrice < self.fullScanSeen[itemID] then
				self.fullScanSeen[itemID] = unitPrice
			end
		end
	end

	self.fullScanPage = self.fullScanPage + 1
	self.fullScanStatusText = string.format("Scanning AH page %d / %d...", math.min(self.fullScanPage, self.fullScanTotalPages), self.fullScanTotalPages)
	self:UpdateStatusBar()

	if self.fullScanPage >= self.fullScanTotalPages or numBatch == 0 then
		self:FinishFullScan(false)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(0.35, function()
			PluribusHiveAuction:QueryNextPagedScan()
		end)
	end
end

-- Frame-budgeted zero-lag C_AuctionHouse.ReplicateItems() dump processor (4ms/frame, monotonic progress, NEVER restarts on repeated REPLICATE_ITEM_LIST_UPDATE!)
function PluribusHiveAuction:ProcessReplicateDump()
	if not self.fullScanActive or self.fullScanMode ~= "replicate" then return end
	if not (C_AuctionHouse and C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetReplicateItemInfo) then
		self:FinishFullScan(true)
		return
	end
	local total = C_AuctionHouse.GetNumReplicateItems() or 0
	if total <= 0 then
		if not self.fullScanProcessing then
			self:FinishFullScan(false)
		end
		return
	end
	if self.fullScanProcessing then
		-- Repeated REPLICATE_ITEM_LIST_UPDATE while already slicing: extend total smoothly without EVER resetting idx!
		if total > (self.fullScanTotal or 0) then
			self.fullScanTotal = total
		end
		return
	end

	self.fullScanProcessing = true
	self.fullScanTotal = total
	self.fullScanMaxPct = 0
	local idx = 0
	local getRep = C_AuctionHouse.GetReplicateItemInfo
	local seen = self.fullScanSeen
	local seenMeta = self.fullScanMeta or {}
	self.fullScanMeta = seenMeta
	local sliceFrame = self.scanFrame or CreateFrame("Frame")
	self.scanFrame = sliceFrame
	local lastUiUpdate = 0

	sliceFrame:SetScript("OnUpdate", function(f)
		if not PluribusHiveAuction.fullScanActive or PluribusHiveAuction.fullScanMode ~= "replicate" then
			f:SetScript("OnUpdate", nil)
			return
		end
		local targetTotal = PluribusHiveAuction.fullScanTotal or total
		local startMs = debugprofilestop and debugprofilestop() or (GetTime() * 1000)
		local budgetMs = 4.0
		while idx < targetTotal do
			local name, _, count, qual, _, _, _, minBid, _, buyoutPrice, bidAmount, _, _, _, _, _, itemID = getRep(idx)
			if itemID then
				if name and name ~= "" and not seenMeta[itemID] then
					seenMeta[itemID] = { name = name, quality = tonumber(qual) }
				end
				local eff = (buyoutPrice and buyoutPrice > 0 and buyoutPrice)
					or (bidAmount and bidAmount > 0 and bidAmount)
					or (minBid and minBid > 0 and minBid)
					or 0
				if eff > 0 then
					local stack = (count and count > 0) and count or 1
					local unitPrice = math.floor(eff / stack)
					if unitPrice < 1 then unitPrice = 1 end
					local prev = seen[itemID]
					if not prev or unitPrice < prev then
						seen[itemID] = unitPrice
					end
				end
			end
			idx = idx + 1
			if (idx % 150) == 0 then
				local spent = (debugprofilestop and debugprofilestop() or (GetTime() * 1000)) - startMs
				if spent >= budgetMs then break end
			end
		end

		local done = math.min(idx, targetTotal)
		PluribusHiveAuction.fullScanProcessed = done
		local rawPct = math.min(100, math.floor((done / math.max(1, targetTotal)) * 100))
		if rawPct > (PluribusHiveAuction.fullScanMaxPct or 0) then
			PluribusHiveAuction.fullScanMaxPct = rawPct
		end
		local nowT = GetTime()
		if (nowT - lastUiUpdate) >= 0.15 or idx >= targetTotal then
			lastUiUpdate = nowT
			PluribusHiveAuction.fullScanStatusText = string.format("Fast Scan: %d%% (%d/%d)", PluribusHiveAuction.fullScanMaxPct, done, targetTotal)
			PluribusHiveAuction:UpdateStatusBar()
		end
		if idx >= targetTotal then
			local liveTotal = (C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems()) or targetTotal
			if liveTotal > targetTotal then
				PluribusHiveAuction.fullScanTotal = liveTotal
				return
			end
			f:SetScript("OnUpdate", nil)
			PluribusHiveAuction:FinishFullScan(false)
		end
	end)
end

-- Check if Auctionator is loaded (if so, reuse Auctionator's super-fast scan DB instead of double-scanning!)
function PluribusHiveAuction:IsAuctionatorPresent()
	return (_G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1 and _G.Auctionator.API.v1.GetAuctionPriceByItemID) ~= nil
end

-- Start an instant zero-lag AH full scan (NEVER falls back to slow 300-page crawling!)
function PluribusHiveAuction:StartFullScan(isManual)
	if not self.ahOpen then return false end
	if self.fullScanActive then return false end

	-- If Auctionator is installed and this is an automatic scan, defer to Auctionator's native DB to avoid double server queries & lag!
	if not isManual and self:IsAuctionatorPresent() then
		self.fullScanStatusText = "Synced with Auctionator (0ms lag)"
		self:UpdateStatusBar()
		return false
	end

	local rem = self:GetFullScanCooldownRemaining()
	if rem > 0 and not isManual then
		self:UpdateStatusBar()
		return false
	end

	self.fullScanSeen = {}
	self.fullScanMeta = {}
	self.fullScanProcessing = false
	self.fullScanProcessed = 0
	self.fullScanTotal = 0
	self.fullScanMaxPct = 0
	self.fullScanPage = 0
	self.fullScanTotalPages = 0

	-- 1. Modern C_AuctionHouse.ReplicateItems() (single packet, ~1.5s total with 3ms/frame slicer)
	if C_AuctionHouse and C_AuctionHouse.ReplicateItems then
		self.fullScanActive = true
		self.fullScanMode = "replicate"
		self.fullScanStatusText = "Fast AH snapshot..."
		self:UpdateStatusBar()
		local ok = pcall(C_AuctionHouse.ReplicateItems)
		if not ok then
			self.fullScanActive = false
			self.fullScanMode = nil
			return false
		end
		return true
	end

	-- 2. Classic / Warcraft Forever fast single-packet GetAll dump (NEVER slow 300-page crawl!)
	if CanSendAuctionQuery and QueryAuctionItems then
		local ok, _, canQueryAll = pcall(CanSendAuctionQuery)
		if ok and canQueryAll then
			self.fullScanActive = true
			self.fullScanMode = "getall"
			self.fullScanStatusText = "Fast AH dump (GetAll)..."
			self:UpdateStatusBar()
			pcall(QueryAuctionItems, "", nil, nil, 0, 0, 0, false, false, true)
			return true
		else
			-- Blizzard's 15m GetAll throttle is active: stay lag-free & passively record browsed pages instead of crawling 300 pages!
			self.fullScanStatusText = "GetAll CD — passive fast capture active"
			self:UpdateStatusBar()
			if isManual and _G.PluribusUtils then
				_G.PluribusUtils:Info("Fast AH GetAll is on Blizzard's 15m server cooldown. Browsing records prices instantly with zero lag!", "HiveMarket")
			end
			return false
		end
	end
	return false
end

-- Scan currently visible Auction House browse results (lightweight passive capture during manual browsing)
function PluribusHiveAuction:ScanVisibleListings()
	local now = GetTime()
	if (now - self.lastScanTime) < 1.5 then return 0 end
	self.lastScanTime = now

	local lowest = {}
	local meta = {}
	local scanned = 0

	if GetNumAuctionItems and GetAuctionItemInfo then
		local ok, numBatch = pcall(GetNumAuctionItems, "list")
		if ok and numBatch and numBatch > 0 then
			local limit = math.min(numBatch, 100)
			for i = 1, limit do
				local itemID, unitPrice, name, qual = ParseClassicAuctionRow("list", i)
				if itemID and unitPrice and unitPrice > 0 then
					if name and name ~= "" and not meta[itemID] then
						meta[itemID] = { name = name, quality = qual }
					end
					if not lowest[itemID] or unitPrice < lowest[itemID] then
						lowest[itemID] = unitPrice
					end
					scanned = scanned + 1
				end
			end
		end
	end

	if scanned == 0 and C_AuctionHouse and C_AuctionHouse.GetBrowseResults then
		local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
		if ok and type(results) == "table" then
			for _, res in ipairs(results) do
				local itemID = res.itemKey and res.itemKey.itemID
				local price = res.minPrice
				if itemID and price and price > 0 then
					if not lowest[itemID] or price < lowest[itemID] then
						lowest[itemID] = price
					end
					scanned = scanned + 1
				end
			end
		end
	end

	local me = PluribusHive:GetPlayerShortName()
	local recorded = 0
	for itemID, unitPrice in pairs(lowest) do
		local m = meta[itemID]
		self:RecordPrice(itemID, unitPrice, me, true, m and m.name or nil, m and m.quality or nil)
		recorded = recorded + 1
	end

	if recorded > 0 and self.panel and self.panel:IsVisible() then
		self:RefreshPanel()
	end
	return recorded
end

-- Helper to pre-fill and trigger a native Auction House search by item name (returns true if AH was open)
function PluribusHiveAuction:SearchNativeAH(itemName)
	if not itemName or itemName == "" then return false end
	if _G.AuctionFrame and _G.AuctionFrame:IsShown() then
		if _G.AuctionFrameTab1 and _G.AuctionFrameTab1.Click then
			pcall(_G.AuctionFrameTab1.Click, _G.AuctionFrameTab1)
		end
		if _G.BrowseName and _G.BrowseName.SetText then
			_G.BrowseName:SetText(itemName)
			if _G.AuctionFrameBrowse_Search then
				pcall(_G.AuctionFrameBrowse_Search)
				return true
			end
		end
		if QueryAuctionItems and CanSendAuctionQuery and CanSendAuctionQuery() then
			pcall(QueryAuctionItems, itemName, nil, nil, 0, 0, 0, false, false, false)
			return true
		end
	elseif _G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown() then
		if _G.AuctionHouseFrame.SearchBar and _G.AuctionHouseFrame.SearchBar.SearchBox then
			_G.AuctionHouseFrame.SearchBar.SearchBox:SetText(itemName)
			if _G.AuctionHouseFrame.SearchBar.StartSearch then
				pcall(function() _G.AuctionHouseFrame.SearchBar:StartSearch() end)
				return true
			end
		elseif C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
			pcall(C_AuctionHouse.SendBrowseQuery, { searchString = itemName, sorts = {}, filters = {} })
			return true
		end
	end
	if _G.PluribusUIFramework then
		local L = _G.PluribusL
		local msg = L and L:Get("TODO_OPEN_AH_HINT", itemName) or ("Open the Auction House to search for '" .. itemName .. "'.")
		_G.PluribusUIFramework:ShowNotification("|cfffbbf24" .. msg .. "|r", 3)
	end
	return false
end

-- Gather all items guildmates currently need for professions
function PluribusHiveAuction:GetAllGuildNeededItems()
	local db = PluribusHive:GetDB()
	local me = PluribusHive:GetPlayerShortName()
	local byItem = {}

	for memberName, rec in pairs(db.guildProfs or {}) do
		if memberName ~= me and rec.needs then
			for itemID, n in pairs(rec.needs) do
				byItem[itemID] = byItem[itemID] or { itemID = itemID, needers = {} }
				table.insert(byItem[itemID].needers, { name = memberName, prof = n.prof or "Craft", qty = n.qty or 10 })
			end
		end
	end

	local list = {}
	for itemID, data in pairs(byItem) do
		local name, link, quality = PluribusUtils:GetItemInfo(itemID)
		local priceInfo = self:GetPrice(itemID)
		table.insert(list, {
			itemID = itemID,
			name = name or ("Item #" .. itemID),
			link = link,
			quality = quality or 1,
			needers = data.needers,
			price = priceInfo and priceInfo.copper or nil,
		})
	end
	table.sort(list, function(a, b)
		if #a.needers ~= #b.needers then return #a.needers > #b.needers end
		return a.name < b.name
	end)
	return list
end

-- ============================================================================
-- ZERO-LAG REVISION-KEYED, FRAME-BUDGETED MARKET QUERY & SORT ENGINE
-- Shared by MainFrame (AH Market & P2P DB) and the docked AH Side Drawer.
-- Guarantees <= ~2.5ms/frame even with 15,000+ AH items, O(1) cache hits on
-- page flips / tab re-opens, and O(N) bounded Top-K for top-N drawers.
-- ============================================================================
local MAX_QUERY_CACHE = 8
local CHUNK_RUN_SIZE = 400
local SYNC_SORT_THRESHOLD = 600

local function NowMs()
	if debugprofilestop then
		return debugprofilestop()
	end
	return (GetTime and GetTime() or 0) * 1000
end

local function ResolveCachedNameFast(itemID, info, netItems)
	if info and info.name and info.name ~= "" then
		return info.name, info.quality
	end
	if netItems then
		local net = netItems[itemID] or netItems[tostring(itemID)]
		if net and net.name and net.name ~= "" then
			if info then info.name = net.name end
			return net.name, net.quality or (info and info.quality)
		end
	end
	if C_Item and C_Item.GetItemNameByID then
		local cn = C_Item.GetItemNameByID(itemID)
		if cn and cn ~= "" then
			if info then info.name = cn end
			return cn, info and info.quality
		end
	end
	return "Item #" .. tostring(itemID), info and info.quality or 1
end

local function GetMarketComparator(sortMode)
	if sortMode == "price" then
		return function(a, b)
			local ac, bc = a.copper or 0, b.copper or 0
			if ac ~= bc then return ac > bc end
			return (a.itemID or 0) < (b.itemID or 0)
		end
	elseif sortMode == "name" then
		return function(a, b)
			local an, bn = a.nameLower or "", b.nameLower or ""
			if an ~= bn then return an < bn end
			return (a.itemID or 0) < (b.itemID or 0)
		end
	else
		return function(a, b)
			local at, bt = a.seenAt or 0, b.seenAt or 0
			if at ~= bt then return at > bt end
			return (a.itemID or 0) < (b.itemID or 0)
		end
	end
end

local function InsertBoundedTopK(list, maxK, rec, cmp)
	local n = #list
	if n >= maxK and not cmp(rec, list[n]) then
		return false
	end
	local pos = n + 1
	if n >= maxK then
		pos = maxK
		list[maxK] = rec
	else
		list[pos] = rec
	end
	while pos > 1 and cmp(list[pos], list[pos - 1]) do
		list[pos], list[pos - 1] = list[pos - 1], list[pos]
		pos = pos - 1
	end
	return true
end

function PluribusHiveAuction:PutQueryCache(cacheKey, items, totalCached)
	self._queryCache = self._queryCache or {}
	self._queryCacheOrder = self._queryCacheOrder or {}
	if not self._queryCache[cacheKey] then
		self._queryCacheOrder[#self._queryCacheOrder + 1] = cacheKey
		while #self._queryCacheOrder > MAX_QUERY_CACHE do
			local oldest = table.remove(self._queryCacheOrder, 1)
			if oldest then self._queryCache[oldest] = nil end
		end
	end
	self._queryCache[cacheKey] = {
		items = items,
		totalCached = totalCached,
	}
end

function PluribusHiveAuction:CancelMarketQuery(ownerKey)
	ownerKey = ownerKey or "mainFrame"
	local w = self._queryWorkers and self._queryWorkers[ownerKey]
	if w then
		w.gen = (w.gen or 0) + 1
		if w.frame then
			w.frame:SetScript("OnUpdate", nil)
			w.frame:Hide()
		end
	end
end

function PluribusHiveAuction:QueryMarketPricesAsync(opts)
	opts = opts or {}
	local ownerKey = opts.owner or "mainFrame"
	local q = tostring(opts.query or ""):lower():match("^%s*(.-)%s*$") or ""
	local sortMode = opts.sortMode or "recent"
	local budgetMs = tonumber(opts.budgetMs) or 2.5
	local previewSize = tonumber(opts.previewSize) or 25
	local topKOnly = tonumber(opts.topKOnly) or 0
	local onProgress = opts.onProgress
	local onComplete = opts.onComplete

	local priceRev = self:GetPriceRevision()
	local netRev = (_G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.GetDataRevision)
		and _G.PluribusHiveNetworkDB:GetDataRevision() or 1
	local cacheKey = string.format("%d|%d|%s|%d|%s", priceRev, netRev, sortMode, topKOnly, q)

	-- O(1) Cache Hit (instant page flips, sort-back, and tab re-opens!)
	local cached = self._queryCache and self._queryCache[cacheKey]
	if cached then
		self:CancelMarketQuery(ownerKey)
		if onComplete then
			onComplete(cached.items, cached.totalCached, true)
		end
		return true
	end

	-- Setup per-owner worker frame (reused forever, zero frame leaks)
	self._queryWorkers = self._queryWorkers or {}
	local worker = self._queryWorkers[ownerKey]
	if not worker then
		local wf = CreateFrame("Frame")
		wf:Hide()
		worker = { frame = wf, gen = 0 }
		self._queryWorkers[ownerKey] = worker
	end
	worker.gen = (worker.gen or 0) + 1
	local myGen = worker.gen

	local db = PluribusHive:GetDB()
	local rawPrices = db and db.prices or {}
	local netStore = _G.PluribusHiveNetworkDB and _G.PluribusHiveNetworkDB.GetStore and _G.PluribusHiveNetworkDB:GetStore() or nil
	local netItems = netStore and netStore.items or nil

	local cmp = GetMarketComparator(sortMode)
	local needNamesNow = (q ~= "" or sortMode == "name")
	local qNum = tonumber(q)

	local phase = "scan" -- scan -> runsort -> merge -> done
	local cursor = nil
	local totalCached = 0
	local matched = {}
	local previewTop = {}
	local previewDirty = false
	local jobPriceRev = priceRev

	-- Chunked run-sort / merge state
	local runs = nil
	local nextRunStart = 1
	local mergeNextRuns = nil
	local mergePairIdx = 1
	local mergeA, mergeB, mergeOut, mergeIA, mergeIB = nil, nil, nil, 1, 1

	local function FinishJob(resultList)
		if worker.gen ~= myGen then return end
		phase = "done"
		worker.frame:SetScript("OnUpdate", nil)
		worker.frame:Hide()
		local finalKey = string.format("%d|%d|%s|%d|%s", jobPriceRev, netRev, sortMode, topKOnly, q)
		self:PutQueryCache(finalKey, resultList, totalCached)
		if onComplete then
			onComplete(resultList, totalCached, false)
		end
	end

	local function StepSlice()
		if worker.gen ~= myGen then
			worker.frame:SetScript("OnUpdate", nil)
			worker.frame:Hide()
			return
		end

		-- If prices mutated mid-scan, cleanly restart from updated revision
		local curRev = self:GetPriceRevision()
		if curRev ~= jobPriceRev then
			jobPriceRev = curRev
			db = PluribusHive:GetDB()
			rawPrices = db and db.prices or {}
			phase = "scan"
			cursor = nil
			totalCached = 0
			matched = {}
			previewTop = {}
			previewDirty = false
			runs = nil
		end

		local startMs = NowMs()

		if phase == "scan" then
			local batchCount = 0
			while true do
				local okNext, nextK, info = pcall(next, rawPrices, cursor)
				if not okNext then
					-- Table shape shifted unexpectedly; restart scan safely
					cursor = nil
					totalCached = 0
					matched = {}
					previewTop = {}
					return
				end
				cursor = nextK
				if cursor == nil then
					-- Scan finished!
					if topKOnly > 0 then
						FinishJob(previewTop)
						return
					end
					if #matched <= SYNC_SORT_THRESHOLD then
						table.sort(matched, cmp)
						FinishJob(matched)
						return
					end
					phase = "runsort"
					runs = {}
					nextRunStart = 1
					break
				end

				if type(info) == "table" then
					totalCached = totalCached + 1
					local itemID = tonumber(cursor) or cursor
					local include = true
					local displayName, cachedQual, lowerName = nil, info.quality or 1, nil

					if needNamesNow then
						displayName, cachedQual = ResolveCachedNameFast(itemID, info, netItems)
						cachedQual = cachedQual or 1
						lowerName = displayName:lower()
						if q ~= "" then
							include = (qNum ~= nil and itemID == qNum)
								or (lowerName:find(q, 1, true) ~= nil)
								or (tostring(itemID) == q)
						end
					end

					if include then
						if topKOnly > 0 then
							-- O(N) bounded Top-K: skip allocating a record unless it beats tail!
							local copperVal = info.copper or 0
							local seenVal = info.seenAt or 0
							local tail = previewTop[topKOnly]
							local canEnter = (tail == nil)
							if not canEnter then
								if sortMode == "price" then
									canEnter = copperVal > (tail.copper or 0) or (copperVal == (tail.copper or 0) and (itemID or 0) < (tail.itemID or 0))
								elseif sortMode == "name" then
									canEnter = (lowerName or "") < (tail.nameLower or "")
								else
									canEnter = seenVal > (tail.seenAt or 0) or (seenVal == (tail.seenAt or 0) and (itemID or 0) < (tail.itemID or 0))
								end
							end
							if canEnter then
								local rec = {
									itemID = itemID,
									info = info,
									name = displayName,
									nameLower = lowerName,
									quality = cachedQual,
									copper = copperVal,
									reporter = info.reporter or "?",
									seenAt = seenVal,
								}
								if InsertBoundedTopK(previewTop, topKOnly, rec, cmp) then
									previewDirty = true
								end
							end
						else
							local rec = {
								itemID = itemID,
								info = info,
								name = displayName,
								nameLower = lowerName,
								quality = cachedQual,
								copper = info.copper or 0,
								reporter = info.reporter or "?",
								seenAt = info.seenAt or 0,
							}
							matched[#matched + 1] = rec
							if onProgress and previewSize > 0 then
								if InsertBoundedTopK(previewTop, previewSize, rec, cmp) then
									previewDirty = true
								end
							end
						end
					end
				end

				batchCount = batchCount + 1
				if batchCount >= 128 then
					batchCount = 0
					if (NowMs() - startMs) >= budgetMs then
						if onProgress and previewDirty then
							previewDirty = false
							onProgress(previewTop, totalCached, topKOnly > 0 and #previewTop or #matched)
						end
						return
					end
				end
			end
		end

		if phase == "runsort" then
			local total = #matched
			while nextRunStart <= total do
				local runEnd = math.min(total, nextRunStart + CHUNK_RUN_SIZE - 1)
				local run = {}
				local rIdx = 0
				for i = nextRunStart, runEnd do
					rIdx = rIdx + 1
					run[rIdx] = matched[i]
				end
				table.sort(run, cmp)
				runs[#runs + 1] = run
				nextRunStart = runEnd + 1
				if (NowMs() - startMs) >= budgetMs then
					if onProgress then
						onProgress(previewTop, totalCached, total)
					end
					return
				end
			end
			-- Free flat unsorted array reference before merging runs
			matched = nil
			if #runs <= 1 then
				FinishJob(runs[1] or {})
				return
			end
			phase = "merge"
			mergeNextRuns = {}
			mergePairIdx = 1
			mergeA, mergeB, mergeOut = nil, nil, nil
		end

		if phase == "merge" then
			while #runs > 1 do
				if not mergeA then
					if mergePairIdx > #runs then
						runs = mergeNextRuns
						if #runs <= 1 then
							FinishJob(runs[1] or {})
							return
						end
						mergeNextRuns = {}
						mergePairIdx = 1
					end
					local a = runs[mergePairIdx]
					local b = runs[mergePairIdx + 1]
					mergePairIdx = mergePairIdx + 2
					if not b then
						mergeNextRuns[#mergeNextRuns + 1] = a
					else
						mergeA, mergeB = a, b
						mergeOut = {}
						mergeIA, mergeIB = 1, 1
					end
				end

				if mergeA and mergeB then
					local nA, nB = #mergeA, #mergeB
					local outIdx = #mergeOut
					local step = 0
					while mergeIA <= nA and mergeIB <= nB do
						outIdx = outIdx + 1
						if cmp(mergeA[mergeIA], mergeB[mergeIB]) then
							mergeOut[outIdx] = mergeA[mergeIA]
							mergeIA = mergeIA + 1
						else
							mergeOut[outIdx] = mergeB[mergeIB]
							mergeIB = mergeIB + 1
						end
						step = step + 1
						if step >= 256 then
							step = 0
							if (NowMs() - startMs) >= budgetMs then
								return
							end
						end
					end
					while mergeIA <= nA do
						outIdx = outIdx + 1
						mergeOut[outIdx] = mergeA[mergeIA]
						mergeIA = mergeIA + 1
					end
					while mergeIB <= nB do
						outIdx = outIdx + 1
						mergeOut[outIdx] = mergeB[mergeIB]
						mergeIB = mergeIB + 1
					end
					mergeNextRuns[#mergeNextRuns + 1] = mergeOut
					mergeA, mergeB, mergeOut = nil, nil, nil
					if (NowMs() - startMs) >= budgetMs then
						return
					end
				end
			end
			FinishJob(runs[1] or {})
		end
	end

	-- Run first 2.5ms slice immediately (small/medium DBs finish synchronously on frame 1!)
	StepSlice()
	if worker.gen == myGen and phase ~= "done" and (not self._queryCache or not self._queryCache[cacheKey]) then
		worker.frame:SetScript("OnUpdate", StepSlice)
		worker.frame:Show()
	end
	return false
end

function PluribusHiveAuction:ClosePanel()
	self:CancelMarketQuery("ahDrawer")
	self.activeTab = nil
	if _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.HideAllViews then
		_G.PluribusHiveAuctionator:HideAllViews()
	end
	if self.panel then
		self.panel:Hide()
	end
	if self.sideTabs then
		for _, t in pairs(self.sideTabs) do
			if t and t.SetActiveState then
				t:SetActiveState(false)
			end
		end
	end
end

function PluribusHiveAuction:OpenTab(mode)
	if not self.panel then return end
	self.activeTab = mode
	if self.sideTabs then
		for k, tab in pairs(self.sideTabs) do
			if tab and tab.SetActiveState then
				tab:SetActiveState(k == mode)
			end
		end
	end
	local titles = {
		sell   = "|cff38bdf8Verkaufen (Auctionator)|r",
		shop   = "|cff4ade80Einkaufslisten & To-Do|r",
		de     = "|cffa855f7Entzaubern-Schnäppchen|r",
		needs  = "|cff4ade80Gildenbedarf|r",
		prices = "|cff38bdf8Gilden-AH Preise|r",
	}
	if self.panel.headerLbl then
		self.panel.headerLbl:SetText(titles[mode] or "|cff38bdf8Pluribus Market|r")
	end
	self.panel:Show()

	if mode == "sell" or mode == "shop" or mode == "de" then
		self:CancelMarketQuery("ahDrawer")
		if self.panel.searchBox then self.panel.searchBox:Hide() end
		if self.panel._needsVList then self.panel._needsVList:Hide() end
		if self.panel._pricesVList then self.panel._pricesVList:Hide() end
		if self.panel._emptyLbl then self.panel._emptyLbl:Hide() end
		if _G.PluribusHiveAuctionator then
			_G.PluribusHiveAuctionator:AttachToPanel(self.panel)
			_G.PluribusHiveAuctionator:ShowMode(mode)
		end
		self:UpdateStatusBar()
	else
		if _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.HideAllViews then
			_G.PluribusHiveAuctionator:HideAllViews()
		end
		if self.panel.searchBox then self.panel.searchBox:Show() end
		self:RefreshPanel()
	end
end

-- Virtualized row factory for the AH side drawer (only <=9 visible rows ever instantiated!)
local function CreateDrawerVirtualRow(viewport, slotIdx, rowW, rowH)
	local UI = _G.PluribusUIFramework
	local row = UI:CreateListRow(viewport, rowW, rowH, slotIdx, function()
		if row._searchName and row._searchName ~= "" then
			PluribusHiveAuction:SearchNativeAH(row._searchName)
		end
	end)

	local slotSize = (rowH >= 38) and 28 or 26
	local slot = CreateFrame("Button", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
	slot:SetSize(slotSize, slotSize)
	slot:SetPoint("LEFT", row, "LEFT", 4, 0)
	UI:ApplyBackdrop(slot, 0.05, 0.07, 0.11, 0.96, 0.30, 0.38, 0.50, 0.75)

	local icon = slot:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	slot.icon = icon

	slot:SetScript("OnClick", function()
		if row._searchName and row._searchName ~= "" then
			PluribusHiveAuction:SearchNativeAH(row._searchName)
		end
	end)

	local function ShowDrawerTooltip(anchor)
		if not GameTooltip then return end
		local d = row._tooltipData
		if not d then return end
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
		local ok = PluribusUtils and PluribusUtils:SetTooltipItem(GameTooltip, d.itemID, d.link)
		if not ok then GameTooltip:AddLine(d.name or ("Item #" .. tostring(d.itemID or "?")), 1, 1, 1) end
		GameTooltip:AddLine("|cff38bdf8Click to search in Auction House|r", 0.5, 0.8, 1)
		GameTooltip:Show()
	end
	local function HideDrawerTooltip()
		if GameTooltip then GameTooltip:Hide() end
	end

	slot:SetScript("OnEnter", ShowDrawerTooltip)
	slot:SetScript("OnLeave", HideDrawerTooltip)
	row:SetScript("OnEnter", ShowDrawerTooltip)
	row:SetScript("OnLeave", HideDrawerTooltip)

	local topLbl = UI:CreateLabel(row, "")
	if rowH >= 38 then
		topLbl:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, -1)
		local subLbl = UI:CreateLabel(row, "", 0.65, 0.78, 0.90, "GameFontHighlightSmall")
		subLbl:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, 1)
		row._subLbl = subLbl
		local pLbl = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
		pLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
		row._priceLbl = pLbl
	else
		topLbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)
		local pLbl = UI:CreateLabel(row, "", 1, 1, 1, "GameFontHighlightSmall")
		pLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		row._priceLbl = pLbl
	end

	row._slot = slot
	row._topLbl = topLbl
	row:Hide()
	return row
end

local function BindDrawerNeedsRow(row, item)
	local iconTex = (PluribusUtils and PluribusUtils:GetItemIcon(item.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
	row._slot.icon:SetTexture(iconTex)
	local qr, qg, qb = 0.30, 0.38, 0.50
	if ((item.quality or 1) >= 2 or item.quality == 0) and PluribusUtils and PluribusUtils.GetQualityRGB then
		qr, qg, qb = PluribusUtils:GetQualityRGB(item.quality)
	end
	if row._slot.SetBackdropBorderColor then
		row._slot:SetBackdropBorderColor(qr, qg, qb, (item.quality or 1) >= 2 and 0.95 or 0.72)
	end

	local qCol = PluribusUtils:GetQualityColor(item.quality)
	local who = {}
	for idx, nd in ipairs(item.needers or {}) do
		if idx <= 2 then who[#who + 1] = nd.name .. " (" .. nd.prof .. ")" end
	end
	if #(item.needers or {}) > 2 then
		who[#who + 1] = "+" .. (#item.needers - 2)
	end

	row._searchName = item.name
	row._tooltipData = { itemID = item.itemID, name = item.name, link = item.link }
	row._topLbl:SetText(qCol .. tostring(item.name or ""):sub(1, 20) .. "|r")
	if row._subLbl then
		row._subLbl:SetText("Need: " .. table.concat(who, ", "):sub(1, 28))
	end
	local priceStr = item.price and ("|cfffbbf24" .. PluribusUtils:FormatGold(item.price) .. "|r") or "|cff94a3b8Scan|r"
	row._priceLbl:SetText(priceStr)
end

local function BindDrawerPriceRow(row, p, _, _, isFastScroll)
	local liveName, liveLink, liveQuality, liveIcon = nil, nil, nil, nil
	if not isFastScroll then
		liveName, liveLink, liveQuality, _, _, _, _, _, _, liveIcon = PluribusUtils:GetItemInfo(p.itemID)
	end
	local dName = liveName or p.name or (p.info and p.info.name) or ("Item #" .. tostring(p.itemID))
	local quality = liveQuality or p.quality or (p.info and p.info.quality) or 1
	if p.info then
		if liveName and liveName ~= "" and not p.info.name then p.info.name = liveName end
		if liveQuality ~= nil and p.info.quality == nil then p.info.quality = liveQuality end
	end

	local iconTex = liveIcon
		or (not isFastScroll and PluribusUtils and PluribusUtils:GetItemIcon(p.itemID))
		or (p.info and p.info._cachedIcon)
		or "Interface\\Icons\\INV_Misc_QuestionMark"
	if liveIcon and p.info then p.info._cachedIcon = liveIcon end
	row._slot.icon:SetTexture(iconTex)

	local qr, qg, qb = 0.30, 0.38, 0.50
	if (quality >= 2 or quality == 0) and PluribusUtils and PluribusUtils.GetQualityRGB then
		qr, qg, qb = PluribusUtils:GetQualityRGB(quality)
	end
	if row._slot.SetBackdropBorderColor then
		row._slot:SetBackdropBorderColor(qr, qg, qb, quality >= 2 and 0.95 or 0.72)
	end

	local qCol = PluribusUtils:GetQualityColor(quality)
	row._searchName = dName
	row._tooltipData = { itemID = p.itemID, name = dName, link = liveLink }
	row._topLbl:SetText(qCol .. dName:sub(1, 20) .. "|r")
	row._priceLbl:SetText("|cfffbbf24" .. PluribusUtils:FormatGold(p.copper) .. "|r")
end

function PluribusHiveAuction:RefreshPanel()
	if not self.panel or not self.panel._needsVList or not self.panel._pricesVList then return end
	local panel = self.panel
	self:UpdateStatusBar()

	local query = panel.searchBox and (panel.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""

	if self.activeTab == "needs" then
		self:CancelMarketQuery("ahDrawer")
		panel._pricesVList:Hide()
		panel._needsVList:Show()

		local allNeeds = self:GetAllGuildNeededItems()
		self._needsBadgeCount = #allNeeds
		self._needsBadgeAt = GetTime and GetTime() or 0
		if self.sideTabs and self.sideTabs.needs then
			self.sideTabs.needs:SetBadge(#allNeeds, 0.12, 0.62, 0.36)
		end

		local filtered = {}
		for _, item in ipairs(allNeeds) do
			if query == "" or item.name:lower():find(query, 1, true) then
				filtered[#filtered + 1] = item
			end
		end
		panel._needsVList:SetData(filtered, false)
		if #filtered == 0 then
			panel._emptyLbl:SetText("No guild profession material needs recorded yet.\nGuildmates share automatically when online!")
			panel._emptyLbl:Show()
		else
			panel._emptyLbl:Hide()
		end
	else
		panel._needsVList:Hide()
		panel._pricesVList:Show()

		local function PaintDrawerPrices(priceList)
			if not panel or not panel:IsVisible() or self.activeTab ~= "prices" then return end
			local list = priceList or {}
			panel._pricesVList:SetData(list, false)
			if #list == 0 then
				panel._emptyLbl:SetText("Full AH scan runs automatically on open (20m CD).\nYou can also click 'Full Scan' above.")
				panel._emptyLbl:Show()
			else
				panel._emptyLbl:Hide()
			end
		end

		self:QueryMarketPricesAsync({
			owner = "ahDrawer",
			query = query,
			sortMode = "recent",
			topKOnly = 30,
			budgetMs = 2.5,
			onProgress = function(previewItems)
				PaintDrawerPrices(previewItems)
			end,
			onComplete = function(topItems)
				PaintDrawerPrices(topItems)
			end,
		})
	end
end

-- Attach Adventure-Guide-style right-edge side tabs + docked Pluribus Market drawer to WoW's Auction House
-- IMPORTANT: Drawer starts CLOSED and tabs are strictly mutually exclusive so nothing overlaps on open!
function PluribusHiveAuction:AttachToAuctionHouse()
	local host = _G.AuctionHouseFrame or _G.AuctionFrame
	if not host or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	if host._plbAuctionAttached and self.panel then
		if self.sideTabs then
			_G.PluribusUIFramework:LayoutSideTabs(host, {
				self.sideTabs.sell,
				self.sideTabs.shop,
				self.sideTabs.de,
				self.sideTabs.needs,
				self.sideTabs.prices,
			}, {
				preferredY = -48,
				minYOffset = -48,
				spacing = 42,
				drawer = self.panel,
				drawerGap = 48,
				drawerYOffset = -14,
			})
		end
		self:UpdateStatusBar()
		return
	end

	local UI = _G.PluribusUIFramework
	host._plbAuctionAttached = true
	self.attachedFrame = host

	-- Sleek docked side drawer (closed by default, opens only when a side tab is clicked)
	local panel = CreateFrame("Frame", "PluribusHiveAuctionPanel", host, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetSize(404, 452)
	panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 48, -14)
	panel:SetFrameStrata(host:GetFrameStrata() or "HIGH")
	panel:SetFrameLevel((host:GetFrameLevel() or 5) + 10)
	panel._plbDrawer = true
	UI:ApplyBackdrop(panel, 0.06, 0.08, 0.12, 0.97, 0.22, 0.30, 0.42, 0.95)

	local headerLbl = UI:CreateLabel(panel, "|cff38bdf8Pluribus Market|r", 1, 1, 1, "GameFontNormal")
	headerLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	panel.headerLbl = headerLbl

	local closeBtn = UI:CreateButton(panel, "X", 22, 20, function()
		PluribusHiveAuction:ClosePanel()
	end)
	closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)

	local fullScanBtn = UI:CreateButton(panel, "Full Scan", 68, 20, function()
		PluribusHiveAuction:StartFullScan(true)
	end, true)
	fullScanBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)

	local deQuickBtn = UI:CreateButton(panel, "Entzaubern", 78, 20, function()
		PluribusHiveAuction:OpenTab("de")
		if _G.PluribusHiveAuctionator then
			_G.PluribusHiveAuctionator:ScanCachedDisenchantDeals()
			_G.PluribusHiveAuctionator:RefreshActiveView()
		end
	end)
	deQuickBtn:SetPoint("RIGHT", fullScanBtn, "LEFT", -5, 0)

	local scanStatusLbl = UI:CreateLabel(panel, "", 0.65, 0.78, 0.90, "GameFontHighlightSmall")
	scanStatusLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)
	panel.scanStatusLbl = scanStatusLbl

	local searchDebounce = CreateFrame("Frame", nil, panel)
	searchDebounce:Hide()
	local ahDebounceRem = 0
	searchDebounce:SetScript("OnUpdate", function(sf, elapsed)
		ahDebounceRem = ahDebounceRem - (elapsed or 0)
		if ahDebounceRem <= 0 then
			sf:Hide()
			if panel:IsVisible() and (PluribusHiveAuction.activeTab == "needs" or PluribusHiveAuction.activeTab == "prices") then
				PluribusHiveAuction:RefreshPanel()
			end
		end
	end)

	local searchBox = UI:CreateInputBox(panel, 380, 24, function()
		ahDebounceRem = 0.20
		searchDebounce:Show()
	end)
	searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -52)
	panel.searchBox = searchBox

	local needsVList = UI:CreateVirtualScrollList(panel, {
		width = 380,
		height = 358,
		rowHeight = 38,
		rowGap = 2,
		wheelStep = 2,
		shiftWheelStep = 8,
		createRow = CreateDrawerVirtualRow,
		bindRow = BindDrawerNeedsRow,
	})
	needsVList:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -82)
	needsVList:Hide()
	panel._needsVList = needsVList

	local pricesVList = UI:CreateVirtualScrollList(panel, {
		width = 380,
		height = 358,
		rowHeight = 34,
		rowGap = 2,
		wheelStep = 3,
		shiftWheelStep = 9,
		createRow = CreateDrawerVirtualRow,
		bindRow = BindDrawerPriceRow,
	})
	pricesVList:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -82)
	pricesVList:Hide()
	panel._pricesVList = pricesVList

	local emptyLbl = UI:CreateLabel(panel, "", 0.65, 0.72, 0.82)
	emptyLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -94)
	emptyLbl:Hide()
	panel._emptyLbl = emptyLbl
	panel.listContent = pricesVList

	-- Direct 1-click Disenchant button right on the AH window top-right bar
	local ahDeBtn = UI:CreateButton(host, "Entzaubern (DE)", 114, 22, function()
		PluribusHiveAuction:OpenTab("de")
		if _G.PluribusHiveAuctionator then
			_G.PluribusHiveAuctionator:StartLiveDisenchantScan()
		end
	end, true)
	ahDeBtn:SetPoint("TOPRIGHT", host, "TOPRIGHT", -34, -14)
	ahDeBtn:SetFrameLevel((host:GetFrameLevel() or 5) + 12)
	self.ahDisenchantBtn = ahDeBtn

	-- Mutually exclusive right-edge side bookmark tabs on the Auction House window
	local function ToggleSide(mode)
		if panel:IsVisible() and PluribusHiveAuction.activeTab == mode then
			PluribusHiveAuction:ClosePanel()
		else
			PluribusHiveAuction:OpenTab(mode)
		end
	end

	local sSell = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Misc_Coin_01",
		title = "Verkaufen (Auctionator)",
		tooltip = "Taschen-Items schnell verkaufen, Konkurrenz unterbieten & eigene Auktionen prüfen.",
		yOffset = -48,
		onClick = function() ToggleSide("sell") end,
	})
	local sShop = UI:CreateSideTab(host, 2, {
		icon = "Interface\\Icons\\INV_Scroll_03",
		title = "Einkaufslisten & To-Do",
		tooltip = "Einkaufslisten, erweiterte Filter & Live-Sync mit deiner Pluribus To-Do Liste.",
		yOffset = -90,
		onClick = function() ToggleSide("shop") end,
	})
	local sDE = UI:CreateSideTab(host, 3, {
		icon = "Interface\\Icons\\INV_Enchant_Disenchant",
		title = "Entzaubern-Schnäppchen",
		tooltip = "Findet AH-Items, deren Kaufpreis unter ihrem mittleren Entzauberungswert liegt.",
		yOffset = -132,
		onClick = function() ToggleSide("de") end,
	})
	local sNeeds = UI:CreateSideTab(host, 4, {
		icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
		title = "Gildenbedarf",
		tooltip = "Materialien, die Gildenmitglieder für Berufe benötigen — Klick sucht im AH.",
		yOffset = -174,
		onClick = function() ToggleSide("needs") end,
	})
	local sPrices = UI:CreateSideTab(host, 5, {
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		title = "Gilden-AH Preise",
		tooltip = "Gilden-synchronisierte Marktpreise (Auto-Full-Scan alle 20m).",
		yOffset = -216,
		onClick = function() ToggleSide("prices") end,
	})
	self.sideTabs = { sell = sSell, shop = sShop, de = sDE, needs = sNeeds, prices = sPrices }
	self.panel = panel

	if _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.AttachToPanel then
		_G.PluribusHiveAuctionator:AttachToPanel(panel)
	end

	UI:LayoutSideTabs(host, { sSell, sShop, sDE, sNeeds, sPrices }, {
		preferredY = -48,
		minYOffset = -48,
		spacing = 42,
		drawer = panel,
		drawerGap = 48,
		drawerYOffset = -14,
	})

	-- Always start CLOSED when opening the AH so tabs never overlap or clutter the window
	self:ClosePanel()
	self:UpdateStatusBar()

	-- Update guild needs badge immediately without opening the drawer
	local needCount = #(self:GetAllGuildNeededItems() or {})
	if sNeeds then sNeeds:SetBadge(needCount, 0.12, 0.62, 0.36) end
end

function PluribusHiveAuction:Initialize()
	if self.initialized then return end
	self.initialized = true
	if _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.Initialize then
		_G.PluribusHiveAuctionator:Initialize()
	end

	PluribusHive:RegisterHandler("AH", function(sender, body)
		local idStr, copperStr = body:match("^(%d+)|(%d+)")
		local id, copper = tonumber(idStr), tonumber(copperStr)
		if id and copper and copper > 0 then
			PluribusHiveAuction:RecordPrice(id, copper, sender, false)
		end
	end)

	PluribusHive:RegisterHandler("AHBATCH", function(sender, body)
		local _, listStr = tostring(body or ""):match("^(%d+)|(.*)$")
		if not listStr then return end
		for idStr, priceStr in listStr:gmatch("(%d+):(%d+)") do
			local id, price = tonumber(idStr), tonumber(priceStr)
			if id and price and price > 0 then
				PluribusHiveAuction:RecordPrice(id, price, sender, false)
			end
		end
	end)

	-- Register passive Auctionator DB listener if Auctionator is installed
	if _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1 and _G.Auctionator.API.v1.RegisterForDBUpdate then
		pcall(_G.Auctionator.API.v1.RegisterForDBUpdate, "PluribusCore", function()
			if PluribusHiveAuction.panel and PluribusHiveAuction.panel:IsVisible() then
				PluribusHiveAuction:RefreshPanel()
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"AUCTION_HOUSE_SHOW",
		"AUCTION_HOUSE_CLOSED",
		"AUCTION_ITEM_LIST_UPDATE",
		"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"COMMODITY_SEARCH_RESULTS_UPDATED",
		"ITEM_SEARCH_RESULTS_UPDATED",
		"REPLICATE_ITEM_LIST_UPDATE",
		"ADDON_LOADED",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "AUCTION_HOUSE_SHOW" then
			PluribusHiveAuction.ahOpen = true
			PluribusHiveAuction:AttachToAuctionHouse()
			PluribusHiveAuction:ClosePanel()
			if PluribusHiveAuction:CanAutoFullScan() then
				if C_Timer and C_Timer.After then
					C_Timer.After(0.8, function()
						if PluribusHiveAuction.ahOpen and PluribusHiveAuction:CanAutoFullScan() then
							PluribusHiveAuction:StartFullScan(false)
						end
					end)
				else
					PluribusHiveAuction:StartFullScan(false)
				end
			else
				PluribusHiveAuction:UpdateStatusBar()
			end
		elseif event == "AUCTION_HOUSE_CLOSED" then
			PluribusHiveAuction.ahOpen = false
			PluribusHiveAuction:ClosePanel()
			if PluribusHiveAuction.fullScanActive then
				PluribusHiveAuction:FinishFullScan(true)
			end
		elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
			if PluribusHiveAuction.fullScanActive and PluribusHiveAuction.fullScanMode == "replicate" then
				PluribusHiveAuction:ProcessReplicateDump()
			end
		elseif event == "AUCTION_ITEM_LIST_UPDATE" then
			if PluribusHiveAuction.fullScanActive and PluribusHiveAuction.fullScanMode == "getall" then
				local ok, numBatch = pcall(GetNumAuctionItems, "list")
				if ok and numBatch and numBatch > 0 then
					PluribusHiveAuction:ProcessGetAllBatch(numBatch)
				else
					PluribusHiveAuction:FinishFullScan(false)
				end
			elseif PluribusHiveAuction.fullScanActive and PluribusHiveAuction.fullScanMode == "paged" then
				PluribusHiveAuction:ProcessPagedScanUpdate()
			elseif PluribusHive:GetConfig().autoScanAH ~= false then
				PluribusHiveAuction:ScanVisibleListings()
			end
		elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
			if PluribusHive:GetConfig().autoScanAH ~= false then
				PluribusHiveAuction:ScanVisibleListings()
			end
		elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" and tonumber(arg1) then
			if C_AuctionHouse and C_AuctionHouse.GetCommoditySearchResultInfo then
				local ok, res = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, tonumber(arg1), 1)
				if ok and res and res.unitPrice and res.unitPrice > 0 then
					PluribusHiveAuction:RecordPrice(tonumber(arg1), res.unitPrice, PluribusHive:GetPlayerShortName(), true)
				end
			end
		elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and type(arg1) == "table" and arg1.itemID then
			if C_AuctionHouse and C_AuctionHouse.GetItemSearchResultInfo then
				local ok, res = pcall(C_AuctionHouse.GetItemSearchResultInfo, arg1, 1)
				local p = ok and res and (res.buyoutAmount or res.bidAmount) or 0
				if p and p > 0 then
					PluribusHiveAuction:RecordPrice(arg1.itemID, p, PluribusHive:GetPlayerShortName(), true)
				end
			end
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_AuctionUI" or arg1 == "Blizzard_AuctionHouseUI") then
			PluribusHiveAuction:AttachToAuctionHouse()
		end
	end)
end

return PluribusHiveAuction
