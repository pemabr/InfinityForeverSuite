-- Item Tracking Module
local InfinityItemTracking = {}
_G.InfinityItemTracking = InfinityItemTracking

InfinityItemTracking.itemCache = {} -- {itemId = {name, rarity, quality, count}}
InfinityItemTracking.itemAliases = {} -- {searchName = itemId}

function InfinityItemTracking:Initialize()
	InfinityUtils:Info("Item tracking initialized", "Inventory")
end

function InfinityItemTracking:TrackItem(itemId, itemName, rarity)
	self.itemCache[itemId] = {
		name = itemName,
		rarity = rarity,
		count = 0,
	}
	
	-- Add aliases for searching
	if itemName then
		self.itemAliases[string.lower(itemName)] = itemId
	end
end

function InfinityItemTracking:GetItemInfo(itemId)
	return self.itemCache[itemId]
end

function InfinityItemTracking:FindItemByName(name)
	local searchName = string.lower(name)
	return self.itemAliases[searchName]
end

function InfinityItemTracking:UpdateItemCount(itemId, newCount)
	if self.itemCache[itemId] then
		self.itemCache[itemId].count = newCount
	end
end

function InfinityItemTracking:GetAllTrackedItems()
	return self.itemCache
end

return InfinityItemTracking
