-- Crafting Integration Module
local InfinityCraftingIntegration = {}
_G.InfinityCraftingIntegration = InfinityCraftingIntegration

InfinityCraftingIntegration.recipes = {}
InfinityCraftingIntegration.skillLevels = {}

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
		if have < needed then
			return false
		end
	end
	
	return true
end

return InfinityCraftingIntegration
