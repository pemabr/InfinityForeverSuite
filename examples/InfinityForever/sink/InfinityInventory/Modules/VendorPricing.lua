-- Vendor Pricing Module
local InfinityVendorPricing = {}
_G.InfinityVendorPricing = InfinityVendorPricing

InfinityVendorPricing.vendorPrices = {} -- {itemId = price}
InfinityVendorPricing.auctionPrices = {} -- {itemId = {min, avg, max}}
InfinityVendorPricing.tsm_available = _G.TSM_API ~= nil
InfinityVendorPricing.auctionator_available = _G.Auctionator ~= nil

function InfinityVendorPricing:Initialize()
	self.tsm_available = _G.TSM_API ~= nil
	self.auctionator_available = _G.Auctionator ~= nil
	InfinityUtils:Info("Vendor pricing initialized. TSM: " .. tostring(self.tsm_available) .. ", Auctionator: " .. tostring(self.auctionator_available), "Inventory")
end

function InfinityVendorPricing:GetVendorPrice(itemId)
	local name, link, quality, ilvl, _, _, _, _, _, _, sellPrice = GetItemInfo(itemId)
	return sellPrice or 0
end

function InfinityVendorPricing:GetAuctionPrice(itemId, link)
	if self.auctionator_available and Auctionator and Auctionator.API and Auctionator.API.v1 then
		local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, "InfinityInventory", link)
		if ok and price then
			return price
		end
	end
	
	if self.tsm_available and TSM_API then
		local ok, itemString = pcall(TSM_API.ToItemString, link)
		if ok and itemString then
			local ok2, value = pcall(TSM_API.GetCustomPriceValue, "DBMarket", itemString)
			if ok2 and value then
				return value
			end
		end
	end
	
	return self:GetVendorPrice(itemId)
end

function InfinityVendorPricing:CalculateBagValue()
	local total = 0
	InfinityBagTracker:ScanBags()
	
	for bag, slots in pairs(InfinityBagTracker.bagContents) do
		for slot, item in pairs(slots) do
			local price = self:GetAuctionPrice(item.itemId, GetContainerItemLink(bag, slot))
			total = total + (price * item.quantity)
		end
	end
	
	return total
end

return InfinityVendorPricing
