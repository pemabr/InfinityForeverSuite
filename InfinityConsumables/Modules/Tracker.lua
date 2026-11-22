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

function InfinityConsumables:ScanInventory()
	self.inventory = {}
	
	for bag = 0, 4 do
		for slot = 1, InfinityUtils:GetBagSlots(bag) do
			local itemID = InfinityUtils:GetBagItemID(bag, slot)
			if itemID then
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType = InfinityUtils:GetItemInfo(itemID)
				local _, itemCount = InfinityUtils:GetBagItemInfo(bag, slot)
				
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

function InfinityConsumables:ScanPlayerBuffs()
	local active = {}
	local now = InfinityUtils:GetTimeStamp()
	local isSec = _G.issecretvalue
	local idx = 1
	while true do
		local name, spellId, duration, expirationTime
		if _G.C_UnitAuras and _G.C_UnitAuras.GetBuffDataByIndex then
			local aura = _G.C_UnitAuras.GetBuffDataByIndex("player", idx)
			if not aura then break end
			name = aura.name
			spellId = aura.spellId
			duration = aura.duration
			expirationTime = aura.expirationTime
		elseif _G.UnitBuff then
			local n, _, _, _, dur, exp, _, _, _, sid = _G.UnitBuff("player", idx)
			if not n then break end
			name, duration, expirationTime, spellId = n, dur, exp, sid
		else
			break
		end
		if name and spellId and not (isSec and (isSec(name) or isSec(spellId))) then
			local rem = (expirationTime and not (isSec and isSec(expirationTime)) and expirationTime > 0) and math.max(0, expirationTime - GetTime()) or 0
			active[spellId] = {
				name = name,
				spellID = spellId,
				appliedTime = now,
				duration = (duration and not (isSec and isSec(duration))) and duration or 0,
				expiresAt = now + rem,
			}
		end
		idx = idx + 1
	end
	for k, v in pairs(active) do
		self.buffs[k] = v
	end
	return active
end

function InfinityConsumables:GetActiveBuffs()
	self:ScanPlayerBuffs()
	local result = {}
	local now = InfinityUtils:GetTimeStamp()
	
	for spellID, buff in pairs(self.buffs) do
		if buff.expiresAt >= now or buff.duration == 0 then
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
	
	status.activeBuffs = #self:GetActiveBuffs()
	
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
