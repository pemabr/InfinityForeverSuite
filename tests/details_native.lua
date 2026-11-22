local widgets, commands, registrations, notices = {}, {}, 0, {}
local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:RegisterEvent(event) self.events[event] = true end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(value) self.text = value end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ scripts = {}, events = {}, parent = parent, shown = true, total = false, rate = false }, meta)
	if name then _G[name] = frame end
	widgets[#widgets + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
BackdropTemplateMixin = {}
SlashCmdList = {}
local secretName, secretAmount, secretGuid = {}, {}, {}
local formattedSecret = {}
issecretvalue = function(value) return value == secretName or value == secretAmount or value == secretGuid end
AbbreviateNumbers = function(value) assert(value == secretAmount); return formattedSecret end
Enum = {
	DamageMeterType = { DamageDone = 10, HealingDone = 20, Absorbs = 21, Interrupts = 22, Dispels = 23 },
	DamageMeterSessionType = { Overall = 30, Current = 40 },
}
local damage = {
	combatSources = {
		{ name = "Alice", sourceGUID = "player-1", totalAmount = 1000, amountPerSecond = 100 },
		{ name = secretName, sourceGUID = secretGuid, totalAmount = secretAmount, amountPerSecond = secretAmount },
	},
}
local healing = { combatSources = { { name = "Bob", sourceGUID = "player-2", totalAmount = 600, amountPerSecond = 60 } } }
local details = { combatSpells = { { spellID = 123, totalAmount = 500, amountPerSecond = 50 } } }
local lastSession, lastMetric, lastGuid
C_DamageMeter = {
	GetCombatSessionFromType = function(session, metric)
		lastSession, lastMetric = session, metric
		return metric == 10 and damage or healing
	end,
	GetCombatSessionSourceFromType = function(session, metric, guid)
		assert(session == 40 and metric == 10)
		lastGuid = guid
		return details
	end,
}
C_Spell = { GetSpellName = function(id) assert(id == 123); return "Fireball" end }
InfinityCore = { RegisterAddon = function() registrations = registrations + 1 end }
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) commands[name] = callback end }
InfinityMessaging = { Subscribe = function(_, _, callback) InfinityMessaging.callback = callback end }
local realPrint = print
print = function(message) notices[#notices + 1] = message end
dofile("InfinityCore\\UI\\UIFramework.lua")
for line in io.lines("InfinityDetails\\InfinityDetails.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityDetails\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = widgets[#widgets]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityDetails")
InfinityMessaging.callback()
assert(registrations == 1 and commands.details)
commands.details({})
local ui = InfinityDetailsUI
assert(ui.frame:IsShown() and lastSession == 40 and lastMetric == 10)
assert(ui.frame.rows[1].label.text == "Alice" and ui.frame.rows[1].total.text == "1000")
assert(ui.frame.rows[2].label.text == secretName and ui.frame.rows[2].total.text == formattedSecret)
assert(ui.frame.rows[2].data.onClick == nil)
AbbreviateNumbers = nil
ui:Update()
assert(ui.frame.rows[2].total.text == "Protected")
assert(ui:BuildReport("damage"):find("unavailable", 1, true))
commands.details({"hps"})
assert(notices[#notices]:find("Bob | 600 | 60", 1, true))
for _, element in ipairs(widgets) do
	if element.parent == ui.frame and element.text == "Report" then element.scripts.OnClick() end
end
assert(ui.reportFrame:IsShown() and ui.reportText.text:find("unavailable", 1, true)
	and ui.reportText.text:find("Bob | 600 | 60", 1, true))
ui.frame.rows[1].scripts.OnClick(ui.frame.rows[1])
assert(lastGuid == "player-1" and ui.frame.rows[1].label.text == "Fireball")
assert(ui.frame.rows[1].total.text == "500")
details = {}
ui:Update()
assert(ui.frame.status.text:find("unavailable", 1, true) and not ui.frame.rows[1]:IsShown())
ui.selected, ui.metric, ui.session = nil, "healing", "overall"
ui:Update()
assert(lastSession == 30 and lastMetric == 20 and ui.frame.rows[1].label.text == "Bob")
commands.details({"absorbs"})
assert(lastMetric == 21 and ui.frame:IsShown())
commands.details({"taken"})
assert(ui.frame.status.text:find("unavailable", 1, true) and not ui.frame.rows[1]:IsShown())
commands.details({"interrupts"})
assert(lastMetric == 22)
commands.details({"dispels"})
assert(lastMetric == 23)
C_DamageMeter.GetCombatSessionFromType = function() return nil end
ui.metric = "healing"
ui:Update()
assert(ui.frame.status.text:find("No overall session", 1, true) and not ui.frame.rows[1]:IsShown())
C_DamageMeter = nil
ui.session = "current"
InfinityDetailsMeters = {
	GetHPSMeter = function() return { { name = "Legacy", healing = 20, hps = 2 } } end,
	GetDPSMeter = function() return {} end,
}
ui:Update()
assert(ui.frame.rows[1].label.text == "Legacy" and ui.frame.rows[1].rate.text == "2")
assert(ui.frame.status.text:find("Spell breakdown unavailable", 1, true))
ui.session = "overall"
ui:Update()
assert(ui.frame.status.text:find("unavailable", 1, true) and not ui.frame.rows[1]:IsShown())
print = realPrint
print("details_native: all tests passed")
