local UI = {}
_G.InfinityWorldBossUI = UI

function UI:Initialize()
	if self.frame then return end
	self.frame = InfinityUIFramework:CreateListWindow("InfinityWorldBossFrame", "World Boss estimates", 700, 450)
	local function Input(labelText, x, offset, width, max)
		local label = InfinityUIFramework:CreateLabel(self.frame, labelText)
		label:SetPoint("TOPLEFT", x, -43)
		local box = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
		box:SetSize(width, 20)
		box:SetPoint("TOPLEFT", x + offset, -38)
		box:SetAutoFocus(false)
		box:SetMaxLetters(max)
		return box
	end
	self.idInput = Input("ID", 15, 25, 65, 10)
	self.intervalInput = Input("Seconds", 112, 63, 65, 10)
	self.nameInput = Input("Name", 250, 43, 130, 100)
	local function Number(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then return nil end
		if type(value) ~= "string" or not value:match("^%s*%d+%s*$") then return nil end
		return tonumber(value)
	end
	local function Button(text, x, width, action)
		local button = InfinityUIFramework:CreateButton(self.frame, text, width, 22, action)
		button:SetPoint("TOPLEFT", x, -38)
		return button
	end
	self.addButton = Button("Add", 430, 50, function()
		self.confirmAction = nil
		local name = self.nameInput:GetText()
		if _G.issecretvalue and _G.issecretvalue(name) then name = nil end
		local ok, problem = InfinityWorldBossCore:RegisterBoss(Number(self.idInput), name, Number(self.intervalInput))
		if not ok then InfinityUtils:Warning(problem, "WorldBoss") else self:Refresh() end
	end)
	self.intervalButton = Button("Interval", 484, 60, function()
		self.confirmAction = nil
		local ok, problem = InfinityWorldBossCore:SetInterval(Number(self.idInput), Number(self.intervalInput))
		if not ok then InfinityUtils:Warning(problem, "WorldBoss") else self:Refresh() end
	end)
	local function Confirm(action)
		local id = Number(self.idInput)
		if not id or not InfinityWorldBossCore.bosses[id] then
			self.confirmAction = nil
			InfinityUtils:Warning("Encounter ID is not registered.", "WorldBoss")
			return
		end
		local key = action .. ":" .. id
		if self.confirmAction ~= key then
			self.confirmAction = key
			self.frame.status:SetText(action .. " boss " .. id .. "? Click again to confirm.")
		else
			self.confirmAction = nil
			if action == "Clear kill" then InfinityWorldBossCore:ClearKill(id) else InfinityWorldBossCore:RemoveBoss(id) end
			self:Refresh()
		end
	end
	self.clearButton = Button("Clear", 548, 55, function() Confirm("Clear kill") end)
	self.removeButton = Button("Delete", 607, 65, function() Confirm("Delete") end)
end

function UI:Refresh()
	if not self.frame then return end
	self.confirmAction = nil
	local items = {}
	local now = time()
	for _, entry in ipairs(InfinityWorldBossCore:GetAllBosses()) do
		local id, boss = entry.id, entry.boss
		local report = _G.InfinityGuildBossReports and InfinityGuildBossReports:GetReport(id)
		local shared = ""
		if report then
			local ok, when = false, nil
			if _G.date then ok, when = pcall(date, "%Y-%m-%d %H:%M", report.killed) end
			if not ok or type(when) ~= "string" then when = "timestamp " .. report.killed end
			shared = " | Guild report: " .. when
		end
		items[#items + 1] = {
			text = string.format("%s [%d] - %s%s", boss.name, id, InfinityWorldBossCore:Describe(boss, now), shared),
			onClick = function()
				local ok, problem = InfinityWorldBossCore:RecordBossKill(id, time())
				if not ok then InfinityUtils:Warning(problem, "WorldBoss") end
				self:Refresh()
			end,
		}
	end
	if #items == 0 then items[1] = { text = "No bosses registered. Enter an ID, interval and name, then click Add." } end
	self.frame:SetItems(items)
	self.frame.status:SetText("Click to record a local kill. Guild reports may be from another layer.")
end

function UI:Show()
	self:Initialize()
	self:Refresh()
	self.frame:Show()
end

function UI:Hide()
	self.confirmAction = nil
	if self.frame then self.frame:Hide() end
end

function UI:Toggle()
	self:Initialize()
	if self.frame:IsShown() then self:Hide() else self:Show() end
end

return UI
