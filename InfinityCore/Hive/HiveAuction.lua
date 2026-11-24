-- InfinityHive Auction House Integration & Guild Price Network
-- Embeds a sleek "Infinity Market" panel directly inside WoW's native Auction House window
-- Shares scanned buyout prices across the guild and highlights materials guildmates need

InfinityHiveAuction = {
	initialized = false,
	attachedFrame = nil,
	panel = nil,
	toggleBtn = nil,
	lastScanTime = 0,
	activeTab = "needs",
}
_G.InfinityHiveAuction = InfinityHiveAuction

function InfinityHiveAuction:RecordPrice(itemID, unitCopper, reporter, broadcast)
	itemID = tonumber(itemID)
	unitCopper = tonumber(unitCopper)
	if not itemID or not unitCopper or unitCopper <= 0 then return end

	local db = InfinityHive:GetDB()
	local existing = db.prices[itemID]
	local now = time()

	-- Blend smoothly if recent, otherwise take fresh scan
	local avg = unitCopper
	if existing and existing.copper and (now - (existing.seenAt or 0)) < 21600 then
		avg = math.floor((existing.copper * 0.6) + (unitCopper * 0.4))
	end

	db.prices[itemID] = {
		itemID = itemID,
		copper = avg,
		minCopper = (existing and existing.minCopper and (now - (existing.seenAt or 0)) < 3600)
			and math.min(existing.minCopper, unitCopper) or unitCopper,
		reporter = reporter or InfinityHive:GetPlayerShortName(),
		seenAt = now,
	}

	if broadcast and InfinityHive:GetConfig().shareAuctionPrices then
		InfinityHive:Send("AH", string.format("%d|%d|%d", itemID, avg, now), "GUILD")
	end
end

function InfinityHiveAuction:GetPrice(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	local db = InfinityHive:GetDB()
	return db.prices[itemID]
end

-- Scan currently visible Auction House browse results (Classic AuctionFrame & Modern C_AuctionHouse)
function InfinityHiveAuction:ScanVisibleListings()
	local now = GetTime()
	if (now - self.lastScanTime) < 1.5 then return 0 end
	self.lastScanTime = now

	local lowest = {}
	local scanned = 0

	-- Classic AuctionFrame API
	if GetNumAuctionItems and GetAuctionItemInfo and GetAuctionItemLink then
		local ok, numBatch = pcall(GetNumAuctionItems, "list")
		if ok and numBatch and numBatch > 0 then
			local limit = math.min(numBatch, 50)
			for i = 1, limit do
				local _, _, count, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", i)
				local link = GetAuctionItemLink("list", i)
				local itemID = link and InfinityUtils and InfinityUtils:GetItemIDFromHyperlink(link)
				if itemID and buyoutPrice and buyoutPrice > 0 then
					local stack = (count and count > 0) and count or 1
					local unitPrice = math.floor(buyoutPrice / stack)
					if not lowest[itemID] or unitPrice < lowest[itemID] then
						lowest[itemID] = unitPrice
					end
					scanned = scanned + 1
				end
			end
		end
	end

	-- Modern C_AuctionHouse browse results API
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

	local me = InfinityHive:GetPlayerShortName()
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
function InfinityHiveAuction:SearchNativeAH(itemName)
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
function InfinityHiveAuction:GetAllGuildNeededItems()
	local db = InfinityHive:GetDB()
	local me = InfinityHive:GetPlayerShortName()
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
		local name, link, quality = InfinityUtils:GetItemInfo(itemID)
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

function InfinityHiveAuction:RefreshPanel()
	if not self.panel or not self.panel.listContent then return end
	local UI = _G.InfinityUIFramework
	local container = self.panel.listContent
	UI:ClearContainer(container)

	local query = self.panel.searchBox and (self.panel.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""

	if self.activeTab == "needs" then
		local items = self:GetAllGuildNeededItems()
		local y = -4
		local shown = 0
		for _, item in ipairs(items) do
			if query == "" or item.name:lower():find(query, 1, true) then
				shown = shown + 1
				local row = UI:CreateListRow(container, 274, 34, shown, function()
					InfinityHiveAuction:SearchNativeAH(item.name)
				end)
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

				local qCol = InfinityUtils:GetQualityColor(item.quality)
				local who = {}
				for idx, nd in ipairs(item.needers) do
					if idx <= 2 then table.insert(who, nd.name .. " (" .. nd.prof .. ")") end
				end
				if #item.needers > 2 then
					table.insert(who, "+" .. (#item.needers - 2) .. " more")
				end

				local topLbl = UI:CreateLabel(row, qCol .. item.name .. "|r")
				topLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)

				local subLbl = UI:CreateLabel(row, "Need: " .. table.concat(who, ", "), 0.65, 0.78, 0.90)
				subLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)

				local priceStr = item.price and ("|cfffbbf24" .. InfinityUtils:FormatGold(item.price) .. "|r") or "|cff94a3b8Scan|r"
				local pLbl = UI:CreateLabel(row, priceStr)
				pLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -3)

				row:SetScript("OnEnter", function(selfRow)
					if GameTooltip then
						GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
						if item.link then
							GameTooltip:SetHyperlink(item.link)
						else
							GameTooltip:AddLine(item.name, 1, 1, 1)
						end
						GameTooltip:AddLine("|cff38bdf8Click to search in Auction House|r", 0.5, 0.8, 1)
						GameTooltip:Show()
					end
				end)
				row:SetScript("OnLeave", function()
					if GameTooltip then GameTooltip:Hide() end
				end)

				y = y - 36
				if shown >= 40 then break end
			end
		end
		if shown == 0 then
			local empty = UI:CreateLabel(container, "No guild profession material needs recorded yet.\nGuildmates share automatically when online!", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -12)
		end
		container:SetHeight(math.max(260, math.abs(y) + 12))
	else
		local db = InfinityHive:GetDB()
		local prices = {}
		for itemID, info in pairs(db.prices or {}) do
			local name, link, quality = InfinityUtils:GetItemInfo(itemID)
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
			local row = UI:CreateListRow(container, 274, 30, shown, function()
				InfinityHiveAuction:SearchNativeAH(p.name)
			end)
			row:SetPoint("TOPLEFT", container, "TOPLEFT", 2, y)

			local qCol = InfinityUtils:GetQualityColor(p.quality)
			local nameLbl = UI:CreateLabel(row, qCol .. p.name:sub(1, 24) .. "|r")
			nameLbl:SetPoint("LEFT", row, "LEFT", 6, 0)

			local pLbl = UI:CreateLabel(row, "|cfffbbf24" .. InfinityUtils:FormatGold(p.copper) .. "|r")
			pLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)

			row:SetScript("OnEnter", function(selfRow)
				if GameTooltip and p.link then
					GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
					GameTooltip:SetHyperlink(p.link)
					GameTooltip:Show()
				end
			end)
			row:SetScript("OnLeave", function()
				if GameTooltip then GameTooltip:Hide() end
			end)

			y = y - 32
			if shown >= 50 then break end
		end
		if shown == 0 then
			local empty = UI:CreateLabel(container, "Browse or click 'Scan Page' to record\nand share guild AH buyout prices!", 0.65, 0.72, 0.82)
			empty:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -12)
		end
		container:SetHeight(math.max(260, math.abs(y) + 12))
	end
end

-- Attach sleek docked Infinity Market drawer directly onto WoW's Auction House window
function InfinityHiveAuction:AttachToAuctionHouse()
	local host = _G.AuctionHouseFrame or _G.AuctionFrame
	if not host or not _G.InfinityUIFramework then return end
	if self.attachedFrame == host and self.panel then
		self:RefreshPanel()
		return
	end

	local UI = _G.InfinityUIFramework
	self.attachedFrame = host

	-- Embedded header button inside the AH window
	local toggleBtn = UI:CreateButton(host, "Hive Market", 92, 22, function()
		if InfinityHiveAuction.panel:IsVisible() then
			InfinityHiveAuction.panel:Hide()
		else
			InfinityHiveAuction.panel:Show()
			InfinityHiveAuction:RefreshPanel()
		end
	end, true)
	toggleBtn:SetFrameStrata("HIGH")
	toggleBtn:SetPoint("TOPRIGHT", host, "TOPRIGHT", -36, -6)
	self.toggleBtn = toggleBtn

	-- Sleek docked side panel attached directly to the AH window (moves & closes with AH)
	local panel = CreateFrame("Frame", "InfinityHiveAuctionPanel", host, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetSize(310, 420)
	panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, -8)
	panel:SetFrameStrata("HIGH")
	UI:ApplyBackdrop(panel, 0.06, 0.08, 0.12, 0.97, 0.22, 0.30, 0.42, 0.95)

	local header = UI:CreateLabel(panel, "|cff38bdf8Infinity Hive Market|r", 1, 1, 1, "GameFontNormal")
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)

	local scanBtn = UI:CreateButton(panel, "Scan Page", 78, 22, function()
		local n = InfinityHiveAuction:ScanVisibleListings()
		if _G.InfinityUtils then
			_G.InfinityUtils:Info("Scanned and shared " .. tostring(n) .. " Auction House item prices.", "HiveMarket")
		end
		InfinityHiveAuction:RefreshPanel()
	end, true)
	scanBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -8)

	local tabNeeds, tabPrices
	tabNeeds = UI:CreateButton(panel, "Guild Needs", 138, 24, function()
		InfinityHiveAuction.activeTab = "needs"
		tabNeeds:SetActiveState(true)
		tabPrices:SetActiveState(false)
		InfinityHiveAuction:RefreshPanel()
	end)
	tabNeeds:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -36)
	tabNeeds:SetActiveState(true)

	tabPrices = UI:CreateButton(panel, "Guild AH Prices", 138, 24, function()
		InfinityHiveAuction.activeTab = "prices"
		tabNeeds:SetActiveState(false)
		tabPrices:SetActiveState(true)
		InfinityHiveAuction:RefreshPanel()
	end)
	tabPrices:SetPoint("LEFT", tabNeeds, "RIGHT", 8, 0)

	local searchBox = UI:CreateInputBox(panel, 286, 24, function()
		InfinityHiveAuction:RefreshPanel()
	end)
	searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -66)
	panel.searchBox = searchBox

	local scroll = UI:CreateScrollFrame(panel, "InfinityHiveAuctionScroll", 286, 314)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -96)
	panel.listContent = scroll.content

	self.panel = panel
	panel:Show()
	self:RefreshPanel()
end

function InfinityHiveAuction:Initialize()
	if self.initialized then return end
	self.initialized = true

	InfinityHive:RegisterHandler("AH", function(sender, body)
		local idStr, copperStr = body:match("^(%d+)|(%d+)")
		local id, copper = tonumber(idStr), tonumber(copperStr)
		if id and copper and copper > 0 then
			InfinityHiveAuction:RecordPrice(id, copper, sender, false)
		end
	end)

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"AUCTION_HOUSE_SHOW",
		"AUCTION_ITEM_LIST_UPDATE",
		"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"ADDON_LOADED",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "AUCTION_HOUSE_SHOW" then
			InfinityHiveAuction:AttachToAuctionHouse()
		elseif event == "AUCTION_ITEM_LIST_UPDATE" or event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
			InfinityHiveAuction:ScanVisibleListings()
		elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_AuctionUI" or arg1 == "Blizzard_AuctionHouseUI") then
			InfinityHiveAuction:AttachToAuctionHouse()
		end
	end)
end

return InfinityHiveAuction
