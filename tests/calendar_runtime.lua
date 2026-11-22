local frames, commands, errors = {}, {}, {}
local now, guildMessages = 1000, 0
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame()
	local frame = setmetatable({ events = {}, scripts = {} }, meta)
	frames[#frames + 1] = frame
	return frame
end
time = function(value) return value and os.time(value) or now end
date = os.date
UnitName = function() return "Alice" end
InfinityUtils = {
	Info = function() end,
	Error = function(_, message) errors[#errors + 1] = message end,
	Trim = function(_, value) return value:match("^%s*(.-)%s*$") end,
}
InfinityCore = {
	RegisterAddon = function() end,
	RegisterSlashCommand = function(_, name, callback) commands[name] = callback end,
}
local subscription
InfinityMessaging = { Subscribe = function(_, _, callback) subscription = callback end }
InfinityCalendarUI = { Show = function() end, Hide = function() end, Toggle = function() end }
SendChatMessage = function() guildMessages = guildMessages + 1 end

dofile("InfinityCalendar\\Core\\CalendarCore.lua")
dofile("InfinityCalendar\\Modules\\Notifications.lua")
dofile("InfinityCalendar\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityCalendar")
assert(next(InfinityCalendarCore:GetAllEvents()) == nil)
InfinityCalendarNotifications.notificationChannels = { chat = false, sound = false, screen = false }
local ok, id = InfinityCalendarCore:CreateEvent({ title = "Real raid", type = "raid", startTime = 2000, duration = 600 })
assert(ok and id == 1 and InfinityCalendarDB.events[id].title == "Real raid")
assert(InfinityCalendarDB.reminders["1:15"] and InfinityCalendarDB.reminders["1:5"])
subscription()
assert(InfinityCalendarCore:GetEvent(id).title == "Real raid")

now = 1100
assert(#InfinityCalendarCore:GetActiveReminders() == 1)
InfinityCalendarNotifications:CheckReminders()
assert(InfinityCalendarDB.reminders["1:15"].triggered)
assert(not InfinityCalendarDB.reminders["1:5"].triggered)
dofile("InfinityCalendar\\Core\\CalendarCore.lua")
InfinityCalendarCore:Initialize()
assert(InfinityCalendarCore:GetEvent(id).title == "Real raid")
assert(#InfinityCalendarCore:GetActiveReminders() == 0)
now = 1700
assert(#InfinityCalendarCore:GetActiveReminders() == 1)
InfinityCalendarNotifications:CheckReminders()
assert(InfinityCalendarDB.reminders["1:5"].triggered)
now = 2001
InfinityCalendarNotifications:CheckEventStatus()
assert(InfinityCalendarCore:GetEvent(id).status == "in_progress")
now = 2601
InfinityCalendarNotifications:CheckEventStatus()
assert(InfinityCalendarCore:GetEvent(id).status == "completed")
assert(guildMessages == 0)
assert(InfinityCalendarCore:DeleteEvent(id))
assert(next(InfinityCalendarDB.reminders) == nil)
local added, nextID = InfinityCalendarCore:CreateEvent({ title = "Next", startTime = 4000 })
assert(added and nextID == 2)
assert(not InfinityCalendarCore:CreateEvent({ title = "Bad", startTime = "tomorrow" }))
assert(not InfinityCalendarCore:UpdateEvent(nextID, { duration = -1 }))
local errorsBefore = #errors
commands.calendar('create "Case Preserved" raid 2026-02-31 20:00 3600')
assert(#errors == errorsBefore + 1 and InfinityCalendarCore.eventID == 2)
commands.calendar('CREATE "Case Preserved" Raid 2026-12-01 20:00 3600')
assert(InfinityCalendarCore:GetEvent(3).title == "Case Preserved")
assert(InfinityCalendarCore:GetEvent(3).type == "raid")
assert(guildMessages == 0)
print("calendar_runtime: all tests passed")
