local Lists = {}
_G.InfinityShoppingLists = Lists

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, max)
	value = Public(value)
	return type(value) == "number" and value > 0 and value <= max and value == math.floor(value)
end

local function Name(value)
	value = Public(value)
	return type(value) == "string" and #value <= 80 and value:match("%S")
		and not value:find("[%z\1-\31|]")
end

local function Valid(list)
	list = Public(list)
	local steps = type(list) == "table" and Public(list.steps)
	if type(list) ~= "table" or not Name(list.name) or type(steps) ~= "table" or #steps > 200 then return false end
	local seen = {}
	for index in pairs(steps) do
		if not Integer(index, 200) or index > #steps then return false end
	end
	for _, step in ipairs(steps) do
		step = Public(step)
		if type(step) ~= "table" then return false end
		local itemID, description = Public(step.itemID), Public(step.description)
		if not Integer(itemID, 1000000000) or seen[itemID] or type(description) ~= "string"
			or not description:match("^[1-9]%d*$") or #description > 7
			or not Integer(tonumber(description), 1000000) then return false end
		seen[itemID] = true
	end
	return true
end

function Lists:Initialize()
	if self.initialized then return true end
	local storage = _G.InfinityStorageManager
	if not storage then InfinityUtils:Warning("Shopping list storage is unavailable.", "Inventory"); return false end
	local data = Public(storage:GetFeatureSetting("InfinityInventory", "shoppingLists", {}))
	if type(data) ~= "table" or (_G.issecretvalue and (issecretvalue(data.lists) or issecretvalue(data.active)))
		or (data.lists ~= nil and type(data.lists) ~= "table")
		or (data.active ~= nil and type(data.active) ~= "string") then
		InfinityUtils:Warning("Invalid saved shopping lists.", "Inventory")
		return false
	end
	self.lists, self.active = data.lists or {}, data.active
	self.initialized = true
	self:Connect()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(_, _, name)
		if name == "InfinityGuide" then self:Connect() end
	end)
	self.events = frame
	return true
end

function Lists:Connect()
	local network = Public(_G.InfinityGuideGuildPresets)
	if self.initialized and type(network) == "table" and type(Public(network.RegisterType)) == "function" then
		return network:RegisterType("S", function(name, steps) return self:Save(name, steps, false) end,
			function() return self:GetAll() end)
	end
	return false
end

function Lists:Persist()
	self.deleteConfirmation = nil
	InfinityStorageManager:SetFeatureSetting("InfinityInventory", "shoppingLists", { lists = self.lists, active = self.active })
	if self.window then self:Refresh() end
end

function Lists:GetAll()
	if not self.initialized then InfinityUtils:Warning("Shopping lists are unavailable.", "Inventory"); return nil end
	local ids, result = {}, {}
	for id, list in pairs(self.lists) do
		if not Name(id) or not Valid(list) then
			InfinityUtils:Warning("Invalid saved shopping list; nothing shared.", "Inventory")
			return nil
		end
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do result[#result + 1] = { id = id, preset = self.lists[id] } end
	return result
end

function Lists:Save(name, steps, select)
	local candidate = { name = name, steps = steps }
	if not self.initialized or not Valid(candidate) then
		InfinityUtils:Warning("Invalid shopping list: use unique item IDs and quantities from 1 to 1000000.", "Inventory")
		return nil
	end
	local all = self:GetAll()
	if not all then return nil end
	if #all >= 100 then InfinityUtils:Warning("Shopping list limit reached.", "Inventory"); return nil end
	local index = 1
	while self.lists["shopping_" .. index] do index = index + 1 end
	local id, copy = "shopping_" .. index, {}
	for i, step in ipairs(steps) do copy[i] = { itemID = step.itemID, description = step.description } end
	self.lists[id] = { name = name, steps = copy }
	if select then self.active, self.showingLists = id, false end
	self:Persist()
	print("Saved shopping list " .. id .. ": " .. name .. (select and "" or ". Select it to use it."))
	return id
end

function Lists:Select(id)
	if not self.initialized then InfinityUtils:Warning("Shopping lists are unavailable.", "Inventory"); return false end
	id = Public(id)
	if id == "none" then
		self.active, self.showingLists = nil, true
	elseif type(id) == "string" and Valid(self.lists[id]) then
		self.active, self.showingLists = id, false
	else
		InfinityUtils:Warning("Shopping list not found or invalid.", "Inventory")
		return false
	end
	self:Persist()
	return true
end

function Lists:SetItem(itemID, quantity)
	local list = self.initialized and self.active and Public(self.lists[self.active])
	itemID, quantity = Public(itemID), Public(quantity)
	if not Valid(list) or not Integer(itemID, 1000000000) or not Integer(quantity, 1000000) then
		InfinityUtils:Warning("Select a list and enter a valid item ID and quantity.", "Inventory")
		return false
	end
	for _, step in ipairs(list.steps) do
		if step.itemID == itemID then
			step.description = tostring(quantity)
			self:Persist()
			return true
		end
	end
	if #list.steps >= 200 then InfinityUtils:Warning("Shopping list is full.", "Inventory"); return false end
	list.steps[#list.steps + 1] = { itemID = itemID, description = tostring(quantity) }
	self:Persist()
	return true
end

function Lists:RemoveItem(itemID)
	local list = self.initialized and self.active and Public(self.lists[self.active])
	if not Valid(list) or not Integer(itemID, 1000000000) then
		InfinityUtils:Warning("Select a list and enter a valid item ID.", "Inventory")
		return false
	end
	for index, step in ipairs(list.steps) do
		if step.itemID == itemID then
			table.remove(list.steps, index)
			self:Persist()
			return true
		end
	end
	InfinityUtils:Warning("Item is not in this shopping list.", "Inventory")
	return false
end

function Lists:Delete(id)
	id = Public(id)
	if not self.initialized or type(id) ~= "string" or not Valid(self.lists[id]) then
		InfinityUtils:Warning("Shopping list not found or invalid.", "Inventory")
		return false
	end
	self.lists[id] = nil
	if self.active == id then self.active, self.showingLists = nil, true end
	self:Persist()
	return true
end

function Lists:Share(id)
	id = Public(id)
	local list = self.initialized and type(id) == "string" and Public(self.lists[id])
	local network = Public(_G.InfinityGuideGuildPresets)
	if type(network) ~= "table" or not network.available or not self:Connect() then
		InfinityUtils:Warning("Guild sharing requires InfinityGuide.", "Inventory")
		return false
	end
	if not Valid(list) then InfinityUtils:Warning("Shopping list not found or invalid.", "Inventory"); return false end
	return network:Send(id, false, list, "S")
end

function Lists:Refresh()
	if not self.window then return end
	local all, items = self:GetAll(), {}
	if not all then
		self.window.status:SetText("Shopping lists unavailable; see warning.")
		self.window:SetItems(items)
		return
	end
	local list = self.active and Public(self.lists[self.active])
	if self.showingLists or not Valid(list) then
		for _, entry in ipairs(all) do
			local id, preset = entry.id, entry.preset
			items[#items + 1] = {
				text = id .. " - " .. preset.name .. " (" .. #preset.steps .. " items)",
				onClick = function() self:Select(id) end,
			}
		end
		if #items == 0 then items[1] = { text = "No shopping lists. Enter a name and click New." } end
		self.window.status:SetText("Click a list to select it. Create, select or share only if wanted.")
	else
		for _, step in ipairs(list.steps) do
			local itemID, quantity = step.itemID, step.description
			items[#items + 1] = {
				text = "Item #" .. itemID .. " | Quantity: " .. quantity .. " | Click to search prices",
				onClick = function() InfinityAuctionPrices:OpenItem(itemID) end,
			}
		end
		if #items == 0 then items[1] = { text = "No items. Enter item ID and quantity, then click Set." } end
		self.window.status:SetText(list.name .. " | ID " .. self.active .. " | Quantities are targets, not purchases.")
	end
	self.window:SetItems(items)
end

function Lists:Toggle()
	if not self.initialized then InfinityUtils:Warning("Shopping lists are unavailable.", "Inventory"); return end
	if not self.window then
		local window = InfinityUIFramework:CreateListWindow("InfinityShoppingListsWindow", "Shopping Lists", 700, 500)
		local function Input(x, width, numeric)
			local box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
			box:SetSize(width, 22)
			box:SetPoint("TOPLEFT", x, -38)
			box:SetAutoFocus(false)
			box:SetNumeric(numeric)
			box:SetMaxLetters(numeric and 10 or 80)
			box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
			return box
		end
		local name, item, quantity = Input(54, 85, false), Input(305, 80, true), Input(425, 45, true)
		local nameLabel = InfinityUIFramework:CreateLabel(window, "Name")
		nameLabel:SetPoint("TOPLEFT", 15, -43)
		local itemLabel = InfinityUIFramework:CreateLabel(window, "Item ID")
		itemLabel:SetPoint("TOPLEFT", 250, -43)
		local quantityLabel = InfinityUIFramework:CreateLabel(window, "Qty")
		quantityLabel:SetPoint("TOPLEFT", 394, -43)
		local function Button(text, x, width, action)
			local button = InfinityUIFramework:CreateButton(window, text, width, 22, action)
			button:SetPoint("TOPLEFT", x, -38)
		end
		Button("New", 144, 46, function() name:ClearFocus(); self:Save(name:GetText(), {}, true) end)
		Button("Lists", 194, 48, function() self.showingLists = true; self:Refresh() end)
		Button("Set", 476, 43, function() self:SetItem(tonumber(Public(item:GetText())), tonumber(Public(quantity:GetText()))) end)
		Button("Remove", 523, 65, function() self:RemoveItem(tonumber(Public(item:GetText()))) end)
		Button("Share", 592, 60, function() self:Share(self.active) end)
		Button("Delete", 656, 42, function()
			local id = self.active
			if not id then InfinityUtils:Warning("Select a shopping list first.", "Inventory"); return end
			if self.deleteConfirmation ~= id then
				self.deleteConfirmation = id
				self.window.status:SetText("Delete " .. id .. "? Click Delete again to confirm.")
			else
				self.deleteConfirmation = nil
				self:Delete(id)
			end
		end)
		self.window, self.nameInput, self.itemInput, self.quantityInput = window, name, item, quantity
	end
	if self.window:IsShown() then self.deleteConfirmation = nil; self.window:Hide() else self:Refresh(); self.window:Show() end
end

return Lists
