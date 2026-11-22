local frames, commands, db, warnings, messages = {}, {}, {}, {}, {}
local now, secret = 1800000000, {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
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
time = function() return now end
issecretvalue = function(value) return value == secret end
SendChatMessage = function() error("Unexpected guild message") end
InfinityUtils = { Warning = function(_, message) warnings[#warnings + 1] = message end }
InfinityCore = {
	GetDatabase = function(_, name) assert(name == "InfinityWorldBoss"); return db end,
	RegisterAddon = function() end,
}
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) commands[name] = callback end }
local originalPrint = print
print = function(message) messages[#messages + 1] = message end
dofile("InfinityCore\\UI\\UIFramework.lua")
for line in io.lines("InfinityWorldBoss\\InfinityWorldBoss.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityWorldBoss\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityWorldBoss")
local core = InfinityWorldBossCore
assert(commands.worldboss and #core:GetAllBosses() == 0)
commands.worldboss({"register", "42", "60", "Example", "Dragon"})
assert(db.bosses[42].name == "Example Dragon" and db.bosses[42].interval == 60)
commands.worldboss({"register", "42", "5", "Duplicate"})
assert(db.bosses[42].name == "Example Dragon")
commands.worldboss({"register", "invalid", "60", "Invalid"})
assert(messages[#messages]:find("Usage", 1, true))
commands.worldboss({})
assert(InfinityWorldBossUI.frame:IsShown())
assert(InfinityWorldBossUI.frame.rows[1].data.text:find("status unknown", 1, true))
local encounter
for _, frame in ipairs(frames) do if frame.events.ENCOUNTER_END then encounter = frame end end
assert(encounter)
local shared, guildReport = {}, { killed = now + 100000 }
InfinityGuildBossReports = {
	ObserveKill = function(_, id, name, timestamp) shared[#shared + 1] = { id, name, timestamp } end,
	GetReport = function(_, id) if id == 42 then return guildReport end end,
}
encounter.scripts.OnEvent(encounter, "ENCOUNTER_END", 42, "Example Dragon", 1, 10, 0)
assert(db.bosses[42].lastKilled == nil)
encounter.scripts.OnEvent(encounter, "ENCOUNTER_END", secret, "Example Dragon", 1, 10, 1)
encounter.scripts.OnEvent(encounter, "ENCOUNTER_END", 42, "Example Dragon", 1, 10, secret)
encounter.scripts.OnEvent(encounter, "ENCOUNTER_END", 99, "Other", 1, 10, 1)
assert(db.bosses[42].lastKilled == nil and db.bosses[99] == nil and #shared == 0)
encounter.scripts.OnEvent(encounter, "ENCOUNTER_END", 42, "Example Dragon", 1, 10, 1)
assert(db.bosses[42].lastKilled == now and db.bosses[42].notified == false)
assert(#shared == 1 and shared[1][1] == 42 and shared[1][3] == now)
assert(InfinityWorldBossUI.frame.rows[1].data.text:find("Estimated", 1, true))
assert(InfinityWorldBossUI.frame.rows[1].data.text:find("Guild report", 1, true))
now = now + 60
InfinityWorldBossTimers:Update()
assert(db.bosses[42].notified and messages[#messages]:find("Actual spawn status is unknown", 1, true))
local count = #messages
InfinityWorldBossTimers:Update()
assert(#messages == count)
dofile("InfinityWorldBoss\\Core\\WorldBossCore.lua")
InfinityWorldBossCore:Initialize()
assert(InfinityWorldBossCore.bosses[42].notified and InfinityWorldBossCore.bosses[42].lastKilled == now - 60)
commands.worldboss({"kill", "42"})
assert(db.bosses[42].lastKilled == now and not db.bosses[42].notified and #shared == 1)
commands.worldboss({"interval", "42", "120"})
assert(db.bosses[42].interval == 120 and db.bosses[42].lastKilled == now)
commands.worldboss({"interval", "42", "invalid"})
assert(db.bosses[42].interval == 120 and messages[#messages]:find("positive", 1, true))
commands.worldboss({"forgetkill", "42"})
assert(db.bosses[42].lastKilled == nil and db.bosses[42].notified == nil)
commands.worldboss({"remove", "42"})
assert(db.bosses[42] == nil)
local ui = InfinityWorldBossUI
ui.idInput:SetText("51")
ui.intervalInput:SetText("120")
ui.nameInput:SetText("GUI Boss")
ui.addButton.scripts.OnClick()
assert(db.bosses[51] and db.bosses[51].name == "GUI Boss")
ui.intervalInput:SetText("300")
ui.intervalButton.scripts.OnClick()
assert(db.bosses[51].interval == 300)
ui.frame.rows[1].scripts.OnClick(ui.frame.rows[1])
assert(db.bosses[51].lastKilled == now)
ui.clearButton.scripts.OnClick()
assert(db.bosses[51].lastKilled == now)
ui.clearButton.scripts.OnClick()
assert(db.bosses[51].lastKilled == nil)
ui.removeButton.scripts.OnClick()
assert(db.bosses[51])
ui.removeButton.scripts.OnClick()
assert(not db.bosses[51])
ui.idInput:SetText(secret)
ui.addButton.scripts.OnClick()
assert(warnings[#warnings]:find("Invalid encounter ID", 1, true))
print = originalPrint
print("worldboss_runtime: all tests passed")
