-- Finanzamt – Item-Tooltips: absetzbar? Marktwert für die Gildenbank?
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF

local SOURCE_SHORT = { auc = "Auctionator", scan = "AH-Scan", vendor = "Händlerpreis", manual = "festgesetzt" }

function GS:AddTooltipInfo(tooltip, itemID)
	if not tooltip or not itemID or itemID == 0 then return end
	if not self.db or self.db.tooltipInfo == false or not self:G() then return end
	-- pro Anzeige nur einmal ergänzen
	if tooltip.finanzamtItem == itemID then return end
	tooltip.finanzamtItem = itemID
	local added = false
	if self:IsDeductible(itemID) then
		tooltip:AddLine(L["Finanzamt: absetzbar (Werbungskosten)"], 0.25, 1, 0.25)
		added = true
	end
	local price, src = self:GetUnitPrice(itemID)
	if price and price > 0 then
		local coin = self.CoinText and self.CoinText(price) or self:FormatMoney(price)
		tooltip:AddDoubleLine(L["Finanzamt: Marktwert (Gildenbank)"], coin .. " |cffaaaaaa" .. L[SOURCE_SHORT[src] or ""] .. "|r",
			1, 0.82, 0, 1, 1, 1)
		added = true
	end
	if added and tooltip.Show then tooltip:Show() end
end

local function itemIDFromTooltip(tooltip)
	if not tooltip.GetItem then return nil end
	local _, link = tooltip:GetItem()
	return link and tonumber(link:match("item:(%d+)"))
end

local function hookClassic(tooltip)
	if not tooltip or not tooltip.HookScript or tooltip.finanzamtHooked then return end
	tooltip.finanzamtHooked = true
	pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(t)
		GS:AddTooltipInfo(t, itemIDFromTooltip(t))
	end)
	pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(t) t.finanzamtItem = nil end)
end

local function setup()
	-- neue Tooltip-Schnittstelle (neuere Clients, auch WoW Forever)
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
			local id = data and data.id
			if not id then id = itemIDFromTooltip(tooltip) end
			GS:AddTooltipInfo(tooltip, id)
		end)
		for _, t in ipairs({ GameTooltip, ItemRefTooltip }) do
			if t and t.HookScript and not t.finanzamtCleared then
				t.finanzamtCleared = true
				pcall(t.HookScript, t, "OnTooltipCleared", function(tt) tt.finanzamtItem = nil end)
			end
		end
		return
	end
	-- klassische Tooltips
	hookClassic(GameTooltip)
	hookClassic(ItemRefTooltip)
	hookClassic(_G.ShoppingTooltip1)
	hookClassic(_G.ShoppingTooltip2)
end

GS:On("PLAYER_LOGIN", setup)
