-- Bag Tracker Module
local InfinityBagTracker = {}
_G.InfinityBagTracker = InfinityBagTracker

InfinityBagTracker.bagContents = {} -- {bagId = {slot = {itemId, quantity}}}
InfinityBagTracker.bagSpaces = {} -- {bagId = usedSlots}

function InfinityBagTracker:Initialize()
	InfinityUtils:Info("Bag tracker initialized", "Inventory")
end

function InfinityBagTracker:ScanBags()
	for bag = 0, NUM_BAG_SLOTS or 4 do
		if not self.bagContents[bag] then
			self.bagContents[bag] = {}
		end
		
		for slot = 1, InfinityUtils:GetBagSlots(bag) do
			local itemId = InfinityUtils:GetBagItemID(bag, slot)
			local _, quantity = InfinityUtils:GetBagItemInfo(bag, slot)
			
			if itemId then
				self.bagContents[bag][slot] = {
					itemId = itemId,
					quantity = quantity or 1,
				}
			end
		end
	end
	
	InfinityMessaging:Publish("bags_scanned")
end

function InfinityBagTracker:GetItemCount(itemId)
	local total = 0
	for bag, slots in pairs(self.bagContents) do
		for slot, item in pairs(slots) do
			if item.itemId == itemId then
				total = total + item.quantity
			end
		end
	end
	return total
end

function InfinityBagTracker:GetFreeSlots()
	local free = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, InfinityUtils:GetBagSlots(bag) do
			if not self.bagContents[bag] or not self.bagContents[bag][slot] then
				free = free + 1
			end
		end
	end
	return free
end

return InfinityBagTracker
