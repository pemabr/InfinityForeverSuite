local frames, commands, warnings, output = {}, {}, {}, {}
local secret = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:UnregisterEvent(event) self.events[event] = nil end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
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
time, date = function() return 100000 end, os.date
InfinityUtils = {
	Info = function() end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	Error = function(_, message) error(message) end,
}
InfinityCore = {
	RegisterAddon = function() end,
	RegisterSlashCommand = function(_, name, callback) commands[name] = callback end,
}
local names = { "Alpha", "Beta", "Disabled" }
local loaded = { true, true, false }
C_AddOns = {
	GetNumAddOns = function() return #names end,
	GetAddOnInfo = function(i) return names[i] end,
	IsAddOnLoaded = function(i) return loaded[i] end,
}
local memory = { Alpha = 2048, Beta = 512 }
local cpu = { Alpha = 3.5, Beta = 0.1 }
local updates = 0
UpdateAddOnMemoryUsage = function() updates = updates + 1 end
GetAddOnMemoryUsage = function(name) return memory[name] end
Enum = { AddOnProfilerMetric = { RecentAverageTime = 1 } }
C_AddOnProfiler = {
	IsEnabled = function() return true end,
	GetAddOnMetric = function(name, metric) assert(metric == 1); return cpu[name] end,
}
dofile("InfinityCore\\UI\\UIFramework.lua")
dofile("InfinityProfiler\\Core\\ProfilerCore.lua")
dofile("InfinityProfiler\\Modules\\Monitor.lua")
dofile("InfinityProfiler\\UI\\Main.lua")
dofile("InfinityProfiler\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityProfiler")
assert(commands.profiler and updates == 0)
commands.profiler("")
local ui, monitor = InfinityProfilerUI, InfinityProfilerMonitor
assert(ui.mainFrame:IsShown() and updates == 1)
assert(#monitor.current.addons == 2 and monitor.current.totalMemory == 2560)
assert(ui.mainFrame.rows[1].data.text:find("Alpha", 1, true))
assert(ui.mainFrame.rows[1].data.text:find("3.500 ms", 1, true))
assert(#monitor.current.alerts == 1 and monitor.current.alerts[1].addon == "Alpha")
local buttons = {}
for _, frame in ipairs(frames) do
	if frame.text and frame.scripts.OnClick then buttons[frame.text] = frame end
end
buttons.Alerts.scripts.OnClick(buttons.Alerts)
assert(ui.mainFrame.rows[1].data.text:find("Alpha", 1, true))
buttons.Timeline.scripts.OnClick(buttons.Timeline)
assert(ui.mainFrame.rows[1].data.text:find("2.5 MB", 1, true))
local oldRow = ui.mainFrame.rows[1]
buttons.Addons.scripts.OnClick(buttons.Addons)
assert(ui.mainFrame.rows[1] == oldRow and updates == 1)
buttons.Capture.scripts.OnClick(buttons.Capture)
assert(updates == 2 and #monitor.snapshots == 2)
buttons.Thresholds.scripts.OnClick(buttons.Thresholds)
ui.thresholdInput:SetText("4")
ui.thresholdFrame.rows[1].scripts.OnClick(ui.thresholdFrame.rows[1])
assert(monitor.thresholds.cpuWarning == 4)
ui.thresholdInput:SetText("-1")
ui.thresholdFrame.rows[2].scripts.OnClick(ui.thresholdFrame.rows[2])
assert(monitor.thresholds.memoryWarning == 10240 and warnings[#warnings]:find("positive", 1, true))
buttons.Clear.scripts.OnClick(buttons.Clear)
assert(#monitor.snapshots == 2)
buttons.Clear.scripts.OnClick(buttons.Clear)
assert(#monitor.snapshots == 0)

local originalPrint = print
print = function(message) output[#output + 1] = tostring(message) end
commands.profiler("threshold cpu 5")
commands.profiler("threshold memory 1")
commands.profiler("capture")
assert(updates == 3 and #monitor.current.alerts == 1)
assert(monitor.current.alerts[1].message:find("Memory", 1, true))
commands.profiler("addon alpha")
assert(output[#output]:find("Alpha", 1, true))
commands.profiler("threshold cpu -1")
assert(output[#output]:find("Usage", 1, true))

cpu.Beta = secret
memory.Beta = nil
loaded[3] = secret
commands.profiler("report")
assert(monitor.current.missingCPU == 1 and monitor.current.missingMemory == 1)
assert(monitor.current.unknownAddons == 1 and monitor.current.totalMemory == nil)
assert(ui.mainFrame.status.text:find("Unknown addons: 1", 1, true))
assert(ui.mainFrame.rows[2].data.text:find("unavailable", 1, true))
C_AddOnProfiler.IsEnabled = function() return false end
GetAddOnMemoryUsage = nil
commands.profiler("capture")
assert(monitor.current.missingCPU == 2 and monitor.current.missingMemory == 2)
assert(not monitor.current.cpuAvailable and not monitor.current.memoryAvailable)
local previous = monitor.current
C_AddOns.GetNumAddOns = function() error("count failed") end
commands.profiler("capture")
assert(monitor.current == previous and #warnings > 0)
commands.profiler("clear")
assert(not monitor.current and #monitor.snapshots == 0)
assert(ui.mainFrame.status.text:find("No snapshot", 1, true))
print = originalPrint
print("profiler_runtime: all tests passed")
