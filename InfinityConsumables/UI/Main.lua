local UI = {}
_G.InfinityConsumablesUI = UI

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function UI:Refresh()
	if not self.frame then return end
	local tracker = _G.InfinityConsumables
	local method = tracker and (self.mode == "buffs" and tracker.GetActiveBuffs or tracker.ScanInventory)
	if type(method) ~= "function" then
		InfinityUtils:Warning("Consumable tracker unavailable.", "Consumables")
		self.frame.status:SetText("Tracker unavailable.")
		self.frame:SetItems({})
		return
	end
	local ok, data = pcall(method, tracker)
	data = Public(data)
	if not ok or type(data) ~= "table" then
		InfinityUtils:Warning("Consumable scan failed: " .. tostring(data or "protected or unavailable data"), "Consumables")
		self.frame.status:SetText("Scan failed; see warning.")
		self.frame:SetItems({})
		return
	end
	local rows, partial = {}, false
	for _, entry in pairs(data) do
		entry = Public(entry)
		local name = type(entry) == "table" and Public(entry.name)
		local count = type(entry) == "table" and Public(entry.count)
		if type(name) == "string" and name ~= "" and (self.mode == "buffs" or type(count) == "number") then
			rows[#rows + 1] = { text = self.mode == "buffs" and name or (name .. " x" .. count) }
		else partial = true end
	end
	table.sort(rows, function(a, b) return a.text < b.text end)
	if #rows == 0 then rows[1] = { text = "No readable entries." } end
	self.frame:SetItems(rows)
	self.frame.status:SetText((self.mode == "buffs" and "Buff records may be stale." or "Bag scan; uncached items may be missing.")
		.. (partial and " Some entries unavailable." or ""))
end

function UI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityConsumablesWindow", "Consumables and Buffs", 600, 450)
		local bags = InfinityUIFramework:CreateButton(self.frame, "Scan bags", 100, 22, function()
			self.mode = "bags"
			self:Refresh()
		end)
		bags:SetPoint("TOPLEFT", 20, -38)
		local buffs = InfinityUIFramework:CreateButton(self.frame, "Buffs", 100, 22, function()
			self.mode = "buffs"
			self:Refresh()
		end)
		buffs:SetPoint("LEFT", bags, "RIGHT", 8, 0)
	end
	if self.frame:IsShown() then self.frame:Hide() else self.mode = self.mode or "bags"; self:Refresh(); self.frame:Show() end
end

return UI
