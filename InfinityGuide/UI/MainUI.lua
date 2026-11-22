InfinityGuideUI = {}

function InfinityGuideUI:Initialize()
	if self.eventFrame then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_LOG_UPDATE")
	local ok, err = pcall(events.RegisterEvent, events, "QUEST_WATCH_LIST_CHANGED")
	if not ok then
		InfinityUtils:Warning("Quest watch updates unavailable: " .. tostring(err), "Guide")
	end
	local questEventOK, questEventError = pcall(events.RegisterEvent, events, "QUEST_TURNED_IN")
	if not questEventOK then InfinityUtils:Warning("Quest completion updates unavailable: " .. tostring(questEventError), "Guide") end
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "QUEST_TURNED_IN" and _G.InfinityGuideGuides then
			InfinityGuideGuides:OnQuestTurnedIn(...)
		end
		if InfinityGuideUI.frame and InfinityGuideUI.frame:IsShown() then
			InfinityGuideUI:Refresh()
		end
		if InfinityGuideUI.guideFrame and InfinityGuideUI.guideFrame:IsShown() then
			InfinityGuideUI:RefreshGuides()
		end
	end)
	self.eventFrame = events
end

function InfinityGuideUI:Refresh()
	if not self.frame then return end
	local items, status = InfinityUIFramework:CreateQuestLogItems(function() self:Refresh() end, "Guide")
	self.frame.status:SetText(status)
	self.frame:SetItems(items)
end

function InfinityGuideUI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityGuideWindow", "Quest Log", 600, 500)
		local button = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
		button:SetSize(125, 22)
		button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -40, -10)
		button:SetText("My Guides")
		button:SetScript("OnClick", function() self:ShowGuides() end)
	end

	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end

function InfinityGuideUI:ShowGuides()
	if not self.guideFrame then
		self.guideFrame = InfinityUIFramework:CreateListWindow("InfinityCustomGuideWindow", "My Guides", 600, 500)
		local share = CreateFrame("Button", nil, self.guideFrame, "UIPanelButtonTemplate")
		share:SetSize(125, 22)
		share:SetPoint("TOPRIGHT", self.guideFrame, "TOPRIGHT", -40, -10)
		share:SetText("Share with guild")
		share:SetScript("OnClick", function()
			if self.showGuide and _G.InfinityGuideGuildPresets then
				InfinityGuideGuildPresets:Send(self.showGuide)
			else
				InfinityUtils:Warning("Select a guide before sharing.", "Guide")
			end
		end)
		local pause = CreateFrame("Button", nil, self.guideFrame, "UIPanelButtonTemplate")
		pause:SetSize(85, 22)
		pause:SetPoint("TOPRIGHT", self.guideFrame, "TOPRIGHT", -170, -10)
		pause:SetText("Use none")
		pause:SetScript("OnClick", function()
			if _G.InfinityGuideGuides and InfinityGuideGuides.initialized then
				InfinityGuideGuides:ClearSelection()
				self:RefreshGuides()
			end
		end)
		local actions = CreateFrame("Button", nil, self.guideFrame, "UIPanelButtonTemplate")
		actions:SetSize(85, 22)
		actions:SetPoint("TOPRIGHT", self.guideFrame, "TOPRIGHT", -260, -10)
		actions:SetText("Edit / Sync")
		actions:SetScript("OnClick", function() self:ShowGuideActions() end)
	end
	self:RefreshGuides()
	self.guideFrame:Show()
end

function InfinityGuideUI:RefreshGuides()
	if not self.guideFrame then return end
	local manager = _G.InfinityGuideGuides
	if not manager or not manager.initialized then
		self.guideFrame.status:SetText("Guide data unavailable.")
		self.guideFrame:SetItems({})
		return
	end
	local items = {}
	local guide = self.showGuide and manager.guides[self.showGuide]
	if type(guide) == "table" and type(guide.steps) == "table" then
		items[#items + 1] = {
			text = "< All guides",
			onClick = function() self.showGuide = nil; self:RefreshGuides() end,
		}
		items[#items + 1] = { text = guide.name .. " (" .. self.showGuide .. ")" }
		for index, step in ipairs(guide.steps) do
			if type(step) == "table" and type(step.description) == "string" then
				local number, completed, guideId = index, step.done, self.showGuide
				local description = step.description
				if type(step.questID) == "number" and description == "Quest " .. step.questID
					and _G.C_QuestLog and C_QuestLog.GetTitleForQuestID then
					local title = C_QuestLog.GetTitleForQuestID(step.questID)
					if _G.issecretvalue and issecretvalue(title) then title = nil end
					if type(title) == "string" and title ~= "" and #title <= 70 then description = title end
				end
				items[#items + 1] = {
					text = (completed and "[x] " or "[ ] ") .. number .. ". "
						.. (type(step.questID) == "number" and ("[Q" .. step.questID .. "] ") or "")
						.. description,
					onClick = function()
						manager:SetStepDone(guideId, number, not completed)
						self:RefreshGuides()
					end,
				}
			end
		end
		self.guideFrame.status:SetText("Click a step to mark it done or undo it.")
	else
		self.showGuide = nil
		local guides = {}
		for id, entry in pairs(manager.guides) do
			if type(id) == "string" and type(entry) == "table" and type(entry.name) == "string"
				and type(entry.steps) == "table" then guides[#guides + 1] = { id = id, name = entry.name } end
		end
		table.sort(guides, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
		for _, entry in ipairs(guides) do
			local id = entry.id
			items[#items + 1] = {
				text = (manager.activeGuide == id and "* " or "") .. entry.name .. " (" .. id .. ")",
				onClick = function()
					if manager:ViewGuide(id) then self.showGuide = id; self:RefreshGuides() end
				end,
			}
		end
		if #items == 0 then items[1] = { text = "No custom guides yet." } end
		self.guideFrame.status:SetText("Click a guide to select it; use Edit / Sync to manage guides.")
	end
	self.guideFrame:SetItems(items)
	if self.actionsFrame and self.actionsFrame:IsShown() then self:RefreshGuideActions() end
end

local function GuideInput(box)
	local value = box:GetText()
	if _G.issecretvalue and _G.issecretvalue(value) then
		InfinityUtils:Warning("Protected input cannot be used.", "Guide")
		return nil
	end
	if type(value) ~= "string" then
		InfinityUtils:Warning("Guide input is unavailable.", "Guide")
		return nil
	end
	return value:match("^%s*(.-)%s*$")
end

function InfinityGuideUI:ShowGuideActions()
	if not self.actionsFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityGuideActionsWindow", "Guide Editor and Guild Sync", 680, 500)
		local textLabel = InfinityUIFramework:CreateLabel(frame, "Text")
		textLabel:SetPoint("TOPLEFT", 15, -43)
		local text = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		text:SetSize(245, 20)
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 55, -38)
		text:SetAutoFocus(false)
		text:SetMaxLetters(80)
		local numberLabel = InfinityUIFramework:CreateLabel(frame, "Quest ID / step")
		numberLabel:SetPoint("TOPLEFT", 320, -43)
		local number = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		number:SetSize(100, 20)
		number:SetPoint("TOPLEFT", frame, "TOPLEFT", 425, -38)
		number:SetAutoFocus(false)
		number:SetMaxLetters(10)
		self.actionsFrame, self.actionText, self.actionNumber = frame, text, number
	end
	self.confirmGuideAction, self.confirmGuideRow = nil, nil
	self:RefreshGuideActions()
	self.actionsFrame:Show()
end

function InfinityGuideUI:RefreshGuideActions()
	if not self.actionsFrame then return end
	local manager, source, network = _G.InfinityGuideGuides, _G.InfinityGuideSources, _G.InfinityGuideGuildPresets
	if not manager or not manager.initialized then
		self.actionsFrame.status:SetText("Guides unavailable.")
		self.actionsFrame:SetItems({})
		return
	end
	local pending = network and network.pending
	if _G.issecretvalue and _G.issecretvalue(pending) then pending = nil end
	local function Confirm(key, message)
		if self.confirmGuideAction ~= key then
			self.confirmGuideAction = key
			self.actionsFrame.status:SetText(message .. " Click the same action again to confirm.")
			return false
		end
		self.confirmGuideAction = nil
		return true
	end
	local actions = {
		{ "Create guide | Text: name", function()
			local name = GuideInput(self.actionText)
			if not name then return end
			local guide = manager:CreateGuide(name)
			if guide then self.showGuide = guide.id; self:ShowGuides() end
		end },
		{ "Add step | Text: description; Quest ID optional", function()
			local description, raw = GuideInput(self.actionText), GuideInput(self.actionNumber)
			if not description or not raw then return end
			local questID = raw ~= "" and tonumber(raw) or nil
			if raw ~= "" and not questID then InfinityUtils:Warning("Enter a valid quest ID.", "Guide"); return end
			local id, guide = manager.activeGuide, manager.guides[manager.activeGuide]
			local count = type(guide) == "table" and type(guide.steps) == "table" and #guide.steps or 0
			if manager:AddGuideStep(id, count + 1, description, questID) then self.showGuide = id; self:ShowGuides() end
		end },
		{ "Remove step | Step number; click twice to confirm", function()
			local raw = GuideInput(self.actionNumber)
			if not raw then return end
			local number, id = tonumber(raw), manager.activeGuide
			if not number or not id then InfinityUtils:Warning("Select a guide and enter a step number.", "Guide"); return end
			if Confirm("step:" .. id .. ":" .. raw, "Remove step " .. raw .. " from " .. id .. "?")
				and manager:RemoveGuideStep(id, number) then self:RefreshGuides() end
		end },
		{ "Delete selected guide | Click twice to confirm", function()
			local id = manager.activeGuide
			if not id then InfinityUtils:Warning("Select a guide first.", "Guide"); return end
			if Confirm("delete:" .. id, "Delete guide " .. id .. "?") and manager:DeleteGuide(id) then
				self.showGuide = nil
				self:RefreshGuides()
			end
		end },
		{ "Allow QuestieDB guide imports", function()
			if not source or not source:SetAllowed(true) then InfinityUtils:Warning("QuestieDB settings unavailable.", "Guide") end
		end },
		{ "Disable QuestieDB guide imports", function()
			if not source or not source:SetAllowed(false) then InfinityUtils:Warning("QuestieDB settings unavailable.", "Guide") end
		end },
		{ "Import QuestieDB chain | Quest ID: first quest", function()
			local raw = GuideInput(self.actionNumber)
			if not raw then return end
			if not source then InfinityUtils:Warning("QuestieDB imports unavailable.", "Guide"); return end
			if source:ImportChain(tonumber(raw)) then self.showGuide = nil; self:ShowGuides() end
		end },
		{ "Request guild presets", function()
			if network then network:Request() else InfinityUtils:Warning("Guild presets unavailable.", "Guide") end
		end },
		{ "Publish all local presets | Click twice to confirm", function()
			if not network then InfinityUtils:Warning("Guild presets unavailable.", "Guide"); return end
			if Confirm("publish-all", "Publish all local presets to the guild?") then network:Send(nil, true) end
		end },
		{ "Manage published presets", function() self:ShowPublishedPresets() end },
		{ "Save and republish pending guild preset", function()
			if not network then InfinityUtils:Warning("Guild presets unavailable.", "Guide"); return end
			local current = network.pending
			if _G.issecretvalue and _G.issecretvalue(current) then current = nil end
			if current ~= pending then
				self:RefreshGuideActions()
				InfinityUtils:Warning("Pending preset changed. Review it before saving.", "Guide")
				return
			end
			network:Accept()
			self:RefreshGuideActions()
		end },
		{ "Discard pending guild preset", function()
			if not network then InfinityUtils:Warning("Guild presets unavailable.", "Guide"); return end
			local current = network.pending
			if _G.issecretvalue and _G.issecretvalue(current) then current = nil end
			if current ~= pending then
				self:RefreshGuideActions()
				InfinityUtils:Warning("Pending preset changed. Review it before discarding.", "Guide")
				return
			end
			network:Discard()
			self:RefreshGuideActions()
		end },
	}
	local rows = {}
	if type(pending) == "table" and not (_G.issecretvalue and (issecretvalue(pending.name) or issecretvalue(pending.sender)))
		and type(pending.name) == "string" and type(pending.sender) == "string" then
		rows[#rows + 1] = { text = "Pending: " .. pending.name .. " from " .. pending.sender }
	else
		rows[#rows + 1] = { text = "No guild preset pending review." }
	end
	for _, action in ipairs(actions) do
		local item = action
		rows[#rows + 1] = { text = item[1], onClick = function()
			if self.confirmGuideRow ~= item[1] then self.confirmGuideAction = nil end
			self.confirmGuideRow = item[1]
			item[2]()
		end }
	end
	self.actionsFrame.status:SetText("Selected guide: " .. (manager.activeGuide or "none") .. " | Click an action.")
	self.actionsFrame:SetItems(rows)
end

function InfinityGuideUI:ShowPublishedPresets()
	local network = _G.InfinityGuideGuildPresets
	if not network then InfinityUtils:Warning("Guild presets unavailable.", "Guide"); return end
	local keys = network:GetPublished()
	if not keys then return end
	if not self.publishedFrame then
		self.publishedFrame = InfinityUIFramework:CreateListWindow("InfinityPublishedPresetsWindow", "Published Guild Presets", 600, 450)
	end
	if not self.publishedFrame:IsShown() then self.confirmUnpublish = nil end
	local rows = {}
	for _, key in ipairs(keys) do
		local id = key
		rows[#rows + 1] = { text = id .. " - click twice to stop publishing", onClick = function()
			if self.confirmUnpublish ~= id then
				self.confirmUnpublish = id
				self.publishedFrame.status:SetText("Stop publishing " .. id .. "? Click it again to confirm.")
			elseif network:Unpublish(id) then
				self.confirmUnpublish = nil
				self:ShowPublishedPresets()
			end
		end }
	end
	if #rows == 0 then rows[1] = { text = "No published presets." } end
	self.publishedFrame.status:SetText("Copies already received by others remain.")
	self.publishedFrame:SetItems(rows)
	self.publishedFrame:Show()
end
