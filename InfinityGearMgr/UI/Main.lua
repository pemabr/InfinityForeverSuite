local UI = {}
_G.InfinityGearMgrUI = UI

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function UI:Refresh(scan)
	if not self.frame then return end
	local tracker = _G.InfinityGearTracker
	if not tracker then InfinityUtils:Warning("Gear tracker unavailable.", "Gear"); return end
	local method = scan and tracker.ScanEquipment or
		(self.mode == "upgrades" and tracker.GetUpgradeItems or tracker.GetAllEquipment)
	if type(method) ~= "function" then InfinityUtils:Warning("Gear action unavailable.", "Gear"); return end
	local ok, items = pcall(method, tracker)
	items = Public(items)
	if not ok or type(items) ~= "table" then
		InfinityUtils:Warning("Gear scan failed: " .. tostring(items or "protected or unavailable data"), "Gear")
		self.frame.status:SetText("Gear data unavailable; see warning.")
		self.frame:SetItems({})
		return
	end
	local rows, partial = {}, false
	for _, item in pairs(items) do
		item = Public(item)
		local name = type(item) == "table" and Public(item.name)
		local slot = type(item) == "table" and Public(item.slot)
		local level = type(item) == "table" and Public(item.level)
		local link = type(item) == "table" and Public(item.link)
		if type(name) == "string" and type(slot) == "string" and type(level) == "number" then
			rows[#rows + 1] = { text = slot .. ": " .. name .. " (item level " .. level .. ")",
				link = type(link) == "string" and link or nil }
		else partial = true end
	end
	table.sort(rows, function(a, b) return a.text < b.text end)
	if #rows == 0 then rows[1] = { text = "No readable equipment." } end
	self.frame:SetItems(rows)
	self.frame.status:SetText((self.mode == "upgrades" and "Slots 10 levels below your highest equipped item; not confirmed upgrades."
		or "Currently scanned equipment; item data may be incomplete.") .. (partial and " Some entries unavailable." or ""))
end

function UI:ShowExport()
	local tracker = _G.InfinityGearTracker
	if not tracker or type(tracker.ExportGear) ~= "function" then
		InfinityUtils:Warning("Gear export unavailable.", "Gear")
		return
	end
	local ok, data = pcall(tracker.ExportGear, tracker)
	data = Public(data)
	if not ok or type(data) ~= "table" then
		InfinityUtils:Warning("Gear export failed: " .. tostring(data or "protected data"), "Gear")
		return
	end
	local equipment, character = Public(data.equipment), Public(data.character)
	local name = type(character) == "table" and Public(character.name)
	if type(equipment) ~= "table" or type(name) ~= "string" or name == "" then
		InfinityUtils:Warning("Gear export data unavailable or protected.", "Gear")
		return
	end
	local rows, partial = {}, false
	for rawSlot, rawItem in pairs(equipment) do
		local slot, item = Public(rawSlot), Public(rawItem)
		local link = type(item) == "table" and Public(item.link)
		if type(slot) == "string" and type(link) == "string" then
			rows[#rows + 1] = slot .. ": " .. link
		else
			partial = true
		end
	end
	table.sort(rows)
	if not self.exportFrame then
		local frame = InfinityUIFramework:CreateFrame("InfinityGearExportWindow", UIParent, 650, 450)
		frame:SetPoint("CENTER")
		local title = InfinityUIFramework:CreateLabel(frame, "Gear Export - select and copy")
		title:SetPoint("TOPLEFT", 15, -12)
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -5, -5)
		close:SetScript("OnClick", function() frame:Hide() end)
		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 20, -40)
		scroll:SetSize(590, 370)
		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlight)
		edit:SetWidth(570)
		edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
		scroll:SetScrollChild(edit)
		local status = InfinityUIFramework:CreateLabel(frame, "")
		status:SetPoint("BOTTOMLEFT", 15, 12)
		frame:Hide()
		self.exportFrame, self.exportText, self.exportStatus, self.exportScroll = frame, edit, status, scroll
	end
	self.exportText:SetText("Character: " .. name .. "\n" .. table.concat(rows, "\n"))
	self.exportText:SetHeight(math.max(370, (#rows + 1) * 24))
	self.exportScroll:UpdateScrollChildRect()
	self.exportStatus:SetText(partial and "Some equipment could not be exported." or "Current cached equipment only.")
	self.exportFrame:Show()
end

function UI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityGearMgrWindow", "Gear Tracker", 650, 450)
		local scan = InfinityUIFramework:CreateButton(self.frame, "Rescan", 100, 22, function()
			self.mode = "all"
			self:Refresh(true)
		end)
		scan:SetPoint("TOPLEFT", 20, -38)
		local all = InfinityUIFramework:CreateButton(self.frame, "Equipment", 100, 22, function()
			self.mode = "all"
			self:Refresh()
		end)
		all:SetPoint("LEFT", scan, "RIGHT", 8, 0)
		local upgrades = InfinityUIFramework:CreateButton(self.frame, "Low slots", 100, 22, function()
			self.mode = "upgrades"
			self:Refresh()
		end)
		upgrades:SetPoint("LEFT", all, "RIGHT", 8, 0)
		local export = InfinityUIFramework:CreateButton(self.frame, "Export", 100, 22, function()
			self:ShowExport()
		end)
		export:SetPoint("LEFT", upgrades, "RIGHT", 8, 0)
	end
	if self.frame:IsShown() then self.frame:Hide() else self.mode = "all"; self:Refresh(true); self.frame:Show() end
end

return UI
