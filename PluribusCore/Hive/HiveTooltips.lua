-- PluribusHive Item Tooltips Integration
-- Multi-API hooks for Warcraft Forever 1.60.1 (TooltipDataProcessor + OnTooltipSetItem + direct Set* hooks)
-- Displays: You/Alts/Guild Bag+Bank counts, Guild Profession Needs (highlighting YOUR surplus!),
-- Guild-synced AH Market Price, and Wowhead / Guild P2P Game Data source

PluribusHiveTooltips = {
	initialized = false,
}
_G.PluribusHiveTooltips = PluribusHiveTooltips

local function FormatAge(ts)
	if not ts or ts <= 0 then return "" end
	local diff = math.max(0, time() - ts)
	if diff < 60 then return "now"
	elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
	elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
	else return math.floor(diff / 86400) .. "d ago" end
end

local function HasAnyScannedAHPrices()
	if not _G.PluribusHive then return false end
	local db = _G.PluribusHive:GetDB()
	return db and db.prices and next(db.prices) ~= nil or false
end

local function TooltipAlreadyHasPluribus(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines then return false end
	local name = tooltip:GetName()
	if not name then return false end
	local num = tooltip:NumLines() or 0
	for i = math.max(1, num - 12), num do
		local leftFS = _G[name .. "TextLeft" .. i]
		local txt = leftFS and leftFS.GetText and leftFS:GetText()
		if type(txt) == "string" and (txt:find("AH Price:", 1, true) or txt:find("Hive Bags:", 1, true) or txt:find("Gear Judge:", 1, true)) then
			return true
		end
	end
	return false
end

function PluribusHiveTooltips:EnrichItemTooltip(tooltip, itemID, stackCount, itemLink)
	itemID = tonumber(itemID)
	if not tooltip or not itemID or itemID <= 0 then return end
	local cfg = PluribusHive:GetConfig()
	if cfg.showTooltips == false then return end

	-- Prevent duplicate injection on the exact same rendered tooltip pass (never gets stuck across rebuilds!)
	if TooltipAlreadyHasPluribus(tooltip) then
		return
	end
	tooltip._plbInjectedItem = itemID

	local lines = {}

	-- 1. You / Alts / Guild Bag + Bank Counts
	if cfg.showTooltipCounts and _G.PluribusHiveInventory then
		local c = _G.PluribusHiveInventory:GetItemCounts(itemID)
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
			local MAX_HOLDERS = 3
			if (c.totalAlts or 0) > 0 then
				local altNames = {}
				for i, a in ipairs(c.alts) do
					if i <= MAX_HOLDERS then table.insert(altNames, a.name .. "(" .. a.total .. ")") end
				end
				if #c.alts > MAX_HOLDERS then table.insert(altNames, "+" .. (#c.alts - MAX_HOLDERS) .. " more") end
				table.insert(segs, "Alts: " .. table.concat(altNames, ", "))
			end
			if (c.totalGuild or 0) > 0 then
				local gNames = {}
				for i, g in ipairs(c.guild) do
					if i <= MAX_HOLDERS then table.insert(gNames, g.name .. "(" .. g.total .. ")") end
				end
				if #c.guild > MAX_HOLDERS then table.insert(gNames, "+" .. (#c.guild - MAX_HOLDERS) .. " more") end
				local gHdr = (#c.guild > MAX_HOLDERS) and ("Guild(" .. c.totalGuild .. "): ") or "Guild: "
				table.insert(segs, gHdr .. table.concat(gNames, ", "))
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
	if cfg.showTooltipProfNeeds and _G.PluribusHiveProfessions then
		local neededBy, isSurplus = _G.PluribusHiveProfessions:GetGuildNeedsForItem(itemID)
		if #neededBy > 0 then
			local who = {}
			local MAX_NEEDS = 3
			for i, n in ipairs(neededBy) do
				if i <= MAX_NEEDS then
					local lvlPart = (n.level and n.level > 0) and (" " .. n.level) or ""
					table.insert(who, string.format("%s (%s%s)", n.name, n.prof, lvlPart))
				end
			end
			if #neededBy > MAX_NEEDS then
				table.insert(who, "+" .. (#neededBy - MAX_NEEDS) .. " more")
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

	-- 3. Guild-Synced AH Market Price (always displays unit + stack price, or vendor/scan status)
	if cfg.showTooltipPrices ~= false and _G.PluribusHiveAuction then
		local price = _G.PluribusHiveAuction:GetPrice(itemID)
		local qty = tonumber(stackCount) or 1
		if price and price.copper and price.copper > 0 then
			local age = FormatAge(price.seenAt)
			local agePart = age ~= "" and (" |cff94a3b8(" .. age .. ")|r") or ""
			local stackPart = (qty > 1) and (" |cffcbd5e1(x" .. qty .. ": " .. PluribusUtils:FormatGold(price.copper * qty) .. ")|r") or ""
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cfffef08a" .. PluribusUtils:FormatGold(price.copper) .. "|r" .. stackPart .. agePart,
			})
		elseif HasAnyScannedAHPrices() then
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cff94a3b8No AH listings|r",
			})
		else
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cff94a3b8Open AH to auto-scan|r",
			})
		end
		-- Also show Vendor Sell Value if item has one (handy for vendor-vs-AH decisions)
		local sellPrice = select(11, PluribusUtils:GetItemInfo(itemID))
		if tonumber(sellPrice) and tonumber(sellPrice) > 0 then
			local vQty = (qty > 1) and (" |cff94a3b8(x" .. qty .. ": " .. PluribusUtils:FormatGold(sellPrice * qty) .. ")|r") or ""
			table.insert(lines, {
				left = "|cff94a3b8Vendor:|r",
				right = "|cffcbd5e1" .. PluribusUtils:FormatGold(sellPrice) .. "|r" .. vQty,
			})
		end
	end

	-- 4. Wowhead / Guild P2P Network Game Data (on-demand P2P lookup on miss)
	if cfg.showTooltipGameDB and _G.PluribusHiveNetworkDB then
		local entry = _G.PluribusHiveNetworkDB:GetItem(itemID)
		if entry and entry.source and entry.source ~= "" then
			table.insert(lines, {
				left = "|cff94a3b8Hive DB:|r",
				right = "|cffcbd5e1" .. entry.source:sub(1, 56) .. "|r",
			})
		else
			_G.PluribusHiveNetworkDB:RequestItem(itemID)
		end
	end

	-- 5. Sharpie's Gear Judge (SGJ): % Upgrade/Downgrade, Cap Guardian drop warnings & Alt BoE checks
	if cfg.showGearJudgeTooltips ~= false and _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.EvaluateItem then
		local _, ttLink = tooltip.GetItem and tooltip:GetItem() or nil, nil
		local eval = _G.PluribusHiveGearJudge:EvaluateItem(ttLink or itemID)
		if eval and eval.equippable then
			local pct = tonumber(eval.pctDelta) or 0
			local verdictStr
			if math.abs(pct) < 0.25 then
				verdictStr = "|cff94a3b8Sidegrade (0.0%)|r"
			elseif pct > 0 then
				verdictStr = string.format("|cff4ade80+%.1f%% Upgrade|r |cff94a3b8(%s)|r", pct, tostring(eval.specName or "Spec"))
			else
				verdictStr = string.format("|cfff87171%.1f%% Downgrade|r |cff94a3b8(%s)|r", pct, tostring(eval.specName or "Spec"))
			end
			table.insert(lines, {
				left = "|cff38bdf8Gear Judge:|r",
				right = verdictStr,
			})
			if eval.capWarning and eval.capWarning ~= "" then
				table.insert(lines, {
					left = "|cfffbbf24Cap Guardian:|r",
					right = "|cfffef08a" .. tostring(eval.capWarning) .. "|r",
				})
			end
			if _G.PluribusHiveGearJudge.GetAltUpgradesForItem then
				local alts = _G.PluribusHiveGearJudge:GetAltUpgradesForItem(ttLink or itemID)
				if alts and #alts > 0 then
					local altParts = {}
					local MAX_ALT_BOE = 3
					for idx, a in ipairs(alts) do
						if idx <= MAX_ALT_BOE then
							table.insert(altParts, string.format("%s (+%.1f%%)", tostring(a.name or "Alt"), tonumber(a.pct) or 0))
						end
					end
					if #alts > MAX_ALT_BOE then
						table.insert(altParts, "+" .. tostring(#alts - MAX_ALT_BOE) .. " more")
					end
					table.insert(lines, {
						left = "|cffc084fcAlt BoE Upgrade:|r",
						right = "|cffe9d5ff" .. table.concat(altParts, ", ") .. "|r",
					})
				end
			end
		end
	end

	if #lines == 0 then return end

	tooltip:AddLine(" ")
	for _, ln in ipairs(lines) do
		tooltip:AddDoubleLine(ln.left, ln.right, 1, 1, 1, 1, 1, 1)
	end
	tooltip:Show()
end

local function EnrichFromTooltipGetItem(tt, fallbackID, fallbackCount, fallbackLink)
	if not tt then return end
	local link = fallbackLink
	local itemID = tonumber(fallbackID)
	if (not itemID or not link) and tt.GetItem then
		local ok, _, ttLink = pcall(tt.GetItem, tt)
		if ok and ttLink then
			link = link or ttLink
			itemID = itemID or (PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(ttLink))
		end
	end
	if itemID and itemID > 0 then
		PluribusHiveTooltips:EnrichItemTooltip(tt, itemID, fallbackCount, link)
	end
end

local function GetBagSlotItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and type(info) == "table" then
			return info.itemID, info.stackCount, info.hyperlink
		end
	end
	local id = GetContainerItemID and GetContainerItemID(bag, slot) or nil
	local link = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
	local cnt = 1
	if GetContainerItemInfo then
		local _, c = GetContainerItemInfo(bag, slot)
		cnt = tonumber(c) or 1
	end
	if not id and link and PluribusUtils then
		id = PluribusUtils:GetItemIDFromHyperlink(link)
	end
	return id, cnt, link
end

function PluribusHiveTooltips:Initialize()
	if self.initialized then return end
	self.initialized = true

	-- 1. Modern TooltipDataProcessor hook
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		pcall(function()
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
				if not tooltip or not data then return end
				local itemID = data.id
				local link = data.hyperlink
				if not itemID and tooltip.GetItem then
					local ok, _, ttLink = pcall(tooltip.GetItem, tooltip)
					if ok and ttLink then
						link = link or ttLink
						itemID = PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(ttLink)
					end
				end
				if itemID then
					PluribusHiveTooltips:EnrichItemTooltip(tooltip, itemID, nil, link)
				end
			end)
		end)
	end

	-- 2. Classic / Warcraft Forever GameTooltip & ItemRefTooltip script hooks + direct method hooks
	local function HookTooltip(tt)
		if not tt then return end
		if tt.HookScript then
			pcall(tt.HookScript, tt, "OnTooltipCleared", function(selfTT)
				selfTT._plbInjectedItem = nil
			end)
			pcall(tt.HookScript, tt, "OnHide", function(selfTT)
				selfTT._plbInjectedItem = nil
			end)
			pcall(tt.HookScript, tt, "OnTooltipSetItem", function(selfTT)
				EnrichFromTooltipGetItem(selfTT)
			end)
			pcall(tt.HookScript, tt, "OnShow", function(selfTT)
				EnrichFromTooltipGetItem(selfTT)
			end)
		end

		if hooksecurefunc then
			if tt.SetBagItem then
				pcall(hooksecurefunc, tt, "SetBagItem", function(selfTT, bag, slot)
					local id, cnt, link = GetBagSlotItemInfo(bag, slot)
					EnrichFromTooltipGetItem(selfTT, id, cnt, link)
				end)
			end
			if tt.SetInventoryItem then
				pcall(hooksecurefunc, tt, "SetInventoryItem", function(selfTT, unit, slot)
					local id = GetInventoryItemID and GetInventoryItemID(unit, slot) or nil
					local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot) or nil
					local cnt = GetInventoryItemCount and GetInventoryItemCount(unit, slot) or 1
					EnrichFromTooltipGetItem(selfTT, id, cnt, link)
				end)
			end
			if tt.SetItemByID then
				pcall(hooksecurefunc, tt, "SetItemByID", function(selfTT, itemID)
					if itemID then
						PluribusHiveTooltips:EnrichItemTooltip(selfTT, itemID)
					end
				end)
			end
			if tt.SetHyperlink then
				pcall(hooksecurefunc, tt, "SetHyperlink", function(selfTT, link)
					local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if itemID then
						PluribusHiveTooltips:EnrichItemTooltip(selfTT, itemID, nil, link)
					else
						EnrichFromTooltipGetItem(selfTT)
					end
				end)
			end
			for _, methodName in ipairs({
				"SetAuctionItem",
				"SetTradeSkillItem",
				"SetMerchantItem",
				"SetLootItem",
				"SetInboxItem",
				"SetQuestItem",
				"SetCraftItem",
				"SetGuildBankItem",
			}) do
				if tt[methodName] then
					pcall(hooksecurefunc, tt, methodName, function(selfTT)
						EnrichFromTooltipGetItem(selfTT)
					end)
				end
			end
		end
	end

	HookTooltip(_G.GameTooltip)
	HookTooltip(_G.ItemRefTooltip)
	HookTooltip(_G.ShoppingTooltip1)
	HookTooltip(_G.ShoppingTooltip2)
end

return PluribusHiveTooltips
