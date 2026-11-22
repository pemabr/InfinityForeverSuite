-- InfinityCalendar Core - Guild Event Management
-- Handles event scheduling, raid calendar integration, and reminders

InfinityCalendarCore = {
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
function InfinityCalendarCore:Initialize()
	if _G.InfinityCalendarDB == nil then _G.InfinityCalendarDB = {} end
	if type(_G.InfinityCalendarDB) ~= "table" then error("Invalid calendar database") end
	local db = _G.InfinityCalendarDB
	for _, key in ipairs({ "events", "series", "reminders", "participants" }) do
		if db[key] == nil then db[key] = {} end
		if type(db[key]) ~= "table" then error("Invalid calendar data: " .. key) end
	end
	if db.eventID ~= nil and type(db.eventID) ~= "number" then error("Invalid calendar event ID") end
	self.db = db
	self.events, self.series = db.events, db.series
	self.reminders, self.participants = db.reminders, db.participants
	self.eventID = db.eventID or 0
	for id in pairs(self.events) do
		if type(id) == "number" and id > self.eventID then self.eventID = id end
	end
	db.eventID = self.eventID
	InfinityUtils:Info("Calendar initialized", "Calendar")
end

function InfinityCalendarCore:ParseDateTime(dateText, timeText)
	if type(dateText) ~= "string" or type(timeText) ~= "string" then return nil end
	local y, m, d = dateText:match("^(%d%d%d%d)-(%d%d?)-(%d%d?)$")
	local hr, mn = timeText:match("^(%d%d?):(%d%d)$")
	y, m, d, hr, mn = tonumber(y), tonumber(m), tonumber(d), tonumber(hr), tonumber(mn)
	if not y or not m or not d or not hr or not mn or m < 1 or m > 12
		or d < 1 or d > 31 or hr > 23 or mn > 59 then return nil end
	local ok, timestamp = pcall(time, { year = y, month = m, day = d, hour = hr, min = mn, sec = 0 })
	if not ok or type(timestamp) ~= "number" or timestamp <= 0 then return nil end
	local parsed = date("*t", timestamp)
	if not parsed or parsed.year ~= y or parsed.month ~= m or parsed.day ~= d
		or parsed.hour ~= hr or parsed.min ~= mn then return nil end
	return timestamp
end

-- Create a new event
function InfinityCalendarCore:CreateEvent(eventData)
	if type(eventData) ~= "table" or type(eventData.title) ~= "string" or eventData.title == ""
		or type(eventData.startTime) ~= "number" or eventData.startTime ~= eventData.startTime
		or eventData.startTime <= 0 or eventData.startTime >= math.huge
		or (eventData.duration ~= nil and (type(eventData.duration) ~= "number"
			or eventData.duration ~= eventData.duration or eventData.duration <= 0 or eventData.duration >= math.huge)) then
		return false, "Missing required fields"
	end
	
	self.eventID = self.eventID + 1
	self.db.eventID = self.eventID
	
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
	self:SetReminder(event.id, 15)
	self:SetReminder(event.id, 5)
	
	InfinityUtils:Info(string.format("Event created: %s", event.title), "Calendar")
	return true, event.id
end

-- Update event
function InfinityCalendarCore:UpdateEvent(eventID, updates)
	if not self.events[eventID] or type(updates) ~= "table" then
		return false, "Event not found"
	end
	if (updates.title ~= nil and (type(updates.title) ~= "string" or updates.title == ""))
		or (updates.startTime ~= nil and (type(updates.startTime) ~= "number" or updates.startTime ~= updates.startTime
			or updates.startTime <= 0 or updates.startTime >= math.huge))
		or (updates.duration ~= nil and (type(updates.duration) ~= "number" or updates.duration ~= updates.duration
			or updates.duration <= 0 or updates.duration >= math.huge)) then
		return false, "Invalid event time"
	end
	
	local event = self.events[eventID]
	
	for key, value in pairs(updates) do
		if key ~= "id" and key ~= "createdAt" then
			event[key] = value
		end
	end

	event.updatedAt = time()
	
	for _, reminder in pairs(self.reminders) do
		if reminder.eventID == eventID then
			reminder.eventTitle = event.title
			if updates.startTime then
				reminder.triggerTime = event.startTime - reminder.minutesBefore * 60
				reminder.triggered = false
			end
		end
	end
	return true
end

-- Delete event
function InfinityCalendarCore:DeleteEvent(eventID)
	if not self.events[eventID] then
		return false
	end
	
	local event = self.events[eventID]
	
	if event.seriesID and self.series[event.seriesID] then
		self.series[event.seriesID] = nil
	end
	
	self.events[eventID] = nil
	for key, reminder in pairs(self.reminders) do
		if reminder.eventID == eventID then self.reminders[key] = nil end
	end
	
	InfinityUtils:Info(string.format("Event deleted: %s", event.title), "Calendar")
	return true
end

-- Get event details
function InfinityCalendarCore:GetEvent(eventID)
	return self.events[eventID]
end

-- Get all events
function InfinityCalendarCore:GetAllEvents()
	return self.events
end

-- Get events in date range
function InfinityCalendarCore:GetEventsByDateRange(startTime, endTime)
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
function InfinityCalendarCore:GetEventsByType(eventType)
	local result = {}
	
	for eventID, event in pairs(self.events) do
		if event.type == eventType then
			table.insert(result, event)
		end
	end
	
	return result
end

-- Get upcoming events
function InfinityCalendarCore:GetUpcomingEvents(count)
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
function InfinityCalendarCore:AddParticipant(eventID, characterName, status)
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
function InfinityCalendarCore:UpdateParticipantStatus(eventID, characterName, status)
	if not self.events[eventID] or not self.events[eventID].participants[characterName] then
		return false
	end
	
	self.events[eventID].participants[characterName].status = status
	self.events[eventID].updatedAt = time()
	
	return true
end

-- Remove participant
function InfinityCalendarCore:RemoveParticipant(eventID, characterName)
	if not self.events[eventID] or not self.events[eventID].participants[characterName] then
		return false
	end
	
	self.events[eventID].participants[characterName] = nil
	self.events[eventID].updatedAt = time()
	
	return true
end

-- Get participant list
function InfinityCalendarCore:GetParticipants(eventID)
	if not self.events[eventID] then
		return {}
	end
	
	return self.events[eventID].participants
end

-- Get participant count
function InfinityCalendarCore:GetParticipantCount(eventID)
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
function InfinityCalendarCore:SetReminder(eventID, minutesBefore)
	if not self.events[eventID] or type(minutesBefore) ~= "number" or minutesBefore <= 0 then
		return false
	end
	
	local event = self.events[eventID]
	
	self.reminders[tostring(eventID) .. ":" .. tostring(minutesBefore)] = {
		eventID = eventID,
		eventTitle = event.title,
		triggerTime = event.startTime - (minutesBefore * 60),
		minutesBefore = minutesBefore,
		triggered = false,
	}
	
	return true
end

-- Get active reminders
function InfinityCalendarCore:GetActiveReminders()
	local now = time()
	local active = {}
	
	for _, reminder in pairs(self.reminders) do
		local event = self.events[reminder.eventID]
		if event and event.status == "scheduled" and event.startTime > now
			and not reminder.triggered and reminder.triggerTime <= now then
			table.insert(active, reminder)
		end
	end
	
	return active
end

-- Mark reminder as triggered
function InfinityCalendarCore:MarkReminderTriggered(eventID, minutesBefore)
	local reminder = self.reminders[tostring(eventID) .. ":" .. tostring(minutesBefore)]
	if reminder then
		reminder.triggered = true
	end
end

-- Check if player is event leader
function InfinityCalendarCore:IsEventLeader(eventID)
	local event = self.events[eventID]
	if not event then
		return false
	end
	
	return event.leader == UnitName("player")
end

-- Get attendance rate
function InfinityCalendarCore:GetAttendanceRate(characterName)
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
function InfinityCalendarCore:GetStatistics()
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
function InfinityCalendarCore:FormatEventDisplay(event)
	local startDate = date("%Y-%m-%d %H:%M", event.startTime)
	local endTime = event.startTime + event.duration
	local endDate = date("%H:%M", endTime)
	
	return string.format("%s - %s [%s] (%s participants)",
		startDate, endDate, event.title, 
		self:CountTable(event.participants))
end

-- Helper function
function InfinityCalendarCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

return InfinityCalendarCore
