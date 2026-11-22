-- InfinityCalendar - Initialization
-- Guild event scheduling and raid calendar integration

local addonName = "InfinityCalendar"
local addonVersion = "1.0"

-- Main initialization function
local function InitializeCalendar()
	-- Verify InfinityCore is loaded
	if not _G.InfinityCore or not _G.InfinityUtils then
		return  -- Will retry when INFINITY_DATA_LOADED fires
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
	if InfinityCalendarCore then pcall(function() InfinityCalendarCore:Initialize() end) end
	if InfinityCalendarNotifications then pcall(function() InfinityCalendarNotifications:Initialize() end) end

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
			local startTime = time()  -- Simplified - should parse dateStr properly
			
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
		local dayStart = time({year=date("*t", now).year, month=date("*t", now).month, day=date("*t", now).day, hour=0, min=0})
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
end


-- Register with InfinityAddonManager if available
local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage guild events and raids",
			author = "Infinity Suite Team",
			category = "Guild",
			enabled = true,
			settings = {}
		})
	end
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


