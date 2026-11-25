-- PluribusHive Inventory & Bank Sharing Module
-- Tracks all Alts & Guildmates' bags + bank (if allowed, default ON)
-- Embeds a Bagnon-style character switcher button directly into WoW's Bag frame

PluribusHiveInventory = {
	initialized = false,
	scanPending = false,
	bankOpen = false,
	bagButtonAttached = false,
	pendingUnifiedRefresh = false,
}
_G.PluribusHiveInventory = PluribusHiveInventory

-- Module-local registries so we NEVER write custom fields onto Blizzard's secure ContainerFrames/ItemButtons
local attachedHosts = {}
local unifiedBagContainers = {}
local unifiedSlotButtons = {}
local unifiedUpgDots = {}
local unifiedTrashBadges = {}

local function GetContainerSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	elseif GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function GetContainerSlotItem(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info and info.itemID then
			return info.itemID, info.stackCount or 1, info.hyperlink, info.quality, info.isLocked
		end
		return nil
	elseif GetContainerItemInfo then
		local _, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
		if link then
			local itemID = PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
			if quality == nil and itemID and PluribusUtils then
				quality = select(3, PluribusUtils:GetItemInfo(itemID))
			end
			return itemID, count or 1, link, quality, locked
		end
	end
	return nil
end

-- ============================================================================
-- CUSTOM TRASH LIST (Player-marked items auto-sold along with Gray Junk!)
-- ============================================================================
function PluribusHiveInventory:GetCustomTrashDB()
	local db = PluribusHive and PluribusHive:GetDB()
	if not db then return {} end
	db.customTrash = db.customTrash or {}
	return db.customTrash
end

function PluribusHiveInventory:IsCustomTrash(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return false end
	return self:GetCustomTrashDB()[itemID] == true
end

function PluribusHiveInventory:GetCustomTrashList()
	local out = {}
	for itemID, flagged in pairs(self:GetCustomTrashDB()) do
		local id = tonumber(itemID)
		if id and id > 0 and flagged == true then
			local name, link, quality, _, _, _, _, _, _, icon, sellPrice = PluribusUtils:GetItemInfo(id)
			table.insert(out, {
				itemID = id,
				name = name or ("Item #" .. id),
				link = link,
				quality = quality or 1,
				icon = icon or PluribusUtils:GetItemIcon(id),
				sellPrice = tonumber(sellPrice) or 0,
			})
		end
	end
	table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
	return out
end

function PluribusHiveInventory:GetCustomTrashCount()
	local n = 0
	for _, flagged in pairs(self:GetCustomTrashDB()) do
		if flagged == true then n = n + 1 end
	end
	return n
end

function PluribusHiveInventory:ToggleCustomTrash(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then return false end
	local tbl = self:GetCustomTrashDB()
	local nowTrash = not (tbl[itemID] == true)
	tbl[itemID] = nowTrash or nil
	local itemName, itemLink = PluribusUtils:GetItemInfo(itemID)
	local label = itemLink or itemName or ("Item #" .. itemID)
	if _G.PluribusUIFramework then
		if nowTrash then
			_G.PluribusUIFramework:ShowNotification("|cfff97316Als Trash markiert (Auto-Verkauf):|r " .. label, 2.8)
		else
			_G.PluribusUIFramework:ShowNotification("|cff38bdf8Trash-Markierung entfernt:|r " .. label, 2.4)
		end
	end
	if self.unifiedBagFrame and self.unifiedBagFrame:IsShown() then
		self:RefreshUnifiedBagWindow()
	end
	if self.trashManagerFrame and self.trashManagerFrame:IsShown() then
		self:RefreshTrashManagerWindow()
	end
	return nowTrash
end

function PluribusHiveInventory:IsSellableTrash(itemID, quality, sellPrice)
	if not itemID or itemID <= 0 then return false end
	if (tonumber(sellPrice) or 0) <= 0 then return false end
	if quality == 0 then return true end
	return self:IsCustomTrash(itemID)
end

-- Auto-sell all Poor (gray, quality == 0) AND player-marked Custom Trash items when a vendor window is open.
-- Hold Shift when talking to a vendor to temporarily skip automatic selling.
function PluribusHiveInventory:SellGrayTrash(silent)
	if InCombatLockdown and InCombatLockdown() then
		return 0, 0
	end
	if not (_G.MerchantFrame and _G.MerchantFrame:IsShown()) then
		if not silent and _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Öffne zuerst einen Händler, um Graues & markierten Trash zu verkaufen.|r", 3)
		end
		return 0, 0
	end

	local soldStacks, soldItems, earnedCopper = 0, 0, 0
	local maxBag = NUM_BAG_SLOTS or 4
	for bag = 0, maxBag do
		local slots = GetContainerSlots(bag)
		for slot = 1, slots do
			local itemID, count, _, quality, isLocked = GetContainerSlotItem(bag, slot)
			if itemID and not isLocked then
				local q = quality
				local sellPrice = 0
				if PluribusUtils and PluribusUtils.GetItemInfo then
					local _, _, infoQ, _, _, _, _, _, _, _, infoSell = PluribusUtils:GetItemInfo(itemID)
					if q == nil then q = infoQ end
					sellPrice = tonumber(infoSell) or 0
				end
				if self:IsSellableTrash(itemID, q, sellPrice) then
					if C_Container and C_Container.UseContainerItem then
						pcall(C_Container.UseContainerItem, bag, slot)
					elseif UseContainerItem then
						pcall(UseContainerItem, bag, slot)
					end
					soldStacks = soldStacks + 1
					soldItems = soldItems + (count or 1)
					earnedCopper = earnedCopper + (sellPrice * (count or 1))
				end
			end
		end
	end

	if soldItems > 0 then
		local goldStr = (PluribusUtils and PluribusUtils:FormatGold(earnedCopper)) or (tostring(earnedCopper) .. "c")
		local msg = string.format("|cff4ade80Auto-verkauft: %d Trash-Item%s für %s.|r", soldItems, soldItems == 1 and "" or "s", goldStr)
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification(msg, 3)
		end
		if PluribusUtils and PluribusUtils.Print then
			PluribusUtils:Print(msg, "Bags")
		end
	elseif not silent and _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff94a3b8Kein grauer oder markierter Trash in deinen Taschen.|r", 2.5)
	end

	return soldItems, earnedCopper
end

-- Auto-repair all equipped & bag gear at merchants
-- Payment modes (cfg.autoRepairMode):
--   "PERSONAL_ONLY"  (default) -> only own gold, never uses Guild Bank
--   "PERSONAL_FIRST"           -> own gold first, Guild Bank fallback
--   "GUILD_FIRST"              -> Guild Bank first, own gold fallback
--   "GUILD_ONLY"               -> only Guild Bank, never spends own gold
function PluribusHiveInventory:RepairAllGear(silent)
	if InCombatLockdown and InCombatLockdown() then
		return false, 0, nil
	end
	if not (CanMerchantRepair and CanMerchantRepair()) then
		return false, 0, nil
	end
	local cost, canRepair = 0, false
	if GetRepairAllCost then
		cost, canRepair = GetRepairAllCost()
	end
	cost = tonumber(cost) or 0
	if not canRepair or cost <= 0 then
		return false, 0, nil
	end

	local cfg = PluribusHive and PluribusHive:GetConfig() or {}
	local mode = cfg.autoRepairMode or "PERSONAL_ONLY"

	local function TryGuildRepair()
		if not (CanGuildBankRepair and CanGuildBankRepair() and RepairAllItems) then
			return false
		end
		local withdraw = (GetGuildBankWithdrawMoney and tonumber(GetGuildBankWithdrawMoney())) or 0
		local bankMoney = (GetGuildBankMoney and tonumber(GetGuildBankMoney())) or 0
		local allowed = (withdraw == -1) and bankMoney or math.min(withdraw, bankMoney)
		if allowed >= cost then
			pcall(RepairAllItems, true)
			return true
		end
		return false
	end

	local function TryPersonalRepair()
		local myMoney = (GetMoney and tonumber(GetMoney())) or 0
		if myMoney >= cost and RepairAllItems then
			pcall(RepairAllItems, false)
			return true
		end
		return false
	end

	local source = nil
	if mode == "GUILD_ONLY" then
		if TryGuildRepair() then source = "GUILD" end
	elseif mode == "GUILD_FIRST" then
		if TryGuildRepair() then
			source = "GUILD"
		elseif TryPersonalRepair() then
			source = "PERSONAL"
		end
	elseif mode == "PERSONAL_FIRST" then
		if TryPersonalRepair() then
			source = "PERSONAL"
		elseif TryGuildRepair() then
			source = "GUILD"
		end
	else
		-- Default: PERSONAL_ONLY (never touches Guild Bank)
		if TryPersonalRepair() then source = "PERSONAL" end
	end

	if not source then
		if not silent and _G.PluribusUIFramework then
			local hint = (mode == "GUILD_ONLY") and "Gildenbank-Reparatur nicht verfügbar/ausreichend" or "Nicht genug Gold für Auto-Reparatur"
			_G.PluribusUIFramework:ShowNotification("|cfff87171" .. hint .. " (" .. PluribusUtils:FormatGold(cost) .. ").|r", 3)
		end
		return false, 0, nil
	end

	local goldStr = (PluribusUtils and PluribusUtils:FormatGold(cost)) or (tostring(cost) .. "c")
	local srcStr = (source == "GUILD") and " (Gildenbank)" or " (Eigenes Gold)"
	local msg = "|cff4ade80Auto-Reparatur: " .. goldStr .. srcStr .. "|r"
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification(msg, 3)
	end
	if PluribusUtils and PluribusUtils.Print then
		PluribusUtils:Print(msg, "Bags")
	end
	return true, cost, source
end

-- Average equipped gear durability percentage (0..100) for Unified Bag footer
function PluribusHiveInventory:GetAverageDurabilityPct()
	if not GetInventoryItemDurability then return 100 end
	local curTotal, maxTotal = 0, 0
	for slot = 1, 18 do
		local cur, maxV = GetInventoryItemDurability(slot)
		if cur and maxV and maxV > 0 then
			curTotal = curTotal + cur
			maxTotal = maxTotal + maxV
		end
	end
	if maxTotal <= 0 then return 100 end
	return math.floor((curTotal / maxTotal) * 100 + 0.5)
end

-- Classify bag items for the non-tainting Unified Bag category filter strip & sorting (supports EN & DE clients)
local BAG_CATEGORY_SORT_ORDER = {
	HEARTH = 0,
	EQUIP = 1,
	CONSUMABLE = 2,
	QUEST = 3,
	CRAFT = 4,
	OTHER = 5,
	TRASH = 6,
}

function PluribusHiveInventory:GetItemBagCategory(itemID, quality, itemType, classID)
	if quality == 0 or self:IsCustomTrash(itemID) then
		return "TRASH"
	end
	local cid = tonumber(classID)
	if cid == 2 or cid == 4 then return "EQUIP" end
	if cid == 0 then return "CONSUMABLE" end
	if cid == 7 or cid == 9 then return "CRAFT" end
	if cid == 12 then return "QUEST" end
	local t = tostring(itemType or ""):lower()
	if t:find("weapon") or t:find("armor") or t:find("waffe") or t:find("rüstung") then return "EQUIP" end
	if t:find("consum") or t:find("verbrauch") then return "CONSUMABLE" end
	if t:find("trade") or t:find("reagent") or t:find("recipe") or t:find("handwer") or t:find("rezept") then return "CRAFT" end
	if t:find("quest") then return "QUEST" end
	return "OTHER"
end

function PluribusHiveInventory:GetItemSortOrder(itemID, quality, itemType, classID)
	if tonumber(itemID) == 6948 then
		return BAG_CATEGORY_SORT_ORDER.HEARTH
	end
	local cat = self:GetItemBagCategory(itemID, quality, itemType, classID)
	return BAG_CATEGORY_SORT_ORDER[cat] or BAG_CATEGORY_SORT_ORDER.OTHER
end

function PluribusHiveInventory:IsBagSortedViewEnabled()
	if _G.PluribusHive and _G.PluribusHive.GetConfig then
		return _G.PluribusHive:GetConfig().bagSortedView ~= false
	end
	return self._bagSortedView ~= false
end

function PluribusHiveInventory:SetBagSortedView(enabled)
	self._bagSortedView = enabled == true
	if _G.PluribusHive and _G.PluribusHive.SetConfig then
		_G.PluribusHive:SetConfig("bagSortedView", enabled == true)
	end
	self:RefreshUnifiedBagWindow()
end

local function PickupBagSlot(bag, slot)
	if C_Container and C_Container.PickupContainerItem then
		return pcall(C_Container.PickupContainerItem, bag, slot)
	elseif PickupContainerItem then
		return pcall(PickupContainerItem, bag, slot)
	end
	return false
end

local function GetBagFamilyType(bag)
	if bag == 0 then return 0 end
	if C_Container and C_Container.GetContainerNumFreeSlots then
		local ok, _, bagType = pcall(C_Container.GetContainerNumFreeSlots, bag)
		if ok then return tonumber(bagType) or 0 end
	elseif GetContainerNumFreeSlots then
		local ok, _, bagType = pcall(GetContainerNumFreeSlots, bag)
		if ok then return tonumber(bagType) or 0 end
	end
	return 0
end

local function GetBagItemMaxStack(itemID)
	if not itemID then return 1 end
	local maxStack = select(8, PluribusUtils:GetItemInfo(itemID))
	return math.max(1, tonumber(maxStack) or 1)
end

-- Internal Classic-compatible stepped physical container sorter (supports Bags 0..4 and Bank -1, 5..11)
function PluribusHiveInventory:SortPhysicalContainers(bagList, label, isBankSort)
	local UI = _G.PluribusUIFramework
	if InCombatLockdown and InCombatLockdown() then
		if UI then UI:ShowNotification("|cfffbbf24" .. tostring(label or "Taschen") .. " können im Kampf nicht sortiert werden.|r", 2.5) end
		return false
	end
	if isBankSort and not self.bankOpen then
		if UI then UI:ShowNotification("|cfffbbf24Öffne zuerst deine Bank zum Sortieren.|r", 2.5) end
		return false
	end
	if CursorHasItem and CursorHasItem() then
		if UI then UI:ShowNotification("|cfffbbf24Bitte lege zuerst das Item am Mauszeiger ab.|r", 2.5) end
		return false
	end
	if self._bagSortRunning then return true end

	-- Enable sorted visual mode as well so the window reflects the clean sort immediately
	if not self:IsBagSortedViewEnabled() then
		self:SetBagSortedView(true)
	end

	self._bagSortRunning = true
	self._bagSortTicks = 0
	if not self._bagSortDriver then
		self._bagSortDriver = CreateFrame("Frame")
	end

	local function FinishSort(msg)
		PluribusHiveInventory._bagSortRunning = false
		if PluribusHiveInventory._bagSortDriver then
			PluribusHiveInventory._bagSortDriver:SetScript("OnUpdate", nil)
		end
		if isBankSort then
			PluribusHiveInventory:ScanBank()
			PluribusHiveInventory:RefreshUnifiedBankWindow()
		else
			PluribusHiveInventory:ScanBags()
			PluribusHiveInventory:RefreshUnifiedBagWindow()
		end
		if msg and UI then
			UI:ShowNotification(msg, 2.2)
		end
	end

	local function DoOneSortStep()
		if InCombatLockdown and InCombatLockdown() then
			FinishSort("|cfffbbf24Sortieren im Kampf pausiert.|r")
			return
		end
		if isBankSort and not PluribusHiveInventory.bankOpen then
			FinishSort("|cfffbbf24Bank geschlossen — Sortieren beendet.|r")
			return
		end
		if CursorHasItem and CursorHasItem() then
			return
		end

		local regularSlots = {}
		for _, bag in ipairs(bagList or {}) do
			local family = (bag == (BANK_CONTAINER or -1) or bag == 0) and 0 or GetBagFamilyType(bag)
			if family == 0 then
				local num = GetContainerSlots(bag)
				for slot = 1, num do
					local itemID, count, _, quality, isLocked = GetContainerSlotItem(bag, slot)
					if isLocked then
						return -- wait for previous move to unlock
					end
					local name, _, infoQ, _, _, itemType, _, maxStack, _, _, _, classID = nil, nil, nil, nil, nil, nil, nil, 1, nil, nil, nil, nil
					if itemID then
						name, _, infoQ, _, _, itemType, _, maxStack, _, _, _, classID = PluribusUtils:GetItemInfo(itemID)
					end
					local q = quality or infoQ or 1
					table.insert(regularSlots, {
						bag = bag,
						slot = slot,
						itemID = itemID,
						count = tonumber(count) or 0,
						maxStack = math.max(1, tonumber(maxStack) or GetBagItemMaxStack(itemID)),
						quality = q,
						name = tostring(name or (itemID and ("Item #" .. itemID) or "")):lower(),
						catOrder = itemID and PluribusHiveInventory:GetItemSortOrder(itemID, q, itemType, classID) or 99,
					})
				end
			end
		end

		-- Pass 1: Merge partial stacks of the same itemID
		local partialById = {}
		for i, st in ipairs(regularSlots) do
			if st.itemID and st.maxStack > 1 and st.count < st.maxStack then
				local targetIdx = partialById[st.itemID]
				if targetIdx then
					local dst = regularSlots[targetIdx]
					PickupBagSlot(st.bag, st.slot)
					PickupBagSlot(dst.bag, dst.slot)
					return
				else
					partialById[st.itemID] = i
				end
			end
		end

		-- Pass 2: Build target sorted order and perform 1 swap toward target order
		local desired = {}
		for i, st in ipairs(regularSlots) do
			desired[i] = st
		end
		table.sort(desired, function(a, b)
			local aHas = a.itemID ~= nil
			local bHas = b.itemID ~= nil
			if aHas ~= bHas then return aHas end
			if not aHas then
				if a.bag ~= b.bag then return a.bag < b.bag end
				return a.slot < b.slot
			end
			if a.catOrder ~= b.catOrder then return a.catOrder < b.catOrder end
			if a.quality ~= b.quality then return a.quality > b.quality end
			if a.name ~= b.name then return a.name < b.name end
			if a.count ~= b.count then return a.count > b.count end
			if a.itemID ~= b.itemID then return a.itemID < b.itemID end
			if a.bag ~= b.bag then return a.bag < b.bag end
			return a.slot < b.slot
		end)

		for i = 1, #regularSlots do
			local cur = regularSlots[i]
			local want = desired[i]
			local sameItem = (cur.itemID == want.itemID and cur.count == want.count)
			if not sameItem and want.itemID then
				-- Find a slot j > i that currently holds want.itemID (and count)
				local srcIdx = nil
				for j = i + 1, #regularSlots do
					if regularSlots[j].itemID == want.itemID and regularSlots[j].count == want.count then
						srcIdx = j
						break
					end
				end
				if not srcIdx then
					for j = i + 1, #regularSlots do
						if regularSlots[j].itemID == want.itemID then
							srcIdx = j
							break
						end
					end
				end
				if srcIdx then
					local src = regularSlots[srcIdx]
					PickupBagSlot(src.bag, src.slot)
					PickupBagSlot(cur.bag, cur.slot)
					return
				end
			end
		end

		FinishSort("|cff4ade80" .. tostring(label or "Taschen") .. " sortiert!|r")
	end

	local accum = 0
	self._bagSortDriver:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + (elapsed or 0)
		if accum < 0.06 then return end
		accum = 0
		PluribusHiveInventory._bagSortTicks = (PluribusHiveInventory._bagSortTicks or 0) + 1
		if PluribusHiveInventory._bagSortTicks > 180 then
			FinishSort("|cff4ade80" .. tostring(label or "Taschen") .. " sortiert!|r")
			return
		end
		DoOneSortStep()
	end)
	DoOneSortStep()
	return true
end

-- Physical Classic-compatible bag sorter (bags 0..4)
function PluribusHiveInventory:SortPhysicalBags()
	local maxBag = NUM_BAG_SLOTS or 4
	local bags = {}
	for bag = 0, maxBag do table.insert(bags, bag) end
	return self:SortPhysicalContainers(bags, "Taschen", false)
end

-- Physical Classic-compatible bank sorter (main bank -1 + bank bags 5..11)
function PluribusHiveInventory:SortPhysicalBank()
	local bags = { BANK_CONTAINER or -1 }
	local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
	local lastBankBag = firstBankBag + (NUM_BANKBAGSLOTS or 6) - 1
	for bag = firstBankBag, lastBankBag do
		table.insert(bags, bag)
	end
	return self:SortPhysicalContainers(bags, "Bank", true)
end

-- Fast Auto-Loot helper (instantaneously loots all slots when WoW auto-loot is active)
local lastFastLootAt = 0
function PluribusHiveInventory:TryFastAutoLoot()
	local cfg = PluribusHive and PluribusHive:GetConfig()
	if cfg and cfg.fastAutoLoot == false then return 0 end
	if not (GetNumLootItems and LootSlot) then return 0 end

	local autoDefault = GetCVarBool and GetCVarBool("autoLootDefault") or false
	local modPressed = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") or false
	local shouldAuto = (autoDefault and not modPressed) or (not autoDefault and modPressed)
	if not shouldAuto then return 0 end

	local now = (GetTime and GetTime()) or 0
	if (now - lastFastLootAt) < 0.12 then return 0 end
	lastFastLootAt = now

	local num = tonumber(GetNumLootItems()) or 0
	if num <= 0 then return 0 end
	local looted = 0
	for i = num, 1, -1 do
		local ok = pcall(LootSlot, i)
		if ok then looted = looted + 1 end
	end
	return looted
end

function PluribusHiveInventory:PruneDuplicateCharacters()
	local db = PluribusHive:GetDB()
	local realm = PluribusHive:GetRealmKey()
	local me = PluribusHive:GetPlayerShortName()
	local meKey = PluribusHive:CanonicalKey(me)
	db.alts[realm] = db.alts[realm] or {}
	local realmAlts = db.alts[realm]

	-- 1. Merge any duplicate keys in db.alts[realm] (e.g. "leona" and "Leona Morgenröte" -> single canonical "Leona")
	local byKey = {}
	local keysToCheck = {}
	for k in pairs(realmAlts) do table.insert(keysToCheck, k) end
	for _, rawKey in ipairs(keysToCheck) do
		local rec = realmAlts[rawKey]
		local norm = PluribusHive:NormalizeName(rawKey)
		local cKey = PluribusHive:CanonicalKey(rawKey)
		if cKey ~= "" and type(rec) == "table" then
			local targetName = (cKey == meKey) and me or norm
			local existing = byKey[cKey]
			if not existing then
				byKey[cKey] = { targetName = targetName, rec = rec, rawKey = rawKey }
			else
				-- Merge fresher record & keep non-empty bank/bags
				local keep = ((rec.updatedAt or 0) >= (existing.rec.updatedAt or 0)) and rec or existing.rec
				local other = (keep == rec) and existing.rec or rec
				if not keep.bank or next(keep.bank) == nil then
					keep.bank = other.bank or {}
				end
				if not keep.bags or next(keep.bags) == nil then
					keep.bags = other.bags or {}
				end
				keep.name = targetName
				byKey[cKey].rec = keep
			end
		end
	end

	local rebuilt = {}
	for _, entry in pairs(byKey) do
		entry.rec.name = entry.targetName
		rebuilt[entry.targetName] = entry.rec
	end
	db.alts[realm] = rebuilt

	-- 2. Remove any self/alt duplicates from db.guildBags & db.guildProfs
	local ownKeys = { [meKey] = true }
	for k in pairs(rebuilt) do ownKeys[PluribusHive:CanonicalKey(k)] = true end

	local staleGuild = {}
	for memberName in pairs(db.guildBags or {}) do
		local mk = PluribusHive:CanonicalKey(memberName)
		if mk == "" or ownKeys[mk] then
			table.insert(staleGuild, memberName)
		end
	end
	for _, k in ipairs(staleGuild) do db.guildBags[k] = nil end
end

function PluribusHiveInventory:GetMyAltRecord()
	local db = PluribusHive:GetDB()
	local realm = PluribusHive:GetRealmKey()
	local me = PluribusHive:GetPlayerShortName()
	db.alts[realm] = db.alts[realm] or {}
	if not db.alts[realm][me] then
		self:PruneDuplicateCharacters()
	end
	db.alts[realm][me] = db.alts[realm][me] or {
		name = me,
		class = PluribusHive:GetPlayerClass(),
		level = UnitLevel and UnitLevel("player") or 60,
		gold = 0,
		bags = {},
		bank = {},
		updatedAt = 0,
	}
	return db.alts[realm][me]
end

function PluribusHiveInventory:ScanBags()
	local rec = self:GetMyAltRecord()
	local counts = {}
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local slots = GetContainerSlots(bag)
		for slot = 1, slots do
			local itemID, count = GetContainerSlotItem(bag, slot)
			if itemID and count and count > 0 then
				counts[itemID] = (counts[itemID] or 0) + count
			end
		end
	end
	rec.bags = counts
	rec.gold = GetMoney and GetMoney() or rec.gold or 0
	rec.class = PluribusHive:GetPlayerClass()
	rec.level = UnitLevel and UnitLevel("player") or rec.level or 60
	rec.updatedAt = time()
	return rec
end

function PluribusHiveInventory:ScanBank()
	local rec = self:GetMyAltRecord()
	local counts = {}
	local bankContainer = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1
	local mainSlots = GetContainerSlots(bankContainer)
	for slot = 1, mainSlots do
		local itemID, count = GetContainerSlotItem(bankContainer, slot)
		if itemID and count and count > 0 then
			counts[itemID] = (counts[itemID] or 0) + count
		end
	end
	local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
	local lastBankBag = firstBankBag + (NUM_BANKBAGSLOTS or 7) - 1
	for bag = firstBankBag, lastBankBag do
		local slots = GetContainerSlots(bag)
		for slot = 1, slots do
			local itemID, count = GetContainerSlotItem(bag, slot)
			if itemID and count and count > 0 then
				counts[itemID] = (counts[itemID] or 0) + count
			end
		end
	end
	rec.bank = counts
	rec.gold = GetMoney and GetMoney() or rec.gold or 0
	rec.updatedAt = time()
	return rec
end

local function SerializeCounts(tbl)
	local parts = {}
	for itemID, qty in pairs(tbl or {}) do
		if type(itemID) == "number" and qty and qty > 0 then
			table.insert(parts, itemID .. ":" .. qty)
		end
	end
	return table.concat(parts, ",")
end

local function DeserializeCounts(str)
	local out = {}
	if not str or str == "" then return out end
	for idStr, qtyStr in str:gmatch("(%d+):(%d+)") do
		local id, qty = tonumber(idStr), tonumber(qtyStr)
		if id and qty and qty > 0 then
			out[id] = qty
		end
	end
	return out
end

function PluribusHiveInventory:BroadcastBags()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareBags then return end
	local rec = self:GetMyAltRecord()
	local payload = string.format("%s|%d|%d|%s",
		rec.class or "WARRIOR",
		rec.level or 60,
		rec.gold or 0,
		SerializeCounts(rec.bags)
	)
	PluribusHive:Send("BAGS", payload, "GUILD")
end

function PluribusHiveInventory:BroadcastBank()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareBank then return end
	local rec = self:GetMyAltRecord()
	local payload = string.format("%s|%d|%s",
		rec.class or "WARRIOR",
		rec.gold or 0,
		SerializeCounts(rec.bank)
	)
	PluribusHive:Send("BANK", payload, "GUILD")
end

function PluribusHiveInventory:ScheduleBagSync()
	if self.scanPending then return end
	self.scanPending = true
	if C_Timer and C_Timer.After then
		C_Timer.After(6, function()
			PluribusHiveInventory.scanPending = false
			PluribusHiveInventory:ScanBags()
			PluribusHiveInventory:BroadcastBags()
		end)
	else
		self.scanPending = false
		self:ScanBags()
		self:BroadcastBags()
	end
end

-- Fast cross-character & cross-guild item lookup (used by Tooltips, Professions, and Bag Viewer)
function PluribusHiveInventory:GetItemCounts(itemID)
	if not itemID then return nil end
	local db = PluribusHive:GetDB()
	local realm = PluribusHive:GetRealmKey()
	local me = PluribusHive:GetPlayerShortName()

	local result = {
		selfBags = 0,
		selfBank = 0,
		alts = {},
		guild = {},
		totalAlts = 0,
		totalGuild = 0,
	}

	local realmAlts = db.alts[realm] or {}
	local ownCanon = {}
	local meCanon = PluribusHive:CanonicalKey(me)
	if meCanon ~= "" then ownCanon[meCanon] = true end

	for charName, rec in pairs(realmAlts) do
		local cCanon = PluribusHive:CanonicalKey(charName)
		if cCanon ~= "" then ownCanon[cCanon] = true end
		local b = (rec.bags and rec.bags[itemID]) or 0
		local k = (rec.bank and rec.bank[itemID]) or 0
		if cCanon == meCanon then
			result.selfBags = b
			result.selfBank = k
		elseif (b + k) > 0 then
			table.insert(result.alts, { name = PluribusHive:NormalizeName(charName), class = rec.class, bags = b, bank = k, total = b + k })
			result.totalAlts = result.totalAlts + b + k
		end
	end

	local seenGuild = {}
	for memberName, rec in pairs(db.guildBags or {}) do
		local mNorm = PluribusHive:NormalizeName(memberName)
		local mCanon = PluribusHive:CanonicalKey(memberName)
		if mCanon ~= "" and not ownCanon[mCanon] and not seenGuild[mCanon] then
			seenGuild[mCanon] = true
			local b = (rec.bags and rec.bags[itemID]) or 0
			local k = (rec.bank and rec.bank[itemID]) or 0
			if (b + k) > 0 then
				table.insert(result.guild, { name = mNorm, class = rec.class, bags = b, bank = k, total = b + k })
				result.totalGuild = result.totalGuild + b + k
			end
		end
	end

	table.sort(result.alts, function(a, b) return a.total > b.total end)
	table.sort(result.guild, function(a, b) return a.total > b.total end)
	return result
end

-- List all inspectable characters (self + alts + sharing guildmates) with strict case+surname deduplication
function PluribusHiveInventory:GetInspectableCharacters()
	self:PruneDuplicateCharacters()
	local db = PluribusHive:GetDB()
	local realm = PluribusHive:GetRealmKey()
	local me = PluribusHive:GetPlayerShortName()
	local meKey = PluribusHive:CanonicalKey(me)
	local list = {}
	local seenKey = {}

	local realmAlts = db.alts[realm] or {}
	for charName, rec in pairs(realmAlts) do
		local norm = PluribusHive:NormalizeName(charName)
		local ck = PluribusHive:CanonicalKey(charName)
		if ck ~= "" and not seenKey[ck] then
			seenKey[ck] = true
			table.insert(list, {
				name = norm,
				class = rec.class or "WARRIOR",
				level = rec.level or 60,
				gold = rec.gold or 0,
				bags = rec.bags or {},
				bank = rec.bank or {},
				updatedAt = rec.updatedAt or 0,
				group = (ck == meKey) and "YOU" or "ALT",
			})
		end
	end

	local staleKeys = {}
	for memberName, rec in pairs(db.guildBags or {}) do
		local norm = PluribusHive:NormalizeName(memberName)
		local ck = PluribusHive:CanonicalKey(memberName)
		if ck == "" or ck == meKey or seenKey[ck] then
			table.insert(staleKeys, memberName)
		else
			seenKey[ck] = true
			table.insert(list, {
				name = norm,
				class = rec.class or "WARRIOR",
				level = rec.level or 60,
				gold = rec.gold or 0,
				bags = rec.bags or {},
				bank = rec.bank or {},
				updatedAt = rec.updatedAt or 0,
				group = "GUILD",
			})
		end
	end
	for _, k in ipairs(staleKeys) do
		if db.guildBags then db.guildBags[k] = nil end
	end

	table.sort(list, function(a, b)
		local rank = { YOU = 1, ALT = 2, GUILD = 3 }
		if rank[a.group] ~= rank[b.group] then
			return rank[a.group] < rank[b.group]
		end
		return a.name < b.name
	end)
	return list
end

-- Search all bags & banks across alts and guild
function PluribusHiveInventory:SearchAll(query)
	local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
	local chars = self:GetInspectableCharacters()
	local results = {}
	for _, ch in ipairs(chars) do
		local merged = {}
		for id, cnt in pairs(ch.bags or {}) do
			merged[id] = { bags = cnt, bank = 0 }
		end
		for id, cnt in pairs(ch.bank or {}) do
			merged[id] = merged[id] or { bags = 0, bank = 0 }
			merged[id].bank = cnt
		end
		for itemID, counts in pairs(merged) do
			local itemName, itemLink, quality, _, _, _, _, _, _, icon = PluribusUtils:GetItemInfo(itemID)
			local displayName = itemName or ("Item #" .. itemID)
			if q == "" or displayName:lower():find(q, 1, true) or tostring(itemID) == q then
				table.insert(results, {
					owner = ch.name,
					ownerClass = ch.class,
					group = ch.group,
					itemID = itemID,
					name = displayName,
					link = itemLink,
					quality = quality or 1,
					icon = icon,
					bags = counts.bags,
					bank = counts.bank,
					total = counts.bags + counts.bank,
				})
			end
		end
	end
	table.sort(results, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.total > b.total
	end)
	return results
end

-- Bagnon-style side bookmark tab anchored to WoW's Bag & Bank windows (parented to UIParent = ZERO taint!)
function PluribusHiveInventory:AttachToContainerHost(parent, isBank)
	if not parent or attachedHosts[parent] or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	attachedHosts[parent] = true

	local tab = _G.PluribusUIFramework:CreateSideTab(UIParent, 1, {
		icon = isBank and "Interface\\Icons\\INV_Box_02" or "Interface\\Icons\\INV_Misc_Bag_08",
		title = isBank and "Alts & Guild Banks" or "Alts & Guild Bags",
		tooltip = "View your Alts' and sharing Guildmates' bags & banks with icons and tooltips.",
		yOffset = isBank and -54 or -36,
		onClick = function()
			if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleInventoryViewer then
				_G.PluribusHiveUI:ToggleInventoryViewer(nil, isBank and "BANK" or "ALL")
			end
		end,
	})
	if tab then
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, isBank and -54 or -36)
		tab:SetFrameStrata(parent:GetFrameStrata() or "HIGH")
		tab:SetShown(parent:IsShown() == true)
		if parent.HookScript then
			pcall(parent.HookScript, parent, "OnShow", function()
				local cfg = _G.PluribusHive and _G.PluribusHive:GetConfig()
				if cfg and cfg.attachSideTabs ~= false and not (cfg.replaceNativeBags == true) then
					tab:ClearAllPoints()
					tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, isBank and -54 or -36)
					tab:Show()
				else
					tab:Hide()
				end
			end)
			pcall(parent.HookScript, parent, "OnHide", function()
				tab:Hide()
			end)
		end
	end
end

function PluribusHiveInventory:AttachBagFrameButton()
	if _G.ContainerFrameCombinedBags then
		self:AttachToContainerHost(_G.ContainerFrameCombinedBags, false)
	end
	if _G.ContainerFrame1 then
		self:AttachToContainerHost(_G.ContainerFrame1, false)
	end
	if _G.BankFrame then
		self:AttachToContainerHost(_G.BankFrame, true)
	end
	self.bagButtonAttached = true
end

-- ============================================================================
-- UNIFIED PLURIBUS RUCKSACK UI (100% Native Blizzard ContainerFrameItemButtonTemplate!)
-- Architectural guarantees for zero ADDON_ACTION_BLOCKED & full item interaction:
--   * Every slot is a native Blizzard ItemButton inheriting ContainerFrameItemButtonTemplate
--     inside a parent bag frame whose ID is set to the bag index (0..4), with slot:SetID(slot)
--     and slot:SetBagID(bag) (when supported by 1.15/1.60.1 ContainerFrameItemButtonMixin).
--   * NEVER replaces OnClick / OnDragStart / OnReceiveDrag / OnEnter / OnLeave or SplitStack.
--     Blizzard's own secure XML handlers execute UseContainerItem (use, equip, vendor sell,
--     bank/guild-bank deposit, mail/trade attach), PickupContainerItem (drag/move/drop),
--     ChatEdit_InsertLink (Shift-Click), Stack Split, and DressUpItemLink natively!
--   * NEVER writes custom keys or BackdropTemplate fields onto Blizzard's ItemButton; all
--     overlays (upgrade dot, custom trash badge) live in module-local registries parented to
--     a non-interactive overlay child frame.
--   * Suppresses Blizzard's native bag frames via a hidden parent frame (never calling
--     ContainerFrame:Hide() inside ContainerFrame_OnShow), eliminating UIPanel/ContainerFrame taint.
-- ============================================================================
local QUALITY_BORDER_RGB = {
	[0] = { 0.55, 0.55, 0.55 },
	[1] = { 0.48, 0.54, 0.64 },
	[2] = { 0.12, 0.88, 0.22 },
	[3] = { 0.18, 0.58, 1.00 },
	[4] = { 0.68, 0.28, 0.96 },
	[5] = { 1.00, 0.54, 0.12 },
}

local unifiedHiddenBagParent = nil
local unifiedSlotOverlays = {}
local unifiedSlotBorders = {}

local function GetHiddenBagParent()
	if not unifiedHiddenBagParent then
		unifiedHiddenBagParent = CreateFrame("Frame", "PluribusHiddenNativeBagsHost", UIParent)
		unifiedHiddenBagParent:Hide()
	end
	return unifiedHiddenBagParent
end

local nativeBagOriginalParents = {}

function PluribusHiveInventory:SyncNativeBagSuppression()
	if InCombatLockdown and InCombatLockdown() then
		self.pendingBagSuppressionSync = true
		return
	end
	local cfg = PluribusHive and PluribusHive:GetConfig()
	local suppress = cfg and cfg.replaceNativeBags == true
	local hiddenHost = suppress and GetHiddenBagParent() or nil
	local function ApplyParent(cf)
		if not cf or not cf.SetParent then return end
		if not nativeBagOriginalParents[cf] and cf.GetParent then
			local orig = cf:GetParent()
			if orig and orig ~= hiddenHost then
				nativeBagOriginalParents[cf] = orig
			end
		end
		local targetParent = suppress and hiddenHost or (nativeBagOriginalParents[cf] or UIParent)
		pcall(cf.SetParent, cf, targetParent)
	end
	ApplyParent(_G.ContainerFrameCombinedBags)
	local maxNative = _G.NUM_CONTAINER_FRAMES or 13
	for i = 1, maxNative do
		ApplyParent(_G["ContainerFrame" .. i])
	end
end

function PluribusHiveInventory:HideNativeContainers()
	self:SyncNativeBagSuppression()
end

function PluribusHiveInventory:SyncNativeBagHooks()
	self:SyncNativeBagSuppression()
	local cfg = PluribusHive and PluribusHive:GetConfig()
	if cfg and cfg.replaceNativeBags == true then
		self:ToggleUnifiedBagWindow(true)
	else
		if self.unifiedBagFrame and self.unifiedBagFrame:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
			self.unifiedBagFrame:Hide()
		end
	end
end

local function GetOrCreateBagSlotButton(scrollContent, bag, slot)
	if not unifiedBagContainers[bag] then
		local bagWrap = CreateFrame("Frame", "PluribusUnifiedBagWrap" .. bag, scrollContent)
		bagWrap:SetAllPoints(scrollContent)
		bagWrap:SetID(bag)
		unifiedBagContainers[bag] = bagWrap
	end
	unifiedSlotButtons[bag] = unifiedSlotButtons[bag] or {}
	local btn = unifiedSlotButtons[bag][slot]
	if btn then return btn end

	if InCombatLockdown and InCombatLockdown() then
		return nil
	end

	local bagWrap = unifiedBagContainers[bag]
	local btnName = string.format("PluribusUnifiedBag_%d_Slot_%d", bag, slot)

	-- Use Blizzard's REAL native ItemButton + ContainerFrameItemButtonTemplate (zero taint, full native use/drag/sell/bank/mail!)
	local ok, created = pcall(CreateFrame, "ItemButton", btnName, bagWrap, "ContainerFrameItemButtonTemplate")
	if not ok or not created then
		ok, created = pcall(CreateFrame, "Button", btnName, bagWrap, "ContainerFrameItemButtonTemplate")
	end
	if not ok or not created then
		return nil
	end

	btn = created
	-- Use ONLY C-level Frame:SetID on parent (bag) and button (slot) — NEVER call btn:SetBagID(bag)
	-- because SetBagID writes a tainted Lua field `self.bagID` onto the ItemButton!
	btn:SetID(slot)
	btn:SetSize(37, 37)

	-- Separate mouse-disabled overlay frame so we NEVER write custom fields onto Blizzard's ItemButton
	local overlay = CreateFrame("Frame", nil, btn)
	overlay:SetAllPoints(btn)
	overlay:EnableMouse(false)
	unifiedSlotOverlays[btn] = overlay

	-- Uniform flat obsidian slot skinning (removes Blizzard's classic beveled quickslot border!)
	if _G.PluribusUIFramework and _G.PluribusUIFramework.SkinFlatItemSlot then
		_G.PluribusUIFramework:SkinFlatItemSlot(btn, overlay)
	end

	-- Subtle quality / custom-trash edge border (4 hairline textures on non-interactive overlay)
	local border = {}
	local top = overlay:CreateTexture(nil, "OVERLAY")
	top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
	top:SetHeight(2)
	local bot = overlay:CreateTexture(nil, "OVERLAY")
	bot:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
	bot:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
	bot:SetHeight(2)
	local lft = overlay:CreateTexture(nil, "OVERLAY")
	lft:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
	lft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
	lft:SetWidth(2)
	local rgt = overlay:CreateTexture(nil, "OVERLAY")
	rgt:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
	rgt:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
	rgt:SetWidth(2)
	border.edges = { top, bot, lft, rgt }
	for _, tex in ipairs(border.edges) do
		if tex.SetColorTexture then
			tex:SetColorTexture(0.20, 0.27, 0.38, 0.85)
		else
			tex:SetTexture("Interface\\Buttons\\WHITE8X8")
			tex:SetVertexColor(0.20, 0.27, 0.38, 0.85)
		end
	end
	unifiedSlotBorders[btn] = border

	local dot = overlay:CreateTexture(nil, "OVERLAY")
	dot:SetSize(8, 8)
	dot:SetPoint("TOPLEFT", overlay, "TOPLEFT", 3, -3)
	if dot.SetColorTexture then
		dot:SetColorTexture(0.24, 0.94, 0.48, 1)
	else
		dot:SetTexture("Interface\\Buttons\\WHITE8X8")
		dot:SetVertexColor(0.24, 0.94, 0.48, 1)
	end
	dot:Hide()
	unifiedUpgDots[btn] = dot

	-- Custom Trash indicator badge (bottom-left orange T tag when marked as auto-sell trash)
	local trashTag = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	trashTag:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 3, 2)
	trashTag:SetText("|cfff97316T|r")
	trashTag:Hide()
	unifiedTrashBadges[btn] = trashTag

	-- Post-hook OnClick ONLY (NEVER SetScript!) to support Alt+Click custom trash tagging
	if btn.HookScript then
		pcall(btn.HookScript, btn, "OnClick", function(selfBtn, mouseButton)
			if mouseButton == "LeftButton" and IsAltKeyDown and IsAltKeyDown() and not (CursorHasItem and CursorHasItem()) then
				local b = (selfBtn:GetParent() and selfBtn:GetParent():GetID()) or 0
				local s = selfBtn:GetID()
				local itemID = GetContainerSlotItem(b, s)
				if itemID then
					PluribusHiveInventory:ToggleCustomTrash(itemID)
				end
			end
		end)
	end

	unifiedSlotButtons[bag][slot] = btn
	return btn
end

local function SetSlotBorderColor(btn, r, g, b, a)
	local border = unifiedSlotBorders[btn]
	if not border or not border.edges then return end
	for _, tex in ipairs(border.edges) do
		if tex.SetColorTexture then
			tex:SetColorTexture(r, g, b, a or 0.95)
		else
			tex:SetVertexColor(r, g, b, a or 0.95)
		end
	end
end

local function UpdateSlotCooldown(btn, bag, slot)
	local btnName = btn.GetName and btn:GetName() or nil
	local cd = btn.Cooldown or (btnName and _G[btnName .. "Cooldown"]) or nil
	if not cd then return end
	local start, duration, enable = 0, 0, 0
	if C_Container and C_Container.GetContainerItemCooldown then
		start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
	elseif GetContainerItemCooldown then
		start, duration, enable = GetContainerItemCooldown(bag, slot)
	end
	if CooldownFrame_Set then
		pcall(CooldownFrame_Set, cd, start or 0, duration or 0, enable == 1 or enable == true)
	elseif cd.SetCooldown then
		if (duration or 0) > 0 then
			cd:SetCooldown(start or 0, duration or 0)
		else
			cd:Hide()
		end
	end
end

function PluribusHiveInventory:EnsureUnifiedBagWindow()
	if self.unifiedBagFrame then return self.unifiedBagFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end
	local L = _G.PluribusL

	-- Build standalone window (NOT added to UISpecialFrames and skips BringToFront subtree level walks on secure slots!)
	local p = UI.palette
	local f = CreateFrame("Frame", "PluribusUnifiedBagFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(468, 442)
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -48, 96)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f._plbIgnoreStackLevel = true
	UI:ApplyBackdrop(f, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local header = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	header:SetHeight(36)
	header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -2)
	header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -2)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	UI:ApplyBackdrop(header, p.header[1], p.header[2], p.header[3], p.header[4], p.border[1], p.border[2], p.border[3], 0.55)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", header, "LEFT", 12, 0)
	title:SetText(UI.colors.primary .. (L and L:Get("TAB_BAGS") or "Taschen") .. " — Pluribus|r")

	local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetTextColor(0.72, 0.80, 0.90, 1)
	sub:SetText("R: Benutzen · L: Ziehen · Alt+L: Trash")

	local closeBtn = UI:CreateButton(header, "X", 24, 22, function()
		if InCombatLockdown and InCombatLockdown() then
			UI:ShowNotification("Im Kampf gesperrt — schließt nach dem Kampf.", 2.0)
			return
		end
		f:Hide()
	end)
	closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	f.closeBtn = closeBtn

	local searchBox = UI:CreateInputBox(f, 106, 22, function()
		PluribusHiveInventory:RefreshUnifiedBagWindow()
	end)
	searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
	f.searchBox = searchBox

	local sortBtn = UI:CreateButton(f, "Sortieren", 66, 22, function()
		PluribusHiveInventory:SortPhysicalBags()
	end, true)
	sortBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
	f.sortBtn = sortBtn

	local junkBtn = UI:CreateButton(f, "Trash verk.", 74, 22, function()
		PluribusHiveInventory:SellGrayTrash(false)
		PluribusHiveInventory:RefreshUnifiedBagWindow()
	end)
	junkBtn:SetPoint("LEFT", sortBtn, "RIGHT", 4, 0)

	local trashMgrBtn = UI:CreateButton(f, "Trash (0)", 66, 22, function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveInventory:ToggleCustomTrash(itemID)
				if ClearCursor then pcall(ClearCursor) end
				return
			end
		end
		PluribusHiveInventory:ToggleTrashManagerWindow()
	end)
	trashMgrBtn:SetPoint("LEFT", junkBtn, "RIGHT", 4, 0)
	trashMgrBtn:SetScript("OnReceiveDrag", function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveInventory:ToggleCustomTrash(itemID)
				if ClearCursor then pcall(ClearCursor) end
			end
		end
	end)
	f.trashMgrBtn = trashMgrBtn

	local altBtn = UI:CreateButton(f, "Alts", 44, 22, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("Bags & Bank")
		end
	end)
	altBtn:SetPoint("LEFT", trashMgrBtn, "RIGHT", 4, 0)

	local nativeBtn = UI:CreateButton(f, "Std", 36, 22, function()
		if InCombatLockdown and InCombatLockdown() then return end
		PluribusHive:SetConfig("replaceNativeBags", false)
		PluribusHiveInventory:SyncNativeBagSuppression()
		f:Hide()
		if _G.OpenAllBags then pcall(_G.OpenAllBags) end
	end)
	nativeBtn:SetPoint("LEFT", altBtn, "RIGHT", 4, 0)

	-- Category filter strip + Sorted/Original view toggle (works safely even during combat!)
	self.unifiedCategory = self.unifiedCategory or "ALL"
	local catDefs = {
		{ key = "ALL", label = "Alle", w = 44 },
		{ key = "EQUIP", label = "Ausr.", w = 52 },
		{ key = "CONSUMABLE", label = "Verbr.", w = 54 },
		{ key = "CRAFT", label = "Handw.", w = 60 },
		{ key = "QUEST", label = "Quest", w = 52 },
		{ key = "TRASH", label = "Trash", w = 50 },
	}
	f.catButtons = {}
	local prevCat = nil
	for _, cd in ipairs(catDefs) do
		local cb = UI:CreateButton(f, cd.label, cd.w, 20, function()
			PluribusHiveInventory.unifiedCategory = cd.key
			for k, b in pairs(f.catButtons or {}) do
				if b.SetActiveState then b:SetActiveState(k == cd.key) end
			end
			PluribusHiveInventory:RefreshUnifiedBagWindow()
		end, cd.key == self.unifiedCategory)
		if prevCat then
			cb:SetPoint("LEFT", prevCat, "RIGHT", 3, 0)
		else
			cb:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
		end
		f.catButtons[cd.key] = cb
		prevCat = cb
	end

	local sortViewBtn = UI:CreateButton(f, self:IsBagSortedViewEnabled() and "Sortiert" or "Original", 72, 20, function()
		PluribusHiveInventory:SetBagSortedView(not PluribusHiveInventory:IsBagSortedViewEnabled())
	end, self:IsBagSortedViewEnabled())
	sortViewBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -72)
	f.sortViewBtn = sortViewBtn

	local scroll = UI:CreateScrollFrame(f, "PluribusUnifiedBagScroll", 440, 304)
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -98)
	f.scroll = scroll

	local footer = UI:CreateLabel(f, "", 0.85, 0.92, 0.98, "GameFontHighlightSmall")
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
	f.footer = footer

	f:Hide()
	self.unifiedBagFrame = f
	return f
end

function PluribusHiveInventory:EnsureTrashManagerWindow()
	if self.trashManagerFrame then return self.trashManagerFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local tf = UI:CreateFrame("PluribusTrashManagerFrame", UIParent, 310, 340,
		"Trash-Liste (Auto-Verkauf)",
		"Item ablegen oder Alt+Klick in Tasche")
	tf:SetFrameStrata("DIALOG")
	tf:SetPoint("RIGHT", self.unifiedBagFrame or UIParent, "LEFT", -10, 0)

	local dropBtn = UI:CreateButton(tf, "Item hier ablegen -> als Trash markieren", 282, 24, function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveInventory:ToggleCustomTrash(itemID)
				if ClearCursor then pcall(ClearCursor) end
			end
		end
	end, true)
	dropBtn:SetPoint("TOPLEFT", tf, "TOPLEFT", 14, -46)
	dropBtn:SetScript("OnReceiveDrag", function()
		if GetCursorInfo then
			local kind, itemID = GetCursorInfo()
			if kind == "item" and itemID then
				PluribusHiveInventory:ToggleCustomTrash(itemID)
				if ClearCursor then pcall(ClearCursor) end
			end
		end
	end)

	local scroll = UI:CreateScrollFrame(tf, "PluribusTrashManagerScroll", 282, 250)
	scroll:SetPoint("TOPLEFT", tf, "TOPLEFT", 14, -76)
	tf.scroll = scroll
	tf:Hide()
	self.trashManagerFrame = tf
	return tf
end

function PluribusHiveInventory:RefreshTrashManagerWindow()
	local tf = self.trashManagerFrame
	if not tf or not tf:IsShown() then return end
	local UI = _G.PluribusUIFramework
	local c = tf.scroll.content
	UI:ClearContainer(c)

	local list = self:GetCustomTrashList()
	local y = -2
	if #list == 0 then
		local em = UI:CreateLabel(c, "Noch keine Items markiert.\nAlt+Klick auf ein Item in deiner Tasche oder ziehe es oben auf den Button.", 0.72, 0.80, 0.90, "GameFontHighlightSmall")
		em:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
		em:SetWidth(258)
		c:SetHeight(120)
		return
	end

	for idx, it in ipairs(list) do
		local row = UI:CreateListRow(c, 260, 32, idx)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 2, y)

		local slot = UI:CreateItemSlot(row, 24, { itemID = it.itemID, name = it.name, link = it.link, quality = it.quality })
		slot:SetPoint("LEFT", row, "LEFT", 4, 0)

		local qCol = PluribusUtils:GetQualityColor(it.quality)
		local lbl = UI:CreateLabel(row, qCol .. (it.name or ("Item #" .. it.itemID)):sub(1, 22) .. "|r", 1, 1, 1, "GameFontHighlightSmall")
		lbl:SetPoint("LEFT", slot, "RIGHT", 6, 0)

		local rmBtn = UI:CreateButton(row, "X", 24, 20, function()
			PluribusHiveInventory:ToggleCustomTrash(it.itemID)
		end)
		rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		y = y - 34
	end
	c:SetHeight(math.max(240, math.abs(y) + 8))
end

function PluribusHiveInventory:ToggleTrashManagerWindow()
	local tf = self:EnsureTrashManagerWindow()
	if not tf then return end
	if tf:IsShown() then
		tf:Hide()
	else
		tf:ClearAllPoints()
		if self.unifiedBagFrame and self.unifiedBagFrame:IsShown() then
			tf:SetPoint("TOPRIGHT", self.unifiedBagFrame, "TOPLEFT", -8, 0)
		else
			tf:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		tf:Show()
		self:RefreshTrashManagerWindow()
	end
end

function PluribusHiveInventory:RefreshUnifiedBagWindow()
	local f = self.unifiedBagFrame
	if not f or not f:IsShown() then return end
	local c = f.scroll.content
	local inCombat = (InCombatLockdown and InCombatLockdown()) == true
	if inCombat then
		self.pendingUnifiedRefresh = true
	end

	local query = (f.searchBox and f.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""
	local activeCat = self.unifiedCategory or "ALL"
	local sortedView = self:IsBagSortedViewEnabled()
	if f.sortViewBtn then
		if f.sortViewBtn.SetText then f.sortViewBtn:SetText(sortedView and "Sortiert" or "Original") end
		if f.sortViewBtn.SetActiveState then f.sortViewBtn:SetActiveState(sortedView) end
	end

	local cols, slotSize, gap = 10, 37, 5
	local freeSlots, totalSlots, totalVal = 0, 0, 0
	local maxBag = NUM_BAG_SLOTS or 4
	local slotEntries = {}

	for bag = 0, maxBag do
		local slots = GetContainerSlots(bag)
		totalSlots = totalSlots + slots
		for slot = 1, slots do
			local btn = GetOrCreateBagSlotButton(c, bag, slot)
			local itemID, count, link, quality, isLocked = GetContainerSlotItem(bag, slot)

			if not itemID then
				freeSlots = freeSlots + 1
				table.insert(slotEntries, {
					bag = bag,
					slot = slot,
					btn = btn,
					itemID = nil,
					catOrder = 99,
					quality = -1,
					nameLower = "",
					count = 0,
					matches = (query == "" and activeCat == "ALL"),
				})
			else
				local name, infoLink, infoQ, _, _, itemType, _, _, _, icon, sellPrice, classID = PluribusUtils:GetItemInfo(itemID)
				local dName = name or ("Item #" .. itemID)
				local itemIcon = icon or PluribusUtils:GetItemIcon(itemID)
				local q = quality or infoQ or 1
				local ah = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(itemID)
				local unitVal = (ah and ah.copper and ah.copper > 0) and ah.copper or (tonumber(sellPrice) or 0)
				totalVal = totalVal + unitVal * (count or 1)

				local isCustomTrash = self:IsCustomTrash(itemID)
				local isUpg = false
				if _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.EvaluateItem and (link or infoLink) then
					local ev = _G.PluribusHiveGearJudge:EvaluateItem(link or infoLink)
					if ev and ev.isUpgrade then isUpg = true end
				end

				local itemCat = self:GetItemBagCategory(itemID, q, itemType, classID)
				local catMatch = (activeCat == "ALL") or (itemCat == activeCat)
				local matches = catMatch and ((query == "") or dName:lower():find(query, 1, true) ~= nil)

				table.insert(slotEntries, {
					bag = bag,
					slot = slot,
					btn = btn,
					itemID = itemID,
					count = count or 1,
					isLocked = isLocked == true,
					itemIcon = itemIcon,
					quality = q,
					nameLower = dName:lower(),
					catOrder = self:GetItemSortOrder(itemID, q, itemType, classID),
					isCustomTrash = isCustomTrash,
					isUpg = isUpg,
					matches = matches,
				})
			end
		end

		-- Hide any previously allocated slot buttons beyond current bag's slot count (out of combat only)
		if not inCombat and unifiedSlotButtons[bag] then
			for s, b in pairs(unifiedSlotButtons[bag]) do
				if s > slots and b then
					b:Hide()
				end
			end
		end
	end

	-- Display bags sorted by Category -> Quality -> Name (with matching filtered items first & empty slots last!)
	if sortedView and not inCombat then
		table.sort(slotEntries, function(a, b)
			local aHas = a.itemID ~= nil
			local bHas = b.itemID ~= nil
			if aHas ~= bHas then return aHas end
			if not aHas then
				if a.bag ~= b.bag then return a.bag < b.bag end
				return a.slot < b.slot
			end
			if (activeCat ~= "ALL" or query ~= "") and (a.matches ~= b.matches) then
				return a.matches
			end
			if a.catOrder ~= b.catOrder then return a.catOrder < b.catOrder end
			if a.quality ~= b.quality then return a.quality > b.quality end
			if a.nameLower ~= b.nameLower then return a.nameLower < b.nameLower end
			if a.count ~= b.count then return a.count > b.count end
			if a.bag ~= b.bag then return a.bag < b.bag end
			return a.slot < b.slot
		end)
	end

	for idx, entry in ipairs(slotEntries) do
		local btn = entry.btn
		if btn then
			if not inCombat then
				local col = (idx - 1) % cols
				local row = math.floor((idx - 1) / cols)
				btn:ClearAllPoints()
				btn:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + col * (slotSize + gap), -4 - row * (slotSize + gap))
				btn:Show()
			end

			if entry.itemID then
				if SetItemButtonTexture then
					pcall(SetItemButtonTexture, btn, entry.itemIcon)
				elseif btn.icon then
					btn.icon:SetTexture(entry.itemIcon)
				end
				if SetItemButtonCount then
					pcall(SetItemButtonCount, btn, entry.count or 1)
				end
				if SetItemButtonDesaturated then
					pcall(SetItemButtonDesaturated, btn, entry.isLocked == true)
				end
				local qc = QUALITY_BORDER_RGB[entry.quality] or QUALITY_BORDER_RGB[1]
				SetSlotBorderColor(btn, qc[1], qc[2], qc[3], 0.95)
				UpdateSlotCooldown(btn, entry.bag, entry.slot)

				if entry.isCustomTrash then
					SetSlotBorderColor(btn, 0.96, 0.38, 0.14, 0.98)
				end
				if unifiedTrashBadges[btn] then
					unifiedTrashBadges[btn]:SetShown(entry.isCustomTrash == true)
				end
				if unifiedUpgDots[btn] then
					unifiedUpgDots[btn]:SetShown(entry.isUpg == true)
				end
				btn:SetAlpha(entry.matches and 1.0 or 0.16)
			else
				-- Empty real bag slot (droppable for dragging items into empty slots!)
				if SetItemButtonTexture then
					pcall(SetItemButtonTexture, btn, nil)
				elseif btn.icon then
					btn.icon:SetTexture(nil)
				end
				if SetItemButtonCount then
					pcall(SetItemButtonCount, btn, 0)
				end
				if SetItemButtonDesaturated then
					pcall(SetItemButtonDesaturated, btn, false)
				end
				SetSlotBorderColor(btn, 0.20, 0.27, 0.38, 0.72)
				UpdateSlotCooldown(btn, entry.bag, entry.slot)
				if unifiedUpgDots[btn] then
					unifiedUpgDots[btn]:Hide()
				end
				if unifiedTrashBadges[btn] then
					unifiedTrashBadges[btn]:Hide()
				end
				btn:SetAlpha((query == "" and activeCat == "ALL") and 0.85 or 0.14)
			end
		end
	end

	if not inCombat then
		local totalRows = math.max(1, math.ceil(math.max(1, #slotEntries) / cols))
		c:SetHeight(math.max(284, totalRows * (slotSize + gap) + 12))
	end
	if f.trashMgrBtn and f.trashMgrBtn.SetText then
		f.trashMgrBtn:SetText(string.format("Trash (%d)", self:GetCustomTrashCount()))
	end
	local gold = GetMoney and GetMoney() or 0
	local dur = self:GetAverageDurabilityPct()
	local durCol = (dur >= 70 and "|cff4ade80") or (dur >= 35 and "|cfffbbf24") or "|cfff87171"
	f.footer:SetText(string.format("|cfffbbf24%s|r · |cff38bdf8%d/%d frei|r · Wert: |cff4ade80%s|r · Haltb.: %s%d%%|r",
		PluribusUtils:FormatGold(gold), freeSlots, totalSlots, PluribusUtils:FormatGold(totalVal), durCol, dur))
end

function PluribusHiveInventory:ToggleUnifiedBagWindow(forceOpen)
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	local f = self:EnsureUnifiedBagWindow()
	if not f then return end
	local shouldShow = (forceOpen ~= nil) and forceOpen or (not f:IsShown())
	if shouldShow then
		self:HideNativeContainers()
		f:Show()
		self:RefreshUnifiedBagWindow()
	else
		f:Hide()
	end
end

-- ============================================================================
-- UNIFIED PERSONAL BANK & GUILD BANK UI (Identical Flat Obsidian Bag UI!)
-- ============================================================================
-- Native Blizzard BankFrame & GuildBankFrame suppression helper:
-- NEVER calls :Hide() on BankFrame/GuildBankFrame (which immediately disconnects the server bank session!).
-- Instead moves the native frame offscreen with alpha 0 & scale 0.001 so IsShown() stays true and the
-- server session remains 100% live, restoring original position/scale/alpha cleanly when switching to "Std".
local nativeFrameSavedState = {}
local function SuppressOffscreenNativeFrame(frame, suppress)
	if not frame then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if suppress then
		if not nativeFrameSavedState[frame] then
			local pt, rel, relPt, x, y = nil, nil, nil, nil, nil
			if frame.GetPoint then
				pt, rel, relPt, x, y = frame:GetPoint(1)
			end
			nativeFrameSavedState[frame] = {
				alpha = (frame.GetAlpha and frame:GetAlpha()) or 1,
				scale = (frame.GetScale and frame:GetScale()) or 1,
				pt = pt, rel = rel, relPt = relPt, x = x, y = y,
			}
		end
		pcall(frame.SetAlpha, frame, 0)
		pcall(frame.SetScale, frame, 0.001)
		pcall(frame.EnableMouse, frame, false)
		pcall(frame.ClearAllPoints, frame)
		pcall(frame.SetPoint, frame, "TOPLEFT", UIParent, "BOTTOMRIGHT", 2400, -2400)
	else
		local st = nativeFrameSavedState[frame]
		if st then
			pcall(frame.SetAlpha, frame, st.alpha or 1)
			pcall(frame.SetScale, frame, st.scale or 1)
			pcall(frame.EnableMouse, frame, true)
			pcall(frame.ClearAllPoints, frame)
			if st.pt then
				pcall(frame.SetPoint, frame, st.pt, st.rel or UIParent, st.relPt or st.pt, st.x or 0, st.y or 0)
			else
				pcall(frame.SetPoint, frame, "TOPLEFT", UIParent, "TOPLEFT", 20, -110)
			end
			nativeFrameSavedState[frame] = nil
		end
	end
end

function PluribusHiveInventory:IsUnifiedUIEnabled()
	local cfg = _G.PluribusHive and _G.PluribusHive:GetConfig()
	return cfg and cfg.replaceNativeBags == true or false
end

function PluribusHiveInventory:IsUnifiedGuildBankActive()
	return self.guildBankOpen == true and self:IsUnifiedUIEnabled() and self.unifiedGuildBankFrame and self.unifiedGuildBankFrame:IsShown() == true
end

-- Module-local slot registries for Unified Bank (zero fields written onto Blizzard secure ItemButtons!)
local unifiedBankContainers = {}
local unifiedBankSlotButtons = {}
local unifiedBankSlotOverlays = {}
local unifiedBankSlotBorders = {}
local unifiedBankUpgDots = {}

local function SetBankSlotBorderColor(btn, r, g, b, a)
	local border = unifiedBankSlotBorders[btn]
	if not border or not border.edges then return end
	for _, tex in ipairs(border.edges) do
		if tex.SetColorTexture then
			tex:SetColorTexture(r, g, b, a or 0.95)
		else
			tex:SetTexture("Interface\\Buttons\\WHITE8X8")
			tex:SetVertexColor(r, g, b, a or 0.95)
		end
	end
end

local function GetOrCreateBankSlotButton(scrollContent, bag, slot)
	local bankContainerId = BANK_CONTAINER or -1
	if not unifiedBankContainers[bag] then
		local wrap = CreateFrame("Frame", "PluribusUnifiedBankWrap_" .. tostring(bag), scrollContent)
		wrap:SetAllPoints(scrollContent)
		wrap:SetID(bag)
		unifiedBankContainers[bag] = wrap
	end
	unifiedBankSlotButtons[bag] = unifiedBankSlotButtons[bag] or {}
	local btn = unifiedBankSlotButtons[bag][slot]
	if btn then return btn end

	if InCombatLockdown and InCombatLockdown() then
		return nil
	end

	local wrap = unifiedBankContainers[bag]
	local btnName = string.format("PluribusUnifiedBank_%s_Slot_%d", tostring(bag):gsub("%-", "M"), slot)
	local template = (bag == bankContainerId) and "BankItemButtonGenericTemplate" or "ContainerFrameItemButtonTemplate"

	local ok, created = pcall(CreateFrame, "ItemButton", btnName, wrap, template)
	if not ok or not created then
		ok, created = pcall(CreateFrame, "Button", btnName, wrap, template)
	end
	if not ok or not created then
		ok, created = pcall(CreateFrame, "Button", btnName, wrap, "ContainerFrameItemButtonTemplate")
	end
	if not ok or not created then
		return nil
	end

	btn = created
	btn:SetID(slot)
	btn:SetSize(37, 37)

	local overlay = CreateFrame("Frame", nil, btn)
	overlay:SetAllPoints(btn)
	overlay:EnableMouse(false)
	unifiedBankSlotOverlays[btn] = overlay

	if _G.PluribusUIFramework and _G.PluribusUIFramework.SkinFlatItemSlot then
		_G.PluribusUIFramework:SkinFlatItemSlot(btn, overlay)
	end

	local border = {}
	local top = overlay:CreateTexture(nil, "OVERLAY")
	top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
	top:SetHeight(2)
	local bot = overlay:CreateTexture(nil, "OVERLAY")
	bot:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
	bot:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
	bot:SetHeight(2)
	local lft = overlay:CreateTexture(nil, "OVERLAY")
	lft:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
	lft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
	lft:SetWidth(2)
	local rgt = overlay:CreateTexture(nil, "OVERLAY")
	rgt:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
	rgt:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
	rgt:SetWidth(2)
	border.edges = { top, bot, lft, rgt }
	unifiedBankSlotBorders[btn] = border
	SetBankSlotBorderColor(btn, 0.20, 0.27, 0.38, 0.85)

	local dot = overlay:CreateTexture(nil, "OVERLAY")
	dot:SetSize(8, 8)
	dot:SetPoint("TOPLEFT", overlay, "TOPLEFT", 3, -3)
	if dot.SetColorTexture then
		dot:SetColorTexture(0.24, 0.94, 0.48, 1)
	else
		dot:SetTexture("Interface\\Buttons\\WHITE8X8")
		dot:SetVertexColor(0.24, 0.94, 0.48, 1)
	end
	dot:Hide()
	unifiedBankUpgDots[btn] = dot

	unifiedBankSlotButtons[bag][slot] = btn
	return btn
end

function PluribusHiveInventory:EnsureUnifiedBankWindow()
	if self.unifiedBankFrame then return self.unifiedBankFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end
	local p = UI.palette

	local f = CreateFrame("Frame", "PluribusUnifiedBankFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(468, 480)
	f:SetPoint("CENTER", UIParent, "CENTER", -220, 20)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f._plbIgnoreStackLevel = true
	UI:ApplyBackdrop(f, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local accentLine = f:CreateTexture(nil, "OVERLAY")
	accentLine:SetHeight(2)
	accentLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	accentLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	if accentLine.SetColorTexture then
		accentLine:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
	else
		accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
		accentLine:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1)
	end

	local header = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	header:SetHeight(36)
	header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
	header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	UI:ApplyBackdrop(header, p.header[1], p.header[2], p.header[3], p.header[4], p.border[1], p.border[2], p.border[3], 0.55)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", header, "LEFT", 12, 0)
	title:SetText(UI.colors.primary .. "Bank — Pluribus|r")

	local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetTextColor(0.72, 0.80, 0.90, 1)
	sub:SetText("R: Entnehmen · L: Ziehen")

	local closeBtn = UI:CreateButton(header, "X", 24, 22, function()
		if CloseBankFrame then pcall(CloseBankFrame) end
		f:Hide()
	end)
	closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

	local searchBox = UI:CreateInputBox(f, 134, 22, function()
		PluribusHiveInventory:RefreshUnifiedBankWindow()
	end)
	searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
	f.searchBox = searchBox

	local sortBtn = UI:CreateButton(f, "Sortieren", 68, 22, function()
		PluribusHiveInventory:SortPhysicalBank()
	end, true)
	sortBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)

	local buySlotBtn = UI:CreateButton(f, "+ Fach", 96, 22, function()
		if PurchaseSlot then
			pcall(PurchaseSlot)
			if C_Timer and C_Timer.After then
				C_Timer.After(0.25, function()
					PluribusHiveInventory:ScanBank()
					PluribusHiveInventory:RefreshUnifiedBankWindow()
				end)
			end
		end
	end)
	buySlotBtn:SetPoint("LEFT", sortBtn, "RIGHT", 4, 0)
	f.buySlotBtn = buySlotBtn

	local altBtn = UI:CreateButton(f, "Alts", 48, 22, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("Bags & Bank")
		end
	end)
	altBtn:SetPoint("LEFT", buySlotBtn, "RIGHT", 4, 0)

	local stdBtn = UI:CreateButton(f, "Std", 38, 22, function()
		if InCombatLockdown and InCombatLockdown() then return end
		PluribusHive:SetConfig("replaceNativeBags", false)
		PluribusHiveInventory:SyncNativeBagSuppression()
		SuppressOffscreenNativeFrame(_G.BankFrame, false)
		f:Hide()
	end)
	stdBtn:SetPoint("LEFT", altBtn, "RIGHT", 4, 0)

	self.unifiedBankCategory = self.unifiedBankCategory or "ALL"
	local catDefs = {
		{ key = "ALL", label = "Alle", w = 44 },
		{ key = "EQUIP", label = "Ausr.", w = 52 },
		{ key = "CONSUMABLE", label = "Verbr.", w = 54 },
		{ key = "CRAFT", label = "Handw.", w = 60 },
		{ key = "QUEST", label = "Quest", w = 52 },
		{ key = "TRASH", label = "Trash", w = 50 },
	}
	f.catButtons = {}
	local prevCat = nil
	for _, cd in ipairs(catDefs) do
		local cb = UI:CreateButton(f, cd.label, cd.w, 20, function()
			PluribusHiveInventory.unifiedBankCategory = cd.key
			for k, b in pairs(f.catButtons or {}) do
				if b.SetActiveState then b:SetActiveState(k == cd.key) end
			end
			PluribusHiveInventory:RefreshUnifiedBankWindow()
		end, cd.key == self.unifiedBankCategory)
		if prevCat then
			cb:SetPoint("LEFT", prevCat, "RIGHT", 3, 0)
		else
			cb:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
		end
		f.catButtons[cd.key] = cb
		prevCat = cb
	end

	local sortViewBtn = UI:CreateButton(f, self:IsBagSortedViewEnabled() and "Sortiert" or "Original", 72, 20, function()
		PluribusHiveInventory:SetBagSortedView(not PluribusHiveInventory:IsBagSortedViewEnabled())
		PluribusHiveInventory:RefreshUnifiedBankWindow()
	end, self:IsBagSortedViewEnabled())
	sortViewBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -72)
	f.sortViewBtn = sortViewBtn

	local bagInfoLbl = UI:CreateLabel(f, "", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
	bagInfoLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -96)
	f.bagInfoLbl = bagInfoLbl

	local scroll = UI:CreateScrollFrame(f, "PluribusUnifiedBankScroll", 440, 326)
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -114)
	f.scroll = scroll

	local footer = UI:CreateLabel(f, "", 0.85, 0.92, 0.98, "GameFontHighlightSmall")
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
	f.footer = footer

	f:Hide()
	self.unifiedBankFrame = f
	return f
end

function PluribusHiveInventory:RefreshUnifiedBankWindow()
	local f = self.unifiedBankFrame
	if not f or not f:IsShown() then return end
	local c = f.scroll.content
	local inCombat = (InCombatLockdown and InCombatLockdown()) == true

	local query = (f.searchBox and f.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""
	local activeCat = self.unifiedBankCategory or "ALL"
	local sortedView = self:IsBagSortedViewEnabled()
	if f.sortViewBtn then
		if f.sortViewBtn.SetText then f.sortViewBtn:SetText(sortedView and "Sortiert" or "Original") end
		if f.sortViewBtn.SetActiveState then f.sortViewBtn:SetActiveState(sortedView) end
	end

	-- Update bank bag slot purchase button
	local numSlotsBought, isFull = 0, true
	if GetNumBankSlots then
		numSlotsBought, isFull = GetNumBankSlots()
	end
	if f.buySlotBtn then
		if isFull then
			f.buySlotBtn:SetText("Alle Fächer")
			f.buySlotBtn:SetAlpha(0.55)
		else
			local cost = GetBankSlotCost and GetBankSlotCost(numSlotsBought) or 0
			f.buySlotBtn:SetText("+ Fach (" .. PluribusUtils:FormatGold(cost) .. ")")
			f.buySlotBtn:SetAlpha(1.0)
		end
	end

	local cols, slotSize, gap = 10, 37, 5
	local freeSlots, totalSlots, totalVal = 0, 0, 0
	local slotEntries = {}
	local bankContainerId = BANK_CONTAINER or -1
	local bagList = { bankContainerId }
	local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
	local lastBankBag = firstBankBag + (NUM_BANKBAGSLOTS or 6) - 1
	local equippedBankBags = 0
	for bag = firstBankBag, lastBankBag do
		local bSlots = GetContainerSlots(bag)
		if bSlots > 0 then equippedBankBags = equippedBankBags + 1 end
		table.insert(bagList, bag)
	end

	for _, bag in ipairs(bagList) do
		local slots = GetContainerSlots(bag)
		totalSlots = totalSlots + slots
		for slot = 1, slots do
			local btn = GetOrCreateBankSlotButton(c, bag, slot)
			local itemID, count, link, quality, isLocked = GetContainerSlotItem(bag, slot)

			if not itemID then
				freeSlots = freeSlots + 1
				table.insert(slotEntries, {
					bag = bag, slot = slot, btn = btn, itemID = nil,
					catOrder = 99, quality = -1, nameLower = "", count = 0,
					matches = (query == "" and activeCat == "ALL"),
				})
			else
				local name, infoLink, infoQ, _, _, itemType, _, _, _, icon, sellPrice, classID = PluribusUtils:GetItemInfo(itemID)
				local dName = name or ("Item #" .. itemID)
				local itemIcon = icon or PluribusUtils:GetItemIcon(itemID)
				local q = quality or infoQ or 1
				local ah = _G.PluribusHiveAuction and _G.PluribusHiveAuction:GetPrice(itemID)
				local unitVal = (ah and ah.copper and ah.copper > 0) and ah.copper or (tonumber(sellPrice) or 0)
				totalVal = totalVal + unitVal * (count or 1)

				local isUpg = false
				if _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.EvaluateItem and (link or infoLink) then
					local ev = _G.PluribusHiveGearJudge:EvaluateItem(link or infoLink)
					if ev and ev.isUpgrade then isUpg = true end
				end

				local itemCat = self:GetItemBagCategory(itemID, q, itemType, classID)
				local catMatch = (activeCat == "ALL") or (itemCat == activeCat)
				local matches = catMatch and ((query == "") or dName:lower():find(query, 1, true) ~= nil)

				table.insert(slotEntries, {
					bag = bag, slot = slot, btn = btn, itemID = itemID,
					count = count or 1, isLocked = isLocked == true,
					itemIcon = itemIcon, quality = q, nameLower = dName:lower(),
					catOrder = self:GetItemSortOrder(itemID, q, itemType, classID),
					isUpg = isUpg, matches = matches,
				})
			end
		end

		if not inCombat and unifiedBankSlotButtons[bag] then
			for s, b in pairs(unifiedBankSlotButtons[bag]) do
				if s > slots and b then b:Hide() end
			end
		end
	end

	if sortedView and not inCombat then
		table.sort(slotEntries, function(a, b)
			local aHas = a.itemID ~= nil
			local bHas = b.itemID ~= nil
			if aHas ~= bHas then return aHas end
			if not aHas then
				if a.bag ~= b.bag then return a.bag < b.bag end
				return a.slot < b.slot
			end
			if (activeCat ~= "ALL" or query ~= "") and (a.matches ~= b.matches) then
				return a.matches
			end
			if a.catOrder ~= b.catOrder then return a.catOrder < b.catOrder end
			if a.quality ~= b.quality then return a.quality > b.quality end
			if a.nameLower ~= b.nameLower then return a.nameLower < b.nameLower end
			if a.count ~= b.count then return a.count > b.count end
			if a.bag ~= b.bag then return a.bag < b.bag end
			return a.slot < b.slot
		end)
	end

	for idx, entry in ipairs(slotEntries) do
		local btn = entry.btn
		if btn then
			if not inCombat then
				local col = (idx - 1) % cols
				local row = math.floor((idx - 1) / cols)
				btn:ClearAllPoints()
				btn:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + col * (slotSize + gap), -4 - row * (slotSize + gap))
				btn:Show()
			end

			if entry.itemID then
				if SetItemButtonTexture then pcall(SetItemButtonTexture, btn, entry.itemIcon)
				elseif btn.icon then btn.icon:SetTexture(entry.itemIcon) end
				if SetItemButtonCount then pcall(SetItemButtonCount, btn, entry.count or 1) end
				if SetItemButtonDesaturated then pcall(SetItemButtonDesaturated, btn, entry.isLocked == true) end
				local qc = QUALITY_BORDER_RGB[entry.quality] or QUALITY_BORDER_RGB[1]
				SetBankSlotBorderColor(btn, qc[1], qc[2], qc[3], 0.95)
				if unifiedBankUpgDots[btn] then unifiedBankUpgDots[btn]:SetShown(entry.isUpg == true) end
				btn:SetAlpha(entry.matches and 1.0 or 0.16)
			else
				if SetItemButtonTexture then pcall(SetItemButtonTexture, btn, nil)
				elseif btn.icon then btn.icon:SetTexture(nil) end
				if SetItemButtonCount then pcall(SetItemButtonCount, btn, 0) end
				if SetItemButtonDesaturated then pcall(SetItemButtonDesaturated, btn, false) end
				SetBankSlotBorderColor(btn, 0.20, 0.27, 0.38, 0.72)
				if unifiedBankUpgDots[btn] then unifiedBankUpgDots[btn]:Hide() end
				btn:SetAlpha((query == "" and activeCat == "ALL") and 0.85 or 0.14)
			end
		end
	end

	if not inCombat then
		local totalRows = math.max(1, math.ceil(math.max(1, #slotEntries) / cols))
		c:SetHeight(math.max(306, totalRows * (slotSize + gap) + 12))
	end

	if f.bagInfoLbl then
		f.bagInfoLbl:SetText(string.format("Bank-Taschen: |cff38bdf8%d/%d gekauft|r · |cff4ade80%d ausgerüstet|r",
			tonumber(numSlotsBought) or 0, NUM_BANKBAGSLOTS or 6, equippedBankBags))
	end
	local gold = GetMoney and GetMoney() or 0
	f.footer:SetText(string.format("|cfffbbf24%s|r · Bank: |cff38bdf8%d/%d frei|r · Bankwert: |cff4ade80%s|r",
		PluribusUtils:FormatGold(gold), freeSlots, totalSlots, PluribusUtils:FormatGold(totalVal)))
end

function PluribusHiveInventory:OpenUnifiedBankWindow()
	if InCombatLockdown and InCombatLockdown() then return end
	if not self:IsUnifiedUIEnabled() then
		SuppressOffscreenNativeFrame(_G.BankFrame, false)
		return
	end
	SuppressOffscreenNativeFrame(_G.BankFrame, true)
	local f = self:EnsureUnifiedBankWindow()
	if not f then return end
	f:Show()
	self:RefreshUnifiedBankWindow()
	-- Open Unified Bags right alongside Unified Bank for effortless dragging & right-click deposits!
	self:ToggleUnifiedBagWindow(true)
	if self.unifiedBagFrame and self.unifiedBagFrame:IsShown() then
		self.unifiedBagFrame:ClearAllPoints()
		self.unifiedBagFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 10, 0)
	end
end

function PluribusHiveInventory:CloseUnifiedBankWindow()
	if self.unifiedBankFrame and self.unifiedBankFrame:IsShown() then
		self.unifiedBankFrame:Hide()
	end
	SuppressOffscreenNativeFrame(_G.BankFrame, false)
end

-- ============================================================================
-- UNIFIED GUILD BANK UI (Same Flat Obsidian Bag UI + Integrated Guild Tax!)
-- ============================================================================
local MAX_GUILDBANK_SLOTS_PER_TAB = 98

local function CreateGuildBankSlotButton(parent, index)
	local gbSlot = CreateFrame("Button", "PluribusUnifiedGBSlot_" .. index, parent)
	gbSlot:SetSize(37, 37)
	gbSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	gbSlot:RegisterForDrag("LeftButton")

	local bg = gbSlot:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", gbSlot, "TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", -1, 1)
	if bg.SetColorTexture then bg:SetColorTexture(0.05, 0.07, 0.11, 0.94)
	else bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0.05, 0.07, 0.11, 0.94) end

	local icon = gbSlot:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", gbSlot, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", -2, 2)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	gbSlot.icon = icon

	local hl = gbSlot:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", gbSlot, "TOPLEFT", 2, -2)
	hl:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", -2, 2)
	if hl.SetColorTexture then hl:SetColorTexture(0.22, 0.74, 0.97, 0.24)
	else hl:SetTexture("Interface\\Buttons\\WHITE8X8"); hl:SetVertexColor(0.22, 0.74, 0.97, 0.24) end

	local countText = gbSlot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	countText:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", -3, 3)
	countText:SetTextColor(1, 1, 1, 1)
	gbSlot.countText = countText

	local top = gbSlot:CreateTexture(nil, "OVERLAY")
	top:SetPoint("TOPLEFT", gbSlot, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", gbSlot, "TOPRIGHT", 0, 0); top:SetHeight(2)
	local bot = gbSlot:CreateTexture(nil, "OVERLAY")
	bot:SetPoint("BOTTOMLEFT", gbSlot, "BOTTOMLEFT", 0, 0); bot:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", 0, 0); bot:SetHeight(2)
	local lft = gbSlot:CreateTexture(nil, "OVERLAY")
	lft:SetPoint("TOPLEFT", gbSlot, "TOPLEFT", 0, 0); lft:SetPoint("BOTTOMLEFT", gbSlot, "BOTTOMLEFT", 0, 0); lft:SetWidth(2)
	local rgt = gbSlot:CreateTexture(nil, "OVERLAY")
	rgt:SetPoint("TOPRIGHT", gbSlot, "TOPRIGHT", 0, 0); rgt:SetPoint("BOTTOMRIGHT", gbSlot, "BOTTOMRIGHT", 0, 0); rgt:SetWidth(2)
	gbSlot._edges = { top, bot, lft, rgt }

	function gbSlot:SetBorderRGB(r, g, b, a)
		for _, tex in ipairs(self._edges) do
			if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a or 0.95)
			else tex:SetTexture("Interface\\Buttons\\WHITE8X8"); tex:SetVertexColor(r, g, b, a or 0.95) end
		end
	end
	gbSlot:SetBorderRGB(0.20, 0.27, 0.38, 0.80)

	gbSlot:SetScript("OnEnter", function(selfSlot)
		if GameTooltip and selfSlot._gbTab and selfSlot._gbSlot then
			GameTooltip:SetOwner(selfSlot, "ANCHOR_RIGHT")
			if GameTooltip.SetGuildBankItem then
				pcall(GameTooltip.SetGuildBankItem, GameTooltip, selfSlot._gbTab, selfSlot._gbSlot)
			end
			GameTooltip:Show()
		end
	end)
	gbSlot:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	gbSlot:SetScript("OnClick", function(selfSlot, mouseBtn)
		local tab, slot = selfSlot._gbTab, selfSlot._gbSlot
		if not tab or not slot then return end
		if mouseBtn == "RightButton" then
			if AutoStoreGuildBankItem then
				pcall(AutoStoreGuildBankItem, tab, slot)
			end
			return
		end
		if IsShiftKeyDown and IsShiftKeyDown() then
			local link = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot)
			if link and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then
				pcall(ChatEdit_InsertLink, link)
				return
			end
			local _, count = GetGuildBankItemInfo and GetGuildBankItemInfo(tab, slot)
			if count and count > 1 and OpenStackSplitFrame then
				selfSlot.SplitStack = function(_, splitAmt)
					if SplitGuildBankItem then pcall(SplitGuildBankItem, tab, slot, splitAmt) end
				end
				pcall(OpenStackSplitFrame, count, selfSlot, "BOTTOMLEFT", "TOPLEFT")
				return
			end
		end
		if PickupGuildBankItem then
			pcall(PickupGuildBankItem, tab, slot)
		end
	end)
	gbSlot:SetScript("OnDragStart", function(selfSlot)
		if selfSlot._gbTab and selfSlot._gbSlot and PickupGuildBankItem then
			pcall(PickupGuildBankItem, selfSlot._gbTab, selfSlot._gbSlot)
		end
	end)
	gbSlot:SetScript("OnReceiveDrag", function(selfSlot)
		if selfSlot._gbTab and selfSlot._gbSlot and PickupGuildBankItem then
			pcall(PickupGuildBankItem, selfSlot._gbTab, selfSlot._gbSlot)
		end
	end)

	return gbSlot
end

function PluribusHiveInventory:EnsureUnifiedGuildBankWindow()
	if self.unifiedGuildBankFrame then return self.unifiedGuildBankFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end
	local p = UI.palette

	local f = CreateFrame("Frame", "PluribusUnifiedGuildBankFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(492, 540)
	f:SetPoint("CENTER", UIParent, "CENTER", -225, 16)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f._plbIgnoreStackLevel = true
	UI:ApplyBackdrop(f, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local accentLine = f:CreateTexture(nil, "OVERLAY")
	accentLine:SetHeight(2)
	accentLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	accentLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	if accentLine.SetColorTexture then accentLine:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
	else accentLine:SetTexture("Interface\\Buttons\\WHITE8X8"); accentLine:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1) end

	local header = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	header:SetHeight(36)
	header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
	header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	UI:ApplyBackdrop(header, p.header[1], p.header[2], p.header[3], p.header[4], p.border[1], p.border[2], p.border[3], 0.55)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", header, "LEFT", 12, 0)
	title:SetText(UI.colors.primary .. "Gildenbank — Pluribus|r")
	f.title = title

	local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetTextColor(0.72, 0.80, 0.90, 1)
	sub:SetText("R: Entnehmen · L: Ziehen")
	f.sub = sub

	local closeBtn = UI:CreateButton(header, "X", 24, 22, function()
		if CloseGuildBankFrame then pcall(CloseGuildBankFrame) end
		f:Hide()
	end)
	closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

	-- Guild Bank Tab Strip (up to 8 flat obsidian tab buttons with icons)
	local tabStrip = CreateFrame("Frame", nil, f)
	tabStrip:SetSize(464, 28)
	tabStrip:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -44)
	f.tabStrip = tabStrip
	f.gbTabButtons = {}

	-- Search & action row
	local searchBox = UI:CreateInputBox(f, 168, 22, function()
		PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
	end)
	searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -76)
	f.searchBox = searchBox

	local sortViewBtn = UI:CreateButton(f, self:IsBagSortedViewEnabled() and "Sortiert" or "Original", 72, 22, function()
		PluribusHiveInventory:SetBagSortedView(not PluribusHiveInventory:IsBagSortedViewEnabled())
		PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
	end, self:IsBagSortedViewEnabled())
	sortViewBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
	f.sortViewBtn = sortViewBtn

	local queryBtn = UI:CreateButton(f, "Aktual.", 56, 22, function()
		local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
		if QueryGuildBankTab then pcall(QueryGuildBankTab, cur) end
		PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
	end)
	queryBtn:SetPoint("LEFT", sortViewBtn, "RIGHT", 4, 0)

	local taxHubBtn = UI:CreateButton(f, "Steuer-Tab", 72, 22, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("Guild Tax")
		end
	end)
	taxHubBtn:SetPoint("LEFT", queryBtn, "RIGHT", 4, 0)

	local stdBtn = UI:CreateButton(f, "Std", 38, 22, function()
		if InCombatLockdown and InCombatLockdown() then return end
		PluribusHive:SetConfig("replaceNativeBags", false)
		PluribusHiveInventory:SyncNativeBagSuppression()
		SuppressOffscreenNativeFrame(_G.GuildBankFrame, false)
		f:Hide()
		if _G.PluribusHiveTax and _G.PluribusHiveTax.AttachToGuildBank then
			_G.PluribusHiveTax:AttachToGuildBank()
		end
	end)
	stdBtn:SetPoint("LEFT", taxHubBtn, "RIGHT", 4, 0)

	-- Category filter strip
	self.unifiedGBCategory = self.unifiedGBCategory or "ALL"
	local catDefs = {
		{ key = "ALL", label = "Alle", w = 48 },
		{ key = "EQUIP", label = "Ausr.", w = 56 },
		{ key = "CONSUMABLE", label = "Verbr.", w = 58 },
		{ key = "CRAFT", label = "Handw.", w = 64 },
		{ key = "QUEST", label = "Quest", w = 56 },
		{ key = "TRASH", label = "Trash", w = 54 },
	}
	f.catButtons = {}
	local prevCat = nil
	for _, cd in ipairs(catDefs) do
		local cb = UI:CreateButton(f, cd.label, cd.w, 20, function()
			PluribusHiveInventory.unifiedGBCategory = cd.key
			for k, b in pairs(f.catButtons or {}) do
				if b.SetActiveState then b:SetActiveState(k == cd.key) end
			end
			PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
		end, cd.key == self.unifiedGBCategory)
		if prevCat then cb:SetPoint("LEFT", prevCat, "RIGHT", 4, 0)
		else cb:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -102) end
		f.catButtons[cd.key] = cb
		prevCat = cb
	end

	-- Scrollable 98-slot Guild Bank Grid (10 columns)
	local scroll = UI:CreateScrollFrame(f, "PluribusUnifiedGBScroll", 464, 330)
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -128)
	f.scroll = scroll
	f.gbSlots = {}
	for i = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
		f.gbSlots[i] = CreateGuildBankSlotButton(scroll.content, i)
	end

	-- Integrated Footer Card: Gold Balance + Deposit/Withdraw + 1-Click Guild Tax Payment (NO patchwork floating bar!)
	local footerCard = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	footerCard:SetSize(464, 68)
	footerCard:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 10)
	UI:ApplyBackdrop(footerCard, p.panel[1], p.panel[2], p.panel[3], 0.96, p.border[1], p.border[2], p.border[3], 0.75)
	f.footerCard = footerCard

	local goldLbl = UI:CreateLabel(footerCard, "Gildenbank: |cfffbbf240c|r", 0.90, 0.94, 0.98, "GameFontHighlightSmall")
	goldLbl:SetPoint("TOPLEFT", footerCard, "TOPLEFT", 8, -8)
	f.goldLbl = goldLbl

	local amtBox = UI:CreateInputBox(footerCard, 56, 20)
	amtBox:SetPoint("TOPRIGHT", footerCard, "TOPRIGHT", -144, -5)
	amtBox:SetText("10")
	f.amtBox = amtBox

	local gSuffix = UI:CreateLabel(footerCard, "|cfffbbf24g|r", 1, 1, 1, "GameFontHighlightSmall")
	gSuffix:SetPoint("LEFT", amtBox, "RIGHT", 3, 0)

	local depBtn = UI:CreateButton(footerCard, "Einzahlen", 62, 20, function()
		local g = tonumber(amtBox:GetText()) or 0
		local copper = math.floor(g * 10000 + 0.5)
		if copper > 0 and DepositGuildBankMoney then
			pcall(DepositGuildBankMoney, copper)
		end
	end)
	depBtn:SetPoint("LEFT", gSuffix, "RIGHT", 4, 0)

	local wdBtn = UI:CreateButton(footerCard, "Abheben", 58, 20, function()
		local g = tonumber(amtBox:GetText()) or 0
		local copper = math.floor(g * 10000 + 0.5)
		if copper > 0 and WithdrawGuildBankMoney then
			pcall(WithdrawGuildBankMoney, copper)
		end
	end)
	wdBtn:SetPoint("LEFT", depBtn, "RIGHT", 4, 0)
	f.wdBtn = wdBtn

	-- Row 2: Integrated Guild Tax Strip
	local taxLbl = UI:CreateLabel(footerCard, "|cfffbbf24Gildensteuer:|r |cff4ade80Alles bezahlt|r", 1, 1, 1, "GameFontHighlightSmall")
	taxLbl:SetPoint("BOTTOMLEFT", footerCard, "BOTTOMLEFT", 8, 9)
	f.taxLbl = taxLbl

	local payTaxBtn = UI:CreateButton(footerCard, "Steuern tilgen", 184, 22, function()
		if _G.PluribusHiveTax and _G.PluribusHiveTax.DepositTaxToGuildBank then
			_G.PluribusHiveTax:DepositTaxToGuildBank()
		end
		PluribusHiveInventory:RefreshUnifiedGuildBankTaxStrip()
	end, true)
	payTaxBtn:SetPoint("BOTTOMRIGHT", footerCard, "BOTTOMRIGHT", -8, 6)
	f.payTaxBtn = payTaxBtn

	f:Hide()
	self.unifiedGuildBankFrame = f
	return f
end

function PluribusHiveInventory:RefreshUnifiedGuildBankTaxStrip()
	local f = self.unifiedGuildBankFrame
	if not f or not f.taxLbl or not f.payTaxBtn then return end
	local tax = _G.PluribusHiveTax
	if not tax then
		f.taxLbl:SetText("|cff94a3b8Gildensteuer nicht aktiv|r")
		f.payTaxBtn:SetEnabled(false)
		f.payTaxBtn:SetAlpha(0.5)
		return
	end
	local due = tax:GetBalanceDue()
	local cash = (GetMoney and GetMoney()) or 0
	local pol = tax:GetPolicy()
	if due > 0 then
		f.taxLbl:SetText(string.format("|cfffbbf24Gildensteuer (%d%%):|r |cfff87171%s offen|r",
			math.floor(pol.ratePct or 0), PluribusUtils:FormatGold(due)))
		if cash >= due then
			f.payTaxBtn:SetText("Steuern tilgen (" .. PluribusUtils:FormatGold(due) .. ")")
			f.payTaxBtn:SetEnabled(true)
			f.payTaxBtn:SetAlpha(1.0)
		elseif cash > 0 then
			f.payTaxBtn:SetText("Teilzahlung (" .. PluribusUtils:FormatGold(cash) .. ")")
			f.payTaxBtn:SetEnabled(true)
			f.payTaxBtn:SetAlpha(1.0)
		else
			f.payTaxBtn:SetText("Kein Gold dabei")
			f.payTaxBtn:SetEnabled(false)
			f.payTaxBtn:SetAlpha(0.55)
		end
	else
		f.taxLbl:SetText(string.format("|cfffbbf24Gildensteuer (%d%%):|r |cff4ade80Alles bezahlt (0c)|r",
			math.floor(pol.ratePct or 0)))
		f.payTaxBtn:SetText("Steuern bezahlt")
		f.payTaxBtn:SetEnabled(false)
		f.payTaxBtn:SetAlpha(0.55)
	end
end

function PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
	local f = self.unifiedGuildBankFrame
	if not f or not f:IsShown() then return end
	local UI = _G.PluribusUIFramework
	local c = f.scroll.content

	local numTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
	local curTab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
	if curTab < 1 then curTab = 1 end
	if numTabs > 0 and curTab > numTabs then curTab = 1 end

	-- Rebuild / refresh Guild Bank tab buttons
	for _, tb in ipairs(f.gbTabButtons or {}) do tb:Hide() end
	local tabW = numTabs > 0 and math.min(92, math.floor((464 - (numTabs - 1) * 4) / numTabs)) or 72
	local activeTabName, activeRem = "Fach " .. tostring(curTab), nil
	for t = 1, numTabs do
		local name, icon, isViewable, _, _, remainingWithdrawals = GetGuildBankTabInfo(t)
		local tb = f.gbTabButtons[t]
		if not tb then
			tb = UI:CreateButton(f.tabStrip, "", tabW, 24, function()
				if SetCurrentGuildBankTab then pcall(SetCurrentGuildBankTab, t) end
				if QueryGuildBankTab then pcall(QueryGuildBankTab, t) end
				PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
			end)
			local ic = tb:CreateTexture(nil, "ARTWORK")
			ic:SetSize(16, 16)
			ic:SetPoint("LEFT", tb, "LEFT", 4, 0)
			ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			tb._tabIcon = ic
			tb.label:ClearAllPoints()
			tb.label:SetPoint("LEFT", ic, "RIGHT", 4, 0)
			tb.label:SetPoint("RIGHT", tb, "RIGHT", -4, 0)
			tb.label:SetJustifyH("LEFT")
			f.gbTabButtons[t] = tb
		end
		tb:SetWidth(tabW)
		tb:ClearAllPoints()
		tb:SetPoint("LEFT", f.tabStrip, "LEFT", (t - 1) * (tabW + 4), 0)
		tb._tabIcon:SetTexture(icon or "Interface\\Icons\\INV_Box_02")
		tb.label:SetText(tostring(name or ("Tab " .. t)):sub(1, 9))
		tb:SetActiveState(t == curTab)
		tb:SetAlpha(isViewable == false and 0.45 or 1.0)
		tb:Show()
		if t == curTab then
			activeTabName = name or ("Fach " .. t)
			activeRem = remainingWithdrawals
		end
	end

	local remTxt = ""
	if activeRem ~= nil then
		remTxt = (activeRem == -1) and " · Unbegrenzt" or (" · " .. tostring(activeRem) .. " Entnahmen")
	end
	if f.sub then
		f.sub:SetText(tostring(activeTabName) .. remTxt)
	end

	local query = (f.searchBox and f.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""
	local activeCat = self.unifiedGBCategory or "ALL"
	local sortedView = self:IsBagSortedViewEnabled()
	if f.sortViewBtn then
		if f.sortViewBtn.SetText then f.sortViewBtn:SetText(sortedView and "Sortiert" or "Original") end
		if f.sortViewBtn.SetActiveState then f.sortViewBtn:SetActiveState(sortedView) end
	end

	local entries = {}
	local freeSlots = 0
	for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
		local texture, itemCount, locked = nil, 0, false
		if GetGuildBankItemInfo and numTabs > 0 then
			texture, itemCount, locked = GetGuildBankItemInfo(curTab, slot)
		end
		local link = (GetGuildBankItemLink and numTabs > 0) and GetGuildBankItemLink(curTab, slot) or nil
		local itemID = link and tonumber(link:match("item:(%d+)")) or nil

		if not texture and not itemID then
			freeSlots = freeSlots + 1
			table.insert(entries, {
				tab = curTab, slot = slot, hasItem = false,
				catOrder = 99, quality = -1, nameLower = "", count = 0,
				matches = (query == "" and activeCat == "ALL"),
			})
		else
			local name, _, infoQ, _, _, itemType, _, _, _, icon, _, classID = nil, nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil
			if itemID then
				name, _, infoQ, _, _, itemType, _, _, _, icon, _, classID = PluribusUtils:GetItemInfo(itemID)
			end
			local dName = name or (link and link:match("%[(.-)%]")) or (itemID and ("Item #" .. itemID)) or "Item"
			local q = infoQ or 1
			local itemCat = itemID and self:GetItemBagCategory(itemID, q, itemType, classID) or "OTHER"
			local catMatch = (activeCat == "ALL") or (itemCat == activeCat)
			local matches = catMatch and ((query == "") or dName:lower():find(query, 1, true) ~= nil)
			table.insert(entries, {
				tab = curTab, slot = slot, hasItem = true,
				itemID = itemID, texture = texture or icon,
				count = tonumber(itemCount) or 1, locked = locked == true,
				quality = q, nameLower = dName:lower(),
				catOrder = itemID and self:GetItemSortOrder(itemID, q, itemType, classID) or 50,
				matches = matches,
			})
		end
	end

	if sortedView then
		table.sort(entries, function(a, b)
			if a.hasItem ~= b.hasItem then return a.hasItem end
			if not a.hasItem then return a.slot < b.slot end
			if (activeCat ~= "ALL" or query ~= "") and (a.matches ~= b.matches) then
				return a.matches
			end
			if a.catOrder ~= b.catOrder then return a.catOrder < b.catOrder end
			if a.quality ~= b.quality then return a.quality > b.quality end
			if a.nameLower ~= b.nameLower then return a.nameLower < b.nameLower end
			if a.count ~= b.count then return a.count > b.count end
			return a.slot < b.slot
		end)
	end

	local cols, slotSize, gap = 10, 37, 6
	for idx, entry in ipairs(entries) do
		local btn = f.gbSlots[idx]
		if btn then
			local col = (idx - 1) % cols
			local row = math.floor((idx - 1) / cols)
			btn._gbTab = entry.tab
			btn._gbSlot = entry.slot
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", c, "TOPLEFT", 6 + col * (slotSize + gap), -4 - row * (slotSize + gap))
			btn:Show()
			if entry.hasItem then
				btn.icon:SetTexture(entry.texture)
				btn.icon:SetDesaturated(entry.locked == true)
				btn.icon:Show()
				btn.countText:SetText((entry.count and entry.count > 1) and tostring(entry.count) or "")
				local qc = QUALITY_BORDER_RGB[entry.quality] or QUALITY_BORDER_RGB[1]
				btn:SetBorderRGB(qc[1], qc[2], qc[3], 0.95)
				btn:SetAlpha(entry.matches and 1.0 or 0.16)
			else
				btn.icon:SetTexture(nil)
				btn.icon:Hide()
				btn.countText:SetText("")
				btn:SetBorderRGB(0.20, 0.27, 0.38, 0.68)
				btn:SetAlpha((query == "" and activeCat == "ALL") and 0.85 or 0.14)
			end
		end
	end

	local totalRows = math.max(1, math.ceil(#entries / cols))
	c:SetHeight(math.max(314, totalRows * (slotSize + gap) + 12))

	local gbMoney = (GetGuildBankMoney and GetGuildBankMoney()) or 0
	if f.goldLbl then
		f.goldLbl:SetText(string.format("Gildenbank: |cfffbbf24%s|r · |cff38bdf8%d/%d frei|r",
			PluribusUtils:FormatGold(gbMoney), freeSlots, MAX_GUILDBANK_SLOTS_PER_TAB))
	end
	if f.wdBtn and CanWithdrawGuildBankMoney then
		local canW = CanWithdrawGuildBankMoney()
		f.wdBtn:SetEnabled(canW == true)
		f.wdBtn:SetAlpha(canW and 1.0 or 0.45)
	end
	self:RefreshUnifiedGuildBankTaxStrip()
end

function PluribusHiveInventory:OpenUnifiedGuildBankWindow()
	if InCombatLockdown and InCombatLockdown() then return end
	if not self:IsUnifiedUIEnabled() then
		SuppressOffscreenNativeFrame(_G.GuildBankFrame, false)
		return
	end
	SuppressOffscreenNativeFrame(_G.GuildBankFrame, true)
	-- Hide the external floating tax bar because Guild Tax is natively integrated into our unified Guild Bank footer!
	if _G.PluribusHiveTax and _G.PluribusHiveTax.guildBankBar then
		_G.PluribusHiveTax.guildBankBar:Hide()
	end
	local f = self:EnsureUnifiedGuildBankWindow()
	if not f then return end
	f:Show()
	local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
	if QueryGuildBankTab then pcall(QueryGuildBankTab, cur) end
	self:RefreshUnifiedGuildBankWindow()
	-- Open Unified Bags right beside Unified Guild Bank for seamless drag/drop & right-click deposit!
	self:ToggleUnifiedBagWindow(true)
	if self.unifiedBagFrame and self.unifiedBagFrame:IsShown() then
		self.unifiedBagFrame:ClearAllPoints()
		self.unifiedBagFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 10, 0)
	end
end

function PluribusHiveInventory:CloseUnifiedGuildBankWindow()
	if self.unifiedGuildBankFrame and self.unifiedGuildBankFrame:IsShown() then
		self.unifiedGuildBankFrame:Hide()
	end
	SuppressOffscreenNativeFrame(_G.GuildBankFrame, false)
end

function PluribusHiveInventory:Initialize()
	if self.initialized then return end
	self.initialized = true

	-- Receive guildmates' bags (strictly ignore own character & normalize name)
	PluribusHive:RegisterHandler("BAGS", function(sender, body)
		local norm = PluribusHive:NormalizeName(sender)
		if norm == "" or PluribusHive:SamePlayer(norm, PluribusHive:GetPlayerShortName()) then return end
		local cls, lvl, gold, itemsStr = body:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
		local db = PluribusHive:GetDB()
		db.guildBags[norm] = db.guildBags[norm] or { name = norm, bags = {}, bank = {} }
		local rec = db.guildBags[norm]
		rec.class = cls ~= "" and cls or rec.class or "WARRIOR"
		rec.level = tonumber(lvl) or rec.level or 60
		rec.gold = tonumber(gold) or rec.gold or 0
		rec.bags = DeserializeCounts(itemsStr)
		rec.updatedAt = time()
	end)

	-- Receive guildmates' bank (strictly ignore own character & normalize name)
	PluribusHive:RegisterHandler("BANK", function(sender, body)
		local norm = PluribusHive:NormalizeName(sender)
		if norm == "" or PluribusHive:SamePlayer(norm, PluribusHive:GetPlayerShortName()) then return end
		local cls, gold, itemsStr = body:match("^([^|]*)|([^|]*)|(.*)$")
		local db = PluribusHive:GetDB()
		db.guildBags[norm] = db.guildBags[norm] or { name = norm, bags = {}, bank = {} }
		local rec = db.guildBags[norm]
		rec.class = cls ~= "" and cls or rec.class or "WARRIOR"
		rec.gold = tonumber(gold) or rec.gold or 0
		rec.bank = DeserializeCounts(itemsStr)
		rec.updatedAt = time()
	end)

	-- Share on peer sync request
	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(1, 5), function()
					PluribusHiveInventory:BroadcastBags()
					PluribusHiveInventory:BroadcastBank()
				end)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"PLAYER_ENTERING_WORLD",
		"BAG_UPDATE_DELAYED",
		"ITEM_LOCK_CHANGED",
		"BAG_UPDATE_COOLDOWN",
		"PLAYER_REGEN_ENABLED",
		"BANKFRAME_OPENED",
		"BANKFRAME_CLOSED",
		"PLAYERBANKSLOTS_CHANGED",
		"PLAYERBANKBAGSLOTS_CHANGED",
		"GUILDBANKFRAME_OPENED",
		"GUILDBANKFRAME_CLOSED",
		"GUILDBANKBAGSLOTS_CHANGED",
		"GUILDBANK_UPDATE_TABS",
		"GUILDBANK_UPDATE_MONEY",
		"PLAYER_MONEY",
		"MERCHANT_SHOW",
		"LOOT_READY",
		"LOOT_OPENED",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			PluribusHiveInventory:PruneDuplicateCharacters()
			PluribusHiveInventory:ScanBags()
			PluribusHiveInventory:AttachBagFrameButton()
			PluribusHiveInventory:SyncNativeBagSuppression()
			if C_Timer and C_Timer.After then
				C_Timer.After(6, function()
					PluribusHiveInventory:BroadcastBags()
					PluribusHiveInventory:BroadcastBank()
				end)
			end
		elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" then
			PluribusHiveInventory:AttachBagFrameButton()
			PluribusHiveInventory:ScheduleBagSync()
			if PluribusHiveInventory.unifiedBagFrame and PluribusHiveInventory.unifiedBagFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedBagWindow()
			end
			if PluribusHiveInventory.unifiedBankFrame and PluribusHiveInventory.unifiedBankFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedBankWindow()
			end
			if PluribusHiveInventory.unifiedGuildBankFrame and PluribusHiveInventory.unifiedGuildBankFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedGuildBankTaxStrip()
			end
		elseif event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN" then
			if PluribusHiveInventory.unifiedBagFrame and PluribusHiveInventory.unifiedBagFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedBagWindow()
			end
			if PluribusHiveInventory.unifiedBankFrame and PluribusHiveInventory.unifiedBankFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedBankWindow()
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if PluribusHiveInventory.pendingBagSuppressionSync then
				PluribusHiveInventory.pendingBagSuppressionSync = false
				PluribusHiveInventory:SyncNativeBagSuppression()
			end
			if PluribusHiveInventory.pendingUnifiedRefresh then
				PluribusHiveInventory.pendingUnifiedRefresh = false
				if PluribusHiveInventory.unifiedBagFrame and PluribusHiveInventory.unifiedBagFrame:IsShown() then
					PluribusHiveInventory:RefreshUnifiedBagWindow()
				end
				if PluribusHiveInventory.unifiedBankFrame and PluribusHiveInventory.unifiedBankFrame:IsShown() then
					PluribusHiveInventory:RefreshUnifiedBankWindow()
				end
			end
		elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
			PluribusHiveInventory:TryFastAutoLoot()
		elseif event == "MERCHANT_SHOW" then
			local cfg = PluribusHive and PluribusHive:GetConfig()
			local shiftHeld = IsShiftKeyDown and IsShiftKeyDown()
			if cfg and not shiftHeld then
				local doRepair = cfg.autoRepair ~= false
				local doSell = cfg.autoSellJunk ~= false
				local function RunMerchantQoL()
					if doRepair then PluribusHiveInventory:RepairAllGear(true) end
					if doSell then PluribusHiveInventory:SellGrayTrash(true) end
				end
				if doRepair or doSell then
					if C_Timer and C_Timer.After then
						C_Timer.After(0.15, RunMerchantQoL)
					else
						RunMerchantQoL()
					end
				end
			end
		elseif event == "BANKFRAME_OPENED" then
			PluribusHiveInventory.bankOpen = true
			PluribusHiveInventory:AttachBagFrameButton()
			PluribusHiveInventory:ScanBank()
			PluribusHiveInventory:BroadcastBank()
			PluribusHiveInventory:OpenUnifiedBankWindow()
		elseif (event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED") and PluribusHiveInventory.bankOpen then
			PluribusHiveInventory:ScanBank()
			if PluribusHiveInventory.unifiedBankFrame and PluribusHiveInventory.unifiedBankFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedBankWindow()
			end
		elseif event == "BANKFRAME_CLOSED" then
			PluribusHiveInventory.bankOpen = false
			PluribusHiveInventory:CloseUnifiedBankWindow()
			PluribusHiveInventory:BroadcastBank()
		elseif event == "GUILDBANKFRAME_OPENED" then
			PluribusHiveInventory.guildBankOpen = true
			PluribusHiveInventory:OpenUnifiedGuildBankWindow()
		elseif event == "GUILDBANKBAGSLOTS_CHANGED" or event == "GUILDBANK_UPDATE_TABS" or event == "GUILDBANK_UPDATE_MONEY" then
			if PluribusHiveInventory.unifiedGuildBankFrame and PluribusHiveInventory.unifiedGuildBankFrame:IsShown() then
				PluribusHiveInventory:RefreshUnifiedGuildBankWindow()
			end
		elseif event == "GUILDBANKFRAME_CLOSED" then
			PluribusHiveInventory.guildBankOpen = false
			PluribusHiveInventory:CloseUnifiedGuildBankWindow()
		end
	end)

	-- Hook native bag toggle/open/close safely (NEVER hook ContainerFrame_OnShow to call Hide()!)
	local lastBagToggleAt = 0
	if hooksecurefunc then
		for _, fnName in ipairs({ "ToggleAllBags", "ToggleBackpack", "OpenAllBags", "OpenBackpack" }) do
			if _G[fnName] then
				pcall(hooksecurefunc, fnName, function()
					PluribusHiveInventory:AttachBagFrameButton()
					local cfg = PluribusHive and PluribusHive:GetConfig()
					if cfg and cfg.replaceNativeBags == true and not (InCombatLockdown and InCombatLockdown()) then
						local now = (GetTime and GetTime()) or 0
						if fnName == "ToggleAllBags" or fnName == "ToggleBackpack" then
							if (now - lastBagToggleAt) > 0.06 then
								lastBagToggleAt = now
								PluribusHiveInventory:ToggleUnifiedBagWindow()
							end
						elseif fnName == "OpenAllBags" or fnName == "OpenBackpack" then
							if (now - lastBagToggleAt) > 0.06 then
								lastBagToggleAt = now
								PluribusHiveInventory:ToggleUnifiedBagWindow(true)
							end
						end
					end
				end)
			end
		end
		for _, closeFn in ipairs({ "CloseAllBags", "CloseBackpack" }) do
			if _G[closeFn] then
				pcall(hooksecurefunc, closeFn, function()
					if PluribusHiveInventory.unifiedBagFrame and PluribusHiveInventory.unifiedBagFrame:IsShown()
						and not (InCombatLockdown and InCombatLockdown()) then
						PluribusHiveInventory.unifiedBagFrame:Hide()
					end
				end)
			end
		end
	end
end

return PluribusHiveInventory
