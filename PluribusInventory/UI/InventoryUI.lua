-- PluribusInventory UI Module
-- Visual Icon Grid & List Bag Scanner, Live Valuation, Hover Tooltips, Junk Auto-Sell & Guild/Alt Bag Switcher

local PluribusInventoryUI = {
	mainWindow = nil,
	searchQuery = "",
	viewMode = "grid", -- "grid" or "list"
}
_G.PluribusInventoryUI = PluribusInventoryUI

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
			return info.hyperlink, info.stackCount or 1, info.quality or 1, info.itemID, info.iconFileID
		end
	elseif GetContainerItemInfo then
		local icon, count, _, quality, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
		if link then return link, count or 1, quality or 1, itemID, icon end
	end
	return nil, 0, 0, nil, nil
end

local function scanBags()
	local totalSlots, usedSlots, grayCount, totalValue = 0, 0, 0, 0
	local items = {}
	for bag = 0, 4 do
		local slots = getBagSlots(bag)
		totalSlots = totalSlots + slots
		for slot = 1, slots do
			local link, count, quality, itemID, icon = getBagItem(bag, slot)
			if link then
				usedSlots = usedSlots + 1
				itemID = itemID or tonumber(tostring(link):match("item:(%d+)"))
				local name, _, q, _, _, _, _, _, _, tex, sellPrice
				if C_Item and C_Item.GetItemInfo then
					name, _, q, _, _, _, _, _, _, tex, sellPrice = C_Item.GetItemInfo(link)
				elseif GetItemInfo then
					name, _, q, _, _, _, _, _, _, tex, sellPrice = GetItemInfo(link)
				end
				q = q or quality or 1
				sellPrice = sellPrice or 0
				totalValue = totalValue + (sellPrice * count)
				if q == 0 then grayCount = grayCount + 1 end
				table.insert(items, {
					bag = bag,
					slot = slot,
					id = itemID,
					link = link,
					icon = tex or icon,
					name = name or link,
					count = count,
					quality = q,
					value = sellPrice * count,
				})
			end
		end
	end
	return items, usedSlots, totalSlots, grayCount, totalValue
end

function PluribusInventoryUI:Initialize()
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Inventory UI initialized", "Inventory")
	end
end

function PluribusInventoryUI:SellGrayJunk()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		PluribusUIFramework:ShowNotification("|cfffbbf24Open any vendor window first to auto-sell gray items.|r", 2.8)
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
	PluribusUIFramework:ShowNotification("Sold " .. tostring(sold) .. " gray junk item stack(s).", 2.5)
	return sold
end

function PluribusInventoryUI:Toggle()
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

function PluribusInventoryUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusInventoryMainWindow",
		UIParent,
		660,
		490,
		"Pluribus Inventory",
		"Visual Bag Grid, Tooltips, Valuation & Junk Auto-Sell"
	)
	frame:SetPoint("CENTER")

	local searchBox = PluribusUIFramework:CreateInputBox(frame, 210, 24, function(box)
		PluribusInventoryUI.searchQuery = box:GetText() or ""
		PluribusInventoryUI:Refresh()
	end)
	searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local modeBtn = PluribusUIFramework:CreateButton(frame, "List View", 78, 24, function(btn)
		PluribusInventoryUI.viewMode = (PluribusInventoryUI.viewMode == "grid") and "list" or "grid"
		btn.label:SetText(PluribusInventoryUI.viewMode == "grid" and "List View" or "Grid View")
		PluribusInventoryUI:Refresh()
	end)
	modeBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	frame.modeBtn = modeBtn

	local sellBtn = PluribusUIFramework:CreateButton(frame, "Sell Grays", 86, 24, function()
		PluribusInventoryUI:SellGrayJunk()
		PluribusInventoryUI:Refresh()
	end, true)
	sellBtn:SetPoint("LEFT", modeBtn, "RIGHT", 6, 0)

	local guildBagsBtn = PluribusUIFramework:CreateButton(frame, "Alts & Guild Bags", 132, 24, function()
		if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleInventoryViewer then
			_G.PluribusHiveUI:ToggleInventoryViewer()
		end
	end)
	guildBagsBtn:SetPoint("LEFT", sellBtn, "RIGHT", 6, 0)

	local rescanBtn = PluribusUIFramework:CreateButton(frame, "Rescan", 74, 24, function()
		PluribusInventoryUI:Refresh()
	end)
	rescanBtn:SetPoint("LEFT", guildBagsBtn, "RIGHT", 6, 0)

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(636, 404)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -78)

	frame:RegisterEvent("BAG_UPDATE_DELAYED")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function(self)
		if self:IsShown() then
			PluribusInventoryUI:Refresh()
		end
	end)

	self.mainWindow = frame
	self:Refresh()
end

function PluribusInventoryUI:Refresh()
	if not self.mainWindow then return end
	local b = self.mainWindow.body
	PluribusUIFramework:ClearContainer(b)

	local items, used, total, grays, totalVal = scanBags()
	local fmtGold = function(v) return (PluribusUtils and PluribusUtils.FormatGold) and PluribusUtils:FormatGold(v or 0) or (tostring(v or 0) .. "c") end

	local m1 = PluribusUIFramework:CreateMetricTile(b, 204, 56, "Bag Usage", string.format("%d / %d", used, total), "|cff38bdf8")
	m1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local m2 = PluribusUIFramework:CreateMetricTile(b, 204, 56, "Gray Junk Stacks", grays, "|cfffbbf24")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(b, 204, 56, "Vendor Value", fmtGold(totalVal), "|cff4ade80")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = PluribusUIFramework:CreateCard(b, 636, 336, "Bag Contents (Hover for full tooltip · Shift-Click to link)")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -10)

	local scroll = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusInventoryScroll", 620, 296)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	local content = scroll.content

	local q = (self.searchQuery or ""):lower()
	local filtered = {}
	for _, it in ipairs(items) do
		if q == "" or tostring(it.name):lower():find(q, 1, true) then
			table.insert(filtered, it)
		end
	end

	if #filtered == 0 then
		local empty = PluribusUIFramework:CreateLabel(content, "|cff94a3b8No matching bag items found.|r")
		empty:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -10)
		content:SetHeight(280)
		return
	end

	if self.viewMode == "grid" and PluribusUIFramework.CreateItemSlot then
		local cols = 13
		local slotSize = 40
		local gap = 5
		for idx, it in ipairs(filtered) do
			local col = (idx - 1) % cols
			local rowIdx = math.floor((idx - 1) / cols)
			local slot = PluribusUIFramework:CreateItemSlot(content, slotSize, {
				id = it.id,
				link = it.link,
				name = it.name,
				count = it.count,
				quality = it.quality,
				icon = it.icon,
				extraTip = it.value > 0 and ("Vendor Value: " .. fmtGold(it.value)) or nil,
			})
			slot:SetPoint("TOPLEFT", content, "TOPLEFT", 4 + col * (slotSize + gap), -4 - rowIdx * (slotSize + gap))
		end
		local totalRows = math.ceil(#filtered / cols)
		content:SetHeight(math.max(280, totalRows * (slotSize + gap) + 16))
	else
		local rarityHex = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
		local y = -2
		for idx, it in ipairs(filtered) do
			local row = PluribusUIFramework:CreateListRow(content, 594, 28, idx)
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)

			local iconTex = row:CreateTexture(nil, "ARTWORK")
			iconTex:SetSize(20, 20)
			iconTex:SetPoint("LEFT", row, "LEFT", 6, 0)
			iconTex:SetTexture(it.icon or (PluribusUtils and PluribusUtils:GetItemIcon(it)) or "Interface\\Icons\\INV_Misc_QuestionMark")
			iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

			local l = PluribusUIFramework:CreateLabel(row, (rarityHex[it.quality] or "|cffffffff") .. tostring(it.name) .. "|r  |cff94a3b8x" .. tostring(it.count) .. "|r")
			l:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)

			local r = PluribusUIFramework:CreateLabel(row, fmtGold(it.value))
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)

			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if PluribusUtils and PluribusUtils.SetTooltipItem then
					PluribusUtils:SetTooltipItem(GameTooltip, it.id, it.link)
				elseif it.link then
					GameTooltip:SetHyperlink(it.link)
				end
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
			row:SetScript("OnClick", function()
				if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink and it.link then
					ChatEdit_InsertLink(it.link)
				end
			end)
			y = y - 30
		end
		content:SetHeight(math.max(280, -y + 10))
	end
end

return PluribusInventoryUI
