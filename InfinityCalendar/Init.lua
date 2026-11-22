-- InfinityCalendar - Initialization
-- Guild event scheduling and raid calendar integration

local addonName = "InfinityCalendar"
local addonVersion = "1.0"
local initialized = false

-- Main initialization function
local function InitializeCalendar()
	-- Verify InfinityCore is loaded
	if not _G.InfinityCore or not _G.InfinityUtils then
		return  -- Will retry when INFINITY_DATA_LOADED fires
	end
	if initialized then return end

	-- Register with InfinityCore
	InfinityCore:RegisterAddon(addonName, addonVersion, {
		description = "Local event scheduling and reminders",
		author = "Infinity Suite",
		category = "guild",
	})

	-- Modules are loaded via .toc (Core\CalendarCore.lua, Modules\Notifications.lua, UI\Main.lua)
	-- Initialize calendar
	InfinityCalendarCore:Initialize()
	InfinityCalendarNotifications:Initialize()

-- Slash command handler
local function HandleCalendarCommand(msg)
	local input = InfinityUtils:Trim(msg or "")
	msg = input:lower()
	
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
		local title, eventType, eventDate, eventTime, duration = input:match("^%S+ \"(.+)\" (%w+) ([%d-]+) ([%d:]+) (%d+)$")
		if title and eventType and eventDate and eventTime and duration then
			local startTime = InfinityCalendarCore:ParseDateTime(eventDate, eventTime)
			if not startTime or tonumber(duration) <= 0 or tonumber(duration) >= math.huge then
				InfinityUtils:Error("Invalid date, time or duration", addonName)
				return
			end
			
			local success, eventID = InfinityCalendarCore:CreateEvent({
				title = title,
				type = eventType:lower(),
				startTime = startTime,
				duration = tonumber(duration),
				leader = UnitName("player"),
			})
			
			if success then
				print(string.format("Event created: %s (ID: %d)", title, eventID))
			else
				InfinityUtils:Error("Event creation failed: " .. tostring(eventID), addonName)
			end
		else
			InfinityUtils:Error("Invalid syntax for create command", addonName)
		end
	
	elseif msg == "today" then
		local now = time()
		local today = date("*t", now)
		local dayStart = time({year=today.year, month=today.month, day=today.day, hour=0, min=0})
		local dayEnd = time({year=today.year, month=today.month, day=today.day + 1, hour=0, min=0}) - 1
		
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
		print("  /calendar show|hide|list|stats|today")
		print('  /calendar create "Event Name" raid 2026-12-01 20:00 3600')
	end
end

-- Register slash command
InfinityCore:RegisterSlashCommand("calendar", HandleCalendarCommand, "calendar")

initialized = true
InfinityUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
end

-- Hook into addon loaded and InfinityCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
if event == "ADDON_LOADED" and name == addonName then
	addonLoaded = true
	-- If InfinityCore is already loaded, initialize immediately
	if _G.InfinityCore and _G.InfinityUtils then
		InitializeCalendar()
	end
elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
	-- Initialize when InfinityCore broadcasts it's ready
	InitializeCalendar()
end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
	if addonLoaded then
		InitializeCalendar()
	end
end)
end


