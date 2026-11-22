local InfinityBagTracker = {}
_G.InfinityBagTracker = InfinityBagTracker

InfinityBagTracker.bagContents = {}
InfinityBagTracker.bagSpaces = {}

local function IsSecret(value)
	return _G.issecretvalue and _G.issecretvalue(value)
end

function InfinityBagTracker:Initialize()
	if self.eventFrame then return end
	local saved = InfinityStorageManager:GetFeatureSetting("InfinityInventory", "inventories", {})
	if IsSecret(saved) or type(saved) ~= "table" then
		InfinityUtils:Warning("Saved inventories are invalid; snapshots will not be saved.", "Inventory")
	else
		self.snapshots = saved
		InfinityStorageManager:SetFeatureSetting("InfinityInventory", "inventories", saved)
	end
	local guid = _G.UnitGUID and UnitGUID("player")
	local name = _G.UnitName and UnitName("player")
	local realm = _G.GetRealmName and GetRealmName()
	if _G.RegionalUniqueNamesEnabled and _G.UnitNameUnmodified then
		local enabled = RegionalUniqueNamesEnabled()
		if not IsSecret(enabled) and enabled then
			local first, surname = UnitNameUnmodified("player")
			if not IsSecret(first) and not IsSecret(surname) and type(first) == "string" and first ~= ""
				and type(surname) == "string" and surname ~= "" then
				local constants = _G.Constants and Constants.CharacterNameSeparatorConsts
				local separator = constants and constants.CHARACTERNAME_SURNAME_SEPARATOR or " "
				if not IsSecret(separator) and type(separator) == "string" then
					local ending = separator .. surname
					name = first:sub(-#ending) == ending and first or first .. ending
				end
			end
		end
	end
	if not IsSecret(guid) and type(guid) == "string" and guid ~= ""
		and not IsSecret(name) and type(name) == "string" and name ~= ""
		and not IsSecret(realm) and type(realm) == "string" and realm ~= "" then
		self.characterKey, self.characterName = guid, name .. "-" .. realm
	else
		InfinityUtils:Warning("Character identity unavailable; inventories will not be saved.", "Inventory")
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:RegisterEvent("BANKFRAME_OPENED")
	events:RegisterEvent("BANKFRAME_CLOSED")
	for _, event in ipairs({ "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED" }) do
		local ok = pcall(events.RegisterEvent, events, event)
		if not ok then InfinityUtils:Warning(event .. " unavailable; bank updates may be delayed.", "Inventory") end
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "BANKFRAME_OPENED" then
			self.bankOpen = true
			self.bankObservedThisVisit = false
			self:ScanBank()
			if _G.C_Timer and C_Timer.After then
				C_Timer.After(1, function()
					if self.bankOpen then self:ScanBank(); self:RefreshUI() end
				end)
			end
		elseif event == "BANKFRAME_CLOSED" then
			self.bankOpen = false
		elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then
			self:ScanBags()
			if self.bankOpen then self:ScanBank() end
		elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
			if self.bankOpen then self:ScanBank() end
		end
		self:RefreshUI()
	end)
	self.eventFrame = events
	self:ScanBags()
	InfinityUtils:Info("Bag tracker initialized", "Inventory")
end

function InfinityBagTracker:RefreshUI()
	local ui = _G.InfinityInventoryUI
	if ui and type(ui.Refresh) == "function" then ui:Refresh() end
end

function InfinityBagTracker:SaveSnapshot(kind, contents, sizes)
	if not self.snapshots or not self.characterKey then return end
	local now = _G.time and time()
	if IsSecret(now) or type(now) ~= "number" or now ~= now or now <= 0 or now >= math.huge then
		InfinityUtils:Warning("Clock unavailable; inventory snapshot was not saved.", "Inventory")
		return
	end
	local entry = self.snapshots[self.characterKey]
	if IsSecret(entry) or (entry ~= nil and type(entry) ~= "table") then
		InfinityUtils:Warning("Invalid character inventory; snapshot was not saved.", "Inventory")
		return
	end
	entry = entry or {}
	entry.name = self.characterName
	entry[kind] = { contents = contents, sizes = sizes, observed = now }
	self.snapshots[self.characterKey] = entry
end

function InfinityBagTracker:FailScan(message)
	self.bagContents, self.bagSpaces = {}, {}
	self.freeSlots = nil
	if self.scanError ~= message then InfinityUtils:Warning(message, "Inventory") end
	self.scanError = message
	return false
end

function InfinityBagTracker:ScanBags()
	local container = _G.C_Container
	local getSlots = container and container.GetContainerNumSlots or _G.GetContainerNumSlots
	local getItemID = container and container.GetContainerItemID or _G.GetContainerItemID
	local getInfo = container and container.GetContainerItemInfo or _G.GetContainerItemInfo
	if type(getSlots) ~= "function" or type(getItemID) ~= "function" or type(getInfo) ~= "function" then
		return self:FailScan("Bag API unavailable.")
	end
	local lastBag = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4
	if IsSecret(lastBag) or type(lastBag) ~= "number" or lastBag < 0 or lastBag >= math.huge
		or lastBag ~= math.floor(lastBag) then
		return self:FailScan("Bag count unavailable.")
	end
	local contents, spaces, sizes, free = {}, {}, {}, 0
	for bag = 0, lastBag do
		local slotCount = getSlots(bag)
		if IsSecret(slotCount) or type(slotCount) ~= "number" or slotCount < 0 or slotCount >= math.huge
			or slotCount ~= math.floor(slotCount) then
			return self:FailScan("Bag slots unavailable.")
		end
		if bag == 0 and slotCount == 0 then return self:FailScan("Backpack slots are not yet available.") end
		sizes[bag] = slotCount
		contents[bag], spaces[bag] = {}, 0
		for slot = 1, slotCount do
			local itemId = getItemID(bag, slot)
			local icon, quantity
			if container and getInfo == container.GetContainerItemInfo then
				local info = getInfo(bag, slot)
				if IsSecret(info) then return self:FailScan("Bag contents are protected.") end
				if info ~= nil and type(info) ~= "table" then return self:FailScan("Bag contents are not yet available.") end
				if info then icon, quantity = info.iconFileID, info.stackCount end
			else
				icon, quantity = getInfo(bag, slot)
			end
			if IsSecret(itemId) or IsSecret(icon) or IsSecret(quantity) then
				return self:FailScan("Bag contents are protected.")
			end
			if itemId == nil and icon == nil then
				free = free + 1
			elseif type(itemId) ~= "number" or itemId <= 0 or itemId >= math.huge or itemId ~= math.floor(itemId)
				or type(quantity) ~= "number" or quantity <= 0 or quantity >= math.huge or quantity ~= math.floor(quantity) then
				return self:FailScan("Bag contents are not yet available.")
			else
				local link = InfinityUtils:GetBagItemLink(bag, slot)
				if IsSecret(link) or type(link) ~= "string" then link = nil end
				contents[bag][slot] = { itemId = itemId, quantity = quantity, icon = icon, link = link }
				spaces[bag] = spaces[bag] + 1
			end
		end
	end
	self.bagContents, self.bagSpaces, self.bagSizes, self.freeSlots = contents, spaces, sizes, free
	self.scanError = nil
	self:SaveSnapshot("bags", contents, sizes)
	InfinityMessaging:Publish("bags_scanned")
	return true
end

function InfinityBagTracker:ScanBank(allowEmpty)
	if not self.bankOpen then return false end
	local container = _G.C_Container
	local getSlots = container and container.GetContainerNumSlots or _G.GetContainerNumSlots
	local getID = container and container.GetContainerItemID or _G.GetContainerItemID
	local getInfo = container and container.GetContainerItemInfo or _G.GetContainerItemInfo
	if type(getSlots) ~= "function" or type(getID) ~= "function" or type(getInfo) ~= "function" then
		self.bankError = "Bank API unavailable."; return false
	end
	local ids = {}
	if _G.C_Bank and type(C_Bank.FetchPurchasedBankTabIDs) == "function" then
		if not (_G.Enum and Enum.BankType and Enum.BankType.Character) then
			self.bankError = "Character bank type unavailable."; return false
		end
		local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabIDs, Enum.BankType.Character)
		if not ok or IsSecret(tabs) or type(tabs) ~= "table" or #tabs == 0 then
			self.bankError = "Bank tabs are not yet available."; return false
		end
		for _, id in ipairs(tabs) do ids[#ids + 1] = id end
	else
		if IsSecret(_G.BANK_CONTAINER) or type(_G.BANK_CONTAINER) ~= "number" then
			self.bankError = "Bank containers unavailable."; return false
		end
		ids[1] = BANK_CONTAINER
		local first, count = _G.NUM_BAG_SLOTS or 4, _G.NUM_BANKBAGSLOTS or 6
		if IsSecret(first) or IsSecret(count) or type(first) ~= "number" or type(count) ~= "number"
			or first < 0 or first > 100 or count < 0 or count > 100
			or first ~= math.floor(first) or count ~= math.floor(count) then
			self.bankError = "Bank container count unavailable."; return false
		end
		for i = 1, count do ids[#ids + 1] = first + i end
	end
	local contents, sizes, hasItems = {}, {}, false
	for _, bag in ipairs(ids) do
		if IsSecret(bag) or type(bag) ~= "number" or bag < -1 or bag > 1000000
			or bag ~= math.floor(bag) or sizes[bag] then
			self.bankError = "Invalid bank tab."; return false
		end
		local ok, count = pcall(getSlots, bag)
		if not ok then self.bankError = "Bank slots unavailable: " .. tostring(count); return false end
		if IsSecret(count) or type(count) ~= "number" or count < 0 or count > 1000 or count ~= math.floor(count)
			or (count == 0 and ((_G.C_Bank and C_Bank.FetchPurchasedBankTabIDs) or bag == _G.BANK_CONTAINER)) then
			self.bankError = "Bank slots are not yet available."; return false
		end
		sizes[bag], contents[bag] = count, {}
		for slot = 1, count do
			local okID, id = pcall(getID, bag, slot)
			if not okID then self.bankError = "Bank item unavailable: " .. tostring(id); return false end
			local icon, quantity
			if container and getInfo == container.GetContainerItemInfo then
				local okInfo, info = pcall(getInfo, bag, slot)
				if not okInfo then self.bankError = "Bank item unavailable: " .. tostring(info); return false end
				if IsSecret(info) or (info ~= nil and type(info) ~= "table") then
					self.bankError = "Bank contents unavailable."; return false
				end
				if info then icon, quantity = info.iconFileID, info.stackCount end
			else
				local okInfo
				okInfo, icon, quantity = pcall(getInfo, bag, slot)
				if not okInfo then self.bankError = "Bank item unavailable: " .. tostring(icon); return false end
			end
			if IsSecret(id) or IsSecret(icon) or IsSecret(quantity) then
				self.bankError = "Bank contents are protected."; return false
			end
			if id ~= nil or icon ~= nil then
				if type(id) ~= "number" or id <= 0 or id > 1000000000 or id ~= math.floor(id)
					or type(quantity) ~= "number" or quantity <= 0 or quantity > 1000000000
					or quantity ~= math.floor(quantity) then
					self.bankError = "Bank contents are not yet available."; return false
				end
				local okLink, link = pcall(InfinityUtils.GetBagItemLink, InfinityUtils, bag, slot)
				if not okLink then self.bankError = "Bank item link unavailable: " .. tostring(link); return false end
				if IsSecret(link) or type(link) ~= "string" then link = nil end
				contents[bag][slot] = { itemId = id, quantity = quantity, icon = icon, link = link }
				hasItems = true
			end
		end
	end
	if not hasItems and not allowEmpty and not self.bankObservedThisVisit and self.snapshots and self.characterKey then
		local entry = self.snapshots[self.characterKey]
		if IsSecret(entry) or (entry ~= nil and type(entry) ~= "table") then
			self.bankError = "Saved bank state unavailable."; return false
		end
		local previous = entry and entry.bank
		if IsSecret(previous) or (previous ~= nil and type(previous) ~= "table") then
			self.bankError = "Saved bank state unavailable."; return false
		end
		local oldContents = previous and previous.contents
		if previous and (IsSecret(oldContents) or type(oldContents) ~= "table") then
			self.bankError = "Saved bank contents unavailable."; return false
		end
		if oldContents then
			for _, oldSlots in pairs(oldContents) do
				if IsSecret(oldSlots) or type(oldSlots) ~= "table" then
					self.bankError = "Saved bank contents unavailable."; return false
				end
				if next(oldSlots) then
					self.bankError = "Bank appears empty; refresh to confirm or wait for data."
					return false
				end
			end
		end
	end
	self.bankContents, self.bankSizes, self.bankError = contents, sizes, nil
	self.bankObservedThisVisit = true
	self:SaveSnapshot("bank", contents, sizes)
	return true
end

function InfinityBagTracker:GetItemCount(itemId)
	if IsSecret(itemId) or self.freeSlots == nil or type(itemId) ~= "number" then return nil end
	local total = 0
	for _, slots in pairs(self.bagContents) do
		for _, item in pairs(slots) do
			if item.itemId == itemId then total = total + item.quantity end
		end
	end
	return total
end

function InfinityBagTracker:GetFreeSlots()
	return self.freeSlots
end

return InfinityBagTracker
