-- InfinityCalendar - Initialization
-- Guild event scheduling and raid calendar integration

local addonName = "InfinityCalendar"
local addonVersion = "1.0"

-- Verify InfinityCore is loaded
if not InfinityCore then
	error("InfinityCalendar requires InfinityCore")
	return
end

-- Register with InfinityCore
InfinityCore:RegisterAddon(addonName, addonVersion, {
	description = "Guild event scheduling, raid calendar, and automatic reminders",
	author = "Infinity Suite",
	category = "guild",
})

-- Load core modules
local basePath = "Interface\\AddOns\\InfinityForever\\sink\\InfinityCalendar\\"

-- Load core
dofile(basePath .. "Core\\CalendarCore.lua")

-- Load modules
dofile(basePath .. "Modules\\Notifications.lua")

-- Load UI
dofile(basePath .. "UI\\Main.lua")

-- Initialize calendar
InfinityCalendarCore:Initialize()
InfinityCalendarNotifications:Initialize()

-- Pre-populate with some example events if database is empty
local function InitializeDefaultEvents()
	if InfinityCalendarCore:CountTable(InfinityCalendarCore:GetAllEvents()) == 0 then
		-- Create weekly raid event
		local now = time()
		local nextRaid = now + (3 * 24 * 3600)  -- 3 days from now
		
		InfinityCalendarCore:CreateEvent({
			title = "Weekly Guild Raid",
			description = "Mandatory guild raid night. Come prepared with consumables.",
			type = "raid",
			startTime = nextRaid,
			duration = 10800,  -- 3 hours
			location = "Molten Core",
			leader = "GuildMaster",
			maxParticipants = 40,
		})
		
		-- Create a dungeon event
		local nextDungeon = now + (1 * 24 * 3600)  -- Tomorrow
		InfinityCalendarCore:CreateEvent({
			title = "Dungeon Run - Stratholme",
			description = "5-man dungeon run for loot and reputation.",
			type = "dungeon",
			startTime = nextDungeon,
			duration = 3600,  -- 1 hour
			location = "Stratholme",
			leader = UnitName("player"),
			maxParticipants = 5,
		})
	end
end

-- Setup reminders for all events
local function SetupReminders()
	local events = InfinityCalendarCore:GetAllEvents()
	
	for eventID, event in pairs(events) do
		if event.status == "scheduled" then
			-- Set 15 minute reminder
			InfinityCalendarCore:SetReminder(eventID, 15)
			-- Set 5 minute reminder
			InfinityCalendarCore:SetReminder(eventID, 5)
		end
	end
end

-- Slash command handler
local function HandleCalendarCommand(msg)
	msg = msg:trim():lower()
	
	if msg == "show" or msg == "ui" or msg == "open" then
		InfinityCalendarUI:Show()
		InfinityUtils:Info("Calendar opened", addonName)
	
	elseif msg == "hide" or msg == "close" then
		InfinityCalendarUI:Hide()
		InfinityUtils:Info("Calendar closed", addonName)
	
	elseif msg == "toggle" then
		InfinityCalendarUI:Toggle()
	
	elseif msg == "list" then
		local events = InfinityCalendarCore:GetUpcomingEvents(10)
		print("\n=== UPCOMING EVENTS ===")
		for _, event in ipairs(events) do
			print(InfinityCalendarCore:FormatEventDisplay(event))
		end
		if #events == 0 then
			print("No upcoming events")
		end
	
	elseif msg == "stats" then
		local stats = InfinityCalendarCore:GetStatistics()
		print("\n=== CALENDAR STATISTICS ===")
		print(string.format("Total Events: %d", stats.totalEvents))
		print(string.format("Upcoming Events: %d", stats.upcomingEvents))
		print(string.format("Completed Events: %d", stats.completedEvents))
		print(string.format("Cancelled Events: %d", stats.cancelledEvents))
		print(string.format("Average Participants: %.1f", stats.averageParticipants))
		print(string.format("Total Participants: %d", stats.totalParticipants))
	
	elseif msg:find("^create ") then
		-- Parse: create "Event Name" raid 2024-01-01 20:00 3600
		local title, eventType, date, time, duration = msg:match("^create \"(.+)\" (%w+) ([%d-]+) ([%d:]+) (%d+)$")
		if title and eventType and date and time and duration then
			local dateStr = date .. " " .. time
			local startTime = os.time()  -- Simplified - should parse dateStr properly
			
			success, eventID = InfinityCalendarCore:CreateEvent({
				title = title,
				type = eventType,
				startTime = startTime,
				duration = tonumber(duration),
				leader = UnitName("player"),
			})
			
			if success then
				InfinityUtils:Info(string.format("Event created: %s (ID: %d)", title, eventID), addonName)
			end
		else
			InfinityUtils:Error("Invalid syntax for create command", addonName)
		end
	
	elseif msg == "today" then
		local now = time()
		local dayStart = os.time({year=os.date("*t", now).year, month=os.date("*t", now).month, day=os.date("*t", now).day, hour=0, min=0})
		local dayEnd = dayStart + 86400
		
		local events = InfinityCalendarCore:GetEventsByDateRange(dayStart, dayEnd)
		print("\n=== TODAY'S EVENTS ===")
		for _, event in ipairs(events) do
			print(InfinityCalendarCore:FormatEventDisplay(event))
		end
		if #events == 0 then
			print("No events today")
		end
	
	else
		print("\n=== INFINITY CALENDAR ===")
		print("Usage:")
		print("  /infinity calendar show              - Show calendar UI")
		print("  /infinity calendar hide              - Hide calendar UI")
		print("  /infinity calendar list              - List upcoming events")
		print("  /infinity calendar stats             - Show statistics")
		print("  /infinity calendar today             - Show today's events")
		print("  /infinity calendar create <options>  - Create new event")
	end
end

-- Register slash command
InfinityCore:RegisterSlashCommand("calendar", HandleCalendarCommand, "calendar")

-- Initialize
InitializeDefaultEvents()
SetupReminders()
InfinityCalendarNotifications:Start()

InfinityUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
