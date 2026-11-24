-- Bag Tracker Module
local PluribusBagTracker = {}
_G.PluribusBagTracker = PluribusBagTracker

PluribusBagTracker.bagContents = {} -- {bagId = {slot = {itemId, quantity}}}
PluribusBagTracker.bagSpaces = {} -- {bagId = usedSlots}

local function SafeGetContainerNumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	elseif GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function SafeGetContainerItemID(bag, slot)
	if C_Container and C_Container.GetContainerItemID then
		return C_Container.GetContainerItemID(bag, slot)
	elseif GetContainerItemID then
		return GetContainerItemID(bag, slot)
	end
	return nil
end

local function SafeGetContainerItemCount(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if type(info) == "table" then
			return info.stackCount or 1
		end
	elseif GetContainerItemInfo then
		local _, count = GetContainerItemInfo(bag, slot)
		return count or 1
	end
	return 1
end

function PluribusBagTracker:Initialize()
	PluribusUtils:Info("Bag tracker initialized", "Inventory")
end

function PluribusBagTracker:ScanBags()
	for bag = 0, NUM_BAG_SLOTS or 4 do
		self.bagContents[bag] = {}
		
		for slot = 1, SafeGetContainerNumSlots(bag) do
			local itemId = SafeGetContainerItemID(bag, slot)
			if itemId then
				local quantity = SafeGetContainerItemCount(bag, slot)
				self.bagContents[bag][slot] = {
					itemId = itemId,
					quantity = quantity or 1,
				}
			end
		end
	end
	
	if PluribusMessaging and PluribusMessaging.Publish then
		PluribusMessaging:Publish("bags_scanned")
	end
end

function PluribusBagTracker:GetItemCount(itemId)
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

function PluribusBagTracker:GetFreeSlots()
	local free = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, SafeGetContainerNumSlots(bag) do
			if not self.bagContents[bag] or not self.bagContents[bag][slot] then
				free = free + 1
			end
		end
	end
	return free
end

return PluribusBagTracker
