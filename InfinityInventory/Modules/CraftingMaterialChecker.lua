-- Crafting Material Checker
-- Tracks crafting materials and suggests when to farm or prioritize crafting

local CraftingMaterialChecker = {
	materials = {}, -- {materialId = {name, quantity, sources}}
	professions = {}, -- {professionId = {name, level, maxLevel}}
	
	config = {
		trackMaterials = true,
		notifyLowStock = true,
		lowStockThreshold = 10, -- items
		priorityMaterials = {}, -- High priority materials to track
	},
	
	stats = {
		totalMaterials = 0,
		uniqueMaterials = 0,
		lastUpdated = 0,
	},
}

_G.InfinityInfinityCraftingMaterialChecker = CraftingMaterialChecker

-- Initialize crafting material checker
function CraftingMaterialChecker:Initialize()
	InfinityUtils:Info("Crafting material checker initialized", "Inventory")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	frame:RegisterEvent("BAG_UPDATE")
	frame:RegisterEvent("SKILL_LEVEL_CHANGED")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "UNIT_INVENTORY_CHANGED" or event == "BAG_UPDATE" then
			CraftingMaterialChecker:ScanMaterials()
		elseif event == "SKILL_LEVEL_CHANGED" then
			CraftingMaterialChecker:ScanProfessions()
		end
	end)
	
	-- Enable periodic scans
	C_Timer.NewTicker(30, function()
		CraftingMaterialChecker:ScanMaterials()
	end)
	
	-- Initial scan
	C_Timer.After(2, function()
		CraftingMaterialChecker:ScanProfessions()
		CraftingMaterialChecker:ScanMaterials()
	end)
end

-- Scan professions
function CraftingMaterialChecker:ScanProfessions()
	self.professions = {}
	local knownProfs = {
		alchemy = true, blacksmithing = true, enchanting = true, engineering = true,
		herbalism = true, leatherworking = true, mining = true, skinning = true,
		tailoring = true, cooking = true, ["first aid"] = true, fishing = true,
	}
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
			if name and not isHeader and knownProfs[name:lower()] then
				self.professions[name] = { name = name, rank = rank or 0, maxRank = maxRank or 300 }
			end
		end
	end
end

-- Scan for crafting materials
function CraftingMaterialChecker:ScanMaterials()
	local newMaterials = {}
	local totalQuantity = 0
	
	-- Common crafting materials
	local commonMaterials = {
		-- Ore
		{id = 2770, name = "Copper Ore"},
		{id = 3576, name = "Tin Ore"},
		{id = 7912, name = "Iron Ore"},
		{id = 11370, name = "Thorium Ore"},
		
		-- Herbs
		{id = 2447, name = "Peacebloom"},
		{id = 2449, name = "Silverleaf"},
		{id = 3355, name = "Grave Moss"},
		{id = 3357, name = "Swiftthistle"},
		
		-- Cloth
		{id = 1200, name = "Linen Cloth"},
		{id = 2592, name = "Wool Cloth"},
		{id = 4306, name = "Mageweave Cloth"},
		{id = 14047, name = "Runecloth"},
		
		-- Leather
		{id = 2318, name = "Leather"},
		{id = 4304, name = "Thick Leather"},
		{id = 8169, name = "Rune Leather"},
	}
	
	-- Scan bags for materials
	for _, material in ipairs(commonMaterials) do
		local quantity = InfinityUtils:GetItemCount(material.id)
		
		if quantity > 0 then
			newMaterials[material.id] = {
				name = material.name,
				id = material.id,
				quantity = quantity,
				inStock = quantity >= self.config.lowStockThreshold,
			}
			
			totalQuantity = totalQuantity + quantity
			
			-- Check for low stock
			if quantity < self.config.lowStockThreshold and self.config.notifyLowStock then
				self:OnLowStock(material.id, material.name, quantity)
			end
		end
	end
	
	self.materials = newMaterials
	self.stats.totalMaterials = totalQuantity
	self.stats.uniqueMaterials = InfinityUtils:TableSize(newMaterials)
	self.stats.lastUpdated = GetTime()
	
	InfinityMessaging:Publish("crafting_materials_updated", newMaterials)
end

-- Called when material is low
function CraftingMaterialChecker:OnLowStock(materialId, materialName, quantity)
	InfinityUtils:Warning("Low stock: " .. materialName .. " (" .. quantity .. ")", "Inventory")
	InfinityMessaging:Publish("low_material_stock", materialId, materialName, quantity)
end

-- Get all materials
function CraftingMaterialChecker:GetMaterials()
	return self.materials
end

-- Get specific material
function CraftingMaterialChecker:GetMaterial(materialId)
	return self.materials[materialId]
end

-- Get materials by category
function CraftingMaterialChecker:GetMaterialsByCategory(category)
	local materials = {}
	
	for _, material in pairs(self.materials) do
		if material.category == category then
			table.insert(materials, material)
		end
	end
	
	return materials
end

-- Get materials needing farming
function CraftingMaterialChecker:GetMaterialsNeedingFarming()
	local farmNeeded = {}
	
	for _, material in pairs(self.materials) do
		if not material.inStock then
			table.insert(farmNeeded, material)
		end
	end
	
	return farmNeeded
end

-- Get total material value
function CraftingMaterialChecker:GetMaterialValue()
	local totalValue = 0
	
	for _, material in pairs(self.materials) do
		local itemValue = select(11, InfinityUtils:GetItemInfo(material.id)) or 0
		totalValue = totalValue + (itemValue * material.quantity)
	end
	
	return totalValue
end

-- Set low stock threshold
function CraftingMaterialChecker:SetLowStockThreshold(threshold)
	self.config.lowStockThreshold = threshold
	InfinityUtils:Info("Low stock threshold set to " .. threshold, "Inventory")
end

-- Display material status
function CraftingMaterialChecker:DisplayStatus()
	print("|cffffd700=== CRAFTING MATERIAL STATUS ===|r")
	print("Total Materials: " .. self.stats.totalMaterials)
	print("Unique Materials: " .. self.stats.uniqueMaterials)
	print("Total Value: " .. InfinityUtils:FormatNumber(self:GetMaterialValue()) .. " gold")
	
	local farmNeeded = self:GetMaterialsNeedingFarming()
	if #farmNeeded > 0 then
		print("\n|cffff0000Materials Needing Farming:|r")
		for _, material in ipairs(farmNeeded) do
			print("  " .. material.name .. ": " .. material.quantity .. " (threshold: " .. self.config.lowStockThreshold .. ")")
		end
	else
		print("\n|cff00ff00All materials well-stocked|r")
	end
end

return CraftingMaterialChecker
