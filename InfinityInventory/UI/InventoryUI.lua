local InfinityInventoryUI = {}
_G.InfinityInventoryUI = InfinityInventoryUI

function InfinityInventoryUI:Initialize()
	InfinityUtils:Info("Inventory UI initialized", "Inventory")
end

local function Public(value)
	if _G.issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function Integer(value, low, high)
	value = Public(value)
	return type(value) == "number" and value >= low and value <= high and value == math.floor(value)
end

local function ItemName(item)
	local name = Public(InfinityUtils:GetItemInfo(item.itemId))
	if type(name) == "string" and name ~= "" then return name end
	return "Item #" .. item.itemId
end

local function ItemIcon(item)
	local icon = Public(item.icon)
	if type(icon) == "number" or type(icon) == "string" then return icon end
	if _G.C_Item and type(C_Item.GetItemIconByID) == "function" then
		icon = Public(C_Item.GetItemIconByID(item.itemId))
	elseif _G.GetItemIcon then
		icon = Public(GetItemIcon(item.itemId))
	end
	if type(icon) == "number" or type(icon) == "string" then return icon end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function InfinityInventoryUI:GetSources()
	local tracker, sources = InfinityBagTracker, {}
	sources[#sources + 1] = { kind = "bank", key = tracker.characterKey, name = (tracker.characterName or "Current character") .. " - Bank" }
	if type(tracker.snapshots) == "table" then
		for key, entry in pairs(tracker.snapshots) do
			key = Public(key)
			entry = Public(entry)
			local name = type(entry) == "table" and Public(entry.name)
			if type(key) == "string" and type(name) == "string" and name ~= "" then
				if key ~= tracker.characterKey and type(Public(entry.bags)) == "table" then
					sources[#sources + 1] = { kind = "bags", key = key, name = name .. " - Bags" }
				end
				if key ~= tracker.characterKey and type(Public(entry.bank)) == "table" then
					sources[#sources + 1] = { kind = "bank", key = key, name = name .. " - Bank" }
				end
			end
		end
	end
	local reports, guildProblem = _G.InfinityGuildBagReports
	if reports and type(reports.GetInventories) == "function" then
		local inventories
		inventories, guildProblem = reports:GetInventories()
		if type(inventories) == "table" then
			for key, entry in pairs(inventories) do
				sources[#sources + 1] = { kind = "guild", key = key, name = entry.name .. " - Guild bags" }
			end
		end
	else guildProblem = "Guild inventories require Infinity Data Collector." end
	table.sort(sources, function(a, b) return a.name:lower() < b.name:lower() end)
	return sources, guildProblem
end

function InfinityInventoryUI:GetItems(source)
	local tracker, snapshot, status = InfinityBagTracker
	if source.kind == "live" then
		if tracker.scanError or tracker:GetFreeSlots() == nil then return nil, tracker.scanError or "Bags unavailable." end
		snapshot = { contents = tracker.bagContents, sizes = tracker.bagSizes }
		local value, missing = InfinityVendorPricing:CalculateVendorValue()
		status = "Free: " .. tracker:GetFreeSlots() .. " | Vendor: " .. InfinityUtils:FormatGold(value)
		if missing > 0 then status = status .. " | " .. missing .. " prices unknown" end
	elseif source.kind == "guild" then
		local reports = _G.InfinityGuildBagReports
		if not reports or type(reports.GetInventories) ~= "function" then return nil, "Guild reports unavailable." end
		local inventories, problem = reports:GetInventories()
		local inventory = inventories and inventories[source.key]
		if not inventory then return nil, problem or "Guild report unavailable." end
		local items = {}
		for _, item in ipairs(inventory.items) do items[#items + 1] = { item = item } end
		return items, "Guild counts may be incomplete or outdated; slot positions are not shared."
	else
		local currentBank = source.kind == "bank" and source.key == tracker.characterKey
		if currentBank and tracker.bankOpen and not tracker.bankError and tracker.bankContents then
			snapshot = { contents = tracker.bankContents, sizes = tracker.bankSizes }
			status = "Live bank | Left: move, right: use, Alt-click: AH"
		else
			local entry = tracker.snapshots and Public(tracker.snapshots[source.key])
			snapshot = type(entry) == "table" and Public(entry[source.kind])
			if type(snapshot) ~= "table" then
				return nil, currentBank and (tracker.bankError or "Visit the bank to save its contents.") or "Saved inventory unavailable."
			end
			local observed = Public(snapshot.observed)
			status = "Saved, read-only"
			if Integer(observed, 1, 100000000000) and _G.date then
				local ok, text = pcall(date, "%Y-%m-%d %H:%M", observed)
				if ok and type(text) == "string" then status = status .. " | " .. text end
			end
			if currentBank and tracker.bankOpen and tracker.bankError then status = status .. " | " .. tracker.bankError end
		end
	end
	local contents, sizes = Public(snapshot.contents), Public(snapshot.sizes)
	if type(contents) ~= "table" or type(sizes) ~= "table" then return nil, "Invalid inventory snapshot." end
	local ids, items = {}, {}
	for bag, count in pairs(sizes) do
		if not Integer(bag, -1, 1000000) or not Integer(count, 0, 1000)
			or type(Public(contents[bag])) ~= "table" then return nil, "Invalid inventory snapshot." end
		ids[#ids + 1] = bag
	end
	table.sort(ids)
	for _, bag in ipairs(ids) do
		for slot = 1, sizes[bag] do
			local item = contents[bag][slot]
			if _G.issecretvalue and issecretvalue(item) then return nil, "Protected inventory item." end
			if item ~= nil and (type(item) ~= "table" or not Integer(item.itemId, 1, 1000000000)
				or not Integer(item.quantity, 1, 1000000000)) then return nil, "Invalid inventory item." end
			items[#items + 1] = { item = item, bag = bag, slot = slot }
		end
	end
	if source.kind == "live" then status = status .. " | Left: move, right: use, Alt: AH" end
	return items, status
end

function InfinityInventoryUI:RefreshWindow(frame)
	local items, status = self:GetItems(frame.source)
	local query = Public(frame.search:GetText())
	query = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
	local shown = 0
	for _, entry in ipairs(items or {}) do
		local item = entry.item
		if query == "" or (item and (ItemName(item):lower():find(query, 1, true)
			or tostring(item.itemId):find(query, 1, true))) then
			shown = shown + 1
			local cell = frame.cells[shown]
			if not cell then
				cell = CreateFrame("Button", nil, frame.scroll.content)
				cell:SetSize(38, 38)
				cell:SetPoint("TOPLEFT", ((shown - 1) % 12) * 42, -math.floor((shown - 1) / 12) * 42)
				cell.icon = cell:CreateTexture(nil, "ARTWORK")
				cell.icon:SetAllPoints()
				cell.count = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				cell.count:SetPoint("BOTTOMRIGHT", -2, 2)
				cell:SetScript("OnEnter", function(button)
					local data = button.data
					if data and data.item and _G.GameTooltip then
						GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
						local link = Public(data.item.link)
						GameTooltip:SetHyperlink(type(link) == "string" and link or ("item:" .. data.item.itemId))
						local observed = Public(data.item.observed)
						if Integer(observed, 1, 100000000000) and _G.date and GameTooltip.AddLine then
							local ok, text = pcall(date, "%Y-%m-%d %H:%M", observed)
							if ok and type(text) == "string" then GameTooltip:AddLine("Reported: " .. text) end
						end
						GameTooltip:Show()
					end
				end)
				cell:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
				cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				cell:SetScript("OnClick", function(button, mouseButton) self:ClickItem(frame, button.data, mouseButton) end)
				frame.cells[shown] = cell
			end
			cell.data = entry
			cell.icon:SetTexture(item and ItemIcon(item) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
			cell.count:SetText(item and item.quantity > 1 and tostring(item.quantity) or "")
			cell:Show()
		end
	end
	for index = shown + 1, #frame.cells do frame.cells[index]:Hide() end
	frame.scroll.content:SetHeight(math.max(1, math.ceil(shown / 12) * 42))
	frame.scroll:UpdateScrollChildRect()
	frame.status:SetText(status or "Inventory unavailable.")
end

function InfinityInventoryUI:ClickItem(frame, entry, mouseButton)
	if not entry then return end
	local alt = _G.IsAltKeyDown and IsAltKeyDown()
	if _G.issecretvalue and issecretvalue(alt) then
		InfinityUtils:Warning("Modifier state unavailable.", "Inventory"); return
	end
	if alt then
		if entry.item then InfinityAuctionPrices:OpenItem(entry.item.itemId) end
		return
	end
	local shift = _G.IsShiftKeyDown and IsShiftKeyDown()
	if _G.issecretvalue and issecretvalue(shift) then
		InfinityUtils:Warning("Modifier state unavailable.", "Inventory"); return
	end
	if shift then
		local chat = _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
		if _G.issecretvalue and issecretvalue(chat) then
			InfinityUtils:Warning("Chat state unavailable.", "Inventory"); return
		end
		if entry.item and chat and _G.HandleModifiedItemClick then
			local link = Public(entry.item.link)
			if type(link) ~= "string" then
				local _, resolved = InfinityUtils:GetItemInfo(entry.item.itemId)
				link = Public(resolved)
			end
			if type(link) == "string" then HandleModifiedItemClick(link); return end
		end
		InfinityUtils:Warning("Use the game bags to split stacks or link unavailable items.", "Inventory")
		return
	end
	local tracker = InfinityBagTracker
	local live = frame.source.kind == "live" and not tracker.scanError
		or frame.source.kind == "bank" and frame.source.key == tracker.characterKey and tracker.bankOpen and not tracker.bankError
	if not live then return end
	if not entry.item and mouseButton == "RightButton" then return end
	local combat = _G.InCombatLockdown and InCombatLockdown()
	if (_G.issecretvalue and issecretvalue(combat)) or combat then
		InfinityUtils:Warning("Use the game bags during combat.", "Inventory"); return
	end
	local container = _G.C_Container
	local getID = container and container.GetContainerItemID or _G.GetContainerItemID
	if type(getID) ~= "function" then
		InfinityUtils:Warning("Bag item state unavailable.", "Inventory"); return
	end
	local okID, current = pcall(getID, entry.bag, entry.slot)
	local okLink, link = pcall(InfinityUtils.GetBagItemLink, InfinityUtils, entry.bag, entry.slot)
	if not okID or not okLink then
		InfinityUtils:Warning("Bag item state unavailable: " .. tostring(not okID and current or link), "Inventory")
		return
	end
	if (_G.issecretvalue and (issecretvalue(current) or issecretvalue(link)))
		or current ~= (entry.item and entry.item.itemId)
		or (entry.item and entry.item.link and link ~= entry.item.link) then
		InfinityUtils:Warning("Bag slot changed; refreshing before an action.", "Inventory")
		if frame.source.kind == "live" then tracker:ScanBags() else tracker:ScanBank() end
		self:Refresh()
		return
	end
	local action
	if mouseButton == "RightButton" then action = container and container.UseContainerItem or _G.UseContainerItem
	else action = container and container.PickupContainerItem or _G.PickupContainerItem end
	if type(action) ~= "function" then
		InfinityUtils:Warning("Bag item action unavailable; use the game bags.", "Inventory"); return
	end
	local ok, problem = pcall(action, entry.bag, entry.slot)
	if _G.issecretvalue and issecretvalue(problem) then
		InfinityUtils:Warning("Bag item action result unavailable.", "Inventory")
	elseif not ok or problem == false then
		InfinityUtils:Warning("Bag item action failed: " .. tostring(problem), "Inventory")
	end
end

function InfinityInventoryUI:Refresh()
	if self.mainFrame and self.mainFrame:IsShown() then self:RefreshWindow(self.mainFrame) end
	for _, frame in pairs(self.inventoryWindows or {}) do
		if frame:IsShown() then self:RefreshWindow(frame) end
	end
	if self.sourceWindow and self.sourceWindow:IsShown() then self:RefreshSources() end
end

function InfinityInventoryUI:HasVisibleWindows()
	if self.mainFrame and self.mainFrame:IsShown() then return true end
	if self.sourceWindow and self.sourceWindow:IsShown() then return true end
	for _, frame in pairs(self.inventoryWindows or {}) do if frame:IsShown() then return true end end
	return false
end

function InfinityInventoryUI:RefreshSources()
	local rows, raw = {}, Public(self.sourceSearch:GetText())
	local query = type(raw) == "string" and raw:lower():match("^%s*(.-)%s*$") or ""
	local sources, guildProblem = self:GetSources()
	for _, source in ipairs(sources) do
		if source.name:lower():find(query, 1, true) then
			rows[#rows + 1] = { text = source.name, onClick = function() self:OpenSource(source) end }
		end
	end
	if #rows == 0 then rows[1] = { text = "No matching inventories." } end
	self.sourceWindow:SetItems(rows)
	self.sourceWindow.status:SetText(guildProblem or "Own snapshots and voluntary guild reports; select to open.")
end

function InfinityInventoryUI:ShowSources()
	if not self.sourceWindow then
		local frame = InfinityUIFramework:CreateListWindow("InfinityInventorySources", "Choose inventory", 550, 420)
		local label = InfinityUIFramework:CreateLabel(frame, "Search")
		label:SetPoint("TOPLEFT", 20, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(300, 20)
		input:SetPoint("TOPLEFT", 85, -38)
		input:SetAutoFocus(false)
		input:SetScript("OnTextChanged", function() self:RefreshSources() end)
		local settings = InfinityUIFramework:CreateButton(frame, "Guild sharing", 110, 22, function()
			local collector = _G.InfinityDataCollectorUI
			if not collector or type(collector.Show) ~= "function" or type(collector.ShowTab) ~= "function" then
				InfinityUtils:Warning("Guild sharing settings require Infinity Data Collector.", "Inventory"); return
			end
			collector:Show()
			collector:ShowTab("settings")
		end)
		settings:SetPoint("TOPLEFT", 405, -38)
		self.sourceWindow, self.sourceSearch = frame, input
		frame.status:SetWidth(520)
		frame.status:SetJustifyH("LEFT")
	end
	self.sourceWindow:Show()
	self:RefreshSources()
end

function InfinityInventoryUI:CreateInventoryWindow(name, title, source)
	local frame = InfinityUIFramework:CreateFrame(name, UIParent, 560, 500)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(window) window:StartMoving() end)
	frame:SetScript("OnDragStop", function(window) window:StopMovingOrSizing() end)
	local heading = InfinityUIFramework:CreateLabel(frame, title)
	heading:SetPoint("TOPLEFT", 15, -12)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -5, -5)
	close:SetScript("OnClick", function() frame:Hide() end)
	local label = InfinityUIFramework:CreateLabel(frame, "Search")
	label:SetPoint("TOPLEFT", 20, -80)
	frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.search:SetSize(160, 20)
	frame.search:SetPoint("TOPLEFT", 95, -75)
	frame.search:SetAutoFocus(false)
	frame.search:SetScript("OnTextChanged", function() self:RefreshWindow(frame) end)
	frame.scroll = InfinityUIFramework:CreateScrollFrame(frame, nil, 515, 360)
	frame.scroll:SetPoint("TOPLEFT", 18, -108)
	frame.scroll.content:SetWidth(505)
	frame.cells, frame.source = {}, source
	frame.status = InfinityUIFramework:CreateLabel(frame, "")
	frame.status:SetPoint("BOTTOMLEFT", 15, 12)
	frame.status:SetWidth(530)
	frame.status:SetJustifyH("LEFT")
	if source.kind == "bank" then
		local refresh = InfinityUIFramework:CreateButton(frame, "Refresh bank", 110, 22, function()
			if source.key ~= InfinityBagTracker.characterKey or not InfinityBagTracker.bankOpen then
				InfinityUtils:Warning("Visit this character's bank to refresh it.", "Inventory"); return
			end
			if not InfinityBagTracker:ScanBank(true) then
				InfinityUtils:Warning(InfinityBagTracker.bankError or "Bank unavailable.", "Inventory")
			end
			self:Refresh()
		end)
		refresh:SetPoint("TOPLEFT", 270, -74)
	end
	frame:Hide()
	return frame
end

function InfinityInventoryUI:OpenSource(source)
	self.inventoryWindows = self.inventoryWindows or {}
	local key = source.kind .. ":" .. (source.key or "current")
	local frame = self.inventoryWindows[key]
	if not frame then
		frame = self:CreateInventoryWindow(nil, source.name, source)
		local count = 0
		for _ in pairs(self.inventoryWindows) do count = count + 1 end
		local offset = (count % 6) * 25
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", offset, -offset)
		self.inventoryWindows[key] = frame
	end
	self:RefreshWindow(frame)
	frame:Show()
end

function InfinityInventoryUI:OpenCurrentBank()
	local tracker = _G.InfinityBagTracker
	if not tracker then InfinityUtils:Warning("Bank tracker unavailable.", "Inventory"); return false end
	self:OpenSource({ kind = "bank", key = tracker.characterKey,
		name = (tracker.characterName or "Current character") .. " - Bank" })
	return true
end

function InfinityInventoryUI:OpenGuildMember(name)
	name = Public(name)
	if type(name) ~= "string" or name == "" then
		InfinityUtils:Warning("Guild member name unavailable.", "Inventory"); return false
	end
	if not name:find("-", 1, true) then
		local realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if type(realm) ~= "string" or realm == "" then realm = _G.GetRealmName and Public(GetRealmName()) end
		if type(realm) ~= "string" or realm == "" then
			InfinityUtils:Warning("Realm unavailable; cannot identify guild member.", "Inventory"); return false
		end
		name = name .. "-" .. realm
	end
	local key = name:lower():gsub("%s+", "")
	local reports = _G.InfinityGuildBagReports
	if not reports or type(reports.GetInventories) ~= "function" then
		InfinityUtils:Warning("Guild inventories require Infinity Data Collector.", "Inventory"); return false
	end
	local inventories, problem = reports:GetInventories()
	local entry = type(inventories) == "table" and inventories[key]
	if not entry then
		InfinityUtils:Warning(problem or "No shared bag report for this guild member.", "Inventory"); return false
	end
	self:OpenSource({ kind = "guild", key = key, name = entry.name .. " - Guild bags" })
	return true
end

function InfinityInventoryUI:ShowRecipe()
	if not self.recipeWindow then
		local frame = InfinityUIFramework:CreateListWindow("InfinityInventoryRecipeWindow", "Recipe Reagents", 600, 450)
		local idLabel = InfinityUIFramework:CreateLabel(frame, "Recipe ID")
		idLabel:SetPoint("TOPLEFT", 15, -43)
		local id = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		id:SetSize(90, 20)
		id:SetPoint("TOPLEFT", 85, -38)
		id:SetAutoFocus(false)
		id:SetMaxLetters(10)
		local quantityLabel = InfinityUIFramework:CreateLabel(frame, "Quantity")
		quantityLabel:SetPoint("TOPLEFT", 195, -43)
		local quantity = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		quantity:SetSize(60, 20)
		quantity:SetPoint("TOPLEFT", 260, -38)
		quantity:SetAutoFocus(false)
		quantity:SetMaxLetters(7)
		quantity:SetText("1")
		local function CheckRecipe()
			frame:SetItems({})
			frame.status:SetText("Check failed; see warning.")
			local rawID, rawQuantity = id:GetText(), quantity:GetText()
			if _G.issecretvalue and (issecretvalue(rawID) or issecretvalue(rawQuantity)) then
				InfinityUtils:Warning("Protected recipe input cannot be used.", "Inventory")
				return
			end
			local recipeID = type(rawID) == "string" and rawID:match("^%s*%d+%s*$") and tonumber(rawID)
			local crafts = type(rawQuantity) == "string" and rawQuantity:match("^%s*%d+%s*$") and tonumber(rawQuantity)
			if not recipeID or not crafts then
				InfinityUtils:Warning("Enter a recipe ID and quantity.", "Inventory")
				return
			end
			if not InfinityBagTracker:ScanBags() then
				InfinityUtils:Warning(InfinityBagTracker.scanError or "Bag scan failed.", "Inventory")
				return
			end
			local materials, problem = InfinityCraftingIntegration:GetBasicMaterials(recipeID, crafts)
			if not materials then InfinityUtils:Warning(problem, "Inventory"); return end
			local rows = {}
			for _, item in ipairs(materials) do
				local name, link = InfinityUtils:GetItemInfo(item.itemId)
				name, link = Public(name), Public(link)
				local suffix = type(name) == "string" and name ~= "" and (" - " .. name) or ""
				rows[#rows + 1] = { text = string.format("Item %d: %d / %d | missing %d",
					item.itemId, item.have, item.needed, item.missing) .. suffix,
					link = type(link) == "string" and link or ("item:" .. item.itemId) }
			end
			if #rows == 0 then rows[1] = { text = "No basic reagents found; check the profession window." } end
			frame.status:SetText("Bag reagents only; bank and optional requirements are not checked.")
			frame:SetItems(rows)
		end
		local search = InfinityUIFramework:CreateButton(frame, "Check", 80, 22, CheckRecipe)
		search:SetPoint("TOPLEFT", 340, -38)
		frame.status:SetText("Open the profession, enter a recipe ID and quantity, then click Check.")
		self.recipeWindow, self.recipeID, self.recipeQuantity, self.recipeSearch, self.checkRecipe = frame, id, quantity, search, CheckRecipe
	end
	local recipeID, problem = InfinityUIFramework:GetSelectedProfessionRecipeID()
	if problem then InfinityUtils:Warning(problem, "Inventory") end
	if recipeID then
		self.recipeID:SetText(tostring(recipeID))
		self.recipeQuantity:SetText("1")
		self.checkRecipe()
	end
	self.recipeWindow:Show()
end

function InfinityInventoryUI:Toggle()
	if not self.mainFrame then
		self.mainFrame = self:CreateInventoryWindow("InfinityInventoryFrame", "Inventory", { kind = "live" })
		local openBags = InfinityUIFramework:CreateButton(self.mainFrame, "Game Bags", 90, 22, function()
			if _G.ToggleAllBags then _G.ToggleAllBags()
			else InfinityUtils:Warning("Bag controls unavailable.", "Inventory") end
		end)
		openBags:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 15, -38)
		local sources = InfinityUIFramework:CreateButton(self.mainFrame, "Inventories", 95, 22, function()
			self:ShowSources()
		end)
		sources:SetPoint("LEFT", openBags, "RIGHT", 5, 0)
		local prices = InfinityUIFramework:CreateButton(self.mainFrame, "AH Prices", 80, 22, function()
			InfinityAuctionPrices:Toggle()
		end)
		prices:SetPoint("LEFT", sources, "RIGHT", 5, 0)
		local lists = InfinityUIFramework:CreateButton(self.mainFrame, "Shopping", 80, 22, function()
			InfinityShoppingLists:Toggle()
		end)
		lists:SetPoint("LEFT", prices, "RIGHT", 5, 0)
		local crafters = InfinityUIFramework:CreateButton(self.mainFrame, "Crafters", 80, 22, function()
			if _G.InfinityGuildRecipes then InfinityGuildRecipes:Toggle()
			else InfinityUtils:Warning("Guild recipe reports require InfinityDataCollector.", "Inventory") end
		end)
		crafters:SetPoint("LEFT", lists, "RIGHT", 5, 0)
		local stock = InfinityUIFramework:CreateButton(self.mainFrame, "Guild Stock", 90, 22, function()
			if _G.InfinityGuildBagReports then InfinityGuildBagReports:Toggle()
			else InfinityUtils:Warning("Guild bag reports require InfinityDataCollector.", "Inventory") end
		end)
		stock:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 270, -74)
		local recipe = InfinityUIFramework:CreateButton(self.mainFrame, "Reagents", 80, 22, function()
			self:ShowRecipe()
		end)
		recipe:SetPoint("LEFT", stock, "RIGHT", 6, 0)
	end
	if self.mainFrame:IsShown() then
		self.mainFrame:Hide()
	else
		InfinityBagTracker:ScanBags()
		self.mainFrame:Show()
		self:RefreshWindow(self.mainFrame)
	end
end

return InfinityInventoryUI
