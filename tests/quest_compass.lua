local widgets, messages = {}, {}
local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(text) self.text = text end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name)
	if name then assert(not _G[name]) end
	local frame = setmetatable({ scripts = {}, shown = true }, meta)
	if name then _G[name] = frame end
	widgets[#widgets + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
local secret = {}
issecretvalue = function(value) return value == secret end
local player = { mapID = 12, x = 0.5, y = 0.5 }
InfinityQuestRouter = { GetPlayerPosition = function() return player end }
CreateVector2D = function(x, y) return { x = x, y = y } end
local waypoint = { uiMapID = 12, position = { x = 0.75, y = 0.5 } }
local worldSecret = false
C_Map = {
	GetUserWaypoint = function() return waypoint end,
	GetWorldPosFromMapPos = function(map, point)
		if worldSecret then return 1, { x = secret, y = 0 } end
		return map == 99 and 2 or 1, { x = 1000 - 200 * point.y, y = 1000 - 400 * point.x }
	end,
}
local originalPrint = print
print = function(message) messages[#messages + 1] = message end
dofile("InfinityCore\\UI\\UIFramework.lua")
dofile("InfinityQuestie\\Modules\\QuestNavCompassEngine.lua")
local compass = InfinityQuestCompass
local data = compass:GetCompassData()
assert(data.direction == "East" and math.abs(data.distance - 100) < 0.001)
compass:HandleCommand("")
assert(compass.frame:IsShown() and compass.frame.display.text:find("East", 1, true))
player.x = 0.6
compass.frame.scripts.OnUpdate(compass.frame, 1)
compass:HandleCommand("heading")
assert(messages[#messages]:find("decreased", 1, true))
compass:HandleCommand("set 50 25")
data = compass:GetCompassData()
assert(data.direction == "Northwest" and data.target.mapID == 12)
player.x = 0.5
data = compass:GetCompassData()
assert(data.direction == "North" and math.abs(data.distance - 50) < 0.001)
compass:HandleCommand("set 101 20")
assert(messages[#messages]:find("Usage", 1, true) and compass:GetTarget().x == 0.5)
compass:HandleCommand("set 50 25 99")
local result, problem = compass:GetCompassData()
assert(not result and problem:find("different continent", 1, true))
compass:HandleCommand("waypoint")
assert(compass:GetTarget().x == 0.75)
waypoint.position.x = secret
result, problem = compass:GetCompassData()
assert(not result and problem:find("No target", 1, true))
waypoint.position.x, worldSecret = 0.75, true
result, problem = compass:GetCompassData()
assert(not result and problem:find("World coordinates unavailable", 1, true))
worldSecret = false
player = nil
result, problem = compass:GetCompassData()
assert(not result and problem:find("Player position unavailable", 1, true))
player = { mapID = 12, x = 0.75, y = 0.5 }
data = compass:GetCompassData()
assert(data.distance == 0 and data.direction == "At target")
compass:HandleCommand("clear")
assert(compass:GetTarget() == nil and waypoint.position.x == 0.75)
assert(compass.frame.display.text:find("No target", 1, true))
compass:HandleCommand("set 20 invalid")
assert(messages[#messages]:find("Usage", 1, true))
print = originalPrint
print("quest_compass: all tests passed")
