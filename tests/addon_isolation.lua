local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:RegisterEvent(event) self.events[event] = true end
function widget:UnregisterEvent(event) self.events[event] = nil end
function widget:CreateFontString() return CreateFrame("FontString") end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ scripts = {}, events = {}, shown = true }, meta)
	if name then _G[name] = frame end
	return frame
end
UIParent = CreateFrame("Frame")
InfinityUtils = { Info = function() end }
INFINITY_EVENTS = { DATA_CHANGED = "changed" }
local subscriptions = 0
InfinityMessaging = { Subscribe = function() subscriptions = subscriptions + 1 end }

local function Run(lootFirst)
	_G.InfinityDKPUI, _G.InfinityLootDKPUI = nil, nil
	_G.InfinityDKPMainFrame, _G.InfinityDKPMainWindow = nil, nil
	subscriptions = 0
	if lootFirst then
		dofile("InfinityLoot\\Modules\\DKPDisplayUI.lua")
		dofile("InfinityDKP\\UI\\Main.lua")
	else
		dofile("InfinityDKP\\UI\\Main.lua")
		dofile("InfinityLoot\\Modules\\DKPDisplayUI.lua")
	end
	local dkp, loot = InfinityDKPUI, InfinityLootDKPUI
	assert(dkp ~= loot and dkp.Toggle and not dkp.ToggleWindow and loot.ToggleWindow and not loot.Toggle)
	dkp:Initialize()
	loot:Initialize()
	loot:Initialize()
	dkp:Initialize()
	assert(dkp.frame ~= loot.mainWindow and subscriptions == 1)
	dkp:Show()
	assert(dkp.frame:IsShown() and not loot.mainWindow:IsShown())
	loot.SelectTab = function() end
	loot:ToggleWindow()
	assert(dkp.frame:IsShown() and loot.mainWindow:IsShown())
end

Run(true)
Run(false)

dofile("InfinityAttendance\\Modules\\Tracker.lua")
local attendance = InfinityAttendanceTracker
dofile("InfinityDKP\\Core\\AttendanceTracker.lua")
assert(InfinityAttendanceTracker == attendance)
assert(InfinityDKPAttendanceTracker ~= attendance)
assert(InfinityDKPAttendanceTracker.GetAttendanceStats and attendance.GetPlayerRaids)
dofile("InfinityAttendance\\Modules\\Tracker.lua")
assert(InfinityDKPAttendanceTracker.GetAttendanceStats and InfinityAttendanceTracker.GetPlayerRaids)
time = os.time
SlashCmdList = {}
dofile("InfinityCore\\PerformanceOptimizer.lua")
local coreOptimizer = InfinityPerformanceOptimizer
local frames = {}
local createFrame = CreateFrame
CreateFrame = function(...)
	local frame = createFrame(...)
	frames[#frames + 1] = frame
	return frame
end
dofile("InfinityLoot\\Modules\\PerformanceOptimizer.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityLoot")
assert(InfinityPerformanceOptimizer == coreOptimizer)
assert(InfinityLootPerformanceOptimizer ~= coreOptimizer and InfinityLootPerformanceOptimizer.GetReport)
dofile("InfinityCore\\Modules\\DataCollector.lua")
local coreCollector = InfinityCoreDataCollector
assert(InfinityDataCollector == coreCollector)
dofile("InfinityDataCollector\\Modules\\DataCollector.lua")
assert(InfinityCoreDataCollector == coreCollector)
assert(InfinityDataCollectorLegacy ~= coreCollector and InfinityDataCollectorLegacy.CollectQuestData)
_G.InfinityDataCollector = { RecordQuestData = function() end }
assert(InfinityCoreDataCollector == coreCollector and InfinityDataCollectorLegacy.CollectQuestData)
print("addon_isolation: all tests passed")
