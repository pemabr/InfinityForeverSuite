-- Crafting Integration Module
local InfinityCraftingIntegration = {}
_G.InfinityCraftingIntegration = InfinityCraftingIntegration

InfinityCraftingIntegration.recipes = {}
InfinityCraftingIntegration.skillLevels = {}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function PositiveInteger(value)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= 1000000000 and value == math.floor(value)
end

function InfinityCraftingIntegration:Initialize()
	InfinityUtils:Info("Crafting integration initialized", "Inventory")
end

function InfinityCraftingIntegration:RegisterRecipe(professionId, recipeId, recipeName, materials)
	if not self.recipes[professionId] then
		self.recipes[professionId] = {}
	end
	
	self.recipes[professionId][recipeId] = {
		name = recipeName,
		materials = materials,
	}
end

function InfinityCraftingIntegration:GetRecipesByProfession(professionId)
	return self.recipes[professionId] or {}
end

function InfinityCraftingIntegration:CanCraftRecipe(professionId, recipeId)
	local recipe = self.recipes[professionId] and self.recipes[professionId][recipeId]
	if not recipe then
		return false
	end
	
	-- Check if player has materials
	for itemId, needed in pairs(recipe.materials) do
		local have = InfinityBagTracker:GetItemCount(itemId)
		if have == nil then return nil end
		if have < needed then
			return false
		end
	end
	
	return true
end

function InfinityCraftingIntegration:GetBasicMaterials(recipeId, crafts)
	if not PositiveInteger(recipeId) or not PositiveInteger(crafts) then
		return nil, "Recipe ID and quantity must be positive integers."
	end
	local api = _G.C_TradeSkillUI
	local types = _G.Enum and _G.Enum.CraftingReagentType
	local basic = types and Public(types.Basic)
	if not api or not api.GetRecipeSchematic or type(basic) ~= "number" then
		return nil, "Profession schematic API unavailable."
	end
	local schematic = Public(api.GetRecipeSchematic(recipeId, false))
	if type(schematic) ~= "table" then return nil, "Recipe unavailable; open its profession first." end
	local slots = Public(schematic.reagentSlotSchematics)
	if type(slots) ~= "table" or #slots == 0 then return nil, "Recipe materials unavailable; open its profession first." end
	local needed = {}
	for _, slot in ipairs(slots) do
		slot = Public(slot)
		if type(slot) ~= "table" then return nil, "Recipe materials are protected or incomplete." end
		local kind = Public(slot.reagentType)
		if type(kind) ~= "number" then return nil, "Recipe material type unavailable." end
		if kind == basic then
			local choices, quantity = Public(slot.reagents), Public(slot.quantityRequired)
			if type(choices) ~= "table" or #choices ~= 1 then
				return nil, "Basic reagent choices require the profession window."
			end
			local reagent = Public(choices[1])
			local id = type(reagent) == "table" and Public(reagent.itemID)
			if not PositiveInteger(id) or not PositiveInteger(quantity) then
				return nil, "Recipe material details unavailable."
			end
			local total = (needed[id] or 0) + quantity * crafts
			if total > 1000000000 then return nil, "Recipe quantity is too large." end
			needed[id] = total
		end
	end
	local result = {}
	for id, amount in pairs(needed) do
		local count = InfinityBagTracker:GetItemCount(id)
		if not count then return nil, "Bag contents unavailable." end
		result[#result + 1] = { itemId = id, needed = amount, have = count, missing = math.max(0, amount - count) }
	end
	table.sort(result, function(a, b) return a.itemId < b.itemId end)
	return result
end

return InfinityCraftingIntegration
