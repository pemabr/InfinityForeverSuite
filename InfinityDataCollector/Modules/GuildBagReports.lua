local Knowledge = _G.InfinityGuildKnowledge
local Reports = {
	prefix = "InfinityBag1",
	storageKey = "guildBagReports",
	sequence = 0,
	queue = {},
	maxRecords = 10000,
}
for key, value in pairs(Knowledge) do
	if type(value) == "function" then Reports[key] = value end
end
_G.InfinityGuildBagReports = Reports

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function FullName(value)
	value = Public(value)
	if type(value) ~= "string" or #value > 75 or not value:match("%S")
		or value:find("[%z\1-\31~|]") then return nil end
	local name, realm = value:match("^([^%-]+)%-(.+)$")
	if not name then
		name = value
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

function Reports:Valid(record)
	record = Public(record)
	return type(record) == "table" and Public(record.kind) == "I"
		and FullName(record.owner) ~= nil and Integer(record.id, 1000000000)
		and Integer(record.count, 1000000000, true) and Integer(record.observed, 100000000000)
end

function Reports:Key(record) return "I:" .. FullName(record.owner) .. ":" .. record.id end
function Reports:Payload(prefix, record)
	return table.concat({ prefix, record.id, record.count, record.observed, record.owner }, "~")
end

function Reports:Parse(kind, body)
	if kind ~= "I" then return nil end
	local id, count, observed, owner = body:match("^(%d+)~(%d+)~(%d+)~([^~]+)$")
	local record = { kind = kind, id = tonumber(id), count = tonumber(count),
		observed = tonumber(observed), owner = owner }
	if self:Valid(record) then return record end
end

function Reports:Copy(record, revision)
	return { kind = "I", id = record.id, count = record.count, observed = record.observed,
		owner = record.owner, revision = revision }
end

function Reports:Merge(previous, record)
	if record.observed > previous.observed then return record end
end

function Reports:Apply()
	local inventory = _G.InfinityInventoryUI
	if self.refreshPending or not ((self.window and self.window:IsShown())
		or (inventory and type(inventory.HasVisibleWindows) == "function" and inventory:HasVisibleWindows())) then return end
	self.refreshPending = true
	C_Timer.After(0.5, function()
		self.refreshPending = false
		if self.window and self.window:IsShown() then self:Refresh() end
		local ui = _G.InfinityInventoryUI
		if ui and type(ui.Refresh) == "function" then ui:Refresh() end
	end)
end

function Reports:Initialize()
	if self.initialized then return end
	Knowledge.Initialize(self)
	if not self.available then return end
	if not _G.InfinityMessaging or type(InfinityMessaging.Subscribe) ~= "function" then
		InfinityUtils:Warning("Bag scan notifications unavailable; guild bag reports cannot update.", "Knowledge")
		self.available = false
		return
	end
	InfinityMessaging:Subscribe("bags_scanned", function() self:ScheduleScan() end)
	if self.db.enabled then self:ScheduleScan() end
end

function Reports:ScheduleScan()
	if not self.db or not self.db.enabled or self.scanPending then return end
	local pending = {}
	self.scanPending = pending
	C_Timer.After(1, function()
		if self.scanPending ~= pending then return end
		self.scanPending = nil
		if self.db.enabled then self:PublishScan() end
	end)
end

function Reports:SetEnabled(enabled)
	local tracker = _G.InfinityBagTracker
	if enabled and (type(tracker) ~= "table" or type(tracker.ScanBags) ~= "function") then
		InfinityUtils:Warning("Load Infinity Inventory before enabling guild bag reports.", "Knowledge")
		return false
	end
	local result = Knowledge.SetEnabled(self, enabled)
	if not enabled then self.scanPending = nil end
	self:Apply()
	return result
end

function Reports:PublishCurrent()
	local tracker = _G.InfinityBagTracker
	if not tracker or not tracker:ScanBags() then
		InfinityUtils:Warning("Bag scan unavailable; guild bag reports were not updated.", "Knowledge")
		return
	end
	self:PublishScan()
end

function Reports:PublishScan()
	if not self.available or not self.db.enabled then return false end
	local state = self:State()
	if not state then return false end
	local tracker = Public(_G.InfinityBagTracker)
	local bags = type(tracker) == "table" and Public(tracker.bagContents)
	local free = type(tracker) == "table" and Public(tracker.freeSlots)
	if type(bags) ~= "table" or not Integer(free, 100000, true) then
		InfinityUtils:Warning("Complete bag scan unavailable; previous reports were not changed.", "Knowledge")
		return false
	end
	local counts = {}
	for _, rawSlots in pairs(bags) do
		local slots = Public(rawSlots)
		if type(slots) ~= "table" then
			InfinityUtils:Warning("Bag contents unavailable; previous reports were not changed.", "Knowledge")
			return false
		end
		for _, rawItem in pairs(slots) do
			local item = Public(rawItem)
			local id, count = type(item) == "table" and Public(item.itemId), type(item) == "table" and Public(item.quantity)
			if not Integer(id, 1000000000) or not Integer(count, 1000000000)
				or (counts[id] or 0) + count > 1000000000 then
				InfinityUtils:Warning("Bag contents unavailable; previous reports were not changed.", "Knowledge")
				return false
			end
			counts[id] = (counts[id] or 0) + count
		end
	end
	local owner = _G.UnitName and Public(UnitName("player"))
	local realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
	if (type(realm) ~= "string" or realm == "") and _G.GetRealmName then realm = Public(GetRealmName()) end
	if type(owner) ~= "string" or type(realm) ~= "string" or realm == "" then
		InfinityUtils:Warning("Character identity unavailable; bag reports were not shared.", "Knowledge")
		return false
	end
	if not owner:find("-", 1, true) then owner = owner .. "-" .. realm:gsub("%s+", "") end
	local ownerKey, observed = FullName(owner), Public(time())
	if not ownerKey or not Integer(observed, 100000000000) then
		InfinityUtils:Warning("Character identity or clock unavailable; bag reports were not shared.", "Knowledge")
		return false
	end
	for _, record in pairs(state.records) do
		if self:Valid(record) and FullName(record.owner) == ownerKey and counts[record.id] == nil
			and record.count > 0 then counts[record.id] = 0 end
	end
	for id, count in pairs(counts) do
		local record = { kind = "I", id = id, count = count, observed = observed, owner = owner }
		local previous = state.records[self:Key(record)]
		if not previous or previous.count ~= count or observed - previous.observed >= 3600 then
			if previous and previous.observed >= record.observed then record.observed = previous.observed + 1 end
			self:Add(record, true)
		end
	end
	self:Apply()
	return true
end

function Reports:Search(id)
	id = Public(id)
	if not Integer(id, 1000000000) then return nil, "Enter a valid item ID." end
	local state = self:State()
	if not state then return nil, "Enable guild bag reports while in a guild." end
	local members = self:GetRoster()
	if not members or not next(members) then return nil, "Guild roster unavailable; try again after it loads." end
	local found = {}
	for _, record in pairs(state.records) do
		if self:Valid(record) and record.id == id and record.count > 0 and members[FullName(record.owner)] then
			found[#found + 1] = record
		end
	end
	table.sort(found, function(a, b) return a.owner < b.owner end)
	return found
end

function Reports:GetInventories()
	local state = self:State()
	if not state then return nil, "Enable guild bag reports while in a guild." end
	local members = self:GetRoster()
	if not members or not next(members) then return nil, "Guild roster unavailable." end
	local inventories = {}
	for _, record in pairs(state.records) do
		if self:Valid(record) and record.count > 0 then
			local key = FullName(record.owner)
			if members[key] then
				local inventory = inventories[key]
				if not inventory then
					inventory = { name = members[key], items = {} }
					inventories[key] = inventory
				end
				inventory.items[#inventory.items + 1] = {
					itemId = record.id, quantity = record.count, observed = record.observed,
				}
			end
		end
	end
	for _, inventory in pairs(inventories) do
		table.sort(inventory.items, function(a, b) return a.itemId < b.itemId end)
	end
	return inventories
end

function Reports:Refresh()
	if not self.window then return end
	local input = Public(self.input:GetText())
	local id = type(input) == "string" and input:match("^%s*(%d+)%s*$")
	local records, problem = self:Search(id and tonumber(id))
	local rows = {}
	if records then
		for index = 1, math.min(#records, 200) do
			local record = records[index]
			local ok, observed = false, nil
			if _G.date then ok, observed = pcall(date, "%Y-%m-%d %H:%M", record.observed) end
			if not ok or type(observed) ~= "string" then observed = "timestamp " .. record.observed end
			rows[#rows + 1] = { text = record.owner .. ": " .. record.count .. " | last observed: " .. observed }
		end
		if #rows == 0 then rows[1] = { text = "No matching reports." } end
	end
	local status = "Bag reports may be outdated; confirm with the player. Bank and equipment excluded."
	if records and #records > 200 then status = "First 200 of " .. #records .. "; reports may be outdated." end
	self.window.status:SetText(problem or status)
	self.window:SetItems(rows)
end

function Reports:Toggle()
	if not _G.InfinityUIFramework then
		InfinityUtils:Warning("Guild bag directory UI unavailable.", "Knowledge")
		return
	end
	if not self.window then
		local window = InfinityUIFramework:CreateListWindow("InfinityGuildBagReportsWindow", "Guild Bag Reports", 650, 500)
		self.input = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
		self.input:SetSize(150, 20)
		self.input:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -40)
		self.input:SetAutoFocus(false)
		self.input:SetMaxLetters(10)
		local search = InfinityUIFramework:CreateButton(window, "Search item ID", 120, 22, function() self:Refresh() end)
		search:SetPoint("LEFT", self.input, "RIGHT", 12, 0)
		self.input:SetScript("OnEnterPressed", function(input) input:ClearFocus(); self:Refresh() end)
		self.window = window
	end
	if self.window:IsShown() then self.window:Hide()
	else self:Refresh(); self.window:Show() end
end

function Reports:OpenItem(id)
	if not Integer(id, 1000000000) then
		InfinityUtils:Warning("Enter a valid item ID.", "Knowledge")
		return false
	end
	if not self.window or not self.window:IsShown() then self:Toggle() end
	if not self.window then return false end
	self.input:SetText(tostring(id))
	self:Refresh()
	return true
end

return Reports
