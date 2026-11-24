-- InfinityHive Item Tooltips Integration
-- Native 1.60.1 TooltipDataProcessor + GameTooltip fallback (zero duplicate lines, clean & compact)
-- Displays: You/Alts/Guild Bag+Bank counts, Guild Profession Needs (highlighting YOUR surplus!),
-- Guild-synced AH Market Price, and Wowhead / Guild P2P Game Data source

InfinityHiveTooltips = {
	initialized = false,
}
_G.InfinityHiveTooltips = InfinityHiveTooltips

local function FormatAge(ts)
	if not ts or ts <= 0 then return "" end
	local diff = math.max(0, time() - ts)
	if diff < 60 then return "now"
	elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
	elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
	else return math.floor(diff / 86400) .. "d ago" end
end

function InfinityHiveTooltips:EnrichItemTooltip(tooltip, itemID)
	if not tooltip or not itemID or itemID <= 0 then return end
	local cfg = InfinityHive:GetConfig()
	if not cfg.showTooltips then return end

	-- Prevent duplicate injection if both TooltipDataProcessor and OnTooltipSetItem fire
	local stamp = tostring(itemID) .. ":" .. tostring(tooltip:NumLines() or 0)
	if tooltip._infHiveStamp == stamp then
		return
	end

	local lines = {}

	-- 1. You / Alts / Guild Bag + Bank Counts
	if cfg.showTooltipCounts and _G.InfinityHiveInventory then
		local c = _G.InfinityHiveInventory:GetItemCounts(itemID)
		if c then
			local myTotal = (c.selfBags or 0) + (c.selfBank or 0)
			local segs = {}
			if myTotal > 0 then
				if (c.selfBank or 0) > 0 then
					table.insert(segs, string.format("You: %d (%d bag, %d bank)", myTotal, c.selfBags, c.selfBank))
				else
					table.insert(segs, string.format("You: %d", myTotal))
				end
			end
			if (c.totalAlts or 0) > 0 then
				local altNames = {}
				for i, a in ipairs(c.alts) do
					if i <= 2 then table.insert(altNames, a.name .. "(" .. a.total .. ")") end
				end
				if #c.alts > 2 then table.insert(altNames, "+" .. (#c.alts - 2)) end
				table.insert(segs, "Alts: " .. table.concat(altNames, ", "))
			end
			if (c.totalGuild or 0) > 0 then
				local gNames = {}
				for i, g in ipairs(c.guild) do
					if i <= 2 then table.insert(gNames, g.name .. "(" .. g.total .. ")") end
				end
				if #c.guild > 2 then table.insert(gNames, "+" .. (#c.guild - 2)) end
				table.insert(segs, "Guild: " .. table.concat(gNames, ", "))
			end
			if #segs > 0 then
				table.insert(lines, {
					left = "|cff38bdf8Hive Bags:|r",
					right = "|cffe2e8f0" .. table.concat(segs, "  ·  ") .. "|r",
				})
			end
		end
	end

	-- 2. Guild Profession Needs (with emerald highlight when YOU don't need it!)
	if cfg.showTooltipProfNeeds and _G.InfinityHiveProfessions then
		local neededBy, isSurplus = _G.InfinityHiveProfessions:GetGuildNeedsForItem(itemID)
		if #neededBy > 0 then
			local who = {}
			for i, n in ipairs(neededBy) do
				if i <= 2 then
					local lvlPart = (n.level and n.level > 0) and (" " .. n.level) or ""
					table.insert(who, string.format("%s (%s%s)", n.name, n.prof, lvlPart))
				end
			end
			if #neededBy > 2 then
				table.insert(who, "+" .. (#neededBy - 2) .. " more")
			end
			if isSurplus then
				table.insert(lines, {
					left = "|cff4ade80Guild Needs (Surplus!):|r",
					right = "|cffbbf7d0" .. table.concat(who, ", ") .. "|r",
				})
			else
				table.insert(lines, {
					left = "|cff93c5fdGuild Also Needs:|r",
					right = "|cffcbd5e1" .. table.concat(who, ", ") .. "|r",
				})
			end
		end
	end

	-- 3. Guild-Synced AH Market Price
	if cfg.showTooltipPrices and _G.InfinityHiveAuction then
		local price = _G.InfinityHiveAuction:GetPrice(itemID)
		if price and price.copper and price.copper > 0 then
			local age = FormatAge(price.seenAt)
			table.insert(lines, {
				left = "|cfffbbf24Guild AH Price:|r",
				right = "|cfffef08a" .. InfinityUtils:FormatGold(price.copper) .. "|r |cff94a3b8(" .. age .. ")|r",
			})
		end
	end

	-- 4. Wowhead / Guild P2P Network Game Data (on-demand P2P lookup on miss)
	if cfg.showTooltipGameDB and _G.InfinityHiveNetworkDB then
		local entry = _G.InfinityHiveNetworkDB:GetItem(itemID)
		if entry and entry.source and entry.source ~= "" then
			table.insert(lines, {
				left = "|cff94a3b8Hive DB:|r",
				right = "|cffcbd5e1" .. entry.source:sub(1, 56) .. "|r",
			})
		else
			-- Silently ask guild peers if anyone already has this item's Wowhead data
			_G.InfinityHiveNetworkDB:RequestItem(itemID)
		end
	end

	if #lines == 0 then return end

	tooltip:AddLine(" ")
	for _, ln in ipairs(lines) do
		tooltip:AddDoubleLine(ln.left, ln.right, 1, 1, 1, 1, 1, 1)
	end
	tooltip._infHiveStamp = tostring(itemID) .. ":" .. tostring(tooltip:NumLines() or 0)
	tooltip:Show()
end

function InfinityHiveTooltips:Initialize()
	if self.initialized then return end
	self.initialized = true

	-- Modern 1.60.1 / 12.x TooltipDataProcessor hook
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		pcall(function()
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
				if not tooltip or not data then return end
				local itemID = data.id
				if not itemID and tooltip.GetItem then
					local _, link = tooltip:GetItem()
					itemID = link and InfinityUtils:GetItemIDFromHyperlink(link)
				end
				if itemID then
					InfinityHiveTooltips:EnrichItemTooltip(tooltip, itemID)
				end
			end)
		end)
	end

	-- Legacy / Classic GameTooltip & ItemRefTooltip fallback
	local function HookLegacyTooltip(tt)
		if not tt or not tt.HookScript then return end
		pcall(tt.HookScript, tt, "OnTooltipCleared", function(selfTT)
			selfTT._infHiveStamp = nil
		end)
		pcall(tt.HookScript, tt, "OnTooltipSetItem", function(selfTT)
			if not selfTT.GetItem then return end
			local _, link = selfTT:GetItem()
			local itemID = link and InfinityUtils:GetItemIDFromHyperlink(link)
			if itemID then
				InfinityHiveTooltips:EnrichItemTooltip(selfTT, itemID)
			end
		end)
	end

	HookLegacyTooltip(_G.GameTooltip)
	HookLegacyTooltip(_G.ItemRefTooltip)
	HookLegacyTooltip(_G.ShoppingTooltip1)
	HookLegacyTooltip(_G.ShoppingTooltip2)
end

return InfinityHiveTooltips
