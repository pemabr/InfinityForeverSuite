-- PluribusGearConsumables Module
-- Manages consumables and buff management

PluribusGearConsumables = {}
PluribusGearConsumables.consumables = {}
PluribusGearConsumables.buffs = {}

function PluribusGearConsumables:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGear", "consumables", {})
	self.consumables = storageData.consumables or {}
	self.buffs = storageData.buffs or {}
	PluribusUtils:Info("GearConsumables module initialized", "PluribusGear")
end

function PluribusGearConsumables:RecordConsumable(consumableName, consumableType, quantity, duration)
	local consumableId = "cons_" .. PluribusUtils:GetTimeStamp()
	
	local consumable = {
		id = consumableId,
		name = consumableName,
		type = consumableType or "FOOD",
		quantity = quantity or 1,
		duration = duration or 3600,
		recorded = PluribusUtils:GetTimeStamp(),
		active = false,
	}
	
	self.consumables[consumableId] = consumable
	self:SaveConsumables()
	PluribusMessaging:Publish("consumable_recorded", { consumable = consumableName })
	
	return consumable
end

function PluribusGearConsumables:ActivateBuffConsumable(consumableId)
	if not self.consumables[consumableId] then return nil end
	
	self.consumables[consumableId].active = true
	self.consumables[consumableId].activatedTime = PluribusUtils:GetTimeStamp()
	
	-- Record buff
	local buff = {
		consumable = self.consumables[consumableId].name,
		startTime = PluribusUtils:GetTimeStamp(),
		endTime = PluribusUtils:GetTimeStamp() + (self.consumables[consumableId].duration or 3600),
	}
	table.insert(self.buffs, buff)
	
	self:SaveConsumables()
	PluribusMessaging:Publish("buff_activated", { buff = buff.consumable })
	
	return buff
end

function PluribusGearConsumables:GetActiveBuffs()
	local now = PluribusUtils:GetTimeStamp()
	local active = {}
	
	for _, buff in ipairs(self.buffs) do
		if buff.endTime and buff.endTime > now then
			table.insert(active, buff)
		end
	end
	
	return active
end

function PluribusGearConsumables:SaveConsumables()
	PluribusStorageManager:SetFeatureSetting("PluribusGear", "consumables", {
		consumables = self.consumables,
		buffs = self.buffs,
	})
	PluribusDataManager:UpdateSourceData("PluribusGear", "consumables", {
		consumables = self.consumables,
		buffs = self.buffs,
	})
end

return PluribusGearConsumables
