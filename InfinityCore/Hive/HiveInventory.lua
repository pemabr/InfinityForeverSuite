-- InfinityHive Inventory & Bank Sharing Module
-- Tracks all Alts & Guildmates' bags + bank (if allowed, default ON)
-- Embeds a Bagnon-style character switcher button directly into WoW's Bag frame

InfinityHiveInventory = {
	initialized = false,
	scanPending = false,
	bankOpen = false,
	bagButtonAttached = false,
}
_G.InfinityHiveInventory = InfinityHiveInventory

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
			return info.itemID, info.stackCount or 1, info.hyperlink
		end
		return nil
	elseif GetContainerItemInfo then
		local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
		if link then
			local itemID = InfinityUtils and InfinityUtils:GetItemIDFromHyperlink(link)
			return itemID, count or 1, link
		end
	end
	return nil
end

function InfinityHiveInventory:GetMyAltRecord()
	local db = InfinityHive:GetDB()
	local realm = InfinityHive:GetRealmKey()
	local me = InfinityHive:GetPlayerShortName()
	db.alts[realm] = db.alts[realm] or {}
	db.alts[realm][me] = db.alts[realm][me] or {
		name = me,
		class = InfinityHive:GetPlayerClass(),
		level = UnitLevel and UnitLevel("player") or 60,
		gold = 0,
		bags = {},
		bank = {},
		updatedAt = 0,
	}
	return db.alts[realm][me]
end

function InfinityHiveInventory:ScanBags()
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
	rec.class = InfinityHive:GetPlayerClass()
	rec.level = UnitLevel and UnitLevel("player") or rec.level or 60
	rec.updatedAt = time()
	return rec
end

function InfinityHiveInventory:ScanBank()
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

function InfinityHiveInventory:BroadcastBags()
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareBags then return end
	local rec = self:GetMyAltRecord()
	local payload = string.format("%s|%d|%d|%s",
		rec.class or "WARRIOR",
		rec.level or 60,
		rec.gold or 0,
		SerializeCounts(rec.bags)
	)
	InfinityHive:Send("BAGS", payload, "GUILD")
end

function InfinityHiveInventory:BroadcastBank()
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareBank then return end
	local rec = self:GetMyAltRecord()
	local payload = string.format("%s|%d|%s",
		rec.class or "WARRIOR",
		rec.gold or 0,
		SerializeCounts(rec.bank)
	)
	InfinityHive:Send("BANK", payload, "GUILD")
end

function InfinityHiveInventory:ScheduleBagSync()
	if self.scanPending then return end
	self.scanPending = true
	if C_Timer and C_Timer.After then
		C_Timer.After(6, function()
			InfinityHiveInventory.scanPending = false
			InfinityHiveInventory:ScanBags()
			InfinityHiveInventory:BroadcastBags()
		end)
	else
		self.scanPending = false
		self:ScanBags()
		self:BroadcastBags()
	end
end

-- Fast cross-character & cross-guild item lookup (used by Tooltips, Professions, and Bag Viewer)
function InfinityHiveInventory:GetItemCounts(itemID)
	if not itemID then return nil end
	local db = InfinityHive:GetDB()
	local realm = InfinityHive:GetRealmKey()
	local me = InfinityHive:GetPlayerShortName()

	local result = {
		selfBags = 0,
		selfBank = 0,
		alts = {},
		guild = {},
		totalAlts = 0,
		totalGuild = 0,
	}

	local realmAlts = db.alts[realm] or {}
	for charName, rec in pairs(realmAlts) do
		local b = (rec.bags and rec.bags[itemID]) or 0
		local k = (rec.bank and rec.bank[itemID]) or 0
		if charName == me then
			result.selfBags = b
			result.selfBank = k
		elseif (b + k) > 0 then
			table.insert(result.alts, { name = charName, class = rec.class, bags = b, bank = k, total = b + k })
			result.totalAlts = result.totalAlts + b + k
		end
	end

	for memberName, rec in pairs(db.guildBags or {}) do
		if memberName ~= me and not realmAlts[memberName] then
			local b = (rec.bags and rec.bags[itemID]) or 0
			local k = (rec.bank and rec.bank[itemID]) or 0
			if (b + k) > 0 then
				table.insert(result.guild, { name = memberName, class = rec.class, bags = b, bank = k, total = b + k })
				result.totalGuild = result.totalGuild + b + k
			end
		end
	end

	table.sort(result.alts, function(a, b) return a.total > b.total end)
	table.sort(result.guild, function(a, b) return a.total > b.total end)
	return result
end

-- List all inspectable characters (self + alts + sharing guildmates)
function InfinityHiveInventory:GetInspectableCharacters()
	local db = InfinityHive:GetDB()
	local realm = InfinityHive:GetRealmKey()
	local me = InfinityHive:GetPlayerShortName()
	local list = {}
	local seen = {}

	local realmAlts = db.alts[realm] or {}
	for charName, rec in pairs(realmAlts) do
		seen[charName] = true
		table.insert(list, {
			name = charName,
			class = rec.class or "WARRIOR",
			level = rec.level or 60,
			gold = rec.gold or 0,
			bags = rec.bags or {},
			bank = rec.bank or {},
			updatedAt = rec.updatedAt or 0,
			group = (charName == me) and "YOU" or "ALT",
		})
	end

	for memberName, rec in pairs(db.guildBags or {}) do
		if not seen[memberName] then
			table.insert(list, {
				name = memberName,
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
function InfinityHiveInventory:SearchAll(query)
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
			local itemName, itemLink, quality, _, _, _, _, _, _, icon = InfinityUtils:GetItemInfo(itemID)
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

-- Bagnon-style button embedded directly inside WoW's native Bag frame
function InfinityHiveInventory:AttachBagFrameButton()
	if self.bagButtonAttached then return end
	local parent = _G.ContainerFrameCombinedBags or _G.ContainerFrame1
	if not parent or not _G.InfinityUIFramework then return end

	local btn = _G.InfinityUIFramework:CreateButton(parent, "Hive Bags", 76, 20, function()
		if _G.InfinityHiveUI and _G.InfinityHiveUI.ToggleInventoryViewer then
			_G.InfinityHiveUI:ToggleInventoryViewer()
		end
	end, true)
	btn:SetFrameStrata("HIGH")
	btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -32, -5)
	btn:SetScript("OnEnter", function(selfBtn)
		if GameTooltip then
			GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
			GameTooltip:AddLine("|cff38bdf8Infinity Hive Inventory|r", 1, 1, 1)
			GameTooltip:AddLine("View Alts & Guildmates' Bags and Banks", 0.8, 0.9, 1)
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	self.bagButton = btn
	self.bagButtonAttached = true
end

function InfinityHiveInventory:Initialize()
	if self.initialized then return end
	self.initialized = true

	-- Receive guildmates' bags
	InfinityHive:RegisterHandler("BAGS", function(sender, body)
		local cls, lvl, gold, itemsStr = body:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
		local db = InfinityHive:GetDB()
		db.guildBags[sender] = db.guildBags[sender] or { name = sender, bags = {}, bank = {} }
		local rec = db.guildBags[sender]
		rec.class = cls ~= "" and cls or rec.class or "WARRIOR"
		rec.level = tonumber(lvl) or rec.level or 60
		rec.gold = tonumber(gold) or rec.gold or 0
		rec.bags = DeserializeCounts(itemsStr)
		rec.updatedAt = time()
	end)

	-- Receive guildmates' bank
	InfinityHive:RegisterHandler("BANK", function(sender, body)
		local cls, gold, itemsStr = body:match("^([^|]*)|([^|]*)|(.*)$")
		local db = InfinityHive:GetDB()
		db.guildBags[sender] = db.guildBags[sender] or { name = sender, bags = {}, bank = {} }
		local rec = db.guildBags[sender]
		rec.class = cls ~= "" and cls or rec.class or "WARRIOR"
		rec.gold = tonumber(gold) or rec.gold or 0
		rec.bank = DeserializeCounts(itemsStr)
		rec.updatedAt = time()
	end)

	-- Share on peer sync request
	if _G.InfinityMessaging then
		_G.InfinityMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(1, 5), function()
					InfinityHiveInventory:BroadcastBags()
					InfinityHiveInventory:BroadcastBank()
				end)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_MONEY" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			InfinityHiveInventory:ScanBags()
			InfinityHiveInventory:AttachBagFrameButton()
			if C_Timer and C_Timer.After then
				C_Timer.After(6, function()
					InfinityHiveInventory:BroadcastBags()
					InfinityHiveInventory:BroadcastBank()
				end)
			end
		elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" then
			InfinityHiveInventory:AttachBagFrameButton()
			InfinityHiveInventory:ScheduleBagSync()
		elseif event == "BANKFRAME_OPENED" then
			InfinityHiveInventory.bankOpen = true
			InfinityHiveInventory:ScanBank()
			InfinityHiveInventory:BroadcastBank()
		elseif event == "PLAYERBANKSLOTS_CHANGED" and InfinityHiveInventory.bankOpen then
			InfinityHiveInventory:ScanBank()
		elseif event == "BANKFRAME_CLOSED" then
			InfinityHiveInventory.bankOpen = false
			InfinityHiveInventory:BroadcastBank()
		end
	end)

	-- Also hook opening combined bags if frame is created lazily
	if hooksecurefunc and _G.ToggleAllBags then
		pcall(hooksecurefunc, "ToggleAllBags", function()
			InfinityHiveInventory:AttachBagFrameButton()
		end)
	end
end

return InfinityHiveInventory
