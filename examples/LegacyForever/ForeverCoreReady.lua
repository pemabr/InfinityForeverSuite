local addon, host = ...
local readyCore, resources, loaded, started
local function initialize(...)

end
local function tryStart()
if loaded and readyCore and not started then
started = true
initialize(addon, host, readyCore, resources)
end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
if name ~= addon then return end
self:UnregisterEvent("ADDON_LOADED")
if LegacyForeverDB == nil then LegacyForeverDB = {} end
assert(type(LegacyForeverDB) == "table", "account SavedVariables must be a table")
loaded = true
tryStart()
end)
ForeverCoreLoader.OnReady(function(core, selected)
if core == nil then return end
assert(core.API == 2, "incompatible ForeverCore API")
assert(type(core.Register) == "function", "ForeverCore Register unavailable")
assert(type(core.TrackerLine) == "table", "ForeverCore TrackerLine unavailable")
if selected.mode == "legacy" then
assert(type(core.TrackerLine.SetInteractive) == "function", "unsupported legacy TrackerLine")
if core.TrackerLine.template == nil then core.TrackerLine.template = "ForeverTrackerInteractiveLineTemplate" end
end
local template = core.TrackerLine.template
assert(type(template) == "string", "ForeverCore template unavailable")
resources = { template = template, mode = selected.mode, root = selected.root }
readyCore = core
tryStart()
end)
