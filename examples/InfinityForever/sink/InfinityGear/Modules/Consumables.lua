-- InfinityGearConsumables Module
-- Manages consumables and buff management

InfinityGearConsumables = {}
InfinityGearConsumables.consumables = {}
InfinityGearConsumables.buffs = {}

function InfinityGearConsumables:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGear", "consumables", {})
	self.consumables = storageData.consumables or {}
	self.buffs = storageData.buffs or {}
	InfinityUtils:Info("GearConsumables module initialized", "InfinityGear")
end

function InfinityGearConsumables:RecordConsumable(consumableName, consumableType, quantity, duration)
	local consumableId = "cons_" .. InfinityUtils:GetTimeStamp()
	
	local consumable = {
		id = consumableId,
		name = consumableName,
		type = consumableType or "FOOD",
		quantity = quantity or 1,
		duration = duration or 3600,
		recorded = InfinityUtils:GetTimeStamp(),
		active = false,
	}
	
	self.consumables[consumableId] = consumable
	self:SaveConsumables()
	InfinityMessaging:Publish("consumable_recorded", { consumable = consumableName })
	
	return consumable
end

function InfinityGearConsumables:ActivateBuffConsumable(consumableId)
	if not self.consumables[consumableId] then return nil end
	
	self.consumables[consumableId].active = true
	self.consumables[consumableId].activatedTime = InfinityUtils:GetTimeStamp()
	
	-- Record buff
	local buff = {
		consumable = self.consumables[consumableId].name,
		startTime = InfinityUtils:GetTimeStamp(),
		endTime = InfinityUtils:GetTimeStamp() + (self.consumables[consumableId].duration or 3600),
	}
	table.insert(self.buffs, buff)
	
	self:SaveConsumables()
	InfinityMessaging:Publish("buff_activated", { buff = buff.consumable })
	
	return buff
end

function InfinityGearConsumables:GetActiveBuffs()
	local now = InfinityUtils:GetTimeStamp()
	local active = {}
	
	for _, buff in ipairs(self.buffs) do
		if buff.endTime and buff.endTime > now then
			table.insert(active, buff)
		end
	end
	
	return active
end

function InfinityGearConsumables:SaveConsumables()
	InfinityStorageManager:SetFeatureSetting("InfinityGear", "consumables", {
		consumables = self.consumables,
		buffs = self.buffs,
	})
	InfinityDataManager:UpdateSourceData("InfinityGear", "consumables", {
		consumables = self.consumables,
		buffs = self.buffs,
	})
end

return InfinityGearConsumables
