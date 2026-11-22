local UI = { metric = "damage", session = "current" }
_G.InfinityDetailsUI = UI

local metricTypes = {
	damage = "DamageDone",
	healing = "HealingDone",
	absorbs = "Absorbs",
	taken = "DamageTaken",
	interrupts = "Interrupts",
	dispels = "Dispels",
}

local function Secret(value)
	return _G.issecretvalue and _G.issecretvalue(value)
end

local function Public(value)
	if Secret(value) then return nil end
	return value
end

local function FormatAmount(value)
	if Secret(value) then
		if _G.AbbreviateNumbers then return AbbreviateNumbers(value) end
		return "Protected"
	end
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then return "?" end
	return string.format("%.0f", value)
end

function UI:GetTypes(metricName)
	local types = _G.Enum and _G.Enum.DamageMeterType
	local sessions = _G.Enum and _G.Enum.DamageMeterSessionType
	local name = metricName or self.metric
	local metric = types and types[metricTypes[name]]
	if metric == nil and name == "damage" then metric = 0 end
	if metric == nil and name == "healing" then metric = 2 end
	local session = self.session == "overall" and (sessions and sessions.Overall or 0)
		or (sessions and sessions.Current or 1)
	return session, metric
end

function UI:GetSession(metricName)
	if not (_G.C_DamageMeter and C_DamageMeter.GetCombatSessionFromType) then
		if self.session ~= "current" then return nil, "Overall session unavailable without the native meter." end
		local meters = _G.InfinityDetailsMeters
		if not meters then return nil, "Combat meter unavailable." end
		if (metricName or self.metric) ~= "damage" and (metricName or self.metric) ~= "healing" then
			return nil, "This metric requires the native meter."
		end
		local healing = (metricName or self.metric) == "healing"
		local values = healing and meters:GetHPSMeter(20) or meters:GetDPSMeter(20)
		local sources = {}
		for _, value in ipairs(values) do
			sources[#sources + 1] = {
				name = value.name,
				totalAmount = healing and value.healing or value.damage,
				amountPerSecond = healing and value.hps or value.dps,
			}
		end
		return { combatSources = sources }, nil, sources
	end
	local sessionType, metric = self:GetTypes(metricName)
	if metric == nil then return nil, "This metric is unavailable on this client." end
	local session = Public(C_DamageMeter.GetCombatSessionFromType(sessionType, metric))
	if type(session) ~= "table" then return nil, "No " .. self.session .. " session available." end
	local sources = Public(session.combatSources)
	if type(sources) ~= "table" then return nil, "Combat sources unavailable." end
	return session, nil, sources
end

function UI:Initialize()
	if self.frame then return end
	local frame = InfinityUIFramework:CreateListWindow("InfinityDetailsMainFrame", "Infinity Details", 700, 500)
	self.frame = frame
	local function button(text, x, callback)
		local b = InfinityUIFramework:CreateButton(frame, text, 90, 22, callback)
		b:SetPoint("TOPLEFT", x, -35)
	end
	button("Damage", 15, function() self.metric = "damage"; self.selected = nil; self:Update() end)
	button("Healing", 110, function() self.metric = "healing"; self.selected = nil; self:Update() end)
	button("Current", 205, function() self.session = "current"; self.selected = nil; self:Update() end)
	button("Overall", 300, function() self.session = "overall"; self.selected = nil; self:Update() end)
	button("Back", 395, function() self.selected = nil; self:Update() end)
	local extras, extraIndex = { "absorbs", "taken", "interrupts", "dispels" }, 0
	button("More", 490, function()
		extraIndex = extraIndex % #extras + 1
		self.metric = extras[extraIndex]
		self.selected = nil
		self:Update()
	end)
	button("Report", 585, function() self:ShowReport() end)
end

function UI:ShowReport()
	if not self.reportFrame then
		local frame = InfinityUIFramework:CreateFrame("InfinityDetailsReportFrame", UIParent, 650, 450)
		frame:SetPoint("CENTER")
		local title = InfinityUIFramework:CreateLabel(frame, "Combat report - select and copy")
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
		self.reportFrame, self.reportText, self.reportScroll = frame, edit, scroll
	end
	local report = self:BuildReport("damage") .. "\n\n" .. self:BuildReport("healing")
	self.reportText:SetText(report)
	local _, lines = report:gsub("\n", "\n")
	self.reportText:SetHeight(math.max(370, (lines + 1) * 24))
	self.reportScroll:UpdateScrollChildRect()
	self.reportFrame:Show()
end

function UI:Toggle()
	self:Initialize()
	if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Update() end
end

function UI:Show()
	self:Initialize()
	self.frame:Show()
	self:Update()
end

function UI:Update()
	if not self.frame or not self.frame:IsShown() then return end
	local session, problem, sources = self:GetSession()
	if not session then
		self.frame:SetItems({})
		self.frame.status:SetText(problem)
		return
	end
	local entries, status = {}, self.session .. " " .. self.metric .. " | Name / total / per second"
	if self.selected then
		local api = _G.C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType
		if not api then
			self.selected = nil
			status = "Spell breakdown unavailable."
		else
			local sessionType, metric = self:GetTypes()
			local selected = self.selected
			local details = Public(api(sessionType, metric, selected.guid, selected.creatureID))
			local spells = type(details) == "table" and Public(details.combatSpells)
			if type(spells) ~= "table" then
				self.frame:SetItems({})
				self.frame.status:SetText("Spell breakdown unavailable; use Back.")
				return
			end
			status = "Spell breakdown | Name / total / per second"
			for _, spell in ipairs(spells) do
				if not Secret(spell) and type(spell) == "table" then
					local id = Public(spell.spellID)
					local name
					if type(id) == "number" and id == id and id > 0 and id < math.huge and id == math.floor(id) then
						name = _G.C_Spell and C_Spell.GetSpellName and Public(C_Spell.GetSpellName(id))
						name = type(name) == "string" and name or ("Spell " .. id)
					else
						name = "Protected or unknown spell"
					end
					entries[#entries + 1] = { text = name, total = spell.totalAmount, rate = spell.amountPerSecond }
				end
			end
		end
	end
	if not self.selected then
		for _, source in ipairs(sources) do
			if not Secret(source) and type(source) == "table" then
				local name, guid, creature = source.name, Public(source.sourceGUID), Public(source.sourceCreatureID)
				if not Secret(name) and type(name) ~= "string" then name = "Unknown source" end
				local row = { text = name, total = source.totalAmount, rate = source.amountPerSecond }
				if type(guid) == "string" and guid ~= "" and _G.C_DamageMeter
					and C_DamageMeter.GetCombatSessionSourceFromType then
					row.onClick = function()
						self.selected = { guid = guid, creatureID = creature }
						self:Update()
					end
				end
				entries[#entries + 1] = row
			end
		end
		if _G.C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType then
			status = status .. " | Click a public source for spells."
		else
			status = status .. " | Spell breakdown unavailable."
		end
	end
	self.frame:SetItems(entries)
	for i, entry in ipairs(entries) do
		local row = self.frame.rows[i]
		row.label:SetWidth(300)
		if not row.total then
			row.total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.total:SetPoint("RIGHT", -130, 0)
			row.total:SetWidth(110)
			row.total:SetJustifyH("RIGHT")
			row.rate = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.rate:SetPoint("RIGHT", -5, 0)
			row.rate:SetWidth(110)
			row.rate:SetJustifyH("RIGHT")
		end
		row.total:SetText(FormatAmount(entry.total))
		row.rate:SetText(FormatAmount(entry.rate))
	end
	self.frame.status:SetText(status)
end

function UI:BuildReport(metric)
	local session, problem, sources = self:GetSession(metric)
	if not session then return problem end
	local lines = { self.session .. " " .. metric .. " | total | per second" }
	for _, source in ipairs(sources) do
		if Secret(source) or type(source) ~= "table" then return "Report unavailable: combat data is protected." end
		local name, total, rate = Public(source.name), Public(source.totalAmount), Public(source.amountPerSecond)
		if type(name) ~= "string" or type(total) ~= "number" or type(rate) ~= "number"
			or total ~= total or rate ~= rate or total < 0 or rate < 0 or total >= math.huge or rate >= math.huge then
			return "Report unavailable: combat data is protected or incomplete."
		end
		lines[#lines + 1] = string.format("%s | %.0f | %.0f", name, total, rate)
	end
	if #lines == 1 then lines[#lines + 1] = "No combat data." end
	return table.concat(lines, "\n")
end

return UI
