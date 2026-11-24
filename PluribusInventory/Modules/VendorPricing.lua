-- Vendor Pricing Module
local PluribusVendorPricing = {}
_G.PluribusVendorPricing = PluribusVendorPricing

PluribusVendorPricing.vendorPrices = {} -- {itemId = price}
PluribusVendorPricing.auctionPrices = {} -- {itemId = {min, avg, max}}
PluribusVendorPricing.tsm_available = _G.TSM_API ~= nil
PluribusVendorPricing.auctionator_available = _G.Auctionator ~= nil

function PluribusVendorPricing:Initialize()
	self.tsm_available = _G.TSM_API ~= nil
	self.auctionator_available = _G.Auctionator ~= nil
	PluribusUtils:Info("Vendor pricing initialized. TSM: " .. tostring(self.tsm_available) .. ", Auctionator: " .. tostring(self.auctionator_available), "Inventory")
end

function PluribusVendorPricing:GetVendorPrice(itemId)
	local name, link, quality, ilvl, _, _, _, _, _, _, sellPrice = PluribusUtils:GetItemInfo(itemId)
	return sellPrice or 0
end

function PluribusVendorPricing:GetAuctionPrice(itemId, link)
	if self.auctionator_available and Auctionator and Auctionator.API and Auctionator.API.v1 then
		local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, "PluribusInventory", link)
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

local function SafeGetContainerItemLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	elseif GetContainerItemLink then
		return GetContainerItemLink(bag, slot)
	end
	return nil
end

function PluribusVendorPricing:CalculateBagValue()
	local total = 0
	PluribusBagTracker:ScanBags()
	
	for bag, slots in pairs(PluribusBagTracker.bagContents) do
		for slot, item in pairs(slots) do
			local price = self:GetAuctionPrice(item.itemId, SafeGetContainerItemLink(bag, slot))
			total = total + (price * item.quantity)
		end
	end
	
	return total
end

return PluribusVendorPricing
