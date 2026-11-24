-- PluribusCalendar - Initialization
-- Guild event scheduling and raid calendar integration

local addonName = "PluribusCalendar"
local addonVersion = "1.0"

-- Main initialization function
local function InitializeCalendar()
	-- Verify PluribusCore is loaded
	if not _G.PluribusCore or not _G.PluribusUtils then
		return  -- Will retry when PLURIBUS_DATA_LOADED fires
	end

	-- Register with PluribusCore
	PluribusCore:RegisterAddon(addonName, addonVersion, {
		description = "Guild event scheduling, raid calendar, and automatic reminders",
		author = "Pluribus Suite",
		category = "guild",
	})

	-- Core, modules, and UI are already loaded by PluribusCalendar.toc
	if PluribusCalendarCore and PluribusCalendarCore.Initialize then
		pcall(function() PluribusCalendarCore:Initialize() end)
	end
	if PluribusCalendarNotifications and PluribusCalendarNotifications.Initialize then
		pcall(function() PluribusCalendarNotifications:Initialize() end)
	end

-- Pre-populate with some example events if database is empty
local function InitializeDefaultEvents()
	if PluribusCalendarCore:CountTable(PluribusCalendarCore:GetAllEvents()) == 0 then
		-- Create weekly raid event
		local now = time()
		local nextRaid = now + (3 * 24 * 3600)  -- 3 days from now
		
		PluribusCalendarCore:CreateEvent({
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
		PluribusCalendarCore:CreateEvent({
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
	local events = PluribusCalendarCore:GetAllEvents()
	
	for eventID, event in pairs(events) do
		if event.status == "scheduled" then
			-- Set 15 minute reminder
			PluribusCalendarCore:SetReminder(eventID, 15)
			-- Set 5 minute reminder
			PluribusCalendarCore:SetReminder(eventID, 5)
		end
	end
end

-- Slash command handler
local function HandleCalendarCommand(msg)
	if type(msg) == "table" then
		msg = table.concat(msg, " ")
	end
	msg = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()
	
	if msg == "" or msg == "show" or msg == "ui" or msg == "open" then
		if PluribusCalendarUI and PluribusCalendarUI.Show then
			PluribusCalendarUI:Show()
		end
		PluribusUtils:Info("Calendar opened", addonName)
	
	elseif msg == "hide" or msg == "close" then
		PluribusCalendarUI:Hide()
		PluribusUtils:Info("Calendar closed", addonName)
	
	elseif msg == "toggle" then
		PluribusCalendarUI:Toggle()
	
	elseif msg == "list" then
		local events = PluribusCalendarCore:GetUpcomingEvents(10)
		print("\n=== UPCOMING EVENTS ===")
		for _, event in ipairs(events) do
			print(PluribusCalendarCore:FormatEventDisplay(event))
		end
		if #events == 0 then
			print("No upcoming events")
		end
	
	elseif msg == "stats" then
		local stats = PluribusCalendarCore:GetStatistics()
		print("\n=== CALENDAR STATISTICS ===")
		print(string.format("Total Events: %d", stats.totalEvents))
		print(string.format("Upcoming Events: %d", stats.upcomingEvents))
		print(string.format("Completed Events: %d", stats.completedEvents))
		print(string.format("Cancelled Events: %d", stats.cancelledEvents))
		print(string.format("Average Participants: %.1f", stats.averageParticipants))
		print(string.format("Total Participants: %d", stats.totalParticipants))
	
	elseif msg:find("^create ") then
		-- Parse: create "Event Name" raid 2024-01-01 20:00 3600
		local title, eventType, datePart, timePart, duration = msg:match("^create \"(.+)\" (%w+) ([%d-]+) ([%d:]+) (%d+)$")
		if title and eventType and datePart and timePart and duration then
			local startTime = time()
			local success, eventID = PluribusCalendarCore:CreateEvent({
				title = title,
				type = eventType,
				startTime = startTime,
				duration = tonumber(duration),
				leader = UnitName("player"),
			})
			
			if success then
				PluribusUtils:Info(string.format("Event created: %s (ID: %d)", title, eventID), addonName)
			end
		else
			PluribusUtils:Error("Invalid syntax for create command", addonName)
		end
	
	elseif msg == "today" then
		local now = time()
		local dayStart = time({year=date("*t", now).year, month=date("*t", now).month, day=date("*t", now).day, hour=0, min=0})
		local dayEnd = dayStart + 86400
		
		local events = PluribusCalendarCore:GetEventsByDateRange(dayStart, dayEnd)
		print("\n=== TODAY'S EVENTS ===")
		for _, event in ipairs(events) do
			print(PluribusCalendarCore:FormatEventDisplay(event))
		end
		if #events == 0 then
			print("No events today")
		end
	
	else
		print("\n=== PLURIBUS CALENDAR ===")
		print("Usage:")
		print("  /pluribus calendar show              - Show calendar UI")
		print("  /pluribus calendar hide              - Hide calendar UI")
		print("  /pluribus calendar list              - List upcoming events")
		print("  /pluribus calendar stats             - Show statistics")
		print("  /pluribus calendar today             - Show today's events")
		print("  /pluribus calendar create <options>  - Create new event")
	end
end

-- Register slash command
if PluribusCore and PluribusCore.RegisterSlashCommand then
	PluribusCore:RegisterSlashCommand("calendar", HandleCalendarCommand, "calendar")
elseif PluribusCommandRegistry and PluribusCommandRegistry.RegisterCommand then
	PluribusCommandRegistry:RegisterCommand("calendar", function(args, raw)
		HandleCalendarCommand(raw or "")
	end, { "cal" })
end

-- Initialize
if PluribusCalendarCore then
	pcall(InitializeDefaultEvents)
	pcall(SetupReminders)
end
if PluribusCalendarNotifications and PluribusCalendarNotifications.Start then
	pcall(function() PluribusCalendarNotifications:Start() end)
end

PluribusUtils:Info(string.format("Loaded %s v%s", addonName, addonVersion), addonName)
end


-- Register with PluribusAddonManager if available
local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage guild events and raids",
			author = "Pluribus Suite Team",
			category = "Guild",
			enabled = true,
			settings = {}
		})
	end
end
-- Hook into addon loaded and PluribusCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
if event == "ADDON_LOADED" and name == addonName then
	addonLoaded = true
	-- If PluribusCore is already loaded, initialize immediately
	if _G.PluribusCore and _G.PluribusUtils then
		InitializeCalendar()
	end
elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
	-- Initialize when PluribusCore broadcasts it's ready
	InitializeCalendar()
end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
	if addonLoaded then
		InitializeCalendar()
	end
end)
end


