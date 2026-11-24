-- PluribusHive Interactive UI Components
-- 1) Non-intrusive Auto-Fading Floating Toast Stack (SOS Rescue & Smart LFG Matches)
-- 2) Bagnon-Style Guild & Alt Bags/Bank Viewer (launched from WoW's Bag frame button or /bags)
-- 3) Compact Draggable Guild Cooldowns Strip (live shared + cast-monitored [Est] timers)

PluribusHiveUI = {
	initialized = false,
	toasts = {},
	invFrame = nil,
	selectedChar = nil,
	invFilter = "ALL", -- ALL | BAGS | BANK
	invSearchAll = false,
	cdFrame = nil,
	cdBars = {},
}
_G.PluribusHiveUI = PluribusHiveUI

-- ============================================================================
-- 1. Non-Intrusive Floating Toast Stack (max 3 visible, smooth auto-dismiss)
-- ============================================================================

function PluribusHiveUI:LayoutToasts()
	local y = -165
	for idx, toast in ipairs(self.toasts) do
		toast:ClearAllPoints()
		toast:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, y)
		y = y - (toast:GetHeight() + 8)
	end
end

function PluribusHiveUI:DismissToast(toast)
	if not toast then return end
	toast:Hide()
	toast:SetScript("OnUpdate", nil)
	for i, t in ipairs(self.toasts) do
		if t == toast then
			table.remove(self.toasts, i)
			break
		end
	end
	self:LayoutToasts()
end

function PluribusHiveUI:ShowToast(opts)
	if not opts or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework

	-- Never overwhelm the screen: cap at 3 concurrent toasts
	while #self.toasts >= 3 do
		self:DismissToast(self.toasts[1])
	end

	local c = opts.color or { 0.22, 0.74, 0.97 }
	local hasActions = opts.action1 ~= nil or opts.action2 ~= nil
	local h = hasActions and 92 or 66

	local toast = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	toast:SetSize(330, h)
	toast:SetFrameStrata("HIGH")
	toast:SetClampedToScreen(true)
	UI:ApplyBackdrop(toast, 0.06, 0.08, 0.13, 0.96, c[1], c[2], c[3], 0.95)

	-- Colored left accent bar
	local stripe = toast:CreateTexture(nil, "OVERLAY")
	stripe:SetWidth(4)
	stripe:SetPoint("TOPLEFT", toast, "TOPLEFT", 1, -1)
	stripe:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 1, 1)
	if stripe.SetColorTexture then
		stripe:SetColorTexture(c[1], c[2], c[3], 1)
	else
		stripe:SetTexture(c[1], c[2], c[3], 1)
	end

	local title = UI:CreateLabel(toast, opts.title or "Pluribus Hive", c[1], c[2], c[3], "GameFontNormal")
	title:SetPoint("TOPLEFT", toast, "TOPLEFT", 12, -9)
	title:SetWidth(285)

	local body = UI:CreateLabel(toast, opts.body or "", 0.88, 0.92, 0.98)
	body:SetPoint("TOPLEFT", toast, "TOPLEFT", 12, -28)
	body:SetWidth(306)

	local closeBtn = UI:CreateButton(toast, "X", 20, 18, function()
		PluribusHiveUI:DismissToast(toast)
	end)
	closeBtn:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -6, -6)

	if opts.action1 then
		local b1 = UI:CreateButton(toast, opts.action1.label or "Action", 124, 22, function()
			if opts.action1.onClick then pcall(opts.action1.onClick) end
			PluribusHiveUI:DismissToast(toast)
		end, true)
		b1:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 12, 9)

		if opts.action2 then
			local b2 = UI:CreateButton(toast, opts.action2.label or "Reply", 124, 22, function()
				if opts.action2.onClick then pcall(opts.action2.onClick) end
				PluribusHiveUI:DismissToast(toast)
			end, false)
			b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
		end
	end

	local duration = opts.duration or 11
	local expireAt = GetTime() + duration
	toast:SetScript("OnUpdate", function(selfFrame)
		local rem = expireAt - GetTime()
		if rem <= 0 then
			PluribusHiveUI:DismissToast(selfFrame)
		elseif rem < 1.5 then
			selfFrame:SetAlpha(math.max(0.05, rem / 1.5))
		end
	end)

	table.insert(self.toasts, toast)
	toast:Show()
	self:LayoutToasts()
	return toast
end

-- ============================================================================
-- 2. Bagnon-Style Visual Guild & Alt Bags/Bank Viewer (Icons + Tooltips!)
-- ============================================================================

local function WhisperOwner(ownerName, itemLink, itemName)
	if not ownerName or ownerName == "" then return end
	if _G.PluribusHive and ownerName == _G.PluribusHive:GetPlayerShortName() then return end
	if ChatFrame_SendTell then
		pcall(ChatFrame_SendTell, ownerName)
	elseif SendChatMessage then
		pcall(SendChatMessage, "Hey! Saw " .. tostring(itemLink or itemName or "that item") .. " in your bags — is it available?", "WHISPER", nil, ownerName)
	end
end

-- Reusable icon-grid renderer used by both the standalone Bag Viewer and MainFrame's Bags tab
function PluribusHiveUI:RenderItemGrid(container, items, opts)
	opts = opts or {}
	local UI = _G.PluribusUIFramework
	local cols = opts.cols or 10
	local slotSize = opts.slotSize or 40
	local gap = opts.gap or 4
	local startY = opts.startY or -4
	local startX = opts.startX or 2
	local me = _G.PluribusHive and _G.PluribusHive:GetPlayerShortName() or ""
	local y = startY

	if opts.headerText then
		local hdr = UI:CreateLabel(container, opts.headerText, 0.78, 0.88, 0.98, "GameFontNormal")
		hdr:SetPoint("TOPLEFT", container, "TOPLEFT", startX, y)
		y = y - 20
	end

	if #items == 0 then
		local empty = UI:CreateLabel(container, opts.emptyText or "No items in this section.", 0.62, 0.70, 0.80)
		empty:SetPoint("TOPLEFT", container, "TOPLEFT", startX + 2, y)
		return y - 24
	end

	for idx, it in ipairs(items) do
		local col = (idx - 1) % cols
		local row = math.floor((idx - 1) / cols)
		local xPos = startX + col * (slotSize + gap)
		local yPos = y - row * (slotSize + gap)

		local isGuildOwner = it.owner and it.owner ~= "" and it.owner ~= me
		local extraLines = {}
		if opts.showOwnerInTooltip and it.owner then
			table.insert(extraLines, "Owner: " .. tostring(it.owner) .. (it.isBank and " (Bank)" or " (Bags)"))
		end
		if isGuildOwner then
			table.insert(extraLines, "Shift-Click: Link in chat  ·  Right-Click: Whisper " .. tostring(it.owner))
		else
			table.insert(extraLines, "Shift-Click: Link in chat")
		end

		local isSurplus = false
		if _G.PluribusHiveProfessions and it.owner == me then
			local neededBy, surplus = _G.PluribusHiveProfessions:GetGuildNeedsForItem(it.itemID)
			isSurplus = surplus and #neededBy > 0
		end

		local slot = UI:CreateItemSlot(container, slotSize, {
			itemID = it.itemID,
			name = it.name,
			link = it.link,
			quality = it.quality,
			icon = it.icon,
			count = it.count or it.total or 1,
			isBank = it.isBank == true,
			isSurplus = isSurplus,
			owner = it.owner,
			extraTooltip = table.concat(extraLines, "\n"),
		}, function(_, mouseBtn)
			if mouseBtn == "RightButton" and isGuildOwner then
				WhisperOwner(it.owner, it.link, it.name)
			end
		end)
		slot:SetPoint("TOPLEFT", container, "TOPLEFT", xPos, yPos)
	end

	local totalRows = math.ceil(#items / cols)
	return y - totalRows * (slotSize + gap) - 10
end

function PluribusHiveUI:CreateInventoryViewer()
	if self.invFrame then return self.invFrame end
	local UI = _G.PluribusUIFramework

	local frame = UI:CreateFrame("PluribusHiveInventoryViewer", UIParent, 738, 510, "Pluribus — Bags & Bank Viewer", "Alts & Sharing Guildmates")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)

	-- Top toolbar
	local searchLbl = UI:CreateLabel(frame, "Search:", 0.72, 0.80, 0.90)
	searchLbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -52)

	local searchBox = UI:CreateInputBox(frame, 186, 24, function()
		PluribusHiveUI:RefreshInventoryViewer()
	end)
	searchBox:SetPoint("LEFT", searchLbl, "RIGHT", 6, 0)
	frame.searchBox = searchBox

	local scopeBtn
	scopeBtn = UI:CreateButton(frame, "Selected Char", 104, 24, function()
		PluribusHiveUI.invSearchAll = not PluribusHiveUI.invSearchAll
		scopeBtn.label:SetText(PluribusHiveUI.invSearchAll and "Whole Guild" or "Selected Char")
		scopeBtn:SetActiveState(PluribusHiveUI.invSearchAll)
		PluribusHiveUI:RefreshInventoryViewer()
	end)
	scopeBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	frame.scopeBtn = scopeBtn

	local fAll, fBags, fBank
	local function SetFilter(mode)
		PluribusHiveUI.invFilter = mode
		fAll:SetActiveState(mode == "ALL")
		fBags:SetActiveState(mode == "BAGS")
		fBank:SetActiveState(mode == "BANK")
		PluribusHiveUI:RefreshInventoryViewer()
	end

	fAll = UI:CreateButton(frame, "All", 40, 24, function() SetFilter("ALL") end)
	fAll:SetPoint("LEFT", scopeBtn, "RIGHT", 8, 0)
	fAll:SetActiveState(true)

	fBags = UI:CreateButton(frame, "Bags", 46, 24, function() SetFilter("BAGS") end)
	fBags:SetPoint("LEFT", fAll, "RIGHT", 4, 0)

	fBank = UI:CreateButton(frame, "Bank", 46, 24, function() SetFilter("BANK") end)
	fBank:SetPoint("LEFT", fBags, "RIGHT", 4, 0)
	frame.setFilterFn = SetFilter

	local viewMode = (_G.PluribusHive and _G.PluribusHive:GetConfig().bagViewerMode) or "grid"
	self.invViewMode = viewMode
	local viewBtn
	viewBtn = UI:CreateButton(frame, viewMode == "grid" and "Grid" or "List", 48, 24, function()
		PluribusHiveUI.invViewMode = (PluribusHiveUI.invViewMode == "grid") and "list" or "grid"
		if _G.PluribusHive then
			_G.PluribusHive:SetConfig("bagViewerMode", PluribusHiveUI.invViewMode)
		end
		viewBtn.label:SetText(PluribusHiveUI.invViewMode == "grid" and "Grid" or "List")
		PluribusHiveUI:RefreshInventoryViewer()
	end)
	viewBtn:SetPoint("LEFT", fBank, "RIGHT", 8, 0)
	frame.viewBtn = viewBtn

	local syncBtn = UI:CreateButton(frame, "Sync", 52, 24, function()
		if _G.PluribusHiveInventory then
			_G.PluribusHiveInventory:ScanBags()
			_G.PluribusHiveInventory:BroadcastBags()
			_G.PluribusHiveInventory:BroadcastBank()
		end
		PluribusHive:RequestFullGuildSync()
		PluribusHiveUI:RefreshInventoryViewer()
	end, true)
	syncBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -46)

	-- Left character list (You / Alts / Guildmates)
	local charPanel = UI:CreateCard(frame, 198, 420, "Characters")
	charPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -76)
	local charScroll = UI:CreateScrollFrame(charPanel, "PluribusHiveInvCharScroll", 184, 384)
	charScroll:SetPoint("TOPLEFT", charPanel, "TOPLEFT", 6, -28)
	frame.charContent = charScroll.content

	-- Right visual item panel
	local itemPanel = UI:CreateCard(frame, 504, 420)
	itemPanel:SetPoint("TOPLEFT", charPanel, "TOPRIGHT", 8, 0)

	local summaryLabel = UI:CreateLabel(itemPanel, "", 0.85, 0.90, 0.96, "GameFontNormal")
	summaryLabel:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 10, -9)
	frame.summaryLabel = summaryLabel

	local legendLabel = UI:CreateLabel(itemPanel, "|cff4ade80•|r Guild Surplus   |cff60a5faB|r Bank   Hover for full tooltip", 0.60, 0.70, 0.80, "GameFontHighlightSmall")
	legendLabel:SetPoint("TOPRIGHT", itemPanel, "TOPRIGHT", -10, -10)

	local itemScroll = UI:CreateScrollFrame(itemPanel, "PluribusHiveInvItemScroll", 482, 378)
	itemScroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 10, -32)
	frame.itemContent = itemScroll.content

	-- Automatically refresh uncached remote item icons/names as WoW downloads them
	local cachePending = false
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function(selfF, ev)
		if ev == "GET_ITEM_INFO_RECEIVED" and selfF:IsVisible() and not cachePending then
			cachePending = true
			if C_Timer and C_Timer.After then
				C_Timer.After(0.25, function()
					cachePending = false
					if selfF:IsVisible() then
						PluribusHiveUI:RefreshInventoryViewer()
					end
				end)
			else
				cachePending = false
			end
		end
	end)

	frame:Hide()
	self.invFrame = frame
	return frame
end

local function BuildItemEntries(countsTbl, ownerName, isBank, query)
	local list = {}
	for id, cnt in pairs(countsTbl or {}) do
		if cnt and cnt > 0 then
			local name, link, quality, _, _, _, _, _, _, icon = PluribusUtils:GetItemInfo(id)
			icon = icon or PluribusUtils:GetItemIcon(id)
			local dName = name or ("Item #" .. tostring(id))
			if query == "" or dName:lower():find(query, 1, true) or tostring(id) == query then
				table.insert(list, {
					itemID = id,
					name = dName,
					link = link,
					quality = quality or 1,
					icon = icon,
					count = cnt,
					bags = isBank and 0 or cnt,
					bank = isBank and cnt or 0,
					total = cnt,
					isBank = isBank,
					owner = ownerName,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		if (a.quality or 1) ~= (b.quality or 1) then return (a.quality or 1) > (b.quality or 1) end
		return a.name < b.name
	end)
	return list
end

function PluribusHiveUI:RefreshInventoryViewer()
	if not self.invFrame or not _G.PluribusHiveInventory then return end
	local UI = _G.PluribusUIFramework
	local chars = _G.PluribusHiveInventory:GetInspectableCharacters()

	if not self.selectedChar and #chars > 0 then
		self.selectedChar = chars[1].name
	end

	-- Populate left character selector
	UI:ClearContainer(self.invFrame.charContent)
	local cy = -2
	local selectedObj = nil
	for idx, ch in ipairs(chars) do
		if ch.name == self.selectedChar then selectedObj = ch end
		local row = UI:CreateListRow(self.invFrame.charContent, 162, 34, idx, function()
			PluribusHiveUI.selectedChar = ch.name
			PluribusHiveUI.invSearchAll = false
			if PluribusHiveUI.invFrame.scopeBtn then
				PluribusHiveUI.invFrame.scopeBtn.label:SetText("Selected Char")
				PluribusHiveUI.invFrame.scopeBtn:SetActiveState(false)
			end
			PluribusHiveUI:RefreshInventoryViewer()
		end)
		row:SetPoint("TOPLEFT", self.invFrame.charContent, "TOPLEFT", 0, cy)

		local bagCnt, bankCnt = 0, 0
		for _ in pairs(ch.bags or {}) do bagCnt = bagCnt + 1 end
		for _ in pairs(ch.bank or {}) do bankCnt = bankCnt + 1 end

		local _, _, _, hex = UI:GetClassColor(ch.class)
		local tag = (ch.group == "YOU" and "|cff38bdf8[You]|r ") or (ch.group == "ALT" and "|cff4ade80[Alt]|r ") or "|cfffbbf24[Guild]|r "
		local nameLbl = UI:CreateLabel(row, tag .. hex .. ch.name .. "|r")
		nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)

		local metaLbl = UI:CreateLabel(row, string.format("%s · %d/%d", PluribusUtils:FormatGold(ch.gold or 0), bagCnt, bankCnt), 0.70, 0.78, 0.88)
		metaLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)

		if ch.name == self.selectedChar and not self.invSearchAll then
			UI:ApplyBackdrop(row, 0.14, 0.34, 0.62, 0.95, 0.22, 0.74, 0.97, 1)
		end

		cy = cy - 36
	end
	self.invFrame.charContent:SetHeight(math.max(376, math.abs(cy) + 10))

	-- Populate right visual bag grid or icon-list view
	UI:ClearContainer(self.invFrame.itemContent)
	local query = self.invFrame.searchBox and (self.invFrame.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""
	local useGrid = (self.invViewMode or "grid") == "grid"
	local endY = -4

	if self.invSearchAll then
		local all = _G.PluribusHiveInventory:SearchAll(query)
		local items = {}
		for _, r in ipairs(all) do
			local cnt = (self.invFilter == "BAGS" and r.bags) or (self.invFilter == "BANK" and r.bank) or r.total
			if cnt > 0 then
				table.insert(items, {
					itemID = r.itemID,
					name = r.name,
					link = r.link,
					quality = r.quality,
					icon = r.icon or PluribusUtils:GetItemIcon(r.itemID),
					count = cnt,
					bags = r.bags,
					bank = r.bank,
					total = cnt,
					isBank = (r.bags == 0 and r.bank > 0),
					owner = r.owner,
				})
			end
		end
		self.invFrame.summaryLabel:SetText(string.format("|cff38bdf8Whole Guild & Alts|r  ·  %d matches", #items))

		if useGrid then
			endY = self:RenderItemGrid(self.invFrame.itemContent, items, {
				cols = 10,
				slotSize = 40,
				gap = 5,
				startY = -4,
				showOwnerInTooltip = true,
				emptyText = "No matching items across your alts or sharing guildmates.",
			})
		else
			endY = self:RenderItemList(self.invFrame.itemContent, items, 456, true)
		end
	elseif selectedObj then
		local bagItems = (self.invFilter ~= "BANK") and BuildItemEntries(selectedObj.bags, selectedObj.name, false, query) or {}
		local bankItems = (self.invFilter ~= "BAGS") and BuildItemEntries(selectedObj.bank, selectedObj.name, true, query) or {}
		local _, _, _, hex = UI:GetClassColor(selectedObj.class)
		self.invFrame.summaryLabel:SetText(string.format("%s%s|r (Lv %d)  ·  |cfffbbf24%s|r  ·  %d bags / %d bank",
			hex, selectedObj.name, selectedObj.level or 60, PluribusUtils:FormatGold(selectedObj.gold or 0), #bagItems, #bankItems))

		if useGrid then
			local curY = -4
			if self.invFilter ~= "BANK" then
				curY = self:RenderItemGrid(self.invFrame.itemContent, bagItems, {
					cols = 10,
					slotSize = 40,
					gap = 5,
					startY = curY,
					headerText = string.format("|cff38bdf8Bags|r (%d stacks)", #bagItems),
					emptyText = "No bag items match this filter.",
				})
			end
			if self.invFilter ~= "BAGS" then
				curY = self:RenderItemGrid(self.invFrame.itemContent, bankItems, {
					cols = 10,
					slotSize = 40,
					gap = 5,
					startY = curY,
					headerText = string.format("|cff60a5faBank|r (%d stacks)", #bankItems),
					emptyText = "No bank items cached yet. Open Bank once on this character to sync!",
				})
			end
			endY = curY
		else
			local combined = {}
			for _, it in ipairs(bagItems) do table.insert(combined, it) end
			for _, it in ipairs(bankItems) do table.insert(combined, it) end
			endY = self:RenderItemList(self.invFrame.itemContent, combined, 456, false)
		end
	else
		self.invFrame.summaryLabel:SetText("No character inventory data scanned yet.")
	end

	self.invFrame.itemContent:SetHeight(math.max(368, math.abs(endY) + 12))
end

-- List view fallback (also features crisp 22x22 item icons + full WoW tooltips!)
function PluribusHiveUI:RenderItemList(container, items, rowWidth, showOwner)
	local UI = _G.PluribusUIFramework
	local me = _G.PluribusHive and _G.PluribusHive:GetPlayerShortName() or ""
	local iy = -2
	for idx, it in ipairs(items) do
		if idx > 150 then break end
		local isGuildOwner = it.owner and it.owner ~= "" and it.owner ~= me
		local row = UI:CreateListRow(container, rowWidth or 456, 26, idx, function(_, mouseBtn)
			if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then
				local link = it.link or select(2, PluribusUtils:GetItemInfo(it.itemID))
				if link then pcall(ChatEdit_InsertLink, link) return end
			end
			if mouseBtn == "RightButton" and isGuildOwner then
				WhisperOwner(it.owner, it.link, it.name)
			end
		end)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, iy)

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(20, 20)
		icon:SetPoint("LEFT", row, "LEFT", 5, 0)
		icon:SetTexture(it.icon or PluribusUtils:GetItemIcon(it.itemID))
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		local qCol = PluribusUtils:GetQualityColor(it.quality)
		local leftStr = qCol .. (it.name or ("Item #" .. tostring(it.itemID))):sub(1, 32) .. "|r"
		if showOwner and it.owner then
			leftStr = leftStr .. "  |cff94a3b8(" .. it.owner .. ")|r"
		end
		local lLbl = UI:CreateLabel(row, leftStr)
		lLbl:SetPoint("LEFT", icon, "RIGHT", 6, 0)

		local locStr
		if (it.bags or 0) > 0 and (it.bank or 0) > 0 then
			locStr = string.format("|cffffffffx%d|r |cff94a3b8(%d bag, %d bank)|r", it.bags + it.bank, it.bags, it.bank)
		elseif it.isBank or (it.bank or 0) > 0 then
			locStr = string.format("|cff60a5fax%d|r |cff94a3b8(bank)|r", it.bank or it.count or 1)
		else
			locStr = string.format("|cffffffffx%d|r |cff94a3b8(bags)|r", it.bags or it.count or 1)
		end
		local rLbl = UI:CreateLabel(row, locStr)
		rLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		row:SetScript("OnEnter", function(selfRow)
			if GameTooltip then
				GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
				local ok = PluribusUtils:SetTooltipItem(GameTooltip, it.itemID, it.link)
				if not ok then GameTooltip:AddLine(it.name or "Item", 1, 1, 1) end
				if isGuildOwner then
					GameTooltip:AddLine("|cff38bdf8Right-Click to whisper " .. tostring(it.owner) .. "|r", 0.5, 0.8, 1)
				end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function()
			if GameTooltip then GameTooltip:Hide() end
		end)

		iy = iy - 28
	end
	if #items == 0 then
		local empty = UI:CreateLabel(container, "No items match this filter. Open your Bank once to cache bank slots!", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -12)
	end
	return iy
end

function PluribusHiveUI:ToggleInventoryViewer(charName, filterMode)
	-- Unified single Bags & Bank viewer inside PluribusMainFrame (eliminates duplicate standalone bag windows)
	if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
		if charName then
			_G.PluribusMainFrame.bagChar = charName
			_G.PluribusMainFrame.bagSearchAll = false
		end
		if filterMode then
			_G.PluribusMainFrame.bagFilter = filterMode
		end
		if _G.PluribusHiveInventory and _G.PluribusHiveInventory.ScanBags then
			_G.PluribusHiveInventory:ScanBags()
		end
		local alreadyOpen = _G.PluribusMainFrame.frame
			and _G.PluribusMainFrame.frame:IsVisible()
			and _G.PluribusMainFrame.currentTab == "Bags & Bank"
			and not charName and not filterMode
		if alreadyOpen then
			_G.PluribusMainFrame.frame:Hide()
		else
			_G.PluribusMainFrame:OpenToTab("Bags & Bank")
		end
		return
	end

	-- Fallback only if MainFrame is not yet initialized
	local frame = self:CreateInventoryViewer()
	if charName then
		self.selectedChar = charName
		self.invSearchAll = false
	end
	if filterMode and frame.setFilterFn then
		frame.setFilterFn(filterMode)
	end
	if frame:IsVisible() and not charName and not filterMode then
		frame:Hide()
	else
		if _G.PluribusHiveInventory then
			_G.PluribusHiveInventory:ScanBags()
		end
		frame:Show()
		self:RefreshInventoryViewer()
	end
end

-- ============================================================================
-- 3. Compact Draggable Guild Cooldowns Strip
-- ============================================================================

function PluribusHiveUI:CreateCooldownOverlay()
	if self.cdFrame then return self.cdFrame end
	local UI = _G.PluribusUIFramework

	local f = CreateFrame("Frame", "PluribusHiveCooldownStrip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(230, 32)
	f:SetPoint("LEFT", UIParent, "LEFT", 18, 90)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(selfF)
		UI:BringToFront(selfF)
		selfF:StartMoving()
	end)
	f:SetScript("OnDragStop", function(selfF)
		selfF:StopMovingOrSizing()
		UI:BringToFront(selfF)
	end)
	f:SetClampedToScreen(true)
	UI:ApplyBackdrop(f, 0.05, 0.07, 0.11, 0.86, 0.20, 0.30, 0.44, 0.85)
	UI:RegisterWindow(f, f)

	local hdr = UI:CreateLabel(f, "|cff38bdf8Hive Cooldowns|r", 1, 1, 1, "GameFontHighlightSmall")
	hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)

	local closeBtn = UI:CreateButton(f, "x", 16, 14, function()
		PluribusHive:SetConfig("showCooldownOverlay", false)
		f:Hide()
	end)
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -4)

	f.bars = {}
	for i = 1, 8 do
		local bar = UI:CreateStatusBar(f, 214, 18, 0.18, 0.56, 0.92)
		bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24 - (i - 1) * 20)
		bar:Hide()
		f.bars[i] = bar
	end

	local accum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + (elapsed or 0)
		if accum >= 0.5 then
			accum = 0
			PluribusHiveUI:RefreshCooldownOverlay()
		end
	end)

	f:Hide()
	self.cdFrame = f
	return f
end

function PluribusHiveUI:RefreshCooldownOverlay()
	if not _G.PluribusHiveCooldowns then return end
	local cfg = PluribusHive:GetConfig()
	if not cfg.showCooldownOverlay then
		if self.cdFrame then self.cdFrame:Hide() end
		return
	end

	local active = _G.PluribusHiveCooldowns:GetActiveCooldowns()
	if #active == 0 then
		if self.cdFrame and not self.cdPinned then
			self.cdFrame:Hide()
		end
		return
	end

	local f = self:CreateCooldownOverlay()
	local UI = _G.PluribusUIFramework
	local count = math.min(#active, #f.bars)
	f:SetHeight(28 + count * 20)
	f:Show()

	for i = 1, #f.bars do
		local bar = f.bars[i]
		local cd = active[i]
		if cd then
			local r, g, b = UI:GetClassColor(cd.class)
			local pct = math.max(0, math.min(100, (cd.remaining / math.max(1, cd.duration)) * 100))
			local estTag = cd.estimated and " |cff94a3b8[Est]|r" or ""
			local leftStr = string.format("%s — %s%s", cd.player, cd.name, estTag)
			local rightStr = PluribusUtils:FormatTime(cd.remaining)
			bar:SetBarData(pct, leftStr, rightStr, r, g, b)
			bar:Show()
		else
			bar:Hide()
		end
	end
end

function PluribusHiveUI:ToggleCooldownOverlay()
	local f = self:CreateCooldownOverlay()
	if f:IsVisible() then
		self.cdPinned = false
		PluribusHive:SetConfig("showCooldownOverlay", false)
		f:Hide()
	else
		self.cdPinned = true
		PluribusHive:SetConfig("showCooldownOverlay", true)
		f:Show()
		self:RefreshCooldownOverlay()
	end
end

-- ============================================================================
-- 4. Reusable Dashboard HiveMind Connectivity & Data-Sync Status Indicator
-- ============================================================================

function PluribusHiveUI:CreateHealthBadge(parent, onSyncClick)
	if not parent or not _G.PluribusUIFramework then return nil end
	local UI = _G.PluribusUIFramework

	local badge = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	badge:SetSize(236, 22)
	UI:ApplyBackdrop(badge, 0.06, 0.09, 0.14, 0.96, 0.22, 0.30, 0.42, 0.9)

	-- Outer soft halo behind status beacon dot
	local halo = badge:CreateTexture(nil, "ARTWORK")
	halo:SetSize(14, 14)
	halo:SetPoint("LEFT", badge, "LEFT", 5, 0)
	if halo.SetColorTexture then
		halo:SetColorTexture(0.29, 0.87, 0.50, 0.25)
	else
		halo:SetTexture("Interface\\Buttons\\WHITE8X8")
		halo:SetVertexColor(0.29, 0.87, 0.50, 0.25)
	end
	badge.halo = halo

	local dot = badge:CreateTexture(nil, "OVERLAY")
	dot:SetSize(8, 8)
	dot:SetPoint("CENTER", halo, "CENTER", 0, 0)
	if dot.SetColorTexture then
		dot:SetColorTexture(0.29, 0.87, 0.50, 1)
	else
		dot:SetTexture("Interface\\Buttons\\WHITE8X8")
		dot:SetVertexColor(0.29, 0.87, 0.50, 1)
	end
	badge.dot = dot

	local text = UI:CreateLabel(badge, "HiveMind: Checking...", 0.90, 0.95, 1.0, "GameFontHighlightSmall")
	text:SetPoint("LEFT", halo, "RIGHT", 5, 0)
	text:SetPoint("RIGHT", badge, "RIGHT", -6, 0)
	badge.text = text

	function badge:Refresh()
		local h = (_G.PluribusHive and _G.PluribusHive.GetNetworkHealth)
			and _G.PluribusHive:GetNetworkHealth()
			or { state = "OFFLINE", shortLabel = "Offline", label = "Offline", color = { 0.97, 0.44, 0.44 }, hex = "|cfff87171", onlinePeers = 0, dbRevision = 1, syncFreshness = "Never", score = 0 }
		local c = h.color or { 0.29, 0.87, 0.50 }
		if self.dot.SetColorTexture then
			self.dot:SetColorTexture(c[1], c[2], c[3], 1)
			self.halo:SetColorTexture(c[1], c[2], c[3], 0.26)
		else
			self.dot:SetVertexColor(c[1], c[2], c[3], 1)
			self.halo:SetVertexColor(c[1], c[2], c[3], 0.26)
		end
		UI:ApplyBackdrop(self, 0.06, 0.09, 0.14, 0.96, c[1], c[2], c[3], 0.72)
		self.text:SetText(string.format("%sHiveMind: %s|r |cff94a3b8· %dp · v%d|r", h.hex, h.shortLabel, h.onlinePeers or 0, h.dbRevision or 1))
		self._lastHealth = h
	end

	badge:SetScript("OnClick", function(selfBadge)
		if _G.PluribusHive then _G.PluribusHive:RequestFullGuildSync() end
		if _G.PluribusHiveNetworkDB then _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end
		selfBadge:Refresh()
		if onSyncClick then pcall(onSyncClick) end
	end)

	badge:SetScript("OnEnter", function(selfBadge)
		selfBadge:Refresh()
		local h = selfBadge._lastHealth
		if GameTooltip and h then
			GameTooltip:SetOwner(selfBadge, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("|cff38bdf8Guild HiveMind Network Health|r", 1, 1, 1)
			GameTooltip:AddDoubleLine("Status:", h.hex .. h.label .. " (" .. tostring(h.score or 0) .. "%)|r", 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddDoubleLine("Guild Channel:", h.isInGuild and "|cff4ade80Connected (PLBHIVE)|r" or "|cfff87171Not in Guild|r", 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddDoubleLine("Online Hive Peers:", tostring(h.onlinePeers or 0), 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddDoubleLine("Data Sync:", tostring(h.syncFreshness or "Never"), 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddDoubleLine("Queue / Packets:", string.format("%d queued · %d tx / %d rx", h.queuedMessages or 0, h.messagesSent or 0, h.messagesReceived or 0), 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddDoubleLine("Hive DB Cache:", string.format("Rev v%d (%d items)", h.dbRevision or 1, h.dbItems or 0), 0.75, 0.82, 0.90, 1, 1, 1)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("|cff4ade80Click to run an immediate guild sync & DB check|r", 0.6, 0.9, 0.7)
			GameTooltip:Show()
		end
	end)

	badge:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	-- Auto-refresh every 2s + smooth subtle pulse while SYNCING
	local tick = 0
	local pulseT = 0
	badge:SetScript("OnUpdate", function(selfBadge, elapsed)
		elapsed = elapsed or 0
		tick = tick + elapsed
		if tick >= 2 then
			tick = 0
			selfBadge:Refresh()
		end
		if selfBadge._lastHealth and selfBadge._lastHealth.state == "SYNCING" then
			pulseT = pulseT + elapsed * 4
			selfBadge.halo:SetAlpha(0.18 + 0.32 * math.abs(math.sin(pulseT)))
		else
			selfBadge.halo:SetAlpha(0.28)
		end
	end)

	badge:Refresh()
	return badge
end

-- Sleek full-width HiveMind Connectivity & Data-Sync Health Strip for Addon Dashboards
function PluribusHiveUI:CreateHealthBanner(parent, width, onSyncClick)
	if not parent or not _G.PluribusUIFramework then return nil end
	local UI = _G.PluribusUIFramework
	local w = width or 728

	local compact = w < 540
	local banner = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	banner:SetSize(w, compact and 76 or 58)
	UI:ApplyBackdrop(banner, 0.06, 0.09, 0.14, 0.96, 0.22, 0.30, 0.42, 0.9)

	-- Left status accent bar
	local stripe = banner:CreateTexture(nil, "OVERLAY")
	stripe:SetWidth(4)
	stripe:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
	stripe:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 1, 1)
	banner.stripe = stripe

	local dot = banner:CreateTexture(nil, "OVERLAY")
	dot:SetSize(10, 10)
	dot:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -12)
	banner.dot = dot

	local titleLbl = UI:CreateLabel(banner, "Guild HiveMind Network", 0.96, 0.98, 1.0, "GameFontNormal")
	titleLbl:SetPoint("LEFT", dot, "RIGHT", 7, 0)
	banner.titleLbl = titleLbl

	local syncBtn = UI:CreateButton(banner, "Sync Now", 82, 22, function()
		if _G.PluribusHive then _G.PluribusHive:RequestFullGuildSync() end
		if _G.PluribusHiveNetworkDB then _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end
		banner:Refresh()
		if onSyncClick then pcall(onSyncClick) end
	end, true)

	local healthBar
	local detailLbl = UI:CreateLabel(banner, "", 0.72, 0.80, 0.90, "GameFontHighlightSmall")
	if compact then
		syncBtn:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -10, -8)
		healthBar = UI:CreateStatusBar(banner, w - 28, 16, 0.29, 0.87, 0.50)
		healthBar:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -34)
		detailLbl:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 14, 7)
	else
		syncBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)
		local barW = math.max(150, math.min(220, w - 480))
		healthBar = UI:CreateStatusBar(banner, barW, 18, 0.29, 0.87, 0.50)
		healthBar:SetPoint("RIGHT", syncBtn, "LEFT", -10, 0)
		detailLbl:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 14, 9)
	end
	banner.healthBar = healthBar
	banner.detailLbl = detailLbl

	function banner:Refresh()
		local h = (_G.PluribusHive and _G.PluribusHive.GetNetworkHealth)
			and _G.PluribusHive:GetNetworkHealth()
			or { state = "OFFLINE", label = "Offline", shortLabel = "Offline", color = { 0.97, 0.44, 0.44 }, hex = "|cfff87171", score = 0, isInGuild = false, onlinePeers = 0, queuedMessages = 0, messagesSent = 0, messagesReceived = 0, syncFreshness = "Never", dbRevision = 1, dbItems = 0 }
		local c = h.color or { 0.29, 0.87, 0.50 }

		if self.stripe.SetColorTexture then
			self.stripe:SetColorTexture(c[1], c[2], c[3], 1)
			self.dot:SetColorTexture(c[1], c[2], c[3], 1)
		else
			self.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
			self.stripe:SetVertexColor(c[1], c[2], c[3], 1)
			self.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
			self.dot:SetVertexColor(c[1], c[2], c[3], 1)
		end

		UI:ApplyBackdrop(self, 0.06, 0.09, 0.14, 0.96, c[1], c[2], c[3], 0.55)
		self.titleLbl:SetText(string.format("HiveMind Network: %s%s|r", h.hex, h.label))
		if compact then
			self.detailLbl:SetText(string.format(
				"PLBHIVE · %d peers · Sync: %s · %d tx/%d rx · DB v%d",
				h.onlinePeers or 0,
				h.syncFreshness or "Never",
				h.messagesSent or 0,
				h.messagesReceived or 0,
				h.dbRevision or 1
			))
		else
			self.detailLbl:SetText(string.format(
				"PLBHIVE %s · %d peers · Sync: %s · Queue: %d (%d tx / %d rx) · DB Rev v%d",
				h.isInGuild and "Connected" or "No Guild",
				h.onlinePeers or 0,
				h.syncFreshness or "Never",
				h.queuedMessages or 0,
				h.messagesSent or 0,
				h.messagesReceived or 0,
				h.dbRevision or 1
			))
		end
		self.healthBar:SetBarData(h.score or 0, h.shortLabel, tostring(h.score or 0) .. "%", c[1], c[2], c[3])
	end

	local tick = 0
	banner:SetScript("OnUpdate", function(selfBanner, elapsed)
		tick = tick + (elapsed or 0)
		if tick >= 2 then
			tick = 0
			selfBanner:Refresh()
		end
	end)

	banner:Refresh()
	return banner
end

function PluribusHiveUI:Initialize()
	if self.initialized then return end
	self.initialized = true
end

return PluribusHiveUI
