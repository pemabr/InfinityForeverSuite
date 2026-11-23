-- Infinity Consumables - Consumable and Buff Tracking

InfinityConsumables = {
	inventory = {},
	buffs = {},
	buffTimers = {},
	version = 1,
}

function InfinityConsumables:Initialize()
	InfinityDataManager:RegisterSource("consumables", function(data) end)
	InfinityUtils:Info("Consumables module initialized", "Consumables")
	self:ScanInventory()
end

local function SafeGetContainerNumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	elseif GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function SafeGetContainerItemID(bag, slot)
	if C_Container and C_Container.GetContainerItemID then
		return C_Container.GetContainerItemID(bag, slot)
	elseif GetContainerItemID then
		return GetContainerItemID(bag, slot)
	end
	return nil
end

local function SafeGetContainerItemCount(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if type(info) == "table" then
			return info.stackCount or 1
		end
	elseif GetContainerItemInfo then
		local _, count = GetContainerItemInfo(bag, slot)
		return count or 1
	end
	return 1
end

function InfinityConsumables:ScanInventory()
	self.inventory = {}
	
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local numSlots = SafeGetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local itemID = SafeGetContainerItemID(bag, slot)
			if itemID then
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType = GetItemInfo(itemID)
				local itemCount = SafeGetContainerItemCount(bag, slot)
				
				if itemType == "Consumable" or itemType == "Food & Drink" then
					if not self.inventory[itemID] then
						self.inventory[itemID] = {
							id = itemID,
							name = itemName or "Unknown",
							count = 0,
							rarity = itemRarity or 0,
						}
					end
					self.inventory[itemID].count = self.inventory[itemID].count + (itemCount or 1)
				end
			end
		end
	end
	
	return self.inventory
end

function InfinityConsumables:GetConsumableCount(itemID)
	if self.inventory[itemID] then
		return self.inventory[itemID].count
	end
	return 0
end

function InfinityConsumables:GetAllConsumables()
	local result = {}
	for itemID, data in pairs(self.inventory) do
		table.insert(result, data)
	end
	return result
end

function InfinityConsumables:RecordBuffApplied(buffName, duration, spellID)
	if not spellID then
		spellID = 0
	end
	
	if not self.buffs[spellID] then
		self.buffs[spellID] = {
			name = buffName,
			spellID = spellID,
			appliedTime = InfinityUtils:GetTimeStamp(),
			duration = duration or 0,
			expiresAt = InfinityUtils:GetTimeStamp() + (duration or 0),
		}
	else
		self.buffs[spellID].appliedTime = InfinityUtils:GetTimeStamp()
		self.buffs[spellID].expiresAt = InfinityUtils:GetTimeStamp() + (duration or 0)
	end
	
	InfinityMessaging:Publish("buff_applied", { name = buffName, spellID = spellID })
	return true
end

function InfinityConsumables:RecordBuffExpired(spellID)
	if self.buffs[spellID] then
		InfinityMessaging:Publish("buff_expired", { name = self.buffs[spellID].name, spellID = spellID })
		self.buffs[spellID] = nil
		return true
	end
	return false
end

function InfinityConsumables:GetActiveBuffs()
	local result = {}
	local now = InfinityUtils:GetTimeStamp()
	
	for spellID, buff in pairs(self.buffs) do
		if buff.expiresAt > now then
			table.insert(result, buff)
		else
			self.buffs[spellID] = nil
		end
	end
	
	return result
end

function InfinityConsumables:GetActiveBufcfs()
	return self:GetActiveBuffs()
end

function InfinityConsumables:GetBuffDuration(spellID)
	if self.buffs[spellID] then
		local remaining = self.buffs[spellID].expiresAt - InfinityUtils:GetTimeStamp()
		return math.max(0, remaining)
	end
	return 0
end

function InfinityConsumables:GetBuffStatus()
	local status = {
		activeBuffs = 0,
		consumablesInInventory = 0,
		buffs = {},
		consumables = {},
	}
	
	status.activeBuffs = #self:GetActiveBufcfs()
	
	for _, consumable in ipairs(self:GetAllConsumables()) do
		status.consumablesInInventory = status.consumablesInInventory + consumable.count
		table.insert(status.consumables, consumable)
	end
	
	for spellID, buff in pairs(self.buffs) do
		table.insert(status.buffs, buff)
	end
	
	return status
end

return InfinityConsumables
