-- Tooltip Price Information System
-- Displays locally configured item prices on tooltips.

local TooltipPrices = {
	config = {
		enableTooltipPrices = true,
		showBasellePrice = true,
		priceColor = "|cffffd700", -- Gold color
		tooltipPosition = "right", -- right, left, bottom
	},
	
	itemPriceCache = {}, -- {itemID = {base = n, ascending = n, lastUpdate = time}}
}

_G.InfinityTooltipPrices = TooltipPrices

function TooltipPrices:Initialize()
	InfinityUtils:Info("Tooltip Prices system initialized", "Loot")
	if self.hooked then return end
	local hooked = false
	
	-- Hook tooltips (Forever 1.60.1 TooltipDataProcessor + legacy fallback)
	if _G.TooltipDataProcessor and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function" and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item then
		local ok, err = pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Item, function(tooltip, data)
			TooltipPrices:OnTooltipSetItem(tooltip, data)
		end)
		if ok and not (issecretvalue and issecretvalue(err)) and err ~= false then hooked = true
		else
			if issecretvalue and issecretvalue(err) then err = nil end
			InfinityUtils:Warning("Loot tooltip registration failed: " .. tostring(err or "protected error"), "Loot")
		end
	else
		if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
			GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
				TooltipPrices:OnTooltipSetItem(tooltip)
			end)
			hooked = true
		end
		if ItemRefTooltip and ItemRefTooltip.HasScript and ItemRefTooltip:HasScript("OnTooltipSetItem") then
			ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
				TooltipPrices:OnTooltipSetItem(tooltip)
			end)
			hooked = true
		end
	end
	self.hooked = hooked
	if not hooked then InfinityUtils:Warning("Loot item tooltip hooks unavailable.", "Loot") end
end

function TooltipPrices:OnTooltipSetItem(tooltip, data)
	if not self.config.enableTooltipPrices or not tooltip then return end
	if InfinitySettingsPanel and InfinitySettingsPanel:GetSetting("General", "Enable Tooltips") == false then return end
	local forbidden = tooltip.IsForbidden and tooltip:IsForbidden()
	if (issecretvalue and issecretvalue(forbidden)) or forbidden then return end
	
	if (issecretvalue and issecretvalue(data)) or type(data) ~= "table" then data = nil end
	local itemID = data and data.id
	if (issecretvalue and issecretvalue(itemID)) or type(itemID) ~= "number" or itemID ~= itemID
		or itemID <= 0 or itemID > 1000000000 or itemID ~= math.floor(itemID) then itemID = nil end
	if not itemID and tooltip.GetItem then
		local ok, _, link = pcall(tooltip.GetItem, tooltip)
		if ok then itemID = self:ExtractItemID(link)
		elseif not self.warnedRead then
			self.warnedRead = true
			InfinityUtils:Warning("Loot tooltip item information is unavailable.", "Loot")
		end
	end
	if not itemID and data then
		itemID = self:ExtractItemID(data.hyperlink)
	end
	if not itemID then return end
	
	-- Get price info
	local priceInfo = self:GetItemPriceInfo(itemID)
	if not priceInfo then return end
	
	-- Add tooltip lines
	self:AddPriceLinesToTooltip(tooltip, itemID, priceInfo)
end

function TooltipPrices:ExtractItemID(link)
	-- Extract from |cff9d9d9d|Hitem:12345:0:0:0:0:0:0:0:85:0|h[Item Name]|h|r
	if (issecretvalue and issecretvalue(link)) or type(link) ~= "string" then return nil end
	
	local itemID = link:match("item:(%d+)")
	itemID = tonumber(itemID)
	if itemID and itemID > 0 and itemID <= 1000000000 then return itemID end
end

function TooltipPrices:GetItemPriceInfo(itemID)
	local economy = _G.InfinityLootAdvancedEconomy
	local prices = economy and economy.initialized and economy.itemPrices
	if (issecretvalue and issecretvalue(prices)) or type(prices) ~= "table" then return nil end
	local price = prices[itemID]
	if (issecretvalue and issecretvalue(price)) or type(price) ~= "table"
		or (issecretvalue and issecretvalue(price.basePrice)) or type(price.basePrice) ~= "number"
		or price.basePrice ~= price.basePrice or price.basePrice < 0 or price.basePrice > 1000000000 then return nil end
	return { base = price.basePrice }
end

function TooltipPrices:AddPriceLinesToTooltip(tooltip, itemID, priceInfo)
	if self.config.showBasellePrice then
		tooltip:AddLine(" ")
		tooltip:AddLine(self.config.priceColor .. "Local configured price: " .. priceInfo.base .. " GP|r")
	end
end

function TooltipPrices:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Tooltip Prices config updated: " .. key .. " = " .. tostring(value), "Loot")
	end
end

function TooltipPrices:ClearCache()
	self.itemPriceCache = {}
	InfinityUtils:Info("Tooltip price cache cleared", "Loot")
end

function TooltipPrices:PrintConfig()
	print("|cffffd700=== Tooltip Prices Configuration ===|r")
	print("Enable Tooltip Prices: " .. tostring(self.config.enableTooltipPrices))
	print("Show Base Price: " .. tostring(self.config.showBasellePrice))
	print("Color: " .. self.config.priceColor .. "Gold|r")
	print("Position: " .. self.config.tooltipPosition)
end

return TooltipPrices
