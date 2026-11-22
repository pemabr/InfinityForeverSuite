local Prices = {}
_G.InfinityAuctionPrices = Prices

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, minimum, maximum)
	value = Public(value)
	if type(value) ~= "number" or value ~= value or value < minimum or value > maximum
		or value ~= math.floor(value) then return nil end
	return value
end

local function SameKey(first, second)
	first, second = Public(first), Public(second)
	if type(first) ~= "table" or type(second) ~= "table" then return false end
	for _, field in ipairs({ "itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID" }) do
		if _G.issecretvalue and (_G.issecretvalue(first[field]) or _G.issecretvalue(second[field])) then return false end
		if first[field] ~= second[field] then return false end
	end
	return true
end

function Prices:SetStatus(message)
	self.status = message
	if self.window then self.window.status:SetText(message) end
end

function Prices:Initialize()
	if self.events then return end
	local frame = CreateFrame("Frame")
	for _, event in ipairs({
		"AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
		"ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
	}) do frame:RegisterEvent(event) end
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "AUCTION_HOUSE_SHOW" then
			self.open = true
		elseif event == "AUCTION_HOUSE_CLOSED" then
			self.open, self.pending = false, nil
			self:SetStatus((self.resultItemID and ("Item " .. self.resultItemID .. ": ") or "")
				.. "Auction house closed. Results are no longer current.")
		else
			self:OnResults(event, ...)
		end
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		if not self.pending then return end
		elapsed = Public(elapsed)
		if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 or elapsed >= math.huge then return end
		self.pending.wait = self.pending.wait + elapsed
		if self.pending.wait >= 15 then
			local itemID = self.pending.itemID
			self.pending = nil
			self:SetStatus("Item " .. itemID .. ": search timed out or remained partial; retry manually.")
		end
	end)
	self.events = frame
	local house = Public(_G.AuctionHouseFrame)
	if type(house) == "table" and type(Public(house.IsShown)) == "function" then
		local shown = Public(house:IsShown())
		self.open = shown == true
	end
end

function Prices:CreateWindow()
	if self.window then return end
	local window = InfinityUIFramework:CreateListWindow("InfinityAuctionPricesWindow", "Auction Prices", 700, 500)
	local label = InfinityUIFramework:CreateLabel(window, "Item ID:")
	label:SetPoint("TOPLEFT", 15, -43)
	local input = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
	input:SetSize(110, 22)
	input:SetPoint("LEFT", label, "RIGHT", 12, 0)
	input:SetAutoFocus(false)
	input:SetNumeric(true)
	input:SetMaxLetters(10)
	local search = InfinityUIFramework:CreateButton(window, "Search", 90, 22, function()
		input:ClearFocus()
		self:Search(input:GetText())
	end)
	search:SetPoint("LEFT", input, "RIGHT", 10, 0)
	input:SetScript("OnEnterPressed", function()
		input:ClearFocus()
		self:Search(input:GetText())
	end)
	input:SetScript("OnEscapePressed", function() input:ClearFocus() end)
	self.window, self.input = window, input
	window:SetItems({ { text = "Enter an item ID and search at the auction house." } })
	self:SetStatus(self.status or "Read-only prices. Purchases and sales use the game's auction house.")
end

function Prices:Toggle()
	self:CreateWindow()
	if self.window:IsShown() then self.window:Hide() else self.window:Show() end
end

function Prices:OpenItem(itemID)
	itemID = Integer(itemID, 1, 1000000000)
	if not itemID then
		InfinityUtils:Warning("Invalid item ID.", "Auction Prices")
		return false
	end
	self:CreateWindow()
	self.window:Show()
	if self.pending then
		InfinityUtils:Warning("A price search is still pending.", "Auction Prices")
		return false
	end
	self.input:SetText(tostring(itemID))
	return self:Search(itemID)
end

function Prices:Search(value)
	value = Public(value)
	local itemID = (type(value) == "string" or type(value) == "number") and tonumber(value)
	itemID = Integer(itemID, 1, 1000000000)
	if not itemID then
		InfinityUtils:Warning("Enter a valid item ID.", "Auction Prices")
		return false
	end
	if not self.open then
		InfinityUtils:Warning("Open the auction house before searching.", "Auction Prices")
		return false
	end
	local combat = _G.InCombatLockdown and Public(InCombatLockdown())
	if _G.InCombatLockdown and (combat == nil or combat) then
		InfinityUtils:Warning("Auction price searches are unavailable during combat.", "Auction Prices")
		return false
	end
	if self.pending then
		InfinityUtils:Warning("A price search is still pending.", "Auction Prices")
		return false
	end
	local api = Public(_G.C_AuctionHouse)
	if type(api) ~= "table" or type(Public(api.MakeItemKey)) ~= "function"
		or type(Public(api.GetItemKeyInfo)) ~= "function" or type(Public(api.SendSearchQuery)) ~= "function"
		or type(Public(api.HasSearchResults)) ~= "function" then
		InfinityUtils:Warning("Auction price API unavailable.", "Auction Prices")
		return false
	end
	if type(Public(api.IsThrottledMessageSystemReady)) == "function" then
		local ready = Public(api.IsThrottledMessageSystemReady())
		if ready ~= true then
			InfinityUtils:Warning("Auction house is throttled or unavailable; try again shortly.", "Auction Prices")
			return false
		end
	end
	local ok, key, info = pcall(function()
		local requested = Public(api.MakeItemKey(itemID))
		if type(requested) ~= "table" then return requested, nil end
		return requested, api.GetItemKeyInfo(requested)
	end)
	key, info = Public(key), Public(info)
	if not ok then
		InfinityUtils:Warning("Auction item lookup failed: " .. tostring(key or "protected error"), "Auction Prices")
		return false
	end
	if type(key) ~= "table" or Integer(key.itemID, 1, 1000000000) ~= itemID or type(info) ~= "table" then
		if _G.C_Item and type(Public(C_Item.RequestLoadItemDataByID)) == "function" then
			C_Item.RequestLoadItemDataByID(itemID)
		end
		InfinityUtils:Warning("Item information is not loaded; retry shortly.", "Auction Prices")
		return false
	end
	self.pending = { key = key, itemID = itemID, wait = 0 }
	self.resultItemID = itemID
	self:CreateWindow()
	self.window:SetItems({})
	self:SetStatus("Searching item " .. itemID .. "... Results may vary by item variant.")
	local sent, result = pcall(api.SendSearchQuery, key, {}, true)
	if not sent or (_G.issecretvalue and _G.issecretvalue(result)) or result == false then
		self.pending = nil
		self:SetStatus("Search failed; see warning.")
		local reason = not sent and tostring(Public(result) or "protected error") or "request rejected or protected"
		InfinityUtils:Warning("Auction search failed: " .. reason, "Auction Prices")
		return false
	end
	return true
end

function Prices:OnResults(event, reference)
	local pending = self.pending
	if not pending or not self.open then return end
	reference = Public(reference)
	local commodity = event == "COMMODITY_SEARCH_RESULTS_UPDATED"
	if commodity then
		if Integer(reference, 1, 1000000000) ~= pending.itemID then return end
	elseif not SameKey(reference, pending.key) then return end
	local api = Public(_G.C_AuctionHouse)
	if type(api) ~= "table" then
		self.pending = nil
		self:SetStatus("Result API unavailable.")
		InfinityUtils:Warning("Auction result API unavailable.", "Auction Prices")
		return
	end
	local countFn, infoFn, fullFn
	if commodity then
		countFn, infoFn, fullFn = api.GetNumCommoditySearchResults, api.GetCommoditySearchResultInfo,
			api.HasFullCommoditySearchResults
	else
		countFn, infoFn, fullFn = api.GetNumItemSearchResults, api.GetItemSearchResultInfo,
			api.HasFullItemSearchResults
	end
	if type(Public(countFn)) ~= "function" or type(Public(infoFn)) ~= "function"
		or type(Public(fullFn)) ~= "function" then
		self.pending = nil
		self:SetStatus("Result API unavailable.")
		InfinityUtils:Warning("Auction result API unavailable.", "Auction Prices")
		return
	end
	local ok, result = pcall(function()
		local has = Public(api.HasSearchResults(pending.key))
		if has ~= true then return { waiting = true } end
		local full = Public(fullFn(reference))
		if type(full) ~= "boolean" then error("result completeness unavailable") end
		local count = Integer(countFn(reference), 0, 1000000)
		if not count then error("invalid result count") end
		local rows, skipped = {}, 0
		for i = 1, math.min(count, 200) do
			local record = Public(infoFn(reference, i))
			local quantity = type(record) == "table" and Integer(record.quantity, 1, 1000000000)
			local price
			if type(record) == "table" then
				if commodity then price = Integer(record.unitPrice, 1, 100000000000000)
				else price = Integer(record.buyoutAmount, 1, 100000000000000) end
			end
			local bid = not commodity and type(record) == "table" and Integer(record.bidAmount, 1, 100000000000000)
			if quantity and (price or bid) then
				local link = Public(record.itemLink)
				if type(link) ~= "string" or #link > 1000 then link = nil end
				local unit = price and (commodity and price or price / quantity)
				rows[#rows + 1] = { quantity = quantity, price = price, bid = bid, unit = unit, link = link }
			else skipped = skipped + 1 end
		end
		table.sort(rows, function(a, b) return (a.unit or math.huge) < (b.unit or math.huge) end)
		return { rows = rows, full = full, count = count, skipped = skipped }
	end)
	if not ok then
		self.pending = nil
		self:SetStatus("Could not read auction results.")
		InfinityUtils:Warning("Auction results failed: " .. tostring(Public(result) or "protected error"), "Auction Prices")
		return
	end
	if result.waiting then return end
	local items = {}
	for _, row in ipairs(result.rows) do
		local text
		if commodity then
			text = string.format("%d available | %s each", row.quantity, InfinityUtils:FormatGold(row.price))
		elseif row.price then
			local prefix = row.unit ~= math.floor(row.unit) and "~" or ""
			text = string.format("%d items | %s buyout | %s%s each", row.quantity,
				InfinityUtils:FormatGold(row.price), prefix, InfinityUtils:FormatGold(math.floor(row.unit)))
		else
			text = string.format("%d items | bid %s | no buyout", row.quantity, InfinityUtils:FormatGold(row.bid))
		end
		items[#items + 1] = { text = text, link = row.link }
	end
	if #items == 0 then
		items[1] = { text = result.full and result.count == 0 and "No results for this item key."
			or "No usable results in the loaded page." }
	end
	self.window:SetItems(items)
	local status = result.full and "Complete results" or "Partial results"
	if result.count > 200 then status = status .. "; first 200 only" end
	if result.skipped > 0 then status = status .. "; " .. result.skipped .. " unavailable" end
	self:SetStatus("Item " .. pending.itemID .. ": " .. status .. "; item variants may differ.")
	if result.full then self.pending = nil end
end

return Prices
