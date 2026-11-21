-- InfinityGearEquipment Module
-- Manages gear tracking and optimization

InfinityGearEquipment = {}
InfinityGearEquipment.inventory = {}
InfinityGearEquipment.builds = {}

function InfinityGearEquipment:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGear", "equipment", {})
	self.inventory = storageData.inventory or {}
	self.builds = storageData.builds or {}
	InfinityUtils:Info("GearEquipment module initialized", "InfinityGear")
end

function InfinityGearEquipment:RecordItem(itemName, slot, rarity, stats)
	local itemId = "item_" .. InfinityUtils:GetTimeStamp()
	
	local item = {
		id = itemId,
		name = itemName,
		slot = slot or "MISC",
		rarity = rarity or "COMMON",
		stats = stats or {},
		obtained = InfinityUtils:GetTimeStamp(),
		equipped = false,
	}
	
	self.inventory[itemId] = item
	self:SaveEquipment()
	InfinityMessaging:Publish("item_recorded", { item = itemName, slot = slot })
	
	return item
end

function InfinityGearEquipment:EquipItem(itemId)
	if not self.inventory[itemId] then return nil end
	
	self.inventory[itemId].equipped = true
	self.inventory[itemId].equippedTime = InfinityUtils:GetTimeStamp()
	
	self:SaveEquipment()
	InfinityMessaging:Publish("item_equipped", { item = self.inventory[itemId].name })
	
	return self.inventory[itemId]
end

function InfinityGearEquipment:CreateBuild(buildName, buildType)
	local buildId = "build_" .. InfinityUtils:GetTimeStamp()
	
	local build = {
		id = buildId,
		name = buildName,
		type = buildType or "PvE",
		created = InfinityUtils:GetTimeStamp(),
		items = {},
		stats = {},
	}
	
	self.builds[buildId] = build
	self:SaveEquipment()
	
	return build
end

function InfinityGearEquipment:GetInventoryBySlot(slot)
	local result = {}
	for itemId, item in pairs(self.inventory) do
		if item.slot == slot then
			table.insert(result, item)
		end
	end
	return result
end

function InfinityGearEquipment:SaveEquipment()
	InfinityStorageManager:SetFeatureSetting("InfinityGear", "equipment", {
		inventory = self.inventory,
		builds = self.builds,
	})
	InfinityDataManager:UpdateSourceData("InfinityGear", "equipment", {
		inventory = self.inventory,
		builds = self.builds,
	})
end

return InfinityGearEquipment
