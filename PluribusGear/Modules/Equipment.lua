-- PluribusGearEquipment Module
-- Manages gear tracking and optimization

PluribusGearEquipment = {}
PluribusGearEquipment.inventory = {}
PluribusGearEquipment.builds = {}

function PluribusGearEquipment:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGear", "equipment", {})
	self.inventory = storageData.inventory or {}
	self.builds = storageData.builds or {}
	PluribusUtils:Info("GearEquipment module initialized", "PluribusGear")
end

function PluribusGearEquipment:RecordItem(itemName, slot, rarity, stats)
	local itemId = "item_" .. PluribusUtils:GetTimeStamp()
	
	local item = {
		id = itemId,
		name = itemName,
		slot = slot or "MISC",
		rarity = rarity or "COMMON",
		stats = stats or {},
		obtained = PluribusUtils:GetTimeStamp(),
		equipped = false,
	}
	
	self.inventory[itemId] = item
	self:SaveEquipment()
	PluribusMessaging:Publish("item_recorded", { item = itemName, slot = slot })
	
	return item
end

function PluribusGearEquipment:EquipItem(itemId)
	if not self.inventory[itemId] then return nil end
	
	self.inventory[itemId].equipped = true
	self.inventory[itemId].equippedTime = PluribusUtils:GetTimeStamp()
	
	self:SaveEquipment()
	PluribusMessaging:Publish("item_equipped", { item = self.inventory[itemId].name })
	
	return self.inventory[itemId]
end

function PluribusGearEquipment:CreateBuild(buildName, buildType)
	local buildId = "build_" .. PluribusUtils:GetTimeStamp()
	
	local build = {
		id = buildId,
		name = buildName,
		type = buildType or "PvE",
		created = PluribusUtils:GetTimeStamp(),
		items = {},
		stats = {},
	}
	
	self.builds[buildId] = build
	self:SaveEquipment()
	
	return build
end

function PluribusGearEquipment:GetInventoryBySlot(slot)
	local result = {}
	for itemId, item in pairs(self.inventory) do
		if item.slot == slot then
			table.insert(result, item)
		end
	end
	return result
end

function PluribusGearEquipment:SaveEquipment()
	PluribusStorageManager:SetFeatureSetting("PluribusGear", "equipment", {
		inventory = self.inventory,
		builds = self.builds,
	})
	PluribusDataManager:UpdateSourceData("PluribusGear", "equipment", {
		inventory = self.inventory,
		builds = self.builds,
	})
end

return PluribusGearEquipment
