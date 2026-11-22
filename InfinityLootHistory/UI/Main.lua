local UI = {}
_G.InfinityLootHistoryUI = UI

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function UI:Refresh()
	if not self.frame then return end
	local history = _G.InfinityLootHistoryTracker
	if not history then InfinityUtils:Warning("Loot history unavailable.", "LootHistory"); return end
	local filter = Public(self.filter:GetText())
	if type(filter) ~= "string" then InfinityUtils:Warning("Loot filter unavailable.", "LootHistory"); return end
	filter = filter:lower():match("^%s*(.-)%s*$")
	local entries, rows = history:GetLootBySource("all", history.maxLogSize), {}
	for _, entry in ipairs(entries) do
		entry = Public(entry)
		local name = type(entry) == "table" and Public(entry.itemName)
		local source = type(entry) == "table" and Public(entry.dropSource)
		if type(name) == "string" and type(source) == "string"
			and (name .. " " .. source):lower():find(filter, 1, true) then
			rows[#rows + 1] = { text = name .. " | " .. source }
		end
	end
	if #rows == 0 then rows[1] = { text = "No matching loot records." } end
	self.frame:SetItems(rows)
	local stats = history:GetLootStats()
	self.frame.status:SetText("Session only: " .. stats.totalItems .. " records, " .. stats.totalPlayers
		.. " recipients. Records are not collected automatically.")
end

function UI:ShowRecord()
	if not self.recordFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootHistoryRecordWindow", "Record Loot", 720, 350)
		local function Input(title, x, offset, width, max)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(max)
			return box
		end
		self.recordID = Input("ID", 10, 25, 70, 10)
		self.recordName = Input("Item", 115, 35, 155, 100)
		self.recordSource = Input("Source", 320, 45, 120, 80)
		self.recordRecipient = Input("Player", 500, 45, 140, 80)
		frame:SetItems({ { text = "Save manual loot record", onClick = function()
			local id, name, source, recipient = Public(self.recordID:GetText()), Public(self.recordName:GetText()),
				Public(self.recordSource:GetText()), Public(self.recordRecipient:GetText())
			if type(id) ~= "string" or type(name) ~= "string" or type(source) ~= "string" or type(recipient) ~= "string" then
				InfinityUtils:Warning("Loot record input unavailable or protected.", "LootHistory")
				return
			end
			id, name, source, recipient = tonumber(id), name:match("^%s*(.-)%s*$"),
				source:match("^%s*(.-)%s*$"), recipient:match("^%s*(.-)%s*$")
			local manager = _G.InfinityCharacterManager
			local character = manager and Public(manager:GetCurrentCharacter())
			local characterName = type(character) == "table" and Public(character.name)
			if not id or id ~= id or id <= 0 or id >= math.huge or id ~= math.floor(id) or name == ""
				or name:find("[%c]") or source:find("[%c]") or recipient:find("[%c]") then
				InfinityUtils:Warning("Enter a valid item ID and item name.", "LootHistory")
				return
			end
			if type(characterName) ~= "string" or characterName == "" then
				InfinityUtils:Warning("Current character unavailable.", "LootHistory")
				return
			end
			local recipients = recipient ~= "" and { recipient } or {}
			if InfinityLootHistoryTracker:RecordLoot(id, name, 0, source ~= "" and source or "Unknown", recipients) then
				frame.status:SetText("Manual record saved for this session.")
				self:Refresh()
			else
				InfinityUtils:Warning("Could not save loot record.", "LootHistory")
			end
		end } })
		frame.status:SetText("Enter item ID and name; source and recipient are optional.")
		self.recordFrame = frame
	end
	self.recordFrame:Show()
end

function UI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityLootHistoryWindow", "Loot History", 650, 450)
		local label = InfinityUIFramework:CreateLabel(self.frame, "Filter")
		label:SetPoint("TOPLEFT", 15, -43)
		self.filter = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
		self.filter:SetSize(170, 20)
		self.filter:SetPoint("TOPLEFT", 65, -38)
		self.filter:SetAutoFocus(false)
		self.filter:SetMaxLetters(80)
		local search = InfinityUIFramework:CreateButton(self.frame, "Search", 80, 22, function()
			self.confirmClear = nil
			self:Refresh()
		end)
		search:SetPoint("LEFT", self.filter, "RIGHT", 10, 0)
		self.clearButton = InfinityUIFramework:CreateButton(self.frame, "Clear", 80, 22, function()
			local log = InfinityLootHistoryTracker.lootLog
			local confirmation = self.confirmClear
			if not confirmation or confirmation.log ~= log or confirmation.count ~= #log or confirmation.last ~= log[#log] then
				self.confirmClear = { log = log, count = #log, last = log[#log] }
				self.frame.status:SetText("Clear session loot and recipient statistics? Click Clear again.")
			else
				self.confirmClear = nil
				InfinityLootHistoryTracker:Clear()
				self:Refresh()
			end
		end)
		self.clearButton:SetPoint("LEFT", search, "RIGHT", 5, 0)
		local record = InfinityUIFramework:CreateButton(self.frame, "Record", 80, 22, function() self:ShowRecord() end)
		record:SetPoint("LEFT", self.clearButton, "RIGHT", 5, 0)
	end
	self.confirmClear = nil
	if self.frame:IsShown() then self.frame:Hide() else self:Refresh(); self.frame:Show() end
end

return UI
