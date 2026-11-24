-- PluribusCalendar Notifications Module
-- Handles reminders and automatic guild announcements

PluribusCalendarNotifications = {
	reminderFrame = nil,
	updateInterval = 10,
	lastUpdate = 0,
	notificationChannels = {
		chat = true,
		screen = true,
		sound = true,
	},
}

-- Initialize notifications
function PluribusCalendarNotifications:Initialize()
	if self.reminderFrame then
		return
	end
	
	self.reminderFrame = CreateFrame("Frame")
	self.reminderFrame:SetScript("OnUpdate", function(self, elapsed)
		PluribusCalendarNotifications:OnUpdate(elapsed)
	end)
	
	PluribusUtils:Info("Calendar notifications initialized", "Calendar")
end

-- Main update loop
function PluribusCalendarNotifications:OnUpdate(elapsed)
	self.lastUpdate = self.lastUpdate + elapsed
	
	if self.lastUpdate >= self.updateInterval then
		self:CheckReminders()
		self:CheckEventStatus()
		self.lastUpdate = 0
	end
end

-- Check for active reminders
function PluribusCalendarNotifications:CheckReminders()
	local reminders = PluribusCalendarCore:GetActiveReminders()
	
	for _, reminder in ipairs(reminders) do
		self:NotifyReminder(reminder)
		PluribusCalendarCore:MarkReminderTriggered(reminder.eventID)
	end
end

-- Notify about upcoming event
function PluribusCalendarNotifications:NotifyReminder(reminder)
	local message = string.format("Event starting in %d minutes: %s", 
		reminder.minutesBefore, reminder.eventTitle)
	
	if self.notificationChannels.chat then
		print("|cff00ff00[Calendar]|r " .. message)
	end
	
	if self.notificationChannels.sound then
		PlaySoundFile("Sound\\Interface\\RaidWarning.wav", "Master")
	end
	
	if self.notificationChannels.screen then
		UIErrorsFrame:AddMessage(message, 0, 1, 0, 1, UIERRORS_HOLD_TIME)
	end
	
	-- Announce to guild if raid event
	local event = PluribusCalendarCore:GetEvent(reminder.eventID)
	if event and event.type == "raid" and PluribusCalendarCore:IsEventLeader(reminder.eventID) then
		local announce = string.format("Guild Event in %d minutes: %s - %s",
			reminder.minutesBefore, event.title, event.location)
		SendChatMessage(announce, "GUILD")
	end
end

-- Check event status changes
function PluribusCalendarNotifications:CheckEventStatus()
	local now = time()
	local events = PluribusCalendarCore:GetAllEvents()
	
	for eventID, event in pairs(events) do
		if event.status == "scheduled" then
			-- Check if event should start
			if now >= event.startTime then
				PluribusCalendarCore:UpdateEvent(eventID, {status = "in_progress"})
				self:NotifyEventStarted(event)
			end
		elseif event.status == "in_progress" then
			-- Check if event should end
			if now >= event.startTime + event.duration then
				PluribusCalendarCore:UpdateEvent(eventID, {status = "completed"})
				self:NotifyEventEnded(event)
			end
		end
	end
end

-- Notify event started
function PluribusCalendarNotifications:NotifyEventStarted(event)
	local message = string.format("Event started: %s", event.title)
	
	if self.notificationChannels.chat then
		print("|cff00ff00[Calendar]|r " .. message)
	end
	
	if self.notificationChannels.sound then
		PlaySoundFile("Sound\\Interface\\Doodad\\Bell\\BellTollNeutral.wav", "Master")
	end
	
	-- Guild announcement
	if event.type == "raid" then
		SendChatMessage(event.title .. " is now in progress!", "GUILD")
	end
end

-- Notify event ended
function PluribusCalendarNotifications:NotifyEventEnded(event)
	local message = string.format("Event ended: %s", event.title)
	
	if self.notificationChannels.chat then
		print("|cff00ff00[Calendar]|r " .. message)
	end
	
	-- Send summary
	if event.type == "raid" then
		local participants = PluribusCalendarCore:GetParticipantCount(event.id)
		local summary = string.format("Event Complete: %s (%d participants, %d confirmed)",
			event.title, participants.total, participants.confirmed)
		SendChatMessage(summary, "GUILD")
	end
end

-- Set notification channels
function PluribusCalendarNotifications:SetChannel(channel, enabled)
	if self.notificationChannels[channel] ~= nil then
		self.notificationChannels[channel] = not not enabled
		return true
	end
	return false
end

-- Send manual announcement
function PluribusCalendarNotifications:SendAnnouncement(eventID, message)
	local event = PluribusCalendarCore:GetEvent(eventID)
	if not event then
		return false
	end
	
	local fullMessage = string.format("[%s] %s", event.title, message)
	SendChatMessage(fullMessage, "GUILD")
	
	return true
end

-- Send reminder to participants
function PluribusCalendarNotifications:RemindParticipants(eventID)
	local event = PluribusCalendarCore:GetEvent(eventID)
	if not event then
		return false
	end
	
	local message = string.format("Reminder: Event '%s' at %s", 
		event.title, date("%H:%M", event.startTime))
	
	-- Send to each confirmed participant
	for characterName, participant in pairs(event.participants) do
		if participant.status == "confirmed" then
			PluribusMessaging:SendDirectMessage(characterName, message)
		end
	end
	
	return true
end
