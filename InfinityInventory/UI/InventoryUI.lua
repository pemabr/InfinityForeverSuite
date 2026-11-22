-- InfinityInventory UI Module
-- Live Bag Capacity Meter, Total Vendor Value, Searchable Bag Scanner & One-Click Gray Junk Seller

local InfinityInventoryUI = {
	mainWindow = nil,
	searchQuery = "",
}
_G.InfinityInventoryUI = InfinityInventoryUI

local function getBagSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	elseif GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function getBagItem(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then
			return info.hyperlink, info.stackCount or 1, info.quality or 1
		end
	elseif GetContainerItemInfo then
		local _, count, _, quality, _, _, link = GetContainerItemInfo(bag, slot)
		if link then return link, count or 1, quality or 1 end
	end
	return nil, 0, 0
end

local function scanBags()
	local totalSlots, usedSlots, grayCount, totalValue = 0, 0, 0, 0
	local items = {}
	for bag = 0, 4 do
		local slots = getBagSlots(bag)
		totalSlots = totalSlots + slots
		for slot = 1, slots do
			local link, count, quality = getBagItem(bag, slot)
			if link then
				usedSlots = usedSlots + 1
				local name, _, q, _, _, _, _, _, _, _, sellPrice = GetItemInfo and GetItemInfo(link) or nil
				q = q or quality or 1
				sellPrice = sellPrice or 0
				totalValue = totalValue + (sellPrice * count)
				if q == 0 then grayCount = grayCount + 1 end
				table.insert(items, { bag = bag, slot = slot, name = name or link, count = count, quality = q, value = sellPrice * count })
			end
		end
	end
	return items, usedSlots, totalSlots, grayCount, totalValue
end

function InfinityInventoryUI:Initialize()
	if InfinityUtils and InfinityUtils.Info then
		InfinityUtils:Info("Inventory UI initialized", "Inventory")
	end
end

function InfinityInventoryUI:SellGrayJunk()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		InfinityUIFramework:ShowNotification("|cfffbbf24Open any vendor window first to auto-sell gray items.|r", 2.8)
		return 0
	end
	local sold = 0
	for bag = 0, 4 do
		for slot = 1, getBagSlots(bag) do
			local link, _, quality = getBagItem(bag, slot)
			if link and quality == 0 then
				if C_Container and C_Container.UseContainerItem then
					C_Container.UseContainerItem(bag, slot)
				elseif UseContainerItem then
					UseContainerItem(bag, slot)
				end
				sold = sold + 1
			end
		end
	end
	InfinityUIFramework:ShowNotification("Sold " .. tostring(sold) .. " gray junk item stack(s).", 2.5)
	return sold
end

function InfinityInventoryUI:Toggle()
	if not self.mainWindow then
		self:CreateMainWindow()
	end
	if self.mainWindow:IsShown() then
		self.mainWindow:Hide()
	else
		self:Refresh()
		self.mainWindow:Show()
	end
end

function InfinityInventoryUI:CreateMainWindow()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityInventoryMainWindow",
		UIParent,
		640,
		470,
		"Infinity Inventory",
		"Live Bag Valuation, Search & Junk Auto-Sell"
	)
	frame:SetPoint("CENTER")

	local searchBox = InfinityUIFramework:CreateInputBox(frame, 300, 24, function(box)
		InfinityInventoryUI.searchQuery = box:GetText() or ""
		InfinityInventoryUI:Refresh()
	end)
	searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local sellBtn = InfinityUIFramework:CreateButton(frame, "Sell Gray Junk", 124, 24, function()
		InfinityInventoryUI:SellGrayJunk()
		InfinityInventoryUI:Refresh()
	end, true)
	sellBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

	local rescanBtn = InfinityUIFramework:CreateButton(frame, "Rescan Bags", 106, 24, function()
		InfinityInventoryUI:Refresh()
	end)
	rescanBtn:SetPoint("LEFT", sellBtn, "RIGHT", 8, 0)

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(616, 384)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -78)

	self.mainWindow = frame
	self:Refresh()
end

function InfinityInventoryUI:Refresh()
	if not self.mainWindow then return end
	local b = self.mainWindow.body
	InfinityUIFramework:ClearContainer(b)

	local items, used, total, grays, totalVal = scanBags()
	local fmtGold = function(v) return (InfinityUtils and InfinityUtils.FormatGold) and InfinityUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end

	local m1 = InfinityUIFramework:CreateMetricTile(b, 198, 56, "Bag Usage", string.format("%d / %d", used, total), "|cff38bdf8")
	m1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local m2 = InfinityUIFramework:CreateMetricTile(b, 198, 56, "Gray Junk Stacks", grays, "|cfffbbf24")
	m2:SetPoint("LEFT", m1, "RIGHT", 11, 0)
	local m3 = InfinityUIFramework:CreateMetricTile(b, 198, 56, "Vendor Value", fmtGold(totalVal), "|cff4ade80")
	m3:SetPoint("LEFT", m2, "RIGHT", 11, 0)

	local listCard = InfinityUIFramework:CreateCard(b, 616, 314, "Bag Contents")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -10)

	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityInventoryScroll", 600, 274)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	local content = scroll.content

	local q = (self.searchQuery or ""):lower()
	local rarityHex = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
	local y = -2
	local idx = 0
	for _, it in ipairs(items) do
		if q == "" or tostring(it.name):lower():find(q, 1, true) then
			idx = idx + 1
			local row = InfinityUIFramework:CreateListRow(content, 574, 24, idx)
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
			local l = InfinityUIFramework:CreateLabel(row, (rarityHex[it.quality] or "|cffffffff") .. tostring(it.name) .. "|r  |cff94a3b8x" .. tostring(it.count) .. "|r")
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = InfinityUIFramework:CreateLabel(row, fmtGold(it.value))
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 26
		end
	end
	if idx == 0 then
		local empty = InfinityUIFramework:CreateLabel(content, "|cff94a3b8No matching bag items found.|r")
		empty:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -10)
	end
	content:SetHeight(math.max(260, -y + 10))
end

return InfinityInventoryUI
