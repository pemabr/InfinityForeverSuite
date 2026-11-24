-- PluribusCalendar Core - Guild Event Management
-- Handles event scheduling, raid calendar integration, and reminders

PluribusCalendarCore = {
	events = {},
	series = {},
	reminders = {},
	participants = {},
	eventID = 0,
	db = {},
	version = 1,
}

-- Event structure:
-- {
--   id = number,
--   title = string,
--   description = string,
--   type = "raid" | "dungeon" | "pvp" | "social" | "other",
--   startTime = timestamp,
--   duration = seconds,
--   location = string,
--   leader = character name,
--   maxParticipants = number,
--   participants = { [character] = status },
--   seriesID = optional series id,
--   recurrence = optional recurrence rule,
--   status = "scheduled" | "in_progress" | "completed" | "cancelled",
--   createdAt = timestamp,
--   updatedAt = timestamp,
-- }

-- Initialize calendar
function PluribusCalendarCore:Initialize()
	self.events = {}
	self.series = {}
	self.reminders = {}
	self.participants = {}
	self.eventID = 0
	PluribusUtils:Info("Calendar initialized", "Calendar")
end

-- Create a new event
function PluribusCalendarCore:CreateEvent(eventData)
	if not eventData or not eventData.title or not eventData.startTime then
		return false, "Missing required fields"
	end
	
	self.eventID = self.eventID + 1
	
	local event = {
		id = self.eventID,
		title = eventData.title,
		description = eventData.description or "",
		type = eventData.type or "other",
		startTime = eventData.startTime,
		duration = eventData.duration or 3600,
		location = eventData.location or "Unknown",
		leader = eventData.leader or UnitName("player"),
		maxParticipants = eventData.maxParticipants or 0,
		participants = {},
		recurrence = eventData.recurrence or nil,
		status = "scheduled",
		createdAt = time(),
		updatedAt = time(),
	}
	
	-- If recurrence, create a series
	if event.recurrence then
		local seriesID = "series_" .. self.eventID
		event.seriesID = seriesID
		self.series[seriesID] = {
			id = seriesID,
			baseEvent = event.id,
			recurrence = event.recurrence,
			endDate = eventData.seriesEndDate or nil,
			instances = {},
		}
	end
	
	self.events[event.id] = event
	
	PluribusUtils:Info(string.format("Event created: %s", event.title), "Calendar")
	return true, event.id
end

-- Update event
function PluribusCalendarCore:UpdateEvent(eventID, updates)
	if not self.events[eventID] then
		return false, "Event not found"
	end
	
	local event = self.events[eventID]
	
	for key, value in pairs(updates) do
		if key ~= "id" and key ~= "createdAt" then
			event[key] = value
		end
	end
	
	event.updatedAt = time()
	
	if PluribusMessaging and PluribusMessaging.Publish then
		PluribusMessaging:Publish("PLURIBUS_CALENDAR_EVENT_UPDATED", event)
	end
	return true
end

-- Delete event
function PluribusCalendarCore:DeleteEvent(eventID)
	if not self.events[eventID] then
		return false
	end
	
	local event = self.events[eventID]
	
	if event.seriesID and self.series[event.seriesID] then
		self.series[event.seriesID] = nil
	end
	
	self.events[eventID] = nil
	
	PluribusUtils:Info(string.format("Event deleted: %s", event.title), "Calendar")
	return true
end

-- Get event details
function PluribusCalendarCore:GetEvent(eventID)
	return self.events[eventID]
end

-- Get all events
function PluribusCalendarCore:GetAllEvents()
	return self.events
end

-- Get events in date range
function PluribusCalendarCore:GetEventsByDateRange(startTime, endTime)
	local result = {}
	
	for eventID, event in pairs(self.events) do
		if event.startTime >= startTime and event.startTime <= endTime then
			table.insert(result, event)
		end
	end
	
	table.sort(result, function(a, b)
		return a.startTime < b.startTime
	end)
	
	return result
end

-- Get events by type
function PluribusCalendarCore:GetEventsByType(eventType)
	local result = {}
	
	for eventID, event in pairs(self.events) do
		if event.type == eventType then
			table.insert(result, event)
		end
	end
	
	return result
end

-- Get upcoming events
function PluribusCalendarCore:GetUpcomingEvents(count)
	count = count or 10
	local now = time()
	local result = {}
	
	for eventID, event in pairs(self.events) do
		if event.startTime > now and event.status ~= "cancelled" then
			table.insert(result, event)
		end
	end
	
	table.sort(result, function(a, b)
		return a.startTime < b.startTime
	end)
	
	local limited = {}
	for i = 1, math.min(count, #result) do
		table.insert(limited, result[i])
	end
	
	return limited
end

-- Add participant to event
function PluribusCalendarCore:AddParticipant(eventID, characterName, status)
	if not self.events[eventID] then
		return false
	end
	
	status = status or "tentative"
	
	self.events[eventID].participants[characterName] = {
		name = characterName,
		status = status,
		joinedAt = time(),
	}
	
	return true
end

-- Update participant status
function PluribusCalendarCore:UpdateParticipantStatus(eventID, characterName, status)
	if not self.events[eventID] or not self.events[eventID].participants[characterName] then
		return false
	end
	
	self.events[eventID].participants[characterName].status = status
	self.events[eventID].updatedAt = time()
	
	return true
end

-- Remove participant
function PluribusCalendarCore:RemoveParticipant(eventID, characterName)
	if not self.events[eventID] or not self.events[eventID].participants[characterName] then
		return false
	end
	
	self.events[eventID].participants[characterName] = nil
	self.events[eventID].updatedAt = time()
	
	return true
end

-- Get participant list
function PluribusCalendarCore:GetParticipants(eventID)
	if not self.events[eventID] then
		return {}
	end
	
	return self.events[eventID].participants
end

-- Get participant count
function PluribusCalendarCore:GetParticipantCount(eventID)
	if not self.events[eventID] then
		return 0
	end
	
	local confirmed = 0
	local tentative = 0
	local declined = 0
	
	for characterName, participant in pairs(self.events[eventID].participants) do
		if participant.status == "confirmed" then
			confirmed = confirmed + 1
		elseif participant.status == "tentative" then
			tentative = tentative + 1
		elseif participant.status == "declined" then
			declined = declined + 1
		end
	end
	
	return {
		total = confirmed + tentative + declined,
		confirmed = confirmed,
		tentative = tentative,
		declined = declined,
	}
end

-- Set reminder
function PluribusCalendarCore:SetReminder(eventID, minutesBefore)
	if not self.events[eventID] then
		return false
	end
	
	local event = self.events[eventID]
	
	self.reminders[eventID] = {
		eventID = eventID,
		eventTitle = event.title,
		triggerTime = event.startTime - (minutesBefore * 60),
		minutesBefore = minutesBefore,
		triggered = false,
	}
	
	return true
end

-- Get active reminders
function PluribusCalendarCore:GetActiveReminders()
	local now = time()
	local active = {}
	
	for eventID, reminder in pairs(self.reminders) do
		if not reminder.triggered and reminder.triggerTime <= now then
			table.insert(active, reminder)
		end
	end
	
	return active
end

-- Mark reminder as triggered
function PluribusCalendarCore:MarkReminderTriggered(eventID)
	if self.reminders[eventID] then
		self.reminders[eventID].triggered = true
	end
end

-- Check if player is event leader
function PluribusCalendarCore:IsEventLeader(eventID)
	local event = self.events[eventID]
	if not event then
		return false
	end
	
	return event.leader == UnitName("player")
end

-- Get attendance rate
function PluribusCalendarCore:GetAttendanceRate(characterName)
	local attended = 0
	local total = 0
	
	for eventID, event in pairs(self.events) do
		if event.status == "completed" and event.participants[characterName] then
			total = total + 1
			if event.participants[characterName].status == "confirmed" then
				attended = attended + 1
			end
		end
	end
	
	if total == 0 then
		return 0
	end
	
	return (attended / total) * 100
end

-- Get statistics
function PluribusCalendarCore:GetStatistics()
	local stats = {
		totalEvents = 0,
		upcomingEvents = 0,
		completedEvents = 0,
		cancelledEvents = 0,
		averageParticipants = 0,
		totalParticipants = 0,
	}
	
	local now = time()
	local totalParticipants = 0
	
	for eventID, event in pairs(self.events) do
		stats.totalEvents = stats.totalEvents + 1
		
		if event.status == "scheduled" or event.status == "in_progress" then
			if event.startTime > now then
				stats.upcomingEvents = stats.upcomingEvents + 1
			end
		elseif event.status == "completed" then
			stats.completedEvents = stats.completedEvents + 1
		elseif event.status == "cancelled" then
			stats.cancelledEvents = stats.cancelledEvents + 1
		end
		
		local participantCount = 0
		for _ in pairs(event.participants) do
			participantCount = participantCount + 1
		end
		totalParticipants = totalParticipants + participantCount
	end
	
	if stats.totalEvents > 0 then
		stats.averageParticipants = totalParticipants / stats.totalEvents
	end
	
	stats.totalParticipants = totalParticipants
	
	return stats
end

-- Format event for display
function PluribusCalendarCore:FormatEventDisplay(event)
	local startDate = date("%Y-%m-%d %H:%M", event.startTime)
	local endTime = event.startTime + event.duration
	local endDate = date("%H:%M", endTime)
	
	return string.format("%s - %s [%s] (%s participants)",
		startDate, endDate, event.title, 
		self:CountTable(event.participants))
end

-- Helper function
function PluribusCalendarCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Helper to inform guild of changes
function InformGuildOfChanges(event)
	-- This will be implemented by the messaging module
end
