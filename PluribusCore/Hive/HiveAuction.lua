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
	fullScanMode = nil, -- "getall" | "paged" | "replicate"
	fullScanPage = 0,
	fullScanTotalPages = 0,
	fullScanSeen = {},
	fullScanProcessed = 0,
	fullScanStatusText = "",
}
_G.PluribusHiveAuction = PluribusHiveAuction

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

function PluribusHiveAuction:RecordPrice(itemID, unitCopper, reporter, broadcast)
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

	db.prices[itemID] = {
		itemID = itemID,
		copper = avg,
		minCopper = (existing and existing.minCopper and (now - (existing.seenAt or 0)) < 3600)
			and math.min(existing.minCopper, unitCopper) or unitCopper,
		reporter = reporter or PluribusHive:GetPlayerShortName(),
		seenAt = now,
	}

	if broadcast and PluribusHive:GetConfig().shareAuctionPrices then
		PluribusHive:Send("AH", string.format("%d|%d|%d", itemID, avg, now), "GUILD")
	end
end

-- Auto-detect 1.12 vs 1.14+/Classic/Warcraft Forever GetAuctionItemInfo return signature
-- 1.14+: name, tex, count, qual, canUse, lvl, levelColHeader(string), minBid, minInc, buyoutPrice, bidAmt, ..., itemId(#17)
-- 1.12 : name, tex, count, qual, canUse, lvl, minBid(number),         minInc, buyoutPrice, bidAmt
local function ParseClassicAuctionRow(listType, index)
	if not GetAuctionItemInfo then return nil, nil end
	local _, _, count, _, _, _, a7, a8, a9, a10, a11, _, _, _, _, _, a17 = GetAuctionItemInfo(listType, index)
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
	if not itemID or effectivePrice <= 0 then return nil, nil end
	local stack = (tonumber(count) and tonumber(count) > 0) and tonumber(count) or 1
	return itemID, math.max(1, math.floor(effectivePrice / stack))
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

-- Commit all prices gathered during a full AH scan and politely share priority prices with the guild
function PluribusHiveAuction:FinishFullScan(aborted)
	if not self.fullScanActive then return end
	local seen = self.fullScanSeen or {}
	local me = PluribusHive:GetPlayerShortName()
	local updatedCount = 0

	-- Gather guild-needed item IDs so we prioritize sharing prices guildmates care about most
	local guildNeeds = {}
	for _, n in ipairs(self:GetAllGuildNeededItems() or {}) do
		guildNeeds[n.itemID] = true
	end

	local toBroadcast = {}
	for itemID, unitPrice in pairs(seen) do
		self:RecordPrice(itemID, unitPrice, me, false)
		updatedCount = updatedCount + 1
		if guildNeeds[itemID] then
			table.insert(toBroadcast, 1, { id = itemID, price = unitPrice })
		else
			table.insert(toBroadcast, { id = itemID, price = unitPrice })
		end
	end

	-- Record 20-minute cooldown timestamp whenever a full scan completes (or captured substantial data)
	if not aborted or updatedCount >= 25 then
		local db = PluribusHive:GetDB()
		db.lastFullAHScanAt = time()
	end

	-- Politely broadcast up to 40 priority prices over PLBHIVE so guildmates get fresh prices without flooding comms
	if PluribusHive:GetConfig().shareAuctionPrices and #toBroadcast > 0 then
		local now = time()
		local limit = math.min(#toBroadcast, 40)
		for i = 1, limit do
			local rec = toBroadcast[i]
			PluribusHive:Send("AH", string.format("%d|%d|%d", rec.id, rec.price, now), "GUILD")
		end
	end

	self.fullScanActive = false
	self.fullScanMode = nil
	self.fullScanSeen = {}
	self.fullScanStatusText = ""
	self:UpdateStatusBar()

	if _G.PluribusUtils then
		if aborted then
			_G.PluribusUtils:Info("Full AH scan paused (" .. tostring(updatedCount) .. " item prices saved).", "HiveMarket")
		else
			_G.PluribusUtils:Info("Full AH scan complete: " .. tostring(updatedCount) .. " unique item prices updated (next auto-scan in 20m).", "HiveMarket")
		end
	end

	if self.panel and self.panel:IsVisible() then
		self:RefreshPanel()
	end
end

-- Chunk-process a Classic getAll AH dump without freezing client FPS
function PluribusHiveAuction:ProcessGetAllBatch(totalCount)
	local idx = 1
	local chunkSize = 400
	local function step()
		if not PluribusHiveAuction.fullScanActive or PluribusHiveAuction.fullScanMode ~= "getall" then
			return
		end
		local stopAt = math.min(totalCount, idx + chunkSize - 1)
		for i = idx, stopAt do
			local itemID, unitPrice = ParseClassicAuctionRow("list", i)
			if itemID and unitPrice and unitPrice > 0 then
				if not PluribusHiveAuction.fullScanSeen[itemID] or unitPrice < PluribusHiveAuction.fullScanSeen[itemID] then
					PluribusHiveAuction.fullScanSeen[itemID] = unitPrice
				end
			end
		end
		idx = stopAt + 1
		PluribusHiveAuction.fullScanProcessed = stopAt
		PluribusHiveAuction.fullScanStatusText = string.format("Scanning AH: %d / %d...", stopAt, totalCount)
		PluribusHiveAuction:UpdateStatusBar()

		if idx <= totalCount then
			if C_Timer and C_Timer.After then
				C_Timer.After(0.02, step)
			else
				step()
			end
		else
			PluribusHiveAuction:FinishFullScan(false)
		end
	end
	step()
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

	for i = 1, numBatch do
		local itemID, unitPrice = ParseClassicAuctionRow("list", i)
		if itemID and unitPrice and unitPrice > 0 then
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

-- Chunk-process modern C_AuctionHouse.ReplicateItems() dump
function PluribusHiveAuction:ProcessReplicateDump()
	if not self.fullScanActive or self.fullScanMode ~= "replicate" then return end
	if not (C_AuctionHouse and C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetReplicateItemInfo) then
		self:FinishFullScan(true)
		return
	end
	local total = C_AuctionHouse.GetNumReplicateItems() or 0
	if total <= 0 then
		self:FinishFullScan(false)
		return
	end

	local idx = 0
	local chunkSize = 500
	local function step()
		if not PluribusHiveAuction.fullScanActive or PluribusHiveAuction.fullScanMode ~= "replicate" then return end
		local stopAt = math.min(total - 1, idx + chunkSize - 1)
		for i = idx, stopAt do
			local _, _, count, _, _, _, _, minBid, _, buyoutPrice, bidAmount, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
			local eff = (buyoutPrice and buyoutPrice > 0 and buyoutPrice)
				or (bidAmount and bidAmount > 0 and bidAmount)
				or (minBid and minBid > 0 and minBid)
				or 0
			if itemID and eff > 0 then
				local stack = (count and count > 0) and count or 1
				local unitPrice = math.max(1, math.floor(eff / stack))
				if not PluribusHiveAuction.fullScanSeen[itemID] or unitPrice < PluribusHiveAuction.fullScanSeen[itemID] then
					PluribusHiveAuction.fullScanSeen[itemID] = unitPrice
				end
			end
		end
		idx = stopAt + 1
		PluribusHiveAuction.fullScanStatusText = string.format("Scanning AH: %d / %d...", idx, total)
		PluribusHiveAuction:UpdateStatusBar()
		if idx < total then
			if C_Timer and C_Timer.After then
				C_Timer.After(0.02, step)
			else
				step()
			end
		else
			PluribusHiveAuction:FinishFullScan(false)
		end
	end
	step()
end

-- Start a full AH scan (automatically called on AH open when 20-minute cooldown is ready, or manually via button)
function PluribusHiveAuction:StartFullScan(isManual)
	if not self.ahOpen then return false end
	if self.fullScanActive then return false end

	local rem = self:GetFullScanCooldownRemaining()
	if rem > 0 then
		if isManual and _G.PluribusUtils then
			_G.PluribusUtils:Info("Full AH scan is on cooldown (" .. self:FormatCooldownText(rem) .. " remaining).", "HiveMarket")
		end
		self:UpdateStatusBar()
		return false
	end

	self.fullScanSeen = {}
	self.fullScanProcessed = 0
	self.fullScanPage = 0
	self.fullScanTotalPages = 0

	-- Modern C_AuctionHouse full replication
	if C_AuctionHouse and C_AuctionHouse.ReplicateItems then
		self.fullScanActive = true
		self.fullScanMode = "replicate"
		self.fullScanStatusText = "Requesting full AH snapshot..."
		self:UpdateStatusBar()
		if _G.PluribusUtils then
			_G.PluribusUtils:Info("Starting full Auction House scan (20-min cooldown)...", "HiveMarket")
		end
		local ok = pcall(C_AuctionHouse.ReplicateItems)
		if not ok then
			self.fullScanActive = false
			self.fullScanMode = nil
			return false
		end
		return true
	end

	-- Classic / Warcraft Forever AuctionFrame full scan (prefers GetAll fast dump, falls back to paged full scan)
	if CanSendAuctionQuery and QueryAuctionItems then
		local ok, canQuery, canQueryAll = pcall(CanSendAuctionQuery)
		if ok and canQueryAll then
			self.fullScanActive = true
			self.fullScanMode = "getall"
			self.fullScanStatusText = "Requesting full AH dump..."
			self:UpdateStatusBar()
			if _G.PluribusUtils then
				_G.PluribusUtils:Info("Starting full Auction House scan (20-min cooldown)...", "HiveMarket")
			end
			pcall(QueryAuctionItems, "", nil, nil, 0, 0, 0, false, false, true)
			return true
		elseif ok and canQuery then
			self.fullScanActive = true
			self.fullScanMode = "paged"
			self.fullScanPage = 0
			self.fullScanStatusText = "Scanning AH page 1..."
			self:UpdateStatusBar()
			if _G.PluribusUtils then
				_G.PluribusUtils:Info("Starting full Auction House scan (paged, 20-min cooldown)...", "HiveMarket")
			end
			self:QueryNextPagedScan()
			return true
		elseif not isManual and C_Timer and C_Timer.After then
			-- AH query throttle still settling right after opening; retry once briefly
			C_Timer.After(1.2, function()
				if PluribusHiveAuction.ahOpen and not PluribusHiveAuction.fullScanActive and PluribusHiveAuction:CanAutoFullScan() then
					PluribusHiveAuction:StartFullScan(false)
				end
			end)
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
	local scanned = 0

	if GetNumAuctionItems and GetAuctionItemInfo then
		local ok, numBatch = pcall(GetNumAuctionItems, "list")
		if ok and numBatch and numBatch > 0 then
			local limit = math.min(numBatch, 100)
			for i = 1, limit do
				local itemID, unitPrice = ParseClassicAuctionRow("list", i)
				if itemID and unitPrice and unitPrice > 0 then
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
		self:RecordPrice(itemID, unitPrice, me, true)
		recorded = recorded + 1
	end

	if recorded > 0 and self.panel and self.panel:IsVisible() then
		self:RefreshPanel()
	end
	return recorded
end

-- Helper to pre-fill and trigger a native Auction House search by item name
function PluribusHiveAuction:SearchNativeAH(itemName)
	if not itemName or itemName == "" then return end
	if _G.BrowseName and _G.BrowseName.SetText then
		_G.BrowseName:SetText(itemName)
		if _G.AuctionFrameBrowse_Search then
			pcall(_G.AuctionFrameBrowse_Search)
		end
	elseif _G.AuctionHouseFrame and _G.AuctionHouseFrame.SearchBar and _G.AuctionHouseFrame.SearchBar.SearchBox then
		_G.AuctionHouseFrame.SearchBar.SearchBox:SetText(itemName)
		if _G.AuctionHouseFrame.SearchBar.StartSearch then
			pcall(function() _G.AuctionHouseFrame.SearchBar:StartSearch() end)
		end
	end
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

function PluribusHiveAuction:ClosePanel()
	self.activeTab = nil
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
		if self.sideTabs.needs then self.sideTabs.needs:SetActiveState(mode == "needs") end
		if self.sideTabs.prices then self.sideTabs.prices:SetActiveState(mode == "prices") end
	end
	if self.panel.headerLbl then
		self.panel.headerLbl:SetText(mode == "needs" and "|cff4ade80Guild Material Needs|r" or "|cff38bdf8Guild AH Prices|r")
	end
	self.panel:Show()
	self:RefreshPanel()
end

function PluribusHiveAuction:RefreshPanel()
	if not self.panel or not self.panel.listContent then return end
	local UI = _G.PluribusUIFramework
	local container = self.panel.listContent
	UI:ClearContainer(container)
	self:UpdateStatusBar()

	local allNeeds = self:GetAllGuildNeededItems()
	if self.sideTabs and self.sideTabs.needs then
		self.sideTabs.needs:SetBadge(#allNeeds, 0.12, 0.62, 0.36)
	end

	local query = self.panel.searchBox and (self.panel.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""

	if self.activeTab == "needs" then
		local y = -4
		local shown = 0
		for _, item in ipairs(allNeeds) do
			if query == "" or item.name:lower():find(query, 1, true) then
				shown = shown + 1
				local row = UI:CreateListRow(container, 274, 38, shown, function()
					PluribusHiveAuction:SearchNativeAH(item.name)
				end)
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

				local slot = UI:CreateItemSlot(row, 28, {
					itemID = item.itemID,
					name = item.name,
					link = item.link,
					quality = item.quality,
					extraTooltip = "Click row to search in Auction House",
				}, function()
					PluribusHiveAuction:SearchNativeAH(item.name)
				end)
				slot:SetPoint("LEFT", row, "LEFT", 4, 0)

				local qCol = PluribusUtils:GetQualityColor(item.quality)
				local who = {}
				for idx, nd in ipairs(item.needers) do
					if idx <= 2 then table.insert(who, nd.name .. " (" .. nd.prof .. ")") end
				end
				if #item.needers > 2 then
					table.insert(who, "+" .. (#item.needers - 2))
				end

				local topLbl = UI:CreateLabel(row, qCol .. item.name:sub(1, 20) .. "|r")
				topLbl:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, -1)

				local subLbl = UI:CreateLabel(row, "Need: " .. table.concat(who, ", "):sub(1, 28), 0.65, 0.78, 0.90, "GameFontHighlightSmall")
				subLbl:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 6, 1)

				local priceStr = item.price and ("|cfffbbf24" .. PluribusUtils:FormatGold(item.price) .. "|r") or "|cff94a3b8Scan|r"
				local pLbl = UI:CreateLabel(row, priceStr, 1, 1, 1, "GameFontHighlightSmall")
				pLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)

				row:SetScript("OnEnter", function(selfRow)
					if GameTooltip then
						GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
						local ok = PluribusUtils:SetTooltipItem(GameTooltip, item.itemID, item.link)
						if not ok then GameTooltip:AddLine(item.name, 1, 1, 1) end
						GameTooltip:AddLine("|cff38bdf8Click to search in Auction House|r", 0.5, 0.8, 1)
						GameTooltip:Show()
					end
				end)
				row:SetScript("OnLeave", function()
					if GameTooltip then GameTooltip:Hide() end
				end)

				y = y - 40
				if shown >= 40 then break end
			end
		end
		if shown == 0 then
			local empty = UI:CreateLabel(container, "No guild profession material needs recorded yet.\nGuildmates share automatically when online!", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -12)
		end
		container:SetHeight(math.max(260, math.abs(y) + 12))
	else
		local db = PluribusHive:GetDB()
		local prices = {}
		for itemID, info in pairs(db.prices or {}) do
			local name, link, quality = PluribusUtils:GetItemInfo(itemID)
			local dName = name or ("Item #" .. itemID)
			if query == "" or dName:lower():find(query, 1, true) then
				table.insert(prices, {
					itemID = itemID,
					name = dName,
					link = link,
					quality = quality or 1,
					copper = info.copper or 0,
					reporter = info.reporter or "?",
					seenAt = info.seenAt or 0,
				})
			end
		end
		table.sort(prices, function(a, b) return (a.seenAt or 0) > (b.seenAt or 0) end)

		local y = -4
		local shown = 0
		for _, p in ipairs(prices) do
			shown = shown + 1
			local row = UI:CreateListRow(container, 274, 34, shown, function()
				PluribusHiveAuction:SearchNativeAH(p.name)
			end)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local slot = UI:CreateItemSlot(row, 26, {
				itemID = p.itemID,
				name = p.name,
				link = p.link,
				quality = p.quality,
				extraTooltip = "Click to search in Auction House",
			}, function()
				PluribusHiveAuction:SearchNativeAH(p.name)
			end)
			slot:SetPoint("LEFT", row, "LEFT", 4, 0)

			local qCol = PluribusUtils:GetQualityColor(p.quality)
			local nameLbl = UI:CreateLabel(row, qCol .. p.name:sub(1, 20) .. "|r")
			nameLbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)

			local pLbl = UI:CreateLabel(row, "|cfffbbf24" .. PluribusUtils:FormatGold(p.copper) .. "|r", 1, 1, 1, "GameFontHighlightSmall")
			pLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)

			row:SetScript("OnEnter", function(selfRow)
				if GameTooltip then
					GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
					local ok = PluribusUtils:SetTooltipItem(GameTooltip, p.itemID, p.link)
					if not ok then GameTooltip:AddLine(p.name, 1, 1, 1) end
					GameTooltip:AddLine("|cff38bdf8Click to search in Auction House|r", 0.5, 0.8, 1)
					GameTooltip:Show()
				end
			end)
			row:SetScript("OnLeave", function()
				if GameTooltip then GameTooltip:Hide() end
			end)

			y = y - 36
			if shown >= 60 then break end
		end
		if shown == 0 then
			local empty = UI:CreateLabel(container, "Full AH scan runs automatically on open (20m CD).\nYou can also click 'Full Scan' above.", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -12)
		end
		container:SetHeight(math.max(260, math.abs(y) + 12))
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
			_G.PluribusUIFramework:LayoutSideTabs(host, { self.sideTabs.needs, self.sideTabs.prices }, {
				preferredY = -56,
				minYOffset = -56,
				spacing = 44,
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
	panel:SetSize(310, 424)
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

	local fullScanBtn = UI:CreateButton(panel, "Full Scan", 74, 20, function()
		PluribusHiveAuction:StartFullScan(true)
	end, true)
	fullScanBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

	local scanStatusLbl = UI:CreateLabel(panel, "", 0.65, 0.78, 0.90, "GameFontHighlightSmall")
	scanStatusLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)
	panel.scanStatusLbl = scanStatusLbl

	local searchBox = UI:CreateInputBox(panel, 286, 24, function()
		PluribusHiveAuction:RefreshPanel()
	end)
	searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -52)
	panel.searchBox = searchBox

	local scroll = UI:CreateScrollFrame(panel, "PluribusHiveAuctionScroll", 286, 332)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -82)
	panel.listContent = scroll.content

	-- Mutually exclusive right-edge side bookmark tabs on the Auction House window
	local function ToggleSide(mode)
		if panel:IsVisible() and PluribusHiveAuction.activeTab == mode then
			PluribusHiveAuction:ClosePanel()
		else
			PluribusHiveAuction:OpenTab(mode)
		end
	end

	local sNeeds = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
		title = "Guild Material Needs",
		tooltip = "Items guildmates need for professions — click any item to search the AH.",
		yOffset = -56,
		onClick = function() ToggleSide("needs") end,
	})
	local sPrices = UI:CreateSideTab(host, 2, {
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		title = "Guild AH Prices",
		tooltip = "Guild-synced buyout prices (auto full-scans AH with a 20m cooldown).",
		yOffset = -100,
		onClick = function() ToggleSide("prices") end,
	})
	self.sideTabs = { needs = sNeeds, prices = sPrices }
	self.panel = panel

	UI:LayoutSideTabs(host, { sNeeds, sPrices }, {
		preferredY = -56,
		minYOffset = -56,
		spacing = 44,
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

	PluribusHive:RegisterHandler("AH", function(sender, body)
		local idStr, copperStr = body:match("^(%d+)|(%d+)")
		local id, copper = tonumber(idStr), tonumber(copperStr)
		if id and copper and copper > 0 then
			PluribusHiveAuction:RecordPrice(id, copper, sender, false)
		end
	end)

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
