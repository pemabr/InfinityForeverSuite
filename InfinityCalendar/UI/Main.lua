-- InfinityCalendar UI - Calendar Interface
-- Displays events, allows creation/editing, and shows raid calendar

InfinityCalendarUI = {
	mainFrame = nil,
	currentMonth = nil,
	currentYear = nil,
	selectedDate = nil,
	displayMode = "month",  -- month, list, event
	selectedEvent = nil,
}

local function ContentText(self, font)
	self.textPools[font] = self.textPools[font] or {}
	local pool = self.textPools[font]
	local index = (self.textUsage[font] or 0) + 1
	self.textUsage[font] = index
	local text = pool[index]
	if not text then
		text = self.contentArea:CreateFontString(nil, "ARTWORK", font)
		pool[index] = text
	end
	text:ClearAllPoints()
	text:SetTextColor(1, 1, 1, 1)
	text:SetMaxLines(0)
	text:Show()
	return text
end

local function ContentButton(self, template)
	local key = template or "plain"
	self.buttonPools[key] = self.buttonPools[key] or {}
	local pool = self.buttonPools[key]
	local index = (self.buttonUsage[key] or 0) + 1
	self.buttonUsage[key] = index
	local button = pool[index]
	if not button then
		button = CreateFrame("Button", nil, self.contentArea, template)
		pool[index] = button
	end
	button.confirming = false
	button:ClearAllPoints()
	button:Show()
	return button
end

-- Create main calendar frame
function InfinityCalendarUI:CreateMainFrame()
	if self.mainFrame then
		self.mainFrame:Show()
		return
	end
	
	local frame = CreateFrame("Frame", "InfinityCalendarFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(900, 700)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = {left = 11, right = 12, top = 12, bottom = 11}
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	
	-- Make movable
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	-- Title
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
	title:SetText("INFINITY LOCAL CALENDAR")
	title:SetTextColor(0, 1, 0.5, 1)
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -15)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Navigation buttons
	local prevBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	prevBtn:SetSize(100, 25)
	prevBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -55)
	prevBtn:SetText("< Previous")
	prevBtn:SetScript("OnClick", function()
		InfinityCalendarUI:PreviousMonth()
	end)
	
	local nextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	nextBtn:SetSize(100, 25)
	nextBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 130, -55)
	nextBtn:SetText("Next >")
	nextBtn:SetScript("OnClick", function()
		InfinityCalendarUI:NextMonth()
	end)
	
	local todayBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	todayBtn:SetSize(100, 25)
	todayBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 240, -55)
	todayBtn:SetText("Today")
	todayBtn:SetScript("OnClick", function()
		local now = date("*t", time())
		InfinityCalendarUI.currentMonth = now.month
		InfinityCalendarUI.currentYear = now.year
		InfinityCalendarUI:RefreshDisplay()
	end)
	
	local newEventBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	newEventBtn:SetSize(120, 25)
	newEventBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -120, -55)
	newEventBtn:SetText("New Event")
	newEventBtn:SetScript("OnClick", function()
		InfinityCalendarUI:ShowEventCreationDialog()
	end)
	
	local modeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	modeBtn:SetSize(100, 25)
	modeBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 350, -55)
	modeBtn:SetText("List View")
	modeBtn:SetScript("OnClick", function(selfBtn)
		if InfinityCalendarUI.displayMode == "month" then
			InfinityCalendarUI.displayMode = "list"
			selfBtn:SetText("Month View")
		else
			InfinityCalendarUI.displayMode = "month"
			selfBtn:SetText("List View")
		end
		InfinityCalendarUI:RefreshDisplay()
	end)
	self.modeBtn = modeBtn

	-- Content area
	local contentArea = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentArea:SetSize(860, 600)
	contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -100)
	contentArea:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tile = true, tileSize = 32,
		insets = {left = 5, right = 5, top = 5, bottom = 5}
	})
	contentArea:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
	
	self.mainFrame = frame
	self.contentArea = contentArea
	self.textPools, self.buttonPools = {}, {}
	
	-- Initialize date
	local now = date("*t", time())
	self.currentMonth = now.month
	self.currentYear = now.year
	frame:Hide()
	
	return frame
end

-- Refresh the display
function InfinityCalendarUI:RefreshDisplay()
	if not self.mainFrame then
		return
	end
	self.textUsage, self.buttonUsage = {}, {}
	
	if _G.InfinityUtils and _G.InfinityUtils.ClearContainer then
		_G.InfinityUtils:ClearContainer(self.contentArea)
	else
		for _, child in ipairs({self.contentArea:GetChildren()}) do
			child:Hide()
		end
	end
	
	if self.displayMode == "month" then
		self:DisplayMonthView()
	elseif self.displayMode == "list" then
		self:DisplayListView()
	elseif self.displayMode == "event" and self.selectedEvent then
		self:DisplayEventDetail()
	end
end

-- Display month view
function InfinityCalendarUI:DisplayMonthView()
	-- Month header
	local header = ContentText(self, "GameFontNormalLarge")
	header:SetPoint("TOP", self.contentArea, "TOP", 0, -20)
	header:SetText(date("%B %Y", time({year = self.currentYear, month = self.currentMonth, day = 1})))
	header:SetTextColor(0, 1, 0.5, 1)
	
	-- Day headers
	local days = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
	for i, day in ipairs(days) do
		local dayHeader = ContentText(self, "GameFontNormal")
		dayHeader:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 10 + (i-1) * 120, -60)
		dayHeader:SetText(day)
		dayHeader:SetTextColor(0.7, 0.7, 0.7, 1)
	end
	
	-- Get first day of month
	local firstDay = time({year = self.currentYear, month = self.currentMonth, day = 1, hour = 0, min = 0})
	local firstDayOfWeek = date("%w", firstDay)
	
	-- Get days in month
	local daysInMonth = 31
	if self.currentMonth == 2 then
		local leap = self.currentYear % 4 == 0 and (self.currentYear % 100 ~= 0 or self.currentYear % 400 == 0)
		daysInMonth = leap and 29 or 28
	elseif self.currentMonth == 4 or self.currentMonth == 6 or 
	       self.currentMonth == 9 or self.currentMonth == 11 then
		daysInMonth = 30
	end
	
	-- Display calendar grid
	local row = 0
	local col = tonumber(firstDayOfWeek)
	
	for day = 1, daysInMonth do
		local x = 10 + col * 120
		local y = -90 - row * 80
		
		-- Day number
		local dayText = ContentText(self, "GameFontNormal")
		dayText:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", x, y)
		dayText:SetText(tostring(day))
		
		-- Check for events on this day
		local dayTime = time({year = self.currentYear, month = self.currentMonth, day = day, hour = 0, min = 0})
		local dayEnd = time({year = self.currentYear, month = self.currentMonth, day = day + 1, hour = 0, min = 0}) - 1
		local eventsOnDay = InfinityCalendarCore:GetEventsByDateRange(dayTime, dayEnd)
		
		if #eventsOnDay > 0 then
			dayText:SetTextColor(1, 1, 0, 1)  -- Yellow for days with events
			
			local eventText = ContentText(self, "GameFontSmall")
			eventText:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", x, y - 20)
			eventText:SetText(string.format("%d event%s", #eventsOnDay, #eventsOnDay > 1 and "s" or ""))
			eventText:SetTextColor(0.7, 1, 0.7, 1)
		else
			dayText:SetTextColor(1, 1, 1, 1)
		end
		
		col = col + 1
		if col > 6 then
			col = 0
			row = row + 1
		end
	end
end

-- Display list view
function InfinityCalendarUI:DisplayListView()
	local events = InfinityCalendarCore:GetUpcomingEvents(20)
	
	local y = -20
	
	local header = ContentText(self, "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
	header:SetText("UPCOMING EVENTS")
	header:SetTextColor(0, 1, 0.5, 1)
	
	y = y - 30
	
	for _, event in ipairs(events) do
		local selected = event
		local button = ContentButton(self)
		button:SetSize(800, 20)
		button:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(InfinityCalendarCore:FormatEventDisplay(event))
		button:SetScript("OnClick", function()
			self.selectedEvent = selected
			self.displayMode = "event"
			self:RefreshDisplay()
		end)
		
		y = y - 20
	end
	
	if #events == 0 then
		local text = ContentText(self, "GameFontNormal")
		text:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		text:SetText("No upcoming events")
		text:SetTextColor(0.7, 0.7, 0.7, 1)
	end
end

-- Display event details
function InfinityCalendarUI:DisplayEventDetail()
	local event = self.selectedEvent
	if not event then
		return
	end
	
	local y = -20
	
	local function AddLine(label, value, color)
		local text = ContentText(self, "GameFontNormal")
		text:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		text:SetText(string.format("%-30s: %s", label, value))
		if color then
			text:SetTextColor(color[1], color[2], color[3], 1)
		end
		y = y - 20
	end
	
	AddLine("Title", event.title, {0, 1, 0.5})
	AddLine("Type", event.type)
	AddLine("Leader", event.leader)
	AddLine("Location", event.location)
	AddLine("Start", date("%Y-%m-%d %H:%M", event.startTime))
	AddLine("Duration", string.format("%.0f minutes", event.duration / 60))
	AddLine("Status", event.status, {1, 1, 0})
	
	y = y - 20
	
	local participants = InfinityCalendarCore:GetParticipantCount(event.id)
	AddLine("Confirmed", tostring(participants.confirmed), {0, 1, 0})
	AddLine("Tentative", tostring(participants.tentative), {1, 1, 0})
	AddLine("Declined", tostring(participants.declined), {1, 0, 0})
	
	if event.description ~= "" then
		y = y - 20
		local descHeader = ContentText(self, "GameFontNormal")
		descHeader:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		descHeader:SetText("Description:")
		descHeader:SetTextColor(0.7, 1, 0.7, 1)
		
		y = y - 20
		local desc = ContentText(self, "GameFontNormal")
		desc:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 30, y)
		desc:SetText(event.description)
		desc:SetMaxLines(5)
	end

	local back = ContentButton(self, "UIPanelButtonTemplate")
	back:SetSize(110, 24)
	back:SetPoint("BOTTOMLEFT", self.contentArea, "BOTTOMLEFT", 20, 20)
	back:SetText("Back to list")
	back:SetScript("OnClick", function()
		self.displayMode = "list"
		self.modeBtn:SetText("Month View")
		self:RefreshDisplay()
	end)

	local edit = ContentButton(self, "UIPanelButtonTemplate")
	edit:SetSize(110, 24)
	edit:SetPoint("LEFT", back, "RIGHT", 10, 0)
	edit:SetText("Edit")
	edit:SetScript("OnClick", function() self:ShowEventCreationDialog(event) end)

	local delete = ContentButton(self, "UIPanelButtonTemplate")
	delete:SetSize(120, 24)
	delete:SetPoint("LEFT", edit, "RIGHT", 10, 0)
	delete:SetText("Delete")
	delete:SetScript("OnClick", function(button)
		if not button.confirming then
			button.confirming = true
			button:SetText("Confirm delete")
			return
		end
		if not InfinityCalendarCore:DeleteEvent(event.id) then
			InfinityUtils:Error("Event could not be deleted.", "Calendar")
			return
		end
		self.selectedEvent = nil
		self.displayMode = "list"
		self.modeBtn:SetText("Month View")
		self:RefreshDisplay()
	end)
end

-- Toggle calendar UI
function InfinityCalendarUI:Toggle()
	if not self.mainFrame then
		self:CreateMainFrame()
	end
	
	if self.mainFrame:IsShown() then
		self.mainFrame:Hide()
	else
		self.mainFrame:Show()
		self:RefreshDisplay()
	end
end

-- Show calendar UI
function InfinityCalendarUI:Show()
	if not self.mainFrame then
		self:CreateMainFrame()
	end
	self.mainFrame:Show()
	self:RefreshDisplay()
end

-- Hide calendar UI
function InfinityCalendarUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end

-- Navigation
function InfinityCalendarUI:NextMonth()
	self.currentMonth = self.currentMonth + 1
	if self.currentMonth > 12 then
		self.currentMonth = 1
		self.currentYear = self.currentYear + 1
	end
	self:RefreshDisplay()
end

function InfinityCalendarUI:PreviousMonth()
	self.currentMonth = self.currentMonth - 1
	if self.currentMonth < 1 then
		self.currentMonth = 12
		self.currentYear = self.currentYear - 1
	end
	self:RefreshDisplay()
end

-- Show event creation dialog
function InfinityCalendarUI:ShowEventCreationDialog(event)
	if self.createDialog then
		self:PopulateEventDialog(event)
		self.createDialog:Show()
		return
	end

	local dlg = CreateFrame("Frame", "InfinityCalendarCreateDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dlg:SetSize(380, 310)
	dlg:SetPoint("CENTER")
	dlg:SetFrameStrata("DIALOG")
	dlg:SetMovable(true)
	dlg:EnableMouse(true)
	dlg:RegisterForDrag("LeftButton")
	dlg:SetScript("OnDragStart", dlg.StartMoving)
	dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
	dlg:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4}
	})
	dlg:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
	dlg:SetBackdropBorderColor(0, 0.8, 1, 0.8)

	local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("Create Local Event")

	local function MakeInput(labelText, yPos, defaultText)
		local lbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		lbl:SetPoint("TOPLEFT", 18, yPos)
		lbl:SetText(labelText)
		local eb = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
		eb:SetSize(210, 22)
		eb:SetPoint("TOPLEFT", 145, yPos + 4)
		eb:SetAutoFocus(false)
		eb:SetText(defaultText or "")
		return eb
	end

	local titleBox = MakeInput("Title:", -45, "Guild Raid")
	local typeOptions = {"raid", "dungeon", "pvp", "social", "other"}
	self.typeOptions = typeOptions
	self.typeIndex = 1
	local typeLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	typeLbl:SetPoint("TOPLEFT", 18, -80)
	typeLbl:SetText("Type:")
	local typeBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	typeBtn:SetSize(120, 22)
	typeBtn:SetPoint("TOPLEFT", 140, -76)
	typeBtn:SetText(typeOptions[self.typeIndex])
	typeBtn:SetScript("OnClick", function(selfBtn)
		self.typeIndex = (self.typeIndex % #typeOptions) + 1
		selfBtn:SetText(typeOptions[self.typeIndex])
	end)

	local todayStr = date("%Y-%m-%d")
	local dateBox = MakeInput("Date (YYYY-MM-DD):", -115, todayStr)
	local timeBox = MakeInput("Time (HH:MM):", -150, "20:00")
	local durBox = MakeInput("Duration (min):", -185, "180")
	local locBox = MakeInput("Location:", -220, GetRealZoneText() or "Raid")

	local createBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	createBtn:SetSize(100, 24)
	createBtn:SetPoint("BOTTOMLEFT", 60, 16)
	createBtn:SetText("Create")
	createBtn:SetScript("OnClick", function()
		local evTitle = titleBox:GetText():match("^%s*(.-)%s*$")
		local startTs = InfinityCalendarCore:ParseDateTime(dateBox:GetText(), timeBox:GetText())
		local minutes = tonumber(durBox:GetText())
		if evTitle == "" or not startTs or not minutes or minutes ~= minutes
			or minutes <= 0 or minutes >= math.huge / 60 then
			InfinityUtils:Error("Enter a title, valid date, time and positive duration.", "Calendar")
			return
		end
		local data = {
			title = evTitle,
			type = typeOptions[self.typeIndex],
			startTime = startTs,
			duration = minutes * 60,
			location = locBox:GetText(),
		}
		local ok, res
		if dlg.eventID then
			ok, res = InfinityCalendarCore:UpdateEvent(dlg.eventID, data)
		else
			data.leader = UnitName("player")
			ok, res = InfinityCalendarCore:CreateEvent(data)
		end
		if ok then
			dlg:Hide()
			InfinityCalendarUI:RefreshDisplay()
		else
			InfinityUtils:Error("Failed to save event: " .. tostring(res), "Calendar")
		end
	end)

	local cancelBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	cancelBtn:SetSize(100, 24)
	cancelBtn:SetPoint("BOTTOMRIGHT", -60, 16)
	cancelBtn:SetText("Cancel")
	cancelBtn:SetScript("OnClick", function()
		dlg:Hide()
	end)

	self.createDialog = dlg
	self.createInputs = {
		title = titleBox, date = dateBox, clock = timeBox, duration = durBox,
		location = locBox, type = typeBtn, heading = title, save = createBtn,
	}
	self:PopulateEventDialog(event)
	dlg:Show()
end

function InfinityCalendarUI:PopulateEventDialog(event)
	local fields = self.createInputs
	local start = event and event.startTime or time()
	self.createDialog.eventID = event and event.id or nil
	fields.heading:SetText(event and "Edit Local Event" or "Create Local Event")
	fields.save:SetText(event and "Save" or "Create")
	fields.title:SetText(event and event.title or "")
	fields.date:SetText(date("%Y-%m-%d", start))
	fields.clock:SetText(event and date("%H:%M", start) or "20:00")
	fields.duration:SetText(event and tostring(event.duration / 60) or "180")
	fields.location:SetText(event and event.location or (_G.GetRealZoneText and GetRealZoneText() or ""))
	self.typeIndex = 1
	for index, value in ipairs(self.typeOptions) do
		if event and value == event.type then self.typeIndex = index; break end
	end
	fields.type:SetText(self.typeOptions[self.typeIndex])
end

return InfinityCalendarUI
