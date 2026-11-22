local frames, commands, subscriptions, warnings, db = {}, {}, {}, {}, {}
local now, remaining, sounds, state = 100, 15, 0, 0
local secret = {}
local health, maxHealth = 50, 100
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
function widget:SetShown(value) self.shown = value end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
StaticPopupDialogs = {}
local popup
StaticPopup_Show = function(name) popup = name; return true end
IsLoggedIn = function() return false end
InfinityCore = {
	RegisterAddon = function() end,
	RegisterCommand = function(_, name, _, callback) commands[name] = callback end,
	GetDatabase = function(_, name) assert(name == "InfinityEncounter"); return db end,
}
InfinityMessaging = { Subscribe = function(_, event, callback) subscriptions[event] = callback end }
InfinityUtils = {
	CanUseCombatLogEvent = function() return false end,
	IsRaidBoss = function(_, unit) return unit == "boss1" end,
	GetSpellNameByID = function(_, id) return "Spell " .. id end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
}
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
UnitExists = function(unit) return unit == "boss1" end
UnitName = function() return "Boss" end
UnitHealth = function() return health end
UnitHealthMax = function() return maxHealth end
UnitAffectingCombat = function() return false end
PlaySound = function(id) assert(id == 1); sounds = sounds + 1 end
SOUNDKIT = { RAID_WARNING = 1 }
C_EncounterTimeline = {
	HasActiveEvents = function() return true end,
	GetEventList = function() return { 7 } end,
	GetEventInfo = function() return { spellName = "Fire" } end,
	GetEventTimeRemaining = function() return remaining end,
	GetEventState = function() return state end,
}

dofile("InfinityEncounter\\Core\\Timer.lua")
dofile("InfinityEncounter\\Core\\CombatDetection.lua")
dofile("InfinityEncounter\\Core\\EncounterData.lua")
dofile("InfinityEncounter\\Modules\\Encounters.lua")
dofile("InfinityEncounter\\Modules\\Abilities.lua")
dofile("InfinityEncounter\\Modules\\Alerts.lua")
dofile("InfinityEncounter\\Modules\\StatusBars.lua")
dofile("InfinityEncounter\\Modules\\DBMBridge.lua")
dofile("InfinityEncounter\\Modules\\Presets.lua")
dofile("InfinityEncounter\\UI\\Main.lua")
dofile("InfinityEncounter\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityEncounter")
local events
for _, frame in ipairs(frames) do
	if frame.events.ENCOUNTER_START and frame.events.ENCOUNTER_END then events = frame end
end
assert(events and not events.events.COMBAT_LOG_EVENT_UNFILTERED)
local frameCount = #frames
subscriptions.INFINITY_DATA_LOADED()
assert(#frames == frameCount)
local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end

fire("ENCOUNTER_START", 1, "Boss")
assert(InfinityEncounterAlerts.frame:IsShown() and InfinityEncounterAlerts.frame.text.text == "Encounter: Boss")
assert(InfinityEncounterTimer:GetTimer("et_7"):GetRemaining() == 15)
fire("ENCOUNTER_TIMELINE_EVENT_ADDED", 7)
assert(InfinityEncounterTimer:GetTimerCount() == 1)
state, remaining = 1, 10
fire("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 7)
now = 120
InfinityEncounterTimer:Update()
assert(InfinityEncounterTimer:GetTimer("et_7"):GetRemaining() == 10)
state, remaining = 0, 10
fire("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 7)
now = 122
InfinityEncounterTimer:Update()
assert(sounds == 0)
now = 126
InfinityEncounterTimer:Update()
assert(InfinityEncounterAlerts.frame.text.text:find("Fire", 1, true) and sounds == 1)
remaining = 4
fire("ENCOUNTER_TIMELINE_EVENT_ADDED", 7)
InfinityEncounterTimer:Update()
assert(sounds == 1)
state = 3
fire("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 7)
assert(InfinityEncounterTimer:GetTimerCount() == 0)
state = 0
fire("ENCOUNTER_TIMELINE_EVENT_ADDED", 7)
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", 42)
local ability = InfinityEncounterAbilities:GetAbility(42)
assert(ability and ability.next_cast == nil and InfinityEncounterAbilities:GetAbilityStatus(42) == "unknown")
assert(#InfinityEncounterAbilities:GetUpcomingAbilities() == 0)
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", secret)
assert(#InfinityEncounterAbilities.ability_history == 1)

commands["/encounter"]()
health, maxHealth = secret, secret
InfinityEncounterUI:Update()
assert(InfinityEncounterUI.status_text.text:find("Health: unavailable", 1, true))
InfinityEncounterTimer:CreateTimer("later", "Later", 40)
InfinityEncounterTimer:CreateTimer("gamma", "Gamma", 3)
InfinityEncounterTimer:CreateTimer("alpha", "Alpha", 1)
InfinityEncounterTimer:CreateTimer("beta", "Beta", 2)
InfinityEncounterUI:Update()
local display = InfinityEncounterUI.timer_text.text
assert(display:find("Alpha", 1, true) < display:find("Beta", 1, true))
assert(display:find("Beta", 1, true) < display:find("Gamma", 1, true))
assert(not display:find("Later", 1, true) and not display:find("Fire", 1, true))
for _, id in ipairs({ "later", "gamma", "alpha", "beta" }) do InfinityEncounterTimer:RemoveTimer(id) end
now = 131
InfinityEncounterTimer:Update()
assert(not InfinityEncounterTimer:GetTimer("et_7") and InfinityEncounterTimer:GetTimerCount() == 0)
remaining = 4
fire("ENCOUNTER_TIMELINE_EVENT_ADDED", 7)
assert(InfinityEncounterTimer:GetTimerCount() == 1)
InfinityEncounterTimer:Update()
assert(sounds == 2)
fire("ENCOUNTER_END", 1, "Boss", 1, 10, 0)
assert(InfinityEncounterMgr:GetEncounterStats().wipes == 1 and InfinityEncounterTimer:GetTimerCount() == 0)
fire("ENCOUNTER_START", 2, secret)
assert(InfinityEncounterMgr.active_encounters[1].name == "Boss")
fire("ENCOUNTER_END", 2, "Boss", 1, 10, secret)
assert(InfinityEncounterMgr:GetEncounterStats().wipes == 1)
fire("ENCOUNTER_START", 3, "Boss")
fire("ENCOUNTER_END", 3, "Boss", 1, 10, 1)
local stats = InfinityEncounterMgr:GetEncounterStats()
assert(stats.pulls == 3 and stats.wipes == 1 and stats.victories == 1)
commands["/encounter test"]()
assert(sounds == 4 and InfinityEncounterAlerts.frame:IsShown())
now = 141
InfinityEncounterAlerts.frame.scripts.OnUpdate()
assert(not InfinityEncounterAlerts.frame:IsShown())
local fired = {}
InfinityCore.FireEvent = function(_, event, name) fired[#fired + 1] = event .. ":" .. name end
now = 200
InfinityEncounterTimer:CreateTimer("crossing", "Crossing", 15)
InfinityEncounterTimer:Update()
now = 207
InfinityEncounterTimer:Update()
assert(fired[1] == "timer_warning:Crossing")
now = 212
InfinityEncounterTimer:Update()
assert(fired[2] == "timer_warning:Crossing" and #fired == 2)
local messages, oldPrint = {}, print
print = function(message) messages[#messages + 1] = tostring(message) end
now = 300
commands["/encounter timer"]("10 Big Burst")
local manual = InfinityEncounterTimer:GetTimer("manual:big burst")
assert(manual and manual:GetRemaining() == 10 and InfinityEncounterUI.frame:IsShown())
assert(InfinityEncounterUI.timer_text.text:find("Big Burst", 1, true))
now = 306
InfinityEncounterTimer:Update()
assert(InfinityEncounterAlerts.frame.text.text:find("Big Burst", 1, true))
assert(InfinityEncounterTimer:GetTimer("manual:big burst"))
now = 310
InfinityEncounterTimer:Update()
assert(not InfinityEncounterTimer:GetTimer("manual:big burst"))
assert(InfinityEncounterAlerts.frame.text.text == "Big Burst NOW!")
commands["/encounter timer"]("12 Big Burst")
commands["/encounter timer"]("20 BIG BURST")
assert(InfinityEncounterTimer:GetTimer("manual:big burst"):GetRemaining() == 20)
commands["/encounter timer stop"]("big burst")
assert(not InfinityEncounterTimer:GetTimer("manual:big burst"))
commands["/encounter timer stop"]("missing")
assert(messages[#messages]:find("not found", 1, true))
commands["/encounter timer"]("0 invalid")
assert(messages[#messages]:find("Usage:", 1, true))
commands["/encounter timer"]("86401 invalid")
assert(messages[#messages]:find("Usage:", 1, true))
commands["/encounter timer"]("12 " .. string.rep("a", 81))
assert(messages[#messages]:find("Usage:", 1, true))
local beforeWarnings = #warnings
InfinityEncounterTimer:CreateTimer("broken", "Broken", 1, function() error("timer callback error") end)
now = 312
InfinityEncounterTimer:Update()
assert(#warnings == beforeWarnings + 1 and warnings[#warnings]:find("timer callback error", 1, true))

C_Map = {
	GetBestMapForUnit = function() return 11 end,
	GetMapInfo = function(id) assert(id == 11); return { parentMapID = 10 } end,
}
EJ_GetInstanceForMap = function(id) return id == 10 and 55 or 0 end
EJ_SelectInstance = function() error("journal selection must not be changed") end
EJ_GetEncounterInfoByIndex = function(index, instance)
	assert(instance == 55)
	if index == 1 then return "First boss", "Summary", 101, 10, nil, 55, 900 end
	if index == 2 then return "Second boss", "Summary", 102, 20, nil, 55, 901 end
end
EJ_GetEncounterInfo = function(id)
	if id == 101 then return "First boss", "Native overview", nil, 10 end
end
local sections = {
	[10] = { title = "Overview", description = "Overview detail", firstChildSectionID = 11, siblingSectionID = 12 },
	[11] = { title = "Important cast", spellID = 42, description = "Interrupt this cast", siblingSectionID = 10 },
	[12] = { title = "Heroic mechanic", filteredByDifficulty = true, description = "Avoid this" },
}
C_EncounterJournal = { GetSectionInfo = function(id) return sections[id] end }
commands["/encounter journal"]("")
assert(InfinityEncounterUI.journalFrame:IsShown())
assert(InfinityEncounterUI.journalText.text:find("101 - First boss", 1, true))
assert(InfinityEncounterUI.journalText.text:find("102 - Second boss", 1, true))
commands["/encounter journal"]("101")
local journal = InfinityEncounterUI.journalText.text
assert(journal:find("Native overview", 1, true) and journal:find("Interrupt this cast", 1, true))
assert(journal:find("Spell ID 42", 1, true))
assert(journal:find("Important cast", 1, true) < journal:find("Heroic mechanic", 1, true))
assert(journal:find("other difficulty", 1, true))
commands["/encounter journal"]("900")
assert(warnings[#warnings]:find("not found", 1, true))
commands["/encounter journal"]("invalid")
assert(messages[#messages]:find("Usage:", 1, true))
local selected = false
EJ_GetEncounterInfoByIndex = function(index, instance)
	if not selected then return nil end
	if index == 1 then assert(instance == 55); return "Initialized boss", nil, 103 end
end
EJ_SelectInstance = function(instance) assert(instance == 55); selected = true end
InCombatLockdown = function() return true end
commands["/encounter journal"]("")
assert(not selected and warnings[#warnings]:find("outside combat", 1, true))
InCombatLockdown = function() return false end
commands["/encounter journal"]("")
assert(selected and InfinityEncounterUI.journalText.text:find("103 - Initialized boss", 1, true))
EJ_GetInstanceForMap = function() return secret end
C_Map.GetMapInfo = function() return { parentMapID = secret } end
commands["/encounter journal"]("")
assert(warnings[#warnings]:find("No Encounter Journal instance", 1, true))
EJ_GetEncounterInfo = function() error("journal API unavailable") end
commands["/encounter journal"]("101")
assert(warnings[#warnings]:find("journal API unavailable", 1, true))
commands["/encounter watch add"]("42 Interrupt")
assert(db.watchedSpells[42] == "Interrupt")
commands["/encounter preset"]("create Boss")
assert(db.watchPresets.preset_1 and db.watchPresets.preset_1.steps[1].questID == 42)
commands["/encounter preset"]("use none")
assert(not db.watchedSpells[42])
commands["/encounter preset"]("use preset_1")
assert(db.watchedSpells[42] == "Interrupt")
commands["/encounter preset"]("send preset_1")
assert(warnings[#warnings]:find("requires InfinityGuide", 1, true))
local lateHandler
InfinityGuideGuildPresets = {
	RegisterType = function(_, kind, handler) assert(kind == "E"); lateHandler = handler; return true end,
}
InfinityEncounterPresets.frame.scripts.OnEvent(InfinityEncounterPresets.frame, "ADDON_LOADED", "InfinityGuide")
assert(lateHandler and lateHandler("Late", { { questID = 43, description = "Dodge" } }))
assert(db.watchPresets.preset_2 and db.watchedSpells[42] and not db.watchedSpells[43])
InfinityGuideGuildPresets = nil
commands["/encounter preset"]("list")
assert(messages[#messages - 1]:find("preset_1 - Boss", 1, true))
assert(InfinityEncounterAbilities:InitializeWatches(db) and InfinityEncounterAbilities.watchedSpells[42] == "Interrupt")
local watchSounds = sounds
fire("UNIT_SPELLCAST_START", "boss1", "cast", 42)
assert(sounds == watchSounds + 1 and InfinityEncounterAlerts.frame.text.text == "Casting: Interrupt")
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", 42)
assert(sounds == watchSounds + 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", 42)
assert(sounds == watchSounds + 2 and InfinityEncounterAlerts.frame.text.text == "Cast: Interrupt")
fire("UNIT_SPELLCAST_START", "boss1", "cast", 42)
fire("UNIT_SPELLCAST_INTERRUPTED", "boss1", "cast", secret)
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", 42)
assert(sounds == watchSounds + 4)
fire("UNIT_SPELLCAST_START", "player", "cast", 42)
fire("UNIT_SPELLCAST_START", "boss1", "cast", secret)
assert(sounds == watchSounds + 4)
local bossCheck = InfinityUtils.IsRaidBoss
InfinityUtils.IsRaidBoss = function() return false end
fire("UNIT_SPELLCAST_START", "boss1", "cast", 42)
assert(sounds == watchSounds + 5)
InfinityUtils.IsRaidBoss = bossCheck
commands["/encounter watch"]("")
assert(messages[#messages]:find("42 - Interrupt", 1, true))
commands["/encounter watch remove"]("42")
assert(db.watchedSpells[42] == nil)
fire("UNIT_SPELLCAST_SUCCEEDED", "boss1", "cast", 42)
assert(sounds == watchSounds + 5)
commands["/encounter watch add"]("0")
assert(warnings[#warnings]:find("Invalid spell ID", 1, true))
local callbacks = {}
local registrations = 0
DBM = {
	RegisterCallback = function(_, event, callback)
		registrations = registrations + 1
		if registrations == 3 then error("registration failure") end
		assert(not callbacks[event]); callbacks[event] = callback
	end,
	UnregisterCallback = function(_, event, callback) assert(callbacks[event] == callback); callbacks[event] = nil end,
}
local bridge = InfinityEncounterDBMBridge
bridge.frame.scripts.OnEvent(bridge.frame, "PLAYER_LOGIN")
assert(popup == "INFINITY_ENCOUNTER_DBM" and db.dbmEnabled == nil)
assert(not bridge:SetEnabled(true) and not next(callbacks) and not bridge.provider and not db.dbmEnabled)
StaticPopupDialogs.INFINITY_ENCOUNTER_DBM.OnAccept()
assert(db.dbmEnabled and callbacks.DBM_TimerBegin)
callbacks.DBM_TimerBegin("DBM_TimerBegin", "fire", "Fire", 10)
assert(InfinityEncounterTimer:GetTimer("dbm:fire").name == "[DBM] Fire")
callbacks.DBM_TimerBegin("DBM_TimerBegin", "disabled", "Disabled", 10,
	nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, nil)
assert(not InfinityEncounterTimer:GetTimer("dbm:disabled"))
callbacks.DBM_TimerBegin("DBM_TimerBegin", "text", "Text", 10,
	nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, true)
assert(InfinityEncounterTimer:GetTimer("dbm:text"))
callbacks.DBM_TimerStop("DBM_TimerStop", "text")
callbacks.DBM_TimerBegin("DBM_TimerBegin", secret, "Hidden", 10)
callbacks.DBM_TimerBegin("DBM_TimerBegin", "hidden", secret, 10)
assert(not InfinityEncounterTimer:GetTimer("dbm:hidden"))
now = 315
callbacks.DBM_TimerPause("DBM_TimerPause", "fire")
now = 320
assert(InfinityEncounterTimer:GetTimer("dbm:fire"):GetRemaining() == 7)
callbacks.DBM_TimerUpdate("DBM_TimerUpdate", "fire", 3, 15)
assert(InfinityEncounterTimer:GetTimer("dbm:fire"):GetRemaining() == 12)
callbacks.DBM_TimerResume("DBM_TimerResume", "fire")
now = 322
assert(InfinityEncounterTimer:GetTimer("dbm:fire"):GetRemaining() == 10)
callbacks.DBM_TimerUpdateName("DBM_TimerUpdateName", "fire", "Renamed")
assert(InfinityEncounterTimer:GetTimer("dbm:fire").name == "[DBM] Renamed")
callbacks.DBM_TimerStop("DBM_TimerStop", "fire")
assert(not InfinityEncounterTimer:GetTimer("dbm:fire"))
callbacks.DBM_TimerStart("DBM_TimerStart", "other", "Other", 20)
local removals, failRemoval = 0, true
DBM.UnregisterCallback = function(_, event, callback)
	removals = removals + 1
	if failRemoval and removals == 2 then failRemoval = false; error("removal failure") end
	assert(callbacks[event] == callback)
	callbacks[event] = nil
end
commands["/encounter dbm"]("off")
assert(db.dbmEnabled and not bridge.attached and warnings[#warnings]:find("removal failure", 1, true))
commands["/encounter dbm"]("on")
assert(db.dbmEnabled and bridge.attached and callbacks.DBM_TimerBegin and callbacks.DBM_TimerStop)
callbacks.DBM_TimerBegin("DBM_TimerBegin", "other", "Other", 20)
commands["/encounter dbm"]("off")
assert(not db.dbmEnabled and not next(callbacks) and not InfinityEncounterTimer:GetTimer("dbm:other"))
local module = {
	id = "boss",
	timers = { { spellId = 42 }, { spellId = secret }, { spellId = "ej2" } },
	announces = { { spellId = 42 }, { spellId = 51 } },
	specwarns = {},
}
DBM.Mods = { module }
DBM.GetModByName = function(_, id) return id == "boss" and module or nil end
bridge:Detect()
assert(popup == "INFINITY_ENCOUNTER_DBM_IMPORT")
StaticPopupDialogs.INFINITY_ENCOUNTER_DBM_IMPORT.OnCancel()
assert(db.dbmImportAllowed == false)
commands["/encounter dbm import"]("boss")
assert(warnings[#warnings]:find("Allow DBM imports", 1, true))
commands["/encounter dbm modules"]("")
assert(messages[#messages] == "boss")
commands["/encounter dbm modules"]("unmatched")
assert(messages[#messages]:find("No matching", 1, true))
commands["/encounter dbm import"]("on")
commands["/encounter dbm import"]("boss")
local imported = db.watchPresets.preset_3
assert(imported and imported.name == "DBM boss" and #imported.steps == 2)
assert(imported.steps[1].questID == 42 and imported.steps[2].questID == 51)
assert(db.watchedSpells[42] == nil and db.watchedSpells[51] == nil)
commands["/encounter dbm import"]("missing")
assert(warnings[#warnings]:find("not loaded", 1, true))
module.timers = {}
for i = 1, 201 do module.timers[i] = { spellId = i } end
commands["/encounter dbm import"]("boss")
assert(warnings[#warnings]:find("200%-spell") and not db.watchPresets.preset_4)
commands["/encounter dbm import"]("off")
dofile("InfinityCore\\UI\\UIFramework.lua")
local ui = InfinityEncounterUI
ui:ShowControls()
local function ClickControl(prefix)
	for _, row in ipairs(ui.controls.rows) do
		if row:IsShown() and row.data.text:find(prefix, 1, true) == 1 then
			row.scripts.OnClick(row)
			return
		end
	end
	error("Missing control: " .. prefix)
end
ui.controlText:SetText("GUI timer")
ui.controlID:SetText("20")
ClickControl("Start manual timer")
assert(InfinityEncounterTimer:GetTimer("manual:gui timer"))
ClickControl("Stop manual timer")
assert(not InfinityEncounterTimer:GetTimer("manual:gui timer"))
ui.controlText:SetText("GUI watch")
ui.controlID:SetText("123")
ClickControl("Watch boss spell")
assert(db.watchedSpells[123] == "GUI watch")
ClickControl("Manage watched")
assert(ui.watches.rows[1].data.text:find("123", 1, true))
ui.watches.rows[1].scripts.OnClick(ui.watches.rows[1])
assert(db.watchedSpells[123])
ui.watches.rows[1].scripts.OnClick(ui.watches.rows[1])
assert(not db.watchedSpells[123])
ClickControl("Watch boss spell")
ui.controlText:SetText("GUI preset")
ClickControl("Save current watches")
assert(db.watchPresets.preset_4 and db.watchPresets.preset_4.name == "GUI preset")
ClickControl("Manage boss presets")
local delete
for _, row in ipairs(ui.presetsWindow.rows) do
	if row.data.text:find("Delete GUI preset", 1, true) == 1 then delete = row end
end
assert(delete)
delete.scripts.OnClick(delete)
assert(db.watchPresets.preset_4)
delete.scripts.OnClick(delete)
assert(not db.watchPresets.preset_4)
module.timers = { { spellId = 42 } }
ClickControl("Allow DBM preset")
ui.controlText:SetText("boss")
ClickControl("Browse loaded DBM")
assert(ui.dbmWindow.rows[1].data.text:find("boss", 1, true))
ui.dbmWindow.rows[1].scripts.OnClick(ui.dbmWindow.rows[1])
assert(db.watchPresets.preset_4 and db.watchPresets.preset_4.name == "DBM boss")
local reloaded = dofile("InfinityEncounter\\Modules\\DBMBridge.lua")
local saved = { dbmEnabled = false, dbmImportAllowed = false }
reloaded:Initialize(saved)
popup = nil
reloaded.frame.scripts.OnEvent(reloaded.frame, "PLAYER_LOGIN")
assert(not popup and not next(callbacks))
saved.dbmEnabled = true
reloaded.frame.scripts.OnEvent(reloaded.frame, "ADDON_LOADED")
assert(reloaded.attached and callbacks.DBM_TimerBegin)
assert(reloaded:SetEnabled(false) and not next(callbacks))
DBM = { Mods = {}, GetModByName = function() end }
local importOnly = dofile("InfinityEncounter\\Modules\\DBMBridge.lua")
importOnly:Initialize({})
popup = nil
importOnly.frame.scripts.OnEvent(importOnly.frame, "PLAYER_LOGIN")
assert(popup == "INFINITY_ENCOUNTER_DBM_IMPORT")
print = oldPrint
print("encounter_runtime: all tests passed")
