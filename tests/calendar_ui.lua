local frames, errors = {}, {}
local now = os.time({ year = 2026, month = 12, day = 1, hour = 12, min = 0, sec = 0 })
local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
function widget:GetChildren() return unpack(self.children) end
function widget:GetRegions() return unpack(self.regions) end
function widget:CreateFontString()
	local region = setmetatable({ scripts = {}, children = {}, regions = {}, shown = true }, getmetatable(self))
	self.regions[#self.regions + 1] = region
	return region
end
local meta = { __index = function(_, key)
	if key == "eventID" or key == "confirming" then return nil end
	return widget[key] or function() end
end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ scripts = {}, children = {}, regions = {}, shown = true, parent = parent }, meta)
	if name then _G[name] = frame end
	if parent then parent.children[#parent.children + 1] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
time = function(value) return value and os.time(value) or now end
date = os.date
UnitName = function() return "Alice" end
GetRealZoneText = function() return "Local zone" end
InfinityUtils = {
	Info = function() end,
	Error = function(_, message) errors[#errors + 1] = message end,
	ClearContainer = function(_, container)
		for _, child in ipairs(container.children) do child:Hide() end
		for _, region in ipairs(container.regions) do region:Hide() end
	end,
}

dofile("InfinityCalendar\\Core\\CalendarCore.lua")
dofile("InfinityCalendar\\UI\\Main.lua")
InfinityCalendarCore:Initialize()
InfinityCalendarUI:Toggle()
assert(InfinityCalendarUI.mainFrame:IsShown())
InfinityCalendarUI:ShowEventCreationDialog()
local fields = InfinityCalendarUI.createInputs
fields.title:SetText("Raid")
fields.date:SetText("2026-02-31")
fields.clock:SetText("20:00")
fields.save.scripts.OnClick(fields.save)
assert(#errors == 1 and next(InfinityCalendarCore.events) == nil)
fields.date:SetText("2026-12-03")
fields.clock:SetText("00:30")
fields.duration:SetText("invalid")
fields.save.scripts.OnClick(fields.save)
assert(#errors == 2 and next(InfinityCalendarCore.events) == nil)
fields.duration:SetText("90")
fields.save.scripts.OnClick(fields.save)
assert(InfinityCalendarCore.events[1].title == "Raid")
assert(InfinityCalendarCore.events[1].duration == 5400)
local ok = InfinityCalendarCore:CreateEvent({
	title = "Midnight", startTime = InfinityCalendarCore:ParseDateTime("2026-12-04", "00:00"),
})
assert(ok)
InfinityCalendarUI:RefreshDisplay()
local dayCounts = {}
for _, region in ipairs(InfinityCalendarUI.contentArea.regions) do
	if region.shown and region.text and region.text:find("event", 1, true) then dayCounts[#dayCounts + 1] = region.text end
end
assert(#dayCounts == 2 and dayCounts[1] == "1 event" and dayCounts[2] == "1 event")
local regionCount, frameCount = #InfinityCalendarUI.contentArea.regions, #frames
InfinityCalendarUI:RefreshDisplay()
assert(#InfinityCalendarUI.contentArea.regions == regionCount and #frames == frameCount)

InfinityCalendarUI.modeBtn.scripts.OnClick(InfinityCalendarUI.modeBtn)
local function visibleButton(text)
	for _, frame in ipairs(frames) do
		if frame.parent == InfinityCalendarUI.contentArea and frame.shown and frame.text == text then return frame end
	end
end
local row = visibleButton(InfinityCalendarCore:FormatEventDisplay(InfinityCalendarCore.events[1]))
assert(row)
row.scripts.OnClick(row)
assert(InfinityCalendarUI.selectedEvent.id == 1 and InfinityCalendarUI.displayMode == "event")
local edit = visibleButton("Edit")
assert(edit)
edit.scripts.OnClick(edit)
assert(fields.title:GetText() == "Raid" and fields.duration:GetText() == "90")
fields.title:SetText("Updated raid")
fields.date:SetText("2026-12-05")
fields.save.scripts.OnClick(fields.save)
assert(InfinityCalendarCore.events[1].title == "Updated raid")
assert(InfinityCalendarDB.reminders["1:15"].eventTitle == "Updated raid")
assert(InfinityCalendarDB.reminders["1:15"].triggerTime == InfinityCalendarCore.events[1].startTime - 900)
local delete = visibleButton("Delete")
assert(delete)
delete.scripts.OnClick(delete)
assert(InfinityCalendarCore.events[1] and delete.text == "Confirm delete")
delete.scripts.OnClick(delete)
assert(not InfinityCalendarCore.events[1] and not InfinityCalendarDB.reminders["1:15"])
assert(InfinityCalendarCore.events[2] and InfinityCalendarUI.displayMode == "list")
InfinityCalendarUI:Toggle()
assert(not InfinityCalendarUI.mainFrame:IsShown())
print("calendar_ui: all tests passed")
