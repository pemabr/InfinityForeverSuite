-- Crafting Integration Module
local PluribusCraftingIntegration = {}
_G.PluribusCraftingIntegration = PluribusCraftingIntegration

PluribusCraftingIntegration.recipes = {}
PluribusCraftingIntegration.skillLevels = {}

function PluribusCraftingIntegration:Initialize()
	PluribusUtils:Info("Crafting integration initialized", "Inventory")
end

function PluribusCraftingIntegration:RegisterRecipe(professionId, recipeId, recipeName, materials)
	if not self.recipes[professionId] then
		self.recipes[professionId] = {}
	end
	
	self.recipes[professionId][recipeId] = {
		name = recipeName,
		materials = materials,
	}
end

function PluribusCraftingIntegration:GetRecipesByProfession(professionId)
	return self.recipes[professionId] or {}
end

function PluribusCraftingIntegration:CanCraftRecipe(professionId, recipeId)
	local recipe = self.recipes[professionId] and self.recipes[professionId][recipeId]
	if not recipe then
		return false
	end
	
	-- Check if player has materials
	for itemId, needed in pairs(recipe.materials) do
		local have = PluribusBagTracker:GetItemCount(itemId)
		if have < needed then
			return false
		end
	end
	
	return true
end

return PluribusCraftingIntegration
