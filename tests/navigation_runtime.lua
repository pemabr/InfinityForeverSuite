local frames, commands, db, warnings, messages = {}, {}, {}, {}, {}
local secret, combat, mapAllowed, mapResult = {}, false, true, true
local selected, tracked, playerX, playerY = nil, false, 0.4, 0.7
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return rawget(self, "text") or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
C_Map = {
	GetBestMapForUnit = function() return 12 end,
	GetPlayerMapPosition = function() return { x = playerX, y = playerY } end,
	CanSetUserWaypointOnMap = function() return mapAllowed end,
	SetUserWaypoint = function(point) selected = point; return mapResult end,
}
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { mapID = map, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value) tracked = value end }
C_QuestLog = { GetNextWaypoint = function(id)
	if id == 10 then return 13, 0.3, 0.8 end
	if id == 11 then return 13, secret, 0.8 end
end }
InfinityCore = {
	GetDatabase = function(_, name) assert(name == "InfinityNavigation"); return db end,
	RegisterAddon = function() end,
}
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) commands[name] = callback end }
local originalPrint = print
print = function(message) messages[#messages + 1] = message end
dofile("InfinityCore\\Core\\Utilities.lua")
InfinityUtils.Info = function() end
InfinityUtils.Warning = function(_, message) warnings[#warnings + 1] = message end
dofile("InfinityCore\\UI\\UIFramework.lua")
for line in io.lines("InfinityNavigation\\InfinityNavigation.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityNavigation\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityNavigation")
assert(commands.nav and #db.waypoints == 0)
commands.nav({})
local ui = InfinityWayPointUI
assert(ui.frame:IsShown() and ui.frame.rows[1].data.text == "No saved waypoints.")
commands.nav({ "add", "12", "30", "70", "Town", "gate" })
assert(#db.waypoints == 1 and db.waypoints[1].description == "Town gate")
assert(ui.frame.rows[1].data.text:find("Town gate", 1, true))
ui.frame.rows[1].scripts.OnClick(ui.frame.rows[1])
assert(selected.mapID == 12 and selected.x == 0.3 and selected.y == 0.7 and tracked)
commands.nav({ "here", "My", "position" })
assert(#db.waypoints == 2 and db.waypoints[2].x == 0.4 and db.waypoints[2].description == "My position")
commands.nav({ "add", "12", "101", "70", "Bad" })
commands.nav({ "add", "bad", "20", "70", "Bad" })
assert(#db.waypoints == 2)
playerX = secret
commands.nav({ "here", "Hidden" })
assert(#db.waypoints == 2 and warnings[#warnings]:find("unavailable", 1, true))
playerX, playerY = 0, 0
commands.nav({ "here" })
assert(#db.waypoints == 2)
selected = nil
commands.nav({ "quest", "10" })
assert(selected.mapID == 13 and selected.x == 0.3 and selected.y == 0.8)
selected = nil
commands.nav({ "quest", "11" })
assert(not selected and warnings[#warnings]:find("No public", 1, true))
combat = true
commands.nav({ "quest", "10" })
assert(not selected and warnings[#warnings]:find("combat", 1, true))
combat, mapAllowed = false, false
commands.nav({ "quest", "10" })
assert(not selected and warnings[#warnings]:find("unavailable", 1, true))
mapAllowed, mapResult = secret, true
commands.nav({ "quest", "10" })
assert(not selected)
mapAllowed, mapResult = true, false
commands.nav({ "quest", "10" })
assert(warnings[#warnings]:find("Could not set", 1, true))
commands.nav({ "remove", "1" })
assert(#db.waypoints == 1 and db.waypoints[1].description == "My position")
InfinityNavigator:Initialize()
assert(#InfinityNavigator.waypoints == 1 and InfinityNavigator.waypoints[1].description == "My position")
commands.nav({ "clear" })
assert(#db.waypoints == 0 and ui.frame.rows[1].data.text == "No saved waypoints.")
ui:ShowEditor()
ui.editorID:SetText("12")
ui.editorX:SetText("25")
ui.editorY:SetText("75")
ui.editorName:SetText("GUI waypoint")
ui.editor.rows[2].scripts.OnClick(ui.editor.rows[2])
assert(#db.waypoints == 1 and db.waypoints[1].description == "GUI waypoint")
ui.editorID:SetText("10")
mapResult = true
ui.editor.rows[3].scripts.OnClick(ui.editor.rows[3])
assert(selected.mapID == 13)
ui.editorID:SetText("1")
ui.editor.rows[4].scripts.OnClick(ui.editor.rows[4])
assert(#db.waypoints == 1)
ui.editor.rows[4].scripts.OnClick(ui.editor.rows[4])
assert(#db.waypoints == 0)
ui.editor.rows[2].scripts.OnClick(ui.editor.rows[2])
ui.editor.rows[5].scripts.OnClick(ui.editor.rows[5])
assert(#db.waypoints == 1)
InfinityNavigator:AddWaypoint(0.1, 0.1, 12, "Changed")
ui.editor.rows[5].scripts.OnClick(ui.editor.rows[5])
assert(#db.waypoints == 2)
ui.editor.rows[5].scripts.OnClick(ui.editor.rows[5])
assert(#db.waypoints == 0)
print = originalPrint
print("navigation_runtime: all tests passed")
