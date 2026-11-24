-- PluribusCalendar UI - Calendar Interface
-- Displays events, allows creation/editing, and shows raid calendar

PluribusCalendarUI = {
	mainFrame = nil,
	currentMonth = nil,
	currentYear = nil,
	selectedDate = nil,
	displayMode = "month",  -- month, list, event
	selectedEvent = nil,
}

-- Create main calendar frame
function PluribusCalendarUI:CreateMainFrame()
	if self.mainFrame then
		self.mainFrame:Show()
		return
	end
	
	local frame = CreateFrame("Frame", "PluribusCalendarFrame", UIParent)
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
	title:SetText("PLURIBUS GUILD CALENDAR")
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
		PluribusCalendarUI:PreviousMonth()
	end)
	
	local nextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	nextBtn:SetSize(100, 25)
	nextBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 130, -55)
	nextBtn:SetText("Next >")
	nextBtn:SetScript("OnClick", function()
		PluribusCalendarUI:NextMonth()
	end)
	
	local todayBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	todayBtn:SetSize(100, 25)
	todayBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 240, -55)
	todayBtn:SetText("Today")
	todayBtn:SetScript("OnClick", function()
		local now = date("*t", time())
		PluribusCalendarUI.currentMonth = now.month
		PluribusCalendarUI.currentYear = now.year
		PluribusCalendarUI:RefreshDisplay()
	end)
	
	local newEventBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	newEventBtn:SetSize(120, 25)
	newEventBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -120, -55)
	newEventBtn:SetText("New Event")
	newEventBtn:SetScript("OnClick", function()
		PluribusCalendarUI:ShowEventCreationDialog()
	end)
	
	-- Content area
	local contentArea = CreateFrame("Frame", nil, frame)
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
	
	-- Initialize date
	local now = date("*t", time())
	self.currentMonth = now.month
	self.currentYear = now.year
	
	return frame
end

-- Refresh the display
function PluribusCalendarUI:RefreshDisplay()
	if not self.mainFrame then
		return
	end
	
	for _, child in ipairs({self.contentArea:GetChildren()}) do
		child:Hide()
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
function PluribusCalendarUI:DisplayMonthView()
	-- Month header
	local header = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOP", self.contentArea, "TOP", 0, -20)
	header:SetText(date("%B %Y", time({year = self.currentYear, month = self.currentMonth, day = 1})))
	header:SetTextColor(0, 1, 0.5, 1)
	
	-- Day headers
	local days = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
	for i, day in ipairs(days) do
		local dayHeader = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		dayHeader:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 10 + (i-1) * 120, -60)
		dayHeader:SetText(day)
		dayHeader:SetTextColor(0.7, 0.7, 0.7, 1)
	end
	
	-- Get first day of month
	local firstDay = time({year = self.currentYear, month = self.currentMonth, day = 1})
	local firstDayOfWeek = date("%w", firstDay)
	
	-- Get days in month
	local daysInMonth = 31
	if self.currentMonth == 2 then
		daysInMonth = (self.currentYear % 4 == 0) and 29 or 28
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
		local dayText = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		dayText:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", x, y)
		dayText:SetText(tostring(day))
		
		-- Check for events on this day
		local dayTime = time({year = self.currentYear, month = self.currentMonth, day = day})
		local dayEnd = dayTime + 86400
		local eventsOnDay = PluribusCalendarCore:GetEventsByDateRange(dayTime, dayEnd)
		
		if #eventsOnDay > 0 then
			dayText:SetTextColor(1, 1, 0, 1)  -- Yellow for days with events
			
			local eventText = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontSmall")
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
function PluribusCalendarUI:DisplayListView()
	local events = PluribusCalendarCore:GetUpcomingEvents(20)
	
	local y = -20
	
	local header = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
	header:SetText("UPCOMING EVENTS")
	header:SetTextColor(0, 1, 0.5, 1)
	
	y = y - 30
	
	for _, event in ipairs(events) do
		local text = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		text:SetText(PluribusCalendarCore:FormatEventDisplay(event))
		
		local color = event.type == "raid" and {1, 1, 0} or {0.7, 1, 0.7}
		text:SetTextColor(color[1], color[2], color[3], 1)
		
		y = y - 20
	end
	
	if #events == 0 then
		local text = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		text:SetText("No upcoming events")
		text:SetTextColor(0.7, 0.7, 0.7, 1)
	end
end

-- Display event details
function PluribusCalendarUI:DisplayEventDetail()
	if not self.selectedEvent then
		return
	end
	
	local event = self.selectedEvent
	local y = -20
	
	local function AddLine(label, value, color)
		local text = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
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
	
	local participants = PluribusCalendarCore:GetParticipantCount(event.id)
	AddLine("Confirmed", tostring(participants.confirmed), {0, 1, 0})
	AddLine("Tentative", tostring(participants.tentative), {1, 1, 0})
	AddLine("Declined", tostring(participants.declined), {1, 0, 0})
	
	if event.description ~= "" then
		y = y - 20
		local descHeader = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		descHeader:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 20, y)
		descHeader:SetText("Description:")
		descHeader:SetTextColor(0.7, 1, 0.7, 1)
		
		y = y - 20
		local desc = self.contentArea:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		desc:SetPoint("TOPLEFT", self.contentArea, "TOPLEFT", 30, y)
		desc:SetText(event.description)
		desc:SetMaxLines(5)
	end
end

-- Toggle calendar UI
function PluribusCalendarUI:Toggle()
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
function PluribusCalendarUI:Show()
	if not self.mainFrame then
		self:CreateMainFrame()
	end
	self.mainFrame:Show()
	self:RefreshDisplay()
end

-- Hide calendar UI
function PluribusCalendarUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end

-- Navigation
function PluribusCalendarUI:NextMonth()
	self.currentMonth = self.currentMonth + 1
	if self.currentMonth > 12 then
		self.currentMonth = 1
		self.currentYear = self.currentYear + 1
	end
	self:RefreshDisplay()
end

function PluribusCalendarUI:PreviousMonth()
	self.currentMonth = self.currentMonth - 1
	if self.currentMonth < 1 then
		self.currentMonth = 12
		self.currentYear = self.currentYear - 1
	end
	self:RefreshDisplay()
end

-- Real interactive event creation dialog
function PluribusCalendarUI:ShowEventCreationDialog()
	if self.createDialog then
		self.createDialog:Show()
		return
	end

	local dlg = PluribusUIFramework:CreateFrame("PluribusCalendarCreateEventDialog", UIParent, 420, 300, "Schedule Guild Event", "Pluribus Calendar")
	dlg:SetPoint("CENTER")

	local titleLbl = PluribusUIFramework:CreateLabel(dlg, "Event Title:")
	titleLbl:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -54)
	local titleBox = PluribusUIFramework:CreateInputBox(dlg, 260, 24)
	titleBox:SetPoint("TOPLEFT", dlg, "TOPLEFT", 130, -50)
	titleBox:SetText("Naxxramas Raid Night")

	local typeLbl = PluribusUIFramework:CreateLabel(dlg, "Event Type:")
	typeLbl:SetPoint("TOPLEFT", titleLbl, "BOTTOMLEFT", 0, -24)
	local typeBox = PluribusUIFramework:CreateInputBox(dlg, 260, 24)
	typeBox:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -14)
	typeBox:SetText("raid")

	local durLbl = PluribusUIFramework:CreateLabel(dlg, "Duration (min):")
	durLbl:SetPoint("TOPLEFT", typeLbl, "BOTTOMLEFT", 0, -24)
	local durBox = PluribusUIFramework:CreateInputBox(dlg, 100, 24)
	durBox:SetPoint("TOPLEFT", typeBox, "BOTTOMLEFT", 0, -14)
	durBox:SetText("180")

	local descLbl = PluribusUIFramework:CreateLabel(dlg, "Description:")
	descLbl:SetPoint("TOPLEFT", durLbl, "BOTTOMLEFT", 0, -24)
	local descBox = PluribusUIFramework:CreateInputBox(dlg, 260, 24)
	descBox:SetPoint("TOPLEFT", durBox, "BOTTOMLEFT", 0, -14)
	descBox:SetText("Bring World Buffs, Frost Protection & Flasks.")

	local saveBtn = PluribusUIFramework:CreateButton(dlg, "Create Event", 130, 28, function()
		local title = titleBox:GetText()
		if title == "" then title = "Guild Raid" end
		local minutes = tonumber(durBox:GetText()) or 180
		if PluribusCalendarCore and PluribusCalendarCore.CreateEvent then
			PluribusCalendarCore:CreateEvent({
				title = title,
				eventType = typeBox:GetText() ~= "" and typeBox:GetText() or "raid",
				startTime = time() + 3600,
				duration = minutes * 60,
				description = descBox:GetText() or "",
			})
			PluribusUIFramework:ShowNotification("Created calendar event: " .. title, 2.5)
			PluribusCalendarUI:RefreshDisplay()
		end
		dlg:Hide()
	end, true)
	saveBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 16)

	local cancelBtn = PluribusUIFramework:CreateButton(dlg, "Cancel", 86, 28, function()
		dlg:Hide()
	end)
	cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)

	self.createDialog = dlg
	dlg:Show()
end
